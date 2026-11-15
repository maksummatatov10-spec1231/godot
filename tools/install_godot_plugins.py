#!/usr/bin/env python3
"""Install the three supplied addons, not the entire external asset library.

Requires the verified archive already extracted outside the repository. Updates
Sunshine's Godot 4.7 camera ABI fix from a pinned official commit. No client
daemon is downloaded or run. Network providers default to off in this sandbox.
"""
import base64
import concurrent.futures
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SUNSHINE_COMMIT = 'a73a80b08fb37b255f8f10d49debd71e5541bd70'
PLUGINS = {
    'terrain_3d': 'Terrain3D_v1.1.0-stable-4.zip.contents/addons/terrain_3d',
    'SunshineClouds2': 'SunshineClouds2-6.zip.contents/SunshineClouds2/addons/SunshineClouds2',
    'assets2godot': 'assets2godot_v0.8.2_nobin.zip.contents/addons/assets2godot',
}


def github_bytes(path):
    url=f'repos/Bonkahe/SunshineClouds2/contents/{path}?ref={SUNSHINE_COMMIT}'
    result=json.loads(subprocess.check_output(['gh','api',url],timeout=60))
    if result.get('encoding')!='base64':raise RuntimeError('Expected base64 GitHub contents')
    return base64.b64decode(result['content'])


def main():
    external=Path(sys.argv[1] if len(sys.argv)>1 else '/home/user/asset-library/extracted/assets/plugins')
    destination=ROOT/'godot/addons'
    if any((destination/name).exists() for name in PLUGINS):
        raise SystemExit('Refusing to overwrite an existing addon. Back it up and remove it deliberately first.')
    destination.mkdir(exist_ok=True)
    excluded=[]
    for name,relative in PLUGINS.items():
        source=external/relative
        if not (source/'plugin.cfg').is_file():raise RuntimeError('Missing plugin: '+str(source))
        for file in sorted(source.rglob('*')):
            if not file.is_file():continue
            rel=file.relative_to(source)
            skip=any(part.startswith('.') for part in rel.parts)
            if name=='SunshineClouds2':
                skip=skip or file.suffix in {'.cs'} or '.cs.' in file.name
                # Legacy C# demos and root-project-dependent examples are not addon dependencies.
                skip=skip or file.name in {'ExampleScene.tscn','ExampleCloudsResource.tres','compositor_test_scene.tscn','SunshineCloudsResource.tres','SunshineCloudsResourceLowSettings.tres','SunshineCloudsTestResource.tres'}
            if skip:
                excluded.append(name+'/'+rel.as_posix());continue
            target=destination/name/rel;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(file,target)
    # Match all changed upstream addon blobs except IDE state and omitted demos.
    tree=json.loads(subprocess.check_output(['gh','api',f'repos/Bonkahe/SunshineClouds2/git/trees/{SUNSHINE_COMMIT}?recursive=1'],timeout=60))['tree']
    updates=[]
    for item in tree:
        prefix='addons/SunshineClouds2/'
        if item['type']!='blob' or not item['path'].startswith(prefix):continue
        target=ROOT/'godot'/item['path']
        if not target.is_file():continue
        data=target.read_bytes()
        sha=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        if sha!=item['sha']:updates.append(item)
    def update(item):
        data=github_bytes(item['path'])
        if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=item['sha']:
            raise RuntimeError('Git object mismatch')
        (ROOT/'godot'/item['path']).write_bytes(data)
        return {'path':item['path'],'git_blob':item['sha'],'sha256':hashlib.sha256(data).hexdigest()}
    upstream=list(concurrent.futures.ThreadPoolExecutor(5).map(update,updates))
    for name in ['LICENSE','README.md']:
        (destination/'SunshineClouds2'/name).write_bytes(github_bytes(name))
    # Do not redistribute the vendor's explicitly restricted BlendKit marks.
    for name in ['blendkit-icon.svg','blendkit-logo-hexa_pure.svg']:
        (destination/'assets2godot/logo'/name).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 320 320"><!-- Generic replacement, not a provider trademark; CC0. --><rect x="40" y="40" width="240" height="240" rx="32" fill="#e0e0e0"/><path d="M90 160h140M160 90v140" stroke="#3a4658" stroke-width="24"/></svg>\n')
    subprocess.run(['git', 'apply', '--ignore-space-change', str(ROOT/'tools/plugin-integration.patch')], cwd=ROOT, check=True)
    for path in (destination/'SunshineClouds2').rglob('*'):
        if path.suffix in {'.tscn', '.tres'}:
            text=re.sub(r'(\[ext_resource[^\n]*?) uid="uid://[^"]+"', r'\1', path.read_text())
            path.write_text(text)
    # Main code needs a license notice independent of the library catalog.
    (destination/'assets2godot/ARENA_CHANGES.md').write_text('# Local changes — 2026-11-15\n\nGPLv2 source and notices are retained. Local changes are reviewable in\n`tools/plugin-integration.patch` at repository root:\n\n- Offline mode is an explicit project-level policy: prevent helper auto-start,\n  settings-signal restart and remote provider HTTP calls in this sandbox.\n- Godot 4.7 editor font fallback avoids a missing main_bold theme font.\n- Parent hidden status controls and disconnect the gallery node_added hook.\n  Replace its self-referential Array/lambda cycle; free the main editor screen\n  at shutdown. Full editor smoke now exits without resource/RID leaks.\n- Two restricted BlendKit logo SVGs are replaced by newly drawn generic CC0\n  symbols, not vendor trademarks. Poly Haven/ambientCG marks retain notices.\n\nNo helper executable is bundled (as in the supplied nobin archive). Remote\ncatalogs and external Sources indexing require network/client configuration\nand are not claimed tested or operational in this restricted environment.\n')
    entries=[]
    for name in PLUGINS:
        for path in sorted((destination/name).rglob('*')):
            if path.is_file():entries.append({'path':path.relative_to(ROOT).as_posix(),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    report=ROOT/'docs/plugins';report.mkdir(parents=True, exist_ok=True)
    (report/'installation-manifest.json').write_text(json.dumps({'sunshine_upstream_commit':SUNSHINE_COMMIT,'sunshine_updated_blobs':upstream,'excluded_original_paths':excluded,'installed_files':entries},indent=2)+'\n')
    print('Installed',len(entries),'files; official Sunshine updates:',len(upstream))


if __name__=='__main__':main()
