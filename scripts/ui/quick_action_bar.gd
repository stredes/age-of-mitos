## Quick action bar with buttons for idle villager, Town Center, and army.
##
## Positioned at bottom-left. Shows badge counts. Polls periodically.
extends HBoxContainer

var _idle_btn: Button = null
var _tc_btn: Button = null
var _army_btn: Button = null

var _idle_count_label: Label = null
var _tc_count_label: Label = null
var _army_count_label: Label = null

var _icon_factory: Node = null
var _poll_timer: float = 0.0
var _poll_interval: float = 1.0

var _idle_count: int = 0
var _tc_count: int = 0
var _army_count: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_ui()
	call_deferred("_find_icon_factory")


func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= _poll_interval:
		_poll_timer = 0.0
		_poll_counts()
		_update_badges()


func _build_ui() -> void:
	_idle_btn = _create_button("Idle Villager", "_on_idle_pressed")
	_tc_btn = _create_button("Town Center", "_on_tc_pressed")
	_army_btn = _create_button("Army", "_on_army_pressed")

	_idle_count_label = _add_badge(_idle_btn)
	_tc_count_label = _add_badge(_tc_btn)
	_army_count_label = _add_badge(_army_btn)


func _create_button(label_text: String, callback_name: String) -> Button:
	var btn: Button = Button.new()
	btn.name = label_text.replace(" ", "")
	btn.text = label_text
	btn.custom_minimum_size = Vector2(80, 36)

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.14, 0.22, 0.85)
	btn_style.border_color = Color(0.3, 0.35, 0.45, 0.6)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(5)
	btn_style.content_margin_left = 8
	btn_style.content_margin_right = 8
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style: StyleBoxFlat = btn_style.duplicate()
	hover_style.bg_color = Color(0.15, 0.22, 0.35, 0.9)
	hover_style.border_color = Color(0.45, 0.55, 0.75, 0.8)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = btn_style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.3, 0.5, 0.9)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))

	btn.pressed.connect(func() -> void: call(callback_name))
	add_child(btn)
	return btn


func _add_badge(parent: Button) -> Label:
	var badge: Label = Label.new()
	badge.name = "Badge"
	badge.text = "0"
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(16, 14)
	badge.visible = false

	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.7, 0.15, 0.15, 0.85)
	badge_style.set_corner_radius_all(7)
	badge.add_theme_stylebox_override("normal", badge_style)

	parent.add_child(badge)
	badge.position = Vector2(parent.custom_minimum_size.x - 12, -4)
	badge.z_index = 2
	return badge


func _find_icon_factory() -> void:
	_icon_factory = get_node_or_null("/root/GameWorld/UILayer/ResourceIconFactory")
	if _icon_factory == null:
		_icon_factory = get_node_or_null("/root/GameWorld/ResourceIconFactory")
	_set_button_icons()


func _set_button_icons() -> void:
	if _icon_factory == null or not _icon_factory.has_method("get_icon"):
		return
	_idle_btn.icon = _icon_factory.get_icon("idle_villager", 16)
	_tc_btn.icon = _icon_factory.get_icon("town_center", 16)
	_army_btn.icon = _icon_factory.get_icon("army", 16)


func _poll_counts() -> void:
	var player_id: int = GameManager.local_player_id
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	_idle_count = 0
	_army_count = 0

	for unit: Node in units:
		if not unit.has_method("get"):
			continue
		if unit.get("player_id") != player_id:
			continue
		var unit_type: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if unit_type == "villager":
			var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
			if state_machine != null:
				var current_state: String = state_machine.get("current_state") if state_machine.get("current_state") != null else ""
				if current_state == "IdleState" or current_state == "":
					_idle_count += 1
			else:
				_idle_count += 1
		else:
			_army_count += 1

	_tc_count = _count_player_tcs(player_id)


func _count_player_tcs(player_id: int) -> int:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null:
		return 0

	var count: int = 0
	var buildings: Array = []
	if bm.has_method("get_player_buildings"):
		buildings = bm.get_player_buildings(player_id)
	elif bm.get("buildings") != null:
		for id_variant: Variant in bm.get("buildings"):
			var bld: Node = bm.get("buildings")[id_variant]
			if is_instance_valid(bld) and bld.get("player_id") == player_id:
				buildings.append(bld)

	for bld: Node in buildings:
		if not is_instance_valid(bld):
			continue
		var b_type: String = bld.get("building_type") if bld.get("building_type") != null else ""
		if b_type == "town_center":
			count += 1
	return count


func _update_badges() -> void:
	_update_badge(_idle_count_label, _idle_count)
	_update_badge(_tc_count_label, _tc_count)
	_update_badge(_army_count_label, _army_count)


func _update_badge(label: Label, count: int) -> void:
	if label == null:
		return
	if count > 0:
		label.text = str(count)
		label.visible = true
	else:
		label.visible = false


func _on_idle_pressed() -> void:
	var player_id: int = GameManager.local_player_id
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if not unit.has_method("get"):
			continue
		if unit.get("player_id") != player_id:
			continue
		var unit_type: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if unit_type != "villager":
			continue
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null:
			var current_state: String = state_machine.get("current_state") if state_machine.get("current_state") != null else ""
			if current_state == "IdleState" or current_state == "":
				_select_and_center(unit)
				return
		else:
			_select_and_center(unit)
			return


func _on_tc_pressed() -> void:
	var player_id: int = GameManager.local_player_id
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null:
		return

	var buildings: Array = []
	if bm.has_method("get_player_buildings"):
		buildings = bm.get_player_buildings(player_id)
	elif bm.get("buildings") != null:
		for id_variant: Variant in bm.get("buildings"):
			var bld: Node = bm.get("buildings")[id_variant]
			if is_instance_valid(bld) and bld.get("player_id") == player_id:
				buildings.append(bld)

	for bld: Node in buildings:
		if not is_instance_valid(bld):
			continue
		var b_type: String = bld.get("building_type") if bld.get("building_type") != null else ""
		if b_type == "town_center":
			var b_id: int = bld.get("building_id") if bld.get("building_id") != null else -1
			if b_id != -1:
				var sel_manager: Node = get_node_or_null("/root/GameWorld/SelectionManager")
				if sel_manager != null and sel_manager.has_method("select_building"):
					sel_manager.select_building(b_id)
				var cam: Camera2D = get_viewport().get_camera_2d()
				if cam and cam.has_method("teleport_to"):
					cam.teleport_to(bld.global_position)
				EventBus.building_selected.emit(b_id, player_id)
			return


func _on_army_pressed() -> void:
	var player_id: int = GameManager.local_player_id
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	var army_ids: Array[int] = []
	for unit: Node in units:
		if not unit.has_method("get"):
			continue
		if unit.get("player_id") != player_id:
			continue
		var unit_type: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if unit_type == "villager":
			continue
		var uid: int = unit.get("unit_id") if unit.get("unit_id") != null else -1
		if uid != -1:
			army_ids.append(uid)

	var sel_manager: Node = get_node_or_null("/root/GameWorld/SelectionManager")
	if sel_manager != null and sel_manager.has_method("select_units"):
		sel_manager.select_units(army_ids)


func _select_and_center(unit: Node) -> void:
	var uid: int = unit.get("unit_id") if unit.get("unit_id") != null else -1
	if uid == -1:
		return
	var sel_manager: Node = get_node_or_null("/root/GameWorld/SelectionManager")
	if sel_manager != null and sel_manager.has_method("select_unit"):
		sel_manager.select_unit(uid)
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam and cam.has_method("teleport_to"):
		cam.teleport_to(unit.global_position)
