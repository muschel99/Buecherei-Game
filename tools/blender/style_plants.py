"""Pflanzen im Stil (seit Etappe 4g, Teil 4f): echte Blätter und Blüten statt Kugeln.

Jedes Blatt ist eine leicht gebogene, gefaltete Fläche mit einer Pflanzen-Textur (Form und Adern
aus scripts/tools/generate_plant_textures.gd, Rand per Alpha ausgeschnitten). Jedes Blatt sitzt
an einem Stiel, jeder Stiel an einem Trieb, jeder Trieb wächst aus Erde oder aus dem Stamm –
nichts schwebt. Alles in Godot-Koordinaten (x rechts, y oben, z nach vorn), wie style_lib.py.

Regeln:
  - Blätter/Blüten: Material "plant" (beidseitig sichtbar). Stängel, Stämme: geschlossene Röhren.
  - Nichts darf in Wände, Töpfe oder Kästen ragen: Wer Pflanzen in Gefäße setzt, gibt einen
    Raum (Space) mit, der die Ecken jedes Blatts aus Hindernissen herausschiebt.
  - Zufall immer über ein eigenes random.Random(seed) – jeder Bau sieht gleich aus.
"""

import math
import os
import random

from mathutils import Matrix, Vector

import style_lib as S
from style_lib import Mat, V

# Neutrale Farbe der Pflanzen-Texturen (Blätter haben ihre Farbe schon in der Textur)
NEUTRAL = 0.8

# Farben weicher Pflanzenteile (Stängel, Blütenröhren, Staubfäden): geo_check.py zählt sie nicht
# als feste Teile (Blätter dürfen sie berühren)
SOFT_COLORS = []


def soft_mat(color, glow=0.0, layer="plain"):
    """Material für weiche Pflanzenteile (wird für geo_check.py gemerkt)."""
    color = tuple(color)
    if color not in SOFT_COLORS:
        SOFT_COLORS.append(color)
    return Mat(layer, color=color, glow=glow)


STEM_GREEN = Mat("plain", color=(0.3, 0.4, 0.2))
STEM_BROWN = Mat("plain", color=(0.33, 0.27, 0.19))
IVY_STEM = Mat("plain", color=(0.36, 0.3, 0.22))
SOIL = Mat("plain", color=(0.2, 0.15, 0.11))
BARK = Mat("bark", color=(0.8, 0.8, 0.8))
# Ketten der Hängekörbe: Metall (sieht aus wie IRON – die Ebene "metal" wird nicht eingefärbt);
# eigene Farbe nur, damit geo_check.py sie erkennt (Pflanzen wachsen um Ketten herum)
CHAIN = Mat("metal", color=(0.37, 0.41, 0.43))

# Blütenfarben (sRGB) – sanft, nicht knallig; die Blüten-Texturen sind fast weiß
BLOSSOMS = {
    "rose": [(0.86, 0.45, 0.55), (0.92, 0.6, 0.67), (0.78, 0.34, 0.45)],
    "white": [(0.96, 0.95, 0.92), (0.94, 0.92, 0.86)],
    "lavender": [(0.62, 0.55, 0.82), (0.72, 0.66, 0.88)],
    "coral": [(0.93, 0.5, 0.4), (0.96, 0.62, 0.5)],
    "red": [(0.78, 0.18, 0.18), (0.86, 0.26, 0.24)],
    "hydrangea": [(0.62, 0.7, 0.9), (0.72, 0.66, 0.88), (0.84, 0.72, 0.88)],
    "blue": [(0.38, 0.45, 0.85), (0.5, 0.55, 0.9)],
    "yellow": [(0.98, 0.84, 0.35), (0.96, 0.76, 0.3)],
}


# Detailstufe: Anzahl der Blätter, Blüten und Stiele wird damit multipliziert (z. B. im
# Ladeninneren hinter Glas weniger). Benutzung: with detail(0.6): …
DETAIL = [1.0]


class detail:
    def __init__(self, factor):
        self.factor = factor

    def __enter__(self):
        DETAIL.append(DETAIL[-1] * self.factor)

    def __exit__(self, *args):
        DETAIL.pop()


def _n(count):
    """Anzahl je nach Detailstufe (mindestens 1)."""
    return max(1, int(round(count * DETAIL[-1])))


def leaf_mat(layer, rnd=None, shade=1.0, tint=(1.0, 1.0, 1.0), glow=0.0):
    """Blatt-Material: Textur-Farbe x (neutral 0,8 · Abweichung). shade < 1 dunkler."""
    if rnd is not None:
        shade *= rnd.uniform(0.86, 1.08)
    return Mat(layer, color=tuple(min(1.0, NEUTRAL * shade * t) for t in tint), glow=glow)


def bloom_mat(layer, color, glow=0.0, rnd=None):
    """Blüten-Material: die helle Blüten-Textur wird mit der Blütenfarbe eingefärbt."""
    k = 0.86 * (rnd.uniform(0.92, 1.04) if rnd is not None else 1.0)
    return Mat(layer, color=tuple(min(1.0, c * k) for c in color), glow=glow)


# ---------------------------------------------------------------------------------------------
# Raum: hält Blätter aus Wänden, Töpfen und Kästen heraus
# ---------------------------------------------------------------------------------------------

class Space:
    """Hindernisse, aus denen jede Blattecke herausgeschoben wird (in denselben Koordinaten wie
    die Pflanze). Leer = nichts zu beachten."""

    def __init__(self):
        self.rules = []

    def wall(self, z, x0=-1e9, x1=1e9, y0=-1e9, y1=1e9, gap=0.004):
        """Wand in der Ebene z (Vorderseite +z): alles bleibt davor."""
        self.rules.append(("wall", z + gap, x0, x1, y0, y1))
        return self

    def floor(self, y, x0=-1e9, x1=1e9, z0=-1e9, z1=1e9, gap=0.003):
        """Boden/Erde bei y im Rechteck: alles bleibt darüber."""
        self.rules.append(("floor", y + gap, x0, x1, z0, z1))
        return self

    def block(self, lo, hi, gap=0.006):
        """Fester Kasten (Topf, Blumenkasten, Sims): Punkte darin wandern auf dem kürzesten Weg
        nach oben, vorn oder zur Seite hinaus (nie nach hinten in die Wand)."""
        self.rules.append(("block", Vector(lo) - Vector((gap, 0, gap)), Vector(hi) + Vector((gap, gap, gap))))
        return self

    def inside(self, lo, hi):
        """Alles bleibt innerhalb des Kastens lo..hi (z. B. kleines Zimmer hinter einem Fenster)."""
        self.rules.append(("inside", Vector(lo), Vector(hi)))
        return self

    def plane(self, point, normal, gap=0.006):
        """Wand in beliebiger Lage: alles bleibt auf der Seite, in die normal zeigt."""
        self.rules.append(("plane", Vector(point), Vector(normal).normalized(), gap))
        return self

    def cylinder(self, x, z, radius, y0, y1, gap=0.006):
        """Stehender Zylinder (Topf, Kübel): Punkte darin wandern nach außen oder nach oben."""
        self.rules.append(("cyl", x, z, radius + gap, y0, y1 + gap))
        return self

    def push(self, p):
        p = Vector(p)
        # Jedes Blatt hält etwas anderen Abstand (_EXTRA): Blätter, die an dieselbe Wand
        # gedrückt werden, liegen dann nicht genau aufeinander (sonst flimmern sie)
        e = _EXTRA[0]
        for rule in self.rules:
            kind = rule[0]
            if kind == "wall":
                _, z, x0, x1, y0, y1 = rule
                if x0 <= p.x <= x1 and y0 <= p.y <= y1 and p.z < z + e:
                    p.z = z + e
            elif kind == "floor":
                _, y, x0, x1, z0, z1 = rule
                if x0 <= p.x <= x1 and z0 <= p.z <= z1 and p.y < y + e:
                    p.y = y + e
            elif kind == "block":
                _, lo, hi = rule
                if lo.x - e < p.x < hi.x + e and lo.y < p.y < hi.y + e and lo.z < p.z < hi.z + e:
                    options = [(hi.y - p.y, "up"), (hi.z - p.z, "front"), (p.x - lo.x, "left"), (hi.x - p.x, "right")]
                    dist, way = min(options)
                    if way == "up":
                        p.y = hi.y + e
                    elif way == "front":
                        p.z = hi.z + e
                    elif way == "left":
                        p.x = lo.x - e
                    else:
                        p.x = hi.x + e
            elif kind == "inside":
                _, lo, hi = rule
                p = Vector((min(max(p.x, lo.x), hi.x), min(max(p.y, lo.y), hi.y), min(max(p.z, lo.z), hi.z)))
            elif kind == "plane":
                _, q, nrm, gap = rule
                d = (p - q).dot(nrm)
                if d < gap + e:
                    p = p + nrm * (gap + e - d)
            elif kind == "cyl":
                _, cx, cz, r, y0, y1 = rule
                d = Vector((p.x - cx, 0.0, p.z - cz))
                if y0 < p.y < y1 and d.length < r:
                    if y1 - p.y < r - d.length:
                        p.y = y1
                    else:
                        if d.length < 1e-6:
                            d = Vector((1.0, 0.0, 0.0))
                        d.normalize()
                        p.x = cx + d.x * r
                        p.z = cz + d.z * r
        return p


NO_SPACE = Space()
# Zusatzabstand des gerade gebauten Blatts zu Wänden, Böden, Ebenen und Kästen (siehe Space.push)
_EXTRA = [0.0]
LEAF_GAPS = 4            # Abstufungen des Zusatzabstands
LEAF_GAP_STEP = 0.0025   # je Stufe 2,5 mm


def _leaf_extra(gid):
    return LEAF_GAP_STEP * (gid % LEAF_GAPS)


# ---------------------------------------------------------------------------------------------
# Grundbausteine: Blattfläche, Blütenfläche, Stängel
# ---------------------------------------------------------------------------------------------

_GROUP = [0]


def _tag(b, start, root=None, space=None):
    """Flächen ab start gehören zu einem Blatt / einer Blüte (für settle); root = Ansatzpunkt am
    Stiel (darum wird das Blatt gekippt, wenn es ausweichen muss), space = Hindernisse, die
    auch nach dem Kippen gelten. Beides in Pflanzen-Koordinaten, gemerkt in Modell-Koordinaten
    (wie die Flächen)."""
    _GROUP[0] += 1
    for face in b.faces[start:]:
        face["group"] = _GROUP[0]
    if root is not None:
        b.__dict__.setdefault("roots", {})[_GROUP[0]] = b.xf @ Vector(root)
    if space is not None and space.rules:
        b.__dict__.setdefault("spaces", {})[_GROUP[0]] = (space, b.xf.copy())


def _frame(along, facing):
    d = Vector(along).normalized()
    n = Vector(facing)
    n = n - d * n.dot(d)
    if n.length < 1e-6:
        n = d.orthogonal()
    n.normalize()
    s = d.cross(n).normalized()
    return d, n, s


def card(b, base, along, facing, length, width, mat, rows=2, fold=0.0, curl=0.0, twist=0.0,
         anchor=0.0, space=NO_SPACE, uv=(0.0, 0.0, 1.0, 1.0)):
    """Blatt (oder Zweig) als gebogene Fläche: Unterkante Mitte der Textur bei base (anchor = 0)
    bzw. Mitte der Textur bei base (anchor = 0,5); along = Richtung zur Spitze, facing = Oberseite.
    fold = Faltung am Mittelnerv (Ränder heben sich), curl = Biegung zur Spitze (positiv = Spitze
    hängt nach unten/hinten), twist = Verdrehung. Liefert die Punkte der Mittellinie."""
    start_face = len(b.faces)
    _EXTRA[0] = _leaf_extra(_GROUP[0] + 1)
    d, n, s = _frame(along, facing)
    base = Vector(base)
    if length < 0.07 and abs(curl) < 0.5:
        rows = 1
    step = length / rows
    spine = [base - d * (anchor * length)]
    dirs = []
    norms = []
    sides = []
    for i in range(rows + 1):
        t = i / rows
        a = curl * t
        dt = d * math.cos(a) - n * math.sin(a)
        nt = n * math.cos(a) + d * math.sin(a)
        tw = twist * t
        st = s * math.cos(tw) + nt * math.sin(tw)
        nt = nt * math.cos(tw) - s * math.sin(tw)
        dirs.append(dt)
        norms.append(nt)
        sides.append(st)
        if i < rows:
            a_mid = curl * (t + 0.5 / rows)
            spine.append(spine[-1] + (d * math.cos(a_mid) - n * math.sin(a_mid)) * step)
    u0, v0, u1, v1 = uv
    grid = []
    for i in range(rows + 1):
        row = []
        for j, u in enumerate((0.0, 0.5, 1.0)):
            x = (u - 0.5) * width
            p = spine[i] + sides[i] * (x * math.cos(fold)) + norms[i] * (abs(x) * math.sin(fold))
            p = space.push(p)
            if j == 0:
                nrm = norms[i] * math.cos(fold) + sides[i] * math.sin(fold)
            elif j == 2:
                nrm = norms[i] * math.cos(fold) - sides[i] * math.sin(fold)
            else:
                nrm = norms[i]
            row.append((p, nrm, (u0 + (u1 - u0) * u, v0 + (v1 - v0) * i / rows)))
        grid.append(row)
    for i in range(rows):
        for j in range(2):
            q = [grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]]
            b.poly([c[0] for c in q], mat, normals=[c[1] for c in q], uvs=[c[2] for c in q])
    _tag(b, start_face, base, space)
    _EXTRA[0] = 0.0
    return spine


def blossom(b, center, facing, size, mat, cup=0.18, spin=0.0, space=NO_SPACE):
    """Blüte von vorn (Textur-Mitte bei center), leicht gewölbt wie eine Schale (cup)."""
    n = Vector(facing).normalized()
    ref = Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((1, 0, 0))
    up = (ref - n * ref.dot(n)).normalized()
    side = up.cross(n).normalized()
    up, side = up * math.cos(spin) + side * math.sin(spin), side * math.cos(spin) - up * math.sin(spin)
    c = Vector(center)
    start_face = len(b.faces)
    _EXTRA[0] = _leaf_extra(_GROUP[0] + 1)
    if size < 0.036:
        pts = [c + side * (-0.5 * size) + up * (-0.5 * size), c + side * (0.5 * size) + up * (-0.5 * size),
               c + side * (0.5 * size) + up * (0.5 * size), c + side * (-0.5 * size) + up * (0.5 * size)]
        b.poly([space.push(p) for p in pts], mat, normals=[n] * 4, uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
        _tag(b, start_face, c, space)
        _EXTRA[0] = 0.0
        return
    grid = []
    for i, v in enumerate((0.0, 0.5, 1.0)):
        row = []
        for u in (0.0, 0.5, 1.0):
            x = (u - 0.5) * size
            y = (v - 0.5) * size
            r2 = (x * x + y * y) / (0.25 * size * size)
            p = c + side * x + up * y + n * (cup * size * 0.5 * r2)
            nrm = (n - (side * x + up * y) * (cup * 2.0 / size)).normalized()
            row.append((space.push(p), nrm, (u, v)))
        grid.append(row)
    for i in range(2):
        for j in range(2):
            q = [grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]]
            b.poly([e[0] for e in q], mat, normals=[e[1] for e in q], uvs=[e[2] for e in q])
    _tag(b, start_face, c, space)
    _EXTRA[0] = 0.0


def stem(b, pts, r0, r1, mat=STEM_GREEN, segments=4, space=NO_SPACE):
    """Stängel/Trieb als Röhre, Dicke r0 → r1."""
    pts = [space.push(p) for p in pts]
    if len(pts) < 2:
        return
    if r0 < 0.0035:
        segments = 3
    b.tube(pts, lambda t: r0 + (r1 - r0) * t, mat, segments=segments)


def _curve(a, b2, bulge, count=4):
    """Punkte von a nach b2 mit einem Bogen (bulge = Versatz der Mitte, Vektor)."""
    a = Vector(a)
    b2 = Vector(b2)
    out = []
    for k in range(count + 1):
        t = k / count
        out.append(a.lerp(b2, t) + Vector(bulge) * (4 * t * (1 - t)))
    return out


def _rand_dir(rnd, up_min=-1.0, up_max=1.0):
    """Zufällige Richtung, Höhe (y) zwischen up_min und up_max."""
    y = rnd.uniform(up_min, up_max)
    a = rnd.uniform(0, 2 * math.pi)
    r = math.sqrt(max(0.0, 1 - y * y))
    return Vector((math.cos(a) * r, y, math.sin(a) * r))


def _fib_sphere(count, rnd):
    """Gleichmäßig verteilte Richtungen auf einer Kugel (leicht verwackelt)."""
    out = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(count):
        y = 1 - 2 * (i + 0.5) / count
        r = math.sqrt(max(0.0, 1 - y * y))
        a = golden * i + rnd.uniform(-0.2, 0.2)
        out.append(Vector((math.cos(a) * r, y, math.sin(a) * r)))
    return out


# ---------------------------------------------------------------------------------------------
# Efeu
# ---------------------------------------------------------------------------------------------

