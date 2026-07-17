class_name BuildState
extends UnitState

var target_building: Node2D = null

var _build_timer: float = 0.0
var _build_interval: float = 1.0
const BUILD_RANGE: float = 48.0
const ARRIVAL_TOLERANCE: float = 8.0

# Diminishing returns per additional builder: [1st, 2nd, 3rd, 4th, 5th+]
const BUILDER_EFFICIENCY: Array[float] = [1.0, 0.8, 0.65, 0.55, 0.5]


func enter() -> void:
	_build_timer = 0.0

	if unit == null:
		state_machine.change_state("IdleState")
		return

	if unit.pending_target_building != null:
		target_building = unit.pending_target_building
		unit.pending_target_building = null

	if target_building == null or not is_instance_valid(target_building):
		state_machine.change_state("IdleState")
		return

	# Register this builder with the building.
	_register_builder()

	_move_to_building()


func update(delta: float) -> void:
	if target_building == null or not is_instance_valid(target_building):
		state_machine.change_state("IdleState")
		return

	# Check if building completed by another builder.
	if target_building.get("is_constructed") == true:
		state_machine.change_state("IdleState")
		return

	var dist: float = unit.global_position.distance_to(target_building.global_position)

	if dist > BUILD_RANGE:
		var move_comp: Node = unit.get_node_or_null("MovementComponent")
		if move_comp != null and not move_comp.is_moving:
			_move_to_building()
		return

	var move_comp_stop: Node = unit.get_node_or_null("MovementComponent")
	if move_comp_stop != null and move_comp_stop.is_moving:
		move_comp_stop.stop()

	_play_build_anim()

	_build_timer += delta
	if _build_timer >= _build_interval:
		_build_timer = 0.0
		_advance_construction()


func exit() -> void:
	_unregister_builder()
	target_building = null
	_build_timer = 0.0


func set_target(building: Node2D) -> void:
	target_building = building


func _register_builder() -> void:
	if target_building == null:
		return
	if target_building.get("construction_workers") != null:
		target_building.construction_workers += 1


func _unregister_builder() -> void:
	if target_building == null or not is_instance_valid(target_building):
		return
	if target_building.get("construction_workers") != null:
		target_building.construction_workers = maxi(target_building.construction_workers - 1, 0)


func _get_builder_efficiency() -> float:
	if target_building == null:
		return 1.0
	var worker_count: int = target_building.get("construction_workers") if target_building.get("construction_workers") != null else 1
	var index: int = clampi(worker_count - 1, 0, BUILDER_EFFICIENCY.size() - 1)
	return BUILDER_EFFICIENCY[index]


func _move_to_building() -> void:
	if target_building == null or unit == null:
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(target_building.global_position)

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")


func _advance_construction() -> void:
	if target_building == null or not is_instance_valid(target_building):
		return

	var base_rate: int = unit.build_rate
	var efficiency: float = _get_builder_efficiency()
	var work_amount: int = maxi(ceili(float(base_rate) * efficiency), 1)

	if target_building.has_method("advance_construction"):
		target_building.advance_construction(work_amount)
	elif target_building.get("construction_current") != null and target_building.get("construction_max") != null:
		var current: int = target_building.construction_current
		var total: int = target_building.construction_max
		target_building.construction_current = mini(current + work_amount, total)

		var building_id: int = int(target_building.get("building_id")) if target_building.get("building_id") != null else -1
		var player_id: int = int(target_building.get("player_id")) if target_building.get("player_id") != null else -1
		EventBus.construction_progress.emit(building_id, target_building.construction_current, total)

		if target_building.construction_current >= total:
			if target_building.has_method("complete_construction"):
				target_building.complete_construction()
			EventBus.construction_completed.emit(building_id, player_id)
			state_machine.change_state("IdleState")


func _play_build_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("build")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
