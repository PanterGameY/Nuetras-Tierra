extends Node
class_name GameDocumentationRef

# ═══════════════════════════════════════════════════════════════════════
# GameDocumentationRef.gd — Script de Referencias y Constantes del Juego
# Utilizado para proveer autocompletado y validaciones de datos del juego.
# ═══════════════════════════════════════════════════════════════════════

const CONFIG = {
	"nombre_juego": "Nuestra Tierra 2.0",
	"version": "3.0.0",
	"godot_version": "4.7.rc2"
}

# Coordenadas de los destinos para trabajos de mensajeria
const DESTINOS = {
	"MERCADO_CENTRAL": Vector3(12.0, 0.0, 80.0),
	"CENTRO_CIUDAD": Vector3(0.0, 1.5, -60.0),
	"GASOLINERA_NORTE": Vector3(-80.0, 0.0, 45.0),
	"TALLER_MECANICO": Vector3(-50.0, 0.0, -35.0),
	"POLICIA": Vector3(30.0, 0.0, -90.0)
}

# Formulas matematicas mapeadas
static func calcular_recompensa_trabajo(distancia: float) -> float:
	var base = 200.0
	var factor_distancia = 3.0
	return snapped(base + (distancia * factor_distancia), 1.0)

static func calcular_arrastre_aerodinamico(velocidad: float, coef_arrastre: float, area_frontal: float) -> float:
	var densidad_aire = 1.225
	return 0.5 * densidad_aire * velocidad * velocidad * coef_arrastre * area_frontal

static func calcular_resistencia_rodadura(res_rodadura: float, nivel_barro: float, nivel_mojado: float, masa: float) -> float:
	var crr = res_rodadura + (nivel_barro * 0.05) + (nivel_mojado * 0.008)
	var g = 9.81
	return crr * masa * g
