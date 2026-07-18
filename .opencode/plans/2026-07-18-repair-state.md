# RepairState Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a RepairState so villagers can right-click damaged buildings to walk to them and gradually restore HP, consuming resources per tick.

**Architecture:** Model after BuildState. A new `RepairState` node lives under `UnitStateMachine` in `unit.tscn`. Right-clicking a damaged owned building sets `pending_target_repair` on the villager. IdleState checks this and transitions to RepairState. The state moves the villager to the building, plays the build animation, and calls `BuildingBase.repair()` every second until the building is at full HP or the villager dies/is stopped.

**Tech Stack:** GDScript (Godot 4.4.1), existing state machine pattern, existing `BuildingBase.repair()` method.

---

## Task 1: Add `pending_target_repair` to UnitBase

**Files:**
- Modify: `scripts/units/unit_base.gd:19-20`

**Step 1:** Add a new pending variable after the existing two:

```gdscript
var pending_target_resource: Node2D = null
var pending_target_building: Node2D = null
var pending_target_repair: Node2D = null
```

**Step 2:** Verify the variable is accessible (no syntax errors).

---

## Task 2: Create `repair_state.gd`

**Files:**
- Create: `scripts/units/states/repair_state.gd`

**Step 1:** Create the file with the following content:

```gdscript
class_name RepairState
extends UnitState

var target_building: Node2D = null

var _repair_timer: float = 0.0
var _repair_interval: float = 1.0
const REPAIR_RANGE: float = 48.0


func enter() -> void:
	_repair_timer = 0.0

	if unit == null:
		state_machine.change_state("IdleState")
		return

	if unit.pending_target_repair != null:
		target_building = unit.pending_target_repair
		unit.pending_target_repair = null

	if target_building == null or not is_instance_valid(target_building):
		state_machine.change_state("IdleState")
		return

	if not _is_damaged():
		state_machine.change_state("IdleState")
		return

	_move_to_building()


func update(delta: float) -> void:
	if target_building == null or not is_instance_valid(target_building):
		state_machine.change_state("IdleState")
		return

	if not _is_damaged():
		state_machine.change_state("IdleState")
		return

	var dist: float = unit.global_position.distance_to(target_building.global_position)

	if dist > REPAIR_RANGE:
		var move_comp: Node = unit.get_node_or_null("MovementComponent")
		if move_comp != null and not move_comp.is_moving:
			_move_to_building()
		return

	var move_comp_stop: Node = unit.get_node_or_null("MovementComponent")
	if move_comp_stop != null and move_comp_stop.is_moving:
		move_comp_stop.stop()

	_play_repair_anim()

	_repair_timer += delta
	if _repair_timer >= _repair_interval:
		_repair_timer = 0.0
		_perform_repair()


func exit() -> void:
	target_building = null
	_repair_timer = 0.0


func _is_damaged() -> bool:
	if target_building == null or not is_instance_valid(target_building):
		return false
	var current_hp: int = target_building.get("current_hp") if target_building.get("current_hp") != null else 0
	var max_hp: int = target_building.get("max_hp") if target_building.get("max_hp") != null else 1
	return current_hp < max_hp


func _move_to_building() -> void:
	if target_building == null or unit == null:
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(target_building.global_position)

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		var dir: Vector2 = (target_building.global_position - unit.global_position).normalized()
		anim.play_state("walk", dir)


func _perform_repair() -> void:
	if target_building == null or not is_instance_valid(target_building):
		return

	if not _is_damaged():
		state_machine.change_state("IdleState")
		return

	if target_building.has_method("repair"):
		target_building.repair(0.5)
	else:
		var current_hp: int = target_building.get("current_hp") if target_building.get("current_hp") != null else 0
		var max_hp: int = target_building.get("max_hp") if target_building.get("max_hp") != null else 1
		if current_hp < max_hp:
			target_building.set("current_hp", mini(current_hp + 10, max_hp))

	if not _is_damaged():
		state_machine.change_state("IdleState")


func _play_repair_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("build")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
```

**Key design decisions:**
- Uses `BuildingBase.repair(0.5)` which already handles resource cost calculation (50% of base cost proportioned to HP healed).
- Reuses the "build" animation since repair is visually similar to construction.
- Checks `_is_damaged()` on enter, every update tick, and after each repair tick to exit early when building is fully healed.
- `REPAIR_RANGE` = 48.0 matches BuildState's approach.

---

## Task 3: Add RepairState to IdleState pending command check

**Files:**
- Modify: `scripts/units/states/idle_state.gd:69-78`

**Step 1:** Add the repair check after the build check in `_check_pending_commands()`:

```gdscript
func _check_pending_commands() -> void:
	if unit == null:
		return

	if unit.pending_target_resource != null:
		state_machine.change_state("HarvestState")
		return

	if unit.pending_target_building != null:
		state_machine.change_state("BuildState")
		return

	if unit.pending_target_repair != null:
		state_machine.change_state("RepairState")
		return

	if unit.pending_move_position != Vector2.ZERO:
		state_machine.change_state("MoveState")
		return
```

---

## Task 4: Add right-click-on-damaged-building detection in InputManager

**Files:**
- Modify: `scripts/core/input_manager.gd:280-325` (inside `_handle_right_click`)

**Step 1:** Add building damage detection before the resource check. The logic:
1. Find the nearest building at the click position (using `_find_damaged_building_at_position`).
2. If it's owned by the local player AND is constructed AND is damaged → set `pending_target_repair` on selected villagers and transition to RepairState.
3. If it's NOT damaged (or not owned) → fall through to existing resource/movement logic.

Replace the `_handle_right_click` method:

