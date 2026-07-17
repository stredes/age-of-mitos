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
@export var separation_radius: float = 18.0
@export var separation_strength: float = 80.0
@export var arrival_radius: float = 48.0

var speed: float = 100.0
var target_position: Vector2 = Vector2.ZERO
var path: Array[Vector2] = []
var current_path_index: int = 0
var is_moving: bool = false
var facing: Vector2 = Vector2.RIGHT
var current_velocity: Vector2 = Vector2.ZERO
var formation_offset: Vector2 = Vector2.ZERO

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
const SEPARATION_CHECK_INTERVAL: float = 0.1
const PATH_RECALC_INTERVAL: float = 1.0
const DUST_INTERVAL: float = 0.28

var _pathfinder: Node = null
var _grid_manager: Node = null
var _parent_unit: Node2D = null
var _blocked_timer: float = 0.0
var _recalc_timer: float = 0.0
var _separation_timer: float = 0.0
var _dust_timer: float = 0.0
var _last_known_target: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
const STUCK_THRESHOLD: float = 4.0
const STUCK_TIME: float = 1.5


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


func move_to(world_position: Vector2, formation_offset: Vector2 = Vector2.ZERO) -> void:
	if _parent_unit == null:
		return
	if _pathfinder == null:
		_pathfinder = _find_pathfinder()
		if _pathfinder == null:
			movement_failed.emit()
			return

	target_position = world_position
	formation_offset = formation_offset
	_last_known_target = world_position
	_stuck_timer = 0.0
	_last_position = _parent_unit.global_position

	var raw_path: Array[Vector2] = _pathfinder.find_path_for_movement(_parent_unit.global_position, world_position)

	if raw_path.is_empty():
		if _parent_unit.global_position.distance_to(world_position) < ARRIVAL_THRESHOLD * 4.0:
			path.append(world_position)
		else:
			movement_failed.emit()
			return

	path = _smooth_path(raw_path)
	current_path_index = 0
	is_moving = true
	movement_started.emit()


func _smooth_path(raw_path: Array[Vector2]) -> Array[Vector2]:
	if raw_path.size() <= 2:
		return raw_path

	var smoothed: Array[Vector2] = [raw_path[0]]
	for i in range(1, raw_path.size() - 1):
		var prev: Vector2 = raw_path[i - 1]
		var curr: Vector2 = raw_path[i]
		var next: Vector2 = raw_path[i + 1]

		var dir1: Vector2 = (curr - prev).normalized()
		var dir2: Vector2 = (next - curr).normalized()
		var angle: float = dir1.angle_to(dir2)

		if abs(angle) < 0.3:
			smoothed.append(curr)
		else:
			var mid: Vector2 = curr.lerp(next, 0.5)
			smoothed.append(curr)
			smoothed.append(mid)

	smoothed.append(raw_path[-1])
	return smoothed


func _process(delta: float) -> void:
	if not is_moving or _parent_unit == null:
		return
	move_along_path(delta)


func move_along_path(delta: float) -> void:
	if path.is_empty() or current_path_index >= path.size():
		_arrive()
		return

	var next_point: Vector2 = path[current_path_index] + formation_offset
	var direction: Vector2 = next_point - _parent_unit.global_position
	var distance: float = direction.length()

	if distance < ARRIVAL_THRESHOLD:
		current_path_index += 1
		if current_path_index >= path.size():
			_arrive()
		return

	_check_stuck(delta)

	var move_dir: Vector2 = direction.normalized()
	var speed_mult: float = _get_terrain_multiplier()
	var desired_speed: float = speed * speed_mult

	desired_speed = _apply_separation(desired_speed, move_dir, delta)

	if _is_unit_ahead(move_dir):
		_blocked_timer += delta
		if _blocked_timer > 0.5:
			desired_speed *= BLOCKED_SLOWDOWN
	else:
		_blocked_timer = 0.0

	if distance < arrival_radius:
		desired_speed *= clampf(distance / arrival_radius, 0.15, 1.0)

	var desired_velocity: Vector2 = move_dir * desired_speed
	var rate: float = acceleration if desired_velocity.length_squared() > current_velocity.length_squared() else deceleration
	current_velocity = current_velocity.move_toward(desired_velocity, rate * delta)

	var movement: Vector2 = current_velocity * delta
	_parent_unit.global_position += movement

	facing = facing.lerp(move_dir, clampf(turn_smoothing * delta, 0.0, 1.0)).normalized()
	_parent_unit.facing = move_dir

	_update_facing_visual(facing)
	_spawn_walk_dust(delta)

	_recalc_timer += delta
	if _recalc_timer >= PATH_RECALC_INTERVAL and current_path_index < path.size() - 1:
		_recalc_timer = 0.0
		_maybe_recalculate_path()


