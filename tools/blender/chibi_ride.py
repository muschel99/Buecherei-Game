"""Radfahren (seit Etappe 5c): eigene Bewegung "ride" für die Chibi-Figuren.

Eine Kurbelumdrehung (FRAMES Bilder, als Schleife): Die Figur sitzt auf dem Sattel des Hollandrads
(tools/blender/style_parts.bicycle), die Füße stehen auf den Pedalen, die Hände halten die Griffe.
Knie und Ellbogen rechnet eine Zwei-Glieder-IK aus (gegeben: Hüfte/Schulter und Fuß/Hand, gesucht:
das Gelenk dazwischen, das zu einer Seite zeigt). Das Fahrrad ist für jede Figur so verkleinert,
dass das Bein am unteren Pedal fast gestreckt ist (ride_scale, Godot skaliert das Fahrrad genauso).

Kurbelwinkel wie im Spiel (ChibiCyclistModel): bei Bild 0 zeigt die Kurbel auf der Seite x < 0
(rechte Seite der Figur) nach vorn, danach geht dieses Pedal nach unten (vorwärts treten).

Gerechnet wird in Blender-Achsen der Figur (x = linke Seite, -y = vorn, z = oben); die Drehungen
je Knochen gegenüber der T-Pose in Weltachsen, eingetragen wie in chibi_anim.bake.
"""

import math

import bpy
from mathutils import Matrix, Vector

FRAMES = 30            # Bilder je Kurbelumdrehung (bei 30 fps: eine Umdrehung je Sekunde)
# Hollandrad in echter Größe (Godot-Achsen: x, y oben, z vorn; Werte aus style_parts.bicycle)
SADDLE_TOP = (0.0, 0.976, -0.24)
GRIP = (0.28, 1.08, 0.10)
GRIP_RADIUS = 0.016
CRANK = (0.0, 0.36, 0.02)
CRANK_ARM = 0.17
PEDAL_X = 0.1275
PEDAL_HALF = 0.012     # halbe Dicke des Pedals
LEG_REACH = 0.93       # Bein am unteren Pedal so weit gestreckt (Anteil von Ober- + Unterschenkel)
HIP_ABOVE = 0.05       # Hüftgelenke über der Sattel-Oberkante (m)
HIP_BACK = 0.0         # Hüftgelenke hinter der Sattelmitte (m)
# Oberkörper nach vorn (Grad, je Knochen in Weltachsen aufaddiert), Kopf schaut wieder geradeaus
LEAN = {"Hips": 8.0, "Spine": 12.0, "Chest": 16.0, "UpperChest": 19.0, "Neck": 10.0, "Head": 2.0}
SWAY = 1.5             # Oberkörper schaukelt beim Treten leicht zur Seite (Grad)
ANKLE_MEAN, ANKLE_SWING = 8.0, 8.0   # Fußspitze nach unten (Grad): Mittel und Ausschlag
# Hand am Griff (wie in echt): Handfläche liegt oben innen auf, die Finger legen sich außen um den
# Griff, der Daumen umfasst ihn von innen. Richtung Handgelenk → Fingeransatz: nach außen und vorn
# (der Griff läuft schräg durch die Hand), Handfläche nach unten außen.
HAND_DIR = (0.6, 0.65, 0.3)          # (außen, vorn, unten)
PALM_DIR = (0.35, 0.0, 1.0)          # Handflächen-Normale (außen, vorn, unten)
PALM_HALF = 0.012
FINGER_CURL = (55.0, 60.0, 45.0)     # Fingerglieder um den Griff (Grad)
# Daumen: Richtung je Glied (außen, vorn, unten) – innen am Griff entlang nach vorn und etwas
# hinunter (zum Umgreifen ist der Chibi-Daumen zu dick für den dünnen Griff)
THUMB_DIRS = ((-0.1, 0.7, 0.7), (0.1, 0.75, 0.65), (0.35, 0.7, 0.6))
ELBOW_POLE = (1.0, 0.6, -0.4)        # Ellbogen zeigt nach (außen, hinten, unten)
KNEE_POLE = (0.15, -1.0, 0.1)        # Knie zeigt nach (außen, vorn, oben)

FINGERS = ("Thumb", "Index", "Middle", "Ring", "Little")


