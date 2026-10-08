class_name LooseBooks
extends Node3D
## Alle Bücher, die in einem Raum frei herumliegen oder -stehen ("ausgelegt"): auf Tischen,
## der Theke, der Fensterbank, Sitzmöbeln, dem Boden … – als Deko oder einfach abgelegt.
##
## - Jeder Raum hat einen solchen Knoten (legt Room selbst an). Alle ausgelegten Bücher des
##   Raums werden in einem einzigen Rutsch gezeichnet (MultiMesh, Shader book_loose.gdshader,
##   Cover aus dem Cover-Atlas von BookArt) – auch viele Bücher belasten den PC kaum.
## - Daten je Buch: LooseBook (Buch, Lage, Möbelstück darunter, Haltung).
## - Wiederverwendbar (z. B. später für Besucher): place(buch, lage, möbel_uid, haltung),
##   remove(eintrag), get_entries(), find_spot(blick_start, richtung, buch).
##
## Bedienung (die Spielfigur meldet Blick und Klicks):
## - Linksklick mit Büchern in der Hand: das Buch obenauf dorthin legen, wo ich hinschaue –
##   flach mit dem Cover nach oben, leicht schräg. Auf ein liegendes Buch: kleiner Stapel.
## - Mausrad: das Buch vorher um die Hochachse drehen (turn_degrees, relativ zur Blickrichtung
##   bzw. zum Buch darunter). Angelehnte Bücher nur ein Stück (GameConfig), aufrecht stehende
##   in Reihen gar nicht (Rücken bleibt vorn).
##   An eine Wand: aufrecht angelehnt (Cover nach vorn). Neben eine Buchstütze oder ein
##   aufrechtes Buch: aufrecht daneben (Rücken nach vorn). Eine halbdurchsichtige Vorschau
##   zeigt vorher, wohin es kommt (rötlich, wenn es dort nicht geht).
## - Rechtsklick auf ein ausgelegtes Buch: wieder in die Hand nehmen.
## - Möbelstück verschoben: Bücher darauf wandern mit (move_with). Weggeräumt (X): Bücher
##   gehen ins Lager (release_on).

## Wird gesendet, wenn Bücher ausgelegt oder weggenommen werden.
signal changed

const GROUP := "loose_book_layers"
## Kleiner Abstand über einer Fläche, damit nichts flimmert (in Metern)
const LIFT := 0.0015
## So groß darf die Lücke zwischen zwei Büchern höchstens sein, damit sie als gestapelt gelten
const STACK_GAP := 0.01
## Bis zu dieser Höhe über der Ablage wird nach Büchern eines Stapels gesucht (in Metern)
const STACK_REACH := 0.6
## Um so viel kleiner (je Seite, in Metern) wird das Buch geprüft, wenn es um andere Objekte
## geht – bloßes Berühren (aufliegen, anlehnen) ist erlaubt, Hineinragen nicht.
const SOLID_MARGIN := 0.003

## Mit dem Mausrad gewählte Drehung (Grad) für das nächste Buch, das ich ablege.
## Gilt relativ zu meiner Blickrichtung (bzw. zum Buch darunter); nach dem Ablegen wieder 0.
var turn_degrees: float = 0.0
var _carried_count := 0  # wie viele Bücher ich zuletzt trug (um Ablegen zu erkennen)

var _entries: Array[LooseBook] = []
var _multimesh: MultiMesh
var _material: ShaderMaterial
var _room: Room
var _interactable: Interactable
var _hover: LooseBook = null
var _solid_box: BoxShape3D
## Wohin das Buch obenauf käme: { "book", "ok", "transform", "support_uid", "pose" } – leer,
## wenn ich auf nichts Passendes schaue.
var _plan: Dictionary = {}
var _ghost: MeshInstance3D
var _ghost_material: ShaderMaterial
var _ghost_shake := -1.0
var _refresh_queued := false
# Die letzte Blicksuche (wird im selben Bild mehrmals gebraucht: Ziel, Hervorheben, Vorschau)
var _pick_cache_key := []
var _pick_cache := {}
# Mittelpunkte aller Bücher (gleiche Reihenfolge wie _entries) – zum schnellen Aussortieren
var _origins := PackedVector3Array()
var _origins_dirty := true


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Player.WORLD_PLACER_GROUP)
	_room = get_parent() as Room
	var instance := MultiMeshInstance3D.new()
	instance.name = "Books"
	_multimesh = BookLook.create_multimesh()
	instance.multimesh = _multimesh
	_material = ShaderMaterial.new()
	_material.shader = load("res://assets/shaders/book_loose.gdshader")
	_material.set_shader_parameter("spine_atlas", BookArt.get_spine_atlas())
	_material.set_shader_parameter("cover_atlas", BookArt.get_cover_atlas())
	_material.set_shader_parameter("cover_grid", Vector2(BookArt.COVER_ATLAS_GRID))
	instance.material_override = _material
	add_child(instance)
	# Ziel für den Blick auf ausgelegte Bücher (ohne Kollisionsform – getroffen wird über
	# pick_distance, siehe Spielfigur)
	_interactable = Interactable.new()
	_interactable.name = "Interactable"
	_interactable.prompt_text = ""
	_interactable.highlight_owner = false
	_interactable.handles_placing = true
	add_child(_interactable)
	_interactable.aimed.connect(_on_aimed)
	_interactable.aim_ended.connect(_on_aim_ended)
	_interactable.take_requested.connect(_on_take_requested)
	_interactable.place_requested.connect(func(_interactor: Node) -> void: place_active_book())
	BookArt.atlas_ready.connect(_queue_refresh)
	BookArt.cover_atlas_changed.connect(_queue_refresh)
	BookStock.carried_changed.connect(_on_carried_changed)
	_carried_count = BookStock.carried.size()
	set_process(false)


# --- Abfragen ---

## Alle ausgelegten Bücher (Einträge mit Lage und Haltung).
func get_entries() -> Array[LooseBook]:
	return _entries


## Alle ausgelegten Exemplare.
func get_books() -> Array[Book]:
	var result: Array[Book] = []
	for entry in _entries:
		result.append(entry.book)
	return result


## Wie viele Bücher dieses Genres liegen hier aus? (für den Bestand)
func count_books(genre_id: String) -> int:
	var count := 0
	for entry in _entries:
		if entry.book.genre_id == genre_id:
			count += 1
	return count


## Das ausgelegte Buch, das gerade angeschaut wird (oder null).
func get_hovered() -> LooseBook:
	return _hover


## Das Ziel für die Spielfigur, wenn sie ein ausgelegtes Buch anschaut.
func get_interactable() -> Interactable:
	return _interactable


## Abstand vom Blickpunkt bis zum ersten ausgelegten Buch auf dem Blickstrahl (INF = keins).
func pick_distance(from: Vector3, direction: Vector3, reach: float) -> float:
	var hit := _pick(from, direction, reach)
	return hit.distance if not hit.is_empty() else INF


