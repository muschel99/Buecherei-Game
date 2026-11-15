class_name CounterPc
extends Node3D
## PC auf der Theke (seit Etappe 8, ersetzt die Kasse): gemütlicher alter Rechner mit Röhrenbildschirm, Kartenleser und
## Scanner (Modell aus furniture_fixtures.build_counter_pc). Der Bildschirm zeigt ein eigenes Bild (SubViewport mit
## PcScreen): im Ruhezustand die Ausweise mit ihren Stempeln, beim Bedienen Name und Stempelkarte (der neue Stempel ploppt
## auf), dann die gescannten Bücher. Gezeichnet wird nur, wenn sich etwas ändert (und kurz während der Bewegungen).
## Lagen im Raum des PCs (Godot-Achsen, Bildschirm nach +Z) – passend zum Modell.

const SCREEN_CENTER := Vector3(0.0, 0.18, 0.1045)
const SCREEN_SIZE := Vector2(0.25, 0.19)
const READER_SLOT := Vector3(0.24, 0.045, 0.2)
const SCANNER := Vector3(0.44, 0.016, 0.14)
const SCREEN_PIXELS := Vector2i(500, 380)

var screen: PcScreen
var _viewport: SubViewport
var _redraw_left := 0.0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SCREEN_PIXELS
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	screen = PcScreen.new()
	screen.size = Vector2(SCREEN_PIXELS)
	screen.changed.connect(redraw)
	_viewport.add_child(screen)
	var quad := MeshInstance3D.new()
	quad.name = "Screen"
	var mesh := QuadMesh.new()
	mesh.size = SCREEN_SIZE
	quad.mesh = mesh
	# ohne Licht: der Bildschirm leuchtet selbst, seine Farben bleiben genau so, wie gezeichnet
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	material.albedo_color = Color(0.92, 0.92, 0.92)
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = SCREEN_CENTER
	add_child(quad)
	screen.show_idle()


func _process(delta: float) -> void:
	if _redraw_left > 0.0:
		_redraw_left -= delta
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _redraw_left > 0.0 else SubViewport.UPDATE_ONCE


## Bild neu zeichnen (seconds > 0: so lange laufend, z. B. während ein Stempel aufploppt).
func redraw(seconds: float = 0.0) -> void:
	_redraw_left = maxf(_redraw_left, seconds)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _redraw_left > 0.0 else SubViewport.UPDATE_ONCE


func reader_slot_global() -> Vector3:
	return global_transform * READER_SLOT


func scanner_global() -> Vector3:
	return global_transform * SCANNER


