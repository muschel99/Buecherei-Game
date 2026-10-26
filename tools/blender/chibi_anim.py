"""Bewegungen für die Chibi-Figuren (seit Etappe 5c): Mixamo-Animationen auf jede Figur übertragen.

Die Animationen kommen von einer Figur (female_medium mit unserem Skelett, bei Mixamo hochgeladen)
aus assets/models/characters/animations/<name>.fbx. Übertragen wird je Knochen die Drehung
gegenüber der T-Pose in Weltachsen (so stören verschiedene Knochenrollen nicht); die Hüfte bewegt
sich zusätzlich hoch/runter, im Verhältnis der Hüfthöhen kleiner oder größer. Seitliches Wandern
der Hüfte entfällt bei den Sitz-Übergängen (das Spiel bewegt die Figur selbst zur Bank).

Gebaut werden Blender-Aktionen am Skelett der Figur, je eine NLA-Spur – der glTF-Export macht
daraus je eine Animation (Name wie die Datei).
"""

import os

import numpy as np

import bpy
from mathutils import Quaternion, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
ANIM_DIR = os.path.join(ROOT, "assets", "models", "characters", "animations")
FPS = 30
# Animationen: Name → (Schleife, seitliches Wandern der Hüfte entfernen)
CLIPS = {
    "walk": (True, False),
    "idle": (True, False),
    "idle_2": (True, False),
    "sit_down": (False, True),
    "sit_idle": (True, True),
    "stand_up": (False, True),
}


