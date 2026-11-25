"""Holzhäuschen im großen Garten (Etappe 8d, Zettel 05 der Oase; Wünsche der Entwicklerin nach der Testrunde): klein, frei
stehend, schräg gestellt, eine Etage, wie ein Tiny House mit Gauben (Fenster im Dach mit eigenem kleinen Satteldach).
Innen ein offener Raum bis unters schräge Dach mit sichtbaren Balken; durch die Gauben fällt Licht von oben (Wunsch: „ein
offener Raum“). Seit dem Lageplan der Entwicklerin größer (5,8 × 4,4 m) und übers Eck in der Gartenecke: die Gartenmauern stoßen
an die Seitenwände, die Veranda zeigt zum Bach, die Brücke führt direkt auf sie. Außen waagerechte Bretter als „ästhetische Mischung“ (Beispielbilder der Entwicklerin): türkis- und himmelblau
gestrichene Bretter, deren Farbe abblättert (helles Holz schaut durch – storybook.gdshaderinc weather/peel), dazwischen nacktes
Holz in Honig, Rotbraun, Silbergrau und ein paar dunkle Bretter, einzelne moosgrün gestrichene. Vor der Tür eine kleine
überdachte Veranda (zwei Pfosten, eigenes Satteldach) – Wunsch der Entwicklerin.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_cottage.py [-- --render [--quick]] [--force]
Ergebnis: assets/models/world/garden_cottage.glb, Quelle assets/models/source/garden_cottage_storybook.blend
Lage: Ursprung = Mitte der Grundfläche am Boden; Vorderseite (Tür, Gauben) Blender -y = Godot +z. Das Spiel dreht das Häuschen
an seinen Platz (GameConfig.backyard_cottage_*, scripts/world/alley.gd); Breite und Tiefe aus GameConfig.backyard_cottage_size
(über assets/models/source/layout.json). Die Tür baut das Spiel (scenes/objects/cottage_door.tscn) an den Punkt
„GameSpot_cottage_door“ (Mitte der Öffnung unten auf der Außenfläche; Extras: Maße, Wanddicke, Veranda).
Kollision: Wände als Kästen „…-colonly“; Boden und Rampe vor der Tür setzt das Spiel (Boden FLOOR über dem Rasen).
"""

import json
import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_houses as SH  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

GLB = os.path.join(SC.ROOT, "assets", "models", "world", "garden_cottage.glb")
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "garden_cottage_storybook.blend")
STAMP = BLEND.replace(".blend", ".stamp")
L = json.load(open(os.path.join(SC.ROOT, "assets", "models", "source", "layout.json")))

## Grundfläche (Außenkante der Wände): Breite (Blender x) und Tiefe (Blender y)
W, D = float(L["backyard_cottage"][2]), float(L["backyard_cottage"][3])
## Höhen: Steinsockel, Oberkante Fußboden, Oberkante der Wände; Wanddicke
PLINTH = 0.12
FLOOR = 0.15
EAVES = 2.45
WALL_T = 0.14
## Dach: Neigung (Grad), Überstand an Traufe und Giebel; Dachkern 16 cm (storybook_town.cozy_roof: Oberfläche bis 17 cm darunter)
PITCH = 44.0
OVER = 0.32
GABLE_OVER = 0.3
TAN = math.tan(math.radians(PITCH))
SPAN = D / 2 + OVER
CORE_DOWN = 0.17 / math.cos(math.radians(PITCH))     # senkrechter Abstand Dachfläche – Unterseite des Dachkerns
ROOF_EAVES = EAVES - OVER * TAN + CORE_DOWN          # Höhe der Traufkante: Unterseite des Dachs liegt genau auf den Wänden
RIDGE = ROOF_EAVES + SPAN * TAN
## Tür (Mitte vorn) und Fenster: (Wand, Mitte entlang der Wand ab ihrem Anfang, Unterkante über dem Boden, Breite, Höhe)
DOOR_W, DOOR_H = 0.9, 1.95
WIN_W, WIN_H, WIN_SILL = 0.7, 0.95, 0.9
## Veranda vor der Tür: Tiefe (ab der Wand), Pfosten bei x = ±PORCH_X, Traufhöhe und Neigung des Vordachs
PORCH_DEPTH = 1.15
PORCH_X = 0.95
PORCH_EAVES = 2.3
PORCH_PITCH = 40.0
## Bretter: Arten (Material, Anteil); jede Reihe ist aus 1–3 Brettern zusammengesetzt, jedes Brett bekommt eine Art
BOARD_KINDS = (("b_turq", 24), ("b_sky", 18), ("b_honey", 17), ("b_red", 12), ("b_grey", 11), ("b_dark", 8), ("b_moss", 10))
## Gauben vorn: Mitte x, Vorderwand bei y = DY0, äußere halbe Breite, Fenster (Breite, Höhe)
DORMER_X = (-(W / 2 - 1.55), W / 2 - 1.55)
DY0 = -1.55
DORMER_HW = 0.5
DORMER_WIN = (0.56, 0.6)
DORMER_PITCH = 40.0


