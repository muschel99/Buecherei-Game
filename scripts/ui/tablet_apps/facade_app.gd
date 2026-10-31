extends TabletApp
## App „Fassade“ auf dem Theken-Tablet (seit Etappe 6b neu): Hier gestalte ich die Bücherei außen und
## innen zusammen – Fassade, Pflanzen draußen, Briefkasten und Theke.
##
## - Oben Reiter mit Symbol und einem Wort (PAGES), darunter je Reiter Reihen großer Bild-Kacheln
##   (FacadeTile, Name und Preis im Tooltip; Farbvarianten als Tupfer unter der Kachel).
## - Alles, was ich antippe, landet erst im Entwurf (FacadeDesign.draft) – die echte Fassade bleibt.
##   Neben dem Tablet liegen zwei schräge Polaroids: die Bücherei von gegenüber, live mit dem Entwurf
##   (FacadePreview), und eine drehende Theke bzw. ein Wandstück mit dem Briefkasten außen und innen
##   (TurntablePreview).
## - Unten „Abbrechen“ (Entwurf verwerfen, App schließt) und „Bauen“ mit den Kosten: Erst das baut um
##   (FacadeDesign.build_draft). Der Entwurf bleibt erhalten, wenn ich das Tablet einfach zumache, und
##   wird mit dem Spielstand gespeichert.
##
## Neue Wahl-Möglichkeiten brauchen keinen Code: neue Datenblätter in data/facade/ (FacadeOption),
## data/return_slots/ oder data/counters/. Eine neue Kategorie: in PAGES eine Reihe ergänzen.

## Die Reiter: Kennung, Name, Symbol (CatalogIcons) und die Reihen darauf ([Schlüssel, Überschrift];
## Schlüssel = Kategorie von FacadeDesign oder "slot", "slot_inside", "counter").
const PAGES := [
	{"id": "wall", "name": "Mauer", "icon": "fac_wall", "rows": [["wall", "Mauerwerk"], ["quoins", "Ecksteine"]]},
	{"id": "ground", "name": "Erdgeschoss", "icon": "fac_ground",
		"rows": [["ground", "Verkleidung"], ["ground_color", "Anstrich"], ["window_ground", "Fenster"], ["fascia", "Schild-Balken"]]},
	{"id": "upper", "name": "Obergeschoss", "icon": "fac_upper", "rows": [["window", "Fenster"], ["frame_color", "Rahmen"]]},
	{"id": "door", "name": "Tür", "icon": "fac_door",
		"rows": [["door", "Tür"], ["door_lights", "Fenster an der Tür"], ["door_color", "Türfarbe"]]},
	{"id": "plants", "name": "Pflanzen", "icon": "fac_plants",
		"rows": [["box", "Blumenkästen"], ["basket", "Ampeln"], ["plants", "Mischung"], ["fullness", "Fülle"]]},
	{"id": "outside", "name": "Draußen", "icon": "fac_awning",
		"rows": [["awning", "Markise"], ["fabric", "Stoff"], ["deco", "Deko vor der Tür"]]},
	{"id": "letterbox", "name": "Briefkasten", "icon": "fac_slot", "rows": [["slot", "Einwurf außen"], ["slot_inside", "Innen"]]},
	{"id": "counter", "name": "Theke", "icon": "cat_counter", "rows": [["counter", "Theke"]]},
]
const TILE_SIZE := Vector2(112, 112)
const PLANT_FOLDER := "res://scenes/world/plants/"
## Blickrichtungen für die Fotos der Fassaden-Teile (zum Modell hin gesehen von dort)
const VIEW_DOOR := Vector3(-0.35, 0.12, -1.0)    # Türblatt von der Straße
const VIEW_FRONT := Vector3(0.55, 0.45, 1.0)     # Markise, Kasten, Ampel, Pflanze
## Innen am Briefkasten: die beiden Möglichkeiten
const INSIDE_CHOICES := [["match", "Passend zum Einwurf"], ["neutral", "Neutrale Klappe"]]

