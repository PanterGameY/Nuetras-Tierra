extends Control
class_name MenuPersonalizacion

# ═══════════════════════════════════════════════════════════════════════
# MenuPersonalizacion — Controla la UI de la personalización avanzada
# ═══════════════════════════════════════════════════════════════════════

var taller_ref: Node = null
var customizer_ref: CustomizerComponent = null

@onready var tab_container: TabContainer = $PanelFondo/TabContainer

# Vista previa y Color Picker personalizado
@onready var color_preview: ColorRect = $PanelFondo/TabContainer/Pintura/VBoxPintura/ColorPreview
@onready var color_picker: ColorWheelPicker = $PanelFondo/TabContainer/Pintura/VBoxPintura/ColorPicker

# Botón y panel para colapsar la configuración de material
@onready var btn_configurar: Button = $PanelFondo/TabContainer/Pintura/VBoxPintura/BtnConfigurar
@onready var card_sliders: PanelContainer = $PanelFondo/TabContainer/Pintura/VBoxPintura/CardSliders

# Deslizadores de Material Principal
@onready var slider_metallic: HSlider = $PanelFondo/TabContainer/Pintura/VBoxPintura/CardSliders/VBoxSliders/SliderMetallic
@onready var slider_roughness: HSlider = $PanelFondo/TabContainer/Pintura/VBoxPintura/CardSliders/VBoxSliders/SliderRoughness
@onready var slider_specular: HSlider = $PanelFondo/TabContainer/Pintura/VBoxPintura/CardSliders/VBoxSliders/SliderSpecular

@onready var lbl_metallic: Label = $PanelFondo/TabContainer/Pintura/VBoxPintura/CardSliders/VBoxSliders/LabelMetallic
@onready var lbl_roughness: Label = $PanelFondo/TabContainer/Pintura/VBoxPintura/CardSliders/VBoxSliders/LabelRoughness
@onready var lbl_specular: Label = $PanelFondo/TabContainer/Pintura/VBoxPintura/CardSliders/VBoxSliders/LabelSpecular

# Botones de las pestañas personalizadas
@onready var btn_tab_pintura: Button = $PanelFondo/CustomTabBar/BtnTabPintura
@onready var btn_tab_skins: Button = $PanelFondo/CustomTabBar/BtnTabSkins
@onready var btn_tab_rines: Button = $PanelFondo/CustomTabBar/BtnTabRines

# Nuevos botones creados dinámicamente
var btn_tab_accesorios: Button
var btn_tab_placas: Button

@onready var container_skins: GridContainer = $PanelFondo/TabContainer/Skins/GridSkins
@onready var container_rines: GridContainer = $PanelFondo/TabContainer/Rines/GridRines

@onready var btn_guardar: Button = $PanelFondo/HBoxContainer/BtnGuardar
@onready var btn_cancelar: Button = $PanelFondo/HBoxContainer/BtnCancelar

# Nuevos ScrollContainers creados dinámicamente
var scroll_accesorios: ScrollContainer
var scroll_placas: ScrollContainer

# Nuevos controles para la personalización basada en objetos
var scroll_objetos: ScrollContainer = null
var vbox_objetos: VBoxContainer = null
var btn_volver_objetos: Button = null
var mesh_seleccionado_actual: MeshInstance3D = null
var materiales_mesh_seleccionado: Array = []
var index_material_seleccionado: int = -1
var container_materiales_objeto: VBoxContainer = null

# Nuevos sliders de control manual de cámara
var slider_cam_zoom: HSlider = null
var slider_cam_rot: HSlider = null
var slider_cam_alt: HSlider = null
var is_dragging_cam_slider: bool = false

# Nuevos controles para el menú de categorías principal
var container_menu_categorias: VBoxContainer = null
var btn_volver_menu_principal: Button = null

# Pintura selector de canales
var btn_canal_primario: Button
var btn_canal_secundario: Button
var canal_pintura_secundario: bool = false

# Controles de Accesorios (Vidrios / Neón)
var glass_opacity_slider: HSlider
var neon_toggle_btn: Button
var neon_intensity_slider: HSlider
var selected_glass_color: Color = Color.BLACK
var selected_neon_color: Color = Color.BLUE

# Controles de Rines
var r_metallic_slider: HSlider
var r_roughness_slider: HSlider

# Controles de Placas
var plate_text_input: LineEdit
var plate_city_input: LineEdit
var plate_type_btn: Button

# Presets de skins (Vinilos)
const SKINS_PRESET := [
	{"nombre": "Original", "path": ""},
	{"nombre": "Colombia Tricolor", "path": "res://recursos/texturas/skins/colombia_skin.png"},
	{"nombre": "Líneas Deportivas", "path": "res://recursos/texturas/skins/lineas_skin.png"}
]

# Presets de rines
const RINES_PRESET := ["original", "colombiano_cromado", "deportivo_aluminio"]

# Guardar estado original para cancelar
var color_original: Color
var color_seleccionado: Color = Color.WHITE

var color_sec_original: Color
var metallic_sec_original: float
var roughness_sec_original: float
var specular_sec_original: float

var glass_color_original: Color
var glass_opacity_original: float

var rims_color_original: Color
var rims_metallic_original: float
var rims_roughness_original: float
var rines_original: String

var neon_enabled_original: bool
var neon_color_original: Color
var neon_intensity_original: float

var plate_text_original: String
var plate_city_original: String
var plate_is_public_original: bool

var skin_original: String
var metallic_original: float
var roughness_original: float
var specular_original: float

# Estilos de pestañas
var style_active: StyleBoxFlat
var style_inactive: StyleBoxFlat = StyleBoxFlat.new()

var _grabber_textura: ImageTexture = null
var _snapshot_original: Dictionary = {}


func _ready() -> void:
	# Permitir que los clics en zonas vacías pasen a la zona de cámara orbital (hermana detrás en CanvasLayer)
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Crear textura de grabber circular premium
	_grabber_textura = _crear_textura_grabber(18, Color(0.12, 0.12, 0.16), Color(0.95, 0.8, 0.0))

	# Ajustar tamaños de letras de elementos nativos en la escena .tscn para que sean legibles
	# Glassmorphism para el panel de fondo principal (Automotive Cockpit)
	var main_panel = get_node_or_null("PanelFondo")
	if main_panel:
		var sb_main = StyleBoxFlat.new()
		sb_main.bg_color = Color(0.06, 0.07, 0.08, 0.92)
		for side in ["left", "top", "right", "bottom"]:
			sb_main.set("border_width_" + side, 1)
		sb_main.border_color = Color(0.78, 0.81, 0.85, 0.22)
		for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			sb_main.set("corner_radius_" + corner, 16)
		sb_main.shadow_color = Color(0, 0, 0, 0.55)
		sb_main.shadow_size = 20
		main_panel.add_theme_stylebox_override("panel", sb_main)

	# Ajustar tamaños de letras y sombreado premium del título
	if has_node("PanelFondo/Titulo"):
		var title = $PanelFondo/Titulo
		title.add_theme_font_size_override("font_size", 40)
		title.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
		title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		title.add_theme_constant_override("shadow_offset_x", 2)
		title.add_theme_constant_override("shadow_offset_y", 2)
	
	if lbl_metallic:
		lbl_metallic.add_theme_font_size_override("font_size", 22)
	if lbl_roughness:
		lbl_roughness.add_theme_font_size_override("font_size", 22)
	if lbl_specular:
		lbl_specular.add_theme_font_size_override("font_size", 22)
		
	if btn_configurar:
		btn_configurar.add_theme_font_size_override("font_size", 22)

	if btn_guardar:
		btn_guardar.pressed.connect(_on_guardar_pressed)
		btn_guardar.add_theme_font_size_override("font_size", 28)
		
		var sb_g = StyleBoxFlat.new()
		sb_g.bg_color = Color(0.88, 0.68, 0.28, 0.92)
		for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			sb_g.set("corner_radius_" + side, 12)
		sb_g.shadow_color = Color(0.88, 0.68, 0.28, 0.25)
		sb_g.shadow_size = 6
		
		var sb_g_h = sb_g.duplicate() as StyleBoxFlat
		sb_g_h.bg_color = Color(0.95, 0.76, 0.35, 1.0)
		sb_g_h.shadow_size = 10
		
		btn_guardar.add_theme_stylebox_override("normal", sb_g)
		btn_guardar.add_theme_stylebox_override("hover", sb_g_h)
		btn_guardar.add_theme_stylebox_override("pressed", sb_g)
		
	if btn_cancelar:
		btn_cancelar.pressed.connect(_on_cancelar_pressed)
		btn_cancelar.add_theme_font_size_override("font_size", 28)
		
		var sb_c = StyleBoxFlat.new()
		sb_c.bg_color = Color(0.08, 0.09, 0.11, 0.82)
		for side in ["left", "top", "right", "bottom"]:
			sb_c.set("border_width_" + side, 1)
		sb_c.border_color = Color(0.78, 0.28, 0.26, 0.95)
		for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			sb_c.set("corner_radius_" + side, 12)
			
		var sb_c_h = sb_c.duplicate() as StyleBoxFlat
		sb_c_h.bg_color = Color(0.18, 0.12, 0.15, 0.9)
		sb_c_h.border_color = Color(1.0, 0.3, 0.3, 1.0)
		
		btn_cancelar.add_theme_stylebox_override("normal", sb_c)
		btn_cancelar.add_theme_stylebox_override("hover", sb_c_h)
		
	if btn_tab_pintura:
		style_active = StyleBoxFlat.new()
		style_active.bg_color = Color(0.95, 0.8, 0.0, 0.12)
		style_active.border_width_bottom = 4
		style_active.border_color = Color(0.95, 0.8, 0.0, 1.0)
		for corner in ["top_left", "top_right"]:
			style_active.set("corner_radius_" + corner, 10)
		btn_tab_pintura.pressed.connect(func(): _cambiar_tab(0))
	if btn_tab_skins:
		btn_tab_skins.pressed.connect(func(): _cambiar_tab(1))
	if btn_tab_rines:
		btn_tab_rines.pressed.connect(func(): _cambiar_tab(2))
		
	if btn_configurar:
		btn_configurar.pressed.connect(_on_configurar_pressed)
		
	style_inactive.bg_color = Color(0, 0, 0, 0)
	style_inactive.border_width_bottom = 0

