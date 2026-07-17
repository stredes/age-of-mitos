## Centralized factory for procedural pixel-art icons.
##
## Every UI component calls ResourceIconFactory.get_icon("wood", 16)
## instead of duplicating draw code. Icons are cached by type+size.
extends Node

# =============================================================================
# Cache
# =============================================================================

var _cache: Dictionary = {}

# =============================================================================
# Public API
# =============================================================================

## Get a procedural icon texture. Returns cached version if available.
func get_icon(type: String, size: int = 16) -> ImageTexture:
	var key: String = "%s_%d" % [type, size]
	if key in _cache:
		return _cache[key]
	var tex: ImageTexture = _generate_icon(type, size)
	_cache[key] = tex
	return tex


## Clear the icon cache (call if you need to regenerate).
func clear_cache() -> void:
	_cache.clear()


# =============================================================================
# Icon Generation Router
# =============================================================================

func _generate_icon(type: String, size: int) -> ImageTexture:
	match type:
		"wood":
			return _draw_wood(size)
		"stone":
			return _draw_stone(size)
		"food":
			return _draw_food(size)
		"gold":
			return _draw_gold(size)
		"idle_villager":
			return _draw_idle_villager(size)
		"town_center":
			return _draw_town_center(size)
		"army":
			return _draw_army(size)
		"population":
			return _draw_population(size)
		"alert":
			return _draw_alert(size)
		"build":
			return _draw_build(size)
		"attack":
			return _draw_attack(size)
		"move":
			return _draw_move(size)
		"stop":
			return _draw_stop(size)
		"chop":
			return _draw_chop(size)
		"mine":
			return _draw_mine(size)
		"repair":
			return _draw_repair(size)
		"garrison":
			return _draw_garrison(size)
		_:
			return _draw_placeholder(size)


# =============================================================================
# Resource Icons
# =============================================================================

