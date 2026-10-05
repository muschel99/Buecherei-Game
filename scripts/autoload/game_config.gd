extends Node
## Zentrale Spiel-Einstellungen.
##
## Dieses Script ist ein "Autoload": Godot lädt es beim Spielstart automatisch,
## und jedes andere Script kann darauf zugreifen, z. B. mit GameConfig.walk_speed.
## Hier kannst du Werte gefahrlos ändern, um das Spielgefühl anzupassen.


# --- Spielfigur: Bewegung ---

## Laufgeschwindigkeit in Metern pro Sekunde (gemütliches Schlendern ≈ 2.5).
var walk_speed: float = 2.6
## Laufgeschwindigkeit beim schnellen Laufen (Umschalttaste gedrückt halten).
var sprint_speed: float = 4.4
## Wie sanft zwischen normalem und schnellem Laufen gewechselt wird
## (Meter pro Sekunde, um die sich das Tempo pro Sekunde ändern darf; kleiner = sanfter).
var sprint_blend_rate: float = 3.5
## Wie schnell die Figur auf volle Geschwindigkeit kommt (höher = direkter).
var acceleration: float = 9.0
## Wie schnell die Figur wieder stehen bleibt (höher = abrupter).
var deceleration: float = 11.0
## Augenhöhe der Kamera über dem Boden in Metern.
var eye_height: float = 1.6
## Augenhöhe im Sitzen, gemessen über der Sitzfläche (in Metern).
var seated_eye_height: float = 0.72
## Wie lange das Hinsetzen bzw. Aufstehen dauert (in Sekunden).
var sit_transition_time: float = 0.6


# --- Spielfigur: Kamera und Maus ---

## Mausempfindlichkeit in Grad pro Pixel Mausbewegung.
var mouse_sensitivity: float = 0.12
## true = Maus nach oben schaut nach unten (wie in Flugsimulatoren).
var invert_mouse_y: bool = false
## Wie weit man maximal nach oben/unten schauen kann (in Grad).
var max_look_angle: float = 85.0
## Sichtfeld der Kamera in Grad (größer = mehr Weitwinkel).
var camera_fov: float = 72.0
## Stärke des sanften Kopfwippens beim Laufen in Metern (0 = aus).
var head_bob_amount: float = 0.02
## Tempo des Kopfwippens (höher = schnellere Schritte).
var head_bob_frequency: float = 4.5


# --- Interaktion ---

## Bis zu dieser Entfernung (in Metern) kann man Dinge mit E benutzen.
var interaction_distance: float = 2.5
## Größere Reichweite für schwer erreichbare Dinge wie Deckenlampen (in Metern).
var long_interaction_distance: float = 4.0
## Dauer, in der eine Lampe sanft an- oder ausgeht (in Sekunden).
var light_fade_time: float = 0.35
## Dauer, in der eine Kerzen- oder Laternenflamme erlischt bzw. aufflammt (in Sekunden).
var flame_fade_time: float = 0.6
## Soll der Lichtschalter auch Kerzen und Laternen mitschalten? (Standard: nur elektrische Lampen)
var light_switch_includes_flames: bool = false


# --- Gestaltungsmodus (Etappe 2) ---

## Kantenlänge eines Rasterfelds in Metern. Mit eingeschaltetem Einrasten (G)
## rasten Möbel auf diesem Raster ein. 1/9 m (≈ 11,1 cm) = 9 Felder pro Meter.
## So gehen Raumbreite (6 m) und Raumtiefe (8 m) ohne Rest in Abschnitte von
## 3 Feldern (= 1/3 m) auf.
var grid_cell_size: float = 1.0 / 9.0
## Ist das Einrasten beim Start des Spiels eingeschaltet? (Umschalten mit G)
var grid_enabled_at_start: bool = false
## Drehschritt in Grad pro Mausrad-Raste, wenn das Einrasten an ist.
var rotation_step_grid: float = 15.0
## Drehschritt in Grad pro Mausrad-Raste beim freien Platzieren (klein = fast stufenlos).
var rotation_step_free: float = 5.0
## Breite eines Wandabschnitts in Metern (jeder Abschnitt wird einzeln gestrichen).
var wall_segment_width: float = 1.0
## Boden und Decke werden in Abschnitten gestaltet: so viele Rasterfelder je Seite
## (3 = Abschnitte aus 3 x 3 Feldern, also 1/3 m x 1/3 m).
var floor_section_cells: int = 3
## Bis zu dieser Entfernung (in Metern) erscheint beim Streichen der Farbroller bzw. Teppich.
var paint_reach: float = 6.0
## Bis zu dieser Entfernung (in Metern) kann man im Gestaltungsmodus Möbel platzieren.
var build_reach: float = 9.0
## Deckkraft der Möbel-Vorschau (0 = unsichtbar, 1 = voll sichtbar).
var preview_opacity: float = 0.45
## Farbe der Vorschau, wenn das Möbel an diese Stelle passt.
var preview_color_valid: Color = Color(0.45, 0.9, 0.5)
## Farbe der Vorschau, wenn das Möbel hier nicht stehen kann.
var preview_color_invalid: Color = Color(1.0, 0.35, 0.3)
## Hervorhebung von Objekten (im Gestaltungsmodus und bei allem, was man mit E benutzen kann):
## Aufhellung des ganzen Objekts (0 = keine, 0.3 = deutlich).
var highlight_brightness: float = 0.06
## Heller Schimmer am Rand des Objekts (0 = kein Rand, 1 = sehr hell).
var highlight_rim_strength: float = 0.45
## Name der Währung, wie er im Katalog angezeigt wird.
var currency_name: String = "Taler"


# --- Speichern ---

## Datei, in der die Einrichtung gespeichert wird ("user://" = Benutzerdatenordner von Godot).
var save_file_path: String = "user://savegame.json"
## So viele Sekunden nach einer Änderung wird automatisch gespeichert.
var autosave_delay: float = 1.5


# --- Menü und Fenster ---

## Spiel automatisch pausieren, wenn das Spielfenster in den Hintergrund rückt.
var pause_on_focus_loss: bool = true


# --- Spätere Etappen ---
# Hier kommen nach und nach weitere Werte dazu, z. B.:
# Tageslänge (Etappe 5), Leihgebühren (Etappe 5),
# Freischaltintervalle (Etappe 8).
