"""Die beiden Gassen im Bilderbuch-Stil (Stil-Umbau der Welt, Etappe 4h) – ersetzt build_alleys.py.

Aufruf (Terminal, im Projektordner):
    godot --headless --path . res://scenes/tools/export_layout.tscn      (Lage aus dem Spiel, falls geändert)
    blender -b --factory-startup --python tools/blender/build_storybook_alleys.py [-- --render [--quick]] [--force]

Ergebnis (Koordinaten wie unter "Outside" im Spiel, y = 0 = Gehweg; Blender: x, -z, y):
    assets/models/world/alley_library.glb   Gasse neben der Bücherei: Rückwände der Häuser (Ziegel,
                                            Putz) mit Fenstern, Feldsteinsockeln und Dachansätzen aus
                                            Ziegelreihen, Hofmauern, am Ende ein kleiner Garten mit
                                            runder Holzbank um den Baum, Lattenzaun, dahinter Giebel-
                                            häuser
    assets/models/world/alley_opposite.glb  kleine Gasse gegenüber: Mauern aus warmem Sandstein,
                                            drei Steinbögen, hinten eine Wand mit Tür und Laterne
    assets/models/source/alleys_storybook.blend
Pflanzen (Baum, Hecke, Beete, Efeu, Töpfe) kommen als austauschbare Szenen auf die Pflanzplätze
„PlantSpot_…“. Kollision der Wände baut das Spiel (Alley, OppositeAlley); Bank und Baumstamm
bringen eigene Kollisionen mit („-colonly“).
"""

import json
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_greenery as GR  # noqa: E402
import storybook_houses as SH  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

LAYOUT = json.load(open(os.path.join(SC.ROOT, "assets", "models", "source", "layout.json")))
OUT = os.path.join(SC.ROOT, "assets", "models", "world")
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "alleys_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "alleys_storybook.stamp")


def G(x, z):
    """Godot (x, z) unter Outside → Blender (x, y)."""
    return (x, -z)


def mats(M):
    mk = SC.make_material
    M["brick_a"] = mk("Ziegel Braun", (0.6, 0.38, 0.27), grain="brick", rough=0.92, vary=0.07, bump=0.28, color2=(0.57, 0.5, 0.42))
    M["brick_b"] = mk("Ziegel Dunkel", (0.52, 0.33, 0.26), grain="brick", rough=0.92, vary=0.07, bump=0.28, color2=(0.57, 0.5, 0.42))
    M["brick_c"] = mk("Ziegel Honig", (0.72, 0.52, 0.36), grain="brick", rough=0.92, vary=0.07, bump=0.28, color2=(0.57, 0.5, 0.42))
    M["plaster_a"] = mk("Putz Creme", (0.93, 0.86, 0.72), grain="plaster", rough=0.92, vary=0.07, scale=1.6, bump=0.32)
    M["plaster_b"] = mk("Putz Pfirsich", (0.94, 0.79, 0.65), grain="plaster", rough=0.92, vary=0.07, scale=1.6, bump=0.32)
    M["sandstone"] = mk("Quader Warm", (0.86, 0.76, 0.6), grain="ashlar", rough=0.9, vary=0.07, bump=0.3, color2=(0.62, 0.56, 0.47))
    M["h_join"] = mk("Holz Eiche", (0.5, 0.32, 0.19), grain="wood", rough=0.78, vary=0.07, bump=0.2)
    M["h_join_dark"] = mk("Holz Nuss", (0.37, 0.24, 0.15), grain="wood", rough=0.78, vary=0.07, bump=0.2)
    M["h_door"] = mk("Holz Tür Eiche", (0.46, 0.3, 0.18), grain="wood", rough=0.78, vary=0.1, bump=0.25)
    M["h_roof"] = mk("Dachziegel Ton", (0.75, 0.42, 0.28), grain="stone", rough=0.9, vary=0.08, bump=0.2)
    M["h_roof_cap"] = mk("Dachziegel Ton First", (0.65, 0.36, 0.25), grain="stone", rough=0.9, vary=0.06, bump=0.2)
    M["slate_roof"] = mk("Dachziegel Schiefer", (0.38, 0.38, 0.41), grain="stone", rough=0.9, vary=0.08, bump=0.2)
    M["h_room"] = mk("Zimmer warm 2", SH.ROOMS[1], glow=0.3, rough=0.95, vary=0.05, bump=0.05)
    M["fence"] = mk("Lack Zaun Creme", (0.88, 0.84, 0.74), grain="paint", rough=0.75, vary=0.08, bump=0.12)
    M["lawn"] = mk("Rasen", (0.4, 0.52, 0.26), grain="leaf", rough=0.85, vary=0.12, bump=0.3)
    M["cushion_a"] = mk("Kissen Creme", (0.88, 0.84, 0.74), grain="fabric", rough=0.95, vary=0.04, bump=0.15)
    M["cushion_b"] = mk("Kissen Salbei", (0.5, 0.58, 0.46), grain="fabric", rough=0.95, vary=0.04, bump=0.15)


