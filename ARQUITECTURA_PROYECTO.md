# 🏛️ Guía de Arquitectura y Estándares Titán — Nuestra Tierra 2.0

**Proyecto:** Nuestra Tierra 2.0 (Godot 4 Mobile / Jolt Physics)  
**Idioma Oficial:** Español  
**Versión de Arquitectura:** 4.0.0 (Titán Masivo)  
**Objetivo:** Soportar desarrollo de escala masiva a largo plazo (multiciudades, flotas de camiones pesados, empresas de transporte, economía real y servidores dedicados) con cero roturas.

---

## 📁 Estructura Oficial de Directorios

```
nuestra-tierra-2.0/
│
├── 📁 .agents/                  # Reglas del proyecto, estándares de código y directrices de IA
├── 📁 addons/                  # Plugins de terceros del motor (Firebase, AdMob, Sky3D, Jolt)
├── 📁 android/                 # Plantillas y configuraciones de compilación Android
├── 📁 compilaciones/           # APKs, PCKs y binarios exportados [Ignorado en Git]
├── 📁 herramientas/            # Scripts de análisis, verificación de integridad y optimización
├── 📁 documentacion/           # Base de conocimiento viva
│   ├── diseno_juego/           # GDD, economía de fletes y mecánicas
│   ├── interfaz_ui/            # Manual oficial de diseño UI Glassmorphic
│   └── legal/                  # Contratos de modeladores y acuerdos
│
├── 📁 datos/                   # EL CORAZÓN DE DATOS (Agregar contenido sin tocar código)
│   ├── usuario/                # DatosUsuario.gd (guardado y sincronización Firestore)
│   └── vehiculos/              # Fichas técnicas (.tres)
│       └── fichas_tecnicas/    # Curvas de torque, masas, frenos y transmisión
│
├── 📁 codigo/                  # CÓDIGO FUENTE (Lógica Pura y Programación GDScript)
│   ├── nucleo/                 # KERNEL DEL MOTOR
│   │   ├── red/                # Network.gd, PlayersManager.gd, RedManager.gd
│   │   └── sistema/            # SettingsManager.gd, ConfigManager.gd, FPScontador.gd
│   ├── sistemas/               # SUBSISTEMAS VIVOS
│   │   ├── entorno/            # OptimizadorMapa.gd, AguaRealista.gd, VientoArboles.gd
│   │   ├── interactivos/       # Puertas, persianas santamaría, placas y espejos
│   │   ├── taller/             # taller_personalizacion.gd, ConcesionarioVehiculo.gd
│   │   └── logistica/          # Mensajero.gd, BaseMensajero.gd, puntos de carga
│   ├── entidades/              # ACTORES DEL MUNDO
│   │   ├── jugador/            # player.gd, DañoJugador.gd
│   │   └── vehiculo/           # InputVehiculo.gd, brazo_camara.gd, físicas y marchas
│   └── celular/                # CelularUI.gd, TutorialCelular.gd, GPSRouter.gd
│
├── 📁 interfaz/                # SISTEMA VISUAL Y MENÚS (Glassmorphic NT)
│   ├── pantallas/              # Pantallas completas
│   │   ├── menu_principal/     # Main-Menu.tscn y controladores
│   │   ├── perfil/             # Perfil_Menu.tscn
│   │   ├── configuraciones/    # configuraciones.tscn
│   │   ├── carga/              # escena_carga.tscn
│   │   ├── multijugador/       # LobbyMultijugador.tscn
│   │   ├── tienda/             # Tienda.tscn, MenuPersonalizacion.tscn
│   │   └── login/              # Login.tscn
│   ├── hud/                    # Elementos en pantalla en vivo
│   │   ├── conduccion/         # UIVehiculo.tscn, Dashboard.tscn, pedales y volante
│   │   └── a_pie/              # Botones táctiles de movimiento a pie
│   ├── celular/                # Smartphone NT
│   │   ├── sistema/            # CelularUI.tscn y marco táctil
│   │   └── aplicaciones/       # Mini-apps (input_app, tireinfo_app, render_stats)
│   ├── soporte/                # Sistema de tickets Discord y ayuda
│   ├── shaders/                # Centralización de shaders de interfaz (.gdshader)
│   └── sistema/                # MenuSystem.tscn, MenuUI.tscn, InventarioUI.tscn
│
├── 📁 mundo/                   # ESCENARIOS Y CIUDADES
│   ├── principal/              # Principal.tscn (mapa urbano y ciclo día/noche)
│   ├── pruebas/                # Pistas de pruebas de vehículos
│   └── logistica/              # Hubs de carga y entrega
│
├── 📁 contenido/ y recursos/   # ASSETS DE PRODUCCIÓN
│   ├── audio/ y recursos/audio # Motores, efectos, cornetas y música de radio
│   ├── fuentes/                # Moderniz, Nexa, Dealerplate
│   ├── materiales/             # Shaders PBR y materiales de terreno (.tres)
│   ├── modelos3d/              # Modelos 3D de mapa, personajes, tráfico y vehículos
│   └── shaders/                # Shaders de agua, viento, cielo realista y zonas
│
└── 📁 Scripts/ & escenas/      # Directorios con puentes automáticos de retrocompatibilidad
```

---

## 🔒 Reglas para Mantener la Arquitectura Intacta

1. **Retrocompatibilidad Automática**:
   Las rutas anteriores (`res://Scripts/...`, `res://escenas/...`, `res://Datos/...`) contienen scripts puente que heredan de las nuevas rutas canónicas (`extends "res://codigo/..."` y `extends "res://interfaz/..."`). El motor nunca sufrirá de referencias faltantes.
2. **Nuevas Funcionalidades**:
   - Todo nuevo script de lógica debe crearse dentro de `codigo/` en su submódulo correspondiente.
   - Toda nueva interfaz o HUD debe crearse en `interfaz/`.
   - Toda nueva pista o sector del mapa debe crearse en `mundo/`.
   - Toda nueva ficha técnica de motor o vehículo debe crearse en `datos/vehiculos/fichas_tecnicas/`.
3. **Validación Continua**:
   Ante cualquier cambio masivo futuro, ejecutar el comando:
   `python herramientas/verificar_integridad.py`
