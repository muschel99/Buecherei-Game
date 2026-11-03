"""Katze im weichen Chibi-Stil (seit Etappe 6h, Form nach den Vorlagen der Entwicklerin): ein Körper aus Metaballs –
sehr großer runder Kopf mit Pausbacken, kleiner runder Rumpf, kurze Beinchen mit runden Pfoten, buschiger Schwanz –,
große dreieckige Ohren (wachsen aus dem Kopf, vorn eine Mulde) – und eine kleine Nase als eigener geschlossener Körper.

Augen, rosa Innenohren, Mund, Wangenröte und Tigerstreifen sind GEMALT (wie bei den Chibi-Passanten): der Katzen-Shader
(assets/shaders/storybook_cat.gdshader) malt sie nach der Ruhehaltung aufs Fell. Wo sie sitzen, rechnet
face_params() aus und das Bau-Script schreibt es ins Material „Katze Fell“. Blinzeln/zufrieden schauen stellt das
Spiel über die Material-Werte eye_blink und eye_happy ein (StreetCat._update_face).

Skelett nach dem Vorbild einer echten Katze: Becken (hips) – Rücken (spine1) – Brust (chest) – Hals – Kopf,
Ohren, Vorderbeine (Oberarm, Unterarm, Pfote), Hinterbeine (Oberschenkel, Unterschenkel, Mittelfuß, Pfote),
Schwanz in fünf Gliedern. Gewichte: je Ecke die nächsten Knochen (weich verteilt, dann über das Netz geglättet).

Farbmaske im Fell: > 0 = helles Fell (Schnauze, Kinn, untere Wangen, Brustlatz, Pfoten, Bauch; je Katze ab einem
anderen Wert), < 0 = dunkler Rücken.

Blender-Koordinaten: vorn = -y, oben = z, Ursprung zwischen den Pfoten auf dem Boden. Godot: x gleich, y = z,
z = -y (godot()).
"""
import math

import bpy
from mathutils import Vector

import animal_lib as AL
from animal_lib import smoothstep
from storybook_lib import Body

# Gelenke (linke Seite, x > 0; rechts gespiegelt). Chibi-Maß: Beine kurz, Kopf groß und weit vorn.
FRONT = [Vector((0.034, -0.05, 0.114)), Vector((0.036, -0.038, 0.068)), Vector((0.037, -0.054, 0.024)),
         Vector((0.037, -0.074, 0.006))]
HIND = [Vector((0.04, 0.08, 0.108)), Vector((0.043, 0.05, 0.068)), Vector((0.042, 0.098, 0.033)),
        Vector((0.042, 0.082, 0.009)), Vector((0.042, 0.064, 0.004))]
SPINE = [Vector((0, 0.085, 0.12)), Vector((0, 0.035, 0.122)), Vector((0, -0.015, 0.124)), Vector((0, -0.06, 0.128))]
NECK = [Vector((0, -0.06, 0.128)), Vector((0, -0.088, 0.162))]
HEAD = [Vector((0, -0.088, 0.162)), Vector((0, -0.15, 0.236))]
HEAD_CENTER = Vector((0, -0.112, 0.205))
HEAD_SIZE = (0.083, 0.064, 0.066)          # Halbachsen des Kopfs (breit, tief, hoch)
TAIL = [Vector((0, 0.112, 0.126)), Vector((0, 0.142, 0.127)), Vector((0, 0.171, 0.128)), Vector((0, 0.199, 0.13)),
        Vector((0, 0.225, 0.132)), Vector((0, 0.248, 0.134))]
# Ohren wie in den Vorlagen: breite, weiche Dreiecke, schräg auf den Kopf gesetzt – die innere untere Ecke hoch auf
# der Kuppel, die äußere untere Ecke tief an der Kopfseite (etwa auf Höhe der Augen-Oberkante), die Außenkante steigt
# fast senkrecht zur runden Spitze und setzt so den runden Kopfumriss fort. Öffnung nach vorn, leicht nach außen.
# Ecken (linkes Ohr): innen unten, außen unten, Spitze. Kanten = dicker Fellrand, die Mitte dünner (Mulde).
EAR_IN = Vector((0.033, -0.114, 0.265))
EAR_OUT = Vector((0.079, -0.126, 0.222))
EAR_TIP = Vector((0.071, -0.12, 0.303))
EAR = ((EAR_IN + EAR_OUT) / 2, EAR_TIP)

