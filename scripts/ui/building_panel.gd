extends Control
## Detailed building info panel showing stats, production queue with
## individual progress, rally point, and garrison.
##
## Positioned at the left side when a building is selected.

var _name_label: Label = null
var _type_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _stats_container: VBoxContainer = null
var _queue_label: Label = null
var _queue_container: VBoxContainer = null
var _rally_label: Label = null
var _rally_info: Label = null
var _rally_clear_btn: Button = null
var _garrison_label: Label = null
var _garrison_container: VBoxContainer = null
var _produce_container: HBoxContainer = null

var _current_building_id: int = -1
var _current_building_type: String = ""

const SLOT_SIZE: Vector2 = Vector2(44, 44)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 10
	offset_top = -320
	offset_right = 280
	offset_bottom = -10

	var bg: PanelContainer = PanelContainer.new()
	bg.name = "PanelBG"
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	bg_style.border_color = Color(0.4, 0.35, 0.15, 0.5)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(5)
	bg_style.set_content_margin_all(10)
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "Layout"
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color(0.92, 0.85, 0.55))
	vbox.add_child(_name_label)

	_type_label = Label.new()
	_type_label.name = "TypeLabel"
	_type_label.add_theme_font_size_override("font_size", 11)
	_type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(_type_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HPBar"
	_hp_bar.custom_minimum_size = Vector2(200, 10)
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.12, 0.12, 0.15, 0.8)
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
	_hp_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	vbox.add_child(_hp_label)

	_stats_container = VBoxContainer.new()
	_stats_container.name = "Stats"
	_stats_container.add_theme_constant_override("separation", 2)
	vbox.add_child(_stats_container)

	# --- Production Queue ---
	_queue_label = Label.new()
	_queue_label.name = "QueueLabel"
	_queue_label.text = "Production Queue:"
	_queue_label.add_theme_font_size_override("font_size", 12)
	_queue_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	_queue_label.visible = false
	vbox.add_child(_queue_label)

	_queue_container = VBoxContainer.new()
	_queue_container.name = "QueueContainer"
	_queue_container.add_theme_constant_override("separation", 3)
	_queue_container.visible = false
	vbox.add_child(_queue_container)

	# --- Rally Point ---
	_rally_label = Label.new()
	_rally_label.name = "RallyLabel"
	_rally_label.text = "Rally Point:"
	_rally_label.add_theme_font_size_override("font_size", 12)
	_rally_label.add_theme_color_override("font_color", Color(0.35, 0.7, 0.95))
	_rally_label.visible = false
	vbox.add_child(_rally_label)

	var rally_row: HBoxContainer = HBoxContainer.new()
	rally_row.name = "RallyRow"
	rally_row.add_theme_constant_override("separation", 6)
	rally_row.visible = false
	vbox.add_child(rally_row)

	_rally_info = Label.new()
	_rally_info.name = "RallyInfo"
	_rally_info.add_theme_font_size_override("font_size", 11)
	_rally_info.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
	_rally_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rally_row.add_child(_rally_info)

	_rally_clear_btn = Button.new()
	_rally_clear_btn.name = "RallyClear"
	_rally_clear_btn.text = "X"
	_rally_clear_btn.custom_minimum_size = Vector2(22, 18)
	_rally_clear_btn.pressed.connect(_on_rally_clear)
	rally_row.add_child(_rally_clear_btn)

	# --- Garrison ---
	_garrison_label = Label.new()
	_garrison_label.name = "GarrisonLabel"
	_garrison_label.text = "Garrison:"
	_garrison_label.add_theme_font_size_override("font_size", 12)
	_garrison_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	_garrison_label.visible = false
	vbox.add_child(_garrison_label)

	_garrison_container = VBoxContainer.new()
	_garrison_container.name = "GarrisonContainer"
	_garrison_container.add_theme_constant_override("separation", 2)
	_garrison_container.visible = false
	vbox.add_child(_garrison_container)

	_produce_container = HBoxContainer.new()
	_produce_container.name = "ProduceContainer"
	_produce_container.add_theme_constant_override("separation", 3)
	_produce_container.visible = false
	vbox.add_child(_produce_container)


