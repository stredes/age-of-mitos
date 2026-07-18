extends Control

const BUTTON_SIZE = 80
const BUTTON_SEPARATION = 8
const BOTTOM_MARGIN = 10

var _commands_container: HBoxContainer = null
var _background: ColorRect = null
var _cmd: CommandManager = null
var _is_visible: bool = false
var _current_selection_type: String = ""
var _current_unit_type: String = ""
var _current_building_type: String = ""
var _selection_count: int = 0

var _resource_icons: Dictionary = {
	"wood": "🪵",
	"stone": "🪨",
	"food": "🍖",
	"gold": "🪙",
}

var _command_icons: Dictionary = {
	"attack": "⚔️",
	"stop": "🛑",
	"build": "🔨",
	"gather_wood": "🪵",
	"gather_food": "🍖",
	"gather_stone": "🪨",
	"gather_gold": "🪙",
}

var _tooltip_data: Dictionary = {
	"attack":       {"title": "Attack",       "desc": "Enter attack-targeting mode.\nTap an enemy unit or building to attack it.", "hotkey": "A"},
	"stop":         {"title": "Stop",         "desc": "Cancel the current order.\nUnit returns to idle immediately.",              "hotkey": "S"},
	"move":         {"title": "Move",         "desc": "Enter move-targeting mode.\nTap a location to move to.",                    "hotkey": "M"},
	"build":        {"title": "Build",        "desc": "Open the building menu.\nSelect a structure to construct.",                  "hotkey": "B"},
	"gather_wood":  {"title": "Gather Wood",  "desc": "Send villager to chop the nearest tree\nand carry wood back.",               "hotkey": "W"},
	"gather_food":  {"title": "Gather Food",  "desc": "Send villager to harvest the nearest\nfood source and carry it back.",       "hotkey": "F"},
	"gather_stone": {"title": "Mine Stone",   "desc": "Send villager to mine the nearest\nstone deposit and carry it back.",        "hotkey": "T"},
	"gather_gold":  {"title": "Mine Gold",    "desc": "Send villager to mine the nearest\ngold deposit and carry it back.",         "hotkey": "G"},
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cmd = _find_command_manager()
	_build_ui()
	visible = false
	_connect_signals()

func _find_command_manager() -> CommandManager:
	var cm: CommandManager = get_node_or_null("/root/GameWorld/CommandManager") as CommandManager
	if cm != null:
		return cm
	cm = get_node_or_null("/root/GameWorld/World/CommandManager") as CommandManager
	return cm

func _build_ui() -> void:
	_background = ColorRect.new()
	_background.name = "CommandsBackground"
	_background.color = Color(0.05, 0.05, 0.1, 0.85)
	_background.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_background.offset_top = -(BUTTON_SIZE + BOTTOM_MARGIN * 2)
	_background.offset_bottom = -BOTTOM_MARGIN
	_background.offset_left = BOTTOM_MARGIN
	_background.offset_right = -BOTTOM_MARGIN
	
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	_background.add_theme_stylebox_override("panel", bg_style)
	add_child(_background)

	_commands_container = HBoxContainer.new()
	_commands_container.name = "CommandsContainer"
	_commands_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_commands_container.offset_left = BUTTON_SEPARATION
	_commands_container.offset_right = -BUTTON_SEPARATION
	_commands_container.offset_top = BOTTOM_MARGIN
	_commands_container.offset_bottom = -BOTTOM_MARGIN
	_commands_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_commands_container.add_theme_constant_override("separation", BUTTON_SEPARATION)
	_background.add_child(_commands_container)

func _connect_signals() -> void:
	if not EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.connect(_on_selection_changed)
	if not EventBus.unit_selected.is_connected(_on_unit_selected):
		EventBus.unit_selected.connect(_on_unit_selected)
	if not EventBus.building_selected.is_connected(_on_building_selected):
		EventBus.building_selected.connect(_on_building_selected)
	if not EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.connect(_on_unit_died)
	if not EventBus.building_completed.is_connected(_on_building_completed):
		EventBus.building_completed.connect(_on_building_completed)

func _on_selection_changed(selected_unit_ids: Array, selected_building_ids: Array) -> void:
	if selected_unit_ids.size() > 0:
		_selection_count = selected_unit_ids.size()
		var first_unit: Node = _find_unit_by_id(selected_unit_ids[0])
		if first_unit and first_unit.has_method("get"):
			_current_unit_type = first_unit.get("unit_type") if first_unit.get("unit_type") != null else ""
		_current_selection_type = "units"
		_current_building_type = ""
		_update_commands()
		_show()
	elif selected_building_ids.size() > 0:
		_selection_count = 1
		var building_id: int = selected_building_ids[0]
		var building: Node = _find_building_by_id(building_id)
		if building and building.has_method("get"):
			_current_building_type = building.get("building_type") if building.get("building_type") != null else ""
		_current_selection_type = "building"
		_current_unit_type = ""
		_update_commands()
		_show()
	else:
		_hide()

func _on_unit_selected(unit_id: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		_selection_count = 1
		var unit: Node = _find_unit_by_id(unit_id)
		if unit and unit.has_method("get"):
			_current_unit_type = unit.get("unit_type") if unit.get("unit_type") != null else ""
		_current_selection_type = "units"
		_current_building_type = ""
		_update_commands()
		_show()

func _on_building_selected(building_id: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		_selection_count = 1
		var building: Node = _find_building_by_id(building_id)
		if building and building.has_method("get"):
			_current_building_type = building.get("building_type") if building.get("building_type") != null else ""
		_current_selection_type = "building"
		_current_unit_type = ""
		_update_commands()
		_show()

func _on_unit_died(unit_id: int, _killer_id: int, player_id: int) -> void:
	if player_id != GameManager.local_player_id:
		return
	_selection_count = max(0, _selection_count - 1)
	if _selection_count <= 0:
		_hide()
	else:
		_update_commands()

func _on_building_completed(_building_id: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		_update_commands()

func _update_commands() -> void:
	if _commands_container == null:
		return
	
	for child: Node in _commands_container.get_children():
		child.queue_free()
	
	if _current_selection_type == "units":
		_build_unit_commands()
	elif _current_selection_type == "building":
		_build_building_commands()

func _build_unit_commands() -> void:
	var unit_data: Dictionary = DataManager.get_unit_data(_current_unit_type)
	var unit_states: Array = unit_data.get("states", [])
	
	if "attack" in unit_states:
		_add_button("attack", "Attack", func() -> void: _cmd_attack())
	
	_add_button("stop", "Stop", func() -> void: _cmd_stop())
	
	if _current_unit_type == "villager":
		_add_button("gather_wood", "Wood", func() -> void: _cmd_gather("wood"), _can_afford_villager_task())
		_add_button("gather_food", "Food", func() -> void: _cmd_gather("food"), _can_afford_villager_task())
		_add_button("gather_stone", "Stone", func() -> void: _cmd_gather("stone"), _can_afford_villager_task())
		_add_button("gather_gold", "Gold", func() -> void: _cmd_gather("gold"), _can_afford_villager_task())
		_add_button("build", "Build", func() -> void: _cmd_build(), _can_afford_villager_task())
	
	if "move" in unit_states:
		_add_button("move", "Move", func() -> void: _cmd_move())

func _build_building_commands() -> void:
	var building_data: Dictionary = DataManager.get_building_data(_current_building_type)
	var is_constructed: bool = true
	var produces: Array = building_data.get("produces", [])
	
	if produces.size() > 0 and is_constructed:
		for unit_type: String in produces:
			var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
			var unit_name: String = unit_data.get("display_name", unit_type.capitalize())
			var cost: Dictionary = unit_data.get("cost", {})
			var pop_cost: int = unit_data.get("pop_cost", 1)
			var can_afford: bool = GameManager.can_afford(cost, GameManager.local_player_id)
			var has_pop: bool = _can_train_unit(unit_type, pop_cost)
			var cost_text: String = _format_cost_short(cost)
			var disabled_reason: String = ""
			if not has_pop:
				disabled_reason = "Poblacion maxima alcanzada"
			elif not can_afford:
				disabled_reason = "Recursos insuficientes"
			_add_button("train_" + unit_type, unit_name + cost_text, func() -> void: _cmd_train(unit_type), disabled_reason)


func _can_train_unit(unit_type: String, pop_cost: int) -> bool:
	var rm: Node = get_node_or_null("/root/GameWorld/ResourceManager")
	if rm == null:
		return true
	var pop_data: Dictionary = rm.get_pop(GameManager.local_player_id)
	return pop_data["current"] + pop_cost <= pop_data["max"]

func _add_button(action_id: String, label: String, callback: Callable, disabled_reason: String = "") -> void:
	if _commands_container == null:
		return
	
	var btn: Button = Button.new()
	btn.name = "CmdBtn_" + action_id
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.text = _command_icons.get(action_id, "") + "\n" + label
	btn.disabled = disabled_reason.length() > 0
	btn.tooltip_text = label + (": " + disabled_reason if disabled_reason.length() > 0 else "")
	
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	if disabled_reason.length() > 0:
		style_normal.bg_color = Color(0.2, 0.15, 0.15, 0.9)
		style_normal.border_color = Color(0.4, 0.25, 0.25, 0.7)
	else:
		style_normal.bg_color = Color(0.15, 0.2, 0.3, 0.9)
		style_normal.border_color = Color(0.3, 0.5, 0.7, 0.7)
	style_normal.border_width_bottom = 2
	style_normal.border_width_top = 2
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 6
	style_normal.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
	if disabled_reason.length() > 0:
		style_hover.bg_color = Color(0.25, 0.18, 0.18, 1.0)
		style_hover.border_color = Color(0.5, 0.3, 0.3, 0.8)
	else:
		style_hover.bg_color = Color(0.2, 0.3, 0.45, 1.0)
		style_hover.border_color = Color(0.4, 0.6, 0.9, 1.0)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	var style_pressed: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
	if disabled_reason.length() > 0:
		style_pressed.bg_color = Color(0.15, 0.12, 0.12, 1.0)
		style_pressed.border_color = Color(0.3, 0.2, 0.2, 0.6)
	else:
		style_pressed.bg_color = Color(0.1, 0.2, 0.35, 1.0)
		style_pressed.border_color = Color(0.2, 0.4, 0.6, 1.0)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	var style_disabled: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
	style_disabled.bg_color = Color(0.15, 0.12, 0.12, 0.9)
	style_disabled.border_color = Color(0.3, 0.2, 0.2, 0.5)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.4, 0.4))
	
	btn.pressed.connect(func() -> void:
		_play_press_feedback(btn)
		callback.call()
	)
	
	var tip: Dictionary = _tooltip_data.get(action_id, {})
	if not tip.is_empty():
		TooltipSystem.register_button(btn, tip.get("title", label), tip.get("desc", ""), tip.get("hotkey", ""))
	
	_commands_container.add_child(btn)

func _play_press_feedback(button: Button) -> void:
	if button == null:
		return
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.92, 0.92), 0.04)
	tween.tween_property(button, "scale", Vector2.ONE, 0.08)

