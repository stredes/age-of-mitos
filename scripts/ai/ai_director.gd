## Top-level AI orchestrator. Evaluates threats, manages sub-systems, and
## coordinates scouting, economy, military, and building. Four distinct
## personality archetypes with different risk tolerances, reaction times,
## and decision-making biases. Scouting is limited by fog of war.
extends Node

signal decision_made(priority: String, target: Vector2, reason: String)

# =============================================================================
# Personality Definitions
# =============================================================================

enum Personality { AGGRESSIVE, DEFENSIVE, BALANCED, TURTLE }

const PROFILES: Dictionary = {
	Personality.AGGRESSIVE: {
		"name": "aggressive",
		"update_interval": 2.5,
		"reaction_delay": 1.0,
		"attack_threshold": 50,
		"attack_cooldown": 18.0,
		"defense_threshold": 30,
		"economy_cap": 18,
		"villager_food_ratio": 0.30,
		"villager_wood_ratio": 0.25,
		"villager_gold_ratio": 0.30,
		"villager_stone_ratio": 0.15,
		"military_bias": 1.6,
		"economy_bias": 0.5,
		"expansion_bias": 1.0,
		"scout_interval": 15.0,
		"scout_party_size": 1,
		"retreat_ratio": 0.4,
	},
	Personality.DEFENSIVE: {
		"name": "defensive",
		"update_interval": 3.5,
		"reaction_delay": 2.0,
		"attack_threshold": 100,
		"attack_cooldown": 40.0,
		"defense_threshold": 15,
		"economy_cap": 30,
		"villager_food_ratio": 0.40,
		"villager_wood_ratio": 0.35,
		"villager_gold_ratio": 0.10,
		"villager_stone_ratio": 0.15,
		"military_bias": 0.6,
		"economy_bias": 1.4,
		"expansion_bias": 0.7,
		"scout_interval": 30.0,
		"scout_party_size": 1,
		"retreat_ratio": 0.7,
	},
	Personality.BALANCED: {
		"name": "balanced",
		"update_interval": 3.0,
		"reaction_delay": 1.5,
		"attack_threshold": 75,
		"attack_cooldown": 28.0,
		"defense_threshold": 20,
		"economy_cap": 25,
		"villager_food_ratio": 0.35,
		"villager_wood_ratio": 0.30,
		"villager_gold_ratio": 0.20,
		"villager_stone_ratio": 0.15,
		"military_bias": 1.0,
		"economy_bias": 1.0,
		"expansion_bias": 1.0,
		"scout_interval": 22.0,
		"scout_party_size": 1,
		"retreat_ratio": 0.55,
	},
	Personality.TURTLE: {
		"name": "turtle",
		"update_interval": 4.0,
		"reaction_delay": 2.5,
		"attack_threshold": 130,
		"attack_cooldown": 55.0,
		"defense_threshold": 10,
		"economy_cap": 35,
		"villager_food_ratio": 0.40,
		"villager_wood_ratio": 0.30,
		"villager_gold_ratio": 0.10,
		"villager_stone_ratio": 0.20,
		"military_bias": 0.4,
		"economy_bias": 1.3,
		"expansion_bias": 0.5,
		"scout_interval": 40.0,
		"scout_party_size": 1,
		"retreat_ratio": 0.8,
	},
}

# =============================================================================
# Properties
# =============================================================================

var ai_player_id: int = -1
var difficulty: int = 2
var personality: int = Personality.BALANCED

var ai_economy: Node = null
var ai_military: Node = null
var ai_builder: Node = null

var _update_timer: float = 0.0
var _scout_timer: float = 0.0
var _reaction_timer: float = 0.0
var _pending_decision: String = ""
var _pending_target: Vector2 = Vector2.ZERO

var _last_attack_time: float = 0.0
var _last_scout_positions: Array[Vector2] = []
var _known_enemy_positions: Dictionary = {}
var _last_threat_check: float = 0.0
var _current_threat: int = 0

var _decision_history: Array[String] = []
const HISTORY_SIZE: int = 8

# =============================================================================
# Lifecycle
# =============================================================================

