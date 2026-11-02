"""Bewegungen der Katze (seit Etappe 6h) – nach dem Vorbild echter Katzen.

Beine mit IK (inverse Kinematik): Für jede Pfote gibt es einen Zielknochen („ik_fl_l“ …), Blender rechnet die
Beinwinkel aus. So stehen Pfoten beim Gehen fest auf dem Boden (kein Rutschen) und Bewegungen wie Sitzen oder
Strecken lassen sich über die Lage der Pfoten beschreiben. Rücken, Hals, Kopf, Ohren und Schwanz werden direkt
gedreht. Zum Schluss wird alles in einfache Knochen-Drehungen umgerechnet („gebacken“) – das Spiel braucht keine IK.

Achsen (Blender, Skelett): vorn = -y, oben = z, links = +x. Drehung um x: + kippt nach vorn ein Glied, das nach
vorn zeigt, nach unten (Kopf nickt); ein Glied, das nach hinten zeigt (Schwanz), hebt + nach oben.
"""
import math

import bpy
from mathutils import Quaternion, Vector

import animal_cat as AC

FPS = 30
# Ziel-Knochen der Pfoten: (Name, Bein-Knochen mit IK, Ketten-Länge, Knochen mit gleicher Drehung, Pol-Seite)
LEGS = {
    "fl": ("fl_lower", "fl_paw", +1.0),      # Ellbogen zeigt nach hinten (+y)
    "bl": ("bl_lower", "bl_foot", -1.0),     # Knie zeigt nach vorn (-y)
}


def _quat(steps):
    q = Quaternion()
    for axis, deg in steps:
        v = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}[axis]
        q = Quaternion(v, math.radians(deg)) @ q
    return q


def rest_points():
    """Ruhelage der Pfoten-Ziele (Armatur-Raum): Vorderbein = Handgelenk, Hinterbein = Sprunggelenk."""
    pts = {}
    for side, s in ((1, "l"), (-1, "r")):
        m = (lambda v: v) if side > 0 else AC._mirror
        pts["fl_" + s] = m(AC.FRONT[2])
        pts["bl_" + s] = m(AC.HIND[2])
    return pts


