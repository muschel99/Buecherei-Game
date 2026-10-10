@tool
class_name ShopProp
extends Node3D
## Requisite in einem Laden (seit Etappe 4g): Schneiderpuppe mit Outfit oder hängendes
## Kleidungsstück. Die Modelle (assets/models/props/, aus tools/blender/build_props.py) nutzen
## das gemeinsame Stil-Material; ihre Stoffteile haben die Rolle "Akzentfarbe" – die Farbe
## stellt man hier je Stück ein (kostet nichts extra: Instanz-Werte).
## Kleidung ist vorerst Platzhalter: Später ersetzt ein eigenes Modell den Knoten "Outfit"
## (Puppe) bzw. "Model" (hängendes Teil); die Farbe wirkt dann nur, wenn das Modell die
## Rolle "accent" nutzt.

## Farbe des Stoffs.
@export var color: Color = Color(0.74, 0.58, 0.28):
	set(value):
		color = value
		_apply()
## Ab dieser Entfernung (Meter) wird die Requisite nicht mehr gezeichnet (spart Leistung).
@export var visible_distance: float = 25.0:
	set(value):
		visible_distance = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	for node: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		node.set_instance_shader_parameter("accent_color", color)
		# Im Laden: keine eigenen Schatten (Leistung), nur aus der Nähe sichtbar
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = visible_distance
