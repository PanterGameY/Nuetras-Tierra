extends Node

## Gestor central de anuncios AdMob (Poing Studios 5.x).
## Usa los IDs oficiales de PRUEBA de Google. En PC/editor no existe el SDK
## nativo, asi que el flujo se simula para poder validar la interfaz.

signal inicializacion_terminada(ok: bool)
signal banner_cargado
signal banner_cerrado
signal intersticial_cargado
signal intersticial_cerrado
signal recompensado_cargado
signal recompensa_obtenida(cantidad: int, tipo: String)
signal anuncio_fallido(formato: String, mensaje: String)
signal simulacion_ejecutada(formato: String)

const MODO_PRUEBA := true
const RECOMPENSA_SIMULADA := 25

# IDs oficiales de prueba de Google. No cobran y no requieren cuenta.
const BANNER_ANDROID := "ca-app-pub-3940256099942544/6300978111"
const BANNER_IOS := "ca-app-pub-3940256099942544/2934735716"
const INTERSTICIAL_ANDROID := "ca-app-pub-3940256099942544/1033173712"
const INTERSTICIAL_IOS := "ca-app-pub-3940256099942544/4411468910"
const RECOMPENSADO_ANDROID := "ca-app-pub-3940256099942544/5224354917"
const RECOMPENSADO_IOS := "ca-app-pub-3940256099942544/1712485313"

var modo_simulado := true
var inicializado := false
var banner_visible := false

var _banner = null
var _intersticial = null
var _recompensado = null
var _cargando_intersticial := false
var _cargando_recompensado := false
var _mostrar_intersticial_pendiente := false
var _mostrar_recompensado_pendiente := false
var _reward_listener = null


func _ready() -> void:
	var es_movil := OS.get_name() == "Android" or OS.get_name() == "iOS"
	modo_simulado = not es_movil or not Engine.has_singleton("PoingGodotAdMob")
	if modo_simulado:
		inicializado = true
		inicializacion_terminada.emit(true)
	else:
		_inicializar_mobile_ads()


func _inicializar_mobile_ads() -> void:
	if inicializado:
		return
	var listener = OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _al_terminar_inicializacion
	MobileAds.initialize(listener)


func _al_terminar_inicializacion(_estado) -> void:
	inicializado = true
	inicializacion_terminada.emit(true)


func plataforma() -> String:
	return OS.get_name()


func modo_texto() -> String:
	if modo_simulado:
		return "SIMULACION PC (sin SDK nativo)"
	return "NATIVO ANDROID/IOS CON IDS DE PRUEBA"


# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

func mostrar_banner() -> void:
	if modo_simulado:
		banner_visible = true
		_simular("BANNER")
		return
	if _banner == null:
		_crear_banner()
	if _banner == null:
		return
	banner_visible = true
	_banner.load_ad(AdRequest.new())
	_banner.show()


func ocultar_banner() -> void:
	banner_visible = false
	if modo_simulado:
		banner_cerrado.emit()
		return
	if _banner:
		_banner.hide()


func destruir_banner() -> void:
	banner_visible = false
	if modo_simulado:
		banner_cerrado.emit()
		return
	if _banner:
		_banner.destroy()
		_banner = null


func _crear_banner() -> void:
	var listener = AdListener.new()
	listener.on_ad_loaded = func() -> void:
		banner_cargado.emit()
	listener.on_ad_failed_to_load = func(error) -> void:
		anuncio_fallido.emit("BANNER", str(error.message))
	listener.on_ad_closed = func() -> void:
		banner_cerrado.emit()
	var tamano = AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(_id_banner(), tamano, AdPosition.BOTTOM)
	_banner.ad_listener = listener


# ---------------------------------------------------------------------------
# Intersticial
# ---------------------------------------------------------------------------

func cargar_intersticial() -> void:
	if modo_simulado:
		_simular("INTERSTICIAL")
		return
	if _cargando_intersticial:
		return
	_cargando_intersticial = true
	var callback = InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = _al_cargar_intersticial
	callback.on_ad_failed_to_load = func(error) -> void:
		_cargando_intersticial = false
		anuncio_fallido.emit("INTERSTICIAL", str(error.message))
	InterstitialAdLoader.new().load(_id_intersticial(), AdRequest.new(), callback)


