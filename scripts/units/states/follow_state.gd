class_name FollowState
extends UnitState

var target_node: Node2D = null

const FOLLOW_DISTANCE: float = 32.0
const RECALC_INTERVAL: float = 0.5

var _recalc_timer: float = 0.0


func enter() -> void:
	_recalc_timer = 0.0

	if unit == null:
		state_machine.change_state("IdleState")
		return

	if target_node == null or not is_instance_valid(target_node):
		state_machine.change_state("IdleState")
		return

	_move_to_target()


func update(_delta: float) -> void:
	if unit == null or target_node == null or not is_instance_valid(target_node):
		state_machine.change_state("IdleState")
		return

	var dist: float = unit.global_position.distance_to(target_node.global_position)

	if dist <= FOLLOW_DISTANCE:
		var move_comp: MovementComponent = unit.get_node_or_null("MovementComponent") as MovementComponent
		if move_comp != null and move_comp.is_moving:
			move_comp.stop()
		return

	_recalc_timer += _delta
	if _recalc_timer >= RECALC_INTERVAL:
		_recalc_timer = 0.0
		_move_to_target()


func exit() -> void:
	target_node = null
	_recalc_timer = 0.0


func set_target(node: Node2D) -> void:
	target_node = node


func _move_to_target() -> void:
	if target_node == null or unit == null:
		return

	var move_comp: MovementComponent = unit.get_node_or_null("MovementComponent") as MovementComponent
	if move_comp != null:
		move_comp.move_to(target_node.global_position)

	var anim: Node = unit.get_node_or_null("UnitAnimationController")
	if anim != null and anim.has_method("play_state"):
		var dir: Vector2 = (target_node.global_position - unit.global_position).normalized()
		anim.play_state("walk", dir)
