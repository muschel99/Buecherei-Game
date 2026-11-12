class_name RoomTrim
extends RefCounted
## Zierleisten des Raums (seit Etappe 6j): eine schmale Stuckleiste rund um die Decke, die dem Grundriss folgt (auch der
## schrägen Eingangswand) und an den Ecken auf Gehrung stößt. Sie gehört fest zum Haus – wie die Sockelleiste – und
## bleibt bei jeder Wand- und Deckenfarbe.

## Querschnitt der Leiste: (Abstand von der Wand, Abstand unter der Decke) in Metern, von der Decke zur Wand.
const CORNICE := [Vector2(0.085, 0.0), Vector2(0.085, 0.012), Vector2(0.066, 0.02), Vector2(0.042, 0.04),
	Vector2(0.026, 0.066), Vector2(0.012, 0.074), Vector2(0.012, 0.09), Vector2(0.0, 0.09)]
const COLOR := Color(0.93, 0.9, 0.83)


## Leiste entlang des Grundrisses (Ecken in x/z, gegen den Uhrzeigersinn von oben in x/z gesehen), Oberkante auf height.
static func build_cornice(outline: PackedVector2Array, height: float) -> MeshInstance3D:
	var count := outline.size()
	# Gehrung: je Ecke die Richtung, in die ein Punkt mit Abstand 1 von beiden Wänden rückt
	var miters := PackedVector2Array()
	for i in count:
		var before := (outline[i] - outline[(i - 1 + count) % count]).normalized()
		var after := (outline[(i + 1) % count] - outline[i]).normalized()
		var n0 := Vector2(-before.y, before.x)
		var n1 := Vector2(-after.y, after.x)
		miters.append((n0 + n1) / (1.0 + n0.dot(n1)))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var j := (i + 1) % count
		for k in CORNICE.size() - 1:
			var a := _point(outline[i], miters[i], CORNICE[k], height)
			var b := _point(outline[j], miters[j], CORNICE[k], height)
			var c := _point(outline[j], miters[j], CORNICE[k + 1], height)
			var d := _point(outline[i], miters[i], CORNICE[k + 1], height)
			var normal := (b - a).cross(d - a).normalized()
			# die Fläche schaut in den Raum und nach unten
			var inward := Vector3(miters[i].x, 0.0, miters[i].y)
			if normal.dot(inward + Vector3.DOWN) < 0.0:
				normal = -normal
				tool.set_normal(normal)
				for p: Vector3 in [a, b, c, a, c, d]:
					tool.add_vertex(p)
			else:
				tool.set_normal(normal)
				for p: Vector3 in [a, c, b, a, d, c]:
					tool.add_vertex(p)
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.name = "Cornice"
	instance.mesh = tool.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func _point(corner: Vector2, miter: Vector2, profile: Vector2, height: float) -> Vector3:
	var p := corner + miter * profile.x
	return Vector3(p.x, height - profile.y, p.y)
