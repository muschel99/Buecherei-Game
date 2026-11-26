"""Kleiner Park hinter dem Torhaus (Testrunde nach Etappe 8d, Wunsch der Entwicklerin: „in der Stadt ist kein Platz für Bäume –
hinter dem Torhaus ein oder zwei Häuser durch einen kleinen Park ersetzen“).

Wo vorher Häuser standen (GameConfig.street_parks, Lage aus layout.json „street_parks“), liegt jetzt ein kleiner Stadtpark: zur
Straße eine niedrige Sandsteinmauer mit Eisengitter und einem offenen Tor in der Mitte, dahinter Rasen, ein Kiesweg zu einem
runden Platz mit Parkbank und Laterne, Beete am Gitter und an der Mauer, Bäume (Pflanzplätze, sparsame Bäume „far“ – man sieht
den Park nur von Weitem durch den Torbogen). Links und rechts begrenzen ihn die Seitenwände der Nachbarhäuser (sie bekommen beim
Neubau mit build_storybook_street.py von selbst Fenster), hinten eine Backsteinmauer mit Efeu. Man kommt nicht hinein (der
Torbogen ist die Grenze), darum hat der Park keine Kollision.

Aufruf (Terminal, im Projektordner):
    godot --headless --path . res://scenes/tools/export_layout.tscn      (Lage der Plätze aus dem Spiel)
    blender -b --factory-startup --python tools/blender/build_storybook_park.py [-- --force]

Ergebnis (Koordinaten wie unter "Outside" im Spiel, y = 0 = Gehweg; Blender: x, -z, y):
    assets/models/world/gate_park.glb           Modell (steht in scenes/world/gate_park.tscn, die Hauptszene setzt es ein)
    assets/models/source/gate_park_storybook.blend
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_storybook_alleys as A  # noqa: E402
import build_storybook_backyard as BY  # noqa: E402
import build_storybook_lamps as LP  # noqa: E402
import build_storybook_props as PR  # noqa: E402
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

L = A.LAYOUT
G = A.G
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "gate_park_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "gate_park_storybook.stamp")

GATE_WIDTH = 1.3          # Toröffnung in der Mitte der Straßenseite
WALL_HEIGHT = 0.44        # niedrige Mauer unter dem Gitter
WALL_DEPTH = 0.28
RAIL_TOP = 1.3            # Oberkante des Gitters
BACK_WALL_HEIGHT = 2.6    # Mauer hinten (wie die Gartenmauern)
GATE_PILLAR = 0.42        # Torpfeiler (quadratisch)
END_PILLAR = 0.36         # Eckpfeiler an den Nachbarhäusern


# --- Lage ---

def lot_axes(r):
    """Achsen eines Platzes (Godot x/z): x entlang der Front, z nach vorn (zur Straße) – wie Basis(UP, Drehung) im Spiel."""
    yaw = r[3]
    return Vector((math.cos(yaw), -math.sin(yaw))), Vector((math.sin(yaw), math.cos(yaw)))


def lot_corner(r, side, back):
    """Ecke eines Platzes (Godot x/z): side -1/1 = Seite, back 0 = vorn, 1 = hinten."""
    xa, za = lot_axes(r)
    return Vector((r[1], r[2])) + xa * side * r[4] / 2 - za * back * r[5]


def facing_side(r, other):
    """Welche Seite des Platzes r (-1/1) zum Platz other zeigt."""
    o = Vector((other[1], other[2]))
    return min((-1, 1), key=lambda s: (lot_corner(r, s, 0.0) - o).length)


def park_shape():
    """Umriss des Parks (Godot x/z): Front (Punkte von links nach rechts, an den Ecken der Nachbarhäuser beginnend), hinten
    links und rechts (die hinteren Ecken der Nachbarn auf der Parkseite), Mitte des Tors und die Richtung zur Straße."""
    lots = L["street_parks"]
    idx = [i for i, r in enumerate(lots) if r[6]]
    left_n, right_n = lots[idx[0] - 1], lots[idx[-1] + 1]
    parks = [lots[i] for i in idx]
    sl, sr = facing_side(left_n, parks[0]), facing_side(right_n, parks[-1])
    front = [lot_corner(left_n, sl, 0.0)]
    for a, b in zip(parks, parks[1:]):
        front.append((lot_corner(a, facing_side(a, b), 0.0) + lot_corner(b, facing_side(b, a), 0.0)) / 2)
    front.append(lot_corner(right_n, sr, 0.0))
    back_l, back_r = lot_corner(left_n, sl, 1.0), lot_corner(right_n, sr, 1.0)
    # Tor: in der Mitte der Front (bei zwei Plätzen genau zwischen ihnen)
    gate = front[len(front) // 2] if len(front) % 2 == 1 else (front[len(front) // 2 - 1] + front[len(front) // 2]) / 2
    street = sum((lot_axes(r)[1] for r in parks), Vector((0.0, 0.0))).normalized()
    return front, back_l, back_r, gate, street


def ccw(outline):
    area = sum(outline[i][0] * outline[(i + 1) % len(outline)][1] - outline[(i + 1) % len(outline)][0] * outline[i][1]
               for i in range(len(outline)))
    return outline if area > 0 else list(reversed(outline))


def bv(p):
    """Godot x/z → Blender (x, y)."""
    return Vector(G(p.x, p.y))


# --- Teile ---

def front_wall(M, C, name, a, b, street, rnd):
    """Niedrige Sandsteinmauer mit Abdeckplatte und Eisengitter (Stäbe mit Spitzen, zwei Riegel) von a nach b (Godot x/z);
    die Mauer steht mit ihrer Vorderseite auf der Linie, das Gitter in der Mitte der Mauer."""
    p0, p1 = BY.facing(bv(a), bv(b), bv((a + b) / 2 + street * 3.0))
    length = T.seg_len(p0, p1)
    fm = T.wall_matrix(p0, p1)
    wl = Body(name, M["sandstone"], C["walls"], seed=rnd.randrange(999), vary=0.05, bevel=0.015)
    wl.box((length / 2, WALL_HEIGHT / 2, -WALL_DEPTH / 2), (length, WALL_HEIGHT, WALL_DEPTH), step=0.5, dent=0.004, matrix=fm)
    wl.build()
    cap = Body(name + " Abdeckung", M["stone"], C["walls"], seed=rnd.randrange(999), vary=0.06, bevel=0.012)
    cap.box((length / 2, WALL_HEIGHT + 0.03, -WALL_DEPTH / 2), (length + 0.02, 0.06, WALL_DEPTH + 0.06), step=0.5, dent=0.003,
            matrix=fm)
    cap.build()
    rail = Body(name + " Gitter", M["lamp_iron"], C["deco"], seed=rnd.randrange(999), vary=0.03)
    mid = -WALL_DEPTH / 2
    base = WALL_HEIGHT + 0.06
    for y in (base + 0.12, RAIL_TOP - 0.1):
        rail.box((length / 2, y, mid), (length - 0.1, 0.035, 0.03), step=0.6, dent=0.0, matrix=fm)
    n = max(2, int((length - 0.16) / 0.13))
    for k in range(n + 1):
        x = 0.08 + (length - 0.16) * k / n
        rail.box((x, (base + RAIL_TOP) / 2 - 0.01, mid), (0.022, RAIL_TOP - base + 0.02, 0.022), step=1.0, dent=0.0, matrix=fm)
        tip = fm @ Vector((x, RAIL_TOP, mid))
        rail.lathe([(0.0, 0.0), (0.016, 0.0), (0.024, 0.03), (0.012, 0.06), (0.0, 0.085)], (tip.x, tip.y, tip.z - 0.01), segs=6,
                   dent=0.0)
    rail.build()


def pillar(M, C, name, p, rnd, height=1.5, size=0.42):
    """Torpfeiler aus Sandstein mit Abdeckplatte und Kugel (p = Mitte unten, Blender)."""
    pl = Body(name, M["sandstone"], C["walls"], seed=rnd.randrange(999), vary=0.05, bevel=0.02)
    pl.box((p.x, p.y, height / 2), (size, size, height), step=0.5, dent=0.004)
    pl.build()
    cp = Body(name + " Abdeckung", M["stone"], C["walls"], seed=rnd.randrange(999), vary=0.06, bevel=0.015)
    cp.box((p.x, p.y, height + 0.04), (size + 0.08, size + 0.08, 0.08), step=0.5, dent=0.003)
    cp.lathe([(0.0, 0.0), (0.07, 0.0), (0.05, 0.05), (0.11, 0.13), (0.12, 0.2), (0.09, 0.28), (0.0, 0.31)], (p.x, p.y, height + 0.08),
             segs=16, dent=0.002)
    cp.build()


def gate_leaf(M, C, name, hinge, along, to_pillar, width, rnd):
    """Offener Torflügel aus Eisen (hinge = Angel unten, Blender; along = Richtung des Flügels, schon aufgeschwenkt), mit zwei
    Angeln in den Pfeiler (to_pillar = Richtung zur Pfeilerwand, Abstand 3 cm)."""
    gl = Body(name, M["lamp_iron"], C["deco"], seed=rnd.randrange(999), vary=0.03)
    h0 = Vector((hinge.x, hinge.y, 0.0))
    d = Vector((along.x, along.y, 0.0)).normalized()
    tp = Vector((to_pillar.x, to_pillar.y, 0.0)).normalized()
    for z in (0.3, 1.15):
        gl.tube([h0 + Vector((0, 0, z)), h0 + tp * 0.07 + Vector((0, 0, z))], 0.014, segs=6, round_ends=True)
        gl.tube([h0 + Vector((0, 0, z - 0.06)), h0 + Vector((0, 0, z + 0.06))], 0.02, segs=8, round_ends=True)
    for z in (0.12, 0.62, 1.32):
        gl.tube([h0 + Vector((0, 0, z)), h0 + d * width + Vector((0, 0, z))], 0.016, segs=6, round_ends=True)
    n = max(2, int(width / 0.12))
    for k in range(n + 1):
        q = h0 + d * (0.02 + (width - 0.04) * k / n)
        gl.tube([q + Vector((0, 0, 0.05)), q + Vector((0, 0, 1.38))], 0.011, segs=6, round_ends=True)
        if 0 < k < n:
            gl.lathe([(0.0, 0.0), (0.014, 0.0), (0.02, 0.025), (0.01, 0.05), (0.0, 0.07)], (q.x, q.y, 1.37), segs=6, dent=0.0)
    gl.build()


# --- Park ---

def park(M, C, rnd):
    front, back_l, back_r, gate, street = park_shape()
    inward = -street
    spots = []
    # Rasen über den ganzen Platz (bis an die Mauern und Seitenwände der Nachbarn)
    outline = ccw([G(p.x, p.y) for p in front + [back_r, back_l]])
    lw = Body("Rasen Park", M["lawn"], C["deco"], seed=600, vary=0.1)
    lw.slab(outline, 0.024, Matrix.Identity(4), dent=0.003)
    lw.build()
    # Straßenseite: Mauer mit Gitter zwischen Pfeilern – an den Nachbarhäusern je ein Eckpfeiler (2 cm Luft zur Hauswand), in
    # der Mitte das Tor (Öffnung GATE_WIDTH zwischen den Torpfeilern). Bei zwei Plätzen liegt das Tor genau an ihrer Nahtstelle.
    k = len(front) // 2
    assert len(front) % 2 == 1, "Park über eine gerade Zahl von Abschnitten: Tor an der Nahtstelle erwartet"
    j = front[k]
    to_l, to_r = (front[k - 1] - j).normalized(), (front[k + 1] - j).normalized()
    gate_l, gate_r = j + to_l * GATE_WIDTH / 2, j + to_r * GATE_WIDTH / 2
    u0 = (front[1] - front[0]).normalized()
    u1 = (front[-2] - front[-1]).normalized()
    end_l, end_r = front[0] + u0 * (0.02 + END_PILLAR), front[-1] + u1 * (0.02 + END_PILLAR)
    pieces = []
    left_pts = [end_l] + front[1:k] + [gate_l + to_l * GATE_PILLAR]
    right_pts = [gate_r + to_r * GATE_PILLAR] + front[k + 1:-1] + [end_r]
    for pts in (left_pts, right_pts):
        pieces += list(zip(pts, pts[1:]))
    for i, (a, b) in enumerate(pieces):
        front_wall(M, C, "Parkmauer vorn %d" % i, a, b, street, rnd)
    # Torpfeiler (Innenseite an der Öffnung) und offene Flügel (75° in den Park geschwenkt)
    for n_, (p, out) in enumerate(((gate_l, to_l), (gate_r, to_r))):
        across = -out
        pillar(M, C, "Torpfeiler %d" % n_, bv(p + out * GATE_PILLAR / 2 + inward * (WALL_DEPTH / 2)), rnd, size=GATE_PILLAR)
        hinge = p + across * 0.03 + inward * (WALL_DEPTH / 2)
        swing = (across * math.cos(math.radians(75)) + inward * math.sin(math.radians(75))).normalized()
        gate_leaf(M, C, "Torflügel %d" % n_, bv(hinge), Vector(G(swing.x, swing.y)) - Vector(G(0.0, 0.0)),
                  Vector(G(out.x, out.y)) - Vector(G(0.0, 0.0)), GATE_WIDTH / 2 - 0.05, rnd)
    # Eckpfeiler an den Nachbarhäusern
    for n_, (p, u) in enumerate(((front[0], u0), (front[-1], u1))):
        pillar(M, C, "Eckpfeiler %d" % n_, bv(p + u * (0.02 + END_PILLAR / 2) + inward * (WALL_DEPTH / 2)), rnd, height=1.4,
               size=END_PILLAR)
    # Mauer hinten mit Efeu (wie die Gartenmauern), etwas kürzer als der Abstand der Hausecken
    d = (back_r - back_l).normalized()
    wa, wb = back_l + d * 0.06, back_r - d * 0.06
    center = (sum(front, Vector((0.0, 0.0))) / len(front) + (back_l + back_r) / 2) / 2
    p0, p1 = BY.facing(bv(wa), bv(wb), bv(center))
    BY.garden_wall(M, C, "Parkmauer hinten", p0, p1, rnd, kind="brick_b")
    length = T.seg_len(p0, p1)
    for along in (0.25, 0.7):
        place = A.climber_place([], length, length * along, 1.2, 2.2)
        if place:
            A.alley_ivy(M, C, p0, p1, [], [place[0]], rnd, height=BACK_WALL_HEIGHT - 0.2)
    # Kiesweg vom Tor zu einem runden Platz vor der hinteren Mauer
    back_mid = (back_l + back_r) / 2
    plaza = back_mid + (j - back_mid).normalized() * 2.0
    entry = j + inward * (WALL_DEPTH + 0.05)
    pts = BY.smooth([j + inward * 0.02, entry + inward * 0.6, entry.lerp(plaza, 0.6) + d * 0.25, plaza])
    widths = [1.05 + 0.08 * math.sin(i * 0.8) + rnd.uniform(-0.02, 0.02) for i in range(len(pts))]
    gb = Body("Kiesweg Park", M["gravel"], C["deco"], seed=610, vary=0.06)
    gb.slab(BY.ribbon(pts, widths), 0.012, Matrix.Translation((0, 0, 0.02)), dent=0.003)
    pc = bv(plaza)
    disc = [(pc.x + math.cos(2 * math.pi * i / 28) * 1.35, pc.y + math.sin(2 * math.pi * i / 28) * 1.35) for i in range(28)]
    gb.slab(ccw(disc), 0.012, Matrix.Translation((0, 0, 0.0201)), dent=0.003)
    gb.build()
    # Parkbank am Platz (Rücken zur Mauer, Blick zum Tor) und Laterne daneben
    look = (j - plaza).normalized()
    f = Vector(G(look.x, look.y)) - Vector(G(0.0, 0.0))
    turn = math.atan2(f.y, f.x) + math.pi / 2
    T.placed(C["deco"], Matrix.Translation((*bv(plaza - look * 0.75), 0.0)) @ Matrix.Rotation(turn, 4, "Z"), PR.street_bench, M,
             C["deco"])
    T.placed(C["deco"], Matrix.Translation((*bv(plaza - look * 0.55 + d * 1.25), 0.0)) @ Matrix.Rotation(turn, 4, "Z"),
             LP.street_lamp, M, C["deco"])

    # Pflanzen: Beete hinter dem Gitter und an der hinteren Mauer, drei Bäume (hinten links, hinten rechts, vorn rechts)
    def bed(p_a, p_b, depth, into, offset):
        a2, b2 = bv(p_a), bv(p_b)
        n = (Vector(G(into.x, into.y)) - Vector(G(0.0, 0.0))).normalized()
        face = math.degrees(math.atan2(n.y, n.x)) + 90.0
        m = (a2 + b2) / 2 + n * (offset + depth / 2)
        spots.append(("bed", (m.x, m.y, 0.02), ((b2 - a2).length, depth, 0.9), face, "garden"))
    for (a, b) in pieces:
        if (b - a).length > 1.3:
            u = (b - a).normalized()
            bed(a + u * 0.3, b - u * 0.3, 0.65, inward, WALL_DEPTH + 0.04)
    perp = Vector((-d.y, d.x))
    if perp.dot(center - wa) < 0:
        perp = -perp
    bed(wa + d * 0.6, wa + d * (length * 0.36), 0.8, perp, 0.14)
    bed(wb - d * (length * 0.36), wb - d * 0.6, 0.8, perp, 0.14)
    for p, h in ((back_l.lerp(front[0], 0.35) + d * 2.1, 8.0), (back_r.lerp(front[-1], 0.38) - d * 2.1, 7.5),
                 (front[-1].lerp(back_r, 0.32) - d * 2.2, 6.5)):
        q = bv(p)
        spots.append(("tree", (q.x, q.y, 0.0), (4.6, 4.6, h), 0.0, "far"))
    return spots


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("gate_park_storybook.blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    A.mats(M)
    BY.mats(M)
    rnd = random.Random(909)
    C = A.collections("Park")
    SC.SPOTS["coll"] = C["plants"]
    spots = park(M, C, rnd)
    A.export(C, "gate_park", None, spots)
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
