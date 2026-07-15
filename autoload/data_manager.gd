## Loads, validates, and caches all JSON data files for game content.
##
## DataManager provides a centralized data layer for units, buildings, resources,
## technologies, and civilizations. Data is loaded from res://data/ on startup
## and cached in memory for fast runtime access.
extends Node

# =============================================================================
# Constants
# =============================================================================

## Base path for all data files.
const DATA_PATH: String = "res://data/"

## Known data file names (without extension). Each must exist in DATA_PATH.
const DATA_FILES: Dictionary = {
	"units": "units.json",
	"buildings": "buildings.json",
	"resources": "resources.json",
	"technologies": "technologies.json",
	"civilizations": "civilizations.json",
}

# =============================================================================
# Signals
# =============================================================================

## Emitted when a data file is successfully loaded.
signal data_loaded(file_name: String, entry_count: int)

## Emitted when a data file fails to load or validate.
signal data_load_failed(file_name: String, error: String)

# =============================================================================
# Properties
# =============================================================================

## In-memory cache of all loaded data keyed by data category.
## Structure: { "units": { "villager": {...}, "warrior": {...} }, ... }
var _cache: Dictionary = {}

## Set of data categories that have been successfully loaded.
var _loaded_categories: Dictionary = {}

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_preload_all_data()

# =============================================================================
# Preloading
# =============================================================================

## Load all data files on startup. Logs errors for missing files but
## does not crash the game, allowing graceful degradation.
func _preload_all_data() -> void:
	for category: String in DATA_FILES:
		var file_name: String = DATA_FILES[category]
		var result: bool = load_data(category, DATA_PATH + file_name)
		if result:
			_loaded_categories[category] = true
		else:
			_loaded_categories[category] = false
			push_warning("DataManager: Failed to load '%s' from %s" % [category, file_name])

# =============================================================================
# Core Loading
# =============================================================================

## Load a JSON data file and store it in the cache.
## [param category: String] The data category key (e.g. "units").
## [param full_path: String] The full res:// path to the JSON file.
## [return] true if loading and parsing succeeded.
func load_data(category: String, full_path: String) -> bool:
	if not FileAccess.file_exists(full_path):
		var err_msg: String = "File not found: %s" % full_path
		data_load_failed.emit(category, err_msg)
		push_error("DataManager: %s" % err_msg)
		return false

	var file: FileAccess = FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		var err_msg: String = "Cannot open file: %s (error %d)" % [full_path, FileAccess.get_open_error()]
		data_load_failed.emit(category, err_msg)
		push_error("DataManager: %s" % err_msg)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		var err_msg: String = "JSON parse error in %s at line %d: %s" % [full_path, json.get_error_line(), json.get_error_message()]
		data_load_failed.emit(category, err_msg)
		push_error("DataManager: %s" % err_msg)
		return false

	var data: Variant = json.data
	if data is not Dictionary:
		var err_msg: String = "Expected Dictionary root in %s, got %s" % [full_path, type_string(typeof(data))]
		data_load_failed.emit(category, err_msg)
		push_error("DataManager: %s" % err_msg)
		return false

	if not _validate_data(category, data as Dictionary):
		var err_msg: String = "Validation failed for %s" % full_path
		data_load_failed.emit(category, err_msg)
		push_error("DataManager: %s" % err_msg)
		return false

	_cache[category] = data
	data_loaded.emit(category, (data as Dictionary).size())
	return true

# =============================================================================
# Validation
# =============================================================================

## Validate the structure of loaded data. Ensures each entry has required fields.
## [param category: String] The data category.
## [param data: Dictionary] The parsed JSON data.
## [return] true if the data passes validation checks.
func _validate_data(category: String, data: Dictionary) -> bool:
	if data.is_empty():
		push_warning("DataManager: Data for '%s' is empty." % category)
		return true  # Empty data is valid, just nothing to work with.

	for key: String in data:
		var entry: Variant = data[key]
		if entry is not Dictionary:
			push_warning("DataManager: Entry '%s' in '%s' is not a Dictionary." % [key, category])
			return false

		# Every entry must have a name or display_name for UI purposes.
		var entry_dict: Dictionary = entry as Dictionary
		if not entry_dict.has("name") and not entry_dict.has("display_name"):
			push_warning("DataManager: Entry '%s' in '%s' is missing 'name' field." % [key, category])

		# Every entry should have a cost if it's a unit or building.
		if category in ["units", "buildings"]:
			if not entry_dict.has("cost"):
				push_warning("DataManager: Entry '%s' in '%s' is missing 'cost' field." % [key, category])
	return true

