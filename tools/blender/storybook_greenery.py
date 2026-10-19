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
    """Sammelt die Körper einer Pflanze (je Material ein Body). container = Lage des Gefäßrands
    (CONTAINERS): Teile, die in der Gefäßwand stecken würden, legt build() über den Rand."""

    def __init__(self, M, coll, seed, container=None):
        self.M, self.coll = M, coll
        self.rnd = random.Random(seed)
        self.bodies = {}
        self.seed = seed
        self.container = container

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
            if self.container:
                clear_rim(b.bm, self.container)
            o = b.build(smooth_angle=180)   # Pflanzen ganz weich schattiert, keine Kanten
            if sway_height:
                ca = o.data.color_attributes.get("tint")
                for k, v in enumerate(o.data.vertices):
                    w = max(0.0, min(1.0, v.co.z / sway_height))
                    c = ca.data[k].color
                    ca.data[k].color = (c[0], c[1], c[2], 1.0 - 0.85 * w * w)
            objs.append(o)
        return objs


# --- Einzelteile ---

def leaf_on(p, at, d, n, size, shape="oval", width=0.85, petiole=0.02, mat="leaf", stem_mat="stem", thick=None, curl=0.18, fan=None,
            segs=None):
    """Ein Blatt mit kurzem Stiel: Ansatz at, Richtung d, Blattoberseite n."""
    tip_base = at + d * petiole
    if petiole > 0.004:
        p.body(stem_mat, vary=0.06).tube([at, tip_base], max(0.0022, size * 0.04), segs=4)
    # genug Randpunkte für einen weichen, runden Umriss; dick und kissenförmig (kein Blatt Papier)
    if segs is None:
        segs = {"heart": 14, "round": 8, "oval": 7, "narrow": 5, "petal": 6, "cup": 6, "blade": 6, "ivy": None}.get(shape, 7)
        if size > 0.14 and segs and shape != "blade":
            segs += 3   # große Blätter (Funkie, Baum) noch runder
        elif size < 0.06 and segs and shape in ("oval", "round", "heart"):
            segs -= 4 if shape == "heart" else 2   # kleine Blätter: weich schattiert reichen weniger Randpunkte
    p.body(mat).leaf(tip_base, d, n, size, size * width, shape=shape, thick=thick or max(0.005, size * (0.07 if shape == "blade" else 0.16)),
                     curl=curl, segs=segs, fan=fan)
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
        # kleiner, dunkler Kern ganz innen: wirkt nur als Schatten zwischen den Blättern, nie als Kugel
        p.body("leaf_core", vary=0.1).blob(c, radius * 0.42, subdiv=2, lump=0.2, scale=squash)
    # etwas größere Blätter und so viele, dass sie den Kern rundum verdecken (Blattfläche ≈ 1,8 × die
    # Fläche der Hülle, auf der sie sitzen); höchstens 2,5 × so viele wie angegeben
    size *= 1.2
    area = 0.5 * size * size * width
    ax, ay, az = (radius * 0.84 * k for k in squash)
    shell = 4 * math.pi * (((ax * ay) ** 1.6 + (ax * az) ** 1.6 + (ay * az) ** 1.6) / 3) ** (1 / 1.6)
    n = max(int(n * 0.6 + 0.5), min(int(n * 2.4), int(2.0 * shell / area + 0.5)))
    for _ in range(n):
        d = rnd_dir(rnd)
        if d.z < -0.6:
            d.z = -d.z * 0.4
        d = (d + FRONT * front_bias * rnd.random() + UP * 0.12).normalized()
        sq = Vector((d.x * squash[0], d.y * squash[1], d.z * squash[2]))
        at = c + sq * radius * rnd.uniform(0.62, 0.85)
        tang = d.cross(UP)
        if tang.length < 0.1:
            tang = d.cross(Vector((1, 0, 0)))
        tang.normalize()
        s = size * rnd.uniform(0.8, 1.2)
        # schräg nach außen (etwa 30°), Oberseite nach außen und oben: runde Blattenden bilden den Umriss
        ld = (d * 0.55 + tang * rnd.uniform(-0.6, 0.6) - UP * rnd.uniform(0.0, 0.3)).normalized()
        nn = (d * 0.8 + UP * 0.35).normalized()
        leaf_on(p, at - ld * s * 0.15, ld, nn, s, shape=shape, mat=mat, stem_mat=stem_mat, width=width, petiole=0.0)


def floret(p, mat, center, normal, size, petals=5, cup=0.25, samples=None, notch=0.42):
    if samples is None and size < 0.03:
        samples = 4
    p.body(mat, vary=0.1).star(center, normal, size, petals, p.rnd, thick=max(0.004, size * 0.16), cup=cup, samples=samples, notch=notch)


def spike(p, mat, a, b, radius, n=8, segs=5):
    """Blütenähre (Lavendel, Heide) als ein weicher Körper: perlenartig gewellt, oben spitz zulaufend."""
    pts = [Vector(a).lerp(Vector(b), k / n) for k in range(n + 1)]
    p.body(mat, vary=0.1).tube(pts, lambda t: radius * (0.55 + 0.45 * abs(math.sin(t * math.pi * n * 0.5))) * (1.0 - 0.45 * t),
                               segs=segs, round_ends=True)


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
                   thick=size * 0.1, curl=curl, segs=6)
    b.blob(Vector(center) + n * size * 0.22, size * 0.2, subdiv=1, lump=0.15, scale=(1.0, 1.0, 1.0))


def umbel(p, mat, center, radius, up, count, size, petals=5, core=True):
    """Kugeliger Blütenkopf (Geranie, Hortensie): dicht gepackte Einzelblüten auf einer Halbkugel."""
    rnd = p.rnd
    # kleiner, dunkler Kern in Blütenfarbe ganz innen (nur Schatten zwischen den Blüten), darüber dicht
    # an dicht etwas größere, weiche Einzelblüten – rundum, auch von unten gesehen
    if core:
        p.body(mat, vary=0.05).blob(Vector(center), radius * 0.55, subdiv=2, lump=0.15, scale=(1.0, 1.0, 0.9), tint=(0.62, 0.6, 0.6))
    up = Vector(up).normalized()
    s1 = up.orthogonal().normalized()
    s2 = up.cross(s1)
    spin = rnd.uniform(0, 6.28)
    for i in range(count):
        # gleichmäßig verteilt von oben bis etwas unter die Mitte (unten sitzt der Stiel)
        z = 1.0 - 1.7 * (i + 0.5) / count
        rr = math.sqrt(max(0.0, 1 - z * z))
        a = spin + i * 2.39996
        d = (s1 * math.cos(a) * rr + s2 * math.sin(a) * rr + up * z + rnd_dir(rnd) * 0.12).normalized()
        c = Vector(center) + d * radius * rnd.uniform(0.92, 1.0)
        floret(p, mat, c, d, size * 1.2 * rnd.uniform(0.9, 1.1), petals)


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

def box_geranium(p, color, leaf_mat="leaf"):
    """Geranien im Kasten: üppiges Polster aus runden, gewellten Blättern über die ganze Breite,
    darüber zwei bis drei kugelige Blütenköpfe; vorn hängt eine Ranke über den Rand."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, -0.005, 0.07)), 0.1, 30, 0.085, rnd, mat=leaf_mat, shape="round", width=0.95, squash=(1.45, 0.75, 0.6),
              twig_from=Vector((0, 0, 0)))
    for k in range(rnd.randint(2, 3)):
        base = Vector(((k - 1) * 0.09 + rnd.uniform(-0.02, 0.02), rnd.uniform(-0.03, 0.02), 0.04))
        top = base + Vector((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.0), rnd.uniform(0.18, 0.26)))
        p.body("stem", vary=0.06).tube([base, base.lerp(top, 0.5) + Vector((0, -0.01, 0)), top], 0.0045, segs=5, smooth=1, round_ends=True)
        umbel(p, color, top, rnd.uniform(0.06, 0.072), UP, rnd.randint(10, 12), 0.033)
    if rnd.random() < 0.7:
        trail(p, rnd.uniform(-0.1, 0.1), rnd.uniform(0.18, 0.32), rnd, leaf=0.05)


def box_petunia(p, colors, leaf_mat="leaf"):
    """Hängepetunien: dichtes Polster aus ovalen Blättern und Trichterblüten, viele Ranken fallen
    vorn weit über den Rand."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, -0.005, 0.065)), 0.11, 26, 0.06, rnd, mat=leaf_mat, shape="oval", squash=(1.35, 0.75, 0.55),
              twig_from=Vector((0, 0, 0)))
    for _ in range(9):
        d = rnd_dir(rnd)
        d.z = abs(d.z) * 0.6 + 0.2
        c = Vector((0, -0.01, 0.07)) + Vector((d.x * 0.14, d.y * 0.07, d.z * 0.08))
        floret(p, rnd.choice(colors), c, d, rnd.uniform(0.026, 0.034), petals=5, cup=0.45)
    for k in range(4):
        trail(p, -0.12 + 0.08 * k + rnd.uniform(-0.02, 0.02), rnd.uniform(0.22, 0.4), rnd, leaf_mat=leaf_mat, shape="oval",
              leaf=0.036, flowers=colors, flower_size=0.028)