func _process(delta: float) -> void:
	if ai_player_id == -1:
		return
	if GameManager.is_paused() or GameManager.is_game_over():
		return

	_update_timer -= delta
	if _update_timer <= 0.0:
		var profile: Dictionary = PROFILES[personality]
		_update_timer = profile["update_interval"] + randf_range(-0.5, 0.5)
		_tick(delta)

	_scout_timer -= delta
	if _scout_timer <= 0.0:
		_scout_timer = PROFILES[personality]["scout_interval"]
		_send_scout()

	_reaction_timer -= delta
	if _reaction_timer <= 0.0 and not _pending_decision.is_empty():
		_execute_decision(_pending_decision, _pending_target)
		_pending_decision = ""
		_pending_target = Vector2.ZERO

# =============================================================================
# Initialization
# =============================================================================

func initialize(player_id: int, diff: int) -> void:
	ai_player_id = player_id
	difficulty = clampi(diff, 1, 3)

	match difficulty:
		1:
			personality = Personality.DEFENSIVE
		2:
			personality = Personality.BALANCED
		3:
			personality = Personality.AGGRESSIVE

	# Override personality from difficulty only at low levels.
	# At difficulty 3, randomly pick between aggressive/turtle for variety.
	if difficulty == 3 and randf() < 0.3:
		personality = Personality.TURTLE

	_update_timer = randf_range(1.0, 3.0)
	_scout_timer = randf_range(5.0, 15.0)

	_create_sub_systems()


func _create_sub_systems() -> void:
	var profile_name: String = PROFILES[personality]["name"]

	ai_economy = Node.new()
	ai_economy.set_script(load("res://scripts/ai/ai_economy.gd"))
	ai_economy.name = "AIEconomy_%d" % ai_player_id
	add_child(ai_economy)
	ai_economy.initialize(ai_player_id, profile_name)

	ai_military = Node.new()
	ai_military.set_script(load("res://scripts/ai/ai_military.gd"))
	ai_military.name = "AIMilitary_%d" % ai_player_id
	add_child(ai_military)
	ai_military.initialize(ai_player_id, profile_name)

	ai_builder = Node.new()
	ai_builder.set_script(load("res://scripts/ai/ai_builder.gd"))
	ai_builder.name = "AIBuilder_%d" % ai_player_id
	add_child(ai_builder)
	ai_builder.initialize(ai_player_id, profile_name)

# =============================================================================
# Decision Loop
# =============================================================================

func _tick(_delta: float) -> void:
	_update_threat()
	_update_known_enemies()

	var priority: String = _evaluate_priority()
	var target: Vector2 = _resolve_target(priority)
	var reason: String = _explain_decision(priority)

	var profile: Dictionary = PROFILES[personality]
	var reaction: float = profile["reaction_delay"] + randf_range(-0.3, 0.3)
	reaction = maxf(reaction, 0.3)

	_pending_decision = priority
	_pending_target = target
	_reaction_timer = reaction


func _execute_decision(priority: String, target: Vector2) -> void:
	match priority:
		"ECONOMY":
			if ai_economy != null:
				ai_economy.manage_economy(PROFILES[personality]["update_interval"])
		"MILITARY":
			if ai_military != null:
				ai_military.manage_military(PROFILES[personality]["update_interval"])
		"EXPANSION":
			if ai_builder != null:
				ai_builder.manage_buildings(PROFILES[personality]["update_interval"])
		"DEFENSE":
			if ai_builder != null:
				ai_builder.build_defenses()
			if ai_military != null:
				ai_military.defend_base()
		"SCOUT":
			pass

	_decision_history.append(priority)
	if _decision_history.size() > HISTORY_SIZE:
		_decision_history.pop_front()

	decision_made.emit(priority, target, _explain_decision(priority))

# =============================================================================
# Priority Evaluation
# =============================================================================

func _evaluate_priority() -> String:
	var profile: Dictionary = PROFILES[personality]
	var mil_strength: int = get_military_strength()
	var econ_strength: int = get_economic_strength()
	var threat: int = _current_threat
	var game_time: float = GameManager.game_time

	# Immediate threat overrides everything.
	if threat > mil_strength * 2 and threat > profile["defense_threshold"]:
		return "DEFENSE"

	# Check attack readiness.
	var time_since_attack: float = game_time - _last_attack_time
	if mil_strength >= profile["attack_threshold"] and time_since_attack >= profile["attack_cooldown"]:
		if ai_military != null and ai_military.has_method("should_attack"):
			if ai_military.should_attack():
				return "MILITARY"

	# Economy floor — always build up early.
	if game_time < 120.0:
		return "ECONOMY"

	# Personality-weighted scoring.
	var econ_score: float = float(econ_strength) * profile["economy_bias"]
	var mil_score: float = float(mil_strength) * profile["military_bias"]

	match personality:
		Personality.AGGRESSIVE:
			if mil_score > 60 and threat == 0:
				return "MILITARY"
			if econ_score > 50:
				return "EXPANSION"
			return "ECONOMY"

		Personality.DEFENSIVE:
			if threat > profile["defense_threshold"]:
				return "DEFENSE"
			if econ_score > 80 and mil_score < 50:
				return "MILITARY"
			return "ECONOMY"

		Personality.TURTLE:
			if threat > profile["defense_threshold"]:
				return "DEFENSE"
			if econ_score > 100 and _get_own_building_count("castle") == 0:
				return "EXPANSION"
			return "ECONOMY"

		Personality.BALANCED:
			if mil_score > 70:
				return "MILITARY"
			if econ_score > 60:
				return "EXPANSION"
			return "ECONOMY"

	return "ECONOMY"

