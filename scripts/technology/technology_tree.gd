## Manages technology research, prerequisites, effects, and per-player state.
##
## Tracks which techs are researched, currently researching, and applies
## multiplicative effects to gather rates, attack, and other modifiers.
extends Node

# =============================================================================
# Signals
# =============================================================================

signal research_started(tech_id: String, player_id: int)
signal research_completed(tech_id: String, player_id: int)
signal tech_effect_applied(tech_id: String, player_id: int)

# =============================================================================
# Properties
# =============================================================================

## player_id -> Array of researched tech_id strings.
var researched: Dictionary = {}

## player_id -> { "tech_id": String, "building_id": int, "progress": float, "total_time": float }
var researching: Dictionary = {}

## player_id -> Dictionary of active modifier key -> float multiplier.
var tech_effects: Dictionary = {}

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	update_research(delta)

# =============================================================================
# Research API
# =============================================================================

## Check if a player can research a given technology.
func can_research(tech_id: String, player_id: int) -> bool:
	if not _has_player_state(player_id):
		_init_player_state(player_id)

	# Already researched.
	if tech_id in researched[player_id]:
		return false

	# Already researching.
	if researching.has(player_id) and researching[player_id].get("tech_id", "") == tech_id:
		return false

	# Check tech data exists.
	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	if tech_data.is_empty():
		# Try category data in case get_tech_data has nesting issues.
		var all_techs: Dictionary = DataManager.get_category_data("technologies")
		tech_data = _resolve_tech_data(tech_id, all_techs)
		if tech_data.is_empty():
			return false

	# Check tier prerequisites: must have at least one tech from each lower tier.
	var tier: int = tech_data.get("tier", 1)
	if tier > 1:
		var has_lower: bool = false
		for rt_id: String in researched[player_id]:
			var rt_data: Dictionary = DataManager.get_tech_data(rt_id)
			if rt_data.is_empty():
				rt_data = _resolve_tech_data(rt_id, DataManager.get_category_data("technologies"))
			if not rt_data.is_empty() and rt_data.get("tier", 0) < tier:
				has_lower = true
				break
		if not has_lower:
			return false

	# Check specific prerequisites (building or tech requirements).
	var requires: Array = tech_data.get("requires", [])
	for req: Variant in requires:
		var req_str: String = str(req)
		# If it's a tech ID, check it's researched.
		if req_str in researched[player_id]:
			continue
		# If it's a building type, check the player owns one.
		if _player_has_building(req_str, player_id):
			continue
		# Neither a researched tech nor an owned building.
		return false

	return true


## Start researching a technology. Deducts cost and begins the timer.
func start_research(tech_id: String, building_id: int, player_id: int) -> bool:
	if not can_research(tech_id, player_id):
		return false

	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	if tech_data.is_empty():
		tech_data = _resolve_tech_data(tech_id, DataManager.get_category_data("technologies"))
	if tech_data.is_empty():
		return false

	var cost: Dictionary = tech_data.get("cost", {})
	if not GameManager.can_afford(cost, player_id):
		return false

	# Cancel any existing research for this player first.
	cancel_research(player_id)

	GameManager.spend_resources(cost, player_id)

	var total_time: float = tech_data.get("research_time", tech_data.get("time", 60.0))
	researching[player_id] = {
		"tech_id": tech_id,
		"building_id": building_id,
		"progress": 0.0,
		"total_time": total_time,
	}

	research_started.emit(tech_id, player_id)
	EventBus.tech_started.emit(tech_id, player_id, total_time)
	return true


## Cancel current research for a player.
func cancel_research(player_id: int) -> void:
	if researching.has(player_id):
		researching.erase(player_id)

# =============================================================================
# Research Update
# =============================================================================

## Advance all active research timers by delta seconds.
func update_research(delta: float) -> void:
	var completed_entries: Array = []

	for pid: Variant in researching:
		var player_id: int = pid
		var info: Dictionary = researching[player_id]
		info["progress"] += delta * GameManager.game_speed

		if info["progress"] >= info["total_time"]:
			completed_entries.append(info.duplicate())

	for info: Dictionary in completed_entries:
		var player_id: int = _get_player_id_from_researching(info)
		if player_id != -1:
			complete_research(info["tech_id"], player_id)


