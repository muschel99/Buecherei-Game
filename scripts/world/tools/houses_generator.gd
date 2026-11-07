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
##
## Nur verschieben (seit der Nachbesserung 3 von 6h, z. B. nach breiteren Gehwegen):
##   godot --headless --path . res://scenes/world/tools/generate_houses.tscn -- --move [--type=Gruppe/Name:haustyp …]
##     [--add=Gruppe/Name:haustyp …]
## Lage und Drehung jedes Hauses kommen neu aus HousesLayout – mit den Haustypen, die schon in houses.tscn stehen (jedes
## Haus hat sein eigenes Modell); alles andere (Modelle, Farben, Laternen, Seitenfenster …) bleibt unverändert.
## --type tauscht den Haustyp eines Hauses, --add hängt ein Haus an eine Reihe an (Name = nächste Nummer der Reihe) –
## danach sein Modell (neu) bauen: build_storybook_street.py -- Gruppe/Name.

const TARGET := "res://scenes/world/houses.tscn"

const HEADER := """; Alle Nachbarhäuser (seit Etappe 4e jedes Haus ein eigener Knoten). Erzeugt von
; scenes/world/tools/generate_houses.tscn (Lage aus StreetLayout und GameConfig) – danach frei
; im Editor anklickbar, verschiebbar und austauschbar. Jedes Haus ist eine Szene aus
; scenes/world/houses/ (ein Haustyp). Liegt unter "Outside" (y = 0 = Gehweg).
; Gruppen: LibraryRow = Nachbarn der Bücherei, Opposite = gegenüber, StraightEnd = bis zur
; Grenze und um die runde Kurve am geraden Straßenende, GateStreet = sanfte Kurve, Torhaus und die
; Häuser dahinter am anderen Ende (seit Etappe 4f).
"""


func _ready() -> void:
	if "--move" in OS.get_cmdline_user_args():
		_move()
		get_tree().quit()
		return
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
		# Weitere Einstellungen nur für dieses Haus (z. B. Fenster in der Seitenwand)
		for key in house.get("props", {}):
			node.set(key, house.props[key])
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


## Nur verschieben: in houses.tscn je Haus die Zeile "transform = …" ersetzen (und bei --type die Szene des Haustyps).
func _move() -> void:
	var scene := (load(TARGET) as PackedScene).instantiate()
	var keep := {}
	for group in scene.get_children():
		for house in group.get_children():
			keep["%s/%s" % [group.name, house.name]] = house.scene_file_path.get_file().get_basename()
	scene.free()
	var changed_types := {}
	var added := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--add="):
			var pair := arg.trim_prefix("--add=").split(":")
			if pair.size() == 2 and not keep.has(pair[0]):
				keep[pair[0]] = pair[1]
				added[pair[0]] = pair[1]
			else:
				push_error("Haus gibt es schon oder falsche Angabe: %s" % arg)
				return
		if arg.begins_with("--type="):
			var pair := arg.trim_prefix("--type=").split(":")
			if pair.size() == 2 and keep.has(pair[0]):
				keep[pair[0]] = pair[1]
				changed_types[pair[0]] = pair[1]
			else:
				push_error("Unbekanntes Haus oder falsche Angabe: %s" % arg)
				return
	var text := FileAccess.get_file_as_string(TARGET)
	var lines: Array = Array(text.split("\n"))   # Array: _type_resource fügt evtl. eine Zeile ein
	var moved := 0
	for house: Dictionary in HousesLayout.plan(keep):
		var header := '[node name="%s" parent="%s"' % [house.name, house.group]
		var index := -1
		for i in lines.size():
			if String(lines[i]).begins_with(header):
				index = i
				break
		var key := "%s/%s" % [house.group, house.name]
		if index < 0 and added.has(key):
			index = _insert_house(lines, house, _type_resource(lines, String(added[key])))
		if index < 0:
			push_error("Haus fehlt in houses.tscn: %s/%s" % [house.group, house.name])
			continue
		if changed_types.has(key):
			var id := _type_resource(lines, String(changed_types[key]))
			lines[index] = RegEx.create_from_string('instance=ExtResource\\("[^"]*"\\)').sub(String(lines[index]),
				'instance=ExtResource("%s")' % id)
		var xform := Transform3D(Basis(Vector3.UP, house.yaw), house.position)
		var line := "transform = " + var_to_str(xform)
		if index + 1 < lines.size() and String(lines[index + 1]).begins_with("transform = "):
			lines[index + 1] = line
		else:
			lines.insert(index + 1, line)
		moved += 1
	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	file.store_string("\n".join(PackedStringArray(lines)))
	file.close()
	print("Häuser verschoben: %d (Haustyp getauscht: %s, neu: %s)" % [moved, changed_types, added])


## Kennung der Szene eines Haustyps in houses.tscn (fehlt sie, wird sie oben ergänzt).
func _type_resource(lines: Array, type: String) -> String:
	var path := "res://scenes/world/houses/%s.tscn" % type
	var last := 0
	for i in lines.size():
		if String(lines[i]).begins_with("[ext_resource"):
			last = i
			if String(lines[i]).contains('path="%s"' % path):
				var found := RegEx.create_from_string('id="([^"]*)"').search(String(lines[i]))
				return found.get_string(1)
	var id := "t_" + type
	lines.insert(last + 1, '[ext_resource type="PackedScene" path="%s" id="%s"]' % [path, id])
	return id


## Neues Haus hinter dem letzten Haus seiner Gruppe einfügen (Farben aus der Planung); liefert die Zeile des Knotens.
func _insert_house(lines: Array, house: Dictionary, type_id: String) -> int:
	var group_header := '[node name="%s" type="Node3D"' % house.group
	var at := -1
	var in_group := false
	for i in lines.size():
		var line := String(lines[i])
		if line.begins_with(group_header):
			in_group = true
		elif in_group and line.begins_with("[node ") and not line.contains('parent="%s"' % house.group):
			at = i
			break
	if not in_group:
		return -1
	if at < 0:
		at = lines.size()
		while at > 0 and String(lines[at - 1]).strip_edges() == "":
			at -= 1
	var block := ['[node name="%s" parent="%s" instance=ExtResource("%s")]' % [house.name, house.group, type_id],
		"transform = " + var_to_str(Transform3D(Basis(Vector3.UP, house.yaw), house.position)),
		"wall_color = " + var_to_str(house.wall_color), "door_color = " + var_to_str(house.door_color),
		"casts_shadow = " + var_to_str(house.casts_shadow), "solid = " + var_to_str(house.solid)]
	for k in block.size():
		lines.insert(at + k, block[k])
	return at
