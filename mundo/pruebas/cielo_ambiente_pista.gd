# ═══════════════════════════════════════════════════════════════════════════════
# cielo_ambiente_pista.gd
# Controlador de WorldEnvironment e Iluminación Hiperrealista Móvil
# Pista de Pruebas de Vehículos Pesados - Nuestra Tierra 2.0
# ═══════════════════════════════════════════════════════════════════════════════
@tool
class_name CieloAmbientePista
extends WorldEnvironment

@export_group("⏰ Ciclo Horario")
## Hora actual del día (0.0 a 24.0). 9.5 = 9:30 AM (luz matutina óptima con sombras largas y nítidas).
@export_range(0.0, 24.0, 0.05) var hora_del_dia: float = 9.5:
	set(valor):
		hora_del_dia = valor
		_actualizar_ambiente()

## Si está activado, el tiempo avanza progresivamente durante el juego.
@export var ciclo_dinamico: bool = false
## Minutos reales que tarda un día completo (24h de juego).
@export_range(1.0, 60.0, 0.5) var minutos_por_dia: float = 24.0

@export_group("☀️ Iluminación Solar")
@export var luz_solar: DirectionalLight3D
## Intensidad base del sol al mediodía.
@export_range(0.5, 4.0, 0.1) var energia_solar_maxima: float = 1.35
## Distancia máxima de proyección de sombras (móvil: 120-150m da máxima nitidez cerca del camión).
@export_range(50.0, 300.0, 10.0) var distancia_sombras: float = 140.0

@export_group("🌫️ Niebla Atmosférica")
@export var niebla_activa: bool = true:
	set(valor):
		niebla_activa = valor
		if environment:
			environment.fog_enabled = valor

@export_range(0.0001, 0.005, 0.0001) var densidad_niebla: float = 0.0008:
	set(valor):
		densidad_niebla = valor
		if environment:
			environment.fog_density = valor

@export_group("📱 Optimización Móvil")
## Perfil de sombras optimizado para GPU móvil (Vulkan Mobile).
@export var optimizar_movil: bool = true


func _ready() -> void:
	_configurar_environment_base()
	_buscar_o_vincular_luz_solar()
	_actualizar_ambiente()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not ciclo_dinamico:
		return
	
	if ciclo_dinamico and not Engine.is_editor_hint():
		var incremento_horas = (delta / (minutos_por_dia * 60.0)) * 24.0
		hora_del_dia = fmod(hora_del_dia + incremento_horas, 24.0)


func _buscar_o_vincular_luz_solar() -> void:
	if not is_instance_valid(luz_solar):
		# Intentar buscar nodo de luz solar en los hijos o hermanos
		luz_solar = get_node_or_null("SunLight") as DirectionalLight3D
		if not luz_solar and get_parent():
			luz_solar = get_parent().find_child("SunLight", true, false) as DirectionalLight3D
		if not luz_solar and get_parent():
			luz_solar = get_parent().find_child("DirectionalLight3D", true, false) as DirectionalLight3D

	if is_instance_valid(luz_solar):
		var sm = get_node_or_null("/root/SettingsManager")
		var sombras_actuales: int = 1
		if sm and "current_sombras" in sm:
			sombras_actuales = sm.current_sombras
		aplicar_configuracion_sombras(sombras_actuales)


func aplicar_configuracion_sombras(sombras_idx: int) -> void:
	if not is_instance_valid(luz_solar):
		return
	luz_solar.shadow_enabled = (sombras_idx > 0)
	luz_solar.shadow_bias = 0.025
	luz_solar.shadow_normal_bias = 1.8
	luz_solar.directional_shadow_fade_start = 0.82
	match sombras_idx:
		1: # Baja
			luz_solar.directional_shadow_mode = DirectionalLight3D.ShadowMode.SHADOW_PARALLEL_2_SPLITS
			luz_solar.directional_shadow_max_distance = 80.0
			luz_solar.directional_shadow_blend_splits = false
		2: # Media
			luz_solar.directional_shadow_mode = DirectionalLight3D.ShadowMode.SHADOW_PARALLEL_2_SPLITS
			luz_solar.directional_shadow_max_distance = 140.0
			luz_solar.directional_shadow_blend_splits = true
		3: # Alta
			luz_solar.directional_shadow_mode = DirectionalLight3D.ShadowMode.SHADOW_PARALLEL_4_SPLITS
			luz_solar.directional_shadow_max_distance = 200.0
			luz_solar.directional_shadow_blend_splits = true
		_:
			luz_solar.directional_shadow_mode = DirectionalLight3D.ShadowMode.SHADOW_PARALLEL_2_SPLITS
			luz_solar.directional_shadow_max_distance = distancia_sombras
			luz_solar.directional_shadow_blend_splits = false


