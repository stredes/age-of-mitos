class_name ProceduralSpriteFactory
extends RefCounted

const TRANSPARENT: Color = Color(0, 0, 0, 0)
const OUTLINE: Color = Color(0.08, 0.06, 0.04, 1.0)
const SKIN: Color = Color(0.86, 0.62, 0.38, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.24)

static func create_unit_frames(unit_type: String, player_id: int) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")

	_add_unit_animation(frames, "idle", unit_type, player_id, 4, 4.0)
	_add_unit_animation(frames, "walk", unit_type, player_id, 6, 9.0)
	_add_unit_animation(frames, "run", unit_type, player_id, 6, 12.0)
	_add_unit_animation(frames, "attack", unit_type, player_id, 5, 8.0, false)
	_add_unit_animation(frames, "build", unit_type, player_id, 4, 6.0)
	_add_unit_animation(frames, "carry", unit_type, player_id, 4, 6.0)
	_add_unit_animation(frames, "hurt", unit_type, player_id, 2, 8.0, false)
	_add_unit_animation(frames, "death", unit_type, player_id, 5, 5.0, false)
	_add_unit_animation(frames, "celebrate", unit_type, player_id, 6, 8.0, false)
	_add_unit_animation(frames, "sleep", unit_type, player_id, 4, 2.0)
	_add_unit_animation(frames, "fear", unit_type, player_id, 4, 9.0)
	_add_unit_animation(frames, "victory", unit_type, player_id, 6, 8.0, false)
	_add_unit_animation(frames, "harvest", unit_type, player_id, 4, 7.0)
	_add_unit_animation(frames, "mine", unit_type, player_id, 4, 7.0)
	_add_unit_animation(frames, "harvest_axe", unit_type, player_id, 4, 7.0)
	_add_unit_animation(frames, "harvest_pickaxe", unit_type, player_id, 4, 7.0)
	_add_unit_animation(frames, "harvest_bend", unit_type, player_id, 4, 7.0)
	_add_unit_animation(frames, "harvest_shovel", unit_type, player_id, 4, 7.0)

	return frames


static func create_building_frames(building_type: String, player_id: int, grid_size: Vector2i) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")

	_add_building_animation(frames, "constructing", building_type, player_id, grid_size, 4, 4.0, false)
	_add_building_animation(frames, "construction", building_type, player_id, grid_size, 4, 4.0, false)
	_add_building_animation(frames, "active", building_type, player_id, grid_size, 4, 3.0)
	_add_building_animation(frames, "idle", building_type, player_id, grid_size, 4, 3.0)
	_add_building_animation(frames, "producing", building_type, player_id, grid_size, 4, 5.0)
	_add_building_animation(frames, "damaged", building_type, player_id, grid_size, 2, 2.0)
	_add_building_animation(frames, "burning", building_type, player_id, grid_size, 4, 6.0)
	_add_building_animation(frames, "destroyed", building_type, player_id, grid_size, 1, 1.0, false)

	return frames


static func _add_unit_animation(frames: SpriteFrames, anim: String, unit_type: String, player_id: int, count: int, speed: float, loop: bool = true) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, speed)
	frames.set_animation_loop(anim, loop)
	for frame in range(count):
		frames.add_frame(anim, _texture_from_image(_draw_unit(unit_type, player_id, anim, frame, count)))


static func _add_building_animation(frames: SpriteFrames, anim: String, building_type: String, player_id: int, grid_size: Vector2i, count: int, speed: float, loop: bool = true) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, speed)
	frames.set_animation_loop(anim, loop)
	for frame in range(count):
		frames.add_frame(anim, _texture_from_image(_draw_building(building_type, player_id, grid_size, anim, frame, count)))


