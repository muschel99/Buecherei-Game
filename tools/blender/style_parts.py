"""Wiederverwendbare Bauteile im Stil (seit Etappe 4g, Teil 1b): Pflanzen, Blumenkästen,
Hängekorb, Ausleger-Schild, Kreidetafel. Alles in Godot-Koordinaten (siehe style_lib.py).
Die Pflanzen selbst (Blätter, Blüten, Ranken) baut seit Teil 4f style_plants.py."""

import math
import random

import style_lib as S
import style_plants as PL
from mathutils import Vector
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


def trailing_strand(b, start, length, rnd, color_index=1, palette=None, out=(0.0, 0.0, 1.0), space=None):
    """Hängende Ranke (Efeu, mit palette Hängepetunie): beginnt bei start (auf einer Kante),
    geht kurz nach vorn (out) und hängt dann herab – Blätter an Stielen (style_plants)."""
    kind = "petunia" if palette in ("rose", "lavender", "white", "coral") else "ivy"
    PL.trailing_ivy(b, Vector(start), length, rnd, Vector(out), space or PL.NO_SPACE, leaf_size=0.05, kind=kind,
                    palette=palette, over=0.03, lift=0.005)


def flower_box(b, x0, x1, y, z_back, z_front, box_mat, palettes, seed, glow=0.0, wall_z=0.0):
    """Blumenkasten (unten bei y, von z_back bis z_front; die Hauswand liegt bei wall_z – steht
    etwas vor, z. B. Fensterrahmen oder Fachwerk, beginnt der Kasten erst bei z_back): offener
    Kasten mit Leiste, Erde, Halter bis an die Wand; darin Geranien, Petunien, Margeriten und
    Lobelien, vorn hängen Ranken über den Rand."""
    rnd = random.Random(seed)
    h = 0.17
    at_wall = z_back <= wall_z + 0.001
    soil_y = PL.trough(b, x0, x1, y, z_back, z_front, h, box_mat, soil_drop=0.018, skip_back=at_wall, lip=0.015)
    b.box((x0 - 0.015, y + h - 0.025, z_front), (x1 + 0.015, y + h, z_front + 0.015), box_mat, skip=("back",))
    PL.extend_last_vessel(b)
    for cx in (x0 + 0.1, x1 - 0.1):
        b.box((cx - 0.02, y - 0.12, wall_z), (cx + 0.02, y, z_back + 0.1), IRON, skip=("back",))
    space = PL.BoxSpace(x0 - 0.015, x1 + 0.015, z_back, z_front + 0.015, y + h, soil_y, wall=0.018)
    space.wall(z_back)
    PL.bedding_row(b, x0 + 0.06, x1 - 0.06, soil_y, z_back + 0.03, z_front - 0.03, rnd, palettes, space, glow=glow,
                   trail_front=0.32, front_dir=Vector((0, 0, 1)))


def hydrangea_tub(b, x, z, seed, wall_z=None):
    """Zinkwanne mit Hortensie (links vom Eingang)."""
    rnd = random.Random(seed)
    v = PL.vessel(b, x, z, 0.24, 0.44, 0.27, ZINC, lip=0.015, lip_h=0.04, soil_drop=0.035, segments=16)
    for y in (0.08, 0.3):
        b.tube([V(x + 0.255 * math.cos(a), y, z + 0.255 * math.sin(a)) for a in [2 * math.pi * k / 16 for k in range(17)]],
               0.01, ZINC, segments=4, caps=False)
    for side in (-1, 1):
        b.tube([V(x + side * 0.27, 0.3, z), V(x + side * 0.31, 0.33, z), V(x + side * 0.31, 0.37, z), V(x + side * 0.28, 0.39, z)],
               0.012, ZINC, segments=5)
    PL.extend_last_vessel(b)
    space = PL.PotSpace(x, z, v["inner"], v["rim"], v["soil"], outer=v["outer"])
    if wall_z is not None:
        space.wall(wall_z)
    PL.hydrangea(b, V(x, v["soil"], z), 0.3, rnd, "hydrangea", space, heads=6)
    b.colliders.append(((x - 0.3, 0, z - 0.3), (x + 0.3, 0.9, z + 0.3)))


def olive_tree(b, x, z, seed):
    """Hoher Terrakotta-Topf mit kleinem Olivenbäumchen (rechts vom Eingang)."""
    rnd = random.Random(seed)
    v = PL.vessel(b, x, z, 0.17, 0.56, 0.22, POT, lip=0.015, lip_h=0.06, soil_drop=0.04)
    b.cylinder(V(x, 0.1, z), 0.19, 0.03, POT, segments=14, caps=(False, False))
    space = PL.PotSpace(x, z, v["inner"], v["rim"], v["soil"], outer=v["outer"])
    PL.olive(b, V(x, v["soil"], z), 1.0, rnd, space)
    b.colliders.append(((x - 0.24, 0, z - 0.24), (x + 0.24, 1.0, z + 0.24)))


CHALKBOARD_SIZE = (0.42, 0.7)


