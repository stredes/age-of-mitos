## Manages all building instances in the game. Central registry for placement,
## removal, queries, and lifecycle coordination of every placed building.
class_name BuildingManager
extends Node

# =============================================================================
# Signals
# =============================================================================

signal building_added(building_id: int, building_type: String, player_id: int)
signal building_removed(building_id: int, player_id: int)

# =============================================================================
# Properties
# =============================================================================

var buildings: Dictionary = {}
var _next_id: int = 1
var _grid_manager: Node = null
var _building_scene: PackedScene = null

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_grid_manager = _find_grid_manager()
	_building_scene = _load_building_scene()
	_connect_event_bus()


func _connect_event_bus() -> void:
	if not EventBus.building_placed.is_connected(_on_event_building_placed):
		EventBus.building_placed.connect(_on_event_building_placed)
	if not EventBus.building_destroyed.is_connected(_on_event_building_destroyed):
		EventBus.building_destroyed.connect(_on_event_building_destroyed)
	if not EventBus.construction_completed.is_connected(_on_event_construction_completed):
		EventBus.construction_completed.connect(_on_event_construction_completed)

# =============================================================================
# Setup Helpers
# =============================================================================

func _find_grid_manager() -> Node:
	var node: Node = get_node_or_null("/root/GameWorld/GridManager")
	if node:
		return node
	return get_node_or_null("/root/GameWorld/World/GridManager")


func _load_building_scene() -> PackedScene:
	var path: String = "res://scenes/buildings/building.tscn"
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null

# =============================================================================
# Placement
# =============================================================================

func place_building(type: String, grid_pos: Vector2i, player_id: int) -> Node2D:
	var building_data: Dictionary = DataManager.get_building_data(type)
	if building_data.is_empty():
		push_warning("BuildingManager: Unknown building type '%s'." % type)
		return null

	var raw_size: Variant = building_data.get("size", {"x": 2, "y": 2})
	var size: Vector2i
	if raw_size is Vector2i:
		size = raw_size
	elif raw_size is Dictionary:
		size = Vector2i(int(raw_size.get("x", 2)), int(raw_size.get("y", 2)))
	else:
		size = Vector2i(2, 2)

	if _grid_manager and not _grid_manager.is_buildable(grid_pos, size):
		push_warning("BuildingManager: Cannot place '%s' at %s." % [type, grid_pos])
		return null

	var id: int = _next_id
	_next_id += 1

	var building_node: Node2D = _create_building_node(type, id, player_id, grid_pos)
	if building_node == null:
		return null

	buildings[id] = building_node
	_register_building_signals(building_node)

	if _grid_manager:
		var id_str: String = str(id)
		_grid_manager.place_building(grid_pos, size, type, id_str)

	EventBus.building_placed.emit(id, type, player_id, building_node.global_position)
	building_added.emit(id, type, player_id)
	return building_node


func _create_building_node(type: String, id: int, player_id: int, grid_pos: Vector2i) -> Node2D:
	var building_node: Node2D = null

	if _building_scene:
		building_node = _building_scene.instantiate() as Node2D
	else:
		building_node = _create_fallback_building()

	if building_node == null:
		return null

	if not building_node.is_inside_tree():
		add_child(building_node)

	if building_node.has_method("initialize"):
		building_node.initialize(type, player_id, grid_pos)

	building_node.building_id = id

	if _grid_manager:
		building_node.global_position = _grid_manager.get_world_pos_from_cell(grid_pos)

	return building_node


func _create_fallback_building() -> Node2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	body.add_child(sprite)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	body.add_child(collision_shape)

	return body


func _register_building_signals(building_node: Node) -> void:
	if building_node == null:
		return
	if building_node.has_signal("production_completed"):
		var callback: Callable = Callable(self, "_on_building_production_completed")
		if not building_node.production_completed.is_connected(callback):
			building_node.production_completed.connect(callback)

# =============================================================================
# Removal
# =============================================================================

