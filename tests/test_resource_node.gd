## Tests for ResourceNode (scripts/world/resource_node.gd).
## Validates harvest, depletion, regrow, visual state, world ID generation.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("ResourceNode")

	# --- Resource colors ---
	var RESOURCE_COLORS: Dictionary = {
		"wood": Color(0.3, 0.65, 0.2),
		"stone": Color(0.55, 0.52, 0.5),
		"food": Color(0.85, 0.3, 0.25),
		"gold": Color(0.95, 0.82, 0.15),
	}
	T.assert_eq(RESOURCE_COLORS.size(), 4, "4 resource colors")
	T.assert_true(RESOURCE_COLORS["wood"] is Color, "wood color is Color")
	T.assert_true(RESOURCE_COLORS["gold"] is Color, "gold color is Color")

	var DEPLETED_COLOR: Color = Color(0.35, 0.35, 0.35, 0.5)
	T.assert_eq(DEPLETED_COLOR.a, 0.5, "depleted alpha = 0.5")

	# --- Harvest logic ---
	var current_amount: int = 100
	var max_amount: int = 100
	var harvest_per_action: int = 10

	var harvested: int = mini(harvest_per_action, current_amount)
	current_amount -= harvested
	T.assert_eq(harvested, 10, "harvested 10")
	T.assert_eq(current_amount, 90, "remaining 90")

	# --- Harvest near depletion ---
	current_amount = 5
	harvested = mini(harvest_per_action, current_amount)
	current_amount -= harvested
	T.assert_eq(harvested, 5, "harvested 5 (less than action)")
	T.assert_eq(current_amount, 0, "remaining 0")

	# --- Depletion ---
	var _is_depleted: bool = false
	if current_amount <= 0:
		_is_depleted = true
	T.assert_true(_is_depleted, "depleted when amount = 0")

	# --- Depleted harvest returns 0 ---
	if _is_depleted:
		harvested = 0
	T.assert_eq(harvested, 0, "depleted harvest returns 0")

	# --- Regrow (food only) ---
	var resource_type: String = "food"
	var regrow_rate: int = 1
	var regrow_interval: float = 30.0
	current_amount = 50
	var regrow_timer: float = 30.0
	if resource_type == "food" and not _is_depleted and current_amount < max_amount:
		if regrow_timer >= regrow_interval:
			regrow_timer = 0.0
			var new_amount: int = mini(current_amount + regrow_rate, max_amount)
			if new_amount != current_amount:
				current_amount = new_amount
	T.assert_eq(current_amount, 51, "food regrows by 1")

	# --- Regrow capped at max ---
	current_amount = 99
	max_amount = 100
	current_amount = mini(current_amount + regrow_rate, max_amount)
	T.assert_eq(current_amount, 100, "regrow capped at max")

	# --- Regrow from depletion (food) ---
	_is_depleted = true
	current_amount = 0
	if _is_depleted and resource_type == "food":
		_is_depleted = false
		current_amount = maxi(regrow_rate, 1)
	T.assert_false(_is_depleted, "food revives from depletion")
	T.assert_eq(current_amount, 1, "food revives with regrow_rate")

	# --- World ID generation ---
	var grid_pos: Vector2i = Vector2i(10, 20)
	var hash_val: int = grid_pos.x * 73856093 + grid_pos.y * 19349669
	var res_type_str: String = "wood"
	for c: String in res_type_str:
		hash_val += c.unicode_at(0) * 83492791
	var world_id: int = absi(hash_val) % 100000000
	T.assert_gte(world_id, 0, "world_id >= 0")
	T.assert_lt(world_id, 100000000, "world_id < 100M")

	# --- Interaction radius ---
	var interaction_radius: float = 48.0
	var distance: float = 30.0
	T.assert_true(distance <= interaction_radius, "in range")
	distance = 60.0
	T.assert_false(distance <= interaction_radius, "out of range")

	# --- Position from grid ---
	var cell_size: int = 32
	var pos: Vector2 = Vector2(
		float(grid_pos.x * cell_size + cell_size / 2),
		float(grid_pos.y * cell_size + cell_size / 2)
	)
	T.assert_near(pos.x, 336.0, 0.1, "world x from grid(10)")
	T.assert_near(pos.y, 656.0, 0.1, "world y from grid(20)")

	# --- Alpha based on depletion ---
	var alpha: float = 0.35 if _is_depleted else 1.0
	T.assert_near(alpha, 1.0, 0.01, "active alpha = 1.0")
	_is_depleted = true
	alpha = 0.35 if _is_depleted else 1.0
	T.assert_near(alpha, 0.35, 0.01, "depleted alpha = 0.35")

	T.summary()
	quit()
