class_name ChatBubble
extends Sprite3D
## Kleine Sprechblase mit einem Symbol über dem Kopf einer plaudernden Figur (seit Etappe 6c): ploppt
## auf, schwebt ein wenig nach oben und blendet aus. Bilder: assets/textures/ui/bubbles/*.png (jede Datei
## dort ist ein mögliches Symbol – eigene einfach dazulegen oder austauschen).

const FOLDER := "res://assets/textures/ui/bubbles/"

static var _textures: Array[Texture2D] = []

var _tween: Tween


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Alle Symbole aus dem Ordner (einmal geladen).
static func textures() -> Array[Texture2D]:
	if _textures.is_empty():
		for file in DirAccess.get_files_at(FOLDER):
			var name := file.trim_suffix(".import").trim_suffix(".remap")
			if name.get_extension().to_lower() in ["png", "webp", "jpg"] and not _textures.any(func(t: Texture2D) -> bool: return t.resource_path.ends_with(name)):
				var texture := load(FOLDER + name) as Texture2D
				if texture:
					_textures.append(texture)
	return _textures


## Zeigt ein (zufälliges) Symbol für eine Weile über dem Kopf (height = Höhe des Kopfs über den Füßen).
func pop(height: float) -> void:
	var all := textures()
	if all.is_empty():
		return
	texture = all[randi() % all.size()]
	pixel_size = GameConfig.chat_bubble_size / maxf(float(texture.get_width()), 1.0)
	position = Vector3(0.12, height + GameConfig.chat_bubble_height, 0.0)
	modulate = Color(1, 1, 1, 0)
	scale = Vector3.ONE * 0.6
	visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", position.y + 0.08, GameConfig.chat_bubble_time)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.chain().tween_callback(func() -> void: visible = false)