func remove_building(building_id: int) -> void:
	if not buildings.has(building_id):
		return

	var building_node: Node2D = buildings[building_id]
	var player_id: int = building_node.player_id if building_node.has_method("get") and building_node.get("player_id") != null else -1
	var grid_pos: Vector2i = building_node.grid_position if building_node.has_method("get") and building_node.get("grid_position") != null else Vector2i.ZERO
	var b_size: Vector2i = building_node.grid_size if building_node.has_method("get") and building_node.get("grid_size") != null else Vector2i(1, 1)

	buildings.erase(building_id)

	if _grid_manager:
		_grid_manager.remove_building_by_id(str(building_id))

	if is_instance_valid(building_node):
		building_node.queue_free()

	building_removed.emit(building_id, player_id)


## Cancel a building under construction and refund a percentage of resources.
## [param refund_percent: float] Fraction of original cost returned (0.0 - 1.0).
func cancel_construction(building_id: int, refund_percent: float = 0.75) -> void:
	if not buildings.has(building_id):
		return

	var building_node: Node2D = buildings[building_id]
	if building_node == null or not is_instance_valid(building_node):
		return

	# Only cancel if not yet completed.
	if building_node.get("is_constructed") == true:
		return

	var player_id: int = building_node.get("player_id") if building_node.has_method("get") and building_node.get("player_id") != null else -1
	var building_type: String = building_node.get("building_type") if building_node.has_method("get") and building_node.get("building_type") != null else ""

	# Calculate and refund resources.
	if player_id != -1 and not building_type.is_empty():
		var building_data: Dictionary = DataManager.get_building_data(building_type)
		var cost: Dictionary = building_data.get("cost", {})
		for res_type: String in cost:
			var original: int = cost[res_type]
			var refund: int = maxi(ceili(float(original) * refund_percent), 0)
			if refund > 0:
				GameManager.add_resource(res_type, refund, player_id)

	# Remove from grid and scene.
	var grid_pos: Vector2i = building_node.get("grid_position") if building_node.has_method("get") and building_node.get("grid_position") != null else Vector2i.ZERO

	buildings.erase(building_id)
	if _grid_manager:
		_grid_manager.remove_building_by_id(str(building_id))

	if is_instance_valid(building_node):
		building_node.queue_free()

	building_removed.emit(building_id, player_id)

# =============================================================================
# Queries
# =============================================================================

func get_building(building_id: int) -> Node2D:
	if buildings.has(building_id):
		var node: Node2D = buildings[building_id]
		if is_instance_valid(node):
			return node
		buildings.erase(building_id)
	return null


func get_player_buildings(player_id: int) -> Array:
	var result: Array = []
	for id: int in buildings:
		var node: Node2D = buildings[id]
		if not is_instance_valid(node):
			continue
		if node.has_method("get") and node.get("player_id") == player_id:
			result.append(node)
	return result


func get_buildings_in_area(center: Vector2, radius: float) -> Array:
	var result: Array = []
	var radius_sq: float = radius * radius
	for id: int in buildings:
		var node: Node2D = buildings[id]
		if not is_instance_valid(node):
			continue
		if node.global_position.distance_squared_to(center) <= radius_sq:
			result.append(node)
	return result