def back_wall(M, C, name, p0, p1, h, wall, rnd, kind="brick", windows=True, roof=True, pipe=True, roof_mat="h_roof"):
    """Rückwand eines Hauses p0 → p1 (Vorderseite rechts der Laufrichtung, in die Gasse): Fenster mit
    Rahmen, Vorhängen und warmem Raum dahinter, Feldsteinsockel, Traufe mit Dachansatz aus
    Ziegelreihen, Fallrohr. Liefert die Fenster (x, z0, w, h) entlang der Wand."""
    L = T.seg_len(p0, p1)
    body = Body(name, M[wall], C["walls"], seed=rnd.randrange(999), vary=0.03)
    T.wall_run(body, p0, p1, 0.0, h + (0.15 if roof else 0.0), thick=0.3, step=0.6)
    wobj = body.build()
    wins = []
    if windows:
        x = rnd.uniform(0.9, 1.4)
        while x < L - 0.9:
            for z0 in ((0.9, 3.9) if h > 5 else (0.9,)):
                if rnd.random() < 0.7:
                    wins.append((x, z0, 0.8, 1.25))
            x += rnd.uniform(2.2, 3.1)
    rise = 0.1 if kind != "plaster" else 0.24
    if wins:
        SB.boolean_cut(wobj, [SH.cutter_for(T.wall_matrix(p0, p1, x, z0), w, hh, rise) for x, z0, w, hh in wins])
    SC.add_bevel(wobj, 0.02)
    for k, (x, z0, w, hh) in enumerate(wins):
        fm = T.wall_matrix(p0, p1, x, z0, 0.0, rnd.uniform(-1, 1))
        n = "%s Fenster %d" % (name, k + 1)
        SH.window(M, C, n, fm, w, hh, rise, panes=(2, 2), curtains=True, seed=rnd.randrange(999))
        SH.surround(M, C, n, fm, w, hh, rise, kind, seed=rnd.randrange(999))
        rm = Body(n + " Raum", M["h_room"], C["inside"], seed=rnd.randrange(999), vary=0.05)
        rm.box((0, 0.6, -1.3), (1.8, 1.9, 0.08), step=1, dent=0.0, matrix=fm)
        for sx in (-0.9, 0.9):
            rm.box((sx, 0.6, -0.8), (0.08, 1.9, 1.0), step=1, dent=0.0, matrix=fm)
        rm.box((0, -0.32, -0.8), (1.8, 0.08, 1.0), step=1, dent=0.0, matrix=fm)
        rm.box((0, 1.52, -0.8), (1.8, 0.08, 1.0), step=1, dent=0.0, matrix=fm)
        rm.build()
    fm0 = T.wall_matrix(p0, p1)
    st = Body(name + " Sockel", M["stone"], C["walls"], seed=rnd.randrange(999), vary=0.13, bevel=0.025)
    for row, (z0, z1) in enumerate(((0.0, 0.2), (0.2, 0.38))):
        x = 0.12 if row else 0.0
        while x < L - 0.06:
            w = min(rnd.uniform(0.3, 0.5), L - x)
            if w > 0.08:
                st.box((x + w / 2, (z0 + z1) / 2, 0.035), (w - 0.022, z1 - z0 - 0.02, 0.12), step=1, dent=0.01,
                       turn=(rnd.uniform(-1.5, 1.5), 0, rnd.uniform(-1.5, 1.5)), matrix=fm0)
            x += w
    st.build()
    if roof:
        tr = Body(name + " Traufe", M["h_join_dark"], C["roof"], seed=rnd.randrange(999), vary=0.05, bevel=0.01)
        tr.box((L / 2, h - 0.03, 0.16), (L, 0.06, 0.32), step=0.6, dent=0.003, matrix=fm0)
        tr.box((L / 2, h - 0.04, 0.31), (L, 0.2, 0.05), step=0.6, dent=0.003, matrix=fm0)
        tr.build()
        tiles = Body(name + " Dachansatz", M[roof_mat], C["roof"], seed=rnd.randrange(999), vary=0.0)
        rise_r, back_r = 2.0, 2.0
        b0, b1 = fm0 @ Vector((0.0, h, 0.34)), fm0 @ Vector((L, h, 0.34))
        t0, t1 = fm0 @ Vector((0.0, h + rise_r, -back_r)), fm0 @ Vector((L, h + rise_r, -back_r))
        frame = T.tile_rows(tiles, b0, b1, t0, t1, rnd, simple=False)
        tiles.build()
        slope = (t0 - b0).length
        core = Body(name + " Dachfläche", M[roof_mat], C["roof"], seed=rnd.randrange(999), vary=0.04)
        core.box((0, 0, 0), (L, slope + 0.02, 0.16), step=0.6, dent=0.004, matrix=frame @ Matrix.Translation((L / 2, slope / 2, -0.09)))
        core.build()
        cap = Body(name + " First", M["h_roof_cap"], C["roof"], seed=rnd.randrange(999), vary=0.05)
        cap.tube([fm0 @ Vector((0.0, h + rise_r + 0.04, -back_r)), fm0 @ Vector((L, h + rise_r + 0.04, -back_r))], 0.08, segs=10,
                 round_ends=True)
        cap.build()
        g = Body(name + " Rinne", M["bronze"], C["roof"], seed=rnd.randrange(999))
        g.tube([fm0 @ Vector((0.0, h - 0.02, 0.4)), fm0 @ Vector((L, h - 0.02, 0.4))], 0.05, segs=10, round_ends=True)
        if pipe:
            free = [x for x in [0.4 + 0.1 * k for k in range(int((L - 0.8) / 0.1))] if all(abs(x - wx) > w / 2 + 0.3 for wx, _, w, _ in wins)]
            if free:
                px = rnd.choice(free)
                g.tube([fm0 @ Vector((px, h - 0.02, 0.4)), fm0 @ Vector((px, h - 0.35, 0.12)), fm0 @ Vector((px, h - 0.7, 0.08)),
                        fm0 @ Vector((px, 0.15, 0.08)), fm0 @ Vector((px, 0.03, 0.16))], 0.033, segs=10, smooth=2, round_ends=True)
        g.build()
    return wins


