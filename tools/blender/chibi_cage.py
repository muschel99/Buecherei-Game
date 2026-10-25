"""Gitter (Käfig) der Chibi-Figuren (seit Etappe 5c, Neubau): ein grobes Netz nur aus Vierecken mit
Ringen um jedes Gelenk – so wie bei einer von Hand modellierten Spielfigur. build_chibi glättet es
zweimal (Catmull-Clark, jedes Viereck wird zu 16) und legt es danach genau auf die Form aus
chibi_sdf. Ein durchgehender, geschlossener Körper ohne Nähte:

- Rumpf: 8 Ringe zu je 20 Ecken (Hüfte bis Schulter); oben und unten ein Deckel aus 5x5 Feldern
  mit der Öffnung für den Hals bzw. die Beine; seitlich je eine Öffnung (3x2 Felder) für die Arme.
- Arme, Beine und Hals: Röhren aus Ringen mit 10 Ecken, je ein Ring genau auf dem Gelenk.
- Hand: flache 10er-Ringe, vorn vier Öffnungen für die Finger (Röhren aus 4er-Ringen, Ringe auf
  den Fingergelenken), an der Seite der Daumen.
- Füße: aus der Vorderseite des Knöchels nach vorn; die Sohle ist ein Deckel mit 2x3 Feldern.
- Kopf: Würfelkugel mit 5x5 Feldern je Seite (unten die Öffnung für den Hals), Ohren als kurze
  Röhre aus einem Feld, Nase und Bauchnabel als eingesetztes kleines Feld (feineres Netz dort).

Jede Ecke gehört zu einem Bereich (Rumpf, Arm, Hand, Finger …); chibi_rig rechnet daraus die
Gewichte. Die Lage der Ecken wird von der Form abgetastet (Strahlen auf die einzelnen Teile).
Gleiche Aufrufe ergeben immer dieselbe Reihenfolge der Ecken – dünn, mittel und dick haben darum
dasselbe Netz (Formregler).
"""

import math

import numpy as np

import chibi_sdf as S

GRID = 5   # Rumpfdeckel und Kopfseiten: 5x5 Felder
WEB_X = 0.068   # Schwimmhaut zwischen den Fingern so weit vor dem Handgelenk (mal Handgröße)
WEB_Z = 0.62    # und so hoch (Anteil der halben Handdicke)
THUMB_BASE = 0.55  # Daumenansatz: so weit entlang des Mittelhandknochens (Anteil)
# Ohr-Ringe: (Abstand nach außen, Größe) als Anteil der Ohr-Halbmaße; Boden der Mulde
EAR_RINGS = ((0.25, 0.97), (0.90, 0.80), (1.00, 0.56), (0.80, 0.30))
EAR_CUP = 0.74

# Ringe als Punkte auf dem Rand des Quadrats [-1, 1]² (a, b): Reihenfolge = Reihenfolge der Ecken
# Arm (a = y, b = z) und Hals (a = x, b = y): wie die 3x2-Öffnung im Rumpf
SQUARE_10 = [(-1, -1), (-1 / 3, -1), (1 / 3, -1), (1, -1), (1, 0), (1, 1), (1 / 3, 1), (-1 / 3, 1), (-1, 1), (-1, 0)]
# flache Hand (a = y quer, b = z): 4 Felder oben und unten (vorn die vier Fingeröffnungen)
PALM_10 = [(-1, -1), (-0.5, -1), (0, -1), (0.5, -1), (1, -1), (1, 1), (0.5, 1), (0, 1), (-0.5, 1), (-1, 1)]
# Bein (a = seitlich nach außen, b = y): wie die 2x3-Öffnung im Rumpfdeckel
LEG_10 = [(-1, -1), (0, -1), (1, -1), (1, -1 / 3), (1, 1 / 3), (1, 1), (0, 1), (-1, 1), (-1, 1 / 3), (-1, -1 / 3)]
# Fuß (a = seitlich nach außen, b = z): oben die Vorderseite des Knöchels, unten die Sohle
FOOT_6 = [(-1, 1), (0, 1), (1, 1), (1, -1), (0, -1), (-1, -1)]
FINGER_4 = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
NECK_PORT = [(1, 2), (2, 2), (3, 2), (4, 2), (4, 3), (4, 4), (3, 4), (2, 4), (1, 4), (1, 3)]


def square_boundary(n):
    """Rand eines n x n-Gitters (u, w) als Ring: vorn (w = 0) von rechts nach links, dann linke
    Seite, hinten, rechte Seite."""
    pts = [(u, 0) for u in range(n + 1)]
    pts += [(n, w) for w in range(1, n + 1)]
    pts += [(u, n) for u in range(n - 1, -1, -1)]
    pts += [(0, w) for w in range(n - 1, 0, -1)]
    return pts