func _get_player_id_from_researching(info: Dictionary) -> int:
	for pid: Variant in researching:
		if researching[pid] == info or researching[pid].get("tech_id", "") == info.get("tech_id", ""):
			return int(pid)
	return -1

# =============================================================================
# Research Completion
# =============================================================================

## Mark a tech as researched and apply its effects.
func complete_research(tech_id: String, player_id: int) -> void:
	if not _has_player_state(player_id):
		_init_player_state(player_id)

	if tech_id not in researched[player_id]:
		researched[player_id].append(tech_id)

	researching.erase(player_id)

	apply_tech_effects(tech_id, player_id)

	research_completed.emit(tech_id, player_id)
	EventBus.tech_completed.emit(tech_id, player_id)

# =============================================================================
# Effects
# =============================================================================

## Parse and apply a technology's effects to a player's modifier stack.
func apply_tech_effects(tech_id: String, player_id: int) -> void:
	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	if tech_data.is_empty():
		tech_data = _resolve_tech_data(tech_id, DataManager.get_category_data("technologies"))
	if tech_data.is_empty():
		return

	var effects: Dictionary = tech_data.get("effects", {})
	if effects.is_empty():
		return

	if not _has_player_state(player_id):
		_init_player_state(player_id)

	if not tech_effects.has(player_id):
		tech_effects[player_id] = {}

	for effect_key: String in effects:
		var value: Variant = effects[effect_key]
		if value is int or value is float:
			# Multiplicative stacking: multiply the existing modifier by the new value.
			var current: float = tech_effects[player_id].get(effect_key, 1.0)
			tech_effects[player_id][effect_key] = current * float(value)

	# Apply gather rate modifiers to ResourceManager.
	_apply_gather_rate_effects(tech_id, player_id, effects)

	# Apply combat modifiers.
	_apply_combat_effects(player_id, effects)

	# Apply other system modifiers.
	_apply_movement_effects(player_id, effects)

	tech_effect_applied.emit(tech_id, player_id)
	EventBus.tech_researched.emit(tech_id, player_id)


func _apply_gather_rate_effects(tech_id: String, player_id: int, effects: Dictionary) -> void:
	var res_manager: Node = _find_node_in_tree("ResourceManager")
	if res_manager == null:
		return

	var gather_keys: Array[String] = ["wood_gather_rate", "stone_gather_rate", "food_gather_rate", "gold_gather_rate"]
	for key: String in gather_keys:
		if effects.has(key):
			var new_modifier: float = get_total_modifier(key, player_id)
			var resource_type: String = key.replace("_gather_rate", "")
			if res_manager.has_method("set_gather_rate_modifier"):
				res_manager.set_gather_rate_modifier(resource_type, new_modifier, player_id)


func _apply_combat_effects(player_id: int, effects: Dictionary) -> void:
	# Combat modifiers are stored in tech_effects and queried by CombatManager
	# when calculating damage. No immediate action needed here.
	pass


func _apply_movement_effects(player_id: int, effects: Dictionary) -> void:
	# Movement speed modifiers are queried by units via get_total_modifier.
	pass

# =============================================================================
# Query API
# =============================================================================

## Get the research progress (0.0-1.0) for a player's current research.
func get_research_progress(player_id: int) -> float:
	if not researching.has(player_id):
		return 0.0
	var info: Dictionary = researching[player_id]
	var total: float = info.get("total_time", 1.0)
	if total <= 0.0:
		return 1.0
	return clampf(info.get("progress", 0.0) / total, 0.0, 1.0)


## Get all researched tech IDs for a player.
func get_researched_techs(player_id: int) -> Array:
	if not _has_player_state(player_id):
		return []
	return researched[player_id].duplicate()


## Get all techs available for research by a player.
func get_available_techs(player_id: int) -> Array:
	var available: Array = []
	var all_tech_ids: Array = DataManager.get_all_tech_ids()
	for tech_id_variant: Variant in all_tech_ids:
		var tech_id: String = str(tech_id_variant)
		if can_research(tech_id, player_id):
			available.append(tech_id)
	return available


## Get a specific modifier value from a tech for a player.
func get_tech_modifier(tech_id: String, player_id: int) -> Dictionary:
	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	if tech_data.is_empty():
		tech_data = _resolve_tech_data(tech_id, DataManager.get_category_data("technologies"))
	if tech_data.is_empty():
		return {}
	return tech_data.get("effects", {})


