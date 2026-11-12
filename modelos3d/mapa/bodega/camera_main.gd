@tool
extends Camera3D

# Control de Cámara Orbital Cinematográfica para el Menú Principal / Bodega.

## Ruta hacia el nodo 3D objetivo que la cámara rodeará (ej. camión o "CameraTarget")
@export var ruta_objetivo: NodePath = NodePath("")
## Distancia o radio de la órbita alrededor del objetivo (en metros)
@export var radio_orbita: float = 6.0:
	set(val):
		radio_orbita = _limitar_flotante(val, 0.5, 50.0)
		_radio_base_activo = radio_orbita
## Altura de la cámara con respecto al suelo/origen del objetivo (en metros)
@export var altura_camara: float = 1.0:
	set(val):
		altura_camara = _limitar_flotante(val, -10.0, 50.0)
		_altura_base_activa = altura_camara
## Altura del punto de la mirada al que apunta el objetivo (en metros)
@export var altura_puesto_mirada: float = 1.2:
	set(val):
		altura_puesto_mirada = _limitar_flotante(val, -10.0, 50.0)
		_altura_mirada_activa = altura_puesto_mirada

# Variables de compatibilidad en inglés para scripts existentes
var target_path: NodePath:
	get: return ruta_objetivo
	set(val): ruta_objetivo = val

var radius: float:
	get: return radio_orbita
	set(val): radio_orbita = val

var height_offset: float:
	get: return altura_camara
	set(val): altura_camara = val

var look_at_height: float:
	get: return altura_puesto_mirada
	set(val): altura_puesto_mirada = val


@export_group("Director Cinematográfico (Cortes y Parpadeos)")
## Activa el cambio automático e impredecible de tomas y ángulos de cámara
@export var activar_cortes_director: bool = true
## Tiempo en segundos que transcurre antes de cambiar automáticamente a un nuevo ángulo
@export var intervalo_cambio_toma: float = 7.0
## Activa el parpadeo de pantalla (fundido a negro rápido) al teletransportarse a un nuevo ángulo
@export var activar_parpadeo_pantalla: bool = true
## Duración total en segundos del efecto de parpadeo de pantalla
@export var duracion_parpadeo: float = 0.3


@export_group("Prevención de Colisiones (Paredes y Entorno)")
## Previene que la cámara atraviese paredes, techos o colisiones 3D del escenario
@export var activar_evitar_colisiones: bool = true
## Distancia mínima de separación que mantendrá la cámara frente a una pared impactada
@export var margen_colision_pared: float = 0.35
## Máscara de capa física para detectar colisiones en el espacio 3D
@export var mascara_capa_colision: int = 1


@export_group("Movimiento y Rotación")
## Velocidad de rotación automática en grados por segundo
@export var velocidad_rotacion_grados: float = 14.0
## Ángulo inicial de inicio en grados
@export var angulo_inicial_grados: float = 0.0
## Velocidad de suavizado del movimiento (valores altos = respuesta inmediata)
@export var velocidad_suavizado: float = 12.0
## Activa la rotación continua automática alrededor del vehículo
@export var rotacion_automatica: bool = true
## Si es verdadero, gira en sentido horario; si es falso, gira en sentido antihorario
@export var girar_sentido_horario: bool = true
## Activa el seguimiento de mirada fija hacia el objetivo
@export var apuntar_al_objetivo: bool = true


@export_group("Inercia y Control Táctil / Arrastre")
## Sensibilidad de respuesta al deslizar el dedo o ratón por la pantalla
@export var sensibilidad_arrastre: float = 0.35
## Fricción de frenado que detiene progresivamente el giro tras soltar el arrastre
@export var friccion_inercia: float = 6.0
## Pausa temporalmente la rotación automática mientras el usuario arrastra la cámara
@export var pausar_al_arrastrar: bool = true
## Tiempo en segundos que espera para reanudar la rotación automática tras soltar
@export var tiempo_reanudacion_auto: float = 4.0


