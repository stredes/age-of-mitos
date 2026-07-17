## Command card UI panel that shows available actions for selected units/buildings.
##
## Displays a grid of command buttons (move, stop, attack, build, train, abilities)
## with hotkey labels, cooldown indicators, and disabled state reasons.
class_name CommandCard
extends PanelContainer

# =============================================================================
# Signals
# =============================================================================

signal command_issued(command: String, data: Dictionary)
signal command_hovered(command: String)

# =============================================================================
# Configuration
# =============================================================================

## Grid layout.
@export var columns: int = 5
@export var button_size: Vector2 = Vector2(48, 48)
@export var button_spacing: int = 4

# =============================================================================
# Internal State
# =============================================================================

var _buttons: Dictionary = {}  # command_id → Button
var _current_context: String = ""  # "unit", "building", "none"
var _current_unit_type: String = ""
var _current_building_type: String = ""

## Button texture paths.
var _icon_paths: Dictionary = {
	"move": "res://assets/ui/icons/cmd_move.png",
	"stop": "res://assets/ui/icons/cmd_stop.png",
	"attack": "res://assets/ui/icons/cmd_attack.png",
	"harvest_wood": "res://assets/ui/icons/cmd_wood.png",
	"harvest_food": "res://assets/ui/icons/cmd_food.png",
	"harvest_stone": "res://assets/ui/icons/cmd_stone.png",
	"harvest_gold": "res://assets/ui/icons/cmd_gold.png",
	"build": "res://assets/ui/icons/cmd_build.png",
	"patrol": "res://assets/ui/icons/cmd_patrol.png",
	"guard": "res://assets/ui/icons/cmd_guard.png",
}

## Hotkey bindings for display.
var _hotkeys: Dictionary = {
	"move": "M",
	"stop": "S",
	"attack": "A",
	"build": "B",
	"harvest_wood": "W",
	"harvest_food": "F",
	"harvest_stone": "T",
	"harvest_gold": "G",
	"patrol": "P",
	"guard": "G",
}

## Default commands shown for any selection.
var _universal_commands: Array[Dictionary] = [
	{"id": "move", "label": "Mover", "tooltip": "Mover unidad (M)"},
	{"id": "stop", "label": "Detener", "tooltip": "Detener unidad (S)"},
	{"id": "attack", "label": "Atacar", "tooltip": "Atacar objetivo (A)"},
	{"id": "patrol", "label": "Patrullar", "tooltip": "Patrullar zona (P)"},
	{"id": "guard", "label": "Guardar", "tooltip": "Custodiar unidad (G)"},
]

## Civil unit commands.
var _civil_commands: Array[Dictionary] = [
	{"id": "harvest_wood", "label": "Madera", "tooltip": "Recolectar madera (W)"},
	{"id": "harvest_food", "label": "Comida", "tooltip": "Recolectar comida (F)"},
	{"id": "harvest_stone", "label": "Piedra", "tooltip": "Recolectar piedra (T)"},
	{"id": "harvest_gold", "label": "Oro", "tooltip": "Recolectar oro (G)"},
	{"id": "build", "label": "Construir", "tooltip": "Construir edificio (B)"},
]

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_build_ui()
	_clear_commands()
	if not EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.connect(_on_selection_changed)

# =============================================================================
# UI Construction
# =============================================================================

func _build_ui() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.name = "CommandGrid"
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", button_spacing)
	grid.add_theme_constant_override("v_separation", button_spacing)
	add_child(grid)


func _create_button(command: Dictionary) -> Button:
	var btn: Button = Button.new()
	btn.name = "Cmd_%s" % command["id"]
	btn.custom_minimum_size = button_size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.tooltip_text = command.get("tooltip", "")

	# Icon.
	var icon_path: String = _icon_paths.get(command["id"], "")
	if ResourceLoader.exists(icon_path):
		btn.icon = load(icon_path)
		btn.icon_display_mode = Button.ICON_DISPLAY_TOP

	# Label below icon.
	btn.text = command.get("label", "")
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Hotkey label.
	var hotkey: String = _hotkeys.get(command["id"], "")
	if not hotkey.is_empty():
		btn.text = "%s\n[%s]" % [command.get("label", ""), hotkey]

	# Style.
	btn.add_theme_font_size_override("font_size", 10)

	# Connect.
	btn.pressed.connect(_on_command_pressed.bind(command["id"]))
	btn.mouse_entered.connect(_on_command_hovered.bind(command["id"]))

	return btn

# =============================================================================
# Command Management
# =============================================================================

func set_unit_commands(unit_type: String) -> void:
	_clear_commands()
	_current_context = "unit"
	_current_unit_type = unit_type

	var grid: GridContainer = get_node_or_null("CommandGrid")
	if grid == null:
		return

	# Universal commands.
	for cmd: Dictionary in _universal_commands:
		var btn: Button = _create_button(cmd)
		grid.add_child(btn)
		_buttons[cmd["id"]] = btn

	# Civil-specific commands.
	var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
	var category: String = unit_data.get("unit_category", "")
	if category == "civil":
		for cmd: Dictionary in _civil_commands:
			var btn: Button = _create_button(cmd)
			grid.add_child(btn)
			_buttons[cmd["id"]] = btn


