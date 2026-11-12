# PROTOCOLO DE PRUEBAS Y BANCO DE VERIFICACIÓN (QA)

## 1. Alcance de las Pruebas

El sistema de carreteras e intersecciones de *Nuestra Tierra 2.0* cuenta con una matriz exhaustiva de pruebas unitarias, de integración, rendimiento móvil y persistencia de datos. Cada prueba especifica las precondiciones, el procedimiento de ejecución y los criterios de aceptación matemática y visual.

---

## 2. Matriz de Pruebas Unitarias (Matemática y Geometría)

| Identificador | Caso de Prueba | Algoritmo Evaluado | Criterio de Éxito |
| :--- | :--- | :--- | :--- |
| **UNIT-ARC-01** | Arco circular tangencial 2-puntos | `calcular_arco_circular_tangente` | Radio constante $R$ con desviación $\|\vec{P}(t) - \vec{O}\| - R < 0.001\text{ m}$. Tangente de entrada colineal a $\vec{T}_0$. |
| **UNIT-ARC-02** | Continuidad $C^1$ en encadenado | `calcular_tangente_salida_arco` | La tangente de salida del tramo $A$ coincide exactamente con el vector de entrada del tramo $B$. Sin quiebres visuales. |
| **UNIT-GEO-01** | Ortogonalidad de marco Frenet | $\vec{N} = \vec{T} \times \vec{U}$ | $\vec{N} \cdot \vec{T} = 0.0 \pm 10^{-6}$ y $\|\vec{N}\| = 1.0$ en el 100% de las subdivisiones transversales. |
| **UNIT-GEO-02** | Anti-pellizco en curvas cerradas | Clamp de factor Miter | En curvas con radio $R < 15\text{ m}$, el borde interior nunca invierte su orden de devanado (winding order) ni colapsa. |
| **UNIT-INT-01** | Ordenamiento angular de brazos | `atan2(dir.z, dir.x)` | Ángulos estrictamente monótonos crecientes en rango $[-\pi, +\pi]$. Detección exacta de brazos adyacentes. |
| **UNIT-INT-02** | Acordamiento Fillet Tangencial | $T = R / \tan(\theta/2)$ | Puntos de contacto de calzadas coincidentes con los extremos de aceras de tramos incidentes con error $< 0.005\text{ m}$. |

---

## 3. Matriz de Pruebas de Integración (Construcción en Editor)

### PRUEBA-INT-01: Trazado Continuo en 2 Clics
- **Objetivo:** Verificar que al colocar un nodo inicial y uno final, la carretera se cree de inmediato y el cursor quede listo para el siguiente tramo sin duplicar segmentos previos.
- **Pasos:**
  1. Activar modo `↪️ Curva Continua`.
  2. Tocar punto $A (0, 0, 0)$.
  3. Tocar punto $B (50, 0, 30)$.
  4. Tocar punto $C (100, 0, 80)$.
- **Resultado Esperado:** Dos tramos concatenados con transición suave en el nodo $B$. En la jerarquía de nodos no existen mallas duplicadas ni superpuestas en $A \to B$.

### PRUEBA-INT-02: Generación Automática de Cruce en T
- **Objetivo:** Conectar una carretera perpendicular a un tramo recto existente.
- **Pasos:**
  1. Trazar carretera principal de $(0,0,0)$ a $(100,0,0)$.
  2. Iniciar nuevo trazado desde $(50,0,50)$ hacia $(50,0,0)$ con snapping activo.
  3. Confirmar conexión.
- **Resultado Esperado:**
  - El tramo principal se divide limpiamente en dos subtramos.
  - Se genera el nodo de cruce central en $(50,0,0)$.
  - Las 3 calzadas se truncan a la distancia de seguridad $D_{\text{arm}}$.
  - Se generan los dos empalmes en esquina (fillets) de radio $R=6\text{ m}$ con aceras continuas sin hendiduras.

### PRUEBA-INT-03: Cruce Irregular de 4 y 5 Brazos
- **Objetivo:** Evaluar estabilidad del polígono central bajo ángulos oblicuos no ortogonales.
- **Pasos:**
  1. Crear un nodo central.
  2. Conectar 5 carreteras convergiendo en ángulos de $30^\circ$, $75^\circ$, $120^\circ$, $200^\circ$ y $290^\circ$.
- **Resultado Esperado:**
  - Triangulación en abanico sin caras invertidas ni normales oscuras.
  - Textura de asfalto alineada por proyección mundial (sin saltos de grano entre calzadas y el centro).

### PRUEBA-INT-04: Transición de Terreno con Pendiente y Puentes
- **Objetivo:** Trazar una carretera a través de una colina o depresión.
- **Pasos:**
  1. Establecer nodo de entrada a cota $y=0$.
  2. Establecer nodo de salida a cota $y=12\text{ m}$.
- **Resultado Esperado:**
  - El perfil vial acompaña la rasante longitudinal respetando la pendiente máxima permitida.
  - Al superar los 4 metros de despeje respecto al terreno base, se generan los pilares procedurales de soporte tipo puente.

---

## 4. Pruebas de Interacción Táctil y Ergonomía Móvil

1. **Aislamiento de Cámara vs. Construcción:**
   - Tocar y arrastrar con un solo dedo sobre el botón de modo vial: la cámara orbital **no** debe rotar.
   - Pizcar con dos dedos sobre el mapa mientras un nodo está en previsualización: el zoom debe ejecutarse con suavidad sin modificar la posición del nodo preview.
2. **Hitbox y Respuesta:**
   - Confirmación de toque en pantalla de 5.5" (1080x2400 px): los botones de la barra inferior se activan en el 100% de los intentos sin falsos toques entre elementos adyacentes.

---

## 5. Pruebas de Persistencia y Serialización (`.ntmap`)

1. **Guardado:** Guardar un mapa con 40 tramos, 12 intersecciones y distintos anchos de vía en formato JSON binario/texto.
2. **Carga en Frío:** Reiniciar el editor y cargar el archivo generado.
3. **Validación:**
   - Comparación topológica: igual número de nodos y segmentos.
   - Comparación geométrica: las mallas reconstruidas proceduralmente al cargar son idénticas en vértices y cotas a las guardadas en la sesión original.
   - El historial de deshacer/rehacer (`Undo/Redo`) se reinicia a estado limpio sin pérdidas de memoria.

---

## 6. Verificación Headless Automatizada en Godot

Comando oficial de ejecución en CI/CD o consola local:
```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --check-only --quit
```
- **Criterio de Validación:** Código de salida `0`, cero errores de análisis sintáctico (*Parser Errors*), cero variables sin tipar y cero accesos a propiedades inexistentes en tipos nativos.
