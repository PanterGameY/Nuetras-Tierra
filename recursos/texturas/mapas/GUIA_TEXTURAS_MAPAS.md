# 🗺️ Guía Técnica de Texturas para Mapas — Nuestra Tierra 2.0 (Godot 4 Mobile)

Esta carpeta centraliza todos los recursos de imagen y texturas PBR utilizados en la construcción y renderizado de escenarios, ciudades, carreteras y biomas del juego.

---

## 📁 Estructura de Subcarpetas

| Carpeta | Descripción y Uso |
|---|---|
| `01_terrenos/` | Suelos modulares y paisajes: pasto, tierra, trocha, asfalto base, rocas y arena/grava. |
| `02_vias_urbanismo/` | Señalización horizontal (líneas viales, cebras), andenes, aceras y cunetas. |
| `03_arquitectura/` | Fachadas de edificios, bodegas logísticas, casas campestres, ladrillos, tejas y vidrios. |
| `04_vegetacion/` | Naturaleza: troncos, cortezas, copas de árboles y arbustos/cultivos de la región. |
| `05_props_mobiliario/` | Señalización vertical, vallas de contención, postes de alumbrado y guardarraíles. |
| `06_atlases_trimsheets/` | **Ultra-optimización móvil:** Múltiples elementos en una sola textura para minimizar *Draw Calls*. |
| `07_cielos_ambiente/` | Panoramas HDRI equirectangulares y planos de nubes para ambientación. |

---

## 🏷️ Convención de Nomenclatura (PBR Estándar)

Para que Godot y los diseñadores reconozcan automáticamente el tipo de mapa, nombra los archivos con los siguientes sufijos:

- **Albedo / Color:** `*_albedo.png` (o `*_diffuse.png`)
- **Normal Map:** `*_normal.png` (formato Tangent Space Normal)
- **Canal Empaquetado ORM (Recomendado para Móvil):** `*_orm.png`
  - **R (Rojo):** *Ambient Occlusion* (AO)
  - **G (Verde):** *Roughness* (Rugosidad)
  - **B (Azul):** *Metallic* (Metálico)
- **Emisivo:** `*_emission.png` (luces, reflectivos nocturnos, semáforos)
- **Opacidad:** `*_opacity.png` (follaje de árboles y rejas)

> 💡 **Tip de Rendimiento Móvil:** Usar texturas **ORM empaquetadas** reduce el número de unidades de textura muestreadas de 3 a 1 en el shader, liberando ancho de banda de GPU crítico en teléfonos móviles.

---

## ⚙️ Configuración de Importación Recomendada en Godot 4

Al seleccionar una textura en la pestaña **"FileSystem"** y revisar la pestaña **"Import"**:

1. **Modo de Compresión (Compression Mode):**
   - Texturas 3D generales: `VRAM Compressed` (Godot comprimirá automáticamente en ASTC/ETC2 para Android y BC/DXT para PC).
   - HDRI / Panoramas: `Lossless` o `VRAM Uncompressed` según la fidelidad deseada.
2. **Mipmaps:**
   - **Siempre activados (`Generate = On`)** para texturas 3D (reduce el aliasing y mejora los FPS a la distancia).
3. **Normal Map:**
   - En texturas con sufijo `_normal`, asegúrate de que el modo de importación reconozca `Normal Map: Enable` para optimizar el canal de compresión de normales.

---

## 📐 Resoluciones Recomendadas para Dispositivos Móviles

| Elemento | Tamaño Máximo Sugerido |
|---|---|
| Suelos y Asfaltos continuos (Tiling) | 1024 × 1024 o 2048 × 2048 |
| Props y Señales individuales | 256 × 256 o 512 × 512 |
| Fachadas de Edificios / Bodegas | 1024 × 1024 |
| Trim Sheets y Atlases combinados | 2048 × 2048 |
| Panoramas de Cielo / HDRI | 2048 × 1024 |
