"""Wiederverwendbare Bauteile im Stil (seit Etappe 4g, Teil 1b): Pflanzen, Blumenkästen,
Hängekorb, Ausleger-Schild, Kreidetafel. Alles in Godot-Koordinaten (siehe style_lib.py)."""

import math
import random

import style_lib as S
from style_lib import Mat, V

POT = Mat("terracotta")
SOIL = Mat("plain", color=(0.2, 0.15, 0.11))
IRON = Mat("metal")
GOLD = Mat("gold")
TIMBER = Mat("timber")
ZINC = Mat("plain", color=(0.62, 0.64, 0.63))
CHALK = Mat("plain", color=(0.92, 0.91, 0.86))
SLATE_BOARD = Mat("plain", color=(0.13, 0.14, 0.13))
MOSS = Mat("foliage", color=(0.36, 0.38, 0.22))

# Blüten (sRGB): Geranien, Petunien, Lobelien, Margeriten – eher sanft als knallig
BLOSSOMS = {
    "rose": [(0.86, 0.45, 0.55), (0.92, 0.62, 0.68), (0.78, 0.36, 0.45)],
    "white": [(0.95, 0.94, 0.9), (0.93, 0.9, 0.82)],
    "lavender": [(0.62, 0.55, 0.8), (0.72, 0.66, 0.86)],
    "coral": [(0.92, 0.5, 0.4), (0.95, 0.62, 0.5)],
    "hydrangea": [(0.66, 0.72, 0.88), (0.74, 0.68, 0.86), (0.82, 0.74, 0.88)],
}
LEAF_GREENS = [(0.3, 0.42, 0.2), (0.24, 0.36, 0.17), (0.34, 0.46, 0.24)]


def leaf(color_index=0):
    return Mat("foliage", color=LEAF_GREENS[color_index % len(LEAF_GREENS)])


def blossom_cluster(b, center, radius, palette, rnd, count=6, size=0.035):
    """Kleine Blüten (Kügelchen) verstreut auf einer Halbkugel."""
    colors = BLOSSOMS[palette]
    c = V(*center)
    for _ in range(count):
        a = rnd.uniform(0, 2 * math.pi)
        up = rnd.uniform(0.15, 1.0)
        d = V(math.cos(a) * math.sqrt(1 - up * up), up, math.sin(a) * math.sqrt(1 - up * up))
        p = c + d * radius
        b.sphere(p, size * rnd.uniform(0.8, 1.2), Mat("plain", color=rnd.choice(colors)), rings=3, segments=6, squash=0.7)


def trailing_strand(b, start, length, rnd, color_index=1, palette=None):
    """Hängende Ranke (Efeu, Hängepetunie): leicht schwingende Röhre mit Blättchen."""
    pts = []
    x, y, z = start
    sway = rnd.uniform(-0.04, 0.04)
    for k in range(7):
        t = k / 6
        pts.append(V(x + math.sin(t * 2.4) * sway, y - t * length, z + t * 0.05 + 0.02 * math.sin(t * 5)))
    b.tube(pts, 0.007, leaf(color_index), segments=4)
    for k in range(1, 7):
        p = pts[k]
        b.sphere(p + V(rnd.uniform(-0.02, 0.02), 0, 0.012), rnd.uniform(0.022, 0.032), leaf(color_index),
                 rings=3, segments=5, squash=0.6)
    if palette:
        b.sphere(pts[-1] + V(0, -0.01, 0.01), 0.03, Mat("plain", color=rnd.choice(BLOSSOMS[palette])), rings=3, segments=6)