def setup_rig(arm):
    """Ziel- und Polknochen anlegen, IK und Drehungs-Übernahme einstellen."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for leg, (lower, follow, pole_dir) in LEGS.items():
        for s in ("l", "r"):
            src = eb[follow + "_" + s]
            ik = eb.new("ik_%s_%s" % (leg, s))
            ik.head, ik.tail, ik.roll = src.head.copy(), src.tail.copy(), src.roll
            ik.use_deform = False
            knee = eb[lower + "_" + s].head
            pole = eb.new("pole_%s_%s" % (leg, s))
            pole.head = knee + Vector((0, 0.2 * pole_dir, 0))
            pole.tail = pole.head + Vector((0, 0, 0.03))
            pole.use_deform = False
    bpy.ops.object.mode_set(mode="POSE")
    for leg, (lower, follow, pole_dir) in LEGS.items():
        for s in ("l", "r"):
            pb = arm.pose.bones[lower + "_" + s]
            c = pb.constraints.new("IK")
            c.target, c.subtarget = arm, "ik_%s_%s" % (leg, s)
            c.pole_target, c.pole_subtarget = arm, "pole_%s_%s" % (leg, s)
            c.chain_count = 2
            c.pole_angle = _best_pole_angle(arm, pb, c)
            f = arm.pose.bones[follow + "_" + s]
            r = f.constraints.new("COPY_ROTATION")
            r.target, r.subtarget = arm, "ik_%s_%s" % (leg, s)
            r.target_space = r.owner_space = "WORLD"
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    bpy.ops.object.mode_set(mode="OBJECT")


def _best_pole_angle(arm, pb, c):
    """Polwinkel so wählen, dass das Bein in der Ruhehaltung genau so gebeugt bleibt wie modelliert."""
    upper = pb.parent
    rest = upper.bone.tail_local.copy()
    best, best_err = 0.0, 1e9
    for deg in range(-180, 180, 15):
        c.pole_angle = math.radians(deg)
        bpy.context.view_layer.update()
        err = (upper.tail - rest).length
        if err < best_err:
            best, best_err = math.radians(deg), err
    return best


class Pose:
    """Hilfe für eine Haltung: Drehungen (Achse, Grad) je Knochen, Lage der Pfoten-Ziele (Armatur-Raum, absolut),
    Verschiebung des Beckens (hips)."""

    def __init__(self):
        self.rot = {}
        self.pos = {}
        self.loc = {}

    def r(self, bone, *steps):
        self.rot.setdefault(bone, []).extend(steps)
        return self

    def foot(self, name, pos, *steps):
        self.pos[name] = Vector(pos)
        if steps:
            self.rot["ik_" + name] = list(steps)
        return self

    def move(self, bone, offset):
        self.loc[bone] = Vector(offset)
        return self


def apply_pose(arm, pose, frame):
    rest = rest_points()
    for pb in arm.pose.bones:
        name = pb.name
        if name.startswith("pole"):
            continue
        rest_q = pb.bone.matrix_local.to_quaternion()
        steps = pose.rot.get(name, [])
        pb.rotation_quaternion = rest_q.inverted() @ _quat(steps) @ rest_q
        loc = Vector((0, 0, 0))
        if name.startswith("ik_"):
            key = name[3:]
            target = pose.pos.get(key, rest[key])
            loc = rest_q.inverted() @ (target - pb.bone.head_local)
        elif name in pose.loc:
            loc = rest_q.inverted() @ pose.loc[name]
        pb.location = loc
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def make_action(arm, name, length, poses, loop=True):
    """poses = {bild: Pose}; Schleifen enden wie sie beginnen. Liefert die (noch nicht gebackene) Aktion."""
    act = bpy.data.actions.new(name + "_ik")
    arm.animation_data_create()
    arm.animation_data.action = act
    frames = sorted(poses)
    if loop and length not in poses:
        poses = dict(poses)
        poses[length] = poses[frames[0]]
        frames.append(length)
    for f in frames:
        apply_pose(arm, poses[f], f)
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.easing = "AUTO"
    act["length"] = length
    act["loop"] = loop
    arm.animation_data.action = None
    return act


def bake(arm, act, name):
    """IK in einfache Knochen-Drehungen umrechnen; als NLA-Spur „name“ ablegen."""
    from bpy_extras import anim_utils
    length = int(act["length"])
    arm.animation_data.action = act
    baked = anim_utils.bake_action(arm, action=None, frames=range(0, length + 1), only_selected=False, do_pose=True,
                                   do_object=False, do_visual_keying=True, do_constraint_clear=False,
                                   do_parents_clear=False, do_clean=False)
    baked.name = name
    for fc in list(baked.fcurves):
        if '"ik_' in fc.data_path or '"pole_' in fc.data_path:
            baked.fcurves.remove(fc)
            continue
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, baked)
    bpy.data.actions.remove(act)
    return baked


def finish_rig(arm):
    """Nach dem Backen: IK und Hilfsknochen entfernen (das Spiel braucht nur die echten Knochen)."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in list(arm.data.edit_bones):
        if eb.name.startswith("ik_") or eb.name.startswith("pole_"):
            arm.data.edit_bones.remove(eb)
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()


# ---------------------------------------------------------------------------------------------
# Bausteine für Haltungen
# ---------------------------------------------------------------------------------------------

def stand(p=None):
    """Grundhaltung: Stehen, Schwanz entspannt leicht erhoben."""
    p = p or Pose()
    return p


def tail_curve(p, raise_deg, curl, sway=0.0, phase=0.0, bend=None):
    """Schwanz: raise_deg = Ansatz anheben (+ hoch), curl = Biegung der übrigen Glieder (+ weiter hoch, − hängen),
    sway = seitliches Schwingen (Grad), phase = Versatz (Welle läuft den Schwanz entlang)."""
    for i in range(5):
        steps = [("x", raise_deg if i == 0 else curl * (0.6 + 0.2 * i))]
        if sway:
            steps.append(("z", sway * math.sin(phase - i * 0.7) * (0.6 + 0.25 * i)))
        if bend:
            steps.append(("z", bend * (0.5 + 0.3 * i)))
        p.r("tail%d" % (i + 1), *steps)
    return p


