extends Node

var hud: Control = null
var minimap: Control = null
var build_menu: Control = null
var train_menu: Control = null
var selection_panel: Control = null
var command_card: Control = null
var tooltip_system: PanelContainer = null
var notification_system: Node = null
var building_panel: Control = null
var victory_screen: Control = null
var tech_tree_panel: Control = null
var diplomacy_panel: Control = null
var _pause_menu: Control = null
var _open_menu: String = ""


func _ready() -> void:
	call_deferred("_find_ui_nodes")
	_connect_signals()


func _find_ui_nodes() -> void:
	hud = _find_node_recursive("/root/GameWorld/UILayer", "HUD") as Control
	minimap = _find_node_recursive("/root/GameWorld/UILayer", "Minimap") as Control
	build_menu = _find_node_recursive("/root/GameWorld/UILayer", "BuildMenu") as Control
	train_menu = _find_node_recursive("/root/GameWorld/UILayer", "TrainMenu") as Control
	selection_panel = _find_node_recursive("/root/GameWorld/UILayer", "SelectionPanel") as Control
	command_card = _find_node_recursive("/root/GameWorld/UILayer", "CommandCard") as Control
	tooltip_system = _find_node_recursive("/root/GameWorld/UILayer", "TooltipSystem") as PanelContainer
	notification_system = _find_node_recursive("/root/GameWorld", "NotificationSystem")
	building_panel = _find_node_recursive("/root/GameWorld/UILayer", "BuildingPanel") as Control
	victory_screen = _find_node_recursive("/root/GameWorld/UILayer", "VictoryScreen") as Control
	tech_tree_panel = _find_node_recursive("/root/GameWorld/UILayer", "TechTreePanel") as Control
	diplomacy_panel = _find_node_recursive("/root/GameWorld/UILayer", "DiplomacyPanel") as Control

	if hud and hud.has_signal("build_menu_requested"):
		if not hud.build_menu_requested.is_connected(open_build_menu):
			hud.build_menu_requested.connect(open_build_menu)

	if command_card and command_card.has_signal("command_issued"):
		if not command_card.command_issued.is_connected(_on_command_issued):
			command_card.command_issued.connect(_on_command_issued)

	if tooltip_system and tooltip_system.has_method("add_to_group"):
		tooltip_system.add_to_group("_tooltip_system")


func _find_node_recursive(root_path: String, target_name: String) -> Node:
	var root: Node = get_node_or_null(root_path)
	if root == null:
		return null
	return _search_children(root, target_name)


