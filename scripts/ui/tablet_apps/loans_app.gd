extends TabletApp
## App „Ausleihe“ auf dem Theken-Tablet (seit dem Nachtest von Etappe 8): alle Leseausweise mit ihrer Stempelkarte – vorher stand
## diese Liste immer auf dem PC an der Theke; jetzt zeigt das Tablet „Bücherei-Ausleihe“ nur beim Bedienen (LoanScreen), die
## Liste liegt hier. Je Ausweis eine Zeile: Name, Besuche, volle Karten, Freundschaft (Herzen, Stammgäste) und die Stempel.
## Stammgäste stehen oben, sonst nach Zahl der Besuche.

var _box: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 12)
	margin.add_child(_box)


func refresh() -> void:
	clear(_box)
	var ids := Lending.readers.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ra := a.begins_with("stamm_")
		var rb := b.begins_with("stamm_")
		if ra != rb:
			return ra
		return int(Lending.readers[a].get("visits", 0)) > int(Lending.readers[b].get("visits", 0)))
	_box.add_child(make_title("Leseausweise", 26))
	if ids.is_empty():
		_box.add_child(make_label("Noch keine Ausweise – die ersten Gäste kommen bestimmt bald.", 17, style.muted))
		return
	for id: String in ids:
		_box.add_child(_row(id, Lending.readers[id]))


func _row(id: String, info: Dictionary) -> Control:
	var panel := make_panel(12.0)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	panel.add_child(line)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	line.add_child(text)
	text.add_child(make_title(str(info.get("name", "")), 21))
	var details := "Besuche: %d" % int(info.get("visits", 0))
	if int(info.get("full", 0)) > 0:
		details += "  ·  volle Karten: %d" % int(info.get("full", 0))
	if id.begins_with("stamm_"):
		details += "  ·  Stammgast"
	text.add_child(make_label(details, 15, style.muted))
	var stamps := _StampRow.new()
	stamps.stamps = int(info.get("stamps", 0))
	stamps.regular = id.begins_with("stamm_")
	stamps.hearts = mini(5, int(ceil(int(info.get("friendship", 0)) / 2.0))) if stamps.regular else 0
	stamps.ink = style.muted
	stamps.stamp = style.second
	line.add_child(stamps)
	return panel


## Herzen (Freundschaft) und die Stempelkarte als Reihe kleiner Kreise.
class _StampRow extends Control:
	var stamps := 0
	var hearts := 0
	var regular := false  # nur Stammgäste haben Herzen (Freundschaft)
	var ink := Color(0.4, 0.4, 0.4)
	var stamp := Color(0.86, 0.45, 0.48)

	func _init() -> void:
		custom_minimum_size = Vector2(5 * 14 + GameConfig.stamp_card_size * 22 + 20, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y / 2.0
		for h in (5 if regular else 0):
			var c := Vector2(8 + h * 14, y)
			if h < hearts:
				SoftShapes.heart(self, c, 5.5, stamp)
			else:
				SoftShapes.heart(self, c, 5.5, Color(ink, 0.18))
		var x0 := 5 * 14 + 20.0
		for k in GameConfig.stamp_card_size:
			var c := Vector2(x0 + k * 22, y)
			if k < stamps:
				draw_circle(c, 8.0, stamp)
				SoftShapes.heart(self, c + Vector2(0, -1), 3.6, Color(1, 0.96, 0.94))
			else:
				draw_arc(c, 8.0, 0.0, TAU, 20, Color(ink, 0.45), 1.6, true)
