extends Node
## Manages unit stances: Aggressive, Defensive, Passive.
##
## Stance affects how units behave when idle or in combat:
##   Aggressive: Chase enemies up to 400px, attack on sight (default).
##   Defensive: Attack enemies within attack range only, never chase.
##   Passive: Never auto-attack, only respond to direct attack commands.
##
## Attach to each unit. Reads stance from unit.stance or defaults to "defensive".

const STANCE_AGGRESSIVE: String = "aggressive"
const STANCE_DEFENSIVE: String = "defensive"
const STANCE_PASSIVE: String = "passive"

const AGGRO_RANGES: Dictionary = {
	STANCE_AGGRESSIVE: 300.0,
	STANCE_DEFENSIVE: 0.0,
	STANCE_PASSIVE: 0.0,
}

const CHASE_LIMITS: Dictionary = {
	STANCE_AGGRESSIVE: 400.0,
	STANCE_DEFENSIVE: 0.0,
	STANCE_PASSIVE: 0.0,
}

var _unit: Node2D = null


func _ready() -> void:
	_unit = get_parent() as Node2D


func set_stance(new_stance: String) -> void:
	if _unit == null:
		return
	if new_stance not in AGGRO_RANGES:
		return
	_unit.stance = new_stance


func get_stance() -> String:
	if _unit == null:
		return STANCE_DEFENSIVE
	return _unit.get("stance") if _unit.get("stance") != null else STANCE_DEFENSIVE


func get_aggro_range() -> float:
	return AGGRO_RANGES.get(get_stance(), 0.0)


func get_chase_limit() -> float:
	return CHASE_LIMITS.get(get_stance(), 0.0)


func should_auto_attack() -> bool:
	return get_stance() == STANCE_AGGRESSIVE


func should_attack_in_range() -> bool:
	var s: String = get_stance()
	return s == STANCE_AGGRESSIVE or s == STANCE_DEFENSIVE


func should_chase() -> bool:
	return get_stance() == STANCE_AGGRESSIVE


func can_retaliate() -> bool:
	return get_stance() != STANCE_PASSIVE


func get_stance_color() -> Color:
	match get_stance():
		STANCE_AGGRESSIVE:
			return Color(1.0, 0.3, 0.2)
		STANCE_DEFENSIVE:
			return Color(0.2, 0.6, 1.0)
		STANCE_PASSIVE:
			return Color(0.5, 0.5, 0.5)
		_:
			return Color.WHITE


func get_stance_name() -> String:
	match get_stance():
		STANCE_AGGRESSIVE:
			return "Aggressive"
		STANCE_DEFENSIVE:
			return "Defensive"
		STANCE_PASSIVE:
			return "Passive"
		_:
			return "Unknown"
