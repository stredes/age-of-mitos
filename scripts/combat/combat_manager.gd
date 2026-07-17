extends Node

signal attack_processed(attacker_id: int, target_id: int, damage: int)
signal area_damage_dealt(center: Vector2, radius: float, targets_hit: int)

var _active_projectiles: Array[Node2D] = []
var _projectile_id_counter: int = 0


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	var i: int = _active_projectiles.size() - 1
	while i >= 0:
		var proj: Node2D = _active_projectiles[i]
		if not is_instance_valid(proj):
			_active_projectiles.remove_at(i)
		i -= 1


func process_attack(attacker: Node2D, target: Node2D) -> void:
	if attacker == null or target == null:
		return
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return

	var attacker_data: Dictionary = _get_unit_data(attacker)
	var target_data: Dictionary = _get_unit_data(target)
	if attacker_data.is_empty():
		return

	var attacker_id: int = attacker.get("unit_id") if attacker.get("unit_id") != null else -1
	var projectile_type: String = attacker_data.get("projectile_type", "")
	var attack_range: float = attacker_data.get("range", 48.0)
	var is_ranged: bool = attack_range > 48.0
	var splash_radius: float = attacker_data.get("splash_radius", 0.0)
	var pierce_count: int = attacker_data.get("pierce_count", 0)
	var chain_count: int = attacker_data.get("chain_count", 0)

	if is_ranged and not projectile_type.is_empty() and projectile_type != "none":
		spawn_projectile(attacker, target, attacker_data, projectile_type)
	else:
		var dmg: int = calculate_damage(attacker_data, target_data)
		apply_damage(target, dmg, attacker_id)
		EventBus.unit_attacked.emit(attacker_id, target.get("unit_id") if target.get("unit_id") != null else -1, dmg)

		if splash_radius > 0.0:
			apply_area_damage(target.global_position, splash_radius, dmg, attacker_id, attacker_data, target)
		if pierce_count > 0:
			_apply_pierce_damage(attacker, target, dmg, attacker_id, pierce_count, attacker_data)
		if chain_count > 0:
			_apply_chain_damage(target, dmg, attacker_id, chain_count, attacker_data)

	attack_processed.emit(attacker_id, target.get("unit_id") if target.get("unit_id") != null else -1, 0)


func calculate_damage(attacker_data: Dictionary, target_data: Dictionary, attacker_pos: Vector2 = Vector2.ZERO, target_pos: Vector2 = Vector2.ZERO) -> int:
	var base_attack: int = attacker_data.get("attack", 1)
	var target_armor: int = target_data.get("armor", 0)
	var base_damage: int = DamageCalculator.calculate_base_damage(base_attack, target_armor)

	var bonus_vs: Dictionary = attacker_data.get("bonus_vs", {})
	var target_type: String = target_data.get("unit_type", "")
	base_damage = DamageCalculator.calculate_bonus_damage(base_damage, bonus_vs, target_type)

	var terrain_bonus: float = DamageCalculator.calculate_terrain_damage_bonus(attacker_data, target_data, attacker_pos, target_pos)
	base_damage = int(float(base_damage) * terrain_bonus)

	var crit_result: Array = DamageCalculator.calculate_critical(base_damage)
	base_damage = crit_result[0]
	var _is_crit: bool = crit_result[1]

	return base_damage


func apply_damage(target: Node2D, damage: int, attacker_id: int) -> int:
	if target == null or not is_instance_valid(target):
		return 0

	var target_id: int = -1
	if target.get("unit_id") != null:
		target_id = target.unit_id
	elif target.get("building_id") != null:
		target_id = target.building_id

	var actual_damage: int = damage
	var health_comp: Node = target.get_node_or_null("HealthComponent")
	if health_comp != null and health_comp.has_method("take_damage"):
		var old_hp: int = health_comp.get("current_hp") if health_comp.get("current_hp") != null else 0
		health_comp.take_damage(damage, attacker_id)
		var new_hp: int = health_comp.get("current_hp") if health_comp.get("current_hp") != null else 0
		actual_damage = old_hp - new_hp
	elif target.has_method("take_damage"):
		target.take_damage(damage, attacker_id)

	var crit_result: Array = DamageCalculator.calculate_critical(actual_damage)
	var final_dmg: int = crit_result[0]
	var is_crit: bool = crit_result[1]
	EventBus.damage_dealt.emit(target_id, attacker_id, final_dmg, is_crit)

	_spawn_impact_at(target.global_position)
	return actual_damage


