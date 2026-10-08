class_name TabletIconButton
extends Button
## Ein runder Symbol-Knopf für Tablets (siehe TabletFrame): statt langer Textzeilen ein kleines,
## gezeichnetes Symbol. Fährt die Maus darüber, erscheint kurz ein Tooltip mit einem Wort
## (tooltip_text; ohne eigenen Text nimmt er das Wort zum Symbol, siehe DEFAULT_TIPS).
## Die Symbole sind einfache Formen (keine Bilddateien) – austauschbar: einfach "icon" mit
## einem eigenen Bild setzen, dann wird das Bild statt der Form gezeigt.

enum Icon { CLOSE, BACK, PICK, FILL, SORT, STORE, HOME, BUY, SELL, PLUS, MINUS, EXPAND, COLLAPSE, NEXT, CONTENTS }

const DEFAULT_TIPS := {
	Icon.CLOSE: "Schließen",
	Icon.BACK: "Zurück",
	Icon.PICK: "Buch aus dem Lager",
	Icon.FILL: "Auffüllen",
	Icon.SORT: "Sortieren",
	Icon.STORE: "Alle ins Lager",
	Icon.HOME: "Startbildschirm",
	Icon.BUY: "Kaufen",
	Icon.SELL: "Verkaufen",
	Icon.PLUS: "Mehr",
	Icon.MINUS: "Weniger",
	Icon.EXPAND: "Aufklappen",
	Icon.COLLAPSE: "Zuklappen",
	Icon.NEXT: "Weiter",
	Icon.CONTENTS: "Inhalt",
}
## Kleine Knöpfe (Kreuz, Pfeile, Plus, Minus …): 34 Pixel, die anderen 46
const SMALL_ICONS := [Icon.CLOSE, Icon.BACK, Icon.HOME, Icon.PLUS, Icon.MINUS, Icon.EXPAND, Icon.COLLAPSE, Icon.NEXT]
const LINE_COLOR := Color(1.0, 0.94, 0.84, 0.92)
const HOVER_COLOR := Color(0.96, 0.78, 0.48)
const DISABLED_COLOR := Color(0.85, 0.78, 0.68, 0.3)

## Welches Symbol gezeichnet wird.
@export var icon_kind: Icon = Icon.CLOSE:
	set(value):
		icon_kind = value
		_update_size()
		queue_redraw()


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_update_size()


func _ready() -> void:
	text = ""
	if tooltip_text.is_empty():
		tooltip_text = DEFAULT_TIPS.get(icon_kind, "")
	var radius := int(custom_minimum_size.x / 2.0)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(radius)
		box.anti_aliasing = true
		match state:
			"normal":
				box.bg_color = Color(1.0, 0.95, 0.85, 0.07)
			"hover":
				box.bg_color = Color(1.0, 0.95, 0.85, 0.16)
			"pressed", "hover_pressed":
				box.bg_color = Color(1.0, 0.85, 0.6, 0.24)
			"disabled":
				box.bg_color = Color(1.0, 0.95, 0.85, 0.03)
			_:
				box.bg_color = Color(0, 0, 0, 0)
		add_theme_stylebox_override(state, box)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _update_size() -> void:
	var side := 34.0 if SMALL_ICONS.has(icon_kind) else 46.0
	custom_minimum_size = Vector2(side, side)