def ivy_leaf(b, at, out, size, rnd, space=NO_SPACE, young=False, glow=0.0, hang=0.75):
    """Efeublatt mit Stiel: at = Punkt am Trieb, out = Richtung von der Wand weg (Oberseite des
    Blatts zeigt etwa dorthin). hang: wie stark die Spitze nach unten zeigt."""
    out = Vector(out).normalized()
    side = Vector((0, 1, 0)).cross(out)
    if side.length < 1e-6:
        side = Vector((1, 0, 0))
    side.normalize()
    lean = rnd.uniform(-1, 1)
    petiole_dir = (out * 0.85 + side * lean * 0.45 + Vector((0, rnd.uniform(-0.1, 0.35), 0))).normalized()
    petiole = size * rnd.uniform(0.45, 0.85)
    raw = Vector(at) + petiole_dir * petiole
    tip = space.push(raw)
    if (tip - raw).length > 0.02:
        # Kein Platz für dieses Blatt (Hindernis direkt daneben): lieber weglassen als verbiegen
        return
    # Der Stiel beginnt immer genau am Trieb (nur Mitte und Ende weichen Hindernissen aus)
    b.tube([Vector(at), tip], lambda t: 0.0016 - 0.0004 * t, IVY_STEM, segments=3, caps=False)
    along = (Vector((0, -hang, 0)) + side * lean * 0.6 + out * 0.35 + Vector((0, 0.25, 0)) * rnd.uniform(-1, 1)).normalized()
    facing = (out + Vector((0, 0.55, 0)) + side * rnd.uniform(-0.3, 0.3)).normalized()
    shade = 1.25 if young else 1.0
    mat = leaf_mat("ivy_leaf", rnd, shade=shade, tint=(1.05, 1.05, 0.85) if young else (1.0, 1.0, 1.0), glow=glow)
    card(b, tip - along * size * 0.06, along, facing, size * 1.25, size * 1.25, mat, rows=2,
         fold=rnd.uniform(0.12, 0.35), curl=rnd.uniform(0.1, 0.45), twist=rnd.uniform(-0.25, 0.25), space=space)


def _in_holes(x, y, holes, margin):
    for hx0, hy0, hx1, hy1 in holes:
        if hx0 - margin < x < hx1 + margin and hy0 - margin < y < hy1 + margin:
            return True
    return False


def ivy_wall(b, x_root, z_wall, top, rnd, x_min=-1e9, x_max=1e9, holes=(), y_root=0.0, stems=5,
             spread=0.9, leaf_size=0.085, density=1.0, pit=True, glow=0.0, bumps=(), max_leaves=None, floor_y=None,
             cover=False):
    """Efeu, der aus dem Boden (bzw. einem kleinen Pflanzloch) bei x_root die Wand (Ebene z_wall,
    Vorderseite +z) hochwächst: verzweigte Triebe mit Haftwurzeln, Blätter an Stielen, unten
    dichter und größer, oben jung und heller. Fenster/Türen (holes = Rechtecke x0, y0, x1, y1)
    bleiben frei, die Triebe wachsen um sie herum. bumps = vorstehende Teile (Gesimse, Sockel:
    x0, y0, x1, y1, Vorderkante z) – Triebe und Blätter wachsen darüber hinweg. Alles bleibt vor
    der Wand. cover = ganze Wand (x_min..x_max bis top) dicht bewachsen, schon ab dem Boden
    stark verzweigt. Die Blätter werden gleichmäßig auf alle Triebe verteilt (keine kahlen
    Triebe), Anzahl nach Fläche (max_leaves = None)."""
    space = Space().wall(z_wall, gap=0.003)
    for bx0, by0, bx1, by1, bz in bumps:
        space.block((bx0, by0, z_wall - 1.0), (bx1, by1, bz), gap=0.004)

    def stem_z(px, py, r):
        z = z_wall + r + 0.002
        for bx0, by0, bx1, by1, bz in bumps:
            if bx0 - 0.02 < px < bx1 + 0.02 and by0 - 0.04 < py < by1 + 0.04:
                z = max(z, bz + r + 0.003)
        return z
    if cover:
        spread = max(spread, (x_max - x_min) / 2)
    # Fläche, die der Efeu bewachsen darf (ohne Öffnungen grob geschätzt)
    lo_x, hi_x = max(x_min, x_root - spread * 1.5), min(x_max, x_root + spread * 1.5)
    area = max(0.3, (hi_x - lo_x) * (top - y_root) * (0.85 if not cover else 1.0))
    if max_leaves is None:
        max_leaves = int(area * (330 if cover else 150))
    max_leaves = int(max_leaves * DETAIL[-1])
    # Liegt die Wurzel in einer Öffnung (Tür, Fenster bis zum Boden), rückt sie zur nächsten
    # freien Stelle an der Wand
    if _in_holes(x_root, y_root + 0.1, holes, 0.1):
        free = [x_root + d * sgn for d in [0.05 * k for k in range(1, 60)] for sgn in (1, -1)
                if x_min + 0.1 < x_root + d * sgn < x_max - 0.1 and not _in_holes(x_root + d * sgn, y_root + 0.1, holes, 0.12)]
        if not free:
            return
        x_root = free[0]
    space.floor(floor_y if floor_y is not None else y_root, gap=0.01)
    if pit:
        pit_half = 0.2 if not cover else min(0.6, (x_max - x_min) / 2 - 0.05)
        space.block((x_root - pit_half - 0.05, y_root - 0.1, z_wall - 0.1), (x_root + pit_half + 0.05, y_root + 0.045, z_wall + 0.21), gap=0.03)
        corners = [b.xf @ Vector(c) for c in ((x_root - pit_half - 0.1, y_root, z_wall), (x_root + pit_half + 0.1, y_root, z_wall + 0.27))]
        lo_ = Vector((min(c.x for c in corners), y_root, min(c.z for c in corners)))
        hi_ = Vector((max(c.x for c in corners), y_root + 0.045, max(c.z for c in corners)))
        _register(b, "box", (lo_, hi_, 0.0, 0.045, None, lo_, hi_))
        # Pflanzloch im Pflaster: Erde, Rand aus Ziegeln
        b.box((x_root - pit_half, y_root, z_wall), (x_root + pit_half, y_root + 0.012, z_wall + 0.16), SOIL, skip=("back",))
        for k, (lo, hi) in enumerate((((x_root - pit_half - 0.04, y_root, z_wall), (x_root - pit_half, y_root + 0.04, z_wall + 0.2)),
                                      ((x_root + pit_half, y_root, z_wall), (x_root + pit_half + 0.04, y_root + 0.04, z_wall + 0.2)),
                                      ((x_root - pit_half - 0.04, y_root, z_wall + 0.16), (x_root + pit_half + 0.04, y_root + 0.04, z_wall + 0.2)))):
            b.box(lo, hi, Mat("brick", color=(0.5, 0.33, 0.27)), skip=("back", "bottom"))
    branches = []
    step = 0.06
    width = hi_x - lo_x
    for k in range(stems):
        if cover:
            # Fächer aus dem Boden: Triebe laufen erst schräg zur Seite, dann nach oben – jeder hat
            # sein eigenes Ziel über die ganze Breite
            goal = lo_x + width * (k + 0.5) / stems
            heading = math.atan2(1.0, (goal - x_root) / max(0.3, top * 0.25))
            heading = min(max(heading, 0.25), math.pi - 0.25) + rnd.uniform(-0.1, 0.1)
        else:
            goal = None
            heading = math.pi / 2 + (k - (stems - 1) / 2) * 0.35 + rnd.uniform(-0.15, 0.15)
        start = (x_root + rnd.uniform(-0.08, 0.08), y_root + 0.01)
        branches.append([start, heading, 0, 0.008 * rnd.uniform(0.85, 1.1), rnd.uniform(0.8, 1.0) * (top - y_root) * 1.35, goal])
    paths = []
    # Belegung je 10-cm-Feld: höchstens drei Triebe – so verteilt sich der Efeu, statt sich in
    # einer schmalen Lücke zu stauen
    stem_cells = {}

    def cell(px, py):
        return (int(math.floor(px / 0.1)), int(math.floor(py / 0.1)))
    # So viel Trieb, wie die Blätter bedecken können
    stem_budget = max_leaves * 0.026
    grown = 0.0
    while branches and grown < stem_budget:
        (x, y), heading, depth, radius, budget, goal = branches.pop(0 if cover else -1)
        pts = [(x, y)]
        length = 0.0
        target_x = goal if goal is not None else x + rnd.uniform(-spread, spread) * (0.6 if depth == 0 else 1.0)
        while length < budget and y < top and grown < stem_budget:
            heading += rnd.gauss(0, 0.2)
            # Nach oben ziehen, zum eigenen Ziel auffächern
            pull = max(-1.0, min(1.0, (target_x - x) / 0.4))
            want = math.pi / 2 - pull * (0.9 if goal is not None and y < top * 0.3 else 0.5)
            heading += 0.15 * (want - heading)
            moved = False
            for turn in (0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5):
                h = heading + turn
                nx, ny = x + math.cos(h) * step, y + math.sin(h) * step
                if not (x_min < nx < x_max) or ny < y_root or _in_holes(nx, ny, holes, 0.07):
                    continue
                c = cell(nx, ny)
                if c != cell(x, y) and stem_cells.get(c, 0) >= 3 and ny > y_root + 0.15:
                    continue
                heading = h
                x, y = nx, ny
                moved = True
                break
            if not moved:
                break
            c = cell(x, y)
            if c != cell(*pts[-1]):
                stem_cells[c] = stem_cells.get(c, 0) + 1
            pts.append((x, y))
            length += step
            grown += step
            # Verzweigen: unten (bis 1,2 m) besonders oft, Seitentriebe streben zur Seite
            p_branch = 0.12 * density * (1.8 if y < y_root + 1.2 else 1.0) * (1.4 if cover else 1.0)
            if depth < 3 and rnd.random() < p_branch and length > 0.1:
                side = rnd.choice((-1, 1))
                sub_goal = None if goal is None else min(hi_x, max(lo_x, x + side * rnd.uniform(0.2, 0.6)))
                branches.append([(x, y), heading + side * rnd.uniform(0.5, 1.1), depth + 1, radius * 0.65,
                                 (budget - length) * rnd.uniform(0.45, 0.85), sub_goal])
        if len(pts) >= 3:
            paths.append((pts, depth, radius))
    # Mögliche Blattstellen auf allen Trieben sammeln, dann gemischt und gleichmäßig auswählen
    spots = []
    lines = []
    for pi_, (pts, depth, radius) in enumerate(paths):
        count = len(pts)
        rad = (lambda i, r=radius, n=count: max(0.0018, r * (1 - 0.8 * i / max(1, n - 1))))
        line = [Vector((px, py, stem_z(px, py, rad(i)))) for i, (px, py) in enumerate(pts)]
        lines.append(line)
        b.tube(line, lambda t, r=radius: max(0.0018, r * (1 - 0.8 * t)), IVY_STEM, segments=4 if radius > 0.006 else 3, caps=True)
        for i in range(1, count):
            # Haftwurzeln: kleine Fäden vom Trieb an die Wand
            if i % 3 == 0:
                for q in (-1, 1):
                    b.tube([line[i] + Vector((0, 0, -rad(i) * 0.5)), line[i] + Vector((q * 0.012, -0.006, -rad(i) - 0.0015))],
                           0.0009, IVY_STEM, segments=3, caps=False)
            for half in (0.0, 0.5):
                if half and i == count - 1:
                    continue
                p = line[i] if not half else line[i].lerp(line[i + 1], 0.5)
                spots.append((p + Vector((0, 0, rad(i) * 0.6)), i > count - 4, pi_))
    rnd.shuffle(spots)
    leaf_cells = {}
    leaves = 0
    cap = 6 if cover else 5
    side_sign = 1
    for p, young, _ in spots:
        if leaves >= max_leaves:
            break
        frac = (p.y - y_root) / max(0.01, top - y_root)
        size = leaf_size * rnd.uniform(0.8, 1.2) * (1.0 - 0.3 * frac) * (0.6 if young else 1.0)
        if _in_holes(p.x, p.y, holes, size * 0.9):
            continue
        c = cell(p.x, p.y)
        if leaf_cells.get(c, 0) >= cap:
            continue
        leaf_cells[c] = leaf_cells.get(c, 0) + 1
        leaves += 1
        out = Vector((side_sign * rnd.uniform(0.1, 0.5), rnd.uniform(-0.1, 0.25), 1.0))
        side_sign = -side_sign
        ivy_leaf(b, p, out, size, rnd, space, young=young, glow=glow)
    # Spitzen: zwei junge, helle Blättchen
    for line in lines:
        tip = line[-1]
        for q in range(2):
            ivy_leaf(b, tip, Vector((rnd.uniform(-0.4, 0.4), 0.3, 1.0)), leaf_size * 0.45, rnd, space, young=True, glow=glow, hang=0.2)


def ivy_garland(b, x0, x1, y, z, rnd, drops=True, drop_max=1.2, leaf_size=0.06, holes=(), glow=0.0, z_back=0.0, side_drops=(),
                source=None, pipe=None, lanes=4):
    """Efeu, der oben auf einem Sims (Höhe y, Vorderkante z) entlangwächst und in Ranken
    herabhängt (z. B. über dem Pub-Schild). Die Triebe liegen auf dem Sims, die Ranken hängen
    vor der Front (Ebene z). source = Pflanztrog auf dem Sims, aus dem der Efeu wächst
    (x_links, x_rechts, Höhe Erde, Höhe Rand, z_vorn, z_hinten) – links oder rechts: die Triebe
    kommen aus der Erde, gehen über den Rand und laufen auf dem Sims weiter. pipe = x eines
    Fallrohrs auf dem Sims (Blätter wachsen nicht hinein)."""
    space = Space().wall(z - 0.002, y0=-1e9, y1=y - 0.005, gap=0.006).floor(y, z0=-1e9, z1=z, gap=0.002).wall(z_back, y0=y - 0.01)
    corners = [b.xf @ Vector(c) for c in ((x0 - 0.3, y - 0.4, z_back), (x1 + 0.3, y - 0.4, z))]
    _register(b, "box", (Vector((min(c.x for c in corners), y - 0.4, min(c.z for c in corners))),
                         Vector((max(c.x for c in corners), y, max(c.z for c in corners))), 0.0, 0.4,
                         (b.xf.to_3x3() @ Vector((0, 0, -1))).normalized(), None, None))
    if pipe is not None:
        space.cylinder(pipe, 0.07, 0.045, y - 0.01, y + 3.0)
    right = False
    if source:
        sx0, sx1, soil_y, rim_y, sz0, sz1 = source
        space.block((sx0, y - 0.01, sz0), (sx1, rim_y, sz1), gap=0.005)
        right = (sx0 + sx1) / 2 > (x0 + x1) / 2
    # Liegende Haupttriebe auf dem Sims
    for lane in range(lanes):
        zz = z - 0.045 - lane * 0.05
        pts = []
        if source and not right:
            pts += [Vector((sx0 + 0.12 + 0.05 * lane, soil_y + 0.005, zz)), Vector((sx1 - 0.08, rim_y + 0.02, zz)),
                    Vector((sx1 + 0.03, rim_y + 0.012, zz)), Vector((sx1 + 0.12, y + 0.008, zz))]
            x = sx1 + 0.2
        else:
            x = x0
        end = (sx0 - 0.2) if (source and right) else x1
        while x < end:
            pts.append(Vector((x, y + 0.008, zz + rnd.uniform(-0.015, 0.015))))
            x += 0.06
        pts.append(Vector((end, y + 0.008, zz)))
        if source and right:
            pts += [Vector((sx0 - 0.12, y + 0.008, zz)), Vector((sx0 - 0.03, rim_y + 0.012, zz)), Vector((sx0 + 0.08, rim_y + 0.02, zz)),
                    Vector((sx1 - 0.12 - 0.05 * lane, soil_y + 0.005, zz))]
        b.tube(pts, 0.007 - lane * 0.001, IVY_STEM, segments=4)
        for k, p in enumerate(pts[1:-1]):
            for q in range(3 if lane == 0 else 2):
                out = Vector((rnd.uniform(-0.6, 0.6), 1.0, rnd.uniform(0.2, 0.9))) if q < 2 else Vector((rnd.uniform(-0.4, 0.4), 0.2, 1.0))
                ivy_leaf(b, p, out, leaf_size * rnd.uniform(0.85, 1.25), rnd, space, glow=glow, hang=0.1 if q < 2 else 0.8)
    for x, length in side_drops:
        if source and sx0 - 0.02 < x < sx1 + 0.02:
            start = Vector((x, soil_y + 0.005, z - 0.08))
            trailing_ivy(b, start, length, rnd, Vector((0, 0, 1)), space=space, leaf_size=leaf_size, glow=glow,
                         over=sz1 - start.z + 0.09, lift=rim_y - soil_y + 0.02)
        else:
            trailing_ivy(b, Vector((x, y + 0.01, z - 0.06)), length, rnd, Vector((0, 0, 1)), space=space, leaf_size=leaf_size, glow=glow,
                         over=0.09, lift=0.01)
    if not drops:
        return
    # Ranken, die über die Kante herabhängen
    lo = (sx1 + 0.1) if (source and not right) else x0
    hi = (sx0 - 0.1) if (source and right) else x1
    x = lo + rnd.uniform(0.05, 0.2)
    while x < hi - 0.05:
        if not _in_holes(x, y - 0.1, holes, 0.05):
            length = rnd.uniform(0.15, drop_max) if rnd.random() < 0.45 else rnd.uniform(0.1, 0.35)
            trailing_ivy(b, Vector((x, y + 0.01, z - 0.05)), length, rnd, Vector((0, 0, 1)), space=space, leaf_size=leaf_size * 0.85, glow=glow,
                         over=0.08, lift=0.01)
        x += rnd.uniform(0.07, 0.18)


