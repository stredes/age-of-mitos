extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0

func run_all_tests() -> void:
	_tests_passed = 0
	_tests_failed = 0
	print("=== AI SYSTEM TESTS START ===")
	print("")

	_test_director_initialization()
	_test_director_personality_weights()
	_test_director_decision_history()
	_test_director_sub_nodes_with_personality()
	_test_director_priority_logic()
	_test_economy_initialization()
	_test_economy_personality_ratios()
	_test_economy_resource_urgency()
	_test_economy_rebalance()
	_test_economy_ensure_food()
	_test_economy_assign_idle_best_resource()
	_test_military_initialization()
	_test_military_personality_thresholds()
	_test_military_formation_selection()
	_test_military_formation_offsets()
	_test_military_should_attack()
	_test_military_should_retreat()
	_test_military_plan_attack_null_safety()
	_test_builder_initialization()
	_test_builder_personality_cooldown()
	_test_builder_should_expand()
	_test_builder_building_priority()
	_test_builder_find_expansion_null_safety()
	_test_builder_build_defenses_null_safety()

	print("")
	print("=== AI SYSTEM TESTS END ===")
	print("PASSED: %d / %d" % [_tests_passed, _tests_passed + _tests_failed])
	if _tests_failed > 0:
		print("FAILED: %d" % _tests_failed)
	else:
		print("ALL TESTS PASSED!")

func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual == expected:
		_tests_passed += 1
	else:
		_tests_failed += 1
		print("  FAIL: %s (expected %s, got %s)" % [msg, str(expected), str(actual)])

func assert_true(condition: bool, msg: String = "") -> void:
	if condition:
		_tests_passed += 1
	else:
		_tests_failed += 1
		print("  FAIL: %s (expected true)" % msg)

func assert_false(condition: bool, msg: String = "") -> void:
	if not condition:
		_tests_passed += 1
	else:
		_tests_failed += 1
		print("  FAIL: %s (expected false)" % msg)

func assert_range(value: float, min_val: float, max_val: float, msg: String = "") -> void:
	if value >= min_val and value <= max_val:
		_tests_passed += 1
	else:
		_tests_failed += 1
		print("  FAIL: %s (expected %f <= %f <= %f)" % [msg, min_val, value, max_val])

func _begin_test(name: String) -> void:
	print("  [TEST] %s" % name)

func _make_scene() -> Node:
	var scene: Node = Node.new()
	scene.name = "TestScene"
	add_child(scene)
	return scene

func _make_director(scene: Node, player_id: int = 1, diff: int = 2) -> Node:
	var dir: Node = load("res://scripts/ai/ai_director.gd").new()
	dir.name = "AIDirector"
	scene.add_child(dir)
	dir.initialize(player_id, diff)
	return dir

func _make_economy(scene: Node, player_id: int = 1, personality: String = "balanced") -> Node:
	var eco: Node = load("res://scripts/ai/ai_economy.gd").new()
	eco.name = "AIEconomy"
	scene.add_child(eco)
	eco.initialize(player_id, personality)
	return eco

func _make_military(scene: Node, player_id: int = 1, personality: String = "balanced") -> Node:
	var mil: Node = load("res://scripts/ai/ai_military.gd").new()
	mil.name = "AIMilitary"
	scene.add_child(mil)
	mil.initialize(player_id, personality)
	return mil

func _make_builder(scene: Node, player_id: int = 1, personality: String = "balanced") -> Node:
	var bld: Node = load("res://scripts/ai/ai_builder.gd").new()
	bld.name = "AIBuilder"
	scene.add_child(bld)
	bld.initialize(player_id, personality)
	return bld


# =============================================================================
# AIDirector Tests
# =============================================================================
func _test_director_initialization() -> void:
	print("\n--- AIDirector: Initialization ---")

	var scene: Node = _make_scene()
	var dir: Node = _make_director(scene, 1, 1)

	_begin_test("difficulty 1 = defensive")
	assert_eq(dir.personality, "defensive", "personality = defensive")
	assert_eq(dir.update_interval, 5.0, "interval = 5.0")

	dir.free()

	var dir3: Node = _make_director(scene, 1, 3)
	_begin_test("difficulty 3 = aggressive")
	assert_eq(dir3.personality, "aggressive", "personality = aggressive")
	assert_eq(dir3.update_interval, 2.0, "interval = 2.0")

	dir3.free()
	scene.free()


