extends Node

class_name ConstructionSystem

signal construction_started(building: BuildingBase)
signal construction_progress(building: BuildingBase, progress: float)
signal construction_completed(building: BuildingBase)
signal construction_cancelled(building: BuildingBase, refund_amount: float)

@export var construction_particle_scene: PackedScene = preload("res://scenes/effects/construction_particles.tscn")
@export var completion_effect_scene: PackedScene = preload("res://scenes/effects/construction_complete.tscn")

var buildings_under_construction: Array[BuildingBase] = []
var particle_pool: Array[CPUParticles2D] = []
var completion_pool: Array[Node] = []

@onready var grid_manager: GridManager = GridManager.get_instance()
@onready var event_bus: EventBus = EventBus.get_instance()
@onready var particle_manager: ParticleEffectsManager = ParticleEffectsManager.get_instance()

func _ready() -> void:
	event_bus.building_placed.connect(_on_building_placed.bind())
	event_bus.building_cancelled.connect(_on_building_cancelled.bind())
	_preload_particles(20)

func _preload_particles(count: int) -> void:
	for i in range(count):
		if construction_particle_scene:
			var particles = construction_particle_scene.instantiate()
			particles.emitting = false
			particle_pool.append(particles)
		if completion_effect_scene:
			var effect = completion_effect_scene.instantiate()
			effect.visible = false
			completion_pool.append(effect)

func _on_building_placed(building: BuildingBase, position: Vector2) -> void:
	if building.construction_time > 0:
		_start_construction(building)
	else:
		_complete_construction_immediately(building)

func _start_construction(building: BuildingBase) -> void:
	building.set_construction_state(BuildingBase.CONSTRUCTION_STATE.BUILDING)
	buildings_under_construction.append(building)
	construction_started.emit(building)
	
	var particles = _get_particles_from_pool()
	if particles:
		particles.global_position = building.global_position
		particles.emitting = true
		building.construction_particles = particles

func _physics_process(delta: float) -> void:
	for i in buildings_under_construction.size() - 1 down to 0:
		var building = buildings_under_construction[i]
		if not is_instance_valid(building):
			buildings_under_construction.remove_at(i)
			continue
		
		_advance_construction(building, delta)

func _advance_construction(building: BuildingBase, delta: float) -> void:
	building.construction_progress += delta / building.construction_time
	building.construction_progress = clamp(building.construction_progress, 0.0, 1.0)
	
	construction_progress.emit(building, building.construction_progress)
	
	if building.construction_progress >= 1.0:
		_complete_construction(building)
		buildings_under_construction.remove_at(i)

func _complete_construction(building: BuildingBase) -> void:
	building.set_construction_state(BuildingBase.CONSTRUCTION_STATE.COMPLETE)
	building.construction_progress = 1.0
	
	if is_instance_valid(building.construction_particles):
		building.construction_particles.emitting = false
		_return_particles_to_pool(building.construction_particles)
		building.construction_particles = null
	
	_play_completion_effect(building)
	
	if building.has_rally_point:
		building.spawn_rally_point_unit()
	
	construction_completed.emit(building)
	event_bus.building_completed.emit(building)

func _complete_construction_immediately(building: BuildingBase) -> void:
	building.set_construction_state(BuildingBase.CONSTRUCTION_STATE.COMPLETE)
	building.construction_progress = 1.0
	construction_completed.emit(building)
	event_bus.building_completed.emit(building)

func _play_completion_effect(building: BuildingBase) -> void:
	var effect = _get_completion_effect_from_pool()
	if effect:
		effect.global_position = building.global_position
		effect.visible = true
		if effect.has_method("play"):
			effect.play()
		await get_tree().create_timer(2.0).timeout
		effect.visible = false
		_return_completion_effect_to_pool(effect)
	
	if CameraController.get_instance():
		CameraController.get_instance().shake(0.3, 0.15)
	
	AudioManager.play_sfx("res://assets/audio/sfx/building_complete.wav", building.global_position)

func _on_building_cancelled(building: BuildingBase, refund: bool) -> void:
	if building in buildings_under_construction:
		buildings_under_construction.erase(building)
		
		if is_instance_valid(building.construction_particles):
			building.construction_particles.emitting = false
			_return_particles_to_pool(building.construction_particles)
			building.construction_particles = null
		
		var refund_amount: float = 0.75 if refund else 0.0
		construction_cancelled.emit(building, refund_amount)
		event_bus.building_cancelled.emit(building, refund_amount)

func _get_particles_from_pool() -> CPUParticles2D:
	if particle_pool.is_empty():
		if construction_particle_scene:
			var particles = construction_particle_scene.instantiate()
			particles.emitting = false
			return particles
		return null
	return particle_pool.pop_back()

func _return_particles_to_pool(particles: CPUParticles2D) -> void:
	if particle_pool.size() < 30:
		particle_pool.append(particles)
	else:
		particles.queue_free()

func _get_completion_effect_from_pool() -> Node:
	if completion_pool.is_empty():
		if completion_effect_scene:
			return completion_effect_scene.instantiate()
		return null
	return completion_pool.pop_back()

func _return_completion_effect_to_pool(effect: Node) -> void:
	if completion_pool.size() < 10:
		completion_pool.append(effect)
	else:
		effect.queue_free()

func cancel_construction(building: BuildingBase, refund: bool = true) -> void:
	if building in buildings_under_construction:
		var building_data: Dictionary = DataManager.get_building_data(building.building_type)
		var cost: Dictionary = building_data.get("cost", {})
		var refund_amount: float = 0.75 if refund else 0.0
		
		if refund > 0.0 and cost.size() > 0:
			var refunded_resources: Dictionary = {}
			for resource_type: String in cost:
				var base_cost: int = cost[resource_type]
				var refunded_amount: int = maxi(ceili(float(base_cost) * refund_amount), 1)
				refunded_resources[resource_type] = refunded_amount
			
			GameManager.give_resources(refunded_resources, building.player_id)
		
		_on_building_cancelled(building, refund)
		building.queue_free()

func get_construction_progress(building: BuildingBase) -> float:
	return building.construction_progress

func get_buildings_under_construction() -> Array[BuildingBase]:
	return buildings_under_construction.duplicate()

func set_rally_point(building: BuildingBase, position: Vector2) -> void:
	building.set_rally_point(position)

func get_rally_point(building: BuildingBase) -> Vector2:
	return building.get_rally_point()

func has_rally_point(building: BuildingBase) -> bool:
	return building.has_rally_point()

func clear_rally_point(building: BuildingBase) -> void:
	building.clear_rally_point()

func _on_building_destroyed(building: BuildingBase) -> void:
	if building in buildings_under_construction:
		buildings_under_construction.erase(building)
		if is_instance_valid(building.construction_particles):
			building.construction_particles.emitting = false
			_return_particles_to_pool(building.construction_particles)