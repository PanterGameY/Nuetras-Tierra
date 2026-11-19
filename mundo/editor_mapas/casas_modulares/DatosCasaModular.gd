class_name DatosCasaModular
extends RefCounted

## DatosCasaModular.gd — Catálogos, presets arquitectónicos y esquema de configuración
## para el Sistema de Creación de Casas Modular de Nuestra Tierra 2.0.

const MATERIALES_FACHADA: Array[Dictionary] = [
	{"id": 0, "nombre": "Estuco Liso", "tintable": true},
	{"id": 1, "nombre": "Pañete Rústico / Bahareque", "tintable": true},
	{"id": 2, "nombre": "Ladrillo a la Vista", "tintable": false},
	{"id": 3, "nombre": "Ladrillo Pintado", "tintable": true},
	{"id": 4, "nombre": "Concreto Visto", "tintable": true},
	{"id": 5, "nombre": "Madera Horizontal", "tintable": true},
	{"id": 6, "nombre": "Madera Tablón Rústico", "tintable": false},
	{"id": 7, "nombre": "Piedra Laja Andina", "tintable": false},
	{"id": 8, "nombre": "Piedra Sillar Colonial", "tintable": true},
	{"id": 9, "nombre": "Mármol / Travertino", "tintable": true},
	{"id": 10, "nombre": "Paneles Ranurados", "tintable": true},
	{"id": 11, "nombre": "Guadua / Bambú", "tintable": false},
	{"id": 12, "nombre": "Lámina Acanalada", "tintable": true},
	{"id": 13, "nombre": "Graniplast Texturizado", "tintable": true},
	{"id": 14, "nombre": "Cerámica Exterior", "tintable": true},
	{"id": 15, "nombre": "Zócalo Concreto Base", "tintable": true},
]

const ESTILOS_VENTANA: Array[Dictionary] = [
	{"id": 0, "nombre": "Colonial con Postigos"},
	{"id": 1, "nombre": "Colonial Reja Forjada"},
	{"id": 2, "nombre": "Moderna Minimalista"},
	{"id": 3, "nombre": "Ventanal Piso-Techo"},
	{"id": 4, "nombre": "Barrio con Reja Seguridad"},
	{"id": 5, "nombre": "Celosía Aluminio"},
	{"id": 6, "nombre": "Arco Colonial"},
	{"id": 7, "nombre": "Industrial Loft"},
	{"id": 8, "nombre": "Tradicional Paisa"},
	{"id": 9, "nombre": "Clásica con Montante"},
	{"id": 10, "nombre": "Ventila / Baño Alta"},
	{"id": 11, "nombre": "Vitrina Comercial"},
	{"id": 12, "nombre": "Circular Ojo de Buey"},
	{"id": 13, "nombre": "Panorámica Horizontal"},
	{"id": 14, "nombre": "Madera Rústica Cabaña"},
	{"id": 15, "nombre": "Muro Cortina Cristal"},
]

const ESTILOS_PUERTA: Array[Dictionary] = [
	{"id": 0, "nombre": "Colonial Tallada Doble"},
	{"id": 1, "nombre": "Tradicional Paisa Postigo"},
	{"id": 2, "nombre": "Moderna Madera y Vidrio"},
	{"id": 3, "nombre": "Minimalista Pivotante"},
	{"id": 4, "nombre": "Residencial con Reja"},
	{"id": 5, "nombre": "Vidrio Doble Comercial"},
	{"id": 6, "nombre": "Cortina Santamaría"},
	{"id": 7, "nombre": "Garaje Seccional Moderno"},
	{"id": 8, "nombre": "Portón Madera Hacienda"},
	{"id": 9, "nombre": "Arco Colonial Antigua"},
	{"id": 10, "nombre": "Rústica de Tablones"},
	{"id": 11, "nombre": "Metálica Económica"},
	{"id": 12, "nombre": "Clásica con Montante"},
	{"id": 13, "nombre": "Corrediza de Cristal"},
	{"id": 14, "nombre": "Portón Barrio Metálico"},
	{"id": 15, "nombre": "Hierro Forjado y Cristal"},
]