func show_building(building_id: int) -> void:
	_current_building_id = building_id
	var building_node: Node = _find_building_by_id(building_id)
	if building_node == null:
		visible = false
		return

	_current_building_type = building_node.get("building_type") if building_node.get("building_type") != null else ""
	var building_data: Dictionary = DataManager.get_building_data(_current_building_type)
	var display_name: String = building_data.get("display_name", _current_building_type.capitalize())
	var is_constructed: bool = building_node.get("is_constructed") if building_node.get("is_constructed") != null else true

	visible = true

	if _name_label:
		_name_label.text = display_name
	if _type_label:
		_type_label.text = _current_building_type.replace("_", " ").capitalize() + (" (Building...)" if not is_constructed else "")

	_update_hp(building_node)
	_update_stats(building_data)
	_update_queue(building_node, is_constructed)
	_update_rally(building_id)
	_update_garrison(building_node, building_data)
	_update_produce(building_data, is_constructed)


func hide_building() -> void:
	_current_building_id = -1
	_current_building_type = ""
	visible = false


func _update_hp(building_node: Node) -> void:
	var current_hp: int = building_node.get("current_hp") if building_node.get("current_hp") != null else 0
	var max_hp: int = building_node.get("max_hp") if building_node.get("max_hp") != null else 1

	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value = current_hp
		var fill: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			var ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
			if ratio > 0.66:
				fill.bg_color = Color(0.2, 0.75, 0.2)
			elif ratio > 0.33:
				fill.bg_color = Color(0.85, 0.82, 0.2)
			else:
				fill.bg_color = Color(0.85, 0.2, 0.2)

	if _hp_label:
		_hp_label.text = "HP: %d / %d" % [current_hp, max_hp]


func _update_stats(building_data: Dictionary) -> void:
	if _stats_container == null:
		return
	for child: Node in _stats_container.get_children():
		child.queue_free()

	var armor: int = building_data.get("armor", 0)
	var sight: int = building_data.get("sight", 5)
	var attack: int = building_data.get("attack", 0)
	var range_val: int = building_data.get("range", 0)
	var pop_add: int = building_data.get("pop_add", 0)
	var garrison_cap: int = building_data.get("garrison_capacity", 0)

	var lines: PackedStringArray = []
	lines.append("Armor: %d  Sight: %d" % [armor, sight])
	if attack > 0:
		lines.append("Attack: %d  Range: %d" % [attack, range_val])
	if pop_add > 0:
		lines.append("Population: +%d" % pop_add)
	if garrison_cap > 0:
		lines.append("Garrison: %d slots" % garrison_cap)

	for line: String in lines:
		var lbl: Label = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
		_stats_container.add_child(lbl)


