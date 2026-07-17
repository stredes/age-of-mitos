extends Node

signal attack_planned(target_pos: Vector2, army: Array[Node])
signal formation_changed(formation: String)

var ai_player_id: int = -1
var personality: String = "balanced"
var _attack_threshold: int = 80
var _last_attack_time: float = 0.0
var _attack_cooldown: float = 30.0

enum Formation { LINE, WEDGE, SCATTER, FLANK }

var _current_formation: Formation = Formation.LINE
var _formation_spread: float = 60.0
var _rally_point: Vector2 = Vector2.ZERO
var _last_rally_time: float = 0.0
const RALLY_UPDATE_INTERVAL: float = 10.0

var _formation_offsets: Dictionary = {
	Formation.LINE: _get_line_offsets,
	Formation.WEDGE: _get_wedge_offsets,
	Formation.SCATTER: _get_scatter_offsets,
	Formation.FLANK: _get_flank_offsets,
}


func initialize(player_id: int, ai_personality: String = "balanced") -> void:
	ai_player_id = player_id
	personality = ai_personality

	match personality:
		"aggressive":
			_attack_threshold = 60
			_attack_cooldown = 20.0
		"defensive":
			_attack_threshold = 100
			_attack_cooldown = 45.0
		_:
			_attack_threshold = 80
			_attack_cooldown = 30.0


func manage_military(delta: float) -> void:
	train_army()
	_update_rally_point(delta)

	var game_time: float = GameManager.game_time
	if game_time - _last_attack_time < _attack_cooldown:
		return
	if should_attack():
		plan_attack()
	else:
		defend_base()


func train_army() -> void:
	var food: int = GameManager.get_resource("food", ai_player_id)
	var wood: int = GameManager.get_resource("wood", ai_player_id)
	var gold: int = GameManager.get_resource("gold", ai_player_id)

	var barracks: Array[Node] = _get_own_producers(["barracks"])
	var archery_ranges: Array[Node] = _get_own_producers(["archery_range"])
	var stables: Array[Node] = _get_own_producers(["stable"])

	var unit_to_train: String = choose_unit_to_train()
	var unit_data: Dictionary = DataManager.get_unit_data(unit_to_train)
	if unit_data.is_empty():
		return

	var cost: Dictionary = unit_data.get("cost", {})
	if not GameManager.can_afford(cost, ai_player_id):
		return

	var producers: Array[Node] = []
	match unit_to_train:
		"swordsman", "spearman":
			producers = barracks
		"archer":
			producers = archery_ranges
		"cavalry":
			producers = stables
		_:
			producers = barracks

	if producers.is_empty():
		return

	for producer: Node in producers:
		if producer.has_method("can_produce") and producer.can_produce(unit_to_train):
			if producer.has_method("start_production"):
				GameManager.spend_resources(cost, ai_player_id)
				producer.start_production(unit_to_train)
				break


func should_attack() -> bool:
	var strength: int = get_army_strength()
	if strength < _attack_threshold:
		return false
	var army: Array[Node] = _get_combat_units()
	var min_units: int = 3 + int(GameManager.game_time / 120.0)
	return army.size() >= min_units


func plan_attack() -> void:
	var scene: Node = get_tree().current_scene
	var combat_manager: Node = scene.get_node_or_null("CombatManager") if scene != null else null
	var target_pos: Vector2 = Vector2.ZERO

	if combat_manager != null:
		var ai_director: Node = get_parent()
		if ai_director != null and ai_director.has_method("find_enemy_base"):
			target_pos = ai_director.find_enemy_base()
		else:
			target_pos = _find_enemy_center()

	if target_pos == Vector2.ZERO:
		return

	var army: Array[Node] = _get_combat_units()
	if army.is_empty():
		return

	_last_attack_time = GameManager.game_time

	_select_formation(army)
	_send_army_in_formation(army, target_pos)

	EventBus.ai_attack_planned.emit(ai_player_id, _get_target_player(), get_army_strength(), target_pos)
	attack_planned.emit(target_pos, army)


