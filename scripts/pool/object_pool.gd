extends Node

var pools: Dictionary = {}
var pool_configs: Dictionary = {}


func register_pool(pool_name: String, scene: PackedScene, prewarm: int = 10, max: int = 50) -> void:
	pool_configs[pool_name] = {
		"scene": scene,
		"prewarm": prewarm,
		"max_count": max,
	}
	pools[pool_name] = []
	_prewarm_pool(pool_name, prewarm)


func get_object(pool_name: String) -> Node:
	if not pools.has(pool_name):
		push_warning("ObjectPool: Pool '%s' not registered." % pool_name)
		return null

	var pool: Array = pools[pool_name]
	var config: Dictionary = pool_configs.get(pool_name, {})

	for obj: Node in pool:
		if _is_inactive(obj):
			_activate(obj)
			return obj

	var current_count: int = pool.size()
	var max_count: int = config.get("max_count", 50)
	if current_count >= max_count:
		push_warning("ObjectPool: Pool '%s' at max capacity (%d)." % [pool_name, max_count])
		return null

	var new_obj: Node = _create_object(pool_name)
	if new_obj != null:
		pool.append(new_obj)
		_activate(new_obj)
	return new_obj


func return_object(pool_name: String, obj: Node) -> void:
	if obj == null:
		return
	if not pools.has(pool_name):
		push_warning("ObjectPool: Pool '%s' not registered." % pool_name)
		obj.queue_free()
		return

	_deactivate(obj)
	if obj not in pools[pool_name]:
		pools[pool_name].append(obj)


func prewarm_all() -> void:
	for pool_name: String in pool_configs:
		var config: Dictionary = pool_configs[pool_name]
		var prewarm_count: int = config.get("prewarm", 10)
		var pool: Array = pools.get(pool_name, [])
		var existing: int = pool.size()
		var to_add: int = maxi(prewarm_count - existing, 0)
		_prewarm_pool(pool_name, to_add)


func clear_all() -> void:
	for pool_name: String in pools:
		for obj: Node in pools[pool_name]:
			if is_instance_valid(obj):
				obj.queue_free()
	pools.clear()
	pool_configs.clear()


func get_pool_size(pool_name: String) -> int:
	return pools.get(pool_name, []).size()


func get_active_count(pool_name: String) -> int:
	if not pools.has(pool_name):
		return 0
	var count: int = 0
	for obj: Node in pools[pool_name]:
		if not _is_inactive(obj):
			count += 1
	return count


func _prewarm_pool(pool_name: String, count: int) -> void:
	if not pools.has(pool_name):
		pools[pool_name] = []
	for _i in range(count):
		var obj: Node = _create_object(pool_name)
		if obj != null:
			_deactivate(obj)
			pools[pool_name].append(obj)


func _create_object(pool_name: String) -> Node:
	var config: Dictionary = pool_configs.get(pool_name, {})
	var scene: PackedScene = config.get("scene", null)
	if scene == null:
		push_warning("ObjectPool: No scene for pool '%s'." % pool_name)
		return null
	var obj: Node = scene.instantiate()
	add_child(obj)
	return obj


func _activate(obj: Node) -> void:
	if obj == null:
		return
	obj.visible = true
	if obj is Node2D:
		(obj as Node2D).process_mode = Node.PROCESS_MODE_INHERIT
	elif obj is Node:
		obj.process_mode = Node.PROCESS_MODE_INHERIT


func _deactivate(obj: Node) -> void:
	if obj == null:
		return
	obj.visible = false
	if obj is Node2D:
		(obj as Node2D).process_mode = Node.PROCESS_MODE_DISABLED
	elif obj is Node:
		obj.process_mode = Node.PROCESS_MODE_DISABLED
	_reset_object_state(obj)


func _is_inactive(obj: Node) -> bool:
	if obj == null:
		return false
	return not obj.visible and obj.process_mode == Node.PROCESS_MODE_DISABLED


func _reset_object_state(obj: Node) -> void:
	if obj is Area2D:
		(obj as Area2D).set_deferred("monitoring", false)
		(obj as Area2D).set_deferred("monitorable", false)
	if obj is CharacterBody2D:
		(obj as CharacterBody2D).velocity = Vector2.ZERO
	if obj.has_method("reset"):
		obj.reset()
	if obj.has_method("stop"):
		obj.stop()
