extends Node2D
## Manages rally points for buildings.
##
## When a building has a rally point set, newly trained units automatically
## walk to that location. Draws a dashed line from building to rally point.
## Right-click while a building is selected to set the rally point.

const LINE_COLOR: Color = Color(0.3, 0.8, 1.0, 0.7)
const LINE_WIDTH: float = 2.0
const DASH_LENGTH: float = 8.0
const GAP_LENGTH: float = 6.0
const ARROW_SIZE: float = 8.0
const FLAG_SIZE: float = 6.0

var _rally_points: Dictionary = {}  # building_id -> Vector2
var _selected_building_id: int = -1
var _camera: Camera2D = null


func _ready() -> void:
	z_index = 5
	_find_camera()
	EventBus.building_selected.connect(_on_building_selected)
	EventBus.building_placed.connect(_on_building_placed)


func _process(_delta: float) -> void:
	queue_redraw()


func _find_camera() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_node_or_null("/root/GameWorld/Camera2D")


func set_rally_point(building_id: int, world_pos: Vector2) -> void:
	_rally_points[building_id] = world_pos
	EventBus.rally_point_set.emit(building_id, world_pos) if EventBus.has_signal("rally_point_set") else null


func get_rally_point(building_id: int) -> Vector2:
	return _rally_points.get(building_id, Vector2.ZERO)


func has_rally_point(building_id: int) -> bool:
	return _rally_points.has(building_id)


func clear_rally_point(building_id: int) -> void:
	_rally_points.erase(building_id)


func send_unit_to_rally(unit_node: Node, building_id: int) -> void:
	if not _rally_points.has(building_id):
		return
	var target: Vector2 = _rally_points[building_id]
	if unit_node.has_method("set") and unit_node.get("pending_move_position") != null:
		unit_node.pending_move_position = target
		var sm: Node = unit_node.get_node_or_null("UnitStateMachine")
		if sm != null and sm.has_method("change_state"):
			sm.change_state("MoveState")


func get_all_rally_points() -> Dictionary:
	return _rally_points.duplicate()


func _on_building_selected(building_id: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		_selected_building_id = building_id
	else:
		_selected_building_id = -1


func _on_building_placed(building_id: int, _building_type: String, player_id: int, _position: Vector2) -> void:
	if player_id == GameManager.local_player_id:
		# Default rally point: 120px below the building.
		var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
		if bm == null:
			bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
		if bm != null and bm.has_method("get_building"):
			var bnode: Node2D = bm.get_building(building_id)
			if bnode != null:
				set_rally_point(building_id, bnode.global_position + Vector2(0, 120))


func _gui_input(event: InputEvent) -> void:
	if _selected_building_id == -1:
		return

	var click_pos: Vector2 = Vector2.ZERO
	var is_click: bool = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		click_pos = event.position
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		# Only handle right-click equivalent (long press could be used on mobile).
		return

	if is_click:
		var world_pos: Vector2 = get_global_mouse_position()
		set_rally_point(_selected_building_id, world_pos)


func _draw() -> void:
	for building_id: int in _rally_points:
		var rally_pos: Vector2 = _rally_points[building_id]
		var building_node: Node2D = _find_building_by_id(building_id)
		if building_node == null:
			continue
		var from: Vector2 = building_node.global_position
		_draw_dashed_line(from, rally_pos, LINE_COLOR, LINE_WIDTH)
		_draw_arrowhead(from, rally_pos, LINE_COLOR)
		_draw_flag(rally_pos, LINE_COLOR)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var dir: Vector2 = (to - from)
	var total_len: float = dir.length()
	if total_len < 1.0:
		return
	var norm: Vector2 = dir / total_len
	var traveled: float = 0.0
	var drawing: bool = true

	while traveled < total_len:
		var seg_len: float = DASH_LENGTH if drawing else GAP_LENGTH
		var end: float = minf(traveled + seg_len, total_len)
		if drawing:
			var p1: Vector2 = from + norm * traveled
			var p2: Vector2 = from + norm * end
			draw_line(p1, p2, color, width)
		traveled = end
		drawing = not drawing


func _draw_arrowhead(from: Vector2, to: Vector2, color: Color) -> void:
	var dir: Vector2 = (to - from).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = to
	var left: Vector2 = tip - dir * ARROW_SIZE + perp * ARROW_SIZE * 0.4
	var right: Vector2 = tip - dir * ARROW_SIZE - perp * ARROW_SIZE * 0.4
	var points: PackedVector2Array = PackedVector2Array([tip, left, right])
	draw_colored_polygon(points, color)


func _draw_flag(pos: Vector2, color: Color) -> void:
	# Pole.
	draw_line(pos, pos + Vector2(0, -14), color, 1.5)
	# Flag triangle.
	var flag_points: PackedVector2Array = PackedVector2Array([
		pos + Vector2(0, -14),
		pos + Vector2(FLAG_SIZE * 2, -10),
		pos + Vector2(0, -6),
	])
	draw_colored_polygon(flag_points, color)


func _find_building_by_id(building_id: int) -> Node2D:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm != null and bm.has_method("get_building"):
		return bm.get_building(building_id)
	return null