## Get the total stacked modifier for a specific modifier type across all researched techs.
func get_total_modifier(modifier_type: String, player_id: int) -> float:
	if not _has_player_state(player_id):
		return 1.0
	if not tech_effects.has(player_id):
		return 1.0
	return tech_effects[player_id].get(modifier_type, 1.0)


## Get the current researching info for a player.
func get_current_research(player_id: int) -> Dictionary:
	return researching.get(player_id, {})


## Check if a player has a specific tech researched.
func has_tech(tech_id: String, player_id: int) -> bool:
	if not _has_player_state(player_id):
		return false
	return tech_id in researched[player_id]


## Reapply all tech effects for a player (used after loading a save).
func reapply_all_effects() -> void:
	for pid: Variant in researched:
		var player_id: int = pid
		for tech_id: String in researched[player_id]:
			var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
			if tech_data.is_empty():
				tech_data = _resolve_tech_data(tech_id, DataManager.get_category_data("technologies"))
			if tech_data.is_empty():
				continue
			var effects: Dictionary = tech_data.get("effects", {})
			if not tech_effects.has(player_id):
				tech_effects[player_id] = {}
			for effect_key: String in effects:
				var value: Variant = effects[effect_key]
				if value is int or value is float:
					var current: float = tech_effects[player_id].get(effect_key, 1.0)
					tech_effects[player_id][effect_key] = current * float(value)

	# Reapply gather rates.
	for pid: Variant in tech_effects:
		var player_id: int = pid
		_apply_gather_rate_effects("", player_id, _extract_gather_effects(player_id))


func _extract_gather_effects(player_id: int) -> Dictionary:
	var result: Dictionary = {}
	if not tech_effects.has(player_id):
		return result
	for key: String in tech_effects[player_id]:
		if key.begins_with("wood_gather_rate") or key.begins_with("stone_gather_rate") or key.begins_with("food_gather_rate") or key.begins_with("gold_gather_rate"):
			result[key] = 1.0
	return result

# =============================================================================
# Player State
# =============================================================================

func _has_player_state(player_id: int) -> bool:
	return researched.has(player_id)


func _init_player_state(player_id: int) -> void:
	researched[player_id] = []
	tech_effects[player_id] = {}

# =============================================================================
# Data Resolution
# =============================================================================

## Resolve tech data from nested JSON structure (handles both flat and wrapped formats).
func _resolve_tech_data(tech_id: String, raw_data: Dictionary) -> Dictionary:
	# Direct lookup.
	if raw_data.has(tech_id):
		var entry: Variant = raw_data[tech_id]
		if entry is Dictionary:
			return entry as Dictionary

	# Nested under "technologies" key.
	if raw_data.has("technologies"):
		var techs: Variant = raw_data["technologies"]
		if techs is Dictionary:
			var techs_dict: Dictionary = techs as Dictionary
			if techs_dict.has(tech_id):
				var entry: Variant = techs_dict[tech_id]
				if entry is Dictionary:
					return entry as Dictionary

	return {}

# =============================================================================
# Building Check
# =============================================================================

func _player_has_building(building_type: String, player_id: int) -> bool:
	var building_manager: Node = _find_node_in_tree("BuildingManager")
	if building_manager == null:
		return false

	var buildings: Dictionary = building_manager.get("buildings") if building_manager.get("buildings") != null else {}
	for id: Variant in buildings:
		var building: Node2D = buildings[id]
		if not is_instance_valid(building):
			continue
		var b_pid: int = int(building.get("player_id")) if building.get("player_id") != null else -1
		if b_pid != player_id:
			continue
		var b_type: String = str(building.get("building_type")) if building.get("building_type") != null else ""
		if b_type == building_type:
			return true
	return false

# =============================================================================
# Helpers
# =============================================================================

func _find_node_in_tree(target_name: String) -> Node:
	var direct: Node = get_node_or_null("/root/GameWorld/" + target_name)
	if direct != null:
		return direct
	direct = get_node_or_null("/root/GameWorld/World/" + target_name)
	if direct != null:
		return direct

	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_recursive(scene, target_name)


func _find_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_recursive(child, target_name)
		if result != null:
			return result
	return null
