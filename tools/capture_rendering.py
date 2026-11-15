"""Capture real Forward+ frames and preserve diagnostics, including failed runs.

Run on Linux with Xvfb + Mesa lavapipe, or a machine with a real GPU/display.
Unlike --headless, Xvfb provides a presentation surface. Software Vulkan is
for correctness/visual inspection only, never hardware performance claims.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from check import ERRORS, ROOT, resolve_engine, validate_capture
from project_setup import prepare_extensions

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'artifacts/forward-plus')
    parser.add_argument('--timeout', type=int, default=240)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    engine = resolve_engine()
    if not engine:
        raise RuntimeError('Godot 4.7.2 is required')
    prepare_extensions(ROOT / 'godot')
    base = [engine, '--path', str(ROOT / 'godot')]
    report = {'timestamp_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'],
                                                        cwd=ROOT, text=True).strip(),
              'runner': os.environ.get('GITHUB_ACTIONS', 'local'),
              'renderer': 'forward_plus',
              'software_rendering': bool(os.environ.get('VK_ICD_FILENAMES', '').find('lvp') >= 0),
              'purpose': 'Frame correctness, not hardware performance', 'steps': []}

    def run(name, command, marker=None, image=None):
        if image:
            image.unlink(missing_ok=True)
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=args.timeout)
            text, code = result.stdout, result.returncode
        except subprocess.TimeoutExpired as error:
            text = error.stdout or b''
            if isinstance(text, bytes):
                text = text.decode(errors='replace')
            code = 124
        text = ANSI.sub('', text)
        (output / f'{name}.log').write_text(text)
        passed = code == 0 and not ERRORS.search(text) and 'SHADER ERROR:' not in text
        if marker:
            passed = passed and marker in text
        details = {'name': name, 'exit_code': code, 'passed': passed}
        if image and 'Forward+ - Using Device' not in text:
            details['renderer_error'] = 'Forward+ was not confirmed by the actual device log'
            details['passed'] = False
        if image and image.exists():
            try:
                validate_capture(image)
                details['image'] = image.name
            except (OSError, RuntimeError) as error:
                details['image_error'] = str(error)
                passed = False
                details['passed'] = False
        elif image:
            details['image_error'] = 'No fresh screenshot was produced'
            details['passed'] = False
        report['steps'].append(details)
        print(name, 'PASS' if details['passed'] else 'FAIL', flush=True)
        return details['passed']

    run('import', base + ['--headless', '--editor', '--import'])
    run('plugins', base + ['--headless', '--script', 'res://tests/plugin_smoke.gd'],
        'PLUGIN_SMOKE_OK')
    prefix = []
    if sys.platform.startswith('linux') and not os.environ.get('DISPLAY'):
        xvfb = shutil.which('xvfb-run')
        if not xvfb:
            raise RuntimeError('Install xvfb and xauth: headless cannot render frames')
        prefix = [xvfb, '-a', '-s', '-screen 0 960x540x24']
    gpu = prefix + base + ['--rendering-method', 'forward_plus', '--audio-driver', 'Dummy',
                           '--resolution', '960x540']
    for name, scene, marker, user_args in [
        ('lab', 'res://scenes/lab.tscn', 'SMOKE_OK', ['--smoke']),
        ('terrain-only', 'res://scenes/rendering_validation.tscn',
         'RENDER_VALIDATION_OK', ['--without-clouds']),
        ('clouds-only', 'res://scenes/rendering_validation.tscn',
         'RENDER_VALIDATION_OK', ['--without-terrain']),
        ('terrain-clouds', 'res://scenes/rendering_validation.tscn',
         'RENDER_VALIDATION_OK', []),
    ]:
        image = output / f'{name}.png'
        success = run(name, gpu + [scene, '--', *user_args, f'--capture={image}'], marker, image)
        if name == 'terrain-clouds' and not success and shutil.which('gdb'):
            run('terrain-clouds-backtrace', prefix + [shutil.which('gdb'), '--batch',
                '--return-child-result', '-ex', 'run', '-ex', 'thread apply all bt 8',
                '--args', *base, '--disable-crash-handler', '--rendering-method',
                'forward_plus', '--audio-driver', 'Dummy', '--resolution', '960x540',
                scene, '--', f'--capture={image}'])
    editor_prefix = prefix
    if prefix:
        editor_prefix = [prefix[0], '-a', '-s', '-screen 0 1280x800x24']
    run('editor', editor_prefix + [sys.executable, str(ROOT / 'tools/capture_editor.py'),
                                  '--output', str(output / 'editor.png')],
        'EDITOR_CAPTURE_OK')
    report['passed'] = all(step['passed'] for step in report['steps'])
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
