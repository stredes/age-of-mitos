extends CanvasLayer
## Dedicated error display for clear, prominent error messages.
##
## Shows a centered error banner with shake animation, icon, title,
## message, and optional details. Auto-dismisses or can be clicked to dismiss.
## Stackable: multiple errors queue and show one at a time.

const ERROR_BG: Color = Color(0.18, 0.03, 0.03, 0.95)
const ERROR_BORDER: Color = Color(0.92, 0.25, 0.2, 1.0)
const ERROR_TEXT: Color = Color(0.95, 0.9, 0.88)
const ERROR_TITLE_COLOR: Color = Color(0.95, 0.35, 0.28)
const ERROR_DETAIL_COLOR: Color = Color(0.7, 0.65, 0.6)
const ERROR_ICON: String = "!"

const SHAKE_INTENSITY: float = 6.0
const SHAKE_DURATION: float = 0.35
const FADE_IN_TIME: float = 0.2
const FADE_OUT_TIME: float = 0.3
const AUTO_DISMISS_TIME: float = 5.0
const MAX_WIDTH: int = 420

var _panel: PanelContainer = null
var _title_label: Label = null
var _message_label: Label = null
var _detail_label: Label = null
var _queue: Array[Dictionary] = []
var _is_showing: bool = false


func _ready() -> void:
	layer = 30
	_build_ui()
	visible = false


func _build_ui() -> void:
	# Full-screen dim background.
	_panel = PanelContainer.new()
	_panel.name = "ErrorPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -MAX_WIDTH / 2
	_panel.offset_right = MAX_WIDTH / 2
	_panel.offset_top = -60
	_panel.offset_bottom = 60
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ERROR_BG
	style.border_color = ERROR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)

	_panel.gui_input.connect(_on_panel_input)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 12)
	_panel.add_child(hbox)

	# Icon circle.
	var icon_panel: PanelContainer = PanelContainer.new()
	icon_panel.name = "IconPanel"
	icon_panel.custom_minimum_size = Vector2(36, 36)
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.bg_color = ERROR_BORDER
	icon_style.set_corner_radius_all(18)
	icon_style.set_content_margin_all(0)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	var icon_label: Label = Label.new()
	icon_label.name = "Icon"
	icon_label.text = ERROR_ICON
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_panel.add_child(icon_label)
	hbox.add_child(icon_panel)

	# Text content.
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "TextVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", ERROR_TITLE_COLOR)
	vbox.add_child(_title_label)

	_message_label = Label.new()
	_message_label.name = "Message"
	_message_label.add_theme_font_size_override("font_size", 13)
	_message_label.add_theme_color_override("font_color", ERROR_TEXT)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size.x = MAX_WIDTH - 80
	vbox.add_child(_message_label)

	_detail_label = Label.new()
	_detail_label.name = "Detail"
	_detail_label.add_theme_font_size_override("font_size", 11)
	_detail_label.add_theme_color_override("font_color", ERROR_DETAIL_COLOR)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size.x = MAX_WIDTH - 80
	_detail_label.visible = false
	vbox.add_child(_detail_label)

	add_child(_panel)


func show_error(title: String, message: String, detail: String = "") -> void:
	_queue.append({"title": title, "message": message, "detail": detail})
	if not _is_showing:
		_display_next()


func show_error_simple(message: String) -> void:
	show_error("Error", message)


func _display_next() -> void:
	if _queue.size() == 0:
		_is_showing = false
		visible = false
		return

	_is_showing = true
	var data: Dictionary = _queue.pop_front()

	_title_label.text = data.get("title", "Error")
	_message_label.text = data.get("message", "")
	var detail: String = data.get("detail", "")
	if detail.length() > 0:
		_detail_label.text = detail
		_detail_label.visible = true
	else:
		_detail_label.visible = false

	visible = true
	_panel.modulate.a = 0.0
	_panel.position = Vector2(0, 0)

	# Fade in.
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_TIME)

	# Shake.
	_shake()

	# Auto-dismiss after delay.
	await get_tree().create_timer(AUTO_DISMISS_TIME).timeout
	_dismiss_current()


func _dismiss_current() -> void:
	if not _is_showing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_callback(func() -> void:
		visible = false
		_display_next()
	)


func _shake() -> void:
	var original_pos: Vector2 = _panel.position
	var shake_tween: Tween = create_tween()
	for i in range(6):
		var offset_x: float = randf_range(-SHAKE_INTENSITY, SHAKE_INTENSITY)
		var offset_y: float = randf_range(-SHAKE_INTENSITY * 0.5, SHAKE_INTENSITY * 0.5)
		shake_tween.tween_property(_panel, "position", original_pos + Vector2(offset_x, offset_y), SHAKE_DURATION / 6.0)
	shake_tween.tween_property(_panel, "position", original_pos, SHAKE_DURATION / 6.0)


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_current()
	elif event is InputEventScreenTouch and event.pressed:
		_dismiss_current()


func clear_all() -> void:
	_queue.clear()
	_is_showing = false
	visible = false
