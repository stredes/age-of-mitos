extends Node

signal build_planned(building_type: String, position: Vector2)

var ai_player_id: int = -1
var personality: String = "balanced"
var _last_build_time: float = 0.0
var _build_cooldown: float = 15.0


func initialize(player_id: int, ai_personality: String = "balanced") -> void:
	ai_player_id = player_id
	personality = ai_personality

	match personality:
		"aggressive":
			_build_cooldown = 12.0
		"defensive":
			_build_cooldown = 18.0
		_:
			_build_cooldown = 15.0


func manage_buildings(delta: float) -> void:
	var game_time: float = GameManager.game_time
	if game_time - _last_build_time < _build_cooldown:
		return

	build_essentials()
	repair_damaged_buildings()

	if should_expand():
		var spot: Vector2 = find_expansion_spot()
		if spot != Vector2.ZERO:
			var priority: Array = get_building_priority()
			if not priority.is_empty():
				var building_type: String = priority[0]
				_try_build(building_type, spot)

	build_defenses()
	_last_build_time = game_time


func should_expand() -> bool:
	var buildings: Array[Node] = _get_own_buildings()
	var town_center_count: int = 0
	for bld: Node in buildings:
		var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
		if btype == "town_center":
			town_center_count += 1

	var villagers: int = _count_own_villagers()
	if town_center_count < 2 and villagers > 20:
		return true
	if town_center_count < 3 and villagers > 40:
		return true

	var food: int = GameManager.get_resource("food", ai_player_id)
	var wood: int = GameManager.get_resource("wood", ai_player_id)
	if food > 400 and wood > 300:
		return true
	return false


func find_expansion_spot() -> Vector2:
	var base_pos: Vector2 = _get_own_base_position()
	var best_spot: Vector2 = Vector2.ZERO
	var best_score: float = -1.0

	for i in range(8):
		var angle: float = float(i) * (TAU / 8.0)
		var dist: float = randf_range(200.0, 400.0)
		var check_pos: Vector2 = base_pos + Vector2.from_angle(angle) * dist

		var threat: int = 0
		var scene: Node = get_tree().current_scene
		if scene != null:
			var combat_manager: Node = scene.get_node_or_null("CombatManager")
			if combat_manager != null and combat_manager.has_method("get_threat_at_position"):
				threat = combat_manager.get_threat_at_position(check_pos, 200.0, ai_player_id)

		var enemy_nearby: bool = false
		var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
		for unit: Node in all_units:
			var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
			if pid == ai_player_id or pid == -1:
				continue
			if unit is Node2D and (unit as Node2D).global_position.distance_to(check_pos) < 150.0:
				enemy_nearby = true
				break

		if enemy_nearby:
			continue

		var score: float = 100.0 - float(threat) * 0.5
		if score > best_score:
			best_score = score
			best_spot = check_pos

	return best_spot


func build_essentials() -> void:
	var pop_count: int = _count_own_units()
	var house_count: int = _get_building_count("house")
	var max_pop: int = house_count * 5 + 5

	if pop_count >= max_pop - 2:
		var base_pos: Vector2 = _get_own_base_position()
		var spot: Vector2 = base_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		_try_build("house", spot)

	var barracks_count: int = _get_building_count("barracks")
	if barracks_count == 0 and _count_own_villagers() >= 5:
		var base_pos: Vector2 = _get_own_base_position()
		var spot: Vector2 = base_pos + Vector2(randf_range(80, 160), randf_range(-80, 80))
		_try_build("barracks", spot)

	var archery_count: int = _get_building_count("archery_range")
	if archery_count == 0 and barracks_count > 0 and _count_own_villagers() >= 15:
		var base_pos: Vector2 = _get_own_base_position()
		var spot: Vector2 = base_pos + Vector2(randf_range(80, 160), randf_range(-80, 80))
		_try_build("archery_range", spot)

	var stable_count: int = _get_building_count("stable")
	if stable_count == 0 and barracks_count > 0 and _count_own_villagers() >= 20:
		var base_pos: Vector2 = _get_own_base_position()
		var spot: Vector2 = base_pos + Vector2(randf_range(80, 160), randf_range(-80, 80))
		_try_build("stable", spot)

	var farm_count: int = _get_building_count("farm")
	var food_villagers: int = _count_villagers_on_resource("food")
	if farm_count < food_villagers + 2:
		var base_pos: Vector2 = _get_own_base_position()
		var spot: Vector2 = base_pos + Vector2(randf_range(-120, 120), randf_range(-120, 120))
		_try_build("farm", spot)


