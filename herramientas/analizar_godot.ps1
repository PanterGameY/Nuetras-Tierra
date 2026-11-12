# Script completo de análisis de proyecto Godot
$proyectoPath = "c:\Users\johan\OneDrive\Documentos\GitHub\Nuetras-Tierra"
$reportPath = Join-Path $proyectoPath "REPORTE_ANALISIS_GODOT.json"

Write-Host "=== INICIANDO ANÁLISIS DEL PROYECTO GODOT ===" -ForegroundColor Cyan
Write-Host "Proyecto: $proyectoPath`n" -ForegroundColor Yellow

# Variables para almacenar datos
$allFiles = @{}
$fileReferences = @{}
$orphaned = @{ scripts = @(); shaders = @(); models = @(); scenes = @(); materials = @(); textures = @() }
$brokenReferences = @()
$temporalFiles = @()
$documentationFiles = @()
$duplicates = @()
$criticalFiles = @()

# =================== PASO 1: ESCANEAR ARCHIVOS ===================
Write-Host "PASO 1: Escaneando archivos del proyecto..." -ForegroundColor Green

$extensions = @('.gd', '.tscn', '.tres', '.md', '.tmp', '.uid', '.import', '.gdshader', '.obj', '.fbx', '.gltf', '.glb', '.png', '.jpg', '.jpeg')