def _square_param(a, b):
    """Lage eines Randpunkts des Quadrats als Umfangs-Maß 0..8 (Start bei (-1, -1))."""
    if abs(b + 1) < 1e-9:
        return a + 1.0
    if abs(a - 1) < 1e-9:
        return 2.0 + (b + 1)
    if abs(b - 1) < 1e-9:
        return 4.0 + (1 - a)
    return 6.0 + (1 - b)


def _square_point(s):
    s %= 8.0
    if s < 2:
        return (s - 1, -1)
    if s < 4:
        return (1, s - 3)
    if s < 6:
        return (5 - s, 1)
    return (-1, 7 - s)


def mix_layout(la, lb, t):
    """Zwischen zwei Ring-Aufteilungen überblenden (entlang des Umfangs)."""
    out = []
    for pa, pb in zip(la, lb):
        sa, sb = _square_param(*pa), _square_param(*pb)
        out.append(_square_point(sa + (sb - sa) * t))
    return out


def round_dirs(layout, ea, eb):
    """Richtungen für runde Teile: Umfangs-Maß gleichmäßig in Winkel umgerechnet."""
    out = []
    for a, b in layout:
        ang = math.radians(225.0 + 45.0 * _square_param(a, b))
        out.append(math.cos(ang) * ea + math.sin(ang) * eb)
    return np.array(out)


def flat_dirs(layout, ea, eb, sa, sb):
    """Richtungen für flache Teile (Hand): Quadrat auf ein Rechteck sa x sb gestreckt."""
    return np.array([a * sa * ea + b * sb * eb for a, b in layout])


def frame(d, across):
    """Rahmen senkrecht zur Richtung d: e_a möglichst wie across, e_b nach oben (z)."""
    d = d / np.linalg.norm(d)
    ea = across - (across @ d) * d
    ea /= np.linalg.norm(ea)
    eb = np.cross(d, ea)
    if eb[2] < 0:
        eb = -eb
    return ea, eb


def coons(boundary, n):
    """Innenpunkte eines n x n-Gitters aus seinem Rand (dict (u, w) -> Punkt), Coons-Fläche."""
    out = {}
    for u in range(1, n):
        for w in range(1, n):
            a, b = u / n, w / n
            p = ((1 - a) * boundary[(0, w)] + a * boundary[(n, w)] + (1 - b) * boundary[(u, 0)] + b * boundary[(u, n)]
                 - ((1 - a) * (1 - b) * boundary[(0, 0)] + a * (1 - b) * boundary[(n, 0)]
                    + (1 - a) * b * boundary[(0, n)] + a * b * boundary[(n, n)]))
            out[(u, w)] = p
    return out


class Cage:
    """Ecken (Lage + Bereich) und Vierecke."""

    def __init__(self):
        self.p = []
        self.region = []
        self.faces = []

    def add(self, pos, region):
        self.p.append(np.asarray(pos, np.float64))
        self.region.append(region)
        return len(self.p) - 1

    def ring(self, pts, region):
        return [self.add(q, region) for q in pts]

    def quad(self, a, b, c, d):
        self.faces.append((a, b, c, d))

    def band(self, ra, rb, skip=()):
        """Vierecke zwischen zwei Ringen gleicher Länge (Feld i verbindet Ecke i und i+1)."""
        n = len(ra)
        for i in range(n):
            if i not in skip:
                j = (i + 1) % n
                self.quad(ra[i], ra[j], rb[j], rb[i])

    def inset(self, corners, inner_pos, region, cap=True):
        """Viereck corners durch ein kleineres Viereck (inner_pos) mit vier Feldern darum ersetzen –
        mit Abstand nach außen wird daraus eine kurze Röhre mit Deckel (Ohr). Ohne Deckel bleibt
        das innere Viereck offen (Ansatz für einen Finger, mit einem Steg zum Nachbarn)."""
        inner = self.ring(inner_pos, region)
        for i in range(4):
            j = (i + 1) % 4
            self.quad(corners[i], corners[j], inner[j], inner[i])
        if cap:
            self.quad(*inner)
        return inner

    def ring_band(self, ring, pts, region):
        """Neuer Ring (pts) mit einem Band aus Vierecken zum Ring ring."""
        new = self.ring(pts, region)
        self.band(ring, new)
        return new

    @staticmethod
    def ring_on(part, center, d, across):
        """Vier Punkte (wie FINGER_4) rund um die Achse d auf der Oberfläche von part."""
        ea, eb = frame(d, across)
        q, _ = S.raycast(part, center, round_dirs(FINGER_4, ea, eb), tmax=0.04, steps=200)
        return list(q)

    def finish(self):
        """Unbenutzte Ecken entfernen; liefert (Ecken, Vierecke, Bereiche, neue Nummern)."""
        faces = np.array(self.faces, np.int64)
        used = np.unique(faces)
        remap = np.full(len(self.p), -1, np.int64)
        remap[used] = np.arange(len(used))
        p = np.array(self.p)[used]
        region = [self.region[i] for i in used]
        return p, remap[faces], region, remap


