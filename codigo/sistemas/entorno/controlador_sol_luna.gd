# ═══════════════════════════════════════════════════════════════════════════════
# controlador_sol_luna.gd
# Controlador Dinámico de Iluminación Solar y Lunar (Ciclo Día / Noche)
# Proyecto: Nuestra Tierra 2.0
# ═══════════════════════════════════════════════════════════════════════════════
@tool
class_name ControladorSolLuna
extends Node3D

@export_group("⏰ Control Horario")
## Hora actual en formato decimal (ej: 12.0 = mediodía, 6.5 = 6:30 AM).
@export_range(0.0, 24.0, 0.1) var hora_actual: float = 12.0:
	set(valor):
		hora_actual = valor
		_actualizar_luces()

## Si está activo, el ciclo horario avanza automáticamente.
@export var activo: bool = false
## Duración en segundos de un ciclo de 24 horas completas.
@export_range(10.0, 3600.0, 10.0) var duracion_dia_segundos: float = 1200.0

@export_group("☀️ Configuración Solar")
@export var luz_sol: DirectionalLight3D
@export var gradiente_color_sol: Gradient
@export var curva_energia_sol: Curve
@export_range(0.0, 360.0, 1.0) var azimut_sol: float = 45.0
@export_range(0.0, 5.0, 0.1) var energia_maxima_sol: float = 1.35

@export_group("🌙 Configuración Lunar")
@export var luz_luna: DirectionalLight3D
@export var color_luz_luna: Color = Color(0.65, 0.78, 1.0, 1.0)
@export_range(0.0, 2.0, 0.05) var energia_maxima_luna: float = 0.35

@export_group("🌍 Entorno")
@export var world_environment: WorldEnvironment


func _ready() -> void:
	_buscar_nodos_si_es_necesario()
	_actualizar_luces()


func _process(delta: float) -> void:
	if activo and not Engine.is_editor_hint():
		var incremento: float = (delta / duracion_dia_segundos) * 24.0
		hora_actual = fmod(hora_actual + incremento, 24.0)


func _buscar_nodos_si_es_necesario() -> void:
	if not luz_sol:
		luz_sol = get_node_or_null("SunLight") as DirectionalLight3D
	if not luz_luna:
		luz_luna = get_node_or_null("MoonLight") as DirectionalLight3D
	if not world_environment:
		world_environment = get_node_or_null("../WorldEnvironment") as WorldEnvironment


func _actualizar_luces() -> void:
	# Progreso de 0.0 a 1.0 (0.0 = 00:00, 0.5 = 12:00)
	var t: float = hora_actual / 24.0
	
	# Ángulo de elevación del Sol (-PI/2 a 3PI/2)
	# 6:00 (t=0.25) -> 0 rad (amanecer)
	# 12:00 (t=0.50) -> PI/2 rad (cenit)
	# 18:00 (t=0.75) -> PI rad (atardecer)
	var angulo_elevacion: float = (t * TAU) - (PI * 0.5)
	var altura_sol: float = sin(angulo_elevacion)
	
	# Orientación Solar
	var azimut_rad: float = deg_to_rad(azimut_sol)
	var dir_sol_x: float = cos(angulo_elevacion) * cos(azimut_rad)
	var dir_sol_y: float = -altura_sol
	var dir_sol_z: float = cos(angulo_elevacion) * sin(azimut_rad)
	var direccion_sol: Vector3 = Vector3(dir_sol_x, dir_sol_y, dir_sol_z).normalized()
	
	# Actualizar Sol
	if is_instance_valid(luz_sol):
		var up_safe = Vector3.UP if abs(direccion_sol.dot(Vector3.UP)) < 0.99 else Vector3.BACK
		luz_sol.look_at_from_position(Vector3.ZERO, direccion_sol, up_safe)
		
		# Color y energía
		if altura_sol > 0.0:
			if gradiente_color_sol:
				luz_sol.light_color = gradiente_color_sol.sample(t)
			else:
				luz_sol.light_color = Color(1.0, 0.96, 0.9, 1.0)
				
			if curva_energia_sol:
				luz_sol.light_energy = curva_energia_sol.sample(t) * energia_maxima_sol
			else:
				luz_sol.light_energy = maxf(0.0, altura_sol) * energia_maxima_sol
		else:
			luz_sol.light_energy = 0.0
	
	# Actualizar Luna (posición opuesta)
	if is_instance_valid(luz_luna):
		var direccion_luna: Vector3 = -direccion_sol
		var up_safe_luna = Vector3.UP if abs(direccion_luna.dot(Vector3.UP)) < 0.99 else Vector3.BACK
		luz_luna.look_at_from_position(Vector3.ZERO, direccion_luna, up_safe_luna)
		
		if altura_sol <= 0.0:
			var altura_luna: float = -altura_sol
			luz_luna.light_color = color_luz_luna
			luz_luna.light_energy = clampf(altura_luna * 1.5, 0.0, 1.0) * energia_maxima_luna
		else:
			luz_luna.light_energy = 0.0
