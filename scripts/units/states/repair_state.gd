class_name RepairState
extends UnitState

var target_id: int = -1
var target_type: String = "building"
var _target: Node2D = null
var _repair_timer: float = 0.0
const REPAIR_INTERVAL: float = 1.0
const REPAIR_AMOUNT: int = 20
const REPAIR_COST: int = 5
const REPAIR_RANGE: float = 32.0
var _resource_type: String = "wood"
var _cost_resource: String = "wood"

func enter() -> void:
	_repair_timer = 0.0
	_target = null

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("build")

	_target = _find_target()
	if _target != null:
		_move_to_target()

func update(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		state_machine.change_state("IdleState")
		return

	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp != null and harvest_comp.has_method("get_carry_amount"):
		var carry_amount: int = harvest_comp.get_carry_amount()
		if carry_amount <= 0:
			_go_gather_resources()
			return

	var dist: float = unit.global_position.distance_to(_target.global_position)
	if dist > REPAIR_RANGE:
		_move_to_target()
		return

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("build")

	_repair_timer += delta
	if _repair_timer >= REPAIR_INTERVAL:
		_repair_timer = 0.0
		_perform_repair()

	var target_health: Node = _target.get_node_or_null("HealthComponent")
	if target_health != null and target_health.has_method("get_current_hp"):
		if target_health.get_current_hp() >= target_health.get_max_hp():
			state_machine.change_state("IdleState")


func exit() -> void:
	target_id = -1
	target_type = "building"
	_target = null
	_repair_timer = 0.0


func set_target(entity_id: int, entity_type: String) -> void:
	target_id = entity_id
	target_type = entity_type
	_target = _find_target()


func _find_target() -> Node2D:
	if target_id == -1:
		return null

	if target_type == "building":
		var building_manager: Node = get_node_or_null("/root/GameWorld/BuildingManager")
		if building_manager == null:
			building_manager = get_node_or_null("/root/GameWorld/World/BuildingManager")
		if building_manager != null and building_manager.has_method("get_building"):
			return building_manager.get_building(target_id) as Node2D
	elif target_type == "unit":
		var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
		for u: Node in all_units:
			if u is Node2D and u.get("unit_id") != null and int(u.get("unit_id")) == target_id:
				return u as Node2D
	return null


func _move_to_target() -> void:
	if _target == null:
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(_target.global_position)

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")


func _perform_repair() -> void:
	if _target == null:
		return

	var player_id: int = int(unit.get("player_id"))
	if not GameManager.spend_resources({_cost_resource: REPAIR_COST}, player_id):
		return

	var target_health: Node = _target.get_node_or_null("HealthComponent")
	if target_health != null and target_health.has_method("heal"):
		target_health.heal(REPAIR_AMOUNT)

	EventBus.villager_assigned.emit(unit.unit_id, target_id, "repair")


func _go_gather_resources() -> void:
	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	if harvest_comp != null and harvest_comp.has_method("find_nearest_resource"):
		var resource: Node2D = harvest_comp.find_nearest_resource(_resource_type)
		if resource != null:
			unit.set("pending_target_resource", resource)
			state_machine.change_state("HarvestState")
			return
	state_machine.change_state("IdleState")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")