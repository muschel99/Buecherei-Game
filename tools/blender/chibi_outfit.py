"""Kleidung und Frisuren der Chibi-Figuren (seit Etappe 5c): eine einfache Grundausstattung.

Kleidung = Hülle aus dem Körpernetz: Die Flächen eines Körperbereichs (z. B. Rumpf und Oberarme
für ein T-Shirt) werden kopiert, entlang der Lichtrichtung (Normale) ein Stück nach außen
geschoben und zu einem geschlossenen Körper gemacht (Außenseite, Innenseite, Saum). Jede Ecke
behält die Gewichte des Körpers – der Stoff bewegt sich genau mit, nichts schaut durch – und
dieselben Formregler (dünn/dick). Dellen (Bauchnabel, zwischen Brust und Po) überbrückt ein
Glätten, das nur nach außen schiebt. Säume liegen genau auf einer Schnittlinie (Ecken am Rand
werden entlang ihrer Kante auf die Linie geschoben).

Rock = eigene Glocke (Ringe von der Taille bis zum Saum), Gewichte zwischen Becken und Beinen.

Frisuren = weiche Grundformen um den Kopf (wie der Körper in chibi_sdf), daraus ein Netz aus
Vierecken (Surface Nets), auf die Form gelegt; hängen ganz am Kopf-Knochen.

Reines numpy bis auf das Anlegen der Blender-Objekte (build_chibi).
"""

import math

import numpy as np

import chibi_sdf as S

# Grundfarben für die Kontrollbilder (in Godot frei wählbar)
PREVIEW_COLORS = {
    "tshirt": (0.86, 0.80, 0.62), "sweater": (0.55, 0.64, 0.52), "trousers": (0.30, 0.34, 0.46),
    "skirt": (0.66, 0.36, 0.30), "shoes": (0.36, 0.24, 0.16),
    "hair": (0.36, 0.24, 0.16),
}
TOPS = ("tshirt", "sweater")
BOTTOMS = ("trousers", "skirt")
HAIRS = ("bob", "bun", "pigtails", "short")
INNER = 0.0018        # Innenseite des Stoffs so weit über der Haut (m)
INNER_BAND = 2        # Innenseite nur so viele Reihen tief ab dem Saum
HAIR_GRID = 0.0095    # Rasterweite der Frisuren (m)
HAIR_HIDDEN = 0.004   # Flächen der Frisur, die so tief im Kopf liegen, entfallen (nie zu sehen)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------------------------------------
# Netz-Hilfen
# ---------------------------------------------------------------------------------------------

def vertex_normals(p, faces):
    """Normalen je Ecke (nach Fläche gewichtet) eines Vierecknetzes."""
    a, b, c, d = (p[faces[:, i]] for i in range(4))
    fn = np.cross(c - a, d - b)
    n = np.zeros_like(p)
    for i in range(4):
        np.add.at(n, faces[:, i], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1), 1e-12)[:, None]


def face_edges(faces):
    """Alle Kanten (a, b) in Umlaufrichtung der Flächen."""
    return np.concatenate([np.stack([faces[:, i], faces[:, (i + 1) % 4]], 1) for i in range(4)])


def neighbor_lists(n, faces):
    e = face_edges(faces)
    e = np.unique(np.sort(e, axis=1), axis=0)
    out = [[] for _ in range(n)]
    for a, b in e:
        out[a].append(b)
        out[b].append(a)
    return [np.array(x, np.int64) for x in out]


def smooth_outward(x, n, nbrs, iterations, factor=0.6):
    """Glätten, das nur nach außen schiebt: Dellen füllen sich, die Form bleibt (Stoff spannt
    über Bauchnabel und Mulden)."""
    for _ in range(iterations):
        avg = np.array([x[nb].mean(axis=0) if len(nb) else x[i] for i, nb in enumerate(nbrs)])
        dn = ((avg - x) * n).sum(axis=1)
        x = x + n * (np.maximum(dn, 0.0) * factor)[:, None]
    return x


# ---------------------------------------------------------------------------------------------
# Kleidung als Hülle
# ---------------------------------------------------------------------------------------------

