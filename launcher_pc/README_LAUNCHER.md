# Nuestra Tierra 2.0 — PC Launcher (Godot 4.7)

Proyecto independiente en Godot 4.7 (`GL Compatibility`) para el lanzador de PC. Al estar separado de la raíz del juego, al exportarlo **no empaqueta los modelos 3D ni texturas** del juego principal.

## Cómo exportar y usar

1. **Exportar el juego principal**:
   - Abre el proyecto principal (`project.godot`) y exporta el preset **Windows Desktop** (ya genera `NuestraTierra.exe` + `NuestraTierra.pck` por separado en `../../Nuestra tierra_pc/`).
2. **Exportar el Launcher**:
   - Abre `launcher_pc/project.godot` en Godot 4.7.
   - Exporta el preset **Windows Desktop** hacia `../../../Nuestra tierra_pc/NuestraTierraLauncher.exe` (el `.pck` va embebido en el `.exe` del launcher).
3. **Configurar actualizaciones remotas (opcional)**:
   - Sube `NuestraTierra.pck` (o un `.zip`) y un `manifest.json` (usa `manifest.example.json` como plantilla) a **Supabase Storage**, **GitHub Releases** o **Cloudflare R2**.
   - Coloca la URL pública del `manifest.json` en `launcher_pc/launcher_config.json` (`"manifest_url"`).
   - Si `"manifest_url"` está vacío o no hay internet, el launcher funciona en **Modo Local / Offline**.
