"""Modegeschäft "Zwirn und Zwirbel" im Bilderbuch-Stil – eigenes Modell nach dem Vorlagebild
der Entwicklerin (warme Kinderbuch-Illustration: cremefarbener Putz, taubenblaue Ladenfront,
terrakotta-rosa Markisen, Gauben mit Blumenkästen, Efeu, Buchsbäume, Kopfsteinpflaster).

Unabhängig von den bisherigen Modellen (build_houses.py bleibt, wie es ist).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_shop.py
    blender -b --factory-startup --python tools/blender/build_storybook_shop.py -- --render
    blender -b --factory-startup --python tools/blender/build_storybook_shop.py -- --render --quick

Ergebnis:
    assets/models/source/houses/fashion_shop_storybook.blend   zum Anschauen und Weiterbauen (Einzelteile)
    assets/models/houses/fashion_shop.glb (+ .import)         fürs Spiel (Teile je Material zusammengefasst,
                                                              Knoten "Model" in scenes/world/houses/fashion_shop.tscn)
    assets/materials/storybook/*.tres                         Godot-Materialien (Shader storybook.gdshader)
    screenshots/blender/storybook/*.png                       Bilder (mit --render)
Mit --no-game nur die .blend (ohne Spiel-Dateien).

Aufbau in Blender (Outliner): Sammlung "Modegeschäft (Bilderbuch)" mit Mauern, Dach, Fenster,
Laden, Innen, Pflanzen, Deko, Licht; "Umgebung (nur Vorschau)" = Gehweg und Pflaster.
Jedes Teil ist ein geschlossener Körper (prüfbar: am Ende steht die Zahl offener Kanten).

Maße wie das Modegeschäft im Spiel: 5,4 m breit, 8 m tief, Traufe 6,8 m – so kann das Modell
später an derselben Stelle stehen (Wege und Kollision bleiben).
"""

import bpy
import math
import os
import random
import sys
import zlib

from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(__file__))
import storybook_lib as SB  # noqa: E402
from storybook_lib import Body  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND = os.path.join(ROOT, "assets", "models", "source", "houses", "fashion_shop_storybook.blend")
SHOTS = os.path.join(ROOT, "screenshots", "blender", "storybook")

W, D, E = 5.4, 8.0, 6.8          # Breite, Tiefe, Traufhöhe
HW = W / 2
PITCH = 38.0                      # Dachneigung (Grad)
EAVES_Y = -0.32                   # Dachkante vorn
RIDGE_Y = D / 2
RIDGE = E + (RIDGE_Y - EAVES_Y) * math.tan(math.radians(PITCH))
SLOPE = (RIDGE_Y - EAVES_Y) / math.cos(math.radians(PITCH))
SHOP_TOP = 3.62                   # Oberkante Ladengesims
WIN_X = (-1.7, 0.0, 1.7)          # Fenster im Obergeschoss
WIN_W, WIN_Z0, WIN_H = 0.92, 4.3, 1.58
DORMER_X, DORMER_FY = (-1.85, 1.85), 0.62   # Gauben: Mitte und Lage der Front

# Wölbung dieses Hauses (jedes Haus bekommt eigene Werte)
SETTLE = {"wave": 0.018, "wavelength": 3.4, "lean": 0.004, "roof_sag": 0.075, "ridge_tilt": 0.035, "eaves_sag": 0.025}

RND = random.Random(1907)


# --- Materialien ---

GRAIN_ID = {"plaster": 0, "stone": 1, "wood": 2, "brick": 3, "fabric": 4, "leaf": 5, "smooth": 6}
GAME_MATERIALS = {}   # Blender-Name -> Werte für das Godot-Material (siehe write_game_materials)


def materials():
    def M(name, color, glow=0.0, plant=False, **kw):
        """Material in Blender anlegen und die Werte für Godot merken (glow = Leuchten im Spiel,
        z. B. Innenräume, die in Blender von Lampen beleuchtet werden; plant = Blätter/Blüten, im
        Spiel beidseitig sichtbar)."""
        GAME_MATERIALS[name] = dict(kw, color=color, glow=glow, plant=plant)
        mat = SB.material(name, color, **kw)
        mat["spiel_pflanze"] = plant   # export_storybook.py vereinfacht diese Teile fürs Spiel
        return mat
    return {
        "plaster": M("Putz Creme", (0.9, 0.83, 0.7), rough=0.93, vary=0.09, scale=1.4, bump=0.35),
        "plaster_side": M("Putz Sand Seitenwand", (0.84, 0.75, 0.6), rough=0.93, vary=0.1, scale=1.2),
        "stone": M("Sandstein", (0.85, 0.77, 0.62), grain="stone", rough=0.9, vary=0.1, bump=0.3),
        "trim": M("Stuck Gebrochenweiß", (0.93, 0.89, 0.8), rough=0.88, vary=0.05, scale=3.0),
        "blue": M("Lack Taubenblau", (0.24, 0.33, 0.44), grain="wood", rough=0.72, vary=0.06, bump=0.12),
        "blue_dark": M("Lack Taubenblau dunkel", (0.18, 0.25, 0.34), grain="wood", rough=0.72, vary=0.05, bump=0.12),
        "sign": M("Holz Schild Nussbraun", (0.33, 0.21, 0.13), grain="wood", rough=0.8, vary=0.08, bump=0.25),
        "gold": M("Ocker-Gold matt", (0.84, 0.64, 0.3), grain="smooth", rough=0.5, metal=0.35, vary=0.05),
        "roof": M("Dachziegel Schiefer-Braun", (0.42, 0.34, 0.3), grain="stone", rough=0.92, vary=0.08, bump=0.2),
        "terra": M("Terrakotta", (0.74, 0.39, 0.25), rough=0.9, vary=0.08, scale=3.0),
        "brick": M("Backstein", (0.66, 0.36, 0.26), grain="brick", rough=0.92, vary=0.06),
        "frame": M("Fensterrahmen Creme", (0.91, 0.86, 0.76), grain="wood", rough=0.8, vary=0.04, bump=0.08),
        "glass": M("Glas", (0.92, 0.95, 0.93), grain="smooth", rough=0.03, glass=True, vary=0.0, bump=0.0),
        "curtain": M("Vorhang Leinen", (0.9, 0.8, 0.64), grain="fabric", rough=0.95, vary=0.05, emit=0.35,
                     emit_color=(0.95, 0.72, 0.45)),
        "awning": M("Markisenstoff", (0.93, 0.88, 0.78), grain="fabric", rough=0.95, vary=0.04, stripes=0.13,
                    color2=(0.76, 0.35, 0.27)),
        "iron": M("Schmiedeeisen", (0.21, 0.2, 0.19), grain="smooth", rough=0.7, metal=0.4, vary=0.04),
        "bronze": M("Dachrinne Bronze", (0.36, 0.28, 0.2), grain="smooth", rough=0.65, metal=0.4),
        "lamp": M("Laternenglas leuchtend", (1.0, 0.86, 0.62), grain="smooth", rough=0.4, emit=7.0,
                  emit_color=(1.0, 0.74, 0.42), vary=0.0, bump=0.0),
        "bulb": M("Lampenschirm leuchtend", (1.0, 0.9, 0.72), grain="smooth", rough=0.6, emit=4.0,
                  emit_color=(1.0, 0.76, 0.48), vary=0.0, bump=0.0),
        "box": M("Holz Blumenkasten", (0.5, 0.32, 0.21), grain="wood", rough=0.85, vary=0.08),
        "soil": M("Erde", (0.25, 0.18, 0.12), rough=1.0, vary=0.1, scale=8),
        "ivy": M("Blatt Efeu", (0.2, 0.34, 0.13), grain="leaf", rough=0.7, vary=0.1, plant=True),
        "ivy_young": M("Blatt Efeu jung", (0.36, 0.5, 0.2), grain="leaf", rough=0.7, vary=0.1, plant=True),
        "leaf": M("Blatt Geranie", (0.28, 0.44, 0.17), grain="leaf", rough=0.75, vary=0.1, plant=True),
        "box_leaf": M("Blatt Buchs", (0.22, 0.38, 0.14), grain="leaf", rough=0.72, vary=0.16, plant=True),
        "box_core": M("Buchs Inneres", (0.08, 0.15, 0.06), grain="leaf", rough=0.9, vary=0.1),
        "olive_leaf": M("Blatt Olive", (0.5, 0.56, 0.4), grain="leaf", rough=0.8, vary=0.1, plant=True),
        "stem": M("Stiel", (0.34, 0.38, 0.2), rough=0.8, vary=0.08),
        "bark": M("Rinde", (0.42, 0.34, 0.26), grain="wood", rough=0.95, vary=0.1),
        "pink": M("Blüte Rosa", (0.93, 0.46, 0.6), grain="fabric", rough=0.7, vary=0.12, plant=True),
        "rose": M("Blüte Himbeer", (0.85, 0.3, 0.43), grain="fabric", rough=0.7, vary=0.1, plant=True),
        "coral": M("Blüte Koralle", (0.96, 0.56, 0.45), grain="fabric", rough=0.7, vary=0.1, plant=True),
        "cream_flower": M("Blüte Creme", (0.96, 0.93, 0.85), grain="fabric", rough=0.7, vary=0.05, plant=True),
        "blush_flower": M("Blüte Zartrosa", (0.97, 0.75, 0.78), grain="fabric", rough=0.7, vary=0.08, plant=True),
        "lilac": M("Blüte Flieder", (0.68, 0.58, 0.86), grain="fabric", rough=0.7, vary=0.12, plant=True),
        "blue_flower": M("Blüte Blau", (0.48, 0.55, 0.86), grain="fabric", rough=0.7, vary=0.1, plant=True),
        "zinc": M("Zink", (0.62, 0.63, 0.6), grain="smooth", rough=0.6, metal=0.3, vary=0.06),
        "pot": M("Terrakotta Topf", (0.72, 0.42, 0.28), rough=0.92, vary=0.08, scale=6),
        "chalkboard": M("Tafel", (0.17, 0.21, 0.19), rough=0.95, vary=0.06),
        "chalk": M("Kreide", (0.93, 0.91, 0.85), rough=1.0, vary=0.03),
        "wood": M("Holz Eiche", (0.62, 0.44, 0.28), grain="wood", rough=0.8, vary=0.08),
        "wood_in": M("Holz Eiche innen", (0.62, 0.44, 0.28), grain="wood", rough=0.8, vary=0.08, glow=0.22),
        "in_wall": M("Innenwand Salbei", (0.66, 0.68, 0.54), rough=0.9, vary=0.05, glow=0.26),
        "in_paper": M("Tapete Creme", (0.9, 0.82, 0.68), rough=0.9, vary=0.05, glow=0.26),
        "in_dark": M("Zimmer warm", (0.66, 0.54, 0.4), rough=0.95, vary=0.05, glow=0.3),
        "linen": M("Schneiderpuppe Leinen", (0.86, 0.79, 0.66), grain="fabric", rough=0.9, vary=0.04, glow=0.2),
        "mustard": M("Stoff Senf", (0.82, 0.62, 0.24), grain="fabric", rough=0.92, vary=0.06, glow=0.2),
        "sage": M("Stoff Salbeigrün", (0.33, 0.46, 0.33), grain="fabric", rough=0.92, vary=0.06, glow=0.2),
        "rust": M("Stoff Rostrot", (0.68, 0.31, 0.22), grain="fabric", rough=0.92, vary=0.06, glow=0.2),
        "blush": M("Stoff Altrosa", (0.88, 0.62, 0.62), grain="fabric", rough=0.92, vary=0.06, glow=0.2),
        "slab": M("Gehwegplatten", (0.7, 0.64, 0.55), grain="stone", rough=0.95, vary=0.08, bump=0.2),
        "curb": M("Bordstein", (0.62, 0.59, 0.54), grain="stone", rough=0.95, vary=0.06),
        "cobble": M("Kopfsteinpflaster", (0.58, 0.42, 0.33), grain="stone", rough=0.95, vary=0.06),
        "earth": M("Fugen", (0.36, 0.3, 0.25), rough=1.0),
        "grass": M("Gras", (0.36, 0.5, 0.2), grain="leaf", rough=0.8, vary=0.15, plant=True),
    }


# --- Hilfen ---

