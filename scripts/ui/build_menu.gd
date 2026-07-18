extends Control

const CATEGORIES: Dictionary = {
	"Economy": ["house", "lumber_camp", "mill", "mine"],
	"Military": ["barracks", "archery_range", "stable", "siege_workshop"],
	"Defense": ["wall", "tower", "castle"],
}

var _is_open: bool = false
var _grid_container: GridContainer = null
var _scroll_container: ScrollContainer = null
var _close_button: Button = null
var _title_label: Label = null

var _resource_icons: Dictionary = {
	"wood": "🪵",
	"stone": "🪨",
	"food": "🍖",
	"gold": "🪙",
}


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.08, 0.12, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 16
	main_vbox.offset_right = -16
	main_vbox.offset_top = 16
	main_vbox.offset_bottom = -16
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Build"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(48, 48)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "ScrollContainer"
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll_container)

	_grid_container = GridContainer.new()
	_grid_container.name = "GridContainer"
	_grid_container.columns = 3
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_container.add_theme_constant_override("h_separation", 8)
	_grid_container.add_theme_constant_override("v_separation", 8)
	_scroll_container.add_child(_grid_container)


func open() -> void:
	_is_open = true
	visible = true
	refresh_build_options(GameManager.local_player_id)
	EventBus.menu_opened.emit("build_menu")


func close() -> void:
	_is_open = false
	visible = false
	EventBus.menu_closed.emit("build_menu")


func is_open() -> bool:
	return _is_open


func refresh_build_options(player_id: int) -> void:
	if _grid_container == null:
		return

	for child: Node in _grid_container.get_children():
		child.queue_free()

	for category: String in CATEGORIES:
		var cat_label: Label = Label.new()
		cat_label.name = "Category_" + category
		cat_label.text = category
		cat_label.add_theme_font_size_override("font_size", 16)
		cat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		cat_label.custom_minimum_size = Vector2(200, 24)
		_grid_container.add_child(cat_label)

		var building_types: Array = CATEGORIES[category]
		for building_type: String in building_types:
			_create_building_button(building_type, player_id)


func _create_building_button(building_type: String, player_id: int) -> void:
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	if building_data.is_empty():
		return

	var display_name: String = building_data.get("display_name", building_type.capitalize())
	var cost: Dictionary = building_data.get("cost", {})
	var prerequisite_buildings: Array = building_data.get("prerequisite_buildings", [])
	var can_afford: bool = GameManager.can_afford(cost, player_id)
	var has_prereqs: bool = _check_prerequisites(prerequisite_buildings, player_id)
	var enabled: bool = can_afford and has_prereqs

	var btn: Button = Button.new()
	btn.name = "Build_" + building_type
	btn.custom_minimum_size = Vector2(100, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6

	var disabled_reason: String = ""
	if not can_afford:
		var resources: Dictionary = GameManager.get_resources()
		var missing: Array[String] = []
		for res_type: String in cost:
			var have: int = resources.get(res_type, 0)
			var need: int = cost[res_type]
			if have < need:
				missing.append(res_type.capitalize() + " (" + str(have) + "/" + str(need) + ")")
		disabled_reason = "Need: " + ", ".join(missing)
	elif not has_prereqs:
		disabled_reason = "Requires: " + ", ".join(prerequisite_buildings)

	if enabled:
		btn_style.bg_color = Color(0.15, 0.25, 0.15, 0.9)
		btn_style.border_color = Color(0.3, 0.6, 0.3, 0.8)
		btn_style.border_width_bottom = 2
		btn_style.border_width_top = 2
		btn_style.border_width_left = 2
		btn_style.border_width_right = 2
	else:
		btn_style.bg_color = Color(0.2, 0.15, 0.15, 0.9)
		btn_style.border_color = Color(0.4, 0.2, 0.2, 0.6)
		btn_style.border_width_bottom = 2
		btn_style.border_width_top = 2
		btn_style.border_width_left = 2
		btn_style.border_width_right = 2

	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.border_color = Color(0.5, 0.8, 0.5, 1.0) if enabled else Color(0.5, 0.3, 0.3, 0.8)
	btn.add_theme_stylebox_override("hover", btn_hover)

	btn.tooltip_text = display_name + ("\n[color=#ff6666]" + disabled_reason + "[/color]" if disabled_reason.length() > 0 else "")

	_grid_container.add_child(btn)

	var inner_vbox: VBoxContainer = VBoxContainer.new()
	inner_vbox.name = "Inner"
	inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_theme_constant_override("separation", 2)
	btn.add_child(inner_vbox)

	var preview: TextureRect = TextureRect.new()
	preview.name = "Preview"
	preview.custom_minimum_size = Vector2(48, 48)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var raw_size: Dictionary = building_data.get("size", {"x": 2, "y": 2})
	var grid_size: Vector2i = Vector2i(raw_size.get("x", 2), raw_size.get("y", 2))
	preview.texture = ProceduralSpriteFactory.get_building_preview(building_type, player_id, grid_size)
	if not enabled:
		preview.modulate = Color(0.5, 0.5, 0.5, 0.7)
	inner_vbox.add_child(preview)

	var name_label: Label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not enabled:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	inner_vbox.add_child(name_label)

	var cost_label: Label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = _format_cost_short(cost)
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not can_afford:
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		cost_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	inner_vbox.add_child(cost_label)

	if not has_prereqs:
		var prereq_label: Label = Label.new()
		prereq_label.text = "Requires: " + ", ".join(prerequisite_buildings)
		prereq_label.add_theme_font_size_override("font_size", 9)
		prereq_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		prereq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner_vbox.add_child(prereq_label)

	if enabled:
		btn.pressed.connect(func() -> void: on_build_button_pressed(building_type))


func on_build_button_pressed(building_type: String) -> void:
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	var cost: Dictionary = building_data.get("cost", {})
	var prerequisite_buildings: Array = building_data.get("prerequisite_buildings", [])

	if not GameManager.can_afford(cost, GameManager.local_player_id):
		EventBus.button_pressed.emit("cant_afford", GameManager.local_player_id)
		return

	if not _check_prerequisites(prerequisite_buildings, GameManager.local_player_id):
		EventBus.button_pressed.emit("missing_prereq", GameManager.local_player_id)
		return

	var input_manager: Node = _find_input_manager()
	if input_manager and input_manager.has_method("enter_build_mode"):
		input_manager.enter_build_mode(building_type)

	close()


func _check_prerequisites(prerequisite_buildings: Array, player_id: int) -> bool:
	if prerequisite_buildings.is_empty():
		return true

	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null:
		return true

	var player_buildings: Array = []
	if bm.has_method("get_player_buildings"):
		player_buildings = bm.get_player_buildings(player_id)
	elif bm.get("player_buildings") != null:
		player_buildings = bm.get("player_buildings")

	var owned_types: Array[String] = []
	for b: Node in player_buildings:
		if is_instance_valid(b) and b.has_method("get") and b.get("building_type") != null:
			var b_type: String = b.get("building_type")
			if b_type not in owned_types:
				owned_types.append(b_type)

	for prereq: String in prerequisite_buildings:
		if prereq not in owned_types:
			return false
	return true


func _format_cost_short(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Free"
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = _resource_icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return " ".join(parts)


func _find_input_manager() -> Node:
	var im: Node = get_node_or_null("/root/GameWorld/InputManager")
	if im:
		return im
	im = get_node_or_null("/root/GameWorld/World/InputManager")
	return im
