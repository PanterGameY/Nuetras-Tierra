# Manual de Diseño UI: Nuestra Tierra 2.0 (Glassmorphism Automotriz)

Este documento recopila las directrices de diseño visual, colores, tipografías y reglas de maquetación para la interfaz de usuario (UI), asegurando coherencia visual en todos los futuros diálogos, paneles informativos, HUDs y el dispositivo **CelularUI** del juego.

> **Nota:** Para la especificación técnica completa y arquitectura de componentes, consulta también [diseño.md](file:///c:/Users/johan/OneDrive/Documentos/GitHub/nuestra-tierra-2.0/diseño.md).

---

## 1. Filosofía Visual: Glassmorphism Automotriz

El estilo visual oficial del proyecto está unificado con la estética de cabina de **`UIVehiculo`** y la tablet de abordo **`CelularUI`**. Combina:
* **Cristal Ahumado de Alta Densidad**: Fondos carbón translúcidos oscuros (`Color(0.06, 0.07, 0.08, 0.85 - 0.95)`).
* **Bordes Metálicos Glaseados Finos**: Bordes de `1px` con acabado metálico gélido (`Color(0.78, 0.81, 0.85, 0.20 - 0.25)`).
* **Acentos Ámbar de Instrumentación**: Indicadores activos y selecciones en ámbar automotriz (`Color(0.88, 0.68, 0.28, 0.92)`).
* **Acentos Carmesí Técnico**: Botones de salida, emergencias o frenos en tono carmesí (`Color(0.78, 0.28, 0.26, 0.95)`).

---

## 2. Paleta de Colores y Tokens

| Propiedad | Valor RGBA / Hex | Propósito |
| :--- | :--- | :--- |
| **Fondo Base Vidrio** | `Color(0.06, 0.07, 0.08, 0.95)` (`#0f1214`) | Vidrio ahumado para chasis de celular, modales y panel de cajón. |
| **Fondo Panel HUD** | `Color(0.06, 0.07, 0.08, 0.80)` | Paneles de velocímetro, tacómetro y mapas. |
| **Superficie / Card** | `Color(0.09, 0.10, 0.12, 0.90)` (`#171a1e`) | Tarjetas de aplicaciones internas (Banco, Garaje, Trabajos). |
| **Borde Frost 1px** | `Color(0.78, 0.81, 0.85, 0.22)` (`#c7cfd9`) | Borde metálico translúcido estándar en todos los contenedores. |
| **Acento Ámbar** | `Color(0.88, 0.68, 0.28, 0.92)` (`#e0ad47`) | Botones pulsados, rutas activas, títulos y testigos de motor. |
| **Acento Carmesí** | `Color(0.78, 0.28, 0.26, 0.95)` (`#c74742`) | Botones de salir, cancelar rutas, alertas y testigo de freno. |
| **Texto Primario** | `Color(0.88, 0.90, 0.93, 0.95)` | Blanco de alto contraste para números, nombres y opciones. |
| **Texto Secundario** | `Color(0.50, 0.54, 0.58, 0.85)` | Gris mate para unidades de telemetría y descripciones secundarias. |

---

## 3. Componente: Panel de Vidrio Templado (Glassmorphic)

Para diálogos modales o ventanas grandes en pantalla (ej. tienda de licencias, reglas de conducción, contenedor de tableta):

### Dimensiones Estándar
* **Uso General / Lectura Móvil**: Mínimo `Vector2(1100, 680)`.
* **Margen Interno (Content Margin)**: 25 - 45 px en todos los lados.
* **Separación de VBox**: 20 - 30 px.

### Estilo de Fondo (StyleBoxFlat)
```gdscript
var style = StyleBoxFlat.new()
style.bg_color = Color(0.06, 0.07, 0.08, 0.95)   # Vidrio ahumado profundo
style.border_width_left = 1
style.border_width_top = 1
style.border_width_right = 1
style.border_width_bottom = 1
style.border_color = Color(0.78, 0.81, 0.85, 0.22) # Borde gélido sutil
style.corner_radius_top_left = 12
style.corner_radius_top_right = 12
style.corner_radius_bottom_left = 12
style.corner_radius_bottom_right = 12
style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
style.shadow_size = 8
```

---

## 4. Tipografía y Jerarquías de Texto

La tipografía principal del proyecto es **Moderniz** (`res://recursos/fonts/Moderniz.otf`).

* **Títulos Principales**:
  * **Fuente**: `Moderniz.otf`
  * **Tamaño**: `36 - 48 px`.
  * **Color**: `Color(0.88, 0.90, 0.93, 0.95)` o Acento Ámbar `Color(0.88, 0.68, 0.28, 0.92)`.
* **Textos Descriptivos / Párrafos**:
  * **Fuente**: Sans-serif limpia y legible.
  * **Tamaño**: `24 - 28 px` para visibilidad en móviles.
  * **Color**: `Color(0.85, 0.87, 0.90, 0.95)`.
* **Textos HUD de Telemetría (Velocidad/Checkpoints)**:
  * **Fuente**: `Moderniz.otf`
  * **Tamaño**: `18` o `24 px` (hasta `56 - 64 px` para velocímetro).
  * **Color**: Blanco con sombra o contorno sutil.

---

## 5. Botones Interactivos (Action Buttons)

Los botones de confirmación o acción táctil:

* **Tamaño Mínimo Recomendado**: Altura de `65 - 80 px` para toque táctil ágil.
* **Esquinas Redondeadas (Corner Radius)**: `8 - 12 px`.
* **Fuente**: `Moderniz.otf` con tamaño **`24 - 32 px`**.
* **GDScript Template**:
```gdscript
var btn = Button.new()
btn.text = "CONTINUAR"
btn.custom_minimum_size = Vector2(0, 80)

var btn_st = StyleBoxFlat.new()
btn_st.bg_color = Color(0.08, 0.09, 0.11, 0.78)
btn_st.set_border_width_all(1)
btn_st.border_color = Color(0.78, 0.81, 0.85, 0.20)
btn_st.set_corner_radius_all(10)
btn_st.shadow_color = Color(0, 0, 0, 0.35)
btn_st.shadow_size = 5

btn.add_theme_stylebox_override("normal", btn_st)
btn.add_theme_font_override("font", preload("res://recursos/fonts/Moderniz.otf"))
btn.add_theme_font_size_override("font_size", 30)
```

---

## 6. Patrón Dashboard Cockpit 2 Columnas (Menús Interactivos)

Para pantallas complejas (ej. centro de configuraciones, personalización de tractomulas o talleres):
* **Columna Izquierda (~65% del ancho):** Grid con selectores táctiles segmentados (pills) para evitar desplegables aburridos e interruptores táctiles instantáneos `[ ● ACTIVADO ]` / `[ ○ DESACTIVADO ]`.
* **Columna Derecha (~35% del ancho):** Inspector interactivo en vivo que reacciona a cada ajuste:
  * Telemetría gráfica con carga de GPU, consumo de batería y target de FPS.
  * Probador de sonido con vúmetro visual animado y botones de test de claxon y motor.
  * Volante interactivo con física de autocentrado para calibrar la dirección antes de salir a la carretera.

---

## 7. Animación de Entrada Suave (Tweens)

Toda la UI modal debe aparecer con una transición de entrada dinámica:
```gdscript
panel.scale = Vector2(0.92, 0.92)
panel.modulate.a = 0.0
var tw = get_tree().create_tween().set_parallel(true)
tw.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
tw.tween_property(panel, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
```
