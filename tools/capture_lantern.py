"""Run physics/input tests and capture real Compatibility-rendered village evidence."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'lantern_game'
OUTPUT = ROOT / 'docs/evidence/lantern'


def game_digest():
    digest = hashlib.sha256()
    for path in sorted(GAME.rglob('*')):
        if not path.is_file() or '.godot' in path.parts:
            continue
        digest.update(path.relative_to(GAME).as_posix().encode() + b'\0' + path.read_bytes())
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--portable', action='store_true')
    args = parser.parse_args()
    engine = os.environ.get('GODOT4_BIN', str(ROOT / '.tools/godot/Godot_v4.7.2-stable_linux.x86_64'))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for path in OUTPUT.glob('*.png'):
        path.unlink()
    report = {'timestamp_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
              'game_sha256': game_digest(), 'passed': False, 'incomplete': True, 'steps': [],
              'renderer': 'Compatibility', 'physical_gpu_benchmark': False}
    result = OUTPUT / 'result.json'
    result.write_text(json.dumps(report, indent=2)+'\n')
    base = [engine, '--path', str(GAME)]

    def run(name, command, marker=None, env=None):
        log_path = OUTPUT / (name+'.log')
        timed_out = False
        with log_path.open('w') as logfile:
            try:
                process = subprocess.run(command, stdout=logfile, stderr=subprocess.STDOUT,
                                         text=True, env=env, timeout=240)
                code = process.returncode
            except subprocess.TimeoutExpired:
                code = 124
                timed_out = True
        text = log_path.read_text()
        if timed_out:
            text += '\nCAPTURE_SUBPROCESS_TIMEOUT after 240 seconds\n'
            log_path.write_text(text)
        passed = code == 0 and 'ERROR:' not in text and 'leaked' not in text
        if marker:
            passed = passed and marker in text
        report['steps'].append({'name': name, 'passed': passed, 'exit_code': code})
        print(name, 'PASS' if passed else 'FAIL', flush=True)
        if not passed:
            detail=text[-6000:].replace('%','%25').replace('\r','%0D').replace('\n','%0A')
            print(f'::error title=Lantern {name}::{detail}',flush=True)
        return passed

    if run('import', base+['--headless', '--editor', '--import']):
        run('gameplay',base+['--headless','--audio-driver','Dummy','--fixed-fps','60',
                             '--script','res://tests.gd'], 'LANTERN_TEST_OK')
        render = base+['--audio-driver','Dummy','--fixed-fps','30','--resolution',
                       '960x540' if args.portable else '1280x720','--', '--capture-dir='+str(OUTPUT)]
        if args.portable:
            from portable_graphics import environment
            with environment() as env:
                rendered = run('render', render[:1]+['--display-driver','x11','--rendering-driver','opengl3_es']+render[1:], 'LANTERN_CAPTURE_OK', env)
        else:
            rendered = run('render',['xvfb-run','-a','-s','-screen 0 1280x720x24',*render], 'LANTERN_CAPTURE_OK')
        if rendered:
            capture = json.loads((OUTPUT / 'capture.json').read_text())
            valid = len(capture['images']) == 24
            expected = (960,540) if args.portable else (1280,720)
            for name in capture['images']:
                with Image.open(OUTPUT / (name+'.png')) as image:
                    valid = valid and image.size == expected and max(ImageStat.Stat(image.convert('RGB')).stddev)>15
            differences = {}
            for clean,overlay in [('02-village','03-village-collisions'),('05-lake','06-lake-collisions'),('05-farm','06-farm-collisions')]:
                a=Image.open(OUTPUT/(clean+'.png')).convert('RGB');b=Image.open(OUTPUT/(overlay+'.png')).convert('RGB')
                difference=sum(ImageStat.Stat(ImageChops.difference(a,b)).mean)/3.0
                valid = valid and difference>0.15
                differences[clean]=difference
            report['steps'].append({'name':'image-validation','passed':bool(valid),'overlay_mean_difference':differences})
    report['passed'] = len(report['steps'])==4 and all(s['passed'] for s in report['steps'])
    report['incomplete'] = False
    # Editor imports may add .import files on a clean checkout. Record final content identity.
    report['game_sha256'] = game_digest()
    result.write_text(json.dumps(report,indent=2)+'\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
