## Decorative World Animations
## Adds ambient life to the game world: tree sway, water animation,
## grass movement, cloud shadows, and bird flocks.
## Attach to the game world root node.
class_name DecorativeWorldAnimations
extends Node2D

# --- Signals ---
signal bird_flock_spawned(position: Vector2)
signal ambient_started
signal ambient_stopped

# --- Constants ---
const TREE_SWAY_RANGE: float = 1.0
const TREE_SWAY_SPEED: float = 0.8
const WATER_COLOR_SHIFT_SPEED: float = 1.5
const WATER_COLOR_RANGE: float = 0.05
const GRASS_MODULATE_RANGE: float = 0.08
const GRASS_SWAY_SPEED: float = 1.2
const CLOUD_SHADOW_SIZE: float = 200.0
const CLOUD_SHADOW_SPEED: float = 15.0
const CLOUD_SHADOW_ALPHA: float = 0.15
const CLOUD_SHADOW_COUNT: int = 3
const BIRD_FLOCK_MIN_INTERVAL: float = 30.0
const BIRD_FLOCK_MAX_INTERVAL: float = 60.0
const BIRD_FLOCK_SPEED: float = 80.0
const BIRD_COUNT_MIN: int = 3
const BIRD_COUNT_MAX: int = 7
const BIRD_SPACING: float = 12.0
const BIRD_V_FORM_ANGLE: float = 25.0
const MAX_TREE_SWAY_NODES: int = 200
const MAX_GRASS_NODES: int = 150
const AMBIENT_ANIMAL_COUNT: int = 18
const ANIMAL_SPEED_MIN: float = 8.0
const ANIMAL_SPEED_MAX: float = 18.0
const ANIMAL_WANDER_INTERVAL_MIN: float = 2.0
const ANIMAL_WANDER_INTERVAL_MAX: float = 6.0
const DAY_LENGTH_SECONDS: float = 240.0
const NIGHT_TINT: Color = Color(0.48, 0.58, 0.86, 1.0)
const DAY_TINT: Color = Color(1.0, 0.96, 0.86, 1.0)
const VISIBILITY_MARGIN: float = 100.0
const THROTTLE_FRAME_SKIP_Distant: int = 3
const THROTTLE_FRAME_SKIP_Close: int = 1

# --- Exported Properties ---
@export var enabled: bool = true
@export var ambient_intensity: float = 1.0
@export var tree_sway_enabled: bool = true
@export var water_animation_enabled: bool = true
@export var grass_animation_enabled: bool = true
@export var cloud_shadows_enabled: bool = true
@export var bird_flocks_enabled: bool = true
@export var animals_enabled: bool = true
@export var day_night_enabled: bool = true
@export var world_bounds: Rect2 = Rect2(-2000, -2000, 4000, 4000)

# --- Node References ---
var _camera: Camera2D = null
var _canvas_modulate: CanvasModulate = null

# --- Tree Sway Data ---
class TreeSwayData:
	var node: Node2D
	var original_x: float
	var speed_offset: float
	var phase_offset: float

var _tree_sway_nodes: Array[TreeSwayData] = []

# --- Water Animation Data ---
class WaterAnimData:
	var tile_map: TileMapLayer
	var original_colors: Array[Color]

var _water_nodes: Array[WaterAnimData] = []

# --- Grass Animation Data ---
class GrassAnimData:
	var node: Node2D
	var original_modulate: Color
	var speed_offset: float
	var phase_offset: float

var _grass_nodes: Array[GrassAnimData] = []

# --- Cloud Shadows ---
var _cloud_shadows: Array[Node2D] = []
var _cloud_shadow_directions: Array[Vector2] = []

# --- Bird Flocks ---
var _bird_timer: float = 0.0
var _next_bird_interval: float = 45.0
var _active_bird_flocks: Array[Array] = []

class AmbientAnimalData:
	var node: Node2D
	var direction: Vector2 = Vector2.RIGHT
	var speed: float = 10.0
	var wander_timer: float = 1.0
	var phase_offset: float = 0.0

var _ambient_animals: Array[AmbientAnimalData] = []

# --- Animation State ---
var _elapsed_time: float = 0.0
var _frame_counter: int = 0
var _is_active: bool = false


## --- Lifecycle ---

func _ready() -> void:
	_find_camera()
	_register_tree_nodes()
	_register_water_nodes()
	_register_grass_nodes()
	_create_cloud_shadows()
	_create_day_night_overlay()
	_create_ambient_animals()
	_reset_bird_timer()


