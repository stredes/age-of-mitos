class_name UnitManager
extends Node

signal unit_added(unit: Node2D)
signal unit_removed(unit_id: int)

const UNIT_SCENE_PATH: String = "res://scenes/units/unit.tscn"

var units: Dictionary = {}
var _next_id: int = 1


func _ready() -> void:
	EventBus.unit_died.connect(_on_unit_died)


func spawn_unit(type: String, position: Vector2, player_id: int) -> Node2D:
	var unit_scene: PackedScene = null
	if ResourceLoader.exists(UNIT_SCENE_PATH):
		unit_scene = load(UNIT_SCENE_PATH) as PackedScene

	var unit: Node2D = null
	if unit_scene != null:
		unit = unit_scene.instantiate() as Node2D
	else:
		unit = _create_fallback_unit()

	if unit == null:
		push_error("UnitManager: Failed to create unit of type '%s'." % type)
		return null

	var assigned_id: int = _next_id
	_next_id += 1
	unit.unit_id = assigned_id
	units[assigned_id] = unit

	add_child(unit)

	if unit.has_method("initialize"):
		unit.initialize(type, player_id, position)

	EventBus.unit_spawned.emit(assigned_id, type, player_id, position)
	unit_added.emit(unit)

	return unit


func despawn_unit(target_id: int) -> void:
	if not units.has(target_id):
		return

	var unit: Node2D = units[target_id] as Node2D
	units.erase(target_id)

	if unit != null and is_instance_valid(unit):
		unit.queue_free()

	unit_removed.emit(target_id)


func get_unit(target_id: int) -> Node2D:
	if units.has(target_id):
		var unit: Node2D = units[target_id]
		if unit != null and is_instance_valid(unit):
			return unit
		units.erase(target_id)
	return null


func get_all_units() -> Array:
	var result: Array = []
	var to_remove: Array = []
	for id: int in units:
		var unit: Node2D = units[id] as Node2D
		if unit != null and is_instance_valid(unit):
			result.append(unit)
		else:
			to_remove.append(id)
	for id: int in to_remove:
		units.erase(id)
	return result


func get_player_units(target_player_id: int) -> Array:
	var result: Array = []
	var to_remove: Array = []
	for id: int in units:
		var unit: Node2D = units[id] as Node2D
		if unit == null or not is_instance_valid(unit):
			to_remove.append(id)
			continue
		var pid: int = int(unit.get("player_id")) if unit.get("player_id") != null else -1
		if pid == target_player_id:
			result.append(unit)
	for id: int in to_remove:
		units.erase(id)
	return result


func get_units_in_area(center: Vector2, radius: float) -> Array:
	var result: Array = []
	var radius_sq: float = radius * radius
	var to_remove: Array = []
	for id: int in units:
		var unit: Node2D = units[id] as Node2D
		if unit == null or not is_instance_valid(unit):
			to_remove.append(id)
			continue
		var dist_sq: float = unit.global_position.distance_squared_to(center)
		if dist_sq <= radius_sq:
			result.append(unit)
	for id: int in to_remove:
		units.erase(id)
	return result


func get_enemy_units_in_area(center: Vector2, radius: float, target_player_id: int) -> Array:
	var result: Array = []
	var radius_sq: float = radius * radius
	var to_remove: Array = []
	for id: int in units:
		var unit: Node2D = units[id] as Node2D
		if unit == null or not is_instance_valid(unit):
			to_remove.append(id)
			continue
		var pid: int = int(unit.get("player_id")) if unit.get("player_id") != null else -1
		if pid == target_player_id:
			continue
		var my_team: int = _get_team(target_player_id)
		var other_team: int = _get_team(pid)
		if my_team == other_team:
			continue
		var dist_sq: float = unit.global_position.distance_squared_to(center)
		if dist_sq <= radius_sq:
			result.append(unit)
	for id: int in to_remove:
		units.erase(id)
	return result


func get_nearest_enemy(position: Vector2, target_player_id: int) -> Node2D:
	var best: Node2D = null
	var best_dist_sq: float = INF
	var my_team: int = _get_team(target_player_id)
	var to_remove: Array = []

	for id: int in units:
		var unit: Node2D = units[id] as Node2D
		if unit == null or not is_instance_valid(unit):
			to_remove.append(id)
			continue
		var pid: int = int(unit.get("player_id")) if unit.get("player_id") != null else -1
		if pid == target_player_id:
			continue
		var other_team: int = _get_team(pid)
		if my_team == other_team:
			continue

		var health: Node = unit.get_node_or_null("HealthComponent")
		if health != null and health.get("is_alive") != null:
			if not health.is_alive:
				continue

		var dist_sq: float = unit.global_position.distance_squared_to(position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = unit

	for id: int in to_remove:
		units.erase(id)
	return best


func on_unit_died(killed_unit_id: int, killer_id: int, killed_player_id: int) -> void:
	pass


func get_unit_count() -> int:
	return units.size()


func get_player_unit_count(target_player_id: int) -> int:
	return get_player_units(target_player_id).size()


func _on_unit_died(killed_unit_id: int, killer_id: int, killed_player_id: int) -> void:
	var unit: Node2D = get_unit(killed_unit_id)
	if unit != null:
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("DeadState")


func _get_team(pid: int) -> int:
	var player_data: Dictionary = GameManager.get_player(pid)
	if not player_data.is_empty():
		return player_data.get("team", pid)
	return pid


func _create_fallback_unit() -> Node2D:
	var unit: CharacterBody2D = CharacterBody2D.new()
	unit.name = "Unit"

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	unit.add_child(sprite)

	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	unit.add_child(collision)

	var health_comp: Node = Node.new()
	health_comp.name = "HealthComponent"
	health_comp.set_script(load("res://scripts/units/components/health_component.gd"))
	unit.add_child(health_comp)

	var move_comp: Node = Node.new()
	move_comp.name = "MovementComponent"
	move_comp.set_script(load("res://scripts/units/components/movement_component.gd"))
	unit.add_child(move_comp)

	var combat_comp: Node = Node.new()
	combat_comp.name = "CombatComponent"
	combat_comp.set_script(load("res://scripts/units/components/combat_component.gd"))
	unit.add_child(combat_comp)

	var harvest_comp: Node = Node.new()
	harvest_comp.name = "HarvestComponent"
	harvest_comp.set_script(load("res://scripts/units/components/harvest_component.gd"))
	unit.add_child(harvest_comp)

	var sel_comp: Node = Node.new()
	sel_comp.name = "SelectionComponent"
	sel_comp.set_script(load("res://scripts/units/components/selection_component.gd"))
	unit.add_child(sel_comp)

	var state_machine: Node = Node.new()
	state_machine.name = "UnitStateMachine"
	state_machine.set_script(load("res://scripts/units/unit_state_machine.gd"))
	unit.add_child(state_machine)

	var anim_controller: Node = Node.new()
	anim_controller.name = "UnitAnimationController"
	anim_controller.set_script(load("res://scripts/animation/unit_animation_controller.gd"))
	unit.add_child(anim_controller)

	unit.set_script(load("res://scripts/units/unit_base.gd"))

	return unit
