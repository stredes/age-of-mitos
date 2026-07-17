extends Control

signal command_issued(command: String, params: Dictionary)

var _grid: GridContainer = null
var _info_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _name_label: Label = null
var _queue_container: HBoxContainer = null

var _current_selection_type: String = ""
var _current_unit_ids: Array = []
var _current_building_id: int = -1
var _queued_commands: Array[Dictionary] = []

const GRID_COLUMNS: int = 5
const BUTTON_SIZE: Vector2 = Vector2(52, 52)
const ICON_FONT_SIZE: int = 20
const LABEL_FONT_SIZE: int = 10

var _resource_icons: Dictionary = {
	"wood": "W",
	"stone": "S",
	"food": "F",
	"gold": "G",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -340
	offset_top = -260
	offset_right = -10
	offset_bottom = -10

	var bg: PanelContainer = PanelContainer.new()
	bg.name = "CardBG"
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	bg_style.border_color = Color(0.45, 0.38, 0.15, 0.6)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(4)
	bg_style.set_content_margin_all(6)
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "CardLayout"
	vbox.add_theme_constant_override("separation", 4)
	bg.add_child(vbox)

	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.text = ""
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
	vbox.add_child(_info_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HPBar"
	_hp_bar.custom_minimum_size = Vector2(200, 8)
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.visible = false
	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	hp_bg.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.2, 0.75, 0.2)
	hp_fill.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	vbox.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.name = "HPLabel"
	_hp_label.add_theme_font_size_override("font_size", 10)
	_hp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_hp_label.visible = false
	vbox.add_child(_hp_label)

	_grid = GridContainer.new()
	_grid.name = "CommandGrid"
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(_grid)

	_queue_container = HBoxContainer.new()
	_queue_container.name = "QueueContainer"
	_queue_container.add_theme_constant_override("separation", 2)
	_queue_container.visible = false
	vbox.add_child(_queue_container)


func show_selection(unit_ids: Array, building_id: int) -> void:
	_current_unit_ids = unit_ids.duplicate()
	_current_building_id = building_id
	_queued_commands.clear()
	_clear_grid()

	if unit_ids.size() == 0 and building_id == -1:
		visible = false
		return

	visible = true

	if building_id != -1:
		_show_building_card(building_id)
	elif unit_ids.size() == 1:
		_show_single_unit_card(unit_ids[0])
	elif unit_ids.size() > 1:
		_show_multi_unit_card(unit_ids)


func _show_single_unit_card(unit_id: int) -> void:
	var unit_node: Node = _find_unit_by_id(unit_id)
	if unit_node == null:
		_info_label.text = "Unknown Unit"
		return

	var unit_type: String = unit_node.get("unit_type") if unit_node.get("unit_type") != null else "unknown"
	var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
	var display_name: String = unit_data.get("display_name", unit_type.capitalize())
	_current_selection_type = unit_type

	_info_label.text = display_name
	_show_unit_hp(unit_node)

	if unit_type == "villager":
		_add_command_button("chop", "W", "Gather Wood", func() -> void: command_issued.emit("gather_wood", {"unit_id": unit_id}))
		_add_command_button("mine", "S", "Mine Stone", func() -> void: command_issued.emit("gather_stone", {"unit_id": unit_id}))
		_add_command_button("hunt", "F", "Gather Food", func() -> void: command_issued.emit("gather_food", {"unit_id": unit_id}))
		_add_command_button("trade", "G", "Mine Gold", func() -> void: command_issued.emit("gather_gold", {"unit_id": unit_id}))
		_add_command_button("build", "B", "Build", func() -> void: command_issued.emit("build", {}))
		_add_command_button("repair", "R", "Repair", func() -> void: command_issued.emit("repair", {}))
		_add_command_button("stop", "S", "Stop", func() -> void: command_issued.emit("stop", {}))
		_fill_empty(10)
	else:
		var unit_states: Array = unit_data.get("states", [])
		if "attack" in unit_states:
			_add_command_button("attack", "A", "Attack", func() -> void: command_issued.emit("attack", {}))
		if "move" in unit_states:
			_add_command_button("move", "M", "Move", func() -> void: command_issued.emit("move", {}))
		_add_command_button("stop", "S", "Stop", func() -> void: command_issued.emit("stop", {}))
		_add_command_button("guard", "G", "Guard", func() -> void: command_issued.emit("guard", {}))
		_fill_empty(10)


func _show_multi_unit_card(unit_ids: Array) -> void:
	var types: Dictionary = {}
	var has_villager: bool = false
	var has_military: bool = false

	for uid in unit_ids:
		var node: Node = _find_unit_by_id(uid)
		if node == null:
			continue
		var utype: String = node.get("unit_type") if node.get("unit_type") != null else "unknown"
		types[utype] = types.get(utype, 0) + 1
		if utype == "villager":
			has_villager = true
		else:
			has_military = true

	_current_selection_type = "multi"
	_info_label.text = str(unit_ids.size()) + " Units"

	_add_command_button("attack", "A", "Attack", func() -> void: command_issued.emit("attack", {}))
	_add_command_button("move", "M", "Move", func() -> void: command_issued.emit("move", {}))
	_add_command_button("stop", "S", "Stop", func() -> void: command_issued.emit("stop", {}))

	if has_villager:
		_add_command_button("build", "B", "Build", func() -> void: command_issued.emit("build", {}))
		_add_command_button("chop", "W", "Gather", func() -> void: command_issued.emit("gather_wood", {}))
	else:
		_add_command_button("guard", "G", "Guard", func() -> void: command_issued.emit("guard", {}))

	_fill_empty(10)


func _show_building_card(building_id: int) -> void:
	var building_node: Node = _find_building_by_id(building_id)
	if building_node == null:
		_info_label.text = "Unknown Building"
		return

	var building_type: String = building_node.get("building_type") if building_node.get("building_type") != null else "unknown"
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	var display_name: String = building_data.get("display_name", building_type.capitalize())
	var is_constructed: bool = building_node.get("is_constructed") if building_node.get("is_constructed") != null else true
	_current_selection_type = building_type

	if is_constructed:
		_info_label.text = display_name
	else:
		_info_label.text = display_name + " (Building...)"

	_show_building_hp(building_node)

	if not is_constructed:
		_add_command_button("stop", "X", "Cancel", func() -> void: command_issued.emit("cancel_construction", {"building_id": building_id}))
		_fill_empty(10)
		return

	var produces: Array = building_data.get("produces", [])
	if produces.size() > 0:
		for unit_type: String in produces:
			var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
			var unit_name: String = unit_data.get("display_name", unit_type.capitalize())
			var cost: Dictionary = unit_data.get("cost", {})
			var hotkey: String = unit_name[0].to_upper() if unit_name.length() > 0 else "?"
			_add_command_button("train_" + unit_type, hotkey, unit_name, func() -> void: command_issued.emit("train_" + unit_type, {"building_id": building_id}), cost)

	var techs: Array = building_data.get("technologies", [])
	if techs.size() > 0:
		for tech_id: String in techs:
			var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
			var tech_name: String = tech_data.get("display_name", tech_id.capitalize())
			_add_command_button("research_" + tech_id, "T", tech_name, func() -> void: command_issued.emit("research_" + tech_id, {"building_id": building_id}))

	_add_command_button("garrison", "G", "Garrison", func() -> void: command_issued.emit("garrison", {"building_id": building_id}))

	_fill_empty(10)


func _add_command_button(cmd_id: String, hotkey: String, label_text: String, callback: Callable, cost: Dictionary = {}) -> void:
	var btn: Button = Button.new()
	btn.name = cmd_id.capitalize()
	btn.custom_minimum_size = BUTTON_SIZE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.16, 0.24, 0.9)
	btn_style.border_color = Color(0.35, 0.32, 0.12, 0.5)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover: StyleBoxFlat = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.2, 0.28, 0.42, 0.95)
	btn_hover.border_color = Color(0.92, 0.78, 0.38)
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(3)
	btn_hover.set_content_margin_all(2)
	btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed: StyleBoxFlat = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.08, 0.12, 0.2, 1.0)
	btn_pressed.border_color = Color(0.92, 0.78, 0.38)
	btn_pressed.set_border_width_all(1)
	btn_pressed.set_corner_radius_all(3)
	btn_pressed.set_content_margin_all(2)
	btn.add_theme_stylebox_override("pressed", btn_pressed)

	btn.pressed.connect(callback)

	var inner_vbox: VBoxContainer = VBoxContainer.new()
	inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_theme_constant_override("separation", 0)
	btn.add_child(inner_vbox)

	var icon_lbl: Label = Label.new()
	icon_lbl.text = hotkey
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", ICON_FONT_SIZE)
	icon_lbl.add_theme_color_override("font_color", Color(0.92, 0.85, 0.55))
	inner_vbox.add_child(icon_lbl)

	var name_lbl: Label = Label.new()
	name_lbl.text = label_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	name_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	inner_vbox.add_child(name_lbl)

	if not cost.is_empty():
		var cost_lbl: Label = Label.new()
		cost_lbl.text = _format_cost_short(cost)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 8)
		cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.45))
		inner_vbox.add_child(cost_lbl)

	_grid.add_child(btn)


