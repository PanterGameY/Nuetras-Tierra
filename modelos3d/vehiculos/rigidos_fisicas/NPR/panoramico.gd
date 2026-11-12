extends MeshInstance3D

@export_group("Configuración de Impacto")
## Fuerza mínima del impacto para romper el vidrio.
## Un valor entre 5.0 y 15.0 suele ser bueno.
@export var fuerza_impacto_minima: float = 8.0 
@export var probabilidad_base: float = 0.5

var coche_ref: RigidBody3D
var velocidad_ultimo_frame: Vector3 = Vector3.ZERO

func _ready() -> void:
	coche_ref = _buscar_coche(get_parent())
	
	if coche_ref:
		coche_ref.contact_monitor = true
		coche_ref.max_contacts_reported = 5
		# Usamos body_entered para asegurar que hubo contacto físico
		if not coche_ref.body_entered.is_connected(_on_coche_collision):
			coche_ref.body_entered.connect(_on_coche_collision)
	
	set_instance_shader_parameter("damage_amount", 0.0)

func _on_coche_collision(body: Node) -> void:
	# 1. Solo calculamos el impacto si hay un cuerpo contra el que chocamos
	# (StaticBody, RigidBody, AnimatableBody)
	if body.is_class("StaticBody3D") or body.is_class("RigidBody3D"):
		
		# 2. CALCULAR FUERZA DEL IMPACTO
		# Comparamos la velocidad actual contra la velocidad del frame anterior
		# Un choque causa una deceleración instantánea (cambio de velocidad en 0.016s)
		var cambio_velocidad = (coche_ref.linear_velocity - velocidad_ultimo_frame).length()
		
		# Solo para pruebas:
		# print("💥 Impacto detectado con fuerza: ", cambio_velocidad)

		# 3. FILTRADO: Si el cambio de velocidad es mayor que el umbral, se rompe.
		# A diferencia de antes, acelerar solo cambia la velocidad gradualmente, 
		# por lo que el cambio_velocidad será pequeño (0.1 o 0.2).
		# Al chocar contra una pared, el cambio_velocidad será de golpe (10.0, 20.0).
		if cambio_velocidad > fuerza_impacto_minima:
			_romper_con_probabilidad(cambio_velocidad)

func _romper_con_probabilidad(fuerza: float) -> void:
	var chance = (fuerza / fuerza_impacto_minima) * probabilidad_base
	if randf() < chance:
		_aplicar_danio(1.0)

func _physics_process(_delta: float) -> void:
	if coche_ref:
		# Guardamos la velocidad de este frame para comparar en el siguiente
		velocidad_ultimo_frame = coche_ref.linear_velocity

func _aplicar_danio(cantidad: float) -> void:
	var tween = create_tween()
	tween.tween_property(self, "instance_shader_parameters/damage_amount", cantidad, 0.1)

func _buscar_coche(nodo: Node) -> RigidBody3D:
	if nodo == null or nodo is RigidBody3D: return nodo
	return _buscar_coche(nodo.get_parent())