# --- Auslegen und wegnehmen (auch für spätere Besucher) ---

## Legt ein Buch aus: Lage in diesem Knoten (= im Raum, mit Buchgröße in der Basis),
## Möbelstück darunter (0 = Boden) und Haltung.
func place(book: Book, local_transform: Transform3D, support_uid: int,
		pose: LooseBook.Pose = LooseBook.Pose.FLAT) -> LooseBook:
	var entry := LooseBook.create(book, local_transform, support_uid, pose)
	_entries.append(entry)
	_origins_dirty = true
	BookArt.retain_cover(book.data)
	_queue_refresh()
	_changed()
	return entry


## Nimmt ein ausgelegtes Buch weg; Bücher, die darauf lagen, rutschen nach. Liefert das Buch.
func remove(entry: LooseBook) -> Book:
	if not _entries.has(entry):
		return null
	_entries.erase(entry)
	_origins_dirty = true  # sofort: _settle_above sucht gleich in der Nähe
	BookArt.release_cover(entry.book.data)
	if entry == _hover:
		_hover = null
		BookInfoCard.hide_card(self)
	_settle_above(entry)
	_check_resting(_nearby(entry.transform.origin))
	_queue_refresh()
	_changed()
	return entry.book


## Wohin ein Buch käme, wenn man vom Punkt "from" in Richtung "direction" schaut (siehe _plan).
## "turn": Drehung um die Hochachse in Grad (wie das Mausrad der Spielfigur).
func find_spot(from: Vector3, direction: Vector3, book: Book, turn: float = 0.0) -> Dictionary:
	var player_turn := turn_degrees
	turn_degrees = turn
	var plan := _compute_plan(from, direction, book)
	turn_degrees = player_turn
	return plan


# --- Mit Möbeln ---

## Ein Möbelstück wurde verschoben (change = neue Lage × alte Lage⁻¹, in der Welt): Bücher auf
## ihm und auf allem, was darauf steht (uids), wandern mit.
func move_with(uids: Array[int], change: Transform3D) -> void:
	var local_change := global_transform.affine_inverse() * change * global_transform
	var moved := false
	var moved_entries: Array[LooseBook] = []
	for entry in _entries:
		if uids.has(entry.support_uid):
			entry.transform = local_change * entry.transform
			moved = true
			moved_entries.append(entry)
	if moved:
		_check_resting(moved_entries)
		_queue_refresh()
		_changed()


## Ein Möbelstück wird weggeräumt: Liefert die Bücher, die darauf lagen (der Aufrufer legt sie
## ins Lager).
func release_on(uids: Array[int]) -> Array[Book]:
	var released: Array[Book] = []
	for entry in _entries.duplicate():
		if uids.has(entry.support_uid):
			released.append(remove(entry))
	return released


## Gestaltungsmodus: Liegt ein ausgelegtes Buch in dieser Form (Kollisionsform eines Möbelstücks,
## Lage in der Welt)? Dann darf das Möbelstück dort nicht hin. Gerechnet wird mit dem Quader
## um die Form herum, an jeder Seite um "margin" (Meter) kleiner – bloßes Berühren ist erlaubt.
func overlaps_shape(shape: Shape3D, shape_transform: Transform3D, margin: float = 0.0) -> bool:
	var box: AABB
	if shape is BoxShape3D:
		box = AABB(-(shape as BoxShape3D).size / 2.0, (shape as BoxShape3D).size)
	else:
		var mesh := shape.get_debug_mesh() if shape else null
		if mesh == null:
			return false
		box = mesh.get_aabb()
	box = box.grow(-margin)
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return false
	var shape_world := Transform3D(shape_transform.basis * Basis.from_scale(box.size),
		shape_transform * box.get_center())
	var reach := (shape_world.basis.x.length() + shape_world.basis.y.length() + shape_world.basis.z.length()) / 2.0 + 0.35
	for entry in _entries:
		if entry.hidden:
			continue
		var world := global_transform * entry.transform
		if world.origin.distance_to(shape_world.origin) > reach:
			continue
		if _boxes_overlap(shape_world, world):
			return true
	return false


## Bücher auf diesen Möbeln aus- bzw. wieder einblenden (während das Möbelstück im
## Gestaltungsmodus getragen wird).
func set_hidden_on(uids: Array[int], hidden: bool) -> void:
	for entry in _entries:
		if uids.has(entry.support_uid):
			entry.hidden = hidden
	_queue_refresh()


# --- Blick und Klicks der Spielfigur ---

## Jedes Bild von der Spielfigur: Soll eine Vorschau zum Ablegen erscheinen (active = ich trage
## Bücher und schaue nicht auf ein Regal)?
func update_world_aim(active: bool, from: Vector3, direction: Vector3) -> void:
	var book := BookStock.get_active_book()
	if not active or book == null:
		_set_plan({})
		return
	_set_plan(_compute_plan(from, direction, book))


## Linksklick: das Buch obenauf dorthin legen, wo die Vorschau ist. Geht es dort nicht,
## schüttelt sich die Vorschau kurz (ohne Text). Liefert true, wenn es geklappt hat.
func place_active_book(_interactor: Node = null) -> bool:
	if _plan.is_empty():
		return false
	if not _plan.ok or _plan.book != BookStock.get_active_book():
		_ghost_shake = 0.0
		set_process(true)
		return false
	var plan := _plan
	_set_plan({})
	var book := BookStock.take_active()
	place(book, plan.transform, plan.support_uid, plan.pose)
	turn_degrees = 0.0  # das nächste Buch beginnt wieder gerade
	return true


## Wirkt das Mausrad gerade (Vorschau flach oder angelehnt)? Für den Hinweis "Drehen".
func can_turn() -> bool:
	return not _plan.is_empty() and _plan.pose in [LooseBook.Pose.FLAT, LooseBook.Pose.OPEN, LooseBook.Pose.LEANING]


## Mausrad: das Buch obenauf vor dem Ablegen drehen (direction +1 / -1). Nur, wenn die
## Vorschau flach liegt oder angelehnt ist – im Regal und in Reihen bleibt der Rücken vorn.
## Liefert true, wenn sich etwas gedreht hat.
func turn_active_book(direction: float) -> bool:
	if _plan.is_empty():
		return false
	var step := GameConfig.book_turn_step * direction
	match _plan.pose:
		LooseBook.Pose.FLAT, LooseBook.Pose.OPEN:
			turn_degrees = fposmod(turn_degrees + step, 360.0)
		LooseBook.Pose.LEANING:
			var limit := GameConfig.loose_book_lean_max_turn
			turn_degrees = fposmod(clampf(_lean_turn() + step, -limit, limit), 360.0)
		_:
			return false
	return true


## Nimmt ein ausgelegtes Buch in die Hand (volle Hände: der Stapel wackelt nur).
func take_book(entry: LooseBook) -> bool:
	if BookStock.is_hand_full():
		BookStock.show_hands_full()
		return false
	var book := remove(entry)
	if book:
		BookStock.carry([book])
	return book != null


