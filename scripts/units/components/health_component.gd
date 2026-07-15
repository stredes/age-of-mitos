class_name HealthComponent
extends Node

signal health_changed(old_hp: int, new_hp: int, max_hp: int)
signal died(attacker_id: int)
signal healed(amount: int)

@export var max_hp: int = 100

var current_hp: int = 0
var is_alive: bool = true

var _parent_unit_id: int = -1
var _parent_building_id: int = -1
var _parent_player_id: int = -1
var _is_building: bool = false


func _ready() -> void:
	current_hp = max_hp
	is_alive = true
	call_deferred("_identify_parent")


func _identify_parent() -> void:
	var p: Node = get_parent()
	if p == null:
		return
	if p.has_method("get") and p.get("unit_id") != null:
		_parent_unit_id = p.unit_id
		_parent_player_id = p.get("player_id") if p.get("player_id") != null else -1
		_is_building = false
	elif p.has_method("get") and p.get("building_id") != null:
		_parent_building_id = p.building_id
		_parent_player_id = p.get("player_id") if p.get("player_id") != null else -1
		_is_building = true
	else:
		if p.has_method("get") and p.get("player_id") != null:
			_parent_player_id = p.player_id
		_is_building = "building" in str(p.name).to_lower()


func initialize(hp: int, owner_player_id: int = -1) -> void:
	max_hp = hp
	current_hp = max_hp
	is_alive = true
	if owner_player_id != -1:
		_parent_player_id = owner_player_id


func take_damage(amount: int, attacker_id: int = -1) -> void:
	if not is_alive or amount <= 0:
		return

	var old_hp: int = current_hp
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(old_hp, current_hp, max_hp)

	if _parent_unit_id != -1:
		EventBus.damage_dealt.emit(_parent_unit_id, attacker_id, amount, false)

	if current_hp <= 0:
		is_alive = false
		died.emit(attacker_id)
		if _is_building and _parent_building_id != -1:
			EventBus.building_damaged.emit(_parent_building_id, amount, attacker_id)
			EventBus.building_destroyed.emit(_parent_building_id, _parent_player_id, attacker_id)
		elif _parent_unit_id != -1:
			EventBus.unit_died.emit(_parent_unit_id, attacker_id, _parent_player_id)
	else:
		if _is_building and _parent_building_id != -1:
			EventBus.building_damaged.emit(_parent_building_id, amount, attacker_id)


func heal(amount: int) -> void:
	if not is_alive or amount <= 0:
		return

	var old_hp: int = current_hp
	current_hp = mini(current_hp + amount, max_hp)
	var actual_healed: int = current_hp - old_hp
	if actual_healed > 0:
		health_changed.emit(old_hp, current_hp, max_hp)
		healed.emit(actual_healed)


func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


func get_missing_hp() -> int:
	return maxi(max_hp - current_hp, 0)


func set_max_hp(new_max: int, heal_to_full: bool = true) -> void:
	max_hp = maxi(new_max, 1)
	if heal_to_full:
		current_hp = max_hp
	else:
		current_hp = mini(current_hp, max_hp)
	health_changed.emit(current_hp, current_hp, max_hp)
