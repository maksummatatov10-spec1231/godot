"""Private Linux fallback for this restricted sandbox; normal hosts should use current Xvfb/Mesa.

Downloads pinned legacy diagnostic libraries into .tools only. No system library replacement.
See docs/GRAPHICS.md before use. Needs gcc, gh, Brotli and an existing libz.so.1.
"""
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import sys

from dependencies import ROOT, extract, fetch

DEST = ROOT / ".tools/graphics/portable"


def main():
    if not sys.platform.startswith("linux"):
        raise RuntimeError("portable backend is Linux-only")
    import brotli
    sources = json.loads((ROOT / "tools/graphics/sources.json").read_text())
    DEST.mkdir(parents=True, exist_ok=True)
    source_root = DEST / "sources"
    for name in ["xvfb", "fontenc", "xkeyboard", "zlib", "egl_headers"]:
        print(f"Preparing {name}", flush=True)
        extract(fetch(sources[name]), source_root / name)
    extract((source_root / "fontenc/libfontenc-1.1.1.tar.bz2").read_bytes(),
            source_root / "fontenc-build")
    # Extract just the graphics payload, not Chromium itself.
    with tarfile.open(fileobj=io.BytesIO(fetch(sources["angle"]))) as archive:
        compressed = archive.extractfile("package/bin/swiftshader.tar.br").read()
    extract(brotli.decompress(compressed), DEST / "angle", strip_root=False)
    lib = DEST / "lib"
    lib.mkdir(exist_ok=True)
    for name, source in sources.items():
        if source["kind"] != "github_file":
            continue
        output = DEST / name if name == "xkbcomp" else lib / name
        output.write_bytes(fetch(source))
        output.chmod(0o755 if name == "xkbcomp" else 0o644)
    shutil.copy2(source_root / "xvfb/Xvfb.64bit", DEST / "Xvfb")
    (DEST / "Xvfb").chmod(0o755)
    subprocess.run(["gcc", "-shared", "-fPIC", "-O2",
                    f"-I{source_root / 'fontenc-build/include'}", f"-I{source_root / 'zlib'}",
                    '-DFONT_ENCODINGS_DIRECTORY="/usr/share/fonts/X11/encodings/encodings.dir"',
                    str(source_root / "fontenc-build/src/fontenc.c"),
                    str(source_root / "fontenc-build/src/encparse.c"),
                    "-Wl,-soname,libfontenc.so.1", "-l:libz.so.1", "-o", str(lib / "libfontenc.so.1")],
                   check=True, timeout=60)
    egl = DEST / "egl"
    egl.mkdir(exist_ok=True)
    subprocess.run(["gcc", "-shared", "-fPIC", "-O2", "-DEGL_NO_PLATFORM_SPECIFIC_TYPES",
                    f"-I{source_root / 'egl_headers/api'}", str(ROOT / "tools/graphics/egl_pbuffer.c"),
                    "-ldl", "-o", str(egl / "libEGL.so.1")], check=True, timeout=60)
    rules = source_root / "xkeyboard/rules/base"
    rules.write_text("! model = keycodes\n  * = xfree86\n! model = types\n  * = complete\n"
                     "! model = compat\n  * = complete\n! layout = symbols\n  * = pc+us\n"
                     "! model = geometry\n  * = pc(pc105)\n")
    (DEST / "ready.json").write_text(json.dumps({"width": 960, "height": 540}))
    print("Portable graphics prepared. This is a fixed-size, offscreen diagnostic backend.")


if __name__ == "__main__":
    main()
