"""Prepare and validate ZoneTools evidence against local native copies."""
import hashlib
import shutil
from pathlib import Path
from workflow import configure_research_kit, resolve_path, timestamp, write_json

FORMAT = 'endfield-zone-native-evidence'
NATIVE_NAMES = ('GameAssembly.dll', 'global-metadata.dat')

def hash_file(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()

def installed_paths(config):
    game = resolve_path(config['game_data'])
    return {'GameAssembly.dll': game.parent / 'GameAssembly.dll',
            'global-metadata.dat': game / 'il2cpp_data/Metadata/global-metadata.dat'}

def validate_schema(evidence):
    if evidence.get('format') != FORMAT or evidence.get('version') != 1:
        raise ValueError('Unsupported native evidence format; run zones.py --prepare-native')
    schemas = evidence['wrappers']
    expected = ['bufferDistance','defaultOff','euler','functionType','hasCondition','index','offset','posList','postion','radius','shapeType','size','uniqueId']
    base = schemas['Beyond.Gameplay.LevelFunctionAreaData+FunctionAreaBaseData']
    if base['memberOrder'] != expected:
        raise ValueError('Unsupported current-build function-area member order')
    declared = ['float','bool','UnityEngine.Vector3','Beyond.Gameplay.EFunctionAreaType','bool','int','UnityEngine.Vector3','System.Collections.Generic.List`1<UnityEngine.Vector2>','UnityEngine.Vector3','float','Beyond.Gameplay.Core.TriggerObserverComponent+Shape','UnityEngine.Vector3','ulong']
    if [m['declaredType'] for m in base['members']] != declared:
        raise ValueError('Unsupported current-build function-area member types')
    for member in base['members']:
        if member['kind'] == 'enum' and member.get('width') != 4:
            raise ValueError('Unsupported function-area enum width')
    for enum, values in {
        'Beyond.Gameplay.EFunctionAreaType': {'RepatriateZone': 1, 'TempRepatriateZone': 15},
        'Beyond.Gameplay.Core.TriggerObserverComponent+Shape': {'Box': 1, 'PolyLine': 3},
    }.items():
        if any(evidence['enumConstants'][enum].get(name) != value for name, value in values.items()):
            raise ValueError('Unsupported current-build zone enum identities: ' + enum)
    settings = schemas['Beyond.Gameplay.LevelFunctionAreaData+RepatriateZoneData']
    if settings['memberOrder'] != ['lifeRatio', 'useRepatriateZoneType'] or [m['declaredType'] for m in settings['members']] != ['float', 'bool']:
        raise ValueError('Unsupported current-build repatriation settings')
    by_name = {s['wrapperName']: s for s in schemas.values()}
    for family in ('ConditionRuntimeBase', 'FunctionAreaSpecificData'):
        seen = set()
        for entry in evidence['families'][family]:
            if entry['tag'] in seen:
                raise ValueError('Duplicate native union tag')
            seen.add(entry['tag'])
            schema = by_name[entry['wrapperName']]
            if schema['serializedMemberCount'] != entry['memberCount'] or schema['memberOrder'] != entry['members']:
                raise ValueError('Native union and generated schema disagree')

def verify_hashes(expected, paths, label):
    for name in NATIVE_NAMES:
        path = paths[name]
        if not path.is_file():
            raise FileNotFoundError(label + ' native input missing: ' + str(path))
        if hash_file(path) != expected.get(name):
            raise ValueError(label + ' build differs from native evidence: ' + name + '; run zones.py --prepare-native for the selected installed build')

def load_evidence(config, check_installed=False):
    import json
    path = resolve_path(config['native_evidence'])
    if not path.is_file():
        raise FileNotFoundError('Native evidence missing; run python -B zones.py --prepare-native')
    evidence = json.loads(path.read_text(encoding='utf-8-sig'))
    validate_schema(evidence)
    directory = resolve_path(config['native_inputs'])
    verify_hashes(evidence['nativeInputs'], {n: directory / n for n in NATIVE_NAMES}, 'Copied')
    if check_installed:
        verify_hashes(evidence['nativeInputs'], installed_paths(config), 'Installed')
    return evidence

def prepare(config):
    output = resolve_path(config['output'])
    directory = resolve_path(config['native_inputs'])
    sources = installed_paths(config)
    # Fix: preparation always analyzes copies and must never overwrite installed native files.
    for name in NATIVE_NAMES:
        if (directory / name).resolve() == sources[name].resolve():
            raise ValueError('native_inputs must be separate from installed game inputs')
        if not sources[name].is_file():
            raise FileNotFoundError(sources[name])
    hashes = {name: hash_file(path) for name, path in sources.items()}
    directory.mkdir(parents=True, exist_ok=True)
    for name in NATIVE_NAMES:
        destination = directory / name
        if destination.is_file() and hash_file(destination) == hashes[name]:
            continue
        if destination.exists():
            backup = output / 'backups' / timestamp()
            backup.mkdir(parents=True)
            shutil.copy2(destination, backup / name)
        temporary = destination.with_name(name + '.' + timestamp() + '.tmp')
        try:
            shutil.copy2(sources[name], temporary)
            if hash_file(temporary) != hashes[name]:
                raise ValueError('Installed input changed while being copied: ' + name)
            temporary.replace(destination)
        finally:
            if temporary.exists(): temporary.unlink()
    verify_hashes(hashes, sources, 'Installed')
    configure_research_kit(config)
    from scripts.game_data.il2cpp.native_image import NativeImage
    from scripts.game_data.memorypack.wrapper_members import derive_from_image
    from scripts.game_data.memorypack.union_dispatch import read_union_switch
    from scripts.game_data.levelscript_union_tags import FAMILY_BASES, short_name
    from scripts.game_data.il2cpp.protocol import field_defaults, native_enum_members
    image = NativeImage(directory / 'GameAssembly.dll', directory / 'global-metadata.dat', label='ZoneTools')
    wrappers = derive_from_image(image)
    by_name = {w.name: w for w in wrappers.values()}
    families = {}
    for family in ('ConditionRuntimeBase', 'FunctionAreaSpecificData'):
        switch = read_union_switch(image, FAMILY_BASES[family], wrappers=wrappers)
        families[family] = [{**entry, 'name': short_name(entry['wrapperName']),
                            'memberCount': len(by_name[entry['wrapperName']].members),
                            'members': [m.name for m in by_name[entry['wrapperName']].members]}
                           for entry in switch['entries']]
        print(family, len(families[family]), 'verified routes', flush=True)
    defaults = field_defaults(image.metadata)
    enum_names = ('Beyond.Gameplay.EFunctionAreaType', 'Beyond.Gameplay.Core.TriggerObserverComponent+Shape', 'Beyond.Gameplay.RepatriateRealSource', 'Proto.SCENE_CROSS_BORDER_OP', 'Proto.SCENE_CROSS_BORDER_REASON')
    enums = {name: {row['name']: row['id'] for row in native_enum_members(image.metadata, defaults, image.pe, image.registration, name)} for name in enum_names}
    evidence = {'format': FORMAT, 'version': 1, 'nativeInputs': hashes, 'families': families,
                'enumConstants': enums, 'wrappers': {w.wrapped_type: w.row() for w in wrappers.values() if w.wrapped_type},
                'boundary': 'Current copied-build formatter switches, generated member declarations, and typed enum constants; not a runtime activation proof.'}
    validate_schema(evidence)
    verify_hashes(hashes, {n: directory / n for n in NATIVE_NAMES}, 'Copied')
    verify_hashes(hashes, sources, 'Installed')
    write_json(resolve_path(config['native_evidence']), evidence, output)
    print('Native evidence ready:', resolve_path(config['native_evidence']), flush=True)
    return evidence
