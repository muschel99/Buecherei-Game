"""Gemeinsame Bausteine der Bilderbuch-Läden (seit Etappe 4h): Teeladen, Wolleladen, Blumenladen,
Bäckerei und Torhaus bauen sich daraus zusammen (build_storybook_<haus>.py). Jedes Teil ist ein
geschlossener Körper mit weichen Kanten, alles leicht unperfekt – Regeln: docs/STYLE_GUIDE.md
„Bilderbuch-Stil“.

Koordinaten wie bei Pub und Modegeschäft (Blender): Front bei y = 0 zeigt nach -y, das Haus reicht
nach +y, z nach oben. Wände folgen dem Grundriss (Punkte gegen den Uhrzeigersinn, außen rechts der
Laufrichtung):
- wall_matrix(p0, p1, x, z) = Ebene einer Wand (lokal x entlang der Wand ab p0, y nach oben,
  z nach außen) – für Fenster (build_storybook_shop.window), Türen, Ladenfronten.
- canon(p0, p1, x, z) = dieselbe Stelle, aber im Rahmen „Wand bei y = 0, außen -y, oben z“ (wie die
  Front des Modegeschäfts). Teile, die so gebaut werden (Töpfe, Tafeln, Schilder, Fahrrad …),
  setzt placed(...) an jede Wand, auch an schräge Ecken.
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

import build_storybook_shop as FS
import storybook_common as SC
import storybook_lib as SB
import storybook_parts as SP
from storybook_lib import Body

RND = random.Random(7)


def reseed(n):
    """Zufall je Haus fest (gleiches Haus bei jedem Bau)."""
    RND.seed(n)
    FS.RND.seed(n)


# --- Wände und Ebenen ---

def wall_matrix(p0, p1, x=0.0, z=0.0, out=0.0, turn=0.0):
    """Ebene der Wand p0 → p1: lokal x entlang der Wand ab p0, y nach oben, z nach außen.
    x, z, out = Punkt in der Wand (out vor der Wand), turn = Drehung in der Wandebene (Grad)."""
    d = Vector((p1[0] - p0[0], p1[1] - p0[1], 0.0)).normalized()
    n = Vector((d.y, -d.x, 0.0))
    m = Matrix(((d.x, 0.0, n.x, p0[0]), (d.y, 0.0, n.y, p0[1]), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))
    return m @ Matrix.Translation((x, z, out)) @ Matrix.Rotation(math.radians(turn), 4, "Z")


def canon(p0, p1, x=0.0, z=0.0, out=0.0, yaw=0.0):
    """Rahmen „Wand bei y = 0, außen -y, oben z“ an der Stelle x der Wand p0 → p1 (für Teile, die
    wie vor der Front des Modegeschäfts gebaut werden)."""
    d = Vector((p1[0] - p0[0], p1[1] - p0[1], 0.0)).normalized()
    n = Vector((d.y, -d.x, 0.0))
    p = Vector((p0[0], p0[1], 0.0)) + d * x + n * out
    m = Matrix(((d.x, -n.x, 0.0, p.x), (d.y, -n.y, 0.0, p.y), (0.0, 0.0, 1.0, z), (0.0, 0.0, 0.0, 1.0)))
    return m @ Matrix.Rotation(math.radians(yaw), 4, "Z")


def seg_len(p0, p1):
    return math.hypot(p1[0] - p0[0], p1[1] - p0[1])


def placed(coll, matrix, fn, *args, **kw):
    """fn(...) baut Teile im Rahmen canon (Wand bei y = 0); danach alle neuen Objekte (egal in
    welcher Sammlung, z. B. Ampel-Halter und Topf) an die richtige Stelle setzen. coll bleibt
    nur zur Lesbarkeit."""
    before = set(bpy.data.objects)
    out = fn(*args, **kw)
    for o in bpy.data.objects:
        if o not in before:
            o.matrix_world = matrix @ o.matrix_world
    return out


def wall_run(body, p0, p1, z0, z1, thick=0.3, inset=0.0, ext=(0.0, 0.0), step=0.25, dent=0.006):
    """Mauerstück p0 → p1 (Außenfläche auf der Linie, Dicke nach innen); inset = so weit nach innen
    versetzt (Innenverkleidung), ext = an den Enden verlängert."""
    length = seg_len(p0, p1)
    body.box(((length + ext[1] - ext[0]) / 2, (z0 + z1) / 2, -inset - thick / 2), (length + ext[0] + ext[1], z1 - z0, thick),
             step=step, dent=dent, dent_scale=1.5, matrix=wall_matrix(p0, p1))


def opening_cutter(p0, p1, x, z, w, h, turn=0.0, rise=0.0, depth=2.0):
    """Schneidekörper für eine Öffnung (Mitte x, Unterkante z) in der Wand p0 → p1; rise = flacher
    Bogen oben."""
    m = wall_matrix(p0, p1, x, z, 0.0, turn)
    if rise > 0:
        return SB.slab_cutter([(-w / 2, 0.0), (w / 2, 0.0)] + SB.arc_points(w / 2, h, rise), m, -depth / 2, depth)
    return SB.cutter((0, h / 2, 0), (w, h, depth), matrix=m)


def cut(obj, openings, bevel=0.012):
    """Öffnungen [(p0, p1, x, z, w, h, turn, rise), …] aus einem Körper schneiden, dann weiche Kanten."""
    if openings:
        SB.boolean_cut(obj, [opening_cutter(*o) for o in openings])
    if bevel:
        SC.add_bevel(obj, bevel)
    return obj


def settle_free(objects, p, eaves, ridge, party_x=()):
    """Wie storybook_common.settle, aber für beliebige Grundrisse: an Brandwänden (x in party_x)
    wandert nichts zur Seite und nichts sackt, sonst Wellen, Neigung nach vorn, Durchhang oben."""
    seed = Vector((3.1, 7.7, 1.3))
    for obj in objects:
        if obj.type != "MESH":
            continue
        mw = obj.matrix_world
        inv = mw.inverted()
        for v in obj.data.vertices:
            wp = mw @ v.co
            d = noise.noise_vector(wp / p["wavelength"] + seed) * p["wave"]
            keep = 1.0
            for px in party_x:
                keep *= SB.smooth(abs(wp.x - px) / 0.8)
            d.x *= keep
            d.z *= SB.smooth(wp.z / 0.8)
            d.y -= p["lean"] * max(wp.z, 0.0)
            if wp.z > eaves - 1.2:
                d.z -= p["eaves_sag"] * keep * SB.smooth((wp.z - (eaves - 1.2)) / 1.2)
            if wp.z > eaves:
                d.z -= p["roof_sag"] * keep * SB.smooth((wp.z - eaves) / max(0.3, ridge - eaves))
            v.co = inv @ (wp + d)
    for obj in objects:
        if obj.type == "LIGHT":
            obj.location.y -= p["lean"] * max(obj.location.z, 0.0)


# --- Dächer ---

def offset_polygon(pts, offs):
    """Grundriss (gegen den Uhrzeigersinn) je Kante um offs[i] nach innen versetzen (negativ = nach
    außen, für den Dachüberstand)."""
    n = len(pts)
    lines = []
    for i in range(n):
        a, b = Vector(pts[i][:2]), Vector(pts[(i + 1) % n][:2])
        d = (b - a).normalized()
        lines.append((a + Vector((-d.y, d.x)) * offs[i], d))
    out = []
    for k in range(n):
        (a, da), (b, db) = lines[k - 1], lines[k]
        den = da.x * db.y - da.y * db.x
        if abs(den) < 1e-9:
            out.append(b.copy())
        else:
            t = ((b.x - a.x) * db.y - (b.y - a.y) * db.x) / den
            out.append(a + da * t)
    return out


def tile_face(body, b0, b1, t0, t1, rnd, tile_w=0.27, row=0.21, skip=None, lift=0.012):
    """Ziegel/Schieferplatten in versetzten Reihen auf einer Dachfläche (Trapez: Traufe b0 → b1,
    oben t0 → t1). Am Rand werden die Platten passend schmaler (keine Lücken an Graten)."""
    b0, b1, t0, t1 = (Vector(v) for v in (b0, b1, t0, t1))
    d = b1 - b0
    length = d.length
    d.normalize()
    up = (t0 - b0) - d * (t0 - b0).dot(d)
    slope = up.length
    u = up / slope
    n = d.cross(u)
    xa, xb = (t0 - b0).dot(d), (t1 - b0).dot(d)
    frame = Matrix(((d.x, u.x, n.x, b0.x), (d.y, u.y, n.y, b0.y), (d.z, u.z, n.z, b0.z), (0, 0, 0, 1)))
    s, r = 0.02, 0
    while s < slope - 0.12:
        t = min(1.0, (s + 0.16) / slope)
        x0, x1 = xa * t, length + (xb - length) * t
        x = x0 - (0.13 if r % 2 else 0.0)
        while x < x1 - 0.04:
            tw = tile_w * rnd.uniform(0.85, 1.12)
            lo, hi = max(x, x0), min(x + tw, x1)
            cx = (lo + hi) / 2
            if hi - lo > 0.05 and (skip is None or not skip(frame @ Vector((cx, s + 0.15, 0.0)))):
                m = frame @ Matrix.Translation((cx, s + 0.15, lift)) @ Matrix.Rotation(-math.radians(rnd.uniform(2.5, 5.0)), 4, "X") @ \
                    Matrix.Rotation(math.radians(rnd.uniform(-1.5, 1.5)), 4, "Z")
                body.box((0, 0, 0), (hi - lo - 0.01, 0.32, 0.02), step=1, dent=0.003, matrix=m)
            x += tw
        s += row
        r += 1
    return frame


def roof_core(body, low, high, z_low, z_high):
    """Geschlossener Dachkern zwischen dem Traufpolygon (unten) und dem Polygon oben."""
    bm = body.bm
    bot = [bm.verts.new((p.x, p.y, z_low)) for p in low]
    top = [bm.verts.new((p.x, p.y, z_high)) for p in high]
    n = len(bot)
    faces = [bm.faces.new(list(reversed(bot))), bm.faces.new(top)]
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((bot[i], bot[j], top[j], top[i])))
    body._finish_island(bot + top, faces)


def hip_roof(M, C, name, outline, hipped, eaves, rise, run, overhang, mat, cap_mat=None, skip=None, seed=8):
    """Walmdach über einem beliebigen Grundriss: Kanten mit hipped[i] steigen um rise auf run Meter
    nach innen an (mit overhang Dachüberstand), die anderen (Brandwand, hinten) enden senkrecht.
    Oben bleibt eine flache Fläche (von der Straße nicht zu sehen). Grate und Firste mit Wulst."""
    rnd = random.Random(seed)
    low = offset_polygon(outline, [-overhang if h else 0.0 for h in hipped])
    high = offset_polygon(outline, [run if h else 0.0 for h in hipped])
    core = Body(name + " Kern", M[mat], C["roof"], seed=seed, vary=0.03)
    roof_core(core, low, high, eaves - 0.06, eaves + rise - 0.03)
    core.build()
    tiles = Body(name + " Ziegel", M[mat], C["roof"], seed=seed + 1, vary=0.12, bevel=0.005)
    caps = Body(name + " Grate", M[cap_mat or mat], C["roof"], seed=seed + 2, vary=0.06)
    n = len(outline)
    for i in range(n):
        if not hipped[i]:
            continue
        j = (i + 1) % n
        b0, b1 = low[i].to_3d(), low[j].to_3d()
        t0, t1 = high[i].to_3d(), high[j].to_3d()
        b0.z = b1.z = eaves
        t0.z = t1.z = eaves + rise
        tile_face(tiles, b0, b1, t0, t1, rnd, skip=skip)
        caps.tube([t0 + Vector((0, 0, 0.03)), t1 + Vector((0, 0, 0.03))], 0.065, segs=10, wobble=0.03, round_ends=True)
        for k in (i, j):
            # Grat an jeder Ecke zwischen zwei geneigten Flächen (bzw. am Rand zur Brandwand)
            lo, hi = low[k].to_3d(), high[k].to_3d()
            lo.z, hi.z = eaves + 0.02, eaves + rise + 0.03
            caps.tube([lo, hi], 0.06, segs=10, wobble=0.03, round_ends=True)
    tiles.build()
    caps.build()
    return low, high


def pitched_roof(M, C, name, frame, length, span, eaves, pitch, mat, cap_mat=None, ends=(0.1, 0.1), skip=None, seed=8,
                 both=True):
    """Satteldach in einem eigenen Rahmen (lokal x = Firstrichtung, y quer, First bei y = 0, z oben):
    Traufen bei y = -span und +span auf Höhe eaves. frame = Lage im Haus. Liefert die Firsthöhe
    (lokal) und eine Funktion z(y) für die Dachfläche."""
    rnd = random.Random(seed)
    a = math.radians(pitch)
    ridge = eaves + span * math.tan(a)
    slope = span / math.cos(a)
    core = Body(name + " Dachflächen", M[mat], C["roof"], seed=seed, vary=0.04, bevel=0.01)
    tiles = Body(name + " Ziegel", M[mat], C["roof"], seed=seed + 1, vary=0.12, bevel=0.005)
    x0, x1 = -length / 2 - ends[0], length / 2 + ends[1]
    for side in ((-1, 1) if both else (-1,)):
        start = Vector((x0 if side < 0 else x1, side * span, eaves))
        d = Vector((1.0 if side < 0 else -1.0, 0, 0))
        u = Vector((0, -side * span, ridge - eaves)).normalized()
        n = d.cross(u)
        m = frame @ Matrix(((d.x, u.x, n.x, start.x), (d.y, u.y, n.y, start.y), (d.z, u.z, n.z, start.z), (0, 0, 0, 1)))
        core.box((0, 0, 0), (x1 - x0, slope + 0.04, 0.16), step=0.3, dent=0.006,
                 matrix=m @ Matrix.Translation(((x1 - x0) / 2, slope / 2, -0.09)))
        b0 = frame @ start
        b1 = frame @ (start + d * (x1 - x0))
        top = start + u * slope
        tile_face(tiles, b0, b1, frame @ top, frame @ (top + d * (x1 - x0)), rnd, skip=skip)
    core.build()
    tiles.build()
    r = Body(name + " First", M[cap_mat or mat], C["roof"], seed=seed + 2, vary=0.06)
    r.tube([frame @ Vector((x0, 0, ridge + 0.04)), frame @ Vector((0, 0, ridge + 0.06)), frame @ Vector((x1, 0, ridge + 0.04))], 0.08,
           segs=12, wobble=0.03, round_ends=True)
    r.build()
    return ridge, (lambda y: eaves + (span - abs(y)) * math.tan(a))


def chimney(M, C, name, base, size, top, mat, pots=2, seed=11):
    """Schornstein mit Abdeckplatte und Tonköpfen. base = Mitte unten (im Dach), size = (Breite, Tiefe)."""
    rnd = random.Random(seed)
    x, y, z0 = base
    w, d = size
    tt = rnd.uniform(-1.2, 1.2)
    ch = Body(name, M[mat], C["roof"], seed=seed, vary=0.04, bevel=0.012)
    ch.box((x, y, (z0 + top) / 2), (w, d, top - z0), step=0.25, dent=0.006, turn=(tt, rnd.uniform(-1, 1), 0))
    ch.build()
    cp = Body(name + " Abdeckung", M["trim"], C["roof"], seed=seed + 1, bevel=0.012)
    cp.box((x + tt * 0.01, y, top + 0.04), (w + 0.12, d + 0.12, 0.09), step=0.3, dent=0.004, turn=(tt, 0, 0))
    cp.build()
    if pots:
        pb = Body(name + " Töpfe", M["terra"], C["roof"], seed=seed + 2, vary=0.1, bevel=0.004)
        for k in range(pots):
            off = (k - (pots - 1) / 2) * min(0.36, d / pots + 0.05)
            h = 0.34 + 0.07 * k
            pb.lathe([(0.0, 0.0), (0.11, 0.0), (0.095, h * 0.7), (0.112, h * 0.8), (0.11, h), (0.075, h), (0.0, h - 0.02)],
                     (x + tt * 0.012, y + off, top + 0.08), segs=16, dent=0.003, turn=(rnd.uniform(-3, 3), rnd.uniform(-3, 3)))
        pb.build()


# --- Fenster: Stürze, Bänke, Fensterläden ---

def lintel_sill(M, C, name, fm, w, h, mat="stone", lintel=True, sill=True, seed=60):
    """Steinsturz über und Steinbank unter einem Fenster (fm = Ebene der Fensterunterkante)."""
    b = Body(name + " Sturz und Bank", M[mat], C["walls"], seed=seed, vary=0.06, bevel=0.01)
    if lintel:
        b.box((0, h + 0.09, 0.03), (w + 0.26, 0.18, 0.06), step=0.3, dent=0.004, matrix=fm)
    if sill:
        b.box((0, -0.045, 0.07), (w + 0.2, 0.09, 0.14), step=0.3, dent=0.004, matrix=fm)
    b.build()


def shutters(M, C, name, fm, w, h, mat="shutter", open_off=10.0, seed=70):
    """Klappläden aus Lamellen links und rechts, fast flach an die Wand geklappt (open_off = Grad
    Abstand zur Wand). Jeder Laden: Rahmen, Mittelriegel und schräge Lamellen – alles Körper."""
    b = Body(name + " Läden", M[mat], C["windows"], seed=seed, vary=0.05, bevel=0.004)
    lw = w / 2 + 0.02
    phi = math.radians(open_off)
    for side in (-1, 1):
        hinge = Vector((side * (w / 2 + 0.03), 0.0, 0.03))
        lx = Vector((side * math.cos(phi), 0.0, math.sin(phi)))
        ly = Vector((0.0, 1.0, 0.0))
        lz = lx.cross(ly)
        leaf = fm @ Matrix(((lx.x, ly.x, lz.x, hinge.x), (lx.y, ly.y, lz.y, hinge.y), (lx.z, ly.z, lz.z, hinge.z), (0, 0, 0, 1)))

        def lb(c, s, rot=0.0):
            b.box(c, s, step=0.4, dent=0.002, matrix=leaf @ Matrix.Translation(c) @ Matrix.Rotation(math.radians(rot), 4, "X") @
                  Matrix.Translation(Vector(c) * -1.0))
        for cx in (0.03, lw - 0.03):
            lb((cx, h / 2, 0.0), (0.06, h, 0.035))
        for cy in (0.03, h / 2, h - 0.03):
            lb((lw / 2, cy, 0.0), (lw - 0.08, 0.06, 0.03))
        # Lamellen zwischen den Riegeln, schräg gestellt
        y = 0.08
        while y < h - 0.08:
            if abs(y - h / 2) > 0.05:
                lb((lw / 2, y, 0.0), (lw - 0.1, 0.045, 0.01), rot=35.0)
            y += 0.055
    b.build()


# --- Tür und Ladenfront ---

def door(M, C, name, fm, half, head, mat, mat_frame, glazed=True, transom="bars", dz=-0.28, seed=30, panes=(2, 2)):
    """Ladentür in flacher Nische (fm = Wandebene, Mitte der Tür, Unterkante 0). Breite Pfosten vorn
    (überlappen den Schaufensterrahmen auch bei schiefer Wand), Nischenwände bis unter den Kopf,
    Nischendecke, Zarge, Türblatt füllt die Zarge (5 mm Überlappung), Glas oder Füllungen,
    Oberlicht in der Ebene des Türblatts (bars = Sprossen, lattice = Rauten, none = Holzfeld),
    flache Platte davor (2,5 cm, keine Stufe)."""
    lift = 0.025
    zi = half - 0.06                       # Innenkante der Zarge
    top = 2.2 + lift + 0.08                # Oberkante der Zarge
    b = Body(name + " Tür und Rahmen", M[mat], C["shop"], seed=seed, vary=0.04, bevel=0.008)

    def fb(c, s):
        b.box(c, s, step=0.3, dent=0.003, matrix=fm)
    for sx in (-1, 1):
        fb((sx * (half + 0.09), head / 2, 0.0), (0.18, head, 0.2))
        fb((sx * (half - 0.02), head / 2, -0.16), (0.04, head, 0.28))
    fb((0, head - 0.02, -0.18), (2 * half, 0.04, 0.36))
    # Türblatt
    for sx in (-1, 1):
        fb((sx * (zi - 0.05), 1.1 + lift, dz), (0.11, 2.2, 0.05))
    for z, h in ((0.17, 0.34), (0.98, 0.1), (2.15, 0.12)):
        fb((0, z + lift, dz), (2 * (zi - 0.1), h, 0.05))
    fb((0, 0.635 + lift, dz - 0.004), (2 * (zi - 0.09), 0.62, 0.04))
    fb((0, 0.62 + lift, dz + 0.028), (2 * (zi - 0.21), 0.38, 0.02))
    if glazed:
        for i in range(1, panes[0]):
            fb((-(zi - 0.1) + 2 * (zi - 0.1) * i / panes[0], 1.56 + lift, dz), (0.03, 1.1, 0.045))
        for i in range(1, panes[1]):
            fb((0, 1.03 + 1.06 * i / panes[1] + lift, dz), (2 * (zi - 0.1), 0.03, 0.045))
    else:
        fb((0, 1.56 + lift, dz - 0.004), (2 * (zi - 0.09), 1.12, 0.04))
        fb((0, 1.56 + lift, dz + 0.028), (2 * (zi - 0.21), 0.82, 0.02))
    # Oberlicht über der Tür, in der Ebene des Türblatts
    has_transom = head - 0.07 - top > 0.12
    if has_transom:
        fb((0, head - 0.07, dz), (2 * half - 0.02, 0.06, 0.06))
        if transom == "bars":
            for i in (1, 2):
                fb((-half + 2 * half * i / 3, (top + head - 0.07) / 2, dz), (0.03, head - 0.07 - top, 0.045))
        elif transom == "none":
            fb((0, (top + head - 0.07) / 2, dz - 0.004), (2 * half - 0.04, head - 0.07 - top, 0.04))
    else:
        fb((0, (top + head) / 2, dz), (2 * half - 0.02, head - top + 0.01, 0.06))
    b.build()
    z = Body(name + " Zarge", M[mat_frame], C["shop"], seed=seed + 1, vary=0.03, bevel=0.012)
    for sx in (-1, 1):
        z.box((sx * (zi + 0.04), 1.1 + lift, dz), (0.08, 2.2, 0.14), step=0.3, dent=0.002, matrix=fm)
    z.box((0, 2.24 + lift, dz), (2 * zi + 0.16, 0.08, 0.14), step=0.3, dent=0.002, matrix=fm)
    z.build()
    if transom == "lattice" and has_transom:
        lat = Body(name + " Oberlicht Rauten", M[mat_frame], C["shop"], seed=seed + 2, vary=0.03)
        h = head - 0.07 - top
        n = 5
        for k in range(-n, n + 1):
            for sgn in (-1, 1):
                # Diagonalen im Rechteck (Breite 2·half, Höhe h), an den Rändern abgeschnitten
                xs = k * (2 * half) / n
                p0, p1 = Vector((xs, 0.0)), Vector((xs + sgn * h, h))
                pts = clip_segment(p0, p1, -half + 0.02, half - 0.02, 0.0, h)
                if pts:
                    a, c = pts
                    lat.tube([fm @ Vector((a.x, top + a.y, dz)), fm @ Vector((c.x, top + c.y, dz))], 0.008, segs=6)
        lat.build()
    g = Body(name + " Glas", M["glass"], C["shop"], seed=seed + 3)
    if glazed:
        g.box((0, 1.565 + lift, dz), (2 * (zi - 0.09), 1.13, 0.006), step=10, dent=0, matrix=fm)
    if has_transom and transom != "none":
        g.box((0, (top + head - 0.07) / 2, dz), (2 * half - 0.04, head - 0.07 - top + 0.02, 0.006), step=10, dent=0, matrix=fm)
    if g.bm.verts:
        g.build()
    else:
        g.bm.free()
    k = Body(name + " Knauf und Briefschlitz", M["gold"], C["shop"], seed=seed + 4, bevel=0.003)
    k.blob(fm @ Vector((zi - 0.18, 1.02 + lift, dz + 0.06)), 0.03, subdiv=2, lump=0.05)
    k.box((0, 0.95 + lift, dz + 0.035), (0.26, 0.04, 0.02), step=1, dent=0.001, matrix=fm)
    k.build()
    st = Body(name + " Platte", M["stone"], C["shop"], seed=seed + 5, vary=0.06, bevel=0.012)
    st.box((0, 0.0125, 0.06), (2 * half + 0.16, 0.025, 0.62), step=0.3, dent=0.002, matrix=fm)
    st.build()


def clip_segment(p0, p1, x0, x1, y0, y1):
    """Strecke p0-p1 auf ein Rechteck zuschneiden (Liang-Barsky); None = ganz außerhalb."""
    t0, t1 = 0.0, 1.0
    d = p1 - p0
    for p, q in ((-d.x, p0.x - x0), (d.x, x1 - p0.x), (-d.y, p0.y - y0), (d.y, y1 - p0.y)):
        if abs(p) < 1e-12:
            if q < 0:
                return None
            continue
        r = q / p
        if p < 0:
            t0 = max(t0, r)
        else:
            t1 = min(t1, r)
        if t0 > t1:
            return None
    if (t1 - t0) * d.length < 0.03:
        return None
    return p0 + d * t0, p0 + d * t1


def shop_window(M, C, name, fm, ww, mat, head=2.75, sill=0.6, transom=2.2, transom_bars=4, mullions=1, seed=22):
    """Schaufenster (fm = Wandebene, Mitte unten): Brüstung mit Feldern, Bank, Pfosten, Kämpfer,
    Sprossen im Oberlicht, Mittelpfosten, Glas – alles Körper, Glas reicht in die Rahmen."""
    fr = Body(name + " Rahmen", M[mat], C["shop"], seed=seed, vary=0.03, bevel=0.008)
    gl = Body(name + " Glas", M["glass"], C["shop"], seed=seed + 1)

    def fb(c, sz):
        fr.box(c, sz, step=0.3, dent=0.003, matrix=fm)
    fb((0, sill / 2, 0.1), (ww, sill, 0.16))
    for px in (-ww / 2 + 0.14, ww / 2 - 0.14):
        fb((px, sill / 2, 0.19), (0.03, sill - 0.22, 0.02))
    for pz in (0.11, sill - 0.11):
        fb((0, pz, 0.19), (ww - 0.25, 0.03, 0.02))
    fb((0, sill + 0.02, 0.12), (ww + 0.04, 0.07, 0.22))
    fb((-ww / 2 + 0.04, (sill + head) / 2, 0.06), (0.08, head - sill, 0.1))
    fb((ww / 2 - 0.04, (sill + head) / 2, 0.06), (0.08, head - sill, 0.1))
    fb((0, head - 0.035, 0.06), (ww, 0.07, 0.1))
    if transom:
        fb((0, transom, 0.06), (ww - 0.08, 0.07, 0.1))
        for i in range(1, transom_bars):
            fb((-ww / 2 + 0.08 + (ww - 0.16) * i / transom_bars, (transom + head) / 2, 0.05), (0.03, head - transom, 0.06))
    for i in range(1, mullions + 1):
        fb((-ww / 2 + ww * i / (mullions + 1), ((transom or head) + sill) / 2, 0.05), (0.05, (transom or head) - sill, 0.07))
    gl.box((0, (sill + head) / 2, 0.03), (ww - 0.1, head - sill, 0.006), step=10, dent=0.0, matrix=fm)
    fr.build()
    gl.build()


def fascia(M, C, name, fm, length, z0, height, mat, signs=(), depth=0.3, cornice=True, seed=24):
    """Geschlossener Schildkasten über der Ladenfront (fm = Wandebene, Mitte; lokal x quer), oben
    ein Gesims. signs = [(Mitte x, Breite, Material, Seitenverhältnis Breite/Höhe)] – Bilder der
    Entwicklerin als dünne Platten vorn auf dem Kasten."""
    b = Body(name, M[mat], C["shop"], seed=seed, vary=0.04, bevel=0.012)
    b.box((0, z0 + height / 2, depth / 2 - 0.06), (length, height, depth + 0.12), step=0.3, dent=0.003, matrix=fm)
    if cornice:
        b.box((0, z0 + height + 0.05, depth / 2 - 0.02), (length + 0.08, 0.1, depth + 0.1), step=0.3, dent=0.004, matrix=fm)
        b.box((0, z0 + height + 0.13, depth / 2 + 0.01), (length + 0.14, 0.07, depth + 0.16), step=0.3, dent=0.004, matrix=fm)
    b.build()
    for k, (xc, w, image, aspect) in enumerate(signs):
        h = min(w / aspect, height - 0.06)
        w = h * aspect
        s = Body("%s Schild %d" % (name, k + 1), image, C["shop"], seed=seed + 1 + k, vary=0.0)
        s.panel(fm @ Matrix.Translation((xc, z0 + height / 2, depth - 0.005)) @ Matrix.Rotation(math.radians(RND.uniform(-0.3, 0.3)), 4, "Z"),
                w, h, 0.045)
        s.build()


def pilaster(M, C, name, fm, x, head, top, mat, width=0.3, seed=26):
    """Pilaster der Ladenfront mit Sockel, Füllung und Kapitell (fm = Wandebene, x = Mitte)."""
    b = Body(name, M[mat], C["shop"], seed=seed, vary=0.04, bevel=0.012)
    b.box((x, head / 2, 0.1), (width, head, 0.2), step=0.25, dent=0.004, matrix=fm)
    b.box((x, 0.17, 0.12), (width + 0.06, 0.34, 0.24), step=0.3, dent=0.004, matrix=fm)
    for (px0, px1, pz0, pz1) in ((-width / 2 + 0.05, -width / 2 + 0.08, 0.5, head - 0.35), (width / 2 - 0.08, width / 2 - 0.05, 0.5, head - 0.35),
                                 (-width / 2 + 0.05, width / 2 - 0.05, 0.47, 0.5), (-width / 2 + 0.05, width / 2 - 0.05, head - 0.35, head - 0.32)):
        b.box((x + (px0 + px1) / 2, (pz0 + pz1) / 2, 0.21), (px1 - px0, pz1 - pz0, 0.025), step=0.3, dent=0.002, matrix=fm)
    b.box((x, head - 0.1, 0.16), (width + 0.08, 0.2, 0.32), step=0.3, dent=0.004, matrix=fm)
    if top > head:
        b.box((x, (head + top) / 2, 0.16), (width + 0.1, top - head, 0.34), step=0.3, dent=0.004, matrix=fm)
    b.build()


# --- Deko: Blumenampel, Fahrrad, Markise ---

def hanging_basket(M, C, name, x, z, reach=0.5, drop=0.42, radius=0.17, mat="pot", seed=1):
    """Blumenampel ohne Pflanzen (Rahmen canon: Wand bei y = 0, außen -y): Wandplatte, Arm mit
    Strebe und Schnecke aus Schmiedeeisen, Haken mit Ring, drei Ketten, bauchiger Topf mit Erde."""
    ir = Body(name + " Halter", M["lamp_iron"], C["deco"], seed=seed, vary=0.03, bevel=0.004)
    ir.box((x, -0.012, z - 0.1), (0.07, 0.024, 0.3), step=1, dent=0.001)
    hook = Vector((x, -reach, z + 0.02))
    ir.tube([(x, -0.02, z), (x, -reach * 0.5, z + 0.035), hook], 0.013, segs=8, smooth=2, round_ends=True)
    ir.tube([(x, -0.02, z - 0.22), (x, -reach * 0.42, z - 0.08), (x, -reach * 0.8, z + 0.01)], 0.009, segs=8, smooth=2, round_ends=True)
    SP.scroll(ir, (x, -0.17, z - 0.06), 0.05, x, turns=1.2, thick=0.006, start=0.8)
    ir.blob(hook + Vector((0, -0.02, 0.0)), 0.016, subdiv=1, lump=0.0)
    ring = hook + Vector((0, 0, -0.07))
    ir.tube([hook, ring], 0.005, segs=6, round_ends=True)
    ir.lathe([(0.0, -0.012), (0.018, -0.006), (0.018, 0.006), (0.0, 0.012)], ring, segs=10)
    h = radius * 0.95
    base = ring + Vector((0, 0, -drop - h))
    rim = radius * 1.06
    for k in range(3):
        a = math.radians(90 + 120 * k)
        p = base + Vector((math.cos(a) * rim * 0.92, math.sin(a) * rim * 0.92, h + 0.005))
        ir.tube([ring, p], 0.0035, segs=5, round_ends=True)
    ir.build()
    SC.pot(M, C["pots"], name + " Topf", tuple(base), radius, h, seed + 3, mat=mat, style="bowl")


def bicycle(M, C, name, x, y, seed=90):
    """Hollandrad mit Körben (Rahmen canon: Wand bei y = 0, außen -y), parallel zur Wand, Front
    nach +x. Steht auf dem Hinterbau-Doppelständer: Vorderrad und beide Ständerfüße auf dem Boden,
    das Hinterrad 2 cm angehoben – so steht ein Rad wirklich. Alles Körper."""
    R = 0.34
    xf, xr = x + 0.56, x - 0.56
    fa = Vector((xf, y, R))                  # Vorderachse (Reifen berührt den Boden)
    ra = Vector((xr, y, R + 0.02))           # Hinterachse (Ständer hebt das Hinterrad an)
    bb = Vector((x - 0.12, y, 0.29))         # Tretlager
    st = bb + Vector((-0.2, 0, 0.56))        # Sattelrohr oben
    ht_top = Vector((xf - 0.24, y, 0.96))
    ht_bot = Vector((xf - 0.18, y, 0.78))
    frame = Body(name + " Rahmen", M["bike"], C["deco"], seed=seed, vary=0.03, bevel=0.003)
    frame.tube([ht_top, ht_bot], 0.022, segs=10, round_ends=True)
    frame.tube([bb, st], 0.017, segs=10, round_ends=True)
    # Tiefer Einstieg: zwei geschwungene Rohre vom Steuerrohr zum Tretlager
    for dz in (0.0, 0.07):
        frame.tube([ht_bot + Vector((0.0, 0, 0.04 + dz)), ht_bot + Vector((-0.2, 0, -0.18 + dz)), bb + Vector((0.2, 0, 0.06 + dz * 0.6)),
                    bb + Vector((0.02, 0, 0.02 + dz * 0.3))], 0.016, segs=10, smooth=2, round_ends=True)
    for dy in (-0.055, 0.055):
        frame.tube([bb + Vector((0, dy * 0.5, 0)), ra + Vector((0, dy, 0))], 0.011, segs=8, round_ends=True)
        frame.tube([st + Vector((0, dy * 0.4, -0.06)), ra + Vector((0, dy, 0))], 0.01, segs=8, round_ends=True)
        # Gabel: vom Steuerrohr leicht nach vorn gebogen zur Vorderachse
        frame.tube([ht_bot + Vector((0, dy * 0.5, 0)), ht_bot.lerp(fa, 0.6) + Vector((0.03, dy, 0)), fa + Vector((0, dy, 0))], 0.011, segs=8,
                   smooth=2, round_ends=True)
    # Schutzbleche
    for c, a0, a1 in ((fa, -25, 200), (ra, -20, 205)):
        pts = [c + Vector((math.cos(math.radians(a)) * (R + 0.035), 0, math.sin(math.radians(a)) * (R + 0.035))) for a in range(a0, a1 + 1, 15)]
        frame.tube(pts, 0.022, segs=8, round_ends=True)
    # Kettenschutz
    frame.tube([bb + Vector((0.06, -0.07, 0.02)), ra + Vector((0.06, -0.07, 0.0))], 0.035, segs=10, round_ends=True)
    frame.build()
    ch = Body(name + " Chrom", M["chrome"], C["deco"], seed=seed + 1, vary=0.02, bevel=0.002)
    tire = Body(name + " Reifen", M["rubber"], C["deco"], seed=seed + 2, vary=0.02)
    for c in (fa, ra):
        # Reifen und Felge als geschlossene Ringe (ohne Fuge)
        loop_tube(tire, [c + Vector((math.cos(a) * (R - 0.024), 0, math.sin(a) * (R - 0.024))) for a in [math.radians(k * 6) for k in range(60)]],
                  0.024, segs=10, axis=(0, 1, 0))
        loop_tube(ch, [c + Vector((math.cos(a) * (R - 0.055), 0, math.sin(a) * (R - 0.055))) for a in [math.radians(k * 8) for k in range(45)]],
                  0.009, segs=6, axis=(0, 1, 0))
        ch.lathe([(0.0, -0.05), (0.025, -0.045), (0.02, 0.0), (0.025, 0.045), (0.0, 0.05)], c, segs=12, turn=(90, 0))
        for k in range(28):
            a = math.radians(k * 360 / 28 + 4)
            side = 0.035 if k % 2 else -0.035
            ch.tube([c + Vector((0, side, 0)), c + Vector((math.cos(a) * (R - 0.06), 0, math.sin(a) * (R - 0.06)))], 0.0022, segs=4)
    tire.build()
    # Lenker (nach hinten geschwungen), Vorbau, Sattelstütze, Kurbel, Pedale, Kette
    stem = ht_top + Vector((-0.03, 0, 0.1))
    ch.tube([ht_top, stem], 0.014, segs=8, round_ends=True)
    ch.tube([stem + Vector((-0.2, -0.28, 0.06)), stem + Vector((-0.04, -0.2, 0.02)), stem, stem + Vector((-0.04, 0.2, 0.02)),
             stem + Vector((-0.2, 0.28, 0.06))], 0.011, segs=8, smooth=2, round_ends=True)
    ch.tube([st, st + Vector((-0.04, 0, 0.14))], 0.012, segs=8, round_ends=True)
    ch.lathe([(0.0, -0.006), (0.1, -0.004), (0.1, 0.004), (0.0, 0.006)], bb + Vector((0, -0.085, 0)), segs=24, turn=(90, 0))
    for sgn in (-1, 1):
        foot = bb + Vector((sgn * 0.06, sgn * 0.1, -sgn * 0.15))
        ch.tube([bb + Vector((0, sgn * 0.09, 0)), foot], 0.01, segs=6, round_ends=True)
        ch.box(tuple(foot + Vector((0, sgn * 0.05, 0))), (0.1, 0.08, 0.025), step=1, dent=0.001)
    for dz in (0.085, -0.085):
        ch.tube([bb + Vector((0, -0.085, dz)), ra + Vector((0, -0.085, dz * 0.45))], 0.004, segs=5)
    ch.lathe([(0.0, -0.005), (0.045, -0.004), (0.045, 0.004), (0.0, 0.005)], ra + Vector((0, -0.085, 0)), segs=16, turn=(90, 0))
    # Doppelständer: zwei Beine von der Hinterachse auf den Boden
    for sgn in (-1, 1):
        ch.tube([ra + Vector((0.04, sgn * 0.06, -0.03)), Vector((ra.x + 0.1, y + sgn * 0.18, 0.012))], 0.01, segs=6, round_ends=True)
    # Gepäckträger hinten: Plattform über dem Hinterrad (weit hinten, frei vom Sattelrohr), zwei
    # Beine zur Hinterachse, vorn zwei kurze Streben zu den Sattelstreben
    rack_z = ra.z + R + 0.075                # knapp über dem hinteren Schutzblech
    rx0, rx1 = xr - 0.22, xr + 0.2
    for dy in (-0.1, 0.1):
        ch.tube([Vector((rx0, y + dy, rack_z)), Vector((rx1, y + dy, rack_z))], 0.007, segs=6, round_ends=True)
        ch.tube([ra + Vector((0.0, dy * 0.7, 0)), Vector((rx0 + 0.02, y + dy, rack_z))], 0.007, segs=6, round_ends=True)
        # vorn an die Sattelstreben (dort, wo sie die Höhe des Trägers kreuzen)
        ch.tube([Vector((rx1, y + dy, rack_z)), Vector((st.x - 0.01, y + dy * 0.3, rack_z))], 0.006, segs=6, round_ends=True)
    for xx in (rx0 + 0.01, (rx0 + rx1) / 2, rx1 - 0.01):
        ch.tube([Vector((xx, y - 0.1, rack_z)), Vector((xx, y + 0.1, rack_z))], 0.006, segs=6, round_ends=True)
    # Klingel
    ch.lathe([(0.0, 0.0), (0.028, 0.004), (0.03, 0.018), (0.0, 0.03)], stem + Vector((-0.06, -0.16, 0.035)), segs=12)
    # Vorderer Korbträger: zwei Streben von der Achse und eine vom Steuerrohr zu einem Ring unter dem
    # Korb (der Korb sitzt knapp über dem Schutzblech, unter dem Lenker)
    fb_c = Vector((xf + 0.04, y, R + R + 0.035 + 0.05))     # Mitte unter dem vorderen Korb
    loop_tube(ch, [fb_c + Vector((math.cos(a) * 0.13, math.sin(a) * 0.13, -0.006)) for a in [2 * math.pi * k / 24 for k in range(24)]], 0.006,
              segs=6)
    for dy in (-0.09, 0.09):
        ch.tube([fa + Vector((0.01, dy, 0)), fb_c + Vector((0.02, dy, -0.006))], 0.006, segs=6, round_ends=True)
    # hintere Strebe vom Steuerrohr unter dem Korbboden hindurch zum Ring
    ch.tube([Vector((xf - 0.165, y, 0.8)), Vector((xf - 0.12, y, 0.745)), fb_c + Vector((-0.13, 0, -0.006))], 0.007, segs=6, smooth=1,
            round_ends=True)
    # Lampe vorn am Korbträger (schaut nach vorn)
    lamp = fb_c + Vector((0.2, 0, -0.04))
    ch.tube([fb_c + Vector((0.12, 0, -0.006)), lamp + Vector((-0.03, 0, 0))], 0.006, segs=6, round_ends=True)
    ch.lathe([(0.0, -0.03), (0.04, -0.02), (0.045, 0.03), (0.0, 0.035)], lamp, segs=12, turn=(0, 90))
    ch.build()
    sad = Body(name + " Sattel und Griffe", M["saddle"], C["deco"], seed=seed + 3, vary=0.04)
    sad.blob(tuple(st + Vector((-0.06, 0, 0.17))), 0.1, subdiv=2, lump=0.03, scale=(1.25, 0.85, 0.32))
    for sgn in (-1, 1):
        sad.tube([stem + Vector((-0.17, sgn * 0.27, 0.055)), stem + Vector((-0.24, sgn * 0.3, 0.07))], 0.016, segs=8, round_ends=True)
    sad.build()
    # Runde Weidenkörbe: vorn auf dem Träger, hinten weit hinten auf dem Gepäckträger (unter dem
    # Sattel bleibt Luft, die Sattelstütze bleibt frei)
    round_basket(M, C, name + " Korb vorn", fb_c, 0.15, 0.17, 0.19, seed + 4)
    round_basket(M, C, name + " Korb hinten", Vector((xr - 0.07, y, rack_z + 0.007)), 0.14, 0.16, 0.17, seed + 6)


def loop_tube(body, points, radius, segs=6, axis=(0, 0, 1), tint=None):
    """Geschlossene Röhre entlang einer geschlossenen Punktfolge (Reifen, Rute im Korb, Ring) – ein
    Körper ohne Deckel und ohne Fuge. axis = Richtung, um die der Ring läuft (für gleichmäßige
    Querschnitte, z. B. (0, 1, 0) für ein Rad parallel zur Wand)."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    ax = Vector(axis).normalized()
    bm = body.bm
    rings = []
    for i, p in enumerate(pts):
        d = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        side = d.cross(ax)
        if side.length < 1e-6:
            side = d.orthogonal()
        side.normalize()
        up = side.cross(d).normalized()
        rings.append([bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * radius) for a in [2 * math.pi * k / segs for k in range(segs)]])
    faces = []
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(segs):
            k1 = (k + 1) % segs
            faces.append(bm.faces.new((a[k], a[k1], b[k1], b[k])))
    body._finish_island([v for r in rings for v in r], faces, tint)
    return faces


