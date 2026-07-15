## Manages the tile grid for walkability, building placement, and coordinate conversion.
##
## GridManager maintains a 2D array matching the TileMap cell size (32x32).
## It tracks which cells are walkable, which are occupied by buildings, and
## provides utility functions for neighbors, radius queries, and conversion
## between grid coordinates and world coordinates.
class_name GridManager
extends Node

# =============================================================================
# Configuration
# =============================================================================

## Size of each grid cell in pixels (must match TileMap cell_size).
@export var cell_size: Vector2i = Vector2i(32, 32)

## Total grid dimensions in cells (width x height).
@export var grid_dimensions: Vector2i = Vector2i(128, 128)

# =============================================================================
# Signals
# =============================================================================

## Emitted when the walkability or occupancy of any cell changes.
signal grid_changed()

## Emitted when a building is placed on the grid.
signal building_placed_on_grid(cell: Vector2i, building_type: String, building_id: String)

## Emitted when a building is removed from the grid.
signal building_removed_from_grid(cell: Vector2i, building_type: String)

# =============================================================================
# Constants — Cell States
# =============================================================================

## Walkability states stored in the walkability grid.
const WALKABLE: int = 0
const BLOCKED_WATER: int = 1
const BLOCKED_MOUNTAIN: int = 2
const BLOCKED_BUILDING: int = 3
const BLOCKED_DYNAMIC: int = 4

# =============================================================================
# Internal Data
# =============================================================================

## 2D array: walkability[y][x]. Values are WALKABLE or BLOCKED_* constants.
## Positive values indicate the cell is blocked (value = blocker type ID).
var _walkability: Array[PackedInt32Array] = []

## 2D array: building occupancy[y][x]. Empty string = no building, otherwise
## the building's unique string ID occupies this cell.
var _building_occupancy: Array[PackedStringArray] = []

## Mapping of building_id -> { "cell": Vector2i, "size": Vector2i, "type": String }
## Tracks every placed building for quick lookup.
var _placed_buildings: Dictionary = {}

## Whether the grid has been initialized.
var _initialized: bool = false

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_initialize_grid()


func _initialize_grid() -> void:
	_walkability.resize(grid_dimensions.y)
	_building_occupancy.resize(grid_dimensions.y)
	for y in range(grid_dimensions.y):
		var walk_row: PackedInt32Array = PackedInt32Array()
		walk_row.resize(grid_dimensions.x)
		walk_row.fill(WALKABLE)
		_walkability[y] = walk_row

		var occ_row: PackedStringArray = PackedStringArray()
		occ_row.resize(grid_dimensions.x)
		occ_row.fill("")
		_building_occupancy[y] = occ_row

	_initialized = true

	# Try to load walkability data from a TileMap if present.
	_scan_tilemap_walkability()

# =============================================================================
# Coordinate Conversion
# =============================================================================

## Convert a world-space position to grid cell coordinates.
func get_cell_from_world(world_pos: Vector2) -> Vector2i:
	var cell_x: int = floori(world_pos.x / cell_size.x)
	var cell_y: int = floori(world_pos.y / cell_size.y)
	return Vector2i(cell_x, cell_y)


## Convert grid cell coordinates to the world-space center of that cell.
func get_world_pos_from_cell(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * cell_size.x + cell_size.x * 0.5,
		cell.y * cell_size.y + cell_size.y * 0.5
	)


## Convert grid cell coordinates to the world-space top-left corner of that cell.
func get_world_pos_from_cell_top_left(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size.x, cell.y * cell_size.y)


## Check whether grid coordinates are within the valid grid bounds.
func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_dimensions.x and cell.y >= 0 and cell.y < grid_dimensions.y

# =============================================================================
# Walkability
# =============================================================================

