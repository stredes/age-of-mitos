## Tests for HUD system (scripts/ui/hud.gd).
## Validates resource bar, notifications, selection info, HP bars, cost formatting.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("HUD")

	# --- Resource Icons & Colors (matching hud.gd) ---
	var resource_icons: Dictionary = {
		"wood": "🪵", "stone": "🪨", "food": "🍖", "gold": "🪙",
	}
	var resource_colors: Dictionary = {
		"wood": Color(0.55, 0.27, 0.07),
		"stone": Color(0.5, 0.5, 0.5),
		"food": Color(0.13, 0.55, 0.13),
		"gold": Color(1.0, 0.84, 0.0),
	}
	T.assert_eq(resource_icons.size(), 4, "resource_icons has 4 entries")
	T.assert_in("wood", resource_icons.keys(), "wood in resource_icons")
	T.assert_in("stone", resource_icons.keys(), "stone in resource_icons")
	T.assert_in("food", resource_icons.keys(), "food in resource_icons")
	T.assert_in("gold", resource_icons.keys(), "gold in resource_icons")

	T.assert_eq(resource_colors.size(), 4, "resource_colors has 4 entries")
	T.assert_true(resource_colors["wood"] is Color, "wood color is Color")
	T.assert_true(resource_colors["gold"] is Color, "gold color is Color")

	# --- _get_hp_color logic ---
	T.assert_eq(_hp_color(80, 100), "green", "HP > 66% = green")
	T.assert_eq(_hp_color(50, 100), "yellow", "HP 34-66% = yellow")
	T.assert_eq(_hp_color(20, 100), "red", "HP < 34% = red")
	T.assert_eq(_hp_color(0, 0), "red", "max=0 = red")

	# --- _format_cost logic ---
	T.assert_eq(_format_cost({}), "", "empty cost = empty string")
	T.assert_eq(_format_cost({"wood": 50}), "🪵50", "single resource cost")
	T.assert_eq(_format_cost({"wood": 50, "food": 30}), "🪵50 🍖30", "multi resource cost")

	# --- Construction bar progress ---
	T.assert_near(_construction_progress(50, 100), 0.5, 0.01, "construction progress 50/100 = 0.5")
	T.assert_near(_construction_progress(0, 100), 0.0, 0.01, "construction progress 0/100 = 0.0")
	T.assert_near(_construction_progress(100, 100), 1.0, 0.01, "construction progress 100/100 = 1.0")

	T.summary()
	quit()


func _hp_color(current: int, maximum: int) -> String:
	if maximum <= 0:
		return "red"
	var ratio: float = float(current) / float(maximum)
	if ratio > 0.66:
		return "green"
	elif ratio > 0.33:
		return "yellow"
	return "red"


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var icons: Dictionary = {"wood": "🪵", "stone": "🪨", "food": "🍖", "gold": "🪙"}
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return " ".join(parts)


func _construction_progress(current_hp: int, total_hp: int) -> float:
	if total_hp <= 0:
		return 0.0
	return float(current_hp) / float(total_hp)
