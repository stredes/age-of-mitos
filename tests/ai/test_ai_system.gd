extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0

func run_all_tests() -> void:
	_tests_passed = 0
	_tests_failed = 0
	print("=== AI SYSTEM TESTS START ===")
	print("")

	_test_director_initialization()
	_test_director_timer_after_difficulty()
	_test_director_priority_logic()
	_test_director_sub_nodes_created()
	_test_director_scene_null_safety()
	_test_economy_initialization()
	_test_economy_ensure_food()
	_test_economy_ensure_wood()
	_test_economy_ensure_gold()
	_test_economy_villager_distribution()
	_test_economy_queue_to_resource()
	_test_military_initialization()
	_test_military_should_attack()
	_test_military_army_strength()
	_test_military_choose_unit_counter()
	_test_military_plan_attack_null_safety()
	_test_military_defend_base_null_safety()
	_test_builder_initialization()
	_test_builder_should_expand()
	_test_builder_building_priority()
	_test_builder_find_expansion_null_safety()
	_test_builder_build_defenses_null_safety()
	_test_builder_repair_damaged()
	_test_builder_build_essentials()

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

func _make_economy(scene: Node, player_id: int = 1) -> Node:
	var eco: Node = load("res://scripts/ai/ai_economy.gd").new()
	eco.name = "AIEconomy"
	scene.add_child(eco)
	eco.initialize(player_id)
	return eco

func _make_military(scene: Node, player_id: int = 1) -> Node:
	var mil: Node = load("res://scripts/ai/ai_military.gd").new()
	mil.name = "AIMilitary"
	scene.add_child(mil)
	mil.initialize(player_id)
	return mil

func _make_builder(scene: Node, player_id: int = 1) -> Node:
	var bld: Node = load("res://scripts/ai/ai_builder.gd").new()
	bld.name = "AIBuilder"
	scene.add_child(bld)
	bld.initialize(player_id)
	return bld


# =============================================================================
# AIDirector Tests
# =============================================================================
func _test_director_initialization() -> void:
	print("\n--- AIDirector: Initialization ---")

	var scene: Node = _make_scene()

	var dir: Node = _make_director(scene, 1, 2)
	_begin_test("difficulty 2 = balanced")
	assert_eq(dir.difficulty, 2, "difficulty = 2")
	assert_eq(dir.personality, "balanced", "personality = balanced")
	assert_eq(dir.update_interval, 3.0, "interval = 3.0")

	dir.free()

	var dir1: Node = _make_director(scene, 1, 1)
	_begin_test("difficulty 1 = defensive")
	assert_eq(dir1.personality, "defensive", "personality = defensive")
	assert_eq(dir1.update_interval, 5.0, "interval = 5.0")
	dir1.free()

	var dir3: Node = _make_director(scene, 1, 3)
	_begin_test("difficulty 3 = aggressive")
	assert_eq(dir3.personality, "aggressive", "personality = aggressive")
	assert_eq(dir3.update_interval, 2.0, "interval = 2.0")
	dir3.free()

	scene.free()


func _test_director_timer_after_difficulty() -> void:
	print("\n--- AIDirector: Timer After Difficulty ---")

	var scene: Node = _make_scene()
	var dir: Node = _make_director(scene, 1, 1)

	_begin_test("timer is within correct interval range (0-5)")
	assert_range(dir.update_timer, 0.0, 5.0, "timer 0-5 for difficulty 1")

	dir.free()

	var dir3: Node = _make_director(scene, 1, 3)
	_begin_test("timer is within correct interval range (0-2)")
	assert_range(dir3.update_timer, 0.0, 2.0, "timer 0-2 for difficulty 3")

	dir3.free()
	scene.free()


func _test_director_priority_logic() -> void:
	print("\n--- AIDirector: Priority Logic ---")

	var scene: Node = _make_scene()
	var dir: Node = _make_director(scene, 1, 2)

	_begin_test("evaluate_priority returns valid string")
	var priority: String = dir._evaluate_priority()
	assert_true(priority in ["ECONOMY", "MILITARY", "EXPANSION", "DEFENSE"],
		"valid priority returned: " + priority)

	dir.free()
	scene.free()


