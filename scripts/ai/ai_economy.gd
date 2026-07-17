## AI economy manager. Executes predefined build orders, balances villager
## distribution across resources, trains villagers, and adapts ratios based
## on personality and game phase.
extends Node

signal economy_action(action: String, detail: String)

# =============================================================================
# Build Orders — sequential steps executed in order
# =============================================================================

const BUILD_ORDERS: Dictionary = {
	"aggressive": [
		{"phase": "early", "condition": "villagers>=4",  "action": "gather", "resource": "food", "count": 3},
		{"phase": "early", "condition": "villagers>=5",  "action": "gather", "resource": "wood", "count": 2},
		{"phase": "early", "condition": "villagers>=7",  "action": "build",  "building": "barracks"},
		{"phase": "early", "condition": "villagers>=8",  "action": "gather", "resource": "gold", "count": 2},
		{"phase": "mid",   "condition": "barracks_done", "action": "train",  "unit": "swordsman", "target": 4},
		{"phase": "mid",   "condition": "villagers>=12", "action": "build",  "building": "archery_range"},
		{"phase": "mid",   "condition": "villagers>=15", "action": "train",  "unit": "archer", "target": 3},
		{"phase": "late",  "condition": "villagers>=20", "action": "build",  "building": "stable"},
		{"phase": "late",  "condition": "stable_done",   "action": "train",  "unit": "cavalry", "target": 3},
	],
	"defensive": [
		{"phase": "early", "condition": "villagers>=5",  "action": "gather", "resource": "food", "count": 3},
		{"phase": "early", "condition": "villagers>=6",  "action": "gather", "resource": "wood", "count": 3},
		{"phase": "early", "condition": "villagers>=9",  "action": "build",  "building": "barracks"},
		{"phase": "early", "condition": "villagers>=10", "action": "gather", "resource": "stone", "count": 2},
		{"phase": "mid",   "condition": "barracks_done", "action": "build",  "building": "tower"},
		{"phase": "mid",   "condition": "villagers>=14", "action": "build",  "building": "archery_range"},
		{"phase": "mid",   "condition": "villagers>=18", "action": "train",  "unit": "spearman", "target": 5},
		{"phase": "late",  "condition": "villagers>=25", "action": "build",  "building": "castle"},
	],
	"balanced": [
		{"phase": "early", "condition": "villagers>=4",  "action": "gather", "resource": "food", "count": 3},
		{"phase": "early", "condition": "villagers>=6",  "action": "gather", "resource": "wood", "count": 2},
		{"phase": "early", "condition": "villagers>=8",  "action": "build",  "building": "barracks"},
		{"phase": "early", "condition": "villagers>=9",  "action": "gather", "resource": "gold", "count": 1},
		{"phase": "mid",   "condition": "barracks_done", "action": "train",  "unit": "swordsman", "target": 3},
		{"phase": "mid",   "condition": "villagers>=14", "action": "build",  "building": "archery_range"},
		{"phase": "mid",   "condition": "villagers>=18", "action": "train",  "unit": "archer", "target": 3},
		{"phase": "late",  "condition": "villagers>=22", "action": "build",  "building": "stable"},
		{"phase": "late",  "condition": "villagers>=28", "action": "train",  "unit": "cavalry", "target": 2},
	],
	"turtle": [
		{"phase": "early", "condition": "villagers>=5",  "action": "gather", "resource": "food", "count": 3},
		{"phase": "early", "condition": "villagers>=7",  "action": "gather", "resource": "wood", "count": 3},
		{"phase": "early", "condition": "villagers>=8",  "action": "gather", "resource": "stone", "count": 2},
		{"phase": "early", "condition": "villagers>=11", "action": "build",  "building": "barracks"},
		{"phase": "mid",   "condition": "barracks_done", "action": "build",  "building": "tower"},
		{"phase": "mid",   "condition": "villagers>=15", "action": "build",  "building": "tower"},
		{"phase": "mid",   "condition": "villagers>=18", "action": "train",  "unit": "spearman", "target": 4},
		{"phase": "late",  "condition": "villagers>=25", "action": "build",  "building": "castle"},
		{"phase": "late",  "condition": "castle_done",   "action": "train",  "unit": "swordsman", "target": 6},
	],
}

# =============================================================================
# Properties
# =============================================================================

var ai_player_id: int = -1
var personality: String = "balanced"

var _order_index: int = 0
var _order_phase: String = "early"
var _build_order_complete: bool = false

var _target_ratios: Dictionary = {
	"food": 0.35, "wood": 0.30, "gold": 0.20, "stone": 0.15,
}
var _rebalance_timer: float = 0.0
const REBALANCE_INTERVAL: float = 5.0

var _train_timer: float = 0.0
const TRAIN_INTERVAL: float = 8.0

# =============================================================================
# Lifecycle
# =============================================================================

