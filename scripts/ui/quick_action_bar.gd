class_name QuickActionBar
extends HBoxContainer

signal idle_villagers_requested
signal town_center_requested
signal army_requested
signal builders_requested
signal speed_changed(speed: float)

@export var button_size: Vector2i = Vector2i(56, 56)
@export var spacing: int = 8
@export var margin: int = 16
@export var corner_radius: int = 10
@export var show_tooltips: bool = true

var _idle_villagers_btn: TextureButton = null
var _town_center_btn: TextureButton = null
var _army_btn: TextureButton = null
var _builders_btn: TextureButton = null
var _resource_factory: ResourceIconFactory = null
var _player_id: int = 1
var _has_idle_villagers: bool = false
var _has_town_center: bool = false
var _has_military: bool = false
var _has_builders: bool = false

func _ready() -> void:
	_name = "QuickActionBar"
	alignment = ALIGNMENT_CENTER
	add_theme_constant_override("separation", spacing)
	mouse_filter = MOUSE_FILTER_IGNORE

	_resource_factory = ResourceIconFactory.new()
	_resource_factory.icon_size = Vector2i(32, 32)
	add_child(_resource_factory)

	_player_id = GameManager.get_local_player_id()
	_create_buttons()
	_connect_signals()
	_update_visibility()


func _create_buttons() -> void:
	var style_normal = _create_button_style(Color(0.1, 0.1, 0.12, 0.92), Color(0.25, 0.25, 0.3, 1.0))
	var style_hover = _create_button_style(Color(0.15, 0.15, 0.18, 0.95), Color(0.4, 0.4, 0.5, 1.0))
	var style_pressed = _create_button_style(Color(0.08, 0.08, 0.1, 1.0), Color(0.2, 0.2, 0.25, 1.0))
	var style_disabled = _create_button_style(Color(0.08, 0.08, 0.09, 0.7), Color(0.18, 0.18, 0.2, 0.7))
	var style_focus = _create_button_style(Color(0.1, 0.1, 0.12, 0.95), Color(0.2, 0.55, 1.0, 1.0), 2)

	_idle_villagers_btn = _create_action_button(
		"IdleVillagers",
		_resource_factory.get_icon("idle_villager"),
		"Aldeanos ociosos (.)",
		style_normal, style_hover, style_pressed, style_disabled, style_focus
	)
	_idle_villagers_btn.pressed.connect(_on_idle_pressed)
	_idle_villagers_btn.disabled = true
	add_child(_idle_villagers_btn)

	_town_center_btn = _create_action_button(
		"TownCenter",
		_resource_factory.get_icon("town_center"),
		"Centro Urbano (,)",
		style_normal, style_hover, style_pressed, style_disabled, style_focus
	)
	_town_center_btn.pressed.connect(_on_tc_pressed)
	_town_center_btn.disabled = true
	add_child(_town_center_btn)

	_army_btn = _create_action_button(
		"Army",
		_resource_factory.get_icon("swordsman"),
		"Ejército (;)",
		style_normal, style_hover, style_pressed, style_disabled, style_focus
	)
	_army_btn.pressed.connect(_on_army_pressed)
	_army_btn.disabled = true
	add_child(_army_btn)

	_builders_btn = _create_action_button(
		"Builders",
		_resource_factory.get_icon("builder"),
		"Constructores (')",
		style_normal, style_hover, style_pressed, style_disabled, style_focus
	)
	_builders_btn.pressed.connect(_on_builders_pressed)
	_builders_btn.disabled = true
	add_child(_builders_btn)

	var speed_container = _create_speed_controls()
	add_child(speed_container)


