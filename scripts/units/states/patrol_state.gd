## Patrol state: unit alternates between two waypoints in a loop (A→B→A→B…).
## Scans for enemies while moving. If an enemy is found, the unit chases and
## attacks it, then resumes patrolling from its current position.
## The patrol loop continues indefinitely until interrupted by another command.
class_name PatrolState
extends UnitState

var _point_a: Vector2 = Vector2.ZERO
var _point_b: Vector2 = Vector2.ZERO
var _current_target: Vector2 = Vector2.ZERO
var _heading_to_b: bool = true

var _is_combat: bool = false

var _scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.4
const SCAN_RANGE: float = 160.0
const ARRIVAL_THRESHOLD: float = 6.0


func enter() -> void:
	_scan_timer = 0.0

	if _point_a == Vector2.ZERO or _point_b == Vector2.ZERO:
		var pending: Dictionary = unit.get("pending_patrol_points") if unit.has_method("get") else {}
		if pending.is_empty():
			state_machine.change_state("IdleState")
			return
		_point_a = pending.get("a", Vector2.ZERO)
		_point_b = pending.get("b", Vector2.ZERO)
		unit.set("pending_patrol_points", {})

		if _point_a == Vector2.ZERO or _point_b == Vector2.ZERO:
			state_machine.change_state("IdleState")
			return

		_current_target = _point_b
		_heading_to_b = true
		_is_combat = false

	_move_to_target()


func update(delta: float) -> void:
	if _is_combat:
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp == null:
		state_machine.change_state("IdleState")
		return

	if not move_comp.is_moving:
		state_machine.change_state("IdleState")
		return

	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_for_enemies()

	_check_arrival(move_comp)


func exit() -> void:
	_point_a = Vector2.ZERO
	_point_b = Vector2.ZERO
	_current_target = Vector2.ZERO
	_heading_to_b = true
	_is_combat = false
	_scan_timer = 0.0

# =============================================================================
# Movement
# =============================================================================

func _move_to_target() -> void:
	if _current_target == Vector2.ZERO:
		state_machine.change_state("IdleState")
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(_current_target)
		EventBus.unit_moved.emit(unit.unit_id, _current_target)

	_play_anim("walk")


func _check_arrival(move_comp: Node) -> void:
	var dist: float = unit.global_position.distance_to(_current_target)
	if dist < ARRIVAL_THRESHOLD:
		move_comp.stop()
		_swap_target()
		_move_to_target()
		return

	if not move_comp.is_moving:
		_swap_target()
		_move_to_target()


func _swap_target() -> void:
	if _heading_to_b:
		_current_target = _point_a
		_heading_to_b = false
	else:
		_current_target = _point_b
		_heading_to_b = true

# =============================================================================
# Enemy Scanning
# =============================================================================

func _scan_for_enemies() -> void:
	if unit == null:
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		return

	var nearest_enemy: Node2D = combat.find_nearest_enemy(SCAN_RANGE)
	if nearest_enemy != null:
		_enter_combat(nearest_enemy)

# =============================================================================
# Combat
# =============================================================================

func _enter_combat(enemy: Node2D) -> void:
	_is_combat = true

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat != null:
		combat.set_target(enemy)

	_play_anim("walk")
	state_machine.change_state("AttackState")

# =============================================================================
# Re-entry After Combat
# =============================================================================

## Called via IdleState when pending_patrol_points is still set after combat.
func resume_patrol() -> void:
	_is_combat = false
	_scan_timer = SCAN_INTERVAL
	_move_to_target()

# =============================================================================
# Helpers
# =============================================================================

func _play_anim(anim_name: String, direction: Vector2 = Vector2.ZERO) -> void:
	var anim: Node = unit.get_node_or_null("UnitAnimationController")
	if anim != null and anim.has_method("play_state"):
		if direction != Vector2.ZERO:
			anim.play_state(anim_name, direction)
		else:
			anim.play_state(anim_name)


func set_patrol_points(a: Vector2, b: Vector2) -> void:
	_point_a = a
	_point_b = b
