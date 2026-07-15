extends Control

var _is_open: bool = false
var _current_building_id: int = -1
var _current_building_type: String = ""

var _main_vbox: VBoxContainer = null
var _units_container: VBoxContainer = null
var _queue_container: HBoxContainer = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null
var _title_label: Label = null
var _close_button: Button = null
var _queue_separator: HSeparator = null
var _queue_label: Label = null

var _resource_icons: Dictionary = {
	"wood": "🪵",
	"stone": "🪨",
	"food": "🍖",
	"gold": "🪙",
}


func _ready() -> void:
	_build_ui()
	visible = false
	if not EventBus.construction_progress.is_connected(_on_construction_progress):
		EventBus.construction_progress.connect(_on_construction_progress)
	if not EventBus.construction_completed.is_connected(_on_construction_completed):
		EventBus.construction_completed.connect(_on_construction_completed)


func _process(_delta: float) -> void:
	if _is_open and _current_building_id != -1:
		_update_progress_display()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.08, 0.12, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_vbox.offset_left = 16
	_main_vbox.offset_right = -16
	_main_vbox.offset_top = 16
	_main_vbox.offset_bottom = -16
	_main_vbox.add_theme_constant_override("separation", 8)
	add_child(_main_vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	_main_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Train Units"
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
	progress_fill.bg_color = Color(0.2, 0.6, 0.9, 1.0)
	progress_fill.corner_radius_top_left = 4
	progress_fill.corner_radius_top_right = 4
	progress_fill.corner_radius_bottom_left = 4
	progress_fill.corner_radius_bottom_right = 4
	_progress_bar.add_theme_stylebox_override("fill", progress_fill)

	_main_vbox.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.text = ""
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.visible = false
	_main_vbox.add_child(_progress_label)

	_queue_label = Label.new()
	_queue_label.name = "QueueLabel"
	_queue_label.text = "Queue:"
	_queue_label.add_theme_font_size_override("font_size", 14)
	_queue_label.visible = false
	_main_vbox.add_child(_queue_label)

	_queue_container = HBoxContainer.new()
	_queue_container.name = "QueueContainer"
	_queue_container.add_theme_constant_override("separation", 4)
	_queue_container.visible = false
	_main_vbox.add_child(_queue_container)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "UnitScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_vbox.add_child(scroll)

	_units_container = VBoxContainer.new()
	_units_container.name = "UnitsContainer"
	_units_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_units_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_units_container)


func open_for_building(building_id: int) -> void:
	_current_building_id = building_id
	_is_open = true
	visible = true

	var building_node: Node = _find_building_by_id(building_id)
	if building_node != null:
		_current_building_type = building_node.get("building_type") if building_node.get("building_type") != null else ""
	else:
		_current_building_type = ""

	refresh_unit_options(_current_building_type)
	_update_queue_display()
	EventBus.menu_opened.emit("train_menu")


func close() -> void:
	_is_open = false
	_current_building_id = -1
	_current_building_type = ""
	visible = false
	EventBus.menu_closed.emit("train_menu")


func refresh_unit_options(building_type: String) -> void:
	if _units_container == null:
		return

	for child: Node in _units_container.get_children():
		child.queue_free()

	var building_data: Dictionary = DataManager.get_building_data(building_type)
	var produces: Array = building_data.get("produces", [])

	if _title_label:
		_title_label.text = building_data.get("display_name", building_type.capitalize()) + " - Train"

	if produces.is_empty():
		var no_units: Label = Label.new()
		no_units.text = "No units available"
		no_units.add_theme_font_size_override("font_size", 14)
		no_units.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_units_container.add_child(no_units)
		return

	for unit_type: String in produces:
		_create_unit_button(unit_type)