func get_nearest_drop_off(position: Vector2, player_id: int, resource_type: String = "") -> Node2D:
	var best: Node2D = null
	var best_dist_sq: float = INF

	for id: int in buildings:
		var node: Node2D = buildings[id]
		if not is_instance_valid(node):
			continue
		if node.has_method("get") and node.get("player_id") != player_id:
			continue
		if not node.has_method("get"):
			continue

		var b_type: String = node.get("building_type") if node.get("building_type") != null else ""
		if b_type == "":
			continue

		var is_drop_off: bool = _is_drop_off_building(b_type)
		if not is_drop_off:
			continue

		if resource_type != "":
			var produces: Array = node.get("produces") if node.get("produces") != null else []
			if resource_type not in produces and b_type != "town_center":
				continue

		var dist_sq: float = node.global_position.distance_squared_to(position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = node

	return best


func get_nearest_town_center(player_id: int, position: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist_sq: float = INF

	for id: int in buildings:
		var node: Node2D = buildings[id]
		if not is_instance_valid(node):
			continue
		if node.has_method("get") and node.get("player_id") != player_id:
			continue
		if node.has_method("get") and node.get("building_type") == "town_center":
			var dist_sq: float = node.global_position.distance_squared_to(position)
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best = node

	return best


func get_producing_buildings(player_id: int) -> Array:
	var result: Array = []
	for id: int in buildings:
		var node: Node2D = buildings[id]
		if not is_instance_valid(node):
			continue
		if node.has_method("get") and node.get("player_id") != player_id:
			continue
		if node.has_method("get") and node.get("is_producing") == true:
			result.append(node)
	return result


func _is_drop_off_building(type: String) -> bool:
	var drop_off_types: Array[String] = ["town_center", "lumber_camp", "mining_camp", "mill", "market", "dock"]
	return type in drop_off_types

# =============================================================================
# Placement Validation
# =============================================================================

func can_place_building(type: String, grid_pos: Vector2i) -> bool:
	var building_data: Dictionary = DataManager.get_building_data(type)
	if building_data.is_empty():
		return false
	var raw_size: Variant = building_data.get("size", {"x": 2, "y": 2})
	var size: Vector2i
	if raw_size is Vector2i:
		size = raw_size
	elif raw_size is Dictionary:
		size = Vector2i(int(raw_size.get("x", 2)), int(raw_size.get("y", 2)))
	else:
		size = Vector2i(2, 2)
	if _grid_manager:
		return _grid_manager.is_buildable(grid_pos, size)
	return true

# =============================================================================
# Event Bus Handlers
# =============================================================================

func _on_event_building_placed(building_id: int, building_type: String, player_id: int, _position: Vector2) -> void:
	if buildings.has(building_id):
		return


func _on_event_building_destroyed(building_id: int, player_id: int, destroyer_id: int) -> void:
	on_building_destroyed(building_id, player_id, destroyer_id)


func _on_event_construction_completed(building_id: int, _player_id: int) -> void:
	var building: Node2D = get_building(building_id)
	if building != null:
		_register_building_signals(building)


func _on_building_production_completed(building_id: int, unit_type: String) -> void:
	var building: Node2D = get_building(building_id)
	if building == null:
		return

	var unit_manager: Node = _find_unit_manager()
	if unit_manager == null or not unit_manager.has_method("spawn_unit"):
		return

	var player_id: int = building.get("player_id") if building.get("player_id") != null else GameManager.get_local_player_id()
	var spawn_pos: Vector2 = _find_spawn_position_near_building(building)
	unit_manager.spawn_unit(unit_type, spawn_pos, player_id)


func _find_unit_manager() -> Node:
	var node: Node = get_node_or_null("/root/GameWorld/UnitManager")
	if node:
		return node
	return get_node_or_null("/root/GameWorld/World/UnitManager")


func _find_spawn_position_near_building(building: Node2D) -> Vector2:
	if _grid_manager == null or not _grid_manager.has_method("get_cell_from_world"):
		return building.global_position + Vector2(64, 0)

	var origin: Vector2i = _grid_manager.get_cell_from_world(building.global_position)
	for radius in range(2, 8):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if abs(x) != radius and abs(y) != radius:
					continue
				var cell: Vector2i = origin + Vector2i(x, y)
				if _grid_manager.has_method("is_in_bounds") and not _grid_manager.is_in_bounds(cell):
					continue
				if _grid_manager.has_method("get_blocker") and _grid_manager.get_blocker(cell) != GridManager.WALKABLE:
					continue
				return _grid_manager.get_world_pos_from_cell(cell)

	return building.global_position + Vector2(64, 0)

# =============================================================================
# Building Lifecycle Callbacks
# =============================================================================

func on_building_destroyed(building_id: int, player_id: int, _destroyer_id: int) -> void:
	if buildings.has(building_id):
		var node: Node2D = buildings[building_id]
		buildings.erase(building_id)

		if _grid_manager:
			_grid_manager.remove_building_by_id(str(building_id))

		if is_instance_valid(node):
			node.queue_free()

		building_removed.emit(building_id, player_id)

# =============================================================================
# Debug
# =============================================================================

func get_all_building_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in buildings:
		ids.append(id)
	return ids


func get_building_count() -> int:
	return buildings.size()


func get_player_building_count(player_id: int) -> int:
	var count: int = 0
	for id: int in buildings:
		var node: Node2D = buildings[id]
		if is_instance_valid(node) and node.has_method("get") and node.get("player_id") == player_id:
			count += 1
	return count
