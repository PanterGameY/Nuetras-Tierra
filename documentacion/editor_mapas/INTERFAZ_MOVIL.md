# GUÍA DE DISEÑO E IMPLEMENTACIÓN UI/UX MÓVIL: SISTEMA VIAL Y EDITOR DE MAPAS

## 1. Filosofía Mobile-First y Automotive Glassmorphism

El editor de mapas de *Nuestra Tierra 2.0* está concebido para funcionar de manera óptima y fluida en dispositivos móviles táctiles (Android). Un error común al portar herramientas de escritorio a plataformas móviles es saturar la pantalla con menús anidados, campos de texto diminutos o barras de botones diseñadas para ratón.

Nuestra interfaz aplica los principios del **Cockpit Automotriz de Alto Rendimiento (Glassmorphic Theme)**:
- **Espacio de Juego Despejado:** El mapa 3D y la traza de la carretera ocupan el 100% del viewport; los controles flotan sin invadir el campo visual de trazado.
- **Zonas Ergonómicas del Pulgar:** Controles de modo y selección agrupados en el pulgar izquierdo; acciones de confirmación, elevación, snapping y deshacer en el pulgar derecho.
- **Feedback Háptico y Visual Inmediato:** Cada interacción táctil reacciona con micro-animaciones (Tweens de escala `0.92` a `1.0`, modulación alfa `0.0` a `1.0` en `0.25s - 0.35s`) y estados de color contrastantes.

---

## 2. Paleta Cromática y Estilos Visuales (Design System)

| Componente | Valor Color Godot (`Color`) | Hex / Opacidad | Propósito UI |
| :--- | :--- | :--- | :--- |
| **Fondo Cockpit Glass** | `Color(0.06, 0.07, 0.08, 0.90)` | `#0f1214` @ 90% | Bandejas inferiores, barras de estado y paneles contextuales |
| **Tarjetas / Contenedores** | `Color(0.09, 0.10, 0.12, 0.92)` | `#171a1f` @ 92% | Contenedor de herramientas, selector de perfiles de vía |
| **Bordes Frost Metallic** | `Color(0.78, 0.81, 0.85, 0.22)` | `#c7cfd9` @ 22% | Línea de 1px perimetral para efecto de cristal satinado |
| **Instrument Amber (Activo)** | `Color(0.88, 0.68, 0.28, 0.95)` | `#e0ad47` @ 95% | Botón de herramienta activa, trazado de preview, arcos angulares |
| **Technical Crimson (Cierre/Peligro)** | `Color(0.78, 0.28, 0.26, 0.95)` | `#c74742` @ 95% | Cancelar trazado, demoler tramo, cerrar inspector |
| **Asphalt Frost (Botones base)** | `Color(0.08, 0.09, 0.11, 0.80)` | `#14171c` @ 80% | Botones inactivos con radios redondeados de `8-12px` |
| **Pintura Vial Marcadores** | `Color(0.96, 0.97, 0.98, 1.00)` | `#f5f7fa` | Etiquetas 3D de distancia, radio y grados de curvatura |

---

## 3. Jerarquía Tipográfica (`Moderniz.otf`)

- **Títulos de Herramienta / Modo Activo:** `36 - 48 px` (Alto impacto, legible a 40 cm de distancia).
- **Botones de Acción Rápida:** `24 - 32 px` (Acompañados de iconografía vectorial monocroma o emoji de alta visibilidad).
- **Telemetría Flotante 3D (CS2 HUD):** `20 - 28 px` con `Label3D` (Ángulo entre tangentes, radio del arco $R$, longitud $L$, pendiente $\%$, coste estimado).
- **Subtítulos y Telemetría Secundaria:** `14 - 24 px` (Estado de snapping a rejilla o nodos, elevación relativa $\Delta h$).

---

## 4. Dimensiones Táctiles y Ergonometría (Touch Targets)

Para evitar toques erráticos en pantallas táctiles con densidades altas (xxhdpi / xxxhdpi):
- **Objetivo Táctil Mínimo:** `48 x 48 dp` (Físicamente $\approx 9\text{ mm}$, garantizando el estándar Android Material Design).
- **Botones Principales de Construcción:** `64 x 64 dp` a `72 x 72 dp` para toggles de trazado (`Recta`, `Arco`, `Curva`).
- **Separación entre Elementos Interactivos:** Mínimo `8 - 12 dp` de padding/margin para mitigar pulsaciones simultáneas accidentales.
- **Deadzone Perimetral:** Las áreas táctiles excluyen los bordes extremos de pantalla (`16 dp` de margen) para prevenir gestos involuntarios del sistema operativo (navegación por gestos de Android).

