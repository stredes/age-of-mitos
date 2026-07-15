## Main menu screen for Age of Mitos.
##
## Provides New Game, Continue, Settings, and Quit buttons.
## Checks for existing saves to enable/disable the Continue button.
extends Control

# =============================================================================
# Properties
# =============================================================================

var _settings_panel: Control = null
var _is_settings_open: bool = false

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_build_ui()
	_update_continue_button()
	_apply_styling()

# =============================================================================
# UI Building
# =============================================================================

func _build_ui() -> void:
	# Full-screen background.
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.12, 0.18, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Center container.
	var center: CenterContainer = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Main vertical layout.
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.custom_minimum_size = Vector2(400, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# Title.
	var title: Label = Label.new()
	title.name = "Title"
	title.text = "Age of Mitos"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38))
	vbox.add_child(title)

	# Subtitle.
	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Civilizations Rise and Fall"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	subtitle.add_theme_constant_override("margin_top", -8)
	vbox.add_child(subtitle)

	# Spacer.
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	# New Game button.
	var new_game_btn: Button = _create_button("New Game", "NewGameBtn")
	new_game_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_game_btn)

	# Continue button.
	var continue_btn: Button = _create_button("Continue", "ContinueBtn")
	continue_btn.pressed.connect(_on_continue)
	vbox.add_child(continue_btn)

	# Settings button.
	var settings_btn: Button = _create_button("Settings", "SettingsBtn")
	settings_btn.pressed.connect(_on_settings)
	vbox.add_child(settings_btn)

	# Quit button.
	var quit_btn: Button = _create_button("Quit", "QuitBtn")
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)

	# Version label (bottom center).
	var version: Label = Label.new()
	version.name = "Version"
	version.text = "v0.1.0 - Alpha"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	version.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	version.offset_top = -30
	version.offset_bottom = -8
	add_child(version)


func _create_button(text: String, btn_name: String) -> Button:
	var btn: Button = Button.new()
	btn.name = btn_name
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return btn

# =============================================================================
# Styling
# =============================================================================

func _apply_styling() -> void:
	var theme: Theme = Theme.new()

	# Button normal.
	var btn_normal: StyleBoxFlat = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.28, 0.42, 0.9)
	btn_normal.border_color = Color(0.55, 0.45, 0.2)
	btn_normal.border_width_bottom = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_left = 20
	btn_normal.content_margin_right = 20
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", btn_normal)

	# Button hover.
	var btn_hover: StyleBoxFlat = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.38, 0.55, 0.95)
	btn_hover.border_color = Color(0.92, 0.78, 0.38)
	btn_hover.border_width_bottom = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	btn_hover.content_margin_left = 20
	btn_hover.content_margin_right = 20
	btn_hover.content_margin_top = 8
	btn_hover.content_margin_bottom = 8
	theme.set_stylebox("hover", "Button", btn_hover)

	# Button pressed.
	var btn_pressed: StyleBoxFlat = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.12, 0.2, 0.32, 1.0)
	btn_pressed.border_color = Color(0.92, 0.78, 0.38)
	btn_pressed.border_width_bottom = 2
	btn_pressed.border_width_top = 2
	btn_pressed.border_width_left = 2
	btn_pressed.border_width_right = 2
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_left = 6
	btn_pressed.corner_radius_bottom_right = 6
	btn_pressed.content_margin_left = 20
	btn_pressed.content_margin_right = 20
	btn_pressed.content_margin_top = 8
	btn_pressed.content_margin_bottom = 8
	theme.set_stylebox("pressed", "Button", btn_pressed)

	# Button disabled.
	var btn_disabled: StyleBoxFlat = StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.12, 0.15, 0.2, 0.7)
	btn_disabled.border_color = Color(0.3, 0.3, 0.35)
	btn_disabled.border_width_bottom = 1
	btn_disabled.border_width_top = 1
	btn_disabled.border_width_left = 1
	btn_disabled.border_width_right = 1
	btn_disabled.corner_radius_top_left = 6
	btn_disabled.corner_radius_top_right = 6
	btn_disabled.corner_radius_bottom_left = 6
	btn_disabled.corner_radius_bottom_right = 6
	btn_disabled.content_margin_left = 20
	btn_disabled.content_margin_right = 20
	btn_disabled.content_margin_top = 8
	btn_disabled.content_margin_bottom = 8
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# Button font colors.
	theme.set_color("font_color", "Button", Color(0.9, 0.88, 0.8))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.7))
	theme.set_color("font_disabled_color", "Button", Color(0.35, 0.35, 0.4))
	theme.set_font_size("font_size", "Button", 20)

	# Panel.
	var panel_bg: StyleBoxFlat = StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.1, 0.14, 0.2, 0.95)
	panel_bg.border_color = Color(0.55, 0.45, 0.2)
	panel_bg.border_width_bottom = 2
	panel_bg.border_width_top = 2
	panel_bg.border_width_left = 2
	panel_bg.border_width_right = 2
	panel_bg.corner_radius_top_left = 8
	panel_bg.corner_radius_top_right = 8
	panel_bg.corner_radius_bottom_left = 8
	panel_bg.corner_radius_bottom_right = 8
	panel_bg.content_margin_left = 16
	panel_bg.content_margin_right = 16
	panel_bg.content_margin_top = 16
	panel_bg.content_margin_bottom = 16
	theme.set_stylebox("panel", "PanelContainer", panel_bg)

	theme.set_color("font_color", "Label", Color(0.85, 0.85, 0.9))

	apply_theme(theme)

