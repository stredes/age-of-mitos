## Particle Effects Manager
## Centralized particle effect spawner with object pooling.
## Attach to the game world root node. Uses CPUParticles2D for performance.
class_name ParticleEffectsManager
extends Node

# --- Constants ---
const DEFAULT_POOL_SIZE: int = 8
const POOL_GROW_SIZE: int = 4
const CLEANUP_INTERVAL: float = 5.0

# --- Type Definitions ---
class ParticleConfig:
	var amount: int = 10
	var lifetime: float = 1.0
	var spread: float = 180.0
	var initial_velocity_min: float = 20.0
	var initial_velocity_max: float = 60.0
	var gravity: Vector2 = Vector2(0, 80)
	var color: Color = Color.WHITE
	var color_end: Color = Color(1, 1, 1, 0)
	var scale_amount_min: float = 0.5
	var scale_amount_max: float = 1.5
	var rotation_degrees_min: float = 0.0
	var rotation_degrees_max: float = 360.0
	var friction: float = 0.0
	var damp: float = 0.0
	var emission_shape: CPUParticles2D.EmissionShape = CPUParticles2D.EMISSION_SHAPE_POINT
	var emission_rect_size: Vector2 = Vector2(10, 10)
	var angular_velocity_min: float = 0.0
	var angular_velocity_max: float = 0.0
	var trajectory_amount: float = 0.0
	var trajectory_bias: float = 0.0

# --- Pooled Node ---
class PooledParticle:
	var node: CPUParticles2D
	var in_use: bool = false
	var auto_free_timer: float = 0.0

# --- Configuration Dictionary ---
var _configs: Dictionary = {}
# --- Pool Storage ---
var _pools: Dictionary = {}  # effect_name -> Array[PooledParticle]
# --- Active particles for tracking ---
var _active_particles: Array[PooledParticle] = []
# --- Cleanup timer ---
var _cleanup_timer: float = CLEANUP_INTERVAL


## --- Lifecycle ---

func _ready() -> void:
	_register_all_effects()


func _process(delta: float) -> void:
	# Update auto-free timers
	var i: int = _active_particles.size() - 1
	while i >= 0:
		var pooled: PooledParticle = _active_particles[i]
		if pooled.in_use:
			pooled.auto_free_timer -= delta
			if pooled.auto_free_timer <= 0.0 or not pooled.node.emitting:
				_release_particle(pooled)
				_active_particles.remove_at(i)
		i -= 1
	# Periodic cleanup
	_cleanup_timer -= delta
	if _cleanup_timer <= 0.0:
		_cleanup_timer = CLEANUP_INTERVAL
		_cleanup_orphaned_nodes()


## --- Public API ---

## Spawn a particle effect at a world position. Returns the CPUParticles2D node.
func spawnEffect(effect_name: String, position: Vector2, count: int = -1) -> CPUParticles2D:
	if not _configs.has(effect_name):
		push_warning("ParticleEffectsManager: Unknown effect '%s'" % effect_name)
		return null
	var pooled: PooledParticle = _get_or_create_particle(effect_name)
	var particle: CPUParticles2D = pooled.node
	var config: ParticleConfig = _configs[effect_name]
	# Apply config
	particle.amount = count if count > 0 else config.amount
	particle.lifetime = config.lifetime
	particle.spread = config.spread
	particle.initial_velocity_min = config.initial_velocity_min
	particle.initial_velocity_max = config.initial_velocity_max
	particle.gravity = config.gravity
	particle.color = config.color
	particle.color_ramp = _create_gradient(config.color, config.color_end)
	particle.scale_amount_min = config.scale_amount_min
	particle.scale_amount_max = config.scale_amount_max
	particle.angle_min = config.rotation_degrees_min
	particle.angle_max = config.rotation_degrees_max
	_set_particle_property_if_available(particle, "friction", config.friction)
	_set_particle_property_if_available(particle, "damping_min", config.damp)
	_set_particle_property_if_available(particle, "damping_max", config.damp)
	_set_particle_property_if_available(particle, "angular_velocity_min", config.angular_velocity_min)
	_set_particle_property_if_available(particle, "angular_velocity_max", config.angular_velocity_max)
	particle.emission_shape = config.emission_shape
	if config.emission_shape == CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS:
		particle.emission_rect_size = config.emission_rect_size
	# Position and activate
	particle.global_position = position
	particle.emitting = true
	particle.restart()
	# Track
	pooled.in_use = true
	pooled.auto_free_timer = config.lifetime + 0.5
	if pooled not in _active_particles:
		_active_particles.append(pooled)
	return particle


