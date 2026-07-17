## Minimal test harness for Age of Mitos.
## Run via: godot --headless -s tests/run_all.gd
## Or run individual test scripts in the editor.
class_name TestHarness
extends RefCounted

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""


func suite(name: String) -> void:
	_current_suite = name
	print("\n=== SUITE: %s ===" % name)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual == expected:
		_pass_count += 1
	else:
		_fail_count += 1
		var detail: String = "  FAIL: %s — expected %s, got %s" % [msg, expected, actual]
		print(detail)


func assert_true(condition: bool, msg: String = "") -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s — expected true" % msg)


func assert_false(condition: bool, msg: String = "") -> void:
	if not condition:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s — expected false" % msg)


func assert_null(value: Variant, msg: String = "") -> void:
	if value == null:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s — expected null, got %s" % [msg, value])


func assert_not_null(value: Variant, msg: String = "") -> void:
	if value != null:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s — expected non-null" % msg)


func assert_near(actual: float, expected: float, tolerance: float = 0.01, msg: String = "") -> void:
	if absf(actual - expected) <= tolerance:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s — expected ~%f, got %f" % [msg, expected, actual])


func assert_gt(actual: float, threshold: float, msg: String = "") -> void:
	if actual > threshold:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s — expected > %f, got %f" % [msg, threshold, actual])


func assert_gte(actual: float, threshold: float, msg: String = "") -> void:
	if actual >= threshold:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s — expected >= %f, got %f" % [msg, threshold, actual])


func assert_lt(actual: float, threshold: float, msg: String = "") -> void:
	if actual < threshold:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s — expected < %f, got %f" % [msg, threshold, actual])


func assert_in(item: Variant, collection: Array, msg: String = "") -> void:
	if item in collection:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s — %s not in %s" % [msg, item, collection])


func summary() -> void:
	var total: int = _pass_count + _fail_count
	print("\n=== RESULTS: %d/%d passed, %d failed ===" % [_pass_count, total, _fail_count])
	if _fail_count > 0:
		print("SOME TESTS FAILED")
	else:
		print("ALL TESTS PASSED")