def chalkboard(b, x, z, sign_mat, facing=0.0):
    """Klapp-Kreidetafel (A-Aufsteller). Die Tafel vorn zeigt ein Bild (Schild sign_mat, Größe
    CHALKBOARD_SIZE), hinten ist sie leer."""
    b.push(b.move(x, 0, z) @ b.turn_y(facing))
    w, h = 0.5, 0.8
    bw, bh = CHALKBOARD_SIZE
    # So schräg, dass sich beide Tafeln oben genau treffen
    lean = math.asin(0.172 / h)
    for side in (1, -1):
        # Drehpunkt ist die innere Unterkante der Tafel – so steht sie auf dem Boden
        b.push(b.turn_y(0 if side > 0 else 180) @ b.move(0, 0, 0.17) @ S.Matrix.Rotation(-lean, 4, "X") @ b.move(0, 0, -0.17))
        b.box((-w / 2, 0, 0.17), (w / 2, h, 0.2), TIMBER)
        y0 = (h - bh) / 2
        if side > 0:
            b.box((-bw / 2, y0, 0.2), (bw / 2, y0 + bh, 0.203), SLATE_BOARD, skip=("back", "front"))
            b.poly([V(-bw / 2, y0, 0.203), V(bw / 2, y0, 0.203), V(bw / 2, y0 + bh, 0.203), V(-bw / 2, y0 + bh, 0.203)],
                   sign_mat, uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
        else:
            b.box((-bw / 2, y0, 0.2), (bw / 2, y0 + bh, 0.203), SLATE_BOARD, skip=("back",))
        b.pop()
    b.pop()
    b.colliders.append(((x - 0.3, 0, z - 0.3), (x + 0.3, 0.85, z + 0.3)))


def chalkboard_design(b, lines, seed):
    """Startbild der Kreidetafel: Schiefer mit Kreideschrift (Mitte = Ursprung)."""
    bw, bh = CHALKBOARD_SIZE
    b.box((-bw / 2 - 0.05, -bh / 2 - 0.05, -0.02), (bw / 2 + 0.05, bh / 2 + 0.05, 0.0), SLATE_BOARD)
    y = bh / 2 - 0.2
    for k, line in enumerate(lines):
        b.playful_text(line, 0.0, y, 0.0, 0.075 if k else 0.06, 0.002, CHALK, seed=seed + k, bounce=0.05,
                       tilt=4, font_path=S.PLAYFUL_FONT)
        y -= 0.13


def hanging_basket(b, x, y_bracket, z_wall, reach, seed, variant=None, clear_z=None):
    """Hängekorb an einem schmiedeeisernen Arm (von der Wand bei z_wall nach vorn). variant:
    "summer", "fuchsia" oder "cascade" (ohne Angabe je nach seed)."""
    rnd = random.Random(seed)
    zb = z_wall + reach
    arm = [V(x, y_bracket, z_wall + 0.01), V(x, y_bracket, zb + 0.05)]
    strut = [V(x, y_bracket - 0.35, z_wall + 0.01), V(x, y_bracket - 0.12, z_wall + reach * 0.5), V(x, y_bracket - 0.01, zb - 0.05)]
    b.tube(arm, 0.016, IRON, segments=6)
    b.tube(strut, 0.012, IRON, segments=5)
    _scroll(b, x, y_bracket - 0.12, z_wall + 0.16, 0.08, axis_plane="yz", attach=(arm, strut))
    b.box((x - 0.04, y_bracket - 0.4, z_wall), (x + 0.04, y_bracket + 0.05, z_wall + 0.02), IRON)
    # Nichts wächst über die Strebe in den Winkel zwischen Arm und Wand (Ebene durch die Strebe)
    d = Vector((0.0, 0.34, reach - 0.06)).normalized()
    under_strut = (V(x, y_bracket - 0.35, z_wall + 0.01), Vector((0.0, -d.z, d.y)), 0.025)
    basket(b, V(x, y_bracket - 0.4, zb), 0.17, V(x, y_bracket - 0.015, zb), rnd,
           wall_z=clear_z if clear_z is not None else z_wall + 0.03, variant=variant, planes=(under_strut,))


BASKET_VARIANTS = ("summer", "fuchsia", "cascade")


def _bowl(b, rim, radius, mat, rings=4, segs=14, squash=0.85):
    """Untere Halbkugel (außen sichtbar) unter dem Rand rim."""
    for r in range(rings):
        a0 = math.pi / 2 * r / rings
        a1 = math.pi / 2 * (r + 1) / rings
        for k in range(segs):
            t0 = 2 * math.pi * k / segs
            t1 = 2 * math.pi * (k + 1) / segs
            pts = [rim + Vector((math.cos(t) * math.cos(a), -math.sin(a) * squash, math.sin(t) * math.cos(a))) * radius
                   for t, a in ((t0, a0), (t0, a1), (t1, a1), (t1, a0))]
            nrm = [Vector((math.cos(t) * math.cos(a), -math.sin(a) / squash, math.sin(t) * math.cos(a))).normalized()
                   for t, a in ((t0, a0), (t0, a1), (t1, a1), (t1, a0))]
            # Ausrichtung über die Diagonalen (unten am Pol fallen zwei Ecken zusammen)
            if (pts[2] - pts[0]).cross(pts[3] - pts[1]).dot(nrm[0] + nrm[2]) < 0:
                pts, nrm = pts[::-1], nrm[::-1]
            b.poly(pts, mat, normals=nrm)


def basket(b, rim, radius, hook, rnd, palettes=("rose", "white", "lavender"), wall_z=None, mat=None, variant=None, planes=()):
    """Hängekorb mit drei Ketten zum Haken, in drei Arten:
    summer  – Drahtkorb mit Kokosmatte; Geranien obenauf, ringsum Lobelien, Petunien, Efeu
    fuchsia – Weidenkorb; Fuchsien hängen in Bögen über, dazwischen weiße Lobelien
    cascade – grün lackierte Schale; ein Wasserfall aus Hängepetunien in ein, zwei Farben"""
    mat = mat or IRON
    rim = Vector(rim)
    hook = Vector(hook)
    variant = variant or rnd.choice(BASKET_VARIANTS)
    segs = 14
    if variant == "fuchsia":
        wicker = Mat("plain", color=(0.55, 0.4, 0.24))
        _bowl(b, rim, radius, wicker, squash=0.75)
        # Geflecht: waagerechte Ringe auf dem Korb
        for q in range(1, 4):
            a = math.pi / 2 * q / 4.4
            r = radius * math.cos(a) + 0.003
            yy = -math.sin(a) * radius * 0.75
            b.tube([rim + Vector((math.cos(t) * r, yy, math.sin(t) * r)) for t in [2 * math.pi * k / segs for k in range(segs + 1)]],
                   0.005, Mat("plain", color=(0.48, 0.34, 0.2)), segments=3, caps=False)
        b.tube([rim + Vector((math.cos(t) * radius, 0.0, math.sin(t) * radius)) for t in [2 * math.pi * k / segs for k in range(segs + 1)]],
               0.011, Mat("plain", color=(0.5, 0.36, 0.22)), segments=4, caps=False)
        squash = 0.75
        rim_top = 0.012
    elif variant == "cascade":
        paint = Mat("paint", color=(0.13, 0.22, 0.17))
        _bowl(b, rim, radius, paint, squash=0.6)
        b.tube([rim + Vector((math.cos(t) * (radius + 0.004), 0.0, math.sin(t) * (radius + 0.004))) for t in
                [2 * math.pi * k / segs for k in range(segs + 1)]], 0.008, paint, segments=4, caps=False)
        squash = 0.6
        rim_top = 0.013
    else:
        coir = Mat("fabric", color=(0.46, 0.34, 0.22))
        _bowl(b, rim, radius, coir)
        # Drahtkorb außen: Ring oben, Bügel nach unten, Ring unten
        b.tube([rim + Vector((math.cos(t) * (radius + 0.004), 0.0, math.sin(t) * (radius + 0.004))) for t in
                [2 * math.pi * k / segs for k in range(segs + 1)]], 0.004, mat, segments=4, caps=False)
        for k in range(6):
            t = 2 * math.pi * k / 6 + 0.2
            b.tube([rim + Vector((math.cos(t) * math.cos(a), -math.sin(a) * 0.85, math.sin(t) * math.cos(a))) * (radius + 0.008)
                    for a in [math.pi / 2 * q / 6 * 0.8 for q in range(7)]], 0.0025, mat, segments=3, caps=False)
        a_end = math.pi / 2 * 0.8
        b.tube([rim + Vector((math.cos(t) * math.cos(a_end), -math.sin(a_end) * 0.85, math.sin(t) * math.cos(a_end))) * (radius + 0.008)
                for t in [2 * math.pi * q / 12 for q in range(13)]], 0.0025, mat, segments=3, caps=False)
        squash = 0.85
        rim_top = 0.006
    b.poly([rim + Vector((math.cos(t) * radius, -0.012, math.sin(t) * radius)) for t in
            [-2 * math.pi * k / segs for k in range(segs)]], SOIL)
    # Ketten aus Gliedern vom Rand zum Haken
    for k in range(3):
        t = 2 * math.pi * k / 3 + 0.5
        chain(b, rim + Vector((math.cos(t) * radius, 0.0, math.sin(t) * radius)), hook, PL.CHAIN)
    b.tube([hook, hook + Vector((0, 0.03, 0))], 0.004, mat, segments=4)
    # Pflanzen (der Korb zählt am Ende als Gefäß, siehe style_plants.settle)
    PL._register(b, "bowl", (b.xf @ rim, radius * 1.0 + 0.012, squash, rim.y - 0.012, rim.y + rim_top))
    space = PL.BasketSpace(rim, radius, rim.y - 0.012)
    if wall_z is not None:
        space.wall(wall_z)
    for point, normal, gap in planes:
        space.plane(point, normal, gap=gap)
    soil = rim + Vector((0, -0.012, 0))
    if variant == "fuchsia":
        colors = rnd.choice(PL.FUCHSIA_COLORS)
        # Mitte: ein Busch aus aufrechten Trieben, ringsum Bögen, die weit überhängen
        for k in range(10):
            t = 2 * math.pi * k / 10 + rnd.uniform(-0.2, 0.2)
            d = Vector((math.cos(t), 0, math.sin(t)))
            PL.fuchsia_trail(b, soil + d * (radius * rnd.uniform(0.3, 0.75)), rnd.uniform(0.22, 0.42), rnd, d, space, colors=colors,
                             over=radius * 0.45, lift=rnd.uniform(0.05, 0.12))
        for k in range(4):
            t = 2 * math.pi * k / 4 + 0.4
            d = Vector((math.cos(t), 0, math.sin(t)))
            PL.lobelia(b, soil + d * (radius * 0.6), rnd, "white", 1.0, space, trail=0.25, out=d, reach=radius * 0.5, lift=0.02)
    elif variant == "cascade":
        pal = rnd.choice([("rose", "white"), ("lavender", "white"), ("coral", "rose"), ("lavender", "rose")])
        PL.petunia_plant(b, soil, rnd, pal[0], 1.0, space)
        for k in range(14):
            t = 2 * math.pi * k / 14 + rnd.uniform(-0.15, 0.15)
            d = Vector((math.cos(t), 0, math.sin(t)))
            start = soil + d * (radius - 0.04)
            PL.trailing_ivy(b, start, rnd.uniform(0.3, 0.6), rnd, d, space, leaf_size=0.045, kind="petunia", palette=pal[k % 2],
                            over=0.1, lift=0.025)
            if k % 2 == 0:
                PL.petunia_plant(b, soil + d * (radius * 0.55), rnd, pal[k % 2], 0.85, space)
    else:
        PL.geranium(b, soil + Vector((rnd.uniform(-0.02, 0.02), 0, rnd.uniform(-0.02, 0.02))), rnd, palettes[0], 0.9, space, flowers=4)
        for k in range(10):
            t = 2 * math.pi * k / 10 + rnd.uniform(-0.25, 0.25)
            d = Vector((math.cos(t), 0, math.sin(t)))
            start = soil + d * (radius - 0.05)
            kind = ("lobelia", "petunia", "ivy", "lobelia", "petunia", "ivy", "lobelia", "petunia", "ivy", "lobelia")[k]
            pal = {"lobelia": rnd.choice(["blue", "white"]), "petunia": palettes[(k + 1) % len(palettes)]}.get(kind)
            PL.trailing_ivy(b, start, rnd.uniform(0.15, 0.4), rnd, d, space, leaf_size=0.045, kind=kind, palette=pal, over=0.11, lift=0.02)
            if kind == "petunia":
                PL.petunia_plant(b, soil + d * (radius * 0.55), rnd, pal, 0.8, space)
            elif kind == "lobelia":
                PL.lobelia(b, soil + d * (radius * 0.6), rnd, pal, 1.1, space)


def door_knob(b, x, y, z_face, out=1, mat=None):
    """Türknauf: Rosette auf dem Türblatt (Ebene z_face), Hals, Kugel (out = +1 nach +z, -1 nach -z)."""
    mat = mat or GOLD
    b.cylinder(V(x, y, z_face if out > 0 else z_face - 0.006), 0.028, 0.006, mat, segments=12, axis="z", caps=(True, True))
    zn = z_face + 0.006 * out
    b.cylinder(V(x, y, zn if out > 0 else zn - 0.025), 0.009, 0.025, mat, segments=8, axis="z", caps=(False, False))
    b.sphere(V(x, y, zn + out * 0.045), 0.027, mat, rings=5, segments=10)


def chain(b, a, z, mat, link=0.024, wire=0.0018):
    """Kette aus ovalen Gliedern von a nach z (jedes zweite Glied um 90° gedreht)."""
    a = Vector(a)
    z = Vector(z)
    d = z - a
    n = max(2, int(d.length / (link * 0.78)))
    axis = d.normalized()
    side = axis.cross(Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))).normalized()
    other = axis.cross(side).normalized()
    for k in range(n):
        c = a + d * ((k + 0.5) / n)
        w = side if k % 2 == 0 else other
        loop = [c + axis * (math.cos(q) * link * 0.5) + w * (math.sin(q) * link * 0.28) for q in [2 * math.pi * i / 5 for i in range(6)]]
        b.tube(loop, wire, mat, segments=3, caps=False)


