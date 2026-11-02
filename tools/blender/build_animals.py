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
import animal_birds as AB  # noqa: E402
import animal_cat as ACAT  # noqa: E402
import animal_cat_anim as ACA  # noqa: E402

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


def assemble(name, parts, bones, coll):
    """Netz aus animal_lib.Parts + Skelett (Knochen: [(Name, Kopf, Ende, Eltern)]) – wie Animal.build für die
    weichen Tiere (seit Etappe 6h)."""
    mesh = parts.build(name, coll)
    arm_data = bpy.data.armatures.new(name + " Skelett")
    arm = bpy.data.objects.new(name + " Skelett", arm_data)
    coll.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, head, tail, parent in bones:
        eb = arm_data.edit_bones.new(bname)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.roll = 0.0
        if parent:
            eb.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh.parent = arm
    mod = mesh.modifiers.new("Skelett", "ARMATURE")
    mod.object = arm
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"

    class Holder:
        pass
    a = Holder()
    a.name, a.mesh, a.arm = name, mesh, arm
    return a


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

def bird_materials(kind="bird"):
    """Materialien der Vögel. Das Spiel färbt sie je Art (GameConfig.bird_species bzw. pigeon_looks): Gefieder =
    Grundfarbe + Brust (zweite Farbe) + Kappe/Hals (dritte Farbe) über die Maske im Netz."""
    if kind == "pigeon":
        return {
            "plumage": SC.make_material("Taube Gefieder", (0.55, 0.58, 0.64), grain="smooth", rough=0.8, vary=0.05),
            "wing": SC.make_material("Taube Flügel", (0.5, 0.53, 0.58), grain="smooth", rough=0.8, vary=0.07),
            "beak": SC.make_material("Taube Schnabel", (0.25, 0.22, 0.22), grain="smooth", rough=0.6, vary=0.03),
            "eye": SC.make_material("Taube Auge", (0.6, 0.25, 0.08), grain="smooth", rough=0.15, vary=0.0),
            "leg": SC.make_material("Taube Beine", (0.75, 0.35, 0.35), grain="smooth", rough=0.6, vary=0.03),
        }
    return {
        "plumage": SC.make_material("Vogel Gefieder", (0.55, 0.42, 0.3), grain="smooth", rough=0.85, vary=0.05),
        "wing": SC.make_material("Vogel Flügel", (0.42, 0.3, 0.2), grain="smooth", rough=0.85, vary=0.06),
        "beak": SC.make_material("Vogel Schnabel", (0.35, 0.3, 0.26), grain="smooth", rough=0.6, vary=0.03),
        "eye": SC.make_material("Vogel Auge", (0.03, 0.025, 0.02), grain="smooth", rough=0.15, vary=0.0),
        "leg": SC.make_material("Vogel Beine", (0.62, 0.48, 0.42), grain="smooth", rough=0.7, vary=0.03),
    }


