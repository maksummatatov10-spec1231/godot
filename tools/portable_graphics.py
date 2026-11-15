"""Context-managed private Xvfb + ANGLE/SwiftShader pbuffer renderer (960x540 only)."""
from contextlib import contextmanager
import ctypes
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
PORTABLE = ROOT / ".tools/graphics/portable"


def query_visual():
    xlib = ctypes.CDLL("libX11.so.6")
    xlib.XOpenDisplay.argtypes = [ctypes.c_char_p]
    xlib.XOpenDisplay.restype = ctypes.c_void_p
    xlib.XDefaultScreen.argtypes = [ctypes.c_void_p]
    xlib.XDefaultScreen.restype = ctypes.c_int
    xlib.XDefaultVisual.argtypes = [ctypes.c_void_p, ctypes.c_int]
    xlib.XDefaultVisual.restype = ctypes.c_void_p
    xlib.XVisualIDFromVisual.argtypes = [ctypes.c_void_p]
    xlib.XVisualIDFromVisual.restype = ctypes.c_ulong
    xlib.XCloseDisplay.argtypes = [ctypes.c_void_p]
    until = time.monotonic() + 8
    display = None
    while not display and time.monotonic() < until:
        display = xlib.XOpenDisplay(None)
        if not display:
            time.sleep(0.05)
    if not display:
        raise RuntimeError("Xvfb did not become ready")
    try:
        visual = xlib.XDefaultVisual(display, xlib.XDefaultScreen(display))
        print(xlib.XVisualIDFromVisual(visual))
    finally:
        xlib.XCloseDisplay(display)


@contextmanager
def environment():
    if not (PORTABLE / "ready.json").is_file():
        raise RuntimeError("run tools/bootstrap_graphics.py first (see docs/GRAPHICS.md)")
    env = dict(os.environ)
    env.update({
        "LD_LIBRARY_PATH": ":".join([str(PORTABLE / "egl"), str(PORTABLE / "angle"),
                                     str(PORTABLE / "lib"), env.get("LD_LIBRARY_PATH", "")]),
        "GODOT_REAL_EGL": str(PORTABLE / "angle/libEGL.so"),
        "ANGLE_DEFAULT_PLATFORM": "swiftshader",
        "VK_ICD_FILENAMES": str(PORTABLE / "angle/vk_swiftshader_icd.json"),
        "XKB_CONFIG_ROOT": str(PORTABLE / "sources/xkeyboard"),
    })
    number = next((n for n in range(100, 200) if not Path(f"/tmp/.X11-unix/X{n}").exists()
                   and not Path(f"/tmp/.X{n}-lock").exists()), None)
    if number is None:
        raise RuntimeError("no free diagnostic X display")
    env["DISPLAY"] = f":{number}"
    # This legacy Xvfb has a compiled-in /usr/bin/xkbcomp path. Use an existing system
    # compiler if present; otherwise create an exact temporary symlink and remove it.
    compiler = Path("/usr/bin/xkbcomp")
    created = False
    process = None
    try:
        if not os.path.lexists(compiler):
            subprocess.run(["sudo", "-n", "ln", "-s", str(PORTABLE / "xkbcomp"), str(compiler)],
                           check=True, timeout=10)
            created = True
        (ROOT / "artifacts").mkdir(exist_ok=True)
        with (ROOT / "artifacts/portable-xvfb.log").open("w") as log:
            process = subprocess.Popen([str(PORTABLE / "Xvfb"), env["DISPLAY"],
                                        "-screen", "0", "960x540x24", "-nolisten", "tcp", "-ac",
                                        "-noreset", "-xkbdir", env["XKB_CONFIG_ROOT"]],
                                       env=env, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            visual = subprocess.check_output([sys.executable, __file__, "--query-visual"],
                                             env=env, text=True, timeout=12).strip()
            if not visual.isdigit() or process.poll() is not None:
                raise RuntimeError("invalid Xvfb visual; see artifacts/portable-xvfb.log")
            env["GODOT_PBUFFER_VISUAL"] = visual
            yield env
    finally:
        if process and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)
        if created and compiler.is_symlink() and compiler.readlink() == PORTABLE / "xkbcomp":
            subprocess.run(["sudo", "-n", "rm", "--", str(compiler)], check=True, timeout=10)


if __name__ == "__main__":
    query_visual()
