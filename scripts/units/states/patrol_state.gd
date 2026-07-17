## Patrol state: walk between two waypoints, scanning for enemies.
## Engages any enemy found along the route, then resumes patrolling.
class_name PatrolState
extends UnitState

var patrol_a: Vector2 = Vector2.ZERO
var patrol_b: Vector2 = Vector2.ZERO

var _current_target: Vector2 = Vector2.ZERO
var _going_to_b: bool = true
var _scan_timer: float = 0.0
var _returning_from_combat: bool = false

const SCAN_INTERVAL: float = 0.3
const SCAN_RANGE: float = 200.0
const ARRIVAL_TOLERANCE: float = 16.0


func enter() -> void:
	_scan_timer = 0.0
	_returning_from_combat = false

	if unit == null:
		state_machine.change_state("IdleState")
		return

	# Read waypoints from unit properties or use sensible defaults.
	var pa: Variant = unit.get("patrol_point_a")
	var pb: Variant = unit.get("patrol_point_b")
	if pa is Vector2 and pa != Vector2.ZERO:
		patrol_a = pa
	else:
		patrol_a = unit.global_position + Vector2(-120, 0)
	if pb is Vector2 and pb != Vector2.ZERO:
		patrol_b = pb
	else:
		patrol_b = unit.global_position + Vector2(120, 0)

	# Decide which direction to start.
	if _returning_from_combat:
		_current_target = patrol_a if _going_to_b else patrol_b
	else:
		_current_target = patrol_b
		_going_to_b = true

	_move_to(_current_target)
	_play_walk_anim()


func update(delta: float) -> void:
	if unit == null:
		state_machine.change_state("IdleState")
		return

	# Periodic enemy scan.
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		var enemy: Node2D = _scan_for_enemy()
		if enemy != null:
			_engage(enemy)
			return

	# Check arrival at current waypoint.
	var dist: float = unit.global_position.distance_to(_current_target)
	if dist < ARRIVAL_TOLERANCE:
		_reached_waypoint()
		return

	# If movement stopped unexpectedly, try next waypoint.
	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and not move_comp.is_moving:
		_reached_waypoint()


func exit() -> void:
	_scan_timer = 0.0
	_returning_from_combat = false


func set_patrol_points(a: Vector2, b: Vector2) -> void:
	patrol_a = a
	patrol_b = b


func _reached_waypoint() -> void:
	if _going_to_b:
		# Arrived at B, now go back to A.
		_going_to_b = false
		_current_target = patrol_a
	else:
		# Arrived at A, now go to B.
		_going_to_b = true
		_current_target = patrol_b

	_move_to(_current_target)
	_play_walk_anim()


func _scan_for_enemy() -> Node2D:
	if unit == null:
		return null

	var player_id: int = unit.get("player_id") if unit.get("player_id") != null else -1
	if player_id == -1:
		return null

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat != null and combat.has_method("find_nearest_enemy"):
		return combat.find_nearest_enemy(SCAN_RANGE)

	return null


func _engage(enemy: Node2D) -> void:
	if unit == null or enemy == null:
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_method("stop"):
		move_comp.stop()

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat != null and combat.has_method("set_target"):
		combat.set_target(enemy)

	var sm: UnitStateMachine = unit.get_node_or_null("UnitStateMachine") as UnitStateMachine
	if sm != null:
		var atk_state: Node = sm.states.get("AttackState")
		if atk_state != null and atk_state is AttackState:
			atk_state.set_target(enemy)
		sm.change_state("AttackState")


func _move_to(pos: Vector2) -> void:
	if unit == null:
		return
	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_method("move_to"):
		move_comp.move_to(pos)


func _play_walk_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