func _process(delta: float) -> void:
	if not enabled or not _is_active:
		return
	_elapsed_time += delta
	_frame_counter += 1
	# Update each system with throttling
	if tree_sway_enabled:
		_update_tree_sway(delta)
	if water_animation_enabled:
		_update_water_animation(delta)
	if grass_animation_enabled:
		_update_grass_animation(delta)
	if cloud_shadows_enabled:
		_update_cloud_shadows(delta)
	if bird_flocks_enabled:
		_update_bird_flocks(delta)
	if animals_enabled:
		_update_ambient_animals(delta)
	if day_night_enabled:
		_update_day_night()


## --- Public API ---

## Start all ambient animations.
func start_ambient() -> void:
	_is_active = true
	visible = true
	ambient_started.emit()


## Stop all ambient animations.
func stop_ambient() -> void:
	_is_active = false
	visible = false
	ambient_stopped.emit()


## Set ambient intensity (0.0 to 1.0). Affects animation magnitude.
func set_ambient_intensity(level: float) -> void:
	ambient_intensity = clampf(level, 0.0, 1.0)
	# Scale tree sway and grass
	for data in _tree_sway_nodes:
		data.node.visible = ambient_intensity > 0.0
	for data in _grass_nodes:
		data.node.visible = ambient_intensity > 0.0
	for shadow in _cloud_shadows:
		shadow.modulate.a = CLOUD_SHADOW_ALPHA * ambient_intensity
	for animal_data in _ambient_animals:
		if is_instance_valid(animal_data.node):
			animal_data.node.visible = ambient_intensity > 0.15


## Manually trigger a bird flock at a position.
func trigger_bird_flock(start_position: Vector2 = Vector2.ZERO) -> void:
	_spawn_bird_flock(start_position)


## Refresh registered nodes (call after world generation).
func refresh_world_nodes() -> void:
	_tree_sway_nodes.clear()
	_water_nodes.clear()
	_grass_nodes.clear()
	_register_tree_nodes()
	_register_water_nodes()
	_register_grass_nodes()
	_create_cloud_shadows()
	_create_ambient_animals()


## --- Tree Sway ---

func _register_tree_nodes() -> void:
	# Find all nodes with "tree" or "Tree" in their name under the world
	_scan_for_nodes(get_tree().current_scene, "tree", _tree_sway_nodes, MAX_TREE_SWAY_NODES)


func _scan_for_nodes(root: Node, keyword: String, result_array: Array, max_count: int) -> void:
	if result_array.size() >= max_count:
		return
	for child in root.get_children():
		if result_array.size() >= max_count:
			return
		if child is Node2D and child.name.to_lower().contains(keyword):
			var data: TreeSwayData = TreeSwayData.new()
			data.node = child
			data.original_x = child.position.x
			data.speed_offset = randf_range(0.8, 1.2)
			data.phase_offset = randf_range(0.0, TAU)
			result_array.append(data)
		_scan_for_nodes(child, keyword, result_array, max_count)


func _update_tree_sway(delta: float) -> void:
	if _tree_sway_nodes.is_empty():
		return
	var intensity: float = ambient_intensity
	for data in _tree_sway_nodes:
		if not is_instance_valid(data.node):
			continue
		# Throttle distant trees
		if _is_distant(data.node.global_position):
			if _frame_counter % THROTTLE_FRAME_SKIP_Distant != 0:
				continue
		else:
			if _frame_counter % THROTTLE_FRAME_SKIP_Close != 0:
				continue
		var sway: float = sin(_elapsed_time * TREE_SWAY_SPEED * data.speed_offset + data.phase_offset)
		data.node.position.x = data.original_x + sway * TREE_SWAY_RANGE * intensity


## --- Water Animation ---

func _register_water_nodes() -> void:
	# Look for TileMapLayer nodes with "water" in name
	_scan_for_water(get_tree().current_scene)


func _scan_for_water(root: Node) -> void:
	for child in root.get_children():
		if child is TileMapLayer and child.name.to_lower().contains("water"):
			var data: WaterAnimData = WaterAnimData.new()
			data.tile_map = child
			_water_nodes.append(data)
		_scan_for_water(child)


func _update_water_animation(delta: float) -> void:
	if _water_nodes.is_empty():
		return
	var intensity: float = ambient_intensity
	for data in _water_nodes:
		if not is_instance_valid(data.tile_map):
			continue
		# Animate the modulate color with a slight blue shift
		var shift: float = sin(_elapsed_time * WATER_COLOR_SHIFT_SPEED) * WATER_COLOR_RANGE * intensity
		data.tile_map.modulate = Color(
			0.9 + shift * 0.5,
			0.95 + shift,
			1.0,
			1.0
		)


