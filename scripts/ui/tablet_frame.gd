class_name TabletFrame
extends PanelContainer
## Gemeinsame Vorlage für alles, was als Tablet erscheint (Regal-Menü, Theken-Tablet mit Shop):
## ein dunkler Rahmen mit runden Ecken und kleiner Kamera oben, darin der warme Bildschirm.
##
## So benutzt man sie: einen PanelContainer-Knoten mit diesem Script anlegen (in einer Szene
## oder im Code) und den Inhalt als Kind hinzufügen – er liegt dann auf dem Bildschirm.
## Für den Inhalt gibt es passende Farben (TEXT_COLOR …) und Bausteine: make_label(),
## make_close_button() (kleines Kreuz oben rechts, wie im Browser) und TabletIconButton
## (Symbol-Knöpfe mit kurzem Tooltip). So sehen Regal-Menü und Theken-Tablet gleich aus.
## Optik austauschen: nur die Konstanten hier ändern.

## Farbe des Gehäuses (wie das Tablet an der Theke)
const BEZEL_COLOR := Color(0.1, 0.085, 0.07, 0.98)
const BEZEL_EDGE_COLOR := Color(0.34, 0.29, 0.24, 0.75)
## Farbe des Bildschirms
const SCREEN_COLOR := Color(0.17, 0.12, 0.09, 1.0)
## Farbe für Kästen auf dem Bildschirm (z. B. Listen)
const PANEL_COLOR := Color(0.24, 0.17, 0.12, 0.9)
const TEXT_COLOR := Color(1.0, 0.96, 0.88)
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.85)
const KEY_COLOR := Color(0.96, 0.78, 0.48)
## Breite des Rahmens und Abstand vom Bildschirmrand zum Inhalt (Pixel)
const BEZEL := 16.0
const PADDING := 16.0
const BEZEL_RADIUS := 30
const SCREEN_RADIUS := 16

var _screen_box: StyleBoxFlat


func _init() -> void:
	_screen_box = StyleBoxFlat.new()
	_screen_box.bg_color = SCREEN_COLOR
	_screen_box.set_corner_radius_all(SCREEN_RADIUS)
	_screen_box.anti_aliasing = true
	_apply_bezel()


func _ready() -> void:
	# Auch in Szenen (dort könnte im Inspektor noch ein anderer Stil eingetragen sein)
	_apply_bezel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Der Bildschirm und die kleine Kamera werden auf das Gehäuse gezeichnet.
func _draw() -> void:
	var screen := Rect2(Vector2(BEZEL, BEZEL), size - Vector2(BEZEL, BEZEL) * 2.0)
	if screen.size.x > 0.0 and screen.size.y > 0.0:
		draw_style_box(_screen_box, screen)
	draw_circle(Vector2(size.x / 2.0, BEZEL / 2.0), 2.5, Color(0.24, 0.21, 0.19))


func _apply_bezel() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = BEZEL_COLOR
	box.border_color = BEZEL_EDGE_COLOR
	box.set_border_width_all(2)
	box.set_corner_radius_all(BEZEL_RADIUS)
	box.anti_aliasing = true
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_size = 14
	box.set_content_margin_all(BEZEL + PADDING)
	add_theme_stylebox_override("panel", box)


# --- Bausteine für den Inhalt ---

## Text auf dem Tablet (umbricht bei Bedarf).
static func make_label(text: String, font_size: int = 17, color: Color = TEXT_COLOR) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 120
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Das kleine Kreuz oben rechts zum Schließen.
static func make_close_button() -> TabletIconButton:
	var button := TabletIconButton.new()
	button.icon_kind = TabletIconButton.Icon.CLOSE
	return button


## Stil für Kästen auf dem Bildschirm (z. B. Zeilen, Listen).
static func make_panel_style(color: Color = PANEL_COLOR, radius: int = 10, margin: float = 10.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