func _cmd_stop() -> void:
	if _cmd == null:
		return
	_cmd.issue_command(UnitCommand.stop(false, GameManager.local_player_id))

func _cmd_attack() -> void:
	EventBus.button_pressed.emit("attack_command", GameManager.local_player_id)

func _cmd_move() -> void:
	EventBus.button_pressed.emit("move_command", GameManager.local_player_id)

func _cmd_build() -> void:
	EventBus.menu_opened.emit("build_menu")

func _cmd_gather(resource_type: String) -> void:
	if _cmd == null:
		return
	_cmd.handle_gather_command(resource_type, GameManager.local_player_id)

func _cmd_train(unit_type: String) -> void:
	if _cmd == null:
		return
	_cmd.issue_command(UnitCommand.train(unit_type, GameManager.local_player_id))

func _can_afford_villager_task() -> bool:
	var resources: Dictionary = GameManager.get_resources()
	return resources.get("wood", 0) >= 0 and resources.get("food", 0) >= 0

func _format_cost_short(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = _resource_icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return "\n" + " ".join(parts)

func _show() -> void:
	if not _is_visible:
		_is_visible = true
		visible = true
		_background.visible = true
		_modulate.a = 1.0

func _hide() -> void:
	if _is_visible:
		_is_visible = false
		visible = false
		_background.visible = false
		_current_selection_type = ""
		_current_unit_type = ""
		_current_building_type = ""
		_selection_count = 0

func _find_unit_by_id(unit_id: int) -> Node:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if unit.has_method("get") and unit.get("unit_id") != null and unit.get("unit_id") == unit_id:
			return unit
	return null

func _find_building_by_id(building_id: int) -> Node:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm and bm.has_method("get_building"):
		return bm.get_building(building_id)
	return null