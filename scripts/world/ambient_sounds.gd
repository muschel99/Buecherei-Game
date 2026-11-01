class_name AmbientSounds
extends Node3D
## Ruhige Geräuschkulisse draußen (seit Etappe 6e): Vögel zwitschern ab und zu an Dachkanten, in Blumenkästen,
## Ampeln und Bäumen in der Nähe der Spielfigur (ein- bis dreimal, jede Variante leicht anders); aus dem
## Garten hinter der Gasse und aus der kleinen Gasse gegenüber miaut oder schnattert gelegentlich eine Katze.
## Alles räumlich (Audio-System, Lautstärke „Umgebung“; Dateien ambience/bird_*, cat_meow_*, cat_chatter_*).
## Wird von main.gd unter „Outside“ angelegt; Zeiten und Lautstärken in GameConfig (bird_*, cat_*).

## Bis zu so vielen Pflanzplätzen als Vogel-Plätze (zufällig ausgewählt)
const MAX_PLANT_SPOTS := 160

var _bird_spots: Array[Vector3] = []
var _cat_spots: Array[Vector3] = []
var _bird_timer := 2.0
var _cat_timer := 20.0


func _ready() -> void:
	_bird_timer = randf_range(1.0, GameConfig.bird_interval.y)
	_cat_timer = randf_range(GameConfig.cat_interval.x * 0.4, GameConfig.cat_interval.y)
	# erst sammeln, wenn alle Häuser und Pflanzen stehen
	call_deferred("_collect")


func _collect() -> void:
	var outside := get_parent()
	if outside == null:
		return
	# Dachkanten der Häuser (vorn an der Traufe, irgendwo über die Breite)
	for house: Node in outside.find_children("*", "HouseFacade", true, false):
		var node := house as Node3D
		var w := float(house.get("width"))
		var eaves := float(house.get("eaves_height"))
		for k in 2:
			_bird_spots.append(node.to_global(Vector3(randf_range(-w * 0.35, w * 0.35), eaves + 0.25, 0.15)))
	# Pflanzen: Blumenkästen, Ampeln, Töpfe, Bäume (leere Knoten „PlantSpot_…“ in den Modellen)
	var plants := outside.find_children(Greenery.SPOT_PREFIX + "*", "", true, false)
	plants.shuffle()
	for spot in plants.slice(0, MAX_PLANT_SPOTS):
		_bird_spots.append((spot as Node3D).global_position + Vector3.UP * 0.4)
	# Katzen: im Garten (Bank unter dem Baum) und hinten in der Gasse gegenüber
	for seat in get_tree().get_nodes_in_group(StreetLife.SEAT_GROUP):
		if not seat is StreetSeat:
			_cat_spots.append((seat as Node3D).global_position + Vector3(0.0, 0.3, 0.0))
			break
	var opposite := outside.get_node_or_null("OppositeAlley") as Node3D
	if opposite:
		var end := opposite.find_child("AlleyEnd*", true, false) as Node3D
		_cat_spots.append((end.global_position if end else opposite.global_position) + Vector3.UP * 0.4)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var listener := camera.global_position
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = randf_range(GameConfig.bird_interval.x, GameConfig.bird_interval.y)
		_bird(listener)
	_cat_timer -= delta
	if _cat_timer <= 0.0:
		_cat_timer = randf_range(GameConfig.cat_interval.x, GameConfig.cat_interval.y)
		_cat(listener)


## Ein Vogel in passender Entfernung: ein- bis dreimal hintereinander.
func _bird(listener: Vector3) -> void:
	var near: Array[Vector3] = []
	for p in _bird_spots:
		var d := p.distance_to(listener)
		if d >= GameConfig.bird_distance.x and d <= GameConfig.bird_distance.y:
			near.append(p)
	if near.is_empty():
		return
	var where: Vector3 = near[randi() % near.size()]
	var pitch := randf_range(0.94, 1.12)
	var count := 1 + int(randf() < 0.45) + int(randf() < 0.2)
	for k in count:
		if k > 0:
			await get_tree().create_timer(randf_range(0.25, 0.7)).timeout
		Audio.play_at("ambience/bird", where, GameConfig.bird_volume_db, pitch * randf_range(0.97, 1.03))


func _cat(listener: Vector3) -> void:
	for p in _cat_spots:
		if p.distance_to(listener) < 30.0:
			var sound := "ambience/cat_meow" if randf() < 0.6 else "ambience/cat_chatter"
			Audio.play_at(sound, p, GameConfig.cat_volume_db, randf_range(0.92, 1.08))
			return
