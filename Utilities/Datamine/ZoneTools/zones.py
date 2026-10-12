"""Extract supported offline Endfield zone meshes; --decode-only reuses saved inputs."""
import argparse
import collections
import hashlib
import json
import re
import subprocess
from pathlib import Path
from decoder import ZoneCodec
from geometry import reconstruct
from native import load_evidence, prepare
from workflow import ROOT, KINDS, load_config, resolve_path, timestamp, write_json

def build(input_dir,output,regions,kinds,config,evidence):
    codec=ZoneCodec(config,evidence); datasets={(r,k):[] for r in regions for k in kinds}; errors=[]; unresolved=[]; prefixes=[]; source_hashes={}; files=collections.Counter()
    paths=sorted((input_dir/'Data/Json/LevelData').rglob('*.json'))
    if not paths: raise FileNotFoundError('No LevelData inputs; run with --extract or supply --input')
    for path in paths:
        region=next((r for r in regions if path.name.startswith(r+'_')),None)
        if region is None: continue
        files[region]+=1; raw=path.read_bytes(); source=path.relative_to(input_dir).as_posix(); digest=hashlib.sha256(raw).hexdigest(); source_hashes[source]=digest
        try:
            framed=codec.frame(raw); area=framed['fields'].get('functionArea'); stop=framed.get('openField')
            if stop and (stop['name'].startswith('functionArea') or stop['name'].split('.')[0] in codec.leveldata.LEVELDATA_FIELDS[:17]):
                prefixes.append({'region':region,'source':source,'stop':stop}); continue
            if not area or area.get('value','present') is None: continue
            members=area.get('members',{}); bases=members.get('baseData',{}).get('rows',[]); ranges=members.get('ranges',{}).get('rows',[]); specifics=members.get('specificDatas',{}).get('rows',[])
            conditions=members.get('functionAreaConditions',{}).get('rows',[])
            if len(ranges)!=len(bases): raise ValueError('Function-area bounds are not parallel to base rows')
            for row_index,base in enumerate(bases):
                if base.get('value','present') is None: continue
                function_type=base['functionType']
                if function_type not in (1,15): continue
                if function_type==15:
                    unresolved.append({'region':region,'source':source,'baseData':base,'reason':'TempRepatriateZone is not established as a timed eviction volume'}); continue
                setting_index=base['index']
                if not 0<=setting_index<len(specifics): raise ValueError('Repatriation settings index outside specificDatas')
                settings=specifics[setting_index]
                if not settings or settings['storedType']!='Beyond.Gameplay.LevelFunctionAreaData+RepatriateZoneData': raise ValueError('Function type does not join to RepatriateZoneData')
                kind='teleport' if settings['useRepatriateZoneType'] else 'death'
                if kind not in kinds: continue
                try:
                    geometry=reconstruct(base,ranges[row_index])
                    selected_conditions=[c for c in conditions if str(c.get('uniqueId'))==base['uniqueId']] if base['hasCondition'] else []
                    if base['hasCondition'] and not selected_conditions: raise ValueError('Conditional zone has no matching condition identity')
                    identity=region+':'+source+':'+str(row_index)
                    row={'zoneId':identity,'kind':kind,'baseData':base,'settings':settings,'conditions':selected_conditions,'range':ranges[row_index],'origins':[{'source':source,'sourceSha256':digest,'rowIndex':row_index,'decodedOffset':base['startOffset'],'inputRoot':str(input_dir.resolve())}],**geometry}
                    datasets[(region,kind)].append(row)
                except ValueError as exc:
                    errors.append({'region':region,'kind':kind,'source':source,'rowIndex':row_index,'error':str(exc)})
                    unresolved.append({'region':region,'source':source,'baseData':base,'settings':settings,'reason':str(exc)})
        except Exception as exc: errors.append({'region':region,'source':source,'error':str(exc)})
    summaries=[]
    for region in regions:
        if not files[region]: raise ValueError('No LevelData files for '+region)
        for kind in kinds:
            selected_errors=[e for e in errors if e['region']==region and e.get('kind',kind)==kind]
            selected_prefixes=[p for p in prefixes if p['region']==region]
            supported=kind!='eviction'
            status='decoded' if supported and not selected_errors and not selected_prefixes else 'partial' if supported else 'unresolved'
            boundary='Authored supported function-area volumes. Conditions/defaultOff are retained; no runtime activation or whole-game coverage claim.'
            if kind=='eviction': boundary='Timed cross-border response is server-notified. An authored eviction-volume geometry definition has not been established; empty zones is not a successful extraction.'
            report={'format':'endfield-offline-zone-meshes','version':1,'region':region,'kind':kind,'status':status,'coordinateSpace':'unity-world','boundary':boundary,'nativeInputs':codec.hashes,'filesScanned':files[region],'sourceHashes':{s:h for s,h in source_hashes.items() if region+'_' in s},'errors':selected_errors,'unresolvedPrefixes':selected_prefixes,'zones':datasets[(region,kind)]}
            write_json(output/(region+'-'+kind+'-zones.json'),report,output)
            summaries.append({'region':region,'kind':kind,'status':status,'zoneCount':len(report['zones']),'triangleCount':sum(len(z['triangles']) for z in report['zones']),'errorCount':len(selected_errors),'prefixGaps':len(selected_prefixes)})
    write_json(output/'unresolved-candidates.json',{'records':unresolved,'prefixes':prefixes,'errors':errors},output)
    write_json(output/'extraction-report.json',{'datasets':summaries,'inputRoot':str(input_dir.resolve()),'nativeInputs':codec.hashes,'boundary':'Eviction classification withheld; no safe-zone or chunk-boundary substitutes are published.'},output)
    for row in summaries: print(row,flush=True)
    return 0 if all(s['status']=='decoded' for s in summaries) else 2


