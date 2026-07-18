## Bridges technology effects to gameplay systems.
##
## Listens to EventBus tech_effect_* signals emitted by TechnologyManager
## and immediately applies modifiers to ResourceManager, CombatComponent,
## HealthComponent, BuildState, ProductionQueue, and other gameplay systems.
## Also stores cumulative modifiers per player so new units/buildings can
## query them at spawn time.
class_name TechEffectsManager
extends Node

# =============================================================================
# Per-Player Modifier Storage
# =============================================================================

## Cumulative multiplicative modifiers keyed by effect_type.
## E.g. { 1: { "wood_gather_rate": 1.4, "melee_attack": 1.2 } }
var _player_modifiers: Dictionary = {}

## Cumulative additive bonuses keyed by effect_type (for flat +N effects).
## E.g. { 1: { "building_armor": 2.0, "range": 2.0 } }
var _player_additive_bonuses: Dictionary = {}

## Derived convenience modifiers per player.
var _player_attack_multiplier: Dictionary = {}
var _player_ranged_attack_multiplier: Dictionary = {}
var _player_range_bonus: Dictionary = {}
var _player_armor_bonus: Dictionary = {}
var _player_cavalry_hp_multiplier: Dictionary = {}
var _player_cavalry_speed_multiplier: Dictionary = {}
var _player_villager_speed_multiplier: Dictionary = {}
var _player_carry_capacity_multiplier: Dictionary = {}
var _player_build_speed: Dictionary = {}
var _player_train_speed: Dictionary = {}

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	EventBus.tech_effect_gather_rate.connect(_on_gather_rate_effect)
	EventBus.tech_effect_attack.connect(_on_attack_effect)
	EventBus.tech_effect_armor.connect(_on_armor_effect)
	EventBus.tech_effect_production.connect(_on_production_effect)
	EventBus.tech_effect_other.connect(_on_other_effect)

# =============================================================================
# Gather Rate Effects
# =============================================================================

func _on_gather_rate_effect(effect_type: String, value: Variant, player_id: int) -> void:
	if not (value is int or value is float):
		return
	var modifier: float = float(value)

	_store_modifier(player_id, effect_type, modifier)

	# Map effect keys to ResourceManager resource types.
	var resource_type: String = ""
	match effect_type:
		"wood_gather_rate":
			resource_type = "wood"
		"food_gather_rate", "farm_capacity":
			resource_type = "food"
		"gold_gather_rate":
			resource_type = "gold"
		"stone_gather_rate":
			resource_type = "stone"

	if resource_type.is_empty():
		return

	var res_manager: Node = _find_node("ResourceManager")
	if res_manager == null:
		return

	# Use multiplicative stacking: get the cumulative modifier and set it.
	var cumulative: float = _get_cumulative_modifier(player_id, effect_type)
	if res_manager.has_method("set_gather_rate_modifier"):
		res_manager.set_gather_rate_modifier(resource_type, cumulative, player_id)

# =============================================================================
# Attack Effects
# =============================================================================

func _on_attack_effect(effect_type: String, value: Variant, player_id: int) -> void:
	if not (value is int or value is float):
		return
	var modifier: float = float(value)

	_store_modifier(player_id, effect_type, modifier)

	# Update the derived attack multiplier for this player.
	match effect_type:
		"melee_attack":
			_player_attack_multiplier[player_id] = _get_cumulative_modifier(player_id, "melee_attack")
		"ranged_attack":
			_player_ranged_attack_multiplier[player_id] = _get_cumulative_modifier(player_id, "ranged_attack")
		"tower_attack", "siege_attack":
			# Tower/siege attack modifiers stored in _player_modifiers for query.
			pass

	# Apply to all existing units of this player.
	_apply_attack_to_existing_units(player_id)

# =============================================================================
# Armor / Defensive Effects
# =============================================================================

func _on_armor_effect(effect_type: String, value: Variant, player_id: int) -> void:
	if not (value is int or value is float):
		return
	var modifier: float = float(value)

	_store_modifier(player_id, effect_type, modifier)

	# Handle range bonuses.
	if effect_type == "range" or effect_type == "siege_range":
		_player_range_bonus[player_id] = _get_range_bonus(player_id)
		_apply_range_to_existing_units(player_id)
		return

	# Handle cavalry HP bonus.
	if effect_type == "cavalry_hp":
		_player_cavalry_hp_multiplier[player_id] = _get_cumulative_modifier(player_id, "cavalry_hp")
		_apply_hp_to_existing_units(player_id)
		return

	# Handle building HP bonus.
	if effect_type == "building_hp" or effect_type == "wall_hp" or effect_type == "tower_hp":
		_apply_building_hp_to_existing(player_id, effect_type)
		return

	# Armor bonuses (cavalry_armor, building_armor).
	_player_armor_bonus[player_id] = _get_armor_bonus(player_id)
	_apply_armor_to_existing_units(player_id)