func _draw_wood(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var trunk: Color = Color(0.45, 0.25, 0.08)
	var leaves: Color = Color(0.15, 0.55, 0.12)
	var leaves2: Color = Color(0.2, 0.65, 0.15)
	var cx: float = s * 0.5
	var trunk_w: float = maxf(s * 0.12, 1.0)
	for y in range(int(s * 0.5), int(s * 0.87)):
		for dx in range(int(-trunk_w), int(trunk_w) + 1):
			var px: int = clampi(int(cx + dx), 0, s - 1)
			img.set_pixel(px, y, trunk)
	for y in range(int(s * 0.25), int(s * 0.56)):
		for x in range(int(s * 0.25), int(s * 0.75)):
			var dx2: float = x - cx
			var dy2: float = y - s * 0.38
			if dx2 * dx2 / (s * 0.22 * s * 0.22) + dy2 * dy2 / (s * 0.14 * s * 0.14) <= 1.0:
				img.set_pixel(x, y, leaves2 if (x + y) % 3 == 0 else leaves)
	return ImageTexture.create_from_image(img)


func _draw_stone(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var stone: Color = Color(0.55, 0.55, 0.58)
	var stone_lt: Color = Color(0.68, 0.68, 0.7)
	var stone_dk: Color = Color(0.4, 0.4, 0.42)
	var pts: Array[Vector2i] = [
		Vector2i(int(s * 0.25), int(s * 0.62)),
		Vector2i(int(s * 0.19), int(s * 0.5)),
		Vector2i(int(s * 0.25), int(s * 0.31)),
		Vector2i(int(s * 0.37), int(s * 0.19)),
		Vector2i(int(s * 0.56), int(s * 0.19)),
		Vector2i(int(s * 0.69), int(s * 0.31)),
		Vector2i(int(s * 0.75), int(s * 0.5)),
		Vector2i(int(s * 0.69), int(s * 0.62)),
		Vector2i(int(s * 0.5), int(s * 0.75)),
		Vector2i(int(s * 0.31), int(s * 0.69)),
	]
	for y in range(s):
		for x in range(s):
			if _point_in_poly(Vector2i(x, y), pts):
				img.set_pixel(x, y, stone)
	for y in range(int(s * 0.31), int(s * 0.5)):
		for x in range(int(s * 0.31), int(s * 0.62)):
			if _point_in_poly(Vector2i(x, y), pts):
				img.set_pixel(x, y, stone_lt)
	for y in range(int(s * 0.56), int(s * 0.75)):
		for x in range(int(s * 0.25), int(s * 0.75)):
			if _point_in_poly(Vector2i(x, y), pts):
				img.set_pixel(x, y, stone_dk)
	return ImageTexture.create_from_image(img)


func _draw_food(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var meat: Color = Color(0.75, 0.25, 0.1)
	var meat_lt: Color = Color(0.88, 0.35, 0.15)
	var bone: Color = Color(0.92, 0.88, 0.78)
	var cx: float = s * 0.5
	var cy: float = s * 0.56
	var rx: float = s * 0.25
	var ry: float = s * 0.19
	for y in range(s):
		for x in range(s):
			var dx: float = (x - cx) / rx
			var dy: float = (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, meat_lt if y < int(cy) else meat)
	# Bone ends.
	var bx: int = clampi(int(cx + rx + 1), 0, s - 1)
	var by: int = clampi(int(cy), 0, s - 1)
	for i in range(-1, 2):
		if by + i >= 0 and by + i < s and bx < s:
			img.set_pixel(bx, by + i, bone)
	if bx + 1 < s:
		img.set_pixel(bx + 1, by, bone)
	var lx: int = clampi(int(cx - rx - 1), 0, s - 1)
	for i in range(-1, 2):
		if by + i >= 0 and by + i < s and lx >= 0:
			img.set_pixel(lx, by + i, bone)
	if lx - 1 >= 0:
		img.set_pixel(lx - 1, by, bone)
	return ImageTexture.create_from_image(img)


func _draw_gold(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var gold: Color = Color(1.0, 0.82, 0.0)
	var gold_dk: Color = Color(0.85, 0.65, 0.0)
	var gold_lt: Color = Color(1.0, 0.92, 0.3)
	var cx: float = s * 0.5 - 0.5
	var cy: float = s * 0.5 - 0.5
	var r_outer: float = s * 0.44
	var r_mid: float = s * 0.31
	var r_inner: float = s * 0.22
	for y in range(s):
		for x in range(s):
			var d: float = sqrtf((x - cx) * (x - cx) + (y - cy) * (y - cy))
			if d <= r_outer:
				if d <= r_inner:
					img.set_pixel(x, y, gold_lt)
				elif d <= r_mid:
					img.set_pixel(x, y, gold_dk)
				else:
					img.set_pixel(x, y, gold)
	# Cross pattern.
	var cross_w: int = maxi(int(s * 0.08), 1)
	for i in range(-cross_w, cross_w + 1):
		var px: int = clampi(int(cx + i), 0, s - 1)
		for y in range(int(s * 0.31), int(s * 0.69)):
			if img.get_pixel(px, y).a > 0.0:
				img.set_pixel(px, y, gold_dk)
		var py: int = clampi(int(cy + i), 0, s - 1)
		for x in range(int(s * 0.31), int(s * 0.69)):
			if img.get_pixel(x, py).a > 0.0:
				img.set_pixel(x, py, gold_dk)
	return ImageTexture.create_from_image(img)


# =============================================================================
# UI Icons
# =============================================================================

func _draw_idle_villager(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var skin: Color = Color(0.85, 0.65, 0.45)
	var shirt: Color = Color(0.3, 0.5, 0.7)
	var pants: Color = Color(0.4, 0.3, 0.2)
	var cx: int = int(s * 0.5)
	# Head.
	var head_r: int = maxi(int(s * 0.14), 1)
	for y in range(s):
		for x in range(s):
			if sqrtf(float((x - cx) * (x - cx) + (y - int(s * 0.22)) * (y - int(s * 0.22)))) <= float(head_r):
				img.set_pixel(x, y, skin)
	# Body.
	var body_top: int = int(s * 0.35)
	var body_bot: int = int(s * 0.65)
	var body_w: int = maxi(int(s * 0.14), 1)
	for y in range(body_top, body_bot):
		for dx in range(-body_w, body_w + 1):
			var px: int = clampi(cx + dx, 0, s - 1)
			img.set_pixel(px, y, shirt)
	# Legs.
	var leg_top: int = body_bot
	var leg_bot: int = clampi(int(s * 0.88), 0, s - 1)
	for y in range(leg_top, leg_bot):
		img.set_pixel(clampi(cx - 1, 0, s - 1), y, pants)
		img.set_pixel(clampi(cx + 1, 0, s - 1), y, pants)
	# Question mark (idle indicator).
	if s >= 12:
		var q_color: Color = Color(1.0, 0.9, 0.2, 0.9)
		img.set_pixel(clampi(cx + int(s * 0.22), 0, s - 1), clampi(int(s * 0.12), 0, s - 1), q_color)
		img.set_pixel(clampi(cx + int(s * 0.28), 0, s - 1), clampi(int(s * 0.12), 0, s - 1), q_color)
		img.set_pixel(clampi(cx + int(s * 0.31), 0, s - 1), clampi(int(s * 0.16), 0, s - 1), q_color)
	return ImageTexture.create_from_image(img)


func _draw_town_center(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var wall: Color = Color(0.65, 0.5, 0.3)
	var roof: Color = Color(0.55, 0.2, 0.1)
	var door: Color = Color(0.35, 0.2, 0.08)
	var cx: float = s * 0.5
	# Roof triangle.
	for y in range(int(s * 0.12), int(s * 0.4)):
		var w: float = (y - s * 0.12) * (s * 0.45) / (s * 0.28)
		for x in range(s):
			if absf(x - cx) <= w:
				img.set_pixel(x, y, roof)
	# Walls.
	var wall_l: int = int(s * 0.22)
	var wall_r: int = int(s * 0.78)
	for y in range(int(s * 0.4), int(s * 0.82)):
		for x in range(wall_l, wall_r):
			img.set_pixel(x, y, wall)
	# Door.
	var door_w: int = maxi(int(s * 0.1), 1)
	var door_top: int = int(s * 0.56)
	var door_bot: int = int(s * 0.82)
	for y in range(door_top, door_bot):
		for dx in range(-door_w, door_w + 1):
			var px: int = clampi(int(cx + dx), 0, s - 1)
			img.set_pixel(px, y, door)
	return ImageTexture.create_from_image(img)


func _draw_army(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var blade: Color = Color(0.75, 0.75, 0.8)
	var handle: Color = Color(0.45, 0.3, 0.1)
	var guard: Color = Color(0.7, 0.6, 0.2)
	var cx: int = int(s * 0.5)
	# Blade.
	for y in range(int(s * 0.08), int(s * 0.55)):
		var w: float = maxf((1.0 - float(y) / (s * 0.55)) * s * 0.12, 0.5)
		for dx in range(int(-w), int(w) + 1):
			var px: int = clampi(cx + dx, 0, s - 1)
			img.set_pixel(px, y, blade)
	# Guard.
	var guard_y: int = int(s * 0.55)
	for dx in range(int(-s * 0.16), int(s * 0.16) + 1):
		var px: int = clampi(cx + dx, 0, s - 1)
		if guard_y >= 0 and guard_y < s:
			img.set_pixel(px, guard_y, guard)
	# Handle.
	for y in range(int(s * 0.58), int(s * 0.85)):
		var px: int = clampi(cx, 0, s - 1)
		if y >= 0 and y < s:
			img.set_pixel(px, y, handle)
	return ImageTexture.create_from_image(img)


func _draw_population(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var skin: Color = Color(0.85, 0.65, 0.45)
	var body: Color = Color(0.4, 0.55, 0.7)
	var cx: float = s * 0.5
	# Head 1 (left).
	var h1x: float = s * 0.35
	var h1y: float = s * 0.22
	var hr: float = s * 0.12
	for y in range(s):
		for x in range(s):
			if sqrtf(float((x - h1x) * (x - h1x) + (y - h1y) * (y - h1y))) <= hr:
				img.set_pixel(x, y, skin)
	# Head 2 (right, slightly behind).
	var h2x: float = s * 0.65
	var h2y: float = s * 0.25
	for y in range(s):
		for x in range(s):
			if sqrtf(float((x - h2x) * (x - h2x) + (y - h2y) * (y - h2y))) <= hr * 0.85:
				img.set_pixel(x, y, skin)
	# Body 1.
	for y in range(int(s * 0.35), int(s * 0.7)):
		for dx in range(int(-s * 0.12), int(s * 0.12) + 1):
			var px: int = clampi(int(h1x + dx), 0, s - 1)
			img.set_pixel(px, y, body)
	# Body 2.
	for y in range(int(s * 0.38), int(s * 0.7)):
		for dx in range(int(-s * 0.1), int(s * 0.1) + 1):
			var px: int = clampi(int(h2x + dx), 0, s - 1)
			img.set_pixel(px, y, body)
	return ImageTexture.create_from_image(img)


func _draw_alert(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var red: Color = Color(0.9, 0.15, 0.15)
	var white: Color = Color(1.0, 1.0, 1.0)
	var cx: float = s * 0.5
	# Triangle background.
	for y in range(int(s * 0.12), int(s * 0.88)):
		var w: float = (float(y) - s * 0.12) * (s * 0.42) / (s * 0.76)
		if y > s * 0.5:
			w = (s * 0.88 - float(y)) * (s * 0.42) / (s * 0.38)
		for x in range(s):
			if absf(x - cx) <= w:
				img.set_pixel(x, y, red)
	# Exclamation mark.
	var ex: int = clampi(int(cx), 0, s - 1)
	for y in range(int(s * 0.28), int(s * 0.56)):
		img.set_pixel(ex, y, white)
	img.set_pixel(ex, clampi(int(s * 0.65), 0, s - 1), white)
	img.set_pixel(ex, clampi(int(s * 0.72), 0, s - 1), white)
	return ImageTexture.create_from_image(img)


func _draw_build(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var wood: Color = Color(0.55, 0.35, 0.12)
	var metal: Color = Color(0.65, 0.65, 0.7)
	# Hammer handle.
	for y in range(int(s * 0.3), int(s * 0.8)):
		var px: int = clampi(int(s * 0.4), 0, s - 1)
		img.set_pixel(px, y, wood)
		img.set_pixel(clampi(px + 1, 0, s - 1), y, wood)
	# Hammer head.
	for y in range(int(s * 0.15), int(s * 0.35)):
		for x in range(int(s * 0.25), int(s * 0.65)):
			img.set_pixel(x, y, metal)
	return ImageTexture.create_from_image(img)


func _draw_attack(s: int) -> ImageTexture:
	return _draw_army(s)


func _draw_move(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var arrow: Color = Color(0.3, 0.8, 0.3)
	var cx: float = s * 0.5
	# Arrow shaft.
	for y in range(int(s * 0.35), int(s * 0.75)):
		var px: int = clampi(int(cx), 0, s - 1)
		img.set_pixel(px, y, arrow)
		img.set_pixel(clampi(px + 1, 0, s - 1), y, arrow)
	# Arrow head.
	for y in range(int(s * 0.15), int(s * 0.35)):
		var w: float = (float(y) - s * 0.15) * (s * 0.25) / (s * 0.2)
		for dx in range(int(-w), int(w) + 1):
			var px: int = clampi(int(cx + dx), 0, s - 1)
			img.set_pixel(px, y, arrow)
	return ImageTexture.create_from_image(img)


func _draw_stop(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var red: Color = Color(0.85, 0.15, 0.15)
	var cx: float = s * 0.5
	var cy: float = s * 0.5
	var r: float = s * 0.38
	for y in range(s):
		for x in range(s):
			var d: float = sqrtf(float((x - cx) * (x - cx) + (y - cy) * (y - cy)))
			if d <= r and d > r - s * 0.1:
				img.set_pixel(x, y, red)
	return ImageTexture.create_from_image(img)


func _draw_chop(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var handle: Color = Color(0.5, 0.3, 0.1)
	var blade: Color = Color(0.6, 0.6, 0.65)
	# Handle diagonal.
	for i in range(int(s * 0.2), int(s * 0.75)):
		var px: int = clampi(int(s * 0.3 + i * 0.3), 0, s - 1)
		var py: int = clampi(i, 0, s - 1)
		img.set_pixel(px, py, handle)
	# Blade.
	for y in range(int(s * 0.1), int(s * 0.35)):
		for x in range(int(s * 0.5), int(s * 0.8)):
			img.set_pixel(x, y, blade)
	return ImageTexture.create_from_image(img)


func _draw_mine(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var handle: Color = Color(0.5, 0.3, 0.1)
	var head: Color = Color(0.55, 0.55, 0.6)
	# Handle.
	for y in range(int(s * 0.3), int(s * 0.8)):
		var px: int = clampi(int(s * 0.5), 0, s - 1)
		img.set_pixel(px, y, handle)
	# Pickaxe head.
	for y in range(int(s * 0.1), int(s * 0.3)):
		for x in range(int(s * 0.2), int(s * 0.8)):
			if absf(x - s * 0.5) < s * 0.3:
				img.set_pixel(x, y, head)
	return ImageTexture.create_from_image(img)


func _draw_repair(s: int) -> ImageTexture:
	return _draw_build(s)


func _draw_garrison(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var wall: Color = Color(0.6, 0.5, 0.35)
	var door: Color = Color(0.3, 0.2, 0.08)
	# Building outline.
	for y in range(int(s * 0.25), int(s * 0.85)):
		img.set_pixel(clampi(int(s * 0.2), 0, s - 1), y, wall)
		img.set_pixel(clampi(int(s * 0.8), 0, s - 1), y, wall)
	for x in range(int(s * 0.2), int(s * 0.8) + 1):
		img.set_pixel(x, clampi(int(s * 0.25), 0, s - 1), wall)
	# Door opening.
	for y in range(int(s * 0.5), int(s * 0.85)):
		for x in range(int(s * 0.38), int(s * 0.62)):
			img.set_pixel(x, y, door)
	# Arrow into door.
	var arrow_y: int = int(s * 0.4)
	for x in range(int(s * 0.35), int(s * 0.65)):
		img.set_pixel(x, arrow_y, Color(0.3, 0.8, 0.3))
	return ImageTexture.create_from_image(img)


func _draw_placeholder(s: int) -> ImageTexture:
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.35))
	var border: Color = Color(0.5, 0.5, 0.55)
	for x in range(s):
		img.set_pixel(x, 0, border)
		img.set_pixel(x, s - 1, border)
	for y in range(s):
		img.set_pixel(0, y, border)
		img.set_pixel(s - 1, y, border)
	return ImageTexture.create_from_image(img)


# =============================================================================
# Geometry Helper
# =============================================================================

func _point_in_poly(point: Vector2i, polygon: Array[Vector2i]) -> bool:
	var inside: bool = false
	var n: int = polygon.size()
	var j: int = n - 1
	for i in range(n):
		var pi: Vector2i = polygon[i]
		var pj: Vector2i = polygon[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
			(point.x < (pj.x - pi.x) * (point.y - pi.y) / float(pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside
