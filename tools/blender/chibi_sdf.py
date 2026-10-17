"""Chibi-Figuren (seit Etappe 5c) als Abstandsfeld: Der Körper ist eine weiche Vereinigung von
Grundformen (Ellipsoide, runde Kegel), wie eine Vinyl-Figur aus Knete. Aus dem Feld entstehen
das Netz (Surface Nets), die Formregler (dieselben Ecken auf das Feld der dünnen/dicken Form
geschoben), die Gewichte fürs Skelett (welche Grundform ist an einer Stelle am nächsten) und
eine leichte Verschattung (AO) als Vertex-Farbe.

Reines numpy (kein bpy): lässt sich auch außerhalb von Blender testen.
Koordinaten wie Blender: x = linke Körperseite, y nach hinten, z oben; Blick nach -y; T-Pose.
"""

import math

import numpy as np

BIG = np.float32(1.0)
# Jede Form wird bis zu diesem Abstand um ihren Kasten ausgewertet (größer als jedes k), damit
# die weichen Übergänge auch an den Kastenrändern stimmen
PAD = 0.11

# Körpergrößen (m) und fester Kopf (Scheitel bis Kinn) – Frauen und Männer gleich großer Kopf
HEAD_HEIGHT = 0.47
HEIGHTS = {
    "female": {"small": 1.50, "medium": 1.58, "tall": 1.66},
    "male": {"small": 1.58, "medium": 1.67, "tall": 1.76},
}
SHAPES = ("thin", "medium", "fat")
EAR_TURN = 24.0   # Ohren um so viel Grad nach vorn gedreht
ARM_REST = 50.0   # Ruhehaltung der Arme: so viel Grad unter der Waagerechten (A-Pose)
NOSE_Z = 0.114    # Nasenspitze über dem Kinn


# ---------------------------------------------------------------------------------------------
# Weiche Verknüpfungen
# ---------------------------------------------------------------------------------------------

def smin(a, b, k):
    if k <= 0.0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * (k * 0.25)


def smax(a, b, k):
    return -smin(-a, -b, k)


# ---------------------------------------------------------------------------------------------
# Grundformen (Blätter) und Gruppen
# ---------------------------------------------------------------------------------------------

class Leaf:
    """Eine Grundform. bones = {Knochen: Anteil} (None = zählt nicht für Gewichte),
    sigma = wie weich der Übergang der Gewichte zu Nachbarformen ist."""

    def __init__(self, name, lo, hi, bones=None, sigma=0.012):
        self.name = name
        self.lo = np.array(lo, np.float64)
        self.hi = np.array(hi, np.float64)
        self.bones = bones
        self.sigma = sigma

    def f(self, x, y, z):
        raise NotImplementedError

    def eval_grid(self, xs, ys, zs):
        return self.f(xs[:, None, None], ys[None, :, None], zs[None, None, :]).astype(np.float32)

    def eval_points(self, p):
        return self.f(p[:, 0], p[:, 1], p[:, 2])

    def leaves(self):
        return [self]


class Ellipsoid(Leaf):
    def __init__(self, name, c, r, bones=None, sigma=0.012, rot=None):
        c = np.array(c, np.float64)
        r = np.array(r, np.float64)
        m = float(max(r))
        super().__init__(name, c - m, c + m, bones, sigma)
        self.c, self.r = c, r
        self.rot = None if rot is None else np.array(rot, np.float64)

    def f(self, x, y, z):
        dx, dy, dz = x - self.c[0], y - self.c[1], z - self.c[2]
        if self.rot is not None:
            r = self.rot  # Spalten = lokale Achsen
            dx, dy, dz = (r[0, 0] * dx + r[1, 0] * dy + r[2, 0] * dz,
                          r[0, 1] * dx + r[1, 1] * dy + r[2, 1] * dz,
                          r[0, 2] * dx + r[1, 2] * dy + r[2, 2] * dz)
        rx, ry, rz = self.r
        k0 = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2 + (dz / rz) ** 2)
        k1 = np.sqrt((dx / (rx * rx)) ** 2 + (dy / (ry * ry)) ** 2 + (dz / (rz * rz)) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


class RoundCone(Leaf):
    """Runder Kegel (Kapsel mit zwei Radien) von a (Radius ra) nach b (Radius rb)."""

    def __init__(self, name, a, b, ra, rb, bones=None, sigma=0.012):
        a = np.array(a, np.float64)
        b = np.array(b, np.float64)
        lo = np.minimum(a - ra, b - rb)
        hi = np.maximum(a + ra, b + rb)
        super().__init__(name, lo, hi, bones, sigma)
        self.a, self.b, self.ra, self.rb = a, b, float(ra), float(rb)

    def f(self, x, y, z):
        a, b, r1, r2 = self.a, self.b, self.ra, self.rb
        ba = b - a
        l2 = float(ba @ ba)
        rr = r1 - r2
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pax, pay, paz = x - a[0], y - a[1], z - a[2]
        yy = pax * ba[0] + pay * ba[1] + paz * ba[2]
        zz = yy - l2
        qx, qy, qz = pax * l2 - ba[0] * yy, pay * l2 - ba[1] * yy, paz * l2 - ba[2] * yy
        x2 = qx * qx + qy * qy + qz * qz
        y2 = yy * yy * l2
        z2 = zz * zz * l2
        k = math.copysign(1.0, rr) * rr * rr * x2 if rr != 0 else 0.0 * x2
        d_end = np.sqrt(x2 + z2) * il2 - r2
        d_start = np.sqrt(x2 + y2) * il2 - r1
        d_side = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + yy * rr) * il2 - r1
        use_end = np.sign(zz) * a2 * z2 > k
        use_start = np.sign(yy) * a2 * y2 < k
        return np.where(use_end, d_end, np.where(use_start, d_start, d_side))


