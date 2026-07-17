## Manages production queues for all buildings. Each building can queue multiple
## units or technologies; items are processed sequentially with progress tracking.
class_name ProductionQueue
extends Node

# =============================================================================
# Signals
# =============================================================================

signal production_complete(building_id: int, item_type: String)
signal queue_updated(building_id: int, queue: Array)
signal rally_point_set(building_id: int, position: Vector2)

# =============================================================================
# Constants
# =============================================================================

const MAX_QUEUE_SIZE: int = 5

# =============================================================================
# Properties
# =============================================================================

var queues: Dictionary = {}

## Rally points per building. Key: building_id, Value: Vector2.
var rally_points: Dictionary = {}

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_connect_event_bus()


func _process(delta: float) -> void:
	var ids: Array = queues.keys()
	for building_id: int in ids:
		if queues.has(building_id):
			update_production(building_id, delta)

# =============================================================================
# Setup
# =============================================================================

func _connect_event_bus() -> void:
	if not EventBus.building_destroyed.is_connected(_on_building_destroyed):
		EventBus.building_destroyed.connect(_on_building_destroyed)
	if not EventBus.construction_completed.is_connected(_on_construction_completed):
		EventBus.construction_completed.connect(_on_construction_completed)

# =============================================================================
# Queue Management
# =============================================================================

func add_to_queue(building_id: int, item_type: String) -> bool:
	if not _is_building_producible(building_id, item_type):
		return false

	if not queues.has(building_id):
		queues[building_id] = []

	var queue: Array = queues[building_id]
	if queue.size() >= MAX_QUEUE_SIZE:
		return false

	var total_time: float = _get_production_time(building_id, item_type)
	if total_time <= 0.0:
		return false

	var item: Dictionary = {
		"type": item_type,
		"progress": 0.0,
		"total_time": total_time,
	}
	queue.append(item)
	queues[building_id] = queue

	# Deduct cost from player resources.
	var building: Node2D = _get_building(building_id)
	if building and building.has_method("get"):
		var pid: int = building.get("player_id") if building.get("player_id") != null else -1
		var cost: Dictionary = _get_item_cost(building_id, item_type)
		if cost.size() > 0 and pid != -1:
			GameManager.spend_resources(cost, pid)

	queue_updated.emit(building_id, queue)
	return true


func cancel_last(building_id: int) -> void:
	if not queues.has(building_id):
		return
	var queue: Array = queues[building_id]
	if queue.is_empty():
		return

	# Refund the last queued item if it hasn't started producing yet.
	if queue.size() > 1:
		var last_item: Dictionary = queue[-1]
		_refund_item(building_id, last_item["type"])

	queue.pop_back()
	queues[building_id] = queue
	queue_updated.emit(building_id, queue)


func cancel_all(building_id: int) -> void:
	if not queues.has(building_id):
		return
	var queue: Array = queues[building_id]

	# Refund all items except the one currently producing.
	for i in range(1, queue.size()):
		_refund_item(building_id, queue[i]["type"])

	queues[building_id] = []
	queue_updated.emit(building_id, [])

# =============================================================================
# Query
# =============================================================================

func get_queue(building_id: int) -> Array:
	return queues.get(building_id, []).duplicate(true)


func get_queue_progress(building_id: int) -> float:
	if not queues.has(building_id):
		return 0.0
	var queue: Array = queues[building_id]
	if queue.is_empty():
		return 0.0
	var first: Dictionary = queue[0]
	var total: float = first["total_time"]
	if total <= 0.0:
		return 0.0
	return clampf(first["progress"] / total, 0.0, 1.0)


func get_queue_size(building_id: int) -> int:
	if not queues.has(building_id):
		return 0
	return queues[building_id].size()

# =============================================================================
# Rally Point
# =============================================================================

## Set the rally point for a building. Produced units will walk here after spawning.
func set_rally_point(building_id: int, position: Vector2) -> void:
	rally_points[building_id] = position
	rally_point_set.emit(building_id, position)


## Get the rally point for a building, or the building's position if unset.
func get_rally_point(building_id: int) -> Vector2:
	if rally_points.has(building_id):
		return rally_points[building_id]
	var building: Node2D = _get_building(building_id)
	if building != null:
		return building.global_position
	return Vector2.ZERO


func clear_rally_point(building_id: int) -> void:
	rally_points.erase(building_id)

# =============================================================================
# Production Update
# =============================================================================

func update_production(building_id: int, delta: float) -> void:
	if not queues.has(building_id):
		return
	var queue: Array = queues[building_id]
	if queue.is_empty():
		return

	var first: Dictionary = queue[0]
	first["progress"] += delta

	if first["progress"] >= first["total_time"]:
		var completed_type: String = first["type"]
		queue.pop_front()

		# Produce the item.
		_on_item_produced(building_id, completed_type)

		production_complete.emit(building_id, completed_type)
		queue_updated.emit(building_id, queue)

		if queue.is_empty():
			queues.erase(building_id)

# =============================================================================
# Item Production Callback
# =============================================================================