func configurar_taller(taller: Node, customizer: CustomizerComponent) -> void:
	taller_ref = taller
	customizer_ref = customizer
	if customizer and customizer.has_method("crear_snapshot"):
		_snapshot_original = customizer.crear_snapshot()
	
	# Respaldar originales para restaurar en caso de Cancelar
	color_original = customizer.color_actual
	color_seleccionado = customizer.color_actual
	metallic_original = customizer.metallic_actual
	roughness_original = customizer.roughness_actual
	specular_original = customizer.specular_actual
	skin_original = customizer.skin_actual_path
	
	color_sec_original = customizer.color_sec_actual
	metallic_sec_original = customizer.metallic_sec_actual
	roughness_sec_original = customizer.roughness_sec_actual
	specular_sec_original = customizer.specular_sec_actual
	
	glass_color_original = customizer.glass_color_actual
	glass_opacity_original = customizer.glass_opacity_actual
	
	rims_color_original = customizer.rims_color_actual
	rims_metallic_original = customizer.rims_metallic_actual
	rims_roughness_original = customizer.rims_roughness_actual
	rines_original = customizer.modelo_rines
	
	neon_enabled_original = customizer.neon_enabled_actual
	neon_color_original = customizer.neon_color_actual
	neon_intensity_original = customizer.neon_intensity_actual
	
	plate_text_original = customizer.plate_text_actual
	plate_city_original = customizer.plate_city_actual
	plate_is_public_original = customizer.plate_is_public_actual
	
	# Configurar Color Picker personalizado
	if color_picker:
		color_picker.set_color_hsv(color_original.h, color_original.s, color_original.v)
		if not color_picker.color_changed.is_connected(_on_color_changed):
			color_picker.color_changed.connect(_on_color_changed)
	
	if slider_metallic:
		slider_metallic.value = customizer.metallic_actual
		if not slider_metallic.value_changed.is_connected(_on_material_changed):
			slider_metallic.value_changed.connect(_on_material_changed)
		_estilizar_slider(slider_metallic, _grabber_textura)
	if slider_roughness:
		slider_roughness.value = customizer.roughness_actual
		if not slider_roughness.value_changed.is_connected(_on_material_changed):
			slider_roughness.value_changed.connect(_on_material_changed)
		_estilizar_slider(slider_roughness, _grabber_textura)
	if slider_specular:
		slider_specular.value = customizer.specular_actual
		if not slider_specular.value_changed.is_connected(_on_material_changed):
			slider_specular.value_changed.connect(_on_material_changed)
		_estilizar_slider(slider_specular, _grabber_textura)

		
	# Construir e inicializar todos los componentes extendidos dinámicamente
	_crear_pestanas_nuevas()
	_inicializar_nueva_ui_objetos()
	_crear_panel_camaras()
	_generar_opciones()
	_update_labels()
	
	# Cargar los valores iniciales del customizer en los controles de la UI
	_cargar_valores_iniciales_en_ui()
	
	# Inicializar menú principal de categorías
	_inicializar_menu_categorias()

	# Conectar señal de selección de malla para actualizar la UI
	if customizer_ref and customizer_ref.has_signal("mesh_selected"):
		var cb := Callable(self, "_on_mesh_selected")
		if not customizer_ref.is_connected("mesh_selected", cb):
			customizer_ref.connect("mesh_selected", cb)

func _crear_pestanas_nuevas() -> void:
	if not tab_container:
		return

	if is_instance_valid(btn_tab_accesorios):
		if is_instance_valid(scroll_accesorios):
			for c in scroll_accesorios.get_children():
				c.queue_free()
			_construir_ui_accesorios()
		if is_instance_valid(scroll_placas):
			for c in scroll_placas.get_children():
				c.queue_free()
			_construir_ui_placas()
		return
		
	var font_path := "res://recursos/fonts/Moderniz.otf"
	var font = load(font_path) if ResourceLoader.exists(font_path) else null
	
	# Redimensionar botones de pestañas existentes para móviles
	var tab_buttons = [btn_tab_pintura, btn_tab_skins, btn_tab_rines]
	for btn in tab_buttons:
		if btn:
			btn.custom_minimum_size = Vector2(165, 55)
			btn.add_theme_font_size_override("font_size", 20)
			
	# Agregar botón pestaña: Accesorios / Detalles
	btn_tab_accesorios = Button.new()
	btn_tab_accesorios.name = "BtnTabAccesorios"
	btn_tab_accesorios.text = "DETALLES"
	btn_tab_accesorios.focus_mode = Control.FOCUS_NONE
	btn_tab_accesorios.custom_minimum_size = Vector2(165, 55)
	if font: btn_tab_accesorios.add_theme_font_override("font", font)
	btn_tab_accesorios.add_theme_font_size_override("font_size", 20)
	$PanelFondo/CustomTabBar.add_child(btn_tab_accesorios)
	btn_tab_accesorios.pressed.connect(func(): _cambiar_tab(3))
	
	# Agregar botón pestaña: Placas
	btn_tab_placas = Button.new()
	btn_tab_placas.name = "BtnTabPlacas"
	btn_tab_placas.text = "PLACAS"
	btn_tab_placas.focus_mode = Control.FOCUS_NONE
	btn_tab_placas.custom_minimum_size = Vector2(165, 55)
	if font: btn_tab_placas.add_theme_font_override("font", font)
	btn_tab_placas.add_theme_font_size_override("font_size", 20)
	$PanelFondo/CustomTabBar.add_child(btn_tab_placas)
	btn_tab_placas.pressed.connect(func(): _cambiar_tab(4))
	
	# Crear contenedor pestaña 3 (Accesorios)
	scroll_accesorios = ScrollContainer.new()
	scroll_accesorios.name = "Accesorios"
	tab_container.add_child(scroll_accesorios)
	_construir_ui_accesorios()
	
	# Crear contenedor pestaña 4 (Placas)
	scroll_placas = ScrollContainer.new()
	scroll_placas.name = "Placas"
	tab_container.add_child(scroll_placas)
	_construir_ui_placas()

var slot_color_seleccionado: int = 0
var container_canales: HFlowContainer = null

func _crear_selector_canales_pintura() -> void:
	var vbox_pintura = $PanelFondo/TabContainer/Pintura/VBoxPintura
	
	container_canales = HFlowContainer.new()
	container_canales.name = "CanalPinturaHBox"
	container_canales.alignment = FlowContainer.ALIGNMENT_CENTER
	container_canales.add_theme_constant_override("h_separation", 15)
	container_canales.add_theme_constant_override("v_separation", 15)
	
	vbox_pintura.add_child(container_canales)
	vbox_pintura.move_child(container_canales, 1) # Insertar despuǸs de spacer

func _refrescar_canales_color_dinamicos() -> void:
	if not container_canales or not customizer_ref:
		return
		
	for child in container_canales.get_children():
		child.queue_free()
		
	var font_path := "res://recursos/fonts/Moderniz.otf"
	var font = load(font_path) if ResourceLoader.exists(font_path) else null
	
	for i in range(customizer_ref.materiales_detectados.size()):
		var btn = Button.new()
		btn.text = "COLOR " + str(i + 1)
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(170, 50)
		if font: btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _seleccionar_slot_color(i))
		container_canales.add_child(btn)
		
	if customizer_ref.materiales_detectados.size() > 0:
		_seleccionar_slot_color(0)

func _seleccionar_slot_color(index: int) -> void:
	slot_color_seleccionado = index
	if not customizer_ref or index >= customizer_ref.materiales_detectados.size():
		return
		
	var sb_active = StyleBoxFlat.new()
	sb_active.bg_color = Color(0.95, 0.8, 0.0) # Gold
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb_active.set("corner_radius_" + side, 8)
		
	var sb_inactive = StyleBoxFlat.new()
	sb_inactive.bg_color = Color(0.12, 0.12, 0.16, 0.85)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb_inactive.set("corner_radius_" + side, 8)
		
	for i in range(container_canales.get_child_count()):
		var btn = container_canales.get_child(i) as Button
		if i == index:
			btn.add_theme_stylebox_override("normal", sb_active)
			btn.add_theme_stylebox_override("hover", sb_active)
			btn.add_theme_color_override("font_color", Color(0, 0, 0))
		else:
			btn.add_theme_stylebox_override("normal", sb_inactive)
			btn.add_theme_stylebox_override("hover", sb_inactive)
			btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			
	var mat = customizer_ref.materiales_detectados[index]
	var col = Color.WHITE
	var met = 0.0
	var rough = 0.5
	var spec = 0.5
	
	if customizer_ref and customizer_ref.has_method("_leer_color_material"):
		var info: Dictionary = customizer_ref._leer_color_material(mat)
		if not info.is_empty():
			col = info["color"]
			met = info["metallic"]
			rough = info["roughness"]
			spec = info["specular"]
	elif mat is StandardMaterial3D:
		col = mat.albedo_color
		met = mat.metallic
		rough = mat.roughness
		spec = mat.metallic_specular
	elif mat is ShaderMaterial:
		for param in ["albedo", "paint_color", "albedo_color", "base_color", "color"]:
			var c = mat.get_shader_parameter(param)
			if c != null:
				col = c
				break
		var m = mat.get_shader_parameter("metallic")
		if m != null: met = m
		var r = mat.get_shader_parameter("roughness")
		if r != null: rough = r
		
	color_seleccionado = col
	if color_picker:
		color_picker.set_color_hsv(col.h, col.s, col.v)
	if slider_metallic: slider_metallic.value = met
	if slider_roughness: slider_roughness.value = rough
	if slider_specular: slider_specular.value = spec
	
	_update_labels()