def trailing_ivy(b, start, length, rnd, out=Vector((0, 0, 1)), space=NO_SPACE, leaf_size=0.05, glow=0.0, kind="ivy", palette=None,
                 over=0.07, lift=0.03):
    """Hängende Ranke: geht vom Startpunkt (auf der Erde/dem Sims) erst ein Stück nach vorn über
    die Kante, dann nach unten; Blätter an Stielen abwechselnd links/rechts, an der Spitze kleiner.
    kind: "ivy" (Efeu), "petunia" (Hängepetunie mit Blüten), "lobelia" (kleine Blüten)."""
    out = Vector(out).normalized()
    start = Vector(start)
    over = start + out * over * rnd.uniform(0.9, 1.2) + Vector((0, lift, 0))
    pts = [start, start.lerp(over, 0.5) + Vector((0, lift * 0.6, 0)), over]
    sway = rnd.uniform(-0.05, 0.05)
    p = over
    steps = max(2, int(length / 0.045))
    for k in range(steps):
        t = (k + 1) / steps
        p = p + Vector((sway * 0.3 * math.cos(t * 3 + sway * 20), -length / steps, 0)) + out * (0.006 * (1 - t))
        pts.append(p.copy())
    pts = [space.push(q) for q in pts]
    stem(b, pts, 0.0032, 0.0016, IVY_STEM if kind == "ivy" else STEM_GREEN, segments=3, space=space)
    flip = 1
    for k in range(2, len(pts)):
        t = k / len(pts)
        if kind == "ivy":
            size = leaf_size * (1.0 - 0.45 * t) * rnd.uniform(0.85, 1.15)
            ivy_leaf(b, pts[k], out + Vector((flip * 0.6, 0.1, 0)), size, rnd, space, young=t > 0.8, glow=glow)
        elif kind == "petunia":
            leaf_dir = (out * 0.6 + Vector((flip * 0.7, -0.3, 0))).normalized()
            card(b, pts[k], leaf_dir, out + Vector((0, 0.6, 0)), 0.045 * (1 - 0.3 * t), 0.045, leaf_mat("broad_leaf", rnd, glow=glow),
                 rows=1, fold=0.3, curl=0.3, space=space)
            if k % 2 == 0 and palette:
                fp = pts[k] + out * 0.03 + Vector((flip * 0.02, -0.01, 0))
                stem(b, [pts[k], fp], 0.0015, 0.0012, STEM_GREEN, segments=3, space=space)
                blossom(b, fp + out * 0.008, (out + Vector((flip * 0.3, -0.25, 0))), 0.06, bloom_mat("petunia", rnd.choice(BLOSSOMS[palette]), glow, rnd),
                        cup=0.3, spin=rnd.uniform(0, 6.28), space=space)
        else:
            card(b, pts[k], (out * 0.5 + Vector((flip * 0.8, 0.2, 0))), out, 0.03, 0.03, leaf_mat("narrow_leaf", rnd, tint=(0.9, 1.05, 0.9), glow=glow),
                 rows=1, space=space)
            if palette:
                for q in range(2):
                    fp = space.push(pts[k] + out * rnd.uniform(0.01, 0.02) + Vector((rnd.uniform(-0.018, 0.018), rnd.uniform(-0.015, 0.01), 0)))
                    b.tube([pts[k], fp], 0.0009, STEM_GREEN, segments=3, caps=False)
                    blossom(b, fp, out + Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.3, 0.3), 0)), 0.016,
                            bloom_mat("floret5", rnd.choice(BLOSSOMS[palette]), glow, rnd), cup=0.1, spin=rnd.uniform(0, 6.28), space=space)
        flip = -flip


# ---------------------------------------------------------------------------------------------
# Beet- und Balkonpflanzen
# ---------------------------------------------------------------------------------------------

def geranium(b, base, rnd, palette="rose", scale=1.0, space=NO_SPACE, glow=0.0, flowers=None):
    """Geranie (Pelargonie): kräftige Triebe aus der Erde, runde Blätter mit dunkler Zone an
    langen Stielen – zusammen eine dichte Kuppel, die auch über den Rand hängt – darüber
    Blütendolden auf langen Stielen. base = Punkt auf der Erde."""
    base = Vector(base)
    colors = BLOSSOMS[palette]
    nodes = []
    for k in range(rnd.randint(4, 6)):
        d = _rand_dir(rnd, 0.0, 0.0)
        tip = space.push(base + Vector((d.x * 0.05, rnd.uniform(0.05, 0.1), d.z * 0.05)) * scale)
        stem(b, _curve(base, tip, (0, 0.01, 0), 3), 0.006 * scale, 0.004 * scale, STEM_BROWN, space=space)
        nodes.append(tip)
    center = base + Vector((0, 0.06 * scale, 0))
    dome = 0.13 * scale
    count = _n(rnd.randint(24, 30))
    for k, d in enumerate(_fib_sphere(count * 2, rnd)[:count]):
        # Nur die obere Hälfte und ein Kranz knapp darunter (hängt über den Rand)
        if d.y < -0.25:
            d.y = -d.y * 0.4
        d.normalize()
        end = space.push(center + Vector((d.x, d.y * 0.75, d.z)) * dome * rnd.uniform(0.7, 1.05))
        node = min(nodes, key=lambda n: (n - end).length)
        stem(b, _curve(node, end, (0, 0.015 * scale, 0), 3), 0.0025 * scale, 0.002 * scale, STEM_GREEN, space=space)
        size = rnd.uniform(0.075, 0.1) * scale
        flat = Vector((d.x, 0, d.z))
        out = flat.normalized() if flat.length > 1e-3 else _rand_dir(rnd, 0.0, 0.0)
        facing = (Vector((0, 1, 0)) + out * (0.2 + 0.6 * max(0.0, 0.5 - d.y))).normalized()
        card(b, end - out * size * 0.45, out, facing, size, size, leaf_mat("round_leaf", rnd, glow=glow), rows=2,
             fold=rnd.uniform(0.0, 0.2), curl=rnd.uniform(0.1, 0.45), space=space)
    count = flowers if flowers is not None else rnd.randint(4, 6)
    for k in range(count):
        node = rnd.choice(nodes)
        d = _rand_dir(rnd, 0.0, 0.0)
        top = space.push(center + Vector((d.x * dome * 0.6, dome * 0.75 + rnd.uniform(0.05, 0.11) * scale, d.z * dome * 0.6)))
        stem(b, _curve(node, top, (d.x * 0.02, 0, d.z * 0.02), 4), 0.0028 * scale, 0.0022 * scale, STEM_GREEN, space=space)
        umbel(b, top, 0.045 * scale, rnd, rnd.choice(colors), count=_n(rnd.randint(10, 14)), size=0.034 * scale, space=space, glow=glow)


def umbel(b, top, radius, rnd, color, count=14, size=0.032, space=NO_SPACE, glow=0.0, layer="floret5"):
    """Blütendolde: kurze Blütenstiele vom Stielende zu Blüten auf einer Halbkugel, dazu Knospen."""
    top = Vector(top)
    center = top + Vector((0, radius * 0.45, 0))
    for d in _fib_sphere(count * 2, rnd)[:count]:
        if d.y < -0.15:
            d.y = -d.y * 0.5
        d.normalize()
        p = center + d * radius
        stem(b, [top, top.lerp(p, 0.5) + Vector((0, radius * 0.1, 0)), p - d * size * 0.15], 0.0011, 0.0009, STEM_GREEN, segments=3, space=space)
        tone = tuple(min(1.0, c * rnd.uniform(0.92, 1.05)) for c in color)
        blossom(b, p, d + Vector((0, 0.4, 0)), size * rnd.uniform(0.9, 1.1), bloom_mat(layer, tone, glow), cup=0.2,
                spin=rnd.uniform(0, 6.28), space=space)
    for k in range(3):
        d = _rand_dir(rnd, -0.3, 0.4)
        p = space.push(top + d * radius * 0.7 + Vector((0, radius * 0.1, 0)))
        stem(b, [top, p], 0.0011, 0.0009, STEM_GREEN, segments=3, space=space)
        b.sphere(p, 0.006, soft_mat(tuple(round(0.5 * c + 0.2, 3) for c in color), layer="foliage"), rings=3, segments=5, squash=1.3)


def petunia_plant(b, base, rnd, palette="lavender", scale=1.0, space=NO_SPACE, glow=0.0, trail=0.0, out=Vector((0, 0, 1)),
                  reach=0.07, lift=0.03):
    """Petunie: weiche, eiförmige Blätter an liegenden Trieben, große Trichterblüten nach außen
    und oben. trail > 0: einige Triebe hängen so weit über die Kante (Richtung out)."""
    base = Vector(base)
    colors = BLOSSOMS[palette]
    for k in range(_n(rnd.randint(12, 15))):
        a = 2 * math.pi * k / 13 + rnd.uniform(-0.4, 0.4)
        d = Vector((math.cos(a), 0, math.sin(a)))
        end = space.push(base + d * rnd.uniform(0.06, 0.14) * scale + Vector((0, rnd.uniform(0.09, 0.19) * scale, 0)))
        pts = _curve(base, end, (0, 0.03 * scale, 0), 4)
        stem(b, pts, 0.003 * scale, 0.002 * scale, STEM_GREEN, space=space)
        for j, p in enumerate(pts[1:]):
            for q in (-1, 1):
                side = Vector((0, 1, 0)).cross(d).normalized() * q
                card(b, p, (d + side * 0.9 + Vector((0, rnd.uniform(-0.1, 0.4), 0))), Vector((0, 1, 0)) + d * 0.3, 0.06 * scale, 0.06 * scale,
                     leaf_mat("broad_leaf", rnd, tint=(1.0, 1.06, 0.88), glow=glow), rows=1, fold=0.3, curl=0.35, space=space)
        bud = space.push(end + d * 0.02 * scale + Vector((0, 0.015 * scale, 0)))
        stem(b, [end, bud], 0.0018 * scale, 0.0015 * scale, STEM_GREEN, segments=3, space=space)
        blossom(b, bud, d * 0.7 + Vector((0, 0.7, 0)), 0.07 * scale, bloom_mat("petunia", rnd.choice(colors), glow, rnd),
                cup=0.32, spin=rnd.uniform(0, 6.28), space=space)
    if trail > 0:
        for k in range(rnd.randint(1, 2)):
            trailing_ivy(b, base + Vector((rnd.uniform(-0.04, 0.04), 0.01, 0)), trail * rnd.uniform(0.6, 1.0), rnd, out, space,
                         kind="petunia", palette=palette, glow=glow, over=reach, lift=lift)


def lobelia(b, base, rnd, palette="blue", scale=1.0, space=NO_SPACE, glow=0.0, trail=0.0, out=Vector((0, 0, 1)),
            reach=0.07, lift=0.03):
    """Lobelie/Steinkraut: kleines Polster aus feinen Blättchen, übersät mit winzigen Blüten;
    mit trail hängen ein paar Triebe herab."""
    base = Vector(base)
    colors = BLOSSOMS[palette]
    for d in _fib_sphere(26, rnd)[:_n(16)]:
        p = space.push(base + Vector((d.x * 0.07, abs(d.y) * 0.06 + 0.01, d.z * 0.07)) * scale)
        stem(b, [base, p], 0.0015 * scale, 0.001 * scale, STEM_GREEN, segments=3, space=space)
        card(b, p, d + Vector((0, 0.5, 0)), d + Vector((0, 1, 0)), 0.035 * scale, 0.03 * scale,
             leaf_mat("narrow_leaf", rnd, tint=(0.9, 1.1, 0.85), glow=glow), rows=1, space=space)
        for q in range(2):
            fp = space.push(p + _rand_dir(rnd, 0.0, 1.0) * 0.014 * scale)
            b.tube([p, fp], 0.0009, STEM_GREEN, segments=3, caps=False)
            blossom(b, fp, d + Vector((0, 0.8, 0)), 0.017 * scale, bloom_mat("floret5", rnd.choice(colors), glow, rnd), cup=0.1,
                    spin=rnd.uniform(0, 6.28), space=space)
    if trail > 0:
        for k in range(rnd.randint(1, 3)):
            trailing_ivy(b, base + Vector((rnd.uniform(-0.03, 0.03), 0.01, 0)), trail * rnd.uniform(0.5, 1.0), rnd, out, space,
                         kind="lobelia", palette=palette, glow=glow, over=reach, lift=lift)


def daisy_plant(b, base, rnd, scale=1.0, space=NO_SPACE, glow=0.0, color=(0.97, 0.97, 0.95)):
    """Margerite: schmale Blätter, Blüten auf dünnen Stielen."""
    base = Vector(base)
    count = _n(16)
    for k in range(count):
        a = 2 * math.pi * k / count + rnd.uniform(-0.15, 0.15)
        flat = Vector((math.cos(a), 0, math.sin(a)))
        d = (flat + Vector((0, rnd.uniform(0.5, 1.4), 0))).normalized()
        card(b, base + flat * rnd.uniform(0.01, 0.03) * scale + Vector((0, 0.004 * (k % 3), 0)), d, Vector((0, 1, 0)) - d * d.y,
             0.1 * scale, 0.08 * scale, leaf_mat("fern_frond", rnd, tint=(0.95, 1.05, 0.9), glow=glow), rows=2, curl=0.6, space=space)
    for k in range(_n(rnd.randint(9, 13))):
        d = _rand_dir(rnd, 0.0, 0.0)
        top = space.push(base + Vector((d.x * 0.09, rnd.uniform(0.14, 0.26), d.z * 0.09)) * scale)
        stem(b, _curve(base, top, (d.x * 0.02, 0, d.z * 0.02), 3), 0.002 * scale, 0.0015 * scale, STEM_GREEN, segments=3, space=space)
        blossom(b, top, d * 0.5 + Vector((0, 1, 0)), 0.065 * scale, bloom_mat("daisy", color, glow), cup=0.15,
                spin=rnd.uniform(0, 6.28), space=space)


def bedding_row(b, x0, x1, y, z0, z1, rnd, palettes, space, glow=0.0, trail_front=0.0, front_dir=Vector((0, 0, 1)), spacing=0.12):
    """Reihe Balkonblumen (Blumenkasten, Beet): Geranien, Petunien, Lobelien und Margeriten
    abwechselnd; vorn hängen Ranken über die Kante (trail_front = Länge)."""
    n = max(2, int((x1 - x0) / spacing))
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n + rnd.uniform(-0.02, 0.02)
        z = z0 + (z1 - z0) * (rnd.uniform(0.25, 0.45) if k % 2 else rnd.uniform(0.55, 0.8))
        pal = palettes[k % len(palettes)]
        kind = rnd.random()
        p = Vector((x, y, z))
        if kind < 0.45:
            geranium(b, p, rnd, pal if pal in ("rose", "coral", "red", "white") else "rose", 0.95, space, glow)
        elif kind < 0.72:
            petunia_plant(b, p, rnd, pal if pal in ("lavender", "rose", "white") else "lavender", 0.9, space, glow)
        elif kind < 0.86:
            daisy_plant(b, p, rnd, 0.9, space, glow)
        else:
            lobelia(b, p, rnd, "blue" if pal != "white" else "white", 1.0, space, glow)
    if trail_front > 0:
        x = x0 + rnd.uniform(0.04, 0.12)
        while x < x1 - 0.04:
            start = Vector((x, y + 0.005, z1 - 0.04))
            kind = rnd.choice(["ivy", "ivy", "lobelia", "petunia"])
            trailing_ivy(b, start, trail_front * rnd.uniform(0.45, 1.0), rnd, front_dir, space, leaf_size=0.05,
                         glow=glow, kind=kind, palette=rnd.choice(["blue", "white"]) if kind == "lobelia" else rnd.choice(palettes),
                         over=0.09)
            x += rnd.uniform(0.07, 0.15) / DETAIL[-1]


# ---------------------------------------------------------------------------------------------
# Formgehölze und Kübelpflanzen
# ---------------------------------------------------------------------------------------------

def box_ball(b, center, radius, rnd, space=NO_SPACE, glow=0.0, core=True):
    """Buchskugel: dichte Kugel aus vielen kleinen Buchs-Zweigen, die nach außen zeigen; innen
    ein dunkler Kern, damit man nicht hindurchsieht."""
    center = Vector(center)
    if core:
        b.sphere(center, radius * 0.8, Mat("foliage", color=(0.16, 0.24, 0.1), glow=glow), rings=6, segments=10)
    length = max(0.07, min(0.12, radius * 0.5))
    count = _n(int(4 * math.pi * radius * radius / (length * length * 0.22)))
    for k, d in enumerate(_fib_sphere(count, rnd)):
        mat = leaf_mat("box_sprig", rnd, glow=glow, shade=1.0 + 0.15 * max(0.0, d.y))
        size = length * rnd.uniform(0.85, 1.15)
        tangent = d.cross(_rand_dir(rnd))
        if tangent.length < 0.1:
            tangent = d.orthogonal()
        tangent.normalize()
        if k % 4:
            # Anliegend: Zweig liegt auf der Kugel, folgt ihrer Rundung
            base = center + d * radius * 0.93 - tangent * size * 0.5
            card(b, base, tangent, d, size, size, mat, rows=2, curl=size / radius * 0.9, space=space)
        else:
            # Abstehend: Zweig wächst nach außen (macht den Rand buschig)
            along = (d + _rand_dir(rnd) * 0.35).normalized()
            size *= 0.7
            base = center + d * (radius - size * 0.75)
            card(b, base, along, tangent, size, size, mat, rows=2, fold=0.15, curl=rnd.uniform(-0.2, 0.3), space=space)


