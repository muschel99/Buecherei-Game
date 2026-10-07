class_name PlacementSurface
extends Area3D
## Eine Ablagefläche: Hier darf Deko stehen (Tischplatte, Regalbrett, Sitzfläche,
## Armlehne, Fensterbank …).
##
## So legst du eine Ablagefläche an:
## 1. Dem Möbelstück einen Kind-Knoten vom Typ "PlacementSurface" hinzufügen.
## 2. Den Knoten genau auf die Höhe der Fläche schieben (der Ursprung = Oberkante).
## 3. Ihm eine CollisionShape3D mit einer flachen BoxShape3D geben, so groß wie die Fläche
##    (Höhe z. B. 0,03 m, mittig auf dem Ursprung).
## Ein Möbelstück kann beliebig viele Ablageflächen haben.
## Bücherregale bekommen für jedes Brett automatisch eine Ablagefläche (siehe BookShelf).

## Physik-Ebene 6 = "placement_surface" (als Bit-Wert 32).
const SURFACE_LAYER_BIT := 32

## Lichte Höhe über der Fläche (z. B. bis zum nächsten Regalbrett) in Metern:
## Höhere Dinge passen hier nicht hin. 0 = keine Grenze.
@export var max_height: float = 0.0


func _ready() -> void:
	collision_layer = SURFACE_LAYER_BIT
	collision_mask = 0
	monitoring = false


## Höhe der Fläche in der Welt.
func get_surface_height() -> float:
	return global_position.y
