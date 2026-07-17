## AI Director with distance-based throttling and cached queries.
##
## Manages AI decision-making with performance optimizations:
## - Caches unit/building queries to avoid per-frame allocations
## - Throttles updates based on distance to player (near = faster, far = slower)
## - Pre-calculates threat assessments
extends Node

signal decision_made(priority: String, target: Vector2)

enum Priority { ECONOMY, MILITARY, EXPANSION, DEFENSE }

# =============================================================================
# Configuration
# =============================================================================

var ai_player_id: int = -1
var difficulty: int = 1
var update_interval: float = 3.0
var update_timer: float = 0.0
var personality: String = "balanced"

## Distance-based throttle multipliers.
@export var throttle_near: float = 0.5  # < 1000px: update 2x faster
@export var throttle_far: float = 2.0   # > 3000px: update 2x slower
@export var throttle_near_dist: float = 1000.0
@export var throttle_far_dist: float = 3000.0

## Cache lifetime in seconds for unit/building queries.
@export var cache_lifetime: float = 1.0

var ai_economy: Node = null
var ai_military: Node = null
var ai_builder: Node = null

# =============================================================================
# Personality Weights
# =============================================================================

var _personality_weights: Dictionary = {
	"aggressive": {
		"economy_threshold": 30,
		"military_threshold": 40,
		"expansion_threshold": 150,
		"defense_threshold": 25,
		"military_bias": 1.5,
		"economy_bias": 0.6,
		"expansion_bias": 1.2,
		"defense_bias": 0.5,
		"attack_cooldown_mult": 0.7,
		"villager_ratio": 0.3,
	},
	"defensive": {
		"economy_threshold": 40,
		"military_threshold": 60,
		"expansion_threshold": 120,
		"defense_threshold": 15,
		"military_bias": 0.6,
		"economy_bias": 1.4,
		"expansion_bias": 0.8,
		"defense_bias": 1.8,
		"attack_cooldown_mult": 1.5,
		"villager_ratio": 0.5,
	},
	"balanced": {
		"economy_threshold": 50,
		"military_threshold": 50,
		"expansion_threshold": 100,
		"defense_threshold": 20,
		"military_bias": 1.0,
		"economy_bias": 1.0,
		"expansion_bias": 1.0,
		"defense_bias": 1.0,
		"attack_cooldown_mult": 1.0,
		"villager_ratio": 0.4,
	},
}

# =============================================================================
# Cached State
# =============================================================================

var _decision_history: Array[String] = []
const HISTORY_SIZE: int = 5

## Cached unit list: { units: [], timestamp: float }
var _unit_cache: Dictionary = {"units": [], "timestamp": -1.0}

## Cached building list: { buildings: [], timestamp: float }
var _building_cache: Dictionary = {"buildings": [], "timestamp": -1.0}

## Cached own base position.
var _own_base_position: Vector2 = Vector2.ZERO
var _own_base_valid: bool = false

## Cached military/economic strength.
var _cached_military_strength: int = 0
var _cached_economic_strength: int = 0
var _strength_cache_time: float = -1.0

## Player position for distance-based throttling.
var _player_base_position: Vector2 = Vector2.ZERO
var _player_base_valid: bool = false

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)


func _on_game_started(_player_id: int) -> void:
	_invalidate_caches()


func initialize(player_id: int, diff: int) -> void:
	ai_player_id = player_id
	difficulty = clampi(diff, 1, 3)

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

	update_timer = randf_range(0.0, update_interval)

	_create_sub_nodes()
	_find_player_base()


func _create_sub_nodes() -> void:
	ai_economy = Node.new()
	ai_economy.set_script(load("res://scripts/ai/ai_economy.gd"))
	ai_economy.name = "AIEconomy_%d" % ai_player_id
	add_child(ai_economy)
	ai_economy.initialize(ai_player_id, personality)

	ai_military = Node.new()
	ai_military.set_script(load("res://scripts/ai/ai_military.gd"))
	ai_military.name = "AIMilitary_%d" % ai_player_id
	add_child(ai_military)
	ai_military.initialize(ai_player_id, personality)

	ai_builder = Node.new()
	ai_builder.set_script(load("res://scripts/ai/ai_builder.gd"))
	ai_builder.name = "AIBuilder_%d" % ai_player_id
	add_child(ai_builder)
	ai_builder.initialize(ai_player_id, personality)


func _process(delta: float) -> void:
	if ai_player_id == -1:
		return
	if GameManager.is_paused() or GameManager.is_game_over():
		return

	# Distance-based throttle.
	var throttle: float = _get_distance_throttle()
	var effective_interval: float = update_interval * throttle

	update_timer -= delta
	if update_timer <= 0.0:
		update_timer = effective_interval
		make_decisions()

# =============================================================================
# Distance-Based Throttling
# =============================================================================

func _get_distance_throttle() -> float:
	if not _player_base_valid:
		_find_player_base()

	if not _player_base_valid or not _own_base_valid:
		return 1.0  # Default throttle.

	var dist: float = _own_base_position.distance_to(_player_base_position)

	if dist < throttle_near_dist:
		return throttle_near
	elif dist > throttle_far_dist:
		return throttle_far
	else:
		# Interpolate between near and far.
		var t: float = (dist - throttle_near_dist) / (throttle_far_dist - throttle_near_dist)
		return lerpf(throttle_near, throttle_far, t)


func _find_player_base() -> void:
	var all_buildings: Array[Node] = _get_cached_buildings()
	for bld: Node in all_buildings:
		if not (bld is Node2D):
			continue
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid != ai_player_id:
			var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
			if btype == "town_center":
				_player_base_position = (bld as Node2D).global_position
				_player_base_valid = true
				return

	_player_base_valid = false

