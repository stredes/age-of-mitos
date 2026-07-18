## Manages overall game state, player data, resources, and game flow.
##
## GameManager is the central authority for game state. It tracks which phase
## the game is in, manages per-player resources, controls game speed, and
## coordinates start/pause/resume lifecycle events.
extends Node

# =============================================================================
# Constants
# =============================================================================

## Default starting resources for each player.
const DEFAULT_STARTING_RESOURCES: Dictionary = {
	"wood": 200,
	"stone": 100,
	"food": 200,
	"gold": 100,
}

## Available game speed multipliers.
const SPEED_OPTIONS: Array[float] = [0.5, 1.0, 2.0, 3.0]

## Maximum number of players supported.
const MAX_PLAYERS: int = 8

# =============================================================================
# Enums
# =============================================================================

## Represents the current high-level game state.
enum GameState {
	MENU,      ## Main menu is displayed.
	PLAYING,   ## Active gameplay.
	PAUSED,    ## Game is paused by the player.
	GAME_OVER, ## Game has ended (victory or defeat).
}

# =============================================================================
# Signals
# =============================================================================

## Emitted when the game state transitions.
signal game_state_changed(old_state: GameState, new_state: GameState)

## Emitted when a player's resource total changes.
signal player_resource_changed(player_id: int, resource_type: String, new_amount: int)

## Emitted when the game ends with a winner.
## [param winner_id: int] The winning player's ID (-1 for draw).
signal game_ended(winner_id: int)

# =============================================================================
# Properties
# =============================================================================

## Current game state.
var current_state: GameState = GameState.MENU

## Active game speed multiplier.
var game_speed: float = 1.0

## Index into SPEED_OPTIONS for the current speed.
var speed_index: int = 1

## Elapsed in-game time in seconds (affected by game_speed).
var game_time: float = 0.0

## Real elapsed time in seconds (not affected by game_speed).
var real_time: float = 0.0

## Dictionary of player data keyed by player_id (int).
## Each value is a Dictionary with keys: "resources", "team", "is_ai", "name".
var players: Dictionary = {}

## The local human player's ID.
var local_player_id: int = 1

## Whether the game has been initialized.
var is_initialized: bool = false

## The winning player's ID when the game ends (-1 for draw, -2 for not ended).
var winner_id: int = -2

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		real_time += delta
		game_time += delta * game_speed

# =============================================================================
# Game Lifecycle Methods
# =============================================================================

## Initialize and start a new game with the given number of players.
## [param num_players: int] Total number of players (human + AI).
## [param num_ai: int] Number of AI-controlled players.
func start_game(num_players: int = 2, num_ai: int = 1) -> void:
	_initialize_players(num_players, num_ai)
	game_time = 0.0
	real_time = 0.0
	game_speed = 1.0
	speed_index = 1
	Engine.time_scale = 1.0
	winner_id = -2
	is_initialized = true
	_change_state(GameState.PLAYING)
	EventBus.game_started.emit(local_player_id)
	set_physics_process(true)


## Pause the game. Only allowed during PLAYING state.
func pause_game() -> void:
	if current_state != GameState.PLAYING:
		return
	_change_state(GameState.PAUSED)
	Engine.time_scale = 0.0
	EventBus.game_paused.emit(true)


## Resume the game from a paused state.
func resume_game() -> void:
	if current_state != GameState.PAUSED:
		return
	_change_state(GameState.PLAYING)
	Engine.time_scale = game_speed
	EventBus.game_paused.emit(false)


## End the game and transition to GAME_OVER.
## [param winner_id: int] The player ID of the winner (-1 for draw).
func end_game(winner_id: int = -1) -> void:
	if current_state == GameState.GAME_OVER:
		return
	self.winner_id = winner_id
	_change_state(GameState.GAME_OVER)
	set_physics_process(false)
	game_ended.emit(winner_id)
	EventBus.game_over.emit(winner_id, game_time)


## Return to the main menu.
func return_to_menu() -> void:
	_change_state(GameState.MENU)
	is_initialized = false
	players.clear()
	set_physics_process(false)

# =============================================================================
# Game Speed
# =============================================================================

## Set the game speed to a specific multiplier.
## [param speed: float] The desired speed (clamped to SPEED_OPTIONS).
func set_speed(speed: float) -> void:
	var closest_index: int = 0
	var closest_diff: float = absf(SPEED_OPTIONS[0] - speed)
	for i in range(1, SPEED_OPTIONS.size()):
		var diff: float = absf(SPEED_OPTIONS[i] - speed)
		if diff < closest_diff:
			closest_diff = diff
			closest_index = i
	speed_index = closest_index
	game_speed = SPEED_OPTIONS[speed_index]
	if current_state == GameState.PLAYING:
		Engine.time_scale = game_speed
	EventBus.game_speed_changed.emit(game_speed)


## Cycle to the next speed option.
func cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEED_OPTIONS.size()
	set_speed(SPEED_OPTIONS[speed_index])


## Get the current speed multiplier.
func get_speed() -> float:
	return game_speed

# =============================================================================
# Player Management
# =============================================================================

## Create and register all players for a new game.
## [param num_players: int] Total number of players.
## [param num_ai: int] Number of AI players (assigned to the highest IDs).
func _initialize_players(num_players: int, num_ai: int) -> void:
	players.clear()
	num_players = clampi(num_players, 1, MAX_PLAYERS)
	num_ai = clampi(num_ai, 0, num_players - 1)
	for i in range(1, num_players + 1):
		var is_ai: bool = i > (num_players - num_ai)
		players[i] = {
			"resources": DEFAULT_STARTING_RESOURCES.duplicate(),
			"team": i if is_ai else 0,
			"is_ai": is_ai,
			"player_name": "Player %d" % i,
		}


