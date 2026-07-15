class_name SelectionComponent
extends Node

signal selected()
signal deselected()

@export var is_selectable: bool = true
@export var selection_radius: float = 20.0

var is_selected: bool = false

var _parent_unit: Node2D = null


func _ready() -> void:
	call_deferred("_setup_parent")


func _setup_parent() -> void:
	_parent_unit = get_parent() as Node2D
	if _parent_unit != null:
		_parent_unit.draw.connect(_on_parent_draw)


func select() -> void:
	if not is_selectable:
		return
	if is_selected:
		return

	is_selected = true
	if _parent_unit != null:
		_parent_unit.is_selected = true
		_parent_unit.queue_redraw()

	var unit_id: int = -1
	var player_id: int = -1
	if _parent_unit != null:
		unit_id = int(_parent_unit.get("unit_id")) if _parent_unit.get("unit_id") != null else -1
		player_id = int(_parent_unit.get("player_id")) if _parent_unit.get("player_id") != null else -1

	if unit_id != -1:
		EventBus.unit_selected.emit(unit_id, player_id)

	selected.emit()


func deselect() -> void:
	if not is_selected:
		return

	is_selected = false
	if _parent_unit != null:
		_parent_unit.is_selected = false
		_parent_unit.queue_redraw()

	var unit_id: int = -1
	var player_id: int = -1
	if _parent_unit != null:
		unit_id = int(_parent_unit.get("unit_id")) if _parent_unit.get("unit_id") != null else -1
		player_id = int(_parent_unit.get("player_id")) if _parent_unit.get("player_id") != null else -1

	if unit_id != -1:
		EventBus.unit_deselected.emit(unit_id, player_id)

	deselected.emit()


func draw_selection_ring() -> void:
	if not is_selected or _parent_unit == null:
		return

	var color: Color = Color(0.2, 1.0, 0.2, 0.35)
	_parent_unit.draw_circle(Vector2.ZERO, selection_radius, color)
	_parent_unit.draw_arc(Vector2.ZERO, selection_radius, 0, TAU, 32, Color(0.2, 1.0, 0.2, 0.9), 2.0)


func set_selectable(value: bool) -> void:
	is_selectable = value
	if not value and is_selected:
		deselect()


func toggle() -> void:
	if is_selected:
		deselect()
	else:
		select()


func _on_parent_draw() -> void:
	draw_selection_ring()
