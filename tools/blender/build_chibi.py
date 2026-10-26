"""Chibi-Figuren (seit Etappe 5c, Körper neu gebaut): Grundkörper ("Mannequins") für Frauen und
Männer in drei Größen, je mit den Formreglern "thin" und "fat", aufgemalter Unterwäsche (Bandeau +
Slip bzw. Boxershorts), Skelett mit Namen wie Godots SkeletonProfileHumanoid und gezeichnetem
Gesicht (Material "face").

So entsteht der Körper:
  1. chibi_cage baut ein grobes Netz nur aus Vierecken mit Ringen um jedes Gelenk (T-Pose).
  2. Es wird zweimal geglättet (Catmull-Clark) und genau auf die Form aus chibi_sdf gelegt.
  3. Die Lichtrichtungen (Normalen) kommen aus dem Netz selbst – sie passen also immer zu den
     Flächen (früher aus der Form gerechnet: bis 16° daneben, fleckiges Licht).
  4. Gewichte und Skelett aus chibi_rig, Formregler: dasselbe Netz der dünnen/dicken Form.

Aufruf:
  blender -b --factory-startup --python tools/blender/build_chibi.py -- [Optionen]
    --only female_medium,male_medium   nur diese Figuren
    --render                           Kontrollbilder nach screenshots/blender/chibi/ (nichts schreiben)
    --views=front,poses,...            welche Kontrollbilder (Liste unten in main)

Ausgabe: assets/models/characters/chibi/<gender>_<größe>.glb (am Skelett die Gelenk-Verschiebungen
für dünn/dick, "chibi_bone_offsets"), .blend-Quellen in assets/models/source/characters/chibi/,
Mixamo-Dateien in assets/models/characters/chibi/mixamo/.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import numpy as np  # noqa: E402

import character_lib as C  # noqa: E402  (numpy-Kniff, Export, Kontrollbilder)
import chibi_cage as G  # noqa: E402
import chibi_face as F  # noqa: E402
import chibi_outfit as O  # noqa: E402
import chibi_rig as R  # noqa: E402
import chibi_sdf as S  # noqa: E402
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ROOT = C.ROOT
OUT_DIR = os.path.join(ROOT, "assets", "models", "characters", "chibi")
SOURCE_DIR = os.path.join(ROOT, "assets", "models", "source", "characters", "chibi")
SHOT_DIR = os.path.join(ROOT, "screenshots", "blender", "chibi")

SUBDIVISIONS = 2     # so oft wird der Käfig geglättet (jedes Viereck wird zu 4^n)
RELAX_ITERATIONS = 3  # danach die Ecken so oft gleichmäßig verteilen (entlang der Oberfläche)

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


def vertex_normals(obj):
    me = obj.data
    me.update()
    n = np.zeros(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("normal", n)
    return n.reshape(-1, 3).astype(np.float64)


def neighbors(obj):
    """Nachbarecken je Ecke (über Kanten)."""
    me = obj.data
    e = np.zeros(len(me.edges) * 2, np.int64)
    me.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    out = [[] for _ in range(len(me.vertices))]
    for a, b in e:
        out[a].append(b)
        out[b].append(a)
    return [np.array(x) for x in out]


def recalc_normals(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def subdivide(obj, levels):
    m = obj.modifiers.new("Subdivision", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    m.quality = 3
    m.uv_smooth = "NONE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=m.name)


def fit_to_shape(obj, node, relax=RELAX_ITERATIONS):
    """Geglättetes Netz genau auf die Form legen: jede Ecke entlang ihrer Normalen auf die
    Oberfläche, dann die Ecken entlang der Oberfläche gleichmäßig verteilen."""
    p, f = S.project_along(node, coords(obj), vertex_normals(obj))
    set_coords(obj, p)
    nb = neighbors(obj)
    for _ in range(relax):
        p = coords(obj)
        avg = np.array([p[x].mean(axis=0) for x in nb])
        n = vertex_normals(obj)
        move = avg - p
        move -= (move * n).sum(axis=1)[:, None] * n
        q, f = S.project_along(node, p + 0.5 * move, n, iterations=12)
        set_coords(obj, q)
    return np.abs(f)


def body_mesh(name, body):
    """Netz einer Figur: Käfig → zweimal glätten → auf die Form legen. Die Bereiche des Käfigs
    (Rumpf, Arm, Finger …) werden als Gruppen "region_…" weich mitgeglättet."""
    p, faces, region, info = G.build(body)
    obj = mesh_from_arrays(name, p, faces)
    for r in sorted(set(region)):
        vg = obj.vertex_groups.new(name="region_" + r)
        vg.add([i for i, x in enumerate(region) if x == r], 1.0, "REPLACE")
    recalc_normals(obj)
    subdivide(obj, SUBDIVISIONS)
    err = fit_to_shape(obj, body.root)
    print(f"  {name}: {len(obj.data.vertices)} Ecken, {len(obj.data.polygons)} Vierecke, "
          f"Abstand zur Form max {err.max() * 1000:.2f} mm")
    return obj, info


def read_regions(obj):
    """Bereiche (geglättet) je Ecke aus den Gruppen region_… – danach werden sie entfernt."""
    n = len(obj.data.vertices)
    out = {}
    groups = [g for g in obj.vertex_groups if g.name.startswith("region_")]
    for g in groups:
        out[g.name[len("region_"):]] = np.zeros(n)
    names = {g.index: g.name[len("region_"):] for g in groups}
    for v in obj.data.vertices:
        for gr in v.groups:
            if gr.group in names:
                out[names[gr.group]][v.index] = gr.weight
    for g in groups:
        obj.vertex_groups.remove(g)
    return out


def mesh_report(obj, node):
    """Prüfwerte des Netzes: geschlossen, Ecken-Nachbarn, umgeklappte Flächen."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    nonman = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    val = np.array([len(v.link_edges) for v in bm.verts])
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    centers = np.array([f.calc_center_median() for f in bm.faces])
    fn = np.array([f.normal for f in bm.faces])
    bm.free()
    g = S.normals(node, centers)
    dots = (fn * g).sum(axis=1)
    hist = {int(k): int((val == k).sum()) for k in np.unique(val)}
    print(f"  Netz: {nonman} offene/mehrfache Kanten, Nachbarn je Ecke {hist}, "
          f"Flächen schräg zur Form (>45°): {int((dots < 0.707).sum())}, umgeklappt: {int((dots < 0).sum())}")
    return nonman, int((dots < 0).sum())


