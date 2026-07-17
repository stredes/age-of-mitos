extends Control

signal build_menu_requested
signal speed_button_pressed

var resource_bar: HBoxContainer = null
var top_right_panel: HBoxContainer = null
var game_time_label: Label = null
var speed_button: Button = null
var pause_button: Button = null
var population_label: Label = null
var action_panel: VBoxContainer = null
var action_label: Label = null
var minimap_container: Control = null
var notification_label: Label = null
var action_bar: HBoxContainer = null
var construction_bar: ProgressBar = null
var construction_label: Label = null

var _resource_labels: Dictionary = {}
var _resource_panels: Dictionary = {}
var _is_paused: bool = false
var _notification_tween: Tween = null
var _resource_tweens: Dictionary = {}

var _resource_icons: Dictionary = {}
var _resource_icon_textures: Dictionary = {}

var _resource_colors: Dictionary = {
	"wood": Color(0.55, 0.27, 0.07),
	"stone": Color(0.5, 0.5, 0.5),
	"food": Color(0.13, 0.55, 0.13),
	"gold": Color(1.0, 0.84, 0.0),
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud_ui()
	_connect_signals()
	_setup_resource_bar()
	_setup_action_panel()
	_setup_notification()
	update_resources()
	_update_speed_display()
	_update_time_display()


func _build_hud_ui() -> void:
	# Resource bar at top-left.
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 40
	top_bar.offset_left = 10
	top_bar.offset_right = -10
	top_bar.add_theme_constant_override("separation", 20)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	var res_bar: HBoxContainer = HBoxContainer.new()
	res_bar.name = "ResourceBar"
	res_bar.add_theme_constant_override("separation", 16)
	top_bar.add_child(res_bar)
	resource_bar = res_bar

	# Time + speed at top-right.
	var tr_panel: HBoxContainer = HBoxContainer.new()
	tr_panel.name = "TopRightPanel"
	tr_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_panel.offset_left = -300
	tr_panel.offset_bottom = 40
	tr_panel.offset_right = -10
	tr_panel.add_theme_constant_override("separation", 8)
	tr_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr_panel)
	top_right_panel = tr_panel

	var time_lbl: Label = Label.new()
	time_lbl.name = "GameTimeLabel"
	time_lbl.text = "00:00"
	time_lbl.add_theme_font_size_override("font_size", 16)
	tr_panel.add_child(time_lbl)
	game_time_label = time_lbl

	var spd_btn: Button = Button.new()
	spd_btn.name = "SpeedButton"
	spd_btn.text = "Speed: 1.0x"
	spd_btn.custom_minimum_size = Vector2(100, 30)
	spd_btn.pressed.connect(_on_SpeedButton_pressed)
	tr_panel.add_child(spd_btn)
	speed_button = spd_btn

	var pause_btn: Button = Button.new()
	pause_btn.name = "PauseButton"
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(40, 30)
	pause_btn.pressed.connect(_on_PauseButton_pressed)
	tr_panel.add_child(pause_btn)
	pause_button = pause_btn

	# Population label.
	var pop_lbl: Label = Label.new()
	pop_lbl.name = "PopulationLabel"
	pop_lbl.text = "Pop: 0/0"
	pop_lbl.add_theme_font_size_override("font_size", 14)
	tr_panel.add_child(pop_lbl)
	population_label = pop_lbl

	# Action panel at bottom-center for selected units/buildings.
	var action_pnl: VBoxContainer = VBoxContainer.new()
	action_pnl.name = "ActionPanel"
	action_pnl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	action_pnl.offset_top = -120
	action_pnl.offset_left = 200
	action_pnl.offset_right = -200
	action_pnl.offset_bottom = -10
	action_pnl.add_theme_constant_override("separation", 6)
	action_pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_pnl.visible = false
	add_child(action_pnl)
	action_panel = action_pnl

	var act_lbl: Label = Label.new()
	act_lbl.name = "ActionLabel"
	act_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_lbl.add_theme_font_size_override("font_size", 16)
	action_pnl.add_child(act_lbl)
	action_label = act_lbl

	var act_bar: HBoxContainer = HBoxContainer.new()
	act_bar.name = "ActionBar"
	act_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	act_bar.add_theme_constant_override("separation", 6)
	action_pnl.add_child(act_bar)
	action_bar = act_bar
	action_bar.visible = false

	var c_bar: ProgressBar = ProgressBar.new()
	c_bar.name = "ConstructionBar"
	c_bar.custom_minimum_size = Vector2(200, 20)
	c_bar.max_value = 100
	c_bar.visible = false
	action_pnl.add_child(c_bar)
	construction_bar = c_bar

	var c_label: Label = Label.new()
	c_label.name = "ConstructionLabel"
	c_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_label.add_theme_font_size_override("font_size", 12)
	action_pnl.add_child(c_label)
	construction_label = c_label

	# Notification label at top-center.
	var notif: Label = Label.new()
	notif.name = "NotificationLabel"
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.set_anchors_preset(Control.PRESET_TOP_WIDE)
	notif.offset_top = 50
	notif.offset_bottom = 80
	notif.add_theme_font_size_override("font_size", 18)
	notif.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	notif.visible = false
	notif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notif)
	notification_label = notif


