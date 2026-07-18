extends Control

var _is_open: bool = false
var _current_building_id: int = -1
var _current_building_type: String = ""
var _tech_list_container: VBoxContainer = null
var _queue_container: HBoxContainer = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null
var _title_label: Label = null
var _close_button: Button = null
var _queue_label: Label = null
var _scroll_container: ScrollContainer = null

var _resource_icons: Dictionary = {
	"wood": "🪵",
	"stone": "🪨",
	"food": "🍖",
	"gold": "🪙",
}

func _ready() -> void:
	_build_ui()
	visible = false
	_connect_signals()

func _connect_signals() -> void:
	if not EventBus.tech_started.is_connected(_on_tech_started):
		EventBus.tech_started.connect(_on_tech_started)
	if not EventBus.tech_completed.is_connected(_on_tech_completed):
		EventBus.tech_completed.connect(_on_tech_completed)
	if not EventBus.tech_progress.is_connected(_on_tech_progress):
		EventBus.tech_progress.connect(_on_tech_progress)
	if not EventBus.button_pressed.is_connected(_on_button_pressed):
		EventBus.button_pressed.connect(_on_button_pressed)

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.08, 0.12, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 16
	main_vbox.offset_right = -16
	main_vbox.offset_top = 16
	main_vbox.offset_bottom = -16
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Research Technologies"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(48, 48)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.custom_minimum_size = Vector2(0, 20)
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.visible = false
	_progress_bar.show_percentage = false

	var progress_bg: StyleBoxFlat = StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	progress_bg.corner_radius_top_left = 4
	progress_bg.corner_radius_top_right = 4
	progress_bg.corner_radius_bottom_left = 4
	progress_bg.corner_radius_bottom_right = 4
	_progress_bar.add_theme_stylebox_override("background", progress_bg)

	var progress_fill: StyleBoxFlat = StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.2, 0.5, 0.9, 1.0)
	progress_fill.corner_radius_top_left = 4
	progress_fill.corner_radius_top_right = 4
	progress_fill.corner_radius_bottom_left = 4
	progress_fill.corner_radius_bottom_right = 4
	_progress_bar.add_theme_stylebox_override("fill", progress_fill)

	main_vbox.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.text = ""
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.visible = false
	main_vbox.add_child(_progress_label)

	_queue_label = Label.new()
	_queue_label.name = "QueueLabel"
	_queue_label.text = "Research Queue:"
	_queue_label.add_theme_font_size_override("font_size", 14)
	_queue_label.visible = false
	main_vbox.add_child(_queue_label)

	_queue_container = HBoxContainer.new()
	_queue_container.name = "QueueContainer"
	_queue_container.add_theme_constant_override("separation", 4)
	_queue_container.visible = false
	main_vbox.add_child(_queue_container)

	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "TechScroll"
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll_container)

	_tech_list_container = VBoxContainer.new()
	_tech_list_container.name = "TechListContainer"
	_tech_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tech_list_container.add_theme_constant_override("separation", 6)
	_scroll_container.add_child(_tech_list_container)

func open_for_building(building_id: int) -> void:
	_current_building_id = building_id
	_is_open = true
	visible = true

	var building_node: Node = _find_building_by_id(building_id)
	if building_node != null:
		_current_building_type = building_node.get("building_type") if building_node.get("building_type") != null else ""
	else:
		_current_building_type = ""

	refresh_tech_list(_current_building_type)
	_update_queue_display()
	EventBus.menu_opened.emit("tech_panel")

func close() -> void:
	_is_open = false
	_current_building_id = -1
	_current_building_type = ""
	visible = false
	EventBus.menu_closed.emit("tech_panel")

func refresh_tech_list(building_type: String) -> void:
	if _tech_list_container == null:
		return

	for child: Node in _tech_list_container.get_children():
		child.queue_free()

	var tech_manager: TechnologyManager = get_node_or_null("/root/TechnologyManager")
	if not tech_manager:
		return

	var available_techs: Array = tech_manager.get_available_techs(building_id, GameManager.local_player_id)

	if _title_label:
		var building_data: Dictionary = DataManager.get_building_data(building_type)
		_title_label.text = building_data.get("display_name", building_type.capitalize()) + " - Research"

	if available_techs.is_empty():
		var no_techs: Label = Label.new()
		no_techs.text = "No technologies available"
		no_techs.add_theme_font_size_override("font_size", 14)
		no_techs.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_tech_list_container.add_child(no_techs)
		return

	for tech_info: Dictionary in available_techs:
		_create_tech_button(tech_info)