# =============================================================================
# Cached Queries
# =============================================================================

func _get_cached_units() -> Array[Node]:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _unit_cache["timestamp"] < cache_lifetime:
		return _unit_cache["units"]

	_unit_cache["units"] = get_tree().get_nodes_in_group("units")
	_unit_cache["timestamp"] = now
	return _unit_cache["units"]


func _get_cached_buildings() -> Array[Node]:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _building_cache["timestamp"] < cache_lifetime:
		return _building_cache["buildings"]

	_building_cache["buildings"] = get_tree().get_nodes_in_group("buildings")
	_building_cache["timestamp"] = now
	return _building_cache["buildings"]


func _invalidate_caches() -> void:
	_unit_cache = {"units": [], "timestamp": -1.0}
	_building_cache = {"buildings": [], "timestamp": -1.0}
	_strength_cache_time = -1.0
	_own_base_valid = false
	_player_base_valid = false

# =============================================================================
# Decision Making
# =============================================================================

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

	_decision_history.append(priority)
	if _decision_history.size() > HISTORY_SIZE:
		_decision_history.pop_front()

	decision_made.emit(priority, target_pos)


func _evaluate_priority() -> String:
	# Refresh strength cache periodically.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _strength_cache_time > 2.0:
		_cached_military_strength = _calc_military_strength()
		_cached_economic_strength = _calc_economic_strength()
		_strength_cache_time = now

	var military_str: int = _cached_military_strength
	var economic_str: int = _cached_economic_strength
	var threat: int = _get_own_base_threat()
	var weights: Dictionary = _personality_weights.get(personality, _personality_weights["balanced"])

	if threat > military_str * 2:
		return "DEFENSE"

	var econ_threshold: int = int(weights["economy_threshold"])
	if economic_str < econ_threshold:
		return "ECONOMY"

	var mil_threshold: int = int(weights["military_threshold"])
	if military_str < mil_threshold and personality != "defensive":
		return "MILITARY"

	var econ_score: float = float(economic_str) * weights["economy_bias"]
	var mil_score: float = float(military_str) * weights["military_bias"]
	var exp_threshold: float = weights["expansion_threshold"]

	match personality:
		"aggressive":
			if mil_score > 80:
				return "MILITARY"
			if threat > 0 and mil_score > 40:
				return "MILITARY"
			if econ_score > 60:
				return "EXPANSION"
			return "ECONOMY"
		"defensive":
			if threat > int(weights["defense_threshold"]):
				return "DEFENSE"
			if econ_score > 80 and mil_score < 40:
				return "MILITARY"
			return "ECONOMY"
		_:
			if mil_score > 80:
				return "MILITARY"
			if econ_score > exp_threshold:
				return "EXPANSION"
			return "ECONOMY"

# =============================================================================
# Strength Calculations (cached)
# =============================================================================

func _calc_military_strength() -> int:
	var total: int = 0
	var all_units: Array[Node] = _get_cached_units()
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


func _calc_economic_strength() -> int:
	var total: int = 0
	var all_units: Array[Node] = _get_cached_units()
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype == "villager":
			total += 10
	var all_buildings: Array[Node] = _get_cached_buildings()
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

# =============================================================================
# Target Finding (with cached data)
# =============================================================================

func find_weakest_point() -> Vector2:
	var base_pos: Vector2 = _get_own_base_position()
	var weakest: Vector2 = base_pos
	var min_threat: int = 999999

	for angle_i: int in range(0, 360, 45):
		var check_pos: Vector2 = base_pos + Vector2.from_angle(deg_to_rad(float(angle_i))) * 200.0
		var threat: int = 0
		var all_units: Array[Node] = _get_cached_units()
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

	var all_buildings: Array[Node] = _get_cached_buildings()
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

	var all_units: Array[Node] = _get_cached_units()
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

		var threat: int = 0
		var scene: Node = get_tree().current_scene
		if scene != null:
			var combat_manager: Node = scene.get_node_or_null("CombatManager")
			if combat_manager != null and combat_manager.has_method("get_threat_at_position"):
				threat = combat_manager.get_threat_at_position(check_pos, 200.0, ai_player_id)
		var enemy_nearby: bool = false
		var all_units: Array[Node] = _get_cached_units()
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

# =============================================================================
# Getters
# =============================================================================

func get_personality_weight(key: String) -> float:
	return _personality_weights.get(personality, _personality_weights["balanced"]).get(key, 0.0)


func get_decision_history() -> Array[String]:
	return _decision_history.duplicate()


func get_personality_profile() -> Dictionary:
	return _personality_weights.get(personality, _personality_weights["balanced"]).duplicate()


func get_military_strength() -> int:
	return _cached_military_strength


func get_economic_strength() -> int:
	return _cached_economic_strength

# =============================================================================
# Internal Helpers
# =============================================================================

func _get_own_base_position() -> Vector2:
	if _own_base_valid:
		return _own_base_position

	var all_buildings: Array[Node] = _get_cached_buildings()
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id and bld is Node2D:
			var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
			if btype == "town_center":
				_own_base_position = (bld as Node2D).global_position
				_own_base_valid = true
				return _own_base_position
	return Vector2.ZERO


func _get_own_base_threat() -> int:
	var base_pos: Vector2 = _get_own_base_position()
	var scene: Node = get_tree().current_scene
	if scene == null:
		return 0
	var combat_manager: Node = scene.get_node_or_null("CombatManager")
	if combat_manager != null and combat_manager.has_method("get_threat_at_position"):
		return combat_manager.get_threat_at_position(base_pos, 400.0, ai_player_id)
	return 0
