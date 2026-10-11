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
import random

from mathutils import Vector

import style_lib as S
from style_lib import Mat, V

# Neutrale Farbe der Pflanzen-Texturen (Blätter haben ihre Farbe schon in der Textur)
NEUTRAL = 0.8

STEM_GREEN = Mat("plain", color=(0.3, 0.4, 0.2))
STEM_BROWN = Mat("plain", color=(0.33, 0.27, 0.19))
IVY_STEM = Mat("plain", color=(0.36, 0.3, 0.22))
SOIL = Mat("plain", color=(0.2, 0.15, 0.11))
BARK = Mat("bark", color=(0.8, 0.8, 0.8))
# Ketten der Hängekörbe: Metall (sieht aus wie IRON); eigene Farbe nur, damit geo_check.py sie
# erkennt (Pflanzen wachsen um Ketten herum)
CHAIN = Mat("metal", color=(0.999, 0.999, 0.999))

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
        for rule in self.rules:
            kind = rule[0]
            if kind == "wall":
                _, z, x0, x1, y0, y1 = rule
                if x0 <= p.x <= x1 and y0 <= p.y <= y1 and p.z < z:
                    p.z = z
            elif kind == "floor":
                _, y, x0, x1, z0, z1 = rule
                if x0 <= p.x <= x1 and z0 <= p.z <= z1 and p.y < y:
                    p.y = y
            elif kind == "block":
                _, lo, hi = rule
                if lo.x < p.x < hi.x and lo.y < p.y < hi.y and lo.z < p.z < hi.z:
                    options = [(hi.y - p.y, "up"), (hi.z - p.z, "front"), (p.x - lo.x, "left"), (hi.x - p.x, "right")]
                    dist, way = min(options)
                    if way == "up":
                        p.y = hi.y
                    elif way == "front":
                        p.z = hi.z
                    elif way == "left":
                        p.x = lo.x
                    else:
                        p.x = hi.x
            elif kind == "inside":
                _, lo, hi = rule
                p = Vector((min(max(p.x, lo.x), hi.x), min(max(p.y, lo.y), hi.y), min(max(p.z, lo.z), hi.z)))
            elif kind == "plane":
                _, q, nrm, gap = rule
                d = (p - q).dot(nrm)
                if d < gap:
                    p = p + nrm * (gap - d)
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


# ---------------------------------------------------------------------------------------------
# Grundbausteine: Blattfläche, Blütenfläche, Stängel
# ---------------------------------------------------------------------------------------------

_GROUP = [0]