# Gemaltes Gesicht: Augen (Richtung vom Kopfmittelpunkt; groß, etwas unter der Kopfmitte, weit auseinander),
# Halbachsen der Augen, Mund (Höhe), Nase
EYE_DIR = (0.5, -0.86, -0.1)
EYE_SIZE = (0.0165, 0.0185)
MOUTH_Z = 0.174
MOUTH_SIZE = (0.0085, 0.0035)
NOSE_Z = 0.187


def _mirror(v):
    return Vector((-v.x, v.y, v.z))


def ear_frame(side):
    """Ebene eines Ohrs: Ecke innen unten, Achse e1 (zur äußeren Ecke), e2 (in der Ebene zur Spitze), n (vorn),
    2D-Lage der äußeren Ecke und der Spitze in (e1, e2)."""
    m = (lambda v: v) if side > 0 else _mirror
    i, o, t = m(EAR_IN), m(EAR_OUT), m(EAR_TIP)
    e1 = (o - i).normalized()
    e2 = (t - i) - e1 * (t - i).dot(e1)
    e2.normalize()
    n = e1.cross(e2) if side > 0 else e2.cross(e1)
    return i, e1, e2, n, Vector(((o - i).dot(e1), 0.0)), Vector(((t - i).dot(e1), (t - i).dot(e2)))


def _ear_coords(co, side):
    """Lage im Ohr: Höhe über der Grundlinie (0 = Grund, 1 = Spitze), Abstand zur Ebene, Abstand außerhalb des
    Dreiecks in der Ebene (0 = innen)."""
    i, e1, e2, n, o2, t2 = ear_frame(side)
    d = Vector(co) - i
    a, b, w = d.dot(e1), d.dot(e2), d.dot(n)
    h = b / t2.y
    # Abstand zum Dreieck (grob): links/rechts der Seitenkanten
    def side_out(p0, p1):
        e = p1 - p0
        nrm = Vector((e.y, -e.x)).normalized()
        return (Vector((a, b)) - p0).dot(nrm)
    out = max(side_out(Vector((0, 0)), t2) * -1.0, side_out(o2, t2), -b)
    return h, w, out


def ear_weight(co, side):
    """Wie stark eine Ecke am Ohr-Knochen hängt (0 = Kopf): von der Grundlinie weich zur Spitze."""
    h, w, out = _ear_coords(co, side)
    if abs(w) > 0.03 or out > 0.014 or h < 0.05:
        return 0.0
    return smoothstep(0.12, 0.42, h)


def godot(v):
    """Blender-Lage → Godot-Lage (x gleich, y oben, z vorn)."""
    return Vector((v[0], v[2], -v[1]))


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
    """Weicher Körper: Rumpf, Hals, großer Kopf mit Pausbacken und Schnäuzchen, kurze Beine, runde Pfoten,
    buschiger Schwanz."""
    bl = AL.Blobs(coll, scale=4.0)
    bl.add((0, -0.038, 0.118), (0.05, 0.058, 0.054), (-6, 0, 0))          # Brust
    bl.add((0, 0.02, 0.112), (0.048, 0.06, 0.048))                         # Bauch
    bl.add((0, 0.074, 0.116), (0.052, 0.05, 0.054))                        # Becken
    bl.add((0, -0.07, 0.145), (0.032, 0.03, 0.036), (-30, 0, 0))           # Hals (kurz, der Kopf sitzt auf der Brust)
    bl.add((0, -0.07, 0.115), (0.03, 0.026, 0.04))                         # Brustlatz (flauschig vorgewölbt)
    bl.add(tuple(HEAD_CENTER), HEAD_SIZE)                                  # Kopf (groß und rund)
    for side in (1, -1):
        bl.add((side * 0.04, -0.122, 0.185), (0.036, 0.034, 0.026), stiffness=1.2)   # Pausbacken (weich, knapp unter den Augen)
    bl.add((0, -0.164, 0.181), (0.023, 0.016, 0.016))                      # Schnäuzchen
    bl.add((0, -0.152, 0.167), (0.015, 0.014, 0.01))                       # Kinn
    for side in (1, -1):
        m = (lambda v: v) if side > 0 else _mirror
        bl.add(m(Vector((0.032, -0.05, 0.1))), (0.028, 0.032, 0.038))                      # Schulter
        bl.add(m(Vector((0.044, 0.07, 0.088))), (0.039, 0.049, 0.052), (18, 0, 0))        # Oberschenkel (rund, voll)
        f = [m(v) for v in FRONT]
        bl.capsule(f[0], f[1], 0.0195, stiffness=3.0)
        bl.capsule(f[1], f[2], 0.0182, stiffness=3.0)
        bl.add(m(Vector((0.037, -0.064, 0.0165))), (0.021, 0.025, 0.0125), stiffness=3.0)  # Vorderpfote (rund)
        h = [m(v) for v in HIND]
        bl.capsule(h[1], h[2], 0.018, stiffness=3.0)
        bl.capsule(h[2], h[3], 0.016, stiffness=3.0)
        bl.add(m(Vector((0.042, 0.075, 0.0155))), (0.02, 0.027, 0.0125), stiffness=3.0)   # Hinterpfote (rund)
    for i in range(len(TAIL) - 1):
        r = 0.0175 + 0.003 * math.sin(math.pi * i / (len(TAIL) - 2))       # buschig, in der Mitte am dicksten
        bl.capsule(TAIL[i], TAIL[i + 1], r, stiffness=3.0)
    bl.add(tuple(TAIL[-1] + Vector((0, -0.004, 0))), (0.0185, 0.02, 0.0185))  # runde Schwanzspitze
    for side in (1, -1):
        # Ohr: dicker Rand entlang der Kanten (Röhren), die Mitte als flache Füllung etwas zurückgesetzt (Mulde)
        m = (lambda v: v) if side > 0 else _mirror
        i, o, t = m(EAR_IN), m(EAR_OUT), m(EAR_TIP)
        base, e1, e2, n, o2, t2 = ear_frame(side)
        bl.capsule(i, t, 0.0095, stiffness=3.0)
        bl.capsule(o, t, 0.0105, stiffness=3.0)
        bl.capsule(i + (o - i) * 0.1, o - (o - i) * 0.1, 0.01, stiffness=3.0)
        for k, (wa, wb, wt) in enumerate(((0.33, 0.33, 0.34), (0.5, 0.35, 0.15), (0.2, 0.25, 0.55))):
            c = i * wa + o * wb + t * wt - n * 0.004
            bl.add_axes(c, (0.017, 0.017, 0.0065), (e1, e2, n if side > 0 else -n))
    return bl


