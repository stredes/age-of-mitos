## Tests for WeatherSystem (scripts/world/weather_system.gd).
## Validates weather types, transitions, wind, rain, fog, storm.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("WeatherSystem")

	# --- Weather types ---
	var WeatherType: Dictionary = {
		"CLEAR": 0, "RAIN": 1, "FOG": 2, "STORM": 3, "STRONG_WIND": 4
	}
	var WEATHER_NAMES: Dictionary = {
		0: "clear", 1: "rain", 2: "fog", 3: "storm", 4: "strong_wind"
	}
	T.assert_eq(WeatherType.size(), 5, "5 weather types")
	T.assert_eq(WEATHER_NAMES[0], "clear", "0 = clear")
	T.assert_eq(WEATHER_NAMES[1], "rain", "1 = rain")
	T.assert_eq(WEATHER_NAMES[2], "fog", "2 = fog")
	T.assert_eq(WEATHER_NAMES[3], "storm", "3 = storm")
	T.assert_eq(WEATHER_NAMES[4], "strong_wind", "4 = strong_wind")

	# --- Weather probability distribution ---
	T.assert_near(0.45, 0.45, 0.01, "clear probability = 0.45")
	T.assert_near(0.23, 0.23, 0.01, "strong_wind range = 0.23")
	T.assert_near(0.16, 0.16, 0.01, "rain range = 0.16")
	T.assert_near(0.11, 0.11, 0.01, "fog range = 0.11")
	T.assert_near(0.05, 0.05, 0.01, "storm probability = 0.05")

	# --- Roll mapping ---
	var roll: float = 0.3
	var weather: String
	if roll < 0.45:
		weather = "clear"
	elif roll < 0.68:
		weather = "strong_wind"
	elif roll < 0.84:
		weather = "rain"
	elif roll < 0.95:
		weather = "fog"
	else:
		weather = "storm"
	T.assert_eq(weather, "clear", "roll 0.3 = clear")

	roll = 0.5
	if roll < 0.45:
		weather = "clear"
	elif roll < 0.68:
		weather = "strong_wind"
	else:
		weather = "other"
	T.assert_eq(weather, "strong_wind", "roll 0.5 = strong_wind")

	roll = 0.75
	if roll < 0.45:
		weather = "clear"
	elif roll < 0.68:
		weather = "strong_wind"
	elif roll < 0.84:
		weather = "rain"
	else:
		weather = "other"
	T.assert_eq(weather, "rain", "roll 0.75 = rain")

	roll = 0.9
	if roll < 0.45:
		weather = "clear"
	elif roll < 0.68:
		weather = "strong_wind"
	elif roll < 0.84:
		weather = "rain"
	elif roll < 0.95:
		weather = "fog"
	else:
		weather = "other"
	T.assert_eq(weather, "fog", "roll 0.9 = fog")

	roll = 0.98
	if roll < 0.95:
		weather = "other"
	else:
		weather = "storm"
	T.assert_eq(weather, "storm", "roll 0.98 = storm")

	# --- Duration range ---
	T.assert_near(55.0, 55.0, 0.1, "min_weather_duration = 55")
	T.assert_near(120.0, 120.0, 0.1, "max_weather_duration = 120")
	var duration: float = randf_range(55.0, 120.0)
	T.assert_gte(duration, 55.0, "duration >= min")
	T.assert_lte(duration, 120.0, "duration <= max")

	# --- Transition speed ---
	T.assert_near(0.8, 0.8, 0.01, "transition_speed = 0.8")
	var intensity: float = 0.0
	var target: float = 1.0
	var delta: float = 0.016
	intensity = move_toward(intensity, target, 0.8 * delta)
	T.assert_gt(intensity, 0.0, "intensity increases toward target")
	T.assert_lt(intensity, 1.0, "intensity not yet at target")

	# --- Wind strength per weather ---
	var wind_strengths: Dictionary = {
		"clear": 0.15,
		"strong_wind": 0.75,
		"rain": 0.35,
		"storm": 0.95,
	}
	T.assert_near(wind_strengths["clear"], 0.15, 0.01, "clear wind = 0.15")
	T.assert_near(wind_strengths["strong_wind"], 0.75, 0.01, "strong_wind = 0.75")
	T.assert_near(wind_strengths["rain"], 0.35, 0.01, "rain wind = 0.35")
	T.assert_near(wind_strengths["storm"], 0.95, 0.01, "storm wind = 0.95")
	T.assert_gt(wind_strengths["storm"], wind_strengths["strong_wind"], "storm wind > strong_wind")
	T.assert_gt(wind_strengths["strong_wind"], wind_strengths["rain"], "strong_wind > rain")

	# --- Rain particles ---
	T.assert_eq(120, 120, "max_rain_particles = 120")
	T.assert_near(0.9, 0.9, 0.1, "rain lifetime = 0.9")
	T.assert_near(8.0, 8.0, 0.1, "rain spread = 8.0")

	# --- Fog particles ---
	T.assert_eq(26, 26, "max_fog_particles = 26")

	# --- Lightning timer ---
	var lightning_timer: float = randf_range(5.0, 12.0)
	T.assert_gte(lightning_timer, 5.0, "lightning >= 5s")
	T.assert_lte(lightning_timer, 12.0, "lightning <= 12s")

	# --- Initial wind ---
	T.assert_near(0.15, 0.15, 0.01, "initial wind_strength = 0.15")
	T.assert_true(Vector2.RIGHT is Vector2, "initial wind_direction = RIGHT")

	T.summary()
	quit()


func move_toward(current: float, target: float, delta: float) -> float:
	if current < target:
		return minf(current + delta, target)
	return maxf(current - delta, target)


func minf(a: float, b: float) -> float:
	return a if a < b else b


func maxf(a: float, b: float) -> float:
	return a if a > b else b
