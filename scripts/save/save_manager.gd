## Game save/load system using JSON serialization.
##
## Manages multiple save slots, auto-save, and full game state serialization.
## Saves are stored in user://saves/ as JSON files.
extends Node

# =============================================================================
# Constants
# =============================================================================

const SAVE_DIR: String = "user://saves/"
const MAX_SLOTS: int = 5
const AUTO_SAVE_INTERVAL: float = 300.0
const SAVE_FILE_PREFIX: String = "save_slot_"
const SAVE_FILE_SUFFIX: String = ".json"
const SAVE_VERSION: int = 1

# =============================================================================
# Signals
# =============================================================================

signal save_completed(success: bool, slot: int)
signal load_completed(success: bool, slot: int)

# =============================================================================
# Properties
# =============================================================================

var _auto_save_timer: float = 0.0
var _auto_save_enabled: bool = true
var _is_loading: bool = false

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_ensure_save_directory()


func _process(delta: float) -> void:
	if not _auto_save_enabled:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		auto_save()

# =============================================================================
# Public API
# =============================================================================

## Save the current game state to a slot (0-4).
func save_game(slot: int = 0) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_warning("SaveManager: Invalid slot %d." % slot)
		return false

	var save_data: Dictionary = _collect_save_data()
	save_data["metadata"] = _build_metadata()

	var path: String = _get_save_path(slot)
	var json_text: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Cannot write to '%s' (error %d)." % [path, FileAccess.get_open_error()])
		save_completed.emit(false, slot)
		return false

	file.store_string(json_text)
	file.close()

	EventBus.game_saved.emit("slot_%d" % slot)
	save_completed.emit(true, slot)
	return true


## Load a game state from a slot.
func load_game(slot: int = 0) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_warning("SaveManager: Invalid slot %d." % slot)
		return false

	var path: String = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: Save file not found at '%s'." % path)
		load_completed.emit(false, slot)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Cannot read '%s' (error %d)." % [path, FileAccess.get_open_error()])
		load_completed.emit(false, slot)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error in '%s' at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		load_completed.emit(false, slot)
		return false

	var save_data: Variant = json.data
	if save_data is not Dictionary:
		push_error("SaveManager: Expected Dictionary root in '%s'." % path)
		load_completed.emit(false, slot)
		return false

	_is_loading = true
	_apply_save_data(save_data as Dictionary)
	_is_loading = false

	EventBus.game_loaded.emit("slot_%d" % slot)
	load_completed.emit(true, slot)
	return true


## Delete a save file.
func delete_save(slot: int = 0) -> bool:
	var path: String = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var err: Error = DirAccess.remove_absolute(path)
	if err != OK:
		push_error("SaveManager: Failed to delete '%s' (error %d)." % [path, err])
		return false
	return true


## Get metadata for a specific save slot without loading the full data.
func get_save_info(slot: int) -> Dictionary:
	var path: String = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		return {}

	var save_data: Variant = json.data
	if save_data is not Dictionary:
		return {}

	return (save_data as Dictionary).get("metadata", {})


## Get info for all existing save slots.
func get_all_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	for slot in range(MAX_SLOTS):
		var info: Dictionary = get_save_info(slot)
		if not info.is_empty():
			info["slot"] = slot
			saves.append(info)
	return saves


## Trigger an auto-save.
func auto_save() -> void:
	save_game(0)


## Check if any save file exists.
func has_saves() -> bool:
	for slot in range(MAX_SLOTS):
		if FileAccess.file_exists(_get_save_path(slot)):
			return true
	return false


## Enable or disable auto-save.
func set_auto_save_enabled(enabled: bool) -> void:
	_auto_save_enabled = enabled


## Get whether auto-save is enabled.
func is_auto_save_enabled() -> bool:
	return _auto_save_enabled


## Check if a save exists for a specific slot.
func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))

# =============================================================================
# Data Collection
# =============================================================================

func _collect_save_data() -> Dictionary:
	var data: Dictionary = {}

	data["game_manager"] = _save_game_manager()
	data["units"] = _save_units()
	data["buildings"] = _save_buildings()
	data["world_resources"] = _save_world_resources()
	data["fog_of_war"] = _save_fog_of_war()
	data["technology"] = _save_technology()
	data["camera"] = _save_camera()
	data["resource_manager"] = _save_resource_manager()

	return data


