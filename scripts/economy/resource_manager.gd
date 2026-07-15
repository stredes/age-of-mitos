## Manages resource economy for all players. Tracks resource amounts, gather rates,
## resource collection, drop-off, and provides cost checking and spending.
class_name ResourceManager
extends Node

# =============================================================================
# Signals
# =============================================================================

signal resource_updated(resource_type: String, amount: int, player_id: int)

# =============================================================================
# Constants
# =============================================================================

const BASE_GATHER_RATES: Dictionary = {
	"wood": 0.39,
	"stone": 0.39,
	"food": 0.39,
	"gold": 0.39,
}

const CARRY_CAPACITY: Dictionary = {
	"villager": 10,
}

# =============================================================================
# Properties
# =============================================================================

var global_resources: Dictionary = {}

var gather_rates: Dictionary = {}
var gather_rate_modifiers: Dictionary = {}

var _player_buffers: Dictionary = {}

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_connect_event_bus()


func _process(_delta: float) -> void:
	pass

# =============================================================================
# Setup
# =============================================================================

func _connect_event_bus() -> void:
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)
	if not EventBus.resource_collected.is_connected(_on_resource_collected):
		EventBus.resource_collected.connect(_on_resource_collected)
	if not EventBus.resource_drop_off.is_connected(_on_resource_drop_off):
		EventBus.resource_drop_off.connect(_on_resource_drop_off)
	if not EventBus.unit_spawned.is_connected(_on_unit_spawned):
		EventBus.unit_spawned.connect(_on_unit_spawned)

# =============================================================================
# Initialization
# =============================================================================

func _on_game_started(player_id: int) -> void:
	_initialize_all_players()


func _initialize_all_players() -> void:
	var all_ids: Array = GameManager.get_all_player_ids()
	for pid_variant: Variant in all_ids:
		var pid: int = pid_variant if pid_variant is int else int(pid_variant)
		_initialize_player(pid)


func _initialize_player(player_id: int) -> void:
	var player_data: Dictionary = GameManager.get_player(player_id)
	if player_data.is_empty():
		return

	global_resources[player_id] = player_data.get("resources", {}).duplicate()

	gather_rates[player_id] = {}
	gather_rate_modifiers[player_id] = {}
	for resource_type: String in BASE_GATHER_RATES:
		gather_rates[player_id][resource_type] = BASE_GATHER_RATES[resource_type]
		gather_rate_modifiers[player_id][resource_type] = 1.0

	_player_buffers[player_id] = {}

	for resource_type: String in global_resources[player_id]:
		var amount: int = global_resources[player_id][resource_type]
		resource_updated.emit(resource_type, amount, player_id)

# =============================================================================
# Resource Collection
# =============================================================================

func _on_resource_collected(resource_type: String, amount: int, collector_id: int, player_id: int) -> void:
	_add_to_buffer(player_id, resource_type, amount)


func _on_resource_drop_off(villager_id: int, drop_off_id: int, resource_type: String, amount: int) -> void:
	var player_id: int = _get_villager_player_id(villager_id)
	if player_id == -1:
		return

	_add_to_buffer(player_id, resource_type, amount)

# =============================================================================
# Buffer System
# =============================================================================

func _add_to_buffer(player_id: int, resource_type: String, amount: int) -> void:
	if player_id not in _player_buffers:
		_player_buffers[player_id] = {}
	if resource_type not in _player_buffers[player_id]:
		_player_buffers[player_id][resource_type] = 0

	_player_buffers[player_id][resource_type] += amount


func flush_buffers(player_id: int) -> void:
	if player_id not in _player_buffers:
		return

	for resource_type: String in _player_buffers[player_id]:
		var buffered: int = _player_buffers[player_id][resource_type]
		if buffered > 0:
			GameManager.add_resource(resource_type, buffered, player_id)
			_update_local_cache(player_id, resource_type)

	_player_buffers[player_id].clear()


func flush_buffer(player_id: int, resource_type: String) -> void:
	if player_id not in _player_buffers:
		return
	if resource_type not in _player_buffers[player_id]:
		return

	var buffered: int = _player_buffers[player_id][resource_type]
	if buffered > 0:
		GameManager.add_resource(resource_type, buffered, player_id)
		_update_local_cache(player_id, resource_type)

	_player_buffers[player_id][resource_type] = 0


func _update_local_cache(player_id: int, resource_type: String) -> void:
	if player_id not in global_resources:
		global_resources[player_id] = {}
	global_resources[player_id][resource_type] = GameManager.get_resource(resource_type, player_id)

# =============================================================================
# Gather Rates
# =============================================================================

func get_gather_rate(resource_type: String, player_id: int) -> float:
	if player_id not in gather_rates:
		return 0.0
	var base_rate: float = gather_rates[player_id].get(resource_type, 0.0)
	var modifier: float = gather_rate_modifiers.get(player_id, {}).get(resource_type, 1.0)
	return base_rate * modifier


