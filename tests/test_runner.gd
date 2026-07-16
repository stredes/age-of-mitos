extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test: String = ""

func run_all_tests() -> void:
	_tests_passed = 0
	_tests_failed = 0
	print("=== TEST SUITE START ===")
	print("")

	_test_damage_calculator()
	_test_health_component()
	_test_combat_component()
	_test_resource_manager()
	_test_ai_director_initialization()
	_test_ai_director_priority()
	_test_ai_military_counter_system()
	_test_ai_builder_essentials()
	_test_unit_manager()
	_test_unit_base()
	_test_combat_manager()

	print("")
	print("=== TEST SUITE END ===")
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
	_current_test = name
	print("  [TEST] %s" % name)


# =============================================================================
# DamageCalculator Tests
# =============================================================================
func _test_damage_calculator() -> void:
	print("\n--- DamageCalculator ---")

	_begin_test("calculate_base_damage: attack > armor")
	assert_eq(DamageCalculator.calculate_base_damage(10, 3), 7, "10 - 3 = 7")

	_begin_test("calculate_base_damage: attack == armor")
	assert_eq(DamageCalculator.calculate_base_damage(5, 5), 1, "min 1 when attack == armor")

	_begin_test("calculate_base_damage: attack < armor")
	assert_eq(DamageCalculator.calculate_base_damage(3, 10), 1, "min 1 when attack < armor")

	_begin_test("calculate_base_damage: zero attack")
	assert_eq(DamageCalculator.calculate_base_damage(0, 0), 1, "min 1 with zeros")

	_begin_test("calculate_bonus_damage: matching type")
	var bonus: Dictionary = {"cavalry": 2.0, "archer": 1.5}
	assert_eq(DamageCalculator.calculate_bonus_damage(10, bonus, "cavalry"), 20, "2x bonus vs cavalry")

	_begin_test("calculate_bonus_damage: non-matching type")
	assert_eq(DamageCalculator.calculate_bonus_damage(10, bonus, "swordsman"), 10, "no bonus")

	_begin_test("calculate_bonus_damage: empty bonus dict")
	assert_eq(DamageCalculator.calculate_bonus_damage(10, {}, "cavalry"), 10, "empty bonus")

	_begin_test("calculate_bonus_damage: empty target type")
	assert_eq(DamageCalculator.calculate_bonus_damage(10, bonus, ""), 10, "empty target")

	_begin_test("calculate_critical: deterministic (mock)")
	var result: Array = DamageCalculator.calculate_critical(10, 0.0, 1.5)
	assert_eq(result[0], 10, "no crit with 0 chance")
	assert_false(result[1], "is_crit should be false")

	_begin_test("calculate_critical: always crit")
	var crit_result: Array = DamageCalculator.calculate_critical(10, 1.0, 2.0)
	assert_eq(crit_result[0], 20, "2x crit damage")
	assert_true(crit_result[1], "is_crit should be true")

	_begin_test("calculate_projectile_damage: at origin")
	assert_eq(DamageCalculator.calculate_projectile_damage(10, 0.0, 100.0), 10, "full damage at origin")

	_begin_test("calculate_projectile_damage: at max range")
	var proj_dmg: int = DamageCalculator.calculate_projectile_damage(10, 100.0, 100.0)
	assert_range(proj_dmg, 6, 8, "falloff at max range (70% of 10 = 7)")

	_begin_test("calculate_projectile_damage: zero max range")
	assert_eq(DamageCalculator.calculate_projectile_damage(10, 50.0, 0.0), 10, "no falloff with 0 range")

	_begin_test("calculate_dps: normal")
	assert_true(absf(DamageCalculator.calculate_dps(10, 1.0) - 10.0) < 0.01, "10 dmg / 1s = 10 dps")

	_begin_test("calculate_dps: zero speed")
	assert_eq(DamageCalculator.calculate_dps(10, 0.0), 0.0, "0 dps with 0 speed")

	_begin_test("get_effective_hp: no armor")
	assert_eq(DamageCalculator.get_effective_hp(100, 0), 100.0, "100 hp no armor = 100 ehp")

	_begin_test("get_effective_hp: with armor")
	var ehp: float = DamageCalculator.get_effective_hp(100, 5)
	assert_range(ehp, 149.0, 151.0, "100 hp + 5 armor ≈ 150 ehp")


