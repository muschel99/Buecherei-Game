class_name DayCycle
extends Node
## Licht und Himmel über den Tag (seit Etappe 7): Sonne und Mond wandern mit der Uhr (GameClock), Farben von Licht, Himmel
## und Wolken folgen einer Tabelle von Stützpunkten (GameConfig.day_light_keys, dazwischen weich gemischt). Nachts übernimmt
## dasselbe Licht (Knoten "Sun") die Rolle des Mondes – nie zwei Schattenlichter gleichzeitig. Gemalter Himmel:
## assets/shaders/storybook_sky.gdshader (Wolken ziehen mit GameConfig.sky_cloud_wind). Laternen: abends an, morgens aus.
## Das Tageslicht durch die Fenster der Bücherei wird mit dem Tageslicht schwächer.
## Später: Wetter (cloud_cover, cloud_darkness) und Jahreszeiten (Sonnenbahn) – die Werte stehen schon bereit.

const SKY_SHADER := preload("res://assets/shaders/storybook_sky.gdshader")
## Diese Werte werden zwischen den Stützpunkten gemischt.
const KEYS := ["sun_color", "sun_energy", "moon_color", "moon_energy", "ambient_color", "ambient_energy", "sky_top",
	"sky_horizon", "fill_color", "fill_energy", "exposure", "cloud_lit", "cloud_shade", "stars", "window_light"]

var main: Node3D
var sun: DirectionalLight3D
var sky_fill: DirectionalLight3D
var environment: Environment
var _sky_material: ShaderMaterial
var _cloud_offset := Vector2.ZERO
var _lanterns_lit := -1
var _night_cover := 0.0


func setup(main_node: Node3D, sun_light: DirectionalLight3D, fill_light: DirectionalLight3D, env: Environment) -> void:
	main = main_node
	sun = sun_light
	sky_fill = fill_light
	environment = env
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	_cloud_offset = Vector2(randf() * 50.0, randf() * 50.0)
	apply(0.0)


func _process(delta: float) -> void:
	if sun:
		apply(delta)


## Alles auf die aktuelle Uhrzeit stellen (delta: Wolken ziehen weiter).
func apply(delta: float) -> void:
	var hour := GameClock.minute_of_day() / 60.0
	var v := _values_at(hour)
	# Sonne: Bahn von Sonnenaufgang (links, vom Laden aus gesehen) über Mittag bis Sonnenuntergang (rechts)
	var sun_up := GameConfig.sky_sunrise
	var sun_down := GameConfig.sky_sunset
	var day_t := (hour - sun_up) / (sun_down - sun_up)
	var sun_el := sin(clampf(day_t, 0.0, 1.0) * PI) * GameConfig.sky_sun_max_elevation
	if day_t < 0.0 or day_t > 1.0:
		sun_el = -10.0
	var sun_az := lerpf(GameConfig.sky_sun_azimuth_range.x, GameConfig.sky_sun_azimuth_range.y, clampf(day_t, 0.0, 1.0))
	# Mond: in der Nacht in einem flacheren Bogen über den Himmel
	var night_len := 24.0 - (sun_down - sun_up)
	var night_t := fposmod(hour - sun_down, 24.0) / night_len
	var moon_el := sin(clampf(night_t, 0.0, 1.0) * PI) * GameConfig.sky_moon_max_elevation
	if night_t > 1.0:
		moon_el = -10.0
	var moon_az := lerpf(GameConfig.sky_sun_azimuth_range.x * 0.7, GameConfig.sky_sun_azimuth_range.y * 0.7, clampf(night_t, 0.0, 1.0))
	var to_sun := _direction(sun_el, sun_az)
	var to_moon := _direction(moon_el, moon_az)
	# Ein Licht für beide: tags die Sonne, nachts der Mond (am Horizont jeweils auf fast 0 – kein Sprung)
	var sun_strength := smoothstep(0.0, 9.0, sun_el)
	var moon_strength := smoothstep(0.0, 9.0, moon_el)
	if sun_el > 0.0:
		_point_light(to_sun)
		sun.light_color = v.sun_color
		sun.light_energy = float(v.sun_energy) * sun_strength
	else:
		_point_light(to_moon)
		sun.light_color = v.moon_color
		sun.light_energy = float(v.moon_energy) * moon_strength
	sun.visible = sun.light_energy > 0.005
	environment.ambient_light_color = v.ambient_color
	environment.ambient_light_energy = v.ambient_energy
	environment.tonemap_exposure = v.exposure
	sky_fill.light_color = v.fill_color
	sky_fill.light_energy = v.fill_energy
	# Himmel
	_cloud_offset += GameConfig.sky_cloud_wind * delta
	var m := _sky_material
	m.set_shader_parameter("top_color", v.sky_top)
	m.set_shader_parameter("horizon_color", v.sky_horizon)
	m.set_shader_parameter("ground_color", (v.sky_horizon as Color).darkened(0.6))
	m.set_shader_parameter("curve", GameConfig.light_sky_curve)
	m.set_shader_parameter("sun_dir", to_sun)
	m.set_shader_parameter("sun_color", v.sun_color)
	m.set_shader_parameter("sun_visible", smoothstep(-3.0, 2.0, sun_el))
	m.set_shader_parameter("moon_dir", to_moon)
	m.set_shader_parameter("moon_visible", smoothstep(-2.0, 3.0, moon_el))
	m.set_shader_parameter("stars", v.stars)
	m.set_shader_parameter("cloud_cover", GameConfig.sky_cloud_cover)
	m.set_shader_parameter("cloud_offset", _cloud_offset)
	m.set_shader_parameter("cloud_lit", v.cloud_lit)
	m.set_shader_parameter("cloud_shade", v.cloud_shade)
	# Laternen: abends an, morgens aus
	var lit := 1 if GameClock.is_between(GameConfig.lanterns_on_hour, GameConfig.lanterns_off_hour) else 0
	if lit != _lanterns_lit:
		_lanterns_lit = lit
		if main.has_method("set_street_lanterns"):
			main.call("set_street_lanterns", lit == 1)
	_update_window_light(float(v.window_light))