def front_matrix(x, z, y=0.0, turn=0.0):
    """Ebene der Fassade: lokal x = Welt x, lokal y = Welt z (oben), lokal z = Welt -y (zur
    Straße); turn = Drehung in der Wand (Grad)."""
    m = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    return Matrix.Translation((x, y, z)) @ m @ Matrix.Rotation(math.radians(turn), 4, "Z")


def roof_point(x, s, h=0.0):
    """Punkt auf der vorderen Dachfläche: s = Weg hangaufwärts ab der Traufe, h = über der Fläche."""
    a = math.radians(PITCH)
    return Vector((x, EAVES_Y + s * math.cos(a) - h * math.sin(a), E + s * math.sin(a) + h * math.cos(a)))


def roof_z(y):
    """Höhe der vorderen Dachfläche über der Stelle y."""
    return E + (y - EAVES_Y) * math.tan(math.radians(PITCH))


# --- Mauern, Gesimse, Dach ---

def walls(M, C):
    # Obere Front aus Putz, Fensteröffnungen leicht schief ausgeschnitten
    b = Body("Fassade oben (Putz)", M["plaster"], C["walls"], seed=1, vary=0.03)
    b.box((0, 0.15, (SHOP_TOP - 0.12 + E) / 2), (W, 0.3, E - SHOP_TOP + 0.12), step=0.22, dent=0.007, dent_scale=1.5)
    wall = b.build()
    cuts = [SB.cutter((0, WIN_H / 2, 0), (WIN_W, WIN_H, 1.0), matrix=front_matrix(x + dx, WIN_Z0, 0.0, t)) for x, dx, t in WIN_JITTER]
    SB.boolean_cut(wall, cuts)
    add_bevel(wall, 0.012)
    # Seitenwände, Rückwand, Giebel
    b = Body("Seitenwände und Giebel", M["plaster_side"], C["walls"], seed=2, vary=0.04, bevel=0.01)
    for side in (-1, 1):
        b.box((side * (HW - 0.15), D / 2 + 0.01, E / 2), (0.3, D - 0.02, E), step=0.4, dent=0.006)
        m = Matrix.Translation((side * HW - (0.3 if side > 0 else 0), 0, 0)) @ Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        b.slab([(0.0, E), (D, E), (RIDGE_Y, RIDGE + 0.05)], 0.3, m, dent=0.006)
    b.box((0, D - 0.15, E / 2), (W - 0.6, 0.3, E), step=0.5, dent=0.006)
    b.build()
    # Ecksteine (Sandstein, abwechselnd lang und kurz) und Gurtgesims über dem Laden
    b = Body("Ecksteine", M["stone"], C["walls"], seed=3, vary=0.08, bevel=0.012)
    z = SHOP_TOP + 0.26
    k = 0
    while z + 0.3 < E - 0.45:
        long_ = k % 2 == 0
        wdt = 0.4 if long_ else 0.26
        for side in (-1, 1):
            b.box((side * (HW - wdt / 2 - 0.004), -0.025, z + 0.14), (wdt, 0.06, 0.27), step=0.3, dent=0.004,
                  turn=(0, RND.uniform(-1.2, 1.2), 0))
        z += 0.3
        k += 1
    b.build()
    b = Body("Gurtgesims", M["trim"], C["walls"], seed=4, vary=0.04, bevel=0.012)
    b.box((0, -0.04, SHOP_TOP + 0.16), (W + 0.02, 0.1, 0.13), step=0.3, dent=0.004)
    b.build()


def add_bevel(obj, width):
    mod = obj.modifiers.new("Weiche Kanten", "BEVEL")
    mod.width = width
    mod.segments = 2
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(40)


def eaves_cornice(M, C):
    """Traufgesims mit Zahnschnitt (jeder Zahn etwas anders) und Dachrinne."""
    b = Body("Traufgesims", M["trim"], C["walls"], seed=5, vary=0.04, bevel=0.01)
    b.box((0, 0.0, E - 0.36), (W + 0.04, 0.16, 0.1), step=0.3, dent=0.004)
    x = -HW + 0.09
    while x < HW - 0.08:
        b.box((x, -0.08, E - 0.265), (0.07 * RND.uniform(0.92, 1.08), 0.09, 0.09), step=1, dent=0.003,
              turn=(0, RND.uniform(-2, 2), 0))
        x += 0.145
    b.box((0, -0.06, E - 0.17), (W + 0.06, 0.24, 0.1), step=0.3, dent=0.004)
    b.box((0, -0.1, E - 0.075), (W + 0.1, 0.36, 0.1), step=0.3, dent=0.004)
    b.build()
    b = Body("Dachrinne", M["bronze"], C["roof"], seed=6)
    b.tube([(-HW - 0.05, -0.36, E + 0.02), (0, -0.37, E + 0.0), (HW + 0.05, -0.36, E + 0.02)], 0.055, segs=10)
    b.build()


