"""Vögel im weichen Stil (seit Etappe 6h): kleiner Singvogel und Taube.

Körper und Kopf sind EIN weicher Körper aus Metaballs (animal_lib.Blobs) – keine Nähte, kein Knick am Hals.
Die Flügel sind dünne, geschlossene Schalen, die mit 0,8 mm Luft genau auf dem Körper liegen (angelegt beim
Sitzen); die Formvariante „spread“ breitet sie zu richtigen Flügeln aus (im Spiel beim Fliegen). Der Schwanz
ist ein flacher Fächer, der in den Bürzel hineinreicht. Farben: Gefieder = Grundfarbe, Brust/Kehle =
zweite Farbe (Maske > 0), Kappe/Nacken = dritte Farbe (Maske < 0) – alles im Material „… Gefieder“.

Blender-Koordinaten: vorn = -y, oben = z, Ursprung zwischen den Füßen.
"""
import math

from mathutils import Vector

import animal_lib as AL
from animal_lib import smoothstep
from storybook_lib import Body


def _eye(tree, center, direction, radius, embed=0.0015):
    """Auge auf der Kopfoberfläche: von außen auf den Kopf gezielt, leicht eingelassen."""
    d = Vector(direction).normalized()
    hit = tree.ray_cast(Vector(center) + d * 0.2, -d, 0.4)
    p, n = hit[0], hit[1]
    return p - n * embed + n * 0.0, n


class BirdSpec:
    """Maße eines Vogels (alles in Metern, Blender-Koordinaten)."""

    def __init__(self, **kw):
        self.__dict__.update(kw)


SONGBIRD = BirdSpec(
    name="bird",
    # Körperteile: (Mitte, Halbachsen, Drehung)
    blobs=[((0, 0.006, 0.047), (0.021, 0.031, 0.022), (-18, 0, 0)),
           ((0, -0.011, 0.043), (0.019, 0.018, 0.019), (0, 0, 0)),
           ((0, 0.004, 0.035), (0.016, 0.02, 0.012), (0, 0, 0)),
           ((0, -0.028, 0.082), (0.0165, 0.0175, 0.0165), (0, 0, 0)),
           ((0, -0.019, 0.071), (0.0125, 0.0125, 0.0125), (0, 0, 0)),
           ((0, 0.032, 0.055), (0.011, 0.015, 0.009), (-25, 0, 0))],
    head=(0, -0.028, 0.082), head_r=0.0165,
    shoulder=(0.0165, -0.008, 0.066),
    wing_axis=((0, -0.006, 0.056), (0, 0.06, 0.05)),
    wing_theta=(36.0, 30.0), wing_width=58.0, wing_thick=0.0024,
    span=0.105, chord=0.046,
    tail=((0, 0.03, 0.052), (0, 0.088, 0.064), 0.026),
    beak=((0, -0.041, 0.081), (0, -0.061, 0.0795), 0.0055),
    eye_dir=(0.78, -0.55, 0.28), eye_r=0.0042,
    legs=[(0.008, 0.002, 0.03), (0.009, -0.001, 0.004)], leg_r=0.0022, toe=0.016, toe_r=0.0016,
    neck=(0.064, 0.074),
    target=3200,
)

PIGEON = BirdSpec(
    name="pigeon",
    blobs=[((0, 0.012, 0.115), (0.05, 0.08, 0.052), (-12, 0, 0)),
           ((0, -0.03, 0.11), (0.046, 0.045, 0.048), (0, 0, 0)),
           ((0, 0.005, 0.088), (0.04, 0.055, 0.03), (0, 0, 0)),
           ((0, -0.058, 0.168), (0.024, 0.026, 0.028), (-20, 0, 0)),
           ((0, -0.068, 0.208), (0.024, 0.028, 0.024), (0, 0, 0)),
           ((0, 0.075, 0.122), (0.028, 0.035, 0.02), (-15, 0, 0))],
    head=(0, -0.068, 0.208), head_r=0.024,
    shoulder=(0.04, -0.02, 0.15),
    wing_axis=((0, -0.02, 0.125), (0, 0.15, 0.115)),
    wing_theta=(36.0, 28.0), wing_width=58.0, wing_thick=0.004,
    span=0.27, chord=0.11,
    tail=((0, 0.07, 0.115), (0, 0.225, 0.122), 0.064),
    beak=((0, -0.086, 0.205), (0, -0.104, 0.2), 0.0055),
    eye_dir=(0.8, -0.45, 0.4), eye_r=0.0052,
    legs=[(0.017, 0.012, 0.07), (0.019, 0.008, 0.006)], leg_r=0.0045, toe=0.03, toe_r=0.0028,
    neck=(0.13, 0.18),
    target=5200,
)


