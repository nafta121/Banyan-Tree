class_name TestBase
extends RefCounted

var tree: SceneTree = null
var suite_name: String = ""
var assertions_passed: int = 0
var assertions_failed: int = 0
var failure_messages: Array[String] = []


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if _values_equal(actual, expected):
		assertions_passed += 1
		return
	var detail := "assert_eq failed: expected %s, got %s" % [var_to_str(expected), var_to_str(actual)]
	_record_failure(detail, msg)


func assert_ne(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not _values_equal(actual, expected):
		assertions_passed += 1
		return
	var detail := "assert_ne failed: value unexpectedly equaled %s" % [var_to_str(expected)]
	_record_failure(detail, msg)


func assert_true(cond: bool, msg: String = "") -> void:
	if cond:
		assertions_passed += 1
		return
	_record_failure("assert_true failed: condition was false", msg)


func assert_false(cond: bool, msg: String = "") -> void:
	if not cond:
		assertions_passed += 1
		return
	_record_failure("assert_false failed: condition was true", msg)


func assert_near(a: float, b: float, eps: float = 0.01, msg: String = "") -> void:
	if not is_nan(a) and not is_nan(b) and absf(a - b) <= eps:
		assertions_passed += 1
		return
	var detail := "assert_near failed: expected %s +/- %s, got %s" % [str(b), str(eps), str(a)]
	_record_failure(detail, msg)


func run():
	for method_info in get_method_list():
		var m_name: String = method_info["name"]
		if m_name.begins_with("test_") and method_info["args"].is_empty():
			await call(m_name)
	return assertions_failed


func _record_failure(detail: String, msg: String) -> void:
	assertions_failed += 1
	var formatted := detail if msg.is_empty() else "%s (%s)" % [detail, msg]
	failure_messages.append(formatted)
	var prefix := "[FAIL]" if suite_name.is_empty() else "[FAIL %s]" % suite_name
	printerr("%s %s" % [prefix, formatted])


static func _values_equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == TYPE_NIL or tb == TYPE_NIL:
		return ta == tb
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return a == b
	if (ta == TYPE_STRING or ta == TYPE_STRING_NAME) and (tb == TYPE_STRING or tb == TYPE_STRING_NAME):
		return String(a) == String(b)
	if ta != tb:
		return false
	return a == b
