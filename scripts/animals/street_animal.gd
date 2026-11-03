class_name StreetAnimal
extends Node3D
## Gemeinsame Grundlage der Tiere (seit Etappe 6g): Modell mit Skelett und Bewegungen (Kind "Model",
## austauschbar – siehe docs/ASSET_GUIDE.md „Eigene Tiere“), Farben je Art bzw. je Katze, Schatten.
##
## Das Modell braucht einen AnimationPlayer mit den Bewegungen (Namen wie in tools/blender/build_animals.py)
## und Materialien mit festen Namen (z. B. „Katze Fell“) – die Farben setzt apply_look über Kopien
## dieser Materialien (je Aussehen nur einmal, gemeinsam genutzt: wenige Zeichenaufrufe).

## Bewegungen, die nicht in Schleife laufen (alle übrigen wiederholen sich)
const ONCE := [&"stretch", &"jump", &"sit_down", &"stand_up", &"pounce", &"jump_up", &"jump_down", &"hop_up",
	&"step_down", &"takeoff", &"land", &"roll"]

## Kopien der Materialien je Aussehen: "aussehen|material" -> Material
static var _materials := {}

var anim: AnimationPlayer
var mesh: MeshInstance3D
var skeleton: Skeleton3D
var current_anim: StringName = &""
var _model: Node3D


func _ready() -> void:
	_model = get_node_or_null("Model") as Node3D
	if _model == null:
		return
	anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	mesh = _model.find_child("*", true, false) as MeshInstance3D
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		mesh = node as MeshInstance3D
		break
	skeleton = _model.find_child("*", true, false) as Skeleton3D
	for node in _model.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
		break
	if anim:
		for anim_name in anim.get_animation_list():
			var a := anim.get_animation(anim_name)
			a.loop_mode = Animation.LOOP_NONE if StringName(anim_name) in ONCE else Animation.LOOP_LINEAR


## Bewegung abspielen (weich überblendet). speed = Tempo; gleiche Bewegung läuft weiter.
func play(anim_name: StringName, blend: float = 0.2, speed: float = 1.0) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	if current_anim == anim_name and anim.is_playing():
		anim.speed_scale = speed
		return
	current_anim = anim_name
	anim.play(anim_name, blend)
	anim.speed_scale = speed


## Länge einer Bewegung in Sekunden (0, wenn es sie nicht gibt).
func anim_length(anim_name: StringName) -> float:
	if anim == null or not anim.has_animation(anim_name):
		return 0.0
	return anim.get_animation(anim_name).length


## Farben setzen: look_id = Name des Aussehens, colors = Material-Name → Farbe, extra = Material-Name →
## { Shader-Wert: Wert } (z. B. Tigerstreifen).
func apply_look(look_id: String, colors: Dictionary, extra: Dictionary = {}) -> void:
	if mesh == null or mesh.mesh == null:
		return
	for i in mesh.mesh.get_surface_count():
		var base := mesh.mesh.surface_get_material(i)
		if base == null or not (colors.has(base.resource_name) or extra.has(base.resource_name)):
			continue
		var key := look_id + "|" + base.resource_name
		if not _materials.has(key):
			var copy := base.duplicate() as Material
			if colors.has(base.resource_name):
				var color: Color = colors[base.resource_name]
				if copy is ShaderMaterial:
					(copy as ShaderMaterial).set_shader_parameter("base_color", color)
				elif copy is StandardMaterial3D:
					(copy as StandardMaterial3D).albedo_color = color
			if copy is ShaderMaterial:
				var values: Dictionary = extra.get(base.resource_name, {})
				for param in values:
					(copy as ShaderMaterial).set_shader_parameter(param, values[param])
			_materials[key] = copy
		mesh.set_surface_override_material(i, _materials[key])


func set_shadows(enabled: bool) -> void:
	for node in find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Draußen bekommt das Tier zusätzlich das Himmelslicht (Render-Ebene GameConfig.OUTDOOR_RENDER_LAYER), drinnen nicht.
func set_outdoor(outdoor: bool) -> void:
	for node in find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).set_layer_mask_value(GameConfig.OUTDOOR_RENDER_LAYER, outdoor)


## Richtung (Welt, waagerecht) → Drehung um y, so dass das Modell (+Z vorn) dorthin schaut.
static func yaw_of(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)
