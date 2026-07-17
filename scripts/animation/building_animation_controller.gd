## Building Animation Controller
## Manages building visual states, construction progress, damage states,
## and ambient animated effects (smoke, torches, flags, mill blades).
## Attach as a child node of a Building that has an AnimatedSprite2D child.
class_name BuildingAnimationController
extends Node

const ProceduralFactory = preload("res://scripts/animation/procedural_sprite_factory.gd")

# --- Signals ---
signal construction_completed
signal building_destroyed_visual
signal production_pulse

# --- Constants ---
const CONSTRUCTION_FRAMES: int = 3
const TORCH_FLICKER_MIN: float = 0.7
const TORCH_FLICKER_MAX: float = 1.0
const TORCH_FLICKER_SPEED: float = 4.0
const FLAG_SWING_ANGLE: float = 5.0
const FLAG_SWING_DURATION: float = 1.5
const MILL_ROTATION_SPEED: float = 30.0
const DAMAGE_CRACKS_THRESHOLD: float = 0.66
const DAMAGE_FIRE_THRESHOLD: float = 0.33
const PRODUCTION_BOUNCE_AMOUNT: float = -2.0
const PRODUCTION_BOUNCE_DURATION: float = 0.2
const PRODUCTION_FLASH_DURATION: float = 0.15
const SMOKE_PARTICLE_AMOUNT: int = 8
const SMOKE_PARTICLE_LIFETIME: float = 2.0
const FIRE_PARTICLE_AMOUNT: int = 12
const FIRE_PARTICLE_LIFETIME: float = 1.5
# Construction stages.
const STAGE_FOUNDATION_MAX: float = 0.25
const STAGE_FRAMING_MAX: float = 0.60
const STAGE_FINISHING_MAX: float = 0.90

# --- Exported Properties ---
@export var production_pulse_interval: float = 1.0
@export var enable_torch_flicker: bool = true
@export var enable_flag_wave: bool = true
@export var enable_mill_rotation: bool = false

# --- Node References ---
var _sprite: AnimatedSprite2D = null
var _parent_building: Node2D = null
var _construction_bar: Control = null
var _cracks_overlay: Sprite2D = null
var _fire_particles: CPUParticles2D = null
var _smoke_particles: CPUParticles2D = null
var _torch_light: Light2D = null
var _flag_sprite: Sprite2D = null
var _mill_blades: Node2D = null

# --- State ---
var _current_state: String = "active"
var _damage_level: float = 1.0
var _construction_progress: float = 0.0
var _construction_stage: int = 0
var _is_producing: bool = false
var _is_on_fire: bool = false
var _torch_tween: Tween = null
var _flag_tween: Tween = null
var _mill_tween: Tween = null
var _production_tween: Tween = null
var _completion_tween: Tween = null
var _production_timer: float = 0.0


## --- Lifecycle ---

func _ready() -> void:
	_find_parent_building()
	_find_sprite_node()
	if _sprite:
		_ensure_sprite_frames()
	_setup_sub_nodes()
	if _sprite:
		_sprite.animation_finished.connect(_on_animation_finished)


func _process(delta: float) -> void:
	if _is_producing:
		_production_timer -= delta
		if _production_timer <= 0.0:
			_play_production_pulse()
			_production_timer = production_pulse_interval


func _exit_tree() -> void:
	_kill_all_tweens()


## --- Setup ---

func _find_sprite_node() -> void:
	if _sprite:
		return
	if _parent_building == null:
		_find_parent_building()
	if _parent_building != null:
		_sprite = _get_child_sprite(_parent_building)
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


func _find_parent_building() -> void:
	_parent_building = get_parent() as Node2D


## Find or create sub-nodes for effects.
func _setup_sub_nodes() -> void:
	# Cracks overlay
	_cracks_overlay = _find_or_create_child(self, "CracksOverlay")
	_cracks_overlay.visible = false
	_cracks_overlay.z_index = 1
	# Fire particles
	_fire_particles = _find_or_create_cpuparticles(self, "FireParticles")
	_fire_particles.emitting = false
	_fire_particles.amount = FIRE_PARTICLE_AMOUNT
	_fire_particles.lifetime = FIRE_PARTICLE_LIFETIME
	_fire_particles.gravity = Vector2(0, -40)
	_fire_particles.color = Color(1.0, 0.4, 0.1, 0.8)
	_fire_particles.scale_amount_min = 0.5
	_fire_particles.scale_amount_max = 1.5
	_fire_particles.z_index = 2
	# Smoke particles
	_smoke_particles = _find_or_create_cpuparticles(self, "SmokeParticles")
	_smoke_particles.emitting = false
	_smoke_particles.amount = SMOKE_PARTICLE_AMOUNT
	_smoke_particles.lifetime = SMOKE_PARTICLE_LIFETIME
	_smoke_particles.gravity = Vector2(0, -20)
	_smoke_particles.color = Color(0.4, 0.4, 0.4, 0.6)
	_smoke_particles.scale_amount_min = 0.3
	_smoke_particles.scale_amount_max = 1.0
	_smoke_particles.z_index = 2
	# Torch light
	_torch_light = _find_child_by_type(self, Light2D)
	if _torch_light and enable_torch_flicker:
		_start_torch_flicker()
	# Flag sprite
	_flag_sprite = _find_child_by_name(self, "Flag")
	if _flag_sprite and enable_flag_wave:
		_start_flag_wave()
	# Mill blades
	_mill_blades = _find_child_by_name(self, "MillBlades")
	if _mill_blades and enable_mill_rotation:
		_start_mill_rotation()


