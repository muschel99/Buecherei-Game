"""Der große Garten hinter Bücherei und Pub (Etappe 8d, „Die Oase hinter der Bücherei“, Zettel 02 – fertiger Zustand).

Nach der Skizze der Entwicklerin und ihren Wünschen aus der Testrunde: Die Gasse neben der Bücherei führt als einziger Weg von der
Straße in den Garten (keine Türen anderer Häuser). Rechts endet er an einer Gartenmauer (Kante = rechte Seite des Pubs), links an
einer Mauer hinter dem Nachbarn des Modegeschäfts, hinten an einer Mauer; vorn liegen die Rückseiten der Häuser. Ein Bach kommt
links vorn aus einem gewölbten Tunnel, fließt in einem Bogen durch den Garten und verschwindet rechts hinten im zweiten Tunnel;
eine gewölbte Holzbrücke führt hinüber zum Platz des Holzhäuschens (hinten links, Zettel 05). Am Ufer Steine, Schilf und
Rohrkolben. Der Baum mit der runden Bank und das Vogelbad bleiben, wo sie im kleinen Garten waren. Hinter den Mauern Bäume
(Pflanzplätze) und eine Häuserreihe mit Lücken (viel Himmel). Die Rückseiten der Häuser ringsum bekommen eine Haut mit Fenstern,
die auf der Wand sitzen (Rahmen, Scheibe, zugezogene Vorhänge, manchmal Fensterläden) – die Häuser haben hinten nur glatte Wände.

Aufruf (Terminal, im Projektordner):
    godot --headless --path . res://scenes/tools/export_layout.tscn      (Lage aus dem Spiel, Maße in GameConfig backyard_*)
    blender -b --factory-startup --python tools/blender/build_storybook_backyard.py [-- --force]

Ergebnis (Koordinaten wie unter "Outside" im Spiel, y = 0 = Gehweg; Blender: x, -z, y):
    assets/models/world/backyard.glb          Modell (die Gasse setzt es ein: scripts/world/alley.gd)
    assets/models/source/backyard_storybook.blend
Pflanzen (Baum, Beete, Bäume hinter den Mauern) kommen als austauschbare Szenen auf die Pflanzplätze „PlantSpot_…“; Efeu an den
Mauern und Schilf am Bach gehören zum Modell. Das Wasser heißt im Modell „Wasser Bach“ (das Spiel gibt ihm den bewegten
Wasser-Shader). Kollision der Mauern, des Bachs und der Brücke baut das Spiel (Alley); Bank und Vogelbad bringen eigene mit.
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
import storybook_greenery as GR  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

L = A.LAYOUT
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "backyard_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "backyard_storybook.stamp")
G = A.G

RIGHT_X = L["backyard_right_x"]
LEFT_X = L["backyard_left_x"]
BACK_Z = L["backyard_back_wall_z"]
WALL_H = L["backyard_wall_height"]
STREAM_W = L["backyard_stream_width"]
BRIDGE = L["backyard_bridge"]          # Mitte x, z, Richtung (Grad, 0 = +z), Länge, Breite, Wölbung
COTTAGE = L["backyard_cottage"]        # Mitte x, z, Breite, Tiefe, Drehung
LIB_X, FAR_X = L["library_x"], L["far_x"]
LIB_BACK, PUB_BACK = L["library_back_z"], L["neighbor_back_z"]
BR_X0, BR_Z0, BR_W, BR_D = L["back_room"]
BR_X1, BR_BACK = BR_X0 + BR_W + 0.2, BR_Z0 + BR_D + 0.2   # Außenseite des Hinterzimmers (Wände 0,2)
ROW_BACK = min(h[2] for h in L["house_backs"])              # Rückseite Modeladen und Nachbar (z)
WATER_TOP = 0.045        # Wasser knapp über dem Boden (der Boden ist überall flach), Steinrand ringsum höher


def stream_line(step=0.35):
    """Mittellinie des Bachs (Godot x/z) geglättet (Chaikin) und gleichmäßig unterteilt."""
    pts = [Vector(p) for p in L["backyard_stream"]]
    for _ in range(3):
        sm = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            sm += [a.lerp(b, 0.25), a.lerp(b, 0.75)]
        sm.append(pts[-1])
        pts = sm
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        n = max(1, int((b - a).length / step))
        out += [a.lerp(b, (k + 1) / n) for k in range(n)]
    return out


def stream_z_at(x):
    """Wo der Bach die Linie x kreuzt (z)."""
    line = stream_line()
    for a, b in zip(line, line[1:]):
        if (a.x - x) * (b.x - x) <= 0 and abs(b.x - a.x) > 1e-6:
            return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
    return line[0].y


def near_bridge(p, margin=0.6):
    """Liegt ein Punkt (Godot x/z) im Bereich der Brücke?"""
    c = Vector((BRIDGE[0], BRIDGE[1]))
    d = Vector((math.sin(math.radians(BRIDGE[2])), math.cos(math.radians(BRIDGE[2]))))
    n = Vector((d.y, -d.x))
    rel = Vector(p) - c
    return abs(rel.dot(d)) < BRIDGE[3] / 2 + margin and abs(rel.dot(n)) < BRIDGE[4] / 2 + margin


def mats(M):
    mk = SC.make_material
    M["gravel"] = mk("Kies Garten", (0.66, 0.58, 0.46), grain="stone", rough=0.95, vary=0.1, bump=0.4, scale=6.0)
    M["river_stone"] = mk("Bachstein", (0.62, 0.6, 0.55), grain="stone", rough=0.9, vary=0.14, bump=0.35)
    M["moss_stone"] = mk("Bachstein Moos", (0.44, 0.5, 0.34), grain="stone", rough=0.95, vary=0.14, bump=0.4)
    # Tunnel: Gewölbe aus Steinen, nach hinten immer dunkler (man sieht ins Dunkel, nicht auf eine Wand)
    M["tunnel_a"] = mk("Bachtunnel vorn", (0.34, 0.32, 0.28), grain="stone", rough=0.95, vary=0.08, bump=0.3)
    M["tunnel_b"] = mk("Bachtunnel Mitte", (0.15, 0.15, 0.13), grain="stone", rough=0.95, vary=0.06)
    M["tunnel_c"] = mk("Bachtunnel hinten", (0.06, 0.06, 0.055), grain="stone", rough=0.95, vary=0.04)
    M["tunnel_end"] = mk("Bachtunnel Ende", (0.015, 0.015, 0.015), grain="stone", rough=1.0, vary=0.0)
    # das Wasser bekommt im Spiel den bewegten Bach-Shader: eigenes Material (nicht zusammengefasst)
    M["stream"] = mk("Wasser Bach", (0.26, 0.38, 0.38), grain="smooth", rough=0.08, vary=0.03, own=True)
    M["cattail"] = mk("Rohrkolben", (0.36, 0.22, 0.12), grain="fabric", rough=0.9, vary=0.08, plant=True)
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
    """Rasen über das ganze Grundstück (flache Körper aneinander); unter dem Bach liegt er auch (das Wasser liegt darauf)."""
    rects = [
        (RIGHT_X, PUB_BACK, LEFT_X, BACK_Z),                     # Hauptteil
        (LIB_X, LIB_BACK, BR_X0, PUB_BACK),                      # hinter der Bücherei (später Glasanbau)
        (BR_X0, BR_BACK, BR_X1, PUB_BACK),                       # hinter dem Hinterzimmer
        (BR_X1, ROW_BACK, LEFT_X, PUB_BACK),                     # hinter Modeladen und Nachbar
    ]
    for i, (x0, z0, x1, z1) in enumerate(rects):
        if x1 - x0 < 0.05 or z1 - z0 < 0.05:
            continue
        (ax, ay), (bx, by) = G(x0, z0), G(x1, z1)
        lw = Body("Rasen %d" % i, M["lawn"], C["deco"], seed=400 + i, vary=0.1)
        lw.box(((ax + bx) / 2, (ay + by) / 2, 0.012), (abs(bx - ax) - 0.004, abs(by - ay) - 0.004, 0.024), step=1.0, dent=0.004)
        lw.build()


def ribbon(points, widths):
    """Umriss eines Bands entlang points (Godot x/z) mit Breiten je Punkt, gegen den Uhrzeigersinn (Blender)."""
    left, right = [], []
    for i, p in enumerate(points):
        a = points[max(0, i - 1)]
        b = points[min(len(points) - 1, i + 1)]
        d = (b - a).normalized()
        n = Vector((-d.y, d.x))
        left.append(p + n * widths[i] / 2)
        right.append(p - n * widths[i] / 2)
    outline = [G(p.x, p.y) for p in right] + [G(p.x, p.y) for p in reversed(left)]
    area = sum(outline[i][0] * outline[(i + 1) % len(outline)][1] - outline[(i + 1) % len(outline)][0] * outline[i][1]
               for i in range(len(outline)))
    return outline if area > 0 else list(reversed(outline))


def smooth(pts, rounds=3):
    pts = [Vector(p) for p in pts]
    for _ in range(rounds):
        sm = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            sm += [a.lerp(b, 0.25), a.lerp(b, 0.75)]
        sm.append(pts[-1])
        pts = sm
    return pts


def bridge_ends():
    """Anfang (Gartenseite) und Ende (Häuschen-Seite) der Brücke (Godot x/z) und Richtung."""
    c = Vector((BRIDGE[0], BRIDGE[1]))
    d = Vector((math.sin(math.radians(BRIDGE[2])), math.cos(math.radians(BRIDGE[2]))))
    return c - d * BRIDGE[3] / 2, c + d * BRIDGE[3] / 2, d


def gravel_path(M, C, rnd):
    """Kiesweg aus der Gasse in den Garten bis an die Brücke, jenseits davon weiter bis vor das Holzhäuschen."""
    mid = (LIB_X + FAR_X) / 2
    start, end, d = bridge_ends()
    cx, cz, cw, cd, turn = COTTAGE
    # Platz vor der Tür des Häuschens (Vorderseite zeigt zum Garten, -z gedreht um turn)
    a = math.radians(turn)
    front = Vector((cx, cz)) + Vector((-math.sin(a), -math.cos(a))) * (cd / 2 + 0.7)
    parts = [
        [Vector((mid, PUB_BACK - 0.2)), Vector((mid + 0.4, PUB_BACK + 1.6)), Vector((mid + 2.0, PUB_BACK + 3.2)),
         start - d * 1.4, start + d * 0.05],
        [end - d * 0.05, end + d * 1.2, front - (front - end).normalized() * 0.6, front],
    ]
    for k, raw in enumerate(parts):
        pts = smooth(raw)
        widths = [1.22 + 0.1 * math.sin(i * 0.9) + rnd.uniform(-0.03, 0.03) for i in range(len(pts))]
        gb = Body("Kiesweg %d" % k, M["gravel"], C["deco"], seed=410 + k, vary=0.06)
        gb.slab(ribbon(pts, widths), 0.012, Matrix.Translation((0, 0, 0.02)), dent=0.003)
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

def tunnel(M, C, name, p0, p1, a0, a1, spring, rise, rnd, depth=2.4):
    """Gewölbter Bachtunnel hinter einem Mauerbogen (entlang a0 … a1 der Mauer p0 → p1): ein Gewölbe aus Stein mit Innenseite
    (Halbkreis auf geraden Wangen), in drei Stücken nach hinten immer dunkler, ganz hinten Dunkel – man schaut hinein wie in
    einen echten Tunnel."""
    w = a1 - a0
    amid = (a0 + a1) / 2
    ri, ro = w / 2, w / 2 + 0.25
    y0 = -0.06
    outline = [(amid + ro, y0)]
    outline += [(amid + math.cos(math.pi * k / 16) * ro, spring + math.sin(math.pi * k / 16) * ro) for k in range(17)]
    outline += [(amid - ro, y0), (amid - ri, y0)]
    outline += [(amid - math.cos(math.pi * k / 16) * ri, spring + math.sin(math.pi * k / 16) * ri) for k in range(17)]
    outline += [(amid + ri, y0)]
    seg = depth / 3
    for k, key in enumerate(("tunnel_a", "tunnel_b", "tunnel_c")):
        vb = Body("%s Gewölbe %d" % (name, k), M[key], C["walls"], seed=rnd.randrange(999), vary=0.05)
        z0 = -0.3 - seg * (k + 1)
        vb.slab(outline, seg + (0.002 if k < 2 else 0.0), T.wall_matrix(p0, p1) @ Matrix.Translation((0, 0, z0)), dent=0.002)
        vb.build()
    end = Body(name + " Dunkel", M["tunnel_end"], C["walls"], seed=rnd.randrange(999), vary=0.0)
    end.box((amid, (spring + ri) / 2, -0.3 - depth - 0.05), (w + 0.1, spring + ri + 0.12, 0.1), step=1.0, dent=0.0,
            matrix=T.wall_matrix(p0, p1))
    end.build()


def garden_wall(M, C, name, p0, p1, rnd, kind="brick_c", gap=None):
    """Gartenmauer (Ziegel, Steinkrone, Feldsteinsockel), Innenseite auf der Linie p0 → p1 (Außenseite zum Garten).
    gap = (a0, a1) entlang der Mauer: dort ein Bogen über dem Bach (die Mauer steht links und rechts davon, darüber ein
    Ziegelstück mit runder Unterkante und Bogensteinen), dahinter der Tunnel."""
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
        top.slab(arc + [(a1, WALL_H), (a0, WALL_H)], 0.3, T.wall_matrix(p0, p1) @ Matrix.Translation((0, 0, -0.3)), dent=0.003)
        top.build()
        ring = Body(name + " Bogensteine", M["sandstone"], C["walls"], seed=rnd.randrange(999), vary=0.08, bevel=0.01)
        for k in range(9):
            ang0, ang1 = math.pi * k / 9, math.pi * (k + 1) / 9
            outer = 0.16
            pts = [(a0 + w / 2 - math.cos(ang0) * w / 2, spring + math.sin(ang0) * rise),
                   (a0 + w / 2 - math.cos(ang1) * w / 2, spring + math.sin(ang1) * rise),
                   (a0 + w / 2 - math.cos(ang1) * (w / 2 + outer), spring + math.sin(ang1) * (rise + outer)),
                   (a0 + w / 2 - math.cos(ang0) * (w / 2 + outer), spring + math.sin(ang0) * (rise + outer))]
            ring.slab(pts, 0.32, T.wall_matrix(p0, p1) @ Matrix.Translation((0, 0, -0.31)), dent=0.002)
        ring.build()
        tunnel(M, C, name + " Tunnel", p0, p1, a0, a1, spring, rise, rnd)
    A.plinth_run(M, C, name + " Sockel", p0, p1, rnd, z_top=0.32)


def walls(M, C, rnd):
    """Gartenmauern ringsum: rechts (hinter dem Pub-Nachbarn, mit dem Tunnel, in dem der Bach verschwindet), links (vorn der
    Tunnel, aus dem er kommt) und hinten."""
    inside = G((RIGHT_X + LEFT_X) / 2, (PUB_BACK + BACK_Z) / 2)
    walls_out = []
    for name, (x0, z0), (x1, z1), cross in (
            ("Gartenmauer rechts", (RIGHT_X, PUB_BACK), (RIGHT_X, BACK_Z), RIGHT_X),
            ("Gartenmauer links", (LEFT_X, ROW_BACK), (LEFT_X, BACK_Z), LEFT_X),
            ("Gartenmauer hinten", (RIGHT_X - 0.3, BACK_Z), (LEFT_X + 0.3, BACK_Z), None)):
        p0, p1 = facing(G(x0, z0), G(x1, z1), inside)
        gap = None
        if cross is not None:
            z = stream_z_at(cross)
            along = [abs(-zz - p0[1]) for zz in (z - STREAM_W / 2 - 0.12, z + STREAM_W / 2 + 0.12)]   # die Mauer läuft entlang z
            gap = (min(along), max(along))
        garden_wall(M, C, name, p0, p1, rnd, gap=gap)
        walls_out.append((p0, p1, gap))
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
    # Fallrohr an einem Ende, mit Schellen – nur an Häuten, die am Boden beginnen (eine Haut über dem Hinterzimmer hat keins:
    # es ginge sonst durch dessen Dach bis in den Raum)
    side = rnd.random() < 0.5
    if from_y > 0.1:
        return
    px = length - 0.25 if side else 0.25
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
    Pub und dessen Nachbar; dazu zwei Fenster oben an der Rückwand der Bücherei."""
    for i, (x0, x1, back_z, eaves) in enumerate(L["house_backs"]):
        pub = abs(x1 - FAR_X) < 0.01
        if x0 >= BR_X0 - 0.01 and x0 < BR_X1:
            # Modeladen: unten steht das Hinterzimmer davor – die Haut beginnt über dessen Dach, rechts daneben ab dem Boden
            house_skin(M, C, "Rückseite Modeladen oben", x0, BR_X1 + 0.05, back_z, eaves, rnd, wall="plaster_b", kind="plaster",
                       from_y=3.55, plinth=False)
            house_skin(M, C, "Rückseite Modeladen", BR_X1 + 0.05, x1, back_z, eaves, rnd, wall="plaster_b", kind="plaster")
        elif pub:
            # keine Hintertür: der Garten ist ganz für sich (Wunsch der Entwicklerin)
            house_skin(M, C, "Rückseite Pub", x0, x1, back_z, eaves, rnd, wall="plaster_a", kind="plaster")
        else:
            house_skin(M, C, "Rückseite Nachbar %d" % i, x0, x1, back_z, eaves, rnd, wall=("brick_a", "brick_b")[i % 2])
    # Bücherei oben: zwei Fenster mit Vorhängen auf der Ziegelwand (das Erdgeschoss bekommt später den Glasanbau)
    p0, p1 = facing(G(LIB_X, LIB_BACK + 0.005), G(-LIB_X, LIB_BACK + 0.005), G(0.0, LIB_BACK + 3.0))
    for k, x in enumerate((1.6, 4.8)):
        surface_window(M, C, "Bücherei hinten Fenster %d" % k, T.wall_matrix(p0, p1, x, 4.0, 0.0), 0.9, 1.35, rnd, curtain="curtain_b")


