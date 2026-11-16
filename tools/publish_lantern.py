"""Publish only the full verified PC + Android set from one successful workflow."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from capture_lantern import ROOT, GAME, game_digest

OUT = ROOT / 'artifacts/lantern'


def main():
    run_id = os.environ['VALIDATION_RUN']
    if not run_id.isdigit():
        raise RuntimeError('Numeric validation run required')
    run = json.loads(subprocess.check_output(['gh', 'api', f'repos/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{run_id}'], text=True))
    if run['conclusion'] != 'success' or run['head_branch'] != 'arena/449f84de-godot' or run['path'] != '.github/workflows/lantern.yml':
        raise RuntimeError('Not a successful canonical same-branch validation run')
    digest = game_digest()
    build = json.loads((OUT / 'BUILD-VALIDATION.json').read_text())
    sources = json.loads((OUT / 'source-manifest.json').read_text())
    android = json.loads((ROOT / 'docs/evidence/lantern-platforms/android.json').read_text())
    if not build['passed'] or build['game_sha256'] != digest or sources['game_sha256'] != digest:
        raise RuntimeError('Current source does not match exported binaries/source ZIPs')
    if not android['passed'] or not android['native_os_touch'] or not android['lifecycle_save_resume']:
        raise RuntimeError('Android native input/lifecycle acceptance missing')
    # Match the smoke APK used by Android to this exact release's build metadata.
    smoke = OUT / 'Lantern-Valley-Android-Smoke.apk'
    if hashlib.sha256(smoke.read_bytes()).hexdigest() != build['apks'][smoke.name]['sha256']:
        raise RuntimeError('Android smoke binary mismatch')
    for row in sources['sources']:
        if hashlib.sha256((OUT / row['file']).read_bytes()).hexdigest() != row['sha256']:
            raise RuntimeError('Source ZIP hash mismatch')
    for name, row in build['apks'].items():
        if hashlib.sha256((OUT / name).read_bytes()).hexdigest() != row['sha256'] or not row['signature_verified']:
            raise RuntimeError('APK hash/signature proof mismatch')
    for line in (OUT / 'SHA256SUMS.txt').read_text().splitlines():
        sha, name = line.split('  ', 1)
        if hashlib.sha256((OUT / name).read_bytes()).hexdigest() != sha:
            raise RuntimeError('Asset checksum mismatch: ' + name)
    (OUT / 'ANDROID-VALIDATION.json').write_text(json.dumps(android, indent=2) + '\n')
    checksum = hashlib.sha256((OUT / 'ANDROID-VALIDATION.json').read_bytes()).hexdigest()
    with (OUT / 'SHA256SUMS.txt').open('a') as out:
        out.write(checksum + '  ANDROID-VALIDATION.json\n')
    version = re.search(r'config/version="([0-9.]+)"', (GAME / 'project.godot').read_text()).group(1)
    names = ['Lantern-Valley-PC-Project.zip', 'Lantern-Valley-Android-Project.zip',
             'Lantern-Valley-Android.apk', 'Lantern-Valley-PC-Windows-x64.zip',
             f'Lantern-Valley-{version}-Screenshots.zip', 'SHA256SUMS.txt',
             'BUILD-VALIDATION.json', 'ANDROID-VALIDATION.json']
    assets = [str(OUT / n) for n in names]
    for n in ['android-emulator-play.png', 'android-emulator-pause.png', '03-layout-editor.png']:
        assets.append(str(ROOT / 'docs/evidence/lantern-platforms' / n))
    subprocess.run(['gh', 'release', 'create', 'lantern-valley-v' + version, *assets,
                    '--target', subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                    '--title', 'Фонарщик — ПК и Android ' + version,
                    '--notes-file', str(ROOT / 'docs/releases' / f'lantern-valley-{version}.md'),
                    '--prerelease', '--draft'], check=True)
    release = json.loads(subprocess.check_output(['gh', 'release', 'view', 'lantern-valley-v' + version, '--json', 'assets,isDraft'], text=True))
    uploaded = {asset['name']: asset['size'] for asset in release['assets']}
    for asset in assets:
        path = Path(asset)
        if uploaded.get(path.name) != path.stat().st_size:
            raise RuntimeError('Draft upload incomplete: ' + path.name)
    subprocess.run(['gh', 'release', 'edit', 'lantern-valley-v' + version, '--draft=false'], check=True)
    print('LANTERN_RELEASE_PUBLISHED', version, digest)


if __name__ == '__main__':
    main()
