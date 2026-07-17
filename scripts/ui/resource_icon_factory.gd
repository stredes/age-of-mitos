class_name ResourceIconFactory
extends Node

static var _icon_cache: Dictionary = {}
static var _cache_initialized: bool = false

@export var icon_size: Vector2i = Vector2i(24, 24)
@export var outline_color: Color = Color(0.1, 0.1, 0.1, 1.0)
@export var scale: float = 1.0

func _ready() -> void:
	if not _cache_initialized:
		_initialize_cache()


func _initialize_cache() -> void:
	var resources = ["wood", "food", "stone", "gold", "population", "idle_villager", "town_center", "swordsman", "builder"]
	for res in resources:
		_icon_cache[res] = _generate_icon(res)
	_cache_initialized = true


func get_icon(resource_type: String) -> Texture2D:
	if not _icon_cache.has(resource_type):
		_icon_cache[resource_type] = _generate_icon(resource_type)
	return _icon_cache.get(resource_type, _generate_fallback())


func get_icon_image(resource_type: String) -> Image:
	var tex = get_icon(resource_type)
	return tex.get_image()


func _generate_icon(resource_type: String) -> ImageTexture:
	var img = Image.create(icon_size.x, icon_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match resource_type:
		"wood":
			_draw_wood(img)
		"food":
			_draw_food(img)
		"stone":
			_draw_stone(img)
		"gold":
			_draw_gold(img)
		"population":
			_draw_population(img)
		"idle_villager":
			_draw_idle_villager(img)
		"town_center":
			_draw_town_center(img)
		"swordsman":
			_draw_swordsman(img)
		"builder":
			_draw_builder(img)
		_:
			_draw_fallback(img)

	var tex = ImageTexture.create_from_image(img)
	return tex


func _draw_wood(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2

	var trunk_color = Color(0.55, 0.35, 0.15, 1.0)
	var trunk_dark = Color(0.35, 0.22, 0.08, 1.0)
	var trunk_light = Color(0.7, 0.45, 0.2, 1.0)
	var leaf_color = Color(0.2, 0.55, 0.15, 1.0)
	var leaf_dark = Color(0.12, 0.35, 0.08, 1.0)
	var leaf_light = Color(0.3, 0.7, 0.2, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy
			var dist = sqrt(dx * dx + dy * dy)

			if y > cy + 2:
				var trunk_w = max(3, size / 6)
				if abs(dx) < trunk_w:
					var t = (y - (cy + 2)) / (size - cy - 2)
					var c = trunk_dark.lerp(trunk_light, sin(t * 3.14 + x * 0.5) * 0.3 + 0.5)
					img.set_pixel(x, y, c)
				continue

			var leaf_radius = size * 0.42
			var noise = sin(x * 1.2) * cos(y * 1.2) * 2.0
			if dist < leaf_radius + noise:
				var t = dist / leaf_radius
				var c = leaf_dark.lerp(leaf_light, 1.0 - t * 0.7)
				img.set_pixel(x, y, c)

	_draw_outline(img, outline_color)


func _draw_food(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2

	var wheat_color = Color(0.85, 0.72, 0.25, 1.0)
	var wheat_dark = Color(0.65, 0.52, 0.12, 1.0)
	var wheat_light = Color(0.95, 0.85, 0.4, 1.0)
	var stem_color = Color(0.3, 0.55, 0.2, 1.0)
	var stem_dark = Color(0.18, 0.35, 0.12, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy

			var stem_w = max(1, size / 16)
			if abs(dx) < stem_w and y > cy - 2:
				var t = (y - (cy - 2)) / (size - cy + 2)
				var c = stem_color.lerp(stem_dark, t * 0.5)
				img.set_pixel(x, y, c)
				continue

			var head_radius = size * 0.3
			var grain_x = int(x / 2) * 2
			var grain_y = int(y / 2) * 2
			if (grain_x + grain_y) % 4 == 0:
				var dist = sqrt(dx * dx + dy * dy)
				if dist < head_radius:
					var t = dist / head_radius
					var c = wheat_dark.lerp(wheat_light, 1.0 - t * 0.6)
					img.set_pixel(x, y, c)

	for y in range(cy - 4, size):
		for x in range(max(0, cx - 5), min(size, cx + 6)):
			if (x + y) % 3 == 0:
				var t = (y - (cy - 4)) / (size - cy + 4)
				var c = wheat_color.lerp(wheat_light, sin(t * 6.28 + x) * 0.3 + 0.5)
				img.set_pixel(x, y, c)

	_draw_outline(img, outline_color)


func _draw_stone(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2

	var stone_base = Color(0.45, 0.45, 0.48, 1.0)
	var stone_dark = Color(0.25, 0.25, 0.28, 1.0)
	var stone_light = Color(0.6, 0.6, 0.63, 1.0)
	var crack_color = Color(0.18, 0.18, 0.2, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy
			var dist = sqrt(dx * dx + dy * dy)

			var radius = size * 0.42
			if dist < radius:
				var noise = sin(x * 0.8) * cos(y * 0.8) * 0.15
				var t = dist / radius
				var c = stone_base.lerp(stone_dark, t * 0.6 + noise)
				img.set_pixel(x, y, c)

				if (x + y * 7) % 17 == 0 and dist < radius * 0.8:
					img.set_pixel(x, y, crack_color)
				if (x * 3 - y * 5) % 13 == 0 and dist > radius * 0.3:
					var h = sin(x * 0.5 + y * 0.3) * 0.1
					img.set_pixel(x, y, stone_base.lerp(stone_light, 0.3 + h))

	_draw_outline(img, outline_color)


func _draw_gold(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2

	var gold_base = Color(0.95, 0.75, 0.15, 1.0)
	var gold_dark = Color(0.65, 0.48, 0.05, 1.0)
	var gold_light = Color(1.0, 0.92, 0.35, 1.0)
	var gold_shine = Color(1.0, 1.0, 0.7, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy
			var dist = sqrt(dx * dx + dy * dy)

			var radius = size * 0.4
			if dist < radius:
				var angle = atan2(dy, dx)
				var noise = sin(dist * 8.0 + angle * 3.0) * 0.12
				var t = dist / radius
				var shine = max(0.0, cos(angle - 0.785) * (1.0 - t) * 0.4)
				var c = gold_base.lerp(gold_dark, t * 0.7 + noise)
				c = c.lerp(gold_shine, shine)
				c = c.lerp(gold_light, max(0.0, 0.3 - t * 0.3))
				img.set_pixel(x, y, c)

	_draw_outline(img, outline_color)


func _draw_population(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2

	var person_color = Color(0.3, 0.5, 0.8, 1.0)
	var person_dark = Color(0.15, 0.3, 0.55, 1.0)
	var person_light = Color(0.5, 0.7, 1.0, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy

			var head_r = size * 0.18
			var head_y = cy - size * 0.25
			var head_dist = sqrt(dx * dx + (y - head_y) * (y - head_y))
			if head_dist < head_r:
				var t = head_dist / head_r
				var c = person_dark.lerp(person_light, 1.0 - t * 0.5)
				img.set_pixel(x, y, c)

			var body_top = cy - size * 0.1
			var body_bottom = cy + size * 0.35
			var body_w = size * 0.25
			if y > body_top and y < body_bottom and abs(dx) < body_w:
				var t = (y - body_top) / (body_bottom - body_top)
				var c = person_color.lerp(person_dark, t * 0.4)
				img.set_pixel(x, y, c)

	_draw_outline(img, outline_color)


func _draw_idle_villager(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2

	var person_color = Color(0.8, 0.7, 0.3, 1.0)
	var person_dark = Color(0.55, 0.45, 0.15, 1.0)
	var person_light = Color(0.95, 0.9, 0.5, 1.0)
	var zzz_color = Color(0.5, 0.7, 0.9, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy

			var head_r = size * 0.16
			var head_y = cy - size * 0.28
			var head_dist = sqrt(dx * dx + (y - head_y) * (y - head_y))
			if head_dist < head_r:
				var t = head_dist / head_r
				var c = person_dark.lerp(person_light, 1.0 - t * 0.5)
				img.set_pixel(x, y, c)

			var body_top = cy - size * 0.12
			var body_bottom = cy + size * 0.3
			var body_w = size * 0.22
			if y > body_top and y < body_bottom and abs(dx) < body_w:
				var t = (y - body_top) / (body_bottom - body_top)
				var c = person_color.lerp(person_dark, t * 0.4)
				img.set_pixel(x, y, c)

			if x > cx + size * 0.22 and y < cy - size * 0.1:
				var zx = x - (cx + size * 0.22)
				var zy = y - (cy - size * 0.1)
				if (zx + zy * 2) % 3 == 0:
					var z_dist = sqrt(zx * zx + zy * zy)
					if z_dist < size * 0.15:
						img.set_pixel(x, y, zzz_color)

	_draw_outline(img, outline_color)


func _draw_town_center(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2

	var roof_color = Color(0.55, 0.25, 0.15, 1.0)
	var roof_dark = Color(0.35, 0.15, 0.08, 1.0)
	var wall_color = Color(0.45, 0.4, 0.35, 1.0)
	var wall_dark = Color(0.3, 0.25, 0.2, 1.0)
	var door_color = Color(0.25, 0.15, 0.1, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy

			var roof_h = size * 0.35
			if y < cy - size * 0.15:
				var roof_w = size * 0.5 - (y - (cy - size * 0.15)) * 1.5
				if abs(dx) < roof_w:
					var t = (cy - size * 0.15 - y) / roof_h
					var c = roof_dark.lerp(roof_color, t * 0.5)
					img.set_pixel(x, y, c)

			if y >= cy - size * 0.15 and y < cy + size * 0.35:
				var wall_w = size * 0.42
				if abs(dx) < wall_w:
					var t = (y - (cy - size * 0.15)) / (size * 0.5)
					var c = wall_color.lerp(wall_dark, t * 0.4)
					if abs(dx) < size * 0.12 and y > cy + size * 0.05:
						c = door_color
					img.set_pixel(x, y, c)

	_draw_outline(img, outline_color)


func _draw_swordsman(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2

	var armor_color = Color(0.45, 0.45, 0.5, 1.0)
	var armor_dark = Color(0.25, 0.25, 0.3, 1.0)
	var armor_light = Color(0.6, 0.6, 0.65, 1.0)
	var sword_color = Color(0.7, 0.7, 0.75, 1.0)
	var sword_dark = Color(0.4, 0.4, 0.45, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy

			var head_r = size * 0.16
			var head_y = cy - size * 0.28
			var head_dist = sqrt(dx * dx + (y - head_y) * (y - head_y))
			if head_dist < head_r:
				var t = head_dist / head_r
				var c = armor_dark.lerp(armor_light, 1.0 - t * 0.5)
				img.set_pixel(x, y, c)

			var body_top = cy - size * 0.1
			var body_bottom = cy + size * 0.3
			var body_w = size * 0.25
			if y > body_top and y < body_bottom and abs(dx) < body_w:
				var t = (y - body_top) / (body_bottom - body_top)
				var c = armor_color.lerp(armor_dark, t * 0.4)
				img.set_pixel(x, y, c)

			if x > cx and y < cy + size * 0.1 and y > cy - size * 0.25:
				if abs(x - cx - size * 0.1) < 1.5:
					var t = (y - (cy - size * 0.25)) / (size * 0.35)
					var c = sword_color.lerp(sword_dark, t * 0.3)
					img.set_pixel(x, y, c)

	_draw_outline(img, outline_color)


func _draw_builder(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2

	var body_color = Color(0.35, 0.55, 0.3, 1.0)
	var body_dark = Color(0.2, 0.35, 0.18, 1.0)
	var body_light = Color(0.5, 0.75, 0.4, 1.0)
	var hammer_color = Color(0.55, 0.35, 0.2, 1.0)
	var hammer_dark = Color(0.35, 0.22, 0.1, 1.0)
	var hammer_head = Color(0.5, 0.5, 0.55, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy

			var head_r = size * 0.16
			var head_y = cy - size * 0.28
			var head_dist = sqrt(dx * dx + (y - head_y) * (y - head_y))
			if head_dist < head_r:
				var t = head_dist / head_r
				var c = body_dark.lerp(body_light, 1.0 - t * 0.5)
				img.set_pixel(x, y, c)

			var body_top = cy - size * 0.1
			var body_bottom = cy + size * 0.3
			var body_w = size * 0.25
			if y > body_top and y < body_bottom and abs(dx) < body_w:
				var t = (y - body_top) / (body_bottom - body_top)
				var c = body_color.lerp(body_dark, t * 0.4)
				img.set_pixel(x, y, c)

			if x < cx - size * 0.1 and y < cy + size * 0.1 and y > cy - size * 0.15:
				var hx = x - (cx - size * 0.1)
				var hy = y - (cy - size * 0.15)
				if abs(hx) < 1.5 and abs(hy) < size * 0.2:
					var t = (hy + size * 0.15) / (size * 0.2)
					var c = hammer_color.lerp(hammer_dark, t * 0.3)
					img.set_pixel(x, y, c)
				if abs(hx - size * 0.15) < 2.5 and hy < size * 0.1:
					img.set_pixel(x, y, hammer_head)

	_draw_outline(img, outline_color)


func _draw_fallback(img: Image) -> void:
	var size = icon_size.x
	var cx = size / 2
	var cy = size / 2
	var color = Color(0.5, 0.5, 0.5, 1.0)

	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy
			if dx * dx + dy * dy < (size * 0.35) * (size * 0.35):
				img.set_pixel(x, y, color)

	_draw_outline(img, outline_color)


func _draw_outline(img: Image, color: Color) -> void:
	var size = icon_size.x
	for x in range(size):
		for y in range(size):
			var has_neighbor = false
			for nx in range(max(0, x-1), min(size, x+2)):
				for ny in range(max(0, y-1), min(size, y+2)):
					if img.get_pixel(nx, ny).a > 0.5:
						has_neighbor = true
						break
				if has_neighbor:
					break
			if img.get_pixel(x, y).a == 0.0 and has_neighbor:
				img.set_pixel(x, y, color)


func _generate_fallback() -> ImageTexture:
	var img = Image.create(icon_size.x, icon_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	return ImageTexture.create_from_image(img)


func clear_cache() -> void:
	_icon_cache.clear()
	_cache_initialized = false
	_initialize_cache()