## Hold state: stand in place, attack any enemy within range.
## Does NOT chase enemies that move out of range. Pure defensive stance.
class_name HoldState
extends UnitState

var _scan_timer: float = 0.0
var _target: Node2D = null
var _engage_timer: float = 0.0

const SCAN_INTERVAL: float = 0.25
const ENGAGE_COOLDOWN: float = 0.5


func enter() -> void:
	_scan_timer = 0.0
	_engage_timer = 0.0
	_target = null

	if unit == null:
		state_machine.change_state("IdleState")
		return

	# Stop all movement.
	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_method("stop"):
		move_comp.stop()

	_play_idle_anim()


func update(delta: float) -> void:
	if unit == null:
		state_machine.change_state("IdleState")
		return

	# Cooldown between engagement checks.
	_engage_timer += delta

	# Check current target validity.
	if _target != null:
		if not is_instance_valid(_target):
			_target = null
		else:
			var health: Node = _target.get_node_or_null("HealthComponent")
			if health != null and not health.is_alive:
				_target = null

	# If we have a valid target in range, attack it.
	if _target != null:
		var combat: Node = unit.get_node_or_null("CombatComponent")
		if combat == null:
			_target = null
		else:
			var dist: float = unit.global_position.distance_to(_target.global_position)
			var attack_range: float = combat.get("attack_range") if combat.get("attack_range") != null else 48.0

			if dist <= attack_range:
				# In range — attack.
				if combat.can_attack():
					_play_attack_anim()
					combat.attack(_target)
				return
			else:
				# Target moved out of range — release it (don't chase).
				combat.clear_target()
				_target = null

	# Periodic scan for new enemies.
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_for_target()


func exit() -> void:
	_target = null
	_scan_timer = 0.0
	_engage_timer = 0.0


func _scan_for_target() -> void:
	if unit == null:
		return
	if _engage_timer < ENGAGE_COOLDOWN:
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		return

	var attack_range: float = combat.get("attack_range") if combat.get("attack_range") != null else 48.0
	var scan_range: float = attack_range + 32.0

	var enemy: Node2D = combat.find_nearest_enemy(scan_range)
	if enemy != null:
		_target = enemy
		combat.set_target(enemy)
		_engage_timer = 0.0


func _play_idle_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("idle")


func _play_attack_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state") and _target != null:
		var dir: Vector2 = (_target.global_position - unit.global_position).normalized()
		anim.play_state("attack", dir)


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
