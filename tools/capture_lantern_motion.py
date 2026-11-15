"""Capture actual in-engine motion, build a GIF and isolate wind-driven shadow changes."""
import argparse
import json
import os
from pathlib import Path
import subprocess

from PIL import Image, ImageChops

from capture_lantern import ROOT, game_digest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--portable', action='store_true')
    args = parser.parse_args()
    raw = ROOT / 'artifacts/lantern/motion'
    raw.mkdir(parents=True, exist_ok=True)
    output = ROOT / 'docs/evidence/lantern-motion'
    output.mkdir(parents=True, exist_ok=True)
    report = {'passed': False, 'game_sha256': game_digest(), 'real_render': True,
              'physical_gpu_benchmark': False}
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    engine = os.environ.get('GODOT4_BIN', str(ROOT / '.tools/godot/Godot_v4.7.2-stable_linux.x86_64'))
    command = [engine, '--path', str(ROOT / 'lantern_game'), '--audio-driver', 'Dummy',
               '--fixed-fps', '30', '--resolution', '960x540' if args.portable else '1280x720',
               '--script', str(ROOT / 'tools/lantern_motion.gd')]

    def run(env, command):
        with (output / 'render.log').open('w') as log:
            return subprocess.run(command, env=dict(env, MOTION_DIR=str(raw)), cwd=ROOT,
                                  stdout=log, stderr=subprocess.STDOUT, timeout=300).returncode

    if args.portable:
        from portable_graphics import environment
        with environment() as env:
            code = run(env, command[:1] + ['--display-driver', 'x11', '--rendering-driver',
                                         'opengl3_es'] + command[1:])
    else:
        code = run(os.environ, ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', *command])
    log = (output / 'render.log').read_text()
    if code != 0 or 'LANTERN_MOTION_OK 50' not in log or 'ERROR' in log or 'leaked' in log:
        print('MOTION_FAIL exit=', code, log[-6000:], flush=True)
        return 1
    if game_digest() != report['game_sha256']:
        raise RuntimeError('Game changed during motion capture')
    images = [Image.open(raw / f'motion-{i:02}.png').convert('RGB') for i in range(48)]
    a = Image.open(raw / 'isolated-shadow-a.png').convert('RGB')
    b = Image.open(raw / 'isolated-shadow-b.png').convert('RGB')
    difference = ImageChops.difference(a, b)
    changed = sum(1 for y in range(difference.height) for x in range(difference.width)
                  if max(difference.getpixel((x, y))) > 3)
    if changed <= 100:
        raise RuntimeError('Isolated tree/plant shadows did not visibly move')
    images[0].save(output / 'sunlight-wind-wildlife.gif', save_all=True,
                   append_images=images[1:], duration=100, loop=0, optimize=False)
    for index in [0, 18, 34]:
        images[index].save(output / f'motion-{index:02}.png')
    a.save(output / 'isolated-shadow-a.png')
    b.save(output / 'isolated-shadow-b.png')
    report.update(passed=True, frames=48, fps=10, isolated_shadow_changed_pixels=changed)
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print('LANTERN_MOTION_PASS', changed, 'changed isolated-shadow pixels', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