func initialize(player_id: int, ai_personality: String = "balanced") -> void:
	ai_player_id = player_id
	personality = ai_personality
	_order_index = 0
	_order_phase = "early"
	_build_order_complete = false

	match personality:
		"aggressive":
			_target_ratios = {"food": 0.30, "wood": 0.25, "gold": 0.30, "stone": 0.15}
		"defensive":
			_target_ratios = {"food": 0.40, "wood": 0.35, "gold": 0.10, "stone": 0.15}
		"turtle":
			_target_ratios = {"food": 0.35, "wood": 0.25, "gold": 0.10, "stone": 0.30}
		_:
			_target_ratios = {"food": 0.35, "wood": 0.30, "gold": 0.20, "stone": 0.15}

# =============================================================================
# Main Entry
# =============================================================================

func manage_economy(delta: float) -> void:
	_process_build_order()
	_rebalance_timer += delta
	if _rebalance_timer >= REBALANCE_INTERVAL:
		_rebalance_timer = 0.0
		_rebalance_villagers()
	_assign_idle_villagers()

	_train_timer += delta
	if _train_timer >= TRAIN_INTERVAL:
		_train_timer = 0.0
		_train_villagers()

# =============================================================================
# Build Order Execution
# =============================================================================

func _process_build_order() -> void:
	if _build_order_complete:
		return

	var orders: Array = BUILD_ORDERS.get(personality, BUILD_ORDERS["balanced"])
	if _order_index >= orders.size():
		_build_order_complete = true
		return

	var step: Dictionary = orders[_order_index]
	if not _check_condition(step.get("condition", "")):
		return

	_execute_order_step(step)
	_order_index += 1


func _check_condition(condition: String) -> bool:
	if condition.is_empty():
		return true

	if condition.begins_with("villagers>="):
		var required: int = int(condition.substr(11))
		return _count_own_villagers() >= required

	if condition == "barracks_done":
		return _get_building_count("barracks") > 0
	if condition == "archery_range_done":
		return _get_building_count("archery_range") > 0
	if condition == "stable_done":
		return _get_building_count("stable") > 0
	if condition == "castle_done":
		return _get_building_count("castle") > 0

	return true


func _execute_order_step(step: Dictionary) -> void:
	var action: String = step.get("action", "")

	match action:
		"gather":
			var res_type: String = step.get("resource", "food")
			var count: int = step.get("count", 2)
			_assign_villagers_to_resource(res_type, count)
			economy_action.emit("gather", res_type)

		"build":
			var btype: String = step.get("building", "")
			_queue_building(btype)
			economy_action.emit("build", btype)

		"train":
			var utype: String = step.get("unit", "swordsman")
			var target: int = step.get("target", 3)
			_train_unit_type(utype, target)
			economy_action.emit("train", utype)

# =============================================================================
# Villager Assignment
# =============================================================================

func _assign_villagers_to_resource(resource_type: String, count: int) -> void:
	var idle: Array[Node] = _get_idle_villagers()
	var assigned: int = 0
	for villager: Node in idle:
		if assigned >= count:
			break
		var nearest: Node2D = _find_nearest_resource(villager as Node2D, resource_type)
		if nearest != null:
			_send_villager_to_resource(villager, nearest)
			assigned += 1


func _assign_idle_villagers() -> void:
	var idle: Array[Node] = _get_idle_villagers()
	if idle.is_empty():
		return

	var distribution: Dictionary = _get_villager_distribution()
	var total: int = _count_own_villagers()
	if total == 0:
		return

	for villager: Node in idle:
		var neediest: String = _find_needy_resource(distribution, total)
		if neediest.is_empty():
			return
		var nearest: Node2D = _find_nearest_resource(villager as Node2D, neediest)
		if nearest != null:
			_send_villager_to_resource(villager, nearest)
			distribution[neediest] = distribution.get(neediest, 0) + 1
			total += 1


func _rebalance_villagers() -> void:
	var distribution: Dictionary = _get_villager_distribution()
	var total: int = _count_own_villagers()
	if total == 0:
		return

	for res_type: String in _target_ratios:
		var ideal: float = _target_ratios[res_type]
		var actual: float = float(distribution.get(res_type, 0)) / float(total)
		if actual > ideal * 1.6:
			var surplus: int = int((actual - ideal) * float(total))
			_reassign_surplus(res_type, surplus, distribution, total)


func _reassign_surplus(resource_type: String, surplus: int, distribution: Dictionary, total: int) -> void:
	var workers: Array[Node] = _get_villagers_on_resource(resource_type)
	var moved: int = 0
	for i in range(workers.size() - 1, -1, -1):
		if moved >= surplus:
			break
		var villager: Node = workers[i]
		var neediest: String = _find_needy_resource(distribution, total)
		if neediest.is_empty():
			break
		var nearest: Node2D = _find_nearest_resource(villager as Node2D, neediest)
		if nearest != null:
			_send_villager_to_resource(villager, nearest)
			distribution[resource_type] = distribution.get(resource_type, 0) - 1
			distribution[neediest] = distribution.get(neediest, 0) + 1
			moved += 1


func _find_needy_resource(distribution: Dictionary, total: int) -> String:
	var best_deficit: float = 0.0
	var best: String = ""
	for res_type: String in _target_ratios:
		var ideal: float = _target_ratios[res_type]
		var actual: float = float(distribution.get(res_type, 0)) / float(total) if total > 0 else 0.0
		var deficit: float = ideal - actual
		if deficit > best_deficit:
			best_deficit = deficit
			best = res_type
	return best