func _create_unit_button(unit_type: String) -> void:
	var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
	if unit_data.is_empty():
		return

	var display_name: String = unit_data.get("display_name", unit_type.capitalize())
	var cost: Dictionary = unit_data.get("cost", {})
	var train_time: float = unit_data.get("train_time", 10.0)
	var hp: int = unit_data.get("hp", 0)
	var attack: int = unit_data.get("attack", 0)
	var can_afford: bool = GameManager.can_afford(cost, GameManager.local_player_id)

	var btn: Button = Button.new()
	btn.name = "Train_" + unit_type
	btn.custom_minimum_size = Vector2(0, 64)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4

	if can_afford:
		btn_style.bg_color = Color(0.12, 0.2, 0.12, 0.9)
		btn_style.border_color = Color(0.3, 0.5, 0.3, 0.7)
	else:
		btn_style.bg_color = Color(0.2, 0.15, 0.12, 0.9)
		btn_style.border_color = Color(0.4, 0.25, 0.2, 0.6)

	btn_style.border_width_bottom = 1
	btn_style.border_width_top = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn.add_theme_stylebox_override("normal", btn_style)

	_units_container.add_child(btn)

	var inner_hbox: HBoxContainer = HBoxContainer.new()
	inner_hbox.name = "Inner"
	inner_hbox.add_theme_constant_override("separation", 12)
	btn.add_child(inner_hbox)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.name = "Left"
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 2)
	inner_hbox.add_child(left_vbox)

	var name_label: Label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 15)
	if not can_afford:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left_vbox.add_child(name_label)

	var stats_label: Label = Label.new()
	stats_label.text = "HP: %d  ATK: %d" % [hp, attack]
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	left_vbox.add_child(stats_label)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.name = "Right"
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 2)
	inner_hbox.add_child(right_vbox)

	var cost_label: Label = Label.new()
	cost_label.text = _format_cost_short(cost)
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not can_afford:
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		cost_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	right_vbox.add_child(cost_label)

	var time_label: Label = Label.new()
	time_label.text = "%.0fs" % train_time
	time_label.add_theme_font_size_override("font_size", 11)
	time_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_vbox.add_child(time_label)

	if can_afford:
		btn.pressed.connect(func() -> void: on_train_button_pressed(unit_type))


func on_train_button_pressed(unit_type: String) -> void:
	var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
	var cost: Dictionary = unit_data.get("cost", {})

	if not GameManager.can_afford(cost, GameManager.local_player_id):
		EventBus.button_pressed.emit("cant_afford", GameManager.local_player_id)
		return

	EventBus.button_pressed.emit("train_" + unit_type, GameManager.local_player_id)
	_update_queue_display()
	refresh_unit_options(_current_building_type)


func _update_queue_display() -> void:
	var building_node: Node = _find_building_by_id(_current_building_id)
	if building_node == null:
		_hide_queue()
		return

	var queue: Array = building_node.get("production_queue") if building_node.get("production_queue") != null else []
	var is_producing: bool = building_node.get("is_producing") if building_node.get("is_producing") != null else false

	if queue.is_empty():
		_hide_queue()
		return

	_queue_label.visible = true
	_queue_container.visible = true

	for child: Node in _queue_container.get_children():
		child.queue_free()

	for i in range(queue.size()):
		var item_type: Variant = queue[i]
		var item_name: String = ""
		if item_type is String:
			item_name = item_type
		elif item_type is Dictionary:
			item_name = item_type.get("type", "unknown")

		var unit_data: Dictionary = DataManager.get_unit_data(item_name)
		var display_name: String = unit_data.get("display_name", item_name.capitalize())

		var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = Vector2(48, 48)

		var slot_style: StyleBoxFlat = StyleBoxFlat.new()
		if i == 0 and is_producing:
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

	if _progress_bar and is_producing:
		_progress_bar.visible = true
		_progress_label.visible = true
		var progress: float = _get_production_progress(building_node)
		_progress_bar.value = progress * 100.0
		_progress_label.text = "Producing: %d%%" % int(progress * 100.0)
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


func _get_production_progress(building_node: Node) -> float:
	if building_node.has_method("get_production_progress"):
		return building_node.get_production_progress()
	return 0.0


func update_progress(building_id: int, progress: float) -> void:
	if building_id == _current_building_id:
		if _progress_bar:
			_progress_bar.visible = true
			_progress_bar.value = progress * 100.0
		if _progress_label:
			_progress_label.visible = true
			_progress_label.text = "Producing: %d%%" % int(progress * 100.0)


func _update_progress_display() -> void:
	var building_node: Node = _find_building_by_id(_current_building_id)
	if building_node == null:
		return
	if building_node.has_method("get_production_progress"):
		var progress: float = building_node.get_production_progress()
		if progress > 0.0:
			_progress_bar.visible = true
			_progress_bar.value = progress * 100.0
			_progress_label.visible = true
			_progress_label.text = "Producing: %d%%" % int(progress * 100.0)
	_update_queue_display()


func _find_building_by_id(building_id: int) -> Node2D:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm and bm.has_method("get_building"):
		return bm.get_building(building_id)
	return null


func _format_cost_short(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Free"
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = _resource_icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return " ".join(parts)


func _on_construction_progress(_building_id: int, _current_hp: int, _total_hp: int) -> void:
	pass


func _on_construction_completed(_building_id: int, _player_id: int) -> void:
	pass
