extends Button

signal stance_changed(new_stance: String)

const STANCES: Array[String] = ["defensive", "aggressive", "passive"]
const STANCE_ICONS: Dictionary = {
	"defensive": Color(0.2, 0.6, 1.0),
	"aggressive": Color(1.0, 0.3, 0.2),
	"passive": Color(0.5, 0.5, 0.5),
}
const STANCE_LABELS: Dictionary = {
	"defensive": "Def",
	"aggressive": "Agg",
	"passive": "Pas",
}
const STANCE_ICONS_IMAGE: Dictionary = {
	"defensive": "shield",
	"aggressive": "attack",
	"passive": "stop",
}

var _current_stance: String = "defensive"
var _stance_label: Label = null
var _icon_rect: TextureRect = null
var _icon_factory: Node = null


func _ready() -> void:
	custom_minimum_size = Vector2(40, 40)
	tooltip_text = "Defensive: Fight back when attacked"
	toggled.connect(_on_toggled)
	pressed.connect(_on_pressed)
	call_deferred("_find_icon_factory")
	_update_visual()


func _find_icon_factory() -> void:
	_icon_factory = get_node_or_null("/root/GameWorld/UILayer/ResourceIconFactory")
	if _icon_factory == null:
		_icon_factory = get_node_or_null("/root/GameWorld/ResourceIconFactory")
	_update_icon()


func _on_toggled(pressed: bool) -> void:
	if pressed:
		_cycle_stance()


func _on_pressed() -> void:
	_cycle_stance()


func _cycle_stance() -> void:
	var idx: int = STANCES.find(_current_stance)
	idx = (idx + 1) % STANCES.size()
	_current_stance = STANCES[idx]
	_update_visual()
	stance_changed.emit(_current_stance)
	EventBus.button_pressed.emit("stance_" + _current_stance, GameManager.local_player_id)


func set_stance(new_stance: String) -> void:
	if STANCES.find(new_stance) == -1:
		return
	_current_stance = new_stance
	_update_visual()


func get_stance() -> String:
	return _current_stance


func _update_visual() -> void:
	tooltip_text = _get_stance_description(_current_stance)
	button_pressed = false
	_update_icon()


func _get_stance_description(stance: String) -> String:
	match stance:
		"defensive":
			return "Defensive: Fight back when attacked"
		"aggressive":
			return "Aggressive: Chase and attack enemies"
		"passive":
			return "Passive: Do not attack"
		_:
			return ""


func _update_icon() -> void:
	var icon_name: String = STANCE_ICONS_IMAGE.get(_current_stance, "placeholder")
	if _icon_factory != null and _icon_factory.has_method("get_icon"):
		var tex: ImageTexture = _icon_factory.get_icon(icon_name, 24)
		if tex != null:
			icon = tex
			return

	# Fallback: color tint
	icon = null
	modulate = STANCE_ICONS.get(_current_stance, Color.WHITE)
