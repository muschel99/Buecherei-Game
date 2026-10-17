"""Chibi-Figuren (seit Etappe 5c): Grundkörper ("Mannequins") für Frauen und Männer in drei Größen,
je mit den Formreglern "thin" und "fat", Unterwäsche (Bandeau + Slip bzw. Boxershorts), Skelett
mit Namen wie Godots SkeletonProfileHumanoid, gezeichnetes Gesicht (Material "face").

Aufruf:
  blender -b --factory-startup --python tools/blender/build_chibi.py -- [Optionen]
    --only female_medium,male_medium   nur diese Figuren
    --render                           Kontrollbilder nach screenshots/blender/chibi/
    --no-export                        nichts schreiben (nur ansehen)

Ausgabe: assets/models/characters/chibi/<gender>_<größe>.glb, .blend-Quellen in
assets/models/source/characters/chibi/, Mixamo-Dateien in assets/models/characters/chibi/mixamo/.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import numpy as np  # noqa: E402

import character_lib as C  # noqa: E402  (numpy-Kniff, Export, Kontrollbilder)
import chibi_face as F  # noqa: E402
import chibi_sdf as S  # noqa: E402
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

ROOT = C.ROOT
OUT_DIR = os.path.join(ROOT, "assets", "models", "characters", "chibi")
SOURCE_DIR = os.path.join(ROOT, "assets", "models", "source", "characters", "chibi")
SHOT_DIR = os.path.join(ROOT, "screenshots", "blender", "chibi")

GRID = 0.003           # Rasterweite des Feldes (m)
BODY_TRIS = 26000      # Dreiecke des Körpers nach dem Ausdünnen
ZONE_DENSITY = 3.0     # Biegestellen (Gelenke) bekommen so viel mehr Dreiecke je Fläche

SKIN = (0.95, 0.80, 0.68)
CLOTH = (0.90, 0.89, 0.87)   # aufgemalte Unterwäsche (hellgrau-weiß)


# ---------------------------------------------------------------------------------------------
# Netz
# ---------------------------------------------------------------------------------------------

def mesh_from_arrays(name, verts, faces):
    me = bpy.data.meshes.new(name)
    n = len(faces[0])
    me.vertices.add(len(verts))
    me.vertices.foreach_set("co", np.asarray(verts, np.float32).ravel())
    me.loops.add(len(faces) * n)
    me.loops.foreach_set("vertex_index", np.asarray(faces, np.int32).ravel())
    me.polygons.add(len(faces))
    me.polygons.foreach_set("loop_start", np.arange(0, len(faces) * n, n, dtype=np.int32))
    me.polygons.foreach_set("loop_total", np.full(len(faces), n, np.int32))
    me.update(calc_edges=True)
    me.validate()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def coords(obj):
    me = obj.data
    a = np.zeros(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", a)
    return a.reshape(-1, 3).astype(np.float64)


def set_coords(obj, p):
    obj.data.vertices.foreach_set("co", np.asarray(p, np.float32).ravel())
    obj.data.update()


def _decimate_pass(obj, ratio, keep_mask=None):
    """Ein Ausdünn-Durchgang; Ecken mit keep_mask bleiben unverändert."""
    m = obj.modifiers.new("Decimate", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = min(1.0, max(ratio, 0.0001))
    m.use_symmetry = True
    m.symmetry_axis = "X"
    if keep_mask is not None:
        vg = obj.vertex_groups.new(name="keep")
        vg.add([int(i) for i in np.nonzero(keep_mask)[0]], 1.0, "REPLACE")
        # Gewicht 1 würde stärker ausdünnen – umgekehrt bleibt die Gruppe stehen
        m.vertex_group = vg.name
        m.invert_vertex_group = True
        m.vertex_group_factor = 1000.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=m.name)
    if keep_mask is not None:
        obj.vertex_groups.remove(obj.vertex_groups["keep"])


def _zone_mask(obj, protect):
    p = coords(obj)
    mask = np.zeros(len(p), bool)
    for c, r in protect:
        mask |= np.linalg.norm(p - np.asarray(c), axis=1) < r
    return mask


def _tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def decimate(obj, tris, protect=None):
    """Ausdünnen auf etwa tris Dreiecke. protect = Liste (Punkt, Radius): Biegestellen (Gelenke)
    bekommen ein ZONE_DENSITY-mal so dichtes Netz (sonst knickt die Haut dort beim Animieren)."""
    total = _tris(obj)
    if not protect:
        _decimate_pass(obj, tris / max(total, 1))
        return
    zone = _zone_mask(obj, protect)
    share = zone.mean()
    rest_target = tris * (1.0 - share)
    zone_target = tris * share * ZONE_DENSITY
    # 1. alles außer den Biegestellen
    zone_faces = total * share
    _decimate_pass(obj, (zone_faces + rest_target) / total, zone)
    # 2. die Biegestellen (der Rest bleibt stehen)
    zone = _zone_mask(obj, protect)
    now = _tris(obj)
    rest_now = now - now * zone.mean()
    _decimate_pass(obj, (rest_now + zone_target) / now, ~zone)


def surface_object(name, node, lo, hi, tris, keep=None, protect=None):
    """Netz der Oberfläche eines Feldes, ausgedünnt und genau auf die Oberfläche gesetzt.
    keep(p) = welche Flächen bleiben (Mittelpunkte)."""
    v, q = S.surface_nets(node, lo, hi, GRID)
    v = S.project(node, v, 3)
    if keep is not None:
        centers = v[q].mean(axis=1)
        q = q[keep(centers)]
        used = np.unique(q)
        remap = np.full(len(v), -1, np.int64)
        remap[used] = np.arange(len(used))
        v = v[used]
        q = remap[q]
    obj = mesh_from_arrays(name, v, q)
    decimate(obj, tris, protect)
    set_coords(obj, S.project(node, coords(obj), 4))
    fix_folds(obj, node)
    return obj


def fix_folds(obj, node, rounds=8):
    """Umgeklappte Dreiecke (vom Ausdünnen) glätten: Ecken der Fläche und ihre Nachbarn in die
    Mitte ihrer Nachbarn setzen und wieder auf die Oberfläche schieben."""
    for _ in range(rounds):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        bm.normal_update()
        centers = np.array([f.calc_center_median() for f in bm.faces])
        fn = np.array([f.normal for f in bm.faces])
        g = S.normals(node, centers)
        bad = np.nonzero((fn * g).sum(axis=1) < 0.35)[0]
        if len(bad) == 0:
            bm.free()
            return
        if _ >= rounds // 2:
            # hartnäckige Stellen (winzige Dreiecke an Fingerspitzen): kürzeste Kante zusammenlegen
            edges = set()
            for i in bad:
                f = bm.faces[int(i)]
                edges.add(min(f.edges, key=lambda e: e.calc_length()))
            bmesh.ops.collapse(bm, edges=list(edges), uvs=False)
            bm.to_mesh(obj.data)
            bm.free()
            set_coords(obj, S.project(node, coords(obj), 4))
            continue
        verts = set()
        for i in bad:
            for v in bm.faces[int(i)].verts:
                verts.add(v)
                for e in v.link_edges:
                    verts.add(e.other_vert(v))
        moved = {}
        for v in verts:
            nb = [e.other_vert(v).co for e in v.link_edges]
            moved[v.index] = sum(nb, Vector()) / len(nb)
        idx = np.array(list(moved))
        pts = S.project(node, np.array([moved[i] for i in idx]), 6)
        for i, q in zip(idx, pts):
            bm.verts.ensure_lookup_table()
            bm.verts[int(i)].co = q
        bm.to_mesh(obj.data)
        bm.free()


def smooth_normals(obj, node):
    me = obj.data
    n = S.normals(node, coords(obj))
    me.use_auto_smooth = True
    me.auto_smooth_angle = math.pi
    for p in me.polygons:
        p.use_smooth = True
    me.normals_split_custom_set_from_vertices([tuple(x) for x in n])


def add_shape_keys(obj, plain, variants):
    """Formregler: dieselben Ecken auf die glatte Form (ohne Bauchnabel) der anderen Körperform
    schieben; Feinheiten (Nabel) wandern als Abstand zur glatten Form mit. Arme und Beine werden
    vorher so weit verschoben wie in der anderen Form (breitere Schultern, Lücke im Schritt)."""
    base = coords(obj)
    smooth = S.project(plain.root, base, 6)
    detail = base - smooth
    names, w = S.skin_weights(plain.root, smooth, plain.spine)
    obj.shape_key_add(name="Basis", from_mix=False)
    for name, other in variants.items():
        key = obj.shape_key_add(name=name, from_mix=False)
        p = S.project(other.root, smooth + limb_shift(names, w, other), 10) + detail
        key.data.foreach_set("co", p.astype(np.float32).ravel())
        key.value = 0.0


ARM_BONES = ("UpperArm", "LowerArm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little")
LEG_BONES = ("UpperLeg", "LowerLeg", "Foot", "Toes")


def limb_shift(names, w, other):
    """Arme und Beine (nach ihrem Gewicht) seitlich verschieben wie in der Form other."""
    out = np.zeros((len(w), 3))
    for i, n in enumerate(names):
        sign = 1.0 if n.startswith("Left") else -1.0
        if any(b in n for b in ARM_BONES):
            out[:, 0] += w[:, i] * other.arm_spread * sign
        elif n.endswith("Shoulder"):
            out[:, 0] += w[:, i] * other.arm_spread * sign * 0.5
        elif any(b in n for b in LEG_BONES):
            out[:, 0] += w[:, i] * other.leg_spread * sign
    return out


def add_ao(obj, node, strength=0.9):
    """Verschattung je Ecke als zweite Texturkoordinate "AO" (u = Helligkeit) – Vertex-Farben
    kommen beim glTF-Export von Blender 3.4 durcheinander."""
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    p = coords(obj)
    ao = S.ambient_occlusion(node, p, S.normals(node, p), strength=strength)
    layer = me.uv_layers.new(name="AO")
    li = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", li)
    uv = np.stack([ao[li], np.zeros(len(li))], axis=1)
    layer.data.foreach_set("uv", uv.astype(np.float32).ravel())


# ---------------------------------------------------------------------------------------------
# Skelett und Gewichte
# ---------------------------------------------------------------------------------------------

def make_armature(body, name="Skeleton"):
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for bname, head, tail, parent in body.bones():
        eb = arm.edit_bones.new(bname)
        eb.head = head
        eb.tail = tail
        if parent:
            eb.parent = made[parent]
            eb.use_connect = False
        made[bname] = eb
    # Rollen: Arme und Finger mit der Handfläche nach unten (z-Achse des Knochens nach oben)
    for eb in arm.edit_bones:
        if any(k in eb.name for k in ("Arm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little", "Shoulder")):
            eb.align_roll(Vector((0, 0, 1)))
        else:
            eb.align_roll(Vector((0, -1, 0)))
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def bind(obj, arm, body):
    """Gewichte aus den Grundformen: Eckpunkte zuerst auf den Körper schieben (Kleidung)."""
    p = coords(obj)
    on_body = S.project(body.root, p, 4)
    names, w = S.skin_weights(body.root, on_body, body.spine)
    for i, n in enumerate(names):
        idx = np.nonzero(w[:, i] > 0)[0]
        if len(idx) == 0:
            continue
        vg = obj.vertex_groups.new(name=n)
        for j in idx:
            vg.add([int(j)], float(w[j, i]), "REPLACE")
    obj.parent = arm
    m = obj.modifiers.new("Armature", "ARMATURE")
    m.object = arm


# ---------------------------------------------------------------------------------------------
# Materialien
# ---------------------------------------------------------------------------------------------

def principled(name, color, rough=0.5, ao=True, image=None, cloth=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular"].default_value = 0.35
    col = C.srgb(color) + (1.0,)
    bsdf.inputs["Base Color"].default_value = col
    mix = None
    if ao:
        uvn = nt.nodes.new("ShaderNodeUVMap")
        uvn.uv_map = "AO"
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(uvn.outputs["UV"], sep.inputs[0])
        attr = nt.nodes.new("ShaderNodeCombineXYZ")
        for c in "XYZ":
            nt.links.new(sep.outputs["X"], attr.inputs[c])
        mix = nt.nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[1].default_value = col
        nt.links.new(attr.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], bsdf.inputs["Base Color"])
        if cloth is not None:
            # Wäsche: wo UV2.y (Abstand zum Rand) negativ ist, mit scharfer Kante
            cov = nt.nodes.new("ShaderNodeMath")
            cov.operation = "MULTIPLY_ADD"
            cov.use_clamp = True
            nt.links.new(sep.outputs["Y"], cov.inputs[0])
            cov.inputs[1].default_value = -1500.0
            cov.inputs[2].default_value = 0.5
            paint = nt.nodes.new("ShaderNodeMixRGB")
            paint.inputs[1].default_value = col
            paint.inputs[2].default_value = C.srgb(cloth) + (1.0,)
            nt.links.new(cov.outputs[0], paint.inputs[0])
            nt.links.new(paint.outputs[0], mix.inputs[1])
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.extension = "EXTEND"
        nt.links.new(tex.outputs["Color"], mix.inputs[1] if mix else bsdf.inputs["Base Color"])
    return mat


# ---------------------------------------------------------------------------------------------
# Gesicht
# ---------------------------------------------------------------------------------------------

_ATLASES = {}


def atlases():
    if not _ATLASES:
        _ATLASES.update(F.build_atlases())
    return _ATLASES


def face_image(name, expression, gender, size=1024, shape=None):
    """Gesicht als Bild (für Blender und als Standard-Gesicht im .glb)."""
    img = F.compose(atlases(), expression, gender, size, skin=SKIN, shape=shape)
    im = bpy.data.images.get(name) or bpy.data.images.new(name, size, size, alpha=False)
    im.pixels.foreach_set(np.flipud(img).astype(np.float32).ravel())
    im.update()
    return im


def face_uv(obj, body):
    """Texturkoordinaten: Zylinder-Abwicklung um die Kopfachse (wie chibi_face.gdshader);
    vorn am Kopf bekommen die Flächen das Material "face"."""
    me = obj.data
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    li = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", li)
    p = coords(obj)[li]
    ang = np.arctan2(p[:, 0], -(p[:, 1] - F.FACE_AXIS_Y))
    fz = p[:, 2] - body.chin
    u = 0.5 + ang * F.FACE_RADIUS / F.FACE_SIZE
    v = fz / F.FACE_SIZE
    uv.data.foreach_set("uv", np.stack([u, v], axis=1).astype(np.float32).ravel())
    ok = (fz > -0.02) & (np.abs(ang) < math.radians(105))
    starts = np.zeros(len(me.polygons), np.int32)
    me.polygons.foreach_get("loop_start", starts)
    inside = np.minimum.reduceat(ok.astype(np.int8), starts) > 0
    me.polygons.foreach_set("material_index", inside.astype(np.int32))
    me.update()


# ---------------------------------------------------------------------------------------------
# Figur
# ---------------------------------------------------------------------------------------------

def bend_zones(body):
    """Stellen, die sich beim Animieren stark biegen: dort bleibt das Netz fein."""
    zones = []
    for side in ("Left", "Right"):
        a = body.joints_arm[side]
        sh = np.array(a["shoulder"])
        s = 1.0 if side == "Left" else -1.0
        zones += [(sh + np.array((-s * 0.03, 0.0, -0.06)), 0.07),   # Achsel und Brustseite
                  (sh + np.array((0.0, 0.0, 0.02)), 0.06),           # Schulter
                  (a["elbow"], 0.045), (a["wrist"], 0.035)]
        lg = body.joints_leg[side]
        zones += [(lg["hip"], 0.08), (lg["knee"], 0.05), (lg["ankle"], 0.04)]
    zones.append(((0.0, 0.02, body.neck_base), 0.05))
    return zones


def build(gender, height):
    bodies = {s: S.Body(gender, height, s) for s in S.SHAPES}
    plain = {s: S.Body(gender, height, s, navel=False) for s in S.SHAPES}
    body = bodies["medium"]
    lo, hi = body.bounds()
    arm = make_armature(body)
    obj = surface_object("Body", body.root, lo, hi, BODY_TRIS, protect=bend_zones(body))
    add_ao(obj, body.root, 0.5)
    smooth_normals(obj, body.root)
    add_shape_keys(obj, plain["medium"], {"thin": plain["thin"], "fat": plain["fat"]})
    obj.data.materials.append(principled("skin", SKIN, cloth=CLOTH))
    face_uv(obj, body)
    img = face_image(f"face_{gender}_{height}", "neutral", gender)
    obj.data.materials.append(principled("face", SKIN, image=img))
    bind(obj, arm, body)
    paint_underwear(obj, body)
    return arm, [obj], body


def paint_underwear(obj, body):
    """Unterwäsche aufmalen: Abstand zum Rand je Ecke in UV2.y (Shader zieht daraus die Kante)."""
    me = obj.data
    p = coords(obj)
    d = body.underwear_distance(p)
    # nur auf Haut, die beim Bewegen der Arme nicht mitdreht (sonst wandert die Ecke auf den Arm)
    # stufenlose Anteile (ungerundet), damit die Kante unter der Achsel eine saubere Linie wird
    names, w = S.skin_weights(body.root, S.project(body.root, p, 4), body.spine, raw=True)
    moving = sum(w[:, i] for i, n in enumerate(names)
                 if any(b in n for b in ARM_BONES) or n.endswith("Shoulder"))
    # nur in Armnähe wirken lassen (sonst würde der Rand von Slip/Hose verbogen)
    d = np.maximum(d, np.where(moving > 0.001, moving - 0.012, -1.0))
    layer = me.uv_layers["AO"]
    li = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", li)
    uv = np.zeros(len(li) * 2, np.float32)
    layer.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    uv[:, 1] = d[li]
    layer.data.foreach_set("uv", uv.ravel())


RELAX_ANGLE = 57.0   # Kontrollbilder: Arme so viel Grad aus der T-Pose heruntergenommen
FAT_RELAX_LESS = 8.0    # dicke Figuren: Arme so viel Grad weniger tief (wie ChibiCharacter)
SHOULDER_SHARE = 15.0   # davon übernimmt das Schlüsselbein (wie ChibiCharacter.SHOULDER_SHARE)


def pose_relaxed(arm, angle=None):
    """Arme aus der T-Pose locker herunter (für die Kontrollbilder)."""
    angle = RELAX_ANGLE if angle is None else angle
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for side, s in (("Left", 1), ("Right", -1)):
        # das Schlüsselbein dreht ein Stück mit (runde Schulter), der Oberarm den Rest
        share = min(SHOULDER_SHARE, angle)
        for bone, part in ((side + "Shoulder", share), (side + "UpperArm", angle - share)):
            pb = arm.pose.bones[bone]
            rest = pb.bone.matrix_local.to_3x3()
            r = Matrix.Rotation(math.radians(s * part), 3, "Y")
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (rest.inverted() @ r @ rest).to_quaternion()
        lower = arm.pose.bones[side + "LowerArm"]
        rest2 = lower.bone.matrix_local.to_3x3()
        r2 = Matrix.Rotation(math.radians(-12), 3, "Z") if s > 0 else Matrix.Rotation(math.radians(12), 3, "Z")
        lower.rotation_mode = "QUATERNION"
        lower.rotation_quaternion = (rest2.inverted() @ r2 @ rest2).to_quaternion()
    bpy.ops.object.mode_set(mode="OBJECT")


REFERENCE = os.path.join(ROOT, "screenshots", "chibi_reference.png")


def ortho_render(path, x0, H, res=1024, feet_row=948, fig_px=808, turn=0.0):
    """Gerade von vorn (ohne Perspektive), Maßstab wie das Vorlagenbild."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x = scene.render.resolution_y = res
    cam = bpy.data.objects.new("Ortho", bpy.data.cameras.new("Ortho"))
    cam.data.type = "ORTHO"
    scale = H * res / fig_px
    cam.data.ortho_scale = scale
    zc = (feet_row - res / 2) * scale / res
    t = math.radians(turn)
    cam.location = (x0 + 6.0 * math.sin(t), -6.0 * math.cos(t), zc)
    cam.rotation_euler = (math.radians(90), 0, t)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    scene.render.resolution_x, scene.render.resolution_y = old


