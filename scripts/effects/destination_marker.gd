class_name DestinationMarker
extends Node2D

## Visual marker that appears briefly at the movement target location.
## Shows a green circle with expanding ring that fades out.

var _markers: Array[Dictionary] = []
var _marker_layer: CanvasLayer = null

const MARKER_DURATION: float = 1.2
const MARKER_RADIUS: float = 12.0
const MARKER_RING_MAX_RADIUS: float = 30.0
const MARKER_COLOR: Color = Color(0.2, 0.9, 0.3, 0.8)
const MARKER_RING_COLOR: Color = Color(0.3, 1.0, 0.4, 0.6)


func _ready() -> void:
	_marker_layer = CanvasLayer.new()
	_marker_layer.layer = 50
	_marker_layer.name = "DestinationMarkerLayer"
	add_child(_marker_layer)


func _process(delta: float) -> void:
	var to_remove: Array[int] = []
	for i: int in range(_markers.size()):
		var marker: Dictionary = _markers[i]
		marker["elapsed"] += delta
		var elapsed: float = marker["elapsed"]

		if elapsed >= MARKER_DURATION:
			to_remove.append(i)
			continue

		var progress: float = elapsed / MARKER_DURATION
		var ring_radius: float = MARKER_RADIUS + (MARKER_RING_MAX_RADIUS - MARKER_RADIUS) * progress
		var alpha: float = 1.0 - progress

		var marker_node: Node2D = marker.get("node", null)
		if marker_node != null and is_instance_valid(marker_node):
			marker_node.queue_redraw()
			marker["ring_radius"] = ring_radius
			marker["alpha"] = alpha

	for i: int in range(to_remove.size() - 1, -1, -1):
		var idx: int = to_remove[i]
		var marker: Dictionary = _markers[idx]
		var marker_node: Node2D = marker.get("node", null)
		if marker_node != null and is_instance_valid(marker_node):
			marker_node.queue_free()
		_markers.remove_at(idx)


func show_marker(world_pos: Vector2) -> void:
	var marker_node: Node2D = Node2D.new()
	marker_node.position = world_pos
	marker_node.name = "MoveMarker"
	_marker_layer.add_child(marker_node)

	marker_node.draw.connect(_draw_marker.bind(marker_node))

	var data: Dictionary = {
		"node": marker_node,
		"elapsed": 0.0,
		"ring_radius": MARKER_RADIUS,
		"alpha": 1.0,
	}
	_markers.append(data)


func _draw_marker(marker_node: Node2D) -> void:
	var idx: int = -1
	for i: int in range(_markers.size()):
		if _markers[i].get("node", null) == marker_node:
			idx = i
			break

	if idx == -1:
		return

	var marker: Dictionary = _markers[idx]
	var ring_radius: float = marker.get("ring_radius", MARKER_RADIUS)
	var alpha: float = marker.get("alpha", 1.0)

	var inner_color: Color = MARKER_COLOR
	inner_color.a = alpha * 0.6
	var ring_color: Color = MARKER_RING_COLOR
	ring_color.a = alpha * 0.8

	draw_circle(Vector2.ZERO, MARKER_RADIUS * 0.5, inner_color)
	draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 24, ring_color, 2.0)
