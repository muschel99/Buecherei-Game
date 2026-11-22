class_name ShopGlow
extends Node3D
## Ladenlicht (seit der großen Überarbeitung; seit dem zweiten Nachtest je Laden und nach dem Verkäufer, Wunsch der Entwicklerin:
## „Beleuchtung, die nur aus ist, wenn die Verkäufer nicht da sind – bis 22 Uhr sieht man, dass sie offen haben“).
## Je Laden: ein warmes Licht innen (hellt den Raum hinter den Scheiben auf), ein paar weiche Lichter knapp vor der Ladenfront
## (Schein auf Gehweg und Hauswand) und das Leuchten der Einrichtung (Shader-Wert shop_lit am Hausmodell, storybook.gdshaderinc).
## An, solange StreetHomes das Licht des Ladens an hat (shop.light_on: der Verkäufer schaltet es morgens an der Tür an und
## abends an der Tür aus); tagsüber schwächer, abends voll; alles sanft überblendet. Werte: GameConfig.shop_glow_* und
## shop_light_*. main.gd legt den Knoten unter Outside an.

var _shops: Array[Dictionary] = []   # {shop, front: [OmniLight3D], inside: OmniLight3D, meshes: [GeometryInstance3D], level}
var _night := 0.0
var _check := 0.0


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	for k in 3:
		await get_tree().physics_frame
	var life := get_tree().get_first_node_in_group(StreetLife.GROUP) as StreetLife
	if life == null or life.homes == null:
		return
	for shop: Dictionary in life.homes.shops:
		var house := shop.get("house") as Node3D
		if house == null:
			continue
		var entry := {"shop": shop, "front": [] as Array[OmniLight3D], "inside": null, "meshes": [] as Array[GeometryInstance3D],
			"level": -1.0}
		var width := float(house.get("width")) if house.get("width") != null else 5.0
		var offsets: Array[float] = []
		if width < 6.0:
			offsets.append_array([-width * 0.25, width * 0.25])
		else:
			offsets.append_array([-width * 0.32, 0.0, width * 0.32])
		for x in offsets:
			var light := _make_light("ShopGlow", GameConfig.shop_glow_range, 1.6)
			light.global_position = house.to_global(Vector3(x, GameConfig.shop_glow_height, GameConfig.shop_glow_out))
			(entry.front as Array).append(light)
		# innen: zwischen Theke und Tür, unter der Decke
		var counter: Dictionary = shop.get("counter", {})
		if not counter.is_empty():
			var mid: Vector2 = ((counter.pos as Vector2) + (shop.inner as Vector2)) / 2.0
			var light := _make_light("ShopInside", GameConfig.shop_light_range, 0.9)
			light.global_position = life.to_global(Vector3(mid.x, float(counter.floor) + GameConfig.shop_light_height, mid.y))
			entry.inside = light
		for node: Node in house.find_children("*", "GeometryInstance3D", true, false):
			(entry.meshes as Array).append(node)
		_shops.append(entry)


func _make_light(light_name: String, light_range: float, attenuation: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_name
	light.light_color = GameConfig.shop_glow_color
	light.light_energy = 0.0
	light.light_specular = 0.2
	light.omni_range = light_range
	light.omni_attenuation = attenuation
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 34.0
	light.distance_fade_length = 8.0
	light.visible = false
	add_child(light)
	return light


func _process(delta: float) -> void:
	if _shops.is_empty():
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		# (nicht RenderingServer.global_shader_parameter_get – das bremst außerhalb des Editors das ganze Spiel)
		_night = smoothstep(0.15, 0.6, DayCycle.night)
	for entry in _shops:
		var target := 1.0 if bool((entry.shop as Dictionary).get("light_on", true)) else 0.0
		var level := float(entry.level)
		if level >= 0.0 and is_equal_approx(level, target) and is_equal_approx(float(entry.get("night", -1.0)), _night):
			continue
		level = target if level < 0.0 else move_toward(level, target, delta / GameConfig.shop_light_fade)
		entry.level = level
		entry.night = _night
		_apply(entry, level)


func _apply(entry: Dictionary, level: float) -> void:
	var front := level * GameConfig.shop_glow_energy * lerpf(GameConfig.shop_glow_day_share, 1.0, _night)
	for light: OmniLight3D in entry.front:
		light.light_energy = front
		light.visible = front > 0.01
	var inside := entry.inside as OmniLight3D
	if inside:
		inside.light_energy = level * GameConfig.shop_light_energy * lerpf(GameConfig.shop_light_day_share, 1.0, _night)
		inside.visible = inside.light_energy > 0.01
	for mesh: GeometryInstance3D in entry.meshes:
		if is_instance_valid(mesh):
			mesh.set_instance_shader_parameter(&"shop_lit", level)
