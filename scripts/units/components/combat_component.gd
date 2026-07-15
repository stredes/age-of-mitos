class_name CombatComponent
extends Node

signal attack_started(target: Node2D)
signal attack_completed(target: Node2D, damage: int)
signal target_killed(target: Node2D)
signal need_move(target_pos: Vector2)

@export var attack_damage: int = 10
@export var attack_range: float = 48.0
@export var attack_speed: float = 1.0

var attack_cooldown: float = 0.0
var target: Node2D = null
var projectile_type: String = ""
var bonus_vs: Dictionary = {}

var _parent_unit: Node2D = null
var _is_ranged: bool = false


func _ready() -> void:
	call_deferred("_setup_parent")


func _setup_parent() -> void:
	_parent_unit = get_parent() as Node2D
	_is_ranged = attack_range > 48.0


func initialize(data: Dictionary) -> void:
	attack_damage = data.get("attack", 10)
	attack_range = data.get("range", 48.0)
	attack_speed = data.get("attack_speed", 1.0)
	projectile_type = data.get("projectile_type", "")
	bonus_vs = data.get("bonus_vs", {})
	_is_ranged = attack_range > 48.0


func _process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta


func is_in_attack_range(target_pos: Vector2) -> bool:
	if _parent_unit == null:
		return false
	return _parent_unit.global_position.distance_to(target_pos) <= attack_range


func can_attack() -> bool:
	return attack_cooldown <= 0.0 and target != null


func attack(target_node: Node2D) -> void:
	if target_node == null or not is_instance_valid(target_node):
		clear_target()
		return

	if not can_attack():
		return

	var dist: float = _parent_unit.global_position.distance_to(target_node.global_position)
	if dist > attack_range:
		need_move.emit(target_node.global_position)
		return

	attack_cooldown = attack_speed

	var actual_damage: int = _calculate_damage(target_node)

	attack_started.emit(target_node)

	if _is_ranged and not projectile_type.is_empty():
		_spawn_projectile(target_node, actual_damage)
	else:
		_apply_damage(target_node, actual_damage)

	attack_completed.emit(target_node, actual_damage)


func set_target(new_target: Node2D) -> void:
	target = new_target


func clear_target() -> void:
	target = null


func find_nearest_enemy(search_range: float) -> Node2D:
	if _parent_unit == null:
		return null

	var player_id: int = _parent_unit.get("player_id") if _parent_unit.get("player_id") != null else -1
	if player_id == -1:
		return null

	var unit_manager: Node = _find_unit_manager()
	if unit_manager == null:
		return null

	return unit_manager.get_nearest_enemy(_parent_unit.global_position, player_id)


func _calculate_damage(target_node: Node2D) -> int:
	var damage: int = attack_damage

	var target_type: String = ""
	if target_node.has_method("get") and target_node.get("unit_type") != null:
		target_type = target_node.unit_type

	if not target_type.is_empty() and bonus_vs.has(target_type):
		damage = int(float(damage) * bonus_vs[target_type])

	var armor: int = 0
	var health_comp: Node = target_node.get_node_or_null("HealthComponent")
	if health_comp != null and health_comp.get("armor") != null:
		armor = health_comp.armor
	elif target_node.has_method("get") and target_node.get("armor") != null:
		armor = target_node.armor

	damage = maxi(damage - armor, 1)

	return damage


func _apply_damage(target_node: Node2D, damage: int) -> void:
	var health_comp: Node = target_node.get_node_or_null("HealthComponent")
	var attacker_id: int = _parent_unit.unit_id if _parent_unit.has_method("get") and _parent_unit.get("unit_id") != null else -1

	if health_comp != null and health_comp.has_method("take_damage"):
		health_comp.take_damage(damage, attacker_id)
		if not health_comp.is_alive:
			target_killed.emit(target_node)
	elif target_node.has_method("take_damage"):
		target_node.take_damage(damage, attacker_id)

	EventBus.unit_attacked.emit(attacker_id, _get_target_id(target_node), damage)


func _spawn_projectile(target_node: Node2D, damage: int) -> void:
	if _parent_unit == null:
		return

	var attacker_id: int = _parent_unit.unit_id if _parent_unit.get("unit_id") != null else -1
	var target_id: int = _get_target_id(target_node)

	var projectile_id: int = randi()
	EventBus.projectile_fired.emit(projectile_id, attacker_id, target_id, _parent_unit.global_position, damage)

	_apply_damage(target_node, damage)


func _get_target_id(target_node: Node2D) -> int:
	if target_node.has_method("get") and target_node.get("unit_id") != null:
		return target_node.unit_id
	return -1


func _find_unit_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_node_by_method(scene, "get_nearest_enemy")


func _find_node_by_method(node: Node, method_name: String) -> Node:
	if node.has_method(method_name):
		return node
	for child: Node in node.get_children():
		if child.has_method(method_name):
			return child
	for child: Node in node.get_children():
		var result: Node = _find_node_by_method(child, method_name)
		if result != null:
			return result
	return null