func _test_director_personality_weights() -> void:
	print("\n--- AIDirector: Personality Weights ---")

	var scene: Node = _make_scene()

	var dir_agg: Node = _make_director(scene, 1, 3)
	_begin_test("aggressive: military_bias > 1.0")
	var agg_profile: Dictionary = dir_agg.get_personality_profile()
	assert_true(agg_profile["military_bias"] > 1.0, "military_bias > 1.0")

	_begin_test("aggressive: attack_cooldown_mult < 1.0")
	assert_true(agg_profile["attack_cooldown_mult"] < 1.0, "cooldown_mult < 1.0")
	dir_agg.free()

	var dir_def: Node = _make_director(scene, 1, 1)
	_begin_test("defensive: defense_bias > 1.0")
	var def_profile: Dictionary = dir_def.get_personality_profile()
	assert_true(def_profile["defense_bias"] > 1.0, "defense_bias > 1.0")

	_begin_test("defensive: military_bias < 1.0")
	assert_true(def_profile["military_bias"] < 1.0, "military_bias < 1.0")
	dir_def.free()

	var dir_bal: Node = _make_director(scene, 1, 2)
	_begin_test("balanced: all biases = 1.0")
	var bal_profile: Dictionary = dir_bal.get_personality_profile()
	assert_eq(bal_profile["military_bias"], 1.0, "military_bias = 1.0")
	assert_eq(bal_profile["economy_bias"], 1.0, "economy_bias = 1.0")
	assert_eq(bal_profile["defense_bias"], 1.0, "defense_bias = 1.0")
	dir_bal.free()

	scene.free()


func _test_director_decision_history() -> void:
	print("\n--- AIDirector: Decision History ---")

	var scene: Node = _make_scene()
	var dir: Node = _make_director(scene, 1, 2)

	_begin_test("history starts empty")
	var history: Array[String] = dir.get_decision_history()
	assert_eq(history.size(), 0, "empty history")

	_begin_test("get_personality_profile returns dict")
	var profile: Dictionary = dir.get_personality_profile()
	assert_true(profile.size() > 0, "profile not empty")

	_begin_test("get_personality_weight returns float")
	var weight: float = dir.get_personality_weight("military_bias")
	assert_eq(weight, 1.0, "balanced military_bias = 1.0")

	dir.free()
	scene.free()


func _test_director_sub_nodes_with_personality() -> void:
	print("\n--- AIDirector: Sub Nodes Personality ---")

	var scene: Node = _make_scene()
	var dir: Node = _make_director(scene, 1, 3)

	_begin_test("AIEconomy has personality")
	var eco: Node = dir.get_node_or_null("AIEconomy_1")
	assert_true(eco != null, "economy exists")
	if eco != null:
		assert_eq(eco.personality, "aggressive", "economy personality = aggressive")

	_begin_test("AIMilitary has personality")
	var mil: Node = dir.get_node_or_null("AIMilitary_1")
	assert_true(mil != null, "military exists")
	if mil != null:
		assert_eq(mil.personality, "aggressive", "military personality = aggressive")

	_begin_test("AIBuilder has personality")
	var bld: Node = dir.get_node_or_null("AIBuilder_1")
	assert_true(bld != null, "builder exists")
	if bld != null:
		assert_eq(bld.personality, "aggressive", "builder personality = aggressive")

	dir.free()
	scene.free()


func _test_director_priority_logic() -> void:
	print("\n--- AIDirector: Priority Logic ---")

	var scene: Node = _make_scene()
	var dir: Node = _make_director(scene, 1, 2)

	_begin_test("evaluate_priority returns valid string")
	var priority: String = dir._evaluate_priority()
	assert_true(priority in ["ECONOMY", "MILITARY", "EXPANSION", "DEFENSE"],
		"valid priority: " + priority)

	dir.free()
	scene.free()


