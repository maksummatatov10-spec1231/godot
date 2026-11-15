"""Capture the actual Godot editor window from an X11 display, not a mockup."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import time

from PIL import ImageGrab, ImageStat

from check import ROOT, resolve_engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--settle-seconds', type=float, default=20)
    args = parser.parse_args()
    if not os.environ.get('DISPLAY'):
        raise RuntimeError('Use xvfb-run or an actual X11 display for the editor capture')
    engine = resolve_engine()
    if not engine:
        raise RuntimeError('Godot 4.7.2 is required')
    destination = args.output.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.unlink(missing_ok=True)
    log_path = destination.with_suffix('.engine.log')
    with log_path.open('w') as log:
        process = subprocess.Popen(
            [engine, '--path', str(ROOT / 'godot'), '--editor',
             '--rendering-method', 'forward_plus', '--audio-driver', 'Dummy',
             '--resolution', '1280x800', '--position', '0,0'],
            cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            try:
                process.wait(timeout=args.settle_seconds)
            except subprocess.TimeoutExpired:
                pass  # The editor must remain open for the capture.
            if process.poll() is not None:
                raise RuntimeError(f'Editor exited before capture: {process.returncode}')
            image = ImageGrab.grab(xdisplay=os.environ['DISPLAY'])
            if image.width < 960 or image.height < 540:
                raise RuntimeError(f'Unexpected display size: {image.size}')
            if max(ImageStat.Stat(image.convert('RGB')).stddev) < 5:
                raise RuntimeError('Editor screenshot is blank')
            image.save(destination)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
    text = log_path.read_text()
    if 'Forward+ - Using Device' not in text:
        raise RuntimeError('Editor did not confirm Forward+ in its device log')
    print('EDITOR_CAPTURE_OK', destination)


if __name__ == '__main__':
    main()
