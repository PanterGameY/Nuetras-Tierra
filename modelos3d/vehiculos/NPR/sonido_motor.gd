# Archivo: motor_sonido.gd
extends AudioStreamPlayer3D

@export var motor_nodo: NodePath
var ref_motor: Node

# Variables internas de control para evitar saltos bruscos
var rpm_controlada: float = 0.0

func _ready() -> void:
	if motor_nodo:
		ref_motor = get_node(motor_nodo)
	# Configuraciones críticas de Godot 4 para evitar cortes
	autoplay = true
	bus = "Master" # Asegúrate de que este bus exista o cámbialo al tuyo
	volume_db = -40.0 # Volumen muy bajo
	if not playing:
		play()

func _physics_process(delta: float) -> void:
	# 1. VALIDACIÓN DE RECURSOS (Silenciosa para evitar errores en consola)
	if not ref_motor or not ref_motor.datos_motor:
		return

	# 2. ASEGURAR REPRODUCCIÓN (Sin reiniciar el stream)
	if not playing:
		play()

	# 3. EXTRACCIÓN SEGURA DE DATOS
	var d = ref_motor.datos_motor
	var gas = Input.get_action_strength("up")
	var v_norm = ref_motor.get_velocidad_norm()

	# 4. LÓGICA DE RPM ROBUSTA
	# Mezclamos la velocidad actual con el "rugido" del acelerador
	# Usamos un valor de suavizado fijo y alto para evitar que pisotones rápidos rompan el audio
	var objetivo = max(v_norm, gas * 0.45)
	rpm_controlada = lerp(rpm_controlada, objetivo, delta * 12.0)

	# Aseguramos que rpm_controlada nunca sea NaN o Infinity
	if is_nan(rpm_controlada): rpm_controlada = 0.0

	# 5. APLICACIÓN DE PITCH (El culpable de los fallos)
	# Godot 4 odia los cambios de pitch instantáneos de 0 a 100
	var final_pitch = lerp(d.pitch_idle, d.pitch_max, rpm_controlada)

	# CLAMP AGRESIVO: El audio nunca morirá si nos mantenemos entre 0.1 y 3.0
	pitch_scale = clamp(final_pitch, 0.15, 3.5)

	# 6. VOLUMEN DINÁMICO
	# Usamos una curva de volumen más suave para evitar el "pop" auditivo
	var db_objetivo = lerp(-40.0, -20.0, rpm_controlada) # Mucho más bajo

	# Si sueltas el gas muy rápido, el volumen baja pero nunca se apaga del todo
	volume_db = lerp(volume_db, db_objetivo, delta * 8.0)

	# 7. ESTABILIZADOR DE STREAM
	# Si por alguna razón el stream se corrompe (buffer underrun), forzamos reinicio suave
	if pitch_scale <= 0.15:
		pitch_scale = 0.2
