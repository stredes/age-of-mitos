extends HBoxContainer

const RESOURCE_TYPES: Array[String] = ["wood", "food", "stone", "gold"]

const RESOURCE_ICONS: Dictionary = {
	"wood": "🪵",
	"food": "🍖",
	"stone": "🪨",
	"gold": "🪙",
}

const RESOURCE_COLORS: Dictionary = {
	"wood": Color(0.55, 0.27, 0.07),
	"food": Color(0.13, 0.55, 0.13),
	"stone": Color(0.5, 0.5, 0.5),
	"gold": Color(1.0, 0.84, 0.0),
}

const BG_COLOR: Color = Color(0.08, 0.08, 0.14, 0.7)
const FLASH_COLOR: Color = Color(0.23, 0.23, 0.24, 0.7)
const POP_FULL_COLOR: Color = Color(0.8, 0.2, 0.2)

var _labels: Dictionary = {}
var _panels: Dictionary = {}
var _tweens: Dictionary = {}
var _pop_panel: PanelContainer = null
var _pop_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 12)
	_build_ui()
	_connect_signals()
	_update_all()


func _build_ui() -> void:
	for res_type: String in RESOURCE_TYPES:
		var panel: PanelContainer = PanelContainer.new()
		panel.name = res_type.capitalize() + "Panel"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", style)
		_panels[res_type] = panel

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.name = res_type.capitalize() + "Row"
		hbox.add_theme_constant_override("separation", 4)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon: Label = Label.new()
		icon.name = "Icon"
		icon.text = RESOURCE_ICONS.get(res_type, "?")
		icon.add_theme_font_size_override("font_size", 18)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

		var amount: Label = Label.new()
		amount.name = "Amount"
		amount.text = "0"
		amount.add_theme_font_size_override("font_size", 16)
		amount.add_theme_color_override("font_color", RESOURCE_COLORS.get(res_type, Color.WHITE))
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(amount)
		_labels[res_type] = amount

		panel.add_child(hbox)
		add_child(panel)

	# Population panel
	_pop_panel = PanelContainer.new()
	_pop_panel.name = "PopPanel"
	_pop_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pop_style: StyleBoxFlat = StyleBoxFlat.new()
	pop_style.bg_color = BG_COLOR
	pop_style.corner_radius_top_left = 10
	pop_style.corner_radius_top_right = 10
	pop_style.corner_radius_bottom_left = 10
	pop_style.corner_radius_bottom_right = 10
	pop_style.content_margin_left = 8
	pop_style.content_margin_right = 8
	pop_style.content_margin_top = 4
	pop_style.content_margin_bottom = 4
	_pop_panel.add_theme_stylebox_override("panel", pop_style)

	var pop_hbox: HBoxContainer = HBoxContainer.new()
	pop_hbox.name = "PopRow"
	pop_hbox.add_theme_constant_override("separation", 4)
	pop_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pop_icon: Label = Label.new()
	pop_icon.name = "Icon"
	pop_icon.text = "👤"
	pop_icon.add_theme_font_size_override("font_size", 18)
	pop_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_hbox.add_child(pop_icon)

	_pop_label = Label.new()
	_pop_label.name = "Amount"
	_pop_label.text = "0/10"
	_pop_label.add_theme_font_size_override("font_size", 16)
	_pop_label.add_theme_color_override("font_color", Color.WHITE)
	_pop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_hbox.add_child(_pop_label)

	_pop_panel.add_child(pop_hbox)
	add_child(_pop_panel)


func _connect_signals() -> void:
	if not EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.connect(_on_resource_changed)
	var rm: Node = get_node_or_null("/root/GameWorld/ResourceManager")
	if rm != null and rm.has_signal("population_changed"):
		if not rm.population_changed.is_connected(_on_population_changed):
			rm.population_changed.connect(_on_population_changed)


func _update_all() -> void:
	var resources: Dictionary = GameManager.get_resources()
	for res_type: String in RESOURCE_TYPES:
		var label: Label = _labels.get(res_type)
		if label == null:
			continue
		var amount: int = resources.get(res_type, 0)
		label.text = str(amount)
	_update_pop_display()


func _on_resource_changed(resource_type: String, amount: int, _player_id: int) -> void:
	if resource_type not in _labels:
		return
	var label: Label = _labels[resource_type]
	var old_text: String = label.text
	var new_text: String = str(amount)
	if old_text != new_text and old_text != "0":
		_flash(resource_type)
	label.text = new_text


func _on_population_changed(current_pop: int, max_pop: int, player_id: int) -> void:
	if player_id != GameManager.get_local_player_id():
		return
	_update_pop_display()


func _update_pop_display() -> void:
	var rm: Node = get_node_or_null("/root/GameWorld/ResourceManager")
	if rm == null or _pop_label == null:
		return
	var pop_data: Dictionary = rm.get_pop(GameManager.get_local_player_id())
	var current: int = pop_data.get("current", 0)
	var max_p: int = pop_data.get("max", 10)
	_pop_label.text = "%d/%d" % [current, max_p]
	if current >= max_p:
		_pop_label.add_theme_color_override("font_color", POP_FULL_COLOR)
	else:
		_pop_label.add_theme_color_override("font_color", Color.WHITE)


func _flash(res_type: String) -> void:
	if res_type not in _panels:
		return
	var panel: PanelContainer = _panels[res_type]
	if panel == null:
		return
	if res_type in _tweens and _tweens[res_type] != null and _tweens[res_type].is_valid():
		_tweens[res_type].kill()
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate", Color(1.25, 1.25, 1.1, 1.0), 0.08)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.25)
	_tweens[res_type] = tween
