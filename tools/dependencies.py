"""Small pinned-download helpers. Never extract archive paths outside their destination."""
import base64
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".tools/downloads"


def fetch(source):
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = CACHE / source["sha256"]
    if cached.exists():
        data = cached.read_bytes()
        if hashlib.sha256(data).hexdigest() == source["sha256"]:
            return data
    url = source["url"]
    if source.get("kind") == "github_file":
        response = subprocess.check_output(["gh", "api", url], timeout=60)
        data = base64.b64decode(json.loads(response)["content"], validate=False)
    else:
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read(120_000_001)
        if len(data) > 120_000_000:
            raise RuntimeError("dependency download exceeds size limit")
    if hashlib.sha256(data).hexdigest() != source["sha256"]:
        raise RuntimeError(f"SHA-256 mismatch: {url}")
    cached.write_bytes(data)
    return data


def extract(data, destination, strip_root=True):
    destination = Path(destination)
    total = 0
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as archive:
        for member in archive:
            parts = PurePosixPath(member.name).parts
            if member.name.startswith("/") or ".." in parts:
                raise RuntimeError("unsafe archive path")
            parts = parts[1:] if strip_root else parts
            if not parts:
                continue
            if member.issym() or member.islnk():
                raise RuntimeError("archive links are not allowed")
            target = destination.joinpath(*parts)
            if not target.resolve().is_relative_to(destination.resolve()):
                raise RuntimeError("archive path escapes through an existing symlink")
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                total += member.size
                if total > 250_000_000:
                    raise RuntimeError("extracted archive exceeds size limit")
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as src, target.open("wb") as dst:
                    shutil.copyfileobj(src, dst)
                target.chmod(0o755 if member.mode & 0o111 else 0o644)
            else:
                raise RuntimeError("archive special files are not allowed")