## Get a player's data dictionary.
## [param player_id: int] The player to query.
## [return] The player's data Dictionary, or an empty dict if not found.
func get_player(player_id: int) -> Dictionary:
	return players.get(player_id, {})


## Get the local player's ID.
func get_local_player_id() -> int:
	return local_player_id


## Set which player is the local human player.
## [param id: int] The player ID to designate as local.
func set_local_player(id: int) -> void:
	if id in players:
		local_player_id = id


## Check if a given player ID is an AI.
## [param player_id: int] The player to check.
func is_ai_player(player_id: int) -> bool:
	var p: Dictionary = players.get(player_id, {})
	return p.get("is_ai", false)


## Get all player IDs.
func get_all_player_ids() -> Array:
	return players.keys()

# =============================================================================
# Resource Management
# =============================================================================

## Get a specific resource amount for a player.
## [param resource_type: String] "wood", "stone", "food", or "gold".
## [param player_id: int] The player to query.
## [return] The amount of the resource, or -1 if invalid.
func get_resource(resource_type: String, player_id: int = -1) -> int:
	if player_id == -1:
		player_id = local_player_id
	var p: Dictionary = players.get(player_id, {})
	if p.is_empty():
		return -1
	var resources: Dictionary = p.get("resources", {})
	return resources.get(resource_type, 0)


## Get all resources for a player as a Dictionary.
## [param player_id: int] The player to query.
func get_resources(player_id: int = -1) -> Dictionary:
	if player_id == -1:
		player_id = local_player_id
	var p: Dictionary = players.get(player_id, {})
	if p.is_empty():
		return {}
	return p.get("resources", {}).duplicate()


## Add resources to a player's stockpile.
## [param resource_type: String] The resource type to add.
## [param amount: int] The amount to add (must be positive).
## [param player_id: int] The player receiving resources.
## [return] true if the operation succeeded.
func add_resource(resource_type: String, amount: int, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = local_player_id
	if amount <= 0:
		push_warning("GameManager: add_resource called with non-positive amount %d." % amount)
		return false
	var p: Dictionary = players.get(player_id, {})
	if p.is_empty():
		push_warning("GameManager: add_resource for unknown player %d." % player_id)
		return false
	var resources: Dictionary = p.get("resources", {})
	if not resources.has(resource_type):
		resources[resource_type] = 0
	resources[resource_type] += amount
	p["resources"] = resources
	player_resource_changed.emit(player_id, resource_type, resources[resource_type])
	EventBus.resource_changed.emit(resource_type, resources[resource_type], player_id)
	return true


## Spend (remove) resources from a player's stockpile.
## [param resource_type: String] The resource type to spend.
## [param amount: int] The amount to spend (must be positive).
## [param player_id: int] The player spending resources.
## [return] true if the player had enough and the spend succeeded.
func spend_resource(resource_type: String, amount: int, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = local_player_id
	if amount <= 0:
		push_warning("GameManager: spend_resource called with non-positive amount %d." % amount)
		return false
	var p: Dictionary = players.get(player_id, {})
	if p.is_empty():
		return false
	var resources: Dictionary = p.get("resources", {})
	var current: int = resources.get(resource_type, 0)
	if current < amount:
		return false
	resources[resource_type] = current - amount
	p["resources"] = resources
	player_resource_changed.emit(player_id, resource_type, resources[resource_type])
	EventBus.resource_changed.emit(resource_type, resources[resource_type], player_id)
	return true


## Check whether a player can afford a given cost.
## [param cost: Dictionary] e.g. {"wood": 50, "gold": 25}.
## [param player_id: int] The player to check.
## [return] true if the player has at least the required amount of each resource.
func can_afford(cost: Dictionary, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = local_player_id
	var p: Dictionary = players.get(player_id, {})
	if p.is_empty():
		return false
	var resources: Dictionary = p.get("resources", {})
	for resource_type: String in cost:
		var required: int = cost[resource_type]
		var available: int = resources.get(resource_type, 0)
		if available < required:
			return false
	return true


## Spend multiple resources at once. Only succeeds if the player can afford all.
## [param cost: Dictionary] e.g. {"wood": 50, "gold": 25}.
## [param player_id: int] The player spending.
## [return] true if the full cost was deducted.
func spend_resources(cost: Dictionary, player_id: int = -1) -> bool:
	if not can_afford(cost, player_id):
		return false
	for resource_type: String in cost:
		spend_resource(resource_type, cost[resource_type], player_id)
	return true

# =============================================================================
# Game State Helpers
# =============================================================================

## Check if the game is actively being played (not paused, not menu, not over).
func is_playing() -> bool:
	return current_state == GameState.PLAYING


## Check if the game is paused.
func is_paused() -> bool:
	return current_state == GameState.PAUSED


## Check if the game has ended.
func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER


## Get the formatted game time as "MM:SS".
func get_game_time_formatted() -> String:
	var minutes: int = int(game_time) / 60
	var seconds: int = int(game_time) % 60
	return "%02d:%02d" % [minutes, seconds]


## Get the formatted game time as "HH:MM:SS".
func get_game_time_full() -> String:
	var total_seconds: int = int(game_time)
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

# =============================================================================
# Private Helpers
# =============================================================================

## Transition to a new game state and emit the state change signal.
## [param new_state: GameState] The state to transition to.
func _change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	var old_state: GameState = current_state
	current_state = new_state
	game_state_changed.emit(old_state, new_state)
