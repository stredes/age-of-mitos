extends Control

var _is_showing: bool = false
var _main_vbox: VBoxContainer = null
var _portrait_area: PanelContainer = null
var _name_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _state_label: Label = null
var _stats_container: VBoxContainer = null
var _commands_container: HBoxContainer = null
var _unit_grid: GridContainer = null
var _unit_grid_container: ScrollContainer = null

var _current_unit_ids: Array = []
var _current_building_id: int = -1
var _resource_icons: Dictionary = {
	"wood": "🪵",
	"stone": "🪨",
	"food": "🍖",
	"gold": "🪙",
}


func _ready() -> void:
	_build_ui()
	visible = false
	if not EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.connect(_on_unit_died)
	if not EventBus.unit_spawned.is_connected(_on_unit_spawned):
		EventBus.unit_spawned.connect(_on_unit_spawned)


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "PanelBG"
	bg.color = Color(0.05, 0.05, 0.1, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_vbox.offset_left = 8
	_main_vbox.offset_right = -8
	_main_vbox.offset_top = 8
	_main_vbox.offset_bottom = -8
	_main_vbox.add_theme_constant_override("separation", 6)
	add_child(_main_vbox)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.text = ""
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_vbox.add_child(_name_label)

	var hp_container: HBoxContainer = HBoxContainer.new()
	hp_container.name = "HPContainer"
	hp_container.add_theme_constant_override("separation", 6)
	_main_vbox.add_child(hp_container)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HPBar"
	_hp_bar.custom_minimum_size = Vector2(120, 14)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	_hp_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.8, 0.2)
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	_hp_bar.add_theme_stylebox_override("fill", bar_fill)

	hp_container.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.name = "HPLabel"
	_hp_label.text = ""
	_hp_label.add_theme_font_size_override("font_size", 12)
	hp_container.add_child(_hp_label)

	_state_label = Label.new()
	_state_label.name = "StateLabel"
	_state_label.text = ""
	_state_label.add_theme_font_size_override("font_size", 12)
	_state_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_vbox.add_child(_state_label)

	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsContainer"
	_stats_container.visible = false
	_stats_container.add_theme_constant_override("separation", 2)
	_main_vbox.add_child(_stats_container)

	_unit_grid_container = ScrollContainer.new()
	_unit_grid_container.name = "UnitGridScroll"
	_unit_grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_unit_grid_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_unit_grid_container.visible = false
	_main_vbox.add_child(_unit_grid_container)

	_unit_grid = GridContainer.new()
	_unit_grid.name = "UnitGrid"
	_unit_grid.columns = 8
	_unit_grid.add_theme_constant_override("h_separation", 4)
	_unit_grid.add_theme_constant_override("v_separation", 4)
	_unit_grid_container.add_child(_unit_grid)

	_commands_container = HBoxContainer.new()
	_commands_container.name = "CommandsContainer"
	_commands_container.add_theme_constant_override("separation", 6
	)
	_commands_container.visible = false
	_main_vbox.add_child(_commands_container)


func show_unit(unit_data: Dictionary, unit_node: Node2D) -> void:
	clear()
	visible = true
	_is_showing = true

	var display_name: String = unit_data.get("display_name", "Unknown")
	_name_label.text = display_name

	_state_label.text = "Idle"

	var hp: int = 0
	var max_hp: int = unit_data.get("hp", 100)
	if unit_node and unit_node.has_method("get"):
		var health_comp: Node = unit_node.get_node_or_null("HealthComponent")
		if health_comp:
			hp = health_comp.get("current_hp") if health_comp.get("current_hp") != null else 0
			max_hp = health_comp.get("max_hp") if health_comp.get("max_hp") != null else max_hp
	update_hp_bar(hp, max_hp)

	_stats_container.visible = true
	_clear_stats()

	var attack: int = unit_data.get("attack", 0)
	var armor: int = unit_data.get("armor", 0)
	var speed: int = unit_data.get("speed", 0)
	var range_val: float = unit_data.get("range", 1.0)

	_add_stat_label("Attack: %d" % attack)
	_add_stat_label("Armor: %d" % armor)
	_add_stat_label("Speed: %d" % speed)
	_add_stat_label("Range: %.1f" % range_val)

	_add_unit_commands(unit_data)


