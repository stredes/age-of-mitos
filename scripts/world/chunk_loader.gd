## Chunk-based loading and unloading system for large RTS maps.
##
## Divides the world into fixed-size chunks and manages which are active based
## on camera position. Handles throttled loading to prevent frame stutters and
## emits signals so other systems can react to chunk state changes.
class_name ChunkLoader
extends Node2D

# =============================================================================
# Signals
# =============================================================================

## Emitted when a chunk is loaded into the scene tree.
signal chunk_loaded(chunk_key: Vector2i)

## Emitted when a chunk is unloaded from the scene tree.
signal chunk_unloaded(chunk_key: Vector2i)

## Emitted when all visible chunks around a position are ready.
signal visible_chunks_ready(camera_position: Vector2i)

# =============================================================================
# Constants
# =============================================================================

## Size of each chunk in grid cells.
const CHUNK_SIZE: int = 32

## Maximum chunks to load per frame to prevent stuttering.
const MAX_LOADS_PER_FRAME: int = 3

## Maximum chunks to unload per frame.
const MAX_UNLOADS_PER_FRAME: int = 4

# =============================================================================
# Inner Class: ChunkData
# =============================================================================

## Holds all data and scene state for a single chunk.
class ChunkData:
	## The chunk's grid key (chunk_x, chunk_y).
	var key: Vector2i = Vector2i.ZERO

	## The top-left world cell this chunk covers.
	var origin: Vector2i = Vector2i.ZERO

	## 2D array of terrain ints for cells in this chunk (local to chunk).
	var terrain_cells: Array = []

	## Resource node data relevant to this chunk (dictionaries).
	var resource_entries: Array = []

	## Scene nodes currently instantiated for this chunk (resource nodes, etc).
	var active_nodes: Array[Node] = []

	## The visual tile node (ColorRect or similar) for this chunk's terrain.
	var terrain_node: Node2D = null

	## Whether this chunk is currently loaded in the scene tree.
	var is_loaded: bool = false

	## Whether the terrain visuals have been built.
	var terrain_built: bool = false

	func _init(p_key: Vector2i = Vector2i.ZERO, p_origin: Vector2i = Vector2i.ZERO) -> void:
		key = p_key
		origin = p_origin

	## Return the world cell at a local offset within this chunk.
	func local_to_world_cell(local: Vector2i) -> Vector2i:
		return Vector2i(origin.x + local.x, origin.y + local.y)

	## Return the local cell from a world cell.
	func world_to_local_cell(world: Vector2i) -> Vector2i:
		return Vector2i(world.x - origin.x, world.y - origin.y)

# =============================================================================
# Configuration
# =============================================================================

## How many chunks beyond the visible area to pre-load.
@export var buffer_chunks: int = 2

## Radius in chunks around the camera to consider "visible".
@export var visible_radius_chunks: int = 4

## Whether to draw terrain colors for loaded chunks (debug / placeholder).
@export var draw_terrain_visuals: bool = true

# =============================================================================
# Properties
# =============================================================================

## Reference to the WorldData being managed.
var _world_data: WorldData = null

## Dictionary of Vector2i (chunk key) -> ChunkData.
var _chunks: Dictionary = {}

## Set of currently loaded chunk keys.
var _loaded_keys: Dictionary = {}

## Queue of chunk keys waiting to be loaded (Vector2i).
var _load_queue: Array[Vector2i] = []

## Queue of chunk keys waiting to be unloaded (Vector2i).
var _unload_queue: Array[Vector2i] = []

## The last camera chunk position to detect movement.
var _last_camera_chunk: Vector2i = Vector2i(-999999, -999999)

## Node2D container for chunk visual nodes.
var _chunk_container: Node2D = null

## Node2D container for resource nodes spawned in chunks.
var _resource_container: Node2D = null