func _find_or_create_child(parent: Node, node_name: String, _type: StringName = &"Sprite2D") -> Sprite2D:
	var existing = parent.get_node_or_null(node_name)
	if existing:
		return existing
	var new_node: Sprite2D = Sprite2D.new()
	new_node.name = node_name
	parent.add_child(new_node)
	new_node.owner = parent.owner if parent.owner else null
	return new_node


func _find_or_create_cpuparticles(parent: Node, node_name: String) -> CPUParticles2D:
	var existing = parent.get_node_or_null(node_name)
	if existing is CPUParticles2D:
		return existing
	var new_particles: CPUParticles2D = CPUParticles2D.new()
	new_particles.name = node_name
	parent.add_child(new_particles)
	new_particles.owner = parent.owner if parent.owner else null
	return new_particles


func _find_child_by_type(node: Node, type) -> Node:
	for child in node.get_children():
		if is_instance_of(child, type):
			return child
		var result = _find_child_by_type(child, type)
		if result:
			return result
	return null


func _find_child_by_name(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child
		var result = _find_child_by_name(child, target_name)
		if result:
			return result
	return null


## --- Public API ---

## Set the building's visual state.
func set_state(new_state: String) -> void:
	var valid_states: Array[String] = [
		"constructing", "active", "producing", "damaged", "burning", "destroyed"
	]
	if not new_state in valid_states:
		push_warning("BuildingAnimationController: Unknown state '%s'" % new_state)
		return
	_current_state = new_state
	_apply_state_visuals()


## Set construction progress from 0.0 to 1.0 with stage feedback.
func set_construction_progress(progress: float) -> void:
	var old_progress: float = _construction_progress
	_construction_progress = clampf(progress, 0.0, 1.0)

	# Determine construction stage for visual feedback.
	var new_stage: int = 0
	if _construction_progress >= STAGE_FINISHING_MAX:
		new_stage = 3
	elif _construction_progress >= STAGE_FRAMING_MAX:
		new_stage = 2
	elif _construction_progress >= STAGE_FOUNDATION_MAX:
		new_stage = 1

	# Emit signal on stage change for particle/sound effects.
	if new_stage != _construction_stage:
		_construction_stage = new_stage

	# Map progress to construction frames (0-2).
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("constructing"):
		var frame_count: int = _sprite.sprite_frames.get_frame_count("constructing")
		var frame: int = int(_construction_progress * (frame_count - 1))
		_sprite.play("constructing")
		_sprite.frame = frame

	# Scale construction smoke with progress (more at start, less near end).
	if _smoke_particles:
		var smoke_intensity: float = 1.0 - _construction_progress * 0.6
		_smoke_particles.amount = int(float(SMOKE_PARTICLE_AMOUNT) * smoke_intensity)
		_smoke_particles.emitting = _construction_progress < 1.0 and _construction_progress > 0.0

	# Update construction bar.
	_update_construction_bar()

	# Emit completion with burst effect.
	if _construction_progress >= 1.0 and old_progress < 1.0:
		_play_completion_burst()
		construction_completed.emit()
		set_state("active")


## Set damage level. 1.0 = full health, 0.0 = destroyed.
func set_damage_level(level: float) -> void:
	_damage_level = clampf(level, 0.0, 1.0)
	_apply_damage_visuals()
	if _damage_level <= 0.0:
		set_state("destroyed")


## Start production animation cycle.
func start_production() -> void:
	_is_producing = true
	_production_timer = production_pulse_interval
	set_state("producing")


## Stop production animation.
func stop_production() -> void:
	_is_producing = false
	if _current_state == "producing":
		set_state("active")


## Set the building on fire with particle effects.
func set_on_fire() -> void:
	_is_on_fire = true
	_fire_particles.emitting = true
	_smoke_particles.emitting = true
	# Position fire at building center
	if _parent_building:
		_fire_particles.position = Vector2(0, -10)
		_smoke_particles.position = Vector2(0, -20)


## Extinguish fire effects.
func extinguish_fire() -> void:
	_is_on_fire = false
	_fire_particles.emitting = false
	_smoke_particles.emitting = false


## Set a chimney smoke source at a local position.
func set_chimney_smoke(pos: Vector2, enabled: bool = true) -> void:
	_smoke_particles.position = pos
	_smoke_particles.emitting = enabled


func setup_building_visuals(building_type: String, player_id: int, grid_size: Vector2i) -> void:
	_find_sprite_node()
	if not _sprite:
		push_warning("BuildingAnimationController: AnimatedSprite2D not found for '%s'." % building_type)
		return
	_sprite.sprite_frames = ProceduralFactory.create_building_frames(building_type, player_id, grid_size)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0, -16)
	_sprite.z_index = 6
	_apply_state_visuals()