def g2b(p, s=1.0):
    """Godot-Achsen (x, y oben, z vorn) → Blender-Achsen der Figur (x, -y vorn, z oben), mal s."""
    return Vector((p[0] * s, -p[2] * s, p[1] * s))


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 3, axis)


def frame(direction, hinge):
    """Drehung (Spalten): Richtung, Gelenkachse senkrecht dazu, und die dritte Achse."""
    a = direction.normalized()
    n = (hinge - a * hinge.dot(a)).normalized()
    return Matrix((a, n, a.cross(n))).transposed()


def two_bone(root, l1, l2, target, pole):
    """Zwei-Glieder-IK: Gelenk und Endpunkt (Ziel, höchstens fast gestreckt erreichbar); das Gelenk
    liegt auf der Seite von pole."""
    d = target - root
    dist = min(d.length, (l1 + l2) * 0.999)
    u = d.normalized()
    v = (pole - u * pole.dot(u)).normalized()
    x = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    h = math.sqrt(max(l1 * l1 - x * x, 0.0))
    return root + u * x + v * h, root + u * dist, v.cross(u).normalized()


class Rig:
    """Ruhelage des Skeletts (Köpfe der Knochen, Ruhe-Drehungen, Eltern)."""

    def __init__(self, arm):
        self.arm = arm
        bones = arm.data.bones
        self.names = [b.name for b in bones]
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.head = {b.name: Vector(b.head_local) for b in bones}
        self.tail = {b.name: Vector(b.tail_local) for b in bones}
        self.rest = {b.name: b.matrix_local.to_3x3().normalized() for b in bones}
        # Reihenfolge: Eltern vor Kindern
        order, seen = [], set()

        def visit(n):
            if n in seen:
                return
            if self.parent[n]:
                visit(self.parent[n])
            seen.add(n)
            order.append(n)
        for n in self.names:
            visit(n)
        self.order = order

    def length(self, a, b):
        return (self.head[b] - self.head[a]).length

    def leg_length(self, side):
        return self.length(side + "UpperLeg", side + "LowerLeg") + self.length(side + "LowerLeg", side + "Foot")


def _hip_target(rig, s):
    """Mitte der Hüftgelenke auf dem Sattel."""
    return g2b(SADDLE_TOP, s) + Vector((0.0, HIP_BACK, HIP_ABOVE))


def _pedal(side_x, phi, s):
    """Oberkante des Pedals (Blender-Achsen) bei Kurbelwinkel phi; side_x < 0 = Kurbel, die bei 0
    nach vorn zeigt."""
    a = phi if side_x < 0 else phi + math.pi
    p = (math.copysign(PEDAL_X, side_x), CRANK[1] - math.sin(a) * CRANK_ARM, CRANK[2] + math.cos(a) * CRANK_ARM)
    return g2b(p, s) + Vector((0.0, 0.0, PEDAL_HALF * s)), a


def _ankle_angle(a):
    """Fußspitze nach unten (Grad) je Stellung des eigenen Pedals (a = 0 vorn, π/2 unten)."""
    return ANKLE_MEAN + ANKLE_SWING * math.cos(a - 0.75 * math.pi)


def _foot(rig, side, phi, s):
    """Fuß-Drehung (Welt) und Ziel des Knöchels: Ballen auf dem Pedal."""
    foot, toes = side + "Foot", side + "Toes"
    x = rig.head[foot].x
    pedal, a = _pedal(x, phi, s)
    d_foot = rot("X", _ankle_angle(a))
    ball = rig.head[toes]
    ball_ground = Vector((ball.x, ball.y, 0.0))
    return d_foot, pedal + d_foot @ (rig.head[foot] - ball_ground)


def _hand_axes(sx):
    """Richtung der Hand (Handgelenk → Finger) und Handflächen-Normale am Griff; sx = Seite (+1 links)."""
    h_dir = _side_dir(HAND_DIR, sx)
    palm = _side_dir(PALM_DIR, sx)
    return h_dir, (palm - h_dir * palm.dot(h_dir)).normalized()


def _side_dir(d, sx):
    """Richtung (außen, vorn, unten) → Blender-Achsen für die Seite sx (+1 links, -1 rechts)."""
    return Vector((d[0] * sx, -d[1], -d[2])).normalized()


