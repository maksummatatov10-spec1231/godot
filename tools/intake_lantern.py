"""Read the verified user archive; select CC0 Ninja Adventure PNGs for a separate game."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import tempfile
import zipfile
import gdown
import py7zr

ROOT = Path(__file__).resolve().parents[1]
FILE_ID = '1oYbF42doEsEK8kN6EVzFVdoZtz_TLZhr'
EXPECTED = 'cd56f13d4ceb33f0e90a1447a86ad8c5'


def main():
    outer = ROOT / '.tools/intake-2d/2d-assets.7z'
    outer.parent.mkdir(parents=True, exist_ok=True)
    if not outer.exists():
        if not gdown.download(id=FILE_ID, output=str(outer), quiet=False):
            raise RuntimeError('Drive download failed')
    if hashlib.md5(outer.read_bytes()).hexdigest() != EXPECTED:
        raise ValueError('Source hash mismatch')
    with tempfile.TemporaryDirectory() as temporary:
        with py7zr.SevenZipFile(outer) as archive:
            name = next(n for n in archive.getnames() if n.endswith('Ninja Adventure - Asset Pack.zip'))
            if '..' in PurePosixPath(name).parts:
                raise ValueError('Unsafe outer path')
            archive.extract(path=temporary, targets=[name])
        output = ROOT / 'lantern_game/assets/ninja'
        records = []
        selection_file = output.parent / "intake.json"
        selection = {r["path"] for r in json.loads(selection_file.read_text())["files"]} if selection_file.exists() else None
        with zipfile.ZipFile(Path(temporary, name)) as pack:
            names = pack.namelist()
            license_name = next(n for n in names if n.endswith('/LICENSE.txt'))
            if 'CC0 1.0 Universal' not in pack.read(license_name).decode():
                raise ValueError('Expected CC0 license absent')
            for item in pack.infolist():
                relative = PurePosixPath(item.filename).relative_to('Ninja Adventure - Asset Pack')
                if selection is not None and str(relative) not in selection:
                    continue
                if item.is_dir() or relative.suffix.lower() not in {'.png', '.txt', '.md'}:
                    continue
                if '..' in relative.parts or relative.is_absolute() or item.file_size > 2_000_000:
                    raise ValueError('Unsafe member')
                data = pack.read(item)
                path = output / str(relative)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
                records.append({'path': str(relative), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        output.parent.joinpath('intake.json').write_text(json.dumps({'source_drive_id': FILE_ID, 'source_md5': EXPECTED, 'license': 'CC0 1.0 Universal, included LICENSE.txt', 'files': records}, indent=2))
        print('NINJA_INTAKE_OK', len(records), sum(r['bytes'] for r in records))


if __name__ == '__main__':
    main()