def roof_top(y):
    """Höhe der Dachfläche über dem Punkt y (beide Seiten)."""
    return ROOF_EAVES + (SPAN - abs(y)) * TAN


def roof_under(y):
    """Unterseite des Dachkerns über dem Punkt y – dort endet die Innenverkleidung."""
    return roof_top(y) - CORE_DOWN


## Gauben: Traufhöhe = Dachfläche an der Vorderwand + Fenster mit etwas Rand; dort, wo die Dachfläche diese Höhe erreicht,
## endet die Gaube hinten (DY1)
DORMER_EAVES = roof_top(DY0) + 0.12 + DORMER_WIN[1] + 0.14
DY1 = -(ROOF_EAVES + SPAN * TAN - DORMER_EAVES) / TAN


def mats(M):
    mk = SC.make_material
    wood = (0.76, 0.6, 0.42)       # helles Holz unter der Farbe
    # gestrichene Bretter: Farbe blättert ab (eigene Materialien – nur die tragen die Verwitterung ins Spiel)
    M["b_turq"] = mk("Bretter Türkis abgeblättert", (0.36, 0.64, 0.68), grain="paint", rough=0.8, vary=0.08, own=True,
                     weather=0.85, weather_color=wood, peel=0.7)
    M["b_sky"] = mk("Bretter Himmelblau verblichen", (0.55, 0.7, 0.78), grain="paint", rough=0.82, vary=0.08, own=True,
                    weather=0.9, weather_color=(0.7, 0.53, 0.36), peel=0.9)
    M["b_moss"] = mk("Bretter Moosgrün abgeblättert", (0.38, 0.5, 0.36), grain="paint", rough=0.85, vary=0.1, own=True,
                     weather=0.8, weather_color=(0.62, 0.48, 0.33), peel=0.6)
    # nacktes Holz
    M["b_honey"] = mk("Bretter Holz Honig", (0.7, 0.5, 0.31), grain="wood", rough=0.85, vary=0.1, bump=0.35)
    M["b_red"] = mk("Bretter Holz Rotbraun", (0.58, 0.34, 0.21), grain="wood", rough=0.85, vary=0.1, bump=0.35)
    M["b_grey"] = mk("Bretter Holz Silbergrau", (0.64, 0.6, 0.53), grain="wood", rough=0.9, vary=0.1, bump=0.35)
    M["b_dark"] = mk("Bretter Holz Dunkel", (0.27, 0.21, 0.17), grain="wood", rough=0.85, vary=0.1, bump=0.35)
    M["core"] = mk("Wandkern Häuschen", (0.42, 0.33, 0.26), grain="wood", rough=0.9, vary=0.06)
    M["h_join"] = mk("Lack Rahmen Häuschen", (0.93, 0.89, 0.8), grain="paint", rough=0.75, vary=0.04, own=True, weather=0.45,
                     weather_color=wood, peel=0.2)
    M["shutter"] = mk("Lack Läden Häuschen", (0.24, 0.45, 0.48), grain="paint", rough=0.78, vary=0.06, own=True, weather=0.75,
                      weather_color=wood, peel=0.55)
    M["in_wood"] = mk("Holz Häuschen innen", (0.8, 0.63, 0.43), grain="wood", rough=0.85, vary=0.06, bump=0.3)
    M["in_floor"] = mk("Dielen Häuschen", (0.6, 0.42, 0.27), grain="wood", rough=0.8, vary=0.08, bump=0.35)
    M["beam"] = mk("Balken Häuschen", (0.46, 0.31, 0.19), grain="wood", rough=0.85, vary=0.08, bump=0.4)
    M["shingle"] = mk("Holzschindeln Häuschen", (0.42, 0.34, 0.29), grain="wood", rough=0.9, vary=0.1, bump=0.4)
    M["shingle_cap"] = mk("Holzschindeln First", (0.33, 0.26, 0.22), grain="wood", rough=0.9, vary=0.08)
    M["deck"] = mk("Holz Veranda", (0.56, 0.42, 0.3), grain="wood", rough=0.85, vary=0.1, bump=0.35)
    M["pipe"] = mk("Ofenrohr Eisen", (0.22, 0.21, 0.2), grain="smooth", rough=0.55, metal=0.5, vary=0.04)


def board_kind(rnd, avoid=None):
    """Zufällige Brettart nach Anteil (nicht dieselbe wie avoid – Nachbarn sollen sich unterscheiden)."""
    kinds = [(k, w) for k, w in BOARD_KINDS if k != avoid]
    r = rnd.uniform(0, sum(w for _, w in kinds))
    for k, w in kinds:
        r -= w
        if r <= 0:
            return k
    return kinds[-1][0]


