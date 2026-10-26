@tool
class_name ChibiCharacter
extends Node3D
## Chibi-Figur (seit Etappe 5c): einer der sechs Grundkörper (Frau/Mann, klein/mittel/groß) aus
## assets/models/characters/chibi/, gebaut von tools/blender/build_chibi.py.
##
## Körperform: body_shape von -1 (dünn) über 0 (mittel) bis 1 (dick) – Formregler im Modell.
## Gesicht: gezeichnet (Shader chibi_face.gdshader). Ausdruck, Blickrichtung, Blinzeln und
## Sprechen sind Eigenschaften dieses Knotens und lassen sich mit einem AnimationPlayer
## animieren (z. B. Spur "mood" oder "look"). Mit eyes_override/mouth_override kann eine
## Animation einzelne Teile des Gesichts unabhängig vom Ausdruck setzen (-1 = vom Ausdruck).
## Kleidung und Frisur: Jede Figur enthält alle Stücke (Knoten "Cloth_…", "Hair_…" im Modell);
## top, bottom, shoes und hair blenden das gewählte ein, die Farben sind Instanz-Werte.

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
const EYE_FRAMES: Array[String] = ["open", "half", "closed", "happy", "wide", "sad", "angry", "soft", "annoyed",
	"squeeze", "cry", "teary"]
const IRIS_FRAMES: Array[String] = ["normal", "heart", "sparkle", "spiral", "small", "star"]
const BROW_FRAMES: Array[String] = ["neutral", "raised", "worried", "angry", "sad", "flat", "focused", "relaxed"]
const MOUTH_FRAMES: Array[String] = ["smile", "smile_wide", "open_smile", "laugh", "o", "O", "flat", "frown",
	"cat", "wavy", "sad_open", "smirk", "talk_a", "talk_e", "talk_o", "pout", "grin", "bleh", "shout", "triangle"]

## Augenformen: Frauen süß / elegant / lebhaft, Männer sanft / cool / fröhlich.
enum EyeShape { SHAPE_1, SHAPE_2, SHAPE_3 }

## Kleidung und Frisuren (Namen der Knoten im Modell: "Cloth_" bzw. "Hair_" + Name).
enum Top { NONE, TSHIRT, SWEATER }
enum Bottom { NONE, TROUSERS, SKIRT }
enum Hair { NONE, BOB, BUN, PIGTAILS, SHORT }
const TOP_NAMES: Array[String] = ["", "tshirt", "sweater"]
const BOTTOM_NAMES: Array[String] = ["", "trousers", "skirt"]
const HAIR_NAMES: Array[String] = ["", "bob", "bun", "pigtails", "short"]

enum Mood { NEUTRAL, HAPPY, LAUGH, CONTENT, GRIN, EXCITED, LOVE, STARSTRUCK, WINK, CHEEKY, SURPRISED,
	SHOCKED, SAD, TEARY, CRYING, ANGRY, FURIOUS, ANNOYED, SMUG, WORRIED, EMBARRASSED, SHY, THINKING,
	SLEEPY, ASLEEP, DIZZY }
