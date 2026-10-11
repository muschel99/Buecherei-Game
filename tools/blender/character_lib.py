"""Bausteine für die Figuren (seit Etappe 5b): Grundkörper laden (Quaternius, CC0), Körperformen
als Formregler (Shape Keys), Kleidung als Hülle um den Körper, Röcke und Mäntel, Frisuren aus
dicken Strähnen, Materialien, Export als .glb (Godot) und .fbx (Mixamo), Kontrollbilder.

Koordinaten: Blender (x rechts = linke Körperseite "_l", y nach hinten, z oben); die Figuren
stehen in T-Pose und schauen nach -y (in Godot nach +z).

Grundidee Kleidung: Ein Kleidungsstück ist eine Kopie eines Körperbereichs, ein Stück nach außen
geschoben und geglättet. Jede Ecke behält die Gewichte des Körpers (bewegt sich also genau mit)
und dieselben Formregler (passt zu jeder Körperform). Röcke und Mantelschöße werden als
Glocke um die Beine gebaut. Frisuren: einzelne dicke Strähnen (linsenförmiger Querschnitt,
spitz zulaufend), die vom Scheitel über den Kopf laufen und herabfallen, darunter eine Kappe.
"""

import math
import os
import random

import numpy as _np

# Blenders glTF-Werkzeuge (3.4) nutzen alte numpy-Namen, die neuere numpy-Versionen nicht mehr
# kennen – hier wieder bereitstellen
for _name, _type in (("bool", bool), ("int", int), ("float", float), ("object", object)):
    setattr(_np, _name, _type)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
BASE_DIR = os.path.join(ROOT, "assets", "models", "characters", "base_quaternius")
BODY_FILES = {
    "female": os.path.join(BASE_DIR, "Base Characters", "Godot - UE", "Superhero_Female_FullBody.gltf"),
    "male": os.path.join(BASE_DIR, "Base Characters", "Godot - UE", "Superhero_Male_FullBody.gltf"),
}
SKIN_TEXTURES = {
    ("female", "light"): "T_Superhero_Female_Light_BaseColor.png",
    ("female", "dark"): "T_Superhero_Female_Dark_BaseColor.png",
    ("male", "light"): "T_Superhero_Male_Ligh.png",
    ("male", "dark"): "T_Superhero_Male_Dark.png",
}
TEXTURE_DIR = os.path.join(BASE_DIR, "Base Characters", "Textures")

# Körperteile (für den Baukasten): Ein Kleidungsstück blendet die Teile aus, die es ganz bedeckt
SEGMENTS = {
    "Head": ("Head", "neck_01"),
    "Torso": ("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"),
    "Hips": ("pelvis",),
    "UpperArms": ("upperarm_l", "upperarm_r"),
    "LowerArms": ("lowerarm_l", "lowerarm_r"),
    "Hands": ("hand_l", "hand_r"),
    "Thighs": ("thigh_l", "thigh_r"),
    "Calves": ("calf_l", "calf_r"),
    "Feet": ("foot_l", "foot_r", "ball_l", "ball_r"),
}


# ---------------------------------------------------------------------------------------------
# Laden und Maße
# ---------------------------------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load_base(kind):
    """Grundkörper laden; liefert dict mit arm (Skelett), body, eyes, brows und den Maßen lm."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=BODY_FILES[kind])
    new = [o for o in bpy.data.objects if o not in before]
    arm = [o for o in new if o.type == "ARMATURE"][0]
    meshes = [o for o in new if o.type == "MESH"]
    body = max(meshes, key=lambda o: len(o.data.vertices))
    eyes = [o for o in meshes if any("Eye" in m.name for m in o.data.materials)][0]
    brows = [o for o in meshes if o not in (body, eyes)][0]
    arm.name = "Skeleton"
    body.name, eyes.name, brows.name = "Body", "Eyes", "Eyebrows"
    weld(body)
    for o in (body, eyes, brows):
        o.data.name = o.name
    return {"kind": kind, "arm": arm, "body": body, "eyes": eyes, "brows": brows, "lm": landmarks(arm, body)}


def weld(obj, dist=1e-5):
    """Ecken an Texturnähten zusammenfügen (der Import trennt sie; beim Glätten und Aufblähen
    würden die Nähte sonst aufreißen). Texturkoordinaten bleiben je Fläche erhalten."""
    me = obj.data
    if me.has_custom_normals:
        bpy.context.view_layer.objects.active = obj
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.update()


def landmarks(arm, body):
    """Wichtige Punkte der T-Pose aus dem Skelett (Welt = Modell, alles steht im Ursprung)."""
    bones = arm.data.bones
    lm = {}
    for b in bones:
        lm[b.name] = (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local)
    h = lambda n: lm[n][0]  # noqa: E731
    t = lambda n: lm[n][1]  # noqa: E731
    zs = [v.co.z for v in body.data.vertices]
    top = max(zs)
    head_c = Vector((0.0, h("Head").y - 0.005, (h("Head").z + top) / 2 - 0.005))
    m = {
        "top": top,
        "head_c": head_c,
        "head_r": top - head_c.z,
        "neck": t("neck_01"),
        "chest_z": (h("spine_03").z + t("spine_03").z) / 2,
        "shoulder_z": h("upperarm_l").z,
        "shoulder_x": h("upperarm_l").x,
        "elbow_x": h("lowerarm_l").x,
        "wrist_x": h("hand_l").x,
        "waist_z": h("spine_01").z + 0.03,
        "hip_z": h("pelvis").z,
        "crotch_z": h("thigh_l").z - 0.12,
        "knee_z": h("calf_l").z,
        "ankle_z": h("foot_l").z,
        "leg_x": h("thigh_l").x,
        "bones": lm,
    }
    return m


def body_bvh(obj, use_basis=True):
    """BVH der Körperoberfläche (Grundform) in Modell-Koordinaten."""
    me = obj.data
    verts = [v.co.copy() for v in me.vertices]
    if use_basis and me.shape_keys:
        verts = [d.co.copy() for d in me.shape_keys.key_blocks[0].data]
    polys = [tuple(p.vertices) for p in me.polygons]
    return BVHTree.FromPolygons(verts, polys)


def dominant_bone(obj, v):
    best, w = None, 0.0
    for g in v.groups:
        if g.weight > w:
            best, w = obj.vertex_groups[g.group].name, g.weight
    return best


def weights_of(obj, v):
    return {obj.vertex_groups[g.group].name: g.weight for g in v.groups if g.weight > 0.0}


# ---------------------------------------------------------------------------------------------
# Körperformen
# ---------------------------------------------------------------------------------------------

def _segment_point(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return a + ab * t, t


def radial_field(base, amounts, front=None, smooth_falloff=None):
    """Verschiebung je Körperecke: Jeder Knochen bläht die Ecken um seine Achse um amounts[knochen]
    Meter auf (negativ = schlanker), gewichtet nach den Skin-Gewichten. front = dict knochen ->
    zusätzliche Menge nur nach vorn (Bauch, Brust)."""
    body, lm = base["body"], base["lm"]
    out = []
    for v in body.data.vertices:
        d = Vector()
        for name, w in weights_of(body, v).items():
            amount = amounts.get(name, 0.0)
            extra = (front or {}).get(name, 0.0)
            if not amount and not extra:
                continue
            a, b = lm["bones"][name]
            p, t = _segment_point(v.co, a, b)
            r = v.co - p
            if r.length < 1e-6:
                continue
            r.normalize()
            fade = smooth_falloff(t) if smooth_falloff else 1.0
            d += r * (amount * w * fade)
            if extra:
                # Nach vorn (-y): voll; zur Seite halb; hinten nichts
                fwd = max(0.0, -r.y) + 0.35 * max(0.0, 1.0 - abs(r.y) * 1.4)
                d += r * (extra * w * fwd * fade)
        out.append(d)
    return out


def add_shape_key(base, name, deltas):
    body = base["body"]
    if not body.data.shape_keys:
        body.shape_key_add(name="Basis", from_mix=False)
    key = body.shape_key_add(name=name, from_mix=False)
    basis = body.data.shape_keys.key_blocks[0]
    for i, d in enumerate(deltas):
        key.data[i].co = basis.data[i].co + d
    key.value = 0.0
    return key


def smooth_vertices(obj, indices, iterations=6, factor=0.5, keep=None):
    """Laplace-Glättung der Grundform an den Ecken indices (nimmt Muskeln die Härte)."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    sel = set(indices)
    co = [v.co.copy() for v in bm.verts]
    neigh = {i: [e.other_vert(bm.verts[i]).index for e in bm.verts[i].link_edges] for i in sel}
    for _ in range(iterations):
        new = list(co)
        for i in sel:
            if keep and i in keep:
                continue
            nb = neigh[i]
            if not nb:
                continue
            avg = sum((co[j] for j in nb), Vector()) / len(nb)
            new[i] = co[i].lerp(avg, factor)
        co = new
    for i in sel:
        me.vertices[i].co = co[i]
    bm.free()


