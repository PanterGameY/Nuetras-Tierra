extends CanvasLayer

# --- REFERENCIAS A NODOS (% UNIQUE NAMES) ---
@onready var panel_login: PanelContainer = %PanelLogin
@onready var panel_registro: PanelContainer = %PanelRegistro
@onready var panel_nombre_usuario: PanelContainer = %PanelNombreUsuario
@onready var loading_overlay: ColorRect = %LoadingOverlay

# Labels de Error
@onready var label_error_login: Label = %LabelError
@onready var label_error_reg: Label = %LabelErrorReg
@onready var label_error_nombre: Label = %LabelErrorNombre

# Inputs de Texto
@onready var input_email_login: LineEdit = %InputEmail
@onready var input_pass_login: LineEdit = %InputPassword
@onready var input_nombre_final: LineEdit = %InputNombre
@onready var btn_invitado: Button = %BtnInvitado

# Variables temporales para la sesión
var id_temp = ""
var _pending_auth_request_id: int = 0
var _pending_profile_fetch_uid: String = ""
var _pending_profile_name: String = ""
var _pending_firestore_get_kind: String = ""
var _show_firestore_feedback: bool = false
const FONT := preload("res://recursos/fonts/Moderniz.otf")
const DEBUG := true

# Nombre oficial del Singleton nativo del nuevo plugin
const PLUGIN_NAME = "GodotFirebaseAndroid"
const LOGIN_MUSIC_PATH := "res://recursos/Musica/Puya-vallenata.mp3"
var _audio_player: AudioStreamPlayer = null
var _login_music_playing: bool = false

func _ready() -> void:
	_aplicar_diseno_visual()
	
	# Esperamos un frame para garantizar que el motor registre los Singletons nativos de Android
	await get_tree().process_frame
	var firebase_root = get_node_or_null("/root/Firebase")
	# Intentamos conectar con el backend: preferimos el autoload `Firebase`,
	# si no existe usamos el singleton nativo `GodotFirebaseAndroid`.
	if firebase_root:
		var fb = firebase_root
		# Señales del módulo Auth
		if fb.auth and fb.auth.has_signal("auth_success") and not fb.auth.auth_success.is_connected(_on_auth_success):
			fb.auth.auth_success.connect(_on_auth_success)
		if fb.auth and fb.auth.has_signal("auth_failure") and not fb.auth.auth_failure.is_connected(_on_auth_failed):
			fb.auth.auth_failure.connect(_on_auth_failed)
		# Señales del módulo Firestore (nombres del wrapper)
		if fb.firestore and fb.firestore.has_signal("write_task_completed") and not fb.firestore.write_task_completed.is_connected(_on_test_document_written):
			fb.firestore.write_task_completed.connect(_on_test_document_written)
		if fb.firestore and fb.firestore.has_signal("get_task_completed") and not fb.firestore.get_task_completed.is_connected(_on_firestore_document_loaded):
			fb.firestore.get_task_completed.connect(_on_firestore_document_loaded)
		
		if fb.auth and fb.auth.has_method("is_signed_in"):
			print("LoginScreen: Usuario ya logueado al iniciar:", fb.auth.is_signed_in())
		
		if DEBUG: print("LoginScreen: Enlazado con éxito al autoload Firebase.")
	elif Engine.has_singleton(PLUGIN_NAME):
		var firebase = Engine.get_singleton(PLUGIN_NAME)
		# Conexión directa y segura de señales de Autenticación (plugin nativo)
		if firebase.has_signal("auth_success") and not firebase.auth_success.is_connected(_on_auth_success):
			firebase.auth_success.connect(_on_auth_success)
		if firebase.has_signal("auth_failure") and not firebase.auth_failure.is_connected(_on_auth_failed):
			firebase.auth_failure.connect(_on_auth_failed)
		# Señales del plugin nativo (nombres anteriores/compatibilidad)
		if firebase.has_signal("document_written") and not firebase.document_written.is_connected(_on_test_document_written):
			firebase.document_written.connect(_on_test_document_written)
		if firebase.has_signal("document_write_failed") and not firebase.document_write_failed.is_connected(_on_test_document_failed):
			firebase.document_write_failed.connect(_on_test_document_failed)
		if DEBUG: print("LoginScreen: Enlazado con éxito al plugin nativo GodotFirebaseAndroid.")
	else:
		if DEBUG: print("LoginScreen ADVERTENCIA: Plugin nativo no detectado (Comportamiento normal en PC).")

	# Conectar botones de la interfaz
	# Conectar botones de la interfaz (comprobando existencia para evitar null)
	var _btn = null

	_btn = get_node_or_null("%BtnGoogle")
	if _btn:
		_btn.pressed.connect(_on_google_pressed)
	elif DEBUG:
		print("LoginScreen: BtnGoogle no encontrado en la escena.")

	_btn = get_node_or_null("%BtnIngresar")
	if _btn:
		_btn.pressed.connect(_on_ingresar_pressed)
	elif DEBUG:
		print("LoginScreen: BtnIngresar no encontrado en la escena.")

	_btn = get_node_or_null("%BtnInvitado")
	if _btn:
		_btn.pressed.connect(_on_invitado_pressed)
	elif DEBUG:
		print("LoginScreen: BtnInvitado no encontrado en la escena.")

	_btn = get_node_or_null("%BtnRegistrar")
	if _btn:
		_btn.pressed.connect(_on_registrar_pressed)
	elif DEBUG:
		print("LoginScreen: BtnRegistrar no encontrado en la escena.")

	_btn = get_node_or_null("%BtnTestGuardar")
	if _btn:
		_btn.pressed.connect(_on_test_guardar_pressed)
	elif DEBUG:
		print("LoginScreen: BtnTestGuardar no encontrado en la escena.")

	_btn = get_node_or_null("%BtnConfirmar")
	if _btn:
		_btn.pressed.connect(_on_confirmar_nombre_pressed)
	elif DEBUG:
		print("LoginScreen: BtnConfirmar no encontrado en la escena.")

	_btn = get_node_or_null("%BtnVolverLogin")
	if _btn:
		_btn.pressed.connect(_reset_ui)

	_btn = get_node_or_null("%BtnCerrar")
	if _btn:
		_btn.pressed.connect(func(): get_tree().quit())

	_btn = get_node_or_null("%BtnConfig")
	if _btn:
		_btn.pressed.connect(func():
			if has_node("/root/SettingsManager"):
				get_node("/root/SettingsManager").change_to_settings()
			else:
				get_tree().change_scene_to_file("res://escenas/configuraciones/configuraciones.tscn")
		)

	# Redes Sociales - Login
	_conectar_red_social("%Youtube", "https://www.youtube.com/@PanterStudioGameDev")
	_conectar_red_social("%Facebook", "https://www.facebook.com/profile.php?id=61573824572822")
	_conectar_red_social("%Instagram", "https://www.instagram.com/panterstudio_gamedev/")
	_conectar_red_social("%Tiktok", "https://www.tiktok.com/@panterstudiogamedev")
	_conectar_red_social("%X", "https://x.com/PanterStudio")
	_conectar_red_social("%Whatsapp", "https://www.whatsapp.com/channel/0029Vb7E2oX2ZjCkY2rz5K20")
	_conectar_red_social("%Discord", "https://discord.gg/8xqXfR54EW")

	_reset_ui()

	# Iniciar música de fondo para la pantalla de login (si existe)
	_start_login_music()