## Ein Buch hat die Hand verlassen (frei abgelegt, ins Regal gestellt, ins Lager): Das nächste
## beginnt wieder gerade. (Blättern mit E behält die Drehung.)
func _on_carried_changed() -> void:
	if BookStock.carried.size() < _carried_count:
		turn_degrees = 0.0
	_carried_count = BookStock.carried.size()


func _on_aimed(from: Vector3, direction: Vector3) -> void:
	var hit := _pick(from, direction, GameConfig.interaction_distance)
	_set_hover(hit.get("entry"))


func _on_aim_ended() -> void:
	_set_hover(null)


func _on_take_requested(_interactor: Node) -> void:
	if _hover:
		take_book(_hover)


func _set_hover(entry: LooseBook) -> void:
	if entry == _hover:
		return
	_hover = entry
	_interactable.take_text = "Nehmen" if entry else ""
	if entry:
		BookInfoCard.show_book(self, entry.book)
	else:
		BookInfoCard.hide_card(self)
	_queue_refresh()


# --- Wohin kommt das Buch? ---

func _compute_plan(from: Vector3, direction: Vector3, book: Book) -> Dictionary:
	var reach := GameConfig.interaction_distance
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach,
		FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT | FurnitureUtils.SURFACE_LAYER_BIT)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_distance: float = from.distance_to(hit.position) if not hit.is_empty() else INF
	# Ein ausgelegtes Buch liegt näher: darauf stapeln bzw. daneben stellen
	var picked := _pick(from, direction, reach)
	if not picked.is_empty() and picked.distance <= hit_distance + 0.001:
		return _plan_on_entry(book, picked.entry, picked.local_point, direction)
	if hit.is_empty():
		return {}
	var collider: Object = hit.collider
	var normal: Vector3 = hit.normal
	var point: Vector3 = hit.position
	if collider is PlacementSurface:
		if BookShelf.find_for_surface(collider):
			return {}  # Regalbretter: dort stellt das Regal selbst ein
		var item := FurnitureUtils.find_placed_furniture(collider)
		return _plan_flat(book, point, (collider as PlacementSurface).get_surface_height(),
			item.uid if item else 0, direction)
	var furniture := FurnitureUtils.find_placed_furniture(collider)
	var stand := BookStand.find_in(furniture)
	if stand:
		return _plan_in_stand(book, stand, furniture)  # Buch-Aufsteller
	if furniture and furniture.data and furniture.data.subcategory == "bookend":
		return _plan_beside_bookend(book, furniture, point)
	if normal.y > 0.7:
		if furniture == null:
			return _plan_flat(book, point, point.y, 0, direction)  # Boden
		if furniture.data and furniture.data.books_can_lie:
			return _plan_flat(book, point, point.y, furniture.uid, direction)  # Polster (Kissen, Decke)
		return _invalid_plan(book, point, direction)  # z. B. oben auf einer Lampe
	if absf(normal.y) < 0.4 and furniture == null:
		return _plan_leaning(book, point, normal, direction)  # Wand
	if absf(normal.y) < 0.4 and furniture.data and furniture.data.books_can_lean:
		# Lehne, großer Blumentopf …: angelehnt wie an der Wand; ist das Möbelstück dort
		# niedriger als das Buch, liegt das Buch an seiner Oberkante an
		var lean_plan := _plan_leaning(book, point, normal, direction, _top_of(collider, point, normal))
		if not lean_plan.is_empty():
			lean_plan.support_uid = furniture.uid  # wandert mit dem Möbelstück (und geht mit ihm)
		return lean_plan
	# Seite eines Möbelstücks: flach auf den Boden bzw. die Ablage darunter, genau dort, wo ich
	# hinschaue – ragt es dabei in das Möbelstück hinein, ist die Vorschau rot (kein Abprallen)
	var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
	var ground := _find_ground(point + flat_normal * 0.01)
	if ground.is_empty():
		return {}  # nichts darunter (z. B. hoch oben an einem Schrank): keine Vorschau
	return _plan_flat(book, ground.point, ground.height, ground.support_uid, direction)


## Flach mit dem Cover nach oben, die Oberkante des Buchs zeigt von mir weg (leicht schräg).
## Liegen dort schon Bücher, kommt es obendrauf (kleiner Stapel).
func _plan_flat(book: Book, world_point: Vector3, surface_height: float, support_uid: int,
		direction: Vector3, forward_override: Vector3 = Vector3.ZERO) -> Dictionary:
	var size := book.data.size
	var forward := forward_override if forward_override != Vector3.ZERO else Vector3(direction.x, 0.0, direction.z)
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	forward = forward.rotated(Vector3.UP, (_jitter(book, 0) - 0.5) * 2.0 * deg_to_rad(GameConfig.loose_book_yaw_jitter))
	forward = forward.rotated(Vector3.UP, deg_to_rad(turn_degrees))  # mit dem Mausrad gedreht
	var basis := _flat_basis(forward, size)
	var origin := Vector3(world_point.x, surface_height + size.x / 2.0 + LIFT, world_point.z)
	var world := Transform3D(basis, origin)
	var ok := _room == null or _room.is_inside_build_area(origin)
	# Liegen schon Bücher an dieser Stelle? Dann obendrauf (nie ineinander). Zum Stapel gehört
	# nur, was lückenlos aufeinander liegt – nicht z. B. ein Buch auf dem Brett darüber.
	var top := surface_height
	var stacked := 0
	var ceiling := INF  # Unterkante des nächsten Buchs darüber, das nicht zum Stapel gehört
	for entry in _sorted_by_bottom(_overlapping(world, surface_height, STACK_REACH)):
		var entry_world := global_transform * entry.transform
		var half := _vertical_half(entry_world)
		var entry_bottom := entry_world.origin.y - half
		if entry_bottom > top + STACK_GAP:
			ceiling = entry_bottom
			break
		if not entry.is_flat():
			ok = false  # auf ein aufrechtes Buch kann man nichts legen
		top = maxf(top, entry_world.origin.y + half)
		stacked += 1
	if stacked >= GameConfig.loose_book_stack_max or top + size.x + LIFT > ceiling:
		ok = false
	world.origin.y = top + size.x / 2.0 + LIFT
	if ok and _blocked_by_solid(world):
		ok = false
	return {"book": book, "ok": ok, "transform": global_transform.affine_inverse() * world,
		"support_uid": support_uid, "pose": LooseBook.Pose.FLAT}