func mostrar_intersticial() -> void:
	if modo_simulado:
		_simular("INTERSTICIAL")
		return
	if _intersticial:
		_intersticial.show()
		return
	_mostrar_intersticial_pendiente = true
	cargar_intersticial()


func _al_cargar_intersticial(ad) -> void:
	_cargando_intersticial = false
	_intersticial = ad
	var contenido = FullScreenContentCallback.new()
	contenido.on_ad_dismissed_full_screen_content = func() -> void:
		intersticial_cerrado.emit()
	contenido.on_ad_failed_to_show_full_screen_content = func(error) -> void:
		anuncio_fallido.emit("INTERSTICIAL", str(error.message))
	ad.full_screen_content_callback = contenido
	intersticial_cargado.emit()
	if _mostrar_intersticial_pendiente:
		_mostrar_intersticial_pendiente = false
		_intersticial.show()


# ---------------------------------------------------------------------------
# Recompensado
# ---------------------------------------------------------------------------

func cargar_recompensado() -> void:
	if modo_simulado:
		_simular("RECOMPENSADO")
		return
	if _cargando_recompensado:
		return
	_cargando_recompensado = true
	var callback = RewardedAdLoadCallback.new()
	callback.on_ad_loaded = _al_cargar_recompensado
	callback.on_ad_failed_to_load = func(error) -> void:
		_cargando_recompensado = false
		anuncio_fallido.emit("RECOMPENSADO", str(error.message))
	RewardedAdLoader.new().load(_id_recompensado(), AdRequest.new(), callback)


func mostrar_recompensado() -> void:
	if modo_simulado:
		_simular("RECOMPENSADO")
		return
	if _recompensado:
		_mostrar_recompensado()
		return
	_mostrar_recompensado_pendiente = true
	cargar_recompensado()


func _al_cargar_recompensado(ad) -> void:
	_cargando_recompensado = false
	_recompensado = ad
	var contenido = FullScreenContentCallback.new()
	contenido.on_ad_dismissed_full_screen_content = func() -> void:
		intersticial_cerrado.emit()
	contenido.on_ad_failed_to_show_full_screen_content = func(error) -> void:
		anuncio_fallido.emit("RECOMPENSADO", str(error.message))
	ad.full_screen_content_callback = contenido
	recompensado_cargado.emit()
	if _mostrar_recompensado_pendiente:
		_mostrar_recompensado_pendiente = false
		_mostrar_recompensado()


func _mostrar_recompensado() -> void:
	if _reward_listener == null:
		_reward_listener = OnUserEarnedRewardListener.new()
		_reward_listener.on_user_earned_reward = func(item) -> void:
			recompensa_obtenida.emit(int(item.amount), str(item.type))
	_recompensado.show(_reward_listener)


# ---------------------------------------------------------------------------
# Simulacion para PC / editor
# ---------------------------------------------------------------------------

func _simular(formato: String) -> void:
	simulacion_ejecutada.emit(formato)
	await get_tree().create_timer(0.45).timeout
	if formato == "BANNER":
		banner_cargado.emit()
	elif formato == "INTERSTICIAL":
		intersticial_cargado.emit()
		await get_tree().create_timer(0.65).timeout
		intersticial_cerrado.emit()
	elif formato == "RECOMPENSADO":
		recompensado_cargado.emit()
		await get_tree().create_timer(0.65).timeout
		recompensa_obtenida.emit(RECOMPENSA_SIMULADA, "esmeraldas")
		intersticial_cerrado.emit()


# ---------------------------------------------------------------------------
# IDs de prueba
# ---------------------------------------------------------------------------

func _id_banner() -> String:
	if OS.get_name() == "iOS":
		return BANNER_IOS
	return BANNER_ANDROID


func _id_intersticial() -> String:
	if OS.get_name() == "iOS":
		return INTERSTICIAL_IOS
	return INTERSTICIAL_ANDROID


func _id_recompensado() -> String:
	if OS.get_name() == "iOS":
		return RECOMPENSADO_IOS
	return RECOMPENSADO_ANDROID