def walls_list():
    """Die vier Wände als (Anfang, Ende) der Außenkante, außen rechts der Laufrichtung (wie storybook_town.wall_matrix):
    vorn (-y), rechts (+x), hinten (+y), links (-x)."""
    a, b, c, d = (-W / 2, -D / 2), (W / 2, -D / 2), (W / 2, D / 2), (-W / 2, D / 2)
    return {"front": (a, b), "right": (b, c), "back": (c, d), "left": (d, a)}


## Seitenfenster so weit hinter der Vorderkante (m): im Garten steht das Häuschen übers Eck, die Gartenmauern treffen die
## Seitenwände etwa 2,7 m hinter der Vorderkante – die Fenster liegen davor, im Garten
SIDE_WIN = 1.5


def openings():
    """Öffnungen je Wand: (Mitte entlang der Wand ab ihrem Anfang, Unterkante, Breite, Höhe) – z ab Boden des Modells. Die
    rechte Wand beginnt vorn, die linke hinten (walls_list). Hinten ein Fenster mit Blick auf die Wiese hinter der Mauer."""
    win = lambda x, w=WIN_W: (x, FLOOR + WIN_SILL, w, WIN_H)  # noqa: E731
    return {
        "front": [(W / 2, FLOOR, DOOR_W, DOOR_H), win(W / 2 - (W / 2 - 1.1)), win(W / 2 + (W / 2 - 1.1))],
        "right": [win(SIDE_WIN)],
        "back": [win(W / 2, 0.9)],
        "left": [win(D - SIDE_WIN), (D / 2, EAVES + 0.55, 0.42, 0.42)],   # Fensterchen im Giebel (Raum offen bis unters Dach)
    }


def wall_outline(key, length):
    """Umriss einer Wand in ihrer Ebene (x entlang, y hoch): Vorder- und Rückwand rechteckig bis zur Traufe, die Seiten mit
    Giebeldreieck bis knapp unter die Dachunterseite (3 cm in den Dachkern hinein, damit keine Fuge bleibt)."""
    if key in ("front", "back"):
        return [(0.0, PLINTH), (length, PLINTH), (length, EAVES), (0.0, EAVES)]
    return [(0.0, PLINTH), (length, PLINTH), (length, EAVES), (length / 2, roof_under(0.0) + 0.03), (0.0, EAVES)]


def walls(M, C):
    """Wände: Kern (Holz), außen waagerechte Bretter in gemischten Arten (jede Reihe aus 1–3 Brettern, schmale Schattenfuge
    dazwischen), an den Giebeln senkrechte Bretter, innen helle Verkleidung; alles mit den Öffnungen geschnitten. Ecken: Vorder-
    und Rückwand laufen über die Ecken, die Seiten liegen dazwischen."""
    ops = openings()
    rnd = random.Random(77)
    for key, (p0, p1) in walls_list().items():
        length = T.seg_len(p0, p1)
        inset = 0.0 if key in ("front", "back") else WALL_T
        m = T.wall_matrix(p0, p1)
        core = Body("Wand %s" % key, M["core"], C["walls"], seed=500 + len(key), vary=0.03)
        outline = [(max(inset, min(length - inset, x)), y) for x, y in wall_outline(key, length)]
        core.slab(outline, WALL_T, m @ Matrix.Translation((0, 0, -WALL_T)), dent=0.0)
        boards = {k: Body("Bretter %s %s" % (key, k), M[k], C["walls"], seed=510 + len(key) + n, vary=0.07)
                  for n, (k, _) in enumerate(BOARD_KINDS)}
        z = PLINTH + 0.06
        row = 0
        above = []
        while z < EAVES - 0.05:
            top = min(z + 0.16, EAVES - 0.01)
            x0 = -0.03 if key in ("front", "back") else 0.0
            x1 = length + 0.03 if key in ("front", "back") else length
            # Stöße: 0–2 je Reihe, jedes Stück mindestens 0,8 m
            cuts = [x0, x1]
            for _ in range(rnd.choice((0, 1, 1, 2))):
                c = rnd.uniform(x0 + 0.8, x1 - 0.8)
                if all(abs(c - q) > 0.8 for q in cuts):
                    cuts.append(c)
            cuts.sort()
            row_kinds = []
            for a, b in zip(cuts, cuts[1:]):
                mid = (a + b) / 2
                over = [k for (aa, bb, k) in above if aa <= mid <= bb]
                kind = board_kind(rnd, row_kinds[-1] if row_kinds else (over[0] if over else None))
                row_kinds.append(kind)
                boards[kind].box(((a + b) / 2, (z + top) / 2, 0.012 + 0.004 * (row % 2)), (b - a - 0.006, top - z, 0.024),
                                 step=0.7, dent=0.003, matrix=m)
            above = [(a, b, k) for (a, b), k in zip(zip(cuts, cuts[1:]), row_kinds)]
            z = top + 0.005
            row += 1
        if key in ("left", "right"):
            x = 0.12
            last = None
            while x < length - 0.1:
                h = roof_under(0.0) - (abs(x - length / 2) / (length / 2)) * (roof_under(0.0) - EAVES) - EAVES - 0.02
                if h > 0.08:
                    last = board_kind(rnd, last)
                    boards[last].box((x, EAVES + h / 2 + 0.01, 0.014), (0.2, h, 0.028), step=0.7, dent=0.003, matrix=m)
                x += 0.21
        lining = Body("Verkleidung %s" % key, M["in_wood"], C["inside"], seed=520 + len(key), vary=0.05)
        lo = [(max(WALL_T, min(length - WALL_T, x)), max(y, FLOOR - 0.01)) for x, y in wall_outline(key, length)]
        if key in ("left", "right"):
            lo[3] = (lo[3][0], roof_under(0.0) - 0.06)
        lining.slab(lo, 0.02, m @ Matrix.Translation((0, 0, -WALL_T - 0.02)), dent=0.0)
        cuts = [(p0, p1, x, z0, w, h, 0.0, 0.0) for x, z0, w, h in ops.get(key, [])]
        for body in [core, lining] + [b for b in boards.values() if len(b.bm.verts)]:
            obj = body.build()
            T.cut(obj, cuts, bevel=0.0)


