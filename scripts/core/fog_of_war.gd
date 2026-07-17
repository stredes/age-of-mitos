## Fog of war system using Image-based rendering for efficient per-cell updates.
##
## Maintains a per-player 2D byte array with three visibility states:
## UNDISCOVERED (0), EXPLORED (1), VISIBLE (2). Renders fog as a semi-transparent
## overlay on a CanvasLayer above the world. Only updates cells near unit sight
## ranges for performance.
class_name FogOfWar
extends Node2D

# =============================================================================
# Constants
# =============================================================================

const UNDISCOVERED: int = 0
const EXPLORED: int = 1
const VISIBLE: int = 2

## Fog colors mapped to visibility states.
const COLOR_UNDISCOVERED: Color = Color(0.0, 0.0, 0.0, 1.0)
const COLOR_EXPLORED: Color = Color(0.0, 0.0, 0.0, 0.55)
const COLOR_VISIBLE: Color = Color(0.0, 0.0, 0.0, 0.0)

## Edge blend color for smoother transitions at visibility boundaries.
const COLOR_EDGE: Color = Color(0.0, 0.0, 0.0, 0.28)

## Default sight range in grid cells for units without explicit range.
const DEFAULT_SIGHT_RANGE: int = 6

## Number of edge cells to blend for smooth transitions.
const EDGE_BLEND_WIDTH: int = 2

## Speed of smooth reveal/explore transitions (alpha per second).
const TRANSITION_SPEED: float = 4.0

# =============================================================================
# Configuration
# =============================================================================

## Grid dimensions in cells (must match GridManager).
@export var grid_size: Vector2i = Vector2i(128, 128)

## Size of each cell in pixels (must match GridManager/TileMap).
@export var cell_pixel_size: Vector2i = Vector2i(32, 32)

## Which player's fog to render locally (the local human player).
@export var local_player_id: int = 1

## Whether to enable edge blending for smoother visibility transitions.
@export var enable_edge_blending: bool = true

# =============================================================================
# Signals
# =============================================================================

## Emitted when a cell's visibility changes for the local player.
signal fog_visibility_changed(cell: Vector2i, new_state: int)

## Emitted when a previously undiscovered area is first revealed.
signal area_first_revealed(center: Vector2i, radius: int)

# =============================================================================
# Internal Data
# =============================================================================

## Per-player fog arrays. Keys are player_id (int).
## Each value is a PackedByteArray of length (grid_size.x * grid_size.y).
## Stored in row-major order: index = y * grid_size.x + x
var _fog_data: Dictionary = {}

## Per-cell transition alpha (0.0 = fully fogged, 1.0 = fully revealed).
## Used for smooth fading between EXPLORED and VISIBLE states.
var _transition_alpha: PackedFloat32Array = PackedFloat32Array()

## The Image used to render fog. One pixel per grid cell.
var _fog_image: Image = null

## The ImageTexture displayed by this Node2D.
var _fog_texture: ImageTexture = null

## Tracks which cells were modified this frame for batched updates.
var _dirty_cells: Dictionary = {}

## Whether the fog image needs a full re-render.
var _needs_full_redraw: bool = true

## The Rect2 in world space that covers the entire fog area.
var _world_rect: Rect2 = Rect2()

## Reference to GridManager for coordinate queries.
var _grid_manager: Node = null

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_world_rect = Rect2(
		Vector2.ZERO,
		Vector2(grid_size.x * cell_pixel_size.x, grid_size.y * cell_pixel_size.y)
	)
	_initialize_fog_image()

	# Attempt to find GridManager in the scene tree.
	_grid_manager = _find_grid_manager()

	# Listen for grid changes to sync fog dimensions.
	EventBus.game_started.connect(_on_game_started)


