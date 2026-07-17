## Ability system for unit special skills and cooldowns.
##
## Manages active abilities per unit type: activation, cooldowns, mana costs,
## targeting modes, and effect application. Integrates with CombatManager
## and DamageCalculator for ability effects.
class_name AbilitySystem
extends Node

# =============================================================================
# Signals
# =============================================================================

signal ability_activated(unit_id: int, ability_id: String)
signal ability_completed(unit_id: int, ability_id: String)
signal ability_failed(unit_id: int, ability_id: String, reason: String)
signal cooldown_started(unit_id: int, ability_id: String, duration: float)
signal cooldown_ended(unit_id: int, ability_id: String)

# =============================================================================
# Enums
# =============================================================================

enum TargetMode {
	SELF,           ## Affects only the caster.
	ALLIED_SINGLE,  ## Targets one allied unit.
	ENEMY_SINGLE,   ## Targets one enemy unit.
	ENEMY_AOE,      ## Targets area around an enemy.
	ALLIED_AOE,     ## Targets area around an allied unit.
	GROUND,         ## Targets a ground position.
}

enum AbilityType {
	INSTANT,        ## Immediate effect.
	DURATION,       ## Effect lasts for a duration.
	PASSIVE,        ## Always active (no activation needed).
}

# =============================================================================
# Configuration
# =============================================================================

## Ability data loaded from abilities.json.
var _ability_data: Dictionary = {}

## Active cooldowns: { unit_id: { ability_id: time_remaining } }
var _cooldowns: Dictionary = {}

## Active duration effects: { unit_id: { ability_id: { timer, effect_data } } }
var _active_effects: Dictionary = {}

## Mana pool per unit: { unit_id: current_mana }
var _mana_pool: Dictionary = {}

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_load_ability_data()
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)
	if not EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.connect(_on_unit_died)


func _process(delta: float) -> void:
	if GameManager.is_paused() or GameManager.is_game_over():
		return

	_update_cooldowns(delta)
	_update_duration_effects(delta)

# =============================================================================
# Initialization
# =============================================================================

func _on_game_started(_player_id: int) -> void:
	_cooldowns.clear()
	_active_effects.clear()
	_mana_pool.clear()
	_load_ability_data()


func _load_ability_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/abilities.json", FileAccess.READ)
	if file == null:
		push_warning("AbilitySystem: Could not load abilities.json")
		return
	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		push_warning("AbilitySystem: Failed to parse abilities.json")
		return
	_ability_data = json.data

# =============================================================================
# Ability Registration
# =============================================================================

## Register a unit's abilities and mana pool. Called when unit is spawned.
func register_unit(unit_id: int, unit_type: String) -> void:
	var unit_abilities: Array = _get_abilities_for_type(unit_type)
	if unit_abilities.is_empty():
		return

	_cooldowns[unit_id] = {}
	_mana_pool[unit_id] = _get_max_mana(unit_type)

	for ability_id: String in unit_abilities:
		_cooldowns[unit_id][ability_id] = 0.0


## Unregister a unit. Called on death.
func unregister_unit(unit_id: int) -> void:
	_cooldowns.erase(unit_id)
	_active_effects.erase(unit_id)
	_mana_pool.erase(unit_id)

# =============================================================================
# Ability Activation
# =============================================================================

