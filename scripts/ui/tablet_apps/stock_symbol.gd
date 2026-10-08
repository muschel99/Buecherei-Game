class_name StockSymbol
extends Control
## Kleines gezeichnetes Symbol für die Bestand-App: wo Bücher gerade sind.
## STORAGE = Kiste (Lager), SHELF = Regal, LOOSE = ausgelegtes Buch, AWAY = unterwegs
## (in der Hand oder im Rückgabekasten). Mit Tooltip (ein Wort).

enum Kind { STORAGE, SHELF, LOOSE, AWAY }

const TIPS := {Kind.STORAGE: "Im Lager", Kind.SHELF: "Im Regal", Kind.LOOSE: "Ausgelegt", Kind.AWAY: "Unterwegs"}
const LINE_COLOR := Color(1.0, 0.94, 0.84, 0.85)

var kind: Kind = Kind.STORAGE


static func create(new_kind: Kind) -> StockSymbol:
	var symbol := StockSymbol.new()
	symbol.kind = new_kind
	symbol.tooltip_text = TIPS[new_kind]
	symbol.custom_minimum_size = Vector2(26, 26)
	symbol.mouse_filter = Control.MOUSE_FILTER_PASS
	return symbol


func _draw() -> void:
	var c := size / 2.0
	var w := 1.8
	match kind:
		Kind.STORAGE:
			_rect(Rect2(c + Vector2(-10, -4), Vector2(20, 13)), w)
			draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), LINE_COLOR, 1.4, true)
			draw_line(c + Vector2(-3, -4), c + Vector2(-3, -8), LINE_COLOR, 1.4, true)
			draw_line(c + Vector2(3, -4), c + Vector2(3, -9), LINE_COLOR, 1.4, true)
		Kind.SHELF:
			_rect(Rect2(c + Vector2(-10, -10), Vector2(20, 20)), w)
			draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), LINE_COLOR, w, true)
			for x in [-7.0, -4.0, -1.0]:
				draw_line(c + Vector2(x, -1), c + Vector2(x, -8), LINE_COLOR, 1.4, true)
			for x in [3.0, 6.0]:
				draw_line(c + Vector2(x, 9), c + Vector2(x, 2), LINE_COLOR, 1.4, true)
		Kind.LOOSE:
			# Ein flach liegendes Buch, schräg von oben
			draw_colored_polygon(PackedVector2Array([c + Vector2(-11, 2), c + Vector2(3, -5), c + Vector2(11, 0), c + Vector2(-3, 7)]),
				Color(LINE_COLOR, 0.25))
			draw_polyline(PackedVector2Array([c + Vector2(-11, 2), c + Vector2(3, -5), c + Vector2(11, 0), c + Vector2(-3, 7),
				c + Vector2(-11, 2)]), LINE_COLOR, w, true)
			draw_line(c + Vector2(-11, 2), c + Vector2(-11, 5), LINE_COLOR, w, true)
			draw_line(c + Vector2(-3, 7), c + Vector2(-3, 10), LINE_COLOR, w, true)
			draw_line(c + Vector2(-11, 5), c + Vector2(-3, 10), LINE_COLOR, w, true)
		Kind.AWAY:
			# Zwei kleine Pfeile im Kreis (unterwegs)
			draw_arc(c, 8.0, -PI * 0.15, PI * 0.85, 16, LINE_COLOR, w, true)
			draw_arc(c, 8.0, PI * 0.85, PI * 1.85, 16, Color(LINE_COLOR, 0.5), w, true)
			var tip := c + Vector2.from_angle(PI * 0.85) * 8.0
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-3, -3), tip + Vector2(3, -1), tip + Vector2(-1, 3)]), LINE_COLOR)


func _rect(rect: Rect2, width: float) -> void:
	draw_polyline(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y), rect.position]), LINE_COLOR, width, true)
