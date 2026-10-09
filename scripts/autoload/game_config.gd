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
## So lange muss man E gedrückt halten (z. B. am Regal: Regal-Menü öffnen), in Sekunden.
var interact_hold_time: float = 0.45
## So lange muss man die linke Maustaste gedrückt halten, um am Regal alle passenden
## getragenen Bücher einzuräumen (in Sekunden). Kürzer = ein Buch abstellen.
var place_all_hold_time: float = 0.5
## So weit öffnet sich die Eingangstür (in Grad).
var door_open_angle: float = 90.0
## So lange dauert das Öffnen bzw. Schließen der Tür (in Sekunden).
var door_open_time: float = 0.9


# --- Raum ---

## Raumhöhe vom Boden bis zur Decke in Metern (vorher 3,0 m). Wände, Decke, Wandabschnitte
## und Deckenbelag passen sich beim Start daran an. Am besten ein Vielfaches von 1/3 m nahe
## dem Wunschwert wählen – muss aber nicht.
var room_height: float = 3.2

## Eckladen (seit Etappe 4a): So weit (in Metern) ist die vordere linke Ecke abgeschrägt –
## dort sitzt die schräge Eingangswand mit der Ladentür. Dieser Wert legt fest, welcher
## Bereich im Raum bebaubar ist: die abgeschnittene Ecke bleibt frei (dort lässt sich nichts
## aufstellen). Die sichtbare Wand, die Fenster und die Tür sind in
## scenes/rooms/ground_floor_room.tscn für genau diesen Wert (2,0 m) gebaut – änderst du ihn
## stark, solltest du die Wand dort entsprechend anpassen.
var corner_cut: float = 2.0


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
## Wie stark die Cover-Kacheln in der Bücherauswahl in der Farbe ihres Genres hinterlegt sind
## (0 = gar nicht, 1 = ganz in der Genre-Farbe).
var book_picker_tint: float = 0.3
## Deckkraft der Vorschau ("Blaupause") beim Platzieren von Möbeln und Büchern
## (0 = unsichtbar, 1 = voll sichtbar). Nicht zu niedrig: sonst scheint Licht und Schatten von
## dahinter durch und die Vorschau sieht an Lichtinseln halb hell, halb dunkel aus.
var preview_opacity: float = 0.88
## Farbe der Vorschau, wenn das Möbel bzw. Buch an diese Stelle passt (ruhiges Blau).
var preview_color_valid: Color = Color(0.45, 0.65, 0.95)
## Farbe der Vorschau, wenn es hier nicht stehen kann.
var preview_color_invalid: Color = Color(0.95, 0.4, 0.35)
## Hervorhebung von Objekten (im Gestaltungsmodus und bei allem, was man mit E benutzen kann):
## Aufhellung des ganzen Objekts (0 = keine, 0.3 = deutlich).
var highlight_brightness: float = 0.06
## Heller Schimmer am Rand des Objekts (0 = kein Rand, 1 = sehr hell).
var highlight_rim_strength: float = 0.45
## Regal-Menü: Ein Fach, dessen Auswahl ich anfahre, leuchtet so hell auf (Fläche, Kanten).
var fach_highlight_fill: float = 0.07
var fach_highlight_edge: float = 0.5
## Regal-Menü: So weit (in Grad) darf die Ansicht höchstens herauszoomen, damit das ganze
## Regal neben das Tablet passt; so lange (in Sekunden) gleitet die Ansicht dorthin.
var shelf_menu_max_fov: float = 100.0
var shelf_menu_view_time: float = 0.35


# --- Geld, Shop und Lieferung ---

## Name der Währung, wie er im Spiel angezeigt wird.
var currency_name: String = "Taler"
## Kontostand beim allerersten Start (neues Spiel).
var start_money: int = 500
## Anteil des Preises, den man beim Verkaufen zurückbekommt (0.5 = 50 %).
var sell_price_share: float = 0.5
## So viele Sekunden nach dem Bestellen steht der Karton vor der Tür.
var delivery_time: float = 10.0
## So lange dauert das Auspacken eines Kartons (die kleine Animation, in Sekunden).
var unpack_time: float = 0.7
## Kartons vor der Tür: so viele Stapel nebeneinander an der Hauswand (danach eine Reihe davor).
var delivery_stacks_per_row: int = 4
## So viele Kartons höchstens übereinander (ist alles voll, wird trotzdem weiter gestapelt).
var delivery_stack_height: int = 3
## Kartons stehen leicht schief, damit es natürlich aussieht: größte Drehung in Grad.
var delivery_box_turn: float = 8.0
## Lager-Anzeige unten rechts: Abstand zwischen zwei Symbolen, wenn mehrere Dinge kurz
## hintereinander ins Lager gehen (in Sekunden). Kleiner = schneller hintereinander.
var storage_icon_interval: float = 0.7
## So lange bleibt das Lager-Symbol nach dem letzten Einlagern sichtbar (in Sekunden).
var storage_hide_delay: float = 2.5
## So lange bleibt ein Hinweis wie "Deine Lieferung ist da" zu sehen (in Sekunden).
var notice_time: float = 4.0


