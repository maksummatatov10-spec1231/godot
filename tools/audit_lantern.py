"""Render the ENTIRE map at close range and verify object/road screenshot coverage."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from capture_lantern import game_digest  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('output', nargs='?', default='docs/evidence/lantern-audit/after')
    parser.add_argument('--portable', action='store_true')
    args = parser.parse_args()
    output = (ROOT / args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    engine = os.environ.get('GODOT4_BIN', str(ROOT / '.tools/godot/Godot_v4.7.2-stable_linux.x86_64'))
    command = [engine, '--path', str(ROOT / 'lantern_game'), '--audio-driver', 'Dummy',
               '--fixed-fps', '30', '--resolution', '960x540' if args.portable else '1280x720',
               '--script', str(ROOT / 'tools/lantern_audit.gd')]
    before = game_digest()
    for image in output.glob('*.png'):
        image.unlink()

    def run(env, command):
        env = dict(env, AUDIT_DIR=str(output))
        with (output / 'render.log').open('w') as log:
            return subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                  timeout=300, cwd=ROOT).returncode

    if args.portable:
        from portable_graphics import environment
        with environment() as env:
            code = run(env, command[:1] + ['--display-driver', 'x11', '--rendering-driver',
                                         'opengl3_es'] + command[1:])
    else:
        code = run(os.environ, ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', *command])
    log = (output / 'render.log').read_text()
    passed = code == 0 and 'AUDIT_CAPTURE_OK' in log and 'ERROR' not in log and 'leaked' not in log
    if not passed:
        detail=log[-6000:].replace('%','%25').replace('\r','%0D').replace('\n','%0A')
        print(f'::error title=Lantern audit exit {code}::{detail}',flush=True)
        print(log[-6000:])
        return 1
    coverage = json.loads((output / 'coverage.json').read_text())
    manifest = json.loads((ROOT / 'lantern_game/assets/world/map.json').read_text())
    names = {entry['name'] for entry in coverage['images']}
    passed = passed and len(coverage['objects']) == len(manifest['objects'])
    passed = passed and len(coverage['roads']) == len(manifest['paths'])
    views = {item['name']: item['world_rect'] for item in coverage['images']}
    for item in coverage['objects']:
        obj = manifest['objects'][item['index']]
        x, y = obj['position']; w, h = obj['size']
        a, b, c, d = views[item['image']]
        passed = passed and a <= x and b <= y and a+c >= x+w and b+d >= y+h
    for item in coverage['roads']:
        x, y = (v*16 for v in item['cell'])
        a, b, c, d = views[item['image']]
        passed = passed and a <= x and b <= y and a+c >= x+16 and b+d >= y+16
    hashes = {}
    for name in sorted(names):
        path = output / (name + '.png')
        with Image.open(path) as image:
            passed = passed and image.size == ((960, 540) if args.portable else (1280, 720))
        hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    passed = passed and before == game_digest()
    report = {'passed': bool(passed), 'game_sha256': before, 'images': len(names),
              'objects_fully_covered': len(coverage['objects']),
              'road_tiles_fully_covered': len(coverage['roads']), 'image_sha256': hashes,
              'visual_review': 'Separate human/agent review documented in REVIEW.md; coverage is not aesthetic approval.'}
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'image_sha256'}, indent=2))
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
