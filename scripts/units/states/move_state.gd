class_name MoveState
extends UnitState

var target_pos: Vector2 = Vector2.ZERO

var _combat_check_timer: float = 0.0
const COMBAT_CHECK_INTERVAL: float = 0.5
const PATH_BLOCKED_THRESHOLD: float = 0.5


func enter() -> void:
	_combat_check_timer = 0.0

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		if target_pos == Vector2.ZERO:
			target_pos = unit.pending_move_position
			unit.pending_move_position = Vector2.ZERO

		if target_pos != Vector2.ZERO:
			move_comp.move_to(target_pos)
			EventBus.unit_moved.emit(unit.unit_id, target_pos)
		else:
			state_machine.change_state("IdleState")


func update(delta: float) -> void:
	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp == null:
		state_machine.change_state("IdleState")
		return

	if not move_comp.is_moving:
		state_machine.change_state("IdleState")
		return

	_combat_check_timer += delta
	if _combat_check_timer >= COMBAT_CHECK_INTERVAL:
		_combat_check_timer = 0.0
		_check_for_enemies()

	_check_arrival(move_comp)


func exit() -> void:
	target_pos = Vector2.ZERO


func set_target(pos: Vector2) -> void:
	target_pos = pos


func _check_for_enemies() -> void:
	if unit == null:
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		return

	var nearest_enemy: Node2D = combat.find_nearest_enemy(150.0)
	if nearest_enemy != null:
		combat.set_target(nearest_enemy)
		state_machine.change_state("AttackState")


func _check_arrival(move_comp: Node) -> void:
	if target_pos == Vector2.ZERO:
		return

	var dist: float = unit.global_position.distance_to(target_pos)
	if dist < 4.0:
		move_comp.stop()
		state_machine.change_state("IdleState")
		return

	if not move_comp.is_moving:
		state_machine.change_state("IdleState")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
