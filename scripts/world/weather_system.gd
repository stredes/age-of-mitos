class_name WeatherSystem
extends Node2D

signal weather_changed(weather_type: String, intensity: float)
signal wind_changed(strength: float, direction: Vector2)

enum WeatherType {
	CLEAR,
	RAIN,
	FOG,
	STORM,
	STRONG_WIND,
}

const WEATHER_NAMES: Dictionary = {
	WeatherType.CLEAR: "clear",
	WeatherType.RAIN: "rain",
	WeatherType.FOG: "fog",
	WeatherType.STORM: "storm",
	WeatherType.STRONG_WIND: "strong_wind",
}

@export var enabled: bool = true
@export var auto_cycle: bool = true
@export var min_weather_duration: float = 55.0
@export var max_weather_duration: float = 120.0
@export var transition_speed: float = 0.8
@export var max_rain_particles: int = 120
@export var max_fog_particles: int = 30
@export var max_splash_particles: int = 40
@export var max_wind_debris: int = 12

var current_weather: WeatherType = WeatherType.CLEAR
var target_intensity: float = 0.0
var intensity: float = 0.0
var wind_strength: float = 0.15
var wind_direction: Vector2 = Vector2.RIGHT

var _weather_timer: float = 0.0
var _rain_particles: CPUParticles2D = null
var _splash_particles: CPUParticles2D = null
var _fog_layer: Node2D = null
var _fog_drift_offsets: Array[float] = []
var _wind_debris_layer: Node2D = null
var _storm_flash: ColorRect = null
var _storm_tint: ColorRect = null
var _lightning_timer: float = 0.0
var _camera: Camera2D = null
var _elapsed: float = 0.0


func _ready() -> void:
	_camera = get_viewport().get_camera_2d()
	_create_rain()
	_create_splash()
	_create_fog()
	_create_wind_debris()
	_create_storm_flash()
	_create_storm_tint()
	_pick_next_weather()


func _process(delta: float) -> void:
	if not enabled:
		return
	_find_camera_if_needed()
	_elapsed += delta
	if auto_cycle:
		_weather_timer -= delta
		if _weather_timer <= 0.0:
			_pick_next_weather()

	intensity = move_toward(intensity, target_intensity, transition_speed * delta)
	_update_weather_visuals(delta)
	_update_wind(delta)


func set_weather(weather_type: WeatherType, new_intensity: float = 1.0, duration: float = -1.0) -> void:
	current_weather = weather_type
	target_intensity = clampf(new_intensity, 0.0, 1.0)
	_weather_timer = duration if duration > 0.0 else randf_range(min_weather_duration, max_weather_duration)
	weather_changed.emit(WEATHER_NAMES.get(current_weather, "clear"), target_intensity)


func _pick_next_weather() -> void:
	var roll: float = randf()
	if roll < 0.45:
		set_weather(WeatherType.CLEAR, 0.0)
	elif roll < 0.68:
		set_weather(WeatherType.STRONG_WIND, randf_range(0.35, 0.65))
	elif roll < 0.84:
		set_weather(WeatherType.RAIN, randf_range(0.45, 0.85))
	elif roll < 0.95:
		set_weather(WeatherType.FOG, randf_range(0.30, 0.70))
	else:
		set_weather(WeatherType.STORM, randf_range(0.70, 1.0))


func _create_rain() -> void:
	_rain_particles = CPUParticles2D.new()
	_rain_particles.name = "WeatherRain"
	_rain_particles.amount = max_rain_particles
	_rain_particles.lifetime = 0.9
	_rain_particles.emitting = false
	_rain_particles.one_shot = false
	_rain_particles.explosiveness = 0.0
	_rain_particles.spread = 8.0
	_rain_particles.gravity = Vector2(-80, 900)
	_rain_particles.initial_velocity_min = 420.0
	_rain_particles.initial_velocity_max = 650.0
	_rain_particles.scale_amount_min = 0.35
	_rain_particles.scale_amount_max = 0.8
	_rain_particles.color = Color(0.55, 0.72, 0.95, 0.55)
	_rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain_particles.emission_rect_extents = Vector2(520, 16)
	_rain_particles.z_index = 100
	add_child(_rain_particles)


