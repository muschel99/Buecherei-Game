class_name PasserbyPlaceholder
extends Node3D
## Platzhalter-Figur eines Passanten (seit Etappe 5a): angedeutete Form aus runden Teilen –
## Kopf (mit Frisur, manchmal Hut), Körper (manchmal Mantel oder Tasche), Arme und Beine.
## Jede Figur bekommt eigene Farben und eine eigene Größe (randomize_look). Die Laufbewegung
## macht dieses Script selbst (animate): Beine und Arme schwingen, der Körper wippt leicht;
## beim Umschauen dreht sich der Kopf.
##
## Eigene Figur statt Platzhalter: In scenes/street_life/passerby.tscn den Knoten "Model"
## ersetzen (Anleitung: docs/ASSET_GUIDE.md, „Eigene Passanten“). Die Figur steht mit den
## Füßen auf y = 0 und schaut nach +Z.
##
## Leistung: Nah sind es sieben Teile, ab GameConfig.street_detail_distance zeigt die Figur nur
## noch ein einziges, vereinfachtes Teil ohne Bewegung (Sichtweite, visibility_range).

const SKIN_COLORS: Array[Color] = [
	Color(0.96, 0.8, 0.68), Color(0.88, 0.68, 0.52), Color(0.72, 0.5, 0.36),
	Color(0.55, 0.36, 0.25), Color(0.4, 0.26, 0.18), Color(0.98, 0.86, 0.76),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.18, 0.12, 0.08), Color(0.36, 0.22, 0.12), Color(0.62, 0.42, 0.22),
	Color(0.85, 0.72, 0.48), Color(0.72, 0.72, 0.7), Color(0.55, 0.22, 0.12), Color(0.1, 0.09, 0.09),
]
## Kleidung: ruhige, gemütliche Farben (Senf, Salbei, Rost, Marine, Creme, Pflaume …)
const TOP_COLORS: Array[Color] = [
	Color(0.78, 0.6, 0.3), Color(0.55, 0.64, 0.52), Color(0.66, 0.36, 0.26), Color(0.24, 0.3, 0.44),
	Color(0.88, 0.84, 0.74), Color(0.48, 0.3, 0.4), Color(0.36, 0.44, 0.36), Color(0.72, 0.48, 0.42),
	Color(0.5, 0.58, 0.68), Color(0.8, 0.72, 0.56),
]
const BOTTOM_COLORS: Array[Color] = [
	Color(0.22, 0.24, 0.3), Color(0.32, 0.28, 0.24), Color(0.42, 0.4, 0.36), Color(0.18, 0.18, 0.2),
	Color(0.5, 0.42, 0.32), Color(0.3, 0.36, 0.46),
]
const SHOE_COLORS: Array[Color] = [Color(0.15, 0.12, 0.1), Color(0.35, 0.24, 0.16), Color(0.85, 0.83, 0.8)]
const ACCENT_COLORS: Array[Color] = [
	Color(0.62, 0.22, 0.2), Color(0.3, 0.42, 0.34), Color(0.78, 0.66, 0.4), Color(0.38, 0.3, 0.24),
]

## Körpermaße bei Größe 1 (in Metern)
const HIP := 0.88
const SHOULDER_Y := 1.43
const SHOULDER_X := 0.235
const HEAD_Y := 1.5

## Tempo, bei dem die Schritte genau passen (Meter je Doppelschritt)
const STRIDE := 1.3

var _hips: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _near: Array[GeometryInstance3D] = []
var _far: MeshInstance3D
var _phase := 0.0
var _time := 0.0
var _swing := 0.0
var _head_yaw := 0.0
var _head_pitch := 0.0
var _detail_distance := 28.0


func _ready() -> void:
	if _hips == null:
		randomize_look(RandomNumberGenerator.new())


