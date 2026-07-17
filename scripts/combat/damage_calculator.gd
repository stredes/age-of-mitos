class_name DamageCalculator
extends RefCounted

enum Terrain { OPEN, FOREST, HILL, WATER, WALL }

const TERRAIN_MODIFIERS: Dictionary = {
	Terrain.OPEN: {"attack_mult": 1.0, "defense_mult": 1.0, "move_speed": 1.0},
	Terrain.FOREST: {"attack_mult": 0.9, "defense_mult": 1.2, "move_speed": 0.8},
	Terrain.HILL: {"attack_mult": 1.15, "defense_mult": 0.9, "move_speed": 0.7},
	Terrain.WATER: {"attack_mult": 0.7, "defense_mult": 0.8, "move_speed": 0.5},
	Terrain.WALL: {"attack_mult": 1.0, "defense_mult": 1.5, "move_speed": 0.0},
}

const HEIGHT_ADVANTAGE_BONUS: float = 0.15
const HEIGHT_PENALTY: float = 0.1
const FOREST_RANGE_PENALTY: float = 0.8
const HILL_SIGHT_BONUS: float = 1.3

const PROJECTILE_TYPES: Dictionary = {
	"arrow": {
		"speed": 300.0, "arc": 20.0, "color": Color(0.8, 0.7, 0.5),
		"damage_type": "physical", "armor_pen": 0, "splash": 0.0,
		"pierce": 0, "chain": 0, "homing": true,
	},
	"rock": {
		"speed": 180.0, "arc": 40.0, "color": Color(0.5, 0.5, 0.5),
		"damage_type": "physical", "armor_pen": 2, "splash": 60.0,
		"pierce": 0, "chain": 0, "homing": false,
	},
	"bolt": {
		"speed": 400.0, "arc": 10.0, "color": Color(0.3, 0.3, 0.3),
		"damage_type": "physical", "armor_pen": 5, "splash": 0.0,
		"pierce": 2, "chain": 0, "homing": false,
	},
	"fireball": {
		"speed": 200.0, "arc": 15.0, "color": Color(1.0, 0.4, 0.1),
		"damage_type": "fire", "armor_pen": 0, "splash": 80.0,
		"pierce": 0, "chain": 0, "homing": true,
	},
	"lightning": {
		"speed": 600.0, "arc": 0.0, "color": Color(0.4, 0.6, 1.0),
		"damage_type": "magic", "armor_pen": 10, "splash": 0.0,
		"pierce": 0, "chain": 3, "homing": true,
	},
	"boulder": {
		"speed": 120.0, "arc": 50.0, "color": Color(0.4, 0.35, 0.3),
		"damage_type": "physical", "armor_pen": 8, "splash": 100.0,
		"pierce": 0, "chain": 0, "homing": false,
	},
}


static func calculate_base_damage(attack: int, armor: int) -> int:
	return maxi(attack - armor, 1)


static func calculate_bonus_damage(base_damage: int, bonus_multipliers: Dictionary, target_type: String) -> int:
	if target_type.is_empty() or bonus_multipliers.is_empty():
		return base_damage
	if bonus_multipliers.has(target_type):
		return int(float(base_damage) * bonus_multipliers[target_type])
	return base_damage


static func calculate_critical(damage: int, crit_chance: float = 0.1, crit_multiplier: float = 1.5) -> Array:
	var is_crit: bool = randf() < crit_chance
	var final_damage: int = int(float(damage) * crit_multiplier) if is_crit else damage
	return [final_damage, is_crit]


static func calculate_projectile_damage(base_damage: int, distance: float, max_range: float) -> int:
	if max_range <= 0.0:
		return base_damage
	var ratio: float = clampf(distance / max_range, 0.0, 1.0)
	var falloff: float = 1.0 - ratio * 0.3
	return maxi(int(float(base_damage) * falloff), 1)


static func calculate_dps(attack: int, attack_speed: float) -> float:
	if attack_speed <= 0.0:
		return 0.0
	return float(attack) / attack_speed


static func get_effective_hp(hp: int, armor: int) -> float:
	if armor <= 0:
		return float(hp)
	return float(hp) * (1.0 + float(armor) * 0.1)


static func calculate_terrain_damage_bonus(attacker_data: Dictionary, target_data: Dictionary, attacker_pos: Vector2 = Vector2.ZERO, target_pos: Vector2 = Vector2.ZERO) -> float:
	var multiplier: float = 1.0

	var attacker_terrain: int = _get_terrain_at(attacker_pos)
	var target_terrain: int = _get_terrain_at(target_pos)

	var attack_mod: float = TERRAIN_MODIFIERS.get(attacker_terrain, TERRAIN_MODIFIERS[Terrain.OPEN])["attack_mult"]
	multiplier *= attack_mod

	var defense_mod: float = TERRAIN_MODIFIERS.get(target_terrain, TERRAIN_MODIFIERS[Terrain.OPEN])["defense_mult"]
	multiplier *= defense_mod

	if attacker_pos != Vector2.ZERO and target_pos != Vector2.ZERO:
		var height_diff: float = _get_height_at(attacker_pos) - _get_height_at(target_pos)
		if height_diff > 0.0:
			multiplier *= (1.0 + HEIGHT_ADVANTAGE_BONUS)
		elif height_diff < 0.0:
			multiplier *= (1.0 - HEIGHT_PENALTY)

	return multiplier


