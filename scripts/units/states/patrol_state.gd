class_name PatrolState
extends UnitState

var patrol_point_a: Vector2 = Vector2.ZERO
var patrol_point_b: Vector2 = Vector2.ZERO
var _current_target: Vector2 = Vector2.ZERO
var _going_to_a: bool = true
var _combat_check_timer: float = 0.0
const COMBAT_CHECK_INTERVAL: float = 0.5
const DETECTION_RANGE: float = 160.0

func enter() -> void:
	_combat_check_timer = 0.0
	_going_to_a = true
	_current_target = patrol_point_a

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and _current_target != Vector2.ZERO:
		move_comp.move_to(_current_target)


func update(delta: float) -> void:
	if unit == null:
		state_machine.change_state("IdleState")
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp == null:
		state_machine.change_state("IdleState")
		return

	if not move_comp.is_moving:
		_patrol_arrived(move_comp)
		return

	_combat_check_timer += delta
	if _combat_check_timer >= COMBAT_CHECK_INTERVAL:
		_combat_check_timer = 0.0
		_check_for_enemies()


func exit() -> void:
	patrol_point_a = Vector2.ZERO
	patrol_point_b = Vector2.ZERO
	_current_target = Vector2.ZERO
	_going_to_a = true


func set_patrol_points(point_a: Vector2, point_b: Vector2) -> void:
	patrol_point_a = point_a
	patrol_point_b = point_b


func _patrol_arrived(move_comp: Node) -> void:
	if _going_to_a:
		_going_to_a = false
		_current_target = patrol_point_b
	else:
		_going_to_a = true
		_current_target = patrol_point_a

	if _current_target != Vector2.ZERO:
		move_comp.move_to(_current_target)
	else:
		state_machine.change_state("IdleState")


func _check_for_enemies() -> void:
	if unit == null:
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		return

	var nearest_enemy: Node2D = combat.find_nearest_enemy(DETECTION_RANGE)
	if nearest_enemy != null:
		combat.set_target(nearest_enemy)
		state_machine.change_state("AttackState")
		return

	var combat_comp: Node = unit.get_node_or_null("CombatComponent")
	if combat_comp != null and combat_comp.has_method("acquire_target"):
		combat_comp.acquire_target(DETECTION_RANGE)


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")