## Get current construction progress.
func get_construction_progress() -> float:
	return _construction_progress


## Get current damage level.
func get_damage_level() -> float:
	return _damage_level


## --- Internal Visual Methods ---

func _apply_state_visuals() -> void:
	match _current_state:
		"constructing":
			if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("constructing"):
				_sprite.play("constructing")
			extinguish_fire()
			_cracks_overlay.visible = false
			# Start construction smoke.
			if _smoke_particles:
				_smoke_particles.emitting = true
				_smoke_particles.position = Vector2(0, -12)
		"active":
			if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("active"):
				_sprite.play("active")
			extinguish_fire()
			_cracks_overlay.visible = false
			_apply_damage_visuals()
			# Stop construction smoke.
			if _smoke_particles:
				_smoke_particles.emitting = false
		"producing":
			if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("producing"):
				_sprite.play("producing")
			extinguish_fire()
		"damaged":
			if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("damaged"):
				_sprite.play("damaged")
			_cracks_overlay.visible = true
		"burning":
			if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("burning"):
				_sprite.play("burning")
			set_on_fire()
		"destroyed":
			if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("destroyed"):
				_sprite.play("destroyed")
			elif _sprite:
				_sprite.stop()
				_sprite.frame = _sprite.sprite_frames.get_frame_count("active") - 1 if _sprite.sprite_frames.has_animation("active") else 0
			_cracks_overlay.visible = false
			_fire_particles.emitting = false
			_smoke_particles.emitting = true
			building_destroyed_visual.emit()


func _ensure_sprite_frames() -> void:
	if not _sprite:
		return
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("active"):
		return
	var b_type: String = "town_center"
	var owner_id: int = 1
	var size: Vector2i = Vector2i(2, 2)
	if _parent_building and _parent_building.has_method("get"):
		var raw_type: Variant = _parent_building.get("building_type")
		var raw_player: Variant = _parent_building.get("player_id")
		var raw_size: Variant = _parent_building.get("grid_size")
		if raw_type is String and not raw_type.is_empty():
			b_type = raw_type
		if raw_player is int and raw_player > 0:
			owner_id = raw_player
		if raw_size is Vector2i:
			size = raw_size
	_sprite.sprite_frames = ProceduralFactory.create_building_frames(b_type, owner_id, size)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0, -16)
	_sprite.z_index = 6


func _apply_damage_visuals() -> void:
	# Show cracks overlay when below damage threshold.
	if _damage_level < DAMAGE_CRACKS_THRESHOLD and _damage_level > DAMAGE_FIRE_THRESHOLD:
		_cracks_overlay.visible = true
		_current_state = "damaged"
		# Increase smoke as damage worsens.
		if _smoke_particles:
			var smoke_rate: float = 1.0 - (_damage_level - DAMAGE_FIRE_THRESHOLD) / (DAMAGE_CRACKS_THRESHOLD - DAMAGE_FIRE_THRESHOLD)
			_smoke_particles.amount = int(float(SMOKE_PARTICLE_AMOUNT) * (0.3 + smoke_rate * 0.7))
			_smoke_particles.emitting = true
			_smoke_particles.position = Vector2(0, -15)
	elif _damage_level <= DAMAGE_FIRE_THRESHOLD and _damage_level > 0.0:
		_cracks_overlay.visible = true
		if not _is_on_fire:
			set_on_fire()
	elif _damage_level >= DAMAGE_CRACKS_THRESHOLD:
		_cracks_overlay.visible = false
		if _smoke_particles:
			_smoke_particles.emitting = false


