class_name ShopGlow
extends Node3D
## Warmes Licht aus den Schaufenstern (seit der großen Überarbeitung, Wunsch: gemütliche Abende wie auf den Inspirations-
## bildern): Abends, solange die Läden geöffnet haben (StreetHomes.shops_open), fällt vor jedem Laden ein weicher, warmer
## Lichtschein auf Gehweg und Hauswand – ein paar OmniLights ohne Schatten knapp vor der Ladenfront. Tagsüber und nach
## Ladenschluss aus (sanft überblendet). Werte: GameConfig.shop_glow_*. main.gd legt den Knoten unter Outside an.

var _lights: Array[OmniLight3D] = []
var _amount := 0.0
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
		var width := float(house.get("width")) if house.get("width") != null else 5.0
		var offsets: Array[float] = []
		if width < 6.0:
			offsets.append_array([-width * 0.25, width * 0.25])
		else:
			offsets.append_array([-width * 0.32, 0.0, width * 0.32])
		for x in offsets:
			var light := OmniLight3D.new()
			light.name = "ShopGlow"
			light.light_color = GameConfig.shop_glow_color
			light.light_energy = 0.0
			light.omni_range = GameConfig.shop_glow_range
			light.omni_attenuation = 1.6
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 34.0
			light.distance_fade_length = 8.0
			light.visible = false
			add_child(light)
			light.global_position = house.to_global(Vector3(x, GameConfig.shop_glow_height, GameConfig.shop_glow_out))
			_lights.append(light)


func _process(delta: float) -> void:
	if _lights.is_empty():
		return
	_check -= delta
	var target := _amount
	if _check <= 0.0:
		_check = 0.5
		var value: Variant = RenderingServer.global_shader_parameter_get(&"night_glow")
		var night: float = value if value is float else 0.0
		target = smoothstep(0.15, 0.6, night) if StreetHomes.shops_open() else 0.0
		set_meta(&"target", target)
	target = float(get_meta(&"target", 0.0))
	if is_equal_approx(_amount, target):
		return
	_amount = move_toward(_amount, target, delta / 2.5)
	for light in _lights:
		light.light_energy = GameConfig.shop_glow_energy * _amount
		light.visible = _amount > 0.01
