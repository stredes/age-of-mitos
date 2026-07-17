## Unit Animation Controller
## Manages AnimatedSprite2D animations for units with expressive micro-animations.
## Attach as a child node of a Unit that has an AnimatedSprite2D child.
class_name UnitAnimationController
extends Node

const ProceduralFactory = preload("res://scripts/animation/procedural_sprite_factory.gd")

# --- Signals ---
signal animation_attack_impact
signal animation_death_finished

# --- Constants ---
const WALK_BOUNCE_AMOUNT: float = -1.0
const WALK_BOUNCE_DURATION: float = 0.15
const IDLE_OFFSET_RANGE: Vector2 = Vector2(1.0, 1.0)
const IDLE_DURATION_MIN: float = 0.5
const IDLE_DURATION_MAX: float = 1.0
const IDLE_INTERVAL_MIN: float = 2.0
const IDLE_INTERVAL_MAX: float = 5.0
const HURT_FLASH_DURATION: float = 0.12
const HURT_KNOCKBACK_PX: float = 2.0
const HURT_KNOCKBACK_DURATION: float = 0.1
const DEATH_CORPSE_DURATION: float = 8.0
const DEATH_FADE_DURATION: float = 2.0
const ATTACK_IMPACT_FRAME: int = 2
const MIN_SPEED_MULT: float = 0.5
const MAX_SPEED_MULT: float = 2.0
const STATE_TRANSITION_DURATION: float = 0.1
const ATTACK_SWING_ANGLE: float = 12.0

# --- Exported Properties ---
@export var corpse_duration: float = DEATH_CORPSE_DURATION
@export var death_fade_duration: float = DEATH_FADE_DURATION
@export var enable_idle_micro_animations: bool = true

# --- Node References ---
var _sprite: AnimatedSprite2D = null
var _parent_unit: Node2D = null

# --- State ---
var _current_state: String = "idle"
var _previous_state: String = "idle"
var _facing_direction: Vector2 = Vector2.RIGHT
var _anim_speed_mult: float = 1.0
var _unit_id: String = ""
var _is_dead: bool = false
var _idle_timer: float = 0.0
var _next_idle_interval: float = 3.0
var _current_tween: Tween = null
var _idle_tween: Tween = null
var _death_tween: Tween = null
var _transition_tween: Tween = null
var _random_offset: float = 0.0

# Harvest resource type mapping to animation names
var _harvest_animations: Dictionary = {
	"wood": "harvest_axe",
	"stone": "harvest_pickaxe",
	"food": "harvest_bend",
	"gold": "harvest_shovel",
}

# Valid states
var _valid_states: Array[String] = [
	"idle", "walk", "run", "attack", "harvest",
	"mine", "build", "carry", "hurt", "death",
	"celebrate", "sleep", "fear", "victory"
]


## --- Lifecycle ---

func _ready() -> void:
	_random_offset = randf_range(0.0, 100.0)
	_unit_id = str(randi()) if _unit_id.is_empty() else _unit_id
	_find_parent_unit()
	_find_sprite_node()
	if _sprite:
		_ensure_sprite_frames()
		_sprite.animation_finished.connect(_on_animation_finished)
		_sprite.frame_changed.connect(_on_frame_changed)
	_reset_idle_timer()


func _process(delta: float) -> void:
	if _is_dead:
		return
	if _current_state == "idle" and enable_idle_micro_animations:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_play_idle_micro_animation()
			_reset_idle_timer()


func _exit_tree() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()


## --- Setup Methods ---

## Recursively finds an AnimatedSprite2D child node.
func _find_sprite_node() -> void:
	if _sprite:
		return
	if _parent_unit == null:
		_find_parent_unit()
	if _parent_unit != null:
		_sprite = _get_child_sprite(_parent_unit)
	if _sprite == null:
		_sprite = _get_child_sprite(self)


func _get_child_sprite(node: Node) -> AnimatedSprite2D:
	for child in node.get_children():
		if child is AnimatedSprite2D:
			return child
		var result = _get_child_sprite(child)
		if result:
			return result
	return null


func _find_parent_unit() -> void:
	_parent_unit = get_parent() as Node2D


## --- Public API ---