## Auf ein ausgelegtes Buch: flach darauf (Stapel) bzw. aufrecht daneben.
func _plan_on_entry(book: Book, entry: LooseBook, local_point: Vector3, direction: Vector3) -> Dictionary:
	var entry_world := global_transform * entry.transform
	if entry.pose == LooseBook.Pose.DISPLAYED:
		# Ein Buch im Aufsteller: Der ist schon belegt (rot, nichts passiert)
		return {"book": book, "ok": false, "transform": entry.transform, "support_uid": entry.support_uid,
			"pose": LooseBook.Pose.DISPLAYED}
	if entry.is_flat() and absf(local_point.x) < 0.45:
		return _plan_against_stack(book, entry, local_point, direction)  # Seite eines Stapels
	if entry.is_flat():
		# Leicht versetzt auf den Stapel, ungefähr gleich ausgerichtet
		var forward := entry_world.basis.y.normalized()
		var offset := Vector3((_jitter(book, 8) - 0.5) * 0.03, 0.0, (_jitter(book, 16) - 0.5) * 0.03)
		var bottom := _bottom_of_stack(entry)
		return _plan_flat(book, entry_world.origin + offset, bottom, entry.support_uid, direction, forward)
	if entry.pose == LooseBook.Pose.UPRIGHT:
		# Daneben in die Reihe – auf der Seite, auf die ich schaue
		var side := 1.0 if local_point.x >= 0.0 else -1.0
		return _plan_in_row(book, entry_world, side, entry.support_uid, side)
	# An die Wand gelehnt: daneben an dieselbe Wand (auf der Seite, auf die ich schaue).
	# Die Wand selbst suchen (das Buch kann zur Seite gedreht sein, sein Cover zeigt dann
	# nicht genau von der Wand weg).
	var cover := entry_world.basis.x.normalized()
	var cover_flat := Vector3(cover.x, 0.0, cover.z).normalized()
	var wall_normal := cover_flat
	var wall_point := entry_world.origin - cover_flat * (_half_extent(entry_world.basis, cover_flat) + 0.003)
	var query := PhysicsRayQueryParameters3D.create(entry_world.origin, entry_world.origin - cover_flat * 0.5,
		FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT)
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	# Woran lehnt es? Wand (ganz hoch), Möbelstück (bis zu seiner Oberkante) oder ein Stapel
	var top := INF
	var lean_uid := -1
	if not wall.is_empty() and FurnitureUtils.find_placed_furniture(wall.collider):
		top = _top_of(wall.collider, wall.position, wall.normal)
		lean_uid = FurnitureUtils.find_placed_furniture(wall.collider).uid
	elif wall.is_empty():
		var bottom := entry_world.origin.y - _vertical_half(entry_world)
		var probe := entry_world.translated(-cover_flat * 0.03)
		var found := -INF
		for other in _overlapping(probe, bottom):
			if other != entry and other.is_flat():
				var other_world := global_transform * other.transform
				found = maxf(found, other_world.origin.y + _vertical_half(other_world))
		if found > -INF:
			top = found  # lehnt an einem Stapel: bis zu dessen Oberkante
	if not wall.is_empty():
		wall_normal = Vector3(wall.normal.x, 0.0, wall.normal.z).normalized()
		# Mitte des Buchs senkrecht auf die Wand (der Strahl selbst läuft bei gedrehten Büchern
		# schräg und träfe die Wand seitlich versetzt)
		wall_point = entry_world.origin - wall_normal * wall_normal.dot(entry_world.origin - wall.position)
	var along := wall_normal.cross(Vector3.UP).normalized()  # entlang der Wand
	if along.dot(entry_world.basis.z) < 0.0:
		along = -along
	var side_sign := 1.0 if local_point.z >= 0.0 else -1.0
	var new_basis := _leaning_basis(book.data.size, wall_normal, _lean_turn())
	var offset := _half_extent(entry_world.basis, along) + _half_extent(new_basis, along) + 0.02
	var plan := _plan_leaning(book, wall_point + along * side_sign * offset, wall_normal, direction, top)
	if not plan.is_empty():
		plan.support_uid = entry.support_uid if lean_uid < 0 else lean_uid
	return plan


## In einen Buch-Aufsteller: genau ein Buch, nach hinten geneigt, Cover nach vorn. Ist er schon
## belegt oder stößt das Buch irgendwo an (z. B. das Regalbrett darüber), ist die Vorschau rot.
func _plan_in_stand(book: Book, stand: BookStand, item: PlacedFurniture) -> Dictionary:
	var world := stand.get_book_transform(book.data.size)
	var occupied := false
	for entry in _entries:
		if entry.support_uid == item.uid and not entry.hidden:
			occupied = true
	var ok := not occupied and (_room == null or _room.is_inside_build_area(world.origin)) \
		and not _blocked_by_solid(world, [stand.get_body_rid()]) \
		and _overlapping(world, world.origin.y - _vertical_half(world)).is_empty() \
		and _shelf_is_free(item, world)
	return {"book": book, "ok": ok, "transform": global_transform.affine_inverse() * world,
		"support_uid": item.uid, "pose": LooseBook.Pose.DISPLAYED}


## Steht der Aufsteller in einem Bücherregal: Ragt das Buch darin in Bücher des Regals?
## (Das Buch ist breiter als der Aufsteller.) Sonst immer frei.
func _shelf_is_free(stand_item: PlacedFurniture, world: Transform3D) -> bool:
	for shelf: BookShelf in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
		var holder := FurnitureUtils.find_placed_furniture(shelf)
		if holder and holder.uid == stand_item.support_uid:
			return shelf.is_free_at(stand_item.global_position, _box_corners(world))
	return true


## Die acht Ecken eines Buchs (Lage in der Welt, mit Buchgröße in der Basis).
static func _box_corners(world: Transform3D) -> PackedVector3Array:
	var corners := PackedVector3Array()
	for i in 8:
		corners.append(world * Vector3((i & 1) - 0.5, ((i >> 1) & 1) - 0.5, ((i >> 2) & 1) - 0.5))
	return corners


## Nach dem Verschieben oder Wegnehmen: Liegt noch alles richtig?
## - Ein angelehntes Buch, das nirgends mehr anlehnt (Stapel weg), kippt um und liegt flach.
## - Ein Buch im Aufsteller, das jetzt irgendwo hineinragt (z. B. Fach zu niedrig), geht ins Lager.
func _check_resting(entries: Array[LooseBook]) -> void:
	for entry in entries:
		if not _entries.has(entry) or entry.hidden:
			continue
		var world := global_transform * entry.transform
		if entry.pose == LooseBook.Pose.LEANING and not _leans_on_something(entry, world):
			var cover := world.basis.x.normalized()
			var bottom := world.origin.y - _vertical_half(world)
			var flat := _plan_flat(entry.book, world.origin, bottom - LIFT, entry.support_uid,
				Vector3(cover.x, 0.0, cover.z), Vector3(cover.x, 0.0, cover.z))
			entry.transform = flat.transform
			entry.pose = LooseBook.Pose.FLAT
			_origins_dirty = true
		elif entry.pose == LooseBook.Pose.DISPLAYED:
			var stand_item := _find_furniture(entry.support_uid)
			var stand := BookStand.find_in(stand_item)
			if stand == null or _blocked_by_solid(world, [stand.get_body_rid()]):
				var book := remove(entry)
				BookStock.store_books([book])
				StorageIndicator.add_item(self, book.get_genre())