## Terrain colors for visual representation.
const TERRAIN_COLORS: Dictionary = {
	0: Color(0.15, 0.25, 0.55),  # DEEP_WATER
	1: Color(0.25, 0.45, 0.75),  # WATER
	2: Color(0.85, 0.80, 0.55),  # SAND
	3: Color(0.35, 0.65, 0.25),  # GRASS
	4: Color(0.15, 0.50, 0.15),  # FOREST
	5: Color(0.45, 0.40, 0.38),  # MOUNTAIN
}

# =============================================================================
# Resource Node Scene (inline placeholder — will be replaced by actual scene)
# =============================================================================

const RESOURCE_NODE_SCENE: PackedScene = null

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_chunk_container = Node2D.new()
	_chunk_container.name = "ChunkVisuals"
	_chunk_container.z_index = -1
	add_child(_chunk_container)

	_resource_container = Node2D.new()
	_resource_container.name = "ResourceNodes"
	add_child(_resource_container)


func _process(_delta: float) -> void:
	_process_load_queue()
	_process_unload_queue()

# =============================================================================
# Public API
# =============================================================================

## Initialize the chunk loader with world data.
func initialize(world_data: WorldData) -> void:
	_world_data = world_data
	_chunks.clear()
	_loaded_keys.clear()
	_load_queue.clear()
	_unload_queue.clear()
	_last_camera_chunk = Vector2i(-999999, -999999)

	# Pre-create all ChunkData entries.
	var map_w: int = world_data.map_size.x
	var map_h: int = world_data.map_size.y
	var chunks_x: int = ceili(float(map_w) / float(CHUNK_SIZE))
	var chunks_y: int = ceili(float(map_h) / float(CHUNK_SIZE))

	for cy in range(chunks_y):
		for cx in range(chunks_x):
			var key: Vector2i = Vector2i(cx, cy)
			var origin: Vector2i = Vector2i(cx * CHUNK_SIZE, cy * CHUNK_SIZE)
			var chunk: ChunkData = ChunkData.new(key, origin)
			_extract_chunk_terrain(chunk)
			_extract_chunk_resources(chunk)
			_chunks[key] = chunk


## Update loaded chunks based on camera position in world coordinates.
## Call this every frame from the camera controller.
func update_loaded_chunks(camera_world_position: Vector2) -> void:
	var camera_cell: Vector2i = Vector2i(
		int(camera_world_position.x) / (CHUNK_SIZE * WorldGenerator.CELL_SIZE),
		int(camera_world_position.y) / (CHUNK_SIZE * WorldGenerator.CELL_SIZE)
	)

	# Only recalculate when camera crosses a chunk boundary.
	if camera_cell == _last_camera_chunk:
		return
	_last_camera_chunk = camera_cell

	var load_radius: int = visible_radius_chunks + buffer_chunks
	var visible_radius: int = visible_radius_chunks

	# Determine which chunks should be loaded.
	var desired_loaded: Dictionary = {}
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var key: Vector2i = Vector2i(camera_cell.x + dx, camera_cell.y + dy)
			if _chunks.has(key):
				desired_loaded[key] = true

	# Queue newly needed chunks (prioritize visible ones).
	_load_queue.clear()
	for dy in range(-visible_radius, visible_radius + 1):
		for dx in range(-visible_radius, visible_radius + 1):
			var key: Vector2i = Vector2i(camera_cell.x + dx, camera_cell.y + dy)
			if _chunks.has(key) and not _loaded_keys.has(key):
				_load_queue.append(key)

	# Add buffer chunks after visible.
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var key: Vector2i = Vector2i(camera_cell.x + dx, camera_cell.y + dy)
			if _chunks.has(key) and not _loaded_keys.has(key) and key not in _load_queue:
				_load_queue.append(key)

	# Queue chunks that should be unloaded.
	_unload_queue.clear()
	for key: Vector2i in _loaded_keys:
		if not desired_loaded.has(key):
			_unload_queue.append(key)


## Force-load all chunks (useful for debugging or small maps).
func load_all_chunks() -> void:
	if _world_data == null:
		return
	for key: Vector2i in _chunks:
		if not _loaded_keys.has(key):
			_load_chunk(key)


