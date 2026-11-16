"""Strict foundation gate: isolated restart tests + real-render time/menu/light A-B."""
import json
import os
from pathlib import Path
import subprocess
from PIL import Image, ImageChops, ImageStat
from capture_lantern import ROOT, game_digest

OUTPUT = ROOT / 'docs/evidence/lantern-foundation'


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = {'passed': False, 'game_sha256': game_digest(), 'real_render': True,
              'physical_gpu_benchmark': False}
    result_path = OUTPUT / 'result.json'
    result_path.write_text(json.dumps(report, indent=2) + '\n')
    engine = os.environ.get('GODOT4_BIN', str(ROOT / '.tools/godot/Godot_v4.7.2-stable_linux.x86_64'))
    base = [engine, '--path', str(ROOT / 'lantern_game'), '--audio-driver', 'Dummy']
    for phase in ['write', 'read']:
        args = base + ['--headless', '--fixed-fps', '60', '--script',
                       'res://foundation_tests.gd', '--', '--persistence-' + phase]
        run(args, OUTPUT / ('persistence-' + phase + '.log'), 'FOUNDATION_TEST_RESULT')
    command = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', *base,
               '--fixed-fps', '30', '--resolution', '1280x720',
               '--script', str(ROOT / 'tools/lantern_foundation.gd')]
    run(command, OUTPUT / 'render.log', 'LANTERN_FOUNDATION_CAPTURE_OK 22',
        dict(os.environ, FOUNDATION_DIR=str(OUTPUT)))
    capture = json.loads((OUTPUT / 'capture.json').read_text())
    if len(capture['images']) != 22 or capture['ui_overflows']:
        raise RuntimeError('Incomplete captures or clipped UI: ' + str(capture))
    for name in capture['images']:
        with Image.open(OUTPUT / (name + '.png')) as im:
            if im.size != (1280, 720) or max(ImageStat.Stat(im.convert('RGB')).stddev) < 12:
                raise RuntimeError('Empty or incorrect capture: ' + name)
    images = {}
    for name in ['noon', 'night', 'sunrise', 'evening', 'predawn']:
        images[name] = Image.open(OUTPUT / ('03-village-' + name + '.png')).convert('RGB')
    levels = {name: sum(ImageStat.Stat(im).mean)/3 for name, im in images.items()}
    if not 0.15 < levels['night']/levels['noon'] < 0.7:
        raise RuntimeError('Night is missing or unreadably black: ' + str(levels))
    off = Image.open(OUTPUT / '04-night-lights-off.png').convert('RGB')
    delta = ImageChops.difference(images['night'], off)
    changed = sum(delta.convert('L').histogram()[12:])
    if changed < 1000 or levels['night'] <= sum(ImageStat.Stat(off).mean)/3:
        raise RuntimeError('No measurable local night illumination')
    frames = [Image.open(OUTPUT / ('03-village-' + name + '.png')).convert('RGB')
              for name in ['predawn', 'sunrise', 'morning', 'noon', 'evening', 'twilight', 'night']]
    frames[0].save(OUTPUT / 'day-night.gif', save_all=True, append_images=frames[1:],
                   duration=1000, loop=0, optimize=True)
    for frame in frames:
        frame.close()
    report.update(passed=True, images=22, ui_overflows=[], levels=levels,
                  night_lighting_changed_pixels_over_12=changed,
                  restart_processes=2, slot='isolated validation directories only')
    if report['game_sha256'] != game_digest():
        raise RuntimeError('Game changed during validation')
    result_path.write_text(json.dumps(report, indent=2) + '\n')
    print('LANTERN_FOUNDATION_PASS', levels, changed, flush=True)


def run(args, log_path, marker, env=None):
    with log_path.open('w') as log:
        result = subprocess.run(args, cwd=ROOT, env=env, stdout=log,
                                stderr=subprocess.STDOUT, timeout=300)
    text = log_path.read_text()
    if result.returncode or 'ERROR:' in text or 'leaked' in text or marker not in text:
        raise RuntimeError(f'{log_path.name}: exit {result.returncode}\n{text[-6000:]}')
    if marker == 'FOUNDATION_TEST_RESULT':
        data = json.loads(next(line.split(marker, 1)[1].strip()
                               for line in text.splitlines() if marker in line))
        if data['failed']:
            raise RuntimeError('Foundation integration failures: ' + str(data))


if __name__ == '__main__':
    main()