def fur_mask(co):
    """Farbmaske: helles Fell (+, je stärker, desto „sicherer“ hell) und dunkler Rücken (−)."""
    x, y, z = co
    ax = abs(x)
    face = smoothstep(-0.13, -0.165, y)                                    # Vorderseite des Kopfs
    muzzle = face * smoothstep(0.2, 0.184, z) * smoothstep(0.142, 0.158, z) * smoothstep(0.04, 0.018, ax)
    chin = smoothstep(-0.125, -0.15, y) * smoothstep(0.176, 0.158, z) * smoothstep(0.036, 0.014, ax)
    cheeks = face * smoothstep(0.204, 0.186, z) * smoothstep(0.066, 0.036, ax) * smoothstep(0.145, 0.162, z)
    bib_w = 0.012 + 0.03 * smoothstep(0.06, 0.15, z)                       # Latz: unten schmal, oben breit (V)
    bib = smoothstep(-0.064, -0.09, y) * smoothstep(0.165, 0.145, z) * smoothstep(0.045, 0.068, z) \
        * smoothstep(bib_w + 0.016, bib_w, ax)
    paws = smoothstep(0.034, 0.016, z)
    belly = smoothstep(0.09, 0.066, z) * smoothstep(-0.075, -0.04, y) * smoothstep(0.105, 0.065, y) \
        * smoothstep(0.046, 0.018, ax)
    light = max(muzzle * 1.0, chin * 0.97, bib * 0.92, paws * 0.85, belly * 0.72, cheeks * 0.68)
    back = smoothstep(0.155, 0.17, z) * smoothstep(-0.05, -0.02, y) * smoothstep(0.11, 0.08, y)
    tips = 0.0
    for side in (1, -1):
        if ear_weight(co, side) > 0.0:
            h, w, out = _ear_coords(co, side)
            tips = max(tips, smoothstep(0.7, 0.92, h) * smoothstep(-0.001, -0.006, w))  # Ohrspitzen hinten dunkler
    if light > 0.05:
        return light
    return -max(0.7 * back, 0.85 * tips)


