class_name AttackState
extends UnitState

var target_node: Node2D = null

var _chase_timer: float = 0.0
const CHASE_CHECK_INTERVAL: float = 0.3


func enter() -> void:
	_chase_timer = 0.0

	if unit == null:
		return

	# Clear hold_position on new attack command.
	unit.set("hold_position", false)

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		state_machine.change_state("IdleState")
		return

	if target_node == null:
		if combat.get("target") != null:
			target_node = combat.target

	if target_node == null or not is_instance_valid(target_node):
		state_machine.change_state("IdleState")
		return

	if combat.is_in_attack_range(target_node.global_position):
		_play_attack_anim()
		combat.attack(target_node)
	else:
		_chase_target()


func update(delta: float) -> void:
	if target_node == null or not is_instance_valid(target_node):
		state_machine.change_state("IdleState")
		return

	var health: Node = target_node.get_node_or_null("HealthComponent")
	if health != null and not health.is_alive:
		target_node = null
		state_machine.change_state("IdleState")
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		state_machine.change_state("IdleState")
		return

	var dist: float = unit.global_position.distance_to(target_node.global_position)

	if combat.is_in_attack_range(target_node.global_position):
		var move_comp: Node = unit.get_node_or_null("MovementComponent")
		if move_comp != null and move_comp.is_moving:
			move_comp.stop()

		if combat.can_attack():
			_play_attack_anim()
			combat.attack(target_node)
	else:
		# Don't chase if hold_position is set.
		var hold_pos: bool = unit.get("hold_position") if unit.get("hold_position") != null else false
		if hold_pos:
			return

		_chase_timer += delta
		if _chase_timer >= CHASE_CHECK_INTERVAL:
			_chase_timer = 0.0
			_chase_target()

	if dist > 400.0:
		combat.clear_target()
		target_node = null
		state_machine.change_state("IdleState")


func exit() -> void:
	target_node = null
	_chase_timer = 0.0


func set_target(new_target: Node2D) -> void:
	target_node = new_target


func _chase_target() -> void:
	if target_node == null or unit == null:
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		var chase_pos: Vector2 = target_node.global_position
		move_comp.move_to(chase_pos)

		var anim: Node = _get_anim_controller()
		if anim != null and anim.has_method("play_state"):
			var dir: Vector2 = (target_node.global_position - unit.global_position).normalized()
			anim.play_state("walk", dir)


func _play_attack_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		var dir: Vector2 = (target_node.global_position - unit.global_position).normalized()
		anim.play_state("attack", dir)


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