## Lehnt dieses Buch noch an etwas (Wand, Möbel, Bücher)? Dazu wird es ein Stück nach hinten
## geschoben geprüft – stößt es dann an, lehnt es.
func _leans_on_something(entry: LooseBook, world: Transform3D) -> bool:
	var cover := world.basis.x.normalized()
	var probe := world.translated(-Vector3(cover.x, 0.0, cover.z).normalized() * 0.015)
	if _blocked_by_solid(probe):
		return true
	for other in _overlapping(probe, world.origin.y - _vertical_half(world)):
		if other != entry:
			return true
	return false


func _find_furniture(uid: int) -> PlacedFurniture:
	if _room == null or uid <= 0:
		return null
	for item in _room.get_placed_furniture():
		if item.uid == uid:
			return item
	return null


## An die Seite eines liegenden Stapels gelehnt (wie leicht heruntergerutscht): steht auf
## derselben Ablage, liegt oben an der Kante des Stapels an.
func _plan_against_stack(book: Book, entry: LooseBook, local_point: Vector3, direction: Vector3) -> Dictionary:
	var entry_world := global_transform * entry.transform
	# Welche Seite des Buchs schaue ich an? (lokal: y = Oberkante, z = Rücken; x = Cover oben)
	var local_normal := Vector3(0.0, signf(local_point.y), 0.0) if absf(local_point.y) >= absf(local_point.z) \
		else Vector3(0.0, 0.0, signf(local_point.z))
	var normal := entry_world.basis.orthonormalized() * local_normal
	var n := Vector3(normal.x, 0.0, normal.z)
	if n.length() < 0.1:
		return {}
	n = n.normalized()
	# Der ganze Stapel: so weit hinaus, wie das am weitesten vorstehende Buch reicht
	var bottom := _bottom_of_stack(entry)
	var hit_point := entry_world * local_point
	var plane := -INF
	var top := bottom
	for other in _stack_from(bottom, entry_world):
		var other_world := global_transform * other.transform
		plane = maxf(plane, n.dot(other_world.origin - hit_point) + _half_extent(other_world.basis, n))
		top = maxf(top, other_world.origin.y + _vertical_half(other_world))
	var wall_point := hit_point + n * maxf(plane, 0.0)
	var plan := _plan_leaning(book, Vector3(wall_point.x, bottom + 0.01, wall_point.z), n, direction, top)
	if not plan.is_empty():
		# Es muss auf derselben Ablage stehen wie der Stapel (nicht z. B. unten am Tischrand)
		var plan_world := global_transform * (plan.transform as Transform3D)
		if absf(plan_world.origin.y - _vertical_half(plan_world) - LIFT - bottom) > STACK_GAP:
			plan.ok = false
		plan.support_uid = entry.support_uid
	return plan


## Die Bücher eines Stapels, der bei "bottom" beginnt (lückenlos übereinander, über "world").
func _stack_from(bottom: float, world: Transform3D) -> Array[LooseBook]:
	var result: Array[LooseBook] = []
	var top := bottom
	for entry in _sorted_by_bottom(_overlapping(world, bottom, STACK_REACH)):
		var entry_world := global_transform * entry.transform
		var half := _vertical_half(entry_world)
		if entry_world.origin.y - half > top + STACK_GAP:
			break
		if entry.is_flat():
			result.append(entry)
			top = maxf(top, entry_world.origin.y + half)
	return result


## Aufrecht neben einer Buchstütze: Rücken nach vorn, bündig an ihrer Seite (der Seite, auf
## die ich schaue).
func _plan_beside_bookend(book: Book, bookend: PlacedFurniture, world_point: Vector3) -> Dictionary:
	var model := bookend.get_model()
	if model == null:
		return {}
	var box := FurnitureUtils.get_local_aabb(model)
	var local_hit := model.global_transform.affine_inverse() * world_point
	var side := 1.0 if local_hit.x >= box.get_center().x else -1.0
	var size := book.data.size
	var edge := box.end.x if side > 0.0 else box.position.x
	# Lage im Koordinatensystem der Buchstütze: aufrecht, Rücken zeigt nach vorn (+Z)
	var local_origin := Vector3(edge + side * (size.x / 2.0 + 0.002), size.y / 2.0 + LIFT, box.end.z - size.z / 2.0)
	var basis := model.global_basis.orthonormalized() * Basis.from_scale(size)
	var world := Transform3D(basis, model.global_transform * local_origin)
	# Steht die Buchstütze im Bücherregal, räumt das Regal selbst ein (keine Vorschau)
	if _find_ground(world.origin - Vector3.UP * (size.y / 2.0)).is_empty():
		return {}
	return _plan_in_row(book, world, 0.0, bookend.support_uid, side)


## Aufrecht in einer Reihe: neben "neighbor" (side = +1/-1 entlang der Buchdicke) bzw. genau
## dort (side = 0). Steht dort schon ein Buch, rückt es in Richtung "step" weiter, bis Platz ist.
func _plan_in_row(book: Book, neighbor: Transform3D, side: float, support_uid: int, step: float) -> Dictionary:
	var size := book.data.size
	var axis := neighbor.basis.x.normalized()  # Richtung der Reihe
	var up := Vector3.UP
	var spine := neighbor.basis.z.normalized()
	var basis := Basis(axis * size.x, up * size.y, spine * size.z)
	# Unterkante auf gleicher Höhe wie der Nachbar, Rücken bündig vorn
	var bottom := neighbor.origin.y - _vertical_half(neighbor)
	var front := neighbor.origin + spine * neighbor.basis.z.length() / 2.0
	var origin := neighbor.origin
	if side != 0.0:
		origin += axis * side * (neighbor.basis.x.length() / 2.0 + size.x / 2.0 + 0.002)
	origin = Vector3(origin.x, bottom + size.y / 2.0 + LIFT, origin.z)
	origin += spine * (spine.dot(front - origin) - size.z / 2.0)
	var world := Transform3D(basis, origin)
	# Ist die Stelle schon besetzt? Dann weiter in Richtung der Reihe
	var step_side := step if step != 0.0 else 1.0
	for i in 30:
		var blocking := _overlapping(world, bottom)
		if blocking.is_empty():
			break
		var furthest := 0.0
		for entry in blocking:
			var entry_world := global_transform * entry.transform
			furthest = maxf(furthest, (entry_world.origin - world.origin).dot(axis * step_side) + entry_world.basis.x.length() / 2.0)
		world.origin += axis * step_side * (furthest + size.x / 2.0 + 0.002)
	var ok := (_room == null or _room.is_inside_build_area(world.origin)) and _overlapping(world, bottom).is_empty() \
		and not _blocked_by_solid(world)
	# Steht es noch auf derselben Ablage (nicht über die Tischkante hinaus gerückt)?
	var ground := _find_ground(Vector3(world.origin.x, bottom, world.origin.z))
	if ground.is_empty() or absf(ground.height - bottom) > STACK_GAP:
		ok = false
	else:
		support_uid = ground.support_uid
	return {"book": book, "ok": ok, "transform": global_transform.affine_inverse() * world,
		"support_uid": support_uid, "pose": LooseBook.Pose.UPRIGHT}