func _fill_empty(count: int) -> void:
	var current: int = _grid.get_child_count()
	var remaining: int = count - (current % count) if current % count != 0 else 0
	for i in range(remaining):
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = BUTTON_SIZE
		_grid.add_child(spacer)


func _clear_grid() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	_info_label.text = ""
	_hp_bar.visible = false
	_hp_label.visible = false
	_queue_container.visible = false
	for child: Node in _queue_container.get_children():
		child.queue_free()


func _show_unit_hp(unit_node: Node) -> void:
	var health_comp: Node = unit_node.get_node_or_null("HealthComponent")
	if health_comp == null:
		return
	var current_hp: int = health_comp.get("current_hp") if health_comp.get("current_hp") != null else 0
	var max_hp: int = health_comp.get("max_hp") if health_comp.get("max_hp") != null else 1

	_hp_bar.visible = true
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp

	var fill: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = _get_hp_color(current_hp, max_hp)

	_hp_label.visible = true
	_hp_label.text = "%d/%d" % [current_hp, max_hp]


func _show_building_hp(building_node: Node) -> void:
	var current_hp: int = building_node.get("current_hp") if building_node.get("current_hp") != null else 0
	var max_hp: int = building_node.get("max_hp") if building_node.get("max_hp") != null else 1

	_hp_bar.visible = true
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp

	var fill: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = _get_hp_color(current_hp, max_hp)

	_hp_label.visible = true
	_hp_label.text = "%d/%d" % [current_hp, max_hp]


func _get_hp_color(current: int, maximum: int) -> Color:
	if maximum <= 0:
		return Color.RED
	var ratio: float = float(current) / float(maximum)
	if ratio > 0.66:
		return Color(0.2, 0.78, 0.2)
	elif ratio > 0.33:
		return Color(0.88, 0.85, 0.2)
	else:
		return Color(0.88, 0.2, 0.2)


func _format_cost_short(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = _resource_icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return " ".join(parts)


func _find_unit_by_id(unit_id: int) -> Node:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if unit.has_method("get") and unit.get("unit_id") != null and unit.get("unit_id") == unit_id:
			return unit
	return null


func _find_building_by_id(building_id: int) -> Node2D:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm and bm.has_method("get_building"):
		return bm.get_building(building_id)
	return null


func get_selection_type() -> String:
	return _current_selection_type
