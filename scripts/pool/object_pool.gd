## Object pool with dynamic sizing, growth/shrink tracking, and hot-reload support.
##
## Pools automatically grow when demand increases and shrink when idle to
## reclaim memory. Tracks hit/miss rates for profiling.
class_name ObjectPool
extends Node

# =============================================================================
# Signals
# =============================================================================

signal pool_grew(pool_name: String, new_size: int)
signal pool_shrunk(pool_name: String, new_size: int)
signal pool_exhausted(pool_name: String)

# =============================================================================
# Configuration
# =============================================================================

## Default maximum objects per pool if not specified.
@export var default_max: int = 100

## Default prewarm count if not specified.
@export var default_prewarm: int = 10

## Idle frames before a pool considers shrinking (60 frames = ~1 second at 60fps).
@export var idle_threshold_frames: int = 300

## Percentage of excess idle objects to remove per shrink pass (0.0-1.0).
@export var shrink_ratio: float = 0.25

## Growth factor when pool is exhausted (multiply current max by this).
@export var growth_factor: float = 1.5

# =============================================================================
# Internal State
# =============================================================================

## Pool data: pool_name → { scene, pool: [], max_count, prewarm, idle_frames, hit_count, miss_count }
var _pools: Dictionary = {}

# =============================================================================
# Lifecycle
# =============================================================================

func _process(_delta: float) -> void:
	_update_idle_counters()


# =============================================================================
# Public API
# =============================================================================

## Register a new pool. If the pool already exists, it is cleared first.
func register_pool(pool_name: String, scene: PackedScene, prewarm: int = -1, max: int = -1) -> void:
	if _pools.has(pool_name):
		_clear_pool(pool_name)

	var pw: int = prewarm if prewarm >= 0 else default_prewarm
	var mx: int = max if max >= 0 else default_max

	_pools[pool_name] = {
		"scene": scene,
		"pool": [],
		"max_count": mx,
		"original_max": mx,
		"prewarm": pw,
		"idle_frames": 0,
		"hit_count": 0,
		"miss_count": 0,
	}
	_prewarm(pool_name, pw)