static func _draw_unit(unit_type: String, player_id: int, anim: String, frame: int, count: int) -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)

	var player_color: Color = _player_color(player_id)
	var cloth: Color = player_color.lightened(0.08)
	var dark_cloth: Color = player_color.darkened(0.25)
	var phase: float = float(frame) / maxf(float(count), 1.0)
	var bob: int = 0
	if anim in ["walk", "run", "carry"]:
		bob = -1 if frame % 2 == 0 else 1
	elif anim == "idle":
		bob = -1 if frame == 1 else 0
	elif anim.begins_with("harvest") or anim == "build" or anim == "mine":
		bob = 1 if frame % 2 == 1 else 0

	if anim == "death" or anim == "sleep":
		var fall_x: int = mini(frame * 3, 10)
		_ellipse(img, Vector2i(16, 27), Vector2i(10, 3), SHADOW)
		_rect(img, Rect2i(10 + fall_x, 20, 13, 5), dark_cloth)
		_rect(img, Rect2i(8 + fall_x, 18, 5, 5), SKIN)
		_line(img, Vector2i(11 + fall_x, 17), Vector2i(4 + fall_x, 21), OUTLINE)
		if anim == "sleep":
			_rect(img, Rect2i(23, 12 - frame % 2, 2, 2), Color(0.70, 0.84, 1.0, 0.9))
			_rect(img, Rect2i(27, 8 - frame % 2, 3, 3), Color(0.70, 0.84, 1.0, 0.7))
		return img

	_ellipse(img, Vector2i(16, 27), Vector2i(8, 3), SHADOW)

	var leg_shift: int = 0
	if anim in ["walk", "run", "carry"]:
		leg_shift = -2 if frame % 2 == 0 else 2

	_line(img, Vector2i(14, 22 + bob), Vector2i(12 + leg_shift, 28), OUTLINE, 2)
	_line(img, Vector2i(18, 22 + bob), Vector2i(20 - leg_shift, 28), OUTLINE, 2)
	_rect(img, Rect2i(11, 12 + bob, 10, 11), cloth)
	_rect(img, Rect2i(11, 12 + bob, 10, 11), OUTLINE, false)
	_rect(img, Rect2i(12, 15 + bob, 8, 3), dark_cloth)
	_ellipse(img, Vector2i(16, 9 + bob), Vector2i(5, 5), SKIN)
	_rect(img, Rect2i(12, 5 + bob, 8, 3), OUTLINE)

	var arm_y: int = 15 + bob
	if anim == "celebrate" or anim == "victory":
		var lift: int = -4 if frame % 2 == 0 else -1
		_line(img, Vector2i(11, arm_y), Vector2i(7, arm_y + lift), OUTLINE, 2)
		_line(img, Vector2i(21, arm_y), Vector2i(25, arm_y + lift), OUTLINE, 2)
		if anim == "victory":
			_line(img, Vector2i(25, arm_y + lift), Vector2i(29, arm_y + lift - 7), Color(0.80, 0.82, 0.78), 1)
	elif anim == "fear":
		var tremble: int = -1 if frame % 2 == 0 else 1
		_line(img, Vector2i(11 + tremble, arm_y), Vector2i(7 + tremble, arm_y - 2), OUTLINE, 2)
		_line(img, Vector2i(21 + tremble, arm_y), Vector2i(25 + tremble, arm_y - 2), OUTLINE, 2)
		_rect(img, Rect2i(14 + tremble, 9 + bob, 2, 2), OUTLINE)
		_rect(img, Rect2i(18 + tremble, 9 + bob, 2, 2), OUTLINE)
	elif anim == "attack":
		var reach: int = [0, 3, 6, 4, 1][frame]
		_line(img, Vector2i(20, arm_y), Vector2i(25 + reach, arm_y - 4), OUTLINE, 2)
		_line(img, Vector2i(24 + reach, arm_y - 5), Vector2i(30, arm_y - 8), Color(0.80, 0.82, 0.78), 1)
	elif anim.begins_with("harvest") or anim == "build" or anim == "mine":
		var swing: int = -5 if frame % 2 == 0 else 5
		_line(img, Vector2i(20, arm_y), Vector2i(25, arm_y + swing), OUTLINE, 2)
		_line(img, Vector2i(24, arm_y + swing), Vector2i(29, arm_y - swing), Color(0.45, 0.28, 0.12), 2)
		if anim == "harvest_pickaxe" or anim == "mine":
			_line(img, Vector2i(27, arm_y - swing - 4), Vector2i(31, arm_y - swing + 4), Color(0.70, 0.72, 0.68), 1)
		elif anim == "harvest_bend":
			_rect(img, Rect2i(25, 22, 5, 3), Color(0.80, 0.14, 0.12))
		else:
			_rect(img, Rect2i(27, arm_y - swing - 2, 4, 4), Color(0.68, 0.68, 0.64))
	elif anim == "carry":
		_rect(img, Rect2i(21, 13 + bob, 7, 7), Color(0.50, 0.30, 0.12))
		_line(img, Vector2i(20, arm_y), Vector2i(25, arm_y + 2), OUTLINE, 2)
	else:
		_line(img, Vector2i(11, arm_y), Vector2i(7, arm_y + 3), OUTLINE, 2)
		_line(img, Vector2i(21, arm_y), Vector2i(25, arm_y + 2), OUTLINE, 2)

	match unit_type:
		"archer":
			_line(img, Vector2i(6, 11), Vector2i(6, 24), Color(0.42, 0.22, 0.08), 1)
			_line(img, Vector2i(6, 11), Vector2i(9, 17), Color(0.9, 0.9, 0.75), 1)
		"swordsman":
			_rect(img, Rect2i(9, 14 + bob, 3, 6), Color(0.70, 0.72, 0.70))
		"spearman":
			_line(img, Vector2i(25, 7), Vector2i(25, 26), Color(0.42, 0.24, 0.10), 1)
		"cavalry":
			_rect(img, Rect2i(8, 21 + bob, 17, 5), Color(0.38, 0.22, 0.11))
		"catapult":
			_rect(img, Rect2i(6, 17, 20, 8), Color(0.46, 0.30, 0.14))
			_ellipse(img, Vector2i(10, 26), Vector2i(3, 3), OUTLINE)
			_ellipse(img, Vector2i(23, 26), Vector2i(3, 3), OUTLINE)

	return img


