"""Import, gameplay-test and render the standalone forest game with actual Forward+."""
import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'docs/evidence/forest-game'


def main():
    engine = os.environ['GODOT4_BIN']
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for image in OUTPUT.glob('*.png'):
        image.unlink()
    report = {'timestamp_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'renderer': 'Forward+', 'hardware_performance_test': False,
              'device_environment': os.environ.get('VK_ICD_FILENAMES', ''), 'steps': []}
    base = [engine, '--path', str(ROOT / 'forest_game')]

    def run(name, args, marker=None, timeout=120):
        process = subprocess.Popen(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, start_new_session=True)
        try:
            text, _ = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            text, _ = process.communicate()
            text += '\nERROR: capture runner timeout\n'
        (OUTPUT / (name + '.log')).write_text(text)
        passed = process.returncode == 0 and 'ERROR:' not in text and 'Program crashed' not in text
        if marker:
            passed = passed and marker in text
        report['steps'].append({'name': name, 'passed': passed, 'exit_code': process.returncode})
        print(name, 'PASS' if passed else 'FAIL', flush=True)
        return passed

    imported = run('import', base + ['--headless', '--editor', '--import'], timeout=240)
    if imported:
        run('gameplay', base + ['--headless', '--fixed-fps', '60', '--quit-after', '1800',
                               '--script', 'res://tests.gd', '--', '--self-test'], 'FOREST_TEST_OK')
        rendered = run('render', ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', *base,
                                  '--rendering-method', 'forward_plus', '--audio-driver', 'Dummy',
                                  '--fixed-fps', '30', '--resolution', '1280x720', '--',
                                  '--capture-dir=' + str(OUTPUT)], 'FOREST_CAPTURE_OK', timeout=1200)
        if rendered:
            text = (OUTPUT / 'render.log').read_text()
            valid = 'Forward+ - Using Device' in text
            for name in ['01-third-person', '02-first-person', '03-sword', '04-magic',
                         '05-jump', '06-walking', '07-forest-overview', '08-fps-body-shadow',
                         '09-sky-sun', '10-pause-menu', '11-graphics-settings', '12-audio-settings',
                         '13-main-menu', '14-controls-settings', '15-grip-close',
                         '16-fps-sword_regular_a', '17-fps-sword_regular_b', '18-fps-sword_regular_c',
                         '19-fps-walk', '20-fps-jump', '21-fps-jump_land', '22-high-optimized']:
                path = OUTPUT / (name + '.png')
                if not path.is_file():
                    valid = False
                    continue
                with Image.open(path) as image:
                    valid = valid and image.size == (1280, 720) and max(ImageStat.Stat(image.convert('RGB')).stddev) > 15
            a = Image.open(OUTPUT / '01-third-person.png').convert('RGB')
            b = Image.open(OUTPUT / '02-first-person.png').convert('RGB')
            difference = sum(ImageStat.Stat(ImageChops.difference(a, b)).mean) / 3
            valid = valid and difference > 2
            measurements = json.loads((OUTPUT / 'performance-ab.json').read_text())
            valid = valid and len(measurements['stages']) == 12 and not measurements['cancelled']
            report['steps'].append({'name': 'image-checks', 'passed': bool(valid),
                                    'camera_difference': difference})
    report['passed'] = all(step['passed'] for step in report['steps'])
    (OUTPUT / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