## Check if a cell is walkable (not blocked by terrain or buildings).
func is_walkable(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	return _walkability[cell.y][cell.x] == WALKABLE


## Get the blocker type at a cell. Returns WALKABLE if the cell is free.
func get_blocker(cell: Vector2i) -> int:
	if not is_in_bounds(cell):
		return BLOCKED_MOUNTAIN  # Out-of-bounds treated as impassable.
	return _walkability[cell.y][cell.x]


## Set a cell's walkability state.
func set_cell_walkable(cell: Vector2i, blocker_type: int) -> void:
	if not is_in_bounds(cell):
		return
	_walkability[cell.y][cell.x] = blocker_type
	grid_changed.emit()


## Mark a single cell as blocked with a specific blocker type.
func block_cell(cell: Vector2i, blocker_type: int = BLOCKED_DYNAMIC) -> void:
	if not is_in_bounds(cell):
		return
	_walkability[cell.y][cell.x] = blocker_type
	grid_changed.emit()


## Mark a single cell as walkable again.
func unblock_cell(cell: Vector2i) -> void:
	if not is_in_bounds(cell):
		return
	_walkability[cell.y][cell.x] = WALKABLE
	grid_changed.emit()

# =============================================================================
# Building Placement
# =============================================================================

## Check if a building of the given size can be placed at cell.
## The building footprint spans [cell, cell + building_size - (1,1)].
## All cells in the footprint must be walkable and in bounds.
func is_buildable(cell: Vector2i, building_size: Vector2i) -> bool:
	for dy in range(building_size.y):
		for dx in range(building_size.x):
			var check: Vector2i = cell + Vector2i(dx, dy)
			if not is_in_bounds(check):
				return false
			if _walkability[check.y][check.x] != WALKABLE:
				return false
			if _building_occupancy[check.y][check.x] != "":
				return false
	return true


## Place a building on the grid, blocking all cells in its footprint.
## [param cell: Vector2i] Top-left grid cell of the building.
## [param building_size: Vector2i] Footprint in cells.
## [param building_type: String] The type of building (e.g. "town_center").
## [param building_id: String] A unique string ID for this building instance.
## [return] true if placement succeeded.
func place_building(cell: Vector2i, building_size: Vector2i, building_type: String, building_id: String = "") -> bool:
	if not is_buildable(cell, building_size):
		return false

	if building_id.is_empty():
		building_id = "%s_%d_%d" % [building_type, cell.x, cell.y]

	for dy in range(building_size.y):
		for dx in range(building_size.x):
			var target: Vector2i = cell + Vector2i(dx, dy)
			_walkability[target.y][target.x] = BLOCKED_BUILDING
			_building_occupancy[target.y][target.x] = building_id

	_placed_buildings[building_id] = {
		"cell": cell,
		"size": building_size,
		"type": building_type,
	}

	building_placed_on_grid.emit(cell, building_type, building_id)
	grid_changed.emit()
	return true


## Remove a building from the grid, freeing all cells in its footprint.
## [param cell: Vector2i] Any cell within the building's footprint.
func remove_building_at(cell: Vector2i) -> void:
	if not is_in_bounds(cell):
		return

	var building_id: String = _building_occupancy[cell.y][cell.x]
	if building_id.is_empty():
		return

	_remove_building_by_id(building_id)


## Remove a building by its unique ID, freeing all occupied cells.
func remove_building_by_id(building_id: String) -> void:
	if not _placed_buildings.has(building_id):
		return
	_remove_building_by_id(building_id)


## Internal helper to remove a building and free its cells.
func _remove_building_by_id(building_id: String) -> void:
	var info: Dictionary = _placed_buildings[building_id]
	var cell: Vector2i = info["cell"]
	var size: Vector2i = info["size"]
	var btype: String = info["type"]

	for dy in range(size.y):
		for dx in range(size.x):
			var target: Vector2i = cell + Vector2i(dx, dy)
			if is_in_bounds(target):
				_walkability[target.y][target.x] = WALKABLE
				_building_occupancy[target.y][target.x] = ""

	_placed_buildings.erase(building_id)
	building_removed_from_grid.emit(cell, btype)
	grid_changed.emit()


## Get the building ID at a given cell, or empty string if none.
func get_building_at(cell: Vector2i) -> String:
	if not is_in_bounds(cell):
		return ""
	return _building_occupancy[cell.y][cell.x]


## Get all placed buildings as a dictionary of { building_id: info }.
func get_all_buildings() -> Dictionary:
	return _placed_buildings.duplicate(true)


## Get info about a specific building by ID.
func get_building_info(building_id: String) -> Dictionary:
	return _placed_buildings.get(building_id, {})

# =============================================================================
# Neighbor & Radius Queries
# =============================================================================

## Get all valid neighboring cells (4-directional: up, down, left, right).
func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(1, 0),
	]
	for dir: Vector2i in directions:
		var neighbor: Vector2i = cell + dir
		if is_in_bounds(neighbor):
			result.append(neighbor)
	return result