def trims_and_windows(M, C):
    """Eckbretter, Fenster (Rahmen, Sprossen, Glas, Vorhänge), Fensterbänke, Läden und Blumenkästen vorn, Türzarge."""
    t = Body("Eckbretter", M["h_join"], C["walls"], seed=530, vary=0.04, bevel=0.006)
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.box((sx * (W / 2 + 0.005), sy * (D / 2 + 0.005), (PLINTH + EAVES) / 2), (0.13, 0.13, EAVES - PLINTH), step=0.6,
                  dent=0.002)
    t.build()
    ops = openings()
    k = 0
    for key, (p0, p1) in walls_list().items():
        for x, z0, w, h in ops.get(key, []):
            if key == "front" and abs(x - W / 2) < 0.01:
                continue  # Tür
            fm = T.wall_matrix(p0, p1, x, z0, 0.03)
            SH.window(M, C, "Fenster %d" % k, fm, w, h, 0.0, panes=(2, 2) if h > 0.5 else (1, 1), curtains=h > 0.5, seed=540 + k,
                      frame="h_join")
            sill = Body("Fensterbank %d" % k, M["h_join"], C["windows"], seed=560 + k, vary=0.04, bevel=0.006)
            sill.box((0.0, -0.03, 0.05), (w + 0.16, 0.06, 0.12), step=0.5, dent=0.002, matrix=fm)
            sill.build()
            if key == "front":
                T.shutters(M, C, "Läden %d" % k, fm, w, h, mat="shutter", open_off=8.0, seed=570 + k)
                SC.planter_box(M, C["pots"], "Blumenkasten %d" % k, fm @ Matrix.Translation((0, -0.2, 0.08)), w + 0.06, 0.2, 0.18,
                               seed=580 + k)
            k += 1
    # Türzarge vorn (die Tür selbst baut das Spiel)
    p0, p1 = walls_list()["front"]
    fm = T.wall_matrix(p0, p1, W / 2, FLOOR, 0.0)
    z = Body("Türzarge", M["h_join"], C["walls"], seed=590, vary=0.04, bevel=0.006)
    for sx in (-1, 1):
        z.box((sx * (DOOR_W / 2 + 0.05), DOOR_H / 2, -WALL_T / 2 + 0.02), (0.1, DOOR_H, WALL_T + 0.08), step=0.5, dent=0.002, matrix=fm)
    z.box((0.0, DOOR_H + 0.06, -WALL_T / 2 + 0.02), (DOOR_W + 0.3, 0.12, WALL_T + 0.08), step=0.5, dent=0.002, matrix=fm)
    z.box((0.0, -0.015, -WALL_T / 2), (DOOR_W, 0.03, WALL_T), step=0.5, dent=0.001, matrix=fm)  # Schwelle
    z.build()


