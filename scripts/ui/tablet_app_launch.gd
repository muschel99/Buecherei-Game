class_name TabletAppLaunch
extends Control
## Öffnen und Schließen einer App auf dem Theken-Tablet (seit Etappe 6b): Die Kachel der App wächst
## weich aus ihrem Symbol auf dem Startbildschirm, bis sie den Bildschirm füllt (grow 0 → 1). Darauf
## erscheinen Logo, Begrüßung („Willkommen bei Nest & Nook“) und ein feiner Ladebalken (greeting,
## loading) – danach blendet das Tablet die App ein. Beim Schließen schrumpft die Kachel zurück.
## Liegt über allem und fängt solange alle Klicks ab. Den Ablauf steuert CounterTablet.

## Größe des Logos, wenn die Kachel den Bildschirm füllt (Pixel)
const LOGO_SIZE := 150.0
## Rundung der kleinen Kachel (wie TabletAppIcon) und des Bildschirms
const TILE_RADIUS := 26.0
const SCREEN_RADIUS := 16.0
const TEXT_COLOR := Color(1.0, 0.97, 0.9)

var app: TabletAppData
## Kachel auf dem Startbildschirm und Bildschirm des Tablets (in eigenen Koordinaten)
var from_rect: Rect2
var to_rect: Rect2
## 0 = so groß wie das Symbol, 1 = füllt den Bildschirm
var grow := 0.0:
	set(value):
		grow = value
		_update_logo()
		queue_redraw()
## Wie deutlich Begrüßung und Ladebalken zu sehen sind (0 bis 1)
var greeting := 0.0:
	set(value):
		greeting = value
		queue_redraw()
## Wie weit der Ladebalken gefüllt ist (0 bis 1)
var loading := 0.0:
	set(value):
		loading = value
		queue_redraw()

var _logo: TabletAppIcon


func setup(data: TabletAppData, tile_rect: Rect2, screen_rect: Rect2) -> void:
	app = data
	from_rect = tile_rect
	to_rect = screen_rect
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_logo = TabletAppIcon.new()
	_logo.compact = true
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_logo.setup(data)
	_update_logo()


## Das Logo gleitet vom Symbol auf dem Startbildschirm in die Mitte (etwas über der Mitte).
func _update_logo() -> void:
	if _logo == null:
		return
	var center := to_rect.get_center() - Vector2(0.0, 46.0)
	var big := Rect2(center - Vector2.ONE * LOGO_SIZE / 2.0, Vector2.ONE * LOGO_SIZE)
	var t := _smooth(grow)
	_logo.position = from_rect.position.lerp(big.position, t)
	_logo.size = from_rect.size.lerp(big.size, t)
	_logo.queue_redraw()


func _draw() -> void:
	if app == null:
		return
	var t := grow
	var rect := Rect2(from_rect.position.lerp(to_rect.position, t), from_rect.size.lerp(to_rect.size, t))
	var box := StyleBoxFlat.new()
	box.bg_color = app.color
	box.set_corner_radius_all(int(lerpf(TILE_RADIUS, SCREEN_RADIUS, t)))
	box.anti_aliasing = true
	draw_style_box(box, rect)
	if greeting <= 0.0:
		return
	# Begrüßung in der Schrift der App, darunter ein feiner Ladebalken
	var style := app.style
	var font: Font = style.get_title_font() if style and style.get_title_font() else get_theme_default_font()
	var welcome := (style.welcome if style else "Willkommen bei %s")
	var text := welcome % app.display_name if welcome.contains("%s") else welcome
	if style:
		text = style.title_text(text)
	var font_size := 30
	var baseline := to_rect.get_center().y + LOGO_SIZE / 2.0 + 10.0
	var color := Color(TEXT_COLOR, greeting)
	draw_string(font, Vector2(to_rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, to_rect.size.x, font_size, color)
	var bar_width := 220.0
	var bar := Rect2(Vector2(to_rect.get_center().x - bar_width / 2.0, baseline + 26.0), Vector2(bar_width, 5.0))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(TEXT_COLOR, 0.22 * greeting)
	track.set_corner_radius_all(3)
	track.anti_aliasing = true
	draw_style_box(track, bar)
	if loading > 0.0:
		var fill := track.duplicate() as StyleBoxFlat
		fill.bg_color = Color(TEXT_COLOR, 0.9 * greeting)
		draw_style_box(fill, Rect2(bar.position, Vector2(maxf(bar.size.x * loading, 5.0), bar.size.y)))


static func _smooth(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
