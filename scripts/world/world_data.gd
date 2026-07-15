## Resource class that holds the complete state of a generated world.
##
## WorldData stores terrain grids, resource node placements, building positions,
## and metadata needed for serialization. It is the authoritative data source
## that world_generator produces and chunk_loader consumes.
class_name WorldData
extends Resource

# =============================================================================
# Enums
# =============================================================================

## Terrain type identifiers stored in the terrain grid.
enum Terrain {
	DEEP_WATER = 0,
	WATER = 1,
	SAND = 2,
	GRASS = 3,
	FOREST = 4,
	MOUNTAIN = 5,
}

## Human-readable names for each terrain type.
const TERRAIN_NAMES: Dictionary = {
	Terrain.DEEP_WATER: "deep_water",
	Terrain.WATER: "water",
	Terrain.SAND: "sand",
	Terrain.GRASS: "grass",
	Terrain.FOREST: "forest",
	Terrain.MOUNTAIN: "mountain",
}

## Reverse lookup: string name -> enum value.
const NAME_TO_TERRAIN: Dictionary = {
	"deep_water": Terrain.DEEP_WATER,
	"water": Terrain.WATER,
	"sand": Terrain.SAND,
	"grass": Terrain.GRASS,
	"forest": Terrain.FOREST,
	"mountain": Terrain.MOUNTAIN,
}

# =============================================================================
# Exported Properties
# =============================================================================

## Width of the world in grid cells.
@export var map_size: Vector2i = Vector2i(120, 120)

## Seed used for procedural generation.
@export var seed_value: int = 0

## 2D array of Terrain enum values. Indexed as [y][x].
@export var terrain_grid: Array = []

## Array of dictionaries describing resource nodes placed on the map.
## Each entry: { "type": String, "grid_pos": Vector2i, "amount": int, "max_amount": int }
@export var resource_nodes: Array = []

## Dictionary of placed buildings keyed by a unique building ID (int).
## Each value: { "building_type": String, "grid_pos": Vector2i, "player_id": int }
@export var building_positions: Dictionary = {}

# =============================================================================
# Terrain Queries
# =============================================================================

## Return the Terrain enum value at a grid cell.
## Returns Terrain.DEEP_WATER (0) for out-of-bounds coordinates.
func get_terrain_at(cell: Vector2i) -> Terrain:
	if not _is_in_bounds(cell):
		return Terrain.DEEP_WATER
	return terrain_grid[cell.y][cell.x] as Terrain


## Return the Terrain enum value at integer x, y.
func get_terrain_at_xy(x: int, y: int) -> Terrain:
	return get_terrain_at(Vector2i(x, y))


## Return the string name of the terrain at a grid cell.
func get_terrain_name_at(cell: Vector2i) -> String:
	return TERRAIN_NAMES.get(get_terrain_at(cell), "unknown")


## Set the terrain type at a grid cell.
func set_terrain_at(cell: Vector2i, terrain: Terrain) -> void:
	if _is_in_bounds(cell):
		terrain_grid[cell.y][cell.x] = terrain


## Check if a grid cell is walkable (not water, not mountain).
func is_walkable(cell: Vector2i) -> bool:
	var terrain: Terrain = get_terrain_at(cell)
	return terrain != Terrain.DEEP_WATER and terrain != Terrain.WATER and terrain != Terrain.MOUNTAIN


## Check if a grid cell blocks movement entirely.
func is_blocked(cell: Vector2i) -> bool:
	return not is_walkable(cell)


## Check if a grid cell is land (any solid terrain).
func is_land(cell: Vector2i) -> bool:
	var terrain: Terrain = get_terrain_at(cell)
	return terrain != Terrain.DEEP_WATER and terrain != Terrain.WATER


## Check if a grid cell is water of any kind.
func is_water(cell: Vector2i) -> bool:
	var terrain: Terrain = get_terrain_at(cell)
	return terrain == Terrain.DEEP_WATER or terrain == Terrain.WATER


## Return true if the cell is within the world bounds.
func is_in_bounds(cell: Vector2i) -> bool:
	return _is_in_bounds(cell)


## Return the center cell of the map.
func get_center() -> Vector2i:
	return Vector2i(map_size.x / 2, map_size.y / 2)

# =============================================================================
# Resource Node Queries
# =============================================================================

## Get all resource nodes of a specific type.
## [param resource_type: String] e.g. "wood", "stone", "food", "gold".
func get_resources_by_type(resource_type: String) -> Array:
	var results: Array = []
	for node_data: Dictionary in resource_nodes:
		if node_data.get("type", "") == resource_type:
			results.append(node_data)
	return results


## Get the total remaining amount of a resource type across all nodes.
func get_total_resource_amount(resource_type: String) -> int:
	var total: int = 0
	for node_data: Dictionary in resource_nodes:
		if node_data.get("type", "") == resource_type:
			total += node_data.get("amount", 0)
	return total


## Find the nearest resource node of a given type to a grid position.
## Returns the node dictionary or an empty dictionary if none found.
func find_nearest_resource(cell: Vector2i, resource_type: String) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = INF
	for node_data: Dictionary in resource_nodes:
		if node_data.get("type", "") != resource_type:
			continue
		if node_data.get("amount", 0) <= 0:
			continue
		var pos: Vector2i = node_data.get("grid_pos", Vector2i.ZERO)
		var dist: float = cell.distance_to(Vector2(pos))
		if dist < best_dist:
			best_dist = dist
			best = node_data
	return best


