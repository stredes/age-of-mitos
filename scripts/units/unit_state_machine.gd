## Finite state machine for units. Manages state transitions with proper
## enter/exit lifecycle, deferred transitions to prevent re-entrant issues,
## and a guard to prevent exiting DeadState prematurely.
class_name UnitStateMachine
extends Node

# =============================================================================
# Signals
# =============================================================================

signal state_changed(old_state: String, new_state: String)

# =============================================================================
# Constants
# =============================================================================

## States that cannot be interrupted by normal transitions.
const LOCKED_STATES: Array[String] = ["DeadState"]

# =============================================================================
# Properties
# =============================================================================

var current_state: Node = null
var states: Dictionary = {}
var unit: Node2D = null

var _pending_state: String = ""
var _state_history: Array[String] = []
var _transition_count: int = 0

const MAX_HISTORY: int = 8

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	unit = get_parent() as Node2D
	call_deferred("_register_states")


func _process(delta: float) -> void:
	# Process deferred state change before updating current state.
	if not _pending_state.is_empty():
		var next: String = _pending_state
		_pending_state = ""
		_do_change_state(next)

	if current_state != null and current_state.has_method("update"):
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null and current_state.has_method("physics_update"):
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != null and current_state.has_method("handle_input"):
		current_state.handle_input(event)

# =============================================================================
# State Registration
# =============================================================================

func _register_states() -> void:
	for child: Node in get_children():
		states[child.name] = child
		if child is UnitState:
			child.unit = unit
			child.state_machine = self

	if states.is_empty():
		return

	# Start in IdleState if it exists, otherwise first registered state.
	var initial: String = "IdleState" if states.has("IdleState") else states.keys()[0]
	_do_change_state(initial)

# =============================================================================
# Public API
# =============================================================================

## Request a state transition. Deferred to next frame to avoid re-entrant
## issues when called from inside update() or enter()/exit().
func change_state(new_state_name: String) -> void:
	if new_state_name.is_empty():
		return

	if not states.has(new_state_name):
		push_warning("UnitStateMachine: State '%s' not found." % new_state_name)
		return

	# If we're already transitioning to this state, ignore.
	if _pending_state == new_state_name:
		return

	# Guard: locked states cannot be interrupted unless the target IS the same state.
	if current_state != null:
		var current_name: String = current_state.name
		if current_name == new_state_name:
			return  # Already in this state.
		if current_name in LOCKED_STATES:
			return  # DeadState cannot be interrupted.

	_pending_state = new_state_name


## Force an immediate state transition, bypassing deferred queue and guards.
## Use sparingly — only for critical transitions like death.
func force_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_warning("UnitStateMachine: Force state '%s' not found." % new_state_name)
		return
	_pending_state = ""
	_do_change_state(new_state_name)


## Get the name of the current active state.
func get_state() -> String:
	if current_state != null:
		return current_state.name
	return ""


## Check if a state exists.
func has_state(name: String) -> bool:
	return states.has(name)


## Add a state node at runtime (e.g. for dynamically added states).
func add_state(name: String, state: Node) -> void:
	states[name] = state
	if state is UnitState:
		state.unit = unit
		state.state_machine = self


## Get the number of transitions that have occurred.
func get_transition_count() -> int:
	return _transition_count


## Get the last N state names for debugging.
func get_history() -> Array[String]:
	return _state_history.duplicate()

# =============================================================================
# Internal
# =============================================================================

func _do_change_state(new_state_name: String) -> void:
	var new_state: Node = states.get(new_state_name)
	if new_state == null:
		return

	# Exit current state.
	if current_state != null and current_state != new_state:
		if current_state.has_method("exit"):
			current_state.exit()

		# Track history.
		_state_history.append(current_state.name)
		if _state_history.size() > MAX_HISTORY:
			_state_history.pop_front()

	_transition_count += 1

	# Enter new state.
	current_state = new_state
	if current_state.has_method("enter"):
		current_state.enter()

	state_changed.emit(_state_history.back() if _state_history.size() > 0 else "", new_state_name)
