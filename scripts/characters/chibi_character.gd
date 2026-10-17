@tool
class_name ChibiCharacter
extends Node3D
## Chibi-Figur (seit Etappe 5c): einer der sechs Grundkörper (Frau/Mann, klein/mittel/groß) aus
## assets/models/characters/chibi/, gebaut von tools/blender/build_chibi.py.
##
## Körperform: body_shape von -1 (dünn) über 0 (mittel) bis 1 (dick) – Formregler im Modell.
## Gesicht: gezeichnet (Shader chibi_face.gdshader). Ausdruck, Blickrichtung, Blinzeln und
## Sprechen sind Eigenschaften dieses Knotens und lassen sich mit einem AnimationPlayer
## animieren (z. B. Spur "expression" oder "look"). Mit eyes_override/mouth_override kann eine
## Animation einzelne Teile des Gesichts unabhängig vom Ausdruck setzen (-1 = vom Ausdruck).

enum Figure { FEMALE_SMALL, FEMALE_MEDIUM, FEMALE_TALL, MALE_SMALL, MALE_MEDIUM, MALE_TALL }
const FIGURE_FILES: Array[String] = [
	"res://assets/models/characters/chibi/female_small.glb",
	"res://assets/models/characters/chibi/female_medium.glb",
	"res://assets/models/characters/chibi/female_tall.glb",
	"res://assets/models/characters/chibi/male_small.glb",
	"res://assets/models/characters/chibi/male_medium.glb",
	"res://assets/models/characters/chibi/male_tall.glb",
]

# Felder der Atlanten – Reihenfolge wie in tools/blender/chibi_face.py
const EYE_FRAMES: Array[String] = ["open", "half", "closed", "happy", "wide", "sad", "angry", "soft"]
const IRIS_FRAMES: Array[String] = ["normal", "heart", "sparkle", "spiral"]
const BROW_FRAMES: Array[String] = ["neutral", "raised", "worried", "angry", "sad", "flat", "focused", "relaxed"]
const MOUTH_FRAMES: Array[String] = ["smile", "smile_wide", "open_smile", "laugh", "o", "O", "flat", "frown",
	"cat", "wavy", "sad_open", "smirk", "talk_a", "talk_e", "talk_o", "pout"]

enum Mood { NEUTRAL, HAPPY, LAUGH, SURPRISED, SAD, ANGRY, SLEEPY, LOVE, EXCITED, WORRIED, DIZZY }
## Ausdruck = [Augen, Iris, Augenbrauen, Mund, Wangenröte, Irisgröße]
const EXPRESSIONS := {
	Mood.NEUTRAL: ["open", "normal", "neutral", "smile", 0.4, 1.0],
	Mood.HAPPY: ["soft", "normal", "relaxed", "open_smile", 0.55, 1.0],
	Mood.LAUGH: ["happy", "normal", "raised", "laugh", 0.7, 1.0],
	Mood.SURPRISED: ["wide", "normal", "raised", "O", 0.2, 0.78],
	Mood.SAD: ["sad", "normal", "worried", "frown", 0.1, 1.0],
	Mood.ANGRY: ["angry", "normal", "angry", "flat", 0.35, 0.95],
	Mood.SLEEPY: ["half", "normal", "relaxed", "o", 0.2, 1.0],
	Mood.LOVE: ["open", "heart", "raised", "cat", 0.9, 1.05],
	Mood.EXCITED: ["open", "sparkle", "raised", "open_smile", 0.6, 1.05],
	Mood.WORRIED: ["open", "normal", "worried", "wavy", 0.3, 0.9],
	Mood.DIZZY: ["open", "spiral", "worried", "wavy", 0.2, 1.0],
}
## Bei diesen Augen wird geblinzelt (bei geschlossenen/lachenden nicht).
const BLINKING_EYES: Array[String] = ["open", "wide", "sad", "angry", "soft"]
const TALK_MOUTHS: Array[String] = ["talk_a", "talk_e", "talk_o", "smile", "talk_a", "flat"]

const SKIN_SHADER := preload("res://assets/shaders/chibi_skin.gdshader")
const FACE_SHADER := preload("res://assets/shaders/chibi_face.gdshader")
const FACE_DIR := "res://assets/textures/characters/chibi_face/"