## Spawn a particle effect that follows a target node.
func spawnAtTarget(effect_name: String, position: Vector2, target: Node2D) -> CPUParticles2D:
	var particle: CPUParticles2D = spawnEffect(effect_name, position)
	if particle and is_instance_valid(target):
		# Create a follow process
		var follow_script: GDScript = GDScript.new()
		follow_script.source_code = """extends CPUParticles2D
var _target: Node2D = null
func _process(_delta: float) -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position
	else:
		queue_free()
"""
		follow_script.reload()
		particle.set_script(follow_script)
		particle.set("target", target)
	return particle


## Pre-instantiate pooled particle nodes for a given effect.
func prewarm(count: int = -1) -> void:
	var pool_count: int = count if count > 0 else DEFAULT_POOL_SIZE
	for effect_name in _configs.keys():
		if not _pools.has(effect_name):
			_pools[effect_name] = []
		for i in pool_count:
			var pooled: PooledParticle = _create_pooled_particle(effect_name)
			_pools[effect_name].append(pooled)


## Clear all active particles immediately.
func clear_all() -> void:
	for pooled in _active_particles:
		if pooled.node and is_instance_valid(pooled.node):
			pooled.node.emitting = false
			pooled.node.queue_free()
	_active_particles.clear()


## Get the number of active particles of a given type.
func get_active_count(effect_name: String) -> int:
	var count: int = 0
	for pooled in _active_particles:
		if pooled.in_use and pooled.node.name.begins_with(effect_name):
			count += 1
	return count


## --- Configuration Registration ---

func _register_all_effects() -> void:
	# dust_walk: small brown particles when units walk
	_configs["dust_walk"] = _make_config(
		4, 0.5, 90.0, 10.0, 30.0,
		Vector2(0, 10), Color(0.6, 0.5, 0.3, 0.7), Color(0.6, 0.5, 0.3, 0.0),
		0.3, 0.8
	)
	# wood_chop: wood chip particles when harvesting trees
	_configs["wood_chop"] = _make_config(
		8, 0.8, 120.0, 30.0, 80.0,
		Vector2(0, 60), Color(0.55, 0.35, 0.15, 1.0), Color(0.55, 0.35, 0.15, 0.0),
		0.4, 1.2
	)
	# stone_mine: grey rock chips when mining
	_configs["stone_mine"] = _make_config(
		8, 0.7, 110.0, 25.0, 70.0,
		Vector2(0, 80), Color(0.6, 0.6, 0.6, 1.0), Color(0.5, 0.5, 0.5, 0.0),
		0.3, 1.0
	)
	# gold_mine: yellow sparkle particles
	var gold_cfg: ParticleConfig = _make_config(
		6, 1.0, 100.0, 20.0, 50.0,
		Vector2(0, 30), Color(1.0, 0.85, 0.2, 1.0), Color(1.0, 0.85, 0.2, 0.0),
		0.2, 0.6
	)
	gold_cfg.angular_velocity_min = -180.0
	gold_cfg.angular_velocity_max = 180.0
	_configs["gold_mine"] = gold_cfg
	# food_gather: green leaf particles
	_configs["food_gather"] = _make_config(
		6, 1.2, 140.0, 15.0, 40.0,
		Vector2(0, 20), Color(0.3, 0.7, 0.2, 1.0), Color(0.3, 0.7, 0.2, 0.0),
		0.4, 1.0
	)
	# build_construct: dust + wood particles
	_configs["build_construct"] = _make_config(
		10, 0.8, 130.0, 15.0, 50.0,
		Vector2(0, 40), Color(0.7, 0.6, 0.4, 0.8), Color(0.7, 0.6, 0.4, 0.0),
		0.3, 0.9
	)
	# combat_impact: white/red flash particles
	_configs["combat_impact"] = _make_config(
		12, 0.4, 160.0, 40.0, 120.0,
		Vector2(0, 0), Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.2, 0.1, 0.0),
		0.3, 1.0
	)
	# arrow_trail: small trail particles
	_configs["arrow_trail"] = _make_config(
		3, 0.4, 30.0, 5.0, 15.0,
		Vector2(0, 0), Color(0.8, 0.8, 0.8, 0.6), Color(0.8, 0.8, 0.8, 0.0),
		0.2, 0.5
	)
	# death_burst: larger burst on unit death
	_configs["death_burst"] = _make_config(
		16, 1.0, 180.0, 40.0, 100.0,
		Vector2(0, 50), Color(0.8, 0.3, 0.2, 0.9), Color(0.5, 0.2, 0.1, 0.0),
		0.5, 1.5
	)
	# building_destroy: large debris cloud
	_configs["building_destroy"] = _make_config(
		24, 2.0, 180.0, 30.0, 90.0,
		Vector2(0, 60), Color(0.5, 0.45, 0.35, 0.9), Color(0.4, 0.35, 0.3, 0.0),
		0.8, 2.0
	)
	# fire_smoke: rising smoke + embers
	var fire_smoke_cfg: ParticleConfig = _make_config(
		10, 2.5, 45.0, 10.0, 30.0,
		Vector2(0, -30), Color(0.5, 0.5, 0.5, 0.7), Color(0.3, 0.3, 0.3, 0.0),
		0.5, 1.5
	)
	fire_smoke_cfg.emission_shape = 1
	fire_smoke_cfg.emission_rect_size = Vector2(12, 6)
	_configs["fire_smoke"] = fire_smoke_cfg
	# water_splash: blue particles near water
	_configs["water_splash"] = _make_config(
		8, 0.6, 80.0, 30.0, 80.0,
		Vector2(0, -100), Color(0.3, 0.5, 0.9, 0.8), Color(0.3, 0.5, 0.9, 0.0),
		0.3, 0.8
	)
	# heal: green rising sparkles
	_configs["heal"] = _make_config(
		8, 1.2, 60.0, 10.0, 30.0,
		Vector2(0, -20), Color(0.2, 0.9, 0.3, 0.9), Color(0.2, 0.9, 0.3, 0.0),
		0.2, 0.6
	)
	# level_up: golden rising burst
	_configs["level_up"] = _make_config(
		14, 1.5, 120.0, 20.0, 60.0,
		Vector2(0, -40), Color(1.0, 0.9, 0.2, 1.0), Color(1.0, 0.9, 0.2, 0.0),
		0.3, 0.8
	)