func _build_metadata() -> Dictionary:
	var timestamp: int = int(Time.get_unix_time_from_system())
	var date_dict: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	var date_string: String = "%04d-%02d-%02d %02d:%02d:%02d" % [
		date_dict.get("year", 0),
		date_dict.get("month", 0),
		date_dict.get("day", 0),
		date_dict.get("hour", 0),
		date_dict.get("minute", 0),
		date_dict.get("second", 0),
	]

	return {
		"version": SAVE_VERSION,
		"name": "Save %s" % date_string,
		"timestamp": timestamp,
		"date_string": date_string,
		"game_time": GameManager.game_time,
		"real_time": GameManager.real_time,
		"game_speed": GameManager.game_speed,
		"player_count": GameManager.players.size(),
		"local_player_id": GameManager.local_player_id,
	}


func _save_game_manager() -> Dictionary:
	return {
		"players": _serialize_players(),
		"game_time": GameManager.game_time,
		"real_time": GameManager.real_time,
		"game_speed": GameManager.game_speed,
		"speed_index": GameManager.speed_index,
		"local_player_id": GameManager.local_player_id,
	}


func _serialize_players() -> Dictionary:
	var result: Dictionary = {}
	for pid: Variant in GameManager.players:
		var player_id: int = pid
		var player_data: Dictionary = GameManager.players[player_id]
		var copy: Dictionary = {}
		for key: String in player_data:
			var val: Variant = player_data[key]
			if val is Dictionary:
				copy[key] = (val as Dictionary).duplicate(true)
			else:
				copy[key] = val
		result[str(player_id)] = copy
	return result


func _save_units() -> Array:
	var units_array: Array = []
	var unit_manager: Node = _find_node_in_tree("UnitManager")
	if unit_manager == null:
		return units_array

	var units_dict: Dictionary = unit_manager.get("units") if unit_manager.get("units") != null else {}
	for id: Variant in units_dict:
		var unit: Node2D = units_dict[id]
		if not is_instance_valid(unit):
			continue
		var unit_data: Dictionary = _serialize_unit(unit)
		units_array.append(unit_data)
	return units_array


func _serialize_unit(unit: Node2D) -> Dictionary:
	var data: Dictionary = {
		"unit_id": unit.get("unit_id") if unit.has("unit_id") else -1,
		"unit_type": unit.get("unit_type") if unit.has("unit_type") else "",
		"player_id": unit.get("player_id") if unit.has("player_id") else -1,
		"position": {"x": unit.global_position.x, "y": unit.global_position.y},
	}

	var health_comp: Node = unit.get_node_or_null("HealthComponent")
	if health_comp != null:
		data["hp"] = health_comp.get("current_hp") if health_comp.get("current_hp") != null else 100
		data["max_hp"] = health_comp.get("max_hp") if health_comp.get("max_hp") != null else 100
	else:
		data["hp"] = unit.get("current_hp") if unit.has("current_hp") else 100
		data["max_hp"] = unit.get("max_hp") if unit.has("max_hp") else 100

	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp != null:
		data["carry_amount"] = harvest_comp.get("carry_amount") if harvest_comp.get("carry_amount") != null else 0
		data["carry_resource_type"] = harvest_comp.get("carry_resource_type") if harvest_comp.get("carry_resource_type") else ""
	else:
		data["carry_amount"] = 0
		data["carry_resource_type"] = ""

	var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
	if state_machine != null:
		data["state"] = state_machine.get("current_state_name") if state_machine.has_method("get") and state_machine.get("current_state_name") != null else "idle"
	else:
		data["state"] = "idle"

	data["assigned_resource"] = unit.get("assigned_resource") if unit.has("assigned_resource") else ""

	return data


func _save_buildings() -> Array:
	var buildings_array: Array = []
	var building_manager: Node = _find_node_in_tree("BuildingManager")
	if building_manager == null:
		return buildings_array

	var buildings_dict: Dictionary = building_manager.get("buildings") if building_manager.get("buildings") != null else {}
	for id: Variant in buildings_dict:
		var building: Node2D = buildings_dict[id]
		if not is_instance_valid(building):
			continue
		var b_data: Dictionary = _serialize_building(building)
		buildings_array.append(b_data)
	return buildings_array


func _serialize_building(building: Node2D) -> Dictionary:
	var data: Dictionary = {
		"building_id": building.get("building_id") if building.has("building_id") else -1,
		"building_type": building.get("building_type") if building.has("building_type") else "",
		"player_id": building.get("player_id") if building.has("player_id") else -1,
		"position": {"x": building.global_position.x, "y": building.global_position.y},
		"grid_position": {"x": building.get("grid_position").x, "y": building.get("grid_position").y} if building.has("grid_position") and building.get("grid_position") is Vector2i else {"x": 0, "y": 0},
	}

	data["hp"] = building.get("current_hp") if building.has("current_hp") else 100
	data["max_hp"] = building.get("max_hp") if building.has("max_hp") else 100
	data["is_constructed"] = building.get("is_constructed") if building.has("is_constructed") else true
	data["construction_progress"] = building.get("construction_progress") if building.has("construction_progress") else 0.0

	var prod_queue: Array = building.get("production_queue") if building.has("production_queue") else []
	data["production_queue"] = prod_queue.duplicate()
	data["is_producing"] = building.get("is_producing") if building.has("is_producing") else false
	data["production_timer"] = building.get("production_timer") if building.has("production_timer") else 0.0

	return data


