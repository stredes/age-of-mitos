## Procedural RTS map generator using layered value noise.
##
## Attach to a Node2D that serves as the game world root. Call generate() to
## produce a WorldData resource containing terrain, resource nodes, and metadata.
## Emits progress signals for loading screen integration.
class_name WorldGenerator
extends Node2D

# =============================================================================
# Signals
# =============================================================================

## Emitted as generation progresses. [param progress] is 0.0 - 1.0.
signal generation_progress(progress: float, stage: String)

## Emitted when map generation is fully complete.
signal generation_complete(world_data: WorldData)

# =============================================================================
# Configuration
# =============================================================================

## Default map size in grid cells.
const DEFAULT_MAP_SIZE: Vector2i = Vector2i(120, 120)

## Chunk size used by chunk_loader (must match).
const CELL_SIZE: int = 32

# --- Terrain Thresholds ---
const DEEP_WATER_MAX: float = 0.3
const WATER_MAX: float = 0.4
const SAND_MAX: float = 0.45
const GRASS_MAX: float = 0.7
const FOREST_MAX: float = 0.85
# Above FOREST_MAX = MOUNTAIN

# --- Moisture Thresholds ---
const MOISTURE_FOREST_MIN: float = 0.55
const MOISTURE_SPARSE_MAX: float = 0.3

# --- Starting Area ---
const START_SAFE_RADIUS: int = 12

# --- Resource Density (per 100 valid cells) ---
const TREE_DENSITY: float = 3.5
const STONE_DENSITY: float = 1.2
const FOOD_DENSITY: float = 2.0
const GOLD_DENSITY: float = 0.3

# --- Resource Amounts ---
const TREE_CLUSTER_MIN: int = 3
const TREE_CLUSTER_MAX: int = 8
const TREE_AMOUNT_PER: int = 100
const STONE_AMOUNT: int = 200
const FOOD_AMOUNT: int = 80
const FOOD_REGROW_RATE: int = 1
const FOOD_REGROW_INTERVAL: float = 30.0
const GOLD_AMOUNT: int = 150

# =============================================================================
# Simple Value Noise Implementation
# =============================================================================