## --- Grass Animation ---

func _register_grass_nodes() -> void:
	_scan_for_nodes(get_tree().current_scene, "grass", _grass_nodes, MAX_GRASS_NODES)


func _scan_for_grass_nodes(root: Node) -> void:
	for child in root.get_children():
		if _grass_nodes.size() >= MAX_GRASS_NODES:
			return
		if child is Node2D and child.name.to_lower().contains("grass"):
			var data: GrassAnimData = GrassAnimData.new()
			data.node = child
			data.original_modulate = child.modulate
			data.speed_offset = randf_range(0.7, 1.3)
			data.phase_offset = randf_range(0.0, TAU)
			_grass_nodes.append(data)
		_scan_for_grass_nodes(child)


func _update_grass_animation(delta: float) -> void:
	if _grass_nodes.is_empty():
		return
	var intensity: float = ambient_intensity
	for data in _grass_nodes:
		if not is_instance_valid(data.node):
			continue
		if _is_distant(data.node.global_position):
			if _frame_counter % THROTTLE_FRAME_SKIP_Distant != 0:
				continue
		else:
			if _frame_counter % THROTTLE_FRAME_SKIP_Close != 0:
				continue
		var wave: float = sin(_elapsed_time * GRASS_SWAY_SPEED * data.speed_offset + data.phase_offset)
		var green_shift: float = wave * GRASS_MODULATE_RANGE * intensity
		data.node.modulate = Color(
			data.original_modulate.r,
			data.original_modulate.g + green_shift,
			data.original_modulate.b,
			data.original_modulate.a
		)


## --- Cloud Shadows ---

func _create_cloud_shadows() -> void:
	# Clear existing
	for shadow in _cloud_shadows:
		if is_instance_valid(shadow):
			shadow.queue_free()
	_cloud_shadows.clear()
	_cloud_shadow_directions.clear()
	# Create large semi-transparent circles
	for i in CLOUD_SHADOW_COUNT:
		var shadow: Node2D = Node2D.new()
		shadow.name = "CloudShadow_%d" % i
		# Draw a circle using a ColorRect scaled up
		var circle: ColorRect = ColorRect.new()
		circle.name = "ShadowCircle"
		circle.size = Vector2(CLOUD_SHADOW_SIZE, CLOUD_SHADOW_SIZE * 0.6)
		circle.position = -circle.size * 0.5
		circle.color = Color(0, 0, 0, CLOUD_SHADOW_ALPHA)
		# Round corners via clip or just use the rect
		shadow.add_child(circle)
		shadow.z_index = -5
		# Random start position within world bounds
		shadow.global_position = Vector2(
			randf_range(world_bounds.position.x, world_bounds.end.x),
			randf_range(world_bounds.position.y, world_bounds.end.y)
		)
		add_child(shadow)
		_cloud_shadows.append(shadow)
		# Random direction
		_cloud_shadow_directions.append(Vector2(
			randf_range(-1, 1), randf_range(-0.3, 0.3)
		).normalized())


func _update_cloud_shadows(delta: float) -> void:
	for i in _cloud_shadows.size():
		if not is_instance_valid(_cloud_shadows[i]):
			continue
		var shadow: Node2D = _cloud_shadows[i]
		var dir: Vector2 = _cloud_shadow_directions[i]
		shadow.global_position += dir * CLOUD_SHADOW_SPEED * delta * ambient_intensity
		# Wrap around world bounds
		shadow.global_position.x = wrapf(
			shadow.global_position.x,
			world_bounds.position.x - CLOUD_SHADOW_SIZE,
			world_bounds.end.x + CLOUD_SHADOW_SIZE
		)
		shadow.global_position.y = wrapf(
			shadow.global_position.y,
			world_bounds.position.y - CLOUD_SHADOW_SIZE,
			world_bounds.end.y + CLOUD_SHADOW_SIZE
		)


## --- Bird Flocks ---

func _reset_bird_timer() -> void:
	_next_bird_interval = randf_range(BIRD_FLOCK_MIN_INTERVAL, BIRD_FLOCK_MAX_INTERVAL)
	_bird_timer = _next_bird_interval


func _update_bird_flocks(delta: float) -> void:
	# Update existing flocks
	var i: int = _active_bird_flocks.size() - 1
	while i >= 0:
		var flock: Array = _active_bird_flocks[i]
		var all_dead: bool = true
		for bird in flock:
			if is_instance_valid(bird):
				all_dead = false
				break
		if all_dead:
			_active_bird_flocks.remove_at(i)
		i -= 1
	# Spawn new flocks
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_spawn_bird_flock()
		_reset_bird_timer()


