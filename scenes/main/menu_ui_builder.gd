## Programmatic menu UI builder for Age of Mitos.
##
## This script can be attached to a Control node to programmatically build
## the entire main menu UI in _ready(). Serves as an alternative to .tscn
## scenes for the menu system.
extends Control

# =============================================================================
# Configuration
# =============================================================================

const BUTTON_WIDTH: float = 280.0
const BUTTON_HEIGHT: float = 52.0
const MENU_TITLE: String = "Age of Mitos"
const MENU_SUBTITLE: String = "Civilizations Rise and Fall"
const VERSION_STRING: String = "v0.1.1 - Alpha"

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_full_menu()


func _build_full_menu() -> void:
	_setup_background()
	_setup_center_container()
	_setup_version_label()

# =============================================================================
# Background
# =============================================================================

func _setup_background() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "MenuBackground"
	bg.color = Color(0.06, 0.1, 0.16, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Decorative top gradient bar.
	var top_bar: ColorRect = ColorRect.new()
	top_bar.name = "TopAccent"
	top_bar.color = Color(0.55, 0.42, 0.15, 0.3)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 4
	add_child(top_bar)

	# Decorative bottom bar.
	var bottom_bar: ColorRect = ColorRect.new()
	bottom_bar.name = "BottomAccent"
	bottom_bar.color = Color(0.55, 0.42, 0.15, 0.3)
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -4
	add_child(bottom_bar)

# =============================================================================
# Center Layout
# =============================================================================

func _setup_center_container() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.name = "MenuCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.name = "MenuLayout"
	main_vbox.custom_minimum_size = Vector2(BUTTON_WIDTH + 40, 0)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 14)
	center.add_child(main_vbox)

	_add_title(main_vbox)
	_add_spacer(main_vbox, 30)
	_add_new_game_button(main_vbox)
	_add_continue_button(main_vbox)
	_add_settings_button(main_vbox)
	_add_quit_button(main_vbox)

# =============================================================================
# Title
# =============================================================================

func _add_title(parent: Control) -> void:
	var title: Label = Label.new()
	title.name = "GameTitle"
	title.text = MENU_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.name = "GameSubtitle"
	subtitle.text = MENU_SUBTITLE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	parent.add_child(subtitle)

# =============================================================================
# Buttons
# =============================================================================

func _add_new_game_button(parent: Control) -> void:
	var btn: Button = _make_button("New Game", "NewGameBtn")
	btn.pressed.connect(_on_new_game_pressed)
	parent.add_child(btn)


func _add_continue_button(parent: Control) -> void:
	var btn: Button = _make_button("Continue", "ContinueBtn")
	btn.disabled = not FileAccess.file_exists("user://saves/save_slot_0.json")
	btn.pressed.connect(_on_continue_pressed)
	parent.add_child(btn)


func _add_settings_button(parent: Control) -> void:
	var btn: Button = _make_button("Settings", "SettingsBtn")
	btn.pressed.connect(_on_settings_pressed)
	parent.add_child(btn)


func _add_quit_button(parent: Control) -> void:
	var btn: Button = _make_button("Quit", "QuitBtn")
	btn.pressed.connect(_on_quit_pressed)
	parent.add_child(btn)

# =============================================================================
# Helpers
# =============================================================================

func _make_button(text: String, btn_name: String) -> Button:
	var btn: Button = Button.new()
	btn.name = btn_name
	btn.text = text
	btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_button_theme(btn)
	return btn


func _apply_button_theme(btn: Button) -> void:
	var theme: Theme = btn.get_theme() if btn.theme else Theme.new()
	btn.theme = theme

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.26, 0.38, 0.9)
	normal.border_color = Color(0.55, 0.42, 0.18)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	normal.set_content_margin_all(16)
	theme.set_stylebox("normal", "Button", normal)

	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.35, 0.52, 0.95)
	hover.border_color = Color(0.92, 0.78, 0.38)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(5)
	hover.set_content_margin_all(16)
	theme.set_stylebox("hover", "Button", hover)

	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = Color(0.1, 0.18, 0.28, 1.0)
	pressed.border_color = Color(0.92, 0.78, 0.38)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(5)
	pressed.set_content_margin_all(16)
	theme.set_stylebox("pressed", "Button", pressed)

	var disabled: StyleBoxFlat = StyleBoxFlat.new()
	disabled.bg_color = Color(0.1, 0.12, 0.18, 0.6)
	disabled.border_color = Color(0.25, 0.28, 0.32)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(5)
	disabled.set_content_margin_all(16)
	theme.set_stylebox("disabled", "Button", disabled)

	theme.set_color("font_color", "Button", Color(0.9, 0.88, 0.82))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.7))
	theme.set_color("font_disabled_color", "Button", Color(0.32, 0.35, 0.38))
	theme.set_font_size("font_size", "Button", 18)


func _add_spacer(parent: Control, height: int) -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)


func _setup_version_label() -> void:
	var version: Label = Label.new()
	version.name = "VersionLabel"
	version.text = VERSION_STRING
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 11)
	version.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42))
	version.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	version.offset_top = -28
	version.offset_bottom = -6
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(version)

# =============================================================================
# Callbacks
# =============================================================================

func _on_new_game_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/main/game_world.tscn")


func _on_continue_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/main/game_world.tscn")


func _on_settings_pressed() -> void:
	AudioManager.play_ui_click()
	# Settings is handled by main_menu.gd if that script is also attached.
	# This builder provides a standalone fallback.
	var settings_overlay: Control = get_node_or_null("SettingsOverlay")
	if settings_overlay != null:
		settings_overlay.queue_free()
		return

	var overlay: Control = Control.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 280)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var lbl: Label = Label.new()
	lbl.text = "Settings"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38))
	vbox.add_child(lbl)

	var close: Button = _make_button("Close", "CloseSettings")
	close.pressed.connect(func() -> void: overlay.queue_free())
	vbox.add_child(close)


func _on_quit_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().quit()