## Get all valid neighboring cells including diagonals (8-directional).
func get_neighbors_diagonal(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var neighbor: Vector2i = cell + Vector2i(dx, dy)
			if is_in_bounds(neighbor):
				result.append(neighbor)
	return result


## Get all walkable neighbors (4-directional).
func get_walkable_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for neighbor: Vector2i in get_neighbors(cell):
		if is_walkable(neighbor):
			result.append(neighbor)
	return result


## Get all walkable neighbors including diagonals (8-directional).
func get_walkable_neighbors_diagonal(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for neighbor: Vector2i in get_neighbors_diagonal(cell):
		if is_walkable(neighbor):
			result.append(neighbor)
	return result


## Get all cells within a given radius (in grid cells) of a center cell.
## Uses Manhattan distance for a diamond shape; for circle, use Euclidean.
func get_cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if absi(dx) + absi(dy) <= radius:
				var cell: Vector2i = center + Vector2i(dx, dy)
				if is_in_bounds(cell):
					result.append(cell)
	return result


## Get all cells within a Euclidean radius of a center cell (circular).
func get_cells_in_circle(center: Vector2i, radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var r_ceil: int = ceili(radius)
	for dy in range(-r_ceil, r_ceil + 1):
		for dx in range(-r_ceil, r_ceil + 1):
			if Vector2(dx, dy).length() <= radius:
				var cell: Vector2i = center + Vector2i(dx, dy)
				if is_in_bounds(cell):
					result.append(cell)
	return result


## Get all walkable cells within a radius.
func get_walkable_cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in get_cells_in_radius(center, radius):
		if is_walkable(cell):
			result.append(cell)
	return result

# =============================================================================
# Tilemap Scanning
# =============================================================================

## Scan the scene tree for a TileMap node and mark non-walkable cells
## based on terrain tile data. Looks for custom data layers named
## "walkable" (bool) or infers from tile names containing "water"/"mountain".
func _scan_tilemap_walkability() -> void:
	var tilemap: TileMap = _find_tilemap()
	if tilemap == null:
		return

	var used_cells: Array[Vector2i] = tilemap.get_used_cells(0)
	for cell: Vector2i in used_cells:
		# Check custom data layer "walkable" if it exists.
		var walkable_data: Variant = tilemap.get_cell_tile_data(0, cell).get_custom_data("walkable") if tilemap.get_cell_tile_data(0, cell) != null else null
		if walkable_data is bool:
			if not walkable_data:
				_walkability[cell.y][cell.x] = BLOCKED_WATER  # Generic blocked terrain.
			continue

		# Fallback: check atlas coords to guess terrain type.
		# This is a heuristic — real maps should use custom data layers.
		var source_id: int = tilemap.get_cell_source_id(0, cell)
		if source_id == -1:
			continue
		# Atlas coords (1,0) commonly = water in standard tilesets; adjust as needed.
		var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(0, cell)
		if atlas_coords.y == 0 and atlas_coords.x >= 2:
			_walkability[cell.y][cell.x] = BLOCKED_WATER
		elif atlas_coords.y == 1:
			_walkability[cell.y][cell.x] = BLOCKED_MOUNTAIN


## Recursively find the first TileMap node in the scene tree.
func _find_tilemap() -> TileMap:
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _find_tilemap_recursive(root)


func _find_tilemap_recursive(node: Node) -> TileMap:
	if node is TileMap:
		return node as TileMap
	for child: Node in node.get_children():
		if child is TileMap:
			return child as TileMap
	for child: Node in node.get_children():
		var result: TileMap = _find_tilemap_recursive(child)
		if result != null:
			return result
	return null

# =============================================================================
# Full Rebuild
# =============================================================================

## Completely rebuild walkability from scratch. Call after major map changes.
## Preserves building occupancy — buildings remain blocked.
func rebuild_walkability() -> void:
	# Clear terrain blockers (keep buildings).
	for y in range(grid_dimensions.y):
		for x in range(grid_dimensions.x):
			if _walkability[y][x] != BLOCKED_BUILDING:
				_walkability[y][x] = WALKABLE

	# Re-scan tilemap terrain.
	_scan_tilemap_walkability()
	grid_changed.emit()


## Get the total number of walkable cells in the grid.
func get_walkable_count() -> int:
	var count: int = 0
	for y in range(grid_dimensions.y):
		for x in range(grid_dimensions.x):
			if _walkability[y][x] == WALKABLE:
				count += 1
	return count


## Get a random walkable cell on the map. Returns Vector2i(-1, -1) if none found.
func get_random_walkable_cell() -> Vector2i:
	# Try a few random positions; fall back to full scan.
	for _i in range(100):
		var cell: Vector2i = Vector2i(
			randi_range(0, grid_dimensions.x - 1),
			randi_range(0, grid_dimensions.y - 1)
		)
		if is_walkable(cell):
			return cell

	# Full scan fallback.
	for y in range(grid_dimensions.y):
		for x in range(grid_dimensions.x):
			if _walkability[y][x] == WALKABLE:
				return Vector2i(x, y)

	return Vector2i(-1, -1)