def build_bird(kind="bird"):
    """Singvogel („bird“, etwa 14 cm) oder Taube („pigeon“, etwa 32 cm) im weichen Stil (animal_birds.py)."""
    M = bird_materials(kind)
    spec = AB.SONGBIRD if kind == "bird" else AB.PIGEON
    coll = SB.collection(kind)
    parts, bones = AB.build(spec, M, coll)
    a = assemble(kind, parts, bones, coll)
    arm = a.arm
    s = 1.0 if kind == "bird" else 2.3
    tuck = [("x", 70)]
    # Ruhe: umschauen (kurze, ruckartige Kopfdrehungen), Schwanz wippt
    action(arm, "idle", 72, {
        0: {"head": [], "tail": []},
        10: {"head": [("z", 30)]},
        22: {"head": [("z", 30), ("x", 6)], "tail": [("x", 14)]},
        26: {"tail": []},
        34: {"head": []},
        46: {"head": [("z", -34)]},
        56: {"head": [("z", -34), ("y", 10)]},
        64: {"head": []},
    })
    # Picken: Körper kippt nach vorn, Kopf schnell zweimal hinunter
    action(arm, "peck", 24, {
        0: {"body": [], "head": []},
        5: {"body": [("x", 26)], "head": [("x", 30)]},
        8: {"body": [("x", 28)], "head": [("x", 50)]},
        11: {"body": [("x", 26)], "head": [("x", 26)]},
        14: {"body": [("x", 28)], "head": [("x", 52)]},
        19: {"body": [("x", 8)], "head": [("x", 6)]},
    })
    # Hüpfen (Singvogel): ganzer Körper springt, Beine falten sich, Flügel heben sich kurz
    action(arm, "hop", 12, {
        0: {"root": {"rot": [], "loc": (0, 0, 0)}},
        3: {"root": {"rot": [], "loc": (0, 0, 0.018 * s)}, "leg_l": [("x", 22)], "leg_r": [("x", 22)], "tail": [("x", 12)]},
        6: {"root": {"rot": [], "loc": (0, 0, 0.026 * s)}, "leg_l": [("x", 30)], "leg_r": [("x", 30)], "tail": [("x", 16)]},
        9: {"root": {"rot": [], "loc": (0, 0, 0.01 * s)}, "leg_l": [("x", 8)], "leg_r": [("x", 8)], "tail": [("x", 4)]},
    })
    # Gehen (Taube): Beine abwechselnd, Kopf nickt vor und zurück (Kopf bleibt stehen, während der Körper aufholt)
    action(arm, "walk", 20, {
        0: {"leg_l": [("x", -24)], "leg_r": [("x", 22)], "head": {"rot": [], "loc": (0, -0.016 * s, 0)},
            "body": [("y", 3)], "root": {"rot": [], "loc": (0, 0, 0.002 * s)}},
        5: {"leg_l": [], "leg_r": [], "head": {"rot": [], "loc": (0, 0.012 * s, 0)}, "body": [],
            "root": {"rot": [], "loc": (0, 0, 0)}},
        10: {"leg_l": [("x", 22)], "leg_r": [("x", -24)], "head": {"rot": [], "loc": (0, -0.016 * s, 0)},
             "body": [("y", -3)], "root": {"rot": [], "loc": (0, 0, 0.002 * s)}},
        15: {"leg_l": [], "leg_r": [], "head": {"rot": [], "loc": (0, 0.012 * s, 0)}, "body": [],
             "root": {"rot": [], "loc": (0, 0, 0)}},
    })
    # Flügelschlag (mit ausgebreiteten Flügeln – Formvariante „spread“ setzt das Spiel): Spitze schwingt nach
    up_l, up_r = [("y", -52)], [("y", 52)]
    down_l, down_r = [("y", 42)], [("y", -42)]
    action(arm, "fly", 10, {
        0: {"wing_l": up_l, "wing_r": up_r, "wingtip_l": [("y", 12)], "wingtip_r": [("y", -12)], "leg_l": tuck,
            "leg_r": tuck, "tail": [("x", -6)], "head": [("x", -8)], "body": [("x", -4)]},
        5: {"wing_l": down_l, "wing_r": down_r, "wingtip_l": [("y", -20)], "wingtip_r": [("y", 20)], "leg_l": tuck,
            "leg_r": tuck, "tail": [("x", -2)], "head": [("x", -8)], "body": [("x", -1)]},
    })
    # Gleiten: Flügel ruhig ausgebreitet, leicht nach oben (V-Form)
    action(arm, "glide", 40, {
        0: {"wing_l": [("y", -8)], "wing_r": [("y", 8)], "wingtip_l": [("y", -4)], "wingtip_r": [("y", 4)],
            "leg_l": tuck, "leg_r": tuck, "tail": [("x", -4)], "head": [("x", -8)]},
        20: {"wing_l": [("y", -3)], "wing_r": [("y", 3)], "wingtip_l": [("y", -1)], "wingtip_r": [("y", 1)],
             "leg_l": tuck, "leg_r": tuck, "tail": [("x", -8)], "head": [("x", -6)]},
    })
    # Abheben: ducken, abspringen, erste kräftige Schläge
    action(arm, "takeoff", 12, {
        0: {"body": [("x", 18)], "leg_l": [("x", 25)], "leg_r": [("x", 25)], "wing_l": [("y", -30)], "wing_r": [("y", 30)],
            "root": {"rot": [], "loc": (0, 0, -0.004 * s)}},
        3: {"body": [("x", -10)], "leg_l": [("x", -15)], "leg_r": [("x", -15)], "wing_l": up_l, "wing_r": up_r,
            "wingtip_l": [("y", 10)], "wingtip_r": [("y", -10)], "root": {"rot": [], "loc": (0, 0, 0.01 * s)}},
        7: {"body": [("x", -14)], "leg_l": tuck, "leg_r": tuck, "wing_l": down_l, "wing_r": down_r,
            "wingtip_l": [("y", -18)], "wingtip_r": [("y", 18)], "root": {"rot": [], "loc": (0, 0, 0.012 * s)}},
        11: {"body": [("x", -6)], "leg_l": tuck, "leg_r": tuck, "wing_l": up_l, "wing_r": up_r,
             "root": {"rot": [], "loc": (0, 0, 0.0)}},
    }, loop=False)
    # Landen: Körper aufgerichtet, Flügel bremsen (nach vorn oben), Schwanz gefächert nach unten, Beine vor
    action(arm, "land", 12, {
        0: {"body": [("x", -30)], "wing_l": [("y", -40), ("z", -18)], "wing_r": [("y", 40), ("z", 18)],
            "wingtip_l": [("y", -10)], "wingtip_r": [("y", 10)], "tail": [("x", 28)], "leg_l": [("x", -35)],
            "leg_r": [("x", -35)], "head": [("x", 12)]},
        5: {"body": [("x", -34)], "wing_l": [("y", 10), ("z", -24)], "wing_r": [("y", -10), ("z", 24)],
            "tail": [("x", 30)], "leg_l": [("x", -30)], "leg_r": [("x", -30)], "head": [("x", 14)]},
        11: {"body": [("x", -8)], "wing_l": [("y", -20)], "wing_r": [("y", 20)], "tail": [("x", 10)],
             "leg_l": [], "leg_r": [], "head": [("x", 4)]},
    }, loop=False)
    return a, M


