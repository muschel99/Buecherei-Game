class_name ItemTile
extends Button
## Bild-Kachel für ein Möbelstück oder eine Oberfläche (Gestaltungsmodus und Shop „Nest & Nook“).
##
## Groß das Vorschaubild in der gewählten Farbe (ThumbnailRenderer fotografiert das Modell) bzw.
## das Farbfeld einer Wandfarbe/eines Bodens, klein in der Ecke eine Zahl (Anzahl im Inventar
## oder Preis). Im Shop darunter Farbtupfer zum Wählen der Farbe vor dem Kauf. Name und Werte
## stehen nur im Tooltip – so bleibt fast kein Text auf dem Bildschirm.

## Ein Farbtupfer wurde angeklickt (die Kachel zeigt jetzt diese Farbe).
signal variant_chosen(variant: String)

const TEXT_COLOR := Color(1.0, 0.96, 0.88)
const KEY_COLOR := Color(0.96, 0.78, 0.48)
const DOT_SIZE := 18.0

## Das Datenblatt (FurnitureData oder SurfaceData).
var item: Resource
## Gewählte Farbe (Möbel mit Farbvarianten, sonst leer).
var variant: String = ""

var _thumbnails: ThumbnailRenderer
var _picture: TextureRect
var _swatch: Panel
var _badge: PanelContainer
var _badge_label: Label
var _badge_coin: Control
var _dots: HBoxContainer
var _dot_buttons := {}  # Farb-id -> Button
var _show_dots := false
## Ring um den gewählten Farbtupfer (in Apps mit eigenem Look deren Akzent)
var ring_color := KEY_COLOR
## Farbe der Zahl oben rechts, wenn set_badge ohne eigene Farbe aufgerufen wird
var _badge_default_color := KEY_COLOR


## tile_size: Größe der Kachel; with_dots: Farbtupfer zum Wählen (Shop).
func _init(tile_size: Vector2 = Vector2(132, 112), with_dots: bool = false) -> void:
	custom_minimum_size = tile_size
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	_show_dots = with_dots
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(12)
		box.anti_aliasing = true
		match state:
			"normal":
				box.bg_color = Color(0.36, 0.27, 0.2, 0.55)
			"hover":
				box.bg_color = Color(0.46, 0.34, 0.24, 0.75)
			"pressed", "hover_pressed":
				box.bg_color = Color(0.48, 0.34, 0.22, 0.9)
				box.border_color = KEY_COLOR
				box.set_border_width_all(3)
			"disabled":
				box.bg_color = Color(0.3, 0.22, 0.16, 0.35)
			_:
				box.bg_color = Color(0, 0, 0, 0)
		add_theme_stylebox_override(state, box)

	var bottom := DOT_SIZE + 10.0 if with_dots else 6.0
	_picture = TextureRect.new()
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.offset_left = 6
	_picture.offset_top = 6
	_picture.offset_right = -6
	_picture.offset_bottom = -bottom
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)

	_swatch = Panel.new()
	_swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_swatch.offset_left = 16
	_swatch.offset_top = 14
	_swatch.offset_right = -16
	_swatch.offset_bottom = -bottom - 8
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swatch.visible = false
	add_child(_swatch)

	_badge = PanelContainer.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = Color(0.13, 0.09, 0.07, 0.82)
	badge_box.set_corner_radius_all(9)
	badge_box.content_margin_left = 7
	badge_box.content_margin_right = 7
	badge_box.content_margin_top = 1
	badge_box.content_margin_bottom = 2
	_badge.add_theme_stylebox_override("panel", badge_box)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge.offset_left = -6
	_badge.offset_right = -6
	_badge.offset_top = 6
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 4)
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(badge_row)
	_badge_coin = _Coin.new()
	_badge_coin.visible = false
	badge_row.add_child(_badge_coin)
	_badge_label = Label.new()
	_badge_label.add_theme_font_size_override("font_size", 13)
	_badge_label.add_theme_color_override("font_color", KEY_COLOR)
	badge_row.add_child(_badge_label)
	_badge.visible = false
	add_child(_badge)

	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 5)
	_dots.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dots.offset_top = -DOT_SIZE - 6
	_dots.offset_bottom = -6
	_dots.mouse_filter = Control.MOUSE_FILTER_PASS
	_dots.visible = false
	add_child(_dots)


## Zeigt ein Datenblatt (in der Farbe variant). thumbnails: Fotograf für das Vorschaubild.
func setup(new_item: Resource, new_variant: String, thumbnails: ThumbnailRenderer) -> void:
	item = new_item
	_thumbnails = thumbnails
	variant = new_item.resolve_variant(new_variant) if new_item is FurnitureData else ""
	if item is SurfaceData:
		_picture.visible = false
		_swatch.visible = true
		var box := StyleBoxFlat.new()
		box.bg_color = item.preview_color
		box.set_corner_radius_all(8)
		box.border_color = item.preview_color.darkened(0.25)
		box.set_border_width_all(2)
		_swatch.add_theme_stylebox_override("panel", box)
	else:
		_build_dots()
		_load_picture()


## Tooltip-Text: Name (und Farbe), Grundfläche, Stile, Beschreibung. extra = weitere Zeilen.
static func describe(described: Resource, variant_id: String = "", extra: Array[String] = []) -> String:
	var title: String = described.display_name
	var lines: Array[String] = []
	if described is FurnitureData:
		if described.has_variants():
			title += " · " + described.get_variant_name(variant_id)
		var area: Vector2 = described.get_footprint_size()
		lines.append("%s × %s m" % [_decimal(area.x), _decimal(area.y)])
	var names: Array[String] = []
	for style_id in StyleTags.known(described.style_ids):
		names.append(StyleTags.get_display_name(style_id))
	lines.append(", ".join(names) if not names.is_empty() else "stilneutral")
	if "description" in described and not str(described.description).is_empty():
		lines.append(str(described.description))
	lines.append_array(extra)
	return title + "\n" + "\n".join(lines)


