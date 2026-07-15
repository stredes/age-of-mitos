extends Node

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

	var dmg: int = calculate_damage(attacker_data, target_data)
	var attacker_id: int = attacker.get("unit_id") if attacker.get("unit_id") != null else -1
	var projectile_type: String = attacker_data.get("projectile_type", "")
	var attack_range: float = attacker_data.get("range", 48.0)
	var is_ranged: bool = attack_range > 48.0

	if is_ranged and not projectile_type.is_empty() and projectile_type != "none":
		spawn_projectile(attacker, target, dmg, projectile_type)
	else:
		apply_damage(target, dmg, attacker_id)
		EventBus.unit_attacked.emit(attacker_id, target.get("unit_id") if target.get("unit_id") != null else -1, dmg)


func calculate_damage(attacker_data: Dictionary, target_data: Dictionary) -> int:
	var base_attack: int = attacker_data.get("attack", 1)
	var target_armor: int = target_data.get("armor", 0)
	var base_damage: int = DamageCalculator.calculate_base_damage(base_attack, target_armor)

	var bonus_vs: Dictionary = attacker_data.get("bonus_vs", {})
	var target_type: String = target_data.get("unit_type", "")
	base_damage = DamageCalculator.calculate_bonus_damage(base_damage, bonus_vs, target_type)

	var crit_result: Array = DamageCalculator.calculate_critical(base_damage)
	base_damage = crit_result[0]
	var _is_crit: bool = crit_result[1]

	return base_damage


func apply_damage(target: Node2D, damage: int, attacker_id: int) -> void:
	if target == null or not is_instance_valid(target):
		return

	var target_id: int = -1
	if target.get("unit_id") != null:
		target_id = target.unit_id
	elif target.get("building_id") != null:
		target_id = target.building_id

	var health_comp: Node = target.get_node_or_null("HealthComponent")
	if health_comp != null and health_comp.has_method("take_damage"):
		health_comp.take_damage(damage, attacker_id)
	elif target.has_method("take_damage"):
		target.take_damage(damage, attacker_id)

	var crit_result: Array = DamageCalculator.calculate_critical(damage)
	var final_dmg: int = crit_result[0]
	var is_crit: bool = crit_result[1]
	EventBus.damage_dealt.emit(target_id, attacker_id, final_dmg, is_crit)

	_spawn_impact_at(target.global_position)


func spawn_projectile(attacker: Node2D, target: Node2D, dmg: int, projectile_type: String) -> void:
	if attacker == null or target == null:
		return

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


func _spawn_impact_at(pos: Vector2) -> void:
	var particle_manager: Node = get_tree().current_scene.get_node_or_null("ParticleEffects")
	if particle_manager == null:
		particle_manager = _find_in_scene("ParticleEffects")
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect("combat_impact", pos)


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
