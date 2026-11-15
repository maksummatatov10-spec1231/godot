"""Derive an FPS lower-body index subset; retain skin, materials and all clip channels."""
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

    legs = copy.deepcopy(data)
    body_id = next(i for i, mesh in enumerate(data['meshes'])
                   if any(data['materials'][p.get('material', 0)].get('name') == 'MI_Superhero_Male' for p in mesh['primitives']))
    for node in legs['nodes']:
        if 'mesh' in node:
            if node['mesh'] == body_id:
                node['mesh'] = 0
            else:
                del node['mesh']
    legs['meshes'] = [legs['meshes'][body_id]]
    extra = bytearray()
    for mesh in legs['meshes']:
        for primitive in mesh['primitives']:
            points = read(primitive['attributes']['POSITION'])
            indices = [v[0] for v in read(primitive['indices'])]
            selected = []
            for i in range(0, len(indices), 3):
                tri = indices[i:i+3]
                if max(points[v][1] for v in tri) < 1.16:
                    selected.extend(tri)
            primitive['indices'] = len(legs['accessors'])
            legs['accessors'].append({'bufferView': len(legs['bufferViews']), 'componentType': 5125,
                                      'count': len(selected), 'type': 'SCALAR'})
            legs['bufferViews'].append({'buffer': 1, 'byteOffset': len(extra),
                                       'byteLength': len(selected)*4, 'target': 34963})
            extra.extend(struct.pack('<'+'I'*len(selected), *selected))
    legs['buffers'].append({'uri': 'warden_legs.bin', 'byteLength': len(extra)})
    (ROOT / 'warden_legs.bin').write_bytes(extra)
    (ROOT / 'warden_legs.gltf').write_text(json.dumps(legs, separators=(',', ':')))


if __name__ == '__main__':
    main()