func _crear_panel_camaras() -> void:
	if has_node("FloatingCameraPanel"):
		return
	# Crear panel de presets de enfoque en la izquierda de la pantalla
	var cam_panel = PanelContainer.new()
	cam_panel.name = "FloatingCameraPanel"
	add_child(cam_panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.88)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("border_width_" + side, 1)
	sb.border_color = Color(0.78, 0.81, 0.85, 0.22)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb.set("corner_radius_" + corner, 12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 15
	sb.content_margin_bottom = 15
	cam_panel.add_theme_stylebox_override("panel", sb)
	
	# Anclas a la izquierda centro
	cam_panel.anchor_left = 0.0
	cam_panel.anchor_top = 0.5
	cam_panel.anchor_right = 0.0
	cam_panel.anchor_bottom = 0.5
	cam_panel.offset_left = 40
	cam_panel.offset_right = 230
	cam_panel.offset_top = -185
	cam_panel.offset_bottom = 185
	cam_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	cam_panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "ENFOQUE 3D"
	var font_path := "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var presets = [
		{"name": "📷 GENERAL", "method": "enfocar_carroceria"},
		{"name": "📷 RUEDAS", "method": "enfocar_rines"},
		{"name": "📷 PLACAS", "method": "enfocar_placas"},
		{"name": "📷 NEON", "method": "enfocar_neon"}

	]
	
	for pr in presets:
		var btn = Button.new()
		btn.text = pr["name"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(180, 50)
		
		var btn_sb = StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.08, 0.08, 0.12, 0.8)
		btn_sb.border_width_left = 3
		btn_sb.border_color = Color(0.95, 0.8, 0.0, 0.5)
		for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			btn_sb.set("corner_radius_" + corner, 10)
		
		var btn_sb_hover = btn_sb.duplicate() as StyleBoxFlat
		btn_sb_hover.bg_color = Color(0.14, 0.14, 0.2, 0.9)
		btn_sb_hover.border_color = Color(0.95, 0.8, 0.0, 1.0)
		btn_sb_hover.shadow_color = Color(0.95, 0.8, 0.0, 0.15)
		btn_sb_hover.shadow_size = 5
		
		btn.add_theme_stylebox_override("normal", btn_sb)
		btn.add_theme_stylebox_override("hover", btn_sb_hover)
		btn.add_theme_stylebox_override("pressed", btn_sb)
		if ResourceLoader.exists(font_path):
			btn.add_theme_font_override("font", load(font_path))
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		
		btn.pressed.connect(func():
			if taller_ref and taller_ref.has_method(pr["method"]):
				taller_ref.call(pr["method"])
		)
		vbox.add_child(btn)

	# Botón para activar modo selección de objeto en la cámara
	var select_btn = Button.new()
	select_btn.text = "Seleccionar Objeto"
	select_btn.toggle_mode = true
	select_btn.focus_mode = Control.FOCUS_NONE
	select_btn.custom_minimum_size = Vector2(180, 50)
	if ResourceLoader.exists(font_path):
		select_btn.add_theme_font_override("font", load(font_path))
	select_btn.add_theme_font_size_override("font_size", 20)
	select_btn.pressed.connect(func():
		if select_btn.pressed:
			if taller_ref and taller_ref.has_method("set_selection_mode"):
				taller_ref.call("set_selection_mode", true)
			select_btn.text = "Cancelar selección"
		else:
			if taller_ref and taller_ref.has_method("set_selection_mode"):
				taller_ref.call("set_selection_mode", false)
			select_btn.text = "Seleccionar Objeto"
	)
	vbox.add_child(select_btn)

func _crear_tarjeta_seccion(titulo: String, parent_node: Node) -> VBoxContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.09, 0.09, 0.13, 0.9)
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3
	card_style.border_color = Color(0.18, 0.18, 0.24, 0.8)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		card_style.set("corner_radius_" + corner, 16)
	card_style.content_margin_left = 20
	card_style.content_margin_right = 20
	card_style.content_margin_top = 20
	card_style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", card_style)
	parent_node.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	card.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = titulo.to_upper()
	var font_path := "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		lbl.add_theme_font_override("font", load(font_path))
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.0))
	vbox.add_child(lbl)
	
	return vbox

func _construir_ui_accesorios() -> void:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 25)
	scroll_accesorios.add_child(container)
	
	# --- TARJETA DE VIDRIOS / POLARIZADO ---
	var tint_vbox = _crear_tarjeta_seccion("Polarizado de Vidrios", container)
	
	var colors_label = Label.new()
	colors_label.text = "Color del Polarizado:"
	colors_label.add_theme_font_size_override("font_size", 16)
	tint_vbox.add_child(colors_label)
	
	var colors_hbox = HBoxContainer.new()
	colors_hbox.add_theme_constant_override("h_separation", 10)
	tint_vbox.add_child(colors_hbox)
	
	var glass_presets = [
		{"name": "Negro", "color": Color.BLACK},
		{"name": "Azul", "color": Color(0.0, 0.2, 0.6)},
		{"name": "Verde", "color": Color(0.0, 0.4, 0.1)},
		{"name": "Plata", "color": Color(0.85, 0.85, 0.9)},
		{"name": "Bronce", "color": Color(0.6, 0.4, 0.25)}
	]
	
	for preset in glass_presets:
		var btn = Button.new()
		btn.text = preset["name"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(110, 50)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(func():
			selected_glass_color = preset["color"]
			_aplicar_vidrios_ui()
		)
		colors_hbox.add_child(btn)
		
	var op_label = Label.new()
	op_label.text = "Opacidad (Polarizado):"
	op_label.add_theme_font_size_override("font_size", 22)
	tint_vbox.add_child(op_label)
	
	glass_opacity_slider = HSlider.new()
	glass_opacity_slider.min_value = 0.0
	glass_opacity_slider.max_value = 0.95
	glass_opacity_slider.step = 0.05
	glass_opacity_slider.value = 0.0
	glass_opacity_slider.focus_mode = Control.FOCUS_NONE
	glass_opacity_slider.value_changed.connect(func(v): _aplicar_vidrios_ui())
	_estilizar_slider(glass_opacity_slider, _grabber_textura)
	tint_vbox.add_child(glass_opacity_slider)

	
	# --- TARJETA DE NEÓN UNDERGLOW ---
	var neon_vbox = _crear_tarjeta_seccion("Neon Bajo el Chasis", container)
	
	neon_toggle_btn = Button.new()
	neon_toggle_btn.text = "NEON: APAGADO"
	neon_toggle_btn.focus_mode = Control.FOCUS_NONE
	neon_toggle_btn.custom_minimum_size = Vector2(280, 55)
	neon_toggle_btn.add_theme_font_size_override("font_size", 22)
	neon_toggle_btn.pressed.connect(func():
		_toggle_neon_ui()
	)
	neon_vbox.add_child(neon_toggle_btn)
	
	var neon_colors_label = Label.new()
	neon_colors_label.text = "Color de Luz Neon:"
	neon_colors_label.add_theme_font_size_override("font_size", 22)
	neon_vbox.add_child(neon_colors_label)

	
	var neon_colors_hbox = HBoxContainer.new()
	neon_colors_hbox.add_theme_constant_override("h_separation", 10)
	neon_vbox.add_child(neon_colors_hbox)
	
	var neon_presets = [
		{"name": "Azul", "color": Color.BLUE},
		{"name": "Rojo", "color": Color.RED},
		{"name": "Verde", "color": Color.GREEN},
		{"name": "Morado", "color": Color.PURPLE},
		{"name": "Amarillo", "color": Color.YELLOW},
		{"name": "Cian", "color": Color.CYAN}
	]
	
	for preset in neon_presets:
		var btn = Button.new()
		btn.text = preset["name"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(110, 50)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(func():
			selected_neon_color = preset["color"]
			_aplicar_neon_ui()
		)
		neon_colors_hbox.add_child(btn)
		
	var int_label = Label.new()
	int_label.text = "Intensidad de Brillo:"
	int_label.add_theme_font_size_override("font_size", 22)
	neon_vbox.add_child(int_label)
	
	neon_intensity_slider = HSlider.new()
	neon_intensity_slider.min_value = 0.2
	neon_intensity_slider.max_value = 2.0
	neon_intensity_slider.step = 0.1
	neon_intensity_slider.value = 1.0
	neon_intensity_slider.focus_mode = Control.FOCUS_NONE
	neon_intensity_slider.value_changed.connect(func(_v): _aplicar_neon_ui())
	_estilizar_slider(neon_intensity_slider, _grabber_textura)
	neon_vbox.add_child(neon_intensity_slider)


func _aplicar_vidrios_ui() -> void:
	if customizer_ref and glass_opacity_slider:
		customizer_ref.aplicar_vidrios(selected_glass_color, glass_opacity_slider.value)

func _aplicar_neon_ui() -> void:
	if customizer_ref and neon_toggle_btn and neon_intensity_slider:
		var is_enabled = neon_toggle_btn.text.contains("ENCENDIDO")
		customizer_ref.aplicar_neon(is_enabled, selected_neon_color, neon_intensity_slider.value)

func _toggle_neon_ui() -> void:
	if neon_toggle_btn:
		var was_enabled = neon_toggle_btn.text.contains("ENCENDIDO")
		if was_enabled:
			neon_toggle_btn.text = "NEON: APAGADO"
			neon_toggle_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			neon_toggle_btn.remove_theme_stylebox_override("normal")
		else:
			neon_toggle_btn.text = "NEON: ENCENDIDO"
			neon_toggle_btn.add_theme_color_override("font_color", Color(0, 0, 0))
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.95, 0.8, 0.0, 1.0)
			for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
				sb.set("corner_radius_" + corner, 8)
			neon_toggle_btn.add_theme_stylebox_override("normal", sb)
		_aplicar_neon_ui()


func _construir_ui_placas() -> void:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 25)
	scroll_placas.add_child(container)
	
	var placa_vbox = _crear_tarjeta_seccion("Personalizar Placas", container)
	
	var num_lbl = Label.new()
	num_lbl.text = "Texto de Placa (Ej. ABC 123):"
	num_lbl.add_theme_font_size_override("font_size", 22)
	placa_vbox.add_child(num_lbl)
	
	plate_text_input = LineEdit.new()
	plate_text_input.placeholder_text = "ABC 123"
	plate_text_input.max_length = 7
	plate_text_input.focus_mode = Control.FOCUS_CLICK
	plate_text_input.custom_minimum_size = Vector2(250, 55)
	plate_text_input.add_theme_font_size_override("font_size", 24)
	plate_text_input.text_changed.connect(func(new_text):
		plate_text_input.text = new_text.to_upper()
		plate_text_input.caret_column = plate_text_input.text.length()
		_aplicar_placa_ui()
	)
	placa_vbox.add_child(plate_text_input)
	
	var city_lbl = Label.new()
	city_lbl.text = "Municipio / Ciudad:"
	city_lbl.add_theme_font_size_override("font_size", 22)
	placa_vbox.add_child(city_lbl)
	
	plate_city_input = LineEdit.new()
	plate_city_input.placeholder_text = "BOGOTA"
	plate_city_input.max_length = 15
	plate_city_input.focus_mode = Control.FOCUS_CLICK
	plate_city_input.custom_minimum_size = Vector2(250, 55)
	plate_city_input.add_theme_font_size_override("font_size", 24)
	plate_city_input.text_changed.connect(func(new_text):
		plate_city_input.text = new_text.to_upper()
		plate_city_input.caret_column = plate_city_input.text.length()
		_aplicar_placa_ui()
	)
	placa_vbox.add_child(plate_city_input)

	
	var type_lbl = Label.new()
	type_lbl.text = "Tipo de Placa (Colombia):"
	type_lbl.add_theme_font_size_override("font_size", 22)
	placa_vbox.add_child(type_lbl)
	
	plate_type_btn = Button.new()
	plate_type_btn.text = "SERVICIO: PARTICULAR (AMARILLA)"
	plate_type_btn.focus_mode = Control.FOCUS_NONE
	plate_type_btn.custom_minimum_size = Vector2(280, 55)
	plate_type_btn.add_theme_font_size_override("font_size", 22)

	
	# Estilo inicial particular
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.988, 0.82, 0.086, 1.0)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb.set("corner_radius_" + corner, 8)
	plate_type_btn.add_theme_stylebox_override("normal", sb)
	plate_type_btn.add_theme_color_override("font_color", Color(0, 0, 0))
	
	plate_type_btn.pressed.connect(func():
		_toggle_tipo_placa_ui()
	)
	placa_vbox.add_child(plate_type_btn)