def import_source(path):
    """Mixamo-FBX laden; liefert das Skelett-Objekt (Szene danach aufräumen: remove_source)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    new = [o for o in bpy.data.objects if o not in before]
    arm = [o for o in new if o.type == "ARMATURE"][0]
    for o in new:
        if o is not arm:
            bpy.data.objects.remove(o)
    return arm


def remove_source(arm):
    action = arm.animation_data.action if arm.animation_data else None
    data = arm.data
    bpy.data.objects.remove(arm)
    bpy.data.armatures.remove(data)
    if action:
        bpy.data.actions.remove(action)


def world_rot(m):
    return m.to_3x3().normalized()


def bake(target, source, name, strip_horizontal):
    """Animation von source (Mixamo-Skelett) auf target übertragen → Aktion name. Liefert dict mit
    Hüftbahn (Welt) und Länge."""
    import build_chibi as B
    mapping = {}
    for b in target.data.bones:
        src = B.mixamo_name(b.name)
        if src in source.pose.bones:
            mapping[b.name] = src
    act_src = source.animation_data.action
    f0, f1 = int(act_src.frame_range[0]), int(act_src.frame_range[1])
    frames = list(range(f0, f1 + 1))
    sw = source.matrix_world
    src_rest = {s: world_rot(sw @ source.data.bones[s].matrix_local) for s in mapping.values()}
    tgt_rest = {b.name: b.matrix_local.to_3x3().normalized() for b in target.data.bones}
    s_hips = source.data.bones["mixamorig:Hips"]
    s_hips_rest = (sw @ s_hips.matrix_local).translation
    t_hips = target.data.bones["Hips"]
    ratio = t_hips.head_local.z / s_hips_rest.z
    scene = bpy.context.scene
    rots = {b: [] for b in mapping}
    hips_loc = []
    hips_world = []
    for f in frames:
        scene.frame_set(f)
        deltas = {}
        for tb, sb in mapping.items():
            m = sw @ source.pose.bones[sb].matrix
            deltas[tb] = world_rot(m) @ src_rest[sb].inverted()
        for tb in mapping:
            bone = target.data.bones[tb]
            d = deltas[tb]
            if bone.parent and bone.parent.name in deltas:
                d = deltas[bone.parent.name].inverted() @ d
            r = tgt_rest[tb]
            q = (r.inverted() @ d @ r).to_quaternion()
            if rots[tb] and rots[tb][-1].dot(q) < 0:
                q.negate()
            rots[tb].append(q)
        # Hüfte: Bewegung gegenüber der Ruhelage (Welt), auf die Figur umgerechnet
        hw = (sw @ source.pose.bones["mixamorig:Hips"].matrix).translation
        hips_world.append(Vector(hw))
        off = (hw - s_hips_rest) * ratio
        hips_loc.append(off)
    if strip_horizontal:
        for v in hips_loc:
            v.x, v.y = 0.0, 0.0
    action = bpy.data.actions.new(name)
    rest_hips = t_hips.matrix_local
    for tb, qs in rots.items():
        path = f'pose.bones["{tb}"].rotation_quaternion'
        for i in range(4):
            fc = action.fcurves.new(path, index=i, action_group=tb)
            fc.keyframe_points.add(len(frames))
            co = np.zeros(len(frames) * 2)
            co[0::2] = frames
            co[1::2] = [q[i] for q in qs]
            fc.keyframe_points.foreach_set("co", co)
            fc.update()
    # Hüfte: Verschiebung in den Achsen des Knochens (Basis = Ruhelage⁻¹ · Verschiebung in Welt)
    inv = rest_hips.to_3x3().normalized().inverted()
    path = 'pose.bones["Hips"].location'
    for i in range(3):
        fc = action.fcurves.new(path, index=i, action_group="Hips")
        fc.keyframe_points.add(len(frames))
        co = np.zeros(len(frames) * 2)
        co[0::2] = frames
        co[1::2] = [(inv @ v)[i] for v in hips_loc]
        fc.keyframe_points.foreach_set("co", co)
        fc.update()
    for fc in action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    return {"action": action, "frames": frames, "ratio": ratio, "hips_world": hips_world}


def walk_speed(target, action, frames):
    """Tempo (m/s), bei dem die Füße der Geh-Animation genau passen: Wie schnell gleitet der Fuß
    nach hinten, solange er auf dem Boden steht?"""
    scene = bpy.context.scene
    target.animation_data_create()
    target.animation_data.action = action
    foot, hips = target.pose.bones["LeftFoot"], target.pose.bones["Hips"]
    pos = []
    for f in frames:
        scene.frame_set(f)
        p = target.matrix_world @ foot.head
        h = target.matrix_world @ hips.head
        pos.append((p.z, p.y - h.y))   # Höhe, Lage hinter der Hüfte (Blender: +y = hinten)
    target.animation_data.action = None
    z = np.array([p[0] for p in pos])
    y = np.array([p[1] for p in pos])
    ground = z < z.min() + 0.012
    v = np.diff(y) * FPS
    stance = ground[:-1] & ground[1:]
    if stance.sum() < 2:
        return 1.0
    return float(np.median(v[stance]))


def sit_seat_height(target, body_obj, action, frames):
    """Höhe der Sitzfläche unter dem Po in der Sitz-Animation (m über dem Boden der Figur)."""
    scene = bpy.context.scene
    target.animation_data_create()
    target.animation_data.action = action
    scene.frame_set(frames[len(frames) // 2])
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body_obj.evaluated_get(dg)
    co = np.array([v.co[:] for v in ev.data.vertices])
    target.animation_data.action = None
    groups = {g.index: g.name for g in body_obj.vertex_groups}
    w = np.zeros(len(body_obj.data.vertices))
    for v in body_obj.data.vertices:
        for g in v.groups:
            if groups[g.group] in ("Hips", "LeftUpperLeg", "RightUpperLeg"):
                w[v.index] += g.weight
    sel = (w > 0.6) & (co[:, 2] > 0.12)
    return float(co[sel, 2].min())


def add_animations(target, body_obj):
    """Alle Animationen auf das Skelett target übertragen. Liefert Zusatzangaben für Godot
    (Tempo der Geh-Animation, Sitzhöhe, Länge der Sitz-Übergänge)."""
    scene = bpy.context.scene
    scene.render.fps = FPS
    info = {}
    target.animation_data_create()
    for name, (loop, strip) in CLIPS.items():
        path = os.path.join(ANIM_DIR, name + ".fbx")
        if not os.path.exists(path):
            print("  Animation fehlt:", path)
            continue
        src = import_source(path)
        res = bake(target, src, name, strip)
        remove_source(src)
        action = res["action"]
        if name == "walk":
            info["walk_speed"] = walk_speed(target, action, res["frames"])
        if name == "sit_idle":
            info["sit_seat"] = sit_seat_height(target, body_obj, action, res["frames"])
        if name in ("sit_down", "stand_up"):
            info[name + "_time"] = (len(res["frames"]) - 1) / FPS
            hw = res["hips_world"]
            info[name + "_shift"] = abs(hw[-1].y - hw[0].y) * res["ratio"]
        track = target.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, int(res["frames"][0]), action)
        strip.name = name
        track.mute = True
        action.use_fake_user = True
        print(f"  Animation {name}: {len(res['frames'])} Bilder")
    target.animation_data.action = None
    scene.frame_set(1)
    for pb in target.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    return info
