## Manages resource economy for all players. Tracks resource amounts, gather rates,
## resource collection, drop-off, and provides cost checking and spending.
## FASE B: Added income tracking, idle villager detection, auto drop-off logic.
class_name ResourceManager
extends Node

# =============================================================================
# Signals
# =============================================================================

## Emitted when a resource amount changes.
signal resource_updated(resource_type: String, amount: int, player_id: int)

## Emitted when a villager becomes idle.
signal villager_idle_detected(villager_id: int, player_id: int)

## Emitted when resources are auto-dropped off at a building.
signal auto_drop_off_completed(villager_id: int, drop_off_building_id: int, resource_type: String, amount: int)

# =============================================================================
# Constants
# =============================================================================

const BASE_GATHER_RATES: Dictionary = {
	"wood": 0.39,
	"stone": 0.39,
	"food": 0.39,
	"gold": 0.39,
}

const CARRY_CAPACITY: Dictionary = {
	"villager": 10,
	"lumberjack": 12,
	"miner": 8,
	"builder": 6,
}

## Resource types that can be gathered.
const GATHERABLE_RESOURCES: Array[String] = ["wood", "stone", "food", "gold"]

## Drop-off building types per resource type.
const DROP_OFF_BUILDINGS: Dictionary = {
	"wood": ["lumber_camp", "town_center"],
	"stone": ["mine", "town_center"],
	"gold": ["mine", "town_center"],
	"food": ["mill", "town_center"],
}

## Income tracking interval in seconds.
const INCOME_TRACK_INTERVAL: float = 1.0

## Idle detection threshold in seconds.
const IDLE_DETECTION_INTERVAL: float = 5.0

# =============================================================================
# Properties
# =============================================================================

var global_resources: Dictionary = {}

var gather_rates: Dictionary = {}
var gather_rate_modifiers: Dictionary = {}

var _player_buffers: Dictionary = {}

## Income tracking: {player_id: {resource_type: {current_income: float, last_amount: int, last_time: float}}}
var _income_tracking: Dictionary = {}

## Idle villager tracking: {player_id: {villager_id: {last_activity_time: float, state: String}}}
var _villager_activity: Dictionary = {}

## Auto drop-off tracking: {villager_id: {resource_type: String, amount: int, target_building: Node2D}}
var _auto_drop_off_queue: Dictionary = {}

var _income_timer: float = 0.0
var _idle_check_timer: float = 0.0

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_connect_event_bus()


func _process(delta: float) -> void:
	_income_timer += delta
	if _income_timer >= INCOME_TRACK_INTERVAL:
		_update_income_tracking()
		_income_timer = 0.0

	_idle_check_timer += delta
	if _idle_check_timer >= IDLE_DETECTION_INTERVAL:
		_check_idle_villagers()
		_idle_check_timer = 0.0

	_process_auto_drop_off_queue()

# =============================================================================
# Setup
# =============================================================================

func _connect_event_bus() -> void:
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)
	if not EventBus.resource_collected.is_connected(_on_resource_collected):
		EventBus.resource_collected.connect(_on_resource_collected)
	if not EventBus.resource_drop_off.is_connected(_on_resource_drop_off):
		EventBus.resource_drop_off.connect(_on_resource_drop_off)
	if not EventBus.unit_spawned.is_connected(_on_unit_spawned):
		EventBus.unit_spawned.connect(_on_unit_spawned)
	if not EventBus.unit_state_changed.is_connected(_on_unit_state_changed):
		EventBus.unit_state_changed.connect(_on_unit_state_changed)
	if not EventBus.building_completed.is_connected(_on_building_completed):
		EventBus.building_completed.connect(_on_building_completed)
	if not EventBus.unit_deselected.is_connected(_on_unit_deselected):
		EventBus.unit_deselected.connect(_on_unit_deselected)

# =============================================================================
# Initialization
# =============================================================================

func _on_game_started(player_id: int) -> void:
	_initialize_all_players()


func _initialize_all_players() -> void:
	var all_ids: Array = GameManager.get_all_player_ids()
	for pid_variant: Variant in all_ids:
		var pid: int = pid_variant if pid_variant is int else int(pid_variant)
		_initialize_player(pid)