## Get an object from the pool. Returns null if pool is at capacity.
func get_object(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		push_warning("ObjectPool: Pool '%s' not registered." % pool_name)
		return null

	var data: Dictionary = _pools[pool_name]
	var pool: Array = data["pool"]

	# Reset idle counter — pool is active.
	data["idle_frames"] = 0

	# Try to find an inactive object.
	for obj: Node in pool:
		if _is_inactive(obj):
			data["hit_count"] += 1
			_activate(obj)
			return obj

	# No inactive object found — try to grow.
	data["miss_count"] += 1
	var current_count: int = pool.size()
	var max_count: int = data["max_count"]

	if current_count >= max_count:
		# Try dynamic growth.
		var new_max: int = _grow_pool(pool_name)
		if current_count >= new_max:
			pool_exhausted.emit(pool_name)
			return null

	var new_obj: Node = _create_object(pool_name)
	if new_obj != null:
		pool.append(new_obj)
		_activate(new_obj)
	return new_obj


## Return an object to the pool.
func return_object(pool_name: String, obj: Node) -> void:
	if obj == null:
		return
	if not _pools.has(pool_name):
		push_warning("ObjectPool: Pool '%s' not registered." % pool_name)
		obj.queue_free()
		return

	var pool: Array = _pools[pool_name]["pool"]
	_deactivate(obj)
	if obj not in pool:
		pool.append(obj)


## Prewarm all registered pools to their configured prewarm counts.
func prewarm_all() -> void:
	for pool_name: String in _pools:
		var data: Dictionary = _pools[pool_name]
		var pool: Array = data["pool"]
		var existing: int = pool.size()
		var to_add: int = maxi(data["prewarm"] - existing, 0)
		if to_add > 0:
			_prewarm(pool_name, to_add)


## Clear all pools and free all objects.
func clear_all() -> void:
	for pool_name: String in _pools.keys():
		_clear_pool(pool_name)
	_pools.clear()


## Get the total object count (active + inactive) for a pool.
func get_pool_size(pool_name: String) -> int:
	if not _pools.has(pool_name):
		return 0
	return _pools[pool_name]["pool"].size()


## Get the count of active (in-use) objects for a pool.
func get_active_count(pool_name: String) -> int:
	if not _pools.has(pool_name):
		return 0
	var count: int = 0
	for obj: Node in _pools[pool_name]["pool"]:
		if not _is_inactive(obj):
			count += 1
	return count


## Get hit/miss statistics for a pool.
func get_stats(pool_name: String) -> Dictionary:
	if not _pools.has(pool_name):
		return {}
	var data: Dictionary = _pools[pool_name]
	var total: int = data["hit_count"] + data["miss_count"]
	return {
		"pool_size": data["pool"].size(),
		"active": get_active_count(pool_name),
		"hit_count": data["hit_count"],
		"miss_count": data["miss_count"],
		"hit_rate": float(data["hit_count"]) / float(total) if total > 0 else 0.0,
		"max_count": data["max_count"],
		"idle_frames": data["idle_frames"],
	}


## Get stats for all pools.
func get_all_stats() -> Dictionary:
	var result: Dictionary = {}
	for pool_name: String in _pools:
		result[pool_name] = get_stats(pool_name)
	return result


## Manually trigger a shrink check on all pools.
func shrink_all() -> void:
	for pool_name: String in _pools:
		_try_shrink(pool_name)


## Reset pool max to original configured value.
func reset_max(pool_name: String) -> void:
	if _pools.has(pool_name):
		_pools[pool_name]["max_count"] = _pools[pool_name]["original_max"]

# =============================================================================
# Internal: Creation / Activation
# =============================================================================

func _prewarm(pool_name: String, count: int) -> void:
	for _i in range(count):
		var obj: Node = _create_object(pool_name)
		if obj != null:
			_deactivate(obj)
			_pools[pool_name]["pool"].append(obj)


func _create_object(pool_name: String) -> Node:
	var data: Dictionary = _pools.get(pool_name, {})
	var scene: PackedScene = data.get("scene", null)
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

# =============================================================================
# Internal: Dynamic Sizing
# =============================================================================

## Grow pool capacity when exhausted. Returns the new max.
func _grow_pool(pool_name: String) -> int:
	var data: Dictionary = _pools[pool_name]
	var old_max: int = data["max_count"]
	var new_max: int = int(float(old_max) * growth_factor)
	data["max_count"] = new_max
	pool_grew.emit(pool_name, new_max)
	return new_max


## Check if an idle pool should shrink excess objects.
func _try_shrink(pool_name: String) -> void:
	var data: Dictionary = _pools[pool_name]
	var pool: Array = data["pool"]
	var current_size: int = pool.size()
	var original_max: int = data["original_max"]

	# Only shrink if above original max and all objects inactive.
	if current_size <= original_max:
		return

	var active_count: int = 0
	for obj: Node in pool:
		if not _is_inactive(obj):
			active_count += 1

	if active_count > 0:
		return  # Some objects still in use.

	# Calculate how many to remove.
	var excess: int = current_size - original_max
	var to_remove: int = maxi(int(float(excess) * shrink_ratio), 1)
	to_remove = mini(to_remove, current_size)

	# Remove from end of pool.
	for _i in range(to_remove):
		var obj: Node = pool.pop_back()
		if is_instance_valid(obj):
			obj.queue_free()

	data["max_count"] = maxi(data["max_count"], original_max)
	pool_shrunk.emit(pool_name, pool.size())


## Increment idle counters and trigger shrink checks.
func _update_idle_counters() -> void:
	for pool_name: String in _pools:
		var data: Dictionary = _pools[pool_name]
		data["idle_frames"] += 1
		if data["idle_frames"] >= idle_threshold_frames:
			_try_shrink(pool_name)
			data["idle_frames"] = 0  # Reset after shrink attempt.

# =============================================================================
# Internal: Cleanup
# =============================================================================

func _clear_pool(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return
	var pool: Array = _pools[pool_name]["pool"]
	for obj: Node in pool:
		if is_instance_valid(obj):
			obj.queue_free()
	_pools[pool_name]["pool"] = []