def add_ao(obj, node, strength=0.5):
    """Verschattung je Ecke als zweite Texturkoordinate "AO" (u = Helligkeit) – Vertex-Farben
    kommen beim glTF-Export von Blender 3.4 durcheinander."""
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    p = coords(obj)
    ao = S.ambient_occlusion(node, p, vertex_normals(obj), strength=strength)
    layer = me.uv_layers.new(name="AO")
    li = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", li)
    uv = np.stack([ao[li], np.zeros(len(li))], axis=1)
    layer.data.foreach_set("uv", uv.astype(np.float32).ravel())


def smooth_shading(obj):
    me = obj.data
    me.use_auto_smooth = False
    me.polygons.foreach_set("use_smooth", np.ones(len(me.polygons), bool))
    me.update()


# ---------------------------------------------------------------------------------------------
# Skelett, Gewichte, Formregler
# ---------------------------------------------------------------------------------------------

def make_armature(body, name="Skeleton"):
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for bname, head, tail, parent in R.bones(body):
        eb = arm.edit_bones.new(bname)
        eb.head = tuple(head)
        eb.tail = tuple(tail)
        if parent:
            eb.parent = made[parent]
            eb.use_connect = False
        made[bname] = eb
    # Rollen: Arme und Finger mit der z-Achse nach oben (Handfläche unten), sonst nach vorn
    for eb in arm.edit_bones:
        if any(k in eb.name for k in ("Arm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little", "Shoulder")):
            eb.align_roll(Vector((0, 0, 1)))
        else:
            eb.align_roll(Vector((0, -1, 0)))
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def bind(obj, arm, weights, names):
    for i, n in enumerate(names):
        idx = np.nonzero(weights[:, i] > 0)[0]
        if len(idx) == 0:
            continue
        vg = obj.vertex_groups.new(name=n)
        for j in idx:
            vg.add([int(j)], float(weights[j, i]), "REPLACE")
    obj.parent = arm
    m = obj.modifiers.new("Armature", "ARMATURE")
    m.object = arm


def add_shape_keys(obj, body, others, weights, names):
    """Formregler: dasselbe Netz der dünnen/dicken Form. Arme und Beine rücken dort samt Gelenken
    nach außen – diese Verschiebung machen in Godot die Knochen (ChibiCharacter), darum ist sie
    hier herausgerechnet (sonst knickt der Ellbogen neben dem Gelenk)."""
    obj.shape_key_add(name="Basis", from_mix=False)
    offsets = {}
    for name, other_obj in others.items():
        other = other_obj["body"]
        p = coords(other_obj["obj"])
        shift = np.zeros_like(p)
        offs = R.limb_offsets(body, other)
        for root, d in offs.items():
            chain = R.chain_children(names, root)
            shift += weights[:, chain].sum(axis=1)[:, None] * d[None, :]
        key = obj.shape_key_add(name=name, from_mix=False)
        key.data.foreach_set("co", (p - shift).astype(np.float32).ravel())
        key.value = 0.0
        offsets[name] = {k: [float(x) for x in v] for k, v in offs.items()}
    return offsets


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
# Gesicht und Unterwäsche
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


def paint_underwear(obj, body, weights, names):
    """Unterwäsche aufmalen: Abstand zum Rand je Ecke in UV2.y (Shader zieht daraus die Kante).
    Nie auf Haut, die mit Arm oder Schlüsselbein dreht (sonst wandert der Rand auf den Arm)."""
    me = obj.data
    p = coords(obj)
    d = body.underwear_distance(p)
    moving = sum(weights[:, i] for i, n in enumerate(names) if any(b in n for b in R.ARM_BONES) or n.endswith("Shoulder"))
    d = np.maximum(d, np.where(moving > 0.001, moving - 0.012, -1.0))
    layer = me.uv_layers["AO"]
    li = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", li)
    uv = np.zeros(len(li) * 2, np.float32)
    layer.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    uv[:, 1] = d[li]
    layer.data.foreach_set("uv", uv.ravel())


# ---------------------------------------------------------------------------------------------
# Figur
# ---------------------------------------------------------------------------------------------

def build(gender, height):
    """Eine Figur in der Szene bauen. Liefert (Skelett, [Körper], Body, Verschiebungen dünn/dick)."""
    bodies = {s: S.Body(gender, height, s) for s in S.SHAPES}
    body = bodies["medium"]
    print(f"{gender}_{height}:")
    obj, info = body_mesh("Body", body)
    regions = read_regions(obj)
    others = {}
    for s in ("thin", "fat"):
        o, _ = body_mesh("tmp_" + s, bodies[s])
        assert len(o.data.vertices) == len(obj.data.vertices), "dünn/dick: anderes Netz"
        others[s] = {"obj": o, "body": bodies[s]}
    mesh_report(obj, body.root)
    smooth_shading(obj)
    arm = make_armature(body)
    names = [b[0] for b in R.bones(body)]
    weights = R.skin_weights(body, coords(obj), regions, neighbors(obj), names)
    add_ao(obj, body.root)
    offsets = add_shape_keys(obj, body, others, weights, names)
    for o in others.values():
        bpy.data.objects.remove(o["obj"])
    obj.data.materials.append(principled("skin", SKIN, cloth=CLOTH))
    face_uv(obj, body)
    img = face_image(f"face_{gender}_{height}", "neutral", gender)
    obj.data.materials.append(principled("face", SKIN, image=img))
    bind(obj, arm, weights, names)
    paint_underwear(obj, body, weights, names)
    # Gelenk-Verschiebungen für dünn/dick als Zusatzangabe am Skelett (Godot liest sie als
    # Metadaten "extras"; Achsen wie in Godot: x, z → y, -y → z)
    arm["chibi_bone_offsets"] = {shape: {bone: [d[0], d[2], -d[1]] for bone, d in bones.items()}
                                 for shape, bones in offsets.items()}
    outfit = build_outfit(obj, arm, bodies, weights, names, offsets)
    return arm, [obj] + outfit, body, offsets


# ---------------------------------------------------------------------------------------------
# Kleidung und Frisuren (chibi_outfit)
# ---------------------------------------------------------------------------------------------

