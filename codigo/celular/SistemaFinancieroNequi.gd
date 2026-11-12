# ════════════════════════════════════════════════════════════════════════════════
# SistemaFinancieroNequi.gd — Motor Financiero Nequi (Préstamos por Días Reales,
# Cuotas Diarias, Días de Mora, Score Crediticio y Mejoramiento Financiero)
# Panter Studio | Nuestra Tierra Job Simulator (Godot 4.7)
# ════════════════════════════════════════════════════════════════════════════════
extends RefCounted
class_name SistemaFinancieroNequi

const SAVE_PATH: String = "user://banco_nt.cfg"
const SEGUNDOS_POR_DIA_REAL: int = 86400

## Formatea cualquier cifra en pesos sin el sufijo "COP" (ej: "$ 100.000")
static func formatear_pesos(valor: float) -> String:
	var negativo: bool = valor < 0.0
	var entero: int = int(round(absf(valor)))
	var texto: String = str(entero)
	var longitud: int = texto.length()
	var formateado: String = ""

	for i in range(longitud):
		var pos_desde_derecha: int = longitud - 1 - i
		formateado = texto[pos_desde_derecha] + formateado
		if i < longitud - 1 and (i + 1) % 3 == 0:
			formateado = "." + formateado

	return ("- $ " if negativo else "$ ") + formateado

## Obtiene la marca de fecha y hora real actual (DD/MM HH:MM)
static func obtener_fecha_hora_actual() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%02d/%02d %02d:%02d" % [
		int(dt.get("day", 1)),
		int(dt.get("month", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0))
	]

## Obtiene el índice de día calendario real desde Unix Epoch (UTC-5 Colombia)
static func obtener_dia_calendario_real() -> int:
	var unix_col: int = int(Time.get_unix_time_from_system()) - (5 * 3600)
	return int(floor(float(unix_col) / float(SEGUNDOS_POR_DIA_REAL)))

## Calcula el cupo máximo de libre inversión según el Score Financiero y los días de mora acumulados
static func calcular_cupo_maximo(score: int, dias_mora_historicos: int) -> float:
	var cupo_base: float = 100000.0
	if score >= 800:
		cupo_base = 3500000.0
	elif score >= 700:
		cupo_base = 1500000.0
	elif score >= 600:
		cupo_base = 600000.0
	elif score >= 500:
		cupo_base = 250000.0
	elif score >= 400:
		cupo_base = 100000.0
	else:
		cupo_base = 50000.0

	# Penalización progresiva por días de mora acumulados (reduce 12% por cada día de mora sin sanear)
	var factor_mora: float = clampf(1.0 - (float(dias_mora_historicos) * 0.12), 0.20, 1.0)
	var cupo_final: float = round(cupo_base * factor_mora / 10000.0) * 10000.0
	return maxf(cupo_final, 20000.0)

## Evalúa el estado de días reales transcurridos y actualiza las cuotas pendientes y días de mora
static func evaluar_mora_dias_reales(estado_prestamo: Dictionary) -> Dictionary:
	if not estado_prestamo.get("activo", false):
		return {"nuevos_dias_mora": 0, "cuota_hoy_pendiente": false}

	var dia_actual: int = obtener_dia_calendario_real()
	var dia_inicio: int = int(estado_prestamo.get("dia_real_inicio", dia_actual))
	var ultimo_dia_evaluado: int = int(estado_prestamo.get("ultimo_dia_evaluado", dia_inicio))
	var cuotas_pagadas: int = int(estado_prestamo.get("cuotas_pagadas", 0))
	var plazo_dias: int = max(int(estado_prestamo.get("plazo_dias", 10)), 1)

	var dias_transcurridos_desde_inicio: int = max(0, dia_actual - dia_inicio)
	# Cuotas que ya deberían estar cubiertas al cierre del día anterior
	var cuotas_exigibles_ayer: int = clampi(dias_transcurridos_desde_inicio, 0, plazo_dias)
	var nuevos_mora: int = 0

	if dia_actual > ultimo_dia_evaluado:
		var deficit_cuotas: int = max(0, cuotas_exigibles_ayer - cuotas_pagadas)
		if deficit_cuotas > 0:
			var dias_sin_evaluar: int = dia_actual - ultimo_dia_evaluado
			nuevos_mora = mini(deficit_cuotas, dias_sin_evaluar)
			estado_prestamo["dias_mora_actuales"] = int(estado_prestamo.get("dias_mora_actuales", 0)) + nuevos_mora
			estado_prestamo["dias_mora_historicos"] = int(estado_prestamo.get("dias_mora_historicos", 0)) + nuevos_mora
			estado_prestamo["score_financiero"] = clampi(int(estado_prestamo.get("score_financiero", 500)) - (nuevos_mora * 25), 300, 850)
		estado_prestamo["ultimo_dia_evaluado"] = dia_actual

	var ultimo_dia_pago: int = int(estado_prestamo.get("ultimo_dia_pago", -1))
	var cuota_hoy_pendiente: bool = (ultimo_dia_pago < dia_actual) and (cuotas_pagadas < plazo_dias)

	return {
		"nuevos_dias_mora": nuevos_mora,
		"cuota_hoy_pendiente": cuota_hoy_pendiente,
		"dias_mora_actuales": int(estado_prestamo.get("dias_mora_actuales", 0))
	}
