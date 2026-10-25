"""Form der Chibi-Figuren (seit Etappe 5c) als Abstandsfeld: Der Körper ist eine weiche Vereinigung
von Grundformen (Ellipsoide, runde Kegel, abgerundete Kästen), wie eine Vinyl-Figur. Das Feld legt
nur die Form fest; das Netz baut chibi_cage (Vierecke mit Ringen um die Gelenke), es wird nach
dem Glätten genau auf die Oberfläche dieses Feldes gelegt.

Wichtig für eine saubere Oberfläche: Teile in einer Linie (Ober- und Unterarm, Ober- und
Unterschenkel, Fingerglieder) werden hart vereinigt – eine weiche Vereinigung bläht die Stelle auf
(früher Beulen an Ellbogen und Handgelenk). Weich verschmolzen wird nur, wo eine Rundung gewollt
ist (Achsel, Schulter, Hals, Bauch, Po).

Reines numpy (kein bpy): lässt sich auch außerhalb von Blender testen.
Koordinaten wie Blender: x = linke Körperseite, y nach hinten, z oben; Blick nach -y; T-Pose
(Arme waagerecht, Handflächen nach unten, Daumen nach vorn).
"""

import math

import numpy as np

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
EAR_TURN = 40.0   # Ohren um so viel Grad nach vorn gedreht
HEAD_DROP = 0.018  # Kopf so viel tiefer gesetzt (kürzerer Hals)
NOSE_Z = 0.112    # Nasenspitze über dem Kinn (an der Unterkante der Augen, wie im Manga-Chibi-Stil)
NOSE_R = (0.0105, 0.0072, 0.0085)  # kleine, flache Knopfnase (Halbmaße; nur ein Punkt im Gesicht)
# Ohren auf Augenhöhe (Mitte der Augen 0,146 m über dem Kinn): Oberkante etwa an der Oberkante der
# Augen, Unterkante an der Nase – Höhe in Kopf-Einheiten (gebaut für 0,41 m), Abstand der Ohrmitte
# zur Kopfseite (m), Halbmaße (Dicke, Breite, Höhe)
EAR_Z = 0.128
EAR_OUT = 0.021
EAR_R = (0.016, 0.038, 0.041)
# Schultern breiter/schmaler (m): Bei dick/dünn rückt der ganze Arm samt Gelenken nach außen/innen
# (in Godot verschiebt ChibiCharacter dafür die Oberarm-Knochen, die Formregler enthalten es nicht)
ARM_SPREAD = {"thin": -0.006, "medium": 0.0, "fat": 0.054}
LEG_SPREAD = {"thin": -0.003, "medium": 0.0, "fat": 0.020}    # Beine auseinander (Lücke im Schritt)
FINGER_CURL = (4.0, 9.0, 14.0)  # Finger in der T-Pose leicht gekrümmt (Grad je Glied, locker statt steif)
# Finger: Name, Versatz quer zur Hand (y, vorn = Zeigefinger), Länge, Spreizung (Grad)
FINGERS = (("Index", -0.0255, 0.050, -6.0), ("Middle", -0.0085, 0.055, -2.0),
           ("Ring", 0.0085, 0.051, 2.5), ("Little", 0.0250, 0.042, 7.5))
FINGER_SEGMENTS = (0.44, 0.31, 0.25)   # Anteile der Glieder (Grund-, Mittel-, Endglied)
FINGER_RADIUS = (0.0066, 0.0058)       # Fingerdicke am Ansatz und an der Spitze (mal Handgröße)
THUMB_RADIUS = (0.0105, 0.0088, 0.0077, 0.0066)
PALM_X = 0.064    # Fingeransätze (Knöchel) so weit vor dem Handgelenk (mal Handgröße)
WEB_K = 0.005     # so weich gehen die Finger am Ansatz ineinander über (Schwimmhaut, m)


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
# Grundformen und Gruppen
# ---------------------------------------------------------------------------------------------

class Leaf:
    """Eine Grundform mit Kasten lo..hi (außerhalb davon wird sie nicht ausgewertet)."""

    def __init__(self, name, lo, hi):
        self.name = name
        self.lo = np.array(lo, np.float64)
        self.hi = np.array(hi, np.float64)

    def f(self, x, y, z):
        raise NotImplementedError

    def eval_points(self, p):
        return self.f(p[:, 0], p[:, 1], p[:, 2])


def _local(rot, dx, dy, dz):
    """In die eigenen Achsen der Form drehen (Spalten von rot = lokale Achsen)."""
    if rot is None:
        return dx, dy, dz
    r = rot
    return (r[0, 0] * dx + r[1, 0] * dy + r[2, 0] * dz,
            r[0, 1] * dx + r[1, 1] * dy + r[2, 1] * dz,
            r[0, 2] * dx + r[1, 2] * dy + r[2, 2] * dz)