def _scroll(b, x, y, z, radius, axis_plane="yz", turns=1.6, mat=None, attach=()):
    """Kleine Schnecke (Spirale) aus Rundeisen, in der Ebene x = konstant. attach = Stäbe
    (Listen von Punkten), mit denen sie verbunden ist: wo sie einen Stab nicht berührt, kommt
    ein kurzes Verbindungsstück mit Bund dazu (geschmiedet, nichts schwebt)."""
    pts = []
    for k in range(25):
        t = k / 24
        a = t * turns * 2 * math.pi
        r = radius * (1 - 0.8 * t)
        pts.append(V(x, y + r * math.sin(a), z + r * math.cos(a)))
    b.tube(pts, 0.009, mat or IRON, segments=4)
    for bar in attach:
        weld(b, pts, bar, mat or IRON)


def weld(b, pts, bar, mat, radius=0.008):
    """Verbindet eine Linie aus Punkten (pts) mit einem Stab (bar) an der engsten Stelle."""
    best = None
    for p in pts:
        for i in range(len(bar) - 1):
            a, c = Vector(bar[i]), Vector(bar[i + 1])
            seg = c - a
            f = max(0.0, min(1.0, (p - a).dot(seg) / max(seg.length_squared, 1e-9)))
            q = a + seg * f
            d = (p - q).length
            if best is None or d < best[0]:
                best = (d, p, q)
    if best and best[0] > 0.004:
        b.tube([best[1], best[2]], radius, mat, segments=4, caps=False)
    if best:
        b.sphere(best[2], radius * 1.6, mat, rings=3, segments=6)


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


