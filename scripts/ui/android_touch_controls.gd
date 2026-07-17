class_name AndroidTouchControls
extends Control

signal cancel_pressed
signal contextual_pressed(action: String)
signal idle_villagers_requested
signal select_all_military
signal select_all_builders
signal cycle_subgroups

@export var button_size: Vector2i = Vector2i(72, 72)
@export var button_margin: int = 12
@export var touch_target_min: int = 48
@export var corner_offset: Vector2i = Vector2i(16, 16)

var _cancel_button: TextureButton = null
var _contextual_button: TextureButton = null
var _idle_villagers_button: TextureButton = null
var _military_button: TextureButton = null
var _builder_button: TextureButton = null
var _subgroup_button: TextureButton = null
var _build_mode: bool = false
var _visible_actions: Array[String] = []

func _ready() -> void:
	_name = "AndroidTouchControls"
	mouse_filter = MOUSE_FILTER_IGNORE
	layout_mode = LAYOUT_MODE_ANCHORED
	set_anchors_preset(PRESET_BOTTOM_RIGHT)
	offset_left = -corner_offset.x
	offset_top = -corner_offset.y
	offset_right = -corner_offset.x
	offset_bottom = -corner_offset.y

	_create_buttons()
	_update_visibility()

	EventBus.build_mode_changed.connect(_on_build_mode_changed)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.menu_opened.connect(_on_menu_opened)
	EventBus.menu_closed.connect(_on_menu_closed)


func _create_buttons() -> void:
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	style_box.border_width_bottom = 2
	style_box.border_width_right = 2
	style_box.border_color = Color(0.3, 0.3, 0.35, 1.0)
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 12
	style_box.shadow_enabled = true
	style_box.shadow_color = Color(0, 0, 0, 0.4)
	style_box.shadow_offset = Vector2(0, 3)
	style_box.shadow_blur = 6

	var pressed_style = style_box.duplicate()
	pressed_style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	pressed_style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	pressed_style.shadow_offset = Vector2(0, 1)

	var hover_style = style_box.duplicate()
	hover_style.bg_color = Color(0.18, 0.18, 0.22, 0.9)
	hover_style.border_color = Color(0.6, 0.6, 0.7, 1.0)

	_cancel_button = _create_button("Cancel", "✕", style_box, pressed_style, hover_style)
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_on_cancel_pressed.bind())

	_contextual_button = _create_button("Contextual", "☰", style_box, pressed_style, hover_style)
	_contextual_button.visible = false
	_contextual_button.pressed.connect(_on_contextual_pressed.bind())

	_idle_villagers_button = _create_button("IdleVillagers", "🛑", style_box, pressed_style, hover_style)
	_idle_villagers_button.visible = false
	_idle_villagers_button.pressed.connect(_on_idle_villagers_pressed.bind())

	_military_button = _create_button("Military", "⚔", style_box, pressed_style, hover_style)
	_military_button.visible = false
	_military_button.pressed.connect(_on_military_pressed.bind())

	_builder_button = _create_button("Builders", "🔨", style_box, pressed_style, hover_style)
	_builder_button.visible = false
	_builder_button.pressed.connect(_on_builder_pressed.bind())

	_subgroup_button = _create_button("Subgroup", "◀▶", style_box, pressed_style, hover_style)
	_subgroup_button.visible = false
	_subgroup_button.pressed.connect(_on_subgroup_pressed.bind())

	add_child(_cancel_button)
	add_child(_contextual_button)
	add_child(_idle_villagers_button)
	add_child(_military_button)
	add_child(_builder_button)
	add_child(_subgroup_button)


func _create_button(name: String, text: String, normal: StyleBoxFlat, pressed: StyleBoxFlat, hover: StyleBoxFlat) -> TextureButton:
	var btn = TextureButton.new()
	btn.name = name
	btn.custom_minimum_size = button_size
	btn.focus_mode = FOCUS_NONE
	btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	btn.tooltip_text = name

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = button_size
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	label.mouse_filter = MOUSE_FILTER_IGNORE
	btn.add_child(label)

	btn.theme_overrides["normal"] = normal
	btn.theme_overrides["pressed"] = pressed
	btn.theme_overrides["hover"] = hover
	btn.theme_overrides["focus"] = StyleBoxEmpty.new()

	return btn


func _update_visibility() -> void:
	var visible_count = 0

	if _build_mode:
		_cancel_button.visible = true
		_contextual_button.visible = false
		_idle_villagers_button.visible = false
		_military_button.visible = false
		_builder_button.visible = false
		_subgroup_button.visible = false
		visible_count = 1
	else:
		_cancel_button.visible = false

		if _visible_actions.has("idle_villagers"):
			_idle_villagers_button.visible = true
			visible_count += 1
		else:
			_idle_villagers_button.visible = false

		if _visible_actions.has("military"):
			_military_button.visible = true
			visible_count += 1
		else:
			_military_button.visible = false

		if _visible_actions.has("builders"):
			_builder_button.visible = true
			visible_count += 1
		else:
			_builder_button.visible = false

		if _visible_actions.has("subgroup"):
			_subgroup_button.visible = true
			visible_count += 1
		else:
			_subgroup_button.visible = false

		_contextual_button.visible = visible_count > 0