func set_building_commands(building_type: String) -> void:
	_clear_commands()
	_current_context = "building"
	_current_building_type = building_type

	var grid: GridContainer = get_node_or_null("CommandGrid")
	if grid == null:
		return

	var b_data: Dictionary = DataManager.get_building_data(building_type)

	# Production commands.
	var produces: Array = b_data.get("produces", [])
	for item: Variant in produces:
		var item_type: String = str(item)
		var item_data: Dictionary = DataManager.get_unit_data(item_type)
		if item_data.is_empty():
			item_data = DataManager.get_tech_data(item_type)
		var display: String = item_data.get("display_name", item_type) if not item_data.is_empty() else item_type
		var cmd: Dictionary = {
			"id": "train_%s" % item_type,
			"label": display,
			"tooltip": "Entrenar %s" % display,
			"data": {"item_type": item_type},
		}
		var btn: Button = _create_button(cmd)
		grid.add_child(btn)
		_buttons[cmd["id"]] = btn

	# Technology commands.
	var techs: Array = b_data.get("technologies", [])
	for tech: Variant in techs:
		var tech_id: String = str(tech)
		var tech_data: Dictionary = DataManager.get_tech_data(tech_id)
		var display: String = tech_data.get("display_name", tech_id) if not tech_data.is_empty() else tech_id
		var cmd: Dictionary = {
			"id": "research_%s" % tech_id,
			"label": display,
			"tooltip": "Investigar %s" % display,
			"data": {"tech_id": tech_id},
		}
		var btn: Button = _create_button(cmd)
		grid.add_child(btn)
		_buttons[cmd["id"]] = btn


func set_ability_commands(unit_id: int, unit_type: String) -> void:
	var ability_sys: Node = get_node_or_null("/root/GameWorld/AbilitySystem")
	if ability_sys == null:
		return

	var abilities: Array = ability_sys.get_available_abilities(unit_id, unit_type)
	var grid: GridContainer = get_node_or_null("CommandGrid")
	if grid == null:
		return

	for ability: Dictionary in abilities:
		var cmd: Dictionary = {
			"id": "ability_%s" % ability["id"],
			"label": ability["name"],
			"tooltip": "%s (CD: %.1fs)" % [ability["name"], ability["cooldown_remaining"]],
			"data": {"ability_id": ability["id"]},
		}
		var btn: Button = _create_button(cmd)
		grid.add_child(btn)
		_buttons[cmd["id"]] = btn

		# Cooldown visual.
		if ability["on_cooldown"]:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.8)

		# Mana insufficient.
		if ability["mana_cost"] > 0 and not ability["has_enough_mana"]:
			btn.disabled = true
			btn.modulate = Color(0.3, 0.3, 0.8, 0.8)


func _clear_commands() -> void:
	var grid: GridContainer = get_node_or_null("CommandGrid")
	if grid != null:
		for child: Node in grid.get_children():
			child.queue_free()
	_buttons.clear()
	_current_context = "none"
	_current_unit_type = ""
	_current_building_type = ""

# =============================================================================
# Button State Updates
# =============================================================================

func set_button_enabled(command_id: String, enabled: bool) -> void:
	if _buttons.has(command_id):
		_buttons[command_id].disabled = not enabled


func set_button_cooldown(command_id: String, cooldown_percent: float) -> void:
	if not _buttons.has(command_id):
		return
	var btn: Button = _buttons[command_id]
	if cooldown_percent > 0.0:
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.8)
		btn.tooltip_text = "%s (Cooldown: %.1f%%)" % [btn.tooltip_text, cooldown_percent * 100.0]
	else:
		btn.disabled = false
		btn.modulate = Color.WHITE


func set_button_highlight(command_id: String, highlight: bool) -> void:
	if _buttons.has(command_id):
		var btn: Button = _buttons[command_id]
		if highlight:
			btn.modulate = Color(1.2, 1.2, 0.8, 1.0)
		else:
			btn.modulate = Color.WHITE

# =============================================================================
# Callbacks
# =============================================================================

func _on_command_pressed(command_id: String) -> void:
	var data: Dictionary = {}

	# Extract data from command ID.
	if command_id.begins_with("train_"):
		data["item_type"] = command_id.substr(6)
	elif command_id.begins_with("research_"):
		data["tech_id"] = command_id.substr(9)
	elif command_id.begins_with("ability_"):
		data["ability_id"] = command_id.substr(8)

	# Check for stored data in buttons.
	if _buttons.has(command_id):
		var btn: Button = _buttons[command_id]
		if btn.has_meta("command_data"):
			data = btn.get_meta("command_data")

	command_issued.emit(command_id, data)


func _on_command_hovered(command_id: String) -> void:
	command_hovered.emit(command_id)

# =============================================================================
# Selection Integration
# =============================================================================

func _on_selection_changed(unit_ids: Array, building_ids: Array) -> void:
	if not unit_ids.is_empty():
		var uid: int = unit_ids[0]
		var node: Node = _find_unit_node(uid)
		if node != null:
			var utype: String = node.get("unit_type") if node.get("unit_type") != null else ""
			set_unit_commands(utype)
			set_ability_commands(uid, utype)
			return

	if not building_ids.is_empty():
		var bid: int = building_ids[0]
		var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
		if bm != null and bm.has_method("get_building"):
			var bld: Node = bm.get_building(bid)
			if bld != null:
				var btype: String = bld.get("building_type") if bld.get("building_type") != null else ""
				set_building_commands(btype)
				return

	_clear_commands()

# =============================================================================
# Helpers
# =============================================================================

func _find_unit_node(unit_id: int) -> Node:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if unit.get("unit_id") != null and int(unit.get("unit_id")) == unit_id:
			return unit
	return null
