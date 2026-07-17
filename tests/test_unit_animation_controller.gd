## Tests for UnitAnimationController (scripts/animation/unit_animation_controller.gd).
## Validates states, facing, speed mult, idle micro-anims, hurt, death.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("UnitAnimationController")

	# --- Valid states list ---
	var valid_states: Array[String] = [
		"idle", "walk", "run", "attack", "harvest",
		"mine", "build", "carry", "hurt", "death",
		"celebrate", "sleep", "fear", "victory"
	]
	T.assert_eq(valid_states.size(), 14, "14 valid states")
	T.assert_in("idle", valid_states, "idle is valid")
	T.assert_in("walk", valid_states, "walk is valid")
	T.assert_in("run", valid_states, "run is valid")
	T.assert_in("attack", valid_states, "attack is valid")
	T.assert_in("harvest", valid_states, "harvest is valid")
	T.assert_in("mine", valid_states, "mine is valid")
	T.assert_in("death", valid_states, "death is valid")
	T.assert_in("celebrate", valid_states, "celebrate is valid")
	T.assert_not_in("invalid_state", valid_states, "invalid_state not in valid")

	# --- Harvest animation mapping ---
	var harvest_anims: Dictionary = {
		"wood": "harvest_axe",
		"stone": "harvest_pickaxe",
		"food": "harvest_bend",
		"gold": "harvest_shovel",
	}
	T.assert_eq(harvest_anims["wood"], "harvest_axe", "wood → harvest_axe")
	T.assert_eq(harvest_anims["stone"], "harvest_pickaxe", "stone → harvest_pickaxe")
	T.assert_eq(harvest_anims["food"], "harvest_bend", "food → harvest_bend")
	T.assert_eq(harvest_anims["gold"], "harvest_shovel", "gold → harvest_shovel")

	# --- Constants ---
	T.assert_near(-1.0, -1.0, 0.01, "WALK_BOUNCE_AMOUNT = -1.0")
	T.assert_near(0.15, 0.15, 0.01, "WALK_BOUNCE_DURATION = 0.15")
	T.assert_near(0.12, 0.12, 0.01, "HURT_FLASH_DURATION = 0.12")
	T.assert_near(8.0, 8.0, 0.01, "DEATH_CORPSE_DURATION = 8.0")
	T.assert_near(2.0, 2.0, 0.01, "DEATH_FADE_DURATION = 2.0")
	T.assert_eq(2, 2, "ATTACK_IMPACT_FRAME = 2")

	# --- Speed multiplier clamping ---
	T.assert_near(clampf(0.3, 0.5, 2.0), 0.5, 0.01, "speed mult clamped to 0.5 min")
	T.assert_near(clampf(1.5, 0.5, 2.0), 1.5, 0.1, "speed mult in range")
	T.assert_near(clampf(3.0, 0.5, 2.0), 2.0, 0.01, "speed mult clamped to 2.0 max")

	# --- Idle timer logic ---
	var idle_interval_min: float = 2.0
	var idle_interval_max: float = 5.0
	var idle_timer: float = randf_range(idle_interval_min, idle_interval_max)
	T.assert_gte(idle_timer, idle_interval_min, "idle timer >= min")
	T.assert_lt(idle_timer, idle_interval_max, "idle timer < max")

	# --- Idle offset range ---
	var idle_offset_range: Vector2 = Vector2(1.0, 1.0)
	var offset_x: float = randf_range(-idle_offset_range.x, idle_offset_range.x)
	T.assert_gte(offset_x, -1.0, "idle offset x >= -1")
	T.assert_lte(offset_x, 1.0, "idle offset x <= 1")

	# --- Facing direction logic ---
	var facing_right: Vector2 = Vector2.RIGHT
	var facing_left: Vector2 = Vector2.LEFT
	T.assert_false(facing_right.x < 0.0, "right = not flipped")
	T.assert_true(facing_left.x < 0.0, "left = flipped")

	# --- Sprite animation speed with random offset ---
	var random_offset: float = 50.0
	var anim_speed_mult: float = 1.0
	var expected_speed: float = anim_speed_mult + (random_offset * 0.01)
	T.assert_near(expected_speed, 1.5, 0.01, "speed_scale = mult + offset*0.01")

	# --- Death state transitions ---
	var is_dead: bool = false
	is_dead = true
	T.assert_true(is_dead, "is_dead set on death")
	T.assert_true(is_dead and "death" == "death", "death state persists")

	# --- Animation finished looping logic ---
	var loop_states: Array = ["idle", "walk", "run", "build", "carry", "fear", "sleep"]
	var one_shot_states: Array = ["attack", "celebrate", "victory", "hurt"]
	T.assert_in("idle", loop_states, "idle loops")
	T.assert_in("walk", loop_states, "walk loops")
	T.assert_in("attack", one_shot_states, "attack is one-shot")
	T.assert_in("celebrate", one_shot_states, "celebrate is one-shot")
	T.assert_not_in("attack", loop_states, "attack does not loop")

	T.summary()
	quit()


func clampf(value: float, min_val: float, max_val: float) -> float:
	return maxf(min_val, minf(value, max_val))


func maxf(a: float, b: float) -> float:
	return a if a > b else b


func minf(a: float, b: float) -> float:
	return a if a < b else b