def round_basket(M, C, name, base, r0, r1, h, seed, stakes=18, coll="deco"):
    """Runder Weidenkorb mit echtem Flechtmuster (alles Körper): geflochtener Boden, senkrechte
    Staken, waagerechte Ruten, die abwechselnd vor und hinter den Staken laufen (jede Reihe
    versetzt), oben ein gedrehter Rand aus zwei Strängen. base = Mitte unten, r0/r1 = Radius
    unten/oben, h = Höhe; stakes gerade Zahl."""
    rnd = random.Random(seed)
    base = Vector(base)
    b = Body(name, M["wicker"], C[coll], seed=seed, vary=0.12)

    def rad(z):
        return r0 + (r1 - r0) * z / h
    # Boden: Scheibe mit Ringen obendrauf (wie spiralig geflochten)
    b.lathe([(0.0, 0.0), (r0 + 0.002, 0.0), (r0 + 0.006, 0.008), (r0 + 0.002, 0.016), (0.0, 0.016)], base, segs=36)
    rr = 0.02
    while rr < r0 - 0.012:
        loop_tube(b, [base + Vector((math.cos(a) * rr, math.sin(a) * rr, 0.017)) for a in [2 * math.pi * k / max(12, int(rr * 160)) for k in
                                                                                         range(max(12, int(rr * 160)))]], 0.004, segs=5)
        rr += 0.016
    # Staken
    for k in range(stakes):
        a = 2 * math.pi * k / stakes
        d = Vector((math.cos(a), math.sin(a), 0.0))
        b.tube([base + d * (r0 - 0.004) + Vector((0, 0, 0.008)), base + d * rad(h) + Vector((0, 0, h))], 0.0045, segs=6, round_ends=True)
    # Ruten: über und unter den Staken, Reihe für Reihe versetzt
    row = 0.0145
    n_rows = int((h - 0.03) / row)
    m = stakes * 4
    for j in range(n_rows):
        z = 0.024 + j * row
        wob = rnd.uniform(0, 2 * math.pi)
        pts = []
        for i in range(m):
            a = 2 * math.pi * i / m
            off = 0.0055 * math.cos(stakes * a / 2 + j * math.pi)
            dz = 0.0015 * math.sin(a * 3 + wob)
            pts.append(base + Vector((math.cos(a) * (rad(z) + off), math.sin(a) * (rad(z) + off), z + dz)))
        loop_tube(b, pts, 0.0062, segs=5)
    # Rand: zwei umeinander gedrehte Stränge
    m = 96
    for strand in (0, 1):
        pts = []
        for i in range(m):
            a = 2 * math.pi * i / m
            t = a * 16 + strand * math.pi
            r = rad(h) + 0.007 * math.cos(t)
            pts.append(base + Vector((math.cos(a) * r, math.sin(a) * r, h + 0.007 * math.sin(t))))
        loop_tube(b, pts, 0.0075, segs=6)
    b.build()


