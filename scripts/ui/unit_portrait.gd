extends PanelContainer

signal stance_changed(new_stance: String)

const PORTRAIT_SIZE: Vector2 = Vector2(64, 64)
const BG_COLOR: Color = Color(0.08, 0.08, 0.14, 0.9)
const BORDER_COLOR: Color = Color(0.35, 0.35, 0.35, 1.0)
const BORDER_SELECTED: Color = Color(0.9, 0.85, 0.2, 1.0)

var _portrait_image: Image = null
var _portrait_texture: ImageTexture = null
var _current_type: String = ""
var _hp_bar: ProgressBar = null
var _name_label: Label = null
var _hp_label: Label = null
var _unit_node: Node = null

var UNIT_COLORS: Dictionary = {
	"villager": Color(0.75, 0.55, 0.3),
	"swordsman": Color(0.8, 0.3, 0.2),
	"archer": Color(0.2, 0.6, 0.25),
	"horseman": Color(0.6, 0.4, 0.15),
	"spearman": Color(0.3, 0.3, 0.7),
	"priest": Color(0.85, 0.8, 0.55),
	"catapult": Color(0.5, 0.5, 0.5),
}


func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	_build_ui()
	_set_empty()


func _build_ui() -> void:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = BG_COLOR
	bg.border_color = BORDER_COLOR
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.border_width_top = 2
	bg.border_width_bottom = 2
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 4
	bg.content_margin_right = 4
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	add_theme_stylebox_override("panel", bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var portrait_rect: TextureRect = TextureRect.new()
	portrait_rect.name = "Portrait"
	portrait_rect.custom_minimum_size = PORTRAIT_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vbox.add_child(portrait_rect)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text = ""
	vbox.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HPBar"
	_hp_bar.custom_minimum_size = Vector2(60, 6)
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.2, 0.8, 0.2)
	hp_fill.corner_radius_top_left = 2
	hp_fill.corner_radius_top_right = 2
	hp_fill.corner_radius_bottom_left = 2
	hp_fill.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.15, 0.15, 0.15)
	hp_bg.corner_radius_top_left = 2
	hp_bg.corner_radius_top_right = 2
	hp_bg.corner_radius_bottom_left = 2
	hp_bg.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	vbox.add_child(_hp_bar)


func show_unit(unit_type: String, unit_node: Node = null) -> void:
	if unit_type == _current_type and unit_node == _unit_node:
		return
	_current_type = unit_type
	_unit_node = unit_node
	_generate_portrait(unit_type)
	_name_label.text = unit_type.capitalize()
	if unit_node != null and unit_node.has_method("get") and unit_node.get("current_hp") != null and unit_node.get("max_hp") != null:
		_hp_bar.max_value = unit_node.max_hp
		_hp_bar.value = unit_node.current_hp
	else:
		_hp_bar.max_value = 100
		_hp_bar.value = 100
	visible = true


func show_empty() -> void:
	_set_empty()


func _set_empty() -> void:
	_current_type = ""
	_unit_node = null
	_name_label.text = ""
	_hp_bar.value = 0
	visible = false


func _generate_portrait(unit_type: String) -> void:
	_portrait_image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_portrait_image.fill(Color(0, 0, 0, 0))

	var base_color: Color = UNIT_COLORS.get(unit_type, Color(0.6, 0.5, 0.4))

	match unit_type:
		"villager":
			_draw_face(base_color)
			_draw_hat(Color(0.6, 0.4, 0.2))
		"swordsman":
			_draw_face(base_color)
			_draw_helmet(Color(0.5, 0.5, 0.55))
			_draw_beard(Color(0.3, 0.2, 0.1))
		"archer":
			_draw_face(base_color)
			_draw_hood(Color(0.15, 0.45, 0.15))
		"horseman":
			_draw_face(base_color)
			_draw_helmet(Color(0.65, 0.55, 0.2))
			_draw_mustache(Color(0.2, 0.15, 0.05))
		"spearman":
			_draw_face(base_color)
			_draw_helmet(Color(0.4, 0.45, 0.5))
		"priest":
			_draw_face(base_color)
			_draw_halo(Color(0.95, 0.9, 0.5))
		"catapult":
			_draw_siege(Color(0.5, 0.5, 0.5))
		_:
			_draw_face(base_color)

	_portrait_texture = ImageTexture.create_from_image(_portrait_image)
	var tex_rect: TextureRect = get_node_or_null("VBox/Portrait") as TextureRect
	if tex_rect != null:
		tex_rect.texture = _portrait_texture


