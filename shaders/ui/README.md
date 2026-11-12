Shader de ajuste de color para TextureRect

Archivo:
res://shaders/ui/color_adjust.shader

Uso (editor):
- Selecciona tu `TextureRect`.
- En la propiedad `Material` crea `New ShaderMaterial`.
- Abre el material y en `Shader` pulsa `Load` → selecciona `res://shaders/ui/color_adjust.shader`.
- Ajusta los parámetros del material (ver lista abajo).

Parámetros principales:
- `hue_shift`: desplazamiento de tono (fracciones de vuelta; 1.0 = 360°).
- `saturation`: multiplicador de saturación.
- `value_multiplier`: multiplicador de valor/brightness multiplicativo.
- `brightness`: suma de brillo (valor añadido).
- `contrast`: multiplicador de contraste.
- `tint_color`: color de tinte.
- `tint_amount`: cuánto aplicar el tinte (0..1).
- `alpha_multiplier`: multiplicador de alpha final.

Ejemplo GDScript:

```
var mat = $TextureRect.material
if mat and mat is ShaderMaterial:
    mat.set_shader_parameter("hue_shift", 0.08) # ~29°
    mat.set_shader_parameter("saturation", 1.2)
    mat.set_shader_parameter("tint_color", Color(1, 0.8, 0.6))
    mat.set_shader_parameter("tint_amount", 0.25)
```

Notas:
- `hue_shift` se expresa en vueltas (0.5 = 180°).
- Este shader está pensado para `TextureRect` / `CanvasItem`.