def _tag(b, start):
    """Flächen ab start gehören zu einem Blatt / einer Blüte (für settle)."""
    _GROUP[0] += 1
    for face in b.faces[start:]:
        face["group"] = _GROUP[0]


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
    _tag(b, start_face)
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
    if size < 0.036:
        pts = [c + side * (-0.5 * size) + up * (-0.5 * size), c + side * (0.5 * size) + up * (-0.5 * size),
               c + side * (0.5 * size) + up * (0.5 * size), c + side * (-0.5 * size) + up * (0.5 * size)]
        b.poly([space.push(p) for p in pts], mat, normals=[n] * 4, uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
        _tag(b, start_face)
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
    _tag(b, start_face)


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
             spread=0.9, leaf_size=0.085, density=1.0, pit=True, glow=0.0, bumps=(), max_leaves=1800, floor_y=None):
    """Efeu, der aus dem Boden (bzw. einem kleinen Pflanzloch) bei x_root die Wand (Ebene z_wall,
    Vorderseite +z) hochwächst: verzweigte Triebe mit Haftwurzeln, Blätter an Stielen, unten
    dichter und größer, oben jung und heller. Fenster/Türen (holes = Rechtecke x0, y0, x1, y1)
    bleiben frei, die Triebe wachsen um sie herum. bumps = vorstehende Teile (Gesimse, Sockel:
    x0, y0, x1, y1, Vorderkante z) – Triebe und Blätter wachsen darüber hinweg. Alles bleibt vor
    der Wand."""
    space = Space().wall(z_wall, gap=0.003)
    for bx0, by0, bx1, by1, bz in bumps:
        space.block((bx0, by0, z_wall - 1.0), (bx1, by1, bz), gap=0.004)

    def stem_z(px, py, r):
        z = z_wall + r + 0.002
        for bx0, by0, bx1, by1, bz in bumps:
            if bx0 - 0.02 < px < bx1 + 0.02 and by0 - 0.04 < py < by1 + 0.04:
                z = max(z, bz + r + 0.003)
        return z
    # Liegt die Wurzel in einer Öffnung (Tür, Fenster bis zum Boden), rückt sie zur nächsten
    # freien Stelle an der Wand
    max_leaves = int(max_leaves * DETAIL[-1])
    if _in_holes(x_root, y_root + 0.1, holes, 0.1):
        free = [x_root + d * sgn for d in [0.05 * k for k in range(1, 60)] for sgn in (1, -1)
                if x_min + 0.1 < x_root + d * sgn < x_max - 0.1 and not _in_holes(x_root + d * sgn, y_root + 0.1, holes, 0.12)]
        if not free:
            return
        x_root = free[0]
    space.floor(floor_y if floor_y is not None else y_root, gap=0.01)
    if pit:
        space.block((x_root - 0.25, y_root - 0.1, z_wall - 0.1), (x_root + 0.25, y_root + 0.045, z_wall + 0.21), gap=0.03)
        corners = [b.xf @ Vector(c) for c in ((x_root - 0.3, y_root, z_wall), (x_root + 0.3, y_root, z_wall + 0.27))]
        _register(b, "box", (Vector((min(c.x for c in corners), y_root, min(c.z for c in corners))),
                             Vector((max(c.x for c in corners), y_root + 0.045, max(c.z for c in corners))), 0.0, 0.045, None))
        # Kleines Pflanzloch im Pflaster: Erde, Rand aus Ziegeln
        b.box((x_root - 0.2, y_root, z_wall), (x_root + 0.2, y_root + 0.012, z_wall + 0.16), SOIL, skip=("back",))
        for k, (lo, hi) in enumerate((((x_root - 0.24, y_root, z_wall), (x_root - 0.2, y_root + 0.04, z_wall + 0.2)),
                                      ((x_root + 0.2, y_root, z_wall), (x_root + 0.24, y_root + 0.04, z_wall + 0.2)),
                                      ((x_root - 0.24, y_root, z_wall + 0.16), (x_root + 0.24, y_root + 0.04, z_wall + 0.2)))):
            b.box(lo, hi, Mat("brick", color=(0.5, 0.33, 0.27)), skip=("back", "bottom"))
    branches = []
    step = 0.06
    for k in range(stems):
        heading = math.pi / 2 + (k - (stems - 1) / 2) * 0.35 + rnd.uniform(-0.15, 0.15)
        start = (x_root + rnd.uniform(-0.08, 0.08), y_root + 0.01)
        branches.append([start, heading, 0, 0.007 * rnd.uniform(0.85, 1.1), rnd.uniform(0.75, 1.0) * (top - y_root) * 1.3])
    paths = []
    # Belegung je 10-cm-Feld: höchstens zwei Triebe und vier Blätter – so verteilt sich der
    # Efeu, statt sich in einer schmalen Lücke zu stauen
    stem_cells = {}
    leaf_cells = {}

    def cell(px, py):
        return (int(math.floor(px / 0.1)), int(math.floor(py / 0.1)))
    # So viel Trieb, wie die Blätter bedecken können (sonst bleiben kahle Triebe übrig)
    stem_budget = max_leaves * 0.024
    grown = 0.0
    while branches and grown < stem_budget:
        (x, y), heading, depth, radius, budget = branches.pop()
        pts = [(x, y)]
        length = 0.0
        target_x = x + rnd.uniform(-spread, spread) * (0.6 if depth == 0 else 1.0)
        while length < budget and y < top and grown < stem_budget:
            heading += rnd.gauss(0, 0.22)
            # Nach oben ziehen, etwas zur Seite auffächern
            heading += 0.12 * (math.pi / 2 - heading) + 0.04 * max(-1.0, min(1.0, (target_x - x) / 0.4)) * -1
            moved = False
            for turn in (0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5):
                h = heading + turn
                nx, ny = x + math.cos(h) * step, y + math.sin(h) * step
                if not (x_min < nx < x_max) or ny < y_root or _in_holes(nx, ny, holes, 0.07):
                    continue
                c = cell(nx, ny)
                if c != cell(x, y) and stem_cells.get(c, 0) >= 2 and ny > y_root + 0.15:
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
            if depth < 3 and rnd.random() < 0.12 * density and length > 0.12:
                side = rnd.choice((-1, 1))
                branches.append([(x, y), heading + side * rnd.uniform(0.5, 1.1), depth + 1, radius * 0.65,
                                 (budget - length) * rnd.uniform(0.4, 0.8)])
        if len(pts) >= 3:
            paths.append((pts, depth, radius))
    leaves = 0
    for pts, depth, radius in paths:
        count = len(pts)
        rad = lambda i: max(0.0018, radius * (1 - 0.8 * i / max(1, count - 1)))
        line = [Vector((px, py, stem_z(px, py, rad(i)))) for i, (px, py) in enumerate(pts)]
        b.tube(line, lambda t: max(0.0018, radius * (1 - 0.8 * t)), IVY_STEM, segments=4 if radius > 0.006 else 3, caps=True)
        acc = 0.0
        side_sign = 1
        for i in range(1, count):
            acc += step
            px, py = pts[i]
            # Haftwurzeln: kleine Fäden vom Trieb an die Wand
            if i % 3 == 0:
                for q in (-1, 1):
                    b.tube([line[i] + Vector((0, 0, -rad(i) * 0.5)), line[i] + Vector((q * 0.012, -0.006, -rad(i) - 0.0015))],
                           0.0009, IVY_STEM, segments=3, caps=False)
            spacing = 0.029 if py < top * 0.6 else 0.038
            if acc < spacing / max(0.4, density):
                continue
            acc = 0.0
            frac = (py - y_root) / max(0.01, top - y_root)
            young = i > count - 4
            for pair in range(2 if rnd.random() < 0.35 else 1):
                size = leaf_size * rnd.uniform(0.8, 1.2) * (1.0 - 0.35 * frac) * (0.6 if young else 1.0)
                out = Vector((side_sign * rnd.uniform(0.1, 0.5), rnd.uniform(-0.1, 0.25), 1.0))
                side_sign = -side_sign
                if _in_holes(px, py, holes, size * 0.9):
                    continue
                c = cell(px, py)
                if leaf_cells.get(c, 0) >= 5 or leaves >= max_leaves:
                    continue
                leaf_cells[c] = leaf_cells.get(c, 0) + 1
                leaves += 1
                ivy_leaf(b, line[i] + Vector((0, 0, rad(i) * 0.6)), out, size, rnd, space, young=young, glow=glow)
        # Spitze: zwei, drei junge, helle Blättchen
        tip = line[-1]
        for q in range(2):
            ivy_leaf(b, tip, Vector((rnd.uniform(-0.4, 0.4), 0.3, 1.0)), leaf_size * 0.45, rnd, space, young=True, glow=glow, hang=0.2)


