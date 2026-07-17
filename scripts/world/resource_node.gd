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
var _depletion_scale: float = 1.0
var _depletion_alpha: float = 1.0

## Regrow timer for food.
var _regrow_timer: float = 0.0

## Whether this node is fully depleted.
var _is_depleted: bool = false

## Unique world ID for EventBus communication.
var _world_id: int = -1

## Visual variant (determines tree shape, rock form, etc.).
var _visual_variant: int = 0

## Color palette per resource type.
const RESOURCE_COLORS: Dictionary = {
	"wood": Color(0.3, 0.65, 0.2),
	"stone": Color(0.55, 0.52, 0.5),
	"food": Color(0.85, 0.3, 0.25),
	"gold": Color(0.95, 0.82, 0.15),
}

## Depleted color (grey/faded).
const DEPLETED_COLOR: Color = Color(0.35, 0.35, 0.35, 0.5)

## Depletion animation speed.
const DEPLETION_SPEED: float = 2.5

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_visual_variant = (grid_pos.x * 7 + grid_pos.y * 13 + resource_type.length()) % 5
	_build_visual()
	_update_visual()
	_world_id = _generate_world_id()


func _process(delta: float) -> void:
	_visual_time += delta

	# Smooth depletion animation.
	if _is_depleted:
		_depletion_scale = move_toward(_depletion_scale, 0.55, DEPLETION_SPEED * delta)
		_depletion_alpha = move_toward(_depletion_alpha, 0.35, DEPLETION_SPEED * delta)
	else:
		_depletion_scale = move_toward(_depletion_scale, 1.0, DEPLETION_SPEED * delta)
		_depletion_alpha = move_toward(_depletion_alpha, 1.0, DEPLETION_SPEED * delta)

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


## Find the nearest drop-off building for a given resource type and player.
## Returns the nearest building that can accept this resource type.
## [param resource_type: String] The type of resource to drop off.
## [param player_id: int] The player ID to find buildings for.
## [return] Node2D or null if no valid drop-off building found.
func find_nearest_drop_off(resource_type: String, player_id: int) -> Node2D:
	var drop_off_types: Array[String] = []
	match resource_type:
		"wood":
			drop_off_types = ["lumber_camp", "town_center"]
		"stone", "gold":
			drop_off_types = ["mine", "town_center"]
		"food":
			drop_off_types = ["mill", "town_center"]
		_:
			drop_off_types = ["town_center"]

	var best: Node2D = null
	var best_dist: float = INF
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	var candidates: Array[Node] = []
	_find_drop_off_buildings_recursive(scene, candidates, drop_off_types, player_id)

	for node: Node in candidates:
		if node is Node2D:
			var bld: Node2D = node as Node2D
			var dist: float = position.distance_to(bld.global_position)
			if dist < best_dist:
				best_dist = dist
				best = bld

	return best


func _find_drop_off_buildings_recursive(node: Node, results: Array[Node], building_types: Array[String], player_id: int) -> void:
	var node_building_type: String = ""
	if node.has_method("get_building_type"):
		node_building_type = node.get_building_type()
	elif node.get("building_type") != null:
		node_building_type = node.get("building_type")

	if node_building_type in building_types:
		var bld_player: int = node.get("player_id") if node.has_method("get") and node.get("player_id") != null else -2
		if bld_player == player_id or player_id == -1:
			results.append(node)

	for child: Node in node.get_children():
		_find_drop_off_buildings_recursive(child, results, building_types, player_id)


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
	var alpha: float = _depletion_alpha
	var sway: float = sin(_visual_time * 1.4 + float(grid_pos.x + grid_pos.y)) * 1.5
	var sc: float = _depletion_scale

	# Shadow beneath resource.
	draw_circle(Vector2(0, 9 * sc), 12.0 * sc, Color(0, 0, 0, 0.18 * alpha))

	match resource_type:
		"wood":
			_draw_tree(ratio, alpha, sway, sc)
		"stone":
			_draw_stone(ratio, alpha, sc)
		"food":
			_draw_food_bush(ratio, alpha, sway, sc)
		"gold":
			_draw_gold(ratio, alpha, sc)
		_:
			draw_circle(Vector2.ZERO, 10.0 * sc, RESOURCE_COLORS.get(resource_type, Color.MAGENTA))

	# Draw selection ring when selected.
	if _selection_ring != null and _selection_ring.visible:
		draw_circle(Vector2.ZERO, 18.0, Color(1.0, 1.0, 1.0, 0.3))
		draw_arc(Vector2.ZERO, 18.0, 0, TAU, 64, Color(1.0, 1.0, 0.5, 0.8), 2.0)


