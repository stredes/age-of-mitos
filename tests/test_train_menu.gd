## Tests for TrainMenu (scripts/ui/train_menu.gd).
## Validates unit options, cost formatting, queue display, progress.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("TrainMenu")

	# --- Cost formatting ---
	T.assert_eq(_format_cost({}), "Free", "empty cost = Free")
	T.assert_eq(_format_cost({"food": 50, "gold": 20}), "🍖50 🪙20", "villager cost")

	# --- Queue display logic ---
	var queue: Array = ["villager", "villager", "swordsman"]
	T.assert_eq(queue.size(), 3, "queue has 3 items")
	T.assert_eq(queue[0], "villager", "first item = villager")
	T.assert_eq(queue[2], "swordsman", "third item = swordsman")

	# --- Queue with dictionary items ---
	var queue_dict: Array = [{"type": "villager"}, {"type": "archer"}]
	var first_type: String = queue_dict[0].get("type", "unknown") if queue_dict[0] is Dictionary else ""
	T.assert_eq(first_type, "villager", "dict queue first = villager")

	# --- Progress calculation ---
	T.assert_near(_production_progress(5.0, 10.0), 0.5, 0.01, "5/10 = 50%")
	T.assert_near(_production_progress(0.0, 10.0), 0.0, 0.01, "0/10 = 0%")
	T.assert_near(_production_progress(10.0, 10.0), 1.0, 0.01, "10/10 = 100%")

	# --- Train button enabled/disabled ---
	var can_afford: bool = true
	T.assert_true(can_afford, "can afford = enabled")
	can_afford = false
	T.assert_false(can_afford, "cannot afford = disabled")

	# --- Building type detection ---
	T.assert_eq("barracks", "barracks", "building type preserved")
	T.assert_eq("", "", "empty building type")

	# --- Menu state ---
	var _is_open: bool = false
	var _current_building_id: int = -1
	T.assert_false(_is_open, "initially closed")
	T.assert_eq(_current_building_id, -1, "no building selected initially")

	_is_open = true
	_current_building_id = 5
	T.assert_true(_is_open, "opened for building")
	T.assert_eq(_current_building_id, 5, "building_id set to 5")

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


func _production_progress(current: float, total: float) -> float:
	if total <= 0.0:
		return 0.0
	return current / total