# =============================================================================
# HealthComponent Tests
# =============================================================================
func _test_health_component() -> void:
	print("\n--- HealthComponent ---")

	var hc: HealthComponent = HealthComponent.new()
	hc.max_hp = 100
	hc.current_hp = 100
	hc.is_alive = true

	_begin_test("HealthComponent: initial state")
	assert_eq(hc.current_hp, 100, "current_hp = 100")
	assert_true(hc.is_alive, "is_alive = true")

	_begin_test("HealthComponent: take damage")
	hc.take_damage(30)
	assert_eq(hc.current_hp, 70, "hp after 30 dmg = 70")
	assert_true(hc.is_alive, "still alive")

	_begin_test("HealthComponent: take lethal damage")
	hc.take_damage(80)
	assert_eq(hc.current_hp, 0, "hp = 0 after lethal")
	assert_false(hc.is_alive, "dead after lethal")

	_begin_test("HealthComponent: damage when dead")
	hc.take_damage(10)
	assert_eq(hc.current_hp, 0, "hp stays 0 when dead")

	_begin_test("HealthComponent: heal")
	var hc2: HealthComponent = HealthComponent.new()
	hc2.max_hp = 100
	hc2.current_hp = 50
	hc2.is_alive = true
	hc2.heal(30)
	assert_eq(hc2.current_hp, 80, "hp after heal 30 = 80")

	_begin_test("HealthComponent: heal capped at max")
	hc2.heal(50)
	assert_eq(hc2.current_hp, 100, "hp capped at max")

	_begin_test("HealthComponent: heal when dead")
	hc.heal(10)
	assert_eq(hc.current_hp, 0, "dead units don't heal")

	_begin_test("HealthComponent: get_hp_percent")
	var hc3: HealthComponent = HealthComponent.new()
	hc3.max_hp = 200
	hc3.current_hp = 100
	hc3.is_alive = true
	assert_true(absf(hc3.get_hp_percent() - 0.5) < 0.01, "50% hp")

	_begin_test("HealthComponent: get_missing_hp")
	assert_eq(hc3.get_missing_hp(), 100, "missing 100 hp")

	_begin_test("HealthComponent: set_max_hp heal to full")
	hc3.set_max_hp(150, true)
	assert_eq(hc3.current_hp, 150, "healed to new max")
	assert_eq(hc3.max_hp, 150, "max set to 150")

	_begin_test("HealthComponent: set_max_hp clamp current")
	var hc4: HealthComponent = HealthComponent.new()
	hc4.max_hp = 100
	hc4.current_hp = 80
	hc4.is_alive = true
	hc4.set_max_hp(50, false)
	assert_eq(hc4.current_hp, 50, "current clamped to 50")
	assert_eq(hc4.max_hp, 50, "max set to 50")

	hc.free()
	hc2.free()
	hc3.free()
	hc4.free()