func _draw_tree(ratio: float, alpha: float, sway: float, sc: float) -> void:
	var trunk_color: Color = Color(0.35, 0.19, 0.08, alpha)
	var leaf_color: Color = Color(0.12, 0.45 + ratio * 0.18, 0.14, alpha)

	# Variant determines tree shape.
	match _visual_variant:
		0:  # Round canopy tree.
			draw_rect(Rect2(Vector2(-2.5 * sc, -2 * sc), Vector2(5 * sc, 14 * sc)), trunk_color)
			draw_circle(Vector2(sway * sc, -10 * sc), 10.0 * sc, leaf_color)
			draw_circle(Vector2(-6 * sc + sway * sc, -4 * sc), 7.0 * sc, leaf_color.darkened(0.08))
			draw_circle(Vector2(6 * sc + sway * sc, -4 * sc), 7.0 * sc, leaf_color.lightened(0.06))
		1:  # Tall narrow tree.
			draw_rect(Rect2(Vector2(-2 * sc, -1 * sc), Vector2(4 * sc, 16 * sc)), trunk_color)
			draw_circle(Vector2(sway * sc, -12 * sc), 8.0 * sc, leaf_color)
			draw_circle(Vector2(-4 * sc + sway * sc, -7 * sc), 6.0 * sc, leaf_color.darkened(0.06))
			draw_circle(Vector2(4 * sc + sway * sc, -7 * sc), 6.0 * sc, leaf_color.lightened(0.04))
		2:  # Wide bushy tree.
			draw_rect(Rect2(Vector2(-3 * sc, -2 * sc), Vector2(6 * sc, 15 * sc)), trunk_color)
			draw_circle(Vector2(-8 * sc + sway * sc, -6 * sc), 9.0 * sc, leaf_color.darkened(0.04))
			draw_circle(Vector2(0, -11 * sc), 11.0 * sc, leaf_color)
			draw_circle(Vector2(8 * sc + sway * sc, -6 * sc), 9.0 * sc, leaf_color.lightened(0.06))
		3:  # Pine-like.
			draw_rect(Rect2(Vector2(-2 * sc, 0), Vector2(4 * sc, 13 * sc)), trunk_color)
			draw_circle(Vector2(sway * sc * 0.5, -10 * sc), 7.0 * sc, leaf_color.darkened(0.04))
			draw_circle(Vector2(sway * sc * 0.3, -6 * sc), 9.0 * sc, leaf_color)
		_:  # Default round.
			draw_rect(Rect2(Vector2(-3 * sc, -2 * sc), Vector2(6 * sc, 16 * sc)), trunk_color)
			draw_circle(Vector2(sway, -10 * sc), 11.0 * sc, leaf_color)
			draw_circle(Vector2(-7 * sc + sway, -4 * sc), 8.0 * sc, leaf_color.darkened(0.08))
			draw_circle(Vector2(7 * sc + sway, -4 * sc), 8.0 * sc, leaf_color.lightened(0.06))


func _draw_stone(ratio: float, alpha: float, sc: float) -> void:
	var rock_color: Color = Color(0.50, 0.50, 0.48, alpha)
	match _visual_variant:
		0:  # Large boulder.
			draw_polygon(
				PackedVector2Array([
					Vector2(-14 * sc, 7 * sc), Vector2(-8 * sc, -7 * sc),
					Vector2(5 * sc, -12 * sc), Vector2(15 * sc, -1 * sc),
					Vector2(11 * sc, 10 * sc), Vector2(-5 * sc, 13 * sc)
				]),
				PackedColorArray([rock_color, rock_color.lightened(0.12), rock_color.lightened(0.20), rock_color, rock_color.darkened(0.14), rock_color.darkened(0.08)])
			)
			draw_line(Vector2(-7 * sc, -5 * sc), Vector2(2 * sc, 9 * sc), Color(0.25, 0.25, 0.24, alpha), 2.0 * sc)
		1:  # Medium flat rock.
			draw_polygon(
				PackedVector2Array([
					Vector2(-12 * sc, 8 * sc), Vector2(-6 * sc, -5 * sc),
					Vector2(7 * sc, -7 * sc), Vector2(13 * sc, 3 * sc),
					Vector2(8 * sc, 11 * sc), Vector2(-3 * sc, 12 * sc)
				]),
				PackedColorArray([rock_color.darkened(0.06), rock_color.lightened(0.10), rock_color.lightened(0.16), rock_color, rock_color.darkened(0.10), rock_color.darkened(0.04)])
			)
		_:  # Small rocks.
			draw_polygon(
				PackedVector2Array([
					Vector2(-10 * sc, 7 * sc), Vector2(-4 * sc, -6 * sc),
					Vector2(6 * sc, -8 * sc), Vector2(12 * sc, 2 * sc),
					Vector2(5 * sc, 10 * sc)
				]),
				PackedColorArray([rock_color, rock_color.lightened(0.14), rock_color.lightened(0.22), rock_color, rock_color.darkened(0.12)])
			)