static func _draw_building(building_type: String, player_id: int, grid_size: Vector2i, anim: String, frame: int, count: int) -> Image:
	var img: Image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)

	var base: Color = Color(0.58, 0.44, 0.28)
	var roof: Color = _player_color(player_id).darkened(0.05)
	var stone: Color = Color(0.46, 0.44, 0.40)
	var dark: Color = Color(0.16, 0.12, 0.09)
	var wood: Color = Color(0.43, 0.25, 0.12)
	var progress: float = float(frame + 1) / maxf(float(count), 1.0)
	if anim == "constructing" or anim == "construction":
		progress *= 0.86

	_ellipse(img, Vector2i(48, 76), Vector2i(34, 9), SHADOW)

	var width: int = clampi(grid_size.x * 18 + 22, 34, 78)
	var height: int = clampi(grid_size.y * 13 + 20, 30, 72)
	var x: int = 48 - width / 2
	var y: int = 72 - int(float(height) * progress)

	if building_type in ["castle", "tower", "wall"]:
		base = stone
		roof = stone.lightened(0.18)
	elif building_type in ["mill", "lumber_camp"]:
		base = wood
	elif building_type == "mine":
		base = Color(0.40, 0.36, 0.32)
	elif building_type == "barracks":
		base = Color(0.52, 0.34, 0.25)

	_rect(img, Rect2i(x, y + 12, width, height - 12), base)
	_rect(img, Rect2i(x, y + 12, width, height - 12), dark, false)
	if progress > 0.35:
		_roof(img, x - 4, y + 8, width + 8, 18, roof)
	if progress > 0.55:
		_rect(img, Rect2i(44, 62, 9, 14), dark)
		_rect(img, Rect2i(25, y + 28, 8, 8), Color(0.82, 0.72, 0.45))
		_rect(img, Rect2i(63, y + 28, 8, 8), Color(0.82, 0.72, 0.45))

	match building_type:
		"town_center":
			_rect(img, Rect2i(40, y - 2, 16, 18), base.lightened(0.08))
			_roof(img, 36, y - 7, 24, 10, roof.lightened(0.05))
			_flag(img, Vector2i(58, y - 9), roof, frame)
		"house":
			_rect(img, Rect2i(35, 58, 8, 8), Color(0.90, 0.78, 0.42))
		"mill":
			var center := Vector2i(48, 41)
			var angle: float = float(frame) / maxf(float(count), 1.0) * TAU
			for i in range(4):
				var a: float = angle + float(i) * TAU / 4.0
				_line(img, center, center + Vector2i(int(cos(a) * 18.0), int(sin(a) * 18.0)), Color(0.82, 0.72, 0.58), 3)
		"tower":
			_rect(img, Rect2i(36, 18, 24, 58), stone)
			_rect(img, Rect2i(32, 16, 32, 10), stone.lightened(0.16))
			_flag(img, Vector2i(61, 16), roof, frame)
		"castle":
			_rect(img, Rect2i(21, 32, 16, 42), stone.darkened(0.04))
			_rect(img, Rect2i(59, 32, 16, 42), stone.darkened(0.04))
			_rect(img, Rect2i(20, 24, 18, 9), stone.lightened(0.16))
			_rect(img, Rect2i(58, 24, 18, 9), stone.lightened(0.16))
		"barracks":
			_rect(img, Rect2i(25, 58, 46, 5), Color(0.35, 0.22, 0.14))
		"archery_range":
			_line(img, Vector2i(27, 58), Vector2i(69, 58), Color(0.40, 0.22, 0.10), 2)
			_line(img, Vector2i(32, 51), Vector2i(32, 65), Color(0.40, 0.22, 0.10), 1)
		"stable":
			_rect(img, Rect2i(26, 61, 44, 9), dark)
		"siege_workshop":
			_ellipse(img, Vector2i(30, 75), Vector2i(5, 5), dark)
			_ellipse(img, Vector2i(66, 75), Vector2i(5, 5), dark)
		"mine":
			_rect(img, Rect2i(34, 60, 28, 16), dark)

	if anim == "producing":
		var pulse: float = sin(float(frame) / maxf(float(count), 1.0) * TAU) * 0.18 + 0.18
		_rect(img, Rect2i(x + 5, y + 18, width - 10, 4), Color(1.0, 0.86, 0.32, pulse))
	elif anim == "damaged" or anim == "burning":
		_line(img, Vector2i(x + 12, y + 20), Vector2i(x + 24, y + 40), dark, 2)
		_line(img, Vector2i(x + width - 18, y + 26), Vector2i(x + width - 30, y + 50), dark, 2)
	if anim == "burning":
		_flame(img, Vector2i(34, y + 20), frame)
		_flame(img, Vector2i(62, y + 24), frame + 1)
	elif anim == "destroyed":
		_rect(img, Rect2i(x, 58, width, 15), base.darkened(0.25))
		_rect(img, Rect2i(x + 8, 48, 14, 14), base.darkened(0.15))

	return img


