class_name TabletAppData
extends Resource
## Datenblatt einer App auf dem Theken-Tablet (data/tablet_apps/<id>.tres).
##
## Neue App: eine kleine Szene bauen (Wurzel-Knoten mit einem Script, das von TabletApp erbt)
## und hier ein Datenblatt anlegen – der Startbildschirm zeigt sie dann von selbst an.
## Kein Code am Startbildschirm nötig.

## Wie das große Symbol auf dem Startbildschirm aussieht (gezeichnet, siehe TabletAppIcon).
enum Symbol { FURNISHING, BOOKS, STOCK, COLLECTION, GENERIC }

## Eindeutige Kennung (z. B. "stock").
@export var id: String = ""
## Name unter dem Symbol (kurz, ein Wort).
@export var display_name: String = ""
## Gezeichnetes Symbol …
@export var symbol: Symbol = Symbol.GENERIC
## … oder ein eigenes Bild (wenn gesetzt, wird es statt des gezeichneten Symbols gezeigt).
@export var custom_icon: Texture2D
## Farbe der Kachel hinter dem Symbol.
@export var color: Color = Color(0.45, 0.32, 0.22)
## Die Szene der App.
@export_file("*.tscn") var scene_path: String = ""
## Reihenfolge auf dem Startbildschirm (kleiner = weiter vorn).
@export var order: int = 0
## Ausgeschaltete Apps erscheinen nicht.
@export var is_enabled: bool = true