## A simple value noise generator with permutation table and interpolation.
## Supports 2D noise with configurable seed for reproducibility.
class ValueNoise:
	var _permutation: PackedInt32Array = PackedInt32Array()
	var _gradients: PackedFloat32Array = PackedFloat32Array()
	var _table_size: int = 256

	func _init(noise_seed: int = 0) -> void:
		_rebuild(noise_seed)


	func _rebuild(noise_seed: int) -> void:
		_permutation.resize(_table_size * 2)
		_gradients.resize(_table_size * 2)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = noise_seed
		for i in range(_table_size):
			_permutation[i] = i
			_gradients[i] = rng.randf_range(-1.0, 1.0)
		# Fisher-Yates shuffle.
		for i in range(_table_size - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: int = _permutation[i]
			_permutation[i] = _permutation[j]
			_permutation[j] = tmp
		# Duplicate for wrapping.
		for i in range(_table_size):
			_permutation[_table_size + i] = _permutation[i]
			_gradients[_table_size + i] = _gradients[i]


	func _fade(t: float) -> float:
		return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


	func _lerp(a: float, b: float, t: float) -> float:
		return a + t * (b - a)


	func _hash(x: int, y: int) -> int:
		return _permutation[(_permutation[x & 255] + y) & 255]


	## Sample 2D value noise at coordinates (x, y). Returns roughly -1.0 to 1.0.
	func get_noise_2d(x: float, y: float) -> float:
		var xi: int = floori(x) & 255
		var yi: int = floori(y) & 255
		var xf: float = x - floorf(x)
		var yf: float = y - floorf(y)
		var u: float = _fade(xf)
		var v: float = _fade(yf)
		var aa: float = _gradients[_hash(xi, yi)]
		var ab: float = _gradients[_hash(xi, yi + 1)]
		var ba: float = _gradients[_hash(xi + 1, yi)]
		var bb: float = _gradients[_hash(xi + 1, yi + 1)]
		var x1: float = _lerp(aa, ba, u)
		var x2: float = _lerp(ab, bb, u)
		return _lerp(x1, x2, v)


	## Sample noise with fractal brownian motion (multiple octaves).
	## [param lacunarity] Frequency multiplier per octave.
	## [param persistence] Amplitude multiplier per octave.
	## [param octaves] Number of octaves to sum.
	func get_fbm(x: float, y: float, octaves: int = 4, lacunarity: float = 2.0, persistence: float = 0.5) -> float:
		var value: float = 0.0
		var amplitude: float = 1.0
		var frequency: float = 1.0
		var max_value: float = 0.0
		for i in range(octaves):
			value += get_noise_2d(x * frequency, y * frequency) * amplitude
			max_value += amplitude
			amplitude *= persistence
			frequency *= lacunarity
		return value / max_value

# =============================================================================
# Properties
# =============================================================================

var _elevation_noise: ValueNoise
var _moisture_noise: ValueNoise
var _detail_noise: ValueNoise
var _world_data: WorldData

# =============================================================================
# Public API
# =============================================================================

## Generate a complete world. Returns the WorldData resource.
## [param seed_value: int] Seed for reproducible generation.
## [param size: Vector2i] Map size in grid cells.
func generate(seed_value: int, size: Vector2i = DEFAULT_MAP_SIZE) -> WorldData:
	generation_progress.emit(0.0, "initializing")

	_world_data = WorldData.new()
	_world_data.map_size = size
	_world_data.seed_value = seed_value

	# Create noise generators with different seeds derived from master seed.
	_elevation_noise = ValueNoise.new(seed_value)
	_moisture_noise = ValueNoise.new(seed_value + 7919)
	_detail_noise = ValueNoise.new(seed_value + 6271)

	generation_progress.emit(0.05, "generating_terrain")
	_generate_terrain()

	generation_progress.emit(0.6, "clearing_start_area")
	_clear_starting_area()

	generation_progress.emit(0.7, "spawning_resources")
	_spawn_resources()

	generation_progress.emit(0.95, "finalizing")
	_validate_balance()

	generation_progress.emit(1.0, "complete")
	generation_complete.emit(_world_data)
	return _world_data

# =============================================================================
# Terrain Generation
# =============================================================================

func _generate_terrain() -> void:
	var w: int = _world_data.map_size.x
	var h: int = _world_data.map_size.y
	var scale_elev: float = 0.025
	var scale_moist: float = 0.03
	var scale_detail: float = 0.06
	var total_cells: float = float(w * h)
	var cell_index: int = 0

	for y in range(h):
		var row: Array = []
		for x in range(w):
			# Elevation from fractal noise.
			var elev: float = _elevation_noise.get_fbm(
				float(x) * scale_elev, float(y) * scale_elev, 5, 2.0, 0.5
			)
			# Remap from [-1,1] to [0,1].
			elev = (elev + 1.0) * 0.5

			# Moisture layer.
			var moisture: float = _moisture_noise.get_fbm(
				float(x) * scale_moist, float(y) * scale_moist, 4, 2.0, 0.5
			)
			moisture = (moisture + 1.0) * 0.5

			# Detail layer for edge variation.
			var detail: float = _detail_noise.get_fbm(
				float(x) * scale_detail, float(y) * scale_detail, 2, 2.0, 0.5
			)
			detail = (detail + 1.0) * 0.5

			# Apply coastline distortion using detail noise.
			var elev_modified: float = elev + (detail - 0.5) * 0.08

			# Determine terrain type.
			var terrain: int = _classify_terrain(elev_modified, moisture)
			row.append(terrain)
			cell_index += 1

		_world_data.terrain_grid.append(row)

		# Emit progress every 10 rows.
		if y % 10 == 0:
			var pct: float = 0.05 + (float(cell_index) / total_cells) * 0.55
			generation_progress.emit(pct, "generating_terrain")


func _classify_terrain(elevation: float, moisture: float) -> int:
	if elevation < DEEP_WATER_MAX:
		return WorldData.Terrain.DEEP_WATER
	if elevation < WATER_MAX:
		return WorldData.Terrain.WATER
	if elevation < SAND_MAX:
		return WorldData.Terrain.SAND
	if elevation < GRASS_MAX:
		# Grass vs sparse based on moisture.
		if moisture < MOISTURE_SPARSE_MAX:
			return WorldData.Terrain.GRASS
		return WorldData.Terrain.GRASS
	if elevation < FOREST_MAX:
		# Forest threshold depends on moisture.
		if moisture >= MOISTURE_FOREST_MIN:
			return WorldData.Terrain.FOREST
		# Moderate moisture = scattered trees on grass.
		return WorldData.Terrain.GRASS if moisture < MOISTURE_FOREST_MIN else WorldData.Terrain.FOREST
	# High elevation = mountain.
	return WorldData.Terrain.MOUNTAIN

# =============================================================================
# Starting Area
# =============================================================================

func _clear_starting_area() -> void:
	var center: Vector2i = _world_data.get_center()
	var radius: int = START_SAFE_RADIUS

	# Ensure center and surrounding area is walkable grass.
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell: Vector2i = Vector2i(center.x + dx, center.y + dy)
			if not _world_data.is_in_bounds(cell):
				continue
			var dist: float = sqrt(float(dx * dx + dy * dy))
			if dist <= float(radius):
				# Force grass with slight inner/outer ring.
				if dist <= float(radius) * 0.6:
					_world_data.set_terrain_at(cell, WorldData.Terrain.GRASS)
				else:
					# Outer ring: grass or sand for natural transition.
					_world_data.set_terrain_at(cell, WorldData.Terrain.GRASS)

	# Also clear a slightly larger ring of mountains/deep water for safety.
	var clear_radius: int = radius + 5
	for dy in range(-clear_radius, clear_radius + 1):
		for dx in range(-clear_radius, clear_radius + 1):
			var cell: Vector2i = Vector2i(center.x + dx, center.y + dy)
			if not _world_data.is_in_bounds(cell):
				continue
			var dist: float = sqrt(float(dx * dx + dy * dy))
			if dist <= float(clear_radius) and dist > float(radius):
				var current: int = _world_data.get_terrain_at(cell)
				if current == WorldData.Terrain.MOUNTAIN:
					_world_data.set_terrain_at(cell, WorldData.Terrain.GRASS)
				elif current == WorldData.Terrain.DEEP_WATER:
					_world_data.set_terrain_at(cell, WorldData.Terrain.WATER)

# =============================================================================
# Resource Spawning
# =============================================================================

func _spawn_resources() -> void:
	var w: int = _world_data.map_size.x
	var h: int = _world_data.map_size.y
	var center: Vector2i = _world_data.get_center()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _world_data.seed_value + 3571

	# Count valid cells per terrain type for balanced density.
	var grass_cells: Array[Vector2i] = []
	var forest_cells: Array[Vector2i] = []
	var mountain_cells: Array[Vector2i] = []
	var sand_cells: Array[Vector2i] = []

	for y in range(h):
		for x in range(w):
			var cell: Vector2i = Vector2i(x, y)
			# Skip starting safe zone.
			if cell.distance_to(Vector2(center)) <= float(START_SAFE_RADIUS + 2):
				continue
			var terrain: int = _world_data.get_terrain_at(cell)
			match terrain:
				WorldData.Terrain.GRASS:
					grass_cells.append(cell)
				WorldData.Terrain.FOREST:
					forest_cells.append(cell)
				WorldData.Terrain.MOUNTAIN:
					mountain_cells.append(cell)
				WorldData.Terrain.SAND:
					sand_cells.append(cell)

	# --- Trees in forest areas (clustered) ---
	var tree_target: int = int(float(forest_cells.size()) * TREE_DENSITY / 100.0)
	tree_target = maxi(tree_target, int(float(grass_cells.size()) * 1.0 / 100.0))
	_spawn_clustered_resources(
		rng, forest_cells, "wood", tree_target,
		TREE_CLUSTER_MIN, TREE_CLUSTER_MAX, TREE_AMOUNT_PER
	)
	# Also spawn some trees on grass near forests for natural edges.
	var grass_tree_count: int = int(float(grass_cells.size()) * 0.8 / 100.0)
	_spawn_scattered_resources(rng, grass_cells, "wood", grass_tree_count, TREE_AMOUNT_PER)

	# --- Stone deposits near mountains ---
	var stone_target: int = int(float(mountain_cells.size()) * STONE_DENSITY / 100.0)
	_spawn_near_terrain(rng, mountain_cells, grass_cells, "stone", stone_target, STONE_AMOUNT, 5)
	if _world_data.get_total_resource_amount("stone") <= 0:
		var fallback_stone_count: int = maxi(int(float(grass_cells.size()) * 0.8 / 100.0), 8)
		_spawn_scattered_resources(rng, grass_cells, "stone", fallback_stone_count, STONE_AMOUNT)

	# --- Food (berry bushes) in grasslands ---
	var food_target: int = int(float(grass_cells.size()) * FOOD_DENSITY / 100.0)
	_spawn_scattered_resources(rng, grass_cells, "food", food_target, FOOD_AMOUNT)

	# --- Gold deposits in rare locations (near sand or mountains) ---
	var gold_cells: Array[Vector2i] = []
	gold_cells.append_array(sand_cells)
	gold_cells.append_array(mountain_cells)
	# Also include grass cells near sand for transition zones.
	for cell: Vector2i in grass_cells:
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var neighbor: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
				if _world_data.get_terrain_at(neighbor) == WorldData.Terrain.SAND:
					gold_cells.append(cell)
					break
	var gold_target: int = maxi(int(float(gold_cells.size()) * GOLD_DENSITY / 100.0), 3)
	_spawn_scattered_resources(rng, gold_cells, "gold", gold_target, GOLD_AMOUNT)
	if _world_data.get_total_resource_amount("gold") <= 0:
		var fallback_gold_count: int = maxi(int(float(grass_cells.size()) * 0.25 / 100.0), 3)
		_spawn_scattered_resources(rng, grass_cells, "gold", fallback_gold_count, GOLD_AMOUNT)

	generation_progress.emit(0.9, "resources_complete")


func _spawn_clustered_resources(
	rng: RandomNumberGenerator,
	cells: Array[Vector2i],
	resource_type: String,
	target_count: int,
	cluster_min: int,
	cluster_max: int,
	amount_per: int
) -> void:
	var placed: int = 0
	var occupied: Dictionary = {}
	var max_attempts: int = target_count * 10
	var attempt: int = 0

	while placed < target_count and attempt < max_attempts:
		attempt += 1
		if cells.is_empty():
			break
		var idx: int = rng.randi_range(0, cells.size() - 1)
		var anchor: Vector2i = cells[idx]
		if occupied.has(anchor):
			continue
		var cluster_size: int = rng.randi_range(cluster_min, cluster_max)
		for c in range(cluster_size):
			var ox: int = rng.randi_range(-2, 2)
			var oy: int = rng.randi_range(-2, 2)
			var pos: Vector2i = Vector2i(anchor.x + ox, anchor.y + oy)
			if occupied.has(pos):
				continue
			if not _world_data.is_in_bounds(pos):
				continue
			var terrain: int = _world_data.get_terrain_at(pos)
			if terrain != WorldData.Terrain.FOREST and terrain != WorldData.Terrain.GRASS:
				continue
			occupied[pos] = true
			_world_data.add_resource_node(resource_type, pos, amount_per)
			placed += 1
			if placed >= target_count:
				break


func _spawn_scattered_resources(
	rng: RandomNumberGenerator,
	cells: Array[Vector2i],
	resource_type: String,
	target_count: int,
	amount: int
) -> void:
	var placed: int = 0
	var occupied: Dictionary = {}
	# Build a set of cells already occupied by existing resources.
	for node_data: Dictionary in _world_data.resource_nodes:
		occupied[node_data.get("grid_pos", Vector2i(-999, -999))] = true

	var shuffled: Array[Vector2i] = cells.duplicate()
	# Fisher-Yates shuffle.
	for i in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp

	for cell: Vector2i in shuffled:
		if placed >= target_count:
			break
		if occupied.has(cell):
			continue
		occupied[cell] = true
		_world_data.add_resource_node(resource_type, cell, amount)
		placed += 1


func _spawn_near_terrain(
	rng: RandomNumberGenerator,
	near_cells: Array[Vector2i],
	valid_cells: Array[Vector2i],
	resource_type: String,
	target_count: int,
	amount: int,
	max_distance: int
) -> void:
	# Find grass cells that are close to the target terrain.
	var candidates: Array[Vector2i] = []
	var near_set: Dictionary = {}
	for cell: Vector2i in near_cells:
		near_set[cell] = true

	for cell: Vector2i in valid_cells:
		for dx in range(-max_distance, max_distance + 1):
			for dy in range(-max_distance, max_distance + 1):
				var neighbor: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
				if near_set.has(neighbor):
					candidates.append(cell)
					break
			if candidates.size() > 0 and candidates.back() == cell:
				break

	# Shuffle and pick from candidates.
	candidates.shuffle()
	rng.seed = rng.seed + 1
	var occupied: Dictionary = {}
	for node_data: Dictionary in _world_data.resource_nodes:
		occupied[node_data.get("grid_pos", Vector2i(-999, -999))] = true

	var placed: int = 0
	for cell: Vector2i in candidates:
		if placed >= target_count:
			break
		if occupied.has(cell):
			continue
		occupied[cell] = true
		_world_data.add_resource_node(resource_type, cell, amount)
		placed += 1

# =============================================================================
# Balance Validation
# =============================================================================

func _validate_balance() -> void:
	# Ensure minimum resource availability.
	var min_wood: int = _world_data.get_total_resource_amount("wood")
	var min_stone: int = _world_data.get_total_resource_amount("stone")
	var min_food: int = _world_data.get_total_resource_amount("food")
	var min_gold: int = _world_data.get_total_resource_amount("gold")

	if min_wood < 50:
		push_warning("WorldGenerator: Low wood count (%d). Consider adjusting density." % min_wood)
	if min_stone < 20:
		push_warning("WorldGenerator: Low stone count (%d). Consider adjusting density." % min_stone)
	if min_food < 30:
		push_warning("WorldGenerator: Low food count (%d). Consider adjusting density." % min_food)
	if min_gold < 10:
		push_warning("WorldGenerator: Low gold count (%d). Consider adjusting density." % min_gold)
