class_name DeliveryVanPlaceholder
extends Node3D
## Platzhalter des Lieferwagens (seit Etappe 5a): klein, rundlich und freundlich – runde
## Karosserie, große runde Scheinwerfer, ein kleines Lächeln vorn, ein Paket auf dem Dach und
## eine Schiebetür auf der linken Seite (zum Gehweg hin; Linksverkehr wie in England).
## Karosserie in einem Mesh (Farbe GameConfig.delivery_van_color), die Tür ist ein eigenes Teil
## (Knoten "Door"), damit sie beim Ausladen zur Seite gleiten kann (open_door).
## Vorderseite nach +Z, Räder auf y = 0. Eigenes Modell: in scenes/street_life/delivery_van.tscn
## den Knoten "Model" ersetzen; Vorlage in echter Größe:
## assets/models/templates/street_life/delivery_van.glb (docs/ASSET_GUIDE.md).

const LENGTH := 3.6
const WIDTH := 1.76
## Mitte der Schiebetür (lokal) – dort kommen die Kartons heraus (siehe DeliveryVan.door_offset).
const DOOR_CENTER := Vector3(WIDTH / 2.0 + 0.012, 1.0, -0.1)
const DOOR_SIZE := Vector3(0.06, 1.15, 1.0)

var _mesh: MeshInstance3D
var _door: MeshInstance3D
var _color := Color(0.56, 0.74, 0.7)
var _door_tween: Tween


func _ready() -> void:
	if _mesh == null:
		build(RandomNumberGenerator.new(), _color)


func build(_rng: RandomNumberGenerator, color: Color) -> void:
	_color = color
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		add_child(_mesh)
		_door = MeshInstance3D.new()
		_door.name = "Door"
		add_child(_door)
	var shapes := StreetShapes.new()
	var glass := StreetShapes.glossy(Color(0.2, 0.25, 0.3))
	var trim := StreetShapes.glossy(Color(0.88, 0.87, 0.84))
	var cream := StreetShapes.solid(Color(0.95, 0.91, 0.8))
	var tyre := StreetShapes.solid(Color(0.1, 0.1, 0.1))
	var dark := StreetShapes.solid(Color(0.16, 0.14, 0.13))
	# Runde Karosserie mit hellem Streifen rundherum
	shapes.add_round_box(Vector3(0.0, 1.07, 0.0), Vector3(WIDTH, 1.62, LENGTH), StreetShapes.TINT, 0.42, 22, 12)
	shapes.add_round_box(Vector3(0.0, 0.66, 0.0), Vector3(WIDTH + 0.02, 0.16, LENGTH + 0.02), cream, 0.5, 22, 6)
	# Frontscheibe und Seitenfenster vorn (stehen ein wenig vor der runden Karosserie)
	shapes.add_round_box(Vector3(0.0, 1.43, LENGTH / 2.0 - 0.3), Vector3(WIDTH - 0.3, 0.56, 0.62), glass, 0.3, 16, 8)
	shapes.add_round_box(Vector3(0.0, 1.43, 1.0), Vector3(WIDTH + 0.03, 0.52, 0.8), glass, 0.3, 16, 8)
	# Dunkle Öffnung hinter der Schiebetür (sieht man, wenn die Tür offen ist)
	shapes.add_round_box(DOOR_CENTER + Vector3(0.006, 0.0, 0.0), Vector3(0.02, DOOR_SIZE.y - 0.06, DOOR_SIZE.z - 0.06),
		StreetShapes.solid(Color(0.14, 0.12, 0.11)), 0.2, 8, 4)
	# Große runde Scheinwerfer mit hellem Rand
	for x in [-0.55, 0.55]:
		shapes.add_ellipsoid(Vector3(x, 0.98, LENGTH / 2.0 - 0.1), Vector3(0.38, 0.38, 0.16), trim, 14, 7)
		shapes.add_ellipsoid(Vector3(x, 0.98, LENGTH / 2.0 - 0.06), Vector3(0.3, 0.3, 0.14), StreetShapes.glowing(Color(1.0, 0.96, 0.82)), 14, 7)
		shapes.add_round_box(Vector3(x * 1.3, 0.95, -LENGTH / 2.0 + 0.04), Vector3(0.2, 0.2, 0.08), StreetShapes.glowing(Color(0.88, 0.2, 0.15)), 0.6, 8, 4)
	# Ein kleines Lächeln (Kühlergrill)
	for i in 9:
		var t := (i - 4) / 4.0
		shapes.add_ellipsoid(Vector3(t * 0.3, 0.66 - (1.0 - t * t) * 0.08, LENGTH / 2.0 + 0.01), Vector3(0.07, 0.05, 0.05), dark, 6, 3)
	# Stoßstangen und Räder
	for z in [LENGTH / 2.0 - 0.02, -LENGTH / 2.0 + 0.02]:
		shapes.add_round_box(Vector3(0.0, 0.38, z), Vector3(WIDTH - 0.06, 0.18, 0.16), trim, 0.6, 14, 4)
	for x in [-WIDTH / 2.0 + 0.14, WIDTH / 2.0 - 0.14]:
		for z in [LENGTH / 2.0 - 0.78, -LENGTH / 2.0 + 0.72]:
			var out := signf(x)
			shapes.add_cylinder(Vector3(x - out * 0.09, 0.34, z), Vector3(x + out * 0.1, 0.34, z), 0.34, tyre, 16)
			shapes.add_cylinder(Vector3(x + out * 0.1, 0.34, z), Vector3(x + out * 0.106, 0.34, z), 0.17, cream, 12)
	# Ein Paket auf dem Dach (Zeichen des Lieferdienstes)
	var parcel := StreetShapes.solid(Color(0.74, 0.57, 0.37))
	shapes.add_round_box(Vector3(0.0, 2.08, -0.5), Vector3(0.8, 0.48, 0.66), parcel, 0.18, 12, 6)
	shapes.add_round_box(Vector3(0.0, 2.08, -0.5), Vector3(0.82, 0.5, 0.12), StreetShapes.solid(Color(0.86, 0.78, 0.6)), 0.2, 10, 4)
	_mesh.mesh = shapes.commit()
	_mesh.set_instance_shader_parameter("tint", color)
	# Schiebetür (eigenes Teil) mit Griff und kleinem Fenster
	var door := StreetShapes.new()
	door.add_round_box(Vector3.ZERO, DOOR_SIZE, StreetShapes.tinted(1.06), 0.35, 10, 8)
	door.add_round_box(Vector3(0.035, 0.3, 0.05), Vector3(0.02, 0.36, 0.7), glass, 0.5, 10, 5)
	door.add_round_box(Vector3(0.04, -0.05, 0.42), Vector3(0.03, 0.05, 0.16), trim, 0.6, 6, 3)
	_door.mesh = door.commit()
	_door.set_instance_shader_parameter("tint", color)
	_door.position = DOOR_CENTER
	_door.visible = true


## Schiebetür auf- oder zuschieben (Sekunden).
func open_door(open: bool, duration: float) -> void:
	if _door == null:
		return
	if _door_tween:
		_door_tween.kill()
	var target := DOOR_CENTER + (Vector3(0.07, 0.0, -0.78) if open else Vector3.ZERO)
	_door_tween = create_tween()
	if open:
		_door_tween.tween_property(_door, "position", DOOR_CENTER + Vector3(0.07, 0.0, 0.0), duration * 0.3)
	_door_tween.tween_property(_door, "position", target, duration * (0.7 if open else 1.0)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_shadows(enabled: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part in [_mesh, _door]:
		if part:
			part.cast_shadow = mode
