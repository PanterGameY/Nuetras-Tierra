#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import json
import re
from pathlib import Path
from collections import defaultdict

def analyze_godot_project(project_path):
    """Analiza un proyecto Godot y genere un reporte completo."""
    
    project_path = Path(project_path)
    
    # Estructuras de datos
    all_files = {}  # path -> info
    file_references = defaultdict(set)  # file -> set of referenced files
    orphaned_files = {
        'scripts': [],
        'shaders': [],
        'models': [],
        'scenes': [],
        'materials': [],
        'textures': []
    }
    broken_references = []
    temporal_files = []
    documentation_files = []
    duplicates = []
    critical_files = set()
    
    # Extensiones de interés
    script_extensions = {'.gd'}
    scene_extensions = {'.tscn'}
    shader_extensions = {'.gdshader'}
    model_extensions = {'.obj', '.fbx', '.gltf', '.glb'}
    material_extensions = {'.tres', '.tres'}
    texture_extensions = {'.png', '.jpg', '.jpeg', '.bmp', '.webp'}
    
    # 1. Escanear todos los archivos
    print("=[Scanning project files]=")
    for root, dirs, files in os.walk(project_path):
        # Ignorar directorios de caché
        dirs[:] = [d for d in dirs if d not in ['.godot', '.git', '__pycache__', 'node_modules']]
        
        for file in files:
            full_path = Path(root) / file
            relative_path = full_path.relative_to(project_path)
            
            all_files[str(relative_path)] = {
                'full_path': str(full_path),
                'extension': full_path.suffix.lower(),
                'size': full_path.stat().st_size if full_path.exists() else 0
            }
    
    print(f"Total files found: {len(all_files)}")
    
    # 2. Analizar archivos .tscn
    print("=[Analyzing .tscn files]=")
    tscn_files = [f for f in all_files if f.endswith('.tscn')]
    print(f"Found {len(tscn_files)} .tscn files")
    
    for tscn_file in tscn_files:
        full_path = all_files[tscn_file]['full_path']
        try:
            with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
                # Buscar paths en ExtResource
                for match in re.finditer(r'path="([^"]+)"', content):
                    ref_path = match.group(1)
                    # Normalizar path
                    ref_path = ref_path.replace('res://', '').replace('uid://', '')
                    file_references[tscn_file].add(ref_path)
                
                # Buscar instancias de escenas
                for match in re.finditer(r'instance=<res://([^"]+\.tscn)>', content):
                    ref_path = match.group(1)
                    file_references[tscn_file].add(ref_path)
                    
        except Exception as e:
            print(f"Error reading {tscn_file}: {e}")
    
    # 3. Analizar archivos .gd
    print("=[Analyzing .gd files]=")
    gd_files = [f for f in all_files if f.endswith('.gd')]
    print(f"Found {len(gd_files)} .gd files")
    
    for gd_file in gd_files:
        full_path = all_files[gd_file]['full_path']
        try:
            with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
                # Buscar load() y preload()
                for match in re.finditer(r'(?:load|preload)\s*\(\s*["\']([^"\']+)["\']', content):
                    ref_path = match.group(1)
                    ref_path = ref_path.replace('res://', '')
                    file_references[gd_file].add(ref_path)
                    
        except Exception as e:
            print(f"Error reading {gd_file}: {e}")
    
    # 4. Buscar documentación obsoleta
    print("=[Searching deprecated documentation]=")
    doc_patterns = ['CAMBIOS_', 'CHECKLIST_', 'DIAGRAMA_', 'GUIA_', 'INTEGRACION_', 'README_', 'RESUMEN_', 'SISTEMA_']
    for file_path in all_files:
        if file_path.endswith('.md'):
            filename = Path(file_path).name
            # Revisar si es documentación obsoleta
            if any(pattern in filename for pattern in doc_patterns):
                documentation_files.append(file_path)
    
    print(f"Found {len(documentation_files)} documentation files")
    
    # 5. Buscar archivos temporales
    print("=[Searching temporary files]=")
    temp_patterns = ['.tmp', '.uid', '.import', '.swp', '~']
    for file_path in all_files:
        if any(pattern in file_path for pattern in temp_patterns):
            temporal_files.append(file_path)
    
    print(f"Found {len(temporal_files)} temporary files")
    
    # 6. Buscar duplicados
    print("=[Searching duplicates]=")
    for file_path in all_files:
        if re.search(r'\(\d+\)', file_path):
            duplicates.append(file_path)
    
    print(f"Found {len(duplicates)} duplicate files")
    
    # 7. Identificar archivos críticos
    critical_patterns = ['MainMenu', 'MenuSystem', 'Player', 'Mapa', 'UIVehiculo']
    for file_path in all_files:
        for pattern in critical_patterns:
            if pattern in file_path:
                critical_files.add(file_path)
    
    # 8. Identificar huérfanos
    print("=[Identifying orphaned files]=")
    referenced_normalized = set()
    for refs in file_references.values():
        for ref in refs:
            referenced_normalized.add(ref)
    
    # Comprobar scripts
    for script in gd_files:
        if script not in referenced_normalized and script not in critical_files:
            # Excepto si es el script del archivo actual
            if script not in file_references:
                orphaned_files['scripts'].append(script)
    
    # Comprobar escenas
    for scene in tscn_files:
        if scene not in referenced_normalized and scene not in critical_files:
            orphaned_files['scenes'].append(scene)
    
    # Comprobar materiales
    material_files = [f for f in all_files if f.endswith('.tres')]
    for material in material_files:
        if material not in referenced_normalized:
            orphaned_files['materials'].append(material)
    
    # 9. Generar reporte
    print("=[Generating report]=")
    report = {
        'timestamp': __import__('datetime').datetime.now().isoformat(),
        'huerfanos': orphaned_files,
        'referencias_rotas': broken_references,
        'temporales': temporal_files,
        'documentacion': documentation_files,
        'duplicados': duplicates,
        'criticos_preservar': sorted(list(critical_files)),
        'resumen': {
            'total_archivos': len(all_files),
            'archivos_gd': len(gd_files),
            'archivos_tscn': len(tscn_files),
            'archivos_md': len(documentation_files),
            'archivos_temporales': len(temporal_files),
            'duplicados_encontrados': len(duplicates),
            'huerfanos_totales': sum(len(v) for v in orphaned_files.values())
        },
        'recomendaciones_limpieza': [
            f"1. Eliminar {len(documentation_files)} archivos de documentación obsoleta",
            f"2. Eliminar {len(temporal_files)} archivos temporales",
            f"3. Investigar {len(duplicates)} duplicados encontrados",
            f"4. Revisar {sum(len(v) for v in orphaned_files.values())} archivos huérfanos",
            "5. Considerar reorganizar estructura de carpetas"
        ]
    }
    
    return report

if __name__ == '__main__':
    proyecto = r"c:\Users\johan\OneDrive\Documentos\GitHub\Nuetras-Tierra"
    reporte_path = Path(proyecto) / "REPORTE_ANALISIS_GODOT.json"
    
    print(f"Analizando proyecto: {proyecto}\n")
    
    try:
        reporte = analyze_godot_project(proyecto)
        
        # Guardar JSON
        with open(reporte_path, 'w', encoding='utf-8') as f:
            json.dump(reporte, f, indent=2, ensure_ascii=False)
        
        print(f"\n✓ Reporte guardado en: {reporte_path}")
        print("\n=== RESUMEN ===")
        print(f"Total de archivos: {reporte['resumen']['total_archivos']}")
        print(f"Scripts (.gd): {reporte['resumen']['archivos_gd']}")
        print(f"Escenas (.tscn): {reporte['resumen']['archivos_tscn']}")
        print(f"Documentación: {reporte['resumen']['archivos_md']}")
        print(f"Temporales: {reporte['resumen']['archivos_temporales']}")
        print(f"Duplicados: {reporte['resumen']['duplicados_encontrados']}")
        print(f"Huérfanos: {reporte['resumen']['huerfanos_totales']}")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