# ---------------------------------------------------------------------------------------------
# Katze (etwa 45 cm lang, großer runder Kopf wie die Chibi-Figuren)
# ---------------------------------------------------------------------------------------------

def cat_materials():
    """Materialien der Katze. Das Spiel färbt sie je Katze (GameConfig.cat_looks): Fell = Grundfarbe, helles
    Fell (Maske > 0, ab mask_from) und dunkler Rücken (Maske < 0) im selben Material, Tigerstreifen im Shader."""
    return {
        "fur": SC.make_material("Katze Fell", (0.85, 0.5, 0.24), grain="smooth", rough=0.95, vary=0.07),
        "ear": SC.make_material("Katze Ohr innen", (0.9, 0.62, 0.62), grain="smooth", rough=0.8, vary=0.03),
        "nose": SC.make_material("Katze Nase", (0.86, 0.5, 0.52), grain="smooth", rough=0.6, vary=0.03),
        "eye": SC.make_material("Katze Auge", (0.45, 0.62, 0.22), grain="smooth", rough=0.12, vary=0.0),
        "pupil": SC.make_material("Katze Pupille", (0.03, 0.025, 0.02), grain="smooth", rough=0.1, vary=0.0),
        "shine": SC.make_material("Katze Glanz", (0.98, 0.97, 0.95), grain="smooth", rough=0.1, vary=0.0),
        "mouth": SC.make_material("Katze Mund", (0.25, 0.14, 0.12), grain="smooth", rough=0.7, vary=0.0),
    }


def build_cat(only=None):
    """Katze im weichen Stil (animal_cat.py) mit eigenem Skelett und Bewegungen (animal_cat_anim.py)."""
    M = cat_materials()
    coll = SB.collection("cat")
    parts, bones = ACAT.build(M, coll)
    a = assemble("cat", parts, bones, coll)
    ACA.build_all(a.arm, only)
    return a, M


# ---------------------------------------------------------------------------------------------
# Vogelhäuschen (an einer Hauswand, mit Futterbrett)
# ---------------------------------------------------------------------------------------------

