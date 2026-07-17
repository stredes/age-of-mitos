## Main game world orchestrator. Creates, initializes, and coordinates all
## gameplay systems. Attach to the root Node2D of the game scene.
##
## Manages the lifecycle of world generation, managers, AI, fog of war,
## chunk loading, and the per-frame update loop. Spawns starting entities
## for each player and wires up EventBus connections.
extends Node2D

const WeatherSystemScript = preload("res://scripts/world/weather_system.gd")

# =============================================================================
# Signals
# =============================================================================

signal world_initialized()
signal world_cleanup_complete()

# =============================================================================
# Configuration
# =============================================================================

## Number of human + AI players.
@export var num_players: int = 2

## Number of AI-controlled players.
@export var num_ai: int = 1

## Map size in grid cells for the world generator.
@export var map_size: Vector2i = Vector2i(120, 120)

## Seed for procedural generation. 0 = random.
@export var world_seed: int = 0

## Starting villagers per player.
@export var starting_villagers: int = 3

## Auto-save interval override. -1 = use SaveManager default.
@export var auto_save_interval: float = -1.0

# =============================================================================
# Node References (created in _ready)
# =============================================================================

var world_generator: WorldGenerator = null
var grid_manager: GridManager = null
var pathfinder: Pathfinder = null
var fog_of_war: FogOfWar = null
var chunk_loader: ChunkLoader = null
var camera_controller: CameraController = null
var input_manager: InputManager = null
var unit_manager: UnitManager = null
var building_manager: BuildingManager = null
var resource_manager: ResourceManager = null
var selection_manager: SelectionManager = null
var command_manager: CommandManager = null
var combat_manager: Node = null
var technology_tree: Node = null
var save_manager: Node = null
var particle_effects: ParticleEffectsManager = null
var decorative_world: DecorativeWorldAnimations = null
var weather_system: Node = null
var ai_directors: Dictionary = {}

# =============================================================================
# Internal State
# =============================================================================

var _world_data: WorldData = null
var _initialized: bool = false
var _fog_update_timer: float = 0.0
var _fog_update_interval: float = 0.2
var _chunk_update_timer: float = 0.0
var _chunk_update_interval: float = 0.1

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_create_system_nodes()
	_connect_event_bus()
	_initialize_world()


func _process(delta: float) -> void:
	if not _initialized:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_update_fog_of_war(delta)
	_update_chunk_loader(delta)
	_flush_resource_buffers(delta)

# =============================================================================
# System Node Creation
# =============================================================================

func _create_system_nodes() -> void:
	# Camera (must be a Camera2D to function).
	camera_controller = CameraController.new()
	camera_controller.name = "Camera2D"
	add_child(camera_controller)

	# Grid and pathfinding.
	grid_manager = GridManager.new()
	grid_manager.name = "GridManager"
	add_child(grid_manager)

	pathfinder = Pathfinder.new()
	pathfinder.name = "Pathfinder"
	add_child(pathfinder)

	# World generation (temporary node — generates then detaches).
	world_generator = WorldGenerator.new()
	world_generator.name = "WorldGenerator"
	add_child(world_generator)

	# Chunk loading.
	chunk_loader = ChunkLoader.new()
	chunk_loader.name = "ChunkLoader"
	add_child(chunk_loader)

	# Fog of war.
	fog_of_war = FogOfWar.new()
	fog_of_war.name = "FogOfWar"
	add_child(fog_of_war)

	# Input.
	input_manager = InputManager.new()
	input_manager.name = "InputManager"
	add_child(input_manager)

	# Unit management.
	unit_manager = UnitManager.new()
	unit_manager.name = "UnitManager"
	add_child(unit_manager)

	# Building management.
	building_manager = BuildingManager.new()
	building_manager.name = "BuildingManager"
	add_child(building_manager)

	# Resource economy.
	resource_manager = ResourceManager.new()
	resource_manager.name = "ResourceManager"
	add_child(resource_manager)

	# Selection.
	selection_manager = SelectionManager.new()
	selection_manager.name = "SelectionManager"
	add_child(selection_manager)

	# Command system.
	command_manager = CommandManager.new()
	command_manager.name = "CommandManager"
	add_child(command_manager)

	# Combat.
	combat_manager = Node.new()
	combat_manager.name = "CombatManager"
	combat_manager.set_script(load("res://scripts/combat/combat_manager.gd"))
	add_child(combat_manager)

	# Technology tree.
	technology_tree = Node.new()
	technology_tree.name = "TechnologyTree"
	technology_tree.set_script(load("res://scripts/technology/technology_tree.gd"))
	add_child(technology_tree)

	# Save/load.
	save_manager = Node.new()
	save_manager.name = "SaveManager"
	save_manager.set_script(load("res://scripts/save/save_manager.gd"))
	add_child(save_manager)

	# Particle effects.
	particle_effects = ParticleEffectsManager.new()
	particle_effects.name = "ParticleEffects"
	add_child(particle_effects)

	# Living world ambience: clouds, animals, day/night, and subtle world motion.
	decorative_world = DecorativeWorldAnimations.new()
	decorative_world.name = "DecorativeWorldAnimations"
	add_child(decorative_world)

	weather_system = WeatherSystemScript.new()
	weather_system.name = "WeatherSystem"
	add_child(weather_system)
	weather_system.wind_changed.connect(_on_weather_wind_changed)

	# UI layer is already defined in the .tscn scene.
	var ui_layer: CanvasLayer = get_node_or_null("UILayer")
	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		ui_layer.layer = 10
		add_child(ui_layer)

