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
@export var max_fog_particles: int = 26

var current_weather: WeatherType = WeatherType.CLEAR
var target_intensity: float = 0.0
var intensity: float = 0.0
var wind_strength: float = 0.15
var wind_direction: Vector2 = Vector2.RIGHT

var _weather_timer: float = 0.0
var _rain_particles: CPUParticles2D = null
var _fog_layer: Node2D = null
var _storm_flash: ColorRect = null
var _lightning_timer: float = 0.0
var _camera: Camera2D = null


func _ready() -> void:
	_camera = get_viewport().get_camera_2d()
	_create_rain()
	_create_fog()
	_create_storm_flash()
	_pick_next_weather()


func _process(delta: float) -> void:
	if not enabled:
		return
	_find_camera_if_needed()
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


func _update_weather_visuals(delta: float) -> void:
	var view: Rect2 = _get_camera_view()
	global_position = view.get_center()

	if _rain_particles:
		_rain_particles.position = Vector2(0, -view.size.y * 0.48)
		_rain_particles.emission_rect_extents = Vector2(view.size.x * 0.55, 16)
		var rain_active: bool = current_weather == WeatherType.RAIN or current_weather == WeatherType.STORM
		_rain_particles.emitting = rain_active and intensity > 0.04
		_rain_particles.amount = int(float(max_rain_particles) * clampf(intensity, 0.15, 1.0))
		_rain_particles.modulate.a = intensity
		_rain_particles.gravity.x = -220.0 * wind_strength * wind_direction.x

	if _fog_layer:
		_fog_layer.visible = intensity > 0.02 and (current_weather == WeatherType.FOG or current_weather == WeatherType.STORM)
		for child in _fog_layer.get_children():
			if child is ColorRect:
				child.position.x += wind_direction.x * (8.0 + wind_strength * 22.0) * delta
				if child.position.x > view.size.x * 0.55:
					child.position.x = -view.size.x * 0.55
				child.color.a = 0.10 * intensity

	if _storm_flash:
		_storm_flash.size = view.size
		_storm_flash.position = -view.size * 0.5
		if current_weather == WeatherType.STORM and intensity > 0.5:
			_lightning_timer -= delta
			if _lightning_timer <= 0.0:
				_lightning_timer = randf_range(5.0, 12.0)
				_storm_flash.color.a = 0.45 * intensity
		_storm_flash.color.a = move_toward(_storm_flash.color.a, 0.0, delta * 2.8)


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
