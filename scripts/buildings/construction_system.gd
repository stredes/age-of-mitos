## Handles construction logic for buildings. Tracks which villagers are assigned
## to each building under construction and advances their progress over time.
class_name ConstructionSystem
extends Node

# =============================================================================
# Signals
# =============================================================================

signal construction_complete(building_id: int)

# =============================================================================
# Constants
# =============================================================================

const WORK_PER_VILLAGER_PER_SECOND: int = 5

# Diminishing returns per additional builder: [1st, 2nd, 3rd, 4th, 5th+]
const BUILDER_EFFICIENCY: Array[float] = [1.0, 0.8, 0.65, 0.55, 0.5]

# =============================================================================
# Properties
# =============================================================================

var active_constructions: Dictionary = {}

var _building_manager: Node = null

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_building_manager = _find_building_manager()
	_connect_event_bus()


func _process(delta: float) -> void:
	var ids: Array = active_constructions.keys()
	for building_id: int in ids:
		if not active_constructions.has(building_id):
			continue
		update_construction(building_id, delta)

# =============================================================================
# Setup
# =============================================================================

func _find_building_manager() -> Node:
	var node: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if node:
		return node
	return get_node_or_null("/root/GameWorld/World/BuildingManager")


func _connect_event_bus() -> void:
	if not EventBus.villager_assigned.is_connected(_on_villager_assigned):
		EventBus.villager_assigned.connect(_on_villager_assigned)
	if not EventBus.villager_unassigned.is_connected(_on_villager_unassigned):
		EventBus.villager_unassigned.connect(_on_villager_unassigned)

# =============================================================================
# Builder Assignment
# =============================================================================

func assign_builder(building_id: int, villager_id: int) -> void:
	if not active_constructions.has(building_id):
		var building: Node2D = _get_building(building_id)
		if building == null:
			return
		if building.has_method("get") and building.get("is_constructed") == true:
			return

		var total: int = 100
		if building.has_method("get") and building.get("construction_total") != null:
			total = building.get("construction_total")

		active_constructions[building_id] = {
			"builder_ids": [],
			"progress": 0,
			"total": total,
		}

		if building.has_method("start_construction"):
			building.start_construction()

	var entry: Dictionary = active_constructions[building_id]
	var builders: Array = entry["builder_ids"]
	if villager_id not in builders:
		builders.append(villager_id)
		entry["builder_ids"] = builders


func unassign_builder(building_id: int, villager_id: int) -> void:
	if not active_constructions.has(building_id):
		return

	var entry: Dictionary = active_constructions[building_id]
	var builders: Array = entry["builder_ids"]
	builders.erase(villager_id)
	entry["builder_ids"] = builders

	if builders.is_empty():
		# Pause construction but don't remove it — villagers can resume.
		pass

# =============================================================================
# Construction Update
# =============================================================================

func update_construction(building_id: int, delta: float) -> void:
	if not active_constructions.has(building_id):
		return

	var entry: Dictionary = active_constructions[building_id]
	var builders: Array = entry["builder_ids"]
	var builder_count: int = builders.size()

	if builder_count == 0:
		return

	var building: Node2D = _get_building(building_id)
	if building == null:
		active_constructions.erase(building_id)
		return

	if building.has_method("get") and building.get("is_constructed") == true:
		active_constructions.erase(building_id)
		return

	# Clean up invalid builders.
	var valid_builders: Array = []
	for vid: int in builders:
		if _is_valid_villager(vid):
			valid_builders.append(vid)
	entry["builder_ids"] = valid_builders
	builder_count = valid_builders.size()

	if builder_count == 0:
		return

	# Apply diminishing returns for multiple builders.
	var efficiency_index: int = clampi(builder_count - 1, 0, BUILDER_EFFICIENCY.size() - 1)
	var efficiency: float = BUILDER_EFFICIENCY[efficiency_index]
	var work_per_second: int = WORK_PER_VILLAGER_PER_SECOND * builder_count
	var actual_work: int = maxi(ceili(float(work_per_second) * efficiency), 1)

	var total_work: int = entry["total"]

	if building.has_method("advance_construction"):
		building.advance_construction(actual_work)

	var current_hp: int = 0
	if building.has_method("get"):
		current_hp = building.get("current_hp") if building.get("current_hp") != null else 0

	entry["progress"] = current_hp

	EventBus.construction_progress.emit(building_id, current_hp, total_work)

	if current_hp >= total_work:
		_complete_construction(building_id)

# =============================================================================
# Completion
# =============================================================================

func _complete_construction(building_id: int) -> void:
	if not active_constructions.has(building_id):
		return

	var entry: Dictionary = active_constructions[building_id]
	var builders: Array = entry["builder_ids"]

	var building: Node2D = _get_building(building_id)
	if building and building.has_method("complete_construction"):
		building.complete_construction()

	for vid: int in builders:
		EventBus.villager_unassigned.emit(vid, building_id)

	active_constructions.erase(building_id)
	construction_complete.emit(building_id)

# =============================================================================
# Progress Query
# =============================================================================

func get_construction_progress(building_id: int) -> float:
	if not active_constructions.has(building_id):
		return 0.0
	var entry: Dictionary = active_constructions[building_id]
	var total: int = entry["total"]
	if total <= 0:
		return 0.0
	return clampf(float(entry["progress"]) / float(total), 0.0, 1.0)

# =============================================================================
# Manual Completion (for debugging / cheats)
# =============================================================================

func complete_construction(building_id: int) -> void:
	_complete_construction(building_id)

# =============================================================================
# Helpers
# =============================================================================

func _get_building(building_id: int) -> Node2D:
	if _building_manager and _building_manager.has_method("get_building"):
		return _building_manager.get_building(building_id)
	return null


func _is_valid_villager(villager_id: int) -> bool:
	var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
	for v: Node in villagers:
		if v.has_method("get") and v.get("unit_id") != null and v.get("unit_id") == villager_id:
			if v.has_method("get") and v.get("is_dead") != true:
				return true
	return false

# =============================================================================
# Event Bus Handlers
# =============================================================================

func _on_villager_assigned(villager_id: int, target_id: int, task: String) -> void:
	if task == "build":
		assign_builder(target_id, villager_id)


func _on_villager_unassigned(villager_id: int, previous_target_id: int) -> void:
	unassign_builder(previous_target_id, villager_id)

# =============================================================================
# Query
# =============================================================================

func is_under_construction(building_id: int) -> bool:
	return active_constructions.has(building_id)


func get_builder_count(building_id: int) -> int:
	if not active_constructions.has(building_id):
		return 0
	return active_constructions[building_id]["builder_ids"].size()


func get_active_building_ids() -> Array:
	return active_constructions.keys()