def gait_feet(p, t, stride, lift, offsets, duty, rest, lifts_hind=None):
    """Füße eines Gangs zur Zeit t (0..1): Standphase (Anteil duty) gleitet nach hinten, Schwungphase hebt
    vorn wieder auf. offsets = Aufsetz-Zeitpunkt je Fuß."""
    for foot, phi in offsets.items():
        q = (t - phi) % 1.0
        base = rest[foot]
        if q < duty:
            k = q / duty
            y = -stride / 2 + stride * k
            z = 0.0
        else:
            k = (q - duty) / (1.0 - duty)
            s = k * k * (3 - 2 * k)
            y = stride / 2 - stride * s
            z = (lifts_hind if lifts_hind and foot.startswith("bl") else lift) * math.sin(math.pi * k)
        p.foot(foot, base + Vector((0, y, z)))
    return p


# ---------------------------------------------------------------------------------------------
# Die Bewegungen
# ---------------------------------------------------------------------------------------------

def anim_idle():
    poses = {}
    for f in range(0, 91, 6):
        t = f / 90
        b = math.sin(t * math.tau)
        p = Pose().move("hips", (0, 0, 0.0015 * b))
        p.r("chest", ("x", 1.0 * b))
        p.r("head", ("z", 14 * math.sin(t * math.tau) if 0.3 < t < 0.7 else 0.0), ("x", -3))
        tail_curve(p, 32, 6, sway=10, phase=t * math.tau)
        p.r("ear_l", ("y", -14 if 0.45 < t < 0.5 else 0))
        poses[f] = p
    return 90, poses, True


def anim_walk():
    """Weicher, federnder Gang (Lateralfolge: links hinten, links vorn, rechts hinten, rechts vorn); Becken und
    Schultern schwingen sanft, der Kopf bleibt ruhig, der Schwanz ist erhoben und schwingt mit."""
    rest = rest_points()
    n = 30
    poses = {}
    offsets = {"bl_l": 0.0, "fl_l": 0.25, "bl_r": 0.5, "fl_r": 0.75}
    for f in range(n):
        t = f / n
        p = Pose()
        gait_feet(p, t, 0.21, 0.03, offsets, 0.62, rest)
        w = math.sin(t * math.tau * 2)
        p.move("hips", (0, 0, 0.004 * w))
        p.r("hips", ("z", 5 * math.sin(t * math.tau)), ("y", 3 * math.sin(t * math.tau)))
        p.r("chest", ("z", -5 * math.sin(t * math.tau + 0.8)), ("y", -3 * math.sin(t * math.tau + 0.8)))
        # Kopf ruhig: Drehungen von Becken und Brust ausgleichen
        p.r("neck", ("x", -4))
        p.r("head", ("z", -0.6 * 5 * math.sin(t * math.tau)), ("x", 4))
        tail_curve(p, 42, 10, sway=8, phase=t * math.tau)
        poses[f] = p
    return n, poses, True


def anim_run():
    """Galopp: Hinterbeine und Vorderbeine je paarweise, Rücken beugt und streckt sich."""
    rest = rest_points()
    n = 16
    poses = {}
    offsets = {"bl_l": 0.0, "bl_r": 0.06, "fl_l": 0.45, "fl_r": 0.51}
    for f in range(n):
        t = f / n
        p = Pose()
        gait_feet(p, t, 0.34, 0.06, offsets, 0.38, rest)
        flex = math.sin(t * math.tau)
        p.r("hips", ("x", -8 * flex))
        p.r("spine1", ("x", 6 * flex))
        p.r("chest", ("x", 6 * flex))
        p.move("hips", (0, 0, 0.012 * max(0.0, math.sin(t * math.tau * 2))))
        p.r("head", ("x", -6 * flex))
        tail_curve(p, 12, -4, sway=6, phase=t * math.tau)
        poses[f] = p
    return n, poses, True


