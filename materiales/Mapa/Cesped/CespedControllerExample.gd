# ==============================================================================
# CespedControllerExample.gd
# Controlador de Terreno en ESPAÑOL con Modos Rápidos y Actualización en Vivo
# ==============================================================================
@tool
extends Node
class_name CespedControllerExample

const RUTA_CESPED_DEFECTO: String = "res://materiales/Mapa/Cesped/Cesped.tres"

@export_group("Conexión del Terreno")

## Malla 3D del terreno (opcional: si la asignas, se asegura de que use Cesped.tres)
@export var malla_terreno: MeshInstance3D:
	set(nodo):
		malla_terreno = nodo
		_vincular_malla()

## Material de césped del mapa (Cesped.tres)
@export var material_cesped: Material:
	set(valor):
		material_cesped = valor
		if material_cesped:
			_sincronizar_desde_material()

## Marca esta casilla para forzar el guardado y refresco de todo el terreno en el editor
@export var forzar_refresco: bool = false:
	set(valor):
		if valor:
			_forzar_guardado()

# ==============================================================================
# MODOS REALISTAS RÁPIDOS (SELECCIÓN EN 1 CLIC)
# ==============================================================================
enum ModoPreset {
	PERSONALIZADO,       ## Control manual libre de cada control
	PRADO_VERDE,         ## Prado verde fresco, vivo y limpio
	CAMPO_RURAL,         ## Campo rural cálido con parches de tierra natural
	SABANA_SECA,         ## Pastizal seco, amarillento y suelo árido
	LLUVIA_BARRO,        ## Terreno mojado, tierra convertida en barro y charcos
	ORILLA_CARRETERA     ## Carretera de campo con berma de tierra y piedras
}

@export_group("Modos Realistas Rapidos")

## Selecciona un estilo predeterminado para el terreno:
@export var modo_realista: ModoPreset = ModoPreset.PERSONALIZADO:
	set(valor):
		modo_realista = valor
		_aplicar_modo(valor)

# ==============================================================================
# CONTROLES MANUALES DEL TERRENO
# ==============================================================================
@export_group("Controles Manuales de Terreno")

## Cantidad de tierra natural mezclada con el césped
@export_range(0.0, 1.0, 0.01) var mezcla_tierra: float = 0.28:
	set(valor):
		mezcla_tierra = valor
		_asignar_parametro("dirt_blend_amount", clampf(valor, 0.0, 1.0))

## Humedad del terreno / lluvia (0 = Seco, 1 = Mojado / Charcos reflectivos)
@export_range(0.0, 1.0, 0.01) var humedad_suelo: float = 0.0:
	set(valor):
		humedad_suelo = valor
		_asignar_parametro("wetness", clampf(valor, 0.0, 1.0))

## Nivel de sequedad del césped (0 = Verde fresco, 1 = Verano, 2 = Sabana, 3 = Seco)
@export_range(0.0, 3.0, 0.05) var estado_secado: float = 0.0:
	set(valor):
		estado_secado = valor
		_asignar_parametro("grass_state", clampf(valor, 0.0, 3.0))

## Fuerza de la variación de tonos para quitar lo monótono y repetitivo
@export_range(0.0, 1.0, 0.01) var variacion_color: float = 0.45:
	set(valor):
		variacion_color = valor
		_asignar_parametro("variation_strength", clampf(valor, 0.0, 1.0))

## Intensidad de la onda de viento sobre el pasto
@export_range(0.0, 2.0, 0.01) var fuerza_viento: float = 0.30:
	set(valor):
		fuerza_viento = valor
		_asignar_parametro("wind_strength", maxf(valor, 0.0))

## Velocidad de la onda de viento
@export_range(0.0, 10.0, 0.1) var velocidad_viento: float = 1.5:
	set(valor):
		velocidad_viento = valor
		_asignar_parametro("wind_speed", maxf(valor, 0.0))

## Desgaste por huellas o paso de vehículos
@export_range(0.0, 1.0, 0.01) var desgaste_huellas: float = 0.0:
	set(valor):
		desgaste_huellas = valor
		_asignar_parametro("wear_amount", clampf(valor, 0.0, 1.0))

## Activar tierra en el contorno exterior del objeto
@export var activar_borde_carretera: bool = false:
	set(valor):
		activar_borde_carretera = valor
		_asignar_parametro("road_edge_enabled", valor)

## Intensidad de tierra en la orilla junto a la carretera
@export_range(0.0, 1.0, 0.01) var tierra_en_orilla: float = 0.85:
	set(valor):
		tierra_en_orilla = valor
		_asignar_parametro("road_edge_dirt_intensity", clampf(valor, 0.0, 1.0))

## Ancho de la franja de tierra junto a la carretera
@export_range(0.01, 10.0, 0.05) var ancho_orilla_tierra: float = 0.15:
	set(valor):
		ancho_orilla_tierra = valor
		_asignar_parametro("road_edge_width", clampf(valor, 0.01, 10.0))

