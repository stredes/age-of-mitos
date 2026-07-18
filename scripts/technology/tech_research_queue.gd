## Research queue for buildings that support technology research (university, market).
## Handles queuing multiple technologies and processing them sequentially.
class_name TechResearchQueue
extends Node

signal research_started(tech_id: String, player_id: int, building_id: int)
signal research_completed(tech_id: String, player_id: int, building_id: int)
signal queue_updated(player_id: int, queue: Array)

const MAX_QUEUE_SIZE: int = 5

var _queues: Dictionary = {}
var _current_research: Dictionary = {}
var _research_progress: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_update_research(delta)

func queue_research(building_id: int, tech_id: String, player_id: int) -> bool:
	if not _queues.has(player_id):
		_queues[player_id] = []

	var queue: Array = _queues[player_id]
	if queue.size() >= MAX_QUEUE_SIZE:
		return false

	var building: Node = _get_building(building_id)
	if not building:
		return false

	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	if tech_data.is_empty():
		return false

	var item: Dictionary = {
		"tech_id": tech_id,
		"building_id": building_id,
		"progress": 0.0,
		"total_time": tech_data.get("research_time", 30.0),
	}
	queue.append(item)
	_queues[player_id] = queue
	queue_updated.emit(player_id, queue.duplicate(true))
	return true

func dequeue(player_id: int) -> String:
	if not _queues.has(player_id):
		return ""
	var queue: Array = _queues[player_id]
	if queue.is_empty():
		return ""
	var item: Dictionary = queue.pop_front()
	_queues[player_id] = queue
	queue_updated.emit(player_id, queue.duplicate(true))
	return item.get("tech_id", "")

func cancel_research(building_id: int) -> void:
	for player_id: int in _queues:
		var queue: Array = _queues[player_id]
		for i in range(queue.size()):
			if queue[i].get("building_id") == building_id:
				queue.remove_at(i)
				_queues[player_id] = queue
				queue_updated.emit(player_id, queue.duplicate(true))
				break

func cancel_last(player_id: int) -> void:
	if not _queues.has(player_id):
		return
	var queue: Array = _queues[player_id]
	if queue.size() > 0:
		queue.pop_back()
		_queues[player_id] = queue
		queue_updated.emit(player_id, queue.duplicate(true))

func get_queue(player_id: int) -> Array:
	return _queues.get(player_id, []).duplicate(true)

func get_queue_size(player_id: int) -> int:
	if not _queues.has(player_id):
		return 0
	return _queues[player_id].size()

func clear_player_queue(player_id: int) -> void:
	if _queues.has(player_id):
		_queues.erase(player_id)
		queue_updated.emit(player_id, [])

func _update_research(delta: float) -> void:
	var speed: float = GameManager.get_speed()
	for player_id: int in _queues:
		if _current_research.has(player_id):
			continue
		var queue: Array = _queues[player_id]
		if queue.is_empty():
			continue

		var item: Dictionary = queue[0]
		var building: Node = _get_building(item["building_id"])
		if not building or building.get("is_constructed") != true:
			continue

		_current_research[player_id] = item.duplicate()
		_research_progress[player_id] = 0.0
		research_started.emit(item["tech_id"], player_id, item["building_id"])
		EventBus.tech_started.emit(item["tech_id"], player_id, item["total_time"])
		queue.pop_front()
		_queues[player_id] = queue
		queue_updated.emit(player_id, queue.duplicate(true))

	for player_id: int in _current_research:
		if not _current_research.has(player_id):
			continue
		var item: Dictionary = _current_research[player_id]
		var progress: float = _research_progress.get(player_id, 0.0)
		progress += delta * speed
		_research_progress[player_id] = progress

		if progress >= item["total_time"]:
			var tech_id: String = item["tech_id"]
			var building_id: int = item["building_id"]
			_current_research.erase(player_id)
			_research_progress.erase(player_id)
			research_completed.emit(tech_id, player_id, building_id)
			EventBus.tech_completed.emit(tech_id, player_id)
		else:
			var pct: float = progress / item["total_time"]
			EventBus.tech_progress.emit(item["tech_id"], player_id, pct)

func get_current_research(player_id: int) -> Dictionary:
	return _current_research.get(player_id, {})

func get_research_progress(player_id: int) -> float:
	if not _current_research.has(player_id):
		return 0.0
	var item: Dictionary = _current_research[player_id]
	var progress: float = _research_progress.get(player_id, 0.0)
	var total: float = item.get("total_time", 1.0)
	if total <= 0.0:
		return 0.0
	return clampf(progress / total, 0.0, 1.0)

func is_researching(player_id: int) -> bool:
	return _current_research.has(player_id)

func _get_building(building_id: int) -> Node:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm and bm.has_method("get_building"):
		return bm.get_building(building_id)
	return null