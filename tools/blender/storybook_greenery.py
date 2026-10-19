"""Pflanzen im Bilderbuch-Stil (Stil-Umbau der Welt, Etappe 4h, Schritt 5): üppig, rund und
verschlungen. Jedes Blatt ist ein kleiner linsenförmiger Körper (Body.leaf), jede Blüte ein Körper
(Stern, Rose, Doldenblüte), Stiele, Zweige und Stämme sind runde Röhren. Kronen und Büsche entstehen
aus vielen Blatt-Büscheln an Zweigen – keine Kugeln oder Würfel als Laub.

Alle Pflanzen werden in Blender-Koordinaten am Ursprung gebaut: Vorderseite (zur Straße) = -y,
oben = +z. Der Ursprung liegt dort, wo die Pflanze im Spiel auf ihrem Pflanzplatz sitzt (Erde im
Kasten/Topf, Fuß an der Wand, Boden). Kletterpflanzen wachsen an einer Wand bei y = 0 hoch.
Gebaut und exportiert von tools/blender/build_storybook_plants.py.
"""

import math
import random

from mathutils import Matrix, Vector

import storybook_common as SC
from storybook_lib import Body

UP = Vector((0, 0, 1))
FRONT = Vector((0, -1, 0))


def rnd_dir(rnd):
    while True:
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
        if 0.1 < d.length <= 1.0:
            return d.normalized()


class Plant:
    """Sammelt die Körper einer Pflanze (je Material ein Body)."""

    def __init__(self, M, coll, seed):
        self.M, self.coll = M, coll
        self.rnd = random.Random(seed)
        self.bodies = {}
        self.seed = seed

    def body(self, mat, vary=0.12, bevel=0.0):
        if mat not in self.bodies:
            self.bodies[mat] = Body("%s" % mat, self.M[mat], self.coll, seed=self.seed + len(self.bodies), vary=vary, bevel=bevel)
        return self.bodies[mat]

    def build(self, sway_height=None):
        """Alle Körper bauen; sway_height = Höhe, ab der die Pflanze voll im Wind schwingt (Alpha der
        Vertex-Farbe: 1 = fest am Fuß, darüber weicher)."""
        objs = []
        for mat, b in self.bodies.items():
            if not b.bm.verts:
                b.bm.free()
                continue
            o = b.build()
            if sway_height:
                ca = o.data.color_attributes.get("tint")
                for k, v in enumerate(o.data.vertices):
                    w = max(0.0, min(1.0, v.co.z / sway_height))
                    c = ca.data[k].color
                    ca.data[k].color = (c[0], c[1], c[2], 1.0 - 0.85 * w * w)
            objs.append(o)
        return objs


# --- Einzelteile ---

def leaf_on(p, at, d, n, size, shape="oval", width=0.85, petiole=0.02, mat="leaf", stem_mat="stem", thick=None, curl=0.18):
    """Ein Blatt mit kurzem Stiel: Ansatz at, Richtung d, Blattoberseite n."""
    rnd = p.rnd
    tip_base = at + d * petiole
    if petiole > 0.004:
        p.body(stem_mat, vary=0.06).tube([at, tip_base], max(0.0022, size * 0.04), segs=4)
    # wenige Randpunkte je Blatt (sparsam), die weichen Formen kommen aus der Linsenform
    segs = {"heart": 7, "round": 5, "oval": 5, "narrow": 4, "petal": 5, "ivy": None}.get(shape, 5)
    if size > 0.14 and segs:
        segs += 3   # große Blätter (Funkie, Baum) runder
    p.body(mat).leaf(tip_base, d, n, size, size * width, shape=shape, thick=thick or max(0.004, size * 0.09), curl=curl, segs=segs)
    return tip_base


def leaf_ball(p, center, radius, n, size, rnd, mat="leaf", shape="oval", squash=(1.0, 1.0, 0.85), twig_from=None, stem_mat="stem",
              front_bias=0.25, width=0.85, petiole=0.018, core=True):
    """Rundes Blatt-Büschel: ein dunkelgrüner, unregelmäßiger Kern (damit keine Lücken zu sehen sind),
    darauf n Blätter dicht wie Schindeln – jedes zeigt mit der Oberseite nach außen, die Spitze hängt
    leicht. Ein Zweig von twig_from trägt das Büschel (nichts schwebt)."""
    c = Vector(center)
    if twig_from is not None:
        mid = Vector(twig_from).lerp(c, 0.55) + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0.3)) * radius * 0.25
        p.body(stem_mat, vary=0.06).tube([Vector(twig_from), mid, c], max(0.004, radius * 0.06), segs=6, smooth=1, round_ends=True)
    if core:
        p.body("leaf_core", vary=0.1).blob(c, radius * 0.66, subdiv=2 if radius > 0.3 else 1, lump=0.25, scale=squash)
    for _ in range(n):
        d = rnd_dir(rnd)
        if d.z < -0.6:
            d.z = -d.z * 0.4
        d = (d + FRONT * front_bias * rnd.random() + UP * 0.12).normalized()
        sq = Vector((d.x * squash[0], d.y * squash[1], d.z * squash[2]))
        at = c + sq * radius * rnd.uniform(0.72, 0.95)
        tang = d.cross(UP)
        if tang.length < 0.1:
            tang = d.cross(Vector((1, 0, 0)))
        tang.normalize()
        s = size * rnd.uniform(0.8, 1.2)
        ld = (tang * rnd.uniform(-0.8, 0.8) + d * 0.35 - UP * rnd.uniform(0.1, 0.5)).normalized()
        nn = (d * 0.85 + UP * 0.3).normalized()
        leaf_on(p, at - ld * s * 0.35, ld, nn, s, shape=shape, mat=mat, stem_mat=stem_mat, width=width, petiole=0.0)


