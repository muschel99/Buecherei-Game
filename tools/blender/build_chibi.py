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
CLOTH_TRIS = 3200      # Dreiecke je Wäschestück

SKIN = (0.95, 0.80, 0.68)
CLOTH = (0.80, 0.70, 0.60)


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


def decimate(obj, tris):
    faces = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    m = obj.modifiers.new("Decimate", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = min(1.0, tris / max(faces, 1))
    m.use_symmetry = True
    m.symmetry_axis = "X"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=m.name)


def surface_object(name, node, lo, hi, tris, keep=None):
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
    decimate(obj, tris)
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
    schieben; Feinheiten (Nabel) wandern als Abstand zur glatten Form mit."""
    base = coords(obj)
    smooth = S.project(plain.root, base, 6)
    detail = base - smooth
    obj.shape_key_add(name="Basis", from_mix=False)
    for name, other in variants.items():
        key = obj.shape_key_add(name=name, from_mix=False)
        p = S.project(other.root, smooth, 10) + detail
        key.data.foreach_set("co", p.astype(np.float32).ravel())
        key.value = 0.0


def follow_body_keys(obj, body, variants):
    """Formregler für Kleidung: jede Ecke wandert so weit wie die (glatte) Haut direkt darunter."""
    base = coords(obj)
    on_body = S.project(body.root, base, 6)
    obj.shape_key_add(name="Basis", from_mix=False)
    nrm = S.normals(body.root, on_body)
    for name, other in variants.items():
        delta = S.project(other.root, on_body, 10) - on_body
        # bei mehr Bauch etwas mehr Abstand, damit nichts durch den Bund drückt
        grow = np.clip((delta * nrm).sum(axis=1), 0.0, None)[:, None]
        delta = delta + nrm * np.minimum(grow * 0.15, 0.004)
        key = obj.shape_key_add(name=name, from_mix=False)
        key.data.foreach_set("co", (base + delta).astype(np.float32).ravel())
        key.value = 0.0


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

def principled(name, color, rough=0.5, ao=True, image=None):
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


def face_image(name, expression, gender, size=1024):
    """Gesicht als Bild (für Blender und als Standard-Gesicht im .glb)."""
    img = F.compose(atlases(), expression, gender, size, skin=SKIN)
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

def build(gender, height):
    bodies = {s: S.Body(gender, height, s) for s in S.SHAPES}
    plain = {s: S.Body(gender, height, s, navel=False) for s in S.SHAPES}
    body = bodies["medium"]
    lo, hi = body.bounds()
    arm = make_armature(body)
    obj = surface_object("Body", body.root, lo, hi, BODY_TRIS)
    add_ao(obj, body.root, 0.5)
    smooth_normals(obj, body.root)
    add_shape_keys(obj, plain["medium"], {"thin": plain["thin"], "fat": plain["fat"]})
    obj.data.materials.append(principled("skin", SKIN))
    face_uv(obj, body)
    img = face_image(f"face_{gender}_{height}", "neutral", gender)
    obj.data.materials.append(principled("face", SKIN, image=img))
    bind(obj, arm, body)
    parts = [obj]
    for kind in (("bandeau", "pants") if gender == "female" else ("pants",)):
        node = body.cloth(kind)
        variants = {s: bodies[s].cloth(kind) for s in ("thin", "fat")}

        def keep(c, node=node):
            return body.root.eval_points(c) > -0.0015

        cl = surface_object(kind.capitalize(), node, node.lo, node.hi, CLOTH_TRIS, keep)
        add_ao(cl, node, 0.6)
        smooth_normals(cl, node)
        follow_body_keys(cl, plain["medium"], {s: plain[s] for s in ("thin", "fat")})
        cl.data.materials.append(principled("cloth", CLOTH, 0.8))
        bind(cl, arm, body)
        parts.append(cl)
    return arm, parts, body


def pose_relaxed(arm, angle=24.0):
    """Arme herunter (A-Pose) für die Kontrollbilder."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for side, s in (("Left", 1), ("Right", -1)):
        pb = arm.pose.bones[side + "UpperArm"]
        rest = pb.bone.matrix_local.to_3x3()
        r = Matrix.Rotation(math.radians(s * angle), 3, "Y")
        local = rest.inverted() @ r @ rest
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = local.to_quaternion()
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


def around_sheet(figs):
    """Erste Figur von der Seite, von hinten, von der anderen Seite und von vorn (wie die Vorlage)."""
    arm, body, _ = figs[0]
    tiles = []
    for turn in (-90, 180, 90, 0):
        path = os.path.join(SHOT_DIR, f"around_{turn}.png")
        ortho_render(path, arm.location.x, S.HEIGHTS["female"]["medium"], turn=turn)
        tiles.append(load_png(path)[:, 262:762])
    F.write_png(os.path.join(SHOT_DIR, "around.png"), np.concatenate(tiles, 1))


def set_shape(figs, name):
    for _arm, _body, parts in figs:
        for o in parts:
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 1.0 if kb.name == name else 0.0


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


def cloth_uv(obj):
    """Einfache Texturkoordinaten für die Wäsche (Godot braucht sie für Tangenten)."""
    me = obj.data
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    li = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", li)
    p = coords(obj)[li]
    ang = np.arctan2(p[:, 0], -p[:, 1]) / (2 * math.pi) + 0.5
    uv.data.foreach_set("uv", np.stack([ang, p[:, 2]], axis=1).astype(np.float32).ravel())


def export_figure(gender, height):
    """Eine Figur bauen und als .glb (Godot), .fbx (Mixamo) und .blend (Quelle) schreiben."""
    C.reset()
    arm, parts, body = build(gender, height)
    for o in parts[1:]:
        cloth_uv(o)
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
    C.export_fbx(os.path.join(mixamo, name + ".fbx"), parts, arm)
    os.makedirs(SOURCE_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, name + ".blend"), compress=True)
    print("geschrieben:", name, len(parts[0].data.polygons), "Flächen")


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
            elif v == "headfront":
                z = body.chin + 0.2
                C.render(path, (x0, -1.3, z + 0.02), (x0, 0, z), lens=60)
            elif v == "shapes":
                shapes_sheet(figs, cx)
            elif v == "fat":
                set_shape(figs, "fat")
                C.render(path, (x0, -3.0, 0.9), (x0, 0, 0.75), lens=50)
                set_shape(figs, "medium")
            elif v == "around":
                around_sheet(figs)
            elif v == "compare":
                compare_with_reference(figs)
            elif v == "faces":
                faces_sheet(figs)
            elif v == "hand":
                hand = arm.matrix_world @ arm.pose.bones["LeftHand"].head
                C.render(path, tuple(hand + Vector((0.35, -0.4, 0.05))), tuple(hand + Vector((0, 0, -0.05))), lens=60)


if __name__ == "__main__":
    main()