## An eine Wand gelehnt: steht auf dem Boden bzw. der Ablage davor, Cover zeigt in den Raum.
## top: Oberkante dessen, woran es lehnt (Höhe in der Welt; INF = Wand, höher als jedes Buch).
func _plan_leaning(book: Book, wall_point: Vector3, wall_normal: Vector3, direction: Vector3,
		top: float = INF) -> Dictionary:
	var n := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
	var ground := _find_ground(wall_point + n * 0.05)
	if ground.is_empty():
		return {}  # zu hoch an der Wand: keine Vorschau (sonst schwebt beim Umsehen ständig eine)
	var basis := _leaning_basis(book.data.size, n, _lean_turn())
	# So weit vor die Wand und über den Boden, dass das Buch gerade anliegt bzw. aufsteht –
	# bei etwas Niedrigerem (Armlehne, Bücherstapel) liegt es an dessen Oberkante an
	var base := Vector3(wall_point.x, ground.height, wall_point.z)
	var contact: float = top - ground.height - LIFT
	var reach := _lean_reach(basis, n, contact)
	var origin := base + n * (reach + 0.003) + Vector3.UP * (_vertical_half_of(basis) + LIFT)
	var world := Transform3D(basis, origin)
	var ok := (_room == null or _room.is_inside_build_area(origin)) and _overlapping(world, ground.height).is_empty() \
		and not _blocked_by_solid(world) and contact >= 0.02  # an fast nichts kann es nicht lehnen
	return {"book": book, "ok": ok, "transform": global_transform.affine_inverse() * world,
		"support_uid": ground.support_uid, "pose": LooseBook.Pose.LEANING}


## Wie weit ragt ein angelehntes Buch (Lage basis, Mitte = 0) in Richtung der Wand (-n) – nur
## bis zur Höhe contact_height über seiner Unterkante gezählt (dort liegt es an; darüber ist
## nichts mehr, woran es stoßen könnte). INF = ganz (wie an einer Wand).
static func _lean_reach(basis: Basis, n: Vector3, contact_height: float) -> float:
	var bottom := -_vertical_half_of(basis)
	var limit := bottom + maxf(contact_height, 0.0)
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(basis.x * ((i & 1) - 0.5) + basis.y * (((i >> 1) & 1) - 0.5) + basis.z * (((i >> 2) & 1) - 0.5))
	var reach := -INF
	for c in corners:
		if c.y <= limit:
			reach = maxf(reach, c.dot(-n))
	# Kanten, die die Höhe "limit" kreuzen: dort ein Punkt mehr
	for i in 8:
		for bit in [1, 2, 4]:
			var j: int = i | bit
			if j == i:
				continue
			var a := corners[i]
			var b := corners[j]
			if (a.y - limit) * (b.y - limit) < 0.0:
				var t := (limit - a.y) / (b.y - a.y)
				reach = maxf(reach, a.lerp(b, t).dot(-n))
	return reach if reach > -INF else _half_extent(basis, n)


## Oberkante eines Möbelstücks (seines Körpers "collider") direkt hinter der Stelle, auf die ich
## schaue (INF, wenn sie nicht zu finden ist).
func _top_of(collider: Object, point: Vector3, normal: Vector3) -> float:
	var inside := point - Vector3(normal.x, 0.0, normal.z).normalized() * 0.01
	var query := PhysicsRayQueryParameters3D.create(inside + Vector3.UP * 0.6, inside,
		FurnitureUtils.FURNITURE_LAYER_BIT)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() and hit.collider == collider else INF


## Lage eines angelehnten Buchs (mit Buchgröße): Cover zeigt von der Wand weg (Wandnormale n),
## oben nach hinten gekippt; "turn" (Grad) dreht es zusätzlich um die Hochachse.
static func _leaning_basis(size: Vector3, n: Vector3, turn: float) -> Basis:
	var angle := deg_to_rad(GameConfig.loose_book_lean_angle)
	var up := Vector3.UP
	var cover := n * cos(angle) + up * sin(angle)
	var top := up * cos(angle) - n * sin(angle)
	var basis := Basis(cover * size.x, top * size.y, cover.cross(top).normalized() * size.z)
	return Basis(up, deg_to_rad(turn)) * basis


## Die mit dem Mausrad gewählte Drehung für angelehnte Bücher (begrenzt, Grad).
func _lean_turn() -> float:
	var limit := GameConfig.loose_book_lean_max_turn
	return clampf(wrapf(turn_degrees, -180.0, 180.0), -limit, limit)


## Eine Vorschau an der Stelle, die nicht geht (rötlich).
func _invalid_plan(book: Book, world_point: Vector3, direction: Vector3) -> Dictionary:
	var plan := _plan_flat(book, world_point, world_point.y, 0, direction)
	plan.ok = false
	return plan


## Ragt ein Buch (Lage in der Welt, mit Buchgröße in der Basis) in ein anderes Objekt hinein –
## Möbel, Deko, Wände, Boden? Das Buch wird dafür an jeder Seite um SOLID_MARGIN kleiner
## geprüft: Aufliegen und Anlehnen ist erlaubt, Hineinragen nie. Eine Regel für alles, was ich
## ablege (flach, aufrecht, angelehnt).
## exclude: Körper, die es berühren darf (z. B. der Aufsteller, in dem es liegt).
func _blocked_by_solid(world: Transform3D, exclude: Array[RID] = []) -> bool:
	var size := Vector3(world.basis.x.length(), world.basis.y.length(), world.basis.z.length())
	if _solid_box == null:
		_solid_box = BoxShape3D.new()  # eine Form für alle Prüfungen (nicht jedes Bild neu)
	_solid_box.size = (size - Vector3.ONE * SOLID_MARGIN * 2.0).max(Vector3.ONE * 0.001)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _solid_box
	query.transform = Transform3D(world.basis.orthonormalized(), world.origin)
	query.collision_mask = FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT
	query.collide_with_areas = false
	query.exclude = exclude
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Boden oder Ablage senkrecht unter einem Punkt: { "point", "height", "support_uid" } – leer,
## wenn dort nichts ist (oder es ein Regalbrett ist).
func _find_ground(world_point: Vector3) -> Dictionary:
	var from := world_point + Vector3.UP * 0.05
	var to := world_point - Vector3.UP * GameConfig.loose_book_ground_reach
	var query := PhysicsRayQueryParameters3D.create(from, to,
		FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT | FurnitureUtils.SURFACE_LAYER_BIT)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.7:
		return {}
	if hit.collider is PlacementSurface:
		if BookShelf.find_for_surface(hit.collider):
			return {}
		var item := FurnitureUtils.find_placed_furniture(hit.collider)
		return {"point": hit.position, "height": (hit.collider as PlacementSurface).get_surface_height(),
			"support_uid": item.uid if item else 0}
	var item := FurnitureUtils.find_placed_furniture(hit.collider)
	if item:
		if item.data and item.data.books_can_lie:
			return {"point": hit.position, "height": hit.position.y, "support_uid": item.uid}  # Polster
		return {}  # auf Möbeln sonst nur dort, wo eine Ablagefläche ist
	return {"point": hit.position, "height": hit.position.y, "support_uid": 0}