# =============================================================================
# World Initialization
# =============================================================================

func _initialize_world() -> void:
	# Step 1: Generate the world.
	var seed_val: int = world_seed
	if seed_val == 0:
		seed_val = randi()
	_world_data = world_generator.generate(seed_val, map_size)

	# Step 2: Configure GridManager with world dimensions.
	grid_manager.grid_dimensions = _world_data.map_size
	grid_manager.cell_size = Vector2i(WorldGenerator.CELL_SIZE, WorldGenerator.CELL_SIZE)
	grid_manager._initialize_grid()

	# Apply terrain walkability from WorldData to GridManager.
	_apply_terrain_walkability()

	# Step 3: Initialize ChunkLoader with world data.
	chunk_loader.initialize(_world_data)

	# Step 4: Configure Pathfinder (finds GridManager via scene tree).
	# Pathfinder auto-initializes in _ready via call_deferred.

	# Step 5: Configure FogOfWar dimensions.
	var grid_pixel_size: Vector2i = Vector2i(
		_world_data.map_size.x * WorldGenerator.CELL_SIZE,
		_world_data.map_size.y * WorldGenerator.CELL_SIZE
	)
	fog_of_war.grid_size = _world_data.map_size
	fog_of_war.cell_pixel_size = Vector2i(WorldGenerator.CELL_SIZE, WorldGenerator.CELL_SIZE)
	fog_of_war._initialize_fog_image()

	# Step 6: Set camera boundaries and center on map.
	var map_pixel_size: Vector2 = Vector2(grid_pixel_size)
	camera_controller.set_map_size(map_pixel_size)
	camera_controller.position = map_pixel_size * 0.5
	camera_controller._target_zoom = 0.7
	camera_controller.zoom = Vector2.ONE * 0.7

	# Step 7: Wire InputManager to camera.
	input_manager.set_camera(camera_controller)

	# Step 8: GameManager.start_game() already called from main menu.
	# Ensure players are initialized (safe to call again).
	if GameManager.players.is_empty():
		GameManager.start_game(num_players, num_ai)

	# Step 9: Spawn starting entities for each player.
	_spawn_starting_entities()

	# Step 10: Initialize AI directors for AI players.
	_create_ai_directors()

	# Step 11: Perform initial fog reveal around starting positions.
	_initial_fog_reveal()

	# Step 12: Load initial chunks around starting camera position.
	chunk_loader.update_loaded_chunks(camera_controller.position)
	decorative_world.world_bounds = Rect2(Vector2.ZERO, map_pixel_size)
	decorative_world.refresh_world_nodes()
	decorative_world.start_ambient()

	_initialized = true
	world_initialized.emit()

# =============================================================================
# Terrain Walkability
# =============================================================================

