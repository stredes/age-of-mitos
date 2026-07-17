## Global signal bus for decoupled communication between systems.
##
## EventBus provides a centralized location for all game-wide signals.
## Systems connect to these signals instead of referencing each other directly,
## following the observer pattern to maintain loose coupling.
## Usage: EventBus.unit_selected.emit(unit_data)
##        EventBus.resource_changed.connect(callback)
extends Node

# =============================================================================
# Resource Signals
# =============================================================================

## Emitted when a player's resource count changes.
## [param resource_type: String] The type of resource (wood, stone, food, gold).
## [param amount: int] The new total amount.
## [param player_id: int] The player whose resource changed.
signal resource_changed(resource_type: String, amount: int, player_id: int)

## Emitted when multiple resources change at once (e.g., after a trade or cost payment).
## [param resources: Dictionary] Map of resource_type -> new amount.
## [param player_id: int] The player whose resources changed.
signal resources_changed(resources: Dictionary, player_id: int)

## Emitted when a player's population changes.
## [param current: int] Current population.
## [param max_pop: int] Maximum population capacity.
## [param player_id: int] The player whose population changed.
signal population_changed(current: int, max_pop: int, player_id: int)

## Emitted when the count of idle villagers changes.
## [param count: int] Number of idle villagers.
## [param player_id: int] The player whose idle villagers changed.
signal idle_villagers_changed(count: int, player_id: int)

## Emitted when resources are gathered/collected by a unit.
## [param resource_type: String] The type collected.
## [param amount: int] How much was collected.
## [param collector_id: int] The unit that collected it.
## [param player_id: int] The owning player.
signal resource_collected(resource_type: String, amount: int, collector_id: int, player_id: int)

## Emitted when a resource node on the map is fully depleted.
## [param resource_id: int] The world ID of the resource node.
## [param resource_type: String] The type that ran out.
signal resource_depleted(resource_id: int, resource_type: String)

# =============================================================================
# Unit Signals
# =============================================================================

## Emitted when a unit is added to the current selection.
## [param unit_id: int] The unique ID of the selected unit.
## [param player_id: int] The owning player.
signal unit_selected(unit_id: int, player_id: int)

## Emitted when a unit is removed from the current selection.
## [param unit_id: int] The unique ID of the deselected unit.
## [param player_id: int] The owning player.
signal unit_deselected(unit_id: int, player_id: int)

## Emitted when a unit begins or completes movement.
## [param unit_id: int] The unit that moved.
## [param target_position: Vector2] The destination in world coordinates.
signal unit_moved(unit_id: int, target_position: Vector2)

## Emitted when a unit initiates an attack.
## [param attacker_id: int] The attacking unit.
## [param target_id: int] The target being attacked.
## [param damage: int] The damage dealt.
signal unit_attacked(attacker_id: int, target_id: int, damage: int)

## Emitted when a unit's health reaches zero or it is removed.
## [param unit_id: int] The unit that died.
## [param killer_id: int] The unit or entity that dealt the killing blow (-1 if environmental).
## [param player_id: int] The owning player of the killed unit.
signal unit_died(unit_id: int, killer_id: int, player_id: int)

## Emitted when a new unit is created/spawned.
## [param unit_id: int] The unique ID of the new unit.
## [param unit_type: String] The type of unit spawned.
## [param player_id: int] The owning player.
## [param position: Vector2] Spawn position in world coordinates.
signal unit_spawned(unit_id: int, unit_type: String, player_id: int, position: Vector2)

## Emitted when a unit finishes training at a building.
## [param unit_type: String] The type of unit trained.
## [param building_id: int] The building that produced it.
## [param player_id: int] The owning player.
signal unit_trained(unit_type: String, building_id: int, player_id: int)

# =============================================================================
# Building Signals
# =============================================================================

## Emitted when a building placement is confirmed by the player.
## [param building_id: int] The unique ID of the new building.
## [param building_type: String] The type of building placed.
## [param player_id: int] The owning player.
## [param position: Vector2] World position of the placement.
signal building_placed(building_id: int, building_type: String, player_id: int, position: Vector2)

## Emitted when a building finishes construction.
## [param building_id: int] The completed building.
## [param player_id: int] The owning player.
signal building_completed(building_id: int, player_id: int)

## Emitted when a Town Center is built.
## [param player_id: int] The owning player.
signal town_center_built(player_id: int)

## Emitted when a Town Center is destroyed.
## [param player_id: int] The owning player.
signal town_center_destroyed(player_id: int)

## Emitted when a building is destroyed.
## [param building_id: int] The destroyed building.
## [param player_id: int] The owning player.
## [param destroyer_id: int] The player who destroyed it (-1 if environmental).
signal building_destroyed(building_id: int, player_id: int, destroyer_id: int)