# --- Bücher und Regale (Etappe 3) ---

## So viele Bücher stecken in einem Bücherpaket aus dem Shop (der Preis steht im Genre-Datenblatt).
var books_per_package: int = 10
## So viele Bücher je freigeschaltetem Genre liegen beim allerersten Start im Lager.
var start_books_per_genre: int = 12
## Das besitze ich zum Start zusätzlich im Inventar (id aus data/furniture/ -> Anzahl).
## Kommt auch in ältere Spielstände, aber nur einmal. (Der Rückgabekasten ist seit Etappe 3l
## fest in der Wand eingebaut und kein Geschenk mehr.)
var start_furniture_gifts: Dictionary = {}
## Ein Buch gleitet in so vielen Sekunden ins Regal (bzw. heraus).
var book_slide_time: float = 0.35
## Abstand zwischen zwei Büchern, die nacheinander ins Regal gleiten (in Sekunden).
## Kleiner = schneller hintereinander. Viele Bücher auf einmal werden automatisch schneller.
var book_slide_interval: float = 0.035
## So lange dauert das Einräumen höchstens, egal wie viele Bücher es sind (in Sekunden).
var book_slide_max_total: float = 2.5
## Buchgrößen im Regal in Metern: Höhe, Dicke (Rücken) und Tiefe – jeweils von bis.
## Jedes Buch bekommt feste Werte dazwischen (passend zur Fachhöhe).
var book_height_range: Vector2 = Vector2(0.19, 0.31)
var book_thickness_range: Vector2 = Vector2(0.022, 0.048)
var book_depth_range: Vector2 = Vector2(0.15, 0.21)
## Wie stark der Farbton der Buchrücken schwankt (0 = alle Bücher eines Genres gleich).
var book_color_variation: float = 1.0

## So viele Bücher kann ich höchstens gleichzeitig tragen.
var max_carried_books: int = 7
## So lange Q gedrückt halten, um alle getragenen Bücher ins Lager zu legen (in Sekunden).
var store_books_hold_time: float = 0.6

## So lange (in Sekunden) muss ich ein Buch anschauen, bis seine kleine Infokarte erscheint
## (nicht bei jedem flüchtigen Blick).
var book_info_delay: float = 0.5
## So lange (in Sekunden) zeigt die Infokarte ein neues Buch obenauf in meiner Hand
## (z. B. nach dem Nehmen oder Blättern mit E).
var book_info_hand_time: float = 2.5

## Bücher frei ablegen (Tisch, Theke, Boden …): So weit (in Grad) liegt ein Buch zufällig
## schräg, damit es natürlich wirkt.
var loose_book_yaw_jitter: float = 6.0
## So viele Bücher passen höchstens übereinander auf einen Stapel.
var loose_book_stack_max: int = 10
## So weit lehnt ein Buch an der Wand nach hinten (in Grad).
var loose_book_lean_angle: float = 10.0
## Drehen mit dem Mausrad vor dem Ablegen: Schritt in Grad pro Mausrad-Raste
## (z. B. 5 = fast stufenlos, 90 = nur gerade Lagen).
var book_turn_step: float = 15.0
## An die Wand gelehnte Bücher lassen sich höchstens so weit (in Grad) zur Seite drehen –
## weiter wäre das Cover nicht mehr zu sehen.
var loose_book_lean_max_turn: float = 30.0
## Schaue ich auf eine Wand oder Möbelseite, wird bis so weit darunter (in Metern) ein Boden
## oder eine Ablage gesucht, auf die das Buch kommt.
var loose_book_ground_reach: float = 0.8

