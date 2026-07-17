class_name HUD
extends Control

@export var resource_bar_height: int = 48
@export var icon_size: Vector2i = Vector2i(24, 24)
@export var font_size: int = 18
@export var update_interval: float = 0.5
@export var low_pop_threshold: float = 0.85
@export var critical_pop_threshold: float = 0.95

var _resource_icons: Dictionary = {}
var _resource_labels: Dictionary = {}
var _income_labels: Dictionary = {}
var _pop_current_label: Label = null
var _pop_max_label: Label = null
var _pop_bar: ProgressBar = null
var _idle_villagers_label: Label = null
var _idle_villagers_button: TextureButton = null
var _speed_buttons: Array[TextureButton] = []
var _current_speed: int = 1
var _resource_factory: ResourceIconFactory = null
var _update_timer: float = 0.0
var _player_id: int = 1
var _last_resources: Dictionary = {}
var _last_pop: int = 0
var _last_pop_max: int = 0

func _ready() -> void:
	_resource_factory = ResourceIconFactory.new()
	_resource_factory.icon_size = icon_size
	add_child(_resource_factory)

	_player_id = GameManager.get_local_player_id()
	_build_ui()
	_connect_signals()
	_update_all()


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_all()
		_update_timer = 0.0


func _build_ui() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	layout_mode = LAYOUT_MODE_ANCHORED
	set_anchors_preset(PRESET_TOP_WIDE)
	offset_top = 0
	offset_bottom = resource_bar_height
	offset_left = 0
	offset_right = 0

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.07, 0.92)
	bg.border_width_bottom = 2
	bg.border_color = Color(0.2, 0.2, 0.25, 1.0)
	add_theme_stylebox_override("panel", bg)

	var hbox = HBoxContainer.new()
	hbox.name = "ResourceBar"
	hbox.alignment = HBoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 16)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 16
	hbox.offset_right = -16
	hbox.offset_top = 4
	hbox.offset_bottom = -4
	add_child(hbox)

	_build_resource_section(hbox, "wood", "Madera")
	_build_resource_section(hbox, "food", "Comida")
	_build_resource_section(hbox, "stone", "Piedra")
	_build_resource_section(hbox, "gold", "Oro")

	var separator = VSeparator.new()
	separator.custom_minimum_size = Vector2(2, 28)
	hbox.add_child(separator)

	_build_population_section(hbox)
	_build_idle_villagers_section(hbox)
	_build_speed_controls(hbox)


func _build_resource_section(parent: HBoxContainer, resource_id: String, display_name: String) -> void:
	var vbox = VBoxContainer.new()
	vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	parent.add_child(vbox)

	var icon = TextureRect.new()
	icon.name = resource_id + "_icon"
	icon.custom_minimum_size = icon_size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture = _resource_factory.get_icon(resource_id)
	vbox.add_child(icon)
	_resource_icons[resource_id] = icon

	var hbox = HBoxContainer.new()
	hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 2)
	vbox.add_child(hbox)

	var amount_label = Label.new()
	amount_label.name = resource_id + "_amount"
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", font_size)
	amount_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	amount_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	amount_label.add_theme_constant_override("outline_size", 2)
	amount_label.text = "0"
	hbox.add_child(amount_label)
	_resource_labels[resource_id] = amount_label

	var income_label = Label.new()
	income_label.name = resource_id + "_income"
	income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	income_label.add_theme_font_size_override("font_size", 11)
	income_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	income_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	income_label.add_theme_constant_override("outline_size", 1)
	income_label.text = "+0/s"
	income_label.visible = false
	hbox.add_child(income_label)
	_income_labels[resource_id] = income_label

	amount_label.mouse_entered.connect(_on_resource_hover.bind(resource_id, true))
	amount_label.mouse_exited.connect(_on_resource_hover.bind(resource_id, false))


