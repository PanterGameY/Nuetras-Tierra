extends Node

# Variables globales para el juego
signal nombre_usuario_cambiado(new_name: String)
signal avatar_cambiada(new_texture)

func _ready() -> void:
	var loaded = load_local()
	print("[DatosUsuario DEBUG] cargado al iniciar: ", loaded, " | tutorial_completado = ", tutorial_completado)


var id_usuario : String = ""
var firebase_uid : String = ""
var id_publico_numero: int = 0
var nombre_usuario : String = ""
var email_usuario : String = ""
var discord_username : String = ""
var proveedor_auth : String = ""
var esmeraldas : int = 0
var dinero : float = 0.0
var next_scene : String = ""
var previous_scene : String = ""
var escenas_precargadas : Dictionary = {}

func cambiar_escena(ruta_destino: String) -> void:
	next_scene = ruta_destino
	var ruta_carga := "res://interfaz/sistema/escena_carga.tscn"
	if ResourceLoader.exists(ruta_carga):
		get_tree().change_scene_to_file(ruta_carga)
	else:
		get_tree().change_scene_to_file(ruta_destino)
var avatar_path: String = ""
var avatar_texture: Texture2D = null
var vehiculos_personalizados : Dictionary = {}
var vehiculos_comprados : Dictionary = {}
var remolques_activos : Dictionary = {}
var tutorial_completado : bool = true
var tutorial_celular_completado : bool = false
var mision_licencia_completada : bool = false
var mision_reparto_completada : bool = false
var experiencia : int = 0
var nivel : int = 0

# ── Pase Élite ────────────────────────────────────────────────────────────
# Membresía de pago único con recompensa diaria (monedas + experiencia).
const PASE_ELITE_COSTO : float = 2500.0
const PASE_ELITE_MULT_XP : float = 1.15
const PASE_ELITE_DIAS_CICLO : int = 7
const PASE_ELITE_RECOMPENSAS : Array = [
	{"monedas": 500.0, "experiencia": 60, "bono": false},
	{"monedas": 700.0, "experiencia": 80, "bono": false},
	{"monedas": 900.0, "experiencia": 100, "bono": false},
	{"monedas": 1200.0, "experiencia": 130, "bono": false},
	{"monedas": 1500.0, "experiencia": 160, "bono": false},
	{"monedas": 1900.0, "experiencia": 200, "bono": false},
	{"monedas": 2800.0, "experiencia": 320, "bono": true},
]

var pase_elite_activo : bool = false
var pase_elite_desde : String = ""
var pase_elite_ultimo_reclamo : String = ""
var pase_elite_dias_reclamados : int = 0
var trabajos_legales_desbloqueados : bool = false
var licencia_automovil : bool = false
var licencia_camion : bool = false
var licencia_carga_delicada : bool = false
var licencia_carga_sobredimensionada : bool = false
var licencia_c1 : bool = false # Examen C1 = Tutorial inicial disfrazado de examen de conduccion (gratuito, sin cobro ni perdida del 50%)
var licencia_c2 : bool = false # Camión rígido (se aprueba en Academia: 3 intentos, 50% devolución si reprueba)
var licencia_c3 : bool = false # Tractomula articulada (se aprueba en Academia: 3 intentos, 50% devolución si reprueba)
var licencia_prueba_pendiente : String = ""
var guardado_player_pos : Vector3 = Vector3.ZERO
var guardado_player_rot_y : float = 0.0
var guardado_player_scene : String = ""
var guardado_player_conduciendo : bool = false
var guardado_player_vehiculo_nombre : String = ""
var vehiculos_posiciones : Dictionary = {}



const LOCAL_SAVE_PATH := "user://datos_usuario.cfg"
const FIRESTORE_ACCOUNTS_COLLECTION := "conductores"
const FIRESTORE_META_COLLECTION := "meta"
const FIRESTORE_PUBLIC_ID_COUNTER_DOCUMENT := "public_id_counter"
const USER_PUBLIC_ID_PREFIX := ""
const USER_PUBLIC_ID_MIN_DIGITS := 3

func _emit_nombre_usuario_actualizado() -> void:
	emit_signal("nombre_usuario_cambiado", nombre_usuario)

func _build_firestore_payload(include_progress: bool = true) -> Dictionary:
	var payload: Dictionary = {
		"uid": firebase_uid,
		"firebase_uid": firebase_uid,
		"id_usuario": id_usuario,
		"public_id": id_usuario,
		"public_id_number": id_publico_numero,
		"nombre_usuario": nombre_usuario,
		"email": email_usuario,
		"provider": proveedor_auth,
		"last_sync_unix": Time.get_unix_time_from_system(),
	}
	if include_progress:
		payload["esmeraldas"] = esmeraldas
		payload["dinero"] = dinero
		payload["avatar_path"] = avatar_path
	return payload


func _build_identity_payload() -> Dictionary:
	return {
		"uid": firebase_uid,
		"firebase_uid": firebase_uid,
		"id_usuario": id_usuario,
		"public_id": id_usuario,
		"public_id_number": id_publico_numero,
		"email": email_usuario,
		"provider": proveedor_auth,
		"last_sync_unix": Time.get_unix_time_from_system(),
	}


func _is_public_user_id(candidate: String) -> bool:
	if not candidate.begins_with(USER_PUBLIC_ID_PREFIX):
		return false
	var suffix: String = candidate.substr(USER_PUBLIC_ID_PREFIX.length())
	if suffix == "":
		return false
	for character in suffix:
		if character < "0" or character > "9":
			return false
	return true


func _extraer_numero_id_publico(candidate: String) -> int:
	if not _is_public_user_id(candidate):
		return 0
	var suffix: String = candidate.substr(USER_PUBLIC_ID_PREFIX.length())
	if suffix == "":
		return 0
	return int(suffix)


