## Visual feedback for touch interactions on mobile.
##
## Shows tap circles, long-press rings, selection box highlights,
## and drag trails. Draws on a dedicated CanvasLayer above the game.
extends CanvasItem

# =============================================================================
# Configuration
# =============================================================================

## Radius of the tap indicator circle.
var tap_radius: float = 16.0

## Duration of the tap indicator fade-out in seconds.
var tap_duration: float = 0.3

## Maximum scale the tap indicator reaches at end of life.
var tap_max_scale: float = 1.5

## Color of the tap indicator.
var tap_color: Color = Color(1.0, 1.0, 1.0, 0.6)

## Long-press ring fill radius.
var long_press_radius: float = 20.0

## Color of the long-press fill ring.
var long_press_color: Color = Color(0.3, 0.75, 1.0, 0.5)

## Selection box fill color.
var selection_box_color: Color = Color(0.2, 0.8, 0.2, 0.2)

## Selection box border color.
var selection_box_border: Color = Color(0.2, 0.8, 0.2, 0.7)

## Selection box border width.
var selection_box_width: float = 2.0

# =============================================================================
# Active Indicators
# =============================================================================

## Each indicator: { "type": String, "pos": Vector2, "time": float, "duration": float, ... }
var _indicators: Array[Dictionary] = []

## Selection box state.
var _selection_active: bool = false
var _selection_start: Vector2 = Vector2.ZERO
var _selection_current: Vector2 = Vector2.ZERO

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var i: int = _indicators.size() - 1
	while i >= 0:
		var ind: Dictionary = _indicators[i]
		ind["time"] += delta
		if ind["time"] >= ind["duration"]:
			_indicators.remove_at(i)
		i -= 1

	if not _indicators.is_empty() or _selection_active:
		queue_redraw()


func _draw() -> void:
	for ind: Dictionary in _indicators:
		match ind.get("type", ""):
			"tap":
				_draw_tap(ind)
			"long_press":
				_draw_long_press(ind)

	if _selection_active:
		_draw_selection_box()


# =============================================================================
# Public API
# =============================================================================

## Show a tap indicator at the given screen position.
func show_tap(pos: Vector2) -> void:
	_indicators.append({
		"type": "tap",
		"pos": pos,
		"time": 0.0,
		"duration": tap_duration,
	})
	queue_redraw()


## Show a long-press ring at the given screen position.
func show_long_press(pos: Vector2) -> void:
	_indicators.append({
		"type": "long_press",
		"pos": pos,
		"time": 0.0,
		"duration": 0.5,
	})
	queue_redraw()


## Begin showing a selection box from a start position.
func begin_selection_box(start: Vector2) -> void:
	_selection_active = true
	_selection_start = start
	_selection_current = start
	queue_redraw()


## Update the selection box end position.
func update_selection_box(current: Vector2) -> void:
	_selection_current = current
	queue_redraw()


## End the selection box and fade it out.
func end_selection_box() -> void:
	_selection_active = false
	queue_redraw()


# =============================================================================
# Drawing
# =============================================================================

func _draw_tap(ind: Dictionary) -> void:
	var pos: Vector2 = ind["pos"]
	var t: float = ind["time"] / ind["duration"]
	var alpha: float = lerpf(tap_color.a, 0.0, t)
	var radius: float = tap_radius * lerpf(1.0, tap_max_scale, t)
	var color: Color = Color(tap_color.r, tap_color.g, tap_color.b, alpha)

	draw_circle(pos, radius, color)

	# Inner ring.
	var inner_color: Color = Color(tap_color.r, tap_color.g, tap_color.b, alpha * 0.4)
	draw_circle(pos, radius * 0.6, inner_color)


func _draw_long_press(ind: Dictionary) -> void:
	var pos: Vector2 = ind["pos"]
	var t: float = clampf(ind["time"] / ind["duration"], 0.0, 1.0)
	var angle: float = t * TAU

	# Background ring.
	draw_arc(pos, long_press_radius, 0.0, TAU, 64, Color(long_press_color.r, long_press_color.g, long_press_color.b, 0.2), 2.0, true)

	# Filled arc.
	if angle > 0.01:
		var points: PackedVector2Array = PackedVector2Array()
		points.append(pos)
		var segments: int = maxi(int(angle / (TAU / 32.0)), 1)
		for s in range(segments + 1):
			var a: float = angle * float(s) / float(segments) - PI / 2.0
			points.append(pos + Vector2(cos(a), sin(a)) * long_press_radius)
		if points.size() >= 3:
			draw_colored_polygon(points, long_press_color)

	# Center dot.
	draw_circle(pos, 4.0, Color(long_press_color.r, long_press_color.g, long_press_color.b, 0.8))


func _draw_selection_box() -> void:
	var rect: Rect2 = Rect2(_selection_start, _selection_current - _selection_start).abs()

	# Fill.
	draw_rect(rect, selection_box_color, true)
	# Border.
	draw_rect(rect, selection_box_border, false, selection_box_width)

	# Corner markers (4 small squares at corners).
	var corner_size: float = 6.0
	var corners: Array[Vector2] = [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + Vector2(0, rect.size.y),
		rect.position + rect.size,
	]
	for corner: Vector2 in corners:
		var corner_rect: Rect2 = Rect2(corner - Vector2(corner_size * 0.5, corner_size * 0.5), Vector2(corner_size, corner_size))
		draw_rect(corner_rect, selection_box_border, true)