def vertex_ao(obj):
    """Verschattung je Ecke (aus der Texturkoordinate "AO")."""
    me = obj.data
    li = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", li)
    uv = np.zeros(len(li) * 2, np.float32)
    me.uv_layers["AO"].data.foreach_get("uv", uv)
    ao = np.ones(len(me.vertices))
    ao[li] = uv.reshape(-1, 2)[:, 0]
    return ao


def piece_object(name, data, arm, names, mat):
    """Blender-Objekt aus einem Kleidungsstück/einer Frisur (chibi_outfit): Formregler, Gewichte,
    Verschattung (UV2.x) und Höhe über dem Boden (UV2.y, für die Schuhsohle). Die Flächen zeigen
    schon richtig nach außen (Außenseite wie der Körper, Innenstreifen umgedreht)."""
    obj = mesh_from_arrays(name, data["P"]["Basis"], data["faces"])
    if len(data["P"]) > 1:
        obj.shape_key_add(name="Basis", from_mix=False)
        for key_name in ("thin", "fat"):
            key = obj.shape_key_add(name=key_name, from_mix=False)
            key.data.foreach_set("co", data["P"][key_name].astype(np.float32).ravel())
            key.value = 0.0
    me = obj.data
    li = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", li)
    # erste Texturkoordinate überall 0 (neue Ebenen bekommen sonst je Fläche eigene Ecken – der
    # Export müsste dann jede Ecke vervielfachen)
    first = me.uv_layers.new(name="UVMap")
    first.data.foreach_set("uv", np.zeros(len(li) * 2, np.float32))
    layer = me.uv_layers.new(name="AO")
    uv = np.stack([data["ao"][li], data["height"][li]], axis=1)
    layer.data.foreach_set("uv", uv.astype(np.float32).ravel())
    smooth_shading(obj)
    me.materials.append(mat)
    bind(obj, arm, R.prune(data["W"]), names)
    return obj


def hair_data(style, body, names):
    """Frisur als Netz: Raster-Oberfläche der Form (ohne die Teile tief im Kopf), auf die Form
    gelegt; hängt ganz am Kopf-Knochen."""
    field = O.hair_field(style, body.chin)
    v, q = O.surface_nets(field, field.lo, field.hi, O.HAIR_GRID)
    centers = v[q].mean(axis=1)
    q = q[body.parts["head"].eval_points(centers) > -O.HAIR_HIDDEN]
    used = np.unique(q)
    remap = np.full(len(v), -1, np.int64)
    remap[used] = np.arange(len(used))
    v, q = v[used], remap[q]
    tmp = mesh_from_arrays("tmp_hair", v, q)
    fit_to_shape(tmp, field, relax=2)
    p = coords(tmp)
    faces = np.array([list(f.vertices) for f in tmp.data.polygons], np.int64)
    n = vertex_normals(tmp)
    bpy.data.objects.remove(tmp)
    both = S.Group("hair_head", [("union", field, 0.0), ("union", body.parts["head"], 0.0)])
    ao = S.ambient_occlusion(both, p, n, strength=0.6)
    W = np.zeros((len(p), len(names)))
    W[:, names.index("Head")] = 1.0
    return {"P": {"Basis": p}, "faces": faces, "W": W, "ao": ao, "height": p[:, 2]}


def build_outfit(obj, arm, bodies, weights, names, offsets):
    """Alle Kleidungsstücke und Frisuren der Figur (in Godot einzeln ein-/ausblendbar)."""
    body = bodies["medium"]
    keys = obj.data.shape_keys.key_blocks
    P = {}
    for key_name in ("Basis", "thin", "fat"):
        a = np.zeros(len(obj.data.vertices) * 3, np.float32)
        keys[key_name].data.foreach_get("co", a)
        P[key_name] = a.reshape(-1, 3).astype(np.float64)
    faces = np.array([list(f.vertices) for f in obj.data.polygons], np.int64)
    ao = vertex_ao(obj)
    # Körperform je Formregler und Verschiebung von Armen/Beinen je Ecke (die Formregler sind ohne
    # sie gespeichert, die Form selbst hat sie)
    fields = {"Basis": body.root, "thin": bodies["thin"].root, "fat": bodies["fat"].root}
    shifts = {"Basis": np.zeros_like(P["Basis"])}
    for shape in ("thin", "fat"):
        sh = np.zeros_like(P["Basis"])
        for root, d in offsets[shape].items():
            sh += weights[:, R.chain_children(names, root)].sum(axis=1)[:, None] * np.asarray(d)[None, :]
        shifts[shape] = sh
    parts = []
    for name, spec in O.garment_specs(body).items():
        data = O.shell(P, faces, weights, ao, fields=fields, shifts=shifts, **spec)
        mat = principled("cloth_" + name, O.PREVIEW_COLORS[name], rough=0.8)
        parts.append(piece_object("Cloth_" + name, data, arm, names, mat))
    data = O.skirt(bodies, names, offsets)
    parts.append(piece_object("Cloth_skirt", data, arm, names, principled("cloth_skirt", O.PREVIEW_COLORS["skirt"], rough=0.8)))
    for style in O.HAIRS:
        data = hair_data(style, body, names)
        parts.append(piece_object("Hair_" + style, data, arm, names, principled("hair_" + style, O.PREVIEW_COLORS["hair"], rough=0.45)))
    for o in parts:
        print(f"  {o.name}: {len(o.data.polygons)} Flächen")
    return parts


RELAX_ANGLE = 57.0   # Kontrollbilder: Arme so viel Grad aus der T-Pose heruntergenommen
FAT_RELAX_LESS = 8.0    # dicke Figuren: Arme so viel Grad weniger tief (wie ChibiCharacter)
SHOULDER_SHARE = 6.0    # davon übernimmt das Schlüsselbein (wie ChibiCharacter.SHOULDER_SHARE)


def _rotate(arm, bone, axis, deg):
    """Knochen um eine Achse im Skelett-Raum drehen (zusätzlich zur bisherigen Drehung)."""
    pb = arm.pose.bones[bone]
    rest = pb.bone.matrix_local.to_3x3()
    r = Matrix.Rotation(math.radians(deg), 3, axis)
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = (rest.inverted() @ r @ rest).to_quaternion() @ pb.rotation_quaternion


def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)


