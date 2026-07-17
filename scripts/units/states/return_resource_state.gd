## Return resource state: carry accumulated resources to the nearest drop-off
## building, deposit them, then return to harvesting if the source node still
## has resources, otherwise go idle. Useful when a villager needs to drop off
## before switching tasks.
class_name ReturnResourceState
extends UnitState

enum Phase {
	WALKING_TO_DROP_OFF,
	DEPOSITING,
	RETURNING_TO_RESOURCE,
}

var phase: Phase = Phase.WALKING_TO_DROP_OFF

var _drop_off_building: Node2D = null
var _source_resource: Node2D = null
var _deposit_timer: float = 0.0

const DROP_OFF_RANGE: float = 48.0
const DEPOSIT_TIME: float = 0.6


func enter() -> void:
	phase = Phase.WALKING_TO_DROP_OFF
	_deposit_timer = 0.0

	if unit == null:
		state_machine.change_state("IdleState")
		return

	# Check if actually carrying anything.
	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp == null:
		state_machine.change_state("IdleState")
		return

	var carry: int = int(harvest_comp.get("current_carry")) if harvest_comp.get("current_carry") != null else 0
	if carry <= 0:
		state_machine.change_state("IdleState")
		return

	# Remember what resource we were harvesting so we can return after depositing.
	_source_resource = harvest_comp.get("target_resource") if harvest_comp.get("target_resource") != null else null

	# Find the nearest drop-off building.
	_drop_off_building = harvest_comp.find_nearest_drop_off()
	if _drop_off_building == null:
		state_machine.change_state("IdleState")
		return

	harvest_comp.drop_off_building = _drop_off_building
	_move_to(_drop_off_building.global_position)
	_update_carry_visual(true)
	_play_walk_anim()


func update(delta: float) -> void:
	if unit == null:
		state_machine.change_state("IdleState")
		return

	match phase:
		Phase.WALKING_TO_DROP_OFF:
			_update_walking_to_drop_off()
		Phase.DEPOSITING:
			_update_depositing(delta)
		Phase.RETURNING_TO_RESOURCE:
			_update_returning_to_resource()


func exit() -> void:
	phase = Phase.WALKING_TO_DROP_OFF
	_drop_off_building = null
	_source_resource = null
	_deposit_timer = 0.0
	_update_carry_visual(false)


func set_source_resource(resource: Node2D) -> void:
	_source_resource = resource


func _update_walking_to_drop_off() -> void:
	if _drop_off_building == null or not is_instance_valid(_drop_off_building):
		state_machine.change_state("IdleState")
		return

	var dist: float = unit.global_position.distance_to(_drop_off_building.global_position)
	if dist <= DROP_OFF_RANGE:
		# Arrived at drop-off.
		var move_comp: Node = unit.get_node_or_null("MovementComponent")
		if move_comp != null and move_comp.is_moving:
			move_comp.stop()
		phase = Phase.DEPOSITING
		_play_build_anim()
	else:
		# Re-navigate if movement stopped.
		var move_comp: Node = unit.get_node_or_null("MovementComponent")
		if move_comp != null and not move_comp.is_moving:
			_move_to(_drop_off_building.global_position)


func _update_depositing(delta: float) -> void:
	_deposit_timer += delta
	if _deposit_timer >= DEPOSIT_TIME:
		# Deposit resources.
		var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
		if harvest_comp != null:
			harvest_comp.return_resources()

		_update_carry_visual(false)

		# Decide whether to return to resource or go idle.
		if _source_resource != null and is_instance_valid(_source_resource):
			var res_amount: int = 0
			if _source_resource.has_method("get_current_amount"):
				res_amount = _source_resource.get_current_amount()
			elif _source_resource.get("current_amount") != null:
				res_amount = int(_source_resource.get("current_amount"))

			if res_amount > 0:
				phase = Phase.RETURNING_TO_RESOURCE
				_move_to(_source_resource.global_position)
				_play_walk_anim()
				return

		state_machine.change_state("IdleState")


func _update_returning_to_resource() -> void:
	if _source_resource == null or not is_instance_valid(_source_resource):
		state_machine.change_state("IdleState")
		return

	var dist: float = unit.global_position.distance_to(_source_resource.global_position)
	if dist < 40.0:
		# Back at resource — resume harvesting.
		var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
		if harvest_comp != null:
			harvest_comp.start_gathering(_source_resource)
		state_machine.change_state("HarvestState")
	else:
		# Re-navigate if stopped.
		var move_comp: Node = unit.get_node_or_null("MovementComponent")
		if move_comp != null and not move_comp.is_moving:
			_move_to(_source_resource.global_position)


func _move_to(pos: Vector2) -> void:
	if unit == null:
		return
	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_method("move_to"):
		move_comp.move_to(pos)


func _update_carry_visual(show_carry: bool) -> void:
	if unit == null:
		return
	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp == null:
		return

	var resource_type: String = harvest_comp.get("carry_resource_type") if harvest_comp.get("carry_resource_type") != null else ""
	var carry_amount: int = int(harvest_comp.get("current_carry")) if harvest_comp.get("current_carry") != null else 0

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("set_carry"):
		anim.set_carry(show_carry and carry_amount > 0, resource_type)


func _play_walk_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")


func _play_build_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("build")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
