class_name GhostBuilding
extends Node2D

## Visual preview of a building being placed. Shows green when placement is
## valid, red when invalid. Follows the cursor in build mode.

var building_type: String = ""
var player_id: int = -1
var grid_size: Vector2i = Vector2i(2, 2)
var is_valid: bool = false

var _ghost_layer: CanvasLayer = null
var _sprite: AnimatedSprite2D = null
var _grid_overlay: Node2D = null

const VALID_COLOR: Color = Color(0.2, 0.9, 0.3, 0.45)
const INVALID_COLOR: Color = Color(0.9, 0.2, 0.2, 0.45)
const VALID_BORDER: Color = Color(0.3, 1.0, 0.4, 0.8)
const INVALID_BORDER: Color = Color(1.0, 0.3, 0.3, 0.8)
const CELL_SIZE: float = 32.0

var _grid_manager: Node = null
var _camera: Camera2D = null


func _ready() -> void:
	_ghost_layer = CanvasLayer.new()
	_ghost_layer.layer = 90
	_ghost_layer.name = "GhostBuildingLayer"
	add_child(_ghost_layer)

	_grid_overlay = Node2D.new()
	_grid_overlay.name = "GridOverlay"
	_ghost_layer.add_child(_grid_overlay)
	_grid_overlay.draw.connect(_draw_grid)

	_grid_manager = _find_grid_manager()
	_camera = _find_camera()


func setup(type: String, owner_id: int) -> void:
	building_type = type
	player_id = owner_id

	var building_data: Dictionary = DataManager.get_building_data(type)
	if building_data.is_empty():
		return

	var raw_size: Variant = building_data.get("size", {"x": 2, "y": 2})
	if raw_size is Vector2i:
		grid_size = raw_size
	elif raw_size is Dictionary:
		grid_size = Vector2i(int(raw_size.get("x", 2)), int(raw_size.get("y", 2)))

	# Create preview sprite.
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.queue_free()

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "GhostSprite"
	_sprite.sprite_frames = ProceduralSpriteFactory.create_building_frames(type, player_id, grid_size)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0, -16)
	_sprite.z_index = 6
	_ghost_layer.add_child(_sprite)

	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
	elif _sprite.sprite_frames and _sprite.sprite_frames.has_animation("active"):
		_sprite.play("active")

	visible = true


func update_position(screen_pos: Vector2) -> void:
	if _camera == null:
		_camera = _find_camera()
	if _camera == null:
		return

	var world_pos: Vector2 = _camera.get_canvas_transform().affine_inverse() * screen_pos
	global_position = world_pos

	_validate_placement()
	_grid_overlay.queue_redraw()


func _validate_placement() -> void:
	if _grid_manager == null:
		_grid_manager = _find_grid_manager()
	if _grid_manager == null:
		is_valid = false
		return

	var cell: Vector2i = _grid_manager.get_cell_from_world(global_position)
	is_valid = _grid_manager.is_buildable(cell, grid_size)

	# Also check if player can afford.
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	var cost: Dictionary = building_data.get("cost", {})
	if not GameManager.can_afford(cost, player_id):
		is_valid = false

	# Update sprite tint.
	if _sprite != null:
		_sprite.modulate = VALID_COLOR if is_valid else INVALID_COLOR


func confirm_placement() -> bool:
	if not is_valid:
		return false

	var grid_manager: Node = _find_grid_manager()
	if grid_manager == null:
		return false

	var cell: Vector2i = grid_manager.get_cell_from_world(global_position)
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	var cost: Dictionary = building_data.get("cost", {})

	if not GameManager.spend_resources(cost, player_id):
		return false

	var building_manager: Node = _find_building_manager()
	if building_manager != null and building_manager.has_method("place_building"):
		var building_node: Node2D = building_manager.place_building(building_type, cell, player_id)
		if building_node != null:
			if building_node.has_method("start_construction"):
				building_node.start_construction()
			AudioManager.play_sfx("res://audio/sfx/build_place.wav")
			return true

	AudioManager.play_sfx("res://audio/sfx/cant_build.wav")
	GameManager.add_resource("wood", cost.get("wood", 0), player_id)
	GameManager.add_resource("stone", cost.get("stone", 0), player_id)
	GameManager.add_resource("food", cost.get("food", 0), player_id)
	GameManager.add_resource("gold", cost.get("gold", 0), player_id)
	return false


func cancel() -> void:
	queue_free()


func _draw_grid() -> void:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return

	var border_color: Color = VALID_BORDER if is_valid else INVALID_BORDER
	var fill_color: Color = VALID_COLOR if is_valid else INVALID_COLOR

	var cell: Vector2i = Vector2i.ZERO
	if _grid_manager != null:
		cell = _grid_manager.get_cell_from_world(global_position)

	var top_left: Vector2 = Vector2(
		float(cell.x) * CELL_SIZE,
		float(cell.y) * CELL_SIZE
	)
	var size: Vector2 = Vector2(
		float(grid_size.x) * CELL_SIZE,
		float(grid_size.y) * CELL_SIZE
	)

	# Draw in canvas-layer space (no transform needed).
	_grid_overlay.draw_rect(Rect2(top_left, size), fill_color, true)
	_grid_overlay.draw_rect(Rect2(top_left, size), border_color, false, 2.0)


func _find_grid_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var node: Node = scene.get_node_or_null("GridManager")
	if node != null:
		return node
	var world: Node = scene.get_node_or_null("World")
	if world != null:
		return world.get_node_or_null("GridManager")
	return null


func _find_building_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var node: Node = scene.get_node_or_null("BuildingManager")
	if node != null:
		return node
	var world: Node = scene.get_node_or_null("World")
	if world != null:
		return world.get_node_or_null("BuildingManager")
	return null


func _find_camera() -> Camera2D:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var cam: Node = scene.get_node_or_null("Camera2D")
	if cam != null and cam is Camera2D:
		return cam as Camera2D
	return null
