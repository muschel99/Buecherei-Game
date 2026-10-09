extends Node
## Erzeugt scenes/world/houses.tscn neu (seit Etappe 4e): stellt jedes Haus als eigenen Knoten
## fest in die Szene – Lage und Typ aus HousesLayout (also aus StreetLayout und GameConfig).
##
## Benutzen: In Godot die Szene scenes/world/tools/generate_houses.tscn öffnen und mit F6
## („Aktuelle Szene starten“) starten. Das Fenster schließt sich nach einem Augenblick von
## selbst; die Ausgabe unten zeigt „Häuser neu erzeugt“. Danach fragt Godot evtl., ob es
## houses.tscn neu laden soll – mit „Neu laden“ bestätigen.
## Achtung: Eigene Änderungen in houses.tscn (verschobene oder getauschte Häuser) werden dabei
## überschrieben.

const TARGET := "res://scenes/world/houses.tscn"

const HEADER := """; Alle Nachbarhäuser (seit Etappe 4e jedes Haus ein eigener Knoten). Erzeugt von
; scenes/world/tools/generate_houses.tscn (Lage aus StreetLayout und GameConfig) – danach frei
; im Editor anklickbar, verschiebbar und austauschbar. Jedes Haus ist eine Szene aus
; scenes/world/houses/ (ein Haustyp). Liegt unter "Outside" (y = 0 = Gehweg).
; Gruppen: LibraryRow = Nachbarn der Bücherei, Opposite = gegenüber, StraightEnd = hinter der
; Grenze am geraden Straßenende, SideStreets = an den Knicks, GateStreet = Torhaus am abbiegenden
; Ende und die Häuser entlang der Kurve dahinter.
"""


func _ready() -> void:
	var root := Node3D.new()
	root.name = "Houses"
	var groups := {}
	var count := 0
	for house: Dictionary in HousesLayout.plan():
		if not groups.has(house.group):
			var group := Node3D.new()
			group.name = house.group
			root.add_child(group)
			group.owner = root
			groups[house.group] = group
		var node := HouseTypes.get_scene(house.type).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as HouseFacade
		node.name = house.name
		node.position = house.position
		node.rotation.y = house.yaw
		node.wall_color = house.wall_color
		node.door_color = house.door_color
		node.casts_shadow = house.casts_shadow
		node.solid = house.solid
		groups[house.group].add_child(node)
		node.owner = root
		count += 1
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error == OK:
		error = ResourceSaver.save(scene, TARGET)
	if error == OK:
		_add_header()
		print("Häuser neu erzeugt: %d Häuser in %s" % [count, TARGET])
	else:
		push_error("Häuser konnten nicht gespeichert werden (Fehler %d)" % error)
	root.free()
	get_tree().quit()


## Kurze Erklärung oben in die Datei schreiben (für alle, die sie im Texteditor öffnen).
func _add_header() -> void:
	var file := FileAccess.open(TARGET, FileAccess.READ)
	if file == null:
		return
	var lines := file.get_as_text().split("\n")
	file.close()
	if lines.size() < 2:
		return
	lines.insert(1, "\n" + HEADER.strip_edges())
	file = FileAccess.open(TARGET, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