func _update_queue(building_node: Node, is_constructed: bool) -> void:
	var queue: Array = building_node.get("production_queue") if building_node.get("production_queue") != null else []
	var is_producing: bool = building_node.get("is_producing") if building_node.get("is_producing") != null else false
	var total_queue_time: float = building_node.get("production_total_time") if building_node.get("production_total_time") != null else 0.0
	var elapsed: float = building_node.get("production_timer") if building_node.get("production_timer") != null else 0.0

	if queue.is_empty():
		if _queue_label:
			_queue_label.visible = false
		if _queue_container:
			_queue_container.visible = false
		return

	if _queue_label:
		_queue_label.visible = true
		_queue_label.text = "Production Queue (%d):" % queue.size()
	if _queue_container:
		_queue_container.visible = true
		for child: Node in _queue_container.get_children():
			child.queue_free()

	for i in range(queue.size()):
		var item: Variant = queue[i]
		var item_name: String = ""
		if item is String:
			item_name = item
		elif item is Dictionary:
			item_name = item.get("type", "unknown")

		var unit_data: Dictionary = DataManager.get_unit_data(item_name)
		var display_name: String = unit_data.get("display_name", item_name.capitalize())
		var train_time: float = unit_data.get("train_time", 5.0)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_queue_container.add_child(row)

		# Icon slot.
		var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = SLOT_SIZE
		var slot_style: StyleBoxFlat = StyleBoxFlat.new()
		if i == 0 and is_producing:
			slot_style.bg_color = Color(0.12, 0.25, 0.45, 0.9)
			slot_style.border_color = Color(0.3, 0.6, 1.0, 0.8)
		else:
			slot_style.bg_color = Color(0.12, 0.12, 0.18, 0.8)
			slot_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(3)
		slot.add_theme_stylebox_override("panel", slot_style)
		row.add_child(slot)

		var preview: TextureRect = TextureRect.new()
		preview.custom_minimum_size = Vector2(30, 30)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = ProceduralSpriteFactory.get_unit_preview(item_name, GameManager.local_player_id)
		preview.set_anchors_preset(Control.PRESET_CENTER)
		slot.add_child(preview)

		# Individual progress bar under the icon.
		if i == 0 and is_producing and total_queue_time > 0.0:
			var progress: float = clampf(elapsed / total_queue_time, 0.0, 1.0)
			var prog_bar: ProgressBar = ProgressBar.new()
			prog_bar.custom_minimum_size = Vector2(SLOT_SIZE.x, 4)
			prog_bar.max_value = 100
			prog_bar.value = progress * 100.0
			prog_bar.show_percentage = false
			prog_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			prog_bar.offset_top = -4
			var prog_fill: StyleBoxFlat = StyleBoxFlat.new()
			prog_fill.bg_color = Color(0.3, 0.65, 1.0, 0.9)
			prog_fill.set_corner_radius_all(1)
			prog_bar.add_theme_stylebox_override("fill", prog_fill)
			var prog_bg: StyleBoxFlat = StyleBoxFlat.new()
			prog_bg.bg_color = Color(0.08, 0.08, 0.1)
			prog_bg.set_corner_radius_all(1)
			prog_bar.add_theme_stylebox_override("background", prog_bg)
			slot.add_child(prog_bar)

		# Name + time label.
		var info_vbox: VBoxContainer = VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 1)
		row.add_child(info_vbox)

		var name_lbl: Label = Label.new()
		name_lbl.text = display_name
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
		info_vbox.add_child(name_lbl)

		var time_lbl: Label = Label.new()
		if i == 0 and is_producing:
			var remaining: float = maxf(total_queue_time - elapsed, 0.0)
			time_lbl.text = "%.1fs left" % remaining
			time_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		else:
			time_lbl.text = "%.1fs" % train_time
			time_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		time_lbl.add_theme_font_size_override("font_size", 10)
		info_vbox.add_child(time_lbl)


func _update_rally(building_id: int) -> void:
	var rally_sys: Node = get_node_or_null("/root/GameWorld/RallyPointSystem")
	var has_rally: bool = false
	var rally_pos: Vector2 = Vector2.ZERO

	if rally_sys != null and rally_sys.has_method("has_rally_point"):
		has_rally = rally_sys.has_rally_point(building_id)
		if has_rally:
			rally_pos = rally_sys.get_rally_point(building_id)

	if _rally_label:
		_rally_label.visible = has_rally
	if _rally_info:
		_rally_info.visible = has_rally
		if has_rally:
			_rally_info.text = "(%.0f, %.0f)" % [rally_pos.x, rally_pos.y]
	if _rally_clear_btn:
		_rally_clear_btn.visible = has_rally


func _on_rally_clear() -> void:
	if _current_building_id == -1:
		return
	var rally_sys: Node = get_node_or_null("/root/GameWorld/RallyPointSystem")
	if rally_sys != null and rally_sys.has_method("clear_rally_point"):
		rally_sys.clear_rally_point(_current_building_id)
		_update_rally(_current_building_id)