class Ellipsoid(Leaf):
    def __init__(self, name, c, r, rot=None):
        c = np.array(c, np.float64)
        r = np.array(r, np.float64)
        m = float(max(r))
        super().__init__(name, c - m, c + m)
        self.c, self.r = c, r
        self.rot = None if rot is None else np.array(rot, np.float64)

    def f(self, x, y, z):
        dx, dy, dz = _local(self.rot, x - self.c[0], y - self.c[1], z - self.c[2])
        rx, ry, rz = self.r
        k0 = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2 + (dz / rz) ** 2)
        k1 = np.sqrt((dx / (rx * rx)) ** 2 + (dy / (ry * ry)) ** 2 + (dz / (rz * rz)) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


class RoundBox(Leaf):
    """Abgerundeter Quader (Mitte c, halbe Kantenlängen b, Rundung r, optional gedreht)."""

    def __init__(self, name, c, b, r, rot=None):
        c = np.array(c, np.float64)
        b = np.array(b, np.float64)
        m = float(np.linalg.norm(b) + r)
        super().__init__(name, c - m, c + m)
        self.c, self.b, self.r = c, b, float(r)
        self.rot = None if rot is None else np.array(rot, np.float64)

    def f(self, x, y, z):
        dx, dy, dz = _local(self.rot, x - self.c[0], y - self.c[1], z - self.c[2])
        qx, qy, qz = np.abs(dx) - self.b[0], np.abs(dy) - self.b[1], np.abs(dz) - self.b[2]
        outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2 + np.maximum(qz, 0) ** 2)
        inside = np.minimum(np.maximum(qx, np.maximum(qy, qz)), 0.0)
        return outside + inside - self.r


class RoundCone(Leaf):
    """Runder Kegel (Kapsel mit zwei Radien) von a (Radius ra) nach b (Radius rb)."""

    def __init__(self, name, a, b, ra, rb):
        a = np.array(a, np.float64)
        b = np.array(b, np.float64)
        lo = np.minimum(a - ra, b - rb)
        hi = np.maximum(a + ra, b + rb)
        super().__init__(name, lo, hi)
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
    """Beliebige Funktion f(x, y, z) (z. B. der Boden unter den Füßen)."""

    def __init__(self, name, fn, lo=(-9, -9, -9), hi=(9, 9, 9)):
        super().__init__(name, lo, hi)
        self.fn = fn

    def f(self, x, y, z):
        return self.fn(x, y, z)


class Group:
    """Verknüpft Kinder nacheinander: ("union", Knoten, k), ("subtract", …), ("intersect", …)."""

    def __init__(self, name, items):
        self.name = name
        self.items = items
        los = [n.lo - k for op, n, k in items if op == "union"]
        his = [n.hi + k for op, n, k in items if op == "union"]
        self.lo = np.min(los, axis=0)
        self.hi = np.max(his, axis=0)

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
        # große Sprünge begrenzen
        n = np.linalg.norm(step, axis=1)
        step *= np.minimum(1.0, 0.03 / np.maximum(n, 1e-9))[:, None]
        p -= step
    return p


def project_along(node, p, n, iterations=30, max_step=0.0015, max_dist=0.012, h=0.0003):
    """Punkte entlang ihrer Richtung n auf die Oberfläche schieben (Newton, je Schritt höchstens
    max_step – so springt kein Punkt über eine schmale Lücke auf einen Nachbarfinger; insgesamt
    höchstens max_dist). Wer so nicht ankommt (Richtung fast entlang der Oberfläche), geht den
    kürzesten Weg auf die Oberfläche. Liefert die Punkte und den Feldwert dort (0 = getroffen)."""
    p = np.asarray(p, np.float64)
    n = np.asarray(n, np.float64)
    t = np.zeros(len(p))
    for _ in range(iterations):
        q = p + n * t[:, None]
        f = node.eval_points(q)
        df = (node.eval_points(q + n * h) - node.eval_points(q - n * h)) / (2 * h)
        df = np.where(np.abs(df) < 0.3, np.where(df < 0, -0.3, 0.3), df)
        t = np.clip(t + np.clip(-f / df, -max_step, max_step), -max_dist, max_dist)
    q = p + n * t[:, None]
    f = node.eval_points(q)
    bad = np.abs(f) > 0.0004
    if bad.any():
        moved = project(node, p[bad], 10) - p[bad]
        length = np.linalg.norm(moved, axis=1)
        q[bad] = p[bad] + moved * np.minimum(1.0, max_dist / np.maximum(length, 1e-9))[:, None]
        f[bad] = node.eval_points(q[bad])
    return q, f


def normals(node, p):
    g = gradient(node, p)
    return g / np.maximum(np.linalg.norm(g, axis=1), 1e-9)[:, None]


