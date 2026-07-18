extends Node

class_name MovementComponent

@export var max_speed: float = 100.0
@export var acceleration: float = 500.0
@export var deceleration: float = 800.0
@export var turn_speed: float = 5.0
@export var terrain_speed_multiplier: float = 1.0
@export var obstacle_slowdown: float = 0.5
@export var formation_offset: Vector2 = Vector2.ZERO

@signal movement_started(target_position: Vector2)
@signal movement_stopped()
@signal destination_reached()

var current_velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var use_formation: bool = false
var formation_type: String = "square"
var formation_index: int = 0
var formation_size: int = 1
var rally_point: Vector2 = Vector2.ZERO
var has_rally_point: bool = false

@onready var owner: CharacterBody2D = get_parent()

func _ready() -> void:
	if not owner.is_class("CharacterBody2D"):
		push_error("MovementComponent must be child of CharacterBody2D")
		return
	
	movement_started.connect(_on_movement_started.bind())
	movement_stopped.connect(_on_movement_stopped.bind())
	destination_reached.connect(_on_destination_reached.bind())

func _physics_process(delta: float) -> void:
	if not is_moving:
		return
	
	var target = _get_effective_target()
	var direction = (target - owner.global_position).normalized()
	var distance = owner.global_position.distance_to(target)
	
	if distance <= 5.0:
		_stop_movement()
		destination_reached.emit()
		return
	
	var target_velocity = direction * max_speed * terrain_speed_multiplier
	current_velocity = current_velocity.lerp(target_velocity, acceleration * delta / max_speed)
	
	var angle_to_target = direction.angle()
	var current_angle = current_velocity.angle()
	var angle_diff = lerp_angle(current_angle, angle_to_target, turn_speed * delta)
	current_velocity = current_velocity.rotated(angle_diff - current_angle).length() * Vector2.RIGHT.rotated(angle_diff)
	
	owner.velocity = current_velocity
	owner.move_and_slide()
	
	_emit_walking_dust(delta)

func _get_effective_target() -> Vector2:
	if use_formation and formation_size > 1:
		return target_position + _get_formation_offset()
	return target_position

func _get_formation_offset() -> Vector2:
	match formation_type:
		"line":
			return _get_line_formation_offset()
		"column":
			return _get_column_formation_offset()
		"square":
			return _get_square_formation_offset()
		_:
			return Vector2.ZERO

func _get_line_formation_offset() -> Vector2:
	var spacing = 30.0
	var row = formation_index
	var offset_x = (row - formation_size / 2.0 + 0.5) * spacing
	return Vector2(offset_x, 0).rotated(owner.global_position.angle_to_point(target_position))

func _get_column_formation_offset() -> Vector2:
	var spacing = 30.0
	var col = formation_index
	var offset_y = (col - formation_size / 2.0 + 0.5) * spacing
	return Vector2(0, offset_y).rotated(owner.global_position.angle_to_point(target_position))

func _get_square_formation_offset() -> Vector2:
	var spacing = 30.0
	var cols = ceil(sqrt(formation_size))
	var row = formation_index / cols
	var col = formation_index % cols
	var center_offset = (cols - 1) * 0.5
	var offset_x = (col - center_offset) * spacing
	var offset_y = (row - center_offset) * spacing
	return Vector2(offset_x, offset_y).rotated(owner.global_position.angle_to_point(target_position))

func move_to(position: Vector2, p_formation_type: String = "", p_formation_index: int = 0, p_formation_size: int = 1) -> void:
	target_position = position
	is_moving = true
	use_formation = p_formation_type != ""
	formation_type = p_formation_type
	formation_index = p_formation_index
	formation_size = p_formation_size
	movement_started.emit(position)

func move_to_rally_point() -> void:
	if has_rally_point:
		move_to(rally_point)

func set_rally_point(position: Vector2) -> void:
	rally_point = position
	has_rally_point = true

func clear_rally_point() -> void:
	has_rally_point = false
	rally_point = Vector2.ZERO

func stop() -> void:
	if is_moving:
		_stop_movement()
		movement_stopped.emit()

func _stop_movement() -> void:
	is_moving = false
	current_velocity = Vector2.ZERO
	owner.velocity = Vector2.ZERO

func _emit_walking_dust(delta: float) -> void:
	if current_velocity.length() > 10.0 and randf() < 0.1:
		EventBus.emit_walking_dust(owner.global_position, current_velocity.normalized())

func _on_movement_started(target: Vector2) -> void:
	pass

func _on_movement_stopped() -> void:
	pass

func _on_destination_reached() -> void:
	if has_rally_point and owner.global_position.distance_to(rally_point) > 10.0:
		move_to_rally_point()

func lerp_angle(from: float, to: float, weight: float) -> float:
	var diff = fmod(to - from + PI, TAU) - PI
	return from + diff * weight

func _get_terrain_speed_multiplier() -> float:
	return terrain_speed_multiplier

func _get_obstacle_slowdown() -> float:
	var space_state = owner.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(owner.global_position, owner.global_position + current_velocity.normalized() * 20.0)
	var result = space_state.intersect_ray(query)
	if result and result.collider.is_in_group("obstacles"):
		return obstacle_slowdown
	return 1.0