def floret(p, mat, center, normal, size, petals=5, cup=0.25):
    p.body(mat, vary=0.1).star(center, normal, size, petals, p.rnd, thick=max(0.003, size * 0.12), cup=cup)


def rose(p, mat, center, normal, size):
    """Rose: drei Ringe schalenförmiger Blütenblätter um eine runde Knospe."""
    rnd = p.rnd
    n = Vector(normal).normalized()
    ref = UP if abs(n.z) < 0.9 else Vector((1, 0, 0))
    s1 = n.cross(ref).normalized()
    s2 = n.cross(s1).normalized()
    b = p.body(mat, vary=0.1)
    for ring, (count, rad, lift, curl) in enumerate(((5, 1.0, 0.0, 0.35), (4, 0.7, 0.25, 0.5), (3, 0.42, 0.45, 0.7))):
        spin = rnd.uniform(0, 6.28)
        for k in range(count):
            a = spin + 2 * math.pi * k / count
            out = s1 * math.cos(a) + s2 * math.sin(a)
            base = Vector(center) + out * size * 0.15 * rad + n * size * lift * 0.5
            d = (out * (1.0 - 0.45 * ring) + n * (0.35 + 0.35 * ring)).normalized()
            b.leaf(base, d, (n * 0.6 - out * 0.4 * ring).normalized(), size * rad * 0.9, size * rad * 0.85, shape="petal",
                   thick=size * 0.08, curl=curl, segs=4)
    b.blob(Vector(center) + n * size * 0.22, size * 0.2, subdiv=1, lump=0.15, scale=(1.0, 1.0, 1.0))


def umbel(p, mat, center, radius, up, count, size, petals=5):
    """Kugeliger Blütenkopf (Geranie, Hortensie): dicht gepackte Einzelblüten auf einer Halbkugel."""
    rnd = p.rnd
    for _ in range(count):
        d = rnd_dir(rnd)
        if d.dot(up) < -0.2:
            d = (d + up * 1.1).normalized()
        c = Vector(center) + d * radius * rnd.uniform(0.75, 1.05)
        floret(p, mat, c, d, size * rnd.uniform(0.85, 1.15), petals)


def stem_path(start, direction, length, rnd, step=0.04, bend=0.25, gravity=0.0, wall=None):
    """Weich geschwungener Trieb als Punktfolge; wall = (y-Grenze): bleibt davor."""
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    for _ in range(max(2, int(length / step))):
        d = (d + Vector((rnd.uniform(-bend, bend), rnd.uniform(-bend, bend) * 0.5, rnd.uniform(-bend, bend) - gravity))).normalized()
        q = pts[-1] + d * step
        if wall is not None and q.y > wall:
            q.y = wall - rnd.uniform(0.0, 0.01)
            d.y = -abs(d.y) * 0.5
        pts.append(q)
    return pts


# --- Blumenkästen (Ausschnitt 0,3 m; das Spiel reiht mehrere nebeneinander) ---