func _save_world_resources() -> Array:
	var resource_nodes: Array = []
	var chunk_loader: Node = _find_node_in_tree("ChunkLoader")
	if chunk_loader == null:
		return resource_nodes

	var resource_container: Node = chunk_loader.get_node_or_null("ResourceNodes")
	if resource_container == null:
		return resource_nodes

	for child: Node in resource_container.get_children():
		if child is Node2D and child.has_method("get"):
			var res_type: String = child.get("resource_type") if child.get("resource_type") != null else ""
			if res_type.is_empty():
				res_type = child.get_meta("resource_type", "")
			var amount: int = child.get("current_amount") if child.get("current_amount") != null else 0
			if amount == 0:
				amount = child.get_meta("amount", 0)
			var max_amount: int = child.get("max_amount") if child.get("max_amount") != null else 0
			if max_amount == 0:
				max_amount = child.get_meta("max_amount", 0)
			var grid_pos: Vector2i = child.get("grid_pos") if child.get("grid_pos") != null else Vector2i.ZERO
			if grid_pos == Vector2i.ZERO:
				grid_pos = child.get_meta("grid_pos", Vector2i.ZERO)

			if amount > 0:
				resource_nodes.append({
					"type": res_type,
					"grid_pos": {"x": grid_pos.x, "y": grid_pos.y},
					"amount": amount,
					"max_amount": max_amount,
				})
	return resource_nodes


func _save_fog_of_war() -> Dictionary:
	var fog: Node = _find_node_in_tree("FogOfWar")
	if fog == null:
		return {}

	var fog_data: Dictionary = fog.get("_fog_data") if fog.get("_fog_data") != null else {}
	var serialized: Dictionary = {}
	for pid: Variant in fog_data:
		var player_id: int = pid
		var packed: PackedByteArray = fog_data[player_id]
		serialized[str(player_id)] = Marshalls.raw_to_base64(packed)

	var local_player: int = fog.get("local_player_id") if fog.get("local_player_id") != null else 1
	var grid_size: Vector2i = fog.get("grid_size") if fog.get("grid_size") != null else Vector2i(128, 128)

	return {
		"fog_data": serialized,
		"local_player_id": local_player,
		"grid_size": {"x": grid_size.x, "y": grid_size.y},
	}


func _save_technology() -> Dictionary:
	var tech_tree: Node = _find_node_in_tree("TechnologyTree")
	if tech_tree == null:
		return {}

	return {
		"researched": tech_tree.get("researched") if tech_tree.get("researched") != null else {},
		"researching": tech_tree.get("researching") if tech_tree.get("researching") != null else {},
		"tech_effects": tech_tree.get("tech_effects") if tech_tree.get("tech_effects") != null else {},
	}


func _save_camera() -> Dictionary:
	var camera: Camera2D = null
	if has_node("/root/GameWorld/Camera2D"):
		camera = get_node("/root/GameWorld/Camera2D")
	elif has_node("/root/GameWorld/CameraController"):
		camera = get_node("/root/GameWorld/CameraController")

	if camera == null:
		return {}

	return {
		"position": {"x": camera.position.x, "y": camera.position.y},
		"zoom": camera.zoom.x,
	}


func _save_resource_manager() -> Dictionary:
	var res_manager: Node = _find_node_in_tree("ResourceManager")
	if res_manager == null or not res_manager.has_method("get_save_data"):
		return {}
	return res_manager.get_save_data()

# =============================================================================
# Data Application
# =============================================================================

func _apply_save_data(data: Dictionary) -> void:
	_apply_game_manager(data.get("game_manager", {}))
	_apply_resource_manager(data.get("resource_manager", {}))
	_apply_units(data.get("units", []))
	_apply_buildings(data.get("buildings", []))
	_apply_world_resources(data.get("world_resources", []))
	_apply_fog_of_war(data.get("fog_of_war", {}))
	_apply_technology(data.get("technology", {}))
	_apply_camera(data.get("camera", {}))


