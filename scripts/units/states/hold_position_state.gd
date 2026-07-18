## Hold Position state: unit stays in place and defends itself against nearby
## enemies. Unlike AttackMove, the unit NEVER chases. It attacks only enemies
## within its attack range, and retaliates when damaged.
class_name HoldPositionState
extends UnitState

var _scan_timer: float = 0.0
var _target_node: Node2D = null

const SCAN_INTERVAL: float = 0.35
const ATTACK_RANGE_SCAN: float = 120.0


func enter() -> void:
	_scan_timer = 0.0
	_target_node = null

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.is_moving:
		move_comp.stop()

	_play_anim("idle")

	if unit.damaged.is_connected(_on_damaged):
		unit.damaged.disconnect(_on_damaged)
	unit.damaged.connect(_on_damaged)


func update(delta: float) -> void:
	if _target_node != null and is_instance_valid(_target_node):
		var health: Node = _target_node.get_node_or_null("HealthComponent")
		if health != null and not health.is_alive:
			_target_node = null
			_play_anim("idle")
			return

		var combat: Node = unit.get_node_or_null("CombatComponent")
		if combat == null:
			_target_node = null
			return

		var dist: float = unit.global_position.distance_to(_target_node.global_position)
		if combat.is_in_attack_range(_target_node.global_position):
			var move_comp: Node = unit.get_node_or_null("MovementComponent")
			if move_comp != null and move_comp.is_moving:
				move_comp.stop()
			if combat.can_attack():
				_play_attack_anim()
				combat.attack(_target_node)
		elif dist > ATTACK_RANGE_SCAN:
			combat.clear_target()
			_target_node = null
			_play_anim("idle")
	else:
		_scan_timer += delta
		if _scan_timer >= SCAN_INTERVAL:
			_scan_timer = 0.0
			_scan_for_enemy()


func exit() -> void:
	if unit.damaged.is_connected(_on_damaged):
		unit.damaged.disconnect(_on_damaged)

	_target_node = null
	_scan_timer = 0.0


func _on_damaged(_amount: int, attacker_id: int) -> void:
	if _target_node != null and is_instance_valid(_target_node):
		return

	var attacker: Node2D = _find_unit_by_id(attacker_id)
	if attacker == null:
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		return

	var dist: float = unit.global_position.distance_to(attacker.global_position)
	if combat.is_in_attack_range(attacker.global_position):
		_target_node = attacker
		combat.set_target(attacker)
		if combat.can_attack():
			_play_attack_anim()
			combat.attack(attacker)


func _scan_for_enemy() -> void:
	if unit == null:
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		return

	var nearest_enemy: Node2D = combat.find_nearest_enemy(ATTACK_RANGE_SCAN)
	if nearest_enemy != null:
		var dist: float = unit.global_position.distance_to(nearest_enemy.global_position)
		if combat.is_in_attack_range(nearest_enemy.global_position):
			_target_node = nearest_enemy
			combat.set_target(nearest_enemy)
			if combat.can_attack():
				_play_attack_anim()
				combat.attack(nearest_enemy)


func _play_attack_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state") and _target_node != null:
		var dir: Vector2 = (_target_node.global_position - unit.global_position).normalized()
		anim.play_state("attack", dir)


func _play_anim(anim_name: String) -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state(anim_name)


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")


func _find_unit_by_id(unit_id: int) -> Node2D:
	var units: Array[Node] = unit.get_tree().get_nodes_in_group("units")
	for u: Node in units:
		if u is Node2D and u.has_method("get") and u.get("unit_id") != null:
			if int(u.get("unit_id")) == unit_id:
				return u as Node2D
	return null
