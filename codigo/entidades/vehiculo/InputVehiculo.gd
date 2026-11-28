# input_vehiculo.gd - Sistema Central de Conducción Profesional
# Maneja: Aceleración, Frenado, Dirección, Freno de Mano, Marchas, Splitter y Range
extends Node

# ════════════════════════════════════════════════════════════════════════════
# VARIABLES DE ESTADO (LECTURA PÚBLICA)
# ════════════════════════════════════════════════════════════════════════════
var conduciendo: bool = false
var motor_encendido: bool = false
var combustible: float = 100.0 : set = _set_combustible

# Valores procesados para los componentes
var gas: float = 0.0
var freno: float = 0.0
var direccion: float = 0.0
var freno_mano: bool = false
var freno_motor: bool = false
var plumillas: bool = false
var embrague: float = 0.0 # Simulación de acople de torque

# Transmisión
enum Marcha { PARQUEO, REVERSA, NEUTRO, DRIVE }
var marcha_actual: Marcha = Marcha.NEUTRO
var marcha: String = "N"
const MARCHAS_DISPLAY := ["P", "R", "N", "D"]

# Multiplicadores para Camiones Pesados
var multiplicador_rango: bool = false
var multiplicador_splitter: bool = false

# ════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN DE SIMULACIÓN
# ════════════════════════════════════════════════════════════════════════════
@export_group("Sensibilidad Mecánica")
@export var suavizado_direccion: float = 10.0
@export var suavizado_pedales: float = 3.5
@export var suavizado_teclado: float = 1.2
@export var retorno_volante: float = 3.5

@export_group("Seguridad")
@export var velocidad_segura_cambio: float = 8.0 # km/h para pasar de D a R

@export_group("Transmisión")
@export var habilitar_marcha_input: bool = false

# ════════════════════════════════════════════════════════════════════════════
# VARIABLES INTERNAS DE PROCESAMIENTO
# ════════════════════════════════════════════════════════════════════════════
var _gas_target: float = 0.0
var _freno_target: float = 0.0
var _dir_target: float = 0.0
var _gas_teclado: float = 0.0
var velocidad_actual_kmh: float = 0.0 # Sincronizado desde el RigidBody
var modo_tactil_activo: bool = false

# ════════════════════════════════════════════════════════════════════════════
# CICLO DE PROCESAMIENTO
# ════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if not conduciendo:
		_reset_inputs_instant()
		return
	
	# Entrada de teclado (PC)
	_procesar_entradas_raw()
	# Cálculo de suavizado y física
	_aplicar_suavizado(delta)

func _procesar_entradas_raw() -> void:
	# Encendido manual
	if Input.is_action_just_pressed("encender_motor"):
		if marcha_actual <= Marcha.NEUTRO:
			motor_encendido = !motor_encendido
	
	# Dirección
	var dir_keyboard = Input.get_axis("izquierda", "derecha")
	if abs(dir_keyboard) > 0.02:
		modo_tactil_activo = false
		_dir_target = dir_keyboard
	
	# Pedales (PC)
	var tecla_gas = Input.get_action_strength("acelerar")
	_gas_teclado = lerp(_gas_teclado, tecla_gas, suavizado_teclado * get_process_delta_time())
	_gas_target = max(_gas_target, _gas_teclado)
	_freno_target = max(_freno_target, Input.get_action_strength("frenar"))
	
	# Freno de mano (Toggle por teclado con tecla B sin sobrescribir el estado del botón táctil)
	if Input.is_action_just_pressed("freno_mano"):
		freno_mano = not freno_mano
	# Cambios de marcha rápidos (PC)
	# Soportar nombres antiguos y nuevos de acción por compatibilidad
	if habilitar_marcha_input:
		if Input.is_action_just_pressed("subir_marcha") or Input.is_action_just_pressed("marcha_arriba"):
			cambiar_marcha_relativa(1)
		if Input.is_action_just_pressed("bajar_marcha") or Input.is_action_just_pressed("marcha_abajo"):
			cambiar_marcha_relativa(-1)