def roof(M, C):
    a = math.radians(PITCH)
    rm = Matrix.Translation(roof_point(0, 0)) @ Matrix.Rotation(-a, 4, "X") @ Matrix(((1, 0, 0, 0), (0, -1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
    # Dachflächen (Körper mit Dicke), vorn und hinten
    b = Body("Dachflächen", M["roof"], C["roof"], seed=7, vary=0.04, bevel=0.01)
    front = Matrix.Translation(roof_point(0, SLOPE / 2, -0.09)) @ Matrix.Rotation(a, 4, "X")
    b.box((0, 0, 0), (W + 0.3, SLOPE, 0.16), step=0.3, dent=0.006, matrix=front)
    back_center = Vector((0, 2 * RIDGE_Y - roof_point(0, SLOPE / 2, -0.09).y, roof_point(0, SLOPE / 2, -0.09).z))
    back = Matrix.Translation(back_center) @ Matrix.Rotation(-a, 4, "X")
    b.box((0, 0, 0), (W + 0.3, SLOPE, 0.16), step=0.4, dent=0.006, matrix=back)
    b.build()
    # Ziegel in Reihen auf der Vorderseite: versetzt, jeder etwas anders breit und schief
    b = Body("Dachziegel", M["roof"], C["roof"], seed=8, vary=0.13, bevel=0.006)
    row = 0
    s = 0.02
    sin_a = math.sin(a)

    def covered(x, s):
        """Liegt der Ziegel unter Ziergiebel, Gaube oder Schornstein? (Nur dort fehlen Ziegel.)"""
        h = s * sin_a
        if abs(x) < 1.36 and h + 0.04 < 1.1 * (1 - abs(x) / 1.36):
            return True
        for cx in DORMER_X:
            dx = abs(x - cx)
            base = roof_z(DORMER_FY) - 0.18
            s_front = (DORMER_FY - EAVES_Y) / math.cos(a)
            if dx < 0.52 and s > s_front - 0.12 and E + h < base + 0.96 + 0.52 * (1 - dx / 0.64) + 0.12:
                return True
        for cx in (-HW + 0.42, HW - 0.42):
            if abs(x - cx) < 0.36 and (2.22 - EAVES_Y) / math.cos(a) < s + 0.15 < (3.18 - EAVES_Y) / math.cos(a):
                return True
        return False
    while s < SLOPE - 0.15:
        x = -HW - 0.12 + (0.13 if row % 2 else 0.0)
        while x < HW + 0.1:
            tw = 0.25 * RND.uniform(0.85, 1.12)
            cx = x + tw / 2
            if not covered(cx, s + 0.15) and abs(cx) < HW + 0.1:
                p = roof_point(cx, s + 0.15, 0.012)
                m = Matrix.Translation(p) @ Matrix.Rotation(a - math.radians(RND.uniform(2.5, 5.5)), 4, "X") @ \
                    Matrix.Rotation(math.radians(RND.uniform(-2.5, 2.5)), 4, "Z")
                b.box((0, 0, 0), (tw - 0.012, 0.3, 0.022), step=1, dent=0.003, matrix=m)
            x += tw
        s += 0.205
        row += 1
    b.build()
    # First (Terrakotta-Halbrund) und Ortgänge
    b = Body("First", M["terra"], C["roof"], seed=9, vary=0.07, bevel=0.0)
    b.tube([(-HW - 0.12, RIDGE_Y, RIDGE + 0.05), (0, RIDGE_Y, RIDGE + 0.07), (HW + 0.12, RIDGE_Y, RIDGE + 0.05)], 0.09, segs=10, wobble=0.04)
    b.build()


def pediment(M, C):
    """Ziergiebel in der Mitte: Putzdreieck, Terrakotta-Abdeckung, Rosette, kleines Dach dahinter."""
    turn = RND.uniform(-1.2, 1.2)
    b = Body("Ziergiebel", M["trim"], C["walls"], seed=10, vary=0.04, bevel=0.01)
    m = Matrix.Translation((0, -0.12, E - 0.02)) @ Matrix.Rotation(math.radians(turn), 4, "Y") @ \
        Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    b.slab([(-1.2, 0.0), (1.2, 0.0), (0.0, 1.0)], 1.8, m, dent=0.005)
    # Rosette: Scheibe mit Blütenblättern
    rz = E + 0.36
    b.lathe([(0.0, 0.0), (0.19, 0.0), (0.2, 0.03), (0.16, 0.06), (0.0, 0.065)], (0, -0.12, rz), segs=20, dent=0.002, turn=(90, 0))
    for k in range(8):
        ang = 2 * math.pi * k / 8 + 0.2
        c = Vector((0.1 * math.cos(ang), -0.19, rz + 0.1 * math.sin(ang)))
        b.blob(c, 0.035, subdiv=1, lump=0.1, scale=(1, 0.6, 1))
    b.blob((0, -0.2, rz), 0.045, subdiv=1, lump=0.08, scale=(1, 0.7, 1))
    b.build()
    b = Body("Ziergiebel Abdeckung", M["terra"], C["roof"], seed=11, vary=0.07, bevel=0.012)
    for side in (-1, 1):
        b.span((side * 1.36, -0.2, E - 0.04), (0, -0.2, E + 1.1), 0.12, 0.11, step=0.25)
    b.build()
    b = Body("Ziergiebel Dach", M["roof"], C["roof"], seed=12, vary=0.08, bevel=0.008)
    for side in (-1, 1):
        lo, hi = Vector((side * 1.34, -0.14, E + 0.02)), Vector((0, -0.14, E + 1.12))
        mid = (lo + hi) / 2
        d = (hi - lo)
        ang = math.atan2(d.z, abs(d.x)) * side
        m = Matrix.Translation(mid + Vector((0, 0.95, -0.03))) @ Matrix.Rotation(ang, 4, "Y")
        b.box((0, 0, 0), (d.length, 1.9, 0.06), step=0.3, dent=0.004, matrix=m)
    b.build()


def chimneys(M, C):
    for side in (-1, 1):
        x = side * (HW - 0.42)
        y = 2.7
        base = roof_z(y) - 0.4
        top = base + 2.05
        t = RND.uniform(-1.4, 1.4)
        b = Body("Schornstein %s" % ("links" if side < 0 else "rechts"), M["brick"], C["roof"], seed=20 + side, vary=0.04, bevel=0.01)
        b.box((x, y, (base + top) / 2), (0.62, 0.86, top - base), step=0.25, dent=0.006, turn=(t, RND.uniform(-1, 1), 0))
        b.build()
        b = Body("Schornstein Abdeckung %s" % ("links" if side < 0 else "rechts"), M["trim"], C["roof"], seed=22 + side, bevel=0.01)
        b.box((x + t * 0.01, y, top + 0.04), (0.74, 0.98, 0.09), step=0.3, dent=0.004, turn=(t, 0, 0))
        b.build()
        b = Body("Schornstein Töpfe %s" % ("links" if side < 0 else "rechts"), M["terra"], C["roof"], seed=24 + side, vary=0.1)
        for k, dy in enumerate((-0.2, 0.2)):
            h = 0.38 + 0.08 * k
            b.lathe([(0.11, 0.0), (0.095, h * 0.7), (0.11, h * 0.8), (0.11, h), (0.075, h), (0.075, 0.06)],
                    (x + t * 0.012, y + dy, top + 0.08), segs=14, dent=0.003, turn=(RND.uniform(-3, 3), RND.uniform(-3, 3)))
        b.build()


# --- Fenster ---

def window(M, C, name, cx, z0, w, h, turn, panes=(2, 2), wall_y=0.0, surround=True, curtains=True, hood=True,
           sill=True, fm=None):
    """Schiebefenster mit Rahmen, Sprossen, Glas und Vorhängen; alles in derselben leicht
    schiefen Ebene (turn) wie die ausgeschnittene Öffnung. fm = Ebene direkt vorgeben."""
    fm = fm or front_matrix(cx, z0, wall_y, turn)   # lokal: x quer, y hoch, z zur Straße
    b = Body("%s Rahmen" % name, M["frame"], C["windows"], seed=zlib.crc32(name.encode()) % 1000, vary=0.03, bevel=0.006)
    back = -0.12
    f = 0.065
    hx = w / 2
    def lbox(c, s, step=0.3):
        b.box(c, s, step=step, dent=0.002, matrix=fm)
    lbox((-hx + f / 2, h / 2, back), (f, h, 0.07))
    lbox((hx - f / 2, h / 2, back), (f, h, 0.07))
    lbox((0, f / 2, back), (w - 2 * f, f, 0.07))
    lbox((0, h - f / 2, back), (w - 2 * f, f, 0.07))
    lbox((0, h / 2, back + 0.012), (w - 2 * f, 0.055, 0.075))
    for half, dz in ((0, 0.0), (1, 0.014)):
        y0 = f + half * (h / 2 - f + 0.03)
        y1 = y0 + h / 2 - f - 0.03
        for c in range(1, panes[0]):
            xx = -hx + f + (w - 2 * f) * c / panes[0]
            lbox((xx, (y0 + y1) / 2, back - 0.005 + dz), (0.026, y1 - y0, 0.045))
        for r in range(1, panes[1]):
            yy = y0 + (y1 - y0) * r / panes[1]
            lbox((0, yy, back - 0.005 + dz), (w - 2 * f, 0.026, 0.045))
    b.build()
    g = Body("%s Glas" % name, M["glass"], C["windows"], seed=1)
    g.box((0, h / 2, back - 0.03), (w - 0.02, h - 0.02, 0.006), step=10, dent=0.0, matrix=fm)
    g.build()
    if curtains:
        c = Body("%s Vorhänge" % name, M["curtain"], C["windows"], seed=zlib.crc32(name.encode()) % 977, vary=0.05)
        for side in (-1, 1):
            cw = w * RND.uniform(0.26, 0.34)
            x0 = side * hx - (cw if side > 0 else 0) + side * 0.02
            folds = RND.randint(4, 6)
            origin = fm @ Vector((x0, 0.02, back - 0.12))
            u = (fm.to_3x3() @ Vector((cw, 0, 0)))
            v = (fm.to_3x3() @ Vector((0, h - 0.06, 0)))
            c.sheet(origin, u, v, 16, 10, 0.008,
                    offset=lambda uu, vv, f_=folds: 0.025 * math.sin(uu * math.pi * f_) * (0.6 + 0.4 * vv))
        c.build()
    if surround:
        s = Body("%s Faschen" % name, M["trim"], C["windows"], seed=zlib.crc32(name.encode()) % 991, vary=0.04, bevel=0.01)
        sw = 0.1
        for x0, x1, y0, y1 in ((-hx - sw, -hx, -0.02, h + sw), (hx, hx + sw, -0.02, h + sw), (-hx, hx, h, h + sw)):
            s.box(((x0 + x1) / 2, (y0 + y1) / 2, 0.025), (x1 - x0, y1 - y0, 0.05), step=0.3, dent=0.003, matrix=fm)
        if sill:
            s.box((0, -0.045, 0.09), (w + 0.34, 0.09, 0.22), step=0.3, dent=0.004, matrix=fm)
            for sx in (-hx - 0.05, hx + 0.05):
                s.box((sx, -0.16, 0.04), (0.09, 0.15, 0.08), step=1, dent=0.003, matrix=fm)
        if hood:
            s.box((0, h + sw + 0.05, 0.05), (w + 0.36, 0.1, 0.1), step=0.3, dent=0.003, matrix=fm)
            s.box((0, h + sw + 0.13, 0.08), (w + 0.48, 0.07, 0.16), step=0.3, dent=0.003, matrix=fm)
            for sx in (-hx - 0.13, hx + 0.13):
                s.box((sx, h + sw - 0.04, 0.06), (0.08, 0.16, 0.12), step=1, dent=0.003, matrix=fm)
        s.build()
    return fm


def upper_windows(M, C):
    for k, (x, dx, t) in enumerate(WIN_JITTER):
        fm = window(M, C, "Fenster %d" % (k + 1), x + dx, WIN_Z0, WIN_W, WIN_H, t)
        flower_box(M, C, "Blumenkasten Fenster %d" % (k + 1), fm, WIN_W + 0.16, 0.22, 0.24,
                   [("pink", "coral", "blush_flower"), ("rose", "pink", "blush_flower"), ("coral", "pink", "rose")][k], seed=40 + k)


def dormers(M, C):
    a = math.radians(PITCH)
    for k, cx in enumerate(DORMER_X):
        t = RND.uniform(-1.8, 1.8)
        fy = DORMER_FY
        base = roof_z(fy) - 0.18
        top = base + 1.0
        name = "Gaube %s" % ("links" if cx < 0 else "rechts")
        fm = front_matrix(cx, base, fy, t)
        b = Body("%s Wände" % name, M["trim"], C["walls"], seed=60 + k, vary=0.04)
        depth = (top + 0.45 - E) / math.tan(a) + EAVES_Y - fy + 0.3
        b.box((0, 0.5, -depth / 2), (1.0, 1.0, depth), step=0.2, dent=0.005, matrix=fm)
        wall = b.build()
        cut = SB.cutter((0, 0.56, -0.2), (0.54, 0.64, 0.5), matrix=fm)
        SB.boolean_cut(wall, [cut])
        add_bevel(wall, 0.01)
        window(M, C, name + " Fenster", 0, 0, 0.54, 0.64, t, panes=(2, 2), surround=False, hood=False,
               fm=fm @ Matrix.Translation((0, 0.24, 0)))
        sill = Body("%s Fensterbank" % name, M["trim"], C["walls"], seed=66 + k, bevel=0.008)
        sill.box((0, 0.2, 0.05), (0.7, 0.04, 0.14), step=0.3, dent=0.002, matrix=fm)
        sill.build()
        # Satteldach der Gaube (Terrakotta) mit cremefarbenen Ortgangbrettern
        r = Body("%s Dach" % name, M["terra"], C["roof"], seed=62 + k, vary=0.08, bevel=0.01)
        ridge = fm @ Vector((0, 1.48, 0.12))
        for side in (-1, 1):
            eave = fm @ Vector((side * 0.64, 0.96, 0.12))
            mid = (eave + ridge) / 2
            d = ridge - eave
            ang = math.atan2(d.z, abs(d.x)) * side
            m = Matrix.Translation(mid + Vector((0, depth / 2 - 0.12, 0.03))) @ Matrix.Rotation(ang, 4, "Y")
            r.box((0, 0, 0), (d.length + 0.04, depth + 0.1, 0.07), step=0.25, dent=0.004, matrix=m)
        r.build()
        tr = Body("%s Ortgang" % name, M["trim"], C["roof"], seed=64 + k, vary=0.03, bevel=0.008)
        for side in (-1, 1):
            tr.span(fm @ Vector((side * 0.66, 0.9, 0.16)), fm @ Vector((0, 1.45, 0.16)), 0.05, 0.13, step=0.3)
        tr.blob(fm @ Vector((0, 1.56, 0.16)), 0.04, subdiv=1, lump=0.1)
        tr.build()
        flower_box(M, C, "Blumenkasten %s" % name, fm @ Matrix.Translation((0, 0.22, 0)), 0.64, 0.15, 0.16,
                   ("pink", "rose", "blush_flower"), seed=70 + k, trailing=4, gap=0.0)


# --- Laden im Erdgeschoss ---

def shopfront(M, C):
    t_sign = RND.uniform(-0.5, 0.5)
    b = Body("Ladenfront Pfeiler", M["blue"], C["shop"], seed=80, vary=0.04, bevel=0.012)
    for side in (-1, 1):
        x0, x1 = sorted((side * HW, side * (HW - 0.36)))
        cx = (x0 + x1) / 2
        b.box((cx, -0.09, 1.45), (0.36, 0.2, 2.9), step=0.25, dent=0.004)
        b.box((cx, -0.11, 0.17), (0.42, 0.24, 0.34), step=0.3, dent=0.004)
        # aufgesetzte Füllung
        for (px0, px1, pz0, pz1) in ((x0 + 0.06, x0 + 0.09, 0.55, 2.35), (x1 - 0.09, x1 - 0.06, 0.55, 2.35),
                                     (x0 + 0.06, x1 - 0.06, 0.52, 0.55), (x0 + 0.06, x1 - 0.06, 2.35, 2.38)):
            b.box(((px0 + px1) / 2, -0.2, (pz0 + pz1) / 2), (px1 - px0, 0.025, pz1 - pz0), step=0.3, dent=0.002)
        # Kapitell (Konsole) über dem Pfeiler
        b.box((cx, -0.14, 2.72), (0.42, 0.3, 0.18), step=0.3, dent=0.004)
        b.box((cx, -0.17, 3.15), (0.46, 0.36, 0.6), step=0.3, dent=0.004)
    # Gesims über dem Schild
    b.box((0, -0.15, 3.48), (W + 0.06, 0.32, 0.1), step=0.3, dent=0.004)
    b.box((0, -0.19, 3.58), (W + 0.1, 0.4, 0.09), step=0.3, dent=0.004)
    b.build()
    g = Body("Ladenfront Goldrollen", M["gold"], C["shop"], seed=81, vary=0.04)
    for side in (-1, 1):
        cx = side * (HW - 0.18)
        g.tube([(cx - 0.17, -0.36, 2.95), (cx + 0.17, -0.36, 2.95)], 0.055, segs=10)
    g.build()
    # Schild: Nussbaum mit goldenem Rand und goldener Schrift
    sm = front_matrix(0, 3.13, -0.24, t_sign)
    s = Body("Ladenschild", M["sign"], C["shop"], seed=82, vary=0.03, bevel=0.01)
    s.box((0, 0, -0.1), (W - 0.74, 0.44, 0.2), step=0.25, dent=0.003, matrix=sm)
    s.build()
    gb = Body("Ladenschild Goldschrift", M["gold"], C["shop"], seed=83, vary=0.04)
    for (x0, x1, y0, y1) in ((-2.25, 2.25, 0.17, 0.19), (-2.25, 2.25, -0.19, -0.17), (-2.25, -2.23, -0.19, 0.19), (2.23, 2.25, -0.19, 0.19)):
        gb.box(((x0 + x1) / 2, (y0 + y1) / 2, 0.006), (x1 - x0, y1 - y0, 0.012), step=0.3, dent=0.001, matrix=sm)
    gb.text("Zwirn und Zwirbel", 0.31, 0.024, sm @ Matrix.Translation((0, -0.09, 0)), font="DejaVuSerif-Bold.ttf", jitter=0.05)
    gb.build()
    # Schaufenster: Brüstung, Bank, Pfosten, Kämpfer, Glas
    f = Body("Schaufenster Rahmen", M["blue"], C["shop"], seed=84, vary=0.03, bevel=0.008)
    gl = Body("Schaufenster Glas", M["glass"], C["shop"], seed=85)
    for side in (-1, 1):
        x0, x1 = sorted((side * (HW - 0.36), side * 0.74))
        cx, ww = (x0 + x1) / 2, x1 - x0
        t = RND.uniform(-0.4, 0.4)
        fm = front_matrix(cx, 0, 0.0, t)
        def fb(c, sz, step=0.3):
            f.box(c, sz, step=step, dent=0.003, matrix=fm)
        fb((0, 0.28, 0.1), (ww, 0.56, 0.14))
        fb((-ww / 2 + 0.16, 0.28, 0.18), (0.03, 0.34, 0.02))
        fb((ww / 2 - 0.16, 0.28, 0.18), (0.03, 0.34, 0.02))
        fb((0, 0.12, 0.18), (ww - 0.3, 0.03, 0.02))
        fb((0, 0.44, 0.18), (ww - 0.3, 0.03, 0.02))
        fb((0, 0.59, 0.12), (ww + 0.04, 0.07, 0.2))
        fb((-ww / 2 + 0.04, 1.74, 0.06), (0.08, 2.3, 0.1))
        fb((ww / 2 - 0.04, 1.74, 0.06), (0.08, 2.3, 0.1))
        fb((0, 2.86, 0.06), (ww, 0.12, 0.1))
        fb((0, 2.3, 0.06), (ww - 0.08, 0.06, 0.1))
        for i in range(1, 4):
            fb((-ww / 2 + 0.08 + (ww - 0.16) * i / 4, 2.57, 0.05), (0.026, 0.5, 0.05))
        gl.box((0, 1.74, 0.03), (ww - 0.1, 2.24, 0.006), step=10, dent=0.0, matrix=fm)
        awning(M, C, side, cx, ww)
    f.build()
    gl.build()
    door(M, C)
    window_display(M, C)


def awning(M, C, side, cx, ww):
    """Markise: Stoff mit leichtem Durchhang, Volant vorn, Seitenwangen; Stange und Halter."""
    tilt = RND.uniform(-2.5, 2.5)
    droop = RND.uniform(0.0, 0.03)
    name = "Markise %s" % ("links" if side < 0 else "rechts")
    b = Body(name, M["awning"], C["shop"], seed=90 + side, vary=0.03)
    x0, x1 = cx - ww / 2 - 0.04, cx + ww / 2 + 0.04
    top = Vector((x0, -0.14, 2.95))
    reach, drop = 0.85, 0.5 + math.radians(tilt) * 0.85
    b.sheet(top, (x1 - x0, 0, 0), (0, -reach, -drop), 18, 8, 0.012,
            offset=lambda u, v: -(0.025 * math.sin(math.pi * v) + droop * math.sin(math.pi * u)) * 1.0)
    fy, fz = -0.14 - reach, 2.95 - drop
    b.sheet((x0, fy, fz), (x1 - x0, 0, 0), (0, 0, -0.2), 18, 3, 0.012,
            offset=lambda u, v: 0.006 * math.sin(u * 40))
    for xx in (x0, x1):
        b.slab([(0.14, 2.95), (0.14 + reach, fz), (0.14 + reach, fz - 0.2), (0.14 + 0.3, fz - 0.05)], 0.012,
               Matrix.Translation((xx - (0.012 if xx > cx else 0), 0, 0)) @ Matrix(((0, 0, 1, 0), (-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    b.build()
    r = Body(name + " Stange", M["iron"], C["shop"], seed=92 + side)
    r.tube([(x0, fy + 0.02, fz + 0.01), (x1, fy + 0.02, fz + 0.01)], 0.016, segs=8)
    r.build()


def door(M, C):
    """Ladentür in einer Nische: Glas oben, Füllung unten, halbrundes Oberlicht mit Strahlen."""
    t = RND.uniform(-0.6, 0.6)
    fm = front_matrix(0, 0, 0.0, t)
    b = Body("Tür Rahmen und Nische", M["blue"], C["shop"], seed=100, vary=0.04, bevel=0.008)
    def fb(c, s, step=0.3):
        b.box(c, s, step=step, dent=0.003, matrix=fm)
    for side in (-1, 1):
        fb((side * 0.68, 1.48, 0.0), (0.12, 2.96, 0.2))
        fb((side * 0.6, 1.2, -0.17), (0.04, 2.4, 0.3))
    fb((0, 2.92, 0.0), (1.48, 0.1, 0.2))
    # Zwickel neben dem Bogen
    for side in (-1, 1):
        arc = [(side * 0.6 * math.cos(q), 2.3 + 0.58 * math.sin(q)) for q in [math.pi / 2 * k / 8 for k in range(9)]]
        pts = [(side * 0.62, 2.3)] + arc + [(side * 0.62, 2.88)]
        if side < 0:
            pts = list(reversed(pts))
        b.slab(pts, 0.04, fm @ Matrix.Translation((0, 0, -0.02)), dent=0.002)
    # Türblatt
    dz = -0.3
    fb((-0.5, 1.15, dz), (0.1, 2.3, 0.05))
    fb((0.5, 1.15, dz), (0.1, 2.3, 0.05))
    fb((0, 0.18, dz), (0.9, 0.36, 0.05))
    fb((0, 0.95, dz), (0.9, 0.1, 0.05))
    fb((0, 2.25, dz), (0.9, 0.1, 0.05))
    fb((0, 0.62, dz - 0.005), (0.9, 0.56, 0.04))
    fb((0, 0.62, dz + 0.03), (0.6, 0.38, 0.02))
    b.build()
    g = Body("Tür Glas", M["glass"], C["shop"], seed=101)
    g.box((0, 1.6, dz), (0.82, 1.2, 0.006), step=10, dent=0, matrix=fm)
    g.box((0, 2.59, -0.02), (1.18, 0.56, 0.006), step=10, dent=0, matrix=fm)
    g.build()
    ar = Body("Oberlicht Sprossen", M["frame"], C["shop"], seed=102, vary=0.03)
    arc = [fm @ Vector((0.58 * math.cos(math.pi * k / 20), 2.32 + 0.56 * math.sin(math.pi * k / 20), 0.0)) for k in range(21)]
    ar.tube(arc, 0.022, segs=8)
    hub = fm @ Vector((0, 2.33, 0.0))
    for k in range(1, 6):
        q = math.pi * k / 6
        ar.tube([hub, fm @ Vector((0.56 * math.cos(q), 2.33 + 0.54 * math.sin(q), 0.0))], 0.011, segs=6)
    ar.lathe([(0.0, 0.0), (0.09, 0.0), (0.09, 0.02), (0.0, 0.03)], hub, segs=16, turn=(90, 0))
    ar.tube([fm @ Vector((-0.6, 2.32, 0.0)), fm @ Vector((0.6, 2.32, 0.0))], 0.02, segs=8)
    ar.build()
    k = Body("Tür Knauf und Briefschlitz", M["gold"], C["shop"], seed=103)
    k.blob(fm @ Vector((0.4, 1.02, dz + 0.06)), 0.03, subdiv=2, lump=0.05)
    k.box((0, 0.98, dz + 0.035), (0.28, 0.04, 0.02), step=1, dent=0.001, matrix=fm)
    k.build()
    st = Body("Türstufe", M["stone"], C["shop"], seed=104, vary=0.06, bevel=0.015)
    st.box((0, -0.14, 0.04), (1.36, 0.34, 0.08), step=0.3, dent=0.004)
    st.box((0, 0.15, 0.03), (1.22, 0.32, 0.06), step=0.3, dent=0.003)
    st.build()


def window_display(M, C):
    """Laden hinter den Schaufenstern: Auslage, vier Schneiderpuppen, Raum mit Regalen und Licht."""
    r = Body("Laden Raum", M["in_wall"], C["inside"], seed=110, vary=0.03)
    r.box((0, 5.6, 1.6), (W - 0.6, 0.12, 3.2), step=0.6, dent=0.004)
    for side in (-1, 1):
        r.box((side * (HW - 0.36), 2.9, 1.6), (0.1, 5.4, 3.2), step=0.6, dent=0.004)
    r.build()
    c = Body("Laden Decke", M["in_paper"], C["inside"], seed=111, vary=0.03)
    c.box((0, 2.9, 3.05), (W - 0.6, 5.4, 0.1), step=0.6, dent=0.003)
    c.build()
    fl = Body("Laden Dielen", M["wood_in"], C["inside"], seed=112, vary=0.1)
    x = -HW + 0.36
    while x < HW - 0.36:
        bw = RND.uniform(0.14, 0.2)
        fl.box((x + bw / 2, 2.9, 0.04), (bw - 0.006, 5.4, 0.08), step=0.8, dent=0.002)
        x += bw
    fl.build()
    disp = Body("Auslage Podest", M["wood_in"], C["inside"], seed=113, vary=0.05, bevel=0.01)
    for side in (-1, 1):
        cx = side * (HW / 2 + 0.2)
        disp.box((cx, 0.55, 0.3), (1.6, 0.8, 0.6), step=0.4, dent=0.004)
    disp.build()
    # Regal an der Rückwand mit gefalteten Stoffen
    sh = Body("Regal", M["wood_in"], C["inside"], seed=114, vary=0.06, bevel=0.006)
    stack = {k: Body("Stoffe %s" % k, M[k], C["inside"], seed=115 + i, vary=0.08) for i, k in enumerate(("mustard", "sage", "rust", "blush", "linen"))}
    for z in (1.0, 1.5, 2.0, 2.5):
        sh.box((0, 5.4, z), (3.2, 0.32, 0.035), step=0.6, dent=0.002)
        xx = -1.45
        while xx < 1.4:
            key = RND.choice(list(stack))
            hgt = 0.0
            for n in range(RND.randint(2, 4)):
                th = RND.uniform(0.035, 0.06)
                stack[key].box((xx + 0.14, 5.4, z + 0.02 + hgt + th / 2), (0.26, 0.26, th), step=1, dent=0.006,
                               turn=(0, 0, RND.uniform(-4, 4)))
                hgt += th
            xx += RND.uniform(0.32, 0.4)
    for xx in (-1.62, 1.62):
        sh.box((xx, 5.4, 1.75), (0.04, 0.32, 1.6), step=0.6, dent=0.002)
    sh.build()
    for body in stack.values():
        body.build()
    # Pendelleuchten
    lamp = Body("Pendelleuchten", M["bulb"], C["inside"], seed=120)
    cord = Body("Pendelleuchten Kabel", M["iron"], C["inside"], seed=121)
    for y in (1.6, 3.6):
        cord.tube([(0, y, 3.0), (0, y, 2.55)], 0.006, segs=5)
        lamp.lathe([(0.0, 0.0), (0.14, 0.04), (0.15, 0.14), (0.06, 0.25), (0.0, 0.27)], (0, y, 2.3), segs=16)
        add_light("Pendellicht", (0, y, 2.25), 2700, 70, C["light"], radius=0.08)
    lamp.build()
    cord.build()
    add_light("Laden Grundlicht", (0, 2.6, 2.9), 3000, 260, C["light"], kind="AREA", size=2.5)
    for side in (-1, 1):
        add_light("Schaufensterlicht", (side * 1.55, 0.45, 2.75), 2700, 45, C["light"], radius=0.1)
    # Schneiderpuppen mit Kleidern
    for (x, y, key, kind, yaw) in ((-1.95, 0.5, "mustard", "dress", 15), (-1.2, 0.62, "sage", "coat", -10),
                                   (1.2, 0.62, "rust", "coat", 8), (1.95, 0.5, "blush", "dress", -18)):
        mannequin(M, C, x, y, 0.6, M[key], kind, yaw)


def mannequin(M, C, x, y, z, cloth, kind, yaw):
    n = "Schneiderpuppe %s" % cloth.name.split()[-1]
    st = Body(n + " Ständer", M["wood_in"], C["inside"], seed=int(abs(x) * 100))
    st.tube([(x, y, z + 0.02), (x, y, z + 0.82)], 0.016, segs=8)
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.radians(yaw)
        st.tube([(x, y, z + 0.2), (x + 0.24 * math.cos(a), y + 0.24 * math.sin(a), z + 0.01)], 0.012, segs=6)
    st.lathe([(0.0, 0.0), (0.02, 0.0), (0.025, 0.03), (0.0, 0.05)], (x, y, z + 1.62), segs=10)
    st.build()
    body = Body(n + " Körper", M["linen"], C["inside"], seed=int(abs(x) * 101))
    body.lathe([(0.0, 0.0), (0.15, 0.0), (0.16, 0.08), (0.12, 0.28), (0.16, 0.45), (0.15, 0.55), (0.06, 0.6), (0.045, 0.66), (0.0, 0.68)],
               (x, y, z + 0.92), segs=18, dent=0.004)
    body.build()
    c = Body(n + " Kleid", cloth, C["inside"], seed=int(abs(x) * 103), vary=0.04)
    if kind == "dress":
        c.lathe([(0.0, 0.0), (0.33, 0.0), (0.3, 0.12), (0.2, 0.42), (0.135, 0.6), (0.0, 0.61)], (x, y, z + 0.38), segs=24, wave=0.07, waves=9,
                dent=0.005)
        c.lathe([(0.0, 0.0), (0.135, 0.0), (0.168, 0.2), (0.16, 0.32), (0.07, 0.36), (0.0, 0.37)], (x, y, z + 1.0), segs=18, dent=0.003)
        belt = Body(n + " Gürtel", M["sign"], C["inside"], seed=3)
        belt.lathe([(0.0, 0.0), (0.137, 0.0), (0.137, 0.03), (0.0, 0.031)], (x, y, z + 0.98), segs=18)
        belt.build()
    else:
        c.lathe([(0.0, 0.0), (0.25, 0.0), (0.2, 0.3), (0.165, 0.62), (0.175, 0.86), (0.165, 0.98), (0.07, 1.02), (0.0, 1.03)],
                (x, y, z + 0.35), segs=22, wave=0.04, waves=7, dent=0.004)
        bt = Body(n + " Knöpfe", M["gold"], C["inside"], seed=4)
        a = math.radians(yaw) - math.pi / 2
        for k in range(4):
            hz = z + 0.8 + k * 0.13
            rr = 0.175
            bt.blob((x + rr * math.cos(a), y + rr * math.sin(a), hz), 0.012, subdiv=1, lump=0.05)
        bt.build()
    c.build()


# --- Laternen und Licht ---

def add_light(name, pos, kelvin, watt, coll, kind="POINT", radius=0.05, size=1.0):
    data = bpy.data.lights.new(name, kind)
    data.energy = watt
    data.color = kelvin_rgb(kelvin)
    if kind == "POINT":
        data.shadow_soft_size = radius
    elif kind == "AREA":
        data.size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = pos
    # Lampe selbst unsichtbar (auch durch Glas und in Spiegelungen), nur ihr Licht wirkt
    obj.visible_camera = False
    obj.visible_transmission = False
    obj.visible_glossy = False
    if kind == "AREA":
        obj.rotation_euler = (0, 0, 0)
    coll.objects.link(obj)
    return obj


def kelvin_rgb(k):
    """Grobe Farbe einer Glühlampe (linear) – 2700 K sehr warm, 3500 K warm."""
    table = {2700: (1.0, 0.52, 0.2), 3000: (1.0, 0.6, 0.28), 3500: (1.0, 0.69, 0.4), 4000: (1.0, 0.76, 0.52)}
    return table.get(k, (1.0, 0.69, 0.4))


def lanterns(M, C):
    for side in (-1, 1):
        x = side * (HW - 0.2)
        t = RND.uniform(-3, 3)
        name = "Wandlaterne %s" % ("links" if side < 0 else "rechts")
        ir = Body(name + " Eisen", M["iron"], C["deco"], seed=130 + side, vary=0.03)
        ir.box((x, -0.02, 4.24), (0.12, 0.04, 0.22), step=1, dent=0.002)
        arm = [(x, -0.04, 4.27), (x, -0.25, 4.29), (x, -0.36, 4.24)]
        ir.tube(arm, 0.014, segs=6)
        curl = [(x, -0.06 - 0.06 * (1 - math.cos(q)), 4.15 + 0.06 * math.sin(q)) for q in [k * 0.4 for k in range(10)]]
        ir.tube([(x, -0.04, 4.17)] + curl[1:], 0.009, segs=5)
        c = Vector((x, -0.36, 4.04))
        m = Matrix.Translation(c) @ Matrix.Rotation(math.radians(t), 4, "Y")
        ir.lathe([(0.0, 0.0), (0.07, 0.0), (0.09, 0.03), (0.0, 0.04)], m @ Vector((0, 0, -0.22)), segs=12)
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            p = Vector((0.075 * math.cos(a), 0.075 * math.sin(a), 0))
            ir.tube([m @ (p + Vector((0, 0, -0.19))), m @ (p + Vector((0, 0, 0.06)))], 0.008, segs=5)
        ir.lathe([(0.0, 0.0), (0.12, 0.0), (0.1, 0.03), (0.02, 0.13), (0.0, 0.14)], m @ Vector((0, 0, 0.06)), segs=12)
        ir.blob(m @ Vector((0, 0, 0.23)), 0.022, subdiv=1, lump=0.1)
        ir.build()
        gl = Body(name + " Glas", M["lamp"], C["deco"], seed=132 + side)
        gl.lathe([(0.0, 0.0), (0.062, 0.0), (0.07, 0.12), (0.066, 0.24), (0.0, 0.245)], m @ Vector((0, 0, -0.18)), segs=4,
                 turn=(0, 0))
        gl.build()
        add_light(name + " Licht", m @ Vector((0, 0, -0.05)), 2700, 22, C["light"], radius=0.04)


# --- Pflanzen ---

def flower_box(M, C, name, fm, width, depth, height, palette, seed, trailing=8, gap=0.06):
    """Holzkasten auf der Fensterbank, randvoll mit Geranien, darüber hinaus wuchernd, vorn
    hängen Efeuranken über den Rand. fm = Ebene des Fensters (lokal y = 0 Unterkante)."""
    rnd = random.Random(seed)
    b = Body(name, M["box"], C["plants"], seed=seed, vary=0.06, bevel=0.008)
    g = gap
    z_front = g + depth
    # Boden, vier Wände (oben offen), Leiste vorn
    wall = 0.022
    b.box((0, wall / 2, g + depth / 2), (width, wall, depth), step=0.25, dent=0.002, matrix=fm)
    b.box((0, height / 2, g + depth - wall / 2), (width + 0.02, height, wall), step=0.25, dent=0.003, matrix=fm)
    b.box((0, height / 2, g + wall / 2), (width, height, wall), step=0.25, dent=0.003, matrix=fm)
    for side in (-1, 1):
        b.box((side * (width / 2 - wall / 2), height / 2, g + depth / 2), (wall, height, depth), step=0.25, dent=0.003, matrix=fm)
    b.box((0, height + 0.01, g + depth - wall / 2 + 0.005), (width + 0.05, 0.02, wall + 0.02), step=0.25, dent=0.002, matrix=fm)
    b.build()
    s = Body(name + " Erde", M["soil"], C["plants"], seed=seed + 1)
    s.box((0, height - 0.045, g + depth / 2), (width - 2 * wall - 0.004, 0.05, depth - 2 * wall - 0.004), step=0.2, dent=0.006, matrix=fm)
    s.build()
    soil_y = height - 0.02
    leaves = Body(name + " Blätter", M["leaf"], C["plants"], seed=seed + 2, vary=0.12)
    stems = Body(name + " Stiele", M["stem"], C["plants"], seed=seed + 3, vary=0.08)
    blooms = {k: Body("%s Blüten %s" % (name, k), M[k], C["plants"], seed=seed + 4 + i, vary=0.1) for i, k in enumerate(dict.fromkeys(palette))}
    rot = fm.to_3x3()
    n_plants = max(3, int(width / 0.12))
    for i in range(n_plants):
        lx = -width / 2 + 0.08 + (width - 0.16) * (i + rnd.uniform(-0.25, 0.25)) / max(1, n_plants - 1)
        lz = g + depth / 2 + rnd.uniform(-0.03, 0.03)
        base = fm @ Vector((lx, soil_y, lz))
        geranium(leaves, stems, blooms[rnd.choice(palette)], base, rot, rnd)
    ivy = Body(name + " Ranken", M["ivy"], C["plants"], seed=seed + 9, vary=0.12)
    for k in range(trailing):
        lx = -width / 2 + 0.06 + rnd.uniform(0, width - 0.12)
        start = fm @ Vector((lx, soil_y, z_front - 0.03))
        hang(ivy, stems, start, rot @ Vector((rnd.uniform(-0.2, 0.2), -1, 0.3)).normalized(), rnd.uniform(0.25, 0.75), rnd,
             out=rot @ Vector((0, 0, 1)), wall_z=fm @ Vector((0, 0, z_front + 0.01)))
    # Hängepetunien: Blüten fallen in Kaskaden über den vorderen Rand
    for k in range(max(2, int(width / 0.3))):
        lx = -width / 2 + 0.08 + rnd.uniform(0, width - 0.16)
        start = fm @ Vector((lx, soil_y + 0.01, z_front - 0.02))
        cascade(leaves, stems, blooms[rnd.choice(palette)], start, rot @ Vector((rnd.uniform(-0.3, 0.3), 0.2, 1)).normalized(),
                rnd.uniform(0.15, 0.35), rnd)
    for body in (leaves, stems, ivy, *blooms.values()):
        body.build()


def cascade(leaves, stems, bloom, start, out, length, rnd):
    """Hängende Blütenranke (Petunie): wächst erst über den Rand nach vorn, dann nach unten;
    Blätter und offene Trichterblüten verteilt, nicht gleichmäßig."""
    pts = [Vector(start)]
    d = Vector(out)
    for i in range(max(3, int(length / 0.03))):
        d = (d + Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), -0.45))).normalized()
        pts.append(pts[-1] + d * 0.03)
    stems.tube(pts, lambda t: 0.004 * (1 - 0.5 * t), segs=4)
    for i, p in enumerate(pts[1:], 1):
        if rnd.random() < 0.7:
            dd = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.5, 0.5))).normalized()
            leaves.leaf(p, dd, Vector((0, 0, 1)) + dd * 0.2, rnd.uniform(0.03, 0.045), 0.03, shape="oval", curl=0.15, segs=6)
        if rnd.random() < 0.55:
            n = (Vector(out) + Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(-0.3, 0.6)))).normalized()
            floret(bloom, p + n * 0.02, n, rnd.uniform(0.022, 0.03), rnd, petals=5)


