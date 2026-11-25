# 02 – Das Gelände hinter Bücherei und Pub (fertiger Zustand)
Status: ready-for-agent

Gebaut wird zuerst der **fertige Zustand** (Gasse offen, Garten gepflegt); Verwilderung und Sperren kommen in Zettel 07.

Maße (Godot, x nach links von der Straße aus gesehen positiv, z nach hinten): Bücherei x −3,2…3,2, Rückwand z 4,2; Gasse
x −6,0…−3,2; Pub x −11,6…−6,0, Rückwand z 5,92; Hinterzimmer x 3,2…6,6, z 1,72…4,72. Nach der Skizze (32 px ≈ 1 m):
- Garten etwa x −11,6 (rechte Kante des Pubs) … 5,1, von den Rückwänden bis zum Bach bei z ≈ 16,5; Bach etwa 1,3 m breit,
  dahinter (z ≈ 18,5) eine hohe Backsteinmauer (Rückseiten der Häuser der nächsten Straße).
- Platz für den Glasanbau hinter der Bücherei (x −3,2…3,2, z 4,2…≈8) und für das Holzhäuschen hinten links (x ≈ 2,6…9,5,
  z ≈ 10…16, schräge Front zum Garten) – beide werden in Zettel 03 und 05 gebaut.
- Der jetzige kleine Garten am Ende der Gasse (Baum bei −7,7 / 12,9 mit runder Bank, Vogelbad) wird Teil des großen Gartens.

Schritte:
1. Grundstück und Ränder: Boden (Rasen, Erde), Mauern ringsum (seitlich Gartenmauern bzw. Rückseiten der Nachbarhäuser), Bach
   mit Steinen, Schilf und Moos, der links und rechts unter einem Mauerbogen verschwindet, Backsteinmauer dahinter; die Gasse
   öffnet sich in den Garten. Kollision, die Spielfigur kann überall hin (nicht ins Wasser).
2. Leben im Garten: Katzen und Vögel (bisher Gartenhof in `bird_life.gd`, `cat_life.gd`) nutzen den großen Garten; Tier-Plätze
   neu ausmessen (`scenes/tools/bake_animal_spots.tscn`).
Gebaut mit `tools/blender/build_storybook_alleys.py` (Gassen, Garten) bzw. einem neuen Bau-Script; Maße in GameConfig.

## Comments

24.11.2026: Schritt 1 fertig. `tools/blender/build_storybook_backyard.py` baut `assets/models/world/backyard.glb` (Rasen, Kiesweg,
Trittsteine, Gartenmauern mit Steinkrone und Efeu, Bach mit Ufersteinen und Bögen samt dunklem Tunnel, Giebelhäuser hinter dem
Bach, Häute mit Fenstern auf den glatten Rückseiten der Nachbarhäuser, zwei Fenster oben an der Bücherei, Bank, Vogelbad). Die Gasse
(`scripts/world/alley.gd`) setzt es ein, Kollision an Mauern und über dem Bach. Der Boden ist überall flach – das Wasser liegt
4,5 cm hoch zwischen Ufersteinen. Noch offen (Schritt 2): Katzen/Vögel im ganzen Garten, Tier-Plätze, Wasser in Bewegung, Schilf.

25.11.2026: Hinweis für „Leben im ganzen Garten“: street_life_check --garden meldet manchmal „solid“ an der Vogeltränke
(„Garten 4“ bei x −6,65, z 11,3) – Spaziergänger gehen von der Gasse zu einem Sitzplatz der Bank, der direkt daneben liegt, und
laufen hindurch. Zufällig (gleicher Stand und Startwert: mal 0, mal 4), nicht durch den Garten-Umbau. Beim Verlegen von Baum und
Bank (näher ans Pub) die Vogeltränke als Hindernis für die Wege berücksichtigen.
