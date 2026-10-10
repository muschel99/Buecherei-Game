class_name CarPlaceholder
extends Node3D
## Platzhalter eines kleinen, rundlichen Autos (seit Etappe 5a): Karosserie in der Farbe des
## Autos, Fenster, runde Scheinwerfer, Rücklichter und Räder – alles ein einziges Mesh (ein
## Zeichenaufruf). Vorderseite nach +Z, Räder stehen auf y = 0. Eigenes Modell: in
## scenes/street_life/car.tscn den Knoten "Model" ersetzen (docs/ASSET_GUIDE.md).

const LENGTH := 3.5
const WIDTH := 1.6

var _mesh: MeshInstance3D


func _ready() -> void:
	if _mesh == null:
		build(RandomNumberGenerator.new(), Color(0.55, 0.68, 0.62))


func build(_rng: RandomNumberGenerator, color: Color) -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		add_child(_mesh)
	var shapes := StreetShapes.new()
	var glass := StreetShapes.glossy(Color(0.22, 0.27, 0.32))
	var trim := StreetShapes.glossy(Color(0.82, 0.82, 0.8))
	var tyre := StreetShapes.solid(Color(0.1, 0.1, 0.1))
	# Karosserie unten und Dach mit Fenstern
	shapes.add_round_box(Vector3(0.0, 0.62, 0.0), Vector3(WIDTH, 0.72, LENGTH), StreetShapes.TINT, 0.38, 18, 10)
	shapes.add_round_box(Vector3(0.0, 1.08, -0.25), Vector3(WIDTH - 0.16, 0.62, 2.0), glass, 0.45, 16, 8)
	shapes.add_round_box(Vector3(0.0, 1.38, -0.28), Vector3(WIDTH - 0.2, 0.1, 1.86), StreetShapes.TINT, 0.6, 14, 6)
	# Scheinwerfer, Kühlergrill, Rücklichter, Stoßstangen
	for x in [-0.5, 0.5]:
		shapes.add_ellipsoid(Vector3(x, 0.72, LENGTH / 2.0 - 0.12), Vector3(0.26, 0.26, 0.14), StreetShapes.glowing(Color(1.0, 0.95, 0.8)))
		shapes.add_round_box(Vector3(x * 1.25, 0.74, -LENGTH / 2.0 + 0.06), Vector3(0.22, 0.14, 0.08), StreetShapes.glowing(Color(0.85, 0.16, 0.12)), 0.5, 8, 4)
	shapes.add_round_box(Vector3(0.0, 0.62, LENGTH / 2.0 - 0.03), Vector3(0.6, 0.18, 0.08), trim, 0.5, 10, 4)
	for z in [LENGTH / 2.0 - 0.02, -LENGTH / 2.0 + 0.02]:
		shapes.add_round_box(Vector3(0.0, 0.36, z), Vector3(WIDTH - 0.1, 0.14, 0.12), trim, 0.6, 12, 4)
	# Räder mit hellen Radkappen
	for x in [-WIDTH / 2.0 + 0.12, WIDTH / 2.0 - 0.12]:
		for z in [LENGTH / 2.0 - 0.72, -LENGTH / 2.0 + 0.68]:
			var out := signf(x)
			shapes.add_cylinder(Vector3(x - out * 0.08, 0.31, z), Vector3(x + out * 0.1, 0.31, z), 0.31, tyre, 14)
			shapes.add_cylinder(Vector3(x + out * 0.1, 0.31, z), Vector3(x + out * 0.105, 0.31, z), 0.15, trim, 10)
	_mesh.mesh = shapes.commit()
	_mesh.set_instance_shader_parameter("tint", color)


func set_shadows(enabled: bool) -> void:
	if _mesh:
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