HANGING_SIGN = (0.6, 0.56)


def _arch_outline(width, height, round_=False):
    """Umriss des Ausleger-Schilds (u, v) um die Mitte: unten gerade, oben ein flacher Bogen –
    oder rund (round_)."""
    hw, hh = width / 2, height / 2
    if round_:
        return [(hw * math.cos(2 * math.pi * k / 24 - math.pi / 2), hh * math.sin(2 * math.pi * k / 24 - math.pi / 2)) for k in range(24)]
    arc = []
    for k in range(13):
        a = math.pi * k / 12
        arc.append((hw * math.cos(a), hh - 0.1 + 0.1 * math.sin(a)))
    return [(-hw, -hh), (hw, -hh)] + arc


def projecting_sign(b, x, y_bracket, z_wall, edge_mat, sign_mat, round_=False):
    """Ausleger-Schild quer zur Fassade (Ebene x = konstant): Schmiedeeisen-Arm mit Schnecken,
    Holzschild; beide Seiten zeigen das Bild sign_mat (Größe HANGING_SIGN, lesbar von beiden
    Seiten)."""
    reach = 0.95
    b.box((x - 0.05, y_bracket - 0.5, z_wall), (x + 0.05, y_bracket + 0.06, z_wall + 0.025), IRON)
    # Der Arm beginnt in der Wandplatte (nicht genau auf ihrer Rückseite)
    arm = [V(x, y_bracket, z_wall + 0.01), V(x, y_bracket, z_wall + reach)]
    strut = [V(x, y_bracket - 0.45, z_wall + 0.02), V(x, y_bracket - 0.18, z_wall + 0.35), V(x, y_bracket - 0.02, z_wall + 0.62)]
    b.tube(arm, 0.018, IRON, segments=6)
    b.sphere(V(x, y_bracket, z_wall + reach + 0.01), 0.03, GOLD, rings=4, segments=8)
    b.tube(strut, 0.013, IRON, segments=5)
    _scroll(b, x, y_bracket - 0.14, z_wall + 0.2, 0.1, turns=1.8, attach=(arm, strut))
    _scroll(b, x, y_bracket - 0.06, z_wall + 0.48, 0.05, turns=1.4, attach=(arm, strut))
    width, height = HANGING_SIGN
    cz = z_wall + 0.3 + width / 2
    cy = y_bracket - 0.1 - height / 2
    for zr in (cz - width / 2 + 0.06, cz + width / 2 - 0.06):
        b.tube([V(x, y_bracket - 0.015, zr), V(x, cy + height / 2 - 0.02, zr)], 0.006, IRON, segments=4)
    outline = _arch_outline(width, height, round_)
    t = 0.035
    # +x-Seite: rechts im Bild = -z; -x-Seite: rechts im Bild = +z
    for side in (1, -1):
        xs = x + side * t / 2
        pts = [V(xs, cy + v, cz - side * u) for u, v in outline]
        uvs = [((u + width / 2) / width, (v + height / 2) / height) for u, v in outline]
        for tri_idx in _fan_indices(len(pts)):
            tri = [pts[i] for i in tri_idx]
            tuv = [uvs[i] for i in tri_idx]
            b.poly(tri, sign_mat, uvs=tuv) if (tri[1] - tri[0]).cross(tri[2] - tri[0]).x * side > 0 else \
                b.poly(tri[::-1], sign_mat, uvs=tuv[::-1])
    ring = [(cz - u, cy + v) for u, v in outline]
    for i in range(len(ring)):
        z0, y0 = ring[i]
        z1, y1 = ring[(i + 1) % len(ring)]
        quad = [V(x - t / 2, y0, z0), V(x - t / 2, y1, z1), V(x + t / 2, y1, z1), V(x + t / 2, y0, z0)]
        n = (quad[1] - quad[0]).cross(quad[2] - quad[0])
        out = V(0, y0 + y1 - 2 * cy, z0 + z1 - 2 * cz)
        b.poly(quad if n.dot(out) > 0 else quad[::-1], edge_mat)