func _formatear_id_publico(number: int) -> String:
	var safe_number: int = maxi(number, 0)
	var text_number: String = str(safe_number)
	if text_number.length() < USER_PUBLIC_ID_MIN_DIGITS:
		text_number = text_number.lpad(USER_PUBLIC_ID_MIN_DIGITS, "0")
	return "%s%s" % [USER_PUBLIC_ID_PREFIX, text_number]


func _asegurar_id_publico() -> String:
	if id_publico_numero > 0:
		id_usuario = _formatear_id_publico(id_publico_numero)
		return id_usuario
	if _is_public_user_id(id_usuario):
		id_publico_numero = _extraer_numero_id_publico(id_usuario)
		id_usuario = _formatear_id_publico(id_publico_numero)
		return id_usuario
	id_usuario = ""
	return id_usuario


func needs_public_id_assignment() -> bool:
	return id_publico_numero <= 0 or not _is_public_user_id(id_usuario)


func get_public_id_counter_collection() -> String:
	return FIRESTORE_META_COLLECTION


func get_public_id_counter_document() -> String:
	return FIRESTORE_PUBLIC_ID_COUNTER_DOCUMENT


func set_public_id_number(new_number: int, guardar: bool = true, sync_remote: bool = true) -> String:
	id_publico_numero = maxi(new_number, 1)
	id_usuario = _formatear_id_publico(id_publico_numero)
	if guardar:
		save_local()
	if sync_remote and firebase_uid != "":
		sync_account_to_firebase({
			"public_id_number_assigned": true,
			"public_id_number": id_publico_numero,
		})
	return id_usuario

var _ultimo_guardado_ms: int = 0
var _timer_guardado_pendiente: SceneTreeTimer = null
var _guardado_pendiente: bool = false
const INTERVALO_MIN_GUARDADO_MS: int = 4000 # Máximo una escritura a disco cada 4s si no es forzado

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PREDELETE:
		if _guardado_pendiente:
			_ejecutar_guardado_disco()

# Guardado local (ConfigFile) -------------------------------------------------
func save_local(forzar: bool = false) -> bool:
	if not forzar:
		var ahora: int = Time.get_ticks_msec()
		if ahora - _ultimo_guardado_ms < INTERVALO_MIN_GUARDADO_MS:
			_guardado_pendiente = true
			if _timer_guardado_pendiente == null:
				var tree = get_tree()
				if tree:
					var espera: float = float(INTERVALO_MIN_GUARDADO_MS - (ahora - _ultimo_guardado_ms)) / 1000.0
					_timer_guardado_pendiente = tree.create_timer(maxf(espera, 0.5))
					_timer_guardado_pendiente.timeout.connect(_on_timer_guardado_timeout)
			return true

	return _ejecutar_guardado_disco()

func _on_timer_guardado_timeout() -> void:
	_timer_guardado_pendiente = null
	if _guardado_pendiente:
		_ejecutar_guardado_disco()

func _ejecutar_guardado_disco() -> bool:
	_ultimo_guardado_ms = Time.get_ticks_msec()
	_guardado_pendiente = false
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("usuario", "id_usuario", id_usuario)
	cfg.set_value("usuario", "firebase_uid", firebase_uid)
	cfg.set_value("usuario", "id_publico_numero", id_publico_numero)
	cfg.set_value("usuario", "nombre_usuario", nombre_usuario)
	cfg.set_value("usuario", "email_usuario", email_usuario)
	cfg.set_value("usuario", "discord_username", discord_username)
	cfg.set_value("usuario", "proveedor_auth", proveedor_auth)
	cfg.set_value("usuario", "esmeraldas", esmeraldas)
	cfg.set_value("usuario", "dinero", dinero)
	cfg.set_value("usuario", "avatar_path", avatar_path)
	cfg.set_value("usuario", "vehiculos_personalizados", vehiculos_personalizados)
	cfg.set_value("usuario", "vehiculos_comprados", vehiculos_comprados)
	cfg.set_value("usuario", "remolques_activos", remolques_activos)
	cfg.set_value("usuario", "tutorial_completado", tutorial_completado)
	cfg.set_value("usuario", "tutorial_celular_completado", tutorial_celular_completado)
	cfg.set_value("usuario", "mision_licencia_completada", mision_licencia_completada)
	cfg.set_value("usuario", "mision_reparto_completada", mision_reparto_completada)
	cfg.set_value("usuario", "experiencia", experiencia)
	cfg.set_value("usuario", "nivel", nivel)
	cfg.set_value("usuario", "pase_elite_activo", pase_elite_activo)
	cfg.set_value("usuario", "pase_elite_desde", pase_elite_desde)
	cfg.set_value("usuario", "pase_elite_ultimo_reclamo", pase_elite_ultimo_reclamo)
	cfg.set_value("usuario", "pase_elite_dias_reclamados", pase_elite_dias_reclamados)
	cfg.set_value("usuario", "trabajos_legales_desbloqueados", trabajos_legales_desbloqueados)
	cfg.set_value("usuario", "licencia_automovil", licencia_automovil)
	cfg.set_value("usuario", "licencia_camion", licencia_camion)
	cfg.set_value("usuario", "licencia_carga_delicada", licencia_carga_delicada)
	cfg.set_value("usuario", "licencia_carga_sobredimensionada", licencia_carga_sobredimensionada)
	cfg.set_value("usuario", "licencia_c1", licencia_c1)
	cfg.set_value("usuario", "licencia_c2", licencia_c2)
	cfg.set_value("usuario", "licencia_c3", licencia_c3)
	cfg.set_value("usuario", "guardado_player_pos", guardado_player_pos)
	cfg.set_value("usuario", "guardado_player_rot_y", guardado_player_rot_y)
	cfg.set_value("usuario", "guardado_player_scene", guardado_player_scene)
	cfg.set_value("usuario", "guardado_player_conduciendo", guardado_player_conduciendo)
	cfg.set_value("usuario", "guardado_player_vehiculo_nombre", guardado_player_vehiculo_nombre)
	cfg.set_value("usuario", "vehiculos_posiciones", vehiculos_posiciones)
	var err: int = cfg.save(LOCAL_SAVE_PATH)
	if err == OK:
		print("[DatosUsuario] Guardado local en:", LOCAL_SAVE_PATH)
		if has_node("/root/SupabaseManager"):
			var sb := get_node("/root/SupabaseManager")
			if sb and sb.has_method("esta_autenticado") and sb.esta_autenticado() and sb.has_method("programar_guardado_perfil"):
				sb.programar_guardado_perfil()
		return true
	else:
		printerr("[DatosUsuario] Error guardando localmente:", err)
		return false

