"""Make a cache-free, self-contained Godot project ZIP for a GitHub release."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def package(output: Path):
    source = ROOT / 'forest_game'
    files = sorted(path for path in source.rglob('*')
                   if path.is_file() and '.godot' not in path.parts
                   and '__pycache__' not in path.parts and not path.name.endswith('.tmp'))
    manifest = {'project': 'WARDEN — The Emerald Wild',
                'engine': 'Godot 4.7.2 Standard / Forward+',
                'repository_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'files': [{'path': path.relative_to(source).as_posix(), 'bytes': path.stat().st_size,
                           'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in files]}
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            archive.write(path, 'WardenForest/' + path.relative_to(source).as_posix())
        archive.writestr('WardenForest/BUILD_MANIFEST.json', json.dumps(manifest, ensure_ascii=False, indent=2))
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise RuntimeError('Corrupt ZIP member')
        if 'WardenForest/project.godot' not in archive.namelist():
            raise RuntimeError('No actual Godot project in ZIP')
        if any('/.godot/' in path for path in archive.namelist()):
            raise RuntimeError('Do not ship machine-specific importer cache')
    sha = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(output.suffix + '.sha256').write_text(sha + '  ' + output.name + '\n')
    print(json.dumps({'zip': str(output), 'bytes': output.stat().st_size,
                      'files': len(files), 'sha256': sha}, indent=2))
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / '.tools/releases/Warden-Forest-Godot-Project.zip')
    args = parser.parse_args()
    package(args.output.resolve())