def gable_house(M, C, name, x0, x1, z_face, h, wall, rnd, roof_mat="h_roof"):
    """Kulissenhaus hinter dem Garten: Wand zur Gasse (zeigt nach -z Godot), Giebel und Satteldach
    (First von der Gasse weg)."""
    p0, p1 = G(x1, z_face), G(x0, z_face)
    back_wall(M, C, name, p0, p1, h, wall, rnd, kind="plaster" if wall.startswith("plaster") else "brick", roof=False, pipe=False)
    W = x1 - x0
    fm = T.wall_matrix(p0, p1)
    span = W / 2 + 0.2
    pitch = 48.0
    ridge = h + span * math.tan(math.radians(pitch))
    g = Body(name + " Giebel", M[wall], C["walls"], seed=rnd.randrange(999), vary=0.04)
    g.slab([(0.0, h - 0.05), (W, h - 0.05), (W / 2, ridge - 0.14)], 0.3, fm @ Matrix.Translation((0, 0, -0.3)), dent=0.004)
    g.build()
    yb = -z_face
    frame = Matrix(((0, 1, 0, (x0 + x1) / 2), (-1, 0, 0, yb - 2.0 + 0.3), (0, 0, 1, 0), (0, 0, 0, 1)))
    T.cozy_roof(M, C, name + " Dach", frame, 4.6, span, h, pitch, roof_mat, cap_mat="h_roof_cap", ends=(0.0, 0.0), seed=rnd.randrange(999),
                back_simple=False, verge=True, front_simple=True)