func load_local() -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	# Verificar existencia usando FileAccess para rutas user:// en móviles
	if FileAccess.file_exists(LOCAL_SAVE_PATH):
		var err: int = cfg.load(LOCAL_SAVE_PATH)
		if err == OK:
			id_usuario = str(cfg.get_value("usuario", "id_usuario", ""))
			firebase_uid = str(cfg.get_value("usuario", "firebase_uid", ""))
			id_publico_numero = int(cfg.get_value("usuario", "id_publico_numero", 0))
			nombre_usuario = str(cfg.get_value("usuario", "nombre_usuario", ""))
			email_usuario = str(cfg.get_value("usuario", "email_usuario", ""))
			discord_username = str(cfg.get_value("usuario", "discord_username", ""))
			proveedor_auth = str(cfg.get_value("usuario", "proveedor_auth", ""))
			esmeraldas = int(cfg.get_value("usuario", "esmeraldas", 0))
			dinero = float(cfg.get_value("usuario", "dinero", 0.0))
			avatar_path = str(cfg.get_value("usuario", "avatar_path", ""))
			vehiculos_personalizados = cfg.get_value("usuario", "vehiculos_personalizados", {})
			vehiculos_comprados = cfg.get_value("usuario", "vehiculos_comprados", {})
			remolques_activos = cfg.get_value("usuario", "remolques_activos", {})
			tutorial_completado = bool(cfg.get_value("usuario", "tutorial_completado", true))
			tutorial_celular_completado = bool(cfg.get_value("usuario", "tutorial_celular_completado", false))
			mision_licencia_completada = bool(cfg.get_value("usuario", "mision_licencia_completada", false))
			mision_reparto_completada = bool(cfg.get_value("usuario", "mision_reparto_completada", false))
			experiencia = int(cfg.get_value("usuario", "experiencia", 0))
			nivel = int(cfg.get_value("usuario", "nivel", 0))
			pase_elite_activo = bool(cfg.get_value("usuario", "pase_elite_activo", false))
			pase_elite_desde = str(cfg.get_value("usuario", "pase_elite_desde", ""))
			pase_elite_ultimo_reclamo = str(
				cfg.get_value("usuario", "pase_elite_ultimo_reclamo", "")
			)
			pase_elite_dias_reclamados = int(
				cfg.get_value("usuario", "pase_elite_dias_reclamados", 0)
			)
			trabajos_legales_desbloqueados = bool(cfg.get_value("usuario", "trabajos_legales_desbloqueados", false))
			licencia_automovil = bool(cfg.get_value("usuario", "licencia_automovil", false))
			licencia_camion = bool(cfg.get_value("usuario", "licencia_camion", false))
			licencia_carga_delicada = bool(cfg.get_value("usuario", "licencia_carga_delicada", false))
			licencia_carga_sobredimensionada = bool(cfg.get_value("usuario", "licencia_carga_sobredimensionada", false))
			licencia_c1 = bool(cfg.get_value("usuario", "licencia_c1", false))
			licencia_c2 = bool(cfg.get_value("usuario", "licencia_c2", false))
			licencia_c3 = bool(cfg.get_value("usuario", "licencia_c3", false))
			guardado_player_pos = cfg.get_value("usuario", "guardado_player_pos", Vector3.ZERO)
			guardado_player_rot_y = float(cfg.get_value("usuario", "guardado_player_rot_y", 0.0))
			guardado_player_scene = str(cfg.get_value("usuario", "guardado_player_scene", ""))
			guardado_player_conduciendo = bool(cfg.get_value("usuario", "guardado_player_conduciendo", false))
			guardado_player_vehiculo_nombre = str(cfg.get_value("usuario", "guardado_player_vehiculo_nombre", ""))
			vehiculos_posiciones = cfg.get_value("usuario", "vehiculos_posiciones", {})
			if firebase_uid == "" and id_usuario != "" and not _is_public_user_id(id_usuario):
				firebase_uid = id_usuario
				id_usuario = ""
			if id_publico_numero <= 0 and id_usuario != "" and _is_public_user_id(id_usuario):
				# IDs anteriores con formato legacy se reasignan desde Firestore.
				id_usuario = ""
			if firebase_uid != "":
				_asegurar_id_publico()
			if avatar_path != "":
				var resolved_avatar := avatar_path
				if avatar_path.begins_with("res://") or avatar_path.begins_with("user://"):
					resolved_avatar = ProjectSettings.globalize_path(avatar_path)
				var _img := Image.new()
				if _img.load(resolved_avatar) == OK:
					avatar_texture = ImageTexture.create_from_image(_img)
				else:
					avatar_texture = null
			else:
				avatar_texture = null
			if firebase_uid.strip_edges() == "" and nombre_usuario.strip_edges() == "":
				print("[DatosUsuario] Archivo local vacío; no hay sesión activa.")
				return false
			print("[DatosUsuario] Cargado localmente:", nombre_usuario)
			# Si no hay nombre asignado, generamos uno aleatorio y guardamos
			if firebase_uid != "" and (nombre_usuario == "" or nombre_usuario.strip_edges() == ""):
				nombre_usuario = generar_nombre_aleatorio()
				save_local()
			return true
		else:
			printerr("[DatosUsuario] Error leyendo archivo local:", err)
			return false
	return false


