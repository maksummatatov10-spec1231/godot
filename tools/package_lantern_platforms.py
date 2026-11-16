"""Produce two explicit source profiles, never including signing credentials/binaries."""
import hashlib
import json
from pathlib import Path
import zipfile

ANDROID_OVERRIDE = '''; Android source-project preview. APK detects Android automatically.
[lantern]
platform="android"
[display]
window/size/window_width_override=1280
window/size/window_height_override=720
'''


def put(bundle, name, content):
    info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    bundle.writestr(info, content, compresslevel=9)


def build_platform_archive(source, output, profile, digest):
    if profile not in ('pc', 'android'):
        raise ValueError('Unknown platform')
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(output, 'w') as bundle:
        for name in sorted(original.namelist()):
            parts = Path(name).parts
            if '.godot' in parts or Path(name).suffix in ('.keystore', '.jks', '.apk', '.exe'):
                raise RuntimeError('Forbidden credential/build/cache in source archive: ' + name)
            if name.endswith('/override.cfg'):
                raise RuntimeError('Base source must not override the platform')
            put(bundle, name, original.read(name))
        if profile == 'android':
            put(bundle, 'LanternValley/override.cfg', ANDROID_OVERRIDE)
        manifest = dict(profile=profile, base_game_sha256=digest,
                        physical_pc_default=[1920, 1080], logical_viewport=[640, 360],
                        default_cap=60 if profile == 'android' else 75,
                        private_signing_key_included=False)
        put(bundle, 'LanternValley/PLATFORM.json', json.dumps(manifest, indent=2) + '\n')
        text = ('Android: F5 previews analog touch controls. Export preset: Android.\n'
                'The installable signed APK is a separate GitHub Release asset.\n'
                if profile == 'android' else
                'PC: open project.godot in Godot4.7.2, F5. Export preset: Windows Desktop.\n'
                'Default1920x1080, target75FPS. A target is not a hardware guarantee.\n')
        put(bundle, 'LanternValley/TARGET.txt', text)
    sha = hashlib.sha256(Path(output).read_bytes()).hexdigest()
    Path(str(output) + '.sha256').write_text(f'{sha}  {Path(output).name}\n')
    return dict(file=Path(output).name, bytes=Path(output).stat().st_size, sha256=sha, profile=profile)


def package_profiles(source, output, digest):
    rows = []
    for profile, name in [('pc', 'PC'), ('android', 'Android')]:
        target = output / f'Lantern-Valley-{name}-Project.zip'
        rows.append(build_platform_archive(source, target, profile, digest))
    (output / 'source-manifest.json').write_text(json.dumps(dict(game_sha256=digest, sources=rows), indent=2) + '\n')
    return rows
