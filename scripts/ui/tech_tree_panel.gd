extends Control

const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.85)
const PANEL_COLOR: Color = Color(0.08, 0.08, 0.14, 0.95)
const TIER_COLORS: Array[Color] = [
	Color(0.4, 0.6, 0.9),
	Color(0.9, 0.7, 0.2),
	Color(0.9, 0.3, 0.3),
]
const RESEARCHED_COLOR: Color = Color(0.2, 0.8, 0.3)
const AVAILABLE_COLOR: Color = Color(0.3, 0.5, 0.9)
const LOCKED_COLOR: Color = Color(0.3, 0.3, 0.3)
const RESEARCHING_COLOR: Color = Color(0.9, 0.8, 0.2)

const ICONS: Dictionary = {
	"wood": "M",
	"stone": "P",
	"food": "C",
	"gold": "O",
}

var _tech_tree: Node = null
var _grid: GridContainer = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null
var _info_name: Label = null
var _info_desc: Label = null
var _info_cost: HBoxContainer = null
var _research_btn: Button = null
var _selected_tech: String = ""
var _update_timer: float = 0.0


func _ready() -> void:
	_build_ui()
	visible = false


func open() -> void:
	_find_tech_tree()
	_refresh_all()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _process(delta: float) -> void:
	if not visible:
		return
	_update_timer += delta
	if _update_timer >= 0.5:
		_update_timer = 0.0
		_update_research_progress()


func _find_tech_tree() -> void:
	if _tech_tree != null:
		return
	_tech_tree = get_node_or_null("/root/GameWorld/TechnologyTree")
	if _tech_tree == null:
		_tech_tree = get_node_or_null("/root/GameWorld/World/TechnologyTree")


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.name = "MainLayout"
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = 40
	main_hbox.offset_right = -40
	main_hbox.offset_top = 40
	main_hbox.offset_bottom = -40
	main_hbox.add_theme_constant_override("separation", 20)
	add_child(main_hbox)

	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.name = "TechGridPanel"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 8)
	main_hbox.add_child(left_panel)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	left_panel.add_child(header)

	var title: Label = Label.new()
	title.text = "Arbol de Tecnologias"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	_progress_label = Label.new()
	_progress_label.text = ""
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_progress_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ResearchProgress"
	_progress_bar.custom_minimum_size = Vector2(200, 14)
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.visible = false
	left_panel.add_child(_progress_bar)

	_grid = GridContainer.new()
	_grid.name = "TechGrid"
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_grid)

	var close_btn: Button = Button.new()
	close_btn.text = "Cerrar [ESC]"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.pressed.connect(close)
	left_panel.add_child(close_btn)

	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.name = "InfoPanel"
	right_panel.custom_minimum_size = Vector2(220, 0)
	right_panel.add_theme_constant_override("separation", 8)
	main_hbox.add_child(right_panel)

	_info_name = Label.new()
	_info_name.name = "TechName"
	_info_name.add_theme_font_size_override("font_size", 18)
	right_panel.add_child(_info_name)

	_info_desc = Label.new()
	_info_desc.name = "TechDesc"
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.add_theme_font_size_override("font_size", 13)
	_info_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	right_panel.add_child(_info_desc)

	_info_cost = HBoxContainer.new()
	_info_cost.name = "CostRow"
	_info_cost.add_theme_constant_override("separation", 8)
	right_panel.add_child(_info_cost)

	_research_btn = Button.new()
	_research_btn.name = "ResearchButton"
	_research_btn.text = "Investigar"
	_research_btn.custom_minimum_size = Vector2(0, 36)
	_research_btn.pressed.connect(_on_research_pressed)
	right_panel.add_child(_research_btn)


func _refresh_all() -> void:
	if _grid == null:
		return
	for child: Node in _grid.get_children():
		child.queue_free()

	if _tech_tree == null:
		return

	var all_techs: Dictionary = DataManager.get_category_data("technologies")
	if all_techs.is_empty():
		all_techs = _tech_tree.get("researched", {}) if _tech_tree.get("researched") != null else {}

	_build_tech_grid(all_techs)


func _build_tech_grid(all_techs: Dictionary) -> void:
	var player_id: int = GameManager.local_player_id
	var tiers: Dictionary = {}

	for tech_id: Variant in all_techs:
		var tid: String = str(tech_id)
		var data: Dictionary = all_techs[tid]
		if not data is Dictionary:
			continue
		var tier: int = data.get("tier", 1)
		if not tiers.has(tier):
			tiers[tier] = []
		tiers[tier].append({"id": tid, "data": data})

	var sorted_tiers: Array = tiers.keys()
	sorted_tiers.sort()

	for tier: int in sorted_tiers:
		var tier_label: Label = Label.new()
		tier_label.text = "Tier %d" % tier
		var tc: Color = TIER_COLORS[mini(tier - 1, TIER_COLORS.size() - 1)]
		tier_label.add_theme_color_override("font_color", tc)
		tier_label.add_theme_font_size_override("font_size", 13)
		_grid.add_child(tier_label)

		var entries: Array = tiers[tier]
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])

		for entry: Dictionary in entries:
			var tech_id: String = entry["id"]
			var tech_data: Dictionary = entry["data"]
			_add_tech_button(tech_id, tech_data, player_id)

		var filler: Control = Control.new()
		filler.custom_minimum_size = Vector2(0, 0)
		_grid.add_child(filler)