def base_and_floor(M, C):
    """Steinsockel rund um die Wände, Dielenboden innen, Veranda vor der Tür (Dielen auf Pfosten, Steinstufe davor, Töpfe)."""
    s = Body("Sockel", M["stone"], C["walls"], seed=600, vary=0.08, bevel=0.01)
    for (p0, p1) in walls_list().values():
        T.wall_run(s, p0, p1, 0.0, PLINTH, thick=WALL_T + 0.06, inset=-0.03, ext=(0.03, 0.03), step=0.4, dent=0.006)
    s.build()
    f = Body("Dielen", M["in_floor"], C["inside"], seed=601, vary=0.06)
    inner = W - 2 * WALL_T, D - 2 * WALL_T
    n = int(inner[0] / 0.16)
    for i in range(n):
        x = -inner[0] / 2 + (i + 0.5) * inner[0] / n
        f.box((x, 0.0, FLOOR - 0.035), (inner[0] / n - 0.004, inner[1], 0.07), step=0.9, dent=0.002)
    f.build()
    under = Body("Unterboden", M["beam"], C["inside"], seed=602, vary=0.04)
    under.box((0.0, 0.0, (0.02 + FLOOR - 0.07) / 2), (inner[0], inner[1], FLOOR - 0.07 - 0.02), step=1.0, dent=0.0)
    under.build()
    v = Body("Veranda", M["deck"], C["deco"], seed=603, vary=0.1, bevel=0.006)
    y0 = -D / 2 - 0.035
    rows = 6
    step_y = (PORCH_DEPTH - 0.04) / rows
    for i in range(rows):
        v.box((0.0, y0 - step_y * (i + 0.5), FLOOR - 0.02), (2 * PORCH_X + 0.16, step_y - 0.008, 0.04), step=0.6, dent=0.003)
    for sx in (-1, 1):
        for y in (y0 - 0.1, porch_front() + 0.06):
            v.box((sx * PORCH_X, y, (FLOOR - 0.04) / 2), (0.1, 0.1, FLOOR - 0.04), step=0.5, dent=0.002)
    v.build()
    st = Body("Stufe", M["stone"], C["deco"], seed=604, vary=0.08, bevel=0.01)
    st.box((0.0, porch_front() - 0.16, (FLOOR / 2) / 2), (1.3, 0.3, FLOOR / 2), step=0.5, dent=0.004)
    st.build()
    for k, sx in enumerate((-1, 1)):
        SC.pot(M, C["pots"], "Topf Veranda %d" % k, (sx * (PORCH_X - 0.2), y0 - 0.25, FLOOR), 0.16, 0.28, seed=610 + k)


def porch_front():
    """Vorderkante der Veranda (Blender y)."""
    return -D / 2 - PORCH_DEPTH


def porch_roof(M, C):
    """Vordach über der Veranda: zwei Pfosten auf den Dielen, Querbalken darauf, Wandbalken an der Front, kleines Satteldach
    (First quer zur Wand – es läuft hinten in die Traufe des großen Dachs), vorn ein Giebel aus senkrechten Brettern."""
    yf = porch_front() + 0.06
    p = Body("Veranda Pfosten", M["h_join"], C["deco"], seed=700, vary=0.04, bevel=0.008)
    for sx in (-1, 1):
        p.box((sx * PORCH_X, yf, (FLOOR + PORCH_EAVES) / 2), (0.11, 0.11, PORCH_EAVES - FLOOR), step=0.5, dent=0.002)
        # Kopfband zwischen Pfosten und Querbalken
        p.span(Vector((sx * (PORCH_X - 0.05), yf, PORCH_EAVES - 0.38)), Vector((sx * (PORCH_X - 0.34), yf, PORCH_EAVES - 0.08)),
               0.06, 0.06, step=0.3, dent=0.002)
    p.box((0.0, yf, PORCH_EAVES - 0.07), (2 * PORCH_X + 0.24, 0.12, 0.14), step=0.6, dent=0.002)   # Querbalken
    p.box((0.0, -D / 2 - 0.05, PORCH_EAVES - 0.07), (2 * PORCH_X + 0.24, 0.07, 0.14), step=0.6, dent=0.002)   # Wandbalken
    for sx in (-1, 1):
        p.box((sx * (PORCH_X + 0.05), (yf - D / 2 - 0.05) / 2, PORCH_EAVES - 0.07), (0.1, abs(yf + D / 2 + 0.05), 0.14), step=0.6,
              dent=0.002)
    p.build()
    span = PORCH_X + 0.22
    a = math.radians(PORCH_PITCH)
    ridge = PORCH_EAVES + span * math.tan(a)
    y_back = -D / 2 + 0.05
    y_front = yf - 0.22
    frame = Matrix.Translation((0.0, (y_back + y_front) / 2, 0.0)) @ Matrix.Rotation(math.pi / 2, 4, "Z")
    T.cozy_roof(M, C, "Vordach", frame, y_back - y_front, span, PORCH_EAVES, PORCH_PITCH, "shingle", cap_mat="shingle_cap",
                ends=(0.0, 0.0), seed=705, tile_w=0.24, row=0.2)
    # Giebeldreieck vorn aus senkrechten Brettern (gemischte Arten wie die Wände)
    rnd = random.Random(91)
    under = lambda x: ridge - abs(x) * math.tan(a) - 0.2  # noqa: E731
    gb = {}
    x = -PORCH_X - 0.02
    last = None
    while x < PORCH_X + 0.02:
        h = under(x) - PORCH_EAVES
        if h > 0.05:
            last = board_kind(rnd, last)
            body = gb.setdefault(last, Body("Vordach Giebel %s" % last, M[last], C["deco"], seed=710 + len(gb), vary=0.07))
            body.box((x, yf, PORCH_EAVES + h / 2), (0.15, 0.03, h), step=0.5, dent=0.002)
        x += 0.16
    for body in gb.values():
        body.build()