func apply_area_damage(center: Vector2, radius: float, base_damage: int, attacker_id: int, attacker_data: Dictionary = {}, primary_target: Node2D = null) -> int:
	var targets_hit: int = 0
	var total_damage: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")

	for unit: Node in all_units:
		if unit == primary_target:
			continue
		if not (unit is Node2D):
			continue
		var unit_player_id: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if unit_player_id == -1 or unit_player_id == attacker_id:
			continue

		var dist: float = (unit as Node2D).global_position.distance_to(center)
		if dist > radius:
			continue

		var distance_ratio: float = 1.0 - (dist / radius)
		var falloff_damage: int = maxi(int(float(base_damage) * distance_ratio), 1)

		var target_data: Dictionary = _get_unit_data(unit)
		if not attacker_data.is_empty() and not target_data.is_empty():
			var bonus_vs: Dictionary = attacker_data.get("bonus_vs", {})
			var target_type: String = target_data.get("unit_type", "")
			falloff_damage = DamageCalculator.calculate_bonus_damage(falloff_damage, bonus_vs, target_type)

		apply_damage(unit as Node2D, falloff_damage, attacker_id)
		targets_hit += 1
		total_damage += falloff_damage

	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		if not (bld is Node2D):
			continue
		var bld_player_id: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if bld_player_id == -1 or bld_player_id == attacker_id:
			continue

		var dist: float = (bld as Node2D).global_position.distance_to(center)
		if dist > radius:
			continue

		var distance_ratio: float = 1.0 - (dist / radius)
		var falloff_damage: int = maxi(int(float(base_damage) * distance_ratio), 1)
		apply_damage(bld as Node2D, falloff_damage, attacker_id)
		targets_hit += 1
		total_damage += falloff_damage

	if targets_hit > 0:
		area_damage_dealt.emit(center, radius, targets_hit)
		_spawn_area_impact_at(center, radius)

	return total_damage


func _apply_pierce_damage(attacker: Node2D, primary_target: Node2D, base_damage: int, attacker_id: int, pierce_count: int, attacker_data: Dictionary) -> void:
	if attacker == null or primary_target == null:
		return

	var attacker_pos: Vector2 = attacker.global_position
	var target_pos: Vector2 = primary_target.global_position
	var direction: Vector2 = (target_pos - attacker_pos).normalized()
	var attack_range: float = attacker_data.get("range", 48.0)

	var pierced: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")

	for unit: Node in all_units:
		if unit == primary_target:
			continue
		if not (unit is Node2D):
			continue
		if pierced >= pierce_count:
			break

		var unit_player_id: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if unit_player_id == -1 or unit_player_id == attacker_id:
			continue

		var unit_pos: Vector2 = (unit as Node2D).global_position
		var to_unit: Vector2 = unit_pos - attacker_pos
		var dot: float = to_unit.dot(direction)
		if dot <= 0.0 or dot > attack_range:
			continue

		var lateral: float = (to_unit - direction * dot).length()
		if lateral > 30.0:
			continue

		var pierce_falloff: float = 1.0 - (float(pierced) / float(pierce_count + 1)) * 0.3
		var pierce_damage: int = maxi(int(float(base_damage) * pierce_falloff), 1)

		var target_data: Dictionary = _get_unit_data(unit)
		if not attacker_data.is_empty() and not target_data.is_empty():
			var bonus_vs: Dictionary = attacker_data.get("bonus_vs", {})
			var target_type: String = target_data.get("unit_type", "")
			pierce_damage = DamageCalculator.calculate_bonus_damage(pierce_damage, bonus_vs, target_type)

		apply_damage(unit as Node2D, pierce_damage, attacker_id)
		pierced += 1


func _apply_chain_damage(primary_target: Node2D, base_damage: int, attacker_id: int, chain_count: int, attacker_data: Dictionary) -> void:
	if primary_target == null:
		return

	var chain_pos: Vector2 = primary_target.global_position
	var chain_range: float = 150.0
	var chained: Array[Node2D] = [primary_target]

	for _i in range(chain_count):
		var nearest: Node2D = _find_nearest_enemy(chain_pos, attacker_id, chain_range, chained)
		if nearest == null:
			break

		var chain_falloff: float = 1.0 - (float(chained.size()) / float(chain_count + 1)) * 0.25
		var chain_damage: int = maxi(int(float(base_damage) * chain_falloff), 1)

		var target_data: Dictionary = _get_unit_data(nearest)
		if not attacker_data.is_empty() and not target_data.is_empty():
			var bonus_vs: Dictionary = attacker_data.get("bonus_vs", {})
			var target_type: String = target_data.get("unit_type", "")
			chain_damage = DamageCalculator.calculate_bonus_damage(chain_damage, bonus_vs, target_type)

		apply_damage(nearest, chain_damage, attacker_id)
		chain_pos = nearest.global_position
		chained.append(nearest)

		_spawn_chain_lightning(primary_target.global_position, nearest.global_position)


