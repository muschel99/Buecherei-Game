"""Der große Garten hinter Bücherei und Pub (Etappe 8d, „Die Oase hinter der Bücherei“, Zettel 02 – fertiger Zustand).

Nach der Skizze der Entwicklerin: Die Gasse neben der Bücherei führt offen in einen Garten, der hinter Bücherei und Pub liegt;
rechts endet er an einer Gartenmauer (Kante = rechte Seite des Pubs), links an einer Gartenmauer bis zum Grundstück des
Holzhäuschens (das Häuschen selbst kommt mit Zettel 05). Ganz hinten fließt ein Bach mit Steinrand, der links und rechts unter
einem Mauerbogen verschwindet; dahinter stehen die Rückseiten der Häuser der nächsten Straße. Der Baum mit der runden Bank und
das Vogelbad bleiben, wo sie im kleinen Garten waren. Die Rückseiten der Häuser ringsum (Pub, Modeladen, Nachbarn) bekommen eine
Haut mit Fenstern, die auf der Wand sitzen (Rahmen, Scheibe, zugezogene Vorhänge, manchmal Fensterläden) – die Häuser selbst
haben hinten nur glatte Wände.

Aufruf (Terminal, im Projektordner):
    godot --headless --path . res://scenes/tools/export_layout.tscn      (Lage aus dem Spiel, falls geändert)
    blender -b --factory-startup --python tools/blender/build_storybook_backyard.py [-- --force]

Ergebnis (Koordinaten wie unter "Outside" im Spiel, y = 0 = Gehweg; Blender: x, -z, y):
    assets/models/world/backyard.glb          Modell (die Gasse setzt es ein: scripts/world/alley.gd)
    assets/models/source/backyard_storybook.blend
Pflanzen (Baum, Beete, Efeu-Töpfe) kommen als austauschbare Szenen auf die Pflanzplätze „PlantSpot_…“; Efeu an den Mauern
gehört zum Modell. Kollision der Mauern und des Bachs baut das Spiel (Alley); Bank und Vogelbad bringen eigene Kollisionen mit.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_storybook_alleys as A  # noqa: E402
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

L = A.LAYOUT
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "backyard_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "backyard_storybook.stamp")
G = A.G

RIGHT_X = L["backyard_right_x"]
LEFT_X = L["backyard_left_x"]
GARDEN_LEFT_X = L["backyard_garden_left_x"]
COTTAGE_Z = L["backyard_cottage_front_z"]
STREAM_Z = L["backyard_stream_z"]
STREAM_W = L["backyard_stream_width"]
BACK_Z = L["backyard_back_wall_z"]
WALL_H = L["backyard_wall_height"]
LIB_X, FAR_X = L["library_x"], L["far_x"]
LIB_BACK, PUB_BACK = L["library_back_z"], L["neighbor_back_z"]
BR_X0, BR_Z0, BR_W, BR_D = L["back_room"]
BR_X1, BR_BACK = BR_X0 + BR_W + 0.2, BR_Z0 + BR_D + 0.2   # Außenseite des Hinterzimmers (Wände 0,2)
WATER_TOP = 0.045        # Wasser knapp über dem Boden (der Boden ist überall flach), Steinrand ringsum höher


def mats(M):
    mk = SC.make_material
    M["gravel"] = mk("Kies Garten", (0.78, 0.72, 0.6), grain="stone", rough=0.95, vary=0.1, bump=0.4, scale=6.0)
    M["stream"] = mk("Wasser Bach", (0.26, 0.38, 0.38), grain="smooth", rough=0.08, vary=0.03)
    M["river_stone"] = mk("Bachstein", (0.62, 0.6, 0.55), grain="stone", rough=0.9, vary=0.14, bump=0.35)
    M["moss_stone"] = mk("Bachstein Moos", (0.44, 0.5, 0.34), grain="stone", rough=0.95, vary=0.14, bump=0.4)
    M["tunnel"] = mk("Bachtunnel", (0.06, 0.07, 0.06), grain="stone", rough=0.95, vary=0.04)
    M["shutter_a"] = mk("Fensterladen Salbei", (0.48, 0.6, 0.5), grain="paint", rough=0.7, vary=0.06)
    M["shutter_b"] = mk("Fensterladen Taubenblau", (0.42, 0.54, 0.64), grain="paint", rough=0.7, vary=0.06)
    M["curtain_b"] = mk("Vorhang Altrosa", (0.86, 0.66, 0.64), grain="fabric", rough=0.9, vary=0.05)
    M["curtain_c"] = mk("Vorhang Salbei", (0.72, 0.8, 0.68), grain="fabric", rough=0.9, vary=0.05)


def facing(p0, p1, inside):
    """Wand p0 → p1 so drehen, dass ihre Außenseite (rechts der Laufrichtung, Blender) zum Punkt inside zeigt."""
    d = Vector((p1[0] - p0[0], p1[1] - p0[1]))
    n = Vector((d.y, -d.x))
    to = Vector((inside[0] - p0[0], inside[1] - p0[1]))
    return (p0, p1) if n.dot(to) > 0 else (p1, p0)


# --- Boden ---

def lawn(M, C):
    """Rasen über das ganze Grundstück (flache Körper, aneinander), dazu der schmale Streifen hinter dem Bach."""
    rects = [
        (RIGHT_X, PUB_BACK, GARDEN_LEFT_X, STREAM_Z),            # Hauptteil
        (LIB_X, LIB_BACK, BR_X0, PUB_BACK),                      # hinter der Bücherei (später Glasanbau)
        (BR_X0, BR_BACK, GARDEN_LEFT_X, PUB_BACK),               # hinter dem Hinterzimmer
        (GARDEN_LEFT_X, COTTAGE_Z, LEFT_X, STREAM_Z),            # Grundstück des Holzhäuschens
        (RIGHT_X, STREAM_Z + STREAM_W, LEFT_X, BACK_Z),          # hinter dem Bach
    ]
    for i, (x0, z0, x1, z1) in enumerate(rects):
        if x1 - x0 < 0.05 or z1 - z0 < 0.05:
            continue
        (ax, ay), (bx, by) = G(x0, z0), G(x1, z1)
        lw = Body("Rasen %d" % i, M["lawn"], C["deco"], seed=400 + i, vary=0.1)
        lw.box(((ax + bx) / 2, (ay + by) / 2, 0.012), (abs(bx - ax) - 0.004, abs(by - ay) - 0.004, 0.024), step=1.0, dent=0.004)
        lw.build()


def gravel_path(M, C, rnd):
    """Kiesweg aus der Gasse in den Garten: in einem weichen Bogen an der Bank vorbei zur Mitte und weiter zum Bach."""
    mid = (LIB_X + FAR_X) / 2
    pts = [Vector((mid, PUB_BACK - 0.2)), Vector((mid + 0.2, PUB_BACK + 1.6)), Vector((mid + 1.4, PUB_BACK + 3.4)),
           Vector((mid + 2.3, PUB_BACK + 5.6)), Vector((mid + 2.0, PUB_BACK + 7.8)), Vector((mid + 1.2, STREAM_Z - 0.6))]
    # Mittellinie glätten (Chaikin), dann Ränder mit leicht wechselnder Breite
    for _ in range(3):
        sm = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            sm += [a.lerp(b, 0.25), a.lerp(b, 0.75)]
        sm.append(pts[-1])
        pts = sm
    left, right = [], []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        d = (b - a).normalized()
        n = Vector((-d.y, d.x))
        w = 0.62 + 0.06 * math.sin(i * 0.9) + rnd.uniform(-0.02, 0.02)
        left.append(p + n * w)
        right.append(p - n * w)
    outline = [G(p.x, p.y) for p in right] + [G(p.x, p.y) for p in reversed(left)]
    # Umriss gegen den Uhrzeigersinn (Blender) – sonst umdrehen
    area = sum(outline[i][0] * outline[(i + 1) % len(outline)][1] - outline[(i + 1) % len(outline)][0] * outline[i][1]
               for i in range(len(outline)))
    if area < 0:
        outline.reverse()
    gb = Body("Kiesweg", M["gravel"], C["deco"], seed=410, vary=0.06)
    gb.slab(outline, 0.012, Matrix.Translation((0, 0, 0.02)), dent=0.003)
    gb.build()


def stepping_stones(M, C, rnd):
    """Trittsteine von der Gasse zur Bank um den Baum (wie im kleinen Garten)."""
    tx, tz = L["garden_tree"]
    tsb = Body("Trittsteine", M["slab"], C["deco"], seed=334, vary=0.12, bevel=0.012)
    for k in range(5):
        px, py = G(FAR_X + 0.2 - k * 0.55, tz + 0.9 + math.sin(k) * 0.25)
        r = rnd.uniform(0.2, 0.26)
        tsb.lathe([(0.0, 0.0), (r, 0.0), (r * 1.02, 0.02), (r * 0.94, 0.04), (0.0, 0.042)], (px, py, 0.0), segs=12, dent=0.008)
    tsb.build()


# --- Mauern ---

def garden_wall(M, C, name, p0, p1, rnd, kind="brick_c", gap=None):
    """Gartenmauer (Ziegel, Steinkrone, Feldsteinsockel), Innenseite auf der Linie p0 → p1 (Außenseite zum Garten).
    gap = (a0, a1) entlang der Mauer: dort ein Bogen über dem Bach (die Mauer steht links und rechts davon, darüber ein
    Ziegelstück mit runder Unterkante und Bogensteinen)."""
    length = T.seg_len(p0, p1)
    pieces = [(0.0, length)] if gap is None else [(0.0, gap[0]), (gap[1], length)]
    for i, (a0, a1) in enumerate(pieces):
        if a1 - a0 < 0.05:
            continue
        wl = Body("%s %d" % (name, i), M[kind], C["walls"], seed=rnd.randrange(999), vary=0.04, bevel=0.012)
        wl.box(((a0 + a1) / 2, WALL_H / 2, -0.15), (a1 - a0, WALL_H, 0.3), step=0.6, dent=0.004, matrix=T.wall_matrix(p0, p1))
        wl.build()
    cap = Body(name + " Krone", M["stone"], C["walls"], seed=rnd.randrange(999), vary=0.08, bevel=0.02)
    cap.box((length / 2, WALL_H + 0.06, -0.15), (length + 0.06, 0.12, 0.38), step=0.6, dent=0.004, matrix=T.wall_matrix(p0, p1))
    cap.build()
    if gap:
        a0, a1 = gap
        w = a1 - a0
        spring = 0.42
        rise = w / 2
        arc = [(a0 + w / 2 - math.cos(math.pi * k / 16) * w / 2, spring + math.sin(math.pi * k / 16) * rise) for k in range(17)]
        top = Body(name + " über dem Bach", M[kind], C["walls"], seed=rnd.randrange(999), vary=0.04, bevel=0.012)
        top.slab(arc + [(a1, WALL_H), (a0, WALL_H)], 0.3,
                 T.wall_matrix(p0, p1) @ Matrix.Translation((0, 0, -0.3)), dent=0.003)
        top.build()
        ring = Body(name + " Bogensteine", M["sandstone"], C["walls"], seed=rnd.randrange(999), vary=0.08, bevel=0.01)
        for k in range(9):
            t0, t1 = k / 9, (k + 1) / 9
            ang0, ang1 = math.pi * t0, math.pi * t1
            outer = 0.16
            pts = [(a0 + w / 2 - math.cos(ang0) * w / 2, spring + math.sin(ang0) * rise),
                   (a0 + w / 2 - math.cos(ang1) * w / 2, spring + math.sin(ang1) * rise),
                   (a0 + w / 2 - math.cos(ang1) * (w / 2 + outer), spring + math.sin(ang1) * (rise + outer)),
                   (a0 + w / 2 - math.cos(ang0) * (w / 2 + outer), spring + math.sin(ang0) * (rise + outer))]
            ring.slab(pts, 0.32, T.wall_matrix(p0, p1) @ Matrix.Translation((0, 0, -0.31)), dent=0.002)
        ring.build()
        # Dunkler Tunnel dahinter (man sieht nicht hindurch; das Wasser fließt hinein)
        tn = Body(name + " Tunnel", M["tunnel"], C["walls"], seed=rnd.randrange(999), vary=0.02)
        tn.box(((a0 + a1) / 2, (spring + rise + 0.1) / 2, -1.2), (w + 0.4, spring + rise + 0.1, 1.2), step=1.0, dent=0.0,
               matrix=T.wall_matrix(p0, p1))
        tn.build()
    A.plinth_run(M, C, name + " Sockel", p0, p1, rnd, z_top=0.32)


def walls(M, C, rnd):
    """Gartenmauern ringsum: rechts (hinter dem Pub-Nachbarn), links bis zum Grundstück des Holzhäuschens und um dieses herum;
    die beiden äußeren Mauern haben einen Bogen über dem Bach."""
    inside = G((RIGHT_X + GARDEN_LEFT_X) / 2, (PUB_BACK + STREAM_Z) / 2)
    walls_out = []
    s0, s1 = STREAM_Z - 0.05, STREAM_Z + STREAM_W + 0.05
    for name, (x0, z0), (x1, z1), gap_z in (
            ("Gartenmauer rechts", (RIGHT_X, PUB_BACK), (RIGHT_X, BACK_Z), (s0, s1)),
            ("Gartenmauer links", (GARDEN_LEFT_X, BR_BACK), (GARDEN_LEFT_X, COTTAGE_Z), None),
            ("Gartenmauer vor dem Häuschen", (GARDEN_LEFT_X, COTTAGE_Z), (LEFT_X, COTTAGE_Z), None),
            ("Gartenmauer außen", (LEFT_X, COTTAGE_Z), (LEFT_X, BACK_Z), (s0, s1))):
        p0, p1 = facing(G(x0, z0), G(x1, z1), inside if name != "Gartenmauer außen" else G(LEFT_X - 1.0, (COTTAGE_Z + BACK_Z) / 2))
        gap = None
        if gap_z:
            # entlang der Mauer gemessen (ab p0)
            along = [abs(-z - p0[1]) for z in gap_z]     # die Mauer läuft entlang z (Blender y)
            gap = (min(along), max(along))
        garden_wall(M, C, name, p0, p1, rnd, gap=gap)
        walls_out.append((p0, p1))
    return walls_out


# --- Rückseiten der Häuser ---

def surface_window(M, C, name, m, w, h, rnd, shutters=None, curtain=None):
    """Fenster, das auf der Wand sitzt (für die Häuser, die hinten nur eine glatte Wand haben): Rahmen mit Sprossen, Scheibe,
    dahinter zugezogene Vorhänge (zwischen Scheibe und Wand), Sims unten, Sturz oben, auf Wunsch offene Fensterläden.
    m = Wandebene (lokal x entlang, y oben, z nach außen), Mitte unten."""
    fr = Body(name + " Rahmen", M["frame"], C["windows"], seed=rnd.randrange(999), vary=0.03, bevel=0.004)
    t, d = 0.06, 0.05
    for x, ww in ((-w / 2 + t / 2, t), (w / 2 - t / 2, t)):
        fr.box((x, h / 2, d / 2), (ww, h, d), step=0.5, dent=0.0005, matrix=m)
    for y in (t / 2, h - t / 2):
        fr.box((0, y, d / 2), (w - 2 * t, t, d), step=0.5, dent=0.0005, matrix=m)
    fr.box((0, h * 0.62, d / 2 + 0.004), (w - 2 * t, 0.035, d - 0.012), step=0.5, dent=0.0, matrix=m)
    fr.box((0, h / 2, d / 2 + 0.004), (0.035, h - 2 * t, d - 0.012), step=0.5, dent=0.0, matrix=m)
    fr.build()
    gl = Body(name + " Scheibe", M["glass"], C["windows"], seed=rnd.randrange(999), vary=0.0)
    gl.box((0, h / 2, 0.026), (w - 2 * t + 0.01, h - 2 * t + 0.01, 0.006), step=1.0, dent=0.0, matrix=m)
    gl.build()
    cu = Body(name + " Vorhang", M[curtain or "curtain"], C["windows"], seed=rnd.randrange(999), vary=0.04)
    gap = rnd.uniform(0.02, 0.08)
    inner = w - 2 * t
    for sx in (-1, 1):
        cw = (inner - gap) / 2
        cx = sx * (gap / 2 + cw / 2)
        # Falten: ein paar flache Wülste nebeneinander
        for k in range(4):
            fx = cx - cw / 2 + cw * (k + 0.5) / 4
            cu.box((fx, h / 2, 0.012), (cw / 4 + 0.002, h - 2 * t - 0.01, 0.012 + 0.004 * (k % 2)), step=1.0, dent=0.0005, matrix=m)
    cu.build()
    st = Body(name + " Sims und Sturz", M["stone"], C["windows"], seed=rnd.randrange(999), vary=0.06, bevel=0.008)
    st.box((0, -0.035, 0.05), (w + 0.14, 0.07, 0.1), step=0.5, dent=0.001, matrix=m)
    st.box((0, h + 0.06, 0.025), (w + 0.16, 0.12, 0.05), step=0.5, dent=0.001, matrix=m)
    st.build()
    if shutters:
        sh = Body(name + " Läden", M[shutters], C["windows"], seed=rnd.randrange(999), vary=0.05, bevel=0.004)
        for sx in (-1, 1):
            x = sx * (w / 2 + w * 0.25 + 0.01)
            sh.box((x, h / 2, 0.02), (w / 2, h, 0.03), step=0.5, dent=0.0006, matrix=m)
            for k in range(5):
                sh.box((x, 0.12 + k * (h - 0.24) / 4, 0.038), (w / 2 - 0.06, 0.03, 0.012), step=1.0, dent=0.0, matrix=m)
        sh.build()
        hw = Body(name + " Ladenhaken", M["iron"], C["windows"], seed=rnd.randrange(999), vary=0.0)
        for sx in (-1, 1):
            for y in (0.2, h - 0.2):
                hw.box((sx * (w / 2 + 0.01), y, 0.022), (0.04, 0.03, 0.04), step=1.0, dent=0.0, matrix=m)
        hw.build()


def house_skin(M, C, name, x0, x1, back_z, eaves, rnd, kind="brick", wall="brick_a", from_y=0.0, floors=(0.95, 3.85), door=None,
               plinth=True):
    """Haut auf der glatten Rückseite eines Hauses (2 cm davor): Ziegel oder Putz bis unter die Traufe, Fenster auf der Wand,
    Fallrohr, Sockel; door = Mitte einer Hintertür (entlang)."""
    p0, p1 = G(x0, back_z + 0.02), G(x1, back_z + 0.02)
    p0, p1 = facing(p0, p1, G((x0 + x1) / 2, back_z + 3.0))
    length = T.seg_len(p0, p1)
    sk = Body(name, M[wall], C["walls"], seed=rnd.randrange(999), vary=0.03, bevel=0.01)
    T.wall_run(sk, p0, p1, from_y, eaves - 0.03, thick=0.06, step=0.6)
    sk.build()
    if plinth and from_y < 0.1:
        A.plinth_run(M, C, name + " Sockel", p0, p1, rnd, z_top=0.34)
    shutter = rnd.choice(("shutter_a", "shutter_b", None))
    curtains = rnd.choice(("curtain", "curtain_b", "curtain_c"))
    x = rnd.uniform(0.9, 1.2)
    k = 0
    while x < length - 0.8:
        for y0 in floors:
            if y0 < from_y + 0.3 or y0 + 1.25 > eaves - 0.3:
                continue
            if door and abs(x - door) < 1.0 and y0 < 2.0:
                continue
            if rnd.random() < 0.8:
                surface_window(M, C, "%s Fenster %d" % (name, k), T.wall_matrix(p0, p1, x, y0, 0.0), 0.8, 1.25, rnd,
                               shutters=shutter if y0 < 2.0 else None, curtain=curtains)
                k += 1
        x += rnd.uniform(2.0, 2.6)
    if door is not None:
        back_door(M, C, name + " Hintertür", T.wall_matrix(p0, p1, door, 0.0, 0.0), rnd)
    # Fallrohr an einem Ende, mit Schellen
    px = length - 0.25 if rnd.random() < 0.5 else 0.25
    m = T.wall_matrix(p0, p1, px, 0.0, 0.0)
    pipe = Body(name + " Fallrohr", M["zinc"], C["walls"], seed=rnd.randrange(999), vary=0.03)
    pipe.tube([m @ Vector((0, 0.05, 0.08)), m @ Vector((0, eaves - 0.15, 0.08))], 0.04, segs=10, round_ends=True)
    pipe.tube([m @ Vector((0, 0.18, 0.08)), m @ Vector((0, 0.05, 0.2))], 0.04, segs=10, round_ends=True)
    for y in range(1, int(eaves / 1.6) + 1):
        pipe.box((0, y * 1.5, 0.04), (0.1, 0.03, 0.08), step=1.0, dent=0.0, matrix=m)
    pipe.build()


def back_door(M, C, name, m, rnd):
    """Hintertür auf der Wand (Pub): Holztür mit Rahmen, Klinke, Stufe davor, Laterne daneben."""
    dw, dh = 0.95, 2.1
    fr = Body(name + " Rahmen", M["frame"], C["shop"], seed=rnd.randrange(999), vary=0.03, bevel=0.005)
    for x in (-dw / 2 - 0.04, dw / 2 + 0.04):
        fr.box((x, dh / 2, 0.04), (0.08, dh, 0.08), step=0.5, dent=0.0005, matrix=m)
    fr.box((0, dh + 0.04, 0.04), (dw + 0.16, 0.08, 0.08), step=0.5, dent=0.0005, matrix=m)
    fr.build()
    dr = Body(name + " Blatt", M["h_door"], C["shop"], seed=rnd.randrange(999), vary=0.05, bevel=0.004)
    for k in range(4):
        dr.box((-dw / 2 + dw * (k + 0.5) / 4, dh / 2, 0.03), (dw / 4 - 0.004, dh - 0.004, 0.04), step=0.5, dent=0.0008, matrix=m)
    for y in (0.35, dh - 0.35):
        dr.box((0, y, 0.058), (dw - 0.06, 0.1, 0.02), step=0.5, dent=0.0005, matrix=m)
    dr.build()
    hw = Body(name + " Klinke", M["iron"], C["shop"], seed=rnd.randrange(999), vary=0.0)
    hw.tube([m @ Vector((dw / 2 - 0.12, 1.02, 0.07)), m @ Vector((dw / 2 - 0.12, 1.02, 0.11)), m @ Vector((dw / 2 - 0.24, 1.02, 0.11))],
            0.012, segs=6, round_ends=True)
    hw.build()
    stp = Body(name + " Stufe", M["stone"], C["shop"], seed=rnd.randrange(999), vary=0.06, bevel=0.01)
    stp.box((0, 0.07, 0.2), (dw + 0.4, 0.14, 0.4), step=0.5, dent=0.002, matrix=m)
    stp.build()


def house_backs(M, C, rnd):
    """Rückseiten der Häuser, die an den Garten grenzen (aus layout.json): Modeladen (über dem Hinterzimmer), sein Nachbar,
    Pub (mit Hintertür zum Garten) und dessen Nachbar; dazu zwei Fenster oben an der Rückwand der Bücherei."""
    for i, (x0, x1, back_z, eaves) in enumerate(L["house_backs"]):
        pub = abs(x1 - FAR_X) < 0.01
        if x0 >= BR_X0 - 0.01 and x0 < BR_X1:
            # Modeladen: unten steht das Hinterzimmer davor – die Haut beginnt über dessen Dach, rechts daneben ab dem Boden
            house_skin(M, C, "Rückseite Modeladen oben", x0, BR_X1 + 0.05, back_z, eaves, rnd, wall="plaster_b", kind="plaster",
                       from_y=3.55, plinth=False)
            house_skin(M, C, "Rückseite Modeladen", BR_X1 + 0.05, x1, back_z, eaves, rnd, wall="plaster_b", kind="plaster")
        elif pub:
            house_skin(M, C, "Rückseite Pub", x0, x1, back_z, eaves, rnd, wall="plaster_a", kind="plaster", door=(x1 - x0) * 0.62)
        else:
            house_skin(M, C, "Rückseite Nachbar %d" % i, x0, x1, back_z, eaves, rnd, wall=("brick_a", "brick_b")[i % 2])
    # Bücherei oben: zwei Fenster mit Vorhängen auf der Ziegelwand (das Erdgeschoss bekommt später den Glasanbau)
    p0, p1 = facing(G(LIB_X, LIB_BACK + 0.005), G(-LIB_X, LIB_BACK + 0.005), G(0.0, LIB_BACK + 3.0))
    for k, x in enumerate((1.6, 4.8)):
        surface_window(M, C, "Bücherei hinten Fenster %d" % k, T.wall_matrix(p0, p1, x, 4.0, 0.0), 0.9, 1.35, rnd, curtain="curtain_b")


def back_row(M, C, rnd):
    """Hinter dem Bach: die Rückseiten der Häuser der nächsten Straße (Giebelhäuser, Wand zum Garten)."""
    x = RIGHT_X - 5.2
    widths = [5.4, 6.0, 5.0, 5.8, 4.8, 5.6, 5.2]
    styles = [("brick_b", "slate_roof", 7.2), ("plaster_a", "h_roof", 6.6), ("brick_a", "h_roof", 7.6), ("plaster_b", "slate_roof", 6.9),
              ("brick_c", "h_roof", 7.3), ("plaster_a", "slate_roof", 6.8), ("brick_b", "h_roof", 7.0)]
    k = 0
    while x < LEFT_X + 4.5 and k < len(widths):
        w = widths[k]
        wall, roof, h = styles[k]
        A.gable_house(M, C, "Haus hinter dem Bach %d" % (k + 1), x, x + w, BACK_Z, h, wall, rnd, roof_mat=roof)
        x += w
        k += 1


# --- Bach ---

def stream(M, C, rnd):
    """Bach: Wasser in einem Bett aus Steinen, die beiden Ufer mit unregelmäßigen, teils bemoosten Steinen gesäumt, ein paar
    Steine im Wasser. Er fließt links und rechts in die Tunnel unter den Mauerbögen."""
    x0, x1 = RIGHT_X - 1.4, LEFT_X + 1.4
    z0, z1 = STREAM_Z, STREAM_Z + STREAM_W
    (ax, ay), (bx, by) = G(x0, z0), G(x1, z1)
    w = Body("Bach Wasser", M["stream"], C["deco"], seed=420, vary=0.02)
    w.box(((ax + bx) / 2, (ay + by) / 2, WATER_TOP / 2), (abs(bx - ax), abs(by - ay) - 0.02, WATER_TOP), step=1.0, dent=0.0)
    w.build()
    # Ufersteine: in Reihen entlang beider Ufer (halb im Boden, halb über dem Wasser)
    for edge, sign in ((z0, 1), (z1, -1)):
        stones = Body("Ufersteine %.1f" % edge, M["river_stone"], C["deco"], seed=421 + sign, vary=0.12)
        moss = Body("Ufersteine bemoost %.1f" % edge, M["moss_stone"], C["deco"], seed=423 + sign, vary=0.12)
        x = RIGHT_X + 0.05
        while x < LEFT_X - 0.05:
            r = rnd.uniform(0.11, 0.2)
            px, py = G(x + r, edge + sign * rnd.uniform(0.0, 0.05))
            target = moss if rnd.random() < 0.35 else stones
            target.blob((px, py, r * 0.35), r, subdiv=2, lump=0.18, scale=(1.0, 0.85, 0.62))
            x += r * rnd.uniform(1.5, 1.9)
        stones.build()
        moss.build()
    # Steine im Wasser (ragen heraus)
    inw = Body("Steine im Bach", M["moss_stone"], C["deco"], seed=425, vary=0.12)
    x = RIGHT_X + rnd.uniform(1.0, 2.0)
    while x < LEFT_X - 1.0:
        r = rnd.uniform(0.1, 0.17)
        px, py = G(x, z0 + rnd.uniform(0.35, STREAM_W - 0.35))
        inw.blob((px, py, r * 0.3), r, subdiv=2, lump=0.2, scale=(1.1, 0.9, 0.7))
        x += rnd.uniform(1.4, 3.2)
    inw.build()


# --- Ganzes Modell ---

def backyard(M, C, rnd):
    lawn(M, C)
    gravel_path(M, C, rnd)
    stepping_stones(M, C, rnd)
    garden_walls = walls(M, C, rnd)
    house_backs(M, C, rnd)
    back_row(M, C, rnd)
    stream(M, C, rnd)
    tx, tz = L["garden_tree"]
    obstacles = A.round_bench(M, C, tx, tz, rnd) + A.bird_bath(M, C, A.BIRD_BATH[0], A.BIRD_BATH[1], rnd)
    spots = []
    p = G(tx, tz)
    spots.append(("tree", (p[0], p[1], 0.0), (5.6, 7.4, 10.0), 0.0, "garden"))
    # Beete an den Mauern (die Pflanzen setzt Greenery ein)
    for (x0, z0, x1, z1, face) in (
            (RIGHT_X + 0.25, PUB_BACK + 0.6, RIGHT_X + 0.85, STREAM_Z - 1.4, 90.0),           # rechts an der Mauer
            (GARDEN_LEFT_X - 0.85, BR_BACK + 0.4, GARDEN_LEFT_X - 0.25, COTTAGE_Z - 0.3, -90.0),  # links an der Mauer
            (RIGHT_X + 1.2, STREAM_Z + STREAM_W + 0.1, LEFT_X - 1.2, BACK_Z - 0.1, 180.0)):   # hinter dem Bach
        (ax, ay), (bx, by) = G(x0, z0), G(x1, z1)
        spots.append(("bed", ((ax + bx) / 2, (ay + by) / 2, 0.02), (max(abs(bx - ax), abs(by - ay)), min(abs(bx - ax), abs(by - ay)), 1.0),
                      face))
    # Efeu wächst an den Gartenmauern
    for (p0, p1) in garden_walls:
        length = T.seg_len(p0, p1)
        if length < 3.0:
            continue
        place = A.climber_place([], length, length * rnd.uniform(0.3, 0.7), 1.0, 2.2)
        if place:
            A.alley_ivy(M, C, p0, p1, [], [place[0]], rnd, height=WALL_H - 0.2)
    # Wandlaterne an der Rückseite des Pubs, nahe der Gasse
    T.placed(C["deco"], T.canon(G(FAR_X - 1.7, PUB_BACK + 0.02), G(FAR_X - 0.9, PUB_BACK + 0.02), 0.4, 0.0, 0.0), T.wall_lantern, M, C,
             "Wandlaterne Garten", 0.0, 2.6, seed=440)
    return obstacles, spots


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("backyard_storybook.blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    A.mats(M)
    mats(M)
    rnd = random.Random(808)
    C = A.collections("Garten")
    SC.SPOTS["coll"] = C["plants"]
    obstacles, spots = backyard(M, C, rnd)
    A.export(C, "backyard", {"Garten %d" % i: o for i, o in enumerate(obstacles)}, spots)
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