func _apply_game_manager(data: Dictionary) -> void:
	if data.is_empty():
		return
	GameManager.game_time = data.get("game_time", 0.0)
	GameManager.real_time = data.get("real_time", 0.0)
	GameManager.game_speed = data.get("game_speed", 1.0)
	GameManager.speed_index = data.get("speed_index", 1)
	GameManager.local_player_id = data.get("local_player_id", 1)

	var raw_players: Dictionary = data.get("players", {})
	GameManager.players.clear()
	for pid_str: String in raw_players:
		var player_id: int = int(pid_str)
		var player_data: Dictionary = raw_players[pid_str]
		GameManager.players[player_id] = player_data


func _apply_units(units_array: Array) -> void:
	var unit_manager: Node = _find_node_in_tree("UnitManager")
	if unit_manager == null:
		return

	# Clear existing units.
	var existing_units: Dictionary = unit_manager.get("units") if unit_manager.get("units") != null else {}
	var ids_to_remove: Array = []
	for id: Variant in existing_units:
		ids_to_remove.append(id)
	for id: int in ids_to_remove:
		if unit_manager.has_method("despawn_unit"):
			unit_manager.despawn_unit(id)

	# Restore next_id tracking.
	var max_id: int = 0

	# Spawn units from save data.
	for unit_data: Dictionary in units_array:
		var unit_type: String = unit_data.get("unit_type", "")
		var player_id: int = unit_data.get("player_id", -1)
		var pos_dict: Dictionary = unit_data.get("position", {"x": 0, "y": 0})
		var position: Vector2 = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))

		var unit: Node2D = unit_manager.spawn_unit(unit_type, position, player_id)
		if unit == null:
			continue

		var saved_id: int = unit_data.get("unit_id", -1)
		if saved_id != -1:
			unit.unit_id = saved_id
			# Update the units dictionary key from new auto-generated to saved ID.
			var new_key: int = unit.get("unit_id")
			if new_key != saved_id and unit_manager.get("units").has(new_key):
				unit_manager.get("units").erase(new_key)
				unit_manager.get("units")[saved_id] = unit
			if saved_id > max_id:
				max_id = saved_id

		# Restore HP.
		var hp: int = unit_data.get("hp", 100)
		var health_comp: Node = unit.get_node_or_null("HealthComponent")
		if health_comp != null and health_comp.has_method("initialize"):
			health_comp.initialize(unit_data.get("max_hp", hp), player_id)
			health_comp.current_hp = hp

		# Restore carry state.
		var carry_amount: int = unit_data.get("carry_amount", 0)
		if carry_amount > 0:
			var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
			if harvest_comp != null:
				harvest_comp.set("carry_amount", carry_amount)
				harvest_comp.set("carry_resource_type", unit_data.get("carry_resource_type", ""))

		# Restore assignment.
		var assigned_res: String = unit_data.get("assigned_resource", "")
		if not assigned_res.is_empty():
			unit.set("assigned_resource", assigned_res)

	# Set next_id to max + 1.
	if max_id > 0:
		unit_manager.set("_next_id", max_id + 1)


func _apply_buildings(buildings_array: Array) -> void:
	var building_manager: Node = _find_node_in_tree("BuildingManager")
	if building_manager == null:
		return

	# Clear existing buildings.
	var existing_buildings: Dictionary = building_manager.get("buildings") if building_manager.get("buildings") != null else {}
	var ids_to_remove: Array = []
	for id: Variant in existing_buildings:
		ids_to_remove.append(id)
	for id: int in ids_to_remove:
		building_manager.remove_building(id)

	var max_id: int = 0

	for b_data: Dictionary in buildings_array:
		var building_type: String = b_data.get("building_type", "")
		var player_id: int = b_data.get("player_id", -1)
		var grid_dict: Dictionary = b_data.get("grid_position", {"x": 0, "y": 0})
		var grid_pos: Vector2i = Vector2i(grid_dict.get("x", 0), grid_dict.get("y", 0))

		var building: Node2D = building_manager.place_building(building_type, grid_pos, player_id)
		if building == null:
			continue

		var saved_id: int = b_data.get("building_id", -1)
		if saved_id != -1:
			building.building_id = saved_id
			var old_id: int = building.get("building_id")
			if old_id != saved_id and building_manager.get("buildings").has(old_id):
				building_manager.get("buildings").erase(old_id)
				building_manager.get("buildings")[saved_id] = building
			if saved_id > max_id:
				max_id = saved_id

		# Restore HP.
		building.current_hp = b_data.get("hp", building.max_hp)
		building.max_hp = b_data.get("max_hp", building.max_hp)

		# Restore construction state.
		var is_constructed: bool = b_data.get("is_constructed", true)
		if is_constructed and not building.is_constructed:
			building.complete_construction()
		elif not is_constructed:
			building.construction_progress = b_data.get("construction_progress", 0.0)

		# Restore production queue.
		building.production_queue = b_data.get("production_queue", [])
		building.is_producing = b_data.get("is_producing", false)
		building.production_timer = b_data.get("production_timer", 0.0)

	if max_id > 0:
		building_manager.set("_next_id", max_id + 1)