@export_group("Efectos Orgánicos Épicos")
## Activa variaciones orgánicas como balanceo, flotación y elipse dinámicas
@export var activar_movimiento_organico: bool = true
## Activa una suave inclinación de la lente al realizar giros rápidos
@export var activar_inclinacion_giro: bool = true
## Activa la respiración y variación dinámica de campo de visión (FOV)
@export var activar_fov_dinamico: bool = true
## Campo de visión (FOV) base de la cámara en grados (rango de 15 a 160)
@export var fov_base: float = 54.4:
	set(val):
		fov_base = _limitar_flotante(val, 15.0, 160.0)
		_fov_base_activo = fov_base
## Amplitud de variación en metros de la distancia durante la órbita
@export var amplitud_variacion_radio: float = 0.8
## Amplitud de variación en metros de la altura durante la órbita
@export var amplitud_variacion_altura: float = 0.4
## Amplitud del movimiento de flotación vertical (bobbing)
@export var amplitud_flotacion_vertical: float = 0.15
## Velocidad del movimiento de flotación vertical
@export var velocidad_flotacion_vertical: float = 1.8
## Modificador de forma elíptica en el eje X
@export var excentricidad_eje_x: float = 1.05
## Modificador de forma elíptica en el eje Z
@export var excentricidad_eje_z: float = 0.95


# Variables de control interno
var _temporizador_toma: float = 0.0
var _capa_parpadeo: ColorRect = null
var _animacion_parpadeo: Tween = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _nodo_objetivo: Node3D = null
var _angulo_rad: float = 0.0
var _velocidad_angular: float = 0.0
var _tiempo_acumulado: float = 0.0
var _posicion_mirada_actual: Vector3 = Vector3.ZERO
var _radio_efectivo_actual: float = 6.0
var _inclinacion_actual: float = 0.0
var _temporizador_reanudacion: float = 0.0

# Parámetros activos de la toma actual
var _radio_base_activo: float = 6.0
var _altura_base_activa: float = 1.0
var _altura_mirada_activa: float = 1.2
var _fov_base_activo: float = 54.4

# Función auxiliar estática segura para limitar valores numéricos flotantes
static func _limitar_flotante(val, min_v: float, max_v: float) -> float:
	if val == null:
		return min_v
	var f_val: float = float(val)
	if f_val < min_v:
		return min_v
	if f_val > max_v:
		return max_v
	return f_val


func _ready() -> void:
	_rng.randomize()
	_velocidad_angular = 0.0
	_angulo_rad = 0.0
	_radio_efectivo_actual = _limitar_flotante(radio_orbita, 0.5, 50.0)
	_inclinacion_actual = 0.0
	_temporizador_reanudacion = 0.0
	
	if ruta_objetivo != NodePath(""):
		_nodo_objetivo = get_node_or_null(ruta_objetivo) as Node3D
	if _nodo_objetivo == null:
		var escena = get_tree().get_current_scene()
		if escena:
			_nodo_objetivo = escena.get_node_or_null("CameraTarget") as Node3D
		if _nodo_objetivo == null and get_parent():
			_nodo_objetivo = get_parent().get_node_or_null("T800_Alargada") as Node3D

	_radio_base_activo = radio_orbita
	_altura_base_activa = altura_camara
	_altura_mirada_activa = altura_puesto_mirada
	_fov_base_activo = _limitar_flotante(fov_base, 15.0, 160.0)
	fov = _fov_base_activo

	if _nodo_objetivo:
		var pos_target: Vector3 = _nodo_objetivo.global_transform.origin
		var dif: Vector3 = global_transform.origin - pos_target
		var dist_xz: float = Vector2(dif.x, dif.z).length()
		if dist_xz > 0.1:
			_angulo_rad = atan2(dif.z, dif.x)
			_radio_efectivo_actual = dist_xz
		else:
			_angulo_rad = deg_to_rad(angulo_inicial_grados)
			_radio_efectivo_actual = radio_orbita
			
		_posicion_mirada_actual = pos_target + Vector3(0.0, altura_puesto_mirada, 0.0)
		look_at(_posicion_mirada_actual, Vector3.UP)
	else:
		_angulo_rad = deg_to_rad(angulo_inicial_grados)
		_radio_efectivo_actual = radio_orbita

	var direccion: float = -1.0 if girar_sentido_horario else 1.0
	_velocidad_angular = direccion * deg_to_rad(velocidad_rotacion_grados)

	_configurar_capa_parpadeo()