def box_geranium(p, color):
    """Geranien im Kasten: üppiges Polster aus runden, gewellten Blättern über die ganze Breite,
    darüber zwei bis drei kugelige Blütenköpfe; vorn hängt eine Ranke über den Rand."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, -0.01, 0.06)), 0.1, 30, 0.085, rnd, mat="leaf", shape="round", width=0.95, squash=(1.5, 0.85, 0.65),
              twig_from=Vector((0, 0, 0)))
    for k in range(rnd.randint(2, 3)):
        base = Vector(((k - 1) * 0.09 + rnd.uniform(-0.02, 0.02), rnd.uniform(-0.03, 0.02), 0.04))
        top = base + Vector((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.0), rnd.uniform(0.18, 0.26)))
        p.body("stem", vary=0.06).tube([base, base.lerp(top, 0.5) + Vector((0, -0.01, 0)), top], 0.0045, segs=5, smooth=1, round_ends=True)
        umbel(p, color, top, rnd.uniform(0.06, 0.072), UP, rnd.randint(13, 16), 0.03)
    start = Vector((rnd.uniform(-0.1, 0.1), -0.07, 0.02))
    pts = stem_path(start, Vector((0, -1, 0.2)), 0.3, rnd, step=0.035, bend=0.15, gravity=0.35)
    p.body("stem", vary=0.06).tube(pts, lambda t: 0.004 * (1 - 0.5 * t), segs=5, smooth=1, round_ends=True)
    for i, q in enumerate(pts[1:], 1):
        side = 1 if i % 2 else -1
        leaf_on(p, q, Vector((side * 0.6, -0.4, -0.4)).normalized(), Vector((0, -0.8, 0.5)).normalized(), 0.05 * (1 - 0.3 * i / len(pts)),
                shape="heart", mat="ivy", petiole=0.01)


def box_petunia(p, colors):
    """Hängepetunien: dichtes Polster aus ovalen Blättern und Trichterblüten, viele Ranken fallen
    vorn weit über den Rand."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, -0.01, 0.06)), 0.11, 26, 0.06, rnd, shape="oval", squash=(1.4, 0.9, 0.6), twig_from=Vector((0, 0, 0)))
    for _ in range(9):
        d = rnd_dir(rnd)
        d.z = abs(d.z) * 0.6 + 0.2
        c = Vector((0, -0.01, 0.07)) + Vector((d.x * 0.14, d.y * 0.09, d.z * 0.08))
        floret(p, rnd.choice(colors), c, d, rnd.uniform(0.026, 0.034), petals=5, cup=0.45)
    for k in range(4):
        start = Vector((-0.12 + 0.08 * k + rnd.uniform(-0.02, 0.02), -0.06, 0.03))
        pts = stem_path(start, Vector((rnd.uniform(-0.3, 0.3), -1, 0.1)), rnd.uniform(0.25, 0.42), rnd, step=0.035, bend=0.18, gravity=0.4)
        p.body("stem", vary=0.06).tube(pts, lambda t: 0.004 * (1 - 0.5 * t), segs=5, smooth=1, round_ends=True)
        for i, q in enumerate(pts[1:], 1):
            dd = Vector((rnd.uniform(-1, 1), -0.5, rnd.uniform(-0.6, 0.3))).normalized()
            leaf_on(p, q, dd, Vector((0, -0.6, 0.8)).normalized(), rnd.uniform(0.03, 0.042), shape="oval", petiole=0.008)
            if rnd.random() < 0.55:
                floret(p, rnd.choice(colors), q + dd * 0.02 + Vector((0, -0.015, 0)), (dd + Vector((0, -1, 0))).normalized(),
                       rnd.uniform(0.024, 0.03), 5, cup=0.45)


def box_mixed(p):
    """Gemischter Kasten: Lavendelähren, weiße Margeriten und Efeu, das über den Rand fällt."""
    rnd = p.rnd
    for k in range(5):
        base = Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.03, 0.04), 0.0))
        for _ in range(6):
            top = base + Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.04, 0.03), rnd.uniform(0.2, 0.3)))
            p.body("stem", vary=0.06).tube([base, base.lerp(top, 0.5) + Vector((0, 0, 0)), top], 0.0025, segs=4, smooth=1)
            for j in range(7):
                q = base.lerp(top, 0.65 + 0.35 * j / 6)
                floret(p, "lilac", q + rnd_dir(rnd) * 0.006, rnd_dir(rnd), 0.009, petals=4, cup=0.2)
        for _ in range(4):
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 0.6), 0.3)).normalized()
            leaf_on(p, base + d * 0.02, (d + UP).normalized(), UP, 0.06, shape="narrow", mat="olive_leaf", petiole=0.0, width=0.5)
    for _ in range(3):
        c = Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.06, 0.0), rnd.uniform(0.1, 0.16)))
        p.body("stem", vary=0.06).tube([Vector((c.x, c.y + 0.02, 0.0)), c], 0.003, segs=4)
        n = Vector((rnd.uniform(-0.3, 0.3), -0.5, 1.0)).normalized()
        floret(p, "cream_flower", c, n, 0.03, petals=12, cup=0.1)
        p.body("gold_flower", vary=0.05).lathe([(0.0, 0.0), (0.009, 0.0), (0.008, 0.006), (0.0, 0.009)], c + n * 0.002, segs=8)
    start = Vector((rnd.uniform(-0.1, 0.1), -0.06, 0.01))
    pts = stem_path(start, Vector((0.2, -1, 0.1)), 0.35, rnd, step=0.035, bend=0.12, gravity=0.4)
    p.body("stem", vary=0.06).tube(pts, lambda t: 0.004 * (1 - 0.5 * t), segs=5, smooth=1, round_ends=True)
    for i, q in enumerate(pts[1:], 1):
        side = 1 if i % 2 else -1
        leaf_on(p, q, Vector((side * 0.6, -0.4, -0.4)).normalized(), Vector((0, -0.8, 0.5)).normalized(), 0.045, shape="heart", mat="ivy",
                petiole=0.01)