def body_mask(spec):
    """Farbmaske: Brust/Kehle (+), Kappe/Nacken (−). Für die Taube: Hals schillernd (−)."""
    if spec.name == "pigeon":
        def fn(co):
            # Hals (zwischen Rumpf und Kopf, vorn und an den Seiten) schillert, Kopf und Rumpf grau
            neck = smoothstep(0.135, 0.155, co.z) * smoothstep(0.2, 0.185, co.z) * smoothstep(0.0, -0.035, co.y)
            return -neck
        return fn

    hx, hy, hz = spec.head

    def fn(co):
        front = smoothstep(-0.004, -0.02, co.y)          # vorn am Rumpf
        low = smoothstep(0.086, 0.072, co.z)              # bis unter die Augen
        breast = front * low * smoothstep(0.012, 0.03, co.z)
        cap = smoothstep(hz + 0.004, hz + 0.012, co.z) * smoothstep(hy + 0.022, hy + 0.004, co.y)
        return breast - cap
    return fn


def build(spec, M, coll):
    """Netz-Teile eines Vogels: liefert (Parts, Knochen)."""
    parts = AL.Parts()
    hx, hy, hz = spec.head
    n0, n1 = spec.neck

    def body_weights(co):
        w = smoothstep(n0, n1, co.z) * smoothstep(hy + 0.03 if spec.name == "bird" else hy + 0.06, hy, co.y)
        return {"body": 1.0 - w, "head": w}

    # Körper + Kopf: ein weicher Körper
    blobs = AL.Blobs(coll)
    for c, size, rot in spec.blobs:
        blobs.add(c, size, rot)
    body = blobs.mesh(target_faces=spec.target, smooth=2)
    tree = AL.bvh_of(body)
    parts.add_mesh(body, M["plumage"], body_weights, body_mask(spec))

    # Flügel (links +x, rechts −x): Schale auf dem Körper, Formvariante „spread“ = ausgebreitet
    (a0, a1) = (Vector(spec.wing_axis[0]), Vector(spec.wing_axis[1]))
    th0, th1 = spec.wing_theta
    for side, bone in ((1, "l"), (-1, "r")):
        def grid(u, v, side=side):
            origin = a0.lerp(a1, u)
            # Breite: vorn rund, in der Mitte am breitesten, hinten spitz (Handschwingen)
            width = spec.wing_width * (0.16 + 0.84 * math.sin(math.pi * min(1.0, 0.1 + u * 0.95)) ** 0.8)
            theta = math.radians(th0 + (th1 - th0) * u + (v - 0.5) * width)
            return origin, (side * math.cos(theta), 0.0, math.sin(theta))

        def thick(u, v):
            return spec.wing_thick * (0.45 + 0.55 * math.sin(math.pi * v)) * (1.0 - 0.45 * u)

        joint = Vector(spec.shoulder) * Vector((side, 1, 1))

        def spread(u, v, face, side=side, joint=joint):
            span = spec.span * u
            # Flügelform: am Körper breit, Spitze rund; Hinterkante mit Federn (leichte Wellen)
            chord = spec.chord * (1.0 - 0.3 * u) * math.sqrt(max(0.0, 1.0 - u ** 6)) + spec.chord * 0.08
            feathers = 0.04 * spec.chord * math.sin(u * math.pi * 7) * v * v
            y = (v - 0.32) * chord + feathers
            camber = 0.12 * spec.chord * math.sin(math.pi * v) * (1.0 - 0.6 * u)
            z = camber + 0.1 * spec.span * u * u + face * thick(u, v) * 0.5
            # Wurzel steckt im Körper (keine Lücke zwischen Flügel und Rumpf)
            return (side * (abs(joint.x) * 0.55 + span), joint.y + y, joint.z + z)

        me, keys, params = AL.surface_shell(tree, None, None, grid, thick, spread=spread)
        weights = []
        for (u, v) in params:
            w = smoothstep(0.42, 0.62, u)
            weights.append({"wing_" + bone: 1.0 - w, "wingtip_" + bone: w})
        parts.add_mesh(me, M["wing"], weights, 0.0, keys={"spread": keys})

    # Schwanz: flacher Fächer, Wurzel steckt im Bürzel
    root, tip, width = (Vector(spec.tail[0]), Vector(spec.tail[1]), spec.tail[2])
    tail = Body("Schwanz", M["wing"], coll, seed=21, vary=0.0)
    tail.leaf(root, tip - root, (0, -0.2, 1.0), (tip - root).length, width, shape="oval", thick=spec.wing_thick * 0.9,
              curl=0.05)
    parts.add_body(tail, lambda co: {"tail": 1.0})

    # Schnabel: Kegel, Wurzel im Kopf
    b0, b1, br = Vector(spec.beak[0]), Vector(spec.beak[1]), spec.beak[2]
    beak = Body("Schnabel", M["beak"], coll, seed=22, vary=0.0)
    beak.tube([b0, b1], lambda t: br * (1.0 - t) + br * 0.14, segs=12, round_ends=True)
    parts.add_body(beak, lambda co: {"head": 1.0})

    # Augen: dunkel glänzend, leicht in den Kopf eingelassen
    eyes = Body("Augen", M["eye"], coll, seed=23, vary=0.0)
    ex, ey, ez = spec.eye_dir
    for sx in (-1, 1):
        p, n = _eye(tree, spec.head, (sx * ex, ey, ez), spec.eye_r)
        eyes.blob(p - n * spec.eye_r * 0.35, spec.eye_r, subdiv=2, lump=0.0, scale=(1.0, 1.0, 1.05))
    parts.add_body(eyes, lambda co: {"head": 1.0})

    # Beine und Zehen (Wurzel im Bauch)
    (top, foot) = (Vector(spec.legs[0]), Vector(spec.legs[1]))
    for sx, bone in ((1, "leg_l"), (-1, "leg_r")):
        leg = Body("Bein", M["leg"], coll, seed=24, vary=0.0)
        t = Vector((sx * top.x, top.y, top.z))
        f = Vector((sx * foot.x, foot.y, foot.z))
        leg.tube([t, f], spec.leg_r, segs=8, round_ends=True)
        for tx, ty in ((-0.4, -1.0), (0.0, -1.1), (0.4, -1.0), (0.0, 0.75)):
            end = f + Vector((sx * tx * spec.toe * 0.55, ty * spec.toe, -f.z + spec.toe_r * 0.9))
            leg.tube([f, end], spec.toe_r, segs=6, round_ends=True)
        parts.add_body(leg, lambda co, bone=bone: {bone: 1.0})

    # Knochen: (Name, Kopf, Ende, Eltern)
    s = 1.0 if spec.name == "bird" else 2.3
    sh = Vector(spec.shoulder)
    bones = [
        ("root", (0, 0, 0), (0, 0, 0.02 * s), None),
        ("body", (0, 0.006 * s, 0.035 * s), (0, 0.006 * s, 0.065 * s), "root"),
        ("head", (0, hy + 0.006 * s, n0), (0, hy - 0.004 * s, hz + spec.head_r), "body"),
        ("tail", tuple(root), tuple(tip), "body"),
        ("leg_l", (top.x, top.y, top.z), (foot.x, foot.y, foot.z), "root"),
        ("leg_r", (-top.x, top.y, top.z), (-foot.x, foot.y, foot.z), "root"),
    ]
    for side, b in ((1, "l"), (-1, "r")):
        j = (side * sh.x, sh.y, sh.z)
        wrist = (side * (sh.x + spec.span * 0.48), sh.y, sh.z + spec.span * 0.03)
        tip = (side * (sh.x + spec.span), sh.y + spec.chord * 0.2, sh.z + spec.span * 0.1)
        bones.append(("wing_" + b, j, wrist, "body"))
        bones.append(("wingtip_" + b, wrist, tip, "wing_" + b))
    return parts, bones