Get-ChildItem -Path $proyectoPath -Recurse -Force | Where-Object {
    $_.Extension -in $extensions -or $_.Name -match '\.(tmp|uid|import|md)$'
} | ForEach-Object {
    $relativePath = $_.FullName -replace [regex]::Escape($proyectoPath), ""
    $relativePath = $relativePath.TrimStart('\').Replace('\', '/')
    
    $allFiles[$relativePath] = @{
        'FullPath' = $_.FullName
        'Extension' = $_.Extension
        'Size' = $_.Length
    }
}

Write-Host "✓ Encontrados $($allFiles.Count) archivos relevantes" -ForegroundColor Green

# =================== PASO 2: ANALIZAR .TSCN ===================
Write-Host "PASO 2: Analizando archivos .tscn..." -ForegroundColor Green

$tscnFiles = $allFiles.Keys | Where-Object { $_ -match '\.tscn$' }
Write-Host "Encontrados $($tscnFiles.Count) archivos .tscn"

foreach ($tscnFile in $tscnFiles) {
    $fullPath = $allFiles[$tscnFile].FullPath
    $fileReferences[$tscnFile] = @{}
    
    try {
        $content = Get-Content -Path $fullPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        # Extraer paths
        $pathMatches = [regex]::Matches($content, 'path="([^"]+)"', 'IgnoreCase')
        foreach ($match in $pathMatches) {
            $refPath = $match.Groups[1].Value
            $refPath = $refPath -replace '^res://', '' -replace '^uid://', ''
            if ($fileReferences[$tscnFile]) {
                $fileReferences[$tscnFile][$refPath] = $true
            }
        }
        
        # Extraer instancias
        $instanceMatches = [regex]::Matches($content, 'instance=<res://([^">]+\.tscn)>', 'IgnoreCase')
        foreach ($match in $instanceMatches) {
            $refPath = $match.Groups[1].Value
            $fileReferences[$tscnFile][$refPath] = $true
        }
    } catch {
        Write-Host "✗ Error leyendo $tscnFile : $_" -ForegroundColor Yellow
    }
}

# =================== PASO 3: ANALIZAR .GD ===================
Write-Host "PASO 3: Analizando archivos .gd..." -ForegroundColor Green

$gdFiles = $allFiles.Keys | Where-Object { $_ -match '\.gd$' }
Write-Host "Encontrados $($gdFiles.Count) archivos .gd"

foreach ($gdFile in $gdFiles) {
    $fullPath = $allFiles[$gdFile].FullPath
    $fileReferences[$gdFile] = @{}
    
    try {
        $content = Get-Content -Path $fullPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        # Extraer load() y preload()
        $loadPattern = '(load|preload)\s*\(\s*"([^"]+)"'
        $loadMatches = [regex]::Matches($content, $loadPattern, 'IgnoreCase')
        foreach ($match in $loadMatches) {
            $refPath = $match.Groups[2].Value
            $refPath = $refPath -replace '^res://', ''
            $fileReferences[$gdFile][$refPath] = $true
        }
    } catch {
        Write-Host "✗ Error leyendo $gdFile : $_" -ForegroundColor Yellow
    }
}

# =================== PASO 4: IDENTIFICAR DOCUMENTACIÓN ===================
Write-Host "PASO 4: Identificando documentación obsoleta..." -ForegroundColor Green

$docPatterns = @('CAMBIOS_', 'CHECKLIST_', 'DIAGRAMA_', 'GUIA_', 'INTEGRACION_', 'README_', 'RESUMEN_', 'SISTEMA_')

foreach ($file in $allFiles.Keys) {
    if ($file -match '\.md$') {
        $filename = Split-Path $file -Leaf
        foreach ($pattern in $docPatterns) {
            if ($filename -like "$pattern*") {
                $documentationFiles += $file
                break
            }
        }
    }
}

Write-Host "✓ Encontrados $($documentationFiles.Count) archivos de documentación" -ForegroundColor Green

# =================== PASO 5: IDENTIFICAR ARCHIVOS TEMPORALES ===================
Write-Host "PASO 5: Identificando archivos temporales..." -ForegroundColor Green

$tempPatterns = @('\.tmp$', '\.uid$', '\.import$', '\.swp$', '\~$')

foreach ($file in $allFiles.Keys) {
    foreach ($pattern in $tempPatterns) {
        if ($file -match $pattern) {
            $temporalFiles += $file
            break
        }
    }
}

Write-Host "✓ Encontrados $($temporalFiles.Count) archivos temporales" -ForegroundColor Green

# =================== PASO 6: IDENTIFICAR DUPLICADOS ===================
Write-Host "PASO 6: Identificando duplicados..." -ForegroundColor Green

foreach ($file in $allFiles.Keys) {
    if ($file -match '\(\d+\)') {
        $duplicates += $file
    }
}

Write-Host "✓ Encontrados $($duplicates.Count) duplicados" -ForegroundColor Green

# =================== PASO 7: IDENTIFICAR ARCHIVOS CRÍTICOS ===================
Write-Host "PASO 7: Identificando archivos críticos..." -ForegroundColor Green

$criticalPatterns = @('MainMenu', 'MenuSystem', 'Player', 'Mapa', 'UIVehiculo', 'HUD')

foreach ($file in $allFiles.Keys) {
    foreach ($pattern in $criticalPatterns) {
        if ($file -like "*$pattern*") {
            $criticalFiles += $file
            break
        }
    }
}

Write-Host "✓ Identificados $($criticalFiles.Count) archivos críticos" -ForegroundColor Green

# =================== PASO 8: IDENTIFICAR HUÉRFANOS ===================
Write-Host "PASO 8: Identificando archivos huérfanos..." -ForegroundColor Green

# Crear lista de archivos referenciados
$referencedFiles = @{}
foreach ($fileRefs in $fileReferences.Values) {
    foreach ($ref in $fileRefs.Keys) {
        $normalizedRef = $ref -replace '^res://', ''
        $referencedFiles[$normalizedRef] = $true
    }
}

# Buscar huérfanos
foreach ($script in $gdFiles) {
    $shouldKeep = $false
    
    # Revisar si es crítico
    foreach ($critical in $criticalFiles) {
        if ([System.IO.Path]::GetFileName($script) -eq [System.IO.Path]::GetFileName($critical)) {
            $shouldKeep = $true
            break
        }
    }
    
    # Revisar si es referenciado
    if (-not $shouldKeep -and -not $referencedFiles.ContainsKey($script)) {
        $orphaned.scripts += $script
    }
}

foreach ($scene in $tscnFiles) {
    $shouldKeep = $false
    
    foreach ($critical in $criticalFiles) {
        if ([System.IO.Path]::GetFileName($scene) -eq [System.IO.Path]::GetFileName($critical)) {
            $shouldKeep = $true
            break
        }
    }
    
    if (-not $shouldKeep -and -not $referencedFiles.ContainsKey($scene)) {
        $orphaned.scenes += $scene
    }
}

$materialFiles = $allFiles.Keys | Where-Object { $_ -match '\.tres$' }
foreach ($material in $materialFiles) {
    if (-not $referencedFiles.ContainsKey($material)) {
        $orphaned.materials += $material
    }
}

Write-Host "✓ Scripts huérfanos: $($orphaned.scripts.Count)" -ForegroundColor Green
Write-Host "✓ Escenas huérfanas: $($orphaned.scenes.Count)" -ForegroundColor Green
Write-Host "✓ Materiales huérfanos: $($orphaned.materials.Count)" -ForegroundColor Green

# =================== PASO 9: CREAR REPORTE ===================
Write-Host "PASO 9: Generando reporte JSON..." -ForegroundColor Green

$reporte = @{
    'timestamp' = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    'huerfanos' = $orphaned
    'referencias_rotas' = $brokenReferences
    'temporales' = $temporalFiles
    'documentacion' = $documentationFiles
    'duplicados' = $duplicates
    'criticos_preservar' = $criticalFiles
    'estructura_carpetas' = @(
        "root/"
        "├── scenes/"
        "│   ├── gui/"
        "│   ├── vehiculos/"
        "│   └── *.tscn"
        "├── Scripts/"
        "│   ├── jugador/"
        "│   ├── vehiculos/"
        "│   └── *.gd"
        "├── modelos3d/"
        "│   └── vehiculos/"
        "├── materiales/"
        "├── shaders/"
        "├── sounds/"
        "├── font/"
        "└── proyecto.godot"
    )
    'resumen' = @{
        'total_archivos' = $allFiles.Count
        'archivos_gd' = $gdFiles.Count
        'archivos_tscn' = $tscnFiles.Count
        'archivos_md' = $documentationFiles.Count
        'archivos_temporales' = $temporalFiles.Count
        'duplicados_encontrados' = $duplicates.Count
        'archivos_criticos' = $criticalFiles.Count
        'huerfanos_totales' = ($orphaned.scripts.Count + $orphaned.scenes.Count + $orphaned.materials.Count)
    }
    'recomendaciones_limpieza' = @(
        "1. DOCUMENTACIÓN: Eliminar $($documentationFiles.Count) archivos .md obsoletos (CAMBIOS_*, CHECKLIST_*, DIAGRAMA_*, GUIA_*, INTEGRACION_*, README_*, RESUMEN_*, SISTEMA_*)"
        "2. TEMPORALES: Eliminar $($temporalFiles.Count) archivos temporales (.tmp, .uid, .import, .swp)"
        "3. DUPLICADOS: Revisar y consolidar $($duplicates.Count) archivos duplicados - Especialmente UIVehiculo (1).tscn"
        "4. SCRIPTS HUÉ RFANOS: Revisar $($orphaned.scripts.Count) scripts no referenciados"
        "5. ESCENAS HUÉRFANAS: Revisar $($orphaned.scenes.Count) escenas no referenciadas"
        "6. MATERIALES: Eliminar o reorganizar $($orphaned.materials.Count) materiales huérfanos"
        "7. ESTRUCTURA: Considerar reorganizar archivos para mejor mantenibilidad"
        "8. REFERENCIAS: Auditar todas las referencias cruzadas para evitar rutas rotas"
    )
}

# Guardar reporte como JSON formateado
$reporteJson = $reporte | ConvertTo-Json -Depth 10
$reporteJson | Out-File -Path $reportPath -Encoding UTF8 -Force

Write-Host "`n✓ Reporte generado correctamente en: $reportPath" -ForegroundColor Cyan
Write-Host "`n=== RESUMEN EJECUTIVO ===" -ForegroundColor Cyan
Write-Host "Total de archivos analizados: $($reporte.resumen.total_archivos)" -ForegroundColor White
Write-Host "Scripts (.gd): $($reporte.resumen.archivos_gd)" -ForegroundColor White
Write-Host "Escenas (.tscn): $($reporte.resumen.archivos_tscn)" -ForegroundColor White
Write-Host "Documentación: $($reporte.resumen.archivos_md)" -ForegroundColor Yellow
Write-Host "Temporales: $($reporte.resumen.archivos_temporales)" -ForegroundColor Yellow
Write-Host "Duplicados: $($reporte.resumen.duplicados_encontrados)" -ForegroundColor Yellow
Write-Host "Archivos críticos a preservar: $($reporte.resumen.archivos_criticos)" -ForegroundColor Magenta
Write-Host "HUÉRFANOS TOTALES: $($reporte.resumen.huerfanos_totales)" -ForegroundColor Red

Write-Host "`n✓ Análisis completado exitosamente" -ForegroundColor Green