def _fan_indices(n):
    """Dreiecke eines konvexen Vielecks (Fächer um die Mitte der Unterkante)."""
    return [(0, i, i + 1) for i in range(1, n - 1)]


def hanging_sign_design(b, board_mat, accent_mat):
    """Startbild des Ausleger-Schilds (Mitte = Ursprung): Holz, Goldrand, Garnrolle, Nadel, Faden."""
    width, height = HANGING_SIGN
    b.box((-width / 2 - 0.05, -height / 2 - 0.05, -0.03), (width / 2 + 0.05, height / 2 + 0.05, -0.02),
          Mat("plain", color=(0.5, 0.5, 0.5)))
    outline = _arch_outline(width, height)
    b.slab([V(u, v, 0) for u, v in outline], 0.02, board_mat)
    inset = [V(u * 0.88, v * 0.9 - 0.01, 0.005) for u, v in outline] + [V(outline[0][0] * 0.88, outline[0][1] * 0.9 - 0.01, 0.005)]
    b.tube(inset, 0.007, GOLD, segments=4, caps=False)
    b.box((-0.1, -0.13, 0), (0.1, -0.1, 0.02), TIMBER)
    b.box((-0.1, 0.1, 0), (0.1, 0.13, 0.02), TIMBER)
    b.box((-0.08, -0.1, 0.0), (0.08, 0.1, 0.03), accent_mat)
    for k in range(5):
        yy = -0.08 + k * 0.04
        b.box((-0.08, yy, 0.03), (0.08, yy + 0.008, 0.034), accent_mat)
    b.beam(V(0.06, -0.16, 0.035), V(0.2, 0.15, 0.035), 0.012, 0.008, GOLD)
    thread_spiral(b, (0.08, 0.0), 0.06, 1.3, accent_mat, 0.04, thickness=0.006)


LAMP_GREEN = Mat("paint", color=(0.12, 0.2, 0.16))
LAMP_GLASS = Mat("plain", color=(1.0, 0.88, 0.62), glow=0.35)


def lantern_head(b, x, y, z, size=0.22, mat=None):
    """Viereckige viktorianische Laterne (unten bei y): Boden, vier Glasscheiben mit Stegen,
    Dach mit Spitze."""
    mat = mat or LAMP_GREEN
    h = size * 1.5
    b.cylinder(V(x, y - 0.06, z), size * 0.25, 0.06, mat, segments=8, radius_top=size * 0.55)
    b.box((x - size * 0.55, y, z - size * 0.55), (x + size * 0.55, y + 0.03, z + size * 0.55), mat)
    b.box((x - size * 0.45, y + 0.03, z - size * 0.45), (x + size * 0.45, y + h, z + size * 0.45), LAMP_GLASS)
    for dx in (-1, 1):
        for dz in (-1, 1):
            b.box((x + dx * size * 0.5 - 0.012, y + 0.03, z + dz * size * 0.5 - 0.012), (x + dx * size * 0.5 + 0.012, y + h, z + dz * size * 0.5 + 0.012), mat,
                  skip=("bottom", "top"))
    b.box((x - size * 0.58, y + h, z - size * 0.58), (x + size * 0.58, y + h + 0.03, z + size * 0.58), mat)
    b.cylinder(V(x, y + h + 0.03, z), size * 0.62, size * 0.5, mat, segments=4, radius_top=0.02)
    b.sphere(V(x, y + h + size * 0.55, z), 0.025, mat, rings=3, segments=6)


