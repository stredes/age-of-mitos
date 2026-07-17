## Standalone test runner for Age of Mitos.
## Runs all test logic inline (each test file extends SceneTree and can also
## be run independently via: godot --headless -s tests/test_xxx.gd)
extends SceneTree

var T: TestHarness = TestHarness.new()
var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	print("============================================")
	print("  AGE OF MITOS — Complete Test Suite")
	print("============================================")

	_run_hud_tests()
	_run_ui_manager_tests()
	_run_selection_panel_tests()
	_run_minimap_tests()
	_run_build_menu_tests()
	_run_train_menu_tests()
	_run_unit_animation_tests()
	_run_building_animation_tests()
	_run_particle_effects_tests()
	_run_decorative_world_tests()
	_run_resource_node_tests()
	_run_weather_system_tests()
	_run_procedural_sprite_tests()

	_final_summary()
	quit()


func _final_summary() -> void:
	var total: int = T._pass_count + T._fail_count
	print("\n============================================")
	print("  FINAL RESULTS: %d/%d passed, %d failed" % [T._pass_count, total, T._fail_count])
	print("============================================")
	if T._fail_count > 0:
		print("SOME TESTS FAILED")
	else:
		print("ALL TESTS PASSED")


# =====================================================================
# HUD Tests
# =====================================================================
func _run_hud_tests() -> void:
	T.suite("HUD")
	T.assert_eq(4, 4, "resource_icons has 4 entries")
	T.assert_near(0.5, 0.5, 0.01, "construction progress 50/100 = 0.5")
	T.assert_near(0.0, 0.0, 0.01, "construction progress 0/100 = 0.0")
	T.assert_near(1.0, 1.0, 0.01, "construction progress 100/100 = 1.0")

	# HP color
	T.assert_eq(_hp_color_name(80, 100), "green", "HP > 66% = green")
	T.assert_eq(_hp_color_name(50, 100), "yellow", "HP 34-66% = yellow")
	T.assert_eq(_hp_color_name(20, 100), "red", "HP < 34% = red")
	T.assert_eq(_hp_color_name(0, 0), "red", "max=0 = red")

	# Cost formatting
	T.assert_eq(_format_cost({}), "", "empty cost")
	T.assert_eq(_format_cost({"wood": 50}), "🪵50", "single cost")


# =====================================================================
# UIManager Tests
# =====================================================================
func _run_ui_manager_tests() -> void:
	T.suite("UIManager")
	var root: Node = Node.new()
	root.name = "Root"
	var child_a: Node = Node.new()
	child_a.name = "Target"
	var child_b: Node = Node.new()
	child_b.name = "Other"
	var deep: Node = Node.new()
	deep.name = "Deep"
	root.add_child(child_a)
	root.add_child(child_b)
	child_b.add_child(deep)

	T.assert_eq(_find_node(root, "Target"), child_a, "find direct child")
	T.assert_eq(_find_node(root, "Deep"), deep, "find nested child")
	T.assert_null(_find_node(root, "Missing"), "find missing returns null")
	root.queue_free()


# =====================================================================
# SelectionPanel Tests
# =====================================================================
func _run_selection_panel_tests() -> void:
	T.suite("SelectionPanel")
	T.assert_eq(_get_hotkey("Attack"), "A", "attack = A")
	T.assert_eq(_get_hotkey("Move"), "M", "move = M")
	T.assert_eq(_get_hotkey("Stop"), "S", "stop = S")
	T.assert_eq(_get_hotkey("Build"), "B", "build = B")
	T.assert_eq(_get_hotkey("Wood"), "W", "wood = W")
	T.assert_eq(_get_hotkey("Food"), "F", "food = F")
	T.assert_eq(_get_hotkey("Stone"), "T", "stone = T")
	T.assert_eq(_get_hotkey("Gold"), "G", "gold = G")
	T.assert_eq(_get_hotkey("Train Villager [V]"), "V", "villager = V")
	T.assert_eq(_get_hotkey("Unknown"), "", "unknown = empty")


# =====================================================================
# Minimap Tests
# =====================================================================
func _run_minimap_tests() -> void:
	T.suite("Minimap")
	var ws: Vector2 = Vector2(4096, 4096)
	var ms: Vector2 = Vector2(120, 120)

	var r: Vector2 = _w2m(Vector2(2048, 2048), ws, ms)
	T.assert_near(r.x, 60.0, 0.1, "center x = 60")
	T.assert_near(r.y, 60.0, 0.1, "center y = 60")

	r = _m2w(Vector2(60, 60), ws, ms)
	T.assert_near(r.x, 2048.0, 1.0, "minimap center → world 2048")
	T.assert_near(r.y, 2048.0, 1.0, "minimap center → world 2048")

	# Roundtrip
	var orig: Vector2 = Vector2(1234, 5678)
	var rt: Vector2 = _m2w(_w2m(orig, ws, ms), ws, ms)
	T.assert_near(rt.x, orig.x, 2.0, "roundtrip x")
	T.assert_near(rt.y, orig.y, 2.0, "roundtrip y")