## Das Bild auf dem Bildschirm: mintgrünes, weiches Leuchten, Handschrift, Stempelkarte mit runden Stempeln.
class PcScreen extends Control:
	signal changed(seconds: float)
	const BG := Color(0.86, 0.94, 0.87)
	const INK := Color(0.2, 0.34, 0.27)
	const SOFT := Color(0.38, 0.52, 0.44)
	const STAMP := Color(0.86, 0.45, 0.48)
	const TITLE := preload("res://assets/ui/fonts/Caveat-Bold.woff2")
	const HAND := preload("res://assets/ui/fonts/PatrickHand-Regular.woff2")
	var mode := "idle"
	var reader_name := ""
	var stamps := 0
	var bonus := false
	var scanned: Array[String] = []
	var total := 0
	## 0 → 1: der neue Stempel ploppt auf (Tween)
	var pop := 1.0:
		set(value):
			pop = value
			queue_redraw()

	func show_idle() -> void:
		mode = "idle"
		queue_redraw()
		changed.emit(0.0)

	## Ausweis eingelesen: Name und Stempelkarte; new_stamps = Zahl der Stempel jetzt (der letzte ploppt auf).
	func show_card(name_text: String, new_stamps: int, is_bonus: bool) -> void:
		mode = "card"
		reader_name = name_text
		stamps = new_stamps
		bonus = is_bonus
		scanned.clear()
		pop = 0.0
		var tween := create_tween()
		tween.tween_interval(0.25)
		tween.tween_callback(func() -> void: Audio.play("ui/stamp_pop", -6.0, Audio.vary(0.05)))
		tween.tween_property(self, "pop", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		changed.emit(0.9)

	func show_scan(titles: Array[String], book_total: int) -> void:
		mode = "card"
		scanned = titles.duplicate()
		total = book_total
		queue_redraw()
		changed.emit(0.0)

	func show_done() -> void:
		mode = "done"
		queue_redraw()
		changed.emit(0.0)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, BG)
		# leichte Bildröhren-Wölbung: dunklere, weiche Ränder und feine Zeilen
		for i in 10:
			var t := float(i) / 10.0
			draw_rect(r.grow(-t * 18.0), Color(0.1, 0.2, 0.15, 0.025), false, 2.0)
		for y in range(0, int(size.y), 4):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.05), 1.0)
		match mode:
			"idle":
				_text("Bücherei-Ausleihe", Vector2(30, 62), TITLE, 44, INK)
				_text("Ausweise", Vector2(30, 104), HAND, 22, SOFT)
				var list := Lending.readers.values()
				list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.visits) > int(b.visits))
				var y := 136.0
				for info: Dictionary in list.slice(0, 7):
					_text(str(info.name), Vector2(30, y), HAND, 21, INK)
					# Freundschaft als kleine Herzen (Stammgäste, seit Etappe 8), dahinter die Stempelkarte
					var hearts := mini(5, int(ceil(int(info.get("friendship", 0)) / 2.0)))
					for h in hearts:
						SoftShapes.heart(self, Vector2(206 + h * 11, y - 8), 4.5, STAMP)
					for k in GameConfig.stamp_card_size:
						var c := Vector2(272 + k * 20, y - 7)
						draw_circle(c, 7.0, STAMP if k < int(info.stamps) else Color(SOFT, 0.25))
					y += 32.0
				if list.is_empty():
					_text("Noch keine Ausweise – die ersten Gäste kommen bestimmt bald.", Vector2(30, 140), HAND, 20, SOFT)
			"card":
				_text(reader_name, Vector2(30, 60), TITLE, 46, INK)
				var cell := 52.0
				for k in GameConfig.stamp_card_size:
					var c := Vector2(58 + (k % 5) * (cell + 22), 118 + (k / 5) * (cell + 14))
					draw_arc(c, cell / 2.0, 0.0, TAU, 28, Color(SOFT, 0.5), 2.0, true)
					var filled := k < stamps or (bonus and true)
					if not filled:
						continue
					var is_new := (k == stamps - 1 and not bonus) or (bonus and k == GameConfig.stamp_card_size - 1)
					var s := 1.0 if not is_new else lerpf(1.8, 1.0, pop)
					var a := 1.0 if not is_new else pop
					draw_circle(c, cell / 2.0 * 0.8 * s, Color(STAMP, 0.85 * a))
					SoftShapes.heart(self, c + Vector2(0, -2) * s, 11.0 * s, Color(1.0, 0.95, 0.92, a))
				if bonus:
					_text("Karte voll! Ein Lesezeichen und mehr Zeit zum Lesen ♥", Vector2(30, 268), HAND, 21, Color(STAMP.darkened(0.2), pop))
				if total > 0:
					_text("Bücher: %d von %d" % [scanned.size(), total], Vector2(30, 306), HAND, 22, INK)
					var x := 30.0
					for title in scanned.slice(maxi(0, scanned.size() - 2)):
						_text("✓ " + title.left(26), Vector2(30, 334 + (x - 30.0)), HAND, 18, SOFT)
						x += 22.0
			"done":
				_text("Viel Freude", Vector2(30, 150), TITLE, 56, INK)
				_text("beim Lesen!", Vector2(60, 210), TITLE, 56, INK)
				SoftShapes.heart(self, Vector2(380, 190), 26.0, STAMP)

	func _text(text: String, at: Vector2, font: Font, font_size: int, color: Color) -> void:
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, size.x - at.x - 20.0, font_size, color)
