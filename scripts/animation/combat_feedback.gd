## Combat Feedback System
## Attaches to units/buildings to provide visual feedback on damage and death.
## Hit flash: sprite turns white briefly on damage. Death: fade out + particles.
class_name CombatFeedback
extends Node

# =============================================================================
# Configuration
# =============================================================================

@export_group("Hit Flash")
## Duration of the white flash in seconds.
@export var flash_duration: float = 0.1
## The tint applied during the flash.
@export var flash_color: Color = Color.WHITE
## Intensity of the flash (0 = no flash, 1 = full white overlay).
@export var flash_intensity: float = 1.0

@export_group("Death Animation")
## Duration of the fade-out when dying.
@export var death_fade_duration: float = 0.6
## Whether to spawn death particles.
@export var death_particles_enabled: bool = true
## Name of the particle effect to spawn on death.
@export var death_particle_effect: String = "death_burst"
## Delay in seconds before queue_free after death starts.
@export var death_free_delay: float = 0.8

# =============================================================================
# Internal State
# =============================================================================

var _entity: Node2D = null
var _sprite: AnimatedSprite2D = null
var _flash_tween: Tween = null
var _death_tween: Tween = null
var _original_modulate: Color = Color.WHITE
var _is_dead: bool = false

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_entity = _find_entity()
	_sprite = _find_sprite()
	if _sprite:
		_original_modulate = _sprite.modulate

	_connect_damage_signals()


func _connect_damage_signals() -> void:
	if _entity == null:
		return

	# Units: connect to UnitBase.damaged(amount, attacker_id) for hit flash
	if _entity.has_signal("damaged"):
		if not _entity.damaged.is_connected(_on_damaged):
			_entity.damaged.connect(_on_damaged)

	# Units: listen to EventBus.unit_died for death animation
	if _entity.has("unit_id") and _entity.unit_id != -1:
		if not EventBus.unit_died.is_connected(_on_unit_died_event):
			EventBus.unit_died.connect(_on_unit_died_event)

	# Buildings: use EventBus signals for both damage and death
	if _entity is BuildingBase:
		if not EventBus.building_damaged.is_connected(_on_building_damaged_event):
			EventBus.building_damaged.connect(_on_building_damaged_event)
		if not EventBus.building_destroyed.is_connected(_on_building_destroyed_event):
			EventBus.building_destroyed.connect(_on_building_destroyed_event)

# =============================================================================
# Hit Flash
# =============================================================================

func trigger_hit_flash() -> void:
	if _sprite == null or _is_dead:
		return

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_tween = create_tween()
	_flash_tween.tween_property(
		_sprite, "modulate",
		lerp(_original_modulate, flash_color, flash_intensity),
		0.0
	)
	_flash_tween.tween_property(
		_sprite, "modulate",
		_original_modulate,
		flash_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

# =============================================================================
# Death Animation
# =============================================================================

func trigger_death_animation() -> void:
	if _is_dead:
		return
	_is_dead = true

	# Spawn particles
	if death_particles_enabled:
		_spawn_death_particles()

	# Fade out
	_death_tween = create_tween()
	_death_tween.set_parallel(true)

	if _sprite != null:
		_death_tween.tween_property(
			_sprite, "modulate:a",
			0.0,
			death_fade_duration
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Shrink slightly
	if _entity != null:
		_death_tween.tween_property(
			_entity, "scale",
			Vector2(0.5, 0.5),
			death_fade_duration
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	_death_tween.chain().tween_callback(_finish_death).set_delay(death_free_delay)


func _finish_death() -> void:
	pass
	# Do NOT queue_free here — DeadState (units) or BuildingBase._destroy()
	# handles actual removal. CombatFeedback only does visual effects.

# =============================================================================
# Particle Spawning
# =============================================================================

func _spawn_death_particles() -> void:
	var particle_manager: Node = _find_particle_manager()
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect(death_particle_effect, _entity.global_position, 16)


func _find_particle_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_node_recursive(scene, "ParticleEffects")

# =============================================================================
# Signal Handlers
# =============================================================================

func _on_damaged(_amount: int, _attacker_id: int) -> void:
	trigger_hit_flash()


func _on_died(_attacker_id: int) -> void:
	trigger_death_animation()


func _on_unit_died_event(unit_id: int, _killer_id: int, _player_id: int) -> void:
	if _entity != null and _entity.get("unit_id") != null and int(_entity.unit_id) == unit_id:
		trigger_death_animation()


func _on_building_damaged_event(building_id: int, _damage: int, _attacker_id: int) -> void:
	if _entity is BuildingBase and _entity.building_id == building_id:
		trigger_hit_flash()


func _on_building_destroyed_event(building_id: int, _player_id: int, _destroyer_id: int) -> void:
	if _entity is BuildingBase and _entity.building_id == building_id:
		trigger_death_animation()

# =============================================================================
# Node Discovery
# =============================================================================

func _find_entity() -> Node2D:
	var parent: Node = get_parent()
	if parent is Node2D:
		return parent as Node2D
	return null


func _find_sprite() -> AnimatedSprite2D:
	if _entity == null:
		return null
	# Search from parent (same convention as animation controllers)
	var sprite: Node = _entity.get_node_or_null("AnimatedSprite2D")
	if sprite is AnimatedSprite2D:
		return sprite as AnimatedSprite2D
	# Fallback: recursive search
	for child: Node in _entity.get_children():
		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D
		if child.has_method("_find_child_recursive"):
			var found: Node = child._find_child_recursive("AnimatedSprite2D")
			if found is AnimatedSprite2D:
				return found as AnimatedSprite2D
	return null


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_node_recursive(child, target_name)
		if found != null:
			return found
	return null