def round_bench(M, C, x, z, rnd):
    """Runde Holzbank um den Baumstamm: Sitzring aus Latten (jede Latte ein Körper), Lehne aus
    senkrechten Latten mit Ring obenauf, Beine, zwei Kissen; daneben ein Hocker mit Tasse und Buch."""
    cx, cy = G(x, z)
    r_in, r_out, seat = 0.42, 0.95, 0.45
    wd = Body("Bank Holz", M["h_join"], C["deco"], seed=301, vary=0.1, bevel=0.008)
    n = 26
    for k in range(n):
        a0 = 2 * math.pi * k / n
        a1 = 2 * math.pi * (k + 0.82) / n
        pts = [(cx + r_in * math.cos(a0), cy + r_in * math.sin(a0)), (cx + r_out * math.cos(a0), cy + r_out * math.sin(a0)),
               (cx + r_out * math.cos(a1), cy + r_out * math.sin(a1)), (cx + r_in * math.cos(a1), cy + r_in * math.sin(a1))]
        # gegen den Uhrzeigersinn (von oben): innen-a0, außen-a0, außen-a1, innen-a1
        wd.slab(pts, 0.04, Matrix.Translation((0, 0, seat - 0.04)), dent=0.002)
        am = (a0 + a1) / 2
        bx, by = cx + (r_in + 0.03) * math.cos(am), cy + (r_in + 0.03) * math.sin(am)
        wd.box((bx, by, seat + 0.23), (0.07, 0.03, 0.44), step=1, dent=0.002, turn=(0, 0, math.degrees(am) + 90))
    ring = [Vector((cx + (r_in + 0.03) * math.cos(a), cy + (r_in + 0.03) * math.sin(a), seat + 0.46)) for a in
            [2 * math.pi * k / 24 for k in range(24)]]
    T.loop_tube(wd, ring, 0.028, segs=6)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        for r in (r_in + 0.06, r_out - 0.07):
            wd.box((cx + r * math.cos(a), cy + r * math.sin(a), (seat - 0.04) / 2), (0.06, 0.06, seat - 0.04), step=1, dent=0.002)
    sx, sy = cx + 1.35 * math.cos(-0.7), cy + 1.35 * math.sin(-0.7)
    wd.box((sx, sy, 0.4), (0.44, 0.32, 0.04), step=1, dent=0.002)
    for dx in (-0.18, 0.18):
        for dy in (-0.12, 0.12):
            wd.box((sx + dx, sy + dy, 0.19), (0.04, 0.04, 0.38), step=1, dent=0.002)
    wd.build()
    for k, (a, key) in enumerate(((-0.4, "cushion_a"), (-1.0, "cushion_b"))):
        c = Body("Kissen %d" % (k + 1), M[key], C["deco"], seed=310 + k, vary=0.04)
        px, py = cx + 0.66 * math.cos(a), cy + 0.66 * math.sin(a)
        c.blob((px, py, seat + 0.18), 0.2, subdiv=2, lump=0.04, scale=(1.0, 0.36, 0.9))
        c.build()
    cup = Body("Tasse", M["china"], C["deco"], seed=320)
    cup.lathe([(0.0, 0.0), (0.035, 0.0), (0.042, 0.08), (0.038, 0.085), (0.032, 0.012), (0.0, 0.012)], (sx - 0.08, sy, 0.42), segs=14)
    cup.build()
    bk = Body("Buch", M["cushion_b"], C["deco"], seed=321, bevel=0.004)
    bk.box((sx + 0.08, sy - 0.02, 0.435), (0.16, 0.12, 0.03), step=1, dent=0.001, turn=(0, 0, 12))
    bk.build()
    return [((x, z), (2 * r_out, 1.1), 0.5), ((x, z), (1.1, 2 * r_out), 0.5), ((x + 1.35 * math.cos(0.7), z + 1.35 * math.sin(0.7)), (0.5, 0.4), 0.45),
            ((x, z), (0.6, 0.6), 2.0)]


def climber_place(wins, length, along, width=1.4, height=4.2, blocks=()):
    """Stelle an einer Wand mit Fenstern wins (x, z0, w, h entlang der Wand) nahe along, an der eine
    Kletterpflanze kein Fenster verdeckt: sie wächst nur so hoch, wie die Wand über ihr frei ist, und
    rückt zur Seite, bis neben ihr kein Fenster im Erdgeschoss liegt. blocks = weitere Hindernisse wie
    Fenster (z. B. Bögen über der Gasse). Liefert (along, Breite, Höhe) oder None."""
    best = None
    for w in (width, width * 0.7, 0.55):
        for k in range(41):
            for sg in ((1, -1) if k else (1,)):
                a = along + sg * k * 0.1
                if a - w / 2 < 0.25 or a + w / 2 > length - 0.25:
                    continue
                top = height
                for wx, z0, ww, hh in list(wins) + list(blocks):
                    if abs(a - wx) < ww / 2 + w / 2 + 0.15:
                        top = min(top, z0 - 0.2)
                if top < 2.0:
                    continue
                score = top * w - 0.6 * k * 0.1
                if best is None or score > best[0]:
                    best = (score, a, w, top)
        if best:
            break
    return best[1:] if best else None


def alley_ivy(M, C, p0, p1, wins, roots, rnd, blocks=(), height=4.5):
    """Wilder Efeu an einer Gassenwand p0 → p1 (wächst mit der Gasse, kennt ihre Fenster wins =
    (x, z0, w, h) entlang der Wand und weitere freie Bereiche blocks = (u0, v0, u1, v1))."""
    length = T.seg_len(p0, p1)
    fm0 = T.wall_matrix(p0, p1)
    holes = [(x - w / 2 - 0.12, z0 - 0.17, x + w / 2 + 0.12, z0 + hh + 0.3) for x, z0, w, hh in wins] + list(blocks)
    GR.plant_palette(M)
    p = GR.Plant(M, C["ivy"], seed=rnd.randrange(99999))
    GR.wall_ivy(p, length, height, holes, rnd, lambda u, v, w: tuple(fm0 @ Vector((u, v, w))), [(a, 0.0) for a in roots],
                reach=(0.3, 1.0), bumps=[(0.0, 0.4, 0.1)])
    p.build()


