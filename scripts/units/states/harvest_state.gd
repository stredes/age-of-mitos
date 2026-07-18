class_name HarvestState
extends UnitState

enum Phase {
	GO_TO_RESOURCE,
	GATHERING,
	GO_TO_DROP_OFF,
	DROPPING_OFF,
}

var phase: Phase = Phase.GO_TO_RESOURCE

var resource_node: Node2D = null
var _drop_off_building: Node2D = null


func enter() -> void:
	phase = Phase.GO_TO_RESOURCE

	if unit == null:
		state_machine.change_state("IdleState")
		return

	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp == null:
		state_machine.change_state("IdleState")
		return

	if unit.pending_target_resource != null:
		resource_node = unit.pending_target_resource
		unit.pending_target_resource = null
	elif harvest_comp.get("target_resource") != null:
		resource_node = harvest_comp.target_resource
	else:
		var resource_type: String = ""
		resource_type = unit.preferred_resource
		resource_node = harvest_comp.find_nearest_resource(resource_type)
		if resource_node == null:
			state_machine.change_state("IdleState")
			return

	harvest_comp.start_gathering(resource_node)
	_move_to_resource()


func update(delta: float) -> void:
	if unit == null or resource_node == null or not is_instance_valid(resource_node):
		state_machine.change_state("IdleState")
		return

	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp == null:
		state_machine.change_state("IdleState")
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")

	match phase:
		Phase.GO_TO_RESOURCE:
			if resource_node.has_method("is_in_range"):
				if resource_node.is_in_range(unit.global_position):
					if move_comp != null and move_comp.is_moving:
						move_comp.stop()
					phase = Phase.GATHERING
					_play_gather_anim()
				elif move_comp != null and not move_comp.is_moving:
					_move_to_resource()
			else:
				var dist: float = unit.global_position.distance_to(resource_node.global_position)
				if dist < 40.0:
					if move_comp != null and move_comp.is_moving:
						move_comp.stop()
					phase = Phase.GATHERING
					_play_gather_anim()
				elif move_comp != null and not move_comp.is_moving:
					_move_to_resource()

		Phase.GATHERING:
			harvest_comp.harvest(delta)

			if resource_node.has_method("get_current_amount"):
				if resource_node.get_current_amount() <= 0:
					harvest_comp.reset()
					_switch_to_return(harvest_comp)
					return

			if harvest_comp.is_full():
				_switch_to_return(harvest_comp)

		Phase.GO_TO_DROP_OFF:
			if move_comp != null and not move_comp.is_moving:
				phase = Phase.DROPPING_OFF
				_play_build_anim()

		Phase.DROPPING_OFF:
			harvest_comp.return_resources()
			harvest_comp.reset()

			var res_depleted: bool = true
			if resource_node != null and is_instance_valid(resource_node):
				var res_amount: int = 0
				if resource_node.has_method("get_current_amount"):
					res_amount = resource_node.get_current_amount()
				elif resource_node.get("current_amount") != null:
					res_amount = int(resource_node.get("current_amount"))
				if res_amount > 0:
					res_depleted = false

			if res_depleted:
				var old_resource_type: String = ""
				if resource_node != null and is_instance_valid(resource_node):
					old_resource_type = resource_node.get("resource_type", "")
				resource_node = null
				if old_resource_type != "":
					var new_resource = harvest_comp.find_nearest_resource(old_resource_type)
					if new_resource != null:
						resource_node = new_resource
						phase = Phase.GO_TO_RESOURCE
						harvest_comp.start_gathering(resource_node)
						_move_to_resource()
						return
				state_machine.change_state("IdleState")
			else:
				phase = Phase.GO_TO_RESOURCE
				harvest_comp.start_gathering(resource_node)
				_move_to_resource()


func exit() -> void:
	var harvest_comp: Node = null
	if unit != null:
		harvest_comp = unit.get_node_or_null("HarvestComponent")
	if harvest_comp != null and harvest_comp.has_method("reset"):
		harvest_comp.reset()

	phase = Phase.GO_TO_RESOURCE
	resource_node = null
	_drop_off_building = null


func _move_to_resource() -> void:
	if resource_node == null or unit == null:
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(resource_node.global_position)

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		var dir: Vector2 = (resource_node.global_position - unit.global_position).normalized()
		anim.play_state("walk", dir)


func _move_to_drop_off() -> void:
	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp == null:
		return

	if _drop_off_building == null or not is_instance_valid(_drop_off_building):
		_drop_off_building = harvest_comp.find_nearest_drop_off()
	if _drop_off_building == null:
		state_machine.change_state("IdleState")
		return

	harvest_comp.drop_off_building = _drop_off_building

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(_drop_off_building.global_position)

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		var dir: Vector2 = (_drop_off_building.global_position - unit.global_position).normalized()
		anim.play_state("walk", dir)


func _switch_to_return(harvest_comp: Node) -> void:
	phase = Phase.GO_TO_DROP_OFF
	_move_to_drop_off()


func _play_gather_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("harvest")


func _play_build_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("build")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
