class_name MoveState
extends UnitState

var target_pos: Vector2 = Vector2.ZERO

var _combat_check_timer: float = 0.0
var _recalc_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

const COMBAT_CHECK_INTERVAL: float = 0.5
const RECALC_INTERVAL: float = 1.5
const STUCK_TIMEOUT: float = 2.0
const STUCK_DISTANCE_THRESHOLD: float = 4.0
const ARRIVAL_TOLERANCE: float = 6.0


func enter() -> void:
	_combat_check_timer = 0.0
	_recalc_timer = 0.0
	_stuck_timer = 0.0
	_last_pos = Vector2.ZERO

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
			_last_pos = unit.global_position
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

	# Periodic enemy check for military units.
	_combat_check_timer += delta
	if _combat_check_timer >= COMBAT_CHECK_INTERVAL:
		_combat_check_timer = 0.0
		_check_for_enemies()

	# Periodic path recalculation if path is blocked ahead.
	_recalc_timer += delta
	if _recalc_timer >= RECALC_INTERVAL:
		_recalc_timer = 0.0
		_check_path_blocked(move_comp)

	# Stuck detection: if the unit hasn't moved significantly, try to recalc.
	_stuck_timer += delta
	if _stuck_timer >= STUCK_TIMEOUT:
		var moved_dist: float = unit.global_position.distance_to(_last_pos)
		if moved_dist < STUCK_DISTANCE_THRESHOLD:
			_try_recalc_path(move_comp)
		_stuck_timer = 0.0
		_last_pos = unit.global_position

	_check_arrival(move_comp)


func exit() -> void:
	target_pos = Vector2.ZERO


func set_target(pos: Vector2) -> void:
	target_pos = pos


func _check_for_enemies() -> void:
	if unit == null:
		return

	# Only military units auto-engage.
	var unit_type: String = unit.get("unit_type") if unit.has_method("get") and unit.get("unit_type") != null else ""
	if unit_type == "villager":
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		return

	var nearest_enemy: Node2D = combat.find_nearest_enemy(150.0)
	if nearest_enemy != null:
		combat.set_target(nearest_enemy)
		state_machine.change_state("AttackState")


func _check_path_blocked(move_comp: Node) -> void:
	if move_comp.has_method("is_path_blocked_ahead") and move_comp.is_path_blocked_ahead():
		_try_recalc_path(move_comp)


func _try_recalc_path(move_comp: Node) -> void:
	if target_pos == Vector2.ZERO:
		return

	var dist_to_target: float = unit.global_position.distance_to(target_pos)
	if dist_to_target < ARRIVAL_TOLERANCE:
		# Close enough — just arrive.
		move_comp.stop()
		state_machine.change_state("IdleState")
		return

	# Try recalculation from current position.
	if move_comp.has_method("recalculate_path"):
		move_comp.recalculate_path()


func _check_arrival(move_comp: Node) -> void:
	if target_pos == Vector2.ZERO:
		return

	var dist: float = unit.global_position.distance_to(target_pos)
	if dist < ARRIVAL_TOLERANCE:
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