func _initialize_player(player_id: int) -> void:
	var player_data: Dictionary = GameManager.get_player(player_id)
	if player_data.is_empty():
		return

	global_resources[player_id] = player_data.get("resources", {}).duplicate()

	gather_rates[player_id] = {}
	gather_rate_modifiers[player_id] = {}
	for resource_type: String in BASE_GATHER_RATES:
		gather_rates[player_id][resource_type] = BASE_GATHER_RATES[resource_type]
		gather_rate_modifiers[player_id][resource_type] = 1.0

	_player_buffers[player_id] = {}
	_income_tracking[player_id] = {}
	_villager_activity[player_id] = {}
	_auto_drop_off_queue[player_id] = {}

	for resource_type: String in global_resources[player_id]:
		var amount: int = global_resources[player_id][resource_type]
		_income_tracking[player_id][resource_type] = {
			"current_income": 0.0,
			"last_amount": amount,
			"last_time": Time.get_ticks_msec() / 1000.0
		}
		resource_updated.emit(resource_type, amount, player_id)

# =============================================================================
# Resource Collection
# =============================================================================

func _on_resource_collected(resource_type: String, amount: int, collector_id: int, player_id: int) -> void:
	_add_to_buffer(player_id, resource_type, amount)
	_record_villager_activity(collector_id, player_id, "gathering")


func _on_resource_drop_off(villager_id: int, drop_off_id: int, resource_type: String, amount: int) -> void:
	var player_id: int = _get_villager_player_id(villager_id)
	if player_id == -1:
		return

	_add_to_buffer(player_id, resource_type, amount)
	_record_villager_activity(villager_id, player_id, "drop_off")

	# Track auto drop-off
	if villager_id in _auto_drop_off_queue.get(player_id, {}):
		_auto_drop_off_queue[player_id].erase(villager_id)
	auto_drop_off_completed.emit(villager_id, drop_off_id, resource_type, amount)


func _on_unit_state_changed(unit_id: int, player_id: int, old_state: String, new_state: String) -> void:
	# Track villager state changes for idle detection
	if player_id not in _villager_activity:
		_villager_activity[player_id] = {}
	if unit_id not in _villager_activity[player_id]:
		_villager_activity[player_id][unit_id] = {"last_activity_time": Time.get_ticks_msec() / 1000.0, "state": new_state}
	else:
		_villager_activity[player_id][unit_id]["last_activity_time"] = Time.get_ticks_msec() / 1000.0
		_villager_activity[player_id][unit_id]["state"] = new_state


func _on_unit_spawned(unit_id: int, unit_type: String, player_id: int, _position: Vector2) -> void:
	# Initialize villager activity tracking for new villagers
	if unit_type in ["villager", "lumberjack", "miner", "builder"]:
		if player_id not in _villager_activity:
			_villager_activity[player_id] = {}
		_villager_activity[player_id][unit_id] = {
			"last_activity_time": Time.get_ticks_msec() / 1000.0,
			"state": "idle"
		}

	var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
	if unit_data.is_empty():
		return

	var cost: Dictionary = unit_data.get("cost", {})
	if cost.is_empty():
		return

	for resource_type: String in cost:
		var amount: int = cost[resource_type]
		GameManager.spend_resource(resource_type, amount, player_id)
		_update_local_cache(player_id, resource_type)
		resource_updated.emit(resource_type, get_resource_amount(resource_type, player_id), player_id)


func _on_building_completed(building_id: int, building_type: String, player_id: int) -> void:
	# When a new drop-off building is completed, check for queued auto drop-offs
	_process_pending_auto_drop_offs(player_id, building_type)


func _on_unit_deselected(unit_id: int, player_id: int) -> void:
	# Check if deselected villager should auto-return resources
	_try_auto_return_resources(unit_id, player_id)

# =============================================================================
# Income Tracking
# =============================================================================

func _update_income_tracking() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	for player_id: int in _income_tracking:
		for resource_type: String in _income_tracking[player_id]:
			var tracking: Dictionary = _income_tracking[player_id][resource_type]
			var current_amount: int = get_resource_amount(resource_type, player_id)
			var last_amount: int = tracking.get("last_amount", current_amount)
			var last_time: float = tracking.get("last_time", current_time)

			var time_diff: float = current_time - last_time
			if time_diff > 0.0:
				var income_per_second: float = float(current_amount - last_amount) / time_diff
				tracking["current_income"] = income_per_second * 60.0 # Per minute
				tracking["last_amount"] = current_amount
				tracking["last_time"] = current_time