def geranium(leaves, stems, bloom, base, rot, rnd):
    """Geranie: runde, gewellte Blätter rund um den Fuß (ungleich verteilt), zwei, drei Stiele
    mit Dolden aus kleinen fünfblättrigen Blüten; einzelne Blüten stehen etwas ab."""
    up = rot @ Vector((0, 1, 0))
    out = rot @ Vector((0, 0, 1))
    for k in range(rnd.randint(9, 13)):
        a = rnd.uniform(0, 2 * math.pi)
        d = (rot @ Vector((math.cos(a), rnd.uniform(0.15, 0.7), math.sin(a)))).normalized()
        L = rnd.uniform(0.065, 0.1)
        stem_end = base + d * rnd.uniform(0.03, 0.07)
        stems.tube([base, stem_end], 0.003, segs=4)
        leaves.leaf(stem_end, d + up * 0.2, up + d * -0.3, L, L * 0.95, shape="round", curl=0.18)
    for k in range(rnd.randint(2, 4)):
        top = base + up * rnd.uniform(0.12, 0.26) + (rot @ Vector((rnd.uniform(-0.06, 0.06), 0, rnd.uniform(-0.02, 0.06))))
        mid = (base + top) / 2 + out * 0.015
        stems.tube([base, mid, top], 0.004, segs=5)
        umbel(bloom, top, rnd.uniform(0.045, 0.065), up, rnd, count=rnd.randint(16, 24))