func show_units(unit_nodes: Array) -> void:
	clear()
	visible = true
	_is_showing = true

	_name_label.text = str(unit_nodes.size()) + " Units Selected"
	_state_label.text = ""
	_hp_bar.visible = false
	_hp_label.visible = false
	_stats_container.visible = false

	_unit_grid_container.visible = true
	for child: Node in _unit_grid.get_children():
		child.queue_free()

	for node_variant: Variant in unit_nodes:
		var unit_node: Node = node_variant as Node
		if not is_instance_valid(unit_node):
			continue

		var unit_type: String = unit_node.get("unit_type") if unit_node.has_method("get") and unit_node.get("unit_type") != null else "unknown"
		var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
		var display_name: String = unit_data.get("display_name", unit_type.capitalize())

		var cell: PanelContainer = PanelContainer.new()
		cell.custom_minimum_size = Vector2(48, 48)

		var cell_style: StyleBoxFlat = StyleBoxFlat.new()
		cell_style.bg_color = Color(0.12, 0.15, 0.2, 0.9)
		cell_style.border_color = Color(0.3, 0.4, 0.5, 0.6)
		cell_style.border_width_bottom = 1
		cell_style.border_width_top = 1
		cell_style.border_width_left = 1
		cell_style.border_width_right = 1
		cell_style.corner_radius_top_left = 3
		cell_style.corner_radius_top_right = 3
		cell_style.corner_radius_bottom_left = 3
		cell_style.corner_radius_bottom_right = 3
		cell.add_theme_stylebox_override("panel", cell_style)

		_unit_grid.add_child(cell)

		var cell_vbox: VBoxContainer = VBoxContainer.new()
		cell_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cell_vbox.add_theme_constant_override("separation", 1)
		cell.add_child(cell_vbox)

		var name_lbl: Label = Label.new()
		name_lbl.text = display_name[0] if display_name.length() > 0 else "?"
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell_vbox.add_child(name_lbl)

		var hp_val: int = 0
		var max_hp_val: int = unit_data.get("hp", 100)
		if unit_node.has_method("get"):
			var hc: Node = unit_node.get_node_or_null("HealthComponent")
			if hc:
				hp_val = hc.get("current_hp") if hc.get("current_hp") != null else 0
				max_hp_val = hc.get("max_hp") if hc.get("max_hp") != null else max_hp_val

		var mini_bar: ProgressBar = ProgressBar.new()
		mini_bar.custom_minimum_size = Vector2(36, 4)
		mini_bar.max_value = max_hp_val
		mini_bar.value = hp_val
		mini_bar.show_percentage = false

		var mini_fill: StyleBoxFlat = StyleBoxFlat.new()
		mini_fill.bg_color = _get_hp_color(hp_val, max_hp_val)
		mini_fill.corner_radius_top_left = 2
		mini_fill.corner_radius_top_right = 2
		mini_fill.corner_radius_bottom_left = 2
		mini_fill.corner_radius_bottom_right = 2
		mini_bar.add_theme_stylebox_override("fill", mini_fill)

		var mini_bg: StyleBoxFlat = StyleBoxFlat.new()
		mini_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		mini_bg.corner_radius_top_left = 2
		mini_bg.corner_radius_top_right = 2
		mini_bg.corner_radius_bottom_left = 2
		mini_bg.corner_radius_bottom_right = 2
		mini_bar.add_theme_stylebox_override("background", mini_bg)

		cell_vbox.add_child(mini_bar)

	var first_data: Dictionary = {}
	if unit_nodes.size() > 0 and is_instance_valid(unit_nodes[0]):
		var first_node: Node = unit_nodes[0] as Node
		var ftype: String = first_node.get("unit_type") if first_node.has_method("get") and first_node.get("unit_type") != null else ""
		first_data = DataManager.get_unit_data(ftype)

	if not first_data.is_empty():
		_add_unit_commands(first_data)
	else:
		_add_group_commands()