def box_mixed(p):
    """Gemischter Kasten: Lavendelähren, weiße Margeriten und Efeu, das über den Rand fällt."""
    rnd = p.rnd
    for k in range(5):
        base = Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.02, 0.04), 0.0))
        for _ in range(5):
            top = base + Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.04, 0.03), rnd.uniform(0.2, 0.3)))
            p.body("stem", vary=0.06).tube([base, base.lerp(top, 0.62)], 0.0025, segs=4)
            spike(p, "lilac", base.lerp(top, 0.6), top, 0.011)
        for _ in range(5):
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.6, 0.6), 0.3)).normalized()
            leaf_on(p, base + d * 0.02, (d + UP).normalized(), UP, 0.06, shape="narrow", mat="leaf_silver", petiole=0.0, width=0.4)
    for _ in range(3):
        c = Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.05, 0.0), rnd.uniform(0.1, 0.16)))
        p.body("stem", vary=0.06).tube([Vector((c.x, c.y + 0.02, 0.0)), c], 0.003, segs=4)
        daisy_head(p, c, Vector((rnd.uniform(-0.3, 0.3), -0.5, 1.0)), 0.03)
    trail(p, rnd.uniform(-0.1, 0.1), 0.35, rnd, leaf=0.045)


# --- Kübel- und Topfpflanzen (Topf-Radius 0,2 m; im Spiel passend skaliert) ---

def bush(p, radius=0.22, height=0.42, mat="box_leaf", leaf=0.05, density=1.0, blossoms=None, mats=None):
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
        leaf_ball(p, c, cl, int(40 * density), leaf * 1.5, rnd, mat=rnd.choice(mats) if mats else mat, squash=(1.0, 1.0, 0.92),
                  twig_from=base + UP * 0.02, stem_mat="bark", front_bias=0.2)
        if blossoms and rnd.random() < 0.8:
            for _ in range(5):
                d = rnd_dir(rnd)
                d.z = abs(d.z)
                floret(p, blossoms, c + d * cl * 1.02, d, leaf * 0.7, petals=5, cup=0.35)