func _pick_first_non_empty(candidates: Array) -> String:
	for candidate in candidates:
		var text: String = str(candidate).strip_edges()
		if text != "" and text.to_lower() != "null":
			return text
	return ""


func _assign_profile_value(profile: Dictionary, key: String, value) -> void:
	var text: String = str(value).strip_edges()
	if text == "" or text.to_lower() == "null":
		return
	if not profile.has(key) or str(profile.get(key, "")).strip_edges() == "":
		profile[key] = text


func _merge_auth_dictionary(profile: Dictionary, source: Dictionary) -> void:
	_assign_profile_value(profile, "uid", _pick_first_non_empty([
		source.get("uid", ""),
		source.get("user_id", ""),
		source.get("id", ""),
		source.get("localId", ""),
	]))
	_assign_profile_value(profile, "email", _pick_first_non_empty([
		source.get("email", ""),
		source.get("mail", ""),
	]))
	_assign_profile_value(profile, "name", _pick_first_non_empty([
		source.get("name", ""),
		source.get("display_name", ""),
		source.get("displayName", ""),
		source.get("full_name", ""),
		source.get("username", ""),
		source.get("nombre_usuario", ""),
	]))
	_assign_profile_value(profile, "provider", _pick_first_non_empty([
		source.get("provider", ""),
		source.get("provider_id", ""),
		source.get("sign_in_provider", ""),
	]))

	var metadata = source.get("user_metadata", source.get("metadata", {}))
	if typeof(metadata) == TYPE_DICTIONARY:
		_assign_profile_value(profile, "name", _pick_first_non_empty([
			metadata.get("full_name", ""),
			metadata.get("name", ""),
			metadata.get("display_name", ""),
			metadata.get("displayName", ""),
		]))
		_assign_profile_value(profile, "email", metadata.get("email", ""))

	var provider_data = source.get("providerData", source.get("provider_data", []))
	if typeof(provider_data) == TYPE_ARRAY:
		for entry in provider_data:
			if typeof(entry) == TYPE_DICTIONARY:
				_merge_auth_dictionary(profile, entry)

	var nested_user = source.get("user", null)
	if typeof(nested_user) == TYPE_DICTIONARY:
		_merge_auth_dictionary(profile, nested_user)


func _extract_auth_profile(auth_result) -> Dictionary:
	var profile: Dictionary = {
		"uid": "",
		"name": "",
		"email": "",
		"provider": "",
	}

	if auth_result == null:
		profile["name"] = "Conductor"
		return profile

	if typeof(auth_result) == TYPE_DICTIONARY:
		_merge_auth_dictionary(profile, auth_result)
	elif typeof(auth_result) == TYPE_OBJECT:
		if auth_result.has_method("get_uid"):
			profile["uid"] = str(auth_result.get_uid())
		elif auth_result.has_method("get_user_id"):
			profile["uid"] = str(auth_result.get_user_id())

		if auth_result.has_method("get_email"):
			profile["email"] = str(auth_result.get_email())

		if auth_result.has_method("get_name"):
			profile["name"] = str(auth_result.get_name())
		elif auth_result.has_method("get_display_name"):
			profile["name"] = str(auth_result.get_display_name())

	if str(profile.get("name", "")).strip_edges() == "":
		profile["name"] = "Conductor"
	return profile


func _resolve_account_name(profile: Dictionary, fallback_name: String = "") -> String:
	var resolved_name: String = _pick_first_non_empty([
		fallback_name,
		profile.get("name", ""),
	])
	if resolved_name == "" or resolved_name == "Conductor":
		var email: String = str(profile.get("email", "")).strip_edges()
		if email != "":
			var email_parts: Array = email.split("@")
			if email_parts.size() > 0:
				resolved_name = email_parts[0]
	if resolved_name == "" or resolved_name == "Conductor":
		resolved_name = generar_nombre_aleatorio()
	return resolved_name


func _get_firebase_backend() -> Object:
	var firebase_root = get_node_or_null("/root/Firebase")
	if firebase_root:
		return firebase_root
	if Engine.has_singleton("GodotFirebaseAndroid"):
		return Engine.get_singleton("GodotFirebaseAndroid")
	return null


func sync_account_to_firebase(extra_data: Dictionary = {}) -> bool:
	if firebase_uid.strip_edges() == "":
		return false
	_asegurar_id_publico()

	var payload: Dictionary = _build_firestore_payload(true)
	for key in extra_data.keys():
		payload[key] = extra_data[key]

	var backend = _get_firebase_backend()
	if not backend:
		print("[DatosUsuario] Firebase no disponible; sincronización omitida.")
		return false

	if backend and "firestore" in backend:
		var fb = backend
		if fb.firestore and fb.firestore.has_method("set_document"):
			fb.firestore.set_document(FIRESTORE_ACCOUNTS_COLLECTION, firebase_uid, payload, true)
			return true

	if backend.has_method("firestoreSetDocument"):
		backend.firestoreSetDocument(FIRESTORE_ACCOUNTS_COLLECTION, firebase_uid, payload, true)
		return true

	if backend.has_method("set_document"):
		backend.set_document(FIRESTORE_ACCOUNTS_COLLECTION, firebase_uid, payload, true)
		return true

	print("[DatosUsuario] Firestore no expone set_document para sincronizar cuentas.")
	return false