func _toggle_tipo_placa_ui() -> void:
	if plate_type_btn:
		var is_public = plate_type_btn.text.contains("PUBLICO")
		var sb = StyleBoxFlat.new()
		for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			sb.set("corner_radius_" + corner, 8)
			
		if is_public:
			plate_type_btn.text = "SERVICIO: PARTICULAR (AMARILLA)"
			sb.bg_color = Color(0.988, 0.82, 0.086, 1.0) # Amarillo
		else:
			plate_type_btn.text = "SERVICIO: PUBLICO (BLANCA)"
			sb.bg_color = Color(0.96, 0.96, 0.96, 1.0) # Blanco
			
		plate_type_btn.add_theme_stylebox_override("normal", sb)
		_aplicar_placa_ui()


func _aplicar_placa_ui() -> void:
	if customizer_ref and plate_text_input and plate_city_input and plate_type_btn:
		var is_public = plate_type_btn.text.contains("PUBLICO")
		var text = plate_text_input.text
		if text.strip_edges() == "":
			text = "ABC 123"
		var city = plate_city_input.text
		if city.strip_edges() == "":
			city = "BOGOTA"
		customizer_ref.aplicar_placa(text, city, is_public)


func _cambiar_tab(index: int) -> void:
	if index != 0:
		_on_volver_objetos_pressed()

	if is_node_ready():
		_reproducir_sonido_seleccion()

	if tab_container:
		tab_container.current_tab = index
		
	var tabs = [btn_tab_pintura, btn_tab_skins, btn_tab_rines, btn_tab_accesorios, btn_tab_placas]
	for i in range(tabs.size()):
		var btn = tabs[i]
		if btn and style_active and style_inactive:
			if i == index:
				btn.add_theme_stylebox_override("normal", style_active)
				btn.add_theme_stylebox_override("hover", style_active)
				btn.add_theme_stylebox_override("pressed", style_active)
				btn.add_theme_color_override("font_color", Color(0.95, 0.8, 0.0))
			else:
				btn.add_theme_stylebox_override("normal", style_inactive)
				btn.add_theme_stylebox_override("hover", style_inactive)
				btn.add_theme_stylebox_override("pressed", style_inactive)
				btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

func _on_color_changed(color: Color) -> void:
	color_seleccionado = color
	_aplicar_cambios()

func _on_material_changed(_val = null) -> void:
	_aplicar_cambios()

func _on_configurar_pressed() -> void:
	if card_sliders and color_picker and btn_configurar:
		card_sliders.visible = !card_sliders.visible
		color_picker.visible = !card_sliders.visible
		
		if card_sliders.visible:
			btn_configurar.text = "VOLVER AL COLOR"
			btn_configurar.add_theme_color_override("font_color", Color(0, 0, 0, 1))
			var sb = btn_configurar.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			sb.bg_color = Color(0.95, 0.8, 0.0, 1.0)
			btn_configurar.add_theme_stylebox_override("normal", sb)
		else:
			btn_configurar.text = "CONFIGURAR MATERIAL"
			btn_configurar.add_theme_color_override("font_color", Color(0.95, 0.8, 0.0, 1.0))
			btn_configurar.remove_theme_stylebox_override("normal")

func _aplicar_cambios() -> void:
	var met = slider_metallic.value if slider_metallic else 0.0
	var rough = slider_roughness.value if slider_roughness else 0.5
	var spec = slider_specular.value if slider_specular else 0.5

	if customizer_ref:
		if is_instance_valid(mesh_seleccionado_actual) and index_material_seleccionado != -1:
			var entry = materiales_mesh_seleccionado[index_material_seleccionado]
			var idx = entry["surface_idx"]
			
			var mat_actualizada = customizer_ref.aplicar_color_a_mesh_material(mesh_seleccionado_actual, idx, color_seleccionado, met, rough, spec)
			if mat_actualizada:
				entry["material"] = mat_actualizada
			
			if index_material_seleccionado < container_materiales_objeto.get_child_count():
				var card = container_materiales_objeto.get_child(index_material_seleccionado) as PanelContainer
				if card:
					var swatch_border = card.find_child("SwatchBorder", true, false) as PanelContainer
					if swatch_border:
						var sb = swatch_border.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
						if sb:
							sb.bg_color = color_seleccionado
							swatch_border.add_theme_stylebox_override("panel", sb)
		elif customizer_ref.materiales_detectados.size() > 0:
			customizer_ref.aplicar_color_slot(slot_color_seleccionado, color_seleccionado, met, rough, spec)
			
	_update_labels()

func _update_labels() -> void:
	var met = slider_metallic.value if slider_metallic else 0.0
	var rough = slider_roughness.value if slider_roughness else 0.5
	var spec = slider_specular.value if slider_specular else 0.5

	if color_preview:
		color_preview.color = color_seleccionado

	if lbl_metallic:
		lbl_metallic.text = "METALIZADO (CROMO): %d%%" % int(met * 100)
	if lbl_roughness:
		lbl_roughness.text = "RUGOSIDAD (MATE): %d%%" % int(rough * 100)
	if lbl_specular:
		lbl_specular.text = "REFLEJO (ESPECULAR): %d%%" % int(spec * 100)