# =============================================================================
# AIEconomy Tests
# =============================================================================
func _test_economy_initialization() -> void:
	print("\n--- AIEconomy: Initialization ---")

	var scene: Node = _make_scene()

	var eco_agg: Node = _make_economy(scene, 1, "aggressive")
	_begin_test("aggressive personality set")
	assert_eq(eco_agg.personality, "aggressive", "personality = aggressive")

	_begin_test("aggressive resource priority: food first")
	assert_eq(eco_agg._resource_priority[0], "food", "food first")

	eco_agg.free()

	var eco_def: Node = _make_economy(scene, 1, "defensive")
	_begin_test("defensive personality set")
	assert_eq(eco_def.personality, "defensive", "personality = defensive")
	eco_def.free()

	scene.free()


func _test_economy_personality_ratios() -> void:
	print("\n--- AIEconomy: Personality Ratios ---")

	var scene: Node = _make_scene()

	var eco_agg: Node = _make_economy(scene, 1, "aggressive")
	_begin_test("aggressive: gold ratio higher")
	var agg_ratios: Dictionary = eco_agg._ideal_ratios["aggressive"]
	assert_true(agg_ratios["gold"] > agg_ratios["stone"], "gold > stone")
	eco_agg.free()

	var eco_def: Node = _make_economy(scene, 1, "defensive")
	_begin_test("defensive: wood ratio higher")
	var def_ratios: Dictionary = eco_def._ideal_ratios["defensive"]
	assert_true(def_ratios["wood"] > def_ratios["gold"], "wood > gold")
	eco_def.free()

	scene.free()


