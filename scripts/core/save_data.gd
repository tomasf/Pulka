class_name SaveData
extends RefCounted
## Persistent records and preferences, stored in the user data folder.

const PATH := "user://pulka.cfg"

var best_distance := 0.0
var best_score := 0
var vehicle_id := "pulka"
var master_volume := 1.0
var music_volume := 0.8
var effects_volume := 1.0
var fullscreen := false
var show_fps := false


static func load_saved() -> SaveData:
	var data := SaveData.new()
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		data.best_distance = float(config.get_value("records", "best_distance", 0.0))
		data.best_score = int(config.get_value("records", "best_score", 0))
		data.vehicle_id = str(config.get_value("settings", "vehicle", "pulka"))
		data.master_volume = float(config.get_value("audio", "master", 1.0))
		data.music_volume = float(config.get_value("audio", "music", 0.8))
		data.effects_volume = float(config.get_value("audio", "effects", 1.0))
		data.fullscreen = bool(config.get_value("settings", "fullscreen", false))
		data.show_fps = bool(config.get_value("settings", "show_fps", false))
	return data


func store() -> void:
	var config := ConfigFile.new()
	config.set_value("records", "best_distance", best_distance)
	config.set_value("records", "best_score", best_score)
	config.set_value("settings", "vehicle", vehicle_id)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "show_fps", show_fps)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	config.save(PATH)
