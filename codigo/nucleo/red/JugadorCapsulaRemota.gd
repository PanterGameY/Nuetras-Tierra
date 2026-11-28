extends CharacterBody3D

## Representación humana casual animada para jugadores remotos en multijugador WebRTC P2P.
var _conduciendo: bool = false:
	set(value):
		_conduciendo = value
		visible = not _conduciendo

var _anim_actual: String = "Idle":
	set(value):
		if _anim_actual != value:
			_anim_actual = value

var _pos_objetivo: Vector3 = Vector3.ZERO
var _rot_y_objetivo: float = 0.0
var _tiene_objetivo: bool = false
var _anim_player: AnimationPlayer = null
var _modelo_visual: Node3D = null
var _anim_reproduciendo: String = ""
var _vel_giro_suave: float = 0.0
var _inclinacion_giro: float = 0.0

func _ready() -> void:
	_pos_objetivo = global_position
	_rot_y_objetivo = rotation.y
	_modelo_visual = get_node_or_null("ModeloVoxel") as Node3D
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player:
		for nombre_loop in ["Idle", "caminar", "Correr", "Agacharse", "CaminarAgachado", "GirarIzq", "GirarDer"]:
			if _anim_player.has_animation(nombre_loop):
				var anim_res := _anim_player.get_animation(nombre_loop)
				if anim_res:
					anim_res.loop_mode = Animation.LOOP_LINEAR
		for nombre_unica in ["Saltar", "Saltar Corriendo"]:
			if _anim_player.has_animation(nombre_unica):
				var anim_u := _anim_player.get_animation(nombre_unica)
				if anim_u:
					anim_u.loop_mode = Animation.LOOP_NONE
		_reproducir_animacion("Idle", 0.2)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() or not _tiene_objetivo:
		return

	var rot_anterior := rotation.y
	global_position = global_position.lerp(_pos_objetivo, clampf(delta * 16.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _rot_y_objetivo, clampf(delta * 16.0, 0.0, 1.0))

	var diff_yaw := angle_difference(rot_anterior, rotation.y)
	var vel_giro_inst := diff_yaw / maxf(delta, 0.001)
	_vel_giro_suave = lerpf(_vel_giro_suave, vel_giro_inst, clampf(delta * 10.0, 0.0, 1.0))

	var vel_horiz := Vector2(velocity.x, velocity.z).length()

	# Inclinación sutil del cuerpo al girar corriendo o caminando
	if is_instance_valid(_modelo_visual):
		var bank_obj := clampf(-_vel_giro_suave * 0.035, -0.12, 0.12) if vel_horiz > 1.2 else 0.0
		_inclinacion_giro = lerpf(_inclinacion_giro, bank_obj, clampf(delta * 9.0, 0.0, 1.0))
		_modelo_visual.rotation.z = _inclinacion_giro

	# Selección inteligente de animación sincronizada (incluyendo giro en el sitio, agachado y salto)
	var anim_deseada := _anim_actual
	if anim_deseada == "" or anim_deseada == "Idle":
		if absf(_vel_giro_suave) > 0.85 and vel_horiz < 0.45:
			anim_deseada = "GirarIzq" if _vel_giro_suave > 0.0 else "GirarDer"
		elif vel_horiz > 5.2:
			anim_deseada = "Correr"
		elif vel_horiz > 0.35:
			anim_deseada = "caminar"
		else:
			anim_deseada = "Idle"

	var blend_time := 0.18
	if anim_deseada in ["Saltar", "Saltar Corriendo"]:
		blend_time = 0.10
	elif anim_deseada in ["Agacharse", "CaminarAgachado"]:
		blend_time = 0.20

	_reproducir_animacion(anim_deseada, blend_time)

func _reproducir_animacion(nombre: String, blend: float = 0.18) -> void:
	if not _anim_player:
		return
	var objetivo := nombre if _anim_player.has_animation(nombre) else "Idle"
	if _anim_reproduciendo == objetivo:
		if objetivo in ["Saltar", "Saltar Corriendo"] or _anim_player.is_playing():
			return
	if _anim_player.has_animation(objetivo):
		_anim_reproduciendo = objetivo
		_anim_player.play(objetivo, blend)

@rpc("any_peer", "unreliable")
func actualizar_transform_remoto(pos: Vector3, rot_y: float, vel: Vector3, anim: String, cond: bool) -> void:
	if not is_multiplayer_authority():
		_pos_objetivo = pos
		_rot_y_objetivo = rot_y
		velocity = vel
		_anim_actual = anim
		_conduciendo = cond
		_tiene_objetivo = true
