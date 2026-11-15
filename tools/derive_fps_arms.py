"""Keep complete weighted arms; shoulder anchors can extend behind the FPS lens."""
import copy
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1] / 'forest_game/assets/hero'


def main():
    data = json.loads((ROOT / 'warden.gltf').read_text())
    binary = (ROOT / 'warden.bin').read_bytes()

    def read(index):
        a = data['accessors'][index]
        v = data['bufferViews'][a['bufferView']]
        fmt = '<' + {5126: 'f', 5125: 'I', 5123: 'H'}[a['componentType']] * {'VEC3': 3, 'SCALAR': 1}[a['type']]
        step = v.get('byteStride', struct.calcsize(fmt))
        base = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        return [struct.unpack_from(fmt, binary, base + i * step) for i in range(a['count'])]

    body_id = next(i for i, mesh in enumerate(data['meshes'])
                   if any(data['materials'][p.get('material', 0)].get('name') == 'MI_Superhero_Male' for p in mesh['primitives']))
    arms = copy.deepcopy(data)
    for node in arms['nodes']:
        if 'mesh' in node:
            if node['mesh'] == body_id:
                node['mesh'] = 0
            else:
                del node['mesh']
    arms['meshes'] = [arms['meshes'][body_id]]
    extra = bytearray()
    for primitive in arms['meshes'][0]['primitives']:
        points = read(primitive['attributes']['POSITION'])
        indices = [v[0] for v in read(primitive['indices'])]
        selected = []
        for i in range(0, len(indices), 3):
            tri = indices[i:i+3]
            x, y, _ = [sum(points[v][axis] for v in tri) / 3 for axis in range(3)]
            if abs(x) > 0.24 and y > 1.27:
                selected.extend(tri)
        primitive['indices'] = len(arms['accessors'])
        arms['accessors'].append({'bufferView': len(arms['bufferViews']), 'componentType': 5125,
                                  'count': len(selected), 'type': 'SCALAR'})
        arms['bufferViews'].append({'buffer': 1, 'byteOffset': len(extra),
                                   'byteLength': len(selected)*4, 'target': 34963})
        extra.extend(struct.pack('<'+'I'*len(selected), *selected))
    arms['buffers'].append({'uri': 'warden_arms_indices.bin', 'byteLength': len(extra)})
    (ROOT / 'warden_arms_indices.bin').write_bytes(extra)
    (ROOT / 'warden_arms.gltf').write_text(json.dumps(arms, separators=(',', ':')))


if __name__ == '__main__':
    main()