func _aplicar_suavizado(delta: float) -> void:
	# 1. Dirección con inercia
	direccion = lerp(direccion, _dir_target, suavizado_direccion * delta)
	if not modo_tactil_activo:
		_dir_target = move_toward(_dir_target, 0.0, retorno_volante * delta)
	
	# 2. Pedales (Si no hay motor o gasolina, el gas muere)
	var limite_gas = _gas_target if motor_encendido and combustible > 0 else 0.0
	gas = limite_gas
	freno = _freno_target
	
	# 3. Decaimiento natural de objetivos (para soltar teclas)
	_gas_target = move_toward(_gas_target, 0.0, delta * 2.0)
	_freno_target = move_toward(_freno_target, 0.0, delta * 2.0)
	
	# 4. Embrague automático: Simula la entrega de potencia progresiva
	if gas > 0.1 and puede_moverse():
		embrague = lerp(embrague, 1.0, 4.0 * delta)
	else:
		embrague = lerp(embrague, 0.0, 6.0 * delta)

# ════════════════════════════════════════════════════════════════════════════
# API PÚBLICA - MÓVIL Y BOTONES
# ════════════════════════════════════════════════════════════════════════════

func set_dir(v: float) -> void: _dir_target = clamp(v, -1.0, 1.0)
func set_direccion(v: float) -> void: _dir_target = clamp(v, -1.0, 1.0)

func set_direccion_tactil(v: float) -> void:
	modo_tactil_activo = true
	_dir_target = clamp(v, -1.0, 1.0)
	direccion = _dir_target

func set_gas(v: float) -> void:
	_gas_target = clamp(v, 0.0, 1.0)

func set_freno(v: float) -> void:
	_freno_target = clamp(v, 0.0, 1.0)

func set_fmano(estado: bool) -> void:
	freno_mano = estado

func centrar_direccion() -> void:
	# Forzar centrado inmediato del volante desde UI
	modo_tactil_activo = false
	_dir_target = 0.0
	direccion = 0.0

func liberar_direccion_tactil() -> void:
	# Llamado por controles táctiles al soltar el toque.
	modo_tactil_activo = false
	_dir_target = direccion

func set_marcha_enum(nueva: Marcha) -> void:
	# Verificación de seguridad antes de aplicar
	if (marcha_actual == Marcha.DRIVE and nueva == Marcha.REVERSA) or (marcha_actual == Marcha.REVERSA and nueva == Marcha.DRIVE):
		if velocidad_actual_kmh > velocidad_segura_cambio:
			return # Bloqueado por velocidad
	
	if nueva != marcha_actual:
		_gas_target = 0.0
		_gas_teclado = 0.0
		gas = 0.0
	marcha_actual = nueva
	marcha = MARCHAS_DISPLAY[nueva]

func cambiar_marcha_relativa(dir: int) -> void:
	var nueva_idx = clamp(marcha_actual + dir, 0, Marcha.DRIVE)
	set_marcha_enum(nueva_idx as Marcha)

# ════════════════════════════════════════════════════════════════════════════
# HELPERS DE LÓGICA
# ════════════════════════════════════════════════════════════════════════════
func puede_moverse() -> bool:
	return motor_encendido and (marcha_actual == Marcha.DRIVE or marcha_actual == Marcha.REVERSA)

func esta_en_reversa() -> bool: return marcha_actual == Marcha.REVERSA

func _set_combustible(val: float) -> void:
	combustible = clamp(val, 0.0, 100.0)
	if combustible <= 0: motor_encendido = false

func _reset_inputs_instant() -> void:
	gas = 0.0; freno = 0.0; direccion = 0.0
	_gas_target = 0.0; _freno_target = 0.0; _dir_target = 0.0
	modo_tactil_activo = false
	freno_mano = true
	freno_motor = false

func start_driving() -> void:
	conduciendo = true
	# Entrar en neutro; el jugador arranca el motor con BtnCorriente
	set_marcha_enum(Marcha.NEUTRO)
	motor_encendido = false
	freno_mano = true

func stop_driving() -> void:
	conduciendo = false
	motor_encendido = false
	_reset_inputs_instant()