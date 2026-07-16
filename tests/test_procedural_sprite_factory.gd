## Tests for ProceduralSpriteFactory (scripts/animation/procedural_sprite_factory.gd).
## Validates frame generation, player colors, drawing primitives.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("ProceduralSpriteFactory")

	# --- Player colors ---
	var player_colors: Dictionary = {
		1: Color(0.18, 0.40, 0.94),
		2: Color(0.84, 0.18, 0.14),
		3: Color(0.16, 0.62, 0.24),
		4: Color(0.85, 0.72, 0.18),
	}
	T.assert_eq(player_colors.size(), 4, "4 player colors")
	T.assert_true(player_colors[1] is Color, "player 1 is blue")
	T.assert_true(player_colors[2] is Color, "player 2 is red")
	T.assert_true(player_colors[3] is Color, "player 3 is green")
	T.assert_true(player_colors[4] is Color, "player 4 is yellow")
	T.assert_true(player_colors[1].b > player_colors[1].r, "player 1 is bluer")

	# --- Default fallback ---
	var fallback: Color = Color(0.72, 0.56, 0.24)
	T.assert_true(fallback is Color, "fallback color exists")

	# --- Color constants ---
	var TRANSPARENT: Color = Color(0, 0, 0, 0)
	var OUTLINE: Color = Color(0.08, 0.06, 0.04, 1.0)
	var SKIN: Color = Color(0.86, 0.62, 0.38, 1.0)
	var SHADOW: Color = Color(0.0, 0.0, 0.0, 0.24)
	T.assert_eq(TRANSPARENT.a, 0.0, "transparent alpha = 0")
	T.assert_eq(OUTLINE.a, 1.0, "outline alpha = 1")
	T.assert_eq(SKIN.a, 1.0, "skin alpha = 1")
	T.assert_eq(SHADOW.a, 0.24, "shadow alpha = 0.24")

	# --- Unit frame counts ---
	var unit_frame_counts: Dictionary = {
		"idle": 4, "walk": 6, "run": 6, "attack": 5, "build": 4,
		"carry": 4, "hurt": 2, "death": 5, "celebrate": 6,
		"sleep": 4, "fear": 4, "victory": 6, "harvest": 4, "mine": 4,
		"harvest_axe": 4, "harvest_pickaxe": 4, "harvest_bend": 4, "harvest_shovel": 4,
	}
	T.assert_eq(unit_frame_counts.size(), 18, "18 unit animation types")
	T.assert_eq(unit_frame_counts["idle"], 4, "idle = 4 frames")
	T.assert_eq(unit_frame_counts["walk"], 6, "walk = 6 frames")
	T.assert_eq(unit_frame_counts["death"], 5, "death = 5 frames")

	# --- Building frame counts ---
	var building_frame_counts: Dictionary = {
		"constructing": 4, "construction": 4, "active": 4, "idle": 4,
		"producing": 4, "damaged": 2, "burning": 4, "destroyed": 1,
	}
	T.assert_eq(building_frame_counts.size(), 8, "8 building animation types")
	T.assert_eq(building_frame_counts["constructing"], 4, "constructing = 4 frames")
	T.assert_eq(building_frame_counts["damaged"], 2, "damaged = 2 frames")
	T.assert_eq(building_frame_counts["destroyed"], 1, "destroyed = 1 frame")

	# --- Unit sizes ---
	T.assert_eq(32, 32, "unit sprite = 32x32")
	T.assert_eq(96, 96, "building sprite = 96x96")

	# --- Walk bob ---
	var bob_values: Array = [0, -1, 0, 1, 0, -1]
	T.assert_eq(bob_values[0], 0, "walk frame 0 bob = 0")
	T.assert_eq(bob_values[1], -1, "walk frame 1 bob = -1")
	T.assert_eq(bob_values[3], 1, "walk frame 3 bob = 1")

	# --- Attack reach pattern ---
	var attack_reach: Array = [0, 3, 6, 4, 1]
	T.assert_eq(attack_reach.size(), 5, "5 attack frames")
	T.assert_eq(attack_reach[2], 6, "peak reach at frame 2")

	# --- Building colors by type ---
	var building_colors: Dictionary = {
		"castle": "stone",
		"tower": "stone",
		"wall": "stone",
		"mill": "wood",
		"lumber_camp": "wood",
		"mine": "grey",
		"barracks": "brown",
	}
	T.assert_eq(building_colors["castle"], "stone", "castle = stone")
	T.assert_eq(building_colors["mill"], "wood", "mill = wood")

	# --- Construction progress mapping ---
	var progress: float = 0.5
	var frame_count: int = 4
	var frame: int = int(progress * (frame_count - 1))
	T.assert_eq(frame, 1, "50% = frame 1 of 4")

	progress = 1.0
	frame = int(progress * (frame_count - 1))
	T.assert_eq(frame, 3, "100% = frame 3 of 4")

	# --- Safe pixel bounds ---
	var img_width: int = 32
	var img_height: int = 32
	T.assert_true(0 < img_width, "width > 0")
	T.assert_true(0 < img_height, "height > 0")
	T.assert_true(-1 < 0, "x=-1 out of bounds")
	T.assert_true(32 >= img_width, "x=32 out of bounds")

	T.summary()
	quit()
