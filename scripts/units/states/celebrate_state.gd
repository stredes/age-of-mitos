## Celebrate state: unit plays a victory animation for a fixed duration
## after killing an enemy, then returns to idle.
class_name CelebrateState
extends UnitState

var _timer: float = 0.0
const CELEBRATE_DURATION: float = 2.0


func enter() -> void:
	_timer = 0.0

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.is_moving:
		move_comp.stop()

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("celebrate")


func update(delta: float) -> void:
	_timer += delta
	if _timer >= CELEBRATE_DURATION:
		state_machine.change_state("IdleState")


func exit() -> void:
	_timer = 0.0


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
