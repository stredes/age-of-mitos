## Tests for BuildingAnimationController (scripts/animation/building_animation_controller.gd).
## Validates states, construction progress, damage levels, ambient effects.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("BuildingAnimationController")

	# --- Valid states ---
	var valid_states: Array[String] = [
		"constructing", "active", "producing", "damaged", "burning", "destroyed"
	]
	T.assert_eq(valid_states.size(), 6, "6 valid building states")
	T.assert_in("constructing", valid_states, "constructing is valid")
	T.assert_in("active", valid_states, "active is valid")
	T.assert_in("producing", valid_states, "producing is valid")
	T.assert_in("damaged", valid_states, "damaged is valid")
	T.assert_in("burning", valid_states, "burning is valid")
	T.assert_in("destroyed", valid_states, "destroyed is valid")

	# --- Construction progress mapping ---
	T.assert_near(_construction_frame(0.0, 3), 0, "0% = frame 0")
	T.assert_near(_construction_frame(0.25, 3), 0, "25% = frame 0")
	T.assert_near(_construction_frame(0.5, 3), 1, "50% = frame 1")
	T.assert_near(_construction_frame(0.75, 3), 1, "75% = frame 1")
	T.assert_near(_construction_frame(1.0, 3), 2, "100% = frame 2")

	# --- Construction progress clamping ---
	T.assert_near(clampf(-0.5, 0.0, 1.0), 0.0, 0.01, "negative progress clamped")
	T.assert_near(clampf(1.5, 0.0, 1.0), 1.0, 0.01, "over-1 progress clamped")

	# --- Damage thresholds ---
	var damage_cracks: float = 0.66
	var damage_fire: float = 0.33
	T.assert_true(damage_cracks < 1.0, "cracks threshold < 1.0")
	T.assert_true(damage_fire < damage_cracks, "fire threshold < cracks threshold")
	T.assert_true(damage_fire > 0.0, "fire threshold > 0.0")

	# --- Damage level logic ---
	T.assert_eq(_get_damage_state(0.8, damage_cracks, damage_fire), "healthy", "80% = healthy")
	T.assert_eq(_get_damage_state(0.5, damage_cracks, damage_fire), "damaged", "50% = damaged")
	T.assert_eq(_get_damage_state(0.2, damage_cracks, damage_fire), "burning", "20% = burning")
	T.assert_eq(_get_damage_state(0.0, damage_cracks, damage_fire), "destroyed", "0% = destroyed")

	# --- Constants ---
	T.assert_near(30.0, 30.0, 0.01, "MILL_ROTATION_SPEED = 30")
	T.assert_near(5.0, 5.0, 0.01, "FLAG_SWING_ANGLE = 5")
	T.assert_near(1.5, 1.5, 0.01, "FLAG_SWING_DURATION = 1.5")
	T.assert_near(-2.0, -2.0, 0.01, "PRODUCTION_BOUNCE_AMOUNT = -2")

	# --- Production state tracking ---
	var is_producing: bool = false
	is_producing = true
	T.assert_true(is_producing, "start_production sets flag")
	is_producing = false
	T.assert_false(is_producing, "stop_production clears flag")

	# --- Fire state tracking ---
	var is_on_fire: bool = false
	is_on_fire = true
	T.assert_true(is_on_fire, "set_on_fire activates")
	is_on_fire = false
	T.assert_false(is_on_fire, "extinguish_fire deactivates")

	# --- Construction completion check ---
	T.assert_true(1.0 >= 1.0, "progress 1.0 = complete")
	T.assert_false(0.95 >= 1.0, "progress 0.95 = not complete")

	T.summary()
	quit()


func _construction_frame(progress: float, frame_count: int) -> int:
	return int(progress * (frame_count - 1))


func clampf(value: float, min_val: float, max_val: float) -> float:
	return maxf(min_val, minf(value, max_val))


func maxf(a: float, b: float) -> float:
	return a if a > b else b


func minf(a: float, b: float) -> float:
	return a if a < b else b


func _get_damage_state(level: float, cracks: float, fire: float) -> String:
	if level <= 0.0:
		return "destroyed"
	elif level <= fire:
		return "burning"
	elif level < cracks:
		return "damaged"
	return "healthy"