## Emitted when a building is selected by the player.
## [param building_id: int] The selected building.
## [param player_id: int] The selecting player.
signal building_selected(building_id: int, player_id: int)

## Emitted when a building takes damage.
## [param building_id: int] The damaged building.
## [param damage: int] Amount of damage received.
## [param attacker_id: int] The unit that dealt damage (-1 if environmental).
signal building_damaged(building_id: int, damage: int, attacker_id: int)

# =============================================================================
# Selection Signals
# =============================================================================

## Emitted when the player begins a box/rubber-band selection.
## [param start_position: Vector2] World position where the drag began.
signal selection_started(start_position: Vector2)

## Emitted when the player releases the selection box.
## [param start_position: Vector2] World position where the drag began.
## [param end_position: Vector2] World position where the drag ended.
## [param selected_ids: Array] Array of selected unit/building IDs.
signal selection_ended(start_position: Vector2, end_position: Vector2, selected_ids: Array)

## Emitted when the overall selection set changes.
## [param selected_unit_ids: Array] All currently selected unit IDs.
## [param selected_building_ids: Array] All currently selected building IDs.
signal selection_changed(selected_unit_ids: Array, selected_building_ids: Array)

# =============================================================================
# Camera Signals
# =============================================================================

## Emitted when the camera moves to a new position.
## [param new_position: Vector2] The camera's new world position.
signal camera_moved(new_position: Vector2)

## Emitted when the camera zoom level changes.
## [param new_zoom: float] The new zoom factor (1.0 = default).
signal camera_zoomed(new_zoom: float)

# =============================================================================
# Game Signals
# =============================================================================

## Emitted when the game session begins.
## [param player_id: int] The local player's ID.
signal game_started(player_id: int)

## Emitted when the game is paused or unpaused.
## [param is_paused: bool] Whether the game is now paused.
signal game_paused(is_paused: bool)

## Emitted when the game speed is changed.
## [param speed: float] The new game speed multiplier.
signal game_speed_changed(speed: float)

## Emitted when the game state is saved.
## [param save_name: String] The name of the save file.
signal game_saved(save_name: String)

## Emitted when a game state is loaded.
## [param save_name: String] The name of the loaded save file.
signal game_loaded(save_name: String)

# =============================================================================
# Combat Signals
# =============================================================================

## Emitted when damage is applied to any entity (unit or building).
## [param target_id: int] The entity receiving damage.
## [param attacker_id: int] The entity dealing damage.
## [param damage: int] The raw damage amount.
## [param is_critical: bool] Whether this was a critical hit.
signal damage_dealt(target_id: int, attacker_id: int, damage: int, is_critical: bool)

## Emitted when a unit is killed by another unit in combat.
## [param victim_id: int] The unit that was killed.
## [param killer_id: int] The unit that scored the kill.
## [param victim_player_id: int] The owning player of the victim.
signal unit_killed(victim_id: int, killer_id: int, victim_player_id: int)

## Emitted when a projectile is fired.
## [param projectile_id: int] Unique ID of the projectile.
## [param attacker_id: int] The unit firing.
## [param target_id: int] The target being fired at.
## [param origin: Vector2] World position the projectile was fired from.
## [param damage: int] Damage the projectile will deal on impact.
signal projectile_fired(projectile_id: int, attacker_id: int, target_id: int, origin: Vector2, damage: int)

# =============================================================================
# Economy Signals
# =============================================================================

## Emitted when a villager is assigned to a resource or task.
## [param villager_id: int] The villager being assigned.
## [param target_id: int] The resource or drop-off point ID.
## [param task: String] The task type (gather, build, repair, etc.).
signal villager_assigned(villager_id: int, target_id: int, task: String)

## Emitted when a villager is unassigned from a task.
## [param villager_id: int] The villager being freed.
## [param previous_target_id: int] What they were previously assigned to.
signal villager_unassigned(villager_id: int, previous_target_id: int)

## Emitted when a villager drops off resources at a drop-off point.
## [param villager_id: int] The villager dropping off.
## [param drop_off_id: int] The building receiving resources.
## [param resource_type: String] The resource being dropped off.
## [param amount: int] The amount dropped off.
signal resource_drop_off(villager_id: int, drop_off_id: int, resource_type: String, amount: int)

# =============================================================================
# Construction Signals
# =============================================================================

## Emitted when construction of a building begins.
## [param building_id: int] The building being constructed.
## [param player_id: int] The owning player.
## [param total_hp: int] The total construction HP needed.
signal construction_started(building_id: int, player_id: int, total_hp: int)

