class_name MovementComponent
extends Node

signal movement_started()
signal movement_completed()
signal movement_failed()
signal need_move(target_pos: Vector2)

@export var base_speed: float = 100.0
@export var acceleration: float = 360.0
@export var deceleration: float = 520.0
@export var turn_smoothing: float = 10.0

var speed: float = 100.0
var target_position: Vector2 = Vector2.ZERO
var path: Array[Vector2] = []
var current_path_index: int = 0
var is_moving: bool = false
var facing: Vector2 = Vector2.RIGHT
var current_velocity: Vector2 = Vector2.ZERO

const TERRAIN_SPEED_MULTIPLIERS: Dictionary = {
	"grass": 1.0,
	"sand": 0.9,
	"forest": 0.7,
	"mountain": 0.5,
	"water": 0.0,
	"deep_water": 0.0,
}

const ARRIVAL_THRESHOLD: float = 2.0
const AHEAD_CHECK_DISTANCE: float = 24.0
const BLOCKED_SLOWDOWN: float = 0.3
const SEPARATION_RADIUS: float = 28.0
const SEPARATION_FORCE: float = 120.0
const MAX_SPEED_SAFETY: float = 500.0

var _pathfinder: Node = null
var _grid_manager: Node = null
var _parent_unit: Node2D = null
var _blocked_timer: float = 0.0
var _recalc_timer: float = 0.0
var _dust_timer: float = 0.0
var _last_valid_position: Vector2 = Vector2.ZERO
const RECALC_INTERVAL: float = 1.0
const DUST_INTERVAL: float = 0.28


func _ready() -> void:
	call_deferred("_initialize_references")


func _initialize_references() -> void:
	_parent_unit = get_parent() as Node2D
	_pathfinder = _find_pathfinder()
	_grid_manager = _find_grid_manager()
	speed = base_speed


func _find_pathfinder() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_node_recursive(scene, "Pathfinder")


func _find_grid_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_node_recursive(scene, "GridManager")


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		if child.name == target_name:
			return child
	for child: Node in node.get_children():
		var result: Node = _find_node_recursive(child, target_name)
		if result != null:
			return result
	return null


func move_to(world_position: Vector2) -> void:
	if _parent_unit == null:
		return
	if _pathfinder == null:
		_pathfinder = _find_pathfinder()
		if _pathfinder == null:
			movement_failed.emit()
			return

	target_position = world_position
	path = _pathfinder.find_path_for_movement(_parent_unit.global_position, world_position)

	if path.is_empty():
		if _parent_unit.global_position.distance_to(world_position) < ARRIVAL_THRESHOLD * 4.0:
			path.append(world_position)
		else:
			movement_failed.emit()
			return

	current_path_index = 0
	is_moving = true
	movement_started.emit()


func _process(delta: float) -> void:
	if not is_moving or _parent_unit == null:
		return
	move_along_path(delta)


func move_along_path(delta: float) -> void:
	if path.is_empty() or current_path_index >= path.size():
		_arrive()
		return

	var next_point: Vector2 = path[current_path_index]
	var direction: Vector2 = next_point - _parent_unit.global_position
	var distance: float = direction.length()

	if distance < ARRIVAL_THRESHOLD:
		current_path_index += 1
		if current_path_index >= path.size():
			_arrive()
		return

	var move_dir: Vector2 = direction.normalized()
	var speed_mult: float = _get_terrain_multiplier()
	var desired_speed: float = speed * speed_mult

	if _is_unit_ahead(move_dir):
		_blocked_timer += delta
		if _blocked_timer > 0.5:
			desired_speed *= BLOCKED_SLOWDOWN
	else:
		_blocked_timer = 0.0

	# Smooth arrival: decelerate when near the final destination.
	if current_path_index >= path.size() - 1 and distance < 64.0:
		desired_speed *= clampf(distance / 64.0, 0.2, 1.0)

	# Apply separation force to avoid stacking with nearby units.
	var separation: Vector2 = _calculate_separation()

	var desired_velocity: Vector2 = move_dir * desired_speed + separation
	if desired_velocity.length() > MAX_SPEED_SAFETY:
		desired_velocity = desired_velocity.normalized() * MAX_SPEED_SAFETY

	var rate: float = acceleration if desired_velocity.length_squared() > current_velocity.length_squared() else deceleration
	current_velocity = current_velocity.move_toward(desired_velocity, rate * delta)

	var movement: Vector2 = current_velocity * delta

	# No-teleport safety: clamp movement to a max distance per frame.
	var max_step: float = speed * delta * 1.5
	if movement.length() > max_step:
		movement = movement.normalized() * max_step

	_parent_unit.global_position += movement

	# Track last valid position (updated when not stuck).
	if not _is_unit_ahead(move_dir):
		_last_valid_position = _parent_unit.global_position

	facing = facing.lerp(move_dir, clampf(turn_smoothing * delta, 0.0, 1.0)).normalized()
	_parent_unit.facing = move_dir

	_update_facing_visual(facing)
	_spawn_walk_dust(delta)


