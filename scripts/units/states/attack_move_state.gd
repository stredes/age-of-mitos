## Attack-Move state: the unit advances to the cursor position but will stop
## and engage any enemy encountered along the way.  Triggered by the A-key.
class_name AttackMoveState
extends UnitState

var _destination: Vector2 = Vector2.ZERO
var _scan_timer: float = 0.0
var _scan_interval: float = 0.25
var _has_arrived: bool = false


func enter() -> void:
	_scan_timer = 0.0
	_has_arrived = false

	if unit == null:
		state_machine.change_state("IdleState")
		return

	# Determine destination: use pending_move_position if set, otherwise
	# the cursor world position stored by InputManager.
	var pending: Variant = unit.get("pending_move_position")
	if pending is Vector2 and pending != Vector2.ZERO:
		_destination = pending
	else:
		# Fallback — just idle.
		state_machine.change_state("IdleState")
		return

	# Start walking toward destination.
	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_method("move_to"):
		move_comp.move_to(_destination)
	else:
		state_machine.change_state("IdleState")
		return

	_play_walk_anim()


func update(delta: float) -> void:
	if unit == null:
		state_machine.change_state("IdleState")
		return

	# Scan for nearby enemies periodically.
	_scan_timer += delta
	if _scan_timer >= _scan_interval:
		_scan_timer = 0.0
		var enemy: Node2D = _scan_for_enemy()
		if enemy != null:
			_engage(enemy)
			return

	# Check if we've reached the destination.
	var dist_to_dest: float = unit.global_position.distance_to(_destination)
	if dist_to_dest < 24.0:
		_has_arrived = true
		state_machine.change_state("IdleState")
		return

	# Check if movement component stopped (path blocked or finished).
	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.get("is_moving") == false and not _has_arrived:
		# Arrived.
		state_machine.change_state("IdleState")


func exit() -> void:
	_destination = Vector2.ZERO
	_scan_timer = 0.0
	_has_arrived = false

	# Clear hold_position flag when leaving via normal path.
	if unit != null:
		unit.set("hold_position", false)


func _scan_for_enemy() -> Node2D:
	if unit == null:
		return null

	var player_id: int = unit.get("player_id") if unit.get("player_id") != null else -1
	if player_id == -1:
		return null

	var scan_range: float = 200.0
	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat != null and combat.get("attack_range") > scan_range:
		scan_range = combat.get("attack_range") + 48.0

	var unit_manager: Node = _find_unit_manager()
	if unit_manager != null and unit_manager.has_method("get_nearest_enemy"):
		return unit_manager.get_nearest_enemy(unit.global_position, player_id, scan_range)

	return null


func _engage(enemy: Node2D) -> void:
	if unit == null or enemy == null:
		return

	# Stop current movement.
	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_method("stop"):
		move_comp.stop()

	# Set target on combat component.
	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat != null and combat.has_method("set_target"):
		combat.set_target(enemy)

	# Transition to AttackState.
	var state_machine_node: UnitStateMachine = unit.get_node_or_null("UnitStateMachine") as UnitStateMachine
	if state_machine_node != null:
		var attack_state: Node = state_machine_node.states.get("AttackState")
		if attack_state != null and attack_state is AttackState:
			attack_state.set_target(enemy)
		state_machine_node.change_state("AttackState")


func _play_walk_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		var dir: Vector2 = Vector2.RIGHT
		if unit != null:
			var move_comp: Node = unit.get_node_or_null("MovementComponent")
			if move_comp != null and move_comp.has_method("get_velocity"):
				var vel: Vector2 = move_comp.get_velocity()
				if vel.length_squared() > 1.0:
					dir = vel.normalized()
		anim.play_state("walk", dir)


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")


func _find_unit_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_node_by_name(scene, "UnitManager")


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_node_by_name(child, target_name)
		if result != null:
			return result
	return null
