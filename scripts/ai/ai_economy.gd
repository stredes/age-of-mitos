extends Node

signal economy_action(action: String, target: String)

var ai_player_id: int = -1
var personality: String = "balanced"

var _resource_priority: Array[String] = ["food", "wood", "gold", "stone"]

var _stockpile_targets: Dictionary = {
	"food": 200,
	"wood": 200,
	"gold": 100,
	"stone": 50,
}

var _ideal_ratios: Dictionary = {
	"balanced": {"food": 0.4, "wood": 0.3, "gold": 0.2, "stone": 0.1},
	"aggressive": {"food": 0.35, "wood": 0.25, "gold": 0.3, "stone": 0.1},
	"defensive": {"food": 0.45, "wood": 0.35, "gold": 0.1, "stone": 0.1},
}

var _last_balance_check: float = 0.0
const BALANCE_INTERVAL: float = 5.0


func initialize(player_id: int, ai_personality: String = "balanced") -> void:
	ai_player_id = player_id
	personality = ai_personality
	_update_resource_priority()


func _update_resource_priority() -> void:
	match personality:
		"aggressive":
			_resource_priority = ["food", "gold", "wood", "stone"]
		"defensive":
			_resource_priority = ["food", "wood", "stone", "gold"]
		_:
			_resource_priority = ["food", "wood", "gold", "stone"]


func manage_economy(delta: float) -> void:
	assign_idle_villagers()
	_rebalance_villagers()
	ensure_food_income()
	ensure_wood_income()
	ensure_gold_income()
	train_villagers()


func _rebalance_villagers() -> void:
	var distribution: Dictionary = get_villager_distribution()
	var total_villagers: int = _count_own_villagers()
	if total_villagers == 0:
		return

	var ratios: Dictionary = _ideal_ratios.get(personality, _ideal_ratios["balanced"])
	var overallocated: String = _find_overallocated_resource(distribution, total_villagers, ratios)

	if not overallocated.is_empty():
		_reassign_from_overallocated(overallocated, distribution, ratios)


func _find_overallocated_resource(distribution: Dictionary, total: int, ratios: Dictionary) -> String:
	var worst_ratio: float = 0.0
	var worst_resource: String = ""

	for resource_type: String in _resource_priority:
		var ideal: float = ratios.get(resource_type, 0.25)
		var actual: float = float(distribution.get(resource_type, 0)) / float(total) if total > 0 else 0.0
		if actual > ideal * 1.5 and actual > worst_ratio:
			worst_ratio = actual
			worst_resource = resource_type

	return worst_resource


func _reassign_from_overallocated(over_resource: String, distribution: Dictionary, ratios: Dictionary) -> void:
	var neediest: String = _find_needy_resource(distribution, ratios)
	if neediest.is_empty() or neediest == over_resource:
		return

	var workers_on_over: Array[Node] = _get_villagers_on_resource(over_resource)
	if workers_on_over.is_empty():
		return

	var worker: Node = workers_on_over[workers_on_over.size() - 1]
	var resource_nodes: Array[Node] = _get_available_resources()
	var matching: Array[Node] = []
	for res: Node in resource_nodes:
		var rtype: String = res.get("resource_type") if res.get("resource_type") != null else ""
		if rtype == neediest:
			matching.append(res)

	if not matching.is_empty():
		var nearest: Node = _find_nearest(worker as Node2D, matching)
		if nearest != null:
			_assign_villager(worker, nearest)


func _find_needy_resource(distribution: Dictionary, ratios: Dictionary) -> String:
	var best_deficit: float = 0.0
	var best_resource: String = ""

	for resource_type: String in _resource_priority:
		var ideal: float = ratios.get(resource_type, 0.25)
		var actual: float = float(distribution.get(resource_type, 0)) / float(_count_own_villagers()) if _count_own_villagers() > 0 else 0.0
		var deficit: float = ideal - actual
		if deficit > best_deficit:
			best_deficit = deficit
			best_resource = resource_type

	return best_resource


func ensure_food_income() -> void:
	var food: int = GameManager.get_resource("food", ai_player_id)
	var food_villagers: int = _count_villagers_on_resource("food")
	var min_food_villagers: int = 3 if personality != "aggressive" else 2

	if food < _stockpile_targets["food"] or food_villagers < min_food_villagers:
		_queue_villager_to_resource("food")
		economy_action.emit("gather", "food")


func ensure_wood_income() -> void:
	var wood: int = GameManager.get_resource("wood", ai_player_id)
	var wood_villagers: int = _count_villagers_on_resource("wood")
	var min_wood_villagers: int = 2 if personality != "defensive" else 3

	if wood < _stockpile_targets["wood"] or wood_villagers < min_wood_villagers:
		_queue_villager_to_resource("wood")
		economy_action.emit("gather", "wood")


func ensure_gold_income() -> void:
	var gold: int = GameManager.get_resource("gold", ai_player_id)
	var gold_villagers: int = _count_villagers_on_resource("gold")
	var min_gold: int = 50 if personality != "aggressive" else 80
	var min_gold_villagers: int = 1 if personality != "aggressive" else 2

	if gold < min_gold or gold_villagers < min_gold_villagers:
		_queue_villager_to_resource("gold")
		economy_action.emit("gather", "gold")


func assign_idle_villagers() -> void:
	var idle_villagers: Array[Node] = _get_idle_villagers()
	if idle_villagers.is_empty():
		return

	var resources: Array[Node] = _get_available_resources()
	if resources.is_empty():
		return

	for villager: Node in idle_villagers:
		if resources.is_empty():
			break
		var best_res: Node = _find_best_resource_for_villager(villager as Node2D, resources)
		if best_res != null:
			_assign_villager(villager, best_res)
			resources.erase(best_res)


