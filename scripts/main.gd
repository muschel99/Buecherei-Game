extends Node3D
## Hauptszene. Lädt beim Start den gespeicherten Spielstand (falls vorhanden) und
## stellt die Effekte der Umgebung passend zur gewählten Grafikstufe ein.

@onready var _environment: Environment = $WorldEnvironment.environment
@onready var _dust: GPUParticles3D = $GroundFloorRoom/WindowDust

var _dust_amount: int = 0


func _ready() -> void:
	_dust_amount = _dust.amount
	_apply_graphics_quality()
	Settings.setting_changed.connect(_on_setting_changed)
	# Alle Knoten der Szene sind jetzt bereit – also können sie ihre Daten übernehmen
	SaveManager.load_game()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "graphics/quality":
		_apply_graphics_quality()


## Aufwändige Effekte je nach Grafikstufe (Werte in GameConfig.graphics_presets).
func _apply_graphics_quality() -> void:
	var preset := Settings.get_graphics_preset()
	_environment.ssao_enabled = preset.ssao
	_environment.ssil_enabled = preset.ssil
	_environment.volumetric_fog_enabled = preset.volumetric_fog
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, preset.ssao_half_size, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(preset.fog_volume_size, preset.fog_volume_size)
	_dust.amount = maxi(1, roundi(_dust_amount * preset.dust_amount))