def hydrangea(p, color, size=1.0, leaf_mat="leaf"):
    """Hortensie: rundes Polster aus großen, ovalen Blättern, darauf fünf bis sieben große,
    halbkugelige Blütenköpfe aus vielen vierblättrigen Blüten."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, 0, 0.16 * size)), 0.18 * size, 34, 0.11 * size, rnd, mat=leaf_mat, shape="oval", width=0.75,
              squash=(1.15, 1.15, 0.8), twig_from=Vector((0, 0, 0.0)), front_bias=0.15)
    for k in range(rnd.randint(5, 7)):
        a = 2 * math.pi * k / 6 + rnd.uniform(-0.3, 0.3)
        r = 0.11 if k else 0.0
        top = Vector((math.cos(a) * r, math.sin(a) * r * 0.9 - 0.02, rnd.uniform(0.3, 0.36))) * size
        p.body("stem", vary=0.06).tube([Vector((0, 0, 0)), top * 0.5 + Vector((0, 0, 0.03)), top], 0.006, segs=5, smooth=1)
        p.body(color, vary=0.06).blob(top + UP * 0.02 * size, 0.045 * size, subdiv=2, lump=0.15, scale=(1.0, 1.0, 0.75), tint=(0.62, 0.62, 0.66))
        umbel(p, color, top + UP * 0.03 * size, rnd.uniform(0.075, 0.09) * size, UP, int(26 * size), 0.03 * size, petals=4, core=False)


def olive(p, height=0.85, crown_r=0.26):
    """Olivenbäumchen: leicht gedrehter Stamm, Äste in eine lockere, buschige Krone aus vielen Büscheln
    schmaler, silbriger Blätter – ohne Kugeln."""
    rnd = p.rnd
    t = [Vector((0, 0, 0)), Vector((0.02, 0.01, height * 0.3)), Vector((-0.015, 0.0, height * 0.55)), Vector((0.0, 0.0, height * 0.66))]
    p.body("bark", vary=0.08).tube(t, lambda u: 0.028 * (1 - 0.4 * u), segs=8, smooth=2, round_ends=True)
    top = t[-1]
    lobes = [(top + UP * crown_r * 0.95, crown_r * 0.55)]
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.3, 0.3)
        lobes.append((top + Vector((math.cos(a) * crown_r * 0.62, math.sin(a) * crown_r * 0.62, crown_r * rnd.uniform(0.25, 0.7))),
                      crown_r * rnd.uniform(0.45, 0.55)))
    crown(p, top, lobes, rnd, leaf=0.085, mats=("olive_leaf", "olive_leaf", "leaf_silver"), shape="narrow", width=0.32, per_spray=7,
          density=1.25, limb=0.018, limbs=4, inner=0.15)


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


def trailing(p, colors, ranks=10, leaf_mat="leaf", shape="oval", petals=5, bells=None):
    """Ampel-Füllung: Polster in der Mitte, Ranken mit Blüten fallen rundherum über den Rand."""
    rnd = p.rnd
    c = p.container or CONTAINERS["basket"]
    leaf_ball(p, Vector((0, 0, 0.06)), c["inner"] * 0.9, 30, 0.055, rnd, mat=leaf_mat, shape=shape, squash=(1.0, 1.0, 0.6),
              twig_from=Vector((0, 0, 0)))
    if colors:
        for _ in range(20):
            d = rnd_dir(rnd)
            d.z = abs(d.z) * 0.6 + 0.2
            d.normalize()
            floret(p, rnd.choice(colors), Vector((0, 0, 0.07)) + Vector((d.x, d.y, d.z * 0.6)) * c["inner"] * 0.95, d,
                   rnd.uniform(0.03, 0.038), petals, cup=0.45)
    for k in range(ranks):
        a = 2 * math.pi * k / ranks + rnd.uniform(-0.2, 0.2)
        if k % 3 == 0:
            trail(p, a, rnd.uniform(0.25, 0.5), rnd, leaf=0.05)
        else:
            trail(p, a, rnd.uniform(0.15, 0.42), rnd, leaf_mat=leaf_mat, shape=shape, leaf=0.042, flowers=colors, flower_size=0.03,
                  petals=petals, bells=bells)


# --- Kletterpflanzen (Wand bei y = 0, wachsen vor der Wand nach oben) ---

def along(pts, step):
    """Punkte im Abstand step entlang einer Punktfolge, je mit Richtung."""
    out = []
    left = step * 0.5
    for a, b in zip(pts, pts[1:]):
        seg = b - a
        L = seg.length
        if L < 1e-6:
            continue
        t = seg / L
        pos = left
        while pos < L:
            out.append((a + t * pos, t))
            pos += step
        left = pos - L
    return out


def climber(p, width, height, kind="ivy", flower=None):
    """Kletterpflanze als wilde Ranke (wie im Bilderbuch): aus einem Pflanzloch am Boden wachsen
    verholzte Haupttriebe in Bögen und schrägen Schwüngen die Wand hoch, ungleich verteilt; Seitentriebe
    schwingen zur Seite, manche verzweigen sich, manche hängen herab; oben fallen einzelne Ranken wieder
    nach unten. An allen Trieben sitzen pralle Blätter an kurzen Stielen in kleinen Büscheln (Efeu:
    Herzblätter; Rose: ovale Blätter und Rosen; Glyzinie: helle Blätter und hängende Trauben; Clematis:
    große sternförmige Blüten). Alles bleibt vor der Wand (y < -0,1) und in der Breite."""
    rnd = p.rnd
    leaf_mat = {"ivy": "ivy", "rose": "leaf_dark", "wisteria": "ivy_young", "clematis": "leaf"}[kind]
    stem_mat = "bark" if kind in ("wisteria", "rose") else "stem"
    shape = "heart" if kind == "ivy" else "oval"
    leaf_w = 0.95 if kind == "ivy" else 0.62
    base_size = {"ivy": 0.12, "rose": 0.095, "wisteria": 0.09, "clematis": 0.09}[kind]
    half = width / 2
    p.body("soil", vary=0.08).lathe([(0.0, 0.0), (0.17, 0.0), (0.16, 0.02), (0.0, 0.035)], Vector((0, -0.18, 0.0)), segs=10, dent=0.006)

    def wall(q, margin=0.05):
        q.x = max(-half + margin, min(half - margin, q.x))
        q.y = min(q.y, -0.1)
        return q

    mains = max(2, int(round(width / 0.42))) + rnd.choice((0, 0, 1))
    shoots = []
    for k in range(mains):
        target_x = rnd.uniform(-half * 0.85, half * 0.85)
        pts = [Vector((rnd.uniform(-0.06, 0.06), -0.17, 0.0))]
        d = Vector((target_x * 0.4, 0.25, 1.0)).normalized()
        h = height * rnd.uniform(0.6, 0.97)
        swing = rnd.uniform(1.2, 2.6)
        phase = rnd.uniform(0, 6.28)
        amp = rnd.uniform(0.25, 0.55)
        while pts[-1].z < h and len(pts) < 200:
            z = pts[-1].z
            # schräge Schwünge statt gerader Säulen: die Ranke pendelt um ihr Ziel
            want_x = target_x * min(1.0, z / (h * 0.35)) + math.sin(z * swing + phase) * min(0.3, width * 0.22)
            lateral = (want_x - pts[-1].x) * 0.9 + math.sin(z * swing * 1.7 + phase) * amp + rnd.uniform(-0.3, 0.3)
            d = (d + Vector((lateral, 0.0, 0.75))).normalized()
            q = pts[-1] + d * 0.1
            q.y = max(-0.14, min(-0.1, q.y + 0.03))
            pts.append(wall(q, 0.08))
        p.body(stem_mat, vary=0.06).tube(pts, lambda t: 0.016 * (1 - 0.6 * t), segs=6, smooth=1, round_ends=True)
        shoots.append((pts, True))
        i = rnd.randint(2, 3)
        while i < len(pts) - 1:
            side = rnd.choice((-1, 1))
            droop = rnd.random() < 0.3
            sd = Vector((side, -0.05, rnd.uniform(-0.6, -0.2) if droop else rnd.uniform(-0.1, 0.8)))
            sp = stem_path(pts[i], sd, rnd.uniform(0.3, 0.75), rnd, step=0.06, bend=0.35,
                           gravity=0.35 if droop else (0.05 if kind != "wisteria" else 0.2), wall=-0.1)
            sp = [wall(q) for q in sp]
            p.body(stem_mat, vary=0.06).tube(sp, lambda t: 0.0065 * (1 - 0.5 * t), segs=4, smooth=1, round_ends=True)
            shoots.append((sp, False))
            if len(sp) > 5 and rnd.random() < 0.45:
                j = rnd.randint(2, len(sp) - 2)
                sub = stem_path(sp[j], Vector((rnd.uniform(-0.5, 0.5), -0.05, rnd.uniform(-0.8, 0.8))), rnd.uniform(0.18, 0.35), rnd,
                                step=0.05, bend=0.4, gravity=0.15, wall=-0.1)
                sub = [wall(q) for q in sub]
                p.body(stem_mat, vary=0.06).tube(sub, lambda t: 0.0045 * (1 - 0.5 * t), segs=4, smooth=1, round_ends=True)
                shoots.append((sub, False))
            i += rnd.randint(2, 4)
        # oben fallen einzelne Ranken wieder herab
        for _ in range(rnd.randint(0, 2)):
            j = rnd.randint(len(pts) // 2, len(pts) - 1)
            hang = stem_path(pts[j], Vector((rnd.uniform(-1, 1), -0.3, -0.4)), rnd.uniform(0.35, 0.8), rnd, step=0.06, bend=0.2,
                             gravity=0.6, wall=-0.1)
            hang = [wall(q) for q in hang]
            p.body(stem_mat, vary=0.06).tube(hang, lambda t: 0.0045 * (1 - 0.5 * t), segs=4, smooth=1, round_ends=True)
            shoots.append((hang, False))
    # Blätter: einzeln an kurzen Stielen, abwechselnd links/rechts, in Büscheln; Größe und Dichte
    # wechseln (unten dichter, an den Spitzen kleiner und heller)
    n_leaf = 0
    for pts, main in shoots:
        nodes = along(pts, rnd.uniform(0.075, 0.095) if main else rnd.uniform(0.065, 0.085))
        for i, (q, t) in enumerate(nodes):
            tip = i / max(1, len(nodes) - 1)
            fade = 1.0 - 0.15 * q.z / max(0.1, height) - (0.25 * tip if not main else 0.0)
            side = 1 if i % 2 else -1
            perp = Vector((-t.z, 0.0, t.x))
            perp = (perp.normalized() if perp.length > 1e-3 else Vector((1.0, 0.0, 0.0))) * side
            count = rnd.choice((1, 2, 3)) if main else rnd.choice((1, 2, 2))
            if q.z < 0.8:
                count += 1
            for j in range(count):
                s_ = base_size * rnd.uniform(0.7, 1.2) * fade
                dirn = (perp * rnd.uniform(0.5, 1.0) + t * rnd.uniform(-0.3, 0.6) + Vector((0, -rnd.uniform(0.15, 0.5), 0))
                        - UP * rnd.uniform(0.0, 0.4)).normalized()
                if abs(q.x + dirn.x * s_ * 1.2) > half - 0.02:
                    dirn.x = -dirn.x   # am Rand nach innen
                nrm = Vector((rnd.uniform(-0.4, 0.4), -1.0, rnd.uniform(0.0, 0.7))).normalized()
                at = q + Vector((0, -0.012 - 0.02 * ((n_leaf + j) % 3), 0))
                young = kind == "ivy" and (tip > 0.7 or rnd.random() < 0.15)
                leaf_on(p, at, dirn, nrm, s_, shape=shape, mat="ivy_young" if young else leaf_mat, stem_mat="stem",
                        petiole=rnd.uniform(0.012, 0.024), width=leaf_w * rnd.uniform(0.92, 1.06), curl=rnd.uniform(0.06, 0.2))
            n_leaf += 1
    for pts, main in shoots:
        for i in range(1, len(pts)):
            q = pts[i]
            if kind == "rose" and rnd.random() < (0.2 if main else 0.3):
                c = q + Vector((rnd.uniform(-0.06, 0.06), -0.1, rnd.uniform(-0.03, 0.04)))
                rose(p, rnd.choice(flower or ("rose", "pink", "blush_flower")), c,
                     Vector((rnd.uniform(-0.3, 0.3), -1, 0.35)).normalized(), rnd.uniform(0.055, 0.075))
            if kind == "clematis" and rnd.random() < (0.16 if main else 0.28):
                c = q + Vector((rnd.uniform(-0.05, 0.05), -0.09, rnd.uniform(-0.03, 0.03)))
                col = rnd.choice(flower or ("purple_flower", "lilac"))
                floret(p, col, c, Vector((rnd.uniform(-0.3, 0.3), -1, 0.3)).normalized(), rnd.uniform(0.055, 0.07), 6, cup=0.12,
                       samples=5, notch=0.3)
                p.body("cream_flower", vary=0.05).blob(c + Vector((0, -0.012, 0)), 0.012, subdiv=1, lump=0.1)
            if kind == "wisteria" and main and i % 3 == 0 and rnd.random() < 0.65 and q.z > 0.8:
                L = rnd.uniform(0.22, 0.36)
                top = q + Vector((0, -0.12, -0.04))
                p.body("stem", vary=0.06).tube([q, top, top - UP * L], 0.003, segs=4)
                for j in range(9):
                    tt = j / 8
                    c = top - UP * L * tt + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 0.3), 0)) * 0.03 * (1 - tt * 0.6)
                    floret(p, rnd.choice(flower or ("lilac", "lilac", "blue_flower")), c, rnd_dir(rnd), 0.022 * (1 - 0.4 * tt), petals=4,
                           cup=0.3)


# --- Beete, Hecke, Bäume ---

def hosta(p, size=1.0, mats=("leaf", "box_leaf")):
    """Funkie: breite Herzblätter an langen Stielen, die rundherum nach außen überhängen."""
    rnd = p.rnd
    for k in range(int(16 * size) + 6):
        a = 2 * math.pi * k / 18 + rnd.uniform(-0.25, 0.25)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        up_k = rnd.uniform(0.7, 1.4)
        at = out * 0.08 * size + UP * 0.12 * size * up_k
        p.body("stem", vary=0.06).tube([out * 0.01, out * 0.04 * size + UP * 0.08 * size * up_k, at], 0.0055, segs=4, smooth=1)
        leaf_on(p, at, (out + UP * rnd.uniform(0.25, 1.0)).normalized(), (UP + out * 0.25).normalized(), rnd.uniform(0.15, 0.21) * size,
                shape="heart", mat=rnd.choice(mats), petiole=0.0, width=0.9, curl=-0.12)


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
    lavender_bush(p)


def shrub(p, width=0.8, height=1.2, blossoms=None, mats=("leaf", "box_leaf")):
    """Strauch für Hecke und Beet: üppige runde Blatt-Büschel bis knapp über den Boden."""
    rnd = p.rnd
    centers = []
    for k in range(9):
        a = 2 * math.pi * k / 9 + rnd.uniform(-0.3, 0.3)
        centers.append(Vector((math.cos(a) * width * 0.3, math.sin(a) * width * 0.25, height * rnd.uniform(0.3, 0.7))))
    centers += [Vector((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.05), height * rnd.uniform(0.75, 0.85))) for _ in range(2)]
    for c in centers:
        cl = width * rnd.uniform(0.26, 0.32)
        leaf_ball(p, c, cl, 60, 0.13, rnd, mat=rnd.choice(mats), squash=(1.0, 1.0, 0.9), twig_from=Vector((0, 0, 0.02)),
                  stem_mat="bark", front_bias=0.2)
        if blossoms:
            for _ in range(5):
                d = rnd_dir(rnd)
                d.z = abs(d.z) * 0.8 + 0.1
                if blossoms == "rose":
                    rose(p, rnd.choice(("rose", "pink", "blush_flower")), c + d * cl * 1.02, d, 0.04)
                elif blossoms in ("hydrangea_blue", "hydrangea_pink"):
                    if rnd.random() < 0.5:
                        col = "blue_flower" if blossoms == "hydrangea_blue" else "pink"
                        umbel(p, col, c + d * cl * 0.95, rnd.uniform(0.07, 0.09), d, 20, 0.03, petals=4)
                else:
                    floret(p, blossoms, c + d * cl * 1.02, d, 0.03, 5, cup=0.4)


def tree(p, height=5.0, crown_r=1.45, mats=("leaf", "leaf", "leaf_dark")):
    """Laubbaum (für Platz und Beete): kräftiger, leicht geschwungener Stamm mit Wurzelanläufen, Äste
    in eine runde, wolkige Krone aus vielen Blattbüscheln – ohne Kugelkern."""
    rnd = p.rnd
    fz = height - crown_r * 1.7
    t = [Vector((0, 0, -0.05)), Vector((0.04, 0.02, fz * 0.4)), Vector((-0.04, 0.0, fz * 0.75)), Vector((0.0, 0.01, fz))]
    trunk(p, t, 0.16, rnd)
    fork = t[-1]
    cz = height - crown_r
    lobes = [(Vector((0, 0, cz + crown_r * 0.3)), crown_r * 0.6)]
    for k in range(6):
        a = 2 * math.pi * k / 6 + rnd.uniform(-0.3, 0.3)
        lobes.append((Vector((math.cos(a) * crown_r * 0.55, math.sin(a) * crown_r * 0.55, cz - crown_r * 0.1 + rnd.uniform(-0.2, 0.25))),
                      crown_r * rnd.uniform(0.5, 0.62)))
    crown(p, fork, lobes, rnd, leaf=0.21, mats=mats, limb=0.07, density=1.6)


# Gartenhof hinter der Bücherei: erlaubter Raum der Krone in Pflanzen-Koordinaten (Ursprung = Stamm,
# Blender x/y). Mauern, Dächer und Giebelhäuser liegen außerhalb (aus layout.json, siehe
# build_storybook_alleys: Hof x -9,2 … -3,2, z 9,9 … Giebelhäuser 18,4; Stamm bei x -7,7, z 12,92).
GARDEN_BOUNDS = ((-1.3, 4.3), (-4.6, 2.8), (2.9, 10.2))


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
    """Zusätzliche Materialien für Pflanzen: Kerne, Grüntöne (dunkel, blaugrün, gelbgrün, silbrig,
    bronze, Gras) und natürliche Blütenfarben."""
    mk = SC.make_material
    M["blue_flower_core"] = mk("Blütenkern Blau", (0.3, 0.34, 0.58), grain="fabric", rough=0.75, vary=0.1)
    M["pink_core"] = mk("Blütenkern Rosa", (0.62, 0.3, 0.4), grain="fabric", rough=0.75, vary=0.1)
    M["leaf_core"] = mk("Blattkern Grün", (0.12, 0.21, 0.08), grain="leaf", rough=0.85, vary=0.12)
    leaf = dict(grain="leaf", rough=0.7, vary=0.12, plant=True)
    for key, name, col in (("leaf_dark", "Blatt Dunkelgrün", (0.15, 0.3, 0.12)), ("leaf_blue", "Blatt Blaugrün", (0.3, 0.45, 0.37)),
                           ("leaf_lime", "Blatt Gelbgrün", (0.5, 0.63, 0.22)), ("leaf_silver", "Blatt Silbergrau", (0.56, 0.62, 0.52)),
                           ("leaf_bronze", "Blatt Bronze", (0.3, 0.14, 0.17)), ("grass_leaf", "Grashalm", (0.42, 0.56, 0.24))):
        M[key] = mk(name, col, **leaf)
    bloom = dict(grain="leaf", rough=0.7, vary=0.1, plant=True)
    for key, name, col in (("gold_flower", "Blüte Goldgelb", (0.93, 0.72, 0.25)), ("yellow_flower", "Blüte Zitronengelb", (0.97, 0.84, 0.36)),
                           ("orange_flower", "Blüte Orange", (0.95, 0.52, 0.2)), ("peach_flower", "Blüte Pfirsich", (0.98, 0.72, 0.58)),
                           ("purple_flower", "Blüte Violett", (0.48, 0.27, 0.6)), ("magenta_flower", "Blüte Magenta", (0.78, 0.24, 0.5)),
                           ("burgundy_flower", "Blüte Weinrot", (0.48, 0.1, 0.17)), ("sky_flower", "Blüte Himmelblau", (0.58, 0.72, 0.92)),
                           ("white_flower", "Blüte Weiß", (0.95, 0.94, 0.9)), ("brown_disc", "Blütenmitte Braun", (0.3, 0.19, 0.1))):
        M[key] = mk(name, col, **bloom)
    M["fruit"] = mk("Frucht Orange", (0.95, 0.58, 0.2), grain="smooth", rough=0.5, vary=0.08, plant=True)
    M["fruit_lemon"] = mk("Frucht Zitrone", (0.97, 0.85, 0.3), grain="smooth", rough=0.5, vary=0.08, plant=True)


def clear_rim(bm, c):
    """Nichts steckt in der Gefäßwand: jedes Teil (Blatt, Blüte, Stiel), das unterhalb der Randhöhe in
    der Wand läge, wird über den Rand gehoben (liegt es innen) bzw. nach außen geschoben (hängt es
    außen herab)."""
    seen = set()
    for v0 in bm.verts:
        if v0 in seen:
            continue
        isl, stack = [], [v0]
        seen.add(v0)
        while stack:
            v = stack.pop()
            isl.append(v)
            for e in v.link_edges:
                w = e.other_vert(v)
                if w not in seen:
                    seen.add(w)
                    stack.append(w)
        _clear_island(isl, c)


def _clear_island(isl, c):
    lim = c["rim_h"] + 0.006
    low = [v for v in isl if v.co.z < lim]
    if not low:
        return
    n = len(isl)
    cen = Vector((sum(v.co.x for v in isl) / n, sum(v.co.y for v in isl) / n, 0.0))
    move = None
    if c["kind"] == "round":
        def rho(v):
            return math.hypot(v.co.x, v.co.y)
        band = [v for v in low if c["inner"] - 0.004 < rho(v) < c["rim_r"] + 0.02]
        if not band:
            return
        if cen.length > c["rim_r"]:
            need = c["rim_r"] + 0.024 - min(rho(v) for v in band)
            move = cen.normalized() * need
        else:
            move = UP * (lim - min(v.co.z for v in band))
    else:
        yf, yi, yb = -c["front"], -c["inner"], c["inner"]
        front = [v for v in low if yf - 0.012 < v.co.y < yi + 0.004]
        back = [v for v in low if yb - 0.004 < v.co.y < c["back"] + 0.012]
        if front:
            if cen.y < yf:
                move = Vector((0.0, (yf - 0.024) - max(v.co.y for v in front), 0.0))
            else:
                move = UP * (lim - min(v.co.z for v in front))
        elif back:
            move = UP * (lim - min(v.co.z for v in back))
    if move is not None:
        for v in isl:
            v.co += move


# Lage des Gefäßrands in Pflanzen-Koordinaten (Ursprung = Erde, so wie Greenery die Pflanze einsetzt):
# inner = Innenwand, rim_r/front = Außenkante des Rands, rim_h = Oberkante über der Erde.
CONTAINERS = {
    "box": {"kind": "box", "inner": 0.078, "front": 0.12, "back": 0.105, "rim_h": 0.045, "half_w": 0.14},
    "potfill": {"kind": "round", "inner": 0.182, "rim_r": 0.218, "rim_h": 0.035},
    "basket": {"kind": "round", "inner": 0.155, "rim_r": 0.19, "rim_h": 0.035},
    "pot": {"kind": "round", "inner": 0.205, "rim_r": 0.245, "rim_h": 0.045},
    "tub": {"kind": "round", "inner": 0.31, "rim_r": 0.36, "rim_h": 0.03},
}


def drape(p, at, length, rnd, gravity=0.4):
    """Weg einer Ranke, die über den Gefäßrand fällt: innen aus der Erde hoch, über den Rand und außen
    herab – nie durch die Wand. at = Richtung (rund: Winkel in rad) bzw. Lage quer (Kasten: x).
    Liefert die Punkte und die Funktion keep(q), die einen Punkt außen vor der Wand hält."""
    c = p.container or CONTAINERS["potfill"]
    h = c["rim_h"]
    if c["kind"] == "round":
        out = Vector((math.cos(at), math.sin(at), 0.0))
        r0 = c["rim_r"]
        pts = [out * (c["inner"] - 0.06) + UP * 0.004, out * (c["inner"] - 0.012) + UP * (h + 0.022),
               out * (r0 + 0.006) + UP * (h + 0.03), out * (r0 + 0.045) + UP * (h - 0.004)]

        def keep(q):
            rr = math.hypot(q.x, q.y)
            if q.z < h + 0.03 and rr < r0 + 0.04:
                k = (r0 + 0.04) / max(rr, 1e-4)
                q.x *= k
                q.y *= k
            return q
        down = (out * 0.9 - UP * 0.5).normalized()
    else:
        out = Vector((rnd.uniform(-0.25, 0.25), -1.0, 0.0)).normalized()
        yf, hw = -c["front"], c["half_w"]
        x = max(-hw, min(hw, at))
        pts = [Vector((x, -c["inner"] + 0.05, 0.004)), Vector((x, -c["inner"] + 0.008, h + 0.022)),
               Vector((x + out.x * 0.02, yf - 0.004, h + 0.03)), Vector((x + out.x * 0.04, yf - 0.04, h - 0.006))]

        def keep(q):
            if q.z < h + 0.03 and q.y > yf - 0.04:
                q.y = yf - 0.04
            q.x = max(-hw - 0.02, min(hw + 0.02, q.x))
            return q
        down = (out * 0.8 - UP * 0.55).normalized()
    rest = stem_path(pts[-1], down, length, rnd, step=0.035, bend=0.24, gravity=gravity * 0.75)[1:]
    pts += [keep(q) for q in rest]
    return pts, keep


def trail(p, at, length, rnd, leaf_mat="ivy", shape="heart", leaf=0.042, flowers=None, flower_size=0.026, bells=None,
          petals=5, every=1, stem="stem"):
    """Hängende Ranke über den Gefäßrand mit Blättern (und Blüten bzw. Glöckchen) an den Knoten."""
    pts, keep = drape(p, at, length, rnd)
    p.body(stem, vary=0.06).tube(pts, lambda t: 0.0038 * (1 - 0.5 * t), segs=4, smooth=1, round_ends=True)
    n = len(pts)
    for i, q in enumerate(pts[3:], 3):
        if (i - 3) % every:
            continue
        t = i / n
        prev = pts[i - 1]
        tang = (q - prev).normalized()
        side = tang.cross(UP)
        side = side.normalized() if side.length > 1e-3 else Vector((1, 0, 0))
        out = Vector((q.x, q.y, 0.0))
        out = out.normalized() if out.length > 1e-3 else FRONT
        nrm = (out + UP * 0.6).normalized()
        for sg in ((1, -1) if rnd.random() < 0.4 else ((1 if i % 2 else -1),)):
            d = (side * sg * 0.8 + tang * 0.3 + out * 0.25 + Vector((0, 0, -0.15))).normalized()
            leaf_on(p, q, d, nrm, leaf * (1 - 0.3 * t) * rnd.uniform(0.85, 1.2), shape=shape, mat=leaf_mat, petiole=0.008, width=0.9)
        if flowers and rnd.random() < 0.65:
            floret(p, rnd.choice(flowers), keep(q + d * 0.02 + out * 0.012), (d + out).normalized(), flower_size * rnd.uniform(0.85, 1.1),
                   petals, cup=0.4)
        if bells and rnd.random() < 0.5:
            bell(p, bells[0], bells[1], keep(q + side * sg * 0.015 - UP * 0.02), 0.026)
    return pts


def twig(p, start, d, length, rnd, leaf_mat, leaf=0.05, pairs=6, width=0.35, shape="narrow", stem_mat="stem", droop=0.25,
         flowers=None):
    """Zweig mit gegenständigen Blättern (Olive, Rosmarin, Lorbeer): Blätter schräg nach vorn, oben
    dunkler Glanz, an der Spitze kleiner."""
    pts = stem_path(start, d, length, rnd, step=length / 5, bend=0.18, gravity=droop * 0.3)
    p.body(stem_mat, vary=0.06).tube(pts, lambda t: 0.0045 * (1 - 0.5 * t), segs=4, smooth=1, round_ends=True)
    for i, (q, t) in enumerate(along(pts, length / (pairs + 0.5))):
        k = i / max(1, pairs)
        side = t.cross(UP)
        side = side.normalized() if side.length > 1e-3 else Vector((1, 0, 0))
        nrm = t.cross(side).normalized()
        if nrm.z < 0:
            nrm = -nrm
        for sg in (-1, 1):
            dd = (t * 0.75 + side * sg * 0.65 - UP * droop * 0.3).normalized()
            leaf_on(p, q, dd, nrm, leaf * (1 - 0.35 * k) * rnd.uniform(0.85, 1.12), shape=shape, mat=leaf_mat, width=width, petiole=0.0,
                    curl=0.12)
    tip = pts[-1]
    leaf_on(p, tip, (pts[-1] - pts[-2]).normalized(), UP, leaf * 0.7, shape=shape, mat=leaf_mat, width=width, petiole=0.0)
    if flowers:
        floret(p, flowers, tip, (pts[-1] - pts[-2]).normalized(), 0.014, 5, cup=0.3)
    return pts


def lavender_bush(p, color="lilac", spikes=48, height=0.5, leaf_mat="leaf_silver"):
    """Lavendel als dichter Busch: graugrünes Polster aus vielen schmalen Blättchen, darüber ein Fächer
    aus Stielen mit Ähren, die nach außen auseinanderfallen (Topf sieht man kaum noch)."""
    rnd = p.rnd
    for _ in range(150):
        d = rnd_dir(rnd)
        d.z = abs(d.z) * 0.7 + 0.15
        d.normalize()
        at = Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), 0.0)) + d * rnd.uniform(0.03, 0.13) + UP * rnd.uniform(0.0, 0.1)
        leaf_on(p, at, (d + UP * 0.5).normalized(), (UP * 0.6 + d * 0.4).normalized(), rnd.uniform(0.045, 0.07), shape="narrow", width=0.32,
                petiole=0.0, mat=leaf_mat)
    for _ in range(spikes):
        a = rnd.uniform(0, 2 * math.pi)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        base = out * rnd.uniform(0.0, 0.05) + UP * 0.02
        d = (out * rnd.uniform(0.08, 0.6) + UP).normalized()
        L = height * rnd.uniform(0.7, 1.05)
        bend = out * 0.06 * L
        top = base + d * L + bend
        knee = base + d * L * 0.68 + bend * 0.5
        p.body("stem", vary=0.06).tube([base, base + d * L * 0.35, knee], 0.0022, segs=3, smooth=0)
        spike(p, color, knee, top, 0.011 * rnd.uniform(0.85, 1.1))


def spray(p, base, out, n, size, rnd, mats, shape="round", width=0.9, spread=0.85, stem="bark", flowers=None, fruit=None):
    """Blattbüschel am Ende eines Zweigs: kurzer Zweig, daran n Blätter fächerförmig nach außen (die
    Oberseite zeigt nach außen und oben). Bausteine für Baumkronen ohne Kern."""
    tip = base + out * size * 1.1
    p.body(stem, vary=0.06).tube([base, tip], 0.006 + size * 0.02, segs=4)
    s1 = out.orthogonal().normalized()
    s2 = out.cross(s1)
    for j in range(n):
        a = 2 * math.pi * j / n + rnd.uniform(-0.4, 0.4)
        k = rnd.uniform(0.35, 1.0)
        d = (out * rnd.uniform(0.45, 0.9) + (s1 * math.cos(a) + s2 * math.sin(a)) * spread * k - UP * rnd.uniform(0.0, 0.3)).normalized()
        at = base.lerp(tip, rnd.uniform(0.15, 1.0))
        nrm = (out * 0.6 + UP * 0.6).normalized()
        leaf_on(p, at, d, nrm, size * rnd.uniform(0.8, 1.2), shape=shape, width=width, petiole=0.0, mat=rnd.choice(mats), fan=True,
                curl=rnd.uniform(0.1, 0.25), segs=7 if shape in ("round", "oval") else None)
    if flowers and rnd.random() < 0.5:
        floret(p, rnd.choice(flowers), tip + out * 0.01, out, size * 0.35, 5, cup=0.3)
    if fruit and rnd.random() < 0.35:
        p.body(fruit, vary=0.08).blob(tip - UP * size * 0.4 + out * size * 0.2, size * 0.32, subdiv=2, lump=0.05, scale=(1.0, 1.0, 1.08))


def crown(p, fork, lobes, rnd, leaf=0.2, mats=("leaf",), shape="round", width=0.9, per_spray=9, density=1.3, inside=None,
          limb=0.08, flowers=None, fruit=None, limbs=5, inner=0.0):
    """Baumkrone aus Laubwolken ohne Kern: lobes = [(Mitte, Radius)]. Vom Gabelpunkt fork gehen wenige
    Hauptäste aus (Wolken nach Richtung gruppiert), jeder verzweigt sich zu seinen Wolken, dort führen
    Zweige zu Blattbüscheln auf der freien Außenseite der Wolke. Außen dicht, innen sieht man Äste und
    Himmel. inside(q) = erlaubter Raum (z. B. der Hof zwischen den Mauern)."""
    spray_area = per_spray * 0.42 * leaf * leaf * width
    lob = [(Vector(c), r) for c, r in lobes]
    dirs = [(c - fork).normalized() for c, _ in lob]
    # Hauptäste: weit auseinander liegende Richtungen als Kerne, jede Wolke zum nächsten Kern
    seeds = [max(range(len(lob)), key=lambda i: lob[i][1])]
    while len(seeds) < min(limbs, len(lob)):
        seeds.append(max(range(len(lob)), key=lambda i: min((dirs[i] - dirs[j]).length for j in seeds)))
    groups = {j: [] for j in seeds}
    for i in range(len(lob)):
        groups[min(seeds, key=lambda j: (dirs[i] - dirs[j]).length)].append(i)
    for members in groups.values():
        g = sum((lob[i][0] for i in members), Vector()) / len(members)
        to = g - fork
        limb_end = fork + to * 0.5 + UP * to.length * 0.08
        mid = fork + to * 0.25 + UP * to.length * 0.08 + rnd_dir(rnd) * to.length * 0.04
        p.body("bark", vary=0.08).tube([fork, mid, limb_end], lambda t: limb * (1 - 0.45 * t), segs=8, smooth=2, round_ends=True)
        for i in members:
            c, r = lob[i]
            end = c - (c - limb_end).normalized() * r * 0.3
            bm = limb_end.lerp(end, 0.5) + UP * 0.1 + rnd_dir(rnd) * 0.05
            p.body("bark", vary=0.08).tube([limb_end, bm, end], lambda t: limb * 0.55 * (1 - 0.5 * t), segs=6, smooth=1, round_ends=True)
            _lobe_sprays(p, c, r, end, lob, rnd, spray_area, density, inside, leaf, per_spray, mats, shape, width, limb, flowers, fruit,
                         inner)


def _lobe_sprays(p, c, r, end, lob, rnd, spray_area, density, inside, leaf, per_spray, mats, shape, width, limb, flowers, fruit,
                 inner=0.0):
    # Blattbüschel auf der freien Außenseite der Wolke: so viele Versuche, wie die ganze Kugel bräuchte –
    # angenommen werden nur freie Stellen, die Zahl passt so von selbst zur freien Fläche
    sprays = []
    for _ in range(int(density * 4 * math.pi * r * r / spray_area)):
        d = rnd_dir(rnd)
        if rnd.random() < inner:
            # ein paar Büschel weiter innen: füllen Lücken, wirken als Schatten in der Krone
            q = c + d * r * rnd.uniform(0.45, 0.75)
        else:
            q = c + d * r * rnd.uniform(0.86, 1.02)
            if any((q - c2).length < r2 * 0.9 for c2, r2 in lob if c2 != c):
                continue
        if inside is not None and not inside(q):
            continue
        sprays.append((q, d))
    # Zweige in Gruppen: Unteräste zu den Richtungen der Büschel
    groups = {}
    for q, d in sprays:
        groups.setdefault((round(d.x * 1.3), round(d.y * 1.3), round(d.z * 1.3)), []).append((q, d))
    for items in groups.values():
        gq = sum((q for q, _ in items), Vector()) / len(items)
        sub = end.lerp(gq, 0.55)
        p.body("bark", vary=0.08).tube([end, end.lerp(sub, 0.5) + UP * 0.05 * r, sub], lambda t: limb * 0.3 * (1 - 0.5 * t), segs=5,
                                       smooth=1, round_ends=True)
        for q, d in items:
            b0 = q - d * leaf * 0.5
            p.body("bark", vary=0.08).tube([sub, sub.lerp(b0, 0.5) + UP * 0.03 * r, b0], max(0.004, limb * 0.12), segs=4, smooth=0)
            spray(p, b0, (d + UP * 0.15).normalized(), per_spray, leaf, rnd, mats, shape=shape, width=width, flowers=flowers, fruit=fruit)


def trunk(p, pts, radius, rnd, roots=5, root_len=0.35, root_angles=None):
    """Stamm mit Wurzelanläufen (root_angles = feste Richtungen, z. B. zwischen den Beinen einer Rundbank)."""
    p.body("bark", vary=0.08).tube(pts, lambda t: radius * (1 - 0.35 * t), segs=12, smooth=2, round_ends=True)
    for k in range(len(root_angles) if root_angles else roots):
        a = root_angles[k] + rnd.uniform(-0.04, 0.04) if root_angles else 2 * math.pi * k / roots + rnd.uniform(-0.25, 0.25)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        p.body("bark", vary=0.08).tube([out * radius * 0.3 + UP * radius * 1.6, out * radius * 1.1 + UP * radius * 0.4,
                                        out * (radius + root_len) - UP * 0.04],
                                       lambda t: radius * 0.45 * (1 - 0.65 * t), segs=7, smooth=1, round_ends=True)


def garden_tree(p, mats=("leaf", "leaf", "leaf_lime", "leaf_dark")):
    """Der große Baum im Gartenhof: mächtiger Stamm mit Wurzelanläufen, teilt sich in gut 2,5 m Höhe
    in Hauptäste; das Blätterdach ist eine hohe, üppige Kuppel über den ganzen Hof von Mauer zu Mauer
    (bleibt in GARDEN_BOUNDS, also nie in Wänden oder Dächern), unten ab etwa 3 m frei."""
    rnd = p.rnd
    (x0, x1), (y0, y1), (z0, z1) = GARDEN_BOUNDS
    m = 0.45   # Blätter ragen bis etwa 0,45 m über ihren Zweig hinaus

    def inside(q):
        return x0 + m < q.x < x1 - m and y0 + m < q.y < y1 - m and z0 < q.z < z1

    # Stamm passt in die Rundbank (innen 0,42 m), Wurzeln laufen zwischen ihren acht Beinen hindurch
    t = [Vector((0, 0, -0.08)), Vector((0.02, -0.01, 1.0)), Vector((0.2, -0.1, 1.85)), Vector((0.45, -0.25, 2.6))]
    trunk(p, t, 0.3, rnd, root_len=0.42, root_angles=[0.2 + math.pi / 8 + k * math.pi / 4 for k in range(8)])
    fork = t[-1]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    ax, ay = (x1 - x0) / 2 - 1.05, (y1 - y0) / 2 - 1.05
    lobes = [(Vector((cx, cy, 8.3)), 1.75)]
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        lobes.append((Vector((cx + math.cos(a) * ax * 0.55, cy + math.sin(a) * ay * 0.55, 6.9 + rnd.uniform(-0.2, 0.2))), 1.6))
    for k in range(8):
        a = 2 * math.pi * k / 8 + rnd.uniform(-0.15, 0.15)
        lobes.append((Vector((cx + math.cos(a) * ax, cy + math.sin(a) * ay, 5.0 + rnd.uniform(-0.25, 0.25))), 1.4 * rnd.uniform(0.92, 1.08)))
    lobes.append((Vector((cx, cy, 5.3)), 1.5))
    crown(p, fork, lobes, rnd, leaf=0.28, mats=mats, per_spray=10, density=2.3, inside=inside, limb=0.17, limbs=6, inner=0.18)


def boxball(p, radius=0.17, leaf_mat="box_leaf", z=None):
    """Buchskugel (in Form geschnitten): dicht an dicht kleine Blätter, Kern ganz verdeckt."""
    c = Vector((0, 0, z if z is not None else radius * 0.9))
    leaf_ball(p, c, radius, 260, 0.045, p.rnd, mat=leaf_mat, shape="oval", squash=(1.0, 1.0, 0.95), twig_from=Vector((0, 0, 0)),
              stem_mat="bark", front_bias=0.0)


def cone_topiary(p, height=0.85, radius=0.24, leaf_mat="box_leaf"):
    """Buchs-Kegel: übereinander kleiner werdende Blattbüschel."""
    rnd = p.rnd
    n = 7
    for k in range(n):
        t = k / (n - 1)
        r = radius * (1 - 0.75 * t)
        leaf_ball(p, Vector((0, 0, 0.12 + (height - 0.25) * t)), max(0.065, r), 60, 0.042, rnd, mat=leaf_mat, shape="oval",
                  squash=(1.0, 1.0, 0.75), twig_from=Vector((0, 0, 0)) if k == 0 else None, stem_mat="bark", front_bias=0.0)


def standard(p, stem_h, crown_fn, stem_r=0.022):
    """Hochstämmchen: gerader Stamm mit Bast-Bindung, oben die Krone (crown_fn(Mittelpunkt))."""
    p.body("bark", vary=0.06).tube([Vector((0, 0, 0)), Vector((0.01, 0, stem_h * 0.5)), Vector((0, 0, stem_h))], stem_r, segs=8, smooth=1,
                                   round_ends=True)
    crown_fn(Vector((0, 0, stem_h)))


def citrus(p, height=0.75, fruit="fruit_lemon"):
    """Zitronen- bzw. Orangenbäumchen: dunkle, glänzende Blätter in Büscheln, leuchtende Früchte."""
    rnd = p.rnd

    def top(c):
        lobes = [(c + Vector((0, 0, 0.16)), 0.13)] + [
            (c + Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.08 + rnd.uniform(-0.03, 0.05))), 0.11)
            for a in (rnd.uniform(0, 1) + 2 * math.pi * k / 4 for k in range(4))]
        crown(p, c, lobes, rnd, leaf=0.075, mats=("leaf_dark", "leaf_dark", "leaf"), shape="oval", width=0.62, per_spray=7, density=1.3,
              limb=0.012, fruit=fruit, flowers=("cream_flower",))
    standard(p, height, top, 0.02)


def rose_bush(p, colors, height=0.45, leaf_mat="leaf_dark"):
    """Rosenbusch im Topf: Zweige mit gefiederten Blättern, Rosen und Knospen."""
    rnd = p.rnd
    for k in range(7):
        a = 2 * math.pi * k / 7 + rnd.uniform(-0.3, 0.3)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        d = (out * rnd.uniform(0.2, 0.6) + UP).normalized()
        pts = twig(p, out * 0.02, d, height * rnd.uniform(0.7, 1.05), rnd, leaf_mat, leaf=0.05, pairs=5, width=0.62, shape="oval",
                   stem_mat="bark", droop=0.15)
        tip = pts[-1]
        rose(p, rnd.choice(colors), tip + d * 0.02, (d + UP).normalized(), rnd.uniform(0.05, 0.07))
        if rnd.random() < 0.5:
            mid = pts[len(pts) // 2]
            rose(p, rnd.choice(colors), mid + out * 0.05, (out + UP).normalized(), rnd.uniform(0.04, 0.05))


def tulip(p, mat, at, up, size):
    """Tulpenkelch: sechs Blütenblätter in zwei Kreisen, oben leicht nach innen gewölbt."""
    rnd = p.rnd
    up = Vector(up).normalized()
    s1 = up.orthogonal().normalized()
    s2 = up.cross(s1)
    spin = rnd.uniform(0, 6.28)
    b = p.body(mat, vary=0.08)
    for ring, (rad, tilt) in enumerate(((0.3, 0.26), (0.22, 0.12))):
        for k in range(3):
            a = spin + 2 * math.pi * k / 3 + ring * math.pi / 3
            out = s1 * math.cos(a) + s2 * math.sin(a)
            b.leaf(Vector(at) + out * size * rad * 0.3 - up * size * 0.05, (up + out * tilt).normalized(), -out, size, size * 0.66,
                   shape="cup", thick=size * 0.1, curl=0.22, segs=6, fan=True)
    p.body("stem", vary=0.05).blob(Vector(at) - up * size * 0.02, size * 0.13, subdiv=1, lump=0.05)


def peony(p, mat, at, up, size, rings=3):
    """Ranunkel/Pfingstrose: Ball aus vielen schalenförmigen Blütenblättern in Ringen, innen dichter."""
    rnd = p.rnd
    up = Vector(up).normalized()
    s1 = up.orthogonal().normalized()
    s2 = up.cross(s1)
    b = p.body(mat, vary=0.09)
    for ring in range(rings):
        t = ring / max(1, rings - 1)
        count = (9, 7, 5, 4)[min(ring, 3)]
        spin = rnd.uniform(0, 6.28)
        for k in range(count):
            a = spin + 2 * math.pi * k / count
            out = s1 * math.cos(a) + s2 * math.sin(a)
            d = (out * (1.0 - 0.6 * t) + up * (0.35 + 0.6 * t)).normalized()
            base = Vector(at) + out * size * 0.08 * (1 - t) + up * size * 0.1 * t
            b.leaf(base, d, (up - out * 0.5 * t).normalized(), size * (0.95 - 0.35 * t), size * (0.9 - 0.3 * t), shape="petal",
                   thick=size * 0.1, curl=0.35 + 0.3 * t, segs=6, fan=True)
    b.blob(Vector(at) + up * size * 0.22, size * 0.22, subdiv=1, lump=0.12)


def pompon(p, mat, at, up, size, layers=4, points=11):
    """Dahlie/Chrysantheme: übereinander gestapelte Blütensterne, nach innen kleiner und steiler –
    eine runde, gefüllte Blüte."""
    up = Vector(up).normalized()
    for k in range(layers):
        t = k / max(1, layers - 1)
        floret(p, mat, Vector(at) + up * size * 0.16 * t, up, size * (1.0 - 0.55 * t), points, cup=0.15 + 0.5 * t, samples=3,
               notch=0.45)
    p.body(mat, vary=0.06).blob(Vector(at) + up * size * 0.22, size * 0.2, subdiv=1, lump=0.1)


def daisy_head(p, at, up, size, petal="cream_flower", center="gold_flower", points=12):
    """Margerite/Sonnenblume: Strahlenkranz und gewölbte Mitte."""
    up = Vector(up).normalized()
    floret(p, petal, at, up, size, points, cup=0.08, samples=3 if size < 0.05 else 4, notch=0.6)
    p.body(center, vary=0.05).blob(Vector(at) + up * size * 0.06, size * 0.32, subdiv=1, lump=0.08, scale=(1.0, 1.0, 0.55))


def bell(p, outer, inner, at, size):
    """Fuchsie: vier zurückgebogene Kelchblätter (outer) über einer hängenden Glocke (inner)."""
    rnd = p.rnd
    down = (Vector((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), -1.0))).normalized()
    s1 = down.orthogonal().normalized()
    s2 = down.cross(s1)
    b = p.body(outer, vary=0.08)
    for k in range(4):
        a = 2 * math.pi * k / 4 + rnd.uniform(-0.2, 0.2)
        out = s1 * math.cos(a) + s2 * math.sin(a)
        b.leaf(Vector(at), (out * 0.9 - down * 0.3).normalized(), -down, size * 0.8, size * 0.32, shape="narrow", thick=size * 0.12,
               curl=0.3, segs=4, fan=True)
    p.body(inner, vary=0.08).lathe([(0.0, 0.0), (size * 0.18, -size * 0.02), (size * 0.32, -size * 0.45), (size * 0.36, -size * 0.75),
                                    (size * 0.2, -size * 0.7), (0.0, -size * 0.6)], Vector(at), segs=8)
    p.body("stem", vary=0.05).tube([Vector(at) + UP * size * 0.5, Vector(at)], 0.0025, segs=3)


def pansy(p, at, up, size, c1, c2):
    """Stiefmütterchen: fünf runde Blütenblätter, in der Mitte dunkler Fleck."""
    up = Vector(up).normalized()
    floret(p, c1, at, up, size, 5, cup=0.08, samples=4, notch=0.32)
    floret(p, c2, Vector(at) + up * size * 0.08, up, size * 0.42, 5, cup=0.05, samples=3, notch=0.3)


def tulip_pot(p, color, n=9, leaf_mat="leaf_blue"):
    """Tulpen im Topf: breite blaugrüne Blätter am Grund, schlanke Stiele, Kelche."""
    rnd = p.rnd
    for _ in range(n + 4):
        a = rnd.uniform(0, 6.28)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        leaf_on(p, out * 0.03, (out * 0.5 + UP).normalized(), out, rnd.uniform(0.16, 0.22), shape="narrow", width=0.38, petiole=0.0,
                mat=leaf_mat, curl=0.35, fan=True)
    for _ in range(n):
        a = rnd.uniform(0, 6.28)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        base = out * rnd.uniform(0.0, 0.07)
        top = base + out * rnd.uniform(0.02, 0.08) + UP * rnd.uniform(0.26, 0.36)
        p.body("stem", vary=0.05).tube([base, base.lerp(top, 0.5) + out * 0.01, top], 0.0045, segs=4, smooth=1)
        tulip(p, rnd.choice(color) if isinstance(color, tuple) else color, top, (UP + out * 0.15).normalized(), 0.06)


def flower_bush(p, head, colors, n=9, height=0.35, leaf_mat="leaf", leaf_shape="oval", leaf=0.06, leaves=40):
    """Blühender Busch im Topf (Margerite, Dahlie, Chrysantheme …): Laubpolster, darüber Blüten an Stielen."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, 0, height * 0.35)), height * 0.45, leaves, leaf, rnd, mat=leaf_mat, shape=leaf_shape, squash=(1.1, 1.1, 0.75),
              twig_from=Vector((0, 0, 0)))
    for _ in range(n):
        d = rnd_dir(rnd)
        d.z = abs(d.z) * 0.6 + 0.4
        d.normalize()
        top = Vector((0, 0, height * 0.35)) + Vector((d.x * height * 0.5, d.y * height * 0.5, d.z * height * 0.7))
        p.body("stem", vary=0.05).tube([Vector((d.x * 0.03, d.y * 0.03, height * 0.2)), top], 0.003, segs=3)
        head(p, rnd.choice(colors), top, (d + UP).normalized())