def ivy_garland(b, x0, x1, y, z, rnd, drops=True, drop_max=1.2, leaf_size=0.06, holes=(), glow=0.0, z_back=0.0, side_drops=(),
                source=None):
    """Efeu, der oben auf einem Sims (Höhe y, Vorderkante z) entlangwächst und in Ranken
    herabhängt (z. B. über dem Pub-Schild). Die Triebe liegen auf dem Sims, die Ranken hängen
    vor der Front (Ebene z). source = Pflanztrog auf dem Sims, aus dem der Efeu wächst
    (x_links, x_rechts, Höhe Erde, Höhe Rand, z_vorn, z_hinten): die Triebe kommen aus der Erde,
    gehen über den Rand und laufen auf dem Sims weiter."""
    space = Space().wall(z - 0.002, y0=-1e9, y1=y - 0.005, gap=0.006).floor(y, z0=-1e9, z1=z, gap=0.002).wall(z_back, y0=y - 0.01)
    if source:
        sx0, sx1, soil_y, rim_y, sz0, sz1 = source
        space.block((sx0, y - 0.01, sz0), (sx1, rim_y, sz1), gap=0.005)
    # Liegende Haupttriebe auf dem Sims
    for lane in range(4):
        zz = z - 0.045 - lane * 0.05
        pts = []
        if source:
            pts += [Vector((sx0 + 0.12 + 0.05 * lane, soil_y + 0.005, zz)), Vector((sx1 - 0.08, rim_y + 0.02, zz)),
                    Vector((sx1 + 0.03, rim_y + 0.012, zz)), Vector((sx1 + 0.12, y + 0.008, zz))]
            x = sx1 + 0.2
        else:
            x = x0
        while x < x1:
            pts.append(Vector((x, y + 0.008, zz + rnd.uniform(-0.015, 0.015))))
            x += 0.06
        pts.append(Vector((x1, y + 0.008, zz)))
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
    x = (sx1 + 0.1 if source else x0) + rnd.uniform(0.05, 0.2)
    while x < x1 - 0.05:
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
    """Geranie (Pelargonie): kurze, kräftige Triebe, runde Blätter mit dunkler Zone an langen
    Stielen, darüber Blütendolden auf langen Stielen. base = Punkt auf der Erde."""
    base = Vector(base)
    colors = BLOSSOMS[palette]
    nodes = []
    for k in range(rnd.randint(3, 4)):
        d = _rand_dir(rnd, 0.0, 0.2)
        tip = base + Vector((d.x * 0.05, rnd.uniform(0.05, 0.1), d.z * 0.05)) * scale
        stem(b, _curve(base, tip, (0, 0.01, 0), 3), 0.006 * scale, 0.004 * scale, STEM_BROWN, space=space)
        nodes.append(tip)
    for k in range(_n(rnd.randint(13, 17))):
        node = rnd.choice(nodes)
        a = 2 * math.pi * k / 16 + rnd.uniform(-0.3, 0.3)
        out = Vector((math.cos(a), 0, math.sin(a)))
        reach = rnd.uniform(0.04, 0.12) * scale
        end = node + out * reach + Vector((0, rnd.uniform(-0.01, 0.08) * scale, 0))
        end = space.push(end)
        stem(b, _curve(node, end, (0, 0.02 * scale, 0), 3), 0.0025 * scale, 0.002 * scale, STEM_GREEN, space=space)
        size = rnd.uniform(0.075, 0.1) * scale
        facing = (Vector((0, 1, 0)) + out * rnd.uniform(0.15, 0.6)).normalized()
        card(b, end - out * size * 0.47, out, facing, size, size, leaf_mat("round_leaf", rnd, glow=glow), rows=2,
             fold=rnd.uniform(0.0, 0.2), curl=rnd.uniform(0.1, 0.4), space=space)
    count = flowers if flowers is not None else rnd.randint(2, 3)
    for k in range(count):
        node = rnd.choice(nodes)
        d = _rand_dir(rnd, 0.0, 0.0)
        top = node + Vector((d.x * 0.06, rnd.uniform(0.13, 0.2), d.z * 0.06)) * scale
        top = space.push(top)
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
        b.sphere(p, 0.006, Mat("foliage", color=tuple(0.5 * c + 0.2 for c in color)), rings=3, segments=5, squash=1.3)


