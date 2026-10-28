@tool
class_name TabletAppStyle
extends Resource
## Der eigene Look einer App auf dem Theken-Tablet (seit Etappe 6b): Jede App wirkt wie von einem
## eigenen Anbieter – Farben, Hintergrundmuster, Schrift, Rundung von Kästen, Kacheln und Knöpfen.
## Steht im Datenblatt der App (TabletAppData.style). Ohne Stil sieht die App aus wie das Tablet
## (warmes Braun). Die App holt sich ihre Farben und Bausteine über TabletApp (make_label …),
## das Tablet färbt damit Hintergrund, Leiste und Ladebildschirm.

## Hintergrundmuster des Bildschirms (gezeichnet, keine Bilder).
enum Pattern { NONE, LINEN, PAPER, LINES, GRID, KRAFT, DOTS }

@export_group("Farben")
## Bildschirm hinter der App
@export var background: Color = Color(0.17, 0.12, 0.09)
## Farbe des Musters (Fäden, Linien, Punkte …)
@export var pattern_color: Color = Color(1.0, 0.95, 0.85, 0.05)
@export var pattern: Pattern = Pattern.NONE
## Kästen, Karten und Kacheln
@export var panel: Color = Color(0.24, 0.17, 0.12, 0.9)
@export var panel_border: Color = Color(0, 0, 0, 0)
## Normale Schrift, gedämpfte Schrift (Untertitel, Hinweise)
@export var text: Color = Color(1.0, 0.96, 0.88)
@export var muted: Color = Color(0.85, 0.78, 0.68, 0.85)
## Akzent: Preise, Hervorhebungen, gewählte Kacheln, Hauptknopf
@export var accent: Color = Color(0.96, 0.78, 0.48)
## Schrift auf dem Hauptknopf (auf der Akzentfarbe)
@export var accent_text: Color = Color(0.2, 0.13, 0.08)
## Zweite Farbe (Balken, kleine Zeichen)
@export var second: Color = Color(0.85, 0.55, 0.4)

@export_group("Formen")
## Rundung von Kästen und Kacheln (Pixel)
@export var radius: int = 12
## Rundung von Knöpfen (groß = Pille)
@export var button_radius: int = 8
## Rahmenstärke von Kästen (0 = ohne)
@export var border_width: int = 0

@export_group("Schrift")
## Schrift für alles (leer = Schrift des Spiels)
@export var font: Font
## Schrift für Name und Überschriften (leer = wie font)
@export var title_font: Font
## Überschriften in Großbuchstaben
@export var title_uppercase: bool = false
## Zusätzlicher Abstand zwischen den Buchstaben der Überschriften (Pixel)
@export var title_spacing: int = 0

@export_group("Begrüßung")
## Text auf dem Ladebildschirm, %s = Name der App (z. B. "Willkommen bei %s")
@export var welcome: String = "Willkommen bei %s"


## Schrift der Überschriften (mit Buchstabenabstand), sonst die normale Schrift.
func get_title_font() -> Font:
	var base: Font = title_font if title_font else font
	if title_spacing == 0:
		return base
	var variation := FontVariation.new()
	variation.base_font = base if base else ThemeDB.fallback_font
	variation.spacing_glyph = title_spacing
	return variation


## Überschrift so, wie sie erscheinen soll (z. B. in Großbuchstaben).
func title_text(value: String) -> String:
	return value.to_upper() if title_uppercase else value


## Ein Kasten in den Farben und Formen der App.
func make_panel_box(margin: float = 12.0, color: Variant = null) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color if color is Color else panel
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	if border_width > 0:
		box.border_color = panel_border
		box.set_border_width_all(border_width)
	box.set_content_margin_all(margin)
	return box


## Ein Godot-Theme aus diesen Farben (für alles, was keine eigenen Farben gesetzt hat:
## Knöpfe, Listen, Schieberegler, Bildlaufleisten).
func make_theme() -> Theme:
	var theme := Theme.new()
	if font:
		theme.default_font = font
	theme.set_color("font_color", "Label", text)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", text)
	theme.set_color("font_disabled_color", "Button", Color(muted, muted.a * 0.6))
	var states := {
		"normal": Color(panel, minf(panel.a, 0.9)),
		"hover": panel.lerp(accent, 0.18),
		"pressed": panel.lerp(accent, 0.3),
		"hover_pressed": panel.lerp(accent, 0.36),
		"disabled": Color(panel, panel.a * 0.5),
	}
	for state: String in states:
		var box := make_panel_box(10.0, states[state])
		box.set_corner_radius_all(button_radius)
		box.content_margin_left = 18
		box.content_margin_right = 18
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		theme.set_stylebox(state, "Button", box)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", make_panel_box())
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(text, 0.35)
	grabber.set_corner_radius_all(4)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber", "HScrollBar", grabber)
	var grabber_hover := grabber.duplicate()
	grabber_hover.bg_color = accent
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_hover)
	theme.set_stylebox("grabber_highlight", "HScrollBar", grabber_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_hover)
	theme.set_stylebox("grabber_pressed", "HScrollBar", grabber_hover)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(text, 0.06)
	track.set_corner_radius_all(4)
	theme.set_stylebox("scroll", "VScrollBar", track)
	theme.set_stylebox("scroll", "HScrollBar", track)
	return theme