def _sit_pose(p=None, breathe=0.0, tail_phase=0.0):
    """Sitzen: Becken am Boden, Hinterbeine gefaltet (Mittelfuß flach), Vorderbeine gerade, Brust aufrecht,
    Schwanz um die Pfoten gelegt."""
    rest = rest_points()
    p = p or Pose()
    p.move("hips", (0, 0.03, -0.112))
    p.r("hips", ("x", -42))
    p.r("spine1", ("x", -6))
    p.r("chest", ("x", 4 + breathe))
    p.r("neck", ("x", 14))
    p.r("head", ("x", 30))
    for s, side in (("l", 1), ("r", -1)):
        h = rest["bl_" + s]
        p.foot("bl_" + s, h + Vector((0, 0.03, -0.028)), ("x", -62))
        fr = rest["fl_" + s]
        p.foot("fl_" + s, fr + Vector((0, -0.01, 0)))
    # Schwanz liegt am Boden und legt sich seitlich nach vorn um die Pfoten
    tail_curve(p, -34, 4, bend=-44, sway=3, phase=tail_phase)
    return p


def anim_sit_down():
    """Hinsetzen: erst hinten absetzen (Becken sinkt, Hinterbeine falten), Vorderbeine bleiben stehen."""
    rest = rest_points()
    poses = {0: stand(tail_curve(Pose(), 30, 6))}
    mid = Pose().move("hips", (0, 0.015, -0.06)).r("hips", ("x", -20)).r("neck", ("x", 6)).r("head", ("x", 14))
    for s in ("l", "r"):
        mid.foot("bl_" + s, rest["bl_" + s] + Vector((0, 0.02, -0.012)), ("x", -30))
    tail_curve(mid, 10, 0)
    poses[12] = mid
    poses[26] = _sit_pose()
    return 26, poses, False


def anim_stand_up():
    n, poses, _ = anim_sit_down()
    rev = {n - f: p for f, p in poses.items()}
    return n, rev, False


def anim_sit():
    poses = {}
    for f in range(0, 91, 10):
        t = f / 90
        p = _sit_pose(breathe=1.2 * math.sin(t * math.tau), tail_phase=t * math.tau)
        if 0.55 < t < 0.75:
            p.r("ear_r", ("y", 16))
        poses[f] = p
    return 90, poses, True


def anim_groom():
    """Putzen im Sitzen: Pfote zum Mund, lecken (Kopf nickt), dann übers Gesicht wischen."""
    rest = rest_points()
    poses = {}
    keys = [(0, 0.0, 0.0), (8, 1.0, 0.0), (16, 1.0, 1.0), (24, 1.0, 0.0), (32, 1.0, 1.0), (44, 0.4, 2.0), (52, 1.0, 0.0),
            (60, 0.0, 0.0)]
    for f, up, lick in keys:
        p = _sit_pose()
        # Pfote vor den Mund (Kopf neigt sich leicht hin), lecken = kleines Nicken
        paw = rest["fl_l"].lerp(Vector((0.012, -0.175, 0.215)), up)
        if lick >= 2.0:
            paw = Vector((0.03, -0.17, 0.255))      # übers Gesicht wischen
        p.foot("fl_l", paw, ("x", -95 * up))
        p.r("head", ("x", 30 + 10 * up + 7 * min(lick, 1.0)), ("z", 12 * up), ("y", -14 * up if lick >= 2.0 else 0.0))
        p.r("neck", ("x", 14 + 4 * up))
        poses[f] = p
    return 60, poses, True


def anim_pet():
    """Gestreichelt werden: Kopf reibt sich an der Hand (neigen, hochstrecken), Schwanz steil."""
    poses = {}
    for f in range(0, 61, 6):
        t = f / 60
        p = Pose()
        p.r("neck", ("x", -8 - 6 * math.sin(t * math.tau)))
        p.r("head", ("x", -12), ("y", 16 * math.sin(t * math.tau)), ("z", 8 * math.sin(t * math.tau)))
        p.r("chest", ("y", -4 * math.sin(t * math.tau)))
        tail_curve(p, 60, 12, sway=3, phase=t * math.tau * 2)
        p.r("ear_l", ("y", -10))
        p.r("ear_r", ("y", 10))
        poses[f] = p
    return 60, poses, True