func _build_population_section(parent: HBoxContainer) -> void:
	var vbox = VBoxContainer.new()
	vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	parent.add_child(vbox)

	var pop_icon = TextureRect.new()
	pop_icon.custom_minimum_size = icon_size
	pop_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pop_icon.texture = _resource_factory.get_icon("population")
	vbox.add_child(pop_icon)

	var hbox = HBoxContainer.new()
	hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 2)
	vbox.add_child(hbox)

	_pop_current_label = Label.new()
	_pop_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pop_current_label.add_theme_font_size_override("font_size", font_size)
	_pop_current_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_pop_current_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_pop_current_label.add_theme_constant_override("outline_size", 2)
	_pop_current_label.text = "0"
	hbox.add_child(_pop_current_label)

	var slash = Label.new()
	slash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slash.add_theme_font_size_override("font_size", font_size)
	slash.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	slash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	slash.add_theme_constant_override("outline_size", 2)
	slash.text = "/"
	hbox.add_child(slash)

	_pop_max_label = Label.new()
	_pop_max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pop_max_label.add_theme_font_size_override("font_size", font_size)
	_pop_max_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_pop_max_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_pop_max_label.add_theme_constant_override("outline_size", 2)
	_pop_max_label.text = "0"
	hbox.add_child(_pop_max_label)

	_pop_bar = ProgressBar.new()
	_pop_bar.custom_minimum_size = Vector2(100, 6)
	_pop_bar.min_value = 0
	_pop_bar.max_value = 100
	_pop_bar.value = 0
	_pop_bar.show_percentage = false
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.12, 1.0)
	bar_bg.border_width_all = 1
	bar_bg.border_color = Color(0.25, 0.25, 0.3, 1.0)
	bar_bg.corner_radius_all = 3
	_pop_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.7, 0.25, 1.0)
	bar_fill.corner_radius_all = 3
	_pop_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_pop_bar)

	_pop_current_label.mouse_entered.connect(_on_pop_hover.bind(true))
	_pop_current_label.mouse_exited.connect(_on_pop_hover.bind(false))


func _build_idle_villagers_section(parent: HBoxContainer) -> void:
	var vbox = VBoxContainer.new()
	vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	parent.add_child(vbox)

	var btn = TextureButton.new()
	btn.name = "IdleVillagersButton"
	btn.custom_minimum_size = Vector2(40, 40)
	btn.focus_mode = FOCUS_NONE
	btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED

	var idle_icon = _resource_factory.get_icon("idle_villager")
	if idle_icon == null:
		idle_icon = _resource_factory.get_icon("food")
	btn.texture_normal = idle_icon

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.12, 0.14, 0.9)
	btn_normal.border_width_all = 1
	btn_normal.border_color = Color(0.3, 0.3, 0.35, 1.0)
	btn_normal.corner_radius_all = 6
	btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.18, 0.18, 0.22, 0.95)
	btn_hover.border_color = Color(0.5, 0.7, 0.4, 1.0)
	btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	btn_pressed.border_color = Color(0.3, 0.5, 0.35, 1.0)
	btn.add_theme_stylebox_override("pressed", btn_pressed)

	btn.tooltip_text = "Aldeanos ociosos (clic para seleccionar todos)"
	btn.pressed.connect(_on_idle_villagers_pressed)
	vbox.add_child(btn)
	_idle_villagers_button = btn

	_idle_villagers_label = Label.new()
	_idle_villagers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle_villagers_label.add_theme_font_size_override("font_size", 12)
	_idle_villagers_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
	_idle_villagers_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_idle_villagers_label.add_theme_constant_override("outline_size", 1)
	_idle_villagers_label.text = "0"
	vbox.add_child(_idle_villagers_label)


func _build_speed_controls(parent: HBoxContainer) -> void:
	var separator = VSeparator.new()
	separator.custom_minimum_size = Vector2(2, 28)
	parent.add_child(separator)

	var vbox = VBoxContainer.new()
	vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	parent.add_child(vbox)

	var speed_label = Label.new()
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.add_theme_font_size_override("font_size", 11)
	speed_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	speed_label.text = "VELOCIDAD"
	vbox.add_child(speed_label)

	var hbox = HBoxContainer.new()
	hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	var speeds = [1, 2, 3]
	var speed_labels = ["1x", "2x", "3x"]

	for i in speeds.size():
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(44, 28)
		btn.focus_mode = FOCUS_NONE

		var label = Label.new()
		label.text = speed_labels[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 1)
		label.mouse_filter = MOUSE_FILTER_IGNORE
		btn.add_child(label)

		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.12, 0.12, 0.14, 0.9)
		btn_normal.border_width_all = 1
		btn_normal.border_color = Color(0.3, 0.3, 0.35, 1.0)
		btn_normal.corner_radius_all = 4
		btn.add_theme_stylebox_override("normal", btn_normal)

		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color(0.18, 0.18, 0.22, 0.95)
		btn_hover.border_color = Color(0.5, 0.5, 0.6, 1.0)
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed = btn_normal.duplicate()
		btn_pressed.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		btn_pressed.border_color = Color(0.3, 0.3, 0.35, 1.0)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		var btn_focus = btn_normal.duplicate()
		btn_focus.border_color = Color(0.2, 0.6, 1.0, 1.0)
		btn_focus.border_width_all = 2
		btn.add_theme_stylebox_override("focus", btn_focus)

		if speeds[i] == _current_speed:
			btn.disabled = true

		btn.pressed.connect(_on_speed_pressed.bind(speeds[i]))
		hbox.add_child(btn)
		_speed_buttons.append(btn)