def flower_box(b, x0, x1, y, z_back, z_front, box_mat, palettes, seed):
    """Blumenkasten (unten bei y, von z_back bis z_front) mit Polstern, Blüten und Ranken."""
    rnd = random.Random(seed)
    h = 0.17
    b.box((x0, y, z_back), (x1, y + h, z_front), box_mat, skip=("back",))
    b.box((x0 - 0.015, y + h - 0.025, z_front), (x1 + 0.015, y + h, z_front + 0.015), box_mat, skip=("back",))
    b.box((x0 + 0.01, y + h - 0.03, z_back + 0.01), (x1 - 0.01, y + h - 0.01, z_front - 0.01), SOIL, skip=("bottom", "back"))
    for cx in (x0 + 0.1, x1 - 0.1):
        b.box((cx - 0.02, y - 0.12, z_back), (cx + 0.02, y, z_back + 0.1), IRON, skip=("back",))
    n = max(3, int((x1 - x0) / 0.16))
    for k in range(n):
        cx = x0 + (x1 - x0) * (k + 0.5) / n + rnd.uniform(-0.03, 0.03)
        cz = (z_back + z_front) / 2 + rnd.uniform(-0.02, 0.03)
        r = rnd.uniform(0.09, 0.12)
        b.sphere(V(cx, y + h + r * 0.35, cz), r, leaf(k), rings=4, segments=8, squash=0.75, jitter=0.12, seed=seed * 7 + k)
        blossom_cluster(b, (cx, y + h + r * 0.4, cz), r * 0.95, palettes[k % len(palettes)], rnd, count=7)
    for k in range(int((x1 - x0) / 0.22) + 1):
        sx = x0 + 0.06 + (x1 - x0 - 0.12) * rnd.random()
        trailing_strand(b, (sx, y + h, z_front + 0.01), rnd.uniform(0.2, 0.4), rnd,
                        palette=palettes[k % len(palettes)] if rnd.random() < 0.5 else None)


def hydrangea_tub(b, x, z, seed):
    """Zinkwanne mit Hortensie (links vom Eingang)."""
    rnd = random.Random(seed)
    b.cylinder(V(x, 0, z), 0.24, 0.42, ZINC, segments=16, radius_top=0.27, caps=(False, False))
    b.cylinder(V(x, 0.4, z), 0.285, 0.04, ZINC, segments=16, caps=(False, True))
    b.cylinder(V(x, 0.37, z), 0.26, 0.04, SOIL, segments=16)
    for y in (0.08, 0.3):
        b.tube([V(x + 0.255 * math.cos(a), y, z + 0.255 * math.sin(a)) for a in [2 * math.pi * k / 16 for k in range(17)]],
               0.01, ZINC, segments=4, caps=False)
    for side in (-1, 1):
        b.tube([V(x + side * 0.27, 0.3, z), V(x + side * 0.31, 0.33, z), V(x + side * 0.31, 0.37, z), V(x + side * 0.28, 0.39, z)],
               0.012, ZINC, segments=5)
    b.sphere(V(x, 0.62, z), 0.3, leaf(1), rings=6, segments=12, squash=0.75, jitter=0.1, seed=seed)
    for k in range(9):
        a = 2 * math.pi * k / 9 + rnd.uniform(-0.2, 0.2)
        up = rnd.uniform(0.25, 0.85)
        d = V(math.cos(a) * math.sqrt(1 - up * up), up, math.sin(a) * math.sqrt(1 - up * up))
        p = V(x, 0.62, z) + V(d.x * 0.3, d.y * 0.24, d.z * 0.3)
        color = rnd.choice(BLOSSOMS["hydrangea"])
        b.sphere(p, rnd.uniform(0.085, 0.11), Mat("foliage", color=color), rings=5, segments=9, jitter=0.12, seed=seed + k)
    b.colliders.append(((x - 0.3, 0, z - 0.3), (x + 0.3, 0.9, z + 0.3)))


def olive_tree(b, x, z, seed):
    """Hoher Terrakotta-Topf mit kleinem Olivenbäumchen (rechts vom Eingang)."""
    rnd = random.Random(seed)
    b.cylinder(V(x, 0, z), 0.17, 0.5, POT, segments=14, radius_top=0.22, caps=(False, False))
    b.cylinder(V(x, 0.5, z), 0.235, 0.06, POT, segments=14, caps=(False, True))
    b.cylinder(V(x, 0.47, z), 0.205, 0.05, SOIL, segments=14)
    b.cylinder(V(x, 0.1, z), 0.19, 0.03, POT, segments=14, caps=(False, False))
    trunk = [V(x, 0.5, z), V(x + 0.02, 0.75, z + 0.01), V(x - 0.03, 1.0, z), V(x + 0.01, 1.2, z - 0.02)]
    b.tube(trunk, lambda t: 0.035 - 0.015 * t, Mat("timber"), segments=6)
    silver = Mat("foliage", color=(0.5, 0.56, 0.42))
    silver2 = Mat("foliage", color=(0.42, 0.5, 0.36))
    for k, (dx, dy, dz, r) in enumerate([(0, 1.38, 0, 0.2), (-0.16, 1.28, 0.06, 0.15), (0.15, 1.3, -0.04, 0.16),
                                         (0.05, 1.5, 0.08, 0.14), (-0.08, 1.48, -0.1, 0.14)]):
        b.sphere(V(x + dx, dy, z + dz), r, silver if k % 2 == 0 else silver2, rings=5, segments=10, jitter=0.18,
                 seed=seed * 3 + k)
    for dx, dz in ((-0.1, 0.04), (0.1, -0.03)):
        b.tube([V(x, 1.15, z), V(x + dx, 1.28, z + dz)], 0.012, Mat("timber"), segments=4)
    b.colliders.append(((x - 0.24, 0, z - 0.24), (x + 0.24, 1.0, z + 0.24)))