def wall_tufts(spots, p0z, p1z, x, inward, rnd, avoid, every=None):
    """Grasbüschel aus der Ecke zwischen Gassenwand und Pflaster (Godot x der Wand, z von p0z bis p1z,
    inward = Richtung in die Gasse), nach vorn gefächert; unregelmäßig (einzeln oder in kleinen Gruppen),
    nicht vor Töpfen und Türen (avoid = [(x, z, Abstand)])."""
    face = -90.0 if inward < 0 else 90.0
    z = min(p0z, p1z) + rnd.uniform(0.2, 1.0)
    while z < max(p0z, p1z) - 0.3:
        for k in range(1 if rnd.random() < 0.6 else rnd.randint(2, 3)):
            zz = z + k * rnd.uniform(0.14, 0.32)
            px = x + inward * 0.1
            if zz < max(p0z, p1z) - 0.2 and all(math.hypot(px - ax, zz - az) > d for ax, az, d in avoid):
                gx_, gy_ = G(px, zz)
                spots.append(("walltuft", (gx_, gy_, 0.0), (0.3, 0.15, 0.3), face + rnd.uniform(-22, 22)))
        z += rnd.uniform(0.45, 1.0) if rnd.random() < 0.4 else rnd.uniform(1.1, 2.8)


def library_alley(M, C, rnd):
    L = LAYOUT
    lx, fx = L["library_x"], L["far_x"]
    end = L["alley_end_z"]
    gz = end - L["garden_depth"]
    gx = fx - L["garden_extra_width"]
    h = L["wall_height"]
    spots = []
    wins_lib = back_wall(M, C, "Rückwand hinter der Bücherei", G(lx, L["library_back_z"]), G(lx, end + 0.6), h, "brick_a", rnd)
    wins_pub = back_wall(M, C, "Rückwand hinter dem Pub", G(fx, gz), G(fx, L["neighbor_back_z"]), h, "plaster_a", rnd, kind="plaster")
    back_wall(M, C, "Gartenwand hinten", G(gx, gz), G(fx, gz), h - 0.6, "plaster_b", rnd, kind="plaster")
    wins_gl = back_wall(M, C, "Gartenwand links", G(gx, end + 0.6), G(gx, gz), h - 0.4, "brick_c", rnd)
    # Lattenzaun hinten mit runden Latten-Köpfen
    fz = end + 0.15
    fence = Body("Gartenzaun", M["fence"], C["walls"], seed=330, vary=0.07, bevel=0.006)
    x = gx + 0.08
    while x < lx - 0.05:
        px, py = G(x, fz)
        fence.slab([(-0.04, 0.0), (0.04, 0.0), (0.04, 1.12), (0.0, 1.2), (-0.04, 1.12)], 0.03,
                   Matrix.Translation((px, py + 0.015, 0)) @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))), dent=0.002)
        x += 0.13
    for zz in (0.3, 0.9):
        a, b = G(gx, fz + 0.045), G(lx, fz + 0.045)
        fence.box(((a[0] + b[0]) / 2, a[1], zz), (lx - gx, 0.035, 0.08), step=0.6, dent=0.002)
    fence.build()
    bz = end + 2.5
    # Mauern zwischen Garten und den Häusern hinten (sonst sieht man seitlich hinaus)
    for x0, x1, key in ((lx, lx + 0.3, "brick_a"), (gx - 0.3, gx, "brick_c")):
        wl = Body("Hofmauer %.1f" % x0, M[key], C["walls"], seed=331, vary=0.04, bevel=0.012)
        (ax, ay), (bx2, by2) = G(x0, end + 0.6), G(x1, bz + 0.05)
        wl.box(((ax + bx2) / 2, (ay + by2) / 2, h / 2), (abs(bx2 - ax), abs(by2 - ay), h), step=0.6, dent=0.005)
        wl.build()
        cap = Body("Mauerkrone %.1f" % x0, M["stone"], C["walls"], seed=332, vary=0.08, bevel=0.02)
        cap.box(((ax + bx2) / 2, (ay + by2) / 2, h + 0.06), (abs(bx2 - ax) + 0.08, abs(by2 - ay), 0.12), step=0.6, dent=0.004)
        cap.build()
    gable_house(M, C, "Giebelhaus links", gx - 1.0, (gx + lx) / 2, bz, 6.6, "brick_b", rnd, roof_mat="slate_roof")
    gable_house(M, C, "Giebelhaus rechts", (gx + lx) / 2, lx + 1.5, bz, 7.3, "plaster_a", rnd)
    # Rasen im Garten und zwischen Zaun und Häusern (flache Körper)
    for (x0, z0, x1, z1) in ((gx, gz, fx, end), (gx, fz + 0.06, lx + 1.5, bz)):
        (ax, ay), (bx2, by2) = G(x0, z0), G(x1, z1)
        lw = Body("Rasen", M["lawn"], C["deco"], seed=333, vary=0.1)
        lw.box(((ax + bx2) / 2, (ay + by2) / 2, 0.012), (abs(bx2 - ax) - 0.02, abs(by2 - ay) - 0.02, 0.024), step=1.0, dent=0.004)
        lw.build()
    # Trittsteine zur Bank
    tx, tz = L["garden_tree"]
    tsb = Body("Trittsteine", M["slab"], C["deco"], seed=334, vary=0.12, bevel=0.012)
    for k in range(5):
        px, py = G(fx + 0.2 - k * 0.55, tz + 0.9 + math.sin(k) * 0.25)
        r = rnd.uniform(0.2, 0.26)
        tsb.lathe([(0.0, 0.0), (r, 0.0), (r * 1.02, 0.02), (r * 0.94, 0.04), (0.0, 0.042)], (px, py, 0.0), segs=12, dent=0.008)
    tsb.build()
    obstacles = round_bench(M, C, tx, tz, rnd)
    p = G(tx, tz)
    # der große Baum (tree_garden_big): Krone passt genau in den Hof, darum fester Hinweis "garden"
    spots.append(("tree", (p[0], p[1], 0.0), (5.6, 7.4, 10.0), 0.0, "garden"))
    # Hecke hinter dem Zaun, Beete am Rand des Gartens
    a, b = G(gx + 0.3, fz + 1.1), G(lx - 0.3, fz + 1.1)
    spots.append(("hedge", ((a[0] + b[0]) / 2, a[1], 0.02), (lx - gx - 0.6, 1.2, 1.6), 180.0))
    for (x0, z0, x1, z1, face) in ((gx + 0.25, gz + 0.25, fx - 0.3, gz + 0.85, 0.0), (gx + 0.25, gz + 1.0, gx + 0.85, end - 0.3, 90.0)):
        (ax, ay), (bx2, by2) = G(x0, z0), G(x1, z1)
        spots.append(("bed", ((ax + bx2) / 2, (ay + by2) / 2, 0.02), (max(abs(bx2 - ax), abs(by2 - ay)), 0.6, 0.9), face))
    # Töpfe an der Wand hinter der Bücherei (Gasse) und Efeu an den Wänden
    avoid = []
    for zz in (5.6, 8.3, 9.0):
        ok = all(abs((zz - L["library_back_z"]) - wx) > w / 2 + 0.35 for wx, z0, w, _ in wins_lib if z0 < 2)
        if ok:
            px, py = G(lx - 0.34, zz)
            spots.append(("pot", (px, py, 0.0), (0.5, 0.5, 1.0), -90.0))
            avoid.append((lx - 0.34, zz, 0.6))
    # Efeu wächst wild an den Wänden: um Fenster herum, nicht hinter Töpfe und Laterne
    lib_len, pub_len, gl_len = end + 0.6 - L["library_back_z"], gz - L["neighbor_back_z"], end + 0.6 - gz
    lantern_lib = (3.0, 2.0, 3.45, 3.3)   # Wandlaterne Gasse (along 3,2 m, 2,7 m hoch)
    for (x, z, p0, p1, height, wins, along_of, length, extra) in (
            (lx, 11.4, G(lx, L["library_back_z"]), G(lx, end + 0.6), 5.0, wins_lib, lambda zz: zz - L["library_back_z"], lib_len,
             [lantern_lib]),
            (fx, 7.0, G(fx, gz), G(fx, L["neighbor_back_z"]), 5.2, wins_pub, lambda zz: gz - zz, pub_len, []),
            (gx, 14.3, G(gx, end + 0.6), G(gx, gz), 4.6, wins_gl, lambda zz: end + 0.6 - zz, gl_len, [])):
        pots = [(along_of(az) - 0.32, 0.0, along_of(az) + 0.32, 1.0) for ax, az, d in avoid if abs(ax - x) < 0.5]
        place = climber_place(wins, length, along_of(z), 1.0, 4.0, [((a0 + a1) / 2, 0.0, a1 - a0, 1.0) for a0, _, a1, _ in pots])
        if place:
            roots = [place[0]] + ([place[0] + rnd.choice((-1, 1)) * rnd.uniform(0.8, 1.6)] if rnd.random() < 0.5 else [])
            roots = [a for a in roots if 0.3 < a < length - 0.3 and not any(a0 - 0.1 < a < a1 + 0.1 for a0, _, a1, _ in pots)]
            alley_ivy(M, C, p0, p1, wins, roots, rnd, pots + extra, height)
    # Grasbüschel am Fuß der Gassenwände (nicht im Garten: dort ist Rasen)
    wall_tufts(spots, L["library_back_z"] + 0.4, gz, lx, -1, rnd, avoid)
    wall_tufts(spots, L["neighbor_back_z"] + 0.3, gz, fx, 1, rnd, avoid)
    T.placed(C["deco"], T.canon(*(G(lx, 7.0), G(lx, 7.8)), 0.4, 0.0, 0.0), T.wall_lantern, M, C, "Wandlaterne Gasse", 0.0, 2.7, seed=340)
    return obstacles, spots