func get_resource_income_per_minute(resource_type: String, player_id: int) -> float:
	if player_id not in _income_tracking:
		return 0.0
	if resource_type not in _income_tracking[player_id]:
		return 0.0
	return _income_tracking[player_id][resource_type].get("current_income", 0.0)


func get_all_resource_income(player_id: int) -> Dictionary:
	var result: Dictionary = {}
	if player_id not in _income_tracking:
		return result
	for resource_type: String in _income_tracking[player_id]:
		result[resource_type] = _income_tracking[player_id][resource_type].get("current_income", 0.0)
	return result


func get_total_income_per_minute(player_id: int) -> float:
	var total: float = 0.0
	var income_data: Dictionary = get_all_resource_income(player_id)
	for resource_type: String in income_data:
		total += income_data[resource_type]
	return total

# =============================================================================
# Idle Villager Detection
# =============================================================================

func _check_idle_villagers() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	for player_id: int in _villager_activity:
		var villagers: Dictionary = _villager_activity[player_id]
		for villager_id: int in villagers:
			var data: Dictionary = villagers[villager_id]
			var last_activity: float = data.get("last_activity_time", current_time)
			var state: String = data.get("state", "idle")

			# Consider a villager idle if they've been in "idle" state for > IDLE_DETECTION_INTERVAL
			# and are not currently moving/working
			if state == "idle" and (current_time - last_activity) >= IDLE_DETECTION_INTERVAL:
				villager_idle_detected.emit(villager_id, player_id)


func _record_villager_activity(villager_id: int, player_id: int, activity: String) -> void:
	if player_id not in _villager_activity:
		_villager_activity[player_id] = {}
	if villager_id not in _villager_activity[player_id]:
		_villager_activity[player_id][villager_id] = {"last_activity_time": 0.0, "state": "idle"}

	_villager_activity[player_id][villager_id]["last_activity_time"] = Time.get_ticks_msec() / 1000.0
	_villager_activity[player_id][villager_id]["state"] = activity


func get_idle_villagers(player_id: int) -> Array[int]:
	var result: Array[int] = []
	if player_id not in _villager_activity:
		return result

	var current_time: float = Time.get_ticks_msec() / 1000.0
	for villager_id: int in _villager_activity[player_id]:
		var data: Dictionary = _villager_activity[player_id][villager_id]
		var last_activity: float = data.get("last_activity_time", current_time)
		var state: String = data.get("state", "idle")

		if state == "idle" and (current_time - last_activity) >= IDLE_DETECTION_INTERVAL:
			result.append(villager_id)

	return result


func get_idle_villager_count(player_id: int) -> int:
	return get_idle_villagers(player_id).size()


func is_villager_idle(villager_id: int, player_id: int) -> bool:
	if player_id not in _villager_activity:
		return false
	if villager_id not in _villager_activity[player_id]:
		return false

	var data: Dictionary = _villager_activity[player_id][villager_id]
	var last_activity: float = data.get("last_activity_time", 0.0)
	var state: String = data.get("state", "idle")
	var current_time: float = Time.get_ticks_msec() / 1000.0

	return state == "idle" and (current_time - last_activity) >= IDLE_DETECTION_INTERVAL


func get_villager_state(villager_id: int, player_id: int) -> String:
	if player_id not in _villager_activity:
		return "unknown"
	if villager_id not in _villager_activity[player_id]:
		return "unknown"
	return _villager_activity[player_id][villager_id].get("state", "unknown")

# =============================================================================
# Public API for Auto Drop-Off
# =============================================================================

## Queue an automatic drop-off for a villager carrying resources.
## Called by HarvestComponent when villager reaches carry capacity.
func queue_auto_drop_off(villager_id: int, player_id: int, resource_type: String, amount: int) -> void:
	_queue_auto_drop_off(villager_id, player_id, resource_type, amount)


# =============================================================================
# Auto Drop-Off Logic (Internal)
# =============================================================================

