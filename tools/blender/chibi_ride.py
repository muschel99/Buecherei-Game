"""Radfahren (seit Etappe 5c): eigene Bewegung "ride" für die Chibi-Figuren.

Eine Kurbelumdrehung (FRAMES Bilder, als Schleife): Die Figur sitzt auf dem Sattel des Chibi-
Hollandrads (tools/blender/build_vehicles.py: bicycle_chibi = Rahmen mit tiefem Sitzrohr, Sattel
und Kurbel als eigene Teile), die Füße stehen auf den Pedalen, die Hände halten die Griffe. Knie und
Ellbogen rechnet eine Zwei-Glieder-IK aus (gegeben: Hüfte/Schulter und Fuß/Hand, gesucht: das Gelenk
dazwischen, das zu einer Seite zeigt).

Je Figur eingestellt (wie bei einem echten Rad): Rahmengröße nach der Beinlänge (ride_scale), die
Sattelhöhe so, dass das Bein am unteren Pedal fast gestreckt ist (ride_seat), und die Neigung des
Oberkörpers so, dass die Arme bequem bis zum Lenker reichen. Godot (ChibiCyclistModel) baut das
Fahrrad mit denselben Werten.

Kurbelwinkel wie im Spiel: bei Bild 0 zeigt die Kurbel auf der Seite x < 0 (rechte Seite der Figur)
nach vorn, danach geht dieses Pedal nach unten (vorwärts treten).

Gerechnet wird in Blender-Achsen der Figur (x = linke Seite, -y = vorn, z = oben); die Drehungen
je Knochen gegenüber der T-Pose in Weltachsen, eingetragen wie in chibi_anim.bake.
"""

import math

import bpy
from mathutils import Matrix, Vector

FRAMES = 30            # Bilder je Kurbelumdrehung (bei 30 fps: eine Umdrehung je Sekunde)
# Chibi-Hollandrad in voller Größe (Godot-Achsen: x, y oben, z vorn; wie build_vehicles.CHIBI_BIKE
# und style_parts.bicycle)
SEAT_Z = -0.22         # Sitzpunkt über der Sattelstütze (z); die Höhe stellt solve_setup ein
SEAT_RANGE = (0.70, 0.97)            # Sitzpunkt: tiefer stößt der Sattel aufs Sitzrohr, höher reicht die Stütze nicht
SADDLE_TOP = (0.0555, -0.02)         # Oberkante des Sattels gegenüber dem Sitzpunkt (y, z)
GRIP = (0.28, 1.08, 0.10)
GRIP_RADIUS = 0.016
CRANK = (0.0, 0.36, 0.02)
CRANK_ARM = 0.13
PEDAL_X = 0.1275
PEDAL_HALF = 0.012     # halbe Dicke des Pedals
# Rahmengröße: so viel kleiner als das echte Hollandrad bei LEG_REF Beinlänge, sonst im Verhältnis
FRAME_SCALE = 0.88
LEG_REF = 0.523
LEG_REACH = 0.93       # Bein am unteren Pedal so weit gestreckt (Anteil von Ober- + Unterschenkel)
ARM_REACH = 0.88       # Schulter bis Griff: Anteil der Armlänge (Ellbogen leicht gebeugt)
HIP_ABOVE = 0.05       # Hüftgelenke über der Sattel-Oberkante (m)
HIP_BACK = 0.0         # Hüftgelenke hinter der Sattelmitte (m)
# Oberkörper nach vorn (Grad, je Knochen in Weltachsen aufaddiert; mal dem Faktor aus solve_setup,
# LEAN_RANGE), Nacken mit halber Neigung, Kopf schaut geradeaus (HEAD_LEAN)
LEAN = {"Hips": 8.0, "Spine": 12.0, "Chest": 16.0, "UpperChest": 19.0}
LEAN_RANGE = (0.25, 2.0)
HEAD_LEAN = 2.0
SWAY = 1.5             # Oberkörper schaukelt beim Treten leicht zur Seite (Grad)
ANKLE_MEAN, ANKLE_SWING = 8.0, 8.0   # Fußspitze nach unten (Grad): Mittel und Ausschlag
# Hand am Griff (wie in echt): gerade Verlängerung des Unterarms, Handrücken nach außen, Handfläche
# innen am Griff; die Finger umschließen ihn unten herum nach innen, der Daumen oben herum nach
# innen; der kleine Finger ist hinten (am nächsten zum Körper).
PALM_DOWN = 0.2        # Handfläche zeigt nach innen und so viel nach unten
PALM_HALF = 0.012
GRIP_ALONG = 0.5       # Griff liegt so weit vom Handgelenk zum Fingeransatz (Anteil)
FINGER_CURL = (55.0, 60.0, 45.0)     # Fingerglieder um den Griff (Grad, zur Handfläche hin)
# Daumen: Richtung je Glied im Handrahmen (Handrichtung, Handfläche, Daumenseite)
THUMB_DIRS = ((0.55, 0.25, 0.4), (0.3, 0.85, 0.1), (0.05, 0.9, -0.4))
ELBOW_POLE = (0.35, 0.2, 1.0)        # Ellbogen zeigt nach (außen, hinten, unten): Arme hängen locker
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