## Play a completion burst effect when construction finishes.
func _play_completion_burst() -> void:
	if not _sprite:
		return
	# White flash + bounce.
	var original_y: float = _sprite.position.y
	if _completion_tween and _completion_tween.is_valid():
		_completion_tween.kill()
	_completion_tween = create_tween().set_parallel(true)
	_completion_tween.tween_property(
		_sprite, "modulate",
		Color(1.5, 1.5, 1.5, 1.0),
		0.12
	)
	_completion_tween.tween_property(
		_sprite, "position:y",
		original_y - 4.0,
		0.15
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_completion_tween.chain().tween_property(
		_sprite, "modulate", Color.WHITE,
		0.25
	)
	_completion_tween.tween_property(
		_sprite, "position:y", original_y,
		0.2
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Emit construction smoke burst.
	if _smoke_particles:
		_smoke_particles.amount = SMOKE_PARTICLE_AMOUNT * 2
		_smoke_particles.emitting = true
		_completion_tween.tween_interval(0.5)
		_completion_tween.tween_callback(func(): _smoke_particles.emitting = false)
	production_pulse.emit()


func _update_construction_bar() -> void:
	# If there's a progress bar child, update it
	if not _construction_bar:
		_construction_bar = _find_progress_bar(self)
	if _construction_bar:
		if _construction_bar is TextureProgressBar:
			_construction_bar.value = _construction_progress * 100.0
		elif _construction_bar is ColorRect:
			_construction_bar.size.x = _construction_progress * 50.0


func _find_progress_bar(node: Node) -> Control:
	for child in node.get_children():
		if child is TextureProgressBar or child is ProgressBar:
			return child
		if child is ColorRect and child.name == "ConstructionBar":
			return child
		var result = _find_progress_bar(child)
		if result:
			return result
	return null


## --- Ambient Effects ---

func _start_torch_flicker() -> void:
	if not _torch_light:
		return
	var original_energy: float = _torch_light.energy
	_torch_tween = create_tween().set_loops()
	_torch_tween.tween_property(
		_torch_light, "energy",
		randf_range(TORCH_FLICKER_MIN, TORCH_FLICKER_MAX),
		randf_range(0.1, 0.3)
	).set_trans(Tween.TRANS_SINE)
	_torch_tween.tween_property(
		_torch_light, "energy",
		original_energy,
		randf_range(0.1, 0.3)
	).set_trans(Tween.TRANS_SINE)


func _start_flag_wave() -> void:
	if not _flag_sprite:
		return
	var original_rotation: float = _flag_sprite.rotation_degrees
	_flag_tween = create_tween().set_loops()
	_flag_tween.tween_property(
		_flag_sprite, "rotation_degrees",
		original_rotation + FLAG_SWING_ANGLE,
		FLAG_SWING_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flag_tween.tween_property(
		_flag_sprite, "rotation_degrees",
		original_rotation - FLAG_SWING_ANGLE,
		FLAG_SWING_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flag_tween.tween_property(
		_flag_sprite, "rotation_degrees",
		original_rotation,
		FLAG_SWING_DURATION * 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_mill_rotation() -> void:
	if not _mill_blades:
		return
	_mill_tween = create_tween().set_loops()
	_mill_tween.tween_property(
		_mill_blades, "rotation_degrees",
		_mill_blades.rotation_degrees + 360.0,
		360.0 / MILL_ROTATION_SPEED
	).set_trans(Tween.TRANS_LINEAR)


## --- Production Animation ---

func _play_production_pulse() -> void:
	if not _sprite:
		return
	# Small bounce
	var original_y: float = _sprite.position.y
	if _production_tween and _production_tween.is_valid():
		_production_tween.kill()
	_production_tween = create_tween().set_parallel(true)
	_production_tween.tween_property(
		_sprite, "position:y",
		original_y + PRODUCTION_BOUNCE_AMOUNT,
		PRODUCTION_BOUNCE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_production_tween.tween_property(
		_sprite, "modulate",
		Color(1.3, 1.3, 1.3, 1.0),
		PRODUCTION_FLASH_DURATION
	)
	_production_tween.chain().tween_property(
		_sprite, "position:y", original_y,
		PRODUCTION_BOUNCE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_production_tween.tween_property(
		_sprite, "modulate", Color.WHITE,
		PRODUCTION_FLASH_DURATION
	)
	production_pulse.emit()


## --- Cleanup ---

func _kill_all_tweens() -> void:
	for tween in [_torch_tween, _flag_tween, _mill_tween, _production_tween]:
		if tween and tween.is_valid():
			tween.kill()


## --- Signal Callbacks ---

func _on_animation_finished() -> void:
	if _current_state == "constructing" and _construction_progress < 1.0:
		# Loop construction animation
		if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("constructing"):
			_sprite.play("constructing")