def pose_relaxed(arm, angle=None):
    """Arme aus der T-Pose locker herunter (für die Kontrollbilder, wie ChibiCharacter)."""
    angle = RELAX_ANGLE if angle is None else angle
    for side, s in (("Left", 1), ("Right", -1)):
        for bone in (side + "Shoulder", side + "UpperArm", side + "LowerArm"):
            pb = arm.pose.bones[bone]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
        share = min(SHOULDER_SHARE, angle)
        _rotate(arm, side + "Shoulder", "Y", s * share)
        _rotate(arm, side + "UpperArm", "Y", s * (angle - share))
        _rotate(arm, side + "LowerArm", "Z", -s * 12)


def set_shape(figs, name):
    """Formregler setzen und Arme/Beine samt Knochen verschieben (wie ChibiCharacter in Godot)."""
    for arm, _body, parts, offsets in figs:
        for o in parts:
            if o.data.shape_keys is None:
                continue
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 1.0 if kb.name == name else 0.0
        for pb in arm.pose.bones:
            pb.location = (0, 0, 0)
        if name in offsets:
            for bone, d in offsets[name].items():
                pb = arm.pose.bones[bone]
                pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector(d)
        posed = arm.pose.bones["LeftUpperArm"].rotation_quaternion.angle > 0.01
        if posed:
            pose_relaxed(arm, RELAX_ANGLE - (FAT_RELAX_LESS if name == "fat" else 0.0))
    bpy.context.view_layer.update()


# ---------------------------------------------------------------------------------------------
# Kontrollbilder
# ---------------------------------------------------------------------------------------------

REFERENCE = os.path.join(ROOT, "screenshots", "chibi_reference.png")