def roof(M, C):
    """Satteldach aus Holzschindeln (Traufen vorn und hinten), Löcher für die Gauben in Kern und Schindeln, die Gauben (Vorderwand
    mit Fenster, Seitenwände, eigenes Satteldach) und ein Ofenrohr hinten."""
    a = math.radians(PITCH)
    holes = []
    x_left = -W / 2 - GABLE_OVER
    for cx in DORMER_X:
        s0 = (SPAN - abs(DY0) - 0.06) / math.cos(a)
        s1 = (SPAN - abs(DY1) + 0.25) / math.cos(a)
        holes.append((cx - DORMER_HW - x_left - 0.04, cx + DORMER_HW - x_left + 0.04, s0, s1))
    T.cozy_roof(M, C, "Dach", Matrix.Identity(4), W, SPAN, ROOF_EAVES, PITCH, "shingle", cap_mat="shingle_cap",
                ends=(GABLE_OVER, GABLE_OVER), holes=holes, seed=620, tile_w=0.28, row=0.22)
    core = [o for o in C["roof"].objects if o.name.startswith("Dach Dachflächen")][0]
    cutters = []
    for cx in DORMER_X:
        cutters.append(SB.cutter((cx, (DY0 + 0.06 + DY1 + 0.1) / 2, 3.5), (2 * DORMER_HW - 0.12, DY1 + 0.1 - DY0 - 0.06, 3.0)))
    SB.boolean_cut(core, cutters)
    for i, cx in enumerate(DORMER_X):
        dormer(M, C, cx, i)
    # Ofenrohr auf der hinteren Fläche
    px, py = -1.25, 0.75
    p = Body("Ofenrohr", M["pipe"], C["roof"], seed=640, vary=0.03)
    z0 = roof_top(py) - 0.12
    p.tube([(px, py, z0), (px, py, z0 + 0.85)], 0.075, segs=14)
    p.tube([(px, py, z0 + 0.86), (px, py, z0 + 0.9)], 0.13, segs=14)
    p.lathe([(0.0, 0.0), (0.16, 0.0), (0.0, 0.09)], (px, py, z0 + 0.95), segs=14)
    p.build()


