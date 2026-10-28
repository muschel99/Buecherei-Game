class_name CounterTablet
extends CanvasLayer
## Das Tablet auf der Theke (E am Tablet): ein echtes kleines Tablet mit Startbildschirm und Apps,
## in derselben Gestaltung wie das Regal-Menü (TabletFrame).
##
## - Oben eine schmale Leiste: links das Home-Symbol (in einer App), das kleine Logo und der
##   Name der App (bei Läden der Ladenname mit kurzem Untertitel), rechts dezent der Kontostand
##   und das Kreuz zum Schließen.
## - Startbildschirm: große App-Symbole mit Namen auf ruhigem Hintergrund (TabletWallpaper).
##   Ein Klick öffnet die App, das Home-Symbol führt zurück.
## - Esc und das Kreuz schließen immer das ganze Tablet (Esc-Regel über MenuStack). Beim
##   nächsten Öffnen startet es wieder auf dem Startbildschirm.
## - Apps sind eigene kleine Szenen mit Datenblatt (data/tablet_apps/*.tres, TabletAppData);
##   neue App = neue Szene + Datenblatt, der Startbildschirm findet sie von selbst.
## - Seit Etappe 6b hat jede App ihren eigenen Look (TabletAppData.style): Das Tablet malt den
##   Bildschirm in ihrer Farbe und ihrem Muster und färbt die Leiste. Tippt man ein Symbol an,
##   wächst es weich zum ganzen Bildschirm, zeigt kurz Logo und Begrüßung (TabletAppLaunch) und
##   öffnet dann die App; Home, Kreuz und Esc lassen sie zurück zum Symbol schrumpfen.
##   open_app(id) öffnet ohne Animation (Tests, andere Stellen im Spiel).
## Solange das Tablet offen ist, ist der Mauszeiger sichtbar und die Spielfigur steht still.

const GROUP := "counter_tablet"
const APPS_FOLDER := "res://data/tablet_apps/"
## Größe des Tablets (Anteil des Bilds, von der Mitte aus)
const MARGIN_X := 0.06
const MARGIN_Y := 0.06

## Pfad zur Spielfigur (im Inspektor der Hauptszene eingetragen).
@export var player_path: NodePath

@onready var _player: Player = get_node(player_path)

var is_open: bool = false
## Vorschaubilder von Möbeln (gemeinsam für alle Apps).
var thumbnails: ThumbnailRenderer

var _apps: Array[TabletAppData] = []
var _app_nodes: Dictionary = {}  # id -> TabletApp (erst beim ersten Öffnen gebaut)
var _current: TabletApp = null
var _current_id := ""
var _frame: TabletFrame
var _home_button: TabletIconButton
var _app_logo: TabletAppIcon
var _app_title: Label
var _app_tagline: Label
var _money_label: Label
var _home_view: Control
var _app_area: Control
var _close_button: TabletIconButton
var _refresh_queued := false
var _app_icons: Dictionary = {}  # id -> TabletAppIcon auf dem Startbildschirm
## Läuft gerade eine Öffnen- oder Schließen-Animation? (dann zählen keine weiteren Klicks)
var _animating := false


func _ready() -> void:
	add_to_group(GROUP)
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	thumbnails = ThumbnailRenderer.new()
	thumbnails.name = "Thumbnails"
	add_child(thumbnails)
	_apps = load_apps()
	_build()
	hide()
	Wallet.money_changed.connect(func(_money: int, _change: int) -> void: _queue_refresh())
	Inventory.changed.connect(_queue_refresh)
	BookStock.changed.connect(_queue_refresh)


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden (dieser Knoten läuft auch bei Pause weiter)
	visible = is_open and not get_tree().paused


## Alle Apps aus data/tablet_apps/ (eingeschaltet, nach "order" sortiert).
static func load_apps() -> Array[TabletAppData]:
	var result: Array[TabletAppData] = []
	# list_directory funktioniert auch im fertig exportierten Spiel
	for file_name in ResourceLoader.list_directory(APPS_FOLDER):
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var data := load(APPS_FOLDER + file_name) as TabletAppData
			if data and data.is_enabled and not data.scene_path.is_empty():
				result.append(data)
	result.sort_custom(func(a: TabletAppData, b: TabletAppData) -> bool:
		return a.order < b.order if a.order != b.order else a.display_name < b.display_name)
	return result


## Name einer App aus ihrem Datenblatt (z. B. der Ladenname "Nest & Nook" für "furnishing").
static func get_app_name(id: String) -> String:
	for app in load_apps():
		if app.id == id:
			return app.display_name
	return id


func get_apps() -> Array[TabletAppData]:
	return _apps


# --- Öffnen und Schließen ---

