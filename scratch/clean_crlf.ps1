$paths = @(
    "c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\modelos3d\vehiculos\materiales\Parabrisas.gd",
    "c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\modelos3d\vehiculos\rigidos_fisicas\NPR\coche.gd",
    "c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\shaders\parabrisas.gdshader"
)

foreach ($p in $paths) {
    if (Test-Path $p) {
        Write-Output "Limpiando: $p"
        $content = [System.IO.File]::ReadAllText($p)
        $clean = $content -replace "`r", ""
        [System.IO.File]::WriteAllText($p, $clean)
    }
}