func _arrive() -> void:
	is_moving = false
	path.clear()
	current_path_index = 0
	current_velocity = Vector2.ZERO
	movement_completed.emit()


func stop() -> void:
	is_moving = false
	path.clear()
	current_path_index = 0
	_blocked_timer = 0.0
	current_velocity = Vector2.ZERO


func get_facing_direction() -> Vector2:
	return facing


## Get the last known valid position (used before a teleport or recalc).
func get_last_valid_position() -> Vector2:
	return _last_valid_position


## Recalculate the path from the unit's current position to target_position.
## Used when an obstacle appears mid-movement.
func recalculate_path() -> void:
	if target_position == Vector2.ZERO or _parent_unit == null:
		return
	if _pathfinder == null:
		_pathfinder = _find_pathfinder()
		if _pathfinder == null:
			return

	var new_path: Array[Vector2] = _pathfinder.find_path_for_movement(
		_parent_unit.global_position, target_position
	)

	if not new_path.is_empty():
		path = new_path
		current_path_index = 0
		is_moving = true


## Check if the current path's next waypoint is still walkable.
func is_path_blocked_ahead() -> bool:
	if path.is_empty() or current_path_index >= path.size():
		return false
	if _pathfinder == null:
		return false
	var wp: Vector2 = path[current_path_index]
	var cell: Vector2i = _pathfinder._world_to_cell(wp) if _pathfinder.has_method("_world_to_cell") else Vector2i(-1, -1)
	if cell == Vector2i(-1, -1):
		return false
	return _pathfinder.is_cell_blocked(cell) if _pathfinder.has_method("is_cell_blocked") else false


func _calculate_separation() -> Vector2:
	if _parent_unit == null:
		return Vector2.ZERO

	var separation: Vector2 = Vector2.ZERO
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	var my_pos: Vector2 = _parent_unit.global_position

	for other: Node in all_units:
		if other == _parent_unit:
			continue
		if not other is Node2D:
			continue
		var other_pos: Vector2 = (other as Node2D).global_position
		var diff: Vector2 = my_pos - other_pos
		var dist: float = diff.length()
		if dist > SEPARATION_RADIUS or dist < 0.1:
			continue
		# Stronger push the closer the units are.
		var strength: float = 1.0 - (dist / SEPARATION_RADIUS)
		separation += diff.normalized() * SEPARATION_FORCE * strength

	return separation


func _get_terrain_multiplier() -> float:
	if _parent_unit == null:
		return 1.0
	if _grid_manager == null:
		return 1.0

	var cell: Vector2i = _grid_manager.get_cell_from_world(_parent_unit.global_position)
	var terrain_name: String = "grass"

	if _grid_manager.has_method("get_terrain_name"):
		terrain_name = _grid_manager.get_terrain_name(cell)
	elif _grid_manager.has_method("get_blocker"):
		var blocker: int = _grid_manager.get_blocker(cell)
		if blocker == 1:
			terrain_name = "water"
		elif blocker == 2:
			terrain_name = "mountain"
		elif blocker == 3:
			terrain_name = "water"
		else:
			terrain_name = "grass"

	return TERRAIN_SPEED_MULTIPLIERS.get(terrain_name, 1.0)


func _is_unit_ahead(move_direction: Vector2) -> bool:
	if _parent_unit == null:
		return false

	var space_state: PhysicsDirectSpaceState2D = _parent_unit.get_world_2d().direct_space_state
	if space_state == null:
		return false

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	query.from = _parent_unit.global_position
	query.to = _parent_unit.global_position + move_direction * AHEAD_CHECK_DISTANCE
	query.exclude = [_parent_unit]
	query.collision_mask = 1

	var result: Dictionary = space_state.intersect_ray(query)
	return not result.is_empty()


func _update_facing_visual(move_dir: Vector2) -> void:
	if _parent_unit == null:
		return
	var anim: Node = _parent_unit.get_node_or_null("UnitAnimationController")
	if anim != null and anim.has_method("set_facing"):
		anim.set_facing(move_dir)
	else:
		var sprite: Node = _parent_unit.get_node_or_null("AnimatedSprite2D")
		if sprite != null and sprite is AnimatedSprite2D:
			(sprite as AnimatedSprite2D).flip_h = move_dir.x < 0.0


func _spawn_walk_dust(delta: float) -> void:
	_dust_timer -= delta
	if _dust_timer > 0.0:
		return
	_dust_timer = DUST_INTERVAL
	var particle_manager: Node = _find_node_recursive(get_tree().current_scene, "ParticleEffects")
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect("dust_walk", _parent_unit.global_position + Vector2(0, 10), 3)