def load_png(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    px = np.flipud(np.array(im.pixels[:]).reshape(h, w, 4))
    bpy.data.images.remove(im)
    return px


def shot(cam, target, lens=50, size=None):
    """Ein Bild rendern und als Feld (Pixel) liefern."""
    scene = bpy.context.scene
    old = scene.render.resolution_x, scene.render.resolution_y
    if size:
        scene.render.resolution_x = scene.render.resolution_y = size
    path = os.path.join(SHOT_DIR, "tile.png")
    C.render(path, tuple(cam), tuple(target), lens=lens)
    scene.render.resolution_x, scene.render.resolution_y = old
    return load_png(path)


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


# Kontrollbilder: welche Kleidungsstücke/Frisur je Figur zu sehen sind (Name des Skeletts →
# Namen der Teile); ohne Eintrag nur der Körper
WORN = {}


def base_name(o):
    return o.name.split(".")[0]


def worn(fig, o):
    return base_name(o) == "Body" or base_name(o) in WORN.get(fig[0].name, ())


def dress(fig, pieces):
    """Figur für die Kontrollbilder anziehen (pieces = z. B. ["tshirt", "trousers", "shoes", "bob"])."""
    WORN[fig[0].name] = {("Hair_" if p in O.HAIRS else "Cloth_") + p for p in pieces}
    for o in fig[2]:
        o.hide_render = not worn(fig, o)


def only_visible(figs, keep):
    """Nur die Figur keep rendern (die anderen stehen sonst bei Seitenansichten im Bild)."""
    for f in figs:
        for o in f[2]:
            o.hide_render = (keep is not None and f is not keep) or not worn(f, o)


def compare_with_reference(figs):
    """Vorlage (falls vorhanden) und Figuren nebeneinander, gleicher Maßstab (Kopf = 30 %)."""
    tiles = []
    if os.path.exists(REFERENCE):
        tiles.append(load_png(REFERENCE)[:, 430:930])
    for arm, body, parts, _ in figs:
        path = os.path.join(SHOT_DIR, f"ortho_{body.gender}_{body.height_class}.png")
        ortho_render(path, arm.location.x, S.HEIGHTS["female"]["medium"])
        tiles.append(load_png(path)[:, 262:762])
    F.write_png(os.path.join(SHOT_DIR, "compare.png"), np.concatenate(tiles, 1))


def around_sheet(figs, suffix=""):
    """Je Geschlecht: von der Seite, von hinten, von der anderen Seite und von vorn."""
    for fig in figs[:2]:
        arm, body = fig[0], fig[1]
        only_visible(figs, fig)
        tiles = []
        for turn in (-90, 180, 90, 0):
            path = os.path.join(SHOT_DIR, "tile.png")
            ortho_render(path, arm.location.x, S.HEIGHTS["male"]["tall"] + 0.05, turn=turn)
            tiles.append(load_png(path)[:, 262:762])
        F.write_png(os.path.join(SHOT_DIR, f"around_{body.gender}{suffix}.png"), np.concatenate(tiles, 1))
    only_visible(figs, None)


def tpose_sheet(figs):
    """Figuren in T-Pose (so wie gebaut, für Mixamo): vorn und hinten, Frau oben, Mann unten."""
    rows = []
    for fig in figs[:2]:
        arm = fig[0]
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
    only_visible(figs, None)


# Bewegungsprobe: Haltungen (Name, Drehungen [(Knochen, Achse, Grad je Seite)], Blickpunkte)
POSES = [
    ("tpose", [], [((0.55, -0.75, 1.05), (0.12, 0, 0.92)), ((0.0, 0.9, 1.1), (0.1, 0, 0.92))]),
    ("down", [("Shoulder", "Y", 6), ("UpperArm", "Y", 60)],
     [((0.0, -1.1, 1.0), (0.0, 0, 0.88)), ((0.75, -0.7, 1.0), (0.1, 0, 0.88))]),
    ("forward", [("UpperArm", "Y", 15), ("UpperArm", "Z", -80)],
     [((0.9, -0.7, 1.1), (0.1, -0.1, 0.92)), ((0.0, 1.0, 1.1), (0.0, 0, 0.92))]),
    ("up", [("Shoulder", "Y", -18), ("UpperArm", "Y", -60)],
     [((0.0, -1.2, 1.15), (0.0, 0, 1.0)), ((0.8, -0.6, 1.0), (0.12, 0, 1.0))]),
    ("elbow", [("UpperArm", "Y", 50), ("LowerArm", "Z", -100), ("Hand", "X", 30)],
     [((0.6, -0.8, 1.0), (0.2, -0.1, 0.9)), ((0.3, -0.9, 0.85), (0.3, 0, 0.85))]),
    ("fist", [("UpperArm", "Y", 60)] + [(f + p, "Y", 70) for f in ("Index", "Middle", "Ring", "Little")
                                       for p in ("Proximal", "Intermediate", "Distal")]
     + [("ThumbProximal", "Z", 30), ("ThumbDistal", "Z", 30)],
     [((0.55, -0.55, 0.72), (0.3, 0.0, 0.68)), ((0.65, 0.2, 0.6), (0.3, 0.0, 0.68))]),
    ("sit", [("UpperLeg", "X", -90), ("LowerLeg", "X", 90), ("UpperArm", "Y", 60)],
     [((1.0, -0.6, 0.75), (0.0, -0.15, 0.6)), ((0.0, -1.2, 0.75), (0.0, -0.1, 0.6))]),
    ("walk", [("UpperArm", "Y", 65)], [((1.1, -0.2, 0.6), (0.0, 0, 0.5)), ((0.0, -1.3, 0.6), (0, 0, 0.5))]),
]
WALK = [("LeftUpperLeg", "X", -30), ("LeftLowerLeg", "X", 45), ("RightUpperLeg", "X", 20)]


def apply_pose(arm, name):
    reset_pose(arm)
    for pname, rots, _ in POSES:
        if pname != name:
            continue
        for side, s in (("Left", 1), ("Right", -1)):
            for bone, axis, deg in rots:
                full = side + bone
                if full not in arm.pose.bones:
                    continue
                # Drehungen um y und z spiegeln sich mit der Seite, um x nicht
                _rotate(arm, full, axis, deg * (s if axis in ("Y", "Z") else 1.0))
        if name == "walk":
            for bone, axis, deg in WALK:
                _rotate(arm, bone, axis, deg)
    bpy.context.view_layer.update()


def poses_sheet(figs, size=420):
    """Bewegungsprobe mit hartem Licht: Arme runter/vor/hoch, Ellbogen, Faust, Sitzen, Gehen."""
    sun = bpy.data.objects["Sun"]
    old_angle, old_energy = sun.data.angle, sun.data.energy
    sun.data.angle = math.radians(2)
    sun.data.energy = 4.0
    for fig in figs[:2]:
        arm, body = fig[0], fig[1]
        only_visible(figs, fig)
        x0 = Vector((arm.location.x, 0, 0))
        tiles = []
        for name, _, cams in POSES:
            apply_pose(arm, name)
            row = [shot(Vector(c) + x0, Vector(t) + x0, size=size) for c, t in cams]
            tiles.append(np.concatenate(row, 1))
        grid = [np.concatenate(tiles[i:i + 2], 1) for i in range(0, len(tiles), 2)]
        F.write_png(os.path.join(SHOT_DIR, f"poses_{body.gender}.png"), np.concatenate(grid, 0))
        reset_pose(arm)
        pose_relaxed(arm)
    only_visible(figs, None)
    sun.data.angle, sun.data.energy = old_angle, old_energy


OUTFITS = {
    "female": [["tshirt", "trousers", "shoes", "bob"], ["sweater", "skirt", "shoes", "pigtails"],
               ["tshirt", "skirt", "shoes", "bun"]],
    "male": [["tshirt", "trousers", "shoes", "short"], ["sweater", "trousers", "shoes", "short"],
             ["sweater", "trousers", "shoes", "bun"]],
}


def outfits_sheet(figs, size=460):
    """Kleidung und Frisuren: je Figur drei Kombinationen von vorn, schräg und hinten, dazu
    Gehen und Sitzen mit der ersten Kombination (nichts darf durchschauen)."""
    sun = bpy.data.objects["Sun"]
    for fig in figs[:2]:
        arm, body = fig[0], fig[1]
        x0 = Vector((arm.location.x, 0, 0))
        rows = []
        for pieces in OUTFITS[body.gender]:
            dress(fig, pieces)
            only_visible(figs, fig)
            reset_pose(arm)
            pose_relaxed(arm)
            bpy.context.view_layer.update()
            row = [shot(Vector(c) + x0, Vector(t) + x0, size=size)
                   for c, t in (((0.0, -2.6, 1.0), (0, 0, 0.8)), ((1.9, -1.7, 1.05), (0, 0, 0.8)),
                                ((-0.6, 2.5, 1.0), (0, 0, 0.8)), ((0.55, -1.0, 1.35), (0, 0, body.chin + 0.2)))]
            rows.append(np.concatenate(row, 1))
        dress(fig, OUTFITS[body.gender][0])
        only_visible(figs, fig)
        old_angle = sun.data.angle
        sun.data.angle = math.radians(3)
        row = []
        for name in ("walk", "sit", "forward", "elbow"):
            apply_pose(arm, name)
            cams = [c for n, _, c in POSES if n == name][0]
            row.append(shot(Vector(cams[0][0]) + x0, Vector(cams[0][1]) + x0, size=size))
        sun.data.angle = old_angle
        rows.append(np.concatenate(row, 1))
        reset_pose(arm)
        pose_relaxed(arm)
        F.write_png(os.path.join(SHOT_DIR, f"outfits_{body.gender}.png"), np.concatenate(rows, 0))
        dress(fig, [])
    only_visible(figs, None)


def wire_sheet(figs, size=520):
    """Netz sichtbar (Drahtgitter über der Haut): Rumpf, Schulter, Hand und Kopf in T-Pose."""
    for fig in figs[:2]:
        arm, body, parts = fig[0], fig[1], fig[2]
        only_visible(figs, fig)
        arm.data.pose_position = "REST"
        obj = parts[0]
        wire = obj.modifiers.new("Wire", "WIREFRAME")
        wire.thickness = 0.0012
        wire.use_replace = False
        wire.material_offset = 5
        dark = principled("wire_dark", (0.15, 0.12, 0.12), ao=False)
        obj.data.materials.append(dark)
        x0 = Vector((arm.location.x, 0, 0))
        sz = body.shoulder_z
        wx = body.joints_arm["Left"]["wrist"]
        cams = [((0.0, -1.2, 0.85), (0.0, 0, 0.8)), ((0.55, -0.45, sz + 0.05), (0.14, 0, sz)),
                ((wx[0] + 0.05, -0.02, sz + 0.32), (wx[0] + 0.05, 0, sz)), ((wx[0] + 0.05, -0.05, sz - 0.32), (wx[0] + 0.05, 0, sz)),
                ((0.45, -0.75, body.chin + 0.2), (0, 0, body.chin + 0.2)), ((0.3, -0.5, 0.2), (0.09, -0.03, 0.1))]
        tiles = [shot(Vector(c) + x0, Vector(t) + x0, lens=50 if i == 0 else 60, size=size) for i, (c, t) in enumerate(cams)]
        F.write_png(os.path.join(SHOT_DIR, f"wire_{body.gender}.png"),
                    np.concatenate([np.concatenate(tiles[:3], 1), np.concatenate(tiles[3:], 1)], 0))
        obj.modifiers.remove(wire)
        obj.data.materials.pop()
        arm.data.pose_position = "POSE"
    only_visible(figs, None)


def hands_sheet(figs, size=460):
    """Hand in T-Pose von oben, unten, vorn und hängend von vorn und von der Seite."""
    for fig in figs[:2]:
        arm, body = fig[0], fig[1]
        only_visible(figs, fig)
        x0 = Vector((arm.location.x, 0, 0))
        w = Vector(body.joints_arm["Left"]["wrist"]) + x0
        c = w + Vector((0.06, 0.0, 0.0))
        reset_pose(arm)
        bpy.context.view_layer.update()
        tiles = [shot(c + Vector((0.0, -0.02, 0.36)), c, lens=60, size=size),
                 shot(c + Vector((0.0, -0.02, -0.36)), c, lens=60, size=size),
                 shot(c + Vector((0.04, -0.36, 0.05)), c, lens=60, size=size)]
        pose_relaxed(arm)
        bpy.context.view_layer.update()
        hand = arm.matrix_world @ arm.pose.bones["LeftHand"].head
        tiles.append(shot(hand + Vector((0.05, -0.42, -0.02)), hand + Vector((0.0, 0, -0.05)), lens=60, size=size))
        tiles.append(shot(hand + Vector((0.42, -0.05, -0.02)), hand + Vector((0.0, 0, -0.05)), lens=60, size=size))
        tiles.append(shot(hand + Vector((0.30, 0.30, 0.0)), hand + Vector((0.0, 0, -0.05)), lens=60, size=size))
        F.write_png(os.path.join(SHOT_DIR, f"hands_{body.gender}.png"),
                    np.concatenate([np.concatenate(tiles[:3], 1), np.concatenate(tiles[3:], 1)], 0))
    only_visible(figs, None)


def gender_lineups(figs):
    """Je Geschlecht ein Bild: Zeilen dünn/mittel/dick, Spalten klein/mittel/groß."""
    for gender in ("female", "male"):
        group = [f for f in figs if f[1].gender == gender]
        if not group:
            continue
        cx = sum(f[0].location.x for f in group) / len(group)
        for f in figs:
            for o in f[2]:
                o.hide_render = f[1].gender != gender
        rows = []
        for name in ("thin", "medium", "fat"):
            set_shape(group, name)
            path = os.path.join(SHOT_DIR, "tile.png")
            C.render(path, (cx, -4.4, 0.95), (cx, 0, 0.86), lens=50)
            rows.append(load_png(path))
        set_shape(group, "medium")
        only_visible(figs, None)
        F.write_png(os.path.join(SHOT_DIR, f"lineup_{gender}.png"), np.concatenate(rows, 0))


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


def head_tiles(arm, body, items, size):
    """Kopf-Nahaufnahmen; items = [(Ausdruck, Augenform)]."""
    name = f"face_{body.gender}_{body.height_class}"
    tiles = []
    for e, shape in items:
        face_image(name, e, body.gender, shape=shape)
        z = body.chin + 0.2
        tiles.append(shot((arm.location.x + 0.3, -1.3, z + 0.04), (arm.location.x, 0, z - 0.03), lens=85, size=size))
    face_image(name, "neutral", body.gender)
    return tiles


def eyes_sheet(figs, size=360):
    """Augenformen zur Auswahl: je Zeile eine Form (3 Frau, 3 Mann), Spalten = Ausdrücke."""
    moods = ("neutral", "happy", "laugh", "surprised", "sad", "angry", "wink", "embarrassed")
    for fig in figs[:2]:
        arm, body = fig[0], fig[1]
        only_visible(figs, fig)
        rows = [np.concatenate(head_tiles(arm, body, [(m, shape) for m in moods], size), 1)
                for shape in F.SHAPE_NAMES[body.gender]]
        F.write_png(os.path.join(SHOT_DIR, f"eyes_{body.gender}.png"), np.concatenate(rows, 0))
    only_visible(figs, None)


def heads_sheet(figs, size=520):
    """Kopf von vorn, schräg und im Profil (Kinn, Kiefer, Ohren), Frau oben, Mann unten."""
    rows = []
    for fig in figs[:2]:
        arm, body = fig[0], fig[1]
        only_visible(figs, fig)
        x0 = arm.location.x
        z = body.chin + 0.17
        rows.append(np.concatenate([shot((x0 + dx * 1.9, dy * 1.9, z + 0.05), (x0, 0.0, z - 0.04), lens=70, size=size)
                                    for dx, dy in ((0.0, -1.0), (0.7, -0.7), (1.0, 0.0), (0.7, 0.7))], 1))
    F.write_png(os.path.join(SHOT_DIR, "heads.png"), np.concatenate(rows, 0))
    only_visible(figs, None)


def armpits_sheet(figs, size=360):
    """Achseln aus der Nähe (Arme hängend): Zeilen = Figuren, Spalten = dünn/mittel/dick × vorn/schräg."""
    rows = []
    for fig in figs:
        arm, body = fig[0], fig[1]
        only_visible(figs, fig)
        tiles = []
        z = body.shoulder_z - 0.06
        x0 = arm.location.x
        for name in ("thin", "medium", "fat"):
            set_shape([fig], name)
            for cam in ((x0, -1.2, z + 0.05), (x0 + 0.75, -0.9, z + 0.1)):
                tiles.append(shot(cam, (x0, 0, z), lens=60, size=size))
        set_shape([fig], "medium")
        rows.append(np.concatenate(tiles, 1))
    F.write_png(os.path.join(SHOT_DIR, "armpits.png"), np.concatenate(rows, 0))
    only_visible(figs, None)


def collision_check(figs):
    """Ragen die locker hängenden Arme in den Rumpf? (je Figur und Form, kleinster Abstand in mm)"""
    dg = bpy.context.evaluated_depsgraph_get()
    for fig in figs:
        arm, body, parts = fig[0], fig[1], fig[2]
        obj = parts[0]
        groups = {g.index: g.name for g in obj.vertex_groups}
        armw = np.zeros(len(obj.data.vertices))
        for v in obj.data.vertices:
            for g in v.groups:
                if any(b in groups[g.group] for b in R.ARM_BONES):
                    armw[v.index] += g.weight
        idx = np.nonzero(armw > 0.95)[0]
        line = []
        for name in ("thin", "medium", "fat"):
            set_shape([fig], name)
            pose_relaxed(arm, RELAX_ANGLE - (FAT_RELAX_LESS if name == "fat" else 0.0))
            dg.update()
            ev = obj.evaluated_get(dg)
            co = np.array([ev.data.vertices[i].co for i in idx])
            other = S.Body(body.gender, body.height_class, name)
            rest = S.Group("rest", [it for it in other.root.items if it[0] == "union" and not it[1].name.startswith("arm_")])
            d = rest.eval_points(co)
            hits = co[d < 0]
            j = int(np.argmin(d))
            where = f" bei z={co[j, 2]:.2f} x={co[j, 0]:.2f}" if len(hits) else ""
            line.append(f"{name}: {d.min() * 1000:.0f} mm{where} ({len(hits)} Ecken)")
        set_shape([fig], "medium")
        pose_relaxed(arm)
        print("ARME", body.gender, body.height_class, ", ".join(line))


def joints_check(figs):
    """Jedes Gelenk muss innen im Körper liegen (für Mixamo/Godot)."""
    for fig in figs:
        body = fig[1]
        heads = [(n, h) for n, h, t, par in R.bones(body)]
        d = body.root.eval_points(np.array([h for _, h in heads]))
        outside = [(n, round(float(v) * 1000, 1)) for (n, _), v in zip(heads, d) if v > -0.002]
        print("GELENKE", body.gender, body.height_class, len(heads), "Knochen,",
              "alle innen" if not outside else f"außen/am Rand: {outside}")


def underwear_check(figs):
    """Keine bemalte Ecke (Unterwäsche) darf am Arm oder Schlüsselbein hängen."""
    for fig in figs:
        body, obj = fig[1], fig[2][0]
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
                if any(b in n for b in R.ARM_BONES) or n.endswith("Shoulder"):
                    moving[v.index] += g.weight
        bad = int(((d < 0.0005) & (moving > 0.02)).sum())
        print("WAESCHE", body.gender, body.height_class, "bemalte Ecken, die mit Arm/Schulter drehen:", bad)


# ---------------------------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------------------------

FACE_TEX_DIR = os.path.join(ROOT, "assets", "textures", "characters", "chibi_face")


def export_figure(gender, height):
    """Eine Figur bauen und als .glb (Godot), .fbx (Mixamo) und .blend (Quelle) schreiben."""
    C.reset()
    arm, parts, body, offsets = build(gender, height)
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
    # mit unserem Skelett (zuerst hochladen) und, falls Mixamo es nicht nimmt, nur das Netz
    export_mixamo(os.path.join(mixamo, name + ".fbx"), parts[0], arm)
    export_mixamo(os.path.join(mixamo, name + "_mesh_only.fbx"), parts[0])
    os.makedirs(SOURCE_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, name + ".blend"), compress=True)
    print("geschrieben:", name, len(parts[0].data.polygons), "Vierecke")