func _test_economy_resource_urgency() -> void:
	print("\n--- AIEconomy: Resource Urgency ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 1, "balanced")

	_begin_test("get_resource_urgency returns float")
	var urgency: float = eco.get_resource_urgency("food")
	assert_true(urgency >= 0.0 and urgency <= 1.0, "urgency in [0, 1]")

	_begin_test("resource urgency > 0 with low resources")
	eco._stockpile_targets["food"] = 999999
	var urgency2: float = eco.get_resource_urgency("food")
	assert_true(urgency2 > 0.5, "high urgency with low resources")

	eco.free()
	scene.free()


func _test_economy_rebalance() -> void:
	print("\n--- AIEconomy: Rebalance ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 1, "balanced")

	_begin_test("rebalance with no villagers doesn't crash")
	eco._rebalance_villagers()
	assert_true(true, "no crash")

	_begin_test("find_needy_resource with empty distribution")
	var needy: String = eco._find_needy_resource(
		{"food": 0, "wood": 0, "gold": 0, "stone": 0},
		{"food": 0.4, "wood": 0.3, "gold": 0.2, "stone": 0.1}
	)
	assert_eq(needy, "food", "food most needy")

	eco.free()
	scene.free()


func _test_economy_ensure_food() -> void:
	print("\n--- AIEconomy: Ensure Food ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 1, "aggressive")

	_begin_test("ensure_food_income doesn't crash")
	eco.ensure_food_income()
	assert_true(true, "no crash")

	_begin_test("ensure_wood_income doesn't crash")
	eco.ensure_wood_income()
	assert_true(true, "no crash")

	_begin_test("ensure_gold_income doesn't crash")
	eco.ensure_gold_income()
	assert_true(true, "no crash")

	eco.free()
	scene.free()


func _test_economy_assign_idle_best_resource() -> void:
	print("\n--- AIEconomy: Assign Idle Best Resource ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 1, "balanced")

	_begin_test("find_best_resource_for_villager with no resources")
	var best: Node = eco._find_best_resource_for_villager(Node2D.new(), [])
	assert_eq(best, null, "null with empty resources")

	_begin_test("assign_idle_villagers doesn't crash")
	eco.assign_idle_villagers()
	assert_true(true, "no crash")

	eco.free()
	scene.free()


# =============================================================================
# AIMilitary Tests
# =============================================================================
func _test_military_initialization() -> void:
	print("\n--- AIMilitary: Initialization ---")

	var scene: Node = _make_scene()

	var mil_agg: Node = _make_military(scene, 1, "aggressive")
	_begin_test("aggressive: low attack threshold")
	assert_eq(mil_agg._attack_threshold, 60, "threshold = 60")
	assert_eq(mil_agg._attack_cooldown, 20.0, "cooldown = 20s")
	mil_agg.free()

	var mil_def: Node = _make_military(scene, 1, "defensive")
	_begin_test("defensive: high attack threshold")
	assert_eq(mil_def._attack_threshold, 100, "threshold = 100")
	assert_eq(mil_def._attack_cooldown, 45.0, "cooldown = 45s")
	mil_def.free()

	var mil_bal: Node = _make_military(scene, 1, "balanced")
	_begin_test("balanced: medium threshold")
	assert_eq(mil_bal._attack_threshold, 80, "threshold = 80")
	assert_eq(mil_bal._attack_cooldown, 30.0, "cooldown = 30s")
	mil_bal.free()

	scene.free()


func _test_military_personality_thresholds() -> void:
	print("\n--- AIMilitary: Personality Thresholds ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1, "aggressive")

	_begin_test("personality stored")
	assert_eq(mil.personality, "aggressive", "personality = aggressive")

	_begin_test("should_attack false with no army")
	assert_false(mil.should_attack(), "no army = no attack")

	mil.free()
	scene.free()


func _test_military_formation_selection() -> void:
	print("\n--- AIMilitary: Formation Selection ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1, "balanced")

	_begin_test("initial formation = LINE")
	assert_eq(mil._current_formation, mil.Formation.LINE, "starts as LINE")

	_begin_test("_get_formation_name returns string")
	var name: String = mil._get_formation_name()
	assert_eq(name, "line", "name = line")

	_begin_test("_get_formation_spread returns float")
	var spread: float = mil._get_formation_spread()
	assert_eq(spread, 60.0, "LINE spread = 60")

	mil.free()
	scene.free()


func _test_military_formation_offsets() -> void:
	print("\n--- AIMilitary: Formation Offsets ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1, "balanced")

	_begin_test("LINE offsets: 5 units")
	mil._current_formation = mil.Formation.LINE
	mil._formation_spread = 60.0
	var line_offsets: Array[Vector2] = mil._calculate_offsets(5)
	assert_eq(line_offsets.size(), 5, "5 offsets")
	assert_eq(line_offsets[0].x, -120.0, "first at -120")
	assert_eq(line_offsets[2].x, 0.0, "middle at 0")

	_begin_test("WEDGE offsets: 4 units")
	mil._current_formation = mil.Formation.WEDGE
	var wedge_offsets: Array[Vector2] = mil._calculate_offsets(4)
	assert_eq(wedge_offsets.size(), 4, "4 offsets")
	assert_true(wedge_offsets[0].y < wedge_offsets[2].y, "front unit ahead")

	_begin_test("SCATTER offsets: 6 units")
	mil._current_formation = mil.Formation.SCATTER
	var scatter_offsets: Array[Vector2] = mil._calculate_offsets(6)
	assert_eq(scatter_offsets.size(), 6, "6 offsets")
	_begin_test("SCATTER: offsets are spread out")
	var all_same: bool = true
	for i in range(1, scatter_offsets.size()):
		if scatter_offsets[i] != scatter_offsets[0]:
			all_same = false
			break
	assert_false(all_same, "scatter offsets differ")

	_begin_test("FLANK offsets: 6 units")
	mil._current_formation = mil.Formation.FLANK
	var flank_offsets: Array[Vector2] = mil._calculate_offsets(6)
	assert_eq(flank_offsets.size(), 6, "6 offsets")
	assert_true(flank_offsets[0].x < 0, "left flank at negative x")
	assert_true(flank_offsets[3].x > 0, "right flank at positive x")

	mil.free()
	scene.free()


func _test_military_should_attack() -> void:
	print("\n--- AIMilitary: Should Attack ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1, "balanced")

	_begin_test("should_attack false with no army")
	assert_false(mil.should_attack(), "no army")

	_begin_test("army strength = 0")
	assert_eq(mil.get_army_strength(), 0, "strength = 0")

	_begin_test("army composition empty")
	assert_true(mil.get_army_composition().is_empty(), "empty composition")

	mil.free()
	scene.free()


func _test_military_should_retreat() -> void:
	print("\n--- AIMilitary: Should Retreat ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1, "balanced")

	_begin_test("should_retreat true with no army")
	assert_true(mil.should_retreat(), "retreat with no army")

	mil.free()
	scene.free()


func _test_military_plan_attack_null_safety() -> void:
	print("\n--- AIMilitary: Plan Attack Null Safety ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1, "balanced")

	_begin_test("plan_attack doesn't crash")
	mil.plan_attack()
	assert_true(true, "no crash")

	_begin_test("defend_base doesn't crash")
	mil.defend_base()
	assert_true(true, "no crash")

	mil.free()
	scene.free()


# =============================================================================
# AIBuilder Tests
# =============================================================================
func _test_builder_initialization() -> void:
	print("\n--- AIBuilder: Initialization ---")

	var scene: Node = _make_scene()

	var bld_agg: Node = _make_builder(scene, 1, "aggressive")
	_begin_test("aggressive: low cooldown")
	assert_eq(bld_agg._build_cooldown, 12.0, "cooldown = 12s")
	assert_eq(bld_agg.personality, "aggressive", "personality = aggressive")
	bld_agg.free()

	var bld_def: Node = _make_builder(scene, 1, "defensive")
	_begin_test("defensive: high cooldown")
	assert_eq(bld_def._build_cooldown, 18.0, "cooldown = 18s")
	bld_def.free()

	var bld_bal: Node = _make_builder(scene, 1, "balanced")
	_begin_test("balanced: medium cooldown")
	assert_eq(bld_bal._build_cooldown, 15.0, "cooldown = 15s")
	bld_bal.free()

	scene.free()


func _test_builder_personality_cooldown() -> void:
	print("\n--- AIBuilder: Personality Cooldown ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1, "aggressive")

	_begin_test("should_expand false with no buildings")
	assert_false(bld.should_expand(), "no expansion")

	_begin_test("building priority not empty")
	var priority: Array = bld.get_building_priority()
	assert_true(priority.size() > 0, "priority not empty")

	bld.free()
	scene.free()


func _test_builder_should_expand() -> void:
	print("\n--- AIBuilder: Should Expand ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1, "balanced")

	_begin_test("should_expand false initially")
	assert_false(bld.should_expand(), "no expand at start")

	bld.free()
	scene.free()


func _test_builder_building_priority() -> void:
	print("\n--- AIBuilder: Building Priority ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1, "balanced")

	_begin_test("priority starts with barracks")
	var priority: Array = bld.get_building_priority()
	assert_eq(priority[0], "barracks", "first = barracks")

	bld.free()
	scene.free()


func _test_builder_find_expansion_null_safety() -> void:
	print("\n--- AIBuilder: Find Expansion Null Safety ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1, "balanced")

	_begin_test("find_expansion_spot doesn't crash")
	var spot: Vector2 = bld.find_expansion_spot()
	assert_true(true, "no crash")

	bld.free()
	scene.free()


func _test_builder_build_defenses_null_safety() -> void:
	print("\n--- AIBuilder: Build Defenses Null Safety ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1, "balanced")

	_begin_test("build_defenses doesn't crash")
	bld.build_defenses()
	assert_true(true, "no crash")

	_begin_test("repair_damaged_buildings doesn't crash")
	bld.repair_damaged_buildings()
	assert_true(true, "no crash")

	_begin_test("build_essentials doesn't crash")
	bld.build_essentials()
	assert_true(true, "no crash")

	bld.free()
	scene.free()