def soften_body(base, strength=1.0):
    """Superhelden-Muskeln weicher machen (Bauch, Brust, Arme, Beine) – Gesicht, Hände und Füße
    bleiben, wie sie sind."""
    body = base["body"]
    soft = {"spine_01", "spine_02", "spine_03", "pelvis", "upperarm_l", "upperarm_r", "lowerarm_l",
            "lowerarm_r", "thigh_l", "thigh_r", "calf_l", "calf_r", "clavicle_l", "clavicle_r"}
    idx = [v.index for v in body.data.vertices if dominant_bone(body, v) in soft]
    smooth_vertices(body, idx, iterations=int(4 * strength) + 1, factor=0.45)


def scale_head(base, factor):
    """Kopf etwas größer (verspielter, wie in Disney-Filmen): um den Halsansatz skalieren; Augen
    und Brauen mit. Ecken mit nur teilweisem Kopf-Gewicht werden anteilig mitgenommen."""
    lm = base["lm"]
    pivot = lm["neck"].copy()
    for obj in (base["body"], base["eyes"], base["brows"]):
        for v in obj.data.vertices:
            w = 0.0
            for g in v.groups:
                n = obj.vertex_groups[g.group].name
                if n == "Head":
                    w += g.weight
                elif n == "neck_01":
                    w += g.weight * 0.35
            if w <= 0.0:
                continue
            v.co = pivot + (v.co - pivot) * (1.0 + (factor - 1.0) * min(1.0, w))
    # Maße neu (Kopfoberkante)
    base["lm"] = landmarks(base["arm"], base["body"])


def scale_character(base, factor):
    """Ganze Figur größer/kleiner (Füße bleiben auf dem Boden): Skelett und Netze skalieren und die
    Skalierung übernehmen."""
    arm = base["arm"]
    arm.scale = (factor, factor, factor)
    bpy.ops.object.select_all(action="DESELECT")
    for o in [arm] + list(arm.children):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    base["lm"] = landmarks(arm, base["body"])


# ---------------------------------------------------------------------------------------------
# Kleidung als Hülle
# ---------------------------------------------------------------------------------------------

def _copy_object(obj, name):
    new = obj.copy()
    new.data = obj.data.copy()
    new.name = name
    new.data.name = name
    for c in obj.users_collection:
        c.objects.link(new)
    return new


def _key_coords(me):
    """Liste der Formregler-Koordinaten (Grundform zuerst) oder nur die Ecken."""
    if me.shape_keys:
        return [[d.co.copy() for d in kb.data] for kb in me.shape_keys.key_blocks]
    return [[v.co.copy() for v in me.vertices]]


def _write_keys(me, keys):
    if me.shape_keys:
        for kb, cos in zip(me.shape_keys.key_blocks, keys):
            for d, c in zip(kb.data, cos):
                d.co = c
        for v, c in zip(me.vertices, keys[0]):
            v.co = c
    else:
        for v, c in zip(me.vertices, keys[0]):
            v.co = c


def shell(base, name, select, offset, mat, smooth=8, smooth_factor=0.5, lip=0.006, push_min=None,
          offset_fn=None, keep_boundary=False, cuts=()):
    """Kleidungsstück als Hülle: Körperecken, für die select(co, knochen) True liefert, werden
    kopiert, um offset (oder offset_fn(co)) entlang der Normale nach außen geschoben, geglättet und
    überall mindestens push_min vom Körper entfernt gehalten. Am Rand eine Kante nach innen (lip),
    damit man Stoffdicke sieht und nicht hineinschaut."""
    body = base["body"]
    obj = _copy_object(body, name)
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    deform = bm.verts.layers.deform.active
    names = {i: g.name for i, g in enumerate(obj.vertex_groups)}
    kill = []
    for v in bm.verts:
        bone = None
        if deform is not None and v[deform]:
            gi, _ = max(v[deform].items(), key=lambda kv: kv[1])
            bone = names.get(gi)
        if not select(v.co, bone):
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    # Gerade Säume: an Ebenen abschneiden (Punkt, Richtung zur Seite, die bleibt)
    for cut in cuts:
        co, no = cut[0], cut[1]
        region = cut[2] if len(cut) > 2 else None
        if region is None:
            geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        else:
            # Nur in einem Bereich schneiden (z. B. Halsausschnitt, nicht die Schultern)
            faces = [f for f in bm.faces if region(f.calc_center_median())]
            verts = list({v for f in faces for v in f.verts})
            edges = list({e for f in faces for e in f.edges})
            geom = verts + edges + faces
        if geom:
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no).normalized(), clear_inner=True)
    # Kleine Inseln (einzelne Ecken an Rändern) entfernen
    loose = [v for v in bm.verts if len(v.link_faces) == 0]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.update()
    keys = _key_coords(me)
    basis = keys[0]
    normals = [v.normal.copy() for v in me.vertices]
    moved = []
    for i, c in enumerate(basis):
        off = offset_fn(c) if offset_fn else offset
        moved.append(c + normals[i] * off)
    _write_keys(me, [moved] + [[k[i] + (moved[i] - basis[i]) for i in range(len(basis))] for k in keys[1:]])
    me.update()
    if smooth:
        bnd = _boundary_indices(me) if keep_boundary else None
        old = [v.co.copy() for v in me.vertices]
        smooth_vertices(obj, range(len(me.vertices)), iterations=smooth, factor=smooth_factor, keep=bnd)
        new = [v.co.copy() for v in me.vertices]
        keys = _key_coords(me)
        _write_keys(me, [new] + [[k[i] + (new[i] - old[i]) for i in range(len(new))] for k in keys[1:]])
    if push_min is None or push_min >= 0:
        _push_out(obj, base, push_min if push_min is not None else offset * 0.6)
    if lip:
        _add_lip(obj, lip + (offset if not offset_fn else 0.0))
    _clear_shading(obj)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def drape(obj, center, z_from, segments=36):
    """Unterhalb z_from fällt der Stoff gerade herab: Jede Ecke rückt in ihrem Winkel um die Mitte
    auf den äußersten Punkt dieser Höhe (füllt Mulden zwischen den Beinen)."""
    me = obj.data
    keys = _key_coords(me)
    for cos in keys:
        bins = {}
        for c in cos:
            if c.z > z_from + 0.06:
                continue
            d = Vector((c.x - center.x, c.y - center.y))
            k = int(((math.atan2(d.x, -d.y)) % (2 * math.pi)) / (2 * math.pi) * segments) % segments
            band = int((z_from + 0.06 - c.z) / 0.03)
            bins[(band, k)] = max(bins.get((band, k), 0.0), d.length)
        for i, c in enumerate(cos):
            if c.z > z_from:
                continue
            d = Vector((c.x - center.x, c.y - center.y))
            if d.length < 1e-6:
                continue
            k = int(((math.atan2(d.x, -d.y)) % (2 * math.pi)) / (2 * math.pi) * segments) % segments
            # Größter Radius in diesem Winkel (Nachbarwinkel mit) ab z_from abwärts
            r = 0.0
            for (band, kk), rr in bins.items():
                if min(abs(kk - k), segments - abs(kk - k)) <= 1:
                    r = max(r, rr * (0.97 if kk != k else 1.0))
            w = min(1.0, (z_from - c.z) / 0.05)
            target = d.normalized() * max(d.length, r)
            nd = d.lerp(target, w)
            cos[i] = Vector((center.x + nd.x, center.y + nd.y, c.z))
    _write_keys(me, keys)
    me.update()