def petunia_plant(b, base, rnd, palette="lavender", scale=1.0, space=NO_SPACE, glow=0.0, trail=0.0, out=Vector((0, 0, 1)),
                  reach=0.07, lift=0.03):
    """Petunie: weiche, eiförmige Blätter an liegenden Trieben, große Trichterblüten nach außen
    und oben. trail > 0: einige Triebe hängen so weit über die Kante (Richtung out)."""
    base = Vector(base)
    colors = BLOSSOMS[palette]
    for k in range(_n(rnd.randint(9, 11))):
        a = 2 * math.pi * k / 10 + rnd.uniform(-0.4, 0.4)
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
    for k in range(18):
        d = _rand_dir(rnd, 0.25, 0.75)
        card(b, base + Vector((d.x, 0, d.z)) * 0.01, d, Vector((0, 1, 0)) + Vector((d.x, 0, d.z)), 0.1 * scale, 0.1 * scale,
             leaf_mat("fern_frond", rnd, tint=(0.95, 1.05, 0.9), glow=glow), rows=2, curl=0.6, space=space)
    for k in range(rnd.randint(6, 9)):
        d = _rand_dir(rnd, 0.0, 0.0)
        top = space.push(base + Vector((d.x * 0.07, rnd.uniform(0.14, 0.24), d.z * 0.07)) * scale)
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