func sync_identity_to_firebase(extra_data: Dictionary = {}) -> bool:
	if firebase_uid.strip_edges() == "":
		return false
	_asegurar_id_publico()

	var payload: Dictionary = _build_identity_payload()
	for key in extra_data.keys():
		payload[key] = extra_data[key]

	var backend = _get_firebase_backend()
	if not backend:
		return false

	if backend and "firestore" in backend:
		var fb = backend
		if fb.firestore and fb.firestore.has_method("set_document"):
			fb.firestore.set_document(FIRESTORE_ACCOUNTS_COLLECTION, firebase_uid, payload, true)
			return true

	if backend.has_method("firestoreSetDocument"):
		backend.firestoreSetDocument(FIRESTORE_ACCOUNTS_COLLECTION, firebase_uid, payload, true)
		return true

	if backend.has_method("set_document"):
		backend.set_document(FIRESTORE_ACCOUNTS_COLLECTION, firebase_uid, payload, true)
		return true

	return false


func _decode_firestore_value(value):
	if typeof(value) != TYPE_DICTIONARY:
		return value
	if value.has("stringValue"):
		return str(value.get("stringValue", ""))
	if value.has("integerValue"):
		return int(value.get("integerValue", 0))
	if value.has("doubleValue"):
		return float(value.get("doubleValue", 0.0))
	if value.has("booleanValue"):
		return bool(value.get("booleanValue", false))
	if value.has("nullValue"):
		return null
	if value.has("timestampValue"):
		return value.get("timestampValue")
	if value.has("mapValue"):
		var map_value = value.get("mapValue", {})
		if typeof(map_value) == TYPE_DICTIONARY:
			return _decode_firestore_fields(map_value.get("fields", {}))
	if value.has("arrayValue"):
		var array_value = value.get("arrayValue", {})
		var decoded: Array = []
		if typeof(array_value) == TYPE_DICTIONARY:
			for item in array_value.get("values", []):
				decoded.append(_decode_firestore_value(item))
		return decoded
	return value


func _decode_firestore_fields(fields) -> Dictionary:
	var decoded: Dictionary = {}
	if typeof(fields) != TYPE_DICTIONARY:
		return decoded
	for key in fields.keys():
		decoded[key] = _decode_firestore_value(fields.get(key))
	return decoded


func _extract_firestore_document_data(result) -> Dictionary:
	if typeof(result) != TYPE_DICTIONARY:
		return {}
	if result.has("data") and typeof(result.get("data")) == TYPE_DICTIONARY:
		var data_result: Dictionary = result.get("data")
		if data_result.has("fields") and typeof(data_result.get("fields")) == TYPE_DICTIONARY:
			return _decode_firestore_fields(data_result.get("fields"))
		return data_result
	if result.has("document") and typeof(result.get("document")) == TYPE_DICTIONARY:
		var document_data: Dictionary = result.get("document")
		if document_data.has("data") and typeof(document_data.get("data")) == TYPE_DICTIONARY:
			var nested_data: Dictionary = document_data.get("data")
			if nested_data.has("fields") and typeof(nested_data.get("fields")) == TYPE_DICTIONARY:
				return _decode_firestore_fields(nested_data.get("fields"))
			return nested_data
		if document_data.has("fields") and typeof(document_data.get("fields")) == TYPE_DICTIONARY:
			return _decode_firestore_fields(document_data.get("fields"))
		return document_data
	if result.has("fields") and typeof(result.get("fields")) == TYPE_DICTIONARY:
		return _decode_firestore_fields(result.get("fields"))
	return result


func _document_has_remote_profile(result, document_data: Dictionary) -> bool:
	if typeof(result) == TYPE_DICTIONARY:
		if result.has("exists"):
			return bool(result.get("exists"))
		if result.has("found"):
			return bool(result.get("found"))
		if result.has("success") and not bool(result.get("success")) and document_data.is_empty():
			return false
	return not document_data.is_empty()


func apply_firestore_profile(result, fallback_name: String = "") -> Dictionary:
	var document_data: Dictionary = _extract_firestore_document_data(result)
	var has_remote_profile: bool = _document_has_remote_profile(result, document_data)

	if has_remote_profile:
		firebase_uid = _pick_first_non_empty([
			document_data.get("firebase_uid", ""),
			document_data.get("uid", ""),
			firebase_uid,
		])
		id_publico_numero = int(document_data.get("public_id_number", 0))
		id_usuario = _pick_first_non_empty([
			document_data.get("id_usuario", ""),
			document_data.get("public_id", ""),
			id_usuario,
		])
		if id_publico_numero <= 0:
			id_publico_numero = _extraer_numero_id_publico(id_usuario)
		_asegurar_id_publico()
		nombre_usuario = _pick_first_non_empty([
			document_data.get("nombre_usuario", ""),
			document_data.get("username", ""),
			document_data.get("name", ""),
			fallback_name,
			nombre_usuario,
		])
		email_usuario = _pick_first_non_empty([
			document_data.get("email", ""),
			email_usuario,
		])
		proveedor_auth = _pick_first_non_empty([
			document_data.get("provider", ""),
			document_data.get("auth_provider", ""),
			proveedor_auth,
			"google",
		])
		esmeraldas = int(document_data.get("esmeraldas", document_data.get("emeralds", 0)))
		dinero = float(document_data.get("dinero", document_data.get("money", 0.0)))
		avatar_path = str(document_data.get("avatar_path", ""))
		if avatar_path != "" and ResourceLoader.exists(avatar_path):
			avatar_texture = load(avatar_path)
		else:
			avatar_texture = null
		save_local()
		_emit_nombre_usuario_actualizado()
		return {
			"exists": true,
			"name": nombre_usuario,
			"needs_public_id_assignment": needs_public_id_assignment(),
			"data": document_data,
		}

	nombre_usuario = _resolve_account_name({
		"name": fallback_name,
		"email": email_usuario,
	}, fallback_name)
	id_publico_numero = 0
	id_usuario = ""
	esmeraldas = 0
	dinero = 0.0
	avatar_path = ""
	avatar_texture = null
	save_local()
	sync_account_to_firebase({
		"last_login_unix": Time.get_unix_time_from_system(),
		"profile_created_from_google_login": true,
	})
	_emit_nombre_usuario_actualizado()
	return {
		"exists": false,
		"name": nombre_usuario,
		"needs_public_id_assignment": true,
		"data": _build_firestore_payload(true),
	}