## Das angeschaute Buch rutscht ein Stück aus dem Regal (in Metern).
var book_hover_pull: float = 0.015
## So weit vor dem Regal schwebt die Vorschau, wenn das Buch zwischen andere geschoben wird
## (in Metern). An einer freien Stelle steht die Vorschau genau dort, wo das Buch hinkommt.
var book_insert_preview_pull: float = 0.06
## Feines Raster auf jedem Regalbrett: Bücher werden in diesen Schritten abgestellt (in Metern).
var shelf_grid_step: float = 0.01
## Steht ein Buch näher als das an einem Nachbarn (Buch, Deko, Seitenwand), rückt es bündig
## heran (in Metern).
var shelf_snap_distance: float = 0.025
## Stelle ich ein Buch so nah neben eine Buchstütze (auf Tisch, Boden …), steht es aufrecht
## und bündig daran (in Metern). Die Buchstütze selbst rastet nie an Büchern ein.
var bookend_snap_distance: float = 0.05


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
##   shadow_size     Schattenauflösung der Lampen in Pixeln (größer = schärfer, teurer)
##   sun_shadow_size Schattenauflösung der Sonne in Pixeln (Fensterlicht)
##   soft_shadows    Weichheit der Schattenkanten 0 = hart, 1 = sehr niedrig, 2 = niedrig, 3 = mittel
##   lamp_shadows    0 = Lampen ohne Schatten, 1 = nur wichtige Lampen (Steh- und Tischlampen),
##                   2 = auch Deckenlampen. Nie Schatten: Kerzen, Laternen, Kronleuchter und
##                   Rattan-Hängelampe (ihr Licht sitzt zwischen vielen Teilen – deren Schatten
##                   sähen seltsam aus). Einstellung je Lampe: LightSource.shadow_importance.
##   cube_shadows    Lampenschatten in voller Qualität (6 statt 2 Durchgänge je Lampe)
##   sun_cascades    Schattenstufen der Sonne: 2 (schneller) oder 4 (schärfer in der Nähe).
##                   Die Übergänge werden immer weich überblendet (sonst Linie im Fensterlicht).
##   dust_amount     Anteil der Staubteilchen im Lichtstrahl (1 = alle)
##   render_scale    Auflösung der 3D-Ansicht (1 = voll, 0.8 = etwas weicher, schneller)
var graphics_presets: Array[Dictionary] = [
	{"ssao": false, "ssao_half_size": true, "ssil": false, "volumetric_fog": false, "fog_volume_size": 48,
		"msaa": 0, "fxaa": true, "shadow_size": 1024, "sun_shadow_size": 2048, "soft_shadows": 1, "lamp_shadows": 0,
		"cube_shadows": false, "sun_cascades": 2, "dust_amount": 0.5, "render_scale": 0.8},
	{"ssao": true, "ssao_half_size": true, "ssil": false, "volumetric_fog": true, "fog_volume_size": 48,
		"msaa": 0, "fxaa": true, "shadow_size": 2048, "sun_shadow_size": 2048, "soft_shadows": 2, "lamp_shadows": 1,
		"cube_shadows": false, "sun_cascades": 4, "dust_amount": 1.0, "render_scale": 1.0},
	{"ssao": true, "ssao_half_size": false, "ssil": true, "volumetric_fog": true, "fog_volume_size": 64,
		"msaa": 2, "fxaa": false, "shadow_size": 4096, "sun_shadow_size": 4096, "soft_shadows": 3, "lamp_shadows": 2,
		"cube_shadows": true, "sun_cascades": 4, "dust_amount": 1.0, "render_scale": 1.0},
]
## Bis zu dieser Entfernung (in Metern) wirft die Sonne Schatten. Der Raum ist 8 m tief –
## 20 m reichen auch für den Blick von der Gasse. Kleiner = schärfere Schatten in der Nähe.
var sun_shadow_distance: float = 20.0
## Bei 2 Schattenstufen (Grafikstufe Niedrig): Grenze zwischen feiner und grober Stufe als
## Anteil der Schattenweite (0.3 = nach 6 m). So liegt das Fensterlicht meist in der feinen.
var sun_two_cascade_split: float = 0.3
## Höchstens so viele Bilder pro Sekunde, solange das Pausenmenü offen ist (spart Strom).
var paused_max_fps: int = 30


# --- Menü und Fenster ---

## Spiel automatisch pausieren, wenn das Spielfenster in den Hintergrund rückt.
var pause_on_focus_loss: bool = true


# --- Theke ---

## Stil der Theke beim allerersten Start (id aus CounterStyle.STYLES). Den Stil wechsle ich
## im Spiel über das Theken-Tablet in der App "Fassade".
var counter_default_style: String = "wood_warm"


# --- Rückgabekasten ---

## So viele Bücher passen in den Rückgabekasten. Ist er voll, nimmt er nichts mehr an.
var return_box_capacity: int = 50
## Einwurf-Variante zum Start (id aus data/return_slots/).
var return_box_default_slot: String = "slot_plain"


# --- Testtasten (nur zum Ausprobieren) ---

## Schaltet alle Testtasten auf einmal ein oder aus (F9 = Bücher in den Rückgabekasten,
## F10 = Testgeld). Für die fertige Version auf false setzen.
var debug_keys_enabled: bool = true
## So viele Bücher legt die Testtaste F9 auf einmal in den Rückgabekasten.
var debug_return_box_books: int = 7
## So viel Geld gibt die Testtaste F10 bei jedem Drücken.
var debug_money_amount: int = 500


# --- Spätere Etappen ---
# Hier kommen nach und nach weitere Werte dazu, z. B.:
# Tageslänge (Etappe 5), Leihgebühren (Etappe 5),
# Freischaltintervalle (Etappe 8).
