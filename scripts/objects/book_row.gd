@tool
class_name BookRow
extends Marker3D
## Ein Regalfach für Bücher (gehört zu einem BookShelf).
##
## Der Ursprung liegt mitten auf dem Regalbrett: in der Mitte der Breite und der Tiefe,
## genau auf der Oberkante des Bretts. Die Bücher stehen von links nach rechts, die Rücken
## zeigen nach vorn (+Z). Die Fächer werden in der Reihenfolge im Szenenbaum befüllt
## (am besten von oben nach unten).

## Nutzbare Breite des Fachs in Metern (von Seitenwand zu Seitenwand, etwas Luft lassen).
@export var width: float = 1.0
## Lichte Höhe bis zum nächsten Brett in Metern (höhere Bücher werden etwas kleiner).
@export var height: float = 0.4
## Tiefe des Bretts in Metern (die Bücher stehen vorn bündig).
@export var depth: float = 0.35