def face_neighbor_lists(n, faces):
    """Nachbarn je Ecke über gemeinsame Flächen (auch über die Diagonale)."""
    out = [set() for _ in range(n)]
    for f in faces:
        for a in f:
            out[a].update(int(b) for b in f if b != a)
    return [np.array(sorted(x), np.int64) for x in out]


def boundary_loops_neighbors(boundary, m):
    """Je Randecke ihre beiden Nachbarn auf der Saumlinie."""
    nb = [[] for _ in range(m)]
    for a, b in boundary:
        nb[a].append(b)
        nb[b].append(a)
    return nb


def keep_clear(x, n, field, shift, t):
    """Stoff nie näher als t an den Körper: entlang der Normalen hinausschieben (field = Körperform,
    shift = Verschiebung von Armen/Beinen in dieser Form, weil die Formregler ohne sie gespeichert sind)."""
    for _ in range(3):
        d = field.eval_points(x + shift)
        push = np.maximum(t - d, 0.0)
        if push.max() < 1e-5:
            break
        x = x + n * push[:, None]
    return x


def shell(P, faces, W, ao, cuts, offset, fields, shifts, smooth=10, floor=False):
    """Kleidungsstück aus dem Körpernetz.
    P = {Form: Ecken (N, 3)} ("Basis" zuerst), faces = Vierecke, W = Gewichte (N, Knochen),
    ao = Verschattung je Ecke, cuts = Funktionen f(p) (behalten, wo f >= 0), offset(p, n) =
    Abstand der Außenseite je Ecke, fields/shifts = Körperform je Form und Verschiebung von Armen
    und Beinen je Ecke (siehe keep_clear). floor = nie unter den Boden (Schuhsohlen).
    Liefert dict: P (je Form), faces, W, ao, height."""
    base = P["Basis"]
    n_all = len(base)
    fv = np.stack([f(base) for f in cuts], axis=1)
    keep_v = (fv >= 0).all(axis=1)
    keep_f = keep_v[faces].all(axis=1)
    kf = faces[keep_f]
    used = np.unique(kf)
    remap = np.full(n_all, -1, np.int64)
    remap[used] = np.arange(len(used))
    gf = remap[kf]
    # Ränder: Kanten, die nur eine behaltene Fläche haben
    e = face_edges(gf)
    key = np.sort(e, axis=1)
    _, inv, cnt = np.unique(key, axis=0, return_inverse=True, return_counts=True)
    boundary = e[cnt[inv] == 1]
    bverts = np.unique(boundary)
    # Körpernormalen je Form (vom ganzen Körper)
    normals = {s: vertex_normals(p, faces) for s, p in P.items()}
    Pg = {s: p[used].copy() for s, p in P.items()}
    Ng = {s: n[used].copy() for s, n in normals.items()}
    Sg = {s: shifts[s][used].copy() for s in P}
    Wg = W[used].copy()
    aog = ao[used].copy()
    # Randecken genau auf die Schnittlinie schieben (entlang einer Kante oder Flächendiagonale)
    body_nbrs = face_neighbor_lists(n_all, faces)
    for gv in bverts:
        v = used[gv]
        i = int(np.argmin(fv[v]))
        fvi = fv[v, i]
        best, best_u, best_t = None, -1, 0.0
        for u in body_nbrs[v]:
            fu = fv[u, i]
            if fu >= 0:
                continue
            t = fvi / (fvi - fu)
            d = t * np.linalg.norm(base[u] - base[v])
            if best is None or d < best:
                best, best_u, best_t = d, u, min(t, 0.95)
        if best_u < 0:
            continue
        u, t = best_u, best_t
        for s in P:
            Pg[s][gv] = P[s][v] + t * (P[s][u] - P[s][v])
            nn = normals[s][v] + t * (normals[s][u] - normals[s][v])
            Ng[s][gv] = nn / max(np.linalg.norm(nn), 1e-9)
            Sg[s][gv] = shifts[s][v] + t * (shifts[s][u] - shifts[s][v])
        Wg[gv] = W[v] + t * (W[u] - W[v])
        aog[gv] = ao[v] + t * (ao[u] - ao[v])
    m = len(used)
    # Saumlinie glätten (keine Zacken)
    loop_nb = boundary_loops_neighbors(boundary, m)
    for s in P:
        for _ in range(4):
            q = Pg[s].copy()
            for gv in bverts:
                if len(loop_nb[gv]) == 2:
                    q[gv] = 0.5 * Pg[s][gv] + 0.25 * (Pg[s][loop_nb[gv][0]] + Pg[s][loop_nb[gv][1]])
            Pg[s] = q
    g_nbrs = neighbor_lists(m, gf)
    is_rim = np.zeros(m, bool)
    is_rim[bverts] = True
    t_out = offset(Pg["Basis"], Ng["Basis"])
    outer, inner = {}, {}
    for s in P:
        n = Ng[s]
        o = Pg[s] + n * t_out[:, None]
        # glätten (Stoff spannt über Dellen) und dabei nie zu nah an den Körper
        for _ in range(3):
            for _ in range(max(smooth // 3, 1)):
                avg = np.array([o[nb].mean(axis=0) if len(nb) else o[i] for i, nb in enumerate(g_nbrs)])
                o = np.where(is_rim[:, None], o, 0.5 * o + 0.5 * avg)
            o = keep_clear(o, n, fields[s], Sg[s], t_out * 0.85)
        i_ = Pg[s] + n * INNER
        if floor:
            o[:, 2] = np.maximum(o[:, 2], 0.0)
            i_[:, 2] = np.maximum(i_[:, 2], 0.0)
        outer[s], inner[s] = o, i_
    # Innenseite nur als schmaler Streifen am Saum (weiter innen liegt sie unsichtbar unter dem
    # Stoff – so bleibt die Datei klein)
    near = np.zeros(m, bool)
    near[bverts] = True
    for _ in range(INNER_BAND):
        near[np.unique(gf[near[gf].any(axis=1)])] = True
    band_f = gf[near[gf].all(axis=1)]
    band_v = np.unique(band_f)
    inner_index = np.full(m, -1, np.int64)
    inner_index[band_v] = m + np.arange(len(band_v))
    # Saumrand: über die Randkante andersherum als die Außenfläche (zeigt so nach außen)
    rim = np.stack([boundary[:, 1], boundary[:, 0], inner_index[boundary[:, 0]], inner_index[boundary[:, 1]]], axis=1)
    out_faces = np.concatenate([gf, inner_index[band_f][:, ::-1], rim])
    height = Pg["Basis"][:, 2]
    return {"P": {s: np.concatenate([outer[s], inner[s][band_v]]) for s in P}, "faces": out_faces,
            "W": np.concatenate([Wg, Wg[band_v]]), "ao": np.concatenate([aog, aog[band_v]]),
            "height": np.concatenate([height, height[band_v]])}


def front(p, y0=0.0, depth=0.07):
    """0 hinten/seitlich … 1 ganz vorn (für Ausschnitte)."""
    return np.clip(-(p[:, 1] - y0) / depth, 0.0, 1.0) ** 1.5


def garment_specs(body):
    """Schnitte und Abstände der Kleidungsstücke für die Maße von body."""
    cr, T, nb = body.crotch, body.T, body.neck_base
    sx = body.shoulder_x
    wrist = sx + body.upper_arm + body.fore_arm
    fem = body.gender == "female"
    waist = cr + (0.30 if fem else 0.32) * T

    def above(z0):
        return lambda p: p[:, 2] - z0

    def below(z0):
        return lambda p: z0 - p[:, 2]

    def sleeve(x0):
        return lambda p: x0 - np.abs(p[:, 0])

    def neckline(drop, high):
        return lambda p: (nb - high - drop * front(p, 0.01)) - p[:, 2]

    def tshirt_off(p, n):
        # Ärmel etwas weiter
        return 0.0088 + 0.0025 * smoothstep(sx - 0.02, sx + 0.03, np.abs(p[:, 0]))

    def sweater_off(p, n):
        return 0.0108 + 0.002 * smoothstep(sx - 0.02, sx + 0.03, np.abs(p[:, 0]))

    def trousers_off(p, n):
        # unten weiter (gerades Bein), oben eng am Bund
        return 0.0058 + 0.0055 * smoothstep(cr - 0.02, 0.12, p[:, 2])

    def shoes_off(p, n):
        # Sohle bleibt flach auf dem Boden
        return 0.0055 * (1.0 - smoothstep(-0.55, -0.85, n[:, 2]))

    return {
        "tshirt": dict(cuts=[above(cr + 0.15 * T), neckline(0.030 if fem else 0.022, 0.010), sleeve(sx + 0.075)],
                       offset=tshirt_off, smooth=14),
        "sweater": dict(cuts=[above(cr + 0.13 * T), neckline(0.016, 0.004), sleeve(wrist - 0.014)],
                        offset=sweater_off, smooth=16),
        "trousers": dict(cuts=[below(waist), above(0.072)], offset=trousers_off, smooth=10),
        "shoes": dict(cuts=[below(0.082)], offset=shoes_off, smooth=4, floor=True),
    }


# ---------------------------------------------------------------------------------------------
# Rock (Glocke)
# ---------------------------------------------------------------------------------------------

SKIRT_SEGMENTS = 56
SKIRT_FLARE = 0.20     # so viel weiter je Meter nach unten (A-Linie; mehr: Hände schwingen hindurch)
SKIRT_WEIGHT_SMOOTH = 4   # Glätten der vom Körper übernommenen Gewichte (rundum und nach unten)


def _skin_weights_below(points, body_P, body_W, names, z_min, k=6):
    """Anteil linkes und rechtes Bein an den Gewichten der nächsten Körper-Ecken (je Punkt)."""
    idx = {n: i for i, n in enumerate(names)}
    sel = np.where(body_P[:, 2] > z_min)[0]
    bp = body_P[sel]
    legs = {side: body_W[sel][:, [idx[n] for n in names if n.startswith(side) and
                                  any(part in n for part in ("Leg", "Foot", "Toe"))]].sum(axis=1)
            for side in ("Left", "Right")}
    out = np.zeros((len(points), 2))
    for i0 in range(0, len(points), 64):
        p = points[i0:i0 + 64]
        d = np.linalg.norm(p[:, None, :] - bp[None, :, :], axis=2)
        nn = np.argpartition(d, k, axis=1)[:, :k]
        dn = np.take_along_axis(d, nn, axis=1)
        w = 1.0 / (dn + 1e-3) ** 2
        w /= w.sum(axis=1, keepdims=True)
        out[i0:i0 + 64, 0] = (w * legs["Left"][nn]).sum(axis=1)
        out[i0:i0 + 64, 1] = (w * legs["Right"][nn]).sum(axis=1)
    return out


def skirt(bodies, names, limb_offsets, body_P, body_W):
    """Glockenrock: Ringe von der Taille bis über das Knie, außen um Rumpf und Beine gemessen.
    bodies = {Form: Body}, limb_offsets = {Form: {Knochen: Verschiebung}} (wie beim Körper),
    body_P/body_W = Ecken und Gewichte des Körpers (mittlere Form)."""
    body = bodies["medium"]
    cr, T = body.crotch, body.T
    fem = body.gender == "female"
    z_top = cr + (0.30 if fem else 0.32) * T
    z_wide = cr + 0.05 * T
    z_hem = cr - 0.55 * (cr - body.knee_z)
    rows = np.concatenate([np.linspace(z_top, z_wide, 12, endpoint=False), np.linspace(z_wide, z_hem, 16)])
    ang = np.linspace(0.0, 2 * math.pi, SKIRT_SEGMENTS, endpoint=False)
    dirs = np.stack([np.cos(ang), np.sin(ang), np.zeros_like(ang)], axis=1)
    axis_y = 0.02
    out = {}
    for shape, b in bodies.items():
        lower = S.Group("lower", [("union", b.parts["torso"], 0.0), ("union", b.parts["legfoot_Left"], 0.045),
                                  ("union", b.parts["legfoot_Right"], 0.045)])
        pts, r_prev, z_prev = [], None, None
        for z in rows:
            c = np.array((0.0, axis_y, z))
            hit, ok = S.raycast(lower, c + dirs * 0.45, -dirs, tmax=0.45)
            r_body = np.where(ok, np.linalg.norm(hit[:, :2] - c[:2], axis=1), 0.0)
            if z >= z_wide:
                # oben eng an der Taille (unter T-Shirt und Pullover, die 7,5 mm und mehr abstehen)
                off = 0.0025 + 0.0035 * ((z_top - z) / (z_top - z_wide)) ** 2
                r = r_body + off
            else:
                r = np.maximum(r_body + 0.008, r_prev + SKIRT_FLARE * (z_prev - z))
            # rund um den Körper glätten (Bauchnabel, Po-Falte)
            for _ in range(3):
                r = np.maximum(r, 0.5 * r + 0.25 * (np.roll(r, 1) + np.roll(r, -1)))
            r_prev, z_prev = r, z
            pts.append(np.stack([r * np.cos(ang), axis_y + r * np.sin(ang), np.full_like(ang, z)], axis=1))
        out[shape] = np.concatenate(pts)
    n_seg = SKIRT_SEGMENTS
    # Gewichte: oben Becken, nach unten immer mehr die Oberschenkel (nach Seite)
    base = out["medium"]
    z = base[:, 2]
    # (unten fast ganz mit den Beinen – beim Sitzen und bei großen Schritten bleiben die
    # Oberschenkel so unter dem Stoff; vorn und hinten in der Mitte je zur Hälfte)
    leg = 0.95 * smoothstep(z_wide, z_hem, z)
    rad = base[:, :2] - np.array((0.0, axis_y))
    left = smoothstep(-0.4, 0.4, rad[:, 0] / np.maximum(np.linalg.norm(rad, axis=1), 1e-9))   # +x = links
    # dazu mindestens so stark wie die Haut darunter (sonst stößt der Oberschenkel beim großen
    # Schritt vorn durch den Stoff): Gewichte der nächsten Körper-Ecken, rundum und nach unten geglättet
    skin = _skin_weights_below(base, body_P, body_W, names, body.knee_z + 0.03)
    n_rows = len(rows)
    grid = skin.reshape(n_rows, SKIRT_SEGMENTS, 2)
    for _ in range(SKIRT_WEIGHT_SMOOTH):
        ring = 0.5 * grid + 0.25 * (np.roll(grid, 1, axis=1) + np.roll(grid, -1, axis=1))
        grid = ring.copy()
        grid[1:-1] = 0.5 * ring[1:-1] + 0.25 * (ring[:-2] + ring[2:])
    skin = grid.reshape(-1, 2)
    wl = np.maximum(leg * left, skin[:, 0])
    wr = np.maximum(leg * (1.0 - left), skin[:, 1])
    total = np.maximum(wl + wr, 1.0)
    wl, wr = wl / total, wr / total
    W = np.zeros((len(base), len(names)))
    idx = {n: i for i, n in enumerate(names)}
    W[:, idx["Hips"]] = 1.0 - wl - wr
    W[:, idx["LeftUpperLeg"]] = wl
    W[:, idx["RightUpperLeg"]] = wr
    # Formregler: Bein-Verschiebung herausrechnen (die machen in Godot die Knochen)
    keys = {"Basis": base}
    for shape in ("thin", "fat"):
        p = out[shape].copy()
        for bone, d in limb_offsets.get(shape, {}).items():
            if bone in idx:
                p -= W[:, idx[bone]][:, None] * np.asarray(d)[None, :]
        keys[shape] = p
    # Außen- und Innenseite, Saum unten, Bund oben
    # Außenseite: Umlauf so, dass die Flächen nach außen zeigen (Ringe laufen nach unten,
    # Segmente gegen den Uhrzeiger); Innenseite umgekehrt; Bund oben und Saum unten passend dazu
    faces = []
    for r in range(n_rows - 1):
        for s in range(n_seg):
            a = r * n_seg + s
            b = r * n_seg + (s + 1) % n_seg
            faces.append((a, a + n_seg, b + n_seg, b))
    faces = np.array(faces, np.int64)
    m = len(base)
    rim = []
    for s in range(n_seg):
        a, b = s, (s + 1) % n_seg
        rim.append((a, b, b + m, a + m))
        a, b = (n_rows - 1) * n_seg + s, (n_rows - 1) * n_seg + (s + 1) % n_seg
        rim.append((b, a, a + m, b + m))
    rim = np.array(rim, np.int64)
    P = {}
    for s, p in keys.items():
        radial = p - np.array((0.0, axis_y, 0.0))
        radial[:, 2] = 0.0
        radial /= np.maximum(np.linalg.norm(radial, axis=1), 1e-9)[:, None]
        P[s] = np.concatenate([p, p - radial * 0.004])
    return {"P": P, "faces": np.concatenate([faces, faces[:, ::-1] + m, rim]),
            "W": np.concatenate([W, W]), "ao": np.full(2 * m, 0.92), "height": np.concatenate([z, z])}


# ---------------------------------------------------------------------------------------------
# Frisuren
# ---------------------------------------------------------------------------------------------

def _E(chin, c, r):
    return S.Ellipsoid("e", S.head_point(chin, *c), np.array(r) * S.HEAD_K)


def _C(chin, a, b, ra, rb):
    return S.RoundCone("c", S.head_point(chin, *a), S.head_point(chin, *b), ra * S.HEAD_K, rb * S.HEAD_K)


def _B(chin, c, b, r):
    return S.RoundBox("b", S.head_point(chin, *c), np.array(b) * S.HEAD_K, r * S.HEAD_K)


def _cut_below(chin, z_side, z_back):
    """Unterkante der Frisur: an den Seiten z_side, hinten z_back (Kopf-Einheiten)."""
    k = S.HEAD_K

    def f(x, y, z):
        zc = chin + k * (z_side + (z_back - z_side) * np.clip((y / k - 0.0) / 0.18, 0.0, 1.0))
        return zc - z
    return S.Func("cut", f)


def hair_field(style, chin):
    """Abstandsfeld einer Frisur (Kopf-Einheiten wie chibi_sdf.head_group, Kinn auf chin).
    Gesicht bleibt frei (Fenster bis über die Augenbrauen); der Pony hat kleine Kerben (Strähnen)."""
    k = S.HEAD_K

    # Gesichtsfenster: vom Hals bis zur Ponykante (top), half_w breit, mit runden Ecken
    def window(top, half_w, r=0.035):
        return _B(chin, (0.0, -0.30, (top - 0.10) / 2.0), (half_w - r, 0.26 - r, (top + 0.10) / 2.0 - r), r)

    def notches(xs, top, depth):
        """Schmale Kerben von der Ponykante nach oben (quer durch den Pony): einzelne Strähnen."""
        return [("subtract", _E(chin, (x, -0.19, top), (0.009, 0.07, depth)), 0.006 * k) for x in xs]

    cap_front = (0, 0.024, 0.240), (0.224, 0.200, 0.198)   # Haube: vorn 1,5 cm über der Stirn
    if style == "bob":
        items = [
            ("union", _E(chin, *cap_front), 0.0),
            ("union", _E(chin, (0.152, 0.030, 0.140), (0.084, 0.165, 0.150)), 0.06 * k),
            ("union", _E(chin, (-0.152, 0.030, 0.140), (0.084, 0.165, 0.150)), 0.06 * k),
            ("union", _E(chin, (0, 0.085, 0.150), (0.195, 0.140, 0.170)), 0.06 * k),
            ("intersect", _cut_below(chin, 0.040, 0.070), 0.02 * k),
            ("subtract", window(0.262, 0.150), 0.020 * k),
        ] + notches((-0.095, -0.035, 0.035, 0.095), 0.262, 0.040)
    elif style == "pigtails":
        items = [
            ("union", _E(chin, *cap_front), 0.0),
            ("union", _E(chin, (0.160, 0.020, 0.170), (0.070, 0.130, 0.110)), 0.05 * k),
            ("union", _E(chin, (-0.160, 0.020, 0.170), (0.070, 0.130, 0.110)), 0.05 * k),
            ("intersect", _cut_below(chin, 0.090, 0.110), 0.02 * k),
            ("subtract", window(0.262, 0.150), 0.020 * k),
        ] + notches((-0.095, -0.035, 0.035, 0.095), 0.262, 0.040)
        for s in (1, -1):
            # Zöpfe tief hinter den Ohren gebunden, hängen nach unten und etwas nach außen
            items.append(("union", _E(chin, (s * 0.170, 0.110, 0.115), (0.040, 0.040, 0.040)), 0.025 * k))
            items.append(("union", _C(chin, (s * 0.182, 0.118, 0.095), (s * 0.222, 0.128, -0.040), 0.040, 0.020), 0.02 * k))
    elif style == "bun":
        items = [
            ("union", _E(chin, (0, 0.022, 0.240), (0.214, 0.194, 0.188)), 0.0),
            ("intersect", _cut_below(chin, 0.175, 0.105), 0.02 * k),
            ("subtract", window(0.305, 0.178), 0.03 * k),
            ("union", _E(chin, (0, 0.110, 0.420), (0.088, 0.082, 0.078)), 0.03 * k),
        ]
    elif style == "short":
        items = [
            ("union", _E(chin, (0, 0.024, 0.245), (0.218, 0.196, 0.192)), 0.0),
            ("intersect", _cut_below(chin, 0.178, 0.100), 0.02 * k),
            ("subtract", window(0.292, 0.180), 0.03 * k),
        ] + notches((-0.07, 0.0, 0.07), 0.292, 0.030)
    else:
        raise ValueError(style)
    return S.Group("hair_" + style, items)


def grid_field(node, lo, hi, h):
    """Feldwerte auf einem Raster (für Surface Nets)."""
    xs = np.arange(lo[0] - 2 * h, hi[0] + 2 * h, h)
    ys = np.arange(lo[1] - 2 * h, hi[1] + 2 * h, h)
    zs = np.arange(lo[2] - 2 * h, hi[2] + 2 * h, h)
    X, Y, Z = np.meshgrid(xs, ys, zs, indexing="ij")
    pts = np.stack([X.ravel(), Y.ravel(), Z.ravel()], axis=1)
    d = np.empty(len(pts))
    step = 400000
    for i in range(0, len(pts), step):
        d[i:i + step] = node.eval_points(pts[i:i + step])
    return xs, ys, zs, d.reshape(len(xs), len(ys), len(zs))


def surface_nets(node, lo, hi, h):
    """Ecken (N, 3) und Vierecke (Q, 4) der Oberfläche des Feldes im Kasten lo..hi."""
    xs, ys, zs, d = grid_field(node, lo, hi, h)
    inside = d < 0
    nx, ny, nz = d.shape
    cnt = np.zeros((nx - 1, ny - 1, nz - 1), np.uint8)
    for a in (0, 1):
        for b in (0, 1):
            for c in (0, 1):
                cnt += inside[a:nx - 1 + a, b:ny - 1 + b, c:nz - 1 + c]
    active = (cnt > 0) & (cnt < 8)
    ci, cj, ck = np.nonzero(active)
    lin = (ci.astype(np.int64) * (ny - 1) + cj) * (nz - 1) + ck
    acc = np.zeros((len(ci), 3))
    num = np.zeros(len(ci))
    for (a0, b0, c0) in [(a, b, c) for a in (0, 1) for b in (0, 1) for c in (0, 1)]:
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
            acc[m, 0] += (xs[ci] + h * (o1[0] + (t if axis == 0 else 0.0)))[m]
            acc[m, 1] += (ys[cj] + h * (o1[1] + (t if axis == 1 else 0.0)))[m]
            acc[m, 2] += (zs[ck] + h * (o1[2] + (t if axis == 2 else 0.0)))[m]
            num += m
    verts = acc / np.maximum(num, 1)[:, None]
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
            ring.append(np.searchsorted(lin, (cell[0] * (ny - 1) + cell[1]) * (nz - 1) + cell[2]))
        q = np.stack(ring, axis=1)
        q[~first_inside] = q[~first_inside][:, ::-1]
        quads.append(q)
    return verts, np.concatenate(quads)
