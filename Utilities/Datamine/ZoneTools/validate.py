"""Validate generated zone datasets against saved inputs and geometric invariants."""
import argparse
import collections
import json
import math
import re
from pathlib import Path

from geometry import area_volume, bounds, cross, subtract
from native import hash_file, load_evidence
from workflow import ROOT, KINDS, load_config, resolve_path, write_json
from zones import saved_input, validate_input

BOUNDS_TOLERANCE = .003
AUTHORED_BOUNDS_TOLERANCE = .02
METRIC_RELATIVE_TOLERANCE = 1e-6


def finite_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def vector(value, length=3):
    if not isinstance(value, list) or len(value) != length or not all(finite_number(v) for v in value):
        raise ValueError('Expected a finite numeric vector')
    return value


def close_metric(actual, stored):
    return finite_number(stored) and abs(actual-stored) <= METRIC_RELATIVE_TOLERANCE * max(1., abs(actual))


def check_geometry(zone):
    """Check mesh topology and metrics without relying on a known shape count."""
    vertices = zone['vertices']
    triangles = zone['triangles']
    if not isinstance(vertices, list) or len(vertices) < 4:
        raise ValueError('A volume needs at least four vertices')
    for point in vertices:
        vector(point)
    if not isinstance(triangles, list) or not triangles:
        raise ValueError('A volume needs triangle faces')
    edges = collections.defaultdict(list)
    used = set()
    signed_parts = []
    origin = vertices[0]
    for triangle in triangles:
        if not isinstance(triangle, list) or len(triangle) != 3 or any(type(i) is not int or not 0 <= i < len(vertices) for i in triangle):
            raise ValueError('Triangle indices must reference three valid vertices')
        if len(set(triangle)) != 3:
            raise ValueError('Triangle repeats a vertex')
        used.update(triangle)
        p, q, r = [vertices[i] for i in triangle]
        normal = cross(subtract(q, p), subtract(r, p))
        if not all(math.isfinite(v) for v in normal) or sum(v*v for v in normal) <= 1e-24:
            raise ValueError('Degenerate or nonfinite triangle')
        a, b, c = [subtract(point, origin) for point in (p, q, r)]
        signed_parts.append(sum(x*y for x,y in zip(a, cross(b,c)))/6)
        for a,b in zip(triangle, triangle[1:]+triangle[:1]):
            edges[tuple(sorted((a,b)))].append((a,b))
    if len(used) != len(vertices):
        raise ValueError('Volume contains unused vertices')
    if any(len(pair) != 2 or pair[0] != tuple(reversed(pair[1])) for pair in edges.values()):
        raise ValueError('Volume is not closed with consistent winding')
    # Fix: absolute volume alone would accept a completely inward-wound mesh.
    signed_volume = math.fsum(signed_parts)
    if not math.isfinite(signed_volume) or signed_volume <= 0:
        raise ValueError('Volume must have positive outward-wound enclosed volume')
    actual_bounds = bounds(vertices)
    stored_bounds = zone['bounds']
    if not isinstance(stored_bounds, list) or len(stored_bounds) != 2:
        raise ValueError('Missing stored bounds')
    for point in stored_bounds:
        vector(point)
    if max(abs(a-b) for p,q in zip(actual_bounds, stored_bounds) for a,b in zip(p,q)) > BOUNDS_TOLERANCE:
        raise ValueError('Stored bounds disagree with mesh vertices')
    authored = zone.get('range')
    if authored is not None:
        center = vector(authored['center'])
        size = vector(authored['size'])
        if not all(v > 0 for v in size):
            raise ValueError('Authored range has nonpositive dimensions')
        expected = [[center[i]+sign*size[i]/2 for i in range(3)] for sign in (-1,1)]
        if max(abs(a-b) for p,q in zip(actual_bounds, expected) for a,b in zip(p,q)) > AUTHORED_BOUNDS_TOLERANCE:
            raise ValueError('Mesh bounds disagree with authored range')
    elif zone['baseData']['shapeType'] == 3:
        raise ValueError('Polygon extrusion is missing its authored range')
    area, volume = area_volume(vertices, triangles)
    if not math.isfinite(area) or area <= 0 or not close_metric(area, zone['surfaceArea']):
        raise ValueError('Stored surface area disagrees with mesh')
    if not close_metric(volume, zone['enclosedVolume']):
        raise ValueError('Stored enclosed volume disagrees with mesh')
    return len(triangles)


def source_path(input_dir, source):
    if not isinstance(source, str) or Path(source).is_absolute():
        raise ValueError('Source provenance must use an extraction-relative path')
    path = (input_dir/source).resolve()
    if not path.is_relative_to(input_dir.resolve()):
        raise ValueError('Source provenance escapes the extraction directory')
    return path