static func _decimal(value: float) -> String:
	return String.num(value, 2).replace(".", ",")


## Kleine Zahl oben rechts (z. B. „×2“); leer = keine. coin = kleine Goldmünze davor (Preis).
func set_badge(text: String, color: Color = KEY_COLOR, coin: bool = false) -> void:
	_badge.visible = not text.is_empty()
	_badge_label.text = text
	_badge_label.add_theme_color_override("font_color", _badge_default_color if color == KEY_COLOR else color)
	_badge_coin.visible = coin


## Im Look einer Tablet-App (seit Etappe 6b): Kachel, Rahmen, Zahl und Tupfer-Ring in ihren Farben.
func apply_style(style: TabletAppStyle) -> void:
	var states := {
		"normal": style.panel,
		"hover": style.panel.lerp(style.accent, 0.16),
		"pressed": style.panel.lerp(style.accent, 0.22),
		"hover_pressed": style.panel.lerp(style.accent, 0.28),
		"disabled": Color(style.panel, style.panel.a * 0.6),
	}
	for state: String in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state]
		box.set_corner_radius_all(style.radius)
		box.anti_aliasing = true
		if state.contains("pressed"):
			box.border_color = style.accent
			box.set_border_width_all(3)
		elif style.border_width > 0:
			box.border_color = style.panel_border
			box.set_border_width_all(style.border_width)
		add_theme_stylebox_override(state, box)
	var badge_box := _badge.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	badge_box.bg_color = Color(style.text, 0.88)
	badge_box.set_corner_radius_all(mini(style.button_radius, 9) if style.button_radius > 2 else 2)
	_badge.add_theme_stylebox_override("panel", badge_box)
	_badge_default_color = style.panel if style.panel.get_luminance() > 0.5 else style.background
	_badge_label.add_theme_color_override("font_color", _badge_default_color)
	if style.font:
		_badge_label.add_theme_font_override("font", style.font)
	ring_color = style.accent
	for dot in _dot_buttons.values():
		dot.queue_redraw()


## Ausgegraut (z. B. Oberfläche gehört mir schon), bleibt sichtbar.
func set_dimmed(dimmed: bool) -> void:
	_picture.modulate.a = 0.45 if dimmed else 1.0
	_swatch.modulate.a = 0.45 if dimmed else 1.0


## Wählt eine Farbe (Bild und Tupfer zeigen sie).
func choose_variant(new_variant: String) -> void:
	if not item is FurnitureData:
		return
	variant = item.resolve_variant(new_variant)
	for id in _dot_buttons:
		_dot_buttons[id].queue_redraw()
	_load_picture()
	variant_chosen.emit(variant)


func _load_picture() -> void:
	if not item is FurnitureData or _thumbnails == null:
		return
	var cached := ThumbnailRenderer.get_cached(item, variant)
	if cached:
		_picture.texture = cached
		return
	# Schwache Referenz: Ist die Kachel schon weg, bevor das Foto fertig ist, passiert nichts
	var self_ref: WeakRef = weakref(self)
	var wanted := variant
	var on_ready := func(texture: Texture2D) -> void:
		var tile := self_ref.get_ref() as ItemTile
		if tile and tile.variant == wanted:
			tile._picture.texture = texture
	_thumbnails.request(item, on_ready, variant)


func _build_dots() -> void:
	for child in _dots.get_children():
		child.queue_free()
	_dot_buttons.clear()
	_dots.visible = _show_dots and item is FurnitureData and item.has_variants()
	if not _dots.visible:
		return
	for color_variant: ColorVariant in item.color_variants:
		if color_variant == null:
			continue
		var dot := _ColorDot.new(self, color_variant)
		dot.pressed.connect(choose_variant.bind(color_variant.id))
		_dots.add_child(dot)
		_dot_buttons[color_variant.id] = dot


## Kleine Goldmünze vor dem Preis.
class _Coin:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(11, 11)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size / 2.0
		draw_circle(center, 5.0, Color(0.93, 0.74, 0.36))
		draw_arc(center, 3.2, 0.0, TAU, 16, Color(0.7, 0.5, 0.2), 1.0, true)


## Farbtupfer: runder Knopf in der Farbe einer Variante, die gewählte mit Ring.
class _ColorDot:
	extends Button
	var tile: ItemTile
	var color_variant: ColorVariant

	func _init(owner_tile: ItemTile, value: ColorVariant) -> void:
		tile = owner_tile
		color_variant = value
		custom_minimum_size = Vector2(ItemTile.DOT_SIZE, ItemTile.DOT_SIZE)
		focus_mode = Control.FOCUS_NONE
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = value.display_name if not value.display_name.is_empty() else value.id
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			add_theme_stylebox_override(state, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var center := size / 2.0
		var radius := size.x * 0.36
		draw_circle(center, radius, color_variant.get_swatch())
		draw_arc(center, radius, 0.0, TAU, 24, Color(0, 0, 0, 0.35), 1.0, true)
		if tile.variant == color_variant.id or is_hovered():
			draw_arc(center, radius + 2.5, 0.0, TAU, 28, tile.ring_color, 1.6, true)
