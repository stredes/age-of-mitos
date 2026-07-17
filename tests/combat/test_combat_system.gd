extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0

func run_all_tests() -> void:
	_tests_passed = 0
	_tests_failed = 0
	print("=== COMBAT SYSTEM TESTS START ===")
	print("")

	_test_damage_calculator_base()
	_test_damage_calculator_bonus()
	_test_damage_calculator_crit()
	_test_damage_calculator_projectile_falloff()
	_test_damage_calculator_terrain()
	_test_damage_calculator_projectile_types()
	_test_damage_calculator_splash()
	_test_damage_calculator_pierce_chain()
	_test_damage_calculator_armor_pen()
	_test_combat_manager_init()
	_test_combat_manager_area_damage()
	_test_combat_manager_enemies_in_radius()
	_test_combat_manager_projectile_data()
	_test_projectile_initialization()

	print("")
	print("=== COMBAT SYSTEM TESTS END ===")
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


# =============================================================================
# DamageCalculator: Base
# =============================================================================
func _test_damage_calculator_base() -> void:
	print("\n--- DamageCalculator: Base ---")

	_begin_test("calculate_base_damage: attack > armor")
	assert_eq(DamageCalculator.calculate_base_damage(10, 3), 7, "10 - 3 = 7")

	_begin_test("calculate_base_damage: attack == armor")
	assert_eq(DamageCalculator.calculate_base_damage(5, 5), 1, "min 1")

	_begin_test("calculate_base_damage: attack < armor")
	assert_eq(DamageCalculator.calculate_base_damage(3, 10), 1, "min 1")

	_begin_test("calculate_base_damage: zeros")
	assert_eq(DamageCalculator.calculate_base_damage(0, 0), 1, "min 1")

	_begin_test("calculate_dps: normal")
	assert_true(absf(DamageCalculator.calculate_dps(10, 1.0) - 10.0) < 0.01, "10 dps")

	_begin_test("calculate_dps: zero speed")
	assert_eq(DamageCalculator.calculate_dps(10, 0.0), 0.0, "0 dps")

	_begin_test("get_effective_hp: no armor")
	assert_eq(DamageCalculator.get_effective_hp(100, 0), 100.0, "100 ehp")

	_begin_test("get_effective_hp: with armor")
	var ehp: float = DamageCalculator.get_effective_hp(100, 5)
	assert_range(ehp, 149.0, 151.0, "150 ehp")


# =============================================================================
# DamageCalculator: Bonus
# =============================================================================
func _test_damage_calculator_bonus() -> void:
	print("\n--- DamageCalculator: Bonus ---")

	var bonus: Dictionary = {"cavalry": 2.0, "archer": 1.5}

	_begin_test("calculate_bonus_damage: matching")
	assert_eq(DamageCalculator.calculate_bonus_damage(10, bonus, "cavalry"), 20, "2x")

	_begin_test("calculate_bonus_damage: non-matching")
	assert_eq(DamageCalculator.calculate_bonus_damage(10, bonus, "swordsman"), 10, "1x")

	_begin_test("calculate_bonus_damage: empty bonus")
	assert_eq(DamageCalculator.calculate_bonus_damage(10, {}, "cavalry"), 10, "1x")

	_begin_test("calculate_bonus_damage: empty type")
	assert_eq(DamageCalculator.calculate_bonus_damage(10, bonus, ""), 10, "1x")


# =============================================================================
# DamageCalculator: Critical
# =============================================================================
func _test_damage_calculator_crit() -> void:
	print("\n--- DamageCalculator: Critical ---")

	_begin_test("calculate_critical: no crit")
	var result: Array = DamageCalculator.calculate_critical(10, 0.0, 1.5)
	assert_eq(result[0], 10, "10 dmg")
	assert_false(result[1], "no crit")

	_begin_test("calculate_critical: always crit")
	var crit_result: Array = DamageCalculator.calculate_critical(10, 1.0, 2.0)
	assert_eq(crit_result[0], 20, "20 dmg")
	assert_true(crit_result[1], "crit")


