"""Strict orbit, night-contrast A/B and frozen-geometry render acceptance."""
import json
import os
import subprocess
from PIL import Image, ImageChops, ImageStat
from capture_lantern import ROOT, game_digest
from capture_lantern_foundation import run

OUTPUT = ROOT / 'docs/evidence/lantern-celestial'


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = {'passed': False, 'game_sha256': game_digest(), 'real_render': True,
              'physical_gpu_benchmark': False}
    path = OUTPUT / 'result.json'
    path.write_text(json.dumps(report, indent=2) + '\n')
    engine = os.environ.get('GODOT4_BIN', str(ROOT / '.tools/godot/Godot_v4.7.2-stable_linux.x86_64'))
    base = [engine, '--path', str(ROOT / 'lantern_game'), '--audio-driver', 'Dummy']
    run(base + ['--headless', '--script', 'res://celestial_tests.gd'],
        OUTPUT / 'math.log', 'LANTERN_CELESTIAL_TEST_RESULT')
    math = json.loads(next(line.split('LANTERN_CELESTIAL_TEST_RESULT', 1)[1].strip()
                           for line in (OUTPUT / 'math.log').read_text().splitlines()
                           if 'LANTERN_CELESTIAL_TEST_RESULT' in line))
    if math['failed']:
        raise RuntimeError(math)
    run(['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', *base,
         '--fixed-fps', '30', '--resolution', '1280x720', '--script',
         str(ROOT / 'tools/lantern_celestial.gd')], OUTPUT / 'render.log',
        'LANTERN_CELESTIAL_CAPTURE_OK 30', dict(os.environ, CELESTIAL_DIR=str(OUTPUT)))
    capture = json.loads((OUTPUT / 'capture.json').read_text())
    from benchmark_lantern import changed_pixels
    acne = {name: changed_pixels(OUTPUT / (name + '-on.png'), OUTPUT / (name + '-off.png'))
            for name in capture['acne_pairs']}
    if len(acne) != 7 or max(acne.values()) != 0:
        raise RuntimeError('Isolated caster falsely shadows itself: ' + str(acne))
    contrast = {}
    for name in ['orbit-0000', 'orbit-1200']:
        on = Image.open(OUTPUT / (name + '.png')).convert('RGB')
        off = Image.open(OUTPUT / (name + '-no-shadows.png')).convert('RGB')
        contrast[name] = sum(ImageStat.Stat(ImageChops.difference(on, off)).mean) / 3
    if contrast['orbit-1200'] < 0.2 or not 0.0001 < contrast['orbit-0000'] / contrast['orbit-1200'] < 0.20:
        raise RuntimeError('Night shadows not proven subtler than day: ' + str(contrast))
    frames = [Image.open(OUTPUT / (s['image'] + '.png')).convert('RGB') for s in capture['samples']]
    frames[0].save(OUTPUT / 'celestial-cycle.gif', save_all=True, append_images=frames[1:],
                   duration=650, loop=0, optimize=True)
    for frame in frames:
        frame.close()
    if game_digest() != report['game_sha256']:
        raise RuntimeError('Source changed during celestial capture')
    report.update(passed=True, math=math, images=30, self_shadow_changed_pixels_over_12=acne, contrast_mean_rgb=contrast,
                  night_to_day_contrast=contrast['orbit-0000'] / contrast['orbit-1200'],
                  clock_pose_rebuilds=capture['clock_pose_rebuilds'],
                  clock_mesh_rebuilds=capture['clock_mesh_rebuilds'])
    path.write_text(json.dumps(report, indent=2) + '\n')
    print('LANTERN_CELESTIAL_PASS', report, flush=True)


if __name__ == '__main__':
    main()
