"""Export release apps, verify Android signatures/manifests, package Windows x64.

Requires CI-provisioned Godot templates, Java17, Android SDK35 and private environment
keystore paths. Does not write credentials to export_presets.cfg or release assets.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile
from capture_lantern import ROOT, GAME, game_digest

OUTPUT = ROOT / 'artifacts/lantern'
EVIDENCE = ROOT / 'docs/evidence/lantern-platforms'


def command(args, log):
    result = subprocess.run([str(a) for a in args], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=300)
    (EVIDENCE / log).write_text(result.stdout)
    if result.returncode or 'ERROR:' in result.stdout:
        raise RuntimeError(log + '\n' + result.stdout[-6000:])
    return result.stdout


def main():
    digest = game_digest()
    for name in ['lantern', 'lantern-audit/after', 'lantern-motion', 'lantern-beauty',
                 'lantern-performance', 'lantern-contact', 'lantern-foundation',
                 'lantern-celestial', 'lantern-platforms']:
        report = json.loads((ROOT / 'docs/evidence' / name / 'result.json').read_text())
        if not report.get('passed') or report['game_sha256'] != digest:
            raise RuntimeError('Refuse application export with stale/failed evidence: ' + name)
    engine = os.environ['GODOT4_BIN']
    base = [engine, '--headless', '--path', GAME, '--audio-driver', 'Dummy']
    command(base + ['--editor', '--import', '--quit'], 'apps-import.log')
    for preset, name in [('Windows Desktop', 'Lantern-Valley-PC.exe'),
                         ('Android', 'Lantern-Valley-Android.apk'),
                         ('Android Smoke', 'Lantern-Valley-Android-Smoke.apk')]:
        command(base + ['--export-release', preset, OUTPUT / name], 'export-' + name + '.log')
        if not (OUTPUT / name).is_file() or (OUTPUT / name).stat().st_size < 1_000_000:
            raise RuntimeError('Export produced no usable binary: ' + name)
    sdk = Path(os.environ.get('ANDROID_HOME', os.environ.get('ANDROID_SDK_ROOT', '')))
    tools = sdk / 'build-tools/35.0.1'
    apks = {}
    for name, package, abis in [('Lantern-Valley-Android.apk', 'org.lanternvalley.game', {'arm64-v8a', 'armeabi-v7a'}),
                                ('Lantern-Valley-Android-Smoke.apk', 'org.lanternvalley.game.smoke', {'x86_64'})]:
        path = OUTPUT / name
        signature = command([tools / 'apksigner', 'verify', '--verbose', '--print-certs', path], name + '-signature.log')
        manifest = command([tools / 'aapt', 'dump', 'badging', path], name + '-manifest.log')
        if "package: name='" + package + "'" not in manifest:
            raise RuntimeError('Wrong Android package')
        if 'application-debuggable' in manifest or 'android.permission.INTERNET' in manifest:
            raise RuntimeError('Unexpected debug/network capability in release APK')
        with zipfile.ZipFile(path) as z:
            actual = {n.split('/')[1] for n in z.namelist() if n.startswith('lib/') and n.endswith('.so')}
            if actual != abis:
                raise RuntimeError('Wrong native ABI set: ' + str(actual))
        apks[name] = dict(bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                          package=package, abis=sorted(abis), signature_verified=True,
                          signing_certificate_sha256=next(line.split(': ', 1)[1] for line in signature.splitlines()
                                                         if 'certificate SHA-256 digest:' in line))
    with zipfile.ZipFile(OUTPUT / 'Lantern-Valley-PC-Windows-x64.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(OUTPUT / 'Lantern-Valley-PC.exe', 'Lantern-Valley.exe')
        z.write(GAME / 'README.md', 'README.md')
        z.write(GAME / 'CREDITS.md', 'CREDITS.md')
    if game_digest() != digest:
        raise RuntimeError('Export unexpectedly modified verified source')
    report = dict(passed=True, game_sha256=digest, apks=apks, native_windows_tested=False,
                  signing='private configured key or cached non-production preview key; no private key distributed')
    (EVIDENCE / 'build.json').write_text(json.dumps(report, indent=2) + '\n')
    (OUTPUT / 'BUILD-VALIDATION.json').write_text(json.dumps(report, indent=2) + '\n')
    names = ['Lantern-Valley-PC-Project.zip', 'Lantern-Valley-Android-Project.zip',
             'Lantern-Valley-PC-Windows-x64.zip', 'Lantern-Valley-Android.apk',
             'Lantern-Valley-0.4.0-Screenshots.zip', 'BUILD-VALIDATION.json']
    hashes = [hashlib.sha256((OUTPUT / n).read_bytes()).hexdigest() + '  ' + n for n in names]
    (OUTPUT / 'SHA256SUMS.txt').write_text('\n'.join(hashes) + '\n')
    print('LANTERN_APPLICATIONS_BUILT', json.dumps(report))


if __name__ == '__main__':
    main()