def _lie_pose(p=None, breathe=0.0):
    """Liegen (wie ein Brotlaib): Bauch am Boden, Vorderpfoten untergeschlagen, Hinterbeine gefaltet."""
    rest = rest_points()
    p = p or Pose()
    p.move("hips", (0, 0.0, -0.12))
    p.r("hips", ("x", -4))
    p.r("chest", ("x", 6 + breathe))
    p.r("neck", ("x", 14))
    p.r("head", ("x", 14))
    for s in ("l", "r"):
        p.foot("fl_" + s, rest["fl_" + s] + Vector((0, 0.06, 0.035)), ("x", 80))
        p.foot("bl_" + s, rest["bl_" + s] + Vector((0, -0.02, -0.025)), ("x", -70))
    tail_curve(p, -16, 0, bend=-30)
    return p


def anim_lie():
    poses = {}
    for f in range(0, 91, 15):
        t = f / 90
        poses[f] = _lie_pose(breathe=1.2 * math.sin(t * math.tau))
    return 90, poses, True


def anim_sleep():
    """Eingerollt schlafen: Rücken zur Seite gebogen (C-Form), Kopf zum Schwanz, Schwanz um den Körper."""
    rest = rest_points()
    poses = {}
    for f in range(0, 121, 20):
        t = f / 120
        b = 1.0 * math.sin(t * math.tau)
        p = _lie_pose(breathe=b)
        # stark eingerollt: Rücken als Bogen, Kopf liegt am Schwanz, leicht auf der Seite
        # Rücken biegt sich nach links (+z dreht ein nach vorn zeigendes Glied nach links), der Schwanz ebenfalls
        # nach links (für nach hinten zeigende Glieder: −z) – Kopf und Schwanz treffen sich vorn
        p.move("hips", (0.0, 0.0, -0.13))
        p.r("hips", ("y", 8), ("z", 38))
        p.r("spine1", ("z", 46))
        p.r("chest", ("z", 46), ("x", 4 + b))
        p.r("neck", ("z", 36), ("x", 22))
        p.r("head", ("z", 26), ("x", 26), ("y", 18))
        p.foot("fl_l", rest["fl_l"] + Vector((-0.03, 0.05, 0.03)), ("x", 85))
        p.foot("fl_r", rest["fl_r"] + Vector((-0.02, 0.07, 0.03)), ("x", 85))
        p.foot("bl_l", rest["bl_l"] + Vector((-0.01, -0.03, -0.02)), ("x", -75))
        p.foot("bl_r", rest["bl_r"] + Vector((0.03, -0.04, -0.015)), ("x", -75))
        tail_curve(p, -22, 0, bend=-60)
        p.r("ear_l", ("y", -18))
        p.r("ear_r", ("y", 18))
        poses[f] = p
    return 120, poses, True


def anim_stretch():
    """Strecken: erst vorn lang machen (Pfoten weit vor, Brust tief, Becken hoch), dann Buckel (Rücken rund nach
    oben, Kopf hinunter), zurück in den Stand."""
    rest = rest_points()
    poses = {0: Pose()}
    fwd = Pose().move("hips", (0, 0.01, 0.0)).r("hips", ("x", 16)).r("spine1", ("x", 8)).r("chest", ("x", 8))
    fwd.r("neck", ("x", -24)).r("head", ("x", -20))
    for s in ("l", "r"):
        fwd.foot("fl_" + s, rest["fl_" + s] + Vector((0, -0.11, 0.0)), ("x", -10))
    tail_curve(fwd, 56, 14)
    poses[18] = fwd
    poses[30] = fwd
    arch = Pose().move("hips", (0, 0, 0.012)).r("hips", ("x", -18)).r("spine1", ("x", 10)).r("chest", ("x", 18))
    arch.r("neck", ("x", 16)).r("head", ("x", 18))
    tail_curve(arch, -10, -8)
    poses[48] = arch
    poses[58] = arch
    poses[75] = Pose()
    return 75, poses, False


def _crouch_pose(p=None, low=1.0):
    p = p or Pose()
    p.move("hips", (0, 0.0, -0.06 * low))
    p.r("chest", ("x", 6 * low))
    p.r("neck", ("x", -12 * low))
    p.r("head", ("x", -6 * low))
    tail_curve(p, -6, -4)
    return p


def anim_crouch():
    """Lauern: tief geduckt, Kopf vorn, Schwanzspitze zuckt."""
    poses = {}
    for f in range(0, 31, 5):
        t = f / 30
        p = _crouch_pose()
        p.r("tail5", ("z", 18 * math.sin(t * math.tau * 2)))
        poses[f] = p
    return 30, poses, True


