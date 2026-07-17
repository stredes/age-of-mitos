## Context menu that appears on right-click with context-sensitive options.
##
## Shows relevant commands based on what was clicked (unit, building, resource,
## ground) and what is selected. Supports submenus and keyboard navigation.
class_name CommandContextMenu
extends PopupPanel

# =============================================================================
# Signals
# =============================================================================

signal menu_option_selected(option_id: String, data: Dictionary)
signal menu_dismissed()

# =============================================================================
# Configuration
# =============================================================================

@export var max_width: int = 200
@export var item_height: int = 28
@export var icon_size: int = 20

# =============================================================================
# Internal State
# =============================================================================

var _menu_items: Array[Dictionary] = []
var _selected_unit_ids: Array[int] = []
var _click_world_pos: Vector2 = Vector2.ZERO
var _click_target_id: int = -1
var _click_target_type: String = ""  # "unit", "building", "resource", "ground"

var _container: VBoxContainer = null
var _hovered_item: int = -1

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_build_menu_structure()
	visibility_changed.connect(_on_visibility_changed)

# =============================================================================
# UI Construction
# =============================================================================

func _build_menu_structure() -> void:
	_container = VBoxContainer.new()
	_container.name = "MenuContainer"
	_container.custom_minimum_size.x = max_width
	add_child(_container)


func _rebuild_items() -> void:
	for child: Node in _container.get_children():
		child.queue_free()

	_menu_items.clear()

	# Build context-sensitive items.
	match _click_target_type:
		"unit":
			_build_unit_menu()
		"building":
			_build_building_menu()
		"resource":
			_build_resource_menu()
		"ground":
			_build_ground_menu()

	# Add separator and cancel.
	_add_separator()
	_add_item("cancel", "Cancelar", "Esc")

	# Update popup size.
	var total_height: int = _menu_items.size() * item_height + 8
	custom_minimum_size = Vector2(max_width, total_height)
	size = Vector2(max_width, total_height)

# =============================================================================
# Menu Builders
# =============================================================================

func _build_unit_menu() -> void:
	var target_node: Node = _find_node_by_id(_click_target_id, _click_target_type)
	if target_node == null:
		return

	var target_pid: int = target_node.get("player_id") if target_node.get("player_id") != null else -1
	var local_pid: int = GameManager.get_local_player_id()

	# Check if target is enemy.
	var is_enemy: bool = target_pid != local_pid and target_pid != -1

	if is_enemy:
		_add_item("attack", "Atacar", "A")
		_add_item("attack_move", "Mover y Atacar", "Ctrl+A")

		# Check for special targets.
		var utype: String = target_node.get("unit_type") if target_node.get("unit_type") != null else ""
		if utype == "villager":
			_add_item("attack_villager", "Priorizar Aldeano", "")
	elif target_pid == local_pid:
		_add_item("follow", "Seguir", "Ctrl+F")
		_add_item("guard", "Guardar", "G")

		# If we have a villager selected, add harvest options.
		if _has_villager_selected():
			_add_item("gather_from", "Recolectar desde", "")

	# Ability targeting.
	if not is_enemy and _selected_unit_ids.size() == 1:
		var abilities: Array = _get_targetable_abilities(_selected_unit_ids[0])
		for ability: Dictionary in abilities:
			_add_item("ability_%s" % ability["id"], ability["name"], "")


func _build_building_menu() -> void:
	var target_node: Node = _find_node_by_id(_click_target_id, _click_target_type)
	if target_node == null:
		return

	var target_pid: int = target_node.get("player_id") if target_node.get("player_id") != null else -1
	var local_pid: int = GameManager.get_local_player_id()
	var is_enemy: bool = target_pid != local_pid and target_pid != -1

	if is_enemy:
		_add_item("attack_building", "Atacar Edificio", "A")
		_add_item("attack_building_prioritize", "Priorizar Edificio", "")
	else:
		var btype: String = target_node.get("building_type") if target_node.get("building_type") != null else ""

		# Garrison options.
		if _has_villager_selected():
			_add_item("repair", "Reparar", "R")

		# Drop-off options.
		if btype in ["town_center", "mill", "lumber_camp", "mine"]:
			_add_item("gather_wood", "Recolectar Madera", "W")
			_add_item("gather_food", "Recolectar Comida", "F")
			_add_item("gather_stone", "Recolectar Piedra", "T")
			_add_item("gather_gold", "Recolectar Oro", "G")


func _build_resource_menu() -> void:
	var target_node: Node = _find_node_by_id(_click_target_id, _click_target_type)
	if target_node == null:
		return

	if _has_villager_selected():
		_add_item("harvest", "Recolectar", "W/F/T/G")

		var res_type: String = ""
		if target_node.has_method("get"):
			res_type = target_node.get("resource_type") if target_node.get("resource_type") != null else ""

		if not res_type.is_empty():
			match res_type:
				"wood":
					_add_item("harvest_wood", "Recolectar Madera", "W")
				"food":
					_add_item("harvest_food", "Recolectar Comida", "F")
				"stone":
					_add_item("harvest_stone", "Recolectar Piedra", "T")
				"gold":
					_add_item("harvest_gold", "Recolectar Oro", "G")
	else:
		_add_item("move_to", "Mover Aquí", "M")
		_add_item("attack_move_to", "Mover y Atacar", "Ctrl+A")