func _process(_delta: float) -> void:
	_update_time_display()


func _connect_signals() -> void:
	if not EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.connect(_on_resource_changed)
	if not EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.connect(_on_selection_changed)
	if not EventBus.construction_progress.is_connected(_on_construction_progress):
		EventBus.construction_progress.connect(_on_construction_progress)
	if not EventBus.construction_completed.is_connected(_on_construction_completed):
		EventBus.construction_completed.connect(_on_construction_completed)
	if not EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.connect(_on_game_paused)
	if not EventBus.game_speed_changed.is_connected(_on_game_speed_changed):
		EventBus.game_speed_changed.connect(_on_game_speed_changed)
	if not EventBus.building_selected.is_connected(_on_building_selected):
		EventBus.building_selected.connect(_on_building_selected)
	if not EventBus.unit_selected.is_connected(_on_unit_selected):
		EventBus.unit_selected.connect(_on_unit_selected)
	if not EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.connect(_on_building_placed)
	if not EventBus.building_completed.is_connected(_on_building_completed):
		EventBus.building_completed.connect(_on_building_completed)
	if not EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.connect(_on_unit_died)
	if not EventBus.unit_spawned.is_connected(_on_unit_spawned):
		EventBus.unit_spawned.connect(_on_unit_spawned)
	if not EventBus.tech_completed.is_connected(_on_tech_completed):
		EventBus.tech_completed.connect(_on_tech_completed)


func _setup_resource_bar() -> void:
	if resource_bar == null:
		return
	for child: Node in resource_bar.get_children():
		child.queue_free()
	_resource_labels.clear()
	_resource_panels.clear()

	_generate_resource_icons()

	var resource_types: Array[String] = ["wood", "stone", "food", "gold"]
	for res_type: String in resource_types:
		var panel: PanelContainer = PanelContainer.new()
		panel.name = res_type.capitalize() + "Panel"
		var pill: StyleBoxFlat = StyleBoxFlat.new()
		pill.bg_color = Color(0.08, 0.08, 0.14, 0.7)
		pill.corner_radius_top_left = 10
		pill.corner_radius_top_right = 10
		pill.corner_radius_bottom_left = 10
		pill.corner_radius_bottom_right = 10
		pill.content_margin_left = 8
		pill.content_margin_right = 8
		pill.content_margin_top = 3
		pill.content_margin_bottom = 3
		panel.add_theme_stylebox_override("panel", pill)
		_resource_panels[res_type] = panel

		var container: HBoxContainer = HBoxContainer.new()
		container.name = res_type.capitalize() + "Container"
		container.add_theme_constant_override("separation", 4)

		var icon_tex: TextureRect = TextureRect.new()
		icon_tex.name = "Icon"
		icon_tex.custom_minimum_size = Vector2(16, 16)
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if res_type in _resource_icon_textures:
			icon_tex.texture = _resource_icon_textures[res_type]
		container.add_child(icon_tex)

		var amount_label: Label = Label.new()
		amount_label.name = "Amount"
		amount_label.text = "0"
		amount_label.add_theme_font_size_override("font_size", 16)
		amount_label.add_theme_color_override("font_color", _resource_colors.get(res_type, Color.WHITE))
		container.add_child(amount_label)

		panel.add_child(container)
		resource_bar.add_child(panel)
		_resource_labels[res_type] = amount_label