func _generar_opciones() -> void:
	# 1. Generar botones de skins
	if container_skins:
		for c in container_skins.get_children():
			c.queue_free()
		for skin in SKINS_PRESET:
			var btn = Button.new()
			btn.text = skin["nombre"]
			btn.custom_minimum_size = Vector2(180, 60)
			btn.add_theme_font_size_override("font_size", 20)
			
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.12, 0.12, 0.16)
			for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
				sb.set("corner_radius_" + corner, 8)
			btn.add_theme_stylebox_override("normal", sb)
			
			btn.pressed.connect(func(): 
				if skin["path"] == "":
					customizer_ref.aplicar_pintura(color_seleccionado, slider_metallic.value if slider_metallic else 0.0, slider_roughness.value if slider_roughness else 0.5, slider_specular.value if slider_specular else 0.5)
				else:
					customizer_ref.aplicar_skin(skin["path"])
			)
			container_skins.add_child(btn)

	# 2. Generar botones de rines/llantas y pintar rines
	if container_rines:
		var rines_scroll = container_rines.get_parent()
		var rines_vbox = VBoxContainer.new()
		rines_vbox.name = "RinesVBox"
		rines_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rines_vbox.add_theme_constant_override("separation", 25)
		
		rines_scroll.remove_child(container_rines)
		rines_vbox.add_child(container_rines)
		rines_scroll.add_child(rines_vbox)
		
		for c in container_rines.get_children():
			c.queue_free()
		for rin in RINES_PRESET:
			var btn = Button.new()
			btn.text = rin.replace("_", " ").capitalize()
			btn.custom_minimum_size = Vector2(180, 60)
			btn.add_theme_font_size_override("font_size", 20)
			
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.12, 0.12, 0.16)
			for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
				sb.set("corner_radius_" + corner, 8)
			btn.add_theme_stylebox_override("normal", sb)
			
			btn.pressed.connect(func(): customizer_ref.aplicar_rines(rin))
			container_rines.add_child(btn)
			
		# Añadir tarjeta de color de rines
		var rims_paint_vbox = _crear_tarjeta_seccion("Acabado y Color de Rines", rines_vbox)
		
		var color_label = Label.new()
		color_label.text = "Color del Metal:"
		color_label.add_theme_font_size_override("font_size", 22)
		rims_paint_vbox.add_child(color_label)
		
		var colors_hbox = HBoxContainer.new()
		colors_hbox.add_theme_constant_override("h_separation", 10)
		rims_paint_vbox.add_child(colors_hbox)
		
		var rims_presets = [
			{"name": "Cromo", "color": Color.WHITE},
			{"name": "Oro", "color": Color(0.9, 0.7, 0.25)},
			{"name": "Negro", "color": Color(0.1, 0.1, 0.15)},
			{"name": "Cobre", "color": Color(0.75, 0.45, 0.28)},
			{"name": "Rojo", "color": Color(0.85, 0.1, 0.15)}
		]
		
		for preset in rims_presets:
			var btn = Button.new()
			btn.text = preset["name"]
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(110, 50)
			btn.add_theme_font_size_override("font_size", 20)
			btn.pressed.connect(func():
				_aplicar_color_rines_ui(preset["color"], r_metallic_slider.value, r_roughness_slider.value)
			)
			colors_hbox.add_child(btn)
			
		var met_label = Label.new()
		met_label.text = "Metalizado (Brillo):"
		met_label.add_theme_font_size_override("font_size", 22)
		rims_paint_vbox.add_child(met_label)
		
		r_metallic_slider = HSlider.new()
		r_metallic_slider.min_value = 0.0
		r_metallic_slider.max_value = 1.0
		r_metallic_slider.step = 0.05
		r_metallic_slider.value = 0.8
		r_metallic_slider.focus_mode = Control.FOCUS_NONE
		r_metallic_slider.value_changed.connect(func(v): _aplicar_color_rines_ui(customizer_ref.rims_color_actual, v, r_roughness_slider.value))
		_estilizar_slider(r_metallic_slider, _grabber_textura)
		rims_paint_vbox.add_child(r_metallic_slider)

		
		var rough_label = Label.new()
		rough_label.text = "Rugosidad (Brillo Mate):"
		rough_label.add_theme_font_size_override("font_size", 22)
		rims_paint_vbox.add_child(rough_label)
		
		r_roughness_slider = HSlider.new()
		r_roughness_slider.min_value = 0.0
		r_roughness_slider.max_value = 1.0
		r_roughness_slider.step = 0.05
		r_roughness_slider.value = 0.2
		r_roughness_slider.focus_mode = Control.FOCUS_NONE
		r_roughness_slider.value_changed.connect(func(v): _aplicar_color_rines_ui(customizer_ref.rims_color_actual, r_metallic_slider.value, v))
		_estilizar_slider(r_roughness_slider, _grabber_textura)
		rims_paint_vbox.add_child(r_roughness_slider)
		
		# Tarjeta de Ajustes Físicos (Offset & Camber)
		var stance_vbox = _crear_tarjeta_seccion("Ajustes Físicos de Ruedas (Stance)", rines_vbox)
		
		# Offset / Ancho de vía
		var offset_label = Label.new()
		offset_label.text = "ANCHO DE VÍA (OFFSET): 0 cm"
		offset_label.add_theme_font_size_override("font_size", 22)
		stance_vbox.add_child(offset_label)
		
		var slider_offset = HSlider.new()
		slider_offset.min_value = 0.0
		slider_offset.max_value = 0.20
		slider_offset.step = 0.01
		slider_offset.value = customizer_ref.wheel_offset_actual if customizer_ref else 0.0
		slider_offset.focus_mode = Control.FOCUS_NONE
		_estilizar_slider(slider_offset, _grabber_textura)
		stance_vbox.add_child(slider_offset)
		
		var update_offset_label = func(val: float):
			offset_label.text = "ANCHO DE VÍA (OFFSET): %d cm" % int(val * 100)
		update_offset_label.call(slider_offset.value)
		
		slider_offset.value_changed.connect(func(v):
			if customizer_ref:
				customizer_ref.aplicar_offset_ruedas(v)
			update_offset_label.call(v)
		)
		
		# Camber / Inclinación
		var camber_label = Label.new()
		camber_label.text = "CAÍDA DE RUEDA (CAMBER): 0°"
		camber_label.add_theme_font_size_override("font_size", 22)
		stance_vbox.add_child(camber_label)
		
		var slider_camber = HSlider.new()
		slider_camber.min_value = -15.0
		slider_camber.max_value = 0.0
		slider_camber.step = 0.5
		slider_camber.value = customizer_ref.wheel_camber_actual if customizer_ref else 0.0
		slider_camber.focus_mode = Control.FOCUS_NONE
		_estilizar_slider(slider_camber, _grabber_textura)
		stance_vbox.add_child(slider_camber)
		
		var update_camber_label = func(val: float):
			camber_label.text = "CAÍDA DE RUEDA (CAMBER): %.1f°" % val
		update_camber_label.call(slider_camber.value)
		
		slider_camber.value_changed.connect(func(v):
			if customizer_ref:
				customizer_ref.aplicar_camber_ruedas(v)
			update_camber_label.call(v)
		)


func _aplicar_color_rines_ui(color: Color, met: float, rough: float) -> void:
	if customizer_ref:
		customizer_ref.aplicar_color_rines(color, met, rough)

func _on_mesh_selected(slot_idx: int) -> void:
	if not customizer_ref or slot_idx < 0 or slot_idx >= customizer_ref.materiales_detectados.size():
		return
	var mat = customizer_ref.materiales_detectados[slot_idx]
	var lista = customizer_ref.meshes_materiales_mapeo.get(mat, [])
	if lista.size() > 0:
		var mesh = lista[0].get("mesh")
		if is_instance_valid(mesh):
			if container_menu_categorias and container_menu_categorias.visible:
				_abrir_categoria(0, "enfocar_carroceria")
			_on_objeto_seleccionado(mesh)

func _cargar_valores_iniciales_en_ui() -> void:
	if not customizer_ref:
		return
		
	# Cargar polarizado
	if glass_opacity_slider:
		glass_opacity_slider.value = customizer_ref.glass_opacity_actual
	selected_glass_color = customizer_ref.glass_color_actual
	
	# Cargar neón
	selected_neon_color = customizer_ref.neon_color_actual
	if neon_intensity_slider:
		neon_intensity_slider.value = customizer_ref.neon_intensity_actual
	if neon_toggle_btn:
		if customizer_ref.neon_enabled_actual:
			neon_toggle_btn.text = "NEON: ENCENDIDO"
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.95, 0.8, 0.0, 1.0)
			for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
				sb.set("corner_radius_" + corner, 8)
			neon_toggle_btn.add_theme_stylebox_override("normal", sb)
			neon_toggle_btn.add_theme_color_override("font_color", Color(0, 0, 0))
		else:
			neon_toggle_btn.text = "NEON: APAGADO"
			neon_toggle_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			neon_toggle_btn.remove_theme_stylebox_override("normal")

			
	# Cargar placa
	if plate_text_input:
		plate_text_input.text = customizer_ref.plate_text_actual
	if plate_city_input:
		plate_city_input.text = customizer_ref.plate_city_actual
	if plate_type_btn:
		var sb = StyleBoxFlat.new()
		for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			sb.set("corner_radius_" + corner, 8)
		if customizer_ref.plate_is_public_actual:
			plate_type_btn.text = "SERVICIO: PUBLICO (BLANCA)"
			sb.bg_color = Color(0.96, 0.96, 0.96, 1.0)
		else:
			plate_type_btn.text = "SERVICIO: PARTICULAR (AMARILLA)"
			sb.bg_color = Color(0.988, 0.82, 0.086, 1.0)
		plate_type_btn.add_theme_stylebox_override("normal", sb)

		
	# Cargar rines
	if r_metallic_slider:
		r_metallic_slider.value = customizer_ref.rims_metallic_actual
	if r_roughness_slider:
		r_roughness_slider.value = customizer_ref.rims_roughness_actual

func _on_guardar_pressed() -> void:
	if customizer_ref:
		customizer_ref.desactivar_xray()
		customizer_ref.guardar_personalizacion()
		if customizer_ref.has_method("crear_snapshot"):
			_snapshot_original = customizer_ref.crear_snapshot()
		if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
			var mm = get_node_or_null("/root/MultiplayerManager")
			if mm and mm.has_method("sincronizar_personalizacion_vehiculo"):
				mm.sincronizar_personalizacion_vehiculo.rpc(
					multiplayer.get_unique_id(),
					customizer_ref.color_actual.to_html(false),
					customizer_ref.metallic_actual,
					customizer_ref.roughness_actual,
					customizer_ref.neon_enabled_actual,
					customizer_ref.neon_color_actual.to_html(false),
					customizer_ref.neon_intensity_actual
				)
	_salir_ui()

func _on_cancelar_pressed() -> void:
	if customizer_ref:
		customizer_ref.desactivar_xray()
		if not _snapshot_original.is_empty() and customizer_ref.has_method("restaurar_snapshot"):
			customizer_ref.restaurar_snapshot(_snapshot_original)
		else:
			customizer_ref.aplicar_pintura(color_original, metallic_original, roughness_original, specular_original)
			customizer_ref.aplicar_pintura_secundaria(color_sec_original, metallic_sec_original, roughness_sec_original, specular_sec_original)
			customizer_ref.aplicar_vidrios(glass_color_original, glass_opacity_original)
			customizer_ref.aplicar_color_rines(rims_color_original, rims_metallic_original, rims_roughness_original)
			customizer_ref.aplicar_rines(rines_original)
			customizer_ref.aplicar_neon(neon_enabled_original, neon_color_original, neon_intensity_original)
			customizer_ref.aplicar_placa(plate_text_original, plate_city_original, plate_is_public_original)
			if skin_original != "":
				customizer_ref.aplicar_skin(skin_original)
	_salir_ui()