func _create_button_style(bg: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_all = border_width
	style.border_color = border
	style.corner_radius_all = corner_radius
	style.shadow_enabled = true
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_offset = Vector2(0, 2)
	style.shadow_blur = 4
	return style


func _create_action_button(name: String, icon: Texture2D, tooltip: String,
		normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat,
		disabled: StyleBoxFlat, focus: StyleBoxFlat) -> TextureButton:

	var btn = TextureButton.new()
	btn.name = name
	btn.custom_minimum_size = button_size
	btn.focus_mode = FOCUS_ALL
	btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	btn.texture_normal = icon

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", focus)

	if show_tooltips:
		btn.tooltip_text = tooltip

	return btn


func _create_speed_controls() -> HBoxContainer:
	var container = HBoxContainer.new()
	container.name = "SpeedControls"
	container.alignment = ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 4)
	container.mouse_filter = MOUSE_FILTER_IGNORE

	var separator = VSeparator.new()
	separator.custom_minimum_size = Vector2(2, 36)
	container.add_child(separator)

	var speeds = [1, 2, 3]
	var labels = ["1x", "2x", "3x"]

	for i in speeds.size():
		var btn = TextureButton.new()
		btn.name = "Speed" + str(speeds[i])
		btn.custom_minimum_size = Vector2i(44, 36)
		btn.focus_mode = FOCUS_ALL

		var label = Label.new()
		label.text = labels[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 1)
		label.mouse_filter = MOUSE_FILTER_IGNORE
		btn.add_child(label)

		var style_normal = _create_button_style(Color(0.1, 0.1, 0.12, 0.9), Color(0.25, 0.25, 0.3, 1.0))
		var style_hover = _create_button_style(Color(0.15, 0.15, 0.18, 0.95), Color(0.4, 0.4, 0.5, 1.0))
		var style_pressed = _create_button_style(Color(0.08, 0.08, 0.1, 1.0), Color(0.2, 0.2, 0.25, 1.0))
		var style_focus = _create_button_style(Color(0.1, 0.1, 0.12, 0.95), Color(0.2, 0.55, 1.0, 1.0), 2)
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("focus", style_focus)

		if speeds[i] == 1:
			btn.disabled = true

		btn.pressed.connect(_on_speed_pressed.bind(speeds[i]))
		container.add_child(btn)

	var pause_btn = TextureButton.new()
	pause_btn.name = "Pause"
	pause_btn.custom_minimum_size = Vector2i(36, 36)
	pause_btn.focus_mode = FOCUS_ALL

	var pause_label = Label.new()
	pause_label.text = "⏸"
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.add_theme_font_size_override("font_size", 18)
	pause_label.mouse_filter = MOUSE_FILTER_IGNORE
	pause_btn.add_child(pause_label)

	var pause_normal = _create_button_style(Color(0.1, 0.1, 0.12, 0.9), Color(0.25, 0.25, 0.3, 1.0))
	var pause_hover = _create_button_style(Color(0.15, 0.15, 0.18, 0.95), Color(0.6, 0.2, 0.2, 1.0))
	var pause_pressed = _create_button_style(Color(0.08, 0.08, 0.1, 1.0), Color(0.4, 0.15, 0.15, 1.0))
	var pause_focus = _create_button_style(Color(0.1, 0.1, 0.12, 0.95), Color(1.0, 0.3, 0.3, 1.0), 2)
	pause_btn.add_theme_stylebox_override("normal", pause_normal)
	pause_btn.add_theme_stylebox_override("hover", pause_hover)
	pause_btn.add_theme_stylebox_override("pressed", pause_pressed)
	pause_btn.add_theme_stylebox_override("focus", pause_focus)

	pause_btn.tooltip_text = "Pausar (Espacio)"
	pause_btn.pressed.connect(_on_pause_pressed)
	container.add_child(pause_btn)

	return container


func _connect_signals() -> void:
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.idle_villagers_changed.connect(_on_idle_villagers_changed)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_destroyed.connect(_on_building_destroyed)
	EventBus.unit_spawned.connect(_on_unit_spawned)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.game_speed_changed.connect(_on_game_speed_changed)


func _on_selection_changed(units: Array, buildings: Array) -> void:
	_has_military = false
	_has_builders = false

	var unit_manager = UnitManager.get_singleton()
	if unit_manager == null:
		_update_visibility()
		return

	for unit_id in units:
		var unit = _find_unit_by_id(unit_id)
		if unit != null:
			var unit_type = unit.get("unit_type", "")
			if unit_type in ["swordsman", "spearman", "archer", "cavalry"]:
				_has_military = true
			if unit_type == "villager" and unit.has_method("can_build") and unit.can_build():
				_has_builders = true

	_update_visibility()


