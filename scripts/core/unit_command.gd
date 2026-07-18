class_name UnitCommand
extends Resource

enum CommandType {
	NONE = -1,
	MOVE = 0,
	STOP = 1,
	ATTACK = 2,
	ATTACK_MOVE = 3,
	PATROL = 4,
	HARVEST = 5,
	RETURN_RESOURCE = 6,
	BUILD = 7,
	REPAIR = 8,
	RALLY_POINT = 9,
	CANCEL = 10,
	FOLLOW = 11,
	HOLD_POSITION = 12,
	GARRISON = 13,
	UNGARRISON = 14,
	TRAIN = 15,
	RESEARCH = 16,
	CANCEL_TRAIN = 17,
	CANCEL_RESEARCH = 18
}

enum FormationMode {
	NONE = -1,
	COMPACT = 0,
	LINE = 1,
	COLUMN = 2,
	LOOSE = 3,
	SQUARE = 4
}

enum QueueMode {
	REPLACE = 0,
	APPEND = 1,
	INSERT = 2
}

@export var command_type: CommandType = CommandType.NONE
@export var queued: bool = false
@export var queue_mode: QueueMode = QueueMode.APPEND
@export var target_entity_id: int = -1
@export var target_position: Vector2 = Vector2.ZERO
@export var formation_mode: FormationMode = FormationMode.NONE
@export var formation_offset_index: int = -1
@export var issued_by_player_id: int = -1
@export var issued_timestamp: float = 0.0
@export var target_resource_type: String = ""
@export var target_building_id: int = -1
@export var unit_type_to_train: String = ""
@export var technology_id: String = ""
@export var rally_point: Vector2 = Vector2.ZERO
@export var patrol_points: Array[Vector2] = []
@export var follow_target_id: int = -1
@export var hold_position: bool = false
@export var garrison_target_id: int = -1
@export var ungarrison_spawn_point: Vector2 = Vector2.ZERO
@export var priority: int = 0
@export var data: Dictionary = {}

func _init(cmd_type: CommandType = CommandType.NONE) -> void:
	command_type = cmd_type
	issued_timestamp = Time.get_ticks_msec() / 1000.0

static func move(target_pos: Vector2, formation: FormationMode = FormationMode.COMPACT, queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.MOVE)
	cmd.target_position = target_pos
	cmd.formation_mode = formation
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func stop(queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.STOP)
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func attack(target_id: int, queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.ATTACK)
	cmd.target_entity_id = target_id
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func attack_move(target_pos: Vector2, formation: FormationMode = FormationMode.LINE, queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.ATTACK_MOVE)
	cmd.target_position = target_pos
	cmd.formation_mode = formation
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func patrol(points: Array[Vector2], queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.PATROL)
	cmd.patrol_points = points
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func harvest(resource_id: int, resource_type: String = "", queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.HARVEST)
	cmd.target_entity_id = resource_id
	cmd.target_resource_type = resource_type
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func return_resource(building_id: int = -1, queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.RETURN_RESOURCE)
	cmd.target_building_id = building_id
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func build(building_id: int, queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.BUILD)
	cmd.target_building_id = building_id
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func repair(building_id: int, queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.REPAIR)
	cmd.target_building_id = building_id
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func rally_point(position: Vector2, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.RALLY_POINT)
	cmd.rally_point = position
	cmd.issued_by_player_id = player_id
	return cmd

static func cancel(queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.CANCEL)
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func follow(target_id: int, queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.FOLLOW)
	cmd.follow_target_id = target_id
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func hold_position(hold: bool = true, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.HOLD_POSITION)
	cmd.hold_position = hold
	cmd.issued_by_player_id = player_id
	return cmd

static func garrison(building_id: int, queued: bool = false, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.GARRISON)
	cmd.garrison_target_id = building_id
	cmd.queued = queued
	cmd.issued_by_player_id = player_id
	return cmd

static func ungarrison(building_id: int, spawn_point: Vector2 = Vector2.ZERO, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.UNGARRISON)
	cmd.garrison_target_id = building_id
	cmd.ungarrison_spawn_point = spawn_point
	cmd.issued_by_player_id = player_id
	return cmd

static func train(unit_type: String, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.TRAIN)
	cmd.unit_type_to_train = unit_type
	cmd.issued_by_player_id = player_id
	return cmd

static func research(tech_id: String, player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.RESEARCH)
	cmd.technology_id = tech_id
	cmd.issued_by_player_id = player_id
	return cmd

static func cancel_train(player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.CANCEL_TRAIN)
	cmd.issued_by_player_id = player_id
	return cmd

static func cancel_research(player_id: int = -1) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType.CANCEL_RESEARCH)
	cmd.issued_by_player_id = player_id
	return cmd