def stone_arch(M, C, name, x0, x1, z, depth, spring, top, rnd):
    """Steinbogen über der Gasse: Bogensteine strahlenförmig (Schlussstein größer), Laibung, Mauer
    darüber bis top. Alles Körper."""
    a = (x1 - x0) / 2
    cx = (x0 + x1) / 2
    (_, y0), (_, y1) = G(cx, z), G(cx, z - depth)
    wall = Body(name + " Mauer", M["sandstone"], C["walls"], seed=rnd.randrange(999), vary=0.04)
    outline = [(x0, top)] + [(cx - a * math.cos(math.pi * k / 16), spring + a * math.sin(math.pi * k / 16)) for k in range(17)] + [(x1, top)]
    # Umriss liegt in der Ebene x/z (Blender), Platte von y0 über die Tiefe der Gasse nach y1
    wall.slab(outline, abs(y1 - y0), Matrix(((1, 0, 0, 0), (0, 0, 1, min(y0, y1)), (0, 1, 0, 0), (0, 0, 0, 1))), dent=0.004)
    wall.build()
    st = Body(name + " Bogensteine", M["stone"], C["walls"], seed=rnd.randrange(999), vary=0.1, bevel=0.012)
    n = 11
    for k in range(n):
        t = math.pi * (k + 0.5) / n
        key = k == n // 2
        rr = a + 0.16
        for yy in (y0 + 0.02 * (1 if y1 > y0 else -1), y1 - 0.02 * (1 if y1 > y0 else -1)):
            m = Matrix.Translation((cx - rr * math.cos(t), yy, spring + rr * math.sin(t))) @ Matrix.Rotation(-(t - math.pi / 2), 4, "Y")
            st.box((0, 0, 0), (2 * rr * math.sin(math.pi / (2 * n)) * (1.15 if key else 0.92), 0.08, 0.36 if key else 0.3), step=1, dent=0.004,
                   matrix=m)
    st.build()


