extends PanelContainer
## Reusable hover tooltip for UI elements.
##
## Add to the scene tree (e.g. as a child of the HUD). Any Control can
## trigger it by connecting mouse_entered / mouse_exited.
##
## Quick attach helper:
##   TooltipSystem.attach(control, "Title", "Description\ndata here")
##
## Or manual usage:
##   tooltip.show_tooltip("Title", "Description", global_pos)

var _title_label: Label = null
var _desc_label: Label = null
var _hide_tween: Tween = null

const TITLE_FONT_SIZE: int = 14
const DESC_FONT_SIZE: int = 12
const MAX_WIDTH: int = 280
const OFFSET: Vector2 = Vector2(8, 8)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_build_ui()
	visible = false


func _build_ui() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.94)
	style.border_color = Color(0.35, 0.30, 0.20, 0.8)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.60))
	vbox.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.name = "Description"
	_desc_label.add_theme_font_size_override("font_size", DESC_FONT_SIZE)
	_desc_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.72))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size.x = MAX_WIDTH
	vbox.add_child(_desc_label)


func show_tooltip(title: String, desc: String, pos: Vector2) -> void:
	if _title_label:
		_title_label.text = title
		_title_label.visible = title.length() > 0
	if _desc_label:
		_desc_label.text = desc
		_desc_label.visible = desc.length() > 0

	visible = true
	modulate.a = 1.0

	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()

	# Defer position so size is calculated after text is set.
	await get_tree().process_frame
	_clamp_to_viewport(pos)


func hide_tooltip() -> void:
	if visible:
		_fade_out(0.12)


func _fade_out(duration: float) -> void:
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_property(self, "modulate:a", 0.0, duration)
	_hide_tween.tween_callback(func() -> void: visible = false)


func _clamp_to_viewport(pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = size
	var final_pos: Vector2 = pos + OFFSET

	if final_pos.x + tooltip_size.x > viewport_size.x:
		final_pos.x = pos.x - tooltip_size.x - OFFSET.x
	if final_pos.y + tooltip_size.y > viewport_size.y:
		final_pos.y = pos.y - tooltip_size.y - OFFSET.y
	final_pos.x = maxf(final_pos.x, 4.0)
	final_pos.y = maxf(final_pos.y, 4.0)

	position = final_pos


## Static helper: connect a Control's hover signals to this tooltip.
## The tooltip must already be in the scene tree.
static func attach(control: Control, title: String, desc: String) -> void:
	if control == null:
		return
	var on_enter: Callable = func() -> void:
		var tooltips: Array[Node] = control.get_tree().get_nodes_in_group("_tooltip_system")
		if tooltips.size() > 0:
			var tip: PanelContainer = tooltips[0] as PanelContainer
			var pos: Vector2 = control.global_position + Vector2(0, control.size.y)
			tip.show_tooltip(title, desc, pos)
	var on_exit: Callable = func() -> void:
		var tooltips: Array[Node] = control.get_tree().get_nodes_in_group("_tooltip_system")
		if tooltips.size() > 0:
			(tooltips[0] as PanelContainer).hide_tooltip()
	if not control.mouse_entered.is_connected(on_enter):
		control.mouse_entered.connect(on_enter)
	if not control.mouse_exited.is_connected(on_exit):
		control.mouse_exited.connect(on_exit)


## Static helper: register this tooltip instance in the scene tree.
static func register(tooltip: PanelContainer) -> void:
	if not tooltip.is_in_group("_tooltip_system"):
		tooltip.add_to_group("_tooltip_system")
