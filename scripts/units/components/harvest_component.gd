class_name HarvestComponent
extends Node

signal resource_gathered(type: String, amount: int)
signal resource_full(type: String, amount: int)
signal return_started()
signal return_completed()

@export var gather_rate: float = 1.0
@export var carry_capacity: int = 10

var current_carry: int = 0
var carry_resource_type: String = ""
var target_resource: Node2D = null
var drop_off_building: Node2D = null

var _parent_unit: Node2D = null
var _gather_timer: float = 0.0


func _ready() -> void:
	call_deferred("_setup_parent")


func _setup_parent() -> void:
	_parent_unit = get_parent() as Node2D


func initialize(data: Dictionary) -> void:
	var raw_gather_rate: Variant = data.get("gather_rate", 1.0)
	if raw_gather_rate is Dictionary:
		gather_rate = float(raw_gather_rate.get("wood", 1.0))
	elif raw_gather_rate is int or raw_gather_rate is float:
		gather_rate = float(raw_gather_rate)
	else:
		gather_rate = 1.0
	carry_capacity = data.get("carry_capacity", 10)


func is_full() -> bool:
	return current_carry >= carry_capacity


func harvest(delta: float) -> void:
	if target_resource == null or not is_instance_valid(target_resource):
		return
	if is_full():
		return

	_gather_timer += delta
	var gather_interval: float = 1.0
	if gather_rate > 0.0:
		gather_interval = 1.0 / gather_rate

	if _gather_timer >= gather_interval:
		_gather_timer = 0.0
		var available: int = 0
		if target_resource.has_method("get_current_amount"):
			available = target_resource.get_current_amount()
		elif target_resource.get("current_amount") != null:
			available = int(target_resource.get("current_amount"))

		if available <= 0:
			resource_full.emit(carry_resource_type, current_carry)
			return

		var to_gather: int = mini(1, available)
		var actual: int = 0
		if target_resource.has_method("harvest"):
			actual = target_resource.harvest(to_gather)
		else:
			actual = to_gather

		current_carry += actual

		if actual > 0:
			resource_gathered.emit(carry_resource_type, actual)
			_spawn_harvest_particles()

		if is_full():
			resource_full.emit(carry_resource_type, current_carry)


func find_nearest_resource(resource_type: String = "") -> Node2D:
	if _parent_unit == null:
		return null

	var best: Node2D = null
	var best_dist: float = INF
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	var candidates: Array[Node] = []
	_find_resource_nodes_recursive(scene, candidates, resource_type)

	for node: Node in candidates:
		if node is Node2D:
			var res: Node2D = node as Node2D
			var available: int = 0
			if res.has_method("get_current_amount"):
				available = res.get_current_amount()
			elif res.get("current_amount") != null:
				available = int(res.get("current_amount"))
			if available <= 0:
				continue
			if not resource_type.is_empty():
				var res_type: String = ""
				if res.has_method("get_resource_type"):
					res_type = res.get_resource_type()
				elif res.get("resource_type") != null:
					res_type = str(res.get("resource_type"))
				if res_type != resource_type:
					continue

			var dist: float = _parent_unit.global_position.distance_to(res.global_position)
			if dist < best_dist:
				best_dist = dist
				best = res

	return best


func find_nearest_drop_off() -> Node2D:
	if _parent_unit == null:
		return null

	var player_id: int = _parent_unit.get("player_id") if _parent_unit.has_method("get") and _parent_unit.get("player_id") != null else -1
	var best: Node2D = null
	var best_dist: float = INF
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	var candidates: Array[Node] = []
	_find_buildings_recursive(scene, candidates)

	for node: Node in candidates:
		if node is Node2D:
			var bld: Node2D = node as Node2D
			var bld_player: int = bld.get("player_id") if bld.has_method("get") and bld.get("player_id") != null else -2
			if bld_player != player_id and player_id != -1:
				continue
			var dist: float = _parent_unit.global_position.distance_to(bld.global_position)
			if dist < best_dist:
				best_dist = dist
				best = bld

	return best


func start_gathering(resource_node: Node2D) -> void:
	target_resource = resource_node
	if resource_node.has_method("get_resource_type"):
		carry_resource_type = resource_node.get_resource_type()
	elif resource_node.get("resource_type") != null:
		carry_resource_type = str(resource_node.get("resource_type"))
	current_carry = 0
	_gather_timer = 0.0


func return_resources() -> void:
	if drop_off_building == null or not is_instance_valid(drop_off_building):
		drop_off_building = find_nearest_drop_off()
		if drop_off_building == null:
			return

	return_started.emit()

	if current_carry > 0 and not carry_resource_type.is_empty():
		var player_id: int = _parent_unit.get("player_id") if _parent_unit.has_method("get") and _parent_unit.get("player_id") != null else -1
		var unit_id: int = _parent_unit.unit_id if _parent_unit.has_method("get") and _parent_unit.get("unit_id") != null else -1
		var drop_off_id: int = drop_off_building.get("building_id") if drop_off_building.has_method("get") and drop_off_building.get("building_id") != null else -1

		GameManager.add_resource(carry_resource_type, current_carry, player_id)
		EventBus.resource_collected.emit(carry_resource_type, current_carry, unit_id, player_id)
		EventBus.resource_drop_off.emit(unit_id, drop_off_id, carry_resource_type, current_carry)

	current_carry = 0
	return_completed.emit()


func reset() -> void:
	current_carry = 0
	_gather_timer = 0.0
	target_resource = null
	drop_off_building = null
	carry_resource_type = ""


func _find_resource_nodes_recursive(node: Node, results: Array[Node], resource_type: String) -> void:
	if node.has_method("harvest") and (node.has_method("get_resource_type") or node.get("resource_type") != null):
		results.append(node)
	for child: Node in node.get_children():
		_find_resource_nodes_recursive(child, results, resource_type)


func _find_buildings_recursive(node: Node, results: Array[Node]) -> void:
	if node.get("building_id") != null or node.has_method("is_drop_off"):
		results.append(node)
	for child: Node in node.get_children():
		_find_buildings_recursive(child, results)


func _spawn_harvest_particles() -> void:
	if target_resource == null:
		return
	var effect_name: String = "%s_gather" % carry_resource_type
	match carry_resource_type:
		"wood":
			effect_name = "wood_chop"
		"stone":
			effect_name = "stone_mine"
		"gold":
			effect_name = "gold_mine"
		"food":
			effect_name = "food_gather"
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var particle_manager: Node = _find_node_recursive(scene, "ParticleEffects")
	if particle_manager != null and particle_manager.has_method("spawnEffect"):
		particle_manager.spawnEffect(effect_name, target_resource.global_position, 4)


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_node_recursive(child, target_name)
		if result != null:
			return result
	return null
