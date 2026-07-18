extends Node

class_name FormationManager

@export var default_spacing: float = 32.0
@export var min_spacing: float = 24.0
@export var max_spacing: float = 48.0
@export var formation_rotation_speed: float = 3.0

signal formation_changed(formation_type: String, unit_count: int)

enum FormationType {
	SQUARE = "square",
	LINE = "line",
	COLUMN = "column",
	DISPERSED = "dispersed",
	WEDGE = "wedge",
	FLANK = "flank"
}

var current_formation: String = "square"
var _cached_offsets: Dictionary = {}

func _ready() -> void:
	_cache_common_formations()

func _cache_common_formations() -> void:
	for i in range(1, 51):
		_get_formation_offsets("square", i)
		_get_formation_offsets("line", i)
		_get_formation_offsets("column", i)
		_get_formation_offsets("dispersed", i)

func get_formation_type() -> String:
	return current_formation

func set_formation_type(formation_type: String) -> void:
	if formation_type in ["square", "line", "column", "dispersed", "wedge", "flank"]:
		current_formation = formation_type
	else:
		current_formation = "square"

func cycle_formation() -> void:
	var formations: Array[String] = ["square", "line", "column", "dispersed", "wedge", "flank"]
	var current_index: int = formations.find(current_formation)
	var next_index: int = (current_index + 1) % formations.size()
	current_formation = formations[next_index]

func get_formation_offsets(unit_count: int, target_position: Vector2, center_position: Vector2 = Vector2.ZERO, facing_direction: Vector2 = Vector2.RIGHT) -> Array[Vector2]:
	var offsets: Array[Vector2] = _get_formation_offsets(current_formation, unit_count)
	var direction: Vector2 = (target_position - center_position).normalized() if center_position != target_position else facing_direction
	var angle: float = direction.angle()
	
	var rotated_offsets: Array[Vector2] = []
	for offset in offsets:
		rotated_offsets.append(offset.rotated(angle))
	
	return rotated_offsets

func _get_formation_offsets(formation_type: String, unit_count: int) -> Array[Vector2]:
	var cache_key: String = "%s_%d" % [formation_type, unit_count]
	if _cached_offsets.has(cache_key):
		return _cached_offsets[cache_key]
	
	var offsets: Array[Vector2] = []
	
	match formation_type:
		"square":
			offsets = _calculate_square_formation(unit_count)
		"line":
			offsets = _calculate_line_formation(unit_count)
		"column":
			offsets = _calculate_column_formation(unit_count)
		"dispersed":
			offsets = _calculate_dispersed_formation(unit_count)
		"wedge":
			offsets = _calculate_wedge_formation(unit_count)
		"flank":
			offsets = _calculate_flank_formation(unit_count)
		_:
			offsets = _calculate_square_formation(unit_count)
	
	_cached_offsets[cache_key] = offsets
	return offsets

