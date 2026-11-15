"""Build for the current host and stage the library INSIDE res:// for exports."""
import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    if not shutil.which("cargo"):
        parser.error("cargo not found; install Rust 1.94.0 with rustup on the build host")
    system, machine = platform.system(), platform.machine().lower()
    if system not in {"Linux", "Windows", "Darwin"}:
        parser.error(f"unsupported host: {system}")
    if system != "Darwin" and machine not in {"x86_64", "amd64"}:
        parser.error("this fixture currently maps Linux/Windows x86_64 only")
    names = {"Linux": "libgame_native.so", "Windows": "game_native.dll",
             "Darwin": "libgame_native.dylib"}
    target = ROOT / "native" / "target"
    # Fixed destination avoids depending on the caller's Cargo target directory.
    env = dict(os.environ, CARGO_TARGET_DIR=str(target))
    command = ["cargo", "build", "--manifest-path", str(ROOT / "native/Cargo.toml")]
    if args.release:
        command.append("--release")
    subprocess.run(command, check=True, env=env, timeout=900)
    destination = ROOT / "godot/native"
    (destination / "bin").mkdir(parents=True, exist_ok=True)
    shutil.copy2(target / ("release" if args.release else "debug") / names[system],
                 destination / "bin" / names[system])
    # Enable only after a successful build: a clean GDScript-only checkout works.
    shutil.copy2(ROOT / "native/game_native.gdextension.in",
                 destination / "game_native.gdextension")
    print("Native library staged. Re-import the Godot project before running.")


if __name__ == "__main__":
    main()