def box_cone(b, base, height, radius, rnd, space=NO_SPACE, glow=0.0, layer="box_sprig"):
    """Kegel aus Buchs oder Lorbeer (Form geschnitten), unten breit, oben spitz."""
    base = Vector(base)
    b.cylinder(base, radius * 0.8, height * 0.9, Mat("foliage", color=(0.16, 0.24, 0.1), glow=glow), segments=10, radius_top=0.01,
               caps=(True, False))
    length = max(0.08, min(0.15, radius * 0.6))
    slant = math.hypot(radius, height)
    count = int(math.pi * radius * slant / (length * length * 0.2))
    for k in range(count):
        t = math.sqrt(rnd.random())
        y = height * (1 - t)
        r = radius * t
        a = rnd.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a) * height, radius, math.sin(a) * height)).normalized()
        p = base + Vector((math.cos(a) * r, y, math.sin(a) * r)) - d * length * 0.6
        along = (d + Vector((0, 0.6, 0)) + _rand_dir(rnd) * 0.3).normalized()
        card(b, p, along, d.cross(_rand_dir(rnd)), length, length, leaf_mat(layer, rnd, glow=glow), rows=2, fold=0.15, curl=0.1, space=space)
    card(b, base + Vector((0, height - length * 0.5, 0)), Vector((0, 1, 0)), Vector((1, 0, 0)), length, length,
         leaf_mat(layer, rnd, glow=glow), rows=2, space=space)


def standard_ball(b, base, height, radius, rnd, space=NO_SPACE, glow=0.0):
    """Hochstämmchen: dünner Stamm aus der Erde, oben eine Buchskugel."""
    base = Vector(base)
    top = base + Vector((rnd.uniform(-0.01, 0.01), height - radius * 0.6, rnd.uniform(-0.01, 0.01)))
    b.tube([base, base.lerp(top, 0.5) + Vector((0.008, 0, 0)), top], lambda t: 0.018 - 0.006 * t, BARK, segments=6)
    box_ball(b, base + Vector((0, height, 0)), radius, rnd, space, glow)


def resting_height(rim_y, rim_radius, radius):
    """Mittelpunkt einer Kugel (Radius radius), die auf einem runden Rand (Radius rim_radius) liegt."""
    if radius <= rim_radius:
        return rim_y + radius * 0.6
    return rim_y + math.sqrt(radius * radius - rim_radius * rim_radius) + 0.01


def olive(b, base, height, rnd, space=NO_SPACE, glow=0.0):
    """Olivenbäumchen: knorriger Stamm, vier Äste in eine runde Krone, viele Zweige mit schmalen,
    silbrig-grünen Blättern, paarweise und dicht."""
    base = Vector(base)
    trunk_top = base + Vector((rnd.uniform(-0.03, 0.03), height * 0.48, rnd.uniform(-0.03, 0.03)))
    b.tube(_curve(base, trunk_top, (0.03, 0, -0.02), 5), lambda t: 0.035 - 0.012 * t, BARK, segments=7)
    crown = trunk_top + Vector((0, height * 0.28, 0))
    radius = height * 0.26
    leaf = lambda: leaf_mat("narrow_leaf", rnd, tint=(0.97, 1.03, 0.97), glow=glow)
    for k in range(4):
        a = 2 * math.pi * k / 4 + rnd.uniform(-0.4, 0.4)
        d = Vector((math.cos(a), 0, math.sin(a)))
        end = crown + d * radius * 0.45 + Vector((0, rnd.uniform(-0.05, 0.12), 0))
        b.tube(_curve(trunk_top, end, (0, 0.02, 0), 4), lambda t: 0.02 - 0.011 * t, BARK, segments=5)
        for j in range(12):
            start = trunk_top.lerp(end, rnd.uniform(0.55, 1.0))
            target = crown + (_rand_dir(rnd, -0.5, 1.0) + d * 0.6).normalized() * radius * rnd.uniform(0.85, 1.05)
            pts = _curve(start, target, (0, 0.02, 0), 9)
            stem(b, pts, 0.0045, 0.0018, STEM_BROWN, segments=3, space=space)
            for i in range(1, len(pts)):
                p = pts[i]
                tangent = (pts[i] - pts[i - 1]).normalized()
                side = tangent.cross(Vector((0, 1, 0)))
                if side.length < 0.1:
                    side = Vector((1, 0, 0))
                side.normalize()
                for s in (-1, 1):
                    along = (tangent * 0.7 + side * s + Vector((0, rnd.uniform(-0.3, 0.3), 0))).normalized()
                    card(b, p, along, Vector((0, 1, 0)) + side * s * 0.4, rnd.uniform(0.065, 0.085), 0.075, leaf(), rows=1,
                         fold=0.25, curl=0.2, space=space)
            card(b, pts[-1], tangent, Vector((0, 1, 0)), 0.06, 0.06, leaf(), rows=1, space=space)


def hydrangea(b, base, radius, rnd, palette="hydrangea", space=NO_SPACE, glow=0.0, heads=None):
    """Hortensie: Triebe aus der Erde mit großen, gegenständigen, gesägten Blättern, oben runde
    Blütenbälle aus vielen vierzähligen Einzelblüten."""
    base = Vector(base)
    colors = BLOSSOMS[palette]
    count = heads if heads is not None else max(4, int(radius / 0.05))
    for k in range(count):
        a = 2 * math.pi * k / count + rnd.uniform(-0.3, 0.3)
        reach = radius * rnd.uniform(0.25, 0.75)
        top = base + Vector((math.cos(a) * reach, rnd.uniform(0.28, 0.42) * radius / 0.3, math.sin(a) * reach))
        top = space.push(top)
        pts = _curve(base + Vector((math.cos(a) * 0.03, 0, math.sin(a) * 0.03)), top, (0, 0.02, 0), 4)
        stem(b, pts, 0.006, 0.004, STEM_GREEN, segments=4, space=space)
        d = Vector((math.cos(a), 0, math.sin(a)))
        for j, p in enumerate(pts[1:-1] + [pts[1].lerp(pts[2], 0.5), pts[2].lerp(pts[3], 0.5)]):
            side = Vector((0, 1, 0)).cross(d).normalized()
            side = (side * math.cos(j * 1.3) + d * math.sin(j * 1.3) * 0.5).normalized()
            for s in (-1, 1):
                along = (d * 0.6 + side * s + Vector((0, -0.1, 0))).normalized()
                size = rnd.uniform(0.11, 0.15) * min(1.3, radius / 0.3 + 0.3)
                card(b, p, along, Vector((0, 1, 0)) + d * 0.3, size, size * 0.85, leaf_mat("broad_leaf", rnd, glow=glow), rows=2,
                     fold=0.3, curl=0.35, space=space)
        head_r = rnd.uniform(0.075, 0.1) * min(1.2, radius / 0.3 + 0.2)
        flower_ball(b, top + Vector((0, head_r * 0.6, 0)), head_r, rnd, rnd.choice(colors), space, glow)


def flower_ball(b, center, radius, rnd, color, space=NO_SPACE, glow=0.0):
    """Blütenball der Hortensie: Kern in Blütenfarbe, darauf viele Einzelblüten."""
    center = space.push(Vector(center))
    core = tuple(c * 0.75 for c in color)
    b.sphere(center, radius * 0.82, Mat("foliage", color=core, glow=glow), rings=5, segments=8)
    count = _n(int(4 * math.pi * radius * radius / (0.04 * 0.04 * 0.55)))
    for d in _fib_sphere(count, rnd):
        if d.y < -0.6:
            continue
        tone = tuple(min(1.0, c * rnd.uniform(0.88, 1.06)) for c in color)
        # Einzelblüten sitzen dicht auf dem Kern (kurze Stiele, nichts schwebt)
        blossom(b, center + d * radius * rnd.uniform(0.86, 0.93), d, rnd.uniform(0.03, 0.04), bloom_mat("floret4", tone, glow), cup=0.15,
                spin=rnd.uniform(0, 6.28), space=space)


def lavender(b, base, radius, rnd, space=NO_SPACE, glow=0.0):
    """Lavendel: viele holzige Triebe aus der Erde, dicht mit schmalen, graugrünen Blättern,
    an den Spitzen lange Stiele mit violetten Blütenähren."""
    base = Vector(base)
    leaf = lambda: leaf_mat("narrow_leaf", rnd, tint=(0.95, 1.0, 1.0), shade=1.12, glow=glow)
    spike_mat = Mat("lavender", color=(NEUTRAL,) * 3, glow=glow)
    count = int(18 * radius / 0.15)
    for k in range(count):
        a = 2 * math.pi * k / count + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        lean = rnd.uniform(0.2, 0.8)
        tip = space.push(base + d * radius * lean * 0.9 + Vector((0, radius * rnd.uniform(0.8, 1.2), 0)))
        pts = _curve(base + d * 0.01, tip, (0, 0.02, 0), 4)
        stem(b, pts, 0.003, 0.002, STEM_BROWN, segments=3, space=space)
        for i in range(1, len(pts)):
            tangent = (pts[i] - pts[i - 1]).normalized()
            for q in range(3):
                side = _rand_dir(rnd, -0.2, 0.2)
                along = (tangent * 0.8 + side).normalized()
                card(b, pts[i], along, side.cross(along), rnd.uniform(0.06, 0.085), 0.06, leaf(), rows=1, curl=0.25, space=space)
        # Blütenstiele aus der Triebspitze
        for q in range(rnd.randint(1, 2)):
            up = (Vector((0, 1, 0)) + d * rnd.uniform(0.1, 0.45) + _rand_dir(rnd, -0.1, 0.1) * 0.2).normalized()
            top = space.push(tip + up * rnd.uniform(0.18, 0.26) * radius / 0.15)
            stem(b, [tip, tip.lerp(top, 0.5) + d * 0.008, top], 0.0016, 0.0012, Mat("plain", color=(0.45, 0.5, 0.38)), segments=3, space=space)
            spike = rnd.uniform(0.1, 0.13)
            spin = rnd.uniform(0, 3.14)
            for r in range(2):
                facing = Vector((math.cos(spin + r * 1.57), 0, math.sin(spin + r * 1.57)))
                card(b, top - up * spike * 0.48, up, facing, spike, spike * 0.5, spike_mat, rows=1, space=space)


def fern(b, base, size, rnd, space=NO_SPACE, glow=0.0):
    """Farn: Wedel wachsen aus der Mitte, steigen auf und biegen sich nach außen."""
    base = Vector(base)
    for k in range(rnd.randint(8, 12)):
        a = 2 * math.pi * k / 10 + rnd.uniform(-0.3, 0.3)
        elev = rnd.uniform(0.9, 1.3)
        along = Vector((math.cos(a) * math.cos(elev), math.sin(elev), math.sin(a) * math.cos(elev)))
        facing = Vector((0, 1, 0)) - along * along.y
        length = size * rnd.uniform(0.75, 1.1)
        card(b, base + Vector((math.cos(a), 0, math.sin(a))) * 0.015, along, facing, length, length * 0.6,
             leaf_mat("fern_frond", rnd, glow=glow), rows=4, curl=rnd.uniform(0.9, 1.4), fold=0.15, space=space)


def hosta(b, base, size, rnd, space=NO_SPACE, glow=0.0):
    """Funkie: breite, herzförmige Blätter mit tiefen Längsadern an bogigen Stielen."""
    base = Vector(base)
    for k in range(rnd.randint(9, 13)):
        a = 2 * math.pi * k / 11 + rnd.uniform(-0.25, 0.25)
        d = Vector((math.cos(a), 0, math.sin(a)))
        reach = size * rnd.uniform(0.35, 0.6)
        end = space.push(base + d * reach + Vector((0, size * rnd.uniform(0.35, 0.6), 0)))
        stem(b, _curve(base, end, (0, size * 0.1, 0), 4), 0.006, 0.004, Mat("plain", color=(0.45, 0.55, 0.35)), segments=4, space=space)
        leaf = size * rnd.uniform(0.6, 0.8)
        card(b, end, d + Vector((0, -0.15, 0)), Vector((0, 1, 0)), leaf, leaf * 0.85,
             leaf_mat("heart_leaf", rnd, tint=(0.95, 1.0, 1.05), glow=glow), rows=3, fold=0.35, curl=0.5, space=space)


def grass(b, base, size, rnd, space=NO_SPACE, glow=0.0):
    """Grasbüschel: zwei gekreuzte Flächen."""
    base = Vector(base)
    spin = rnd.uniform(0, 3.14)
    for q in range(3):
        facing = Vector((math.cos(spin + q * 1.05), 0, math.sin(spin + q * 1.05)))
        card(b, base, Vector((0, 1, 0)), facing, size, size, leaf_mat("grass_tuft", rnd, glow=glow), rows=2, curl=0.15, space=space)


def shrub(b, base, radius, height, rnd, palette=None, space=NO_SPACE, glow=0.0, layer="leaf_spray"):
    """Strauch: viele Triebe aus dem Boden, verzweigt, dicht mit Laubzweigen besetzt (rundliche
    Form); mit palette Blütenbälle (Hortensie) obenauf."""
    base = Vector(base)
    center = base + Vector((0, height * 0.55, 0))
    tips = []
    for k in range(rnd.randint(7, 9)):
        a = 2 * math.pi * k / 8 + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        end = space.push(base + d * radius * rnd.uniform(0.35, 0.6) + Vector((0, height * rnd.uniform(0.5, 0.8), 0)))
        b.tube([space.push(p) for p in _curve(base + d * 0.03, end, (0, 0.05, 0), 4)], lambda t: 0.014 - 0.009 * t, STEM_BROWN, segments=4)
        tips.append((end, d))
        for j in range(3):
            mid = (base + d * 0.03).lerp(end, rnd.uniform(0.35, 0.8))
            d2 = (d + _rand_dir(rnd, -0.1, 0.8)).normalized()
            twig = space.push(mid + d2 * radius * rnd.uniform(0.3, 0.5))
            b.tube([mid, twig], lambda t: 0.008 - 0.005 * t, STEM_BROWN, segments=3)
            tips.append((twig, d2))
    for p, d in tips:
        for q in range(6):
            along = (d + _rand_dir(rnd, -0.3, 1.0) * 0.9).normalized()
            size = radius * rnd.uniform(0.5, 0.75)
            rel = p - center
            card(b, p - along * size * 0.15, along, _rand_dir(rnd).cross(along), size, size,
                 leaf_mat(layer, rnd, glow=glow, shade=0.9 + 0.15 * max(0.0, rel.y / max(height, 0.1))), rows=2, fold=0.1, curl=0.3,
                 space=space)
    if palette:
        for p, d in tips[::2]:
            flower_ball(b, p + d * 0.05 + Vector((0, 0.06, 0)), rnd.uniform(0.07, 0.09), rnd, rnd.choice(BLOSSOMS[palette]), space, glow)


def tree(b, base, height, rnd, space=NO_SPACE):
    """Laubbaum: Stamm mit Rinde und Wurzelanläufen, Hauptäste in eine runde Krone,
    Seitenäste bis an den Rand der Krone, dort viele Laubzweige – dicht genug, dass man den
    Himmel nur in kleinen Lücken sieht."""
    base = Vector(base)
    trunk_top = base + Vector((0.05, height * 0.4, 0.03))
    b.tube(_curve(base, trunk_top, (0.04, 0, -0.03), 5), lambda t: 0.24 - 0.08 * t, BARK, segments=12)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), 0, math.sin(a)))
        b.tube([base + d * 0.1 + Vector((0, 0.45, 0)), base + d * 0.24 + Vector((0, 0.12, 0)), base + d * 0.42 + Vector((0, -0.02, 0))],
               lambda t: 0.09 - 0.07 * t, BARK, segments=6)
    crown = base + Vector((0.0, height * 0.66, 0.0))
    rx, ry = height * 0.34, height * 0.27
    sprays = []
    for k in range(7):
        a = 2 * math.pi * k / 7 + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        end = space.push(crown + Vector((d.x * rx * 0.55, ry * rnd.uniform(-0.1, 0.45), d.z * rx * 0.55)))
        pts = [space.push(p) for p in _curve(trunk_top - Vector((0, 0.2, 0)), end, Vector((0, 0.25, 0)) - d * 0.15, 5)]
        b.tube(pts, lambda t: 0.13 - 0.09 * t, BARK, segments=8)
        for j in range(6):
            start = pts[2].lerp(pts[-1], rnd.uniform(0.0, 1.0))
            out = (d * 0.8 + _rand_dir(rnd, -0.4, 0.9)).normalized()
            goal = space.push(crown + Vector((out.x * rx, out.y * ry, out.z * rx)) * rnd.uniform(0.75, 0.95))
            mid = space.push(start.lerp(goal, 0.55) + Vector((0, 0.1, 0)))
            b.tube([start, mid, goal], lambda t: 0.04 - 0.03 * t, BARK, segments=5)
            for i in range(5):
                s2 = start.lerp(goal, rnd.uniform(0.45, 1.0))
                d3 = (out + _rand_dir(rnd, -0.5, 0.9) * 0.8).normalized()
                tip = space.push(s2 + d3 * rnd.uniform(0.25, 0.5))
                b.tube([s2, tip], lambda t: 0.012 - 0.008 * t, STEM_BROWN, segments=3)
                for q in range(4):
                    sprays.append((s2.lerp(tip, rnd.uniform(0.25, 1.0)), d3))
    for p, d3 in sprays:
        along = (d3 + _rand_dir(rnd, -0.6, 0.7) * 0.8).normalized()
        size = rnd.uniform(0.42, 0.58)
        # Innen dunkler (im Schatten der Krone), außen heller
        rel = (p - crown)
        shell = math.sqrt((rel.x / rx) ** 2 + (rel.y / ry) ** 2 + (rel.z / rx) ** 2)
        card(b, p - along * 0.04, along, _rand_dir(rnd).cross(along), size, size,
             leaf_mat("leaf_spray", rnd, shade=0.85 + 0.2 * min(1.0, shell), tint=(1.0, 1.02, 0.95)), rows=2, fold=0.1, curl=0.35, space=space)


