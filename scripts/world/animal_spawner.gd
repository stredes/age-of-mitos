## Ambient animal spawner for living world effects.
##
## Spawns deer, wolves, birds, and other animals that roam the map.
## Animals have simple AI: wander, flee from units, and respawn when killed.
class_name AnimalSpawner
extends Node

# =============================================================================
# Signals
# =============================================================================

signal animal_spawned(animal_id: int, animal_type: String, position: Vector2)
signal animal_died(animal_id: int, animal_type: String, position: Vector2)

# =============================================================================
# Enums
# =============================================================================

enum AnimalType {
	DEER,       ## Passive, flees from units, can be hunted for food.
	WOLF,       ## Aggressive, attacks isolated units.
	BIRD,       ## Visual only, flies across map.
	RABBIT,     ## Fast, passive, flees quickly.
	FISH,       ## In water only, visual effect.
}

# =============================================================================
# Configuration
# =============================================================================

## Maximum animals per type on the map.
@export var max_per_type: Dictionary = {
	"deer": 8,
	"wolf": 4,
	"bird": 12,
	"rabbit": 6,
	"fish": 10,
}

## Spawn interval per type (seconds).
@export var spawn_intervals: Dictionary = {
	"deer": 30.0,
	"wolf": 45.0,
	"bird": 10.0,
	"rabbit": 20.0,
	"fish": 60.0,
}

## Animal stats: { type: { hp, speed, food_value, flee_range, aggro_range } }
@export var animal_stats: Dictionary = {
	"deer": {
		"hp": 30,
		"speed": 100,
		"food_value": 40,
		"flee_range": 200.0,
		"aggro_range": 0.0,
		"color": Color(0.6, 0.4, 0.2),
		"size": 12.0,
	},
	"wolf": {
		"hp": 50,
		"speed": 90,
		"food_value": 30,
		"flee_range": 0.0,
		"aggro_range": 150.0,
		"color": Color(0.4, 0.4, 0.4),
		"size": 14.0,
	},
	"bird": {
		"hp": 5,
		"speed": 150,
		"food_value": 0,
		"flee_range": 100.0,
		"aggro_range": 0.0,
		"color": Color(0.2, 0.2, 0.2),
		"size": 6.0,
	},
	"rabbit": {
		"hp": 10,
		"speed": 140,
		"food_value": 15,
		"flee_range": 250.0,
		"aggro_range": 0.0,
		"color": Color(0.5, 0.35, 0.2),
		"size": 8.0,
	},
	"fish": {
		"hp": 10,
		"speed": 60,
		"food_value": 20,
		"flee_range": 0.0,
		"aggro_range": 0.0,
		"color": Color(0.3, 0.5, 0.7),
		"size": 10.0,
	},
}

## Minimum distance between animals of same type.
@export var min_spawn_distance: float = 150.0

## Distance from camera to stop spawning (optimization).
@export var spawn_radius: float = 800.0

## Despawn distance from camera (animals disappear when too far).
@export var despawn_radius: float = 1200.0

# =============================================================================
# Internal State
# =============================================================================

## Active animals: animal_id → { type, node, position, hp, state, wander_target }
var _animals: Dictionary = {}
var _next_animal_id: int = 0

## Spawn timers per type.
var _spawn_timers: Dictionary = {}

## Reference to camera for distance checks.
var _camera: Node2D = null

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_initialize_timers()
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)


func _process(delta: float) -> void:
	if GameManager.is_paused() or GameManager.is_game_over():
		return

	_update_spawn_timers(delta)
	_update_animals(delta)
	_check_despawn()

# =============================================================================
# Initialization
# =============================================================================

func _on_game_started(_player_id: int) -> void:
	_animals.clear()
	_next_animal_id = 0
	_initialize_timers()
	_find_camera()
	_spawn_initial_animals()


func _initialize_timers() -> void:
	for animal_type: String in spawn_intervals:
		_spawn_timers[animal_type] = randf_range(0.0, spawn_intervals[animal_type])


func _find_camera() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_camera = scene.get_node_or_null("CameraController")


func _spawn_initial_animals() -> void:
	for animal_type: String in max_per_type:
		var target_count: int = maxi(max_per_type[animal_type] / 2, 1)
		for _i in range(target_count):
			_spawn_animal(animal_type)

# =============================================================================
# Spawning
# =============================================================================

func _update_spawn_timers(delta: float) -> void:
	for animal_type: String in _spawn_timers:
		_spawn_timers[animal_type] -= delta
		if _spawn_timers[animal_type] <= 0.0:
			_spawn_timers[animal_type] = spawn_intervals.get(animal_type, 30.0)
			_try_spawn(animal_type)


