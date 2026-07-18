## Core building entity. Extends StaticBody2D and manages health, construction,
## production, and combat for all building types in the game.
class_name BuildingBase
extends StaticBody2D

# =============================================================================
# Signals
# =============================================================================

signal constructed(building_id: int)
signal destroyed(building_id: int)
signal production_completed(building_id: int, item_type: String)

# =============================================================================
# Properties
# =============================================================================

var building_id: int = -1
var building_type: String = ""
var player_id: int = -1
var max_hp: int = 100
var current_hp: int = 100
var armor: int = 0
var is_constructed: bool = false
var construction_progress: float = 0.0
var construction_total: int = 0
var grid_position: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i(1, 1)
var production_queue: Array[String] = []
var is_producing: bool = false
var production_timer: float = 0.0
var sight_range: int = 4
var attack_damage: int = 0
var attack_range: float = 0.0
var attack_speed: float = 0.0
var attack_cooldown: float = 0.0
var current_attack_target: Node2D = null
var garrison_count: int = 0
var garrison_capacity: int = 0
var is_selected: bool = false
var construction_build_time: float = 15.0
var construction_workers: int = 1

var rally_point: Vector2 = Vector2.ZERO
var has_rally_point: bool = false

var _sprite: AnimatedSprite2D = null
var _collision: CollisionShape2D = null
var _anim_controller: Node = null
var _progress_bar: Node = null
var _building_data: Dictionary = {}
var _construction_fx_timer: float = 0.0
var _completion_glow_timer: float = 0.0

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_find_child_nodes()
	connect_signals()


func _process(delta: float) -> void:
	if not is_constructed:
		_update_construction(delta)
		return
	if _completion_glow_timer > 0.0:
		_completion_glow_timer = maxf(_completion_glow_timer - delta, 0.0)
		queue_redraw()
	_update_attack(delta)
	_update_production(delta)


func _update_production(delta: float) -> void:
	update_production(delta)

# =============================================================================
# Setup
# =============================================================================

func initialize(type: String, owner_id: int, grid_pos: Vector2i) -> void:
	building_type = type
	player_id = owner_id
	grid_position = grid_pos
	building_id = _generate_id()

	_building_data = DataManager.get_building_data(building_type)
	if _building_data.is_empty():
		push_warning("BuildingBase: No data found for type '%s'." % building_type)
		max_hp = 100
		current_hp = 100
		return

	max_hp = _building_data.get("hp", 100)
	current_hp = max_hp
	armor = _building_data.get("armor", 0)
	sight_range = _building_data.get("sight", 4)
	var raw_size: Variant = _building_data.get("size", {"x": 2, "y": 2})
	if raw_size is Vector2i:
		grid_size = raw_size
	elif raw_size is Dictionary:
		grid_size = Vector2i(int(raw_size.get("x", 2)), int(raw_size.get("y", 2)))
	else:
		grid_size = Vector2i(2, 2)
	construction_total = max_hp
	construction_build_time = float(_building_data.get("build_time", 15.0))
	attack_damage = _building_data.get("attack", 0)
	attack_range = _building_data.get("range", 0.0)
	attack_speed = _building_data.get("attack_speed", 0.0)
	garrison_capacity = _building_data.get("garrison_capacity", 0)
	attack_cooldown = 0.0

	_setup_visuals()


func _find_child_nodes() -> void:
	_sprite = _find_child_recursive("AnimatedSprite2D") as AnimatedSprite2D
	_collision = _find_child_recursive("CollisionShape2D") as CollisionShape2D
	_anim_controller = _find_child_recursive("BuildingAnimationController")
	_progress_bar = _find_child_recursive("ProgressBar")


func _find_child_recursive(target_name: String) -> Node:
	for child: Node in get_children():
		if child.name == target_name:
			return child
	for child: Node in get_children():
		var result: Node = child._find_child_recursive(target_name) if child.has_method("_find_child_recursive") else null
		if result != null:
			return result
	return null


func connect_signals() -> void:
	if not EventBus.building_damaged.is_connected(_on_building_damaged):
		EventBus.building_damaged.connect(_on_building_damaged)


func _setup_visuals() -> void:
	if _anim_controller and _anim_controller.has_method("setup_building_visuals"):
		_anim_controller.setup_building_visuals(building_type, player_id, grid_size)
	if _sprite and (_sprite.sprite_frames == null or _sprite.sprite_frames.get_animation_names().is_empty()):
		_sprite.sprite_frames = preload("res://scripts/animation/procedural_sprite_factory.gd").create_building_frames(building_type, player_id, grid_size)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.centered = true
		_sprite.position = Vector2(0, -16)
		_sprite.z_index = 6
	if _sprite:
		if is_constructed and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("active"):
			_sprite.play("active")
		elif _sprite.sprite_frames and _sprite.sprite_frames.has_animation("constructing"):
			_sprite.play("constructing")
		elif _sprite.sprite_frames and _sprite.sprite_frames.has_animation("idle"):
			_sprite.play("idle")
	if _collision:
		var rect_shape: RectangleShape2D = _collision.shape as RectangleShape2D
		if rect_shape != null:
			rect_shape.size = Vector2(float(grid_size.x * 32), float(grid_size.y * 32))
		_collision.set_deferred("disabled", not is_constructed)