func _process(delta: float) -> void:
	# Update transition alpha for smooth reveals.
	var total: int = grid_size.x * grid_size.y
	for i in range(total):
		var target_alpha: float = 0.0
		var fog: PackedByteArray = _fog_data.get(local_player_id, PackedByteArray())
		if fog.size() > i:
			match fog[i]:
				VISIBLE:
					target_alpha = 1.0
				EXPLORED:
					target_alpha = 0.5
				_:
					target_alpha = 0.0
		var current: float = _transition_alpha[i]
		if not is_equal_approx(current, target_alpha):
			_transition_alpha[i] = move_toward(current, target_alpha, TRANSITION_SPEED * delta)
			var x: int = i % grid_size.x
			var y: int = i / grid_size.x
			_dirty_cells[Vector2i(x, y)] = true

	if _needs_full_redraw:
		_full_redraw()
		_needs_full_redraw = false
	elif _dirty_cells.size() > 0:
		_flush_dirty_cells()

	queue_redraw()

# =============================================================================
# Initialization
# =============================================================================

## Create the fog Image and texture at the correct resolution.
func _initialize_fog_image() -> void:
	# Image dimensions: one pixel per grid cell.
	_fog_image = Image.create(grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8)
	_fog_image.fill(COLOR_UNDISCOVERED)
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	_world_rect = Rect2(
		Vector2.ZERO,
		Vector2(grid_size.x * cell_pixel_size.x, grid_size.y * cell_pixel_size.y)
	)
	# Initialize transition alpha map (all cells start fully fogged).
	var total: int = grid_size.x * grid_size.y
	_transition_alpha.resize(total)
	_transition_alpha.fill(0.0)


## Initialize fog data for a specific player.
func _ensure_player_fog(player_id: int) -> void:
	if not _fog_data.has(player_id):
		var data: PackedByteArray = PackedByteArray()
		data.resize(grid_size.x * grid_size.y)
		data.fill(UNDISCOVERED)
		_fog_data[player_id] = data


## Find the GridManager node in the scene.
func _find_grid_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("GridManager")

# =============================================================================
# Drawing
# =============================================================================

## Draw the fog texture covering the entire map.
func _draw() -> void:
	if _fog_texture == null:
		return
	draw_texture_rect(_fog_texture, _world_rect, false)

# =============================================================================
# Visibility Queries
# =============================================================================