func _try_spawn(animal_type: String) -> void:
	var current_count: int = _get_type_count(animal_type)
	var max_count: int = max_per_type.get(animal_type, 10)

	if current_count >= max_count:
		return

	# Only spawn near camera.
	var camera_pos: Vector2 = _get_camera_position()
	var angle: float = randf() * TAU
	var dist: float = randf_range(200.0, spawn_radius)
	var spawn_pos: Vector2 = camera_pos + Vector2.from_angle(angle) * dist

	# Check minimum distance from other animals of same type.
	if not _check_min_distance(spawn_pos, animal_type):
		return

	_spawn_animal(animal_type, spawn_pos)


func _spawn_animal(animal_type: String, position: Vector2 = Vector2.ZERO) -> void:
	if position == Vector2.ZERO:
		position = _get_random_spawn_position()

	var stats: Dictionary = animal_stats.get(animal_type, animal_stats["deer"])
	var animal_id: int = _next_animal_id
	_next_animal_id += 1

	# Create animal node.
	var animal: Node2D = _create_animal_node(animal_type, stats, position)

	_animals[animal_id] = {
		"type": animal_type,
		"node": animal,
		"position": position,
		"hp": stats["hp"],
		"max_hp": stats["hp"],
		"state": "wander",
		"wander_target": position,
		"wander_timer": randf_range(2.0, 5.0),
		"flee_target": Vector2.ZERO,
	}

	animal_spawned.emit(animal_id, animal_type, position)


func _create_animal_node(animal_type: String, stats: Dictionary, position: Vector2) -> Node2D:
	var animal: Node2D = Node2D.new()
	animal.name = "Animal_%s_%d" % [animal_type, _next_animal_id]
	animal.global_position = position
	animal.set_meta("animal_type", animal_type)
	animal.set_meta("is_animal", true)
	add_child(animal)
	return animal

# =============================================================================
# Animal AI
# =============================================================================

func _update_animals(delta: float) -> void:
	var camera_pos: Vector2 = _get_camera_position()

	for animal_id: int in _animals.keys():
		var data: Dictionary = _animals[animal_id]
		var node: Node2D = data["node"]

		if not is_instance_valid(node):
			_animals.erase(animal_id)
			continue

		var stats: Dictionary = animal_stats.get(data["type"], animal_stats["deer"])
		var pos: Vector2 = node.global_position

		# Only update animals near camera.
		if pos.distance_to(camera_pos) > despawn_radius:
			continue

		match data["state"]:
			"wander":
				_update_wander(animal_id, data, stats, delta)
			"flee":
				_update_flee(animal_id, data, stats, delta)
			"attack":
				_update_attack(animal_id, data, stats, delta)

		data["position"] = node.global_position


func _update_wander(animal_id: int, data: Dictionary, stats: Dictionary, delta: float) -> void:
	var node: Node2D = data["node"]
	var pos: Vector2 = node.global_position

	# Check for nearby units to flee or attack.
	var nearby_unit: Node2D = _find_nearest_unit(pos, 300.0)
	if nearby_unit != null:
		var dist: float = pos.distance_to(nearby_unit.global_position)
		var flee_range: float = stats.get("flee_range", 0.0)
		var aggro_range: float = stats.get("aggro_range", 0.0)

		if flee_range > 0.0 and dist < flee_range:
			data["state"] = "flee"
			data["flee_target"] = pos + (pos - nearby_unit.global_position).normalized() * 200.0
			return

		if aggro_range > 0.0 and dist < aggro_range:
			data["state"] = "attack"
			data["attack_target"] = nearby_unit
			return

	# Wander movement.
	data["wander_timer"] -= delta
	if data["wander_timer"] <= 0.0:
		var angle: float = randf() * TAU
		var dist: float = randf_range(50.0, 150.0)
		data["wander_target"] = pos + Vector2.from_angle(angle) * dist
		data["wander_timer"] = randf_range(3.0, 8.0)

	var move_dir: Vector2 = (data["wander_target"] - pos).normalized()
	var speed: float = stats.get("speed", 80.0)
	node.global_position += move_dir * speed * delta

	# Keep within map bounds.
	node.global_position = _clamp_to_map(node.global_position)


func _update_flee(animal_id: int, data: Dictionary, stats: Dictionary, delta: float) -> void:
	var node: Node2D = data["node"]
	var pos: Vector2 = node.global_position
	var target: Vector2 = data["flee_target"]

	var move_dir: Vector2 = (target - pos).normalized()
	var speed: float = stats.get("speed", 80.0) * 1.3  # Flee faster.
	node.global_position += move_dir * speed * delta

	# Reached flee target or unit is far enough.
	if pos.distance_to(target) < 20.0:
		data["state"] = "wander"
		data["wander_timer"] = 0.0