func _calculate_square_formation(unit_count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if unit_count <= 0:
		return offsets
	
	var cols: int = maxi(ceil(sqrt(unit_count)), 1)
	var rows: int = maxi(ceil(float(unit_count) / float(cols)), 1)
	var spacing: float = default_spacing
	
	var center_x: float = (cols - 1) * spacing * 0.5
	var center_y: float = (rows - 1) * spacing * 0.5
	
	var index: int = 0
	for row in range(rows):
		for col in range(cols):
			if index >= unit_count:
				break
			var offset_x: float = (col * spacing) - center_x
			var offset_y: float = (row * spacing) - center_y
			offsets.append(Vector2(offset_x, offset_y))
			index += 1
	
	return offsets

func _calculate_line_formation(unit_count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if unit_count <= 0:
		return offsets
	
	var spacing: float = default_spacing
	var center_offset: float = (unit_count - 1) * spacing * 0.5
	
	for i in range(unit_count):
		var offset_x: float = (i * spacing) - center_offset
		offsets.append(Vector2(offset_x, 0.0))
	
	return offsets

func _calculate_column_formation(unit_count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if unit_count <= 0:
		return offsets
	
	var spacing: float = default_spacing
	var center_offset: float = (unit_count - 1) * spacing * 0.5
	
	for i in range(unit_count):
		var offset_y: float = (i * spacing) - center_offset
		offsets.append(Vector2(0.0, offset_y))
	
	return offsets

func _calculate_dispersed_formation(unit_count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if unit_count <= 0:
		return offsets
	
	var radius: float = default_spacing * sqrt(unit_count) * 0.6
	var golden_angle: float = TAU * (3.0 - sqrt(5.0))
	
	for i in range(unit_count):
		var r: float = radius * sqrt(float(i) / float(unit_count))
		var theta: float = float(i) * golden_angle
		var offset_x: float = r * cos(theta)
		var offset_y: float = r * sin(theta)
		offsets.append(Vector2(offset_x, offset_y))
	
	return offsets

func _calculate_wedge_formation(unit_count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if unit_count <= 0:
		return offsets
	
	var spacing: float = default_spacing
	var row: int = 0
	var units_in_row: int = 1
	var placed: int = 0
	
	while placed < unit_count:
		var row_center: float = (units_in_row - 1) * spacing * 0.5
		for i in range(units_in_row):
			if placed >= unit_count:
				break
			var offset_x: float = (i * spacing) - row_center
			var offset_y: float = row * spacing * 1.2
			offsets.append(Vector2(offset_x, -offset_y))
			placed += 1
		row += 1
		units_in_row += 1
	
	return offsets

func _calculate_flank_formation(unit_count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if unit_count <= 0:
		return offsets
	
	var spacing: float = default_spacing
	var half: int = unit_count / 2
	var left_count: int = half
	var right_count: int = unit_count - half
	
	for i in range(left_count):
		var offset_x: float = -(i + 1) * spacing * 1.5
		var offset_y: float = randf_range(-spacing * 0.3, spacing * 0.3)
		offsets.append(Vector2(offset_x, offset_y))
	
	for i in range(right_count):
		var offset_x: float = (i + 1) * spacing * 1.5
		var offset_y: float = randf_range(-spacing * 0.3, spacing * 0.3)
		offsets.append(Vector2(offset_x, offset_y))
	
	return offsets

func apply_formation_to_units(units: Array[Node2D], target_position: Vector2, center_position: Vector2 = Vector2.ZERO, facing_direction: Vector2 = Vector2.RIGHT) -> void:
	if units.is_empty():
		return
	
	var offsets: Array[Vector2] = get_formation_offsets(units.size(), target_position, center_position, facing_direction)
	
	for i in range(units.size()):
		var unit: Node2D = units[i]
		if not is_instance_valid(unit):
			continue
		
		var movement: Node = unit.get_node_or_null("MovementComponent")
		if movement and movement.has_method("move_to"):
			var formation_target: Vector2 = target_position + offsets[i]
			movement.move_to(formation_target, current_formation, i, units.size())
		else:
			unit.set("pending_move_position", target_position + offsets[i])
			var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
			if state_machine and state_machine.has_method("change_state"):
				state_machine.change_state("MoveState")

func get_formation_bounds(unit_count: int) -> Rect2:
	var offsets: Array[Vector2] = _get_formation_offsets(current_formation, unit_count)
	if offsets.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	
	for offset in offsets:
		min_x = min(min_x, offset.x)
		max_x = max(max_x, offset.x)
		min_y = min(min_y, offset.y)
		max_y = max(max_y, offset.y)
	
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func get_optimal_spacing(unit_count: int) -> float:
	if unit_count <= 4:
		return default_spacing
	elif unit_count <= 12:
		return default_spacing * 0.9
	elif unit_count <= 24:
		return default_spacing * 0.8
	else:
		return max(min_spacing, default_spacing * 0.7)

func is_valid_formation(formation_type: String) -> bool:
	return formation_type in ["square", "line", "column", "dispersed", "wedge", "flank"]

func get_all_formations() -> Array[String]:
	return ["square", "line", "column", "dispersed", "wedge", "flank"]

func get_formation_name(formation_type: String) -> String:
	match formation_type:
		"square": return "Cuadrado"
		"line": return "Línea"
		"column": return "Columna"
		"dispersed": return "Disperso"
		"wedge": return "Cuña"
		"flank": return "Flanco"
		_: return "Cuadrado"