func _salir_ui() -> void:
	if taller_ref:
		taller_ref.cerrar_taller()
		return
	if get_tree():
		get_tree().change_scene_to_file("res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn")
	queue_free()

func _crear_textura_grabber(radio: int, color_centro: Color, color_borde: Color) -> ImageTexture:
	var img_size = radio * 2
	var img = Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)
	var centro = Vector2(radio, radio)
	for x in range(img_size):
		for y in range(img_size):
			var dist = centro.distance_to(Vector2(x, y))
			if dist <= radio:
				var alpha = 1.0
				if dist > radio - 1.0:
					alpha = radio - dist
				
				if dist > radio - 3.0:
					img.set_pixel(x, y, Color(color_borde, alpha))
				elif dist > radio - 5.0:
					img.set_pixel(x, y, Color(0.1, 0.1, 0.15, alpha))
				elif dist < 3.0:
					img.set_pixel(x, y, Color(color_borde, alpha))
				else:
					img.set_pixel(x, y, Color(color_centro, alpha))
	return ImageTexture.create_from_image(img)

func _estilizar_slider(slider: HSlider, grabber_tex: ImageTexture) -> void:
	if not slider:
		return
	slider.add_theme_icon_override("grabber", grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", grabber_tex)
	
	var sb_track = StyleBoxFlat.new()
	sb_track.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	sb_track.border_width_left = 1
	sb_track.border_width_top = 1
	sb_track.border_width_right = 1
	sb_track.border_width_bottom = 1
	sb_track.border_color = Color(0.2, 0.2, 0.28, 0.8)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb_track.set("corner_radius_" + corner, 6)
	sb_track.expand_margin_top = 6
	sb_track.expand_margin_bottom = 6
	
	var sb_area = StyleBoxFlat.new()
	sb_area.bg_color = Color(0.95, 0.8, 0.0, 1.0)
	sb_area.set("corner_radius_top_left", 6)
	sb_area.set("corner_radius_bottom_left", 6)
	sb_area.expand_margin_top = 6
	sb_area.expand_margin_bottom = 6
	
	slider.add_theme_stylebox_override("slider", sb_track)
	slider.add_theme_stylebox_override("grabber_area", sb_area)
	slider.add_theme_stylebox_override("grabber_area_highlight", sb_area)
	
	var parent = slider.get_parent()
	var scroll: ScrollContainer = null
	while parent:
		if parent is ScrollContainer:
			scroll = parent
			break
		parent = parent.get_parent()
		
	if scroll:
		var original_v_mode = scroll.vertical_scroll_mode
		var original_h_mode = scroll.horizontal_scroll_mode
		
		# Conectar usando Callable/anónimas directamente
		slider.drag_started.connect(func():
			scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		)
		slider.drag_ended.connect(func(_changed):
			scroll.vertical_scroll_mode = original_v_mode
			scroll.horizontal_scroll_mode = original_h_mode
		)

# ═══════════════════════════════════════════════════════════════════════
# Métodos para la Nueva Interfaz Basada en Objetos y X-Ray
# ═══════════════════════════════════════════════════════════════════════

func _inicializar_nueva_ui_objetos() -> void:
	if is_instance_valid(scroll_objetos):
		_refrescar_lista_objetos()
		_mostrar_view_a()
		return

	var vbox_pintura = $PanelFondo/TabContainer/Pintura/VBoxPintura
	
	var font_path := "res://recursos/fonts/Moderniz.otf"
	var font = load(font_path) if ResourceLoader.exists(font_path) else null
	
	# 1. Crear el botón "VOLVER"
	btn_volver_objetos = Button.new()
	btn_volver_objetos.text = "VOLVER"
	btn_volver_objetos.focus_mode = Control.FOCUS_NONE
	btn_volver_objetos.custom_minimum_size = Vector2(250, 60)
	if font: btn_volver_objetos.add_theme_font_override("font", font)
	btn_volver_objetos.add_theme_font_size_override("font_size", 30)
	btn_volver_objetos.visible = false
	
	var sb_v = StyleBoxFlat.new()
	sb_v.bg_color = Color(0.18, 0.18, 0.24, 0.85)
	sb_v.border_width_left = 3
	sb_v.border_width_top = 3
	sb_v.border_width_right = 3
	sb_v.border_width_bottom = 3
	sb_v.border_color = Color(0.95, 0.8, 0.0, 1.0)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb_v.set("corner_radius_" + side, 14)
	btn_volver_objetos.add_theme_stylebox_override("normal", sb_v)
	btn_volver_objetos.add_theme_stylebox_override("hover", sb_v)
	btn_volver_objetos.pressed.connect(_on_volver_objetos_pressed)
	
	vbox_pintura.add_child(btn_volver_objetos)
	vbox_pintura.move_child(btn_volver_objetos, 0)
	
	# 2. ScrollContainer para la lista de objetos (View A)
	scroll_objetos = ScrollContainer.new()
	scroll_objetos.custom_minimum_size = Vector2(0, 400)
	scroll_objetos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_objetos.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	vbox_objetos = VBoxContainer.new()
	vbox_objetos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_objetos.add_theme_constant_override("separation", 15)
	scroll_objetos.add_child(vbox_objetos)
	
	vbox_pintura.add_child(scroll_objetos)
	
	# 3. Contenedor para los materiales del objeto seleccionado (View B)
	container_materiales_objeto = VBoxContainer.new()
	container_materiales_objeto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container_materiales_objeto.add_theme_constant_override("separation", 15)
	container_materiales_objeto.visible = false
	vbox_pintura.add_child(container_materiales_objeto)
	
	_refrescar_lista_objetos()
	_mostrar_view_a()

func _formatear_nombre_pieza(raw_name: String) -> String:
	var n := raw_name.strip_edges().to_lower()
	n = n.replace("_ok", "").replace(" ok", "").replace("accesorio_", "").replace("accesorios ", "")
	var lado := ""
	if "_izq" in n or "izq" in n or "_fl" in n or "_rl" in n or "left" in n or "_l" in n.right(2):
		lado = " (IZQ)"
	elif "_der" in n or "der" in n or "_fr" in n or "_rr" in n or "right" in n or "_r" in n.right(2) or n.ends_with("d"):
		if "parachoquesd" in raw_name.to_lower():
			return "PARACHOQUES DELANTERO"
		lado = " (DER)"
	if "bonnet" in n or "capo" in n or "hood" in n:
		return "CAPÓ"
	if "boot" in n or "baul" in n or "maletero" in n or "tailgate" in n:
		return "COMPUERTA / BAÚL"
	if "bump_front" in n or "bumper_front" in n or "parachoques_del" in n:
		return "PARACHOQUES DELANTERO"
	if "bump_rear" in n or "bumper_rear" in n or "parachoques_tras" in n:
		return "PARACHOQUES TRASERO"
	if "parachoques" in n or "bumper" in n or "defensa" in n:
		return "PARACHOQUES" + lado
	if "carroceria" in n or "cabina" in n or "chassis" in n or "chasis" in n or "body" in n:
		return "CARROCERÍA PRINCIPAL"
	if "door" in n or "puerta" in n:
		return "PUERTA" + lado
	if "fender" in n or "guardafango" in n or "salpicadera" in n:
		return "GUARDAFANGO" + lado
	if "grille" in n or "parrilla" in n or "persiana" in n:
		return "PARRILLA FRONTAL"
	if "mirror" in n or "espejo" in n or "retrovisor" in n:
		return "ESPEJOS" + lado
	if "exhaust" in n or "escape" in n or "mofle" in n:
		return "ESCAPES / MOFLE"
	if "spoiler" in n or "aleron" in n:
		return "ALERÓN"
	if "roof" in n or "techo" in n:
		return "TECHO"
	if "light" in n or "faro" in n or "luz" in n or "luces" in n:
		return "LUCES / FAROS"
	if "glass" in n or "vidrio" in n or "windshield" in n or "parabrisas" in n or "ventana" in n:
		return "VIDRIOS"
	if "antena" in n:
		return "ANTENA"
	if "tanque" in n or "tank" in n:
		return "TANQUES"
	if "pendejos" in n:
		return "ACCESORIOS EXTRAS"
	return n.replace("_", " ").to_upper().replace("Á", "A").replace("É", "E").replace("Í", "I").replace("Ó", "O").replace("Ú", "U")

func _clasificar_pieza(nombre_formateado: String) -> int:
	if "CARROCERÍA" in nombre_formateado or "CAPÓ" in nombre_formateado or "PUERTA" in nombre_formateado or "TECHO" in nombre_formateado or "COMPUERTA" in nombre_formateado:
		return 0
	if "PARACHOQUES" in nombre_formateado or "PARRILLA" in nombre_formateado or "GUARDAFANGO" in nombre_formateado or "ESPEJOS" in nombre_formateado or "VIDRIOS" in nombre_formateado:
		return 1
	return 2

func _abrir_pintura_general_completa() -> void:
	if not customizer_ref:
		return
	_reproducir_sonido_seleccion()
	customizer_ref.desactivar_xray()
	mesh_seleccionado_actual = null
	index_material_seleccionado = -1
	slot_color_seleccionado = 0
	if scroll_objetos: scroll_objetos.visible = false
	if container_materiales_objeto: container_materiales_objeto.visible = false
	if btn_volver_objetos: btn_volver_objetos.visible = false
	var col: Color = customizer_ref.color_actual
	color_seleccionado = col
	if color_picker:
		color_picker.set_color_hsv(col.h, col.s, max(col.v, 0.9))
		color_picker.visible = true
	if color_preview:
		color_preview.color = col
		color_preview.visible = true
	if btn_configurar:
		btn_configurar.visible = true
	if card_sliders:
		card_sliders.visible = false
	if slider_metallic: slider_metallic.value = customizer_ref.metallic_actual
	if slider_roughness: slider_roughness.value = customizer_ref.roughness_actual
	if slider_specular: slider_specular.value = customizer_ref.specular_actual
	_update_labels()

func _refrescar_lista_objetos() -> void:
	if not vbox_objetos or not customizer_ref:
		return
		
	for child in vbox_objetos.get_children():
		vbox_objetos.remove_child(child)
		child.queue_free()
		
	var font_path := "res://recursos/fonts/Moderniz.otf"
	var font = load(font_path) if ResourceLoader.exists(font_path) else null
	
	if customizer_ref.meshes_detectados.size() == 0:
		customizer_ref.detectar_meshes_personalizables()

	# Botón destacado para pintar toda la carrocería en un toque
	var btn_todo := Button.new()
	btn_todo.text = "🎨 PINTAR TODA LA CARROCERIA"
	btn_todo.focus_mode = Control.FOCUS_NONE
	btn_todo.custom_minimum_size = Vector2(0, 76)
	btn_todo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font: btn_todo.add_theme_font_override("font", font)
	btn_todo.add_theme_font_size_override("font_size", 26)
	var sb_todo := StyleBoxFlat.new()
	sb_todo.bg_color = Color(0.88, 0.68, 0.28, 0.92)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb_todo.set("corner_radius_" + side, 12)
	var sb_todo_h := sb_todo.duplicate() as StyleBoxFlat
	sb_todo_h.bg_color = Color(0.95, 0.76, 0.35, 1.0)
	btn_todo.add_theme_stylebox_override("normal", sb_todo)
	btn_todo.add_theme_stylebox_override("hover", sb_todo_h)
	btn_todo.add_theme_stylebox_override("pressed", sb_todo)
	btn_todo.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08, 1.0))
	btn_todo.pressed.connect(_abrir_pintura_general_completa)
	vbox_objetos.add_child(btn_todo)

	var grupos: Array = [[], [], []]
	for mesh in customizer_ref.meshes_detectados:
		if not is_instance_valid(mesh):
			continue
		var label_limpio := _formatear_nombre_pieza(mesh.name)
		var cat_idx := _clasificar_pieza(label_limpio)
		grupos[cat_idx].append({"mesh": mesh, "label": label_limpio})

	var titulos := ["CARROCERIA Y CABINA", "EXTERIOR Y PARACHOQUES", "ACCESORIOS Y DETALLES"]
	for g_idx in range(3):
		var items: Array = grupos[g_idx]
		if items.is_empty():
			continue
		items.sort_custom(func(a, b): return a["label"] < b["label"])

		var hdr := Label.new()
		hdr.text = titulos[g_idx]
		if font: hdr.add_theme_font_override("font", font)
		hdr.add_theme_font_size_override("font_size", 18)
		hdr.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.9))
		vbox_objetos.add_child(hdr)

		for item in items:
			var mesh: MeshInstance3D = item["mesh"]
			var btn = Button.new()
			btn.text = item["label"]
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(0, 68)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if font: btn.add_theme_font_override("font", font)
			btn.add_theme_font_size_override("font_size", 24)
			
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.09, 0.10, 0.12, 0.90)
			sb.border_width_left = 3
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(0.78, 0.81, 0.85, 0.22)
			for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
				sb.set("corner_radius_" + side, 12)
			sb.content_margin_left = 20
			sb.shadow_size = 4
			sb.shadow_color = Color(0, 0, 0, 0.35)
			
			var sb_h = sb.duplicate()
			sb_h.bg_color = Color(0.13, 0.15, 0.18, 0.95)
			sb_h.border_color = Color(0.88, 0.68, 0.28, 0.92)
			
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover", sb_h)
			btn.add_theme_stylebox_override("pressed", sb)
			
			btn.pressed.connect(func(): _on_objeto_seleccionado(mesh))
			vbox_objetos.add_child(btn)