def load_png(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    px = np.flipud(np.array(im.pixels[:]).reshape(h, w, 4))
    bpy.data.images.remove(im)
    return px


def compare_with_reference(figs):
    """Vorlage (falls vorhanden) und Figuren nebeneinander, gleicher Maßstab (Kopf = 30 %)."""
    tiles = []
    if os.path.exists(REFERENCE):
        ref = load_png(REFERENCE)
        tiles.append(ref[:, 430:930])
    for arm, body, parts in figs:
        path = os.path.join(SHOT_DIR, f"ortho_{body.gender}_{body.height_class}.png")
        ortho_render(path, arm.location.x, S.HEIGHTS["female"]["medium"])
        tiles.append(load_png(path)[:, 262:762])
    F.write_png(os.path.join(SHOT_DIR, "compare.png"), np.concatenate(tiles, 1))


def only_visible(figs, keep):
    """Nur die Figur keep rendern (die anderen stehen sonst bei Seitenansichten im Bild)."""
    for f in figs:
        for o in f[2]:
            o.hide_render = f is not keep


def around_sheet(figs, suffix=""):
    """Je Geschlecht: von der Seite, von hinten, von der anderen Seite und von vorn."""
    for fig in figs[:2]:
        arm, body, _ = fig
        only_visible(figs, fig)
        tiles = []
        for turn in (-90, 180, 90, 0):
            path = os.path.join(SHOT_DIR, "tile.png")
            ortho_render(path, arm.location.x, S.HEIGHTS["male"]["tall"] + 0.05, turn=turn)
            tiles.append(load_png(path)[:, 262:762])
        F.write_png(os.path.join(SHOT_DIR, f"around_{body.gender}{suffix}.png"), np.concatenate(tiles, 1))
    for f in figs:
        for o in f[2]:
            o.hide_render = False


def gender_lineups(figs):
    """Je Geschlecht ein Bild: Zeilen dünn/mittel/dick, Spalten klein/mittel/groß."""
    for gender in ("female", "male"):
        group = [f for f in figs if f[1].gender == gender]
        if not group:
            continue
        cx = sum(f[0].location.x for f in group) / len(group)
        hidden = [f for f in figs if f[1].gender != gender]
        for arm, _, parts in hidden:
            for o in parts:
                o.hide_render = True
        rows = []
        for name in ("thin", "medium", "fat"):
            set_shape(group, name)
            path = os.path.join(SHOT_DIR, "tile.png")
            C.render(path, (cx, -4.4, 0.95), (cx, 0, 0.86), lens=50)
            rows.append(load_png(path))
        set_shape(group, "medium")
        for arm, _, parts in hidden:
            for o in parts:
                o.hide_render = False
        F.write_png(os.path.join(SHOT_DIR, f"lineup_{gender}.png"), np.concatenate(rows, 0))


def wrists_sheet(figs, size=420):
    """Hände und Unterarme von vorn: je Figur dünn, mittel, dick (Zeilen = Figuren)."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x = scene.render.resolution_y = size
    rows = []
    for arm, body, parts in figs:
        tiles = []
        for name in ("thin", "medium", "fat"):
            set_shape([(arm, body, parts)], name)
            bpy.context.view_layer.update()
            hand = arm.matrix_world @ arm.pose.bones["LeftLowerArm"].tail
            path = os.path.join(SHOT_DIR, f"wrist_{name}.png")
            C.render(path, tuple(hand + Vector((0.12, -0.75, 0.02))), tuple(hand + Vector((0.0, 0.0, -0.01))), lens=85)
            tiles.append(load_png(path))
        set_shape([(arm, body, parts)], "medium")
        rows.append(np.concatenate(tiles, 1))
    F.write_png(os.path.join(SHOT_DIR, "wrists.png"), np.concatenate(rows, 0))
    scene.render.resolution_x, scene.render.resolution_y = old


def head_tiles(arm, body, items, size):
    """Kopf-Nahaufnahmen; items = [(Ausdruck, Augenform)]."""
    name = f"face_{body.gender}_{body.height_class}"
    tiles = []
    for e, shape in items:
        face_image(name, e, body.gender, shape=shape)
        z = body.chin + 0.2
        path = os.path.join(SHOT_DIR, "tile.png")
        C.render(path, (arm.location.x + 0.3, -1.3, z + 0.04), (arm.location.x, 0, z - 0.03), lens=85)
        tiles.append(load_png(path))
    face_image(name, "neutral", body.gender)
    return tiles


def eyes_sheet(figs, size=360):
    """Augenformen zur Auswahl: je Zeile eine Form (3 Frau, 3 Mann), Spalten = Ausdrücke."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x = scene.render.resolution_y = size
    moods = ("neutral", "happy", "laugh", "surprised", "sad", "angry", "wink", "embarrassed")
    for arm, body, parts in figs[:2]:
        rows = []
        for shape in F.SHAPE_NAMES[body.gender]:
            rows.append(np.concatenate(head_tiles(arm, body, [(m, shape) for m in moods], size), 1))
        F.write_png(os.path.join(SHOT_DIR, f"eyes_{body.gender}.png"), np.concatenate(rows, 0))
    scene.render.resolution_x, scene.render.resolution_y = old


def matrix_sheet(figs, size=240):
    """Vollständige Übersicht je Geschlecht: jede Augenform (Zeilenpaar) mit allen Ausdrücken."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x = scene.render.resolution_y = size
    names = [n for n in F.EXPRESSIONS if n != "blink"]
    half = (len(names) + 1) // 2
    for fig in figs[:2]:
        arm, body, parts = fig
        only_visible(figs, fig)
        rows = []
        for shape in F.SHAPE_NAMES[body.gender]:
            tiles = head_tiles(arm, body, [(m, shape) for m in names], size)
            while len(tiles) < 2 * half:
                tiles.append(np.ones_like(tiles[0]))
            rows.append(np.concatenate(tiles[:half], 1))
            rows.append(np.concatenate(tiles[half:], 1))
        F.write_png(os.path.join(SHOT_DIR, f"matrix_{body.gender}.png"), np.concatenate(rows, 0))
    for f in figs:
        for o in f[2]:
            o.hide_render = False
    scene.render.resolution_x, scene.render.resolution_y = old


def moods_sheet(figs, size=300):
    """Alle Ausdrücke (erste Augenform), Frau und Mann."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x = scene.render.resolution_y = size
    names = list(F.EXPRESSIONS)
    for arm, body, parts in figs[:2]:
        tiles = head_tiles(arm, body, [(m, None) for m in names], size)
        while len(tiles) % 9:
            tiles.append(np.ones_like(tiles[0]))
        rows = [np.concatenate(tiles[i:i + 9], 1) for i in range(0, len(tiles), 9)]
        F.write_png(os.path.join(SHOT_DIR, f"moods_{body.gender}.png"), np.concatenate(rows, 0))
    scene.render.resolution_x, scene.render.resolution_y = old


def collision_check(figs):
    """Ragen die locker hängenden Arme in den Rumpf? (je Figur und Form, kleinster Abstand in mm)"""
    dg = bpy.context.evaluated_depsgraph_get()
    for arm, body, parts in figs:
        obj = parts[0]
        groups = {g.index: g.name for g in obj.vertex_groups}
        armw = np.zeros(len(obj.data.vertices))
        for v in obj.data.vertices:
            for g in v.groups:
                if any(b in groups[g.group] for b in ARM_BONES):
                    armw[v.index] += g.weight
        idx = np.nonzero(armw > 0.95)[0]
        line = []
        for name in ("thin", "medium", "fat"):
            set_shape([(arm, body, parts)], name)
            # dicke Figuren lassen die Arme weniger tief hängen (wie ChibiCharacter)
            pose_relaxed(arm, RELAX_ANGLE - (FAT_RELAX_LESS if name == "fat" else 0.0))
            dg.update()
            ev = obj.evaluated_get(dg)
            co = np.array([ev.data.vertices[i].co for i in idx])
            other = S.Body(body.gender, body.height_class, name, navel=False)
            rest = S.Group("rest", [it for it in other.root.items if not it[1].name.startswith("arm_")
                                    and it[0] == "union"])
            d = rest.eval_points(co)
            hits = co[d < 0]
            j = int(np.argmin(d))
            where = f" bei z={co[j, 2]:.2f} x={co[j, 0]:.2f}" if len(hits) else ""
            line.append(f"{name}: {d.min() * 1000:.0f} mm{where} ({len(hits)} Ecken)")
        set_shape([(arm, body, parts)], "medium")
        pose_relaxed(arm)
        print("ARME", body.gender, body.height_class, ", ".join(line))


FINGERS = ("Thumb", "Index", "Middle", "Ring", "Little")


def joints_check(figs):
    """Gelenke prüfen (für Mixamo/Godot): jedes Gelenk muss innen im Körper liegen; Bilder in T-Pose
    mit durchsichtigem Körper, Gelenke rot, Knochen blau (vorn und von der Seite)."""
    for fig in figs:
        arm, body, parts = fig
        heads = [(n, np.array(h)) for n, h, t, par in body.bones()]
        d = body.root.eval_points(np.array([h for _, h in heads]))
        outside = [(n, round(float(v) * 1000, 1)) for (n, _), v in zip(heads, d) if v > -0.002]
        print("GELENKE", body.gender, body.height_class, len(heads), "Knochen,",
              "alle innen" if not outside else f"außen/am Rand: {outside}")
    if not figs:
        return
    # Bilder: nur die ersten zwei Figuren, in Ruhehaltung (T-Pose)
    red = principled("joint", (0.9, 0.1, 0.1), ao=False)
    blue = principled("bone", (0.1, 0.3, 0.9), ao=False)
    for fig in figs[:2]:
        arm, body, parts = fig
        only_visible(figs, fig)
        arm.data.pose_position = "REST"
        mats = [m for o in parts for m in o.data.materials]
        for m in mats:
            m.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.22
        made = []
        for n, h, t, par in body.bones():
            h = Vector(h) + arm.location
            t = Vector(t) + arm.location
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.006 if any(f in n for f in FINGERS) else 0.010,
                                                 location=h, segments=12, ring_count=8)
            made.append(bpy.context.active_object)
            made[-1].data.materials.append(red)
            vec = t - h
            bpy.ops.mesh.primitive_cylinder_add(radius=0.0025 if any(f in n for f in FINGERS) else 0.004,
                                                depth=vec.length, location=(h + t) / 2, vertices=8)
            c = bpy.context.active_object
            c.rotation_euler = vec.to_track_quat("Z", "Y").to_euler()
            c.data.materials.append(blue)
            made.append(c)
        tiles = []
        for turn in (0, 90, 35):
            path = os.path.join(SHOT_DIR, "tile.png")
            ortho_render(path, arm.location.x, S.HEIGHTS["male"]["tall"] + 0.25, turn=turn, res=1024)
            tiles.append(load_png(path)[:, 112:912])
        F.write_png(os.path.join(SHOT_DIR, f"joints_{body.gender}.png"), np.concatenate(tiles, 1))
        # Hand aus der Nähe (von oben und von vorn)
        scene = bpy.context.scene
        old = scene.render.resolution_x, scene.render.resolution_y
        scene.render.resolution_x = scene.render.resolution_y = 600
        wrist = Vector(body.joints_arm["Left"]["wrist"]) + arm.location
        c = wrist + Vector((0.07, -0.01, 0.0))
        hands = []
        for cam in (c + Vector((0.0, -0.02, 0.45)), c + Vector((0.05, -0.45, 0.05))):
            path = os.path.join(SHOT_DIR, "tile.png")
            C.render(path, tuple(cam), tuple(c), lens=60)
            hands.append(load_png(path))
        F.write_png(os.path.join(SHOT_DIR, f"joints_hand_{body.gender}.png"), np.concatenate(hands, 1))
        scene.render.resolution_x, scene.render.resolution_y = old
        for o in made:
            bpy.data.objects.remove(o)
        for m in mats:
            m.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 1.0
        arm.data.pose_position = "POSE"
    for f in figs:
        for o in f[2]:
            o.hide_render = False