func build_defenses() -> void:
	var tower_count: int = _get_building_count("tower")
	var threat_level: int = 0
	var base_pos: Vector2 = _get_own_base_position()
	var scene: Node = get_tree().current_scene
	if scene != null:
		var combat_manager: Node = scene.get_node_or_null("CombatManager")
		if combat_manager != null and combat_manager.has_method("get_threat_at_position"):
			threat_level = combat_manager.get_threat_at_position(base_pos, 500.0, ai_player_id)

	if threat_level > 30 and tower_count < 3:
		var angle: float = randf() * TAU
		var dist: float = randf_range(60.0, 120.0)
		var spot: Vector2 = base_pos + Vector2.from_angle(angle) * dist
		_try_build("tower", spot)

	var lumber_camps: int = _get_building_count("lumber_camp")
	if lumber_camps == 0 and _count_villagers_on_resource("wood") >= 2:
		var wood_spot: Vector2 = _find_resource_spot("wood")
		if wood_spot != Vector2.ZERO:
			_try_build("lumber_camp", wood_spot)

	var mining_camps: int = _get_building_count("mining_camp")
	if mining_camps == 0 and _count_villagers_on_resource("gold") >= 1:
		var gold_spot: Vector2 = _find_resource_spot("gold")
		if gold_spot != Vector2.ZERO:
			_try_build("mining_camp", gold_spot)


func repair_damaged_buildings() -> void:
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var max_hp: int = bld.get("max_hp") if bld.get("max_hp") != null else 100
		var cur_hp: int = bld.get("current_hp") if bld.get("current_hp") != null else 100
		if cur_hp < max_hp * 0.7:
			if bld.has_method("repair"):
				var cost: Dictionary = {"wood": 5, "stone": 2}
				if GameManager.can_afford(cost, ai_player_id):
					bld.repair(0.5)


func get_building_priority() -> Array:
	var priority: Array = []

	if _get_building_count("barracks") == 0:
		priority.append("barracks")
	if _get_building_count("mill") == 0:
		priority.append("mill")
	if _get_building_count("lumber_camp") == 0:
		priority.append("lumber_camp")
	if _get_building_count("mining_camp") == 0:
		priority.append("mining_camp")
	if _count_own_villagers() > 20 and _get_building_count("archery_range") == 0:
		priority.append("archery_range")
	if _count_own_villagers() > 30 and _get_building_count("stable") == 0:
		priority.append("stable")
	if _count_own_villagers() > 40 and _get_building_count("castle") == 0:
		priority.append("castle")

	if priority.is_empty():
		priority.append("farm")

	return priority


func _try_build(building_type: String, position: Vector2) -> void:
	var building_data: Dictionary = DataManager.get_building_data(building_type)
	if building_data.is_empty():
		return

	var cost: Dictionary = building_data.get("cost", {})
	if not GameManager.can_afford(cost, ai_player_id):
		return

	GameManager.spend_resources(cost, ai_player_id)
	build_planned.emit(building_type, position)

	var building_id: int = randi()
	EventBus.building_placed.emit(building_id, building_type, ai_player_id, position)
	EventBus.ai_expansion_planned.emit(ai_player_id, position, building_type)


func _get_own_buildings() -> Array[Node]:
	var result: Array[Node] = []
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id:
			result.append(bld)
	return result


func _get_building_count(building_type: String) -> int:
	var count: int = 0
	var buildings: Array[Node] = _get_own_buildings()
	for bld: Node in buildings:
		var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
		if btype == building_type:
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


func _count_own_units() -> int:
	var count: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		count += 1
	return count


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


func _get_own_base_position() -> Vector2:
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id and bld is Node2D:
			var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
			if btype == "town_center":
				return (bld as Node2D).global_position
	return Vector2.ZERO


func _find_resource_spot(resource_type: String) -> Vector2:
	var all_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_nodes")
	for res: Node in all_nodes:
		if res is Node2D:
			var rtype: String = res.get("resource_type") if res.get("resource_type") != null else ""
			if rtype == resource_type:
				var amount: int = res.get("amount") if res.get("amount") != null else 0
				if amount > 0:
					return (res as Node2D).global_position
	return Vector2.ZERO


func _estimate_resource_income(resource_type: String) -> int:
	var total: int = 0
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
			total += 1
	return total