# =============================================================================
# Button Callbacks
# =============================================================================

func _on_new_game() -> void:
	AudioManager.play_ui_click()
	GameManager.start_game(2, 1)
	get_tree().change_scene_to_file("res://scenes/main/game_world.tscn")


func _on_continue() -> void:
	AudioManager.play_ui_click()
	if SaveManager.save_exists(0):
		SaveManager.load_game(0)
		get_tree().change_scene_to_file("res://scenes/main/game_world.tscn")


func _on_settings() -> void:
	AudioManager.play_ui_click()
	_toggle_settings_panel()


func _on_quit() -> void:
	AudioManager.play_ui_click()
	get_tree().quit()

# =============================================================================
# Settings Panel
# =============================================================================

func _toggle_settings_panel() -> void:
	if _is_settings_open:
		if _settings_panel != null and is_instance_valid(_settings_panel):
			_settings_panel.queue_free()
			_settings_panel = null
		_is_settings_open = false
		return

	_settings_panel = Control.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings_panel)

	# Overlay background.
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.add_child(overlay)

	# Center container.
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.add_child(center)

	# Panel container.
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 320)
	center.add_child(panel)

	# Panel content.
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "SettingsContent"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Settings title.
	var settings_title: Label = Label.new()
	settings_title.text = "Settings"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 28)
	settings_title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38))
	vbox.add_child(settings_title)

	# Master Volume.
	_add_slider_row(vbox, "Master Volume", "Master", 1.0)

	# Music Volume.
	_add_slider_row(vbox, "Music Volume", "Music", 0.8)

	# SFX Volume.
	_add_slider_row(vbox, "SFX Volume", "SFX", 0.8)

	# Auto-save toggle.
	var auto_save_row: HBoxContainer = HBoxContainer.new()
	auto_save_row.add_theme_constant_override("separation", 12)
	vbox.add_child(auto_save_row)

	var auto_save_label: Label = Label.new()
	auto_save_label.text = "Auto-Save (5 min)"
	auto_save_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_save_label.add_theme_font_size_override("font_size", 16)
	auto_save_row.add_child(auto_save_label)

	var auto_save_check: CheckBox = CheckBox.new()
	auto_save_check.button_pressed = SaveManager.is_auto_save_enabled()
	auto_save_check.toggled.connect(func(pressed: bool) -> void: SaveManager.set_auto_save_enabled(pressed))
	auto_save_row.add_child(auto_save_check)

	# Spacer.
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Close button.
	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(200, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_toggle_settings_panel)
	vbox.add_child(close_btn)

	_is_settings_open = true


func _add_slider_row(parent: Control, label_text: String, bus_name: String, default_volume: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = AudioManager.get_volume(bus_name)
	slider.custom_minimum_size = Vector2(150, 0)
	slider.value_changed.connect(func(val: float) -> void: AudioManager.set_volume(bus_name, val))
	row.add_child(slider)

	var value_label: Label = Label.new()
	value_label.text = "%d%%" % int(slider.value * 100)
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.add_theme_font_size_override("font_size", 14)
	row.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void: value_label.text = "%d%%" % int(val * 100))

# =============================================================================
# Save State Check
# =============================================================================

func _update_continue_button() -> void:
	var continue_btn: Button = get_node_or_null("CenterContainer/MainVBox/ContinueBtn")
	if continue_btn == null:
		return
	continue_btn.disabled = not SaveManager.has_saves()