# --- VERIFICADOR DEL BACKEND NATIVO ---

func _get_firebase_backend() -> Object:
	# Devuelve primero el autoload `Firebase` (wrapper GDScript con módulos),
	# si no existe devuelve el singleton nativo `GodotFirebaseAndroid`.
	var firebase_root = get_node_or_null("/root/Firebase")
	if firebase_root:
		return firebase_root
	if Engine.has_singleton(PLUGIN_NAME):
		return Engine.get_singleton(PLUGIN_NAME)
	return null

func _ensure_backend_available(action_name: String) -> bool:
	if _get_firebase_backend():
		return true
	_show_loading(false)
	_mostrar_error(label_error_login, "Firebase no está disponible en PC. Exporta el APK para probar %s." % action_name)
	return false

# --- MANEJO DE TIMEOUTS ---

func _start_auth_timeout(action_name: String, seconds: float = 12.0) -> void:
	_pending_auth_request_id += 1
	var request_id: int = _pending_auth_request_id
	_watch_auth_timeout(request_id, action_name, seconds)

func _clear_auth_timeout() -> void:
	_pending_auth_request_id += 1

func _watch_auth_timeout(request_id: int, action_name: String, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if request_id != _pending_auth_request_id: return
	_pending_auth_request_id += 1
	_show_loading(false)
	_mostrar_error(label_error_login, "El servidor no respondió al %s." % action_name)

func _first_non_empty_value(candidates: Array) -> String:
	for candidate in candidates:
		var text: String = str(candidate).strip_edges()
		if text != "" and text.to_lower() != "null":
			return text
	return ""

func _merge_auth_dictionary(normalized: Dictionary, source: Dictionary) -> void:
	if str(normalized.get("uid", "")).strip_edges() == "":
		normalized["uid"] = _first_non_empty_value([
			source.get("uid", ""),
			source.get("user_id", ""),
			source.get("id", ""),
			source.get("localId", ""),
		])
	if str(normalized.get("email", "")).strip_edges() == "":
		normalized["email"] = _first_non_empty_value([
			source.get("email", ""),
			source.get("mail", ""),
		])
	if str(normalized.get("name", "")).strip_edges() == "" or str(normalized.get("name", "")) == "Conductor":
		normalized["name"] = _first_non_empty_value([
			source.get("name", ""),
			source.get("display_name", ""),
			source.get("displayName", ""),
			source.get("full_name", ""),
			source.get("username", ""),
		])

	var metadata = source.get("user_metadata", source.get("metadata", {}))
	if typeof(metadata) == TYPE_DICTIONARY:
		if str(normalized.get("name", "")).strip_edges() == "" or str(normalized.get("name", "")) == "Conductor":
			normalized["name"] = _first_non_empty_value([
				metadata.get("full_name", ""),
				metadata.get("name", ""),
				metadata.get("display_name", ""),
				metadata.get("displayName", ""),
			])
		if str(normalized.get("email", "")).strip_edges() == "":
			normalized["email"] = _first_non_empty_value([metadata.get("email", "")])

	var provider_data = source.get("providerData", source.get("provider_data", []))
	if typeof(provider_data) == TYPE_ARRAY:
		for entry in provider_data:
			if typeof(entry) == TYPE_DICTIONARY:
				_merge_auth_dictionary(normalized, entry)

	var nested_user = source.get("user", null)
	if typeof(nested_user) == TYPE_DICTIONARY:
		_merge_auth_dictionary(normalized, nested_user)

# --- NORMALIZADOR DE USUARIO MIGRADO ---

func _normalize_auth_user(user_data) -> Dictionary:
	var normalized: Dictionary = {
		"uid": "",
		"name": "Conductor",
		"email": "",
	}
	if user_data == null: return normalized

	if typeof(user_data) == TYPE_DICTIONARY:
		_merge_auth_dictionary(normalized, user_data)
		if str(normalized.get("name", "")).strip_edges() == "":
			normalized["name"] = "Conductor"
		return normalized
		
	if typeof(user_data) == TYPE_OBJECT:
		if user_data.has_method("get_uid"): normalized["uid"] = str(user_data.get_uid())
		elif user_data.has_method("get_user_id"): normalized["uid"] = str(user_data.get_user_id())
		
		var obj_name = ""
		if user_data.has_method("get_name"): obj_name = str(user_data.get_name())
		elif user_data.has_method("get_display_name"): obj_name = str(user_data.get_display_name())
		elif user_data.has_method("get_display_name_google"): obj_name = str(user_data.get_display_name_google())
		
		if obj_name != "":
			normalized["name"] = obj_name
		
		if user_data.has_method("get_email"): normalized["email"] = str(user_data.get_email())

	return normalized

# --- ACCIONES DE BOTONES ---

func _on_google_pressed() -> void:
	if not _ensure_backend_available("login con Google"): return
	
	_show_loading(true, "Conectando con Google...")
	_start_auth_timeout("inicio de sesión con Google")
	var backend = _get_firebase_backend()
	print("[LoginScreen] _on_google_pressed - backend:", backend, "autoload Firebase:", get_node_or_null("/root/Firebase") != null)
	if not backend:
		_show_loading(false)
		_clear_auth_timeout()
		_mostrar_error(label_error_login, "Firebase no está disponible.")
		return
	# Preferimos el autoload `Firebase` (módulo `auth`)
	if backend and "auth" in backend:
		var fb = backend
		if fb.auth and fb.auth.has_method("sign_in_with_google"):
			print("[LoginScreen] forcing sign_out and brief wait to show picker")
			# Intentamos cerrar sesión en Firebase Y en Google Play Services si el plugin lo soporta
			if fb.auth.has_method("sign_out"):
				fb.auth.sign_out()
			
			# Si el backend base tiene un método específico para revocar o limpiar Google
			if backend.has_method("googleSignOut"):
				backend.googleSignOut()
			elif backend.has_method("signOutFromGoogle"):
				backend.signOutFromGoogle()
				
			await get_tree().create_timer(0.6).timeout # Aumentamos espera para asegurar proceso
			print("[LoginScreen] calling fb.auth.sign_in_with_google()")
			fb.auth.sign_in_with_google()
		else:
			_show_loading(false)
			_clear_auth_timeout()
			_mostrar_error(label_error_login, "El autoload 'Firebase' no expone 'sign_in_with_google'.")
		return
	# Fallback al plugin nativo (camelCase)
	# Intentar usar el wrapper Auth.gd aunque no exista el autoload
	if backend:
		var auth_wrapper = preload("res://addons/GodotFirebaseAndroid/modules/Auth.gd").new()
		auth_wrapper._plugin_singleton = backend

		# Fallback al plugin nativo (camelCase)
		if backend.has_method("signOut"):
			print("[LoginScreen] calling backend.signOut() and brief wait to show picker")
			backend.signOut()
		elif backend.has_method("sign_out"):
			print("[LoginScreen] calling backend.sign_out() and brief wait to show picker")
			backend.sign_out()
		
		# Intento de forzar salida de Google específicamente
		if backend.has_method("googleSignOut"):
			backend.googleSignOut()
		
		await get_tree().create_timer(0.6).timeout

		if auth_wrapper.has_method("sign_in_with_google"):
			print("[LoginScreen] calling auth_wrapper.sign_in_with_google()")
			auth_wrapper.sign_in_with_google()
			return
		
		if backend.has_method("signInWithGoogle"):
			print("[LoginScreen] calling backend.signInWithGoogle()")
			backend.signInWithGoogle()
			return
		if backend.has_method("sign_in_with_google"):
			print("[LoginScreen] calling backend.sign_in_with_google()")
			backend.sign_in_with_google()
			return
		# Ningún método conocido: listar métodos expuestos para depuración
		var method_names: Array = []
		var mlist = backend.get_method_list()
		for m in mlist:
			if typeof(m) == TYPE_DICTIONARY and m.has("name"):
				method_names.append(m["name"])
			else:
				method_names.append(str(m))
		print("[LoginScreen] Backend methods:", method_names)
		_show_loading(false)
		_clear_auth_timeout()
		_mostrar_error(label_error_login, "Métodos expuestos: " + str(method_names))
		return
	else:
		_show_loading(false)
		_clear_auth_timeout()
		_mostrar_error(label_error_login, "El plugin no contiene el método 'signInWithGoogle'.")

func _on_ingresar_pressed() -> void:
	# Aquí puedes implementar el inicio clásico de sesión por Email/Password si lo requieres
	var email = input_email_login.text.strip_edges()
	var password = input_pass_login.text.strip_edges()
	
	if email.is_empty() or password.is_empty():
		_mostrar_error(label_error_login, "Por favor rellena todos los campos.")
		return
		
	if not _ensure_backend_available("login por Email"): return
	
	_show_loading(true, "Iniciando sesión...")
	_start_auth_timeout("login por Email")
	var backend = _get_firebase_backend()
	if backend and "auth" in backend:
		var fb = backend
		if fb.auth and fb.auth.has_method("sign_in_with_email_password"):
			fb.auth.sign_in_with_email_password(email, password)
		elif fb.auth and fb.auth.has_method("sign_in"):
			fb.auth.sign_in(email, password)
		else:
			_show_loading(false)
			_clear_auth_timeout()
			_mostrar_error(label_error_login, "El autoload 'Firebase' no soporta login por Email.")
	else:
		if backend.has_method("signInWithEmailPassword"):
			backend.signInWithEmailPassword(email, password)
		elif backend.has_method("sign_in_with_email_password"):
			backend.sign_in_with_email_password(email, password)
		else:
			_show_loading(false)
			_clear_auth_timeout()
			_mostrar_error(label_error_login, "El plugin nativo no soporta login por Email.")

func _on_registrar_pressed() -> void:
	if panel_login:
		panel_login.visible = false
	if panel_registro:
		panel_registro.visible = true

func _on_test_guardar_pressed() -> void:
	if not _ensure_backend_available("test de guardado"): return
	_show_firestore_feedback = true

	_show_loading(true, "Verificando sesión en Firestore...")
	var backend = _get_firebase_backend()
	var fb = null
	var datos: Node = get_node_or_null("/root/DatosUsuario")
	var uid: String = ""

	# Verificación de inicio de sesión nativo (soportar autoload `Firebase` o plugin nativo)
	var logged_in = false
	if backend and "auth" in backend:
		fb = backend
		if fb.auth and fb.auth.has_method("is_signed_in"):
			logged_in = fb.auth.is_signed_in()
	elif backend and backend.has_method("isSignedIn"):
		logged_in = backend.isSignedIn()
	elif backend and backend.has_method("is_signed_in"):
		logged_in = backend.is_signed_in()

	if not logged_in:
		# Si no está logueado, forzamos inicio anónimo temporal para el test
		if backend and "auth" in backend:
			if fb and fb.auth and fb.auth.has_method("sign_in_anonymously"):
				_start_auth_timeout("autenticación anónima")
				_update_loading_text("Creando sesión anónima de prueba...")
				fb.auth.sign_in_anonymously()
				return
		else:
			if backend.has_method("signInAnonymously"):
				_start_auth_timeout("autenticación anónima")
				_update_loading_text("Creando sesión anónima de prueba...")
				backend.signInAnonymously()
				return
			elif backend.has_method("sign_in_anonymously"):
				_start_auth_timeout("autenticación anónima")
				_update_loading_text("Creando sesión anónima de prueba...")
				backend.sign_in_anonymously()
				return
		
		_show_loading(false)
		_mostrar_error(label_error_login, "No hay sesión activa y no se soporta login anónimo.")
		return

	# Si ya está logueado, extraemos su UID nativo
	if backend and "auth" in backend:
		if fb and fb.auth and fb.auth.has_method("get_current_user_data"):
			var current_user = fb.auth.get_current_user_data()
			var normalized: Dictionary = _normalize_auth_user(current_user)
			uid = normalized.uid
	elif backend and backend.has_method("getCurrentUser"):
		var current_user = backend.getCurrentUser()
		var normalized: Dictionary = _normalize_auth_user(current_user)
		uid = normalized.uid
	elif backend and backend.has_method("get_current_user_data"):
		var current_user = backend.get_current_user_data()
		var normalized: Dictionary = _normalize_auth_user(current_user)
		uid = normalized.uid
	elif datos and str(datos.firebase_uid).strip_edges() != "":
		uid = str(datos.firebase_uid)

	if uid.is_empty():
		_show_loading(false)
		_mostrar_error(label_error_login, "Imposible recuperar un ID de usuario válido.")
		return

	_do_test_guardar(uid)

func _on_invitado_pressed() -> void:
	# Acceso local como invitado: crear perfil local y entrar al juego
	_show_loading(true, "Entrando como invitado...")
	var datos: Node = get_node_or_null("/root/DatosUsuario")
	var guest_name: String = "Invitado"
	if datos:
		if datos.has_method("generar_nombre_aleatorio"):
			guest_name = datos.generar_nombre_aleatorio()
		else:
			guest_name = "Invitado%d" % randi()
		# Forzar sesión local: sin firebase_uid (offline)
		datos.firebase_uid = ""
		if datos.has_method("set_nombre_usuario"):
			datos.set_nombre_usuario(guest_name, true)
		elif datos.has_method("_crear_nuevo_perfil"):
			datos._crear_nuevo_perfil(guest_name)
		else:
			datos.nombre_usuario = guest_name
			if datos.has_method("save_local"):
				datos.save_local()

	# Entrar al juego usando el flujo normal de LoginScreen
	_entrar_al_juego(guest_name)

func _do_test_guardar(uid: String) -> void:
	_update_loading_text("Subiendo datos de prueba a Firestore...")
	var backend = _get_firebase_backend()
	
	# Construimos el diccionario de datos clásico de logística
	var info_tabla: Dictionary = {
		"test_write": true,
		"timestamp": Time.get_ticks_msec(),
		"motor_status": "ok"
	}
	
	# El nuevo plugin soporta subida directa de colecciones y documentos usando diccionarios estructurados
	# Autoload wrapper (Firestore)
	if backend and "firestore" in backend:
		var fb = backend
		if fb.firestore and fb.firestore.has_method("set_document"):
			fb.firestore.set_document("conductores", uid, info_tabla, true)
			return

	# Plugin nativo (camelCase)
	if backend and backend.has_method("firestoreSetDocument"):
		backend.firestoreSetDocument("conductores", uid, info_tabla, true)
		return
	# Compatibilidad: método snake_case directo
	if backend and backend.has_method("set_document"):
		backend.set_document("conductores", uid, info_tabla, true)
		return

	_show_loading(false)
	_mostrar_error(label_error_login, "El plugin no soporta el método directo 'set_document'.")

func _request_firestore_profile(uid: String) -> bool:
	var backend = _get_firebase_backend()
	if not backend:
		return false
	_pending_firestore_get_kind = "profile"

	if backend and "firestore" in backend:
		var fb = backend
		if fb.firestore and fb.firestore.has_method("get_document"):
			fb.firestore.get_document("conductores", uid)
			return true

	if backend.has_method("firestoreGetDocument"):
		backend.firestoreGetDocument("conductores", uid)
		return true

	if backend.has_method("get_document"):
		backend.get_document("conductores", uid)
		return true

	return false


func _request_public_id_counter() -> bool:
	var backend = _get_firebase_backend()
	if not backend:
		return false
	_pending_firestore_get_kind = "public_id_scan"
	var accounts_collection: String = "conductores"
	if backend and "firestore" in backend:
		var fb = backend
		if fb.firestore and fb.firestore.has_method("get_documents_in_collection"):
			fb.firestore.get_documents_in_collection(accounts_collection)
			return true
	if backend.has_method("firestoreGetDocumentsInCollection"):
		backend.firestoreGetDocumentsInCollection(accounts_collection)
		return true
	if backend.has_method("get_documents_in_collection"):
		backend.get_documents_in_collection(accounts_collection)
		return true
	return false


func _extract_firestore_document_data(result_data) -> Dictionary:
	if typeof(result_data) != TYPE_DICTIONARY:
		return {}
	if result_data.has("data") and typeof(result_data.get("data")) == TYPE_DICTIONARY:
		var data_result: Dictionary = result_data.get("data")
		if data_result.has("fields") and typeof(data_result.get("fields")) == TYPE_DICTIONARY:
			return _decode_firestore_fields(data_result.get("fields"))
		return data_result
	if result_data.has("document") and typeof(result_data.get("document")) == TYPE_DICTIONARY:
		var document_data: Dictionary = result_data.get("document")
		if document_data.has("data") and typeof(document_data.get("data")) == TYPE_DICTIONARY:
			var nested_data: Dictionary = document_data.get("data")
			if nested_data.has("fields") and typeof(nested_data.get("fields")) == TYPE_DICTIONARY:
				return _decode_firestore_fields(nested_data.get("fields"))
			return nested_data
		if document_data.has("fields") and typeof(document_data.get("fields")) == TYPE_DICTIONARY:
			return _decode_firestore_fields(document_data.get("fields"))
		return document_data
	return result_data


func _decode_firestore_fields(fields: Dictionary) -> Dictionary:
	var decoded: Dictionary = {}
	for key in fields.keys():
		decoded[key] = _decode_firestore_value(fields.get(key))
	return decoded


func _decode_firestore_value(raw_value):
	if typeof(raw_value) != TYPE_DICTIONARY:
		return raw_value
	if raw_value.has("integerValue"):
		return int(raw_value.get("integerValue", 0))
	if raw_value.has("doubleValue"):
		return float(raw_value.get("doubleValue", 0.0))
	if raw_value.has("stringValue"):
		return str(raw_value.get("stringValue", ""))
	if raw_value.has("booleanValue"):
		return bool(raw_value.get("booleanValue", false))
	return raw_value


func _extract_firestore_documents(result_data) -> Array:
	var raw_documents: Array = []
	if typeof(result_data) == TYPE_ARRAY:
		raw_documents = result_data
	elif typeof(result_data) == TYPE_DICTIONARY:
		if result_data.has("documents") and typeof(result_data.get("documents")) == TYPE_ARRAY:
			raw_documents = result_data.get("documents")
		elif result_data.has("data"):
			var data_block = result_data.get("data")
			if typeof(data_block) == TYPE_ARRAY:
				raw_documents = data_block
			elif typeof(data_block) == TYPE_DICTIONARY:
				if data_block.has("documents") and typeof(data_block.get("documents")) == TYPE_ARRAY:
					raw_documents = data_block.get("documents")
				elif data_block.has("values") and typeof(data_block.get("values")) == TYPE_ARRAY:
					raw_documents = data_block.get("values")
		elif result_data.has("result") and typeof(result_data.get("result")) == TYPE_ARRAY:
			raw_documents = result_data.get("result")
		elif result_data.has("items") and typeof(result_data.get("items")) == TYPE_ARRAY:
			raw_documents = result_data.get("items")

	var decoded_documents: Array = []
	for raw_document in raw_documents:
		if typeof(raw_document) == TYPE_DICTIONARY:
			var document_data: Dictionary = _extract_firestore_document_data(raw_document)
			if not document_data.is_empty():
				decoded_documents.append(document_data)
	return decoded_documents


func _extract_public_id_number(candidate_value) -> int:
	var candidate: String = str(candidate_value).strip_edges()
	if not candidate.begins_with("NT"):
		return 0
	var suffix: String = candidate.substr(2)
	if suffix == "":
		return 0
	for character in suffix:
		if character < "0" or character > "9":
			return 0
	return int(suffix)


func _resolve_next_public_id_number(result_data) -> int:
	var documents: Array = _extract_firestore_documents(result_data)
	var max_number: int = 0
	for document in documents:
		if typeof(document) != TYPE_DICTIONARY:
			continue
		var document_data: Dictionary = document
		var public_id_number: int = int(document_data.get("public_id_number", 0))
		if public_id_number <= 0:
			public_id_number = _extract_public_id_number(document_data.get("public_id", document_data.get("id_usuario", "")))
		if public_id_number > max_number:
			max_number = public_id_number
	return max_number + 1

# --- CALLBACKS DEL PLUGIN NATIVO (RESPUESTAS) ---

func _on_auth_success(user_data) -> void:
	_clear_auth_timeout()
	_show_loading(false)
	print("[LoginScreen] _on_auth_success raw:", user_data)
	var normalized_user: Dictionary = _normalize_auth_user(user_data)
	print("[LoginScreen] _on_auth_success normalized:", normalized_user)
	if str(normalized_user.get("uid", "")).strip_edges() == "":
		# No se obtuvo UID válido: evitar entrar automáticamente
		_mostrar_error(label_error_login, "No se seleccionó una cuenta válida. Intenta de nuevo.")
		return

	id_temp = str(normalized_user.get("uid", ""))
	
	# Usar el nombre de Google si está disponible, de lo contrario el nickname del correo.
	var final_name: String = str(normalized_user.get("name", "Conductor"))
	# Si el nombre detectado es genérico o sigue siendo "Conductor", intentamos forzar la obtención desde user_data
	if final_name == "" or final_name == "Conductor":
		if typeof(user_data) == TYPE_DICTIONARY:
			# Intentar llaves alternativas de Google Play Services
			final_name = str(user_data.get("displayName", user_data.get("name", "")))
		
		# Si después de intentar extraerlo sigue vacío, usamos el email
		if final_name == "" or final_name == "Conductor":
			var normalized_email: String = str(normalized_user.get("email", ""))
			if normalized_email != "":
				var email_parts: Array = normalized_email.split("@")
				if email_parts.size() > 0:
					final_name = email_parts[0]
	
	print("[LoginScreen] Nombre final asignado (identidad Google):", final_name)

	var datos: Node = get_node_or_null("/root/DatosUsuario")
	if datos and datos.has_method("apply_authenticated_profile"):
		var applied_profile: Dictionary = datos.apply_authenticated_profile(user_data, final_name, false)
		id_temp = str(applied_profile.get("uid", id_temp))
		final_name = str(applied_profile.get("name", final_name))
		print("[LoginScreen] Perfil sincronizado en DatosUsuario:", applied_profile)
	elif datos:
		datos.firebase_uid = id_temp
		datos.nombre_usuario = final_name
		if datos.has_method("save_local"): 
			datos.save_local()
			print("[LoginScreen] Datos guardados localmente para:", final_name)

	_pending_profile_fetch_uid = id_temp
	_pending_profile_name = final_name
	if _request_firestore_profile(id_temp):
		_show_loading(true, "Cargando progreso de tu cuenta...")
		return

	print("[LoginScreen] Firestore get_document no disponible; entrando con perfil base autenticado.")
	_pending_profile_fetch_uid = ""
	_pending_profile_name = ""
	_entrar_al_juego(final_name)

func _on_auth_failed(error_msg: String) -> void:
	_clear_auth_timeout()
	_show_loading(false)
	_mostrar_error(label_error_login, "Error de Firebase: " + error_msg)

func _on_test_document_written(_result_data) -> void:
	if _show_firestore_feedback:
		_show_firestore_feedback = false
		_show_loading(false)
		_mostrar_error(label_error_login, "¡ÉXITO! Datos sincronizados en la nube.")
	else:
		print("[LoginScreen] Firestore write_task_completed")

func _on_test_document_failed(error_msg) -> void:
	_show_firestore_feedback = false
	_show_loading(false)
	_mostrar_error(label_error_login, "Fallo al escribir en Firestore: " + str(error_msg))

func _on_firestore_document_loaded(result_data) -> void:
	if _pending_profile_fetch_uid == "":
		return

	print("[LoginScreen] Firestore get_task_completed:", result_data)
	var final_name: String = _pending_profile_name
	var datos: Node = get_node_or_null("/root/DatosUsuario")
	if _pending_firestore_get_kind == "public_id_scan":
		if datos and datos.has_method("set_public_id_number"):
			var next_number: int = _resolve_next_public_id_number(result_data)
			var assigned_id: String = str(datos.set_public_id_number(next_number, true, true))
			print("[LoginScreen] ID publico asignado:", assigned_id)
			final_name = datos.nombre_usuario
	else:
		if datos and datos.has_method("apply_firestore_profile"):
			var profile_result: Dictionary = datos.apply_firestore_profile(result_data, final_name)
			final_name = str(profile_result.get("name", final_name))
			print("[LoginScreen] Perfil remoto aplicado:", profile_result)
			if bool(profile_result.get("needs_public_id_assignment", false)):
				if _request_public_id_counter():
					_show_loading(true, "Asignando ID publico...")
					return

	_pending_profile_fetch_uid = ""
	_pending_profile_name = ""
	_pending_firestore_get_kind = ""
	_entrar_al_juego(final_name)

# --- FLUJO FINAL DEL JUEGO ---

func _on_confirmar_nombre_pressed() -> void:
	var nombre_elegido = input_nombre_final.text.strip_edges()
	if nombre_elegido.length() < 3:
		_mostrar_error(label_error_nombre, "Nombre demasiado corto (mínimo 3).")
		return
		
	_show_loading(true, "Sincronizando perfil...")
	var datos: Node = get_node_or_null("/root/DatosUsuario")
	if datos:
		if datos.has_method("set_nombre_usuario"):
			datos.set_nombre_usuario(nombre_elegido, true)
		else:
			datos.firebase_uid = id_temp
			datos.nombre_usuario = nombre_elegido
			if datos.has_method("save_local"): datos.save_local()

	_entrar_al_juego(nombre_elegido)

func _entrar_al_juego(nombre_pj: String) -> void:
	# Detener la música de login antes de cambiar de escena
	_stop_login_music()
	_show_loading(true, "Entrando a Nuestra Tierra...")
	print("[LoginScreen] _entrar_al_juego called with:", nombre_pj, " id_temp:", id_temp)
	var discord = get_node_or_null("/root/DiscordBot")
	if discord: discord.enviar_anuncio_pro(nombre_pj)

	var world_path = "res://escenas/gui/escena_carga.tscn"
	var datos: Node = get_node_or_null("/root/DatosUsuario")
	if datos:
		# Forzamos que la siguiente escena sea Main-Menu.tscn
		datos.next_scene = "res://escenas/main menu/Main-Menu.tscn"
		print("[LoginScreen] DatosUsuario.next_scene (destinatario final) set to:", datos.next_scene)

	print("[LoginScreen] world_path:", world_path, " exists:", ResourceLoader.exists(world_path))
	if ResourceLoader.exists(world_path):
		# Intentamos cambiar de escena inmediatamente y registramos el código de error
		var err = get_tree().change_scene_to_file(world_path)
		print("[LoginScreen] change_scene_to_file returned:", err)
		if err != OK:
			# Fallback: intentar con call_deferred
			get_tree().call_deferred("change_scene_to_file", world_path)
			# Si aun así falla, intentar ir directo al Perfil_Menu como último recurso
			var menu_path = "res://escenas/Perfil_Menu/Perfil_Menu.tscn"
			print("[LoginScreen] intentando fallback a Main-Menu:", menu_path, "exists:", ResourceLoader.exists(menu_path))
			if ResourceLoader.exists(menu_path):
				var err2 = get_tree().change_scene_to_file(menu_path)
				print("[LoginScreen] fallback change_scene_to_file returned:", err2)
				if err2 != OK:
					get_tree().call_deferred("change_scene_to_file", menu_path)
		return
	else:
		_show_loading(false)
		_mostrar_error(label_error_nombre, "Error: Escena de carga inaccesible.")

# --- UTILIDADES DE INTERFAZ Y DISEÑO ---

func _reset_ui() -> void:
	_clear_auth_timeout()
	if panel_login:
		panel_login.visible = true
	if panel_registro:
		panel_registro.visible = false
	if panel_nombre_usuario:
		panel_nombre_usuario.visible = false
	if loading_overlay:
		loading_overlay.visible = false

func _conectar_red_social(node_path: String, url: String) -> void:
	var node = get_node_or_null(node_path)
	if node:
		if not node.pressed.is_connected(OS.shell_open):
			node.pressed.connect(OS.shell_open.bind(url))
	elif DEBUG:
		print("LoginScreen: Nodo de red social no encontrado: ", node_path)

func _show_loading(should_show: bool, text: String = "Cargando...") -> void:
	if loading_overlay:
		loading_overlay.visible = should_show
	_update_loading_text(text)

func _update_loading_text(text: String) -> void:
	if not loading_overlay:
		return
	var label = loading_overlay.find_child("Label", true, false)
	if label:
		if FONT:
			label.add_theme_font_override("font", FONT)
			label.add_theme_font_size_override("font_size", 30)
		label.text = text

func _mostrar_error(label: Label, msg: String) -> void:
	if label:
		label.text = msg
		label.modulate = Color.RED
		await get_tree().create_timer(4.0).timeout
		if label.text == msg: label.text = ""

func _aplicar_diseno_visual() -> void:
	var style_panel = StyleBoxFlat.new()
	style_panel.bg_color = Color("#0f111aaa") 
	style_panel.border_width_left = 2
	style_panel.border_width_top = 2
	style_panel.border_width_right = 2
	style_panel.border_width_bottom = 2
	style_panel.border_color = Color("#00ffff") 
	style_panel.set_corner_radius_all(15)
	
	for p in [panel_login, panel_registro, panel_nombre_usuario]:
		if p: p.add_theme_stylebox_override("panel", style_panel)
	
	var style_input = StyleBoxFlat.new()
	style_input.bg_color = Color("#00000044")
	style_input.border_width_bottom = 2
	style_input.border_color = Color("#00ffff44")
	style_input.set_corner_radius_all(8)
	
	for input in [input_email_login, input_pass_login, input_nombre_final]:
		if input:
			input.add_theme_stylebox_override("normal", style_input)
			input.add_theme_stylebox_override("focus", style_input)

	# Aplicar fuente consistente (Moderniz) a paneles, inputs, botones y labels de error
	for p in [panel_login, panel_registro, panel_nombre_usuario]:
		if p:
			p.add_theme_font_override("font", FONT)
			p.add_theme_font_size_override("font_size", 18)

	for input in [input_email_login, input_pass_login, input_nombre_final]:
		if input:
			input.add_theme_font_override("font", FONT)
			input.add_theme_font_size_override("font_size", 36)

	var btn_names: Array = ["%BtnIngresar", "%BtnGoogle", "%BtnInvitado", "%BtnTestGuardar", "%BtnCerrar", "%BtnRegistrar", "%BtnVolverLogin", "%BtnConfirmar"]
	for name in btn_names:
		if has_node(name):
			var b = get_node(name)
			b.add_theme_font_override("font", FONT)
			b.add_theme_font_size_override("font_size", 36)

	for lbl in [label_error_login, label_error_reg, label_error_nombre]:
		if lbl:
			lbl.add_theme_font_override("font", FONT)
			lbl.add_theme_font_size_override("font_size", 28)

	# Efecto hover sencillo para el botón invitado
	if has_node("%BtnInvitado"):
		%BtnInvitado.mouse_entered.connect(func(): %BtnInvitado.rect_scale = Vector2(1.04, 1.04))
		%BtnInvitado.mouse_exited.connect(func(): %BtnInvitado.rect_scale = Vector2(1, 1))


func _start_login_music() -> void:
	# Crea un AudioStreamPlayer y reproduce la canción si está disponible
	if _audio_player and _login_music_playing:
		return
	if not ResourceLoader.exists(LOGIN_MUSIC_PATH):
		if DEBUG: print("LoginScreen: música no encontrada:", LOGIN_MUSIC_PATH)
		return
	var stream = load(LOGIN_MUSIC_PATH)
	if not stream:
		if DEBUG: print("LoginScreen: fallo al cargar música:", LOGIN_MUSIC_PATH)
		return

	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = stream
	# Reducir volumen por defecto para que no sea intrusiva
	_audio_player.volume_db = -6
	_audio_player.autoplay = false
	add_child(_audio_player)
	_audio_player.play()
	_login_music_playing = true


func _stop_login_music() -> void:
	if _audio_player:
		if _audio_player.playing:
			_audio_player.stop()
		_audio_player.queue_free()
		_audio_player = null
		_login_music_playing = false