const MATERIALES_TECHO: Array[Dictionary] = [
	{"id": 0, "nombre": "Teja de Barro Colonial", "tintable": false},
	{"id": 1, "nombre": "Teja de Barro Antigua", "tintable": false},
	{"id": 2, "nombre": "Shingle Asfáltico Oscuro", "tintable": false},
	{"id": 3, "nombre": "Teja de Zinc / Eternit", "tintable": true},
	{"id": 4, "nombre": "Lámina Standing Seam", "tintable": true},
	{"id": 5, "nombre": "Losa de Concreto", "tintable": true},
	{"id": 6, "nombre": "Paja / Palma Tropical", "tintable": false},
	{"id": 7, "nombre": "Pizarra Negra", "tintable": false},
	{"id": 8, "nombre": "Policarbonato Pérgola", "tintable": true},
	{"id": 9, "nombre": "Deck de Madera", "tintable": false},
	{"id": 10, "nombre": "Baldosa Roja Azotea", "tintable": false},
	{"id": 11, "nombre": "Adoquín / Piedra", "tintable": false},
	{"id": 12, "nombre": "Concreto Pulido", "tintable": true},
	{"id": 13, "nombre": "Teja Esmaltada", "tintable": true},
	{"id": 14, "nombre": "Grava de Azotea", "tintable": false},
	{"id": 15, "nombre": "Cielorraso Madera", "tintable": false},
]

const CATEGORIAS_CONSTRUCCION: Array[Dictionary] = [
	{"id": "casa", "nombre": "Casas"},
	{"id": "edificio", "nombre": "Edificios"},
	{"id": "industria", "nombre": "Industrias"},
	{"id": "conjunto", "nombre": "Conjuntos"},
	{"id": "comercial", "nombre": "Comercial"},
]

const TIPOS_TECHO: Array[Dictionary] = [
	{"id": "dos_aguas", "nombre": "Dos Aguas"},
	{"id": "cuatro_aguas", "nombre": "Cuatro Aguas"},
	{"id": "plano", "nombre": "Plano / Azotea"},
	{"id": "un_agua", "nombre": "Inclinado (1 Agua)"},
	{"id": "mansarda", "nombre": "Mansarda / Clásico"},
	{"id": "diente_sierra", "nombre": "Diente de Sierra (Industrial)"},
	{"id": "boveda", "nombre": "Bóveda / Hangar Curvo"},
]

const TIPOS_BALCON: Array[Dictionary] = [
	{"id": "madera", "nombre": "Madera Paisa"},
	{"id": "hierro", "nombre": "Hierro Forjado"},
	{"id": "vidrio", "nombre": "Vidrio Moderno"},
	{"id": "concreto", "nombre": "Muro / Concreto"},
]

const FORMAS_CASA: Array[Dictionary] = [
	{"id": "rectangular", "nombre": "Rectangular Clásica"},
	{"id": "voladizo", "nombre": "Voladizo Moderno"},
	{"id": "escalonada", "nombre": "Escalonada / Terraza"},
]

const PALETA_COLORES_FACHADA: Array[Dictionary] = [
	{"nombre": "Blanco Hueso", "color": Color(0.86, 0.85, 0.81)},
	{"nombre": "Crema Piedra", "color": Color(0.82, 0.78, 0.69)},
	{"nombre": "Ocre Apagado", "color": Color(0.74, 0.63, 0.44)},
	{"nombre": "Terracota Quemado", "color": Color(0.64, 0.40, 0.33)},
	{"nombre": "Azul Pizarra", "color": Color(0.36, 0.48, 0.58)},
	{"nombre": "Verde Salvia", "color": Color(0.42, 0.54, 0.46)},
	{"nombre": "Rosa Tierra", "color": Color(0.68, 0.52, 0.52)},
	{"nombre": "Gris Concreto", "color": Color(0.52, 0.54, 0.56)},
	{"nombre": "Grafito Oscuro", "color": Color(0.24, 0.25, 0.28)},
	{"nombre": "Arena Natural", "color": Color(0.71, 0.66, 0.58)},
	{"nombre": "Natural (Sin Tinte)", "color": Color(1.0, 1.0, 1.0)},
]

const PALETA_COLORES_ACENTO: Array[Dictionary] = [
	{"nombre": "Madera Nogal", "color": Color(0.35, 0.23, 0.15)},
	{"nombre": "Verde Bosque", "color": Color(0.20, 0.36, 0.26)},
	{"nombre": "Azul Colonial", "color": Color(0.19, 0.31, 0.44)},
	{"nombre": "Rojo Ladrillo", "color": Color(0.50, 0.22, 0.19)},
	{"nombre": "Blanco Marfil", "color": Color(0.84, 0.84, 0.82)},
	{"nombre": "Negro Carbón", "color": Color(0.16, 0.17, 0.19)},
	{"nombre": "Café Roble", "color": Color(0.46, 0.32, 0.20)},
	{"nombre": "Bronce Envejecido", "color": Color(0.56, 0.44, 0.26)},
]