# =============================================================================
# ID Generation
# =============================================================================

func _generate_id() -> int:
	return randi()

# =============================================================================
# Damage & Health
# =============================================================================

func take_damage(amount: int, attacker_id: int = -1) -> void:
	if not is_constructed:
		return
	var reduced: int = maxi(amount - armor, 1)
	current_hp -= reduced
	EventBus.building_damaged.emit(building_id, reduced, attacker_id)
	EventBus.damage_dealt.emit(building_id, attacker_id, reduced, false)

	if _anim_controller and _anim_controller.has_method("play_hurt"):
		_anim_controller.play_hurt()

	if current_hp <= 0:
		current_hp = 0
		_destroy(attacker_id)


func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)


func _destroy(killer_id: int = -1) -> void:
	var destroyer_player: int = -1
	if killer_id != -1:
		var killer_unit: Node = _find_unit_by_id(killer_id)
		if killer_unit and killer_unit.has_method("get"):
			destroyer_player = killer_unit.get("player_id") if killer_unit.get("player_id") != null else -1

	EventBus.building_destroyed.emit(building_id, player_id, destroyer_player)
	destroyed.emit(building_id)

	if _anim_controller and _anim_controller.has_method("play_death"):
		_anim_controller.play_death()
		await _anim_controller.animation_death_finished if _anim_controller.has_signal("animation_death_finished") else null

	queue_free()


func _find_unit_by_id(unit_id: int) -> Node:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if unit.has_method("get") and unit.get("unit_id") != null and unit.get("unit_id") == unit_id:
			return unit
	return null

# =============================================================================
# Construction
# =============================================================================

func start_construction() -> void:
	if is_constructed:
		return
	construction_progress = 0.0
	current_hp = 0
	EventBus.construction_started.emit(building_id, player_id, construction_total)
	if _anim_controller and _anim_controller.has_method("set_state"):
		_anim_controller.set_state("constructing")
	if _anim_controller and _anim_controller.has_method("set_construction_progress"):
		_anim_controller.set_construction_progress(construction_progress)
	queue_redraw()

	if _collision:
		_collision.set_deferred("disabled", true)


func _update_construction(delta: float) -> void:
	if construction_build_time <= 0.0:
		complete_construction()
		return
	var hp_per_second: float = float(construction_total) / construction_build_time
	var workers_mult: float = maxf(float(construction_workers), 1.0)
	advance_construction(maxi(ceili(hp_per_second * workers_mult * delta), 1))

	_construction_fx_timer -= delta
	if _construction_fx_timer <= 0.0:
		_construction_fx_timer = 0.45
		_spawn_build_effect()


func advance_construction(work_amount: int) -> void:
	if is_constructed:
		return
	current_hp = mini(current_hp + work_amount, construction_total)
	construction_progress = float(current_hp) / float(construction_total) if construction_total > 0 else 0.0
	EventBus.construction_progress.emit(building_id, current_hp, construction_total)
	if _anim_controller and _anim_controller.has_method("set_construction_progress"):
		_anim_controller.set_construction_progress(construction_progress)
	queue_redraw()

	if construction_progress >= 1.0:
		complete_construction()


func complete_construction() -> void:
	if is_constructed:
		return
	is_constructed = true
	current_hp = max_hp
	construction_progress = 1.0
	EventBus.construction_completed.emit(building_id, player_id)
	constructed.emit(building_id)
	_completion_glow_timer = 1.1
	_spawn_completion_effect()
	_shake_camera(1.8, 0.18)
	queue_redraw()

	if _collision:
		_collision.set_deferred("disabled", false)

	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("idle"):
		if _sprite.sprite_frames.has_animation("active"):
			_sprite.play("active")
		else:
			_sprite.play("idle")

	if _anim_controller and _anim_controller.has_method("set_state"):
		_anim_controller.set_state("active")

	if _progress_bar:
		_progress_bar.visible = false


func _spawn_build_effect() -> void:
	var particle_manager: Node = _find_particle_manager()
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		var offset: Vector2 = Vector2(randf_range(-float(grid_size.x) * 12.0, float(grid_size.x) * 12.0), randf_range(-10.0, 10.0))
		particle_manager.spawnEffect("build_construct", global_position + offset, 6)