def solve_scale(rig):
    """Fahrrad-Größe: am unteren Pedal ist das Bein LEG_REACH gestreckt (Halbierungsverfahren)."""
    side = "Right"   # Seite x < 0: Pedal unten bei phi = π/2
    reach = LEG_REACH * rig.leg_length(side)
    mid_rest = (rig.head["LeftUpperLeg"] + rig.head["RightUpperLeg"]) / 2.0
    lo, hi = 0.3, 1.2
    for _ in range(40):
        s = (lo + hi) / 2.0
        hip = _hip_target(rig, s) + rot("X", LEAN["Hips"]) @ (rig.head[side + "UpperLeg"] - mid_rest)
        _, ankle = _foot(rig, side, math.pi / 2.0, s)
        # Bein noch zu stark gebeugt → größeres Fahrrad
        if (ankle - hip).length < reach:
            lo = s
        else:
            hi = s
    return (lo + hi) / 2.0


def pose(rig, phi, s):
    """Drehungen aller Knochen (Welt, gegenüber der T-Pose) und Verschiebung der Hüfte für
    Kurbelwinkel phi."""
    D = {}
    sway = rot("Y", SWAY * math.sin(phi))
    for name, deg in LEAN.items():
        D[name] = rot("X", deg) if name == "Hips" else sway @ rot("X", deg)
    # Hüfte: Gelenke auf den Sattel
    hips = rig.head["Hips"]
    mid_rest = (rig.head["LeftUpperLeg"] + rig.head["RightUpperLeg"]) / 2.0
    offset = _hip_target(rig, s) - hips - D["Hips"] @ (mid_rest - hips)

    def world_heads():
        """Lage der Knochenköpfe mit den bisherigen Drehungen (nicht gesetzte erben vom Eltern)."""
        pos, rotation = {}, {}
        for n in rig.order:
            p = rig.parent[n]
            if p is None:
                pos[n] = rig.head[n] + offset
                rotation[n] = D.get(n, Matrix.Identity(3))
            else:
                pos[n] = pos[p] + rotation[p] @ (rig.head[n] - rig.head[p])
                rotation[n] = D.get(n, rotation[p])
        return pos, rotation

    pos, _ = world_heads()
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        # Beine: Knöchel auf das Pedal, Knie nach vorn
        up, low, foot = side + "UpperLeg", side + "LowerLeg", side + "Foot"
        d_foot, ankle = _foot(rig, side, phi, s)
        knee, end, n_new = two_bone(pos[up], rig.length(up, low), rig.length(low, foot), ankle,
                                    Vector((KNEE_POLE[0] * sx, KNEE_POLE[1], KNEE_POLE[2])))
        a_rest = rig.head[low] - rig.head[up]
        n_rest = a_rest.normalized().cross(Vector((0.0, 1.0, 0.0))).normalized()
        D[up] = frame(knee - pos[up], n_new) @ frame(a_rest, n_rest).inverted()
        D[low] = frame(end - knee, n_new) @ frame(rig.head[foot] - rig.head[low], n_rest).inverted()
        D[foot] = d_foot
        # Hand am Griff: Richtung (Handgelenk → Finger) und Handfläche nach unten
        hand = side + "Hand"
        h_dir, palm = _hand_axes(sx)
        rest_dir = rig.head[side + "MiddleProximal"] - rig.head[hand]
        D[hand] = frame(h_dir, palm) @ frame(rest_dir, Vector((0.0, 0.0, -1.0))).inverted()
        # Finger außen um den Griff (zur Handfläche hin gekrümmt)
        for finger in FINGERS[1:]:
            total = 0.0
            for seg, deg in zip(("Proximal", "Intermediate", "Distal"), FINGER_CURL):
                bone = side + finger + seg
                if bone not in rig.head:
                    continue
                d = (rig.tail[bone] - rig.head[bone]).normalized()
                axis = d.cross(Vector((0.0, 0.0, -1.0)))
                total += deg
                D[bone] = D[hand] @ (Matrix.Rotation(math.radians(total), 3, axis.normalized())
                                     if axis.length > 1e-6 else Matrix.Identity(3))
        # Daumen innen um den Griff: jedes Glied in seine Richtung gedreht
        for seg, t in zip(("Metacarpal", "Proximal", "Distal"), THUMB_DIRS):
            bone = side + "Thumb" + seg
            if bone not in rig.head:
                continue
            d = D[hand] @ (rig.tail[bone] - rig.head[bone]).normalized()
            D[bone] = d.rotation_difference(_side_dir(t, sx)).to_matrix() @ D[hand]
    pos, _ = world_heads()
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        # Arme: Handgelenk hinter und über den Griff (Handfläche liegt oben auf), Ellbogen nach außen
        upper, lower, hand = side + "UpperArm", side + "LowerArm", side + "Hand"
        h_dir, palm = _hand_axes(sx)
        grip = g2b((GRIP[0] * sx, GRIP[1], GRIP[2]), s)
        palm_len = rig.length(hand, side + "MiddleProximal")
        wrist = grip - h_dir * (0.55 * palm_len) - palm * (GRIP_RADIUS * s + PALM_HALF)
        elbow, end, n_new = two_bone(pos[upper], rig.length(upper, lower), rig.length(lower, hand), wrist,
                                     Vector((ELBOW_POLE[0] * sx, ELBOW_POLE[1], ELBOW_POLE[2])))
        a_rest = rig.head[lower] - rig.head[upper]
        n_rest = a_rest.normalized().cross(Vector((0.0, -1.0, 0.0))).normalized()
        D[upper] = frame(elbow - pos[upper], n_new) @ frame(a_rest, n_rest).inverted()
        D[lower] = frame(end - elbow, n_new) @ frame(rig.head[hand] - rig.head[lower], n_rest).inverted()
    return D, offset