func _try_auto_return_resources(villager_id: int, player_id: int) -> void:
	# Check if villager has resources to drop off
	var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
	for v: Node in villagers:
		if v.has_method("get") and v.get("unit_id") == villager_id:
			var harvest_comp: Node = v.get_node_or_null("HarvestComponent")
			if harvest_comp != null and harvest_comp.has_method("get_carried_amount"):
				var carried: int = harvest_comp.get_carried_amount()
				var resource_type: String = harvest_comp.get_carried_resource_type()
				if carried > 0 and not resource_type.is_empty():
					_queue_auto_drop_off(villager_id, player_id, resource_type, carried)
			break


func _queue_auto_drop_off(villager_id: int, player_id: int, resource_type: String, amount: int) -> void:
	if player_id not in _auto_drop_off_queue:
		_auto_drop_off_queue[player_id] = {}

	var drop_off_types: Array[String] = DROP_OFF_BUILDINGS.get(resource_type, ["town_center"])
	var target_building: Node2D = _find_nearest_drop_off_building(villager_id, player_id, drop_off_types)

	if target_building != null:
		_auto_drop_off_queue[player_id][villager_id] = {
			"resource_type": resource_type,
			"amount": amount,
			"target_building": target_building,
			"started_at": Time.get_ticks_msec() / 1000.0
		}
	else:
		# No drop-off building available yet, queue for later
		_auto_drop_off_queue[player_id][villager_id] = {
			"resource_type": resource_type,
			"amount": amount,
			"target_building": null,
			"pending_building_type": drop_off_types,
			"started_at": Time.get_ticks_msec() / 1000.0
		}


func _find_nearest_drop_off_building(villager_id: int, player_id: int, building_types: Array[String]) -> Node2D:
	var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
	var villager_node: Node2D = null
	for v: Node in villagers:
		if v.has_method("get") and v.get("unit_id") == villager_id:
			villager_node = v as Node2D
			break

	if villager_node == null:
		return null

	var best: Node2D = null
	var best_dist: float = INF
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	var candidates: Array[Node] = []
	_find_drop_off_buildings_recursive(scene, candidates, building_types, player_id)

	for node: Node in candidates:
		if node is Node2D:
			var bld: Node2D = node as Node2D
			var dist: float = villager_node.global_position.distance_to(bld.global_position)
			if dist < best_dist:
				best_dist = dist
				best = bld

	return best


func _find_drop_off_buildings_recursive(node: Node, results: Array[Node], building_types: Array[String], player_id: int) -> void:
	if node.has_method("get_building_type"):
		var bld_type: String = node.get_building_type()
		if bld_type in building_types:
			var bld_player: int = node.get("player_id") if node.has_method("get") and node.get("player_id") != null else -2
			if bld_player == player_id or player_id == -1:
				results.append(node)
	elif node.get("building_type") != null and node.get("building_type") in building_types:
		var bld_player: int = node.get("player_id") if node.has_method("get") and node.get("player_id") != null else -2
		if bld_player == player_id or player_id == -1:
			results.append(node)

	for child: Node in node.get_children():
		_find_drop_off_buildings_recursive(child, results, building_types, player_id)


func _process_auto_drop_off_queue() -> void:
	for player_id: int in _auto_drop_off_queue:
		var queue: Dictionary = _auto_drop_off_queue[player_id]
		var to_remove: Array[int] = []

		for villager_id: int in queue:
			var entry: Dictionary = queue[villager_id]
			var target_building: Node2D = entry.get("target_building")

			# If no target building yet, try to find one
			if target_building == null:
				var pending_types: Array[String] = entry.get("pending_building_type", [])
				var new_target: Node2D = _find_nearest_drop_off_building(villager_id, player_id, pending_types)
				if new_target != null:
					entry["target_building"] = new_target
					target_building = new_target

			# If we have a target, send the villager there
			if target_building != null and is_instance_valid(target_building):
				# Send command to villager to move to drop-off building
				var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
				for v: Node in villagers:
					if v.has_method("get") and v.get("unit_id") == villager_id:
						if v.has_method("move_to_drop_off"):
							v.move_to_drop_off(target_building)
						break
				to_remove.append(villager_id)

		for vid: int in to_remove:
			queue.erase(vid)


