# 🏛️ BIBLIOTECA DE ASSETS — EDITOR DE MAPAS (CITY BUILDER)
## Nuestra Tierra 2.0

Esta carpeta (`res://mundo/editor_mapas/Biblioteca/`) es el repositorio central, modular y escalable para todos los modelos 3D, props, edificaciones y elementos paisajísticos disponibles en el editor de mapas del juego.

Está inspirada en la arquitectura de bibliotecas de simuladores urbanos y city builders modernos (*Cities: Skylines, SimCity, Workers & Resources*), organizada por tipología funcional y sectores temáticos.

---

## 📁 Estructura de Categorías

```text
res://mundo/editor_mapas/Biblioteca/
│
├── 01_Edificaciones/
│   ├── 01_Residencial/
│   │   ├── Casas_Tradicionales/         # Casas de pueblo, estilo colonial y rural
│   │   ├── Casas_Modernas/              # Viviendas urbanas de 1 y 2 plantas
│   │   ├── Edificios_Apartamentos/      # Bloques residenciales y torres de vivienda
│   │   └── Conjuntos_Cerrados/          # Módulos habitacionales y condominios
│   │
│   ├── 02_Comercial/
│   │   ├── Tiendas_y_Locales/           # Panaderías, ferreterías, droguerías, tiendas de barrio
│   │   ├── Supermercados_CentrosComerciales/ # Grandes superficies y centros de compras
│   │   ├── Restaurantes_Cafes/          # Piqueteaderos, paraderos gastronómicos, cafeterías
│   │   ├── Estaciones_Servicio/         # Bombas de gasolina, servitecas, lavaderos
│   │   └── Hoteles_Hospedaje/           # Hoteles de paso, hostales, posadas turísticas
│   │
│   ├── 03_Industrial_Logistica/
│   │   ├── Bodegas_Almacenaje/          # Bodegas de carga, centros de distribución
│   │   ├── Fabricas_Plantas/            # Plantas de manufactura y producción
│   │   ├── Talleres_Mecanicos/          # Talleres de tractomulas, montallantas
│   │   └── Silos_Tolvas/                # Almacenamiento agroindustrial y tolvas de áridos
│   │
│   ├── 04_Servicios_Publicos/
│   │   ├── Salud/                       # Puestos de salud, clínicas, hospitales
│   │   ├── Seguridad_Emergencias/       # CAI, estaciones de policía, cuarteles de bomberos
│   │   ├── Educacion/                   # Escuelas rurales, colegios, bibliotecas
│   │   ├── Gobierno_Comunitario/        # Alcaldías, salones comunales, notarías
│   │   └── Servicios_Basicos/           # Subestaciones de energía, tanques de acueducto
│   │
│   └── 05_Rural_Agropecuario/
│       ├── Fincas_Haciendas/            # Casonas de finca, casas campestres
│       ├── Galpones_Establos/           # Corrales de ganado, galpones avícolas, porquerizas
│       └── Cultivos_Invernaderos/       # Invernaderos, zonas de beneficio de café
│
├── 02_Monumentos_Hitos/
│   ├── 01_Religiosos/                   # Iglesias coloniales, capillas de vereda, santuarios
│   ├── 02_Monumentos_Civicos/           # Estatuas próceres, obeliscos, arcos conmemorativos
│   ├── 03_Plazas_Miradores/             # Plazas centrales, quioscos, miradores de carretera
│   └── 04_Sitios_Turisticos/            # Letreros monumentales de ciudades, monumentos al camionero
│
├── 03_Accesorios_Viales/
│   ├── 01_Senalizacion/
│   │   ├── Reglamentarias/              # Pare, prohibido parquear, límites de velocidad
│   │   ├── Preventivas/                 # Curvas peligrosas, zona escolar, derrumbes
│   │   ├── Informativas/                # Vallas de ruta, destinos kilométricos, señales de peaje
│   │   └── Demarcacion_Horizontal/      # Boyas viales, tachas reflectivas, resaltos/reductores
│   │
│   ├── 02_Iluminacion_Vial/
│   │   ├── Postes_Luz_Concreto/         # Postes tradicionales con transformador y cableado
│   │   ├── Postes_Luz_Metalicos/        # Farolas dobles de autopista, luminarias LED
│   │   └── Reflectores_Torres/          # Torres de iluminación de peaje y rotondas
│   │
│   ├── 03_Semaforos/
│   │   ├── Semaforos_Vehiculares/       # Postes con ménsula horizontal o verticales
│   │   └── Semaforos_Peatonales/        # Cruces para peatones
│   │
│   ├── 04_Barreras_Seguridad/
│   │   ├── Defensas_Metalicas/          # Guardarraíles viales
│   │   ├── Barreras_Concreto/           # Muros New Jersey modulares
│   │   └── Conos_Balizas/               # Señalizadores de obras en vía
│   │
│   └── 05_Peajes_Control/
│       ├── Casetas_Peaje/               # Casetas de cobro manual y talanqueras
│       └── Portales_Control/            # Pórticos de lectura electrónica, básculas camioneras
│
├── 04_Mobiliario_Urbano/
│   ├── 01_Bancas_Asientos/              # Bancas de parque, asientos de concreto
│   ├── 02_Paraderos_Buses/              # Casetas y paraderos de transporte público
│   ├── 03_Basura_Reciclaje/             # Canecas públicas y puntos ecológicos
│   ├── 04_Cercas_Muros/                 # Muros de ladrillo a la vista, rejas y cercas rurales
│   ├── 05_Parques_Recreacion/
│   │   ├── Juegos_Infantiles/           # Columpios, toboganes
│   │   ├── Gimnasios_Al_Aire_Libre/     # Máquinas biosaludables
│   │   └── Fuentes_Jardineras/          # Fuentes ornamentales y jardineras urbanas
│   └── 06_Puestos_Comercio_Calle/       # Casetas de revistas, quioscos típicos
│
├── 05_Vegetacion_Naturaleza/
│   ├── 01_Arboles/
│   │   ├── Urbanos/                     # Árboles de andén, urapanes, acacias
│   │   ├── Nativos_Bosque/              # Árbol sabanero, robles andinos, guayacanes
│   │   ├── Palmeras/                    # Palma de cera del Quindío, palmeras tropicales
│   │   └── Pinos_Eucaliptos/            # Eucaliptos y pinos de páramo/clima frío
│   │
│   ├── 02_Arbustos_Setos/               # Setos delimitadores y matorrales
│   ├── 03_Plantas_Flores/               # Flores ornamentales, buganvilias, heliconias
│   └── 04_Rocas_Geologia/               # Rocas andinas, cantos rodados, taludes rocosos
│
├── 06_Infraestructura_Transporte/
│   ├── 01_Terminales_Estaciones/        # Terminales de transporte intermunicipal
│   ├── 02_Puentes_Pasarelas/            # Pasarelas peatonales metálicas/concreto
│   ├── 03_Tuneles/                      # Portales de túnel vehicular y ventiladores
│   └── 04_Parqueaderos_Patios/          # Patios de parqueo de tractomulas y carros
│
└── 07_Plantillas_y_Kits/
    ├── Manzanas_Urbanas/                # Prefabs de manzanas completas
    ├── Intersecciones_Decoradas/        # Glorietas y cruces con mobiliario ya decorado
    └── Zonas_Campestres/                # Módulos rurales listos (finca + corrales + vía)
```