def tpose_sheet(figs):
    """Figuren in T-Pose (so wie gebaut, für Mixamo): vorn und hinten, Frau oben, Mann unten."""
    rows = []
    for fig in figs[:2]:
        arm, body, parts = fig
        only_visible(figs, fig)
        arm.data.pose_position = "REST"
        tiles = []
        for turn in (0, 180):
            path = os.path.join(SHOT_DIR, "tile.png")
            ortho_render(path, arm.location.x, S.HEIGHTS["male"]["tall"] + 0.25, turn=turn, res=1024)
            tiles.append(load_png(path)[200:900, 62:962])
        arm.data.pose_position = "POSE"
        rows.append(np.concatenate(tiles, 1))
    F.write_png(os.path.join(SHOT_DIR, "tpose.png"), np.concatenate(rows, 0))
    for f in figs:
        for o in f[2]:
            o.hide_render = False


def underwear_check(figs):
    """Keine bemalte Ecke (Unterwäsche) darf am Arm oder Schlüsselbein hängen."""
    for arm, body, parts in figs:
        obj = parts[0]
        me = obj.data
        layer = me.uv_layers["AO"]
        li = np.zeros(len(me.loops), np.int32)
        me.loops.foreach_get("vertex_index", li)
        uv = np.zeros(len(li) * 2, np.float32)
        layer.data.foreach_get("uv", uv)
        d = np.full(len(me.vertices), 1.0)
        d[li] = uv.reshape(-1, 2)[:, 1]
        groups = {g.index: g.name for g in obj.vertex_groups}
        moving = np.zeros(len(me.vertices))
        for v in me.vertices:
            for g in v.groups:
                n = groups[g.group]
                if any(b in n for b in ARM_BONES) or n.endswith("Shoulder"):
                    moving[v.index] += g.weight
        bad = int(((d < 0.0005) & (moving > 0.02)).sum())
        print("WAESCHE", body.gender, body.height_class, "bemalte Ecken, die mit Arm/Schulter drehen:", bad)


