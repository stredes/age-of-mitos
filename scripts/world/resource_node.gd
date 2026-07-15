## Physical resource node placed on the world map.
##
## Attach to a Node2D (or Area2D) that represents a harvestable resource.
## Villagers interact with these to gather wood, stone, food, or gold.
## Handles depletion, regrowth for food, visual feedback, and EventBus integration.
class_name ResourceNode
extends Node2D

# =============================================================================
# Signals
# =============================================================================

## Emitted when the resource amount changes (harvest or regrow).
## [param current: int] New remaining amount.
## [param max_amount: int] Maximum amount.
signal resource_changed(current: int, max_amount: int)

## Emitted when the resource is fully depleted.
signal resource_depleted_signal()

## Emitted when food regrows.
signal resource_regrown(current: int)

# =============================================================================
# Exports
# =============================================================================

## The type of resource this node provides.
@export var resource_type: String = "wood":
	set(value):
		resource_type = value
		_update_visual()

## Maximum amount this node can hold.
@export var max_amount: int = 100:
	set(value):
		max_amount = value
		current_amount = mini(current_amount, max_amount)
		_update_visual()

## Current harvestable amount remaining.
@export var current_amount: int = 100:
	set(value):
		current_amount = clampi(value, 0, max_amount)
		_update_visual()

## Grid cell position in the world.
@export var grid_pos: Vector2i = Vector2i.ZERO

## Harvest amount per villager action.
@export var harvest_per_action: int = 10

## Regrow rate for food resources (amount restored per regrow tick).
@export var regrow_rate: int = 1

## Time in seconds between regrow ticks (food only).
@export var regrow_interval: float = 30.0

## Radius around the node for villager proximity detection.
@export var interaction_radius: float = 48.0

# =============================================================================
# Properties
# =============================================================================

## Visual components.
var _sprite_rect: ColorRect = null
var _amount_label: Label = null
var _selection_ring: Node2D = null
var _visual_time: float = 0.0

## Regrow timer for food.
var _regrow_timer: float = 0.0

## Whether this node is fully depleted.
var _is_depleted: bool = false

## Unique world ID for EventBus communication.
var _world_id: int = -1

## Color palette per resource type.
const RESOURCE_COLORS: Dictionary = {
	"wood": Color(0.3, 0.65, 0.2),
	"stone": Color(0.55, 0.52, 0.5),
	"food": Color(0.85, 0.3, 0.25),
	"gold": Color(0.95, 0.82, 0.15),
}

## Depleted color (grey/faded).
const DEPLETED_COLOR: Color = Color(0.35, 0.35, 0.35, 0.5)

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_build_visual()
	_update_visual()
	_world_id = _generate_world_id()


func _process(delta: float) -> void:
	_visual_time += delta
	queue_redraw()
	if resource_type == "food" and not _is_depleted and current_amount < max_amount:
		_regrow_timer += delta
		if _regrow_timer >= regrow_interval:
			_regrow_timer = 0.0
			_regrow()

# =============================================================================
# Public API
# =============================================================================

## Harvest resources from this node. Returns the actual amount harvested.
## [param amount: int] Requested amount to harvest.
## [return] The amount actually taken (may be less if nearly depleted).
func harvest(amount: int) -> int:
	if _is_depleted:
		return 0
	var actual: int = mini(amount, current_amount)
	current_amount -= actual
	_update_visual()

	if current_amount <= 0:
		_deplete()

	resource_changed.emit(current_amount, max_amount)

	# Notify the global event bus.
	EventBus.resource_collected.emit(resource_type, actual, -1, GameManager.get_local_player_id())

	return actual


## Check whether this resource node is fully depleted.
func is_depleted() -> bool:
	return _is_depleted


## Get the resource type string.
func get_resource_type() -> String:
	return resource_type


## Get the current remaining amount.
func get_current_amount() -> int:
	return current_amount


## Get the maximum amount.
func get_max_amount() -> int:
	return max_amount


## Get the grid position in world cells.
func get_grid_pos() -> Vector2i:
	return grid_pos


## Set the grid position in world cells.
func set_grid_pos(pos: Vector2i) -> void:
	grid_pos = pos


## Get the unique world ID for this node.
func get_world_id() -> int:
	return _world_id


## Set the world ID (used when loading from WorldData).
func set_world_id(id: int) -> void:
	_world_id = id


## Initialize this node from a WorldData resource node dictionary.
func initialize_from_data(data: Dictionary) -> void:
	resource_type = data.get("type", "wood")
	grid_pos = data.get("grid_pos", Vector2i.ZERO)
	max_amount = data.get("max_amount", 100)
	current_amount = data.get("amount", max_amount)
	_update_visual()


## Get proximity radius for villager interaction checks.
func get_interaction_radius() -> float:
	return interaction_radius


## Check if a world position is within interaction range.
func is_in_range(world_position: Vector2) -> bool:
	return position.distance_to(world_position) <= interaction_radius


## Set the node's world position from its grid position.
## [param cell_size: int] Pixels per grid cell (default 32).
func update_world_position(cell_size: int = 32) -> void:
	position = Vector2(
		float(grid_pos.x * cell_size + cell_size / 2),
		float(grid_pos.y * cell_size + cell_size / 2)
	)

# =============================================================================
# Depletion
# =============================================================================

func _deplete() -> void:
	_is_depleted = true
	_update_visual()
	resource_depleted_signal.emit()
	EventBus.resource_depleted.emit(_world_id, resource_type)

# =============================================================================
# Regrowth (Food Only)
# =============================================================================