def grass_tuft(p, blades=24, height=0.24, mats=("grass_leaf", "grass_leaf", "leaf_lime"), flowers=None, plume=None):
    """Grasbüschel (am Fuß der Hauswände, im Gehweg, Ziergras im Topf): schmale Halme, die vom Fuß
    nach außen fallen; dazwischen ab und zu eine kleine Blüte oder Rispe."""
    rnd = p.rnd
    for _ in range(blades):
        a = rnd.uniform(0, 6.28)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        lean = rnd.uniform(0.15, 0.75)
        d = (UP + out * lean).normalized()
        nrm = (out - UP * lean).normalized()
        L = height * rnd.uniform(0.55, 1.15)
        leaf_on(p, out * rnd.uniform(0.0, 0.03), d, nrm, L, shape="blade", width=rnd.uniform(0.07, 0.11), petiole=0.0,
                mat=rnd.choice(mats), curl=rnd.uniform(0.25, 0.6), fan=True, segs=6)
    if flowers:
        for _ in range(rnd.randint(1, 3)):
            a = rnd.uniform(0, 6.28)
            out = Vector((math.cos(a), math.sin(a), 0.0))
            top = out * rnd.uniform(0.02, 0.06) + UP * height * rnd.uniform(0.5, 0.9)
            p.body("stem", vary=0.05).tube([out * 0.01, top], 0.002, segs=3)
            col = rnd.choice(flowers)
            if col == "gold_flower":
                floret(p, col, top, (UP + out * 0.3).normalized(), 0.016, 12, cup=0.15, samples=2, notch=0.5)
            else:
                daisy_head(p, top, (UP + out * 0.3).normalized(), 0.016, petal=col)
    if plume:
        for _ in range(rnd.randint(3, 6)):
            a = rnd.uniform(0, 6.28)
            out = Vector((math.cos(a), math.sin(a), 0.0))
            top = out * height * rnd.uniform(0.15, 0.4) + UP * height * rnd.uniform(1.0, 1.3)
            mid = out * height * 0.08 + UP * height * 0.6
            p.body("stem", vary=0.05).tube([out * 0.01, mid, top], 0.0022, segs=3, smooth=1)
            spike(p, plume, top - (top - mid).normalized() * height * 0.25, top, 0.012, n=6, segs=5)