static func get_unit_preview(unit_type: String, player_id: int = 0) -> Texture2D:
	var img: Image = _draw_unit(unit_type, player_id, "idle", 0, 4)
	return _texture_from_image(img)


static func get_building_preview(building_type: String, player_id: int = 0, grid_size: Vector2i = Vector2i(2, 2)) -> Texture2D:
	var img: Image = _draw_building(building_type, player_id, grid_size, "active", 0, 4)
	return _texture_from_image(img)


static func create_wood_bundle(size: Vector2i = Vector2i(16, 16)) -> Texture2D:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	var wood: Color = Color(0.55, 0.35, 0.18)
	var wood_dark: Color = Color(0.38, 0.22, 0.10)
	var wood_light: Color = Color(0.68, 0.48, 0.28)
	var cx: int = size.x / 2
	var cy: int = size.y / 2 + 2
	for i in range(4):
		var x: int = cx - 6 + i * 4
		_rect(img, Rect2i(x, cy - 8, 3, 10), wood)
		_rect(img, Rect2i(x, cy - 8, 3, 10), wood_dark, false)
		_rect(img, Rect2i(x + 1, cy - 7, 1, 4), wood_light)
	_line(img, Vector2i(cx - 7, cy - 2), Vector2i(cx + 5, cy - 2), wood_dark, 1)
	_line(img, Vector2i(cx - 7, cy + 2), Vector2i(cx + 5, cy + 2), wood_dark, 1)
	return _texture_from_image(img)


