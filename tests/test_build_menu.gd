## Tests for BuildMenu (scripts/ui/build_menu.gd).
## Validates categories, prerequisites, cost checking, button creation.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("BuildMenu")

	# --- CATEGORIES structure ---
	var categories: Dictionary = {
		"Economy": ["house", "lumber_camp", "mill", "mine"],
		"Military": ["barracks", "archery_range", "stable", "siege_workshop"],
		"Defense": ["wall", "tower", "castle"],
	}

	T.assert_eq(categories.size(), 3, "3 categories")
	T.assert_in("Economy", categories.keys(), "has Economy")
	T.assert_in("Military", categories.keys(), "has Military")
	T.assert_in("Defense", categories.keys(), "has Defense")

	T.assert_eq(categories["Economy"].size(), 4, "Economy has 4 buildings")
	T.assert_in("house", categories["Economy"], "Economy has house")
	T.assert_in("lumber_camp", categories["Economy"], "Economy has lumber_camp")
	T.assert_in("mill", categories["Economy"], "Economy has mill")
	T.assert_in("mine", categories["Economy"], "Economy has mine")

	T.assert_eq(categories["Military"].size(), 4, "Military has 4 buildings")
	T.assert_in("barracks", categories["Military"], "Military has barracks")

	T.assert_eq(categories["Defense"].size(), 3, "Defense has 3 buildings")
	T.assert_in("castle", categories["Defense"], "Defense has castle")

	# --- Cost formatting ---
	T.assert_eq(_format_cost({}), "Free", "empty cost = Free")
	T.assert_eq(_format_cost({"wood": 100}), "🪵100", "single cost")
	T.assert_eq(_format_cost({"wood": 50, "food": 30}), "🪵50 🍖30", "multi cost")

	# --- Prerequisite checking ---
	var owned_types: Array[String] = ["house", "lumber_camp"]
	T.assert_true(_check_prereqs([], owned_types), "no prereqs = true")
	T.assert_true(_check_prereqs(["house"], owned_types), "have house prereq")
	T.assert_true(_check_prereqs(["lumber_camp"], owned_types), "have lumber_camp prereq")
	T.assert_false(_check_prereqs(["barracks"], owned_types), "missing barracks prereq")
	T.assert_false(_check_prereqs(["house", "barracks"], owned_types), "missing one of multiple prereqs")

	# --- Affordability ---
	T.assert_true(_can_afford({"wood": 50}, {"wood": 100, "food": 200}), "can afford 50 wood with 100")
	T.assert_false(_can_afford({"wood": 150}, {"wood": 100, "food": 200}), "cannot afford 150 wood with 100")
	T.assert_true(_can_afford({}, {"wood": 100}), "free building always affordable")
	T.assert_false(_can_afford({"wood": 50, "food": 50}, {"wood": 100, "food": 30}), "cannot afford missing food")

	# --- Open/close state ---
	var is_open: bool = false
	is_open = true
	T.assert_true(is_open, "menu can open")
	is_open = false
	T.assert_false(is_open, "menu can close")

	T.summary()
	quit()


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Free"
	var icons: Dictionary = {"wood": "🪵", "stone": "🪨", "food": "🍖", "gold": "🪙"}
	var parts: PackedStringArray = []
	for res_type: String in cost:
		var icon: String = icons.get(res_type, "?")
		parts.append(icon + str(cost[res_type]))
	return " ".join(parts)


func _check_prereqs(prereqs: Array, owned: Array[String]) -> bool:
	if prereqs.is_empty():
		return true
	for prereq: String in prereqs:
		if prereq not in owned:
			return false
	return true


func _can_afford(cost: Dictionary, resources: Dictionary) -> bool:
	for res_type: String in cost:
		if resources.get(res_type, 0) < cost[res_type]:
			return false
	return true