func _apply_terrain_walkability() -> void:
	if _world_data == null:
		return

	var w: int = _world_data.map_size.x
	var h: int = _world_data.map_size.y

	for y in range(h):
		for x in range(w):
			var cell: Vector2i = Vector2i(x, y)
			if not grid_manager.is_in_bounds(cell):
				continue
			var terrain: int = _world_data.get_terrain_at(cell) as int
			match terrain:
				WorldData.Terrain.DEEP_WATER:
					grid_manager.set_cell_walkable(cell, GridManager.BLOCKED_WATER)
				WorldData.Terrain.WATER:
					grid_manager.set_cell_walkable(cell, GridManager.BLOCKED_WATER)
				WorldData.Terrain.MOUNTAIN:
					grid_manager.set_cell_walkable(cell, GridManager.BLOCKED_MOUNTAIN)
				_:
					# GRASS, FOREST, SAND are walkable.
					pass

# =============================================================================
# Starting Entities
# =============================================================================

func _spawn_starting_entities() -> void:
	if _world_data == null:
		return

	var center: Vector2i = _world_data.get_center()
	var spawn_offsets: Array[Vector2i] = [
		Vector2i(0, 0),      # Player 1: center
		Vector2i(-30, -30),  # Player 2: offset away from center
		Vector2i(30, -30),
		Vector2i(-30, 30),
		Vector2i(30, 30),
		Vector2i(0, -40),
		Vector2i(0, 40),
		Vector2i(-40, 0),
	]

	var all_player_ids: Array = GameManager.get_all_player_ids()
	for i in range(all_player_ids.size()):
		var player_id: int = all_player_ids[i]
		var offset: Vector2i = spawn_offsets[i] if i < spawn_offsets.size() else Vector2i(i * 20, 0)
		var spawn_cell: Vector2i = center + offset

		# Ensure spawn cell is walkable.
		spawn_cell = _find_nearest_walkable(spawn_cell, 80)
		if spawn_cell == Vector2i(-1, -1):
			push_warning("GameWorld: No walkable cell found for player %d." % player_id)
			continue
		spawn_cell = _find_nearest_buildable("town_center", spawn_cell, 80)
		if spawn_cell == Vector2i(-1, -1):
			push_warning("GameWorld: No buildable town center location found for player %d." % player_id)
			continue

		var spawn_pos: Vector2 = grid_manager.get_world_pos_from_cell(spawn_cell)

		# Place town center.
		var tc_building: Node2D = building_manager.place_building("town_center", spawn_cell, player_id)
		if tc_building == null:
			# Fallback: spawn at position directly.
			var tc: Node2D = _create_fallback_building("town_center", player_id, spawn_cell)
			add_child(tc)
			tc.global_position = spawn_pos
		elif tc_building.has_method("complete_construction"):
			tc_building.complete_construction()

		# Spawn starting villagers.
		for v in range(starting_villagers):
			var v_offset: Vector2 = Vector2(
				randf_range(-48.0, 48.0),
				randf_range(-48.0, 48.0)
			)
			var v_pos: Vector2 = spawn_pos + v_offset
			unit_manager.spawn_unit("villager", v_pos, player_id)


func _create_fallback_building(type: String, player_id: int, grid_pos: Vector2i) -> Node2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "%s_%d" % [type, player_id]
	body.collision_layer = 2
	body.collision_mask = 0

	var sprite: ColorRect = ColorRect.new()
	sprite.size = Vector2(64, 64)
	sprite.position = Vector2(-32, -32)
	match type:
		"town_center":
			sprite.color = Color(0.6, 0.4, 0.2)
		_:
			sprite.color = Color(0.5, 0.5, 0.5)
	body.add_child(sprite)

	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	collision.shape = shape
	body.add_child(collision)

	body.set("building_id", randi())
	body.set("building_type", type)
	body.set("player_id", player_id)
	body.set("grid_position", grid_pos)
	body.set("current_hp", 2000)
	body.set("max_hp", 2000)
	body.set("is_constructed", true)
	body.set("construction_progress", 1.0)
	body.set("production_queue", [])
	body.set("is_producing", false)
	body.set("production_timer", 0.0)

	body.add_to_group("buildings")
	return body

# =============================================================================
# AI Directors
# =============================================================================