func _process_pending_auto_drop_offs(player_id: int, completed_building_type: String) -> void:
	if player_id not in _auto_drop_off_queue:
		return

	var queue: Dictionary = _auto_drop_off_queue[player_id]
	for villager_id: int in queue:
		var entry: Dictionary = queue[villager_id]
		if entry.get("target_building") == null and entry.get("pending_building_type"):
			var pending_types: Array[String] = entry.get("pending_building_type", [])
			if completed_building_type in pending_types:
				# Re-try finding the building
				var new_target: Node2D = _find_nearest_drop_off_building(villager_id, player_id, pending_types)
				if new_target != null:
					entry["target_building"] = new_target

# =============================================================================
# Buffer System
# =============================================================================

func _add_to_buffer(player_id: int, resource_type: String, amount: int) -> void:
	if player_id not in _player_buffers:
		_player_buffers[player_id] = {}
	if resource_type not in _player_buffers[player_id]:
		_player_buffers[player_id][resource_type] = 0

	_player_buffers[player_id][resource_type] += amount


func flush_buffers(player_id: int) -> void:
	if player_id not in _player_buffers:
		return

	for resource_type: String in _player_buffers[player_id]:
		var buffered: int = _player_buffers[player_id][resource_type]
		if buffered > 0:
			GameManager.add_resource(resource_type, buffered, player_id)
			_update_local_cache(player_id, resource_type)

	_player_buffers[player_id].clear()


func flush_buffer(player_id: int, resource_type: String) -> void:
	if player_id not in _player_buffers:
		return
	if resource_type not in _player_buffers[player_id]:
		return

	var buffered: int = _player_buffers[player_id][resource_type]
	if buffered > 0:
		GameManager.add_resource(resource_type, buffered, player_id)
		_update_local_cache(player_id, resource_type)

	_player_buffers[player_id][resource_type] = 0


func _update_local_cache(player_id: int, resource_type: String) -> void:
	if player_id not in global_resources:
		global_resources[player_id] = {}
	global_resources[player_id][resource_type] = GameManager.get_resource(resource_type, player_id)

# =============================================================================
# Gather Rates
# =============================================================================

func get_gather_rate(resource_type: String, player_id: int) -> float:
	if player_id not in gather_rates:
		return 0.0
	var base_rate: float = gather_rates[player_id].get(resource_type, 0.0)
	var modifier: float = gather_rate_modifiers.get(player_id, {}).get(resource_type, 1.0)
	return base_rate * modifier


func set_gather_rate_modifier(resource_type: String, modifier: float, player_id: int) -> void:
	if player_id not in gather_rate_modifiers:
		gather_rate_modifiers[player_id] = {}
	gather_rate_modifiers[player_id][resource_type] = modifier


func set_gather_rate_base(resource_type: String, rate: float, player_id: int) -> void:
	if player_id not in gather_rates:
		gather_rates[player_id] = {}
	gather_rates[player_id][resource_type] = rate


func get_carry_capacity(unit_type: String) -> int:
	return CARRY_CAPACITY.get(unit_type, 10)

# =============================================================================
# Cost Checking & Spending
# =============================================================================

func can_afford(cost: Dictionary, player_id: int) -> bool:
	_flush_pending(player_id)

	var player_res: Dictionary = global_resources.get(player_id, {})
	for resource_type: String in cost:
		var required: int = cost[resource_type]
		var available: int = player_res.get(resource_type, 0)
		if available < required:
			return false
	return true


func spend(cost: Dictionary, player_id: int) -> bool:
	if not can_afford(cost, player_id):
		return false

	for resource_type: String in cost:
		var amount: int = cost[resource_type]
		var buffered: int = _get_buffered(player_id, resource_type)
		if buffered >= amount:
			_player_buffers[player_id][resource_type] = buffered - amount
		else:
			_player_buffers[player_id][resource_type] = 0
			var remaining: int = amount - buffered
			GameManager.spend_resource(resource_type, remaining, player_id)

		_update_local_cache(player_id, resource_type)
		resource_updated.emit(resource_type, get_resource_amount(resource_type, player_id), player_id)

	return true

# =============================================================================
# Resource Query
# =============================================================================

