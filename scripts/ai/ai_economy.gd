extends Node

signal economy_action(action: String, target: String)

var ai_player_id: int = -1


func initialize(player_id: int) -> void:
	ai_player_id = player_id


func manage_economy(delta: float) -> void:
	assign_idle_villagers()
	ensure_food_income()
	ensure_wood_income()
	ensure_gold_income()
	train_villagers()


func ensure_food_income() -> void:
	var food: int = GameManager.get_resource("food", ai_player_id)
	var food_villagers: int = _count_villagers_on_resource("food")
	if food < 100 or food_villagers < 3:
		_queue_villager_to_resource("food")
		economy_action.emit("gather", "food")


func ensure_wood_income() -> void:
	var wood: int = GameManager.get_resource("wood", ai_player_id)
	var wood_villagers: int = _count_villagers_on_resource("wood")
	if wood < 100 or wood_villagers < 2:
		_queue_villager_to_resource("wood")
		economy_action.emit("gather", "wood")


func ensure_gold_income() -> void:
	var gold: int = GameManager.get_resource("gold", ai_player_id)
	var gold_villagers: int = _count_villagers_on_resource("gold")
	if gold < 50 or gold_villagers < 1:
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
		var nearest_res: Node = _find_nearest(villager as Node2D, resources)
		if nearest_res != null:
			_assign_villager(villager, nearest_res)
			resources.erase(nearest_res)


func train_villagers() -> void:
	var villagers: int = _count_own_villagers()
	var town_centers: Array[Node] = _get_own_buildings("town_center")
	if town_centers.is_empty():
		return

	var food: int = GameManager.get_resource("food", ai_player_id)
	if food < 50:
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
	elif villager.has_method("set("):
		villager.set("target_resource", resource)

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
