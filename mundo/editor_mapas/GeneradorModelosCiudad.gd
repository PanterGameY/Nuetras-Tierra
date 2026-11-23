class_name GeneradorModelosCiudad
extends RefCounted

## GeneradorModelosCiudad.gd — Fábrica procedural de edificios, árboles y mobiliario urbano
## Genera mallas 3D estilizadas de alta calidad con colisiones físicas integradas.

enum Categoria {
	RESIDENCIAL,
	COMERCIAL,
	INDUSTRIAL,
	SERVICIOS,
	VEGETACION,
	MOBILIARIO
}

static func obtener_catalogo() -> Array[Dictionary]:
	return [
		# ZONAS Y CHECKPOINTS LOGÍSTICOS (No son edificaciones, son áreas funcionales)
		{
			"id": "zona_carga",
			"nombre": "Punto de Carga",
			"categoria": Categoria.INDUSTRIAL,
			"icono": "📦",
			"tamano": Vector3(6.0, 0.3, 10.0),
			"desc": "Zona/checkpoint donde los vehículos recogen mercancía."
		},
		{
			"id": "zona_descarga",
			"nombre": "Punto de Descarga",
			"categoria": Categoria.INDUSTRIAL,
			"icono": "🏁",
			"tamano": Vector3(6.0, 0.3, 10.0),
			"desc": "Zona/checkpoint donde los vehículos entregan mercancía."
		},
		{
			"id": "zona_alquiler_trailer",
			"nombre": "Alquiler de Tráiler",
			"categoria": Categoria.INDUSTRIAL,
			"icono": "🚛",
			"tamano": Vector3(5.0, 0.3, 14.0),
			"desc": "Zona/checkpoint para alquilar y desplegar un tráiler en la bahía."
		},
		# RESIDENCIAL
		{
			"id": "casa_suburbana",
			"nombre": "Casa Suburbana",
			"categoria": Categoria.RESIDENCIAL,
			"icono": "🏡",
			"tamano": Vector3(8.0, 5.5, 9.0),
			"desc": "Casa unifamiliar con tejado rojo y jardín."
		},
		{
			"id": "casa_moderna",
			"nombre": "Casa Moderna",
			"categoria": Categoria.RESIDENCIAL,
			"icono": "🏢",
			"tamano": Vector3(10.0, 6.5, 10.0),
			"desc": "Residencia de 2 pisos con ventanales y terraza."
		},
		{
			"id": "edificio_residencial",
			"nombre": "Edificio Residencial",
			"categoria": Categoria.RESIDENCIAL,
			"icono": "🏬",
			"tamano": Vector3(12.0, 14.0, 12.0),
			"desc": "Bloque de apartamentos de 4 plantas."
		},
		
		# COMERCIAL
		{
			"id": "tienda_barrio",
			"nombre": "Tienda Comercial",
			"categoria": Categoria.COMERCIAL,
			"icono": "🏪",
			"tamano": Vector3(8.0, 5.0, 7.0),
			"desc": "Local de barrio con vitrina y toldo frontal."
		},
		{
			"id": "centro_comercial",
			"nombre": "Centro Comercial",
			"categoria": Categoria.COMERCIAL,
			"icono": "🛍️",
			"tamano": Vector3(18.0, 8.0, 15.0),
			"desc": "Gran superficie comercial con amplios accesos."
		},
		{
			"id": "gasolinera",
			"nombre": "Estación Gasolina",
			"categoria": Categoria.COMERCIAL,
			"icono": "⛽",
			"tamano": Vector3(14.0, 5.5, 12.0),
			"desc": "Estación de servicio con marquesina de surtidores."
		},
		{
			"id": "garaje_camiones",
			"nombre": "Garaje de Camiones",
			"categoria": Categoria.COMERCIAL,
			"icono": "🚛",
			"icono_textura": "res://recursos/iconos_editor/garaje_camiones.png",
			"tamano": Vector3(10.6, 5.8, 15.6),
			"desc": "Garaje amplio para camiones y vehículos. Permite sacar vehículos en modo prueba."
		},

		# INDUSTRIAL Y CORPORATIVO
		{
			"id": "rascacielos",
			"nombre": "Torre Corporativa",
			"categoria": Categoria.INDUSTRIAL,
			"icono": "🏙️",
			"tamano": Vector3(14.0, 32.0, 14.0),
			"desc": "Rascacielos de oficinas con fachada de cristal."
		},
		{
			"id": "bodega_industrial",
			"nombre": "Bodega Logística",
			"categoria": Categoria.INDUSTRIAL,
			"icono": "🏭",
			"tamano": Vector3(20.0, 7.5, 16.0),
			"desc": "Nave industrial para carga y almacenamiento."
		},

		# SERVICIOS PÚBLICOS
		{
			"id": "hospital",
			"nombre": "Hospital Municipal",
			"categoria": Categoria.SERVICIOS,
			"icono": "🏥",
			"tamano": Vector3(18.0, 12.0, 15.0),
			"desc": "Centro médico con cruz de emergencias."
		},
		{
			"id": "estacion_bomberos",
			"nombre": "Estación Bomberos",
			"categoria": Categoria.SERVICIOS,
			"icono": "🚒",
			"tamano": Vector3(14.0, 8.0, 12.0),
			"desc": "Cuartel con portones dobles para camiones."
		},
		{
			"id": "plaza_parque",
			"nombre": "Plaza Central",
			"categoria": Categoria.SERVICIOS,
			"icono": "⛲",
			"tamano": Vector3(16.0, 2.5, 16.0),
			"desc": "Espacio público con fuente y bancas."
		},

		# VEGETACIÓN (MODELOS OFICIALES DE LA ESCENA DE MAPA)
		{
			"id": "arbol_sabanero",
			"nombre": "Árbol Sabanero",
			"categoria": Categoria.VEGETACION,
			"icono": "🌳",
			"icono_textura": "res://recursos/iconos_editor/arboles/arbol_sabanero.png",
			"tamano": Vector3(7.8, 11.4, 8.9),
			"desc": "Árbol insignia de la escena de mapa con follaje nativo."
		},
		{
			"id": "arbol_roble_3d",
			"nombre": "Roble Andino 3D",
			"categoria": Categoria.VEGETACION,
			"icono": "🌲",
			"icono_textura": "res://recursos/iconos_editor/arboles/arbol_roble_3d.png",
			"tamano": Vector3(9.8, 12.9, 9.8),
			"desc": "Árbol 3D del mapa con tronco detallado y ramas."
		},
		{
			"id": "arbol_palmera",
			"nombre": "Palmera Tropical",
			"categoria": Categoria.VEGETACION,
			"icono": "🌴",
			"icono_textura": "res://recursos/iconos_editor/arboles/arbol_palmera.png",
			"tamano": Vector3(8.2, 15.8, 8.2),
			"desc": "Palmera costera y tropical de la escena del mapa."
		},
		{
			"id": "arbol_alto_silvestre",
			"nombre": "Árbol Silvestre",
			"categoria": Categoria.VEGETACION,
			"icono": "🌿",
			"icono_textura": "res://recursos/iconos_editor/arboles/arbol_alto_silvestre.png",
			"tamano": Vector3(9.6, 15.6, 9.6),
			"desc": "Árbol alto de gran copa del sector Balmoral."
		},
		{
			"id": "arbol_frondoso",
			"nombre": "Árbol Frondoso",
			"categoria": Categoria.VEGETACION,
			"icono": "🍃",
			"icono_textura": "res://recursos/iconos_editor/arboles/arbol_frondoso.png",
			"tamano": Vector3(8.8, 12.8, 10.1),
			"desc": "Árbol de copa tupida y follaje denso del mapa."
		},
		{
			"id": "arboleda_grupo",
			"nombre": "Arboleda en Grupo",
			"categoria": Categoria.VEGETACION,
			"icono": "🏕️",
			"icono_textura": "res://recursos/iconos_editor/arboles/arboleda_grupo.png",
			"tamano": Vector3(44.8, 12.5, 12.0),
			"desc": "Agrupación de árboles múltiples para bosques rápidos."
		},
		{
			"id": "arbusto_flores",
			"nombre": "Arbusto Floral",
			"categoria": Categoria.VEGETACION,
			"icono": "🌺",
			"tamano": Vector3(2.5, 1.8, 2.5),
			"desc": "Seto floral para bordes y jardines."
		},

		# MOBILIARIO URBANO
		{
			"id": "poste_luz",
			"nombre": "Farola Urbana",
			"categoria": Categoria.MOBILIARIO,
			"icono": "💡",
			"tamano": Vector3(1.0, 5.5, 1.0),
			"desc": "Luminaria pública para calles y aceras."
		},
		{
			"id": "semaforo",
			"nombre": "Semáforo Vial",
			"categoria": Categoria.MOBILIARIO,
			"icono": "🚦",
			"tamano": Vector3(0.8, 4.5, 0.8),
			"desc": "Semáforo regulador de tráfico."
		},
		{
			"id": "senal_pare",
			"nombre": "Señal de Pare",
			"categoria": Categoria.MOBILIARIO,
			"icono": "🛑",
			"tamano": Vector3(0.6, 2.8, 0.6),
			"desc": "Señal reglamentaria octogonal."
		},
		{
			"id": "banca_parque",
			"nombre": "Banca de Parque",
			"categoria": Categoria.MOBILIARIO,
			"icono": "🪑",
			"tamano": Vector3(2.2, 1.0, 0.9),
			"desc": "Banca para peatones en madera y forja."
		}
	]