func apply_authenticated_profile(auth_result, fallback_name: String = "", use_local_cache: bool = false) -> Dictionary:
	var auth_profile: Dictionary = _extract_auth_profile(auth_result)
	var auth_uid: String = str(auth_profile.get("uid", "")).strip_edges()
	var previous_uid: String = firebase_uid
	var previous_public_id_number: int = id_publico_numero
	var previous_name: String = nombre_usuario
	var previous_public_id: String = id_usuario
	var had_local: bool = false
	if use_local_cache:
		had_local = load_local()
		previous_uid = firebase_uid
		previous_public_id_number = id_publico_numero
		previous_name = nombre_usuario
		previous_public_id = id_usuario

	firebase_uid = auth_uid
	id_publico_numero = previous_public_id_number
	id_usuario = previous_public_id
	if not (had_local and previous_uid != "" and previous_uid == auth_uid and id_publico_numero > 0):
		id_publico_numero = 0
		id_usuario = ""
	_asegurar_id_publico()
	email_usuario = str(auth_profile.get("email", "")).strip_edges()
	proveedor_auth = _pick_first_non_empty([
		auth_profile.get("provider", ""),
		proveedor_auth,
		"google",
	])

	var resolved_name: String = _resolve_account_name(auth_profile, fallback_name)
	if had_local and previous_uid != "" and previous_uid == auth_uid:
		nombre_usuario = resolved_name
		if nombre_usuario == "":
			nombre_usuario = previous_name
	else:
		esmeraldas = 0
		dinero = 0.0
		avatar_path = ""
		avatar_texture = null
		nombre_usuario = resolved_name

	if nombre_usuario == "" or nombre_usuario.strip_edges() == "":
		nombre_usuario = generar_nombre_aleatorio()

	save_local()
	sync_identity_to_firebase({
		"last_login_unix": Time.get_unix_time_from_system(),
		"auth_provider": proveedor_auth,
	})
	_emit_nombre_usuario_actualizado()

	auth_profile["uid"] = firebase_uid
	auth_profile["public_id"] = id_usuario
	auth_profile["public_id_number"] = id_publico_numero
	auth_profile["name"] = nombre_usuario
	auth_profile["email"] = email_usuario
	auth_profile["provider"] = proveedor_auth
	return auth_profile


func clear_session(clear_persistent: bool = true) -> void:
	id_usuario = ""
	firebase_uid = ""
	id_publico_numero = 0
	nombre_usuario = ""
	email_usuario = ""
	proveedor_auth = ""
	esmeraldas = 0
	dinero = 0.0
	next_scene = ""
	previous_scene = ""
	avatar_path = ""
	avatar_texture = null
	if clear_persistent:
		save_local()
	_emit_nombre_usuario_actualizado()


# Compatibilidad: anteriormente esta función usaba Supabase.
# Ahora intenta cargar datos locales y, si no existen, crea un perfil local.
func cargar_perfil_desde_supabase(auth_result) -> void:
	var applied_profile: Dictionary = apply_authenticated_profile(auth_result)
	print("[DatosUsuario] Perfil autenticado aplicado:", applied_profile)
	_entrar_al_juego()

func _crear_nuevo_perfil(nombre: String) -> void:
	# Si el nombre pasado es vacío o es el placeholder, generar uno aleatorio
	if nombre == null or nombre == "" or nombre.strip_edges() == "" or nombre == "Conductor":
		nombre_usuario = generar_nombre_aleatorio()
	else:
		nombre_usuario = nombre
	esmeraldas = 0
	dinero = 0.0

	# Guardar localmente siempre
	var saved: bool = save_local()
	if not saved:
		printerr("No se pudo guardar el perfil localmente")
	elif firebase_uid != "":
		sync_account_to_firebase({"profile_created_locally": true})

	# Continuar al juego
	_entrar_al_juego()

func _aplicar_datos(data):
	nombre_usuario = _pick_first_non_empty([
		data.get("nombre_usuario", ""),
		data.get("username", ""),
		data.get("name", ""),
		nombre_usuario,
	])
	esmeraldas = int(data.get("esmeraldas", data.get("emeralds", 0)))
	# Leer dinero si está presente en la fila de la base de datos (fallback 0.0)
	dinero = float(data.get("dinero", data.get("money", 0.0)))
	print("Datos cargados: ", nombre_usuario, " tiene ", esmeraldas, " esmeraldas y ", dinero, " dinero.")
	# Guardar una copia local para uso offline
	save_local()
	_entrar_al_juego()

func _entrar_al_juego():
	# Asegúrate de que esta ruta sea la correcta para tu escena de Fusagasugá
	# Antes de entrar, asegurarnos de tener un nombre de usuario
	if nombre_usuario == "" or nombre_usuario.strip_edges() == "":
		nombre_usuario = generar_nombre_aleatorio()
		save_local()

	var path = "res://interfaz/pantallas/carga/Escena_carga.tscn"
	if ResourceLoader.exists(path):
		next_scene = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
		get_tree().change_scene_to_file(path)
	else:
		# Fallback directo al main menu si no existe la pantalla de carga
		var menu_path = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
		if ResourceLoader.exists(menu_path):
			get_tree().change_scene_to_file(menu_path)
		else:
			print("Error: No se encuentran las escenas de destino.")


func generar_nombre_aleatorio() -> String:
	randomize()
	# Formato solicitado: Prefijo#sufijo (ej. Panter#iujhioosj)
	var prefixes: Array = ["Panter", "Pantera", "Panther", "Lynx", "Raven"]
	var prefix: String = prefixes[randi() % prefixes.size()]
	var chars: String = "abcdefghijklmnopqrstuvwxyz"
	var suffix: String = ""
	for i in range(9):
		suffix += chars[randi() % chars.length()]
	return "%s#%s" % [prefix, suffix]