func _update_garrison(building_node: Node, building_data: Dictionary) -> void:
	var garrison_cap: int = building_data.get("garrison_capacity", 0)
	if garrison_cap <= 0:
		if _garrison_label:
			_garrison_label.visible = false
		if _garrison_container:
			_garrison_container.visible = false
		return

	var garrisoned: Array = building_node.get("garrisoned_units") if building_node.get("garrisoned_units") != null else []

	if _garrison_label:
		_garrison_label.visible = true
		_garrison_label.text = "Garrison: %d / %d" % [garrisoned.size(), garrison_cap]
	if _garrison_container:
		_garrison_container.visible = true
		for child: Node in _garrison_container.get_children():
			child.queue_free()

		for uid in garrisoned:
			var unit_node: Node = _find_unit_by_id(uid)
			if unit_node == null:
				continue
			var unit_type: String = unit_node.get("unit_type") if unit_node.get("unit_type") != null else "unknown"
			var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
			var unit_name: String = unit_data.get("display_name", unit_type.capitalize())

			var slot: PanelContainer = PanelContainer.new()
			slot.custom_minimum_size = SLOT_SIZE
			var slot_style: StyleBoxFlat = StyleBoxFlat.new()
			slot_style.bg_color = Color(0.12, 0.18, 0.12, 0.8)
			slot_style.border_color = Color(0.3, 0.5, 0.3, 0.5)
			slot_style.set_border_width_all(1)
			slot_style.set_corner_radius_all(3)
			slot.add_theme_stylebox_override("panel", slot_style)
			_garrison_container.add_child(slot)

			var preview: TextureRect = TextureRect.new()
			preview.custom_minimum_size = Vector2(28, 28)
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.texture = ProceduralSpriteFactory.get_unit_preview(unit_type, GameManager.local_player_id)
			preview.set_anchors_preset(Control.PRESET_CENTER)
			slot.add_child(preview)

	for _i in range(garrisoned.size(), garrison_cap):
		var empty_slot: PanelContainer = PanelContainer.new()
		empty_slot.custom_minimum_size = SLOT_SIZE
		var empty_style: StyleBoxFlat = StyleBoxFlat.new()
		empty_style.bg_color = Color(0.08, 0.08, 0.1, 0.5)
		empty_style.border_color = Color(0.2, 0.2, 0.25, 0.3)
		empty_style.set_border_width_all(1)
		empty_style.set_corner_radius_all(3)
		empty_slot.add_theme_stylebox_override("panel", empty_style)
		_garrison_container.add_child(empty_slot)


func _update_produce(building_data: Dictionary, is_constructed: bool) -> void:
	if _produce_container == null:
		return
	for child: Node in _produce_container.get_children():
		child.queue_free()

	if not is_constructed:
		_produce_container.visible = false
		return

	var produces: Array = building_data.get("produces", [])
	if produces.is_empty():
		_produce_container.visible = false
		return

	_produce_container.visible = true

	for unit_type: String in produces:
		var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
		var unit_name: String = unit_data.get("display_name", unit_type.capitalize())

		var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = SLOT_SIZE
		var slot_style: StyleBoxFlat = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.1, 0.14, 0.2, 0.8)
		slot_style.border_color = Color(0.3, 0.35, 0.15, 0.5)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(3)
		slot.add_theme_stylebox_override("panel", slot_style)
		_produce_container.add_child(slot)

		var preview: TextureRect = TextureRect.new()
		preview.custom_minimum_size = Vector2(28, 28)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = ProceduralSpriteFactory.get_unit_preview(unit_type, GameManager.local_player_id)
		preview.set_anchors_preset(Control.PRESET_CENTER)
		slot.add_child(preview)


func _find_building_by_id(building_id: int) -> Node2D:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm and bm.has_method("get_building"):
		return bm.get_building(building_id)
	return null


func _find_unit_by_id(unit_id: int) -> Node:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if unit.has_method("get") and unit.get("unit_id") != null and unit.get("unit_id") == unit_id:
			return unit
	return null