static func create_stone_sack(size: Vector2i = Vector2i(16, 16)) -> Texture2D:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	var sack: Color = Color(0.46, 0.44, 0.40)
	var sack_dark: Color = Color(0.32, 0.30, 0.28)
	var sack_light: Color = Color(0.58, 0.56, 0.52)
	var cx: int = size.x / 2
	var cy: int = size.y / 2 + 1
	_ellipse(img, Vector2i(cx, cy), Vector2i(6, 5), sack)
	_ellipse(img, Vector2i(cx, cy), Vector2i(6, 5), sack_dark, false)
	for x in range(cx - 4, cx + 5, 3):
		_line(img, Vector2i(x, cy - 4), Vector2i(x, cy + 4), sack_light, 1)
	_rect(img, Rect2i(cx - 3, cy - 7, 6, 3), sack_dark)
	_ellipse(img, Vector2i(cx, cy - 6), Vector2i(3, 1), sack_dark)
	return _texture_from_image(img)


static func create_food_basket(size: Vector2i = Vector2i(16, 16)) -> Texture2D:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	var basket: Color = Color(0.48, 0.30, 0.12)
	var basket_dark: Color = Color(0.32, 0.18, 0.06)
	var basket_light: Color = Color(0.62, 0.42, 0.18)
	var apple: Color = Color(0.82, 0.22, 0.18)
	var wheat: Color = Color(0.88, 0.78, 0.32)
	var cx: int = size.x / 2
	var cy: int = size.y / 2 + 1
	_ellipse(img, Vector2i(cx, cy + 2), Vector2i(7, 5), basket)
	_ellipse(img, Vector2i(cx, cy + 2), Vector2i(7, 5), basket_dark, false)
	for x in range(cx - 6, cx + 7, 2):
		_line(img, Vector2i(x, cy), Vector2i(x, cy + 6), basket_light, 1)
	_rect(img, Rect2i(cx - 6, cy - 2, 12, 2), basket_dark)
	_ellipse(img, Vector2i(cx - 2, cy - 4), Vector2i(3, 3), apple)
	_ellipse(img, Vector2i(cx + 3, cy - 5), Vector2i(2, 2), wheat)
	_ellipse(img, Vector2i(cx - 4, cy - 5), Vector2i(2, 2), wheat)
	return _texture_from_image(img)


