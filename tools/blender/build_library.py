"""Baut die Fassade der Bücherei (seit Etappe 4g): eine alte englische Ladenfront aus
lackiertem Holz vor der Hauswand – Sockelfelder, Pilaster mit Konsolen, Wandvertäfelung neben
den bodentiefen Fenstern, Schildband mit Bild, Gesims, Wandlaternen, Hängekörbe.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_library.py
    blender -b --factory-startup --python tools/blender/build_library.py -- --check

Ergebnis:
    assets/models/world/library_facade.glb   (Knoten "Facade" im Raum, Koordinaten des Raums:
                                              y = 0 Ladenboden, draußen liegt der Gehweg 0,5 m tiefer)
    assets/models/source/library_facade.blend
    assets/textures/signs/library_fascia.png  Schild über den Fenstern (nur angelegt, wenn es fehlt)
    assets/textures/signs/library_door.png    Schild über der Tür
Lage der Wände wie in scenes/rooms/ground_floor_room.tscn (Außenseite: vorn z = -4,2, links
x = -3,2, Schräge dazwischen); Fenster 2,4 x 2,3 m (0,30 bis 2,60 m), Tür 1,4 x 2,6 m.
"""

import bpy
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
import style_parts as P  # noqa: E402
import street_houses as H  # noqa: E402
import build_houses as BH  # noqa: E402
from style_lib import Mat, V  # noqa: E402

GREEN = Mat("paint", color=(0.11, 0.2, 0.15))
GREEN_DARK = Mat("paint", color=(0.08, 0.15, 0.11))
GOLD = Mat("gold")
LEAD = Mat("metal")
GROUND = -0.5          # Gehweg (Ladenboden = 0)
FASCIA = (2.78, 3.3)   # Schildband von – bis
TOP = 3.42             # Oberkante Gesims (Deckenplatte 3,2 + 0,2)
PROUD = 0.012          # Bretter stehen so weit vor der Wand (kein Flimmern)

FRONT = ((3.2, -4.2), (-1.0828, -4.2))
LEFT = ((-3.2, -2.0828), (-3.2, 4.2))
DIAGONAL = ((-1.0828, -4.2), (-3.2, -2.0828))


def _local_x(a, c, x, z):
    """Lage eines Punkts (x, z) entlang der Wand a → c (Mitte = 0)."""
    mx, mz = (a[0] + c[0]) / 2, (a[1] + c[1]) / 2
    ln = math.hypot(c[0] - a[0], c[1] - a[1])
    return ((x - mx) * (c[0] - a[0]) + (z - mz) * (c[1] - a[1])) / ln


def panel_board(b, x0, x1, y0, y1, z=PROUD, mat=GREEN, panels=True):
    """Brett mit eingesetzten Füllungen (Rahmen und Kassetten), Vorderseite +z."""
    b.box((x0, y0, z), (x1, y1, z + 0.035), mat, skip=("back",))
    if not panels or x1 - x0 < 0.3 or y1 - y0 < 0.3:
        return
    n = max(1, round((y1 - y0) / 0.9))
    m = max(1, round((x1 - x0) / 0.8))
    for i in range(m):
        for j in range(n):
            px0 = x0 + 0.08 + (x1 - x0 - 0.16) * i / m + (0.03 if i else 0.0)
            px1 = x0 + 0.08 + (x1 - x0 - 0.16) * (i + 1) / m - (0.03 if i < m - 1 else 0.0)
            py0 = y0 + 0.08 + (y1 - y0 - 0.16) * j / n + (0.03 if j else 0.0)
            py1 = y0 + 0.08 + (y1 - y0 - 0.16) * (j + 1) / n - (0.03 if j < n - 1 else 0.0)
            b.frame(px0 + 0.025, py0 + 0.025, px1 - 0.025, py1 - 0.025, z + 0.035, z + 0.05, 0.025, mat)
            b.box((px0 + 0.07, py0 + 0.07, z + 0.035), (px1 - 0.07, py1 - 0.07, z + 0.045), mat, skip=("back",))