## Neues Aussehen: Farben, Frisur, Kleidung, Größe.
func randomize_look(rng: RandomNumberGenerator) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_arms.clear()
	_legs.clear()
	_near.clear()
	var skin: Color = SKIN_COLORS[rng.randi() % SKIN_COLORS.size()]
	var hair: Color = HAIR_COLORS[rng.randi() % HAIR_COLORS.size()]
	var top: Color = TOP_COLORS[rng.randi() % TOP_COLORS.size()]
	var bottom: Color = BOTTOM_COLORS[rng.randi() % BOTTOM_COLORS.size()]
	var shoes: Color = SHOE_COLORS[rng.randi() % SHOE_COLORS.size()]
	var accent: Color = ACCENT_COLORS[rng.randi() % ACCENT_COLORS.size()]
	var hair_style := rng.randi() % 5  # 0 kurz, 1 lang, 2 Dutt, 3 lockig, 4 fast keine
	var hat := rng.randf() < 0.18
	var coat := rng.randf() < 0.3
	var bag := rng.randf() < 0.3
	var width := rng.randf_range(0.92, 1.1)

	# Die Teile: Becken (wippt beim Gehen) mit Körper, Kopf und Armen; Beine an den Hüften
	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position.y = HIP
	add_child(_hips)
	var torso := StreetShapes.new()
	var torso_bottom := 0.5 if coat else 0.84
	_add_torso(torso, torso_bottom - HIP, width, top, coat)
	if bag:
		# Umhängetasche an der Seite, Riemen über die Schulter
		torso.add_round_box(Vector3(-0.25 * width, 0.98 - HIP, 0.02), Vector3(0.08, 0.26, 0.3), StreetShapes.solid(accent), 0.3)
		torso.add_round_box(Vector3(0.0, 1.26 - HIP, 0.0), Vector3(0.42 * width, 0.04, 0.27), StreetShapes.solid(accent.darkened(0.2)), 0.5)
	_near.append(_mesh_instance(_hips, "Torso", torso))

	_head = Node3D.new()
	_head.name = "Head"
	_head.position.y = HEAD_Y - HIP
	_hips.add_child(_head)
	var head := StreetShapes.new()
	_add_head(head, skin, hair, accent, hair_style, hat)
	_near.append(_mesh_instance(_head, "HeadMesh", head))

	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(side * SHOULDER_X * width, SHOULDER_Y - HIP, 0.0)
		_hips.add_child(arm)
		var arm_shapes := StreetShapes.new()
		_add_arm(arm_shapes, side, top if not coat else top.darkened(0.06), skin)
		_near.append(_mesh_instance(arm, "Mesh", arm_shapes))
		_arms.append(arm)
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(side * 0.095, HIP, 0.0)
		add_child(leg)
		var leg_shapes := StreetShapes.new()
		_add_leg(leg_shapes, bottom, shoes)
		_near.append(_mesh_instance(leg, "Mesh", leg_shapes))
		_legs.append(leg)

	# Vereinfachte Figur für die Ferne: alles in einem Teil, ohne Bewegung
	var far := StreetShapes.new()
	far.xform = Transform3D(Basis.IDENTITY, Vector3(0.0, HIP, 0.0))
	_add_torso(far, torso_bottom - HIP, width, top, coat)
	far.xform = Transform3D(Basis.IDENTITY, Vector3(0.0, HEAD_Y, 0.0))
	_add_head(far, skin, hair, accent, hair_style, hat, 8)
	for side in [-1.0, 1.0]:
		far.xform = Transform3D(Basis.IDENTITY, Vector3(side * SHOULDER_X * width, SHOULDER_Y, 0.0))
		_add_arm(far, side, top, skin, 8)
		far.xform = Transform3D(Basis.IDENTITY, Vector3(side * 0.095, HIP, 0.0))
		_add_leg(far, bottom, shoes, 8)
	_far = _mesh_instance(self, "Far", far)
	_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_detail_distance(_detail_distance)


## Ab dieser Entfernung (Meter) nur noch die vereinfachte Figur.
func set_detail_distance(distance: float) -> void:
	_detail_distance = distance
	for part in _near:
		part.visibility_range_end = distance
	if _far:
		_far.visibility_range_begin = distance


