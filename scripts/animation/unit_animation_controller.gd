extends Node

## UnitAnimationController
# Controla animaciones procedurales y por sprites de las unidades.
# Compatible con ProceduralSpriteFactory y SpriteFrames cargados desde disco.

@export_group("Node References")
@export_node_path("AnimatedSprite2D") var sprite_path: NodePath
@export_node_path("UnitBase") var unit_base_path: NodePath

@export_group("Animation Config")
@export var enable_procedural: bool = true
@export var enable_carry_visual: bool = true
@export var carry_offset: Vector2 = Vector2(0, -16)
@export var carry_scale: float = 0.6
@export var bounce_intensity: float = 0.15
@export var bounce_speed: float = 12.0
@export var squash_intensity: float = 0.25
@export var squash_duration: float = 0.15
@export var spawn_squash_intensity: float = 0.5
@export var spawn_squash_duration: float = 0.3

@export_group("Carry Sprites (Procedural)")
@export var carry_wood_sprite: Texture2D
@export var carry_stone_sprite: Texture2D
@export var carry_food_sprite: Texture2D
@export var carry_gold_sprite: Texture2D

@onready var sprite: AnimatedSprite2D = get_node(sprite_path) if sprite_path else null
@onready var unit: UnitBase = get_node(unit_base_path) if unit_base_path else null

var carry_sprite: Sprite2D
var carry_type: String = ""
var carry_visible: bool = false
var walk_time: float = 0.0
var squash_t: float = 0.0
var spawn_squash_t: float = 0.0
var is_spawning: bool = false
var current_state: String = "idle"

func _ready() -> void:
	if not sprite:
		sprite = get_parent().get_node_or_null("AnimatedSprite2D")
	if not unit:
		unit = get_parent() as UnitBase
	
	_setup_carry_sprite()
	_setup_spawn_animation()
	
	if unit:
		unit.animation_changed.connect(_on_animation_changed)
		unit.state_changed.connect(_on_state_changed)
		unit.resource_carried_changed.connect(_on_resource_carried_changed)
		# Also connect to state machine for state changes
		var state_machine = unit.get_node_or_null("UnitStateMachine")
		if state_machine:
			state_machine.state_changed.connect(_on_state_changed_from_machine)

func _setup_carry_sprite() -> void:
	if not enable_carry_visual or not sprite:
		return
	
	carry_sprite = Sprite2D.new()
	carry_sprite.name = "CarrySprite"
	carry_sprite.position = carry_offset
	carry_sprite.scale = Vector2(carry_scale, carry_scale)
	carry_sprite.z_index = sprite.z_index + 1
	carry_sprite.visible = false
	sprite.add_child(carry_sprite)

func _setup_spawn_animation() -> void:
	is_spawning = true
	spawn_squash_t = 0.0
	if sprite:
		sprite.scale = Vector2(1.0 + spawn_squash_intensity, 1.0 - spawn_squash_intensity * 0.5)

func _process(delta: float) -> void:
	_process_walk_bounce(delta)
	_process_squash(delta)
	_process_spawn_squash(delta)

func _process_walk_bounce(delta: float) -> void:
	if not enable_procedural or not sprite or not unit:
		return
	
	if current_state == "walk" or current_state == "move":
		walk_time += delta * bounce_speed
		var bounce = sin(walk_time) * bounce_intensity
		sprite.position.y = bounce
		if carry_sprite and carry_visible:
			carry_sprite.position.y = carry_offset.y + bounce * 0.5
	else:
		walk_time = 0.0
		sprite.position.y = lerp(sprite.position.y, 0.0, delta * 10.0)
		if carry_sprite and carry_visible:
			carry_sprite.position.y = lerp(carry_sprite.position.y, carry_offset.y, delta * 10.0)

func _process_squash(delta: float) -> void:
	if squash_t > 0.0:
		squash_t -= delta / squash_duration
		var t = clamp(squash_t / squash_duration, 0.0, 1.0)
		var squash = sin(t * PI) * squash_intensity
		if sprite:
			sprite.scale = Vector2(1.0 + squash, 1.0 - squash * 0.5)

