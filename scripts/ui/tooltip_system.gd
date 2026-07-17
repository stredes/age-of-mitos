extends PanelContainer
## Reusable hover tooltip for UI elements.
##
## Shows name, description, hotkey, and resource cost on hover.
## 0.5s delay before appearing. Auto-hides on mouse exit.
##
## Quick attach helper:
##   TooltipSystem.attach(control, { "name": "Villager", "desc": "...", "hotkey": "V", "cost": {"wood": 50} })
##
## Or manual usage:
##   tooltip.show_tooltip(data, global_pos)

const TITLE_FONT_SIZE: int = 14
const DESC_FONT_SIZE: int = 11
const HOTKEY_FONT_SIZE: int = 10
const COST_FONT_SIZE: int = 11
const MAX_WIDTH: int = 260
const OFFSET: Vector2 = Vector2(8, 8)
const SHOW_DELAY: float = 0.5
const FADE_DURATION: float = 0.12

var _title_label: Label = null
var _desc_label: Label = null
var _hotkey_label: Label = null
var _cost_container: HBoxContainer = null
var _separator: HSeparator = null
var _hide_tween: Tween = null
var _show_timer: Timer = null
var _pending_data: Dictionary = {}
var _pending_pos: Vector2 = Vector2.ZERO

var RESOURCE_COLORS: Dictionary = {
	"wood": Color(0.85, 0.65, 0.35),
	"stone": Color(0.7, 0.7, 0.72),
	"food": Color(0.4, 0.8, 0.35),
	"gold": Color(1.0, 0.85, 0.2),
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_build_ui()
	visible = false
	_show_timer = Timer.new()
	_show_timer.one_shot = true
	_show_timer.wait_time = SHOW_DELAY
	_show_timer.timeout.connect(_on_show_timer_timeout)
	add_child(_show_timer)


func _build_ui() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.95)
	style.border_color = Color(0.4, 0.35, 0.22, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 3)
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

	_hotkey_label = Label.new()
	_hotkey_label.name = "Hotkey"
	_hotkey_label.add_theme_font_size_override("font_size", HOTKEY_FONT_SIZE)
	_hotkey_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(_hotkey_label)

	_separator = HSeparator.new()
	_separator.name = "Separator"
	_separator.visible = false
	vbox.add_child(_separator)

	_cost_container = HBoxContainer.new()
	_cost_container.name = "Cost"
	_cost_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_cost_container)


func show_tooltip(data: Dictionary, pos: Vector2) -> void:
	_pending_data = data
	_pending_pos = pos
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	if _show_timer and not _show_timer.is_stopped():
		_show_timer.stop()
	if _show_timer:
		_show_timer.start()


func show_tooltip_immediate(data: Dictionary, pos: Vector2) -> void:
	_pending_data = data
	_pending_pos = pos
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	_apply_tooltip_content(data, pos)


func show_title_desc(title: String, desc: String, pos: Vector2) -> void:
	show_tooltip({"name": title, "desc": desc}, pos)


func _on_show_timer_timeout() -> void:
	_apply_tooltip_content(_pending_data, _pending_pos)


func _apply_tooltip_content(data: Dictionary, pos: Vector2) -> void:
	var title_text: String = data.get("name", "")
	var desc_text: String = data.get("desc", "")
	var hotkey_text: String = data.get("hotkey", "")
	var cost: Dictionary = data.get("cost", {})

	if _title_label:
		_title_label.text = title_text
		_title_label.visible = title_text.length() > 0

	if _desc_label:
		_desc_label.text = desc_text
		_desc_label.visible = desc_text.length() > 0

	if _hotkey_label:
		if hotkey_text.length() > 0:
			_hotkey_label.text = "Hotkey: " + hotkey_text
			_hotkey_label.visible = true
		else:
			_hotkey_label.visible = false

	# Build cost display.
	for child: Node in _cost_container.get_children():
		child.queue_free()
	var has_cost: bool = cost.size() > 0
	if _separator:
		_separator.visible = has_cost
	if has_cost:
		for res_type: String in cost:
			var amount: int = int(cost[res_type])
			if amount <= 0:
				continue
			var lbl: Label = Label.new()
			lbl.add_theme_font_size_override("font_size", COST_FONT_SIZE)
			lbl.add_theme_color_override("font_color", RESOURCE_COLORS.get(res_type, Color.WHITE))
			lbl.text = "%s: %d" % [res_type.capitalize(), amount]
			_cost_container.add_child(lbl)
		_cost_container.visible = true
	else:
		_cost_container.visible = false

	visible = true
	modulate.a = 1.0

	await get_tree().process_frame
	_clamp_to_viewport(pos)


func hide_tooltip() -> void:
	if _show_timer and not _show_timer.is_stopped():
		_show_timer.stop()
	if visible:
		_fade_out(FADE_DURATION)


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
## data should contain: { "name", "desc", "hotkey" (optional), "cost" (optional) }
static func attach(control: Control, data: Dictionary) -> void:
	if control == null:
		return
	var on_enter: Callable = func() -> void:
		var tooltips: Array[Node] = control.get_tree().get_nodes_in_group("_tooltip_system")
		if tooltips.size() > 0:
			var tip: PanelContainer = tooltips[0] as PanelContainer
			var pos: Vector2 = control.global_position + Vector2(0, control.size.y)
			tip.show_tooltip(data, pos)
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
