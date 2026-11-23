class_name ControladorSpawn
extends Node3D

## ControladorSpawn.gd — Marcador 3D visual y gestor del punto de spawn
## Permite reubicar el punto de inicio, orientar la dirección y elegir el modo (Vehículo o A Pie).

signal spawn_actualizado(posicion: Vector3, rotacion_y: float, modo: String)

enum ModoSpawn {
	VEHICULO,
	A_PIE
}

@export var modo_spawn: ModoSpawn = ModoSpawn.VEHICULO
@export var rotacion_y_grados: float = 0.0

var _marcador_raiz: Node3D
var _proyector_spawn: MeshInstance3D
var _etiqueta: Label3D
var _marcador_preview_spawn: Node3D = null
static var _shader_proyeccion_spawn: Shader = null

func _ready() -> void:
	_construir_marcador_3d()
	_crear_marcador_preview_spawn()

static func _obtener_shader_proyeccion_spawn() -> Shader:
	if _shader_proyeccion_spawn:
		return _shader_proyeccion_spawn
	_shader_proyeccion_spawn = Shader.new()
	_shader_proyeccion_spawn.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never, blend_mix;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D mapa_altura : filter_linear, repeat_disable;
uniform bool usa_mapa_altura = false;
uniform float tolerancia_altura = 0.22;
uniform vec4 color_spawn : source_color = vec4(0.76, 0.62, 0.34, 0.86);
uniform float radio_ext = 2.7;
uniform float half_h = 12.0;
uniform float animar_pulso = 1.0;

varying mat4 v_inv_model;

