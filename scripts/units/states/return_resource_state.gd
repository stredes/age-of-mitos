class_name ReturnResourceState
extends UnitState

var drop_off_id: int = -1
var drop_off_type: String = "building"
var _drop_off: Node2D = null
var _returning_to_resource: bool = false
var _resource_type: String = "wood"
var _resource_node: Node2D = null

func enter() -> void:
	_drop_off = _find_drop_off()

	if _drop_off == null:
		state_machine.change_state("IdleState")
		return

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("carry")

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(_drop_off.global_position)

	_returning_to_resource = false

func update(delta: float) -> void:
	if _drop_off == null or not is_instance_valid(_drop_off):
		state_machine.change_state("IdleState")
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp == null:
		state_machine.change_state("IdleState")
		return

	if move_comp.is_moving:
		return

	if not _returning_to_resource:
		_drop_off_resources()
	else:
		_return_to_resource()


func exit() -> void:
	drop_off_id = -1
	drop_off_type = "building"
	_drop_off = null
	_returning_to_resource = false
	_resource_node = null


func set_drop_off(entity_id: int, entity_type: String) -> void:
	drop_off_id = entity_id
	drop_off_type = entity_type
	_drop_off = _find_drop_off()


func _find_drop_off() -> Node2D:
	if drop_off_id == -1:
		return null

	if drop_off_type == "building":
		var building_manager: Node = get_node_or_null("/root/GameWorld/BuildingManager")
		if building_manager == null:
			building_manager = get_node_or_null("/root/GameWorld/World/BuildingManager")
		if building_manager != null and building_manager.has_method("get_building"):
			return building_manager.get_building(drop_off_id) as Node2D
	return null


func _drop_off_resources() -> void:
	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp == null:
		_returning_to_resource = true
		_find_and_return_to_resource()
		return

	if harvest_comp.has_method("return_resources"):
		var amount: int = harvest_comp.return_resources()
		if amount > 0:
			var player_id: int = int(unit.get("player_id"))
			var resource_type: String = harvest_comp.get_carry_type()
			EventBus.resource_drop_off.emit(unit.unit_id, drop_off_id, resource_type, amount)

	harvest_comp.reset()

	_resource_type = harvest_comp.get_preferred_resource()
	_returning_to_resource = true
	_find_and_return_to_resource()


func _find_and_return_to_resource() -> void:
	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp == null or not harvest_comp.has_method("find_nearest_resource"):
		state_machine.change_state("IdleState")
		return

	_resource_node = harvest_comp.find_nearest_resource(_resource_type)
	if _resource_node == null:
		state_machine.change_state("IdleState")
		return

	harvest_comp.start_gathering(_resource_node)

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(_resource_node.global_position)

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")


func _return_to_resource() -> void:
	if _resource_node == null or not is_instance_valid(_resource_node):
		_returning_to_resource = false
		_enter_harvest_state()
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp == null:
		return

	if move_comp.is_moving:
		var dist: float = unit.global_position.distance_to(_resource_node.global_position)
		if dist < 40.0:
			move_comp.stop()
			_enter_harvest_state()
		return

	move_comp.move_to(_resource_node.global_position)

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")


func _enter_harvest_state() -> void:
	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp != null and harvest_comp.has_method("start_gathering") and _resource_node != null:
		harvest_comp.start_gathering(_resource_node)
	state_machine.change_state("HarvestState")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")