def umbel(bloom, center, radius, up, rnd, count=None, petals=5, size=0.017):
    for k in range(count or rnd.randint(11, 17)):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
        if d.length < 0.1:
            continue
        d.normalize()
        if d.dot(up) < -0.2:
            d = (d + up * 0.8).normalized()
        c = Vector(center) + d * radius * rnd.uniform(0.75, 1.15)
        floret(bloom, c, d, size * rnd.uniform(0.85, 1.15), rnd, petals)


def floret(body, center, normal, size, rnd, petals=5):
    if SB.GAME:
        body.star(center, normal, size, petals, rnd)
        return
    n = Vector(normal).normalized()
    ref = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    s1 = n.cross(ref).normalized()
    s2 = n.cross(s1).normalized()
    spin = rnd.uniform(0, 2 * math.pi)
    for k in range(petals):
        a = spin + 2 * math.pi * k / petals
        d = s1 * math.cos(a) + s2 * math.sin(a) + n * 0.25
        body.leaf(center, d, n, size, size * 0.8, shape="petal", thick=0.0015, curl=0.1, segs=6)


def hang(leaves, stems, start, direction, length, rnd, out=None, wall_z=None, young=None):
    """Hängende Efeuranke: Trieb fällt in leichtem Bogen, Blätter abwechselnd links/rechts,
    zur Spitze hin kleiner."""
    pts = [Vector(start)]
    d = Vector(direction)
    step = 0.035
    n = max(3, int(length / step))
    for i in range(n):
        d = (d + Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.05, 0.05), -0.35))).normalized()
        pts.append(pts[-1] + d * step)
    stems.tube(pts, lambda t: 0.0035 * (1 - 0.5 * t), segs=4)
    out = out or Vector((0, -1, 0))
    for i in range(1, len(pts), 1):
        side = 1 if i % 2 else -1
        tang = (pts[i] - pts[i - 1]).normalized()
        sideways = tang.cross(out).normalized() * side
        size = 0.06 * (1 - 0.45 * i / len(pts)) * rnd.uniform(0.8, 1.15)
        base = pts[i] + sideways * 0.01 + out * 0.006
        leaves.leaf(base, (sideways * 0.6 + Vector((0, 0, -0.6)) + out * 0.2).normalized(), out, size, size, shape="ivy", curl=0.12)