func _apply_world_resources(resources_array: Array) -> void:
	# Resource nodes are managed by ChunkLoader. We restore their amounts.
	var chunk_loader: Node = _find_node_in_tree("ChunkLoader")
	if chunk_loader == null:
		return

	var resource_container: Node = chunk_loader.get_node_or_null("ResourceNodes")
	if resource_container == null:
		return

	for save_res: Dictionary in resources_array:
		var res_type: String = save_res.get("type", "")
		var grid_dict: Dictionary = save_res.get("grid_pos", {"x": 0, "y": 0})
		var grid_pos: Vector2i = Vector2i(grid_dict.get("x", 0), grid_dict.get("y", 0))
		var amount: int = save_res.get("amount", 0)

		# Find the matching resource node in the scene.
		for child: Node in resource_container.get_children():
			if child is Node2D:
				var child_type: String = child.get("resource_type") if child.get("resource_type") != null else child.get_meta("resource_type", "")
				var child_grid: Vector2i = child.get("grid_pos") if child.get("grid_pos") != null else child.get_meta("grid_pos", Vector2i.ZERO)
				if child_type == res_type and child_grid == grid_pos:
					if child.has_method("set") and child.get("current_amount") != null:
						child.current_amount = amount
					else:
						child.set_meta("amount", amount)
					break


func _apply_fog_of_war(data: Dictionary) -> void:
	if data.is_empty():
		return

	var fog: Node = _find_node_in_tree("FogOfWar")
	if fog == null:
		return

	var fog_raw: Dictionary = data.get("fog_data", {})
	var restored: Dictionary = {}
	for pid_str: String in fog_raw:
		var player_id: int = int(pid_str)
		var b64: String = fog_raw[pid_str]
		var raw_bytes: PackedByteArray = Marshalls.base64_to_raw(b64)
		restored[player_id] = raw_bytes

	fog.set("_fog_data", restored)
	fog.request_full_redraw()


func _apply_technology(data: Dictionary) -> void:
	if data.is_empty():
		return

	var tech_tree: Node = _find_node_in_tree("TechnologyTree")
	if tech_tree == null:
		return

	tech_tree.set("researched", data.get("researched", {}))
	tech_tree.set("researching", data.get("researching", {}))
	tech_tree.set("tech_effects", data.get("tech_effects", {}))

	# Reapply all effects from researched techs.
	if tech_tree.has_method("reapply_all_effects"):
		tech_tree.reapply_all_effects()


func _apply_camera(data: Dictionary) -> void:
	if data.is_empty():
		return

	var camera: Camera2D = null
	if has_node("/root/GameWorld/Camera2D"):
		camera = get_node("/root/GameWorld/Camera2D")
	elif has_node("/root/GameWorld/CameraController"):
		camera = get_node("/root/GameWorld/CameraController")

	if camera == null:
		return

	var pos_dict: Dictionary = data.get("position", {"x": 0, "y": 0})
	camera.position = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))
	var zoom_val: float = data.get("zoom", 1.0)
	camera.zoom = Vector2.ONE * zoom_val

	if camera.has_method("set_zoom"):
		camera.set_zoom_level(zoom_val)


func _apply_resource_manager(data: Dictionary) -> void:
	if data.is_empty():
		return

	var res_manager: Node = _find_node_in_tree("ResourceManager")
	if res_manager == null or not res_manager.has_method("load_save_data"):
		return
	res_manager.load_save_data(data)

# =============================================================================
# Helpers
# =============================================================================

func _get_save_path(slot: int) -> String:
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_SUFFIX


func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			push_error("SaveManager: Failed to create save directory '%s' (error %d)." % [SAVE_DIR, err])


func _find_node_in_tree(target_name: String) -> Node:
	# Try direct path first.
	var direct: Node = get_node_or_null("/root/GameWorld/" + target_name)
	if direct != null:
		return direct
	direct = get_node_or_null("/root/GameWorld/World/" + target_name)
	if direct != null:
		return direct

	# Recursive search.
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_recursive(scene, target_name)


func _find_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_recursive(child, target_name)
		if result != null:
			return result
	return null