# ---------------------------------------------------------------------------------------------
# Sträuße (Blumenladen)
# ---------------------------------------------------------------------------------------------

def bouquet(b, base, height, radius, rnd, kind="tulip", palette="rose", space=NO_SPACE, glow=0.0, count=None, greens=True):
    """Strauß in einem Eimer/einer Vase: Stiele aus dem Wasser (base, Mitte), oben Blüten.
    kind: tulip, rose, daisy, hydrangea, lavender, greens."""
    base = Vector(base)
    colors = BLOSSOMS.get(palette, BLOSSOMS["rose"])
    n = _n(count or {"tulip": 18, "rose": 14, "daisy": 22, "hydrangea": 5, "lavender": 34, "greens": 12}.get(kind, 14))
    for k in range(n):
        a = 2 * math.pi * k * 0.618 + rnd.uniform(-0.2, 0.2)
        lean = 0.05 + 0.4 * math.sqrt((k + 0.5) / n) + rnd.uniform(-0.05, 0.05)
        d = Vector((math.cos(a) * lean, 1.0, math.sin(a) * lean)).normalized()
        top = space.push(base + Vector((math.cos(a), 0, math.sin(a))) * radius * 0.25 + d * height * rnd.uniform(0.85, 1.05))
        pts = _curve(base + Vector((math.cos(a), 0, math.sin(a))) * radius * 0.15, top, (d.x * 0.03, 0, d.z * 0.03), 4)
        if kind == "lavender":
            stem(b, pts, 0.0018, 0.0013, Mat("plain", color=(0.45, 0.5, 0.38)), segments=3, space=space)
            spike = 0.12
            for q in range(2):
                facing = Vector((math.cos(a + q * 1.57), 0, math.sin(a + q * 1.57)))
                card(b, top - d * spike * 0.48, d, facing, spike, spike * 0.5, Mat("lavender", color=(NEUTRAL,) * 3, glow=glow), rows=1, space=space)
            continue
        stem(b, pts, 0.0028, 0.0024, STEM_GREEN, segments=3, space=space)
        color = rnd.choice(colors)
        rim = getattr(space, "rim", base.y)
        above = [p for p in pts if p.y > rim + 0.03] or [pts[-1]]
        if kind == "tulip":
            leaf_p = above[0]
            card(b, leaf_p, (d + Vector((math.cos(a), 0, math.sin(a))) * 0.5).normalized(), Vector((math.cos(a), 0.2, math.sin(a))),
                 height * 0.45, 0.07, leaf_mat("narrow_leaf", rnd, tint=(0.95, 1.05, 1.0), glow=glow), rows=3, curl=0.6, fold=0.4, space=space)
            tulip(b, top, d, 0.06, color, rnd, space, glow)
        elif kind == "rose":
            for j in (1, 2):
                side = Vector((math.cos(a + 1.6 * j), 0, math.sin(a + 1.6 * j)))
                card(b, above[min(j, len(above) - 1)], (side + Vector((0, 0.4, 0))).normalized(), Vector((0, 1, 0)), 0.045, 0.04,
                     leaf_mat("broad_leaf", rnd, shade=0.85, glow=glow), rows=1, fold=0.25, space=space)
            rose(b, top, d, 0.05, color, rnd, space, glow)
        elif kind == "daisy":
            blossom(b, top, d + Vector((math.cos(a), 0, math.sin(a))) * 0.4, 0.06, bloom_mat("daisy", (0.97, 0.97, 0.95) if palette == "white" else color, glow),
                    cup=0.12, spin=rnd.uniform(0, 6.28), space=space)
        elif kind == "hydrangea":
            flower_ball(b, top + d * 0.05, 0.075, rnd, color, space, glow)
        else:
            for j in range(3):
                p = above[min(j, len(above) - 1)]
                side = Vector((math.cos(a + 2.1 * j), 0.3, math.sin(a + 2.1 * j))).normalized()
                card(b, p, side, Vector((0, 1, 0)), 0.18, 0.18, leaf_mat("leaf_spray", rnd, tint=(0.9, 1.0, 1.05), glow=glow), rows=2,
                     curl=0.3, space=space)
    # Grün dazu: Kranz über den Rand und ein paar aufrechte Zweige zwischen den Stielen
    if greens:
        greens_collar(b, base, radius, getattr(space, "rim", base.y + 0.03), rnd, space, glow,
                      layer=rnd.choice(["leaf_spray", "leaf_spray", "broad_leaf", "fern_frond"]) if kind != "lavender" else "narrow_leaf",
                      upright=3 if kind != "greens" else 0, height=height)


def tulip(b, top, d, size, color, rnd, space=NO_SPACE, glow=0.0):
    """Tulpe: sechs Blütenblätter, die sich zu einem Kelch schließen."""
    d = Vector(d).normalized()
    ref = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 0, 1))
    s = d.cross(ref).normalized()
    t = d.cross(s).normalized()
    for k in range(6):
        a = 2 * math.pi * k / 6 + (0.5 if k % 2 else 0.0)
        out = s * math.cos(a) + t * math.sin(a)
        r = 0.006 if k % 2 else 0.009
        along = (d + out * 0.12).normalized()
        card(b, top + out * r, along, out, size, size * 0.62, bloom_mat("petal", color, glow, rnd), rows=2, curl=0.35, fold=0.3, space=space)


def rose(b, top, d, size, color, rnd, space=NO_SPACE, glow=0.0):
    """Rose: drei Kränze aus Blütenblättern, innen geschlossen, außen offen; darunter Kelchblätter."""
    d = Vector(d).normalized()
    ref = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 0, 1))
    s = d.cross(ref).normalized()
    t = d.cross(s).normalized()
    b.sphere(top + d * size * 0.25, size * 0.22, Mat("foliage", color=tuple(c * 0.8 for c in color), glow=glow), rings=4, segments=6)
    for ring, (count, open_, scale, r) in enumerate(((3, 0.05, 0.5, 0.003), (5, 0.2, 0.65, 0.007), (6, 0.45, 0.8, 0.012),
                                                    (7, 0.8, 0.95, 0.017))):
        for k in range(count):
            a = 2 * math.pi * k / count + ring * 0.6 + rnd.uniform(-0.15, 0.15)
            out = s * math.cos(a) + t * math.sin(a)
            along = (d + out * open_).normalized()
            card(b, top + out * r, along, out, size * scale, size * scale * 0.9, bloom_mat("petal", color, glow, rnd), rows=2 if ring == 3 else 1,
                 curl=0.9 - 0.35 * ring, fold=0.35, space=space)
    for k in range(5):
        a = 2 * math.pi * k / 5
        out = s * math.cos(a) + t * math.sin(a)
        card(b, top + out * 0.004, (-d * 0.3 + out).normalized(), out + d * 0.5, size * 0.6, size * 0.25,
             leaf_mat("narrow_leaf", rnd, glow=glow), rows=1, space=space)


# ---------------------------------------------------------------------------------------------
# Gefäße mit Pflanzen
# ---------------------------------------------------------------------------------------------

def _register(b, kind, data):
    """Gefäß merken (in Modell-Koordinaten) – settle() schiebt am Ende alle Blätter heraus."""
    b.__dict__.setdefault("containers", []).append((kind, data))


def settle(b):
    """Schlussschritt für jedes Modell: Blätter und Blüten, die in die Wand eines Topfes, Eimers
    oder Kastens ragen (auch eines Nachbargefäßes), werden über den Rand oder nach außen
    geschoben; was im Gefäß unter der Erde liegt, auf die Erde. Gleiche Punkte werden gleich
    verschoben – Blätter bleiben ganz."""
    containers = b.__dict__.get("containers")
    if not containers:
        return
    cache = {}
    groups = {}
    roots = b.__dict__.setdefault("roots", {})
    for face in b.faces:
        if not face["mat"].plant:
            continue
        new = []
        for p in face["pts"]:
            key = (round(p.x, 6), round(p.y, 6), round(p.z, 6))
            if key not in cache:
                cache[key] = _settle_point(Vector(p), containers)
            new.append(cache[key])
        face["pts"] = new
        if "group" in face:
            groups.setdefault(face["group"], []).append(face)
    # Ganze Blätter: reicht eines unter dem Rand durch eine Gefäßwand (eine Ecke innen, eine
    # außen), legt es sich auf den Rand
    for gid, faces in groups.items():
        pts = {}
        for face in faces:
            for p in face["pts"]:
                pts[(round(p.x, 6), round(p.y, 6), round(p.z, 6))] = p
        # Jedes Blatt liegt etwas anders hoch auf dem Rand (sonst decken sich viele flach liegende
        # Blätter genau und flimmern)
        lift = _crossing_lift(list(pts.values()), containers, offset=0.0035 * (gid % 7))
        if not lift:
            # Blattkante als Sehne durch eine runde Gefäßwand (beide Ecken außen, z. B. am
            # Nachbartopf): das Blatt ein Stück anheben, bis die Kante über dem Rand liegt
            delta = _chord_lift(faces, containers, 0.008 + 0.0035 * (gid % 7))
            if delta <= 0.0:
                continue
            lift = (lambda p, d=delta: Vector((p.x, p.y + d, p.z)))
        for face in faces:
            face["pts"] = [lift(p) for p in face["pts"]]
        # Wird der Ansatz mit angehoben, verbindet ein kurzes Stielstück Blatt und Stängel
        # (sonst schwebt das Blatt)
        root = roots.get(gid)
        if root is not None:
            moved = lift(root)
            if (moved - root).length > 0.0015:
                # Punkte sind schon Modell-Koordinaten: ohne Verschiebung bauen
                saved, b.xf = b.xf, Matrix.Identity(4)
                b.tube([Vector(root), moved], 0.0011, STEM_GREEN, segments=3, caps=False)
                b.xf = saved
                roots[gid] = moved


def _cyl_outer(data, y):
    """Außenradius eines runden Gefäßes in der Höhe y: Töpfe sind unten schmaler als oben
    (von unten linear bis zum Rand; der Rand ist breiter als die Wand, so liegt die Linie
    immer etwas außerhalb)."""
    base, outer, height = data[0], data[2], data[3]
    bottom_r = data[5] if len(data) > 5 else outer
    t = min(1.0, max(0.0, (y - base.y) / max(height, 1e-6)))
    return bottom_r + (outer - bottom_r) * t


def _chord_lift(faces, containers, clear):
    """Wie weit ein Blatt angehoben werden muss, damit keine seiner Kanten unter dem Rand durch
    die Wand eines runden Gefäßes läuft (0 = nichts zu tun; mehr als 8 cm hebt es nicht)."""
    need = 0.0
    for kind, data in containers:
        if kind != "cyl":
            continue
        base, inner, outer, height, soil_h = data[:5]
        rim = base.y + height
        for face in faces:
            pts = face["pts"]
            for i in range(len(pts)):
                a, c = pts[i], pts[(i + 1) % len(pts)]
                if max(a.y, c.y) < base.y or min(a.y, c.y) > rim + 0.004:
                    continue
                # Nur Kanten, deren Ecken beide außerhalb der Wand liegen (sonst: Pflanze im Topf)
                if math.hypot(a.x - base.x, a.z - base.z) < _cyl_outer(data, a.y) + 0.002 or \
                        math.hypot(c.x - base.x, c.z - base.z) < _cyl_outer(data, c.y) + 0.002:
                    continue
                dx, dz = c.x - a.x, c.z - a.z
                ln2 = dx * dx + dz * dz
                if ln2 < 1e-12:
                    continue
                t = max(0.0, min(1.0, ((base.x - a.x) * dx + (base.z - a.z) * dz) / ln2))
                y = a.y + (c.y - a.y) * t
                if math.hypot(a.x + dx * t - base.x, a.z + dz * t - base.z) >= _cyl_outer(data, y) + 0.002:
                    continue
                if base.y < y < rim + 0.004:
                    need = max(need, rim + clear - y)
    return need if need < 0.08 else 0.0


def _crossing_lift(pts, containers, offset=0.0):
    """Falls ein Blatt über eine Gefäßwand hinweg reicht (innen unter dem Rand, auf oder außen
    neben der Wand): Funktion, die das Blatt über die Kante legt – nahe der Wand auf den Rand,
    außen so hoch, dass die gerade Fläche dazwischen über der Kante bleibt. Sonst None."""
    fixes = []
    for kind, data in containers:
        if kind == "bowl":
            c0, r0, squash0, soil0, top0 = data
            rim = top0
            bottom = c0.y - r0 * squash0

            def sd(p, c0=c0, r0=r0, squash0=squash0):
                if p.y >= c0.y:
                    return math.hypot(p.x - c0.x, p.z - c0.z) - r0
                return Vector((p.x - c0.x, (p.y - c0.y) / squash0, p.z - c0.z)).length - r0

            def sdi(p, sd=sd):
                return sd(p) + 0.02
        elif kind == "cyl":
            base, inner, outer, height, soil_h = data[:5]
            rim = base.y + height
            bottom = base.y

            def sd(p, base=base, data=data):
                return math.hypot(p.x - base.x, p.z - base.z) - _cyl_outer(data, p.y)

            def sdi(p, base=base, inner=inner):
                # Die Innenwand ist ein Vieleck (ab 10 Ecken): zwischen den Ecken liegt sie bis
                # 5 % näher an der Mitte
                return math.hypot(p.x - base.x, p.z - base.z) - inner * 0.945
        else:
            lo, hi, wall, soil_h, back, ilo, ihi = data
            rim = hi.y
            bottom = lo.y

            def sd(p, lo=lo, hi=hi):
                return max(lo.x - p.x, p.x - hi.x, lo.z - p.z, p.z - hi.z)
            if ilo is None:
                sdi = sd
            else:
                def sdi(p, ilo=ilo, ihi=ihi):
                    return max(ilo.x - p.x, p.x - ihi.x, ilo.z - p.z, p.z - ihi.z)
        # Nur, was auf Höhe des Gefäßes liegt (nicht darunter, z. B. im Regalfach darunter)
        low = max(rim - 0.3, bottom)
        inner_low = [p for p in pts if sdi(p) < 0.0 and low < p.y < rim + 0.004]
        on_or_out = [p for p in pts if sdi(p) >= 0.0 and low < p.y < rim + 0.1 and sd(p) < 0.6]
        inner_any = [p for p in pts if sd(p) < 0.0 and p.y > low]
        out_low = [p for p in pts if sd(p) >= 0.0 and low < p.y < rim + 0.004]
        if kind == "cyl" and inner_any and out_low and not inner_low and \
                all(p.y > rim for p in inner_any) and min(p.y for p in out_low) < rim - 0.04:
            # Blatt hängt außen an der Wand herab und kippt oben über die Öffnung: der obere Teil
            # rückt nach außen (das Blatt hängt dann ganz außen)
            fixes.append(("out", (base, data), rim))
        elif (inner_low and on_or_out) or (inner_any and out_low):
            fixes.append((sd, sdi, rim + offset))
    if not fixes:
        return None

    def lift(p, all_pts=pts):
        p = Vector(p)
        for sd, sdi, rim in fixes:
            if sd == "out":
                base, data = sdi
                d = Vector((p.x - base.x, 0.0, p.z - base.z))
                need = _cyl_outer(data, rim) + 0.012
                if d.length < need and p.y > rim - 0.01:
                    if d.length < 1e-6:
                        d = Vector((1.0, 0.0, 0.0))
                    d = d.normalized() * need
                    p = Vector((base.x + d.x, p.y, base.z + d.z))
                continue
            d = sd(p)
            di = sdi(p)
            top = rim + 0.008
            if di > -0.04 and d < 0.02 and rim - 0.08 < p.y < top:
                # Auf oder nahe an der Kante: auf den Rand
                p.y = top
            if di >= -0.005 and d < 0.02 and p.y < rim + 0.1:
                # Auf der Wand: so hoch, dass die Linie zu tiefer innen liegenden Punkten über die
                # Innenkante geht
                need = None
                for q in all_pts:
                    dq = sdi(q)
                    if dq >= -0.005 or q.y >= top:
                        continue
                    t = (-dq) / max(di - dq, 1e-6)
                    if t <= 0.05:
                        continue
                    req = q.y + (top - q.y) / t
                    need = req if need is None else max(need, req)
                if need is not None and p.y < need:
                    p.y = min(need, rim + 0.1)
            elif d >= 0.02 and p.y < rim + 0.004:
                # Außen: höchstens so tief, dass die Linie zum nächsten inneren Punkt über der
                # Kante bleibt
                need = None
                for q in all_pts:
                    dq = sd(q)
                    if dq >= 0.0:
                        continue
                    yq = max(q.y, rim + 0.008) if (sdi(q) > -0.04 and q.y > rim - 0.08) else q.y
                    if yq < rim + 0.008:
                        # Tief innen liegender Punkt: daraus folgt keine sinnvolle Höhe
                        continue
                    t = (-dq) / (d - dq)
                    # y(Kante) = yq + (y - yq) * t  >= rim + 0.008  →  y >= yq - (yq - rim - 0.008) / t
                    req = yq - (yq - rim - 0.008) / max(t, 0.05)
                    need = req if need is None else max(need, req)
                if need is not None and p.y < need:
                    p.y = min(need, rim + 0.008)
        return p
    return lift