## Emitted periodically as construction progresses.
## [param building_id: int] The building under construction.
## [param current_hp: int] Current construction progress.
## [param total_hp: int] Total HP needed to complete.
signal construction_progress(building_id: int, current_hp: int, total_hp: int)

## Emitted when construction is fully complete.
## [param building_id: int] The building that finished.
## [param player_id: int] The owning player.
signal construction_completed(building_id: int, player_id: int)

# =============================================================================
# Technology Signals
# =============================================================================

## Emitted when a player starts researching a technology.
## [param tech_id: String] The technology being researched.
## [param player_id: int] The researching player.
## [param research_time: float] Total time to complete.
signal tech_started(tech_id: String, player_id: int, research_time: float)

## Emitted when a technology research completes.
## [param tech_id: String] The completed technology.
## [param player_id: int] The owning player.
signal tech_completed(tech_id: String, player_id: int)

## Emitted when a technology effect is applied to the player.
## [param tech_id: String] The technology whose effects are applied.
## [param player_id: int] The player receiving the effects.
signal tech_researched(tech_id: String, player_id: int)

# =============================================================================
# UI Signals
# =============================================================================

## Emitted when a UI menu or panel is opened.
## [param menu_name: String] The identifier of the opened menu.
signal menu_opened(menu_name: String)

## Emitted when a UI menu or panel is closed.
## [param menu_name: String] The identifier of the closed menu.
signal menu_closed(menu_name: String)

## Emitted when a UI button is pressed.
## [param button_name: String] The identifier of the pressed button.
## [param player_id: int] The player who pressed it.
signal button_pressed(button_name: String, player_id: int)

# =============================================================================
# AI Signals
# =============================================================================

## Emitted when the AI plans an attack.
## [param ai_player_id: int] The AI player planning the attack.
## [param target_player_id: int] The target player.
## [param army_strength: int] Approximate strength of the attack force.
## [param target_position: Vector2] The position being attacked.
signal ai_attack_planned(ai_player_id: int, target_player_id: int, army_strength: int, target_position: Vector2)

## Emitted when the AI plans to expand to a new location.
## [param ai_player_id: int] The AI player expanding.
## [param position: Vector2] The target expansion location.
## [param building_type: String] The type of building to construct.
signal ai_expansion_planned(ai_player_id: int, position: Vector2, building_type: String)

# =============================================================================
# Fog of War Signals
# =============================================================================

## Emitted when the fog of war state is updated for a player.
## [param player_id: int] The player whose fog was updated.
## [param grid_position: Vector2] The grid cell that changed.
## [param visibility: int] Visibility level (0 = hidden, 1 = explored, 2 = visible).
signal fog_updated(player_id: int, grid_position: Vector2, visibility: int)

## Emitted when a previously hidden area is revealed.
## [param player_id: int] The player who revealed it.
## [param center: Vector2] The center of the revealed area.
## [param radius: float] The radius of revealed tiles.
signal area_revealed(player_id: int, center: Vector2, radius: float)

# =============================================================================
# Helper Methods for Deferred Emission
# =============================================================================

## Emit a signal on the next idle frame to avoid issues with
## signals fired during physics or process callbacks.
## [param signal_name: StringName] The signal to emit.
## [param args: Array] Arguments to pass to the signal.
func emit_deferred(signal_name: StringName, args: Array = []) -> void:
	if not has_signal(signal_name):
		push_warning("EventBus: Attempted to emit unknown signal '%s'." % signal_name)
		return
	match args.size():
		0: call_deferred("emit_signal", signal_name)
		1: call_deferred("emit_signal", signal_name, args[0])
		2: call_deferred("emit_signal", signal_name, args[0], args[1])
		3: call_deferred("emit_signal", signal_name, args[0], args[1], args[2])
		4: call_deferred("emit_signal", signal_name, args[0], args[1], args[2], args[3])
		5: call_deferred("emit_signal", signal_name, args[0], args[1], args[2], args[3], args[4])
		_:
			pass


## Safely connect to a signal, preventing duplicate connections.
## [param signal_name: StringName] The signal to connect to.
## [param callable: Callable] The callback function.
## [param flags: int] Optional connection flags.
func safe_connect(signal_name: StringName, callable: Callable, flags: int = 0) -> void:
	if not has_signal(signal_name):
		push_warning("EventBus: Cannot connect to unknown signal '%s'." % signal_name)
		return
	if not is_connected(signal_name, callable):
		connect(signal_name, callable, flags)


## Safely disconnect a previously connected signal.
## [param signal_name: StringName] The signal to disconnect.
## [param callable: Callable] The callback to remove.
func safe_disconnect(signal_name: StringName, callable: Callable) -> void:
	if is_connected(signal_name, callable):
		disconnect(signal_name, callable)
