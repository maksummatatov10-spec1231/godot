"""Render clean player-visible PNGs and prove elevated facade/hero reception with A/B."""
import argparse
import json
import os
import subprocess

from PIL import Image, ImageChops

from capture_lantern import ROOT, game_digest


OUTPUT = ROOT / 'docs/evidence/lantern-beauty'


def changed_pixels(difference, bounds):
    crop = difference.crop(bounds)
    return sum(1 for y in range(crop.height) for x in range(crop.width)
               if max(crop.getpixel((x, y))) > 12)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--portable', action='store_true')
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = {'passed': False, 'game_sha256': game_digest(), 'real_render': True,
              'player_visible': True, 'physical_gpu_benchmark': False}
    (OUTPUT / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    engine = os.environ.get('GODOT4_BIN', str(ROOT / '.tools/godot/Godot_v4.7.2-stable_linux.x86_64'))
    command = [engine, '--path', str(ROOT / 'lantern_game'), '--audio-driver', 'Dummy',
               '--fixed-fps', '30', '--resolution', '960x540' if args.portable else '1280x720',
               '--script', str(ROOT / 'tools/lantern_beauty.gd')]

    def run(env, command):
        with (OUTPUT / 'render.log').open('w') as log:
            return subprocess.run(command, env=dict(env, BEAUTY_DIR=str(OUTPUT)), cwd=ROOT,
                                  stdout=log, stderr=subprocess.STDOUT, timeout=240).returncode

    if args.portable:
        from portable_graphics import environment
        with environment() as env:
            code = run(env, command[:1] + ['--display-driver', 'x11', '--rendering-driver',
                                         'opengl3_es'] + command[1:])
    else:
        code = run(os.environ, ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', *command])
    log = (OUTPUT / 'render.log').read_text()
    if code != 0 or 'LANTERN_BEAUTY_OK 6' not in log or 'ERROR' in log or 'leaked' in log:
        print('BEAUTY_FAIL exit=', code, log[-6000:], flush=True)
        return 1
    if game_digest() != report['game_sha256']:
        raise RuntimeError('Game changed while rendering beauty evidence')
    on = Image.open(OUTPUT / '04-received-shadow.png').convert('RGB')
    off = Image.open(OUTPUT / '04-reception-disabled.png').convert('RGB')
    difference = ImageChops.difference(on, off)
    # Fixed camera (595,716), zoom 2, logical viewport 640x360 => world left435/top626.
    # Facade ROI excludes the hero, pot and flowers. Hero ROI is separately checked.
    scale = on.width / 320

    def screen_rect(world_rect):
        x, y, w, h = world_rect
        return tuple(round(value * scale) for value in
                     (x - 435, y - 626, x + w - 435, y + h - 626))

    facade = changed_pixels(difference, screen_rect((579, 729, 10, 15)))
    hero = changed_pixels(difference, screen_rect((594, 733, 18, 24)))
    if facade < 12 or hero < 30:
        raise RuntimeError(f'No proven raised-surface reception: facade={facade}, hero={hero}')
    report.update(passed=True, images=6, facade_receiver_changed_pixels=facade,
                  hero_receiver_changed_pixels=hero, difference_threshold=12,
                  fixed_camera=True, unchanged_time_and_pose=True,
                  wildlife_portrait='Existing game actors staged for a readable close-up, not painted in')
    (OUTPUT / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print('LANTERN_BEAUTY_PASS', facade, 'facade pixels;', hero, 'hero pixels', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
