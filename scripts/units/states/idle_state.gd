class_name IdleState
extends UnitState

var _aggro_timer: float = 0.0
var _micro_action_timer: float = 0.0
var _next_micro_interval: float = 3.0

const AGGRO_CHECK_INTERVAL: float = 1.0
const MICRO_ACTION_MIN: float = 2.0
const MICRO_ACTION_MAX: float = 6.0
const AUTO_AGGRO_RANGE: float = 150.0


func enter() -> void:
	_aggro_timer = 0.0
	_micro_action_timer = 0.0
	_next_micro_interval = randf_range(MICRO_ACTION_MIN, MICRO_ACTION_MAX)

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("idle")

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.get("is_moving") != null:
		if move_comp.is_moving:
			move_comp.stop()

	_check_auto_aggro()
	_check_pending_commands()


func update(delta: float) -> void:
	_aggro_timer += delta
	if _aggro_timer >= AGGRO_CHECK_INTERVAL:
		_aggro_timer = 0.0
		_check_auto_aggro()

	_micro_action_timer += delta
	if _micro_action_timer >= _next_micro_interval:
		_micro_action_timer = 0.0
		_next_micro_interval = randf_range(MICRO_ACTION_MIN, MICRO_ACTION_MAX)
		_play_micro_action()

	_check_pending_commands()


func exit() -> void:
	pass


func _check_auto_aggro() -> void:
	if unit == null:
		return

	var combat: Node = unit.get_node_or_null("CombatComponent")
	if combat == null:
		return

	var nearest_enemy: Node2D = combat.find_nearest_enemy(AUTO_AGGRO_RANGE)
	if nearest_enemy != null:
		combat.set_target(nearest_enemy)
		state_machine.change_state("AttackState")


func _check_pending_commands() -> void:
	if unit == null:
		return

	var is_villager: bool = false
	if unit.has_method("get") and unit.get("unit_type") != null:
		is_villager = unit.get("unit_type") == "villager"

	if unit.pending_target_resource != null and is_villager:
		state_machine.change_state("HarvestState")
		return

	if unit.pending_target_building != null and is_villager:
		state_machine.change_state("BuildState")
		return

	if unit.pending_move_position != Vector2.ZERO:
		state_machine.change_state("MoveState")
		return


func _play_micro_action() -> void:
	if unit == null:
		return

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		var roll: float = randf()
		if roll < 0.18:
			anim.play_state("celebrate")
			return
		if roll < 0.32:
			anim.play_state("sleep")
			return
		if roll < 0.45:
			anim.play_state("fear")
			return
		if roll < 0.55:
			anim.play_state("victory")
			return

	var sprite: Node2D = unit.get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite == null:
		return

	var offset: Vector2 = Vector2(randf_range(-1.5, 1.5), randf_range(-0.5, 0.5))
	var tween: Tween = unit.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position", offset, 0.3)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.3)


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
