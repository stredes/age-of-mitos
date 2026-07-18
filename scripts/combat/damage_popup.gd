## Floating damage numbers that appear over entities when they take damage.
##
## Pools up to MAX_POPUPS Label2D nodes. Red for normal hits, yellow for
## criticals. Each popup rises 30 px and fades out over DURATION seconds.
## Connects to EventBus.damage_dealt automatically.
extends Node2D

const MAX_POPUPS: int = 20
const FLOAT_HEIGHT: float = 30.0
const DURATION: float = 1.0

const COLOR_NORMAL: Color = Color(1.0, 0.25, 0.2, 1.0)
const COLOR_CRIT: Color = Color(1.0, 0.95, 0.2, 1.0)

var _pool: Array[Label2D] = []
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	for i: int in MAX_POPUPS:
		var label: Label2D = _create_label()
		_pool.append(label)
		_deactivate(label)

	EventBus.damage_dealt.connect(_on_damage_dealt)

# =============================================================================
# Public API
# =============================================================================

func show_damage(world_pos: Vector2, amount: int, is_critical: bool) -> void:
	if amount <= 0:
		return

	var label: Label2D = _get_from_pool()
	if label == null:
		return

	label.text = str(amount)
	label.modulate = COLOR_CRIT if is_critical else COLOR_NORMAL
	label.global_position = world_pos + Vector2(randf_range(-6.0, 6.0), -16.0)
	label.visible = true
	label.modulate.a = 1.0

	# Slightly larger font for crits.
	label.scale = Vector2(1.4, 1.4) if is_critical else Vector2(1.0, 1.0)

	var start_pos: Vector2 = label.global_position
	var end_pos: Vector2 = start_pos + Vector2(0.0, -FLOAT_HEIGHT)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position", end_pos, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, DURATION).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_return_to_pool.bind(label))
	_active_tweens.append(tw)

# =============================================================================
# Pool
# =============================================================================

func _get_from_pool() -> Label2D:
	for label: Label2D in _pool:
		if not label.visible:
			return label
	# All in use — recycle the oldest active popup.
	var oldest: Label2D = _pool[0]
	_return_to_pool(oldest)
	return oldest


func _return_to_pool(label: Label2D) -> void:
	_deactivate(label)
	# Kill any lingering tween for this label.
	var i: int = _active_tweens.size() - 1
	while i >= 0:
		var tw: Tween = _active_tweens[i]
		if not tw.is_valid():
			_active_tweens.remove_at(i)
		i -= 1

# =============================================================================
# Factory
# =============================================================================

func _create_label() -> Label2D:
	var lbl: Label2D = Label2D.new()
	lbl.name = "DamagePopup"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.z_index = 100
	lbl.z_as_relative = false
	lbl.pixel_size = 0.1
	lbl.offset_right = 120.0
	lbl.offset_left = -120.0
	lbl.offset_bottom = 24.0
	lbl.offset_top = -24.0
	add_child(lbl)
	return lbl


func _deactivate(label: Label2D) -> void:
	label.visible = false
	label.modulate.a = 0.0
	label.global_position = Vector2(-9999.0, -9999.0)

# =============================================================================
# Signal handler
# =============================================================================

func _on_damage_dealt(target_id: int, _attacker_id: int, damage: int, is_critical: bool) -> void:
	if target_id == -1:
		return

	var world_pos: Vector2 = _find_entity_position(target_id)
	if world_pos == Vector2.ZERO:
		return

	show_damage(world_pos, damage, is_critical)


func _find_entity_position(entity_id: int) -> Vector2:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return Vector2.ZERO

	# Search units.
	var units: Array[Node] = scene.get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		var uid: int = unit.get("unit_id") if unit.get("unit_id") != null else -1
		if uid == entity_id and unit is Node2D:
			return (unit as Node2D).global_position

	# Search buildings.
	var buildings: Array[Node] = scene.get_tree().get_nodes_in_group("buildings")
	for bld: Node in buildings:
		var bid: int = bld.get("building_id") if bld.get("building_id") != null else -1
		if bid == entity_id and bld is Node2D:
			return (bld as Node2D).global_position

	return Vector2.ZERO