static func crear_config_defecto() -> Dictionary:
	return {
		"preset": "colonial_paisa",
		"ancho": 9.0,
		"fondo": 8.0,
		"pisos": 2,
		"altura_piso": 3.0,
		"altura_zocalo": 0.45,
		"forma": "rectangular",

		# Fachada y colores
		"mat_fachada": 0,
		"color_fachada": "#f0ede6",
		"usar_mat_piso1": true,
		"mat_piso1": 1,
		"color_piso1": "#f0ede6",
		"mat_zocalo": 15,
		"color_zocalo": "#9e382e",
		"color_molduras": "#e8e3d9",
		"escala_textura": 0.35,

		# Puertas y garaje
		"tipo_puerta": 1,
		"color_puerta": "#2e754c",
		"pos_puerta": "centro", # izquierda, centro, derecha
		"puerta_doble": false,
		"tiene_garaje": false,
		"tipo_garaje": 6,
		"color_garaje": "#5a6068",

		# Ventanas
		"tipo_ventana_p1": 8,
		"tipo_ventana_sup": 0,
		"color_ventanas": "#2e754c",
		"ventanas_frente": 2,
		"ventanas_lados": 2,
		"ventanas_atras": 2,
		"escala_ventana": 1.0,
		"luz_nocturna": false,
		"intensidad_luz": 0.65,

		# Techo
		"tipo_techo": "dos_aguas",
		"mat_techo": 0,
		"color_techo": "#ffffff",
		"pendiente_techo": 24.0,
		"alero": 0.65,

		# Detalles modulares
		"tiene_balcon": true,
		"tipo_balcon": "madera",
		"color_balcon": "#6b4024",
		"tiene_porche": false,
		"color_porche": "#6b4024",
		"tiene_escaleras": true,
		"tiene_toldo": false,
		"color_toldo": "#c94038",
		"tiene_chimenea": false,
		"detalles_azotea": false,
		"tiene_jardineras": true,
		"tiene_pilastras": true,

		# Expansión Edificios, Industrias, Conjuntos y Comercial
		"categoria": "casa",
		"modulos_conjunto": 1,
		"tiene_porteria": false,
		"tiene_marquesina": false,
		"muelles_carga": 0,
		"silos_laterales": 0,
		"tiene_chimenea_ind": false,
		"unidades_hvac": 0,
		"tiene_domos": false,
		"tiene_antena": false,
		"tiene_paneles_solares": false,
		"tiene_totem": false,
		"color_totem": "#4b6478",
	}