## Play a named animation state with optional facing direction.
func play_state(state_name: String, direction: Vector2 = Vector2.ZERO) -> void:
	if _is_dead and state_name != "death":
		return
	if not state_name in _valid_states:
		push_warning("UnitAnimationController: Unknown state '%s'" % state_name)
		return
	if not _sprite:
		return
	if direction != Vector2.ZERO:
		_facing_direction = direction.normalized()

	# Skip if already in this state.
	if state_name == _current_state and _sprite.is_playing():
		_apply_facing()
		return

	_apply_facing()

	# Handle harvest sub-types.
	if state_name == "harvest":
		_play_harvest_state()
		return
	if state_name == "mine":
		_previous_state = _current_state
		_current_state = "mine"
		_transition_to("mine")
		return

	# Smooth transition for state changes.
	var needs_transition: bool = _current_state != state_name
	_previous_state = _current_state
	_current_state = state_name

	if needs_transition and _previous_state in ["idle", "walk", "run", "build", "carry"]:
		_crossfade_to(state_name)
	else:
		_set_sprite_animation(state_name)


## Crossfade to a new animation by fading out the current and playing the new one.
func _crossfade_to(state_name: String) -> void:
	if not _sprite:
		return
	# For instant transitions, just play the new animation.
	_set_sprite_animation(state_name)


## Transition to a new animation state.
func _transition_to(state_name: String) -> void:
	if not _sprite:
		return
	_set_sprite_animation(state_name)


## Play the hurt flash + knockback effect, then return to previous state.
func play_hurt() -> void:
	if _is_dead or not _sprite:
		return
	# White flash
	var original_modulate: Color = _sprite.modulate
	_sprite.modulate = Color(10.0, 10.0, 10.0, 1.0)
	# Knockback
	var knockback_dir: Vector2 = -_facing_direction
	var original_position: Vector2 = _sprite.position
	# Tween flash + knockback
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(_sprite, "modulate", original_modulate, HURT_FLASH_DURATION)
	_current_tween.tween_property(
		_sprite, "position",
		original_position + knockback_dir * HURT_KNOCKBACK_PX,
		HURT_KNOCKBACK_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_current_tween.chain().tween_property(
		_sprite, "position", original_position,
		HURT_KNOCKBACK_DURATION * 1.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.finished.connect(_on_hurt_tween_finished.bind(original_modulate), CONNECT_ONE_SHOT)


func _on_hurt_tween_finished(original_modulate: Color) -> void:
	if _sprite:
		_sprite.modulate = original_modulate
	# Return to previous state.
	play_state(_previous_state)


## Play the death sequence: death anim -> corpse hold -> fade -> free.
func play_death() -> void:
	if _is_dead or not _sprite:
		return
	_is_dead = true
	_current_state = "death"
	# Stop any running tweens
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	# Play the death animation
	_set_sprite_animation("death")
	# Wait for death animation to finish before corpse phase
	if not _sprite.animation_finished.is_connected(_on_death_anim_finished):
		_sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	if not _sprite:
		return
	# Set to last frame as corpse
	_sprite.frame = _sprite.sprite_frames.get_frame_count("death") - 1
	_sprite.stop()
	# Dim the corpse
	var target_alpha: float = 0.6
	_sprite.modulate.a = target_alpha
	# After corpse_duration, fade out
	_death_tween = create_tween()
	_death_tween.tween_interval(corpse_duration - death_fade_duration)
	_death_tween.tween_property(_sprite, "modulate:a", 0.0, death_fade_duration)
	_death_tween.tween_callback(_on_death_corpse_finished)


func _on_death_corpse_finished() -> void:
	animation_death_finished.emit()
	queue_free()


## Set the facing direction for sprite flipping.
func set_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	_facing_direction = direction.normalized()
	_apply_facing()


## Set the animation speed multiplier (1.0 = normal).
func set_animation_speed_multiplier(mult: float) -> void:
	_anim_speed_mult = clampf(mult, MIN_SPEED_MULT, MAX_SPEED_MULT)
	if _sprite and _sprite.speed_scale > 0:
		_sprite.speed_scale = _anim_speed_mult + _random_offset * 0.01


## Get the current animation state name.
func get_current_state() -> String:
	return _current_state


## Check if the current animation has finished playing.
func is_animation_finished() -> bool:
	if not _sprite:
		return true
	return _sprite.frame >= _sprite.sprite_frames.get_frame_count(_sprite.animation) - 1


## Get the random offset value (for syncing with other systems).
func get_random_offset() -> float:
	return _random_offset


## Set the unit ID for debugging and sync.
func set_unit_id(id: String) -> void:
	_unit_id = id


func setup_unit_visuals(unit_type: String, player_id: int) -> void:
	_find_sprite_node()
	if not _sprite:
		push_warning("UnitAnimationController: AnimatedSprite2D not found for '%s'." % unit_type)
		return
	_sprite.sprite_frames = ProceduralFactory.create_unit_frames(unit_type, player_id)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0, -8)
	_sprite.z_index = 3
	play_state(_current_state)


## Set the sprite frame directly (for network sync).
func set_frame(frame_index: int) -> void:
	if _sprite:
		_sprite.frame = frame_index


## Force stop all animations and tweens.
func stop_all() -> void:
	if _sprite:
		_sprite.stop()
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()


## --- Internal Methods ---

## Apply horizontal flip based on facing direction.
func _apply_facing() -> void:
	if not _sprite:
		return
	_sprite.flip_h = _facing_direction.x < 0.0


func _ensure_sprite_frames() -> void:
	if not _sprite:
		return
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("idle"):
		return
	var unit_type: String = "villager"
	var owner_id: int = 1
	if _parent_unit and _parent_unit.has_method("get"):
		var raw_type: Variant = _parent_unit.get("unit_type")
		var raw_player: Variant = _parent_unit.get("player_id")
		if raw_type is String and not raw_type.is_empty():
			unit_type = raw_type
		if raw_player is int and raw_player > 0:
			owner_id = raw_player
	_sprite.sprite_frames = ProceduralFactory.create_unit_frames(unit_type, owner_id)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0, -8)
	_sprite.z_index = 3