def bouquet(b, base, height, radius, rnd, kind="tulip", palette="rose", space=NO_SPACE, glow=0.0, count=None):
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
    for faces in groups.values():
        pts = {}
        for face in faces:
            for p in face["pts"]:
                pts[(round(p.x, 6), round(p.y, 6), round(p.z, 6))] = p
        lift = _crossing_lift(list(pts.values()), containers)
        if not lift:
            continue
        for face in faces:
            face["pts"] = [lift(p) for p in face["pts"]]


def _crossing_lift(pts, containers):
    """Falls die Punkte eines Blatts eine Gefäßwand unterhalb des Rands kreuzen: Funktion, die
    die betroffenen Punkte auf den Rand hebt – sonst None."""
    lifts = []
    for kind, data in containers:
        if kind == "cyl":
            base, inner, outer, height, soil_h = data
            rim = base.y + height
            low = [p for p in pts if base.y <= p.y < rim + 0.004]
            if not low:
                continue
            dists = [math.hypot(p.x - base.x, p.z - base.z) for p in low]
            above_inside = any(p.y >= rim + 0.004 and math.hypot(p.x - base.x, p.z - base.z) < outer for p in pts)
            crossing = min(dists) < outer + 0.006 and max(dists) > inner - 0.006 and (min(dists) < inner or max(dists) > outer)
            over_rim = above_inside and min(dists) < outer + 0.04
            if crossing or over_rim:
                lifts.append(("cyl", base, outer, rim))
        else:
            lo, hi, wall, soil_h, back = data
            low = [p for p in pts if lo.y <= p.y < hi.y + 0.004]
            if not low:
                continue
            ins = [lo.x <= p.x <= hi.x and lo.z <= p.z <= hi.z for p in low]
            if any(ins) and not all(ins):
                lifts.append(("box", lo, hi))
    if not lifts:
        return None

    def lift(p):
        p = Vector(p)
        for item in lifts:
            if item[0] == "cyl":
                _, base, outer, rim = item
                if p.y < rim + 0.006 and math.hypot(p.x - base.x, p.z - base.z) < outer + 0.045:
                    p.y = rim + 0.006
            else:
                _, lo, hi = item
                if p.y < hi.y + 0.006 and lo.x - 0.012 < p.x < hi.x + 0.012 and lo.z - 0.012 < p.z < hi.z + 0.012:
                    p.y = hi.y + 0.006
        return p
    return lift


