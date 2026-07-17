## Tracks resource income per second using a sliding time window.
## Records every deposit event and computes rolling rates over the last
## INCOME_WINDOW seconds. Exposed via get_income_per_second() and
## get_all_incomes() for UI display (e.g. "+5.2/s" next to resource counts).
class_name ResourceIncomeTracker
extends Node

signal income_changed(player_id: int, resource_type: String, ips: float)

const INCOME_WINDOW: float = 30.0
const PRUNE_INTERVAL: float = 2.0
const SIGNAL_DELTA_THRESHOLD: float = 0.3

var _income_log: Dictionary = {}
var _prune_timer: float = 0.0
var _last_emitted: Dictionary = {}


func _ready() -> void:
	if not EventBus.resource_collected.is_connected(_on_resource_collected):
		EventBus.resource_collected.connect(_on_resource_collected)
	if not EventBus.resource_drop_off.is_connected(_on_resource_drop_off):
		EventBus.resource_drop_off.connect(_on_resource_drop_off)


func _process(delta: float) -> void:
	_prune_timer += delta
	if _prune_timer >= PRUNE_INTERVAL:
		_prune_timer = 0.0
		_prune_expired()
		_emit_changed_for_all()

# =============================================================================
# Recording
# =============================================================================

func _on_resource_collected(resource_type: String, amount: int, _collector_id: int, player_id: int) -> void:
	_record(player_id, resource_type, amount)


func _on_resource_drop_off(_villager_id: int, _drop_off_id: int, resource_type: String, amount: int) -> void:
	_record(_get_villager_player_id(_villager_id), resource_type, amount)


func _record(player_id: int, resource_type: String, amount: int) -> void:
	if player_id == -1:
		return
	if amount <= 0:
		return
	if player_id not in _income_log:
		_income_log[player_id] = {}
	if resource_type not in _income_log[player_id]:
		_income_log[player_id][resource_type] = []

	_income_log[player_id][resource_type].append({
		"time": Time.get_ticks_msec() / 1000.0,
		"amount": amount,
	})

# =============================================================================
# Query API
# =============================================================================

func get_income_per_second(resource_type: String, player_id: int) -> float:
	if player_id not in _income_log:
		return 0.0
	if resource_type not in _income_log[player_id]:
		return 0.0

	var now: float = Time.get_ticks_msec() / 1000.0
	var window_start: float = now - INCOME_WINDOW
	var total: int = 0
	var entries: Array = _income_log[player_id][resource_type]

	var i: int = entries.size() - 1
	while i >= 0:
		var entry: Dictionary = entries[i]
		if entry["time"] < window_start:
			break
		total += entry["amount"]
		i -= 1

	var elapsed: float = minf(now - window_start, INCOME_WINDOW)
	if elapsed <= 0.0:
		return 0.0

	return float(total) / elapsed


func get_all_incomes(player_id: int) -> Dictionary:
	var result: Dictionary = {}
	if player_id not in _income_log:
		return result
	for resource_type: String in _income_log[player_id]:
		result[resource_type] = get_income_per_second(resource_type, player_id)
	return result


func get_total_income(player_id: int) -> float:
	var all: Dictionary = get_all_incomes(player_id)
	var total: float = 0.0
	for key: String in all:
		total += all[key]
	return total

# =============================================================================
# Pruning
# =============================================================================

func _prune_expired() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var cutoff: float = now - INCOME_WINDOW
	for player_id: Variant in _income_log:
		var player_log: Dictionary = _income_log[player_id]
		for resource_type: String in player_log:
			var entries: Array = player_log[resource_type]
			var j: int = entries.size() - 1
			while j >= 0:
				if entries[j]["time"] < cutoff:
					entries.remove_at(j)
				j -= 1

# =============================================================================
# Signal Emission (throttled to avoid spam)
# =============================================================================

func _emit_changed_for_all() -> void:
	for player_id: Variant in _income_log:
		var pid: int = int(player_id)
		for resource_type: String in _income_log[pid]:
			var ips: float = get_income_per_second(resource_type, pid)
			var key: String = "%d_%s" % [pid, resource_type]
			var prev: float = _last_emitted.get(key, -999.0)
			if absf(ips - prev) >= SIGNAL_DELTA_THRESHOLD:
				_last_emitted[key] = ips
				income_changed.emit(pid, resource_type, ips)

# =============================================================================
# Helpers
# =============================================================================

func _get_villager_player_id(villager_id: int) -> int:
	var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
	for v: Node in villagers:
		if v.has_method("get") and v.get("unit_id") != null and v.get("unit_id") == villager_id:
			return v.get("player_id") if v.get("player_id") != null else -1
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for u: Node in units:
		if u.has_method("get") and u.get("unit_id") != null and u.get("unit_id") == villager_id:
			return u.get("player_id") if u.get("player_id") != null else -1
	return -1

# =============================================================================
# Serialization
# =============================================================================

func get_save_data() -> Dictionary:
	return {"income_log": _income_log.duplicate(true)}


func load_save_data(data: Dictionary) -> void:
	_income_log = data.get("income_log", {}).duplicate(true)