func _create_ai_directors() -> void:
	var all_player_ids: Array = GameManager.get_all_player_ids()
	for pid_variant: Variant in all_player_ids:
		var player_id: int = pid_variant
		if not GameManager.is_ai_player(player_id):
			continue

		var director: Node = Node.new()
		director.name = "AIDirector_%d" % player_id
		director.set_script(load("res://scripts/ai/ai_director.gd"))
		add_child(director)
		director.initialize(player_id, 2)
		ai_directors[player_id] = director

# =============================================================================
# Fog of War Updates
# =============================================================================

func _initial_fog_reveal() -> void:
	var all_player_ids: Array = GameManager.get_all_player_ids()
	for pid_variant: Variant in all_player_ids:
		var player_id: int = pid_variant

		# Reveal around town center.
		var buildings: Array = building_manager.get_player_buildings(player_id)
		for bld: Node2D in buildings:
			var cell: Vector2i = grid_manager.get_cell_from_world(bld.global_position)
			fog_of_war.reveal_area(cell, 10)

		# Reveal around starting units.
		var units: Array = unit_manager.get_player_units(player_id)
		for unit: Node2D in units:
			var cell: Vector2i = grid_manager.get_cell_from_world(unit.global_position)
			fog_of_war.reveal_area(cell, FogOfWar.DEFAULT_SIGHT_RANGE)


func _update_fog_of_war(delta: float) -> void:
	_fog_update_timer += delta
	if _fog_update_timer < _fog_update_interval:
		return
	_fog_update_timer = 0.0

	# Collect positions of the local player's units and buildings.
	var player_id: int = GameManager.get_local_player_id()
	var unit_cells: Array[Vector2i] = []
	var building_cells: Array[Vector2i] = []

	var units: Array = unit_manager.get_player_units(player_id)
	for unit: Node2D in units:
		var cell: Vector2i = grid_manager.get_cell_from_world(unit.global_position)
		unit_cells.append(cell)

	var buildings: Array = building_manager.get_player_buildings(player_id)
	for bld: Node2D in buildings:
		var cell: Vector2i = grid_manager.get_cell_from_world(bld.global_position)
		building_cells.append(cell)

	fog_of_war.update_visibility(unit_cells, building_cells)

# =============================================================================
# Chunk Loader Updates
# =============================================================================

func _update_chunk_loader(delta: float) -> void:
	_chunk_update_timer += delta
	if _chunk_update_timer < _chunk_update_interval:
		return
	_chunk_update_timer = 0.0

	chunk_loader.update_loaded_chunks(camera_controller.position)

# =============================================================================
# Resource Buffer Flushing
# =============================================================================

func _flush_resource_buffers(delta: float) -> void:
	if resource_manager == null:
		return
	# Flush resource buffers every 0.5 seconds for all players.
	var all_player_ids: Array = GameManager.get_all_player_ids()
	for pid_variant: Variant in all_player_ids:
		var player_id: int = pid_variant
		resource_manager.flush_buffers(player_id)

# =============================================================================
# EventBus Connections
# =============================================================================

func _connect_event_bus() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_saved.connect(_on_game_saved)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.building_destroyed.connect(_on_building_destroyed)
	EventBus.construction_completed.connect(_on_construction_completed)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.button_pressed.connect(_on_button_pressed)
	EventBus.villager_assigned.connect(_on_villager_assigned)

# =============================================================================
# EventBus Handlers
# =============================================================================

func _on_game_started(_player_id: int) -> void:
	pass


func _on_game_saved(_save_name: String) -> void:
	pass


func _on_game_loaded(_save_name: String) -> void:
	# Reload chunks after loading.
	if chunk_loader and _world_data:
		chunk_loader.cleanup()
		chunk_loader.initialize(_world_data)
		chunk_loader.update_loaded_chunks(camera_controller.position)

	# Reapply fog.
	if fog_of_war:
		fog_of_war.request_full_redraw()
		_initial_fog_reveal()

	# Rebuild pathfinder.
	if pathfinder:
		pathfinder.rebuild()

	# Reapply tech effects.
	if technology_tree and technology_tree.has_method("reapply_all_effects"):
		technology_tree.reapply_all_effects()


func _on_unit_died(unit_id: int, _killer_id: int, player_id: int) -> void:
	if particle_effects:
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit != null:
			particle_effects.spawnEffect("death_burst", unit.global_position)


