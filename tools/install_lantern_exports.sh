#!/usr/bin/env bash
set -euo pipefail
tag=$(cat .godot-version)
folder="$PWD/.tools/godot-exports"
mkdir -p "$folder"
engine="Godot_v${tag}_linux.x86_64.zip"
templates="Godot_v${tag}_export_templates.tpz"
gh release download "$tag" --repo godotengine/godot --pattern "$engine" --pattern "$templates" --pattern SHA512-SUMS.txt --dir "$folder" --clobber
(cd "$folder"; grep -F " $engine" SHA512-SUMS.txt | sha512sum --check --strict -; grep -F " $templates" SHA512-SUMS.txt | sha512sum --check --strict -)
unzip -oq "$folder/$engine" -d "$folder"
python - "$folder/$templates" "${tag/-/.}" <<'PY'
from pathlib import Path
import sys,zipfile
out=Path.home()/'.local/share/godot/export_templates'/sys.argv[2]
out.mkdir(parents=True,exist_ok=True)
required={'android_release.apk','android_debug.apk','windows_release_x86_64.exe','version.txt'}
with zipfile.ZipFile(sys.argv[1]) as z:
    selected={Path(n).name:n for n in z.namelist() if Path(n).name in required}
    if selected.keys()!=required: raise RuntimeError('Missing official export templates: '+str(selected))
    for name,path in selected.items(): (out/name).write_bytes(z.read(path))
PY
chmod +x "$folder/${engine%.zip}"
echo "GODOT4_BIN=$folder/${engine%.zip}" >> "$GITHUB_ENV"
# SDK-provided tools are used for export/signature/manifest checks; no Gradle/NDK build.
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" 'build-tools;35.0.1' 'platforms;android-35'
"$ANDROID_HOME/platform-tools/adb" start-server
mkdir -p "$HOME/.config/godot"
python - <<'PY'
from pathlib import Path
import os
text='[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
text+='export/android/java_sdk_path = "'+os.environ['JAVA_HOME']+'"\n'
text+='export/android/android_sdk_path = "'+os.environ['ANDROID_HOME']+'"\n'
(Path.home()/'.config/godot/editor_settings-4.7.tres').write_text(text)
PY