# =============================================================================
# Production Effects (train speed, build speed)
# =============================================================================

func _on_production_effect(effect_type: String, value: Variant, player_id: int) -> void:
	if not (value is int or value is float):
		return
	var modifier: float = float(value)

	_store_modifier(player_id, effect_type, modifier)

	match effect_type:
		"train_speed":
			_player_train_speed[player_id] = _get_cumulative_modifier(player_id, "train_speed")
			ProductionQueue.set_train_speed_modifier(player_id, _player_train_speed[player_id])
		"build_speed_modifier":
			_player_build_speed[player_id] = _get_cumulative_modifier(player_id, "build_speed_modifier")
			BuildState.set_build_speed_modifier(player_id, _player_build_speed[player_id])

# =============================================================================
# Other Effects (villager speed, carry capacity, cavalry speed, etc.)
# =============================================================================

func _on_other_effect(effect_type: String, value: Variant, player_id: int) -> void:
	if not (value is int or value is float):
		return
	var modifier: float = float(value)

	_store_modifier(player_id, effect_type, modifier)

	match effect_type:
		"villager_speed":
			_player_villager_speed_multiplier[player_id] = _get_cumulative_modifier(player_id, "villager_speed")
			_apply_speed_to_existing_units(player_id, "villager")
		"carry_capacity":
			_player_carry_capacity_multiplier[player_id] = _get_cumulative_modifier(player_id, "carry_capacity")
			_apply_carry_capacity_to_existing(player_id)
		"cavalry_speed":
			_player_cavalry_speed_multiplier[player_id] = _get_cumulative_modifier(player_id, "cavalry_speed")
			_apply_speed_to_existing_units(player_id, "cavalry")

# =============================================================================
# Apply to Existing Entities
# =============================================================================

func _apply_attack_to_existing_units(player_id: int) -> void:
	var melee_mult: float = _player_attack_multiplier.get(player_id, 1.0)
	var ranged_mult: float = _player_ranged_attack_multiplier.get(player_id, 1.0)
	var units: Array[Node] = _get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if not _unit_belongs_to_player(unit, player_id):
			continue
		var combat: Node = unit.get_node_or_null("CombatComponent")
		if combat == null:
			continue
		var base_damage: int = combat.get("attack_damage") if combat.get("attack_damage") != null else 0
		var is_ranged: bool = combat.get("_is_ranged") if combat.get("_is_ranged") != null else false
		if is_ranged:
			combat.tech_attack_multiplier = ranged_mult
		else:
			combat.tech_attack_multiplier = melee_mult


func _apply_range_to_existing_units(player_id: int) -> void:
	var range_b: float = _player_range_bonus.get(player_id, 0.0)
	var units: Array[Node] = _get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if not _unit_belongs_to_player(unit, player_id):
			continue
		var combat: Node = unit.get_node_or_null("CombatComponent")
		if combat != null:
			combat.tech_range_bonus = range_b


func _apply_armor_to_existing_units(player_id: int) -> void:
	var armor_b: int = _player_armor_bonus.get(player_id, 0)

	# Apply to units.
	var units: Array[Node] = _get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if not _unit_belongs_to_player(unit, player_id):
			continue
		var hc: Node = unit.get_node_or_null("HealthComponent")
		if hc != null and hc.has_method("set_tech_armor_bonus"):
			# Compute type-specific bonus.
			var unit_type: String = str(unit.get("unit_type")) if unit.get("unit_type") != null else ""
			var bonus: int = armor_b
			if unit_type == "cavalry":
				var cav_bonus: float = _player_modifiers.get(player_id, {}).get("cavalry_armor", 1.0)
				bonus = int(float(armor_b) * cav_bonus) if cav_bonus > 1.0 else armor_b
			hc.set_tech_armor_bonus(bonus)

	# Apply to buildings.
	var buildings: Array[Node] = _get_tree().get_nodes_in_group("buildings")
	for bld: Node in buildings:
		if not _building_belongs_to_player(bld, player_id):
			continue
		var hc: Node = bld.get_node_or_null("HealthComponent")
		if hc != null and hc.has_method("set_tech_armor_bonus"):
			hc.set_tech_armor_bonus(armor_b)


