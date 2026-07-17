## Formation system for coordinated group movement.
##
## Calculates formation positions for groups of units moving together.
## Supports multiple formation types with dynamic sizing based on group size.
class_name FormationSystem
extends Node

# =============================================================================
# Enums
# =============================================================================

enum FormationType {
	LINE,       ## Units arranged in a line perpendicular to movement direction.
	WEDGE,      ## V-shape pointing towards movement direction.
	SQUARE,     ## Grid arrangement.
	CIRCLE,     ## Circular arrangement around center.
	SCATTER,    ## Loose formation with randomized offsets.
	COLUMN,     ## Single file column.
}

# =============================================================================
# Configuration
# =============================================================================

## Base spacing between units in a formation (pixels).
@export var base_spacing: float = 48.0

## Maximum units per row in LINE/SQUARE formations.
@export var max_per_row: int = 10

## Random scatter offset range for SCATTER formation.
@export var scatter_range: float = 32.0

## Speed multiplier when in formation (0.0-1.0). Lower = slower for cohesion.
@export var formation_speed_factor: float = 0.85

# =============================================================================
# Signals
# =============================================================================

signal formation_calculated(group_id: int, positions: Dictionary)

# =============================================================================
# Internal State
# =============================================================================

## Active formations: group_id → { type, positions: {}, leader: Node2D, target: Vector2 }
var _formations: Dictionary = {}

## Group ID counter.
var _next_group_id: int = 0

# =============================================================================
# Public API
# =============================================================================

## Create a new formation group from a list of units. Returns group_id.
func create_formation(units: Array, formation_type: FormationType = FormationType.LINE, leader: Node2D = null) -> int:
	if units.is_empty():
		return -1

	var group_id: int = _next_group_id
	_next_group_id += 1

	# Use first selected unit or provided leader.
	if leader == null:
		for unit in units:
			if unit.get("is_selected") == true:
				leader = unit
				break
		if leader == null:
			leader = units[0]

	var positions: Dictionary = _calculate_positions(units, formation_type, leader.global_position)

	_formations[group_id] = {
		"type": formation_type,
		"positions": positions,
		"leader": leader,
		"target": leader.global_position,
		"units": units.duplicate(),
	}

	formation_calculated.emit(group_id, positions)
	return group_id


## Update formation positions as units move. Returns updated positions.
func update_formation(group_id: int, target_pos: Vector2) -> Dictionary:
	if not _formations.has(group_id):
		return {}

	var data: Dictionary = _formations[group_id]
	var units: Array = data["units"]
	var formation_type: FormationType = data["type"]
	var leader: Node2D = data["leader"]

	# Filter out dead/invalid units.
	var valid_units: Array = []
	for unit in units:
		if is_instance_valid(unit):
			valid_units.append(unit)

	if valid_units.is_empty():
		_formations.erase(group_id)
		return {}

	data["units"] = valid_units
	data["target"] = target_pos

	var positions: Dictionary = _calculate_positions(valid_units, formation_type, target_pos)
	data["positions"] = positions

	formation_calculated.emit(group_id, positions)
	return positions


## Get the target position for a specific unit in a formation.
func get_unit_target(group_id: int, unit) -> Vector2:
	if not _formations.has(group_id):
		return Vector2.ZERO

	var positions: Dictionary = _formations[group_id]["positions"]
	if positions.has(unit):
		return positions[unit]
	return Vector2.ZERO


## Remove a unit from a formation. Returns updated positions.
func remove_unit(group_id: int, unit) -> Dictionary:
	if not _formations.has(group_id):
		return {}

	var data: Dictionary = _formations[group_id]
	var units: Array = data["units"]
	var idx: int = units.find(unit)
	if idx >= 0:
		units.remove_at(idx)

	if units.is_empty():
		_formations.erase(group_id)
		return {}

	# Recalculate with remaining units.
	var positions: Dictionary = _calculate_positions(
		units, data["type"], data["target"]
	)
	data["positions"] = positions
	return positions


## Dissolve a formation group.
func dissolve_formation(group_id: int) -> void:
	_formations.erase(group_id)


## Get the formation type for a group.
func get_formation_type(group_id: int) -> FormationType:
	if _formations.has(group_id):
		return _formations[group_id]["type"]
	return FormationType.LINE


## Get the number of active formations.
func get_formation_count() -> int:
	return _formations.size()


## Get all active formation group IDs.
func get_active_groups() -> Array[int]:
	var result: Array[int] = []
	for group_id: int in _formations:
		result.append(group_id)
	return result