static func crear_instancia_objeto(id_modelo: String) -> Node3D:
	if id_modelo == "casa_modular":
		return GeneradorCasaModular.crear_casa(DatosCasaModular.crear_config_defecto())

	var nodo_raiz := StaticBody3D.new()
	nodo_raiz.name = "Objeto_%s" % id_modelo
	nodo_raiz.set_meta("id_modelo", id_modelo)
	
	match id_modelo:
		"casa_suburbana":
			_construir_casa_suburbana(nodo_raiz)
		"casa_moderna":
			_construir_casa_moderna(nodo_raiz)
		"edificio_residencial":
			_construir_edificio_residencial(nodo_raiz)
		"tienda_barrio":
			_construir_tienda_barrio(nodo_raiz)
		"centro_comercial":
			_construir_centro_comercial(nodo_raiz)
		"gasolinera":
			_construir_gasolinera(nodo_raiz)
		"garaje_camiones", "garaje_doble", "garaje_terminal", "garaje_moderno":
			_construir_garaje_variacion(nodo_raiz, id_modelo)
		"rascacielos":
			_construir_rascacielos(nodo_raiz)
		"bodega_industrial":
			_construir_bodega_industrial(nodo_raiz)
		"zona_carga", "zona_descarga", "zona_alquiler_trailer":
			_construir_zona_checkpoint(nodo_raiz, id_modelo)
		"hospital":
			_construir_hospital(nodo_raiz)
		"estacion_bomberos":
			_construir_estacion_bomberos(nodo_raiz)
		"plaza_parque":
			_construir_plaza_parque(nodo_raiz)
		"arbol_sabanero", "arbol_roble_3d", "arbol_palmera", "arbol_alto_silvestre", "arbol_frondoso", "arboleda_grupo":
			var path_tscn := "res://modelos3d/mapa/arboles/%s.tscn" % id_modelo
			if ResourceLoader.exists(path_tscn):
				var tree_scn = load(path_tscn)
				if tree_scn:
					var inst: Node3D = tree_scn.instantiate()
					inst.name = "Objeto_%s" % id_modelo
					inst.set_meta("id_modelo", id_modelo)
					return inst
			_construir_arbol_roble(nodo_raiz)
		"arbol_roble":
			return crear_instancia_objeto("arbol_sabanero")
		"arbol_pino":
			return crear_instancia_objeto("arbol_roble_3d")
		"arbusto_flores":
			_construir_arbusto_flores(nodo_raiz)
		"poste_luz":
			_construir_poste_luz(nodo_raiz)
		"semaforo":
			_construir_semaforo(nodo_raiz)
		"senal_pare":
			_construir_senal_pare(nodo_raiz)
		"banca_parque":
			_construir_banca_parque(nodo_raiz)
		_:
			_construir_casa_suburbana(nodo_raiz)
			
	return nodo_raiz