func _apply_hp_to_existing_units(player_id: int) -> void:
	var cav_hp_mult: float = _player_cavalry_hp_multiplier.get(player_id, 1.0)
	if absf(cav_hp_mult - 1.0) < 0.001:
		return
	var units: Array[Node] = _get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if not _unit_belongs_to_player(unit, player_id):
			continue
		var unit_type: String = str(unit.get("unit_type")) if unit.get("unit_type") != null else ""
		if unit_type != "cavalry":
			continue
		var hc: Node = unit.get_node_or_null("HealthComponent")
		if hc == null:
			continue
		if hc.has_method("set_tech_hp_multiplier"):
			hc.set_tech_hp_multiplier(cav_hp_mult)


func _apply_building_hp_to_existing(player_id: int, effect_type: String) -> void:
	var hp_mult: float = _get_cumulative_modifier(player_id, effect_type)
	if absf(hp_mult - 1.0) < 0.001:
		return
	var buildings: Array[Node] = _get_tree().get_nodes_in_group("buildings")
	for bld: Node in buildings:
		if not _building_belongs_to_player(bld, player_id):
			continue
		var bld_type: String = str(bld.get("building_type")) if bld.get("building_type") != null else ""
		match effect_type:
			"wall_hp":
				if not bld_type.containsn("wall"):
					continue
			"tower_hp":
				if not bld_type.containsn("tower"):
					continue
		var hc: Node = bld.get_node_or_null("HealthComponent")
		if hc == null:
			continue
		if hc.has_method("set_tech_hp_multiplier"):
			hc.set_tech_hp_multiplier(hp_mult)


func _apply_speed_to_existing_units(player_id: int, unit_category: String) -> void:
	var speed_mult: float = 1.0
	match unit_category:
		"cavalry":
			speed_mult = _player_cavalry_speed_multiplier.get(player_id, 1.0)
		"villager":
			speed_mult = _player_villager_speed_multiplier.get(player_id, 1.0)
	if absf(speed_mult - 1.0) < 0.001:
		return
	var units: Array[Node] = _get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if not _unit_belongs_to_player(unit, player_id):
			continue
		var unit_type: String = str(unit.get("unit_type")) if unit.get("unit_type") != null else ""
		if unit_category == "cavalry" and not unit_type.containsn("cav"):
			continue
		if unit_category == "villager" and unit_type != "villager":
			continue
		var move_comp: Node = unit.get_node_or_null("MovementComponent")
		if move_comp != null and move_comp.get("max_speed") != null:
			var base_speed: float = move_comp.max_speed
			move_comp.max_speed = base_speed * speed_mult


func _apply_carry_capacity_to_existing(player_id: int) -> void:
	var carry_mult: float = _player_carry_capacity_multiplier.get(player_id, 1.0)
	if absf(carry_mult - 1.0) < 0.001:
		return
	var units: Array[Node] = _get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if not _unit_belongs_to_player(unit, player_id):
			continue
		var unit_type: String = str(unit.get("unit_type")) if unit.get("unit_type") != null else ""
		if unit_type != "villager":
			continue
		var harvest: Node = unit.get_node_or_null("HarvestComponent")
		if harvest != null and harvest.get("carry_capacity") != null:
			var base_cap: int = harvest.carry_capacity
			harvest.carry_capacity = int(float(base_cap) * carry_mult)

# =============================================================================
# Query API (for new units / buildings at spawn time)
# =============================================================================

func get_attack_modifier(player_id: int, is_ranged: bool = false) -> float:
	if is_ranged:
		return _player_ranged_attack_multiplier.get(player_id, 1.0)
	return _player_attack_multiplier.get(player_id, 1.0)


func get_range_bonus(player_id: int) -> float:
	return _player_range_bonus.get(player_id, 0.0)


func get_armor_bonus(player_id: int) -> int:
	return _player_armor_bonus.get(player_id, 0)


func get_build_speed_modifier(player_id: int) -> float:
	return _player_build_speed.get(player_id, 1.0)


func get_train_speed_modifier(player_id: int) -> float:
	return _player_train_speed.get(player_id, 1.0)


func get_villager_speed_modifier(player_id: int) -> float:
	return _player_villager_speed_multiplier.get(player_id, 1.0)