def chalkboard(b, x, z, lines, seed, facing=0.0):
    """Klapp-Kreidetafel (A-Aufsteller) mit Schrift auf der Vorderseite."""
    b.push(b.move(x, 0, z) @ b.turn_y(facing))
    w, h = 0.5, 0.8
    lean = math.radians(12)
    for side in (1, -1):
        b.push(b.turn_y(0 if side > 0 else 180) @ S.Matrix.Translation((0, 0, 0.0)) @ S.Matrix.Rotation(-lean, 4, "X"))
        # Rahmen und Tafel (leicht nach hinten geneigt, Fuß vorn)
        b.box((-w / 2, 0, 0.17), (w / 2, h, 0.2), TIMBER)
        b.box((-w / 2 + 0.04, 0.05, 0.2), (w / 2 - 0.04, h - 0.05, 0.205), SLATE_BOARD, skip=("back",))
        if side > 0:
            y = h - 0.2
            for k, line in enumerate(lines):
                b.playful_text(line, 0.0, y, 0.205, 0.075 if k else 0.06, 0.002, CHALK, seed=seed + k, bounce=0.05,
                               tilt=4, font_path=S.PLAYFUL_FONT)
                y -= 0.13
        b.pop()
    b.pop()
    b.colliders.append(((x - 0.3, 0, z - 0.3), (x + 0.3, 0.85, z + 0.3)))


def hanging_basket(b, x, y_bracket, z_wall, reach, seed):
    """Hängekorb an einem schmiedeeisernen Arm (von der Wand bei z_wall nach vorn)."""
    rnd = random.Random(seed)
    zb = z_wall + reach
    b.tube([V(x, y_bracket, z_wall), V(x, y_bracket, zb + 0.05)], 0.016, IRON, segments=6)
    b.tube([V(x, y_bracket - 0.35, z_wall), V(x, y_bracket - 0.12, z_wall + reach * 0.5), V(x, y_bracket - 0.01, zb - 0.05)],
           0.012, IRON, segments=5)
    _scroll(b, x, y_bracket - 0.12, z_wall + 0.16, 0.08, axis_plane="yz")
    b.box((x - 0.04, y_bracket - 0.4, z_wall), (x + 0.04, y_bracket + 0.05, z_wall + 0.02), IRON)
    top = y_bracket - 0.4
    for a in (0, 2.1, 4.2):
        b.tube([V(x, y_bracket - 0.02, zb), V(x + 0.17 * math.cos(a), top, zb + 0.17 * math.sin(a))], 0.004, IRON, segments=3, caps=False)
    b.sphere(V(x, top, zb), 0.2, MOSS, rings=5, segments=12, squash=0.6)
    b.sphere(V(x, top + 0.05, zb), 0.17, leaf(0), rings=5, segments=10, squash=0.6, jitter=0.15, seed=seed)
    blossom_cluster(b, (x, top + 0.05, zb), 0.17, "rose", rnd, count=12)
    blossom_cluster(b, (x, top + 0.04, zb), 0.17, "white", rnd, count=6)
    for k in range(6):
        a = 2 * math.pi * k / 6 + rnd.uniform(-0.3, 0.3)
        trailing_strand(b, (x + 0.17 * math.cos(a), top, zb + 0.17 * math.sin(a)), rnd.uniform(0.15, 0.3), rnd,
                        palette="rose" if k % 2 else "lavender")


def _scroll(b, x, y, z, radius, axis_plane="yz", turns=1.6, mat=None):
    """Kleine Schnecke (Spirale) aus Rundeisen, in der Ebene x = konstant."""
    pts = []
    for k in range(25):
        t = k / 24
        a = t * turns * 2 * math.pi
        r = radius * (1 - 0.8 * t)
        pts.append(V(x, y + r * math.sin(a), z + r * math.cos(a)))
    b.tube(pts, 0.009, mat or IRON, segments=4)


