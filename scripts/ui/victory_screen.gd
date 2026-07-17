extends Control

const VICTORY_COLOR: Color = Color(0.2, 0.9, 0.2)
const DEFEAT_COLOR: Color = Color(0.9, 0.2, 0.2)
const DRAW_COLOR: Color = Color(0.9, 0.9, 0.3)
const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.8)
const PANEL_COLOR: Color = Color(0.08, 0.08, 0.14, 0.95)
const STAT_LABEL_COLOR: Color = Color(0.6, 0.6, 0.6)
const STAT_VALUE_COLOR: Color = Color(0.95, 0.95, 0.95)
const BTN_HOVER_COLOR: Color = Color(0.18, 0.40, 0.94)

var _winner_id: int = -1
var _stats_container: VBoxContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _restart_btn: Button = null
var _menu_btn: Button = null
var _stats: Dictionary = {}


func _ready() -> void:
	_build_ui()
	visible = false


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(480, 420)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(0.3, 0.3, 0.3, 0.6)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 42)
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "Subtitle"
	_subtitle_label.text = "Partida terminada"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.add_theme_color_override("font_color", STAT_LABEL_COLOR)
	vbox.add_child(_subtitle_label)

	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	var stats_title: Label = Label.new()
	stats_title.text = "Estadisticas"
	stats_title.add_theme_font_size_override("font_size", 18)
	stats_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(stats_title)

	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsContainer"
	_stats_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_stats_container)

	var sep2: HSeparator = HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	vbox.add_child(sep2)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_restart_btn = Button.new()
	_restart_btn.name = "RestartButton"
	_restart_btn.text = "Reiniciar"
	_restart_btn.custom_minimum_size = Vector2(140, 44)
	_restart_btn.pressed.connect(_on_restart_pressed)
	btn_row.add_child(_restart_btn)

	_menu_btn = Button.new()
	_menu_btn.name = "MenuButton"
	_menu_btn.text = "Menu Principal"
	_menu_btn.custom_minimum_size = Vector2(140, 44)
	_menu_btn.pressed.connect(_on_menu_pressed)
	btn_row.add_child(_menu_btn)


func show_victory(winner_id: int) -> void:
	_winner_id = winner_id
	_collect_stats()
	_populate_stats()

	if winner_id == GameManager.local_player_id:
		_title_label.text = "VICTORIA"
		_title_label.add_theme_color_override("font_color", VICTORY_COLOR)
		_subtitle_label.text = "Has derrotado a todos los enemigos"
	elif winner_id == -1:
		_title_label.text = "EMPATE"
		_title_label.add_theme_color_override("font_color", DRAW_COLOR)
		_subtitle_label.text = "La partida ha terminado sin vencedor"
	else:
		_title_label.text = "DERROTA"
		_title_label.add_theme_color_override("font_color", DEFEAT_COLOR)
		var winner_name: String = _get_player_name(winner_id)
		_subtitle_label.text = "%s ha conquistado el mapa" % winner_name

	visible = true
	get_tree().paused = true
	_play_title_animation()


func _collect_stats() -> void:
	var local_id: int = GameManager.local_player_id
	var enemy_id: int = _get_enemy_id()

	_stats = {
		"duracion": GameManager.get_game_time_full(),
		"recursos_locales": _sum_resources(local_id),
		"recursos_enemigo": _sum_resources(enemy_id),
		"unidades_creadas": _count_units_created(),
		"edificios_construidos": _count_buildings(),
		"tecnologias": _count_techs(local_id),
	}


func _sum_resources(pid: int) -> int:
	if pid == -1:
		return 0
	var res: Dictionary = GameManager.get_resources(pid)
	var total: int = 0
	for key: String in res:
		total += res[key]
	return total


func _count_units_created() -> int:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	var local_count: int = 0
	for u: Node in units:
		if u.has_method("get") and u.get("player_id") != null:
			if int(u.get("player_id")) == GameManager.local_player_id:
				local_count += 1
	return local_count


func _count_buildings() -> int:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null:
		return 0
	var buildings: Dictionary = bm.get("buildings") if bm.get("buildings") != null else {}
	var count: int = 0
	for id: Variant in buildings:
		var b: Node = buildings[id]
		if is_instance_valid(b) and b.get("player_id") != null:
			if int(b.get("player_id")) == GameManager.local_player_id:
				count += 1
	return count


func _count_techs(pid: int) -> int:
	var tech_tree: Node = get_node_or_null("/root/GameWorld/TechnologyTree")
	if tech_tree == null:
		tech_tree = get_node_or_null("/root/GameWorld/World/TechnologyTree")
	if tech_tree == null:
		return 0
	if tech_tree.has_method("get_researched_techs"):
		return tech_tree.get_researched_techs(pid).size()
	return 0


func _get_enemy_id() -> int:
	for pid: int in GameManager.get_all_player_ids():
		if pid != GameManager.local_player_id:
			return pid
	return -1


func _get_player_name(pid: int) -> String:
	var p: Dictionary = GameManager.get_player(pid)
	return p.get("player_name", "Jugador %d" % pid)


func _populate_stats() -> void:
	for child: Node in _stats_container.get_children():
		child.queue_free()

	var stat_rows: Array[Array] = [
		["Duracion", str(_stats.get("duracion", "00:00"))],
		["Recursos totales", str(_stats.get("recursos_locales", 0))],
		["Unidades vivas", str(_stats.get("unidades_creadas", 0))],
		["Edificios", str(_stats.get("edificios_construidos", 0))],
		["Tecnologias", str(_stats.get("tecnologias", 0))],
	]

	for row: Array in stat_rows:
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		_stats_container.add_child(hbox)

		var key_label: Label = Label.new()
		key_label.text = row[0]
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_label.add_theme_font_size_override("font_size", 14)
		key_label.add_theme_color_override("font_color", STAT_LABEL_COLOR)
		hbox.add_child(key_label)

		var val_label: Label = Label.new()
		val_label.text = row[1]
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_label.add_theme_font_size_override("font_size", 14)
		val_label.add_theme_color_override("font_color", STAT_VALUE_COLOR)
		hbox.add_child(val_label)


func _play_title_animation() -> void:
	_title_label.modulate.a = 0.0
	_title_label.scale = Vector2(0.5, 0.5)
	_title_label.pivot_offset = _title_label.size / 2

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_title_label, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.1)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.return_to_menu()
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