func _configurar_capa_parpadeo() -> void:
	if Engine.is_editor_hint():
		return
	if _capa_parpadeo == null:
		_capa_parpadeo = ColorRect.new()
		_capa_parpadeo.name = "CameraBlinkOverlay"
		_capa_parpadeo.set_anchors_preset(Control.PRESET_FULL_RECT)
		_capa_parpadeo.color = Color(0, 0, 0, 0)
		_capa_parpadeo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var canvas = CanvasLayer.new()
		canvas.name = "BlinkCanvas"
		canvas.layer = 10
		canvas.add_child(_capa_parpadeo)
		add_child(canvas)


func activar_corte_cinematografico() -> void:
	# Tomas estilizadas a nivel de ojos y suelo (altura automotriz de showroom)
	var tomas_predefinidas = [
		{"radio": 7.0, "altura": 0.8, "mirada": 1.0, "fov": 46.0}, # Tres cuartos frontal imponente
		{"radio": 6.2, "altura": 0.5, "mirada": 0.85, "fov": 48.0}, # Toma baja estilo heroica
		{"radio": 8.0, "altura": 1.1, "mirada": 1.1, "fov": 44.0}, # Perfil completo de carroceria
		{"radio": 5.8, "altura": 0.7, "mirada": 0.95, "fov": 50.0}, # Detalle de rueda y tren motriz
		{"radio": 7.5, "altura": 0.9, "mirada": 1.05, "fov": 45.0}  # Perspectiva general nivel de piso
	]
	var toma = tomas_predefinidas[_rng.randi() % tomas_predefinidas.size()]
	var radio_azar: float = toma["radio"]
	var altura_azar: float = toma["altura"]
	var mirada_azar: float = toma["mirada"]
	var fov_azar: float = toma["fov"]
	var angulo_azar: float = _rng.randf_range(0.0, TAU)
	girar_sentido_horario = _rng.randf() > 0.5

	if activar_parpadeo_pantalla and _capa_parpadeo and not Engine.is_editor_hint():
		if _animacion_parpadeo and _animacion_parpadeo.is_valid():
			_animacion_parpadeo.kill()
		_animacion_parpadeo = create_tween()
		
		# 1. Fundido a negro ultrarrápido (Parpadeo)
		_animacion_parpadeo.tween_property(_capa_parpadeo, "color:a", 1.0, duracion_parpadeo * 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
		# 2. En el punto de oscuridad absoluta: TELETRANSPORTE INSTANTÁNEO
		_animacion_parpadeo.tween_callback(func():
			_teletransportar_a_toma(radio_azar, altura_azar, mirada_azar, fov_azar, angulo_azar)
		)
		
		# 3. Revelar la nueva toma
		_animacion_parpadeo.tween_property(_capa_parpadeo, "color:a", 0.0, duracion_parpadeo * 0.6)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		_teletransportar_a_toma(radio_azar, altura_azar, mirada_azar, fov_azar, angulo_azar)


func _teletransportar_a_toma(p_radio: float, p_altura: float, p_mirada: float, p_fov: float, p_angulo: float) -> void:
	_radio_base_activo = p_radio
	_altura_base_activa = p_altura
	_altura_mirada_activa = p_mirada
	_fov_base_activo = _limitar_flotante(p_fov, 15.0, 160.0)
	_angulo_rad = p_angulo
	_radio_efectivo_actual = p_radio
	fov = _fov_base_activo

	var direccion: float = -1.0 if girar_sentido_horario else 1.0
	_velocidad_angular = direccion * deg_to_rad(velocidad_rotacion_grados)

	if _nodo_objetivo:
		var pos_target: Vector3 = _nodo_objetivo.global_transform.origin
		var px: float = cos(_angulo_rad) * _radio_efectivo_actual * excentricidad_eje_x
		var pz: float = sin(_angulo_rad) * _radio_efectivo_actual * excentricidad_eje_z
		var pos_deseada = pos_target + Vector3(px, _altura_base_activa, pz)
		
		var pos_segura = _resolver_colision(pos_target, pos_deseada)
		global_transform.origin = pos_segura
		
		_posicion_mirada_actual = pos_target + Vector3(0.0, _altura_mirada_activa, 0.0)
		look_at(_posicion_mirada_actual, Vector3.UP)


func _resolver_colision(desde_pos: Vector3, hacia_pos: Vector3) -> Vector3:
	if not activar_evitar_colisiones or Engine.is_editor_hint():
		return hacia_pos

	var w3d = get_world_3d()
	if not w3d:
		return hacia_pos

	var espacio_estado = w3d.direct_space_state
	if not espacio_estado:
		return hacia_pos

	var consulta_rayo = PhysicsRayQueryParameters3D.create(desde_pos, hacia_pos)
	consulta_rayo.collision_mask = mascara_capa_colision
	
	if _nodo_objetivo is CollisionObject3D:
		consulta_rayo.exclude = [_nodo_objetivo.get_rid()]

	var impacto = espacio_estado.intersect_ray(consulta_rayo)
	if not impacto.is_empty():
		var pos_impacto: Vector3 = impacto.position
		var dir: Vector3 = (hacia_pos - desde_pos).normalized()
		return pos_impacto - dir * margen_colision_pared

	return hacia_pos


func _process(delta: float) -> void:
	# Garantizar inicialización segura de variables
	if _velocidad_angular == null:
		_velocidad_angular = 0.0
	if _angulo_rad == null:
		_angulo_rad = 0.0
	if _radio_efectivo_actual == null:
		_radio_efectivo_actual = _limitar_flotante(radio_orbita, 0.5, 50.0)
	if _inclinacion_actual == null:
		_inclinacion_actual = 0.0
	if _temporizador_reanudacion == null:
		_temporizador_reanudacion = 0.0
	if _fov_base_activo == null or _fov_base_activo < 15.0 or _fov_base_activo > 160.0:
		_fov_base_activo = _limitar_flotante(fov_base, 15.0, 160.0)

	if _nodo_objetivo == null:
		if get_parent():
			_nodo_objetivo = get_parent().get_node_or_null("T800_Alargada") as Node3D
		if _nodo_objetivo == null:
			return

	_tiempo_acumulado += delta

	if _temporizador_reanudacion > 0.0:
		_temporizador_reanudacion -= delta
	else:
		if activar_cortes_director and not Engine.is_editor_hint():
			_temporizador_toma += delta
			if _temporizador_toma >= intervalo_cambio_toma:
				_temporizador_toma = 0.0
				activar_corte_cinematografico()

	var direccion: float = -1.0 if girar_sentido_horario else 1.0

	# 1. Aplicar Auto-Rotación e Inercia de Arrastre
	var t_vel: float = _limitar_flotante(5.0 * delta, 0.0, 1.0)
	if rotacion_automatica and _temporizador_reanudacion <= 0.0:
		var target_vel: float = direccion * deg_to_rad(velocidad_rotacion_grados)
		_velocidad_angular += (target_vel - _velocidad_angular) * t_vel
	else:
		var t_fric: float = _limitar_flotante(friccion_inercia * delta, 0.0, 1.0)
		_velocidad_angular += (0.0 - _velocidad_angular) * t_fric

	_angulo_rad += _velocidad_angular * delta

	# 2. Radio y posición elíptica
	var pos_target: Vector3 = _nodo_objetivo.global_transform.origin
	var radio_mod: float = 0.0
	if activar_movimiento_organico:
		radio_mod = sin(_angulo_rad * 1.5 + _tiempo_acumulado * 0.5) * amplitud_variacion_radio

	var calc_radius: float = max(0.5, _radio_base_activo + radio_mod)
	var t_rad: float = _limitar_flotante(6.0 * delta, 0.0, 1.0)
	_radio_efectivo_actual += (calc_radius - _radio_efectivo_actual) * t_rad

	var px: float = cos(_angulo_rad) * _radio_efectivo_actual * excentricidad_eje_x
	var pz: float = sin(_angulo_rad) * _radio_efectivo_actual * excentricidad_eje_z
	var pos_deseada: Vector3 = pos_target + Vector3(px, _altura_base_activa, pz)

	if activar_movimiento_organico:
		pos_deseada.y += sin(_tiempo_acumulado * velocidad_flotacion_vertical) * amplitud_flotacion_vertical
		pos_deseada.y += sin(_angulo_rad * 1.2) * amplitud_variacion_altura

	# Prevención de colisiones con paredes/escenario
	pos_deseada = _resolver_colision(pos_target, pos_deseada)

	# 3. Interpolar posición suavemente
	var lerp_factor: float = _limitar_flotante(velocidad_suavizado * delta, 0.0, 1.0)
	var nueva_pos: Vector3 = global_transform.origin.lerp(pos_deseada, lerp_factor)
	global_transform.origin = nueva_pos

	# 4. Apuntar dinámicamente al objetivo (LookAt)
	if apuntar_al_objetivo:
		var mirada_deseada: Vector3 = pos_target + Vector3(0.0, _altura_mirada_activa, 0.0)
		if activar_movimiento_organico:
			mirada_deseada.y += sin(_tiempo_acumulado * 0.8) * 0.1
		
		var t_look: float = _limitar_flotante(8.0 * delta, 0.0, 1.0)
		_posicion_mirada_actual = _posicion_mirada_actual.lerp(mirada_deseada, t_look)
		look_at(_posicion_mirada_actual, Vector3.UP)

	# 5. Inclinación lateral en giros (Leaning Roll)
	if activar_inclinacion_giro and abs(_velocidad_angular) > 0.001:
		var inclinacion_objetivo: float = _limitar_flotante(-_velocidad_angular * 0.15, -deg_to_rad(4.0), deg_to_rad(4.0))
		var t_roll: float = _limitar_flotante(8.0 * delta, 0.0, 1.0)
		_inclinacion_actual += (inclinacion_objetivo - _inclinacion_actual) * t_roll
		rotate_object_local(Vector3.FORWARD, _inclinacion_actual)

	# 6. FOV Dinámico con Respiración Cinematográfica
	if activar_fov_dinamico:
		var impulso_fov_velocidad: float = _limitar_flotante(abs(_velocidad_angular) * 2.0, 0.0, 5.0)
		var respiracion_fov: float = sin(_tiempo_acumulado * 0.6) * 1.2
		var fov_objetivo: float = _fov_base_activo + impulso_fov_velocidad + respiracion_fov
		var t_fov: float = _limitar_flotante(4.0 * delta, 0.0, 1.0)
		var fov_siguiente: float = fov + (fov_objetivo - fov) * t_fov
		fov = _limitar_flotante(fov_siguiente, 15.0, 160.0)


## Método público en español para arrastrar la cámara manualmente desde la UI
func rotar_desde_entrada(relativo_x: float) -> void:
	if _velocidad_angular == null:
		_velocidad_angular = 0.0
	_velocidad_angular += relativo_x * (sensibilidad_arrastre * 0.15)
	if pausar_al_arrastrar:
		_temporizador_reanudacion = tiempo_reanudacion_auto

## Método de compatibilidad en inglés para invocaciones previas
func rotate_from_input(relative_x: float) -> void:
	rotar_desde_entrada(relative_x)