class Setup:
    """Einstellung des Fahrrads für eine Figur: Rahmengröße s, Sitzpunkt seat (Höhe in voller
    Größe), Neigung des Oberkörpers lean (Faktor auf LEAN)."""

    def __init__(self, s, seat, lean):
        self.s, self.seat, self.lean = s, seat, lean


def _hip_target(setup):
    """Mitte der Hüftgelenke auf dem Sattel."""
    top = (0.0, setup.seat + SADDLE_TOP[0], SEAT_Z + SADDLE_TOP[1])
    return g2b(top, setup.s) + Vector((0.0, HIP_BACK, HIP_ABOVE))


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
    pedal, a = _pedal(rig.head[foot].x, phi, s)
    d_foot = rot("X", _ankle_angle(a))
    ball = rig.head[toes]
    ball_ground = Vector((ball.x, ball.y, 0.0))
    return d_foot, pedal + d_foot @ (rig.head[foot] - ball_ground)


def _side_dir(d, sx):
    """Richtung (außen, hinten, unten) → Blender-Achsen für die Seite sx (+1 links, -1 rechts)."""
    return Vector((d[0] * sx, d[1], -d[2])).normalized()


def _torso(setup, phi):
    """Drehungen von Hüfte bis Kopf (Welt): Neigung nach vorn, leichtes Schaukeln."""
    sway = rot("Y", SWAY * math.sin(phi))
    D = {n: rot("X", deg * setup.lean) if n == "Hips" else sway @ rot("X", deg * setup.lean) for n, deg in LEAN.items()}
    D["Neck"] = sway @ rot("X", 0.5 * LEAN["UpperChest"] * setup.lean)
    D["Head"] = sway @ rot("X", HEAD_LEAN)
    return D


def _hips_offset(rig, D, setup):
    hips = rig.head["Hips"]
    mid_rest = (rig.head["LeftUpperLeg"] + rig.head["RightUpperLeg"]) / 2.0
    return _hip_target(setup) - hips - D["Hips"] @ (mid_rest - hips)


def _fk(rig, D, offset):
    """Lage der Knochenköpfe mit den Drehungen D (nicht gesetzte erben vom Eltern)."""
    pos, rotation = {}, {}
    for n in rig.order:
        p = rig.parent[n]
        if p is None:
            pos[n] = rig.head[n] + offset
            rotation[n] = D.get(n, Matrix.Identity(3))
        else:
            pos[n] = pos[p] + rotation[p] @ (rig.head[n] - rig.head[p])
            rotation[n] = D.get(n, rotation[p])
    return pos


def _bisect(f, lo, hi, steps=40):
    """Nullstelle einer steigenden Funktion f zwischen lo und hi (sonst der nächste Rand)."""
    for _ in range(steps):
        mid = (lo + hi) / 2.0
        if f(mid) < 0.0:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2.0


def solve_setup(rig):
    """Rahmengröße nach der Beinlänge, dann abwechselnd Sattelhöhe (Bein am unteren Pedal
    LEG_REACH gestreckt) und Neigung des Oberkörpers (Schulter bis Griff ARM_REACH der Armlänge)."""
    side = "Right"   # Seite x < 0: Pedal unten bei phi = π/2
    s = FRAME_SCALE * rig.leg_length(side) / LEG_REF
    setup = Setup(s, 0.8, 1.0)
    mid_rest = (rig.head["LeftUpperLeg"] + rig.head["RightUpperLeg"]) / 2.0
    leg = LEG_REACH * rig.leg_length(side)
    arm = ARM_REACH * (rig.length(side + "UpperArm", side + "LowerArm") + rig.length(side + "LowerArm", side + "Hand"))
    grip = g2b((-GRIP[0], GRIP[1], GRIP[2]), s)

    def leg_error(seat):
        setup.seat = seat
        hip = _hip_target(setup) + rot("X", LEAN["Hips"] * setup.lean) @ (rig.head[side + "UpperLeg"] - mid_rest)
        return (_foot(rig, side, math.pi / 2.0, s)[1] - hip).length - leg

    def arm_error(lean):
        # weiter vorgebeugt = Schulter näher am Griff
        setup.lean = lean
        D = _torso(setup, 0.0)
        pos = _fk(rig, D, _hips_offset(rig, D, setup))
        return arm - (grip - pos[side + "UpperArm"]).length

    for _ in range(3):
        setup.seat = _bisect(leg_error, *SEAT_RANGE)
        setup.lean = _bisect(arm_error, *LEAN_RANGE)
    return setup