def basket(M, C, name, base, size, seed):
    """Weidenkorb (offen, mit Boden und Rand), Unterkante base."""
    sx, sy, sz = size
    b = Body(name, M["wicker"], C["deco"], seed=seed, vary=0.06, bevel=0.006)
    w = 0.018
    b.box(tuple(base + Vector((0, 0, w / 2))), (sx - 0.02, sy - 0.02, w), step=0.1, dent=0.002)
    for sgn in (-1, 1):
        b.box(tuple(base + Vector((sgn * (sx / 2 - w / 2), 0, sz / 2))), (w, sy, sz), step=0.06, dent=0.003)
        b.box(tuple(base + Vector((0, sgn * (sy / 2 - w / 2), sz / 2))), (sx - 2 * w + 0.004, w, sz), step=0.06, dent=0.003)
    b.tube([base + Vector((-sx / 2, -sy / 2, sz)), base + Vector((sx / 2, -sy / 2, sz)), base + Vector((sx / 2, sy / 2, sz)),
            base + Vector((-sx / 2, sy / 2, sz)), base + Vector((-sx / 2, -sy / 2 + 0.01, sz))], 0.014, segs=8, round_ends=True)
    b.build()


def cloth_awning(M, C, name, width, top, reach, drop, valance=0.24, mat="awning", frames=30, seed=1):
    """Markise aus EINEM Stück Stoff (Rahmen canon: Wand bei y = 0, außen -y, Mitte x = 0): Blenders
    Stoffsimulation lässt die Bahn zwischen Kasten und Fallstange leicht durchhängen, der Volant
    fällt vorn herab. Danach bekommt der Stoff Dicke (Körper, keine Löcher). Im Alpha der
    Vertex-Farbe steht, wie frei jede Stelle im Wind schwingt (Shader: wind_strength).
    Dazu Kasten an der Wand, die Fallstange und zwei Gelenkarme SEITLICH neben dem Stoff (an den
    Enden der Stange) – so kann der Stoff nie durch die Arme stechen, auch nicht im Wind."""
    rnd = random.Random(seed)
    a = Vector((0.0, -0.06, top))              # Stoff kommt aus dem Kasten
    b = Vector((0.0, -reach, top - drop))      # Fallstange
    straight = (b - a).length
    nu = max(10, int(width / 0.04))
    nv_slope = max(12, int(straight / 0.035))
    nv_val = max(5, int(valance / 0.035))
    slack = 0.012 * straight                   # etwas Spiel: der Stoff hängt leicht durch
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    grid = []
    weights = []
    for i in range(nu + 1):
        x = -width / 2 + width * i / nu
        col = []
        for j in range(nv_slope + nv_val + 1):
            if j <= nv_slope:
                t = j / nv_slope
                p = a.lerp(b, t) + Vector((0, 0, -slack * math.sin(math.pi * t) * 1.6))
                w = 0.35 * math.sin(math.pi * t)
            else:
                t = (j - nv_slope) / nv_val
                p = b + Vector((0, -0.025, -valance * t))
                w = 0.25 + 0.75 * t
            p.x = x
            col.append(bm.verts.new(p))
            weights.append(w)
        grid.append(col)
    for i in range(nu):
        for j in range(nv_slope + nv_val):
            bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    C["shop"].objects.link(obj)
    attr = me.attributes.new("wind", "FLOAT", "POINT")
    for k, w in enumerate(weights):
        attr.data[k].value = w
    # Halten: Kante am Kasten und die Reihe an der Fallstange
    vg = obj.vertex_groups.new(name="Halt")
    rows = nv_slope + nv_val + 1
    pins = [i * rows + j for i in range(nu + 1) for j in (0, nv_slope)]
    vg.add(pins, 1.0, "REPLACE")
    cl = obj.modifiers.new("Stoff", "CLOTH")
    s = cl.settings
    s.quality = 8
    s.mass = 0.25
    s.air_damping = 3.0
    s.tension_stiffness = 30.0
    s.compression_stiffness = 30.0
    s.shear_stiffness = 10.0
    s.bending_stiffness = 0.6
    s.vertex_group_mass = "Halt"
    cl.collision_settings.use_collision = False
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 1, frames
    cl.point_cache.frame_start, cl.point_cache.frame_end = 1, frames
    for f in range(1, frames + 1):
        sc.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    done = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    obj.modifiers.remove(cl)
    old = obj.data
    obj.data = done
    bpy.data.meshes.remove(old)
    sc.frame_set(1)
    # Dicke: Stoff als geschlossener Körper
    sol = obj.modifiers.new("Dicke", "SOLIDIFY")
    sol.thickness = 0.012
    sol.offset = 0.0
    sol.use_rim = True
    sol.use_even_offset = True
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier=sol.name)
    me = obj.data
    me.materials.append(M[mat])
    for p in me.polygons:
        p.use_smooth = True
    tint = me.color_attributes.new("tint", "FLOAT_COLOR", "POINT")
    wind = me.attributes.get("wind")
    v = 1.0 + rnd.uniform(-0.03, 0.03)
    for k, vert in enumerate(me.vertices):
        if wind is not None:
            w = wind.data[k].value
        else:
            # Ersatz, falls die Simulation das Merkmal verliert: frei je weiter vorn und unten
            w = min(1.0, max(0.0, (-vert.co.y) / reach * 0.4 + (top - drop - vert.co.z) / valance * 0.6))
        tint.data[k].color = (v, v, v, 1.0 - w)
    if wind is not None:
        me.attributes.remove(wind)
    obj.vertex_groups.clear()
    # Kasten, Fallstange (etwas breiter als der Stoff) und Gelenkarme außen neben dem Stoff
    fr = Body(name + " Kasten und Arme", M["iron"], C["shop"], seed=seed + 1, vary=0.03, bevel=0.006)
    fr.box((0, -0.06, top + 0.03), (width + 0.16, 0.13, 0.13), step=0.3, dent=0.002)
    bar = b + Vector((0, -0.012, 0.0))
    fr.box(tuple(bar), (width + 0.16, 0.05, 0.05), step=0.3, dent=0.001)
    for sgn in (-1, 1):
        sx = sgn * (width / 2 + 0.045)
        # Lager unten am Kasten, Gelenk in der Mitte (leicht durchgeknickt), Kappe am Stangenende
        root = Vector((sx, -0.07, top - 0.06))
        end = Vector((sx, bar.y, bar.z))
        elbow = root.lerp(end, 0.5) + Vector((0, 0, -0.07))
        fr.tube([root, elbow, end], 0.014, segs=8, round_ends=True)
        fr.blob(tuple(elbow), 0.022, subdiv=1, lump=0.0)
        fr.box(tuple(root + Vector((0, 0, 0.02))), (0.07, 0.08, 0.06), step=1, dent=0.001)
        fr.blob(tuple(Vector((sgn * (width / 2 + 0.085), bar.y, bar.z))), 0.03, subdiv=1, lump=0.0)
    fr.build()
    return obj


