class_name HoldPositionState
extends UnitState

var hold_position: Vector2 = Vector2.ZERO
var _returning: bool = false
const RETURN_THRESHOLD: float = 120.0
const COMBAT_CHECK_INTERVAL: float = 0.25
const DETECTION_RANGE: float = 180.0
var _combat_check_timer: float = 0.0

func enter() -> void:
	_combat_check_timer = 0.0
	_returning = false

	if hold_position == Vector2.ZERO and unit != null:
		hold_position = unit.global_position

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("idle")

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_method("stop"):
		move_comp.stop()

func update(delta: float) -> void:
	if unit == null:
		state_machine.change_state("IdleState")
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		_return_to_position()
		return

	var nearest_enemy: Node2D = combat.find_nearest_enemy(DETECTION_RANGE)
	if nearest_enemy != null:
		combat.set_target(nearest_enemy)
		state_machine.change_state("AttackState")
		return

	var combat_comp: Node = unit.get_node_or_null("CombatComponent")
	if combat_comp != null and combat_comp.has_method("acquire_target"):
		var target: Node2D = combat_comp.acquire_target(DETECTION_RANGE)
		if target != null:
			state_machine.change_state("AttackState")
			return

	_return_to_position()


func exit() -> void:
	hold_position = Vector2.ZERO
	_returning = false


func set_hold_position(pos: Vector2) -> void:
	hold_position = pos


func _return_to_position() -> void:
	if hold_position == Vector2.ZERO:
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp == null:
		return

	if move_comp.is_moving:
		var dist: float = unit.global_position.distance_to(hold_position)
		if dist < 8.0:
			move_comp.stop()
			_returning = false
		return

	var dist: float = unit.global_position.distance_to(hold_position)
	if dist > RETURN_THRESHOLD:
		_returning = true
		move_comp.move_to(hold_position)

		var anim: Node = _get_anim_controller()
		if anim != null and anim.has_method("play_state"):
			anim.play_state("walk")
	else:
		_returning = false


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")