## Try to activate an ability. Returns true if successful.
func activate_ability(unit_id: int, ability_id: String, target_pos: Vector2 = Vector2.ZERO, target_unit: int = -1) -> bool:
	var ability: Dictionary = _get_ability(ability_id)
	if ability.is_empty():
		ability_failed.emit(unit_id, ability_id, "Unknown ability")
		return false

	# Check cooldown.
	if _is_on_cooldown(unit_id, ability_id):
		ability_failed.emit(unit_id, ability_id, "On cooldown")
		return false

	# Check mana cost.
	var mana_cost: int = ability.get("mana_cost", 0)
	if mana_cost > 0:
		var current_mana: int = _mana_pool.get(unit_id, 0)
		if current_mana < mana_cost:
			ability_failed.emit(unit_id, ability_id, "Not enough mana")
			return false

	# Check target validity.
	var target_mode: int = ability.get("target_mode", TargetMode.SELF)
	if not _validate_target(target_mode, unit_id, target_pos, target_unit):
		ability_failed.emit(unit_id, ability_id, "Invalid target")
		return false

	# Consume mana.
	if mana_cost > 0:
		_mana_pool[unit_id] -= mana_cost

	# Start cooldown.
	var cooldown: float = ability.get("cooldown", 0.0)
	if cooldown > 0.0:
		_cooldowns[unit_id][ability_id] = cooldown
		cooldown_started.emit(unit_id, ability_id, cooldown)

	# Apply effect.
	var ability_type: int = ability.get("ability_type", AbilityType.INSTANT)
	match ability_type:
		AbilityType.INSTANT:
			_apply_instant_effect(unit_id, ability_id, ability, target_pos, target_unit)
			ability_activated.emit(unit_id, ability_id)
			ability_completed.emit(unit_id, ability_id)
		AbilityType.DURATION:
			_apply_duration_effect(unit_id, ability_id, ability, target_pos, target_unit)
			ability_activated.emit(unit_id, ability_id)
		AbilityType.PASSIVE:
			ability_activated.emit(unit_id, ability_id)

	return true

# =============================================================================
# Effect Application
# =============================================================================

func _apply_instant_effect(unit_id: int, ability_id: String, ability: Dictionary, target_pos: Vector2, target_unit: int) -> void:
	var effect_type: String = ability.get("effect_type", "")

	match effect_type:
		"damage":
			_apply_damage_effect(unit_id, ability, target_pos, target_unit)
		"heal":
			_apply_heal_effect(unit_id, ability, target_unit)
		"buff":
			_apply_buff_effect(unit_id, ability, target_unit)
		"debuff":
			_apply_debuff_effect(unit_id, ability, target_unit)
		"summon":
			_apply_summon_effect(unit_id, ability, target_pos)
		"dash":
			_apply_dash_effect(unit_id, ability, target_pos)
		"aoe_damage":
			_apply_aoe_damage_effect(unit_id, ability, target_pos)


func _apply_duration_effect(unit_id: int, ability_id: String, ability: Dictionary, target_pos: Vector2, target_unit: int) -> void:
	var duration: float = ability.get("duration", 5.0)
	_active_effects[unit_id] = _active_effects.get(unit_id, {})
	_active_effects[unit_id][ability_id] = {
		"timer": duration,
		"effect_data": ability,
		"target_pos": target_pos,
		"target_unit": target_unit,
	}
	# Apply initial effect.
	_apply_instant_effect(unit_id, ability_id, ability, target_pos, target_unit)


func _apply_damage_effect(unit_id: int, ability: Dictionary, _target_pos: Vector2, target_unit: int) -> void:
	var damage: int = ability.get("damage", 0)
	var range: float = ability.get("range", 0.0)

	if target_unit != -1:
		var unit_node: Node = _find_unit_node(target_unit)
		if unit_node != null and unit_node.has_method("take_damage"):
			unit_node.take_damage(damage, unit_id)
			return

	# AOE damage at position if no single target.
	if range > 0.0:
		_damage_units_in_range(unit_id, ability.get("target_pos", Vector2.ZERO), range, damage)


func _apply_heal_effect(unit_id: int, ability: Dictionary, target_unit: int) -> void:
	var heal_amount: int = ability.get("heal_amount", 0)
	var target_id: int = target_unit if target_unit != -1 else unit_id
	var unit_node: Node = _find_unit_node(target_id)
	if unit_node != null:
		var health_comp: Node = unit_node.get_node_or_null("HealthComponent")
		if health_comp != null and health_comp.has_method("heal"):
			health_comp.heal(heal_amount)