# --- Kübel- und Topfpflanzen (Topf-Radius 0,2 m; im Spiel passend skaliert) ---

def bush(p, radius=0.22, height=0.42, mat="box_leaf", leaf=0.05, density=1.0, blossoms=None):
    """Runder, dichter Busch (Buchs, Lorbeer): ein paar Zweige, darauf runde Blatt-Büschel, die
    ineinander übergehen; blossoms = Blütenfarbe."""
    rnd = p.rnd
    base = Vector((0, 0, 0))
    centers = [Vector((0, -0.01, height * 0.55))]
    for k in range(int(6 * density)):
        a = 2 * math.pi * k / 6 + rnd.uniform(-0.3, 0.3)
        centers.append(Vector((math.cos(a) * radius * 0.5, math.sin(a) * radius * 0.45, height * rnd.uniform(0.35, 0.75))))
    centers.append(Vector((rnd.uniform(-0.03, 0.03), 0.0, height * 0.85)))
    for c in centers:
        cl = radius * rnd.uniform(0.52, 0.62)
        leaf_ball(p, c, cl, int(40 * density), leaf * 1.5, rnd, mat=mat, squash=(1.0, 1.0, 0.92), twig_from=base + UP * 0.02,
                  stem_mat="bark", front_bias=0.2)
        if blossoms and rnd.random() < 0.8:
            for _ in range(5):
                d = rnd_dir(rnd)
                d.z = abs(d.z)
                floret(p, blossoms, c + d * cl * 1.02, d, leaf * 0.7, petals=5, cup=0.35)


def hydrangea(p, color, size=1.0):
    """Hortensie: rundes Polster aus großen, ovalen Blättern, darauf fünf bis sieben große,
    halbkugelige Blütenköpfe aus vielen vierblättrigen Blüten."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, 0, 0.16 * size)), 0.18 * size, 34, 0.11 * size, rnd, mat="leaf", shape="oval", width=0.75,
              squash=(1.15, 1.15, 0.8), twig_from=Vector((0, 0, 0.0)), front_bias=0.15)
    for k in range(rnd.randint(5, 7)):
        a = 2 * math.pi * k / 6 + rnd.uniform(-0.3, 0.3)
        r = 0.11 if k else 0.0
        top = Vector((math.cos(a) * r, math.sin(a) * r * 0.9 - 0.02, rnd.uniform(0.3, 0.36))) * size
        p.body("stem", vary=0.06).tube([Vector((0, 0, 0)), top * 0.5 + Vector((0, 0, 0.03)), top], 0.006, segs=5, smooth=1)
        p.body(color + "_core", vary=0.08).blob(top + UP * 0.02 * size, 0.065 * size, subdiv=1, lump=0.15, scale=(1.0, 1.0, 0.75))
        umbel(p, color, top + UP * 0.03 * size, rnd.uniform(0.075, 0.09) * size, UP, int(26 * size), 0.03 * size, petals=4)


def olive(p, height=0.85, crown=0.26):
    """Olivenbäumchen: leicht gedrehter Stamm, drei Äste, runde Krone aus schmalen silbrigen
    Blättern in Büscheln."""
    rnd = p.rnd
    trunk = [Vector((0, 0, 0)), Vector((0.02, 0.01, height * 0.3)), Vector((-0.015, 0.0, height * 0.55)), Vector((0.0, 0.0, height * 0.7))]
    p.body("bark", vary=0.08).tube(trunk, lambda t: 0.028 * (1 - 0.4 * t), segs=8, smooth=2, round_ends=True)
    top = trunk[-1]
    for k in range(7):
        a = 2 * math.pi * k / 7 + rnd.uniform(-0.3, 0.3)
        c = top + Vector((math.cos(a) * crown * 0.55, math.sin(a) * crown * 0.5, rnd.uniform(0.0, crown * 0.75)))
        leaf_ball(p, c, crown * 0.42, 22, 0.045, rnd, mat="olive_leaf", shape="narrow", width=0.4, twig_from=top, stem_mat="bark",
                  petiole=0.006)
    leaf_ball(p, top + UP * crown * 0.75, crown * 0.45, 26, 0.045, rnd, mat="olive_leaf", shape="narrow", width=0.4, twig_from=top,
              stem_mat="bark", petiole=0.006)


def geranium_bush(p, color):
    rnd = p.rnd
    for k in range(3):
        a = 2 * math.pi * k / 3
        base = Vector((math.cos(a) * 0.07, math.sin(a) * 0.07, 0.0))
        for _ in range(14):
            b = rnd.uniform(0, 2 * math.pi)
            d = Vector((math.cos(b), math.sin(b), rnd.uniform(0.2, 0.9))).normalized()
            at = base + d * rnd.uniform(0.04, 0.12) + UP * rnd.uniform(0.0, 0.08)
            p.body("stem", vary=0.06).tube([base, at], 0.0035, segs=4)
            leaf_on(p, at, (d + UP * 0.3).normalized(), (UP * 0.8 + d * 0.3).normalized(), rnd.uniform(0.07, 0.095), shape="round", width=0.95,
                    petiole=0.0)
        top = base + Vector((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.0), rnd.uniform(0.22, 0.3)))
        p.body("stem", vary=0.06).tube([base, base.lerp(top, 0.5), top], 0.005, segs=5, smooth=1, round_ends=True)
        umbel(p, color, top, rnd.uniform(0.06, 0.075), UP, rnd.randint(20, 26), 0.022)


def trailing(p, colors, radius=0.17, ranks=10):
    """Ampel-Füllung: Polster in der Mitte, Ranken mit Blüten fallen rundherum über den Rand."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, 0, 0.05)), radius * 0.75, 24, 0.05, rnd, shape="oval", squash=(1.0, 1.0, 0.55), twig_from=Vector((0, 0, 0)))
    for _ in range(10):
        d = rnd_dir(rnd)
        d.z = abs(d.z) * 0.5 + 0.2
        floret(p, rnd.choice(colors), Vector((0, 0, 0.06)) + Vector((d.x, d.y, d.z * 0.5)) * radius * 0.85, d, 0.03, 5, cup=0.45)
    for k in range(ranks):
        a = 2 * math.pi * k / ranks + rnd.uniform(-0.2, 0.2)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        start = out * radius * 0.85 + UP * 0.02
        pts = stem_path(start, (out + UP * 0.2).normalized(), rnd.uniform(0.25, 0.45), rnd, step=0.035, bend=0.15, gravity=0.45)
        p.body("stem", vary=0.06).tube(pts, lambda t: 0.004 * (1 - 0.5 * t), segs=5, smooth=1, round_ends=True)
        for i, q in enumerate(pts[1:], 1):
            dd = (out + Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.2)))).normalized()
            if k % 3 == 0:
                leaf_on(p, q, dd, (out + UP * 0.5).normalized(), 0.042 * (1 - 0.3 * i / len(pts)), shape="heart", mat="ivy", petiole=0.008)
            else:
                leaf_on(p, q, dd, (out + UP * 0.5).normalized(), rnd.uniform(0.03, 0.04), shape="oval", petiole=0.008)
                if rnd.random() < 0.5:
                    floret(p, rnd.choice(colors), q + dd * 0.02, (dd + out).normalized(), rnd.uniform(0.024, 0.03), 5, cup=0.45)