## Wird vom Tablet auf der Theke aufgerufen (E). Startet immer auf dem Startbildschirm.
func open_tablet() -> void:
	if is_open:
		return
	is_open = true
	MenuStack.open(self)
	_player.movement_enabled = false
	_player.interaction_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	go_home()
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	MenuStack.close(self)
	_player.movement_enabled = true
	_player.interaction_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Esc (über den MenuStack): schließt immer das ganze Tablet, nicht nur die App (die App schrumpft
## vorher kurz zurück zu ihrem Symbol).
func close_from_escape() -> void:
	_back_to_icon(close)


## Nach dem Pausenmenü: Mauszeiger wieder sichtbar.
func restore_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Startbildschirm und Apps ---

## Zurück zum Startbildschirm.
func go_home() -> void:
	if _current:
		_current.hide()
	_current = null
	_current_id = ""
	_app_area.hide()
	_home_view.show()
	_home_button.hide()
	_app_logo.hide()
	_app_title.text = ""
	_app_tagline.text = ""
	_apply_bar_style(null)


## Ein App-Symbol wurde angetippt: Die Kachel wächst zum ganzen Bildschirm, Logo und Begrüßung
## erscheinen kurz, dann öffnet sich die App (Zeiten in GameConfig).
func launch_app(id: String) -> void:
	var data := _find_app(id)
	var icon: TabletAppIcon = _app_icons.get(id)
	if _animating or data == null or icon == null:
		return
	_animating = true
	var launch := _make_launch(data, icon)
	var tween := create_tween()
	tween.tween_property(launch, "grow", 1.0, GameConfig.tablet_app_zoom_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Hinter der Kachel öffnet sich schon die App
	tween.tween_callback(open_app.bind(id))
	tween.tween_property(launch, "greeting", 1.0, 0.2)
	tween.parallel().tween_property(launch, "loading", 1.0, GameConfig.tablet_app_loading_time)
	tween.tween_property(launch, "modulate:a", 0.0, GameConfig.tablet_app_reveal_time)
	tween.tween_callback(func() -> void:
		launch.queue_free()
		_animating = false)


## Home: Die App schrumpft zurück zu ihrem Symbol.
func _on_home_pressed() -> void:
	_back_to_icon(go_home)


## Die App schrumpft kurz zurück zu ihrem Symbol, danach then (Startbildschirm oder Tablet zu).
## Ohne offene App (oder ohne Symbol) gleich then.
func _back_to_icon(then: Callable) -> void:
	if _animating:
		return
	var data := _find_app(_current_id)
	var icon: TabletAppIcon = _app_icons.get(_current_id)
	if _current == null or data == null or icon == null or not visible:
		then.call()
		return
	_animating = true
	var launch := _make_launch(data, icon)
	launch.grow = 1.0
	launch.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(launch, "modulate:a", 1.0, 0.1)
	tween.tween_callback(go_home)
	tween.tween_property(launch, "grow", 0.0, GameConfig.tablet_app_close_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		launch.queue_free()
		_animating = false
		then.call())


## Die wachsende Kachel liegt über allem (Symbol und Bildschirm in Koordinaten des Tablets).
func _make_launch(data: TabletAppData, icon: TabletAppIcon) -> TabletAppLaunch:
	var launch := TabletAppLaunch.new()
	launch.name = "Launch"
	add_child(launch)
	var screen := _frame.get_screen_rect()
	launch.setup(data, icon.get_tile_rect_in_canvas(), Rect2(_frame.get_global_rect().position + screen.position, screen.size))
	return launch


func _find_app(id: String) -> TabletAppData:
	for app in _apps:
		if app.id == id:
			return app
	return null


## Die Leiste oben im Look der App (null = Standard des Tablets): Schrift, Farben, Knöpfe.
func _apply_bar_style(style: TabletAppStyle) -> void:
	_frame.screen_style = style
	var text := style.text if style else TabletFrame.TEXT_COLOR
	var muted := style.muted if style else TabletFrame.MUTED_COLOR
	var accent := style.accent if style else TabletFrame.KEY_COLOR
	_app_title.add_theme_color_override("font_color", text)
	_app_tagline.add_theme_color_override("font_color", muted)
	_money_label.add_theme_color_override("font_color", accent)
	for label: Label in [_app_tagline, _money_label]:
		if style and style.font:
			label.add_theme_font_override("font", style.font)
		else:
			label.remove_theme_font_override("font")
	if style and style.get_title_font():
		_app_title.add_theme_font_override("font", style.get_title_font())
	else:
		_app_title.remove_theme_font_override("font")
	for button: TabletIconButton in [_home_button, _close_button]:
		button.set_colors(text if style else TabletIconButton.LINE_COLOR, accent if style else TabletIconButton.HOVER_COLOR)


## Öffnet eine App (id aus ihrem Datenblatt). Liefert die App (oder null).
func open_app(id: String) -> TabletApp:
	var data: TabletAppData = null
	for app in _apps:
		if app.id == id:
			data = app
	if data == null:
		return null
	if not _app_nodes.has(id):
		var scene := load(data.scene_path) as PackedScene
		var node := scene.instantiate() if scene else null
		if not node is TabletApp:
			push_warning("Tablet: Die App '%s' hat keine TabletApp-Szene (%s)." % [id, data.scene_path])
			if node:
				node.queue_free()
			return null
		node.tablet = self
		node.apply_style(data.style)  # vor dem Einfügen: die App baut sich darin schon auf
		node.hide()
		_app_area.add_child(node)
		_app_nodes[id] = node
	if _current:
		_current.hide()
	_current = _app_nodes[id]
	_current_id = id
	_home_view.hide()
	_app_area.show()
	_current.show()
	_home_button.show()
	_app_logo.setup(data)
	_app_logo.show()
	_app_title.text = data.style.title_text(data.display_name) if data.style else data.display_name
	_app_tagline.text = data.tagline
	_apply_bar_style(data.style)
	_current.app_opened()
	_current.refresh()
	return _current


func get_current_app_id() -> String:
	return _current_id


# --- Anzeige ---

## Alles neu zeigen – erst am Ende des Bilds (einmal, auch wenn viel auf einmal passiert).
func queue_refresh() -> void:
	_queue_refresh()


func _queue_refresh() -> void:
	if _refresh_queued or not is_open:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_open:
		return
	_money_label.text = Wallet.format(Wallet.money)
	if _current:
		_current.refresh()


## Baut das Tablet aus Containern (passt sich jeder Auflösung an).
func _build() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0.05, 0.03, 0.02, 0.35)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	_frame = TabletFrame.new()
	_frame.name = "Tablet"
	_frame.anchor_left = MARGIN_X
	_frame.anchor_right = 1.0 - MARGIN_X
	_frame.anchor_top = MARGIN_Y
	_frame.anchor_bottom = 1.0 - MARGIN_Y
	add_child(_frame)

	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation", 12)
	_frame.add_child(screen)

	# Schmale Leiste oben
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	screen.add_child(bar)
	_home_button = TabletIconButton.new()
	_home_button.icon_kind = TabletIconButton.Icon.HOME
	_home_button.pressed.connect(_on_home_pressed)
	bar.add_child(_home_button)
	# Kleines Logo der App, Name und (bei Läden) ein kurzer Untertitel
	_app_logo = TabletAppIcon.new()
	_app_logo.compact = true
	_app_logo.custom_minimum_size = Vector2(38, 38)
	_app_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_app_logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_app_logo.hide()
	bar.add_child(_app_logo)
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 12)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(names)
	_app_title = TabletFrame.make_label("", 22, TabletFrame.TEXT_COLOR)
	_app_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_app_title.custom_minimum_size.x = 0
	_app_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_child(_app_title)
	_app_tagline = TabletFrame.make_label("", 16, TabletFrame.MUTED_COLOR)
	_app_tagline.autowrap_mode = TextServer.AUTOWRAP_OFF
	_app_tagline.custom_minimum_size.x = 0
	_app_tagline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_child(_app_tagline)
	_money_label = TabletFrame.make_label("", 17, TabletFrame.KEY_COLOR)
	_money_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_money_label.custom_minimum_size.x = 0
	_money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_money_label)
	_close_button = TabletFrame.make_close_button()
	_close_button.pressed.connect(_back_to_icon.bind(close))
	bar.add_child(_close_button)

	# Startbildschirm
	_home_view = Control.new()
	_home_view.name = "Home"
	_home_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_view.clip_contents = true
	screen.add_child(_home_view)
	var wallpaper := TabletWallpaper.new()
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_home_view.add_child(wallpaper)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_home_view.add_child(center)
	var grid := HFlowContainer.new()
	grid.name = "Apps"
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 24)
	# Bis zu fünf Apps nebeneinander, mehr laufen in die nächste Reihe
	var columns := clampi(_apps.size(), 1, 5)
	grid.custom_minimum_size.x = columns * (TabletAppIcon.TILE_SIZE + 40.0) + (columns - 1) * 36.0
	center.add_child(grid)
	for app in _apps:
		var icon := TabletAppIcon.new()
		icon.name = app.id
		icon.setup(app)
		icon.pressed.connect(launch_app.bind(app.id))
		grid.add_child(icon)
		_app_icons[app.id] = icon

	# Bereich für die geöffnete App
	_app_area = MarginContainer.new()  # die App füllt den ganzen Bereich
	_app_area.name = "AppArea"
	_app_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_app_area.hide()
	screen.add_child(_app_area)
