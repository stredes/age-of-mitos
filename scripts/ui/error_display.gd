extends CanvasLayer
## Dedicated error display for clear, prominent error messages.
##
## Shows centered error banners with shake animation, icon, title,
## message, and optional details. Auto-dismisses or click to dismiss.
## Includes preset methods for common game errors:
##   show_resources_insufficient(cost, have)
##   show_location_blocked()
##   show_population_max()
##   show_no_training_queue()
##   show_building_not_ready()

const ERROR_BG: Color = Color(0.18, 0.03, 0.03, 0.95)
const ERROR_BORDER: Color = Color(0.92, 0.25, 0.2, 1.0)
const ERROR_TEXT: Color = Color(0.95, 0.9, 0.88)
const ERROR_TITLE_COLOR: Color = Color(0.95, 0.35, 0.28)
const ERROR_DETAIL_COLOR: Color = Color(0.7, 0.65, 0.6)
const ERROR_ICON: String = "!"

const WARN_BG: Color = Color(0.22, 0.16, 0.02, 0.95)
const WARN_BORDER: Color = Color(0.95, 0.78, 0.18, 1.0)
const WARN_TITLE_COLOR: Color = Color(0.98, 0.82, 0.22)

const SHAKE_INTENSITY: float = 6.0
const SHAKE_DURATION: float = 0.35
const FADE_IN_TIME: float = 0.2
const FADE_OUT_TIME: float = 0.3
const AUTO_DISMISS_TIME: float = 4.0
const MAX_WIDTH: int = 420

var _panel: PanelContainer = null
var _icon_panel: PanelContainer = null
var _icon_label: Label = null
var _title_label: Label = null
var _message_label: Label = null
var _detail_label: Label = null
var _queue: Array[Dictionary] = []
var _is_showing: bool = false
var _current_style: int = 0  # 0 = error, 1 = warning


func _ready() -> void:
	layer = 30
	_build_ui()
	visible = false


func _build_ui() -> void:
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

	_apply_error_style()
	_panel.gui_input.connect(_on_panel_input)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 12)
	_panel.add_child(hbox)

	# Icon circle.
	_icon_panel = PanelContainer.new()
	_icon_panel.name = "IconPanel"
	_icon_panel.custom_minimum_size = Vector2(36, 36)
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.bg_color = ERROR_BORDER
	icon_style.set_corner_radius_all(18)
	icon_style.set_content_margin_all(0)
	_icon_panel.add_theme_stylebox_override("panel", icon_style)
	_icon_label = Label.new()
	_icon_label.name = "Icon"
	_icon_label.text = ERROR_ICON
	_icon_label.add_theme_font_size_override("font_size", 20)
	_icon_label.add_theme_color_override("font_color", Color.WHITE)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_panel.add_child(_icon_label)
	hbox.add_child(_icon_panel)

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


func _apply_error_style() -> void:
	if _panel == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ERROR_BG
	style.border_color = ERROR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)


func _apply_warn_style() -> void:
	if _panel == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = WARN_BG
	style.border_color = WARN_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)


# =============================================================================
# Generic API
# =============================================================================

func show_error(title: String, message: String, detail: String = "", is_warning: bool = false) -> void:
	_queue.append({"title": title, "message": message, "detail": detail, "warning": is_warning})
	if not _is_showing:
		_display_next()


func show_error_simple(message: String) -> void:
	show_error("Error", message)


# =============================================================================
# Preset: Resources Insufficient
# =============================================================================

func show_resources_insufficient(cost: Dictionary, have: Dictionary = {}) -> void:
	var missing_lines: PackedStringArray = []
	for res_type: String in cost:
		var needed: int = int(cost[res_type])
		var owned: int = have.get(res_type, 0) if have.size() > 0 else GameManager.get_resource(res_type)
		var deficit: int = needed - owned
		if deficit > 0:
			var res_color: Color = _get_resource_color(res_type)
			missing_lines.append("%s: need %d, have %d (-%d)" % [res_type.capitalize(), needed, owned, deficit])

	if missing_lines.size() == 0:
		return

	var detail: String = PoolStringArray(missing_lines).join("\n")
	show_error("Not Enough Resources", "You don't have enough resources to do that.", detail)


func _get_resource_color(res_type: String) -> Color:
	match res_type:
		"wood":
			return Color(0.85, 0.65, 0.35)
		"stone":
			return Color(0.7, 0.7, 0.72)
		"food":
			return Color(0.4, 0.8, 0.35)
		"gold":
			return Color(1.0, 0.85, 0.2)
		_:
			return Color.WHITE


# =============================================================================
# Preset: Location Blocked
# =============================================================================

func show_location_blocked() -> void:
	show_error("Cannot Build Here", "This location is blocked by another building or impassable terrain.", "", true)


func show_location_blocked_detail(reason: String) -> void:
	show_error("Cannot Build Here", reason, "", true)


# =============================================================================
# Preset: Population Max
# =============================================================================

func show_population_max() -> void:
	show_error("Population Limit Reached", "You've reached the maximum population. Build more houses to increase the limit.")


func show_population_max_detail(current: int, maximum: int) -> void:
	var detail: str = "Current: %d / %d" % [current, maximum]
	show_error("Population Limit Reached", "Build more houses to increase your population cap.", detail)


# =============================================================================
# Preset: Training / Production Errors
# =============================================================================

func show_no_training_queue() -> void:
	show_error("Nothing to Cancel", "The training queue is already empty.", "", true)


func show_building_not_ready() -> void:
	show_error("Building Not Ready", "This building is still under construction and cannot produce units yet.", "", true)


func show_training_full() -> void:
	show_error("Training Queue Full", "This building's training queue is at maximum capacity. Wait for units to finish.", "", true)


# =============================================================================
# Display Logic
# =============================================================================

func _display_next() -> void:
	if _queue.size() == 0:
		_is_showing = false
		visible = false
		return

	_is_showing = true
	var data: Dictionary = _queue.pop_front()
	var is_warning: bool = data.get("warning", false)

	# Apply style.
	if is_warning:
		_apply_warn_style()
		_title_label.add_theme_color_override("font_color", WARN_TITLE_COLOR)
		var icon_style: StyleBoxFlat = _icon_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if icon_style:
			icon_style = icon_style.duplicate()
			icon_style.bg_color = WARN_BORDER
			_icon_panel.add_theme_stylebox_override("panel", icon_style)
		_icon_label.text = "!"
	else:
		_apply_error_style()
		_title_label.add_theme_color_override("font_color", ERROR_TITLE_COLOR)
		var icon_style: StyleBoxFlat = _icon_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if icon_style:
			icon_style = icon_style.duplicate()
			icon_style.bg_color = ERROR_BORDER
			_icon_panel.add_theme_stylebox_override("panel", icon_style)
		_icon_label.text = ERROR_ICON

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

	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_TIME)

	_shake()

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