## Nivel de calidad para optimizar en móviles (0 = Bajo, 1 = Medio, 2 = Alto)
@export_range(0, 2, 1) var nivel_calidad: int = 2:
	set(valor):
		nivel_calidad = valor
		_asignar_parametro("quality_level", clampi(valor, 0, 2))


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
	if not malla_terreno:
		var p: Node = get_parent()
		if p and p is MeshInstance3D:
			malla_terreno = p as MeshInstance3D

	if malla_terreno:
		var mat = _obtener_material()
		if mat:
			# Si la malla no tiene asignado Cesped.tres, asignarlo como override
			var mat_actual = malla_terreno.get_active_material(0)
			if mat_actual != mat:
				malla_terreno.material_override = mat


func _obtener_material() -> ShaderMaterial:
	if material_cesped is ShaderMaterial:
		return material_cesped as ShaderMaterial

	if not material_cesped:
		material_cesped = load(RUTA_CESPED_DEFECTO)

	if material_cesped is ShaderMaterial:
		return material_cesped as ShaderMaterial

	if malla_terreno:
		var m: Material = malla_terreno.get_active_material(0)
		if m is ShaderMaterial:
			material_cesped = m
			return material_cesped as ShaderMaterial

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
		ResourceSaver.save(mat, RUTA_CESPED_DEFECTO)
		print("[CespedController] Material Cesped.tres guardado y propagado al mapa.")


## Lee los valores actuales del shader para sincronizar los deslizadores
func _sincronizar_desde_material() -> void:
	if not is_inside_tree():
		return
	var mat: ShaderMaterial = _obtener_material()
	if not mat:
		return

	var v
	v = mat.get_shader_parameter("dirt_blend_amount")
	if v != null: mezcla_tierra = float(v)

	v = mat.get_shader_parameter("wetness")
	if v != null: humedad_suelo = float(v)

	v = mat.get_shader_parameter("grass_state")
	if v != null: estado_secado = float(v)

	v = mat.get_shader_parameter("variation_strength")
	if v != null: variacion_color = float(v)

	v = mat.get_shader_parameter("wind_strength")
	if v != null: fuerza_viento = float(v)

	v = mat.get_shader_parameter("wind_speed")
	if v != null: velocidad_viento = float(v)

	v = mat.get_shader_parameter("wear_amount")
	if v != null: desgaste_huellas = float(v)

	v = mat.get_shader_parameter("road_edge_enabled")
	if v != null: activar_borde_carretera = bool(v)

	v = mat.get_shader_parameter("road_edge_dirt_intensity")
	if v != null: tierra_en_orilla = float(v)

	v = mat.get_shader_parameter("road_edge_width")
	if v != null: ancho_orilla_tierra = float(v)

	v = mat.get_shader_parameter("quality_level")
	if v != null: nivel_calidad = int(v)


# ------------------------------------------------------------------------------
# APLICACIÓN DE MODOS REALISTAS RÁPIDOS
# ------------------------------------------------------------------------------
func _aplicar_modo(modo: ModoPreset) -> void:
	if not is_inside_tree():
		return
	if modo == ModoPreset.PERSONALIZADO:
		return

	var mat: ShaderMaterial = _obtener_material()
	if not mat:
		return

	match modo:
		ModoPreset.PRADO_VERDE:
			self.humedad_suelo = 0.05
			self.estado_secado = 0.0
			self.mezcla_tierra = 0.15
			self.variacion_color = 0.35
			self.fuerza_viento = 0.20

		ModoPreset.CAMPO_RURAL:
			self.humedad_suelo = 0.0
			self.estado_secado = 0.70
			self.mezcla_tierra = 0.35
			self.variacion_color = 0.50
			self.fuerza_viento = 0.25

		ModoPreset.SABANA_SECA:
			self.humedad_suelo = 0.0
			self.estado_secado = 2.10
			self.mezcla_tierra = 0.45
			self.variacion_color = 0.55
			self.fuerza_viento = 0.30

		ModoPreset.LLUVIA_BARRO:
			self.humedad_suelo = 0.85
			self.estado_secado = 0.15
			self.mezcla_tierra = 0.50
			self.variacion_color = 0.40
			self.fuerza_viento = 0.45

		ModoPreset.ORILLA_CARRETERA:
			self.humedad_suelo = 0.0
			self.estado_secado = 0.85
			self.mezcla_tierra = 0.40
			self.variacion_color = 0.50
			self.activar_borde_carretera = true
			self.tierra_en_orilla = 0.95
			self.ancho_orilla_tierra = 0.20
			self.fuerza_viento = 0.25

	_forzar_guardado()
	notify_property_list_changed()


# ------------------------------------------------------------------------------
# MÉTODOS EN ESPAÑOL PARA USAR DESDE OTROS SCRIPTS
# ------------------------------------------------------------------------------
func cambiar_humedad(valor: float) -> void: self.humedad_suelo = valor
func cambiar_secado(valor: float) -> void: self.estado_secado = valor
func cambiar_tierra(valor: float) -> void: self.mezcla_tierra = valor
func cambiar_variacion(valor: float) -> void: self.variacion_color = valor
func cambiar_viento(fuerza: float) -> void: self.fuerza_viento = fuerza
func cambiar_calidad(calidad: int) -> void: self.nivel_calidad = calidad