# =============================================================================
# CombatComponent Tests
# =============================================================================
func _test_combat_component() -> void:
	print("\n--- CombatComponent ---")

	var cc: CombatComponent = CombatComponent.new()
	cc.attack_damage = 15
	cc.attack_range = 48.0
	cc.attack_speed = 1.0
	cc.attack_cooldown = 0.0

	_begin_test("CombatComponent: initial state")
	assert_eq(cc.attack_damage, 15, "damage = 15")
	assert_false(cc._is_ranged, "melee at range 48")

	_begin_test("CombatComponent: ranged detection")
	cc.attack_range = 200.0
	cc._is_ranged = cc.attack_range > 48.0
	assert_true(cc._is_ranged, "ranged at range 200")

	_begin_test("CombatComponent: can_attack when cooldown 0")
	cc.attack_cooldown = 0.0
	cc.target = Node2D.new()
	assert_true(cc.can_attack(), "can attack with target and no cooldown")

	_begin_test("CombatComponent: can_attack when on cooldown")
	cc.attack_cooldown = 0.5
	assert_false(cc.can_attack(), "cannot attack during cooldown")

	_begin_test("CombatComponent: can_attack with no target")
	cc.attack_cooldown = 0.0
	cc.target = null
	assert_false(cc.can_attack(), "cannot attack without target")

	_begin_test("CombatComponent: cooldown decrements")
	cc.attack_cooldown = 1.0
	cc._process(0.5)
	assert_true(absf(cc.attack_cooldown - 0.5) < 0.01, "cooldown reduced by delta")

	cc.free()


# =============================================================================
# ResourceManager Tests
# =============================================================================
func _test_resource_manager() -> void:
	print("\n--- ResourceManager ---")

	var rm: ResourceManager = ResourceManager.new()

	_begin_test("ResourceManager: constants exist")
	assert_eq(rm.BASE_GATHER_RATES["wood"], 0.39, "wood gather rate = 0.39")
	assert_eq(rm.CARRY_CAPACITY["villager"], 10, "villager carry = 10")

	_begin_test("ResourceManager: initial global_resources empty")
	assert_true(rm.global_resources.is_empty(), "starts empty")

	_begin_test("ResourceManager: get_carry_capacity")
	assert_eq(rm.get_carry_capacity("villager"), 10, "villager carry 10")
	assert_eq(rm.get_carry_capacity("unknown"), 10, "default carry 10")

	_begin_test("ResourceManager: can_afford with empty resources")
	assert_false(rm.can_afford({"food": 100}, 1), "cannot afford with no resources")

	_begin_test("ResourceManager: buffer system")
	rm._player_buffers[1] = {"food": 50, "wood": 30}
	assert_eq(rm._get_buffered(1, "food"), 50, "buffered food = 50")
	assert_eq(rm._get_buffered(1, "stone"), 0, "no buffered stone")

	_begin_test("ResourceManager: add to buffer")
	rm._add_to_buffer(1, "gold", 25)
	assert_eq(rm._get_buffered(1, "gold"), 25, "gold buffer = 25")

	rm._add_to_buffer(1, "gold", 15)
	assert_eq(rm._get_buffered(1, "gold"), 40, "gold buffer = 40 after add")

	_begin_test("ResourceManager: gather rate modifier")
	rm.gather_rates[1] = {"wood": 0.39, "food": 0.39}
	rm.gather_rate_modifiers[1] = {"wood": 1.0, "food": 1.0}
	rm.set_gather_rate_modifier("wood", 1.5, 1)
	assert_true(absf(rm.get_gather_rate("wood", 1) - 0.585) < 0.01, "wood rate with 1.5x mod")

	_begin_test("ResourceManager: set gather rate base")
	rm.set_gather_rate_base("food", 0.5, 1)
	rm.set_gather_rate_modifier("food", 1.0, 1)
	assert_true(absf(rm.get_gather_rate("food", 1) - 0.5) < 0.01, "food rate = 0.5")

	_begin_test("ResourceManager: get resource amount unknown player")
	assert_eq(rm.get_resource_amount("food", 999), 0, "unknown player = 0")

	_begin_test("ResourceManager: serialization round-trip")
	rm.global_resources[1] = {"food": 500, "wood": 300}
	rm.gather_rates[1] = {"wood": 0.5, "food": 0.5}
	rm.gather_rate_modifiers[1] = {"wood": 1.2, "food": 1.0}
	var save: Dictionary = rm.get_save_data()
	var rm2: ResourceManager = ResourceManager.new()
	rm2.load_save_data(save)
	assert_eq(rm2.global_resources[1]["food"], 500, "deserialized food = 500")
	assert_eq(rm2.gather_rates[1]["wood"], 0.5, "deserialized wood rate = 0.5")

	rm.free()
	rm2.free()


