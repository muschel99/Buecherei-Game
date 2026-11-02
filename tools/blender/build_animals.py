"""Tiere der Straße (seit Etappe 6g): kleine Vögel und Katzen im weichen Bilderbuch-Stil – geschlossene,
runde Körper, liebevoll und passend zu den Chibi-Figuren – mit Skelett und Bewegungen.

Jedes Tier ist EIN Netz mit Skelett (je Teil feste bzw. weich verteilte Gewichte, kein automatisches
Gewichten) und mehreren Bewegungen (NLA-Spuren → Animationen in der .glb):
    Vogel:  idle, peck, hop, fly, glide
    Katze:  idle, walk, run, sit, lie, sleep, groom, stretch, pet, jump
Farben: Materialien „Vogel Gefieder“, „Vogel Flügel“, „Vogel Brust“, „Vogel Schnabel“, „Vogel Auge“ bzw.
„Katze Fell“, „Katze Fell hell“, „Katze Nase“, „Katze Auge“ – das Spiel färbt sie je Art bzw. je Katze
(scripts/animals/animal_model.gd). Blender-Koordinaten: vorn = -y, oben = z, Ursprung zwischen den Füßen.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_animals.py               beide Tiere + Vogelhäuschen
    blender -b --factory-startup --python tools/blender/build_animals.py -- cat        nur die Katze
    blender -b --factory-startup --python tools/blender/build_animals.py -- --render   dazu Kontrollbilder
Ausgabe:
    assets/models/animals/<tier>.glb                     Spiel-Modell (+ .glb.import mit den Materialien)
    assets/models/animals/birdhouse.glb                  Vogelhäuschen (Plätze „Perch_<n>“, siehe build_birdhouse)
    assets/models/animals/cat_toy.glb                    Filzmaus, Spielzeug der Katzen (siehe build_toy)
    assets/models/source/animals/<tier>.blend            Quelle zum Weiterbauen
    assets/models/templates/animals/<tier>.glb           Vorlage in echter Größe (gleich dem Spiel-Modell)
    screenshots/blender/animals/<tier>_<pose>.png        Kontrollbilder (mit --render)
"""
import math
import os
import random
import shutil
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_lib as SB  # noqa: E402
import storybook_common as SC  # noqa: E402
from storybook_lib import Body  # noqa: E402

ROOT = SC.ROOT
OUT = os.path.join(ROOT, "assets", "models", "animals")
SRC = os.path.join(ROOT, "assets", "models", "source", "animals")
TEMPLATES = os.path.join(ROOT, "assets", "models", "templates", "animals")
SHOTS = os.path.join(ROOT, "screenshots", "blender", "animals")
FPS = 30


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------------------------
# Netz aus Teilen + Gewichte
# ---------------------------------------------------------------------------------------------

class Animal:
    """Sammelt Teile (Body + Gewichtsregel) und Knochen, baut daraus ein Netz mit Skelett."""

    def __init__(self, name):
        self.name = name
        self.coll = SB.collection(name)
        self.parts = []      # [(Body, weights(co) -> {knochen: gewicht})]
        self.bones = []      # [(name, kopf, ende, eltern)]
        self.seed = 11

    def part(self, label, mat, weights, bevel=0.0):
        b = Body(label, mat, self.coll, seed=self.seed, vary=0.02, bevel=bevel)
        self.seed += 7
        self.parts.append((b, weights))
        return b

    def bone(self, name, head, tail, parent=None):
        self.bones.append((name, Vector(head), Vector(tail), parent))

    def build(self):
        """Teile bauen, Gewichte setzen, zu einem Netz verbinden, Skelett anlegen und verbinden."""
        dg = bpy.context.evaluated_depsgraph_get()
        objs = []
        for b, weights in self.parts:
            o = b.build(smooth_angle=180)
            dg = bpy.context.evaluated_depsgraph_get()
            me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
            c = bpy.data.objects.new(o.name, me)
            self.coll.objects.link(c)
            bpy.data.objects.remove(o)
            groups = {}
            for v in me.vertices:
                for bone, w in weights(v.co).items():
                    if w <= 0.0:
                        continue
                    if bone not in groups:
                        groups[bone] = c.vertex_groups.new(name=bone)
                    groups[bone].add([v.index], w, "REPLACE")
            objs.append(c)
        with bpy.context.temp_override(active_object=objs[0], object=objs[0], selected_objects=objs,
                                       selected_editable_objects=objs):
            bpy.ops.object.join()
        mesh = objs[0]
        mesh.name = self.name
        # überall weich schattiert (Tiere haben keine Kanten)
        for poly in mesh.data.polygons:
            poly.use_smooth = True
        for edge in mesh.data.edges:
            edge.use_edge_sharp = False
        mesh.data.use_auto_smooth = False
        ca = mesh.data.color_attributes.get("tint")
        if ca:
            mesh.data.color_attributes.active_color = ca
            mesh.data.color_attributes.render_color_index = list(mesh.data.color_attributes).index(ca)
        rest_uvs(mesh.data)
        # Skelett
        arm_data = bpy.data.armatures.new(self.name + " Skelett")
        arm = bpy.data.objects.new(self.name + " Skelett", arm_data)
        self.coll.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        for name, head, tail, parent in self.bones:
            eb = arm_data.edit_bones.new(name)
            eb.head = head
            eb.tail = tail
            eb.roll = 0.0
            if parent:
                eb.parent = arm_data.edit_bones[parent]
        bpy.ops.object.mode_set(mode="OBJECT")
        mesh.parent = arm
        mod = mesh.modifiers.new("Skelett", "ARMATURE")
        mod.object = arm
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
        self.mesh, self.arm = mesh, arm
        return mesh, arm


def rest_uvs(me):
    """Lage in der Ruhehaltung als Texturkoordinaten (Godot-Achsen): UV = (x, y), UV2 = (z, 0). Der Shader
    storybook_animal.gdshader rechnet Flecken und Tigerstreifen daraus – so bleibt das Muster beim Laufen am
    Fell (die Lage nach dem Skelett würde unter den Mustern hindurchrutschen)."""
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uv1 = me.uv_layers.new(name="rest_xy")
    uv2 = me.uv_layers.new(name="rest_z")
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uv1.data[loop.index].uv = (co.x, co.z)
        uv2.data[loop.index].uv = (-co.y, 0.0)


