signal time_of_day_changed(period: String)
signal night_started()
signal day_started()

enum Period { DAWN, MORNING, MIDDAY, AFTERNOON, DUSK, NIGHT }

const PERIOD_NAMES: Dictionary = {
	Period.DAWN: "amanecer",
	Period.MORNING: "manana",
	Period.MIDDAY: "mediodia",
	Period.AFTERNOON: "tarde",
	Period.DUSK: "atardecer",
	Period.NIGHT: "noche",
}

const DAY_LENGTH: float = 300.0
const PERIOD_FRACTIONS: Dictionary = {
	Period.DAWN: 0.0,
	Period.MORNING: 0.12,
	Period.MIDDAY: 0.30,
	Period.AFTERNOON: 0.50,
	Period.DUSK: 0.68,
	Period.NIGHT: 0.82,
}

const COLOR_DAWN: Color = Color(1.0, 0.82, 0.65)
const COLOR_MORNING: Color = Color(1.0, 0.96, 0.90)
const COLOR_MIDDAY: Color = Color(1.0, 1.0, 1.0)
const COLOR_AFTERNOON: Color = Color(1.0, 0.94, 0.82)
const COLOR_DUSK: Color = Color(0.95, 0.70, 0.50)
const COLOR_NIGHT: Color = Color(0.35, 0.42, 0.72)

const NIGHT_SPEED_MULT: float = 0.85
const NIGHT_SIGHT_PENALTY: float = 0.7

var _elapsed: float = 0.0
var _current_period: Period = Period.MIDDAY
var _canvas_modulate: CanvasModulate = null
var _initialized: bool = false


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "DayNightCycle"
	_canvas_modulate.color = COLOR_MIDDAY
	add_child(_canvas_modulate)
	_initialized = true


func _process(delta: float) -> void:
	if not _initialized:
		return
	_elapsed += delta
	_update_tint()
	_update_period()


func get_night_amount() -> float:
	var cycle: float = fmod(_elapsed, DAY_LENGTH) / DAY_LENGTH
	var raw: float = clampf((sin(cycle * TAU - PI * 0.5) + 1.0) * 0.5, 0.0, 1.0)
	return smoothstep(0.3, 0.9, raw)


func is_night() -> bool:
	return get_night_amount() > 0.5


func get_day_progress() -> float:
	return fmod(_elapsed, DAY_LENGTH) / DAY_LENGTH


func get_current_period() -> Period:
	return _current_period


func get_period_name() -> String:
	return PERIOD_NAMES.get(_current_period, "desconocido")


func get_speed_modifier() -> float:
	if is_night():
		return NIGHT_SPEED_MULT
	return 1.0


func get_sight_modifier() -> float:
	return lerpf(1.0, NIGHT_SIGHT_PENALTY, get_night_amount())


func get_tint_color() -> Color:
	return _canvas_modulate.color if _canvas_modulate else COLOR_MIDDAY


func set_time(elapsed: float) -> void:
	_elapsed = elapsed


func skip_to_night() -> void:
	var cycle: float = fmod(_elapsed, DAY_LENGTH) / DAY_LENGTH
	var target_cycle: float = 0.85
	_elapsed += (target_cycle - cycle) * DAY_LENGTH


func skip_to_day() -> void:
	var cycle: float = fmod(_elapsed, DAY_LENGTH) / DAY_LENGTH
	var target_cycle: float = 0.30
	if cycle > target_cycle:
		_elapsed += (1.0 - cycle + target_cycle) * DAY_LENGTH
	else:
		_elapsed += (target_cycle - cycle) * DAY_LENGTH


func _update_tint() -> void:
	if _canvas_modulate == null:
		return
	var progress: float = get_day_progress()
	var color: Color

	if progress < 0.08:
		color = COLOR_DAWN.lerp(COLOR_MORNING, progress / 0.08)
	elif progress < 0.30:
		color = COLOR_MORNING.lerp(COLOR_MIDDAY, (progress - 0.08) / 0.22)
	elif progress < 0.50:
		color = COLOR_MIDDAY.lerp(COLOR_AFTERNOON, (progress - 0.30) / 0.20)
	elif progress < 0.70:
		color = COLOR_AFTERNOON.lerp(COLOR_DUSK, (progress - 0.50) / 0.20)
	elif progress < 0.82:
		color = COLOR_DUSK.lerp(COLOR_NIGHT, (progress - 0.70) / 0.12)
	elif progress < 0.95:
		color = COLOR_NIGHT
	else:
		color = COLOR_NIGHT.lerp(COLOR_DAWN, (progress - 0.95) / 0.05)

	_canvas_modulate.color = color


func _update_period() -> void:
	var progress: float = get_day_progress()
	var new_period: Period = Period.NIGHT

	if progress < 0.08:
		new_period = Period.DAWN
	elif progress < 0.30:
		new_period = Period.MORNING
	elif progress < 0.50:
		new_period = Period.MIDDAY
	elif progress < 0.70:
		new_period = Period.AFTERNOON
	elif progress < 0.82:
		new_period = Period.DUSK
	else:
		new_period = Period.NIGHT

	if new_period != _current_period:
		var old: Period = _current_period
		_current_period = new_period
		time_of_day_changed.emit(PERIOD_NAMES.get(new_period, ""))

		if old != Period.NIGHT and new_period == Period.NIGHT:
			night_started.emit()
		elif old == Period.NIGHT and new_period != Period.NIGHT:
			day_started.emit()