func _apply_separation(base_speed: float, move_dir: Vector2, delta: float) -> float:
	_separation_timer += delta
	if _separation_timer < SEPARATION_CHECK_INTERVAL:
		return base_speed
	_separation_timer = 0.0

	if _parent_unit == null:
		return base_speed

	var space_state: PhysicsDirectSpaceState2D = _parent_unit.get_world_2d().direct_space_state
	if space_state == null:
		return base_speed

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = separation_radius
	query.shape_rid = shape.get_rid()
	query.transform = Transform2D.IDENTITY.translated(_parent_unit.global_position)
	query.collision_mask = 1
	query.exclude = [_parent_unit.get_rid()]

	var collisions: Array = space_state.intersect_shape(query, 10)
	var separation_force: Vector2 = Vector2.ZERO

	for collision: Dictionary in collisions:
		var collider: Node2D = collision.get_collider()
		if collider == null or not collider.is_in_group("units"):
			continue
		if collider == _parent_unit:
			continue

		var to_other: Vector2 = (collider.global_position - _parent_unit.global_position).normalized()
		var dist: float = _parent_unit.global_position.distance_to(collider.global_position)
		if dist < separation_radius and dist > 0.1:
			separation_force += -to_other * (1.0 - dist / separation_radius)

	if separation_force.length() > 0.0:
		separation_force = separation_force.normalized() * separation_strength
		var current_pos: Vector2 = _parent_unit.global_position
		_parent_unit.global_position += separation_force * delta

		var anim: Node = _parent_unit.get_node_or_null("UnitAnimationController")
		if anim != null and anim.has_method("play_state"):
			anim.play_state("idle")

		return base_speed * 0.5

	return base_speed


func _check_stuck(delta: float) -> void:
	if _parent_unit == null:
		return

	var dist_moved: float = _parent_unit.global_position.distance_to(_last_position)
	if dist_moved < STUCK_THRESHOLD:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0

	_last_position = _parent_unit.global_position

	if _stuck_timer > STUCK_TIME:
		_stuck_timer = 0.0
		if target_position != Vector2.ZERO and _last_known_target != Vector2.ZERO:
			move_to(target_position, formation_offset)


func _maybe_recalculate_path() -> void:
	if _pathfinder == null or _parent_unit == null:
		return

	var remaining_path: Array[Vector2] = path.slice(current_path_index)
	if remaining_path.is_empty():
		return

	var current_pos: Vector2 = _parent_unit.global_position
	var next_wp: Vector2 = remaining_path[0]
	var dist_to_next: float = current_pos.distance_to(next_wp)

	if dist_to_next > 80.0:
		var new_path: Array[Vector2] = _pathfinder.find_path_for_movement(current_pos, target_position)
		if not new_path.is_empty():
			new_path = _smooth_path(new_path)
			path = new_path
			current_path_index = 0


func _arrive() -> void:
	is_moving = false
	path.clear()
	current_path_index = 0
	current_velocity = Vector2.ZERO
	formation_offset = Vector2.ZERO
	movement_completed.emit()


func stop() -> void:
	is_moving = false
	path.clear()
	current_path_index = 0
	_blocked_timer = 0.0
	current_velocity = Vector2.ZERO
	formation_offset = Vector2.ZERO


func get_facing_direction() -> Vector2:
	return facing


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


func set_formation_offset(offset: Vector2) -> void:
	formation_offset = offset