static func get_terrain_move_speed_modifier(position: Vector2) -> float:
	var terrain: int = _get_terrain_at(position)
	return TERRAIN_MODIFIERS.get(terrain, TERRAIN_MODIFIERS[Terrain.OPEN])["move_speed"]


static func get_terrain_defense_bonus(position: Vector2) -> float:
	var terrain: int = _get_terrain_at(position)
	return TERRAIN_MODIFIERS.get(terrain, TERRAIN_MODIFIERS[Terrain.OPEN])["defense_mult"]


static func get_projectile_data(projectile_type: String) -> Dictionary:
	return PROJECTILE_TYPES.get(projectile_type, PROJECTILE_TYPES["arrow"])


static func calculate_splash_damage(base_damage: int, distance_from_center: float, splash_radius: float) -> int:
	if splash_radius <= 0.0:
		return base_damage
	var ratio: float = clampf(distance_from_center / splash_radius, 0.0, 1.0)
	var falloff: float = 1.0 - ratio * ratio
	return maxi(int(float(base_damage) * falloff), 1)


static func calculate_pierce_damage(base_damage: int, pierce_index: int, max_pierce: int) -> int:
	if max_pierce <= 0:
		return base_damage
	var falloff: float = 1.0 - (float(pierce_index) / float(max_pierce + 1)) * 0.4
	return maxi(int(float(base_damage) * falloff), 1)


static func calculate_chain_damage(base_damage: int, chain_index: int, max_chain: int) -> int:
	if max_chain <= 0:
		return base_damage
	var falloff: float = 1.0 - (float(chain_index) / float(max_chain + 1)) * 0.3
	return maxi(int(float(base_damage) * falloff), 1)


static func calculate_armor_penetration(base_damage: int, armor: int, armor_pen: int) -> int:
	var effective_armor: int = maxi(armor - armor_pen, 0)
	return maxi(base_damage - effective_armor, 1)


static func get_effective_armor(target_data: Dictionary, is_ranged: bool) -> int:
	if is_ranged:
		return target_data.get("armor_ranged", target_data.get("armor", 0))
	return target_data.get("armor_melee", target_data.get("armor", 0))


static func calculate_attack_damage(attacker_data: Dictionary, target_data: Dictionary, is_ranged: bool = false, attacker_pos: Vector2 = Vector2.ZERO, target_pos: Vector2 = Vector2.ZERO) -> int:
	var base_attack: int = attacker_data.get("attack", 1)
	var effective_armor: int = get_effective_armor(target_data, is_ranged)
	var damage: int = calculate_base_damage(base_attack, effective_armor)

	var bonus_vs: Dictionary = attacker_data.get("bonus_vs", {})
	var target_type: String = target_data.get("unit_type", "")
	damage = calculate_bonus_damage(damage, bonus_vs, target_type)

	var bonus_vs_buildings: float = attacker_data.get("bonus_vs_buildings", 0.0)
	if bonus_vs_buildings > 0.0 and target_data.has("building_id"):
		damage = int(float(damage) * (1.0 + bonus_vs_buildings))

	var terrain_bonus: float = calculate_terrain_damage_bonus(attacker_data, target_data, attacker_pos, target_pos)
	damage = int(float(damage) * terrain_bonus)

	var crit_result: Array = calculate_critical(damage)
	damage = crit_result[0]

	return damage


static func calculate_projectile_attack_damage(attacker_data: Dictionary, target_data: Dictionary, projectile_type: String, distance: float, attacker_pos: Vector2 = Vector2.ZERO, target_pos: Vector2 = Vector2.ZERO) -> int:
	var base_damage: int = calculate_attack_damage(attacker_data, target_data, true, attacker_pos, target_pos)
	var proj_data: Dictionary = get_projectile_data(projectile_type)
	var armor_pen: int = proj_data.get("armor_pen", 0)

	if armor_pen > 0:
		var target_armor: int = get_effective_armor(target_data, true)
		base_damage = calculate_armor_penetration(base_damage, target_armor, armor_pen)

	var max_range: float = attacker_data.get("range", 8.0) * 32.0
	if max_range > 0.0:
		base_damage = calculate_projectile_damage(base_damage, distance, max_range)

	return base_damage


static func _get_terrain_at(_position: Vector2) -> int:
	return Terrain.OPEN


static func _get_height_at(_position: Vector2) -> float:
	return 0.0
