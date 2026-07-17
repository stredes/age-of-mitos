extends CanvasLayer
## Floating notification system with color-coded messages.
##
## Shows stacked notifications that auto-dismiss after a duration.
## Green = success, Red = error, Yellow = warning, White = info.

enum Type { SUCCESS, ERROR, WARNING, INFO }

const COLORS: Dictionary = {
	Type.SUCCESS: Color(0.2, 0.85, 0.3),
	Type.ERROR: Color(0.92, 0.25, 0.2),
	Type.WARNING: Color(0.95, 0.82, 0.2),
	Type.INFO: Color(0.85, 0.85, 0.9),
}

const BG_COLORS: Dictionary = {
	Type.SUCCESS: Color(0.05, 0.15, 0.05, 0.88),
	Type.ERROR: Color(0.2, 0.05, 0.05, 0.88),
	Type.WARNING: Color(0.2, 0.16, 0.02, 0.88),
	Type.INFO: Color(0.08, 0.08, 0.14, 0.88),
}

const DISPLAY_TIME: float = 3.0
const FADE_TIME: float = 0.4
const MAX_VISIBLE: int = 5
const NOTIF_HEIGHT: int = 32
const NOTIF_SPACING: int = 4
const NOTIF_WIDTH: int = 320

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
	if _active.size() >= MAX_VISIBLE:
		var oldest: Dictionary = _active[0]
		if oldest.has("panel") and is_instance_valid(oldest["panel"]):
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

	var icon_label: Label = Label.new()
	icon_label.name = "Icon"
	icon_label.text = _get_icon(type)
	icon_label.add_theme_font_size_override("font_size", 14)
	icon_label.add_theme_color_override("font_color", COLORS.get(type, Color.WHITE))
	icon_label.custom_minimum_size = Vector2(18, 0)
	hbox.add_child(icon_label)

	var msg_label: Label = Label.new()
	msg_label.name = "Message"
	msg_label.text = text
	msg_label.add_theme_font_size_override("font_size", 13)
	msg_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.88))
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(msg_label)

	panel.modulate.a = 0.0
	_container.add_child(panel)

	var entry: Dictionary = {
		"panel": panel,
		"type": type,
		"text": text,
	}
	_active.append(entry)

	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(duration)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(func() -> void: _remove_notification(entry))


func _remove_notification(entry: Dictionary) -> void:
	var idx: int = _active.find(entry)
	if idx != -1:
		_active.remove_at(idx)
	if entry.has("panel") and is_instance_valid(entry["panel"]):
		entry["panel"].queue_free()


func _get_icon(type: int) -> String:
	match type:
		Type.SUCCESS:
			return "+"
		Type.ERROR:
			return "X"
		Type.WARNING:
			return "!"
		Type.INFO:
			return "i"
		_:
			return "*"


func clear_all() -> void:
	for entry: Dictionary in _active:
		if entry.has("panel") and is_instance_valid(entry["panel"]):
			entry["panel"].queue_free()
	_active.clear()