def build_birdhouse():
    """Vogelhäuschen zum Anschrauben: Rückenbrett an der Wand (zwei Schrauben), darunter zwei Winkelstützen,
    darauf das Futterbrett mit Rand und Körnern, hinten auf dem Brett das Häuschen (Giebel, Dach aus zwei
    Brettern mit Firstleiste, Flugloch, Sitzstange). Ursprung = Mitte des Rückenbretts auf der Wand, vorn = -y.
    Plätze für Vögel: leere Objekte „Perch_<n>“ mit extras kind = feed (Seitenrand, picken), rim (Rand vorn),
    roof (First) und face = in (zur Mitte), out (nach vorn), along (längs). Die Sitzstange ist nur Schmuck."""
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
    wood.box((0, -0.01, z0 + 0.065), (0.3, 0.02, 0.43), step=0.05, dent=0.001)
    # Futterbrett (liegt auf den Stützen, hinten am Rückenbrett)
    tray_front = -0.27
    tray_half = 0.18
    wood.box((0, (back + tray_front) / 2, z0 - 0.008), (tray_half * 2, back - tray_front, 0.016), step=0.05, dent=0.001)
    # Rand vorn und an den Seiten (auf dem Brett)
    wood.box((0, tray_front + 0.006, z0 + 0.011), (tray_half * 2, 0.012, 0.022), step=0.05, dent=0.0005)
    for sx in (-1, 1):
        wood.box((sx * (tray_half - 0.006), (back + tray_front) / 2, z0 + 0.011), (0.012, back - tray_front - 0.002, 0.022),
                 step=0.05, dent=0.0005)
    # Winkelstützen unter dem Brett (Dreiecke in der Seitenebene, Dicke 12 mm)
    side = Matrix(((0, 0, -1, 0), (-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    for sx in (-1, 1):
        m = Matrix.Translation((sx * 0.11 + 0.006, back, z0 - 0.016)) @ side
        wood.slab([(0.0, 0.0), (0.0, -0.13), (0.2, 0.0)], 0.012, m, dent=0.0005)
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
    for x, z in ((-0.115, z0 + 0.25), (0.115, z0 + 0.25), (-0.065, z0 - 0.125), (0.065, z0 - 0.125)):
        screws.blob((x, back + 0.001, z), 0.0065, subdiv=2, lump=0.0, scale=(1, 0.4, 1))
    screws.build(smooth_angle=180)
    # Körner auf dem Brett vor dem Häuschen
    seeds = Body("Körner", M["seed"], coll, seed=12, vary=0.0)
    for k in range(46):
        x = rnd.uniform(-0.15, 0.15)
        y = rnd.uniform(tray_front + 0.02, house_front - 0.01)
        seeds.blob((x, y, z0 + 0.0025), rnd.uniform(0.0035, 0.005), subdiv=1, lump=0.1, scale=(1.3, 0.8, 0.55))
    seeds.build(smooth_angle=180)
    # Plätze für Vögel – so verteilt, dass sich vier Vögel nie berühren und keiner in die Wand ragt: an den
    # Seitenrändern nach innen (picken Körner), vorn auf dem Rand nach draußen, auf dem First längs
    perches = []
    side_y = (tray_front + house_front) / 2 - 0.01
    for name, pos, kind, face in (("Perch_1", (-(tray_half - 0.006), side_y, z0 + 0.022), "feed", "in"),
                                  ("Perch_2", (tray_half - 0.006, side_y, z0 + 0.022), "feed", "in"),
                                  ("Perch_3", (0.0, tray_front + 0.006, z0 + 0.022), "rim", "out"),
                                  ("Perch_4", (0.0, (back + depth_front) / 2, z0 + 0.261), "roof", "along")):
        e = bpy.data.objects.new(name, None)
        e.location = pos
        e["kind"] = kind
        e["face"] = face
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


def build_more_toys():
    """Weitere Spielzeuge (seit Etappe 6h): Wollknäuel (gewickelte Fäden auf einer Kugel, ein loses Fadenende),
    Federbüschel (kleiner Korken mit drei Federn) und Ball (weich, zweifarbig). Ursprung = Mitte, liegen mit
    dem Boden bei −Radius (im Spiel 1,5 cm über dem Boden abgelegt)."""
    rnd = random.Random(8)
    result = {}
    # Wollknäuel: Kugel + gewickelte Fadenringe darauf (schräg in mehreren Richtungen)
    M = {"wool": SC.make_material("Spielzeug Wolle", (0.82, 0.32, 0.36), grain="fabric", rough=0.95, vary=0.06),
         "cork": SC.make_material("Spielzeug Korken", (0.72, 0.56, 0.38), grain="wood", rough=0.9, vary=0.1),
         "feather": SC.make_material("Spielzeug Feder", (0.35, 0.62, 0.82), grain="smooth", rough=0.8, vary=0.08),
         "feather2": SC.make_material("Spielzeug Feder hell", (0.95, 0.85, 0.4), grain="smooth", rough=0.8, vary=0.08),
         "ball": SC.make_material("Spielzeug Ball", (0.95, 0.75, 0.25), grain="smooth", rough=0.6, vary=0.04),
         "ball2": SC.make_material("Spielzeug Ball Streifen", (0.3, 0.6, 0.85), grain="smooth", rough=0.6, vary=0.04)}
    coll = SB.collection("toy_yarn")
    r = 0.022
    wool = Body("Wolle", M["wool"], coll, seed=61, vary=0.0)
    wool.blob((0, 0, 0), r * 0.94, subdiv=3, lump=0.02)
    for k in range(9):
        axis = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized()
        u = axis.orthogonal().normalized()
        v = axis.cross(u)
        pts = [(u * math.cos(t) + v * math.sin(t)) * r for t in [i / 24 * math.tau for i in range(26)]]
        wool.tube(pts, 0.0024, segs=6, round_ends=True)
    # loses Fadenende, das auf dem Boden liegt
    wool.tube([Vector((0.0, -r * 0.9, -r * 0.3)), Vector((0.006, -r * 1.6, -r * 0.88)), Vector((0.02, -r * 2.6, -r * 0.92)),
               Vector((0.035, -r * 3.2, -r * 0.92))], 0.0018, segs=6, smooth=2, round_ends=True)
    wool.build(smooth_angle=180)
    result["toy_yarn"] = coll
    # Federbüschel: Korken mit drei Federn (je ein Kiel und eine Fahne aus zwei Blättern)
    coll = SB.collection("toy_feather")
    cork = Body("Korken", M["cork"], coll, seed=62, vary=0.0, bevel=0.002)
    cork.lathe([(0.0, -0.012), (0.011, -0.012), (0.012, 0.012), (0.0, 0.012)], (0, 0, 0), segs=18, turn=(90, 0))
    cork.build(smooth_angle=40)
    for k, (yaw, mat) in enumerate(((0, "feather"), (22, "feather2"), (-22, "feather"))):
        f = Body("Feder", M[mat], coll, seed=63 + k, vary=0.0)
        d = Vector((math.sin(math.radians(yaw)), 1.0, 0.25)).normalized()
        base = Vector((0, 0.008, 0))
        f.tube([base, base + d * 0.075], lambda t: 0.0016 * (1 - t) + 0.0006, segs=6, round_ends=True)
        f.leaf(base + d * 0.012, d, Vector((0, -0.25, 1)), 0.068, 0.022, shape="oval", thick=0.0016, curl=0.1)
        f.build(smooth_angle=180)
    result["toy_feather"] = coll
    # Ball: weich, mit einem farbigen Ring
    coll = SB.collection("toy_ball")
    ball = Body("Ball", M["ball"], coll, seed=66, vary=0.0)
    ball.blob((0, 0, 0), 0.02, subdiv=3, lump=0.0)
    ball.build(smooth_angle=180)
    ring = Body("Streifen", M["ball2"], coll, seed=67, vary=0.0)
    pts = [Vector((math.cos(t) * 0.0198, math.sin(t) * 0.0198, 0.0)) for t in [i / 30 * math.tau for i in range(32)]]
    ring.tube(pts, 0.0035, segs=8)
    ring.build(smooth_angle=180)
    result["toy_ball"] = coll
    return result


def export_more_toys():
    for name, coll in build_more_toys().items():
        objs = [o for o in coll.objects if o.type == "MESH"]
        path = os.path.join(OUT, name + ".glb")
        tris, n = SC.export_objects(objs, [], path, extra=[])
        mapping = SC.write_game_materials(only=list(SC.LAST_EXPORT_MATERIALS))
        SC.write_import_settings(mapping, path)
        shutil.copyfile(path, os.path.join(TEMPLATES, name + ".glb"))
        print("%s: %d Dreiecke" % (name, tris))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "toys.blend"), compress=True)


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
                              export_morph=True, export_morph_normal=True,
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
        # Flügel ausbreiten (Formvariante „spread“), wie im Spiel beim Fliegen
        keys = mesh.data.shape_keys
        if keys and "spread" in keys.key_blocks:
            keys.key_blocks["spread"].value = 1.0 if pose in ("fly", "glide", "takeoff", "land") else 0.0
        sc.frame_set(frame)
        for view, d in (("vorn", Vector((0.9, -1.6, 0.7))), ("seite", Vector((1.8, 0.1, 0.5))), ("oben", Vector((0.3, -0.5, 1.9)))):
            tgt = Vector((0, 0, size * 0.3))
            cam = d * size * 1.25 + tgt
            SC.render("%s_%s_%d_%s" % (name, pose or "ruhe", frame, view), tuple(cam), tuple(tgt), 50, (640, 480))


def render_sequences(name, anims, count=8, views=("seite",)):
    """Bewegungen als Einzelbilder hintereinander (zum Prüfen, ob sie natürlich aussehen): je Bewegung count Bilder
    gleichmäßig verteilt, Ansicht von der Seite (und schräg vorn). Dateien <tier>_seq_<bewegung>_<ansicht>_<n>.png."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(SRC, name + ".blend"))
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    mesh = [o for o in bpy.data.objects if o.type == "MESH"][0]
    SC.setup_render(True)
    sc = bpy.context.scene
    sc.cycles.samples = 24
    floor = bpy.data.meshes.new("Boden")
    floor.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)])
    sc.collection.objects.link(bpy.data.objects.new("Boden", floor))
    os.makedirs(SHOTS, exist_ok=True)
    SC.SHOTS = SHOTS
    size = max(mesh.dimensions)
    cams = {"seite": Vector((1.7, -0.15, 0.35)), "vorn": Vector((0.8, -1.5, 0.55)), "oben": Vector((0.5, 0.6, 1.7))}
    for anim in anims:
        track = arm.animation_data.nla_tracks.get(anim)
        if track is None:
            continue
        for t in arm.animation_data.nla_tracks:
            t.mute = t.name != anim
        strip = track.strips[0]
        length = int(strip.frame_end)
        for k in range(count):
            frame = round(k * length / max(1, count - (0 if anim in LOOPING else 1)))
            sc.frame_set(min(frame, length))
            for view in views:
                tgt = Vector((0, -0.03, 0.06 if anim in ("sleep", "lie") else 0.14))
                cam = cams[view].normalized() * size * 1.7 + tgt
                SC.render("%s_seq_%s_%s_%d" % (name, anim, view, k), tuple(cam), tuple(tgt), 45, (360, 300))


LOOPING = {"idle", "walk", "run", "sit", "groom", "pet", "lie", "sleep", "crouch", "stalk", "sniff", "bat", "fly", "glide", "peck",
           "hop"}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [n for n in argv if not n.startswith("--")] or ["bird", "pigeon", "cat", "birdhouse", "cat_toy", "toys"]
    for name in names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        SC.GAME_MATERIALS.clear()
        if name == "toys":
            os.makedirs(OUT, exist_ok=True)
            os.makedirs(TEMPLATES, exist_ok=True)
            export_more_toys()
            if "--render" in argv:
                SC.setup_render(True)
                SC.SHOTS = SHOTS
                SC.render("toys", (0.0, -0.3, 0.16), (0, 0.0, 0.0), 50, (640, 400))
            continue
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
        only = None
        for arg in argv:
            if arg.startswith("--only="):
                only = arg[7:].split(",")
        a, M = build_bird(name) if name in ("bird", "pigeon") else build_cat(only)
        export(a, M)
        views = ("seite", "vorn")
        for arg in argv:
            if arg.startswith("--seqview="):
                views = tuple(arg[10:].split(","))
        for arg in argv:
            if arg.startswith("--seq="):
                render_sequences(name, arg[6:].split(","), views=views)
        if "--render" in argv:
            poses = [("", 0), ("idle", 24), ("peck", 8), ("walk", 0), ("fly", 0), ("fly", 5), ("land", 5),
                     ("takeoff", 7)] if name in ("bird", "pigeon") else \
                [("", 0), ("walk", 6), ("sit", 0), ("lie", 0), ("sleep", 0), ("groom", 6), ("stretch", 30), ("pet", 0),
                 ("run", 3)]
            render_poses(name, poses)


if __name__ == "__main__":
    main()