# =============================================================================
# DamageCalculator: Projectile Falloff
# =============================================================================
func _test_damage_calculator_projectile_falloff() -> void:
	print("\n--- DamageCalculator: Projectile Falloff ---")

	_begin_test("calculate_projectile_damage: at origin")
	assert_eq(DamageCalculator.calculate_projectile_damage(10, 0.0, 100.0), 10, "10 dmg")

	_begin_test("calculate_projectile_damage: at max range")
	var proj_dmg: int = DamageCalculator.calculate_projectile_damage(10, 100.0, 100.0)
	assert_range(proj_dmg, 6, 8, "falloff")

	_begin_test("calculate_projectile_damage: zero range")
	assert_eq(DamageCalculator.calculate_projectile_damage(10, 50.0, 0.0), 10, "10 dmg")


# =============================================================================
# DamageCalculator: Terrain
# =============================================================================
func _test_damage_calculator_terrain() -> void:
	print("\n--- DamageCalculator: Terrain ---")

	_begin_test("TERRAIN_MODIFIERS has all terrains")
	assert_true(DamageCalculator.TERRAIN_MODIFIERS.has(DamageCalculator.Terrain.OPEN), "has OPEN")
	assert_true(DamageCalculator.TERRAIN_MODIFIERS.has(DamageCalculator.Terrain.FOREST), "has FOREST")
	assert_true(DamageCalculator.TERRAIN_MODIFIERS.has(DamageCalculator.Terrain.HILL), "has HILL")
	assert_true(DamageCalculator.Terrain_MODIFIERS.has(DamageCalculator.Terrain.WATER), "has WATER")

	_begin_test("OPEN terrain: no modifier")
	var open_mod: Dictionary = DamageCalculator.TERRAIN_MODIFIERS[DamageCalculator.Terrain.OPEN]
	assert_eq(open_mod["attack_mult"], 1.0, "attack = 1.0")
	assert_eq(open_mod["defense_mult"], 1.0, "defense = 1.0")

	_begin_test("FOREST terrain: defense bonus")
	var forest_mod: Dictionary = DamageCalculator.TERRAIN_MODIFIERS[DamageCalculator.Terrain.FOREST]
	assert_true(forest_mod["defense_mult"] > 1.0, "defense > 1.0")
	assert_true(forest_mod["move_speed"] < 1.0, "slower")

	_begin_test("HILL terrain: attack bonus")
	var hill_mod: Dictionary = DamageCalculator.TERRAIN_MODIFIERS[DamageCalculator.Terrain.HILL]
	assert_true(hill_mod["attack_mult"] > 1.0, "attack > 1.0")

	_begin_test("WATER terrain: penalty")
	var water_mod: Dictionary = DamageCalculator.TERRAIN_MODIFIERS[DamageCalculator.Terrain.WATER]
	assert_true(water_mod["attack_mult"] < 1.0, "attack < 1.0")
	assert_true(water_mod["move_speed"] < 1.0, "slower")

	_begin_test("calculate_terrain_damage_bonus: default OPEN")
	var bonus: float = DamageCalculator.calculate_terrain_damage_bonus({}, {}, Vector2(100, 100), Vector2(200, 200))
	assert_range(bonus, 0.9, 1.1, "OPEN bonus ~1.0")

	_begin_test("get_terrain_move_speed_modifier: default")
	var speed_mod: float = DamageCalculator.get_terrain_move_speed_modifier(Vector2(100, 100))
	assert_eq(speed_mod, 1.0, "OPEN speed = 1.0")

	_begin_test("get_terrain_defense_bonus: default")
	var def_bonus: float = DamageCalculator.get_terrain_defense_bonus(Vector2(100, 100))
	assert_eq(def_bonus, 1.0, "OPEN defense = 1.0")