func _find_nearest_enemy(from_pos: Vector2, exclude_player: int, range: float, exclude: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_dist: float = range
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")

	for unit: Node in all_units:
		if not (unit is Node2D):
			continue
		if exclude.has(unit):
			continue

		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid == -1 or pid == exclude_player:
			continue

		var dist: float = (unit as Node2D).global_position.distance_to(from_pos)
		if dist < best_dist:
			best_dist = dist
			best = unit as Node2D

	return best


func spawn_projectile(attacker: Node2D, target: Node2D, attacker_data: Dictionary, projectile_type: String) -> void:
	if attacker == null or target == null:
		return

	var dmg: int = calculate_damage(attacker_data, _get_unit_data(target), attacker.global_position, target.global_position)
	_projectile_id_counter += 1
	var proj: Node2D = _create_projectile_node()
	proj.initialize(attacker, target, dmg, projectile_type)
	_active_projectiles.append(proj)

	var attacker_id: int = attacker.get("unit_id") if attacker.get("unit_id") != null else -1
	var target_id: int = target.get("unit_id") if target.get("unit_id") != null else -1
	EventBus.projectile_fired.emit(_projectile_id_counter, attacker_id, target_id, attacker.global_position, dmg)


func _create_projectile_node() -> Node2D:
	var proj: Area2D = Area2D.new()
	proj.set_script(load("res://scripts/combat/projectile.gd"))
	var world: Node = get_tree().current_scene
	if world != null:
		world.add_child(proj)
	else:
		add_child(proj)
	return proj


func get_threat_at_position(position: Vector2, radius: float, player_id: int) -> int:
	var total_strength: int = 0
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in all_units:
		if unit is Node2D == false:
			continue
		var unit_player_id: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if unit_player_id == -1 or unit_player_id == player_id:
			continue
		var dist: float = (unit as Node2D).global_position.distance_to(position)
		if dist <= radius:
			var hp: int = unit.get("current_hp") if unit.get("current_hp") != null else 100
			var atk: int = unit.get("attack_damage") if unit.get("attack_damage") != null else 5
			total_strength += hp + atk * 2

	var all_buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for bld: Node in all_buildings:
		if bld is Node2D == false:
			continue
		var bld_player_id: int = bld.get("player_id") if bld.get("player_id") != null else -1
		if bld_player_id == -1 or bld_player_id == player_id:
			continue
		var dist: float = (bld as Node2D).global_position.distance_to(position)
		if dist <= radius:
			var hp: int = bld.get("current_hp") if bld.get("current_hp") != null else 200
			var atk: int = bld.get("attack_damage") if bld.get("attack_damage") != null else 0
			total_strength += hp + atk * 2

	return total_strength


func get_enemies_in_radius(center: Vector2, radius: float, player_id: int) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_sq: float = radius * radius
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")

	for unit: Node in all_units:
		if not (unit is Node2D):
			continue
		var pid: int = unit.get("player_id") if unit.get("player_id") != null else -1
		if pid == -1 or pid == player_id:
			continue
		var dist_sq: float = (unit as Node2D).global_position.distance_squared_to(center)
		if dist_sq <= radius_sq:
			result.append(unit as Node2D)

	return result


func _spawn_impact_at(pos: Vector2) -> void:
	var particle_manager: Node = get_tree().current_scene.get_node_or_null("ParticleEffects")
	if particle_manager == null:
		particle_manager = _find_in_scene("ParticleEffects")
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect("combat_impact", pos)


func _spawn_area_impact_at(center: Vector2, radius: float) -> void:
	var particle_manager: Node = get_tree().current_scene.get_node_or_null("ParticleEffects")
	if particle_manager == null:
		particle_manager = _find_in_scene("ParticleEffects")
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect("area_impact", center)
		particle_manager.spawnEffect("area_ring", center)


func _spawn_chain_lightning(from: Vector2, to: Vector2) -> void:
	var particle_manager: Node = get_tree().current_scene.get_node_or_null("ParticleEffects")
	if particle_manager == null:
		particle_manager = _find_in_scene("ParticleEffects")
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect("chain_lightning", (from + to) * 0.5)


func _find_in_scene(target_name: String) -> Node:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	return _search(root, target_name)


func _search(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _search(child, target_name)
		if result != null:
			return result
	return null


func _get_unit_data(unit: Node) -> Dictionary:
	var unit_type: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
	if unit_type.is_empty():
		return {}
	return DataManager.get_unit_data(unit_type)
