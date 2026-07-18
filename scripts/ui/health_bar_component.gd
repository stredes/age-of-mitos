extends Node2D

const UNIT_BAR_SIZE: Vector2 = Vector2(40, 5)
const BUILDING_BAR_SIZE: Vector2 = Vector2(60, 6)
const BAR_OFFSET_Y: float = -30.0

const COLOR_HEALTHY: Color = Color(0.2, 0.8, 0.2)
const COLOR_WOUNDED: Color = Color(0.9, 0.9, 0.2)
const COLOR_CRITICAL: Color = Color(0.9, 0.2, 0.2)
const COLOR_BG: Color = Color(0.1, 0.1, 0.1, 0.8)

var _bar_size: Vector2 = UNIT_BAR_SIZE
var _health_comp: HealthComponent = null
var _current_percent: float = 1.0


func _ready() -> void:
	z_index = 100
	_detect_parent_type()
	_connect_health_signal()
	queue_redraw()


func _detect_parent_type() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	_bar_size = UNIT_BAR_SIZE
	if parent is BuildingBase or "building" in str(parent.name).to_lower():
		_bar_size = BUILDING_BAR_SIZE


func _connect_health_signal() -> void:
	_health_comp = get_node_or_null("../HealthComponent") as HealthComponent
	if _health_comp == null:
		_health_comp = get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if _health_comp != null:
		_health_comp.health_changed.connect(_on_health_changed)
		_current_percent = _health_comp.get_hp_percent()


func _on_health_changed(_old_hp: int, new_hp: int, max_hp: int) -> void:
	if max_hp <= 0:
		_current_percent = 0.0
	else:
		_current_percent = float(new_hp) / float(max_hp)
	queue_redraw()


func _get_bar_color() -> Color:
	if _current_percent < 0.3:
		return COLOR_CRITICAL
	elif _current_percent < 0.7:
		return COLOR_WOUNDED
	return COLOR_HEALTHY


func _draw() -> void:
	var offset: Vector2 = Vector2(-_bar_size.x * 0.5, BAR_OFFSET_Y)
	draw_rect(Rect2(offset, _bar_size), COLOR_BG)
	var fill_size: Vector2 = Vector2(_bar_size.x * _current_percent, _bar_size.y)
	draw_rect(Rect2(offset, fill_size), _get_bar_color())
