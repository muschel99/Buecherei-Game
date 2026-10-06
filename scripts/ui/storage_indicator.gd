class_name StorageIndicator
extends CanvasLayer
## Lager-Anzeige unten rechts: zeigt beiläufig, dass etwas ins Lager (Inventar) geht.
##
## Ablauf für jedes Ding: Über dem kleinen Lager-Symbol ploppt sein Bild mit einem "+" auf,
## rutscht ein kurzes Stück nach unten ins Lager, und das Lager-Symbol federt kurz auf wie
## eine kleine Blase. Danach blendet das Lager-Symbol nach ein paar Sekunden sanft aus.
## Kommen mehrere Dinge kurz hintereinander, stehen sie in einer Warteschlange und erscheinen
## nacheinander (Abstand GameConfig.storage_icon_interval). Das Spiel wartet nie darauf.
##
## Von überall aus aufrufen (wiederverwendbar, z. B. später auch für Bücher):
##   StorageIndicator.add_item(self, datenblatt)   # FurnitureData oder SurfaceData
##   StorageIndicator.add_icon(self, bild)         # ein beliebiges Texture2D
## Die Bilder der Möbel entstehen automatisch aus den 3D-Modellen (ThumbnailRenderer) und
## werden zwischengespeichert; Wandfarben und Böden bekommen ein Farbfeld.

const GROUP := "storage_indicator"
## Größe des Objekt-Symbols und wie weit es nach unten ins Lager rutscht (in Pixeln)
const ICON_SIZE := 50.0
const SLIDE_DISTANCE := 52.0
## Anteile der Animation an GameConfig.storage_icon_interval (Aufploppen, Halten, Rutschen)
const POP_SHARE := 0.32
const HOLD_SHARE := 0.22
const SLIDE_SHARE := 0.42
## So weit federt das Lager-Symbol beim Ankommen auf
const BOUNCE_SCALE := 1.16
const FADE_TIME := 0.35

## Das Lager-Symbol (austauschbar, z. B. durch eine eigene Grafik).
@export var storage_texture: Texture2D

@onready var _storage: Control = %Storage
@onready var _items: Control = %Items

## Wie viele Dinge im Lager angekommen sind, seit das Spiel läuft (für Tests).
var arrived_count: int = 0

var _queue: Array = []  # Datenblätter oder Bilder
var _running := false
var _thumbnails: ThumbnailRenderer
var _fade_tween: Tween
var _bounce_tween: Tween
static var _swatches := {}  # Oberflächen-id -> Farbfeld


## Meldet ein Ding, das ins Lager geht (FurnitureData oder SurfaceData).
static func add_item(sender: Node, item: Resource, count: int = 1) -> void:
	for i in count:
		sender.get_tree().call_group(GROUP, "enqueue", item)


## Meldet ein Ding mit eigenem Bild.
static func add_icon(sender: Node, texture: Texture2D) -> void:
	sender.get_tree().call_group(GROUP, "enqueue", texture)


func _ready() -> void:
	add_to_group(GROUP)
	_thumbnails = ThumbnailRenderer.new()
	_thumbnails.name = "Thumbnails"
	add_child(_thumbnails)
	(%StorageIcon as TextureRect).texture = storage_texture
	_storage.modulate.a = 0.0
	_storage.pivot_offset = _storage.size / 2.0


## Wie viele Dinge noch in der Warteschlange stehen.
func get_queue_size() -> int:
	return _queue.size()


func enqueue(entry: Variant) -> void:
	_queue.append(entry)
	if not _running:
		_run_queue()


## Arbeitet die Warteschlange ab: ein Symbol nach dem anderen, mit festem Abstand.
func _run_queue() -> void:
	_running = true
	_fade_storage(1.0, 0.0)
	while not _queue.is_empty():
		var entry: Variant = _queue.pop_front()
		var texture := await _icon_for(entry)
		_animate_item(texture)
		await get_tree().create_timer(GameConfig.storage_icon_interval, false).timeout
	_running = false