---

## 📐 Estándares Técnicos para Nuevos Assets

Para garantizar un rendimiento óptimo en dispositivos móviles y una integración perfecta con el editor:

### 1. Formato de Archivo
- **Recomendado:** Escena empaquetada de Godot (`.tscn`) con nodo raíz `StaticBody3D`.
- **Alternativa:** Modelos `.glb` o `.gltf` con materiales PBR estándar.

### 2. Punto de Pivote (Origen)
- **Centro en el suelo:** El origen `(X = 0, Y = 0, Z = 0)` **debe estar en la base del objeto (al nivel del suelo)**.
- El objeto nunca debe tener el pivote flotando ni en el centro geométrico vertical, para que al colocarlo sobre el terreno quede alineado a ras de suelo sin hundirse ni volar.

### 3. Escala y Dimensiones
- **Escala:** 1 unidad de Godot = 1 metro en la vida real.
- Todos los modelos deben exportarse con escala aplicada `(1.0, 1.0, 1.0)`.

### 4. Físicas y Colisiones
- El nodo raíz debe tener un `CollisionShape3D` configurado con formas simples (`BoxShape3D`, `CylinderShape3D` o `ConvexPolygonShape3D` simplificado).
- Evitar `ConcavePolygonShape3D` (trimesh) en props dinámicos o repetitivos para proteger los FPS en móviles.

### 5. Texturas y Materiales
- Reutilizar atlas compartidos (ej: `res://modelos3d/mapa/mapa/Props_Mundo_atlas_maestro_colombia_2k_albedo.png`).
- Usar compresión VRAM (ETC2/ASTC para Android).

---

## 🏷️ Archivo de Metadatos (`metadata.json`)

Cada modelo o subcarpeta puede incluir un archivo descriptivo opcional para auto-configurar la UI del editor de mapas:

```json
{
  "id": "casa_colonial_01",
  "nombre": "Casa Colonial con Tejado",
  "categoria": "RESIDENCIAL",
  "icono": "🏡",
  "icono_textura": "res://recursos/iconos_editor/edificios/casa_colonial_01.png",
  "escena": "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/01_Residencial/Casas_Tradicionales/casa_colonial_01.tscn",
  "tamano": [10.0, 6.0, 12.0],
  "snap_tamano": 4.0,
  "descripcion": "Vivienda tradicional de teja de barro y paredes encaladas típica de la región andina.",
  "autor": "Equipo Nuestra Tierra",
  "version": "1.0"
}
```

---

## 🚀 Cómo Agregar un Nuevo Objeto en 3 Pasos

1. **Ubicar la carpeta:** Elige la subcarpeta temática que corresponda (por ejemplo: `03_Accesorios_Viales/02_Iluminacion_Vial/Postes_Luz_Concreto/`).
2. **Copiar la escena o modelo:** Coloca allí el archivo `.tscn` o `.glb` junto con sus texturas o asignando el material global.
3. **Listo:** La estructura jerárquica permite que el gestor de recursos o el catálogo de la UI lo indexe directamente por ruta.
