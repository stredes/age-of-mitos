class_name DamageCalculator
extends RefCounted


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