func get_carry_capacity_modifier(player_id: int) -> float:
	return _player_carry_capacity_multiplier.get(player_id, 1.0)


func get_cavalry_hp_modifier(player_id: int) -> float:
	return _player_cavalry_hp_multiplier.get(player_id, 1.0)


func get_cavalry_speed_modifier(player_id: int) -> float:
	return _player_cavalry_speed_multiplier.get(player_id, 1.0)


func get_total_modifier(player_id: int, effect_type: String) -> float:
	return _get_cumulative_modifier(player_id, effect_type)

## Flat-value effect types that should be stored additively, not multiplicatively.
const _FLAT_EFFECTS: Array = ["building_armor", "range", "siege_range"]

# =============================================================================
# Modifier Storage Helpers
# =============================================================================

func _store_modifier(player_id: int, effect_type: String, value: float) -> void:
	if effect_type in _FLAT_EFFECTS:
		if not _player_additive_bonuses.has(player_id):
			_player_additive_bonuses[player_id] = {}
		var current: float = _player_additive_bonuses[player_id].get(effect_type, 0.0)
		_player_additive_bonuses[player_id][effect_type] = current + value
	else:
		if not _player_modifiers.has(player_id):
			_player_modifiers[player_id] = {}
		var current: float = _player_modifiers[player_id].get(effect_type, 1.0)
		_player_modifiers[player_id][effect_type] = current * value


func _get_cumulative_modifier(player_id: int, effect_type: String) -> float:
	if not _player_modifiers.has(player_id):
		return 1.0
	return _player_modifiers[player_id].get(effect_type, 1.0)


func _get_additive_bonus(player_id: int, effect_type: String) -> float:
	if not _player_additive_bonuses.has(player_id):
		return 0.0
	return _player_additive_bonuses[player_id].get(effect_type, 0.0)


func _get_range_bonus(player_id: int) -> float:
	return _get_additive_bonus(player_id, "range") + _get_additive_bonus(player_id, "siege_range")


func _get_armor_bonus(player_id: int) -> int:
	return int(_get_additive_bonus(player_id, "building_armor"))

# =============================================================================
# Apply All (for save/load reapplication)
# =============================================================================

func reapply_all_effects(player_id: int) -> void:
	if _player_modifiers.has(player_id):
		var mods: Dictionary = _player_modifiers[player_id]
		for effect_type: String in mods:
			var value: float = mods[effect_type]
			_route_effect(effect_type, value, player_id)
	if _player_additive_bonuses.has(player_id):
		var bonuses: Dictionary = _player_additive_bonuses[player_id]
		for effect_type: String in bonuses:
			var value: float = bonuses[effect_type]
			_route_effect(effect_type, value, player_id)


func _route_effect(effect_type: String, value: float, player_id: int) -> void:
	match effect_type:
		"wood_gather_rate", "food_gather_rate", "farm_capacity", \
		"gold_gather_rate", "stone_gather_rate":
			EventBus.tech_effect_gather_rate.emit(effect_type, value, player_id)
		"melee_attack", "ranged_attack", "tower_attack", "siege_attack":
			EventBus.tech_effect_attack.emit(effect_type, value, player_id)
		"cavalry_armor", "cavalry_hp", "building_hp", "building_armor", \
		"wall_hp", "tower_hp", "range", "siege_range":
			EventBus.tech_effect_armor.emit(effect_type, value, player_id)
		"train_speed", "build_speed_modifier":
			EventBus.tech_effect_production.emit(effect_type, value, player_id)
		_:
			EventBus.tech_effect_other.emit(effect_type, value, player_id)

# =============================================================================
# Helpers
# =============================================================================

func _unit_belongs_to_player(unit: Node, player_id: int) -> bool:
	if unit.get("player_id") != null:
		return int(unit.get("player_id")) == player_id
	return false


func _building_belongs_to_player(bld: Node, player_id: int) -> bool:
	if bld.get("player_id") != null:
		return int(bld.get("player_id")) == player_id
	return false


func _find_node(target_name: String) -> Node:
	var direct: Node = get_node_or_null("/root/GameWorld/" + target_name)
	if direct != null:
		return direct
	direct = get_node_or_null("/root/GameWorld/World/" + target_name)
	if direct != null:
		return direct
	return null


func _find_node_in_scene(target_name: String) -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_recursive(scene, target_name)


func _find_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_recursive(child, target_name)
		if result != null:
			return result
	return null