static var _shader_proyeccion_zona: Shader = null

static func _obtener_shader_proyeccion_zona() -> Shader:
	if _shader_proyeccion_zona:
		return _shader_proyeccion_zona
	_shader_proyeccion_zona = Shader.new()
	_shader_proyeccion_zona.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D mapa_altura : filter_nearest, repeat_disable;
uniform bool usa_mapa_altura = false;
uniform vec4 color_zona : source_color = vec4(0.68, 0.58, 0.38, 0.85);
uniform float half_w = 3.0;
uniform float half_l = 5.0;

varying vec2 v_local_xz;

void vertex() {
	v_local_xz = VERTEX.xz;
	if (usa_mapa_altura) {
		vec2 uv_h = clamp((VERTEX.xz / vec2(half_w * 2.0, half_l * 2.0)) + 0.5, vec2(0.0), vec2(1.0));
		float h_suelo = clamp(textureLod(mapa_altura, uv_h, 0.0).r, -25.0, 25.0);
		VERTEX.y = h_suelo + 0.08;
	} else {
		VERTEX.y += 0.08;
	}
}

void fragment() {
	vec2 p = v_local_xz;
	vec2 b = vec2(half_w, half_l);
	float r_esq = 0.35;
	vec2 q = abs(p) - b + vec2(r_esq);
	float d_box = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r_esq;
	if (d_box > 0.0) {
		discard;
	}

	// Marco perimetral nítido (0.20 m)
	float borde = 1.0 - smoothstep(0.17, 0.22, -d_box);

	// Flecha direccional sobria hacia -Z
	float d_tallo = max(abs(p.x) - 0.13, abs(p.y - 0.15) - 0.72);
	float py_punta = p.y + 0.55;
	float ancho_punta = clamp((py_punta + 0.70) / 0.70, 0.0, 1.0) * 0.46;
	float d_punta = (p.y > -1.25 && p.y < -0.55) ? (abs(p.x) - ancho_punta) : 1.0;
	float flecha = 1.0 - smoothstep(-0.02, 0.02, min(d_tallo, d_punta));

	float relleno = 0.08;
	float alpha = clamp(borde * 0.88 + flecha * 0.78 + relleno, 0.0, 0.90) * color_zona.a;

	ALBEDO = color_zona.rgb;
	ALPHA = alpha;
}
"""
	return _shader_proyeccion_zona


static func actualizar_alturas_proyeccion_zona(padre: Node3D) -> void:
	if not is_instance_valid(padre) or not padre.is_inside_tree():
		return
	var raiz := padre.get_tree().current_scene if padre.get_tree().current_scene else padre.get_tree().root
	var terr := raiz.find_child("Terrain3D", true, false)
	if not terr or not ("data" in terr) or not terr.data:
		return
	var t_data = terr.data
	for ch in padre.get_children():
		if ch is MeshInstance3D and ch.material_override is ShaderMaterial:
			var sm := ch.material_override as ShaderMaterial
			if sm.shader != _obtener_shader_proyeccion_zona():
				continue
			var hw := float(sm.get_shader_parameter("half_w"))
			var hl := float(sm.get_shader_parameter("half_l"))
			var img := Image.create(16, 16, false, Image.FORMAT_RF)
			for iy in range(16):
				var tz := (float(iy) / 15.0 - 0.5) * 2.0 * hl
				for ix in range(16):
					var tx := (float(ix) / 15.0 - 0.5) * 2.0 * hw
					var w_pos: Vector3 = ch.global_transform * Vector3(tx, 0.0, tz)
					var h: float = t_data.get_height(w_pos)
					var h_loc: float = (h - ch.global_position.y) if (not is_nan(h) and not is_inf(h)) else 0.0
					img.set_pixel(ix, iy, Color(h_loc, 0.0, 0.0, 1.0))
			var tex := ImageTexture.create_from_image(img)
			sm.set_shader_parameter("mapa_altura", tex)
			sm.set_shader_parameter("usa_mapa_altura", true)


static func _crear_proyector_zona(nombre: String, ancho: float, largo: float, _alto_proy: float, col_zona: Color, pos_local: Vector3) -> MeshInstance3D:
	var mat_proy := ShaderMaterial.new()
	mat_proy.shader = _obtener_shader_proyeccion_zona()
	mat_proy.set_shader_parameter("color_zona", col_zona)
	mat_proy.set_shader_parameter("half_w", ancho * 0.5)
	mat_proy.set_shader_parameter("half_l", largo * 0.5)

	var proyector := MeshInstance3D.new()
	proyector.name = nombre
	var plano_proy := PlaneMesh.new()
	plano_proy.size = Vector2(ancho + 0.6, largo + 0.6)
	plano_proy.subdivide_width = 15
	plano_proy.subdivide_depth = 15
	proyector.mesh = plano_proy
	proyector.material_override = mat_proy
	proyector.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proyector.position = pos_local
	return proyector


static func _construir_zona_checkpoint(padre: StaticBody3D, id_modelo: String) -> void:
	var ancho: float = 6.0
	var largo: float = 10.0
	var alto_proy: float = 24.0
	var titulo: String = "PUNTO DE CARGA"
	var col_zona := Color(0.68, 0.58, 0.38, 0.85) # Arena cálida moderada

	if id_modelo == "zona_descarga":
		titulo = "PUNTO DE DESCARGA"
		col_zona = Color(0.58, 0.64, 0.70, 0.85) # Acero pizarra sobrio
	elif id_modelo == "zona_alquiler_trailer":
		ancho = 5.0
		largo = 24.0
		titulo = "ALQUILER TRÁILER"
		col_zona = Color(0.62, 0.60, 0.54, 0.85) # Piedra neutra sobria

	if id_modelo == "zona_alquiler_trailer":
		# Cuadro delantero más largo para el cabezote, separado de la bahía del tráiler (Z = -7.8)
		padre.add_child(_crear_proyector_zona(
			"ProyeccionCabina", 5.0, 8.5, alto_proy,
			Color(0.72, 0.62, 0.42, 0.88), Vector3(0.0, 0.0, -7.8)
		))
		# Cuadro trasero más largo donde aparece el tráiler sin enganchar (Z = +7.5)
		padre.add_child(_crear_proyector_zona(
			"ProyeccionBahiaTrailer", 5.0, 13.0, alto_proy,
			Color(0.58, 0.62, 0.66, 0.82), Vector3(0.0, 0.0, 7.5)
		))
	else:
		padre.add_child(_crear_proyector_zona(
			"ProyeccionZona", ancho, largo, alto_proy, col_zona, Vector3.ZERO
		))

	# Etiqueta 3D flotante sobria visible en el editor y en juego
	var lbl := Label3D.new()
	lbl.name = "EtiquetaZona"
	lbl.text = titulo
	lbl.font_size = 64
	lbl.pixel_size = 0.011
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.90, 0.92, 0.94, 0.92)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.06, 0.07, 0.09, 0.78)
	lbl.position = Vector3(0.0, 2.35, -7.8 if id_modelo == "zona_alquiler_trailer" else 0.0)
	padre.add_child(lbl)

	# Colisión plana mínima solo para selección con raycast en el editor (no frena camiones)
	var col_sel := CollisionShape3D.new()
	var box_sel := BoxShape3D.new()
	box_sel.size = Vector3(ancho, 0.04, largo)
	col_sel.shape = box_sel
	col_sel.position = Vector3(0.0, 0.02, 0.0)
	padre.add_child(col_sel)

	# Nodo funcional de logística o alquiler
	if id_modelo == "zona_alquiler_trailer":
		var script_alq = preload("res://mundo/editor_mapas/ZonaAlquilerTrailer.gd")
		var alquiler: Node3D = script_alq.new()
		alquiler.name = "ZonaAlquilerTrailer"
		padre.add_child(alquiler)
	else:
		var script_pcd = preload("res://codigo/sistemas/logistica/PuntoCargaDescarga.gd")
		var punto: Marker3D = script_pcd.new()
		punto.name = "PuntoCargaDescarga"
		punto.set("nombre_punto", titulo.capitalize())
		punto.set("tipo_punto", 0 if id_modelo == "zona_carga" else 1)
		punto.set("forma_zona", 1)
		punto.set("ancho", ancho - 0.5)
		punto.set("largo", largo - 0.5)
		punto.set("generar_area_deteccion", true)
		punto.set("mostrar_etiqueta_3d", false)
		punto.set("mostrar_visual_suelo", false)
		padre.add_child(punto)

		var script_carga_ui = preload("res://mundo/editor_mapas/ZonaCargaInteractiva.gd")
		var zona_ui: Node3D = script_carga_ui.new()
		zona_ui.name = "ZonaCargaInteractiva"
		zona_ui.set("es_descarga", id_modelo == "zona_descarga")
		padre.add_child(zona_ui)


# ── CONSTRUCTORES PROCEDURALES DE ALTA FIDELIDAD ─────────────────────

static func _agregar_caja_con_colision(padre: Node3D, tam: Vector3, centro_rel: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tam
	mi.mesh = box
	mi.position = centro_rel
	mi.material_override = mat
	padre.add_child(mi)
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = tam
	col.shape = shape
	col.position = centro_rel
	padre.add_child(col)
	return mi

static func _material_color(color: Color, roughness: float = 0.5, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

static func _construir_casa_suburbana(raiz: StaticBody3D) -> void:
	# Base de paredes (estuco blanco/crema)
	var mat_pared = _material_color(Color(0.92, 0.90, 0.85), 0.6)
	_agregar_caja_con_colision(raiz, Vector3(7.0, 3.2, 8.0), Vector3(0.0, 1.6, 0.0), mat_pared)
	
	# Tejado a dos aguas en teja terracota
	var mi_techo := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(8.0, 2.2, 8.6)
	mi_techo.mesh = prism
	mi_techo.position = Vector3(0.0, 4.3, 0.0)
	mi_techo.material_override = _material_color(Color(0.72, 0.28, 0.18), 0.7)
	raiz.add_child(mi_techo)
	
	# Chimenea de ladrillo
	var mat_chimenea = _material_color(Color(0.55, 0.25, 0.20), 0.8)
	_agregar_caja_con_colision(raiz, Vector3(1.0, 3.0, 1.0), Vector3(2.2, 4.2, 1.5), mat_chimenea)
	
	# Puerta de madera
	var mi_puerta := MeshInstance3D.new()
	var box_p := BoxMesh.new()
	box_p.size = Vector3(1.2, 2.1, 0.15)
	mi_puerta.mesh = box_p
	mi_puerta.position = Vector3(0.0, 1.05, 4.05)
	mi_puerta.material_override = _material_color(Color(0.38, 0.22, 0.12), 0.4)
	raiz.add_child(mi_puerta)

static func _construir_casa_moderna(raiz: StaticBody3D) -> void:
	var mat_gris = _material_color(Color(0.85, 0.86, 0.88), 0.3)
	var mat_madera = _material_color(Color(0.52, 0.34, 0.20), 0.5)
	var mat_vidrio = _material_color(Color(0.25, 0.45, 0.65, 0.85), 0.1, 0.2)
	mat_vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Primer piso
	_agregar_caja_con_colision(raiz, Vector3(9.0, 3.0, 8.5), Vector3(0.0, 1.5, 0.0), mat_gris)
	# Segundo piso desplazado
	_agregar_caja_con_colision(raiz, Vector3(7.5, 2.8, 7.0), Vector3(0.8, 4.4, -0.6), mat_madera)
	# Balcón / ventanal superior
	var mi_vidrio := MeshInstance3D.new()
	var b_v := BoxMesh.new()
	b_v.size = Vector3(4.0, 2.0, 0.2)
	mi_vidrio.mesh = b_v
	mi_vidrio.position = Vector3(0.8, 4.5, 3.0)
	mi_vidrio.material_override = mat_vidrio
	raiz.add_child(mi_vidrio)

static func _construir_edificio_residencial(raiz: StaticBody3D) -> void:
	var mat_cuerpo = _material_color(Color(0.78, 0.76, 0.73), 0.5)
	_agregar_caja_con_colision(raiz, Vector3(11.0, 14.0, 11.0), Vector3(0.0, 7.0, 0.0), mat_cuerpo)
	
	# Cornisa superior
	var mat_cornisa = _material_color(Color(0.35, 0.36, 0.38), 0.4)
	_agregar_caja_con_colision(raiz, Vector3(11.6, 0.8, 11.6), Vector3(0.0, 14.4, 0.0), mat_cornisa)

static func _construir_tienda_barrio(raiz: StaticBody3D) -> void:
	var mat_pared = _material_color(Color(0.95, 0.93, 0.88), 0.6)
	_agregar_caja_con_colision(raiz, Vector3(7.5, 4.2, 6.5), Vector3(0.0, 2.1, 0.0), mat_pared)
	
	# Toldo frontal a rayas rojas/blancas
	var mi_toldo := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(6.5, 1.2, 1.8)
	mi_toldo.mesh = prism
	mi_toldo.rotation_degrees.x = 25.0
	mi_toldo.position = Vector3(0.0, 3.4, 3.8)
	mi_toldo.material_override = _material_color(Color(0.85, 0.25, 0.22), 0.5)
	raiz.add_child(mi_toldo)

static func _construir_centro_comercial(raiz: StaticBody3D) -> void:
	var mat_muro = _material_color(Color(0.88, 0.90, 0.92), 0.4)
	_agregar_caja_con_colision(raiz, Vector3(16.0, 7.0, 14.0), Vector3(0.0, 3.5, 0.0), mat_muro)
	
	# Entrada acristalada
	var mat_vidrio = _material_color(Color(0.2, 0.5, 0.75, 0.9), 0.1, 0.4)
	mat_vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_agregar_caja_con_colision(raiz, Vector3(7.0, 4.5, 1.5), Vector3(0.0, 2.25, 7.3), mat_vidrio)

static func _construir_gasolinera(raiz: StaticBody3D) -> void:
	# Edificio de tienda anexa
	var mat_tienda = _material_color(Color(0.92, 0.92, 0.92), 0.5)
	_agregar_caja_con_colision(raiz, Vector3(6.0, 4.0, 8.0), Vector3(-3.5, 2.0, -1.5), mat_tienda)
	
	# Techo marquesina de surtidores
	var mat_techo = _material_color(Color(0.88, 0.68, 0.28), 0.4) # Amber
	_agregar_caja_con_colision(raiz, Vector3(7.0, 0.6, 9.0), Vector3(3.5, 4.8, 0.0), mat_techo)
	
	# 2 Columnas de marquesina
	var mat_col = _material_color(Color(0.7, 0.7, 0.7), 0.4, 0.5)
	_agregar_caja_con_colision(raiz, Vector3(0.6, 4.6, 0.6), Vector3(3.5, 2.3, -3.0), mat_col)
	_agregar_caja_con_colision(raiz, Vector3(0.6, 4.6, 0.6), Vector3(3.5, 2.3, 3.0), mat_col)

static func _construir_rascacielos(raiz: StaticBody3D) -> void:
	var mat_vidrio = _material_color(Color(0.18, 0.32, 0.48), 0.1, 0.6)
	_agregar_caja_con_colision(raiz, Vector3(12.0, 30.0, 12.0), Vector3(0.0, 15.0, 0.0), mat_vidrio)
	
	# Remate superior con antena
	var mat_antena = _material_color(Color(0.8, 0.8, 0.8), 0.2, 0.8)
	var mi_ant := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.4
	cyl.height = 6.0
	mi_ant.mesh = cyl
	mi_ant.position = Vector3(0.0, 33.0, 0.0)
	mi_ant.material_override = mat_antena
	raiz.add_child(mi_ant)

static func _construir_bodega_industrial(raiz: StaticBody3D) -> void:
	var mat_chapa = _material_color(Color(0.55, 0.58, 0.62), 0.5, 0.3)
	_agregar_caja_con_colision(raiz, Vector3(18.0, 6.5, 14.0), Vector3(0.0, 3.25, 0.0), mat_chapa)
	
	# Portón rojo de carga
	var mat_porton = _material_color(Color(0.75, 0.22, 0.20), 0.4)
	_agregar_caja_con_colision(raiz, Vector3(4.5, 4.2, 0.2), Vector3(0.0, 2.1, 7.05), mat_porton)

static func _construir_hospital(raiz: StaticBody3D) -> void:
	var mat_hosp = _material_color(Color(0.96, 0.96, 0.98), 0.4)
	_agregar_caja_con_colision(raiz, Vector3(16.0, 11.0, 13.0), Vector3(0.0, 5.5, 0.0), mat_hosp)
	
	# Cruz roja en fachada
	var mat_cruz = _material_color(Color(0.85, 0.15, 0.15), 0.3)
	mat_cruz.emission_enabled = true
	mat_cruz.emission = Color(0.9, 0.1, 0.1)
	mat_cruz.emission_energy_multiplier = 1.5
	_agregar_caja_con_colision(raiz, Vector3(0.8, 3.0, 0.2), Vector3(0.0, 8.5, 6.6), mat_cruz)
	_agregar_caja_con_colision(raiz, Vector3(3.0, 0.8, 0.2), Vector3(0.0, 8.5, 6.6), mat_cruz)

static func _construir_estacion_bomberos(raiz: StaticBody3D) -> void:
	var mat_cuartel = _material_color(Color(0.78, 0.35, 0.25), 0.6)
	_agregar_caja_con_colision(raiz, Vector3(13.0, 7.5, 11.0), Vector3(0.0, 3.75, 0.0), mat_cuartel)
	# 2 portones rojos
	var mat_puertas = _material_color(Color(0.88, 0.15, 0.15), 0.4)
	_agregar_caja_con_colision(raiz, Vector3(3.8, 4.5, 0.2), Vector3(-3.0, 2.25, 5.55), mat_puertas)
	_agregar_caja_con_colision(raiz, Vector3(3.8, 4.5, 0.2), Vector3(3.0, 2.25, 5.55), mat_puertas)

static func _construir_plaza_parque(raiz: StaticBody3D) -> void:
	# Suelo adoquines
	var mat_piso = _material_color(Color(0.68, 0.66, 0.62), 0.8)
	_agregar_caja_con_colision(raiz, Vector3(15.0, 0.3, 15.0), Vector3(0.0, 0.15, 0.0), mat_piso)
	
	# Fuente central
	var mat_fuente = _material_color(Color(0.82, 0.84, 0.86), 0.4)
	var mi_f := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.5
	cyl.bottom_radius = 2.6
	cyl.height = 1.0
	mi_f.mesh = cyl
	mi_f.position = Vector3(0.0, 0.6, 0.0)
	mi_f.material_override = mat_fuente
	raiz.add_child(mi_f)

static func _construir_arbol_roble(raiz: StaticBody3D) -> void:
	# Tronco
	var mat_tronco = _material_color(Color(0.38, 0.24, 0.15), 0.8)
	var mi_t := MeshInstance3D.new()
	var cyl_t := CylinderMesh.new()
	cyl_t.top_radius = 0.35
	cyl_t.bottom_radius = 0.5
	cyl_t.height = 3.0
	mi_t.mesh = cyl_t
	mi_t.position = Vector3(0.0, 1.5, 0.0)
	mi_t.material_override = mat_tronco
	raiz.add_child(mi_t)
	
	# Colisión de tronco para vehículos
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 3.0
	col.shape = shape
	col.position = Vector3(0.0, 1.5, 0.0)
	raiz.add_child(col)
	
	# Copa frondosa
	var mat_copa = _material_color(Color(0.22, 0.55, 0.18), 0.7)
	var mi_c := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.2
	sphere.height = 4.2
	mi_c.mesh = sphere
	mi_c.position = Vector3(0.0, 4.8, 0.0)
	mi_c.material_override = mat_copa
	raiz.add_child(mi_c)

static func _construir_arbol_pino(raiz: StaticBody3D) -> void:
	var mat_tronco = _material_color(Color(0.35, 0.22, 0.12), 0.8)
	var mi_t := MeshInstance3D.new()
	var cyl_t := CylinderMesh.new()
	cyl_t.top_radius = 0.25
	cyl_t.bottom_radius = 0.4
	cyl_t.height = 3.2
	mi_t.mesh = cyl_t
	mi_t.position = Vector3(0.0, 1.6, 0.0)
	mi_t.material_override = mat_tronco
	raiz.add_child(mi_t)
	
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.38
	shape.height = 3.2
	col.shape = shape
	col.position = Vector3(0.0, 1.6, 0.0)
	raiz.add_child(col)
	
	# 3 Conos de follaje
	var mat_verde = _material_color(Color(0.12, 0.38, 0.16), 0.7)
	for i in range(3):
		var mi_c := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.9 - (i * 0.4)
		cone.height = 2.5
		mi_c.mesh = cone
		mi_c.position = Vector3(0.0, 3.5 + (i * 1.6), 0.0)
		mi_c.material_override = mat_verde
		raiz.add_child(mi_c)

static func _construir_arbol_palmera(raiz: StaticBody3D) -> void:
	var mat_tronco = _material_color(Color(0.48, 0.36, 0.24), 0.8)
	var mi_t := MeshInstance3D.new()
	var cyl_t := CylinderMesh.new()
	cyl_t.top_radius = 0.22
	cyl_t.bottom_radius = 0.38
	cyl_t.height = 5.5
	mi_t.mesh = cyl_t
	mi_t.position = Vector3(0.0, 2.75, 0.0)
	mi_t.material_override = mat_tronco
	raiz.add_child(mi_t)
	
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 5.5
	col.shape = shape
	col.position = Vector3(0.0, 2.75, 0.0)
	raiz.add_child(col)
	
	# Penacho de hojas
	var mat_hojas = _material_color(Color(0.25, 0.58, 0.15), 0.6)
	var mi_h := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 2.4
	disk.bottom_radius = 0.4
	disk.height = 0.6
	mi_h.mesh = disk
	mi_h.position = Vector3(0.0, 5.6, 0.0)
	mi_h.material_override = mat_hojas
	raiz.add_child(mi_h)

static func _construir_arbusto_flores(raiz: StaticBody3D) -> void:
	var mat_arbusto = _material_color(Color(0.26, 0.52, 0.20), 0.7)
	var mi_s := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.1
	sphere.height = 1.4
	mi_s.mesh = sphere
	mi_s.position = Vector3(0.0, 0.7, 0.0)
	mi_s.material_override = mat_arbusto
	raiz.add_child(mi_s)

static func _construir_poste_luz(raiz: StaticBody3D) -> void:
	var mat_metal = _material_color(Color(0.28, 0.30, 0.32), 0.3, 0.7)
	_agregar_caja_con_colision(raiz, Vector3(0.2, 5.0, 0.2), Vector3(0.0, 2.5, 0.0), mat_metal)
	# Brazo horizontal
	_agregar_caja_con_colision(raiz, Vector3(1.4, 0.15, 0.2), Vector3(0.6, 5.0, 0.0), mat_metal)
	
	# Foco de luz puntual
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.92, 0.75)
	luz.light_energy = 2.0
	luz.omni_range = 15.0
	luz.position = Vector3(1.2, 4.8, 0.0)
	raiz.add_child(luz)

static func _construir_semaforo(raiz: StaticBody3D) -> void:
	var mat_poste = _material_color(Color(0.25, 0.27, 0.28), 0.3, 0.6)
	_agregar_caja_con_colision(raiz, Vector3(0.2, 4.2, 0.2), Vector3(0.0, 2.1, 0.0), mat_poste)
	
	# Caja semáforo
	var mat_caja = _material_color(Color(0.12, 0.12, 0.12), 0.5)
	_agregar_caja_con_colision(raiz, Vector3(0.5, 1.4, 0.4), Vector3(0.0, 3.4, 0.2), mat_caja)

static func _construir_senal_pare(raiz: StaticBody3D) -> void:
	var mat_poste = _material_color(Color(0.7, 0.7, 0.7), 0.4, 0.7)
	_agregar_caja_con_colision(raiz, Vector3(0.1, 2.6, 0.1), Vector3(0.0, 1.3, 0.0), mat_poste)
	
	# Placa roja de Pare
	var mat_pare = _material_color(Color(0.85, 0.12, 0.12), 0.3)
	var mi_p := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 0.05
	mi_p.mesh = cyl
	mi_p.rotation_degrees.x = 90.0
	mi_p.position = Vector3(0.0, 2.4, 0.08)
	mi_p.material_override = mat_pare
	raiz.add_child(mi_p)

static func _construir_banca_parque(raiz: StaticBody3D) -> void:
	var mat_madera = _material_color(Color(0.48, 0.30, 0.18), 0.6)
	# Asiento y respaldo
	_agregar_caja_con_colision(raiz, Vector3(2.0, 0.12, 0.5), Vector3(0.0, 0.5, 0.0), mat_madera)
	_agregar_caja_con_colision(raiz, Vector3(2.0, 0.45, 0.1), Vector3(0.0, 0.85, -0.25), mat_madera)

static func _agregar_colision_caja(raiz: CollisionObject3D, tamano: Vector3, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = tamano
	col.shape = shape
	col.position = pos
	raiz.add_child(col)

static func _aplicar_texturas_garaje(nodo: Node) -> void:
	const TEX_PISO := "res://mundo/editor_mapas/texturas/garaje/garaje_piso_concreto.png"
	const TEX_PARED := "res://mundo/editor_mapas/texturas/garaje/garaje_pared_ladrillo.png"
	const TEX_TECHO := "res://mundo/editor_mapas/texturas/garaje/garaje_techo_metal.png"
	var mats := {}
	if ResourceLoader.exists(TEX_PISO):
		var m_piso := StandardMaterial3D.new()
		m_piso.albedo_texture = ResourceLoader.load(TEX_PISO) as Texture2D
		m_piso.albedo_color = Color.WHITE
		m_piso.roughness = 0.85
		mats["MatPisoGaraje"] = m_piso
	if ResourceLoader.exists(TEX_PARED):
		var m_pared := StandardMaterial3D.new()
		m_pared.albedo_texture = ResourceLoader.load(TEX_PARED) as Texture2D
		m_pared.albedo_color = Color.WHITE
		m_pared.roughness = 0.88
		mats["MatParedGaraje"] = m_pared
	if ResourceLoader.exists(TEX_TECHO):
		var m_techo := StandardMaterial3D.new()
		m_techo.albedo_texture = ResourceLoader.load(TEX_TECHO) as Texture2D
		m_techo.albedo_color = Color.WHITE
		m_techo.metallic = 0.45
		m_techo.roughness = 0.42
		mats["MatTechoMetal"] = m_techo

	var cola: Array[Node] = [nodo]
	while not cola.is_empty():
		var cur: Node = cola.pop_back()
		for ch in cur.get_children():
			cola.append(ch)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var m_orig := mi.mesh.surface_get_material(s)
					if m_orig and mats.has(m_orig.resource_name):
						mi.set_surface_override_material(s, mats[m_orig.resource_name])

static func _construir_garaje_variacion(raiz: StaticBody3D, id_modelo: String) -> void:
	var ruta_glb := "res://mundo/editor_mapas/modelos/%s.glb" % id_modelo
	if ResourceLoader.exists(ruta_glb):
		var escena := ResourceLoader.load(ruta_glb) as PackedScene
		if escena:
			var inst := escena.instantiate() as Node3D
			if inst:
				inst.name = "ModeloGarajeGLB"
				_aplicar_texturas_garaje(inst)
				raiz.add_child(inst)

	# Base/cimiento de concreto bajo la losa para terrenos con pendiente
	var tam_cim := Vector3(11.2, 0.80, 16.2)
	var pos_cim := Vector3(0.0, -0.40, 1.3)
	var tam_piso := Vector3(10.6, 0.30, 15.6)
	var pos_piso := Vector3(0.0, -0.01, 1.3)
	var pos_spawn := Vector3(0.0, 0.15, 0.8)
	var tam_zona := Vector3(6.2, 4.2, 9.6)
	var pos_zona := Vector3(0.0, 2.1, -0.4)

	match id_modelo:
		"garaje_doble":
			tam_cim = Vector3(18.6, 0.80, 18.6)
			pos_cim = Vector3(0.0, -0.40, 1.5)
			tam_piso = Vector3(18.2, 0.30, 18.2)
			pos_piso = Vector3(0.0, -0.01, 1.5)
			pos_spawn = Vector3(-4.05, 0.15, 0.5)
			tam_zona = Vector3(15.2, 4.6, 12.2)
			pos_zona = Vector3(0.0, 2.3, 0.0)
			# Paredes trasera, laterales y pilares (2 bahías de 5.7m)
			_agregar_colision_caja(raiz, Vector3(18.0, 6.2, 0.44), Vector3(0.0, 3.1, -7.28))
			_agregar_colision_caja(raiz, Vector3(0.44, 6.2, 15.0), Vector3(-8.78, 3.1, 0.0))
			_agregar_colision_caja(raiz, Vector3(0.44, 6.2, 15.0), Vector3(8.78, 3.1, 0.0))
			_agregar_colision_caja(raiz, Vector3(2.1, 6.2, 0.44), Vector3(-7.95, 3.1, 7.28))
			_agregar_colision_caja(raiz, Vector3(2.4, 6.2, 0.44), Vector3(0.0, 3.1, 7.28))
			_agregar_colision_caja(raiz, Vector3(2.1, 6.2, 0.44), Vector3(7.95, 3.1, 7.28))
			_agregar_colision_caja(raiz, Vector3(18.0, 1.4, 0.44), Vector3(0.0, 5.5, 7.28))
			_agregar_colision_caja(raiz, Vector3(19.0, 0.24, 16.0), Vector3(0.0, 6.45, 0.0))
		"garaje_terminal":
			tam_cim = Vector3(14.8, 0.80, 27.4)
			pos_cim = Vector3(0.0, -0.40, 0.0)
			tam_piso = Vector3(14.4, 0.30, 27.0)
			pos_piso = Vector3(0.0, -0.01, 0.0)
			pos_spawn = Vector3(0.0, 0.15, 0.0)
			tam_zona = Vector3(9.6, 5.0, 18.0)
			pos_zona = Vector3(0.0, 2.5, 0.0)
			# Paredes laterales + portales pasantes adelante (+Z) y atrás (-Z)
			_agregar_colision_caja(raiz, Vector3(0.48, 6.8, 22.0), Vector3(-6.76, 3.4, 0.0))
			_agregar_colision_caja(raiz, Vector3(0.48, 6.8, 22.0), Vector3(6.76, 3.4, 0.0))
			for pz in [-10.76, 10.76]:
				_agregar_colision_caja(raiz, Vector3(3.8, 6.8, 0.48), Vector3(-5.1, 3.4, pz))
				_agregar_colision_caja(raiz, Vector3(3.8, 6.8, 0.48), Vector3(5.1, 3.4, pz))
				_agregar_colision_caja(raiz, Vector3(6.4, 1.6, 0.48), Vector3(0.0, 6.0, pz))
			_agregar_colision_caja(raiz, Vector3(15.2, 0.25, 23.0), Vector3(0.0, 7.05, 0.0))
		"garaje_moderno":
			tam_cim = Vector3(16.8, 0.80, 20.4)
			pos_cim = Vector3(0.0, -0.40, 2.0)
			tam_piso = Vector3(16.4, 0.30, 20.0)
			pos_piso = Vector3(0.0, -0.01, 2.0)
			pos_spawn = Vector3(-2.3, 0.15, 0.5)
			tam_zona = Vector3(11.0, 4.6, 12.6)
			pos_zona = Vector3(-1.5, 2.3, 0.0)
			# Paredes + amplia bahía 7.0m izquierda + recepción derecha + voladizo
			_agregar_colision_caja(raiz, Vector3(16.0, 6.0, 0.44), Vector3(0.0, 3.0, -7.78))
			_agregar_colision_caja(raiz, Vector3(0.44, 6.0, 16.0), Vector3(-7.78, 3.0, 0.0))
			_agregar_colision_caja(raiz, Vector3(0.44, 6.0, 16.0), Vector3(7.78, 3.0, 0.0))
			_agregar_colision_caja(raiz, Vector3(2.2, 6.0, 0.44), Vector3(-6.9, 3.0, 7.78))
			_agregar_colision_caja(raiz, Vector3(6.8, 6.0, 0.44), Vector3(4.6, 3.0, 7.78))
			_agregar_colision_caja(raiz, Vector3(7.0, 1.2, 0.44), Vector3(-2.3, 5.4, 7.78))
			_agregar_colision_caja(raiz, Vector3(0.40, 6.0, 0.40), Vector3(-7.6, 3.0, 11.4))
			_agregar_colision_caja(raiz, Vector3(0.40, 6.0, 0.40), Vector3(7.6, 3.0, 11.4))
			_agregar_colision_caja(raiz, Vector3(17.2, 0.40, 20.2), Vector3(0.0, 6.2, 1.9))
		_:
			# garaje_camiones (Clásico 1 Bahía)
			_agregar_colision_caja(raiz, Vector3(10.6, 5.6, 0.44), Vector3(0.0, 2.8, -6.28))
			_agregar_colision_caja(raiz, Vector3(0.44, 5.6, 13.0), Vector3(-5.08, 2.8, 0.0))
			_agregar_colision_caja(raiz, Vector3(0.44, 5.6, 13.0), Vector3(5.08, 2.8, 0.0))
			_agregar_colision_caja(raiz, Vector3(2.5, 5.6, 0.44), Vector3(-4.05, 2.8, 6.28))
			_agregar_colision_caja(raiz, Vector3(2.5, 5.6, 0.44), Vector3(4.05, 2.8, 6.28))
			_agregar_colision_caja(raiz, Vector3(5.6, 1.0, 0.44), Vector3(0.0, 5.1, 6.28))
			_agregar_colision_caja(raiz, Vector3(10.8, 0.25, 13.4), Vector3(0.0, 5.7, 0.0))

	var mat_cimiento := _material_color(Color(0.44, 0.45, 0.47), 0.88)
	var mi_cim := MeshInstance3D.new()
	mi_cim.name = "CimientoGaraje"
	var box_cim := BoxMesh.new()
	box_cim.size = tam_cim
	mi_cim.mesh = box_cim
	mi_cim.material_override = mat_cimiento
	mi_cim.position = pos_cim
	raiz.add_child(mi_cim)

	_agregar_colision_caja(raiz, tam_piso, pos_piso)

	# Punto de spawn para vehículos dentro de la bahía (mirando hacia +Z, salida)
	var punto_spawn := Marker3D.new()
	punto_spawn.name = "PuntoSpawnGaraje"
	punto_spawn.position = pos_spawn
	raiz.add_child(punto_spawn)

	# Zona interactiva de garaje (estrictamente interior para que aparezca al entrar)
	var zona := Area3D.new()
	zona.name = "ZonaGaraje"
	zona.monitoring = true
	zona.monitorable = true
	zona.add_to_group("zona_garaje_prueba")
	_agregar_colision_caja(zona, tam_zona, pos_zona)
	raiz.add_child(zona)