## Ausdruck = [Auge links, Auge rechts, Iris, Augenbrauen, Mund, Wangenröte, Irisgröße, Rotstriche]
## (wie EXPRESSIONS in chibi_face.py)
const MOODS := {
	Mood.NEUTRAL: ["open", "open", "normal", "neutral", "smile", 0.55, 1.0, 0.0],
	Mood.HAPPY: ["soft", "soft", "normal", "relaxed", "open_smile", 0.5, 1.0, 0.0],
	Mood.LAUGH: ["happy", "happy", "normal", "raised", "laugh", 0.7, 1.0, 0.0],
	Mood.CONTENT: ["happy", "happy", "normal", "relaxed", "smile_wide", 0.6, 1.0, 0.0],
	Mood.GRIN: ["soft", "soft", "normal", "raised", "grin", 0.5, 1.0, 0.0],
	Mood.EXCITED: ["open", "open", "sparkle", "raised", "open_smile", 0.6, 1.05, 0.0],
	Mood.LOVE: ["open", "open", "heart", "raised", "cat", 0.9, 1.05, 0.0],
	Mood.STARSTRUCK: ["wide", "wide", "star", "raised", "O", 0.6, 1.0, 0.0],
	Mood.WINK: ["open", "happy", "normal", "raised", "grin", 0.5, 1.0, 0.0],
	Mood.CHEEKY: ["happy", "open", "normal", "raised", "bleh", 0.5, 1.0, 0.0],
	Mood.SURPRISED: ["wide", "wide", "normal", "raised", "O", 0.2, 0.8, 0.0],
	Mood.SHOCKED: ["wide", "wide", "small", "raised", "triangle", 0.1, 1.0, 0.0],
	Mood.SAD: ["sad", "sad", "normal", "worried", "frown", 0.1, 1.0, 0.0],
	Mood.TEARY: ["teary", "teary", "sparkle", "worried", "wavy", 0.4, 1.0, 0.0],
	Mood.CRYING: ["cry", "cry", "normal", "worried", "sad_open", 0.4, 1.0, 0.0],
	Mood.ANGRY: ["angry", "angry", "normal", "angry", "flat", 0.3, 0.95, 0.0],
	Mood.FURIOUS: ["squeeze", "squeeze", "normal", "angry", "shout", 0.6, 1.0, 0.0],
	Mood.ANNOYED: ["annoyed", "annoyed", "normal", "flat", "flat", 0.1, 1.0, 0.0],
	Mood.SMUG: ["annoyed", "annoyed", "normal", "focused", "smirk", 0.2, 1.0, 0.0],
	Mood.WORRIED: ["open", "open", "normal", "worried", "wavy", 0.3, 0.9, 0.0],
	Mood.EMBARRASSED: ["soft", "soft", "normal", "worried", "wavy", 0.9, 1.0, 1.0],
	Mood.SHY: ["open", "open", "normal", "sad", "pout", 0.8, 1.0, 1.0],
	Mood.THINKING: ["open", "half", "normal", "focused", "pout", 0.2, 1.0, 0.0],
	Mood.SLEEPY: ["half", "half", "normal", "relaxed", "o", 0.2, 1.0, 0.0],
	Mood.ASLEEP: ["closed", "closed", "normal", "relaxed", "o", 0.3, 1.0, 0.0],
	Mood.DIZZY: ["open", "open", "spiral", "worried", "wavy", 0.2, 1.0, 0.0],
}
## Bei diesen Augen wird geblinzelt (bei geschlossenen/lachenden nicht).
const BLINKING_EYES: Array[String] = ["open", "wide", "sad", "angry", "soft", "annoyed", "teary", "half"]
const TALK_MOUTHS: Array[String] = ["talk_a", "talk_e", "talk_o", "smile", "talk_a", "flat"]
## Beim locker Hängenlassen übernimmt das Schlüsselbein so viele Grad (wenig – sonst hängen die
## Schultern), der Ellbogen ist leicht gebeugt.
const SHOULDER_SHARE := 6.0
const ELBOW_RELAX := 12.0
## Dicke Figuren lassen die Arme so viel Grad weniger tief hängen (sonst liegen sie am Bauch).
const FAT_RELAX_LESS := 8.0

const SKIN_SHADER := preload("res://assets/shaders/chibi_skin.gdshader")
const FACE_SHADER := preload("res://assets/shaders/chibi_face.gdshader")
const CLOTH_SHADER := preload("res://assets/shaders/chibi_cloth.gdshader")
const HAIR_SHADER := preload("res://assets/shaders/chibi_hair.gdshader")
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
		_apply_pose()
@export var skin_color: Color = Color(0.95, 0.80, 0.68):
	set(value):
		skin_color = value
		_apply_colors()
## Farbe der aufgemalten Unterwäsche.
@export var cloth_color: Color = Color(0.90, 0.89, 0.87):
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

@export_group("Kleidung")
@export var top: Top = Top.NONE:
	set(value):
		top = value
		_apply_outfit()
@export var bottom: Bottom = Bottom.NONE:
	set(value):
		bottom = value
		_apply_outfit()
@export var shoes: bool = false:
	set(value):
		shoes = value
		_apply_outfit()
@export var hair: Hair = Hair.NONE:
	set(value):
		hair = value
		_apply_outfit()
@export var top_color: Color = Color(0.86, 0.80, 0.62):
	set(value):
		top_color = value
		_apply_outfit()
@export var bottom_color: Color = Color(0.30, 0.34, 0.46):
	set(value):
		bottom_color = value
		_apply_outfit()
@export var shoe_color: Color = Color(0.38, 0.25, 0.16):
	set(value):
		shoe_color = value
		_apply_outfit()
@export var hair_color: Color = Color(0.36, 0.23, 0.14):
	set(value):
		hair_color = value
		_apply_outfit()

@export_group("Gesicht")
## Augenform (1–3, je Geschlecht verschieden).
@export var eye_shape: EyeShape = EyeShape.SHAPE_1:
	set(value):
		eye_shape = value
		_apply_face()
@export var mood: Mood = Mood.NEUTRAL:
	set(value):
		mood = value
		_apply_face()
## Blickrichtung der Augen (-1..1 je Achse; x = zur linken Gesichtsseite der Figur).
@export var look: Vector2 = Vector2.ZERO:
	set(value):
		look = value
		_apply_face()