class Func(Leaf):
    """Beliebige Funktion f(x, y, z) (z. B. Schnittflächen für Kleidung)."""

    def __init__(self, name, fn, lo=(-9, -9, -9), hi=(9, 9, 9)):
        super().__init__(name, lo, hi, None)
        self.fn = fn

    def f(self, x, y, z):
        return self.fn(x, y, z)


class Offset(Leaf):
    """Ein anderes Feld um t (Zahl oder Funktion von x, y, z) aufgeblasen."""

    def __init__(self, child, t):
        tm = t if not callable(t) else 0.02
        super().__init__("offset", child.lo - tm, child.hi + tm, None)
        self.child, self.t = child, t

    def _t(self, x, y, z):
        return self.t(x, y, z) if callable(self.t) else self.t

    def eval_grid(self, xs, ys, zs):
        d = self.child.eval_grid(xs, ys, zs)
        return (d - self._t(xs[:, None, None], ys[None, :, None], zs[None, None, :])).astype(np.float32)

    def eval_points(self, p):
        return self.child.eval_points(p) - self._t(p[:, 0], p[:, 1], p[:, 2])

    def leaves(self):
        return []


class Group:
    """Verknüpft Kinder nacheinander: ("union", Knoten, k), ("subtract", …), ("intersect", …)."""

    def __init__(self, name, items):
        self.name = name
        self.items = items
        los = [n.lo - k for op, n, k in items if op == "union"]
        his = [n.hi + k for op, n, k in items if op == "union"]
        self.lo = np.min(los, axis=0)
        self.hi = np.max(his, axis=0)

    def leaves(self):
        out = []
        for op, n, k in self.items:
            if op == "union":
                out += n.leaves()
        return out

    def eval_grid(self, xs, ys, zs):
        out = np.full((len(xs), len(ys), len(zs)), BIG, np.float32)
        for op, node, k in self.items:
            lo = node.lo - PAD
            hi = node.hi + PAD
            i0, i1 = np.searchsorted(xs, lo[0]), np.searchsorted(xs, hi[0], "right")
            j0, j1 = np.searchsorted(ys, lo[1]), np.searchsorted(ys, hi[1], "right")
            l0, l1 = np.searchsorted(zs, lo[2]), np.searchsorted(zs, hi[2], "right")
            if op == "intersect":
                # außerhalb des Bereichs bleibt nichts übrig
                mask = np.ones(out.shape, bool)
                mask[i0:i1, j0:j1, l0:l1] = False
                out[mask] = BIG
            if i1 <= i0 or j1 <= j0 or l1 <= l0:
                continue
            sub = node.eval_grid(xs[i0:i1], ys[j0:j1], zs[l0:l1])
            reg = out[i0:i1, j0:j1, l0:l1]
            if op == "union":
                reg[...] = smin(reg, sub, k)
            elif op == "subtract":
                reg[...] = smax(reg, -sub, k)
            else:
                reg[...] = smax(reg, sub, k)
        return out

    def eval_points(self, p):
        out = np.full(len(p), 1.0)
        for op, node, k in self.items:
            lo = node.lo - PAD
            hi = node.hi + PAD
            m = np.all((p >= lo) & (p <= hi), axis=1)
            if op == "intersect":
                out[~m] = 1.0
            if not m.any():
                continue
            sub = node.eval_points(p[m])
            if op == "union":
                out[m] = smin(out[m], sub, k)
            elif op == "subtract":
                out[m] = smax(out[m], -sub, k)
            else:
                out[m] = smax(out[m], sub, k)
        return out


def gradient(node, p, eps=0.0004):
    g = np.zeros_like(p)
    for i in range(3):
        e = np.zeros(3)
        e[i] = eps
        g[:, i] = (node.eval_points(p + e) - node.eval_points(p - e)) / (2 * eps)
    return g


def project(node, p, iterations=6):
    """Punkte auf die Oberfläche (Feld = 0) schieben (Newton entlang des Gradienten)."""
    p = p.astype(np.float64).copy()
    for _ in range(iterations):
        d = node.eval_points(p)
        g = gradient(node, p)
        gg = np.maximum((g * g).sum(axis=1), 1e-6)
        step = (d / gg)[:, None] * g
        # große Sprünge begrenzen (Formregler mit viel Unterschied)
        n = np.linalg.norm(step, axis=1)
        step *= np.minimum(1.0, 0.03 / np.maximum(n, 1e-9))[:, None]
        p -= step
    return p


def normals(node, p):
    g = gradient(node, p)
    return g / np.maximum(np.linalg.norm(g, axis=1), 1e-9)[:, None]


# ---------------------------------------------------------------------------------------------
# Netz aus dem Feld (Surface Nets)
# ---------------------------------------------------------------------------------------------

