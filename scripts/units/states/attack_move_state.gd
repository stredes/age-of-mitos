## Attack-Move state: unit moves toward a destination while scanning for
## enemies along the path. If an enemy is found, the unit chases and attacks
## it, then resumes movement toward the original destination.
## If no enemies are encountered, the unit arrives and goes idle.
class_name AttackMoveState
extends UnitState

var target_pos: Vector2 = Vector2.ZERO
var _is_combat: bool = false

var _scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.35
const SCAN_RANGE: float = 160.0
const ARRIVAL_THRESHOLD: float = 6.0

## Tracks the move position so we can resume after combat.
var _move_resume_pos: Vector2 = Vector2.ZERO


func enter() -> void:
	_scan_timer = 0.0

	if target_pos == Vector2.ZERO:
		target_pos = unit.pending_attack_move_position
		unit.pending_attack_move_position = Vector2.ZERO

	if target_pos == Vector2.ZERO:
		target_pos = unit.pending_move_position
		unit.pending_move_position = Vector2.ZERO

	if target_pos == Vector2.ZERO:
		state_machine.change_state("IdleState")
		return

	_move_resume_pos = target_pos
	_is_combat = false

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(target_pos)
		EventBus.unit_moved.emit(unit.unit_id, target_pos)

	_play_anim("walk")


func update(delta: float) -> void:
	if _is_combat:
		_update_combat(delta)
	else:
		_update_movement(delta)


func exit() -> void:
	target_pos = Vector2.ZERO
	_move_resume_pos = Vector2.ZERO
	_is_combat = false
	_scan_timer = 0.0

# =============================================================================
# Movement Phase
# =============================================================================

func _update_movement(delta: float) -> void:
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


func _check_arrival(move_comp: Node) -> void:
	if target_pos == Vector2.ZERO:
		return

	var dist: float = unit.global_position.distance_to(target_pos)
	if dist < ARRIVAL_THRESHOLD:
		move_comp.stop()
		state_machine.change_state("IdleState")
		return

	if not move_comp.is_moving:
		state_machine.change_state("IdleState")


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
# Combat Phase
# =============================================================================

func _enter_combat(enemy: Node2D) -> void:
	_is_combat = true

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat != null:
		combat.set_target(enemy)

	_play_anim("walk")
	state_machine.change_state("AttackState")


func _update_combat(_delta: float) -> void:
	pass

# =============================================================================
# Re-entry After Combat
# =============================================================================

## Called by IdleState when it detects a pending attack-move position,
## allowing us to resume movement after combat ends.
func resume_from_combat() -> void:
	_is_combat = false
	target_pos = _move_resume_pos
	_scan_timer = SCAN_INTERVAL  # Scan immediately on resume

	if target_pos == Vector2.ZERO or _reached_destination():
		state_machine.change_state("IdleState")
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(target_pos)
		EventBus.unit_moved.emit(unit.unit_id, target_pos)

	_play_anim("walk")


func _reached_destination() -> bool:
	if _move_resume_pos == Vector2.ZERO:
		return true
	return unit.global_position.distance_to(_move_resume_pos) < ARRIVAL_THRESHOLD

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


func set_target(pos: Vector2) -> void:
	target_pos = pos
	_move_resume_pos = pos