func set_gather_rate_modifier(resource_type: String, modifier: float, player_id: int) -> void:
	if player_id not in gather_rate_modifiers:
		gather_rate_modifiers[player_id] = {}
	gather_rate_modifiers[player_id][resource_type] = modifier


func set_gather_rate_base(resource_type: String, rate: float, player_id: int) -> void:
	if player_id not in gather_rates:
		gather_rates[player_id] = {}
	gather_rates[player_id][resource_type] = rate


func get_carry_capacity(unit_type: String) -> int:
	return CARRY_CAPACITY.get(unit_type, 10)

# =============================================================================
# Cost Checking & Spending
# =============================================================================

func can_afford(cost: Dictionary, player_id: int) -> bool:
	_flush_pending(player_id)

	var player_res: Dictionary = global_resources.get(player_id, {})
	for resource_type: String in cost:
		var required: int = cost[resource_type]
		var available: int = player_res.get(resource_type, 0)
		if available < required:
			return false
	return true


func spend(cost: Dictionary, player_id: int) -> bool:
	if not can_afford(cost, player_id):
		return false

	for resource_type: String in cost:
		var amount: int = cost[resource_type]
		# Try buffered resources first, then GameManager.
		var buffered: int = _get_buffered(player_id, resource_type)
		if buffered >= amount:
			_player_buffers[player_id][resource_type] = buffered - amount
		else:
			_player_buffers[player_id][resource_type] = 0
			var remaining: int = amount - buffered
			GameManager.spend_resource(resource_type, remaining, player_id)

		_update_local_cache(player_id, resource_type)
		resource_updated.emit(resource_type, get_resource_amount(resource_type, player_id), player_id)

	return true

# =============================================================================
# Resource Query
# =============================================================================

func get_resource_amount(resource_type: String, player_id: int) -> int:
	_flush_pending(player_id)
	return global_resources.get(player_id, {}).get(resource_type, 0)


func get_all_resources(player_id: int) -> Dictionary:
	_flush_pending(player_id)
	return global_resources.get(player_id, {}).duplicate()


func get_buffered_amount(resource_type: String, player_id: int) -> int:
	return _get_buffered(player_id, resource_type)

# =============================================================================
# Helpers
# =============================================================================

func _flush_pending(player_id: int) -> void:
	flush_buffers(player_id)


func _get_buffered(player_id: int, resource_type: String) -> int:
	if player_id not in _player_buffers:
		return 0
	return _player_buffers[player_id].get(resource_type, 0)


func _get_villager_player_id(villager_id: int) -> int:
	var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
	for v: Node in villagers:
		if v.has_method("get") and v.get("unit_id") != null and v.get("unit_id") == villager_id:
			return v.get("player_id") if v.get("player_id") != null else -1
	# Fallback: check all units group.
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for u: Node in units:
		if u.has_method("get") and u.get("unit_id") != null and u.get("unit_id") == villager_id:
			return u.get("player_id") if u.get("player_id") != null else -1
	return -1

# =============================================================================
# Event Bus Handlers
# =============================================================================

func _on_unit_spawned(unit_id: int, unit_type: String, player_id: int, _position: Vector2) -> void:
	var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
	if unit_data.is_empty():
		return

	var cost: Dictionary = unit_data.get("cost", {})
	if cost.is_empty():
		return

	for resource_type: String in cost:
		var amount: int = cost[resource_type]
		GameManager.spend_resource(resource_type, amount, player_id)
		_update_local_cache(player_id, resource_type)
		resource_updated.emit(resource_type, get_resource_amount(resource_type, player_id), player_id)

# =============================================================================
# Convenience: Direct Add (for villager carry-drop)
# =============================================================================

func add_resource_direct(resource_type: String, amount: int, player_id: int) -> void:
	if amount <= 0:
		return
	GameManager.add_resource(resource_type, amount, player_id)
	_update_local_cache(player_id, resource_type)
	resource_updated.emit(resource_type, get_resource_amount(resource_type, player_id), player_id)

# =============================================================================
# Technology Integration
# =============================================================================

func apply_tech_gather_bonus(resource_type: String, bonus_percent: float, player_id: int) -> void:
	var current_modifier: float = gather_rate_modifiers.get(player_id, {}).get(resource_type, 1.0)
	set_gather_rate_modifier(resource_type, current_modifier + bonus_percent, player_id)

# =============================================================================
# Serialization
# =============================================================================

func get_save_data() -> Dictionary:
	return {
		"global_resources": global_resources.duplicate(true),
		"gather_rates": gather_rates.duplicate(true),
		"gather_rate_modifiers": gather_rate_modifiers.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	global_resources = data.get("global_resources", {}).duplicate(true)
	gather_rates = data.get("gather_rates", {}).duplicate(true)
	gather_rate_modifiers = data.get("gather_rate_modifiers", {}).duplicate(true)

	for pid: int in global_resources:
		for resource_type: String in global_resources[pid]:
			resource_updated.emit(resource_type, global_resources[pid][resource_type], pid)