def check_closed(faces):
    """Jede Kante muss genau zwei Vierecke haben (geschlossener Körper ohne Löcher)."""
    count = {}
    for f in faces:
        for i in range(4):
            a, b = int(f[i]), int(f[(i + 1) % 4])
            key = (min(a, b), max(a, b))
            count[key] = count.get(key, 0) + 1
    bad = {k: c for k, c in count.items() if c != 2}
    return len(count), bad


# ---------------------------------------------------------------------------------------------
# Der Käfig einer Figur
# ---------------------------------------------------------------------------------------------

def build(body):
    """Käfig für body (chibi_sdf.Body). Liefert (Ecken, Vierecke, Bereiche, Lage-Infos)."""
    cg = Cage()
    P = body.parts
    cr, T, nb = body.crotch, body.T, body.neck_base
    sz, sx, y0 = body.shoulder_z, body.shoulder_x, body.arm_y
    r_up = body.r_arm[0]
    rp = 1.25 * r_up          # halbe Größe der Arm-Öffnung im Rumpf
    n = GRID
    sq = square_boundary(n)
    sq_index = {uw: i for i, uw in enumerate(sq)}
    ex, ey, ez = np.eye(3)

    # --- Rumpf: Ringe von der Hüfte bis zur Schulter ------------------------------------------
    t4 = sz - rp
    zs = [body.hip_z + 0.01, cr + 0.27 * T, cr + 0.42 * T, cr + 0.55 * T, 0.5 * (cr + 0.55 * T + t4), t4, sz, sz + rp]
    names = ["T0", "T1", "T2", "T3", "T3b", "T4", "T5", "T6"]
    torso_pts = {}
    dirs = np.array([((u - n / 2) / (n / 2), (w - n / 2) / (n / 2) * 0.85, 0.0) for u, w in sq])
    # die obersten Ringe vorn und hinten tiefer als an den Seiten (Sattel über die Schulter): bei hohen
    # Schultern bliebe dem Deckel sonst am Rücken kein Platz bis zum Hals und das Netz faltete sich
    saddle = {"T5": -0.30, "T6": -0.65}
    for name, z in zip(names, zs):
        if name in saddle:
            heights = np.array([z + saddle[name] * rp * (0.5 if u in (0, n) else 1.0)
                                * (0.0 if u in (0, n) and 0 < w < n else 1.0) for u, w in sq])
        else:
            heights = np.full(len(sq), z)
        origins = np.stack([np.zeros(len(sq)), np.full(len(sq), 0.005), heights], axis=1)
        pts, _ = S.raycast(P["torso"], origins, dirs, tmax=0.4)
        torso_pts[name] = pts
    # Arm-Öffnung (3x2 Felder) seitlich auf T4..T6: ein Quadrat um den Armansatz
    x_port = sx - 0.030
    port_y = {1: -1.0, 2: -1 / 3, 3: 1 / 3, 4: 1.0}
    port_z = {"T4": -1.0, "T5": 0.0, "T6": 1.0}
    for s, u in ((1, n), (-1, 0)):
        for name, zf in port_z.items():
            for w, yf in port_y.items():
                torso_pts[name][sq_index[(u, w)]] = (s * x_port, y0 + yf * rp, sz + zf * rp)
    rings = {name: cg.ring(torso_pts[name], "torso") for name in names}
    # Bänder zwischen den Ringen; seitlich die Arm-Öffnungen frei lassen, vorn den Bauchnabel
    arm_cells = {sq_index[(u, w)] for u in (n,) for w in (1, 2, 3)} | {sq_index[(0, w)] for w in (2, 3, 4)}
    for a, b in zip(names[:-1], names[1:]):
        skip = set(arm_cells) if a in ("T4", "T5") else set()
        if a == "T1":
            skip.add(2)   # Feld vorn in der Mitte (Ecken 2 und 3): Bauchnabel
        cg.band(rings[a], rings[b], skip)
    # Bauchnabel: kleines Feld eingesetzt (feineres Netz für die Mulde)
    nav = body.navel
    corners = [rings["T1"][2], rings["T1"][3], rings["T2"][3], rings["T2"][2]]
    signs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    inner = []
    for sxn, szn in signs:
        o = np.array((sxn * 0.0075, 0.0, nav[2] + szn * 0.010))
        p, _ = S.raycast(P["torso"], o, [(0.0, -1.0, 0.0)], tmax=0.3)
        inner.append(p[0])
    cg.inset(corners, inner, "torso")

    def port_cycle(u):
        """Ecken der Arm-Öffnung (u = Seite) als Ring wie SQUARE_10 (a = y, b = z)."""
        r4, r5, r6 = rings["T4"], rings["T5"], rings["T6"]
        return ([r4[sq_index[(u, w)]] for w in (1, 2, 3, 4)] + [r5[sq_index[(u, 4)]], r6[sq_index[(u, 4)]]]
                + [r6[sq_index[(u, w)]] for w in (3, 2, 1)] + [r5[sq_index[(u, 1)]]])

    # --- Deckel oben (Schultern, Halsansatz) ------------------------------------------------
    top = rings["T6"]
    bnd = {uw: np.array(cg.p[top[i]]) for uw, i in sq_index.items()}
    inner_xy = coons(bnd, n)
    rn, yn = 1.3 * body.neck_r, 0.016
    neck_x = {1: -1.0, 2: -1 / 3, 3: 1 / 3, 4: 1.0}
    neck_y = {2: -1.0, 3: 0.0, 4: 1.0}
    for (u, w) in list(inner_xy):
        if u in neck_x and w in neck_y:
            inner_xy[(u, w)] = np.array((neck_x[u] * rn, yn + neck_y[w] * rn, 0.0))
    top_grid = {uw: top[i] for uw, i in sq_index.items()}
    # nie unter dem obersten Ring (bei dicker Brust träfe der senkrechte Strahl vorn sonst die
    # Brustwölbung tiefer unten und das Netz faltete sich)
    z_floor = min(cg.p[i][2] for i in top) + 0.006
    for (u, w), q in inner_xy.items():
        if (u, w) in ((2, 3), (3, 3)):
            continue   # liegt in der Halsöffnung
        p, _ = S.raycast(P["torso"], (q[0], q[1], nb + 0.3), [(0.0, 0.0, -1.0)], tmax=0.6)
        p[0][2] = max(p[0][2], z_floor)
        top_grid[(u, w)] = cg.add(p[0], "torso")
    neck_cells = {(u, w) for u in (1, 2, 3) for w in (2, 3)}
    for u in range(n):
        for w in range(n):
            if (u, w) not in neck_cells:
                cg.quad(top_grid[(u, w)], top_grid[(u + 1, w)], top_grid[(u + 1, w + 1)], top_grid[(u, w + 1)])
    neck_port = [top_grid[uw] for uw in NECK_PORT]

    # --- Deckel unten (Schritt) mit den Beinöffnungen -----------------------------------------
    bot = rings["T0"]
    r_th = body.r_leg[0]
    hx = body.hip_x
    leg_y = {1: -0.9, 2: -0.3, 3: 0.3, 4: 0.9}
    inner_x = {3: hx - 0.8 * r_th, 4: hx, 2: -(hx - 0.8 * r_th), 1: -hx}
    bot_grid = {uw: bot[i] for uw, i in sq_index.items()}
    for u in (1, 2, 3, 4):
        for w in (1, 2, 3, 4):
            if (u, w) in ((4, 2), (4, 3), (1, 2), (1, 3)):
                continue   # in den Beinöffnungen
            o = (inner_x[u], 0.010 + leg_y[w] * r_th, body.hip_z - 0.5)
            p, _ = S.raycast(P["torso"], o, [(0.0, 0.0, 1.0)], tmax=0.6)
            # nie über dem Hüftring (bei schmalem Becken träfe der Strahl vorn erst den Bauch)
            p[0][2] = min(p[0][2], zs[0] - 0.012)
            bot_grid[(u, w)] = cg.add(p[0], "torso")
    leg_cells = {(u, w) for u in (3, 4) for w in (1, 2, 3)} | {(u, w) for u in (0, 1) for w in (1, 2, 3)}
    for u in range(n):
        for w in range(n):
            if (u, w) not in leg_cells:
                cg.quad(bot_grid[(u, w)], bot_grid[(u + 1, w)], bot_grid[(u + 1, w + 1)], bot_grid[(u, w + 1)])

    def leg_port(s):
        """Ring der Beinöffnung wie LEG_10: vorn innen → vorn außen → außen → hinten → innen."""
        if s > 0:
            us = (3, 4, 5)
        else:
            us = (2, 1, 0)
        g = bot_grid
        return ([g[(u, 1)] for u in us] + [g[(us[2], 2)], g[(us[2], 3)]] + [g[(u, 4)] for u in reversed(us)]
                + [g[(us[0], 3)], g[(us[0], 2)]])

    info = {"rings": {}}

    # --- Arme und Hände -----------------------------------------------------------------------
    for s, u, side in ((1, n, "Left"), (-1, 0, "Right")):
        _arm(cg, body, s, side, port_cycle(u), info)

    # --- Beine und Füße -----------------------------------------------------------------------
    for s, side in ((1, "Left"), (-1, "Right")):
        _leg(cg, body, s, side, leg_port(s), info)

    # --- Hals und Kopf ------------------------------------------------------------------------
    head_port = _head(cg, body, info)
    # mittlerer Halsring zwischen Rumpf und Kopf (vorn sitzt das Kinn fast auf der Brust – ein Ring
    # auf dem Halszylinder läge dort in der Falte und das Netz klappte um), halb zum Hals gezogen
    mid = np.array([0.5 * (cg.p[a] + cg.p[b]) for a, b in zip(neck_port, head_port)])
    axis = np.array([(0.0, 0.018, z) for z in mid[:, 2]])
    hit, _ = S.raycast(P["neck"], axis, mid - axis, tmax=0.2)
    neck_mid = cg.ring(0.5 * (mid + hit), "neck")
    cg.band(neck_port, neck_mid)
    cg.band(neck_mid, head_port)
    info["rings"]["neck"] = neck_mid
    p, f, region, remap = cg.finish()
    info["rings"] = {k: [[int(remap[i]) for i in r] for r in (v if isinstance(v[0], list) else [v])]
                     for k, v in info["rings"].items()}
    return p, f, region, info