func _connect_signals() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.population_changed.connect(_on_population_changed)
	EventBus.idle_villagers_changed.connect(_on_idle_villagers_changed)
	EventBus.game_speed_changed.connect(_on_game_speed_changed)


func _update_all() -> void:
	_update_resources()
	_update_population()
	_update_idle_villagers()


func _update_resources() -> void:
	var resource_manager = ResourceManager.get_singleton()
	if resource_manager == null:
		return

	var resources = ["wood", "food", "stone", "gold"]
	for res in resources:
		var amount = resource_manager.get_resource_amount(res, _player_id)
		var income = resource_manager.get_resource_income(res, _player_id)

		if _resource_labels.has(res):
			_resource_labels[res].text = _format_number(amount)

		if _income_labels.has(res):
			if income != 0:
				_income_labels[res].visible = true
				var color = Color(0.5, 0.9, 0.5) if income > 0 else Color(0.9, 0.4, 0.4)
				_income_labels[res].add_theme_color_override("font_color", color)
				_income_labels[res].text = "%s%d/s" % [ "+" if income > 0 else "", income]
			else:
				_income_labels[res].visible = false


func _update_population() -> void:
	var resource_manager = ResourceManager.get_singleton()
	if resource_manager == null:
		return

	var current = resource_manager.get_population(_player_id)
	var max_pop = resource_manager.get_max_population(_player_id)

	_pop_current_label.text = str(current)
	_pop_max_label.text = str(max_pop)

	if max_pop > 0:
		_pop_bar.max_value = max_pop
		_pop_bar.value = current
		var ratio = current / max_pop

		var fill_style = _pop_bar.get_theme_stylebox("fill")
		if ratio >= critical_pop_threshold:
			fill_style.bg_color = Color(0.9, 0.25, 0.2, 1.0)
			_pop_current_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		elif ratio >= low_pop_threshold:
			fill_style.bg_color = Color(0.95, 0.7, 0.15, 1.0)
			_pop_current_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			fill_style.bg_color = Color(0.2, 0.7, 0.25, 1.0)
			_pop_current_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))

		_pop_bar.add_theme_stylebox_override("fill", fill_style)


func _update_idle_villagers() -> void:
	var unit_manager = UnitManager.get_singleton()
	if unit_manager == null:
		return

	var idle_count = unit_manager.get_idle_villager_count(_player_id)
	_idle_villagers_label.text = str(idle_count)

	if idle_count > 0:
		_idle_villagers_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.7))
		var btn_style = _idle_villagers_button.get_theme_stylebox("normal")
		btn_style.border_color = Color(0.5, 0.8, 0.4, 1.0)
		_idle_villagers_button.add_theme_stylebox_override("normal", btn_style)
	else:
		_idle_villagers_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		var btn_style = _idle_villagers_button.get_theme_stylebox("normal")
		btn_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
		_idle_villagers_button.add_theme_stylebox_override("normal", btn_style)


func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % [num / 1000000.0]
	elif num >= 1000:
		return "%.1fK" % [num / 1000.0]
	return str(num)


# =============================================================================
# Signal Handlers
# =============================================================================

func _on_resources_changed(player_id: int, resource_type: String, amount: int) -> void:
	if player_id == _player_id:
		_update_resources()


func _on_population_changed(player_id: int, current: int, max_pop: int) -> void:
	if player_id == _player_id:
		_update_population()


func _on_idle_villagers_changed(player_id: int, count: int) -> void:
	if player_id == _player_id:
		_update_idle_villagers()


func _on_game_speed_changed(speed: float) -> void:
	_current_speed = int(speed)
	for i, btn in _speed_buttons:
		btn.disabled = (i + 1 == _current_speed)


# =============================================================================
# UI Interactions
# =============================================================================

func _on_resource_hover(resource_id: String, entered: bool) -> void:
	if _income_labels.has(resource_id):
		_income_labels[resource_id].visible = entered


func _on_pop_hover(entered: bool) -> void:
	if entered:
		_pop_bar.modulate = Color(1.1, 1.1, 1.1)
	else:
		_pop_bar.modulate = Color(1.0, 1.0, 1.0)


func _on_idle_villagers_pressed() -> void:
	var unit_manager = UnitManager.get_singleton()
	if unit_manager != null and unit_manager.has_method("select_all_idle_villagers"):
		unit_manager.select_all_idle_villagers(_player_id)
	AudioManager.play_ui_click()


func _on_speed_pressed(speed: int) -> void:
	_current_speed = speed
	EventBus.game_speed_changed.emit(float(speed))
	AudioManager.play_ui_click()

	for i, btn in _speed_buttons:
		btn.disabled = (i + 1 == speed)