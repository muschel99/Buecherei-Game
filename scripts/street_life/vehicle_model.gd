class_name VehicleModel
extends Node3D
## Aussehen eines Fahrzeugs aus den Stil-Modellen (seit Etappe 5b, tools/blender/build_vehicles.py):
## die Karosserie liegt als Kind darin (.glb), die Räder setzt dieses Script ein (wheel_scene an
## wheel_positions, rechts gespiegelt) und dreht sie beim Fahren. Lackfarbe = Farbe des Wagens
## (StreetLife wählt sie aus GameConfig.car_colors), außer fixed_color ist an (z. B. das Taxi).
## Vorderseite +Z, Räder auf y = 0. Eigenes Modell: siehe docs/ASSET_GUIDE.md.

## Ein Rad (.glb, Achse x, Außenseite nach +x).
@export var wheel_scene: PackedScene
@export var wheel_radius: float = 0.3
## Mitten der Räder auf der linken Seite (x > 0); die rechte Seite wird gespiegelt.
@export var wheel_positions: Array[Vector3] = []
## Feste Lackfarbe statt der zufälligen Wagenfarbe.
@export var fixed_color: bool = false
@export var paint_color: Color = Color(0.05, 0.05, 0.055)
## Zweite Farbe (Dach, obere Hälfte, Felgen).
@export var second_color: Color = Color(0.93, 0.9, 0.82)

var _wheels: Array[Node3D] = []
var _mirrored: Array[bool] = []
var _spin := 0.0


func _ready() -> void:
	if _wheels.is_empty() and wheel_scene:
		for p in wheel_positions:
			for side in [1.0, -1.0]:
				var wheel := wheel_scene.instantiate() as Node3D
				wheel.name = "Wheel%d" % (_wheels.size() + 1)
				add_child(wheel)
				wheel.position = Vector3(p.x * side, p.y, p.z)
				_wheels.append(wheel)
				_mirrored.append(side < 0.0)
		animate(0.0, 0.0)
	_apply(paint_color)


func build(_rng: RandomNumberGenerator, color: Color) -> void:
	_apply(paint_color if fixed_color else color)


func _apply(color: Color) -> void:
	for part: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		part.set_instance_shader_parameter("accent_color", color)
		part.set_instance_shader_parameter("door_color", second_color)


## Räder drehen passend zum Tempo (vorwärts = +Z).
func animate(speed: float, delta: float) -> void:
	_spin = fmod(_spin + speed / maxf(0.05, wheel_radius) * delta, TAU)
	for i in _wheels.size():
		if _mirrored[i]:
			_wheels[i].basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -_spin)
		else:
			_wheels[i].basis = Basis(Vector3.RIGHT, _spin)


func set_shadows(enabled: bool) -> void:
	for part: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
