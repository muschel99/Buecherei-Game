# Etappe 6j – Rundgang und Feinschliff (Karte)

Status: claimed

## Auftrag (aus /grill-me am 11.11.2026)
Das ganze Spiel genau anschauen und es schöner, natürlicher, flüssiger und einfach besser machen.
Claude entscheidet selbst, was sinnvoll ist, und setzt es um. Die Entwicklerin prüft erst am Ende.

## Entscheidungen
- Testbilder sind für diese Prüfung erlaubt; danach gilt wieder „keine Bilder nötig“.
- PC der Entwicklerin: Grafikstufe Mittel, bis zu 160 FPS, kein Ruckeln. Leistung nur nebenbei verbessern, ohne dass es schlechter aussieht; auch „Hoch“ soll flüssig bleiben.
- Was sie stört: falsch zusammengebaute Teile, Netzfehler bei Figuren und Tieren, Passanten blockieren sich gegenseitig, beim Reden auf der Bank drehen sie den Kopf fast nach hinten. Dazu sucht Claude selbst weiter.
- „Natürlicher“ heißt: Logik des Spiels und der Gegenstände, Licht und Farben (b), die Welt (d).
- Neues ist erlaubt, wenn es sinnvoll ist und passt.
- Ablauf in Abschnitten. Nach jedem Abschnitt Commit und Push, am Ende Zusammenfassung und Test-Liste.
- Innenraum der Bücherei im Bilderbuch-Stil (Wände, Boden, Decke, Laibungen); die Auswahl im Gestaltungsmodus bleibt.
- Weltlicht abstimmen (warm, ca. 3500 K, weiche Schatten, leichtes Leuchten, mehr AO). Den Sonnenstand dürfen wir so ändern, dass das Licht gut passt. Die alten Werte als Kommentar notieren.
- Die alten 5b-Figuren löschen, aber erst nach der Prüfung, ob sie noch benutzt werden. `base_quaternius` bleibt.
- Neue Etappe „6j – Rundgang und Feinschliff“ in ROADMAP.md und Notion.

## Abschnitte
1. Fehler: Kopfdrehen auf der Bank, sich blockierende Passanten, Netzfehler (Figuren/Tiere), falsch zusammengebaute Teile
2. Logik des Spiels und der Gegenstände
3. Licht und Sonne, Innenraum der Bücherei
4. Neues, Leistung, Aufräumen (5b-Figuren)
5. Roadmap und Notion, Test-Liste

## Decisions-so-far
- Teil 1 (Commit 09557d8): Kopf beim Plaudern auf der Bank höchstens 68° gegen die Hüfte (ChibiHeadModifier, Blick ersetzt die
  Kopfdrehung der Animation); Passanten drücken sich an Engstellen vorbei (Passerby.squeeze), warten neben der Tür, Paare und
  Bank-Nachbarn halten sich nicht mehr fest, Schaufenster-Wege frei von Kübeln/Fahrrädern, Überqueren nach 15 s aufgegeben;
  Autos fahren langsam an Leuten am Fahrbahnrand vorbei. Innenraum: Dielen/Putz-Shader, Stuckleiste (RoomTrim), Tageslicht
  durch die Fenster (Render-Ebene 3), Rahmen und Tür innen ohne Verwitterung.
- Teil 2 (Commit f6b86a8): Säume im Shader abgeschnitten (UV.x = Abstand zur Schnittlinie), Haut unter langen Hosen in
  Hosenfarbe, Rock-Form "sit" im Sitzen; pose_probe grid/close/animal. Tiere: keine Netzfehler gefunden.
- Teil 3: Lichtstimmung in GameConfig (light_*), Sonne 42°/36°, Laternen tagsüber aus (street_lanterns_lit), Rauch aus
  Schornsteinen (ChimneySmoke), alte 5b-Figuren gelöscht.

## Fog
- Welche Netzfehler genau gemeint sind: selbst suchen (Posen-Prüfungen, Testbilder)
