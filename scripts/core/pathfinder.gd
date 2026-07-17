## AStarGrid2D-based pathfinder with path caching and flow fields.
##
## Wraps Godot's AStarGrid2D to provide pathfinding that stays in sync with
## the GridManager's walkability data. Supports dynamic obstacle updates,
## path caching for frequently requested routes, and flow field generation
## for group movement.
class_name Pathfinder
extends Node

# =============================================================================
# Configuration
# =============================================================================

## Heuristic used by AStarGrid2D. MANHATTAN is fastest for 4-directional grids.
@export var heuristic: AStarGrid2D.Heuristic = AStarGrid2D.HEURISTIC_MANHATTAN

## Allow diagonal movement in paths.
@export var allow_diagonal: bool = false

## Penalty added to cells adjacent to blocked cells.
@export var adjacent_wall_penalty: float = 0.0

## Maximum number of cached paths. LRU eviction when exceeded.
@export var max_cache_size: int = 256

## Cache entries older than this (in frames) are eligible for eviction.
@export var cache_ttl_frames: int = 600  # ~10 seconds at 60fps

## Maximum age of a cached path in frames before forced invalidation.
@export var cache_max_age: int = 1800  # ~30 seconds

# =============================================================================
# Signals
# =============================================================================

signal pathfinder_rebuilt()
signal cache_invalidated()

# =============================================================================
# Internal State
# =============================================================================

var _astar: AStarGrid2D = null
var _grid_manager: Node = null
var _grid_size: Vector2i = Vector2i.ZERO
var _cell_size: Vector2i = Vector2i(32, 32)
var _initialized: bool = false
var _temporarily_blocked: Dictionary = {}

## Path cache: "start_x,start_y->end_x,end_y" → { path: Array[Vector2i], age: int, hits: int }
var _path_cache: Dictionary = {}

## Cache access order for LRU eviction.
var _cache_order: Array[String] = []

## Flow field cache: cell → direction Vector2
var _flow_field_cache: Dictionary = {}
var _flow_field_target: Vector2i = Vector2i(-1, -1)

## Frame counter for cache aging.
var _frame_count: int = 0

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_astar = AStarGrid2D.new()
	call_deferred("_initialize")


func _process(_delta: float) -> void:
	_frame_count += 1
	# Evict stale cache entries every 60 frames.
	if _frame_count % 60 == 0:
		_evict_stale_cache()

# =============================================================================
# Initialization
# =============================================================================

func _initialize() -> void:
	_grid_manager = _find_grid_manager()
	if _grid_manager == null:
		push_warning("Pathfinder: GridManager not found. Pathfinding unavailable.")
		return

	_grid_size = _grid_manager.grid_dimensions
	_cell_size = _grid_manager.cell_size
	_astar.region = Rect2i(Vector2i.ZERO, Vector2i(_grid_size.x, _grid_size.y))
	_astar.cell_size = Vector2(_cell_size.x, _cell_size.y)
	_astar.default_compute_heuristic = heuristic
	_astar.default_estimate_heuristic = heuristic
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS if allow_diagonal else AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

	_mark_walkable_cells()
	_initialized = true

	if _grid_manager.has_signal("grid_changed"):
		_grid_manager.grid_changed.connect(_on_grid_changed)

	pathfinder_rebuilt.emit()

# =============================================================================
# Grid Building
# =============================================================================