def house_scene(title, inside="Innen"):
    """Leere Szene mit den Sammlungen eines Hauses (wie Pub und Modegeschäft)."""
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    M = SC.materials()
    root = SB.collection(title)
    C = {k: SB.collection(v, root) for k, v in (("walls", "Mauern"), ("roof", "Dach"), ("windows", "Fenster"), ("shop", "Ladenfront"),
                                                ("inside", inside), ("pots", "Töpfe und Kübel"), ("deco", "Deko"), ("light", "Licht"))}
    C["env"] = SB.collection("Umgebung (nur Vorschau)")
    C["collision"] = SB.collection("Kollision (Spiel)", root)
    return M, C


def run(build_scene, blend, stamp, glb, views, script):
    """Gemeinsamer Ablauf: Fingerabdruck prüfen, bauen, geschlossene Körper prüfen, Spiel-Datei
    schreiben, Kontrollbilder (-- --render [--quick] [--only=a,b]), .blend speichern."""
    import os
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if SC.edited_by_hand(blend, stamp) and "--force" not in argv:
        print("Die .blend wurde in Blender bearbeitet – nichts überschrieben. Ins Spiel bringen mit\n"
              "  blender -b %s --python tools/blender/export_storybook.py\n"
              "Neu bauen (eigene Änderungen gehen verloren): ... %s -- --force" % (os.path.relpath(blend, SC.ROOT), script))
        return
    M, C, cols = build_scene()
    parts = [(o.name, SB.non_manifold(o)) for c in C.values() for o in c.objects if o.type == "MESH"]
    bad = [(n, k) for n, k in parts if k]
    faces = sum(len(o.data.polygons) for c in C.values() for o in c.objects if o.type == "MESH")
    print("Teile: %d, Flächen: %d" % (len(parts), faces))
    print("Offene Kanten: %s" % (bad if bad else "keine – alles geschlossene Körper"))
    if "--no-game" not in argv:
        mapping = SC.write_game_materials()
        objs = [o for key, coll in C.items() if key not in ("env", "collision", "light") for o in coll.objects]
        tris, n = SC.export_objects(objs, cols, glb)
        SC.write_import_settings(mapping, glb)
        print("Spiel: %s (%d Dreiecke, %d Netze)" % (glb, tris, n))
    if "--render" in argv:
        quick = "--quick" in argv
        SC.setup_render(quick)
        s = 0.5 if quick else 1.0
        only = [a.split("=", 1)[1].split(",") for a in argv if a.startswith("--only=")]
        for name, (cam, target, lens, res) in views.items():
            if only and name not in only[0]:
                continue
            SC.render(name, cam, target, lens, (int(res[0] * s), int(res[1] * s)))
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    with open(stamp, "w") as f:
        f.write(SC.blend_fingerprint(blend) + "\n")
    print("Gespeichert:", blend)


