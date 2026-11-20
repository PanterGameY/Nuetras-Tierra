# Devlog — Actualización Nuestra Tierra 2.0

Registro de novedades, optimizaciones, correcciones y mejoras jugables implementadas en esta actualización.

---

## 1. Nuevo Camión Isuzu NPR Optimizado (Licencia C2)
- **Optimización de malla 3D**: Reducción de vértices del **78.1%** y de triángulos del **61.3%** conservando intacta la silueta de la cabina, el tráiler plataforma y los detalles interiores.
- **Ruedas y jerarquía modular**: Incorporación de llantas cromadas con doble rueda trasera, organización limpia en Emptys y montaje automático mediante `npr_setup_modular.gd`.
- **Interior completo y volante funcional**:
  - Texturizado completo de tablero, cojinería, puertas, piso, pomo de cambios, radio, botonera y clúster de instrumentos retroiluminado.
  - Asientos con renderizado a doble cara (`CULL_DISABLED`) para evitar caras invertidas.
  - Eje y centro del volante calibrados al centro real del aro para un giro concéntrico de `780°`.
- **Iluminación completa**: Faros delanteros (`LucesDelanteras`), luces traseras/freno (`LuzStop`) y direccionales/estacionarias (`Direccionales`) conectadas a las mallas emisivas del modelo.
- **Espejos retrovisores funcionales**: Espejo izquierdo, espejo derecho y espejo auxiliar gran angular con renderizado en tiempo real en vista interior, reactivación automática al bajar/subir del camión y zoom óptico al enfocar los retrovisores.
- **Cristales claros**: Ventanas laterales y panorámico calibrados con transparencia automotriz nítida desde cabina.

## 2. Físicas, Suspensión, Cámaras y Partículas
- **Altura y tracción**: Corrección de altura de suspensión al spawnear, fichas técnicas dedicadas (`NPR_Vehiculo.tres`, `NPR_Motor.tres`) y transmisión diésel de 6 velocidades con aceleración y frenado ágiles.
- **Dinámica de peso y curvas**: Balanceo de carrocería y cabeceo rápido en frenadas/aceleraciones sin levantamiento exagerado ni vibraciones parásitas del motor.
- **Cámara interior acoplada al chasis**: La cámara en cabina acompaña físicamente la posición y rotación del chasis en curvas y cabeceos, con asiento neumático y enfoque ampliado hacia los espejos.
- **Cámaras simplificadas**: En la NPR se dejaron únicamente la **Cámara Exterior 360°** y la **Cámara Interior**.
- **Partículas de polvo mejoradas**: Las ruedas ahora solo emiten polvo en tierra, barro, arena o pasto real (nunca sobre asfalto/pavimento) con textura radial suave.

## 3. Academia de Licencias (C1, C2 y C3) y Tienda
- **Prueba de reversa**: Se añadió maniobra obligatoria de alineación y **estacionamiento en reversa** en bahía para las licencias C1, C2 y C3 (11 pruebas por categoría).
- **Reintento de pruebas en Tienda**: Las licencias ya adquiridas ahora permiten **Reintentar Prueba** desde la tienda con una tarifa reducida del **20%** (`$ 30.000` C1, `$ 90.000` C2, `$ 180.000` C3).
- **Spawn fijo en exámenes**: Las pruebas de licencia ya no guardan ni restauran la ubicación del jugador, iniciando siempre en el punto de partida de la academia.

## 4. Tractomula, Tráiler, HUD y Persistencia
- **Enganche de tráiler (C3)**: Se ajustó la colisión inferior del tráiler `Carpado` y se añadió excepción física temporal al aproximarse con la quinta rueda para acoplar sin choques ni rebotes.
- **HUD de conducción (`UIVehiculo`)**: Volante táctil ampliado (`490 × 490` px) y sensibilidad ajustada (`0.72`) para maniobras más precisas.
- **Batería de la tableta**: Tasas de descarga calibradas a valores realistas (~25 minutos de uso continuo abierta y >2 horas en reposo cerrada).
- **Persistencia de ubicación del camión**: El camión ahora guarda y restaura su posición y rotación en el mapa principal (`DatosUsuario.vehiculos_posiciones`) al bajarse y durante el autoguardado.
- **Personaje del jugador**: Eliminada la animación *idle* cuando el jugador permanece quieto.

## 5. Tractomula Kenworth T800 Alargada (Reconstrucción, Retopología y Audio 3D)
- **Consolidación de escena**: Se eliminaron las escenas duplicadas (`t800.tscn`, `800_Modular.tscn`), redirigiendo `GarajeBodega.gd` y `MultiplayerManager.gd` a `T800_A.tscn`.
- **Retopología y limpieza en Blender (`T800_Alargada.blend` / `T800_Alargada.glb`)**: Optimización de malla y sombreado (`Edge Split` + `Weighted Normal`) en cabina, filtros, escapes y accesorios conservando las 6 ruedas originales intactas; organización en jerarquía modular limpia (`Cabina_Exterior`, `Interior_Cabina`, `Cristales_y_Espejos`, `Chasis_y_Suspension`, `Ruedas`) y corrección de normales invertidas en suelo interior, `Puertas` y marcadores del tablero (`Fondo_panel`).
- **Escena heredada limpia y texturizado completo (`T800_A.tscn`)**: Reconstruida desde cero heredando directamente de `T800_Alargada.glb` con raíz `RigidBody3D` (~34 KB frente a ~4.86 MB previos), con materiales `.tres` externos para carrocería, cromados, faros emisivos, gomas, llantas/rines y las superficies diferenciadas del tablero e interior (`t800_setup_modular.gd`).
- **Palanca de cambios animada**: Agrupación de `palanca_003` y `Pomo` bajo `Palanca_Pivot` con inclinación suave en patrón en H sincronizada con `InputVehiculo.marcha` y `Motor._current_gear`.
- **Audio 3D de proximidad**: Ajuste de atenuación en `SonidoVehiculoPesado.gd` y `T800_A.tscn` (`alcance_sonido = 3.5` m, `distancia_maxima = 28.0` m) en los 15 canales `AudioStreamPlayer3D` del motor, turbo, frenos, válvulas, reversa y bocina.
