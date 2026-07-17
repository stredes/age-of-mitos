extends CanvasLayer
## Floating notification system with color-coded stacked messages.
##
## Shows up to 3 stacked notifications that slide in from the right
## and auto-dismiss. Green = success, Red = error, Yellow = warning, Blue = info.

enum Type { SUCCESS, ERROR, WARNING, INFO }

const COLORS: Dictionary = {
	Type.SUCCESS: Color(0.2, 0.88, 0.35),
	Type.ERROR: Color(0.95, 0.28, 0.22),
	Type.WARNING: Color(0.98, 0.85, 0.22),
	Type.INFO: Color(0.4, 0.7, 1.0),
}

const BG_COLORS: Dictionary = {
	Type.SUCCESS: Color(0.04, 0.14, 0.05, 0.92),
	Type.ERROR: Color(0.22, 0.04, 0.04, 0.92),
	Type.WARNING: Color(0.22, 0.17, 0.02, 0.92),
	Type.INFO: Color(0.04, 0.08, 0.18, 0.92),
}

const ICONS: Dictionary = {
	Type.SUCCESS: "+",
	Type.ERROR: "X",
	Type.WARNING: "!",
	Type.INFO: "i",
}

const DISPLAY_TIME: float = 3.0
const FADE_TIME: float = 0.3
const SLIDE_TIME: float = 0.2
const MAX_VISIBLE: int = 3
const NOTIF_HEIGHT: int = 34
const NOTIF_SPACING: int = 4
const NOTIF_WIDTH: int = 300

var _container: VBoxContainer = null
var _active: Array[Dictionary] = []


func _ready() -> void:
	layer = 20
	_container = VBoxContainer.new()
	_container.name = "NotificationContainer"
	_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_container.offset_left = -NOTIF_WIDTH - 16
	_container.offset_top = 50
	_container.offset_right = -16
	_container.offset_bottom = 300
	_container.add_theme_constant_override("separation", NOTIF_SPACING)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)


func show_success(text: String, duration: float = DISPLAY_TIME) -> void:
	_add_notification(text, Type.SUCCESS, duration)


func show_error(text: String, duration: float = DISPLAY_TIME) -> void:
	_add_notification(text, Type.ERROR, duration)


func show_warning(text: String, duration: float = DISPLAY_TIME) -> void:
	_add_notification(text, Type.WARNING, duration)


func show_info(text: String, duration: float = DISPLAY_TIME) -> void:
	_add_notification(text, Type.INFO, duration)


func show_notification(text: String, type: int = Type.INFO, duration: float = DISPLAY_TIME) -> void:
	_add_notification(text, type, duration)


func _add_notification(text: String, type: int, duration: float) -> void:
	# Enforce max stack — remove oldest if at capacity.
	while _active.size() >= MAX_VISIBLE:
		var oldest: Dictionary = _active[0]
		_remove_notification(oldest)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Notification"

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG_COLORS.get(type, BG_COLORS[Type.INFO])
	style.border_color = COLORS.get(type, COLORS[Type.INFO])
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Icon badge.
	var icon_bg: PanelContainer = PanelContainer.new()
	icon_bg.name = "IconBadge"
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.bg_color = COLORS.get(type, COLORS[Type.INFO])
	icon_style.set_corner_radius_all(3)
	icon_style.set_content_margin_all(2)
	icon_bg.add_theme_stylebox_override("panel", icon_style)
	var icon_label: Label = Label.new()
	icon_label.name = "Icon"
	icon_label.text = ICONS.get(type, "*")
	icon_label.add_theme_font_size_override("font_size", 12)
	icon_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(16, 16)
	icon_bg.add_child(icon_label)
	hbox.add_child(icon_bg)

	# Message text.
	var msg_label: Label = Label.new()
	msg_label.name = "Message"
	msg_label.text = text
	msg_label.add_theme_font_size_override("font_size", 13)
	msg_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(msg_label)

	# Progress bar showing time remaining.
	var progress: ProgressBar = ProgressBar.new()
	progress.name = "Progress"
	progress.custom_minimum_size = Vector2(NOTIF_WIDTH - 20, 3)
	progress.max_value = 100.0
	progress.value = 100.0
	progress.show_percentage = false
	var prog_fill: StyleBoxFlat = StyleBoxFlat.new()
	prog_fill.bg_color = COLORS.get(type, COLORS[Type.INFO])
	prog_fill.set_corner_radius_all(1)
	progress.add_theme_stylebox_override("fill", prog_fill)
	var prog_bg: StyleBoxFlat = StyleBoxFlat.new()
	prog_bg.bg_color = Color(0.15, 0.15, 0.15)
	prog_bg.set_corner_radius_all(1)
	progress.add_theme_stylebox_override("background", prog_bg)

	# Outer wrapper: panel + progress stacked.
	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 2)
	outer_vbox.add_child(panel)
	outer_vbox.add_child(progress)

	# Start off-screen to the right for slide-in.
	outer_vbox.position.x = NOTIF_WIDTH + 20
	outer_vbox.modulate.a = 0.0
	_container.add_child(outer_vbox)

	var entry: Dictionary = {
		"panel": outer_vbox,
		"type": type,
		"text": text,
	}
	_active.append(entry)

	# Slide in from right.
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer_vbox, "position:x", 0.0, SLIDE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(outer_vbox, "modulate:a", 1.0, SLIDE_TIME)
	tween.chain().tween_interval(duration)
	tween.tween_property(outer_vbox, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(func() -> void: _remove_notification(entry))

	# Animate progress bar draining.
	var progress_tween: Tween = create_tween()
	progress_tween.tween_property(progress, "value", 0.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)


func _remove_notification(entry: Dictionary) -> void:
	var idx: int = _active.find(entry)
	if idx != -1:
		_active.remove_at(idx)
	if entry.has("panel") and is_instance_valid(entry["panel"]):
		entry["panel"].queue_free()


func clear_all() -> void:
	for entry: Dictionary in _active:
		if entry.has("panel") and is_instance_valid(entry["panel"]):
			entry["panel"].queue_free()
	_active.clear()