def validate_dataset(data, input_dir, region, kind, native_inputs, hashes=None):
    """Return a report for one region/type, accepting correctly decoded empty datasets."""
    report = {'region':region, 'kind':kind, 'status':'failed', 'zoneCount':0,
              'triangleCount':0, 'sourcesChecked':0, 'errors':[]}
    hashes = {} if hashes is None else hashes
    try:
        # Fix: malformed JSON roots must produce a failed report rather than an attribute error.
        if not isinstance(data, dict):
            raise ValueError('Dataset must be a JSON object')
        if data.get('format') != 'endfield-offline-zone-meshes' or data.get('version') != 1 or data.get('coordinateSpace') != 'unity-world':
            raise ValueError('Unsupported dataset format or coordinate space')
        if data.get('region') != region or data.get('kind') != kind:
            raise ValueError('Dataset identity disagrees with selection')
        if data.get('status') != 'decoded' or data.get('errors') or data.get('unresolvedPrefixes'):
            raise ValueError('Dataset is partial or unresolved')
        if data.get('nativeInputs') != native_inputs:
            raise ValueError('Dataset native identity differs from selected evidence')
        sources = data['sourceHashes']
        if not isinstance(sources, dict) or not sources:
            raise ValueError('No decoded source provenance')
        actual_sources = {p.relative_to(input_dir).as_posix() for p in (input_dir/'Data/Json/LevelData').rglob('*.json') if p.name.startswith(region+'_')}
        if set(sources) != actual_sources or data.get('filesScanned') != len(sources):
            raise ValueError('Scanned source inventory disagrees with saved inputs')
        for source,digest in sources.items():
            path = source_path(input_dir, source)
            if not isinstance(digest, str) or not re.fullmatch(r'[0-9a-f]{64}', digest):
                raise ValueError('Invalid recorded source SHA256')
            if path not in hashes:
                hashes[path] = hash_file(path)
            if hashes[path] != digest:
                raise ValueError('Source SHA256 mismatch: '+source)
            report['sourcesChecked'] += 1
        if not isinstance(data['zones'], list):
            raise ValueError('zones must be a list')
        report['zoneCount'] = len(data['zones'])
        seen = set()
        for index,zone in enumerate(data['zones']):
            try:
                if zone['kind'] != kind or not isinstance(zone['zoneId'],str) or zone['zoneId'] in seen:
                    raise ValueError('Invalid or duplicate zone identity')
                seen.add(zone['zoneId'])
                origins = zone['origins']
                if not isinstance(origins,list) or not origins:
                    raise ValueError('Zone has no source provenance')
                for provenance in origins:
                    source = provenance['source']
                    if source not in sources or provenance['sourceSha256'] != sources[source]:
                        raise ValueError('Zone origin disagrees with source inventory')
                    if type(provenance['rowIndex']) is not int or provenance['rowIndex'] < 0:
                        raise ValueError('Invalid authored row index')
                    offset = provenance['decodedOffset']
                    if type(offset) is not int or not 0 <= offset < source_path(input_dir,source).stat().st_size:
                        raise ValueError('Authored record offset is outside its payload')
                report['triangleCount'] += check_geometry(zone)
            except (ValueError, KeyError, TypeError, IndexError, OSError, OverflowError) as error:
                report['errors'].append({'zoneIndex':index, 'error':str(error)})
        if not report['errors']:
            report['status'] = 'passed'
    except (ValueError, KeyError, TypeError, IndexError, OSError, OverflowError) as error:
        report['errors'].append({'error':str(error)})
    return report


def validate(data_dir, input_dir, regions, kinds, config):
    report = {'format':'endfield-zone-validation', 'version':1, 'status':'failed',
              'inputRoot':str(input_dir.resolve()), 'datasets':[], 'errors':[],
              'boundary':'Checks saved-input/native provenance and mesh invariants; not an activation or whole-game completeness proof.'}
    try:
        evidence = load_evidence(config)
        validate_input(input_dir, evidence)
        report['nativeInputs'] = evidence['nativeInputs']
        if not regions:
            regions = sorted({match.group(1) for p in data_dir.glob('map*-*-zones.json') if (match:=re.fullmatch(r'(map\d+)-(death|teleport|eviction)-zones\.json',p.name))})
        if not regions:
            raise ValueError('No configured or discovered mapNN datasets')
        if any(not re.fullmatch(r'map\d+', region) for region in regions):
            raise ValueError('Regions must be mapNN identifiers')
        hashes = {}
        for region in dict.fromkeys(regions):
            for kind in dict.fromkeys(kinds):
                path = data_dir/(region+'-'+kind+'-zones.json')
                try:
                    data = json.loads(path.read_text(encoding='utf-8-sig'))
                    result = validate_dataset(data,input_dir,region,kind,evidence['nativeInputs'],hashes)
                except (OSError, ValueError) as error:
                    result = {'region':region,'kind':kind,'status':'failed','errors':[{'error':str(error)}]}
                report['datasets'].append(result)
                print(region,kind,result['status'],'zones',result.get('zoneCount',0),'errors',len(result['errors']),flush=True)
        if report['datasets'] and all(r['status']=='passed' for r in report['datasets']):
            report['status'] = 'passed'
    except (OSError, ValueError, KeyError, TypeError) as error:
        report['errors'].append({'error':str(error)})
        print('Validation failed:',error,flush=True)
    write_json(data_dir/'validation-report.json',report,data_dir)
    return 0 if report['status']=='passed' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',type=Path,default=ROOT/'config.json')
    parser.add_argument('--data',type=Path,help='Override dataset directory')
    parser.add_argument('--input',type=Path,help='Override saved LevelData input directory')
    parser.add_argument('--regions',nargs='+',help='Select any mapNN region identifiers')
    parser.add_argument('--kinds',nargs='+',choices=KINDS)
    args = parser.parse_args()
    config = load_config(args.config)
    data_dir = args.data.resolve() if args.data else resolve_path(config['output'])
    input_dir = args.input.resolve() if args.input else saved_input(config,data_dir)
    regions = args.regions if args.regions is not None else config['regions']
    kinds = args.kinds if args.kinds is not None else config['kinds']
    return validate(data_dir,input_dir,regions,kinds,config)

if __name__=='__main__': raise SystemExit(main())

