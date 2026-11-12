import os, sys, re
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

def verificar_proyecto(root_path):
    root = Path(root_path)
    print(f"=== VERIFICANDO INTEGRIDAD EN: {root} ===")
    
    broken_refs = []
    checked_files = 0
    checked_refs = 0
    
    # 1. Verificar project.godot
    proj_godot = root / "project.godot"
    if proj_godot.exists():
        content = proj_godot.read_text(encoding="utf-8", errors="ignore")
        for match in re.finditer(r'["\']res://([^"\']+)["\']', content):
            ref = match.group(1)
            checked_refs += 1
            target = root / ref
            if not target.exists():
                broken_refs.append(("project.godot", f"res://{ref}"))
    
    # 2. Verificar .tscn y .tres (excluyendo demo, .godot, .git, android)
    for ext in [".tscn", ".tres"]:
        for f in root.rglob(f"*{ext}"):
            if any(x in f.parts for x in [".godot", ".git", "android", "demo"]):
                continue
            checked_files += 1
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")
                for match in re.finditer(r'path=["\']res://([^"\']+)["\']', content):
                    ref = match.group(1)
                    checked_refs += 1
                    target = root / ref
                    if not target.exists():
                        broken_refs.append((str(f.relative_to(root)), f"res://{ref}"))
            except Exception as e:
                print(f"Error leyendo {f}: {e}")
                
    # 3. Verificar .gd (preload y load)
    for f in root.rglob("*.gd"):
        if any(x in f.parts for x in [".godot", ".git", "android", "demo"]):
            continue
        checked_files += 1
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
            for match in re.finditer(r'(?:preload|load|change_scene_to_file)\s*\(\s*["\']res://([^"\']+)["\']\s*\)', content):
                ref = match.group(1)
                checked_refs += 1
                target = root / ref
                if not target.exists():
                    broken_refs.append((str(f.relative_to(root)), f"res://{ref}"))
        except Exception as e:
            print(f"Error leyendo {f}: {e}")
            
    print(f"\nResumen de integridad:")
    print(f"  • Archivos analizados: {checked_files}")
    print(f"  • Referencias de producción validadas: {checked_refs}")
    print(f"  • Referencias rotas encontradas: {len(broken_refs)}")
    
    if broken_refs:
        print("\nDetalle de referencias rotas encontradas:")
        for origen, destino in broken_refs:
            print(f"  - [{origen}] -> {destino}")
    else:
        print("\n✅ ¡FELICIDADES! Cero referencias rotas en el código de producción del juego.")
        
    return len(broken_refs)

if __name__ == "__main__":
    proj = r"c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0"
    code = verificar_proyecto(proj)
