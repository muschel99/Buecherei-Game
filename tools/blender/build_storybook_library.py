"""Die Bücherei von außen im Bilderbuch-Stil (Stil-Umbau der Welt, Etappe 4h): grüne Holz-
Ladenfront mit Pilastern, Feldern und Goldkanten im Erdgeschoss, Schildkästen mit den Bildern
der Entwicklerin (library_fascia.png über den Fenstern, library_door.png über der Tür), darüber
ein Obergeschoss aus warmen braunen Ziegeln mit Ecksteinen, Rundbogenfenstern, Blumenkästen und
Zahnschnitt-Gesims, Walmdach aus Ziegelreihen mit Schornstein, Sockel aus Feldsteinen,
Wandlaternen mit dem gemeinsamen Laternenkopf und zwei Blumenampeln an der Schräge.

Alles umhüllt das Haus nur von außen: Die Wände, Fenster und die Tür des Ladens (Raum-Szene,
CSG, Fenster-Szenen) bleiben, wie sie sind; die Öffnungen sind ausgespart, der Einwurf des
Rückgabekastens neben der Tür bleibt frei. UpperFloors (main.tscn) baut keine eigene Hülle mehr
(build_visuals = false), nur die leeren Geschoss-Knoten.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_library.py [-- --render [--quick]] [--force]
Ergebnis: assets/models/world/library_facade.glb (Knoten "Facade" im Raum, Raumkoordinaten:
Ladenboden y = 0, Gehweg 0,5 m tiefer) und assets/models/source/library_storybook.blend.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_houses as SH  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "library_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "library_storybook.stamp")
GAME_GLB = os.path.join(SC.ROOT, "assets", "models", "world", "library_facade.glb")

# Grundriss außen (Blender: x = Godot x, y = -Godot z), gegen den Uhrzeigersinn: hinten, rechts
# (Nachbar), vorn (zur Straße), Schräge (Tür), links (zur Gasse)
OUT = [(-3.2, -4.2), (3.2, -4.2), (3.2, 4.2), (-1.0828, 4.2), (-3.2, 2.0828)]
BACK, RIGHT, FRONT, DIAG, LEFT = (T.seg(OUT, i) for i in range(5))
GROUND = -0.5
FASCIA = (2.78, 3.3)
TOP = 3.42                 # Oberkante Ladengesims = Fußboden Obergeschoss
E = 6.42                   # Traufe
RISE, RUN = 1.6, 2.2
WIN = dict(w=2.4, z=0.3, h=2.3)          # Schaufenster (CSG-Loch des Raums)
FRONT_WIN_X = 2.2                         # Mitte entlang FRONT (Godot x = 1,0)
LEFT_WIN_X = 3.0828                       # Mitte entlang LEFT (Godot z = 1,0)
DOOR = dict(w=1.4, h=2.6)
DIAG_LEN = T.seg_len(*DIAG)
SLOT = (2.25, 2.86)                       # Einwurf des Rückgabekastens entlang DIAG (frei lassen)
SETTLE = {"wave": 0.012, "wavelength": 3.0, "lean": 0.0, "roof_sag": 0.04, "ridge_tilt": 0.0, "eaves_sag": 0.015}


def mats(M):
    mk = SC.make_material
    M["green"] = mk("Lack Bücherei Grün", (0.13, 0.25, 0.18), grain="paint", rough=0.7, vary=0.06, bump=0.12)
    M["green_dark"] = mk("Lack Bücherei Grün dunkel", (0.09, 0.18, 0.13), grain="paint", rough=0.7, vary=0.05, bump=0.12)
    M["h_wall"] = mk("Ziegel Braun", (0.6, 0.38, 0.27), grain="brick", rough=0.92, vary=0.07, bump=0.28, color2=(0.57, 0.5, 0.42))
    M["h_join"] = mk("Lack Creme", (0.9, 0.86, 0.76), grain="paint", rough=0.72, vary=0.06, bump=0.12)
    M["h_join_dark"] = M["green_dark"]
    M["h_box"] = M["green"]
    M["h_roof"] = mk("Dachziegel Ton", (0.75, 0.42, 0.28), grain="stone", rough=0.9, vary=0.08, bump=0.2)
    M["h_roof_cap"] = mk("Dachziegel Ton First", (0.65, 0.36, 0.25), grain="stone", rough=0.9, vary=0.06, bump=0.2)
    M["h_room"] = mk("Zimmer warm 1", SH.ROOMS[0], glow=0.3, rough=0.95, vary=0.05, bump=0.05)


def shopfront_side(M, C, seg, win_x, sign, lantern_x=None):
    """Erdgeschoss einer Ladenseite (vorn oder links): Pilaster, Felder, Fensterrahmen, Schildkasten
    über die ganze Länge mit dem Schild über dem Fenster, Gesims."""
    p0, p1 = seg
    L = T.seg_len(p0, p1)
    fm = T.wall_matrix(p0, p1)
    g = Body("Ladenfront Holz", M["green"], C["shop"], seed=20, vary=0.04, bevel=0.012)

    def gb(c, s):
        g.box(c, s, step=0.6, dent=0.003, matrix=fm)
    x0, x1 = win_x - WIN["w"] / 2, win_x + WIN["w"] / 2
    # Fensterrahmen (dick, um die Öffnung herum) und Brüstung mit zwei Feldern
    gb((win_x, WIN["z"] - 0.05, 0.05), (WIN["w"] + 0.2, 0.1, 0.1))
    gb((win_x, WIN["z"] + WIN["h"] + 0.05, 0.05), (WIN["w"] + 0.2, 0.1, 0.1))
    for xx in (x0 - 0.05, x1 + 0.05):
        gb((xx, WIN["z"] + WIN["h"] / 2, 0.05), (0.1, WIN["h"] + 0.2, 0.1))
    gb((win_x, (GROUND + WIN["z"] - 0.1) / 2, 0.03), (WIN["w"] + 0.2, WIN["z"] - 0.1 - GROUND, 0.06))
    gb((win_x, WIN["z"] - 0.13, 0.11), (WIN["w"] + 0.34, 0.06, 0.2))
    for k in range(2):
        cx = x0 + WIN["w"] * (k + 0.5) / 2
        gb((cx, (GROUND + 0.12 + WIN["z"] - 0.22) / 2, 0.075), (WIN["w"] / 2 - 0.24, WIN["z"] - 0.34 - GROUND, 0.03))
    # Felder neben dem Fenster (Vertäfelung) bis unter den Schildkasten
    for a, b in ((0.0, x0 - 0.1), (x1 + 0.1, L)):
        if b - a > 0.15:
            gb(((a + b) / 2, (GROUND + FASCIA[0]) / 2, 0.03), (b - a, FASCIA[0] - GROUND, 0.06))
            n = max(1, round((FASCIA[0] - GROUND - 0.4) / 1.0))
            for j in range(n):
                y0 = GROUND + 0.35 + (FASCIA[0] - GROUND - 0.55) * j / n
                y1 = GROUND + 0.35 + (FASCIA[0] - GROUND - 0.55) * (j + 1) / n - 0.1
                if b - a > 0.5:
                    gb(((a + b) / 2, (y0 + y1) / 2, 0.075), (b - a - 0.36, y1 - y0, 0.03))
    # Pilaster: an den Enden und neben dem Fenster
    for xx in (0.16, x0 - 0.16, x1 + 0.16, L - 0.16):
        if 0.1 < xx < L - 0.1:
            gb((xx, (GROUND + FASCIA[0]) / 2, 0.08), (0.3, FASCIA[0] - GROUND, 0.16))
            gb((xx, GROUND + 0.2, 0.1), (0.36, 0.4, 0.2))
            gb((xx, FASCIA[0] - 0.12, 0.12), (0.36, 0.24, 0.24))
    g.build()
    # Goldene Kapitell-Rollen
    au = Body("Ladenfront Gold", M["gold"], C["shop"], seed=21, vary=0.04)
    for xx in (0.16, x0 - 0.16, x1 + 0.16, L - 0.16):
        if 0.1 < xx < L - 0.1:
            au.tube([fm @ Vector((xx - 0.17, FASCIA[0] - 0.06, 0.25)), fm @ Vector((xx + 0.17, FASCIA[0] - 0.06, 0.25))], 0.04, segs=10,
                    round_ends=True)
    au.build()
    signs = [(win_x - L / 2, 3.6, SC.sign_material("library", sign), 2048 / 296)] if sign else []
    T.fascia(M, C, "Schildkasten %s" % sign, T.wall_matrix(p0, p1, L / 2), L + 0.04, FASCIA[0], FASCIA[1] - FASCIA[0], "green",
             signs=signs, depth=0.22)
    if lantern_x is not None:
        T.placed(C["deco"], T.canon(p0, p1, lantern_x, 0.0, 0.06), T.wall_lantern, M, C, "Wandlaterne %s" % sign, 0.0, 2.55, seed=130)


def diagonal(M, C):
    """Schräge mit der Tür: Pilaster neben der Tür, Holzfelder links, rechts nur ein schmaler Pilaster
    am Ende (der Einwurf des Rückgabekastens bleibt frei), Schildkasten mit dem Türschild, zwei
    Blumenampeln an den Ecken."""
    p0, p1 = DIAG
    L = DIAG_LEN
    fm = T.wall_matrix(p0, p1)
    g = Body("Türfront Holz", M["green"], C["shop"], seed=24, vary=0.04, bevel=0.012)

    def gb(c, s):
        g.box(c, s, step=0.6, dent=0.003, matrix=fm)
    dc = L / 2
    d0, d1 = dc - DOOR["w"] / 2, dc + DOOR["w"] / 2
    # schmaler Türrahmen (rechts sitzt der Rückgabekasten nur 13 cm neben der Tür)
    for xx in (d0 - 0.06, d1 + 0.06):
        gb((xx, (GROUND + DOOR["h"] + 0.1) / 2, 0.07), (0.12, DOOR["h"] + 0.1 - GROUND, 0.14))
    gb((dc, DOOR["h"] + 0.07, 0.07), (DOOR["w"] + 0.24, 0.14, 0.14))
    gb((dc, (DOOR["h"] + 0.14 + FASCIA[0]) / 2, 0.03), (DOOR["w"] + 0.24, FASCIA[0] - DOOR["h"] - 0.14, 0.06))
    # links neben der Tür: Feld
    a, b = 0.0, d0 - 0.12
    if b - a > 0.12:
        gb(((a + b) / 2, (GROUND + FASCIA[0]) / 2, 0.03), (b - a, FASCIA[0] - GROUND, 0.06))
    # rechts: Felder über und unter dem Einwurf, Pilaster am Ende
    a, b = d1 + 0.12, L
    if b - a > 0.1:
        gb(((a + b) / 2, (GROUND + 0.55) / 2, 0.03), (b - a, 0.55 - GROUND, 0.06))
        gb(((a + b) / 2, (1.35 + FASCIA[0]) / 2, 0.03), (b - a, FASCIA[0] - 1.35, 0.06))
    g.build()
    T.fascia(M, C, "Schildkasten Tür", T.wall_matrix(p0, p1, L / 2), L + 0.04, FASCIA[0], FASCIA[1] - FASCIA[0], "green",
             signs=[(0.0, 2.6, SC.sign_material("library", "door"), 1536 / 267)], depth=0.22)
    for side, x in ((-1, 0.18), (1, L - 0.18)):
        T.placed(C["deco"], T.canon(p0, p1, x, 0.0, 0.0), T.hanging_basket, M, C, "Blumenampel %s" % ("links" if side < 0 else "rechts"),
                 0.0, TOP + 0.05, reach=0.5, drop=0.38, radius=0.16, seed=80 + side)


def plinth(M, C, rnd):
    """Sockel aus Feldsteinen unter dem Laden (Gehweg bis Ladenboden), nicht unter der Tür."""
    p = Body("Sockelsteine", M["stone"], C["walls"], seed=8, vary=0.13, bevel=0.03)
    # nur hinten (Hof): vorn, links und an der Schräge reicht die grüne Holzfront bis zum Gehweg
    for i, seg in ((0, BACK),):
        p0, p1 = seg
        L = T.seg_len(p0, p1)
        fm = T.wall_matrix(p0, p1)
        spans = [(0.0, L)]
        if i == 3:
            spans = [(0.0, L / 2 - DOOR["w"] / 2 - 0.02), (L / 2 + DOOR["w"] / 2 + 0.02, L)]
        for a, b in spans:
            for row, (z0, z1) in enumerate(((GROUND, GROUND + 0.25), (GROUND + 0.25, 0.0))):
                x = a + (0.13 if row else 0.0)
                while x < b - 0.06:
                    wdt = min(rnd.uniform(0.3, 0.5), b - x)
                    if wdt > 0.08:
                        p.box((x + wdt / 2, (z0 + z1) / 2, 0.03 + rnd.uniform(-0.01, 0.01)), (wdt - 0.025, z1 - z0 - 0.022, 0.12), step=1,
                              dent=0.012, turn=(rnd.uniform(-1.5, 1.5), rnd.uniform(-1.5, 1.5), 0), matrix=fm)
                    x += wdt
    p.build()


def back_skin(M, C):
    """Rückseite des Ladens (zum Hof): Ziegel-Haut auf der Wand, damit alles zusammenpasst."""
    b = Body("Rückwand Ziegel", M["h_wall"], C["walls"], seed=30, vary=0.03)
    T.wall_run(b, *BACK, 0.0, TOP, thick=0.04, inset=-0.04, step=0.6)
    b.build()


def upper(M, C, rnd):
    """Obergeschoss: Ziegelwände rundherum (rechts Brandwand), Fenster wie bisher verteilt (Schräge 1,
    vorn 2, links 3), Ecksteine, Gurtgesims, Traufgesims mit Zahnschnitt, Räume hinter den Fenstern."""
    w = Body("Obergeschoss Ziegel", M["h_wall"], C["walls"], seed=31, vary=0.03)
    T.outline_walls(w, OUT, range(5), TOP - 0.02, E + 0.2, thick=0.3, step=0.5)
    wall = w.build()
    wins = []
    for i, seg in ((3, DIAG), (2, FRONT), (4, LEFT)):
        L = T.seg_len(*seg)
        n = max(1, int(L / 2.0))
        for k in range(n):
            wins.append((seg, L * (k + 0.5) / n))
    win_w, win_h, z0 = 0.95, 1.45, TOP + 0.85
    rise = win_w * 0.32
    SB.boolean_cut(wall, [SH.cutter_for(T.wall_matrix(*seg, x, z0), win_w, win_h, rise) for seg, x in wins])
    SC.add_bevel(wall, 0.02)
    for k, (seg, x) in enumerate(wins):
        fm = T.wall_matrix(*seg, x, z0, 0.0, rnd.uniform(-1, 1))
        name = "Fenster oben %d" % (k + 1)
        SH.window(M, C, name, fm, win_w, win_h, rise, panes=(2, 3), curtains=True, seed=200 + k)
        SH.surround(M, C, name, fm, win_w, win_h, rise, "brick", seed=210 + k)
        SC.planter_box(M, C["pots"], name + " Blumenkasten", fm @ Matrix.Translation((0, -0.06, 0.1)), win_w + 0.18, 0.2, 0.2, seed=220 + k,
                       gap=0.1, mat="green")
        kb = Body(name + " Konsolen", M["lamp_iron"], C["pots"], seed=230 + k, bevel=0.003)
        for sx in (-win_w / 2 + 0.06, win_w / 2 - 0.06):
            kb.tube([fm @ Vector((sx, -0.36, 0.04)), fm @ Vector((sx, -0.07, 0.4)), fm @ Vector((sx, -0.07, 0.04))], 0.009, segs=6,
                    round_ends=True)
        kb.build()
        c = fm @ Vector((0, 0.175, 0.2))
        nrm = fm.to_3x3() @ Vector((0, 0, 1))
        SH.plant_spot(C, "box", tuple(c), (win_w + 0.12, 0.15, 0.4), len(C["plants"].objects), math.degrees(math.atan2(nrm.x, -nrm.y)))
        # warmer Raum dahinter
        rm = Body(name + " Raum", M["h_room"], C["inside"], seed=240 + k, vary=0.04)
        rm.box((0, 1.35, -1.5), (2.2, 2.9, 0.08), step=1, dent=0.0, matrix=fm)
        rm.box((0, -0.8, -0.9), (2.2, 0.08, 1.3), step=1, dent=0.0, matrix=fm)
        rm.box((0, 2.75, -0.9), (2.2, 0.08, 1.3), step=1, dent=0.0, matrix=fm)
        for sx in (-1.1, 1.1):
            rm.box((sx, 1.0, -0.9), (0.08, 3.6, 1.3), step=1, dent=0.0, matrix=fm)
        rm.build()
    q = Body("Ecksteine", M["stone"], C["walls"], seed=32, vary=0.1, bevel=0.014)
    for k in (2, 3, 4, 0):
        # an jeder sichtbaren Ecke (nicht an der Brandwand rechts)
        prev, nxt = T.seg(OUT, k - 1), T.seg(OUT, k)
        z, j = TOP + 0.15, 0
        while z + 0.3 < E - 0.4:
            wdt = 0.4 if j % 2 == 0 else 0.26
            if k - 1 != 1:
                q.box((T.seg_len(*prev) - wdt / 2 + 0.005, z + 0.14, 0.025), (wdt, 0.27, 0.06), step=0.6, dent=0.004,
                      matrix=T.wall_matrix(*prev))
            if k != 1:
                q.box((wdt / 2 - 0.005, z + 0.14, 0.025), (wdt, 0.27, 0.06), step=0.6, dent=0.004, matrix=T.wall_matrix(*nxt))
            z += 0.3
            j += 1
    q.build()
    c = Body("Gesimse oben", M["trim"], C["walls"], seed=33, vary=0.05, bevel=0.012)
    T.band(c, OUT, (0, 2, 3, 4), TOP + 0.02, 0.12, -0.02, 0.1)
    T.band(c, OUT, (0, 2, 3, 4), E - 0.32, 0.12, -0.02, 0.1)
    T.band(c, OUT, (0, 2, 3, 4), E - 0.08, 0.1, -0.02, 0.3)
    c.build()
    d = Body("Zahnschnitt", M["trim"], C["walls"], seed=34, vary=0.06, bevel=0.008)
    for i in (2, 3, 4):
        p0, p1 = T.seg(OUT, i)
        L = T.seg_len(p0, p1)
        fm = T.wall_matrix(p0, p1)
        x = 0.12
        while x < L - 0.1:
            d.box((x, E - 0.15, 0.09), (0.08, 0.1, 0.18), step=1, dent=0.002, turn=(0, 0, rnd.uniform(-2, 2)), matrix=fm)
            x += 0.2
    d.build()
    T.floor_slab(M, C, "Obergeschoss Decke", "h_room", OUT, 0.29, E - 0.3, 0.08)


def roof(M, C):
    T.cozy_hip_roof(M, C, "Dach", OUT, [True, False, True, True, True], E, RISE, RUN, 0.34, "h_roof", cap_mat="h_roof_cap",
                    simple=(0,), seed=40)
    T.chimney(M, C, "Schornstein", (1.6, -2.6, E + RISE - 0.4), (0.7, 0.8), E + RISE + 0.95, "pub_brick", pots=2, seed=41)
    r = Body("Dachrinne", M["bronze"], C["roof"], seed=42)
    off = T.offset_polygon(OUT, [-0.42 if i != 1 else 0.0 for i in range(5)])
    for i in (2, 3, 4):
        a, b = off[i].to_3d(), off[(i + 1) % 5].to_3d()
        a.z = b.z = E + 0.02
        r.tube([a, b], 0.055, segs=10, round_ends=True)
    m = T.canon(*LEFT, T.seg_len(*LEFT) - 0.15, 0.0, 0.0)
    r.tube([m @ Vector((0, 0.42, E)), m @ Vector((0, 0.16, E - 0.35)), m @ Vector((0, 0.09, E - 0.7)), m @ Vector((0, 0.09, GROUND + 0.15)),
            m @ Vector((0, 0.18, GROUND + 0.03))], 0.034, segs=10, smooth=2, round_ends=True)
    r.build()


def build_scene():
    rnd = random.Random(1924)
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    mats(M)
    root = SB.collection("Bücherei (Bilderbuch)")
    C = {k: SB.collection(v, root) for k, v in (("walls", "Mauern"), ("roof", "Dach"), ("windows", "Fenster"), ("shop", "Ladenfront"),
                                                ("inside", "Räume oben"), ("pots", "Kästen"), ("deco", "Deko"), ("plants", "Pflanzplätze"),
                                                ("light", "Licht"))}
    C["env"] = SB.collection("Umgebung (nur Vorschau)")
    C["collision"] = SB.collection("Kollision (Spiel)", root)
    shopfront_side(M, C, FRONT, FRONT_WIN_X, "fascia", lantern_x=3.75)
    shopfront_side(M, C, LEFT, LEFT_WIN_X, "fascia", lantern_x=5.33)
    diagonal(M, C)
    plinth(M, C, rnd)
    back_skin(M, C)
    upper(M, C, rnd)
    roof(M, C)
    # Pflanzplatz für den Kübel an der Gassenwand (wie bisher bei Godot z = 3,7)
    pm = T.canon(*LEFT, 5.78, GROUND, 0.32)
    SH.plant_spot(C, "pot", tuple(pm @ Vector((0, 0, 0))), (0.5, 0.5, 1.0), len(C["plants"].objects), -90.0)
    objs = [o for k, c in C.items() if k not in ("env", "collision", "plants") for o in c.objects]
    SC.settle(objs, SETTLE, 3.2, E, E + RISE)
    return M, C


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("Die .blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    M, C = build_scene()
    objs = [o for k, c in C.items() if k not in ("env", "collision", "plants", "light") for o in c.objects if o.type == "MESH"]
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    print("Offene Kanten: %s" % (bad if bad else "keine – alles geschlossene Körper"))
    # Raumkoordinaten von Godot: Blender (x, y, z) = Godot (x, -z, y) – glTF dreht das beim Export
    tris, n = SC.export_objects(objs, [], GAME_GLB, palette=True, extra=list(C["plants"].objects))
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, GAME_GLB)
    print("Spiel: %s (%d Dreiecke, %d Netze)" % (GAME_GLB, tris, n))
    if "--render" in argv:
        SC.setup_render("--quick" in argv)
        SC.render("bibliothek_vorn", (0.8, 11.5, 1.2), (0.8, 4.2, 3.2), 30, (1300, 1100))
        SC.render("bibliothek_ecke", (-7.5, 9.0, 1.4), (-1.8, 2.5, 3.0), 30, (1300, 1100))
        SC.render("bibliothek_gasse", (-9.5, -1.0, 1.2), (-3.2, -0.5, 3.0), 30, (1300, 1100))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
