@tool
class_name PlantPiece
extends Node3D
## Eine Pflanze im Bilderbuch-Stil (Stil-Umbau, Etappe 4h, Schritt 5) – Wurzel jeder Pflanzen-Szene in
## scenes/world/plants/. Greenery setzt diese Szenen auf die Pflanzplätze („PlantSpot_…“ in den Modellen
## der Häuser, Läden und Gassen). Austauschbar: eigenes Modell als Kind "Model" (Ursprung wie die Vorlage
## assets/models/templates/plants/<kind>.glb) oder eine neue Szene mit diesem Script in den Ordner legen.
##
## Ursprung = Pflanzplatz: Erde im Kasten/Topf, Fuß an der Wand (Kletterpflanzen: Wand bei z = 0,
## Pflanze davor), Boden (Beet, Hecke, Baum). Vorderseite (zur Straße) = +Z, oben = +Y.

## Art des Pflanzplatzes: box (Blumenkasten, wird in der Breite mehrfach gereiht), potfill (in einen
## vorhandenen Topf), basket (Ampel), pot (Topf mit Pflanze vor der Tür), climber (Kletterpflanze),
## bed (Beet), hedge (Hecke), tree (Baum), tubtree (Bäumchen im Kübel auf dem Platz).
@export var kind := "box"
## Maß, an dem die Pflanze gebaut ist (Breite x, Höhe y, Tiefe z) in Metern – Greenery skaliert danach.
@export var nominal_size := Vector3(0.3, 0.4, 0.16)
## Wie oft diese Pflanze gewählt wird (1 = normal, 0 = nie).
@export var weight := 1.0
## > 0: feste Kollision (Zylinder mit diesem Radius) und Hindernis für Passanten.
@export var collision_radius := 0.0
## Passt besonders zu Plätzen mit diesem Hinweis (z. B. "tall" = hoher Topf, "wisteria" = Torhaus).
@export var hint := ""