# Knochennamen für Mixamo: so heißen die Knochen in Mixamos eigenem Skelett. Mit diesen Namen
# erkennt Mixamo unser Skelett und setzt kein eigenes ein (kein Punkte-Setzen nötig).
MIXAMO_SPINE = {"Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2", "Neck": "Neck",
                "Head": "Head"}
MIXAMO_LIMBS = {"Shoulder": "Shoulder", "UpperArm": "Arm", "LowerArm": "ForeArm", "Hand": "Hand",
                "UpperLeg": "UpLeg", "LowerLeg": "Leg", "Foot": "Foot", "Toes": "ToeBase"}
MIXAMO_FINGERS = {"Thumb": "Thumb", "Index": "Index", "Middle": "Middle", "Ring": "Ring", "Little": "Pinky"}


def mixamo_name(bone):
    """Godot-Humanoid-Name → Mixamo-Name (z. B. LeftUpperArm → mixamorig:LeftArm)."""
    if bone in MIXAMO_SPINE:
        return "mixamorig:" + MIXAMO_SPINE[bone]
    for side in ("Left", "Right"):
        if not bone.startswith(side):
            continue
        rest = bone[len(side):]
        if rest in MIXAMO_LIMBS:
            return f"mixamorig:{side}{MIXAMO_LIMBS[rest]}"
        for finger, mixamo in MIXAMO_FINGERS.items():
            if rest.startswith(finger):
                segments = ("Metacarpal", "Proximal", "Distal") if finger == "Thumb" else ("Proximal", "Intermediate", "Distal")
                return f"mixamorig:{side}Hand{mixamo}{segments.index(rest[len(finger):]) + 1}"
    raise ValueError("kein Mixamo-Name für " + bone)


