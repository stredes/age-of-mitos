extends HBoxContainer
## Quick-action hotkey panel with buttons for idle villagers, TC, and army.
##
## Positioned at the bottom-left. Buttons show badge counts and center
## the camera on the relevant units/buildings when pressed.
## Hotkeys: F1 = idle villagers, F2 = town center, F3 = army.

const BTN_SIZE: Vector2 = Vector2(48, 48)
const BADGE_OFFSET: Vector2 = Vector2(22, -4)
const COLOR_IDLE: Color = Color(0.95, 0.82, 0.2)
const COLOR_TC: Color = Color(0.2, 0.6, 1.0)
const COLOR_ARMY: Color = Color(0.92, 0.3, 0.2)

var _idle_btn: Button = null
var _tc_btn: Button = null
var _army_btn: Button = null
var _idle_badge: Label = null
var _tc_badge: Label = null
var _army_badge: Label = null
var _camera: Camera2D = null
var _poll_timer: float = 0.0
var _poll_interval: float = 1.0
var _icon_factory: Node = null


func _ready() -> void:
	_find_camera()
	_find_icon_factory()
	_build_ui()
	_update_counts()
	_process_inputs()


func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= _poll_interval:
		_poll_timer = 0.0
		_update_counts()


func _find_camera() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_node_or_null("/root/GameWorld/Camera2D")


func _find_icon_factory() -> void:
	_icon_factory = get_node_or_null("/root/GameWorld/UILayer/ResourceIconFactory")
	if _icon_factory == null:
		_icon_factory = get_node_or_null("/root/GameWorld/ResourceIconFactory")


func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	# Idle Villagers button.
	_idle_btn = _create_button("Idle", COLOR_IDLE, "idle_villagers")
	_idle_btn.pressed.connect(_on_idle_pressed)
	add_child(_idle_btn)
	_idle_badge = _add_badge(_idle_btn)

	# Town Center button.
	_tc_btn = _create_button("TC", COLOR_TC, "town_center")
	_tc_btn.pressed.connect(_on_tc_pressed)
	add_child(_tc_btn)
	_tc_badge = _add_badge(_tc_btn)

	# Army button.
	_army_btn = _create_button("Army", COLOR_ARMY, "army")
	_army_btn.pressed.connect(_on_army_pressed)
	add_child(_army_btn)
	_army_badge = _add_badge(_army_btn)


func _create_button(label_text: String, color: Color, _action: String) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = BTN_SIZE
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.85)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn


func _add_badge(parent: Button) -> Label:
	var badge: Label = Label.new()
	badge.name = "Badge"
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.visible = false
	parent.add_child(badge)
	badge.position = BADGE_OFFSET
	return badge


func _update_counts() -> void:
	var local_player: int = GameManager.local_player_id
	var units: Array[Node] = get_tree().get_nodes_in_group("units")

	var idle_count: int = 0
	var army_count: int = 0

	for unit: Node in units:
		if not is_instance_valid(unit):
			continue
		var pid: int = unit.get("player_id") if unit.has_method("get") and unit.get("player_id") != null else -1
		if pid != local_player:
			continue
		var unit_type: String = unit.get("unit_type") if unit.has_method("get") and unit.get("unit_type") != null else ""
		var sm: Node = unit.get_node_or_null("UnitStateMachine")
		var current_state: String = ""
		if sm != null and sm.get("current_state") != null:
			current_state = sm.current_state.name if sm.current_state.has_method("get") and sm.current_state.get("name") != null else ""

		if unit_type == "villager" and current_state == "IdleState":
			idle_count += 1

		if unit_type != "villager" and unit_type != "":
			army_count += 1

	_update_badge(_idle_badge, idle_count)
	_update_badge(_army_badge, army_count)

	# TC count.
	var tc_count: int = 0
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm != null:
		var buildings_dict: Dictionary = bm.get("buildings") if bm.get("buildings") != null else {}
		for id: Variant in buildings_dict:
			var bnode: Node = buildings_dict[id]
			if not is_instance_valid(bnode):
				continue
			var bpid: int = bnode.get("player_id") if bnode.has_method("get") and bnode.get("player_id") != null else -1
			var btype: String = bnode.get("building_type") if bnode.has_method("get") and bnode.get("building_type") != null else ""
			if bpid == local_player and btype == "town_center":
				tc_count += 1
	_update_badge(_tc_badge, tc_count)


