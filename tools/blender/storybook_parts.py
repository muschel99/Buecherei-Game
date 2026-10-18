"""Gemeinsame Bauteile im Bilderbuch-Stil (aus Körpern, mit weichen Kanten).

Laternenkopf (Vorbild: viktorianische Straßenlaterne aus dem Beispielbild der Entwicklerin):
runder Fuß, quadratische Bodenplatte, nach oben breiter werdendes Glas mit Eckstreben,
Randplatte, geschwungenes Pyramidendach, Krone und Spitze. Denselben Kopf tragen die
Straßenlaternen, die hängenden Laternen an den Wandarmen und die Wandlaternen der Häuser.
"""

import math

from mathutils import Matrix, Vector

from storybook_lib import Body

R2 = math.sqrt(2.0)


def lantern_head(M, coll, name, base, scale=1.0, hanging=False, seed=1):
    """Laternenkopf, unten bei base (Blender-Koordinaten, z oben). scale 1.0 = Straßenlaterne
    (etwa 0,62 m hoch, 0,38 m breit). hanging = unten ein kleiner Knauf (hängende Laterne)."""
    s = scale
    b = Vector(base)
    iron = Body(name + " Eisen", M["lamp_iron"], coll, seed=seed, vary=0.03, bevel=0.006 * s)
    glass = Body(name + " Glas", M["lamp"], coll, seed=seed + 1, vary=0.0)

    def sq(profile, z0=0.0):
        """Vierkant als Drehkörper mit vier Seiten (Profil in Halbbreite, Höhe)."""
        return [(r * R2 * s, (z + z0) * s) for r, z in profile]
    # Runder Fuß mit Wulst
    iron.lathe([(0.0, 0.0), (0.035 * s, 0.0), (0.06 * s, 0.025 * s), (0.1 * s, 0.05 * s), (0.115 * s, 0.075 * s),
                (0.1 * s, 0.095 * s), (0.0, 0.1 * s)], b, segs=20, dent=0.0)
    if hanging:
        iron.lathe([(0.0, -0.07 * s), (0.02 * s, -0.06 * s), (0.028 * s, -0.035 * s), (0.02 * s, -0.01 * s), (0.0, 0.0)],
                   b, segs=12)
    # Bodenplatte (quadratisch)
    iron.lathe(sq([(0.0, 0.09), (0.125, 0.09), (0.13, 0.105), (0.125, 0.12), (0.0, 0.12)]), b, segs=4, spin=45)
    # Glas: nach oben breiter
    glass.lathe(sq([(0.0, 0.12), (0.098, 0.12), (0.142, 0.42), (0.0, 0.42)]), b, segs=4, spin=45)
    for dx in (-1, 1):
        for dy in (-1, 1):
            lo = b + Vector((dx * 0.104, dy * 0.104, 0.12)) * s
            hi = b + Vector((dx * 0.148, dy * 0.148, 0.42)) * s
            iron.tube([lo, (lo + hi) / 2 + Vector((dx, dy, 0)) * 0.003 * s, hi], 0.011 * s, segs=8)
    # Zierband unten am Glas
    iron.lathe(sq([(0.0, 0.12), (0.105, 0.12), (0.108, 0.145), (0.0, 0.145)]), b, segs=4, spin=45)
    # Randplatte und geschwungenes Dach
    iron.lathe(sq([(0.0, 0.415), (0.165, 0.415), (0.172, 0.43), (0.165, 0.45), (0.0, 0.45)]), b, segs=4, spin=45)
    iron.lathe(sq([(0.0, 0.445), (0.19, 0.445), (0.192, 0.46), (0.15, 0.48), (0.1, 0.51), (0.065, 0.55), (0.045, 0.58),
                   (0.0, 0.585)]), b, segs=4, spin=45)
    # Krone (rund) mit kleiner Kuppel und Spitze
    iron.lathe([(0.0, 0.565 * s), (0.05 * s, 0.565 * s), (0.055 * s, 0.6 * s), (0.04 * s, 0.62 * s), (0.032 * s, 0.645 * s),
                (0.012 * s, 0.665 * s), (0.0, 0.67 * s)], b, segs=16)
    iron.tube([b + Vector((0, 0, 0.66)) * s, b + Vector((0, 0, 0.72)) * s], 0.008 * s, segs=8)
    iron.blob(b + Vector((0, 0, 0.725)) * s, 0.018 * s, subdiv=2, lump=0.02)
    # Leuchtender Kern (Glühbirnen-Look)
    glass.blob(b + Vector((0, 0, 0.26)) * s, 0.04 * s, subdiv=2, lump=0.05, scale=(1, 1, 1.3))
    return iron.build(), glass.build()


def scroll(body, center, radius, plane_x, turns=1.4, thick=0.01, start=0.0):
    """Schmiedeeisen-Schnecke in der Ebene x = plane_x (y/z), als Röhre."""
    pts = []
    n = 26
    for k in range(n + 1):
        t = k / n
        a = start + t * turns * 2 * math.pi
        r = radius * (1.0 - 0.75 * t)
        pts.append(Vector((plane_x, center[1] + r * math.cos(a), center[2] + r * math.sin(a))))
    body.tube(pts, lambda t: thick * (1.0 - 0.4 * t), segs=8)
    body.blob(pts[-1], thick * 1.3, subdiv=1, lump=0.0)


def street_wall_lantern(M, coll, arm_name, head_name, origin=(0.0, 0.0, 0.0), seed=60):
    """Hängende Straßenlaterne am geschwungenen Wandarm (dieselbe wie assets/models/props/
    wall_street_lantern.glb): Wandplatte bei origin auf der Wand (Front zeigt nach -y), Arm mit
    Strebe und zwei Schnecken 0,72 m nach vorn, daran der gemeinsame Laternenkopf (scale 0.76).
    Die Laterne hängt bis etwa 0,67 m unter origin."""
    o = Vector(origin)
    reach = 0.72
    ir = Body(arm_name, M["lamp_iron"], coll, seed=seed, vary=0.03, bevel=0.005)
    ir.box(tuple(o + Vector((0, -0.015, -0.07))), (0.14, 0.03, 0.45), step=1, dent=0.001)
    ir.box(tuple(o + Vector((0, -0.035, -0.07))), (0.1, 0.015, 0.37), step=1, dent=0.001)
    arm = [o + Vector((0, -0.03, 0.08)), o + Vector((0, -0.25, 0.18)), o + Vector((0, -reach + 0.12, 0.2)), o + Vector((0, -reach, 0.16))]
    strut = [o + Vector((0, -0.03, -0.24)), o + Vector((0, -0.2, -0.08)), o + Vector((0, -0.42, 0.08)), o + Vector((0, -0.58, 0.18))]
    ir.tube(arm, 0.02, segs=10, smooth=2, round_ends=True)
    ir.tube(strut, 0.014, segs=8, smooth=2, round_ends=True)
    scroll(ir, tuple(o + Vector((0, -0.17, 0.03))), 0.075, o.x, turns=1.4, thick=0.009, start=0.6)
    scroll(ir, tuple(o + Vector((0, -0.4, 0.13))), 0.05, o.x, turns=1.3, thick=0.008, start=0.9)
    ir.blob(tuple(o + Vector((0, -reach - 0.03, 0.17))), 0.026, subdiv=2, lump=0.0)
    ir.tube([o + Vector((0, -reach, 0.16)), o + Vector((0, -reach, -0.07))], 0.01, segs=8, round_ends=True)
    ir.build()
    return lantern_head(M, coll, head_name, tuple(o + Vector((0, -reach, -0.62))), scale=0.76, hanging=True, seed=seed + 4)