func _test_director_sub_nodes_created() -> void:
	print("\n--- AIDirector: Sub Nodes ---")

	var scene: Node = _make_scene()
	var dir: Node = _make_director(scene, 1, 2)

	_begin_test("AIEconomy child exists")
	assert_true(dir.get_node_or_null("AIEconomy_1") != null, "AIEconomy_1 exists")

	_begin_test("AIMilitary child exists")
	assert_true(dir.get_node_or_null("AIMilitary_1") != null, "AIMilitary_1 exists")

	_begin_test("AIBuilder child exists")
	assert_true(dir.get_node_or_null("AIBuilder_1") != null, "AIBuilder_1 exists")

	_begin_test("sub nodes have correct player_id")
	assert_eq(dir.get_node("AIEconomy_1").ai_player_id, 1, "economy player_id = 1")
	assert_eq(dir.get_node("AIMilitary_1").ai_player_id, 1, "military player_id = 1")
	assert_eq(dir.get_node("AIBuilder_1").ai_player_id, 1, "builder player_id = 1")

	dir.free()
	scene.free()


func _test_director_scene_null_safety() -> void:
	print("\n--- AIDirector: Scene Null Safety ---")

	var scene: Node = _make_scene()
	var dir: Node = _make_director(scene, 1, 2)

	_begin_test("find_expansion_spot doesn't crash without CombatManager")
	var spot: Vector2 = dir.find_expansion_spot()
	assert_true(true, "no crash")

	_begin_test("find_weakest_point doesn't crash")
	var weak: Vector2 = dir.find_weakest_point()
	assert_true(true, "no crash")

	dir.free()
	scene.free()


