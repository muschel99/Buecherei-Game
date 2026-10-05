# Eigene Grafik und Sounds einbauen

Alle Objekte im Spiel bestehen im Moment aus einfachen Platzhaltern (Kisten, Zylinder, Farben).
Sie sind so gebaut, dass du sie später leicht durch eigene Dateien ersetzen kannst.

## Wohin mit meinen Dateien?
| Art             | Ordner                  | Formate             |
|-----------------|-------------------------|---------------------|
| 3D-Modelle      | `assets/models/`        | `.glb` (empfohlen)  |
| Texturen        | `assets/textures/`      | `.png`, `.jpg`      |
| Materialien     | `assets/materials/`     | `.tres` (Godot)     |
| Musik           | `assets/audio/music/`   | `.ogg`              |
| Geräusche       | `assets/audio/sfx/`     | `.ogg`, `.wav`      |

Dateien einfach in den passenden Ordner kopieren. Godot erkennt sie automatisch.

## Ein Möbelstück durch ein eigenes Modell ersetzen
Jede Möbel-Szene (z. B. `scenes/furniture/armchair.tscn`) hat diesen Aufbau:
```
Armchair        (Wurzel-Knoten)
├── Model       ← nur die Optik: hier kommt dein Modell hin
└── Body        ← die Kollision (damit man nicht durchlaufen kann)
```
1. Doppelklicke die Möbel-Szene im **Dateisystem**-Fenster (unten links), um sie zu öffnen.
2. Lösche alle Kinder des Knotens `Model` (die grauen Platzhalter-Kisten).
3. Ziehe deine `.glb`-Datei aus dem Dateisystem auf den Knoten `Model`.
4. Passe bei Bedarf Größe und Position an. Der Boden ist bei Höhe 0.
5. Passe im Knoten `Body > CollisionShape3D` die Kiste grob an die neue Form an.
6. Speichern mit **Strg+S**. Alle Exemplare im Raum ändern sich automatisch.

## Farben und Texturen von Wänden und Böden
Die Materialien liegen in `assets/materials/` (z. B. `wall_plaster.tres`, `floor_wood.tres`).
Doppelklicke ein Material, dann siehst du rechts im **Inspektor** die Eigenschaften:
- **Albedo > Color**: die Grundfarbe
- **Albedo > Texture**: hier eine Textur aus `assets/textures/` hineinziehen

Wände und Boden nutzen „Triplanar“-Mapping: Texturen werden automatisch gleichmäßig
über die Fläche gelegt. Die Kachelgröße stellst du unter **UV1 > Scale** ein.