func _on_building_destroyed(building_id: int, player_id: int, _destroyer_id: int) -> void:
	if particle_effects:
		var building: Node2D = building_manager.get_building(building_id)
		if building != null:
			particle_effects.spawnEffect("building_destroy", building.global_position)
	if camera_controller:
		camera_controller.shake(7.0, 0.28)


func _on_construction_completed(_building_id: int, _player_id: int) -> void:
	if camera_controller:
		camera_controller.shake(2.0, 0.16)


func _on_damage_dealt(_target_id: int, _attacker_id: int, damage: int, _is_critical: bool) -> void:
	if camera_controller and damage >= 20:
		camera_controller.shake(3.0, 0.12)


func _on_button_pressed(button_name: String, player_id: int) -> void:
	if player_id != GameManager.local_player_id:
		return

	match button_name:
		"build_menu":
			_open_build_menu()
		"stop_command":
			_stop_selected_units()
		"gather_wood":
			_assign_selected_units_to_resource("wood")
		"gather_food":
			_assign_selected_units_to_resource("food")
		"gather_stone":
			_assign_selected_units_to_resource("stone")
		"gather_gold":
			_assign_selected_units_to_resource("gold")
		"attack_command":
			_attack_selected_units()
		"attack_move_command":
			_attack_move_selected_units()
		"hold_position_command":
			_hold_position_selected_units()
		"patrol_command":
			_patrol_selected_units()
		"cant_afford", "missing_prereq":
			if camera_controller:
				camera_controller.shake(1.4, 0.08)
		_:
			if button_name.begins_with("train_"):
				_train_from_selected_building(button_name.substr(6))


func _on_villager_assigned(unit_id: int, _resource_id: int, task_type: String) -> void:
	var resource_type: String = task_type.replace("gather_", "")
	if unit_id >= 0:
		_assign_unit_to_resource(unit_id, resource_type)
	else:
		_assign_selected_units_to_resource(resource_type)


func _open_build_menu() -> void:
	var ui_manager: Node = get_node_or_null("UILayer/UIManager")
	if ui_manager != null and ui_manager.has_method("open_build_menu"):
		ui_manager.open_build_menu()


func _stop_selected_units() -> void:
	if selection_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null:
			continue
		unit.set("pending_move_position", Vector2.ZERO)
		unit.set("pending_target_resource", null)
		unit.set("pending_target_building", null)
		var movement: Node = unit.get_node_or_null("MovementComponent")
		if movement != null and movement.has_method("stop"):
			movement.stop()
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("IdleState")


func _assign_selected_units_to_resource(resource_type: String) -> void:
	if selection_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		_assign_unit_to_resource(unit_id, resource_type)


func _assign_unit_to_resource(unit_id: int, resource_type: String) -> void:
	var unit: Node2D = unit_manager.get_unit(unit_id)
	if unit == null:
		return
	unit.set("preferred_resource", resource_type)
	var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
	var target_resource: Node2D = null
	if harvest_comp != null and harvest_comp.has_method("find_nearest_resource"):
		target_resource = harvest_comp.find_nearest_resource(resource_type)
	if target_resource == null:
		return
	unit.set("pending_target_resource", target_resource)
	var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
	if state_machine != null and state_machine.has_method("change_state"):
		state_machine.change_state("HarvestState")


func _train_from_selected_building(unit_type: String) -> void:
	if selection_manager == null or building_manager == null:
		return
	var building_id: int = selection_manager.get_selected_building()
	if building_id == -1:
		return
	var building: Node = building_manager.get_building(building_id)
	if building == null or not building.has_method("start_production"):
		return
	var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
	if unit_data.is_empty():
		return
	var cost: Dictionary = unit_data.get("cost", {})
	if not GameManager.spend_resources(cost, GameManager.local_player_id):
		EventBus.button_pressed.emit("cant_afford", GameManager.local_player_id)
		return
	building.start_production(unit_type)
	if particle_effects:
		particle_effects.spawnEffect("build_construct", (building as Node2D).global_position + Vector2(0, -12), 4)


func _issue_attack_move(target_pos: Vector2) -> void:
	if selection_manager == null or unit_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null:
			continue
		unit.set("pending_attack_move_position", target_pos)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("AttackMoveState")


func _issue_patrol(point_a: Vector2, point_b: Vector2) -> void:
	if selection_manager == null or unit_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null:
			continue
		unit.set("patrol_point_a", point_a)
		unit.set("patrol_point_b", point_b)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("PatrolState")