def surface_nets(node, lo, hi, h, symmetric_x=True):
    """Liefert Ecken (N, 3) und Vierecke (Q, 4) der Oberfläche des Feldes im Kasten lo..hi."""
    if symmetric_x:
        n = int(math.ceil(max(abs(lo[0]), abs(hi[0])) / h)) + 2
        xs = ((np.arange(-n, n) + 0.5) * h).astype(np.float32)
    else:
        xs = np.arange(lo[0] - 2 * h, hi[0] + 2 * h, h, dtype=np.float32)
    ys = np.arange(lo[1] - 2 * h, hi[1] + 2 * h, h, dtype=np.float32)
    zs = np.arange(lo[2] - 2 * h, hi[2] + 2 * h, h, dtype=np.float32)
    d = node.eval_grid(xs, ys, zs)
    inside = d < 0
    nx, ny, nz = d.shape
    # aktive Zellen: Ecken teils innen, teils außen
    cnt = np.zeros((nx - 1, ny - 1, nz - 1), np.uint8)
    for a in (0, 1):
        for b in (0, 1):
            for c in (0, 1):
                cnt += inside[a:nx - 1 + a, b:ny - 1 + b, c:nz - 1 + c]
    active = (cnt > 0) & (cnt < 8)
    del cnt
    ci, cj, ck = np.nonzero(active)
    del active
    lin = (ci.astype(np.int64) * (ny - 1) + cj) * (nz - 1) + ck
    # Ecke je Zelle = Mittel der Kantendurchgänge
    acc = np.zeros((len(ci), 3))
    num = np.zeros(len(ci))
    corners = [(a, b, c) for a in (0, 1) for b in (0, 1) for c in (0, 1)]
    for (a0, b0, c0) in corners:
        for axis in range(3):
            o1 = [a0, b0, c0]
            if o1[axis] == 1:
                continue
            o2 = list(o1)
            o2[axis] = 1
            d0 = d[ci + o1[0], cj + o1[1], ck + o1[2]]
            d1 = d[ci + o2[0], cj + o2[1], ck + o2[2]]
            m = (d0 < 0) != (d1 < 0)
            t = np.where(m, d0 / np.where(m, d0 - d1, 1.0), 0.0)
            px = xs[ci] + h * (o1[0] + (t if axis == 0 else 0.0))
            py = ys[cj] + h * (o1[1] + (t if axis == 1 else 0.0))
            pz = zs[ck] + h * (o1[2] + (t if axis == 2 else 0.0))
            acc[m, 0] += px[m]
            acc[m, 1] += py[m]
            acc[m, 2] += pz[m]
            num += m
    verts = acc / np.maximum(num, 1)[:, None]
    # Vierecke: je Gitterkante mit Vorzeichenwechsel die vier Zellen drumherum
    quads = []
    shape = (nx, ny, nz)
    for axis in range(3):
        b_ax, c_ax = (axis + 1) % 3, (axis + 2) % 3
        sl0 = [slice(None)] * 3
        sl1 = [slice(None)] * 3
        sl0[axis] = slice(0, shape[axis] - 1)
        sl1[axis] = slice(1, shape[axis])
        cross = inside[tuple(sl0)] != inside[tuple(sl1)]
        idx = np.nonzero(cross)
        first_inside = inside[tuple(sl0)][idx]
        idx = [i.astype(np.int64) for i in idx]
        ok = (idx[b_ax] >= 1) & (idx[c_ax] >= 1) & (idx[b_ax] < shape[b_ax] - 1) & (idx[c_ax] < shape[c_ax] - 1)
        idx = [i[ok] for i in idx]
        first_inside = first_inside[ok]
        ring = []
        for ob, oc in ((-1, -1), (0, -1), (0, 0), (-1, 0)):
            cell = list(idx)
            cell[b_ax] = cell[b_ax] + ob
            cell[c_ax] = cell[c_ax] + oc
            key = (cell[0] * (ny - 1) + cell[1]) * (nz - 1) + cell[2]
            ring.append(np.searchsorted(lin, key))
        q = np.stack(ring, axis=1)
        # Außenseite zeigt nach +axis, wenn das erste Ende innen liegt
        q[~first_inside] = q[~first_inside][:, ::-1]
        quads.append(q)
    return verts, np.concatenate(quads)


# ---------------------------------------------------------------------------------------------
# Gewichte und Verschattung
# ---------------------------------------------------------------------------------------------

def spine_weights(z, spine):
    """Rumpf-Formen: Gewicht über die Wirbelsäule verteilt (spine = [(Knochen, z), …] aufsteigend)."""
    out = {}
    names = [s[0] for s in spine]
    zs = np.array([s[1] for s in spine])
    for i, name in enumerate(names):
        w = np.zeros_like(z)
        if i == 0:
            w = np.where(z <= zs[0], 1.0, w)
        if i == len(names) - 1:
            w = np.where(z >= zs[-1], 1.0, w)
        if i > 0:
            t = (z - zs[i - 1]) / (zs[i] - zs[i - 1])
            w = np.where((z > zs[i - 1]) & (z <= zs[i]), t, w)
        if i < len(names) - 1:
            t = (zs[i + 1] - z) / (zs[i + 1] - zs[i])
            w = np.where((z > zs[i]) & (z < zs[i + 1]), t, w)
        out[name] = w
    return out