func _on_item_produced(building_id: int, item_type: String) -> void:
	var building: Node2D = _get_building(building_id)
	if building == null:
		return

	# Check if the item is a unit.
	var unit_data: Dictionary = DataManager.get_unit_data(item_type)
	if not unit_data.is_empty():
		_spawn_unit(building_id, building, item_type)
		return

	# Check if it's a technology.
	var tech_data: Dictionary = DataManager.get_tech_data(item_type)
	if not tech_data.is_empty():
		_apply_technology(building_id, building, item_type)
		return


func _spawn_unit(building_id: int, building: Node2D, unit_type: String) -> void:
	var player_id: int = -1
	if building.has_method("get"):
		player_id = building.get("player_id") if building.get("player_id") != null else -1

	if player_id == -1:
		return

	var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
	var pop_add: int = unit_data.get("pop_add", 1)

	var spawn_offset: Vector2 = Vector2(randf_range(-32.0, 32.0), randf_range(24.0, 64.0))
	var final_pos: Vector2 = building.global_position + spawn_offset

	var unit_id: int = randi()
	EventBus.unit_spawned.emit(unit_id, unit_type, player_id, final_pos)

	# Send unit to rally point after a short delay.
	var rally: Vector2 = get_rally_point(building_id)
	if rally.distance_to(final_pos) > 16.0:
		call_deferred("_send_unit_to_rally", unit_id, rally)


func _send_unit_to_rally(unit_id: int, rally_pos: Vector2) -> void:
	await get_tree().create_timer(0.3).timeout

	var unit_manager: Node = get_node_or_null("/root/GameWorld/UnitManager")
	if unit_manager == null:
		unit_manager = get_node_or_null("/root/GameWorld/World/UnitManager")
	if unit_manager == null:
		return

	var unit_node: Node2D = null
	if unit_manager.has_method("get_unit"):
		unit_node = unit_manager.get_unit(unit_id)

	if unit_node == null or not is_instance_valid(unit_node):
		return

	var move_comp: Node = unit_node.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_method("move_to"):
		move_comp.move_to(rally_pos)


func _apply_technology(building_id: int, _building: Node2D, tech_id: String) -> void:
	var player_id: int = -1
	var b: Node2D = _get_building(building_id)
	if b and b.has_method("get"):
		player_id = b.get("player_id") if b.get("player_id") != null else -1
	if player_id == -1:
		return
	EventBus.tech_completed.emit(tech_id, player_id)
	EventBus.tech_researched.emit(tech_id, player_id)

# =============================================================================
# Helpers
# =============================================================================

func _is_building_producible(building_id: int, item_type: String) -> bool:
	var building: Node2D = _get_building(building_id)
	if building == null:
		return false
	if building.has_method("can_produce"):
		return building.can_produce(item_type)

	# Fallback: check data directly.
	var b_data: Dictionary = _get_building_data(building_id)
	var produces: Array = b_data.get("produces", [])
	return item_type in produces


func _get_production_time(building_id: int, item_type: String) -> float:
	var unit_data: Dictionary = DataManager.get_unit_data(item_type)
	if not unit_data.is_empty():
		return unit_data.get("build_time", 10.0)

	var tech_data: Dictionary = DataManager.get_tech_data(item_type)
	if not tech_data.is_empty():
		return tech_data.get("research_time", 30.0)

	return 0.0


func _get_item_cost(building_id: int, item_type: String) -> Dictionary:
	var unit_data: Dictionary = DataManager.get_unit_data(item_type)
	if not unit_data.is_empty():
		return unit_data.get("cost", {})

	var tech_data: Dictionary = DataManager.get_tech_data(item_type)
	if not tech_data.is_empty():
		return tech_data.get("cost", {})

	return {}


func _refund_item(building_id: int, item_type: String) -> void:
	var cost: Dictionary = _get_item_cost(building_id, item_type)
	if cost.is_empty():
		return
	var building: Node2D = _get_building(building_id)
	if building and building.has_method("get"):
		var pid: int = building.get("player_id") if building.get("player_id") != null else -1
		if pid != -1:
			for resource_type: String in cost:
				GameManager.add_resource(resource_type, cost[resource_type], pid)


func _get_building(building_id: int) -> Node2D:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm and bm.has_method("get_building"):
		return bm.get_building(building_id)
	return null


func _get_building_data(building_id: int) -> Dictionary:
	var building: Node2D = _get_building(building_id)
	if building and building.has_method("get") and building.get("building_type") != null:
		return DataManager.get_building_data(building.get("building_type"))
	return {}

# =============================================================================
# Event Bus Handlers
# =============================================================================

func _on_building_destroyed(building_id: int, _player_id: int, _destroyer_id: int) -> void:
	if queues.has(building_id):
		var queue: Array = queues[building_id]
		for i in range(1, queue.size()):
			_refund_item(building_id, queue[i]["type"])
		queues.erase(building_id)
	rally_points.erase(building_id)


func _on_construction_completed(building_id: int, _player_id: int) -> void:
	pass