# =============================================================================
# Training
# =============================================================================

func _train_villagers() -> void:
	var food: int = GameManager.get_resource("food", ai_player_id)
	if food < 50:
		return

	var villagers: int = _count_own_villagers()
	var cap: int = _get_villager_cap()
	if villagers >= cap:
		return

	var tcs: Array[Node] = _get_own_buildings("town_center")
	if tcs.is_empty():
		return

	for tc: Node in tcs:
		if tc.has_method("can_produce") and tc.can_produce("villager"):
			if tc.has_method("start_production"):
				tc.start_production("villager")
				economy_action.emit("train", "villager")
				return


func _train_unit_type(unit_type: String, target_count: int) -> void:
	var current: int = _count_own_units_of_type(unit_type)
	if current >= target_count:
		return

	var data: Dictionary = DataManager.get_unit_data(unit_type)
	if data.is_empty():
		return
	var cost: Dictionary = data.get("cost", {})
	if not GameManager.can_afford(cost, ai_player_id):
		return

	var producers: Array[Node] = _get_producers_for_unit(unit_type)
	if producers.is_empty():
		return

	for producer: Node in producers:
		if producer.has_method("can_produce") and producer.can_produce(unit_type):
			if producer.has_method("start_production"):
				producer.start_production(unit_type)
				return


func _get_producers_for_unit(unit_type: String) -> Array[Node]:
	match unit_type:
		"swordsman", "spearman":
			return _get_own_buildings("barracks")
		"archer":
			return _get_own_buildings("archery_range")
		"cavalry":
			return _get_own_buildings("stable")
		_:
			return _get_own_buildings("barracks")

# =============================================================================
# Building
# =============================================================================

func _queue_building(building_type: String) -> void:
	var data: Dictionary = DataManager.get_building_data(building_type)
	if data.is_empty():
		return
	var cost: Dictionary = data.get("cost", {})
	if not GameManager.can_afford(cost, ai_player_id):
		return

	var base_pos: Vector2 = _get_own_base_position()
	if base_pos == Vector2.ZERO:
		return

	var spot: Vector2 = base_pos + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	GameManager.spend_resources(cost, ai_player_id)

	var building_id: int = randi()
	EventBus.building_placed.emit(building_id, building_type, ai_player_id, spot)
	EventBus.ai_expansion_planned.emit(ai_player_id, spot, building_type)

# =============================================================================
# Distribution Tracking
# =============================================================================

func _get_villager_distribution() -> Dictionary:
	var dist: Dictionary = {"food": 0, "wood": 0, "stone": 0, "gold": 0}
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype != "villager":
			continue
		var assigned: String = unit.get("assigned_resource") if unit.get("assigned_resource") != null else ""
		if assigned in dist:
			dist[assigned] += 1
	return dist

# =============================================================================
# Helpers
# =============================================================================

func _get_villager_cap() -> int:
	match personality:
		"aggressive":
			return 18
		"turtle":
			return 35
		"defensive":
			return 30
		_:
			return 25


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
		var sm: Node = unit.get_node_or_null("UnitStateMachine")
		if sm != null and sm.has_method("get_current_state_name"):
			if sm.get_current_state_name() == "IdleState":
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


func _count_own_units_of_type(unit_type: String) -> int:
	var count: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype == unit_type:
			count += 1
	return count


func _get_building_count(btype: String) -> int:
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


func _get_own_buildings(btype: String) -> Array[Node]:
	var result: Array[Node] = []
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid != ai_player_id:
			continue
		var bt: String = bld.get("building_type") if bld.get("building_type") != null else ""
		if bt == btype and bld.get("is_constructed") == true:
			result.append(bld)
	return result


func _get_own_base_position() -> Vector2:
	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		var pid: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if pid == ai_player_id and bld is Node2D:
			var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
			if btype == "town_center":
				return (bld as Node2D).global_position
	return Vector2.ZERO


func _find_nearest_resource(villager: Node2D, resource_type: String) -> Node2D:
	if villager == null:
		return null
	var best: Node2D = null
	var best_dist: float = 999999.0
	var all_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_nodes")
	for res: Node in all_nodes:
		if not (res is Node2D):
			continue
		var rtype: String = res.get("resource_type") if res.get("resource_type") != null else ""
		if rtype != resource_type:
			continue
		var amount: int = res.get("current_amount") if res.get("current_amount") != null else 0
		if amount <= 0:
			continue
		var dist: float = villager.global_position.distance_to((res as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best = res as Node2D
	return best


func _send_villager_to_resource(villager: Node, resource: Node) -> void:
	if villager == null or resource == null:
		return
	var resource_type: String = resource.get("resource_type") if resource.get("resource_type") != null else ""
	villager.set("assigned_resource", resource_type)
	villager.set("pending_target_resource", resource)
	var sm: Node = villager.get_node_or_null("UnitStateMachine")
	if sm != null and sm.has_method("change_state"):
		sm.change_state("HarvestState")