func _update_attack(animal_id: int, data: Dictionary, stats: Dictionary, delta: float) -> void:
	var node: Node2D = data["node"]
	var pos: Vector2 = node.global_position
	var target: Node2D = data.get("attack_target", null)

	if not is_instance_valid(target):
		data["state"] = "wander"
		return

	var target_pos: Vector2 = target.global_position
	var dist: float = pos.distance_to(target_pos)

	# Lost aggro.
	if dist > stats.get("aggro_range", 150.0) * 1.5:
		data["state"] = "wander"
		return

	# Attack if close enough.
	if dist < 30.0:
		if target.has_method("take_damage"):
			target.take_damage(5, -1)
		data["state"] = "wander"
		data["wander_timer"] = 2.0
		return

	# Move towards target.
	var move_dir: Vector2 = (target_pos - pos).normalized()
	var speed: float = stats.get("speed", 80.0)
	node.global_position += move_dir * speed * delta

	node.global_position = _clamp_to_map(node.global_position)

# =============================================================================
# Damage & Death
# =============================================================================

## Apply damage to an animal. Returns true if killed.
func damage_animal(animal_id: int, damage: int) -> bool:
	if not _animals.has(animal_id):
		return false

	var data: Dictionary = _animals[animal_id]
	data["hp"] -= damage

	if data["hp"] <= 0:
		_kill_animal(animal_id)
		return true

	# Flee when damaged.
	if data["state"] != "flee":
		var node: Node2D = data["node"]
		if is_instance_valid(node):
			data["state"] = "flee"
			var angle: float = randf() * TAU
			data["flee_target"] = node.global_position + Vector2.from_angle(angle) * 200.0

	return false


func _kill_animal(animal_id: int) -> void:
	var data: Dictionary = _animals[animal_id]
	var node: Node2D = data["node"]
	var pos: Vector2 = Vector2.ZERO
	var animal_type: String = data["type"]

	if is_instance_valid(node):
		pos = node.global_position
		var stats: Dictionary = animal_stats.get(animal_type, animal_stats["deer"])
		var food_value: int = stats.get("food_value", 0)

		# Emit food drop event.
		if food_value > 0:
			EventBus.resource_collected.emit("food", food_value, -1, 0)

		node.queue_free()

	_animals.erase(animal_id)
	animal_died.emit(animal_id, animal_type, pos)

# =============================================================================
# Despawn
# =============================================================================

func _check_despawn() -> void:
	var camera_pos: Vector2 = _get_camera_position()

	for animal_id: int in _animals.keys():
		var data: Dictionary = _animals[animal_id]
		var node: Node2D = data["node"]

		if not is_instance_valid(node):
			_animals.erase(animal_id)
			continue

		var dist: float = node.global_position.distance_to(camera_pos)
		if dist > despawn_radius:
			node.queue_free()
			_animals.erase(animal_id)

# =============================================================================
# Queries
# =============================================================================

func _get_type_count(animal_type: String) -> int:
	var count: int = 0
	for data: Dictionary in _animals.values():
		if data["type"] == animal_type:
			count += 1
	return count


func get_animal_count() -> int:
	return _animals.size()


func get_animals_by_type(animal_type: String) -> Array:
	var result: Array = []
	for animal_id: int in _animals:
		if _animals[animal_id]["type"] == animal_type:
			result.append(animal_id)
	return result


func get_nearest_animal(pos: Vector2, max_dist: float = 200.0) -> int:
	var best_id: int = -1
	var best_dist: float = max_dist

	for animal_id: int in _animals:
		var node: Node2D = _animals[animal_id]["node"]
		if is_instance_valid(node):
			var dist: float = node.global_position.distance_to(pos)
			if dist < best_dist:
				best_dist = dist
				best_id = animal_id

	return best_id

# =============================================================================
# Helpers
# =============================================================================

func _find_nearest_unit(pos: Vector2, max_dist: float) -> Node2D:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	var best: Node2D = null
	var best_dist: float = max_dist

	for unit: Node in units:
		if unit is Node2D:
			var dist: float = (unit as Node2D).global_position.distance_to(pos)
			if dist < best_dist:
				best_dist = dist
				best = unit as Node2D

	return best


func _get_camera_position() -> Vector2:
	if is_instance_valid(_camera):
		return _camera.global_position
	var scene: Node = get_tree().current_scene
	if scene != null:
		var cam: Node = scene.get_node_or_null("CameraController")
		if cam != null and cam is Node2D:
			return (cam as Node2D).global_position
	return Vector2.ZERO


func _get_random_spawn_position() -> Vector2:
	var camera_pos: Vector2 = _get_camera_position()
	var angle: float = randf() * TAU
	var dist: float = randf_range(200.0, spawn_radius)
	return _clamp_to_map(camera_pos + Vector2.from_angle(angle) * dist)


func _check_min_distance(pos: Vector2, animal_type: String) -> bool:
	for data: Dictionary in _animals.values():
		if data["type"] == animal_type:
			var node: Node2D = data["node"]
			if is_instance_valid(node) and node.global_position.distance_to(pos) < min_spawn_distance:
				return false
	return true


func _clamp_to_map(pos: Vector2) -> Vector2:
	var map_size: Vector2 = Vector2(2048, 2048)  # Default map size.
	return Vector2(
		clampf(pos.x, 32.0, map_size.x - 32.0),
		clampf(pos.y, 32.0, map_size.y - 32.0)
	)