## Augen unabhängig vom Ausdruck (-1 = vom Ausdruck, sonst Nummer in EYE_FRAMES).
@export_range(-1, 11) var eyes_override: int = -1:
	set(value):
		eyes_override = value
		_apply_face()
## Mund unabhängig vom Ausdruck (-1 = vom Ausdruck, sonst Nummer in MOUTH_FRAMES).
@export_range(-1, 19) var mouth_override: int = -1:
	set(value):
		mouth_override = value
		_apply_face()
## Gebaut sind die Figuren in T-Pose (Arme waagerecht, für Mixamo). Ohne Animation lässt die
## Figur die Arme um so viele Grad locker hängen (0 = T-Pose).
@export_range(0.0, 85.0) var relaxed_arms: float = 57.0:
	set(value):
		relaxed_arms = value
		_apply_pose()
@export var auto_blink: bool = true
@export var talking: bool = false

var _model: Node3D
var _body: MeshInstance3D
var _skeleton: Skeleton3D
## Kleidungsstücke und Frisuren der Figur: Name ("Cloth_tshirt", "Hair_bob" …) → MeshInstance3D
var _pieces := {}
var _shape_modifier: ChibiShapeModifier
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
	_pieces.clear()
	var scene := load(FIGURE_FILES[figure]) as PackedScene
	if scene == null:
		return
	_model = scene.instantiate()
	_model.name = "Model"
	add_child(_model)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_add_shape_modifier()
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
			elif mat_name.begins_with("cloth"):
				mi.set_surface_override_material(i, _material("cloth"))
			elif mat_name.begins_with("hair"):
				mi.set_surface_override_material(i, _material("hair"))
		if is_body:
			_body = mi
		elif mi.name.begins_with("Cloth_") or mi.name.begins_with("Hair_"):
			_pieces[String(mi.name)] = mi
	_apply_shape()
	_apply_colors()
	_apply_face()
	_apply_outfit()
	_apply_pose()


## Gewählte Kleidungsstücke und Frisur einblenden, die übrigen ausblenden; Farben setzen.
func _apply_outfit() -> void:
	if _model == null:
		return
	var wanted := {
		"Cloth_" + TOP_NAMES[top]: top_color,
		"Cloth_" + BOTTOM_NAMES[bottom]: bottom_color,
		"Hair_" + HAIR_NAMES[hair]: hair_color,
	}
	if shoes:
		wanted["Cloth_shoes"] = shoe_color
	for piece_name in _pieces:
		var mi: MeshInstance3D = _pieces[piece_name]
		mi.visible = wanted.has(piece_name)
		if mi.visible:
			mi.set_instance_shader_parameter("base_color", wanted[piece_name])
			if piece_name == "Cloth_shoes":
				mi.set_instance_shader_parameter("sole_color", GameConfig.chibi_sole_color)
				mi.set_instance_shader_parameter("sole_height", GameConfig.chibi_sole_height)
	if _body:
		_body.set_instance_shader_parameter("lower_cloth_color", _lower_cloth_color())


## Knochen drehen (ab der Ruhelage): turns = [[Knochen, Achse, Grad], …] – Achsen wie die Figur in
## T-Pose (x = linke Seite der Figur, y oben, z vorn). Mehrere Einträge für denselben Knochen
## werden nacheinander angewendet. Knochen, die nicht vorkommen, bleiben, wie sie sind.
func set_bone_turns(turns: Array) -> void:
	if _skeleton == null:
		return
	var per_bone := {}
	for t in turns:
		var bone := _skeleton.find_bone(t[0])
		if bone < 0:
			continue
		var turn := Basis(t[1], deg_to_rad(t[2]))
		per_bone[bone] = turn * per_bone.get(bone, Basis.IDENTITY)
	for bone in per_bone:
		var rest_global := _skeleton.get_bone_global_rest(bone).basis
		var local := Quaternion(rest_global.inverse() * per_bone[bone] * rest_global)
		_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion() * local)


## Drehungen der locker hängenden Arme (für set_bone_turns; Animationen bauen darauf auf).
func relaxed_arm_turns() -> Array:
	var angle := maxf(relaxed_arms - FAT_RELAX_LESS * maxf(body_shape, 0.0), 0.0)
	var share := minf(SHOULDER_SHARE, angle)
	var elbow := ELBOW_RELAX * minf(angle / 30.0, 1.0)
	var out := []
	for side in [["Left", -1.0], ["Right", 1.0]]:
		out.append([side[0] + "Shoulder", Vector3.BACK, share * side[1]])
		out.append([side[0] + "UpperArm", Vector3.BACK, (angle - share) * side[1]])
		out.append([side[0] + "LowerArm", Vector3.UP, elbow * side[1]])
	return out