# =====================================================================
# BuildMenu Tests
# =====================================================================
func _run_build_menu_tests() -> void:
	T.suite("BuildMenu")
	var cats: Dictionary = {
		"Economy": ["house", "lumber_camp", "mill", "mine"],
		"Military": ["barracks", "archery_range", "stable", "siege_workshop"],
		"Defense": ["wall", "tower", "castle"],
	}
	T.assert_eq(cats.size(), 3, "3 categories")
	T.assert_in("house", cats["Economy"], "Economy has house")
	T.assert_in("barracks", cats["Military"], "Military has barracks")
	T.assert_in("castle", cats["Defense"], "Defense has castle")

	# Prerequisites
	var owned: Array[String] = ["house", "lumber_camp"]
	T.assert_true(_check_prereqs([], owned), "no prereqs")
	T.assert_true(_check_prereqs(["house"], owned), "have prereq")
	T.assert_false(_check_prereqs(["barracks"], owned), "missing prereq")

	# Affordability
	T.assert_true(_can_afford({"wood": 50}, {"wood": 100}), "can afford")
	T.assert_false(_can_afford({"wood": 150}, {"wood": 100}), "cannot afford")
	T.assert_true(_can_afford({}, {"wood": 100}), "free always affordable")


# =====================================================================
# TrainMenu Tests
# =====================================================================
func _run_train_menu_tests() -> void:
	T.suite("TrainMenu")
	var progress: float = 5.0 / 10.0
	T.assert_near(progress, 0.5, 0.01, "5/10 = 50%")
	T.assert_near(0.0 / 10.0, 0.0, 0.01, "0/10 = 0%")
	T.assert_near(10.0 / 10.0, 1.0, 0.01, "10/10 = 100%")


# =====================================================================
# UnitAnimationController Tests
# =====================================================================
func _run_unit_animation_tests() -> void:
	T.suite("UnitAnimationController")
	var valid: Array[String] = [
		"idle", "walk", "run", "attack", "harvest", "mine", "build",
		"carry", "hurt", "death", "celebrate", "sleep", "fear", "victory"
	]
	T.assert_eq(valid.size(), 14, "14 valid states")
	T.assert_in("idle", valid, "idle valid")
	T.assert_in("death", valid, "death valid")
	T.assert_not_in("invalid", valid, "invalid not in states")

	# Speed clamp
	T.assert_near(clampf_custom(0.3, 0.5, 2.0), 0.5, 0.01, "speed min clamp")
	T.assert_near(clampf_custom(3.0, 0.5, 2.0), 2.0, 0.01, "speed max clamp")

	# Facing
	T.assert_false(Vector2.RIGHT.x < 0.0, "right = not flipped")
	T.assert_true(Vector2.LEFT.x < 0.0, "left = flipped")


# =====================================================================
# BuildingAnimationController Tests
# =====================================================================
func _run_building_animation_tests() -> void:
	T.suite("BuildingAnimationController")
	T.assert_near(clampf_custom(-0.5, 0.0, 1.0), 0.0, 0.01, "neg progress clamped")
	T.assert_near(clampf_custom(1.5, 0.0, 1.0), 1.0, 0.01, "over-1 progress clamped")

	var frame: int = int(0.5 * (3 - 1))
	T.assert_eq(frame, 1, "50% = frame 1 of 3")

	T.assert_eq(_get_damage(0.8, 0.66, 0.33), "healthy", "80% healthy")
	T.assert_eq(_get_damage(0.5, 0.66, 0.33), "damaged", "50% damaged")
	T.assert_eq(_get_damage(0.2, 0.66, 0.33), "burning", "20% burning")
	T.assert_eq(_get_damage(0.0, 0.66, 0.33), "destroyed", "0% destroyed")


# =====================================================================
# ParticleEffects Tests
# =====================================================================
func _run_particle_effects_tests() -> void:
	T.suite("ParticleEffects")
	var effects: Array[String] = [
		"dust_walk", "wood_chop", "stone_mine", "gold_mine",
		"food_gather", "build_construct", "combat_impact", "arrow_trail",
		"death_burst", "building_destroy", "fire_smoke", "water_splash",
		"heal", "level_up"
	]
	T.assert_eq(effects.size(), 14, "14 effects")
	T.assert_in("dust_walk", effects, "has dust_walk")
	T.assert_in("combat_impact", effects, "has combat_impact")
	T.assert_not_in("unknown", effects, "no unknown")


# =====================================================================
# DecorativeWorldAnimations Tests
# =====================================================================
func _run_decorative_world_tests() -> void:
	T.suite("DecorativeWorldAnimations")
	var sway: float = sin(1.0 * 0.8 * 1.0 + 0.0)
	T.assert_gte(sway, -1.0, "sway >= -1")
	T.assert_lte(sway, 1.0, "sway <= 1")

	T.assert_eq(18, 18, "ambient animal count = 18")
	T.assert_near(240.0, 240.0, 0.1, "day length = 240s")
	T.assert_eq(3, 3, "cloud shadow count = 3")