func _apply_buff_effect(unit_id: int, ability: Dictionary, target_unit: int) -> void:
	var buff_type: String = ability.get("buff_type", "")
	var buff_value: float = ability.get("buff_value", 1.0)
	var duration: float = ability.get("duration", 5.0)
	var target_id: int = target_unit if target_unit != -1 else unit_id
	var unit_node: Node = _find_unit_node(target_id)
	if unit_node == null:
		return

	match buff_type:
		"speed":
			var move_comp: Node = unit_node.get_node_or_null("MovementComponent")
			if move_comp != null:
				var current_speed: float = move_comp.get("base_speed")
				move_comp.set("base_speed", current_speed * buff_value)
				# Auto-remove after duration.
				get_tree().create_timer(duration).timeout.connect(
					func(): move_comp.set("base_speed", current_speed)
				)
		"attack":
			var combat_comp: Node = unit_node.get_node_or_null("CombatComponent")
			if combat_comp != null:
				var current_atk: int = combat_comp.get("attack_damage")
				combat_comp.set("attack_damage", int(float(current_atk) * buff_value))
				get_tree().create_timer(duration).timeout.connect(
					func(): combat_comp.set("attack_damage", current_atk)
				)
		"armor":
			var health_comp: Node = unit_node.get_node_or_null("HealthComponent")
			if health_comp != null:
				var current_armor: int = health_comp.get("armor", 0)
				health_comp.set("armor", current_armor + int(buff_value))
				get_tree().create_timer(duration).timeout.connect(
					func(): health_comp.set("armor", current_armor)
				)


func _apply_debuff_effect(unit_id: int, ability: Dictionary, target_unit: int) -> void:
	var debuff_type: String = ability.get("debuff_type", "")
	var debuff_value: float = ability.get("debuff_value", 1.0)
	var duration: float = ability.get("duration", 3.0)
	var unit_node: Node = _find_unit_node(target_unit)
	if unit_node == null:
		return

	match debuff_type:
		"slow":
			var move_comp: Node = unit_node.get_node_or_null("MovementComponent")
			if move_comp != null:
				var current_speed: float = move_comp.get("base_speed")
				move_comp.set("base_speed", current_speed * debuff_value)
				get_tree().create_timer(duration).timeout.connect(
					func(): move_comp.set("base_speed", current_speed)
				)
		"dot":
			# Damage over time: apply damage every second for duration.
			var damage_per_tick: int = ability.get("damage", 5)
			var ticks: int = int(duration)
			for i in range(ticks):
				get_tree().create_timer(float(i + 1)).timeout.connect(
					func():
						if is_instance_valid(unit_node) and unit_node.has_method("take_damage"):
							unit_node.take_damage(damage_per_tick, unit_id)
				)


func _apply_summon_effect(unit_id: int, ability: Dictionary, target_pos: Vector2) -> void:
	var summon_type: String = ability.get("summon_type", "swordsman")
	var count: int = ability.get("summon_count", 1)
	var summoner: Node = _find_unit_node(unit_id)
	if summoner == null:
		return
	var player_id: int = summoner.get("player_id") if summoner.get("player_id") != null else -1
	if player_id == -1:
		return

	for _i in range(count):
		var offset: Vector2 = Vector2(randf_range(-32.0, 32.0), randf_range(-32.0, 32.0))
		var spawn_pos: Vector2 = target_pos + offset
		EventBus.unit_spawned.emit(randi(), summon_type, player_id, spawn_pos)


func _apply_dash_effect(unit_id: int, ability: Dictionary, target_pos: Vector2) -> void:
	var unit_node: Node = _find_unit_node(unit_id)
	if unit_node == null or not (unit_node is Node2D):
		return
	var dash_range: float = ability.get("dash_range", 200.0)
	var direction: Vector2 = (target_pos - (unit_node as Node2D).global_position).normalized()
	var dash_target: Vector2 = (unit_node as Node2D).global_position + direction * dash_range
	(unit_node as Node2D).global_position = dash_target