# --- Kletterpflanzen (Wand bei y = 0, wachsen vor der Wand nach oben) ---

def climber(p, width, height, kind="ivy"):
    """Kletterpflanze: aus einem Pflanzloch am Boden wachsen Haupttriebe in weichen Bögen die Wand
    hoch und fächern sich auf, Seitentriebe laufen waagerecht; an jedem Knoten sitzen mehrere große
    Blätter, die sich wie Schindeln überlappen (Efeu: Herzblätter; Rose: ovale Blätter und Rosen;
    Glyzinie: helle Blätter und hängende fliederfarbene Trauben). Alles bleibt vor der Wand (y < -0,1),
    damit nichts in Sockel, Gesimse oder Ecksteine sticht."""
    rnd = p.rnd
    leaf_mat = {"ivy": "ivy", "rose": "leaf", "wisteria": "ivy_young"}[kind]
    stem_mat = "bark" if kind == "wisteria" else "stem"
    p.body("soil", vary=0.08).lathe([(0.0, 0.0), (0.17, 0.0), (0.16, 0.02), (0.0, 0.035)], Vector((0, -0.18, 0.0)), segs=10, dent=0.006)
    mains = max(2, int(round(width / 0.38)))
    shoots = []
    for k in range(mains):
        target_x = ((k + 0.5) / mains - 0.5) * width * 0.9
        pts = [Vector((rnd.uniform(-0.06, 0.06), -0.17, 0.0))]
        d = Vector((target_x * 0.5, 0.25, 1.0)).normalized()
        h = height * rnd.uniform(0.8, 1.0)
        while pts[-1].z < h:
            z = pts[-1].z
            want_x = target_x * min(1.0, z / (h * 0.4)) + math.sin(z * 2.3 + k) * 0.08
            d = (d + Vector(((want_x - pts[-1].x) * 1.2 + rnd.uniform(-0.2, 0.2), 0.0, 0.9))).normalized()
            q = pts[-1] + d * 0.1
            q.y = max(-0.13, min(-0.1, q.y + 0.03))
            pts.append(q)
        p.body(stem_mat, vary=0.06).tube(pts, lambda t: 0.014 * (1 - 0.6 * t), segs=6, smooth=2, round_ends=True)
        shoots.append(pts)
        for i in range(2, len(pts) - 1, 2):
            side = 1 if (i // 2 + k) % 2 else -1
            sp = stem_path(pts[i], Vector((side, -0.1, rnd.uniform(-0.2, 0.5))), rnd.uniform(0.3, 0.6), rnd, step=0.08, bend=0.25,
                           gravity=0.05 if kind != "wisteria" else 0.25, wall=-0.1)
            for q in sp:
                q.x = max(-width / 2, min(width / 2, q.x))
                q.y = min(q.y, -0.1)
            p.body(stem_mat, vary=0.06).tube(sp, lambda t: 0.007 * (1 - 0.5 * t), segs=5, smooth=1, round_ends=True)
            shoots.append(sp)
    base_size = {"ivy": 0.12, "rose": 0.1, "wisteria": 0.1}[kind]
    # dichte, runde Blattpolster entlang der Triebe (wie Efeu, der eine Wand überwächst): jedes Polster
    # ein Kern mit überlappenden Blättern, flach an der Wand
    for si, pts in enumerate(shoots):
        main = si < mains
        for i in range(1, len(pts)):
            q = pts[i]
            fade = 1.0 - 0.3 * q.z / max(0.1, height)
            if i % (2 if main else 3) == 0 or i == len(pts) - 1:
                r = rnd.uniform(0.13, 0.2) * (1.15 if q.z < height * 0.35 else 1.0) * fade
                leaf_ball(p, q + Vector((rnd.uniform(-0.04, 0.04), -0.07 - r * 0.45, rnd.uniform(-0.03, 0.03))), r, int(16 * r / 0.16),
                          base_size * fade, rnd, mat=leaf_mat, shape="heart" if kind == "ivy" else "oval",
                          width=0.95 if kind == "ivy" else 0.68, squash=(1.25, 0.5, 1.0), front_bias=0.6)
            else:
                d = Vector((rnd.uniform(-1, 1), -0.25, rnd.uniform(-1.0, 0.2))).normalized()
                nrm = Vector((rnd.uniform(-0.3, 0.3), -1.0, rnd.uniform(0.1, 0.6))).normalized()
                leaf_on(p, q + Vector((0, -0.02, 0)), d, nrm, base_size * rnd.uniform(0.85, 1.15) * fade, shape="heart" if kind == "ivy" else "oval",
                        mat=leaf_mat if rnd.random() > 0.3 else "ivy_young", petiole=0.0, width=0.95 if kind == "ivy" else 0.7)
        for i in range(1, len(pts)):
            q = pts[i]
            if kind == "rose" and rnd.random() < 0.6:
                # Rosen sitzen vorn auf den Blattpolstern
                c = q + Vector((rnd.uniform(-0.08, 0.08), -0.22, rnd.uniform(-0.04, 0.05)))
                rose(p, rnd.choice(("rose", "pink", "blush_flower")), c, Vector((rnd.uniform(-0.3, 0.3), -1, 0.35)).normalized(),
                     rnd.uniform(0.06, 0.08))
            if kind == "wisteria" and i % 3 == 0 and rnd.random() < 0.65 and q.z > 0.8:
                L = rnd.uniform(0.22, 0.34)
                top = q + Vector((0, -0.2, -0.04))
                p.body("stem", vary=0.06).tube([q, top, top - UP * L], 0.003, segs=4)
                for j in range(10):
                    t = j / 9
                    c = top - UP * L * t + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 0.3), 0)) * 0.035 * (1 - t * 0.6)
                    floret(p, rnd.choice(("lilac", "lilac", "blue_flower")), c, rnd_dir(rnd), 0.02 * (1 - 0.4 * t), petals=4, cup=0.3)