def _settle_point(p, containers):
    for kind, data in containers:
        if kind == "cyl":
            base, inner, outer, height, soil_h = data
            rim = base.y + height
            if not (base.y - 0.001 <= p.y < rim + 0.005):
                continue
            d = Vector((p.x - base.x, 0.0, p.z - base.z))
            dist = d.length
            if dist < inner - 0.006:
                if p.y < base.y + soil_h + 0.002:
                    p.y = base.y + soil_h + 0.002
            elif dist < outer + 0.006:
                if rim + 0.006 - p.y < outer + 0.006 - dist or dist < 1e-6:
                    p.y = rim + 0.006
                else:
                    d.normalize()
                    p.x = base.x + d.x * (outer + 0.006)
                    p.z = base.z + d.z * (outer + 0.006)
        else:
            lo, hi, wall, soil_h, back = data
            if not (lo.y - 0.001 <= p.y < hi.y + 0.005 and lo.x - 0.006 < p.x < hi.x + 0.006 and lo.z - 0.006 < p.z < hi.z + 0.006):
                continue
            inside = lo.x + wall + 0.004 < p.x < hi.x - wall - 0.004 and lo.z + wall + 0.004 < p.z < hi.z - wall - 0.004
            if inside:
                if p.y < lo.y + soil_h + 0.002:
                    p.y = lo.y + soil_h + 0.002
            else:
                options = [(hi.y + 0.006 - p.y, "up"), (p.x - lo.x + 0.006, "-x"), (hi.x + 0.006 - p.x, "+x"),
                           (p.z - lo.z + 0.006, "-z"), (hi.z + 0.006 - p.z, "+z")]
                if back is not None:
                    blocked = {"-x": back.x < -0.7, "+x": back.x > 0.7, "-z": back.z < -0.7, "+z": back.z > 0.7}
                    options = [o for o in options if not blocked.get(o[1], False)]
                _, way = min(options)
                if way == "up":
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


S.FINISHERS.append(settle)


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
    b.cylinder(V(x, y, z), r_bottom, height, mat, segments=segments, radius_top=r_top, caps=(True, False))
    outer = r_top + lip
    _register(b, "cyl", (b.xf @ Vector((x, y, z)), r_top - wall, max(r_bottom, outer), height, rim - soil_drop - y))
    if lip > 0:
        b.cylinder(V(x, rim - lip_h, z), outer, lip_h, mat, segments=segments, caps=(False, False))
        _ring(b, x, rim - lip_h, z, r_top - 0.001, outer, mat, up=False, segments=segments)
    inner = r_top - wall
    _ring(b, x, rim, z, inner, outer, mat, up=True, segments=segments)
    soil = rim - soil_drop
    _inner_wall(b, x, z, inner, soil, rim, mat, segments=segments)
    _ring(b, x, soil, z, 0.0, inner, soil_mat or SOIL, up=True, segments=segments)
    return {"rim": rim, "inner": inner, "soil": soil, "outer": outer}


