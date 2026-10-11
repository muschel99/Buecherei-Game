"""Fahrzeuge im Stil (seit Etappe 5b): englisches Taxi, Mini, Kombi mit Holzrahmen ("Traveller"),
der Lieferwagen (Bulli mit Nest-&-Nook-Logo) und das Fahrrad – ohne Markenzeichen.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_vehicles.py              (alle)
    blender -b --factory-startup --python tools/blender/build_vehicles.py -- taxi --render
        (Kontrollbilder nach screenshots/blender/vehicles/)

Ergebnis: assets/models/vehicles/<name>.glb (Karosserie), <name>_wheel.glb (ein Rad; Godot setzt
es viermal ein und dreht es beim Fahren), beim Lieferwagen <name>_door.glb (Schiebetür).
Koordinaten wie im Spiel: x links (Fahrzeugsicht), y oben, z nach vorn; Räder stehen auf y = 0.
Farben: Lack = Rolle "accent" (Godot: Wagenfarbe), zweite Farbe (Dach, obere Hälfte) = Rolle
"door".
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
import style_parts as P  # noqa: E402
from style_lib import Mat, V  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

OUT = os.path.join(S.ROOT, "assets", "models", "vehicles")
SRC = os.path.join(S.ROOT, "assets", "models", "source", "vehicles")
SHOTS = os.path.join(S.ROOT, "screenshots", "blender", "vehicles")

PAINT = Mat("car_paint", "accent")
PAINT2 = Mat("car_paint", "door")
CHROME = Mat("chrome")
RUBBER = Mat("rubber")
GLASS = Mat("glass", glass=True)
WELL = Mat("plain", color=(0.05, 0.05, 0.05))
DARK = Mat("plain", color=(0.09, 0.09, 0.1))
SEAT = Mat("leather", color=(0.42, 0.28, 0.2))
DASH = Mat("plain", color=(0.16, 0.14, 0.13))
HEAD = Mat("plain", color=(1.0, 0.97, 0.86), glow=0.85)
TAIL = Mat("plain", color=(0.78, 0.08, 0.06), glow=0.45)
AMBER = Mat("plain", color=(0.95, 0.55, 0.1), glow=0.4)
PLATE_F = Mat("plain", color=(0.94, 0.94, 0.9))
PLATE_R = Mat("plain", color=(0.96, 0.8, 0.18))
PLATE_TEXT = Mat("plain", color=(0.08, 0.08, 0.08))
TIMBER = Mat("timber", color=(0.75, 0.55, 0.33))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def interp(points, z):
    """Lineare Kurve durch (z, Wert)-Punkte."""
    pts = sorted(points)
    if z <= pts[0][0]:
        return pts[0][1]
    for (z0, v0), (z1, v1) in zip(pts, pts[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            t = t * t * (3 - 2 * t)
            return v0 + (v1 - v0) * t
    return pts[-1][1]


# ---------------------------------------------------------------------------------------------
# Karosserie aus Querschnitten
# ---------------------------------------------------------------------------------------------

class Body:
    """Karosserie: Querschnitte entlang z (hinten → vorn). Jeder Querschnitt ist ein gerundetes
    Rechteck: Boden (bottom), Seiten bis zur Gürtellinie (belt, halbe Breite hw), darüber zum
    Dach (top) eingezogen (Dachbreite rw · hw), runde Kanten. Radkästen schneiden unten aus."""

    def __init__(self, spec):
        self.s = spec
        self.L = spec["length"]

    def f(self, name, z):
        v = self.s[name]
        return interp(v, z) if isinstance(v, (list, tuple)) else v

    def contour(self, z):
        """Rechte Hälfte (x ≥ 0) als Liste (x, y) vom Boden in der Mitte bis zur Dachmitte."""
        bottom, belt, top = self.f("bottom", z), self.f("belt", z), self.f("top", z)
        hw = self.f("hw", z)
        rw = self.f("rw", z)
        belt = min(belt, top - 0.02)
        rl = min(0.1, (belt - bottom) * 0.45)
        upper = top - belt
        rt = min(self.s.get("roof_round", 0.08), upper * 0.6 + 0.02)
        rx = max(0.05, hw * rw) if upper > 0.12 else max(0.05, hw - upper * 0.8)
        pts = []
        # Boden
        inset = hw - self.s.get("well_inset", 0.28)
        for x in (0.0, inset * 0.5, inset, hw - rl):
            pts.append((x, bottom))
        for k in range(1, 5):
            a = math.pi / 2 * k / 4
            pts.append((hw - rl + math.sin(a) * rl, bottom + rl - math.cos(a) * rl))
        # Seite (leicht gewölbt)
        bulge = self.s.get("bulge", 0.02)
        for k in range(1, 5):
            t = k / 4
            y = bottom + rl + (belt - bottom - rl) * t
            pts.append((hw + bulge * math.sin(math.pi * t), y))
        # Oben zum Dach (Seitenscheiben leicht nach innen geneigt), runde Dachkante
        for k in range(1, 5):
            t = k / 4
            pts.append((hw + (rx + rt * 0.3 - hw) * t, belt + (top - rt - belt) * t))
        for k in range(1, 5):
            a = math.pi / 2 * k / 4
            pts.append((rx + rt * 0.3 - rt + math.cos(a) * rt, top - rt + math.sin(a) * rt))
        crown = self.s.get("crown", 0.015)
        for x in (rx * 0.66, rx * 0.33, 0.0):
            pts.append((x, top + crown * (1 - (x / max(rx, 1e-3)) ** 2)))
        return pts

    def ring(self, z):
        right = self.contour(z)
        # Enden runden: in den letzten nose/tail Metern schrumpft der Querschnitt (Ellipse)
        nose, tail = self.s.get("nose", 0.25), self.s.get("tail", 0.2)
        L = self.L
        s = 1.0
        if z > L / 2 - nose:
            u = (z - (L / 2 - nose)) / nose
            s = math.sqrt(max(0.0, 1 - u * u))
        elif z < -L / 2 + tail:
            u = ((-L / 2 + tail) - z) / tail
            s = math.sqrt(max(0.0, 1 - u * u))
        s = 0.1 + 0.9 * s
        bottom, top = self.f("bottom", z), self.f("top", z)
        cy = (bottom + top) / 2
        pts = []
        for x, y in right:
            pts.append(Vector((x * s, cy + (y - cy) * (0.55 + 0.45 * s), z)))
        left = [Vector((-p.x, p.y, p.z)) for p in reversed(pts[1:-1])]
        ring = pts + left
        # Radkästen: Punkte außen unten heben sich auf den Bogen um das Rad
        lifted = []
        for p in ring:
            lift = False
            for wz, wr in self.s["wheels"]:
                R = wr + self.s.get("arch_gap", 0.05)
                dz = z - wz
                if abs(dz) < R and abs(p.x) > self.f("hw", z) - self.s.get("well_inset", 0.28) + 0.005:
                    ay = wr + math.sqrt(R * R - dz * dz)
                    if p.y < ay:
                        p.y = ay
                        lift = True
            lifted.append(lift)
        return ring, lifted

    def build(self, b, mat_fn, steps=60):
        L = self.L
        zs = [-L / 2 + L * (0.5 - 0.5 * math.cos(math.pi * k / steps)) for k in range(steps + 1)]
        # Zusätzliche Schnitte an den Radkästen (saubere Bögen)
        for wz, wr in self.s["wheels"]:
            R = wr + self.s.get("arch_gap", 0.05)
            zs += [wz + R * math.sin(math.pi / 2 * k / 6) * sgn for k in range(7) for sgn in (-1, 1)]
        zs = sorted(set(round(z, 4) for z in zs if -L / 2 <= z <= L / 2))
        rings = [self.ring(z) for z in zs]
        # Weiche Normalen je Ecke (glatter Lack): aus den Nachbarn im Gitter
        normals = []
        for i, (ring, _) in enumerate(rings):
            row = []
            n = len(ring)
            for k in range(n):
                a = rings[min(i + 1, len(rings) - 1)][0][k] - rings[max(i - 1, 0)][0][k]
                c2 = ring[(k + 1) % n] - ring[k - 1]
                nn = c2.cross(a)
                axis = Vector((0.0, (self.f("bottom", ring[k].z) + self.f("top", ring[k].z)) / 2, ring[k].z))
                if nn.dot(ring[k] - axis) < 0:
                    nn = -nn
                row.append(nn.normalized() if nn.length > 1e-9 else (ring[k] - axis).normalized())
            normals.append(row)
        for i, ((ra, la), (rb, lb)) in enumerate(zip(rings, rings[1:])):
            n = len(ra)
            for k in range(n):
                k1 = (k + 1) % n
                q = [ra[k], ra[k1], rb[k1], rb[k]]
                nq = [normals[i][k], normals[i][k1], normals[i + 1][k1], normals[i + 1][k]]
                c = sum(q, Vector()) / 4
                if (q[0] - q[1]).length < 1e-6 and (q[2] - q[3]).length < 1e-6:
                    continue
                # Radkasten: Flächen, deren Ecken (fast) alle auf den Bogen gehoben wurden, und die
                # innere Wand – die Außenhaut am Bogen bleibt Lack
                in_well = (la[k] + la[k1] + lb[k] + lb[k1]) >= 3 or \
                    ((la[k] or la[k1] or lb[k] or lb[k1]) and abs(c.x) < self.f("hw", c.z) - self.s.get("well_inset", 0.28) + 0.03)
                axis = Vector((0.0, (self.f("bottom", c.z) + self.f("top", c.z)) / 2, c.z))
                out = c - axis
                n_out = (q[1] - q[0]).cross(q[3] - q[0])
                if n_out.dot(out) < 0:
                    q, nq = q[::-1], nq[::-1]
                    n_out = -n_out
                if in_well:
                    b.poly(q, WELL)
                    continue
                mat = mat_fn(c, n_out.normalized() if n_out.length > 1e-9 else out.normalized(), self)
                b.poly(q, mat, normals=nq)
        for z, (ring, _) in ((zs[0], rings[0]), (zs[-1], rings[-1])):
            b.face(ring, mat_fn(sum(ring, Vector()) / len(ring), Vector((0, 0, 1 if z > 0 else -1)), self),
                   (0, 0, 1 if z > 0 else -1))
        return zs

    def side_x(self, z, y):
        """x der Außenhaut rechts (x > 0) in Höhe y am Querschnitt z."""
        ring, _ = self.ring(z)
        best = None
        for a, c in zip(ring, ring[1:]):
            if a.x < 0 or c.x < 0:
                continue
            if (a.y - y) * (c.y - y) <= 0 and abs(c.y - a.y) > 1e-6:
                t = (y - a.y) / (c.y - a.y)
                x = a.x + (c.x - a.x) * t
                best = x if best is None else max(best, x)
        return best if best is not None else self.f("hw", z)


def surface_tree(b):
    tris = []
    for f in b.faces:
        pts = f["pts"]
        for i in range(1, len(pts) - 1):
            tris.append((pts[0], pts[i], pts[i + 1]))
    return BVHTree.FromPolygons([p for t in tris for p in t], [(3 * k, 3 * k + 1, 3 * k + 2) for k in range(len(tris))],
                                all_triangles=True)


def hit(tree, origin, direction):
    loc, nrm, _, _ = tree.ray_cast(Vector(origin), Vector(direction).normalized())
    return loc, nrm


def oriented(b, center, normal, up=(0, 1, 0)):
    """Lokales Koordinatensystem auf der Oberfläche: z = normal (nach außen)."""
    n = Vector(normal).normalized()
    u = Vector(up)
    x = u.cross(n)
    if x.length < 1e-6:
        x = Vector((1, 0, 0))
    x.normalize()
    y = n.cross(x).normalized()
    m = S.Matrix(((x.x, y.x, n.x, center[0]), (x.y, y.y, n.y, center[1]), (x.z, y.z, n.z, center[2]), (0, 0, 0, 1)))
    b.push(m)


def round_lamp(b, tree, x, y, z_probe, radius, lens, front=True, depth=0.05, rim=CHROME):
    """Runder Scheinwerfer/Rücklicht auf der Karosserie: Chromring, gewölbtes Glas."""
    d = 1 if front else -1
    loc, nrm = hit(tree, (x, y, z_probe + d * 2.0), (0, 0, -d))
    if loc is None:
        return
    oriented(b, loc, Vector((0, 0, d)).lerp(nrm, 0.3))
    b.cylinder(V(0, 0, -depth), radius + 0.012, depth + 0.012, rim, segments=20, axis="z", caps=(False, True))
    b.push(S.Matrix.Diagonal((1.0, 1.0, 0.35, 1.0)))
    b.sphere(V(0, 0, 0.012 / 0.35), radius, lens, rings=5, segments=20)
    b.pop()
    b.pop()


def plate(b, tree, y, z_probe, front=True, w=0.52, h=0.12, text="CB 51 KN"):
    d = 1 if front else -1
    loc, nrm = hit(tree, (0, y, z_probe + d * 2.0), (0, 0, -d))
    if loc is None:
        return
    b.push(S.Matrix.Translation(loc + Vector((0, 0, d * 0.006))) @ (S.Matrix.Identity(4) if front else b.turn_y(180)))
    b.box((-w / 2, -h / 2, -0.012), (w / 2, h / 2, 0.004), PLATE_F if front else PLATE_R)
    b.text(text, 0.0, -h * 0.32, 0.004, h * 0.62, 0.002, PLATE_TEXT, font_path="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
    b.pop()


def door_line(b, body, z, y0, y1, steps=8, mat=DARK, side=1, radius=0.0035):
    """Fuge einer Tür: senkrechte Linie auf der Außenhaut."""
    pts = []
    for k in range(steps + 1):
        y = y0 + (y1 - y0) * k / steps
        pts.append(V(side * (body.side_x(z, y) + 0.0015), y, z))
    b.tube(pts, radius, mat, segments=4)


def belt_strip(b, body, z0, z1, y, mat=CHROME, side=1, radius=0.006, steps=16):
    pts = []
    for k in range(steps + 1):
        z = z0 + (z1 - z0) * k / steps
        pts.append(V(side * (body.side_x(z, y) + 0.002), y, z))
    b.tube(pts, radius, mat, segments=5)


def handle(b, body, z, y, side=1):
    x = side * (body.side_x(z, y) + 0.004)
    b.box((min(x, x + side * 0.018), y - 0.012, z - 0.06), (max(x, x + side * 0.018), y + 0.012, z + 0.06), CHROME)


def mirror(b, body, z, y, side=1, mat=CHROME):
    x = body.side_x(z, y)
    b.tube([V(side * (x - 0.01), y, z), V(side * (x + 0.08), y + 0.06, z - 0.02)], 0.008, mat, segments=5)
    b.sphere(V(side * (x + 0.1), y + 0.07, z - 0.02), 0.05, mat, rings=4, segments=10, squash=0.6)
    b.cylinder(V(side * (x + 0.1), y + 0.07, z - 0.064), 0.04, 0.004, Mat("glass", glass=True), segments=10, axis="z", caps=(True, True))


def interior(b, body, z_front, z_back, floor_y, seat_mat=SEAT, rows=1, wheel_side=-1):
    """Innenraum hinter dem Glas: Boden, Sitze, Armaturenbrett, Lenkrad (rechts gelenkt = -x)."""
    hw = body.f("hw", (z_front + z_back) / 2) - 0.12
    b.box((-hw, floor_y, z_back), (hw, floor_y + 0.02, z_front), DASH)
    belt = body.f("belt", z_front)
    b.box((-hw, floor_y, z_front - 0.12), (hw, belt - 0.02, z_front), DASH)
    sx = hw * 0.5
    row_z = [z_front - 0.55 - r * 0.85 for r in range(rows)]
    for rz in row_z:
        if rz < z_back + 0.25:
            continue
        for x in ((-sx, sx) if rows == 1 or rz == row_z[0] else (0.0,)):
            w = 0.46 if rows == 1 or rz == row_z[0] else hw * 1.6
            b.box((x - w / 2, floor_y + 0.019, rz - 0.22), (x + w / 2, floor_y + 0.32, rz + 0.22), seat_mat)
            b.box((x - w / 2, floor_y + 0.3, rz - 0.26), (x + w / 2, floor_y + 0.85, rz - 0.2), seat_mat)
    wx = wheel_side * sx
    ring = [V(wx + math.cos(a) * 0.17, belt + 0.02 + math.sin(a) * 0.17 * 0.85, z_front - 0.32 - math.sin(a) * 0.08)
            for a in [2 * math.pi * k / 16 for k in range(17)]]
    b.tube(ring, 0.014, DARK, segments=5, caps=False)
    b.tube([V(wx, belt - 0.05, z_front - 0.3), V(wx, belt - 0.15, z_front - 0.12)], 0.02, DARK, segments=5)


# ---------------------------------------------------------------------------------------------
# Rad (eigene Datei, Godot setzt es ein und dreht es)
# ---------------------------------------------------------------------------------------------

def wheel(name, radius, width, rim_mat=CHROME, hub="dish", spokes=0):
    """Ein Rad, Achse = x, Mitte im Ursprung, Außenseite nach +x: Reifen mit runder Flanke und
    Profilrillen, Felge, Radkappe."""
    b = S.Builder(name)
    hwid = width / 2
    # Reifen: Drehkörper um x (Profil von innen nach außen)
    prof = [(-hwid, radius * 0.66), (-hwid - 0.004, radius * 0.8), (-hwid + 0.004, radius * 0.94), (-hwid + 0.03, radius),
            (hwid - 0.03, radius), (hwid - 0.004, radius * 0.94), (hwid + 0.004, radius * 0.8), (hwid, radius * 0.66)]
    seg = 28
    rings = []
    for x, r in prof:
        rings.append([V(x, math.cos(a) * r, math.sin(a) * r) for a in [2 * math.pi * k / seg for k in range(seg)]])
    for ra, rb in zip(rings, rings[1:]):
        for k in range(seg):
            k1 = (k + 1) % seg
            q = [ra[k], ra[k1], rb[k1], rb[k]]
            c = sum(q, Vector()) / 4
            b.face(q, RUBBER, Vector((0, c.y, c.z)))
    # Profilrillen (dunkle Blöcke auf der Lauffläche)
    for k in range(seg):
        a = 2 * math.pi * (k + 0.5) / seg
        for sx in (-1, 1):
            b.push(S.Matrix.Rotation(a, 4, "X"))
            b.box((sx * 0.25 * width - 0.012, radius - 0.004, -0.012), (sx * 0.25 * width + 0.012, radius + 0.004, 0.012), RUBBER)
            b.pop()
    # Felge: Scheibe innen, Ring, Radkappe außen
    b.cylinder(V(-hwid * 0.6, 0, 0), radius * 0.66, hwid * 1.4, rim_mat, segments=seg, axis="x", caps=(False, False))
    b.cylinder(V(hwid * 0.6, 0, 0), radius * 0.62, 0.006, rim_mat, segments=seg, axis="x", caps=(True, True))
    if hub == "dish":
        b.push(S.Matrix.Translation((hwid * 0.6 + 0.004, 0, 0)) @ S.Matrix.Diagonal((0.25, 1.0, 1.0, 1.0)))
        b.sphere(V(0, 0, 0), radius * 0.4, CHROME, rings=7, segments=24)
        b.pop()
    if spokes:
        for k in range(spokes):
            a = 2 * math.pi * k / spokes
            b.push(S.Matrix.Rotation(a, 4, "X"))
            b.box((hwid * 0.6, -0.012, radius * 0.18), (hwid * 0.6 + 0.012, 0.012, radius * 0.6), rim_mat)
            b.pop()
        b.cylinder(V(hwid * 0.6, 0, 0), radius * 0.18, 0.02, CHROME, segments=14, axis="x", caps=(True, True))
    return b


# ---------------------------------------------------------------------------------------------
# Fenster und Lack je Fläche
# ---------------------------------------------------------------------------------------------

def window_mats(z_front_glass, z_rear_glass, side_windows, roof_mat=PAINT, lower=PAINT, upper=None, pillar=None,
                rear_glass=True, split=False, upper_fn=None):
    """Liefert mat_fn für Body.build: Glas in der Fensterzone (Windschutzscheibe vorn, Heckscheibe,
    Seitenfenster zwischen den Säulen), Dach in roof_mat, darunter Lack. split = geteilte
    Windschutzscheibe (Mittelsteg). upper_fn(c, n) = True: obere Farbe (zweifarbig)."""
    def fn(c, n, body):
        belt, top = body.f("belt", c.z), body.f("top", c.z)
        hw = body.f("hw", c.z)
        up = upper_fn(c, n) if upper_fn else (upper is not None and c.y > belt)
        body_mat = (upper or lower) if up else lower
        in_zone = z_rear_glass < c.z < z_front_glass and c.y > belt + 0.025
        edge = hw * body.f("rw", c.z)
        if in_zone and n.z > 0.4 and n.y < 0.75:
            if abs(c.x) < edge - 0.07 and not (split and abs(c.x) < 0.035):
                return GLASS
            return pillar or body_mat
        if in_zone and n.z < -0.4 and n.y < 0.75:
            return GLASS if rear_glass and abs(c.x) < edge - 0.08 else (pillar or body_mat)
        if in_zone and abs(n.x) > 0.35 and c.y < top - 0.035:
            if any(z0 < c.z < z1 for z0, z1 in side_windows):
                return GLASS
            return pillar or body_mat
        if n.y > 0.6 and c.y > belt and z_rear_glass - 0.05 < c.z < z_front_glass + 0.05:
            return roof_mat
        return body_mat
    return fn


def bumper(b, z, y, half_w, front=True, mat=CHROME, depth=0.07, tree=None):
    """Gebogene Stoßstange; mit tree zwei Halter bis zur Karosserie."""
    d = 1 if front else -1

    def at(x):
        t = (x + half_w) / (2 * half_w)
        return V(x, y, z + d * (0.05 * (1 - (2 * t - 1) ** 2) - 0.04 * (2 * t - 1) ** 4))
    pts = [at(-half_w + 2 * half_w * k / 12) for k in range(13)]
    b.tube(pts, depth / 2, mat, segments=8)
    for p in (pts[0], pts[-1]):
        b.sphere(p, depth / 2, mat, rings=4, segments=8)
    if tree is not None:
        for x in (-0.42 * half_w, 0.42 * half_w):
            start = at(x)
            loc, _ = hit(tree, (x, y, z + d * 1.0), (0, 0, -d))
            if loc is not None:
                b.tube([start, loc - Vector((0, 0, d * 0.03))], 0.018, DARK, segments=6)


def grille(b, tree, y0, y1, half_w, z_probe, bars=9, mat=CHROME, vertical=True):
    loc, _ = hit(tree, (0, (y0 + y1) / 2, z_probe + 2.0), (0, 0, -1))
    if loc is None:
        return
    z = loc.z + 0.005
    b.box((-half_w - 0.025, y0 - 0.025, z - 0.04), (half_w + 0.025, y1 + 0.025, z + 0.015), mat)
    b.box((-half_w, y0, z + 0.015), (half_w, y1, z + 0.016), DARK)
    for k in range(bars):
        if vertical:
            x = -half_w + 2 * half_w * (k + 0.5) / bars
            b.box((x - 0.008, y0, z + 0.012), (x + 0.008, y1, z + 0.03), mat)
        else:
            y = y0 + (y1 - y0) * (k + 0.5) / bars
            b.box((-half_w, y - 0.007, z + 0.012), (half_w, y + 0.007, z + 0.03), mat)


# ---------------------------------------------------------------------------------------------
# Taxi (englisches Taxi, klassische Form)
# ---------------------------------------------------------------------------------------------

TAXI = dict(
    length=4.5, wheels=[(1.36, 0.35), (-1.38, 0.35)], well_inset=0.26, arch_gap=0.06, nose=0.32, tail=0.28,
    bottom=[(-2.25, 0.34), (-1.85, 0.24), (1.85, 0.24), (2.25, 0.36)],
    belt=[(-2.25, 0.92), (-1.6, 0.98), (1.0, 1.0), (2.25, 0.93)],
    top=[(-2.25, 0.9), (-1.95, 1.0), (-1.62, 1.05), (-1.25, 1.66), (-1.0, 1.73), (0.4, 1.75), (0.62, 1.66), (0.95, 1.08),
         (1.25, 1.0), (2.0, 0.97), (2.25, 0.86)],
    hw=[(-2.25, 0.74), (-1.9, 0.85), (1.85, 0.86), (2.25, 0.76)],
    rw=0.86, roof_round=0.12, bulge=0.025,
)


def build_taxi():
    b = S.Builder("taxi")
    body = Body(TAXI)
    fn = window_mats(0.95, -1.62, [(0.12, 0.6), (-0.62, 0.05), (-1.25, -0.7)])
    body.build(b, fn)
    tree = surface_tree(b)
    # Front: großer Chromgrill, runde Scheinwerfer in den Kotflügeln, Blinker
    grille(b, tree, 0.42, 0.82, 0.3, 2.25, bars=11)
    for sx in (-1, 1):
        round_lamp(b, tree, sx * 0.6, 0.86, 2.25, 0.085, HEAD)
        round_lamp(b, tree, sx * 0.62, 0.66, 2.25, 0.035, AMBER, depth=0.03)
        round_lamp(b, tree, sx * 0.62, 0.78, -2.25, 0.05, TAIL, front=False, depth=0.03)
    bumper(b, 2.27, 0.42, 0.78, tree=tree)
    bumper(b, -2.27, 0.42, 0.78, front=False, tree=tree)
    plate(b, tree, 0.56, 2.25, text="TX 47 LB")
    plate(b, tree, 0.62, -2.25, front=False, text="TX 47 LB")
    # Taxi-Schild auf dem Dach (leuchtet gelb, kein Markenzeichen)
    b.box((-0.28, 1.76, 0.05), (0.28, 1.9, 0.2), Mat("plain", color=(0.98, 0.78, 0.25), glow=0.7))
    for z, rot in ((0.205, 0), (0.045, 180)):
        b.push(S.Matrix.Translation((0, 0, z)) @ b.turn_y(rot))
        b.text("TAXI", 0.0, 1.785, 0.0, 0.09, 0.004, Mat("plain", color=(0.12, 0.1, 0.08)),
               font_path="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
        b.pop()
    for side in (-1, 1):
        door_line(b, body, 0.62, 0.38, 1.0, side=side)
        door_line(b, body, 0.05, 0.38, 1.0, side=side)
        door_line(b, body, -0.66, 0.38, 1.0, side=side)
        belt_strip(b, body, -1.3, 0.65, 1.0, side=side)
        handle(b, body, 0.0, 0.9, side=side)
        handle(b, body, -0.6, 0.9, side=side)
        mirror(b, body, 0.85, 1.02, side=side)
        # Trittbrett
        b.box((side * 0.72 - 0.06, 0.28, -0.95), (side * 0.72 + 0.06 * side, 0.31, 0.95), DARK)
    interior(b, body, 0.95, -1.6, 0.36, rows=2)
    # Scheibenwischer
    for sx in (-0.3, 0.25):
        b.beam(V(sx, 1.1, 0.93), V(sx + 0.35, 1.32, 0.82), 0.012, 0.012, DARK)
    return b, TAXI


# ---------------------------------------------------------------------------------------------
# Mini (klein, Räder an den Ecken, weißes Dach)
# ---------------------------------------------------------------------------------------------

MINI = dict(
    length=3.05, wheels=[(1.02, 0.27), (-1.02, 0.27)], well_inset=0.2, arch_gap=0.04, nose=0.22, tail=0.16,
    bottom=[(-1.52, 0.26), (-1.3, 0.18), (1.3, 0.18), (1.52, 0.27)],
    belt=[(-1.52, 0.8), (1.52, 0.82)],
    top=[(-1.52, 0.78), (-1.32, 0.84), (-1.12, 0.88), (-0.98, 1.28), (-0.8, 1.33), (0.4, 1.34), (0.52, 1.3),
         (0.78, 0.9), (0.95, 0.84), (1.4, 0.82), (1.52, 0.72)],
    hw=[(-1.52, 0.64), (-1.3, 0.7), (1.3, 0.7), (1.52, 0.62)],
    rw=0.9, roof_round=0.07, bulge=0.012,
)


def build_mini():
    b = S.Builder("mini")
    body = Body(MINI)
    fn = window_mats(0.78, -1.1, [(-0.05, 0.5), (-0.9, -0.12)], roof_mat=PAINT2, pillar=PAINT2)
    body.build(b, fn)
    tree = surface_tree(b)
    # Dachkante (Regenrinne) und Front
    grille(b, tree, 0.45, 0.66, 0.36, 1.52, bars=6, vertical=False)
    for sx in (-1, 1):
        round_lamp(b, tree, sx * 0.47, 0.72, 1.52, 0.075, HEAD)
        round_lamp(b, tree, sx * 0.52, 0.55, 1.52, 0.03, AMBER, depth=0.02)
        round_lamp(b, tree, sx * 0.52, 0.68, -1.52, 0.045, TAIL, front=False, depth=0.02)
    bumper(b, 1.56, 0.36, 0.66, depth=0.05, tree=tree)
    bumper(b, -1.56, 0.36, 0.66, front=False, depth=0.05, tree=tree)
    plate(b, tree, 0.42, 1.52, w=0.44, h=0.1, text="MN 64 Y")
    plate(b, tree, 0.5, -1.52, front=False, w=0.44, h=0.1, text="MN 64 Y")
    for side in (-1, 1):
        door_line(b, body, 0.58, 0.3, 0.82, side=side)
        door_line(b, body, -0.15, 0.3, 0.82, side=side)
        handle(b, body, -0.05, 0.74, side=side)
        mirror(b, body, 0.66, 0.84, side=side)
        # Außenliegende Scharniere und Naht unter der Tür (typisch)
        for y in (0.4, 0.68):
            x = side * (body.side_x(0.56, y) + 0.008)
            b.box((min(x, x + side * 0.02), y - 0.02, 0.54), (max(x, x + side * 0.02), y + 0.02, 0.6), CHROME)
        belt_strip(b, body, -1.4, 1.4, 0.24, mat=DARK, side=side, radius=0.008)
    interior(b, body, 0.78, -1.05, 0.22, rows=1)
    for sx in (-0.25, 0.2):
        b.beam(V(sx, 0.88, 0.8), V(sx + 0.3, 1.08, 0.66), 0.01, 0.01, DARK)
    return b, MINI


# ---------------------------------------------------------------------------------------------
# Kombi mit Holzrahmen (rundliche Front, hinten Holzfachwerk mit Fenstern, Doppeltür)
# ---------------------------------------------------------------------------------------------

TRAVELLER = dict(
    length=3.8, wheels=[(1.08, 0.31), (-1.12, 0.31)], well_inset=0.24, arch_gap=0.05, nose=0.34, tail=0.03,
    bottom=[(-1.9, 0.28), (-1.6, 0.21), (1.6, 0.21), (1.9, 0.34)],
    belt=[(-1.9, 0.92), (1.0, 0.94), (1.9, 0.82)],
    top=[(-1.9, 1.46), (-1.8, 1.5), (0.35, 1.52), (0.55, 1.46), (0.9, 0.98), (1.2, 0.92), (1.7, 0.86), (1.9, 0.68)],
    hw=[(-1.9, 0.72), (-1.6, 0.76), (1.5, 0.76), (1.9, 0.6)],
    rw=0.88, roof_round=0.1, bulge=0.03,
)


def build_traveller():
    b = S.Builder("traveller")
    body = Body(TRAVELLER)
    side = [(0.0, 0.52), (-0.75, -0.08), (-1.68, -0.85)]
    fn = window_mats(0.9, -1.85, side, roof_mat=PAINT)
    body.build(b, fn)
    tree = surface_tree(b)
    grille(b, tree, 0.42, 0.7, 0.26, 1.9, bars=9, vertical=False)
    for sx in (-1, 1):
        round_lamp(b, tree, sx * 0.55, 0.82, 1.9, 0.08, HEAD)
        round_lamp(b, tree, sx * 0.5, 0.6, 1.9, 0.03, AMBER, depth=0.02)
        round_lamp(b, tree, sx * 0.55, 0.75, -1.9, 0.045, TAIL, front=False, depth=0.02)
    bumper(b, 1.93, 0.38, 0.68, tree=tree)
    bumper(b, -1.93, 0.38, 0.7, front=False, tree=tree)
    plate(b, tree, 0.5, 1.9, text="TRV 58")
    # Holzfachwerk hinten (Seiten und Heck): Leisten an Gürtellinie, Dachkante und um die Fenster
    for sd in (-1, 1):
        for y in (0.5, 0.95, 1.42):
            belt_strip(b, body, -1.8, -0.04, y, mat=TIMBER, side=sd, radius=0.022, steps=12)
        for z in (-0.04, -0.8, -1.74):
            pts = [V(sd * (body.side_x(z, y) + 0.004), y, z) for y in [0.42 + 1.02 * k / 8 for k in range(9)]]
            b.tube(pts, 0.022, TIMBER, segments=6)
        door_line(b, body, 0.55, 0.32, 0.94, side=sd)
        handle(b, body, 0.45, 0.86, side=sd)
        mirror(b, body, 0.95, 0.98, side=sd)
    # Heck: Doppeltür im Holzrahmen, Fenster
    loc, _ = hit(tree, (0, 1.0, -4.0), (0, 0, 1))
    if loc is not None:
        z = loc.z - 0.012
        for x0, x1 in ((-0.56, -0.02), (0.02, 0.56)):
            b.box((x0, 0.46, z - 0.035), (x1, 0.51, z), TIMBER)
            b.box((x0, 1.3, z - 0.035), (x1, 1.35, z), TIMBER)
            for x in (x0, x1 - 0.05):
                b.box((x, 0.46, z - 0.035), (x + 0.05, 1.35, z), TIMBER)
            b.box((x0, 0.92, z - 0.035), (x1, 0.97, z), TIMBER)
            b.quad(V(x0 + 0.05, 0.97, z - 0.02), V(x1 - 0.05, 0.97, z - 0.02), V(x1 - 0.05, 1.3, z - 0.02), V(x0 + 0.05, 1.3, z - 0.02), GLASS)
        plate(b, tree, 0.6, -1.9, front=False, text="TRV 58")
    interior(b, body, 0.9, -1.8, 0.24, rows=2)
    for sx in (-0.3, 0.22):
        b.beam(V(sx, 0.99, 0.92), V(sx + 0.3, 1.18, 0.82), 0.01, 0.01, DARK)
    return b, TRAVELLER


# ---------------------------------------------------------------------------------------------
# Lieferwagen: Bulli (zweifarbig, V vorn, geteilte Frontscheibe, Schiebetür, Logo, Dachträger)
# ---------------------------------------------------------------------------------------------

VAN = dict(
    length=4.28, wheels=[(1.2, 0.34), (-1.2, 0.34)], well_inset=0.24, arch_gap=0.05, nose=0.42, tail=0.34,
    bottom=[(-2.14, 0.42), (-1.85, 0.3), (1.85, 0.3), (2.14, 0.44)],
    belt=[(-2.14, 1.2), (2.14, 1.2)],
    top=[(-2.14, 1.82), (-1.95, 1.93), (1.85, 1.93), (2.14, 1.72)],
    hw=[(-2.14, 0.82), (-1.9, 0.87), (1.9, 0.87), (2.14, 0.84)],
    rw=0.94, roof_round=0.18, bulge=0.015, crown=0.02,
)
VAN_DOOR = (-0.02, 0.92)   # Schiebetür (links, +x): von z bis z
VAN_LOGO = (0.95, 0.46)    # Logo: Breite, Höhe (m)


def _van_upper(c, n):
    # Obere Farbe: Seiten ab knapp unter den Fenstern; vorn unten die Wagenfarbe (das V liegt als
    # eigene Fläche darauf, siehe _van_front_v)
    if n.z > 0.45 and c.z > 1.6:
        return c.y > 1.22
    return c.y > 1.12


def _van_front_v(b, tree):
    """Das große V vorn (obere Farbe), fein aufgelöst, 3 mm über dem Lack."""
    nx, ny = 28, 14
    pts = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            x = -0.86 + 1.72 * i / nx
            y = 0.86 + 0.42 * j / ny
            loc, nrm = hit(tree, (x, y, 4.0), (0, 0, -1))
            if loc is not None and nrm.z > 0.3:
                pts[(i, j)] = (loc + nrm * 0.003, nrm)
    def g(p):
        return p.y - (0.98 + 0.34 * min(1.0, abs(p.x) / 0.72))
    for i in range(nx):
        for j in range(ny):
            q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if not all(k in pts for k in q):
                continue
            # Kachel genau an der V-Linie abschneiden (glatte Kante statt Treppe)
            poly = [(pts[k][0], pts[k][1]) for k in q]
            out = []
            for a, c2 in zip(poly, poly[1:] + poly[:1]):
                ga, gc = g(a[0]), g(c2[0])
                if ga >= 0:
                    out.append(a)
                if (ga >= 0) != (gc >= 0):
                    t = ga / (ga - gc)
                    out.append((a[0].lerp(c2[0], t), a[1].lerp(c2[1], t).normalized()))
            if len(out) >= 3:
                b.poly([e[0] for e in out], PAINT2, normals=[e[1] for e in out])


def build_van():
    b = S.Builder("delivery_van")
    body = Body(VAN)
    side = [(1.35, 1.95), (VAN_DOOR[0] + 0.06, VAN_DOOR[1] - 0.06), (-0.75, -0.12), (-1.5, -0.85)]
    fn = window_mats(1.6, -2.0, side, roof_mat=PAINT2, upper=PAINT2, upper_fn=_van_upper)
    base_fn = fn

    def fn2(c, n, bd):
        # Hinter der Schiebetür: dunkle Öffnung (zu sieht man die Tür, offen den Laderaum)
        if c.x > 0.5 and VAN_DOOR[0] < c.z < VAN_DOOR[1] and 0.36 < c.y < 1.78 and n.x > 0.5:
            return DARK
        # Front: geteilte Scheibe mit hellem Rahmen und Mittelsteg
        if n.z > 0.45 and c.z > 1.6:
            if 1.28 < c.y < 1.8 and 0.05 < abs(c.x) < 0.72:
                return GLASS
            return PAINT2 if c.y > 1.22 else PAINT
        return base_fn(c, n, bd)
    body.build(b, fn2)
    tree = surface_tree(b)
    _van_front_v(b, tree)
    for sx in (-1, 1):
        round_lamp(b, tree, sx * 0.6, 0.86, 2.14, 0.085, HEAD)
        round_lamp(b, tree, sx * 0.66, 1.2, 2.14, 0.035, AMBER, depth=0.02)
        round_lamp(b, tree, sx * 0.7, 0.9, -2.14, 0.05, TAIL, front=False, depth=0.02)
    bumper(b, 2.2, 0.48, 0.84, depth=0.08, tree=tree)
    bumper(b, -2.2, 0.48, 0.84, front=False, depth=0.08, tree=tree)
    plate(b, tree, 0.62, 2.14, text="NN 24 ME")
    plate(b, tree, 0.68, -2.14, front=False, text="NN 24 ME")
    # Zierleiste zwischen den Farben
    for sd in (-1, 1):
        belt_strip(b, body, -2.0, 1.95, 1.12, mat=CHROME, side=sd, radius=0.007, steps=24)
        mirror(b, body, 1.75, 1.32, side=sd)
        door_line(b, body, 1.3, 0.36, 1.12, side=sd)
        handle(b, body, 1.4, 1.02, side=sd)
    # Logo-Felder an beiden Seiten (Bild "logo", austauschbar)
    lw, lh = VAN_LOGO
    logo = Mat("plain", sign="logo")
    for sd in (-1, 1):
        zc = -0.55
        y0 = 0.52
        nu, nv = 8, 4
        # Gitter, das der Wölbung folgt; u läuft für den Betrachter immer von links nach rechts
        grid = []
        for j in range(nv + 1):
            y = y0 + lh * j / nv
            row = []
            for i in range(nu + 1):
                u = i / nu
                z = zc + lw * (u - 0.5) * (1 if sd < 0 else -1)
                row.append((V(sd * (body.side_x(z, y) + 0.004), y, z), (u, j / nv)))
            grid.append(row)
        for j in range(nv):
            for i in range(nu):
                q = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
                pts = [e[0] for e in q]
                uv = [e[1] for e in q]
                n = (pts[1] - pts[0]).cross(pts[3] - pts[0])
                if n.x * sd < 0:
                    pts, uv = pts[::-1], uv[::-1]
                b.poly(pts, logo, uvs=uv)
    # Dachträger mit zwei Paketen
    for sx in (-0.62, 0.62):
        b.tube([V(sx, 1.95, -1.5), V(sx, 2.04, -1.4), V(sx, 2.04, 0.9), V(sx, 1.95, 1.0)], 0.014, CHROME, segments=6)
    for z in (-1.2, -0.4, 0.4):
        b.tube([V(-0.62, 2.04, z), V(0.62, 2.04, z)], 0.012, CHROME, segments=6)
    for x0, z0, w, d, h in ((-0.42, -1.28, 0.5, 0.95, 0.3), (0.12, -0.5, 0.4, 0.45, 0.24)):
        b.box((x0, 2.05, z0), (x0 + w, 2.05 + h, z0 + d), Mat("plain", color=(0.66, 0.5, 0.33)))
        b.box((x0 + w / 2 - 0.03, 2.05 + h, z0 - 0.002), (x0 + w / 2 + 0.03, 2.053 + h, z0 + d + 0.002), Mat("plain", color=(0.82, 0.74, 0.6)))
    # Laderaum: Kartons, vorn Sitzbank und Lenkrad
    interior(b, body, 1.72, 0.9, 0.42, rows=1)
    for x0, z0, s2 in ((-0.6, -1.6, 0.4), (-0.15, -1.55, 0.35), (0.25, -1.6, 0.42), (-0.55, -1.1, 0.3), (0.2, -1.0, 0.36)):
        b.box((x0, 0.45, z0), (x0 + s2, 0.45 + s2 * 0.8, z0 + s2), Mat("plain", color=(0.66, 0.5, 0.33)))
    b.box((-0.75, 0.42, -1.95), (0.75, 0.45, 0.9), DASH)
    return b, VAN


def build_van_door():
    """Schiebetür (eigenes Teil "Door"): folgt der Außenhaut links, mit Fenster und Griff."""
    b = S.Builder("delivery_van_door")
    body = Body(VAN)
    z0, z1 = VAN_DOOR
    ys = [0.36 + (1.8 - 0.36) * k / 12 for k in range(13)]
    zs = [z0 + (z1 - z0) * k / 8 for k in range(9)]
    grid = [[V(body.side_x(z, y) + 0.009, y, z) for z in zs] for y in ys]
    for i in range(len(ys) - 1):
        for j in range(len(zs) - 1):
            q = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
            c = sum(q, Vector()) / 4
            win = 1.24 < c.y < 1.74 and z0 + 0.07 < c.z < z1 - 0.07
            mat = GLASS if win else (PAINT2 if c.y > 1.12 else PAINT)
            b.face(q, mat, (1, 0, 0))
            # Innen (Rückseite): dunkel
            b.face([p - Vector((0.012, 0, 0)) for p in q], DARK, (-1, 0, 0))
    # Kanten
    for row in (grid[0], grid[-1]):
        for a, c2 in zip(row, row[1:]):
            b.face([a, c2, c2 - Vector((0.012, 0, 0)), a - Vector((0.012, 0, 0))], PAINT, (0, -1 if row is grid[0] else 1, 0))
    for j in (0, len(zs) - 1):
        col = [grid[i][j] for i in range(len(ys))]
        for a, c2 in zip(col, col[1:]):
            b.face([a, c2, c2 - Vector((0.012, 0, 0)), a - Vector((0.012, 0, 0))], PAINT, (0, 0, 1 if j else -1))
    x = body.side_x(z1 - 0.12, 1.0) + 0.012
    b.box((x, 0.97, z1 - 0.22), (x + 0.018, 1.0, z1 - 0.1), CHROME)
    belt_strip(b, body, z0 + 0.01, z1 - 0.01, 1.12, mat=CHROME, side=1, radius=0.007, steps=8)
    return b


def logo_design(b):
    """Startbild des Logos (Bild assets/textures/signs/delivery_van_logo.png, austauschbar): Haus mit
    Herz und Blatt wie das Symbol der App, Schriftzug "Nest & Nook"."""
    W, H = VAN_LOGO
    green = Mat("plain", color=(0.33, 0.47, 0.36))
    cream = Mat("plain", color=(0.96, 0.93, 0.85))
    rose = Mat("plain", color=(0.82, 0.45, 0.42))
    b.box((-W / 2, -H / 2, -0.02), (W / 2, H / 2, 0.0), cream)
    m = 0.03
    b.tube([V(-W / 2 + m, -H / 2 + m, 0.004), V(W / 2 - m, -H / 2 + m, 0.004), V(W / 2 - m, H / 2 - m, 0.004),
            V(-W / 2 + m, H / 2 - m, 0.004), V(-W / 2 + m, -H / 2 + m, 0.004)], 0.007, green, segments=6)
    cx, cy, s2 = -0.29, -0.01, 0.0042
    def P(x, y):
        return V(cx + x * s2, cy - y * s2, 0.006)
    # Dach, Wände, Schornstein (wie das App-Symbol, Maße in dessen Pixeln)
    b.tube([P(-28, -2), P(0, -26), P(28, -2)], 0.009, green, segments=6)
    b.tube([P(-20, -8), P(-20, 24), P(20, 24), P(20, -8)], 0.009, green, segments=6)
    b.tube([P(14, -16), P(14, -26)], 0.009, green, segments=6)
    heart = []
    for k in range(32):
        t = 2 * math.pi * k / 32
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        heart.append(V(cx + x * 0.55 * s2, cy + (y * 0.55 - 6) * s2 * -1 * -1 - 0.025, 0.006))
    b.face(heart, rose, (0, 0, 1))
    leaf = [V(cx + (26 + 9 * math.cos(t)) * s2 + 0.0, cy - (22 + 4 * math.sin(t)) * s2, 0.006) for t in
            [2 * math.pi * k / 16 for k in range(16)]]
    b.face(leaf, green, (0, 0, 1))
    b.text("Nest & Nook", 0.13, 0.0, 0.004, 0.105, 0.003, green)
    b.text("Möbel · Deko · Farben", 0.13, -0.11, 0.004, 0.042, 0.002, green,
           font_path="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")





BIKE = dict(wheel_r=0.34, wheel_z=0.52, crank=(0.36, 0.02))


def build_bicycle(full=False):
    """Fahrrad für die Straße: Rahmen (Lack = Wagenfarbe), Räder und Kurbel als eigene Teile."""
    b = S.Builder("bicycle")
    P.bicycle(b, PAINT, wheels=full, crank_parts=full)
    return b, dict(length=1.8, wheels=[], hw=[(0, 0.3), (0, 0.3)])


def build_bicycle_wheel():
    b = S.Builder("bicycle_wheel")
    P.bike_wheel(b, (0, 0, 0), BIKE["wheel_r"])
    return b


def build_bicycle_crank():
    b = S.Builder("bicycle_crank")
    P.bike_crank(b, (0, 0, 0))
    return b


def render(name, b, spec):
    import bpy
    os.makedirs(SHOTS, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    colors = {"accent": (0.05, 0.05, 0.055), "door": (0.9, 0.88, 0.82), "wall": (0.5, 0.5, 0.5)}
    if name != "taxi":
        colors["accent"] = (0.62, 0.1, 0.1) if name != "delivery_van" else (0.56, 0.74, 0.7)
    if name == "bicycle":
        b, _ = build_bicycle(full=True)
        colors["accent"] = (0.3, 0.45, 0.4)
    S.to_blender(b, colors)
    if name == "delivery_van":
        S.to_blender(build_van_door(), colors)
    w = WHEELS.get(name, dict(radius=0.3, width=0.1, rim=CHROME))
    wb = wheel(name + "_wheel", w["radius"], w["width"], w["rim"])
    for wz, wr in spec["wheels"]:
        for side in (-1, 1):
            o = S.to_blender(wheel(name + "_wheel", w["radius"], w["width"], w["rim"]), colors)
            # Godot (x, y, z) -> Blender (x, -z, y); linke Räder (x > 0) zeigen nach außen
            o.location = (side * (spec["hw"][1][1] - 0.12), -wz, wr)
            if side < 0:
                o.rotation_euler = (0, 0, math.pi)
    del wb
    S.setup_render(resolution=(1200, 800), samples=24)
    floor = bpy.data.meshes.new("Floor")
    floor.from_pydata([(-8, -8, 0), (8, -8, 0), (8, 8, 0), (-8, 8, 0)], [], [(0, 1, 2, 3)])
    fo = bpy.data.objects.new("Floor", floor)
    bpy.context.scene.collection.objects.link(fo)
    L = spec["length"]
    views = (("front34", (3.6, 1.6, L * 0.9), (0, 0.8, 0)), ("side", (-6.0, 1.2, 0.0), (0, 0.8, 0)),
             ("rear34", (-3.4, 1.8, -L * 0.9), (0, 0.8, 0)), ("front", (0.0, 1.0, L * 1.3), (0, 0.8, 0)))
    if name == "bicycle":
        views = (("side", (-2.6, 0.8, 0.0), (0, 0.6, 0)), ("front34", (1.6, 1.1, 1.4), (0, 0.6, 0)))
    for view, cam, tgt in views:
        S.render_view(os.path.join(SHOTS, "%s-%s.png" % (name, view)), cam, tgt, lens=40)


CARS = {"taxi": build_taxi, "mini": build_mini, "traveller": build_traveller, "delivery_van": build_van,
        "bicycle": build_bicycle}
WHEELS = {"taxi": dict(radius=0.35, width=0.19, rim=CHROME), "mini": dict(radius=0.27, width=0.15, rim=CHROME),
          "traveller": dict(radius=0.31, width=0.16, rim=PAINT2), "delivery_van": dict(radius=0.34, width=0.18, rim=PAINT2)}


def save(b, name, signs=None):
    """.glb (+ Godot-Importeinstellungen) und .blend-Quelle schreiben."""
    import bpy
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SRC, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    S.write_glb(b, path)
    S.write_import_settings(path, signs)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    S.to_blender(b, {"accent": (0.62, 0.1, 0.1), "door": (0.9, 0.88, 0.82), "wall": (0.5, 0.5, 0.5)})
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, name + ".blend"))
    print("%s: %d Dreiecke" % (name, sum(len(f["pts"]) - 2 for f in b.faces)))


def export(name):
    import build_houses as BH
    if name == "bicycle":
        save(build_bicycle()[0], "bicycle")
        save(build_bicycle_wheel(), "bicycle_wheel")
        save(build_bicycle_crank(), "bicycle_crank")
        return
    b, spec = CARS[name]()
    signs = None
    if name == "delivery_van":
        BH.SIGNS["delivery_van"] = {"logo": (VAN_LOGO[0], VAN_LOGO[1], 1024, logo_design)}
        signs = BH.prepare_signs("delivery_van")
        b, spec = CARS[name]()
    save(b, name, signs)
    w = WHEELS[name]
    save(wheel(name + "_wheel", w["radius"], w["width"], w["rim"]), name + "_wheel")
    if name == "delivery_van":
        save(build_van_door(), "delivery_van_door")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in argv if not a.startswith("--")] or list(CARS)
    for name in names:
        if "--render" in argv:
            b, spec = CARS[name]()
            render(name, b, spec)
        else:
            export(name)


if __name__ == "__main__":
    main()
