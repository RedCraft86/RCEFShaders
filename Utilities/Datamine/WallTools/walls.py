"""Offline Endfield wall extraction. Never loads DLLs into the game process."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
import decoder

ROOT = Path(__file__).resolve().parent

def path(value):
    p = Path(value)
    return p if p.is_absolute() else ROOT / p

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', default=str(ROOT/'config.json'))
    parser.add_argument('--decode-only', action='store_true', help='Reuse already extracted scene payloads')
    args = parser.parse_args()
    config = json.loads(Path(args.config).read_text(encoding='utf-8-sig'))
    output = path(config['output'])
    scene = path(config['scene_input']) if args.decode_only and config.get('scene_input') else output/'offline-scene'
    kit = path(config['research_kit']).resolve()
    config['research_kit'] = str(kit)
    engine = kit/'tools/AnimeStudio/AnimeStudio.CLI/bin/Release/net9.0-windows/AnimeStudio.CLI.exe'
    game = path(config['game_data'])
    if not args.decode_only:
        if not engine.is_file(): raise FileNotFoundError(engine)
        primary = game/'Persistent' if (game/'Persistent/VFS').is_dir() else game/'StreamingAssets'
        fallback = game/'StreamingAssets' if primary.name=='Persistent' else None
        command = [str(engine), 'dump', '-s', str(primary), '-o', str(scene), '-b', 'streaming']
        if fallback is not None: command += ['--fallback-assets', str(fallback)]
        # New mapNN regions are discovered from extracted paths, not a hardcoded list.
        if config.get('regions'): command += ['--file-regex', '('+'|'.join(re.escape(r) for r in config['regions'])+')/']
        subprocess.run(command, check=True)
    folders = scene/'Data/Streaming/PC'
    regions = config.get('regions') or sorted(p.name for p in folders.glob('map[0-9]*') if p.is_dir())
    if not regions: raise RuntimeError('No map regions found in extracted payloads')
    for region in regions:
        if not re.fullmatch(r'map\d+', region): raise ValueError('Invalid region: '+region)
        decoder.extract(scene, output, region, config)

if __name__ == '__main__': main()
