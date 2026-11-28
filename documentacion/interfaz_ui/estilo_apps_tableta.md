# Estilo Visual Oficial para Aplicaciones de la Tableta (`CelularUI`)

Guía de referencia extraída de la app de **Ajustes** en [CelularUI.gd](file:///c:/Users/johan/OneDrive/Documentos/GitHub/nuestra-tierra-2.0/codigo/celular/CelularUI.gd#L4354-L4830) para mantener consistencia en todas las demás aplicaciones de la tableta.

## 1. Reglas Generales de Diseño
- **Texto limpio**: Todo en MAYÚSCULAS, **sin tildes ni `ñ`** (compatibilidad total con `Moderniz.otf`).
- **Tipografía**: `res://recursos/fonts/Moderniz.otf` en títulos, botones, chips, sliders y toggles.
- **Navegación**: Sin botones de `Home` ni `Regresar` dentro del encabezado de la app; se usa únicamente la barra inferior de la tableta (`◀ REGRESAR` | `⌂ INICIO`, botones `360×74px`, fuente `26px`).
- **Márgenes del contenido**: `MarginContainer` con `margin_left = 70`, `margin_right = 70`, `margin_top = 28`, `margin_bottom = 28`, separación vertical `18px`, ocupando el ancho disponible (`SIZE_EXPAND_FILL`).
- **Scroll táctil**: `VScrollBar` de `36px` de ancho, pista `Color(0.06, 0.07, 0.08, 0.75)` y *grabber* `Color(0.88, 0.68, 0.28, 0.85)` (`1.0` en hover/pressed), `corner_radius = 14`.

## 2. Tarjeta Base (`_make_settings_card_shell`)
- **Contenedor**: `PanelContainer`, `custom_minimum_size = Vector2(0, 92)` (`Vector2(0, 104)` y `SIZE_EXPAND_FILL` vertical en menú de categorías).
- **Fondo y Borde**: `bg_color = Color(0.09, 0.10, 0.12, 0.90)`, borde `1px` `Color(0.78, 0.81, 0.85, 0.22)`, `corner_radius = 12`, `shadow_color = Color(0, 0, 0, 0.40)`, `shadow_size = 5`, padding `24px` horizontal / `14px` vertical.
- **Hover**: `bg_color = Color(0.13, 0.15, 0.18, 0.95)`, borde `Color(0.88, 0.68, 0.28, 0.92)`.
- **Acento izquierdo**: `ColorRect` de `4×42px` en `Color(0.88, 0.68, 0.28, 0.92)` (`Automotive Instrument Amber`).

## 3. Componentes Estándar
- **Categorías / Botones de acción**: Solo título (`34px` en categorías, `26px` en opciones) + indicador `>` a la derecha en ámbar. Sin descripciones.
- **Chips de selección (`_make_settings_chip_card`)**: Título `26px` + fila de botones `72px` de alto, fuente `24px` (`Moderniz.otf`), activo en ámbar `Color(0.88, 0.68, 0.28, 0.92)` con texto oscuro `Color(0.06, 0.07, 0.08, 1.0)`.
- **Sliders (`_make_settings_slider`)**: Título `26px` + `HSlider` (`56px` alto) con pista gruesa (`content_margin_top/bottom = 12`) y tirador circular ámbar de `44×44px` (`_crear_grabber_ajustes(22)`).
- **Toggles / Switch (`_make_settings_toggle`)**: Título `26px` + interruptor de `88×46px` con perilla circular de `36×36px` (`Color(0.88, 0.68, 0.28, 0.92)` activo / `Color(0.06, 0.07, 0.09, 0.95)` inactivo).