def skin_weights(root, p, spine, max_influences=4):
    """Gewichte je Ecke: Jede Grundform zieht ihre Knochen an, je näher, desto stärker."""
    leaves = [lf for lf in root.leaves() if lf.bones]
    ds = np.stack([lf.eval_points(p) for lf in leaves], axis=1)
    dmin = ds.min(axis=1, keepdims=True)
    sig = np.array([lf.sigma for lf in leaves])[None, :]
    infl = np.exp(-np.clip((ds - dmin) / sig, 0.0, 30.0))
    weights = {}
    for i, lf in enumerate(leaves):
        for bone, share in lf.bones.items():
            if bone == "spine":
                for name, w in spine_weights(p[:, 2], spine).items():
                    weights[name] = weights.get(name, 0.0) + infl[:, i] * share * w
            else:
                weights[bone] = weights.get(bone, 0.0) + infl[:, i] * share
    names = list(weights)
    w = np.stack([np.broadcast_to(weights[n], (len(p),)) for n in names], axis=1)
    # nur die stärksten behalten
    order = np.argsort(-w, axis=1)[:, :max_influences]
    keep = np.zeros_like(w, bool)
    np.put_along_axis(keep, order, True, axis=1)
    w = np.where(keep & (w > 0.01 * w.max(axis=1, keepdims=True)), w, 0.0)
    w /= np.maximum(w.sum(axis=1, keepdims=True), 1e-9)
    return names, w


def ambient_occlusion(root, p, n, steps=(0.006, 0.014, 0.028, 0.05), strength=1.0):
    """Wie viel Platz ist vor der Oberfläche? Wenig Platz (Achsel, Bauchnabel) = dunkler."""
    occ = np.zeros(len(p))
    total = 0.0
    for i, s in enumerate(steps):
        d = root.eval_points(p + n * s)
        w = 1.0 / (i + 1)
        occ += w * np.clip((s - d) / s, 0.0, 1.0)
        total += w
    return np.clip(1.0 - strength * occ / total, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------
# Der Körper
# ---------------------------------------------------------------------------------------------

def _rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])


def _rot_y(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0.0, math.sin(a)], [0.0, 1.0, 0.0], [-math.sin(a), 0.0, math.cos(a)]])


def transform(node, rot, origin):
    """Teilbaum drehen (um origin): für die Arme in A-Pose."""
    origin = np.asarray(origin, float)
    if isinstance(node, Group):
        for _op, child, _k in node.items:
            transform(child, rot, origin)
        los = [n.lo - k for op, n, k in node.items if op == "union"]
        his = [n.hi + k for op, n, k in node.items if op == "union"]
        node.lo, node.hi = np.min(los, axis=0), np.max(his, axis=0)
    elif isinstance(node, Ellipsoid):
        node.c = origin + rot @ (node.c - origin)
        node.rot = rot if node.rot is None else rot @ node.rot
        m = float(max(node.r))
        node.lo, node.hi = node.c - m, node.c + m
    elif isinstance(node, RoundCone):
        node.a = origin + rot @ (node.a - origin)
        node.b = origin + rot @ (node.b - origin)
        node.lo = np.minimum(node.a - node.ra, node.b - node.rb)
        node.hi = np.maximum(node.a + node.ra, node.b + node.rb)


def head_group(chin, with_nose=True):
    """Kopf: für alle Figuren gleich (Haare und Hüte passen allen). Kinn auf Höhe chin.
    Gebaut für 0,41 m und auf HEAD_HEIGHT vergrößert."""
    k = HEAD_HEIGHT / 0.41
    hb = {"Head": 1.0}

    def P(x, y, z):
        return (x * k, y * k, chin + z * k)

    def R(*r):
        return tuple(v * k for v in r)

    items = [
        ("union", Ellipsoid("cranium", P(0, 0.012, 0.232), R(0.204, 0.184, 0.178), hb, 0.01), 0.0),
        ("union", Ellipsoid("jaw", P(0, -0.004, 0.122), R(0.168, 0.142, 0.122), hb, 0.01), 0.075 * k),
        ("union", Ellipsoid("cheek_l", P(0.074, -0.060, 0.100), R(0.072, 0.062, 0.066), hb, 0.01), 0.07 * k),
        ("union", Ellipsoid("cheek_r", P(-0.074, -0.060, 0.100), R(0.072, 0.062, 0.066), hb, 0.01), 0.07 * k),
    ]
    for s in (1, -1):
        side = "l" if s > 0 else "r"
        # Ohr: runde Scheibe, schräg nach vorn gedreht (von vorn als Halbkreis zu sehen), vorn
        # eine flache Mulde
        a = math.radians(EAR_TURN)
        n = np.array((s * math.cos(a), -math.sin(a), 0.0))
        ear_c = np.array(P(s * 0.204, 0.022, 0.138))
        ear = Ellipsoid("ear_" + side, ear_c, R(0.017, 0.035, 0.044), hb, 0.006, rot=_rot_z(-s * EAR_TURN))
        cup = Ellipsoid("ear_cup_" + side, ear_c + n * 0.0195 * k + np.array((0, 0, 0.002 * k)),
                        R(0.0068, 0.022, 0.029), None, rot=_rot_z(-s * EAR_TURN))
        items.append(("union", ear, 0.016 * k))
        items.append(("subtract", cup, 0.006 * k))
    if with_nose:
        # kleine Knopfnase: sitzt auf der Gesichtsfläche
        z = chin + NOSE_Z
        y = surface_y(head_group(chin, False), z)
        items.append(("union", Ellipsoid("nose", (0.0, y + 0.0035, z), (0.0135, 0.0095, 0.0105), hb, 0.006), 0.012))
    return Group("head", items)