func _issue_hold_position() -> void:
	if selection_manager == null or unit_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null:
			continue
		unit.set("hold_position", unit.global_position)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("HoldPositionState")


func _issue_repair(target_id: int) -> void:
	if selection_manager == null or unit_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null:
			continue
		if unit.get("unit_type") != "villager":
			continue
		unit.set("pending_repair_target", target_id)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("RepairState")


func _attack_selected_units() -> void:
	if selection_manager == null or unit_manager == null:
		return
	var target_id: int = _find_unit_under_mouse()
	if target_id == -1:
		target_id = _find_building_under_mouse()
	if target_id == -1:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null:
			continue
		unit.set("pending_attack_target", target_id)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("AttackState")


func _attack_move_selected_units() -> void:
	if selection_manager == null or unit_manager == null:
		return
	var target_pos: Vector2 = input_manager.mouse_world_position
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null:
			continue
		unit.set("pending_attack_move_position", target_pos)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("AttackMoveState")


func _hold_position_selected_units() -> void:
	if selection_manager == null or unit_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null:
			continue
		unit.set("hold_position", unit.global_position)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("HoldPositionState")


func _patrol_selected_units() -> void:
	if selection_manager == null or unit_manager == null:
		return
	var mp: Vector2 = input_manager.mouse_world_position
	var point_a: Vector2 = mp
	var point_b: Vector2 = mp + Vector2(200, 0)
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null:
			continue
		unit.set("patrol_point_a", point_a)
		unit.set("patrol_point_b", point_b)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("PatrolState")


func _find_unit_under_mouse() -> int:
	if unit_manager == null or input_manager == null:
		return -1
	var mouse_pos: Vector2 = input_manager.mouse_world_position
	var units: Array = unit_manager.get_player_units(GameManager.get_local_player_id())
	var best_id: int = -1
	var best_dist_sq: float = 32.0 * 32.0
	for unit: Node2D in units:
		if not is_instance_valid(unit):
			continue
		var dist_sq: float = unit.global_position.distance_squared_to(mouse_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_id = unit.get("unit_id")
	return best_id


# =============================================================================
# Utility
# =============================================================================

func _find_nearest_walkable(cell: Vector2i, max_radius: int = 15) -> Vector2i:
	if grid_manager.is_walkable(cell):
		return cell

	for r in range(1, max_radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var check: Vector2i = cell + Vector2i(dx, dy)
				if grid_manager.is_in_bounds(check) and grid_manager.is_walkable(check):
					return check

	return Vector2i(-1, -1)


func _find_nearest_buildable(building_type: String, cell: Vector2i, max_radius: int = 20) -> Vector2i:
	if building_manager != null and building_manager.can_place_building(building_type, cell):
		return cell

	for r in range(1, max_radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var check: Vector2i = cell + Vector2i(dx, dy)
				if grid_manager.is_in_bounds(check) and building_manager.can_place_building(building_type, check):
					return check

	return Vector2i(-1, -1)


func _find_building_under_mouse() -> int:
	if building_manager == null or input_manager == null:
		return -1
	var mouse_pos: Vector2 = input_manager.mouse_world_position
	var buildings: Array = building_manager.get_player_buildings(GameManager.get_local_player_id())
	var best_id: int = -1
	var best_dist_sq: float = 64.0 * 64.0
	for bld: Node2D in buildings:
		if not is_instance_valid(bld):
			continue
		var dist_sq: float = bld.global_position.distance_squared_to(mouse_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_id = bld.get("building_id")
	return best_id


func get_world_data() -> WorldData:
	return _world_data


func is_initialized() -> bool:
	return _initialized

# =============================================================================
# Cleanup
# =============================================================================

func cleanup() -> void:
	_initialized = false

	# Free AI directors.
	for pid: int in ai_directors:
		if is_instance_valid(ai_directors[pid]):
			ai_directors[pid].queue_free()
	ai_directors.clear()

	# Clean up chunk loader.
	if chunk_loader:
		chunk_loader.cleanup()

	# Clear fog data.
	if fog_of_war:
		fog_of_war._fog_data.clear()
		fog_of_war._initialize_fog_image()

	world_cleanup_complete.emit()