def lobelia_box(p, colors=("blue_flower", "sky_flower", "cream_flower"), leaf_mat="leaf_lime"):
    """Männertreu und Schneeflocke: flaches Polster mit vielen winzigen Blüten, Ranken fallen über den Rand."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, -0.005, 0.05)), 0.09, 26, 0.035, rnd, mat=leaf_mat, shape="oval", squash=(1.5, 0.75, 0.5),
              twig_from=Vector((0, 0, 0)))
    for _ in range(45):
        d = rnd_dir(rnd)
        d.z = abs(d.z) * 0.6 + 0.25
        c = Vector((d.x * 0.14, d.y * 0.07 - 0.005, 0.05 + d.z * 0.05))
        floret(p, rnd.choice(colors), c, d, rnd.uniform(0.011, 0.014), 5, cup=0.2, samples=3)
    for k in range(5):
        trail(p, -0.12 + 0.06 * k + rnd.uniform(-0.02, 0.02), rnd.uniform(0.18, 0.32), rnd, leaf_mat=leaf_mat, shape="oval", leaf=0.026,
              flowers=colors, flower_size=0.013)


def begonia_box(p, color, leaf_mat="leaf_bronze"):
    """Begonien: glänzend bronzefarbenes Laub, darüber viele kleine Blüten in Büscheln."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, -0.005, 0.07)), 0.1, 28, 0.06, rnd, mat=leaf_mat, shape="round", width=0.95, squash=(1.45, 0.75, 0.6),
              twig_from=Vector((0, 0, 0)))
    for _ in range(7):
        c = Vector((rnd.uniform(-0.13, 0.13), rnd.uniform(-0.06, 0.03), rnd.uniform(0.11, 0.16)))
        for _ in range(4):
            d = rnd_dir(rnd)
            d.z = abs(d.z) + 0.3
            floret(p, color, c + d * 0.015, d.normalized(), rnd.uniform(0.016, 0.02), 4, cup=0.3, samples=3)