def animal_shader(names):
    """Godot-Materialien der Tiere auf den Tier-Shader umstellen (Muster aus der Ruhehaltung)."""
    for name in names:
        path = os.path.join(SC.GAME_MAT_DIR, SC.slug(name) + ".tres")
        if not os.path.exists(path):
            continue
        with open(path) as f:
            text = f.read()
        text = text.replace("res://assets/shaders/storybook.gdshader", "res://assets/shaders/storybook_animal.gdshader")
        with open(path, "w") as f:
            f.write(text)


def rigid(bone):
    return lambda co: {bone: 1.0}


def blend(bone_a, bone_b, axis, a, b):
    """Weicher Übergang zwischen zwei Knochen entlang einer Achse (0 = x, 1 = y, 2 = z) von a nach b."""
    def fn(co):
        w = smoothstep(a, b, co[axis])
        return {bone_a: 1.0 - w, bone_b: w}
    return fn


def chain(segments):
    """Gewichte entlang einer Kette von Knochen (Schwanz): je Punkt die zwei nächsten Abschnitte, weich."""
    def fn(co):
        ds = []
        for name, p0, p1 in segments:
            d = p1 - p0
            t = max(0.0, min(1.0, (co - p0).dot(d) / d.length_squared))
            ds.append((name, (p0 + d * t - co).length))
        ws = {n: 1.0 / (d + 0.004) ** 4 for n, d in ds}
        total = sum(ws.values())
        return {n: w / total for n, w in ws.items()}
    return fn


# ---------------------------------------------------------------------------------------------
# Bewegungen: Drehungen in Achsen des Skeletts (x = vorn neigen/hinten heben, y = rollen, z = drehen)
# ---------------------------------------------------------------------------------------------

def _quat(steps):
    """steps = [("x", grad), ("z", grad) …] nacheinander um die festen Achsen des Skeletts."""
    q = Quaternion()
    for axis, deg in steps:
        v = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}[axis]
        q = Quaternion(v, math.radians(deg)) @ q
    return q


def action(arm, name, length, keys, loop=True):
    """Bewegung anlegen: keys = {bild: {knochen: [(achse, grad), …] oder {"rot": […], "loc": (x, y, z)}}}.
    Fehlt ein Knochen in einem Bild, gilt dort die Ruhehaltung. Schleifen enden wie sie beginnen."""
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    frames = sorted(keys)
    if loop and length not in keys:
        keys = dict(keys)
        keys[length] = keys[frames[0]]
        frames.append(length)
    # alle Knochen in jedem Bild (sonst behielten nicht bewegte Knochen die Haltung der vorigen Bewegung –
    # z. B. gespreizte Flügel nach dem Fliegen)
    for f in frames:
        for pb in arm.pose.bones:
            spec = keys[f].get(pb.name, [])
            rot = spec.get("rot", []) if isinstance(spec, dict) else spec
            loc = spec.get("loc", (0, 0, 0)) if isinstance(spec, dict) else (0, 0, 0)
            rest = pb.bone.matrix_local.to_quaternion()
            pb.rotation_quaternion = rest.inverted() @ _quat(rot) @ rest
            # Verschiebung in Achsen des Skeletts -> Knochen-Raum
            pb.location = rest.inverted() @ Vector(loc)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.easing = "AUTO"
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    return act


# ---------------------------------------------------------------------------------------------
# Vogel (kleiner Singvogel, etwa 14 cm lang)
# ---------------------------------------------------------------------------------------------

def bird_materials():
    return {
        "plumage": SC.make_material("Vogel Gefieder", (0.55, 0.42, 0.3), grain="smooth", rough=0.85, vary=0.05),
        "wing": SC.make_material("Vogel Flügel", (0.42, 0.3, 0.2), grain="smooth", rough=0.85, vary=0.06),
        "breast": SC.make_material("Vogel Brust", (0.86, 0.76, 0.6), grain="smooth", rough=0.9, vary=0.04),
        "beak": SC.make_material("Vogel Schnabel", (0.85, 0.6, 0.3), grain="smooth", rough=0.6, vary=0.03),
        "eye": SC.make_material("Vogel Auge", (0.03, 0.025, 0.02), grain="smooth", rough=0.15, vary=0.0),
    }