def _settle_point(p, containers):
    for kind, data in containers:
        if kind == "bowl":
            # Halbkugel unter dem Rand (Hängekorb): innen über der Erde frei, sonst nach außen
            c, r, squash, soil, top = data
            if p.y >= top + 0.006:
                continue
            d = Vector((p.x - c.x, (p.y - c.y) / squash, p.z - c.z))
            if d.length >= r + 0.008:
                continue
            if math.hypot(d.x, d.z) < r - 0.02 and p.y >= soil:
                continue
            if top + 0.006 - p.y < r + 0.025 - d.length:
                # Knapp unter der Oberkante des Rands: auf den Rand heben (nicht weit nach außen)
                p = Vector((p.x, top + 0.006, p.z))
                continue
            if d.length < 1e-6:
                d = Vector((0, -1, 0))
            d = d.normalized() * (r + 0.025)
            p = Vector((c.x + d.x, c.y + d.y * squash, c.z + d.z))
            continue
        if kind == "cyl":
            base, inner, outer, height, soil_h = data[:5]
            rim = base.y + height
            if not (base.y - 0.001 <= p.y < rim + 0.005):
                continue
            d = Vector((p.x - base.x, 0.0, p.z - base.z))
            dist = d.length
            # Unten ist der Topf schmaler: neben der schrägen Wand ist Platz
            wall_r = _cyl_outer(data, p.y)
            if dist < inner - 0.006 and p.y > base.y + soil_h - 0.03:
                if p.y < base.y + soil_h + 0.002:
                    p.y = base.y + soil_h + 0.002
            elif dist < wall_r + 0.006:
                if rim + 0.006 - p.y < wall_r + 0.006 - dist or dist < 1e-6:
                    p.y = rim + 0.006
                else:
                    d.normalize()
                    p.x = base.x + d.x * (wall_r + 0.006)
                    p.z = base.z + d.z * (wall_r + 0.006)
        else:
            lo, hi, wall, soil_h, back, ilo, ihi = data
            if not (lo.y - 0.001 <= p.y < hi.y + 0.005 and lo.x - 0.006 < p.x < hi.x + 0.006 and lo.z - 0.006 < p.z < hi.z + 0.006):
                continue
            inside = ilo is not None and ilo.x + 0.004 < p.x < ihi.x - 0.004 and ilo.z + 0.004 < p.z < ihi.z - 0.004
            if inside:
                if p.y < lo.y + soil_h + 0.002:
                    p.y = lo.y + soil_h + 0.002
            else:
                options = [(hi.y + 0.006 - p.y, "up"), (p.x - lo.x + 0.006, "-x"), (hi.x + 0.006 - p.x, "+x"),
                           (p.z - lo.z + 0.006, "-z"), (hi.z + 0.006 - p.z, "+z")]
                if back is not None:
                    blocked = {"-x": back.x < -0.7, "+x": back.x > 0.7, "-z": back.z < -0.7, "+z": back.z > 0.7}
                    options = [o for o in options if not blocked.get(o[1], False)]
                if ilo is not None and p.y >= lo.y + soil_h:
                    # Über der Erde in der Wand: lieber nach innen (bleibt im Kasten)
                    if p.x < ilo.x + 0.004:
                        options.append((ilo.x + 0.006 - p.x, "in+x"))
                    if p.x > ihi.x - 0.004:
                        options.append((p.x - ihi.x + 0.006, "in-x"))
                    if p.z < ilo.z + 0.004:
                        options.append((ilo.z + 0.006 - p.z, "in+z"))
                    if p.z > ihi.z - 0.004:
                        options.append((p.z - ihi.z + 0.006, "in-z"))
                _, way = min(options)
                if way == "in+x":
                    p.x = ilo.x + 0.006
                elif way == "in-x":
                    p.x = ihi.x - 0.006
                elif way == "in+z":
                    p.z = ilo.z + 0.006
                elif way == "in-z":
                    p.z = ihi.z - 0.006
                elif way == "up":
                    p.y = hi.y + 0.006
                elif way == "-x":
                    p.x = lo.x - 0.006
                elif way == "+x":
                    p.x = hi.x + 0.006
                elif way == "-z":
                    p.z = lo.z - 0.006
                else:
                    p.z = hi.z + 0.006
    return p


# --- Flimmern vermeiden: Blätter, die fast deckungsgleich übereinanderliegen, auseinanderschieben ---

_ALPHA = {}


def alpha_table():
    """Deckung (Alpha) der Pflanzen-Texturen: Liste je Ebene, Feld [Zeile von oben][Spalte]."""
    if "cells" not in _ALPHA:
        import bpy
        import numpy as np
        img = bpy.data.images.load(os.path.join(S.PLANT_DIR, "plant_albedo.png"), check_existing=True)
        w, h = img.size
        px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, 3]
        size = S._PLANT_TABLE["layer_size"]
        cells = []
        for index in range(len(S.PLANT_LAYERS)):
            cx, cy = index % S.PLANT_GRID_X, index // S.PLANT_GRID_X
            cells.append(px[cy * size:(cy + 1) * size, cx * size:(cx + 1) * size].copy())
        _ALPHA["cells"] = cells
        _ALPHA["size"] = size
    return _ALPHA["cells"], _ALPHA["size"]


BARK_INDEX = S.PLANT_LAYERS["bark"]["index"]


def plant_alpha(layer, uv):
    """Deckung eines Pflanzen-Bilds an der Stelle uv (0..1, v von unten); Rinde ist deckend."""
    if layer == BARK_INDEX or layer < 0 or uv is None:
        return 1.0
    cells, size = alpha_table()
    u = min(max(uv[0], 0.0), 0.999)
    v = min(max(uv[1], 0.0), 0.999)
    return float(cells[layer][int((1.0 - v) * size) % size, int(u * size)])


def _bary(p, a, b, c):
    v0, v1, v2 = b - a, c - a, p - a
    d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
    d20, d21 = v2.dot(v0), v2.dot(v1)
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-14:
        return None
    v = (d11 * d20 - d01 * d21) / den
    w = (d00 * d21 - d01 * d20) / den
    return (1.0 - v - w, v, w)


SEPARATE_GAP = 0.002     # näher als das gilt als "deckungsgleich" (flimmert)
SEPARATE_STEP = 0.004    # so weit wird ein Blatt dann verschoben
MAX_MOVES = 5            # höchstens so oft je Blatt (sonst löst es sich vom Stiel)


def separate(b):
    """Schlussschritt: Wo zwei Blätter/Blüten (verschiedene Gruppen) an einer gedeckten Stelle
    fast in derselben Ebene liegen, wird die später gebaute Gruppe entlang ihrer Normale weg
    vom anderen Blatt geschoben. Bis zu drei Durchgänge."""
    from mathutils.bvhtree import BVHTree
    moved_total = {}
    # Nach dem ersten Durchgang nur noch die eben verschobenen Blätter prüfen (schneller)
    check = None
    for _ in range(20):
        tris = []
        for face in b.faces:
            mat = face["mat"]
            if not mat.plant or "group" not in face or S.PLANT_LAYERS[mat.layer]["index"] == BARK_INDEX:
                continue
            pts, uvs = face["pts"], face.get("uvs")
            for i in range(1, len(pts) - 1):
                tris.append((pts[0], pts[i], pts[i + 1], (uvs[0], uvs[i], uvs[i + 1]) if uvs else None,
                             S.PLANT_LAYERS[mat.layer]["index"], face["group"]))
        if len(tris) < 2:
            return
        tree = BVHTree.FromPolygons([p for t in tris for p in t[:3]], [(3 * k, 3 * k + 1, 3 * k + 2) for k in range(len(tris))],
                                    all_triangles=True)
        normals = []
        for t in tris:
            n = (t[1] - t[0]).cross(t[2] - t[0])
            normals.append(n.normalized() if n.length > 1e-12 else None)
        moves = {}
        for a, t in enumerate(tris):
            na = normals[a]
            if na is None or t[5] in moves or (check is not None and t[5] not in check):
                continue
            for w in ((1 / 3, 1 / 3, 1 / 3), (0.6, 0.2, 0.2), (0.2, 0.6, 0.2), (0.2, 0.2, 0.6)):
                p = t[0] * w[0] + t[1] * w[1] + t[2] * w[2]
                uv = (t[3][0][0] * w[0] + t[3][1][0] * w[1] + t[3][2][0] * w[2], t[3][0][1] * w[0] + t[3][1][1] * w[1] + t[3][2][1] * w[2]) \
                    if t[3] else None
                if plant_alpha(t[4], uv) < 0.5:
                    continue
                hit = None
                for _, _, c, dist in tree.find_nearest_range(p, SEPARATE_GAP):
                    o = tris[c]
                    if o[5] == t[5] or normals[c] is None or abs(na.dot(normals[c])) < 0.97:
                        continue
                    q = p - normals[c] * (p - o[0]).dot(normals[c])
                    bc = _bary(q, o[0], o[1], o[2])
                    if bc is None or min(bc) < 0.0:
                        continue
                    ouv = (o[3][0][0] * bc[0] + o[3][1][0] * bc[1] + o[3][2][0] * bc[2],
                           o[3][0][1] * bc[0] + o[3][1][1] * bc[1] + o[3][2][1] * bc[2]) if o[3] else None
                    if plant_alpha(o[4], ouv) < 0.5:
                        continue
                    hit = (c, (p - o[0]).dot(normals[c]), p, q)
                    break
                if hit:
                    c, side, p_t, p_o = hit
                    o = tris[c]
                    # Die später gebaute Gruppe weicht aus – weg von der Ebene des anderen Blatts
                    away = normals[c] * (1.0 if side >= 0 else -1.0)
                    mover, direction = (t[5], away) if t[5] > o[5] else (o[5], -away)
                    # Jede Gruppe höchstens zweimal verschieben (sonst löst sie sich vom Stiel) –
                    # dann weicht die andere aus
                    if moved_total.get(mover, 0) >= MAX_MOVES:
                        mover, direction = (o[5], -away) if mover == t[5] else (t[5], away)
                        if moved_total.get(mover, 0) >= MAX_MOVES:
                            break
                    if abs(direction.y) > 0.5 and direction.y < 0:
                        # Flach liegende Blätter (z. B. auf einem Rand) weichen nach oben aus – nach
                        # unten würde der nächste Schritt sie wieder auf den Rand legen
                        mover, direction = (o[5], away) if mover == t[5] else (t[5], -away)
                        if direction.y < 0:
                            direction = -direction
                    if mover not in moves:
                        moves[mover] = (direction, p_t if mover == t[5] else p_o)
                        moved_total[mover] = moved_total.get(mover, 0) + 1
                    break
        if not moves:
            return
        check = set(moves)
        roots = b.__dict__.get("roots", {})
        group_faces = {}
        for face in b.faces:
            gid = face.get("group")
            if gid in moves:
                group_faces.setdefault(gid, []).append(face)
        xforms = {}
        for gid, (direction, at) in moves.items():
            root = roots.get(gid)
            r = (at - root) if root is not None else None
            if r is not None and r.length <= 0.012:
                # Getroffen nahe am Ansatz: um den Ansatz kippen, Hebel bis zur Blattmitte (ein
                # verschobenes Blatt würde sich vom Stiel lösen)
                pts = [p for face in group_faces.get(gid, []) for p in face["pts"]]
                if pts:
                    mid = sum(pts, Vector()) / len(pts)
                    if (mid - root).length > 0.012:
                        r = mid - root
            if r is not None and r.length > 0.012:
                # Um den Ansatz am Stiel kippen: die Stelle at wandert um SEPARATE_STEP in Richtung
                # direction, der Ansatz bleibt, wo er ist
                axis = r.cross(direction)
                if axis.length > 1e-6:
                    angle = min(0.3, SEPARATE_STEP / r.length)
                    options = []
                    for a in (angle, -angle):
                        rot = Matrix.Rotation(a, 4, axis.normalized())
                        options.append((Matrix.Translation(root) @ rot @ Matrix.Translation(-root), rot.to_3x3()))
                    xforms[gid] = options
                    continue
            xforms[gid] = [(Matrix.Translation(direction * SEPARATE_STEP), None), (Matrix.Translation(-direction * SEPARATE_STEP), None)]
        spaces = b.__dict__.get("spaces", {})
        extras = b.__dict__.setdefault("extras", {})
        for gid, faces in group_faces.items():
            # Erst in die gewünschte Richtung, sonst in die Gegenrichtung – aber nie in eine Wand,
            # Sperre oder Gefäßwand hinein (das Space der Pflanze würde das Blatt wieder platt
            # an die Grenze drücken); geht beides nicht, bleibt das Blatt, wo es ist
            space, xf = spaces.get(gid, (None, None))
            inv = xf.inverted() if xf is not None else None
            _EXTRA[0] = extras.get(gid, _leaf_extra(gid))
            for m, rot3 in xforms[gid]:
                moved = [[m @ p for p in face["pts"]] for face in faces]
                if space is not None and any((xf @ space.push(inv @ p) - p).length > 1e-6 for pts in moved for p in pts):
                    continue
                for face, pts in zip(faces, moved):
                    face["pts"] = pts
                    if rot3 is not None:
                        face["normals"] = [(rot3 @ n).normalized() for n in face["normals"]]
                break
            else:
                if space is not None:
                    # Beide Richtungen stoßen an eine Grenze (Blatt liegt platt an einer Wand oder
                    # Ebene): dann hält das Blatt 2–5 mm mehr Abstand zu ihr
                    _EXTRA[0] += 0.002 + 0.0015 * (len(extras) % 3)
                    extras[gid] = _EXTRA[0]
                    for face in faces:
                        face["pts"] = [xf @ space.push(inv @ p) for p in face["pts"]]
            _EXTRA[0] = 0.0


def finish_plants(b):
    """Schlussschritte für Pflanzen: aus Gefäßen schieben, Flimmern beheben, nochmal Gefäße."""
    settle(b)
    if any("group" in f for f in b.faces):
        separate(b)
        settle(b)
        # Was der letzte Schritt wieder aufeinandergelegt hat, noch einmal trennen – und danach
        # nichts zurück in eine Gefäßwand kippen lassen
        separate(b)
        settle(b)


S.FINISHERS.append(finish_plants)


def _ring(b, x, y, z, r_in, r_out, mat, up=True, segments=14):
    """Waagerechter Ring (Topfrand oben oder unten)."""
    for k in range(segments):
        a0 = 2 * math.pi * k / segments
        a1 = 2 * math.pi * (k + 1) / segments
        pts = [V(x + math.cos(a0) * r_in, y, z + math.sin(a0) * r_in), V(x + math.cos(a0) * r_out, y, z + math.sin(a0) * r_out),
               V(x + math.cos(a1) * r_out, y, z + math.sin(a1) * r_out), V(x + math.cos(a1) * r_in, y, z + math.sin(a1) * r_in)]
        b.face(pts, mat, (0, 1 if up else -1, 0))


def _inner_wall(b, x, z, radius, y0, y1, mat, segments=14):
    """Innenwand eines Gefäßes (zeigt nach innen)."""
    for k in range(segments):
        a0 = 2 * math.pi * k / segments
        a1 = 2 * math.pi * (k + 1) / segments
        am = (a0 + a1) / 2
        pts = [V(x + math.cos(a0) * radius, y0, z + math.sin(a0) * radius), V(x + math.cos(a1) * radius, y0, z + math.sin(a1) * radius),
               V(x + math.cos(a1) * radius, y1, z + math.sin(a1) * radius), V(x + math.cos(a0) * radius, y1, z + math.sin(a0) * radius)]
        b.face(pts, mat, (-math.cos(am), 0, -math.sin(am)))


def vessel(b, x, z, r_bottom, height, r_top, mat, y=0.0, lip=0.014, lip_h=0.04, soil_drop=0.025, wall=0.01,
           soil_mat=None, segments=14):
    """Offenes rundes Gefäß (Topf, Eimer, Kübel): Wand, Rand-Wulst, Innenwand, Erde etwas unter
    dem Rand. Gibt rim (Höhe Rand), inner (Radius innen), soil (Höhe Erde), outer (Radius außen)
    zurück – passend für PotSpace."""
    rim = y + height
    start_face = len(b.faces)
    b.cylinder(V(x, y, z), r_bottom, height, mat, segments=segments, radius_top=r_top, caps=(True, False))
    outer = r_top + lip
    _register(b, "cyl", (b.xf @ Vector((x, y, z)), r_top - wall, max(r_bottom, outer), height, rim - soil_drop - y, r_bottom + 0.003))
    if lip > 0:
        b.cylinder(V(x, rim - lip_h, z), outer, lip_h, mat, segments=segments, caps=(False, False))
        _ring(b, x, rim - lip_h, z, r_top - 0.001, outer, mat, up=False, segments=segments)
    inner = r_top - wall
    _ring(b, x, rim, z, inner, outer, mat, up=True, segments=segments)
    soil = rim - soil_drop
    _inner_wall(b, x, z, inner, soil, rim, mat, segments=segments)
    _ring(b, x, soil, z, 0.0, inner, soil_mat or SOIL, up=True, segments=segments)
    # Für geo_check.py: Gefäß darf in nichts Festem stecken (Regal, Wand, Nachbartopf)
    b.__dict__.setdefault("vessels", []).append(("cyl", b.xf.copy(), (x, y, z, r_bottom, r_top + lip, height), start_face, len(b.faces)))
    return {"rim": rim, "inner": inner, "soil": soil, "outer": outer}


