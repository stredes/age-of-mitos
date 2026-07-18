class_name UnitStateMachine
extends Node

signal state_changed(old_state: String, new_state: String)

var current_state: Node = null
var states: Dictionary = {}
var unit: Node2D = null


func _ready() -> void:
	unit = get_parent() as Node2D
	call_deferred("_register_states")


func _register_states() -> void:
	for child: Node in get_children():
		states[child.name] = child
		if child is UnitState:
			child.unit = unit
			child.state_machine = self

	if unit != null and unit.has_signal("damaged"):
		unit.damaged.connect(_on_unit_damaged)

	if states.is_empty():
		return

	var first_state: String = states.keys()[0]
	_change_state(first_state)


func _on_unit_damaged(damage_amount: int, _attacker_id: int) -> void:
	if current_state != null and current_state.name == "HurtState":
		return
	if not states.has("HurtState"):
		return
	var health_comp: Node = unit.get_node_or_null("HealthComponent")
	if health_comp == null:
		return
	var max_hp: int = health_comp.get("max_hp") if health_comp.get("max_hp") != null else 1
	if float(damage_amount) > float(max_hp) * HurtState.HEAVY_HIT_THRESHOLD:
		trigger_hurt()


func trigger_hurt() -> void:
	if current_state != null and states.has("HurtState"):
		var hurt: Node = states["HurtState"]
		if hurt.has_method("get") and hurt.get("previous_state_name") != null:
			hurt.previous_state_name = current_state.name
	change_state("HurtState")


func _process(delta: float) -> void:
	if current_state != null and current_state.has_method("update"):
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null and current_state.has_method("physics_update"):
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != null and current_state.has_method("handle_input"):
		current_state.handle_input(event)


func change_state(new_state_name: String) -> void:
	_change_state(new_state_name)


func _change_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_warning("UnitStateMachine: State '%s' not found." % new_state_name)
		return

	var new_state: Node = states[new_state_name]
	if new_state == current_state:
		return

	var old_name: String = ""
	if current_state != null:
		old_name = current_state.name
		if current_state.has_method("exit"):
			current_state.exit()

	current_state = new_state
	if current_state.has_method("enter"):
		current_state.enter()

	state_changed.emit(old_name, new_state_name)


func get_state() -> String:
	if current_state != null:
		return current_state.name
	return ""


func add_state(name: String, state: Node) -> void:
	states[name] = state
	if state is UnitState:
		state.unit = unit
		state.state_machine = self


func has_state(name: String) -> bool:
	return states.has(name)