# =============================================================================
# Data Accessors
# =============================================================================

## Retrieve raw data for a category.
## [param category: String] The data category.
## [return] The full Dictionary for that category, or an empty Dictionary.
func get_category_data(category: String) -> Dictionary:
	return _cache.get(category, {})


## Get data for a specific unit type.
## [param unit_type: String] The unit type key (e.g. "villager").
## [return] The unit's data Dictionary, or an empty Dictionary if not found.
func get_unit_data(unit_type: String) -> Dictionary:
	var units: Dictionary = _cache.get("units", {})
	return units.get(unit_type, {})


## Get data for a specific building type.
## [param building_type: String] The building type key (e.g. "town_center").
## [return] The building's data Dictionary, or an empty Dictionary if not found.
func get_building_data(building_type: String) -> Dictionary:
	var buildings: Dictionary = _cache.get("buildings", {})
	return buildings.get(building_type, {})


## Get data for a specific resource type.
## [param resource_type: String] The resource type key (e.g. "wood").
## [return] The resource's data Dictionary, or an empty Dictionary if not found.
func get_resource_data(resource_type: String) -> Dictionary:
	var resources: Dictionary = _cache.get("resources", {})
	return resources.get(resource_type, {})


## Get data for a specific technology.
## [param tech_id: String] The technology ID key (e.g. "wheel").
## [return] The technology's data Dictionary, or an empty Dictionary if not found.
func get_tech_data(tech_id: String) -> Dictionary:
	var techs: Dictionary = _cache.get("technologies", {})
	return techs.get(tech_id, {})


## Get data for a specific civilization.
## [param civ_id: String] The civilization ID key (e.g. "greek").
## [return] The civilization's data Dictionary, or an empty Dictionary if not found.
func get_civ_data(civ_id: String) -> Dictionary:
	var civs: Dictionary = _cache.get("civilizations", {})
	return civs.get(civ_id, {})

# =============================================================================
# Query Helpers
# =============================================================================

## Get all keys (IDs) for a given data category.
## [param category: String] The data category to list.
## [return] Array of String keys.
func get_all_ids(category: String) -> Array:
	return _cache.get(category, {}).keys()


## Get all unit IDs.
func get_all_unit_ids() -> Array:
	return get_all_ids("units")


## Get all building IDs.
func get_all_building_ids() -> Array:
	return get_all_ids("buildings")


## Get all resource IDs.
func get_all_resource_ids() -> Array:
	return get_all_ids("resources")


## Get all technology IDs.
func get_all_tech_ids() -> Array:
	return get_all_ids("technologies")


## Get all civilization IDs.
func get_all_civ_ids() -> Array:
	return get_all_ids("civilizations")


## Check if a specific entry exists in a category.
## [param category: String] The data category.
## [param entry_id: String] The entry key to check.
func has_entry(category: String, entry_id: String) -> bool:
	var cat_data: Dictionary = _cache.get(category, {})
	return cat_data.has(entry_id)


## Check if a unit type exists.
func has_unit(unit_type: String) -> bool:
	return has_entry("units", unit_type)


## Check if a building type exists.
func has_building(building_type: String) -> bool:
	return has_entry("buildings", building_type)


## Get a typed field from a data entry, with a fallback default.
## [param category: String] The data category.
## [param entry_id: String] The entry key.
## [param field: String] The field name to retrieve.
## [param default: Variant] The fallback value if the field is missing.
## [return] The field value, or default.
func get_field(category: String, entry_id: String, field: String, default: Variant = null) -> Variant:
	var entry: Dictionary = _cache.get(category, {}).get(entry_id, {})
	return entry.get(field, default)


## Reload all data from disk. Useful for hot-reloading during development.
func reload_all() -> void:
	_cache.clear()
	_loaded_categories.clear()
	_preload_all_data()


## Check if a specific category has been loaded successfully.
## [param category: String] The category to check.
func is_loaded(category: String) -> bool:
	return _loaded_categories.get(category, false)


## Get the total number of entries across all loaded categories.
func get_total_entries() -> int:
	var total: int = 0
	for category: String in _cache:
		total += (_cache[category] as Dictionary).size()
	return total