def raycast(node, origins, dirs, tmax=0.6, steps=300):
    """Erster Schnitt von Strahlen mit der Oberfläche (das Feld wechselt das Vorzeichen).
    Liefert die Punkte und ob es einen Treffer gab."""
    d = np.atleast_2d(np.asarray(dirs, np.float64))
    d = d / np.maximum(np.linalg.norm(d, axis=1), 1e-12)[:, None]
    o = np.atleast_2d(np.asarray(origins, np.float64))
    if len(o) == 1 and len(d) > 1:
        o = np.repeat(o, len(d), axis=0)
    ts = np.linspace(0.0, tmax, steps + 1)
    pts = o[:, None, :] + d[:, None, :] * ts[None, :, None]
    f = node.eval_points(pts.reshape(-1, 3)).reshape(len(o), -1)
    start = f[:, :1] < 0
    change = (f < 0) != start
    ok = change.any(axis=1)
    idx = np.argmax(change, axis=1)
    lo = ts[np.maximum(idx - 1, 0)]
    hi = ts[idx]
    for _ in range(30):
        mid = 0.5 * (lo + hi)
        same = (node.eval_points(o + d * mid[:, None]) < 0) == start[:, 0]
        lo = np.where(same, mid, lo)
        hi = np.where(same, hi, mid)
    t = np.where(ok, 0.5 * (lo + hi), 0.0)
    return o + d * t[:, None], ok


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
# Der Kopf (für alle Figuren gleich)
# ---------------------------------------------------------------------------------------------

def _rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])


HEAD_K = HEAD_HEIGHT / 0.41   # der Kopf ist für 0,41 m gebaut und auf HEAD_HEIGHT vergrößert


def head_point(chin, x, y, z):
    """Punkt im Kopf (Maße wie gebaut, 0,41 m) – Kinn auf Höhe chin."""
    k = HEAD_K
    return np.array((x * k, y * k, chin + z * k))


_EAR_X = {}


def ear_frame(chin, s):
    """Ohr der Seite s: Mitte, Richtung nach außen (schräg nach vorn), Halbmaße (Dicke, Breite, Höhe).
    Die Ohrmitte sitzt EAR_OUT außerhalb der Kopfseite (gemessen an der Kopfform ohne Ohren)."""
    a = math.radians(EAR_TURN)
    n = np.array((s * math.cos(a), -math.sin(a), 0.0))
    r = np.array(EAR_R) * HEAD_K
    if chin not in _EAR_X:
        shell = head_group(chin, with_nose=False, with_ears=False)
        p, _ = raycast(shell, head_point(chin, 0.0, 0.030, EAR_Z), [(1.0, 0.0, 0.0)], tmax=0.4)
        _EAR_X[chin] = float(p[0][0]) + EAR_OUT
    c = head_point(chin, 0.0, 0.030, EAR_Z)
    c[0] = s * _EAR_X[chin]
    return c, n, r


def head_group(chin, with_nose=True, with_ears=True):
    """Kopf: für alle Figuren gleich (Haare und Hüte passen allen). Kinn auf Höhe chin."""
    k = HEAD_K

    def P(x, y, z):
        return tuple(head_point(chin, x, y, z))

    def R(*r):
        return tuple(v * k for v in r)

    items = [
        ("union", Ellipsoid("cranium", P(0, 0.012, 0.232), R(0.204, 0.184, 0.178)), 0.0),
        ("union", Ellipsoid("jaw", P(0, -0.018, 0.112), R(0.160, 0.128, 0.112)), 0.075 * k),
        # Hinterkopf: rund bis hinunter zum Nacken (sonst wirkt der Kopf im Profil wie ein schräges Ei)
        ("union", Ellipsoid("occiput", P(0, 0.072, 0.168), R(0.152, 0.122, 0.092)), 0.06 * k),
        # kleines rundes Kinn vorn unten (Kieferlinie im Profil)
        ("union", Ellipsoid("chin", P(0, -0.090, 0.036), R(0.052, 0.042, 0.038)), 0.05 * k),
        ("union", Ellipsoid("cheek_l", P(0.074, -0.060, 0.100), R(0.072, 0.062, 0.066)), 0.07 * k),
        ("union", Ellipsoid("cheek_r", P(-0.074, -0.060, 0.100), R(0.072, 0.062, 0.066)), 0.07 * k),
    ]
    if with_ears:
        for s in (1, -1):
            side = "l" if s > 0 else "r"
            # Ohr: runde Scheibe, schräg nach vorn gedreht (von vorn als Halbkreis zu sehen), vorn
            # eine flache Mulde
            ear_c, n, r = ear_frame(chin, s)
            ear = Ellipsoid("ear_" + side, ear_c, r, rot=_rot_z(-s * EAR_TURN))
            cup = Ellipsoid("ear_cup_" + side, ear_c + n * 0.0185 * k + np.array((0, 0, 0.001 * k)),
                            R(0.0065, 0.024, 0.026), rot=_rot_z(-s * EAR_TURN))
            items.append(("union", ear, 0.016 * k))
            items.append(("subtract", cup, 0.006 * k))
    if with_nose:
        # kleine Knopfnase: sitzt auf der Gesichtsfläche
        c, r = nose_shape(chin)
        items.append(("union", Ellipsoid("nose", c, r), 0.010))
    return Group("head", items)