def discover_regions(input_dir):
    return sorted({match.group(1) for p in (input_dir/'Data/Json/LevelData').rglob('*.json')
                   if (match:=re.match(r'(map\d+)_',p.name))})

def validate_input(input_dir,evidence):
    manifest=input_dir/'zone-inputs.json'
    if not manifest.is_file():
        raise FileNotFoundError('Input provenance missing: '+str(manifest)+'; use an extraction produced by ZoneTools')
    value=json.loads(manifest.read_text(encoding='utf-8-sig'))
    if value.get('format')!='endfield-zone-inputs' or value.get('version')!=1:
        raise ValueError('Unsupported zone input manifest')
    if value.get('nativeInputs')!=evidence['nativeInputs']:
        raise ValueError('Saved LevelData and native evidence belong to different builds; select matching saved evidence or extract fresh inputs')

def saved_input(config,output):
    if config.get('scene_input'):
        return resolve_path(config['scene_input'])
    manifest=output/'latest-extraction.json'
    if not manifest.is_file():
        raise FileNotFoundError('No saved extraction; run zones.py or configure scene_input')
    value=json.loads(manifest.read_text(encoding='utf-8-sig'))['scene_input']
    path=Path(value)
    return path.resolve() if path.is_absolute() else (output/path).resolve()

def extract_inputs(config,regions,output):
    kit=resolve_path(config['research_kit'])
    engine=kit/'tools/AnimeStudio/AnimeStudio.CLI/bin/Release/net9.0-windows/AnimeStudio.CLI.exe'
    if not engine.is_file(): raise FileNotFoundError('Build ResearchKit AnimeStudio CLI first: '+str(engine))
    game=resolve_path(config['game_data'])
    primary=game/'Persistent' if (game/'Persistent/VFS').is_dir() else game/'StreamingAssets'
    scene=output/'inputs'/timestamp()
    pattern=r'(?i)LevelData/('
    pattern+= '|'.join(re.escape(r) for r in regions)+r')_' if regions else r'map\d+)_' 
    command=[str(engine),'dump','-s',str(primary),'-o',str(scene),'-b','json-data','--file-regex',pattern]
    if primary.name=='Persistent': command+=['--fallback-assets',str(game/'StreamingAssets')]
    subprocess.run(command,check=True)
    if not discover_regions(scene): raise RuntimeError('Extraction returned no mapNN LevelData payloads')
    return scene

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',type=Path,default=ROOT/'config.json')
    mode=parser.add_mutually_exclusive_group()
    mode.add_argument('--decode-only',action='store_true')
    mode.add_argument('--prepare-native',action='store_true',help='Prepare copied native inputs and evidence only')
    parser.add_argument('--input',type=Path,help='Override saved input folder for --decode-only')
    parser.add_argument('--output',type=Path,help='Override dataset directory')
    parser.add_argument('--regions',nargs='+')
    parser.add_argument('--kinds',nargs='+',choices=KINDS)
    args=parser.parse_args()
    if args.input and not args.decode_only: parser.error('--input requires --decode-only')
    if args.prepare_native and any((args.input,args.output,args.regions,args.kinds)):
        parser.error('--prepare-native accepts --config only')
    config=load_config(args.config)
    if args.prepare_native:
        prepare(config)
        return 0
    output=args.output.resolve() if args.output else resolve_path(config['output'])
    regions=list(dict.fromkeys(args.regions if args.regions is not None else config['regions']))
    kinds=list(dict.fromkeys(args.kinds if args.kinds is not None else config['kinds']))
    if any(not re.fullmatch(r'map\d+',r) for r in regions): parser.error('Regions must be mapNN identifiers')
    # Fix: validate the selected build before reading archives or replacing datasets.
    evidence=load_evidence(config,check_installed=not args.decode_only)
    if args.decode_only:
        scene=args.input.resolve() if args.input else saved_input(config,output)
    else:
        scene=extract_inputs(config,regions,output)
        # Refuse a client update that happened during archive extraction.
        load_evidence(config,check_installed=True)
        write_json(scene/'zone-inputs.json',{'format':'endfield-zone-inputs','version':1,'nativeInputs':evidence['nativeInputs']},output)
        write_json(output/'latest-extraction.json',{'scene_input':scene.relative_to(output).as_posix(),'nativeInputs':evidence['nativeInputs']},output)
    # Fix: cached payloads must retain the native identity captured at extraction time.
    validate_input(scene,evidence)
    if not regions: regions=discover_regions(scene)
    if not regions: raise RuntimeError('No mapNN regions found')
    print('LevelData input:',scene,flush=True)
    return build(scene,output,regions,kinds,config,evidence)

if __name__=='__main__': raise SystemExit(main())