```gdscript
func _handle_right_click(world_pos: Vector2) -> void:
	if has_build_mode:
		cancel_build_mode()
		return

	if selected_unit_ids.size() > 0:
		var target_building: Node2D = _find_damaged_building_at_position(world_pos)

		if target_building != null:
			var units: Array[Node2D] = []
			for unit_id in selected_unit_ids:
				var unit: Node2D = _find_unit_by_id(unit_id)
				if unit:
					units.append(unit)

			for unit: Node2D in units:
				unit.set("pending_target_repair", target_building)
				var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
				if state_machine != null and state_machine.has_method("change_state"):
					state_machine.change_state("RepairState")
			EventBus.move_order_feedback.emit(target_building.global_position)
			AudioManager.play_ui_click()
			return

		var target_resource: Node2D = _find_resource_at_position(world_pos)
		
		var formation_manager: Node = get_node_or_null("/root/GameWorld/FormationManager")
		var units: Array[Node2D] = []
		for unit_id in selected_unit_ids:
			var unit: Node2D = _find_unit_by_id(unit_id)
			if unit:
				units.append(unit)
		
		if target_resource != null:
			for unit: Node2D in units:
				unit.set("pending_target_resource", target_resource)
				var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
				if state_machine != null and state_machine.has_method("change_state"):
					state_machine.change_state("HarvestState")
			EventBus.move_order_feedback.emit(target_resource.global_position)
		elif units.size() > 0:
			if formation_manager and formation_manager.has_method("apply_formation_to_units"):
				var center_pos: Vector2 = Vector2.ZERO
				for u in units:
					center_pos += u.global_position
				center_pos /= units.size()
				
				formation_manager.apply_formation_to_units(units, world_pos, center_pos)
			else:
				var formation_targets: Dictionary = _build_formation_targets(world_pos, units.size())
				for i in range(units.size()):
					var move_target: Vector2 = formation_targets.get(i, world_pos)
					var unit: Node2D = units[i]
					unit.set("pending_move_position", move_target)
					var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
					if state_machine != null and state_machine.has_method("change_state"):
						state_machine.change_state("MoveState")
					EventBus.unit_moved.emit(selected_unit_ids[i], move_target)
			EventBus.move_order_feedback.emit(world_pos)
		AudioManager.play_ui_click()
```

**Step 2:** Add the new helper method after `_find_resource_at_position`:

```gdscript
func _find_damaged_building_at_position(world_pos: Vector2) -> Node2D:
	var click_radius: float = 56.0
	var best: Node2D = null
	var best_dist_sq: float = click_radius * click_radius
	var player_id: int = GameManager.get_local_player_id()

	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null or not bm.has_method("get"):
		return null

	var buildings_dict: Dictionary = bm.get("buildings") if bm.get("buildings") != null else {}
	for id_variant: Variant in buildings_dict:
		var node: Node2D = buildings_dict[id_variant]
		if not is_instance_valid(node):
			continue
		var bld_player: int = node.get("player_id") if node.get("player_id") != null else -1
		if bld_player != player_id:
			continue
		var building_is_constructed: bool = node.get("is_constructed") if node.get("is_constructed") != null else false
		if not building_is_constructed:
			continue
		var current_hp: int = node.get("current_hp") if node.get("current_hp") != null else 0
		var max_hp: int = node.get("max_hp") if node.get("max_hp") != null else 1
		if current_hp >= max_hp:
			continue
		var dist_sq: float = node.global_position.distance_squared_to(world_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = node

	return best
```

---

## Task 5: Add RepairState node to unit.tscn

**Files:**
- Modify: `scenes/units/unit.tscn`

**Step 1:** Add the RepairState ext_resource and node. After the existing `AttackMoveState` entry (id="15"), add:

In the `[ext_resource]` section, add:
```
[ext_resource type="Script" path="res://scripts/units/states/repair_state.gd" id="16"]
```

In the node tree, after the `AttackMoveState` node, add:
```
[node name="RepairState" type="Node" parent="UnitStateMachine"]
script = ExtResource("16")
```

---

## Task 6: Clear pending_target_repair in GameWorld stop command

**Files:**
- Modify: `scenes/main/game_world.gd:592-594`

**Step 1:** Add the repair target clear alongside the existing clears:

```gdscript
unit.set("pending_move_position", Vector2.ZERO)
unit.set("pending_target_resource", null)
unit.set("pending_target_building", null)
unit.set("pending_target_repair", null)
```

---

## Summary of Changes

| File | Action | Description |
|------|--------|-------------|
| `scripts/units/unit_base.gd` | Modify | Add `pending_target_repair` variable |
| `scripts/units/states/repair_state.gd` | Create | New RepairState with move, repair, anim, cleanup |
| `scripts/units/states/idle_state.gd` | Modify | Add pending_target_repair check in _check_pending_commands |
| `scripts/core/input_manager.gd` | Modify | Add right-click damaged building detection + helper |
| `scenes/units/unit.tscn` | Modify | Add RepairState node to scene tree |
| `scenes/main/game_world.gd` | Modify | Clear pending_target_repair on stop |

## Testing

1. **Manual in-editor:** Place a building, damage it (console or combat), select a villager, right-click the building → villager walks to it and repairs. Stop command (S key) cancels repair. Building HP reaches max → villager idles.
2. **Resource cost:** Verify resources are spent on each repair tick (BuildingBase.repair handles this).
3. **Death during repair:** Kill the villager → state machine transitions to DeadState, exit() cleans up.
4. **Building destroyed during repair:** Building freed → is_instance_valid fails → state machine transitions to IdleState.
5. **Full HP building:** Right-click a full-HP building → _is_damaged() returns false → villager idles immediately.
