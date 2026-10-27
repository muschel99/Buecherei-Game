class_name IconToggle
extends Button
## Runder Symbol-Knopf zum An- und Abwählen (Filter und Kategorien in Shop und Gestaltungsmodus).
##
## Zeigt ein gezeichnetes Symbol (CatalogIcons, Schlüssel icon_key), ein eigenes Bild (texture)
## oder einen Farbpunkt (dot_color, z. B. für Stile). Der Name steht nur im Tooltip –
## auf dem Bildschirm bleibt es bei einem Symbol.

const LINE_COLOR := Color(1.0, 0.94, 0.84, 0.88)
const ACTIVE_COLOR := Color(0.96, 0.78, 0.48)
const EMPTY_ALPHA := 0.38

## Schlüssel des gezeichneten Symbols (siehe CatalogIcons).
var icon_key: String = "":
	set(value):
		icon_key = value
		queue_redraw()
## Eigenes Bild statt Zeichnung (z. B. das Symbol eines Stils).
var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## Farbpunkt statt Symbol (Alpha 0 = keiner). Mit dot_ring = hohler Ring.
var dot_color: Color = Color(0, 0, 0, 0):
	set(value):
		dot_color = value
		queue_redraw()
var dot_ring: bool = false
## Mehrere kleine Farbpunkte (z. B. „Alle Stile“).
var dot_colors: Array[Color] = []
## Gibt es hier gerade nichts? Dann leicht ausgegraut (bleibt anklickbar).
var is_empty: bool = false:
	set(value):
		is_empty = value
		modulate.a = EMPTY_ALPHA if value else 1.0


func _init(side: float = 40.0) -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(side, side)
	text = ""
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(int(side / 2.0))
		box.anti_aliasing = true
		match state:
			"normal":
				box.bg_color = Color(1.0, 0.95, 0.85, 0.06)
			"hover":
				box.bg_color = Color(1.0, 0.95, 0.85, 0.16)
			"pressed", "hover_pressed":
				box.bg_color = Color(0.45, 0.31, 0.2, 1.0)
				box.border_color = ACTIVE_COLOR
				box.set_border_width_all(2)
			_:
				box.bg_color = Color(0, 0, 0, 0)
		add_theme_stylebox_override(state, box)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func _draw() -> void:
	var inner := Rect2(Vector2.ONE * size.x * 0.2, size * 0.6)
	var color := ACTIVE_COLOR if button_pressed or is_hovered() else LINE_COLOR
	if texture:
		draw_texture_rect(texture, inner, false)
	elif not dot_colors.is_empty():
		var n := dot_colors.size()
		for i in n:
			var angle := -PI / 2.0 + TAU * i / n
			var center := size / 2.0 + Vector2(cos(angle), sin(angle)) * size.x * 0.15
			draw_circle(center, size.x * 0.11, dot_colors[i])
	elif dot_color.a > 0.0:
		if dot_ring:
			draw_arc(size / 2.0, size.x * 0.2, 0.0, TAU, 32, dot_color, maxf(1.5, size.x * 0.05), true)
		else:
			draw_circle(size / 2.0, size.x * 0.2, dot_color)
			draw_arc(size / 2.0, size.x * 0.2, 0.0, TAU, 32, color.darkened(0.2), 1.0, true)
	else:
		CatalogIcons.draw(self, icon_key, inner, color)
