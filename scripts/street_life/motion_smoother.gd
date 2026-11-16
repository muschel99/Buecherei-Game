class_name MotionSmoother
extends RefCounted
## Weiche Bewegung zwischen den Physik-Schritten (seit der Überarbeitung, gegen Mikroruckler):
## Passanten, Fahrzeuge und Tiere bewegen sich im festen Physik-Takt (60 Schritte pro Sekunde), das Bild
## läuft aber oft schneller (z. B. 110 Bilder pro Sekunde). Ohne Zwischenschritte springt alles, was sich
## bewegt, ungleichmäßig – besonders sichtbar, wenn die Kamera mitgeht (Passanten umkreisen).
##
## So geht's (StreetLife benutzt es):
## - Zu Beginn jedes Physik-Schritts `restore()`: alle bekommen wieder ihre echte Lage (die Spiel-Logik
##   rechnet immer mit der echten Lage).
## - Nach dem Physik-Schritt `capture(knoten)`: merkt sich die vorige und die neue echte Lage.
## - In jedem Bild `apply(anteil)`: zeigt alle zwischen voriger und neuer Lage
##   (anteil = Engine.get_physics_interpolation_fraction()).
## Wer zwischendurch woanders hingesetzt wird (z. B. aus dem Vorrat neu losgeschickt), springt einfach
## (weiter als TELEPORT_DISTANCE pro Schritt oder von außen verändert).

## Weiter als so viele Meter in einem Schritt = Sprung (neuer Start), nicht weich überblenden.
const TELEPORT_DISTANCE := 1.5

## Knoten -> echte Lage beim vorigen bzw. letzten Physik-Schritt (lokale Transform).
var _prev: Dictionary = {}
var _curr: Dictionary = {}
## Knoten -> die Lage, die apply() zuletzt gesetzt hat (um Änderungen von außen zu erkennen).
var _applied: Dictionary = {}


## Vor dem Physik-Schritt: echte Lage zurück (nur, wenn seit apply() niemand sonst etwas verändert hat).
func restore() -> void:
	for node: Node3D in _applied:
		if is_instance_valid(node) and node.transform == _applied[node]:
			node.transform = _curr[node]
	_applied.clear()


## Nach dem Physik-Schritt: neue echte Lage aller übergebenen Knoten merken.
func capture(nodes: Array) -> void:
	var limit := TELEPORT_DISTANCE * TELEPORT_DISTANCE
	var prev := {}
	var curr := {}
	for node: Node3D in nodes:
		if not is_instance_valid(node):
			continue
		var now := node.transform
		var before: Variant = _curr.get(node)
		if before == null or (before as Transform3D).origin.distance_squared_to(now.origin) > limit:
			prev[node] = now
		else:
			prev[node] = before
		curr[node] = now
	_prev = prev
	_curr = curr


## In jedem Bild: zwischen voriger und neuer Lage zeigen (nur sichtbare Knoten).
func apply(fraction: float) -> void:
	fraction = clampf(fraction, 0.0, 1.0)
	for node: Node3D in _curr:
		if not is_instance_valid(node) or not node.visible:
			continue
		var from: Transform3D = _prev[node]
		var to: Transform3D = _curr[node]
		if from == to:
			continue
		# Nur, wenn die Lage noch die echte (oder unsere letzte) ist – sonst hat sie jemand neu gesetzt
		var now := node.transform
		if now != to and not (_applied.has(node) and now == _applied[node]):
			continue
		var shown := from.interpolate_with(to, fraction)
		node.transform = shown
		_applied[node] = shown


## Alles vergessen (z. B. beim Vorspulen im Prüfwerkzeug).
func clear() -> void:
	restore()
	_prev.clear()
	_curr.clear()