func _draw() -> void:
	if icon != null:
		return  # eigenes Bild: zeigt der Button selbst
	var color := DISABLED_COLOR if disabled else (HOVER_COLOR if is_hovered() or button_pressed else LINE_COLOR)
	var c := size / 2.0
	var w := 2.0
	match icon_kind:
		Icon.CLOSE:
			var r := 6.5
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), color, w, true)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), color, w, true)
		Icon.BACK:
			var r := 6.0
			draw_polyline(PackedVector2Array([c + Vector2(r * 0.5, -r), c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.5, r)]), color, w, true)
		Icon.PICK:
			# Ein Buch (Cover mit Rücken) und ein kleines Plus
			var book := Rect2(c + Vector2(-9, -11), Vector2(14, 19))
			_draw_rect_outline(book, color, w)
			draw_line(book.position + Vector2(3.5, 1), book.position + Vector2(3.5, book.size.y - 1), color, 1.5, true)
			var p := c + Vector2(8, 7)
			draw_circle(p, 6.0, Color(0.17, 0.12, 0.09))
			draw_line(p + Vector2(-3.5, 0), p + Vector2(3.5, 0), color, w, true)
			draw_line(p + Vector2(0, -3.5), p + Vector2(0, 3.5), color, w, true)
		Icon.FILL:
			# Drei Buchrücken auf einem Brett, darüber ein Pfeil nach unten
			var base_y := c.y + 11.0
			draw_line(Vector2(c.x - 12, base_y), Vector2(c.x + 12, base_y), color, w, true)
			for i in 3:
				var x := c.x - 9.0 + i * 6.5
				var h: float = [11.0, 14.0, 9.0][i]
				_draw_rect_outline(Rect2(Vector2(x, base_y - h - 1.0), Vector2(4.5, h)), color, 1.5)
			var top := c + Vector2(8, -13)
			draw_line(top, top + Vector2(0, 9), color, w, true)
			draw_polyline(PackedVector2Array([top + Vector2(-3.5, 5.5), top + Vector2(0, 9), top + Vector2(3.5, 5.5)]), color, w, true)
		Icon.SORT:
			# Trichter (Filter) mit kleinem Pfeil nach unten (= Auswahl klappt auf)
			var funnel := PackedVector2Array([c + Vector2(-11, -9), c + Vector2(7, -9), c + Vector2(0, 0),
				c + Vector2(0, 8), c + Vector2(-4, 10), c + Vector2(-4, 0), c + Vector2(-11, -9)])
			draw_polyline(funnel, color, w, true)
			var a := c + Vector2(10, 5)
			draw_colored_polygon(PackedVector2Array([a + Vector2(-3.5, -2), a + Vector2(3.5, -2), a + Vector2(0, 2.5)]), color)
		Icon.STORE:
			# Kiste mit Pfeil hinein (alles zurück ins Lager)
			var box := Rect2(c + Vector2(-11, -1), Vector2(22, 12))
			_draw_rect_outline(box, color, w)
			draw_line(box.position + Vector2(0, 4), box.position + Vector2(box.size.x, 4), color, 1.5, true)
			var top := c + Vector2(0, -13)
			draw_line(top, top + Vector2(0, 11), color, w, true)
			draw_polyline(PackedVector2Array([top + Vector2(-4, 7), top + Vector2(0, 11), top + Vector2(4, 7)]), color, w, true)
		Icon.HOME:
			# Kleines Haus
			draw_polyline(PackedVector2Array([c + Vector2(-8, -1), c + Vector2(0, -8), c + Vector2(8, -1)]), color, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-6, -2), c + Vector2(-6, 7), c + Vector2(6, 7), c + Vector2(6, -2)]), color, w, true)
			_draw_rect_outline(Rect2(c + Vector2(-1.8, 2), Vector2(3.6, 5)), color, 1.5)
		Icon.BUY:
			# Einkaufstasche
			var bag := Rect2(c + Vector2(-10, -5), Vector2(20, 16))
			_draw_rect_outline(bag, color, w)
			draw_arc(c + Vector2(0, -5), 5.0, PI, TAU, 12, color, w, true)
		Icon.SELL:
			# Münze mit Pfeil nach oben (Geld zurück)
			draw_arc(c + Vector2(-3, 2), 8.5, 0.0, TAU, 28, color, w, true)
			draw_line(c + Vector2(-3, -2), c + Vector2(-3, 6), color, 1.5, true)
			var tip := c + Vector2(10, -12)
			draw_line(tip, tip + Vector2(0, 10), color, w, true)
			draw_polyline(PackedVector2Array([tip + Vector2(-3.5, 3.5), tip, tip + Vector2(3.5, 3.5)]), color, w, true)
		Icon.PLUS, Icon.MINUS:
			var r := 6.0
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), color, w, true)
			if icon_kind == Icon.PLUS:
				draw_line(c + Vector2(0, -r), c + Vector2(0, r), color, w, true)
		Icon.NEXT:
			var r := 6.0
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.5, -r), c + Vector2(r * 0.6, 0), c + Vector2(-r * 0.5, r)]), color, w, true)
		Icon.CONTENTS:
			# Inhaltsverzeichnis: drei Zeilen mit Punkt davor
			for i in 3:
				var y := -7.0 + i * 7.0
				draw_circle(c + Vector2(-9, y), 1.6, color)
				draw_line(c + Vector2(-5, y), c + Vector2(10, y), color, w, true)
		Icon.EXPAND, Icon.COLLAPSE:
			var r := 6.0
			var dy := 2.5 if icon_kind == Icon.EXPAND else -2.5
			draw_polyline(PackedVector2Array([c + Vector2(-r, -dy), c + Vector2(0, dy), c + Vector2(r, -dy)]), color, w, true)


func _draw_rect_outline(rect: Rect2, color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y), rect.position]), color, width, true)
