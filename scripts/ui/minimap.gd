extends Control

const MINIMAP_SIZE: Vector2 = Vector2(160, 160)
const DOT_PLAYER: Color = Color(0.2, 0.4, 1.0)
const DOT_ENEMY: Color = Color(1.0, 0.2, 0.2)
const DOT_NEUTRAL: Color = Color(0.5, 0.5, 0.5)
const DOT_UNIT_SIZE: float = 2.0
const DOT_BUILDING_SIZE: float = 4.0
const CAMERA_RECT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const BG_COLOR: Color = Color(0.05, 0.05, 0.1, 0.85)
const BORDER_COLOR: Color = Color(0.3, 0.3, 0.3, 1.0)
const TERRAIN_COLORS: Dictionary = {
	0: Color(0.05, 0.15, 0.45),   # DEEP_WATER
	1: Color(0.15, 0.35, 0.7),    # WATER
	2: Color(0.85, 0.78, 0.55),   # SAND
	3: Color(0.28, 0.55, 0.2),    # GRASS
	4: Color(0.12, 0.35, 0.1),    # FOREST
	5: Color(0.45, 0.42, 0.38),   # MOUNTAIN
}

var world_size: Vector2 = Vector2(4096, 4096)
var _update_timer: float = 0.0
var _update_interval: float = 0.25
var _cached_dots: Array = []
var _camera: Camera2D = null
var _terrain_image: Image = null
var _terrain_texture: ImageTexture = null
var _is_dragging: bool = false
var _grid_manager: Node = null


func _ready() -> void:
	custom_minimum_size = MINIMAP_SIZE
	size = MINIMAP_SIZE
	_find_camera()
	_find_grid_manager()
	_build_terrain_image()
	update_minimap()


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		update_minimap()
	queue_redraw()


func _find_camera() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_node_or_null("/root/GameWorld/Camera2D")


func _find_grid_manager() -> void:
	if _grid_manager == null or not is_instance_valid(_grid_manager):
		_grid_manager = get_node_or_null("/root/GameWorld/GridManager")


func set_world_size(new_size: Vector2) -> void:
	world_size = new_size
	_build_terrain_image()


func _build_terrain_image() -> void:
	var grid_dims: Vector2i = Vector2i(128, 128)
	if _grid_manager != null and _grid_manager.get("grid_dimensions") != null:
		grid_dims = _grid_manager.grid_dimensions

	_terrain_image = Image.create(grid_dims.x, grid_dims.y, false, Image.FORMAT_RGBA8)

	if _grid_manager == null or _grid_manager.get("get_cell_walkability") == null:
		_terrain_image.fill(TERRAIN_COLORS[3])
		_terrain_texture = ImageTexture.create_from_image(_terrain_image)
		return

	for y in range(grid_dims.y):
		for x in range(grid_dims.x):
			var cell: Vector2i = Vector2i(x, y)
			var walk_state: int = _grid_manager.get_cell_walkability(cell)
			var terrain_color: Color = TERRAIN_COLORS[3]
			if walk_state == 1:
				terrain_color = TERRAIN_COLORS[1]
			elif walk_state == 2:
				terrain_color = TERRAIN_COLORS[5]
			elif walk_state == 0:
				terrain_color = TERRAIN_COLORS[3]
			_terrain_image.set_pixel(x, y, terrain_color)

	_terrain_texture = ImageTexture.create_from_image(_terrain_image)


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

	if _terrain_texture != null:
		draw_texture_rect(_terrain_texture, Rect2(Vector2.ZERO, size), false)

	for dot: Dictionary in _cached_dots:
		var minimap_pos: Vector2 = world_to_minimap(dot["pos"])
		if minimap_pos.x < 0 or minimap_pos.x > size.x:
			continue
		if minimap_pos.y < 0 or minimap_pos.y > size.y:
			continue
		draw_circle(minimap_pos, dot["size"], dot["color"])

	_draw_camera_rect()


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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_is_dragging = true
			_move_camera_to_click(event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		_move_camera_to_click(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_is_dragging = true
			_move_camera_to_click(event.position)
		else:
			_is_dragging = false
	elif event is InputEventScreenDrag:
		_move_camera_to_click(event.position)


func _move_camera_to_click(click_pos: Vector2) -> void:
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