## Add a resource node entry to the world data.
func add_resource_node(resource_type: String, grid_pos: Vector2i, amount: int) -> Dictionary:
	var node_data: Dictionary = {
		"type": resource_type,
		"grid_pos": grid_pos,
		"amount": amount,
		"max_amount": amount,
	}
	resource_nodes.append(node_data)
	return node_data


## Remove a resource node entry by reference.
func remove_resource_node(node_data: Dictionary) -> void:
	resource_nodes.erase(node_data)

# =============================================================================
# Building Queries
# =============================================================================

## Place a building in the world data. Returns the assigned building ID.
func place_building(building_type: String, grid_pos: Vector2i, player_id: int) -> int:
	var building_id: int = building_positions.size() + 1
	while building_positions.has(building_id):
		building_id += 1
	building_positions[building_id] = {
		"building_type": building_type,
		"grid_pos": grid_pos,
		"player_id": player_id,
	}
	return building_id


## Remove a building by ID.
func remove_building(building_id: int) -> void:
	building_positions.erase(building_id)


## Get building data by ID.
func get_building(building_id: int) -> Dictionary:
	return building_positions.get(building_id, {})


## Get all buildings for a specific player.
func get_player_buildings(player_id: int) -> Dictionary:
	var result: Dictionary = {}
	for id: int in building_positions:
		var bld: Dictionary = building_positions[id]
		if bld.get("player_id", -1) == player_id:
			result[id] = bld
	return result

# =============================================================================
# Serialization
# =============================================================================

## Serialize the entire world data to a Dictionary suitable for JSON encoding.
func serialize() -> Dictionary:
	var terrain_as_ints: Array = []
	for y in range(map_size.y):
		var row: Array = []
		for x in range(map_size.x):
			row.append(terrain_grid[y][x] as int)
		terrain_as_ints.append(row)

	var resource_copy: Array = []
	for node_data: Dictionary in resource_nodes:
		var copy: Dictionary = {}
		for key: String in node_data:
			var val: Variant = node_data[key]
			if val is Vector2i:
				copy[key] = {"x": val.x, "y": val.y}
			else:
				copy[key] = val
		resource_copy.append(copy)

	var building_copy: Dictionary = {}
	for id: int in building_positions:
		var bld: Dictionary = building_positions[id].duplicate()
		if bld.has("grid_pos") and bld["grid_pos"] is Vector2i:
			var gp: Vector2i = bld["grid_pos"]
			bld["grid_pos"] = {"x": gp.x, "y": gp.y}
		building_copy[str(id)] = bld

	return {
		"map_size": {"x": map_size.x, "y": map_size.y},
		"seed_value": seed_value,
		"terrain_grid": terrain_as_ints,
		"resource_nodes": resource_copy,
		"building_positions": building_copy,
	}


## Deserialize world data from a Dictionary (inverse of serialize).
func deserialize(data: Dictionary) -> void:
	var ms: Dictionary = data.get("map_size", {"x": 120, "y": 120})
	map_size = Vector2i(ms.get("x", 120), ms.get("y", 120))
	seed_value = data.get("seed_value", 0)

	var raw_terrain: Array = data.get("terrain_grid", [])
	terrain_grid.clear()
	for y in range(map_size.y):
		var row: Array = []
		if y < raw_terrain.size():
			var src_row: Array = raw_terrain[y]
			for x in range(map_size.x):
				if x < src_row.size():
					row.append(src_row[x] as int)
				else:
					row.append(Terrain.DEEP_WATER)
		else:
			for x in range(map_size.x):
				row.append(Terrain.DEEP_WATER)
		terrain_grid.append(row)

	resource_nodes.clear()
	for raw_node: Dictionary in data.get("resource_nodes", []):
		var node: Dictionary = raw_node.duplicate()
		if node.has("grid_pos") and node["grid_pos"] is Dictionary:
			var gp: Dictionary = node["grid_pos"]
			node["grid_pos"] = Vector2i(gp.get("x", 0), gp.get("y", 0))
		resource_nodes.append(node)

	building_positions.clear()
	var raw_buildings: Dictionary = data.get("building_positions", {})
	for id_str: String in raw_buildings:
		var bld: Dictionary = raw_buildings[id_str].duplicate()
		if bld.has("grid_pos") and bld["grid_pos"] is Dictionary:
			var gp: Dictionary = bld["grid_pos"]
			bld["grid_pos"] = Vector2i(gp.get("x", 0), gp.get("y", 0))
		var bid: int = int(id_str)
		building_positions[bid] = bld


## Save the world data to a file on disk.
## [param file_path: String] Absolute or res:// path to write to.
func save_to_file(file_path: String) -> Error:
	var data: Dictionary = serialize()
	var json_text: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("WorldData: Failed to open file for writing: %s" % file_path)
		return FileAccess.get_open_error()
	file.store_string(json_text)
	file.close()
	return OK


## Load world data from a JSON file on disk.
## [param file_path: String] Path to the JSON file.
## [return] A new WorldData resource, or null on failure.
static func load_from_file(file_path: String) -> WorldData:
	if not FileAccess.file_exists(file_path):
		push_error("WorldData: File not found: %s" % file_path)
		return null
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("WorldData: Cannot open file: %s" % file_path)
		return null
	var json_text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		push_error("WorldData: JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return null
	var world: WorldData = WorldData.new()
	world.deserialize(json.data as Dictionary)
	return world

# =============================================================================
# Internal Helpers
# =============================================================================

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_size.x and cell.y < map_size.y