def extend_last_vessel(b):
    """Was seit dem letzten Gefäß gebaut wurde (Griffe, Ringe, Halter), gehört zu ihm – für
    geo_check.py (Gefäß steckt nicht in seinen eigenen Griffen)."""
    vessels = b.__dict__.get("vessels")
    if vessels:
        kind, xf, data, f0, _ = vessels[-1]
        vessels[-1] = (kind, xf, data, f0, len(b.faces))


def trough(b, x0, x1, y, z0, z1, height, mat, soil_drop=0.02, wall=0.018, skip_back=False, lip=0.0):
    """Offener Kasten (Blumenkasten, Kiste, Pflanztrog): Außenwände, Rand oben, Innenwände,
    Erde. Gibt die Höhe der Erde zurück. lip = Leiste vorn/seitlich (Dicke), zählt beim
    Ausweichen der Blätter mit."""
    top = y + height
    soil = top - soil_drop
    start_face = len(b.faces)
    b.box((x0, y, z0), (x1, top, z1), mat, skip=("top",) + (("back",) if skip_back else ()))
    corners = [b.xf @ Vector(c) for c in ((x0 - lip, y, z0), (x1 + lip, y, z0), (x0 - lip, y, z1 + lip), (x1 + lip, y, z1 + lip))]
    # Steht der Kasten an einer Wand (skip_back), darf nichts nach hinten geschoben werden
    back = (b.xf.to_3x3() @ Vector((0, 0, -1))).normalized() if skip_back else None
    inner = [b.xf @ Vector(c) for c in ((x0 + wall, y, z0 + wall), (x1 - wall, y, z1 - wall))]
    _register(b, "box", (Vector((min(c.x for c in corners), corners[0].y, min(c.z for c in corners))),
                         Vector((max(c.x for c in corners), corners[0].y + height, max(c.z for c in corners))), wall, height - soil_drop, back,
                         Vector((min(c.x for c in inner), 0, min(c.z for c in inner))), Vector((max(c.x for c in inner), 0, max(c.z for c in inner)))))
    ix0, ix1, iz0, iz1 = x0 + wall, x1 - wall, z0 + wall, z1 - wall
    for lo, hi in (((x0, top, z0), (x1, top, iz0)), ((x0, top, iz1), (x1, top, z1)),
                   ((x0, top, iz0), (ix0, top, iz1)), ((ix1, top, iz0), (x1, top, iz1))):
        b.face([V(lo[0], top, lo[2]), V(hi[0], top, lo[2]), V(hi[0], top, hi[2]), V(lo[0], top, hi[2])], mat, (0, 1, 0))
    b.face([V(ix0, soil, iz0), V(ix1, soil, iz0), V(ix1, top, iz0), V(ix0, top, iz0)], mat, (0, 0, 1))
    b.face([V(ix0, soil, iz1), V(ix1, soil, iz1), V(ix1, top, iz1), V(ix0, top, iz1)], mat, (0, 0, -1))
    b.face([V(ix0, soil, iz0), V(ix0, soil, iz1), V(ix0, top, iz1), V(ix0, top, iz0)], mat, (1, 0, 0))
    b.face([V(ix1, soil, iz0), V(ix1, soil, iz1), V(ix1, top, iz1), V(ix1, top, iz0)], mat, (-1, 0, 0))
    b.face([V(ix0, soil, iz0), V(ix1, soil, iz0), V(ix1, soil, iz1), V(ix0, soil, iz1)], SOIL, (0, 1, 0))
    b.__dict__.setdefault("vessels", []).append(("box", b.xf.copy(), (x0, y, z0, x1, top, z1, skip_back), start_face, len(b.faces)))
    return soil


def ledge_planter(b, x0, x1, y, z0, z1, rnd, palettes, mat, front_z, trail=0.4, glow=0.0, long_trails=(), height=0.15,
                  wall_z=0.0, blocks=()):
    """Pflanztrog oben auf einem Gesims (Höhe y, Trog von z0 bis z1, Vorderkante des Gesimses
    front_z): Balkonblumen, vorn hängen Ranken herab; long_trails = [(x, Länge)] lange
    Efeuranken (z. B. an den Pilastern hinunter). Unter dem Gesims bleibt alles davor.
    wall_z = Vorderseite dessen, was hinter dem Trog an der Wand ist (z. B. Ecksteine); blocks =
    feste Teile (lo, hi), an denen die Ranken vorbeiwachsen (z. B. Arme von Hängekörben)."""
    soil = trough(b, x0, x1, y, z0, z1, height, mat)
    space = BoxSpace(x0, x1, z0, z1, y + height, soil, wall=0.018)
    space.wall(wall_z, y0=y - 0.01)
    for lo, hi in blocks:
        space.block(lo, hi)
    space.wall(front_z, y1=y - 0.002)
    with detail(0.6):
        bedding_row(b, x0 + 0.05, x1 - 0.05, soil, z0 + 0.03, z1 - 0.03, rnd, palettes, space, glow=glow, trail_front=trail,
                    front_dir=Vector((0, 0, 1)), spacing=0.2)
    for x, length in long_trails:
        trailing_ivy(b, Vector((x, soil, z1 - 0.05)), length, rnd, Vector((0, 0, 1)), space, leaf_size=0.055, glow=glow,
                     over=front_z - z1 + 0.1, lift=height - (soil - y) + 0.02)


def pot_plant(b, x, z, kind, rnd, r_bottom=0.13, height=0.35, r_top=0.16, y=0.0, palette=None, glow=0.0, wall_z=None,
              mat=None, collider=True, blocks=(), trailers=True, planes=()):
    """Terrakotta-Topf mit Pflanze (kind wie potted) an (x, y, z); mit Kollision. blocks =
    feste Kästen in der Nähe (lo, hi), in die nichts hineinwachsen darf; planes = Grenzen
    (Punkt, Richtung ins Freie, Abstand), z. B. eine Scheibe davor oder ein Brett darüber."""
    v = vessel(b, x, z, r_bottom, height, r_top, mat or Mat("terracotta", glow=glow), y=y)
    potted(b, x, z, v["rim"], v["inner"], v["soil"], kind, rnd, palette, glow, outer_r=v["outer"], wall_z=wall_z, ground=y,
           blocks=blocks, trailers=trailers, planes=planes)
    if collider:
        # Kollision bis über die Pflanze (hohe Formgehölze und Bäumchen ragen weit über den Topf)
        top = height + (0.6 if kind in ("box_ball", "cone", "standard", "olive", "hydrangea", "lavender") else 0.25)
        b.colliders.append(((x - v["outer"], y, z - v["outer"]), (x + v["outer"], y + top, z + v["outer"])))
    return v


def indoor_plant(b, x, y, z, rnd, glow=0.0, kind=None, size=1.0, room=None):
    """Zimmerpflanze im Topf (Wohnzimmer, Läden): Feige mit großen Blättern oder Farn.
    room = (lo, hi): Kasten, in dem alle Blätter bleiben (Zimmer hinter dem Fenster)."""
    kind = kind or rnd.choice(["fig", "fern", "fern", "fig"])
    v = vessel(b, x, z, 0.12 * size, 0.3 * size, 0.15 * size, Mat("terracotta", glow=glow * 0.5), y=y)
    space = PotSpace(x, z, v["inner"], v["rim"], v["soil"], outer=v["outer"], ground=y)
    if room:
        space.inside(*room)
    soil = V(x, v["soil"], z)
    if kind == "fern":
        fern(b, soil, 0.55 * size, rnd, space, glow)
    else:
        for k in range(3):
            d = _rand_dir(rnd, 0.0, 0.0)
            top = space.push(soil + Vector((d.x * 0.08, rnd.uniform(0.7, 1.1) * size, d.z * 0.08)))
            pts = [space.push(p) for p in _curve(soil, top, (d.x * 0.05, 0, d.z * 0.05), 5)]
            b.tube(pts, lambda t: 0.012 - 0.006 * t, BARK, segments=5)
            for i in range(2, len(pts)):
                a = rnd.uniform(0, 6.28)
                out = Vector((math.cos(a), rnd.uniform(-0.1, 0.4), math.sin(a))).normalized()
                size_l = rnd.uniform(0.2, 0.28) * size
                card(b, pts[i], out, Vector((0, 1, 0)) + out * 0.3, size_l, size_l * 0.75, leaf_mat("broad_leaf", rnd, shade=0.8, glow=glow),
                     rows=2, fold=0.3, curl=0.4, space=space)


def wreath(b, center, radius, rnd, glow=0.0, flowers="rose"):
    """Kranz an der Wand (Mitte center, Ebene z = center.z, Vorderseite +z): Buchs-Zweige im
    Kreis, dazwischen kleine Blüten."""
    c = Vector(center)
    b.tube([c + Vector((math.cos(a) * radius, math.sin(a) * radius, 0.013)) for a in [2 * math.pi * k / 20 for k in range(21)]],
           0.012, STEM_BROWN, segments=4, caps=False)
    # Nagel und Schlaufe oben
    b.cylinder(c + Vector((0, radius + 0.03, 0)), 0.004, 0.02, soft_mat((0.3, 0.3, 0.31), layer="metal"), segments=6, axis="z", caps=(False, True))
    b.tube([c + Vector((0, radius + 0.03, 0.012)), c + Vector((0, radius + 0.005, 0.013))], 0.002, soft_mat((0.6, 0.5, 0.36)), segments=3)
    for k in range(28):
        a = 2 * math.pi * k / 28
        p = c + Vector((math.cos(a) * radius, math.sin(a) * radius, 0.02))
        tangent = Vector((-math.sin(a), math.cos(a), 0.0))
        card(b, p, (tangent + Vector((math.cos(a), math.sin(a), 0)) * rnd.uniform(-0.4, 0.4)).normalized(), Vector((0, 0, 1)), 0.12, 0.1,
             leaf_mat("box_sprig", rnd, glow=glow), rows=1, space=Space().wall(c.z + 0.005))
    for k in range(7):
        a = 2 * math.pi * k / 7 + 0.3
        blossom(b, c + Vector((math.cos(a) * radius, math.sin(a) * radius, 0.027)), Vector((0, 0, 1)), 0.05,
                bloom_mat("floret5", rnd.choice(BLOSSOMS[flowers]), glow), cup=0.2, spin=rnd.uniform(0, 6.28))


def dried_bunch(b, top, length, rnd, glow=0.0):
    """Getrockneter Strauß kopfüber an einer Schnur (Lavendel, Strohblumen)."""
    top = Vector(top)
    b.tube([top, top - Vector((0, 0.05, 0))], 0.004, Mat("plain", color=(0.6, 0.52, 0.38)), segments=3)
    knot = top - Vector((0, 0.06, 0))
    b.cylinder(knot - Vector((0, 0.03, 0)), 0.018, 0.035, Mat("plain", color=(0.62, 0.5, 0.36), glow=glow), segments=8)
    spike_mat = Mat("lavender", color=(0.72, 0.68, 0.7), glow=glow)
    for k in range(14):
        d = Vector((rnd.uniform(-0.25, 0.25), -1.0, rnd.uniform(-0.25, 0.25))).normalized()
        end = knot + d * length * rnd.uniform(0.75, 1.0)
        b.tube([knot, end], 0.0018, Mat("plain", color=(0.48, 0.48, 0.36), glow=glow), segments=3)
        spin = rnd.uniform(0, 3.14)
        for q in range(2):
            facing = Vector((math.cos(spin + q * 1.57), 0, math.sin(spin + q * 1.57)))
            card(b, end - d * 0.065, d, facing, 0.12, 0.06, spike_mat, rows=1)


def garden_bed(b, x0, x1, z0, z1, y, rnd, palettes=("lavender", "rose", "white"), space=None, glow=0.0):
    """Beet (Vorgarten): Lavendel, Buchskugeln, Hortensien, Rosen, Funkien, Margeriten,
    Gras – locker gemischt, nichts steht ineinander."""
    space = space or Space().floor(y)
    x = x0 + 0.3
    k = 0
    while x < x1 - 0.2:
        z = z0 + (z1 - z0) * rnd.uniform(0.3, 0.7)
        kind = rnd.choice(["lavender", "box", "hydrangea", "rose", "hosta", "daisy", "lavender", "grass"])
        p = Vector((x, y, z))
        if kind == "lavender":
            lavender(b, p, 0.17, rnd, space, glow)
        elif kind == "box":
            r = rnd.uniform(0.16, 0.22)
            b.tube([p, p + Vector((0, r * 0.3, 0))], 0.01, BARK, segments=4)
            box_ball(b, p + Vector((0, r * 0.92, 0)), r, rnd, space, glow)
        elif kind == "hydrangea":
            hydrangea(b, p, 0.26, rnd, rnd.choice(["hydrangea", "white", "rose"]), space, glow, heads=4)
        elif kind == "rose":
            rose_bush(b, p, 0.32, rnd, rnd.choice(["rose", "white", "red", "coral"]), space, glow)
        elif kind == "hosta":
            hosta(b, p, 0.4, rnd, space, glow)
        elif kind == "daisy":
            daisy_plant(b, p, rnd, 1.1, space, glow)
        else:
            grass(b, p, 0.32, rnd, space, glow)
        x += rnd.uniform(0.4, 0.6)
        k += 1


def rose_bush(b, base, height, rnd, palette="rose", space=NO_SPACE, glow=0.0):
    """Rosenstrauch: Triebe mit gefiederten Blättern, an den Spitzen Rosenblüten und Knospen."""
    base = Vector(base)
    colors = BLOSSOMS[palette]
    for k in range(rnd.randint(6, 8)):
        a = 2 * math.pi * k / 7 + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        top = space.push(base + d * height * rnd.uniform(0.25, 0.45) + Vector((0, height * rnd.uniform(0.75, 1.0), 0)))
        pts = _curve(base + d * 0.02, top, (0, 0.03, 0), 5)
        stem(b, pts, 0.006, 0.003, STEM_GREEN, segments=4, space=space)
        for i in range(1, len(pts) - 1):
            side = d.cross(Vector((0, 1, 0))).normalized() * (1 if i % 2 else -1)
            card(b, pts[i], (side + d * 0.4 + Vector((0, 0.25, 0))).normalized(), Vector((0, 1, 0)), 0.11, 0.11,
                 leaf_mat("leaf_spray", rnd, shade=0.85, glow=glow), rows=1, curl=0.3, space=space)
        tangent = (pts[-1] - pts[-2]).normalized()
        rose(b, pts[-1], tangent, 0.045, rnd.choice(colors), rnd, space, glow)



class PotSpace(Space):
    """Runder Topf: innerhalb des Rands bleibt alles über der Erde; außerhalb bleibt alles über
    dem Rand oder außerhalb der Topfwand."""

    def __init__(self, x, z, radius, rim_y, soil_y, outer=None, ground=0.0):
        super().__init__()
        self.x, self.z, self.r, self.rim, self.soil = x, z, radius, rim_y, soil_y
        self.outer = outer if outer is not None else radius + 0.02
        self.ground = ground

    def push(self, p):
        p = Space.push(self, p)
        e = _EXTRA[0]
        if p.y < self.ground + 0.003 + e:
            p.y = self.ground + 0.003 + e
        d = Vector((p.x - self.x, 0.0, p.z - self.z))
        dist = d.length
        rim, outer = self.rim + 0.006 + e, self.outer + 0.006 + e
        if dist < self.r - 0.008:
            if p.y < self.soil + 0.003 + e:
                p.y = self.soil + 0.003 + e
        elif dist < outer and p.y < rim:
            # In der Topfwand: über den Rand heben, wenn nah dran, sonst nach außen
            if rim - p.y < outer - dist or dist < self.r:
                p.y = rim
            else:
                d.normalize()
                p.x = self.x + d.x * outer
                p.z = self.z + d.z * outer
        return p


class BoxSpace(Space):
    """Kasten (Blumenkasten, Kübel eckig): innen über der Erde, außen vor/über der Wand."""

    def __init__(self, x0, x1, z0, z1, rim_y, soil_y, wall=0.02):
        super().__init__()
        self.x0, self.x1, self.z0, self.z1, self.rim, self.soil, self.w = x0, x1, z0, z1, rim_y, soil_y, wall

    def push(self, p):
        p = Space.push(self, p)
        e = _EXTRA[0]
        inside = self.x0 + self.w < p.x < self.x1 - self.w and self.z0 + self.w < p.z < self.z1 - self.w
        if inside:
            if p.y < self.soil + 0.003 + e:
                p.y = self.soil + 0.003 + e
        elif self.x0 - 0.006 < p.x < self.x1 + 0.006 and self.z0 - 0.006 < p.z < self.z1 + 0.007 + e and p.y < self.rim + 0.006 + e:
            # In der Kastenwand: nach vorn hinaus, wenn vorn; sonst über den Rand
            if p.z > self.z1 - self.w - 0.002 and self.rim - p.y > 0.015:
                p.z = self.z1 + 0.007 + e
            else:
                p.y = self.rim + 0.006 + e
        return p