# =============================================================================
# DamageCalculator: Projectile Types
# =============================================================================
func _test_damage_calculator_projectile_types() -> void:
	print("\n--- DamageCalculator: Projectile Types ---")

	_begin_test("PROJECTILE_TYPES has arrow")
	var arrow: Dictionary = DamageCalculator.get_projectile_data("arrow")
	assert_eq(arrow["speed"], 300.0, "arrow speed = 300")
	assert_eq(arrow["damage_type"], "physical", "arrow physical")
	assert_eq(arrow["homing"], true, "arrow homing")

	_begin_test("PROJECTILE_TYPES has rock")
	var rock: Dictionary = DamageCalculator.get_projectile_data("rock")
	assert_eq(rock["speed"], 180.0, "rock speed = 180")
	assert_true(rock["splash"] > 0.0, "rock has splash")
	assert_eq(rock["armor_pen"], 2, "rock armor pen = 2")

	_begin_test("PROJECTILE_TYPES has bolt")
	var bolt: Dictionary = DamageCalculator.get_projectile_data("bolt")
	assert_eq(bolt["speed"], 400.0, "bolt speed = 400")
	assert_true(bolt["pierce"] > 0, "bolt has pierce")

	_begin_test("PROJECTILE_TYPES has fireball")
	var fireball: Dictionary = DamageCalculator.get_projectile_data("fireball")
	assert_eq(fireball["damage_type"], "fire", "fireball fire")
	assert_true(fireball["splash"] > 0.0, "fireball splash")

	_begin_test("PROJECTILE_TYPES has lightning")
	var lightning: Dictionary = DamageCalculator.get_projectile_data("lightning")
	assert_eq(lightning["damage_type"], "magic", "lightning magic")
	assert_true(lightning["chain"] > 0, "lightning chain")
	assert_eq(lightning["armor_pen"], 10, "lightning armor pen")

	_begin_test("PROJECTILE_TYPES has boulder")
	var boulder: Dictionary = DamageCalculator.get_projectile_data("boulder")
	assert_eq(boulder["speed"], 120.0, "boulder speed = 120")
	assert_true(boulder["splash"] > 50.0, "boulder big splash")

	_begin_test("get_projectile_data: unknown defaults to arrow")
	var unknown: Dictionary = DamageCalculator.get_projectile_data("unknown")
	assert_eq(unknown["speed"], 300.0, "defaults to arrow")


# =============================================================================
# DamageCalculator: Splash
# =============================================================================
func _test_damage_calculator_splash() -> void:
	print("\n--- DamageCalculator: Splash ---")

	_begin_test("calculate_splash_damage: at center")
	assert_eq(DamageCalculator.calculate_splash_damage(100, 0.0, 80.0), 100, "100% at center")

	_begin_test("calculate_splash_damage: at edge")
	var edge_dmg: int = DamageCalculator.calculate_splash_damage(100, 80.0, 80.0)
	assert_range(edge_dmg, 0, 10, "near 0 at edge")

	_begin_test("calculate_splash_damage: half radius")
	var half_dmg: int = DamageCalculator.calculate_splash_damage(100, 40.0, 80.0)
	assert_range(half_dmg, 60, 80, "75% at half")

	_begin_test("calculate_splash_damage: zero radius")
	assert_eq(DamageCalculator.calculate_splash_damage(100, 50.0, 0.0), 100, "100% with 0 radius")


# =============================================================================
# DamageCalculator: Pierce & Chain
# =============================================================================
func _test_damage_calculator_pierce_chain() -> void:
	print("\n--- DamageCalculator: Pierce & Chain ---")

	_begin_test("calculate_pierce_damage: first target")
	var first: int = DamageCalculator.calculate_pierce_damage(100, 0, 3)
	assert_range(first, 90, 100, "~100% first")

	_begin_test("calculate_pierce_damage: last target")
	var last: int = DamageCalculator.calculate_pierce_damage(100, 2, 3)
	assert_range(last, 55, 75, "~60% last")

	_begin_test("calculate_chain_damage: first chain")
	var chain_first: int = DamageCalculator.calculate_chain_damage(100, 0, 3)
	assert_range(chain_first, 90, 100, "~100% first")

	_begin_test("calculate_chain_damage: last chain")
	var chain_last: int = DamageCalculator.calculate_chain_damage(100, 2, 3)
	assert_range(chain_last, 65, 85, "~75% last")

	_begin_test("calculate_armor_penetration: full armor")
	var no_pen: int = DamageCalculator.calculate_armor_penetration(20, 10, 0)
	assert_eq(no_pen, 10, "20 - 10 = 10")

	_begin_test("calculate_armor_penetration: with pen")
	var with_pen: int = DamageCalculator.calculate_armor_penetration(20, 10, 5)
	assert_eq(with_pen, 15, "20 - 5 = 15")

	_begin_test("calculate_armor_penetration: pierce all armor")
	var full_pen: int = DamageCalculator.calculate_armor_penetration(20, 10, 15)
	assert_eq(full_pen, 20, "20 - 0 = 20")