## --- Pool Management ---

func _get_or_create_particle(effect_name: String) -> PooledParticle:
	if _pools.has(effect_name):
		# Find an inactive particle in the pool
		for pooled in _pools[effect_name]:
			if not pooled.in_use:
				return pooled
		# Pool exhausted, grow it
		for i in POOL_GROW_SIZE:
			var new_pooled: PooledParticle = _create_pooled_particle(effect_name)
			_pools[effect_name].append(new_pooled)
		return _pools[effect_name][-1]
	else:
		# First time: create pool
		_pools[effect_name] = []
		for i in DEFAULT_POOL_SIZE:
			var pooled: PooledParticle = _create_pooled_particle(effect_name)
			_pools[effect_name].append(pooled)
		return _pools[effect_name][0]


func _create_pooled_particle(effect_name: String) -> PooledParticle:
	var particle: CPUParticles2D = CPUParticles2D.new()
	particle.name = "%s_pooled_%d" % [effect_name, randi() % 10000]
	particle.emitting = false
	particle.one_shot = true
	particle.explosiveness = 0.9
	particle.finished.connect(_on_particle_finished.bind(particle))
	add_child(particle)
	var pooled: PooledParticle = PooledParticle.new()
	pooled.node = particle
	pooled.in_use = false
	pooled.auto_free_timer = 0.0
	return pooled


func _release_particle(pooled: PooledParticle) -> void:
	if pooled.node and is_instance_valid(pooled.node):
		pooled.node.emitting = false
		pooled.node.restart()
	pooled.in_use = false
	pooled.auto_free_timer = 0.0


func _on_particle_finished(particle: CPUParticles2D) -> void:
	for pooled in _active_particles:
		if pooled.node == particle:
			pooled.in_use = false
			pooled.auto_free_timer = 0.0
			break


func _cleanup_orphaned_nodes() -> void:
	# Remove particles that somehow lost their pooled reference
	for child in get_children():
		if child is CPUParticles2D and not child.emitting:
			var found: bool = false
			for pooled_arr in _pools.values():
				for pooled in pooled_arr:
					if pooled.node == child:
						found = true
						break
				if found:
					break
			if not found:
				child.queue_free()


## --- Helper: Create ParticleConfig ---

func _make_config(
	amount: int,
	lifetime: float,
	spread: float,
	vel_min: float,
	vel_max: float,
	gravity: Vector2,
	color_start: Color,
	color_end: Color,
	scale_min: float,
	scale_max: float
) -> ParticleConfig:
	var cfg: ParticleConfig = ParticleConfig.new()
	cfg.amount = amount
	cfg.lifetime = lifetime
	cfg.spread = spread
	cfg.initial_velocity_min = vel_min
	cfg.initial_velocity_max = vel_max
	cfg.gravity = gravity
	cfg.color = color_start
	cfg.color_end = color_end
	cfg.scale_amount_min = scale_min
	cfg.scale_amount_max = scale_max
	return cfg


## --- Helper: Create Gradient Texture for color ramp ---

func _create_gradient(color_start: Color, color_end: Color) -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, color_start)
	gradient.set_color(1, color_end)
	return gradient


func _set_particle_property_if_available(particle: CPUParticles2D, property_name: StringName, value: Variant) -> void:
	for property: Dictionary in particle.get_property_list():
		if property.get("name", "") == String(property_name):
			particle.set(property_name, value)
			return
