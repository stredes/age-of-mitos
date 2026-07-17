class_name PopulationDisplay
extends Control

@export var show_percentage: bool = true
@export var show_max: bool = true
@export var alert_threshold: float = 0.85
@export var critical_threshold: float = 0.95
@export var pulse_speed: float = 3.0
@export var bar_height: int = 8
@export var font_size: int = 16

var _current_label: Label = null
var _max_label: Label = null
var _progress_bar: ProgressBar = null
var _percentage_label: Label = null
var _warning_icon: TextureRect = null
var _player_id: int = 1
var _current_pop: int = 0
var _max_pop: int = 0
var _pulse_timer: float = 0.0
var _is_alert: bool = false
var _is_critical: bool = false
var _normal_color: Color = Color(0.85, 0.85, 0.9, 1.0)
var _alert_color: Color = Color(1.0, 0.75, 0.2, 1.0)
var _critical_color: Color = Color(1.0, 0.3, 0.3, 1.0)

func _ready() -> void:
	_player_id = GameManager.get_local_player_id()
	_build_ui()
	_connect_signals()
	_update_display()


func _build_ui() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	layout_mode = LAYOUT_MODE_ANCHORED
	set_anchors_preset(PRESET_TOP_RIGHT)
	offset_right = -16
	offset_top = 8
	custom_minimum_size = Vector2(120, 48)

	var hbox = HBoxContainer.new()
	hbox.name = "PopContainer"
	hbox.alignment = HBoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 6)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 0
	hbox.offset_top = 0
	hbox.offset_right = 0
	hbox.offset_bottom = 0
	add_child(hbox)

	var vbox = VBoxContainer.new()
	vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	_current_label = Label.new()
	_current_label.name = "CurrentLabel"
	_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_current_label.add_theme_font_size_override("font_size", font_size + 2)
	_current_label.add_theme_color_override("font_color", _normal_color)
	_current_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_current_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_current_label)

	if show_max:
		_max_label = Label.new()
		_max_label.name = "MaxLabel"
		_max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_max_label.add_theme_font_size_override("font_size", font_size - 4)
		_max_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1.0))
		vbox.add_child(_max_label)

	if show_percentage:
		_percentage_label = Label.new()
		_percentage_label.name = "PercentageLabel"
		_percentage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_percentage_label.add_theme_font_size_override("font_size", font_size - 4)
		_percentage_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1.0))
		vbox.add_child(_percentage_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "PopBar"
	_progress_bar.custom_minimum_size = Vector2(80, bar_height)
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(_progress_bar)

	_warning_icon = TextureRect.new()
	_warning_icon.name = "WarningIcon"
	_warning_icon.custom_minimum_size = Vector2i(20, 20)
	_warning_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_warning_icon.visible = false
	_warning_icon.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.add_child(_warning_icon)

	var warning_shader = Shader.new()
	warning_shader.code = """
	shader_type canvas_item;
	render_mode unshaded;
	uniform float pulse : hint_range(0, 1);
	void fragment() {
		COLOR = texture(TEXTURE, UV);
		COLOR.a *= smoothstep(0.3, 0.7, sin(TIME * 10.0 + UV.x * 20.0) * 0.5 + 0.5) * pulse + (1.0 - pulse);
	}
	"""
	_warning_icon.material = ShaderMaterial.new()
	_warning_icon.material.shader = warning_shader


func _connect_signals() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.population_changed.connect(_on_population_changed)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_destroyed.connect(_on_building_destroyed)


func _process(delta: float) -> void:
	if _is_alert or _is_critical:
		_pulse_timer += delta * pulse_speed
		var pulse = (sin(_pulse_timer) * 0.5 + 0.5)
		_progress_bar.material.set_shader_parameter("pulse", pulse)

		var color = _is_critical ? _critical_color : _alert_color
		var target_color = _normal_color.lerp(color, pulse * 0.6)
		_current_label.add_theme_color_override("font_color", target_color)

		if _warning_icon.texture != null:
			_warning_icon.material.set_shader_parameter("pulse", pulse)


func _on_population_changed(player_id: int, current: int, max_pop: int) -> void:
	if player_id != _player_id:
		return
	_current_pop = current
	_max_pop = max_pop
	_update_display()


func _on_resources_changed(player_id: int, resources: Dictionary) -> void:
	if player_id != _player_id:
		return
	_update_display()


func _on_building_placed(building_type: String, position: Vector2, player_id: int) -> void:
	if player_id != _player_id:
		return
	if building_type in ["house", "town_center"]:
		call_deferred("_refresh_pop_cap")


func _on_building_destroyed(building_id: int, player_id: int) -> void:
	if player_id != _player_id:
		return
	call_deferred("_refresh_pop_cap")


func _refresh_pop_cap() -> void:
	var game_manager = GameManager.get_singleton()
	if game_manager != null and game_manager.has_method("get_population_cap"):
		_max_pop = game_manager.get_population_cap(_player_id)
	_update_display()


func _update_display() -> void:
	var pct = _max_pop > 0 ? float(_current_pop) / float(_max_pop) : 0.0
	var pct_rounded = int(pct * 100)

	_current_label.text = str(_current_pop)
	_current_label.add_theme_color_override("font_color", _normal_color)

	if _max_label:
		_max_label.text = "/ " + str(_max_pop)

	if _percentage_label:
		_percentage_label.text = str(pct_rounded) + "%"

	_progress_bar.max_value = _max_pop
	_progress_bar.value = _current_pop

	var was_alert = _is_alert
	var was_critical = _is_critical

	_is_alert = pct >= alert_threshold and pct < critical_threshold
	_is_critical = pct >= critical_threshold

	if _is_critical:
		_warning_icon.visible = true
		var icon_img = _create_warning_icon(_critical_color)
		_warning_icon.texture = ImageTexture.create_from_image(icon_img)
		_warning_icon.tooltip_text = "¡POBLACIÓN MÁXIMA!"
	elif _is_alert:
		_warning_icon.visible = true
		var icon_img = _create_warning_icon(_alert_color)
		_warning_icon.texture = ImageTexture.create_from_image(icon_img)
		_warning_icon.tooltip_text = "Población cerca del límite"
	else:
		_warning_icon.visible = false

	if _is_alert != was_alert or _is_critical != was_critical:
		_pulse_timer = 0.0
		if _is_critical:
			AudioManager.play_sfx("res://audio/sfx/pop_warning.wav")
		elif _is_alert and not was_alert:
			AudioManager.play_sfx("res://audio/sfx/pop_alert.wav")


func _create_warning_icon(color: Color) -> Image:
	var size = 20
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var cx = size / 2
	var cy = size / 2
	var outer_r = size * 0.45
	var inner_r = size * 0.15

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy
			var dist = sqrt(dx * dx + dy * dy)

			if dist < outer_r and dist > inner_r:
				var angle = atan2(dy, dx)
				if angle < -2.09 or angle > 2.09 or (angle > -0.52 and angle < 0.52):
					var t = (dist - inner_r) / (outer_r - inner_r)
					var c = color
					c.a = 1.0 - t * 0.3
					img.set_pixel(x, y, c)

			if y == cy and dist < outer_r:
				img.set_pixel(x, y, color)

	return img


func get_population_ratio() -> float:
	return _max_pop > 0 ? float(_current_pop) / float(_max_pop) : 0.0


func is_near_cap() -> bool:
	return _is_alert


func is_at_cap() -> bool:
	return _is_critical