var _page := "wall"
var _tabs: HBoxContainer
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _cost_label: Label
var _build_button: Button
var _cancel_button: Button
var _side: Control
var _polaroid_facade: Polaroid
var _polaroid_detail: Polaroid
var _facade_preview: FacadePreview
var _detail_preview: TurntablePreview
var _side_shown := false


func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 6)
	layout.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_scroll.add_child(margin)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 14)
	margin.add_child(_rows)
	layout.add_child(_make_footer())
	FacadeDesign.draft_changed.connect(_on_draft_changed)
	FacadeDesign.unlocks_changed.connect(func() -> void:
		if tablet and tablet.is_open and visible:
			request_refresh())
	Wallet.money_changed.connect(func(_money: int, _change: int) -> void: _update_footer())


## Unten: Kosten, „Abbrechen“ und „Bauen“.
func _make_footer() -> Control:
	var panel := make_panel(10.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	_cost_label = make_label("", 18)
	_cost_label.name = "Cost"
	_cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_cost_label)
	_cancel_button = make_choice_button("Abbrechen", _on_cancel)
	_cancel_button.name = "Cancel"
	_cancel_button.toggle_mode = false
	_cancel_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_cancel_button)
	_build_button = make_primary_button("Bauen", _on_build)
	_build_button.name = "Build"
	_build_button.custom_minimum_size.x = 190
	row.add_child(_build_button)
	return panel


# --- Polaroids neben dem Tablet ---

func get_side_view() -> Control:
	if _side == null:
		_side = Control.new()
		_side.name = "FacadePolaroids"
		_side.set_anchors_preset(Control.PRESET_FULL_RECT)
		_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_facade_preview = FacadePreview.new()
		_side.add_child(_facade_preview)
		_detail_preview = TurntablePreview.new()
		_side.add_child(_detail_preview)
		_polaroid_facade = Polaroid.new()
		_polaroid_facade.name = "PolaroidFacade"
		_polaroid_facade.caption = "Unsere Bücherei"
		_polaroid_facade.texture = _facade_preview.get_texture()
		_polaroid_facade.tilt_degrees = -3.5
		_side.add_child(_polaroid_facade)
		_polaroid_detail = Polaroid.new()
		_polaroid_detail.name = "PolaroidDetail"
		_polaroid_detail.texture = _detail_preview.get_texture()
		_polaroid_detail.tilt_degrees = 4.0
		_polaroid_detail.tape_color = Color(0.62, 0.75, 0.72, 0.75)
		_polaroid_detail.tape_at = 0.74
		_side.add_child(_polaroid_detail)
		_side.resized.connect(_layout_side)
	return _side


func side_view_changed(shown: bool) -> void:
	_side_shown = shown
	if shown:
		_layout_side()
		_update_previews()
	if _facade_preview:
		_facade_preview.set_active(shown)
		_detail_preview.set_active(shown)


## Zwei Polaroids untereinander, leicht überlappend, so groß wie der Platz erlaubt.
func _layout_side() -> void:
	if _side == null:
		return
	var area := _side.size
	var ratio := Polaroid.height_for(1.0)
	var overlap := 0.04
	var width := minf(area.x * 0.9, area.y / (ratio * 2.0 - overlap))
	var height := width * ratio
	_polaroid_facade.size = Vector2(width, height)
	_polaroid_facade.position = Vector2((area.x - width) / 2.0 - area.x * 0.02, (area.y - height * (2.0 - overlap)) / 2.0)
	_polaroid_detail.size = Vector2(width, height)
	_polaroid_detail.position = Vector2((area.x - width) / 2.0 + area.x * 0.03, _polaroid_facade.position.y + height * (1.0 - overlap))