## Das Bild zu einem Eintrag (wartet, falls das Foto des Modells noch entsteht).
func _icon_for(entry: Variant) -> Texture2D:
	if entry is Texture2D:
		return entry
	if entry is SurfaceData:
		return _swatch(entry)
	if entry is FurnitureData:
		var ready_image := ThumbnailRenderer.get_cached(entry)
		if ready_image:
			return ready_image
		var result: Array = [null]
		_thumbnails.request(entry, func(texture: Texture2D) -> void: result[0] = texture)
		var waited := 0.0
		while result[0] == null and waited < 2.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		return result[0]
	return null


## Kleines Farbfeld für Wandfarben, Böden und Decken (einmal erzeugt, dann gemerkt).
func _swatch(surface: SurfaceData) -> Texture2D:
	var id := surface.get_id()
	if not _swatches.has(id):
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		image.fill(surface.preview_color)
		_swatches[id] = ImageTexture.create_from_image(image)
	return _swatches[id]


## Ein Symbol ploppt über dem Lager auf, rutscht hinein, das Lager federt kurz.
func _animate_item(texture: Texture2D) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(ICON_SIZE, ICON_SIZE)
	holder.pivot_offset = holder.size / 2.0
	var center_x := _storage.position.x + _storage.size.x / 2.0
	var end_y := _storage.position.y + _storage.size.y / 2.0 - ICON_SIZE / 2.0
	holder.position = Vector2(center_x - ICON_SIZE / 2.0, end_y - SLIDE_DISTANCE)
	_items.add_child(holder)

	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon)
	var plus := Label.new()
	plus.text = "+"
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plus.add_theme_font_size_override("font_size", 18)
	plus.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	plus.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	plus.position = Vector2(-6, 0)
	holder.add_child(plus)

	var interval := GameConfig.storage_icon_interval
	holder.scale = Vector2.ONE * 0.3
	holder.modulate.a = 0.0
	_fade_storage(1.0, 0.0)  # falls das Lager gerade ausblenden wollte
	# Abschnitte nacheinander (chain), innerhalb eines Abschnitts gleichzeitig (parallel)
	var tween := holder.create_tween().set_parallel()
	# Aufploppen
	tween.tween_property(holder, "scale", Vector2.ONE, interval * POP_SHARE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "modulate:a", 1.0, interval * POP_SHARE * 0.7)
	# kurz halten, dann ein kurzes Stück nach unten ins Lager rutschen
	tween.chain().tween_interval(interval * HOLD_SHARE)
	var slide := interval * SLIDE_SHARE
	tween.chain().tween_property(holder, "position:y", end_y, slide).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(holder, "scale", Vector2.ONE * 0.5, slide).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(holder, "modulate:a", 0.0, slide * 0.5).set_delay(slide * 0.5)
	tween.chain().tween_callback(_on_item_arrived.bind(holder))


## Angekommen: Lager-Symbol federt kurz auf; später sanft ausblenden.
func _on_item_arrived(holder: Control) -> void:
	holder.queue_free()
	arrived_count += 1
	if _bounce_tween:
		_bounce_tween.kill()
	_storage.scale = Vector2.ONE
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_storage, "scale", Vector2.ONE * BOUNCE_SCALE, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_storage, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Ist nichts mehr unterwegs, nach einer Weile ausblenden
	if _queue.is_empty() and _items.get_child_count() <= 1:
		_fade_storage(0.0, GameConfig.storage_hide_delay)


## Lager-Symbol ein- oder ausblenden (delay: so lange vorher warten).
func _fade_storage(alpha: float, delay: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	if delay > 0.0:
		_fade_tween.tween_interval(delay)
	_fade_tween.tween_property(_storage, "modulate:a", alpha, FADE_TIME).set_trans(Tween.TRANS_SINE)
