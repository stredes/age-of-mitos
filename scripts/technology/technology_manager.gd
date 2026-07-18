class_name TechnologyManager
extends Node

signal tech_research_started(tech_id: String, player_id: int, research_time: float)
signal tech_research_completed(tech_id: String, player_id: int)
signal tech_effect_applied(tech_id: String, player_id: int, effects: Dictionary)

var _researched_techs: Dictionary = {}
var _research_queue: Dictionary = {}
var _research_progress: Dictionary = {}

const MAX_RESEARCH_QUEUE: int = 5

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not EventBus.tech_completed.is_connected(_on_tech_completed):
		EventBus.tech_completed.connect(_on_tech_completed)

func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	for player_id: int in _research_queue.keys():
		_update_research(player_id, delta)

func research_technology(tech_id: String, building_id: int, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = GameManager.local_player_id
	if player_id == -1:
		return false

	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	if tech_data.is_empty():
		push_warning("TechnologyManager: Tech '%s' not found" % tech_id)
		return false

	if _is_researched(tech_id, player_id):
		return false

	if not _check_prerequisites(tech_id, player_id):
		EventBus.button_pressed.emit("prereq_not_met", player_id)
		return false

	var cost: Dictionary = tech_data.get("cost", {})
	if not GameManager.can_afford(cost, player_id):
		EventBus.button_pressed.emit("cant_afford", player_id)
		return false

	var building: Node = _get_building(building_id)
	if building == null:
		return false

	if not _can_building_research(building_id, tech_id):
		EventBus.button_pressed.emit("building_cant_research", player_id)
		return false

	if not _research_queue.has(player_id):
		_research_queue[player_id] = []
		if not _research_progress.has(player_id):
			_research_progress[player_id] = 0.0

	var queue: Array = _research_queue[player_id]
	if queue.size() >= MAX_RESEARCH_QUEUE:
		EventBus.button_pressed.emit("queue_full", player_id)
		return false

	GameManager.spend_resources(cost, player_id)

	var research_time: float = tech_data.get("research_time", 30.0)
	var item: Dictionary = {
		"tech_id": tech_id,
		"building_id": building_id,
		"total_time": research_time,
		"start_time": GameManager.game_time
	}
	queue.append(item)
	_research_queue[player_id] = queue

	if queue.size() == 1:
		_research_progress[player_id] = 0.0
		tech_research_started.emit(tech_id, player_id, research_time)
		EventBus.tech_started.emit(tech_id, player_id, research_time)

	return true

func cancel_research(player_id: int, index: int = -1) -> void:
	if not _research_queue.has(player_id):
		return
	var queue: Array = _research_queue[player_id]
	if queue.is_empty():
		return

	var removed_item: Dictionary
	if index == -1 or index >= queue.size():
		removed_item = queue.pop_back()
	else:
		removed_item = queue.remove_at(index)

	_research_queue[player_id] = queue
	_refund_research_cost(removed_item["tech_id"], player_id)

	if queue.is_empty():
		_research_progress.erase(player_id)
	else:
		_research_progress[player_id] = 0.0
		tech_research_started.emit(queue[0]["tech_id"], player_id, queue[0]["total_time"])
		EventBus.tech_started.emit(queue[0]["tech_id"], player_id, queue[0]["total_time"])

func _refund_research_cost(tech_id: String, player_id: int) -> void:
	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	var cost: Dictionary = tech_data.get("cost", {})
	for res_type: String in cost:
		GameManager.add_resource(res_type, cost[res_type], player_id)

func get_available_techs(building_id: int, player_id: int = -1) -> Array:
	if player_id == -1:
		player_id = GameManager.local_player_id

	var building: Node = _get_building(building_id)
	if building == null:
		return []

	var building_type: String = building.get("building_type") if building.get("building_type") != null else ""
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	var researchable: Array = building_data.get("researchable_techs", building_data.get("technologies", []))

	var available: Array = []
	for tech_id: String in researchable:
		if _is_researched(tech_id, player_id):
			continue
		var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
		if tech_data.is_empty():
			continue
		var can_research: bool = _check_prerequisites(tech_id, player_id)
		var can_afford: bool = GameManager.can_afford(tech_data.get("cost", {}), player_id)
		available.append({
			"id": tech_id,
			"tech_id": tech_id,
			"display_name": tech_data.get("display_name", tech_id.capitalize()),
			"description": tech_data.get("description", ""),
			"cost": tech_data.get("cost", {}),
			"research_time": tech_data.get("research_time", 30.0),
			"tier": tech_data.get("tier", 1),
			"effects": tech_data.get("effects", {}),
			"requires": tech_data.get("requires", []),
			"can_research": can_research,
			"can_afford": can_afford,
			"is_researched": false,
			"prereq_met": can_research
		})
	return available

func get_research_queue(player_id: int = -1) -> Array:
	if player_id == -1:
		player_id = GameManager.local_player_id
	return _research_queue.get(player_id, []).duplicate(true)

func get_research_progress(player_id: int = -1) -> float:
	if player_id == -1:
		player_id = GameManager.local_player_id
	if not _research_queue.has(player_id):
		return 0.0
	var queue: Array = _research_queue[player_id]
	if queue.is_empty():
		return 0.0
	var progress: float = _research_progress.get(player_id, 0.0)
	var total: float = queue[0].get("total_time", 1.0)
	if total <= 0.0:
		return 0.0
	return clampf(progress / total, 0.0, 1.0)

func get_current_research(player_id: int = -1) -> Dictionary:
	if player_id == -1:
		player_id = GameManager.local_player_id
	if not _research_queue.has(player_id):
		return {}
	var queue: Array = _research_queue[player_id]
	if queue.is_empty():
		return {}
	return queue[0].duplicate()

func is_researching(player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = GameManager.local_player_id
	if not _research_queue.has(player_id):
		return false
	return not _research_queue[player_id].is_empty()

func can_research(tech_id: String, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = GameManager.local_player_id
	if _is_researched(tech_id, player_id):
		return false
	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	if tech_data.is_empty():
		return false
	if not _check_prerequisites(tech_id, player_id):
		return false
	var cost: Dictionary = tech_data.get("cost", {})
	return GameManager.can_afford(cost, player_id)

func apply_tech_effects(tech_id: String, player_id: int) -> void:
	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	if tech_data.is_empty():
		return
	var effects: Dictionary = tech_data.get("effects", {})
	if effects.is_empty():
		return

	_researched_techs[player_id] = _researched_techs.get(player_id, {})
	_researched_techs[player_id][tech_id] = true

	var applied_effects: Dictionary = {}
	for effect_type: String in effects:
		var value: Variant = effects[effect_type]
		applied_effects[effect_type] = value
		_apply_effect_to_player(effect_type, value, player_id)

	tech_effect_applied.emit(tech_id, player_id, applied_effects)
	EventBus.tech_researched.emit(tech_id, player_id)

func _apply_effect_to_player(effect_type: String, value: Variant, player_id: int) -> void:
	match effect_type:
		"wood_gather_rate", "food_gather_rate", "farm_capacity", "farm_capacity", \
		"gold_gather_rate", "stone_gather_rate", "villager_speed", "carry_capacity":
			EventBus.tech_effect_gather_rate.emit(effect_type, value, player_id)
		"melee_attack", "ranged_attack", "tower_attack", "siege_attack":
			EventBus.tech_effect_attack.emit(effect_type, value, player_id)
		"cavalry_armor", "cavalry_hp", "building_hp", "building_armor", \
		"wall_hp", "tower_hp", "ranged_attack", "range", "siege_range":
			EventBus.tech_effect_armor.emit(effect_type, value, player_id)
		"train_speed", "build_speed_modifier":
			EventBus.tech_effect_production.emit(effect_type, value, player_id)
		_:
			EventBus.tech_effect_other.emit(effect_type, value, player_id)

func _check_prerequisites(tech_id: String, player_id: int) -> bool:
	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	var requires: Array = tech_data.get("requires", [])
	for req: Variant in requires:
		if req is String:
			if not _is_building_owned(req, player_id) and not _is_researched(req, player_id):
				return false
	return true

func _is_building_owned(building_type: String, player_id: int) -> bool:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm and bm.has_method("get_player_buildings"):
		var buildings: Array = bm.get_player_buildings(player_id)
		for b_id: int in buildings:
			var building: Node = bm.get_building(b_id)
			if building and building.get("building_type") == building_type:
				return true
	return false

func _is_researched(tech_id: String, player_id: int) -> bool:
	return _researched_techs.has(player_id) and _researched_techs[player_id].has(tech_id)

func _can_building_research(building_id: int, tech_id: String) -> bool:
	var building: Node = _get_building(building_id)
	if building == null:
		return false
	var building_type: String = building.get("building_type") if building.get("building_type") != null else ""
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	var researchable: Array = building_data.get("researchable_techs", building_data.get("technologies", []))
	return tech_id in researchable

func _update_research(player_id: int, delta: float) -> void:
	if not _research_queue.has(player_id):
		return
	var queue: Array = _research_queue[player_id]
	if queue.is_empty():
		return

	var progress: float = _research_progress.get(player_id, 0.0)
	var item: Dictionary = queue[0]
	var total_time: float = item.get("total_time", 1.0)

	progress += delta * GameManager.get_speed()
	_research_progress[player_id] = progress

	if progress >= total_time:
		var completed_tech: String = item["tech_id"]
		var building_id: int = item["building_id"]
		queue.pop_front()
		_research_queue[player_id] = queue
		_research_progress[player_id] = 0.0

		apply_tech_effects(completed_tech, player_id)
		tech_research_completed.emit(completed_tech, player_id)
		EventBus.tech_completed.emit(completed_tech, player_id)

		if not queue.is_empty():
			var next_item: Dictionary = queue[0]
			tech_research_started.emit(next_item["tech_id"], player_id, next_item["total_time"])
			EventBus.tech_started.emit(next_item["tech_id"], player_id, next_item["total_time"])

func _get_building(building_id: int) -> Node:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm and bm.has_method("get_building"):
		return bm.get_building(building_id)
	return null

func _on_tech_completed(tech_id: String, player_id: int) -> void:
	apply_tech_effects(tech_id, player_id)

func get_researched_techs(player_id: int = -1) -> Array:
	if player_id == -1:
		player_id = GameManager.local_player_id
	if not _researched_techs.has(player_id):
		return []
	return _researched_techs[player_id].keys()