# --- Grundrisse mit Ecken (Teeladen, Wolleladen) ---

def corner_outline(width, depth, angle, chamfer, side):
    """Grundriss der Eckhäuser wie CornerHouseFacade.footprint() (scripts/world/corner_house_facade.gd),
    in Blender-Koordinaten: Vorderseite y = 0 von x = -width/2 bis zur Abschrägung, Abschrägung,
    Seitenfassade um angle Grad nach hinten gedreht, hinten gerade bei y = depth, links Brandwand."""
    w = width / 2
    a = math.radians(angle)
    along = Vector((math.cos(a), math.sin(a)))
    cut = chamfer / (2 * math.cos(a / 2))
    corner = Vector((w, 0.0))
    side_end = corner + along * (depth if angle >= 89.9 else side)
    pts = [Vector((-w, 0.0)), corner - Vector((cut, 0.0)), corner + along * cut, side_end]
    if angle < 89.9:
        back = Vector((-math.sin(a), math.cos(a)))
        pts.append(side_end + back * max(0.0, (depth - side_end.y) / math.cos(a)))
    pts.append(Vector((-w, depth)))
    return [(p.x, p.y) for p in pts]


def turn_angles(outline):
    """Knick an jeder Ecke k (zwischen Kante k-1 und k), Bogenmaß, positiv = nach links (außen
    konvex bei Grundrissen gegen den Uhrzeigersinn)."""
    n = len(outline)
    out = []
    for k in range(n):
        a, b, c = Vector(outline[k - 1]), Vector(outline[k]), Vector(outline[(k + 1) % n])
        d0, d1 = (b - a).normalized(), (c - b).normalized()
        out.append(math.atan2(d0.x * d1.y - d0.y * d1.x, d0.dot(d1)))
    return out