## Liegend: Cover (+X) nach oben, Oberkante (+Y) zeigt nach "forward", Rücken (+Z) nach links.
static func _flat_basis(forward: Vector3, size: Vector3) -> Basis:
	var up := Vector3.UP
	return Basis(up * size.x, forward * size.y, up.cross(forward).normalized() * size.z)


## Welche ausgelegten Bücher überschneiden sich mit diesem Buch (Lage in der Welt)?
## Nur Bücher, die über "floor_height" liegen (nicht die auf einer anderen Ebene darunter) und
## höchstens "reach_above" über der Oberkante beginnen (0 = nur echte Überschneidungen; zum
## Stapeln größer, damit der ganze Stapel darüber gefunden wird).
func _overlapping(world: Transform3D, floor_height: float, reach_above: float = 0.0) -> Array[LooseBook]:
	var result: Array[LooseBook] = []
	var my_top := world.origin.y + _vertical_half(world)
	for entry in _nearby(global_transform.affine_inverse() * world.origin):
		if entry.hidden:
			continue
		var other := global_transform * entry.transform
		var other_bottom := other.origin.y - _vertical_half(other)
		var other_top := other.origin.y + _vertical_half(other)
		if other_top < floor_height + 0.002 or other_bottom > my_top + reach_above:
			continue
		if _footprints_overlap(world, other) and (reach_above > 0.0 or _boxes_overlap(world, other)):
			result.append(entry)
	return result


## Überschneiden sich die Grundrisse (von oben gesehen) zweier Bücher? Trennachsen-Test mit
## dem Schatten des ganzen Buchs – auch ein angelehntes Buch reicht oben ein Stück nach hinten.
## Die Kanten des Schattens laufen entlang der (von oben gesehenen) Buchachsen.
static func _footprints_overlap(a: Transform3D, b: Transform3D) -> bool:
	var axes: Array[Vector2] = []
	for t: Transform3D in [a, b]:
		for v: Vector3 in [t.basis.x, t.basis.y, t.basis.z]:
			var flat := Vector2(v.x, v.z)
			if flat.length_squared() > 1e-8:
				axes.append(Vector2(-flat.y, flat.x).normalized())
	var between := Vector2(b.origin.x - a.origin.x, b.origin.z - a.origin.z)
	for axis in axes:
		var axis_3d := Vector3(axis.x, 0.0, axis.y)
		if absf(between.dot(axis)) >= _half_extent(a.basis, axis_3d) + _half_extent(b.basis, axis_3d) - 0.002:
			return false
	return true


## Überschneiden sich zwei Quader (Würfel der Größe 1, gestreckt und gedreht)? Trennachsen-Test
## im Raum: 3 + 3 Kantenrichtungen und ihre 9 Kreuzprodukte.
static func _boxes_overlap(a: Transform3D, b: Transform3D) -> bool:
	var axes_a: Array[Vector3] = [a.basis.x, a.basis.y, a.basis.z]
	var axes_b: Array[Vector3] = [b.basis.x, b.basis.y, b.basis.z]
	var tests: Array[Vector3] = []
	for v in axes_a + axes_b:
		tests.append(v)
	for u in axes_a:
		for v in axes_b:
			tests.append(u.cross(v))
	var between := b.origin - a.origin
	for axis in tests:
		if axis.length_squared() < 1e-10:
			continue
		var n := axis.normalized()
		var reach_a := (absf(axes_a[0].dot(n)) + absf(axes_a[1].dot(n)) + absf(axes_a[2].dot(n))) / 2.0
		var reach_b := (absf(axes_b[0].dot(n)) + absf(axes_b[1].dot(n)) + absf(axes_b[2].dot(n))) / 2.0
		if absf(between.dot(n)) >= reach_a + reach_b:
			return false
	return true


## Halbe Höhe eines Buchs (Lage in der Welt) – wie weit es nach oben und unten reicht.
static func _vertical_half(t: Transform3D) -> float:
	return _vertical_half_of(t.basis)


static func _vertical_half_of(basis: Basis) -> float:
	return (absf(basis.x.y) + absf(basis.y.y) + absf(basis.z.y)) / 2.0


## Wie weit ein Buch (Basis mit Buchgröße) von seiner Mitte aus in Richtung "axis" reicht.
static func _half_extent(basis: Basis, axis: Vector3) -> float:
	return (absf(basis.x.dot(axis)) + absf(basis.y.dot(axis)) + absf(basis.z.dot(axis))) / 2.0


## Unterkante des Stapels, zu dem dieses liegende Buch gehört (die Fläche darunter): von Buch
## zu Buch nach unten, solange sie lückenlos aufeinander liegen.
func _bottom_of_stack(entry: LooseBook) -> float:
	var current := entry
	var world := global_transform * entry.transform
	var bottom := world.origin.y - _vertical_half(world)
	for i in GameConfig.loose_book_stack_max + 1:
		var below: LooseBook = null
		for other in _nearby(current.transform.origin):
			if other == current or not other.is_flat() or other.hidden:
				continue
			var other_world := global_transform * other.transform
			var other_top := other_world.origin.y + _vertical_half(other_world)
			if absf(bottom - other_top) <= STACK_GAP and _footprints_overlap(world, other_world):
				below = other
				world = other_world
				bottom = other_world.origin.y - _vertical_half(other_world)
				break
		if below == null:
			break
		current = below
	return bottom - LIFT


## Bücher von unten nach oben sortiert (nach ihrer Unterkante).
func _sorted_by_bottom(entries: Array[LooseBook]) -> Array[LooseBook]:
	var bottoms := {}
	for entry in entries:
		var world := global_transform * entry.transform
		bottoms[entry] = world.origin.y - _vertical_half(world)
	entries.sort_custom(func(a: LooseBook, b: LooseBook) -> bool: return bottoms[a] < bottoms[b])
	return entries