static func obtener_presets() -> Array[Dictionary]:
	return [
		{
			"id": "colonial_paisa",
			"nombre": "Casa Pueblo Paisa",
			"desc": "Balcón de madera, zócalo vivo y teja de barro.",
			"config": crear_config_defecto()
		},
		{
			"id": "hacienda_cafetera",
			"nombre": "Hacienda Cafetera",
			"desc": "Amplia casona rural con corredor frontal y guadua.",
			"config": _merge(crear_config_defecto(), {
				"preset": "hacienda_cafetera",
				"ancho": 14.0, "fondo": 10.0, "pisos": 2, "altura_piso": 3.2, "altura_zocalo": 0.6,
				"mat_fachada": 1, "color_fachada": "#f5f0e1",
				"usar_mat_piso1": true, "mat_piso1": 11, "color_piso1": "#ffffff",
				"mat_zocalo": 7, "color_zocalo": "#ffffff",
				"tipo_puerta": 0, "color_puerta": "#6e3f22", "puerta_doble": true,
				"tipo_ventana_p1": 0, "tipo_ventana_sup": 0, "color_ventanas": "#245c3c",
				"ventanas_frente": 4, "ventanas_lados": 3,
				"tipo_techo": "cuatro_aguas", "mat_techo": 0, "alero": 1.1, "pendiente_techo": 22.0,
				"tiene_balcon": true, "tipo_balcon": "madera", "tiene_porche": true, "tiene_jardineras": true
			})
		},
		{
			"id": "barrio_latam",
			"nombre": "Casa de Barrio LATAM",
			"desc": "Ladrillo/estuco, rejas de seguridad y terraza con tanque.",
			"config": _merge(crear_config_defecto(), {
				"preset": "barrio_latam",
				"ancho": 8.0, "fondo": 10.0, "pisos": 2, "altura_piso": 2.9, "altura_zocalo": 0.25,
				"mat_fachada": 0, "color_fachada": "#e8b458",
				"usar_mat_piso1": true, "mat_piso1": 2, "color_piso1": "#ffffff",
				"mat_zocalo": 15, "color_zocalo": "#75787d",
				"tipo_puerta": 4, "color_puerta": "#3b3f45", "pos_puerta": "izquierda",
				"tiene_garaje": true, "tipo_garaje": 14, "color_garaje": "#454a52",
				"tipo_ventana_p1": 4, "tipo_ventana_sup": 4, "color_ventanas": "#d9dde2",
				"ventanas_frente": 2, "ventanas_lados": 1,
				"tipo_techo": "plano", "mat_techo": 10, "color_techo": "#ffffff", "alero": 0.15,
				"tiene_balcon": true, "tipo_balcon": "hierro", "color_balcon": "#2b2d30",
				"detalles_azotea": true, "tiene_jardineras": false, "tiene_pilastras": false
			})
		},
		{
			"id": "moderna_minimalista",
			"nombre": "Casa Moderna Minimalista",
			"desc": "Voladizo cúbico, ventanales amplios, concreto y madera.",
			"config": _merge(crear_config_defecto(), {
				"preset": "moderna_minimalista",
				"ancho": 11.0, "fondo": 9.5, "pisos": 2, "altura_piso": 3.3, "altura_zocalo": 0.2,
				"forma": "voladizo",
				"mat_fachada": 0, "color_fachada": "#ebedf0",
				"usar_mat_piso1": true, "mat_piso1": 4, "color_piso1": "#9fa4ab",
				"mat_zocalo": 4, "color_zocalo": "#54585e", "color_molduras": "#2b2e33",
				"tipo_puerta": 3, "color_puerta": "#3a322c", "pos_puerta": "centro",
				"tiene_garaje": true, "tipo_garaje": 7, "color_garaje": "#383c42",
				"tipo_ventana_p1": 3, "tipo_ventana_sup": 3, "color_ventanas": "#1f2226",
				"ventanas_frente": 2, "ventanas_lados": 2, "escala_ventana": 1.25,
				"tipo_techo": "plano", "mat_techo": 5, "color_techo": "#70757d", "alero": 0.45,
				"tiene_balcon": true, "tipo_balcon": "vidrio", "color_balcon": "#22252a",
				"tiene_jardineras": false, "tiene_pilastras": false, "tiene_escaleras": false
			})
		},
		{
			"id": "chalet_campestre",
			"nombre": "Chalet / Cabaña Campestre",
			"desc": "Techo inclinado a dos aguas, madera rústica, piedra y chimenea.",
			"config": _merge(crear_config_defecto(), {
				"preset": "chalet_campestre",
				"ancho": 9.5, "fondo": 9.0, "pisos": 2, "altura_piso": 2.9, "altura_zocalo": 0.65,
				"mat_fachada": 5, "color_fachada": "#9c673b",
				"usar_mat_piso1": true, "mat_piso1": 7, "color_piso1": "#ffffff",
				"mat_zocalo": 7, "color_zocalo": "#ffffff",
				"tipo_puerta": 10, "color_puerta": "#754724",
				"tipo_ventana_p1": 14, "tipo_ventana_sup": 14, "color_ventanas": "#5e381c",
				"tipo_techo": "dos_aguas", "mat_techo": 2, "pendiente_techo": 38.0, "alero": 0.85,
				"tiene_balcon": true, "tipo_balcon": "madera", "tiene_porche": true,
				"tiene_chimenea": true, "tiene_jardineras": true
			})
		},
		{
			"id": "republicana_antigua",
			"nombre": "Casona Antigua Republicana",
			"desc": "Arcos coloniales, cornisas, pilastras y hierro forjado.",
			"config": _merge(crear_config_defecto(), {
				"preset": "republicana_antigua",
				"ancho": 12.0, "fondo": 9.5, "pisos": 2, "altura_piso": 3.5, "altura_zocalo": 0.55,
				"mat_fachada": 8, "color_fachada": "#ebd8b7",
				"usar_mat_piso1": false, "mat_zocalo": 8, "color_zocalo": "#c9b38f",
				"color_molduras": "#f7f3eb",
				"tipo_puerta": 9, "color_puerta": "#63381e", "puerta_doble": true,
				"tipo_ventana_p1": 6, "tipo_ventana_sup": 6, "color_ventanas": "#5c361d",
				"ventanas_frente": 3, "ventanas_lados": 2,
				"tipo_techo": "cuatro_aguas", "mat_techo": 1, "pendiente_techo": 24.0, "alero": 0.75,
				"tiene_balcon": true, "tipo_balcon": "hierro", "color_balcon": "#1f2124",
				"tiene_pilastras": true, "tiene_jardineras": false
			})
		},
		{
			"id": "tienda_barrio",
			"nombre": "Tienda / Local Esquinero",
			"desc": "Primer piso comercial con santamaría y toldo; arriba vivienda.",
			"config": _merge(crear_config_defecto(), {
				"preset": "tienda_barrio",
				"ancho": 9.0, "fondo": 8.5, "pisos": 2, "altura_piso": 3.1, "altura_zocalo": 0.15,
				"mat_fachada": 0, "color_fachada": "#f2efe9",
				"usar_mat_piso1": true, "mat_piso1": 14, "color_piso1": "#487ab5",
				"tipo_puerta": 5, "color_puerta": "#d9dde2", "pos_puerta": "izquierda",
				"tiene_garaje": true, "tipo_garaje": 6, "color_garaje": "#3c6e9e",
				"tipo_ventana_p1": 11, "tipo_ventana_sup": 4, "color_ventanas": "#d9dde2",
				"ventanas_frente": 2, "escala_ventana": 1.15,
				"tipo_techo": "plano", "mat_techo": 5, "alero": 0.2,
				"tiene_balcon": true, "tipo_balcon": "hierro", "tiene_toldo": true, "color_toldo": "#c93b32",
				"detalles_azotea": true, "tiene_escaleras": false
			})
		},
		{
			"id": "edificio_apartamentos",
			"nombre": "Edificio Apartamentos",
			"desc": "Bloque residencial multifamiliar de 4 pisos con balcones.",
			"config": _merge(crear_config_defecto(), {
				"preset": "edificio_apartamentos",
				"ancho": 13.0, "fondo": 11.0, "pisos": 4, "altura_piso": 2.95, "altura_zocalo": 0.35,
				"mat_fachada": 2, "color_fachada": "#ffffff",
				"usar_mat_piso1": true, "mat_piso1": 4, "color_piso1": "#8f949c",
				"tipo_puerta": 15, "color_puerta": "#22252a", "puerta_doble": true,
				"tipo_ventana_p1": 2, "tipo_ventana_sup": 2, "color_ventanas": "#24272c",
				"ventanas_frente": 4, "ventanas_lados": 3, "ventanas_atras": 4,
				"tipo_techo": "plano", "mat_techo": 5, "alero": 0.25,
				"tiene_balcon": true, "tipo_balcon": "vidrio", "color_balcon": "#2a2d33",
				"detalles_azotea": true, "tiene_jardineras": false
			})
		},
		{
			"id": "casa_costena",
			"nombre": "Casa Caribeña / Costeña",
			"desc": "Colores alegres, celosías frescas, porche amplio y techo palma.",
			"config": _merge(crear_config_defecto(), {
				"preset": "casa_costena",
				"ancho": 10.0, "fondo": 8.0, "pisos": 1, "altura_piso": 3.3, "altura_zocalo": 0.35,
				"mat_fachada": 0, "color_fachada": "#4591c4",
				"usar_mat_piso1": false, "mat_zocalo": 0, "color_zocalo": "#f2f0eb",
				"color_molduras": "#ffffff",
				"tipo_puerta": 1, "color_puerta": "#e8a838",
				"tipo_ventana_p1": 5, "tipo_ventana_sup": 5, "color_ventanas": "#ffffff",
				"ventanas_frente": 2, "ventanas_lados": 2,
				"tipo_techo": "cuatro_aguas", "mat_techo": 6, "pendiente_techo": 26.0, "alero": 0.9,
				"tiene_balcon": false, "tiene_porche": true, "color_porche": "#f2f0eb"
			})
		},
		{
			"id": "casa_industrial_loft",
			"nombre": "Loft Industrial Urbano",
			"desc": "Ladrillo visto, ventanales cuadriculados y cubierta inclinada.",
			"config": _merge(crear_config_defecto(), {
				"preset": "casa_industrial_loft",
				"ancho": 9.5, "fondo": 9.0, "pisos": 2, "altura_piso": 3.4, "altura_zocalo": 0.3,
				"mat_fachada": 2, "color_fachada": "#ffffff",
				"usar_mat_piso1": false, "mat_zocalo": 4, "color_zocalo": "#404347",
				"color_molduras": "#1f2226",
				"tipo_puerta": 15, "color_puerta": "#1c1e22",
				"tipo_ventana_p1": 7, "tipo_ventana_sup": 7, "color_ventanas": "#1a1c20",
				"ventanas_frente": 2, "escala_ventana": 1.2,
				"tipo_techo": "un_agua", "mat_techo": 4, "color_techo": "#363a40", "pendiente_techo": 14.0, "alero": 0.4,
				"tiene_balcon": true, "tipo_balcon": "hierro", "color_balcon": "#1c1e22",
				"tiene_jardineras": false
			})
		},
		# ── EDIFICIOS ──
		{
			"id": "edificio_apartamentos_moderno",
			"nombre": "Torre Apartamentos Ladrillo",
			"desc": "Edificio residencial de 6 pisos con balcones, lobby y antena.",
			"config": _merge(crear_config_defecto(), {
				"preset": "edificio_apartamentos_moderno", "categoria": "edificio",
				"ancho": 16.0, "fondo": 12.0, "pisos": 6, "altura_piso": 3.0, "altura_zocalo": 0.4,
				"mat_fachada": 2, "color_fachada": "#ffffff",
				"usar_mat_piso1": true, "mat_piso1": 4, "color_piso1": "#85898f",
				"color_molduras": "#d6d3cb",
				"tipo_puerta": 5, "color_puerta": "#24282e", "puerta_doble": true,
				"tipo_ventana_p1": 3, "tipo_ventana_sup": 2, "color_ventanas": "#24272c",
				"ventanas_frente": 4, "ventanas_lados": 3, "ventanas_atras": 4,
				"tipo_techo": "plano", "mat_techo": 5, "alero": 0.25,
				"tiene_balcon": true, "tipo_balcon": "vidrio", "color_balcon": "#26292e",
				"tiene_marquesina": true, "detalles_azotea": true, "unidades_hvac": 2, "tiene_antena": true,
				"tiene_jardineras": false, "tiene_pilastras": true
			})
		},
		{
			"id": "torre_corporativa",
			"nombre": "Torre Corporativa Cristal",
			"desc": "Edificio de oficinas de 9 pisos con muro cortina y lobby.",
			"config": _merge(crear_config_defecto(), {
				"preset": "torre_corporativa", "categoria": "edificio",
				"ancho": 18.0, "fondo": 16.0, "pisos": 9, "altura_piso": 3.3, "altura_zocalo": 0.35,
				"mat_fachada": 10, "color_fachada": "#606870",
				"usar_mat_piso1": true, "mat_piso1": 9, "color_piso1": "#454a50",
				"color_molduras": "#2b2f36",
				"tipo_puerta": 5, "color_puerta": "#1c2026", "puerta_doble": true,
				"tipo_ventana_p1": 15, "tipo_ventana_sup": 15, "color_ventanas": "#1e2329",
				"ventanas_frente": 5, "ventanas_lados": 4, "ventanas_atras": 5, "escala_ventana": 1.35,
				"tipo_techo": "plano", "mat_techo": 14, "alero": 0.20,
				"tiene_balcon": false, "tiene_marquesina": true, "unidades_hvac": 4,
				"tiene_antena": true, "tiene_paneles_solares": true, "tiene_jardineras": false
			})
		},
		# ── INDUSTRIAS ──
		{
			"id": "bodega_logistica",
			"nombre": "Bodega Logística 4G",
			"desc": "Centro de distribución con muelles de carga, rampas y paneles.",
			"config": _merge(crear_config_defecto(), {
				"preset": "bodega_logistica", "categoria": "industria",
				"ancho": 24.0, "fondo": 18.0, "pisos": 1, "altura_piso": 6.5, "altura_zocalo": 1.1,
				"mat_fachada": 12, "color_fachada": "#9da3ab",
				"usar_mat_piso1": false, "mat_zocalo": 4, "color_zocalo": "#63676e",
				"color_molduras": "#2e343b",
				"tipo_puerta": 11, "color_puerta": "#32373d", "pos_puerta": "izquierda",
				"tipo_ventana_p1": 10, "tipo_ventana_sup": 10, "color_ventanas": "#2c3138",
				"ventanas_frente": 2, "ventanas_lados": 4, "ventanas_atras": 0,
				"tipo_techo": "boveda", "mat_techo": 3, "color_techo": "#a8aeb5", "pendiente_techo": 16.0, "alero": 0.5,
				"tiene_balcon": false, "tiene_jardineras": false, "tiene_escaleras": true,
				"muelles_carga": 3, "unidades_hvac": 3, "tiene_paneles_solares": true
			})
		},
		{
			"id": "planta_industrial",
			"nombre": "Planta Industrial y Silos",
			"desc": "Fábrica con cubierta diente de sierra, silos y chimenea.",
			"config": _merge(crear_config_defecto(), {
				"preset": "planta_industrial", "categoria": "industria",
				"ancho": 22.0, "fondo": 16.0, "pisos": 1, "altura_piso": 6.2, "altura_zocalo": 0.6,
				"mat_fachada": 4, "color_fachada": "#7a7e85",
				"usar_mat_piso1": false, "mat_zocalo": 4, "color_zocalo": "#4d5057",
				"color_molduras": "#34373d",
				"tipo_puerta": 6, "color_puerta": "#3c424a", "pos_puerta": "izquierda",
				"tiene_garaje": true, "tipo_garaje": 6, "color_garaje": "#484e57",
				"tipo_ventana_p1": 7, "tipo_ventana_sup": 7, "color_ventanas": "#24282e",
				"ventanas_frente": 2, "ventanas_lados": 4, "ventanas_atras": 3,
				"tipo_techo": "diente_sierra", "mat_techo": 3, "color_techo": "#828890", "pendiente_techo": 22.0, "alero": 0.35,
				"tiene_balcon": false, "tiene_jardineras": false, "tiene_escaleras": false,
				"muelles_carga": 2, "silos_laterales": 3, "tiene_chimenea_ind": true, "unidades_hvac": 2
			})
		},
		# ── CONJUNTOS RESIDENCIALES ──
		{
			"id": "conjunto_adosado",
			"nombre": "Conjunto Casas Adosadas",
			"desc": "Hilera de 4 viviendas pareadas con portería y talanquera.",
			"config": _merge(crear_config_defecto(), {
				"preset": "conjunto_adosado", "categoria": "conjunto",
				"ancho": 7.0, "fondo": 8.5, "pisos": 2, "altura_piso": 2.9, "altura_zocalo": 0.35,
				"modulos_conjunto": 4, "tiene_porteria": true,
				"mat_fachada": 0, "color_fachada": "#d9d4c7",
				"usar_mat_piso1": true, "mat_piso1": 2, "color_piso1": "#ffffff",
				"mat_zocalo": 15, "color_zocalo": "#6b6e73",
				"color_molduras": "#cfcac0",
				"tipo_puerta": 2, "color_puerta": "#473222",
				"tipo_ventana_p1": 2, "tipo_ventana_sup": 2, "color_ventanas": "#2a2d32",
				"ventanas_frente": 2, "ventanas_lados": 1, "ventanas_atras": 2,
				"tipo_techo": "dos_aguas", "mat_techo": 0, "pendiente_techo": 20.0, "alero": 0.45,
				"tiene_balcon": true, "tipo_balcon": "hierro", "color_balcon": "#24272b",
				"tiene_jardineras": false, "tiene_pilastras": true
			})
		},
		{
			"id": "conjunto_torres",
			"nombre": "Conjunto Cerrado Torre",
			"desc": "Bloque residencial multifamiliar con portería de acceso.",
			"config": _merge(crear_config_defecto(), {
				"preset": "conjunto_torres", "categoria": "conjunto",
				"ancho": 14.0, "fondo": 11.0, "pisos": 5, "altura_piso": 2.9, "altura_zocalo": 0.35,
				"modulos_conjunto": 1, "tiene_porteria": true,
				"mat_fachada": 0, "color_fachada": "#cfc9bc",
				"usar_mat_piso1": true, "mat_piso1": 7, "color_piso1": "#ffffff",
				"color_molduras": "#87847d",
				"tipo_puerta": 15, "color_puerta": "#24272b", "puerta_doble": true,
				"tipo_ventana_p1": 2, "tipo_ventana_sup": 2, "color_ventanas": "#222529",
				"ventanas_frente": 4, "ventanas_lados": 2, "ventanas_atras": 4,
				"tipo_techo": "plano", "mat_techo": 5, "alero": 0.2,
				"tiene_balcon": true, "tipo_balcon": "vidrio", "color_balcon": "#26292e",
				"detalles_azotea": true, "tiene_paneles_solares": true, "tiene_jardineras": false
			})
		},
		# ── CENTROS COMERCIALES ──
		{
			"id": "centro_comercial",
			"nombre": "Centro Comercial Plaza",
			"desc": "Gran superficie con marquesina, domos, vitrinas, HVAC y tótem.",
			"config": _merge(crear_config_defecto(), {
				"preset": "centro_comercial", "categoria": "comercial",
				"ancho": 24.0, "fondo": 18.0, "pisos": 2, "altura_piso": 4.2, "altura_zocalo": 0.3,
				"mat_fachada": 10, "color_fachada": "#b8b4aa",
				"usar_mat_piso1": true, "mat_piso1": 9, "color_piso1": "#7d7970",
				"color_molduras": "#2b2f36",
				"tipo_puerta": 5, "color_puerta": "#22262b", "puerta_doble": true,
				"tipo_ventana_p1": 11, "tipo_ventana_sup": 13, "color_ventanas": "#23272d",
				"ventanas_frente": 4, "ventanas_lados": 3, "ventanas_atras": 1, "escala_ventana": 1.35,
				"tipo_techo": "plano", "mat_techo": 5, "alero": 0.4,
				"tiene_balcon": false, "tiene_marquesina": true, "tiene_domos": true,
				"unidades_hvac": 4, "tiene_paneles_solares": true, "tiene_totem": true,
				"color_totem": "#3b5266", "tiene_jardineras": false
			})
		},
		{
			"id": "supermercado_barrio",
			"nombre": "Supermercado / Mercado",
			"desc": "Nave comercial con bóveda, marquesina, muelle trasero y tótem.",
			"config": _merge(crear_config_defecto(), {
				"preset": "supermercado_barrio", "categoria": "comercial",
				"ancho": 18.0, "fondo": 15.0, "pisos": 1, "altura_piso": 5.0, "altura_zocalo": 0.25,
				"mat_fachada": 0, "color_fachada": "#d4cfc4",
				"usar_mat_piso1": false, "color_molduras": "#3a3e45",
				"tipo_puerta": 5, "color_puerta": "#23262b", "puerta_doble": true,
				"tipo_ventana_p1": 11, "tipo_ventana_sup": 11, "color_ventanas": "#24272c",
				"ventanas_frente": 4, "ventanas_lados": 2, "ventanas_atras": 0, "escala_ventana": 1.3,
				"tipo_techo": "boveda", "mat_techo": 4, "color_techo": "#4e545c", "pendiente_techo": 14.0, "alero": 0.5,
				"tiene_balcon": false, "tiene_marquesina": true, "unidades_hvac": 2,
				"muelles_carga": 1, "tiene_totem": true, "color_totem": "#7a3b32", "tiene_jardineras": false
			})
		},
	]