# =============================================================================
# CombatManager: Init
# =============================================================================
func _test_combat_manager_init() -> void:
	print("\n--- CombatManager: Init ---")

	var cm: Node = load("res://scripts/combat/combat_manager.gd").new()
	cm.name = "CombatManager"

	_begin_test("calculate_damage basic")
	var atk: Dictionary = {"attack": 10, "armor": 0}
	var tgt: Dictionary = {"unit_type": "swordsman", "armor": 3}
	var dmg: int = cm.calculate_damage(atk, tgt)
	assert_range(dmg, 6, 12, "7 +/- crit")

	_begin_test("process_attack null safety")
	cm.process_attack(null, null)
	assert_true(true, "no crash")

	_begin_test("apply_damage null safety")
	cm.apply_damage(null, 10, 1)
	assert_true(true, "no crash")

	cm.free()


# =============================================================================
# CombatManager: Area Damage
# =============================================================================
func _test_combat_manager_area_damage() -> void:
	print("\n--- CombatManager: Area Damage ---")

	var cm: Node = load("res://scripts/combat/combat_manager.gd").new()
	cm.name = "CombatManager"

	_begin_test("apply_area_damage with no units returns 0")
	var total: int = cm.apply_area_damage(Vector2(100, 100), 50.0, 10, 1, {}, null)
	assert_eq(total, 0, "0 damage with no units")

	_begin_test("apply_area_damage doesn't crash")
	cm.apply_area_damage(Vector2.ZERO, 100.0, 20, 1)
	assert_true(true, "no crash")

	cm.free()


# =============================================================================
# CombatManager: Enemies In Radius
# =============================================================================
func _test_combat_manager_enemies_in_radius() -> void:
	print("\n--- CombatManager: Enemies In Radius ---")

	var cm: Node = load("res://scripts/combat/combat_manager.gd").new()
	cm.name = "CombatManager"

	_begin_test("get_enemies_in_radius empty")
	var enemies: Array = cm.get_enemies_in_radius(Vector2.ZERO, 100.0, 1)
	assert_eq(enemies.size(), 0, "no enemies")

	cm.free()


# =============================================================================
# CombatManager: Projectile Data
# =============================================================================
func _test_combat_manager_projectile_data() -> void:
	print("\n--- CombatManager: Projectile Data ---")

	var cm: Node = load("res://scripts/combat/combat_manager.gd").new()
	cm.name = "CombatManager"

	_begin_test("_get_unit_data empty with no type")
	var data: Dictionary = cm._get_unit_data(Node2D.new())
	assert_true(data.is_empty(), "empty data")

	cm.free()


# =============================================================================
# Projectile: Initialization
# =============================================================================
func _test_projectile_initialization() -> void:
	print("\n--- Projectile: Initialization ---")

	_begin_test("Projectile class exists")
	var proj_script: GDScript = load("res://scripts/combat/projectile.gd")
	assert_true(proj_script != null, "script loaded")

	_begin_test("Projectile types have correct data")
	var arrow: Dictionary = DamageCalculator.get_projectile_data("arrow")
	assert_eq(arrow["speed"], 300.0, "arrow speed")

	var fireball: Dictionary = DamageCalculator.get_projectile_data("fireball")
	assert_true(fireball["splash"] > 0, "fireball splash")

	var lightning: Dictionary = DamageCalculator.get_projectile_data("lightning")
	assert_true(lightning["chain"] > 0, "lightning chain")

	var boulder: Dictionary = DamageCalculator.get_projectile_data("boulder")
	assert_true(boulder["splash"] > 50, "boulder splash")