func _setup_action_panel() -> void:
	if action_panel == null:
		return
	action_panel.visible = false
	if action_bar != null:
		action_bar.visible = false
	if construction_bar != null:
		construction_bar.visible = false


func _setup_notification() -> void:
	if notification_label == null:
		return
	notification_label.visible = false
	notification_label.z_index = 10


func _generate_resource_icons() -> void:
	if not _resource_icon_textures.is_empty():
		return
	_resource_icon_textures["wood"] = _draw_wood_icon()
	_resource_icon_textures["stone"] = _draw_stone_icon()
	_resource_icon_textures["food"] = _draw_food_icon()
	_resource_icon_textures["gold"] = _draw_gold_icon()


func _draw_wood_icon() -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var trunk: Color = Color(0.45, 0.25, 0.08)
	var leaves: Color = Color(0.15, 0.55, 0.12)
	var leaves2: Color = Color(0.2, 0.65, 0.15)
	for y in range(8, 14):
		img.set_pixel(7, y, trunk)
		img.set_pixel(8, y, trunk)
	for y in range(4, 9):
		for x in range(4, 12):
			if y < 5 and (x < 5 or x > 10):
				continue
			if y < 7 and (x < 3 or x > 12):
				continue
			img.set_pixel(x, y, leaves2 if (x + y) % 3 == 0 else leaves)
	return ImageTexture.create_from_image(img)


func _draw_stone_icon() -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var stone: Color = Color(0.55, 0.55, 0.58)
	var stone_light: Color = Color(0.68, 0.68, 0.7)
	var stone_dark: Color = Color(0.4, 0.4, 0.42)
	var points: Array[Vector2i] = [
		Vector2i(4, 10), Vector2i(3, 8), Vector2i(4, 5),
		Vector2i(6, 3), Vector2i(9, 3), Vector2i(11, 5),
		Vector2i(12, 8), Vector2i(11, 10), Vector2i(8, 12),
		Vector2i(5, 11),
	]
	for y in range(16):
		for x in range(16):
			if _point_in_polygon(Vector2i(x, y), points):
				img.set_pixel(x, y, stone)
	for y in range(5, 8):
		for x in range(5, 10):
			if _point_in_polygon(Vector2i(x, y), points):
				img.set_pixel(x, y, stone_light)
	for y in range(9, 12):
		for x in range(4, 12):
			if _point_in_polygon(Vector2i(x, y), points):
				img.set_pixel(x, y, stone_dark)
	return ImageTexture.create_from_image(img)


func _draw_food_icon() -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var meat: Color = Color(0.75, 0.25, 0.1)
	var meat_light: Color = Color(0.88, 0.35, 0.15)
	var bone: Color = Color(0.92, 0.88, 0.78)
	for y in range(6, 13):
		for x in range(3, 11):
			var dx: float = x - 7.0
			var dy: float = y - 9.0
			if dx * dx / 16.0 + dy * dy / 9.0 <= 1.0:
				img.set_pixel(x, y, meat_light if y < 9 else meat)
	img.set_pixel(11, 7, bone)
	img.set_pixel(12, 7, bone)
	img.set_pixel(12, 8, bone)
	img.set_pixel(13, 8, bone)
	img.set_pixel(13, 9, bone)
	img.set_pixel(12, 9, bone)
	img.set_pixel(12, 10, bone)
	img.set_pixel(11, 10, bone)
	img.set_pixel(2, 8, bone)
	img.set_pixel(1, 8, bone)
	img.set_pixel(1, 9, bone)
	img.set_pixel(2, 9, bone)
	return ImageTexture.create_from_image(img)


