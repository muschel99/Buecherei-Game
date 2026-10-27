class_name StreetSeat
extends SeatPoint
## Ein Sitzplatz an der Straße für Passanten (seit Etappe 5c): Bank (scenes/world/street_bench.tscn)
## oder Stuhl vor dem Pub (scenes/world/houses/pub.tscn). Wer vorbeigeht, setzt sich manchmal hin
## (StreetLife plant das wie den Blick ins Schaufenster: GameConfig.passerby_seat_chance).
## Lage = mitten auf der Sitzfläche, Blickrichtung +Z (wie jeder SeatPoint).

## Stelle, von der aus man zum Sitz geht (in den Koordinaten dieses Sitzes, Höhe egal): bei Bänken
## davor, bei Stühlen am Tisch seitlich zur Straße hin.
@export var approach := Vector3(0.0, 0.0, 0.8)
## So weit vor dem Sitz stellt man sich vor dem Hinsetzen hin (Meter; -1 = so weit wie in der
## Sitz-Animation – vor einem Tisch weniger, sonst steht man im Tisch).
@export var front := -1.0


func _ready() -> void:
	add_to_group(StreetLife.SEAT_GROUP)
