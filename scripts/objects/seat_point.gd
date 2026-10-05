class_name SeatPoint
extends Marker3D
## Ein Sitzplatz: liegt mitten auf der Sitzfläche, die Blickrichtung ist +Z
## (die Vorderseite des Sitzmöbels). Ein Sofa hat mehrere davon.
## Später setzen sich hier auch Besucher hin.

## Wer sitzt gerade hier? (null = frei)
var occupant: Node = null


func is_free() -> bool:
	return occupant == null or not is_instance_valid(occupant)