func _on_idle_villagers_changed(player_id: int, count: int) -> void:
	if player_id != _player_id:
		return
	_has_idle_villagers = count > 0
	_update_visibility()


func _on_building_placed(building_id: int, building_type: String, player_id: int, position: Vector2) -> void:
	if player_id != _player_id:
		return
	if building_type == "town_center":
		_has_town_center = true
		_update_visibility()


func _on_building_destroyed(building_id: int, player_id: int, destroyer_id: int) -> void:
	if player_id != _player_id:
		return
	var building_manager = BuildingManager.get_singleton()
	if building_manager != null and building_manager.has_method("get_building_type"):
		var btype = building_manager.get_building_type(building_id)
		if btype == "town_center":
			_has_town_center = false
			_update_visibility()


func _on_unit_spawned(unit_id: int, unit_type: String, player_id: int, position: Vector2) -> void:
	if player_id != _player_id:
		return
	if unit_type == "villager":
		_has_idle_villagers = true
		_update_visibility()
	elif unit_type in ["swordsman", "spearman", "archer", "cavalry"]:
		_has_military = true
		_update_visibility()


func _on_unit_died(unit_id: int, player_id: int) -> void:
	if player_id != _player_id:
		return
	var unit_manager = UnitManager.get_singleton()
	if unit_manager != null and unit_manager.has_method("get_unit_type"):
		var utype = unit_manager.get_unit_type(unit_id)
		if utype == "villager":
			_has_idle_villagers = false
			_update_visibility()
		elif utype in ["swordsman", "spearman", "archer", "cavalry"]:
			_has_military = false
			_update_visibility()


func _on_game_speed_changed(speed: float) -> void:
	var speed_btns = [_get_child_by_name("Speed1"), _get_child_by_name("Speed2"), _get_child_by_name("Speed3")]
	for i, btn in speed_btns:
		if btn != null:
			btn.disabled = (int(speed) == speeds[i])


func _update_visibility() -> void:
	if _idle_villagers_btn != null:
		_idle_villagers_btn.disabled = not _has_idle_villagers
		if _has_idle_villagers:
			var style = _idle_villagers_btn.get_theme_stylebox("normal")
			style.border_color = Color(0.3, 0.7, 0.3, 1.0)
			_idle_villagers_btn.add_theme_stylebox_override("normal", style)
		else:
			var style = _idle_villagers_btn.get_theme_stylebox("normal")
			style.border_color = Color(0.25, 0.25, 0.3, 1.0)
			_idle_villagers_btn.add_theme_stylebox_override("normal", style)

	if _town_center_btn != null:
		_town_center_btn.disabled = not _has_town_center

	if _army_btn != null:
		_army_btn.disabled = not _has_military

	if _builders_btn != null:
		_builders_btn.disabled = not _has_builders


func _find_unit_by_id(unit_id: int) -> Node:
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.get("unit_id", -1) == unit_id:
			return unit
	return null


func _get_child_by_name(name: String) -> TextureButton:
	var container = get_node_or_null("SpeedControls")
	if container != null:
		return container.get_node_or_null(name)
	return null


func _on_idle_pressed() -> void:
	idle_villagers_requested.emit()
	AudioManager.play_ui_click()


func _on_tc_pressed() -> void:
	town_center_requested.emit()
	AudioManager.play_ui_click()


func _on_army_pressed() -> void:
	army_requested.emit()
	AudioManager.play_ui_click()


func _on_builders_pressed() -> void:
	builders_requested.emit()
	AudioManager.play_ui_click()


func _on_speed_pressed(speed: int) -> void:
	speed_changed.emit(float(speed))
	AudioManager.play_ui_click()


func _on_pause_pressed() -> void:
	speed_changed.emit(0.0)
	AudioManager.play_ui_click()