func _regrow() -> void:
	if resource_type != "food":
		return
	if _is_depleted:
		# Revive depleted food bushes.
		_is_depleted = false
		current_amount = maxi(regrow_rate, 1)
		_update_visual()
		EventBus.resource_depleted.emit(_world_id, "")
		return

	var new_amount: int = mini(current_amount + regrow_rate, max_amount)
	if new_amount != current_amount:
		current_amount = new_amount
		_update_visual()
		resource_regrown.emit(current_amount)
		resource_changed.emit(current_amount, max_amount)

# =============================================================================
# Visual
# =============================================================================

func _build_visual() -> void:
	# Amount label.
	_amount_label = Label.new()
	_amount_label.name = "AmountLabel"
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_amount_label.size = Vector2(32, 16)
	_amount_label.position = Vector2(-16, 12)
	_amount_label.add_theme_font_size_override("font_size", 9)
	_amount_label.add_theme_color_override("font_color", Color.WHITE)
	_amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_amount_label.add_theme_constant_override("shadow_offset_x", 1)
	_amount_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_amount_label)

	# Selection ring (hidden by default).
	_selection_ring = Node2D.new()
	_selection_ring.name = "SelectionRing"
	_selection_ring.visible = false
	add_child(_selection_ring)


func _update_visual() -> void:
	var ratio: float = float(current_amount) / float(max_amount) if max_amount > 0 else 0.0

	# Update amount label.
	if _amount_label != null:
		if _is_depleted:
			_amount_label.text = ""
		else:
			_amount_label.text = str(current_amount)
	queue_redraw()


func set_selected(selected: bool) -> void:
	if _selection_ring != null:
		_selection_ring.visible = selected
	queue_redraw()


func _draw() -> void:
	var ratio: float = float(current_amount) / float(max_amount) if max_amount > 0 else 0.0
	var alpha: float = 0.35 if _is_depleted else 1.0
	var sway: float = sin(_visual_time * 1.4 + float(grid_pos.x + grid_pos.y)) * 1.5
	draw_circle(Vector2(0, 9), 12.0, Color(0, 0, 0, 0.18 * alpha))

	match resource_type:
		"wood":
			var trunk_color: Color = Color(0.35, 0.19, 0.08, alpha)
			var leaf_color: Color = Color(0.12, 0.45 + ratio * 0.18, 0.14, alpha)
			draw_rect(Rect2(Vector2(-3, -2), Vector2(6, 16)), trunk_color)
			draw_circle(Vector2(sway, -10), 11.0, leaf_color)
			draw_circle(Vector2(-7 + sway, -4), 8.0, leaf_color.darkened(0.08))
			draw_circle(Vector2(7 + sway, -4), 8.0, leaf_color.lightened(0.06))
		"stone":
			var rock_color: Color = Color(0.50, 0.50, 0.48, alpha)
			draw_polygon(
				PackedVector2Array([Vector2(-14, 7), Vector2(-8, -7), Vector2(5, -12), Vector2(15, -1), Vector2(11, 10), Vector2(-5, 13)]),
				PackedColorArray([rock_color, rock_color.lightened(0.12), rock_color.lightened(0.20), rock_color, rock_color.darkened(0.14), rock_color.darkened(0.08)])
			)
			draw_line(Vector2(-7, -5), Vector2(2, 9), Color(0.25, 0.25, 0.24, alpha), 2.0)
		"food":
			var bush_color: Color = Color(0.10, 0.48 + ratio * 0.10, 0.13, alpha)
			draw_circle(Vector2(-7 + sway * 0.3, 0), 8.0, bush_color)
			draw_circle(Vector2(3 + sway * 0.3, -4), 10.0, bush_color.lightened(0.06))
			draw_circle(Vector2(9 + sway * 0.3, 2), 7.0, bush_color.darkened(0.04))
			for berry in [Vector2(-5, -2), Vector2(4, -7), Vector2(8, 1), Vector2(0, 3)]:
				draw_circle(berry + Vector2(sway * 0.3, 0), 2.0, Color(0.86, 0.12, 0.10, alpha))
		"gold":
			var gold_color: Color = Color(0.95, 0.74 + ratio * 0.12, 0.14, alpha)
			draw_polygon(
				PackedVector2Array([Vector2(-12, 8), Vector2(-5, -8), Vector2(8, -10), Vector2(15, 5), Vector2(4, 12)]),
				PackedColorArray([gold_color.darkened(0.16), gold_color.lightened(0.18), gold_color, gold_color.darkened(0.08), gold_color.darkened(0.20)])
			)
			draw_line(Vector2(-4, -5), Vector2(8, 5), Color(1.0, 0.95, 0.45, alpha), 2.0)
		_:
			draw_circle(Vector2.ZERO, 10.0, RESOURCE_COLORS.get(resource_type, Color.MAGENTA))

	# Draw selection ring when selected.
	if _selection_ring != null and _selection_ring.visible:
		draw_circle(Vector2.ZERO, 18.0, Color(1.0, 1.0, 1.0, 0.3))
		draw_arc(Vector2.ZERO, 18.0, 0, TAU, 64, Color(1.0, 1.0, 0.5, 0.8), 2.0)

# =============================================================================
# Helpers
# =============================================================================

func _generate_world_id() -> int:
	# Simple hash from grid position and type.
	var hash_val: int = grid_pos.x * 73856093 + grid_pos.y * 19349669
	for c: String in resource_type:
		hash_val += c.unicode_at(0) * 83492791
	return absi(hash_val) % 100000000