def build_bird():
    M = bird_materials()
    a = Animal("bird")
    a.bone("root", (0, 0, 0), (0, 0, 0.02))
    a.bone("body", (0, 0.01, 0.035), (0, 0.01, 0.065), "root")
    a.bone("head", (0, -0.028, 0.074), (0, -0.04, 0.1), "body")
    a.bone("wing_l", (0.026, -0.012, 0.066), (0.03, 0.045, 0.055), "body")
    a.bone("wing_r", (-0.026, -0.012, 0.066), (-0.03, 0.045, 0.055), "body")
    a.bone("tail", (0, 0.042, 0.052), (0, 0.085, 0.067), "body")
    a.bone("leg_l", (0.011, 0.002, 0.03), (0.011, 0.0, 0.004), "root")
    a.bone("leg_r", (-0.011, 0.002, 0.03), (-0.011, 0.0, 0.004), "root")
    # Körper: rundlich, vorn die Brust in eigener Farbe (überlappt leicht)
    body = a.part("Körper", M["plumage"], rigid("body"))
    body.blob((0, 0.004, 0.052), 0.04, subdiv=3, lump=0.02, scale=(0.78, 1.15, 0.85))
    breast = a.part("Brust", M["breast"], rigid("body"))
    breast.blob((0, -0.014, 0.046), 0.031, subdiv=3, lump=0.02, scale=(0.86, 0.9, 0.86))
    head = a.part("Kopf", M["plumage"], rigid("head"))
    head.blob((0, -0.034, 0.087), 0.026, subdiv=3, lump=0.015, scale=(0.95, 1.0, 0.95))
    cap = a.part("Kappe", M["wing"], rigid("head"))
    cap.blob((0, -0.033, 0.098), 0.021, subdiv=3, lump=0.01, scale=(0.92, 1.08, 0.58))
    cheek = a.part("Wangen", M["breast"], rigid("head"))
    for sx in (-1, 1):
        cheek.blob((sx * 0.0175, -0.044, 0.081), 0.0075, subdiv=2, lump=0.0, scale=(0.55, 1.0, 0.85))
    beak = a.part("Schnabel", M["beak"], rigid("head"))
    beak.tube([(0, -0.054, 0.0855), (0, -0.07, 0.0835)], lambda t: 0.0062 * (1 - t) + 0.0009, segs=10, round_ends=True)
    eyes = a.part("Augen", M["eye"], rigid("head"))
    for sx in (-1, 1):
        eyes.blob((sx * 0.0175, -0.049, 0.0925), 0.0048, subdiv=2, lump=0.0)
    for sx, bone in ((1, "wing_l"), (-1, "wing_r")):
        w = a.part("Flügel", M["wing"], rigid(bone))
        w.leaf((sx * 0.027, -0.012, 0.066), (0, 1.0, -0.28), (sx * 1.0, 0.0, 0.25), 0.062, 0.034, shape="oval",
               thick=0.007, curl=0.1)
    tail = a.part("Schwanz", M["wing"], rigid("tail"))
    tail.leaf((0, 0.042, 0.054), (0, 1.0, 0.36), (0, -0.2, 1.0), 0.048, 0.03, shape="oval", thick=0.006, curl=0.05)
    for sx, bone in ((1, "leg_l"), (-1, "leg_r")):
        leg = a.part("Bein", M["beak"], rigid(bone))
        x = sx * 0.011
        leg.tube([(x, 0.002, 0.03), (x, 0.0, 0.004)], 0.0024, segs=7, round_ends=True)
        for tx, ty in ((-0.006, -0.014), (0.0, -0.016), (0.006, -0.014), (0.0, 0.011)):
            leg.tube([(x, 0.0, 0.0035), (x + tx * sx, ty, 0.0018)], 0.0017, segs=6, round_ends=True)
    mesh, arm = a.build()
    # Bewegungen
    spread_l = [("z", -82), ("x", -90)]
    spread_r = [("z", 82), ("x", -90)]
    action(arm, "idle", 72, {
        0: {"head": [], "tail": []},
        14: {"head": [("z", 28)]},
        24: {"head": [("z", 28), ("x", 6)], "tail": [("x", 16)]},
        28: {"tail": []},
        36: {"head": []},
        48: {"head": [("z", -32)]},
        58: {"head": [("z", -32), ("y", 10)]},
        66: {"head": []},
    })
    action(arm, "peck", 24, {
        0: {"body": [], "head": []},
        5: {"body": [("x", 28)], "head": [("x", 30)]},
        8: {"body": [("x", 30)], "head": [("x", 48)]},
        11: {"body": [("x", 28)], "head": [("x", 26)]},
        14: {"body": [("x", 30)], "head": [("x", 50)]},
        19: {"body": [("x", 8)], "head": [("x", 6)]},
    })
    action(arm, "hop", 12, {
        0: {"root": {"rot": [], "loc": (0, 0, 0)}, "leg_l": [], "leg_r": [], "wing_l": [], "wing_r": [], "tail": []},
        3: {"root": {"rot": [], "loc": (0, 0, 0.018)}, "leg_l": [("x", 22)], "leg_r": [("x", 22)],
            "wing_l": [("z", -12)], "wing_r": [("z", 12)], "tail": [("x", 12)]},
        6: {"root": {"rot": [], "loc": (0, 0, 0.026)}, "leg_l": [("x", 30)], "leg_r": [("x", 30)],
            "wing_l": [("z", -18)], "wing_r": [("z", 18)], "tail": [("x", 16)]},
        9: {"root": {"rot": [], "loc": (0, 0, 0.01)}, "leg_l": [("x", 8)], "leg_r": [("x", 8)],
            "wing_l": [("z", -6)], "wing_r": [("z", 6)], "tail": [("x", 4)]},
    })
    tuck = [("x", 70)]
    action(arm, "fly", 8, {
        0: {"wing_l": spread_l + [("y", -55)], "wing_r": spread_r + [("y", 55)], "leg_l": tuck, "leg_r": tuck,
            "tail": [("x", -6)], "head": [("x", -6)], "body": [("x", -4)]},
        4: {"wing_l": spread_l + [("y", 35)], "wing_r": spread_r + [("y", -35)], "leg_l": tuck, "leg_r": tuck,
            "tail": [("x", -2)], "head": [("x", -6)], "body": [("x", -2)]},
    })
    action(arm, "glide", 40, {
        0: {"wing_l": spread_l + [("y", -8)], "wing_r": spread_r + [("y", 8)], "leg_l": tuck, "leg_r": tuck,
            "tail": [("x", -4)], "head": [("x", -6)]},
        20: {"wing_l": spread_l + [("y", -2)], "wing_r": spread_r + [("y", 2)], "leg_l": tuck, "leg_r": tuck,
             "tail": [("x", -8)], "head": [("x", -4)]},
    })
    return a, M


# ---------------------------------------------------------------------------------------------
# Katze (etwa 45 cm lang, großer runder Kopf wie die Chibi-Figuren)
# ---------------------------------------------------------------------------------------------

def cat_materials():
    return {
        "fur": SC.make_material("Katze Fell", (0.85, 0.5, 0.24), grain="smooth", rough=0.95, vary=0.07),
        "fur2": SC.make_material("Katze Fell hell", (0.96, 0.9, 0.8), grain="smooth", rough=0.95, vary=0.05),
        "nose": SC.make_material("Katze Nase", (0.86, 0.5, 0.52), grain="smooth", rough=0.6, vary=0.03),
        "eye": SC.make_material("Katze Auge", (0.45, 0.62, 0.22), grain="smooth", rough=0.12, vary=0.0),
        "pupil": SC.make_material("Katze Pupille", (0.03, 0.025, 0.02), grain="smooth", rough=0.1, vary=0.0),
    }