func _mark_walkable_cells() -> void:
	for y in range(_grid_size.y):
		for x in range(_grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if not _grid_manager.is_walkable(cell):
				_astar.set_point_solid(cell, true)
			else:
				_astar.set_point_solid(cell, false)
				if adjacent_wall_penalty > 0.0:
					_apply_adjacency_penalties(cell)


func _apply_adjacency_penalties(cell: Vector2i) -> void:
	if adjacent_wall_penalty <= 0.0:
		return
	var neighbors: Array[Vector2i] = _grid_manager.get_neighbors_diagonal(cell)
	var blocked_neighbors: int = 0
	for n: Vector2i in neighbors:
		if not _grid_manager.is_walkable(n):
			blocked_neighbors += 1
	if blocked_neighbors > 0:
		_astar.set_point_weight_scale(cell, 1.0 + (adjacent_wall_penalty * blocked_neighbors))


func rebuild() -> void:
	if _grid_manager == null:
		return
	_grid_size = _grid_manager.grid_dimensions
	_cell_size = _grid_manager.cell_size
	_astar.region = Rect2i(Vector2i.ZERO, Vector2i(_grid_size.x, _grid_size.y))
	_astar.cell_size = Vector2(_cell_size.x, _cell_size.y)
	_astar.update()

	_mark_walkable_cells()

	for cell: Vector2i in _temporarily_blocked:
		if _is_in_bounds(cell):
			_astar.set_point_solid(cell, true)

	_initialized = true
	invalidate_cache()
	pathfinder_rebuilt.emit()


func refresh_cell(cell: Vector2i) -> void:
	if not _initialized or _grid_manager == null:
		return
	if not _is_in_bounds(cell):
		return
	var is_solid: bool = not _grid_manager.is_walkable(cell) or _temporarily_blocked.has(cell)
	_astar.set_point_solid(cell, is_solid)

# =============================================================================
# Pathfinding (with cache)
# =============================================================================

## Find a path between two grid cells. Uses cache if available.
func find_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if not _initialized:
		push_warning("Pathfinder: Not initialized.")
		return []

	if not _is_in_bounds(start_cell) or not _is_in_bounds(end_cell):
		return []

	# Check cache first.
	var cache_key: String = _make_cache_key(start_cell, end_cell)
	if _path_cache.has(cache_key):
		var entry: Dictionary = _path_cache[cache_key]
		entry["hits"] += 1
		entry["age"] = _frame_count
		_touch_cache(cache_key)
		return entry["path"].duplicate()

	# Handle solid start/end cells.
	if _astar.is_point_solid(start_cell):
		start_cell = _get_nearest_walkable(start_cell)
		if start_cell == Vector2i(-1, -1):
			return []

	if _astar.is_point_solid(end_cell):
		end_cell = _get_nearest_walkable(end_cell)
		if end_cell == Vector2i(-1, -1):
			return []

	var path: PackedVector2Array = _astar.get_id_path(start_cell, end_cell)
	if path.is_empty():
		return []

	var result: Array[Vector2i] = []
	for point: Vector2 in path:
		result.append(Vector2i(int(point.x), int(point.y)))

	# Store in cache.
	_store_in_cache(cache_key, result)

	return result


## Find a path and return world-space positions.
func find_path_world(start_pos: Vector2, end_pos: Vector2) -> Array[Vector2]:
	var start_cell: Vector2i = _world_to_cell(start_pos)
	var end_cell: Vector2i = _world_to_cell(end_pos)
	var cell_path: Array[Vector2i] = find_path(start_cell, end_cell)
	var world_path: Array[Vector2] = []
	for cell: Vector2i in cell_path:
		world_path.append(_cell_to_world(cell))
	return world_path


## Find a path but return only world positions for movement (skips start cell).
func find_path_for_movement(start_pos: Vector2, end_pos: Vector2) -> Array[Vector2]:
	var world_path: Array[Vector2] = find_path_world(start_pos, end_pos)
	if world_path.size() > 0:
		world_path.pop_front()
	return world_path

# =============================================================================
# Path Validation
# =============================================================================

func is_valid_path(path: Array[Vector2i]) -> bool:
	if path.is_empty():
		return false
	for cell: Vector2i in path:
		if not _is_in_bounds(cell):
			return false
		if _astar.is_point_solid(cell):
			return false
	return true


func has_direct_path(start_cell: Vector2i, end_cell: Vector2i) -> bool:
	var path: Array[Vector2i] = find_path(start_cell, end_cell)
	return path.size() == 2

# =============================================================================
# Flow Field (for group movement)
# =============================================================================

## Generate a flow field towards a target cell. Returns a dictionary mapping
## each walkable cell to a normalized direction Vector2.
func generate_flow_field(target: Vector2i) -> Dictionary:
	if not _initialized:
		return {}

	# Check cache.
	if _flow_field_target == target and not _flow_field_cache.is_empty():
		return _flow_field_cache

	var flow: Dictionary = {}
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [target]
	visited[target] = true
	flow[target] = Vector2.ZERO

	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	if allow_diagonal:
		directions.append_array([
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
		])

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_world: Vector2 = _cell_to_world(current)

		for dir: Vector2i in directions:
			var neighbor: Vector2i = current + dir
			if not _is_in_bounds(neighbor):
				continue
			if visited.has(neighbor):
				continue
			if not _is_walkable_cell(neighbor):
				continue

			visited[neighbor] = true
			var neighbor_world: Vector2 = _cell_to_world(neighbor)
			var to_target: Vector2 = (current_world - neighbor_world).normalized()
			flow[neighbor] = to_target
			queue.append(neighbor)

	_flow_field_cache = flow
	_flow_field_target = target
	return flow


## Get movement direction from a flow field for a given position.
func get_flow_direction(flow_field: Dictionary, cell: Vector2i) -> Vector2:
	return flow_field.get(cell, Vector2.ZERO)

# =============================================================================
# Utility
# =============================================================================

func get_furthest_walkable(from: Vector2i, to: Vector2i, max_distance: int = -1) -> Vector2i:
	if max_distance <= 0:
		max_distance = _grid_size.x + _grid_size.y

	var direction: Vector2 = Vector2(to - from)
	var dist: float = direction.length()
	if dist <= 0.0:
		return from if _is_walkable_cell(from) else Vector2i(-1, -1)

	var dir_normalized: Vector2 = direction / dist
	var best: Vector2i = from
	var best_dist: float = 0.0

	var steps: int = mini(ceili(dist), max_distance)
	for i in range(1, steps + 1):
		var candidate: Vector2i = Vector2i(
			floori(float(from.x) + dir_normalized.x * float(i)),
			floori(float(from.y) + dir_normalized.y * float(i))
		)
		if not _is_in_bounds(candidate):
			break
		if not _is_walkable_cell(candidate):
			break
		best = candidate
		best_dist = float(i)

	return best


func estimate_cost(from_cell: Vector2i, to_cell: Vector2i) -> float:
	if not _initialized:
		return 0.0
	return _astar.get_point_position(from_cell).distance_to(
		_astar.get_point_position(to_cell)
	)

# =============================================================================
# Temporary Block / Unblock
# =============================================================================

func temporarily_block(cell: Vector2i) -> void:
	if not _is_in_bounds(cell):
		return
	_temporarily_blocked[cell] = true
	if _initialized:
		_astar.set_point_solid(cell, true)
	invalidate_cache_near(cell)


func unblock(cell: Vector2i) -> void:
	_temporarily_blocked.erase(cell)
	if _initialized and _is_in_bounds(cell):
		if _grid_manager != null and _grid_manager.is_walkable(cell):
			_astar.set_point_solid(cell, false)
	invalidate_cache_near(cell)


func clear_temporary_blocks() -> void:
	_temporarily_blocked.clear()
	if _initialized:
		rebuild()

# =============================================================================
# Cache Management
# =============================================================================

func _make_cache_key(start: Vector2i, end: Vector2i) -> String:
	return "%d,%d->%d,%d" % [start.x, start.y, end.x, end.y]


func _store_in_cache(key: String, path: Array[Vector2i]) -> void:
	# Evict LRU if at capacity.
	while _cache_order.size() >= max_cache_size:
		var oldest: String = _cache_order.pop_front()
		_path_cache.erase(oldest)

	_path_cache[key] = {
		"path": path.duplicate(),
		"age": _frame_count,
		"hits": 0,
	}
	_cache_order.append(key)


func _touch_cache(key: String) -> void:
	var idx: int = _cache_order.find(key)
	if idx >= 0:
		_cache_order.remove_at(idx)
	_cache_order.append(key)


func _evict_stale_cache() -> void:
	var to_remove: Array[String] = []
	for key: String in _cache_order:
		var entry: Dictionary = _path_cache.get(key, {})
		var age: int = entry.get("age", 0)
		if _frame_count - age > cache_max_age:
			to_remove.append(key)

	for key: String in to_remove:
		_path_cache.erase(key)
		var idx: int = _cache_order.find(key)
		if idx >= 0:
			_cache_order.remove_at(idx)


## Invalidate all cached paths. Called on grid rebuild.
func invalidate_cache() -> void:
	_path_cache.clear()
	_cache_order.clear()
	_flow_field_cache.clear()
	_flow_field_target = Vector2i(-1, -1)
	cache_invalidated.emit()


## Invalidate cached paths that pass through a specific cell.
func invalidate_cache_near(cell: Vector2i) -> void:
	var to_remove: Array[String] = []
	for key: String in _cache_order:
		var entry: Dictionary = _path_cache.get(key, {})
		var path: Array = entry.get("path", [])
		for point: Vector2i in path:
			if absi(point.x - cell.x) <= 1 and absi(point.y - cell.y) <= 1:
				to_remove.append(key)
				break

	for key: String in to_remove:
		_path_cache.erase(key)
		var idx: int = _cache_order.find(key)
		if idx >= 0:
			_cache_order.remove_at(idx)


## Get cache statistics.
func get_cache_stats() -> Dictionary:
	return {
		"cache_size": _path_cache.size(),
		"max_cache_size": max_cache_size,
		"flow_field_cached": not _flow_field_cache.is_empty(),
		"flow_field_target": _flow_field_target,
	}

# =============================================================================
# Coordinate Conversion
# =============================================================================

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / float(_cell_size.x)),
		floori(world_pos.y / float(_cell_size.y))
	)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * _cell_size.x + _cell_size.x * 0.5,
		cell.y * _cell_size.y + _cell_size.y * 0.5
	)


func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _grid_size.x and cell.y >= 0 and cell.y < _grid_size.y


func _is_walkable_cell(cell: Vector2i) -> bool:
	if _grid_manager == null:
		return false
	return _grid_manager.is_walkable(cell)

# =============================================================================
# Nearest Walkable
# =============================================================================

func _get_nearest_walkable(cell: Vector2i, search_radius: int = 10) -> Vector2i:
	if _is_walkable_cell(cell):
		return cell

	for r in range(1, search_radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var candidate: Vector2i = cell + Vector2i(dx, dy)
				if _is_in_bounds(candidate) and _is_walkable_cell(candidate):
					return candidate

	return Vector2i(-1, -1)

# =============================================================================
# Scene Tree Helpers
# =============================================================================

func _find_grid_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_grid_manager_recursive(scene)


func _find_grid_manager_recursive(node: Node) -> Node:
	if node.name == "GridManager" or (node.has_method("is_walkable") and node.has_method("is_buildable")):
		return node
	for child: Node in node.get_children():
		var result: Node = _find_grid_manager_recursive(child)
		if result != null:
			return result
	return null

# =============================================================================
# Callbacks
# =============================================================================

func _on_grid_changed() -> void:
	rebuild()