## Auto-select the best formation type based on army composition.
func auto_select_formation(units: Array) -> FormationType:
	if units.is_empty():
		return FormationType.LINE

	var melee_count: int = 0
	var ranged_count: int = 0
	var cavalry_count: int = 0

	for unit in units:
		var category: String = unit.get("unit_category", "")
		match category:
			"infantry":
				melee_count += 1
			"ranged":
				ranged_count += 1
			"cavalry":
				cavalry_count += 1

	var total: int = units.size()

	# Mostly cavalry → WEDGE for charge.
	if cavalry_count > total * 0.5:
		return FormationType.WEDGE

	# Mixed army → LINE for balanced approach.
	if ranged_count > 0 and melee_count > 0:
		return FormationType.LINE

	# Mostly ranged → SCATTER to avoid area damage.
	if ranged_count > total * 0.5:
		return FormationType.SCATTER

	# Mostly melee → SQUARE for dense combat.
	if melee_count > total * 0.5:
		return FormationType.SQUARE

	return FormationType.LINE


## Calculate formation speed (slowest unit determines group speed).
func get_formation_speed(group_id: int) -> float:
	if not _formations.has(group_id):
		return 0.0

	var units: Array = _formations[group_id]["units"]
	var min_speed: float = INF

	for unit in units:
		if is_instance_valid(unit):
			var move_comp = unit.get_node_or_null("MovementComponent")
			if move_comp != null:
				var speed: float = move_comp.get("base_speed")
				if speed < min_speed:
					min_speed = speed

	if min_speed == INF:
		return 80.0  # Default speed.

	return min_speed * formation_speed_factor

# =============================================================================
# Position Calculation
# =============================================================================

func _calculate_positions(units: Array, formation_type: FormationType, center: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var count: int = units.size()

	if count == 0:
		return positions

	# Calculate facing direction from center to target.
	var target: Vector2 = center
	if _formations.size() > 0:
		for group_id: int in _formations:
			if _formations[group_id]["units"] == units:
				target = _formations[group_id]["target"]
				break

	var direction: Vector2 = (target - center).normalized()
	if direction.length() < 0.01:
		direction = Vector2.RIGHT

	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)

	match formation_type:
		FormationType.LINE:
			positions = _calc_line(units, center, direction, perpendicular)
		FormationType.WEDGE:
			positions = _calc_wedge(units, center, direction, perpendicular)
		FormationType.SQUARE:
			positions = _calc_square(units, center, direction, perpendicular)
		FormationType.CIRCLE:
			positions = _calc_circle(units, center)
		FormationType.SCATTER:
			positions = _calc_scatter(units, center)
		FormationType.COLUMN:
			positions = _calc_column(units, center, direction)

	return positions


func _calc_line(units: Array, center: Vector2, dir: Vector2, perp: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var count: int = units.size()
	var rows: int = ceili(float(count) / float(max_per_row))
	var per_row: int = mini(count, max_per_row)

	for i in range(count):
		var row: int = i / max_per_row
		var col: int = i % max_per_row
		var row_offset: float = float(row) * base_spacing * 0.5
		var col_offset: float = (float(col) - float(per_row - 1) * 0.5) * base_spacing

		var offset: Vector2 = dir * row_offset + perp * col_offset
		positions[units[i]] = center + offset

	return positions


func _calc_wedge(units: Array, center: Vector2, dir: Vector2, perp: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var count: int = units.size()

	# Leader at the front.
	positions[units[0]] = center

	var row: int = 1
	var col: int = 0
	var side: int = 1  # +1 = right, -1 = left

	for i in range(1, count):
		var offset: Vector2 = dir * (float(row) * base_spacing * 0.7) + perp * (float(col) * base_spacing * side)
		positions[units[i]] = center + offset

		col += 1
		if col > row:
			row += 1
			col = 0
			side *= -1

	return positions


func _calc_square(units: Array, center: Vector2, dir: Vector2, perp: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var count: int = units.size()
	var side: int = ceili(sqrt(float(count)))

	for i in range(count):
		var row: int = i / side
		var col: int = i % side
		var row_offset: float = (float(row) - float(side - 1) * 0.5) * base_spacing
		var col_offset: float = (float(col) - float(side - 1) * 0.5) * base_spacing

		var offset: Vector2 = dir * row_offset + perp * col_offset
		positions[units[i]] = center + offset

	return positions


func _calc_circle(units: Array, center: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var count: int = units.size()

	if count == 1:
		positions[units[0]] = center
		return positions

	var radius: float = base_spacing * float(count) / TAU
	if radius < base_spacing:
		radius = base_spacing

	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius
		positions[units[i]] = center + offset

	return positions


func _calc_scatter(units: Array, center: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var count: int = units.size()

	for i in range(count):
		var offset: Vector2 = Vector2(
			randf_range(-scatter_range, scatter_range),
			randf_range(-scatter_range, scatter_range)
		)
		positions[units[i]] = center + offset

	return positions


func _calc_column(units: Array, center: Vector2, dir: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var count: int = units.size()

	for i in range(count):
		var offset: Vector2 = dir * (float(i) * base_spacing)
		positions[units[i]] = center + offset

	return positions