class BasketSpace(Space):
    """Hängekorb (untere Halbkugel um rim, Radius radius): innen über der Erde, außen außerhalb
    der Kugel."""

    def __init__(self, rim, radius, soil_y):
        super().__init__()
        self.c = Vector(rim)
        self.r = radius + 0.02
        self.soil = soil_y

    def push(self, p):
        p = Space.push(self, p)
        # Der Ring am Rand ist bis 13 mm dick: darüber ist alles frei (passend zu settle: Rand +
        # höchstens 13 mm + 6 mm)
        e = _EXTRA[0]
        top = self.c.y + 0.022 + e
        if p.y >= top:
            return p
        d = p - self.c
        flat = math.hypot(d.x, d.z)
        shell = self.r + 0.01 + e
        if flat < self.r - 0.035:
            if p.y < self.soil + 0.003 + e:
                if d.length >= shell:
                    # Unter dem Korb (hängende Triebe): frei
                    return p
                if self.soil - p.y > 0.04:
                    # Tief unten im Korb: nach außen auf die Kugel
                    p = self.c + d.normalized() * shell
                else:
                    p.y = self.soil + 0.003 + e
        elif d.length < shell:
            if top - p.y < shell - d.length:
                p.y = top
            else:
                p = self.c + d.normalized() * shell
        return p


def greens_collar(b, base, rim_r, rim_y, rnd, space=NO_SPACE, glow=0.0, count=None, layer=None, upright=4, height=0.3):
    """Grün im Gefäß (Strauß, Korb): ein Kranz aus Laubzweigen, die aus der Mitte über den Rand
    wachsen und sich nach außen hängen, dazu ein paar aufrechte Zweige zwischen den Stielen –
    damit Blumen nicht verloren dastehen."""
    base = Vector(base)
    layer = layer or rnd.choice(["leaf_spray", "leaf_spray", "fern_frond", "broad_leaf"])
    count = _n(count if count is not None else max(6, int(rim_r / 0.011)))
    scale = max(0.6, min(1.6, rim_r / 0.12))
    for k in range(count):
        a = 2 * math.pi * k / count + rnd.uniform(-0.25, 0.25)
        d = Vector((math.cos(a), 0, math.sin(a)))
        start = base + d * rim_r * rnd.uniform(0.35, 0.6)
        length = rnd.uniform(0.1, 0.15) * scale * (0.75 if layer == "broad_leaf" else 1.0)
        lift = max(0.02, rim_y - base.y) + 0.02
        # Erst steil nach oben über den Rand, dann nach außen gebogen
        along = (d * 0.4 + Vector((0, 1.0, 0)) * (0.5 + lift / length)).normalized()
        facing = Vector((0, 1, 0)) - along * along.y + d * 0.2
        card(b, start, along, facing, length, length * (0.75 if layer != "broad_leaf" else 0.8), leaf_mat(layer, rnd, glow=glow),
             rows=3, fold=0.2, curl=rnd.uniform(0.7, 1.1), twist=rnd.uniform(-0.3, 0.3), space=space)
    for k in range(_n(upright)):
        a = rnd.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a), 0, math.sin(a)))
        start = base + d * rim_r * rnd.uniform(0.0, 0.3)
        along = (Vector((0, 1, 0)) + d * rnd.uniform(0.1, 0.35)).normalized()
        length = height * rnd.uniform(0.55, 0.85)
        card(b, start, along, d.cross(Vector((0, 1, 0))) + d * 0.3, length, length * 0.45, leaf_mat("leaf_spray", rnd, glow=glow),
             rows=3, fold=0.15, curl=rnd.uniform(0.2, 0.5), space=space)


def rim_trailers(b, x, z, inner_r, rim_y, soil_y, rnd, space, glow=0.0, count=None, kind=None, palette=None, length=0.3):
    """Ranken, die über den Topfrand hängen (Efeu, Lobelie, Hängepetunie)."""
    count = count if count is not None else rnd.randint(3, 6)
    base_a = rnd.uniform(0, 2 * math.pi)
    for k in range(_n(count)):
        a = base_a + 2 * math.pi * k / count + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        k_kind = kind or rnd.choice(["ivy", "ivy", "lobelia", "petunia"])
        pal = palette or ({"lobelia": rnd.choice(["blue", "white"]), "petunia": rnd.choice(["lavender", "rose", "white"])}.get(k_kind))
        trailing_ivy(b, Vector((x, soil_y, z)) + d * (inner_r - 0.025), length * rnd.uniform(0.5, 1.0), rnd, d, space, leaf_size=0.045,
                     glow=glow, kind=k_kind, palette=pal, over=0.06, lift=rim_y - soil_y + 0.015)


# Größen der Töpfe (Radius unten, Höhe, Radius oben)
POT_SIZES = {"small": (0.09, 0.24, 0.115), "medium": (0.125, 0.33, 0.155), "large": (0.165, 0.44, 0.205),
             "xl": (0.2, 0.55, 0.25)}
POT_KINDS = {
    "small": ["geranium", "daisy", "trailing", "petunia", "lavender", "box_low"],
    "medium": ["geranium", "lavender", "box_low", "petunia", "fern", "hydrangea", "daisy"],
    "large": ["box_ball", "cone", "hydrangea", "lavender", "geranium", "standard"],
    "xl": ["olive", "standard", "cone", "hydrangea", "box_ball"],
}
POT_PALETTES = ["red", "rose", "white", "coral", "lavender"]


def pot_cluster(b, x, rnd, direction=1, count=None, depth=0.6, wall_z=0.0, y=0.0, glow=0.0, sizes=None, gap=(0.0, 0.04),
                stagger=0.05, max_len=None, blocks=()):
    """Gruppe aus 1–3 Töpfen verschiedener Größe dicht nebeneinander an einer Wand (Ebene wall_z,
    Vorderseite +z), beginnend bei x, weiter in Richtung direction (±1). depth = höchstens so
    tief darf die Gruppe vor die Wand ragen; blocks = feste Kästen (lo, hi) an der Wand (Fenster-
    bänke, Fallrohre), in die nichts wächst. Liefert das belegte Stück (x von, x bis)."""
    count = count or rnd.choices([1, 2, 3], weights=[2, 4, 3])[0]
    fits = [k for k in ("xl", "large", "medium", "small") if 2 * (POT_SIZES[k][2] + 0.015) + 0.06 <= depth]
    if not fits:
        return (x, x)
    if sizes is None:
        sizes = []
        for k in range(count):
            # Groß hinten an der Wand, kleinere davor/daneben – nie drei gleiche
            pick = rnd.choice(fits[:2] if k == 0 else fits)
            sizes.append(pick)
        sizes.sort(key=lambda k: -POT_SIZES[k][2])
        if count == 3:
            sizes = [sizes[1], sizes[0], sizes[2]] if rnd.random() < 0.5 else sizes
    cursor = x
    lo_x = hi_x = x
    for k, size in enumerate(sizes):
        r0, h, r1 = POT_SIZES[size]
        scale = rnd.uniform(0.92, 1.08)
        r0, h, r1 = r0 * scale, h * rnd.uniform(0.9, 1.1), r1 * scale
        outer = r1 + 0.015
        if max_len is not None and abs(cursor + direction * 2 * outer - x) > max_len:
            break
        cx = cursor + direction * outer
        free = depth - 2 * outer - 0.04
        cz = wall_z + 0.03 + outer + (rnd.uniform(0.0, min(stagger, max(0.0, free))) if k else 0.0)
        kind = rnd.choice(POT_KINDS[size])
        pot_plant(b, cx, cz, kind, rnd, r0, h, r1, y=y, palette=rnd.choice(POT_PALETTES), glow=glow, wall_z=wall_z + 0.004,
                  blocks=blocks)
        lo_x, hi_x = min(lo_x, cx - outer), max(hi_x, cx + outer)
        cursor = cx + direction * (outer + rnd.uniform(*gap))
    return (lo_x, hi_x)


def fuchsia_flower(b, at, rnd, sepal_color, corolla_color, size=0.045, space=NO_SPACE, glow=0.0):
    """Hängende Fuchsienblüte (Spitze nach unten, Ansatz bei at): Röhre, vier zurückgebogene
    Kelchblätter, glockige Krone, Staubfäden mit Griffel."""
    at = Vector(at)
    down = Vector((0, -1, 0))
    spin = rnd.uniform(0, 2 * math.pi)
    tube_end = at + down * size * 0.35
    b.tube([at, tube_end], lambda t: size * (0.06 + 0.04 * t), soft_mat(sepal_color, glow), segments=4)
    for k in range(4):
        a = spin + math.pi / 2 * k
        out = Vector((math.cos(a), 0, math.sin(a)))
        # Kelchblätter: spreizen nach außen und biegen sich nach oben
        card(b, tube_end, (out * 0.9 + down * 0.25).normalized(), out * 0.2 + Vector((0, 1, 0)), size * 0.75, size * 0.32,
             bloom_mat("petal", sepal_color, glow, rnd), rows=1, curl=-0.6, fold=0.3, space=space)
    for k in range(4):
        a = spin + math.pi / 4 + math.pi / 2 * k
        out = Vector((math.cos(a), 0, math.sin(a)))
        # Krone: Blütenblätter hängen zusammen wie eine Glocke
        card(b, tube_end + out * size * 0.04, (down + out * 0.22).normalized(), out, size * 0.55, size * 0.42,
             bloom_mat("petal", corolla_color, glow, rnd), rows=1, curl=-0.25, fold=0.35, space=space)
    for k in range(5):
        a = spin + 2 * math.pi * k / 5
        tip = tube_end + down * size * (0.95 if k else 1.25) + Vector((math.cos(a), 0, math.sin(a))) * size * 0.08
        b.tube([tube_end, tip], 0.0008, soft_mat((0.9, 0.75, 0.8), glow), segments=3, caps=False)
        b.sphere(tip, 0.0022, soft_mat((0.55, 0.3, 0.35), glow), rings=2, segments=4)


FUCHSIA_COLORS = [((0.8, 0.08, 0.2), (0.36, 0.14, 0.52)), ((0.95, 0.42, 0.6), (0.97, 0.95, 0.96)),
                  ((0.84, 0.12, 0.22), (0.84, 0.12, 0.22)), ((0.97, 0.88, 0.92), (0.78, 0.2, 0.52))]
# Weiche Teile gleich merken: geo_check.py prüft auch fertige .glb-Dateien, ohne sie zu bauen
for _sepal, _corolla in FUCHSIA_COLORS:
    soft_mat(_sepal)
for _soft_color in ((0.9, 0.75, 0.8), (0.55, 0.3, 0.35), (0.5, 0.2, 0.18), (0.55, 0.2, 0.2), (0.3, 0.3, 0.31), (0.6, 0.5, 0.36)):
    soft_mat(_soft_color)


def _clear(space, p, radius, depth):
    """True, wenn um p (seitlich radius, nach unten depth) nichts im Weg ist (space verschiebt
    keinen der Prüfpunkte)."""
    for off in ((0, 0, 0), (radius, 0, 0), (-radius, 0, 0), (0, 0, radius), (0, 0, -radius), (0, -depth, 0),
                (radius * 0.6, -depth * 0.5, 0), (-radius * 0.6, -depth * 0.5, 0), (0, -depth * 0.5, radius * 0.6),
                (0, -depth * 0.5, -radius * 0.6)):
        q = p + Vector(off)
        if (space.push(q) - q).length > 1e-5:
            return False
    return True


def fuchsia_trail(b, start, length, rnd, out, space=NO_SPACE, colors=None, glow=0.0, over=0.08, lift=0.03):
    """Bogig überhängender Fuchsientrieb: rötlicher Stängel, der erst über den Rand wächst und
    dann weich herabhängt, gegenständige Blätter, an den Blattachseln hängende Blüten."""
    sepal, corolla = colors or rnd.choice(FUCHSIA_COLORS)
    out = Vector(out).normalized()
    start = Vector(start)
    # Bogen als quadratische Kurve: Ansatz – über dem Rand – unten außen
    p1 = start + out * over + Vector((0, lift * 2.0, 0))
    p2 = start + out * (over + length * 0.45) + Vector((0, -length * 0.85, 0))
    steps = max(6, int(length / 0.03))
    pts = []
    for k in range(steps + 1):
        t = k / steps
        p = start * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + p2 * t * t
        pts.append(space.push(p))
    stem(b, pts, 0.0038, 0.0022, soft_mat((0.5, 0.2, 0.18)), segments=3, space=space)
    side = Vector((0, 1, 0)).cross(out).normalized()
    leaf = lambda: leaf_mat("broad_leaf", rnd, shade=0.72, tint=(1.0, 0.94, 0.9), glow=glow)
    for k in range(1, len(pts)):
        tangent = (pts[k] - pts[k - 1]).normalized()
        if k % 2 == 1:
            for s in (-1, 1):
                card(b, pts[k], (side * s + tangent * 0.5 + Vector((0, 0.1, 0))).normalized(), Vector((0, 1, 0)) + out * 0.4,
                     0.05 * (1 - 0.3 * k / len(pts)), 0.048, leaf(), rows=1, fold=0.25, curl=0.3, space=space)
        if k >= 3 and k % 2 == 0:
            hang = pts[k] + side * rnd.uniform(-0.025, 0.025) + out * 0.012
            flower_top = space.push(hang + Vector((0, -rnd.uniform(0.025, 0.045), 0)))
            if not _clear(space, flower_top, 0.055, 0.09):
                # Die Blüte hätte keinen Platz (Korbrand, Wand): an dieser Stelle keine
                continue
            b.tube([pts[k], hang, flower_top], 0.001, soft_mat((0.55, 0.2, 0.2)), segments=3, caps=False)
            fuchsia_flower(b, flower_top, rnd, sepal, corolla, rnd.uniform(0.055, 0.07), space, glow)


def potted(b, x, z, rim_y, inner_r, soil_y, kind, rnd, palette=None, glow=0.0, outer_r=None, wall_z=None, ground=0.0, blocks=(),
           trailers=True, planes=()):
    """Pflanze in einem runden Topf (Topf baut der Aufrufer): kind = box_ball, cone, standard,
    geranium, lavender, fern, petunia, olive, hydrangea, daisy, rosemary."""
    space = PotSpace(x, z, inner_r, rim_y, soil_y, outer=outer_r, ground=ground)
    for lo, hi in blocks:
        space.block(lo, hi)
    for point, normal, gap in planes:
        space.plane(point, normal, gap=gap)
    scale = max(0.55, min(1.2, inner_r / 0.15))
    if wall_z is not None:
        space.wall(wall_z)
    soil = Vector((x, soil_y, z))
    if kind == "box_ball":
        r = inner_r * rnd.uniform(1.05, 1.25)
        cy = rim_y + r * 0.8
        b.tube([soil, Vector((x, cy - r * 0.5, z))], 0.012, BARK, segments=5)
        box_ball(b, Vector((x, cy, z)), r, rnd, space, glow)
    elif kind == "cone":
        box_cone(b, Vector((x, soil_y + 0.02, z)), inner_r * 4.0, inner_r * 1.1, rnd, space, glow)
    elif kind == "standard":
        standard_ball(b, soil, inner_r * 4.5, inner_r * 1.2, rnd, space, glow)
    elif kind == "geranium":
        geranium(b, soil, rnd, palette or "red", scale, space, glow)
    elif kind == "lavender":
        lavender(b, soil, inner_r, rnd, space, glow)
    elif kind == "fern":
        fern(b, soil, inner_r * 2.6, rnd, space, glow)
    elif kind == "petunia":
        petunia_plant(b, soil, rnd, palette or "lavender", 1.0, space, glow, trail=0.25, out=Vector((0, 0, 1)),
                      reach=inner_r + 0.04, lift=rim_y - soil_y + 0.02)
    elif kind == "olive":
        olive(b, soil, inner_r * 6.0, rnd, space, glow)
    elif kind == "hydrangea":
        hydrangea(b, soil, inner_r * 1.2, rnd, palette or "hydrangea", space, glow)
    elif kind == "daisy":
        daisy_plant(b, soil, rnd, scale, space, glow)
    elif kind == "trailing":
        # Hängetopf: Polster aus Efeu und Lobelien, viele Ranken über den Rand
        lobelia(b, soil, rnd, palette or "white", scale, space, glow)
        for k in range(7):
            t = 2 * math.pi * k / 7 + rnd.uniform(-0.3, 0.3)
            d = Vector((math.cos(t), 0, math.sin(t)))
            trailing_ivy(b, soil + d * (inner_r - 0.03), rnd.uniform(0.25, 0.55), rnd, d, space, leaf_size=0.045, glow=glow,
                         over=0.07, lift=rim_y - soil_y + 0.015)
    elif kind == "box_low":
        r = inner_r * rnd.uniform(1.0, 1.15)
        b.tube([soil, Vector((x, rim_y + r * 0.3, z))], 0.01, BARK, segments=5)
        box_ball(b, Vector((x, rim_y + r * 0.78, z)), r, rnd, space, glow)
    else:
        geranium(b, soil, rnd, palette or "rose", scale * 0.9, space, glow)
    # Voller wirken: Ranken über den Rand (Blüher), Efeu unter Bäumchen und Formschnitt
    if not trailers:
        pass
    elif kind in ("geranium", "petunia", "daisy", "hydrangea") and rnd.random() < 0.8:
        rim_trailers(b, x, z, inner_r, rim_y, soil_y, rnd, space, glow, length=0.18 + inner_r)
    elif kind in ("olive", "standard", "cone") and rnd.random() < 0.7:
        rim_trailers(b, x, z, inner_r, rim_y, soil_y, rnd, space, glow, kind="ivy", count=rnd.randint(4, 7), length=0.2 + inner_r)