func _search_children(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _search_children(child, target_name)
		if result != null:
			return result
	return null


func _connect_signals() -> void:
	if not EventBus.menu_opened.is_connected(_on_menu_opened):
		EventBus.menu_opened.connect(_on_menu_opened)
	if not EventBus.menu_closed.is_connected(_on_menu_closed):
		EventBus.menu_closed.connect(_on_menu_closed)
	if not EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.connect(_on_game_paused)
	if not EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.connect(_on_selection_changed)
	if not EventBus.building_selected.is_connected(_on_building_selected):
		EventBus.building_selected.connect(_on_building_selected)
	if not EventBus.unit_selected.is_connected(_on_unit_selected):
		EventBus.unit_selected.connect(_on_unit_selected)
	if not EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.connect(_on_building_placed)
	if not EventBus.building_completed.is_connected(_on_building_completed):
		EventBus.building_completed.connect(_on_building_completed)
	if not EventBus.construction_progress.is_connected(_on_construction_progress):
		EventBus.construction_progress.connect(_on_construction_progress)


func open_build_menu() -> void:
	if build_menu == null:
		return
	_close_all_menus()
	build_menu.open()
	_open_menu = "build_menu"


func close_build_menu() -> void:
	if build_menu and build_menu.has_method("close"):
		build_menu.close()
	_open_menu = ""


func open_train_menu(building_id: int) -> void:
	if train_menu == null:
		return
	_close_all_menus()
	train_menu.open_for_building(building_id)
	_open_menu = "train_menu"


func close_train_menu() -> void:
	if train_menu and train_menu.has_method("close"):
		train_menu.close()
	_open_menu = ""


func show_game_over(winner_id: int) -> void:
	if _game_over_panel and is_instance_valid(_game_over_panel):
		_game_over_panel.queue_free()

	_game_over_panel = Control.new()
	_game_over_panel.name = "GameOverPanel"
	_game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title: Label = Label.new()
	if winner_id == GameManager.local_player_id:
		title.text = "VICTORY!"
		title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	elif winner_id == -1:
		title.text = "DRAW"
		title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
	else:
		title.text = "DEFEAT"
		title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Game Over"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_container)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(120, 48)
	menu_btn.pressed.connect(func() -> void: GameManager.return_to_menu())
	btn_container.add_child(menu_btn)

	get_tree().current_scene.add_child(_game_over_panel)


func hide_pause_menu() -> void:
	if _pause_menu and is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
		_pause_menu = null


func show_pause_menu() -> void:
	hide_pause_menu()

	_pause_menu = Control.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title: Label = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn: Button = Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(120, 48)
	resume_btn.pressed.connect(func() -> void:
		GameManager.resume_game()
		hide_pause_menu()
	)
	vbox.add_child(resume_btn)

	var speed_label: Label = Label.new()
	speed_label.text = "Speed: %.1fx" % GameManager.get_speed()
	speed_label.add_theme_font_size_override("font_size", 14)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(speed_label)

	var speed_hbox: HBoxContainer = HBoxContainer.new()
	speed_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(speed_hbox)

	for speed_val: float in GameManager.SPEED_OPTIONS:
		var spd_btn: Button = Button.new()
		spd_btn.text = "%.1fx" % speed_val
		spd_btn.custom_minimum_size = Vector2(56, 40)
		if is_equal_approx(speed_val, GameManager.get_speed()):
			var selected_style: StyleBoxFlat = StyleBoxFlat.new()
			selected_style.bg_color = Color(0.2, 0.4, 0.7, 1.0)
			selected_style.corner_radius_top_left = 4
			selected_style.corner_radius_top_right = 4
			selected_style.corner_radius_bottom_left = 4
			selected_style.corner_radius_bottom_right = 4
			spd_btn.add_theme_stylebox_override("normal", selected_style)
		var sv: float = speed_val
		spd_btn.pressed.connect(func() -> void:
			GameManager.set_speed(sv)
			hide_pause_menu()
			show_pause_menu()
		)
		speed_hbox.add_child(spd_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(120, 48)
	menu_btn.pressed.connect(func() -> void:
		GameManager.return_to_menu()
		hide_pause_menu()
	)
	vbox.add_child(menu_btn)

	get_tree().current_scene.add_child(_pause_menu)


func update_all() -> void:
	if hud and hud.has_method("update_resources"):
		hud.update_resources()
	if minimap and minimap.has_method("update_minimap"):
		minimap.update_minimap()


func _close_all_menus() -> void:
	if build_menu and build_menu.has_method("is_open") and build_menu.is_open():
		build_menu.close()
	if train_menu and train_menu.visible:
		train_menu.close()
	_open_menu = ""


func _on_menu_opened(menu_name: String) -> void:
	if menu_name == "build_mode":
		return
	_open_menu = menu_name


func _on_menu_closed(menu_name: String) -> void:
	if _open_menu == menu_name:
		_open_menu = ""


func _on_game_paused(is_paused: bool) -> void:
	if is_paused:
		show_pause_menu()
	else:
		hide_pause_menu()


func _on_selection_changed(selected_unit_ids: Array, selected_building_ids: Array) -> void:
	if selection_panel == null and command_card == null:
		return

	if selected_unit_ids.size() == 0 and selected_building_ids.size() == 0:
		if selection_panel:
			selection_panel.clear()
		if command_card:
			command_card.show_selection([], -1)
		if building_panel and building_panel.has_method("hide_building"):
			building_panel.hide_building()
		_close_all_menus()
		return

	# Switching from building to unit selection — close building-related menus.
	if selected_unit_ids.size() > 0 and selected_building_ids.size() == 0:
		if train_menu and train_menu.visible:
			close_train_menu()
		if building_panel and building_panel.has_method("hide_building"):
			building_panel.hide_building()

	if selection_panel:
		if selected_unit_ids.size() > 0:
			var unit_nodes: Array = []
			for uid: Variant in selected_unit_ids:
				var node: Node = _find_unit_by_id(uid)
				if node != null:
					unit_nodes.append(node)

			if unit_nodes.size() == 1:
				var unit_node: Node = unit_nodes[0]
				var unit_type: String = unit_node.get("unit_type") if unit_node.has_method("get") and unit_node.get("unit_type") != null else ""
				var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
				selection_panel.show_unit(unit_data, unit_node)
			elif unit_nodes.size() > 1:
				selection_panel.show_units(unit_nodes)
		elif selected_building_ids.size() > 0:
			var building_id: int = selected_building_ids[0]
			var building_node: Node2D = _find_building_by_id(building_id)
			if building_node != null:
				var building_type: String = building_node.get("building_type") if building_node.has_method("get") and building_node.get("building_type") != null else ""
				var building_data: Dictionary = DataManager.get_building_data(building_type)
				selection_panel.show_building(building_data, building_node)

	if command_card:
		var building_id: int = selected_building_ids[0] if selected_building_ids.size() > 0 else -1
		command_card.show_selection(selected_unit_ids, building_id)


func _on_building_selected(building_id: int, player_id: int) -> void:
	if player_id != GameManager.local_player_id:
		return

	var building_node: Node2D = _find_building_by_id(building_id)
	if building_node == null:
		return

	var building_type: String = building_node.get("building_type") if building_node.has_method("get") and building_node.get("building_type") != null else ""
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	var produces: Array = building_data.get("produces", [])
	var is_constructed: bool = building_node.get("is_constructed") if building_node.has_method("get") and building_node.get("is_constructed") != null else true

	if produces.size() > 0 and is_constructed:
		if selection_panel and selection_panel.has_method("show_building"):
			selection_panel.show_building(building_data, building_node)

	if building_panel and building_panel.has_method("show_building"):
		building_panel.show_building(building_id)

	if command_card:
		command_card.show_selection([], building_id)


func _on_unit_selected(_unit_id: int, _player_id: int) -> void:
	pass


func _on_building_placed(_building_id: int, _building_type: String, _player_id: int, _position: Vector2) -> void:
	if hud and hud.has_method("show_notification"):
		pass


func _on_building_completed(_building_id: int, _player_id: int) -> void:
	pass


func _on_construction_progress(_building_id: int, _current_hp: int, _total_hp: int) -> void:
	if _total_hp > 0 and hud and hud.has_method("update_construction_bar"):
		var progress: float = float(_current_hp) / float(_total_hp)
		hud.update_construction_bar(_building_id, progress)


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


func _on_command_issued(command: String, params: Dictionary) -> void:
	var player_id: int = GameManager.local_player_id

	if command.begins_with("train_"):
		var unit_type: String = command.substr(6)
		var building_id: int = params.get("building_id", -1)
		if building_id != -1:
			EventBus.button_pressed.emit("train_" + unit_type, player_id)
		return

	if command.begins_with("research_"):
		var tech_id: String = command.substr(9)
		EventBus.button_pressed.emit("research_" + tech_id, player_id)
		return

	match command:
		"attack":
			EventBus.button_pressed.emit("attack_command", player_id)
		"move":
			EventBus.button_pressed.emit("move_command", player_id)
		"stop":
			EventBus.button_pressed.emit("stop_command", player_id)
		"guard":
			EventBus.button_pressed.emit("guard_command", player_id)
		"build":
			if hud and hud.has_signal("build_menu_requested"):
				hud.build_menu_requested.emit()
		"gather_wood", "gather_food", "gather_stone", "gather_gold":
			var unit_id: int = params.get("unit_id", -1)
			if unit_id != -1:
				EventBus.villager_assigned.emit(unit_id, -1, command)
			EventBus.button_pressed.emit(command, player_id)
		"garrison":
			EventBus.button_pressed.emit("garrison_command", player_id)
		"repair":
			EventBus.button_pressed.emit("repair_command", player_id)
		"cancel_construction":
			EventBus.button_pressed.emit("cancel_construction", player_id)


func notify_success(text: String) -> void:
	if notification_system and notification_system.has_method("show_success"):
		notification_system.show_success(text)


func notify_error(text: String) -> void:
	if notification_system and notification_system.has_method("show_error"):
		notification_system.show_error(text)


func notify_warning(text: String) -> void:
	if notification_system and notification_system.has_method("show_warning"):
		notification_system.show_warning(text)


func notify_info(text: String) -> void:
	if notification_system and notification_system.has_method("show_info"):
		notification_system.show_info(text)