func _spawn_bird_flock(start_pos: Vector2 = Vector2.ZERO) -> void:
	var bird_count: int = randi_range(BIRD_COUNT_MIN, BIRD_COUNT_MAX)
	# Pick a random screen-edge starting position
	if start_pos == Vector2.ZERO:
		var edge: int = randi() % 4
		match edge:
			0:  # Left
				start_pos = Vector2(
					_get_camera_view().position.x - 100,
					randf_range(_get_camera_view().position.y - 300, _get_camera_view().position.y + 300)
				)
			1:  # Right
				start_pos = Vector2(
					_get_camera_view().end.x + 100,
					randf_range(_get_camera_view().position.y - 300, _get_camera_view().position.y + 300)
				)
			2:  # Top
				start_pos = Vector2(
					randf_range(_get_camera_view().position.x - 300, _get_camera_view().end.x + 300),
					_get_camera_view().position.y - 100
				)
			3:  # Bottom
				start_pos = Vector2(
					randf_range(_get_camera_view().position.x - 300, _get_camera_view().end.x + 300),
					_get_camera_view().end.y + 100
				)
	# Direction across screen
	var direction: Vector2 = Vector2(
		randf_range(-1, 1),
		randf_range(-0.5, 0.5)
	).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var flock_birds: Array = []
	# Create V-formation birds
	for j in bird_count:
		var bird_node: Node2D = _create_bird_sprite()
		# V-formation offset
		var side: float = 1.0 if j % 2 == 0 else -1.0
		var rank: float = float(j) / 2.0
		var offset: Vector2 = Vector2(
			-rank * BIRD_SPACING * 0.5,
			side * rank * BIRD_SPACING * sin(deg_to_rad(BIRD_V_FORM_ANGLE))
		)
		bird_node.position = start_pos + offset
		bird_node.rotation = direction.angle()
		# Move the bird
		var move_tween: Tween = create_tween()
		var travel_distance: float = 1500.0
		var travel_time: float = travel_distance / BIRD_FLOCK_SPEED
		move_tween.tween_property(
			bird_node, "position",
			bird_node.position + direction * travel_distance,
			travel_time
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)
		move_tween.tween_callback(bird_node.queue_free)
		# Wing flap animation (small scale tween)
		var flap_tween: Tween = create_tween().set_loops()
		flap_tween.tween_property(bird_node, "scale:y", 0.6, 0.15).set_trans(Tween.TRANS_SINE)
		flap_tween.tween_property(bird_node, "scale:y", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
		add_child(bird_node)
		flock_birds.append(bird_node)
	_active_bird_flocks.append(flock_birds)
	bird_flock_spawned.emit(start_pos)


func _create_bird_sprite() -> Node2D:
	var bird: Node2D = Node2D.new()
	bird.name = "Bird"
	# Create a simple V-shape bird using two lines (ColorRects)
	var left_wing: ColorRect = ColorRect.new()
	left_wing.name = "LeftWing"
	left_wing.size = Vector2(6, 2)
	left_wing.position = Vector2(-3, -1)
	left_wing.color = Color(0.15, 0.15, 0.15)
	left_wing.rotation = deg_to_rad(-20)
	bird.add_child(left_wing)
	var right_wing: ColorRect = ColorRect.new()
	right_wing.name = "RightWing"
	right_wing.size = Vector2(6, 2)
	right_wing.position = Vector2(-3, 1)
	right_wing.color = Color(0.15, 0.15, 0.15)
	right_wing.rotation = deg_to_rad(20)
	bird.add_child(right_wing)
	# Body dot
	var body: ColorRect = ColorRect.new()
	body.name = "Body"
	body.size = Vector2(3, 2)
	body.position = Vector2(-1, -1)
	body.color = Color(0.2, 0.2, 0.2)
	bird.add_child(body)
	return bird


## --- Ambient Animals ---

func _create_ambient_animals() -> void:
	for data in _ambient_animals:
		if is_instance_valid(data.node):
			data.node.queue_free()
	_ambient_animals.clear()
	if not animals_enabled:
		return
	for i in range(AMBIENT_ANIMAL_COUNT):
		var animal: Node2D = _create_animal_sprite(i)
		animal.name = "AmbientAnimal_%d" % i
		animal.z_index = 2
		animal.global_position = Vector2(
			randf_range(world_bounds.position.x, world_bounds.end.x),
			randf_range(world_bounds.position.y, world_bounds.end.y)
		)
		add_child(animal)

		var data: AmbientAnimalData = AmbientAnimalData.new()
		data.node = animal
		data.direction = Vector2(randf_range(-1.0, 1.0), randf_range(-0.4, 0.4)).normalized()
		if data.direction == Vector2.ZERO:
			data.direction = Vector2.RIGHT
		data.speed = randf_range(ANIMAL_SPEED_MIN, ANIMAL_SPEED_MAX)
		data.wander_timer = randf_range(ANIMAL_WANDER_INTERVAL_MIN, ANIMAL_WANDER_INTERVAL_MAX)
		data.phase_offset = randf_range(0.0, TAU)
		_ambient_animals.append(data)


func _create_animal_sprite(index: int) -> Node2D:
	var animal: Node2D = Node2D.new()
	var body: ColorRect = ColorRect.new()
	body.name = "Body"
	body.size = Vector2(8, 5)
	body.position = Vector2(-4, -3)
	body.color = Color(0.34, 0.25, 0.16) if index % 3 != 0 else Color(0.72, 0.68, 0.54)
	animal.add_child(body)

	var head: ColorRect = ColorRect.new()
	head.name = "Head"
	head.size = Vector2(4, 4)
	head.position = Vector2(3, -4)
	head.color = body.color.lightened(0.08)
	animal.add_child(head)

	var leg_a: ColorRect = ColorRect.new()
	leg_a.name = "LegA"
	leg_a.size = Vector2(2, 3)
	leg_a.position = Vector2(-3, 1)
	leg_a.color = body.color.darkened(0.25)
	animal.add_child(leg_a)

	var leg_b: ColorRect = ColorRect.new()
	leg_b.name = "LegB"
	leg_b.size = Vector2(2, 3)
	leg_b.position = Vector2(2, 1)
	leg_b.color = body.color.darkened(0.25)
	animal.add_child(leg_b)
	return animal


func _update_ambient_animals(delta: float) -> void:
	for data in _ambient_animals:
		if not is_instance_valid(data.node):
			continue
		if _is_distant(data.node.global_position):
			if _frame_counter % THROTTLE_FRAME_SKIP_Distant != 0:
				continue
		data.wander_timer -= delta
		if data.wander_timer <= 0.0:
			data.wander_timer = randf_range(ANIMAL_WANDER_INTERVAL_MIN, ANIMAL_WANDER_INTERVAL_MAX)
			data.direction = Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)).normalized()
			if data.direction == Vector2.ZERO:
				data.direction = Vector2.RIGHT

		data.node.global_position += data.direction * data.speed * delta * ambient_intensity
		data.node.global_position.x = wrapf(data.node.global_position.x, world_bounds.position.x, world_bounds.end.x)
		data.node.global_position.y = wrapf(data.node.global_position.y, world_bounds.position.y, world_bounds.end.y)
		data.node.scale.x = -1.0 if data.direction.x < 0.0 else 1.0
		var bob: float = sin(_elapsed_time * 6.0 + data.phase_offset) * 0.8
		var body: Node = data.node.get_node_or_null("Body")
		if body is Control:
			body.position.y = -3.0 + bob