## Set the sprite to play a specific animation by state name.
func _set_sprite_animation(state_name: String) -> void:
	if not _sprite:
		return
	if not _sprite.sprite_frames.has_animation(state_name):
		push_warning("UnitAnimationController: No animation '%s' in SpriteFrames" % state_name)
		return
	_sprite.play(state_name)
	_apply_speed_scale()


## Apply speed scale based on unit speed multiplier + random offset.
func _apply_speed_scale() -> void:
	if not _sprite:
		return
	_sprite.speed_scale = _anim_speed_mult + (_random_offset * 0.01)


## Play harvest animation based on resource type.
func _play_harmest_state() -> void:
	pass


func _play_harvest_state() -> void:
	# Determine resource type from parent if available
	var resource_type: String = "wood"
	if _parent_unit and _parent_unit.has_method("get_harvest_resource_type"):
		resource_type = _parent_unit.get_harvest_resource_type()
	var anim_name: String = _harvest_animations.get(resource_type, "harvest_axe")
	_current_state = "harvest"
	_set_sprite_animation(anim_name)


## Play idle micro-animation: random small position offset with breathing feel.
func _play_idle_micro_animation() -> void:
	if not _sprite or _is_dead:
		return
	var offset_x: float = randf_range(-IDLE_OFFSET_RANGE.x, IDLE_OFFSET_RANGE.x)
	var offset_y: float = randf_range(-IDLE_OFFSET_RANGE.y * 0.5, IDLE_OFFSET_RANGE.y)
	var duration: float = randf_range(IDLE_DURATION_MIN, IDLE_DURATION_MAX)
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(_sprite, "position", Vector2(offset_x, offset_y), duration * 0.5)
	_idle_tween.tween_property(_sprite, "position", Vector2.ZERO, duration * 0.5)


## Reset the idle timer to a random interval.
func _reset_idle_timer() -> void:
	_next_idle_interval = randf_range(IDLE_INTERVAL_MIN, IDLE_INTERVAL_MAX)
	_idle_timer = _next_idle_interval


## --- Signal Callbacks ---

func _on_animation_finished() -> void:
	if _is_dead:
		return
	# Loop most animations
	match _current_state:
		"idle", "walk", "run", "build", "carry", "fear", "sleep":
			if _sprite and _sprite.sprite_frames:
				_sprite.play()
		"attack", "celebrate", "victory", "hurt":
			_current_state = "idle"
			_set_sprite_animation("idle")
		"harvest", "mine":
			# Harvest loops until stopped
			if _sprite:
				_sprite.play()


func _on_frame_changed() -> void:
	if not _sprite:
		return
	# Walk bounce: offset sprite.y briefly on each frame change
	if _current_state == "walk" or _current_state == "run":
		_apply_walk_bounce()
	# Attack impact frame detection
	if _current_state == "attack":
		_check_attack_impact()


## Apply a small vertical bounce synced to walk animation frames.
func _apply_walk_bounce() -> void:
	if not _sprite:
		return
	var original_y: float = 0.0
	var bounce_tween: Tween = create_tween()
	bounce_tween.tween_property(_sprite, "position:y", WALK_BOUNCE_AMOUNT, WALK_BOUNCE_DURATION * 0.5).set_trans(Tween.TRANS_SINE)
	bounce_tween.tween_property(_sprite, "position:y", original_y, WALK_BOUNCE_DURATION * 0.5).set_trans(Tween.TRANS_SINE)


## Check if the current frame is the attack impact frame.
func _check_attack_impact() -> void:
	if not _sprite:
		return
	if _sprite.frame == ATTACK_IMPACT_FRAME:
		animation_attack_impact.emit()