def _neighbors(me):
    nb = [set() for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nb[a].add(b)
        nb[b].add(a)
    return nb


def body_weights(me, bone_list):
    """Gewichte des Körpers: nächste Knochen (Abstand zur Knochenstrecke), nur Knochen der eigenen Seite, weich
    über das Netz geglättet. Der ganze Kopf (bis zu den Pausbacken) hängt am Kopf-Knochen. Liefert je Ecke
    {knochen: gewicht}."""
    segs = []
    for name, head, tail, parent in bone_list:
        if name in ("root",) or name.startswith("ear"):
            continue
        segs.append((name, Vector(head), Vector(tail)))
    hx, hy, hz = HEAD_SIZE
    raw = []
    for v in me.vertices:
        co = v.co
        ear = [(s, ear_weight(co, side)) for side, s in ((1, "l"), (-1, "r"))]
        ear = [e for e in ear if e[1] > 0.0]
        if ear:
            s, w = ear[0]
            raw.append({"ear_" + s: w, "head": 1.0 - w} if w < 0.999 else {"ear_" + s: 1.0})
            continue
        # im Kopf (Ellipsoid etwas größer als der Kopf, vorn bis zum Schnäuzchen): fest am Kopf
        d = co - HEAD_CENTER
        inside = (d.x / (hx * 1.35)) ** 2 + (d.y / (hy * 1.25)) ** 2 + (d.z / (hz * 1.2)) ** 2
        if inside < 0.75 or (d.y < -0.02 and inside < 1.0):
            raw.append({"head": 1.0})
            continue
        ds = []
        for name, a, b in segs:
            side = name[-2:]
            if side == "_l" and co.x < -0.012:
                continue
            if side == "_r" and co.x > 0.012:
                continue
            dd = b - a
            t = max(0.0, min(1.0, (co - a).dot(dd) / dd.length_squared))
            ds.append((name, (a + dd * t - co).length))
        dmin = min(dist for _, dist in ds)
        w = {n: 1.0 / (dist + 0.005) ** 5 for n, dist in ds if dist < dmin + 0.025}
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


def surface_point(tree, start, direction, embed=0.0):
    d = Vector(direction).normalized()
    hit = tree.ray_cast(Vector(start) - d * 0.2, d, 0.5)
    if hit[0] is None:
        return Vector(start), -d
    return hit[0] - hit[1] * embed, hit[1]


def face_params(tree):
    """Lage des gemalten Gesichts für den Katzen-Shader (Godot-Koordinaten der Ruhehaltung): linkes Auge
    (Mitte auf der Haut, Achsen quer/hoch), Mund, Kopf, Beginn von Schwanz und Beinen. Liefert {Name: Wert}."""
    d = Vector(EYE_DIR).normalized()
    hit = tree.ray_cast(HEAD_CENTER + d * 0.3, -d, 0.6)
    p, n = hit[0], hit[1]
    up = (Vector((0, 0, 1)) - n * n.z).normalized()
    right = up.cross(n).normalized()                  # zur Außenseite (+x)
    mouth, _ = surface_point(tree, (0, -0.25, MOUTH_Z), (0, 1, 0))
    ear_i, e1, e2, ear_n, o2, t2 = ear_frame(1)
    return {
        "ear_origin": godot(ear_i), "ear_e1": godot(e1), "ear_e2": godot(e2), "ear_n": godot(ear_n),
        "ear_out": tuple(o2), "ear_tip": tuple(t2),
        "eye_center": godot(p), "eye_right": godot(right), "eye_up": godot(up),
        "eye_size": EYE_SIZE, "mouth_center": godot(mouth), "mouth_size": MOUTH_SIZE,
        "head_center": godot(HEAD_CENTER), "head_radius": HEAD_SIZE[0],
        "tail_start": -(TAIL[0].y + 0.012), "leg_top": 0.062,
    }


def build(M, coll):
    """Alle Teile der Katze: liefert (Parts, Knochen, Gesichts-Werte für den Shader)."""
    parts = AL.Parts()
    bone_list = bones()
    body = body_blobs(coll).mesh(target_faces=9000, smooth=2)
    for v in body.vertices:
        # Pfotensohlen flach auf dem Boden (wie echte Pfoten, die aufliegen) – nichts ragt in den Boden
        if v.co.z < 0.0015:
            v.co.z = 0.0015
    tree = AL.bvh_of(body)
    weights = body_weights(body, bone_list)
    parts.add_mesh(body, M["fur"], weights, fur_mask)


    # Nase: kleines rosa Kissen (Dreieck-Form), leicht eingelassen
    tip_pt, tip_n = surface_point(tree, (0, -0.25, NOSE_Z), (0, 1, -0.1), embed=0.0012)
    nose = Body("Nase", M["nose"], coll, seed=50, vary=0.0)
    nose.blob(tip_pt, 1.0, subdiv=3, lump=0.0, scale=(0.0075, 0.005, 0.0052))
    parts.add_body(nose, lambda co: {"head": 1.0})
    return parts, bone_list, face_params(tree)