# Maße je Geschlecht (mittlere Größe, mittlere Form). Längen in m; Höhen im Rumpf als Anteil
# von T (Halsansatz bis Schritt). thin/fat: Faktoren für die Breiten.
DIMS = {
    "female": dict(
        crotch=0.493,          # Schritthöhe als Anteil der Kinnhöhe
        shoulder=(0.118, 0.875),
        chest=(0.127, 0.104, 0.28), bust=(0.056, -0.072, 0.72, 0.050, 0.047, 0.045),
        waist=(0.106, 0.088, 0.26), belly=(0.07, 0.060, 0.08), pelvis=(0.160, 0.104, 0.22),
        butt=(0.072, 0.074, 0.080), neck=0.046,
        arm=(0.043, 0.038, 0.033), upper_arm=0.20, fore_arm=0.172, hand=1.0,
        hip_x=0.086, thigh=0.079, knee=0.059, calf=0.055, ankle=0.044, foot=1.0),
    "male": dict(
        crotch=0.49,
        shoulder=(0.134, 0.875),
        chest=(0.140, 0.104, 0.30), bust=None,
        waist=(0.126, 0.094, 0.26), belly=(0.08, 0.064, 0.09), pelvis=(0.140, 0.098, 0.21),
        butt=(0.062, 0.058, 0.068), neck=0.050,
        arm=(0.047, 0.042, 0.036), upper_arm=0.21, fore_arm=0.182, hand=1.08,
        hip_x=0.088, thigh=0.076, knee=0.060, calf=0.058, ankle=0.047, foot=1.08),
}
# Faktoren je Form: (dünn, dick) für Rumpfbreite, Bauch, Arme, Beine, Hals, Po
SHAPE_FACTORS = {
    "torso": (0.9, 1.16), "belly": (0.6, 2.1), "arm": (0.87, 1.22), "leg": (0.86, 1.2),
    "neck": (0.93, 1.12), "butt": (0.88, 1.2), "bust": (0.88, 1.15),
}