func _update_previews() -> void:
	if _facade_preview == null or not _side_shown:
		return
	var design := FacadeDesign.get_draft()
	_facade_preview.show_design(design)
	if _page == "counter":
		_polaroid_detail.caption = "Theke"
		_detail_preview.show_counter(Catalog.get_counter(str(design.get("counter", ""))))
	else:
		_polaroid_detail.caption = "Briefkasten"
		var slot := Catalog.get_return_slot(str(design.get("slot", "")))
		_detail_preview.show_letterbox(slot, ReturnBox.inside_path_for(slot, str(design.get("slot_inside", "match"))),
			TurntablePreview.outside_material_for(design))


# --- App ---

func app_opened() -> void:
	# Die Umgebung (Laden, Straße) einmal je Öffnen in die Vorschau kopieren
	get_side_view()
	var room := get_tree().root.find_child("GroundFloorRoom", true, false) as Node3D
	if room:
		_facade_preview.capture(room)


func _on_draft_changed() -> void:
	_update_previews()
	# Nur, solange die App offen ist (beim Öffnen baut sie sich ohnehin neu auf)
	if tablet and tablet.is_open and visible:
		request_refresh()


func refresh() -> void:
	_build_tabs()
	var scroll := _scroll.scroll_vertical
	clear(_rows)
	for page: Dictionary in PAGES:
		if page.id == _page:
			for row: Array in page.rows:
				_build_row(row[0], row[1])
	_scroll.set_deferred("scroll_vertical", scroll)
	_update_footer()
	_update_previews()


## Einen Reiter wählen (id aus PAGES).
func show_page(id: String) -> void:
	if id == _page:
		return
	_page = id
	_scroll.scroll_vertical = 0
	request_refresh()


func _build_tabs() -> void:
	clear(_tabs)
	for page: Dictionary in PAGES:
		var tab := _PageTab.new()
		tab.name = page.id
		tab.icon_key = page.icon
		tab.word = page.name
		tab.selected = page.id == _page
		tab.colors(style)
		tab.pressed.connect(show_page.bind(page.id))
		_tabs.add_child(tab)


func _update_footer() -> void:
	if _build_button == null:
		return
	var changes := FacadeDesign.has_changes()
	var cost := FacadeDesign.get_draft_cost()
	var affordable := Wallet.can_afford(cost)
	if not changes:
		_cost_label.text = "So steht die Bücherei gerade da."
		_cost_label.add_theme_color_override("font_color", style.muted)
	else:
		_cost_label.text = "Umbau: " + Wallet.format(cost)
		_cost_label.add_theme_color_override("font_color", style.text if affordable else style.second)
	_build_button.text = "Bauen" if cost <= 0 else "Bauen · " + Wallet.format(cost)
	_build_button.disabled = not changes or not affordable
	_build_button.tooltip_text = "" if affordable else "Dafür reicht das Geld noch nicht."


func _on_build() -> void:
	if FacadeDesign.build_draft():
		if _polaroid_facade:
			_polaroid_facade.flash()
	request_refresh()


## Abbrechen: Entwurf verwerfen – nichts ändert sich – und die App schließen.
func _on_cancel() -> void:
	FacadeDesign.clear_draft()
	if tablet:
		tablet.close_app()


# --- Reihen und Kacheln ---