def _mixamo_mesh(body_obj, name="Body"):
    """Kopie des Körpers für Mixamo: ohne Formregler, eine Texturkoordinate, ein Material."""
    obj = body_obj.copy()
    obj.data = body_obj.data.copy()
    obj.name = name
    obj.modifiers.clear()
    obj.parent = None
    bpy.context.scene.collection.objects.link(obj)
    me = obj.data
    if me.shape_keys:
        obj.shape_key_clear()
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    me.materials.clear()
    mat = bpy.data.materials.get("mixamo_skin") or principled("mixamo_skin", SKIN, ao=False)
    # einseitig: Rückseiten ausblenden (beidseitig würde Mixamo die Lichtseite in den Schatten rechnen)
    mat.use_backface_culling = True
    me.materials.append(mat)
    me.polygons.foreach_set("material_index", np.zeros(len(me.polygons), np.int32))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # ordentliche, nicht überlappende Texturkoordinaten (die Gesichts-Abwicklung läuft am Scheitel
    # in einem Punkt zusammen)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Zahlen selbst in Zentimeter umrechnen (1,56 m -> 156)
    me.transform(Matrix.Scale(100.0, 4))
    return obj


def _mixamo_armature(arm, body_obj):
    """Kopie des Skeletts mit Mixamo-Namen, Endknochen wie bei Mixamo und Maßen in Zentimetern."""
    a = arm.copy()
    a.data = arm.data.copy()
    a.name = "Armature"
    a.location = (0, 0, 0)
    bpy.context.scene.collection.objects.link(a)
    for g in body_obj.vertex_groups:
        g.name = mixamo_name(g.name)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.mode_set(mode="EDIT")
    eb = a.data.edit_bones
    for b in list(eb):
        b.name = mixamo_name(b.name)
    # Endknochen (ohne Gewichte): Scheitel, Fingerspitzen, Zehenspitzen
    ends = [("mixamorig:HeadTop_End", "mixamorig:Head", Vector((0, 0, 0.12)))]
    for side in ("Left", "Right"):
        for finger in MIXAMO_FINGERS.values():
            parent = eb[f"mixamorig:{side}Hand{finger}3"]
            ends.append((f"mixamorig:{side}Hand{finger}4", parent.name, (parent.tail - parent.head) * 0.6))
        toe = eb[f"mixamorig:{side}ToeBase"]
        ends.append((f"mixamorig:{side}Toe_End", toe.name, (toe.tail - toe.head) * 0.6))
    for name, parent, d in ends:
        p = eb[parent]
        b = eb.new(name)
        b.head = p.tail.copy()
        b.tail = p.tail + d
        b.roll = p.roll
        b.parent = p
        b.use_deform = False
    # in Zentimeter und schon "y oben, z vorn" wie im FBX (das Skelett-Objekt dreht es in Blender
    # zurück) – so schreibt Blender keine -90°-Drehung an die Knoten (wie bei der Datei ohne Skelett)
    xf = Matrix.Rotation(math.radians(-90.0), 4, "X") @ Matrix.Scale(100.0, 4)
    for b in eb:
        b.transform(xf)
    bpy.ops.object.mode_set(mode="OBJECT")
    a.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    return a