# --- Beete, Hecke, Bäume ---

def hosta(p, size=1.0):
    rnd = p.rnd
    for k in range(int(14 * size) + 4):
        a = 2 * math.pi * k / 16 + rnd.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), rnd.uniform(0.6, 1.1))).normalized()
        at = Vector((0, 0, 0.0)) + d * 0.1 * size
        p.body("stem", vary=0.06).tube([Vector((0, 0, 0)), at], 0.006, segs=5)
        leaf_on(p, at, (d + Vector((0, 0, -0.1))).normalized(), (UP + d * 0.6).normalized(), rnd.uniform(0.15, 0.21) * size, shape="heart",
                mat=rnd.choice(("leaf", "box_leaf")), petiole=0.0, width=0.75, curl=0.25)


def fern(p, size=1.0):
    """Farn: gebogene Wedel, jeder Wedel eine Mittelrippe mit vielen kleinen Fiederblättchen."""
    rnd = p.rnd
    for k in range(9):
        a = 2 * math.pi * k / 9 + rnd.uniform(-0.2, 0.2)
        out = Vector((math.cos(a), math.sin(a), 0))
        pts = [Vector((0, 0, 0.02))]
        d = (out * 0.4 + UP).normalized()
        L = rnd.uniform(0.38, 0.5) * size
        for i in range(8):
            d = (d + out * 0.25 - UP * 0.18).normalized()
            pts.append(pts[-1] + d * L / 8)
        p.body("stem", vary=0.06).tube(pts, lambda t: 0.004 * (1 - 0.6 * t), segs=4, smooth=1, round_ends=True)
        for i in range(1, len(pts)):
            q = pts[i]
            tang = (pts[i] - pts[i - 1]).normalized()
            side = tang.cross(UP).normalized()
            s = 0.055 * (1 - 0.6 * i / len(pts)) * size
            for sg in (-1, 1):
                p.body("box_leaf", vary=0.1).leaf(q, (side * sg + tang * 0.5).normalized(), (UP + side.cross(tang) * 0.0).normalized(), s, s * 0.4,
                                                  shape="narrow", thick=0.003, curl=0.15, segs=5)