def opposite_alley(M, C, rnd):
    L = LAYOUT
    x0, x1 = L["opposite_alley_x0"], L["opposite_alley_x1"]
    z0 = L["opposite_end_z"] + 0.2
    z_end = L["opposite_end_z"] - L["opposite_back_depth"]
    h = 6.5
    spots = []
    wins_l = back_wall(M, C, "Wand links", G(x0, z0), G(x0, z_end), h, "sandstone", rnd, kind="ashlar", roof=True, pipe=False)
    wins_r = back_wall(M, C, "Wand rechts", G(x1, z_end), G(x1, z0), h, "sandstone", rnd, kind="ashlar", roof=True, pipe=False)
    for k, zz in enumerate((z0 - 2.5, z0 - 6.5, z0 - 10.0)):
        stone_arch(M, C, "Bogen %d" % (k + 1), x0, x1, zz, 0.6, 2.4 + 0.1 * k, h, rnd)
    # Ende: Wand mit Tür und Laterne
    endw = Body("Endwand", M["sandstone"], C["walls"], seed=350, vary=0.04)
    p0, p1 = G(x0, z_end), G(x1, z_end)
    T.wall_run(endw, p0, p1, 0.0, h, thick=0.3, step=0.6)
    ew = endw.build()
    dx = (x0 + x1) / 2
    fm = T.wall_matrix(p0, p1, dx - x0, 0.0)
    SB.boolean_cut(ew, [SH.cutter_for(fm, 0.95, 2.15, 0.3)])
    SC.add_bevel(ew, 0.02)
    SH.plank_door(M, C, "Tür hinten", fm, 0.95, 2.15, 0.3, seed=351)
    T.placed(C["deco"], T.canon(p0, p1, dx - x0 + 0.62, 0.0, 0.0), T.wall_lantern, M, C, "Laterne hinten", 0.0, 2.6, seed=352)
    avoid = [(dx, z_end, 0.9)]
    for zz, face, xw in ((z0 - 1.5, 90.0, x0 + 0.3), (z0 - 5.6, 90.0, x0 + 0.3), (z0 - 8.3, -90.0, x1 - 0.3)):
        px, py = G(xw, zz)
        spots.append(("pot", (px, py, 0.0), (0.4, 0.4, 0.8), face))
        avoid.append((xw, zz, 0.6))
    # Efeu wächst wild an den Wänden: um Fenster herum, nicht unter die Bögen über der Gasse
    length = z0 - z_end
    arches = [(z0 - zz + 0.3, 2.2, 0.9, 4.0) for zz in (z0 - 2.5, z0 - 6.5, z0 - 10.0)]
    for zz, xw, wins, left, p0, p1 in ((z0 - 3.5, x0, wins_l, True, G(x0, z0), G(x0, z_end)), (z0 - 4.6, x1, wins_r, False, G(x1, z_end), G(x1, z0))):
        along = z0 - zz if left else zz - z_end
        blocks = arches if left else [(length - a, z, w, hh) for a, z, w, hh in arches]
        pots = [(((z0 - az) if left else (az - z_end)) - 0.3, 0.0, ((z0 - az) if left else (az - z_end)) + 0.3, 0.9)
                for ax, az, d in avoid if abs(ax - xw) < 0.5]
        arch_holes = [(a - w / 2 - 0.1, z, a + w / 2 + 0.1, h) for a, z, w, hh in blocks]
        place = climber_place(wins, length, along, 1.0, 4.0, blocks + [((a0 + a1) / 2, 0.0, a1 - a0, 1.0) for a0, _, a1, _ in pots])
        if place:
            roots = [place[0]] + ([place[0] + rnd.choice((-1, 1)) * rnd.uniform(1.0, 2.0)] if rnd.random() < 0.6 else [])
            roots = [a for a in roots if 0.3 < a < length - 0.3 and not any(a0 - 0.1 < a < a1 + 0.1 for a0, _, a1, _ in pots + arch_holes)]
            alley_ivy(M, C, p0, p1, wins, roots, rnd, pots + arch_holes, h - 0.8)
    wall_tufts(spots, z_end + 0.3, z0, x0, 1, rnd, avoid)
    wall_tufts(spots, z_end + 0.3, z0, x1, -1, rnd, avoid)
    return spots