def seg(outline, i):
    """Kante i des Grundrisses als (p0, p1)."""
    return outline[i], outline[(i + 1) % len(outline)]


def outline_walls(body, outline, segs, z0, z1, thick=0.3, inset=0.0, step=0.25, dent=0.006):
    """Mauern (oder Innenverkleidung mit inset) entlang der Kanten segs. Verkleidungen werden an
    konvexen Ecken genau auf Gehrung gekürzt, damit nichts nach außen durchsticht."""
    turns = turn_angles(outline)
    n = len(outline)
    for i in segs:
        e0 = -(inset + thick) * math.tan(turns[i] / 2) + 0.01 if inset > 0 else 0.0
        e1 = -(inset + thick) * math.tan(turns[(i + 1) % n] / 2) + 0.01 if inset > 0 else 0.0
        wall_run(body, *seg(outline, i), z0, z1, thick=thick, inset=inset, ext=(e0, e1), step=step, dent=dent)


def band_ext(outline, i, depth, segs):
    """Verlängerung (Anfang, Ende) eines Bauteils, das depth vor der Wand steht (Gesims,
    Schildkasten), damit es an konvexen Ecken zur Nachbarkante lückenlos übergeht."""
    turns = turn_angles(outline)
    n = len(outline)
    e0 = depth * math.tan(turns[i] / 2) + 0.02 if (i - 1) % n in segs else 0.0
    e1 = depth * math.tan(turns[(i + 1) % n] / 2) + 0.02 if (i + 1) % n in segs else 0.0
    return e0, e1