def daisies(p):
    rnd = p.rnd
    for _ in range(14):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0.4)).normalized()
        leaf_on(p, d * 0.05, (d + UP * 0.5).normalized(), UP, 0.08, shape="narrow", width=0.45, petiole=0.0)
    for _ in range(9):
        c = Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), rnd.uniform(0.22, 0.38)))
        p.body("stem", vary=0.06).tube([Vector((c.x * 0.3, c.y * 0.3, 0.0)), c], 0.003, segs=4, smooth=0)
        n = Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.4, 0.1), 1.0)).normalized()
        floret(p, "cream_flower", c, n, 0.035, petals=12, cup=0.1)
        p.body("gold_flower", vary=0.05).lathe([(0.0, 0.0), (0.01, 0.0), (0.009, 0.007), (0.0, 0.01)], c + n * 0.002, segs=8)


def lavender(p):
    rnd = p.rnd
    for _ in range(26):
        base = Vector((rnd.uniform(-0.06, 0.06), rnd.uniform(-0.06, 0.06), 0.0))
        top = base + Vector((rnd.uniform(-0.14, 0.14), rnd.uniform(-0.14, 0.14), rnd.uniform(0.38, 0.52)))
        p.body("stem", vary=0.06).tube([base, base.lerp(top, 0.5), top], 0.0028, segs=4, smooth=1)
        for j in range(8):
            q = base.lerp(top, 0.7 + 0.3 * j / 7)
            floret(p, "lilac", q + rnd_dir(rnd) * 0.005, rnd_dir(rnd), 0.01, petals=4, cup=0.2)
    for _ in range(30):
        d = rnd_dir(rnd)
        d.z = abs(d.z) * 0.6 + 0.3
        leaf_on(p, d * 0.06, d, UP, 0.07, shape="narrow", mat="olive_leaf", width=0.3, petiole=0.0)


def shrub(p, width=0.8, height=1.2, blossoms=None):
    """Strauch für Hecke und Beet: üppige runde Blatt-Büschel bis knapp über den Boden."""
    rnd = p.rnd
    centers = []
    for k in range(9):
        a = 2 * math.pi * k / 9 + rnd.uniform(-0.3, 0.3)
        centers.append(Vector((math.cos(a) * width * 0.3, math.sin(a) * width * 0.25, height * rnd.uniform(0.3, 0.7))))
    centers += [Vector((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.05), height * rnd.uniform(0.75, 0.85))) for _ in range(2)]
    for c in centers:
        cl = width * rnd.uniform(0.26, 0.32)
        leaf_ball(p, c, cl, 60, 0.13, rnd, mat=rnd.choice(("leaf", "box_leaf")), squash=(1.0, 1.0, 0.9), twig_from=Vector((0, 0, 0.02)),
                  stem_mat="bark", front_bias=0.2)
        if blossoms:
            for _ in range(5):
                d = rnd_dir(rnd)
                d.z = abs(d.z) * 0.8 + 0.1
                if blossoms == "rose":
                    rose(p, rnd.choice(("rose", "pink", "blush_flower")), c + d * cl * 1.02, d, 0.04)
                else:
                    floret(p, blossoms, c + d * cl * 1.02, d, 0.03, 5, cup=0.4)