def ivy_climb(M, C, side, top, seed):
    """Efeu wächst an der Hausecke vom Boden bis unters Dach: Triebe am Pfeiler hoch, über
    Kapitell und Gesims, dann an der Ecke der Putzwand; Seitentriebe, Blätter ungleich, oben
    jung und heller."""
    rnd = random.Random(seed)
    name = "Efeu %s" % ("links" if side < 0 else "rechts")
    leaves = Body(name + " Blätter", M["ivy"], C["plants"], seed=seed, vary=0.12)
    young = Body(name + " junge Blätter", M["ivy_young"], C["plants"], seed=seed + 1, vary=0.12)
    stems = Body(name + " Triebe", M["bark"], C["plants"], seed=seed + 2, vary=0.08)

    def surface_y(x, z):
        ax = abs(x)
        y = 0.0
        if z < 2.62 and ax > HW - 0.38:
            y = -0.23
        elif z < 3.46 and ax > HW - 0.42:
            y = -0.36 if z > 2.84 else -0.3
        elif z < SHOP_TOP + 0.02:
            y = -0.4
        elif z < SHOP_TOP + 0.24:
            y = -0.1
        elif 0.95 < ax < 2.45 and WIN_Z0 + WIN_H + 0.05 < z < WIN_Z0 + WIN_H + 0.42:
            y = -0.19
        elif ax > HW - 0.42:
            y = -0.06
        return y

    def hug(x, z):
        return min(surface_y(x, z + dz) for dz in (-0.08, -0.04, 0.0, 0.04, 0.08))

    def grow(x, z, z_end, xmin, xmax, thick, depth=0):
        pts = []
        heading = 0.0
        while z < z_end:
            heading = max(-0.6, min(0.6, heading + rnd.uniform(-0.25, 0.25)))
            x = max(xmin, min(xmax, x + math.sin(heading) * 0.04))
            z += 0.045
            pts.append(Vector((x, hug(x, z) - thick - 0.004, z)))
            if depth == 0 and rnd.random() < 0.06 and z > 0.4:
                lo_, hi_ = (xmin - 0.12, xmax) if side > 0 else (xmin, xmax + 0.12)
                grow(x, z, min(z_end, z + rnd.uniform(0.4, 1.4)), lo_, hi_, thick * 0.7, depth + 1)
        if len(pts) < 2:
            return
        stems.tube(pts, lambda t: thick * (1 - 0.6 * t), segs=5)
        for i, p in enumerate(pts):
            frac = i / len(pts)
            for side_ in ((1 if i % 2 else -1),) + ((-1 if i % 2 else 1,) if rnd.random() < 0.55 else ()):
                leaf_at(p, side_, frac, depth)

    def leaf_at(p, side_, frac, depth):
        """Ein Blatt an einem kurzen Stiel, zur Seite und nach unten hängend, oben jünger."""
        size = rnd.uniform(0.055, 0.095) * (1.15 - 0.5 * frac * (1 if depth == 0 else 1.3))
        off = Vector((side_ * rnd.uniform(0.02, 0.05), -rnd.uniform(0.01, 0.035), rnd.uniform(-0.01, 0.02)))
        base = p + off
        stems.tube([p, base], 0.0018, segs=3)
        dirv = Vector((side_ * rnd.uniform(0.2, 0.9), -rnd.uniform(0.0, 0.3), rnd.uniform(-1.0, -0.2))).normalized()
        normal = Vector((rnd.uniform(-0.3, 0.3), -1, rnd.uniform(-0.2, 0.3)))
        body = young if frac > 0.82 and rnd.random() < 0.7 else leaves
        body.leaf(base, dirv, normal, size, size * rnd.uniform(0.9, 1.1), shape="ivy", curl=rnd.uniform(0.05, 0.2))

    x_edge = side * (HW - 0.17)
    lo, hi = sorted((side * (HW - 0.36), side * (HW - 0.02)))
    for k in range(5):
        grow(x_edge + rnd.uniform(-0.12, 0.12), 0.05, top - rnd.uniform(0.0, 1.2) * (k > 0), lo, hi, 0.012 - 0.0015 * k)
    for body in (leaves, young, stems):
        body.build()


def ivy_garland(M, C, x0, x1, seed):
    """Efeu oben auf dem Ladengesims mit herabhängenden Ranken über dem Schild."""
    rnd = random.Random(seed)
    leaves = Body("Efeu Gesims %.0f Blätter" % x0, M["ivy"], C["plants"], seed=seed, vary=0.12)
    stems = Body("Efeu Gesims %.0f Triebe" % x0, M["bark"], C["plants"], seed=seed + 1)
    z = SHOP_TOP + 0.012
    pts = []
    x = x0
    step = 0.04 * (1 if x1 > x0 else -1)
    while (x - x1) * (1 if x1 > x0 else -1) < 0:
        pts.append(Vector((x, -0.3 + 0.03 * math.sin(x * 7), z + 0.006)))
        x += step
    stems.tube(pts, 0.006, segs=5)
    for i, p in enumerate(pts):
        for _ in range(rnd.randint(2, 3)):
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 0.2), rnd.uniform(0.2, 0.8))).normalized()
            leaves.leaf(p + Vector((0, 0, 0.005)), d, Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.6, 0.2), 1)), rnd.uniform(0.04, 0.065),
                        0.055, shape="ivy", curl=0.12)
        if rnd.random() < 0.22:
            hang(leaves, stems, p + Vector((0, -0.12, 0)), Vector((rnd.uniform(-0.2, 0.2), -0.6, -0.5)).normalized(), rnd.uniform(0.15, 0.7), rnd)
    leaves.build()
    stems.build()


def boxwood(M, C, center, radius, seed):
    """Buchs: nicht exakt rund – leicht eiförmig, ungleich dicht (Lücken und Büschel), einzelne
    Triebe stehen heraus. Innen dunkel, außen viele kleine Blätter."""
    rnd = random.Random(seed)
    core = Body("Buchs Inneres %d" % seed, M["box_core"], C["plants"], seed=seed, vary=0.08)
    c = Vector(center)
    sc = (rnd.uniform(0.95, 1.12), rnd.uniform(0.9, 1.05), rnd.uniform(0.82, 0.95))
    core.blob(c, radius * 0.8, subdiv=3, lump=0.22, scale=sc)
    core.build()
    leaves = Body("Buchs Blätter %d" % seed, M["box_leaf"], C["plants"], seed=seed + 1, vary=0.2)
    twigs = Body("Buchs Zweige %d" % seed, M["bark"], C["plants"], seed=seed + 2)
    seedv = Vector((rnd.uniform(0, 9), rnd.uniform(0, 9), 0))
    for k in range(2600):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
        if d.z < -0.6:
            continue
        clump = noise.noise(d * 3.0 + seedv)
        if clump < -0.25 and rnd.random() < 0.7:
            continue   # Lücke: hier ist der Busch dünner
        lump = 1 + 0.16 * clump
        p = c + Vector((d.x * sc[0], d.y * sc[1], d.z * sc[2])) * radius * lump * rnd.uniform(0.86, 1.03)
        t = (d * 0.5 + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1)))).normalized()
        leaves.leaf(p, t, d + Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), 0.3)), rnd.uniform(0.026, 0.04), 0.022,
                    shape="oval", thick=0.002, curl=0.15, segs=6)
    for k in range(rnd.randint(7, 12)):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), abs(rnd.gauss(0, 1)))).normalized()
        start = c + Vector((d.x * sc[0], d.y * sc[1], d.z * sc[2])) * radius * 0.8
        end = start + (d + Vector((0, 0, 0.3))).normalized() * rnd.uniform(0.12, 0.24)
        twigs.tube([start, end], 0.0035, segs=4)
        for j in range(7):
            p = start + (end - start) * (0.35 + 0.1 * j)
            leaves.leaf(p, (d + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0.6))).normalized(), d, 0.03, 0.02, shape="oval",
                        thick=0.002, segs=6)
    leaves.build()
    twigs.build()


def hydrangea_tub(M, C, pos, seed):
    rnd = random.Random(seed)
    x, y = pos
    tub = Body("Zinkwanne", M["zinc"], C["plants"], seed=seed, vary=0.04)
    tub.lathe([(0.17, 0.0), (0.22, 0.32), (0.235, 0.33), (0.235, 0.35), (0.21, 0.35), (0.165, 0.04), (0.0, 0.04)], (x, y, 0.0), segs=24, dent=0.004)
    for side in (-1, 1):
        tub.tube([(x + side * 0.22, y, 0.28), (x + side * 0.27, y, 0.3), (x + side * 0.27, y, 0.22), (x + side * 0.215, y, 0.2)], 0.008, segs=5)
    for zz in (0.08, 0.24):
        r = 0.17 + 0.05 * zz / 0.32
        tub.lathe([(0.0, 0.0), (r + 0.006, 0.0), (r + 0.006, 0.015), (0.0, 0.016)], (x, y, zz), segs=24)
    tub.build()
    soil = Body("Zinkwanne Erde", M["soil"], C["plants"], seed=seed + 1)
    soil.lathe([(0.0, 0.0), (0.205, 0.0), (0.2, 0.03), (0.0, 0.035)], (x, y, 0.29), segs=20, dent=0.008)
    soil.build()
    leaves = Body("Hortensie Blätter", M["leaf"], C["plants"], seed=seed + 2, vary=0.12)
    stems = Body("Hortensie Stiele", M["stem"], C["plants"], seed=seed + 3)
    lilac = Body("Hortensie Blüten Flieder", M["lilac"], C["plants"], seed=seed + 4, vary=0.14)
    blue = Body("Hortensie Blüten Blau", M["blue_flower"], C["plants"], seed=seed + 5, vary=0.14)
    base = Vector((x, y, 0.31))
    for k in range(rnd.randint(4, 5)):
        a = 2 * math.pi * k / 4.5 + rnd.uniform(-0.4, 0.4)
        top = base + Vector((0.13 * math.cos(a), 0.13 * math.sin(a) - 0.03, rnd.uniform(0.32, 0.46)))
        stems.tube([base, (base + top) / 2 + Vector((0, 0, 0.03)), top], 0.006, segs=5)
        head = top + Vector((0, 0, 0.06))
        body = lilac if rnd.random() < 0.6 else blue
        hr = rnd.uniform(0.1, 0.13)
        for j in range(130):
            d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), abs(rnd.gauss(0, 1)) + 0.3)).normalized()
            floret(body, head + d * hr * rnd.uniform(0.85, 1.05), d, 0.026 * rnd.uniform(0.8, 1.2), rnd, petals=4)
        for j in range(6):
            p = base + (top - base) * rnd.uniform(0.3, 0.75)
            dd = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.1, 0.4))).normalized()
            leaves.leaf(p, dd, Vector((0, 0, 1)) - dd * 0.4, rnd.uniform(0.11, 0.15), 0.08, shape="oval", curl=0.2)
    for body in (leaves, stems, lilac, blue):
        body.build()