# =============================================================================
# Scouting (Fog-Limited)
# =============================================================================

func _send_scout() -> void:
	var scouts: Array[Node] = _get_scout_candidates()
	if scouts.is_empty():
		return

	var target: Vector2 = _pick_scout_target()
	if target == Vector2.ZERO:
		return

	var scout: Node = scouts[0]
	if scout.has_method("set"):
		scout.set("pending_move_position", target)
	var sm: Node = scout.get_node_or_null("UnitStateMachine")
	if sm != null and sm.has_method("change_state"):
		sm.change_state("MoveState")


func _pick_scout_target() -> Vector2:
	var base_pos: Vector2 = _get_own_base_position()
	if base_pos == Vector2.ZERO:
		return Vector2.ZERO

	var fog: Node = _find_fog_of_war()
	var grid: Node = _find_grid_manager()

	# Try several candidate positions, pick one that is NOT yet explored.
	for _attempt in range(8):
		var angle: float = randf() * TAU
		var dist: float = randf_range(300.0, 700.0)
		var candidate: Vector2 = base_pos + Vector2.from_angle(angle) * dist

		# Check fog: only scout areas the AI hasn't explored yet.
		if fog != null and fog.has_method("is_explored") and grid != null and grid.has_method("get_cell_from_world"):
			var cell: Vector2i = grid.get_cell_from_world(candidate)
			if fog.is_explored(cell, ai_player_id):
				continue

		# Avoid scouting on top of known enemies.
		if _is_position_hostile(candidate):
			continue

		# Avoid revisiting recent scout targets.
		var too_close: bool = false
		for prev: Vector2 in _last_scout_positions:
			if candidate.distance_to(prev) < 100.0:
				too_close = true
				break
		if too_close:
			continue

		_last_scout_positions.append(candidate)
		if _last_scout_positions.size() > 5:
			_last_scout_positions.pop_front()
		return candidate

	return base_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200))


func _get_scout_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype == "villager":
			continue
		var hp: int = 0
		var hc: Node = unit.get_node_or_null("HealthComponent")
		if hc != null:
			hp = hc.get("current_hp") if hc.get("current_hp") != null else 0
		if hp <= 0:
			continue
		# Check if unit is idle (not currently fighting).
		var sm: Node = unit.get_node_or_null("UnitStateMachine")
		if sm != null and sm.has_method("get_current_state_name"):
			var state: String = sm.get_current_state_name()
			if state == "IdleState" or state == "MoveState":
				candidates.append(unit)
	return candidates


func _is_position_hostile(pos: Vector2) -> bool:
	for eid: Variant in _known_enemy_positions:
		var epos: Vector2 = _known_enemy_positions[eid]
		if pos.distance_to(epos) < 80.0:
			return true
	return false

# =============================================================================
# Threat Assessment
# =============================================================================

func _update_threat() -> void:
	var base_pos: Vector2 = _get_own_base_position()
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var cm: Node = scene.get_node_or_null("CombatManager")
	if cm != null and cm.has_method("get_threat_at_position"):
		_current_threat = cm.get_threat_at_position(base_pos, 500.0, ai_player_id)


func _update_known_enemies() -> void:
	_known_enemy_positions.clear()
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid == ai_player_id or pid == -1:
			continue
		if not (unit is Node2D):
			continue
		# Only track enemies visible in fog.
		var fog: Node = _find_fog_of_war()
		var grid: Node = _find_grid_manager()
		if fog != null and fog.has_method("is_cell_visible") and grid != null and grid.has_method("get_cell_from_world"):
			var cell: Vector2i = grid.get_cell_from_world((unit as Node2D).global_position)
			if not fog.is_cell_visible(cell, ai_player_id):
				continue
		var uid: int = unit.get("unit_id") if unit.get("unit_id") != null else -1
		_known_enemy_positions[uid] = (unit as Node2D).global_position