## Licht so drehen, dass es aus Richtung "to" einfällt.
func _point_light(to: Vector3) -> void:
	sun.basis = Basis.looking_at(-to, Vector3.UP if absf(to.y) < 0.99 else Vector3.FORWARD)


## Richtung zum Himmelskörper: Höhe über dem Horizont und Richtung in Grad (0 = hinter den Häusern gegenüber der Bücherei,
## positiv = nach rechts vom Laden aus gesehen; wie GameConfig.sun_azimuth).
func _direction(elevation: float, azimuth: float) -> Vector3:
	var el := deg_to_rad(maxf(elevation, -10.0))
	var az := deg_to_rad(azimuth)
	return Vector3(cos(el) * sin(az), sin(el), -cos(el) * cos(az)).normalized()


## Werte der Tabelle zur Uhrzeit (Stützpunkte nach Stunde, über Mitternacht weiter).
func _values_at(hour: float) -> Dictionary:
	var table: Array[Dictionary] = GameConfig.day_light_keys
	var count := table.size()
	# letzter Stützpunkt bis zur Uhrzeit (vor dem ersten: der letzte des Vortags) und der nächste danach
	var bi := count - 1
	for i in count:
		if float(table[i].hour) <= hour:
			bi = i
	var before: Dictionary = table[bi]
	var after: Dictionary = table[(bi + 1) % count]
	var h0 := float(before.hour)
	var h1 := float(after.hour)
	if h1 <= h0:
		h1 += 24.0
	var h := hour if hour >= h0 else hour + 24.0
	var t := smoothstep(0.0, 1.0, clampf((h - h0) / maxf(h1 - h0, 0.001), 0.0, 1.0))
	var out := {}
	for key: String in KEYS:
		var a: Variant = before.get(key)
		var b: Variant = after.get(key)
		if a is Color:
			out[key] = (a as Color).lerp(b, t)
		else:
			out[key] = lerpf(float(a), float(b), t)
	return out


## Tageslicht durch die Fenster der Bücherei mit der Helligkeit draußen.
func _update_window_light(factor: float) -> void:
	var room := main.get_node_or_null("GroundFloorRoom")
	if room == null or not room.has_meta("window_daylight"):
		return
	var holder: Variant = room.get_meta("window_daylight")
	if not is_instance_valid(holder):
		return
	for light: Node in (holder as Node).get_children():
		if light is Light3D:
			if not light.has_meta("base_energy"):
				light.set_meta("base_energy", (light as Light3D).light_energy)
			(light as Light3D).light_energy = float(light.get_meta("base_energy")) * factor
			(light as Light3D).visible = factor > 0.02
