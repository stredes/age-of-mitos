## AStarGrid2D-based pathfinder for grid-aligned unit movement.
##
## Wraps Godot's AStarGrid2D to provide pathfinding that stays in sync with
## the GridManager's walkability data. Supports dynamic obstacle updates,
## finding the furthest walkable cell along a direction, and converting
## between grid cells and world positions.
class_name Pathfinder
extends Node

# =============================================================================
# Configuration
# =============================================================================

## Heuristic used by AStarGrid2D. MANHATTAN is fastest for 4-directional grids.
@export var heuristic: AStarGrid2D.Heuristic = AStarGrid2D.HEURISTIC_MANHATTAN

## Allow diagonal movement in paths.
@export var allow_diagonal: bool = false

## Penalty added to cells that are adjacent to blocked cells, encouraging
## paths to stay away from walls (useful for larger units).
@export var adjacent_wall_penalty: float = 0.0

# =============================================================================
# Signals
# =============================================================================

## Emitted when the pathfinder recalculates its walkability data.
signal pathfinder_rebuilt()

# =============================================================================
# Internal State
# =============================================================================

## The AStarGrid2D instance used for pathfinding.
var _astar: AStarGrid2D = null

## Reference to the GridManager for walkability data.
var _grid_manager: Node = null

## Grid dimensions cached from GridManager.
var _grid_size: Vector2i = Vector2i.ZERO

## Cell size cached from GridManager.
var _cell_size: Vector2i = Vector2i(32, 32)

## Whether the pathfinder has been initialized.
var _initialized: bool = false

## Set of cells temporarily blocked for unit collision avoidance.
## Key: Vector2i, Value: true. These are cleared on rebuild.
var _temporarily_blocked: Dictionary = {}

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_astar = AStarGrid2D.new()
	# Defer initialization to allow the scene tree to settle.
	call_deferred("_initialize")


## Initialize the pathfinder by finding the GridManager and building the grid.
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

	# Listen for grid changes to rebuild pathfinding data.
	if _grid_manager.has_signal("grid_changed"):
		_grid_manager.grid_changed.connect(_on_grid_changed)

	pathfinder_rebuilt.emit()

# =============================================================================
# Grid Building
# =============================================================================

## Mark all non-walkable cells in the AStarGrid2D as solid.
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


## Apply movement cost penalties to walkable cells adjacent to walls.
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


## Rebuild the entire AStarGrid2D from current GridManager walkability.
## Called when the grid changes (building placed/destroyed, terrain edited).
func rebuild() -> void:
	if _grid_manager == null:
		return
	_grid_size = _grid_manager.grid_dimensions
	_cell_size = _grid_manager.cell_size
	_astar.region = Rect2i(Vector2i.ZERO, Vector2i(_grid_size.x, _grid_size.y))
	_astar.cell_size = Vector2(_cell_size.x, _cell_size.y)
	_astar.update()

	_mark_walkable_cells()

	# Re-apply temporary blocks.
	for cell: Vector2i in _temporarily_blocked:
		if _is_in_bounds(cell):
			_astar.set_point_solid(cell, true)

	_initialized = true
	pathfinder_rebuilt.emit()


## Refresh the pathfinder incrementally — only update cells that changed.
## Faster than a full rebuild for small changes (single building placed).
func refresh_cell(cell: Vector2i) -> void:
	if not _initialized or _grid_manager == null:
		return
	if not _is_in_bounds(cell):
		return
	var is_solid: bool = not _grid_manager.is_walkable(cell) or _temporarily_blocked.has(cell)
	_astar.set_point_solid(cell, is_solid)

# =============================================================================
# Pathfinding
# =============================================================================

## Find a path between two grid cells. Returns an Array of Vector2i.
## Returns an empty array if no path exists.
func find_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if not _initialized:
		push_warning("Pathfinder: Not initialized.")
		return []

	if not _is_in_bounds(start_cell) or not _is_in_bounds(end_cell):
		return []

	# If start or end is solid, try to find the nearest walkable cell.
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
	return result


## Find a path and return world-space positions (cell centers).
func find_path_world(start_pos: Vector2, end_pos: Vector2) -> Array[Vector2]:
	var start_cell: Vector2i = _world_to_cell(start_pos)
	var end_cell: Vector2i = _world_to_cell(end_pos)
	var cell_path: Array[Vector2i] = find_path(start_cell, end_cell)
	var world_path: Array[Vector2] = []
	for cell: Vector2i in cell_path:
		world_path.append(_cell_to_world(cell))
	return world_path


