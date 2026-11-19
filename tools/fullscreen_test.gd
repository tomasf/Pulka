extends SceneTree
## Relaunch an isolated project to check the mode before any scene loads.
## Add -- --native to check the actual first desktop window too.

const PROBE := """extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var configured: int = ProjectSettings.get_setting_with_override("display/window/size/mode")
	var actual := DisplayServer.window_get_mode()
	var valid := configured == int(args[0])
	if DisplayServer.get_name() != "headless":
		valid = valid and actual == int(args[1])
	print("startup mode: configured=%d, window=%d" % [configured, actual])
	quit(0 if valid else 1)
"""

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := DirAccess.create_temp("pulka-fullscreen")
	var path := directory.get_current_dir()
	var data := SaveData.load_saved(path.path_join("pulka.cfg"))
	var project := ConfigFile.new()
	project.set_value("application", "config/name", "PulkaFullscreenTest")
	project.set_value("application", "config/project_settings_override.pc", data.window_settings_path())
	project.save(path.path_join("project.godot"))
	var probe := FileAccess.open(path.path_join("probe.gd"), FileAccess.WRITE)
	probe.store_string(PROBE)
	probe.close()
	var source := ConfigFile.new()
	source.load("res://project.godot")
	_check("project reads the real save's window override at startup", source.get_value("application", "config/project_settings_override.pc") == SaveData.new().window_settings_path())
	_check("no preference starts windowed", _launch(path, 0, 0))
	data.fullscreen = true
	data.store()
	_check("saved fullscreen applies before the first scene", _launch(path, 3, 3))
	data.fullscreen = false
	data.store()
	_check("turning fullscreen off applies on the next launch", _launch(path, 0, 0))
	DirAccess.remove_absolute(data.window_settings_path())
	Quality.force_mobile = true
	data.store()
	_check("mobile saves do not set the desktop startup mode", not FileAccess.file_exists(data.window_settings_path()))
	Quality.force_mobile = false
	Quality.force_tv = true
	data.store()
	_check("TV saves do not set the desktop startup mode", not FileAccess.file_exists(data.window_settings_path()))
	Quality.force_tv = false
	print("fullscreen test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _launch(path: String, configured: int, window: int) -> bool:
	var args := PackedStringArray(["--path", path, "--log-file", path.path_join("probe.log"), "--script", "res://probe.gd"])
	if not OS.get_cmdline_user_args().has("--native"):
		args.append("--headless")
	args.append_array(["--", str(configured), str(window)])
	var output := []
	var result := OS.execute(OS.get_executable_path(), args, output, true)
	if result != 0:
		for line in output: print(line)
	return result == 0

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