@export var figure: Figure = Figure.FEMALE_MEDIUM:
	set(value):
		figure = value
		_rebuild()
## -1 = dünn, 0 = mittel, 1 = dick (Zwischenwerte gehen auch).
@export_range(-1.0, 1.0, 0.01) var body_shape: float = 0.0:
	set(value):
		body_shape = value
		_apply_shape()
@export var skin_color: Color = Color(0.95, 0.80, 0.68):
	set(value):
		skin_color = value
		_apply_colors()
@export var cloth_color: Color = Color(0.80, 0.70, 0.60):
	set(value):
		cloth_color = value
		_apply_colors()
@export var iris_color: Color = Color(0.42, 0.28, 0.20):
	set(value):
		iris_color = value
		_apply_colors()
## Farbe der Augenbrauen (später passend zu den Haaren).
@export var brow_color: Color = Color(0.30, 0.22, 0.18):
	set(value):
		brow_color = value
		_apply_colors()

@export_group("Gesicht")
@export var expression: Mood = Mood.NEUTRAL:
	set(value):
		expression = value
		_apply_face()
## Blickrichtung der Augen (-1..1 je Achse; x = zur linken Gesichtsseite der Figur).
@export var look: Vector2 = Vector2.ZERO:
	set(value):
		look = value
		_apply_face()
## Augen unabhängig vom Ausdruck (-1 = vom Ausdruck, sonst Nummer in EYE_FRAMES).
@export_range(-1, 7) var eyes_override: int = -1:
	set(value):
		eyes_override = value
		_apply_face()
## Mund unabhängig vom Ausdruck (-1 = vom Ausdruck, sonst Nummer in MOUTH_FRAMES).
@export_range(-1, 15) var mouth_override: int = -1:
	set(value):
		mouth_override = value
		_apply_face()
## Ohne Animation stehen die Figuren in A-Pose (Arme 50° nach unten, so gebaut für Mixamo).
## So viele Grad lässt die Figur die Arme zusätzlich locker hängen (0 = Ruhehaltung).
@export_range(0.0, 40.0) var relaxed_arms: float = 25.0:
	set(value):
		relaxed_arms = value
		_apply_pose()
@export var auto_blink: bool = true
@export var talking: bool = false

var _model: Node3D
var _body: MeshInstance3D
var _cloth: Array[MeshInstance3D] = []
var _blink_wait := 2.0
var _blink_t := -1.0
var _talk_t := 0.0
var _talk_mouth := ""

static var _materials := {}


func _ready() -> void:
	_rebuild()


func is_female() -> bool:
	return figure <= Figure.FEMALE_TALL


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _model:
		_model.queue_free()
		_model = null
	_body = null
	_cloth.clear()
	var scene := load(FIGURE_FILES[figure]) as PackedScene
	if scene == null:
		return
	_model = scene.instantiate()
	_model.name = "Model"
	add_child(_model)
	for mesh_instance in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		var is_body := false
		for i in mi.mesh.get_surface_count():
			var mat_name := mi.mesh.surface_get_material(i).resource_name if mi.mesh.surface_get_material(i) else ""
			if mat_name.begins_with("face"):
				mi.set_surface_override_material(i, _material("face"))
				is_body = true
			elif mat_name.begins_with("skin"):
				mi.set_surface_override_material(i, _material("skin"))
				is_body = true
			else:
				mi.set_surface_override_material(i, _material("cloth"))
		if is_body:
			_body = mi
		else:
			_cloth.append(mi)
	_apply_shape()
	_apply_colors()
	_apply_face()
	_apply_pose()


## Arme locker hängen lassen (nur ohne Animation sinnvoll – eine Animation überschreibt das).
func _apply_pose() -> void:
	if _model == null:
		return
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	for side in [["LeftUpperArm", -1.0], ["RightUpperArm", 1.0]]:
		var bone := skeleton.find_bone(side[0])
		if bone < 0:
			continue
		var rest_global := skeleton.get_bone_global_rest(bone).basis
		var turn := Basis(Vector3.BACK, deg_to_rad(relaxed_arms) * side[1])
		var local := Quaternion(rest_global.inverse() * turn * rest_global)
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion() * local)


