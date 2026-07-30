extends Node

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "pl"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DEFAULT_RESOLUTION_INDEX := 1

var locale: String = DEFAULT_LOCALE
var resolution_index: int = DEFAULT_RESOLUTION_INDEX

func _ready() -> void:
	_load()
	_apply_locale()
	_apply_resolution()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		locale = cfg.get_value("general", "locale", DEFAULT_LOCALE)
		resolution_index = cfg.get_value("general", "resolution_index", DEFAULT_RESOLUTION_INDEX)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", locale)
	cfg.set_value("general", "resolution_index", resolution_index)
	cfg.save(CONFIG_PATH)

func set_locale(code: String) -> void:
	if code == locale:
		return
	locale = code
	_apply_locale()
	_save()
	settings_changed.emit()

func set_resolution_index(index: int) -> void:
	if index == resolution_index:
		return
	resolution_index = index
	_apply_resolution()
	_save()
	settings_changed.emit()

func get_resolution() -> Vector2i:
	return RESOLUTIONS[resolution_index]

func _apply_locale() -> void:
	TranslationServer.set_locale(locale)

func _apply_resolution() -> void:
	get_window().size = RESOLUTIONS[resolution_index]
