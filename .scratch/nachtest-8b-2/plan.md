# Zweiter Nachtest nach Etappe 8b (Liste der Entwicklerin, 16.11.2026)

Status: done

## Liste (handschriftlich)
- Schild zeigen → Kamera auf Boden
- To-do-Zettel muss über das Tablet, damit man die Todos lesen kann → Baumodus auch
- Vorschau Möbel Farben einstellen: Hintergrund wird schwarz, Möbel bleibt gleich
- Farben der Möbel sind falsch
- Bei Bedienung → neuer Kunde anschauen + grüßen; mit Laufen von der Theke weggehen
- „Geöffnet“-Schild komisch markiert beim Darüberschauen
- Brauchen mehr Gespräche, nicht mehrmals hintereinander dasselbe Gespräch
- Hitboxen beim Katzen-Streicheln

## Schritte
- [x] 1. Maklerin zeigt das Schild: Kamera schaut auf das Brett (`OpenSign.focus_point`) statt auf den Knoten am Scharnier (Fußboden)
- [x] 2. Schild beim Anschauen: Hervorhebung nie auf Schrift/Bilder (`FurnitureUtils.set_overlay` lässt Label3D/Sprite3D aus –
  vorher lag über jedem Buchstaben ein helles Kästchen)
- [x] 3. To-do-Zettel auf eigener Ebene über dem Tablet (`HUD.TodoLayer` 5, Tablet 4); am Tablet und im Gestaltungsmodus tritt
  er nicht mehr zurück; das Tablet rückt nach links, damit er daneben Platz hat (`CounterTablet._make_room_for_todo`,
  `TodoNote.room_needed`); mit Polaroids (App „Fassade“) tritt er zurück
- [x] 4. Möbelfarben: Vorhänge färben sich jetzt (der Stoff wird erst beim Aufhängen gebaut – `WindowCurtain.set_color_variant`);
  Rankgitter mit Kletterrose: Blüten hießen „b“, „l“, „o“, „m“ statt „bloom“ (Fehler im Bau-Script `climber`) – neu gebaut
- [x] 5. Vorschau in Farbe (schwarzer Hintergrund): mit TAA (Grafikstufe Mittel/Hoch) wird der durchsichtige Hintergrund der
  Fotos undurchsichtig schwarz (gemessen in 4.6.2 und 4.7: TAA Alpha 1, FXAA/MSAA 0) – `ThumbnailRenderer` nimmt FXAA statt TAA
  (`Settings.match_preview_quality(viewport, no_taa)`), `CACHE_VERSION` 3 macht die gespeicherten schwarzen Fotos neu.
  „Möbel bleibt gleich“: beim Leiterregal färbt die Farbe nur die dünnen Holme (Bretter sind Holz) – siehe Messung unten
- [x] 6. Theke: neuer Gast → Kamera schaut zu ihm hoch, er grüßt (lächelt, nickt, winkt manchmal), dann hinunter auf die
  Theke (`CounterDesk._look_at_guest_then_desk`, `desk_greet_*`); W A S D verlässt die Theken-Ansicht wie Esc
- [x] 7. Gespräche: viel mehr Sätze (Gruß, Plaudern, Fragen, Vertrautes, Abschied), kleine Geschichten über zwei Sprechblasen
  („ // “), eigene Sätze für Gäste in der Bücherei (Abschnitt `drinnen`), Gruß „Noch mal hallo!“ beim zweiten Gespräch
  (`wieder`); zuletzt Gesagtes kommt eine Weile nicht wieder (`TalkLines.pick`, `RECENT_SHARE`)
- [x] 8. Katzen streicheln: Zone folgt dem Körper in jeder Haltung (Kugel um den Kopf, Kapsel Hüfte–Hals,
  `StreetCat._update_pet_shapes`) statt einer festen großen Kugel