def fuchsia(p, outer, inner, leaf_mat="leaf_dark", trails=5):
    """Fuchsie: dunkles Laub, an überhängenden Trieben hängen die Glöckchen."""
    rnd = p.rnd
    c = p.container or CONTAINERS["box"]
    if c["kind"] == "box":
        leaf_ball(p, Vector((0, -0.005, 0.07)), 0.1, 26, 0.05, rnd, mat=leaf_mat, shape="oval", squash=(1.45, 0.75, 0.65),
                  twig_from=Vector((0, 0, 0)))
        at = [-0.12 + 0.24 * k / max(1, trails - 1) for k in range(trails)]
    else:
        leaf_ball(p, Vector((0, 0, 0.08)), c["inner"] * 0.8, 30, 0.05, rnd, mat=leaf_mat, shape="oval", squash=(1.0, 1.0, 0.7),
                  twig_from=Vector((0, 0, 0)))
        at = [2 * math.pi * k / trails + rnd.uniform(-0.3, 0.3) for k in range(trails)]
    for a in at:
        trail(p, a, rnd.uniform(0.2, 0.36), rnd, leaf_mat=leaf_mat, shape="oval", leaf=0.04, bells=(outer, inner))
    for _ in range(5):
        d = rnd_dir(rnd)
        d.z = abs(d.z) * 0.5 + 0.3
        bell(p, outer, inner, Vector((d.x * 0.1, d.y * 0.05, 0.1)), 0.026)


