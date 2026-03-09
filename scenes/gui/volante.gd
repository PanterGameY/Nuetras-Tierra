# volante_textura.gd
extends TextureRect

@export_group("Configuración Visual")
@export var sensibilidad: float = 1.5
@export var velocidad_retorno: float = 4.0
@export var vueltas_totales: float = 1.5 
@export var retorno_automatico: bool = true
@export var zona_muerta_centro: float = 48.0

@export_group("Opacidad Dinámica")
@export_range(0.0, 1.0) var opacidad_reposo: float = 0.4
@export_range(0.0, 1.0) var opacidad_activa: float = 0.9
@export var velocidad_fade: float = 10.0

var rotacion_actual: float = 0.0 
var tocando: bool = false
var angulo_anterior: float = 0.0
var dedo_activo: int = -1
var ya_vibro: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    self_modulate.a = opacidad_reposo

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if dedo_activo != -1: return
            var radio_max: float = min(size.x, size.y) * 0.5
            var dist_al_centro = event.position.distance_to(size / 2.0)
            
            if dist_al_centro > zona_muerta_centro and dist_al_centro < radio_max:
                tocando = true
                dedo_activo = event.index
                angulo_anterior = _obtener_angulo(event.position)
        else:
            if event.index == dedo_activo:
                tocando = false
                dedo_activo = -1
                if is_instance_valid(InputVehiculo) and InputVehiculo.has_method("liberar_direccion_tactil"):
                    InputVehiculo.liberar_direccion_tactil()

    if event is InputEventScreenDrag and tocando and event.index == dedo_activo:
        var angulo_nuevo = _obtener_angulo(event.position)
        
        # CORRECCIÓN DE INVERSIÓN: 
        # Invertimos el delta para que el movimiento horario sea positivo
        var delta = wrapf(angulo_nuevo - angulo_anterior, -PI, PI)
        
        var factor_sensibilidad = sensibilidad * 1.2
        var cambio = (delta / PI) * factor_sensibilidad
        
        # Aplicamos el cambio. Ahora rotacion_actual > 0 es derecha (horario)
        rotacion_actual = clamp(rotacion_actual + cambio, -1.0, 1.0)
        angulo_anterior = angulo_nuevo
        _actualizar_visual_y_fisica()

func _obtener_angulo(pos: Vector2) -> float:
    # Retorna el ángulo del toque relativo al centro
    return (pos - size / 2.0).angle()

func _process(delta: float) -> void:
    # Mantener la direccion mientras se sostiene el volante, incluso si no hay drag nuevo.
    if tocando and is_instance_valid(InputVehiculo):
        InputVehiculo.set_direccion(rotacion_actual)

    if retorno_automatico and not tocando and abs(rotacion_actual) > 0.001:
        rotacion_actual = move_toward(rotacion_actual, 0.0, velocidad_retorno * delta)
        _actualizar_visual_y_fisica()
    
    var target_alpha = opacidad_activa if tocando else opacidad_reposo
    self_modulate.a = lerp(self_modulate.a, target_alpha, delta * velocidad_fade)

func _actualizar_visual_y_fisica():
    if material is ShaderMaterial:
        # Invertimos solo la visual del volante para corregir la percepcion de giro.
        var rotacion_shader = -rotacion_actual * PI * vueltas_totales
        material.set_shader_parameter("rotacion", rotacion_shader)
    
    if is_instance_valid(InputVehiculo):
        # Enviamos el valor al coche. 
        # Si las ruedas giran al revés en tu modelo, quita el signo menos.
        InputVehiculo.set_direccion(rotacion_actual)

    if abs(rotacion_actual) >= 0.99:
        if not ya_vibro:
            Input.vibrate_handheld(25)
            ya_vibro = true
    else:
        ya_vibro = false