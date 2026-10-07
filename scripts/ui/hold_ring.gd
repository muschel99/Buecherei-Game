class_name HoldRing
extends Control
## Kleiner Ring um die Bildmitte, der sich füllt, solange E gehalten wird.

const RADIUS := 13.0
const WIDTH := 3.0

## Fortschritt von 0 bis 1 (kleiner als 0 = unsichtbar).
var progress: float = -1.0:
	set(value):
		progress = value
		visible = value >= 0.0
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	if progress < 0.0:
		return
	var center := size / 2.0
	draw_arc(center, RADIUS, 0.0, TAU, 40, Color(0, 0, 0, 0.3), WIDTH + 1.0, true)
	draw_arc(center, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, Color(1.0, 0.92, 0.72), WIDTH, true)
