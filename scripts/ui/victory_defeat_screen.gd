extends CanvasLayer
## Victory / Defeat screen with summary stats.
##
## Shows result banner, game time, resources gathered, units killed/lost,
## buildings built/destroyed, and a return-to-menu button.
## Animated entrance with scale + fade.

const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.82)
const PANEL_BG: Color = Color(0.06, 0.06, 0.10, 0.96)
const PANEL_BORDER: Color = Color(0.35, 0.32, 0.22, 0.9)
const VICTORY_COLOR: Color = Color(0.2, 0.9, 0.3)
const DEFEAT_COLOR: Color = Color(0.92, 0.25, 0.2)
const DRAW_COLOR: Color = Color(0.85, 0.82, 0.3)
const STAT_LABEL_COLOR: Color = Color(0.6, 0.6, 0.55)
const STAT_VALUE_COLOR: Color = Color(0.92, 0.9, 0.85)
const RESOURCE_COLORS: Dictionary = {
	"wood": Color(0.85, 0.65, 0.35),
	"stone": Color(0.7, 0.7, 0.72),
	"food": Color(0.4, 0.8, 0.35),
	"gold": Color(1.0, 0.85, 0.2),
}

var _panel: PanelContainer = null
var _title_label: Label = null
var _stats_container: VBoxContainer = null


func _ready() -> void:
	layer = 25
	_build_ui()
	visible = false


func _build_ui() -> void:
	# Full-screen dim background.
	_panel = PanelContainer.new()
	_panel.name = "VictoryPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -220
	_panel.offset_right = 220
	_panel.offset_top = -200
	_panel.offset_bottom = 200
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Title (VICTORY / DEFEAT / DRAW).
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Subtitle with game time.
	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Game Over"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.65, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Separator.
	var sep: HSeparator = HSeparator.new()
	sep.name = "Separator"
	vbox.add_child(sep)

	# Stats section header.
	var stats_header: Label = Label.new()
	stats_header.text = "Battle Summary"
	stats_header.add_theme_font_size_override("font_size", 14)
	stats_header.add_theme_color_override("font_color", Color(0.55, 0.52, 0.4))
	stats_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_header)

	# Stats grid.
	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsGrid"
	_stats_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_stats_container)

	# Separator.
	var sep2: HSeparator = HSeparator.new()
	vbox.add_child(sep2)

	# Button row.
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var menu_btn: Button = Button.new()
	menu_btn.name = "MenuButton"
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(140, 44)
	menu_btn.pressed.connect(func() -> void: GameManager.return_to_menu())
	btn_row.add_child(menu_btn)

	add_child(_panel)


func show_victory(winner_id: int) -> void:
	visible = true
	_panel.scale = Vector2(0.8, 0.8)
	_panel.modulate.a = 0.0

	# Determine result.
	if winner_id == GameManager.local_player_id:
		_title_label.text = "VICTORY!"
		_title_label.add_theme_color_override("font_color", VICTORY_COLOR)
	elif winner_id == -1:
		_title_label.text = "DRAW"
		_title_label.add_theme_color_override("font_color", DRAW_COLOR)
	else:
		_title_label.text = "DEFEAT"
		_title_label.add_theme_color_override("font_color", DEFEAT_COLOR)

	# Clear old stats.
	for child: Node in _stats_container.get_children():
		child.queue_free()

	# Gather stats.
	var time_str: String = GameManager.get_game_time_formatted()
	_add_stat_row("Game Time", time_str)

	var resources: Dictionary = GameManager.get_resources()
	for res_type: String in ["wood", "stone", "food", "gold"]:
		var amount: int = resources.get(res_type, 0)
		_add_stat_row(res_type.capitalize() + " Gathered", str(amount), RESOURCE_COLORS.get(res_type))

	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	var my_units: int = 0
	var enemy_units: int = 0
	for unit: Node in units:
		if not is_instance_valid(unit):
			continue
		var pid: int = unit.get("player_id") if unit.has_method("get") and unit.get("player_id") != null else -1
		if pid == GameManager.local_player_id:
			my_units += 1
		elif pid != -1:
			enemy_units += 1
	_add_stat_row("Units Alive", str(my_units))
	_add_stat_row("Enemy Units", str(enemy_units))

	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm != null:
		var buildings_dict: Dictionary = bm.get("buildings") if bm.get("buildings") != null else {}
		var my_buildings: int = 0
		var enemy_buildings: int = 0
		for id: Variant in buildings_dict:
			var bnode: Node = buildings_dict[id]
			if not is_instance_valid(bnode):
				continue
			var bpid: int = bnode.get("player_id") if bnode.has_method("get") and bnode.get("player_id") != null else -1
			if bpid == GameManager.local_player_id:
				my_buildings += 1
			elif bpid != -1:
				enemy_buildings += 1
		_add_stat_row("Buildings", str(my_buildings))
		_add_stat_row("Enemy Buildings", str(enemy_buildings))

	# Animate entrance.
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3)


func _add_stat_row(label_text: String, value_text: String, value_color: Color = STAT_VALUE_COLOR) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_stats_container.add_child(row)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", STAT_LABEL_COLOR)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val: Label = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", value_color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)


func hide_screen() -> void:
	visible = false