func _apply_aoe_damage_effect(unit_id: int, ability: Dictionary, target_pos: Vector2) -> void:
	var damage: int = ability.get("damage", 0)
	var radius: float = ability.get("radius", 100.0)
	_damage_units_in_range(unit_id, target_pos, radius, damage)

# =============================================================================
# Cooldown & Duration Management
# =============================================================================

func _update_cooldowns(delta: float) -> void:
	for unit_id: int in _cooldowns.keys():
		var unit_cooldowns: Dictionary = _cooldowns[unit_id]
		for ability_id: String in unit_cooldowns.keys():
			if unit_cooldowns[ability_id] > 0.0:
				unit_cooldowns[ability_id] -= delta
				if unit_cooldowns[ability_id] <= 0.0:
					unit_cooldowns[ability_id] = 0.0
					cooldown_ended.emit(unit_id, ability_id)


func _update_duration_effects(delta: float) -> void:
	for unit_id: int in _active_effects.keys():
		var effects: Dictionary = _active_effects[unit_id]
		for ability_id: String in effects.keys():
			var effect: Dictionary = effects[ability_id]
			effect["timer"] -= delta
			# Apply periodic effect (e.g., DOT, regeneration).
			var ability: Dictionary = _get_ability(ability_id)
			var tick_rate: float = ability.get("tick_rate", 1.0)
			if fmod(effect["timer"], tick_rate) > fmod(effect["timer"] + delta, tick_rate):
				_apply_periodic_tick(unit_id, ability_id, ability, effect)
			if effect["timer"] <= 0.0:
				effects.erase(ability_id)
				ability_completed.emit(unit_id, ability_id)


func _apply_periodic_tick(unit_id: int, _ability_id: String, ability: Dictionary, effect: Dictionary) -> void:
	var effect_type: String = ability.get("effect_type", "")
	match effect_type:
		"dot":
			var damage: int = ability.get("damage", 5)
			var target_unit: int = effect.get("target_unit", -1)
			if target_unit != -1:
				var node: Node = _find_unit_node(target_unit)
				if node != null and node.has_method("take_damage"):
					node.take_damage(damage, unit_id)
		"regen":
			var heal: int = ability.get("heal_amount", 5)
			var node: Node = _find_unit_node(unit_id)
			if node != null:
				var health_comp: Node = node.get_node_or_null("HealthComponent")
				if health_comp != null and health_comp.has_method("heal"):
					health_comp.heal(heal)

# =============================================================================
# Queries
# =============================================================================

func is_on_cooldown(unit_id: int, ability_id: String) -> bool:
	return _is_on_cooldown(unit_id, ability_id)


func get_cooldown_remaining(unit_id: int, ability_id: String) -> float:
	if not _cooldowns.has(unit_id):
		return 0.0
	return _cooldowns[unit_id].get(ability_id, 0.0)


func get_cooldown_percent(unit_id: int, ability_id: String) -> float:
	var ability: Dictionary = _get_ability(ability_id)
	var max_cooldown: float = ability.get("cooldown", 1.0)
	if max_cooldown <= 0.0:
		return 0.0
	var remaining: float = get_cooldown_remaining(unit_id, ability_id)
	return clampf(remaining / max_cooldown, 0.0, 1.0)


func get_mana(unit_id: int) -> int:
	return _mana_pool.get(unit_id, 0)


func get_max_mana(unit_id: int) -> int:
	# Find unit type from node.
	var node: Node = _find_unit_node(unit_id)
	if node != null:
		var unit_type: String = node.get("unit_type") if node.get("unit_type") != null else ""
		return _get_max_mana(unit_type)
	return 0


func get_mana_percent(unit_id: int) -> float:
	var max_mana: int = get_max_mana(unit_id)
	if max_mana <= 0:
		return 1.0
	return clampf(float(_mana_pool.get(unit_id, 0)) / float(max_mana), 0.0, 1.0)


