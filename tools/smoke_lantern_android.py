"""Install x86_64 smoke APK on a real Android emulator; test native OS input/lifecycle.

ARM release APK is separately signature/manifest checked. This is not a physical phone
performance test, nor a claim that emulator frame rate represents mobile hardware.
"""
import json
from pathlib import Path
import subprocess
import time
from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/lantern-platforms'
PACKAGE = 'org.lanternvalley.game.smoke'


def adb(*args, binary=False):
    return subprocess.check_output(['adb', *map(str, args)], timeout=120, text=not binary)


def logs():
    # Early-boot logd can close a dump while rotating buffers; retain partial
    # diagnostics, then retry. Missing markers/transport still fail the deadline.
    result = subprocess.run(['adb', 'logcat', '-d', '-b', 'main', '-b', 'crash',
                             '-v', 'brief'], timeout=30, capture_output=True, text=True)
    if result.returncode:
        with (OUT / 'android-adb.log').open('a') as out:
            out.write(f'logcat exit {result.returncode}: {result.stderr}\n')
            out.write(result.stdout[-2000:] + '\n')
        return ''
    return result.stdout


def wait_for(marker, timeout=100):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        text = logs()
        (OUT / 'android-logcat.log').write_text(text)
        if any(marker in text for marker in ['LANTERN_ANDROID_SMOKE_FAIL', 'PLATFORM_FAIL',
                                                'FATAL EXCEPTION', 'E/godot', 'SCRIPT ERROR:']):
            raise RuntimeError('Android runtime failure:\n' + text[-10000:])
        if marker in text:
            return text
        time.sleep(0.5)
    raise RuntimeError('Android timeout: ' + marker)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'android.json').write_text(json.dumps({'passed': False}) + '\n')
    adb('install', '-r', ROOT / 'artifacts/lantern/Lantern-Valley-Android-Smoke.apk')
    # The first-launch Android full-screen tutorial consumes Back before the app.
    # Acknowledge this OS tutorial in the test fixture, not in game code.
    adb('shell', 'settings', 'put', 'secure', 'immersive_mode_confirmations', 'confirmed')
    adb('logcat', '-c')
    adb('shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')
    text = wait_for('LANTERN_ANDROID_SMOKE_OK')
    result = json.loads(next(line.split('LANTERN_ANDROID_SMOKE_RESULT', 1)[1].strip()
                             for line in text.splitlines() if 'LANTERN_ANDROID_SMOKE_RESULT' in line))
    if result['failed'] or not result['android_runtime']:
        raise RuntimeError(result)
    x, y = map(round, result['stick_screen'])
    travel = round(result['screen_travel'])
    adb('shell', 'input', 'touchscreen', 'swipe', x, y, x + travel, y, '1000')
    wait_for('LANTERN_ANDROID_OS_TOUCH_OK', 30)
    windows = adb('shell', 'dumpsys', 'window', 'windows')
    (OUT / 'android-window.log').write_text(windows)
    focus = next((line for line in windows.splitlines() if 'mCurrentFocus=' in line), '')
    if PACKAGE not in focus or 'ImmersiveModeConfirmation' in focus:
        raise RuntimeError('Android OS overlay prevents app input; inspect android-window.log')
    (OUT / 'android-emulator-play.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
    adb('shell', 'input', 'keyevent', '4')
    wait_for('LANTERN_ANDROID_MODE pause', 15)
    (OUT / 'android-emulator-pause.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
    # Resume with Android Back, then background/restore. App must pause and save.
    adb('shell', 'input', 'keyevent', '4')
    time.sleep(0.5)
    adb('shell', 'input', 'keyevent', '3')
    time.sleep(1)
    adb('shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')
    wait_for('LANTERN_ANDROID_RESUME_SAVE_OK', 30)
    adb('shell', 'input', 'keyevent', '4')
    time.sleep(0.5)
    (OUT / 'android-emulator-restored.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
    dimensions = []
    for name in ['play', 'pause', 'restored']:
        with Image.open(OUT / ('android-emulator-' + name + '.png')) as im:
            if max(ImageStat.Stat(im.convert('RGB')).stddev) < 12:
                raise RuntimeError('Android output is blank: ' + name)
            if im.width <= im.height:
                raise RuntimeError('Android output is not landscape')
            dimensions.append(list(im.size))
    result.update(passed=True, native_os_touch=True, android_back_pause=True,
                  lifecycle_save_resume=True, physical_device_tested=False,
                  emulator_abi='x86_64', screenshots=dimensions,
                  arm_apk_runtime_tested=False)
    (OUT / 'android.json').write_text(json.dumps(result, indent=2) + '\n')
    print('LANTERN_ANDROID_ACCEPTED', json.dumps(result))


if __name__ == '__main__':
    main()