func to_dict() -> Dictionary:
	return {
		"command_type": command_type,
		"queued": queued,
		"queue_mode": queue_mode,
		"target_entity_id": target_entity_id,
		"target_position": {"x": target_position.x, "y": target_position.y},
		"formation_mode": formation_mode,
		"formation_offset_index": formation_offset_index,
		"issued_by_player_id": issued_by_player_id,
		"issued_timestamp": issued_timestamp,
		"target_resource_type": target_resource_type,
		"target_building_id": target_building_id,
		"unit_type_to_train": unit_type_to_train,
		"technology_id": technology_id,
		"rally_point": {"x": rally_point.x, "y": rally_point.y},
		"patrol_points": patrol_points.map(func(v): return {"x": v.x, "y": v.y} end),
		"follow_target_id": follow_target_id,
		"hold_position": hold_position,
		"garrison_target_id": garrison_target_id,
		"ungarrison_spawn_point": {"x": ungarrison_spawn_point.x, "y": ungarrison_spawn_point.y},
		"priority": priority,
		"data": data
	}

static func from_dict(data: Dictionary) -> UnitCommand:
	var cmd = UnitCommand.new(CommandType(data.get("command_type", CommandType.NONE)))
	cmd.queued = data.get("queued", false)
	cmd.queue_mode = QueueMode(data.get("queue_mode", QueueMode.APPEND))
	cmd.target_entity_id = data.get("target_entity_id", -1)
	var pos = data.get("target_position", {"x": 0, "y": 0})
	cmd.target_position = Vector2(pos.x, pos.y)
	cmd.formation_mode = FormationMode(data.get("formation_mode", FormationMode.NONE))
	cmd.formation_offset_index = data.get("formation_offset_index", -1)
	cmd.issued_by_player_id = data.get("issued_by_player_id", -1)
	cmd.issued_timestamp = data.get("issued_timestamp", 0.0)
	cmd.target_resource_type = data.get("target_resource_type", "")
	cmd.target_building_id = data.get("target_building_id", -1)
	cmd.unit_type_to_train = data.get("unit_type_to_train", "")
	cmd.technology_id = data.get("technology_id", "")
	var rally = data.get("rally_point", {"x": 0, "y": 0})
	cmd.rally_point = Vector2(rally.x, rally.y)
	cmd.patrol_points = data.get("patrol_points", []).map(func(v): return Vector2(v.x, v.y) end)
	cmd.follow_target_id = data.get("follow_target_id", -1)
	cmd.hold_position = data.get("hold_position", false)
	cmd.garrison_target_id = data.get("garrison_target_id", -1)
	var spawn = data.get("ungarrison_spawn_point", {"x": 0, "y": 0})
	cmd.ungarrison_spawn_point = Vector2(spawn.x, spawn.y)
	cmd.priority = data.get("priority", 0)
	cmd.data = data.get("data", {})
	return cmd

func get_state_name() -> String:
	match command_type:
		CommandType.MOVE: return "Move"
		CommandType.STOP: return "Stop"
		CommandType.ATTACK: return "Attack"
		CommandType.ATTACK_MOVE: return "AttackMove"
		CommandType.PATROL: return "Patrol"
		CommandType.HARVEST: return "Harvest"
		CommandType.RETURN_RESOURCE: return "ReturnResource"
		CommandType.BUILD: return "Build"
		CommandType.REPAIR: return "Repair"
		CommandType.RALLY_POINT: return "RallyPoint"
		CommandType.CANCEL: return "Cancel"
		CommandType.FOLLOW: return "Follow"
		CommandType.HOLD_POSITION: return "HoldPosition"
		CommandType.GARRISON: return "Garrison"
		CommandType.UNGARRISON: return "Ungarrison"
		CommandType.TRAIN: return "Train"
		CommandType.RESEARCH: return "Research"
		CommandType.CANCEL_TRAIN: return "CancelTrain"
		CommandType.CANCEL_RESEARCH: return "CancelResearch"
		_: return "None"

func is_movement_command() -> bool:
	return command_type in [CommandType.MOVE, CommandType.ATTACK_MOVE, CommandType.PATROL, CommandType.FOLLOW]

func is_combat_command() -> bool:
	return command_type in [CommandType.ATTACK, CommandType.ATTACK_MOVE, CommandType.HOLD_POSITION]

func is_economy_command() -> bool:
	return command_type in [CommandType.HARVEST, CommandType.RETURN_RESOURCE, CommandType.BUILD, CommandType.REPAIR, CommandType.GARRISON, CommandType.UNGARRISON]

func is_building_command() -> bool:
	return command_type in [CommandType.RALLY_POINT, CommandType.TRAIN, CommandType.RESEARCH, CommandType.CANCEL_TRAIN, CommandType.CANCEL_RESEARCH]

func requires_target_entity() -> bool:
	return command_type in [CommandType.ATTACK, CommandType.HARVEST, CommandType.BUILD, CommandType.REPAIR, CommandType.FOLLOW, CommandType.GARRISON, CommandType.UNGARRISON]

func requires_target_position() -> bool:
	return command_type in [CommandType.MOVE, CommandType.ATTACK_MOVE, CommandType.PATROL, CommandType.RALLY_POINT]

func can_queue() -> bool:
	return command_type != CommandType.NONE and command_type != CommandType.CANCEL and command_type != CommandType.CANCEL_TRAIN and command_type != CommandType.CANCEL_RESEARCH