def _palm_normal(h, sx):
    """Handfläche zeigt nach innen (etwas nach unten), senkrecht zur Handrichtung h."""
    p = Vector((-sx, 0.0, -PALM_DOWN))
    return (p - h * p.dot(h)).normalized()


def pose(rig, phi, setup):
    """Drehungen aller Knochen (Welt, gegenüber der T-Pose) und Verschiebung der Hüfte für
    Kurbelwinkel phi."""
    s = setup.s
    D = _torso(setup, phi)
    offset = _hips_offset(rig, D, setup)
    pos = _fk(rig, D, offset)
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
        # Arme: Hand als gerade Verlängerung des Unterarms um den Griff (Handgelenk hängt von der
        # Richtung des Unterarms ab, darum ein paar Mal hin und her)
        upper, lower, hand = side + "UpperArm", side + "LowerArm", side + "Hand"
        l1, l2 = rig.length(upper, lower), rig.length(lower, hand)
        grip = g2b((GRIP[0] * sx, GRIP[1], GRIP[2]), s)
        palm_len = rig.length(hand, side + "MiddleProximal")
        pole = _side_dir(ELBOW_POLE, sx)
        wrist = grip
        for _ in range(8):
            elbow, end, n_new = two_bone(pos[upper], l1, l2, wrist, pole)
            h = (end - elbow).normalized()
            palm = _palm_normal(h, sx)
            wrist = grip - h * (GRIP_ALONG * palm_len) - palm * (GRIP_RADIUS * s + PALM_HALF)
        elbow, end, n_new = two_bone(pos[upper], l1, l2, wrist, pole)
        h = (end - elbow).normalized()
        palm = _palm_normal(h, sx)
        a_rest = rig.head[lower] - rig.head[upper]
        n_rest = a_rest.normalized().cross(Vector((0.0, -1.0, 0.0))).normalized()
        D[upper] = frame(elbow - pos[upper], n_new) @ frame(a_rest, n_rest).inverted()
        # Unterarm dreht sich halb zur Hand hin (so verdreht sich das Handgelenk nicht)
        D[lower] = frame(end - elbow, n_new + palm) @ frame(rig.head[hand] - rig.head[lower], n_rest).inverted()
        rest_dir = rig.head[side + "MiddleProximal"] - rig.head[hand]
        D[hand] = frame(h, palm) @ frame(rest_dir, Vector((0.0, 0.0, -1.0))).inverted()
        # Finger unten herum nach innen um den Griff (zur Handfläche hin gekrümmt)
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
        # Daumen oben herum nach innen: jedes Glied in seine Richtung (Handrahmen) gedreht
        thumb_side = -sx * h.cross(palm)
        for seg, (ch, cp, ct) in zip(("Metacarpal", "Proximal", "Distal"), THUMB_DIRS):
            bone = side + "Thumb" + seg
            if bone not in rig.head:
                continue
            d = D[hand] @ (rig.tail[bone] - rig.head[bone]).normalized()
            target = (h * ch + palm * cp + thumb_side * ct).normalized()
            D[bone] = d.rotation_difference(target).to_matrix() @ D[hand]
    return D, offset


def add_ride(target, name="ride"):
    """Bewegung "ride" am Skelett target anlegen (Aktion + NLA-Spur wie chibi_anim). Liefert die
    Zusatzangaben für Godot (Rahmengröße, Sitzpunkt, Bilder je Umdrehung)."""
    rig = Rig(target)
    setup = solve_setup(rig)
    frames = list(range(1, FRAMES + 2))   # letztes Bild = erstes (Schleife)
    action = bpy.data.actions.new(name)
    rots = {n: [] for n in rig.names}
    locs = []
    for f in frames:
        phi = 2.0 * math.pi * (f - 1) / FRAMES
        D, offset = pose(rig, phi, setup)
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
    print(f"  Animation {name}: {len(frames)} Bilder, Fahrrad {setup.s:.3f}, Sitzpunkt {setup.seat:.3f}, "
          f"Oberkörper {setup.lean:.2f}")
    return {"ride_scale": setup.s, "ride_seat": setup.seat, "ride_frames": FRAMES}


def ride_angle(frame_no):
    """Kurbelwinkel (Bogenmaß) eines Bildes der Bewegung "ride"."""
    return 2.0 * math.pi * (frame_no - 1) / FRAMES
