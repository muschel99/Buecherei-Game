extends Node3D
## Hauptszene. Lädt beim Start den gespeicherten Spielstand (falls vorhanden) und
## stellt die Effekte der Umgebung passend zur gewählten Grafikstufe ein.

@onready var _environment: Environment = $WorldEnvironment.environment
@onready var _dust: GPUParticles3D = $GroundFloorRoom/WindowDust
@onready var _sun: DirectionalLight3D = $Sun

var _dust_amount: int = 0


func _ready() -> void:
	_dust_amount = _dust.amount
	_apply_graphics_quality()
	Settings.setting_changed.connect(_on_setting_changed)
	# Alle Knoten der Szene sind jetzt bereit – also können sie ihre Daten übernehmen
	SaveManager.load_game()
	# Das Tablet mit dem Shop darf nie fehlen (auch nicht in älteren Spielständen)
	($GroundFloorRoom as Room).ensure_essentials()


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
	_apply_sun_shadows(preset)


## Sonnenschatten: Die Sonne verteilt ihre Schatten auf mehrere Stufen ("Kaskaden") – nah
## an der Kamera fein, weiter weg gröber. Ohne Überblendung sieht man dort, wo eine Stufe in
## die nächste übergeht, eine Linie im Fensterlicht, die beim Laufen mitwandert. Deshalb
## werden die Übergänge weich überblendet.
func _apply_sun_shadows(preset: Dictionary) -> void:
	var two := int(preset.get("sun_cascades", 4)) <= 2
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if two \
		else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	# Bei 2 Stufen liegt die Grenze weiter weg, damit das Fensterlicht in der feinen
	# ersten Stufe liegt (Anteil der Schattenweite, siehe GameConfig)
	_sun.directional_shadow_split_1 = GameConfig.sun_two_cascade_split if two else 0.1
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_max_distance = GameConfig.sun_shadow_distance