TAIL = [("tail1", Vector((0, 0.19, 0.22)), Vector((0, 0.25, 0.255))),
        ("tail2", Vector((0, 0.25, 0.255)), Vector((0, 0.29, 0.33))),
        ("tail3", Vector((0, 0.29, 0.33)), Vector((0, 0.3, 0.41)))]


def build_cat():
    M = cat_materials()
    a = Animal("cat")
    a.bone("root", (0, 0, 0), (0, 0, 0.05))
    a.bone("hips", (0, 0.1, 0.19), (0, 0.0, 0.2), "root")
    a.bone("chest", (0, 0.0, 0.2), (0, -0.12, 0.22), "hips")
    a.bone("neck", (0, -0.12, 0.22), (0, -0.17, 0.29), "chest")
    a.bone("head", (0, -0.17, 0.29), (0, -0.2, 0.42), "neck")
    for sx, s in ((1, "l"), (-1, "r")):
        a.bone("fl_upper_" + s, (sx * 0.05, -0.11, 0.17), (sx * 0.05, -0.12, 0.09), "chest")
        a.bone("fl_lower_" + s, (sx * 0.05, -0.12, 0.09), (sx * 0.05, -0.125, 0.02), "fl_upper_" + s)
        a.bone("bl_upper_" + s, (sx * 0.058, 0.12, 0.17), (sx * 0.058, 0.14, 0.085), "hips")
        a.bone("bl_lower_" + s, (sx * 0.058, 0.14, 0.085), (sx * 0.056, 0.13, 0.02), "bl_upper_" + s)
    parent = "hips"
    for name, p0, p1 in TAIL:
        a.bone(name, p0, p1, parent)
        parent = name
    torso = blend("chest", "hips", 1, -0.04, 0.06)

    def trunk_w(co):
        # Rumpf: hinten Hüfte, vorn Brust, oben am Hals in den Hals übergehend
        w = torso(co)
        up = smoothstep(0.235, 0.29, co.z) * smoothstep(-0.08, -0.13, co.y)
        return {"hips": w["hips"] * (1 - up), "chest": w["chest"] * (1 - up), "neck": up}
    # Rumpf als EIN weicher Körper vom Hinterteil bis zum Hals (keine Kugeln hintereinander)
    profile = [(0.0, 0.07), (0.12, 0.088), (0.35, 0.094), (0.6, 0.09), (0.8, 0.08), (1.0, 0.062)]

    def trunk_r(t):
        for (t0, r0), (t1, r1) in zip(profile, profile[1:]):
            if t <= t1:
                return r0 + (r1 - r0) * smoothstep(t0, t1, t)
        return profile[-1][1]
    spine = [(0, 0.17, 0.205), (0, 0.125, 0.198), (0, 0.08, 0.195), (0, 0.03, 0.196), (0, -0.02, 0.2), (0, -0.06, 0.206),
             (0, -0.1, 0.215), (0, -0.128, 0.236), (0, -0.15, 0.262)]
    a.part("Rumpf", M["fur"], trunk_w).tube(spine, trunk_r, segs=24, smooth=2, round_ends=True)
    a.part("Brustfleck", M["fur2"], rigid("chest")).blob((0, -0.132, 0.185), 0.06, subdiv=3, lump=0.02,
                                                         scale=(0.85, 0.62, 1.0))
    a.part("Bauch", M["fur2"], torso).blob((0, 0.01, 0.135), 0.07, subdiv=3, lump=0.02, scale=(0.9, 1.6, 0.5))
    h = rigid("head")
    a.part("Kopf", M["fur"], h).blob((0, -0.19, 0.34), 0.1, subdiv=3, lump=0.015, scale=(1.08, 0.95, 0.92))
    a.part("Schnauze", M["fur2"], h).blob((0, -0.268, 0.312), 0.042, subdiv=3, lump=0.01, scale=(1.18, 0.7, 0.78))
    a.part("Nase", M["nose"], h).blob((0, -0.296, 0.332), 0.011, subdiv=2, lump=0.0, scale=(1.35, 0.8, 0.8))
    eyes = a.part("Augen", M["eye"], h)
    pupils = a.part("Pupillen", M["pupil"], h)
    for sx in (-1, 1):
        eyes.blob((sx * 0.043, -0.27, 0.352), 0.02, subdiv=2, lump=0.0, scale=(1.0, 0.55, 1.15))
        pupils.blob((sx * 0.043, -0.281, 0.353), 0.0085, subdiv=2, lump=0.0, scale=(0.75, 0.5, 1.35))
    ears = a.part("Ohren", M["fur"], h)
    inner = a.part("Ohren innen", M["nose"], h)
    for sx in (-1, 1):
        ears.tube([(sx * 0.055, -0.18, 0.405), (sx * 0.077, -0.172, 0.486)], lambda t: 0.036 * (1 - t) + 0.004,
                  segs=10, round_ends=True)
        inner.tube([(sx * 0.056, -0.196, 0.412), (sx * 0.074, -0.188, 0.474)], lambda t: 0.022 * (1 - t) + 0.003,
                   segs=8, round_ends=True)
    for sx, s in ((1, "l"), (-1, "r")):
        x = sx * 0.05
        fleg = a.part("Vorderbein", M["fur"], blend("fl_lower_" + s, "fl_upper_" + s, 2, 0.07, 0.11))
        fleg.tube([(x * 0.96, -0.11, 0.175), (x, -0.12, 0.09), (x, -0.125, 0.032)], 0.026, segs=10, smooth=1,
                  round_ends=True)
        a.part("Pfote", M["fur2"], rigid("fl_lower_" + s)).blob((x, -0.136, 0.022), 0.03, subdiv=2, lump=0.02,
                                                              scale=(1.0, 1.25, 0.62))
        bx = sx * 0.058
        a.part("Keule", M["fur"], blend("bl_upper_" + s, "hips", 2, 0.17, 0.215)).blob(
            (sx * 0.062, 0.115, 0.16), 0.062, subdiv=3, lump=0.02, scale=(0.7, 1.1, 1.0))
        bleg = a.part("Hinterbein", M["fur"], blend("bl_lower_" + s, "bl_upper_" + s, 2, 0.06, 0.1))
        bleg.tube([(bx, 0.12, 0.13), (bx, 0.14, 0.072), (bx * 0.97, 0.13, 0.03)], 0.025, segs=10, smooth=1,
                  round_ends=True)
        a.part("Pfote", M["fur2"], rigid("bl_lower_" + s)).blob((bx * 0.97, 0.122, 0.022), 0.03, subdiv=2, lump=0.02,
                                                              scale=(1.0, 1.25, 0.62))
    tail_w = chain([("hips", Vector((0, 0.12, 0.2)), Vector((0, 0.19, 0.22)))] + TAIL)
    a.part("Schwanz", M["fur"], tail_w).tube([(0, 0.17, 0.215), (0, 0.25, 0.255), (0, 0.29, 0.33), (0, 0.3, 0.41)],
                                             lambda t: 0.026 - 0.01 * t, segs=12, smooth=3, round_ends=True)
    mesh, arm = a.build()
    cat_actions(arm)
    return a, M


