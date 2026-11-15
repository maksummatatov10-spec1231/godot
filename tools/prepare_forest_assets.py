"""Select CC0 assets from the external library; never copy the whole library."""
from pathlib import Path
import copy
import hashlib
import json
import re
import shutil
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/user/asset-library/extracted/assets')
DEST = ROOT / 'forest_game'
records = []


def copy_asset(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    records.append({'source': str(source.relative_to(SOURCE)),
                    'destination': str(target.relative_to(DEST)),
                    'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest()})


def model(source, folder):
    target = DEST / 'assets' / folder / source.name
    data = json.loads(source.read_text())
    for entry in data.get('buffers', []) + data.get('images', []):
        if 'uri' not in entry:
            continue
        uri = entry['uri']
        origin = source.parent / uri
        if not origin.exists():
            # The supplied base characters contain four _png filename aliases.
            alias = uri.replace('_png', '')
            origin = source.parent / alias
            if not origin.exists():
                raise FileNotFoundError(origin)
        copy_asset(origin, target.parent / uri)
    copy_asset(source, target)
    return target


def animations(character):
    data = json.loads(character.read_text())
    payload = bytearray((character.parent / data['buffers'][0]['uri']).read_bytes())
    names = {node.get('name'): i for i, node in enumerate(data['nodes'])}
    data['animations'] = []
    clips = {
        'Universal Animation Library_Standard_.zip.contents/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb':
            ['Idle_Loop', 'Sword_Idle', 'Walk_Loop', 'Jog_Fwd_Loop', 'Sprint_Loop',
             'Jump_Start', 'Jump_Loop', 'Jump_Land', 'Spell_Simple_Shoot', 'Sword_Attack'],
        'Universal Animation Library 2_Standard_(1).zip.contents/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb':
            ['Sword_Regular_A', 'Sword_Regular_B', 'Sword_Regular_C', 'Sword_Heavy_Combo'],
    }
    for relative, selected in clips.items():
        source = SOURCE / relative
        blob = source.read_bytes()
        length = struct.unpack_from('<I', blob, 12)[0]
        doc = json.loads(blob[20:20 + length])
        binary = blob[28 + length:]
        cached = {}

        def accessor(old):
            if old in cached:
                return cached[old]
            acc = copy.deepcopy(doc['accessors'][old])
            view = copy.deepcopy(doc['bufferViews'][acc['bufferView']])
            start = view.get('byteOffset', 0)
            while len(payload) % 4:
                payload.append(0)
            view['byteOffset'] = len(payload)
            view['buffer'] = 0
            payload.extend(binary[start:start + view['byteLength']])
            acc['bufferView'] = len(data['bufferViews'])
            data['bufferViews'].append(view)
            cached[old] = len(data['accessors'])
            data['accessors'].append(acc)
            return cached[old]

        for original in doc['animations']:
            if original['name'] not in selected:
                continue
            anim = copy.deepcopy(original)
            for sampler in anim['samplers']:
                sampler['input'] = accessor(sampler['input'])
                sampler['output'] = accessor(sampler['output'])
            channels = []
            for channel in anim['channels']:
                name = doc['nodes'][channel['target']['node']].get('name')
                if name in names:
                    channel['target']['node'] = names[name]
                    channels.append(channel)
            anim['channels'] = channels
            data['animations'].append(anim)
        records.append({'source': relative, 'source_sha256': hashlib.sha256(blob).hexdigest(),
                        'selected_animations': selected, 'operation': 'same named Universal rig; no retarget guessing'})
    data['buffers'] = [{'uri': 'warden.bin', 'byteLength': len(payload)}]
    (character.parent / 'warden.bin').write_bytes(payload)
    output = character.parent / 'warden.gltf'
    output.write_text(json.dumps(data, separators=(',', ':')))
    (character.parent / json.loads(character.read_text())['buffers'][0]['uri']).unlink()
    character.unlink()


def main():
    nature = SOURCE / 'Stylized Nature MegaKit_Standard_.zip.contents/glTF'
    for name in ['CommonTree_1', 'CommonTree_2', 'CommonTree_3', 'Pine_1', 'Pine_3',
                 'Bush_Common', 'Fern_1', 'Grass_Common_Short', 'Grass_Wispy_Tall',
                 'Flower_3_Group', 'Flower_4_Group', 'Rock_Medium_1', 'Rock_Medium_2',
                 'Mushroom_Common', 'Pebble_Round_1']:
        model(nature / (name + '.gltf'), 'nature')
    char = next(SOURCE.glob('Universal Base*/**/Godot - UE/Superhero_Male_FullBody.gltf'))
    animations(model(char, 'hero'))
    sword = next(SOURCE.glob('KayKit_Fantasy*/**/gltf/sword_C.gltf'))
    model(sword, 'weapon')
    for pack, name in [('ElementalMagicFXFree', 'ElementalMagicFX'), ('BattleFXFree', 'BattleFX')]:
        folder = SOURCE / f'Effects/{pack}.zip.contents/{pack}/assets/BinbunVFX_Vol2'
        for path in folder.rglob('*'):
            if not path.is_file() or path.suffix in {'.import', '.uid', '.hdr', '.obj'}:
                continue
            if path.suffix == '.tscn' and 'effects' not in path.parts:
                continue
            if 'shared' not in path.parts and name not in path.parts:
                continue
            copy_asset(path, DEST / 'assets/BinbunVFX_Vol2' / path.relative_to(folder))
    # Only selected image inputs; cap texture resolution at 1024, retain alpha.
    for path in (DEST / 'assets').rglob('*.png'):
        with Image.open(path) as image:
            if max(image.size) > 1024:
                image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
                image.save(path, optimize=True)
    # Avoid upstream author UID cache lookups; preserve explicit paths.
    for path in (DEST / 'assets/BinbunVFX_Vol2').rglob('*.tscn'):
        path.write_text(re.sub(r' uid="uid://[^\"]+"', '', path.read_text()))
    licenses = json.loads((ROOT / 'docs/assets/licenses.json').read_text())
    wanted = ['Stylized Nature', 'Universal Base', 'Universal Animation', 'FantasyWeapons',
              'ElementalMagic', 'BattleFX']
    chosen = [entry for entry in licenses if any(key in entry['pack'] for key in wanted)]
    (DEST / 'ASSET_LICENSES.json').write_text(json.dumps(chosen, ensure_ascii=False, indent=2))
    (DEST / 'asset-selection.json').write_text(json.dumps(records, indent=2))
    print('Selected inputs:', len(records))


if __name__ == '__main__':
    main()
