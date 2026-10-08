class_name BookStand
extends Node3D
## Ein Buch-Aufsteller (Deko): hält genau ein Buch, nach hinten geneigt, Cover nach vorn.
##
## Das Buch selbst ist ein ausgelegtes Buch (LooseBooks, Haltung DISPLAYED, support_uid = der
## Aufsteller) – so zählt es zum Bestand ("ausgelegt"), wandert beim Verschieben mit und geht
## beim Wegräumen (X) ins Lager, ganz ohne eigenen Code hier.
## Der Aufsteller sagt nur, wo das Buch liegt: Der Marker "BookSpot" ist die hintere Unterkante
## des Buchs (+Z = nach vorn), lean_angle die Neigung der Stütze. Eigenes Modell: Marker und
## Winkel an die Stütze anpassen.

## Neigung der Stütze nach hinten (Grad, gemessen von der Senkrechten) – passend zum Modell.
@export var lean_angle: float = 20.0

@onready var _spot: Marker3D = $BookSpot


## Der Aufsteller in einem Möbelstück (oder null).
static func find_in(item: Node) -> BookStand:
	if item == null:
		return null
	for node in item.find_children("*", "BookStand", true, false):
		return node as BookStand
	return null


## Lage eines Buchs dieser Größe im Aufsteller (in der Welt, Basis mit Buchgröße – wie bei
## ausgelegten Büchern: x = Dicke/Cover, y = Höhe, z = Breite).
func get_book_transform(size: Vector3) -> Transform3D:
	var spot := _spot.global_transform
	var forward := spot.basis.z.normalized()
	var up := spot.basis.y.normalized()
	var angle := deg_to_rad(lean_angle)
	var cover := forward * cos(angle) + up * sin(angle)
	var top := up * cos(angle) - forward * sin(angle)
	var side := cover.cross(top).normalized()
	var basis := Basis(cover * size.x, top * size.y, side * size.z)
	# Hintere Unterkante liegt am Marker, die Rückseite an der Stütze
	var origin := spot.origin + top * (size.y / 2.0) + cover * (size.x / 2.0 + 0.001)
	return Transform3D(basis, origin)


## Der feste Körper des Aufstellers (das Buch darf ihn berühren).
func get_body_rid() -> RID:
	var item := FurnitureUtils.find_placed_furniture(self)
	if item == null:
		return RID()
	for node in item.find_children("*", "StaticBody3D", true, false):
		return (node as StaticBody3D).get_rid()
	return RID()