void vertex() {
	v_inv_model = inverse(MODEL_MATRIX);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	if (depth <= 0.00001) {
		discard;
	}

	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 local_pos = (v_inv_model * vec4(world_pos, 1.0)).xyz;

	if (abs(local_pos.y) > half_h) {
		discard;
	}

	vec3 surf_normal = normalize(cross(dFdx(world_pos), dFdy(world_pos)));
	if (abs(surf_normal.y) < 0.55) {
		discard;
	}

	vec2 p = local_pos.xz;
	float r = length(p);
	if (r > radio_ext + 0.15) {
		discard;
	}

	if (usa_mapa_altura) {
		vec2 uv_h = clamp((p / vec2(radio_ext * 2.0)) + 0.5, vec2(0.0), vec2(1.0));
		float h_suelo = texture(mapa_altura, uv_h).r;
		if (abs(local_pos.y - h_suelo) > tolerancia_altura) {
			discard;
		}
	}

	// Aro exterior nítido con pulso muy sutil
	float pulso = 1.0 + sin(TIME * 2.2) * 0.03 * animar_pulso;
	float r_norm = r / (radio_ext * pulso);
	float aro_ext = smoothstep(0.89, 0.92, r_norm) * (1.0 - smoothstep(0.98, 1.0, r_norm));
	float aro_int = smoothstep(0.58, 0.60, r_norm) * (1.0 - smoothstep(0.63, 0.65, r_norm)) * 0.40;

	// Flecha direccional centrada apuntando hacia -Z
	float d_tallo = max(abs(p.x) - 0.16, abs(p.y - 0.25) - 0.85);
	float py_punta = p.y + 0.60;
	float ancho_punta = clamp((py_punta + 0.90) / 0.90, 0.0, 1.0) * 0.62;
	float d_punta = (p.y > -1.50 && p.y < -0.60) ? (abs(p.x) - ancho_punta) : 1.0;
	float flecha = 1.0 - smoothstep(-0.02, 0.02, min(d_tallo, d_punta));

	float relleno = (1.0 - smoothstep(0.95, 1.0, r_norm)) * 0.09;
	float alpha = clamp(aro_ext * 0.88 + aro_int + flecha * 0.85 + relleno, 0.0, 0.92) * color_spawn.a;

	ALBEDO = color_spawn.rgb;
	ALPHA = alpha;
}
"""
	return _shader_proyeccion_spawn

func _crear_proyector_spawn(color_base: Color, con_pulso: bool) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = _obtener_shader_proyeccion_spawn()
	mat.set_shader_parameter("color_spawn", color_base)
	mat.set_shader_parameter("radio_ext", 2.7)
	mat.set_shader_parameter("half_h", 12.0)
	mat.set_shader_parameter("animar_pulso", 1.0 if con_pulso else 0.0)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.4, 24.0, 6.4)
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _crear_marcador_preview_spawn() -> void:
	_marcador_preview_spawn = Node3D.new()
	_marcador_preview_spawn.name = "PreviewSpawnCursor"
	_marcador_preview_spawn.add_child(_crear_proyector_spawn(Color(0.60, 0.72, 0.82, 0.62), false))
	_marcador_preview_spawn.visible = false
	add_child(_marcador_preview_spawn)

func actualizar_cursor_spawn(pos_mundo: Vector3, visible_en_pantalla: bool) -> void:
	if not _marcador_preview_spawn:
		return
	_marcador_preview_spawn.visible = visible_en_pantalla
	if visible_en_pantalla:
		_marcador_preview_spawn.global_position = Vector3(pos_mundo.x, pos_mundo.y, pos_mundo.z)
		_marcador_preview_spawn.rotation_degrees.y = rotacion_y_grados

func _construir_marcador_3d() -> void:
	_marcador_raiz = Node3D.new()
	_marcador_raiz.name = "MarcadorSpawn3D"
	add_child(_marcador_raiz)
	_marcador_raiz.global_position = Vector3(0.0, 0.2, 0.0)

	_proyector_spawn = _crear_proyector_spawn(Color(0.76, 0.62, 0.34, 0.86), true)
	_proyector_spawn.name = "ProyeccionSpawn"
	_marcador_raiz.add_child(_proyector_spawn)

	# Etiqueta flotante 3D sobria
	_etiqueta = Label3D.new()
	_etiqueta.text = "PUNTO DE SPAWN"
	_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiqueta.font_size = 56
	_etiqueta.pixel_size = 0.011
	_etiqueta.modulate = Color(0.90, 0.92, 0.94, 0.92)
	_etiqueta.outline_modulate = Color(0.06, 0.07, 0.09, 0.78)
	_etiqueta.outline_size = 6
	_etiqueta.position = Vector3(0.0, 2.4, 0.0)
	_marcador_raiz.add_child(_etiqueta)
	call_deferred("_actualizar_altura_spawn")

func _actualizar_altura_spawn() -> void:
	if not is_instance_valid(_proyector_spawn) or not is_inside_tree():
		return
	var raiz := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var terr := raiz.find_child("Terrain3D", true, false)
	if not terr or not ("data" in terr) or not terr.data:
		return
	var t_data = terr.data
	var sm := _proyector_spawn.material_override as ShaderMaterial
	if not sm:
		return
	var r_ext: float = float(sm.get_shader_parameter("radio_ext"))
	var img := Image.create(12, 12, false, Image.FORMAT_RF)
	for iy in range(12):
		var tz := (float(iy) / 11.0 - 0.5) * 2.0 * r_ext
		for ix in range(12):
			var tx := (float(ix) / 11.0 - 0.5) * 2.0 * r_ext
			var w_pos: Vector3 = _proyector_spawn.global_transform * Vector3(tx, 0.0, tz)
			var h: float = t_data.get_height(w_pos)
			var h_loc: float = (h - _proyector_spawn.global_position.y) if (not is_nan(h) and not is_inf(h)) else 0.0
			img.set_pixel(ix, iy, Color(h_loc, 0.0, 0.0, 1.0))
	sm.set_shader_parameter("mapa_altura", ImageTexture.create_from_image(img))
	sm.set_shader_parameter("usa_mapa_altura", true)

func _process(_delta: float) -> void:
	pass

func posicionar_spawn(pos_mundo: Vector3) -> void:
	if not _marcador_raiz:
		return
	_marcador_raiz.global_position = Vector3(pos_mundo.x, pos_mundo.y + 0.15, pos_mundo.z)
	_actualizar_altura_spawn()
	spawn_actualizado.emit(_marcador_raiz.global_position, rotacion_y_grados, obtener_modo_nombre())

func rotar_spawn(paso_grados: float = 45.0) -> void:
	rotacion_y_grados = fmod(rotacion_y_grados + paso_grados, 360.0)
	if _marcador_raiz:
		_marcador_raiz.rotation_degrees.y = rotacion_y_grados
	_actualizar_altura_spawn()
	spawn_actualizado.emit(_marcador_raiz.global_position, rotacion_y_grados, obtener_modo_nombre())

func alternar_modo() -> String:
	if modo_spawn == ModoSpawn.VEHICULO:
		modo_spawn = ModoSpawn.A_PIE
	else:
		modo_spawn = ModoSpawn.VEHICULO
	
	_actualizar_texto_etiqueta()
	spawn_actualizado.emit(_marcador_raiz.global_position, rotacion_y_grados, obtener_modo_nombre())
	return obtener_modo_nombre()

func establecer_modo(modo: String) -> void:
	if modo.to_lower() == "a_pie" or modo.to_lower() == "pie":
		modo_spawn = ModoSpawn.A_PIE
	else:
		modo_spawn = ModoSpawn.VEHICULO
	_actualizar_texto_etiqueta()

func _actualizar_texto_etiqueta() -> void:
	if _etiqueta:
		if modo_spawn == ModoSpawn.VEHICULO:
			_etiqueta.text = "🚩 SPAWN: VEHÍCULO"
		else:
			_etiqueta.text = "🚩 SPAWN: A PIE"

func obtener_posicion() -> Vector3:
	if _marcador_raiz:
		return _marcador_raiz.global_position
	return Vector3.ZERO

func obtener_rotacion_y() -> float:
	return rotacion_y_grados

func obtener_transform_spawn() -> Transform3D:
	if _marcador_raiz:
		return _marcador_raiz.global_transform
	return Transform3D.IDENTITY

func obtener_modo_nombre() -> String:
	return "vehiculo" if modo_spawn == ModoSpawn.VEHICULO else "a_pie"

func serializar_spawn() -> Dictionary:
	var pos = obtener_posicion()
	return {
		"posicion": [pos.x, pos.y, pos.z],
		"rotacion_y": rotacion_y_grados,
		"modo": obtener_modo_nombre()
	}

func deserializar_spawn(datos: Dictionary) -> void:
	var pos_arr = datos.get("posicion", [0.0, 0.2, 0.0])
	rotacion_y_grados = datos.get("rotacion_y", 0.0)
	establecer_modo(datos.get("modo", "vehiculo"))
	if _marcador_raiz:
		_marcador_raiz.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		_marcador_raiz.rotation_degrees.y = rotacion_y_grados
		call_deferred("_actualizar_altura_spawn")
