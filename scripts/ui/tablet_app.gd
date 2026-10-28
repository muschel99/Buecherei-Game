class_name TabletApp
extends Control
## Grundlage für jede App auf dem Theken-Tablet (CounterTablet).
##
## Eine App ist eine kleine Szene, deren Wurzel-Knoten ein Script hat, das von TabletApp erbt,
## dazu ein Datenblatt in data/tablet_apps/ (TabletAppData). Das Tablet setzt "tablet" und ruft:
## - app_opened(): jedes Mal, wenn die App geöffnet wird (z. B. Rückmeldungen leeren),
## - refresh(): wenn sich Geld, Inventar oder Bücher geändert haben (höchstens einmal pro Bild).
## Seit Etappe 6b hat jede App ihren eigenen Look (style, aus TabletAppData.style): Farben, Schrift,
## Formen. Darum nie feste Farben verwenden, sondern style.text, style.muted, style.accent, style.panel
## und die Bausteine hier (make_label, make_title, make_panel, make_choice_button,
## make_primary_button, make_icon_button). Symbol-Knöpfe (TabletIconButton) mit kurzem Tooltip,
## wenig Text.

## Das Tablet, auf dem die App läuft (für Spielfigur, Vorschaubilder …).
var tablet: CounterTablet
## Der Look der App (ohne eigenen Stil der des Tablets: warmes Braun).
var style: TabletAppStyle = TabletAppStyle.new()


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Das Tablet setzt den Look der App, bevor sie zum ersten Mal erscheint.
func apply_style(new_style: TabletAppStyle) -> void:
	style = new_style if new_style else TabletAppStyle.new()
	theme = style.make_theme()


## Die App wird geöffnet.
func app_opened() -> void:
	pass


## Geld, Inventar oder Bücher haben sich geändert: neu anzeigen.
func refresh() -> void:
	pass


## Ein eigener Bereich neben dem Tablet (z. B. die Polaroids der App „Fassade“) – null = keiner.
## Hat eine App einen, rückt das Tablet nach dem Öffnen nach links und zeigt ihn rechts daneben.
func get_side_view() -> Control:
	return null


## Der Bereich neben dem Tablet erscheint (true) bzw. verschwindet (false).
func side_view_changed(_shown: bool) -> void:
	pass


## Neu anzeigen, aber erst am Ende des Bilds – so wird kein Knopf entfernt, während sein
## Klick noch verarbeitet wird.
func request_refresh() -> void:
	if tablet and tablet.is_open:
		tablet.queue_refresh()
	else:
		refresh()


# --- Kleine Bausteine für alle Apps ---

## Text in der Farbe der App (ohne Farbangabe: style.text).
func make_label(text: String, font_size: int = 17, color: Color = Color.TRANSPARENT) -> Label:
	var label := TabletFrame.make_label(text, font_size, style.text if color.a == 0.0 else color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Überschrift in der Schrift der App (z. B. Großbuchstaben mit Abstand).
func make_title(text: String, font_size: int = 22, color: Color = Color.TRANSPARENT) -> Label:
	var label := make_label(style.title_text(text), font_size, color)
	var title_font := style.get_title_font()
	if title_font:
		label.add_theme_font_override("font", title_font)
	return label


func make_icon_button(kind: TabletIconButton.Icon, action: Callable, tip: String = "") -> TabletIconButton:
	var button := TabletIconButton.new()
	button.icon_kind = kind
	button.set_colors(style.text, style.accent)
	if not tip.is_empty():
		button.tooltip_text = tip
	button.pressed.connect(action)
	return button


## Ein Kasten auf dem Bildschirm (z. B. für eine Spalte oder Zeile).
func make_panel(margin: float = 12.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style.make_panel_box(margin))
	return panel


## Der Hauptknopf einer Seite (z. B. „Bestellen“): in der Akzentfarbe der App.
func make_primary_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var color := style.accent
		match state:
			"hover", "hover_pressed":
				color = style.accent.lightened(0.1)
			"pressed":
				color = style.accent.darkened(0.1)
			"disabled":
				color = Color(style.accent, 0.35)
		var box := style.make_panel_box(10.0, color)
		box.set_corner_radius_all(style.button_radius)
		box.border_width_left = 0
		box.border_width_top = 0
		box.border_width_right = 0
		box.border_width_bottom = 0
		box.content_margin_left = 24
		box.content_margin_right = 24
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, style.accent_text)
	button.add_theme_color_override("font_disabled_color", Color(style.accent_text, 0.5))
	button.pressed.connect(action)
	return button


## Ein Knopf mit Text, der als ausgewählt hervorgehoben werden kann (z. B. Kategorien).
func make_choice_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 17)
	var selected := style.make_panel_box(8.0, style.panel.lerp(style.accent, 0.25))
	selected.set_corner_radius_all(style.button_radius)
	selected.border_color = style.accent
	selected.set_border_width_all(2)
	# Gleiche Innenabstände wie im Theme, damit der Text beim Auswählen nicht springt
	selected.content_margin_left = 24
	selected.content_margin_right = 24
	selected.content_margin_top = 10
	selected.content_margin_bottom = 10
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)
	button.pressed.connect(action)
	return button


## Leert einen Container (die alten Kinder verschwinden am Ende des Bilds).
static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
