extends Node

signal decision_made(priority: String, target: Vector2)

enum Priority { ECONOMY, MILITARY, EXPANSION, DEFENSE }

var ai_player_id: int = -1
var difficulty: int = 1
var update_interval: float = 3.0
var update_timer: float = 0.0
var personality: String = "balanced"

var ai_economy: Node = null
var ai_military: Node = null
var ai_builder: Node = null


func initialize(player_id: int, diff: int) -> void:
	ai_player_id = player_id
	difficulty = clampi(diff, 1, 3)
	update_timer = randf_range(0.0, update_interval)

	match difficulty:
		1:
			update_interval = 5.0
			personality = "defensive"
		2:
			update_interval = 3.0
			personality = "balanced"
		3:
			update_interval = 2.0
			personality = "aggressive"

	ai_economy = Node.new()
	ai_economy.set_script(load("res://scripts/ai/ai_economy.gd"))
	ai_economy.name = "AIEconomy_%d" % ai_player_id
	add_child(ai_economy)
	ai_economy.initialize(ai_player_id)

	ai_military = Node.new()
	ai_military.set_script(load("res://scripts/ai/ai_military.gd"))
	ai_military.name = "AIMilitary_%d" % ai_player_id
	add_child(ai_military)
	ai_military.initialize(ai_player_id)

	ai_builder = Node.new()
	ai_builder.set_script(load("res://scripts/ai/ai_builder.gd"))
	ai_builder.name = "AIBuilder_%d" % ai_player_id
	add_child(ai_builder)
	ai_builder.initialize(ai_player_id)


func _process(delta: float) -> void:
	if ai_player_id == -1:
		return
	if GameManager.is_paused() or GameManager.is_game_over():
		return

	update_timer -= delta
	if update_timer <= 0.0:
		update_timer = update_interval
		make_decisions()


func make_decisions() -> void:
	var priority: String = _evaluate_priority()
	var target_pos: Vector2 = Vector2.ZERO

	match priority:
		"ECONOMY":
			if ai_economy != null:
				ai_economy.manage_economy(update_interval)
		"MILITARY":
			if ai_military != null:
				ai_military.manage_military(update_interval)
			target_pos = find_enemy_base()
		"EXPANSION":
			if ai_builder != null:
				ai_builder.manage_buildings(update_interval)
			target_pos = find_expansion_spot()
		"DEFENSE":
			if ai_builder != null:
				ai_builder.build_defenses()
			target_pos = find_weakest_point()

	decision_made.emit(priority, target_pos)


func _evaluate_priority() -> String:
	var military_str: int = get_military_strength()
	var economic_str: int = get_economic_strength()
	var threat: int = _get_own_base_threat()

	if threat > military_str * 2:
		return "DEFENSE"

	if economic_str < 50:
		return "ECONOMY"

	if military_str < 30 and personality != "defensive":
		return "MILITARY"

	match personality:
		"aggressive":
			if military_str > 60:
				return "MILITARY"
			return "ECONOMY"
		"defensive":
			if threat > 20:
				return "DEFENSE"
			return "ECONOMY"
		_:
			if military_str > 80:
				return "MILITARY"
			if economic_str > 100:
				return "EXPANSION"
			return "ECONOMY"


func get_military_strength() -> int:
	var total: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var hp: int = 0
		var atk: int = 0
		var health_comp: Node = unit.get_node_or_null("HealthComponent")
		if health_comp != null:
			hp = health_comp.get("current_hp") if health_comp.get("current_hp") != null else 0
		else:
			hp = unit.get("current_hp") if unit.get("current_hp") != null else 0
		var combat_comp: Node = unit.get_node_or_null("CombatComponent")
		if combat_comp != null:
			atk = combat_comp.get("attack_damage") if combat_comp.get("attack_damage") != null else 0
		else:
			atk = unit.get("attack_damage") if unit.get("attack_damage") != null else 0
		total += hp + atk * 3
	return total


func get_economic_strength() -> int:
	var total: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype == "villager":
			total += 10
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
		match btype:
			"town_center":
				total += 30
			"mill", "lumber_camp", "mining_camp":
				total += 15
			"farm":
				total += 5
			_:
				total += 3

	var resources: Dictionary = GameManager.get_resources(ai_player_id)
	for key: String in resources:
		total += int(resources[key] / 100)
	return total


func find_weakest_point() -> Vector2:
	var base_pos: Vector2 = _get_own_base_position()
	var weakest: Vector2 = base_pos
	var min_threat: int = 999999

	for angle: float in range(0, 360, 45):
		var check_pos: Vector2 = base_pos + Vector2.from_angle(deg_to_rad(angle)) * 200.0
		var threat: int = 0
		var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
		for unit: Node in all_units:
			var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
			if pid == ai_player_id or pid == -1:
				continue
			var dist: float = (unit as Node2D).global_position.distance_to(check_pos) if unit is Node2D else 9999.0
			if dist < 200.0:
				threat += 10
		if threat < min_threat:
			min_threat = threat
			weakest = check_pos
	return weakest


func find_enemy_base() -> Vector2:
	var best_pos: Vector2 = Vector2(1000, 1000)
	var min_dist: float = 999999.0
	var own_pos: Vector2 = _get_own_base_position()

	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id or pid == -1:
			continue
		if not (bld is Node2D):
			continue
		var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
		if btype == "town_center":
			var dist: float = (bld as Node2D).global_position.distance_to(own_pos)
			if dist < min_dist:
				min_dist = dist
				best_pos = (bld as Node2D).global_position

	if min_dist < 999999.0:
		return best_pos

	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid == ai_player_id or pid == -1:
			continue
		if not (unit is Node2D):
			continue
		var dist: float = (unit as Node2D).global_position.distance_to(own_pos)
		if dist < min_dist:
			min_dist = dist
			best_pos = (unit as Node2D).global_position

	return best_pos


func find_expansion_spot() -> Vector2:
	var base_pos: Vector2 = _get_own_base_position()
	var best_spot: Vector2 = base_pos + Vector2(300, 0)
	var best_score: float = -1.0

	for i in range(12):
		var angle: float = float(i) * (TAU / 12.0)
		var dist: float = randf_range(250.0, 450.0)
		var check_pos: Vector2 = base_pos + Vector2.from_angle(angle) * dist

		var threat: int = get_tree().current_scene.get_node_or_null("CombatManager").get_threat_at_position(check_pos, 200.0, ai_player_id) if get_tree().current_scene.get_node_or_null("CombatManager") != null else 0
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


func _get_own_base_position() -> Vector2:
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id and bld is Node2D:
			var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
			if btype == "town_center":
				return (bld as Node2D).global_position
	return Vector2.ZERO


func _get_own_base_threat() -> int:
	var base_pos: Vector2 = _get_own_base_position()
	var combat_manager: Node = get_tree().current_scene.get_node_or_null("CombatManager")
	if combat_manager != null and combat_manager.has_method("get_threat_at_position"):
		return combat_manager.get_threat_at_position(base_pos, 400.0, ai_player_id)
	return 0