func _on_objeto_seleccionado(mesh: MeshInstance3D) -> void:
	if not is_instance_valid(mesh) or not customizer_ref:
		return
		
	_reproducir_sonido_seleccion()
	mesh_seleccionado_actual = mesh
		
	customizer_ref.activar_xray_para_mesh(mesh)
	_mostrar_view_b()
	_refrescar_materiales_objeto()

func _on_volver_objetos_pressed() -> void:
	if customizer_ref:
		customizer_ref.desactivar_xray()
		
	mesh_seleccionado_actual = null
	index_material_seleccionado = -1
	
	_mostrar_view_a()

func _mostrar_view_a() -> void:
	if btn_volver_objetos: btn_volver_objetos.visible = false
	if container_materiales_objeto: container_materiales_objeto.visible = false
	if color_picker: color_picker.visible = false
	if color_preview: color_preview.visible = false
	if btn_configurar: btn_configurar.visible = false
	if card_sliders: card_sliders.visible = false
	if scroll_objetos: scroll_objetos.visible = true

func _mostrar_view_b() -> void:
	if scroll_objetos: scroll_objetos.visible = false
	if btn_volver_objetos: btn_volver_objetos.visible = false
	if container_materiales_objeto: container_materiales_objeto.visible = true
	if color_picker: color_picker.visible = false
	if color_preview: color_preview.visible = false
	if btn_configurar: btn_configurar.visible = false
	if card_sliders: card_sliders.visible = false

func _refrescar_materiales_objeto() -> void:
	if not container_materiales_objeto or not is_instance_valid(mesh_seleccionado_actual) or not customizer_ref:
		return
		
	for child in container_materiales_objeto.get_children():
		container_materiales_objeto.remove_child(child)
		child.queue_free()
		
	var font_path := "res://recursos/fonts/Moderniz.otf"
	var font = load(font_path) if ResourceLoader.exists(font_path) else null
	
	materiales_mesh_seleccionado = customizer_ref.obtener_materiales_de_mesh(mesh_seleccionado_actual)
	
	for i in range(materiales_mesh_seleccionado.size()):
		var entry = materiales_mesh_seleccionado[i]
		var mat = entry["material"]
		
		var col = Color.WHITE
		if customizer_ref and customizer_ref.has_method("_leer_color_material"):
			var info: Dictionary = customizer_ref._leer_color_material(mat)
			if not info.is_empty():
				col = info["color"]
		elif mat is StandardMaterial3D:
			col = mat.albedo_color
		elif mat is ShaderMaterial:
			for param in ["albedo", "paint_color", "albedo_color", "base_color", "color"]:
				var c = mat.get_shader_parameter(param)
				if c != null:
					col = c
					break
			
		# Crear panel contenedor de la tarjeta premium
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 80)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var sb_r = StyleBoxFlat.new()
		sb_r.bg_color = Color(0.08, 0.08, 0.12, 0.85)
		sb_r.border_width_left = 2
		sb_r.border_width_top = 2
		sb_r.border_width_right = 2
		sb_r.border_width_bottom = 2
		sb_r.border_color = Color(0.18, 0.18, 0.28, 0.8)
		for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			sb_r.set("corner_radius_" + side, 14)
		card.add_theme_stylebox_override("panel", sb_r)
		
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 20)
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(hbox)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(10, 0)
		hbox.add_child(spacer)
		
		# Contenedor del swatch de color con borde blanco y redondeado
		var swatch_border = PanelContainer.new()
		swatch_border.custom_minimum_size = Vector2(48, 48)
		swatch_border.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var sb_sw = StyleBoxFlat.new()
		sb_sw.bg_color = col
		sb_sw.border_width_left = 3
		sb_sw.border_width_top = 3
		sb_sw.border_width_right = 3
		sb_sw.border_width_bottom = 3
		sb_sw.border_color = Color(1.0, 1.0, 1.0, 0.95)
		for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			sb_sw.set("corner_radius_" + side, 8)
		swatch_border.add_theme_stylebox_override("panel", sb_sw)
		swatch_border.name = "SwatchBorder"
		hbox.add_child(swatch_border)
		
		# Etiqueta del nombre (Forzar COLOR X)
		var lbl = Label.new()
		lbl.text = "COLOR " + str(i + 1)
		if font: lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hbox.add_child(lbl)
		
		# Botón invisible overlay
		var invisible_btn = Button.new()
		invisible_btn.focus_mode = Control.FOCUS_NONE
		invisible_btn.flat = true
		invisible_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		invisible_btn.anchor_left = 0.0
		invisible_btn.anchor_top = 0.0
		invisible_btn.anchor_right = 1.0
		invisible_btn.anchor_bottom = 1.0
		invisible_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
		invisible_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
		card.add_child(invisible_btn)
		
		var index = i
		invisible_btn.pressed.connect(func(): _seleccionar_material_slot_objeto(index))
		container_materiales_objeto.add_child(card)
		
	if materiales_mesh_seleccionado.size() > 0:
		_seleccionar_material_slot_objeto(0)