## Gemeinsame Materialien (einmal für alle Figuren; Farben kommen als Instanz-Werte).
static func _material(kind: String) -> ShaderMaterial:
	if _materials.has(kind):
		return _materials[kind]
	var mat := ShaderMaterial.new()
	if kind == "face":
		mat.shader = FACE_SHADER
		mat.set_shader_parameter("eye_lines", load(FACE_DIR + "face_eyes.png"))
		mat.set_shader_parameter("eye_masks", load(FACE_DIR + "face_eye_masks.png"))
		mat.set_shader_parameter("iris_tex", load(FACE_DIR + "face_iris.png"))
		mat.set_shader_parameter("brow_tex", load(FACE_DIR + "face_brows.png"))
		mat.set_shader_parameter("mouth_tex", load(FACE_DIR + "face_mouths.png"))
	else:
		mat.shader = SKIN_SHADER
		if kind == "cloth":
			mat.set_shader_parameter("roughness", 0.85)
			mat.set_shader_parameter("ao_strength", 0.7)
	_materials[kind] = mat
	return mat


func _apply_shape() -> void:
	for mi in _all_meshes():
		_set_blend(mi, "thin", maxf(-body_shape, 0.0))
		_set_blend(mi, "fat", maxf(body_shape, 0.0))


func _set_blend(mi: MeshInstance3D, shape_name: String, value: float) -> void:
	var idx := mi.find_blend_shape_by_name(shape_name)
	if idx >= 0:
		mi.set_blend_shape_value(idx, value)


func _apply_colors() -> void:
	if _body:
		_body.set_instance_shader_parameter("base_color", skin_color)
		_body.set_instance_shader_parameter("iris_color", iris_color)
		_body.set_instance_shader_parameter("brow_color", brow_color)
	for mi in _cloth:
		mi.set_instance_shader_parameter("base_color", cloth_color)


func _apply_face() -> void:
	if _body == null:
		return
	var e: Array = EXPRESSIONS[expression]
	var eyes: String = e[0]
	if eyes_override >= 0:
		eyes = EYE_FRAMES[eyes_override]
	if _blink_t >= 0.0 and eyes in BLINKING_EYES:
		# Blinzeln: halb – zu – halb
		var t := _blink_t / GameConfig.chibi_blink_time
		eyes = "closed" if t > 0.3 and t < 0.7 else "half"
	var mouth: String = e[3]
	if talking and _talk_mouth != "":
		mouth = _talk_mouth
	if mouth_override >= 0:
		mouth = MOUTH_FRAMES[mouth_override]
	_body.set_instance_shader_parameter("eye_frame", EYE_FRAMES.find(eyes))
	_body.set_instance_shader_parameter("eye_set", 0 if is_female() else 1)
	_body.set_instance_shader_parameter("iris_frame", IRIS_FRAMES.find(e[1]))
	_body.set_instance_shader_parameter("brow_frame", BROW_FRAMES.find(e[2]))
	_body.set_instance_shader_parameter("mouth_frame", MOUTH_FRAMES.find(mouth))
	_body.set_instance_shader_parameter("blush", e[4])
	_body.set_instance_shader_parameter("iris_scale", e[5])
	_body.set_instance_shader_parameter("look", look)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var changed := false
	if auto_blink:
		if _blink_t >= 0.0:
			_blink_t += delta
			if _blink_t > GameConfig.chibi_blink_time:
				_blink_t = -1.0
				_blink_wait = randf_range(GameConfig.chibi_blink_interval.x, GameConfig.chibi_blink_interval.y)
			changed = true
		else:
			_blink_wait -= delta
			if _blink_wait <= 0.0:
				_blink_t = 0.0
				changed = true
	if talking:
		_talk_t -= delta
		if _talk_t <= 0.0:
			_talk_t = GameConfig.chibi_talk_frame_time * randf_range(0.7, 1.4)
			_talk_mouth = TALK_MOUTHS[randi() % TALK_MOUTHS.size()]
			changed = true
	elif _talk_mouth != "":
		_talk_mouth = ""
		changed = true
	if changed:
		_apply_face()


func _all_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if _body:
		out.append(_body)
	out.append_array(_cloth)
	return out