def back_row(M, C, rnd):
    """Hinter der hinteren Mauer: Rückseiten von Häusern der nächsten Straße – mit Lücken (dort viel Himmel und Bäume)."""
    z = BACK_Z + 2.2
    for k, (x0, x1, wall, roof, h) in enumerate(((RIGHT_X - 5.4, RIGHT_X - 0.6, "brick_b", "slate_roof", 7.0),
                                                 (RIGHT_X + 2.4, RIGHT_X + 8.0, "plaster_a", "h_roof", 6.6),
                                                 (RIGHT_X + 11.2, RIGHT_X + 16.4, "plaster_b", "slate_roof", 6.9),
                                                 (LEFT_X + 0.8, LEFT_X + 6.2, "brick_a", "h_roof", 7.4))):
        A.gable_house(M, C, "Haus hinter dem Garten %d" % (k + 1), x0, x1, z, h, wall, rnd, roof_mat=roof)


# --- Bach ---

def stream(M, C, rnd):
    """Bach: Wasser in einem Band entlang der Mittellinie (bis in die Tunnel), beide Ufer mit unregelmäßigen, teils bemoosten
    Steinen gesäumt (nicht unter der Brücke), ein paar Steine im Wasser."""
    line = stream_line()
    w = Body("Bach Wasser", M["stream"], C["deco"], seed=420, vary=0.0)
    w.slab(ribbon(line, [STREAM_W - 0.04] * len(line)), WATER_TOP, Matrix.Translation((0, 0, 0.0)), dent=0.0)
    w.build()
    stones = Body("Ufersteine", M["river_stone"], C["deco"], seed=421, vary=0.12)
    moss = Body("Ufersteine bemoost", M["moss_stone"], C["deco"], seed=423, vary=0.12)
    inside = []
    for side in (-1, 1):
        acc = 0.0
        for i in range(1, len(line)):
            a, b = line[i - 1], line[i]
            seg = (b - a).length
            d = (b - a).normalized()
            n = Vector((-d.y, d.x)) * side
            t = 0.0
            while t < seg:
                p = a + d * t
                t += rnd.uniform(0.24, 0.34)
                if not (RIGHT_X + 0.1 < p.x < LEFT_X - 0.1) or near_bridge(p, 0.2):
                    continue
                r = rnd.uniform(0.11, 0.19)
                q = p + n * (STREAM_W / 2 + rnd.uniform(-0.04, 0.03))
                px, py = G(q.x, q.y)
                (moss if rnd.random() < 0.35 else stones).blob((px, py, r * 0.35), r, subdiv=2, lump=0.18, scale=(1.0, 0.85, 0.62))
            acc += seg
        inside.append(acc)
    stones.build()
    moss.build()
    inw = Body("Steine im Bach", M["moss_stone"], C["deco"], seed=425, vary=0.12)
    for i in range(4, len(line) - 4, 7):
        p = line[i]
        if not (RIGHT_X + 1.0 < p.x < LEFT_X - 1.0) or near_bridge(p, 0.4):
            continue
        d = (line[i + 1] - line[i - 1]).normalized()
        q = p + Vector((-d.y, d.x)) * rnd.uniform(-0.3, 0.3)
        r = rnd.uniform(0.1, 0.16)
        px, py = G(q.x, q.y)
        inw.blob((px, py, r * 0.3), r, subdiv=2, lump=0.2, scale=(1.1, 0.9, 0.7))
    inw.build()


