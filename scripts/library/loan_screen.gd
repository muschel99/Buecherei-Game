class_name LoanScreen
extends Control
## Bild „Bücherei-Ausleihe“ (seit dem Nachtest von Etappe 8 auf dem Theken-Tablet, vorher auf dem PC): erscheint nur, während man
## einen Gast bedient (ShopTablet.show_loan). Nach dem Einlesen des Ausweises Name und Stempelkarte (der neue Stempel ploppt
## auf), dann die gescannten Bücher, zum Schluss ein Dankeschön. Gezeichnet in einem SubViewport (ShopTablet), Schriften
## gemütlich-technisch (Nunito, Überschriften Fredoka). Die Liste aller Ausweise zeigt die App „Ausleihe“ (LoansApp).

signal changed(seconds: float)

const BG := Color(0.99, 0.96, 0.9)
const BAR := Color(0.62, 0.74, 0.66)
const INK := Color(0.27, 0.22, 0.2)
const SOFT := Color(0.5, 0.42, 0.38)
const STAMP := Color(0.86, 0.45, 0.48)
const TITLE := preload("res://assets/ui/fonts/Fredoka-SemiBold.woff2")
const TEXT := preload("res://assets/ui/fonts/Nunito-SemiBold.woff2")
const BOLD := preload("res://assets/ui/fonts/Nunito-ExtraBold.woff2")

var mode := "wait"
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


## Warten auf den Ausweis (Gast steht an der Theke).
func show_wait() -> void:
	mode = "wait"
	scanned.clear()
	total = 0
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
	# Kopfleiste mit dem Namen der Anzeige (groß genug, um sie aus der Theken-Ansicht zu lesen)
	draw_rect(Rect2(0, 0, size.x, 60), BAR)
	_text("Bücherei-Ausleihe", Vector2(22, 43), TITLE, 32, Color(1, 0.98, 0.94))
	SoftShapes.heart(self, Vector2(size.x - 36, 30), 11.0, Color(1, 0.94, 0.94))
	match mode:
		"wait":
			_text("Ausweis bitte", Vector2(22, 130), BOLD, 38, SOFT)
			_text("in den Kartenleser", Vector2(22, 178), BOLD, 38, SOFT)
			SoftShapes.heart(self, Vector2(size.x / 2.0, 272), 40.0, Color(STAMP, 0.35))
		"card":
			_text(reader_name, Vector2(22, 108), BOLD, 42, INK)
			var cell := 50.0
			for k in GameConfig.stamp_card_size:
				var c := Vector2(50 + (k % 5) * (cell + 20), 156 + (k / 5) * (cell + 10))
				draw_arc(c, cell / 2.0, 0.0, TAU, 28, Color(SOFT, 0.45), 2.5, true)
				var filled := k < stamps or bonus
				if not filled:
					continue
				var is_new := (k == stamps - 1 and not bonus) or (bonus and k == GameConfig.stamp_card_size - 1)
				var s := 1.0 if not is_new else lerpf(1.8, 1.0, pop)
				var a := 1.0 if not is_new else pop
				draw_circle(c, cell / 2.0 * 0.82 * s, Color(STAMP, 0.85 * a))
				SoftShapes.heart(self, c + Vector2(0, -2) * s, 10.0 * s, Color(1.0, 0.95, 0.92, a))
			if bonus:
				_text("Karte voll! Lesezeichen und mehr Zeit", Vector2(22, 266), BOLD, 24, Color(STAMP.darkened(0.2), pop))
			if total > 0:
				_text("Bücher: %d von %d" % [scanned.size(), total], Vector2(22, 304), BOLD, 32, INK)
				if not scanned.is_empty():
					_text("✓  " + scanned.back().left(30), Vector2(22, 342), TEXT, 24, SOFT)
		"done":
			_text("Viel Freude", Vector2(22, 170), TITLE, 60, INK)
			_text("beim Lesen!", Vector2(52, 238), TITLE, 60, INK)
			SoftShapes.heart(self, Vector2(size.x - 80, 205), 30.0, STAMP)


func _text(text: String, at: Vector2, font: Font, font_size: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, size.x - at.x - 16.0, font_size, color)