static func create_gold_sack(size: Vector2i = Vector2i(16, 16)) -> Texture2D:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	var sack: Color = Color(0.30, 0.24, 0.16)
	var sack_dark: Color = Color(0.18, 0.14, 0.08)
	var sack_light: Color = Color(0.42, 0.34, 0.22)
	var gold: Color = Color(0.96, 0.80, 0.16)
	var gold_dark: Color = Color(0.72, 0.58, 0.08)
	var cx: int = size.x / 2
	var cy: int = size.y / 2 + 1
	_ellipse(img, Vector2i(cx, cy), Vector2i(6, 5), sack)
	_ellipse(img, Vector2i(cx, cy), Vector2i(6, 5), sack_dark, false)
	for x in range(cx - 4, cx + 5, 3):
		_line(img, Vector2i(x, cy - 4), Vector2i(x, cy + 4), sack_light, 1)
	_rect(img, Rect2i(cx - 3, cy - 7, 6, 3), sack_dark)
	_ellipse(img, Vector2i(cx, cy - 6), Vector2i(3, 1), sack_dark)
	_ellipse(img, Vector2i(cx, cy - 2), Vector2i(2, 2), gold)
	_ellipse(img, Vector2i(cx + 3, cy - 4), Vector2i(2, 2), gold)
	_ellipse(img, Vector2i(cx - 3, cy - 4), Vector2i(2, 2), gold_dark)
	return _texture_from_image(img)


static func _texture_from_image(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img)


static func _player_color(player_id: int) -> Color:
	match player_id:
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


static func _rect(img: Image, rect: Rect2i, color: Color, filled: bool = true) -> void:
	if filled:
		img.fill_rect(rect, color)
		return
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		_safe_pixel(img, x, rect.position.y, color)
		_safe_pixel(img, x, rect.position.y + rect.size.y - 1, color)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		_safe_pixel(img, rect.position.x, y, color)
		_safe_pixel(img, rect.position.x + rect.size.x - 1, y, color)


static func _ellipse(img: Image, center: Vector2i, radius: Vector2i, color: Color) -> void:
	for y in range(center.y - radius.y, center.y + radius.y + 1):
		for x in range(center.x - radius.x, center.x + radius.x + 1):
			var dx: float = float(x - center.x) / maxf(float(radius.x), 1.0)
			var dy: float = float(y - center.y) / maxf(float(radius.y), 1.0)
			if dx * dx + dy * dy <= 1.0:
				_safe_pixel(img, x, y, color)


static func _line(img: Image, a: Vector2i, b: Vector2i, color: Color, thickness: int = 1) -> void:
	var steps: int = maxi(abs(b.x - a.x), abs(b.y - a.y))
	if steps <= 0:
		_safe_pixel(img, a.x, a.y, color)
		return
	var half_thickness: int = int(thickness / 2)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2i = Vector2i(roundi(lerpf(float(a.x), float(b.x), t)), roundi(lerpf(float(a.y), float(b.y), t)))
		for oy in range(-half_thickness, half_thickness + 1):
			for ox in range(-half_thickness, half_thickness + 1):
				_safe_pixel(img, p.x + ox, p.y + oy, color)


static func _roof(img: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var center_x: int = x + int(width / 2)
	for row in range(height):
		var half: int = int(float(width) * float(row + 1) / float(height) * 0.5)
		_rect(img, Rect2i(center_x - half, y + row, half * 2, 1), color)
	_rect(img, Rect2i(x, y + height - 2, width, 3), OUTLINE)


static func _flag(img: Image, pole: Vector2i, color: Color, frame: int) -> void:
	_line(img, pole, pole + Vector2i(0, 22), OUTLINE, 1)
	var wave: int = -1 if frame % 2 == 0 else 1
	_rect(img, Rect2i(pole.x + 1, pole.y + 2 + wave, 12, 7), color)
	_rect(img, Rect2i(pole.x + 1, pole.y + 2 + wave, 12, 7), OUTLINE, false)


static func _flame(img: Image, pos: Vector2i, frame: int) -> void:
	var rise: int = frame % 2
	_ellipse(img, pos + Vector2i(0, -rise), Vector2i(5, 8), Color(1.0, 0.28, 0.05, 0.9))
	_ellipse(img, pos + Vector2i(1, 2 - rise), Vector2i(3, 5), Color(1.0, 0.86, 0.12, 0.9))


static func _safe_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)