func _draw_food_bush(ratio: float, alpha: float, sway: float, sc: float) -> void:
	var bush_color: Color = Color(0.10, 0.48 + ratio * 0.10, 0.13, alpha)
	var berry_color: Color = Color(0.86, 0.12, 0.10, alpha)
	var sw: float = sway * 0.3

	match _visual_variant:
		0:  # Round bush with berries.
			draw_circle(Vector2(-7 * sc + sw, 0), 8.0 * sc, bush_color)
			draw_circle(Vector2(3 * sc + sw, -4 * sc), 10.0 * sc, bush_color.lightened(0.06))
			draw_circle(Vector2(9 * sc + sw, 2 * sc), 7.0 * sc, bush_color.darkened(0.04))
			for berry in [Vector2(-5, -2), Vector2(4, -7), Vector2(8, 1), Vector2(0, 3)]:
				draw_circle(berry * sc + Vector2(sw, 0), 2.0 * sc, berry_color)
		1:  # Low spreading bush.
			draw_circle(Vector2(-8 * sc + sw, 2 * sc), 7.0 * sc, bush_color.darkened(0.04))
			draw_circle(Vector2(0, -2 * sc + sw * 0.5), 9.0 * sc, bush_color)
			draw_circle(Vector2(8 * sc + sw, 2 * sc), 7.0 * sc, bush_color.lightened(0.04))
			for berry in [Vector2(-6, 0), Vector2(2, -5), Vector2(7, 1), Vector2(-2, 4)]:
				draw_circle(berry * sc + Vector2(sw, 0), 1.8 * sc, berry_color)
		_:  # Tall bush.
			draw_circle(Vector2(-5 * sc + sw, -3 * sc), 9.0 * sc, bush_color)
			draw_circle(Vector2(4 * sc + sw, -6 * sc), 11.0 * sc, bush_color.lightened(0.06))
			draw_circle(Vector2(7 * sc + sw, 0), 7.0 * sc, bush_color.darkened(0.06))
			for berry in [Vector2(-4, -5), Vector2(3, -9), Vector2(8, -2), Vector2(-1, 0)]:
				draw_circle(berry * sc + Vector2(sw, 0), 2.2 * sc, berry_color)


func _draw_gold(ratio: float, alpha: float, sc: float) -> void:
	var gold_color: Color = Color(0.95, 0.74 + ratio * 0.12, 0.14, alpha)
	match _visual_variant:
		0:  # Large gold nugget.
			draw_polygon(
				PackedVector2Array([
					Vector2(-12 * sc, 8 * sc), Vector2(-5 * sc, -8 * sc),
					Vector2(8 * sc, -10 * sc), Vector2(15 * sc, 5 * sc),
					Vector2(4 * sc, 12 * sc)
				]),
				PackedColorArray([gold_color.darkened(0.16), gold_color.lightened(0.18), gold_color, gold_color.darkened(0.08), gold_color.darkened(0.20)])
			)
			draw_line(Vector2(-4 * sc, -5 * sc), Vector2(8 * sc, 5 * sc), Color(1.0, 0.95, 0.45, alpha), 2.0 * sc)
		_:  # Gold vein / small nuggets.
			draw_polygon(
				PackedVector2Array([
					Vector2(-10 * sc, 7 * sc), Vector2(-3 * sc, -6 * sc),
					Vector2(9 * sc, -7 * sc), Vector2(13 * sc, 4 * sc),
					Vector2(3 * sc, 10 * sc)
				]),
				PackedColorArray([gold_color.darkened(0.12), gold_color.lightened(0.14), gold_color, gold_color.darkened(0.06), gold_color.darkened(0.16)])
			)
			draw_line(Vector2(-3 * sc, -4 * sc), Vector2(7 * sc, 4 * sc), Color(1.0, 0.95, 0.45, alpha), 1.5 * sc)
			# Sparkle.
			var sparkle_alpha: float = (sin(_visual_time * 3.0 + float(grid_pos.x)) * 0.5 + 0.5) * alpha
			draw_circle(Vector2(5 * sc, -3 * sc), 2.0 * sc, Color(1.0, 1.0, 0.7, sparkle_alpha * 0.6))

# =============================================================================
# Helpers
# =============================================================================

func _generate_world_id() -> int:
	# Simple hash from grid position and type.
	var hash_val: int = grid_pos.x * 73856093 + grid_pos.y * 19349669
	for c: String in resource_type:
		hash_val += c.unicode_at(0) * 83492791
	return absi(hash_val) % 100000000
