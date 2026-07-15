class_name UnitBase
extends CharacterBody2D

signal died(unit_id: int)
signal damaged(amount: int, attacker_id: int)
signal command_received(command: String, data: Dictionary)

@export var unit_id: int = -1
@export var unit_type: String = ""
@export var player_id: int = -1
@export var display_name: String = ""
@export var is_selected: bool = false

var facing: Vector2 = Vector2.RIGHT

var pending_target_resource: Node2D = null
var pending_target_building: Node2D = null
var pending_move_position: Vector2 = Vector2.ZERO
var preferred_resource: String = ""
var build_rate: int = 10

var _unit_data: Dictionary = {}


func initialize(type: String, owner_id: int, spawn_pos: Vector2) -> void:
	unit_type = type
	player_id = owner_id
	global_position = spawn_pos

	_unit_data = DataManager.get_unit_data(type)
	if _unit_data.is_empty():
		push_warning("UnitBase: No data found for unit type '%s'." % type)
		return

	display_name = _unit_data.get("name", type)
	_configure_components()


func _configure_components() -> void:
	var hp: int = _unit_data.get("hp", 100)
	var health_comp: Node = get_node_or_null("HealthComponent")
	if health_comp != null and health_comp.has_method("initialize"):
		health_comp.initialize(hp, player_id)

	var move_comp: Node = get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.set("base_speed", float(_unit_data.get("speed", 100)))
		move_comp.set("speed", float(_unit_data.get("speed", 100)))

	var combat_comp: Node = get_node_or_null("CombatComponent")
	if combat_comp != null and combat_comp.has_method("initialize"):
		combat_comp.initialize(_unit_data)

	var harvest_comp: Node = get_node_or_null("HarvestComponent")
	if harvest_comp != null and harvest_comp.has_method("initialize"):
		harvest_comp.initialize(_unit_data)

	var anim_controller: Node = get_node_or_null("UnitAnimationController")
	if anim_controller != null and anim_controller.has_method("setup_unit_visuals"):
		anim_controller.setup_unit_visuals(unit_type, player_id)


func _process(_delta: float) -> void:
	pass


func _draw() -> void:
	if is_selected:
		var radius: float = 20.0
		var color_fill: Color = Color(0.2, 1.0, 0.2, 0.3)
		var color_ring: Color = Color(0.2, 1.0, 0.2, 0.9)
		draw_circle(Vector2.ZERO, radius, color_fill)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color_ring, 2.0)


func get_grid_position() -> Vector2i:
	var grid: Node = get_node_or_null("/root/GameWorld/GridManager")
	if grid != null and grid.has_method("get_cell_from_world"):
		return grid.get_cell_from_world(global_position)
	return Vector2i(
		floori(global_position.x / 32.0),
		floori(global_position.y / 32.0)
	)


func take_damage(amount: int, attacker_id: int = -1) -> void:
	var health_comp: Node = get_node_or_null("HealthComponent")
	if health_comp != null and health_comp.has_method("take_damage"):
		health_comp.take_damage(amount, attacker_id)
	damaged.emit(amount, attacker_id)


func get_data() -> Dictionary:
	return {
		"unit_id": unit_id,
		"unit_type": unit_type,
		"player_id": player_id,
		"display_name": display_name,
		"position": {"x": global_position.x, "y": global_position.y},
		"is_selected": is_selected,
	}


func is_enemy(other_unit: Node2D) -> bool:
	if other_unit == null:
		return false
	var other_player: int = int(other_unit.get("player_id")) if other_unit.get("player_id") != null else -1
	if other_player == -1 or player_id == -1:
		return false
	if other_player == player_id:
		return false

	var my_team: int = _get_team(player_id)
	var other_team: int = _get_team(other_player)
	return my_team != other_team


func _get_team(pid: int) -> int:
	var player_data: Dictionary = GameManager.get_player(pid)
	if not player_data.is_empty():
		return player_data.get("team", pid)
	return pid


func get_harvest_resource_type() -> String:
	if not preferred_resource.is_empty():
		return preferred_resource
	var harvest_comp: Node = get_node_or_null("HarvestComponent")
	if harvest_comp != null and harvest_comp.get("carry_resource_type") != null:
		return harvest_comp.carry_resource_type
	return "wood"