func _spawn_completion_effect() -> void:
	var particle_manager: Node = _find_particle_manager()
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect("build_construct", global_position, 20)
		particle_manager.spawnEffect("fire_smoke", global_position + Vector2(0, -24), 8)


func _find_particle_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_node_recursive(scene, "ParticleEffects")


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_node_recursive(child, target_name)
		if found != null:
			return found
	return null


func _shake_camera(amount: float, duration: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var camera: Node = _find_node_recursive(scene, "Camera2D")
	if camera != null and camera.has_method("shake"):
		camera.shake(amount, duration)

# =============================================================================
# Production
# =============================================================================

func start_production(unit_type: String) -> void:
	if not is_constructed:
		return
	if not can_produce(unit_type):
		return
	production_queue.append(unit_type)

	if not is_producing:
		_begin_next_production()


func cancel_production() -> void:
	if production_queue.is_empty():
		return
	production_queue.clear()
	is_producing = false
	production_timer = 0.0


func _begin_next_production() -> void:
	if production_queue.is_empty():
		is_producing = false
		production_timer = 0.0
		return

	is_producing = true
	production_timer = 0.0

	var unit_data: Dictionary = DataManager.get_unit_data(production_queue[0])
	if unit_data.is_empty():
		push_warning("BuildingBase: No unit data for '%s'." % production_queue[0])
		production_queue.pop_front()
		_begin_next_production()
		return

	var build_time: float = unit_data.get("train_time", unit_data.get("build_time", 10.0))
	production_timer = build_time


func cancel_last() -> void:
	if production_queue.size() > 0:
		production_queue.pop_back()
		if production_queue.is_empty():
			is_producing = false
			production_timer = 0.0


func update_production(delta: float) -> void:
	if not is_producing or production_queue.is_empty():
		return

	production_timer -= delta
	if production_timer <= 0.0:
		var completed_type: String = production_queue.pop_front()
		_spawn_produced_unit(completed_type)
		production_completed.emit(building_id, completed_type)
		_begin_next_production()

	if _progress_bar:
		_update_progress_bar_visual()


func _spawn_produced_unit(unit_type: String) -> void:
	var spawn_pos: Vector2 = global_position
	if has_rally_point:
		spawn_pos = rally_point
	else:
		spawn_pos += Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	
	var unit_scene: PackedScene = preload("res://scenes/units/unit.tscn")
	var unit: UnitBase = unit_scene.instantiate()
	unit.initialize(unit_type, player_id)
	unit.global_position = spawn_pos
	get_tree().current_scene.add_child(unit)
	
	if has_rally_point and unit.has_method("get_node") and unit.has_node("MovementComponent"):
		var movement: MovementComponent = unit.get_node("MovementComponent")
		if movement:
			movement.move_to(rally_point)


func set_rally_point(position: Vector2) -> void:
	rally_point = position
	has_rally_point = true


func get_rally_point() -> Vector2:
	return rally_point


func has_rally_point() -> bool:
	return has_rally_point


func clear_rally_point() -> void:
	has_rally_point = false
	rally_point = Vector2.ZERO


func get_production_progress() -> float:
	if not is_producing or production_queue.is_empty():
		return 0.0
	var unit_data: Dictionary = DataManager.get_unit_data(production_queue[0])
	if unit_data.is_empty():
		return 0.0
	var total_time: float = unit_data.get("train_time", unit_data.get("build_time", 10.0))
	var elapsed: float = total_time - production_timer
	return clampf(elapsed / total_time, 0.0, 1.0) if total_time > 0.0 else 0.0


func can_produce(unit_type: String) -> bool:
	if not is_constructed:
		return false
	var produces: Array = _building_data.get("produces", [])
	return unit_type in produces

# =============================================================================
# Garrison
# =============================================================================

func get_garrison_count() -> int:
	return garrison_count

# =============================================================================
# Repair
# =============================================================================

func repair(cost_multiplier: float = 0.5) -> void:
	if current_hp >= max_hp:
		return
	if not is_constructed:
		return
	var missing_hp: int = max_hp - current_hp
	var repair_amount: int = mini(missing_hp, 10)
	var cost: Dictionary = {}
	for resource_type: String in _building_data.get("cost", {}):
		var base_cost: int = _building_data["cost"][resource_type]
		cost[resource_type] = maxi(ceili(float(base_cost) * cost_multiplier * float(repair_amount) / float(max_hp)), 1)

	if GameManager.can_afford(cost, player_id):
		GameManager.spend_resources(cost, player_id)
		heal(repair_amount)

# =============================================================================
# Combat
# =============================================================================

func _update_attack(delta: float) -> void:
	if attack_damage <= 0 or attack_range <= 0.0:
		return

	attack_cooldown -= delta
	if attack_cooldown > 0.0:
		return

	if current_attack_target == null or not is_instance_valid(current_attack_target):
		current_attack_target = null
		return

	var dist: float = global_position.distance_to(current_attack_target.global_position)
	if dist > attack_range:
		current_attack_target = null
		return

	_perform_attack()
	attack_cooldown = attack_speed


func _perform_attack() -> void:
	if current_attack_target == null or not is_instance_valid(current_attack_target):
		return

	var target_id: int = -1
	if current_attack_target.has_method("get") and current_attack_target.get("unit_id") != null:
		target_id = current_attack_target.get("unit_id")
	elif current_attack_target.has_method("get") and current_attack_target.get("building_id") != null:
		target_id = current_attack_target.get("building_id")

	EventBus.unit_attacked.emit(building_id, target_id, attack_damage)

	if current_attack_target.has_method("take_damage"):
		current_attack_target.take_damage(attack_damage, building_id)

# =============================================================================
# Targeting
# =============================================================================

func set_attack_target(target: Node2D) -> void:
	current_attack_target = target

# =============================================================================
# Enemy Check
# =============================================================================

func is_enemy(other: Node2D) -> bool:
	if other.has_method("get") and other.get("player_id") != null:
		return other.get("player_id") != player_id
	return false

# =============================================================================
# Progress Bar
# =============================================================================

func _update_progress_bar_visual() -> void:
	if _progress_bar == null:
		return
	_progress_bar.visible = true
	if _progress_bar is TextureProgressBar:
		_progress_bar.value = get_production_progress() * 100.0
	elif _progress_bar.has_method("set_size"):
		var progress: float = get_production_progress()
		var bar_width: float = 64.0
		_progress_bar.set_size(Vector2(bar_width * progress, 4.0))

# =============================================================================
# Selection visual feedback
# =============================================================================

func select() -> void:
	is_selected = true
	queue_redraw()
	if _sprite:
		_sprite.modulate = Color(0.4, 1.0, 0.4, 1.0)


func deselect() -> void:
	is_selected = false
	queue_redraw()
	if _sprite:
		_sprite.modulate = Color.WHITE


func _draw() -> void:
	if is_selected:
		var radius: float = maxf(float(maxi(grid_size.x, grid_size.y)) * 20.0, 34.0)
		var pulse: float = 0.5 + sin(Time.get_ticks_msec() * 0.006) * 0.18
		draw_circle(Vector2.ZERO, radius, Color(0.25, 0.9, 0.35, 0.10 + pulse * 0.08))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.35, 1.0, 0.45, 0.75), 2.0)

	if not is_constructed:
		var width: float = maxf(float(grid_size.x * 32), 56.0)
		var top_left: Vector2 = Vector2(-width * 0.5, float(grid_size.y * 16) + 8.0)
		draw_rect(Rect2(top_left, Vector2(width, 6.0)), Color(0.04, 0.04, 0.04, 0.75), true)
		draw_rect(Rect2(top_left, Vector2(width * construction_progress, 6.0)), Color(0.9, 0.7, 0.32, 0.95), true)

	if _completion_glow_timer > 0.0:
		var glow_radius: float = maxf(float(maxi(grid_size.x, grid_size.y)) * 24.0, 40.0)
		var alpha: float = clampf(_completion_glow_timer / 1.1, 0.0, 1.0)
		draw_circle(Vector2.ZERO, glow_radius, Color(1.0, 0.85, 0.3, 0.16 * alpha))

	if has_rally_point and is_selected:
		var local_rally = to_local(rally_point)
		draw_line(Vector2.ZERO, local_rally, Color(0.3, 1.0, 0.4, 0.6), 2.0)
		draw_circle(local_rally, 8.0, Color(0.3, 1.0, 0.4, 0.4))
		draw_circle(local_rally, 5.0, Color(0.3, 1.0, 0.4, 0.8))

# =============================================================================
# Update Loop
# =============================================================================

func _on_building_damaged(_building_id: int, _damage: int, _attacker_id: int) -> void:
	pass

# =============================================================================
# Serialization
# =============================================================================

func get_data() -> Dictionary:
	return {
		"building_id": building_id,
		"building_type": building_type,
		"player_id": player_id,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"armor": armor,
		"is_constructed": is_constructed,
		"construction_progress": construction_progress,
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"grid_size": {"x": grid_size.x, "y": grid_size.y},
		"production_queue": production_queue.duplicate(),
		"is_producing": is_producing,
		"production_timer": production_timer,
		"sight_range": sight_range,
		"attack_damage": attack_damage,
		"attack_range": attack_range,
		"attack_speed": attack_speed,
		"garrison_count": garrison_count,
		"garrison_capacity": garrison_capacity,
		"rally_point": {"x": rally_point.x, "y": rally_point.y},
		"has_rally_point": has_rally_point,
	}
