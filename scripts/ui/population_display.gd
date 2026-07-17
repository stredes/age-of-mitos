## Population display with visual bar and alert animation.
##
## Shows current/max population with color-coded progress bar.
## Pulses red when at capacity. Counts units and buildings periodically.
extends PanelContainer

var _icon: TextureRect = null
var _label: Label = null
var _bar: ProgressBar = null
var _alert_tween: Tween = null

var _current_pop: int = 0
var _max_pop: int = 0
var _is_at_cap: bool = false
var _update_timer: float = 0.0
var _update_interval: float = 0.5

var _icon_factory: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_find_icon_factory()
	_update_population()

	if not EventBus.unit_spawned.is_connected(_on_unit_spawned):
		EventBus.unit_spawned.connect(_on_unit_spawned)
	if not EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.connect(_on_unit_died)
	if not EventBus.building_completed.is_connected(_on_building_completed):
		EventBus.building_completed.connect(_on_building_completed)
	if not EventBus.building_destroyed.is_connected(_on_building_destroyed):
		EventBus.building_destroyed.connect(_on_building_destroyed)


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		_update_population()


func _build_ui() -> void:
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.14, 0.7)
	bg_style.set_corner_radius_all(10)
	bg_style.content_margin_left = 8
	bg_style.content_margin_right = 8
	bg_style.content_margin_top = 3
	bg_style.content_margin_bottom = 3
	add_theme_stylebox_override("panel", bg_style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "Layout"
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(_icon)

	_label = Label.new()
	_label.name = "Label"
	_label.text = "0 / 0"
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	hbox.add_child(_label)

	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.custom_minimum_size = Vector2(60, 8)
	_bar.max_value = 100
	_bar.value = 0
	_bar.show_percentage = false
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	bar_bg.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.75, 0.2)
	bar_fill.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("fill", bar_fill)

	hbox.add_child(_bar)


func _find_icon_factory() -> void:
	_icon_factory = get_node_or_null("/root/GameWorld/UILayer/ResourceIconFactory")
	if _icon_factory == null:
		_icon_factory = get_node_or_null("/root/GameWorld/ResourceIconFactory")


func _update_population() -> void:
	_current_pop = _count_units()
	_max_pop = _calculate_max_pop()

	if _label:
		_label.text = "%d / %d" % [_current_pop, _max_pop]

	if _icon_factory and _icon_factory.has_method("get_icon"):
		_icon.texture = _icon_factory.get_icon("population", 16)

	var ratio: float = float(_current_pop) / float(_max_pop) if _max_pop > 0 else 0.0
	if _bar:
		_bar.max_value = _max_pop
		_bar.value = _current_pop
		var fill: StyleBoxFlat = _bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			if ratio < 0.66:
				fill.bg_color = Color(0.2, 0.75, 0.2)
			elif ratio < 0.85:
				fill.bg_color = Color(0.85, 0.8, 0.2)
			else:
				fill.bg_color = Color(0.85, 0.2, 0.2)

	var was_at_cap: bool = _is_at_cap
	_is_at_cap = _current_pop >= _max_pop and _max_pop > 0

	if _is_at_cap and not was_at_cap:
		_start_alert_pulse()
	elif not _is_at_cap and was_at_cap:
		_stop_alert_pulse()


func _count_units() -> int:
	var player_id: int = GameManager.local_player_id
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	var count: int = 0
	for unit: Node in units:
		if unit.has_method("get") and unit.get("player_id") != null:
			if unit.get("player_id") == player_id:
				count += 1
	return count


func _calculate_max_pop() -> int:
	var player_id: int = GameManager.local_player_id
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null:
		return 10

	var total: int = 0
	var buildings: Array = []
	if bm.has_method("get_player_buildings"):
		buildings = bm.get_player_buildings(player_id)
	elif bm.get("buildings") != null:
		for id_variant: Variant in bm.get("buildings"):
			var bld: Node = bm.get("buildings")[id_variant]
			if is_instance_valid(bld) and bld.get("player_id") == player_id:
				buildings.append(bld)

	for bld: Node in buildings:
		if not is_instance_valid(bld):
			continue
		var is_constructed: bool = bld.get("is_constructed") if bld.get("is_constructed") != null else true
		if not is_constructed:
			continue
		var b_type: String = bld.get("building_type") if bld.get("building_type") != null else ""
		var b_data: Dictionary = DataManager.get_building_data(b_type)
		total += b_data.get("pop_add", 0)

	return maxi(total, 10)


func _start_alert_pulse() -> void:
	if _label:
		_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()
	_alert_tween = create_tween().set_loops()
	_alert_tween.tween_property(self, "modulate", Color(1.3, 0.8, 0.8, 1.0), 0.4)
	_alert_tween.tween_property(self, "modulate", Color.WHITE, 0.4)


func _stop_alert_pulse() -> void:
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()
	_alert_tween = null
	modulate = Color.WHITE
	if _label:
		_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))


func _on_unit_spawned(_unit_id: int, _unit_type: String, player_id: int, _position: Vector2) -> void:
	if player_id == GameManager.local_player_id:
		_update_population()


func _on_unit_died(_unit_id: int, _killer_id: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		_update_population()


func _on_building_completed(_building_id: int, player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		_update_population()


func _on_building_destroyed(_building_id: int, player_id: int, _destroyer_id: int) -> void:
	if player_id == GameManager.local_player_id:
		_update_population()