## Dünn/dick: Arme und Beine samt Gelenken verschieben (Werte aus der Figur, gebaut von
## tools/blender/build_chibi.py; Godot liest sie als Metadaten "extras" am Skelett-Knoten).
func _add_shape_modifier() -> void:
	_shape_modifier = null
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var extras: Dictionary = {}
	for node in [skeleton, skeleton.get_parent()]:
		if node and node.has_meta("extras"):
			extras = node.get_meta("extras")
	var offsets: Dictionary = extras.get("chibi_bone_offsets", {})
	_shape_modifier = ChibiShapeModifier.new()
	_shape_modifier.name = "ShapeModifier"
	for shape in ["fat", "thin"]:
		var table := {}
		var source: Dictionary = offsets.get(shape, {})
		for bone in source:
			var v: Array = source[bone]
			table[bone] = Vector3(v[0], v[1], v[2])
		if shape == "fat":
			_shape_modifier.offsets_fat = table
		else:
			_shape_modifier.offsets_thin = table
	skeleton.add_child(_shape_modifier)


## Arme locker hängen lassen (nur ohne Animation sinnvoll – eine Animation überschreibt das):
## das Schlüsselbein dreht ein kleines Stück mit, der Oberarm den Rest; Ellbogen leicht gebeugt.
func _apply_pose() -> void:
	set_bone_turns(relaxed_arm_turns())


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
	elif kind == "cloth":
		mat.shader = CLOTH_SHADER
	elif kind == "hair":
		mat.shader = HAIR_SHADER
	else:
		mat.shader = SKIN_SHADER
	_materials[kind] = mat
	return mat


func _apply_shape() -> void:
	for mi in _all_meshes():
		_set_blend(mi, "thin", maxf(-body_shape, 0.0))
		_set_blend(mi, "fat", maxf(body_shape, 0.0))
	if _shape_modifier:
		_shape_modifier.body_shape = body_shape


func _set_blend(mi: MeshInstance3D, shape_name: String, value: float) -> void:
	var idx := mi.find_blend_shape_by_name(shape_name)
	if idx >= 0:
		mi.set_blend_shape_value(idx, value)


func _apply_colors() -> void:
	if _body:
		_body.set_instance_shader_parameter("base_color", skin_color)
		_body.set_instance_shader_parameter("iris_color", iris_color)
		_body.set_instance_shader_parameter("brow_color", brow_color)
		_body.set_instance_shader_parameter("cloth_color", cloth_color)
		_body.set_instance_shader_parameter("lower_cloth_color", _lower_cloth_color())


## Unterhose: unter Rock und Hose in deren Farbe (etwas dunkler, unter dem Rock wie ein Hosenrock) –
## beim Sitzen sieht man unter dem Rock nur Stoff im Schatten, und wo die Wäsche in der Hüftbeuge
## durch die Hose drückt, fällt sie nicht auf.
func _lower_cloth_color() -> Color:
	return bottom_color.darkened(GameConfig.chibi_skort_darken) if bottom != Bottom.NONE else cloth_color


func _apply_face() -> void:
	if _body == null:
		return
	var e: Array = MOODS[mood]
	var eyes: Array[String] = [e[0], e[1]]
	for i in 2:
		if eyes_override >= 0:
			eyes[i] = EYE_FRAMES[eyes_override]
		if _blink_t >= 0.0 and eyes[i] in BLINKING_EYES:
			# Blinzeln: halb – zu – halb
			var t := _blink_t / GameConfig.chibi_blink_time
			eyes[i] = "closed" if t > 0.3 and t < 0.7 else "half"
	var mouth: String = e[4]
	if talking and _talk_mouth != "":
		mouth = _talk_mouth
	if mouth_override >= 0:
		mouth = MOUTH_FRAMES[mouth_override]
	_body.set_instance_shader_parameter("eye_set", (0 if is_female() else 3) + int(eye_shape))
	_body.set_instance_shader_parameter("eye_frame", EYE_FRAMES.find(eyes[0]))
	_body.set_instance_shader_parameter("eye_frame_r", EYE_FRAMES.find(eyes[1]))
	_body.set_instance_shader_parameter("iris_frame", IRIS_FRAMES.find(e[2]))
	_body.set_instance_shader_parameter("brow_frame", BROW_FRAMES.find(e[3]))
	_body.set_instance_shader_parameter("mouth_frame", MOUTH_FRAMES.find(mouth))
	_body.set_instance_shader_parameter("blush", e[5])
	_body.set_instance_shader_parameter("iris_scale", e[6])
	_body.set_instance_shader_parameter("blush_lines", e[7])
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


## Körper und alle Kleidungsstücke (für die Formregler dünn/dick).
func _all_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if _body:
		out.append(_body)
	for piece_name in _pieces:
		out.append(_pieces[piece_name])
	return out
