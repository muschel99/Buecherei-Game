extends Node3D
## Hauptszene. Lädt beim Start den gespeicherten Spielstand (falls vorhanden) und
## stellt die Effekte der Umgebung passend zur gewählten Grafikstufe ein.

const LANTERN_GLASS := "res://assets/materials/storybook/laternenglas_leuchtend.tres"

@onready var _environment: Environment = $WorldEnvironment.environment
@onready var _dust: GPUParticles3D = $GroundFloorRoom/WindowDust
@onready var _sun: DirectionalLight3D = $Sun
@onready var _sky_fill: DirectionalLight3D = $SkyFill

var _dust_amount: int = 0
## Malfilter „Aquarell“ (Einstellung Grafik → Malstil)
var _paint := PaintFilterEffect.new()


func _ready() -> void:
	_dust_amount = _dust.amount
	# Draußen liegt alles tiefer als der Ladenboden (Etappe 4d, GameConfig.shop_floor_rise)
	($Outside as Node3D).position.y = StreetLayout.ground_y()
	_apply_sun_direction()
	_setup_paint_filter()
	_apply_graphics_quality()
	_setup_sky_fill()
	# Licht und Himmel über den Tag (seit Etappe 7)
	if GameConfig.day_cycle_enabled:
		var cycle := DayCycle.new()
		cycle.name = "DayCycle"
		add_child(cycle)
		cycle.setup(self, _sun, _sky_fill, _environment)
	Settings.setting_changed.connect(_on_setting_changed)
	# Geräuschkulisse und Musik (Audio-System: Dateien in assets/audio/ambience und assets/audio/music)
	Audio.start_ambience("ambience/outdoor")
	Audio.start_music()
	# Vögel und Katzen sind seit Etappe 6f still: Tiergeräusche kommen nur noch von sichtbaren Tieren (Vögel folgen)
	_add_library_occluders()
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
	var room := get_node_or_null("GroundFloorRoom")
	if room:
		_mark_indoor(room)
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
	var room := get_node_or_null("GroundFloorRoom")
	if room and room.is_ancestor_of(node) and not node is Light3D:
		(node as VisualInstance3D).set_layer_mask_value(GameConfig.INDOOR_RENDER_LAYER, true)


## Alles im Raum (ohne die Fassade) bekommt die Innen-Ebene – nur das trifft das Tageslicht der Fenster.
func _mark_indoor(node: Node) -> void:
	if node.name == "Facade" and node.get_parent() == get_node_or_null("GroundFloorRoom"):
		return
	if node is VisualInstance3D and not node is Light3D:
		(node as VisualInstance3D).set_layer_mask_value(GameConfig.INDOOR_RENDER_LAYER, true)
	for child in node.get_children():
		_mark_indoor(child)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "graphics/quality":
		_apply_graphics_quality()
	elif key == "graphics/paint_style":
		_paint.enabled = int(Settings.get_value("graphics/paint_style")) == 1


## Malfilter als Nachbearbeitung der Kamera-Bilder dieser Welt (Compositor der WorldEnvironment).
func _setup_paint_filter() -> void:
	var compositor := Compositor.new()
	compositor.compositor_effects = [_paint]
	($WorldEnvironment as WorldEnvironment).compositor = compositor
	_paint.enabled = int(Settings.get_value("graphics/paint_style")) == 1


## Aufwändige Effekte je nach Grafikstufe (Werte in GameConfig.graphics_presets).
func _apply_graphics_quality() -> void:
	var preset := Settings.get_graphics_preset()
	_paint.apply_config(preset)
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
	_apply_light_mood()


## Straßen- und Wandlaternen an oder aus (seit Etappe 6j): Am hellen Tag brennen sie nicht – das Glas ist dann matt
## und hell statt leuchtend. Für den späteren Tagesablauf (Etappe 7): abends set_street_lanterns(true).
func set_street_lanterns(lit: bool) -> void:
	var glass := load(LANTERN_GLASS) as ShaderMaterial
	if glass == null:
		return
	if not glass.has_meta("lit_energy"):
		glass.set_meta("lit_energy", glass.get_shader_parameter("emission_energy"))
		glass.set_meta("lit_color", glass.get_shader_parameter("base_color"))
	glass.set_shader_parameter("emission_energy", glass.get_meta("lit_energy") if lit else 0.0)
	glass.set_shader_parameter("base_color", glass.get_meta("lit_color") if lit else GameConfig.lantern_glass_off_color)
	glass.set_shader_parameter("second_color", glass.get_meta("lit_color") if lit else GameConfig.lantern_glass_off_color)


## Lichtstimmung (seit Etappe 6j, alle Werte in GameConfig "light_*"): warme Nachmittagssonne, kühleres Himmelslicht in
## den Schatten, blauer Himmel mit warmem Horizont, sanftes Leuchten um helle Stellen.
func _apply_light_mood() -> void:
	set_street_lanterns(GameConfig.street_lanterns_lit)
	_sun.light_color = GameConfig.light_sun_color
	_sun.light_energy = GameConfig.light_sun_energy
	_environment.ambient_light_color = GameConfig.light_ambient_color
	_environment.ambient_light_energy = GameConfig.light_ambient_energy
	_environment.tonemap_exposure = GameConfig.light_exposure
	_environment.adjustment_saturation = GameConfig.light_saturation
	_environment.adjustment_contrast = GameConfig.light_contrast
	_environment.glow_intensity = GameConfig.light_glow_intensity
	_environment.glow_bloom = GameConfig.light_glow_bloom
	_environment.ssao_intensity = GameConfig.light_ssao_intensity
	_environment.ssao_radius = GameConfig.light_ssao_radius
	var sky := _environment.sky.sky_material as ProceduralSkyMaterial if _environment.sky else null
	if sky:
		sky.sky_top_color = GameConfig.light_sky_top_color
		sky.sky_horizon_color = GameConfig.light_sky_horizon_color
		sky.ground_horizon_color = GameConfig.light_sky_horizon_color
		sky.sky_curve = GameConfig.light_sky_curve


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


## Verdecker (Occlusion Culling, seit Etappe 6d): Was hinter einem Verdecker liegt, zeichnet Godot nicht.
## Ein Verdecker darf nur in wirklich massiven Teilen stecken – seit Etappe 6f darum nur noch in den zwei
## fensterlosen Wänden der Bücherei (Rückwand, Wand zum Nachbarn; hilft vor allem im Laden). In den Häusern
## füllte ein Kasten das ganze Innere: Alles hinter den Schaufenstern (Lampen, Flaschen, Kerzen, Blumen, die
## Tafel im Pub-Fenster) galt dann als verdeckt und verschwand oder flackerte beim Gehen.
func _add_library_occluders() -> void:
	if not GameConfig.library_occluders:
		return
	var room := $GroundFloorRoom as Node3D
	for spec in [[Vector3(0.0, 1.6, 4.1), Vector3(6.0, 3.0, 0.15)], [Vector3(3.1, 1.6, 0.0), Vector3(0.15, 3.0, 8.0)]]:
		var box := BoxOccluder3D.new()
		box.size = spec[1]
		var occluder := OccluderInstance3D.new()
		occluder.name = "Occluder"
		occluder.occluder = box
		occluder.position = spec[0]
		room.add_child(occluder)
