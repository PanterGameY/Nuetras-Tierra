# ARQUITECTURA TÉCNICA DEL SISTEMA DE CARRETERAS
## Nuestra Tierra 2.0 — Red Vial Paramétrica y Topología de Red

---

### 1. Principios de Diseño Arquitectónico

1. **Separación de Capas:** La lógica matemática y topológica de la red vial es completamente agnóstica de la interfaz de usuario y del renderizado.
2. **Topología de Grafo Explícita:** La red se estructura como un grafo conexo orientado donde las entidades fundamentales son **Nodos** (`NetNode`) y **Segmentos** (`NetSegment`).
3. **Generación Geométrica Determinista:** A partir de los parámetros del nodo, la curva y el perfil transversal, la geometría (`ArrayMesh`) se reconstruye de forma predecible sin depender del historial de clics del usuario.
4. **Desempeño Híbrido (Dual-Path C++ / GDScript):** Los cálculos de alta intensidad (discretización de arcos, cálculo de frames ortonormales, triangulación y ensamble de buffers de vértices) se ejecutan a nivel nativo en C++ (`MapBuilderSplineFast`) con fallback transparente en GDScript para entornos de depuración.

---

### 2. Diagrama de Arquitectura y Clases

```mermaid
classDiagram
    class RoadNetwork {
        +Dictionary nodos
        +Dictionary segmentos
        +Dictionary intersecciones
        +crear_nodo(posicion, tipo) NetNode
        +crear_segmento(nodo_a, nodo_b, perfil, modo_curva) NetSegment
        +dividir_segmento(segmento_id, offset) NetNode
        +eliminar_segmento(segmento_id)
        +eliminar_nodo(nodo_id)
        +reconstruir_afectados(lista_ids)
    }

    class NetNode {
        +int id
        +Vector3 posicion
        +Vector3 tangente_referencia
        +int tipo_union
        +Array~int~ segmentos_conectados
        +Dictionary metadata
    }

    class NetSegment {
        +int id
        +int nodo_inicio_id
        +int nodo_fin_id
        +Curve3D curva_eje
        +RoadProfile perfil
        +int modo_trazado
        +float longitud_baked
        +MeshInstance3D malla_calzada
        +MeshInstance3D malla_senales
        +MeshInstance3D malla_aceras
        +StaticBody3D cuerpo_colision
    }

    class RoadProfile {
        +int tipo_via
        +float ancho_carril
        +int numero_carriles
        +bool tiene_separador
        +float ancho_separador
        +bool acera_izquierda
        +bool acera_derecha
        +float ancho_acera
        +float ancho_berma
        +float alto_bordillo
        +obtener_ancho_total() float
        +obtener_puntos_corte() Array
    }

    class MapBuilderSplineFast {
        +calcular_arco_circular_tangente()
        +calcular_tangente_salida_arco()
        +calcular_curva_rapida_2puntos()
        +construir_malla_tramo_vial()
        +construir_malla_cruce_procedural()
    }

    RoadNetwork "1" *-- "many" NetNode
    RoadNetwork "1" *-- "many" NetSegment
    NetSegment --> RoadProfile
    RoadNetwork ..> MapBuilderSplineFast : Aceleración Nativa
```

---

### 3. Modelo Matemático de Trazado de Curvas

#### 3.1. Arco Circular de Radio Constante por Tangente de Entrada
Dado un punto de inicio $P_0$, un punto final $P_1$, y un vector tangente unitario de entrada $\vec{T}_0$ (determinado por el tramo anterior o alineado por el usuario):
1. Vector cuerda en el plano horizontal $XZ$:
   $$\vec{C} = (P_1 - P_0)_{xz}, \quad L = \|\vec{C}\|, \quad \vec{u}_c = \frac{\vec{C}}{L}$$
2. Ángulo de deflexión $\alpha$ entre la tangente inicial $\vec{T}_0$ y la cuerda $\vec{u}_c$:
   $$\sin(\alpha) = (\vec{T}_0 \times \vec{u}_c)_y, \quad \cos(\alpha) = \vec{T}_0 \cdot \vec{u}_c, \quad \alpha = \operatorname{atan2}(\sin\alpha, \cos\alpha)$$
3. Si $|\alpha| < 0.015\text{ rad}$, el tramo se considera una recta perfecta.
4. Para arcos reales, el radio constante de curvatura $R$ es:
   $$R = \frac{L}{2 |\sin\alpha|}$$
5. El centro de curvatura $O$ se ubica desplazándose perpendicularmente a la tangente:
   $$\vec{N}_0 = \operatorname{sign}(\alpha) \cdot (-\vec{T}_{0,z}, 0, \vec{T}_{0,x}), \quad O = P_0 + R \vec{N}_0$$
6. El ángulo total del arco subtendido es $\theta_{\text{total}} = 2 |\alpha|$. Para cualquier parámetro $u \in [0, 1]$:
   $$P(u) = O - R \cos(u \cdot \theta_{\text{total}}) \vec{N}_0 + R \sin(u \cdot \theta_{\text{total}}) \vec{T}_0 + \left(0, \operatorname{lerp}(P_{0,y}, P_{1,y}, u), 0\right)$$
7. **Tangente Unitaria de Salida $\vec{T}_1$:**
   $$\vec{T}_1 = 2 (\vec{T}_0 \cdot \vec{u}_c) \vec{u}_c - \vec{T}_0$$
   Esta fórmula exacta permite encadenar arcos sucesivos en **2 clics continuos** garantizando continuidad $C^1$ impecable.

---

### 4. Ciclo de Vida y Reconstrucción por Dependencias

```mermaid
sequenceDiagram
    participant Usuario as Usuario (Toque / Gestos)
    participant UI as EditorMapaUI
    participant E3D as EditorMundo3D
    participant CV as ConstructorVial (RoadNetwork)
    participant Terreno as TerrenoChunkManager
    participant Nativo as MapBuilderSplineFast (C++)

    Usuario->>UI: Toque en Pantalla (Añadir / Mover Nodo)
    UI->>E3D: Evento táctil filtrado (Fuera de UI)
    E3D->>CV: agregar_punto_vial / mover_nodo
    CV->>CV: Calcular Arco Circular / Tangentes
    CV->>Terreno: Consultar alturas y aplanar márgenes
    CV->>Nativo: construir_malla_tramo_vial
    Nativo-->>CV: ArrayMesh (Calzada, Aceras, Señales 3D)
    CV->>CV: Detectar cruces en nodos afectados
    CV->>Nativo: construir_malla_cruce_procedural
    CV-->>E3D: Señal red_vial_actualizada
    E3D-->>UI: Actualizar Telemetría y HUD
```

---

### 5. Estructura de Persistencia (.ntmap)

El modelo topológico se guarda en formato JSON comprimido en la sección `"red_vial"`:
```json
{
  "version": 2.0,
  "nodos": [
    { "id": 1, "pos": [120.5, 5.0, -84.2], "tipo_union": 0, "segmentos": [101, 102] }
  ],
  "segmentos": [
    {
      "id": 101,
      "nodo_inicio": 1,
      "nodo_fin": 2,
      "tipo_via": 0,
      "modo_curva": 2,
      "es_puente": false,
      "con_acera_izq": false,
      "con_acera_der": false,
      "ancho_acera": 2.0,
      "puntos_curva": [[120.5, 5.0, -84.2], [145.2, 5.0, -60.1]]
    }
  ]
}
```
Esta especificación mantiene retrocompatibilidad completa con los mapas previamente guardados y permite reconstruir la red en cualquier plataforma sin pérdida de precisión.