def armpits_sheet(figs, size=360):
    """Achseln aus der Nähe (Arme hängend): Zeilen = Figuren, Spalten = dünn/mittel/dick × vorn/schräg."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x = scene.render.resolution_y = size
    rows = []
    for fig in figs:
        arm, body, parts = fig
        only_visible(figs, fig)
        tiles = []
        z = body.shoulder_z - 0.06
        x0 = arm.location.x
        for name in ("thin", "medium", "fat"):
            set_shape([fig], name)
            bpy.context.view_layer.update()
            for cam in ((x0, -1.2, z + 0.05), (x0 + 0.75, -0.9, z + 0.1)):
                path = os.path.join(SHOT_DIR, "tile.png")
                C.render(path, cam, (x0, 0, z), lens=60)
                tiles.append(load_png(path))
        set_shape([fig], "medium")
        rows.append(np.concatenate(tiles, 1))
    F.write_png(os.path.join(SHOT_DIR, "armpits.png"), np.concatenate(rows, 0))
    for f in figs:
        for o in f[2]:
            o.hide_render = False
    scene.render.resolution_x, scene.render.resolution_y = old


def underarm_sheet(figs, size=420):
    """Achsel in T-Pose (von unten-vorn) und in mehreren Arm-Stellungen (Mitte bis ganz unten)."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x = scene.render.resolution_y = size
    rows = []
    for fig in figs[:2]:
        arm, body, parts = fig
        only_visible(figs, fig)
        x0 = arm.location.x
        sh = Vector(body.joints_arm["Left"]["shoulder"]) + arm.location
        tiles = []
        for angle in (0.0, 30.0, 50.0, 65.0, 80.0):
            pose_relaxed(arm, angle)
            bpy.context.view_layer.update()
            path = os.path.join(SHOT_DIR, "tile.png")
            target = sh + Vector((-0.03, 0.0, -0.08))
            C.render(path, tuple(target + Vector((0.12, -0.55, -0.10))), tuple(target), lens=55)
            tiles.append(load_png(path))
        pose_relaxed(arm)
        rows.append(np.concatenate(tiles, 1))
    F.write_png(os.path.join(SHOT_DIR, "underarm.png"), np.concatenate(rows, 0))
    for f in figs:
        for o in f[2]:
            o.hide_render = False
    scene.render.resolution_x, scene.render.resolution_y = old


