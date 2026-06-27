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
var proveedor_auth : String = ""
var esmeraldas : int = 0
var dinero : float = 0.0
var next_scene : String = ""
var previous_scene : String = ""
var avatar_path: String = ""
var avatar_texture: Texture2D = null
var vehiculos_personalizados : Dictionary = {}
var tutorial_completado : bool = false
var tutorial_celular_completado : bool = false
var guardado_player_pos : Vector3 = Vector3.ZERO
var guardado_player_rot_y : float = 0.0
var guardado_player_scene : String = ""

const LOCAL_SAVE_PATH := "user://datos_usuario.cfg"
const FIRESTORE_ACCOUNTS_COLLECTION := "conductores"
const FIRESTORE_META_COLLECTION := "meta"
const FIRESTORE_PUBLIC_ID_COUNTER_DOCUMENT := "public_id_counter"
const USER_PUBLIC_ID_PREFIX := "NT"
const USER_PUBLIC_ID_MIN_DIGITS := 2

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

# Guardado local (ConfigFile) -------------------------------------------------
func save_local() -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("usuario", "id_usuario", id_usuario)
	cfg.set_value("usuario", "firebase_uid", firebase_uid)
	cfg.set_value("usuario", "id_publico_numero", id_publico_numero)
	cfg.set_value("usuario", "nombre_usuario", nombre_usuario)
	cfg.set_value("usuario", "email_usuario", email_usuario)
	cfg.set_value("usuario", "proveedor_auth", proveedor_auth)
	cfg.set_value("usuario", "esmeraldas", esmeraldas)
	cfg.set_value("usuario", "dinero", dinero)
	cfg.set_value("usuario", "avatar_path", avatar_path)
	cfg.set_value("usuario", "vehiculos_personalizados", vehiculos_personalizados)
	cfg.set_value("usuario", "tutorial_completado", tutorial_completado)
	cfg.set_value("usuario", "tutorial_celular_completado", tutorial_celular_completado)
	cfg.set_value("usuario", "guardado_player_pos", guardado_player_pos)
	cfg.set_value("usuario", "guardado_player_rot_y", guardado_player_rot_y)
	cfg.set_value("usuario", "guardado_player_scene", guardado_player_scene)
	var err: int = cfg.save(LOCAL_SAVE_PATH)
	if err == OK:
		print("[DatosUsuario] Guardado local en:", LOCAL_SAVE_PATH)
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
			proveedor_auth = str(cfg.get_value("usuario", "proveedor_auth", ""))
			esmeraldas = int(cfg.get_value("usuario", "esmeraldas", 0))
			dinero = float(cfg.get_value("usuario", "dinero", 0.0))
			avatar_path = str(cfg.get_value("usuario", "avatar_path", ""))
			vehiculos_personalizados = cfg.get_value("usuario", "vehiculos_personalizados", {})
			tutorial_completado = bool(cfg.get_value("usuario", "tutorial_completado", false))
			tutorial_celular_completado = bool(cfg.get_value("usuario", "tutorial_celular_completado", false))
			guardado_player_pos = cfg.get_value("usuario", "guardado_player_pos", Vector3.ZERO)
			guardado_player_rot_y = float(cfg.get_value("usuario", "guardado_player_rot_y", 0.0))
			guardado_player_scene = str(cfg.get_value("usuario", "guardado_player_scene", ""))
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

	var path = "res://escenas/Escena_carga/Escena_carga.tscn"
	if ResourceLoader.exists(path):
		next_scene = "res://escenas/main menu/Main-Menu.tscn"
		get_tree().change_scene_to_file(path)
	else:
		# Fallback directo al main menu si no existe la pantalla de carga
		var menu_path = "res://escenas/main menu/Main-Menu.tscn"
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