## --- Day / Night ---

func _create_day_night_overlay() -> void:
	if _canvas_modulate != null:
		return
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "DayNightTint"
	_canvas_modulate.color = DAY_TINT
	add_child(_canvas_modulate)


func _update_day_night() -> void:
	if _canvas_modulate == null:
		return
	var cycle: float = fmod(_elapsed_time, DAY_LENGTH_SECONDS) / DAY_LENGTH_SECONDS
	var night_amount: float = clampf((sin(cycle * TAU - PI * 0.5) + 1.0) * 0.5, 0.0, 1.0)
	night_amount = smoothstep(0.35, 0.95, night_amount)
	_canvas_modulate.color = DAY_TINT.lerp(NIGHT_TINT, night_amount * 0.48)


## --- Utility ---

## Check if a world position is far from the camera.
func _is_distant(pos: Vector2) -> bool:
	if not _camera:
		return false
	var cam_center: Vector2 = _camera.global_position
	var dist: float = pos.distance_to(cam_center)
	return dist > 800.0


## Get the visible viewport rect in world coordinates.
func _get_camera_view() -> Rect2:
	if _camera:
		var viewport_size: Vector2 = _camera.get_viewport_rect().size
		var cam_pos: Vector2 = _camera.global_position
		var zoom: Vector2 = _camera.zoom
		return Rect2(
			cam_pos - viewport_size / (2.0 * zoom),
			viewport_size / zoom
		)
	return Rect2(-1000, -1000, 2000, 2000)


func _find_camera() -> void:
	# Try to find the active camera in the scene
	if get_viewport():
		_camera = get_viewport().get_camera_2d()