func _draw_face(color: Color) -> void:
	# Head shape: 6x6 centered block
	for y in range(5, 11):
		for x in range(5, 11):
			_portrait_image.set_pixel(x, y, color)
	# Eyes
	_portrait_image.set_pixel(6, 7, Color.WHITE)
	_portrait_image.set_pixel(9, 7, Color.WHITE)
	_portrait_image.set_pixel(6, 8, Color(0.1, 0.1, 0.1))
	_portrait_image.set_pixel(9, 8, Color(0.1, 0.1, 0.1))
	# Mouth
	_portrait_image.set_pixel(7, 10, Color(0.5, 0.2, 0.15))
	_portrait_image.set_pixel(8, 10, Color(0.5, 0.2, 0.15))


func _draw_hat(color: Color) -> void:
	for x in range(4, 12):
		_portrait_image.set_pixel(x, 4, color)
	for x in range(5, 11):
		_portrait_image.set_pixel(x, 3, color)
	_portrait_image.set_pixel(7, 2, color)
	_portrait_image.set_pixel(8, 2, color)


func _draw_helmet(color: Color) -> void:
	for x in range(4, 12):
		_portrait_image.set_pixel(x, 4, color)
		_portrait_image.set_pixel(x, 5, color)
	for x in range(5, 11):
		_portrait_image.set_pixel(x, 3, color)
	# Nose guard
	_portrait_image.set_pixel(7, 6, color)
	_portrait_image.set_pixel(7, 7, color)
	_portrait_image.set_pixel(8, 6, color)
	_portrait_image.set_pixel(8, 7, color)


func _draw_hood(color: Color) -> void:
	for x in range(3, 13):
		_portrait_image.set_pixel(x, 3, color)
		_portrait_image.set_pixel(x, 4, color)
	for x in range(4, 12):
		_portrait_image.set_pixel(x, 2, color)
	_portrait_image.set_pixel(5, 5, color)
	_portrait_image.set_pixel(10, 5, color)


func _draw_beard(color: Color) -> void:
	for x in range(6, 10):
		_portrait_image.set_pixel(x, 11, color)
		_portrait_image.set_pixel(x, 12, color)
	_portrait_image.set_pixel(6, 13, color)
	_portrait_image.set_pixel(9, 13, color)


func _draw_mustache(color: Color) -> void:
	for x in range(6, 10):
		_portrait_image.set_pixel(x, 10, color)


func _draw_halo(color: Color) -> void:
	for x in range(5, 11):
		_portrait_image.set_pixel(x, 2, color)
	_portrait_image.set_pixel(4, 3, color)
	_portrait_image.set_pixel(11, 3, color)


func _draw_siege(color: Color) -> void:
	# Simple wooden frame
	for y in range(4, 12):
		_portrait_image.set_pixel(5, y, Color(0.45, 0.3, 0.1))
		_portrait_image.set_pixel(10, y, Color(0.45, 0.3, 0.1))
	for x in range(5, 11):
		_portrait_image.set_pixel(x, 5, Color(0.45, 0.3, 0.1))
		_portrait_image.set_pixel(x, 8, Color(0.45, 0.3, 0.1))
	# Boulder
	_portrait_image.set_pixel(7, 3, color)
	_portrait_image.set_pixel(8, 3, color)
	_portrait_image.set_pixel(7, 4, color)
	_portrait_image.set_pixel(8, 4, color)
	_portrait_image.set_pixel(6, 4, color)
	_portrait_image.set_pixel(9, 4, color)