def add_ride(target, name="ride"):
    """Bewegung "ride" am Skelett target anlegen (Aktion + NLA-Spur wie chibi_anim). Liefert die
    Zusatzangaben für Godot (Fahrrad-Größe, Bilder je Umdrehung)."""
    rig = Rig(target)
    s = solve_scale(rig)
    frames = list(range(1, FRAMES + 2))   # letztes Bild = erstes (Schleife)
    action = bpy.data.actions.new(name)
    rots = {n: [] for n in rig.names}
    locs = []
    for f in frames:
        phi = 2.0 * math.pi * (f - 1) / FRAMES
        D, offset = pose(rig, phi, s)
        full = {}
        for n in rig.order:
            p = rig.parent[n]
            full[n] = D.get(n, full[p] if p else Matrix.Identity(3))
        for n in rig.order:
            p = rig.parent[n]
            d = full[n] if p is None else full[p].inverted() @ full[n]
            r = rig.rest[n]
            q = (r.inverted() @ d @ r).to_quaternion()
            if rots[n] and rots[n][-1].dot(q) < 0:
                q.negate()
            rots[n].append(q)
        locs.append(rig.rest["Hips"].inverted() @ offset)
    for n, qs in rots.items():
        path = f'pose.bones["{n}"].rotation_quaternion'
        for i in range(4):
            fc = action.fcurves.new(path, index=i, action_group=n)
            fc.keyframe_points.add(len(frames))
            for k, (f, q) in enumerate(zip(frames, qs)):
                fc.keyframe_points[k].co = (f, q[i])
                fc.keyframe_points[k].interpolation = "LINEAR"
    for i in range(3):
        fc = action.fcurves.new('pose.bones["Hips"].location', index=i, action_group="Hips")
        fc.keyframe_points.add(len(frames))
        for k, (f, v) in enumerate(zip(frames, locs)):
            fc.keyframe_points[k].co = (f, v[i])
            fc.keyframe_points[k].interpolation = "LINEAR"
    target.animation_data_create()
    track = target.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, frames[0], action)
    strip.name = name
    track.mute = True
    action.use_fake_user = True
    print(f"  Animation {name}: {len(frames)} Bilder, Fahrrad {s:.3f}")
    return {"ride_scale": s, "ride_frames": FRAMES}


def ride_angle(frame_no):
    """Kurbelwinkel (Bogenmaß) eines Bildes der Bewegung "ride"."""
    return 2.0 * math.pi * (frame_no - 1) / FRAMES
