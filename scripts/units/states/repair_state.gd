## Repair state: villager walks to a damaged building and repairs it.
## Costs resources proportional to missing HP. When the building is fully
## repaired (or the villager can't afford repairs), returns to idle.
class_name RepairState
extends UnitState

var target_building: Node2D = null

var _repair_timer: float = 0.0
var _repair_interval: float = 1.0

const REPAIR_RANGE: float = 48.0
const ARRIVAL_TOLERANCE: float = 8.0
const REPAIR_HP_PER_TICK: int = 8
const COST_MULTIPLIER: float = 0.5


func enter() -> void:
	_repair_timer = 0.0

	if unit == null:
		state_machine.change_state("IdleState")
		return

	# Determine target building from pending or nearest damaged.
	if unit.pending_target_building != null:
		target_building = unit.pending_target_building
		unit.pending_target_building = null
	else:
		target_building = _find_nearest_damaged_building()

	if target_building == null or not is_instance_valid(target_building):
		state_machine.change_state("IdleState")
		return

	# Verify building is actually damaged and owned by same player.
	if not _is_valid_repair_target(target_building):
		state_machine.change_state("IdleState")
		return

	_move_to_building()


func update(delta: float) -> void:
	if target_building == null or not is_instance_valid(target_building):
		state_machine.change_state("IdleState")
		return

	# Building fully repaired.
	if target_building.current_hp >= target_building.max_hp:
		state_machine.change_state("IdleState")
		return

	# Building was destroyed.
	if target_building.current_hp <= 0:
		state_machine.change_state("IdleState")
		return

	var dist: float = unit.global_position.distance_to(target_building.global_position)

	if dist > REPAIR_RANGE:
		# Not in range — walk toward it.
		var mc: Node = unit.get_node_or_null("MovementComponent")
		if mc != null and not mc.is_moving:
			_move_to_building()
		return

	# In range — stop and repair.
	var mc_stop: Node = unit.get_node_or_null("MovementComponent")
	if mc_stop != null and mc_stop.is_moving:
		mc_stop.stop()

	_play_repair_anim()

	_repair_timer += delta
	if _repair_timer >= _repair_interval:
		_repair_timer = 0.0
		_do_repair()


func exit() -> void:
	target_building = null
	_repair_timer = 0.0


func set_target(building: Node2D) -> void:
	target_building = building

# =============================================================================
# Repair Logic
# =============================================================================

func _do_repair() -> void:
	if target_building == null or not is_instance_valid(target_building):
		return

	# Check if building is already at full HP.
	if target_building.current_hp >= target_building.max_hp:
		state_machine.change_state("IdleState")
		return

	# Calculate resource cost for this repair tick.
	var missing_hp: int = target_building.max_hp - target_building.current_hp
	var repair_amount: int = mini(missing_hp, REPAIR_HP_PER_TICK)

	var player_id: int = unit.get("player_id") if unit.get("player_id") != null else -1
	if player_id == -1:
		return

	# Compute cost from building data.
	var bld_data: Dictionary = DataManager.get_building_data(target_building.building_type)
	var base_cost: Dictionary = bld_data.get("cost", {})
	var cost: Dictionary = {}
	for res_type: String in base_cost:
		var base: int = base_cost[res_type]
		cost[res_type] = maxi(ceili(float(base) * COST_MULTIPLIER * float(repair_amount) / float(target_building.max_hp)), 1)

	# Check if player can afford.
	if not GameManager.can_afford(cost, player_id):
		# Can't afford — stop repairing.
		state_machine.change_state("IdleState")
		return

	# Spend resources and heal.
	GameManager.spend_resources(cost, player_id)
	target_building.heal(repair_amount)

	# Spawn repair particles.
	_spawn_repair_particles()


func _spawn_repair_particles() -> void:
	if target_building == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var pm: Node = _find_node_recursive(scene, "ParticleEffects")
	if pm != null and pm.has_method("spawnEffect"):
		pm.spawnEffect("build_construct", target_building.global_position + Vector2(0, -10), 3)

# =============================================================================
# Navigation
# =============================================================================

func _move_to_building() -> void:
	if target_building == null or unit == null:
		return
	var mc: Node = unit.get_node_or_null("MovementComponent")
	if mc != null:
		mc.move_to(target_building.global_position)
	_play_walk_anim()

# =============================================================================
# Target Finding
# =============================================================================

func _find_nearest_damaged_building() -> Node2D:
	if unit == null:
		return null

	var player_id: int = unit.get("player_id") if unit.get("player_id") != null else -1
	if player_id == -1:
		return null

	var best: Node2D = null
	var best_dist: float = INF
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	var buildings: Array[Node] = scene.get_tree().get_nodes_in_group("buildings")
	for b: Node in buildings:
		if not (b is Node2D):
			continue
		var bld: Node2D = b as Node2D
		var bld_player: int = bld.get("player_id") if bld.get("player_id") != null else -2
		if bld_player != player_id:
			continue
		if bld.get("is_constructed") != true:
			continue
		var hp: int = bld.get("current_hp") if bld.get("current_hp") != null else 0
		var max_hp: int = bld.get("max_hp") if bld.get("max_hp") != null else 100
		if hp >= max_hp:
			continue

		var dist: float = unit.global_position.distance_to(bld.global_position)
		if dist < best_dist:
			best_dist = dist
			best = bld

	return best


func _is_valid_repair_target(building: Node2D) -> bool:
	if building == null or not is_instance_valid(building):
		return false
	if building.get("is_constructed") != true:
		return false
	var hp: int = building.get("current_hp") if building.get("current_hp") != null else 0
	var max_hp: int = building.get("max_hp") if building.get("max_hp") != null else 100
	if hp >= max_hp:
		return false
	var my_player: int = unit.get("player_id") if unit.get("player_id") != null else -1
	var bld_player: int = building.get("player_id") if building.get("player_id") != null else -2
	return my_player == bld_player

# =============================================================================
# Animation
# =============================================================================

func _play_walk_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("walk")


func _play_repair_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("build")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_node_recursive(child, target_name)
		if result != null:
			return result
	return null
