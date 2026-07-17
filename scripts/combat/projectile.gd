class_name Projectile
extends Area2D

signal projectile_hit(target: Node2D, damage: int)

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

var splash_radius: float = 0.0
var pierce_count: int = 0
var chain_count: int = 0
var armor_pen: int = 0
var damage_type: String = "physical"
var _pierced_targets: Array[Node2D] = []
var _chain_targets: Array[Node2D] = []

var _progress: float = 0.0
var _total_distance: float = 0.0
var _direction: Vector2 = Vector2.ZERO
var _sprite: ColorRect = null
var _initialized: bool = false
var _trail_particles: Array[Vector2] = []
var _trail_timer: float = 0.0
const TRAIL_INTERVAL: float = 0.05


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

	var proj_data: Dictionary = DamageCalculator.get_projectile_data(type)
	speed = proj_data.get("speed", 200.0)
	arc_height = proj_data.get("arc", 15.0)
	damage_type = proj_data.get("damage_type", "physical")
	armor_pen = proj_data.get("armor_pen", 0)
	splash_radius = proj_data.get("splash", 0.0)
	pierce_count = proj_data.get("pierce", 0)
	chain_count = proj_data.get("chain", 0)
	is_homing = proj_data.get("homing", true)

	var proj_color: Color = proj_data.get("color", Color(1.0, 1.0, 1.0))
	_tint_sprite(proj_color)
	_adjust_visual_for_type()

	_initialized = true
	EventBus.projectile_fired.emit(attacker_id, attacker_id, target_id, origin, damage)


func _process(delta: float) -> void:
	if not _initialized:
		return

	_update_trail(delta)

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

	match projectile_type:
		"fireball":
			_update_fire_effect(delta)
		"lightning":
			_update_lightning_effect(delta)


func on_hit() -> void:
	if not is_instance_valid(target_node):
		if splash_radius > 0.0:
			_apply_splash_at_position(target_position)
		queue_free()
		return

	match projectile_type:
		"fireball":
			_on_fireball_hit()
		"boulder":
			_on_boulder_hit()
		"lightning":
			_on_lightning_hit()
		_:
			_on_standard_hit()

	projectile_hit.emit(target_node, damage)
	_spawn_impact_particles()
	queue_free()


func _on_standard_hit() -> void:
	var combat_manager: Node = _get_combat_manager()
	if combat_manager != null and combat_manager.has_method("apply_damage"):
		combat_manager.apply_damage(target_node, damage, attacker_id)
	else:
		if target_node.has_method("take_damage"):
			target_node.take_damage(damage, attacker_id)

	if splash_radius > 0.0:
		var combat_mgr: Node = _get_combat_manager()
		if combat_mgr != null and combat_mgr.has_method("apply_area_damage"):
			combat_mgr.apply_area_damage(target_node.global_position, splash_radius, damage, attacker_id, {}, target_node)

	if pierce_count > 0:
		_apply_pierce()
	if chain_count > 0:
		_apply_chain()


func _on_fireball_hit() -> void:
	var combat_mgr: Node = _get_combat_manager()
	if combat_mgr != null:
		if combat_mgr.has_method("apply_damage"):
			combat_mgr.apply_damage(target_node, damage, attacker_id)
		if combat_mgr.has_method("apply_area_damage"):
			combat_mgr.apply_area_damage(target_node.global_position, splash_radius, damage, attacker_id, {}, target_node)
	else:
		if target_node.has_method("take_damage"):
			target_node.take_damage(damage, attacker_id)

	_spawn_fire_effect(target_node.global_position)


func _on_boulder_hit() -> void:
	var combat_mgr: Node = _get_combat_manager()
	if combat_mgr != null:
		if combat_mgr.has_method("apply_damage"):
			combat_mgr.apply_damage(target_node, damage, attacker_id)
		if combat_mgr.has_method("apply_area_damage"):
			combat_mgr.apply_area_damage(target_node.global_position, splash_radius, damage, attacker_id, {}, target_node)
	else:
		if target_node.has_method("take_damage"):
			target_node.take_damage(damage, attacker_id)

	_spawn_impact_particles()


func _on_lightning_hit() -> void:
	var combat_mgr: Node = _get_combat_manager()
	if combat_mgr != null:
		if combat_mgr.has_method("apply_damage"):
			combat_mgr.apply_damage(target_node, damage, attacker_id)
		if combat_mgr.has_method("_apply_chain_damage"):
			combat_mgr._apply_chain_damage(target_node, damage, attacker_id, chain_count, {})
	else:
		if target_node.has_method("take_damage"):
			target_node.take_damage(damage, attacker_id)