## Unload all chunks except those near a given position.
func unload_all_except(near_cell: Vector2i, radius: int = 3) -> void:
	var to_unload: Array[Vector2i] = []
	for key: Vector2i in _loaded_keys:
		var dist: float = Vector2(key).distance_to(Vector2(near_cell))
		if float(radius) < dist:
			to_unload.append(key)
	for key: Vector2i in to_unload:
		_unload_chunk(key)


## Get the ChunkData for a given chunk key.
func get_chunk(key: Vector2i) -> ChunkData:
	return _chunks.get(key, null)


## Get the chunk key that contains a given world cell.
func world_cell_to_chunk_key(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x / CHUNK_SIZE, cell.y / CHUNK_SIZE)


## Check if a chunk is currently loaded.
func is_chunk_loaded(key: Vector2i) -> bool:
	return _loaded_keys.has(key)


## Get count of currently loaded chunks.
func get_loaded_count() -> int:
	return _loaded_keys.size()


## Get total chunk count.
func get_total_chunks() -> int:
	return _chunks.size()

# =============================================================================
# Chunk Loading / Unloading
# =============================================================================

func _load_chunk(key: Vector2i) -> void:
	if not _chunks.has(key):
		return
	var chunk: ChunkData = _chunks[key]
	if chunk.is_loaded:
		return

	# Build terrain visual if needed.
	if draw_terrain_visuals and not chunk.terrain_built:
		_build_chunk_terrain_visual(chunk)

	# Spawn resource nodes.
	_spawn_chunk_resources(chunk)

	# Add visual node to scene tree.
	if chunk.terrain_node != null and chunk.terrain_node.get_parent() == null:
		_chunk_container.add_child(chunk.terrain_node)

	chunk.is_loaded = true
	_loaded_keys[key] = true
	chunk_loaded.emit(key)


func _unload_chunk(key: Vector2i) -> void:
	if not _chunks.has(key):
		return
	var chunk: ChunkData = _chunks[key]
	if not chunk.is_loaded:
		return

	# Remove resource nodes from scene but keep their data.
	for node: Node in chunk.active_nodes:
		if node and is_instance_valid(node):
			# Save any state changes back to chunk data before removing.
			node.queue_free()
	chunk.active_nodes.clear()

	# Remove terrain visual from scene.
	if chunk.terrain_node != null and chunk.terrain_node.is_inside_tree():
		_chunk_container.remove_child(chunk.terrain_node)

	chunk.is_loaded = false
	_loaded_keys.erase(key)
	chunk_unloaded.emit(key)


func _process_load_queue() -> void:
	var loaded_this_frame: int = 0
	while not _load_queue.is_empty() and loaded_this_frame < MAX_LOADS_PER_FRAME:
		var key: Vector2i = _load_queue.pop_front()
		if not _loaded_keys.has(key):
			_load_chunk(key)
			loaded_this_frame += 1

	if _load_queue.is_empty() and loaded_this_frame > 0:
		visible_chunks_ready.emit(Vector2(_last_camera_chunk) * float(CHUNK_SIZE))


func _process_unload_queue() -> void:
	var unloaded_this_frame: int = 0
	while not _unload_queue.is_empty() and unloaded_this_frame < MAX_UNLOADS_PER_FRAME:
		var key: Vector2i = _unload_queue.pop_front()
		if _loaded_keys.has(key):
			_unload_chunk(key)
			unloaded_this_frame += 1

# =============================================================================
# Terrain Data Extraction
# =============================================================================

func _extract_chunk_terrain(chunk: ChunkData) -> void:
	if _world_data == null:
		return
	var local_terrain: Array = []
	for ly in range(CHUNK_SIZE):
		var row: Array = []
		for lx in range(CHUNK_SIZE):
			var world_cell: Vector2i = chunk.local_to_world_cell(Vector2i(lx, ly))
			if _world_data.is_in_bounds(world_cell):
				row.append(_world_data.get_terrain_at(world_cell) as int)
			else:
				row.append(WorldData.Terrain.DEEP_WATER as int)
		local_terrain.append(row)
	chunk.terrain_cells = local_terrain


