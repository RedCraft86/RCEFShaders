"""Shared ZoneTools configuration, path resolution, and backed-up JSON publication."""
import datetime
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
KINDS = ('death', 'teleport', 'eviction')

def resolve_path(value):
    path = Path(value)
    return path.resolve() if path.is_absolute() else (ROOT / path).resolve()

def load_config(path=None):
    source = Path(path) if path is not None else ROOT / 'config.json'
    config = json.loads(source.read_text(encoding='utf-8-sig'))
    for name in ('game_data', 'research_kit', 'output', 'native_inputs', 'native_evidence', 'blender_export_dir'):
        if not isinstance(config.get(name), str) or not config[name]:
            raise ValueError('Missing configured path: ' + name)
    if not isinstance(config.get('regions'), list) or any(not isinstance(r, str) for r in config['regions']):
        raise ValueError('regions must be a list of mapNN identifiers')
    kinds = config.get('kinds', ['death', 'teleport'])
    if not isinstance(kinds, list) or not kinds or any(k not in KINDS for k in kinds):
        raise ValueError('kinds must select death, teleport, or eviction')
    config['kinds'] = kinds
    return config

def configure_research_kit(config):
    kit = resolve_path(config['research_kit'])
    if not (kit / 'scripts/game_data/leveldata_binary.py').is_file():
        raise FileNotFoundError('ResearchKit source checkout is required: ' + str(kit))
    if str(kit) not in sys.path:
        sys.path.insert(0, str(kit))
    return kit

def timestamp():
    return datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S-%f')

def write_json(path, value, output):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = Path(output) / 'backups' / timestamp()
        backup.mkdir(parents=True)
        shutil.copy2(path, backup / path.name)
    temporary = path.with_name(path.name + '.' + timestamp() + '.tmp')
    try:
        temporary.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n', encoding='utf-8')
        temporary.replace(path)
    finally:
        if temporary.exists():
            temporary.unlink()