def reeds(M, C, rnd):
    """Schilf und Rohrkolben in Büscheln an beiden Ufern (nicht an der Brücke, nicht vor den Tunneln): lange Halme, die sich im
    Wind wiegen, dazwischen Rohrkolben mit braunem Kolben und dünner Spitze."""
    line = stream_line()
    GR.plant_palette(M)
    k = 0
    for i in range(6, len(line) - 6, 4):
        p = line[i]
        if not (RIGHT_X + 1.2 < p.x < LEFT_X - 1.2) or near_bridge(p, 1.0) or rnd.random() < 0.35:
            continue
        d = (line[i + 1] - line[i - 1]).normalized()
        side = rnd.choice((-1, 1))
        q = p + Vector((-d.y, d.x)) * side * (STREAM_W / 2 + rnd.uniform(0.05, 0.22))
        plant = GR.Plant(M, C["deco"], 500 + k)
        GR.grass_tuft(plant, blades=rnd.randint(18, 30), height=rnd.uniform(0.75, 1.15), mats=("grass_leaf", "leaf_lime", "grass_leaf"))
        for j in range(rnd.randint(1, 3)):
            a = rnd.uniform(0, 2 * math.pi)
            base = Vector((math.cos(a), math.sin(a), 0.0)) * rnd.uniform(0.0, 0.08)
            h = rnd.uniform(0.85, 1.25)
            top = base + Vector((rnd.uniform(-0.06, 0.06), rnd.uniform(-0.06, 0.06), h))
            plant.body("stem", vary=0.05).tube([base, base.lerp(top, 0.5), top + Vector((0, 0, 0.12))], 0.006, segs=4, smooth=1,
                                               round_ends=True)
            plant.body("cattail", vary=0.08).lathe([(0.0, 0.0), (0.016, 0.01), (0.019, 0.06), (0.016, 0.11), (0.0, 0.12)],
                                                   top - Vector((0, 0, 0.06)), segs=8)
        objs = plant.build(sway_height=1.0)
        px, py = G(q.x, q.y)
        for o in objs:
            o.data.transform(Matrix.Translation((px, py, 0.02)) @ Matrix.Rotation(rnd.uniform(0, 6.28), 4, "Z"))
            o.data.update()
        k += 1


