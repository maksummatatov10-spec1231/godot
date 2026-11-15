"""Build the Linux x86_64 native alternative to Rust, using official pinned godot-cpp."""
import argparse
from pathlib import Path
import os
import platform
import shutil
import subprocess
import sys

from dependencies import extract, fetch

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "507ed9d840c01a3c5b2a39af8bb4000bfac30bf5"  # 10.0.0-stable
SOURCE = {
    "url": f"https://codeload.github.com/godotengine/godot-cpp/tar.gz/{COMMIT}",
    "sha256": "30da4ac295997061a6af81ae531510efd4e6a86e506eb4466edc0898ef3fe048",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, choices=range(1, 9), default=2)
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        parser.error("this build script currently supports Linux x86_64 only")
    if not shutil.which("g++"):
        parser.error("g++ is missing")
    import SCons  # noqa: F401 -- fail before downloading if tooling is missing.
    destination = ROOT / ".tools/cpp" / f"godot-cpp-{COMMIT}"
    marker = destination / ".verified-source"
    if not marker.exists() or marker.read_text() != SOURCE["sha256"]:
        # Do not trust an arbitrary directory merely because SConstruct exists.
        extract(fetch(SOURCE), destination)
        (destination / ".verified-source").write_text(SOURCE["sha256"])
    env = dict(os.environ, GODOT_CPP_DIR=str(destination))
    target = "template_debug" if args.debug else "template_release"
    subprocess.run([sys.executable, "-m", "SCons", "-C", str(ROOT / "cpp"),
                    "platform=linux", f"target={target}",
                    f"build_profile={ROOT / 'cpp/build_profile.json'}", f"-j{args.jobs}"],
                   check=True, env=env, timeout=900)
    # Enable only after successful linking.
    shutil.copy2(ROOT / "cpp/game_cpp.gdextension.in",
                 ROOT / "godot/native_cpp/game_cpp.gdextension")
    from project_setup import prepare_extensions
    prepare_extensions(ROOT / "godot")
    print("C++ GDExtension built; run tools/check.py smoke --require-cpp")


if __name__ == "__main__":
    main()
