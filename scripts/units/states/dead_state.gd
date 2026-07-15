class_name DeadState
extends UnitState

var _death_timer: float = 0.0
var _corpse_duration: float = 5.0
var _fade_duration: float = 2.0
var _is_corpse: bool = false

const CORPSE_ALPHA: float = 0.5


func enter() -> void:
	_death_timer = 0.0
	_is_corpse = false

	if unit == null:
		return

	_disable_selection()
	_disable_collision()

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_death"):
		anim.play_death()
	elif anim != null and anim.has_method("play_state"):
		anim.play_state("death")

	unit.set_process(false)
	unit.set_physics_process(false)

	EventBus.unit_died.emit(unit.unit_id, -1, unit.player_id)


func update(delta: float) -> void:
	if unit == null:
		return

	_death_timer += delta

	if not _is_corpse:
		var anim: Node = _get_anim_controller()
		if anim != null and anim.has_method("is_animation_finished"):
			if anim.is_animation_finished():
				_is_corpse = true
				_death_timer = 0.0
		else:
			if _death_timer >= 1.0:
				_is_corpse = true
				_death_timer = 0.0

	if _is_corpse:
		if _death_timer >= _corpse_duration:
			_fade_out()
		elif _death_timer >= _corpse_duration - _fade_duration:
			_apply_fade()


func exit() -> void:
	pass


func _disable_selection() -> void:
	if unit == null:
		return

	var sel_comp: Node = unit.get_node_or_null("SelectionComponent")
	if sel_comp != null:
		if sel_comp.has_method("deselect"):
			sel_comp.deselect()
		sel_comp.set("is_selectable", false)

	unit.is_selected = false
	unit.queue_redraw()


func _disable_collision() -> void:
	if unit == null:
		return

	var collision: Node = unit.get_node_or_null("CollisionShape2D")
	if collision != null and collision is CollisionShape2D:
		(collision as CollisionShape2D).set_deferred("disabled", true)

	var area: Node = unit.get_node_or_null("Area2D")
	if area != null and area is Area2D:
		(area as Area2D).set_deferred("monitoring", false)
		(area as Area2D).set_deferred("monitorable", false)


func _apply_fade() -> void:
	if unit == null:
		return

	var sprite: Node = unit.get_node_or_null("AnimatedSprite2D")
	if sprite != null and sprite is CanvasItem:
		var progress: float = (_death_timer - (_corpse_duration - _fade_duration)) / _fade_duration
		progress = clampf(progress, 0.0, 1.0)
		(sprite as CanvasItem).modulate.a = lerpf(CORPSE_ALPHA, 0.0, progress)


func _fade_out() -> void:
	if unit == null:
		return

	unit.queue_free()


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