func _seleccionar_material_slot_objeto(index: int) -> void:
	index_material_seleccionado = index
	if index < 0 or index >= materiales_mesh_seleccionado.size():
		return
		
	_reproducir_sonido_seleccion()
		
	for i in range(container_materiales_objeto.get_child_count()):
		var card = container_materiales_objeto.get_child(i) as PanelContainer
		var sb = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if i == index:
			sb.bg_color = Color(0.95, 0.8, 0.0, 0.15)
			sb.border_width_left = 3
			sb.border_width_top = 3
			sb.border_width_right = 3
			sb.border_width_bottom = 3
			sb.border_color = Color(0.95, 0.8, 0.0, 1.0)
		else:
			sb.bg_color = Color(0.08, 0.08, 0.12, 0.85)
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(0.18, 0.18, 0.28, 0.8)
		card.add_theme_stylebox_override("panel", sb)
		
	var entry = materiales_mesh_seleccionado[index]
	var mat = entry["material"]
	
	var col = Color.WHITE
	var met = 0.0
	var rough = 0.5
	var spec = 0.5
	
	if customizer_ref and customizer_ref.has_method("_leer_color_material"):
		var info: Dictionary = customizer_ref._leer_color_material(mat)
		if not info.is_empty():
			col = info["color"]
			met = info["metallic"]
			rough = info["roughness"]
			spec = info["specular"]
	elif mat is StandardMaterial3D:
		col = mat.albedo_color
		met = mat.metallic
		rough = mat.roughness
		spec = mat.metallic_specular
	elif mat is ShaderMaterial:
		for param in ["albedo", "paint_color", "albedo_color", "base_color", "color"]:
			var c = mat.get_shader_parameter(param)
			if c != null:
				col = c
				break
		var m = mat.get_shader_parameter("metallic")
		if m != null: met = m
		var r = mat.get_shader_parameter("roughness")
		if r != null: rough = r
		
	color_seleccionado = col
	if color_picker:
		color_picker.set_color_hsv(col.h, col.s, col.v)
		color_picker.visible = true
		
	if color_preview:
		color_preview.color = col
		color_preview.visible = true
		
	if btn_configurar:
		btn_configurar.visible = true
		
	if card_sliders:
		card_sliders.visible = false
	if btn_configurar:
		btn_configurar.text = "CONFIGURAR MATERIAL"
		btn_configurar.remove_theme_stylebox_override("normal")
		btn_configurar.add_theme_color_override("font_color", Color(0.95, 0.8, 0.0, 1.0))
		
	if slider_metallic: slider_metallic.value = met
	if slider_roughness: slider_roughness.value = rough
	if slider_specular: slider_specular.value = spec
	
	_update_labels()

func _reproducir_sonido_seleccion() -> void:
	var path := "res://recursos/sonidos_vehiculo/efectos/seleccion1.mp3"
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream and is_inside_tree():
			var player = AudioStreamPlayer.new()
			player.stream = stream
			player.bus = &"Master"
			add_child(player)
			player.play()
			player.finished.connect(func(): player.queue_free())

func _process(_delta: float) -> void:
	if taller_ref and is_instance_valid(taller_ref) and not is_dragging_cam_slider:
		if slider_cam_zoom:
			slider_cam_zoom.value = taller_ref.target_distance
		if slider_cam_rot:
			var y_angle = fmod(taller_ref.target_yaw + 180.0, 360.0)
			if y_angle < 0:
				y_angle += 360.0
			slider_cam_rot.value = y_angle - 180.0
		if slider_cam_alt and taller_ref.vehiculo_dentro:
			slider_cam_alt.value = taller_ref.target_pivot_pos.y

# ═══════════════════════════════════════════════════════════════════════
# Métodos del Menú Principal de Categorías
# ═══════════════════════════════════════════════════════════════════════

func _inicializar_menu_categorias() -> void:
	if is_instance_valid(container_menu_categorias):
		_ir_a_menu_principal()
		return

	var panel_fondo = get_node_or_null("PanelFondo")
	if not panel_fondo:
		return
		
	var font_path := "res://recursos/fonts/Moderniz.otf"
	var font = load(font_path) if ResourceLoader.exists(font_path) else null
	
	# 1. Botón "VOLVER" principal
	btn_volver_menu_principal = Button.new()
	btn_volver_menu_principal.text = "VOLVER"
	btn_volver_menu_principal.focus_mode = Control.FOCUS_NONE
	btn_volver_menu_principal.custom_minimum_size = Vector2(250, 60)
	if font: btn_volver_menu_principal.add_theme_font_override("font", font)
	btn_volver_menu_principal.add_theme_font_size_override("font_size", 30)
	btn_volver_menu_principal.visible = false
	
	var sb_v = StyleBoxFlat.new()
	sb_v.bg_color = Color(0.08, 0.09, 0.11, 0.85)
	for s in ["left", "top", "right", "bottom"]:
		sb_v.set("border_width_" + s, 1)
	sb_v.border_color = Color(0.78, 0.81, 0.85, 0.25)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb_v.set("corner_radius_" + side, 12)
	sb_v.shadow_size = 4
	sb_v.shadow_color = Color(0, 0, 0, 0.4)
		
	var sb_v_h = sb_v.duplicate() as StyleBoxFlat
	sb_v_h.bg_color = Color(0.12, 0.14, 0.17, 0.92)
	sb_v_h.border_color = Color(0.88, 0.68, 0.28, 0.92)
	
	btn_volver_menu_principal.add_theme_stylebox_override("normal", sb_v)
	btn_volver_menu_principal.add_theme_stylebox_override("hover", sb_v_h)
	btn_volver_menu_principal.pressed.connect(_on_volver_menu_principal_pressed)
	
	panel_fondo.add_child(btn_volver_menu_principal)
	
	# Copiar posición y anclajes exactos del contenedor HBoxContainer de guardar/cancelar, pero centrado y con un ancho premium balanceado
	var hbox_btns = get_node_or_null("PanelFondo/HBoxContainer")
	if hbox_btns:
		btn_volver_menu_principal.anchor_left = 0.5
		btn_volver_menu_principal.anchor_right = 0.5
		btn_volver_menu_principal.anchor_top = 1.0
		btn_volver_menu_principal.anchor_bottom = 1.0
		btn_volver_menu_principal.offset_left = -175
		btn_volver_menu_principal.offset_right = 175
		btn_volver_menu_principal.offset_top = -110
		btn_volver_menu_principal.offset_bottom = -50
		btn_volver_menu_principal.grow_horizontal = Control.GROW_DIRECTION_BOTH
		btn_volver_menu_principal.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# 2. Contenedor de categorías
	container_menu_categorias = VBoxContainer.new()
	container_menu_categorias.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container_menu_categorias.add_theme_constant_override("separation", 20)
	
	panel_fondo.add_child(container_menu_categorias)
	container_menu_categorias.anchor_left = 0.05
	container_menu_categorias.anchor_right = 0.95
	container_menu_categorias.anchor_top = 0.18
	container_menu_categorias.anchor_bottom = 0.82
	container_menu_categorias.offset_left = 0
	container_menu_categorias.offset_right = 0
	container_menu_categorias.offset_top = 0
	container_menu_categorias.offset_bottom = 0
	container_menu_categorias.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container_menu_categorias.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var categorias = [
		{"name": "🎨 PINTURA GENERAL", "tab": 0, "focus": "enfocar_carroceria"},
		{"name": "🎭 VINILOS DEPORTIVOS", "tab": 1, "focus": "enfocar_carroceria"},
		{"name": "🛞 RUEDAS Y ALINEACION", "tab": 2, "focus": "enfocar_rines"},
		{"name": "⚙️ DETALLES Y NEON", "tab": 3, "focus": "enfocar_neon"},
		{"name": "🏷️ PLACAS DE SERVICIO", "tab": 4, "focus": "enfocar_placas"}
	]
	
	for cat in categorias:
		var btn = Button.new()
		var clean_name = cat["name"].to_upper().replace("Á", "A").replace("É", "E").replace("Í", "I").replace("Ó", "O").replace("Ú", "U")
		btn.text = clean_name
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 75)
		if font: btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.09, 0.11, 0.86)
		sb.border_width_left = 3
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.88, 0.68, 0.28, 0.72)
		for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			sb.set("corner_radius_" + side, 12)
		sb.content_margin_left = 25
		sb.shadow_size = 5
		sb.shadow_color = Color(0, 0, 0, 0.4)
		
		var sb_h = sb.duplicate() as StyleBoxFlat
		sb_h.bg_color = Color(0.13, 0.15, 0.18, 0.94)
		sb_h.border_color = Color(0.88, 0.68, 0.28, 1.0)
		sb_h.shadow_color = Color(0.88, 0.68, 0.28, 0.18)
		sb_h.shadow_size = 6
		
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("pressed", sb)
		
		btn.pressed.connect(func(): _abrir_categoria(cat["tab"], cat["focus"]))
		container_menu_categorias.add_child(btn)
		
	_ir_a_menu_principal()

func _ir_a_menu_principal() -> void:
	if container_menu_categorias: container_menu_categorias.visible = true
	if tab_container: tab_container.visible = false
	
	var custom_tab_bar = get_node_or_null("PanelFondo/CustomTabBar")
	if custom_tab_bar: custom_tab_bar.visible = false
	
	if btn_volver_menu_principal: btn_volver_menu_principal.visible = false
	
	var hbox_btns = get_node_or_null("PanelFondo/HBoxContainer")
	if hbox_btns: hbox_btns.visible = true
	
	if customizer_ref:
		customizer_ref.desactivar_xray()
		
	mesh_seleccionado_actual = null
	index_material_seleccionado = -1

func _abrir_categoria(tab_idx: int, _focus_method: String) -> void:
	_reproducir_sonido_seleccion()
	
	if container_menu_categorias: container_menu_categorias.visible = false
	
	if tab_container:
		tab_container.visible = true
		_cambiar_tab(tab_idx)
		
	var hbox_btns = get_node_or_null("PanelFondo/HBoxContainer")
	if hbox_btns: hbox_btns.visible = false
	
	if btn_volver_menu_principal: btn_volver_menu_principal.visible = true

func _on_volver_menu_principal_pressed() -> void:
	_reproducir_sonido_seleccion()
	
	if tab_container and tab_container.current_tab == 0 and (is_instance_valid(mesh_seleccionado_actual) or (scroll_objetos and not scroll_objetos.visible)):
		_on_volver_objetos_pressed()
	else:
		_ir_a_menu_principal()