func _extract_chunk_resources(chunk: ChunkData) -> void:
	if _world_data == null:
		return
	var origin: Vector2i = chunk.origin
	var end: Vector2i = Vector2i(
		mini(origin.x + CHUNK_SIZE, _world_data.map_size.x),
		mini(origin.y + CHUNK_SIZE, _world_data.map_size.y)
	)
	for node_data: Dictionary in _world_data.resource_nodes:
		var pos: Vector2i = node_data.get("grid_pos", Vector2i(-999, -999))
		if pos.x >= origin.x and pos.x < end.x and pos.y >= origin.y and pos.y < end.y:
			chunk.resource_entries.append(node_data)

# =============================================================================
# Visual Terrain Building
# =============================================================================

func _build_chunk_terrain_visual(chunk: ChunkData) -> void:
	var container: Node2D = Node2D.new()
	container.name = "Chunk_%d_%d" % [chunk.key.x, chunk.key.y]
	container.position = Vector2(
		float(chunk.origin.x * 32),
		float(chunk.origin.y * 32)
	)

	# Build a single MeshInstance2D covering the chunk with per-cell coloring
	# using an immediate-mode approach: one small rect per cell.
	# For performance, batch same-terrain cells into larger rects where possible.
	# Simplified approach: draw one rect per cell using draw calls.
	var draw_node: Node2D = _ChunkDrawNode.new()
	draw_node.chunk_data = chunk
	draw_node.chunks_ref = _chunks
	container.add_child(draw_node)

	chunk.terrain_node = container
	chunk.terrain_built = true

# =============================================================================
# Resource Node Spawning
# =============================================================================

func _spawn_chunk_resources(chunk: ChunkData) -> void:
	for node_data: Dictionary in chunk.resource_entries:
		var resource_type: String = node_data.get("type", "")
		var grid_pos: Vector2i = node_data.get("grid_pos", Vector2i.ZERO)
		var amount: int = node_data.get("amount", 0)
		var max_amount: int = node_data.get("max_amount", amount)

		var node: Node2D = _create_resource_node(resource_type, grid_pos, amount, max_amount)
		if node != null:
			_resource_container.add_child(node)
			chunk.active_nodes.append(node)


func _create_resource_node(
	resource_type: String, grid_pos: Vector2i, amount: int, max_amount: int
) -> Node2D:
	var scene: PackedScene = load("res://scenes/world/resource_node.tscn") as PackedScene
	var node: Node2D = scene.instantiate() as Node2D if scene != null else ResourceNode.new()
	node.name = "%s_%d_%d" % [resource_type, grid_pos.x, grid_pos.y]
	if node.has_method("initialize_from_data"):
		node.initialize_from_data({
			"type": resource_type,
			"grid_pos": grid_pos,
			"amount": amount,
			"max_amount": max_amount,
		})
	if node.has_method("update_world_position"):
		node.update_world_position(WorldGenerator.CELL_SIZE)
	else:
		node.position = Vector2(float(grid_pos.x * WorldGenerator.CELL_SIZE + 16), float(grid_pos.y * WorldGenerator.CELL_SIZE + 16))

	return node


func _get_resource_color(type: String) -> Color:
	match type:
		"wood":
			return Color(0.3, 0.6, 0.2)
		"stone":
			return Color(0.55, 0.55, 0.55)
		"food":
			return Color(0.8, 0.3, 0.3)
		"gold":
			return Color(0.9, 0.8, 0.2)
		_:
			return Color.MAGENTA

# =============================================================================
# Cleanup
# =============================================================================

## Remove all loaded chunks and free resources.
func cleanup() -> void:
	for key: Vector2i in _loaded_keys.keys():
		_unload_chunk(key)
	_chunks.clear()
	_load_queue.clear()
	_unload_queue.clear()
	_last_camera_chunk = Vector2i(-999999, -999999)

# =============================================================================
# Inner Draw Node (renders chunk terrain)
# =============================================================================