func _configurar_environment_base() -> void:
	if not environment:
		environment = Environment.new()

	# Configuración de Post-procesado Cinemático Realista
	environment.background_mode = Environment.BGMode.BG_SKY

	# ── CRÍTICO: NO usar AMBIENT_SOURCE_SKY ni REFLECTION_SOURCE_SKY.
	# Ambos modos fuerzan una captura del sky a un framebuffer separado cada frame.
	# Cuando hay un DirectionalLight3D con shadow_enabled=true, los dos framebuffers
	# colisionan en Vulkan y causan:
	#   "draw_list_begin: Parameter framebuffer is null"
	# Solución: usar COLOR para ambiente (el script actualiza el color manualmente
	# en _actualizar_ambiente(), que ya era necesario para el ciclo día/noche).
	environment.ambient_light_source = Environment.AmbientSource.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution = 0.72
	environment.ambient_light_energy = 0.90
	environment.reflected_light_source = Environment.ReflectionSource.REFLECTION_SOURCE_DISABLED

	# Tonemapping ACES fílmico (estándar de cine y juegos AAA)
	environment.tonemap_mode = Environment.ToneMapper.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0

	# Glow sutil y realista (para neones de pista, faros y destellos cromados)
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.2
	environment.glow_blend_mode = Environment.GlowBlendMode.GLOW_BLEND_MODE_ADDITIVE

	# Ajuste cromático para colores ricos, asfalto contrastado y cielo vibrante
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.06
	environment.adjustment_brightness = 1.0

	# Niebla de profundidad nativa (0 pasadas extra de textura, cálculo por vértice/píxel)
	environment.fog_enabled = niebla_activa
	environment.fog_mode = Environment.FogMode.FOG_MODE_EXPONENTIAL
	environment.fog_density = densidad_niebla
	environment.fog_aerial_perspective = 0.65
	environment.fog_sky_affect = 0.15


func _actualizar_ambiente() -> void:
	if not environment:
		return

	# Ángulo solar según hora del día (6.0 = amanecer, 12.0 = cenit, 18.0 = atardecer)
	var progreso_dia: float = hora_del_dia / 24.0
	var angulo_solar_rad: float = (progreso_dia * TAU) - (PI * 0.5)

	# Altitud y azimut del sol
	var altura_sol: float = sin(angulo_solar_rad)
	var dir_x: float = cos(angulo_solar_rad) * 0.85
	var dir_z: float = cos(progreso_dia * TAU * 0.5) * 0.45

	var direccion_sol: Vector3 = Vector3(dir_x, -altura_sol, dir_z).normalized()

	# Colores dinámicos del sol según temperatura de color física
	var color_luz_sol: Color
	var energia_sol: float = 0.0
	var color_niebla: Color

	if altura_sol > 0.0:
		if altura_sol < 0.2:
			# Amanecer / Atardecer (luz cálida dorada ~3200K)
			var f: float = altura_sol / 0.2
			color_luz_sol = Color(1.0, 0.72, 0.42).lerp(Color(1.0, 0.94, 0.84), f)
			energia_sol = lerpf(0.25, energia_solar_maxima * 0.85, f)
			color_niebla = Color(0.92, 0.68, 0.48).lerp(Color(0.72, 0.80, 0.90), f)
		else:
			# Pleno día (5500K - 6000K, luz solar natural blanca-cálida)
			var f_zenit: float = clampf((altura_sol - 0.2) / 0.8, 0.0, 1.0)
			color_luz_sol = Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.98, 0.94), f_zenit)
			energia_sol = lerpf(energia_solar_maxima * 0.85, energia_solar_maxima, f_zenit)
			color_niebla = Color(0.68, 0.76, 0.86)
	else:
		# Noche
		color_luz_sol = Color(0.2, 0.25, 0.35)
		energia_sol = 0.02
		color_niebla = Color(0.04, 0.05, 0.08)

	if is_instance_valid(luz_solar):
		# Orientar la luz hacia el origen
		var up_safe = Vector3.UP if abs(direccion_sol.dot(Vector3.UP)) < 0.99 else Vector3.BACK
		luz_solar.look_at_from_position(Vector3.ZERO, direccion_sol, up_safe)
		luz_solar.light_color = color_luz_sol
		luz_solar.light_energy = energia_sol
		# NO tocar luz_solar.visible — usar light_energy=0.0 para "apagar" la luz.
		# Togalear visible en un DirectionalLight3D con sombras corrompe el shadow
		# atlas de Vulkan ("draw_list already inactive" / "framebuffer is null")

	# Actualizar color ambiental y niebla para armonizar con el horizonte
	environment.fog_light_color = color_niebla
	environment.ambient_light_color = color_niebla.lerp(Color.WHITE, 0.3)
