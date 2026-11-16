extends Node
## Jahreszeiten (seit der großen Überarbeitung; Autoload „Season“). Zum Start gibt es Sommer (Aussehen wie bisher) und
## Herbst (Wunsch der Entwicklerin: „cozy Herbst“) – Winter und Frühling kommen später dazu (neue Einträge hinten an
## NAMES und an die Einstellung „gameplay/season“ anhängen, dann hier und in den Shadern umsetzen).
##
## Was die Jahreszeit ändert:
## - globaler Shader-Wert `season_autumn` (0 = Sommer … 1 = Herbst): Laub draußen färbt sich gold/orange/rot
##   (storybook.gdshaderinc `autumn_leaf`; nur grüne Blätter, nie im Laden), weich überblendet beim Umschalten
## - fallende Blätter und Laub am Boden (AutumnLeaves unter Outside) – nur im Herbst
## - Licht/Dunst (DayCycle liest `autumn`)
## Andere Scripts: `Season.autumn` (0–1, weich), `Season.current` ("summer"/"autumn"), Signal `changed`.

signal changed(season: String)

## Reihenfolge wie in der Einstellung „Jahreszeit“.
const NAMES: Array[String] = ["summer", "autumn"]

var current: String = "autumn"
## 0 = Sommer, 1 = Herbst (gleitet beim Umschalten in GameConfig.season_blend_time Sekunden)
var autumn: float = 1.0
var _target := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.setting_changed.connect(_on_setting_changed)
	_set_season(_season_from_settings(), true)


func is_autumn() -> bool:
	return current == "autumn"


func _season_from_settings() -> String:
	var index := int(Settings.get_value("gameplay/season"))
	return NAMES[clampi(index, 0, NAMES.size() - 1)]


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "gameplay/season":
		_set_season(_season_from_settings(), false)


func _set_season(season: String, instant: bool) -> void:
	current = season
	_target = 1.0 if season == "autumn" else 0.0
	if instant:
		autumn = _target
	_push()
	changed.emit(current)


func _process(delta: float) -> void:
	if is_equal_approx(autumn, _target):
		return
	autumn = move_toward(autumn, _target, delta / maxf(GameConfig.season_blend_time, 0.01))
	_push()


func _push() -> void:
	RenderingServer.global_shader_parameter_set(&"season_autumn", autumn)