func show_building(building_data: Dictionary, building_node: Node2D) -> void:
	clear()
	visible = true
	_is_showing = true

	var display_name: String = building_data.get("display_name", "Unknown Building")
	var is_constructed: bool = true
	if building_node and building_node.has_method("get"):
		is_constructed = building_node.get("is_constructed") if building_node.get("is_constructed") != null else true

	if not is_constructed:
		_name_label.text = display_name + " (Building...)"
	else:
		_name_label.text = display_name

	_state_label.text = ""

	var hp: int = 0
	var max_hp: int = building_data.get("hp", 100)
	if building_node and building_node.has_method("get"):
		hp = building_node.get("current_hp") if building_node.get("current_hp") != null else 0
		max_hp = building_node.get("max_hp") if building_node.get("max_hp") != null else max_hp
	update_hp_bar(hp, max_hp)

	if not is_constructed:
		_state_label.text = "Under Construction"
		var current: int = building_node.get("current_hp") if building_node and building_node.has_method("get") and building_node.get("current_hp") != null else 0
		var total: int = building_node.get("construction_total") if building_node and building_node.has_method("get") and building_node.get("construction_total") != null else max_hp
		if total > 0:
			var progress: float = float(current) / float(total)
			_hp_bar.value = progress * 100.0

	_stats_container.visible = true
	_clear_stats()

	var armor: int = building_data.get("armor", 0)
	var sight: int = building_data.get("sight", 0)
	var garrison_cap: int = building_data.get("garrison_capacity", 0)

	_add_stat_label("Armor: %d" % armor)
	_add_stat_label("Sight: %d" % sight)
	if garrison_cap > 0:
		_add_stat_label("Garrison: %d" % garrison_cap)

	var produces: Array = building_data.get("produces", [])
	if produces.size() > 0 and is_constructed:
		_add_building_commands(building_data, building_node)


func clear() -> void:
	_is_showing = false
	visible = false
	_current_unit_ids.clear()
	_current_building_id = -1
	if _name_label:
		_name_label.text = ""
	if _state_label:
		_state_label.text = ""
	if _hp_bar:
		_hp_bar.visible = true
	if _hp_label:
		_hp_label.visible = true
	_clear_stats()
	clear_commands()
	if _unit_grid_container:
		_unit_grid_container.visible = false
	if _unit_grid:
		for child: Node in _unit_grid.get_children():
			child.queue_free()


func update_hp_bar(current: int, max_val: int) -> void:
	if _hp_bar:
		_hp_bar.visible = true
		_hp_bar.max_value = max_val
		_hp_bar.value = current

		var fill: StyleBoxFlat = _hp_bar.get_theme_stylebox_override("fill") as StyleBoxFlat
		if fill == null:
			fill = StyleBoxFlat.new()
		fill.bg_color = _get_hp_color(current, max_val)
		_hp_bar.add_theme_stylebox_override("fill", fill)

	if _hp_label:
		_hp_label.visible = true
		_hp_label.text = "%d/%d" % [current, max_val]


func add_command_button(label: String, icon_text: String, callback: Callable) -> void:
	if _commands_container == null:
		return
	_commands_container.visible = true

	var btn: Button = Button.new()
	btn.name = "Cmd_" + label
	btn.custom_minimum_size = Vector2(64, 48)
	var hotkey: String = _get_command_hotkey(label)
	var label_text: String = label + (" [" + hotkey + "]" if not hotkey.is_empty() else "")
	btn.text = icon_text + "\n" + label_text if icon_text.length() > 0 else label_text
	btn.tooltip_text = _get_command_tooltip(label, hotkey)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.2, 0.3, 0.9)
	btn_style.border_color = Color(0.3, 0.5, 0.7, 0.7)
	btn_style.border_width_bottom = 1
	btn_style.border_width_top = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.content_margin_left = 6
	btn_style.content_margin_right = 6
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.3, 0.45, 1.0)
	btn_hover.border_color = Color(0.4, 0.6, 0.9, 1.0)
	btn.add_theme_stylebox_override("hover", btn_hover)

	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func() -> void:
		_play_button_feedback(btn)
		callback.call()
	)
	_commands_container.add_child(btn)


func _play_button_feedback(button: Button) -> void:
	if button == null:
		return
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.94, 0.94), 0.045)
	tween.tween_property(button, "scale", Vector2.ONE, 0.08)


func _get_command_hotkey(label: String) -> String:
	var lower_label: String = label.to_lower()
	if lower_label.begins_with("attack"):
		return "A"
	if lower_label.begins_with("move"):
		return "M"
	if lower_label.begins_with("stop"):
		return "S"
	if lower_label.begins_with("build"):
		return "B"
	if lower_label.begins_with("wood"):
		return "W"
	if lower_label.begins_with("food"):
		return "F"
	if lower_label.begins_with("stone"):
		return "T"
	if lower_label.begins_with("gold"):
		return "G"
	if lower_label.contains("villager"):
		return "V"
	if lower_label.contains("swordsman"):
		return "Z"
	if lower_label.contains("spearman"):
		return "P"
	if lower_label.contains("archer"):
		return "R"
	if lower_label.contains("cavalry"):
		return "C"
	return ""