func _update_badge(badge: Label, count: int) -> void:
	if badge == null:
		return
	if count > 0:
		badge.text = str(count)
		badge.visible = true
	else:
		badge.visible = false


func _on_idle_pressed() -> void:
	var local_player: int = GameManager.local_player_id
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	var idle_villagers: Array[Node] = []

	for unit: Node in units:
		if not is_instance_valid(unit):
			continue
		var pid: int = unit.get("player_id") if unit.has_method("get") and unit.get("player_id") != null else -1
		if pid != local_player:
			continue
		var unit_type: String = unit.get("unit_type") if unit.has_method("get") and unit.get("unit_type") != null else ""
		if unit_type != "villager":
			continue
		var sm: Node = unit.get_node_or_null("UnitStateMachine")
		if sm != null and sm.get("current_state") != null:
			var state_name: String = sm.current_state.name if sm.current_state.has_method("get") and sm.current_state.get("name") != null else ""
			if state_name == "IdleState":
				idle_villagers.append(unit)

	if idle_villagers.size() > 0:
		# Select first idle villager and center camera.
		var target: Node = idle_villagers[0]
		EventBus.unit_selected.emit(target.get("unit_id"), local_player)
		_center_camera_on(target.global_position)


func _on_tc_pressed() -> void:
	var local_player: int = GameManager.local_player_id
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null:
		return

	var buildings_dict: Dictionary = bm.get("buildings") if bm.get("buildings") != null else {}
	for id: Variant in buildings_dict:
		var bnode: Node = buildings_dict[id]
		if not is_instance_valid(bnode):
			continue
		var bpid: int = bnode.get("player_id") if bnode.has_method("get") and bnode.get("player_id") != null else -1
		var btype: String = bnode.get("building_type") if bnode.has_method("get") and bnode.get("building_type") != null else ""
		if bpid == local_player and btype == "town_center":
			EventBus.building_selected.emit(int(id), local_player)
			_center_camera_on(bnode.global_position)
			return


func _on_army_pressed() -> void:
	var local_player: int = GameManager.local_player_id
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	var army: Array[int] = []

	for unit: Node in units:
		if not is_instance_valid(unit):
			continue
		var pid: int = unit.get("player_id") if unit.has_method("get") and unit.get("player_id") != null else -1
		if pid != local_player:
			continue
		var unit_type: String = unit.get("unit_type") if unit.has_method("get") and unit.get("unit_type") != null else ""
		if unit_type != "villager" and unit_type != "":
			var uid: int = unit.get("unit_id") if unit.has_method("get") and unit.get("unit_id") != null else -1
			if uid != -1:
				army.append(uid)

	if army.size() > 0:
		# Center on the first army unit.
		for unit: Node in units:
			if not is_instance_valid(unit):
				continue
			var uid: int = unit.get("unit_id") if unit.has_method("get") and unit.get("unit_id") != null else -1
			if uid == army[0]:
				_center_camera_on(unit.global_position)
				break
		# Select all army units.
		EventBus.selection_changed.emit(army, [])


func _center_camera_on(world_pos: Vector2) -> void:
	if _camera == null:
		_find_camera()
	if _camera == null:
		return
	if _camera.has_method("teleport_to"):
		_camera.teleport_to(world_pos)
	else:
		_camera.global_position = world_pos
		EventBus.camera_moved.emit(world_pos)


func _process_inputs() -> void:
	# Register keyboard shortcuts via input map is complex; use _unhandled_input.
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_on_idle_pressed()
			KEY_F2:
				_on_tc_pressed()
			KEY_F3:
				_on_army_pressed()