def export(C, name, obstacles, spots):
    # Hindernisse in Godot-Koordinaten (x, z) → Blender (x, -z)
    obstacles = {k: ((p[0], -p[1]), size, h) for k, (p, size, h) in (obstacles or {}).items()}
    cols = SC.colliders(C, obstacles) if obstacles else []
    for spot in spots:
        kind, pos, size, face = spot[:4]
        SH.plant_spot(C, kind, pos, size, facing=face, hint=spot[4] if len(spot) > 4 else "")
    objs = [o for k, c in C.items() if k not in ("env", "collision", "plants", "light") for o in c.objects if o.type == "MESH"]
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    glb = os.path.join(OUT, name + ".glb")
    tris, n = SC.export_objects(objs, cols, glb, palette=True, extra=list(C["plants"].objects))
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, glb)
    print("%s: %d Dreiecke, %d Netze, %d Pflanzplätze, offene Kanten: %s" % (name, tris, n, len(spots), bad if bad else "keine"))


def collections(title):
    root = SB.collection(title)
    C = {k: SB.collection(v + " (" + title + ")", root) for k, v in (("walls", "Mauern"), ("roof", "Dächer"), ("windows", "Fenster"),
                                                                    ("shop", "Türen"), ("inside", "Räume"), ("pots", "Kästen"),
                                                                    ("deco", "Deko"), ("ivy", "Efeu"), ("plants", "Pflanzplätze"),
                                                                    ("light", "Licht"))}
    C["env"] = SB.collection("Umgebung (nur Vorschau)")
    C["collision"] = SB.collection("Kollision (" + title + ")", root)
    return C


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("alleys_storybook.blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    mats(M)
    rnd = random.Random(31)
    C1 = collections("Gasse Bücherei")
    SC.SPOTS["coll"] = C1["plants"]
    obstacles, spots = library_alley(M, C1, rnd)
    export(C1, "alley_library", {"Bank %d" % i: o for i, o in enumerate(obstacles)}, spots)
    C2 = collections("Gasse gegenüber")
    SC.SPOTS["coll"] = C2["plants"]
    spots2 = opposite_alley(M, C2, random.Random(47))
    export(C2, "alley_opposite", None, spots2)
    if "--render" in argv:
        SC.setup_render("--quick" in argv)
        L = LAYOUT
        cx = (L["library_x"] + L["far_x"]) / 2
        SC.render("gasse_1", (cx, -(L["alley_start_z"] + 1.0), 1.6), (cx, -L["alley_end_z"], 2.0), 24, (1200, 900))
        SC.render("gasse_garten", (cx + 0.6, -(L["alley_end_z"] - 7.5), 1.6), (cx - 2.5, -(L["alley_end_z"] - 2.0), 1.5), 22, (1200, 900))
        ox = (L["opposite_alley_x0"] + L["opposite_alley_x1"]) / 2
        SC.render("gasse_gegenueber", (ox, -(L["opposite_front_z"] + 0.5), 1.6), (ox, -(L["opposite_end_z"] - 8.0), 1.8), 24, (1200, 900))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
