"""Bounded checks. Missing runtimes fail explicitly, never silently pass."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"
ERRORS = re.compile(r"SCRIPT ERROR:|(?:^|\n)\s*ERROR:|Parse Error:")


def resolve_engine():
    configured = os.environ.get("GODOT4_BIN")
    if configured:
        return shutil.which(configured)
    installed = shutil.which("godot4") or shutil.which("godot")
    if installed:
        return installed
    if sys.platform.startswith("linux"):
        tag = (ROOT / ".godot-version").read_text().strip()
        local = ROOT / ".tools/godot" / f"Godot_v{tag}_linux.x86_64"
        if local.is_file() and os.access(local, os.X_OK):
            return str(local)
    return None


def run_step(name, command, timeout=120, env=None):
    ARTIFACTS.mkdir(exist_ok=True)
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout, check=False, env=env)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        (ARTIFACTS / f"{name}.log").write_text(output, encoding="utf-8")
        raise RuntimeError(f"{name}: timed out after {timeout}s") from error
    (ARTIFACTS / f"{name}.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode or ERRORS.search(result.stdout):
        raise RuntimeError(f"{name}: failed; see artifacts/{name}.log")
    return result.stdout


def engine_matches(output, tag):
    # Godot --version prints 4.7.2.stable.official.<hash>, unlike release tag.
    return output.strip().startswith(tag.replace("-stable", ".stable") + ".")


def validate_capture(path):
    from PIL import Image, ImageStat
    with Image.open(path) as image:
        image.load()
        if image.format != "PNG" or image.size != (960, 540):
            raise RuntimeError(f"unexpected capture format/size: {image.format}, {image.size}")
        if max(ImageStat.Stat(image.convert("RGB")).stddev) < 5:
            raise RuntimeError("capture appears blank or nearly uniform")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["doctor", "smoke", "visual"])
    parser.add_argument("--require-rust", action="store_true")
    parser.add_argument("--require-cpp", action="store_true")
    parser.add_argument("--test-input", action="store_true",
                        help="exercise the right-movement action before capture")
    parser.add_argument("--portable-graphics", action="store_true",
                        help="Linux-only isolated ANGLE pbuffer diagnostic backend")
    parser.add_argument("--renderer", choices=["forward_plus", "mobile", "gl_compatibility"],
                        default="forward_plus", help="visual renderer; no implicit GL fallback")
    args = parser.parse_args()
    if args.mode == "visual" and args.portable_graphics and args.renderer != "gl_compatibility":
        raise RuntimeError("portable graphics supports only the explicit --renderer gl_compatibility diagnostic; use a real Vulkan/D3D12/Metal driver for Forward+")
    engine = resolve_engine()
    if args.mode == "doctor":
        print(json.dumps({"godot": engine, "cargo": shutil.which("cargo"),
                          "rustc": shutil.which("rustc"), "xvfb_run": shutil.which("xvfb-run"),
                          "display": os.environ.get("DISPLAY"),
                          "required_godot": (ROOT / ".godot-version").read_text().strip(),
                          "cpp_compiler": shutil.which("g++"),
                          "cpp_library": (ROOT / "godot/native_cpp/bin/libgame_cpp.so").is_file(),
                          "portable_graphics": (ROOT / ".tools/graphics/portable/ready.json").is_file(),
                          "optional_rust": "1.94.0"}, indent=2))
        return 0
    if not engine:
        raise RuntimeError("Godot unavailable. Set GODOT4_BIN to the 4.7.2 executable")
    version = run_step("version", [engine, "--version"])
    if not engine_matches(version, (ROOT / ".godot-version").read_text().strip()):
        raise RuntimeError(f"wrong Godot version: {version.strip()}")
    from project_setup import prepare_extensions
    prepare_extensions(ROOT / "godot")
    base = [engine, "--path", str(ROOT / "godot")]
    run_step("import", base + ["--headless", "--editor", "--import"], timeout=180)
    user_args = ["--smoke"] + (["--require-rust"] if args.require_rust else [])
    user_args += ["--require-cpp"] if args.require_cpp else []
    user_args += ["--test-input"] if args.test_input else []
    if args.mode == "smoke":
        output = run_step("smoke", base + ["--headless", "--"] + user_args)
    else:
        screenshot = ARTIFACTS / ("lab-moved.png" if args.test_input else "lab.png")
        screenshot.unlink(missing_ok=True)  # Never mistake an old image for a new capture.
        command = base + ["--rendering-method", args.renderer,
                          "--audio-driver", "Dummy", "--resolution", "960x540",
                          "--", *user_args, f"--capture={screenshot}"]
        if args.portable_graphics:
            from portable_graphics import environment
            command[1:1] = ["--display-driver", "x11", "--rendering-driver", "opengl3_es"]
            with environment() as env:
                output = run_step("visual", command, env=env)
        else:
            if sys.platform.startswith("linux") and not os.environ.get("DISPLAY"):
                xvfb = shutil.which("xvfb-run")
                if not xvfb:
                    raise RuntimeError("visual mode needs DISPLAY or xvfb-run plus Mesa/OpenGL")
                command = [xvfb, "-a", "-s", "-screen 0 960x540x24", *command]
            output = run_step("visual", command)
        if "CAPTURE_OK " not in output:
            raise RuntimeError("missing capture completion marker")
        validate_capture(screenshot)
    if "SMOKE_OK" not in output:
        raise RuntimeError("missing smoke completion marker")
    if args.test_input and "INPUT_OK" not in output:
        raise RuntimeError("missing input completion marker")
    print(f"PASS: {args.mode}; logs in artifacts/")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, ImportError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
