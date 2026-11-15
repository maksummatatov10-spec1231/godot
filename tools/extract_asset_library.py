#!/usr/bin/env python3
"""Extract the user library outside the repository without running asset code."""
import argparse
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import zipfile

LIMIT = 10 * 1024**3
MAX_FILES = 100_000


def safe_target(root, name):
    if '\\' in name or '\x00' in name:
        raise ValueError(f'Ambiguous archive path: {name!r}')
    p = PurePosixPath(name)
    if p.is_absolute() or '..' in p.parts or ':' in name:
        raise ValueError(f'Unsafe archive path: {name!r}')
    target = root.joinpath(*p.parts)
    if not target.resolve().is_relative_to(root.resolve()):
        raise ValueError(f'Path escapes destination: {name!r}')
    return target


def extract_zip(archive, destination, budget):
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        targets = set()
        for info in z.infolist():
            target = safe_target(destination, info.filename)
            if target in targets:
                raise ValueError(f'Duplicate entry: {info.filename}')
            targets.add(target)
            mode = info.external_attr >> 16
            if stat.S_ISLNK(mode) or (stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR)):
                raise ValueError(f'Special entry: {info.filename}')
            if info.flag_bits & 1:
                raise ValueError(f'Encrypted entry: {info.filename}')
            budget['bytes'] += info.file_size
            budget['entries'] += 1
            if budget['bytes'] > LIMIT or budget['entries'] > MAX_FILES:
                raise ValueError('Extraction budget exceeded')
        for info in z.infolist():
            target = safe_target(destination, info.filename)
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with z.open(info) as src, target.open('xb') as dst:
                    shutil.copyfileobj(src, dst, 1024 * 1024)
                target.chmod(0o644)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    if args.destination.resolve().is_relative_to(repo):
        parser.error('The asset library must be outside the repository')
    if args.destination.exists() and any(args.destination.iterdir()):
        parser.error('Destination must be empty')
    budget = {'bytes': 0, 'entries': 0}
    queue = [(args.archive, args.destination, 0)]
    processed = []
    while queue:
        archive, dest, depth = queue.pop(0)
        if depth > 8:
            raise ValueError('Nested archive depth exceeded')
        print('EXTRACT', archive, flush=True)
        extract_zip(archive, dest, budget)
        processed.append(str(archive))
        for child in sorted(dest.rglob('*')):
            if child.is_file() and child.suffix.lower() == '.zip':
                queue.append((child, child.with_name(child.name + '.contents'), depth + 1))
    print(json.dumps(dict(budget, archives=processed), indent=2))


if __name__ == '__main__':
    main()