func _get_command_tooltip(label: String, hotkey: String) -> String:
	var tip: String = label
	if not hotkey.is_empty():
		tip += "\nHotkey: " + hotkey
	return tip


func clear_commands() -> void:
	if _commands_container == null:
		return
	for child: Node in _commands_container.get_children():
		child.queue_free()
	_commands_container.visible = false


func _add_unit_commands(unit_data: Dictionary) -> void:
	var unit_type: String = unit_data.get("name", "")
	var states: Array = unit_data.get("states", [])

	if "attack" in states:
		add_command_button("Attack", "⚔️", func() -> void: EventBus.button_pressed.emit("attack_command", GameManager.local_player_id))
	if "move" in states:
		add_command_button("Move", "👟", func() -> void: EventBus.button_pressed.emit("move_command", GameManager.local_player_id))
	add_command_button("Stop", "🛑", func() -> void: EventBus.button_pressed.emit("stop_command", GameManager.local_player_id))

	if unit_data.get("gather_rate", null) != null:
		add_command_button("Wood", "🪵", func() -> void: EventBus.villager_assigned.emit(-1, -1, "gather_wood"))
		add_command_button("Food", "🍖", func() -> void: EventBus.villager_assigned.emit(-1, -1, "gather_food"))
		add_command_button("Stone", "🪨", func() -> void: EventBus.villager_assigned.emit(-1, -1, "gather_stone"))
		add_command_button("Gold", "🪙", func() -> void: EventBus.villager_assigned.emit(-1, -1, "gather_gold"))
		add_command_button("Build", "🔨", func() -> void: EventBus.button_pressed.emit("build_menu", GameManager.local_player_id))


func _add_group_commands() -> void:
	add_command_button("Attack", "⚔️", func() -> void: EventBus.button_pressed.emit("attack_command", GameManager.local_player_id))
	add_command_button("Move", "👟", func() -> void: EventBus.button_pressed.emit("move_command", GameManager.local_player_id))
	add_command_button("Stop", "🛑", func() -> void: EventBus.button_pressed.emit("stop_command", GameManager.local_player_id))


func _add_building_commands(building_data: Dictionary, building_node: Node2D) -> void:
	var produces: Array = building_data.get("produces", [])
	for unit_type: String in produces:
		var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
		var unit_name: String = unit_data.get("display_name", unit_type.capitalize())
		var cost_text: String = _format_cost_short(unit_data.get("cost", {}))
		add_command_button(unit_name + cost_text, "➕", func() -> void: _train_unit(building_node, unit_type))


func _train_unit(building_node: Node, unit_type: String) -> void:
	if building_node == null:
		return
	EventBus.button_pressed.emit("train_" + unit_type, GameManager.local_player_id)


func _add_stat_label(text: String) -> void:
	if _stats_container == null:
		return
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_stats_container.add_child(lbl)


func _clear_stats() -> void:
	if _stats_container == null:
		return
	for child: Node in _stats_container.get_children():
		child.queue_free()


func _get_hp_color(current: int, maximum: int) -> Color:
	if maximum <= 0:
		return Color.RED
	var ratio: float = float(current) / float(maximum)
	if ratio > 0.66:
		return Color(0.2, 0.8, 0.2)
	elif ratio > 0.33:
		return Color(0.9, 0.9, 0.2)
	else:
		return Color(0.9, 0.2, 0.2)


func _format_cost_short(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = _resource_icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return " " + " ".join(parts)


func _on_unit_died(unit_id: int, _killer_id: int, player_id: int) -> void:
	if player_id != GameManager.local_player_id:
		return
	if unit_id in _current_unit_ids:
		_current_unit_ids.erase(unit_id)
		if _current_unit_ids.is_empty():
			clear()
		else:
			show_units(_get_nodes_for_ids(_current_unit_ids))


func _on_unit_spawned(_unit_id: int, _unit_type: String, _player_id: int, _position: Vector2) -> void:
	pass


func _get_nodes_for_ids(ids: Array) -> Array:
	var nodes: Array = []
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for uid: Variant in ids:
		for unit_node: Node in all_units:
			if unit_node.has_method("get") and unit_node.get("unit_id") == uid:
				nodes.append(unit_node)
				break
	return nodes