def heads_sheet(figs, size=520):
    """Kopf von vorn, schräg und im Profil (Kinn, Kiefer, Ohren), Frau oben, Mann unten."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x = scene.render.resolution_y = size
    rows = []
    for fig in figs[:2]:
        arm, body, _ = fig
        only_visible(figs, fig)
        tiles = []
        x0 = arm.location.x
        z = body.chin + 0.17
        for dx, dy in ((0.0, -1.0), (0.7, -0.7), (1.0, 0.0), (0.7, 0.7)):
            path = os.path.join(SHOT_DIR, "tile.png")
            C.render(path, (x0 + dx * 1.9, dy * 1.9, z + 0.05), (x0, 0.0, z - 0.04), lens=70)
            tiles.append(load_png(path))
        rows.append(np.concatenate(tiles, 1))
    F.write_png(os.path.join(SHOT_DIR, "heads.png"), np.concatenate(rows, 0))
    for f in figs:
        for o in f[2]:
            o.hide_render = False
    scene.render.resolution_x, scene.render.resolution_y = old


def set_shape(figs, name):
    for arm, _body, parts in figs:
        for o in parts:
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 1.0 if kb.name == name else 0.0
        if arm.pose is not None and arm.pose.bones["LeftUpperArm"].rotation_quaternion.angle > 0.01:
            pose_relaxed(arm, RELAX_ANGLE - (FAT_RELAX_LESS if name == "fat" else 0.0))


def shapes_sheet(figs, cx):
    """Alle Figuren dünn, mittel und dick (untereinander)."""
    rows = []
    for name in ("thin", "medium", "fat"):
        set_shape(figs, name)
        path = os.path.join(SHOT_DIR, f"shape_{name}.png")
        C.render(path, (cx, -7.2, 0.95), (cx, 0, 0.85), lens=50)
        rows.append(load_png(path))
    set_shape(figs, "medium")
    F.write_png(os.path.join(SHOT_DIR, "shapes.png"), np.concatenate(rows, 0))


def faces_sheet(figs, size=520):
    """Alle Ausdrücke auf dem Kopf (Frau oben, Mann unten) als ein Bild."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x = scene.render.resolution_y = size
    rows = []
    for arm, body, parts in figs[:2]:
        gender = body.gender
        name = f"face_{gender}_{body.height_class}"
        tiles = []
        for e in F.EXPRESSIONS:
            face_image(name, e, gender)
            z = body.chin + 0.19
            x0 = arm.location.x
            path = os.path.join(SHOT_DIR, f"face_{gender}_{e}.png")
            C.render(path, (x0 + 0.28, -1.15, z + 0.06), (x0, 0, z), lens=85)
            im = bpy.data.images.load(path)
            px = np.array(im.pixels[:]).reshape(size, size, 4)
            tiles.append(np.flipud(px))
            bpy.data.images.remove(im)
        face_image(name, "neutral", gender)
        rows.append(np.concatenate([np.concatenate(tiles[:6], 1), np.concatenate(tiles[6:12], 1)], 0))
    F.write_png(os.path.join(SHOT_DIR, "faces.png"), np.concatenate(rows, 0))
    scene.render.resolution_x, scene.render.resolution_y = old