def band(body, outline, segs, z0, height, out0, out1, step=0.3, dent=0.004):
    """Waagerechtes Band (Gesims, Leiste) von out0 bis out1 vor der Wand entlang der Kanten segs,
    um alle Ecken herum ohne Fuge."""
    for i in segs:
        p0, p1 = seg(outline, i)
        length = seg_len(p0, p1)
        e0, e1 = band_ext(outline, i, out1, segs)
        body.box(((length + e1 - e0) / 2, z0 + height / 2, (out0 + out1) / 2), (length + e0 + e1, height, out1 - out0), step=step,
                 dent=dent, matrix=wall_matrix(p0, p1))


def floor_slab(M, C, name, mat, outline, inset, z, thick, coll="inside", seed=55):
    """Boden/Decke als Platte im Grundriss (um inset nach innen versetzt)."""
    pts = offset_polygon(outline, [inset] * len(outline))
    b = Body(name, M[mat], C[coll], seed=seed, vary=0.03)
    b.slab([(p.x, p.y) for p in pts], thick, Matrix.Translation((0, 0, z)), dent=0.002)
    return b.build()


def obstacle(p0, p1, x, out, size, h):
    """Kollisionskasten vor einer Wand (x entlang der Wand, out davor) → Eintrag für SC.colliders."""
    m = canon(p0, p1, x, 0.0, out)
    c = m @ Vector((0, 0, 0))
    yaw = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
    return ((c.x, c.y), size, h, yaw)


def teapot(body, base, size, rnd, yaw=0.0):
    """Teekanne aus Porzellan: Bauch, Deckel mit Knauf, Tülle und Henkel (Röhren)."""
    s = size
    b = Vector(base)
    body.lathe([(0.0, 0.0), (0.45 * s, 0.0), (0.62 * s, 0.25 * s), (0.66 * s, 0.5 * s), (0.55 * s, 0.75 * s), (0.36 * s, 0.86 * s),
                (0.3 * s, 0.9 * s), (0.22 * s, 0.98 * s), (0.08 * s, 1.0 * s), (0.06 * s, 1.08 * s), (0.0, 1.1 * s)], b, segs=20,
               spin=yaw)
    r = Matrix.Rotation(math.radians(yaw), 3, "Z")
    body.tube([b + r @ Vector((0.55 * s, 0, 0.35 * s)), b + r @ Vector((0.85 * s, 0, 0.55 * s)), b + r @ Vector((1.0 * s, 0, 0.82 * s))],
              lambda t: (0.12 - 0.06 * t) * s, segs=8, smooth=1, round_ends=True)
    body.tube([b + r @ Vector((-0.55 * s, 0, 0.72 * s)), b + r @ Vector((-0.9 * s, 0, 0.7 * s)), b + r @ Vector((-0.88 * s, 0, 0.35 * s)),
               b + r @ Vector((-0.6 * s, 0, 0.28 * s))], 0.045 * s, segs=8, smooth=2, round_ends=True)


def wall_lantern(M, C, name, x, z, scale=0.58, seed=130):
    """Wandlaterne (Rahmen canon): Wandplatte, Arm mit Schnecke, daran der gemeinsame Laternenkopf
    (storybook_parts.lantern_head – derselbe Kopf wie an der Straße und am Modegeschäft)."""
    ir = Body(name + " Arm", M["lamp_iron"], C["deco"], seed=seed, vary=0.03, bevel=0.005)
    ir.box((x, -0.02, z - 0.04), (0.12, 0.04, 0.26), step=1, dent=0.001)
    ir.tube([(x, -0.04, z), (x, -0.16, z + 0.04), (x, -0.3, z + 0.03), (x, -0.38, z)], 0.014, segs=8, smooth=2, round_ends=True)
    SP.scroll(ir, (x, -0.13, z - 0.07), 0.07, x, turns=1.3, thick=0.008, start=1.2)
    ir.tube([(x, -0.38, z), (x, -0.38, z - 0.07)], 0.008, segs=8, round_ends=True)
    ir.build()
    SP.lantern_head(M, C["deco"], name, (x, -0.38, z - 0.49), scale=scale, hanging=True, seed=seed + 2)
    SC.add_light(name + " Licht", (x, -0.38, z - 0.34), 2700, 22, C["light"], radius=0.04)


# Vor der Ladenfront: Brüstung, Pilaster-Sockel und Türpfosten ragen bis 24 cm vor die Wand.
FRONT_CLEAR = 0.25


def pot_out(r, clear=FRONT_CLEAR):
    """Abstand Topfmitte – Wand, damit der Topf (Rand etwas breiter als r) frei vor Brüstung und
    Sockel steht, mit 2 cm Luft."""
    return clear + r * 1.07 + 0.02


def street_lantern(M, C, name, x, z, seed=60):
    """Straßenlaterne am Wandarm (wie wall_street_lantern.glb an den Wohnhäusern) im Rahmen canon:
    Wandplatte bei (x, 0, z), Laterne 0,72 m vor der Wand, Unterkante etwa 0,67 m unter z.
    Mit placed() an jede Wand setzbar."""
    SP.street_wall_lantern(M, C["deco"], name + " Arm", name + " Kopf", (x, 0.0, z), seed=seed)
    SC.add_light(name + " Licht", (x, -0.72, z - 0.36), 2700, 30, C["light"], radius=0.05)


# --- Dächer aus Ziegelreihen (sparsam: eine Reihe = ein Körper) ---