def herb_box(p):
    """Kräuterkasten: Rosmarin (silbrige Nadeln, aufrecht), Thymian (feines Polster), Basilikum (große,
    helle Blätter)."""
    rnd = p.rnd
    for _ in range(8):
        base = Vector((rnd.uniform(-0.13, -0.05), rnd.uniform(-0.03, 0.03), 0.0))
        twig(p, base, (UP + rnd_dir(rnd) * 0.35).normalized(), rnd.uniform(0.15, 0.24), rnd, "leaf_silver", leaf=0.045, pairs=9, width=0.3,
             shape="narrow", droop=0.0, stem_mat="stem")
    leaf_ball(p, Vector((0.01, -0.01, 0.04)), 0.065, 40, 0.022, rnd, mat="leaf_lime", shape="round", squash=(1.2, 1.0, 0.6),
              twig_from=Vector((0.01, 0, 0)))
    for _ in range(6):
        floret(p, "lilac", Vector((rnd.uniform(-0.04, 0.05), rnd.uniform(-0.05, 0.02), 0.07)), UP, 0.007, 4, samples=2)
    for k in range(4):
        base = Vector((0.1 + rnd.uniform(-0.02, 0.02), rnd.uniform(-0.03, 0.03), 0.0))
        for j in range(5):
            a = 2 * math.pi * j / 4 + k
            out = Vector((math.cos(a), math.sin(a), 0.0))
            leaf_on(p, base + UP * (0.04 + 0.04 * k), (out + UP * 0.4).normalized(), (UP + out * 0.3).normalized(), 0.05, shape="round",
                    width=0.75, mat="leaf_lime", petiole=0.008)


