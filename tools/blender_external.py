#!/usr/bin/env python3
"""Launch the separately installed user-provided Blender with autoexec disabled."""
import os
from pathlib import Path
import subprocess
import sys

home = Path(os.environ.get('EXTERNAL_BLENDER_HOME', '/home/user/blender-tools'))
binary = home / 'blender-5.3.0-linux-x64/blender'
if not binary.is_file():
    raise SystemExit('External Blender is absent. Restore the verified archive; see docs/assets/README.md.')
env = os.environ.copy()
env['LD_LIBRARY_PATH'] = str(home / 'runtime') + (':' + env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
raise SystemExit(subprocess.call([str(binary), '--disable-autoexec', *sys.argv[1:]], env=env))