# =============================================================================
# AI Director Tests
# =============================================================================
func _test_ai_director_initialization() -> void:
	print("\n--- AIDirector ---")

	var scene: Node = Node.new()
	scene.name = "TestScene"
	add_child(scene)

	var dir: Node = load("res://scripts/ai/ai_director.gd").new()
	dir.name = "AIDirector"
	scene.add_child(dir)

	_begin_test("AIDirector: difficulty clamped")
	dir.initialize(1, 5)
	assert_eq(dir.difficulty, 3, "difficulty clamped to 3")

	dir.initialize(1, 0)
	assert_eq(dir.difficulty, 1, "difficulty clamped to 1")

	_begin_test("AIDirector: difficulty 1 = defensive")
	dir.initialize(1, 1)
	assert_eq(dir.personality, "defensive", "diff 1 = defensive")
	assert_eq(dir.update_interval, 5.0, "diff 1 interval = 5s")

	_begin_test("AIDirector: difficulty 2 = balanced")
	dir.initialize(1, 2)
	assert_eq(dir.personality, "balanced", "diff 2 = balanced")
	assert_eq(dir.update_interval, 3.0, "diff 2 interval = 3s")

	_begin_test("AIDirector: difficulty 3 = aggressive")
	dir.initialize(1, 3)
	assert_eq(dir.personality, "aggressive", "diff 3 = aggressive")
	assert_eq(dir.update_interval, 2.0, "diff 3 interval = 2s")

	_begin_test("AIDirector: creates sub-nodes")
	assert_true(dir.get_node_or_null("AIEconomy_1") != null, "AIEconomy created")
	assert_true(dir.get_node_or_null("AIMilitary_1") != null, "AIMilitary created")
	assert_true(dir.get_node_or_null("AIBuilder_1") != null, "AIBuilder created")

	dir.free()
	scene.free()


func _test_ai_director_priority() -> void:
	print("\n--- AIDirector Priority ---")

	var scene: Node = Node.new()
	scene.name = "TestScene"
	add_child(scene)

	var dir: Node = load("res://scripts/ai/ai_director.gd").new()
	dir.name = "AIDirector"
	scene.add_child(dir)
	dir.initialize(1, 2)

	_begin_test("AIDirector: _evaluate_priority returns string")
	var priority: String = dir._evaluate_priority()
	assert_true(priority in ["ECONOMY", "MILITARY", "EXPANSION", "DEFENSE"], "valid priority")

	dir.free()
	scene.free()


# =============================================================================
# AI Military Tests
# =============================================================================
func _test_ai_military_counter_system() -> void:
	print("\n--- AIMilitary ---")

	var mil: Node = load("res://scripts/ai/ai_military.gd").new()
	mil.name = "AIMilitary"
	mil.initialize(1)

	_begin_test("AIMilitary: should_attack false with no army")
	assert_false(mil.should_attack(), "no army = no attack")

	_begin_test("AIMilitary: army strength starts at 0")
	assert_eq(mil.get_army_strength(), 0, "strength = 0")

	_begin_test("AIMilitary: army composition empty")
	assert_true(mil.get_army_composition().is_empty(), "empty composition")

	mil.free()


# =============================================================================
# AI Builder Tests
# =============================================================================
func _test_ai_builder_essentials() -> void:
	print("\n--- AIBuilder ---")

	var bld: Node = load("res://scripts/ai/ai_builder.gd").new()
	bld.name = "AIBuilder"
	bld.initialize(1)

	_begin_test("AIBuilder: building priority non-empty")
	var priority: Array = bld.get_building_priority()
	assert_true(priority.size() > 0, "priority list not empty")

	_begin_test("AIBuilder: should_expand false with few resources")
	assert_false(bld.should_expand(), "not enough resources")

	bld.free()