def _tile_strip(body, frame, xa, xb, y_lo, y_hi, rnd, tile_w, scallop, thick, odd, simple):
    """Eine Ziegelreihe von xa bis xb (Dachkoordinaten): runde Ziegel-Unterkanten (Biberschwanz),
    vorn weich gerundet, leicht angehoben (Reihen liegen wie Ziegel übereinander), jeder Ziegel
    mit eigenem Farbton. Ein geschlossener Körper."""
    n = max(1, int(round((xb - xa) / tile_w)))
    tw = (xb - xa) / n
    bounds = [xa]
    x = xa + (tw * 0.5 if odd else tw)
    while x < xb - 0.04:
        bounds.append(x)
        x += tw
    bounds.append(xb)
    samples = (0.0, 0.5) if simple else (0.0, 0.33, 0.67)
    pts, cols = [], []
    for i in range(len(bounds) - 1):
        u0, u1 = bounds[i], bounds[i + 1]
        v = 1.0 + rnd.uniform(-0.11, 0.09)
        w = rnd.uniform(-0.04, 0.04)
        col = (v * (1 + w), v, v * (1 - w * 1.5))
        f = min(1.0, (u1 - u0) / tw)
        for t in samples:
            pts.append((u0 + t * (u1 - u0), y_lo - scallop * f * math.sin(math.pi * t)))
            cols.append(col)
    pts.append((xb, y_lo))
    cols.append(cols[-1])
    lift = thick * 0.9                          # Unterkante steht so weit über der Dachfläche
    span = max(0.05, y_hi - y_lo)

    def z_at(y, z):
        return z + lift * (y_hi - y) / span      # eben: Reihe um die Oberkante gekippt

    r = thick * 0.7
    if simple:
        prof = [(0.0, thick), (0.0, 0.0)]
    else:
        prof = [(r, thick), (0.0, thick - r * 0.6), (0.0, 0.0)]
    bm = body.bm
    rings = []
    for (x, y), c in zip(pts, cols):
        ring = []
        for dy, z in prof:
            vtx = bm.verts.new(frame @ Vector((x, y + dy, z_at(y + dy, z))))
            vtx[body.tint] = (*c, 1.0)
            ring.append(vtx)
        rings.append(ring)
    tl = bm.verts.new(frame @ Vector((xa, y_hi, z_at(y_hi, thick))))
    tr = bm.verts.new(frame @ Vector((xb, y_hi, z_at(y_hi, thick))))
    bl = bm.verts.new(frame @ Vector((xa, y_hi, z_at(y_hi, 0.0))))
    br = bm.verts.new(frame @ Vector((xb, y_hi, z_at(y_hi, 0.0))))
    for vtx, c in ((tl, cols[0]), (bl, cols[0]), (tr, cols[-1]), (br, cols[-1])):
        vtx[body.tint] = (*c, 1.0)
    faces = [bm.faces.new([rg[0] for rg in rings] + [tr, tl]), bm.faces.new([bl, br] + [rg[-1] for rg in reversed(rings)])]
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(len(prof) - 1):
            faces.append(bm.faces.new((a[k], b[k], b[k + 1], a[k + 1])))
    faces.append(bm.faces.new([tl, bl] + list(reversed(rings[0]))))
    faces.append(bm.faces.new([tr] + rings[-1] + [br]))
    faces.append(bm.faces.new((tl, tr, br, bl)))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for fc in faces:
        fc.smooth = True
    return faces


def tile_rows(body, b0, b1, t0, t1, rnd, tile_w=0.3, row=0.24, thick=0.035, scallop=0.05, holes=(), simple=False):
    """Dachziegel als Reihen auf einer Dachfläche (Trapez: Traufe b0 → b1, oben t0 → t1): jede Reihe
    ein Körper mit runden Ziegelkanten und eigenem Farbton je Ziegel (storybook-weich, aber nur ein
    Bruchteil der Dreiecke einzelner Ziegel). holes = Aussparungen (x0, x1, y0, y1) in Dach-
    koordinaten (x entlang der Traufe ab b0, y hangaufwärts), z. B. Gauben und Schornsteine.
    simple = schlichter (Rückseiten, ferne Häuser). Liefert den Rahmen der Dachfläche."""
    b0, b1, t0, t1 = (Vector(v) for v in (b0, b1, t0, t1))
    d = b1 - b0
    length = d.length
    d.normalize()
    up = (t0 - b0) - d * (t0 - b0).dot(d)
    slope = up.length
    u = up / slope
    n = d.cross(u)
    xa_top, xb_top = (t0 - b0).dot(d), (t1 - b0).dot(d)
    frame = Matrix(((d.x, u.x, n.x, b0.x), (d.y, u.y, n.y, b0.y), (d.z, u.z, n.z, b0.z), (0, 0, 0, 1)))
    s, k = 0.0, 0
    while s < slope - 0.06:
        y_hi = min(slope, s + row + 0.07)
        t = min(1.0, (s + y_hi) / 2 / slope)
        x0, x1 = xa_top * t, length + (xb_top - length) * t
        segs = [(x0, x1)]
        for hx0, hx1, hy0, hy1 in holes:
            if hy1 > s - 0.06 and hy0 < y_hi:
                out = []
                for a, b in segs:
                    if hx1 <= a or hx0 >= b:
                        out.append((a, b))
                        continue
                    if hx0 - a > 0.08:
                        out.append((a, hx0))
                    if b - hx1 > 0.08:
                        out.append((hx1, b))
                segs = out
        for a, b in segs:
            _tile_strip(body, frame, a, b, s, y_hi, rnd, tile_w, scallop * (0.6 if simple else 1.0), thick, k % 2 == 1, simple)
        s += row
        k += 1
    return frame


def cozy_roof(M, C, name, frame, length, span, eaves, pitch, mat, cap_mat=None, ends=(0.25, 0.25), holes=(), seed=8,
              back_simple=True, both=True, tile_w=0.33, row=0.26, verge=True, front_simple=False):
    """Satteldach im Bilderbuch-Stil (lokal: x = Firstrichtung, y quer, First bei y = 0, z oben;
    Traufen bei y = -span (vorn) und +span): Dachkern, Ziegelreihen, runder First, Ortgang an beiden
    Enden. holes = Aussparungen der vorderen Fläche (x ab dem linken Ende, y hangaufwärts).
    Liefert (Firsthöhe, z(y) der vorderen Fläche, Winkel)."""
    rnd = random.Random(seed)
    a = math.radians(pitch)
    ridge = eaves + span * math.tan(a)
    slope = span / math.cos(a)
    core = Body(name + " Dachflächen", M[mat], C["roof"], seed=seed, vary=0.04, bevel=0.012)
    tiles = Body(name + " Ziegelreihen", M[mat], C["roof"], seed=seed + 1, vary=0.0)
    x0, x1 = -length / 2 - ends[0], length / 2 + ends[1]
    for side in ((-1, 1) if both else (-1,)):
        start = Vector((x0 if side < 0 else x1, side * span, eaves))
        d = Vector((1.0 if side < 0 else -1.0, 0, 0))
        uu = Vector((0, -side * span, ridge - eaves)).normalized()
        nn = d.cross(uu)
        m = frame @ Matrix(((d.x, uu.x, nn.x, start.x), (d.y, uu.y, nn.y, start.y), (d.z, uu.z, nn.z, start.z), (0, 0, 0, 1)))
        core.box((0, 0, 0), (x1 - x0, slope + 0.04, 0.16), step=0.6, dent=0.006,
                 matrix=m @ Matrix.Translation(((x1 - x0) / 2, slope / 2, -0.09)))
        top = start + uu * slope
        tile_rows(tiles, frame @ start, frame @ (start + d * (x1 - x0)), frame @ top, frame @ (top + d * (x1 - x0)), rnd,
                  tile_w=tile_w, row=row, holes=holes if side < 0 else (), simple=(back_simple and side > 0) or front_simple)
    core.build()
    tiles.build()
    caps = Body(name + " First und Ortgang", M[cap_mat or mat], C["roof"], seed=seed + 2, vary=0.06, bevel=0.01)
    caps.tube([frame @ Vector((x0 - 0.02, 0, ridge + 0.05)), frame @ Vector((0, 0, ridge + 0.07)), frame @ Vector((x1 + 0.02, 0, ridge + 0.05))],
              0.085, segs=12, wobble=0.03, round_ends=True)
    if verge:
        for xe in (x0 + 0.02, x1 - 0.02):
            for side in ((-1, 1) if both else (-1,)):
                lo = Vector((xe, side * (span + 0.03), eaves + 0.04))
                hi = Vector((xe, 0.0, ridge + 0.04))
                caps.tube([frame @ lo, frame @ lo.lerp(hi, 0.5), frame @ hi], 0.055, segs=10, wobble=0.02, round_ends=True)
    caps.build()
    return ridge, (lambda y: eaves + (span - abs(y)) * math.tan(a)), a


def cozy_hip_roof(M, C, name, outline, hipped, eaves, rise, run, overhang, mat, cap_mat=None, simple=(), holes=None, seed=8):
    """Walmdach aus Ziegelreihen über einem beliebigen Grundriss (wie hip_roof, aber im Stil der
    Wohnhäuser): Kanten mit hipped[i] steigen um rise auf run Meter nach innen an, die anderen enden
    senkrecht (Brandwand). simple = Kanten mit schlichten Reihen (Rückseiten). holes = {Kante:
    [(x0, x1, y0, y1)]} Aussparungen (Schornstein). Oben bleibt eine flache Fläche. Grate und Firste
    als runde Wülste."""
    rnd = random.Random(seed)
    low = offset_polygon(outline, [-overhang if h else 0.0 for h in hipped])
    high = offset_polygon(outline, [run if h else 0.0 for h in hipped])
    core = Body(name + " Kern", M[mat], C["roof"], seed=seed, vary=0.03)
    roof_core(core, low, high, eaves - 0.06, eaves + rise - 0.03)
    core.build()
    tiles = Body(name + " Ziegelreihen", M[mat], C["roof"], seed=seed + 1, vary=0.0)
    caps = Body(name + " Grate", M[cap_mat or mat], C["roof"], seed=seed + 2, vary=0.06, bevel=0.01)
    n = len(outline)
    for i in range(n):
        if not hipped[i]:
            continue
        j = (i + 1) % n
        b0, b1 = low[i].to_3d(), low[j].to_3d()
        t0, t1 = high[i].to_3d(), high[j].to_3d()
        b0.z = b1.z = eaves
        t0.z = t1.z = eaves + rise
        tile_rows(tiles, b0, b1, t0, t1, rnd, holes=(holes or {}).get(i, ()), simple=i in simple)
        caps.tube([t0 + Vector((0, 0, 0.04)), t1 + Vector((0, 0, 0.04))], 0.07, segs=10, wobble=0.03, round_ends=True)
        for k in (i, j):
            lo, hi = low[k].to_3d(), high[k].to_3d()
            lo.z, hi.z = eaves + 0.03, eaves + rise + 0.04
            caps.tube([lo, hi], 0.065, segs=10, wobble=0.03, round_ends=True)
    tiles.build()
    caps.build()
    return low, high
