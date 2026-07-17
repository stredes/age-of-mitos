class_name UnitCommand
extends Resource

enum CommandType {
	NONE = -1,
	MOVE = 0,
	ATTACK = 1,
	ATTACK_MOVE = 2,
	HARVEST = 3,
	BUILD = 4,
	REPAIR = 5,
	PATROL = 6,
	FOLLOW = 7,
	HOLD_POSITION = 8,
	STOP = 9,
	RETURN_RESOURCE = 10,
	GARRISON = 11,
	UNGARRISON = 12
}

@export var command_type: CommandType = CommandType.NONE
@export var target_position: Vector2 = Vector2.ZERO
@export var target_entity_id: int = -1
@export var target_entity_type: String = ""
@export var shift_queued: bool = false
@export var formation_index: int = 0
@export var data: Dictionary = {}

func _init() -> void:
	data = {}

static func create_move(target: Vector2, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.MOVE
	cmd.target_position = target
	cmd.shift_queued = shift_queued
	return cmd

static func create_attack(target_id: int, target_type: String, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.ATTACK
	cmd.target_entity_id = target_id
	cmd.target_entity_type = target_type
	cmd.shift_queued = shift_queued
	return cmd

static func create_attack_move(target: Vector2, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.ATTACK_MOVE
	cmd.target_position = target
	cmd.shift_queued = shift_queued
	return cmd

static func create_harvest(resource_id: int, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.HARVEST
	cmd.target_entity_id = resource_id
	cmd.target_entity_type = "resource"
	cmd.shift_queued = shift_queued
	return cmd

static func create_build(building_type: String, cell: Vector2i, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.BUILD
	cmd.target_entity_type = building_type
	cmd.data["cell"] = cell
	cmd.shift_queued = shift_queued
	return cmd

static func create_repair(target_id: int, target_type: String, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.REPAIR
	cmd.target_entity_id = target_id
	cmd.target_entity_type = target_type
	cmd.shift_queued = shift_queued
	return cmd

static func create_patrol(point_a: Vector2, point_b: Vector2, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.PATROL
	cmd.data["patrol_point_a"] = point_a
	cmd.data["patrol_point_b"] = point_b
	cmd.shift_queued = shift_queued
	return cmd

static func create_follow(target_id: int, target_type: String, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.FOLLOW
	cmd.target_entity_id = target_id
	cmd.target_entity_type = target_type
	cmd.shift_queued = shift_queued
	return cmd

static func create_hold_position(shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.HOLD_POSITION
	cmd.shift_queued = shift_queued
	return cmd

static func create_stop(shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.STOP
	cmd.shift_queued = shift_queued
	return cmd

static func create_return_resource(drop_off_id: int, drop_off_type: String, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.RETURN_RESOURCE
	cmd.target_entity_id = drop_off_id
	cmd.target_entity_type = drop_off_type
	cmd.shift_queued = shift_queued
	return cmd

static func create_garrison(building_id: int, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.GARRISON
	cmd.target_entity_id = building_id
	cmd.target_entity_type = "building"
	cmd.shift_queued = shift_queued
	return cmd

static func create_ungarrison(exit_position: Vector2, shift_queued: bool = false) -> UnitCommand:
	var cmd = UnitCommand.new()
	cmd.command_type = CommandType.UNGARRISON
	cmd.target_position = exit_position
	cmd.shift_queued = shift_queued
	return cmd