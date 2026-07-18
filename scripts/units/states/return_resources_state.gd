class_name ReturnResourcesState
extends UnitState

var drop_off_building: Node2D = null

const DROP_OFF_RANGE: float = 48.0


func enter() -> void:
	if unit == null:
		state_machine.change_state("IdleState")
		return

	var harvest_comp: HarvestComponent = unit.get_node_or_null("HarvestComponent") as HarvestComponent
	if harvest_comp == null or harvest_comp.current_carry <= 0:
		state_machine.change_state("IdleState")
		return

	drop_off_building = harvest_comp.drop_off_building
	if drop_off_building == null or not is_instance_valid(drop_off_building):
		drop_off_building = harvest_comp.find_nearest_drop_off()

	if drop_off_building == null:
		state_machine.change_state("IdleState")
		return

	_move_to_building()


func update(_delta: float) -> void:
	if unit == null or drop_off_building == null or not is_instance_valid(drop_off_building):
		state_machine.change_state("IdleState")
		return

	var dist: float = unit.global_position.distance_to(drop_off_building.global_position)

	if dist > DROP_OFF_RANGE:
		var move_comp: MovementComponent = unit.get_node_or_null("MovementComponent") as MovementComponent
		if move_comp != null and not move_comp.is_moving:
			_move_to_building()
		return

	var move_comp_stop: MovementComponent = unit.get_node_or_null("MovementComponent") as MovementComponent
	if move_comp_stop != null and move_comp_stop.is_moving:
		move_comp_stop.stop()

	_unload_resources()


func exit() -> void:
	drop_off_building = null


func _move_to_building() -> void:
	if drop_off_building == null or unit == null:
		return

	var move_comp: MovementComponent = unit.get_node_or_null("MovementComponent") as MovementComponent
	if move_comp != null:
		move_comp.move_to(drop_off_building.global_position)

	var anim: Node = unit.get_node_or_null("UnitAnimationController")
	if anim != null and anim.has_method("play_state"):
		var dir: Vector2 = (drop_off_building.global_position - unit.global_position).normalized()
		anim.play_state("walk", dir)


func _unload_resources() -> void:
	var harvest_comp: HarvestComponent = unit.get_node_or_null("HarvestComponent") as HarvestComponent
	if harvest_comp == null:
		state_machine.change_state("IdleState")
		return

	harvest_comp.drop_off_building = drop_off_building
	harvest_comp.return_resources()

	if harvest_comp.target_resource != null and is_instance_valid(harvest_comp.target_resource):
		state_machine.change_state("HarvestState")
		return

	state_machine.change_state("IdleState")