def tree(p, height=5.8, crown=1.7, mat="leaf"):
    """Kleiner Laubbaum wie auf den Vorlagebildern: kräftiger, leicht geschwungener Stamm mit
    Wurzelanläufen, Äste in die Krone, große runde Krone aus vielen ineinander übergehenden
    Blatt-Büscheln mit großen Blättern."""
    rnd = p.rnd
    cz = height - crown * 0.95
    tz = cz - crown * 0.35
    thick = 0.17 if height > 4 else 0.085
    trunk = [Vector((0, 0, -0.05)), Vector((0.04, 0.02, tz * 0.35)), Vector((-0.05, 0.0, tz * 0.7)), Vector((0.0, 0.01, tz))]
    p.body("bark", vary=0.08).tube(trunk, lambda t: thick * (1 - 0.4 * t), segs=10, smooth=2, round_ends=True)
    k_root = 1.0 if height > 4 else 0.55
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.2, 0.2)
        p.body("bark", vary=0.08).tube([Vector((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.28 * k_root)),
                                        Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -0.04)) * k_root],
                                       lambda t: 0.065 * k_root * (1 - 0.6 * t), segs=6, round_ends=True)
    n = int(8 * crown / 1.7) + 3
    clusters = [Vector((0, 0, cz + crown * 0.15))]
    for k in range(n):
        d = rnd_dir(rnd)
        d.z = d.z * 0.7
        clusters.append(Vector((0, 0, cz)) + Vector((d.x * crown * 0.5, d.y * crown * 0.5, d.z * crown * 0.55 + crown * 0.05)))
    for c in clusters:
        branch_from = trunk[-1] + Vector((0, 0, rnd.uniform(-0.2, 0.1)))
        mid = branch_from.lerp(c, 0.5) + Vector((0, 0, 0.12))
        p.body("bark", vary=0.08).tube([branch_from, mid, c], lambda t: 0.05 * (crown / 1.7) * (1 - 0.6 * t), segs=6, smooth=1,
                                       round_ends=True)
        leaf_ball(p, c, crown * rnd.uniform(0.46, 0.55), int(210 * (crown / 1.7) ** 2) + 30, 0.27 * (crown / 1.7) ** 0.6, rnd,
                  mat=rnd.choice((mat, mat, "box_leaf")), shape="round", width=0.92, squash=(1.0, 1.0, 0.88), stem_mat="bark",
                  front_bias=0.1)


# --- Gefäße für Komplett-Pflanzen ---

def tub(M, coll, radius=0.36, height=0.5, seed=1):
    """Hölzerner Pflanzkübel (Fassform) mit Eisenbändern und Erde – für Bäumchen auf dem Platz."""
    rnd = random.Random(seed)
    b = Body("Kübel Holz", M["box"], coll, seed=seed, vary=0.08, bevel=0.006)
    n = 18
    for k in range(n):
        a0 = 2 * math.pi * k / n
        a1 = 2 * math.pi * (k + 0.92) / n
        prof_r = [radius * 0.88, radius, radius * 0.94]
        pts = []
        for j, z in enumerate((0.0, height * 0.5, height)):
            pts.append((prof_r[j], z))
        for j in range(2):
            pass
        am = (a0 + a1) / 2
        for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
            b.box((math.cos(am) * (r0 + r1) / 2, math.sin(am) * (r0 + r1) / 2, (z0 + z1) / 2),
                  (2 * radius * math.sin(math.pi / n) * 0.95, 0.03, z1 - z0 + 0.004), step=1, dent=0.002,
                  turn=(math.degrees(math.atan2(r0 - r1, z1 - z0)), 0, math.degrees(am) + 90))
    b.lathe([(0.0, 0.02), (radius * 0.86, 0.02), (radius * 0.86, 0.06), (0.0, 0.06)], (0, 0, 0), segs=24)
    b.build()
    ir = Body("Kübel Bänder", M["iron"], coll, seed=seed + 1, vary=0.03)
    for z, rr in ((height * 0.18, radius * 0.93), (height * 0.82, radius * 0.985)):
        ir.lathe([(0.0, 0.0), (rr + 0.012, 0.0), (rr + 0.016, 0.012), (rr + 0.012, 0.025), (0.0, 0.025)], (0, 0, z), segs=24)
    ir.build()
    e = Body("Kübel Erde", M["soil"], coll, seed=seed + 2)
    e.lathe([(0.0, 0.0), (radius * 0.9, 0.0), (radius * 0.88, 0.03), (0.0, 0.05)], (0, 0, height * 0.88), segs=20, dent=0.01)
    e.build()
    del rnd
    return height * 0.88 + 0.04


def plant_materials(M):
    """Zusätzliche Materialien für Pflanzen (Kern = Blattmasse im Inneren der Büschel, Blüten-Kerne für
    dichte Blütenköpfe)."""
    M["blue_flower_core"] = SC.make_material("Blütenkern Blau", (0.42, 0.48, 0.78), grain="fabric", rough=0.75, vary=0.1)
    M["pink_core"] = SC.make_material("Blütenkern Rosa", (0.86, 0.42, 0.55), grain="fabric", rough=0.75, vary=0.1)
    M["leaf_core"] = SC.make_material("Blattkern Grün", (0.2, 0.34, 0.13), grain="leaf", rough=0.85, vary=0.12)
    M["gold_flower"] = SC.make_material("Blüte Goldgelb", (0.93, 0.72, 0.25), grain="fabric", rough=0.7, vary=0.08, plant=True)
    M["fruit"] = SC.make_material("Frucht Orange", (0.95, 0.58, 0.2), grain="smooth", rough=0.5, vary=0.08, plant=True)