```
+-------------------------------------------------------------------------+
| [Escena 3D / Trazado Vial Activo]                                       |
|                                                                         |
|                HUD Telemetría Flotante CS2:                             |
|                [ ∡ 132° ] ---- ( R = 45m ) ---- [ 172 m ]               |
|                                                                         |
| (Pulgar Izquierdo)                                   (Pulgar Derecho)   |
| +-------------------------+                     +---------------------+ |
| | [📏 Recta] [📐 Arco]     |                     | [▲ +1m Elevación]   | |
| | [↪️ Continua]            |                     | [▼ -1m Elevación]   | |
| |-------------------------|                     |---------------------| |
| | [Calle] [Avenida] [Auto]|                     | [🧲 Snap] [↩️ Undo]  | |
| +-------------------------+                     +---------------------+ |
|                                                                         |
| [================ Barra Inferior de Categorías =======================] |
+-------------------------------------------------------------------------+
```

---

## 5. Desambiguación de Gestos Táctiles vs. Cámara Orbital

Uno de los mayores retos en constructores de ciudades móviles es evitar que el jugador rote o mueva la cámara accidentalmente mientras intenta colocar un nodo o ajustar una curva.

### Máquina de Estados de Entrada (`InputFilterManager`)
1. **Toque sobre Control UI (`mouse_filter = Control.MOUSE_FILTER_STOP`):**
   - Consume inmediatamente el evento táctil (`accept_event()`).
   - El sistema de cámara y el raycast de terreno quedan desactivados en ese frame.
2. **Un Solo Dedo sobre Terreno (Tap Simple / Click Down + Up con $\Delta < 15\text{ px}$):**
   - Interpretado como fijación o previsualización de nodo vial (`ConstructorVial.procesar_click_nodo`).
3. **Un Solo Dedo con Desplazamiento ($\Delta > 20\text{ px}$ sostenido):**
   - Si no hay nodo en arrastre de tangente: activa rotación de órbita suave (`CamaraEditor3D`).
   - Si se está editando una tangente o punto de control: actualiza la posición del nodo en tiempo real sin orbitar la cámara.
4. **Dos Dedos Simultáneos (Pinch / Spread / Two-finger Pan):**
   - Bloquea la colocación de nodos inmediatamente.
   - Controla zoom de cámara mediante distancia entre dedos ($\Delta d$) y paneo horizontal en el plano $XZ$.
5. **Pulsación Prolongada (Long-Press $> 450\text{ ms}$):**
   - Abre el inspector contextual del nodo o tramo vial (opciones: *Demoler tramo*, *Cambiar perfil*, *Convertir en rotonda*, *Alinear tangentes*).

---

## 6. HUD de Telemetría Dinámica Inspirado en Cities: Skylines 2

Al trazar una carretera, el usuario recibe retroalimentación espacial en 3D en tiempo real:

1. **Indicador de Arco Angular ($\theta^\circ$):**
   - Se proyecta un semi-círculo segmentado entre la tangente de entrada $\vec{T}_0$ y la dirección hacia el cursor.
   - El color del arco es ámbar suave si el ángulo es cómodo ($> 90^\circ$) y vira progresivamente a rojo técnico si el ángulo es excesivamente cerrado ($< 45^\circ$, advirtiendo de radio peligroso o pellizco de calzada).
2. **Insignia de Radio de Curvatura ($R$ en metros):**
   - Calcula $R = \frac{\|\vec{C}\|}{2 \sin(\theta/2)}$ y lo muestra centrado en el foco de la curva circular.
3. **Insignia de Longitud y Pendiente:**
   - Ubicada en el punto medio del segmento preview. Muestra metros recorridos ($L$) y porcentaje de pendiente ($G = \frac{\Delta y}{\Delta xz} \times 100\%$).
4. **Cálculo de Presupuesto en Tiempo Real:**
   - Etiqueta emergente con el coste en pesos colombianos ficticios ($\text{COP} \$$) proporcional a la longitud, anchura y volumen de corte/relleno del terreno.