func _add_tech_button(tech_id: String, tech_data: Dictionary, player_id: int) -> void:
	var is_researched: bool = _tech_tree.has_tech(tech_id, player_id)
	var is_researching: bool = _is_currently_researching(tech_id, player_id)
	var can_do: bool = _tech_tree.can_research(tech_id, player_id)

	var btn: Button = Button.new()
	btn.name = tech_id
	btn.custom_minimum_size = Vector2(80, 50)
	btn.tooltip_text = tech_data.get("display_name", tech_id)

	var display: String = tech_data.get("display_name", tech_id)
	if display.length() > 10:
		display = display.substr(0, 9) + "."
	btn.text = display

	if is_researched:
		btn.modulate = RESEARCHED_COLOR
	elif is_researching:
		btn.modulate = RESEARCHING_COLOR
	elif can_do:
		btn.modulate = AVAILABLE_COLOR
	else:
		btn.modulate = LOCKED_COLOR

	btn.pressed.connect(func() -> void: _select_tech(tech_id, tech_data))
	_grid.add_child(btn)


func _select_tech(tech_id: String, tech_data: Dictionary) -> void:
	_selected_tech = tech_id

	if _info_name != null:
		_info_name.text = tech_data.get("display_name", tech_id)

	if _info_desc != null:
		_info_desc.text = tech_data.get("description", "")

	_update_cost_display(tech_data.get("cost", {}))
	_update_research_button(tech_id)


func _update_cost_display(cost: Dictionary) -> void:
	if _info_cost == null:
		return
	for child: Node in _info_cost.get_children():
		child.queue_free()

	for res_type: String in cost:
		var amount: int = cost[res_type]
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 2)
		_info_cost.add_child(hbox)

		var icon_lbl: Label = Label.new()
		icon_lbl.text = ICONS.get(res_type, "?")
		icon_lbl.add_theme_font_size_override("font_size", 14)
		hbox.add_child(icon_lbl)

		var val_lbl: Label = Label.new()
		val_lbl.text = str(amount)
		val_lbl.add_theme_font_size_override("font_size", 14)
		var has_enough: bool = GameManager.can_afford(cost)
		if not has_enough:
			val_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		hbox.add_child(val_lbl)


func _update_research_button(tech_id: String) -> void:
	if _research_btn == null:
		return

	if _tech_tree == null:
		_research_btn.disabled = true
		_research_btn.text = "Sin datos"
		return

	var player_id: int = GameManager.local_player_id
	var is_done: bool = _tech_tree.has_tech(tech_id, player_id)
	var is_res: bool = _is_currently_researching(tech_id, player_id)
	var can_do: bool = _tech_tree.can_research(tech_id, player_id)

	if is_done:
		_research_btn.disabled = true
		_research_btn.text = "Investigado"
	elif is_res:
		_research_btn.disabled = true
		_research_btn.text = "Investigando..."
	elif can_do:
		_research_btn.disabled = false
		_research_btn.text = "Investigar"
	else:
		_research_btn.disabled = true
		_research_btn.text = "Requisitos no cumplidos"


func _on_research_pressed() -> void:
	if _selected_tech.is_empty():
		return
	if _tech_tree == null:
		return
	var player_id: int = GameManager.local_player_id
	_tech_tree.start_research(_selected_tech, -1, player_id)
	_update_research_button(_selected_tech)
	_refresh_all()


func _is_currently_researching(tech_id: String, player_id: int) -> bool:
	if _tech_tree == null:
		return false
	var current: Dictionary = _tech_tree.get_current_research(player_id)
	return current.get("tech_id", "") == tech_id


func _update_research_progress() -> void:
	if _tech_tree == null:
		_find_tech_tree()
		return

	var player_id: int = GameManager.local_player_id
	var current: Dictionary = _tech_tree.get_current_research(player_id)

	if current.is_empty():
		_progress_bar.visible = false
		_progress_label.text = ""
		return

	_progress_bar.visible = true
	var progress: float = _tech_tree.get_research_progress(player_id) * 100.0
	_progress_bar.value = progress

	var tech_id: String = current.get("tech_id", "")
	var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
	var name: String = tech_data.get("display_name", tech_id)
	_progress_label.text = "%s: %d%%" % [name, int(progress)]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			close()