def _arm(cg, body, s, side, port, info):
    P = body.parts
    sz, sx, y0 = body.shoulder_z, body.shoulder_x, body.arm_y
    ex, ey, ez = np.eye(3)
    up, fore = body.upper_arm, body.fore_arm
    wrist_x = sx + up + fore
    # Ringe: kurz hinter dem Schultergelenk, Mitte Oberarm, Ellbogen, Mitte Unterarm, Handgelenk;
    # zum Handgelenk hin geht der runde Querschnitt in die flache Hand über (leichte Drehung wie
    # beim echten Unterarm)
    stations = [(0.022, 0.0), (0.5 * up, 0.0), (up, 0.0), (up + 0.5 * fore, 0.4), (up + fore, 0.8)]
    prev = port
    arm_rings = []
    for t, mix in stations:
        layout = mix_layout(SQUARE_10, PALM_10, mix)
        c = np.array((s * (sx + t), y0, sz))
        pts, _ = S.raycast(P["arm_" + side], c, round_dirs(layout, ey, ez), tmax=0.15)
        r = cg.ring(pts, "arm_" + side)
        cg.band(prev, r)
        arm_rings.append(r)
        prev = r
    info["rings"]["arm_" + side] = arm_rings
    # Hand: flache Ringe (4 Felder oben und unten), der letzte liegt an den Fingeransätzen
    h = body.hands[side]
    k = h["k"]
    wx, wy, wz = wrist_x * s, y0, sz
    half_y, half_z = h["half"]
    fingers = h["fingers"]
    order = [f[0] for f in S.FINGERS]
    r0 = S.FINGER_RADIUS[0] * k
    offs = [fingers[f]["pts"][0][1] - wy for f in order]
    cols = [offs[0] - 1.05 * r0, 0.5 * (offs[0] + offs[1]), 0.5 * (offs[1] + offs[2]), 0.5 * (offs[2] + offs[3]),
            offs[3] + 1.05 * r0]
    knuckle = [(c / half_y, -1) for c in cols] + [(c / half_y, 1) for c in reversed(cols)]
    hand_rings = []
    for dx, layout in ((0.008, PALM_10), (0.046, PALM_10), (0.058, knuckle)):
        c = np.array((wx + s * dx * k, wy, wz - 0.0015 * k))
        pts, _ = S.raycast(P["palm_" + side], c, flat_dirs(layout, ey, ez, half_y, half_z), tmax=0.08)
        if layout is knuckle:
            # zwischen den Fingern: Ecken vorn an der Schwimmhaut (dort trennen sich die Finger),
            # nicht hinten auf dem Handrücken – sonst wird die Haut dort zusammengekniffen
            for col in (1, 2, 3):
                for i, zf in ((col, -1.0), (9 - col, 1.0)):
                    pts[i] = (wx + s * WEB_X * k, wy + cols[col], wz - 0.0015 * k + zf * WEB_Z * half_z)
        r = cg.ring(pts, "hand_" + side)
        # Daumen-Öffnung vorn an der Seite zwischen dem 1. und 2. Handring (Feld 9: Ecken 9 und 0)
        cg.band(prev, r, skip={9} if len(hand_rings) == 1 else ())
        hand_rings.append(r)
        prev = r
    h1, h2, h3 = hand_rings
    info["rings"]["hand_" + side] = hand_rings
    # Finger: vorn je ein Feld der letzten Handreihe (unten Ecke c, oben Ecke 9 - c); zwei
    # Nachbarfinger teilen sich die Kante an der Schwimmhaut
    for c, name in enumerate(order):
        port = [h3[c], h3[c + 1], h3[8 - c], h3[9 - c]]
        _finger(cg, body, side, name, port, fingers[name], across=ey)
    # Daumen: aus der Seite vorn (vorderste Ecken des 1. und 2. Handrings); diese Ecken rücken
    # auf den Daumen, dort wo er aus der Handseite kommt (ohne schmalen Rand – der kniff die Haut)
    port = [h1[0], h2[0], h2[9], h1[9]]
    f = fingers["Thumb"]
    d = f["pts"][1] - f["pts"][0]
    base = cg.ring_on(body.parts[f"finger_{side}_Thumb"], f["pts"][0] + d * THUMB_BASE, d / np.linalg.norm(d), s * ex)
    for i, q in zip(port, base):
        cg.p[i] = np.asarray(q, np.float64)
    _finger(cg, body, side, "Thumb", port, f, across=s * ex)


