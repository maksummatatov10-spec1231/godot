"""Package only the separate 2D project, gated by matching rendered evidence."""
import hashlib
import json
from pathlib import Path
import zipfile

from capture_lantern import GAME, ROOT, game_digest


def main():
    evidence = json.loads((ROOT/'docs/evidence/lantern/result.json').read_text())
    if not evidence.get('passed') or evidence.get('incomplete') or evidence['game_sha256'] != game_digest():
        raise RuntimeError('Missing, failed or stale village evidence; render the current game first')
    audit = json.loads((ROOT/'docs/evidence/lantern-audit/after/result.json').read_text())
    if not audit.get('passed') or audit['game_sha256'] != game_digest():
        raise RuntimeError('Full-map close-up audit is missing, failed or stale')
    motion = json.loads((ROOT/'docs/evidence/lantern-motion/result.json').read_text())
    if not motion.get('passed') or motion['game_sha256'] != game_digest():
        raise RuntimeError('Motion/isolated-shadow evidence is missing, failed or stale')
    output = ROOT/'artifacts/lantern'
    output.mkdir(parents=True,exist_ok=True)
    archive = output/'Lantern-Valley-Godot-Project.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as bundle:
        for path in sorted(GAME.rglob('*')):
            if path.is_file() and '.godot' not in path.parts:
                bundle.write(path,Path('LanternValley')/path.relative_to(GAME))
        bundle.writestr('LanternValley/AUDIT_VALIDATION.json',json.dumps(audit,indent=2)+'\n')
        bundle.writestr('LanternValley/MOTION_VALIDATION.json',json.dumps(motion,indent=2)+'\n')
        bundle.writestr('LanternValley/VALIDATION.json',json.dumps(evidence,indent=2)+'\n')
    sha = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.zip.sha256').write_text(f'{sha}  {archive.name}\n')
    print('LANTERN_PACKAGE_OK',archive,archive.stat().st_size,sha)


if __name__ == '__main__':
    main()