func set_nombre_usuario(new_name: String, guardar: bool = true) -> void:
	# Actualiza el nombre en memoria, guarda local si se solicita y emite señal
	nombre_usuario = new_name
	if guardar:
		save_local()
		sync_account_to_firebase({"nombre_actualizado": true})
	# Emitir señal para que UI pueda reaccionar inmediatamente
	emit_signal("nombre_usuario_cambiado", nombre_usuario)

func set_avatar_texture(tex: Texture2D, guardar: bool = true) -> void:
	avatar_texture = tex
	if tex != null:
		# Si la textura viene de un recurso con path, guardamos la ruta
		if "resource_path" in tex and tex.resource_path != "":
			avatar_path = tex.resource_path
	else:
		avatar_path = ""
	if guardar:
		save_local()
	emit_signal("avatar_cambiada", avatar_texture)

func guardar_progreso() -> void:
	# Guardado local simple: la integración con Supabase se ha eliminado de este módulo.
	var saved: bool = save_local()
	if saved:
		sync_account_to_firebase({"progress_synced": true})
		print("Progreso guardado localmente ✅")
	else:
		printerr("Error guardando progreso localmente")

func completar_mision_licencia() -> void:
	if not mision_licencia_completada:
		mision_licencia_completada = true
		trabajos_legales_desbloqueados = true
		agregar_experiencia(100) # Otorga 100 EXP
		save_local()

func agregar_experiencia(puntos: int) -> void:
	_agregar_experiencia_base(_experiencia_con_bonus(puntos))


func _experiencia_con_bonus(puntos: int) -> int:
	if puntos <= 0:
		return puntos
	if tiene_pase_elite():
		return int(round(float(puntos) * PASE_ELITE_MULT_XP))
	return puntos


func _agregar_experiencia_base(puntos: int) -> void:
	experiencia += puntos
	print("[DatosUsuario] Experiencia aÃ±adida: +", puntos, " | Total en este nivel: ", experiencia)
	
	# Verificar si sube de nivel con reinicio de barra a 0 (acumulando el sobrante)
	var req = (nivel + 1) * 300
	var subio_nivel = false
	while experiencia >= req:
		experiencia -= req
		nivel += 1
		_otorgar_premios_nivel(nivel)
		req = (nivel + 1) * 300
		subio_nivel = true
		
	if subio_nivel:
		save_local()


# ── Pase Élite ────────────────────────────────────────────────────────────
func tiene_pase_elite() -> bool:
	return pase_elite_activo


func costo_pase_elite() -> float:
	return PASE_ELITE_COSTO


func recompensas_pase() -> Array:
	return PASE_ELITE_RECOMPENSAS.duplicate(true)


func comprar_pase_elite() -> bool:
	if pase_elite_activo:
		return false
	if dinero < PASE_ELITE_COSTO:
		return false
	dinero -= PASE_ELITE_COSTO
	pase_elite_activo = true
	pase_elite_desde = fecha_hoy()
	pase_elite_ultimo_reclamo = "" # Permite reclamar el primer día justo después de comprar.
	pase_elite_dias_reclamados = 0
	save_local(true)
	print("[DatosUsuario] Pase Elite activado. Efectivo restante: ", dinero)
	return true


func fecha_hoy() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(d.get("year", 1970)), int(d.get("month", 1)), int(d.get("day", 1))
	]


func puede_reclamar_pase() -> bool:
	if not pase_elite_activo:
		return false
	return pase_elite_ultimo_reclamo != fecha_hoy()


func dia_pase_actual() -> int:
	if not pase_elite_activo:
		return 1
	return (pase_elite_dias_reclamados % PASE_ELITE_DIAS_CICLO) + 1


func ciclo_pase_actual() -> int:
	if not pase_elite_activo:
		return 1
	return int(floor(float(pase_elite_dias_reclamados) / float(PASE_ELITE_DIAS_CICLO))) + 1


func recompensa_pase_dia(dia: int) -> Dictionary:
	var indice: int = clampi(dia - 1, 0, PASE_ELITE_RECOMPENSAS.size() - 1)
	var dato: Dictionary = PASE_ELITE_RECOMPENSAS[indice]
	return dato.duplicate(true)


func reclamar_pase_diario() -> Dictionary:
	if not puede_reclamar_pase():
		return {}
	var dia := dia_pase_actual()
	var premio := recompensa_pase_dia(dia)
	var monedas := float(premio.get("monedas", 0.0))
	var xp := int(premio.get("experiencia", 0))
	dinero += monedas
	pase_elite_ultimo_reclamo = fecha_hoy()
	pase_elite_dias_reclamados += 1
	# Se usa la base para no duplicar el bono de experiencia del pase.
	_agregar_experiencia_base(xp)
	save_local(true)
	return {
		"dia": dia,
		"monedas": monedas,
		"experiencia": xp,
		"bono": bool(premio.get("bono", false)),
		"dias_totales": pase_elite_dias_reclamados,
		"nivel": nivel,
	}


func segundos_hasta_proximo_pase() -> int:
	if not pase_elite_activo or puede_reclamar_pase():
		return 0
	var t: Dictionary = Time.get_time_dict_from_system()
	var transcurridos: int = (
		int(t.get("hour", 0)) * 3600 + int(t.get("minute", 0)) * 60 + int(t.get("second", 0))
	)
	return maxi(0, 86400 - transcurridos)


func _otorgar_premios_nivel(n: int) -> void:
	var premio_esmeraldas = n
	esmeraldas += premio_esmeraldas
	
	var premio_monedas = 100 + (n - 1) * 50
	dinero += premio_monedas
	
	# Mostrar celebraciÃ³n en pantalla completa
	_mostrar_celebracion_nivel(n, premio_esmeraldas, premio_monedas)