# =============================================================================
# AIEconomy Tests
# =============================================================================
func _test_economy_initialization() -> void:
	print("\n--- AIEconomy: Initialization ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 2)

	_begin_test("player_id set correctly")
	assert_eq(eco.ai_player_id, 2, "player_id = 2")

	eco.free()
	scene.free()


func _test_economy_ensure_food() -> void:
	print("\n--- AIEconomy: Ensure Food ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 1)

	_begin_test("ensure_food_income doesn't crash")
	eco.ensure_food_income()
	assert_true(true, "no crash")

	eco.free()
	scene.free()


func _test_economy_ensure_wood() -> void:
	print("\n--- AIEconomy: Ensure Wood ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 1)

	_begin_test("ensure_wood_income doesn't crash")
	eco.ensure_wood_income()
	assert_true(true, "no crash")

	eco.free()
	scene.free()


func _test_economy_ensure_gold() -> void:
	print("\n--- AIEconomy: Ensure Gold ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 1)

	_begin_test("ensure_gold_income doesn't crash")
	eco.ensure_gold_income()
	assert_true(true, "no crash")

	eco.free()
	scene.free()


func _test_economy_villager_distribution() -> void:
	print("\n--- AIEconomy: Villager Distribution ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 1)

	_begin_test("distribution has all resource types")
	var dist: Dictionary = eco.get_villager_distribution()
	assert_true(dist.has("food"), "has food")
	assert_true(dist.has("wood"), "has wood")
	assert_true(dist.has("stone"), "has stone")
	assert_true(dist.has("gold"), "has gold")

	_begin_test("distribution starts at 0")
	assert_eq(dist["food"], 0, "food = 0")
	assert_eq(dist["wood"], 0, "wood = 0")

	eco.free()
	scene.free()


func _test_economy_queue_to_resource() -> void:
	print("\n--- AIEconomy: Queue Villager ---")

	var scene: Node = _make_scene()
	var eco: Node = _make_economy(scene, 1)

	_begin_test("queue to resource with no villagers doesn't crash")
	eco._queue_villager_to_resource("food")
	assert_true(true, "no crash")

	eco.free()
	scene.free()


# =============================================================================
# AIMilitary Tests
# =============================================================================
func _test_military_initialization() -> void:
	print("\n--- AIMilitary: Initialization ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1)

	_begin_test("player_id set")
	assert_eq(mil.ai_player_id, 1, "player_id = 1")

	_begin_test("attack threshold default")
	assert_eq(mil._attack_threshold, 80, "threshold = 80")

	_begin_test("attack cooldown default")
	assert_eq(mil._attack_cooldown, 30.0, "cooldown = 30")

	mil.free()
	scene.free()


func _test_military_should_attack() -> void:
	print("\n--- AIMilitary: Should Attack ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1)

	_begin_test("should_attack false with no army")
	assert_false(mil.should_attack(), "no army = no attack")

	mil.free()
	scene.free()


func _test_military_army_strength() -> void:
	print("\n--- AIMilitary: Army Strength ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1)

	_begin_test("army strength = 0 with no units")
	assert_eq(mil.get_army_strength(), 0, "strength = 0")

	_begin_test("army composition empty")
	assert_true(mil.get_army_composition().is_empty(), "empty composition")

	mil.free()
	scene.free()


func _test_military_choose_unit_counter() -> void:
	print("\n--- AIMilitary: Choose Unit Counter ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1)

	_begin_test("choose_unit_to_train returns valid type")
	var unit: String = mil.choose_unit_to_train()
	assert_true(unit in ["swordsman", "spearman", "archer", "cavalry"],
		"valid unit type: " + unit)

	mil.free()
	scene.free()


func _test_military_plan_attack_null_safety() -> void:
	print("\n--- AIMilitary: Plan Attack Null Safety ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1)

	_begin_test("plan_attack doesn't crash without CombatManager")
	mil.plan_attack()
	assert_true(true, "no crash")

	mil.free()
	scene.free()


func _test_military_defend_base_null_safety() -> void:
	print("\n--- AIMilitary: Defend Base Null Safety ---")

	var scene: Node = _make_scene()
	var mil: Node = _make_military(scene, 1)

	_begin_test("defend_base doesn't crash without CombatManager")
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
	var bld: Node = _make_builder(scene, 1)

	_begin_test("player_id set")
	assert_eq(bld.ai_player_id, 1, "player_id = 1")

	_begin_test("build cooldown default")
	assert_eq(bld._build_cooldown, 15.0, "cooldown = 15")

	bld.free()
	scene.free()


func _test_builder_should_expand() -> void:
	print("\n--- AIBuilder: Should Expand ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1)

	_begin_test("should_expand false with no buildings")
	assert_false(bld.should_expand(), "no expansion with nothing")

	bld.free()
	scene.free()


func _test_builder_building_priority() -> void:
	print("\n--- AIBuilder: Building Priority ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1)

	_begin_test("priority list not empty")
	var priority: Array = bld.get_building_priority()
	assert_true(priority.size() > 0, "priority not empty")

	_begin_test("priority starts with essential buildings")
	assert_eq(priority[0], "barracks", "first = barracks (no barracks)")

	bld.free()
	scene.free()


func _test_builder_find_expansion_null_safety() -> void:
	print("\n--- AIBuilder: Find Expansion Null Safety ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1)

	_begin_test("find_expansion_spot doesn't crash without CombatManager")
	var spot: Vector2 = bld.find_expansion_spot()
	assert_true(true, "no crash")

	bld.free()
	scene.free()


func _test_builder_build_defenses_null_safety() -> void:
	print("\n--- AIBuilder: Build Defenses Null Safety ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1)

	_begin_test("build_defenses doesn't crash without CombatManager")
	bld.build_defenses()
	assert_true(true, "no crash")

	bld.free()
	scene.free()


func _test_builder_repair_damaged() -> void:
	print("\n--- AIBuilder: Repair Damaged ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1)

	_begin_test("repair_damaged_buildings doesn't crash with no buildings")
	bld.repair_damaged_buildings()
	assert_true(true, "no crash")

	bld.free()
	scene.free()


func _test_builder_build_essentials() -> void:
	print("\n--- AIBuilder: Build Essentials ---")

	var scene: Node = _make_scene()
	var bld: Node = _make_builder(scene, 1)

	_begin_test("build_essentials doesn't crash with no buildings")
	bld.build_essentials()
	assert_true(true, "no crash")

	bld.free()
	scene.free()
