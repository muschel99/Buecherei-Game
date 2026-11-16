# Große Überarbeitung: schöner, gemütlicher, befriedigender (Auftrag vom 16.11.2026)

Status: ready-for-agent

Wunsch der Entwicklerin: „Das Spiel schöner, gemütlicher und mehr satisfying gestalten. Du kannst alles
überarbeiten … und bei Bedarf vom Stil abweichen.“ Backup vorher: Zweig `backup/vor-ueberarbeitung` und
Tag `backup-vor-ueberarbeitung` auf GitHub (Stand 45f18c1f).

Antworten auf die Fragen:
- **Jahreszeiten** soll es mehrere geben – wenn nur eine: **gemütlicher Herbst**. → System für Jahreszeiten,
  Herbst als erste (Sommer = Aussehen wie bisher), später Winter/Frühling.
- **Startfassade:** alt, aber liebenswert (keine großen Putzflecken mehr).
- **Leistung:** RX 6800, 60–110 FPS auf Hoch; Mikroruckler (z. B. Passanten umkreisen, Kamera auf ihn) und
  gelegentlich Hänger von ein paar Sekunden → mit beheben.

Vorher-Bilder: `screenshots/*-vorher.png`, `*-abend_vorher.png` (nicht in Git).

## Befund (Rundgang mit Testbildern)
- Straße bei Tag schön, aber etwas blass und flach (helle Gehwege fast weiß, wenig Tiefe); abends schon gut.
- Die Bücherei selbst ist das schwächste Haus: große helle Putzflecken wie Tarnmuster, graues leeres
  Schaufenster, kaum Pflanzen.
- Laden innen: kahle Wände, flaches Licht, wirkt leer (Absicht: man richtet ein – aber auch leer soll er
  gemütlich sein).
- Rückmeldung beim Tun fehlt fast ganz: Möbel aufstellen/aufheben und Wände streichen ohne Ton und
  Bewegung, Geld springt nur um.
- Ruckeln: Spielfigur, Passanten, Autos und Tiere bewegen sich im festen Physik-Takt (60/s), das Bild läuft
  mit 60–110/s – ohne Zwischenschritte stottert alles, was sich bewegt, sobald die Kamera mitgeht.

## Teile (je ein Commit, nach jedem Teil testet die Entwicklerin)
1. [x] **Flüssiger:** Bewegungen zwischen den Physik-Schritten weich (Physik-Interpolation für Spielfigur,
   Passanten, Fahrzeuge, Tiere); „Ruckel-Protokoll“: Bilder über 100 ms werden mit Ursache in
   `user://hitches.log` notiert (Shader-Vorbereitung, Speichern, …), damit wir die Hänger finden.
2. [x] **Licht und Farbe:** eigene Farbabstimmung (Bilderbuch: warme Lichter, weiche, leicht kühle
   Schatten), zarter warmer Dunst in der Ferne, goldeneres Licht; innen wärmeres Licht und Lichtstrahlen.
3. [x] **Herbst:** Autoload `Season` + Einstellung; Laub der Bäume/Büsche färbt sich, wilder Wein rot,
   Blätter fallen und wehen über die Straße, Laub sammelt sich am Rand, Kürbisse und Astern vor den Läden.
4. [~] **Bücherei außen:** Startfassade alt, aber liebenswert (feine Verwitterung, Moos, verblasste Farbe),
   warmes Licht im Schaufenster.
5. [x] **Befriedigende Rückmeldung:** Möbel ploppen weich hin (kleines Federn, Staubwölkchen, Holz-Ton je
   Größe), Aufheben hüpft, Streichen breitet sich als Welle aus (mit Ton), Geld zählt hoch (Münzklang), volles
   Regalfach funkelt kurz, Knöpfe federn.
6. [ ] **Laden innen:** schönere Startflächen, warme Lichtinseln, Staub im Sonnenlicht.

Danach: ROADMAP + Notion, CLAUDE.md-Notizen, Prüfung mit Godot 4.6.2.

## Stand (16.11.2026, erste Runde)
- Teil 1 committet (78180509). Teile 2, 3, 5 gebaut: CozyGrade, Dunst, Raum-Staub, Tiefenunschärfe, Gehweg; Season +
  Herbstlaub-Shader, AutumnLeaves (fallend + am Boden), AutumnDecor (Kürbisse); BuildFeedback (plumpsen, Staub, Funken,
  Streich-Welle, Farbtropfen), volles Fach funkelt, Geld zählt/hüpft, Knöpfe federn, neue Geräusche.
- Teil 4 halb: Verwitterung liebenswert (kleine Putzinseln, Moos). Offen: warmes Schaufenster der Bücherei.
- Teil 6 offen (Innenraum) – bisher nur Licht/Farbe/Staub.
- Wunsch nach der ersten Runde: „noch Platz für schönere Grafik oder ein paar mehr Animationen“ → großzügiger bauen.