def _finger(cg, body, side, name, port, f, across):
    """Finger als Röhre aus 4er-Ringen: Ringe auf Mittel- und Endgelenk und an der Kuppe."""
    part = body.parts[f"finger_{side}_{name}"]
    pts, radii = f["pts"], f["radii"]
    stations = []
    for i in (1, 2):
        d = (pts[i] - pts[i - 1]) / np.linalg.norm(pts[i] - pts[i - 1]) + (pts[i + 1] - pts[i]) / np.linalg.norm(pts[i + 1] - pts[i])
        stations.append((pts[i], d))
    # Spitze: ein Ring auf der Mitte der Kuppe und einer kurz davor (runde Kuppe statt Spitze)
    d3 = (pts[3] - pts[2]) / np.linalg.norm(pts[3] - pts[2])
    stations.append((pts[3], d3))
    stations.append((pts[3] + d3 * 0.6 * radii[3], d3))
    prev = port
    region = f"finger_{side}_{name}"
    for c, d in stations:
        ea, eb = frame(d, across)
        q, _ = S.raycast(part, c, round_dirs(FINGER_4, ea, eb), tmax=0.04, steps=200)
        r = cg.ring(q, region)
        cg.band(prev, r)
        prev = r
    cg.quad(*prev)


def _leg(cg, body, s, side, port, info):
    P = body.parts
    ex, ey, ez = np.eye(3)
    j = body.joints_leg[side]
    hip, knee, ankle = j["hip"], j["knee"], j["ankle"]
    r_an = body.r_leg[3]

    def axis(z):
        if z >= knee[2]:
            t = (hip[2] - z) / (hip[2] - knee[2])
            return hip + (knee - hip) * t
        t = (knee[2] - z) / (knee[2] - ankle[2])
        return knee + (ankle - knee) * t

    z1 = body.crotch - 0.035
    z4 = knee[2] - 0.45 * (knee[2] - ankle[2])
    levels = [(z1, "leg"), (0.5 * (z1 + knee[2]), "leg"), (knee[2], "leg"), (z4, "leg"), (ankle[2], "legfoot"),
              (0.024, "legfoot")]
    dirs = round_dirs(LEG_10, s * ex, ey)
    prev = port
    leg_rings = []
    for i, (z, part) in enumerate(levels):
        c = axis(max(z, ankle[2]))
        c = np.array((c[0], c[1], z))
        pts, _ = S.raycast(P[part + "_" + side], c, dirs, tmax=0.25)
        if part == "legfoot":
            # vorn nicht bis zu den Zehen: dort beginnt der Fuß (Öffnung vorn am Knöchel)
            for k in (0, 1, 2):
                v = pts[k] - c
                if np.linalg.norm(v) > 1.15 * r_an:
                    pts[k] = c + v / np.linalg.norm(v) * 1.15 * r_an
        region = "foot_" + side if i == len(levels) - 1 else "leg_" + side
        r = cg.ring(pts, region)
        # Fuß-Öffnung vorn zwischen Knöchel- und Fersenring (Felder 0 und 1)
        cg.band(prev, r, skip={0, 1} if i == len(levels) - 1 else ())
        leg_rings.append(r)
        prev = r
    g5, g6 = leg_rings[-2], leg_rings[-1]
    info["rings"]["leg_" + side] = leg_rings
    # Sohle unter der Ferse: 2x3 Felder, zwei Ecken in der Mitte
    pf, pb = np.array(cg.p[g6[1]]), np.array(cg.p[g6[6]])
    mid = []
    for t in (1 / 3, 2 / 3):
        q = pf + (pb - pf) * t
        mid.append(cg.add((q[0], q[1], 0.0), "foot_" + side))
    c1, c2 = mid
    for quad in ((g6[0], g6[1], c1, g6[9]), (g6[1], g6[2], g6[3], c1), (g6[9], c1, c2, g6[8]),
                 (c1, g6[3], g6[4], c2), (g6[8], c2, g6[6], g6[7]), (c2, g6[4], g6[5], g6[6])):
        cg.quad(*quad)
    # Fuß: Röhre aus 6er-Ringen nach vorn, vorn ein Deckel aus zwei Feldern
    fs = body.foot_scale
    port = [g5[0], g5[1], g5[2], g6[2], g6[1], g6[0]]
    prev = port
    # flache Querschnitte (wie bei der Hand): Ecken zu den Seitenkanten, nicht oben in die Mitte
    for y, z, half_h in ((-0.045, 0.032, 0.030), (-0.085, 0.024, 0.022), (-0.114, 0.020, 0.017)):
        c = np.array((ankle[0] + s * 0.005, y * fs, z * fs))
        fdirs = flat_dirs(FOOT_6, s * ex, ez, 0.050 * fs, half_h * fs)
        pts, _ = S.raycast(P["foot_" + side], c, fdirs, tmax=0.12)
        r = cg.ring(pts, "foot_" + side)
        cg.band(prev, r)
        prev = r
    cg.quad(prev[0], prev[1], prev[4], prev[5])
    cg.quad(prev[1], prev[2], prev[3], prev[4])


