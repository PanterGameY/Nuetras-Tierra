# Sistema de Tráfico IA por Carriles (Path3D) y GPS 2D

Módulo auto-contenido y aislado para creación y gestión de redes viales de tráfico vehicular mediante nodos `Path3D`, intersecciones con semáforos, retornos en U (U-Turns) e integración con sistema de navegación GPS en 2D.

---

## 🚀 Componentes Principales

1. **`TrafficLane3D.gd`** (extends `Path3D`):
   - Define el eje o línea central de cada carril individual.
   - Configuración de límite de velocidad, tipo de carril (`NORMAL`, `RETORNO`, `CRUCE`, `ACELERACION`), ancho de carril y conexiones hacia carriles siguientes (`next_lanes`).
   - Herramientas de depuración visual en el editor 3D con colores personalizables.

2. **`TrafficIntersection3D.gd`** (extends `Node3D`):
   - Gestiona cruces de 3 y 4 vías, retornos U-Turn y rotondas.
   - Sistema de semáforos con fases configurables (`VERDE`, `AMARILLO`, `ROJO`) y temporización.
   - Cálculo automático de maniobras de navegación ("SIGA RECTO", "GIRE A LA DERECHA", "GIRE A LA IZQUIERDA", "RETORNO EN U").

3. **`TrafficNetworkManager3D.gd`** (extends `Node3D`):
   - Nodo principal que escanea y conecta la red vial.
   - Implementa algoritmo A* Pathfinding sobre las curvas 3D.
   - Generación (Spawner) y control de vehículos IA en tiempo real.

4. **`TrafficVehicleAgent3D.gd`** (extends `CharacterBody3D`):
   - Agente vehicular de IA con aceleración, frenado progresivo, sensores `RayCast3D` para evitar colisiones entre vehículos y detención automática ante luz roja o amarilla.

5. **`GPSManager2D.gd`** (extends `Node`):
   - Convierte coordenadas 3D del mundo `(X, Y, Z)` a coordenadas 2D del mapa `(X, Y)`.
   - Genera polilíneas 2D de navegación e instrucciones paso a paso.

6. **`GPSMapView2D.gd`** (extends `PanelContainer`):
   - Interfaz de usuario 2D alineada al manual de diseño `RULE[AGENTS.md]` (Glassmorphic estilo cyberpunk, fondo oscuro `Color(0.06, 0.06, 0.08, 0.9)`, bordes Naranja Neón `Color(1.0, 0.45, 0.0, 0.8)`, fuente `Moderniz.otf` y botones de `80px`).
   - Transiciones animadas con Tweens para entrada/salida suave.

---

## 🎮 Cómo Probar la Demostración

Abre la escena `res://sistema_trafico_gps/escena_demo_trafico_gps.tscn` en Godot y presiona **F6** (Ejecutar Escena Actual).

Verás el vehículo IA desplazándose por los carriles 3D en la pantalla y la interfaz interactiva del GPS 2D en tiempo real.