def olive_pot(M, C, pos, seed):
    rnd = random.Random(seed)
    x, y = pos
    pot = Body("Olivenbaum Topf", M["pot"], C["plants"], seed=seed, vary=0.05)
    pot.lathe([(0.14, 0.0), (0.18, 0.38), (0.2, 0.39), (0.2, 0.44), (0.175, 0.44), (0.135, 0.04), (0.0, 0.04)], (x, y, 0.0), segs=22, dent=0.004)
    pot.build()
    soil = Body("Olivenbaum Erde", M["soil"], C["plants"], seed=seed + 1)
    soil.lathe([(0.0, 0.0), (0.172, 0.0), (0.17, 0.02), (0.0, 0.025)], (x, y, 0.4), segs=18, dent=0.006)
    soil.build()
    bark = Body("Olivenbaum Stamm", M["bark"], C["plants"], seed=seed + 2)
    leaves = Body("Olivenbaum Blätter", M["olive_leaf"], C["plants"], seed=seed + 3, vary=0.14)
    trunk = [Vector((x, y, 0.4)), Vector((x + 0.02, y, 0.7)), Vector((x - 0.015, y + 0.01, 1.0)), Vector((x + 0.01, y, 1.22))]
    bark.tube(trunk, lambda t: 0.028 * (1 - 0.45 * t), segs=8, wobble=0.1)
    top = trunk[-1]
    for k in range(6):
        a = 2 * math.pi * k / 6 + rnd.uniform(-0.4, 0.4)
        L = rnd.uniform(0.18, 0.32)
        end = top + Vector((L * math.cos(a), L * math.sin(a) * 0.8, rnd.uniform(0.05, 0.3)))
        mid = (top + end) / 2 + Vector((0, 0, 0.04))
        bark.tube([top - Vector((0, 0, 0.02)), mid, end], 0.012, segs=6)
        for j in range(60):
            t = rnd.uniform(0.2, 1.08)
            p = top + (end - top) * t + Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), rnd.uniform(-0.04, 0.06)))
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.6, 0.8))).normalized()
            leaves.leaf(p, d, Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), 1)), rnd.uniform(0.045, 0.065), 0.02, shape="narrow",
                        thick=0.0018, curl=0.1, segs=7)
    bark.build()
    leaves.build()


def grass_tufts(M, C, spots, seed):
    rnd = random.Random(seed)
    g = Body("Grasbüschel", M["grass"], C["env"], seed=seed, vary=0.18)
    for (x, y) in spots:
        for k in range(rnd.randint(6, 12)):
            a = rnd.uniform(0, 2 * math.pi)
            d = Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 1)).normalized()
            g.leaf(Vector((x + rnd.uniform(-0.03, 0.03), y + rnd.uniform(-0.02, 0.02), -0.005)), d,
                   Vector((-math.sin(a), math.cos(a), 0)), rnd.uniform(0.05, 0.12), 0.012, shape="narrow", thick=0.0015, curl=0.4, segs=5)
    g.build()


# --- Deko vor dem Laden ---

def chalkboard(M, C, pos, yaw):
    x, y = pos
    m = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    a = math.radians(12)
    w = Body("Kreidetafel Rahmen", M["wood"], C["deco"], seed=140, vary=0.05, bevel=0.005)
    bd = Body("Kreidetafel Tafel", M["chalkboard"], C["deco"], seed=141, vary=0.03)
    ch = Body("Kreidetafel Schrift", M["chalk"], C["deco"], seed=142, vary=0.02)
    for side in (-1, 1):
        fm = m @ Matrix.Translation((0, side * 0.0, 0)) @ Matrix.Rotation(side * a, 4, "X")
        def lb(c, s):
            w.box(c, s, step=0.3, dent=0.002, matrix=fm)
        lb((-0.24, side * -0.02, 0.4), (0.04, 0.03, 0.8))
        lb((0.24, side * -0.02, 0.4), (0.04, 0.03, 0.8))
        lb((0, side * -0.02, 0.78), (0.52, 0.03, 0.04))
        lb((0, side * -0.02, 0.14), (0.52, 0.03, 0.04))
        bd.box((0, side * -0.02, 0.46), (0.44, 0.012, 0.6), step=0.3, dent=0.001, matrix=fm)
    tm = m @ Matrix.Rotation(-a, 4, "X") @ Matrix.Translation((0, -0.027, 0)) @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    for k, (txt, zz, sz) in enumerate((("Neu:", 0.66, 0.07), ("Herbst-", 0.54, 0.075), ("mode", 0.43, 0.075))):
        ch.text(txt, sz, 0.002, tm @ Matrix.Translation((0, zz, 0)), font="DejaVuSerif-BoldItalic.ttf", jitter=0.08)
    pts = [Vector((-0.15 + 0.3 * t, 0, 0.3 + 0.025 * math.sin(t * 12))) for t in [k / 20 for k in range(21)]]
    ch.tube([m @ Matrix.Rotation(-a, 4, "X") @ (p + Vector((0, -0.029, 0))) for p in pts], 0.003, segs=4)
    for body in (w, bd, ch):
        body.build()


# --- Umgebung (nur für die Vorschau) ---

def pavement(M, C, seed=300):
    rnd = random.Random(seed)
    s = Body("Gehwegplatten", M["slab"], C["env"], seed=seed, vary=0.1, bevel=0.012)
    y = 0.02
    while y > -2.35:
        depth = rnd.uniform(0.5, 0.7)
        x = -4.2 + rnd.uniform(0, 0.4)
        while x < 4.2:
            wdt = rnd.uniform(0.5, 0.95)
            s.box((x + wdt / 2, y - depth / 2, -0.04 + rnd.uniform(-0.004, 0.004)), (wdt - 0.014, depth - 0.014, 0.08), step=0.4,
                  dent=0.004, turn=(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(-1, 1)))
            x += wdt
        y -= depth
    s.build()
    cb = Body("Bordstein", M["curb"], C["env"], seed=seed + 1, vary=0.06, bevel=0.015)
    x = -4.2
    while x < 4.2:
        L = rnd.uniform(0.6, 1.0)
        cb.box((x + L / 2, -2.48, -0.09), (L - 0.012, 0.2, 0.2), step=0.3, dent=0.004, turn=(0, 0, rnd.uniform(-0.8, 0.8)))
        x += L
    cb.build()
    co = Body("Kopfsteinpflaster", M["cobble"], C["env"], seed=seed + 2, vary=0.16, bevel=0.018)
    y = -2.62
    row = 0
    while y > -6.0:
        h = rnd.uniform(0.09, 0.13)
        x = -4.2 + (0.06 if row % 2 else 0) + rnd.uniform(-0.03, 0.03)
        while x < 4.2:
            wdt = rnd.uniform(0.1, 0.17)
            co.box((x + wdt / 2, y - h / 2, -0.17 + rnd.uniform(-0.008, 0.01)), (wdt - 0.016, h - 0.016, 0.08), step=1,
                   dent=0.01, dent_scale=12, turn=(rnd.uniform(-3, 3), rnd.uniform(-3, 3), rnd.uniform(-6, 6)))
            x += wdt
        y -= h
        row += 1
    co.build()
    e = Body("Untergrund", M["earth"], C["env"], seed=seed + 3)
    e.box((0, -3.0, -0.28), (8.6, 6.4, 0.3), step=2, dent=0)
    e.build()
    grass_tufts(M, C, [(rnd.uniform(-4, 4), -2.37) for _ in range(9)] + [(side * 2.95, -0.05) for side in (-1, 1)], seed + 4)


# --- Verziehen wie über Jahrzehnte gesetzt ---

def settle(objects, p):
    seed = Vector((3.1, 7.7, 1.3))
    for obj in objects:
        if obj.type != "MESH":
            continue
        mw = obj.matrix_world
        inv = mw.inverted()
        for v in obj.data.vertices:
            wp = mw @ v.co
            d = noise.noise_vector(wp / p["wavelength"] + seed) * p["wave"]
            d.x *= SB.smooth((HW - abs(wp.x)) / 0.6)
            d.z *= SB.smooth(wp.z / 0.8)
            d.y -= p["lean"] * max(wp.z, 0.0)
            across = max(0.0, 1 - (wp.x / HW) ** 2)
            if wp.z > E - 1.2:
                d.z -= p["eaves_sag"] * across * SB.smooth((wp.z - (E - 1.2)) / 1.2)
            if wp.z > E:
                r = SB.smooth((wp.z - E) / (RIDGE - E))
                d.z += (-p["roof_sag"] * across + p["ridge_tilt"] * wp.x / HW) * r
            v.co = inv @ (wp + d)
    for obj in objects:
        if obj.type == "LIGHT":
            wp = obj.location
            obj.location = wp + Vector((0, -p["lean"] * max(wp.z, 0.0), 0))


# --- Fürs Spiel: Kollision, Godot-Materialien, zusammengefasste .glb ---

GAME_GLB = os.path.join(ROOT, "assets", "models", "houses", "fashion_shop.glb")
GAME_MAT_DIR = os.path.join(ROOT, "assets", "materials", "storybook")
# Feste Teile vor dem Haus (Mitte x, y, Größe x, y, Höhe): werden im Spiel zu Kollision und zu
# Hindernissen für Passanten (HouseFacade, Knoten "...-colonly")
OBSTACLES = {
    "Buchs links": ((-HW + 0.38, -0.62), (0.66, 0.62), 0.6),
    "Buchs rechts": ((HW - 0.38, -0.63), (0.68, 0.64), 0.6),
    "Zinkwanne": ((-1.15, -0.48), (0.5, 0.5), 0.35),
    "Olivenbaum": ((1.12, -0.45), (0.42, 0.42), 0.45),
    "Kreidetafel": ((1.78, -0.6), (0.56, 0.42), 0.8),
}


def colliders(C):
    """Kästen für die Kollision im Spiel (in Blender nur als Drahtgitter sichtbar)."""
    out = []
    for name, ((x, y), (sx, sy), h) in OBSTACLES.items():
        b = Body(name + "-colonly", None, C["collision"], vary=0)
        b.box((x, y, h / 2), (sx, sy, h), step=10, dent=0)
        obj = b.build()
        obj.display_type = "WIRE"
        obj.hide_render = True
        out.append(obj)
    return out


def slug(name):
    table = {"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss"}
    out = "".join(table.get(ch, ch) for ch in name.lower())
    return "".join(ch if ch.isalnum() else "_" for ch in out).strip("_")


def write_game_materials():
    """Je Blender-Material ein Godot-Material (Shader storybook.gdshader, Glas eigenes Material).
    Liefert {Blender-Name: res-Pfad}."""
    os.makedirs(GAME_MAT_DIR, exist_ok=True)
    out = {}
    for name, v in GAME_MATERIALS.items():
        path = os.path.join(GAME_MAT_DIR, slug(name) + ".tres")
        res = "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")
        out[name] = res
        c = v["color"]
        head = "; Erzeugt von tools/blender/build_storybook_shop.py (Blender-Material \"%s\") – wird beim Neubau\n; überschrieben. Werte gern ausprobieren, dauerhaft aber im Bau-Script ändern.\n" % name
        if v.get("glass"):
            text = ('[gd_resource type="StandardMaterial3D" format=3]\n\n%s\n[resource]\nresource_name = "%s"\n'
                    'transparency = 1\nalbedo_color = Color(%.3f, %.3f, %.3f, 0.06)\nmetallic_specular = 0.12\nroughness = 0.15\n'
                    % (head, name, c[0], c[1], c[2]))
        else:
            c2 = v.get("color2") or c
            ec = v.get("emit_color") or c
            emit = v.get("emit", 0.0)
            text = ('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n%s\n'
                    '[ext_resource type="Shader" path="res://assets/shaders/%s.gdshader" id="1_shader"]\n\n'
                    '[resource]\nresource_name = "%s"\nrender_priority = 0\nshader = ExtResource("1_shader")\n'
                    'shader_parameter/base_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/second_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/grain = %d\nshader_parameter/stripe_width = %.3f\nshader_parameter/vary = %.3f\n'
                    'shader_parameter/blot_scale = %.3f\nshader_parameter/bump_strength = %.3f\nshader_parameter/rough = %.3f\n'
                    'shader_parameter/metal = %.3f\nshader_parameter/emission_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/emission_energy = %.3f\nshader_parameter/glow = %.3f\n'
                    % (head, "storybook_plant" if v["plant"] else "storybook", name, c[0], c[1], c[2], c2[0], c2[1], c2[2], GRAIN_ID[v.get("grain", "plaster")], v.get("stripes") or 0.0,
                       v.get("vary", 0.08), v.get("scale", 4.0), v.get("bump", 0.25), v.get("rough", 0.85), v.get("metal", 0.0),
                       ec[0], ec[1], ec[2], emit * 0.45, v["glow"]))
        with open(path, "w") as f:
            f.write(text)
    return out