def _boundary_indices(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    out = {v.index for v in bm.verts if any(e.is_boundary for e in v.link_edges)}
    bm.free()
    return out


def _push_out(obj, base, min_dist):
    """Jede Ecke mindestens min_dist außerhalb des Körpers (Grundform und alle Formregler)."""
    me = obj.data
    body = base["body"]
    keys = _key_coords(me)
    body_keys = _key_coords(body.data)
    for ki, cos in enumerate(keys):
        bk = body_keys[min(ki, len(body_keys) - 1)]
        tree = BVHTree.FromPolygons(bk, [tuple(p.vertices) for p in body.data.polygons])
        for i, c in enumerate(cos):
            loc, nrm, _, dist = tree.find_nearest(c)
            if loc is None:
                continue
            side = (c - loc).dot(nrm)
            if side < min_dist:
                cos[i] = loc + nrm * min_dist + (c - loc - nrm * side) * 0.0
    _write_keys(me, keys)
    me.update()


def _add_lip(obj, depth):
    """Am offenen Rand eine schmale Fläche nach innen (Stoffkante). Die neuen Ecken folgen in
    allen Formreglern ihrer Herkunftsecke."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    shapes = list(bm.verts.layers.shape.values())
    edges = [e for e in bm.edges if e.is_boundary]
    if not edges:
        bm.free()
        return
    res = bmesh.ops.extrude_edge_only(bm, edges=edges)
    new_verts = set(g for g in res["geom"] if isinstance(g, bmesh.types.BMVert))
    for v in new_verts:
        src = [e.other_vert(v) for e in v.link_edges if e.other_vert(v) not in new_verts]
        if not src:
            continue
        s = src[0]
        delta = -s.normal * depth
        v.co = s.co + delta
        for layer in shapes:
            v[layer] = s[layer] + delta
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()


def _clear_shading(obj):
    me = obj.data
    if me.has_custom_normals:
        bpy.context.view_layer.objects.active = obj
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for p in me.polygons:
        p.use_smooth = True


# ---------------------------------------------------------------------------------------------
# Glocken: Röcke, Mantelschöße
# ---------------------------------------------------------------------------------------------

def bell(base, name, top_z, bottom_z, mat, flare=0.08, offset=0.012, rings=12, segments=40, lip=0.006,
         open_front=0.0, thigh_share=0.55):
    """Rock/Mantelschoß als Glocke von top_z bis bottom_z um Hüfte und Beine. Oben liegt er am
    Körper an (offset), nach unten weitet er sich (flare) und bleibt immer außerhalb der Beine.
    Gewichte: oben Becken, unten anteilig die Oberschenkel der jeweiligen Seite."""
    body, lm = base["body"], base["lm"]
    verts = [v.co.copy() for v in body.data.vertices]
    center = Vector((0.0, lm["bones"]["pelvis"][0].y, 0.0))
    # Umriss je Höhe und Winkel: weitester Körperpunkt in diesem Winkel (+offset)
    def envelope(z, slab=0.05):
        env = [0.0] * segments
        for c in verts:
            if abs(c.z - z) > slab or abs(c.x) > 0.45:
                continue
            d = Vector((c.x - center.x, c.y - center.y))
            a = (math.atan2(d.x, -d.y)) % (2 * math.pi)
            k = int(a / (2 * math.pi) * segments) % segments
            env[k] = max(env[k], d.length)
        # Lücken füllen und glätten (konvexer Rock)
        for _ in range(3):
            env = [max(env[k], (env[k - 1] + env[(k + 1) % segments]) / 2) for k in range(segments)]
        return env
    ring_radii = []
    for r in range(rings + 1):
        t = r / rings
        z = top_z + (bottom_z - top_z) * t
        env = envelope(z)
        if r == 0:
            radii = [e + offset for e in env]
        else:
            prev = ring_radii[-1][1]
            radii = [max(env[k] + offset + 0.01, prev[k] + flare / rings * (0.6 + 0.8 * t)) for k in range(segments)]
            # Rund ziehen (Stoff fällt glatt)
            radii = [(radii[k - 1] + 2 * radii[k] + radii[(k + 1) % segments]) / 4 for k in range(segments)]
        ring_radii.append((z, radii))
    me = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, me)
    body.users_collection[0].objects.link(obj)
    bm = bmesh.new()
    rows = []
    for z, radii in ring_radii:
        row = []
        for k in range(segments):
            a = 2 * math.pi * k / segments
            # Leichte Falten unten
            fold = 1.0 + 0.025 * math.sin(a * 7) * ((top_z - z) / max(top_z - bottom_z, 1e-6)) ** 1.5
            rr = radii[k] * fold
            row.append(bm.verts.new((center.x + math.sin(a) * rr, center.y - math.cos(a) * rr, z)))
        rows.append(row)
    gap = int(segments * open_front / 2)
    for i in range(len(rows) - 1):
        for k in range(segments):
            if open_front and (k < gap or k >= segments - gap) and i > rings * 0.25:
                continue
            k1 = (k + 1) % segments
            bm.faces.new((rows[i][k], rows[i + 1][k], rows[i + 1][k1], rows[i][k1]))
    bm.to_mesh(me)
    bm.free()
    _bell_weights(base, obj, top_z, bottom_z, thigh_share)
    _bell_shape_keys(base, obj, top_z, bottom_z)
    _add_lip(obj, lip + 0.004)
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    obj.parent = base["arm"]
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = base["arm"]
    return obj


def _bell_weights(base, obj, top_z, bottom_z, thigh_share):
    body = base["body"]
    tree_pts = [v.co.copy() for v in body.data.vertices]
    from mathutils.kdtree import KDTree
    kd = KDTree(len(tree_pts))
    for i, c in enumerate(tree_pts):
        kd.insert(c, i)
    kd.balance()
    groups = {}
    def group(n):
        if n not in groups:
            groups[n] = obj.vertex_groups.get(n) or obj.vertex_groups.new(name=n)
        return groups[n]
    for v in obj.data.vertices:
        t = (top_z - v.co.z) / max(top_z - bottom_z, 1e-6)
        t = max(0.0, min(1.0, t))
        if t < 0.15:
            # Oben: Gewichte des nächsten Körperpunkts
            _, i, _ = kd.find(v.co)
            for n, w in weights_of(body, body.data.vertices[i]).items():
                group(n).add([v.index], w, "REPLACE")
            continue
        side = max(-1.0, min(1.0, v.co.x / 0.09))
        left = (side + 1) / 2
        share = thigh_share * min(1.0, t * 1.4)
        group("pelvis").add([v.index], 1.0 - share, "REPLACE")
        if left > 0.01:
            group("thigh_l").add([v.index], share * left, "REPLACE")
        if left < 0.99:
            group("thigh_r").add([v.index], share * (1 - left), "REPLACE")


def _bell_shape_keys(base, obj, top_z, bottom_z):
    """Formregler für Röcke: Verschiebung des nächsten Körperpunkts, nach unten auslaufend."""
    body = base["body"]
    if not body.data.shape_keys:
        return
    from mathutils.kdtree import KDTree
    basis = body.data.shape_keys.key_blocks[0]
    kd = KDTree(len(basis.data))
    for i, d in enumerate(basis.data):
        kd.insert(d.co, i)
    kd.balance()
    obj.shape_key_add(name="Basis", from_mix=False)
    near = []
    for v in obj.data.vertices:
        # Am Rumpf messen (Rock liegt höher als die Beine in der Mitte)
        probe = Vector((v.co.x * 0.7, v.co.y * 0.7, max(v.co.z, base["lm"]["crotch_z"] + 0.05)))
        _, i, _ = kd.find(probe)
        near.append(i)
    for kb in body.data.shape_keys.key_blocks[1:]:
        key = obj.shape_key_add(name=kb.name, from_mix=False)
        for v, i in zip(obj.data.vertices, near):
            d = kb.data[i].co - basis.data[i].co
            # Nur seitlich (Umfang) übernehmen, nach unten leicht weniger
            d.z = 0.0
            key.data[v.index].co = v.co + d * 1.1


# ---------------------------------------------------------------------------------------------
# Haare aus dicken Strähnen
# ---------------------------------------------------------------------------------------------

class HeadShape:
    """Kopfform zum Anlegen von Strähnen: Strahl von der Kopfmitte nach außen trifft die Haut."""

    def __init__(self, base):
        self.c = base["lm"]["head_c"].copy()
        self.r = base["lm"]["head_r"]
        self.tree = body_bvh(base["body"])
        self.body = self.tree

    def dir(self, az, el):
        """Richtung: az = 0 vorn (-y), 90° = links (+x), 180° hinten; el = Höhe (90° = oben)."""
        a, e = math.radians(az), math.radians(el)
        return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))

    def surface(self, az, el, off=0.0):
        d = self.dir(az, el)
        # Von außen zur Kopfmitte – trifft das zu weit weg (Schulter), dann von innen nach außen
        hit = self.tree.ray_cast(self.c + d * 0.3, -d)
        if hit[0] is None or (hit[0] - self.c).length > self.r * 1.35:
            hit = self.tree.ray_cast(self.c, d)
        p = hit[0] if hit[0] is not None else self.c + d * self.r
        return p + d * off, d

    def surface_dir(self, d, off=0.0):
        d = Vector(d).normalized()
        hit = self.tree.ray_cast(self.c + d * 0.3, -d)
        if hit[0] is None or (hit[0] - self.c).length > self.r * 1.35:
            hit = self.tree.ray_cast(self.c, d)
        p = hit[0] if hit[0] is not None else self.c + d * self.r
        return p + d * off, d

    def keep_out(self, p, margin):
        """Punkt aus dem Körper schieben (Schultern, Rücken)."""
        loc, nrm, _, _ = self.tree.find_nearest(p)
        if loc is None:
            return p
        side = (p - loc).dot(nrm)
        if side < margin:
            return p + nrm * (margin - side)
        return p


def _lens_ring(p, tangent, normal, width, thick, n=8, twist=0.0):
    t = tangent.normalized()
    nn = (normal - t * normal.dot(t))
    if nn.length < 1e-6:
        nn = t.orthogonal()
    nn.normalize()
    side = t.cross(nn).normalized()
    if twist:
        side, nn = side * math.cos(twist) + nn * math.sin(twist), nn * math.cos(twist) - side * math.sin(twist)
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        x = math.cos(a) * width / 2
        # Linsenform: in der Mitte dick, zu den Kanten flach – und oben leicht gewölbt
        y = math.sin(a) * thick / 2 * (1.0 - 0.35 * abs(math.cos(a)))
        pts.append(p + side * x + nn * y)
    return pts


def strand_mesh(bm, path, normals, width_fn, thick_fn, n=10, twist_fn=None):
    """Eine Strähne als geschlossene Röhre mit Linsen-Querschnitt; Spitze läuft in eine Ecke aus."""
    rings = []
    count = len(path)
    for i, p in enumerate(path):
        t = i / (count - 1)
        if i == 0:
            tan = path[1] - path[0]
        elif i == count - 1:
            tan = path[-1] - path[-2]
        else:
            tan = path[i + 1] - path[i - 1]
        w, th = width_fn(t), thick_fn(t)
        if i == count - 1:
            rings.append([bm.verts.new(p)])
            continue
        ring = _lens_ring(p, tan, normals[i], w, th, n, twist_fn(t) if twist_fn else 0.0)
        rings.append([bm.verts.new(q) for q in ring])
    # Anfang zu
    bm.faces.new(list(reversed(rings[0])))
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(n):
            k1 = (k + 1) % n
            if len(b) == 1:
                bm.faces.new((a[k], b[0], a[k1]))
            else:
                bm.faces.new((a[k], b[k], b[k1], a[k1]))


def _smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def make_hair_object(base, name, mat):
    me = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, me)
    base["body"].users_collection[0].objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def finish_hair(base, obj, bm, neck_weight_below=None):
    """Haar-Netz abschließen: glatt schattiert, am Skelett (Kopf; lange Haare unten anteilig am
    oberen Rücken, damit sie beim Gehen nicht durch die Schultern schwingen)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    head = obj.vertex_groups.new(name="Head")
    neck = obj.vertex_groups.new(name="neck_01")
    spine = obj.vertex_groups.new(name="spine_03")
    lm = base["lm"]
    for v in obj.data.vertices:
        if neck_weight_below is None or v.co.z >= neck_weight_below:
            head.add([v.index], 1.0, "REPLACE")
            continue
        t = _smoothstep(neck_weight_below, lm["shoulder_z"] - 0.08, v.co.z)
        t = 1.0 - t
        head.add([v.index], max(0.0, 1.0 - t), "REPLACE")
        neck.add([v.index], t * 0.4, "REPLACE")
        spine.add([v.index], t * 0.6, "REPLACE")
    obj.parent = base["arm"]
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = base["arm"]


def scalp_cap(base, name, mat, hairline, off=0.006, cut=None):
    """Kappe über der Kopfhaut (unter den Strähnen, damit nirgends Haut durchscheint):
    Kopfhaut-Ecken oberhalb der Haarlinie (hairline(az) = Höhe in Grad), nach außen geschoben."""
    head = HeadShape(base)
    def select(co, bone):
        if bone not in ("Head", "neck_01"):
            return False
        d = co - head.c
        if d.length < 1e-6:
            return False
        d.normalize()
        az = math.degrees(math.atan2(d.x, -d.y))
        el = math.degrees(math.asin(max(-1.0, min(1.0, d.z))))
        return el > hairline(az) and (cut is None or cut(co))
    obj = shell(base, name, select, off, mat, smooth=3, lip=0.003, push_min=off * 0.8)
    # Kappe nur am Kopf
    for g in list(obj.vertex_groups):
        if g.name not in ("Head",):
            obj.vertex_groups.remove(g)
    head_g = obj.vertex_groups.get("Head") or obj.vertex_groups.new(name="Head")
    head_g.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    return obj


def hairline_soft(az, front=36.0, temple=14.0, side=4.0, back=-38.0):
    """Typische Haarlinie in Grad Höhe über der Kopfmitte: vorn Stirn, Schläfen, Ohren, Nacken."""
    a = abs(((az + 180) % 360) - 180)
    pts = [(0, front), (35, front - 6), (60, temple), (95, side), (130, back * 0.6), (180, back)]
    for (a0, e0), (a1, e1) in zip(pts, pts[1:]):
        if a <= a1:
            t = (a - a0) / (a1 - a0)
            return e0 + (e1 - e0) * (t * t * (3 - 2 * t))
    return back


def long_hair(base, name, mat, length=0.45, count=30, part_az=0.0, wave=0.02, volume=0.012,
              width=0.05, thick=0.016, seed=1, fringe=False, curl=0.0, layers=2):
    """Lange Haare mit Mittelscheitel: Strähnen vom Scheitel über den Kopf bis zur Haarlinie,
    dann herabfallend (über Schultern und Rücken, nie in den Körper). Gesicht bleibt frei."""
    rnd = random.Random(seed)
    head = HeadShape(base)
    lm = base["lm"]
    obj = make_hair_object(base, name, mat)
    bm = bmesh.new()
    for layer in range(layers):
        off = volume + layer * 0.006
        n = count if layer == 0 else int(count * 0.8)
        for i in range(n):
            u = (i + 0.5 + (0.5 if layer else 0.0)) / n
            # Seite: links/rechts abwechselnd, Ziel-Azimut von der Schläfe bis hinten
            s = 1 if i % 2 == 0 else -1
            az_end = s * (60 + (180 - 60) * ((i // 2) / max(1, n // 2 - 1)) ** 0.9)
            az_end += rnd.uniform(-4, 4)
            el_end = hairline_soft(az_end) - 6
            # Wurzel auf dem Scheitel: vorn für die Strähnen an der Schläfe, bis zum Wirbel am
            # Hinterkopf für die hinteren (so ist der ganze Kopf bedeckt)
            u = (abs(az_end) - 60) / (180 - 60)
            beta = math.radians(35 + 100 * max(0.0, min(1.0, u)) + rnd.uniform(-4, 4))
            d_root = Vector((s * 0.03, -math.cos(beta), math.sin(beta)))
            d_end = head.dir(az_end, el_end)
            path, normals = [], []
            steps = 8
            for k in range(steps + 1):
                t = k / steps
                d = d_root.lerp(d_end, t ** 0.85).normalized()
                p, d = head.surface_dir(d, off + 0.006 * math.sin(math.pi * t))
                path.append(p)
                normals.append(d)
            # Herabfallen
            last, d_out = path[-1], normals[-1]
            horiz = Vector((d_out.x, d_out.y, 0.0))
            horiz = horiz.normalized() if horiz.length > 1e-6 else Vector((0, 1, 0))
            L = length * rnd.uniform(0.85, 1.1) * (0.8 + 0.2 * abs(az_end) / 180)
            fall_steps = 10
            prev = last
            for k in range(1, fall_steps + 1):
                t = k / fall_steps
                p = last + Vector((0, 0, -L * t)) + horiz * (0.025 * math.sin(math.pi * t * 0.7))
                # Wellen quer zur Fallrichtung
                side = Vector((-horiz.y, horiz.x, 0.0))
                p += side * (wave * math.sin(t * math.pi * 2.2 + i * 0.7))
                if curl:
                    p += horiz * (-curl * _smoothstep(0.7, 1.0, t))
                p = head.keep_out(p, 0.022 + 0.004 * layer)
                # Nie höher als der vorige Punkt (fällt)
                if p.z > prev.z - 0.005:
                    p.z = prev.z - 0.005
                path.append(p)
                normals.append(horiz)
                prev = p
            w0 = width * rnd.uniform(0.85, 1.15)
            # Breit und voll, unten weich zur Spitze (keine dünnen Fransen)
            strand_mesh(bm, path, normals, lambda t, w0=w0: w0 * (0.8 + 0.45 * math.sin(math.pi * min(1, t * 1.2))) * (1 - _smoothstep(0.82, 1.0, t) * 0.7),
                        lambda t: thick * (1 - _smoothstep(0.85, 1.0, t) * 0.5), twist_fn=lambda t: 0.2 * math.sin(t * 4 + i))
    if fringe:
        for i in range(5):
            az0 = -24 + i * 12
            path, normals = [], []
            for k in range(7):
                t = k / 6
                p, d = head.surface(az0 + 6 * t, 70 - 44 * t, volume + 0.006)
                path.append(p)
                normals.append(d)
            strand_mesh(bm, path, normals, lambda t: 0.04 * (1 - 0.7 * t), lambda t: 0.012)
    finish_hair(base, obj, bm, neck_weight_below=lm["neck"].z)
    return obj


def bun_hair(base, name, mat, bun_el=35.0, bun_size=0.055, count=26, seed=3):
    """Hochgesteckt: Strähnen laufen von der Haarlinie nach hinten zum Dutt, der Dutt ist eine
    aufgerollte dicke Strähne."""
    rnd = random.Random(seed)
    head = HeadShape(base)
    obj = make_hair_object(base, name, mat)
    bm = bmesh.new()
    bun_p, bun_d = head.surface(180, bun_el, 0.02)
    for i in range(count):
        az0 = -170 + 340 * i / (count - 1) + rnd.uniform(-3, 3)
        el0 = hairline_soft(az0) - 3
        path, normals = [], []
        for k in range(9):
            t = k / 8
            az = az0 + ((180 if az0 > 0 else -180) - az0) * t
            el = el0 + (bun_el - el0) * t
            p, d = head.surface(az, el, 0.010 + 0.006 * math.sin(math.pi * t))
            path.append(p)
            normals.append(d)
        strand_mesh(bm, path, normals, lambda t: 0.045 * (1 - 0.6 * t), lambda t: 0.013 * (1 - 0.4 * t))
    # Dutt: Spirale aus einer dicken Strähne
    up = bun_d
    side = up.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
    fwd = side.cross(up).normalized()
    path, normals = [], []
    turns = 2.3
    for k in range(40):
        t = k / 39
        a = t * turns * 2 * math.pi
        r = bun_size * (0.9 - 0.45 * t)
        p = bun_p + up * (0.02 + 0.03 * t) + side * math.cos(a) * r + fwd * math.sin(a) * r
        path.append(p)
        normals.append((p - bun_p).normalized())
    strand_mesh(bm, path, normals, lambda t: 0.038 * (1 - 0.3 * t), lambda t: 0.034 * (1 - 0.3 * t))
    finish_hair(base, obj, bm)
    return obj


def short_hair(base, name, mat, length=0.07, lift=0.02, part_az=None, sweep=(0.0, 1.0), count=60, seed=5,
               width=0.04, thick=0.014, messy=0.3, front_fringe=0.0):
    """Kurze Haare aus Büscheln: Wurzeln über die Kopfhaut verteilt, jedes Büschel liegt in
    Wuchsrichtung (vom Scheitel nach hinten und zur Seite) und hebt sich zur Spitze leicht ab."""
    rnd = random.Random(seed)
    head = HeadShape(base)
    obj = make_hair_object(base, name, mat)
    bm = bmesh.new()
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(count):
        # Fibonacci-Verteilung auf der Kopfhaube
        z = 1 - (i + 0.5) / count * 1.25
        if z < -0.2:
            continue
        az = math.degrees((i * golden) % (2 * math.pi)) - 180
        el = math.degrees(math.asin(max(-1, min(1, z))))
        hl = hairline_soft(az, front=34, temple=16, side=8, back=-30)
        if el < hl + 2:
            continue
        # Wuchsrichtung: nach hinten unten; vorn mit Seitenscheitel zur Seite
        if part_az is not None and abs(((az - part_az + 180) % 360) - 180) < 70 and el > 40:
            daz = 25 if az >= part_az else -25
            dz = -12
        else:
            daz = (sweep[0] + (1 if az > 0 else -1) * 8) * (1 if abs(az) < 120 else 0.3)
            dz = -length * 260 * sweep[1]
        if front_fringe and abs(az) < 50 and el < hl + 25:
            daz, dz = rnd.uniform(-8, 8), -front_fringe * 260
        path, normals = [], []
        L = length * rnd.uniform(0.8, 1.2)
        for k in range(6):
            t = k / 5
            a2 = az + daz * t * (L / 0.07) + rnd.uniform(-1, 1) * messy * 4 * t
            e2 = el + dz * t * (L / 0.07) * 0.06
            p, d = head.surface(a2, e2, 0.008 + lift * t ** 1.6 + rnd.uniform(0, 0.004) * t)
            path.append(p)
            normals.append(d)
        w0 = width * rnd.uniform(0.8, 1.2)
        strand_mesh(bm, path, normals, lambda t, w0=w0: w0 * (1 - 0.85 * t ** 1.3), lambda t: thick * (1 - 0.6 * t))
    finish_hair(base, obj, bm)
    return obj


def cropped_hair(base, name, mat, count=34, part_az=None, tip=0.035, lift=0.006, front_up=0.0, width=0.05,
                 thick=0.015, seed=5, hairline=None, layers=2, messy=0.0):
    """Kurze Haare aus anliegenden Strähnen: jede läuft vom Wirbel (oder vom Seitenscheitel) über
    den Kopf bis zur Haarlinie und ein Stück darüber hinaus (Spitze). front_up = vorn hebt sich
    die Spitze (Tolle), messy = Spitzen leicht durcheinander."""
    rnd = random.Random(seed)
    head = HeadShape(base)
    hl = hairline or (lambda az: hairline_soft(az, front=34, temple=18, side=10, back=-30))
    obj = make_hair_object(base, name, mat)
    bm = bmesh.new()
    crown = head.dir(180, 62)
    for layer in range(layers):
        n = count if layer == 0 else int(count * 0.75)
        off = 0.009 + layer * 0.005
        for i in range(n):
            az = -180 + 360 * (i + 0.5 * layer + rnd.uniform(-0.2, 0.2)) / n
            el = hl(az) - 3
            d_end = head.dir(az, el)
            if part_az is not None:
                # Seitenscheitel: Wurzeln auf einer Linie von vorn zum Wirbel
                side = 1 if ((az - part_az + 540) % 360 - 180) > 0 else -1
                u = min(1.0, abs(az) / 180)
                beta = math.radians(40 + 95 * u)
                pa = math.radians(part_az)
                d_root = Vector((math.sin(pa) * math.sin(beta) * 0.0 + math.sin(pa) * 0.35 + side * 0.03,
                                 -math.cos(beta), math.sin(beta))).normalized()
            else:
                d_root = crown.lerp(Vector((0, 0, 1)), 0.25).normalized()
            path, normals = [], []
            steps = 8
            for k in range(steps + 1):
                t = k / steps
                d = d_root.lerp(d_end, t ** 0.9).normalized()
                p, d = head.surface_dir(d, off + lift * t * t)
                path.append(p)
                normals.append(d)
            # Spitze ein Stück über die Haarlinie hinaus – sie folgt der Kopfform (liegt an); vorn
            # kurz und ggf. nach oben gebogen (nie ins Gesicht)
            front = max(0.0, 1.0 - abs(az) / 60)
            tip_len = tip * (0.35 if front > 0 else 1.0)
            d_tip = (d_end - d_root)
            d_tip = d_tip.normalized() if d_tip.length > 1e-6 else Vector((0, 0, -1))
            for k in range(1, 4):
                t = k / 3
                d = (d_end + d_tip * (tip_len / max(head.r, 0.05)) * t).normalized()
                q, dd = head.surface_dir(d, off + lift + front_up * front * t * t)
                q += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * messy * 0.006 * t
                path.append(q)
                normals.append(dd)
            w0 = width * rnd.uniform(0.85, 1.15)
            strand_mesh(bm, path, normals, lambda t, w0=w0: w0 * (0.7 + 0.5 * math.sin(math.pi * min(1.0, t * 1.4))) * (1 - 0.75 * _smoothstep(0.7, 1.0, t)),
                        lambda t: thick * (1 - 0.5 * _smoothstep(0.7, 1.0, t)), twist_fn=lambda t: 0.2 * math.sin(t * 4 + i))
    finish_hair(base, obj, bm)
    return obj


def beard(base, name, mat, full=True, mustache=True, thickness=0.009):
    """Bart als Hülle um Kinn und Wangen (unterhalb der Wangenknochen) mit Rillen wie
    modellierte Strähnen; dazu ein Schnurrbart aus zwei Strähnen."""
    head = HeadShape(base)
    lm = base["lm"]
    c = head.c
    objs = []
    if full:
        def select(co, bone):
            if bone not in ("Head", "neck_01"):
                return False
            d = co - c
            if d.y > 0.035 or d.z > -0.035 or d.z < -0.16:
                return False
            # Mund frei lassen
            if abs(d.x) < 0.022 and -0.07 < d.z < -0.045 and d.y < -0.06:
                return False
            return abs(d.x) < 0.075
        b = shell(base, name, select, thickness, mat, smooth=4, lip=0.003, push_min=thickness * 0.7,
                  offset_fn=lambda co: thickness * (1.0 + 0.25 * math.sin((co.x) * 260)))
        for g in list(b.vertex_groups):
            if g.name != "Head":
                b.vertex_groups.remove(g)
        hg = b.vertex_groups.get("Head") or b.vertex_groups.new(name="Head")
        hg.add(list(range(len(b.data.vertices))), 1.0, "REPLACE")
        objs.append(b)
    if mustache:
        obj = make_hair_object(base, name + "Mustache", mat)
        bm = bmesh.new()
        for s in (-1, 1):
            path, normals = [], []
            for k in range(7):
                t = k / 6
                p, d = head.surface(s * (4 + 34 * t), -24 - 16 * t ** 1.5, 0.006)
                path.append(p)
                normals.append(d)
            strand_mesh(bm, path, normals, lambda t: 0.026 * (1 - 0.6 * t), lambda t: 0.011 * (1 - 0.5 * t))
        finish_hair(base, obj, bm)
        objs.append(obj)
    return objs


# ---------------------------------------------------------------------------------------------
# Zubehör
# ---------------------------------------------------------------------------------------------

def tube_object(base, name, mat, path, radius, bones, segments=10):
    """Rundes Rohr (Schal, Gürtel) am Skelett: bones = dict knochen -> gewicht."""
    obj = make_hair_object(base, name, mat)
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(path):
        tan = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        n = tan.orthogonal().normalized()
        b = tan.cross(n)
        r = radius(i / (len(path) - 1)) if callable(radius) else radius
        rings.append([bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * r)
                      for a in [2 * math.pi * k / segments for k in range(segments)]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    for a, b2 in zip(rings, rings[1:]):
        for k in range(segments):
            k1 = (k + 1) % segments
            bm.faces.new((a[k], b2[k], b2[k1], a[k1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    for bn, w in bones.items():
        obj.vertex_groups.new(name=bn).add(list(range(len(obj.data.vertices))), w, "REPLACE")
    obj.parent = base["arm"]
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = base["arm"]
    return obj


def buttons(base, name, mat, points, radius=0.008, bone="spine_02"):
    """Kleine flache Knöpfe an den Punkten (mit Richtung nach außen)."""
    obj = make_hair_object(base, name, mat)
    bm = bmesh.new()
    for p, n in points:
        n = n.normalized()
        u = n.orthogonal().normalized()
        w = n.cross(u)
        top = [bm.verts.new(p + n * 0.003 + (u * math.cos(a) + w * math.sin(a)) * radius) for a in [2 * math.pi * k / 8 for k in range(8)]]
        bot = [bm.verts.new(p - n * 0.002 + (u * math.cos(a) + w * math.sin(a)) * radius) for a in [2 * math.pi * k / 8 for k in range(8)]]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for k in range(8):
            k1 = (k + 1) % 8
            bm.faces.new((bot[k], bot[k1], top[k1], top[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = base["arm"]
    obj.modifiers.new("Armature", "ARMATURE").object = base["arm"]
    return obj


def surface_point(base, x, z, front=True):
    """Punkt auf der Körperoberfläche vorn (oder hinten) bei (x, z) samt Normale."""
    tree = body_bvh(base["body"])
    o = Vector((x, -1.0 if front else 1.0, z))
    hit = tree.ray_cast(o, Vector((0, 1 if front else -1, 0)))
    return hit[0], hit[1]


# ---------------------------------------------------------------------------------------------
# Materialien
# ---------------------------------------------------------------------------------------------

def srgb(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def cloth_mat(name, color, rough=0.85, sheen=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*srgb(color), 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular"].default_value = 0.25
    return m


# Eingefärbte Bild-Kopien -> (Original, Farbton): für die .blend-Dateien wieder durch Original +
# Farbknoten ersetzt (die gepackten Kopien wären viel zu groß)
TINTED = {}


def display_materials():
    """Vor dem Speichern als .blend: eingefärbte Bilder wieder durch die Originale ersetzen und
    den Farbton als Knoten davorsetzen (sieht in Blender gleich aus, Datei bleibt klein)."""
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        nt = m.node_tree
        for node in list(nt.nodes):
            if node.type != "TEX_IMAGE" or not node.image or node.image.name not in TINTED:
                continue
            orig, tint = TINTED[node.image.name]
            node.image = orig
            for link in list(node.outputs["Color"].links):
                mix = nt.nodes.new("ShaderNodeMixRGB")
                mix.blend_type = "MULTIPLY"
                mix.inputs["Fac"].default_value = 1.0
                mix.inputs["Color2"].default_value = (*tint, 1.0)
                target = link.to_socket
                nt.links.remove(link)
                nt.links.new(node.outputs["Color"], mix.inputs["Color1"])
                nt.links.new(mix.outputs["Color"], target)
    for name in list(TINTED):
        img = bpy.data.images.get(name)
        if img:
            bpy.data.images.remove(img)
    TINTED.clear()
    # Vom glTF-Import gepackte Bilder: auf die Originaldateien im Projekt verweisen (kleine Datei)
    for img in list(bpy.data.images):
        if img.packed_file is not None:
            path = bpy.path.abspath(img.filepath)
            if os.path.exists(path):
                img.unpack(method="USE_ORIGINAL")
            elif img.users == 0:
                bpy.data.images.remove(img)
        elif img.users == 0:
            bpy.data.images.remove(img)


def tinted_image(img, tint, name):
    """Kopie eines Bildes, mit tint (sRGB) multipliziert – so kommt der Farbton sicher im .glb an
    (der Export übernimmt keine Farb-Knoten)."""
    w, h = img.size
    px = _np.empty(w * h * 4, dtype=_np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    px[:, 0] *= tint[0]
    px[:, 1] *= tint[1]
    px[:, 2] *= tint[2]
    out = bpy.data.images.new(name, w, h, alpha=True)
    out.pixels.foreach_set(px.ravel())
    out.file_format = "PNG"
    out.pack()
    TINTED[out.name] = (img, tuple(tint))
    return out


def skin_material(base, tone, tint=(1.0, 1.0, 1.0)):
    """Haut: Farbtextur des Grundkörpers (hell/dunkel), mit Farbton multipliziert (in glTF als
    Grundfarbe), Normal-Textur abgeschwächt (weniger Muskeln)."""
    kind = base["kind"]
    old = base["body"].data.materials[0]
    m = bpy.data.materials.new("Skin")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    src = bpy.data.images.load(os.path.join(TEXTURE_DIR, SKIN_TEXTURES[(kind, tone)]), check_existing=True)
    tex.image = tinted_image(src, tint, "Skin_" + tone)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    bsdf.inputs["Specular"].default_value = 0.35
    # Normal-Textur übernehmen, schwächer
    for n in old.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image and "Normal" in n.image.name:
            nimg = nt.nodes.new("ShaderNodeTexImage")
            nimg.image = n.image
            nimg.image.colorspace_settings.name = "Non-Color"
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nmap.inputs["Strength"].default_value = 0.45
            nt.links.new(nimg.outputs["Color"], nmap.inputs["Color"])
            nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    base["body"].data.materials[0] = m
    return m


def tint_material(obj, color):
    """Material eines geladenen Teils (Brauen) einfärben: Grundfarbe multiplizieren."""
    for m in obj.data.materials:
        if not m or not m.use_nodes:
            continue
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        # Das Bild hinter der Grundfarbe suchen (ggf. über Zwischenknoten) und eingefärbt ersetzen
        texs = [n for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and "Normal" not in n.image.name]
        if not texs:
            bsdf.inputs["Base Color"].default_value = (*srgb(color), 1.0)
            continue
        for t in texs:
            t.image = tinted_image(t.image, srgb(color), t.image.name + "_tint")


# ---------------------------------------------------------------------------------------------
# Körper unter der Kleidung, Körperteile, Ausgabe
# ---------------------------------------------------------------------------------------------

def hide_covered(base, clothes, margin=0.012):
    """Körperflächen löschen, die ganz unter Kleidung liegen (spart Dreiecke und verhindert, dass
    Haut bei Bewegung durch den Stoff sticht): Strahl von der Fläche nach außen trifft Kleidung."""
    body = base["body"]
    trees = []
    for c in clothes:
        keys = _key_coords(c.data)
        trees.append(BVHTree.FromPolygons(keys[0], [tuple(p.vertices) for p in c.data.polygons]))
    me = body.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    covered_v = set()
    for v in bm.verts:
        n = v.normal
        hits = 0
        # Nach außen und leicht schräg: überall Kleidung?
        dirs = [n] + [(n + n.orthogonal().normalized() * s * 0.5).normalized() for s in (-1, 1)]
        for d in dirs:
            if any(t.ray_cast(v.co + d * 0.001, d, 0.08)[0] is not None for t in trees):
                hits += 1
        if hits == len(dirs):
            covered_v.add(v.index)
    # Nur Flächen, deren Ecken alle bedeckt sind, und ein Rand bleibt stehen
    kill = [f for f in bm.faces if all(v.index in covered_v for v in f.verts)]
    # Rand der Kleidung: Nachbarn nicht bedeckter Flächen bleiben (ein Ring Puffer)
    keep = set()
    for f in bm.faces:
        if not all(v.index in covered_v for v in f.verts):
            for v in f.verts:
                for f2 in v.link_faces:
                    keep.add(f2.index)
    kill = [f for f in kill if f.index not in keep]
    bmesh.ops.delete(bm, geom=kill, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.update()


def split_segments(base):
    """Körper in Teile zerlegen (Kopf, Rumpf, Arme, Beine …) – der Baukasten blendet aus, was
    Kleidung ganz bedeckt. Liefert dict name -> Objekt."""
    body = base["body"]
    seg_of = {}
    for seg, bones in SEGMENTS.items():
        for bn in bones:
            seg_of[bn] = seg
    out = {}
    for seg in SEGMENTS:
        obj = _copy_object(body, "Body_" + seg)
        me = obj.data
        bm = bmesh.new()
        bm.from_mesh(me)
        deform = bm.verts.layers.deform.active
        names = {i: g.name for i, g in enumerate(obj.vertex_groups)}
        kill = []
        for f in bm.faces:
            votes = {}
            for v in f.verts:
                if v[deform]:
                    gi, _ = max(v[deform].items(), key=lambda kv: kv[1])
                    s = seg_of.get(names.get(gi), "Torso")
                    votes[s] = votes.get(s, 0) + 1
            best = max(votes.items(), key=lambda kv: kv[1])[0] if votes else "Torso"
            if best != seg:
                kill.append(f)
        bmesh.ops.delete(bm, geom=kill, context="FACES_ONLY")
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(me)
        bm.free()
        if len(me.polygons):
            out[seg] = obj
        else:
            bpy.data.objects.remove(obj)
    bpy.data.objects.remove(body)
    return out


def apply_shape_mix(objs, values):
    """Formregler fest einstellen und anwenden (für fertige Figuren / Mixamo)."""
    for o in objs:
        me = o.data
        if not me.shape_keys:
            continue
        for kb in me.shape_keys.key_blocks[1:]:
            kb.value = values.get(kb.name, 0.0)
        bpy.context.view_layer.objects.active = o
        o.shape_key_add(name="__mix", from_mix=True)
        mix = me.shape_keys.key_blocks["__mix"]
        cos = [d.co.copy() for d in mix.data]
        o.shape_key_clear()
        for v, c in zip(me.vertices, cos):
            v.co = c


def ensure_uvs(objects):
    """Jedes Netz braucht Texturkoordinaten (Godot berechnet daraus die Tangenten): Teile ohne
    (Haare, Schuhe, Röcke) bekommen eine einfache Projektion von vorn."""
    for o in objects:
        me = o.data
        if me.uv_layers:
            continue
        uv = me.uv_layers.new(name="UVMap")
        for loop in me.loops:
            co = me.vertices[loop.vertex_index].co
            uv.data[loop.index].uv = (co.x * 2.0, co.z * 2.0)


def strip_layers(objects):
    """Nur die erste Texturkoordinate behalten, keine Vertex-Farben (die Kleidung erbt sonst die
    fünf Koordinaten- und drei Farbsätze des Grundkörpers – unnötig groß)."""
    for o in objects:
        me = o.data
        while len(me.uv_layers) > 1:
            me.uv_layers.remove(me.uv_layers[-1])
        if not any(n in o.name for n in ("Eyes", "Eyebrows")):
            for attr in list(me.color_attributes):
                me.color_attributes.remove(attr)


def export_glb(path, objects, arm, keep_shape_keys=True):
    strip_layers(objects)
    ensure_uvs(objects)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_skins=True,
                              export_morph=keep_shape_keys, export_animations=False, export_extras=True,
                              export_apply=False, export_yup=True, export_image_format="JPEG")


def export_fbx(path, objects, arm):
    """Für Mixamo: nur die Netze in T-Pose als FBX (Texturen eingebettet) – Mixamo setzt sein
    eigenes Skelett hinein (Auto-Rigger)."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, path_mode="STRIP", embed_textures=False,
                             bake_anim=False, object_types={"MESH"}, mesh_smooth_type="FACE",
                             use_mesh_modifiers=True, axis_forward="-Z", axis_up="Y")


# ---------------------------------------------------------------------------------------------
# Kontrollbilder
# ---------------------------------------------------------------------------------------------

def setup_render(res=(900, 1200), samples=20):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    w = bpy.data.worlds.new("W")
    scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.72, 0.68, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.color = (1.0, 0.93, 0.85)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    floor = bpy.data.meshes.new("Floor")
    floor.from_pydata([(-5, -5, 0), (5, -5, 0), (5, 5, 0), (-5, 5, 0)], [], [(0, 1, 2, 3)])
    fo = bpy.data.objects.new("Floor", floor)
    fm = bpy.data.materials.new("FloorMat")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.5, 0.48, 0.45, 1)
    floor.materials.append(fm)
    scene.collection.objects.link(fo)


def render(path, cam, target, lens=50):
    scene = bpy.context.scene
    c = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    c.data.lens = lens
    scene.collection.objects.link(c)
    c.location = cam
    c.rotation_euler = (Vector(target) - Vector(cam)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = c
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(c)


# ---------------------------------------------------------------------------------------------
# Schuhe (eigene Form aus Querschnitten entlang des Fußes)
# ---------------------------------------------------------------------------------------------

def _ring(cx, cz, half_w, top, bottom, n=16, power=3.0, y=0.0, flat_bottom=True):
    """Abgerundetes Rechteck in der x-z-Ebene bei y (Querschnitt eines Schuhs)."""
    pts = []
    cy = (top + bottom) / 2
    hh = (top - bottom) / 2
    for k in range(n):
        a = 2 * math.pi * k / n
        c, s = math.cos(a), math.sin(a)
        x = cx + half_w * math.copysign(abs(c) ** (2 / power), c)
        e = power if s > 0 else (power * 2.5 if flat_bottom else power)
        z = cy + hh * math.copysign(abs(s) ** (2 / e), s)
        pts.append(Vector((x, y, z)))
    return pts


def shoe(base, name, mat, sole_mat, top_z, side_off=0.008, toe_round=0.6, sole=0.016, shaft=True):
    """Ein Paar Schuhe/Stiefel: Querschnitte entlang jedes Fußes (aus den Fuß-Ecken gemessen,
    geglättet – keine Zehen), flache Sohle, bei Stiefeln ein Schaft bis top_z. Gewichte vom
    nächsten Fuß-/Wadenpunkt."""
    from mathutils.kdtree import KDTree
    body, lm = base["body"], base["lm"]
    feet_bones = {"foot_l", "foot_r", "ball_l", "ball_r", "calf_l", "calf_r"}
    me = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, me)
    body.users_collection[0].objects.link(obj)
    bm = bmesh.new()
    sole_rings = []
    for side in (1, -1):
        pts = [v.co.copy() for v in body.data.vertices if v.co.x * side > 0.02 and v.co.z < max(top_z, 0.13)
               and dominant_bone(body, v) in feet_bones]
        foot = [p for p in pts if p.z < lm["ankle_z"] + 0.03]
        y_heel = max(p.y for p in foot) + side_off
        y_toe = min(p.y for p in foot) - side_off
        steps = 14
        sections = []
        for k in range(steps + 1):
            t = k / steps
            y = y_heel + (y_toe - y_heel) * t
            sl = [p for p in foot if abs(p.y - y) < 0.016]
            if not sl:
                sl = foot
            x0, x1 = min(p.x for p in sl), max(p.x for p in sl)
            ztop = max(p.z for p in sl)
            sections.append([y, (x0 + x1) / 2, (x1 - x0) / 2, ztop])
        # Glätten (keine Zehen, keine Knöchelbeulen)
        for _ in range(3):
            sm = [list(s) for s in sections]
            for k in range(1, steps):
                for j in (1, 2, 3):
                    sm[k][j] = (sections[k - 1][j] + 2 * sections[k][j] + sections[k + 1][j]) / 4
            sections = sm
        rings = []
        for k, (y, cx, hw, ztop) in enumerate(sections):
            t = k / steps
            # Spitze und Ferse runden
            shrink = 1.0
            if t > 0.8:
                shrink = math.sqrt(max(0.05, 1 - ((t - 0.8) / 0.2) ** 2 * toe_round))
            if t < 0.12:
                shrink = math.sqrt(max(0.3, 1 - ((0.12 - t) / 0.12) ** 2 * 0.6))
            hw2 = (hw + side_off) * shrink
            top = ztop + side_off * 0.8
            if t > 0.75:
                top = sole + (top - sole) * (0.55 + 0.45 * shrink)
            rings.append(_ring(cx, 0.0, hw2, top, 0.0, y=y))
        verts = [[bm.verts.new(p) for p in r] for r in rings]
        bm.faces.new(list(reversed(verts[0])))
        bm.faces.new(verts[-1])
        for a, b2 in zip(verts, verts[1:]):
            n = len(a)
            for k in range(n):
                bm.faces.new((a[k], a[(k + 1) % n], b2[(k + 1) % n], b2[k]))
        sole_rings.append(rings)
        if shaft and top_z > lm["ankle_z"] + 0.03:
            # Schaft: Ringe um Knöchel und Wade
            shaft_rings = []
            heights = [lm["ankle_z"] - 0.02 + (top_z - lm["ankle_z"] + 0.02) * k / 5 for k in range(6)]
            leg = [p for p in pts]
            for z in heights:
                sl = [p for p in leg if abs(p.z - z) < 0.02] or leg
                cx = (min(p.x for p in sl) + max(p.x for p in sl)) / 2
                cy = (min(p.y for p in sl) + max(p.y for p in sl)) / 2
                rx = (max(p.x for p in sl) - min(p.x for p in sl)) / 2 + side_off + 0.002
                ry = (max(p.y for p in sl) - min(p.y for p in sl)) / 2 + side_off + 0.002
                shaft_rings.append([Vector((cx + math.cos(a) * rx, cy + math.sin(a) * ry, z)) for a in
                                    [2 * math.pi * k / 16 for k in range(16)]])
            # Glätten der Radien nach oben (Schaft wird nicht schmaler als unten)
            sv = [[bm.verts.new(p) for p in r] for r in shaft_rings]
            for a, b2 in zip(sv, sv[1:]):
                for k in range(16):
                    bm.faces.new((a[k], a[(k + 1) % 16], b2[(k + 1) % 16], b2[k]))
            bm.faces.new(list(reversed(sv[0])))
            # Oben offen mit Kante nach innen
            inner = [bm.verts.new(v.co + (Vector((cx, cy, v.co.z)) - v.co) * 0.12) for v in sv[-1]]
            for k in range(16):
                bm.faces.new((sv[-1][k], sv[-1][(k + 1) % 16], inner[(k + 1) % 16], inner[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    # Sohle: etwas breiter, flach, dunkel
    sole_obj = None
    if sole_mat is not None:
        sme = bpy.data.meshes.new(name + "Sole")
        sole_obj = bpy.data.objects.new(name + "Sole", sme)
        body.users_collection[0].objects.link(sole_obj)
        bm = bmesh.new()
        for rings in sole_rings:
            outline = []
            for r in rings:
                xs = [p.x for p in r]
                outline.append((r[0].y, min(xs) - 0.004, max(xs) + 0.004))
            left = [Vector((x0, y, 0.0)) for y, x0, _ in outline]
            right = [Vector((x1, y, 0.0)) for y, _, x1 in reversed(outline)]
            loop = left + right
            bot = [bm.verts.new(p + Vector((0, 0, -0.001))) for p in loop]
            top = [bm.verts.new(p + Vector((0, 0, sole))) for p in loop]
            bm.faces.new(list(reversed(bot)))
            bm.faces.new(top)
            n = len(loop)
            for k in range(n):
                bm.faces.new((bot[k], bot[(k + 1) % n], top[(k + 1) % n], top[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(sme)
        bm.free()
        sme.materials.append(sole_mat)
    # Gewichte vom nächsten Fuß-/Wadenpunkt
    idx = [v.index for v in body.data.vertices if dominant_bone(body, v) in feet_bones]
    kd = KDTree(len(idx))
    for i in idx:
        kd.insert(body.data.vertices[i].co, i)
    kd.balance()
    out = [o for o in (obj, sole_obj) if o]
    for o in out:
        groups = {}
        for v in o.data.vertices:
            _, i, _ = kd.find(v.co)
            for n, w in weights_of(body, body.data.vertices[i]).items():
                if n not in groups:
                    groups[n] = o.vertex_groups.new(name=n)
                groups[n].add([v.index], w, "REPLACE")
        o.parent = base["arm"]
        o.modifiers.new("Armature", "ARMATURE").object = base["arm"]
    return out


def push_out_of(obj, others, margin):
    """Kleidungsschichten: obj liegt überall mindestens margin außerhalb der Teile others
    (z. B. Pullover über der Hose). Grundform und Formregler."""
    trees = []
    for o in others:
        keys = _key_coords(o.data)
        trees.append(BVHTree.FromPolygons(keys[0], [tuple(p.vertices) for p in o.data.polygons]))
    me = obj.data
    keys = _key_coords(me)
    basis = keys[0]
    moved = list(basis)
    for i, c in enumerate(basis):
        for t in trees:
            loc, nrm, _, dist = t.find_nearest(c, 0.05)
            if loc is None:
                continue
            side = (c - loc).dot(nrm)
            if side < margin:
                c = c + nrm * (margin - side)
        moved[i] = c
    _write_keys(me, [moved] + [[k[i] + (moved[i] - basis[i]) for i in range(len(basis))] for k in keys[1:]])
    me.update()


def hide_by(base, predicate):
    """Körperflächen löschen, deren Ecken alle predicate(co, knochen) erfüllen (z. B. Füße in
    Schuhen)."""
    body = base["body"]
    me = body.data
    bm = bmesh.new()
    bm.from_mesh(me)
    deform = bm.verts.layers.deform.active
    names = {i: g.name for i, g in enumerate(body.vertex_groups)}
    hit = set()
    for v in bm.verts:
        bone = None
        if deform is not None and v[deform]:
            gi, _ = max(v[deform].items(), key=lambda kv: kv[1])
            bone = names.get(gi)
        if predicate(v.co, bone):
            hit.add(v.index)
    kill = [f for f in bm.faces if all(v.index in hit for v in f.verts)]
    bmesh.ops.delete(bm, geom=kill, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.update()
