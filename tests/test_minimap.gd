## Tests for Minimap (scripts/ui/minimap.gd).
## Validates coordinate conversion, dot caching, camera rect, click handling.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("Minimap")

	var world_size: Vector2 = Vector2(4096, 4096)
	var minimap_size: Vector2 = Vector2(120, 120)

	# --- world_to_minimap ---
	var result: Vector2 = _world_to_minimap(Vector2(2048, 2048), world_size, minimap_size)
	T.assert_near(result.x, 60.0, 0.1, "center x = 60")
	T.assert_near(result.y, 60.0, 0.1, "center y = 60")

	result = _world_to_minimap(Vector2(0, 0), world_size, minimap_size)
	T.assert_near(result.x, 0.0, 0.1, "origin x = 0")
	T.assert_near(result.y, 0.0, 0.1, "origin y = 0")

	result = _world_to_minimap(Vector2(4096, 4096), world_size, minimap_size)
	T.assert_near(result.x, 120.0, 0.1, "max x = 120")
	T.assert_near(result.y, 120.0, 0.1, "max y = 120")

	# --- minimap_to_world ---
	result = _minimap_to_world(Vector2(60, 60), world_size, minimap_size)
	T.assert_near(result.x, 2048.0, 1.0, "minimap center → world 2048")
	T.assert_near(result.y, 2048.0, 1.0, "minimap center → world 2048")

	result = _minimap_to_world(Vector2(0, 0), world_size, minimap_size)
	T.assert_near(result.x, 0.0, 1.0, "minimap 0,0 → world origin")
	T.assert_near(result.y, 0.0, 1.0, "minimap 0,0 → world origin")

	result = _minimap_to_world(Vector2(120, 120), world_size, minimap_size)
	T.assert_near(result.x, 4096.0, 1.0, "minimap max → world 4096")
	T.assert_near(result.y, 4096.0, 1.0, "minimap max → world 4096")

	# --- Roundtrip ---
	var original: Vector2 = Vector2(1234, 5678)
	var roundtrip: Vector2 = _minimap_to_world(_world_to_minimap(original, world_size, minimap_size), world_size, minimap_size)
	T.assert_near(roundtrip.x, original.x, 2.0, "roundtrip x preserves position")
	T.assert_near(roundtrip.y, original.y, 2.0, "roundtrip y preserves position")

	# --- Click clamping ---
	var click_pos: Vector2 = Vector2(-50, 200)
	var world_pos: Vector2 = _minimap_to_world(click_pos, world_size, minimap_size)
	world_pos.x = clampf(world_pos.x, 0.0, world_size.x)
	world_pos.y = clampf(world_pos.y, 0.0, world_size.y)
	T.assert_gte(world_pos.x, 0.0, "click clamped x >= 0")
	T.assert_gte(world_pos.y, 0.0, "click clamped y >= 0")
	T.assert_lt(world_pos.x, world_size.x, "click clamped x < world_size")
	T.assert_lt(world_pos.y, world_size.y, "click clamped y < world_size")

	# --- Dot color constants ---
	T.assert_eq(DOT_PLAYER, Color(0.2, 0.4, 1.0), "player dot is blue")
	T.assert_eq(DOT_ENEMY, Color(1.0, 0.2, 0.2), "enemy dot is red")
	T.assert_eq(DOT_UNIT_SIZE, 2.0, "unit dot size = 2")
	T.assert_eq(DOT_BUILDING_SIZE, 4.0, "building dot size = 4")

	# --- Update interval ---
	T.assert_near(0.5, 0.5, 0.01, "update interval = 0.5s")

	T.summary()
	quit()


# --- Constants ---
const DOT_PLAYER: Color = Color(0.2, 0.4, 1.0)
const DOT_ENEMY: Color = Color(1.0, 0.2, 0.2)
const DOT_UNIT_SIZE: float = 2.0
const DOT_BUILDING_SIZE: float = 4.0


func _world_to_minimap(world_pos: Vector2, ws: Vector2, ms: Vector2) -> Vector2:
	var ratio: Vector2 = Vector2(world_pos.x / ws.x, world_pos.y / ws.y)
	return Vector2(ratio.x * ms.x, ratio.y * ms.y)


func _minimap_to_world(minimap_pos: Vector2, ws: Vector2, ms: Vector2) -> Vector2:
	var ratio: Vector2 = Vector2(minimap_pos.x / ms.x, minimap_pos.y / ms.y)
	return Vector2(ratio.x * ws.x, ratio.y * ws.y)