func _create_tech_button(tech_info: Dictionary) -> void:
	var tech_id: String = tech_info.get("tech_id", "")
	var display_name: String = tech_info.get("display_name", tech_id.capitalize())
	var cost: Dictionary = tech_info.get("cost", {})
	var research_time: float = tech_info.get("research_time", 30.0)
	var requires: Array = tech_info.get("requires", [])
	var effects: Dictionary = tech_info.get("effects", {})
	var description: String = tech_info.get("description", "")
	var tier: int = tech_info.get("tier", 1)
	var can_afford: bool = tech_info.get("can_afford", false)
	var is_researching: bool = tech_info.get("is_researching", false)
	var progress: float = tech_info.get("progress", 0.0)
	var prereq_met: bool = tech_info.get("prereq_met", false)

	var btn: Button = Button.new()
	btn.name = "Research_" + tech_id
	btn.custom_minimum_size = Vector2(0, 80)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.border_width_bottom = 1
	btn_style.border_width_top = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1

	if is_researching:
		btn_style.bg_color = Color(0.15, 0.3, 0.5, 0.9)
		btn_style.border_color = Color(0.3, 0.6, 1.0, 1.0)
	elif can_afford and prereq_met:
		btn_style.bg_color = Color(0.12, 0.2, 0.12, 0.9)
		btn_style.border_color = Color(0.3, 0.5, 0.3, 0.7)
	else:
		btn_style.bg_color = Color(0.2, 0.15, 0.12, 0.9)
		btn_style.border_color = Color(0.4, 0.25, 0.2, 0.6)

	btn.add_theme_stylebox_override("normal", btn_style)
	_tech_list_container.add_child(btn)

	var inner_hbox: HBoxContainer = HBoxContainer.new()
	inner_hbox.name = "Inner"
	inner_hbox.add_theme_constant_override("separation", 10)
	btn.add_child(inner_hbox)

	var preview: TextureRect = TextureRect.new()
	preview.name = "Preview"
	preview.custom_minimum_size = Vector2(50, 50)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = ProceduralSpriteFactory.get_tech_preview(tech_id)
	if not can_afford or not prereq_met:
		preview.modulate = Color(0.5, 0.5, 0.5, 0.7)
	inner_hbox.add_child(preview)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.name = "Left"
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 2)
	inner_hbox.add_child(left_vbox)

	var name_label: Label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 16)
	if not prereq_met:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		name_label.add_theme_color_override("font_color", Color.WHITE)
	left_vbox.add_child(name_label)

	var desc_label: Label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(desc_label)

	if requires.size() > 0:
		var prereq_names: Array = []
		for req: String in requires:
			var req_data: Dictionary = DataManager.get_tech_data(req)
			if req_data.is_empty():
				req_data = DataManager.get_building_data(req)
			var req_name: String = req_data.get("display_name", req.capitalize())
			if not _is_prereq_met(req):
				req_name = "[color=#ff6666]" + req_name + "[/color]"
			prereq_names.append(req_name)
		var prereq_text: String = "Requires: " + ", ".join(prereq_names)
		var prereq_label: Label = Label.new()
		prereq_label.text = prereq_text
		prereq_label.add_theme_font_size_override("font_size", 10)
		prereq_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		prereq_label.parse_bbcode_enabled = true
		left_vbox.add_child(prereq_label)

	var effects_text: String = _format_effects(effects)
	if effects_text.length() > 0:
		var effects_label: Label = Label.new()
		effects_label.text = "Effects: " + effects_text
		effects_label.add_theme_font_size_override("font_size", 10)
		effects_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		left_vbox.add_child(effects_label)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.name = "Right"
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 4)
	inner_hbox.add_child(right_vbox)

	var cost_label: Label = Label.new()
	cost_label.text = _format_cost(cost)
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not can_afford:
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		cost_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	right_vbox.add_child(cost_label)

	var time_label: Label = Label.new()
	time_label.text = "%.0fs" % research_time
	time_label.add_theme_font_size_override("font_size", 11)
	time_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_vbox.add_child(time_label)

	var tier_label: Label = Label.new()
	tier_label.text = "Tier %d" % tier
	tier_label.add_theme_font_size_override("font_size", 10)
	tier_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_vbox.add_child(tier_label)

	if is_researching:
		var progress_bar: ProgressBar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(80, 12)
		progress_bar.max_value = 100
		progress_bar.value = progress * 100
		progress_bar.show_percentage = false
		var p_bg: StyleBoxFlat = StyleBoxFlat.new()
		p_bg.bg_color = Color(0.1, 0.1, 0.15, 0.8)
		p_bg.corner_radius_top_left = 3
		p_bg.corner_radius_top_right = 3
		p_bg.corner_radius_bottom_left = 3
		p_bg.corner_radius_bottom_right = 3
		progress_bar.add_theme_stylebox_override("background", p_bg)
		var p_fill: StyleBoxFlat = StyleBoxFlat.new()
		p_fill.bg_color = Color(0.3, 0.7, 1.0, 1.0)
		p_fill.corner_radius_top_left = 3
		p_fill.corner_radius_top_right = 3
		p_fill.corner_radius_bottom_left = 3
		p_fill.corner_radius_bottom_right = 3
		progress_bar.add_theme_stylebox_override("fill", p_fill)
		right_vbox.add_child(progress_bar)

		var progress_lbl: Label = Label.new()
		progress_lbl.text = "Researching... %d%%" % int(progress * 100)
		progress_lbl.add_theme_font_size_override("font_size", 10)
		progress_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
		progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_vbox.add_child(progress_lbl)
	elif can_afford and prereq_met:
		btn.pressed.connect(func() -> void: on_research_button_pressed(tech_id))
	else:
		var disabled_label: Label = Label.new()
		if not prereq_met:
			disabled_label.text = "Prerequisites not met"
		elif not can_afford:
			disabled_label.text = "Cannot afford"
		else:
			disabled_label.text = "Unavailable"
		disabled_label.add_theme_font_size_override("font_size", 10)
		disabled_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		disabled_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_vbox.add_child(disabled_label)