func _select_formation(army: Array[Node]) -> void:
	var composition: Dictionary = get_army_composition()
	var melee_count: int = composition.get("swordsman", 0) + composition.get("spearman", 0)
	var ranged_count: int = composition.get("archer", 0)
	var cav_count: int = composition.get("cavalry", 0)
	var total: int = army.size()

	if total <= 2:
		_current_formation = Formation.LINE
	elif cav_count > total * 0.4:
		_current_formation = Formation.WEDGE
	elif ranged_count > total * 0.5:
		_current_formation = Formation.SCATTER
	elif melee_count > total * 0.6 and total >= 4:
		_current_formation = Formation.FLANK
	else:
		_current_formation = Formation.LINE

	_formation_spread = _get_formation_spread()

	formation_changed.emit(_get_formation_name())


func _get_formation_spread() -> float:
	match _current_formation:
		Formation.LINE:
			return 60.0
		Formation.WEDGE:
			return 50.0
		Formation.SCATTER:
			return 120.0
		Formation.FLANK:
			return 90.0
		_:
			return 60.0


func _get_formation_name() -> String:
	match _current_formation:
		Formation.LINE:
			return "line"
		Formation.WEDGE:
			return "wedge"
		Formation.SCATTER:
			return "scatter"
		Formation.FLANK:
			return "flank"
		_:
			return "line"


func _send_army_in_formation(army: Array[Node], target_pos: Vector2) -> void:
	var offsets: Array[Vector2] = _calculate_offsets(army.size())

	for i in range(army.size()):
		var unit: Node = army[i]
		var offset: Vector2 = offsets[i] if i < offsets.size() else Vector2.ZERO
		var formation_target: Vector2 = target_pos + offset

		unit.set("attack_target_position", formation_target)

		if unit.has_method("set_target"):
			unit.set("attack_target_position", formation_target)


func _calculate_offsets(count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var half: float = float(count) / 2.0

	match _current_formation:
		Formation.LINE:
			for i in range(count):
				var x: float = (float(i) - half) * _formation_spread
				offsets.append(Vector2(x, 0.0))
		Formation.WEDGE:
			for i in range(count):
				var row: int = i / 2
				var side: float = -1.0 if i % 2 == 0 else 1.0
				var x: float = side * float(row) * _formation_spread * 0.5
				var y: float = float(row) * _formation_spread * 0.8
				offsets.append(Vector2(x, y))
		Formation.SCATTER:
			for i in range(count):
				var angle: float = randf() * TAU
				var dist: float = randf_range(_formation_spread * 0.3, _formation_spread)
				offsets.append(Vector2.from_angle(angle) * dist)
		Formation.FLANK:
			var flank_size: int = count / 2
			for i in range(count):
				if i < flank_size:
					var x: float = -_formation_spread * 1.5
					var y: float = (float(i) - float(flank_size) / 2.0) * _formation_spread * 0.6
					offsets.append(Vector2(x, y))
				else:
					var x: float = _formation_spread * 1.5
					var y: float = (float(i - flank_size) - float(count - flank_size) / 2.0) * _formation_spread * 0.6
					offsets.append(Vector2(x, y))

	return offsets


func _get_line_offsets() -> Array[Vector2]:
	return []


func _get_wedge_offsets() -> Array[Vector2]:
	return []


func _get_scatter_offsets() -> Array[Vector2]:
	return []


func _get_flank_offsets() -> Array[Vector2]:
	return []


func defend_base() -> void:
	var base_pos: Vector2 = _get_own_base_position()
	if base_pos == Vector2.ZERO:
		return

	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var combat_manager: Node = scene.get_node_or_null("CombatManager")
	if combat_manager == null:
		return

	var threat: int = combat_manager.get_threat_at_position(base_pos, 400.0, ai_player_id) if combat_manager.has_method("get_threat_at_position") else 0
	if threat <= 0:
		return

	var army: Array[Node] = _get_combat_units()
	if army.size() <= 3:
		for unit: Node in army:
			unit.set("attack_target_position", base_pos)
	else:
		_select_formation(army)
		var defense_offsets: Array[Vector2] = _calculate_offsets(army.size())
		for i in range(army.size()):
			var unit: Node = army[i]
			var offset: Vector2 = defense_offsets[i] if i < defense_offsets.size() else Vector2.ZERO
			unit.set("attack_target_position", base_pos + offset)


func _update_rally_point(delta: float) -> void:
	_last_rally_time += delta
	if _last_rally_time < RALLY_UPDATE_INTERVAL:
		return
	_last_rally_time = 0.0

	var base_pos: Vector2 = _get_own_base_position()
	if base_pos == Vector2.ZERO:
		return

	_rally_point = base_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100))