def pilaster(b, x, width=0.3):
    """Pilaster: Sockel, kannelierter Schaft, Kapitell und Konsole am Schildband."""
    hw = width / 2
    b.box((x - hw - 0.03, GROUND, PROUD), (x + hw + 0.03, GROUND + 0.35, 0.16), GREEN_DARK, skip=("back", "bottom"))
    b.box((x - hw, GROUND + 0.35, PROUD), (x + hw, FASCIA[0] - 0.25, 0.12), GREEN, skip=("back",))
    for k in range(3):
        fx = x - hw * 0.6 + k * hw * 0.6
        b.box((fx - 0.012, GROUND + 0.5, 0.12), (fx + 0.012, FASCIA[0] - 0.4, 0.13), GREEN_DARK, skip=("back",))
    b.box((x - hw - 0.02, FASCIA[0] - 0.25, PROUD), (x + hw + 0.02, FASCIA[0] - 0.15, 0.15), GREEN, skip=("back",))
    # Konsole (geschwungen angedeutet) vor dem Schildband
    b.box((x - hw - 0.02, FASCIA[0] - 0.15, PROUD), (x + hw + 0.02, FASCIA[1] + 0.05, 0.24), GREEN, skip=("back",))
    b.box((x - hw + 0.03, FASCIA[0] - 0.4, PROUD), (x + hw - 0.03, FASCIA[0] - 0.15, 0.2), GREEN, skip=("back",))
    b.cylinder(V(x - hw - 0.02, FASCIA[0] + 0.12, 0.22), 0.07, width + 0.04, GOLD, segments=10, caps=(True, True), axis="x")