def _head(cg, body, info):
    """Kopf als Würfelkugel (5x5 Felder je Seite), Strahlen aus der Kopfmitte auf die Kopfform ohne
    Ohren und Nase; die Ohren wachsen aus je einem Feld, die Nase ist ein eingesetztes Feld."""
    P = body.parts
    chin = body.chin
    n = GRID
    center = S.head_point(chin, 0.0, 0.012, 0.205)
    aspect = np.array((0.204, 0.184, 0.205))
    lattice = {}
    for i in range(n + 1):
        for j in range(n + 1):
            for k in range(n + 1):
                if 0 < i < n and 0 < j < n and 0 < k < n:
                    continue
                lattice[(i, j, k)] = None
    keys = list(lattice)
    # gleichwinklige Würfelkugel (Felder gleich groß statt an den Ecken gedrängt)
    cube = np.array([(np.array(key) - n / 2) / (n / 2) for key in keys])
    dirs = np.tan(cube * math.pi / 4) * aspect
    pts, ok = S.raycast(P["head_shell"], center, dirs, tmax=0.5)
    pos = {key: pts[i] for i, key in enumerate(keys)}
    # Halsöffnung unten am Kopf genau dort, wo der Hals auf die Kopfunterseite trifft (weiter innen
    # läge sie im Hals – bei dicken Figuren falteten sich Kopf- und Halsring dann ineinander; weiter
    # außen liefe der Hals als Trichter unter das Kinn): von innen nach außen suchen, ab wo unter der
    # Kopfunterseite kein Körper mehr ist
    neck_x = {1: -1.0, 2: -1 / 3, 3: 1 / 3, 4: 1.0}
    neck_y = {2: -1.0, 3: 0.0, 4: 1.0}
    for (i, j) in NECK_PORT:
        for rho in np.linspace(0.8, 2.6, 37) * body.neck_r:
            o = (neck_x[i] * rho, 0.018 + neck_y[j] * rho, chin - 0.2)
            q, hit = S.raycast(P["head_shell"], o, [(0.0, 0.0, 1.0)], tmax=0.5)
            if hit[0] and body.root.eval_points(q - np.array((0.0, 0.0, 0.004)))[0] > 0.0:
                break
        pos[(i, j, 0)] = q[0]

    # Felder der sechs Würfelseiten (Ecken in Reihenfolge um das Feld)
    cells = []
    for a in range(n):
        for b in range(n):
            cells.append(("bottom", (a, b), [(a, b, 0), (a + 1, b, 0), (a + 1, b + 1, 0), (a, b + 1, 0)]))
            cells.append(("top", (a, b), [(a, b, n), (a + 1, b, n), (a + 1, b + 1, n), (a, b + 1, n)]))
            cells.append(("front", (a, b), [(a, 0, b), (a + 1, 0, b), (a + 1, 0, b + 1), (a, 0, b + 1)]))
            cells.append(("back", (a, b), [(a, n, b), (a + 1, n, b), (a + 1, n, b + 1), (a, n, b + 1)]))
            cells.append(("left", (a, b), [(n, a, b), (n, a + 1, b), (n, a + 1, b + 1), (n, a, b + 1)]))
            cells.append(("right", (a, b), [(0, a, b), (0, a + 1, b), (0, a + 1, b + 1), (0, a, b + 1)]))
    neck_cells = {(a, b) for a in (1, 2, 3) for b in (2, 3)}

    def cell_center(cell):
        return np.mean([pos[c] for c in cell[2]], axis=0)

    # Ohren: 2x2 Felder der Seite um die Ohrmitte (ihr Rand = Ring aus 8 Ecken – runde Ohren)
    def side_key(face, a, b):
        return (n, a, b) if face == "left" else (0, a, b)

    ears = {}
    for s, face in ((1, "left"), (-1, "right")):
        ear_c, ear_n, ear_r = S.ear_frame(chin, s)
        blocks = [(a, b) for a in range(n - 1) for b in range(n - 1)]
        a0, b0 = min(blocks, key=lambda ab: np.linalg.norm(pos[side_key(face, ab[0] + 1, ab[1] + 1)] - ear_c))
        ring = [(a0, b0), (a0 + 1, b0), (a0 + 2, b0), (a0 + 2, b0 + 1), (a0 + 2, b0 + 2), (a0 + 1, b0 + 2),
                (a0, b0 + 2), (a0, b0 + 1)]
        ears[face] = ({(a0 + da, b0 + db) for da in (0, 1) for db in (0, 1)}, [side_key(face, a, b) for a, b in ring],
                      side_key(face, a0 + 1, b0 + 1), ear_c, ear_n, ear_r)
    # Nase: das vordere Feld an der Nase
    nose_c, nose_r = S.nose_shape(chin)
    front = [c for c in cells if c[0] == "front"]
    nose_cell = min(front, key=lambda c: np.linalg.norm(cell_center(c) - nose_c))[1]

    # Rand der Ohrfelder als Ellipse um den Ohransatz legen (Winkel gleichmäßig, Reihenfolge bleibt)
    ear_angles = {}
    for face, (block, ring, mid_key, ear_c, ear_n, ear_r) in ears.items():
        u = np.cross(np.array((0.0, 0.0, 1.0)), ear_n)
        u /= np.linalg.norm(u)
        v = np.array((0.0, 0.0, 1.0))
        mid = pos[mid_key]
        ang = np.unwrap([math.atan2((pos[key] - mid) @ v, (pos[key] - mid) @ u) for key in ring])
        step = math.pi / 4 * (1 if ang[-1] > ang[0] else -1)
        start = float(np.mean(ang - step * np.arange(8)))
        ear_angles[face] = [start + step * i for i in range(8)]
        for key, a in zip(ring, ear_angles[face]):
            target = ear_c + u * math.cos(a) * 0.80 * ear_r[1] + v * math.sin(a) * 0.80 * ear_r[2]
            q, _ = S.raycast(P["head_shell"], center, [target - center], tmax=0.5)
            pos[key] = q[0]

    idx = {}
    ear_mids = {e[2] for e in ears.values()}
    for key in keys:
        if key in ((2, 3, 0), (3, 3, 0)) or key in ear_mids:
            continue   # in der Halsöffnung bzw. mitten im Ohransatz
        idx[key] = cg.add(pos[key], "head")
    for face, ab, corners in cells:
        if face == "bottom" and ab in neck_cells:
            continue
        if face in ears and ab in ears[face][0]:
            continue
        if face == "front" and ab == nose_cell:
            continue
        cg.quad(*[idx[c] for c in corners])
    # Ohren: Ringe aus 8 Ecken auf Ellipsen nach außen – Rand der Scheibe, Vorderkante, Rand der
    # Mulde, in der Mulde – und ein Deckel aus 2x2 Feldern am Boden der Mulde
    for face, (block, ring_keys, mid_key, ear_c, ear_n, ear_r) in ears.items():
        ring = [idx[key] for key in ring_keys]
        u = np.cross(np.array((0.0, 0.0, 1.0)), ear_n)
        u /= np.linalg.norm(u)
        v = np.array((0.0, 0.0, 1.0))
        for out, size in EAR_RINGS:
            pts = [ear_c + ear_n * out * ear_r[0] + u * math.cos(a) * size * ear_r[1] + v * math.sin(a) * size * ear_r[2]
                   for a in ear_angles[face]]
            ring = cg.ring_band(ring, pts, "head")
        mid = cg.add(ear_c + ear_n * EAR_CUP * ear_r[0], "head")
        r = ring
        for quad in ((r[0], r[1], mid, r[7]), (r[1], r[2], r[3], mid), (mid, r[3], r[4], r[5]), (r[7], mid, r[5], r[6])):
            cg.quad(*quad)
    # Nase: kleines Feld auf der Nasenkuppe
    cell = [c for c in cells if c[0] == "front" and c[1] == nose_cell][0]
    corners = [idx[c] for c in cell[2]]
    mid = np.mean([cg.p[c] for c in corners], axis=0)
    inner = []
    for c in corners:
        d = cg.p[c] - mid
        target = nose_c + np.array((np.sign(d[0]) * 0.0125, 0.0, np.sign(d[2]) * 0.0115))
        q, _ = S.raycast(P["head"], center, [target - center], tmax=0.5)
        inner.append(q[0])
    cg.inset(corners, inner, "head")
    info["head_center"] = center
    return [idx[(i, j, 0)] for i, j in NECK_PORT]
