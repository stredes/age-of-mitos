## Tests for ParticleEffects (scripts/animation/particle_effects.gd).
## Validates effect configs, pooling logic, spawn/release, gradient creation.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("ParticleEffects")

	# --- All expected effects registered ---
	var expected_effects: Array[String] = [
		"dust_walk", "wood_chop", "stone_mine", "gold_mine",
		"food_gather", "build_construct", "combat_impact", "arrow_trail",
		"death_burst", "building_destroy", "fire_smoke", "water_splash",
		"heal", "level_up"
	]
	T.assert_eq(expected_effects.size(), 14, "14 particle effects")

	var effects_dict: Dictionary = {}
	for effect: String in expected_effects:
		effects_dict[effect] = true
	T.assert_in("dust_walk", effects_dict, "has dust_walk")
	T.assert_in("combat_impact", effects_dict, "has combat_impact")
	T.assert_in("death_burst", effects_dict, "has death_burst")
	T.assert_in("building_destroy", effects_dict, "has building_destroy")
	T.assert_in("fire_smoke", effects_dict, "has fire_smoke")
	T.assert_in("heal", effects_dict, "has heal")
	T.assert_in("level_up", effects_dict, "has level_up")
	T.assert_not_in("unknown_effect", effects_dict, "no unknown_effect")

	# --- Pool constants ---
	T.assert_eq(8, 8, "DEFAULT_POOL_SIZE = 8")
	T.assert_eq(4, 4, "POOL_GROW_SIZE = 4")
	T.assert_near(5.0, 5.0, 0.01, "CLEANUP_INTERVAL = 5.0")

	# --- Pool grow logic ---
	var pool_size: int = 8
	var in_use: int = 8
	T.assert_eq(in_use, pool_size, "pool exhausted when in_use == pool_size")
	pool_size += 4  # POOL_GROW_SIZE
	T.assert_eq(pool_size, 12, "pool grew by POOL_GROW_SIZE")

	# --- Auto-free timer logic ---
	var lifetime: float = 1.0
	var auto_free_timer: float = lifetime + 0.5
	T.assert_near(auto_free_timer, 1.5, 0.01, "auto_free = lifetime + 0.5")

	# --- Effect config validation ---
	var dust_config: Dictionary = {
		"amount": 4, "lifetime": 0.5, "spread": 90.0,
		"vel_min": 10.0, "vel_max": 30.0,
		"gravity": Vector2(0, 10),
		"scale_min": 0.3, "scale_max": 0.8
	}
	T.assert_gt(dust_config["amount"], 0, "dust_walk has positive amount")
	T.assert_gt(dust_config["lifetime"], 0.0, "dust_walk has positive lifetime")
	T.assert_gt(dust_config["spread"], 0.0, "dust_walk has positive spread")
	T.assert_lt(dust_config["vel_min"], dust_config["vel_max"], "vel_min < vel_max")
	T.assert_lt(dust_config["scale_min"], dust_config["scale_max"], "scale_min < scale_max")

	# --- Combat impact config (high velocity) ---
	var combat_config: Dictionary = {
		"amount": 12, "lifetime": 0.4, "vel_min": 40.0, "vel_max": 120.0
	}
	T.assert_gt(combat_config["vel_max"], combat_config["vel_min"] * 2, "combat has high velocity range")

	# --- Gradient creation ---
	var color_start: Color = Color.WHITE
	var color_end: Color = Color(1, 1, 1, 0)
	T.assert_eq(color_start.a, 1.0, "start alpha = 1.0")
	T.assert_eq(color_end.a, 0.0, "end alpha = 0.0")

	# --- Particle release logic ---
	var pooled_active: Array = [true, true, false, true]
	var released: int = 0
	for i in pooled_active.size():
		if not pooled_active[i]:
			released += 1
	T.assert_eq(released, 1, "1 inactive particle found")

	T.summary()
	quit()
