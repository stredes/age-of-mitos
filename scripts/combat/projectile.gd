class_name Projectile
extends Area2D

var speed: float = 200.0
var damage: int = 10
var target_id: int = -1
var attacker_id: int = -1
var target_node: Node2D = null
var origin: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var projectile_type: String = "arrow"
var is_homing: bool = true
var arc_height: float = 0.0

var _progress: float = 0.0
var _total_distance: float = 0.0
var _direction: Vector2 = Vector2.ZERO
var _sprite: ColorRect = null
var _initialized: bool = false


func _ready() -> void:
	_create_visual()
	_create_collision()


func initialize(attacker: Node2D, target: Node2D, dmg: int, type: String) -> void:
	if attacker == null or target == null:
		queue_free()
		return

	attacker_id = attacker.get("unit_id") if attacker.get("unit_id") != null else -1
	target_id = target.get("unit_id") if target.get("unit_id") != null else -1
	target_node = target
	damage = dmg
	projectile_type = type
	origin = attacker.global_position
	global_position = origin
	target_position = target.global_position

	_total_distance = origin.distance_to(target_position)
	if _total_distance > 0.0:
		_direction = (target_position - origin).normalized()

	match projectile_type:
		"arrow":
			speed = 300.0
			arc_height = 20.0
			_tint_sprite(Color(0.8, 0.7, 0.5))
		"rock":
			speed = 180.0
			arc_height = 40.0
			_tint_sprite(Color(0.5, 0.5, 0.5))
		"bolt":
			speed = 400.0
			arc_height = 10.0
			_tint_sprite(Color(0.3, 0.3, 0.3))
		_:
			speed = 200.0
			arc_height = 15.0
			_tint_sprite(Color(1.0, 1.0, 1.0))

	_initialized = true
	EventBus.projectile_fired.emit(attacker_id, attacker_id, target_id, origin, damage)


func _process(delta: float) -> void:
	if not _initialized:
		return

	var current_target_pos: Vector2 = target_position
	if is_homing and is_instance_valid(target_node):
		current_target_pos = target_node.global_position

	var travel: float = speed * delta
	_progress += travel

	var target_dist: float = global_position.distance_to(current_target_pos)
	if target_dist < 4.0:
		on_hit()
		return

	if _total_distance > 0.0 and _progress >= _total_distance:
		global_position = current_target_pos
		on_hit()
		return

	var move_dir: Vector2 = (current_target_pos - global_position).normalized()
	global_position += move_dir * travel

	if arc_height > 0.0 and _total_distance > 0.0:
		var t: float = clampf(_progress / _total_distance, 0.0, 1.0)
		_position_sprite_offset(sin(t * PI) * arc_height)

	if _direction.length_squared() > 0.01:
		rotation = _direction.angle()

	if move_dir.length_squared() > 0.01:
		_direction = move_dir


func on_hit() -> void:
	if not is_instance_valid(target_node):
		queue_free()
		return

	var combat_manager: Node = get_tree().current_scene.get_node_or_null("CombatManager")
	if combat_manager == null:
		combat_manager = _find_in_tree("CombatManager")

	if combat_manager != null and combat_manager.has_method("apply_damage"):
		combat_manager.apply_damage(target_node, damage, attacker_id)
	else:
		if target_node.has_method("take_damage"):
			target_node.take_damage(damage, attacker_id)

	_spawn_impact_particles()
	queue_free()


func _spawn_impact_particles() -> void:
	var particle_manager: Node = get_tree().current_scene.get_node_or_null("ParticleEffects")
	if particle_manager == null:
		particle_manager = _find_in_tree("ParticleEffects")
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect("combat_impact", global_position)


func _find_in_tree(target_name: String) -> Node:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	return _search_children(root, target_name)


func _search_children(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _search_children(child, target_name)
		if result != null:
			return result
	return null


func _create_visual() -> void:
	_sprite = ColorRect.new()
	_sprite.name = "ProjectileSprite"
	_sprite.size = Vector2(6, 2)
	_sprite.position = Vector2(-3, -1)
	_sprite.z_index = 10
	add_child(_sprite)


func _create_collision() -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(4, 4)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.name = "Hitbox"
	add_child(collision)
	monitoring = false
	monitorable = false


func _tint_sprite(color: Color) -> void:
	if _sprite != null:
		_sprite.color = color


func _position_sprite_offset(y_offset: float) -> void:
	if _sprite != null:
		_sprite.position.y = -1.0 + (-y_offset)