## Eine Reihe: Überschrift mit dem Namen der aktuellen Wahl, darunter die Kacheln.
func _build_row(key: String, title: String) -> void:
	var design := FacadeDesign.get_draft()
	var chosen := str(design.get(key, ""))
	var entries := _entries(key, design)
	if entries.is_empty():
		return
	var box := VBoxContainer.new()
	box.name = key
	box.add_theme_constant_override("separation", 6)
	_rows.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var title_label := make_title(title, 16)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(title_label)
	var chosen_name := ""
	for entry: Dictionary in entries:
		for dot: Array in entry.dots:
			if dot[0] == chosen:
				chosen_name = dot[2]
		if entry.id == chosen and chosen_name.is_empty():
			chosen_name = entry.name
	var name_label := make_label(chosen_name, 16, style.muted)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(name_label)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	box.add_child(flow)
	for entry: Dictionary in entries:
		var tile := FacadeTile.new()
		tile.name = entry.id
		tile.kind = entry.kind
		tile.color = entry.get("color", Color.WHITE)
		tile.material_sample = entry.get("material")
		tile.amount = entry.get("amount", 1.0)
		tile.variant = entry.get("variant", "")
		tile.window = entry.get("window")
		tile.weather = entry.get("weather", 0.0)
		tile.round_top = entry.get("round", false)
		tile.quoin_sample = entry.get("quoin")
		tile.locked = entry.get("locked", false)
		tile.dots = entry.dots
		tile.selected = entry.ids.has(chosen)
		tile.dot_selected = chosen
		tile.tooltip_text = entry.name if entry.price <= 0 else "%s · %s" % [entry.name, Wallet.format(entry.price)]
		if tile.locked:
			tile.tooltip_text = entry.name + " · noch gesperrt"
		tile.setup(style, TILE_SIZE)
		if not tile.selected and not tile.locked:
			tile.pressed.connect(_choose.bind(key, entry.id))
		tile.dot_chosen.connect(func(id: String) -> void: _choose(key, id))
		if entry.has("picture"):
			(entry.picture as Callable).call(tile)
		flow.add_child(tile)


func _choose(key: String, id: String) -> void:
	FacadeDesign.set_draft_value(key, id)


