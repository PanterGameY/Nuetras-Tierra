# 🚗 NUESTRA TIERRA - Proyecto Godot

**Estado:** En Desarrollo  
**Motor:** Godot 4.7
**Plataformas:** PC, Android (Mobile)

---

## 📋 DESCRIPCIÓN

Proyecto de simulación de conducción en Godot con soporte para vehículos, física realista, y UI responsiva para móviles. Sistema de menús integrado, HUD dinámico y controles de vehículo tanto para teclado como para touchscreen.

---

## 🎮 CARACTERÍSTICAS

✅ **Simulación de Vehículos**
- Física realista con motor, transmisión (P/R/N/D)
- Dirección táctil con sensorismo háptico
- Control de pedales (acelerador/freno)

✅ **UI Móvil**
- Interfaz adaptada para notches y safe areas
- Controles touchscreen responsivos
- Selector de marchas de 4 botones con feedback visual

✅ **Sistemas Integrados**
- Menú principal con transiciones
- HUD con velocímetro y información del vehículo
- Sistema de eventos y notificaciones
- Manager de juego singleton

✅ **Gráficos**
- Shaders personalizados para HUD y efectos
- Modelos 3D con iluminación
- Renderizado optimizado para mobile

---

## 📁 ESTRUCTURA DEL PROYECTO

```
nuetras-tierra/
├── scenes/                      # Escenas principales
│   ├── MainMenu.tscn           # Menú principal
│   ├── Player.tscn             # Escena del jugador
│   ├── Mapa.tscn               # Escena del mapa/mundo
│   ├── HUD.tscn                # HUD del juego
│   ├── UIVehiculo.tscn         # UI de vehículo
│   ├── gui/
│   │   ├── MenuSystem.tscn      # Sistema de menús
│   │   ├── UIVehiculo/          # Scripts y shaders de UI
│   │   ├── UIpie/               # Controles de pastel
│   │   └── movil/               # Interfaz móvil
│   ├── vehiculos/               # Escenas de vehículos
│   ├── chasis_efectos.gd
│   ├── CicloCielo.gd
│   ├── interactuar.gd
│   ├── notificaciones.gd
│   └── hud.gd
│
├── Scripts/                     # Scripts generales
│   ├── jugador/
│   │   ├── player.gd
│   │   └── (otros scripts del jugador)
│   └── vehiculos/
│       ├── motor/
│       └── llantas/
│
├── materiales/                  # Materiales (.tres)
│   ├── azul.tres
│   ├── cesped.tres
│   ├── Chasis.tres
│   ├── neon.tres
│   └── (otros materiales)
│
├── shaders/                     # Shaders personalizados
│   ├── HUD.gdshader
│   ├── LabesHUD.gdshader
│   ├── Player.gdshader
│   ├── Steering.gdshader
│   ├── PedalFreno.gdshader
│   ├── Velocimetro.gdshader
│   ├── MarchaBotonUniversal.gdshader
│   └── (otros shaders)
│
├── modelos3d/                   # Modelos 3D importados
│   ├── mapa/
│   ├── vehiculos/
│   └── trees.tscn
│
├── font/                        # Fuentes tipográficas
│   ├── King Gaming Free Trial.otf
│   └── bebas_neue/
│
├── sounds/                      # Recursos de audio
│
├── player/                      # Recursos del jugador
│   └── personajes/
│
├── project.godot                # Configuración del proyecto
├── export_presets.cfg           # Presets de exportación
├── icon.svg                     # Icono del proyecto
└── LICENSE
```

---

## 🚀 AUTOLOADS (Singletons)

Los siguientes scripts están cargados automáticamente:

- **InputVehiculo** - Gestor de entrada y estado del vehículo
- **GameManager** - Manager general del juego
- **MenuSystem** - Sistema de menús

---

## 🎯 ESCENAS PRINCIPALES

| Escena | Propósito | Estado |
|--------|-----------|--------|
| `MainMenu.tscn` | Pantalla de menú principal | ✅ Funcional |
| `Mapa.tscn` | Mundo/mapa jugable | ✅ Funcional |
| `Player.tscn` | Escena del jugador | ✅ Funcional |
| `HUD.tscn` | Interfaz del juego | ✅ Funcional |
| `UIVehiculo.tscn` | Controles de vehículo | ✅ Funcional |

---

## 🎮 CONTROLES

### PC
- **W/A/S/D** - Movimiento
- **Flecha Arriba/Abajo** - Acelerador/Freno
- **Flecha Izquierda/Derecha** - Dirección
- **E** - Interactuar
- **Shift** - Freno de mano

### Mobile (Touchscreen)
- **Zona de rueda** (izquierda abajo) - Dirección
- **Botones de marcha** (derecha abajo) - P/R/N/D
- **Pedales** (derecha abajo) - Acelerador/Freno
- **Botones superiores** - Motor, Freno de mano, Cámara, Salir

---

## 🔧 CONFIGURACIÓN

### Resolución
- **Viewport:** 2460x1080
- **Ventana Desarrollo:** 900x450
- **Modo Stretch:** Canvas Items (Expand)

### Características
- **Motores Soportados:** 4.6
- **Plataformas:** PC, Mobile (Android)
- **Icono:** `icon.svg`

---

## 📊 SISTEMA DE MARCHAS

El sistema de marchas está implementado en `SelectorMarchasNuevo.gd`:

- **P (Parqueo)** - Vehículo estacionado
- **R (Reversa)** - Marcha atrás
- **N (Neutro)** - Sin tracción
- **D (Drive)** - Conducción normal

Cada botón tiene feedback visual con shader personalizado y vibración háptica en móvil.

---

## 🎨 SHADERS PERSONALIZADOS

- **MarchaBotonUniversal.gdshader** - Botones del selector de marchas con glow
- **Steering.gdshader** - Efecto visual de la rueda de dirección
- **PedalFreno.gdshader** - Indicador de frenado
- **Velocimetro.gdshader** - Efecto del velocímetro

---

## 📱 SOPORTE MÓVIL

✅ Safe area handling para notches  
✅ Controles táctiles responsivos  
✅ Feedback háptico (vibración)  
✅ Orientación landscape  
✅ Optimización para baja latencia  

---

## 🐛 DESARROLLO

### Limpieza del Proyecto (01/03/2026)

Se realizó una limpieza completa:
- ✅ Eliminados 311 archivos temporales
- ✅ Eliminada documentación obsoleta
- ✅ Consolidados duplicados
- ✅ Organizada estructura de archivos
- ✅ Validadas todas las referencias

---

## 📝 LICENCIA

Ver archivo `LICENSE`

---

**Última Actualización:** 01 de Marzo de 2026  
**Mantenedor:** Johan  
**Estado del Proyecto:** En Desarrollo Activo