func set_shadows(enabled: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part in _near:
		part.cast_shadow = mode


## Bewegung je Bild: state = "walk", "idle", "look" (Umschauen) oder "browse" (ins Schaufenster
## schauen), speed = Tempo in m/s.
func animate(state: StringName, speed: float, delta: float) -> void:
	if _hips == null:
		return
	_time += delta
	var walking := state == &"walk" and speed > 0.05
	var target_swing := clampf(speed / 1.3, 0.25, 1.2) if walking else 0.0
	_swing = move_toward(_swing, target_swing, delta * 3.0)
	if walking:
		_phase = fmod(_phase + delta * speed / STRIDE * TAU, TAU)
	elif _swing < 0.01:
		_phase = move_toward(_phase, 0.0 if _phase < PI else TAU, delta * 4.0)
	var leg_angle := sin(_phase) * 0.42 * _swing
	var arm_angle := sin(_phase) * 0.32 * _swing
	_legs[0].rotation.x = leg_angle
	_legs[1].rotation.x = -leg_angle
	_arms[0].rotation.x = -arm_angle
	_arms[1].rotation.x = arm_angle
	# Bei jedem Schritt hebt sich das Becken ein wenig
	_hips.position.y = HIP + absf(sin(_phase)) * 0.022 * _swing - 0.01 * _swing
	_hips.rotation.y = sin(_phase) * 0.05 * _swing
	# Ruhig atmen im Stehen
	var breathe := sin(_time * 1.6) * 0.006 * (1.0 - minf(1.0, _swing))
	_hips.scale = Vector3(1.0, 1.0 + breathe, 1.0)
	# Kopf: beim Umschauen nach links und rechts, im Schaufenster leicht gesenkt
	var target_yaw := 0.0
	var target_pitch := 0.0
	if state == &"look":
		target_yaw = sin(_time * 1.4) * 0.75
	elif state == &"browse":
		target_yaw = sin(_time * 0.5) * 0.25
		target_pitch = 0.18
	_head_yaw = lerpf(_head_yaw, target_yaw, minf(1.0, delta * 5.0))
	_head_pitch = lerpf(_head_pitch, target_pitch, minf(1.0, delta * 3.0))
	_head.rotation = Vector3(_head_pitch, _head_yaw, 0.0)


func _mesh_instance(parent: Node3D, mesh_name: String, shapes: StreetShapes) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = shapes.commit()
	parent.add_child(instance)
	return instance


## Körper (relativ zum Becken): Oberkörper, bei Mantel bis über die Knie.
func _add_torso(shapes: StreetShapes, bottom: float, width: float, top: Color, coat: bool) -> void:
	var top_y := 1.47 - HIP
	var height := top_y - bottom
	shapes.add_round_box(Vector3(0.0, bottom + height / 2.0, 0.0), Vector3(0.4 * width, height, 0.25),
		StreetShapes.solid(top), 0.42)
	if coat:
		# Kragen und Knopfleiste
		shapes.add_round_box(Vector3(0.0, top_y - 0.03, 0.0), Vector3(0.3, 0.07, 0.24), StreetShapes.solid(top.darkened(0.15)), 0.5)
		shapes.add_round_box(Vector3(0.0, bottom + height * 0.55, 0.12), Vector3(0.025, height * 0.8, 0.02),
			StreetShapes.solid(top.darkened(0.2)), 0.6, 6, 4)
	else:
		# Gürtel
		shapes.add_round_box(Vector3(0.0, bottom + 0.03, 0.0), Vector3(0.405 * width, 0.05, 0.255), StreetShapes.solid(top.darkened(0.25)), 0.5)


## Kopf (relativ zum Hals): Gesicht mit angedeuteter Nase (zeigt die Blickrichtung), Frisur, Hut.
func _add_head(shapes: StreetShapes, skin: Color, hair: Color, accent: Color, style: int, hat: bool,
		segments: int = 14) -> void:
	var rings := segments / 2 + 1
	var skin_c := StreetShapes.solid(skin)
	var hair_c := StreetShapes.solid(hair)
	shapes.add_round_box(Vector3(0.0, -0.02, 0.0), Vector3(0.1, 0.08, 0.1), skin_c, 0.8, 8, 4)  # Hals
	shapes.add_ellipsoid(Vector3(0.0, 0.12, 0.0), Vector3(0.2, 0.245, 0.22), skin_c, segments, rings)
	shapes.add_ellipsoid(Vector3(0.0, 0.1, 0.105), Vector3(0.035, 0.05, 0.04), StreetShapes.solid(skin.darkened(0.06)), 6, 4)
	for x in [-0.042, 0.042]:  # Augen
		shapes.add_ellipsoid(Vector3(x, 0.14, 0.098), Vector3(0.022, 0.026, 0.012), StreetShapes.solid(Color(0.12, 0.1, 0.09)), 6, 3)
	if style != 4:
		# Hinterkopf (sonst sähe der Kopf von hinten wie ein Gesicht aus)
		shapes.add_round_box(Vector3(0.0, 0.115, -0.05), Vector3(0.212, 0.18, 0.13), hair_c, 0.85, segments, rings)
	match style:
		0:  # kurz
			shapes.add_ellipsoid(Vector3(0.0, 0.18, -0.012), Vector3(0.216, 0.155, 0.234), hair_c, segments, rings)
		1:  # lang, bis auf die Schultern
			shapes.add_ellipsoid(Vector3(0.0, 0.175, -0.01), Vector3(0.226, 0.175, 0.24), hair_c, segments, rings)
			shapes.add_round_box(Vector3(0.0, 0.02, -0.07), Vector3(0.23, 0.3, 0.12), hair_c, 0.55, 10, 6)
		2:  # Dutt
			shapes.add_ellipsoid(Vector3(0.0, 0.18, -0.012), Vector3(0.216, 0.155, 0.234), hair_c, segments, rings)
			shapes.add_ellipsoid(Vector3(0.0, 0.255, -0.09), Vector3(0.1, 0.09, 0.1), hair_c, 10, 5)
		3:  # lockig, voll
			shapes.add_ellipsoid(Vector3(0.0, 0.165, -0.02), Vector3(0.26, 0.22, 0.26), hair_c, segments, rings)
		_:  # fast keine Haare (nur hinten ein Kranz)
			shapes.add_round_box(Vector3(0.0, 0.09, -0.05), Vector3(0.21, 0.09, 0.13), hair_c, 0.85, segments, rings)
	if hat:
		var hat_c := StreetShapes.solid(accent)
		shapes.add_cylinder(Vector3(0.0, 0.215, 0.0), Vector3(0.0, 0.23, 0.0), 0.17, hat_c, segments)
		shapes.add_round_box(Vector3(0.0, 0.27, 0.0), Vector3(0.22, 0.1, 0.22), hat_c, 0.5, segments, rings)


## Arm (relativ zur Schulter, hängt nach unten): Ärmel und Hand.
func _add_arm(shapes: StreetShapes, side: float, sleeve: Color, skin: Color, segments: int = 12) -> void:
	shapes.add_round_box(Vector3(side * 0.012, -0.27, 0.0), Vector3(0.1, 0.58, 0.11), StreetShapes.solid(sleeve), 0.6, segments, 6)
	shapes.add_ellipsoid(Vector3(side * 0.015, -0.6, 0.01), Vector3(0.075, 0.1, 0.08), StreetShapes.solid(skin), 8, 4)


## Bein (relativ zur Hüfte, hängt nach unten): Hosenbein und Schuh.
func _add_leg(shapes: StreetShapes, trousers: Color, shoes: Color, segments: int = 12) -> void:
	shapes.add_round_box(Vector3(0.0, -0.41, 0.0), Vector3(0.14, 0.84, 0.15), StreetShapes.solid(trousers), 0.6, segments, 6)
	shapes.add_round_box(Vector3(0.0, -HIP + 0.04, 0.045), Vector3(0.11, 0.08, 0.25), StreetShapes.solid(shoes), 0.5, 10, 5)