def street_lamp(b, seed=1):
    """Viktorianischer Laternenmast (Ursprung am Fuß, 3,8 m): Sockel, kannelierter Schaft,
    Querstange (für Leitern), Laterne; zwei Hängekörbe mit Blumen."""
    rnd = random.Random(seed)
    m = LAMP_GREEN
    b.cylinder(V(0, 0, 0), 0.17, 0.12, m, segments=12, radius_top=0.15, caps=(False, True))
    b.cylinder(V(0, 0.12, 0), 0.13, 0.55, m, segments=12, radius_top=0.09, caps=(False, True))
    b.cylinder(V(0, 0.67, 0), 0.1, 0.06, m, segments=12, caps=(False, True))
    b.cylinder(V(0, 0.73, 0), 0.055, 2.55, m, segments=10, radius_top=0.045, caps=(False, True))
    for k in range(8):
        a = 2 * math.pi * k / 8
        b.box((0.058 * math.cos(a) - 0.006, 0.8, 0.058 * math.sin(a) - 0.006), (0.058 * math.cos(a) + 0.006, 3.0, 0.058 * math.sin(a) + 0.006), m)
    b.cylinder(V(0, 3.0, 0), 0.07, 0.08, m, segments=10, caps=(True, True))
    b.tube([V(-0.32, 3.08, 0), V(0.32, 3.08, 0)], 0.016, m, segments=5)
    for sx in (-0.32, 0.32):
        b.sphere(V(sx, 3.08, 0), 0.03, m, rings=3, segments=6)
    b.cylinder(V(0, 3.08, 0), 0.04, 0.2, m, segments=8, radius_top=0.06)
    lantern_head(b, 0.0, 3.34, 0.0, size=0.24)
    # Zwei Hängekörbe an Armen quer zur Straße (lokal ±x)
    for sx in (-1, 1):
        b.tube([V(0, 2.55, 0), V(sx * 0.25, 2.62, 0), V(sx * 0.5, 2.6, 0)], 0.012, m, segments=4)
        basket(b, V(sx * 0.5, 2.27, 0), 0.17, V(sx * 0.5, 2.585, 0), rnd, palettes=(rnd.choice(["rose", "coral"]), "white", "lavender"),
               mat=m, variant="cascade" if sx < 0 else "fuchsia")


## Hängende Straßenlaterne am Wandarm: Ausladung (Mitte der Laterne vor der Wand) und Platz,
## den sie braucht (um den Befestigungspunkt: x ±, y von – bis, z von – bis) – damit das
## Bau-Script der Häuser eine freie Stelle an der Fassade findet.
## Drei Kästen: Wandplatte (darf nirgends anstoßen), Arm (dünne Bänder an der Wand dürfen
## dahinter liegen) und Laterne.
BRACKET_REACH = 0.72
BRACKET_SPACE = [((-0.08, 0.08), (-0.31, 0.16), (0.0, 0.05)),
                 ((-0.06, 0.06), (-0.3, 0.26), (0.06, BRACKET_REACH - 0.1)),
                 ((-0.19, 0.19), (-0.72, 0.03), (BRACKET_REACH - 0.22, BRACKET_REACH + 0.2))]


def bracket_lantern(b, mat=None):
    """Hängende viktorianische Straßenlaterne an einem geschwungenen Wandarm (Ursprung: Mitte der
    Wandplatte auf der Wand, +z von der Wand weg, y nach oben). Die Laterne hängt am Ende des
    Arms, ihre Unterkante liegt 0,68 m unter dem Befestigungspunkt."""
    m = mat or LAMP_GREEN
    r = BRACKET_REACH
    b.box((-0.07, -0.3, 0.0), (0.07, 0.15, 0.03), m)
    b.box((-0.05, -0.26, 0.03), (0.05, 0.11, 0.045), m)
    # Oberer Arm (leicht nach oben geschwungen) und eine Strebe von unten
    arm = [V(0, 0.08, 0.03), V(0, 0.18, 0.25), V(0, 0.2, r - 0.12), V(0, 0.16, r)]
    strut = [V(0, -0.24, 0.03), V(0, -0.08, 0.2), V(0, 0.08, 0.42), V(0, 0.18, 0.58)]
    b.tube(arm, 0.022, m, segments=6)
    b.tube(strut, 0.015, m, segments=5)
    _scroll(b, 0, -0.04, 0.17, 0.075, mat=m, attach=(arm, strut))
    _scroll(b, 0, 0.07, 0.4, 0.055, mat=m, attach=(arm, strut))
    b.sphere(V(0, 0.2, r + 0.035), 0.028, m, rings=3, segments=6)
    # Haken mit kurzer Stange, daran die Laterne
    b.tube([V(0, 0.16, r), V(0, -0.03, r)], 0.011, m, segments=5)
    lantern_head(b, 0.0, -0.62, r, size=0.27, mat=m)


