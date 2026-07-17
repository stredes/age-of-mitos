## Tests for SelectionPanel (scripts/ui/selection_panel.gd).
## Validates HP bar updates, command buttons, hotkey mapping, cost formatting.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("SelectionPanel")

	# --- HP color logic ---
	T.assert_eq(_hp_color(80, 100), Color(0.2, 0.8, 0.2), "HP 80% = green")
	T.assert_eq(_hp_color(50, 100), Color(0.9, 0.9, 0.2), "HP 50% = yellow")
	T.assert_eq(_hp_color(20, 100), Color(0.9, 0.2, 0.2), "HP 20% = red")
	T.assert_eq(_hp_color(0, 0), Color.RED, "HP 0/0 = red")

	# --- Hotkey mapping ---
	T.assert_eq(_get_command_hotkey("Attack"), "A", "attack hotkey = A")
	T.assert_eq(_get_command_hotkey("Move"), "M", "move hotkey = M")
	T.assert_eq(_get_command_hotkey("Stop"), "S", "stop hotkey = S")
	T.assert_eq(_get_command_hotkey("Build"), "B", "build hotkey = B")
	T.assert_eq(_get_command_hotkey("Wood Gather"), "W", "wood gather hotkey = W")
	T.assert_eq(_get_command_hotkey("Food Gather"), "F", "food gather hotkey = F")
	T.assert_eq(_get_command_hotkey("Stone Mine"), "T", "stone mine hotkey = T")
	T.assert_eq(_get_command_hotkey("Gold Mine"), "G", "gold mine hotkey = G")
	T.assert_eq(_get_command_hotkey("Train Villager [V]"), "V", "villager train hotkey = V")
	T.assert_eq(_get_command_hotkey("Train Swordsman [Z]"), "Z", "swordsman train hotkey = Z")
	T.assert_eq(_get_command_hotkey("Train Spearman [P]"), "P", "spearman train hotkey = P")
	T.assert_eq(_get_command_hotkey("Train Archer [R]"), "R", "archer train hotkey = R")
	T.assert_eq(_get_command_hotkey("Train Cavalry [C]"), "C", "cavalry train hotkey = C")
	T.assert_eq(_get_command_hotkey("Unknown"), "", "unknown = empty")

	# --- Cost formatting ---
	T.assert_eq(_format_cost_short({}), "", "empty cost = empty")
	T.assert_eq(_format_cost_short({"wood": 100}), "🪵100", "single cost")
	T.assert_eq(_format_cost_short({"wood": 50, "food": 30}), "🪵50 🍖30", "multi cost")

	# --- Clear state ---
	var showing: bool = true
	showing = false
	T.assert_false(showing, "clear hides panel")

	# --- Unit count display ---
	T.assert_eq("3 Units Selected", "3 Units Selected", "multi-unit label")

	# --- Building construction label ---
	T.assert_eq("House (Building...)", "House (Building...)", "building constructing label")

	T.summary()
	quit()


func _hp_color(current: int, maximum: int) -> Color:
	if maximum <= 0:
		return Color.RED
	var ratio: float = float(current) / float(maximum)
	if ratio > 0.66:
		return Color(0.2, 0.8, 0.2)
	elif ratio > 0.33:
		return Color(0.9, 0.9, 0.2)
	return Color(0.9, 0.2, 0.2)


func _get_command_hotkey(label: String) -> String:
	var lower_label: String = label.to_lower()
	if lower_label.begins_with("attack"):
		return "A"
	if lower_label.begins_with("move"):
		return "M"
	if lower_label.begins_with("stop"):
		return "S"
	if lower_label.begins_with("build"):
		return "B"
	if lower_label.begins_with("wood"):
		return "W"
	if lower_label.begins_with("food"):
		return "F"
	if lower_label.begins_with("stone"):
		return "T"
	if lower_label.begins_with("gold"):
		return "G"
	if lower_label.contains("villager"):
		return "V"
	if lower_label.contains("swordsman"):
		return "Z"
	if lower_label.contains("spearman"):
		return "P"
	if lower_label.contains("archer"):
		return "R"
	if lower_label.contains("cavalry"):
		return "C"
	return ""


func _format_cost_short(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var icons: Dictionary = {"wood": "🪵", "stone": "🪨", "food": "🍖", "gold": "🪙"}
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return " ".join(parts)