def thread_spiral(b, start, radius, turns, mat, plane_z, thickness=0.01, direction=1):
    """Faden-Kringel in der Fassadenebene (z = plane_z), beginnt bei start (x, y)."""
    pts = []
    sx, sy = start
    n = int(turns * 24)
    for k in range(n + 1):
        t = k / n
        a = direction * t * turns * 2 * math.pi
        r = radius * (0.25 + 0.75 * (1 - t))
        pts.append(V(sx + r * math.sin(a) * direction, sy + radius - r * math.cos(a), plane_z))
    b.tube(pts, thickness, mat, segments=5)
    return pts


def projecting_sign(b, x, y_bracket, z_wall, board_mat, accent_mat, seed):
    """Ausleger-Schild quer zur Fassade (Ebene x = konstant): Schmiedeeisen-Arm mit Schnecke,
    Holzschild mit Goldrand, darauf eine Garnrolle mit Nadel und Faden (beidseitig)."""
    reach = 0.95
    b.box((x - 0.05, y_bracket - 0.5, z_wall), (x + 0.05, y_bracket + 0.06, z_wall + 0.025), IRON)
    b.tube([V(x, y_bracket, z_wall), V(x, y_bracket, z_wall + reach)], 0.018, IRON, segments=6)
    b.sphere(V(x, y_bracket, z_wall + reach + 0.01), 0.03, GOLD, rings=4, segments=8)
    b.tube([V(x, y_bracket - 0.45, z_wall + 0.02), V(x, y_bracket - 0.18, z_wall + 0.35), V(x, y_bracket - 0.02, z_wall + 0.62)],
           0.013, IRON, segments=5)
    _scroll(b, x, y_bracket - 0.14, z_wall + 0.2, 0.1, turns=1.8)
    _scroll(b, x, y_bracket - 0.06, z_wall + 0.48, 0.05, turns=1.4)
    # Schild: Bogen oben, hängt an zwei Ringen
    z0, z1 = z_wall + 0.3, z_wall + 0.9
    top, bottom = y_bracket - 0.12, y_bracket - 0.7
    for zr in (z0 + 0.06, z1 - 0.06):
        b.tube([V(x, y_bracket - 0.015, zr), V(x, top + 0.05, zr)], 0.006, IRON, segments=4)
    outline = []
    for k in range(13):
        a = math.pi * k / 12
        outline.append(((z0 + z1) / 2 - math.cos(a) * (z1 - z0) / 2, top - 0.12 + math.sin(a) * 0.1))
    outline = [(z1, bottom), (z1, top - 0.12)] + outline[::-1][1:-1] + [(z0, top - 0.12), (z0, bottom)]
    t = 0.035
    # Platte in der Ebene x: Oberseite zeigt nach +x
    pts = [V(x + t / 2, yy, zz) for zz, yy in outline]
    b.slab(list(reversed(pts)), t, board_mat)
    for side in (1, -1):
        xs = x + side * (t / 2 + 0.006)
        ring = [V(xs, yy, zz) for zz, yy in outline] + [V(xs, outline[0][1], outline[0][0])]
        inset = []
        cz = (z0 + z1) / 2
        cy = (top + bottom) / 2 - 0.03
        for p in ring:
            inset.append(V(xs, cy + (p.y - cy) * 0.88, cz + (p.z - cz) * 0.9))
        b.tube(inset, 0.007, GOLD, segments=4, caps=False)
        # Motiv: Garnrolle (in Akzentfarbe), Nadel, Faden-Kringel
        b.push(b.move(xs, cy, cz) @ b.turn_y(90 * side))
        b.box((-0.1, -0.13, 0), (0.1, -0.1, 0.02), TIMBER)
        b.box((-0.1, 0.1, 0), (0.1, 0.13, 0.02), TIMBER)
        b.box((-0.08, -0.1, 0.0), (0.08, 0.1, 0.03), accent_mat)
        for k in range(5):
            yy = -0.08 + k * 0.04
            b.box((-0.08, yy, 0.03), (0.08, yy + 0.008, 0.034), accent_mat)
        b.beam(V(0.06, -0.16, 0.035), V(0.2, 0.15, 0.035), 0.012, 0.008, GOLD)
        thread_spiral(b, (0.08, 0.0), 0.06, 1.3, accent_mat, 0.04, thickness=0.006)
        b.pop()