def bridge(M, C, rnd):
    """Gewölbte Holzbrücke über den Bach: an beiden Enden ein Widerlager aus Stein, darauf zwei gebogene Tragbalken, quer die
    Bohlen, beidseitig ein Geländer (Pfosten auf den Balken, Handlauf und Mittelholm folgen dem Bogen)."""
    cx, cz, turn, length, width, rise = BRIDGE
    a = math.radians(turn)
    d = Vector((math.sin(a), math.cos(a)))
    n = Vector((d.y, -d.x))
    # Blender: Richtung entlang (x, -z), quer, oben
    db = Vector((d.x, -d.y, 0.0))
    nb = Vector((n.x, -n.y, 0.0))
    up = Vector((0, 0, 1))
    c = Vector((cx, -cz, 0.0))

    def at(t, side=0.0, h=0.0):
        """Punkt auf dem Bogen: t von -1 (Anfang) bis 1 (Ende), side quer (m), h über der Lauffläche."""
        y = rise * (1 - t * t) + 0.1   # die Enden liegen auf den Widerlagern
        return c + db * (t * length / 2) + nb * side + up * (y + h)

    def slope(t):
        return math.atan2(-2 * rise * t, length / 2)
    wood = Body("Brücke Holz", M["h_join"], C["deco"], seed=600, vary=0.06, bevel=0.004)
    n_planks = 18
    for i in range(n_planks):
        t = -1 + (2 * i + 1) / n_planks
        p = at(t, 0.0, -0.02)
        ang = slope(t)
        fwd = (db * math.cos(ang) + up * math.sin(ang)).normalized()
        upv = nb.cross(fwd).normalized()
        if upv.z < 0:
            upv = -upv
        m = Matrix((nb, fwd, upv)).transposed().to_4x4()
        m.translation = p
        wood.box((0, 0, 0), (width, length / n_planks - 0.012, 0.04), step=1.0, dent=0.0008, matrix=m)
    for side in (-1, 1):
        sx = side * (width / 2 - 0.08)
        pts = [at(-1 + 2 * k / 12, sx, -0.1) for k in range(13)]
        for p0, p1 in zip(pts, pts[1:]):
            wood.span(p0, p1, 0.08, 0.12, step=0.4, dent=0.0006)
        rx = side * (width / 2 - 0.04)
        posts = [-0.92, -0.46, 0.0, 0.46, 0.92]
        for t in posts:
            base = at(t, rx, -0.04)
            wood.box(base + up * 0.42, (0.07, 0.07, 0.86), step=0.5, dent=0.0006)
        rail = [at(t, rx, 0.84) for t in [-0.92 + 1.84 * k / 10 for k in range(11)]]
        mid = [at(t, rx, 0.45) for t in [-0.92 + 1.84 * k / 10 for k in range(11)]]
        wood.tube(rail, 0.035, segs=8, smooth=1, round_ends=True)
        wood.tube(mid, 0.022, segs=6, smooth=1, round_ends=True)
    wood.build()
    st = Body("Brücke Widerlager", M["stone"], C["deco"], seed=601, vary=0.1, bevel=0.02)
    for t in (-1, 1):
        p = c + db * (t * (length / 2 - 0.05))
        m = Matrix((nb, db, up)).transposed().to_4x4()
        m.translation = p + up * 0.035
        st.box((0, 0, 0), (width + 0.3, 0.5, 0.07), step=0.5, dent=0.004, matrix=m)
    st.build()


