extends PopupPanel

@onready var language_option: OptionButton = $VBox/LanguageRow/LanguageOption
@onready var resolution_option: OptionButton = $VBox/ResolutionRow/ResolutionOption
@onready var version_label: Label = $VBox/VersionLabel

const LOCALE_CODES := ["en", "pl"]

func _ready() -> void:
	language_option.add_item("English", 0)
	language_option.add_item("Polski", 1)
	for i in Settings.RESOLUTIONS.size():
		var res: Vector2i = Settings.RESOLUTIONS[i]
		resolution_option.add_item("%d x %d" % [res.x, res.y], i)
	language_option.select(LOCALE_CODES.find(Settings.locale))
	resolution_option.select(Settings.resolution_index)
	_refresh_dynamic_texts()
	language_option.item_selected.connect(_on_language_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	$VBox/CloseButton.pressed.connect(hide)
	Settings.settings_changed.connect(_refresh_dynamic_texts)

func _on_language_selected(index: int) -> void:
	Settings.set_locale(LOCALE_CODES[index])

func _on_resolution_selected(index: int) -> void:
	Settings.set_resolution_index(index)

func _refresh_dynamic_texts() -> void:
	title = tr("SETTINGS_TITLE")
	version_label.text = tr("SETTINGS_VERSION_FORMAT") % ProjectSettings.get_setting("application/config/version", "")