def export_game(C, cols, path=GAME_GLB):
    """Kopie fürs Spiel aus dem gerade gebauten Haus (ohne Umgebung und Lichter)."""
    objs = [o for key, coll in C.items() if key not in ("env", "collision", "light") for o in coll.objects]
    return export_objects(objs, cols, path)


def leaf_tops(me):
    """Von jedem Blatt (Insel aus Ober-, Unterseite und Rand) nur die größte Fläche behalten –
    im Spiel sind Blätter von beiden Seiten sichtbar (storybook_plant.gdshader)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    seen = set()
    drop = []
    for f in bm.faces:
        if f.index in seen:
            continue
        island, stack = [], [f]
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        # Nur flache Inseln (Blätter, Blütenblätter) – Stiele u. Ä. haben keine große Fläche
        if len(island) > 3:
            keep = max(island, key=lambda g: g.calc_area())
            if keep.calc_area() > 0.3 * sum(g.calc_area() for g in island):
                drop += [g for g in island if g is not keep]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.to_mesh(me)
    bm.free()


def export_objects(objs, cols, path, simplify=None):
    """Alle Teile mit gleichem Material zu einem Netz zusammenfassen (wenige Zeichenaufrufe),
    Modifikatoren anwenden und als .glb speichern. simplify(material) = True: nur die Oberseiten
    der Blätter (leaf_tops). Die Einzelteile bleiben unverändert."""
    tmp = SB.collection("_export")
    groups = {}
    for obj in objs:
        if obj.type == "MESH" and obj.data.materials and obj.data.materials[0] is not None:
            groups.setdefault(obj.data.materials[0].name, []).append(obj)
    dg = bpy.context.evaluated_depsgraph_get()
    merged = []
    for name, objs in groups.items():
        copies = []
        for o in objs:
            me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
            c = bpy.data.objects.new(name, me)
            c.matrix_world = o.matrix_world
            tmp.objects.link(c)
            copies.append(c)
        if simplify and simplify(objs[0].data.materials[0]):
            for c in copies:
                leaf_tops(c.data)
        with bpy.context.temp_override(active_object=copies[0], object=copies[0], selected_objects=copies,
                                       selected_editable_objects=copies):
            bpy.ops.object.join()
        obj = copies[0]
        obj.name = name
        ca = obj.data.color_attributes.get("tint")
        if ca:
            obj.data.color_attributes.active_color = ca
            obj.data.color_attributes.render_color_index = list(obj.data.color_attributes).index(ca)
        merged.append(obj)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in merged + cols:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_colors=True,
                              export_lights=False, export_cameras=False, export_texcoords=False, export_normals=True,
                              export_yup=True, export_materials="EXPORT")
    tris = sum(len(p.vertices) - 2 for o in merged for p in o.data.polygons)
    for o in merged:
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
    bpy.data.collections.remove(tmp)
    return tris, len(merged)


def write_import_settings(mapping, path=GAME_GLB):
    """Godot-Importeinstellungen: Materialien der .glb -> assets/materials/storybook/*.tres;
    Detailstufen (LOD) an, damit das Haus aus der Ferne günstiger wird."""
    entries = ",\n".join('"%s": {\n"use_external/enabled": true,\n"use_external/path": "%s"\n}' % (k, v)
                          for k, v in sorted(mapping.items()))
    res = "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")
    text = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="%s"

[params]

meshes/generate_lods=true
_subresources={
"materials": {
%s
}
}
""" % (res, entries)
    with open(path + ".import", "w") as f:
        f.write(text)


# --- Schutz für selbst bearbeitete .blend ---

STAMP = os.path.join(os.path.dirname(BLEND), "fashion_shop_storybook.stamp")


def blend_fingerprint():
    import hashlib
    with open(BLEND, "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()


def edited_by_hand():
    """Wurde die .blend nach dem letzten Bau in Blender geändert? (Fingerabdruck stimmt nicht.)"""
    if not os.path.exists(BLEND) or not os.path.exists(STAMP):
        return False
    return open(STAMP).read().strip() != blend_fingerprint()


# --- Bilder ---

def setup_render(quick):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48 if quick else 320
    sc.cycles.max_bounces = 8
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.02
    sc.cycles.sample_clamp_indirect = 3.0
    sc.cycles.blur_glossy = 1.0
    sc.cycles.caustics_refractive = False
    sc.cycles.caustics_reflective = False
    try:
        sc.cycles.use_denoising = True
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        sc.cycles.use_denoising = False
    sc.view_settings.view_transform = "Filmic"
    sc.view_settings.look = "Medium Contrast"
    sc.view_settings.exposure = 0.15
    world = bpy.data.worlds.new("Himmel")
    sc.world = world
    world.use_nodes = True
    N, L = world.node_tree.nodes, world.node_tree.links
    bg = N["Background"]
    sky = N.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"
    sky.sun_elevation = math.radians(24)
    sky.sun_rotation = math.radians(215)
    sky.sun_intensity = 0.0
    warm = N.new("ShaderNodeMixRGB")
    warm.blend_type = "MULTIPLY"
    warm.inputs[0].default_value = 1.0
    warm.inputs[2].default_value = (1.0, 0.86, 0.7, 1)
    L.new(sky.outputs[0], warm.inputs[1])
    L.new(warm.outputs[0], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.42
    sun = bpy.data.lights.new("Sonne 3500 K", "SUN")
    sun.energy = 3.6
    sun.color = kelvin_rgb(3500)
    sun.angle = math.radians(9)
    so = bpy.data.objects.new("Sonne 3500 K", sun)
    so.rotation_euler = (math.radians(58), 0, math.radians(-38))
    sc.collection.objects.link(so)
    # mildes, warmes Leuchten um Lichter (Bloom)
    sc.use_nodes = True
    tree = sc.node_tree
    rl = tree.nodes["Render Layers"]
    comp = tree.nodes["Composite"]
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.glare_type = "FOG_GLOW"
    glare.quality = "HIGH"
    glare.threshold = 0.85
    glare.size = 8
    glare.mix = -0.72
    tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], comp.inputs["Image"])


def render(name, cam, target, lens, res, focus=None, fstop=6.0):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.dof.use_dof = True
    data.dof.aperture_fstop = fstop
    obj = bpy.data.objects.new("Kamera " + name, data)
    sc.collection.objects.link(obj)
    obj.location = cam
    obj.rotation_euler = (Vector(target) - Vector(cam)).to_track_quat("-Z", "Y").to_euler()
    data.dof.focus_distance = focus or (Vector(target) - Vector(cam)).length
    sc.camera = obj
    os.makedirs(SHOTS, exist_ok=True)
    sc.render.filepath = os.path.join(SHOTS, name + ".png")
    bpy.ops.render.render(write_still=True)


# --- Ablauf ---

WIN_JITTER = []


def build_scene(game):
    """Ganzes Haus bauen. game = leichte Kopie fürs Spiel (siehe SB.GAME). Beide Durchgänge
    nutzen dieselben Zufallszahlen – Lage und Form sind gleich."""
    SB.GAME = game
    RND.seed(1907)
    WIN_JITTER.clear()
    GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    for x in WIN_X:
        WIN_JITTER.append((x, RND.uniform(-0.015, 0.015), RND.uniform(-1.4, 1.4)))
    M = materials()
    root = SB.collection("Modegeschäft (Bilderbuch)")
    C = {k: SB.collection(v, root) for k, v in (("walls", "Mauern"), ("roof", "Dach"), ("windows", "Fenster"), ("shop", "Laden"),
                                                ("inside", "Innen"), ("plants", "Pflanzen"), ("deco", "Deko"), ("light", "Licht"))}
    C["env"] = SB.collection("Umgebung (nur Vorschau)")
    C["collision"] = SB.collection("Kollision (Spiel)", root)
    walls(M, C)
    eaves_cornice(M, C)
    roof(M, C)
    pediment(M, C)
    chimneys(M, C)
    upper_windows(M, C)
    dormers(M, C)
    shopfront(M, C)
    lanterns(M, C)
    # Warmes Zimmer hinter den oberen Fenstern (Fensterlicht als Blickfang)
    up = Body("Zimmer oben", M["in_dark"], C["inside"], seed=150, vary=0.04)
    up.box((0, 3.0, SHOP_TOP + 0.05), (W - 0.6, 5.4, 0.1), step=0.8, dent=0.003)
    up.box((0, 3.0, E - 0.4), (W - 0.6, 5.4, 0.1), step=0.8, dent=0.003)
    up.box((0, 2.4, (SHOP_TOP + E) / 2), (W - 0.6, 0.1, E - SHOP_TOP), step=0.8, dent=0.003)
    up.build()
    for x in WIN_X:
        add_light("Zimmerlicht", (x, 1.0, 5.2), 2700, 28, C["light"], radius=0.15)
    # Pflanzen
    ivy_climb(M, C, -1, E - 0.55, 501)
    ivy_climb(M, C, 1, E - 0.35, 502)
    ivy_garland(M, C, -HW + 0.1, -0.5, 511)
    ivy_garland(M, C, HW - 0.1, 0.65, 512)
    boxwood(M, C, (-HW + 0.38, -0.62, 0.33), 0.35, 521)
    boxwood(M, C, (HW - 0.38, -0.63, 0.34), 0.36, 522)
    hydrangea_tub(M, C, (-1.15, -0.48), 531)
    olive_pot(M, C, (1.12, -0.45), 532)
    chalkboard(M, C, (1.78, -0.6), -14)
    house = [o for k, c in C.items() if k != "env" for o in c.objects]
    settle(house, SETTLE)
    cols = colliders(C)
    pavement(M, C)
    return M, C, cols


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if edited_by_hand() and "--force" not in argv:
        print("Die .blend wurde in Blender bearbeitet – nichts überschrieben. Ins Spiel bringen mit\n"
              "  blender -b %s --python tools/blender/export_storybook.py\n"
              "Neu bauen (eigene Änderungen gehen verloren): ... build_storybook_shop.py -- --force" % os.path.relpath(BLEND, ROOT))
        return
    if "--no-game" not in argv:
        M, C, cols = build_scene(True)
        mapping = write_game_materials()
        tris, parts = export_game(C, cols)
        write_import_settings(mapping)
        print("Spiel: %s (%d Dreiecke, %d Netze)" % (GAME_GLB, tris, parts))
    M, C, cols = build_scene(False)
    # Prüfung: jedes Teil ein geschlossener Körper?
    open_parts = [(o.name, SB.non_manifold(o)) for c in C.values() for o in c.objects if o.type == "MESH"]
    bad = [(n, k) for n, k in open_parts if k]
    faces = sum(len(o.data.polygons) for c in C.values() for o in c.objects if o.type == "MESH")
    print("Teile: %d, Flächen: %d" % (len(open_parts), faces))
    print("Offene Kanten: %s" % (bad if bad else "keine – alles geschlossene Körper"))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    if "--render" in argv:
        quick = "--quick" in argv
        setup_render(quick)
        s = 0.5 if quick else 1.0
        only = [a.split("=", 1)[1].split(",") for a in argv if a.startswith("--only=")]
        views = {
            "vorn": ((0.0, -13.5, 1.75), (0.0, 0.0, 5.3), 44, (1024, 1536)),
            "schraeg_links": ((-7.0, -9.5, 2.0), (0.2, 0.0, 4.6), 30, (1600, 1100)),
            "schraeg_rechts": ((7.0, -9.5, 2.0), (-0.2, 0.0, 4.6), 30, (1600, 1100)),
            "laden": ((1.4, -4.4, 1.6), (-0.1, 0.0, 1.9), 26, (1600, 1100)),
            "dach": ((3.2, -5.6, 8.9), (0.0, 1.6, 8.0), 32, (1600, 1100)),
            "efeu": ((3.7, -2.6, 2.6), (2.45, 0.0, 3.2), 32, (1100, 1400)),
            "fenster": ((0.6, -2.4, 4.9), (0.0, 0.0, 4.75), 30, (1400, 1000)),
        }
        for name, (cam, target, lens, res) in views.items():
            if only and name not in only[0]:
                continue
            render(name, cam, target, lens, (int(res[0] * s), int(res[1] * s)))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(blend_fingerprint() + "\n")
    print("Gespeichert:", BLEND)


if __name__ == "__main__":
    main()
