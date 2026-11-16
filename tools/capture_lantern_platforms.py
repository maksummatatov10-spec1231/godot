"""Analog touch/auto-run/persistence gate plus real FullHD/phone-profile renders."""
import json
import os
from PIL import Image, ImageStat
from capture_lantern import ROOT, game_digest
from capture_lantern_foundation import run

OUTPUT = ROOT / 'docs/evidence/lantern-platforms'


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = dict(passed=False, game_sha256=game_digest(), physical_gpu_tested=False,
                  android_device_tested=False)
    path = OUTPUT / 'result.json'
    path.write_text(json.dumps(report, indent=2) + '\n')
    engine = os.environ.get('GODOT4_BIN', str(ROOT / '.tools/godot/Godot_v4.7.2-stable_linux.x86_64'))
    base = [engine, '--path', str(ROOT / 'lantern_game'), '--audio-driver', 'Dummy']
    run(base + ['--headless', '--fixed-fps', '60', '--script', 'res://platform_tests.gd'],
        OUTPUT / 'input.log', 'LANTERN_PLATFORM_TEST_RESULT')
    tests = json.loads(next(line.split('LANTERN_PLATFORM_TEST_RESULT', 1)[1].strip()
                            for line in (OUTPUT / 'input.log').read_text().splitlines()
                            if 'LANTERN_PLATFORM_TEST_RESULT' in line))
    if tests['failed']:
        raise RuntimeError(tests)
    run(['xvfb-run', '-a', '-s', '-screen 0 1920x1080x24', *base,
         '--fixed-fps', '30', '--resolution', '1920x1080', '--script',
         str(ROOT / 'tools/lantern_platforms.gd')], OUTPUT / 'render.log',
        'LANTERN_PLATFORMS_CAPTURE_OK 8', dict(os.environ, PLATFORMS_DIR=str(OUTPUT)))
    capture = json.loads((OUTPUT / 'capture.json').read_text())
    if len(capture['images']) != 8 or capture['ui_overflows']:
        raise RuntimeError(capture)
    for item in capture['images']:
        with Image.open(OUTPUT / (item['name'] + '.png')) as image:
            if max(ImageStat.Stat(image.convert('RGB')).stddev) < 12:
                raise RuntimeError('Empty platform frame: ' + item['name'])
    if capture['images'][0]['width'] != 1920 or capture['images'][0]['height'] != 1080:
        raise RuntimeError('PC FullHD output not proven')
    if game_digest() != report['game_sha256']:
        raise RuntimeError('Game changed during platform capture')
    report.update(passed=True, tests=tests, capture=capture, real_render=True,
                  pc_target_fps=75, android_default_cap=60,
                  logical_viewport=[640, 360], tested_os='Linux / Mesa software',
                  analog_pointer_tests='injected viewport screen events, actual physics; not physical fingers')
    path.write_text(json.dumps(report, indent=2) + '\n')
    print('LANTERN_PLATFORMS_PASS', tests['checks'])


if __name__ == '__main__':
    main()