def facade_band(b, half, sign_name, ends=True):
    """Schildband mit Bild (sign_name) und Gesims über die ganze Wandlänge (-half … half)."""
    b.box((-half, FASCIA[0], PROUD), (half, FASCIA[1], 0.18), GREEN, skip=("back", "front"))
    inset = 0.32 if ends else 0.05
    b.box((-half, FASCIA[0], 0.17), (-half + inset, FASCIA[1], 0.18), GREEN, skip=("back",))
    b.box((half - inset, FASCIA[0], 0.17), (half, FASCIA[1], 0.18), GREEN, skip=("back",))
    b.poly([V(-half + inset, FASCIA[0], 0.18), V(half - inset, FASCIA[0], 0.18), V(half - inset, FASCIA[1], 0.18), V(-half + inset, FASCIA[1], 0.18)],
           Mat("plain", sign=sign_name), uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    b.extrude_x([(PROUD, FASCIA[1]), (PROUD, TOP), (0.32, TOP), (0.32, FASCIA[1] + 0.07), (0.22, FASCIA[1] + 0.02), (0.18, FASCIA[1])],
                -half - 0.02, half + 0.02, GREEN)
    b.box((-half - 0.02, TOP, PROUD), (half + 0.02, TOP + 0.02, 0.33), LEAD, skip=("back",))


def window_surround(b, x0, x1, y0, y1):
    """Feine Rahmenleiste um ein Fenster und Brüstungsbrett darunter."""
    b.frame(x0, y0, x1, y1, PROUD, 0.07, 0.07, GREEN)
    b.box((x0 - 0.1, y0 - 0.12, PROUD), (x1 + 0.1, y0 - 0.07, 0.12), GREEN_DARK, skip=("back",))


def front_or_left(b, a, c, window_center, rnd, lantern_at=None, pots=()):
    """Vordere oder linke Wand: Pilaster an den Enden und neben dem Fenster, Vertäfelung,
    Sockelfelder, Fensterrahmen, Schildband."""
    xf, ln = H._facade_xf(a, c)
    b.push(xf)
    half = ln / 2
    wx0, wx1 = window_center - 1.27, window_center + 1.27
    wy0, wy1 = 0.24, 2.66
    # Sockelfelder unter dem Fenster und Vertäfelung daneben
    panel_board(b, wx0, wx1, GROUND + 0.05, wy0 - 0.12)
    for p0, p1 in ((-half + 0.15, wx0 - 0.15), (wx1 + 0.15, half - 0.15)):
        if p1 - p0 > 0.1:
            panel_board(b, p0, p1, GROUND + 0.05, FASCIA[0] - 0.02)
    panel_board(b, wx0, wx1, wy1 + 0.06, FASCIA[0] - 0.02, panels=False)
    window_surround(b, wx0, wx1, wy0, wy1)
    for x in (-half + 0.15, wx0 - 0.15, wx1 + 0.15, half - 0.15):
        pilaster(b, x)
    facade_band(b, half, "fascia")
    if lantern_at is not None:
        P.wall_lantern(b, lantern_at, 2.2, 0.12, mat=GREEN_DARK)
    for px in pots:
        b.cylinder(V(px, GROUND, 0.32), 0.17, 0.42, H.POT, segments=12, radius_top=0.21, caps=(False, True))
        b.sphere(V(px, GROUND + 0.62, 0.32), 0.25, P.leaf(rnd.randrange(3)), rings=5, segments=10, squash=1.0, jitter=0.15, seed=rnd.randrange(99))
        P.blossom_cluster(b, (px, GROUND + 0.66, 0.32), 0.24, rnd.choice(["lavender", "rose", "white"]), rnd, count=14)
        b.colliders.append(((px - 0.22, GROUND, 0.1), (px + 0.22, GROUND + 0.9, 0.54)))
    b.pop()


def diagonal(b, rnd):
    """Schräge mit der Tür: Rahmen um die Tür, kleines Schild darüber (Bild "door"), Gesims.
    Der Platz rechts neben der Tür (Einwurf des Rückgabekastens) bleibt frei."""
    a, c = DIAGONAL
    xf, ln = H._facade_xf(a, c)
    b.push(xf)
    half = ln / 2
    d = 0.8
    b.frame(-d, 0.0, d, 2.72, PROUD, 0.09, 0.09, GREEN, bottom=False)
    b.box((-half, 2.72 + 0.09, PROUD), (half, FASCIA[0], 0.06), GREEN, skip=("back",))
    facade_band(b, half, "door", ends=False)
    # Hängekörbe an beiden Ecken der Schräge
    for side in (-1, 1):
        P.hanging_basket(b, side * (half - 0.15), TOP + 0.1, 0.1, 0.42, seed=rnd.randrange(999))
    b.pop()


def build():
    rnd = random.Random(12)
    b = S.Builder("library_facade")
    fa, fc = FRONT
    la, lc = LEFT
    # Vorn: Fenster bei x = 1,0; Laterne links vom Fenster (Kartons stehen rechts vor der Wand)
    front_or_left(b, fa, fc, _local_x(fa, fc, 1.0, -4.2), rnd, lantern_at=_local_x(fa, fc, -0.55, -4.2))
    # Links (zur Gasse): Fenster bei z = 1,0; Laterne und zwei Töpfe am Gassenende der Wand
    front_or_left(b, la, lc, _local_x(la, lc, -3.2, 1.0), rnd, lantern_at=_local_x(la, lc, -3.2, 3.25),
                  pots=(_local_x(la, lc, -3.2, 3.7),))
    diagonal(b, rnd)
    return b


def _fascia_design(b):
    """Startbild des Schilds über den Fenstern: Dunkelgrün, Goldrand, "Bücherei" mit Büchern."""
    fw, fh = 3.6, 0.52
    b.box((-fw / 2, -fh / 2, -0.02), (fw / 2, fh / 2, 0.0), Mat("paint", color=(0.11, 0.2, 0.15)))
    for y0 in (-fh / 2 + 0.04, fh / 2 - 0.055):
        b.box((-fw / 2 + 0.06, y0, 0.0), (fw / 2 - 0.06, y0 + 0.015, 0.008), GOLD)
    start = len(b.faces)
    width = b.playful_text("Bücherei", 0.0, 0.0, 0.0, 0.28, 0.015, GOLD, font_path=S.PLAYFUL_FONT, seed=4, bounce=0.05, tilt=3,
                           first_scale=1.25)
    for side in (-1, 1):
        for k, col in enumerate(((0.55, 0.2, 0.2), (0.82, 0.68, 0.36), (0.25, 0.36, 0.5))):
            x = side * (width / 2 + 0.15 + k * 0.07)
            b.box((x - 0.03, -0.14, 0.0), (x + 0.03, 0.06 + 0.03 * (k % 2), 0.02), Mat("paint", color=col))
    b.recenter(start, 0.0, 0.0)


def _door_design(b):
    fw, fh = 2.99, 0.52
    b.box((-fw / 2, -fh / 2, -0.02), (fw / 2, fh / 2, 0.0), Mat("paint", color=(0.11, 0.2, 0.15)))
    start = len(b.faces)
    b.playful_text("Willkommen", 0.0, 0.0, 0.0, 0.2, 0.012, GOLD, font_path=S.PLAYFUL_FONT, seed=8, bounce=0.05, tilt=3)
    b.recenter(start, 0.0, 0.0)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    BH.SIGNS["library"] = {
        "fascia": (3.6, 0.52, 2048, _fascia_design),
        "door": (2.99, 0.52, 1536, _door_design),
    }
    signs = BH.prepare_signs("library")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    if "--check" in argv:
        S.SHOW_BACKFACES = True
    S.SIGN_PREFIX = "library_"
    b = build()
    glb = os.path.join(S.ROOT, "assets", "models", "world", "library_facade.glb")
    tris = S.write_glb(b, glb)
    S.write_import_settings(glb, signs)
    print("library_facade: %d Dreiecke" % tris)
    S.to_blender(b, {})
    if "--check" in argv:
        S.setup_render(resolution=(900, 700), samples=10)
        out = os.path.join(S.ROOT, "screenshots", "blender")
        S.render_view(os.path.join(out, "library-front.png"), (1.0, 1.2, -9.5), (0.5, 1.5, -4.2), lens=26)
        S.render_view(os.path.join(out, "library-corner.png"), (-6.0, 1.2, -8.0), (-2.0, 1.4, -3.0), lens=24)
        S.render_view(os.path.join(out, "library-left.png"), (-7.5, 1.2, 1.0), (-3.2, 1.4, 1.0), lens=24)
    blend = os.path.join(S.ROOT, "assets", "models", "source", "library_facade.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend, relative_remap=True, compress=True)


main()