func _build_ground_menu() -> void:
	_add_item("move", "Mover", "M")
	_add_item("attack_move", "Mover y Atacar", "Ctrl+A")
	_add_item("patrol", "Patrullar", "P")

	if _has_villager_selected():
		_add_item("build", "Construir", "B")

	if _selected_unit_ids.size() > 1:
		_add_item("formation_spread", "Formación Dispersa", "")
		_add_item("formation_close", "Formación Cerrada", "")

# =============================================================================
# Menu Items
# =============================================================================

func _add_item(id: String, label: String, hotkey: String) -> void:
	var item: Dictionary = {"id": id, "label": label, "hotkey": hotkey, "is_separator": false}
	_menu_items.append(item)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.custom_minimum_size.y = item_height
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label_node: Label = Label.new()
	label_node.text = label
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_node.size_flags_vertical = Control.SIZE_CENTER
	hbox.add_child(label_node)

	if not hotkey.is_empty():
		var hotkey_label: Label = Label.new()
		hotkey_label.text = "[%s]" % hotkey
		hotkey_label.add_theme_font_size_override("font_size", 10)
		hotkey_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hotkey_label.size_flags_vertical = Control.SIZE_CENTER
		hbox.add_child(hotkey_label)

	# Hover effect.
	var idx: int = _menu_items.size() - 1
	hbox.mouse_entered.connect(_on_item_hovered.bind(idx))
	hbox.gui_input.connect(_on_item_input.bind(idx))

	_container.add_child(hbox)


func _add_separator() -> void:
	_menu_items.append({"is_separator": true})
	var sep: HSeparator = HSeparator.new()
	sep.custom_minimum_size.y = 4
	_container.add_child(sep)

# =============================================================================
# Public API
# =============================================================================

## Show the context menu at a screen position.
func show_context(screen_pos: Vector2, target_id: int, target_type: String, selected_units: Array[int]) -> void:
	_click_world_pos = screen_pos
	_click_target_id = target_id
	_click_target_type = target_type
	_selected_unit_ids = selected_units.duplicate()

	_rebuild_items()
	popup(Rect2(screen_pos, custom_minimum_size))


## Hide the menu.
func hide_menu() -> void:
	hide()

# =============================================================================
# Input Handling
# =============================================================================

func _on_item_hovered(idx: int) -> void:
	_hovered_item = idx
	# Highlight hovered item.
	for i in range(_container.get_child_count()):
		var child: Node = _container.get_child(i)
		if child is HBoxContainer:
			if i == idx:
				child.modulate = Color(1.2, 1.2, 0.8, 1.0)
			else:
				child.modulate = Color.WHITE


func _on_item_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_select_item(idx)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_menu()
		menu_dismissed.emit()
		get_viewport().set_input_as_handled()
		return

	# Keyboard navigation.
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key: int = (event as InputEventKey).keycode
		if key == KEY_UP:
			_hovered_item = maxi(_hovered_item - 1, 0)
			_on_item_hovered(_hovered_item)
			get_viewport().set_input_as_handled()
		elif key == KEY_DOWN:
			_hovered_item = mini(_hovered_item + 1, _menu_items.size() - 1)
			_on_item_hovered(_hovered_item)
			get_viewport().set_input_as_handled()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			if _hovered_item >= 0 and _hovered_item < _menu_items.size():
				_select_item(_hovered_item)
			get_viewport().set_input_as_handled()


func _select_item(idx: int) -> void:
	if idx < 0 or idx >= _menu_items.size():
		return

	var item: Dictionary = _menu_items[idx]
	if item.get("is_separator", false):
		return

	var option_id: String = item["id"]

	if option_id == "cancel":
		hide_menu()
		menu_dismissed.emit()
		return

	var data: Dictionary = {
		"target_id": _click_target_id,
		"target_type": _click_target_type,
		"world_pos": _click_world_pos,
		"selected_units": _selected_unit_ids,
	}

	menu_option_selected.emit(option_id, data)
	hide_menu()

# =============================================================================
# Helpers
# =============================================================================

func _on_visibility_changed() -> void:
	if not visible:
		_hovered_item = -1


func _find_node_by_id(id: int, type: String) -> Node:
	match type:
		"unit":
			var units: Array[Node] = get_tree().get_nodes_in_group("units")
			for unit: Node in units:
				if unit.get("unit_id") != null and int(unit.get("unit_id")) == id:
					return unit
		"building":
			var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
			if bm == null:
				bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
			if bm != null and bm.has_method("get_building"):
				return bm.get_building(id)
		"resource":
			var resources: Array[Node] = get_tree().get_nodes_in_group("resources")
			for res: Node in resources:
				if res.get("resource_id") != null and int(res.get("resource_id")) == id:
					return res
	return null


func _has_villager_selected() -> bool:
	for uid: int in _selected_unit_ids:
		var node: Node = _find_node_by_id(uid, "unit")
		if node != null:
			var utype: String = node.get("unit_type") if node.get("unit_type") != null else ""
			if utype == "villager" or utype == "lumberjack" or utype == "miner" or utype == "builder":
				return true
	return false


func _get_targetable_abilities(unit_id: int) -> Array:
	var node: Node = _find_node_by_id(unit_id, "unit")
	if node == null:
		return []
	var utype: String = node.get("unit_type") if node.get("unit_type") != null else ""
	var ability_sys: Node = get_node_or_null("/root/GameWorld/AbilitySystem")
	if ability_sys == null:
		return []
	return ability_sys.get_available_abilities(unit_id, utype)