## Find a path but return only world positions for movement (skips start cell
## since the unit is already there).
func find_path_for_movement(start_pos: Vector2, end_pos: Vector2) -> Array[Vector2]:
	var world_path: Array[Vector2] = find_path_world(start_pos, end_pos)
	if world_path.size() > 0:
		world_path.pop_front()  # Remove the start position (unit is already there).
	return world_path

# =============================================================================
# Path Validation
# =============================================================================

## Check whether a path is valid (non-empty and all points are walkable).
func is_valid_path(path: Array[Vector2i]) -> bool:
	if path.is_empty():
		return false
	for cell: Vector2i in path:
		if not _is_in_bounds(cell):
			return false
		if _astar.is_point_solid(cell):
			return false
	return true


## Check whether a direct path (no intermediate points) exists between two cells.
func has_direct_path(start_cell: Vector2i, end_cell: Vector2i) -> bool:
	var path: Array[Vector2i] = find_path(start_cell, end_cell)
	return path.size() == 2  # Start + End only = straight line.

# =============================================================================
# Utility
# =============================================================================

## Find the furthest walkable cell in the direction from `from` to `to`,
## up to max_distance cells. Useful for when a unit can't reach its exact
## destination but should move as close as possible.
func get_furthest_walkable(from: Vector2i, to: Vector2i, max_distance: int = -1) -> Vector2i:
	if max_distance <= 0:
		max_distance = _grid_size.x + _grid_size.y  # Effectively unlimited.

	var direction: Vector2 = Vector2(to - from)
	var dist: float = direction.length()
	if dist <= 0.0:
		return from if _is_walkable_cell(from) else Vector2i(-1, -1)

	var dir_normalized: Vector2 = direction / dist
	var best: Vector2i = from
	var best_dist: float = 0.0

	# Step along the direction in fractional cell increments.
	var steps: int = mini(ceili(dist), max_distance)
	for i in range(1, steps + 1):
		var frac: float = float(i) / dist
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


## Find the nearest walkable cell to a given cell within a search radius.
func _get_nearest_walkable(cell: Vector2i, search_radius: int = 10) -> Vector2i:
	if _is_walkable_cell(cell):
		return cell

	for r in range(1, search_radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue  # Only check the perimeter of each radius.
				var candidate: Vector2i = cell + Vector2i(dx, dy)
				if _is_in_bounds(candidate) and _is_walkable_cell(candidate):
					return candidate

	return Vector2i(-1, -1)


## Get the estimated cost of a path between two cells (heuristic only, no actual pathfinding).
func estimate_cost(from_cell: Vector2i, to_cell: Vector2i) -> float:
	if not _initialized:
		return 0.0
	return _astar.get_point_position(from_cell).distance_to(
		_astar.get_point_position(to_cell)
	)

# =============================================================================
# Temporary Block / Unblock (Unit Collision)
# =============================================================================

## Temporarily block a cell for unit collision avoidance. The cell will be
## treated as solid until unblocked. These blocks are cleared on rebuild.
func temporarily_block(cell: Vector2i) -> void:
	if not _is_in_bounds(cell):
		return
	_temporarily_blocked[cell] = true
	if _initialized:
		_astar.set_point_solid(cell, true)


## Remove a temporary block from a cell.
func unblock(cell: Vector2i) -> void:
	_temporarily_blocked.erase(cell)
	if _initialized and _is_in_bounds(cell):
		# Only unblock if the cell is actually walkable in the grid.
		if _grid_manager != null and _grid_manager.is_walkable(cell):
			_astar.set_point_solid(cell, false)


## Clear all temporary blocks.
func clear_temporary_blocks() -> void:
	_temporarily_blocked.clear()
	if _initialized:
		# Rebuild to restore correct solid state.
		rebuild()

# =============================================================================
# Coordinate Conversion
# =============================================================================

## Convert a world position to grid cell coordinates.
func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / float(_cell_size.x)),
		floori(world_pos.y / float(_cell_size.y))
	)


## Convert a grid cell to the world-space center of that cell.
func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * _cell_size.x + _cell_size.x * 0.5,
		cell.y * _cell_size.y + _cell_size.y * 0.5
	)


## Check if grid coordinates are within bounds.
func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _grid_size.x and cell.y >= 0 and cell.y < _grid_size.y


## Check if a cell is walkable via the GridManager.
func _is_walkable_cell(cell: Vector2i) -> bool:
	if _grid_manager == null:
		return false
	return _grid_manager.is_walkable(cell)

# =============================================================================
# Scene Tree Helpers
# =============================================================================

## Recursively search the scene tree for a GridManager node.
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

## Called when GridManager emits grid_changed. Rebuilds pathfinding data.
func _on_grid_changed() -> void:
	rebuild()
