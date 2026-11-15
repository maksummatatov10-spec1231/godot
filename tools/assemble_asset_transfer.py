#!/usr/bin/env python3
"""Verify downloaded Drive parts and assemble originals outside the repository.

Usage: python tools/assemble_asset_transfer.py MANIFEST PARTS_DIR OUTPUT_DIR
Download each manifest part through the connected Drive tool first. This script
uses only local files and has no credentials or network access.
"""
import hashlib
import json
from pathlib import Path
import sys

EXPECTED = {
    'assets.zip': (1264737618, 'cabff06b986e57683a45607690cfa18ce4803a455396e6e923a2c952ed0fff13'),
    'blender-5.3.0-linux-x64.tar.xz': (406944100, 'dacb8264197a3f7fda6001285a5a506fc97ee943881261c2c3bd63c882f22e05'),
}


def assemble(manifest, parts, output):
    repo = Path(__file__).resolve().parents[1]
    if output.resolve().is_relative_to(repo):
        raise ValueError('Archives must remain outside the repository')
    if manifest.get('format') != 'raw-concatenation-v1':
        raise ValueError('Unsupported manifest format')
    output.mkdir(parents=True, exist_ok=True)
    for source in manifest['sources']:
        name = source['name']
        if name not in EXPECTED or (source['size'], source['sha256']) != EXPECTED[name]:
            raise ValueError('Unexpected original archive')
        destination = output / name
        if destination.exists():
            with destination.open('rb') as stream:
                digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            if destination.stat().st_size != source['size'] or digest != source['sha256']:
                raise ValueError('Existing destination failed validation; not overwriting')
            print('Already verified:', name)
            continue
        temporary = destination.with_name(name + '.assembling')
        if temporary.exists():
            raise FileExistsError('An assembly temporary file already exists')
        try:
            total = 0
            whole = hashlib.sha256()
            with temporary.open('xb') as dst:
                for index, part in enumerate(source['parts'], 1):
                    if part['name'] != name + f'.part{index:03d}' or not 0 < part['size'] <= 90*1024**2:
                        raise ValueError('Unexpected part name or size')
                    path = parts / part['name']
                    digest = hashlib.sha256(); size = 0
                    with path.open('rb') as src:
                        for chunk in iter(lambda: src.read(1024**2), b''):
                            size += len(chunk)
                            if size > part['size']:
                                raise ValueError('Part exceeds expected size')
                            digest.update(chunk); whole.update(chunk); dst.write(chunk)
                    if size != part['size'] or digest.hexdigest() != part['sha256']:
                        raise ValueError('Part failed validation: ' + part['name'])
                    total += size
            if total != source['size'] or whole.hexdigest() != source['sha256']:
                raise ValueError('Original archive failed validation')
            temporary.rename(destination)
            print('Verified and assembled:', name)
        except Exception:
            temporary.unlink(missing_ok=True)
            raise


if __name__ == '__main__':
    manifest_path, parts_path, output_path = map(Path, sys.argv[1:])
    assemble(json.loads(manifest_path.read_text()), parts_path, output_path)
