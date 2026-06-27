import re

tscn_path = r"c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\demo\assets\scenes\PrimitivesCity.tscn"

nodes = []
with open(tscn_path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if line.strip().startswith('[node'):
            nodes.append((i+1, line.strip()))
            if len(nodes) >= 150: # limit to first 150 nodes to see the structure
                break

print(f"Total node definitions found (up to 150): {len(nodes)}")
for line_num, node_str in nodes:
    print(f"Line {line_num}: {node_str}")