class Body:
    """Maße, Skelett und Feld einer Figur (gender, height = small/medium/tall, shape)."""

    def __init__(self, gender, height, shape="medium", navel=True):
        """navel=False: ohne Bauchnabel (glatte Form für die Formregler)."""
        self.gender, self.height_class, self.shape = gender, height, shape
        self.with_navel = navel
        self.D = D = DIMS[gender]
        self.H = HEIGHTS[gender][height]
        self.chin = self.H - HEAD_HEIGHT
        self.crotch = D["crotch"] * self.chin
        self.neck_base = self.chin - 0.045
        self.T = self.neck_base - self.crotch
        f = {"thin": -1.0, "medium": 0.0, "fat": 1.0}[shape]

        def fac(part):
            thin, fat = SHAPE_FACTORS[part]
            return 1.0 + (fat - 1.0) * f if f >= 0 else 1.0 + (1.0 - thin) * f

        self.fac = fac
        cr, T = self.crotch, self.T
        # Längen wachsen mit der Körpergröße (gegenüber der mittleren Größe)
        mid = HEIGHTS[gender]["medium"] - HEAD_HEIGHT
        self.len_scale = self.chin / mid
        self.shoulder_x, sfrac = D["shoulder"]
        self.shoulder_z = cr + sfrac * T
        self.upper_arm = D["upper_arm"] * self.len_scale
        self.fore_arm = D["fore_arm"] * self.len_scale
        self.hand_scale = D["hand"]
        self.hip_x = D["hip_x"]
        self.hip_z = cr + 0.06
        self.knee_z = 0.565 * cr
        self.ankle_z = 0.084
        self.foot_scale = D["foot"]
        self.spine = [("Hips", cr + 0.10 * T), ("Spine", cr + 0.40 * T), ("Chest", cr + 0.62 * T),
                      ("UpperChest", cr + 0.82 * T)]
        self.root = self._build()

    # --- Feld ---------------------------------------------------------------------------
    def _build(self):
        D, fac = self.D, self.fac
        fem = self.gender == "female"
        cr, T, nb = self.crotch, self.T, self.neck_base
        sp = {"spine": 1.0}
        ft, fb = fac("torso"), fac("belly")
        cx, cy, cz = D["chest"]
        wx, wy, wz = D["waist"]
        bx, by, bz = D["belly"]
        px, py, pz = D["pelvis"]
        torso = [
            # Brustkorb etwas nach vorn: aufrechte Haltung mit geschwungenem Rücken
            ("union", Ellipsoid("chest", (0, -0.004, cr + 0.70 * T), (cx * ft, cy * ft, cz * T), sp), 0.0),
            ("union", Ellipsoid("waist", (0, 0.0, cr + 0.42 * T), (wx * ft, wy * ft, wz * T), sp), 0.10),
            ("union", Ellipsoid("belly", (0, -0.022 - 0.022 * max(fb - 1, 0), cr + 0.34 * T - 0.01 * max(fb - 1, 0)),
                                (bx * min(fb, 1.0) ** 0.5 * max(fb, 1) ** 0.6, by * fb, bz * max(fb, 1) ** 0.5), sp), 0.07),
            ("union", Ellipsoid("pelvis", (0, 0.018, cr + 0.17 * T), (px * ft ** 0.8, py * ft, pz * T), sp), 0.09),
        ]
        for s in (1, -1):
            side = "Left" if s > 0 else "Right"
            u = fac("butt")
            b = D["butt"]
            torso.append(("union", Ellipsoid("butt_" + side, (s * 0.054, 0.060, cr + 0.065),
                                             (b[0] * u, b[1] * u, b[2] * u),
                                             {"Hips": 0.6, side + "UpperLeg": 0.4}), 0.05))
            if D["bust"]:
                bx_, by_, bz_, rx, ry, rz = D["bust"]
                q = fac("bust")
                torso.append(("union", Ellipsoid("breast_" + side, (s * bx_, by_ * q - 0.012, cr + bz_ * T),
                                                 (rx * q, ry * q, rz * q), {"UpperChest": 1.0}), 0.04))
            # weiche Schulter: vom Nacken über eine runde Schulterkuppe zum Arm
            sz, sx = self.shoulder_z, self.shoulder_x
            # Schulterlinie: vom Hals weich nach außen abfallend (keine Schulterkugel)
            torso.append(("union", RoundCone("trap_" + side, (0, 0.012, nb - 0.028), (s * (sx - 0.012), 0.010, sz - 0.008),
                                             0.036 * ft, 0.042 * ft,
                                             {"UpperChest": 0.5, side + "Shoulder": 0.5}), 0.06))
        if not fem:
            # breite, flache Brust (keine Muskeln)
            torso.append(("union", Ellipsoid("chest_front", (0, -0.028, cr + 0.72 * T),
                                             (0.125 * ft, 0.064 * ft, 0.10), sp), 0.08))
        body = Group("torso", torso)
        nr = D["neck"] * fac("neck")
        neck = RoundCone("neck", (0, 0.024, self.chin + 0.07), (0, 0.014, nb - 0.02), nr, nr * 1.1,
                         {"Neck": 1.0}, 0.01)
        items = [("union", body, 0.0), ("union", neck, 0.04)]
        for s in (1, -1):
            items.append(("union", self._arm(s), 0.075))
        legs = Group("legs", [("union", self._leg(1), 0.0), ("union", self._leg(-1), 0.008)])
        items.append(("union", legs, 0.05))
        items.append(("union", head_group(self.chin), 0.025))
        # Bauchnabel: kleine Mulde vorn
        nav_z = cr + 0.37 * T
        ny = surface_y(Group("body0", items), nav_z)
        if self.with_navel:
            items.append(("subtract", Ellipsoid("navel", (0, ny + 0.0035, nav_z), (0.0058, 0.0062, 0.009)), 0.004))
        # flache Fußsohlen
        items.append(("intersect", Func("floor", lambda x, y, z: -z + 0 * x + 0 * y), 0.006))
        self.navel = (0.0, ny, nav_z)
        return Group("body", items)

    def _arm(self, s):
        """Arm, zuerst waagerecht gebaut (T-Pose) und dann um ARM_REST Grad nach unten gedreht."""
        D, fac = self.D, self.fac
        side = "Left" if s > 0 else "Right"
        sz, sx = self.shoulder_z, self.shoulder_x
        y0 = 0.012
        elbow_x = sx + self.upper_arm
        wrist_x = elbow_x + self.fore_arm
        fa = fac("arm")
        # dicker/dünner vor allem am Oberarm, zum Handgelenk hin immer weniger (kein Überquellen)
        r_up = D["arm"][0] * fa
        r_el = D["arm"][1] * (1 + (fa - 1) * 0.6)
        r_wr = D["arm"][2] * (1 + (fa - 1) * 0.25)
        items = [
            ("union", RoundCone("upperarm_" + side, (s * sx, y0, sz), (s * elbow_x, y0, sz), r_up, r_el,
                                {side + "UpperArm": 1.0}, 0.012), 0.0),
            ("union", RoundCone("forearm_" + side, (s * elbow_x, y0, sz), (s * wrist_x, y0, sz), r_el, r_wr,
                                {side + "LowerArm": 1.0}, 0.012), 0.012),
        ]
        hand, hj = self._hand(s, (s * wrist_x, y0, sz))
        # weicher Übergang vom Unterarm in die Hand
        items.append(("union", hand, 0.03))
        group = Group("arm_" + side, items)
        rot = _rot_y(s * ARM_REST)
        origin = np.array((s * sx, y0, sz))
        transform(group, rot, origin)

        def tp(p):
            return tuple(origin + rot @ (np.asarray(p, float) - origin))

        self.joints_arm = getattr(self, "joints_arm", {})
        self.joints_arm[side] = {"shoulder": tp((s * sx, y0, sz)), "elbow": tp((s * elbow_x, y0, sz)),
                                 "wrist": tp((s * wrist_x, y0, sz)),
                                 "hand": {k: [tp(p) for p in v] for k, v in hj.items()}}
        return group

    def _hand(self, s, wrist):
        """Hand in T-Pose: Handfläche nach unten, Finger entlang ±x, Daumen nach vorn (-y)."""
        side = "Left" if s > 0 else "Right"
        k = self.hand_scale * (1 + (self.fac("arm") - 1) * 0.2)
        wx, wy, wz = wrist
        hb = side + "Hand"
        items = [("union", Ellipsoid("palm_" + side, (wx + s * 0.034 * k, wy + 0.001, wz - 0.002),
                                     (0.041 * k, 0.034 * k, 0.021 * k), {hb: 1.0}, 0.008), 0.0)]
        joints = {}
        fingers = (("Index", -0.0222, 0.044, -3.0), ("Middle", -0.0072, 0.048, -1.0),
                   ("Ring", 0.0076, 0.045, 1.0), ("Little", 0.0218, 0.036, 3.5))
        for name, off, length, spread in fingers:
            base = np.array((wx + s * 0.061 * k, wy + off * k, wz - 0.001))
            a = math.radians(spread)
            d = np.array((s * math.cos(a), math.sin(a), -0.04))
            d /= np.linalg.norm(d)
            seg = (0.44, 0.31, 0.25)
            pts = [base]
            for fr in seg:
                pts.append(pts[-1] + d * length * k * fr)
            r0, r1 = 0.0090 * k, 0.0080 * k
            bones = ("Proximal", "Intermediate", "Distal")
            for i in range(3):
                ra = r0 + (r1 - r0) * i / 3.0
                rb = r0 + (r1 - r0) * (i + 1) / 3.0
                items.append(("union", RoundCone(f"{side}{name}{bones[i]}", pts[i], pts[i + 1], ra, rb,
                                                 {f"{side}{name}{bones[i]}": 1.0}, 0.004),
                              0.012 if i == 0 else 0.004))
            joints[name] = [tuple(p) for p in pts]
        # Daumen: von der Handwurzel nach vorn und außen
        t0 = np.array((wx + s * 0.012 * k, wy - 0.019 * k, wz - 0.005))
        t1 = t0 + np.array((s * 0.025, -0.021, -0.004)) * k
        t2 = t1 + np.array((s * 0.019, -0.011, -0.002)) * k
        t3 = t2 + np.array((s * 0.016, -0.006, 0.0)) * k
        tp = [t0, t1, t2, t3]
        rad = (0.0125 * k, 0.0105 * k, 0.0095 * k, 0.0085 * k)
        tb = ("Metacarpal", "Proximal", "Distal")
        for i in range(3):
            items.append(("union", RoundCone(f"{side}Thumb{tb[i]}", tp[i], tp[i + 1], rad[i], rad[i + 1],
                                             {f"{side}Thumb{tb[i]}": 1.0} if i > 0 else
                                             {f"{side}Thumb{tb[i]}": 0.7, hb: 0.3}, 0.005),
                          0.014 if i == 0 else 0.004))
        joints["Thumb"] = [tuple(p) for p in tp]
        return Group("hand_" + side, items), joints

    def _leg(self, s):
        D, fac = self.D, self.fac
        side = "Left" if s > 0 else "Right"
        hx, hz = s * self.hip_x, self.hip_z
        kx, kz = s * (self.hip_x - 0.002), self.knee_z
        ax, az = s * (self.hip_x - 0.004), self.ankle_z
        fl = fac("leg")
        r_th = D["thigh"] * fl
        r_kn = D["knee"] * (1 + (fl - 1) * 0.75)
        r_ca = D["calf"] * (1 + (fl - 1) * 0.75)
        r_an = D["ankle"] * (1 + (fl - 1) * 0.4)
        fs = self.foot_scale
        # Oberschenkel: oben am Schritt am dicksten (Mitte etwas unter dem Hüftgelenk)
        th_top = (hx, 0.010, hz - 0.05)
        items = [
            ("union", RoundCone("thigh_" + side, (hx, 0.010, hz), (kx, 0.004, kz), r_th * 0.96, r_kn,
                                {side + "UpperLeg": 1.0}, 0.014), 0.0),
            ("union", Ellipsoid("thigh_top_" + side, th_top, (r_th, r_th * 1.08, (hz - kz) * 0.42),
                                {side + "UpperLeg": 1.0}, 0.014), 0.03),
            ("union", RoundCone("shin_" + side, (kx, 0.004, kz), (ax, 0.012, az), r_kn, r_an,
                                {side + "LowerLeg": 1.0}, 0.012), 0.012),
            ("union", Ellipsoid("calf_" + side, (kx, 0.012, kz - 0.32 * (kz - az)),
                                (r_ca * 0.97, r_ca * 1.02, (kz - az) * 0.45), {side + "LowerLeg": 1.0}, 0.012), 0.05),
            ("union", Ellipsoid("foot_" + side, (ax + s * 0.004, -0.022 * fs, 0.042 * fs),
                                (0.052 * fs, 0.084 * fs, 0.044 * fs), {side + "Foot": 1.0}, 0.012), 0.035),
            ("union", Ellipsoid("toes_" + side, (ax + s * 0.006, -0.070 * fs, 0.034 * fs),
                                (0.053 * fs, 0.050 * fs, 0.034 * fs), {side + "Toes": 0.7, side + "Foot": 0.3}, 0.012),
             0.03),
        ]
        self.joints_leg = getattr(self, "joints_leg", {})
        self.joints_leg[side] = {"hip": (hx, 0.010, hz), "knee": (kx, 0.004, kz), "ankle": (ax, 0.012, az),
                                 "ball": (ax + s * 0.004, -0.064 * fs, 0.03), "toe": (ax + s * 0.006, -0.12 * fs, 0.03)}
        return Group("leg_" + side, items)

    # --- Skelett --------------------------------------------------------------------------
    def bones(self):
        """[(Name, Kopf, Ende, Eltern)] – Namen wie Godots SkeletonProfileHumanoid."""
        cr, T = self.crotch, self.T
        out = [
            ("Hips", (0, 0.014, cr + 0.17 * T), (0, 0.016, cr + 0.33 * T), None),
            ("Spine", (0, 0.016, cr + 0.33 * T), (0, 0.018, cr + 0.55 * T), "Hips"),
            ("Chest", (0, 0.018, cr + 0.55 * T), (0, 0.018, cr + 0.74 * T), "Spine"),
            ("UpperChest", (0, 0.018, cr + 0.74 * T), (0, 0.018, self.neck_base - 0.01), "Chest"),
            ("Neck", (0, 0.018, self.neck_base - 0.01), (0, 0.024, self.chin + 0.035), "UpperChest"),
            ("Head", (0, 0.024, self.chin + 0.035), (0, 0.024, self.chin + 0.33), "Neck"),
        ]
        for side, s in (("Left", 1), ("Right", -1)):
            a = self.joints_arm[side]
            out.append((side + "Shoulder", (s * 0.03, 0.016, self.shoulder_z + 0.012), a["shoulder"], "UpperChest"))
            out.append((side + "UpperArm", a["shoulder"], a["elbow"], side + "Shoulder"))
            out.append((side + "LowerArm", a["elbow"], a["wrist"], side + "UpperArm"))
            out.append((side + "Hand", a["wrist"], a["hand"]["Middle"][0], side + "LowerArm"))
            for fname in ("Thumb", "Index", "Middle", "Ring", "Little"):
                pts = a["hand"][fname]
                names = ("Metacarpal", "Proximal", "Distal") if fname == "Thumb" else ("Proximal", "Intermediate", "Distal")
                parent = side + "Hand"
                for i, n in enumerate(names):
                    out.append((f"{side}{fname}{n}", pts[i], pts[i + 1], parent))
                    parent = f"{side}{fname}{n}"
            lg = self.joints_leg[side]
            out.append((side + "UpperLeg", lg["hip"], lg["knee"], "Hips"))
            out.append((side + "LowerLeg", lg["knee"], lg["ankle"], side + "UpperLeg"))
            out.append((side + "Foot", lg["ankle"], lg["ball"], side + "LowerLeg"))
            out.append((side + "Toes", lg["ball"], lg["toe"], side + "Foot"))
        return out

    def bounds(self):
        lo, hi = self.root.lo.copy(), self.root.hi.copy()
        lo[2] = -0.01
        hi[2] = self.H + 0.01
        return lo + np.array((-0.01, -0.01, 0.0)), hi + np.array((0.01, 0.01, 0.0))

    # --- Kleidung -------------------------------------------------------------------------
    def cloth(self, kind):
        """Unterwäsche als Feld: Körper um die Stoffdicke aufgeblasen, mit Schnittflächen begrenzt."""
        cr, T = self.crotch, self.T
        body = self.root
        if kind == "bandeau":
            top = cr + 0.80 * T
            bottom = cr + 0.585 * T

            def t(x, y, z):
                # Saum oben und unten etwas dicker
                edge = np.minimum(np.abs(z - top), np.abs(z - bottom))
                return 0.0032 + 0.0012 * np.clip(1.0 - edge / 0.008, 0.0, 1.0)

            def region(x, y, z):
                # nur am Rumpf (nicht an den Armen)
                return np.maximum(np.maximum(z - top, bottom - z), np.abs(x) - 0.165 + 0 * y)

            lo, hi = (-0.2, -0.2, bottom - 0.02), (0.2, 0.2, top + 0.02)
        else:
            fem = self.gender == "female"
            waist = cr + (0.30 if fem else 0.32) * T
            if fem:
                # Slip/Panty: Beinausschnitt schräg, außen höher
                inner = np.array((0.0, cr - 0.012))
                outer = np.array((0.18, cr + 0.13 * T))
            else:
                # Boxershorts: kurzes Bein, fast waagerecht
                inner = np.array((0.0, cr - 0.09))
                outer = np.array((0.18, cr - 0.068))
            dx, dz = outer - inner
            n = np.array((dz, -dx)) / math.hypot(dx, dz)  # zeigt nach unten-außen

            def t(x, y, z):
                band = np.clip(1.0 - np.abs(z - waist) / 0.018, 0.0, 1.0)
                return 0.0034 + 0.0016 * band

            def region(x, y, z):
                leg = (np.abs(x) - inner[0]) * n[0] + (z - inner[1]) * n[1]
                # Arme (A-Pose) hängen neben der Hüfte: nur bis zur Hüftbreite
                return np.maximum(np.maximum(z - waist, leg), np.abs(x) - 0.24 + 0 * y)

            lo, hi = (-0.24, -0.2, cr - 0.14), (0.24, 0.2, waist + 0.02)
        node = Group(kind, [("union", Offset(body, t), 0.0),
                            ("intersect", Func("region", region, lo, hi), 0.0025)])
        node.lo = np.maximum(node.lo, np.array(lo))
        node.hi = np.minimum(node.hi, np.array(hi))
        return node


def surface_y(node, z, x=0.0):
    """y der Vorderseite (kleinstes y mit Feld = 0) auf der Linie (x, ·, z)."""
    ys = np.linspace(-0.3, 0.1, 801)
    p = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], axis=1)
    d = node.eval_points(p)
    i = int(np.argmax(d < 0))
    if i == 0:
        return 0.0
    y0, y1, d0, d1 = ys[i - 1], ys[i], d[i - 1], d[i]
    return float(y0 + (y1 - y0) * d0 / (d0 - d1))