## Die Kacheln einer Reihe: je [id (beim Antippen), ids (alle, die dazugehören), name, price, kind, dots,
## dazu color/material/amount bzw. picture = Callable(tile), die das Foto bestellt].
func _entries(key: String, design: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match key:
		"slot":
			for slot in Catalog.get_all_return_slots():
				var id := slot.get_id()
				result.append(_entry(id, slot.display_name, slot.price, func(tile: FacadeTile) -> void:
					_photo(tile, "return_slot/" + id, func() -> Node3D: return _with_wall(slot.scene_path, 0.0, 0.5, 0.36), Vector3(0.3, 0.2, 1.0))))
		"slot_inside":
			var slot := Catalog.get_return_slot(str(design.get("slot", "")))
			for choice: Array in INSIDE_CHOICES:
				var path := ReturnBox.inside_path_for(slot, choice[0])
				result.append(_entry(choice[0], choice[1], 0, func(tile: FacadeTile) -> void:
					_photo(tile, "return_inside/" + path, func() -> Node3D: return _with_wall(path, 0.95, 0.62, 0.62), Vector3(0.3, 0.2, 1.0))))
		"counter":
			for counter in CounterStyle.get_all_styles():
				var id := counter.get_id()
				result.append(_entry(id, counter.display_name, counter.price, func(tile: FacadeTile) -> void:
					_photo(tile, "counter/" + id, func() -> Node3D: return _instance(counter.scene_path), ThumbnailRenderer.VIEW_DIRECTION)))
		_:
			result = _facade_entries(key, str(design.get(key, "")))
	return result


func _entry(id: String, title: String, price: int, picture: Callable) -> Dictionary:
	return {"id": id, "ids": [id], "name": title, "price": price, "kind": FacadeTile.Kind.PHOTO, "dots": [], "picture": picture}


## Kacheln einer Fassaden-Kategorie; Optionen derselben Gruppe (z. B. Geranien) teilen sich eine Kachel
## mit Farbtupfern.
func _facade_entries(category: String, chosen: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var groups := {}  # Gruppe -> Eintrag
	for option in Catalog.get_facade_options(category):
		var entry: Dictionary
		if not option.group.is_empty() and groups.has(option.group):
			entry = groups[option.group]
			entry.ids.append(option.id)
			entry.dots.append([option.id, option.get_swatch(), option.display_name])
			if option.id == chosen:
				entry.id = option.id
			continue
		entry = {"id": option.id, "ids": [option.id], "name": option.display_name.get_slice(" · ", 0), "price": option.price,
			"dots": [[option.id, option.get_swatch(), option.display_name]], "locked": not FacadeDesign.is_unlocked(option)}
		_describe_picture(entry, option, category)
		result.append(entry)
		if not option.group.is_empty():
			groups[option.group] = entry
	return result


## Wie die Kachel einer Option aussieht: Probe, Farbe oder Foto.
func _describe_picture(entry: Dictionary, option: FacadeOption, category: String) -> void:
	entry.kind = FacadeTile.Kind.PHOTO
	var draft := FacadeDesign.get_draft()
	if category in ["window_ground", "window"]:
		# Fensterform gezeichnet (Umriss, Rahmen, Sprossen, Erker) in der Rahmenfarbe des Entwurfs
		entry.kind = FacadeTile.Kind.WINDOW
		entry.window = option
		var frame := FacadeDesign.get_option("ground_color" if category == "window_ground" else "frame_color", draft)
		entry.color = frame.color if frame else Color(0.9, 0.86, 0.76)
		entry.material = _wall_sample(draft)
	elif category == "door_lights":
		entry.kind = FacadeTile.Kind.DOOR_LIGHTS
		entry.window = option
		var door_color := FacadeDesign.get_option("door_color", draft)
		entry.color = door_color.color if door_color else Color(0.24, 0.33, 0.27)
		entry.round = FacadeDesign.get_option("door", draft) != null and FacadeDesign.get_option("door", draft).shape == "arch"
	elif category == "quoins":
		entry.kind = FacadeTile.Kind.QUOINS
		entry.material = _wall_sample(draft)
		entry.quoin = option.material
	elif option.material:
		entry.kind = FacadeTile.Kind.MATERIAL
		entry.material = option.material
		entry.weather = option.weather
	elif category == "ground" and option.family == "wood":
		# Holzfronten gezeichnet, im Anstrich des Entwurfs (Fotos wären dunkel und kaum zu unterscheiden)
		entry.kind = FacadeTile.Kind.SHOPFRONT
		entry.variant = option.id
		var paint := FacadeDesign.get_option("ground_color", draft)
		entry.color = paint.color if paint else Color(0.13, 0.25, 0.18)
	elif category == "ground":
		# „Mauerwerk wie oben“: Probe der gewählten Wand
		entry.kind = FacadeTile.Kind.MATERIAL
		entry.material = _wall_sample(draft)
	elif category in ["ground_color", "frame_color", "door_color", "fascia"]:
		entry.kind = {"ground_color": FacadeTile.Kind.PAINT, "frame_color": FacadeTile.Kind.FRAME,
			"door_color": FacadeTile.Kind.DOOR, "fascia": FacadeTile.Kind.FASCIA}[category]
		entry.color = option.color
		entry.weather = option.weather
	elif category == "plants":
		# Pflanzenmischung: ein paar ihrer Pflanzen nebeneinander fotografiert
		var picks: Array = Array(option.plants).slice(0, 4)
		entry.picture = func(tile: FacadeTile) -> void:
			_photo(tile, "facade_mix/" + option.id, func() -> Node3D: return _plant_row(picks), VIEW_FRONT)
	elif category == "fullness":
		entry.kind = FacadeTile.Kind.FULLNESS
		entry.amount = option.amount
	elif option.scene_path.is_empty():
		entry.kind = FacadeTile.Kind.NONE
	else:
		var view := VIEW_DOOR if category == "door" else VIEW_FRONT
		var path := option.scene_path
		var key := "facade/" + category + "_" + option.id
		var fabric: FacadeOption = null
		if category == "awning":
			# Markisen gleich im gewählten Stoff
			fabric = FacadeDesign.get_option("fabric", FacadeDesign.get_draft())
			key += "_" + (fabric.id if fabric else "")
		entry.picture = func(tile: FacadeTile) -> void:
			_photo(tile, key, func() -> Node3D: return _with_fabric(_instance(path), fabric), view)


## Material der Wand im Entwurf (für Proben auf den Kacheln).
static func _wall_sample(draft: Dictionary) -> Material:
	var wall := FacadeDesign.get_option("wall", draft)
	return wall.material if wall else null


## Ein paar Pflanzen einer Mischung nebeneinander (für das Foto der Kachel).
static func _plant_row(ids: Array) -> Node3D:
	var root := Node3D.new()
	for i in ids.size():
		var piece := _instance(PLANT_FOLDER + String(ids[i]) + ".tscn")
		if piece is PlantPiece:
			var s := 0.28 / maxf((piece as PlantPiece).nominal_size.x, 0.05)
			piece.scale = Vector3.ONE * s
		piece.position = Vector3((i - (ids.size() - 1) / 2.0) * 0.24, 0.0, (i % 2) * 0.06)
		root.add_child(piece)
	return root


## Bestellt ein Foto für eine Kachel (zwischengespeichert unter key).
func _photo(tile: FacadeTile, key: String, make_model: Callable, view: Vector3) -> void:
	if tablet == null or tablet.thumbnails == null:
		return
	var tile_ref: WeakRef = weakref(tile)
	tablet.thumbnails.request_model(key, make_model, func(texture: Texture2D) -> void:
		var target := tile_ref.get_ref() as FacadeTile
		if target:
			target.texture = texture, view)


## Wie _photo, aber aus einem festen Blickpunkt (Koordinaten des Modells).
func _photo_view(tile: FacadeTile, key: String, make_model: Callable, eye: Vector3, target: Vector3) -> void:
	if tablet == null or tablet.thumbnails == null:
		return
	var tile_ref: WeakRef = weakref(tile)
	tablet.thumbnails.request_view(key, make_model, func(texture: Texture2D) -> void:
		var target_tile := tile_ref.get_ref() as FacadeTile
		if target_tile:
			target_tile.texture = texture, eye, target, 45.0)


static func _instance(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return Node3D.new()
	return (load(path) as PackedScene).instantiate() as Node3D


## Markisenstoff (Fläche „facade_awning“) durch den gewählten Stoff ersetzen.
static func _with_fabric(model: Node3D, fabric: FacadeOption) -> Node3D:
	if fabric == null or fabric.material == null:
		return model
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(i)
			if material and material.resource_name == "facade_awning":
				mesh_instance.set_surface_override_material(i, fabric.material)
	return model


## Ein Modell vor einem Stück Hauswand (Briefkasten außen bzw. innen), Wand um die Höhe y.
static func _with_wall(path: String, y: float, width: float, height: float) -> Node3D:
	var root := Node3D.new()
	root.add_child(_instance(path))
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, 0.04)
	wall.mesh = box
	wall.material_override = load(ThumbnailRenderer.WALL_MATERIAL)
	wall.position = Vector3(0.0, y, -0.02)
	root.add_child(wall)
	return root


## Ein Reiter oben: Symbol mit einem Wort darunter, der gewählte in der Akzentfarbe.
class _PageTab:
	extends Button
	var icon_key := ""
	var word := ""
	var selected := false
	var _text_color := Color.WHITE
	var _accent := Color.WHITE
	var _accent_text := Color.BLACK
	var _font: Font

	func colors(app_style: TabletAppStyle) -> void:
		_text_color = app_style.text
		_accent = app_style.accent
		_accent_text = app_style.accent_text
		_font = app_style.font
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(118, 78)
		tooltip_text = word
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.set_corner_radius_all(maxi(app_style.button_radius, 6))
			box.anti_aliasing = true
			box.bg_color = _accent if selected else (Color(app_style.panel, 0.9) if state.begins_with("hover") else Color(0, 0, 0, 0))
			if state == "focus":
				box.draw_center = false
			add_theme_stylebox_override(state, box)

	func _draw() -> void:
		var color := _accent_text if selected else _text_color
		var icon_size := 34.0
		CatalogIcons.draw(self, icon_key, Rect2(Vector2((size.x - icon_size) / 2.0, 8.0), Vector2(icon_size, icon_size)), color)
		var font: Font = _font if _font else get_theme_default_font()
		draw_string(font, Vector2(0.0, size.y - 12.0), word, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, color)