def pansy_box(p, pairs=(("purple_flower", "yellow_flower"), ("yellow_flower", "burgundy_flower"), ("cream_flower", "purple_flower"),
                        ("sky_flower", "cream_flower"))):
    """Stiefmütterchen: niedrige Blattrosetten, darüber viele flache Blüten in bunten Paaren."""
    rnd = p.rnd
    c = p.container or CONTAINERS["potfill"]
    wide = c["kind"] == "box"
    leaf_ball(p, Vector((0, -0.005, 0.04)), 0.09, 24, 0.05, rnd, mat="leaf", shape="round", squash=(1.5 if wide else 1.0, 0.75, 0.45),
              twig_from=Vector((0, 0, 0)))
    for _ in range(9):
        d = rnd_dir(rnd)
        d.z = abs(d.z) * 0.6 + 0.4
        q = Vector((d.x * (0.12 if wide else 0.1), d.y * 0.06, 0.06 + d.z * 0.04))
        p.body("stem", vary=0.05).tube([Vector((q.x * 0.5, q.y * 0.5, 0.0)), q], 0.0025, segs=3)
        c1, c2 = rnd.choice(pairs)
        pansy(p, q, (d + UP + FRONT * 0.5).normalized(), rnd.uniform(0.026, 0.032), c1, c2)


def heather(p, color, n=150, height=0.2):
    """Besenheide: dichte, flauschige Kuppel – dunkles, feines Laub, darüber rundherum viele kurze Ähren
    aus winzigen Blüten (Herbst)."""
    rnd = p.rnd
    c = p.container or CONTAINERS["potfill"]
    wide = c["kind"] == "box"
    sq = Vector((1.55, 0.7, 1.0)) if wide else Vector((1.0, 1.0, 1.0))
    R = 0.1 if wide else 0.13
    centre = Vector((0, -0.005 if wide else 0.0, height * 0.45))
    leaf_ball(p, centre, R * 0.9, 40, 0.03, rnd, mat="leaf_dark", shape="narrow", width=0.35, squash=(sq.x, sq.y, 0.8),
              twig_from=Vector((0, 0, 0)))
    for _ in range(n):
        d = rnd_dir(rnd)
        if d.z < -0.2:
            d.z = -d.z * 0.5
        d.normalize()
        q = centre + Vector((d.x * sq.x, d.y * sq.y, d.z * 0.8)) * R * 0.85
        tip = q + (d + UP * 1.1).normalized() * rnd.uniform(0.045, 0.07)
        spike(p, color, q - (tip - q) * 0.3, tip, 0.0095, n=5, segs=4)


def ivy_box(p, flowers=("white_flower",)):
    """Efeu-Kasten: kleines Polster, viele Efeuranken fallen über den Rand, dazwischen weiße Sternchen."""
    rnd = p.rnd
    leaf_ball(p, Vector((0, -0.005, 0.05)), 0.08, 22, 0.045, rnd, mat="ivy", shape="heart", width=0.95, squash=(1.5, 0.75, 0.5),
              twig_from=Vector((0, 0, 0)))
    for k in range(6):
        trail(p, -0.13 + 0.052 * k + rnd.uniform(-0.015, 0.015), rnd.uniform(0.25, 0.5), rnd, leaf=0.045,
              flowers=flowers if k % 2 else None, flower_size=0.014)


def rosemary(p, n=22, height=0.4):
    """Rosmarin: aufrechte, silbrige Zweige mit Nadelblättern, ein paar hellblaue Blüten."""
    rnd = p.rnd
    for _ in range(n):
        a = rnd.uniform(0, 6.28)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        twig(p, out * rnd.uniform(0.0, 0.05), (UP + out * rnd.uniform(0.1, 0.45)).normalized(), height * rnd.uniform(0.6, 1.05), rnd,
             "leaf_silver", leaf=0.055, pairs=12, width=0.3, shape="narrow", droop=0.05, stem_mat="stem",
             flowers="sky_flower" if rnd.random() < 0.4 else None)


def standard_ball(p, stem_h=0.5, radius=0.2, leaf_mat="box_leaf"):
    """Buchs- oder Lorbeer-Stämmchen: gerader Stamm, oben eine dichte, geschnittene Kugel."""
    standard(p, stem_h, lambda c: leaf_ball(p, c + UP * radius * 0.85, radius, 260, 0.045, p.rnd, mat=leaf_mat, shape="oval",
                                            squash=(1.0, 1.0, 0.95), twig_from=c, stem_mat="bark", front_bias=0.0), stem_r=0.02)


def bay_tree(p):
    """Lorbeerbaum im Kübel (Platz): hoher Stamm, große geschnittene Kugel aus dunklen Blättern."""
    standard(p, 1.65, lambda c: leaf_ball(p, c + UP * 0.4, 0.46, 700, 0.06, p.rnd, mat="leaf_dark", shape="oval", width=0.6,
                                          squash=(1.0, 1.0, 0.95), twig_from=c, stem_mat="bark", front_bias=0.0), stem_r=0.04)


def standard_rose(p, colors=("pink", "rose", "blush_flower")):
    """Rosenstämmchen: gerader Stamm, oben ein lockerer Rosenbusch."""
    rnd = p.rnd

    def top(c):
        for k in range(10):
            a = 2 * math.pi * k / 10 + rnd.uniform(-0.3, 0.3)
            out = Vector((math.cos(a), math.sin(a), 0.0))
            d = (out * rnd.uniform(0.6, 1.0) + UP * rnd.uniform(0.0, 0.8)).normalized()
            pts = twig(p, c, d, rnd.uniform(0.24, 0.34), rnd, "leaf_dark", leaf=0.065, pairs=5, width=0.62, shape="oval", stem_mat="bark",
                       droop=0.2)
            rose(p, rnd.choice(colors), pts[-1] + d * 0.02, (d + UP).normalized(), rnd.uniform(0.06, 0.08))
            if rnd.random() < 0.5:
                rose(p, rnd.choice(colors), pts[len(pts) // 2] + out * 0.04, (out + UP).normalized(), rnd.uniform(0.045, 0.06))
    standard(p, 0.62, top, 0.018)