func _is_prereq_met(req: String) -> bool:
	var tech_manager: TechnologyManager = get_node_or_null("/root/TechnologyManager")
	if not tech_manager:
		return false
	var tech_data: Dictionary = DataManager.get_tech_data(req)
	if not tech_data.is_empty():
		return tech_manager._is_researched(req, GameManager.local_player_id)
	var building_data: Dictionary = DataManager.get_building_data(req)
	if not building_data.is_empty():
		return tech_manager._is_building_owned(req, GameManager.local_player_id)
	return false

func _format_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return ""
	var parts: Array = []
	for effect_key: String in effects:
		var value: Variant = effects[effect_key]
		var formatted: String = _format_effect(effect_key, value)
		if formatted.length() > 0:
			parts.append(formatted)
	return ", ".join(parts)

func _format_effect(effect_key: String, value: Variant) -> String:
	match effect_key:
		"wood_gather_rate": return "+%d%% wood gather rate" % int((value - 1.0) * 100)
		"food_gather_rate", "farm_capacity": return "+%d%% food gather rate" % int((value - 1.0) * 100)
		"gold_gather_rate": return "+%d%% gold gather rate" % int((value - 1.0) * 100)
		"stone_gather_rate": return "+%d%% stone gather rate" % int((value - 1.0) * 100)
		"villager_speed": return "+%d%% villager speed" % int((value - 1.0) * 100)
		"carry_capacity": return "+%d%% carry capacity" % int((value - 1.0) * 100)
		"melee_attack": return "+%d%% melee attack" % int((value - 1.0) * 100)
		"ranged_attack": return "+%d%% ranged attack" % int((value - 1.0) * 100)
		"tower_attack": return "+%d%% tower attack" % int((value - 1.0) * 100)
		"siege_attack": return "+%d%% siege attack" % int((value - 1.0) * 100)
		"cavalry_armor": return "+%d%% cavalry armor" % int((value - 1.0) * 100)
		"cavalry_hp": return "+%d%% cavalry HP" % int((value - 1.0) * 100)
		"cavalry_speed": return "+%d%% cavalry speed" % int((value - 1.0) * 100)
		"building_hp": return "+%d%% building HP" % int((value - 1.0) * 100)
		"building_armor": return "+%d building armor" % int(value)
		"wall_hp": return "+%d%% wall HP" % int((value - 1.0) * 100)
		"tower_hp": return "+%d%% tower HP" % int((value - 1.0) * 100)
		"train_speed": return "+%d%% train speed" % int((value - 1.0) * 100)
		"build_speed_modifier": return "+%d%% build speed" % int((value - 1.0) * 100)
		"range": return "+%d range" % int(value)
		"siege_range": return "+%d siege range" % int(value)
		_:
			if value is float:
				return "%s: %.1f" % [effect_key, value]
			return "%s: %s" % [effect_key, str(value)]

