class_name TabletApp
extends Control
## Grundlage für jede App auf dem Theken-Tablet (CounterTablet).
##
## Eine App ist eine kleine Szene, deren Wurzel-Knoten ein Script hat, das von TabletApp erbt,
## dazu ein Datenblatt in data/tablet_apps/ (TabletAppData). Das Tablet setzt "tablet" und ruft:
## - app_opened(): jedes Mal, wenn die App geöffnet wird (z. B. Rückmeldungen leeren),
## - refresh(): wenn sich Geld, Inventar oder Bücher geändert haben (höchstens einmal pro Bild).
## Gestaltung wie im Regal-Menü: Farben und Bausteine aus TabletFrame, Symbol-Knöpfe
## (TabletIconButton) mit kurzem Tooltip, wenig Text.

## Das Tablet, auf dem die App läuft (für Spielfigur, Vorschaubilder, Wackeln …).
var tablet: CounterTablet


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Die App wird geöffnet.
func app_opened() -> void:
	pass


## Geld, Inventar oder Bücher haben sich geändert: neu anzeigen.
func refresh() -> void:
	pass


## Neu anzeigen, aber erst am Ende des Bilds – so wird kein Knopf entfernt, während sein
## Klick noch verarbeitet wird.
func request_refresh() -> void:
	if tablet and tablet.is_open:
		tablet.queue_refresh()
	else:
		refresh()


# --- Kleine Bausteine für alle Apps ---

func make_label(text: String, font_size: int = 17, color: Color = TabletFrame.TEXT_COLOR) -> Label:
	var label := TabletFrame.make_label(text, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func make_icon_button(kind: TabletIconButton.Icon, action: Callable, tip: String = "") -> TabletIconButton:
	var button := TabletIconButton.new()
	button.icon_kind = kind
	if not tip.is_empty():
		button.tooltip_text = tip
	button.pressed.connect(action)
	return button


## Ein Kasten auf dem Bildschirm (z. B. für eine Spalte oder Zeile).
func make_panel(margin: float = 12.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", TabletFrame.make_panel_style(TabletFrame.PANEL_COLOR, 12, margin))
	return panel


## Ein Knopf mit Text, der als ausgewählt hervorgehoben werden kann (z. B. Kategorien).
func make_choice_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 17)
	var selected := TabletFrame.make_panel_style(Color(0.45, 0.31, 0.2, 1.0), 8, 8.0)
	selected.border_color = TabletFrame.KEY_COLOR
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
