extends Control

const MINIMAP_SIZE: Vector2 = Vector2(120, 120)
const DOT_PLAYER: Color = Color(0.2, 0.4, 1.0)
const DOT_ENEMY: Color = Color(1.0, 0.2, 0.2)
const DOT_NEUTRAL: Color = Color(0.5, 0.5, 0.5)
const DOT_UNIT_SIZE: float = 2.0
const DOT_BUILDING_SIZE: float = 4.0
const CAMERA_RECT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const BG_COLOR: Color = Color(0.05, 0.05, 0.1, 0.85)
const BORDER_COLOR: Color = Color(0.3, 0.3, 0.3, 1.0)
const FOG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)

var world_size: Vector2 = Vector2(4096, 4096)
var _update_timer: float = 0.0
var _update_interval: float = 0.5
var _cached_dots: Array = []
var _camera: Camera2D = null


func _ready() -> void:
	custom_minimum_size = MINIMAP_SIZE
	size = MINIMAP_SIZE
	_find_camera()
	update_minimap()


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		update_minimap()
	queue_redraw()


func _find_camera() -> void:
	if has_node("/root/GameWorld/Camera2D"):
		_camera = get_node("/root/GameWorld/Camera2D")


func set_world_size(size: Vector2) -> void:
	world_size = size


func update_minimap() -> void:
	_cached_dots.clear()
	_cache_building_dots()
	_cache_unit_dots()


func _cache_building_dots() -> void:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null:
		return

	var buildings_dict: Dictionary = bm.get("buildings") if bm.get("buildings") != null else {}
	var local_player: int = GameManager.local_player_id

	for id_variant: Variant in buildings_dict:
		var node: Node2D = buildings_dict[id_variant]
		if not is_instance_valid(node):
			continue
		var pos: Vector2 = node.global_position
		var player_id: int = node.get("player_id") if node.has_method("get") and node.get("player_id") != null else -1
		var color: Color = DOT_PLAYER if player_id == local_player else DOT_ENEMY
		_cached_dots.append({"pos": pos, "color": color, "size": DOT_BUILDING_SIZE})


func _cache_unit_dots() -> void:
	var local_player: int = GameManager.local_player_id
	var units: Array[Node] = get_tree().get_nodes_in_group("units")

	for unit: Node in units:
		if not is_instance_valid(unit):
			continue
		if not unit is Node2D:
			continue
		var pos: Vector2 = unit.global_position
		var player_id: int = unit.get("player_id") if unit.has_method("get") and unit.get("player_id") != null else -1
		var color: Color = DOT_PLAYER if player_id == local_player else DOT_ENEMY
		_cached_dots.append({"pos": pos, "color": color, "size": DOT_UNIT_SIZE})


func world_to_minimap(world_pos: Vector2) -> Vector2:
	var ratio: Vector2 = Vector2(world_pos.x / world_size.x, world_pos.y / world_size.y)
	return Vector2(
		ratio.x * size.x,
		ratio.y * size.y
	)


func minimap_to_world(minimap_pos: Vector2) -> Vector2:
	var ratio: Vector2 = Vector2(minimap_pos.x / size.x, minimap_pos.y / size.y)
	return Vector2(
		ratio.x * world_size.x,
		ratio.y * world_size.y
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 2.0)

	for dot: Dictionary in _cached_dots:
		var minimap_pos: Vector2 = world_to_minimap(dot["pos"])
		if minimap_pos.x < 0 or minimap_pos.x > size.x:
			continue
		if minimap_pos.y < 0 or minimap_pos.y > size.y:
			continue
		draw_circle(minimap_pos, dot["size"], dot["color"])

	_draw_camera_rect()
	_draw_fog_overlay()


func _draw_camera_rect() -> void:
	if _camera == null:
		_find_camera()
	if _camera == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom: float = _camera.zoom.x
	if zoom <= 0.0:
		zoom = 1.0

	var half_view: Vector2 = (viewport_size * 0.5) / zoom
	var cam_pos: Vector2 = _camera.global_position

	var top_left_world: Vector2 = cam_pos - half_view
	var bottom_right_world: Vector2 = cam_pos + half_view

	var top_left_minimap: Vector2 = world_to_minimap(top_left_world)
	var bottom_right_minimap: Vector2 = world_to_minimap(bottom_right_world)

	var rect: Rect2 = Rect2(top_left_minimap, bottom_right_minimap - top_left_minimap)
	draw_rect(rect, CAMERA_RECT_COLOR, false, 1.5)


func _draw_fog_overlay() -> void:
	var fog_of_war: Node = get_node_or_null("/root/GameWorld/FogOfWar")
	if fog_of_war == null:
		return
	if not fog_of_war.has_method("get"):
		return


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_minimap_click(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_handle_minimap_click(event.position)


func _handle_minimap_click(click_pos: Vector2) -> void:
	var world_pos: Vector2 = minimap_to_world(click_pos)
	world_pos.x = clampf(world_pos.x, 0.0, world_size.x)
	world_pos.y = clampf(world_pos.y, 0.0, world_size.y)

	if _camera == null:
		_find_camera()
	if _camera and _camera.has_method("teleport_to"):
		_camera.teleport_to(world_pos)
	elif _camera:
		_camera.global_position = world_pos
		EventBus.camera_moved.emit(world_pos)
