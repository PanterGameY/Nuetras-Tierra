# ==============================================================================
# TrochaController.gd
# Controlador de Trocha y Camino Destapado en ESPAÑOL
#
# Permite cambiar el estado de la trocha (seca, barrizal, lluvia, zanjas)
# en tiempo real tanto en el Editor de Godot como durante el juego.
# ==============================================================================
@tool
extends Node
class_name TrochaController

const RUTA_TROCHA_DEFECTO: String = "res://materiales/Mapa/Trocha/Trocha.tres"

@export_group("Conexion de la Malla")

## Malla 3D del camino o trocha (opcional: le aplica Trocha.tres automaticamente)
@export var malla_camino: MeshInstance3D:
	set(nodo):
		malla_camino = nodo
		_vincular_malla()

## Material ShaderMaterial de la trocha (Trocha.tres)
@export var material_trocha: Material:
	set(valor):
		material_trocha = valor
		if material_trocha:
			_sincronizar_desde_material()

## Marca esta casilla para forzar el guardado y refresco de la trocha en el editor
@export var forzar_refresco: bool = false:
	set(valor):
		if valor:
			_forzar_guardado()

# ==============================================================================
# MODOS RÁPIDOS DE TROCHA
# ==============================================================================
enum ModoTrocha {
	PERSONALIZADO,            ## Control manual libre de cada parametro
	TROCHA_SECA_POLVO,        ## Camino destapado en verano, polvoriento y con piedras sueltas
	TROCHA_RURAL_NORMAL,      ## Camino de campo habitual, huellones marcados y tierra firme
	TROCHA_BARRIAL_HUMEDA,    ## Suelo resbaladizo, barro oscuro y huellas frescas
	TROCHA_DESTRUIDA_LLUVIA   ## Barrizal extremo con charcos de agua chocolatosa y zanjas hondas
}

@export_group("Modos Rapidos de Trocha")

## Selecciona un estado preconfigurado para la trocha:
@export var modo_trocha: ModoTrocha = ModoTrocha.PERSONALIZADO:
	set(valor):
		modo_trocha = valor
		_aplicar_modo(valor)

# ==============================================================================
# CONTROLES MANUALES DE TROCHA
# ==============================================================================
@export_group("Controles Manuales de Trocha")

## Humedad general (0 = Seca y polvorienta, 1 = Barrizal empapado)
@export_range(0.0, 1.0, 0.01) var humedad: float = 0.45:
	set(valor):
		humedad = valor
		_asignar_parametro("humedad", clampf(valor, 0.0, 1.0))

## Nivel de agua y acumulacion de charcos en las zanjas
@export_range(0.0, 1.0, 0.01) var nivel_charcos: float = 0.40:
	set(valor):
		nivel_charcos = valor
		_asignar_parametro("nivel_charcos", clampf(valor, 0.0, 1.0))

## Cantidad de lodo y barro espeso revuelto
@export_range(0.0, 1.0, 0.01) var cantidad_barro: float = 0.50:
	set(valor):
		cantidad_barro = valor
		_asignar_parametro("cantidad_barro", clampf(valor, 0.0, 1.0))

## Profundidad visual de los huellones de llantas
@export_range(0.0, 1.0, 0.01) var profundidad_huellones: float = 0.70:
	set(valor):
		profundidad_huellones = valor
		_asignar_parametro("profundidad_huellas", clampf(valor, 0.0, 1.0))

## Cantidad de piedras y cascajo suelto en el camino
@export_range(0.0, 1.0, 0.01) var cantidad_piedras: float = 0.35:
	set(valor):
		cantidad_piedras = valor
		_asignar_parametro("cantidad_piedras", clampf(valor, 0.0, 1.0))

## Activar o desactivar las rodadas/huellones de vehiculos
@export var activar_huellones: bool = true:
	set(valor):
		activar_huellones = valor
		_asignar_parametro("activar_huellones", valor)

## Rota la orientacion del camino 90 grados (util si las huellas van atravesadas en vez de a lo largo)
@export var rotar_camino_90: bool = true:
	set(valor):
		rotar_camino_90 = valor
		_asignar_parametro("rotar_camino_90", valor)

## Desfase para centrar las huellas en el camino si la malla no esta centrada
@export_range(-0.5, 0.5, 0.01) var desfase_lateral: float = 0.0:
	set(valor):
		desfase_lateral = valor
		_asignar_parametro("desfase_lateral", valor)


