extends SceneTree

const TESTS_DIR := "res://godot/tests"
const WATCHDOG_MAX_FRAMES := 1200

var _started: bool = false
var _finished: bool = false
var _frames_elapsed: int = 0
var _autoload_failures: int = 0


func _initialize() -> void:
	_ensure_autoloads_mounted()


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_execute_all_suites()
		return false
	_frames_elapsed += 1
	if not _finished and _frames_elapsed >= WATCHDOG_MAX_FRAMES:
		printerr("[FAIL] Test runner watchdog timeout exceeded (%d frames)" % WATCHDOG_MAX_FRAMES)
		_finished = true
		quit(1)
	return false


func _ensure_autoloads_mounted() -> void:
	for prop in ProjectSettings.get_property_list():
		var prop_name: String = prop["name"]
		if not prop_name.begins_with("autoload/"):
			continue
		var auto_name := prop_name.trim_prefix("autoload/")
		if root.has_node(auto_name):
			continue
		var raw_path := str(ProjectSettings.get_setting(prop_name))
		var clean_path := raw_path.trim_prefix("*")
		var res := ResourceLoader.load(clean_path)
		var inst: Node = null
		if res is PackedScene:
			inst = (res as PackedScene).instantiate()
		elif res is GDScript and (res as GDScript).can_instantiate():
			var obj: Variant = (res as GDScript).new()
			if obj is Node:
				inst = obj
		if inst != null:
			inst.name = auto_name
			root.add_child(inst)
		else:
			_autoload_failures += 1
			printerr("[FAIL autoload] Failed to mount autoload '%s' from '%s'" % [auto_name, clean_path])


func _discover_test_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		return files
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if dir.current_is_dir():
			continue
		if entry.begins_with("test_") and entry.ends_with(".gd") and entry != "test_base.gd":
			files.append(entry)
	dir.list_dir_end()
	files.sort()
	return files


func _execute_all_suites() -> void:
	var suite_files := _discover_test_files()
	if suite_files.is_empty():
		printerr("[FAIL] No test_*.gd files discovered in %s" % TESTS_DIR)
		_finished = true
		quit(1)
		return

	var total_passed: int = 0
	var total_failed: int = _autoload_failures
	var suites_passed: int = 0
	var suites_failed: int = 0

	for file_name in suite_files:
		var full_path := TESTS_DIR.path_join(file_name)
		var res := ResourceLoader.load(full_path)
		var script_res := res as GDScript
		if script_res == null or not script_res.can_instantiate():
			printerr("[FAIL] %s: script failed to load or compile (%s)" % [file_name, full_path])
			total_failed += 1
			suites_failed += 1
			continue

		var inst: Variant = script_res.new()
		if inst == null:
			printerr("[FAIL] %s: failed to instantiate test suite" % file_name)
			total_failed += 1
			suites_failed += 1
			continue

		if "tree" in inst:
			inst.set("tree", self)
		if "suite_name" in inst:
			inst.set("suite_name", file_name)

		var suite_failed: int = 0
		var suite_passed: int = 0

		if inst.has_method("run"):
			var ret: Variant = await inst.call("run")
			if "assertions_failed" in inst:
				suite_failed = int(inst.get("assertions_failed"))
			if "assertions_passed" in inst:
				suite_passed = int(inst.get("assertions_passed"))
			if ret is int and int(ret) > suite_failed:
				suite_failed = int(ret)
			elif ret is bool and not bool(ret) and suite_failed == 0:
				suite_failed = 1
		else:
			printerr("[FAIL] %s: missing run() method" % file_name)
			suite_failed = 1

		total_passed += suite_passed
		total_failed += suite_failed
		if suite_failed == 0:
			suites_passed += 1
			print("[PASS] %s (%d passed)" % [file_name, suite_passed])
		else:
			suites_failed += 1
			printerr("[FAIL] %s (%d failed, %d passed)" % [file_name, suite_failed, suite_passed])

	_finished = true
	if total_failed == 0 and suites_failed == 0:
		print("PASS: %d/%d test suites passed (%d assertions)" % [suites_passed, suite_files.size(), total_passed])
		quit(0)
	else:
		printerr("FAIL: %d/%d test suites failed (%d failed assertions, %d passed)" % [suites_failed, suite_files.size(), total_failed, total_passed])
		quit(1)
