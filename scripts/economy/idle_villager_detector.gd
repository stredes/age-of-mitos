## Detects idle villagers and emits signals when they transition between
## idle and working states. Scans periodically and maintains per-player
## idle counts for UI display and AI decision-making.
class_name IdleVillagerDetector
extends Node

signal villager_became_idle(villager_id: int, player_id: int)
signal villager_started_working(villager_id: int, player_id: int)
signal idle_count_changed(player_id: int, count: int)

const SCAN_INTERVAL: float = 1.0
const RESOURCE_TYPES: Array[String] = ["wood", "stone", "food", "gold"]

var _tracked: Dictionary = {}
var _prev_idle: Dictionary = {}
var _scan_timer: float = 0.0


func _ready() -> void:
	if not EventBus.unit_spawned.is_connected(_on_unit_spawned):
		EventBus.unit_spawned.connect(_on_unit_spawned)
	if not EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.connect(_on_unit_died)
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)
	call_deferred("_initial_scan")


func _process(delta: float) -> void:
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan()

# =============================================================================
# Initialization
# =============================================================================

func _on_game_started(_player_id: int) -> void:
	call_deferred("_initial_scan")


func _initial_scan() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var villagers: Array[Node] = scene.get_tree().get_nodes_in_group("villagers")
	for v: Node in villagers:
		if v is Node2D:
			_add_villager(v as Node2D)

# =============================================================================
# Tracking
# =============================================================================

func _on_unit_spawned(_unit_id: int, unit_type: String, player_id: int, _position: Vector2) -> void:
	if not _is_villager_type(unit_type):
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var units: Array[Node] = scene.get_tree().get_nodes_in_group("units")
	for u: Node in units:
		if u is Node2D and u.has_method("get") and u.get("unit_id") != null and u.get("unit_id") == _unit_id:
			_add_villager(u as Node2D)
			return


func _on_unit_died(unit_id: int, _killer_id: int, _player_id: int) -> void:
	_remove_villager(unit_id)


func _add_villager(unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
	if pid == -1:
		return
	var uid: int = unit.get("unit_id") if unit.get("unit_id") != null else -1
	if uid == -1:
		return

	if pid not in _tracked:
		_tracked[pid] = {}
		_prev_idle[pid] = {}

	_tracked[pid][uid] = unit


func _remove_villager(unit_id: int) -> void:
	for pid: Variant in _tracked:
		if _tracked[pid].has(unit_id):
			_tracked[pid].erase(unit_id)
			if pid in _prev_idle and _prev_idle[pid].has(unit_id):
				_prev_idle[pid].erase(unit_id)
			return

# =============================================================================
# Scanning
# =============================================================================

func _scan() -> void:
	for pid: Variant in _tracked:
		var player_id: int = int(pid)
		var current_idle: Dictionary = {}
		var prev: Dictionary = _prev_idle.get(player_id, {})

		for uid_variant: Variant in _tracked[pid]:
			var uid: int = int(uid_variant)
			var unit: Node2D = _tracked[pid][uid_variant]
			if not is_instance_valid(unit):
				continue

			var is_idle: bool = _check_idle(unit)
			current_idle[uid] = is_idle

			var was_idle: bool = prev.get(uid, false)
			if is_idle and not was_idle:
				villager_became_idle.emit(uid, player_id)
			elif not is_idle and was_idle:
				villager_started_working.emit(uid, player_id)

		_prev_idle[player_id] = current_idle

		var idle_count: int = 0
		for uid_key: Variant in current_idle:
			if current_idle[uid_key]:
				idle_count += 1
		idle_count_changed.emit(player_id, idle_count)

# =============================================================================
# Query API
# =============================================================================

func get_idle_villager_count(player_id: int) -> int:
	var prev: Dictionary = _prev_idle.get(player_id, {})
	var count: int = 0
	for uid: Variant in prev:
		if prev[uid]:
			count += 1
	return count


func get_idle_villagers(player_id: int) -> Array[int]:
	var result: Array[int] = []
	var prev: Dictionary = _prev_idle.get(player_id, {})
	for uid: Variant in prev:
		if prev[uid]:
			result.append(int(uid))
	return result


func get_total_villager_count(player_id: int) -> int:
	return _tracked.get(player_id, {}).size()


func get_idle_percentage(player_id: int) -> float:
	var total: int = get_total_villager_count(player_id)
	if total <= 0:
		return 0.0
	return float(get_idle_villager_count(player_id)) / float(total)


func get_idle_count_for_resource(player_id: int, resource_type: String) -> int:
	var prev: Dictionary = _prev_idle.get(player_id, {})
	var count: int = 0
	for uid: Variant in prev:
		if not prev[uid]:
			continue
		var unit: Node2D = _tracked.get(player_id, {}).get(uid, null)
		if unit == null or not is_instance_valid(unit):
			continue
		var pref: String = unit.get("preferred_resource") if unit.get("preferred_resource") != null else ""
		if pref == resource_type:
			count += 1
	return count

# =============================================================================
# Helpers
# =============================================================================

func _check_idle(unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false

	var sm: Node = unit.get_node_or_null("UnitStateMachine")
	if sm == null:
		return false

	if sm.has_method("get_current_state_name"):
		var state_name: String = sm.get_current_state_name()
		return state_name == "IdleState"

	if sm.has_method("get_state"):
		var state: Node = sm.get_state()
		if state != null:
			var state_class: String = state.get_script().get_global_name() if state.get_script() != null else ""
			return state_class == "IdleState"

	var current: Node = sm.get("current_state") if sm.get("current_state") != null else null
	if current != null:
		var cn: String = current.get_script().get_global_name() if current.get_script() != null else ""
		return cn == "IdleState"

	return false


func _is_villager_type(unit_type: String) -> bool:
	var data: Dictionary = DataManager.get_unit_data(unit_type)
	if data.is_empty():
		return false
	var cat: String = data.get("unit_category", "")
	if cat == "civil":
		return true
	if unit_type in ["villager", "lumberjack", "miner", "builder"]:
		return true
	return false