func _enter_tree() -> void:
	_obtener_material()
	_vincular_malla()
	_sincronizar_desde_material()


func _ready() -> void:
	_obtener_material()
	_vincular_malla()
	_sincronizar_desde_material()


func _vincular_malla() -> void:
	if not is_inside_tree():
		return
	if not malla_camino:
		var p: Node = get_parent()
		if p and p is MeshInstance3D:
			malla_camino = p as MeshInstance3D

	if malla_camino:
		var mat = _obtener_material()
		if mat:
			var mat_actual = malla_camino.get_active_material(0)
			if mat_actual != mat:
				malla_camino.material_override = mat


func _obtener_material() -> ShaderMaterial:
	if material_trocha is ShaderMaterial:
		return material_trocha as ShaderMaterial

	if not material_trocha:
		material_trocha = load(RUTA_TROCHA_DEFECTO)

	if material_trocha is ShaderMaterial:
		return material_trocha as ShaderMaterial

	if malla_camino:
		var m: Material = malla_camino.get_active_material(0)
		if m is ShaderMaterial:
			material_trocha = m
			return material_trocha as ShaderMaterial

	return null


func _asignar_parametro(nombre: String, valor: Variant) -> void:
	if not is_inside_tree():
		return
	var mat: ShaderMaterial = _obtener_material()
	if mat:
		mat.set_shader_parameter(nombre, valor)
		mat.emit_changed()


func _forzar_guardado() -> void:
	if not is_inside_tree():
		return
	var mat: ShaderMaterial = _obtener_material()
	if mat:
		mat.emit_changed()
		ResourceSaver.save(mat, RUTA_TROCHA_DEFECTO)
		print("[TrochaController] Trocha.tres guardado y propagado al mapa.")


func _sincronizar_desde_material() -> void:
	if not is_inside_tree():
		return
	var mat: ShaderMaterial = _obtener_material()
	if not mat:
		return

	var v
	v = mat.get_shader_parameter("humedad")
	if v != null: humedad = float(v)

	v = mat.get_shader_parameter("nivel_charcos")
	if v != null: nivel_charcos = float(v)

	v = mat.get_shader_parameter("cantidad_barro")
	if v != null: cantidad_barro = float(v)

	v = mat.get_shader_parameter("profundidad_huellas")
	if v != null: profundidad_huellones = float(v)

	v = mat.get_shader_parameter("cantidad_piedras")
	if v != null: cantidad_piedras = float(v)

	v = mat.get_shader_parameter("activar_huellones")
	if v != null: activar_huellones = bool(v)

	v = mat.get_shader_parameter("rotar_camino_90")
	if v != null: rotar_camino_90 = bool(v)

	v = mat.get_shader_parameter("desfase_lateral")
	if v != null: desfase_lateral = float(v)


func _aplicar_modo(modo: ModoTrocha) -> void:
	if not is_inside_tree():
		return
	if modo == ModoTrocha.PERSONALIZADO:
		return

	var mat: ShaderMaterial = _obtener_material()
	if not mat:
		return

	match modo:
		ModoTrocha.TROCHA_SECA_POLVO:
			self.humedad = 0.05
			self.nivel_charcos = 0.0
			self.cantidad_barro = 0.15
			self.profundidad_huellones = 0.50
			self.cantidad_piedras = 0.55

		ModoTrocha.TROCHA_RURAL_NORMAL:
			self.humedad = 0.35
			self.nivel_charcos = 0.20
			self.cantidad_barro = 0.40
			self.profundidad_huellones = 0.65
			self.cantidad_piedras = 0.35

		ModoTrocha.TROCHA_BARRIAL_HUMEDA:
			self.humedad = 0.70
			self.nivel_charcos = 0.45
			self.cantidad_barro = 0.75
			self.profundidad_huellones = 0.85
			self.cantidad_piedras = 0.25

		ModoTrocha.TROCHA_DESTRUIDA_LLUVIA:
			self.humedad = 0.95
			self.nivel_charcos = 0.85
			self.cantidad_barro = 0.90
			self.profundidad_huellones = 1.00
			self.cantidad_piedras = 0.30

	_forzar_guardado()
	notify_property_list_changed()


# Metodos para invocar desde logica de juego o clima
func cambiar_humedad(valor: float) -> void: self.humedad = valor
func cambiar_charcos(valor: float) -> void: self.nivel_charcos = valor
func cambiar_barro(valor: float) -> void: self.cantidad_barro = valor