func _process_spawn_squash(delta: float) -> void:
	if not is_spawning:
		return
	
	spawn_squash_t += delta
	var t = clamp(spawn_squash_t / spawn_squash_duration, 0.0, 1.0)
	
	var easing = 1.0 - pow(1.0 - t, 3.0)
	var squash = spawn_squash_intensity * (1.0 - easing)
	
	if sprite:
		sprite.scale = Vector2(
			1.0 + squash * 0.5,
			1.0 - squash
		)
		sprite.position.y = -squash * 8.0
	
	if carry_sprite and carry_visible:
		carry_sprite.scale = Vector2(carry_scale, carry_scale) * Vector2(1.0 + squash * 0.3, 1.0 - squash * 0.3)
	
	if t >= 1.0:
		is_spawning = false
		if sprite:
			sprite.scale = Vector2(1.0, 1.0)
			sprite.position.y = 0.0
		if carry_sprite and carry_visible:
			carry_sprite.scale = Vector2(carry_scale, carry_scale)

func trigger_squash(intensity: float = 1.0) -> void:
	squash_t = squash_duration * intensity

func trigger_spawn_squash() -> void:
	is_spawning = true
	spawn_squash_t = 0.0
	if sprite:
		sprite.scale = Vector2(1.0 + spawn_squash_intensity * 0.5, 1.0 - spawn_squash_intensity)

func _on_animation_changed(anim_name: String) -> void:
	current_state = anim_name
	walk_time = 0.0

func _on_state_changed(new_state: String) -> void:
	current_state = new_state
	if new_state == "spawn" or new_state == "spawn_idle":
		trigger_spawn_squash()
	elif new_state == "idle":
		walk_time = 0.0

func _on_state_changed_from_machine(old_state: String, new_state: String) -> void:
	_on_state_changed(new_state)

func _on_resource_carried_changed(resource_type: String, amount: int) -> void:
	if not enable_carry_visual or not carry_sprite:
		return
	
	if resource_type == "" || amount <= 0:
		carry_visible = false
		carry_sprite.visible = false
		carry_type = ""
		return
	
	carry_type = resource_type
	carry_visible = true
	carry_sprite.visible = true
	
	if enable_procedural and ProceduralSpriteFactory:
		var carry_tex = _get_procedural_carry_texture(resource_type)
		if carry_tex:
			carry_sprite.texture = carry_tex
			return
	
	carry_sprite.texture = _get_carry_texture(resource_type)

func _get_carry_texture(resource_type: String) -> Texture2D:
	match resource_type.to_lower():
		"wood", "wood_bundle": return carry_wood_sprite
		"stone", "stone_sack": return carry_stone_sprite
		"food", "food_basket": return carry_food_sprite
		"gold", "gold_sack": return carry_gold_sprite
		_: return null

func _get_procedural_carry_texture(resource_type: String) -> Texture2D:
	match resource_type.to_lower():
		"wood", "wood_bundle":
			return ProceduralSpriteFactory.create_wood_bundle()
		"stone", "stone_sack":
			return ProceduralSpriteFactory.create_stone_sack()
		"food", "food_basket":
			return ProceduralSpriteFactory.create_food_basket()
		"gold", "gold_sack":
			return ProceduralSpriteFactory.create_gold_sack()
		_:
			return null

func play_animation(anim_name: String, custom_speed: float = 1.0) -> void:
	if sprite and sprite.has_animation(anim_name):
		sprite.play(anim_name)
		sprite.speed_scale = custom_speed
		current_state = anim_name
		if unit:
			unit.animation_changed.emit(anim_name)

func stop_animation() -> void:
	if sprite:
		sprite.stop()
		current_state = "idle"

func get_current_animation() -> String:
	return current_state

func play_state(anim_name: String, direction: String = "") -> void:
	play_animation(anim_name)

func _on_unit_spawned() -> void:
	trigger_spawn_squash()

func _on_unit_damaged() -> void:
	trigger_squash(0.8)

func _on_attack() -> void:
	trigger_squash(0.4)

func _on_harvest() -> void:
	trigger_squash(0.3)