func should_retreat() -> bool:
	var army: Array[Node] = _get_combat_units()
	if army.is_empty():
		return true

	var strength: int = get_army_strength()
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	var combat_manager: Node = scene.get_node_or_null("CombatManager")
	if combat_manager == null:
		return false

	var enemy_threat: int = combat_manager.get_threat_at_position(_rally_point, 300.0, ai_player_id) if combat_manager.has_method("get_threat_at_position") else 0
	return enemy_threat > strength * 1.5


func get_army_composition() -> Dictionary:
	var composition: Dictionary = {}
	var army: Array[Node] = _get_combat_units()
	for unit: Node in army:
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else "unknown"
		if not composition.has(utype):
			composition[utype] = 0
		composition[utype] += 1
	return composition


func choose_unit_to_train() -> String:
	var enemy_composition: Dictionary = _get_enemy_composition()
	var counters: Dictionary = {
		"archer": "cavalry",
		"cavalry": "spearman",
		"spearman": "swordsman",
		"swordsman": "archer",
		"catapult": "cavalry",
	}

	var highest_count: int = 0
	var dominant_enemy: String = "swordsman"
	for key: String in enemy_composition:
		if enemy_composition[key] > highest_count:
			highest_count = enemy_composition[key]
			dominant_enemy = key

	if counters.has(dominant_enemy):
		var counter: String = counters[dominant_enemy]
		var counter_data: Dictionary = DataManager.get_unit_data(counter)
		if not counter_data.is_empty():
			return counter

	var available: Array[String] = ["swordsman", "spearman", "archer", "cavalry"]
	var own_comp: Dictionary = get_army_composition()
	var least_type: String = "swordsman"
	var least_count: int = 999999
	for utype: String in available:
		var count: int = own_comp.get(utype, 0)
		if count < least_count:
			least_count = count
			least_type = utype
	return least_type


func get_army_strength() -> int:
	var total: int = 0
	var army: Array[Node] = _get_combat_units()
	for unit: Node in army:
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


func _get_combat_units() -> Array[Node]:
	var combat: Array[Node] = []
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype == "villager":
			continue
		var hp: int = 0
		var health_comp: Node = unit.get_node_or_null("HealthComponent")
		if health_comp != null:
			hp = health_comp.get("current_hp") if health_comp.get("current_hp") != null else 0
		else:
			hp = unit.get("current_hp") if unit.get("current_hp") != null else 0
		if hp > 0:
			combat.append(unit)
	return combat


func _get_own_producers(types: Array[String]) -> Array[Node]:
	var producers: Array[Node] = []
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
		if btype in types:
			var constructed: bool = bld.get("is_constructed") if bld.get("is_constructed") != null else false
			if constructed:
				producers.append(bld)
	return producers


func _get_enemy_composition() -> Dictionary:
	var composition: Dictionary = {}
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid == ai_player_id or pid == -1:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype == "villager":
			continue
		if not composition.has(utype):
			composition[utype] = 0
		composition[utype] += 1
	return composition


func _get_own_base_position() -> Vector2:
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id and bld is Node2D:
			var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
			if btype == "town_center":
				return (bld as Node2D).global_position
	return Vector2.ZERO


func _find_enemy_center() -> Vector2:
	var best_pos: Vector2 = Vector2(1000, 1000)
	var min_dist: float = 999999.0
	var own_pos: Vector2 = _get_own_base_position()
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id or pid == -1:
			continue
		if bld is Node2D:
			var dist: float = (bld as Node2D).global_position.distance_to(own_pos)
			if dist < min_dist:
				min_dist = dist
				best_pos = (bld as Node2D).global_position
	return best_pos


func _get_target_player() -> int:
	var all_players: Array = GameManager.get_all_player_ids()
	for pid_variant: Variant in all_players:
		var pid: int = int(pid_variant)
		if pid != ai_player_id and not GameManager.is_ai_player(pid):
			return pid
	for pid_variant: Variant in all_players:
		var pid: int = int(pid_variant)
		if pid != ai_player_id:
			return pid
	return -1