FACE_TEX_DIR = os.path.join(ROOT, "assets", "textures", "characters", "chibi_face")


def export_figure(gender, height):
    """Eine Figur bauen und als .glb (Godot), .fbx (Mixamo) und .blend (Quelle) schreiben."""
    C.reset()
    arm, parts, body = build(gender, height)
    for im in bpy.data.images:
        if im.source == "GENERATED":
            im.pack()
    name = f"{gender}_{height}"
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, name + ".glb"), export_format="GLB", use_selection=True,
                              export_skins=True, export_morph=True, export_morph_normal=True, export_colors=False,
                              export_animations=False, export_extras=True, export_apply=False, export_yup=True,
                              export_image_format="AUTO")
    mixamo = os.path.join(OUT_DIR, "mixamo")
    os.makedirs(mixamo, exist_ok=True)
    gd = os.path.join(mixamo, ".gdignore")
    if not os.path.exists(gd):
        open(gd, "w").close()
    export_mixamo(os.path.join(mixamo, name + ".fbx"), parts[0])
    os.makedirs(SOURCE_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, name + ".blend"), compress=True)
    print("geschrieben:", name, len(parts[0].data.polygons), "Flächen")


def export_mixamo(path, body_obj):
    """Für Mixamo: nur das Netz in T-Pose, ohne Formregler, eine Texturkoordinate, ein Material,
    Maße direkt in Zentimetern (Mixamo beachtet den Maßstab-Faktor im FBX nicht – die Figur wäre
    dort 1,5 cm groß und bekäme dunkle Schattenflecken)."""
    me = body_obj.data.copy()
    obj = bpy.data.objects.new("Body", me)
    bpy.context.scene.collection.objects.link(obj)
    if me.shape_keys:
        obj.shape_key_clear()
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    me.materials.clear()
    mat = bpy.data.materials.get("mixamo_skin") or principled("mixamo_skin", SKIN, ao=False)
    me.materials.append(mat)
    for poly in me.polygons:
        poly.material_index = 0
    # Zahlen selbst in Zentimeter umrechnen (1,56 m -> 156) und die Szene auf Zentimeter stellen:
    # nur so schreibt Blender "Einheit Zentimeter" ohne zusätzlichen Faktor 100 am Objekt
    me.transform(Matrix.Scale(100.0, 4))
    units = bpy.context.scene.unit_settings
    old_scale = units.scale_length
    units.scale_length = 0.01
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, path_mode="STRIP",
                             embed_textures=False, bake_anim=False, use_mesh_modifiers=False,
                             mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=1.0,
                             apply_scale_options="FBX_SCALE_UNITS", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y")
    units.scale_length = old_scale
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)


