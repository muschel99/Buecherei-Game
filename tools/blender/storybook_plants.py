"""Pflanzen im Bilderbuch-Stil (jedes Blatt, jede Blüte ein kleiner Körper).

Vorerst nur an den Straßenlaternen im Einsatz (Hängekörbe); an Pub und Modegeschäft bleiben
Pflanzen auf Wunsch der Entwicklerin erst einmal weg (nur Töpfe und Kübel).
"""

import math

from mathutils import Vector

def cascade(leaves, stems, bloom, start, out, length, rnd):
    """Hängende Blütenranke (Petunie): wächst erst über den Rand nach vorn, dann nach unten;
    Blätter und offene Trichterblüten verteilt, nicht gleichmäßig."""
    pts = [Vector(start)]
    d = Vector(out)
    for i in range(max(3, int(length / 0.03))):
        d = (d + Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), -0.45))).normalized()
        pts.append(pts[-1] + d * 0.03)
    stems.tube(pts, lambda t: 0.0045 * (1 - 0.5 * t), segs=6, smooth=2, round_ends=True)
    for i, p in enumerate(pts[1:], 1):
        if rnd.random() < 0.7:
            dd = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.5, 0.5))).normalized()
            leaves.leaf(p, dd, Vector((0, 0, 1)) + dd * 0.2, rnd.uniform(0.035, 0.05), 0.032, shape="oval", curl=0.15, segs=6,
                        thick=0.0035)
        if rnd.random() < 0.55:
            n = (Vector(out) + Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(-0.3, 0.6)))).normalized()
            floret(bloom, p + n * 0.02, n, rnd.uniform(0.022, 0.03), rnd, petals=5)


def geranium(leaves, stems, bloom, base, rot, rnd):
    """Geranie als rundes Polster: viele runde, gewellte Blätter rund um den Fuß (ungleich,
    einzelne stehen heraus), darüber zwei bis vier kugelige Blütenbälle auf Stielen."""
    up = rot @ Vector((0, 1, 0))
    out = rot @ Vector((0, 0, 1))
    for k in range(rnd.randint(14, 20)):
        # vorn (zur Straße) mehr und tiefer hängende Blätter, hinten weniger
        a = rnd.uniform(0, 2 * math.pi)
        if math.sin(a) < 0 and rnd.random() < 0.5:
            a = -a
        lift = rnd.uniform(-0.25, 0.7) if math.sin(a) > 0.3 else rnd.uniform(0.1, 0.75)
        d = (rot @ Vector((math.cos(a), lift, math.sin(a)))).normalized()
        L = rnd.uniform(0.065, 0.1)
        stem_end = base + d * rnd.uniform(0.03, 0.09) + up * rnd.uniform(0.0, 0.05)
        stems.tube([base, stem_end], 0.0035, segs=5)
        leaves.leaf(stem_end, d + up * 0.25, up + d * -0.35, L, L * 0.95, shape="round", curl=0.2, thick=0.004)
    for k in range(rnd.randint(2, 4)):
        top = base + up * rnd.uniform(0.14, 0.26) + (rot @ Vector((rnd.uniform(-0.07, 0.07), 0, rnd.uniform(-0.03, 0.07))))
        mid = (base + top) / 2 + out * 0.02
        stems.tube([base, mid, top], 0.0045, segs=6, smooth=2, round_ends=True)
        umbel(bloom, top, rnd.uniform(0.055, 0.07), up, rnd, count=rnd.randint(22, 30), size=0.021)


def umbel(bloom, center, radius, up, rnd, count=None, petals=5, size=0.019):
    """Kugeliger Blütenball (Geranie): dicht gepackte Einzelblüten, unten etwas flacher."""
    for k in range(count or rnd.randint(16, 22)):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1)))
        if d.length < 0.1:
            continue
        d.normalize()
        if d.dot(up) < -0.35:
            d = (d + up * 0.9).normalized()
        c = Vector(center) + d * radius * rnd.uniform(0.82, 1.08)
        floret(bloom, c, d, size * rnd.uniform(0.85, 1.15), rnd, petals)


def floret(body, center, normal, size, rnd, petals=5):
    """Eine Blüte als ein Körper (Stern aus Blütenblättern, leicht schalenförmig)."""
    body.star(center, normal, size, petals, rnd)
    return
    n = Vector(normal).normalized()
    ref = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    s1 = n.cross(ref).normalized()
    s2 = n.cross(s1).normalized()
    spin = rnd.uniform(0, 2 * math.pi)
    for k in range(petals):
        a = spin + 2 * math.pi * k / petals
        d = s1 * math.cos(a) + s2 * math.sin(a) + n * 0.25
        body.leaf(center, d, n, size, size * 0.8, shape="petal", thick=0.0015, curl=0.1, segs=6)


def hang(leaves, stems, start, direction, length, rnd, out=None, wall_z=None, young=None):
    """Hängende Ranke: Trieb fällt in weichem Bogen, Herzblätter abwechselnd links und rechts,
    zur Spitze hin kleiner."""
    pts = [Vector(start)]
    d = Vector(direction)
    step = 0.04
    n = max(3, int(length / step))
    sway = rnd.uniform(0, 6.28)
    for i in range(n):
        d = (d + Vector((0.08 * math.sin(sway + i * 0.6), rnd.uniform(-0.03, 0.03), -0.4))).normalized()
        pts.append(pts[-1] + d * step)
    stems.tube(pts, lambda t: 0.0045 * (1 - 0.45 * t), segs=6, smooth=1, round_ends=True)
    out = out or Vector((0, -1, 0))
    for i in range(1, len(pts)):
        side = 1 if i % 2 else -1
        tang = (pts[i] - pts[i - 1]).normalized()
        sideways = tang.cross(out).normalized() * side
        size = 0.062 * (1 - 0.45 * i / len(pts)) * rnd.uniform(0.85, 1.15)
        tip = pts[i] + sideways * 0.018 + out * 0.008
        stems.tube([pts[i], tip], 0.0018, segs=4)
        leaves.leaf(tip, (sideways * 0.5 + Vector((0, 0, -0.7)) + out * 0.25).normalized(), out, size, size * 0.95, shape="heart",
                    curl=0.12, thick=0.0035)


