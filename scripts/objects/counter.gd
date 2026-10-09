extends Node3D
## Die Theke im Laden. Sie gehört fest zum Laden (siehe data/furniture/counter_register.tres:
## is_fixed, is_essential) und lässt sich nur verschieben, nicht wegräumen.
##
## Ihren Stil (Farben von Korpus, Frontblende und Platte) holt sie sich zentral von CounterStyle
## und färbt sich danach. Ändere ich den Stil (am Tablet in der App "Fassade"), meldet CounterStyle
## das über sein Signal "changed", und die Theke färbt sich sofort um.
##
## Module (z. B. später eine Backshop-Auslage oder ein Kaffeeautomat) hängen unter dem Knoten
## "Modules" – die Struktur steht bereit, umgesetzt wird davon noch nichts.

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	CounterStyle.changed.connect(_apply_style)
	_apply_style()


## Färbt die drei Teile der Theke nach der gewählten Stilvariante.
func _apply_style() -> void:
	var style := CounterStyle.get_style()
	_color_part("Model/Cabinet", style.get("cabinet"))
	_color_part("Model/FrontPanel", style.get("panel"))
	_color_part("Model/Top", style.get("top"))


func _color_part(path: NodePath, color: Variant) -> void:
	var mesh := get_node_or_null(path) as MeshInstance3D
	if mesh == null or not (color is Color):
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	mesh.material_override = material
