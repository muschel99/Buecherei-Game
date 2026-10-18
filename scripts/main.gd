extends Node3D
## Hauptszene. Lädt beim Start den gespeicherten Spielstand (falls vorhanden) und
## stellt die Effekte der Umgebung passend zur gewählten Grafikstufe ein.

@onready var _environment: Environment = $WorldEnvironment.environment
@onready var _dust: GPUParticles3D = $GroundFloorRoom/WindowDust
@onready var _sun: DirectionalLight3D = $Sun
@onready var _sky_fill: DirectionalLight3D = $SkyFill

var _dust_amount: int = 0


func _ready() -> void:
	_dust_amount = _dust.amount
	# Draußen liegt alles tiefer als der Ladenboden (Etappe 4d, GameConfig.shop_floor_rise)
	($Outside as Node3D).position.y = StreetLayout.ground_y()
	_apply_sun_direction()
	_apply_graphics_quality()
	_setup_sky_fill()
	Settings.setting_changed.connect(_on_setting_changed)
	# Alle Knoten der Szene sind jetzt bereit – also können sie ihre Daten übernehmen
	SaveManager.load_game()
	# Das Tablet mit dem Shop darf nie fehlen (auch nicht in älteren Spielständen)
	($GroundFloorRoom as Room).ensure_essentials()
	# Startgeschenke (z. B. ein Rückgabekasten) kommen einmal ins Inventar
	BookStock.give_start_gifts()


## Himmelslicht (GameConfig.outdoor_fill_*): wirkt nur auf die Render-Ebene "draußen". Alles
## unter Outside, die Eingangstreppe, die Obergeschosse und die Fassade der Bücherei kommen auf
## diese Ebene – auch was später dazukommt (Lieferkartons, Passanten aus dem Vorrat).
func _setup_sky_fill() -> void:
	_sky_fill.light_energy = GameConfig.outdoor_fill_energy
	_sky_fill.light_color = GameConfig.outdoor_fill_color
	_sky_fill.light_cull_mask = 1 << (GameConfig.OUTDOOR_RENDER_LAYER - 1)
	_sky_fill.visible = GameConfig.outdoor_fill_energy > 0.0
	for root: Node in _outdoor_roots():
		_mark_outdoor(root)
	get_tree().node_added.connect(_on_node_added)


func _outdoor_roots() -> Array[Node]:
	var roots: Array[Node] = [$Outside, $EntranceSteps, $UpperFloors]
	var facade := get_node_or_null("GroundFloorRoom/Facade")
	if facade:
		roots.append(facade)
	return roots


func _mark_outdoor(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).set_layer_mask_value(GameConfig.OUTDOOR_RENDER_LAYER, true)
	for child in node.get_children():
		_mark_outdoor(child)


func _on_node_added(node: Node) -> void:
	if not node is VisualInstance3D:
		return
	for root: Node in _outdoor_roots():
		if root.is_ancestor_of(node):
			(node as VisualInstance3D).set_layer_mask_value(GameConfig.OUTDOOR_RENDER_LAYER, true)
			return


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


## Sonne nach GameConfig.sun_elevation / sun_azimuth ausrichten (das Licht fällt von dort ein).
func _apply_sun_direction() -> void:
	var el := deg_to_rad(GameConfig.sun_elevation)
	var az := deg_to_rad(GameConfig.sun_azimuth)
	# Richtung zur Sonne: gegenüber liegt bei -Z, rechts (vom Laden aus) bei +X
	var to_sun := Vector3(cos(el) * sin(az), sin(el), -cos(el) * cos(az))
	_sun.basis = Basis.looking_at(-to_sun, Vector3.UP)


## Sonnenschatten: Die Sonne verteilt ihre Schatten auf mehrere Stufen ("Kaskaden") – nah
## an der Kamera fein, weiter weg gröber. Ohne Überblendung sieht man dort, wo eine Stufe in
## die nächste übergeht, eine Linie im Fensterlicht, die beim Laufen mitwandert. Deshalb
## werden die Übergänge weich überblendet.
## Die Schattenkanten macht der normale weiche Filter (Sun: shadow_blur) weich. Eine "breite
## Sonnenscheibe" (light_angular_distance > 0) bleibt bewusst aus (seit Etappe 4c): Sie ist
## teurer und zeigte an langen geraden Kanten (Dachkante, Fenstersturz, Fensterlicht am Boden)
## eine Treppenlinie.
func _apply_sun_shadows(preset: Dictionary) -> void:
	var two := int(preset.get("sun_cascades", 4)) <= 2
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if two \
		else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	# Bei 2 Stufen liegt die Grenze weiter weg, damit das Fensterlicht in der feinen
	# ersten Stufe liegt (Anteil der Schattenweite, siehe GameConfig)
	# Erste Stufe fein (etwa 5 m, Fensterlicht), weiter weg gröber bis zur ganzen Straße
	_sun.directional_shadow_split_1 = GameConfig.sun_two_cascade_split if two else 0.07
	_sun.directional_shadow_split_2 = 0.2
	_sun.directional_shadow_split_3 = 0.5
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_max_distance = GameConfig.sun_shadow_distance