static func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in extra.keys():
		out[k] = extra[k]
	return out

static func normalizar_config(cfg: Dictionary) -> Dictionary:
	var out := crear_config_defecto()
	for k in cfg.keys():
		out[k] = cfg[k]
	out["ancho"] = clampf(float(out.get("ancho", 9.0)), 4.0, 36.0)
	out["fondo"] = clampf(float(out.get("fondo", 8.0)), 4.0, 30.0)
	out["pisos"] = clampi(int(out.get("pisos", 2)), 1, 12)
	out["altura_piso"] = clampf(float(out.get("altura_piso", 3.0)), 2.4, 7.5)
	out["altura_zocalo"] = clampf(float(out.get("altura_zocalo", 0.4)), 0.0, 1.4)
	out["pendiente_techo"] = clampf(float(out.get("pendiente_techo", 24.0)), 8.0, 48.0)
	out["alero"] = clampf(float(out.get("alero", 0.6)), 0.0, 1.5)
	out["escala_ventana"] = clampf(float(out.get("escala_ventana", 1.0)), 0.65, 1.45)
	out["modulos_conjunto"] = clampi(int(out.get("modulos_conjunto", 1)), 1, 5)
	out["muelles_carga"] = clampi(int(out.get("muelles_carga", 0)), 0, 5)
	out["silos_laterales"] = clampi(int(out.get("silos_laterales", 0)), 0, 4)
	out["unidades_hvac"] = clampi(int(out.get("unidades_hvac", 0)), 0, 6)
	return out

static func parsear_color(val, fallback: Color = Color.WHITE) -> Color:
	if val is Color:
		return val
	if val is String:
		return Color.from_string(val, fallback)
	if val is Array and val.size() >= 3:
		return Color(float(val[0]), float(val[1]), float(val[2]), float(val[3]) if val.size() >= 4 else 1.0)
	return fallback
