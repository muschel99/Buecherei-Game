class_name StreetObstacle
extends Marker3D
## Ein fester Gegenstand draußen, um den Passanten herumgehen (seit Etappe 5a), z. B. die
## Eingangstreppe oder später eine Laterne oder Bank: ein Kreis mit diesem Radius um den Punkt.
## Größere Dinge bekommen mehrere Kreise. StreetLife liest alle beim Start
## (Gruppe StreetLife.OBSTACLE_GROUP). Häuser und Mauern brauchen das nicht – Passanten bleiben
## ohnehin auf ihren Wegen.

## Radius in Metern (Abstand, den die Mitte eines Passanten mindestens hält, kommt dazu).
@export var radius: float = 0.4


func _ready() -> void:
	add_to_group(StreetLife.OBSTACLE_GROUP)