def export_face_textures():
    for key, img in atlases().items():
        F.write_png(os.path.join(FACE_TEX_DIR, key + ".png"), img)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    views = ["front", "side"]
    for a in argv:
        if a.startswith("--only="):
            only = a.split("=", 1)[1].split(",")
        if a.startswith("--views="):
            views = a.split("=", 1)[1].split(",")
        if a.startswith("--relax="):
            global RELAX_ANGLE
            RELAX_ANGLE = float(a.split("=", 1)[1])
    do_render = "--render" in argv
    names = [(g, h) for g in ("female", "male") for h in ("small", "medium", "tall")]
    if only:
        names = [n for n in names if f"{n[0]}_{n[1]}" in only]
    if not do_render:
        export_face_textures()
        for g, h in names:
            export_figure(g, h)
        return
    C.reset()
    if do_render:
        C.setup_render(res=(1200, 900), samples=24)
        # weiches Licht wie bei Vinyl-Figuren im Fotostudio
        sun = bpy.data.objects["Sun"]
        sun.data.angle = math.radians(25)
        sun.data.energy = 2.4
        bpy.context.scene.world.node_tree.nodes["Background"].inputs[1].default_value = 1.3
    x = 0.0
    figs = []
    for g, h in names:
        arm, parts, body = build(g, h)
        arm.location.x = x
        pose_relaxed(arm)
        figs.append((arm, body, parts))
        x += 0.8
    if do_render:
        os.makedirs(SHOT_DIR, exist_ok=True)
        cx = (x - 0.8) / 2
        bpy.context.view_layer.update()
        for v in views:
            path = os.path.join(SHOT_DIR, v + ".png")
            arm, body, _ = figs[0]
            x0 = arm.location.x
            if v == "front":
                C.render(path, (cx, -4.6, 0.95), (cx, 0, 0.82), lens=50)
            elif v == "side":
                C.render(path, (cx + 3.4, -3.2, 1.0), (cx, 0, 0.8), lens=50)
            elif v == "back":
                C.render(path, (cx - 2.0, 4.0, 1.2), (cx, 0, 0.8), lens=50)
            elif v == "head":
                z = body.chin + 0.2
                C.render(path, (x0 + 0.45, -1.1, z + 0.08), (x0, 0, z), lens=60)
            elif v == "heads":
                heads_sheet(figs)
            elif v == "headfront":
                z = body.chin + 0.2
                C.render(path, (x0, -1.3, z + 0.02), (x0, 0, z), lens=60)
            elif v == "shapes":
                shapes_sheet(figs, cx)
            elif v == "fat":
                set_shape(figs, "fat")
                C.render(path, (x0, -3.0, 0.9), (x0, 0, 0.75), lens=50)
                set_shape(figs, "medium")
            elif v == "wrists":
                wrists_sheet(figs)
            elif v == "around":
                around_sheet(figs)
            elif v == "around_fat":
                set_shape(figs, "fat")
                around_sheet(figs, "_fat")
                set_shape(figs, "medium")
            elif v == "lineups":
                gender_lineups(figs)
            elif v == "compare":
                compare_with_reference(figs)
            elif v == "collide":
                collision_check(figs)
            elif v == "joints":
                joints_check(figs)
            elif v == "underwear":
                underwear_check(figs)
            elif v == "armpits":
                armpits_sheet(figs)
            elif v == "underarm":
                underarm_sheet(figs)
            elif v == "tpose":
                tpose_sheet(figs)
            elif v == "eyes":
                eyes_sheet(figs)
            elif v == "moods":
                moods_sheet(figs)
            elif v == "matrix":
                matrix_sheet(figs)
            elif v == "faces":
                faces_sheet(figs)
            elif v == "hand":
                hand = arm.matrix_world @ arm.pose.bones["LeftHand"].head
                C.render(path, tuple(hand + Vector((0.35, -0.4, 0.05))), tuple(hand + Vector((0, 0, -0.05))), lens=60)


if __name__ == "__main__":
    main()