def nose_shape(chin):
    """Mitte und Halbmaße der Knopfnase."""
    z = chin + NOSE_Z
    y = surface_y(head_group(chin, False, False), z)
    return np.array((0.0, y + 0.0030, z)), np.array(NOSE_R)


# ---------------------------------------------------------------------------------------------
# Der Körper
# ---------------------------------------------------------------------------------------------

# Maße je Geschlecht (mittlere Größe, mittlere Form). Längen in m; Höhen im Rumpf als Anteil
# von T (Halsansatz bis Schritt). thin/fat: Faktoren für die Breiten.
DIMS = {
    "female": dict(
        crotch=0.493,          # Schritthöhe als Anteil der Kinnhöhe
        shoulder=(0.140, 0.070),  # Schultergelenk: seitlich (x) und so tief unter dem Halsansatz
        chest=(0.110, 0.096, 0.28), bust=(0.052, -0.074, 0.70, 0.052, 0.050, 0.047),
        waist=(0.104, 0.080, 0.27), belly=(0.064, 0.052, 0.08), pelvis=(0.118, 0.100, 0.20),
        butt=(0.064, 0.068, 0.078), neck=0.044,
        arm=(0.041, 0.036, 0.021), upper_arm=0.20, fore_arm=0.165, hand=1.05,
        hip_x=0.084, thigh=0.070, knee=0.050, calf=0.040, ankle=0.035, foot=0.88, thigh_top=0.80),
    "male": dict(
        crotch=0.49,
        shoulder=(0.156, 0.072),
        chest=(0.124, 0.100, 0.30), bust=None,
        waist=(0.136, 0.088, 0.25), belly=(0.08, 0.064, 0.09), pelvis=(0.126, 0.094, 0.19),
        butt=(0.050, 0.054, 0.064), neck=0.050,
        arm=(0.047, 0.042, 0.024), upper_arm=0.21, fore_arm=0.175, hand=1.13,
        hip_x=0.078, thigh=0.071, knee=0.050, calf=0.039, ankle=0.036, foot=0.95, thigh_top=0.80,
        thigh_start=0.84,
        # Becken so breit wie die Taille: seitlich eine gerade Linie von der Taille zur Hüfte (keine
        # Kerbe); dick: Bauch weniger rund, Hüfte wächst mit, Schultern schmaler
        shape_factors={"waist": (0.9, 1.16), "belly": (0.6, 1.40), "torso": (0.9, 1.14),
                       "pelvis": (0.9, 1.16)},
        arm_spread_fat=0.030),
}
# Faktoren je Form: (dünn, dick) für Rumpfbreite, Bauch, Arme, Beine, Hals, Po
SHAPE_FACTORS = {
    "torso": (0.9, 1.22), "pelvis": (0.9, 1.13), "waist": (0.9, 1.34), "belly": (0.6, 2.1), "arm": (0.87, 1.26), "leg": (0.86, 1.2),
    "neck": (0.93, 1.12), "butt": (0.88, 1.28), "bust": (0.88, 1.42),
}