func _layout_buttons() -> void:
	var buttons = [_cancel_button, _contextual_button, _idle_villagers_button, _military_button, _builder_button, _subgroup_button]
	var visible_buttons = buttons.filter(func(b): return b.visible)

	var spacing = 8
	var total_height = 0
	for btn in visible_buttons:
		total_height += btn.custom_minimum_size.y + spacing
	total_height -= spacing

	var start_y = -total_height - button_margin
	var x_pos = -button_size.x - button_margin

	for i, btn in enumerate(visible_buttons):
		btn.position = Vector2(x_pos, start_y + i * (button_size.y + spacing))


func _on_build_mode_changed(active: bool) -> void:
	_build_mode = active
	_update_visibility()
	_layout_buttons()
	queue_redraw()


func _on_selection_changed(units: Array, buildings: Array) -> void:
	if _build_mode:
		return

	_visible_actions.clear()

	var has_idle_villagers = false
	var has_military = false
	var has_builders = false
	var has_multiple_types = false

	for unit_id in units:
		var unit = _find_unit_by_id(unit_id)
		if unit != null:
			var unit_type = unit.get("unit_type", "")
			if unit_type == "villager":
				var state = unit.get("state", "")
				if state == "IdleState":
					has_idle_villagers = true
				if unit.has_method("can_build") and unit.can_build():
					has_builders = true
			elif unit_type in ["swordsman", "spearman", "archer", "cavalry"]:
				has_military = true

	var types = {}
	for unit_id in units:
		var unit = _find_unit_by_id(unit_id)
		if unit != null:
			var utype = unit.get("unit_type", "unknown")
			types[utype] = true

	has_multiple_types = types.size() > 1

	if has_idle_villagers:
		_visible_actions.append("idle_villagers")
	if has_military:
		_visible_actions.append("military")
	if has_builders:
		_visible_actions.append("builders")
	if has_multiple_types and units.size() > 1:
		_visible_actions.append("subgroup")

	_update_visibility()
	_layout_buttons()


func _on_menu_opened(menu_name: String) -> void:
	if menu_name in ["build_menu", "train_menu", "tech_tree"]:
		_cancel_button.visible = true
		_contextual_button.visible = false
		_idle_villagers_button.visible = false
		_military_button.visible = false
		_builder_button.visible = false
		_subgroup_button.visible = false
		_layout_buttons()


func _on_menu_closed(menu_name: String) -> void:
	if not _build_mode:
		_on_selection_changed(_get_selected_units(), _get_selected_buildings())


func _on_cancel_pressed() -> void:
	cancel_pressed.emit()
	AudioManager.play_ui_click()


func _on_contextual_pressed() -> void:
	contextual_pressed.emit("menu")
	AudioManager.play_ui_click()


func _on_idle_villagers_pressed() -> void:
	idle_villagers_requested.emit()
	AudioManager.play_ui_click()


func _on_military_pressed() -> void:
	select_all_military.emit()
	AudioManager.play_ui_click()


func _on_builder_pressed() -> void:
	select_all_builders.emit()
	AudioManager.play_ui_click()


func _on_subgroup_pressed() -> void:
	cycle_subgroups.emit()
	AudioManager.play_ui_click()


func _find_unit_by_id(unit_id: int) -> Node:
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.get("unit_id", -1) == unit_id:
			return unit
	return null


func _get_selected_units() -> Array:
	var sm = get_node_or_null("/root/GameWorld/SelectionManager")
	if sm != null and sm.has_method("get_selected_units"):
		return sm.get_selected_units()
	return []


func _get_selected_buildings() -> Array:
	var sm = get_node_or_null("/root/GameWorld/SelectionManager")
	if sm != null and sm.has_method("get_selected_buildings"):
		return sm.get_selected_buildings()
	return []


func set_corner(corner: int) -> void:
	match corner:
		0:
			set_anchors_preset(PRESET_BOTTOM_RIGHT)
			offset_left = -corner_offset.x
			offset_top = -corner_offset.y
			offset_right = -corner_offset.x
			offset_bottom = -corner_offset.y
		1:
			set_anchors_preset(PRESET_BOTTOM_LEFT)
			offset_left = corner_offset.x
			offset_top = -corner_offset.y
			offset_right = corner_offset.x
			offset_bottom = -corner_offset.y
		2:
			set_anchors_preset(PRESET_TOP_RIGHT)
			offset_left = -corner_offset.x
			offset_top = corner_offset.y
			offset_right = -corner_offset.x
			offset_bottom = corner_offset.y
		3:
			set_anchors_preset(PRESET_TOP_LEFT)
			offset_left = corner_offset.x
			offset_top = corner_offset.y
			offset_right = corner_offset.x
			offset_bottom = corner_offset.y

	_layout_buttons()


func show_build_mode_cancel() -> void:
	_build_mode = true
	_update_visibility()
	_layout_buttons()


func hide_build_mode_cancel() -> void:
	_build_mode = false
	_update_visibility()
	_layout_buttons()