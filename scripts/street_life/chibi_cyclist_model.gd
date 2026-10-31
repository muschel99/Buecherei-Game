class_name ChibiCyclistModel
extends Node3D
## Radfahrerin oder Radfahrer als Chibi-Figur (seit Etappe 5c): das Chibi-Hollandrad
## (tools/blender/build_vehicles.py: Rahmen bicycle_chibi, Sattel und Kurbel als eigene Teile; Räder
## und Kurbel drehen sich), eingestellt wie ein echtes Rad für die Figur: Rahmengröße
## (ChibiPasserbyModel.ride_scale) und Sattelhöhe (ride_seat). Darauf eine zufällig eingekleidete
## Chibi-Figur; sie tritt mit der Animation "ride" (tools/blender/chibi_ride.py) genau im Takt der
## Kurbel. Dieselbe Schnittstelle wie CyclistPlaceholder (StreetVehicle ruft build, animate,
## set_shadows). Vorderseite nach +Z, Räder auf y = 0.

## Hollandrad in voller Größe (wie chibi_ride.py): Radius, Achsen vorn/hinten, Kurbel, Sitzpunkt
const WHEEL := 0.34
const WHEEL_Z := 0.52
const CRANK := Vector3(0.0, 0.36, 0.02)
const SEAT_Z := -0.22
## Übersetzung: so viele Radumdrehungen je Kurbelumdrehung
const GEAR := 2.4
## Rahmengröße und Sitzpunkt, falls die Figur keine Radfahr-Animation hat
const FALLBACK_SCALE := 0.88
const FALLBACK_SEAT := 0.8

const BIKE_SCENE := preload("res://assets/models/vehicles/bicycle_chibi.glb")
const SADDLE_SCENE := preload("res://assets/models/vehicles/bicycle_chibi_saddle.glb")
const WHEEL_SCENE := preload("res://assets/models/vehicles/bicycle_wheel.glb")
const CRANK_SCENE := preload("res://assets/models/vehicles/bicycle_chibi_crank.glb")
const BASKET_SCENE := preload("res://assets/models/vehicles/bicycle_chibi_basket.glb")
## Material des Rahmens (Blender-Name), das je Fahrrad umgefärbt wird
const PAINT_NAME := "Fahrradlack"

var _rider: ChibiPasserbyModel
var _bike: Node3D
var _wheels: Array[Node3D] = []
var _crank_node: Node3D
var _saddle: Node3D
var _crank := 0.0
var _roll := 0.0
var _scale := FALLBACK_SCALE
## Schräglage in Kurven (Bogenmaß)
var _lean := 0.0


func _ready() -> void:
	if _rider == null:
		build(RandomNumberGenerator.new(), Color(0.3, 0.45, 0.55))


func build(rng: RandomNumberGenerator, color: Color) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_wheels.clear()
	# Figur zuerst: ihre Beinlänge bestimmt die Größe des Fahrrads
	_rider = ChibiPasserbyModel.new()
	_rider.name = "Rider"
	add_child(_rider)
	_rider.randomize_look(rng)
	_bike = Node3D.new()
	_bike.name = "Bike"
	add_child(_bike)
	var frame := BIKE_SCENE.instantiate() as Node3D
	frame.name = "Bicycle"
	_bike.add_child(frame)
	_paint_frame(frame, color)
	for z in [WHEEL_Z, -WHEEL_Z]:
		var wheel := WHEEL_SCENE.instantiate() as Node3D
		wheel.position = Vector3(0.0, WHEEL, z)
		_bike.add_child(wheel)
		_wheels.append(wheel)
	_crank_node = CRANK_SCENE.instantiate() as Node3D
	_crank_node.position = CRANK
	_bike.add_child(_crank_node)
	_saddle = SADDLE_SCENE.instantiate() as Node3D
	_bike.add_child(_saddle)
	if rng.randf() < 0.5:
		# geflochtener Korb vorn auf seinem Träger
		var basket := BASKET_SCENE.instantiate() as Node3D
		basket.name = "Basket"
		_bike.add_child(basket)
	_fit_bike()
	_crank = rng.randf() * TAU
	animate(0.0, 0.0)


## Fahrrad für die Figur einstellen: Rahmengröße und Sattelhöhe (die kennt sie erst, wenn ihr
## Modell geladen ist).
func _fit_bike() -> void:
	_scale = _rider.ride_scale if _rider.ride_scale > 0.0 else FALLBACK_SCALE
	if not is_equal_approx(_bike.scale.x, _scale):
		_bike.scale = Vector3.ONE * _scale
	var seat := _rider.ride_seat if _rider.ride_seat > 0.0 else FALLBACK_SEAT
	if _saddle and not is_equal_approx(_saddle.position.y, seat):
		_saddle.position = Vector3(0.0, seat, SEAT_Z)


## Rahmenfarbe: eigene Kopie des Lacks (Bilderbuch-Modell), ältere Modelle über den Instanz-Wert.
func _paint_frame(frame: Node, color: Color) -> void:
	for part: GeometryInstance3D in frame.find_children("*", "GeometryInstance3D", true, false):
		part.set_instance_shader_parameter("accent_color", color)
		var mesh_part := part as MeshInstance3D
		if mesh_part == null or mesh_part.mesh == null:
			continue
		for i in mesh_part.mesh.get_surface_count():
			var base := mesh_part.mesh.surface_get_material(i)
			if base and base.resource_name == PAINT_NAME and base is ShaderMaterial:
				var own := base.duplicate() as ShaderMaterial
				own.set_shader_parameter("base_color", color)
				mesh_part.set_surface_override_material(i, own)


## Fahren mit Drehrate (rad/s): in Kurven legt sich das Rad samt Figur hinein.
func animate_drive(speed: float, delta: float, _accel: float, turn_rate: float) -> void:
	if delta > 0.0:
		var want := -atan(speed * turn_rate / 9.81) * GameConfig.cyclist_lean_factor
		_lean = lerpf(_lean, clampf(want, -0.35, 0.35), minf(1.0, delta * 4.0))
		rotation.z = _lean
	animate(speed, delta)


## Treten: Räder und Kurbel drehen sich passend zum Tempo, die Figur folgt der Kurbel.
func animate(speed: float, delta: float) -> void:
	if _rider == null:
		return
	_fit_bike()
	var wheel := WHEEL * _scale
	_roll = fmod(_roll + speed / wheel * delta, TAU)
	_crank = fmod(_crank + speed / (wheel * GEAR) * delta, TAU)
	for w in _wheels:
		w.basis = Basis(Vector3.RIGHT, _roll)
	# Kurbel dreht wie die Räder (oben nach vorn); bei 0 zeigt die Kurbel auf der Seite x < 0 nach vorn
	if _crank_node:
		_crank_node.basis = Basis(Vector3.RIGHT, _crank)
	_rider.pose_ride(_crank, delta)


func set_shadows(enabled: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _bike:
		for part: GeometryInstance3D in _bike.find_children("*", "GeometryInstance3D", true, false):
			part.cast_shadow = mode
	if _rider:
		_rider.set_shadows(1 if enabled else 0)