def cat_actions(arm):
    sway = lambda d: {"tail1": [("z", d)], "tail2": [("z", d * 1.4)], "tail3": [("z", d * 1.8)]}  # noqa: E731
    action(arm, "idle", 90, {
        0: dict(sway(0), head=[]),
        22: dict(sway(10), head=[("z", 14)]),
        45: dict(sway(0), head=[("z", 14), ("x", 6)]),
        68: dict(sway(-10), head=[("z", -12)]),
    })

    # Gehen: diagonale Paare (vorn links mit hinten rechts)
    def legs(fl, fr, bl, br, kfl=0, kfr=0, kbl=0, kbr=0):
        return {"fl_upper_l": [("x", fl)], "fl_upper_r": [("x", fr)], "bl_upper_l": [("x", bl)], "bl_upper_r": [("x", br)],
                "fl_lower_l": [("x", kfl)], "fl_lower_r": [("x", kfr)], "bl_lower_l": [("x", kbl)], "bl_lower_r": [("x", kbr)]}
    walk = {}
    for f, (a_, b_, ka, kb) in {0: (-22, 22, 0, 0), 6: (0, 0, 28, 0), 12: (22, -22, 0, 0), 18: (0, 0, 0, 28)}.items():
        k = legs(a_, b_, b_, a_, kfl=ka, kfr=kb, kbl=-kb, kbr=-ka)
        k["root"] = {"rot": [], "loc": (0, 0, 0.006 if f in (6, 18) else 0.0)}
        k.update(sway(8 if f < 12 else -8))
        k["head"] = [("x", 4 if f in (6, 18) else 0)]
        walk[f] = k
    action(arm, "walk", 24, walk)
    run = {}
    for f, (fa, ba, up) in {0: (-38, 34, 0.0), 3: (-10, 10, 0.03), 6: (34, -38, 0.012), 9: (8, -8, 0.025)}.items():
        k = legs(fa, fa, ba, ba, kfl=20 if fa > 0 else 0, kfr=20 if fa > 0 else 0, kbl=-25 if ba < 0 else 0,
                 kbr=-25 if ba < 0 else 0)
        k["root"] = {"rot": [], "loc": (0, 0, up)}
        k["chest"] = [("x", -8 if f in (0, 9) else 8)]
        k["hips"] = [("x", 6 if f in (0, 9) else -6)]
        k["tail1"] = [("x", 20)]
        run[f] = k
    action(arm, "run", 12, run)

    # Sitzen: Hinterteil nach unten, Vorderbeine gerade, Schwanz um die Pfoten
    def sit_pose(extra=None, tail=12):
        k = {"root": {"rot": [], "loc": (0, 0.02, -0.055)}, "hips": [("x", -38)],
             "chest": [("x", -6)], "neck": [("x", 24)], "head": [("x", 16)],
             "fl_upper_l": [("x", 44)], "fl_upper_r": [("x", 44)],
             "bl_upper_l": [("x", -58)], "bl_upper_r": [("x", -58)], "bl_lower_l": [("x", 96)], "bl_lower_r": [("x", 96)],
             "tail1": [("x", -42), ("z", 25)], "tail2": [("z", 45 + tail)], "tail3": [("z", 50 + tail)]}
        if extra:
            k.update(extra)
        return k
    action(arm, "sit", 90, {0: sit_pose(), 30: sit_pose({"head": [("x", 16), ("z", 18)]}, 4),
                            60: sit_pose({"head": [("x", 12), ("z", -10)]}, 16)})
    # Putzen im Sitzen: eine Vorderpfote zum Mund, Kopf leckt
    groom = {}
    for f in range(0, 48, 6):
        lick = 10 if (f // 6) % 2 else 0
        groom[f] = sit_pose({"fl_upper_l": [("x", -30)], "fl_lower_l": [("x", -70)],
                             "neck": [("x", 30)], "head": [("x", 22 + lick), ("z", 14)]})
    action(arm, "groom", 48, groom)
    # Gestreichelt: im Sitzen den Kopf heben und reiben, Schwanz hoch
    action(arm, "pet", 48, {0: sit_pose({"head": [("x", -10), ("z", 10)], "tail1": [("x", 30)]}),
                            24: sit_pose({"head": [("x", -14), ("z", -12)], "tail1": [("x", 36)]})})

    # Liegen („Brotlaib“): Körper unten, Beine untergeschlagen, Pfoten vorn
    def lie_pose(extra=None):
        k = {"root": {"rot": [], "loc": (0, 0, -0.105)}, "neck": [("x", 8)],
             "fl_upper_l": [("x", 84)], "fl_upper_r": [("x", 84)], "fl_lower_l": [("x", -170)], "fl_lower_r": [("x", -170)],
             "bl_upper_l": [("x", -80)], "bl_upper_r": [("x", -80)], "bl_lower_l": [("x", 150)], "bl_lower_r": [("x", 150)],
             "tail1": [("x", -50), ("z", 30)], "tail2": [("z", 55)], "tail3": [("z", 55)]}
        if extra:
            k.update(extra)
        return k
    action(arm, "lie", 90, {0: lie_pose(), 45: lie_pose({"head": [("z", 16)], "tail3": [("z", 70)]})})
    # Schlafen: eingerollt, Kopf auf den Pfoten, ruhiges Atmen
    sleep = lie_pose({"chest": [("z", 26)], "hips": [("z", -22)], "neck": [("x", 40), ("z", 18)], "head": [("x", 20), ("z", 28)],
                      "tail1": [("x", -50), ("z", -40)], "tail2": [("z", -60)], "tail3": [("z", -60)]})
    sleep2 = dict(sleep)
    sleep2["root"] = {"rot": [], "loc": (0, 0, -0.1)}
    action(arm, "sleep", 120, {0: sleep, 60: sleep2})
    # Strecken: vorn tief, Hinterteil hoch, Schwanz hoch (einmal, dann gehalten)
    stretch = {"root": {"rot": [], "loc": (0, 0, -0.02)}, "chest": [("x", 22)], "hips": [("x", -12)],
               "fl_upper_l": [("x", -62)], "fl_upper_r": [("x", -62)], "fl_lower_l": [("x", -10)], "fl_lower_r": [("x", -10)],
               "neck": [("x", -10)], "head": [("x", -14)], "tail1": [("x", 48)], "tail2": [("x", 10)]}
    action(arm, "stretch", 60, {0: {"root": {"rot": [], "loc": (0, 0, 0)}}, 24: stretch, 48: stretch,
                                60: {"root": {"rot": [], "loc": (0, 0, 0)}}}, loop=False)
    # Sprung (auf eine Bank): ducken, strecken, landen
    action(arm, "jump", 16, {
        0: {"root": {"rot": [], "loc": (0, 0, 0)}},
        4: {"root": {"rot": [], "loc": (0, 0, -0.04)}, "hips": [("x", 8)], "chest": [("x", 6)],
            "bl_upper_l": [("x", -30)], "bl_upper_r": [("x", -30)], "bl_lower_l": [("x", 50)], "bl_lower_r": [("x", 50)]},
        8: {"root": {"rot": [], "loc": (0, 0, 0.01)}, "chest": [("x", -14)],
            "fl_upper_l": [("x", -50)], "fl_upper_r": [("x", -50)], "bl_upper_l": [("x", 40)], "bl_upper_r": [("x", 40)],
            "tail1": [("x", 20)]},
        12: {"root": {"rot": [], "loc": (0, 0, -0.02)}, "fl_upper_l": [("x", -10)], "fl_upper_r": [("x", -10)]},
        16: {"root": {"rot": [], "loc": (0, 0, 0)}},
    }, loop=False)


# ---------------------------------------------------------------------------------------------
# Vogelhäuschen (an einer Hauswand, mit Futterbrett)
# ---------------------------------------------------------------------------------------------

def build_birdhouse():
    """Vogelhäuschen zum Anschrauben: Rückenbrett an der Wand (zwei Schrauben), darunter zwei Winkelstützen,
    darauf das Futterbrett mit Rand und Körnern, hinten auf dem Brett das Häuschen (Giebel, Dach aus zwei
    Brettern mit Firstleiste, Flugloch, Sitzstange). Ursprung = Mitte des Rückenbretts auf der Wand, vorn = -y.
    Plätze für Vögel: leere Objekte „Perch_<n>“ mit extras kind = rim (Brettrand), feed (auf dem Brett, picken),
    stick (Sitzstange), roof (First)."""
    M = {
        "wood": SC.make_material("Holz Vogelhaus", (0.66, 0.48, 0.31), grain="wood", rough=0.85, vary=0.08),
        "roof": SC.make_material("Lack Vogelhaus Dach", (0.42, 0.52, 0.42), grain="paint", rough=0.75, vary=0.06),
        "hole": SC.make_material("Vogelhaus Loch", (0.035, 0.028, 0.022), grain="smooth", rough=0.9, vary=0.0),
        "iron": SC.make_material("Vogelhaus Schrauben", (0.2, 0.19, 0.18), grain="smooth", rough=0.5, vary=0.02, metal=0.6),
        "seed": SC.make_material("Vogelhaus Körner", (0.78, 0.66, 0.45), grain="smooth", rough=0.9, vary=0.12),
    }
    coll = SB.collection("birdhouse")
    rnd = random.Random(5)
    z0 = -0.06           # Oberkante des Futterbretts
    back = -0.02         # Vorderseite des Rückenbretts
    wood = Body("Holz", M["wood"], coll, seed=3, vary=0.02, bevel=0.003)
    # Rückenbrett an der Wand
    wood.box((0, -0.01, z0 + 0.065), (0.27, 0.02, 0.43), step=0.05, dent=0.001)
    # Futterbrett (liegt auf den Stützen, hinten am Rückenbrett)
    tray_front = -0.245
    wood.box((0, (back + tray_front) / 2, z0 - 0.008), (0.29, back - tray_front, 0.016), step=0.05, dent=0.001)
    # Rand vorn und an den Seiten (auf dem Brett)
    wood.box((0, tray_front + 0.006, z0 + 0.011), (0.29, 0.012, 0.022), step=0.05, dent=0.0005)
    for sx in (-1, 1):
        wood.box((sx * 0.139, (back + tray_front) / 2, z0 + 0.011), (0.012, back - tray_front - 0.002, 0.022), step=0.05,
                 dent=0.0005)
    # Winkelstützen unter dem Brett (Dreiecke in der Seitenebene, Dicke 12 mm)
    side = Matrix(((0, 0, -1, 0), (-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    for sx in (-1, 1):
        m = Matrix.Translation((sx * 0.1 + 0.006, back, z0 - 0.016)) @ side
        wood.slab([(0.0, 0.0), (0.0, -0.12), (0.17, 0.0)], 0.012, m, dent=0.0005)
    # Häuschen: Fünfeck (Giebel) von hinten (am Rückenbrett) nach vorn, 12 cm tief
    front = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    wood.slab([(-0.085, 0.0), (0.085, 0.0), (0.085, 0.15), (0.0, 0.235), (-0.085, 0.15)], 0.12,
              Matrix.Translation((0, back - 0.001, z0)) @ front, dent=0.0008)
    house_front = back - 0.121
    # Sitzstange (steckt 1 cm in der Vorderwand)
    wood.tube([(0, house_front + 0.01, z0 + 0.06), (0, house_front - 0.05, z0 + 0.06)], 0.0055, segs=10, round_ends=True)
    wood.build(smooth_angle=40)
    # Dach: zwei Bretter auf den Giebelkanten, vorn 3 cm über, hinten bis knapp ans Rückenbrett; Firstleiste
    roof = Body("Dach", M["roof"], coll, seed=7, vary=0.02, bevel=0.003)
    depth_front = house_front - 0.03
    for sx in (-1, 1):
        d = Vector((sx * 0.7071, -0.7071))
        n = Vector((sx * 0.7071, 0.7071))
        s_a, s_b = -0.012, 0.12 + 0.032
        c = Vector((0.0, 0.235)) + d * ((s_a + s_b) / 2) + n * 0.0075
        roof.box((c.x, (back - 0.002 + depth_front) / 2, z0 + c.y), (s_b - s_a, back - 0.002 - depth_front, 0.015),
                 step=0.05, turn=(0, 45 if sx > 0 else 135, 0), dent=0.0008)
    roof.tube([(0, back - 0.004, z0 + 0.252), (0, depth_front, z0 + 0.252)], 0.009, segs=10, round_ends=True)
    roof.build(smooth_angle=40)
    # Flugloch: dunkle Scheibe, eingelassen in die Vorderwand (ragt 1,5 mm vor)
    hole = Body("Flugloch", M["hole"], coll, seed=9, vary=0.0)
    hole.lathe([(0.0, 0.0), (0.024, 0.0), (0.024, 0.0045), (0.0, 0.0045)], (0, 0, 0), segs=24)
    hole_obj = hole.build(smooth_angle=40)
    hole_obj.matrix_world = Matrix.Translation((0, house_front + 0.003, z0 + 0.105)) @ Matrix.Rotation(math.radians(90), 4, "X")
    # Rand ums Loch: runder Wulst (Röhre im Kreis, die Enden überlappen im Inneren)
    ring = Body("Lochrand", M["wood"], coll, seed=10, vary=0.0)
    ring.tube([(0.0275 * math.cos(2 * math.pi * k / 28), house_front - 0.0005, z0 + 0.105 + 0.0275 * math.sin(2 * math.pi * k / 28))
               for k in range(30)], 0.0042, segs=8)
    ring.build(smooth_angle=180)
    # Schrauben im Rückenbrett (oben neben dem Dach, unten unter den Stützen)
    screws = Body("Schrauben", M["iron"], coll, seed=11, vary=0.0)
    for x, z in ((-0.105, z0 + 0.25), (0.105, z0 + 0.25), (-0.06, z0 - 0.125), (0.06, z0 - 0.125)):
        screws.blob((x, back + 0.001, z), 0.0065, subdiv=2, lump=0.0, scale=(1, 0.4, 1))
    screws.build(smooth_angle=180)
    # Körner auf dem Brett vor dem Häuschen
    seeds = Body("Körner", M["seed"], coll, seed=12, vary=0.0)
    for k in range(46):
        x = rnd.uniform(-0.115, 0.115)
        y = rnd.uniform(tray_front + 0.02, house_front - 0.01)
        seeds.blob((x, y, z0 + 0.0025), rnd.uniform(0.0035, 0.005), subdiv=1, lump=0.1, scale=(1.3, 0.8, 0.55))
    seeds.build(smooth_angle=180)
    # Plätze für Vögel
    perches = []
    for name, pos, kind in (("Perch_1", (-0.07, tray_front + 0.006, z0 + 0.022), "rim"),
                            ("Perch_2", (0.07, tray_front + 0.006, z0 + 0.022), "rim"),
                            ("Perch_3", (0.0, tray_front + 0.06, z0), "feed"),
                            ("Perch_4", (0.0, house_front - 0.04, z0 + 0.0655), "stick"),
                            ("Perch_5", (0.0, (back + depth_front) / 2, z0 + 0.261), "roof")):
        e = bpy.data.objects.new(name, None)
        e.location = pos
        e["kind"] = kind
        coll.objects.link(e)
        perches.append(e)
    objs = [o for o in coll.objects if o.type == "MESH"]
    return objs, perches


def build_toy():
    """Kleine Filzmaus (Spielzeug der Katzen, etwa 7 cm mit Schwanz): Körper, Ohren, Näschen, Augen, Schwanz aus
    Wollfaden. Ursprung = Mitte des Körpers (dort hält die Katze sie im Maul), vorn = -y."""
    M = {
        "felt": SC.make_material("Spielzeug Filz", (0.62, 0.6, 0.64), grain="fabric", rough=0.95, vary=0.06),
        "pink": SC.make_material("Spielzeug Rosa", (0.9, 0.56, 0.6), grain="fabric", rough=0.9, vary=0.04),
        "eye": SC.make_material("Spielzeug Augen", (0.04, 0.035, 0.03), grain="smooth", rough=0.3, vary=0.0),
    }
    coll = SB.collection("cat_toy")
    felt = Body("Filz", M["felt"], coll, seed=21, vary=0.02)
    felt.blob((0, 0, 0), 0.026, subdiv=3, lump=0.03, scale=(0.72, 1.28, 0.66))
    felt.build(smooth_angle=180)
    pink = Body("Rosa", M["pink"], coll, seed=22, vary=0.0)
    for sx in (-1, 1):
        pink.blob((sx * 0.0115, -0.019, 0.0155), 0.0085, subdiv=2, lump=0.0, scale=(1.0, 0.42, 1.0))
    pink.blob((0, -0.0335, -0.001), 0.0042, subdiv=2, lump=0.0)
    pink.tube([(0, 0.031, -0.004), (0.006, 0.048, -0.008), (0.018, 0.062, -0.012), (0.03, 0.068, -0.0155)], 0.0021,
              segs=6, smooth=2, round_ends=True)
    pink.build(smooth_angle=180)
    eyes = Body("Augen", M["eye"], coll, seed=23, vary=0.0)
    for sx in (-1, 1):
        eyes.blob((sx * 0.0072, -0.0275, 0.0068), 0.0026, subdiv=2, lump=0.0)
    eyes.build(smooth_angle=180)
    return [o for o in coll.objects if o.type == "MESH"]


def export_toy():
    objs = build_toy()
    path = os.path.join(OUT, "cat_toy.glb")
    os.makedirs(OUT, exist_ok=True)
    tris, n = SC.export_objects(objs, [], path, extra=[])
    mapping = SC.write_game_materials(only=list(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, path)
    os.makedirs(TEMPLATES, exist_ok=True)
    shutil.copyfile(path, os.path.join(TEMPLATES, "cat_toy.glb"))
    os.makedirs(SRC, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "cat_toy.blend"), compress=True)
    print("cat_toy: %d Dreiecke, %d Materialien" % (tris, n))


def export_birdhouse():
    objs, perches = build_birdhouse()
    path = os.path.join(OUT, "birdhouse.glb")
    os.makedirs(OUT, exist_ok=True)
    tris, n = SC.export_objects(objs, [], path, extra=perches)
    names = list(SC.LAST_EXPORT_MATERIALS)
    mapping = SC.write_game_materials(only=names)
    SC.write_import_settings(mapping, path)
    os.makedirs(TEMPLATES, exist_ok=True)
    shutil.copyfile(path, os.path.join(TEMPLATES, "birdhouse.glb"))
    os.makedirs(SRC, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "birdhouse.blend"), compress=True)
    print("birdhouse: %d Dreiecke, %d Materialien" % (tris, n))


# ---------------------------------------------------------------------------------------------
# Export, Kontrollbilder
# ---------------------------------------------------------------------------------------------

def export(a, M):
    name = a.name
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    a.arm.select_set(True)
    a.mesh.select_set(True)
    bpy.context.view_layer.objects.active = a.arm
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=True, export_nla_strips=True, export_force_sampling=True,
                              export_colors=True, export_extras=True, export_apply=False, export_yup=True,
                              export_lights=False, export_cameras=False, export_image_format="NONE")
    names = [m.name for m in a.mesh.data.materials]
    mapping = SC.write_game_materials(only=names)
    animal_shader(names)
    SC.write_import_settings(mapping, path)
    os.makedirs(TEMPLATES, exist_ok=True)
    gd = os.path.join(os.path.dirname(TEMPLATES), ".gdignore")
    if not os.path.exists(gd) and not os.path.exists(os.path.join(TEMPLATES, ".gdignore")):
        open(os.path.join(TEMPLATES, ".gdignore"), "w").close()
    shutil.copyfile(path, os.path.join(TEMPLATES, name + ".glb"))
    os.makedirs(SRC, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, name + ".blend"), compress=True)
    tris = sum(len(p.vertices) - 2 for p in a.mesh.data.polygons)
    print("%s: %d Dreiecke, %d Knochen, Bewegungen: %s" % (name, tris, len(a.arm.data.bones),
                                                         ", ".join(t.name for t in a.arm.animation_data.nla_tracks)))


def render_poses(name, poses):
    """Kontrollbilder aus der gespeicherten .blend (frisch geladen): je Haltung vorn, Seite, oben."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(SRC, name + ".blend"))
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    mesh = [o for o in bpy.data.objects if o.type == "MESH"][0]
    SC.setup_render(True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    floor = bpy.data.meshes.new("Boden")
    floor.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)])
    sc.collection.objects.link(bpy.data.objects.new("Boden", floor))
    size = max(mesh.dimensions)
    os.makedirs(SHOTS, exist_ok=True)
    SC.SHOTS = SHOTS
    for pose, frame in poses:
        for t in arm.animation_data.nla_tracks:
            t.mute = t.name != pose
        for pb in arm.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
        sc.frame_set(frame)
        for view, d in (("vorn", Vector((0.9, -1.6, 0.7))), ("seite", Vector((1.8, 0.1, 0.5))), ("oben", Vector((0.3, -0.5, 1.9)))):
            tgt = Vector((0, 0, size * 0.3))
            cam = d * size * 1.25 + tgt
            SC.render("%s_%s_%d_%s" % (name, pose or "ruhe", frame, view), tuple(cam), tuple(tgt), 50, (640, 480))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [n for n in argv if not n.startswith("--")] or ["bird", "cat", "birdhouse", "cat_toy"]
    for name in names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        SC.GAME_MATERIALS.clear()
        if name == "cat_toy":
            export_toy()
            if "--render" in argv:
                SC.setup_render(True)
                os.makedirs(SHOTS, exist_ok=True)
                SC.SHOTS = SHOTS
                SC.render("cat_toy", (0.12, -0.16, 0.1), (0, 0.01, 0.0), 50, (480, 480))
            continue
        if name == "birdhouse":
            export_birdhouse()
            if "--render" in argv:
                SC.setup_render(True)
                os.makedirs(SHOTS, exist_ok=True)
                SC.SHOTS = SHOTS
                SC.render("birdhouse_vorn", (0.35, -0.7, 0.25), (0, -0.1, 0.0), 50, (640, 640))
                SC.render("birdhouse_seite", (0.75, -0.25, 0.05), (0, -0.1, 0.0), 50, (640, 640))
                SC.render("birdhouse_unten", (0.25, -0.6, -0.45), (0, -0.1, -0.05), 50, (640, 640))
            continue
        a, M = build_bird() if name == "bird" else build_cat()
        export(a, M)
        if "--render" in argv:
            poses = [("", 0), ("idle", 24), ("peck", 8), ("hop", 6), ("fly", 0), ("fly", 4)] if name == "bird" else \
                [("", 0), ("walk", 6), ("sit", 0), ("lie", 0), ("sleep", 0), ("groom", 6), ("stretch", 30), ("pet", 0),
                 ("run", 3)]
            render_poses(name, poses)


if __name__ == "__main__":
    main()
