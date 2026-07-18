## Hurt state: unit staggers when taking a heavy hit (>20% HP in one blow).
## Stops movement, plays pain animation, then resumes the previous state.
class_name HurtState
extends UnitState

var previous_state_name: String = "IdleState"

var _timer: float = 0.0
const HURT_DURATION: float = 0.5
const HEAVY_HIT_THRESHOLD: float = 0.2


func enter() -> void:
	_timer = 0.0

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.is_moving:
		move_comp.stop()

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("hurt")


func update(delta: float) -> void:
	_timer += delta
	if _timer >= HURT_DURATION:
		state_machine.change_state(previous_state_name)


func exit() -> void:
	_timer = 0.0


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