class Body:
    """Maße, Gelenke und Feld einer Figur (gender, height = small/medium/tall, shape).
    parts = einzelne Teile (zum Abtasten durch chibi_cage), root = der ganze Körper."""

    def __init__(self, gender, height, shape="medium"):
        self.gender, self.height_class, self.shape = gender, height, shape
        self.D = D = DIMS[gender]
        self.H = HEIGHTS[gender][height]
        # Körpermaße gehen von body_top aus; der Kopf sitzt HEAD_DROP tiefer (kurzer Hals)
        body_top = self.H - HEAD_HEIGHT
        self.chin = body_top - HEAD_DROP
        self.crotch = D["crotch"] * body_top
        self.neck_base = body_top - 0.045
        self.T = self.neck_base - self.crotch
        f = {"thin": -1.0, "medium": 0.0, "fat": 1.0}[shape]
        # Kleinere Figuren sind auch etwas schmaler gebaut, größere etwas breiter (Kopf bleibt)
        mid = HEIGHTS[gender]["medium"] - HEAD_HEIGHT
        self.ws = ws = (body_top / mid) ** 0.8
        self.len_scale = body_top / mid

        def fac(part):
            thin, fat = D.get("shape_factors", {}).get(part, SHAPE_FACTORS[part])
            v = 1.0 + (fat - 1.0) * f if f >= 0 else 1.0 + (1.0 - thin) * f
            return v * ws

        self.fac = fac
        spread = ARM_SPREAD[shape]
        if shape == "fat" and "arm_spread_fat" in D:
            spread = D["arm_spread_fat"]
        self.arm_spread = spread * ws
        self.leg_spread = LEG_SPREAD[shape] * ws
        cr = self.crotch
        # Schultergelenk (bei dick/dünn samt Arm nach außen/innen gerückt); die Schulterlinie läuft
        # vom Hals flach zur runden Schulter (früher fiel sie mit 49° steil ab: hängende Schultern)
        sx, drop = D["shoulder"]
        self.shoulder_x = sx * ws + self.arm_spread
        self.shoulder_z = self.neck_base - drop * self.len_scale
        self.arm_y = 0.022   # Schultergelenk etwas hinter der Körpermitte (Schultern zurück)
        self.upper_arm = D["upper_arm"] * self.len_scale
        self.fore_arm = D["fore_arm"] * self.len_scale
        fa = fac("arm")
        # dicker/dünner vor allem am Oberarm, zum Handgelenk hin immer weniger (kein Überquellen)
        self.r_arm = (D["arm"][0] * fa, D["arm"][1] * (1 + (fa - 1) * 0.6), D["arm"][2] * (1 + (fa - 1) * 0.25))
        self.hand_k = D["hand"] * (1 + (fa - 1) * 0.2)
        self.hip_x = D["hip_x"] * ws + self.leg_spread
        self.hip_z = cr + 0.06
        self.knee_z = 0.565 * cr
        self.ankle_z = 0.084
        self.foot_scale = D["foot"]
        fl = fac("leg")
        self.r_leg = (D["thigh"] * fl, D["knee"] * (1 + (fl - 1) * 0.75), D["calf"] * (1 + (fl - 1) * 0.75),
                      D["ankle"] * (1 + (fl - 1) * 0.4))
        self.parts = {}
        self.joints_arm = {}
        self.joints_leg = {}
        self.hands = {}
        self.root = self._build()

    # --- Feld ---------------------------------------------------------------------------
    def _build(self):
        D, fac = self.D, self.fac
        fem = self.gender == "female"
        cr, T, nb = self.crotch, self.T, self.neck_base
        ft, fb = fac("torso"), fac("belly")
        ws = self.ws
        cx, cy, cz = D["chest"]
        wx, wy, wz = D["waist"]
        bx, by, bz = D["belly"]
        px, py, pz = D["pelvis"]
        torso = [
            # Brustkorb etwas nach vorn: aufrechte Haltung mit geschwungenem Rücken
            # (bei dick wächst der Brustkorb nach vorn weniger – sonst sitzt das Kinn auf der Brust)
            ("union", Ellipsoid("chest", (0, -0.014, cr + 0.70 * T), (cx * ft, cy * ws * (ft / ws) ** 0.5, cz * T)), 0.0),
            # Taille nach vorn gesetzt: hinten deutliches Hohlkreuz zwischen Brustkorb und Po
            ("union", Ellipsoid("waist", (0, -0.020, cr + 0.42 * T), (wx * fac("waist"), wy * fac("waist"), wz * T)), 0.075),
            ("union", Ellipsoid("belly", (0, -0.022 - 0.022 * max(fb - 1, 0), cr + 0.34 * T - 0.01 * max(fb - 1, 0)),
                                (bx * min(fb, 1.0) ** 0.5 * max(fb, 1) ** 0.6, by * fb, bz * max(fb, 1) ** 0.5)), 0.07),
            # Becken unten kürzer (sonst reicht es unter den Schritt und die Oberschenkel kleben zusammen)
            ("union", Ellipsoid("pelvis", (0, 0.022, cr + 0.19 * T), (px * fac("pelvis"), py * ft, pz * T)), 0.07),
        ]
        sz, sx = self.shoulder_z, self.shoulder_x
        r_up = self.r_arm[0]
        # obere Brust unter den Schlüsselbeinen bis zu den Schultern: füllt die Mulde zwischen Hals, Brust
        # und Armansatz (glatter Übergang von der Schulter zum Brustkorb, die Brust sitzt nicht als Beule)
        torso.append(("union", Ellipsoid("upper_chest", (0, -0.020, sz - 0.014),
                                         (0.118 * ft, 0.060 * ws * (ft / ws) ** 0.5, 0.056)), 0.05))
        # oberer Rücken: breit und glatt vom Nacken bis unter die Schulterblätter (früher einzelne
        # Schulterblätter: Knick quer über den Rücken)
        torso.append(("union", Ellipsoid("upper_back", (0, 0.028, sz - 0.020), (0.108 * ft, 0.050 * ft, 0.080)), 0.06))
        for s in (1, -1):
            side = "Left" if s > 0 else "Right"
            u = fac("butt")
            b = D["butt"]
            torso.append(("union", Ellipsoid("butt_" + side, (s * 0.054 * self.ws, 0.062, cr + 0.065),
                                             (b[0] * u, b[1] * u, b[2] * u)), 0.05))
            if D["bust"]:
                bx_, by_, bz_, rx, ry, rz = D["bust"]
                q = fac("bust")
                torso.append(("union", Ellipsoid("breast_" + side, (s * bx_ * self.ws, by_ * q - 0.012, cr + bz_ * T - 0.02 * max(q - 1.0, 0.0)),
                                                 (rx * q, ry * q, rz * q)), 0.075))
            # Schulterlinie: vom Hals fast waagerecht nach außen bis oben auf den Oberarm (runde Schulter,
            # oben bündig mit dem Arm; bei dicken Figuren weicher angesetzt – sonst eine Rinne oben auf der Brust)
            torso.append(("union", RoundCone("trap_" + side, (s * 0.030, 0.016, nb - 0.032),
                                             (s * (sx - 0.008), self.arm_y, sz + 0.006), 0.030 * ft, r_up * 0.95),
                          0.06 * max(ft / ws, 1.0) ** 1.5))
        if not fem:
            # breite, flache Brust (keine Muskeln)
            torso.append(("union", Ellipsoid("chest_front", (0, -0.028, cr + 0.72 * T),
                                             (0.110 * ft, 0.064 * ft, 0.10)), 0.08))
        body = Group("torso", torso)
        nr = D["neck"] * fac("neck")
        self.neck_r = nr
        neck = RoundCone("neck", (0, 0.024, self.chin + 0.07), (0, 0.014, nb - 0.02), nr, nr * 1.1)
        items = [("union", body, 0.0), ("union", neck, 0.04)]
        for s in (1, -1):
            items.append(("union", self._arm(s), 0.075))
        # Beine mäßig weich angesetzt (zu weich: Oberschenkel kleben innen zusammen), Kopf weich (keine scharfe
        # Falte unter dem Kinn)
        legs = Group("legs", [("union", self._leg(1), 0.0), ("union", self._leg(-1), 0.0)])
        items.append(("union", legs, 0.045))
        head = head_group(self.chin)
        items.append(("union", head, 0.028))
        # Bauchnabel: kleine Mulde vorn
        nav_z = cr + 0.37 * T
        ny = surface_y(Group("body0", items), nav_z)
        items.append(("subtract", Ellipsoid("navel", (0, ny + 0.0035, nav_z), (0.0058, 0.0062, 0.009)), 0.004))
        self.navel = np.array((0.0, ny, nav_z))
        # flache Fußsohlen
        items.append(("intersect", Func("floor", lambda x, y, z: -z + 0 * x + 0 * y), 0.006))
        self.parts.update(torso=body, neck=neck, head=head,
                          head_shell=head_group(self.chin, with_nose=False, with_ears=False))
        return Group("body", items)

    def _arm(self, s):
        """Arm in T-Pose: waagerecht, Handfläche nach unten. Ober- und Unterarm hart vereinigt
        (gleicher Radius am Ellbogen – glatt, ohne Beule)."""
        side = "Left" if s > 0 else "Right"
        sz, sx, y0 = self.shoulder_z, self.shoulder_x, self.arm_y
        elbow_x = sx + self.upper_arm
        wrist_x = elbow_x + self.fore_arm
        r_up, r_el, r_wr = self.r_arm
        upper = RoundCone("upperarm_" + side, (s * sx, y0, sz), (s * elbow_x, y0, sz), r_up, r_el)
        fore = RoundCone("forearm_" + side, (s * elbow_x, y0, sz), (s * wrist_x, y0, sz), r_el, r_wr)
        hand = self._hand(s, np.array((s * wrist_x, y0, sz)), r_wr)
        group = Group("arm_" + side, [("union", upper, 0.0), ("union", fore, 0.0), ("union", hand, 0.006)])
        self.joints_arm[side] = {"shoulder": np.array((s * sx, y0, sz)), "elbow": np.array((s * elbow_x, y0, sz)),
                                 "wrist": np.array((s * wrist_x, y0, sz))}
        self.parts["arm_" + side] = group
        return group

    def _hand(self, s, wrist, wrist_r):
        """Hand in T-Pose: Handfläche nach unten (-z), Finger entlang ±x, leicht gekrümmt,
        Daumen vorn (-y) schräg nach außen und unten. Die Finger verschmelzen weich mit der
        Handfläche und am Ansatz ganz leicht miteinander (kleine Schwimmhaut statt einer scharfen
        Rille), weiter vorn sind sie getrennt."""
        side = "Left" if s > 0 else "Right"
        k = self.hand_k
        wx, wy, wz = wrist
        # Handfläche: weiches Kissen (ringsum runde Kanten), Handrücken leicht gewölbt; zum Handgelenk
        # hin schmaler (Handballen)
        palm_c = np.array((wx + s * 0.038 * k, wy, wz - 0.0015 * k))
        palm = RoundBox("palm_" + side, palm_c, (0.022 * k, 0.0222 * k, 0.0012 * k), 0.0104 * k)
        back = Ellipsoid("back_" + side, palm_c + np.array((0.0, 0.0, 0.003 * k)), (0.030 * k, 0.029 * k, 0.0098 * k))
        heel = RoundCone("heel_" + side, (wx - s * 0.004, wy, wz), (wx + s * 0.024 * k, wy, wz - 0.001 * k),
                         wrist_r, 0.0118 * k)
        palm_g = Group("palm_" + side, [("union", palm, 0.0), ("union", back, 0.012), ("union", heel, 0.014)])
        info = {"k": k, "palm_c": palm_c, "half": (0.0330 * k, 0.0116 * k), "fingers": {}}
        r0, r1 = FINGER_RADIUS[0] * k, FINGER_RADIUS[1] * k
        names = ("Proximal", "Intermediate", "Distal")
        fingers = []
        for name, off, length, spread in FINGERS:
            base = np.array((wx + s * PALM_X * k, wy + off * k, wz - 0.0012 * k))
            a = math.radians(spread)
            pts = [base]
            for i, fr in enumerate(FINGER_SEGMENTS):
                c = math.radians(FINGER_CURL[i])
                d = np.array((s * math.cos(a) * math.cos(c), math.sin(a) * math.cos(c), -math.sin(c)))
                pts.append(pts[-1] + d * length * k * fr)
            radii = [r0 + (r1 - r0) * i / 3.0 for i in range(4)]
            # Glieder hart vereinigt (glatt, ohne Beulen an den Gelenken)
            chain = Group(f"finger_{side}_{name}", [("union", RoundCone(f"{side}{name}{names[i]}", pts[i], pts[i + 1],
                                                                        radii[i], radii[i + 1]), 0.0) for i in range(3)])
            fingers.append(("union", chain, WEB_K if fingers else 0.0))
            info["fingers"][name] = {"pts": pts, "radii": radii}
            self.parts[chain.name] = chain
        # Daumen: von der Handwurzel vorn zur Seite hinaus, nach außen und etwas nach unten, zur Hand gebogen
        t0 = np.array((wx + s * 0.016 * k, wy - 0.016 * k, wz - 0.005 * k))
        dirs = [(0.30, -0.88, -0.37), (0.72, -0.62, -0.30), (0.88, -0.43, -0.20)]
        lengths = (0.028, 0.021, 0.017)
        tp = [t0]
        for (dx, dy, dz), ln in zip(dirs, lengths):
            d = np.array((s * dx, dy, dz))
            tp.append(tp[-1] + d / np.linalg.norm(d) * ln * k)
        rad = [r * k for r in THUMB_RADIUS]
        tb = ("Metacarpal", "Proximal", "Distal")
        thumb = Group(f"finger_{side}_Thumb", [("union", RoundCone(f"{side}Thumb{tb[i]}", tp[i], tp[i + 1], rad[i], rad[i + 1]), 0.0)
                                               for i in range(3)])
        info["fingers"]["Thumb"] = {"pts": tp, "radii": rad}
        self.parts[thumb.name] = thumb
        self.parts["palm_" + side] = palm_g
        self.hands[side] = info
        return Group("hand_" + side, [("union", palm_g, 0.0), ("union", Group("fingers_" + side, fingers), 0.010),
                                      ("union", thumb, 0.022)])

    def _leg(self, s):
        D = self.D
        side = "Left" if s > 0 else "Right"
        hx, hz = s * self.hip_x, self.hip_z
        kx, kz = s * (self.hip_x - 0.002), self.knee_z
        ax, az = s * (self.hip_x - 0.004), self.ankle_z
        r_th, r_kn, r_ca, r_an = self.r_leg
        fs = self.foot_scale
        # Oberschenkel: oben am Schritt am dicksten (Mitte etwas unter dem Hüftgelenk)
        th_top = (hx, 0.010, hz - 0.05)
        leg = [
            ("union", RoundCone("thigh_" + side, (hx, 0.010, hz), (kx, 0.004, kz), r_th * D.get("thigh_start", 0.96), r_kn), 0.0),
            # Oberschenkel oben: bei Männern seitlich flacher (gerade Hüftlinie)
            ("union", Ellipsoid("thigh_top_" + side, th_top, (r_th * D.get("thigh_top", 1.0), r_th * 1.08, (hz - kz) * 0.42)), 0.03),
            # Unterschenkel hart angesetzt (gleicher Radius am Knie: glatt, ohne Beule)
            ("union", RoundCone("shin_" + side, (kx, 0.004, kz), (ax, 0.012, az), r_kn, r_an), 0.0),
            ("union", Ellipsoid("calf_" + side, (kx, 0.012, kz - 0.32 * (kz - az)),
                                (r_ca * 0.97, r_ca * 1.02, (kz - az) * 0.45)), 0.05),
        ]
        foot = [
            # Fuß: hinten an der Ferse höher, vorn zu den Zehen flach auslaufend
            ("union", Ellipsoid("foot_" + side, (ax + s * 0.004, -0.016 * fs, 0.038 * fs), (0.046 * fs, 0.076 * fs, 0.038 * fs)), 0.0),
            ("union", Ellipsoid("toes_" + side, (ax + s * 0.006, -0.074 * fs, 0.025 * fs), (0.050 * fs, 0.052 * fs, 0.025 * fs)), 0.03),
            ("intersect", Func("floor", lambda x, y, z: -z + 0 * x + 0 * y), 0.006),
        ]
        leg_g = Group("leg_" + side, leg)
        foot_g = Group("foot_" + side, foot)
        self.joints_leg[side] = {"hip": np.array((hx, 0.010, hz)), "knee": np.array((kx, 0.004, kz)),
                                 "ankle": np.array((ax, 0.012, az)), "ball": np.array((ax + s * 0.004, -0.064 * fs, 0.024)),
                                 "toe": np.array((ax + s * 0.006, -0.118 * fs, 0.020))}
        legfoot = Group("legfoot_" + side, [("union", leg_g, 0.0), ("union", foot_g, 0.035)])
        self.parts.update({"leg_" + side: leg_g, "foot_" + side: foot_g, "legfoot_" + side: legfoot})
        return legfoot

    def bounds(self):
        lo, hi = self.root.lo.copy(), self.root.hi.copy()
        lo[2] = -0.01
        hi[2] = self.H - HEAD_DROP + 0.01
        return lo + np.array((-0.01, -0.01, 0.0)), hi + np.array((0.01, 0.01, 0.0))

    # --- Unterwäsche (aufgemalt) ------------------------------------------------------------
    def underwear_distance(self, p):
        """Abstand (m) zum Rand der aufgemalten Unterwäsche je Hautpunkt: negativ = Stoff.
        Frauen: Bandeau + Slip, Männer: Boxershorts. An den Armen nie (endet an der Achsel)."""
        cr, T = self.crotch, self.T
        x, z = np.abs(p[:, 0]), p[:, 2]
        fem = self.gender == "female"
        waist = cr + (0.30 if fem else 0.32) * T
        if fem:
            # Slip: Beinausschnitt schräg, außen höher
            inner = np.array((0.0, cr - 0.012))
            outer = np.array((0.18, cr + 0.13 * T))
        else:
            # Boxershorts: kurzes Bein, fast waagerecht
            inner = np.array((0.0, cr - 0.09))
            outer = np.array((0.18, cr - 0.068))
        dx, dz = outer - inner
        n = np.array((dz, -dx)) / math.hypot(dx, dz)
        leg = (x - inner[0]) * n[0] + (z - inner[1]) * n[1]
        d = np.maximum(z - waist, leg)
        if fem:
            # Bandeau: vorn hoch über der Brust, an den Seiten und hinten unter der Achsel
            front_top, bottom = cr + 0.77 * T, cr + 0.565 * T
            side_top = min(self.shoulder_z - self.r_arm[0] - 0.03, front_top)
            # wie weit vorn (Richtung um den Körper, nicht Tiefe – sonst folgt die Kante der Brust
            # und wird wellig)
            dy = p[:, 1] - 0.005
            fwd = -dy / np.maximum(np.hypot(p[:, 0], dy), 1e-6)
            f = np.clip(fwd / 0.75, 0.0, 1.0)
            f = f * f * (3 - 2 * f)
            top = side_top + (front_top - side_top) * f
            d = np.minimum(d, np.maximum(z - top, bottom - z))
        # nie auf den Armen: wo die Haut näher am Arm als am Rumpf liegt, endet die Wäsche
        # (die Kante liegt so genau in der Achselfalte)
        torso = self.parts["torso"].eval_points(p)
        arms = np.minimum(self.parts["arm_Left"].eval_points(p), self.parts["arm_Right"].eval_points(p))
        return np.maximum(d, (torso - arms) * 0.5 + 0.002)


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