def wall_lantern(b, x, y, z_wall, mat=None):
    """Wandlaterne: geschwungener Arm von der Wand (Ebene z_wall, nach +z), Laterne darunter."""
    mat = mat or LAMP_GREEN
    b.box((x - 0.06, y - 0.12, z_wall), (x + 0.06, y + 0.22, z_wall + 0.03), mat)
    arm = [V(x, y, z_wall), V(x, y + 0.12, z_wall + 0.2), V(x, y + 0.1, z_wall + 0.38)]
    b.tube(arm, 0.018, mat, segments=5)
    _scroll(b, x, y - 0.02, z_wall + 0.12, 0.06, mat=mat, attach=(arm, [V(x, y - 0.12, z_wall + 0.03), V(x, y + 0.22, z_wall + 0.03)]))
    b.tube([V(x, y + 0.1, z_wall + 0.38), V(x, y - 0.05, z_wall + 0.38)], 0.008, mat, segments=4)
    lantern_head(b, x, y - 0.45, z_wall + 0.38, size=0.2, mat=mat)


# ---------------------------------------------------------------------------------------------
# Fahrrad (Hollandrad mit tiefem Einstieg) – seit Etappe 5b, auch vor dem Blumenladen
# ---------------------------------------------------------------------------------------------

BIKE_RUBBER = Mat("rubber")
BIKE_CHROME = Mat("chrome")
BIKE_SADDLE = Mat("leather", color=(0.36, 0.23, 0.15))


def bike_wheel(b, center, radius, axis="x", spokes=28):
    """Speichenrad um center (Achse x): Reifen, Felge, Nabe, Speichen (gekreuzt)."""
    c = Vector(center)
    seg = 32
    def ring(r, x=0.0):
        return [c + Vector((x, math.cos(a) * r, math.sin(a) * r)) for a in [2 * math.pi * k / seg for k in range(seg + 1)]]
    b.tube(ring(radius - 0.018), 0.019, BIKE_RUBBER, segments=6, caps=False)
    b.tube(ring(radius - 0.042), 0.007, BIKE_CHROME, segments=4, caps=False)
    b.cylinder(c + Vector((-0.04, 0, 0)), 0.018, 0.08, BIKE_CHROME, segments=10, axis="x", caps=(True, True))
    for k in range(spokes):
        side = -0.035 if k % 2 else 0.035
        a = 2 * math.pi * k / spokes
        a2 = a + (0.35 if k % 4 < 2 else -0.35)
        p0 = c + Vector((side, math.cos(a2) * 0.016, math.sin(a2) * 0.016))
        p1 = c + Vector((0.0, math.cos(a) * (radius - 0.045), math.sin(a) * (radius - 0.045)))
        b.tube([p0, p1], 0.0016, BIKE_CHROME, segments=3, caps=False)


def bike_crank(b, center, arm=0.17):
    """Kettenblatt, Kurbeln und Pedale um center (Achse x, dreht sich als Ganzes)."""
    c = Vector(center)
    b.cylinder(c + Vector((-0.07, 0, 0)), 0.012, 0.14, BIKE_CHROME, segments=8, axis="x", caps=(True, True))
    b.cylinder(c + Vector((0.035, 0, 0)), 0.1, 0.006, BIKE_CHROME, segments=24, axis="x", caps=(True, True))
    # Linke Kurbel (x < 0) zeigt bei Winkel 0 nach vorn – so passen die Beine des Fahrers
    for side, ang in ((-1, 0.0), (1, math.pi)):
        end = c + Vector((side * 0.075, math.sin(ang) * arm, math.cos(ang) * arm))
        b.beam(c + Vector((side * 0.075, 0, 0)), end, 0.022, 0.012, BIKE_CHROME)
        b.box((end.x + side * 0.005 - 0.0, end.y - 0.012, end.z - 0.045), (end.x + side * 0.1, end.y + 0.012, end.z + 0.045), BIKE_RUBBER) \
            if side > 0 else b.box((end.x - 0.1, end.y - 0.012, end.z - 0.045), (end.x - 0.005, end.y + 0.012, end.z + 0.045), BIKE_RUBBER)