func get_resource_amount(resource_type: String, player_id: int) -> int:
	_flush_pending(player_id)
	return global_resources.get(player_id, {}).get(resource_type, 0)


func get_all_resources(player_id: int) -> Dictionary:
	_flush_pending(player_id)
	return global_resources.get(player_id, {}).duplicate()


func get_buffered_amount(resource_type: String, player_id: int) -> int:
	return _get_buffered(player_id, resource_type)

# =============================================================================
# Helpers
# =============================================================================

func _flush_pending(player_id: int) -> void:
	flush_buffers(player_id)


func _get_buffered(player_id: int, resource_type: String) -> int:
	if player_id not in _player_buffers:
		return 0
	return _player_buffers[player_id].get(resource_type, 0)


func _get_villager_player_id(villager_id: int) -> int:
	var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
	for v: Node in villagers:
		if v.has_method("get") and v.get("unit_id") != null and v.get("unit_id") == villager_id:
			return v.get("player_id") if v.get("player_id") != null else -1
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for u: Node in units:
		if u.has_method("get") and u.get("unit_id") != null and u.get("unit_id") == villager_id:
			return u.get("player_id") if u.get("player_id") != null else -1
	return -1

# =============================================================================
# Technology Integration
# =============================================================================

func apply_tech_gather_bonus(resource_type: String, bonus_percent: float, player_id: int) -> void:
	var current_modifier: float = gather_rate_modifiers.get(player_id, {}).get(resource_type, 1.0)
	set_gather_rate_modifier(resource_type, current_modifier + bonus_percent, player_id)

# =============================================================================
# Serialization
# =============================================================================

func get_save_data() -> Dictionary:
	return {
		"global_resources": global_resources.duplicate(true),
		"gather_rates": gather_rates.duplicate(true),
		"gather_rate_modifiers": gather_rate_modifiers.duplicate(true),
		"income_tracking": _income_tracking.duplicate(true),
		"villager_activity": _villager_activity.duplicate(true),
	}

func load_save_data(data: Dictionary) -> void:
	global_resources = data.get("global_resources", {}).duplicate(true)
	gather_rates = data.get("gather_rates", {}).duplicate(true)
	gather_rate_modifiers = data.get("gather_rate_modifiers", {}).duplicate(true)
	_income_tracking = data.get("income_tracking", {}).duplicate(true)
	_villager_activity = data.get("villager_activity", {}).duplicate(true)

	for pid: int in global_resources:
		for resource_type: String in global_resources[pid]:
			resource_updated.emit(resource_type, global_resources[pid][resource_type], pid)

	# Initialize missing tracking for existing players
	var all_ids: Array = GameManager.get_all_player_ids()
	for pid_variant: Variant in all_ids:
		var pid: int = pid_variant if pid_variant is int else int(pid_variant)
		if pid not in _income_tracking:
			_income_tracking[pid] = {}
			for rt: String in GATHERABLE_RESOURCES:
				_income_tracking[pid][rt] = {"current_income": 0.0, "last_amount": 0, "last_time": Time.get_ticks_msec() / 1000.0}
		if pid not in _villager_activity:
			_villager_activity[pid] = {}
		if pid not in _auto_drop_off_queue:
			_auto_drop_off_queue[pid] = {}

# =============================================================================
# Convenience: Direct Add (for villager carry-drop)
# =============================================================================

func add_resource_direct(resource_type: String, amount: int, player_id: int) -> void:
	if amount <= 0:
		return
	GameManager.add_resource(resource_type, amount, player_id)
	_update_local_cache(player_id, resource_type)
	resource_updated.emit(resource_type, get_resource_amount(resource_type, player_id), player_id)

# =============================================================================
# Economy Summary (for UI)
# =============================================================================

func get_economy_summary(player_id: int) -> Dictionary:
	return {
		"resources": get_all_resources(player_id),
		"income_per_minute": get_all_resource_income(player_id),
		"total_income_per_minute": get_total_income_per_minute(player_id),
		"idle_villagers": get_idle_villagers(player_id),
		"idle_villager_count": get_idle_villager_count(player_id),
		"gather_rates": gather_rates.get(player_id, {}).duplicate(),
		"gather_modifiers": gather_rate_modifiers.get(player_id, {}).duplicate(),
	}