## Lightweight node that uses _draw() to render terrain cells as colored rects.
class _ChunkDrawNode extends Node2D:
	var chunk_data: ChunkData = null
	var chunks_ref: Dictionary = {}

	func _draw() -> void:
		if chunk_data == null:
			return
		for ly in range(ChunkLoader.CHUNK_SIZE):
			if ly >= chunk_data.terrain_cells.size():
				break
			var row: Array = chunk_data.terrain_cells[ly]
			for lx in range(row.size()):
				var terrain_type: int = row[lx]
				var rect_pos: Vector2 = Vector2(float(lx * 32), float(ly * 32))
				var rect_size: Vector2 = Vector2(32, 32)
				var rect: Rect2 = Rect2(rect_pos, rect_size)
				var color: Color = ChunkLoader.TERRAIN_COLORS.get(terrain_type, Color.MAGENTA)
				var variation: float = _cell_variation(lx, ly)
				draw_rect(rect, color.lightened(variation * 0.08))
				_draw_terrain_detail(terrain_type, rect_pos, lx, ly)


	func _draw_terrain_detail(terrain_type: int, pos: Vector2, lx: int, ly: int) -> void:
		var h: int = _cell_hash(lx, ly)
		match terrain_type:
			WorldData.Terrain.DEEP_WATER:
				draw_line(pos + Vector2(3, 9 + h % 7), pos + Vector2(25, 7 + h % 7), Color(0.55, 0.75, 0.95, 0.16), 1.0)
			WorldData.Terrain.WATER:
				draw_line(pos + Vector2(4, 10 + h % 6), pos + Vector2(27, 9 + h % 6), Color(0.70, 0.88, 1.0, 0.24), 1.0)
				draw_line(pos + Vector2(9, 21), pos + Vector2(22, 20), Color(0.70, 0.88, 1.0, 0.14), 1.0)
			WorldData.Terrain.SAND:
				for i in range(3):
					var p: Vector2 = pos + Vector2(float((h + i * 9) % 28 + 2), float((h / (i + 2)) % 24 + 4))
					draw_circle(p, 1.0, Color(0.60, 0.50, 0.30, 0.22))
			WorldData.Terrain.GRASS:
				for i in range(2):
					var base: Vector2 = pos + Vector2(float((h + i * 11) % 24 + 4), float((h / (i + 3)) % 22 + 7))
					draw_line(base, base + Vector2(-2, -4), Color(0.14, 0.42, 0.12, 0.30), 1.0)
					draw_line(base, base + Vector2(2, -3), Color(0.18, 0.50, 0.16, 0.25), 1.0)
			WorldData.Terrain.FOREST:
				var trunk: Vector2 = pos + Vector2(16, 21)
				draw_rect(Rect2(trunk + Vector2(-2, -4), Vector2(4, 8)), Color(0.30, 0.16, 0.07, 0.45))
				draw_circle(pos + Vector2(16, 13), 8.0, Color(0.08, 0.33, 0.10, 0.56))
				draw_circle(pos + Vector2(10, 16), 5.0, Color(0.06, 0.28, 0.09, 0.45))
				draw_circle(pos + Vector2(22, 16), 5.0, Color(0.10, 0.38, 0.12, 0.42))
			WorldData.Terrain.MOUNTAIN:
				var peak: PackedVector2Array = PackedVector2Array([
					pos + Vector2(4, 27),
					pos + Vector2(15 + h % 4, 5),
					pos + Vector2(29, 27),
				])
				draw_colored_polygon(peak, Color(0.36, 0.35, 0.34, 0.45))
				draw_line(pos + Vector2(15 + h % 4, 6), pos + Vector2(21, 27), Color(0.18, 0.17, 0.16, 0.28), 1.0)


	func _cell_hash(lx: int, ly: int) -> int:
		return abs((chunk_data.origin.x + lx) * 73856093 ^ (chunk_data.origin.y + ly) * 19349663)


	func _cell_variation(lx: int, ly: int) -> float:
		return float(_cell_hash(lx, ly) % 100) / 100.0 - 0.5