func _apply_pierce() -> void:
	var combat_mgr: Node = _get_combat_manager()
	if combat_mgr == null:
		return

	var attacker_pos: Vector2 = origin
	var direction: Vector2 = (target_position - origin).normalized()
	var range: float = _total_distance

	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	var pierced: int = 0

	for unit: Node in all_units:
		if unit == target_node:
			continue
		if not (unit is Node2D):
			continue
		if pierced >= pierce_count:
			break
		if _pierced_targets.has(unit):
			continue

		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid == -1 or pid == attacker_id:
			continue

		var unit_pos: Vector2 = (unit as Node2D).global_position
		var to_unit: Vector2 = unit_pos - attacker_pos
		var dot: float = to_unit.dot(direction)
		if dot <= 0.0 or dot > range:
			continue

		var lateral: float = (to_unit - direction * dot).length()
		if lateral > 30.0:
			continue

		var pierce_damage: int = DamageCalculator.calculate_pierce_damage(damage, pierced, pierce_count)
		if combat_mgr.has_method("apply_damage"):
			combat_mgr.apply_damage(unit as Node2D, pierce_damage, attacker_id)

		_pierced_targets.append(unit)
		pierced += 1


func _apply_chain() -> void:
	var combat_mgr: Node = _get_combat_manager()
	if combat_mgr == null or target_node == null:
		return

	if combat_mgr.has_method("_apply_chain_damage"):
		combat_mgr._apply_chain_damage(target_node, damage, attacker_id, chain_count, {})


func _apply_splash_at_position(pos: Vector2) -> void:
	var combat_mgr: Node = _get_combat_manager()
	if combat_mgr != null and combat_mgr.has_method("apply_area_damage"):
		combat_mgr.apply_area_damage(pos, splash_radius, damage, attacker_id, {}, target_node)


func _get_combat_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var cm: Node = scene.get_node_or_null("CombatManager")
	if cm != null:
		return cm
	return _find_in_tree("CombatManager")


func _update_trail(delta: float) -> void:
	if projectile_type not in ["fireball", "lightning"]:
		return

	_trail_timer += delta
	if _trail_timer < TRAIL_INTERVAL:
		return
	_trail_timer = 0.0

	_trail_particles.append(global_position)
	if _trail_particles.size() > 8:
		_trail_particles.pop_front()
	queue_redraw()


func _update_fire_effect(_delta: float) -> void:
	if _sprite != null:
		var flicker: float = randf_range(0.8, 1.2)
		_sprite.color = Color(1.0, 0.4 * flicker, 0.1 * flicker, 0.9)


func _update_lightning_effect(_delta: float) -> void:
	if _sprite != null:
		var flash: float = randf_range(0.5, 1.0)
		_sprite.color = Color(0.4 * flash, 0.6 * flash, 1.0, 0.9)


func _spawn_fire_effect(pos: Vector2) -> void:
	var particle_manager: Node = _find_in_tree("ParticleEffects")
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect("fire_impact", pos)


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


func _adjust_visual_for_type() -> void:
	if _sprite == null:
		return

	match projectile_type:
		"arrow":
			_sprite.size = Vector2(8, 2)
			_sprite.position = Vector2(-4, -1)
		"rock":
			_sprite.size = Vector2(6, 6)
			_sprite.position = Vector2(-3, -3)
		"bolt":
			_sprite.size = Vector2(10, 1)
			_sprite.position = Vector2(-5, -0.5)
		"fireball":
			_sprite.size = Vector2(8, 8)
			_sprite.position = Vector2(-4, -4)
		"lightning":
			_sprite.size = Vector2(12, 2)
			_sprite.position = Vector2(-6, -1)
		"boulder":
			_sprite.size = Vector2(10, 10)
			_sprite.position = Vector2(-5, -5)


func _tint_sprite(color: Color) -> void:
	if _sprite != null:
		_sprite.color = color


func _position_sprite_offset(y_offset: float) -> void:
	if _sprite != null:
		_sprite.position.y = -1.0 + (-y_offset)


func _draw() -> void:
	if _trail_particles.size() < 2:
		return

	var trail_color: Color
	match projectile_type:
		"fireball":
			trail_color = Color(1.0, 0.5, 0.1, 0.4)
		"lightning":
			trail_color = Color(0.4, 0.6, 1.0, 0.3)
		_:
			return

	for i in range(1, _trail_particles.size()):
		var alpha: float = float(i) / float(_trail_particles.size())
		var from_local: Vector2 = to_local(_trail_particles[i - 1])
		var to_local_pos: Vector2 = to_local(_trail_particles[i])
		draw_line(from_local, to_local_pos, Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha), 2.0)