# =============================================================================
# UnitManager Tests
# =============================================================================
func _test_unit_manager() -> void:
	print("\n--- UnitManager ---")

	var um: UnitManager = UnitManager.new()
	um.name = "UnitManager"

	_begin_test("UnitManager: initial state")
	assert_eq(um.get_unit_count(), 0, "starts with 0 units")
	assert_true(um.get_all_units().is_empty(), "no units")

	_begin_test("UnitManager: units dictionary empty")
	assert_true(um.units.is_empty(), "units dict empty")

	_begin_test("UnitManager: get_unit nonexistent")
	assert_eq(um.get_unit(999), null, "null for missing id")

	_begin_test("UnitManager: get_player_units empty")
	assert_true(um.get_player_units(1).is_empty(), "no player units")

	_begin_test("UnitManager: get_units_in_area empty")
	assert_true(um.get_units_in_area(Vector2.ZERO, 100.0).is_empty(), "no units in area")

	um.free()


# =============================================================================
# UnitBase Tests
# =============================================================================
func _test_unit_base() -> void:
	print("\n--- UnitBase ---")

	var unit: UnitBase = UnitBase.new()
	unit.unit_id = 1
	unit.unit_type = "swordsman"
	unit.player_id = 1
	unit.is_selected = false

	_begin_test("UnitBase: get_data returns dict")
	var data: Dictionary = unit.get_data()
	assert_eq(data["unit_id"], 1, "unit_id = 1")
	assert_eq(data["unit_type"], "swordsman", "type = swordsman")
	assert_eq(data["player_id"], 1, "player = 1")
	assert_false(data["is_selected"], "not selected")

	_begin_test("UnitBase: is_enemy same player")
	var other: UnitBase = UnitBase.new()
	other.player_id = 1
	other.unit_id = 2
	assert_false(unit.is_enemy(other), "same player = not enemy")

	_begin_test("UnitBase: is_enemy null")
	assert_false(unit.is_enemy(null), "null = not enemy")

	_begin_test("UnitBase: get_harvest_resource_type default")
	assert_eq(unit.get_harvest_resource_type(), "wood", "default wood")

	_begin_test("UnitBase: get_harvest_resource_type preferred")
	unit.preferred_resource = "food"
	assert_eq(unit.get_harvest_resource_type(), "food", "preferred food")

	_begin_test("UnitBase: get_grid_position fallback")
	unit.global_position = Vector2(64.0, 96.0)
	var grid_pos: Vector2i = unit.get_grid_position()
	assert_eq(grid_pos.x, 2, "grid x = 2")
	assert_eq(grid_pos.y, 3, "grid y = 3")

	unit.free()
	other.free()


# =============================================================================
# CombatManager Tests
# =============================================================================
func _test_combat_manager() -> void:
	print("\n--- CombatManager ---")

	var cm: Node = load("res://scripts/combat/combat_manager.gd").new()
	cm.name = "CombatManager"

	_begin_test("CombatManager: calculate_damage basic")
	var attacker: Dictionary = {"attack": 10, "armor": 0}
	var target: Dictionary = {"unit_type": "swordsman", "armor": 3}
	var dmg: int = cm.calculate_damage(attacker, target)
	assert_range(dmg, 6, 12, "damage with crit = 7 +/- crit")

	_begin_test("CombatManager: calculate_damage with bonus")
	var attacker2: Dictionary = {"attack": 10, "armor": 0, "bonus_vs": {"cavalry": 2.0}}
	var target2: Dictionary = {"unit_type": "cavalry", "armor": 0}
	var dmg2: int = cm.calculate_damage(attacker2, target2)
	assert_range(dmg2, 15, 25, "2x bonus damage")

	_begin_test("CombatManager: process_attack null safety")
	cm.process_attack(null, null)
	assert_true(true, "no crash on null")

	_begin_test("CombatManager: apply_damage null safety")
	cm.apply_damage(null, 10, 1)
	assert_true(true, "no crash on null apply_damage")

	cm.free()