def export_mixamo(path, body_obj, arm=None):
    """Für Mixamo: T-Pose, Maße direkt in Zentimetern (Mixamo beachtet den Maßstab-Faktor im FBX
    nicht – die Figur wäre dort 1,5 cm groß und bekäme dunkle Schattenflecken). Mit arm: samt
    unserem Skelett und den Gewichten (Mixamo-Namen) – Mixamo übernimmt es, die Bewegungen laufen
    dann schon in der Vorschau mit unseren Gelenken. Ohne arm: nur das Netz (Mixamo setzt sein
    eigenes Skelett ein, Punkte setzen)."""
    obj = _mixamo_mesh(body_obj)
    selected = [obj]
    if arm is not None:
        a = _mixamo_armature(arm, obj)
        obj.data.transform(Matrix.Rotation(math.radians(-90.0), 4, "X"))
        obj.parent = a
        m = obj.modifiers.new("Armature", "ARMATURE")
        m.object = a
        selected.append(a)
    # Szene auf Zentimeter: nur so schreibt Blender "Einheit Zentimeter" ohne Faktor 100 am Objekt
    units = bpy.context.scene.unit_settings
    old_scale = units.scale_length
    units.scale_length = 0.01
    bpy.ops.object.select_all(action="DESELECT")
    for o in selected:
        o.select_set(True)
    bpy.context.view_layer.objects.active = selected[-1]
    if arm is None:
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, path_mode="STRIP",
                                 embed_textures=False, bake_anim=False, use_mesh_modifiers=False,
                                 mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=1.0,
                                 apply_scale_options="FBX_SCALE_UNITS", bake_space_transform=True,
                                 axis_forward="-Z", axis_up="Y")
    else:
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "ARMATURE"},
                                 path_mode="STRIP", embed_textures=False, bake_anim=False, use_mesh_modifiers=False,
                                 mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=1.0,
                                 apply_scale_options="FBX_SCALE_UNITS", add_leaf_bones=False,
                                 use_armature_deform_only=False, primary_bone_axis="Y", secondary_bone_axis="X",
                                 axis_forward="-Z", axis_up="Y")
    units.scale_length = old_scale
    for o in selected:
        data = o.data
        bpy.data.objects.remove(o)
        if isinstance(data, bpy.types.Mesh):
            bpy.data.meshes.remove(data)
        else:
            bpy.data.armatures.remove(data)


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
    names = [(g, h) for g in ("female", "male") for h in ("small", "medium", "tall")]
    if only:
        names = [n for n in names if f"{n[0]}_{n[1]}" in only]
    if "--render" not in argv:
        export_face_textures()
        for g, h in names:
            export_figure(g, h)
        return
    C.reset()
    C.setup_render(res=(1200, 900), samples=24)
    # weiches Licht wie bei Vinyl-Figuren im Fotostudio
    sun = bpy.data.objects["Sun"]
    sun.data.angle = math.radians(25)
    sun.data.energy = 2.4
    bpy.context.scene.world.node_tree.nodes["Background"].inputs[1].default_value = 1.3
    x = 0.0
    figs = []
    for g, h in names:
        arm, parts, body, offsets = build(g, h)
        arm.location.x = x
        pose_relaxed(arm)
        figs.append((arm, body, parts, offsets))
        dress(figs[-1], [])
        x += 0.8
    os.makedirs(SHOT_DIR, exist_ok=True)
    cx = (x - 0.8) / 2
    bpy.context.view_layer.update()
    arm0, body0 = figs[0][0], figs[0][1]
    x0 = arm0.location.x
    sheets = {"heads": heads_sheet, "wrists": hands_sheet, "hands": hands_sheet, "around": around_sheet,
              "lineups": gender_lineups, "compare": compare_with_reference, "collide": collision_check,
              "joints": joints_check, "underwear": underwear_check, "armpits": armpits_sheet, "tpose": tpose_sheet,
              "eyes": eyes_sheet, "poses": poses_sheet, "wire": wire_sheet, "outfits": outfits_sheet}
    for v in views:
        path = os.path.join(SHOT_DIR, v + ".png")
        if v in sheets:
            sheets[v](figs)
        elif v == "front":
            C.render(path, (cx, -4.6, 0.95), (cx, 0, 0.82), lens=50)
        elif v == "side":
            C.render(path, (cx + 3.4, -3.2, 1.0), (cx, 0, 0.8), lens=50)
        elif v == "back":
            C.render(path, (cx - 2.0, 4.0, 1.2), (cx, 0, 0.8), lens=50)
        elif v == "head":
            z = body0.chin + 0.2
            C.render(path, (x0 + 0.45, -1.1, z + 0.08), (x0, 0, z), lens=60)
        elif v == "shapes":
            shapes_sheet(figs, cx)
        elif v == "around_fat":
            set_shape(figs, "fat")
            around_sheet(figs, "_fat")
            set_shape(figs, "medium")
        else:
            print("unbekannte Ansicht:", v)


if __name__ == "__main__":
    main()
