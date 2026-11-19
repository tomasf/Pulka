class_name SaveData
extends RefCounted
## Persistent records and preferences, stored in the user data folder.

const PATH := "user://pulka.cfg"

var best_distance := 0.0
var best_score := 0
## Unlock progress survives clearing the records. Older saves migrate below.
var unlocked_distance := 0.0
var _path := PATH
var vehicle_id := "pulka"
var master_volume := 1.0
var music_volume := 0.8
var effects_volume := 1.0
var fullscreen := false
var show_fps := false
var language := "sv"


static func load_saved(path := PATH) -> SaveData:
	var data := SaveData.new()
	data._path = path
	var config := ConfigFile.new()
	if config.load(path) == OK:
		data.best_distance = float(config.get_value("records", "best_distance", 0.0))
		data.best_score = int(config.get_value("records", "best_score", 0))
		data.unlocked_distance = maxf(data.best_distance, float(config.get_value("progress", "distance", 0.0)))
		data.vehicle_id = str(config.get_value("settings", "vehicle", "pulka"))
		data.master_volume = float(config.get_value("audio", "master", 1.0))
		data.music_volume = float(config.get_value("audio", "music", 0.8))
		data.effects_volume = float(config.get_value("audio", "effects", 1.0))
		data.fullscreen = bool(config.get_value("settings", "fullscreen", false))
		data.show_fps = bool(config.get_value("settings", "show_fps", false))
		var language := str(config.get_value("settings", "language", "sv"))
		data.language = language if language in ["sv", "en"] else "sv"
	return data


func reset_records() -> void:
	unlocked_distance = maxf(unlocked_distance, best_distance)
	best_distance = 0.0
	best_score = 0


func store() -> void:
	var config := ConfigFile.new()
	config.set_value("records", "best_distance", best_distance)
	config.set_value("records", "best_score", best_score)
	config.set_value("progress", "distance", maxf(unlocked_distance, best_distance))
	config.set_value("settings", "vehicle", vehicle_id)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "show_fps", show_fps)
	config.set_value("settings", "language", language)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	if config.save(_path) == OK:
		store_window_mode()


func window_settings_path() -> String:
	return _path.get_basename() + ".window.cfg"


## Godot reads this override before creating its first window and splash.
## Keep it separate from records/audio, and scoped to native desktop builds.
func store_window_mode() -> void:
	if not Quality.is_desktop():
		return
	var config := ConfigFile.new()
	config.set_value("display", "window/size/mode.pc", DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	var error := config.save(window_settings_path())
	if error != OK:
		push_warning("Could not save startup window mode: " + error_string(error))
