# Nachtest nach Etappe 8 (Liste der Entwicklerin vom 14.11.2026)

Status: claimed

## Wünsche (Wortlaut zusammengefasst)
- Nachts schwarze Linien (Malfilter; vorher dunkelblau)
- PC weg: der Bildschirm „Bücherei-Ausleihe“ kommt aufs Tablet – nur während der Bedienung, sonst als App im Tablet;
  der Kartenleser ist mit dem Tablet verbunden (Kabel); Tablet leicht schräg (gut lesbar hinter der Theke), weiter rechts
- Bücher von rechts nach links scannen (Scanner um 90° gedreht) und in eine Papiertüte packen (links), die der Gast bekommt
- Korb des Gasts steht beim Bedienen auf der Theke und gleitet danach unten rechts aus dem Bild (hinter die Theke)
- Körbe: erscheinen beim Hereinkommen und verschwinden nach dem Bedienen (kein Stapel an der Tür mehr)
- Kaching bei abgeschlossener Bedienung
- Bedien-Ansicht: mittig hinter der Theke, gerade, unterer Bildrand an der Thekenkante, alles sichtbar; die Aufteilung der
  Theke passt dazu
- Alle Schriften gemütlich und passend: Handschrift, wo sie passt, sonst etwas Technisches, aber cozy
- Bücher: verschiedene Schriftarten (keine Handschrift); Titel teils verzerrt und unlesbar
- Hinterzimmer: offene Tür = „andere Dimension“ (keine Möbel zu sehen, aus dem Zimmer nur Teile der Bücherei), Türrahmen
  flimmert; Zimmer soll an die Wand zum Modegeschäft (Modegeschäft hinten ausschneiden, Bücherei um einen Raum zur Seite
  erweitern), damit hinten Erweiterungen möglich sind und das Zimmer nicht im Weg ist
- Lesen: Buch wird zu nah am Körper gehalten

## Ursachen (gefunden)
- „Andere Dimension“: Verdecker (OccluderInstance3D, main.gd `_add_library_occluders`) sitzen genau in der Rückwand mit
  der Tür und in der rechten Wand – alles dahinter wird nicht gezeichnet

## Schritte (je Schritt hochladen, dann weiter)
- [x] 1. Kleinigkeiten: schwarze Linien nachts, Kaching am Ende der Bedienung, Lesehaltung (Buch weiter vom Körper)
- [x] 2. Hinterzimmer neu: rechts neben der Bücherei im hinteren Teil des Modegeschäfts (Laden des Modegeschäfts bleibt),
  Tür in der rechten Wand hinter der Theke, Verdecker mit Loch an der Tür, Türrahmen ohne Flimmern, alte Tür zu;
  hinter der Bücherei bleibt Platz für spätere Erweiterungen; alte Spielstände: Möbel ziehen mit um
- [ ] 3. Schriften: freie Schriften (npm @fontsource, OFL) – Handschrift für Notizen/Überschriften/Schilder, runde
  gemütliche Schrift für Tablet, Zahlen, Hinweise; Bücher mit mehreren Schriftarten (Serifen, schlicht, verspielt –
  keine Handschrift), verzerrte Titel beheben
- [x] 5. Nachtrag der Entwicklerin: Notizzettel am Morgen hängt manchmal oben links in der Ecke; nachts wirklich schwarze
  Linien prüfen (auch bei bläulichem Mondlicht)
- [x] 6. Pausenmenü: schmaleres, normales Buchformat (nicht quadratisch); Haftnotizen kleben sichtbar an IHREN Seiten (die
  anderen stecken zwischen den Seiten im Buch, links bzw. rechts im Seitenstapel); Sprung zwischen Notizen = EIN Umblättern
- [x] 7. Tippgeräusch der Sprechblasen aus „clicking tastatur.mp3“ (Game design, Sounds): leiser und gemütlicher aufbereitet
- [ ] 4. Theke neu: PC weg, Tablet rechts schräg mit Kartenleser (Kabel), Scanner gedreht, Tüte links, Korb rechts;
  Ansicht mittig und gerade; App „Ausleihe“; Körbe erscheinen/verschwinden, Gäste gehen mit der Papiertüte
