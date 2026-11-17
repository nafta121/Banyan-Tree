extends TestBase


func run() -> int:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 412, "viewport_width == 412")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 915, "viewport_height == 915")
	assert_eq(ProjectSettings.get_setting("application/run/low_processor_usage_mode"), true, "low_processor_usage_mode == true")
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	assert_eq(music_idx, 1, "Music bus index == 1")
	assert_eq(sfx_idx, 2, "SFX bus index == 2")
	assert_eq(AudioServer.get_bus_index("Master"), 0, "Master bus index == 0")
	assert_eq(AudioServer.get_bus_send(music_idx), "Master", "Music bus sends to Master")
	assert_eq(AudioServer.get_bus_send(sfx_idx), "Master", "SFX bus sends to Master")
	assert_near(AudioServer.get_bus_volume_db(music_idx), 0.0, 0.01, "Music bus default 0.0 dB")
	assert_near(AudioServer.get_bus_volume_db(sfx_idx), 0.0, 0.01, "SFX bus default 0.0 dB")

	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "handheld/orientation == 1 (portrait)")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch/mode == canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "stretch/aspect == expand")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "renderer == gl_compatibility")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility", "mobile renderer == gl_compatibility")
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://godot/scenes/boot_loader_screen.tscn", "main_scene configured")
	assert_true(ResourceLoader.exists("res://godot/scenes/boot_loader_screen.tscn"), "boot_loader_screen.tscn exists")
	assert_true(tree != null and tree.root != null, "SceneTree injected into TestBase")

	var root_dir := ProjectSettings.globalize_path("res://")
	for ignored_dir in ["js", "css", "data", "docs", "tools"]:
		var gdignore_path := root_dir.path_join(ignored_dir).path_join(".gdignore")
		assert_true(FileAccess.file_exists(gdignore_path), ".gdignore exists in " + ignored_dir)

	return assertions_failed
