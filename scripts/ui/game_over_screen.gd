## Game over screen shown when a player loses all buildings.
## Displays victory/defeat, match duration, and buttons for rematch or main menu.
class_name GameOverScreen
extends Control

var _winner_id: int = -1
var _elapsed_time: float = 0.0

var _title_label: Label = null
var _subtitle_label: Label = null
var _duration_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(winner_id: int, elapsed_time: float) -> void:
	_winner_id = winner_id
	_elapsed_time = elapsed_time
	_build_ui()


func _build_ui() -> void:
	for child: Node in get_children():
		child.queue_free()

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_add_spacer(vbox, 24)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.add_theme_color_override("font_color", _get_title_color())
	_title_label.text = _get_title_text()
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_subtitle_label.text = "Fin de la partida"
	vbox.add_child(_subtitle_label)

	_add_spacer(vbox, 8)

	_duration_label = Label.new()
	_duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duration_label.add_theme_font_size_override("font_size", 16)
	_duration_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	_duration_label.text = "Duracion: %s" % _format_duration(_elapsed_time)
	vbox.add_child(_duration_label)

	_add_spacer(vbox, 16)

	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_container)

	var rematch_btn: Button = _make_button("Revancha", Color(0.2, 0.55, 0.3))
	rematch_btn.pressed.connect(_on_rematch_pressed)
	btn_container.add_child(rematch_btn)

	var menu_btn: Button = _make_button("Menu Principal", Color(0.45, 0.3, 0.2))
	menu_btn.pressed.connect(_on_menu_pressed)
	btn_container.add_child(menu_btn)


func _make_button(label_text: String, bg_color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(160, 52)

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style: StyleBoxFlat = normal.duplicate()
	pressed_style.bg_color = bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

	return btn


func _on_rematch_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene.call_deferred()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.return_to_menu()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main/main_menu.tscn")


func _get_title_text() -> String:
	if _winner_id == -1:
		return "EMPATE"
	if _winner_id == GameManager.get_local_player_id():
		return "VICTORIA"
	return "DERROTA"


func _get_title_color() -> Color:
	if _winner_id == -1:
		return Color(0.85, 0.75, 0.2)
	if _winner_id == GameManager.get_local_player_id():
		return Color(0.2, 0.85, 0.3)
	return Color(0.9, 0.2, 0.2)


func _format_duration(seconds: float) -> String:
	var total: int = int(seconds)
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if h > 0:
		return "%02d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]


func _add_spacer(parent: VBoxContainer, height: int) -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