## Ein Buch aus einem Stapel genommen: Was darauf lag (und darauf …), rutscht um seine Dicke
## nach unten. Bücher, die noch auf einem anderen Buch aufliegen, bleiben liegen.
func _settle_above(removed: LooseBook) -> void:
	if not removed.is_flat():
		return
	var removed_world := global_transform * removed.transform
	var thickness := _vertical_half(removed_world) * 2.0 + LIFT
	# Bücher in der Nähe mit ihrer bisherigen Lage, von unten nach oben
	var others: Array[LooseBook] = []
	var worlds := {}
	for other in _nearby(removed.transform.origin):
		if other != removed and other.is_flat():
			others.append(other)
			worlds[other] = global_transform * other.transform
	others = _sorted_by_bottom(others)
	var lowered := {}
	for other in others:
		var other_world: Transform3D = worlds[other]
		var other_bottom := other_world.origin.y - _vertical_half(other_world)
		var on_lowered := _rests_on(other_world, other_bottom, removed_world)
		var on_fixed := false
		for below in others:
			if below == other:
				break  # nur, was darunter liegt (Liste ist sortiert)
			if _rests_on(other_world, other_bottom, worlds[below]):
				if lowered.has(below):
					on_lowered = true
				else:
					on_fixed = true
		if on_lowered and not on_fixed:
			other.transform.origin.y -= thickness
			lowered[other] = true


## Liegt ein Buch (Lage "world", Unterkante "bottom") auf dem Buch mit der Lage "below"?
static func _rests_on(world: Transform3D, bottom: float, below: Transform3D) -> bool:
	return absf(bottom - (below.origin.y + _vertical_half(below))) <= STACK_GAP \
		and _footprints_overlap(world, below)


## Das ausgelegte Buch auf dem Blickstrahl: { "entry", "distance", "local_point" } – oder leer.
## Im selben Bild mit demselben Blick wird das Ergebnis nur einmal berechnet.
func _pick(from: Vector3, direction: Vector3, reach: float) -> Dictionary:
	var key := [from, direction, reach, Engine.get_physics_frames(), _entries.size()]
	if key == _pick_cache_key:
		return _pick_cache
	_pick_cache_key = key
	_pick_cache = _pick_uncached(from, direction, reach)
	return _pick_cache


func _pick_uncached(from: Vector3, direction: Vector3, reach: float) -> Dictionary:
	var to_local := global_transform.affine_inverse()
	var origin := to_local * from
	var dir := to_local.basis * direction
	var best := {}
	var best_distance := reach
	var ray_dir := dir.normalized()
	var origins := _get_origins()
	for i in origins.size():
		# Schnell aussortieren: zu weit weg oder zu weit neben dem Blickstrahl
		var to_entry := origins[i] - origin
		var along := to_entry.dot(ray_dir)
		if along < -0.3 or along > reach + 0.3 or (to_entry - ray_dir * along).length_squared() > 0.06:
			continue
		var entry := _entries[i]
		if entry.hidden:
			continue
		var inverse := entry.transform.affine_inverse()
		var local_origin := inverse * origin
		var local_dir := inverse.basis * dir
		var distance := BookShelf._ray_box(local_origin, local_dir)
		if distance < best_distance:
			best_distance = distance
			best = {"entry": entry, "distance": distance, "local_point": local_origin + local_dir * distance}
	return best


## Die Bücher in der Nähe eines Punkts (in diesem Knoten), von oben gesehen – nur diese
## müssen genau verglichen werden (Bücher sind höchstens gut 30 cm groß).
func _nearby(local_point: Vector3) -> Array[LooseBook]:
	var result: Array[LooseBook] = []
	var origins := _get_origins()
	for i in origins.size():
		var offset := origins[i] - local_point
		if offset.x * offset.x + offset.z * offset.z <= 0.2:
			result.append(_entries[i])
	return result


## Mittelpunkte aller Bücher (wird nach jeder Änderung neu gesammelt).
func _get_origins() -> PackedVector3Array:
	if _origins_dirty or _origins.size() != _entries.size():
		_origins.resize(_entries.size())
		for i in _entries.size():
			_origins[i] = _entries[i].transform.origin
		_origins_dirty = false
	return _origins


## Eine feste Zahl zwischen 0 und 1 je Exemplar (für kleine Abweichungen).
static func _jitter(book: Book, shift: int) -> float:
	return float((book.look >> shift) & 255) / 255.0


# --- Vorschau ---

func _set_plan(plan: Dictionary) -> void:
	var old_book: Book = _plan.get("book")
	var old_ok: bool = _plan.get("ok", false)
	_plan = plan
	if plan.is_empty():
		if _ghost:
			_ghost.visible = false
		return
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.name = "Preview"
		_ghost.mesh = BookLook.get_mesh()
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost_material = FurnitureUtils.make_blueprint_material(true)
		_ghost.material_override = _ghost_material
		add_child(_ghost)
	var book: Book = plan.book
	if book != old_book or plan.ok != old_ok or not _ghost.visible:
		FurnitureUtils.set_blueprint_valid(_ghost_material, plan.ok)
	if _ghost_shake < 0.0:
		_ghost.transform = plan.transform
	_ghost.visible = true


func _process(delta: float) -> void:
	# Vorschau schüttelt sich kurz (Klick an einer Stelle, wo es nicht geht)
	if _ghost_shake < 0.0:
		set_process(false)
		return
	_ghost_shake += delta
	var fade := clampf(1.0 - _ghost_shake / 0.35, 0.0, 1.0)
	if _ghost and not _plan.is_empty():
		var t: Transform3D = _plan.transform
		_ghost.transform = t.translated(t.basis.z.normalized() * sin(_ghost_shake * 45.0) * 0.01 * fade)
	if fade <= 0.0:
		_ghost_shake = -1.0


# --- Zeichnen ---

func _queue_refresh() -> void:
	_origins_dirty = true
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


## Überträgt alle ausgelegten Bücher ins MultiMesh (Lage, Farbe, Cover-Feld, Buchrücken).
func _refresh() -> void:
	_refresh_queued = false
	if _multimesh.instance_count != _entries.size():
		_multimesh.instance_count = _entries.size()
	for i in _entries.size():
		var entry := _entries[i]
		var t := entry.transform
		if entry.hidden:
			t = Transform3D(Basis.from_scale(Vector3.ZERO), t.origin)
		_multimesh.set_instance_transform(i, t)
		var color := BookLook.get_color(entry.book)
		var code := BookArt.get_cover_slot(entry.book.data) + 1
		if entry == _hover:
			code += 128
		color.a = code / 255.0
		_multimesh.set_instance_color(i, color)
		_multimesh.set_instance_custom_data(i, BookLook.get_custom(entry.book))


func _changed() -> void:
	changed.emit()
	SaveManager.request_save()


# --- Speichern (über den Raum) ---

func get_save_data() -> Array:
	var result := []
	for entry in _entries:
		result.append(entry.to_save_data())
	return result


func load_save_data(data: Variant) -> void:
	for entry in _entries:
		BookArt.release_cover(entry.book.data)
	_entries.clear()
	_hover = null
	if data is Array:
		for saved in data:
			var entry := LooseBook.from_save_data(saved)
			if entry:
				_entries.append(entry)
				BookArt.retain_cover(entry.book.data)
	_queue_refresh()
