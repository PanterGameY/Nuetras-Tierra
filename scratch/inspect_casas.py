import json
import struct

with open("modelos3d/mapa/casas.glb", "rb") as f:
    magic = f.read(4)
    version = struct.unpack("<I", f.read(4))[0]
    length = struct.unpack("<I", f.read(4))[0]
    chunk_len = struct.unpack("<I", f.read(4))[0]
    chunk_type = f.read(4)
    json_bytes = f.read(chunk_len)
    data = json.loads(json_bytes.decode("utf-8", errors="ignore"))

print("GLTF summary:")
if "nodes" in data:
    print(f"Nodes total: {len(data['nodes'])}")
    for i, n in enumerate(data["nodes"]):
        print(f"  Node {i}: {n.get('name', 'unnamed')}")
if "meshes" in data:
    print(f"Meshes total: {len(data['meshes'])}")
    for i, m in enumerate(data["meshes"]):
        print(f"  Mesh {i}: {m.get('name', 'unnamed')}")