func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Free"
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = _resource_icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return " ".join(parts)

func on_research_button_pressed(tech_id: String) -> void:
	var tech_manager: TechnologyManager = get_node_or_null("/root/TechnologyManager")
	if tech_manager and tech_manager.research_technology(tech_id, GameManager.local_player_id, _current_building_id):
		EventBus.button_pressed.emit("research_" + tech_id, GameManager.local_player_id)
		refresh_tech_list(_current_building_type)
		_update_queue_display()

func _update_queue_display() -> void:
	var tech_manager: TechnologyManager = get_node_or_null("/root/TechnologyManager")
	if not tech_manager:
		_hide_queue()
		return

	var queue: Array = tech_manager.get_research_queue(GameManager.local_player_id)
	var is_researching: bool = tech_manager.is_researching(GameManager.local_player_id)

	if queue.is_empty():
		_hide_queue()
		return

	_queue_label.visible = true
	_queue_container.visible = true

	for child: Node in _queue_container.get_children():
		child.queue_free()

	for i in range(queue.size()):
		var tech_id: String = queue[i]
		var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
		var display_name: String = tech_data.get("display_name", tech_id.capitalize())

		var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = Vector2(56, 56)

		var slot_style: StyleBoxFlat = StyleBoxFlat.new()
		if i == 0 and is_researching:
			slot_style.bg_color = Color(0.15, 0.3, 0.5, 0.9)
			slot_style.border_color = Color(0.3, 0.6, 1.0, 1.0)
		else:
			slot_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
			slot_style.border_color = Color(0.3, 0.3, 0.4, 0.6)
		slot_style.border_width_bottom = 2
		slot_style.border_width_top = 2
		slot_style.border_width_left = 2
		slot_style.border_width_right = 2
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		slot.add_theme_stylebox_override("panel", slot_style)

		_queue_container.add_child(slot)

		var slot_label: Label = Label.new()
		slot_label.text = display_name[0] if display_name.length() > 0 else "?"
		slot_label.add_theme_font_size_override("font_size", 14)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(slot_label)

		if i > 0:
			var number_label: Label = Label.new()
			number_label.text = str(i + 1)
			number_label.add_theme_font_size_override("font_size", 10)
			number_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
			number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			number_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			number_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			number_label.offset_right = -4
			number_label.offset_bottom = -4
			slot.add_child(number_label)

	if _progress_bar and is_researching:
		_progress_bar.visible = true
		_progress_label.visible = true
		var progress: float = tech_manager.get_research_progress(GameManager.local_player_id)
		_progress_bar.value = progress * 100.0
		_progress_label.text = "Researching: %d%%" % int(progress * 100.0)
	else:
		_progress_bar.visible = false
		_progress_label.visible = false

func _hide_queue() -> void:
	if _queue_label:
		_queue_label.visible = false
	if _queue_container:
		_queue_container.visible = false
	if _progress_bar:
		_progress_bar.visible = false
	if _progress_label:
		_progress_label.visible = false

func _on_tech_started(tech_id: String, player_id: int, research_time: float) -> void:
	if player_id == GameManager.local_player_id:
		refresh_tech_list(_current_building_type)
		_update_queue_display()

func _on_tech_completed(tech_id: String, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		refresh_tech_list(_current_building_type)
		_update_queue_display()

func _on_tech_progress(tech_id: String, player_id: int, progress: float) -> void:
	if player_id == GameManager.local_player_id and _is_open:
		if _progress_bar:
			_progress_bar.visible = true
			_progress_bar.value = progress * 100.0
		if _progress_label:
			_progress_label.visible = true
			_progress_label.text = "Researching: %d%%" % int(progress * 100.0)

func _on_button_pressed(button_name: String, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		refresh_tech_list(_current_building_type)
		_update_queue_display()

func _find_building_by_id(building_id: int) -> Node2D:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm and bm.has_method("get_building"):
		return bm.get_building(building_id)
	return null