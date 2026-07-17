class_name AttackMoveState
extends UnitState

var target_position: Vector2 = Vector2.ZERO
var _combat_check_timer: float = 0.0
const COMBAT_CHECK_INTERVAL: float = 0.3
const DETECTION_RANGE: float = 160.0

func enter() -> void:
	_combat_check_timer = 0.0

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and target_position != Vector2.ZERO:
		move_comp.move_to(target_position)

func update(delta: float) -> void:
	if unit == null:
		state_machine.change_state("IdleState")
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp == null:
		state_machine.change_state("IdleState")
		return

	if not move_comp.is_moving:
		_check_arrival(move_comp)
		return

	_combat_check_timer += delta
	if _combat_check_timer >= COMBAT_CHECK_INTERVAL:
		_combat_check_timer = 0.0
		_check_for_enemies()


func exit() -> void:
	target_position = Vector2.ZERO


func set_target(pos: Vector2) -> void:
	target_position = pos


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


func _check_arrival(move_comp: Node) -> void:
	if target_position == Vector2.ZERO:
		state_machine.change_state("IdleState")
		return

	var dist: float = unit.global_position.distance_to(target_position)
	if dist < 8.0:
		move_comp.stop()
		state_machine.change_state("IdleState")
		return

	var current_index: int = move_comp.current_path_index
	var path_size: int = move_comp.path.size()
	if current_index >= path_size and not move_comp.is_moving:
		state_machine.change_state("IdleState")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")