def anim_stalk():
    """Anschleichen: langsamer, geduckter Gang, Kopf ruhig und tief."""
    rest = rest_points()
    n = 42
    poses = {}
    offsets = {"bl_l": 0.0, "fl_l": 0.25, "bl_r": 0.5, "fl_r": 0.75}
    for f in range(n):
        t = f / n
        p = _crouch_pose()
        gait_feet(p, t, 0.16, 0.02, offsets, 0.7, rest)
        p.r("hips", ("z", 3 * math.sin(t * math.tau)))
        p.r("head", ("z", -2 * math.sin(t * math.tau)))
        poses[f] = p
    return n, poses, True


def anim_pounce():
    """Sprung auf Beute/Spielzeug: geduckt mit dem Hinterteil wackeln, nach vorn springen, mit den Vorderpfoten
    zuerst aufkommen und zupacken. Das Spiel bewegt die Katze dabei vorwärts (zwischen 0,35 und 0,7)."""
    rest = rest_points()
    poses = {}
    for f, wig in ((0, 0), (3, 1), (6, -1), (9, 1), (12, 0)):
        p = _crouch_pose()
        p.r("hips", ("z", 7 * wig))
        poses[f] = p
    jump = Pose().r("hips", ("x", -10)).r("chest", ("x", -12)).r("neck", ("x", -10))
    for s in ("l", "r"):
        jump.foot("fl_" + s, rest["fl_" + s] + Vector((0, -0.08, 0.06)), ("x", -40))
        jump.foot("bl_" + s, rest["bl_" + s] + Vector((0, 0.07, 0.02)), ("x", 30))
    tail_curve(jump, 6, -2)
    poses[17] = jump
    land = _crouch_pose(low=0.8)
    for s in ("l", "r"):
        land.foot("fl_" + s, rest["fl_" + s] + Vector((0, -0.06, 0)), ("x", -15))
    poses[22] = land
    poses[30] = _crouch_pose(low=0.5)
    return 30, poses, False


def anim_jump_up():
    """Hochspringen (auf Bank, Fensterbank, Sessel): ansetzen (ducken, Blick nach oben), abspringen, Vorderpfoten
    vorn oben, weich landen. Das Spiel hebt die Katze zwischen 0,35 und 0,68 der Bewegung auf die neue Höhe."""
    rest = rest_points()
    crouch = _crouch_pose(low=0.9).r("neck", ("x", -24)).r("head", ("x", -10))
    up = Pose().r("hips", ("x", -26)).r("spine1", ("x", -8)).r("chest", ("x", -10)).r("neck", ("x", -10))
    for s in ("l", "r"):
        up.foot("fl_" + s, rest["fl_" + s] + Vector((0, -0.05, 0.1)), ("x", -50))
        up.foot("bl_" + s, rest["bl_" + s] + Vector((0, 0.06, -0.01)), ("x", 25))
    tail_curve(up, 10, -6)
    tuck = Pose().r("hips", ("x", -6))
    for s in ("l", "r"):
        tuck.foot("fl_" + s, rest["fl_" + s] + Vector((0, -0.03, 0.03)), ("x", -20))
        tuck.foot("bl_" + s, rest["bl_" + s] + Vector((0, 0.02, 0.05)), ("x", -20))
    land = _crouch_pose(low=0.6)
    poses = {0: Pose(), 6: crouch, 10: crouch, 13: up, 17: tuck, 21: land, 28: Pose()}
    return 28, poses, False


