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

# --- Spielfigur: Springen und Hocken ---

## Wie hoch die Figur springt (in Metern). 0.8 reicht für Sessel, Sofa und Tisch.
var jump_height: float = 0.8
## Schwerkraft in der Luft im Verhältnis zur normalen (kleiner = weicher, schwebender Sprung).
## Gilt beim Springen und Fallen, damit sich beides gemütlich anfühlt.
var air_gravity_scale: float = 0.7
## Augenhöhe in der Hocke (in Metern über dem Boden).
var crouch_eye_height: float = 1.0
## Körperhöhe in der Hocke (in Metern) – so niedrig kann man sich bücken.
var crouch_body_height: float = 1.15
## Laufgeschwindigkeit in der Hocke (Meter pro Sekunde).
var crouch_speed: float = 1.3
## Wie schnell sich die Kamera beim Hocken senkt und hebt (Meter pro Sekunde).
var crouch_transition_speed: float = 3.0
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
## So weit öffnet sich die Eingangstür (in Grad).
var door_open_angle: float = 90.0
## So lange dauert das Öffnen bzw. Schließen der Tür (in Sekunden).
var door_open_time: float = 0.9


# --- Raum ---

## Raumhöhe vom Boden bis zur Decke in Metern (vorher 3,0 m). Wände, Decke, Wandabschnitte
## und Deckenbelag passen sich beim Start daran an. Am besten ein Vielfaches von 1/3 m nahe
## dem Wunschwert wählen – muss aber nicht.
var room_height: float = 3.2


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


# --- Geld, Shop und Lieferung ---

## Name der Währung, wie er im Spiel angezeigt wird.
var currency_name: String = "Taler"
## Kontostand beim allerersten Start (neues Spiel).
var start_money: int = 500


# --- Speichern ---

## Datei, in der die Einrichtung gespeichert wird ("user://" = Benutzerdatenordner von Godot).
var save_file_path: String = "user://savegame.json"
## So viele Sekunden nach einer Änderung wird automatisch gespeichert.
var autosave_delay: float = 1.5


# --- Grafikstufen (Leistung) ---

## Was die Grafikstufen Niedrig (0), Mittel (1) und Hoch (2) einschalten.
## Welche Stufe gilt, wählt man im Spiel unter Esc → Einstellungen → Grafik.
##   ssao            Umgebungsverdeckung (weiche Schatten in Ecken)
##   ssao_half_size  SSAO in halber Auflösung berechnen (spart viel, sieht fast gleich aus)
##   ssil            Indirektes Licht (Licht wird von Flächen zurückgeworfen) – sehr teuer
##   volumetric_fog  Lichtstrahlen im Staub (z. B. am Fenster)
##   fog_volume_size Genauigkeit der Lichtstrahlen (kleiner = schneller)
##   msaa            Kantenglättung 0 / 2 / 4 (teurer), fxaa = einfache, günstige Glättung
##   shadow_size     Schattenauflösung in Pixeln (größer = schärfer, teurer)
##   soft_shadows    Weichheit der Schattenkanten 0 = hart, 1 = niedrig, 2 = mittel
##   lamp_shadows    0 = Lampen ohne Schatten, 1 = nur wichtige Lampen (Steh- und Tischlampen),
##                   2 = auch Deckenlampen. Kerzen und Laternen werfen nie eigene Schatten.
##   cube_shadows    Lampenschatten in voller Qualität (6 statt 2 Durchgänge je Lampe)
##   dust_amount     Anteil der Staubteilchen im Lichtstrahl (1 = alle)
##   render_scale    Auflösung der 3D-Ansicht (1 = voll, 0.8 = etwas weicher, schneller)
var graphics_presets: Array[Dictionary] = [
	{"ssao": false, "ssao_half_size": true, "ssil": false, "volumetric_fog": false, "fog_volume_size": 48,
		"msaa": 0, "fxaa": true, "shadow_size": 1024, "soft_shadows": 0, "lamp_shadows": 0,
		"cube_shadows": false, "dust_amount": 0.5, "render_scale": 0.8},
	{"ssao": true, "ssao_half_size": true, "ssil": false, "volumetric_fog": true, "fog_volume_size": 48,
		"msaa": 0, "fxaa": true, "shadow_size": 2048, "soft_shadows": 1, "lamp_shadows": 1,
		"cube_shadows": false, "dust_amount": 1.0, "render_scale": 1.0},
	{"ssao": true, "ssao_half_size": false, "ssil": true, "volumetric_fog": true, "fog_volume_size": 64,
		"msaa": 2, "fxaa": false, "shadow_size": 4096, "soft_shadows": 2, "lamp_shadows": 2,
		"cube_shadows": true, "dust_amount": 1.0, "render_scale": 1.0},
]
## Höchstens so viele Bilder pro Sekunde, solange das Pausenmenü offen ist (spart Strom).
var paused_max_fps: int = 30


# --- Menü und Fenster ---

## Spiel automatisch pausieren, wenn das Spielfenster in den Hintergrund rückt.
var pause_on_focus_loss: bool = true


# --- Spätere Etappen ---
# Hier kommen nach und nach weitere Werte dazu, z. B.:
# Tageslänge (Etappe 5), Leihgebühren (Etappe 5),
# Freischaltintervalle (Etappe 8).