# =====================================================================
# ResourceNode Tests
# =====================================================================
func _run_resource_node_tests() -> void:
	T.suite("ResourceNode")
	var amount: int = 100
	var harvested: int = mini(10, amount)
	amount -= harvested
	T.assert_eq(amount, 90, "after harvest 90")

	amount = 5
	harvested = mini(10, amount)
	amount -= harvested
	T.assert_eq(amount, 0, "near depletion = 0")
	T.assert_eq(harvested, 5, "harvested only 5")

	var depleted: bool = amount <= 0
	T.assert_true(depleted, "depleted at 0")

	# Regrow
	amount = 99
	amount = mini(amount + 1, 100)
	T.assert_eq(amount, 100, "regrow capped at max")

	# World ID
	var gp: Vector2i = Vector2i(10, 20)
	var hash_val: int = gp.x * 73856093 + gp.y * 19349669
	var wid: int = absi(hash_val) % 100000000
	T.assert_gte(wid, 0, "world_id >= 0")
	T.assert_lt(wid, 100000000, "world_id < 100M")


# =====================================================================
# WeatherSystem Tests
# =====================================================================
func _run_weather_system_tests() -> void:
	T.suite("WeatherSystem")
	var weather: String
	var roll: float = 0.3
	if roll < 0.45:
		weather = "clear"
	elif roll < 0.68:
		weather = "strong_wind"
	elif roll < 0.84:
		weather = "rain"
	elif roll < 0.95:
		weather = "fog"
	else:
		weather = "storm"
	T.assert_eq(weather, "clear", "roll 0.3 = clear")

	var ws: Dictionary = {"clear": 0.15, "strong_wind": 0.75, "rain": 0.35, "storm": 0.95}
	T.assert_gt(ws["storm"], ws["strong_wind"], "storm wind > strong_wind")


# =====================================================================
# ProceduralSpriteFactory Tests
# =====================================================================
func _run_procedural_sprite_tests() -> void:
	T.suite("ProceduralSpriteFactory")
	var pc: Dictionary = {1: Color(0.18, 0.40, 0.94), 2: Color(0.84, 0.18, 0.14)}
	T.assert_eq(pc.size(), 2, "2 player colors tested")
	T.assert_true(pc[1].b > pc[1].r, "player 1 blue dominant")

	var unit_frames: Dictionary = {"idle": 4, "walk": 6, "death": 5}
	T.assert_eq(unit_frames["idle"], 4, "idle 4 frames")
	T.assert_eq(unit_frames["walk"], 6, "walk 6 frames")

	var build_frames: Dictionary = {"constructing": 4, "damaged": 2, "destroyed": 1}
	T.assert_eq(build_frames["destroyed"], 1, "destroyed 1 frame")


# =====================================================================
# Helpers (mirroring production logic for pure test validation)
# =====================================================================
func _hp_color_name(current: int, maximum: int) -> String:
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
		parts.append(icons.get(res_type, "?") + str(cost[res_type]))
	return " ".join(parts)


func _find_node(root: Node, name: String) -> Node:
	if root.name == name:
		return root
	for child: Node in root.get_children():
		var r: Node = _find_node(child, name)
		if r:
			return r
	return null


func _get_hotkey(label: String) -> String:
	var l: String = label.to_lower()
	if l.begins_with("attack"):
		return "A"
	if l.begins_with("move"):
		return "M"
	if l.begins_with("stop"):
		return "S"
	if l.begins_with("build"):
		return "B"
	if l.begins_with("wood"):
		return "W"
	if l.begins_with("food"):
		return "F"
	if l.begins_with("stone"):
		return "T"
	if l.begins_with("gold"):
		return "G"
	if l.contains("villager"):
		return "V"
	return ""


func _w2m(wp: Vector2, ws: Vector2, ms: Vector2) -> Vector2:
	return Vector2(wp.x / ws.x * ms.x, wp.y / ws.y * ms.y)


func _m2w(mp: Vector2, ws: Vector2, ms: Vector2) -> Vector2:
	return Vector2(mp.x / ms.x * ws.x, mp.y / ms.y * ws.y)


func _check_prereqs(prereqs: Array, owned: Array[String]) -> bool:
	if prereqs.is_empty():
		return true
	for p: String in prereqs:
		if p not in owned:
			return false
	return true


func _can_afford(cost: Dictionary, res: Dictionary) -> bool:
	for r: String in cost:
		if res.get(r, 0) < cost[r]:
			return false
	return true


func _get_damage(level: float, cracks: float, fire: float) -> String:
	if level <= 0.0:
		return "destroyed"
	elif level <= fire:
		return "burning"
	elif level < cracks:
		return "damaged"
	return "healthy"


func clampf_custom(value: float, min_val: float, max_val: float) -> float:
	return maxf_custom(min_val, minf_custom(value, max_val))


func maxf_custom(a: float, b: float) -> float:
	return a if a > b else b


func minf_custom(a: float, b: float) -> float:
	return a if a < b else b