def trough(b, x0, x1, y, z0, z1, height, mat, soil_drop=0.02, wall=0.018, skip_back=False):
    """Offener Kasten (Blumenkasten, Kiste, Pflanztrog): Außenwände, Rand oben, Innenwände,
    Erde. Gibt die Höhe der Erde zurück."""
    top = y + height
    soil = top - soil_drop
    b.box((x0, y, z0), (x1, top, z1), mat, skip=("top",) + (("back",) if skip_back else ()))
    corners = [b.xf @ Vector(c) for c in ((x0, y, z0), (x1, y, z0), (x0, y, z1), (x1, y, z1))]
    # Steht der Kasten an einer Wand (skip_back), darf nichts nach hinten geschoben werden
    back = (b.xf.to_3x3() @ Vector((0, 0, -1))).normalized() if skip_back else None
    _register(b, "box", (Vector((min(c.x for c in corners), corners[0].y, min(c.z for c in corners))),
                         Vector((max(c.x for c in corners), corners[0].y + height, max(c.z for c in corners))), wall, height - soil_drop, back))
    ix0, ix1, iz0, iz1 = x0 + wall, x1 - wall, z0 + wall, z1 - wall
    for lo, hi in (((x0, top, z0), (x1, top, iz0)), ((x0, top, iz1), (x1, top, z1)),
                   ((x0, top, iz0), (ix0, top, iz1)), ((ix1, top, iz0), (x1, top, iz1))):
        b.face([V(lo[0], top, lo[2]), V(hi[0], top, lo[2]), V(hi[0], top, hi[2]), V(lo[0], top, hi[2])], mat, (0, 1, 0))
    b.face([V(ix0, soil, iz0), V(ix1, soil, iz0), V(ix1, top, iz0), V(ix0, top, iz0)], mat, (0, 0, 1))
    b.face([V(ix0, soil, iz1), V(ix1, soil, iz1), V(ix1, top, iz1), V(ix0, top, iz1)], mat, (0, 0, -1))
    b.face([V(ix0, soil, iz0), V(ix0, soil, iz1), V(ix0, top, iz1), V(ix0, top, iz0)], mat, (1, 0, 0))
    b.face([V(ix1, soil, iz0), V(ix1, soil, iz1), V(ix1, top, iz1), V(ix1, top, iz0)], mat, (-1, 0, 0))
    b.face([V(ix0, soil, iz0), V(ix1, soil, iz0), V(ix1, soil, iz1), V(ix0, soil, iz1)], SOIL, (0, 1, 0))
    return soil


def ledge_planter(b, x0, x1, y, z0, z1, rnd, palettes, mat, front_z, trail=0.4, glow=0.0, long_trails=(), height=0.15):
    """Pflanztrog oben auf einem Gesims (Höhe y, Trog von z0 bis z1, Vorderkante des Gesimses
    front_z): Balkonblumen, vorn hängen Ranken herab; long_trails = [(x, Länge)] lange
    Efeuranken (z. B. an den Pilastern hinunter). Unter dem Gesims bleibt alles davor."""
    soil = trough(b, x0, x1, y, z0, z1, height, mat)
    space = BoxSpace(x0, x1, z0, z1, y + height, soil, wall=0.018)
    space.wall(0.0, y0=y - 0.01)
    space.wall(front_z, y1=y - 0.002)
    with detail(0.6):
        bedding_row(b, x0 + 0.05, x1 - 0.05, soil, z0 + 0.03, z1 - 0.03, rnd, palettes, space, glow=glow, trail_front=trail,
                    front_dir=Vector((0, 0, 1)), spacing=0.2)
    for x, length in long_trails:
        trailing_ivy(b, Vector((x, soil, z1 - 0.05)), length, rnd, Vector((0, 0, 1)), space, leaf_size=0.055, glow=glow,
                     over=front_z - z1 + 0.1, lift=height - (soil - y) + 0.02)


def pot_plant(b, x, z, kind, rnd, r_bottom=0.13, height=0.35, r_top=0.16, y=0.0, palette=None, glow=0.0, wall_z=None,
              mat=None, collider=True, blocks=()):
    """Terrakotta-Topf mit Pflanze (kind wie potted) an (x, y, z); mit Kollision. blocks =
    feste Kästen in der Nähe (lo, hi), in die nichts hineinwachsen darf."""
    v = vessel(b, x, z, r_bottom, height, r_top, mat or Mat("terracotta", glow=glow), y=y)
    potted(b, x, z, v["rim"], v["inner"], v["soil"], kind, rnd, palette, glow, outer_r=v["outer"], wall_z=wall_z, ground=y,
           blocks=blocks)
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
    b.cylinder(c + Vector((0, radius + 0.03, 0)), 0.004, 0.02, Mat("metal"), segments=6, axis="z", caps=(False, True))
    b.tube([c + Vector((0, radius + 0.03, 0.012)), c + Vector((0, radius + 0.005, 0.013))], 0.002, Mat("plain", color=(0.6, 0.5, 0.36)), segments=3)
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
        if p.y < self.ground + 0.003:
            p.y = self.ground + 0.003
        d = Vector((p.x - self.x, 0.0, p.z - self.z))
        dist = d.length
        if dist < self.r - 0.008:
            if p.y < self.soil + 0.003:
                p.y = self.soil + 0.003
        elif dist < self.outer + 0.006 and p.y < self.rim + 0.006:
            # In der Topfwand: über den Rand heben, wenn nah dran, sonst nach außen
            if self.rim + 0.006 - p.y < self.outer + 0.006 - dist or dist < self.r:
                p.y = self.rim + 0.006
            else:
                d.normalize()
                p.x = self.x + d.x * (self.outer + 0.006)
                p.z = self.z + d.z * (self.outer + 0.006)
        return p