func _create_fog() -> void:
	_fog_layer = Node2D.new()
	_fog_layer.name = "WeatherFog"
	_fog_layer.z_index = 98
	add_child(_fog_layer)
	for i in range(max_fog_particles):
		var patch: ColorRect = ColorRect.new()
		patch.name = "FogPatch_%d" % i
		patch.size = Vector2(randf_range(120.0, 260.0), randf_range(28.0, 70.0))
		patch.position = Vector2(randf_range(-500.0, 500.0), randf_range(-280.0, 280.0))
		patch.color = Color(0.76, 0.80, 0.82, 0.0)
		_fog_layer.add_child(patch)


func _create_storm_flash() -> void:
	_storm_flash = ColorRect.new()
	_storm_flash.name = "LightningFlash"
	_storm_flash.color = Color(0.65, 0.72, 1.0, 0.0)
	_storm_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storm_flash.z_index = 200
	add_child(_storm_flash)


func _create_splash() -> void:
	_splash_particles = CPUParticles2D.new()
	_splash_particles.name = "WeatherSplash"
	_splash_particles.amount = max_splash_particles
	_splash_particles.lifetime = 0.35
	_splash_particles.emitting = false
	_splash_particles.one_shot = false
	_splash_particles.explosiveness = 0.85
	_splash_particles.spread = 180.0
	_splash_particles.gravity = Vector2(0, -120)
	_splash_particles.initial_velocity_min = 30.0
	_splash_particles.initial_velocity_max = 80.0
	_splash_particles.scale_amount_min = 0.15
	_splash_particles.scale_amount_max = 0.4
	_splash_particles.color = Color(0.65, 0.78, 0.95, 0.45)
	_splash_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_splash_particles.emission_rect_extents = Vector2(480, 180)
	_splash_particles.z_index = 99
	add_child(_splash_particles)


func _create_wind_debris() -> void:
	_wind_debris_layer = Node2D.new()
	_wind_debris_layer.name = "WindDebris"
	_wind_debris_layer.z_index = 101
	add_child(_wind_debris_layer)
	for i in range(max_wind_debris):
		var leaf: ColorRect = ColorRect.new()
		leaf.name = "Leaf_%d" % i
		var sz: float = randf_range(3.0, 7.0)
		leaf.size = Vector2(sz, sz * 0.6)
		leaf.position = Vector2(randf_range(-520.0, 520.0), randf_range(-280.0, 280.0))
		var hue: float = randf_range(0.22, 0.38)
		leaf.color = Color.from_hsv(hue, randf_range(0.4, 0.7), randf_range(0.4, 0.65), 0.0)
		_wind_debris_layer.add_child(leaf)


func _create_storm_tint() -> void:
	_storm_tint = ColorRect.new()
	_storm_tint.name = "StormTint"
	_storm_tint.color = Color(0.15, 0.18, 0.30, 0.0)
	_storm_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storm_tint.z_index = 97
	add_child(_storm_tint)