def anim_jump_down():
    """Herunterspringen: an der Kante vorbeugen, Kopf voran abspringen, mit den Vorderpfoten zuerst weich landen.
    Das Spiel senkt die Katze zwischen 0,3 und 0,65 der Bewegung auf den Boden."""
    rest = rest_points()
    lean = Pose().r("hips", ("x", 10)).r("chest", ("x", 14)).r("neck", ("x", 14)).r("head", ("x", 8))
    for s in ("l", "r"):
        lean.foot("fl_" + s, rest["fl_" + s] + Vector((0, -0.04, -0.02)), ("x", 10))
    tail_curve(lean, 30, 8)
    reach = Pose().r("hips", ("x", 18)).r("chest", ("x", 10)).r("neck", ("x", 6))
    for s in ("l", "r"):
        reach.foot("fl_" + s, rest["fl_" + s] + Vector((0, -0.07, -0.05)), ("x", 25))
        reach.foot("bl_" + s, rest["bl_" + s] + Vector((0, 0.05, 0.04)), ("x", 30))
    tail_curve(reach, 46, 10)
    land = Pose().move("hips", (0, 0, 0.0)).r("hips", ("x", 14)).r("chest", ("x", 10))
    for s in ("l", "r"):
        land.foot("fl_" + s, rest["fl_" + s] + Vector((0, -0.02, 0)), ("x", 5))
        land.foot("bl_" + s, rest["bl_" + s] + Vector((0, 0.03, 0.03)), ("x", 10))
    soft = _crouch_pose(low=0.5)
    poses = {0: Pose(), 5: lean, 9: lean, 13: reach, 18: land, 22: soft, 28: Pose()}
    return 28, poses, False


def anim_hop_up():
    """Eine Stufe hinauf: kurz ducken, hüpfen, Vorderpfoten zuerst oben."""
    n, poses, loop = anim_jump_up()
    return 15, {0: poses[0], 3: poses[6], 6: poses[13], 9: poses[17], 12: poses[21], 15: poses[28]}, False


def anim_step_down():
    """Eine Stufe hinunter: Vorderpfoten tasten nach unten, Körper folgt, Hinterbeine steigen nach."""
    rest = rest_points()
    a = Pose().r("hips", ("x", 6)).r("chest", ("x", 8)).r("neck", ("x", 10))
    for s in ("l", "r"):
        a.foot("fl_" + s, rest["fl_" + s] + Vector((0, -0.05, -0.06)), ("x", 12))
    b = Pose().r("hips", ("x", 12))
    for s in ("l", "r"):
        b.foot("bl_" + s, rest["bl_" + s] + Vector((0, 0.0, 0.05)), ("x", 10))
    return 16, {0: Pose(), 5: a, 10: b, 16: Pose()}, False


def anim_sniff():
    """Schnuppern: Kopf tief zum Boden, Nase zuckt, Ohren nach vorn."""
    poses = {}
    for f in range(0, 61, 6):
        t = f / 60
        p = Pose().r("neck", ("x", 30)).r("head", ("x", 30 + 4 * math.sin(t * math.tau * 4))).r("chest", ("x", 6))
        p.r("head", ("z", 8 * math.sin(t * math.tau)))
        tail_curve(p, 28, 6, sway=6, phase=t * math.tau)
        poses[f] = p
    return 60, poses, True


def anim_bat():
    """Mit der Pfote anstupsen (im Stehen, leicht geduckt): Pfote hebt sich, schlägt vor und tippt."""
    rest = rest_points()
    poses = {}
    for f, k in ((0, 0.0), (6, 1.0), (10, 0.3), (14, 0.0), (20, 0.0)):
        p = _crouch_pose(low=0.5)
        p.foot("fl_r", rest["fl_r"] + Vector((0, -0.07 * k - 0.02 * (k > 0.5), 0.06 * k)), ("x", -40 * k))
        p.r("head", ("x", 10), ("z", -6))
        poses[f] = p
    return 20, poses, True


ANIMS = [("idle", anim_idle), ("walk", anim_walk), ("run", anim_run), ("sit_down", anim_sit_down),
         ("stand_up", anim_stand_up), ("sit", anim_sit), ("groom", anim_groom), ("pet", anim_pet), ("lie", anim_lie),
         ("sleep", anim_sleep), ("stretch", anim_stretch), ("crouch", anim_crouch), ("stalk", anim_stalk),
         ("pounce", anim_pounce), ("jump_up", anim_jump_up), ("jump_down", anim_jump_down), ("hop_up", anim_hop_up),
         ("step_down", anim_step_down), ("sniff", anim_sniff), ("bat", anim_bat)]


def build_all(arm, only=None):
    setup_rig(arm)
    for name, fn in ANIMS:
        if only and name not in only:
            continue
        length, poses, loop = fn()
        act = make_action(arm, name, length, poses, loop)
        bake(arm, act, name)
    finish_rig(arm)
