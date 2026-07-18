## Procedural portrait widget for the selection panel.
## Displays a 64x64 unit portrait with player color and category shape:
##   - Workers (civil): square frame
##   - Military (infantry, ranged, cavalry, siege): triangle frame
class_name SelectionPortrait
extends Control

const ProceduralSpriteFactory = preload("res://scripts/animation/procedural_sprite_factory.gd")

const PORTRAIT_SIZE: int = 64
const BORDER_THICKNESS: int = 3
const INNER_MARGIN: int = 6

var _unit_type: String = ""
var _player_id: int = 0
var _texture_rect: TextureRect = null


func _ready() -> void:
	custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)


func set_portrait(unit_type: String, player_id: int) -> void:
	_unit_type = unit_type
	_player_id = player_id
	_rebuild()


func clear_portrait() -> void:
	_unit_type = ""
	_player_id = 0
	if _texture_rect != null:
		_texture_rect.texture = null


func _rebuild() -> void:
	if _unit_type.is_empty():
		if _texture_rect != null:
			_texture_rect.texture = null
		return

	var img: Image = Image.create(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var p_color: Color = _player_color(_player_id)
	var is_worker: bool = _is_worker(_unit_type)

	if is_worker:
		_draw_square_frame(img, p_color)
	else:
		_draw_triangle_frame(img, p_color)

	var unit_tex: Texture2D = ProceduralSpriteFactory.get_unit_preview(_unit_type, _player_id)
	if unit_tex != null:
		var unit_img: Image = unit_tex.get_image()
		if unit_img != null:
			var scale_f: float = float(PORTRAIT_SIZE - INNER_MARGIN * 2) / float(maxi(unit_img.get_width(), unit_img.get_height()))
			var dst_size: int = maxi(int(float(unit_img.get_width()) * scale_f), 1)
			var resized: Image = unit_img.resize(dst_size, dst_size, Image.INTERPOLATE_LANCZOS)
			var ox: int = int((PORTRAIT_SIZE - resized.get_width()) / 2)
			var oy: int = int((PORTRAIT_SIZE - resized.get_height()) / 2)
			img.blit_rect(resized, Rect2i(0, 0, resized.get_width(), resized.get_height()), Vector2i(ox, oy))

	if _texture_rect != null:
		_texture_rect.texture = ImageTexture.create_from_image(img)


func _draw_square_frame(img: Image, color: Color) -> void:
	var corner_r: int = 6
	var body_color: Color = color.darkened(0.35)
	body_color.a = 0.55

	_fill_rounded_rect(img, Rect2i(0, 0, PORTRAIT_SIZE, PORTRAIT_SIZE), body_color, corner_r)

	var border_color: Color = color.lerp(Color.WHITE, 0.15)
	_stroke_rounded_rect(img, Rect2i(0, 0, PORTRAIT_SIZE, PORTRAIT_SIZE), border_color, corner_r, BORDER_THICKNESS)

	var inner: int = PORTRAIT_SIZE - BORDER_THICKNESS * 2
	_stroke_rounded_rect(img, Rect2i(BORDER_THICKNESS, BORDER_THICKNESS, inner, inner), border_color, maxi(corner_r - BORDER_THICKNESS, 0), 1)


func _draw_triangle_frame(img: Image, color: Color) -> void:
	var body_color: Color = color.darkened(0.35)
	body_color.a = 0.55
	var border_color: Color = color.lerp(Color.WHITE, 0.15)

	var margin: int = 4
	var top: Vector2i = Vector2i(PORTRAIT_SIZE / 2, margin)
	var bl: Vector2i = Vector2i(margin, PORTRAIT_SIZE - margin)
	var br: Vector2i = Vector2i(PORTRAIT_SIZE - margin, PORTRAIT_SIZE - margin)

	_fill_triangle(img, top, bl, br, body_color)
	_stroke_triangle(img, top, bl, br, border_color, BORDER_THICKNESS)


func _fill_triangle(img: Image, a: Vector2i, b: Vector2i, c: Vector2i, color: Color) -> void:
	var min_x: int = mini(a.x, mini(b.x, c.x))
	var max_x: int = maxi(a.x, maxi(b.x, c.x))
	var min_y: int = mini(a.y, mini(b.y, c.y))
	var max_y: int = maxi(a.y, maxi(b.y, c.y))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_triangle(Vector2i(x, y), a, b, c):
				_safe_pixel(img, x, y, color)


func _stroke_triangle(img: Image, a: Vector2i, b: Vector2i, c: Vector2i, color: Color, thickness: int) -> void:
	_draw_thick_line(img, a, b, color, thickness)
	_draw_thick_line(img, b, c, color, thickness)
	_draw_thick_line(img, c, a, color, thickness)


func _point_in_triangle(p: Vector2i, a: Vector2i, b: Vector2i, c: Vector2i) -> bool:
	var v0: Vector2i = c - a
	var v1: Vector2i = b - a
	var v2: Vector2i = p - a
	var dot00: int = v0.dot(v0)
	var dot01: int = v0.dot(v1)
	var dot02: int = v0.dot(v2)
	var dot11: int = v1.dot(v1)
	var dot12: int = v1.dot(v2)
	var inv: float = 1.0 / float(dot00 * dot11 - dot01 * dot01)
	var u: float = float(dot11 * dot02 - dot01 * dot12) * inv
	var v: float = float(dot00 * dot12 - dot01 * dot02) * inv
	return u >= 0.0 and v >= 0.0 and u + v <= 1.0


func _fill_rounded_rect(img: Image, rect: Rect2i, color: Color, radius: int) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if _in_rounded_rect(Vector2i(x, y), rect, radius):
				_safe_pixel(img, x, y, color)


func _stroke_rounded_rect(img: Image, rect: Rect2i, color: Color, radius: int, thickness: int) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if _in_rounded_rect_border(Vector2i(x, y), rect, radius, thickness):
				_safe_pixel(img, x, y, color)


func _in_rounded_rect(p: Vector2i, rect: Rect2i, radius: int) -> bool:
	if not rect.has_point(p):
		return false
	if radius <= 0:
		return true

	var inner_left: int = rect.position.x + radius
	var inner_right: int = rect.position.x + rect.size.x - 1 - radius
	var inner_top: int = rect.position.y + radius
	var inner_bottom: int = rect.position.y + rect.size.y - 1 - radius

	if p.x >= inner_left and p.x <= inner_right and p.y >= inner_top and p.y <= inner_bottom:
		return true

	var corners: Array[Vector2i] = [
		Vector2i(inner_left, inner_top),
		Vector2i(inner_right, inner_top),
		Vector2i(inner_left, inner_bottom),
		Vector2i(inner_right, inner_bottom),
	]
	for corner: Vector2i in corners:
		var dx: float = float(p.x - corner.x)
		var dy: float = float(p.y - corner.y)
		if dx * dx + dy * dy <= float(radius * radius):
			return true
	return false


func _in_rounded_rect_border(p: Vector2i, rect: Rect2i, radius: int, thickness: int) -> bool:
	return _in_rounded_rect(p, rect, radius) and not _in_rounded_rect(p, rect.grow(-thickness), maxi(radius - thickness, 0))


func _draw_thick_line(img: Image, a: Vector2i, b: Vector2i, color: Color, thickness: int) -> void:
	var diff: Vector2 = Vector2(b - a)
	var length: float = diff.length()
	if length < 0.5:
		_fill_circle(img, a, int(thickness / 2) + 1, color)
		return
	var steps: int = maxi(int(length), 1)
	var half_t: int = int(thickness / 2)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var px: int = roundi(lerpf(float(a.x), float(b.x), t))
		var py: int = roundi(lerpf(float(a.y), float(b.y), t))
		for dy in range(-half_t, half_t + 1):
			for dx in range(-half_t, half_t + 1):
				_safe_pixel(img, px + dx, py + dy, color)


func _fill_circle(img: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if (x - center.x) * (x - center.x) + (y - center.y) * (y - center.y) <= radius * radius:
				_safe_pixel(img, x, y, color)


func _safe_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)


func _is_worker(unit_type: String) -> bool:
	var data: Dictionary = DataManager.get_unit_data(unit_type)
	if data.is_empty():
		return false
	var category: String = data.get("unit_category", "")
	if category == "civil":
		return true
	return data.get("gather_rate", null) != null


func _player_color(pid: int) -> Color:
	match pid:
		1:
			return Color(0.18, 0.40, 0.94)
		2:
			return Color(0.84, 0.18, 0.14)
		3:
			return Color(0.16, 0.62, 0.24)
		4:
			return Color(0.85, 0.72, 0.18)
		_:
			return Color(0.72, 0.56, 0.24)
