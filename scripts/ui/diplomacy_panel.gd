extends Control

const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.85)
const PANEL_COLOR: Color = Color(0.08, 0.08, 0.14, 0.95)
const ALLY_COLOR: Color = Color(0.2, 0.8, 0.3)
const ENEMY_COLOR: Color = Color(0.9, 0.2, 0.2)
const NEUTRAL_COLOR: Color = Color(0.6, 0.6, 0.6)
const PLAYER_COLORS: Array[Color] = [
	Color(0.18, 0.40, 0.94),
	Color(0.84, 0.18, 0.14),
	Color(0.16, 0.62, 0.24),
	Color(0.85, 0.72, 0.18),
	Color(0.72, 0.56, 0.24),
	Color(0.55, 0.27, 0.07),
	Color(0.4, 0.6, 0.9),
	Color(0.9, 0.5, 0.1),
]

enum Relation { ALLY, NEUTRAL, ENEMY }

var _relations: Dictionary = {}
var _player_list: VBoxContainer = null
var _info_label: Label = null
var _selected_player_id: int = -1


func _ready() -> void:
	_build_ui()
	visible = false


func open() -> void:
	_init_relations()
	_refresh_player_list()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func get_relation(from_id: int, to_id: int) -> int:
	var key: String = _key(from_id, to_id)
	return _relations.get(key, Relation.NEUTRAL)


func is_ally(from_id: int, to_id: int) -> bool:
	return get_relation(from_id, to_id) == Relation.ALLY


func is_enemy(from_id: int, to_id: int) -> bool:
	return get_relation(from_id, to_id) == Relation.ENEMY


func _key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]


func _init_relations() -> void:
	if not _relations.is_empty():
		return
	var ids: Array = GameManager.get_all_player_ids()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: int = int(ids[i])
			var b: int = int(ids[j])
			if GameManager.is_ai_player(a) and GameManager.is_ai_player(b):
				_relations[_key(a, b)] = Relation.ALLY
			else:
				_relations[_key(a, b)] = Relation.NEUTRAL


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
	panel.custom_minimum_size = Vector2(520, 380)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "Layout"
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	var left: VBoxContainer = VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	hbox.add_child(left)

	var title: Label = Label.new()
	title.text = "Diplomacia"
	title.add_theme_font_size_override("font_size", 22)
	left.add_child(title)

	var sep: HSeparator = HSeparator.new()
	left.add_child(sep)

	_player_list = VBoxContainer.new()
	_player_list.name = "PlayerList"
	_player_list.add_theme_constant_override("separation", 4)
	left.add_child(_player_list)

	var right: VBoxContainer = VBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size = Vector2(180, 0)
	right.add_theme_constant_override("separation", 8)
	hbox.add_child(right)

	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.text = "Selecciona un jugador"
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	right.add_child(_info_label)

	var sep2: HSeparator = HSeparator.new()
	right.add_child(sep2)

	var btn_ally: Button = Button.new()
	btn_ally.text = "Aliarse"
	btn_ally.custom_minimum_size = Vector2(0, 34)
	btn_ally.pressed.connect(_on_ally_pressed)
	right.add_child(btn_ally)

	var btn_neutral: Button = Button.new()
	btn_neutral.text = "Neutral"
	btn_neutral.custom_minimum_size = Vector2(0, 34)
	btn_neutral.pressed.connect(_on_neutral_pressed)
	right.add_child(btn_neutral)

	var btn_enemy: Button = Button.new()
	btn_enemy.text = "Declarar Guerra"
	btn_enemy.custom_minimum_size = Vector2(0, 34)
	btn_enemy.pressed.connect(_on_enemy_pressed)
	right.add_child(btn_enemy)

	var sep3: HSeparator = HSeparator.new()
	right.add_child(sep3)

	var close_btn: Button = Button.new()
	close_btn.text = "Cerrar [ESC]"
	close_btn.custom_minimum_size = Vector2(0, 34)
	close_btn.pressed.connect(close)
	right.add_child(close_btn)


func _refresh_player_list() -> void:
	if _player_list == null:
		return
	for child: Node in _player_list.get_children():
		child.queue_free()

	var local_id: int = GameManager.local_player_id
	for pid: int in GameManager.get_all_player_ids():
		if pid == local_id:
			continue

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_player_list.add_child(row)

		var color_dot: ColorRect = ColorRect.new()
		color_dot.custom_minimum_size = Vector2(10, 10)
		var pc: Color = PLAYER_COLORS[mini(pid - 1, PLAYER_COLORS.size() - 1)]
		color_dot.color = pc
		row.add_child(color_dot)

		var name_lbl: Label = Label.new()
		var p_data: Dictionary = GameManager.get_player(pid)
		name_lbl.text = p_data.get("player_name", "Jugador %d" % pid)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)

		var rel: int = get_relation(local_id, pid)
		var status_lbl: Label = Label.new()
		status_lbl.add_theme_font_size_override("font_size", 12)
		match rel:
			Relation.ALLY:
				status_lbl.text = "Aliado"
				status_lbl.add_theme_color_override("font_color", ALLY_COLOR)
			Relation.ENEMY:
				status_lbl.text = "Enemigo"
				status_lbl.add_theme_color_override("font_color", ENEMY_COLOR)
			_:
				status_lbl.text = "Neutral"
				status_lbl.add_theme_color_override("font_color", NEUTRAL_COLOR)
		row.add_child(status_lbl)

		var btn: Button = Button.new()
		btn.text = ">"
		btn.custom_minimum_size = Vector2(28, 24)
		var target_id: int = pid
		btn.pressed.connect(func() -> void: _select_player(target_id))
		row.add_child(btn)


func _select_player(pid: int) -> void:
	_selected_player_id = pid
	if _info_label == null:
		return

	var p_data: Dictionary = GameManager.get_player(pid)
	var p_name: String = p_data.get("player_name", "Jugador %d" % pid)
	var is_ai: bool = GameManager.is_ai_player(pid)
	var rel: int = get_relation(GameManager.local_player_id, pid)

	var lines: PackedStringArray = [
		p_name,
		"Tipo: " + ("IA" if is_ai else "Humano"),
		"Relacion: ",
	]
	match rel:
		Relation.ALLY:
			lines[2] += "Aliado"
		Relation.ENEMY:
			lines[2] += "Enemigo"
		_:
			lines[2] += "Neutral"

	_info_label.text = "\n".join(lines)


func _on_ally_pressed() -> void:
	if _selected_player_id == -1:
		return
	_set_relation(GameManager.local_player_id, _selected_player_id, Relation.ALLY)
	_refresh_player_list()
	_select_player(_selected_player_id)


func _on_neutral_pressed() -> void:
	if _selected_player_id == -1:
		return
	_set_relation(GameManager.local_player_id, _selected_player_id, Relation.NEUTRAL)
	_refresh_player_list()
	_select_player(_selected_player_id)


func _on_enemy_pressed() -> void:
	if _selected_player_id == -1:
		return
	_set_relation(GameManager.local_player_id, _selected_player_id, Relation.ENEMY)
	_refresh_player_list()
	_select_player(_selected_player_id)


func _set_relation(a: int, b: int, rel: int) -> void:
	_relations[_key(a, b)] = rel


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