class BoxSpace(Space):
    """Kasten (Blumenkasten, Kübel eckig): innen über der Erde, außen vor/über der Wand."""

    def __init__(self, x0, x1, z0, z1, rim_y, soil_y, wall=0.02):
        super().__init__()
        self.x0, self.x1, self.z0, self.z1, self.rim, self.soil, self.w = x0, x1, z0, z1, rim_y, soil_y, wall

    def push(self, p):
        p = Space.push(self, p)
        inside = self.x0 + self.w < p.x < self.x1 - self.w and self.z0 + self.w < p.z < self.z1 - self.w
        if inside:
            if p.y < self.soil + 0.003:
                p.y = self.soil + 0.003
        elif self.x0 - 0.006 < p.x < self.x1 + 0.006 and self.z0 - 0.006 < p.z < self.z1 + 0.006 and p.y < self.rim + 0.006:
            # In der Kastenwand: nach vorn hinaus, wenn vorn; sonst über den Rand
            if p.z > self.z1 - self.w - 0.002 and self.rim - p.y > 0.015:
                p.z = self.z1 + 0.007
            else:
                p.y = self.rim + 0.006
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
        if p.y > self.c.y + 0.006:
            return p
        d = p - self.c
        flat = math.hypot(d.x, d.z)
        if flat < self.r - 0.02:
            if p.y < self.soil + 0.003:
                if d.length < self.r + 0.01 and self.soil - p.y > 0.04:
                    # Tief unten im Korb: nach außen auf die Kugel
                    p = self.c + d.normalized() * (self.r + 0.01)
                else:
                    p.y = self.soil + 0.003
        elif d.length < self.r + 0.01:
            if self.c.y + 0.006 - p.y < self.r + 0.01 - d.length:
                p.y = self.c.y + 0.006
            else:
                p = self.c + d.normalized() * (self.r + 0.01)
        return p


def potted(b, x, z, rim_y, inner_r, soil_y, kind, rnd, palette=None, glow=0.0, outer_r=None, wall_z=None, ground=0.0, blocks=()):
    """Pflanze in einem runden Topf (Topf baut der Aufrufer): kind = box_ball, cone, standard,
    geranium, lavender, fern, petunia, olive, hydrangea, daisy, rosemary."""
    space = PotSpace(x, z, inner_r, rim_y, soil_y, outer=outer_r, ground=ground)
    for lo, hi in blocks:
        space.block(lo, hi)
    scale = max(0.55, min(1.2, inner_r / 0.15))
    if wall_z is not None:
        space.wall(wall_z)
    soil = Vector((x, soil_y, z))
    if kind == "box_ball":
        r = inner_r * rnd.uniform(1.05, 1.25)
        cy = resting_height(rim_y, (outer_r or inner_r + 0.02), r)
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
        box_ball(b, Vector((x, resting_height(rim_y, (outer_r or inner_r + 0.02), r), z)), r, rnd, space, glow)
    else:
        geranium(b, soil, rnd, palette or "rose", scale * 0.9, space, glow)