def bicycle(b, frame, wheel_r=0.34, wheel_z=0.52, crank=(0.36, 0.02), seat=(0.92, -0.22), bars=(1.06, 0.3),
            wheels=True, crank_parts=True, rack=True, lamp=True, kickstand=False):
    """Hollandrad (vorn +z, Räder auf y = 0): tiefer, geschwungener Rahmen in Farbe frame,
    Schutzbleche, Kettenschutz, Gepäckträger, Lampe, Klingel, Ledersattel. wheels/crank_parts =
    False: Räder bzw. Kurbel nicht mitbauen (im Spiel eigene, drehende Teile)."""
    fz, rz = wheel_z, -wheel_z
    ry = wheel_r
    cy, cz = crank
    sy, sz = seat
    by, bz = bars
    head_top = V(0, by - 0.16, bz + 0.03)
    head_bot = V(0, by - 0.36, bz + 0.07)
    # Rahmen: geschwungenes Unterrohr (tiefer Einstieg), Sitzrohr, Hinterbau, Gabel
    down = [head_bot, V(0, by - 0.48, bz - 0.05), V(0, cy + 0.12, cz + 0.12), V(0, cy + 0.03, cz + 0.04)]
    b.tube(down, 0.024, frame, segments=8)
    seat_lo, seat_hi = V(0, cy, cz), V(0, sy - 0.08, sz + 0.02)
    join = seat_lo.lerp(seat_hi, 0.52)
    # Zweites Rohr: vom Steuerrohr geschwungen bis ans Sitzrohr (Damenrahmen)
    b.tube([head_top, head_top.lerp(join, 0.35) + V(0, -0.1, 0), head_top.lerp(join, 0.7) + V(0, -0.06, 0), join], 0.018, frame,
           segments=8)
    b.tube([seat_lo, seat_hi], 0.02, frame, segments=8)
    for sd in (-1, 1):
        b.tube([V(0, cy, cz), V(sd * 0.055, ry, rz)], 0.011, frame, segments=6)
        b.tube([V(0, sy - 0.14, sz + 0.0), V(sd * 0.055, ry + 0.01, rz + 0.01)], 0.01, frame, segments=6)
        b.tube([head_bot, V(sd * 0.045, head_bot.y - 0.1, head_bot.z + 0.04), V(sd * 0.05, ry, fz)], 0.011, frame, segments=6)
    b.tube([head_bot - V(0, 0.03, 0), head_top + V(0, 0.03, 0)], 0.026, frame, segments=8)
    # Lenker (geschwungen, nach hinten), Griffe, Klingel
    b.tube([head_top, V(0, by, bz)], 0.014, BIKE_CHROME, segments=6)
    for sd in (-1, 1):
        b.tube([V(0, by, bz), V(sd * 0.12, by + 0.02, bz - 0.01), V(sd * 0.24, by + 0.03, bz - 0.1), V(sd * 0.28, by + 0.02, bz - 0.17)],
               0.011, BIKE_CHROME, segments=6)
        b.cylinder(V(sd * 0.28, by + 0.02, bz - 0.2), 0.016, 0.1, BIKE_SADDLE, segments=8, axis="z", caps=(True, True))
    b.cylinder(V(0.08, by + 0.02, bz - 0.02), 0.022, 0.018, BIKE_CHROME, segments=10, caps=(False, True))
    # Sattel (Leder, Federn)
    b.tube([V(0, sy - 0.09, sz + 0.02), V(0, sy - 0.02, sz + 0.0)], 0.012, BIKE_CHROME, segments=6)
    b.push(S.Matrix.Translation((0, sy + 0.015, sz)) @ S.Matrix.Diagonal((1.0, 0.45, 1.0, 1.0)))
    b.sphere(V(0, 0, -0.02), 0.09, BIKE_SADDLE, rings=5, segments=12)
    b.sphere(V(0, 0, 0.08), 0.045, BIKE_SADDLE, rings=4, segments=10)
    b.pop()
    # Sattelfedern: von der Sattelunterseite schräg zur Sattelstütze
    for sd in (-1, 1):
        coil = [V(sd * 0.045 * (1 - k / 10), sy + 0.004 - k * 0.009 + 0.005 * math.sin(k * 2.2), sz - 0.07 + k * 0.004)
                for k in range(11)]
        b.tube(coil, 0.005, BIKE_CHROME, segments=4)
    b.tube([V(-0.045, sy + 0.004, sz - 0.07), V(0.045, sy + 0.004, sz - 0.07)], 0.005, BIKE_CHROME, segments=4)
    # Schutzbleche (Bögen über den Rädern)
    for wz, a0, a1 in ((fz, -0.2, 2.2), (rz, 0.9, 3.4)):
        arc = [V(0, ry + math.sin(a) * (ry + 0.03), wz + math.cos(a) * (ry + 0.03)) for a in [a0 + (a1 - a0) * k / 16 for k in range(17)]]
        for sd in (-1, 1):
            b.tube([p + V(sd * 0.03, 0, 0) for p in arc], 0.006, frame, segments=4)
        for a, c2 in zip(arc, arc[1:]):
            n = (a - V(0, ry, wz)).normalized()
            b.poly([a + V(-0.03, 0, 0), c2 + V(-0.03, 0, 0), c2 + V(0.03, 0, 0), a + V(0.03, 0, 0)], frame,
                   normals=[n, (c2 - V(0, ry, wz)).normalized(), (c2 - V(0, ry, wz)).normalized(), n])
    # Kettenschutz: flaches Blech von der Kurbel bis zur Hinterradnabe
    gx = 0.06
    top0, top1 = V(gx, cy + 0.12, cz + 0.06), V(gx, ry + 0.06, rz + 0.06)
    bot0, bot1 = V(gx, cy + 0.03, cz + 0.08), V(gx, ry - 0.02, rz + 0.1)
    b.poly([bot0, bot1, top1, top0], frame, both=True)
    b.tube([top0, top1], 0.006, frame, segments=4)
    if rack:
        rack_y = ry + wheel_r * 0.5 + 0.06
        for x in (-0.07, 0.0, 0.07):
            b.tube([V(x, rack_y, sz - 0.04), V(x, rack_y, rz - 0.12)], 0.006, BIKE_CHROME, segments=4)
        for sd in (-1, 1):
            b.tube([V(sd * 0.07, rack_y, rz - 0.1), V(sd * 0.06, ry, rz)], 0.006, BIKE_CHROME, segments=4)
        b.box((-0.06, rack_y - 0.02, rz - 0.15), (0.06, rack_y + 0.02, rz - 0.12), Mat("plain", color=(0.8, 0.1, 0.08), glow=0.2))
    if lamp:
        b.cylinder(V(0, head_bot.y + 0.05, head_bot.z + 0.05), 0.04, 0.07, BIKE_CHROME, segments=12, axis="z", caps=(True, False))
        b.cylinder(V(0, head_bot.y + 0.05, head_bot.z + 0.12), 0.036, 0.004, Mat("plain", color=(1.0, 0.95, 0.8), glow=0.6),
                   segments=12, axis="z", caps=(False, True))
    if kickstand:
        b.tube([V(0.03, cy - 0.02, cz - 0.08), V(0.18, 0.0, cz - 0.2)], 0.008, BIKE_CHROME, segments=4)
    if wheels:
        bike_wheel(b, (0, ry, fz), wheel_r)
        bike_wheel(b, (0, ry, rz), wheel_r)
    if crank_parts:
        bike_crank(b, (0, cy, cz))