func _find_best_resource_for_villager(villager: Node2D, resources: Array[Node]) -> Node:
	if villager == null or resources.is_empty():
		return null

	var distribution: Dictionary = get_villager_distribution()
	var ratios: Dictionary = _ideal_ratios.get(personality, _ideal_ratios["balanced"])
	var best_node: Node = null
	var best_score: float = -INF

	for res: Node in resources:
		if not (res is Node2D):
			continue
		var rtype: String = res.get("resource_type") if res.get("resource_type") != null else ""
		var ideal: float = ratios.get(rtype, 0.25)
		var actual: float = float(distribution.get(rtype, 0)) / float(_count_own_villagers()) if _count_own_villagers() > 0 else 0.0
		var need_score: float = ideal - actual

		var dist: float = villager.global_position.distance_to((res as Node2D).global_position)
		var dist_score: float = 1.0 - clampf(dist / 500.0, 0.0, 1.0)

		var score: float = need_score * 10.0 + dist_score * 3.0
		if score > best_score:
			best_score = score
			best_node = res

	return best_node


func train_villagers() -> void:
	var villagers: int = _count_own_villagers()
	var town_centers: Array[Node] = _get_own_buildings("town_center")
	if town_centers.is_empty():
		return

	var food: int = GameManager.get_resource("food", ai_player_id)
	var min_food_for_villager: int = 50 if personality != "aggressive" else 80

	if food < min_food_for_villager:
		return

	var max_villagers: int = 20 if personality == "aggressive" else 30
	if villagers >= max_villagers:
		return

	var tc: Node = town_centers[0]
	if tc.has_method("can_produce") and tc.can_produce("villager"):
		if tc.has_method("start_production"):
			tc.start_production("villager")
			economy_action.emit("train", "villager")


func get_villager_distribution() -> Dictionary:
	var distribution: Dictionary = {"food": 0, "wood": 0, "stone": 0, "gold": 0}
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype != "villager":
			continue
		var assigned_res: String = unit.get("assigned_resource") if unit.get("assigned_resource") != null else ""
		if assigned_res in distribution:
			distribution[assigned_res] += 1
	return distribution


func get_resource_urgency(resource_type: String) -> float:
	var current: int = GameManager.get_resource(resource_type, ai_player_id)
	var target: int = _stockpile_targets.get(resource_type, 100)
	if current >= target:
		return 0.0
	return 1.0 - (float(current) / float(target))


func _get_idle_villagers() -> Array[Node]:
	var idle: Array[Node] = []
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype != "villager":
			continue
		var current_state: String = unit.get("current_state") if unit.get("current_state") != null else "idle"
		if current_state == "idle" or current_state == "":
			idle.append(unit)
	return idle


func _get_villagers_on_resource(resource_type: String) -> Array[Node]:
	var result: Array[Node] = []
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype != "villager":
			continue
		var assigned: String = unit.get("assigned_resource") if unit.get("assigned_resource") != null else ""
		if assigned == resource_type:
			result.append(unit)
	return result


func _get_available_resources() -> Array[Node]:
	var resources: Array[Node] = []
	var all_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_nodes")
	for res: Node in all_nodes:
		if res is Node2D:
			var amount: int = res.get("amount") if res.get("amount") != null else 0
			if amount > 0:
				resources.append(res)
	if resources.is_empty():
		all_nodes = get_tree().get_nodes_in_group("resources")
		for res: Node in all_nodes:
			if res is Node2D:
				resources.append(res)
	return resources


func _find_nearest(origin: Node2D, targets: Array[Node]) -> Node:
	if origin == null or targets.is_empty():
		return null
	var nearest: Node = null
	var min_dist: float = 999999.0
	for target: Node in targets:
		if not (target is Node2D):
			continue
		var dist: float = origin.global_position.distance_to((target as Node2D).global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = target
	return nearest


func _assign_villager(villager: Node, resource: Node) -> void:
	var resource_type: String = resource.get("resource_type") if resource.get("resource_type") != null else ""
	villager.set("assigned_resource", resource_type)

	if villager.has_method("set_target"):
		villager.set_target(resource)

	var harvest_comp: Node = villager.get_node_or_null("HarvestComponent")
	if harvest_comp != null and harvest_comp.has_method("set_resource"):
		harvest_comp.set_resource(resource)

	EventBus.villager_assigned.emit(
		villager.get("unit_id") if villager.get("unit_id") != null else -1,
		resource.get("resource_id") if resource.get("resource_id") != null else -1,
		"gather"
	)


func _queue_villager_to_resource(resource_type: String) -> void:
	var idle_villagers: Array[Node] = _get_idle_villagers()
	if idle_villagers.is_empty():
		return

	var resource_nodes: Array[Node] = _get_available_resources()
	var matching: Array[Node] = []
	for res: Node in resource_nodes:
		var rtype: String = res.get("resource_type") if res.get("resource_type") != null else ""
		if rtype == resource_type:
			matching.append(res)

	if matching.is_empty():
		return

	var villager: Node = idle_villagers[0]
	var nearest: Node = _find_nearest(villager as Node2D, matching)
	if nearest != null:
		_assign_villager(villager, nearest)


func _count_villagers_on_resource(resource_type: String) -> int:
	var count: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype != "villager":
			continue
		var assigned: String = unit.get("assigned_resource") if unit.get("assigned_resource") != null else ""
		if assigned == resource_type:
			count += 1
	return count


func _count_own_villagers() -> int:
	var count: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype == "villager":
			count += 1
	return count


func _get_own_buildings(building_type: String) -> Array[Node]:
	var result: Array[Node] = []
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
		if btype == building_type:
			result.append(bld)
	return result
