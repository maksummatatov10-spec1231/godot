"""Read-only intake for the user supplied 2D archive, never import into forest_game.
Run on CI where public Drive downloads are available. Do not redistribute the pack.
"""
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import tempfile
import zipfile

FILE_ID = '1oYbF42doEsEK8kN6EVzFVdoZtz_TLZhr'
EXPECTED_MD5 = 'cd56f13d4ceb33f0e90a1447a86ad8c5'
ROOT = Path(__file__).resolve().parents[1]


def inspect(archive_path, output):
    import py7zr
    digest = hashlib.md5(archive_path.read_bytes()).hexdigest()
    if digest != EXPECTED_MD5:
        raise ValueError('Drive archive MD5 differs from verified metadata')
    with py7zr.SevenZipFile(archive_path) as archive:
        entries = archive.list()
        files = [entry for entry in entries if not entry.is_directory]
        names = [entry.filename for entry in files]
        for name in names:
            posix = PurePosixPath(name.replace('\\', '/'))
            if posix.is_absolute() or '..' in posix.parts or ':' in name:
                raise ValueError('Unsafe archive path')
        license_names = [entry.filename for entry in files
                         if any(word in PurePosixPath(entry.filename).name.lower()
                                for word in ['license', 'licence', 'readme', 'copyright'])
                         and Path(entry.filename).suffix.lower() in {'.txt', '.md'}
                         and entry.uncompressed < 100_000][:30]
        texts = {}
        # Only small text metadata, no executables or game files are run.
        if license_names:
            archive.reset()
            with tempfile.TemporaryDirectory() as directory:
                archive.extract(path=directory, targets=license_names)
                for name in license_names:
                    p = Path(directory, name)
                    if p.is_file():
                        texts[name] = p.read_text(errors='replace')[:24000]
        packs = []
        with tempfile.TemporaryDirectory() as directory:
            archive.reset()
            archive.extract(path=directory, targets=names)
            for name in names:
                path = Path(directory, name)
                if path.suffix.lower() != '.zip':
                    packs.append({'archive': name, 'inspection': 'outer archive verified; nested non-ZIP retained for later tooling'})
                    continue
                with zipfile.ZipFile(path) as nested:
                    members = [e for e in nested.infolist() if not e.is_dir()]
                    licenses = {}
                    for entry in members:
                        title = PurePosixPath(entry.filename).name.lower()
                        if any(word in title for word in ['license', 'licence', 'readme', 'copyright', 'terms']) and Path(title).suffix in {'.txt', '.md'} and entry.file_size < 100_000:
                            licenses[entry.filename] = nested.read(entry).decode('utf-8', errors='replace')[:24000]
                    packs.append({'archive': name, 'inspection': 'nested ZIP directory and small license texts read; no asset code executed',
                                  'files': len(members), 'uncompressed_bytes': sum(e.file_size for e in members),
                                  'extensions': dict(Counter(Path(e.filename).suffix.lower() for e in members)),
                                  'license_texts': licenses,
                                  'sample_names': [e.filename for e in members[:30]]})
        result = {'drive_id': FILE_ID, 'name': '2d assets.7z',
                  'bytes': archive_path.stat().st_size, 'md5': digest,
                  'sha256': hashlib.sha256(archive_path.read_bytes()).hexdigest(),
                  'file_count': len(files), 'uncompressed_bytes': sum(e.uncompressed for e in files),
                  'extensions': dict(Counter(Path(n).suffix.lower() for n in names)),
                  'top_level': dict(Counter(PurePosixPath(n).parts[0] for n in names)),
                  'files': names, 'license_texts': texts, 'nested_packs': packs,
                  'scope': 'Separate 2D game intake only. No source assets redistributed or added to forest_game.'}
    output.mkdir(parents=True, exist_ok=True)
    (output / 'catalog.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    (output / 'README.md').write_text(
        '# Новый набор 2D — отдельная игра\n\n'
        f'Архив: `2d assets.7z`, {result["bytes"]:,} байт; {len(files):,} файлов.\n\n'
        'Оригинал остаётся на предоставленном Google Drive. В Git сохранён только каталог/лицензионные тексты, '
        'не исходный архив. С лесной игрой не смешивается. Содержимое не исполнялось.\n\n'
        'Перед распространением новой игры нужно проверить лицензии каждого выбранного набора, '
        'а не считать весь архив автоматически CC0. Подробнее: `catalog.json`.\n')
    print(json.dumps({k: result[k] for k in ['file_count', 'uncompressed_bytes', 'extensions', 'top_level']}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    import gdown
    location = ROOT / '.tools/intake-2d/2d-assets.7z'
    location.parent.mkdir(parents=True, exist_ok=True)
    if not location.exists():
        if not gdown.download(id=FILE_ID, output=str(location), quiet=False):
            raise RuntimeError('Public Drive download unavailable; metadata alone is not inspection')
    inspect(location, ROOT / 'docs/assets-2d')
