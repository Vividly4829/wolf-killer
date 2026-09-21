"""Make the island's packed normals importable by Godot, preserving its geometry.

Usage: python godot/tools/prepare_island.py
The source model and browser game assets are never modified.
"""
from pathlib import Path
import json
import struct


def convert(source: Path, destination: Path) -> None:
    raw = source.read_bytes()
    magic, version, _ = struct.unpack_from('<III', raw)
    assert magic == 0x46546C67 and version == 2
    json_length, json_type = struct.unpack_from('<II', raw, 12)
    assert json_type == 0x4E4F534A
    document = json.loads(raw[20:20 + json_length])
    binary_offset = 20 + json_length
    binary_length, binary_type = struct.unpack_from('<II', raw, binary_offset)
    assert binary_type == 0x004E4942
    binary = bytearray(raw[binary_offset + 8:binary_offset + 8 + binary_length])
    count = 0
    for accessor in document['accessors']:
        if accessor['componentType'] != 5122:
            continue
        assert accessor['type'] == 'VEC3' and accessor.get('normalized')
        view = document['bufferViews'][accessor['bufferView']]
        base = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        stride = view.get('byteStride', 6)
        normals = bytearray()
        for index in range(accessor['count']):
            values = struct.unpack_from('<hhh', binary, base + index * stride)
            normals.extend(struct.pack('<fff', *(max(-1.0, value / 32767.0) for value in values)))
        binary.extend(b'\0' * (-len(binary) % 4))
        new_view = {'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(normals), 'target': 34962}
        document['bufferViews'].append(new_view)
        accessor['bufferView'] = len(document['bufferViews']) - 1
        accessor['componentType'] = 5126
        accessor.pop('normalized', None)
        accessor.pop('byteOffset', None)
        binary.extend(normals)
        count += 1
    for field in ('extensionsRequired', 'extensionsUsed'):
        document[field] = [name for name in document.get(field, []) if name != 'KHR_mesh_quantization']
        if not document[field]:
            document.pop(field, None)
    binary.extend(b'\0' * (-len(binary) % 4))
    document['buffers'][0]['byteLength'] = len(binary)
    encoded = json.dumps(document, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    output = struct.pack('<III', magic, version, 28 + len(encoded) + len(binary))
    output += struct.pack('<II', len(encoded), json_type) + encoded
    output += struct.pack('<II', len(binary), binary_type) + binary
    destination.write_bytes(output)
    print(f'Converted {count} normal buffers: {destination.name} ({len(output):,} bytes).')


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[2]
    convert(root / 'game/assets/island-realistic.glb', root / 'godot/assets/island-realistic.glb')