## Check if a cell is visible to a specific player.
func is_cell_visible(cell: Vector2i, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = local_player_id
	var state: int = _get_cell_state(cell, player_id)
	return state == VISIBLE


## Check if a cell has been explored (previously visible) by a player.
func is_explored(cell: Vector2i, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = local_player_id
	var state: int = _get_cell_state(cell, player_id)
	return state == EXPLORED


## Check if a cell is undiscovered by a player.
func is_undiscovered(cell: Vector2i, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = local_player_id
	var state: int = _get_cell_state(cell, player_id)
	return state == UNDISCOVERED


## Get the visibility state of a cell (UNDISCOVERED, EXPLORED, VISIBLE).
func get_visibility(cell: Vector2i, player_id: int = -1) -> int:
	if player_id == -1:
		player_id = local_player_id
	return _get_cell_state(cell, player_id)

# =============================================================================
# Visibility Updates
# =============================================================================

## Update fog visibility based on current unit and building positions.
## Call this each frame (batched) from the game loop.
## [param unit_positions: Array[Vector2i] - grid cells where player units are.
## [param building_positions: Array[Vector2i] - grid cells with player buildings.
## [param sight_ranges: Dictionary - optional per-position sight ranges.
func update_visibility(unit_positions: Array[Vector2i], building_positions: Array[Vector2i] = [], sight_ranges: Dictionary = {}) -> void:
	# Step 1: Mark all currently VISIBLE cells as EXPLORED.
	_reset_to_explored()

	# Step 2: Reveal areas around all units and buildings.
	for cell: Vector2i in unit_positions:
		var range_val: int = sight_ranges.get(cell, DEFAULT_SIGHT_RANGE)
		reveal_area(cell, range_val)

	for cell: Vector2i in building_positions:
		# Buildings typically have a larger sight range.
		var range_val: int = sight_ranges.get(cell, DEFAULT_SIGHT_RANGE + 2)
		reveal_area(cell, range_val)


## Reveal all cells within a radius of a center cell.
func reveal_area(center: Vector2i, radius: int) -> void:
	var radius_sq: float = float(radius * radius)
	var blend_sq: float = float((radius + EDGE_BLEND_WIDTH) * (radius + EDGE_BLEND_WIDTH))
	for dy in range(-radius - EDGE_BLEND_WIDTH, radius + EDGE_BLEND_WIDTH + 1):
		for dx in range(-radius - EDGE_BLEND_WIDTH, radius + EDGE_BLEND_WIDTH + 1):
			var cell: Vector2i = center + Vector2i(dx, dy)
			if not _is_in_bounds(cell):
				continue

			var dist_sq: float = float(dx * dx + dy * dy)

			if dist_sq <= radius_sq:
				# Inside main radius — fully visible.
				_set_cell_state(cell, VISIBLE)
			elif enable_edge_blending and dist_sq <= blend_sq:
				# Edge zone — only upgrade, never downgrade within edge.
				var current: int = _get_cell_state(cell, local_player_id)
				if current != VISIBLE:
					_set_cell_state(cell, EXPLORED)
			else:
				# Outer edge — smooth blend toward fog.
				var current: int = _get_cell_state(cell, local_player_id)
				if current == VISIBLE:
					# Cells just outside vision — mark as explored for smooth transition.
					_set_cell_state(cell, EXPLORED)

	# Mark the image as needing an update for the affected region.
	_needs_full_redraw = true


## Immediately reveal a single cell (always sets to VISIBLE).
func reveal_cell(cell: Vector2i, player_id: int = -1) -> void:
	if player_id == -1:
		player_id = local_player_id
	_ensure_player_fog(player_id)
	var old_state: int = _get_cell_state(cell, player_id)
	if old_state != VISIBLE:
		_set_cell_state(cell, VISIBLE, player_id)
		_needs_full_redraw = true
		fog_visibility_changed.emit(cell, VISIBLE)

# =============================================================================
# Fog State Transitions
# =============================================================================

## Set all VISIBLE cells back to EXPLORED. Called at the start of each
## visibility update cycle before re-revealing from unit positions.
func _reset_to_explored() -> void:
	var player_id: int = local_player_id
	_ensure_player_fog(player_id)
	var fog: PackedByteArray = _fog_data[player_id]
	var total: int = grid_size.x * grid_size.y
	for i in range(total):
		if fog[i] == VISIBLE:
			fog[i] = EXPLORED
	_fog_data[player_id] = fog
	_needs_full_redraw = true


## Public method to reset all visible cells to explored.
func reset_to_explored() -> void:
	_reset_to_explored()

# =============================================================================
# Cell State Access
# =============================================================================

## Get the visibility state of a cell from the fog data array.
func _get_cell_state(cell: Vector2i, player_id: int) -> int:
	if not _is_in_bounds(cell):
		return UNDISCOVERED
	_ensure_player_fog(player_id)
	var fog: PackedByteArray = _fog_data[player_id]
	var idx: int = cell.y * grid_size.x + cell.x
	return fog[idx]


## Set the visibility state of a cell in the fog data array.
func _set_cell_state(cell: Vector2i, state: int, player_id: int = -1) -> void:
	if player_id == -1:
		player_id = local_player_id
	if not _is_in_bounds(cell):
		return
	_ensure_player_fog(player_id)
	var fog: PackedByteArray = _fog_data[player_id]
	var idx: int = cell.y * grid_size.x + cell.x
	var old_state: int = fog[idx]
	fog[idx] = state
	_fog_data[player_id] = fog

	if old_state != state:
		fog_visibility_changed.emit(cell, state)
		if old_state == UNDISCOVERED and state != UNDISCOVERED:
			area_first_revealed.emit(cell, 0)
		EventBus.fog_updated.emit(player_id, Vector2(cell), state)


## Check if coordinates are within grid bounds.
func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y

# =============================================================================
# Image Rendering
# =============================================================================

## Perform a full redraw of the fog image from the fog data array.
func _full_redraw() -> void:
	if _fog_image == null:
		return

	var player_id: int = local_player_id
	_ensure_player_fog(player_id)
	var fog: PackedByteArray = _fog_data[player_id]

	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var idx: int = y * grid_size.x + x
			var state: int = fog[idx]
			var trans_alpha: float = _transition_alpha[idx] if idx < _transition_alpha.size() else 0.0

			var color: Color
			match state:
				UNDISCOVERED:
					color = COLOR_UNDISCOVERED
				EXPLORED:
					# Blend between EXPLORED and VISIBLE using transition alpha.
					var explored_alpha: float = lerp(COLOR_EXPLORED.a, COLOR_VISIBLE.a, trans_alpha)
					color = Color(0.0, 0.0, 0.0, explored_alpha)
				VISIBLE:
					color = COLOR_VISIBLE
				_:
					color = COLOR_UNDISCOVERED
			_fog_image.set_pixel(x, y, color)

	_fog_texture.update(_fog_image)


## Flush only the dirty cells to the image (incremental update).
func _flush_dirty_cells() -> void:
	if _fog_image == null:
		return

	var player_id: int = local_player_id
	_ensure_player_fog(player_id)
	var fog: PackedByteArray = _fog_data[player_id]

	for cell_key: Vector2i in _dirty_cells:
		var x: int = cell_key.x
		var y: int = cell_key.y
		var idx: int = y * grid_size.x + x
		var state: int = fog[idx]
		var trans_alpha: float = _transition_alpha[idx] if idx < _transition_alpha.size() else 0.0

		var color: Color
		match state:
			UNDISCOVERED:
				color = COLOR_UNDISCOVERED
			EXPLORED:
				var explored_alpha: float = lerp(COLOR_EXPLORED.a, COLOR_VISIBLE.a, trans_alpha)
				color = Color(0.0, 0.0, 0.0, explored_alpha)
			VISIBLE:
				color = COLOR_VISIBLE
			_:
				color = COLOR_UNDISCOVERED
		_fog_image.set_pixel(x, y, color)

	_fog_texture.update(_fog_image)
	_dirty_cells.clear()

# =============================================================================
# Public API
# =============================================================================

## Set the fog grid dimensions (call if map size changes at runtime).
func set_grid_size(new_size: Vector2i) -> void:
	grid_size = new_size
	_initialize_fog_image()
	_fog_data.clear()
	_needs_full_redraw = true


## Get the visibility state for an entire row (useful for debug/UI).
func get_row_visibility(row: int, player_id: int = -1) -> PackedByteArray:
	if player_id == -1:
		player_id = local_player_id
	_ensure_player_fog(player_id)
	var fog: PackedByteArray = _fog_data[player_id]
	var result: PackedByteArray = PackedByteArray()
	var start_idx: int = row * grid_size.x
	result.append_array(fog.slice(start_idx, start_idx + grid_size.x))
	return result


## Count cells in each visibility state for a player.
func get_visibility_stats(player_id: int = -1) -> Dictionary:
	if player_id == -1:
		player_id = local_player_id
	_ensure_player_fog(player_id)
	var fog: PackedByteArray = _fog_data[player_id]
	var stats: Dictionary = {
		"undiscovered": 0,
		"explored": 0,
		"visible": 0,
	}
	for i in range(fog.size()):
		match fog[i]:
			UNDISCOVERED:
				stats["undiscovered"] += 1
			EXPLORED:
				stats["explored"] += 1
			VISIBLE:
				stats["visible"] += 1
	return stats


## Check if any cell near a world position is visible to the local player.
func is_world_position_visible(world_pos: Vector2) -> bool:
	var cell: Vector2i = Vector2i(
		floori(world_pos.x / cell_pixel_size.x),
		floori(world_pos.y / cell_pixel_size.y)
	)
	return is_cell_visible(cell)


## Force a complete fog re-render on the next frame.
func request_full_redraw() -> void:
	_needs_full_redraw = true

# =============================================================================
# Callbacks
# =============================================================================

## Called when a new game starts — reset fog and sync grid size.
func _on_game_started(_player_id: int) -> void:
	_fog_data.clear()
	_initialize_fog_image()
	_needs_full_redraw = true
