class_name TouchIndicator
extends CanvasLayer

signal indicator_finished(indicator_type: String)

@export var touch_duration: float = 0.3
@export var long_press_duration: float = 0.5
@export var max_radius: float = 48.0
@export var min_radius: float = 12.0
@export var expansion_speed: float = 200.0
@export var fade_speed: float = 3.0

var _active_indicators: Array[Dictionary] = []

enum IndicatorType {
	TOUCH_DOWN = "touch_down",
	TAP = "tap",
	LONG_PRESS = "long_press",
	DRAG_START = "drag_start",
	PINCH_START = "pinch_start",
	DRAG_SELECT = "drag_select"
}

var _colors: Dictionary = {
	"touch_down": Color(0.2, 0.7, 0.3, 0.8),
	"tap": Color(0.3, 0.8, 1.0, 0.9),
	"long_press": Color(1.0, 0.6, 0.1, 0.9),
	"drag_start": Color(0.8, 0.3, 0.9, 0.8),
	"pinch_start": Color(0.2, 0.9, 0.8, 0.8),
	"drag_select": Color(0.2, 0.7, 0.3, 0.6),
}

var _particle_shader: Shader = null


func _ready() -> void:
	_name = "TouchIndicators"
	layer = 200
	mouse_filter = MOUSE_FILTER_IGNORE
	_process_mode = PROCESS_MODE_ALWAYS

	_particle_shader = _create_particle_shader()


func _process(delta: float) -> void:
	var to_remove = []
	for i in range(_active_indicators.size()):
		var indicator = _active_indicators[i]
		indicator.elapsed += delta
		indicator.progress = clampf(indicator.elapsed / indicator.duration, 0.0, 1.0)

		if indicator.type == "drag_select":
			indicator.current_radius = minf(indicator.current_radius + expansion_speed * delta, indicator.max_radius)
			indicator.alpha = lerpf(indicator.start_alpha, 0.0, indicator.progress * 0.5)

		if indicator.elapsed >= indicator.duration:
			to_remove.append(i)

	for idx in to_remove.reversed():
		var finished = _active_indicators[idx]
		_active_indicators.remove_at(idx)
		indicator_finished.emit(finished.type)

	queue_redraw()


func _draw() -> void:
	for indicator in _active_indicators:
		_draw_indicator(indicator)


func _draw_indicator(indicator: Dictionary) -> void:
	var pos = indicator.position
	var radius = indicator.current_radius
	var color = indicator.color
	color.a = indicator.alpha

	if indicator.type == "drag_select":
		draw_circle(pos, radius, color)
		var border_color = color
		border_color.a = indicator.alpha * 0.5
		draw_circle(pos, radius, border_color, false, 2.0)
	else:
		var rings = 3
		for i in range(rings):
			var ring_progress = (indicator.progress + float(i) / rings) % 1.0
			var ring_radius = lerpf(min_radius, max_radius, ring_progress)
			var ring_alpha = indicator.alpha * (1.0 - ring_progress)
			var ring_color = color
			ring_color.a = ring_alpha
			draw_circle(pos, ring_radius, ring_color, false, 2.0)

		var center_color = color
		center_color.a = indicator.alpha * 0.5
		draw_circle(pos, min_radius * 0.5, center_color)


func show_touch(position: Vector2, indicator_type: String = "touch_down") -> void:
	var color = _colors.get(indicator_type, _colors["touch_down"])
	var duration = indicator_type == "long_press" ? long_press_duration : touch_duration

	var indicator = {
		"type": indicator_type,
		"position": position,
		"color": color,
		"start_alpha": color.a,
		"alpha": color.a,
		"current_radius": indicator_type == "drag_select" ? min_radius : max_radius,
		"max_radius": max_radius,
		"min_radius": min_radius,
		"elapsed": 0.0,
		"duration": duration,
		"progress": 0.0,
	}
	_active_indicators.append(indicator)


func show_tap(position: Vector2) -> void:
	show_touch(position, "tap")


func show_long_press(position: Vector2) -> void:
	show_touch(position, "long_press")


func show_drag_start(position: Vector2) -> void:
	show_touch(position, "drag_start")


func show_pinch_start(position: Vector2) -> void:
	show_touch(position, "pinch_start")


func show_selection_drag(start_pos: Vector2, end_pos: Vector2) -> void:
	var center = (start_pos + end_pos) * 0.5
	var size = (end_pos - start_pos).abs()
	var radius = max(size.x, size.y) * 0.5

	var color = _colors["drag_select"]
	var indicator = {
		"type": "drag_select",
		"position": center,
		"color": color,
		"start_alpha": color.a,
		"alpha": color.a,
		"current_radius": min_radius,
		"max_radius": radius,
		"min_radius": min_radius,
		"elapsed": 0.0,
		"duration": touch_duration * 4.0,
		"progress": 0.0,
	}
	_active_indicators.append(indicator)


func clear_all() -> void:
	_active_indicators.clear()
	queue_redraw()


func _create_particle_shader() -> Shader:
	var shader_code = """
	shader_type canvas_item;
	render_mode unshaded;

	uniform float time : hint_range(0, 10);
	uniform vec4 color : hint_color;
	uniform float progress : hint_range(0, 1);
	uniform float radius;

	void fragment() {
		vec2 center = vec2(0.5, 0.5);
		float dist = distance(UV, center);
		float ring_width = 0.02;
		float alpha = smoothstep(radius, radius - ring_width, dist) * (1.0 - progress);
		COLOR = color * alpha;
	}
	"""
	var shader = Shader.new()
	shader.code = shader_code
	return shader


func get_active_count() -> int:
	return _active_indicators.size()


func is_showing_type(indicator_type: String) -> bool:
	for indicator in _active_indicators:
		if indicator.type == indicator_type:
			return true
	return false