func _mostrar_celebracion_nivel(n: int, prem_esm: int, prem_mon: int) -> void:
	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	
	var canvas = CanvasLayer.new()
	canvas.name = "LevelUpOverlay"
	canvas.layer = 100
	
	var root = get_tree().current_scene if get_tree() else null
	if root:
		root.add_child(canvas)
	else:
		return
	
	# 1. Reproducir sonido de subida de nivel (level_up.mp3)
	var sfx = AudioStreamPlayer.new()
	sfx.name = "LevelUpSFX"
	var stream_res = load("res://recursos/efectos/level_up.mp3")
	if stream_res:
		sfx.stream = stream_res
		canvas.add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 35)
	center.add_child(vbox)
	
	# Icono/NÃºmero de Nivel
	var icon_lbl = Label.new()
	icon_lbl.text = "⚡"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 140)
	vbox.add_child(icon_lbl)
	
	# TÃ­tulo principal: Â¡NUEVO NIVEL X!
	var title_lbl = Label.new()
	title_lbl.text = "¡NUEVO NIVEL %d!" % n
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 60)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1)) # Dorado
	title_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_constant_override("shadow_outline_size", 12)
	if font:
		title_lbl.add_theme_font_override("font", font)
	vbox.add_child(title_lbl)

# Contenedor para recompensas con iconos (money.png y esmeralda.png)
	var rewards_container = HBoxContainer.new()
	rewards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_container.add_theme_constant_override("separation", 60)
	rewards_container.modulate.a = 0.0 # Invisible al inicio
	vbox.add_child(rewards_container)

# Columna Esmeraldas
	var esm_vbox = VBoxContainer.new()
	esm_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	esm_vbox.add_theme_constant_override("separation", 10)
	rewards_container.add_child(esm_vbox)

	var esm_icon = TextureRect.new()
	esm_icon.custom_minimum_size = Vector2(40, 40)
	esm_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	esm_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	esm_icon.texture = load("res://recursos/botones/Esmeralda.png")
	esm_vbox.add_child(esm_icon)

	var esm_lbl = Label.new()
	esm_lbl.text = "+%d ESMERALDAS" % prem_esm
	esm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esm_lbl.add_theme_font_size_override("font_size", 28)
	esm_lbl.add_theme_color_override("font_color", Color(0.14, 0.85, 0.45)) # Verde esmeralda
	esm_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	esm_lbl.add_theme_constant_override("shadow_outline_size", 8)
	if font:
		esm_lbl.add_theme_font_override("font", font)
	esm_vbox.add_child(esm_lbl)

# Columna Monedas
	var mon_vbox = VBoxContainer.new()
	mon_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mon_vbox.add_theme_constant_override("separation", 10)
	rewards_container.add_child(mon_vbox)

	var mon_icon = TextureRect.new()
	mon_icon.custom_minimum_size = Vector2(90, 90)
	mon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mon_icon.texture = load("res://recursos/botones/money.png")
	mon_vbox.add_child(mon_icon)

	var mon_lbl = Label.new()
	mon_lbl.text = "+$%d COP" % prem_mon
	mon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mon_lbl.add_theme_font_size_override("font_size", 28)
	mon_lbl.add_theme_color_override("font_color", Color(0.20, 0.80, 1.00)) # Azul
	mon_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	mon_lbl.add_theme_constant_override("shadow_outline_size", 8)
	if font:
		mon_lbl.add_theme_font_override("font", font)
	mon_vbox.add_child(mon_lbl)

# Configurar el pivote de escala del VBox para que se mueva como unidad
	vbox.pivot_offset = Vector2(350, 220)

# Configurar animaciÃ³n secuencial
	var main_tw = get_tree().create_tween()

# 1. AnimaciÃ³n del tÃ­tulo/nÃºmero de abajo hacia arriba con fade-in y escala aumentada
	vbox.modulate.a = 0.0
	vbox.scale = Vector2(1.3, 1.3)
	var original_pos_y = vbox.position.y
	vbox.position.y += 350

	var slide_tw = get_tree().create_tween().set_parallel(true)
	slide_tw.tween_property(vbox, "position:y", original_pos_y, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide_tw.tween_property(vbox, "modulate:a", 1.0, 0.5)

# 2. Encogimiento (shrink) despuÃ©s de subir
	main_tw.tween_interval(0.65) # Esperar a que termine la subida
	main_tw.tween_property(vbox, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# 3. Al aparecer recompensas, reproducir el sonido money.mp3 y fade-in del contenedor
	main_tw.tween_callback(func():
		var sfx_money = AudioStreamPlayer.new()
		sfx_money.name = "MoneySFX"
		var money_stream = load("res://recursos/efectos/money.mp3")
		if money_stream:
			sfx_money.stream = money_stream
			canvas.add_child(sfx_money)
			sfx_money.play()
			sfx_money.finished.connect(func(): sfx_money.queue_free())
	)
	main_tw.tween_property(rewards_container, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# 4. Desvanecido final y limpieza del overlay
	var fade_tw = get_tree().create_tween()
	fade_tw.tween_interval(4.2)
	fade_tw.tween_property(vbox, "modulate:a", 0.0, 0.6)
	fade_tw.tween_callback(func():
		canvas.queue_free()
)


func tiene_licencia(categoria: String) -> bool:
	match categoria.to_upper().strip_edges():
		"C1":
			return licencia_c1
		"C2":
			return licencia_c2
		"C3":
			return licencia_c3
		_:
			return false

func otorgar_licencia(categoria: String) -> void:
	match categoria.to_upper().strip_edges():
		"C1":
			licencia_c1 = true
			licencia_automovil = true
		"C2":
			licencia_c2 = true
			licencia_camion = true
			mision_licencia_completada = true
			trabajos_legales_desbloqueados = true
		"C3":
			licencia_c3 = true
			licencia_c2 = true
			licencia_camion = true
			licencia_carga_sobredimensionada = true
			mision_licencia_completada = true
			trabajos_legales_desbloqueados = true
	save_local()