def dormer(M, C, cx, i):
    """Gaube bei x = cx: Vorderwand (Bretter, mit Fenster) von der Dachfläche bis unter ihr Dach, zwei Seitenwangen, die auf der
    Dachfläche stehen (unten bis zur Unterseite des Dachkerns – innen schließen sie das Loch), eigenes kleines Satteldach,
    Ortgangbretter. Innen sieht man in die Nische hinauf (Wangen, Fenster, Unterseite des Gaubendachs)."""
    hw = DORMER_HW
    z_lo = roof_under(DY0) - 0.02
    span = hw + 0.08
    a = math.radians(DORMER_PITCH)
    ridge = DORMER_EAVES + span * math.tan(a)
    under = lambda x: DORMER_EAVES + (span - abs(x)) * math.tan(a) - 0.12 / math.cos(a)  # noqa: E731
    front = Body("Gaube %d Vorderwand" % i, M["b_sky"], C["roof"], seed=650 + i, vary=0.04)
    outline = [(cx - hw, z_lo), (cx + hw, z_lo), (cx + hw, DORMER_EAVES), (cx, under(0.0) + 0.02), (cx - hw, DORMER_EAVES)]
    to_xz = Matrix(((1, 0, 0, 0), (0, 0, 1, DY0), (0, 1, 0, 0), (0, 0, 0, 1)))   # Umriss (x, z) in der Ebene y = DY0, Dicke nach +y
    front.slab(outline, 0.08, to_xz, dent=0.0)
    fo = front.build()
    win_z = roof_top(DY0) + 0.12
    fm = Matrix.Translation((cx, DY0, win_z)) @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    SB.boolean_cut(fo, [SB.cutter((0, DORMER_WIN[1] / 2, 0), (DORMER_WIN[0], DORMER_WIN[1], 0.6), matrix=fm)])
    SH.window(M, C, "Gaubenfenster %d" % i, fm @ Matrix.Translation((0, 0, 0.02)), DORMER_WIN[0], DORMER_WIN[1], 0.0, panes=(2, 2),
              curtains=False, seed=660 + i, frame="h_join")
    # Seitenwangen: Umriss (y, z) in der Ebene x = cx ± hw, Dicke nach innen
    cheeks = Body("Gaube %d Wangen" % i, M["b_turq"], C["roof"], seed=670 + i, vary=0.04)
    for side in (-1, 1):
        x = cx + side * hw
        pts = [(DY0, roof_under(DY0) - 0.02), (DY1, roof_under(DY1) - 0.02), (DY1, DORMER_EAVES), (DY0, DORMER_EAVES)]
        to_yz = Matrix(((0, 0, -side, x), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        cheeks.slab(pts, 0.07, to_yz, dent=0.0)
    cheeks.build()
    inside = Body("Gaube %d innen" % i, M["in_wood"], C["inside"], seed=675 + i, vary=0.04)
    for side in (-1, 1):
        x = cx + side * (hw - 0.07)
        pts = [(DY0 + 0.08, roof_under(DY0 + 0.08) - 0.01), (DY1, roof_under(DY1) - 0.01), (DY1, DORMER_EAVES - 0.01),
               (DY0 + 0.08, DORMER_EAVES - 0.01)]
        to_yz = Matrix(((0, 0, -side, x), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        inside.slab(pts, 0.015, to_yz, dent=0.0)
    inside.build()
    # innen vor der Vorderwand der Gaube ebenfalls helles Holz (mit Fensterloch) – sonst sähe man von innen die Farbe von außen
    front_in = Body("Gaube %d innen vorn" % i, M["in_wood"], C["inside"], seed=677 + i, vary=0.04)
    inner_outline = [(cx - hw + 0.07, roof_under(DY0 + 0.08) - 0.01), (cx + hw - 0.07, roof_under(DY0 + 0.08) - 0.01),
                     (cx + hw - 0.07, DORMER_EAVES - 0.01), (cx - hw + 0.07, DORMER_EAVES - 0.01)]
    front_in.slab(inner_outline, 0.015, Matrix(((1, 0, 0, 0), (0, 0, 1, DY0 + 0.08), (0, 1, 0, 0), (0, 0, 0, 1))), dent=0.0)
    fio = front_in.build()
    SB.boolean_cut(fio, [SB.cutter((0, DORMER_WIN[1] / 2, 0), (DORMER_WIN[0], DORMER_WIN[1], 0.6), matrix=fm)])
    # Wechsel: Balken unter der Vorderwand der Gaube (trägt sie, wo das Dach ausgeschnitten ist – von innen sieht man ihn statt
    # der Unterkante der Wand)
    tr = Body("Gaube %d Wechsel" % i, M["beam"], C["inside"], seed=679 + i, vary=0.05, bevel=0.005)
    tr.box((cx, DY0 + 0.05, z_lo - 0.03), (2 * hw + 0.04, 0.16, 0.12), step=0.5, dent=0.002)
    tr.build()
    frame = Matrix.Translation((cx, (DY0 - 0.12 + DY1 + 0.45) / 2, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z")
    T.cozy_roof(M, C, "Gaubendach %d" % i, frame, DY1 + 0.45 - DY0 + 0.12, span, DORMER_EAVES, DORMER_PITCH, "shingle",
                cap_mat="shingle_cap", ends=(0.0, 0.0), seed=680 + i, tile_w=0.24, row=0.2, verge=False)
    ob = Body("Gaube %d Ortgang" % i, M["h_join"], C["roof"], seed=690 + i, vary=0.04, bevel=0.005)
    for side in (-1, 1):
        ob.span(Vector((cx + side * (span + 0.03), DY0 - 0.14, DORMER_EAVES - 0.06)), Vector((cx, DY0 - 0.14, ridge + 0.06)), 0.035,
                0.14, step=0.3, dent=0.002)
    ob.build()


def interior(M, C):
    """Offener Raum bis unters Dach: helle Verkleidung unter den Dachflächen (mit Löchern zu den Gauben), Sparren, Zangen quer
    durch den Raum, Firstbalken."""
    a = math.radians(PITCH)
    lin = Body("Dach innen", M["in_wood"], C["inside"], seed=700, vary=0.05)
    beams = Body("Balken", M["beam"], C["inside"], seed=701, vary=0.06, bevel=0.006)
    x0, x1 = -W / 2 + WALL_T, W / 2 - WALL_T
    for side in (-1, 1):
        y_wall = side * (D / 2 - WALL_T)
        lo = Vector((0, y_wall, roof_under(y_wall) - 0.005))
        hi = Vector((0, 0.0, roof_under(0.0) - 0.005))
        u = (hi - lo).normalized()
        nn = Vector((1, 0, 0)).cross(u) * (1 if side < 0 else -1)
        if nn.z > 0:
            nn = -nn
        length = (hi - lo).length
        m = Matrix(((1, u.x, nn.x, 0), (0, u.y, nn.y, lo.y), (0, u.z, nn.z, lo.z), (0, 0, 0, 1)))
        lin.box(((x0 + x1) / 2, length / 2, 0.01), (x1 - x0, length, 0.02), step=0.8, dent=0.0, matrix=m)
        # Sparren unter der Verkleidung (nicht vor den Gauben)
        x = x0 + 0.25
        while x < x1 - 0.2:
            if side > 0 or all(abs(x - cx) > DORMER_HW + 0.06 for cx in DORMER_X):
                beams.box((x, length / 2, 0.08), (0.07, length, 0.12), step=0.8, dent=0.002, matrix=m)
            x += 0.62
    lo_obj = lin.build()
    cutters = [SB.cutter((cx, (DY0 + 0.06 + DY1 + 0.1) / 2, 3.5), (2 * DORMER_HW - 0.12, DY1 + 0.1 - DY0 - 0.06, 3.0))
               for cx in DORMER_X]
    SB.boolean_cut(lo_obj, cutters)
    # Zangen quer durch den Raum (über Kopfhöhe) und Firstbalken
    for x in (-(W / 2 - 1.0), 0.0, W / 2 - 1.0):
        beams.box((x, 0.0, EAVES - 0.07), (0.1, D - 2 * WALL_T, 0.14), step=0.8, dent=0.002)
    beams.box((0.0, 0.0, roof_under(0.0) - 0.1), (W - 2 * WALL_T, 0.12, 0.16), step=0.8, dent=0.002)
    beams.build()


def colliders(C):
    """Kästen für die Kollision im Spiel: Wände (vorn mit Lücke für die Tür)."""
    side_door = (W / 2 - DOOR_W / 2 - 0.02)
    T_ = WALL_T
    return SC.colliders(C, {
        "Kollision Pfosten links": ((-PORCH_X, porch_front() + 0.06), (0.12, 0.12), PORCH_EAVES),
        "Kollision Pfosten rechts": ((PORCH_X, porch_front() + 0.06), (0.12, 0.12), PORCH_EAVES),
        "Kollision vorn links": ((-W / 2 + side_door / 2, -D / 2 + T_ / 2), (side_door, T_), EAVES),
        "Kollision vorn rechts": ((W / 2 - side_door / 2, -D / 2 + T_ / 2), (side_door, T_), EAVES),
        "Kollision hinten": ((0.0, D / 2 - T_ / 2), (W, T_), EAVES),
        "Kollision links": ((-W / 2 + T_ / 2, 0.0), (T_, D), EAVES),
        "Kollision rechts": ((W / 2 - T_ / 2, 0.0), (T_, D), EAVES),
    })


def build_scene():
    M, C = T.house_scene("Holzhäuschen", inside="Innenraum")
    mats(M)
    random.seed(5)
    walls(M, C)
    trims_and_windows(M, C)
    base_and_floor(M, C)
    porch_roof(M, C)
    roof(M, C)
    interior(M, C)
    cols = colliders(C)
    # Leere Knoten fürs Spiel: Mitte der Türöffnung (unten, außen); der Innenraum (Maße und Öffnungen, room_info)
    SC.game_spot("GameSpot_cottage_door", (0.0, -D / 2, FLOOR), width=DOOR_W, height=DOOR_H, wall=WALL_T, porch=PORCH_DEPTH,
                 porch_x=PORCH_X)
    SC.game_spot("GameSpot_cottage_room", (0.0, 0.0, FLOOR), room=json.dumps(room_info()))
    return M, C, cols


def room_info():
    """Innenraum fürs Spiel (Godot-Koordinaten des Modells: x, z = -Blender y): Innenflächen der Verkleidung (dort liegen die
    Wandfarben), Höhe bis zur Traufe, Fußboden, Öffnungen je Wand (Mitte x/z auf der Außenlinie, Unterkante über dem Boden,
    Breite, Höhe) – daraus baut scripts/world/alley.gd den Raum zum Einrichten (Room.home)."""
    inset = WALL_T + 0.02
    out = []
    for key, (p0, p1) in walls_list().items():
        for x, z0, w, h in openings().get(key, []):
            c = T.wall_matrix(p0, p1) @ Vector((x, 0.0, 0.0))
            out.append([key, round(c.x, 4), round(-c.y, 4), round(z0 - FLOOR, 4), w, h])
    return {"x0": -W / 2 + inset, "x1": W / 2 - inset, "z0": -(D / 2 - inset), "z1": D / 2 - inset, "floor": FLOOR,
            "height": EAVES - FLOOR, "openings": out}


VIEWS = {
    "haeuschen_vorn": ((3.6, -8.5, 2.6), (0.0, 0.0, 1.9), 30, (1200, 900)),
    "haeuschen_schraeg": ((-7.0, -5.5, 4.2), (0.0, 0.0, 1.8), 32, (1200, 900)),
    "haeuschen_hinten": ((5.5, 7.5, 3.5), (0.0, 0.0, 1.8), 32, (1200, 900)),
    "haeuschen_innen": ((0.4, 1.4, 1.5), (-0.2, -1.6, 2.4), 20, (1200, 900)),
}


if __name__ == "__main__":
    T.run(build_scene, BLEND, STAMP, GLB, VIEWS, "tools/blender/build_storybook_cottage.py")
