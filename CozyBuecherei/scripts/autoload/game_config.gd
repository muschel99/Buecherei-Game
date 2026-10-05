extends Node
## Zentrale Spiel-Einstellungen.
##
## Dieses Script ist ein "Autoload": Godot lädt es beim Spielstart automatisch,
## und jedes andere Script kann darauf zugreifen, z. B. mit GameConfig.walk_speed.
## Hier kannst du Werte gefahrlos ändern, um das Spielgefühl anzupassen.


# --- Spielfigur: Bewegung ---

## Laufgeschwindigkeit in Metern pro Sekunde (gemütliches Schlendern ≈ 2.5).
var walk_speed: float = 2.6
## Wie schnell die Figur auf volle Geschwindigkeit kommt (höher = direkter).
var acceleration: float = 9.0
## Wie schnell die Figur wieder stehen bleibt (höher = abrupter).
var deceleration: float = 11.0
## Augenhöhe der Kamera über dem Boden in Metern.
var eye_height: float = 1.6


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
## Dauer, in der eine Lampe sanft an- oder ausgeht (in Sekunden).
var light_fade_time: float = 0.35


# --- Menü und Fenster ---

## Spiel automatisch pausieren, wenn das Spielfenster in den Hintergrund rückt.
var pause_on_focus_loss: bool = true


# --- Spätere Etappen ---
# Hier kommen nach und nach weitere Werte dazu, z. B.:
# Tageslänge (Etappe 5), Preise und Leihgebühren (Etappe 5),
# Freischaltintervalle (Etappe 8).