# =============================================================================
# Target Resolution
# =============================================================================

func _resolve_target(priority: String) -> Vector2:
	match priority:
		"MILITARY":
			return find_enemy_base()
		"EXPANSION":
			return find_expansion_spot()
		"DEFENSE":
			return _get_own_base_position()
		_:
			return Vector2.ZERO


func find_enemy_base() -> Vector2:
	var own_pos: Vector2 = _get_own_base_position()
	var best: Vector2 = Vector2(1000, 1000)
	var min_dist: float = 999999.0
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id or pid == -1:
			continue
		if not (bld is Node2D):
			continue
		var dist: float = (bld as Node2D).global_position.distance_to(own_pos)
		if dist < min_dist:
			min_dist = dist
			best = (bld as Node2D).global_position
	return best


func find_expansion_spot() -> Vector2:
	var base_pos: Vector2 = _get_own_base_position()
	var best_spot: Vector2 = base_pos + Vector2(300, 0)
	var best_score: float = -1.0
	for i in range(12):
		var angle: float = float(i) * (TAU / 12.0)
		var dist: float = randf_range(250.0, 450.0)
		var pos: Vector2 = base_pos + Vector2.from_angle(angle) * dist
		if _is_position_hostile(pos):
			continue
		var threat: int = 0
		var scene: Node = get_tree().current_scene
		if scene != null:
			var cm: Node = scene.get_node_or_null("CombatManager")
			if cm != null and cm.has_method("get_threat_at_position"):
				threat = cm.get_threat_at_position(pos, 200.0, ai_player_id)
		var score: float = 100.0 - float(threat) * 0.5
		if score > best_score:
			best_score = score
			best_spot = pos
	return best_spot

# =============================================================================
# Query API
# =============================================================================

func get_military_strength() -> int:
	var total: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype == "villager":
			continue
		var hp: int = _get_unit_hp(unit)
		var atk: int = _get_unit_attack(unit)
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
	var res: Dictionary = GameManager.get_resources(ai_player_id)
	for key: String in res:
		total += int(res[key] / 100)
	return total


func get_personality_name() -> String:
	return PROFILES[personality]["name"]


func get_personality_profile() -> Dictionary:
	return PROFILES[personality].duplicate()


func get_decision_history() -> Array[String]:
	return _decision_history.duplicate()

# =============================================================================
# Helpers
# =============================================================================

func _explain_decision(priority: String) -> String:
	match priority:
		"ECONOMY":
			return "Economy needs attention"
		"MILITARY":
			return "Army ready to attack"
		"EXPANSION":
			return "Time to expand"
		"DEFENSE":
			return "Base under threat (%d)" % _current_threat
		"SCOUT":
			return "Scouting unknown territory"
		_:
			return ""


func _get_own_base_position() -> Vector2:
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id and bld is Node2D:
			var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
			if btype == "town_center":
				return (bld as Node2D).global_position
	return Vector2.ZERO


func _get_own_building_count(btype: String) -> int:
	var count: int = 0
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var bt: String = bld.get("building_type") if bld.get("building_type") != null else ""
		if bt == btype:
			count += 1
	return count


func _get_unit_hp(unit: Node) -> int:
	var hc: Node = unit.get_node_or_null("HealthComponent")
	if hc != null:
		return hc.get("current_hp") if hc.get("current_hp") != null else 0
	return unit.get("current_hp") if unit.get("current_hp") != null else 0


func _get_unit_attack(unit: Node) -> int:
	var cc: Node = unit.get_node_or_null("CombatComponent")
	if cc != null:
		return cc.get("attack_damage") if cc.get("attack_damage") != null else 0
	return unit.get("attack_damage") if unit.get("attack_damage") != null else 0


func _find_fog_of_war() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var fog: Node = scene.get_node_or_null("FogOfWar")
	if fog != null:
		return fog
	return _find_recursive(scene, "FogOfWar")


func _find_grid_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var grid: Node = scene.get_node_or_null("GridManager")
	if grid != null:
		return grid
	return _find_recursive(scene, "GridManager")


func _find_recursive(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_recursive(child, target)
		if result != null:
			return result
	return null