func _update_weather_visuals(delta: float) -> void:
	var view: Rect2 = _get_camera_view()
	global_position = view.get_center()

	# --- Rain ---
	if _rain_particles:
		_rain_particles.position = Vector2(0, -view.size.y * 0.48)
		_rain_particles.emission_rect_extents = Vector2(view.size.x * 0.55, 16)
		var rain_active: bool = current_weather == WeatherType.RAIN or current_weather == WeatherType.STORM
		_rain_particles.emitting = rain_active and intensity > 0.04
		_rain_particles.amount = int(float(max_rain_particles) * clampf(intensity, 0.15, 1.0))
		_rain_particles.modulate.a = intensity
		_rain_particles.gravity.x = -220.0 * wind_strength * wind_direction.x

	# --- Splash (rain hits ground) ---
	if _splash_particles:
		var splash_active: bool = current_weather == WeatherType.RAIN or current_weather == WeatherType.STORM
		_splash_particles.emitting = splash_active and intensity > 0.15
		_splash_particles.position = Vector2(0, view.size.y * 0.35)
		_splash_particles.emission_rect_extents = Vector2(view.size.x * 0.50, 10)
		_splash_particles.modulate.a = intensity * 0.7
		_splash_particles.amount = int(float(max_splash_particles) * clampf(intensity, 0.2, 1.0))

	# --- Fog patches (with vertical drift) ---
	if _fog_layer:
		_fog_layer.visible = intensity > 0.02 and (current_weather == WeatherType.FOG or current_weather == WeatherType.STORM)
		var children: Array = _fog_layer.get_children()
		for i in range(children.size()):
			var child: Node = children[i]
			if child is ColorRect:
				# Horizontal drift with wind.
				child.position.x += wind_direction.x * (8.0 + wind_strength * 22.0) * delta
				if child.position.x > view.size.x * 0.55:
					child.position.x = -view.size.x * 0.55
				elif child.position.x < -view.size.x * 0.55:
					child.position.x = view.size.x * 0.55
				# Slow vertical sine drift for organic movement.
				var v_offset: float = sin(_elapsed * 0.3 + float(i) * 1.7) * 8.0 * delta
				child.position.y += v_offset
				# Vary alpha per patch for depth.
				var depth_factor: float = 0.06 + float(i % 5) * 0.01
				child.color.a = depth_factor * intensity

	# --- Wind debris (leaves, dust) ---
	if _wind_debris_layer:
		var wind_active: bool = current_weather == WeatherType.STRONG_WIND or current_weather == WeatherType.STORM
		_wind_debris_layer.visible = wind_active and intensity > 0.1
		for i in range(_wind_debris_layer.get_child_count()):
			var child: Node = _wind_debris_layer.get_child(i)
			if child is ColorRect:
				# Move with wind + sine wobble.
				var wobble: float = sin(_elapsed * 2.5 + float(i) * 2.1) * 15.0
				child.position.x += (wind_direction.x * (40.0 + wind_strength * 120.0) + wobble) * delta
				child.position.y += sin(_elapsed * 1.8 + float(i)) * 20.0 * delta
				# Wrap around.
				if child.position.x > view.size.x * 0.55:
					child.position.x = -view.size.x * 0.55
					child.position.y = randf_range(-view.size.y * 0.4, view.size.y * 0.4)
				elif child.position.x < -view.size.x * 0.55:
					child.position.x = view.size.x * 0.55
					child.position.y = randf_range(-view.size.y * 0.4, view.size.y * 0.4)
				# Rotate visually.
				child.rotation = _elapsed * 3.0 + float(i) * 1.3
				child.color.a = clampf(intensity * 0.8, 0.0, 0.7)

	# --- Storm flash (lightning) ---
	if _storm_flash:
		_storm_flash.size = view.size
		_storm_flash.position = -view.size * 0.5
		if current_weather == WeatherType.STORM and intensity > 0.5:
			_lightning_timer -= delta
			if _lightning_timer <= 0.0:
				_lightning_timer = randf_range(4.0, 10.0)
				_storm_flash.color.a = 0.50 * intensity
		_storm_flash.color.a = move_toward(_storm_flash.color.a, 0.0, delta * 3.0)

	# --- Storm tint (darkened screen during storms) ---
	if _storm_tint:
		_storm_tint.size = view.size
		_storm_tint.position = -view.size * 0.5
		var tint_target: float = 0.0
		if current_weather == WeatherType.STORM:
			tint_target = 0.18 * intensity
		elif current_weather == WeatherType.FOG:
			tint_target = 0.08 * intensity
		elif current_weather == WeatherType.RAIN:
			tint_target = 0.06 * intensity
		_storm_tint.color.a = move_toward(_storm_tint.color.a, tint_target, delta * 1.2)


func _update_wind(delta: float) -> void:
	var target_wind: float = 0.15
	if current_weather == WeatherType.STRONG_WIND:
		target_wind = 0.75 * intensity
	elif current_weather == WeatherType.RAIN:
		target_wind = 0.35 * intensity
	elif current_weather == WeatherType.STORM:
		target_wind = 0.95 * intensity
	wind_strength = move_toward(wind_strength, target_wind, delta * 0.35)
	wind_direction = wind_direction.rotated(sin(Time.get_ticks_msec() * 0.0002) * delta * 0.08).normalized()
	wind_changed.emit(wind_strength, wind_direction)


func _get_camera_view() -> Rect2:
	if _camera:
		var viewport_size: Vector2 = _camera.get_viewport_rect().size
		return Rect2(_camera.global_position - viewport_size / (2.0 * _camera.zoom), viewport_size / _camera.zoom)
	return Rect2(global_position - Vector2(640, 360), Vector2(1280, 720))


func _find_camera_if_needed() -> void:
	if _camera == null and get_viewport():
		_camera = get_viewport().get_camera_2d()
