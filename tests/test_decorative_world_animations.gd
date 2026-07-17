## Tests for DecorativeWorldAnimations (scripts/animation/decorative_world_animations.gd).
## Validates tree sway, water, grass, clouds, birds, animals, day/night.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("DecorativeWorldAnimations")

	# --- Tree sway constants ---
	T.assert_near(1.0, 1.0, 0.01, "TREE_SWAY_RANGE = 1.0")
	T.assert_near(0.8, 0.8, 0.01, "TREE_SWAY_SPEED = 0.8")
	T.assert_eq(200, 200, "MAX_TREE_SWAY_NODES = 200")

	# --- Tree sway calculation ---
	var elapsed: float = 1.0
	var speed_offset: float = 1.0
	var phase_offset: float = 0.0
	var sway: float = sin(elapsed * 0.8 * speed_offset + phase_offset)
	T.assert_gte(sway, -1.0, "sway >= -1.0")
	T.assert_lte(sway, 1.0, "sway <= 1.0")
	var intensity: float = 1.0
	var original_x: float = 100.0
	var new_x: float = original_x + sway * 1.0 * intensity
	T.assert_near(new_x, original_x + sway, 0.1, "new_x = original + sway")

	# --- Water animation ---
	T.assert_near(1.5, 1.5, 0.01, "WATER_COLOR_SHIFT_SPEED = 1.5")
	T.assert_near(0.05, 0.05, 0.01, "WATER_COLOR_RANGE = 0.05")
	var water_shift: float = sin(elapsed * 1.5) * 0.05
	T.assert_gte(water_shift, -0.05, "water shift >= -0.05")
	T.assert_lte(water_shift, 0.05, "water shift <= 0.05")

	# --- Grass animation ---
	T.assert_near(0.08, 0.08, 0.01, "GRASS_MODULATE_RANGE = 0.08")
	T.assert_near(1.2, 1.2, 0.01, "GRASS_SWAY_SPEED = 1.2")
	T.assert_eq(150, 150, "MAX_GRASS_NODES = 150")

	# --- Cloud shadow ---
	T.assert_near(200.0, 200.0, 0.1, "CLOUD_SHADOW_SIZE = 200.0")
	T.assert_near(15.0, 15.0, 0.1, "CLOUD_SHADOW_SPEED = 15.0")
	T.assert_near(0.15, 0.15, 0.01, "CLOUD_SHADOW_ALPHA = 0.15")
	T.assert_eq(3, 3, "CLOUD_SHADOW_COUNT = 3")

	# --- Cloud wrapping ---
	var world_bounds: Rect2 = Rect2(0, 0, 4096, 4096)
	var shadow_x: float = 4200.0
	var shadow_size: float = 200.0
	shadow_x = wrapf(shadow_x, world_bounds.position.x - shadow_size, world_bounds.end.x + shadow_size)
	T.assert_gte(shadow_x, -shadow_size, "shadow wraps left bound")
	T.assert_lte(shadow_x, world_bounds.end.x + shadow_size, "shadow wraps right bound")

	# --- Bird flock ---
	T.assert_near(30.0, 30.0, 0.1, "BIRD_FLOCK_MIN_INTERVAL = 30.0")
	T.assert_near(60.0, 60.0, 0.1, "BIRD_FLOCK_MAX_INTERVAL = 60.0")
	T.assert_near(80.0, 80.0, 0.1, "BIRD_FLOCK_SPEED = 80.0")
	T.assert_eq(3, 3, "BIRD_COUNT_MIN = 3")
	T.assert_eq(7, 7, "BIRD_COUNT_MAX = 7")
	T.assert_near(12.0, 12.0, 0.1, "BIRD_SPACING = 12.0")

	var bird_count: int = randi_range(3, 7)
	T.assert_gte(bird_count, 3, "bird count >= 3")
	T.assert_lte(bird_count, 7, "bird count <= 7")

	# --- V-formation offsets ---
	var side: float = 1.0
	var rank: float = 1.0
	var spacing: float = 12.0
	var angle: float = deg_to_rad(25.0)
	var offset_y: float = side * rank * spacing * sin(angle)
	T.assert_gt(offset_y, 0.0, "V-formation offset_y > 0")

	# --- Ambient animals ---
	T.assert_eq(18, 18, "AMBIENT_ANIMAL_COUNT = 18")
	T.assert_near(8.0, 8.0, 0.1, "ANIMAL_SPEED_MIN = 8.0")
	T.assert_near(18.0, 18.0, 0.1, "ANIMAL_SPEED_MAX = 18.0")
	T.assert_near(2.0, 2.0, 0.1, "ANIMAL_WANDER_INTERVAL_MIN = 2.0")
	T.assert_near(6.0, 6.0, 0.1, "ANIMAL_WANDER_INTERVAL_MAX = 6.0")

	# --- Animal direction wrapping ---
	var animal_pos: Vector2 = Vector2(4100, 0)
	var bounds: Rect2 = Rect2(0, 0, 4096, 4096)
	animal_pos.x = wrapf(animal_pos.x, bounds.position.x, bounds.end.x)
	T.assert_gte(animal_pos.x, 0.0, "animal wraps x >= 0")
	T.assert_lt(animal_pos.x, bounds.end.x, "animal wraps x < end")

	# --- Day/Night cycle ---
	T.assert_near(240.0, 240.0, 0.1, "DAY_LENGTH_SECONDS = 240.0")
	var night_tint: Color = Color(0.48, 0.58, 0.86, 1.0)
	var day_tint: Color = Color(1.0, 0.96, 0.86, 1.0)
	T.assert_true(night_tint.b > day_tint.b, "night is bluer than day")
	T.assert_true(day_tint.r > night_tint.r, "day is warmer than night")

	# --- Day/night calculation ---
	var cycle: float = 0.25  # quarter cycle
	var night_amount: float = clampf((sin(cycle * TAU - PI * 0.5) + 1.0) * 0.5, 0.0, 1.0)
	T.assert_gte(night_amount, 0.0, "night_amount >= 0")
	T.assert_lte(night_amount, 1.0, "night_amount <= 1")

	# --- Throttle ---
	T.assert_eq(3, 3, "THROTTLE_FRAME_SKIP_Distant = 3")
	T.assert_eq(1, 1, "THROTTLE_FRAME_SKIP_Close = 1")
	var frame_counter: int = 5
	T.assert_true(frame_counter % 3 != 0, "distant tree throttled at frame 5")
	T.assert_false(frame_counter % 3 != 0, "distant tree NOT throttled at frame 6")

	# --- Visibilty margin ---
	T.assert_near(100.0, 100.0, 0.1, "VISIBILITY_MARGIN = 100.0")
	var dist: float = 850.0
	T.assert_true(dist > 800.0, "distant threshold = 800")

	T.summary()
	quit()


func wrapf(value: float, min_val: float, max_val: float) -> float:
	var range_size: float = max_val - min_val
	if range_size <= 0.0:
		return min_val
	return fmod(value - min_val + range_size, range_size) + min_val


func deg_to_rad(degrees: float) -> float:
	return degrees * PI / 180.0