# --- Ganzes Modell ---

def backyard(M, C, rnd):
    lawn(M, C)
    gravel_path(M, C, rnd)
    stepping_stones(M, C, rnd)
    garden_walls = walls(M, C, rnd)
    house_backs(M, C, rnd)
    back_row(M, C, rnd)
    stream(M, C, rnd)
    reeds(M, C, rnd)
    bridge(M, C, rnd)
    tx, tz = L["garden_tree"]
    obstacles = A.round_bench(M, C, tx, tz, rnd) + A.bird_bath(M, C, A.BIRD_BATH[0], A.BIRD_BATH[1], rnd)
    spots = []
    p = G(tx, tz)
    spots.append(("tree", (p[0], p[1], 0.0), (5.6, 7.4, 10.0), 0.0, "garden"))
    # Bäume hinter den Mauern (die Natur kommt mehr heraus; Gartenbäume aus der Pflanzen-Bibliothek)
    for x, z in ((RIGHT_X - 2.6, PUB_BACK + 4.5), (RIGHT_X - 3.0, BACK_Z - 3.0), (RIGHT_X + 0.9, BACK_Z + 2.4),
                 (RIGHT_X + 9.6, BACK_Z + 2.2), (LEFT_X - 0.6, BACK_Z + 2.6), (LEFT_X + 2.8, BACK_Z - 5.0), (LEFT_X + 2.6, PUB_BACK + 6.0)):
        q = G(x, z)
        spots.append(("tree", (q[0], q[1], 0.0), (4.6, 4.6, 8.0), 0.0))
    # Beete an den Mauern (die Pflanzen setzt Greenery ein): rechts vor dem Tunnel, hinten links und rechts vom Häuschen
    zr = stream_z_at(RIGHT_X)
    for (x0, z0, x1, z1, face) in (
            (RIGHT_X + 0.25, PUB_BACK + 0.6, RIGHT_X + 0.85, zr - STREAM_W - 0.6, 90.0),
            (RIGHT_X + 1.0, BACK_Z - 0.85, COTTAGE[0] - 4.2, BACK_Z - 0.25, 180.0),
            (LEFT_X - 0.85, stream_z_at(LEFT_X) + STREAM_W + 0.8, LEFT_X - 0.25, COTTAGE[1] - 2.8, -90.0)):
        (ax, ay), (bx, by) = G(x0, z0), G(x1, z1)
        spots.append(("bed", ((ax + bx) / 2, (ay + by) / 2, 0.02), (max(abs(bx - ax), abs(by - ay)), min(abs(bx - ax), abs(by - ay)), 1.0),
                      face))
    # Efeu wächst an den Gartenmauern (nicht über den Tunnelbögen)
    for (p0, p1, gap) in garden_walls:
        length = T.seg_len(p0, p1)
        blocks = [((gap[0] + gap[1]) / 2, 0.0, gap[1] - gap[0] + 1.2, WALL_H)] if gap else []
        for along in (0.3, 0.72):
            place = A.climber_place([], length, length * along, 1.0, 2.2, blocks)
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
