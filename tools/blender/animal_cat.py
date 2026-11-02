"""Katze im weichen Stil (seit Etappe 6h): ein Körper aus Metaballs (Rumpf, Hals, großer runder Kopf, Beine,
Pfoten und Schwanz fließen ohne Nähte ineinander), Ohren, Augen, Nase und Mund als eigene geschlossene Körper.

Skelett nach dem Vorbild einer echten Katze: Becken (hips) – Rücken (spine1) – Brust (chest) – Hals – Kopf,
Ohren, Vorderbeine (Oberarm, Unterarm, Pfote), Hinterbeine (Oberschenkel, Unterschenkel, Mittelfuß, Pfote),
Schwanz in fünf Gliedern. Gewichte: je Ecke die nächsten Knochen (weich verteilt, dann über das Netz geglättet).

Augen: Formvarianten „blink“ (geschlossen, Linie leicht nach unten gebogen – schlafen, blinzeln) und „happy“
(zufrieden zugekniffen, Bogen nach oben – streicheln, freundlich schauen). Farbmaske im Fell: > 0 = helles Fell
(Schnauze, Kinn, Brust, Bauch, Pfoten, Schwanzspitze; je Katze ab einem anderen Wert), < 0 = dunkler Rücken.

Blender-Koordinaten: vorn = -y, oben = z, Ursprung zwischen den Pfoten auf dem Boden.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import animal_lib as AL
from animal_lib import smoothstep
from storybook_lib import Body

# Gelenke (linke Seite, x > 0; rechts gespiegelt)
FRONT = [Vector((0.04, -0.072, 0.168)), Vector((0.043, -0.068, 0.1)), Vector((0.043, -0.083, 0.032)),
         Vector((0.043, -0.108, 0.006))]
HIND = [Vector((0.046, 0.108, 0.175)), Vector((0.05, 0.066, 0.104)), Vector((0.047, 0.138, 0.046)),
        Vector((0.046, 0.112, 0.012)), Vector((0.046, 0.088, 0.004))]
SPINE = [Vector((0, 0.13, 0.205)), Vector((0, 0.06, 0.208)), Vector((0, -0.02, 0.212)), Vector((0, -0.092, 0.218))]
NECK = [Vector((0, -0.092, 0.218)), Vector((0, -0.13, 0.262))]
HEAD = [Vector((0, -0.13, 0.262)), Vector((0, -0.2, 0.33))]
HEAD_CENTER = Vector((0, -0.165, 0.302))
TAIL = [Vector((0, 0.15, 0.213)), Vector((0, 0.205, 0.212)), Vector((0, 0.26, 0.205)), Vector((0, 0.31, 0.196)),
        Vector((0, 0.355, 0.19)), Vector((0, 0.395, 0.188))]
EAR = (Vector((0.038, -0.148, 0.342)), Vector((0.05, -0.151, 0.384)))


def _lower(v):
    """Kürzere Beine (Chibi-Maß): alles über den Pfoten etwas tiefer."""
    v = Vector(v)
    v.z -= 0.022 * smoothstep(0.03, 0.12, v.z)
    return v


FRONT = [_lower(v) for v in FRONT]
HIND = [_lower(v) for v in HIND]
SPINE = [_lower(v) for v in SPINE]
NECK = [_lower(v) for v in NECK]
HEAD = [_lower(v) for v in HEAD]
HEAD_CENTER = _lower(HEAD_CENTER)
TAIL = [_lower(v) for v in TAIL]
EAR = (_lower(EAR[0]), _lower(EAR[1]))


def _mirror(v):
    return Vector((-v.x, v.y, v.z))


def bones():
    """Knochen: (Name, Kopf, Ende, Eltern)."""
    b = [("root", (0, 0, 0), (0, 0, 0.05), None),
         ("hips", tuple(SPINE[0]), tuple(SPINE[1]), "root"),
         ("spine1", tuple(SPINE[1]), tuple(SPINE[2]), "hips"),
         ("chest", tuple(SPINE[2]), tuple(SPINE[3]), "spine1"),
         ("neck", tuple(NECK[0]), tuple(NECK[1]), "chest"),
         ("head", tuple(HEAD[0]), tuple(HEAD[1]), "neck")]
    for side, s in ((1, "l"), (-1, "r")):
        m = (lambda v: v) if side > 0 else _mirror
        b.append(("ear_" + s, tuple(m(EAR[0])), tuple(m(EAR[1])), "head"))
        f = [m(v) for v in FRONT]
        b.append(("fl_upper_" + s, tuple(f[0]), tuple(f[1]), "chest"))
        b.append(("fl_lower_" + s, tuple(f[1]), tuple(f[2]), "fl_upper_" + s))
        b.append(("fl_paw_" + s, tuple(f[2]), tuple(f[3]), "fl_lower_" + s))
        h = [m(v) for v in HIND]
        b.append(("bl_upper_" + s, tuple(h[0]), tuple(h[1]), "hips"))
        b.append(("bl_lower_" + s, tuple(h[1]), tuple(h[2]), "bl_upper_" + s))
        b.append(("bl_foot_" + s, tuple(h[2]), tuple(h[3]), "bl_lower_" + s))
        b.append(("bl_paw_" + s, tuple(h[3]), tuple(h[4]), "bl_foot_" + s))
    parent = "hips"
    for i in range(len(TAIL) - 1):
        name = "tail%d" % (i + 1)
        b.append((name, tuple(TAIL[i]), tuple(TAIL[i + 1]), parent))
        parent = name
    return b


def body_blobs(coll):
    """Weicher Körper: Rumpf, Hals, Kopf, Schnauze, Beine, Pfoten, Schwanz."""
    bl = AL.Blobs(coll, scale=4.0)
    L = _lower   # feste Zahlen unten werden abgesenkt (die Gelenk-Listen oben sind es schon)
    bl.add(L((0, -0.056, 0.205)), (0.058, 0.074, 0.068), (-6, 0, 0))       # Brust
    bl.add(L((0, 0.035, 0.192)), (0.052, 0.08, 0.058))                      # Bauch/Taille
    bl.add(L((0, 0.112, 0.2)), (0.058, 0.056, 0.062))                       # Becken
    bl.add(L((0, -0.118, 0.247)), (0.038, 0.04, 0.046), (-35, 0, 0))        # Hals
    bl.add(tuple(HEAD_CENTER), (0.066, 0.058, 0.056))                   # Kopf (groß und rund)
    bl.add(L((0, -0.196, 0.279)), (0.05, 0.03, 0.032))                      # Wangen
    bl.add(L((0, -0.219, 0.276)), (0.026, 0.02, 0.019))                     # Schnauze
    bl.add(L((0, -0.207, 0.259)), (0.018, 0.016, 0.011))                    # Kinn
    for side in (1, -1):
        m = (lambda v: v) if side > 0 else _mirror
        bl.add(L(m(Vector((0.037, -0.066, 0.185)))), (0.03, 0.04, 0.05))          # Schulter
        bl.add(L(m(Vector((0.04, 0.104, 0.158)))), (0.034, 0.052, 0.058), (18, 0, 0))  # Oberschenkel
        f = [m(v) for v in FRONT]
        bl.capsule(f[0], f[1], 0.022, stiffness=3.0)
        bl.capsule(f[1], f[2], 0.0185, stiffness=3.0)
        bl.add(L(m(Vector((0.043, -0.1, 0.015)))), (0.019, 0.027, 0.0135), stiffness=3.0)    # Vorderpfote
        h = [m(v) for v in HIND]
        bl.capsule(h[1], h[2], 0.0195, stiffness=3.0)
        bl.capsule(h[2], h[3], 0.016, stiffness=3.0)
        bl.add(L(m(Vector((0.046, 0.098, 0.014)))), (0.019, 0.029, 0.013), stiffness=3.0)    # Hinterpfote
    for i in range(len(TAIL) - 1):
        r = 0.0165 - 0.004 * i / (len(TAIL) - 2)
        bl.capsule(TAIL[i], TAIL[i + 1], r, stiffness=3.0)
    return bl


def fur_mask(co):
    """Farbmaske: helles Fell (+, je stärker, desto „sicherer“ hell) und dunkler Rücken (−)."""
    x, y, z = co
    z += 0.022 * smoothstep(0.01, 0.1, z)
    ax = abs(x)
    muzzle = smoothstep(-0.19, -0.215, y) * smoothstep(0.3, 0.282, z)
    chin = smoothstep(-0.17, -0.2, y) * smoothstep(0.27, 0.25, z) * smoothstep(0.04, 0.02, ax)
    chest = smoothstep(-0.085, -0.115, y) * smoothstep(0.255, 0.235, z) * smoothstep(0.1, 0.12, z) * smoothstep(0.05, 0.025, ax)
    belly = smoothstep(0.15, 0.135, z) * smoothstep(-0.08, -0.05, y) * smoothstep(0.12, 0.09, y) * smoothstep(0.042, 0.022, ax)
    paws = smoothstep(0.04, 0.022, z)
    tip = smoothstep(0.36, 0.39, y) * smoothstep(0.25, 0.22, z)
    light = max(muzzle * 1.0, chin * 0.95, chest * 0.88, paws * 0.8, belly * 0.68, tip * 0.5)
    back = smoothstep(0.235, 0.26, z) * smoothstep(-0.09, -0.04, y) * smoothstep(0.17, 0.12, y)
    return light if light > 0.05 else -0.7 * back


def _neighbors(me):
    nb = [set() for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nb[a].add(b)
        nb[b].add(a)
    return nb


def body_weights(me, bone_list):
    """Gewichte des Körpers: nächste Knochen (Abstand zur Knochenstrecke), nur Knochen der eigenen Seite, weich
    über das Netz geglättet. Liefert je Ecke {knochen: gewicht}."""
    segs = []
    for name, head, tail, parent in bone_list:
        if name in ("root",) or name.startswith("ear"):
            continue
        segs.append((name, Vector(head), Vector(tail)))
    raw = []
    for v in me.vertices:
        co = v.co
        ds = []
        for name, a, b in segs:
            side = name[-2:]
            if side == "_l" and co.x < -0.012:
                continue
            if side == "_r" and co.x > 0.012:
                continue
            d = b - a
            t = max(0.0, min(1.0, (co - a).dot(d) / d.length_squared))
            ds.append((name, (a + d * t - co).length))
        dmin = min(d for _, d in ds)
        w = {n: 1.0 / (d + 0.006) ** 5 for n, d in ds if d < dmin + 0.03}
        total = sum(w.values())
        raw.append({n: x / total for n, x in w.items()})
    nb = _neighbors(me)
    for _ in range(4):
        new = []
        for i, w in enumerate(raw):
            acc = dict(w)
            for j in nb[i]:
                for n, x in raw[j].items():
                    acc[n] = acc.get(n, 0.0) + x
            total = sum(acc.values())
            new.append({n: x / total for n, x in acc.items()})
        raw = new
    out = []
    for w in raw:
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        total = sum(x for _, x in top)
        out.append({n: x / total for n, x in top if x / total > 0.01})
    return out


def _eye_frame(tree, side):
    d = Vector((side * 0.52, -0.78, 0.33)).normalized()
    hit = tree.ray_cast(HEAD_CENTER + d * 0.3, -d, 0.6)
    p, n = hit[0], hit[1]
    up = (Vector((0, 0, 1)) - n * n.z).normalized()
    right = up.cross(n).normalized()
    return p, n, up, right


def eye_parts(tree, M, coll):
    """Augen: Iris (Farbe der Katze), Pupille, Glanzpunkt – mit Formvarianten blink und happy.
    Liefert [(Netz, Material, Formvarianten)]."""
    result = []
    for side in (1, -1):
        p, n, up, right = _eye_frame(tree, side)
        frame = Matrix((right, up, n)).transposed()   # Spalten: rechts, oben, außen
        to_world = Matrix.Translation(p) @ frame.to_4x4()
        w, h = 0.0165, 0.017                          # halbe Breite/Höhe des Auges

        def blob(center, size, mat, seed):
            b = Body("Auge", mat, coll, seed=seed, vary=0.0)
            b.blob(center, 1.0, subdiv=3, lump=0.0, scale=size)
            o = b.build(smooth_angle=180)
            dg = bpy.context.evaluated_depsgraph_get()
            me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), depsgraph=dg)
            bpy.data.objects.remove(o)
            me.transform(to_world)
            return me

        def keys(me, layer):
            """Formvarianten: Ecken in Augen-Koordinaten (x rechts, y oben, z außen) verschieben."""
            inv = to_world.inverted()
            blink, happy = [], []
            for v in me.vertices:
                q = inv @ v.co
                xn = max(-1.0, min(1.0, q.x / w))
                for key, sign in ((blink, -1.0), (happy, 1.0)):
                    if layer == "pupil":
                        # Pupille wird zur dunklen, gebogenen Linie über die ganze Breite des Auges
                        x = xn * w * 1.12
                        arc = sign * 0.45 * h * (1.0 - xn * xn) - sign * 0.12 * h
                        y = arc + q.y * 0.2
                        key.append(to_world @ Vector((x, y, q.z + 0.0006)))
                    else:
                        # Iris und Glanz verschwinden im Kopf
                        key.append(to_world @ Vector((q.x * 0.6, q.y * 0.3 - 0.003, q.z - 0.0065)))
            return {"blink": blink, "happy": happy}

        iris = blob((0, 0, -0.0035), (w, h, 0.0052), M["eye"], 31)
        pupil = blob((0, 0, 0.0011), (w * 0.42, h * 0.78, 0.0024), M["pupil"], 32)
        shine = blob((w * 0.32 * side, h * 0.38, 0.0028), (0.0034, 0.0034, 0.0014), M["shine"], 33)
        result.append((iris, M["eye"], keys(iris, "iris")))
        result.append((pupil, M["pupil"], keys(pupil, "pupil")))
        result.append((shine, M["shine"], keys(shine, "shine")))
    return result


def surface_point(tree, start, direction, embed=0.0):
    d = Vector(direction).normalized()
    hit = tree.ray_cast(Vector(start) - d * 0.2, d, 0.5)
    if hit[0] is None:
        return Vector(start), -d
    return hit[0] - hit[1] * embed, hit[1]


def build(M, coll):
    """Alle Teile der Katze: liefert (Parts, Knochen)."""
    parts = AL.Parts()
    bone_list = bones()
    body = body_blobs(coll).mesh(target_faces=9000, smooth=2)
    tree = AL.bvh_of(body)
    weights = body_weights(body, bone_list)
    parts.add_mesh(body, M["fur"], weights, fur_mask)

    # Ohren: Muschel (Fell) und Innenohr (rosa), Wurzel im Kopf
    for side, s in ((1, "l"), (-1, "r")):
        m = (lambda v: v) if side > 0 else _mirror
        base, tip = m(EAR[0]), m(EAR[1])
        out = Vector((side * 0.35, -1.0, 0.1)).normalized()
        ear = Body("Ohr", M["fur"], coll, seed=40 + side, vary=0.0)
        ear.leaf(base - (tip - base).normalized() * 0.014, (tip - base), out, (tip - base).length + 0.018, 0.06,
                 shape="blade", thick=0.009, curl=0.25)
        parts.add_body(ear, lambda co, s=s: {"ear_" + s: 1.0}, mask=-0.2)
        inner = Body("Innenohr", M["ear"], coll, seed=42 + side, vary=0.0)
        inner.leaf(base + out * 0.0045 - (tip - base).normalized() * 0.002, (tip - base), out, (tip - base).length * 0.8,
                   0.04, shape="blade", thick=0.003, curl=0.25)
        parts.add_body(inner, lambda co, s=s: {"ear_" + s: 1.0})

    # Augen mit Formvarianten
    for me, mat, keys in eye_parts(tree, M, coll):
        parts.add_mesh(me, mat, lambda co: {"head": 1.0}, 0.0, keys=keys)

    # Nase: kleines rosa Dreieck-Kissen, leicht eingelassen
    tip_pt, tip_n = surface_point(tree, _lower((0, -0.25, 0.287)), (0, 1, -0.15), embed=0.0012)
    nose = Body("Nase", M["nose"], coll, seed=50, vary=0.0)
    nose.blob(tip_pt, 1.0, subdiv=3, lump=0.0, scale=(0.0085, 0.0055, 0.0058))
    parts.add_body(nose, lambda co: {"head": 1.0})

    # Mund: feine dunkle Linie („w“) unter der Nase, auf der Haut
    mouth_pts = []
    for x, z in ((-0.013, 0.267), (-0.0065, 0.2635), (0.0, 0.2665), (0.0065, 0.2635), (0.013, 0.267)):
        p, n = surface_point(tree, _lower((x, -0.26, z)), (0, 1, 0), embed=0.0004)
        mouth_pts.append(p)
    mouth = Body("Mund", M["mouth"], coll, seed=51, vary=0.0)
    mouth.tube(mouth_pts, 0.0011, segs=6, round_ends=True)
    top, _ = surface_point(tree, _lower((0, -0.26, 0.279)), (0, 1, 0), embed=0.0004)
    mouth.tube([top, mouth_pts[2]], 0.001, segs=6, round_ends=True)
    parts.add_body(mouth, lambda co: {"head": 1.0})
    return parts, bone_list