func get_available_abilities(unit_id: int, unit_type: String) -> Array:
	var result: Array = []
	var abilities: Array = _get_abilities_for_type(unit_type)
	for ability_id: String in abilities:
		var ability: Dictionary = _get_ability(ability_id)
		if ability.get("ability_type", AbilityType.PASSIVE) == AbilityType.PASSIVE:
			continue
		result.append({
			"id": ability_id,
			"name": ability.get("display_name", ability_id),
			"on_cooldown": _is_on_cooldown(unit_id, ability_id),
			"cooldown_remaining": get_cooldown_remaining(unit_id, ability_id),
			"mana_cost": ability.get("mana_cost", 0),
			"has_enough_mana": _mana_pool.get(unit_id, 0) >= ability.get("mana_cost", 0),
		})
	return result


func get_active_effect_count(unit_id: int) -> int:
	return _active_effects.get(unit_id, {}).size()

# =============================================================================
# Validation
# =============================================================================

func _validate_target(target_mode: int, caster_id: int, target_pos: Vector2, target_unit: int) -> bool:
	match target_mode:
		TargetMode.SELF:
			return true
		TargetMode.ALLIED_SINGLE:
			return target_unit != -1 and _is_allied(caster_id, target_unit)
		TargetMode.ENEMY_SINGLE:
			return target_unit != -1 and not _is_allied(caster_id, target_unit)
		TargetMode.ENEMY_AOE:
			return target_pos != Vector2.ZERO
		TargetMode.ALLIED_AOE:
			return target_pos != Vector2.ZERO
		TargetMode.GROUND:
			return target_pos != Vector2.ZERO
	return true

# =============================================================================
# Internal Helpers
# =============================================================================

func _get_ability(ability_id: String) -> Dictionary:
	return _ability_data.get(ability_id, {})


func _get_abilities_for_type(unit_type: String) -> Array:
	var result: Array = []
	for ability_id: String in _ability_data:
		var ability: Dictionary = _ability_data[ability_id]
		var applies_to: Array = ability.get("applies_to", [])
		if unit_type in applies_to:
			result.append(ability_id)
	return result


func _get_max_mana(unit_type: String) -> int:
	for ability_id: String in _ability_data:
		var ability: Dictionary = _ability_data[ability_id]
		var applies_to: Array = ability.get("applies_to", [])
		if unit_type in applies_to:
			return ability.get("max_mana", 100)
	return 100


func _is_on_cooldown(unit_id: int, ability_id: String) -> bool:
	if not _cooldowns.has(unit_id):
		return false
	return _cooldowns[unit_id].get(ability_id, 0.0) > 0.0


func _is_allied(unit_a: int, unit_b: int) -> bool:
	var node_a: Node = _find_unit_node(unit_a)
	var node_b: Node = _find_unit_node(unit_b)
	if node_a == null or node_b == null:
		return false
	var pid_a: int = node_a.get("player_id") if node_a.get("player_id") != null else -1
	var pid_b: int = node_b.get("player_id") if node_b.get("player_id") != null else -1
	return pid_a == pid_b


func _find_unit_node(unit_id: int) -> Node:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if unit.get("unit_id") != null and int(unit.get("unit_id")) == unit_id:
			return unit
	return null


func _damage_units_in_range(attacker_id: int, center: Vector2, radius: float, damage: int) -> void:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	var attacker_node: Node = _find_unit_node(attacker_id)
	var attacker_pid: int = -1
	if attacker_node != null:
		attacker_pid = attacker_node.get("player_id") if attacker_node.get("player_id") != null else -1

	for unit: Node in units:
		if not (unit is Node2D):
			continue
		var dist: float = (unit as Node2D).global_position.distance_to(center)
		if dist > radius:
			continue
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid == attacker_pid:
			continue
		if unit.has_method("take_damage"):
			unit.take_damage(damage, attacker_id)

# =============================================================================
# Cleanup
# =============================================================================

func _on_unit_died(unit_id: int, _player_id: int) -> void:
	unregister_unit(unit_id)
