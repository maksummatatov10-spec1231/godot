"""Inventory the separate user-supplied 2D pack; never import or run its assets."""
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import tempfile

FILE_ID = '1oYbF42doEsEK8kN6EVzFVdoZtz_TLZhr'
EXPECTED_MD5 = 'cd56f13d4ceb33f0e90a1447a86ad8c5'
ROOT = Path(__file__).resolve().parents[1]
MAX_TEXT = 100_000
MAX_TOTAL = 2_000_000_000


def safe_name(name):
    path = PurePosixPath(name.replace('\\', '/'))
    if path.is_absolute() or '..' in path.parts or ':' in name:
        raise ValueError('Unsafe archive path: ' + name)
    return name


def inventory(path):
    """Read directory, image dimensions and bounded plain texts, no asset extraction."""
    import libarchive
    from PIL import Image
    import io
    members, texts, dimensions = [], {}, Counter()
    total = 0
    # libarchive streams ZIP / 7z / RAR, avoiding archive-controlled disk paths.
    with libarchive.file_reader(str(path)) as archive:
        for entry in archive:
            name = safe_name(entry.pathname)
            if not entry.isfile:
                continue
            size = entry.size
            total += size
            if size < 0 or total > MAX_TOTAL or len(members) >= 100_000:
                raise ValueError('Nested archive exceeds intake limits')
            members.append({'name': name, 'bytes': size})
            extension = Path(name).suffix.lower()
            is_text = extension in {'.txt', '.md'} and size < MAX_TEXT
            is_image = extension == '.png' and len(dimensions) < 100
            if not (is_text or is_image) or size > 4_000_000:
                continue
            # Only inspect PNG header bytes, not whole image data or pixels.
            data = bytearray()
            for block in entry.get_blocks():
                data.extend(block)
                if is_image and len(data) >= 64:
                    break
                if len(data) > MAX_TEXT:
                    break
            if is_text:
                texts[name] = data.decode('utf-8', errors='replace')[:24000]
            elif is_image:
                try:
                    with Image.open(io.BytesIO(data)) as image:
                        dimensions[f'{image.width}x{image.height}'] += 1
                except (OSError, ValueError):
                    pass
    return {'archive': path.name, 'inspection': 'streamed directory, bounded plain texts and PNG headers; no code executed',
            'files': len(members), 'uncompressed_bytes': total,
            'extensions': dict(Counter(Path(e['name']).suffix.lower() for e in members)),
            'png_dimensions_sample': dict(dimensions), 'plain_texts': texts,
            'sample_names': [e['name'] for e in members[:30]]}


def inspect(archive_path, output):
    import py7zr
    digest = hashlib.md5(archive_path.read_bytes()).hexdigest()
    if digest != EXPECTED_MD5:
        raise ValueError('Drive archive MD5 differs from verified metadata')
    with py7zr.SevenZipFile(archive_path) as archive:
        files = [e for e in archive.list() if not e.is_directory]
        names = [safe_name(e.filename) for e in files]
        if sum(e.uncompressed for e in files) > MAX_TOTAL:
            raise ValueError('Outer archive exceeds intake limits')
        packs = []
        with tempfile.TemporaryDirectory() as directory:
            # Verified outer archive has only regular archives; reject all links.
            if any(e.is_symlink for e in files):
                raise ValueError('Outer symlink rejected')
            archive.extract(path=directory, targets=names)
            for name in names:
                path = Path(directory, name)
                if path.suffix.lower() not in {'.zip', '.7z', '.rar'}:
                    raise ValueError('Unexpected outer member: ' + name)
                item = inventory(path)
                item['archive'] = name
                packs.append(item)
        result = {'drive_id': FILE_ID, 'name': '2d assets.7z',
                  'bytes': archive_path.stat().st_size, 'md5': digest,
                  'sha256': hashlib.sha256(archive_path.read_bytes()).hexdigest(),
                  'file_count': len(files), 'uncompressed_bytes': sum(e.uncompressed for e in files),
                  'extensions': dict(Counter(Path(n).suffix.lower() for n in names)),
                  'files': names, 'nested_packs': packs,
                  'scope': 'Separate 2D game intake only. No source assets redistributed or added to forest_game.'}
    output.mkdir(parents=True, exist_ok=True)
    (output / 'catalog.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    rows = '\n'.join(f'| {Path(p["archive"]).name} | {p["files"]:,} | ' +
                     ', '.join(f'{k or "(none)"}: {v}' for k, v in p['extensions'].items()) + ' |'
                     for p in packs)
    (output / 'README.md').write_text(
        '# 2D assets — отдельная будущая игра\n\n'
        f'Скачан и проверен MD5 исходного архива ({result["bytes"]:,} байт). '
        f'Внутри {len(files)} архивов ZIP/7z/RAR; прочитаны их каталоги, небольшие тексты и заголовки PNG. '
        'Это инвентаризация, не просмотр каждого спрайта и не подтверждение лицензий по названию. '
        'Исходные ассеты не исполнялись, не добавлены в лесную игру и не переопубликованы.\n\n'
        '| Набор | Файлов внутри | Расширения |\n|---|---:|---|\n' + rows + '\n\n'
        '## Лицензии — не все наборы CC0\n\n'
        '- **Ninja Adventure**: вложенный LICENSE/README указывает CC0.\n'
        '- **Super Pixel Effects Gigapack**: разрешены коммерческие игры, требуется указание Will Tice / unTied Games; запрещены отдельная перепубликация, некоторые сценарии tools/engines и AI training. Полная внешняя лицензия по ссылке внутри текста ещё требует проверки.\n'
        '- **Pixel Crawler**: коммерческие проекты разрешены, отдельная продажа ассетов запрещена; это не CC0.\n'
        '- **SuperRetroRanch FreeTier**: только некоммерческие проекты, запрещена отдельная раздача; вложенная лицензия также запрещает NFT/metaverse/IA-проекты. Несмотря на папку `sounds`, каталог содержит в основном JPG и шрифты, не звуковую библиотеку.\n'
        '- Для остальных выбранных наборов нужно отдельно подтвердить условия из вложенных текстов/страниц авторов. Отсутствие LICENSE не означает разрешение.\n\n'
        'Полные найденные небольшие тексты, количество файлов, образцы имён и размеры PNG — в `catalog.json`. '
        'Жанр, управление и объём новой игры ещё не выбраны.\n')
    print(json.dumps({'nested_archives': len(packs), 'nested_files': sum(p['files'] for p in packs)}, indent=2))


if __name__ == '__main__':
    import gdown
    location = ROOT / '.tools/intake-2d/2d-assets.7z'
    location.parent.mkdir(parents=True, exist_ok=True)
    if not location.exists():
        if not gdown.download(id=FILE_ID, output=str(location), quiet=False):
            raise RuntimeError('Public Drive download unavailable; metadata alone is not inspection')
    inspect(location, ROOT / 'docs/assets-2d')
