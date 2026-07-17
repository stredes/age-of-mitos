class_name HarvestComponent
extends Node

signal resource_gathered(type: String, amount: int)
signal resource_full(type: String, amount: int)
signal return_started()
signal return_completed()
signal auto_return_triggered(resource_type: String, amount: int)

@export var gather_rate: float = 1.0
@export var carry_capacity: int = 10

var current_carry: int = 0
var carry_resource_type: String = ""
var target_resource: Node2D = null
var drop_off_building: Node2D = null

var _parent_unit: Node2D = null
var _gather_timer: float = 0.0
var _returning_resources: bool = false


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


func get_carried_amount() -> int:
	return current_carry


func get_carried_resource_type() -> String:
	return carry_resource_type


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
			_trigger_auto_return()


func _trigger_auto_return() -> void:
	if current_carry > 0 and not carry_resource_type.is_empty():
		auto_return_triggered.emit(carry_resource_type, current_carry)
		# Request auto return via ResourceManager
		var player_id: int = _get_player_id()
		var unit_id: int = _get_unit_id()
		if player_id != -1 and unit_id != -1:
			var res_manager: Node = _find_resource_manager()
			if res_manager != null and res_manager.has_method("queue_auto_drop_off"):
				res_manager.queue_auto_drop_off(unit_id, player_id, carry_resource_type, current_carry)


func _find_resource_manager() -> Node:
	# Try direct path first.
	var direct: Node = get_node_or_null("/root/GameWorld/ResourceManager")
	if direct != null:
		return direct
	direct = get_node_or_null("/root/GameWorld/World/ResourceManager")
	if direct != null:
		return direct

	# Recursive search.
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return _find_node_recursive(scene, "ResourceManager")


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


func find_nearest_drop_off(resource_type: String = "") -> Node2D:
	if _parent_unit == null:
		return null

	var player_id: int = _get_player_id()
	var best: Node2D = null
	var best_dist: float = INF
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	# Get valid drop-off building types for this resource
	var drop_off_types: Array[String] = []
	if resource_type.is_empty():
		drop_off_types = ["town_center", "lumber_camp", "mine", "mill"]
	else:
		match resource_type:
			"wood":
				drop_off_types = ["lumber_camp", "town_center"]
			"stone", "gold":
				drop_off_types = ["mine", "town_center"]
			"food":
				drop_off_types = ["mill", "town_center"]
			_:
				drop_off_types = ["town_center"]

	var candidates: Array[Node] = []
	_find_drop_off_buildings_recursive(scene, candidates, drop_off_types, player_id)

	for node: Node in candidates:
		if node is Node2D:
			var bld: Node2D = node as Node2D
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
	_returning_resources = false


func return_resources() -> void:
	_returning_resources = true
	if drop_off_building == null or not is_instance_valid(drop_off_building):
		drop_off_building = find_nearest_drop_off(carry_resource_type)
		if drop_off_building == null:
			_returning_resources = false
			return

	return_started.emit()

	if current_carry > 0 and not carry_resource_type.is_empty():
		var player_id: int = _get_player_id()
		var unit_id: int = _get_unit_id()
		var drop_off_id: int = _get_building_id(drop_off_building)

		GameManager.add_resource(carry_resource_type, current_carry, player_id)
		EventBus.resource_collected.emit(carry_resource_type, current_carry, unit_id, player_id)
		EventBus.resource_drop_off.emit(unit_id, drop_off_id, carry_resource_type, current_carry)

	current_carry = 0
	_returning_resources = false
	return_completed.emit()


func move_to_drop_off(target_building: Node2D) -> void:
	drop_off_building = target_building
	if _parent_unit != null and _parent_unit.has_method("move_to"):
		_parent_unit.move_to(target_building.global_position)


func reset() -> void:
	current_carry = 0
	_gather_timer = 0.0
	target_resource = null
	drop_off_building = null
	carry_resource_type = ""
	_returning_resources = false


func is_returning() -> bool:
	return _returning_resources


func _get_player_id() -> int:
	if _parent_unit == null:
		return -1
	return _parent_unit.get("player_id") if _parent_unit.has_method("get") and _parent_unit.get("player_id") != null else -1


func _get_unit_id() -> int:
	if _parent_unit == null:
		return -1
	return _parent_unit.get("unit_id") if _parent_unit.has_method("get") and _parent_unit.get("unit_id") != null else -1


func _get_building_id(building: Node2D) -> int:
	if building == null:
		return -1
	return building.get("building_id") if building.has_method("get") and building.get("building_id") != null else -1


func _find_resource_nodes_recursive(node: Node, results: Array[Node], resource_type: String) -> void:
	if node.has_method("harvest") and (node.has_method("get_resource_type") or node.get("resource_type") != null):
		results.append(node)
	for child: Node in node.get_children():
		_find_resource_nodes_recursive(child, results, resource_type)


func _find_drop_off_buildings_recursive(node: Node, results: Array[Node], building_types: Array[String], player_id: int) -> void:
	var node_building_type: String = ""
	if node.has_method("get_building_type"):
		node_building_type = node.get_building_type()
	elif node.get("building_type") != null:
		node_building_type = node.get("building_type")

	if node_building_type in building_types:
		var bld_player: int = node.get("player_id") if node.has_method("get") and node.get("player_id") != null else -2
		if bld_player == player_id or player_id == -1:
			results.append(node)

	for child: Node in node.get_children():
		_find_drop_off_buildings_recursive(child, results, building_types, player_id)


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