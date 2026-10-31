class_name VehicleModel
extends Node3D
## Aussehen eines Fahrzeugs (seit Etappe 6c im Bilderbuch-Stil, tools/blender/build_storybook_vehicles.py):
## die Karosserie liegt als Kind darin (.glb), die Räder setzt dieses Script ein (wheel_scene an
## wheel_positions, rechts gespiegelt) und dreht sie beim Fahren; die Vorderräder lenken in Kurven mit.
## Die Karosserie federt weich: beim Bremsen nickt sie nach vorn, beim Anfahren nach hinten, in Kurven
## neigt sie sich nach außen (Werte in GameConfig: vehicle_*).
## Lackfarbe = Farbe des Wagens (StreetLife wählt sie aus GameConfig.car_colors), außer fixed_color ist
## an (z. B. das Taxi): Materialien "Autolack"/"Autolack zwei" bekommen je Wagen eine eigene Kopie in der
## Farbe; ältere Stil-Modelle färbt der Instanz-Wert accent_color/door_color.
## Vorderseite +Z, Räder auf y = 0. Eigenes Modell: siehe docs/ASSET_GUIDE.md.

## Materialnamen (Blender), die je Wagen umgefärbt werden
const PAINT_NAMES := ["Autolack"]
const SECOND_NAMES := ["Autolack zwei"]

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
var _front: Array[bool] = []
var _spin := 0.0
## Karosserie (alles außer den Rädern) hängt an diesem Knoten und federt
var _sway: Node3D
var _pitch := 0.0
var _pitch_speed := 0.0
var _roll := 0.0
var _roll_speed := 0.0
var _steer := 0.0
var _wheelbase := 2.4


func _ready() -> void:
	if _sway == null:
		_sway = Node3D.new()
		_sway.name = "Sway"
		add_child(_sway)
		for child in get_children():
			if child != _sway:
				child.reparent(_sway, false)
	if _wheels.is_empty() and wheel_scene:
		var zs: Array[float] = []
		for p in wheel_positions:
			zs.append(p.z)
			for side in [1.0, -1.0]:
				var wheel := wheel_scene.instantiate() as Node3D
				wheel.name = "Wheel%d" % (_wheels.size() + 1)
				add_child(wheel)
				wheel.position = Vector3(p.x * side, p.y, p.z)
				_wheels.append(wheel)
				_mirrored.append(side < 0.0)
				_front.append(p.z > 0.0)
		if zs.size() >= 2:
			_wheelbase = zs.max() - zs.min()
		animate(0.0, 0.0)
	_apply(paint_color)


func build(_rng: RandomNumberGenerator, color: Color) -> void:
	_apply(paint_color if fixed_color else color)
	_pitch = 0.0
	_pitch_speed = 0.0
	_roll = 0.0
	_roll_speed = 0.0
	_steer = 0.0


func _apply(color: Color) -> void:
	for part: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		part.set_instance_shader_parameter("accent_color", color)
		part.set_instance_shader_parameter("door_color", second_color)
		var mesh_part := part as MeshInstance3D
		if mesh_part == null or mesh_part.mesh == null:
			continue
		for i in mesh_part.mesh.get_surface_count():
			var base := mesh_part.mesh.surface_get_material(i)
			if base == null:
				continue
			var tint: Variant = null
			if base.resource_name in PAINT_NAMES:
				tint = color
			elif base.resource_name in SECOND_NAMES:
				tint = second_color
			if tint == null:
				continue
			# eigene Kopie je Wagen (einmal angelegt, danach nur umgefärbt)
			var own := mesh_part.get_surface_override_material(i)
			if own == null:
				own = base.duplicate()
				mesh_part.set_surface_override_material(i, own)
			if own is ShaderMaterial:
				(own as ShaderMaterial).set_shader_parameter("base_color", tint)
			elif own is StandardMaterial3D:
				(own as StandardMaterial3D).albedo_color = tint


## Räder drehen passend zum Tempo (vorwärts = +Z).
func animate(speed: float, delta: float) -> void:
	animate_drive(speed, delta, 0.0, 0.0)


## Fahren mit Beschleunigung (m/s², für das Nicken) und Drehrate (rad/s, für Lenken und Neigen).
func animate_drive(speed: float, delta: float, accel: float, turn_rate: float) -> void:
	_spin = fmod(_spin + speed / maxf(0.05, wheel_radius) * delta, TAU)
	if delta > 0.0:
		# Lenkeinschlag aus der Kurve (Fahrradmodell: tan(Winkel) = Radstand · Drehrate / Tempo)
		var want := atan(_wheelbase * turn_rate / maxf(speed, 1.0))
		want = clampf(want, -GameConfig.vehicle_max_steer, GameConfig.vehicle_max_steer)
		_steer = lerpf(_steer, want, minf(1.0, delta * 6.0))
		# Federung: weich nachschwingend zum Ziel (Bremsen = Nase runter, Kurve = nach außen neigen)
		var pitch_goal := clampf(-accel * GameConfig.vehicle_pitch_per_accel, -0.05, 0.05)
		var roll_goal := clampf(speed * turn_rate * GameConfig.vehicle_roll_per_accel, -0.05, 0.05)
		var k := GameConfig.vehicle_spring
		var d := GameConfig.vehicle_damping
		# in kleinen Schritten rechnen (bleibt auch bei einem Ruckler ruhig), Ausschlag begrenzt
		var left := minf(delta, 0.25)
		while left > 0.0:
			var dt := minf(left, 1.0 / 120.0)
			left -= dt
			_pitch_speed += ((pitch_goal - _pitch) * k - _pitch_speed * d) * dt
			_pitch = clampf(_pitch + _pitch_speed * dt, -0.06, 0.06)
			_roll_speed += ((roll_goal - _roll) * k - _roll_speed * d) * dt
			_roll = clampf(_roll + _roll_speed * dt, -0.06, 0.06)
	for i in _wheels.size():
		var turn := Basis(Vector3.UP, _steer) if _front[i] else Basis.IDENTITY
		if _mirrored[i]:
			_wheels[i].basis = turn * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -_spin)
		else:
			_wheels[i].basis = turn * Basis(Vector3.RIGHT, _spin)
	if _sway:
		# Drehpunkt in Höhe der Achsen, damit die Räder auf dem Boden bleiben
		var pivot := Vector3(0.0, wheel_radius, 0.0)
		var b := Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.BACK, _roll)
		_sway.transform = Transform3D(b, pivot - b * pivot)


func set_shadows(enabled: bool) -> void:
	for part: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