func _draw_gold_icon() -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var gold: Color = Color(1.0, 0.82, 0.0)
	var gold_dark: Color = Color(0.85, 0.65, 0.0)
	var gold_light: Color = Color(1.0, 0.92, 0.3)
	for y in range(16):
		for x in range(16):
			var dx: float = x - 7.5
			var dy: float = y - 7.5
			if dx * dx + dy * dy <= 49.0:
				img.set_pixel(x, y, gold)
	for y in range(16):
		for x in range(16):
			var dx: float = x - 7.5
			var dy: float = y - 7.5
			if dx * dx + dy * dy <= 25.0 and dx * dx + dy * dy > 16.0:
				img.set_pixel(x, y, gold_dark)
			elif dx * dx + dy * dy <= 16.0:
				img.set_pixel(x, y, gold_light)
	for y in range(5, 10):
		img.set_pixel(7, y, gold_dark)
		img.set_pixel(8, y, gold_dark)
	for x in range(5, 10):
		img.set_pixel(x, 7, gold_dark)
		img.set_pixel(x, 8, gold_dark)
	return ImageTexture.create_from_image(img)


func _point_in_polygon(point: Vector2i, polygon: Array[Vector2i]) -> bool:
	var inside: bool = false
	var n: int = polygon.size()
	var j: int = n - 1
	for i in range(n):
		var pi: Vector2i = polygon[i]
		var pj: Vector2i = polygon[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
			(point.x < (pj.x - pi.x) * (point.y - pi.y) / float(pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside


func update_resources() -> void:
	var resources: Dictionary = GameManager.get_resources()
	for res_type: String in _resource_labels:
		var label: Label = _resource_labels[res_type]
		var amount: int = resources.get(res_type, 0)
		var new_text: String = str(amount)
		if label.text != new_text and label.text != "0":
			_flash_resource(res_type)
		label.text = new_text


func _flash_resource(res_type: String) -> void:
	if res_type not in _resource_panels:
		return
	var panel: PanelContainer = _resource_panels[res_type]
	if panel == null:
		return
	if res_type in _resource_tweens and _resource_tweens[res_type] != null and _resource_tweens[res_type].is_valid():
		_resource_tweens[res_type].kill()
	var original_color: Color = Color(0.08, 0.08, 0.14, 0.7)
	var flash_color: Color = original_color + Color(0.15, 0.15, 0.10, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate", Color(1.25, 1.25, 1.1, 1.0), 0.08)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.25)
	_resource_tweens[res_type] = tween


func update_selection_info(selected_units: Array, selected_building_id: int) -> void:
	if action_panel == null:
		return

	action_panel.visible = true
	_clear_action_buttons()

	if selected_units.size() == 0 and selected_building_id == -1:
		action_panel.visible = false
		return

	if selected_units.size() == 1 and selected_building_id == -1:
		_show_single_unit(selected_units[0])
	elif selected_units.size() > 1:
		_show_multi_units(selected_units)
	elif selected_building_id != -1:
		_show_building(selected_building_id)


func _show_single_unit(unit_id: int) -> void:
	var unit_node: Node = _find_unit_by_id(unit_id)
	if unit_node == null:
		if action_label:
			action_label.text = "Unit #" + str(unit_id)
		return

	var unit_type: String = unit_node.get("unit_type") if unit_node.get("unit_type") != null else "unknown"
	var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
	var display_name: String = unit_data.get("display_name", unit_type.capitalize())

	if action_label:
		action_label.text = display_name

	_add_unit_hp_bar(unit_node)

	if action_bar != null:
		action_bar.visible = true
		var unit_states: Array = unit_data.get("states", [])

		if unit_type == "villager":
			_add_action_button("🪵 Gather Wood", func() -> void: _emit_gather_command(unit_id, "wood"))
			_add_action_button("🍖 Gather Food", func() -> void: _emit_gather_command(unit_id, "food"))
			_add_action_button("🪨 Mine Stone", func() -> void: _emit_gather_command(unit_id, "stone"))
			_add_action_button("🪙 Mine Gold", func() -> void: _emit_gather_command(unit_id, "gold"))
			_add_action_button("🔨 Build", func() -> void: build_menu_requested.emit())
		else:
			if "attack" in unit_states:
				_add_action_button("⚔️ Attack", func() -> void: EventBus.button_pressed.emit("attack_command", GameManager.local_player_id))
			if "move" in unit_states:
				_add_action_button("👟 Move", func() -> void: EventBus.button_pressed.emit("move_command", GameManager.local_player_id))
			_add_action_button("🛑 Stop", func() -> void: EventBus.button_pressed.emit("stop_command", GameManager.local_player_id))


func _show_multi_units(unit_ids: Array) -> void:
	if action_label:
		action_label.text = str(unit_ids.size()) + " Units Selected"

	if action_bar != null:
		action_bar.visible = true
		_add_action_button("⚔️ Attack", func() -> void: EventBus.button_pressed.emit("attack_command", GameManager.local_player_id))
		_add_action_button("👟 Move", func() -> void: EventBus.button_pressed.emit("move_command", GameManager.local_player_id))
		_add_action_button("🛑 Stop", func() -> void: EventBus.button_pressed.emit("stop_command", GameManager.local_player_id))


func _show_building(building_id: int) -> void:
	var building_node: Node = _find_building_by_id(building_id)
	if building_node == null:
		if action_label:
			action_label.text = "Building #" + str(building_id)
		return

	var building_type: String = building_node.get("building_type") if building_node.get("building_type") != null else "unknown"
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	var display_name: String = building_data.get("display_name", building_type.capitalize())
	var is_constructed: bool = building_node.get("is_constructed") if building_node.get("is_constructed") != null else true

	if action_label:
		if is_constructed:
			action_label.text = display_name
		else:
			action_label.text = display_name + " (Building...)"

	_add_building_hp_bar(building_node)

	var produces: Array = building_data.get("produces", [])
	if produces.size() > 0 and is_constructed and action_bar != null:
		action_bar.visible = true
		for unit_type: String in produces:
			var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
			var unit_name: String = unit_data.get("display_name", unit_type.capitalize())
			var cost_text: String = _format_cost(unit_data.get("cost", {}))
			_add_action_button("Train " + unit_name + " " + cost_text, func() -> void: _emit_train_command(building_id, unit_type))


func _add_unit_hp_bar(unit_node: Node) -> void:
	if action_panel == null:
		return
	var health_comp: Node = unit_node.get_node_or_null("HealthComponent")
	if health_comp == null:
		return
	var current_hp: int = health_comp.get("current_hp") if health_comp.get("current_hp") != null else 0
	var max_hp: int = health_comp.get("max_hp") if health_comp.get("max_hp") != null else 1

	var bar_container: HBoxContainer = HBoxContainer.new()
	bar_container.name = "HPBar"

	var hp_bar: ProgressBar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(150, 16)
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_bar.show_percentage = false

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	hp_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = _get_hp_color(current_hp, max_hp)
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	hp_bar.add_theme_stylebox_override("fill", bar_fill)

	bar_container.add_child(hp_bar)

	var hp_label: Label = Label.new()
	hp_label.text = str(current_hp) + "/" + str(max_hp)
	hp_label.add_theme_font_size_override("font_size", 12)
	bar_container.add_child(hp_label)

	action_panel.add_child(bar_container)


func _add_building_hp_bar(building_node: Node) -> void:
	if action_panel == null:
		return
	var current_hp: int = building_node.get("current_hp") if building_node.get("current_hp") != null else 0
	var max_hp: int = building_node.get("max_hp") if building_node.get("max_hp") != null else 1

	var bar_container: HBoxContainer = HBoxContainer.new()
	bar_container.name = "HPBar"

	var hp_bar: ProgressBar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(150, 16)
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_bar.show_percentage = false

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	hp_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = _get_hp_color(current_hp, max_hp)
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	hp_bar.add_theme_stylebox_override("fill", bar_fill)

	bar_container.add_child(hp_bar)

	var hp_label: Label = Label.new()
	hp_label.text = str(current_hp) + "/" + str(max_hp)
	hp_label.add_theme_font_size_override("font_size", 12)
	bar_container.add_child(hp_label)

	action_panel.add_child(bar_container)


func _add_action_button(label_text: String, callback: Callable) -> void:
	if action_bar == null:
		return
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(64, 48)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.pressed.connect(callback)
	action_bar.add_child(btn)


func _clear_action_buttons() -> void:
	if action_bar == null:
		return
	for child: Node in action_bar.get_children():
		child.queue_free()
	action_bar.visible = false

	if action_panel != null:
		for child: Node in action_panel.get_children():
			if child.name != "ActionLabel" and child.name != "ActionBar" and child.name != "ConstructionBar" and child.name != "ConstructionLabel":
				child.queue_free()


func update_construction_bar(building_id: int, progress: float) -> void:
	if construction_bar != null:
		construction_bar.visible = true
		construction_bar.value = progress * 100.0
	if construction_label != null:
		construction_label.text = "Building... %d%%" % int(progress * 100.0)


func show_notification(text: String, duration: float = 3.0) -> void:
	if notification_label == null:
		return
	notification_label.text = text
	notification_label.visible = true
	notification_label.modulate.a = 1.0

	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()

	_notification_tween = create_tween()
	_notification_tween.tween_interval(duration * 0.7)
	_notification_tween.tween_property(notification_label, "modulate:a", 0.0, duration * 0.3)
	_notification_tween.tween_callback(func() -> void: notification_label.visible = false)


func _update_time_display() -> void:
	if game_time_label:
		game_time_label.text = GameManager.get_game_time_formatted()


func _update_speed_display() -> void:
	if speed_button:
		var speed: float = GameManager.get_speed()
		speed_button.text = "Speed: %.1fx" % speed


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


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = _resource_icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return " (" + " ".join(parts) + ")"


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


func _emit_gather_command(unit_id: int, resource_type: String) -> void:
	EventBus.villager_assigned.emit(unit_id, -1, "gather_" + resource_type)
	EventBus.button_pressed.emit("gather_" + resource_type, GameManager.local_player_id)


func _emit_train_command(building_id: int, unit_type: String) -> void:
	EventBus.button_pressed.emit("train_" + unit_type, GameManager.local_player_id)


func _on_resource_changed(resource_type: String, _amount: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		update_resources()


func _on_selection_changed(selected_unit_ids: Array, selected_building_ids: Array) -> void:
	var building_id: int = selected_building_ids[0] if selected_building_ids.size() > 0 else -1
	update_selection_info(selected_unit_ids, building_id)


func _on_construction_progress(building_id: int, current_hp: int, total_hp: int) -> void:
	if total_hp > 0:
		var progress: float = float(current_hp) / float(total_hp)
		update_construction_bar(building_id, progress)


func _on_construction_completed(_building_id: int, _player_id: int) -> void:
	if construction_bar != null:
		construction_bar.visible = false
	if construction_label != null:
		construction_label.text = ""


func _on_game_paused(is_paused: bool) -> void:
	_is_paused = is_paused
	if pause_button:
		pause_button.text = "▶" if is_paused else "⏸"


func _on_game_speed_changed(_speed: float) -> void:
	_update_speed_display()


func _on_building_selected(building_id: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		update_selection_info([], building_id)


func _on_unit_selected(_unit_id: int, _player_id: int) -> void:
	pass


func _on_building_placed(_building_id: int, building_type: String, player_id: int, _position: Vector2) -> void:
	if player_id == GameManager.local_player_id:
		var data: Dictionary = DataManager.get_building_data(building_type)
		var building_name: String = data.get("display_name", building_type)
		show_notification(building_name + " placed!")


func _on_building_completed(_building_id: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		show_notification("Construction complete!")


func _on_unit_died(unit_id: int, _killer_id: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		show_notification("A unit was lost!")


func _on_unit_spawned(_unit_id: int, _unit_type: String, player_id: int, _position: Vector2) -> void:
	pass


func _on_tech_completed(tech_id: String, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
		var tech_name: String = tech_id.capitalize()
		if not tech_data.is_empty():
			tech_name = tech_data.get("display_name", tech_name)
		show_notification("Research complete: " + tech_name)


func _on_SpeedButton_pressed() -> void:
	GameManager.cycle_speed()
	speed_button_pressed.emit()


func _on_PauseButton_pressed() -> void:
	if _is_paused:
		GameManager.resume_game()
	else:
		GameManager.pause_game()
