"""Baut die Figuren (seit Etappe 5b): drei Frauen, drei Männer – als Baukasten je Grundkörper und
als fertige Einzelfiguren. Grundkörper: Quaternius "Universal Base Characters" (CC0), Stil: warm,
stilisiert, Frisuren aus dicken Strähnen (Richtung Disney Dreamlight Valley).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_characters.py              (alles)
    blender -b --factory-startup --python tools/blender/build_characters.py -- --render mila theo
        (nur Kontrollbilder dieser Figuren nach screenshots/blender/characters/, nichts speichern)

Ergebnis:
    assets/models/characters/<name>.glb        fertige Figur (Skelett + Netze, T-Pose)
    assets/models/characters/kit_<körper>.glb   Baukasten: Körper in Teilen mit Formreglern,
                                                alle Kleidungsstücke und Frisuren
    assets/models/characters/mixamo/<name>.fbx  zum Hochladen bei Mixamo (T-Pose, Texturen dabei)
    assets/models/source/characters/*.blend     zum Anschauen in Blender
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import character_lib as C  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

OUT = os.path.join(C.ROOT, "assets", "models", "characters")
SRC = os.path.join(C.ROOT, "assets", "models", "source", "characters")
SHOTS = os.path.join(C.ROOT, "screenshots", "blender", "characters")

# Körperformen je Grundkörper: Knochen -> Menge (m) nach außen; front = nur nach vorn (Bauch)
BODY_SHAPES = {
    "female": {
        "Rundlich": (dict(spine_01=0.018, spine_02=0.012, pelvis=0.02, thigh_l=0.02, thigh_r=0.02, upperarm_l=0.01,
                          upperarm_r=0.01, calf_l=0.006, calf_r=0.006, spine_03=0.006),
                     dict(spine_01=0.035, pelvis=0.02, spine_02=0.012)),
        "Schlank": (dict(spine_01=-0.008, spine_02=-0.006, pelvis=-0.01, thigh_l=-0.012, thigh_r=-0.012, upperarm_l=-0.006,
                         upperarm_r=-0.006, calf_l=-0.006, calf_r=-0.006), {}),
    },
    "male": {
        "Rundlich": (dict(spine_01=0.02, spine_02=0.018, pelvis=0.018, thigh_l=0.014, thigh_r=0.014, upperarm_l=0.006,
                          upperarm_r=0.006, spine_03=0.008),
                     dict(spine_01=0.06, spine_02=0.04, pelvis=0.025)),
        "Kraeftig": (dict(spine_03=0.012, clavicle_l=0.01, clavicle_r=0.01, upperarm_l=0.008, upperarm_r=0.008,
                          lowerarm_l=0.005, lowerarm_r=0.005, thigh_l=0.008, thigh_r=0.008), {}),
        "Schlank": (dict(spine_01=-0.01, spine_02=-0.012, spine_03=-0.014, clavicle_l=-0.01, clavicle_r=-0.01,
                         upperarm_l=-0.014, upperarm_r=-0.014, lowerarm_l=-0.008, lowerarm_r=-0.008,
                         thigh_l=-0.01, thigh_r=-0.01, calf_l=-0.006, calf_r=-0.006, pelvis=-0.008), {}),
    },
}

# Die Figuren: Grundkörper, Haut (Textur hell/dunkel + Farbton), Formregler, Größe, Teile
CHARACTERS = {
    "mila": dict(kind="female", skin=("light", (1.0, 0.96, 0.93)), shape={"Schlank": 0.5}, height=0.95,
                 hair=("long", (0.36, 0.22, 0.14)), brows=(0.3, 0.19, 0.12),
                 parts=["sweater_oversized:(0.55,0.42,0.5)", "leggings:(0.16,0.15,0.17)", "ankle_boots:(0.36,0.23,0.15)"]),
    "rosa": dict(kind="female", skin=("light", (0.9, 0.78, 0.66)), shape={"Rundlich": 0.85}, height=0.94,
                 hair=("long_curly", (0.38, 0.12, 0.09)), brows=(0.3, 0.1, 0.08),
                 parts=["blouse:(0.93,0.89,0.8)", "bodice:(0.26,0.33,0.2)", "long_skirt:(0.38,0.42,0.24)",
                        "flat_shoes:(0.32,0.2,0.13)"]),
    "hanna": dict(kind="female", skin=("light", (1.0, 0.94, 0.9)), shape={"Rundlich": 0.45}, height=0.92,
                  hair=("bun", (0.6, 0.58, 0.56)), brows=(0.5, 0.48, 0.46),
                  parts=["cardigan:(0.82,0.6,0.22)", "midi_skirt:(0.16,0.3,0.33)", "flat_shoes:(0.22,0.16,0.13)"]),
    "theo": dict(kind="male", skin=("dark", (1.0, 0.95, 0.9)), shape={"Schlank": 0.55}, height=0.97,
                 hair=("tousled", (0.1, 0.07, 0.06)), brows=(0.08, 0.06, 0.05),
                 parts=["sweater:(0.2,0.33,0.25)", "jeans:(0.22,0.3,0.45)", "sneakers:(0.9,0.87,0.8)"]),
    "bruno": dict(kind="male", skin=("light", (1.0, 0.9, 0.84)), shape={"Rundlich": 1.0, "Kraeftig": 0.4}, height=0.94,
                  hair=("short", (0.42, 0.24, 0.13)), brows=(0.35, 0.2, 0.11), beard=True,
                  parts=["shirt_rolled:(0.6,0.25,0.18)", "vest:(0.35,0.3,0.24)", "trousers:(0.4,0.3,0.2)",
                         "boots:(0.25,0.17,0.12)", "flat_cap:(0.35,0.32,0.28)"]),
    "arthur": dict(kind="male", skin=("light", (1.0, 0.95, 0.93)), shape={"Schlank": 0.35}, height=0.95,
                   hair=("side_part", (0.62, 0.61, 0.6)), brows=(0.52, 0.5, 0.48), mustache=True,
                   parts=["coat:(0.62,0.48,0.32)", "scarf:(0.62,0.16,0.14)", "trousers:(0.33,0.33,0.35)",
                          "shoes:(0.12,0.1,0.09)"]),
}


def _parse(part):
    name, col = part.split(":")
    return name, tuple(float(x) for x in col.strip("()").split(","))


# ---------------------------------------------------------------------------------------------
# Kleidungsstücke
# ---------------------------------------------------------------------------------------------

def _no(*bones):
    return set(bones)


HEAD = _no("Head", "neck_01")
HANDS = _no("hand_l", "hand_r") | {b + s for b in ("index", "middle", "ring", "pinky", "thumb") for s in
                                   ("_01_l", "_02_l", "_03_l", "_01_r", "_02_r", "_03_r")}
FEET = _no("foot_l", "foot_r", "ball_l", "ball_r")
LEGS = _no("thigh_l", "thigh_r", "calf_l", "calf_r") | FEET


def top_select(lm, sleeve_x, hem_z, neck_drop=0.0, back_drop=0.0, collar=False):
    """Oberteil grob auswählen (mit etwas Rand – die Säume schneidet top_cuts gerade ab)."""
    neck_z = lm["bones"]["neck_01"][0].z - 0.004
    hem_z = max(hem_z, lm["crotch_z"] + 0.1)

    def f(co, bone):
        if bone in HANDS:
            return False
        if bone in HEAD and not collar:
            return False
        if bone == "Head":
            return False
        ax = abs(co.x)
        if ax > sleeve_x + 0.04 or co.z < hem_z - 0.04:
            return False
        if bone in LEGS and co.z < lm["hip_z"] - 0.02 and ax < lm["shoulder_x"]:
            # Oberschenkel nur knapp unter der Hüfte (nie in den Schritt)
            return co.z >= hem_z - 0.04 and ax > 0.03
        if ax > lm["shoulder_x"] + 0.03:
            return True
        # Hals großzügig – den geraden Ausschnitt schneidet neck_cuts
        return co.z <= neck_z + (0.04 if collar else 0.02)
    return f


def top_cuts(lm, sleeve_x, hem_z):
    # Nie tiefer als knapp über dem Beinansatz (dort ist der Rumpf noch ein einfacher Ring)
    hem_z = max(hem_z, lm["crotch_z"] + 0.1)
    return [((0, 0, hem_z), (0, 0, 1)), ((sleeve_x, 0, 0), (-1, 0, 0)), ((-sleeve_x, 0, 0), (1, 0, 0))]


def neck_cuts(lm, drop, back_drop=0.0, v=False):
    """Gerader Halsausschnitt: geneigte Ebene (vorn tiefer), nur im Bereich um den Hals.
    v = V-Ausschnitt (zwei Ebenen von der Mitte nach oben zu den Seiten)."""
    nz = lm["bones"]["neck_01"][0].z - 0.004
    low = lm["shoulder_z"] - 0.08 - drop
    if v:
        k = drop / 0.09
        zv = nz - drop
        return [((0, 0, zv), (k, 0, -1), lambda c: c.x >= 0 and c.y < 0.03 and abs(c.x) < 0.1 and c.z > zv - 0.03),
                ((0, 0, zv), (-k, 0, -1), lambda c: c.x <= 0 and c.y < 0.03 and abs(c.x) < 0.1 and c.z > zv - 0.03),
                ((0, 0, nz - back_drop), (0, 0, -1), lambda c: c.y >= 0.03 and abs(c.x) < 0.09 and c.z > low)]
    a = (drop - back_drop) / 0.14
    z0 = nz - (drop + back_drop) / 2
    return [((0, 0, z0), (0, a, -1), lambda c: abs(c.x) < 0.22 and c.z > low)]


def bottom_select(lm, waist_z, cuff_z):
    def f(co, bone):
        if bone in HANDS or bone in HEAD or bone in ("upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"):
            return False
        return cuff_z - 0.04 <= co.z <= waist_z + 0.03 and abs(co.x) < 0.32
    return f


def foot_select(lm, top_z):
    def f(co, bone):
        return co.z <= top_z + 0.04 and (bone in LEGS) and abs(co.x) < 0.3
    return f


def make_part(base, part, color):
    """Ein Kleidungsstück nach Namen bauen. Liefert (Objekte, verdeckte Körperteile)."""
    lm = base["lm"]
    mat = C.cloth_mat(part, color)
    knit = lambda c: tuple(min(1.0, x * 0.85) for x in c)  # noqa: E731
    if part in ("sweater", "sweater_oversized", "cardigan"):
        big = part == "sweater_oversized"
        hem = lm["hip_z"] - (0.1 if big else 0.06)
        off = 0.022 if big else 0.014
        sx = lm["wrist_x"] - 0.035
        obj = C.shell(base, part, top_select(lm, sx, hem, neck_drop=0.02 if part != "cardigan" else 0.09),
                      off, mat, smooth=10, offset_fn=(lambda co: off + 0.012 * max(0.0, (lm["waist_z"] - co.z) / 0.2)) if big else None,
                      cuts=top_cuts(lm, sx, hem) + neck_cuts(lm, 0.02 if part != "cardigan" else 0.11, 0.0, v=part == "cardigan"),
                      keep_boundary=True)
        C.drape(obj, Vector((0.0, lm["bones"]["pelvis"][0].y, 0.0)), lm["hip_z"] + 0.03)
        objs = [obj]
        # Bündchen: Ring am Saum und an den Ärmeln (etwas dunkler)
        objs.append(_cuff_ring(base, obj, part + "Cuffs", C.cloth_mat(part + "Rib", knit(color))))
        if part == "cardigan":
            pts = []
            for k in range(4):
                z = lm["chest_z"] - 0.03 - k * 0.075
                p, n = C.surface_point(base, 0.0, z)
                if p is not None:
                    pts.append((p + n * 0.02, n))
            objs.append(C.buttons(base, part + "Buttons", C.cloth_mat("Buttons", (0.42, 0.3, 0.2), 0.4), pts))
        return objs, ["Torso", "UpperArms", "LowerArms"]
    if part == "blouse":
        obj = C.shell(base, part, top_select(lm, lm["wrist_x"] - 0.05, lm["hip_z"] - 0.02, neck_drop=0.07, back_drop=0.03),
                      0.012, mat, smooth=10, cuts=top_cuts(lm, lm["wrist_x"] - 0.05, lm["hip_z"] - 0.02) + neck_cuts(lm, 0.08, 0.03),
                      keep_boundary=True,
                      offset_fn=lambda co: 0.012 + 0.03 * math.sin(math.pi * min(1.0, max(0.0, (abs(co.x) - lm["shoulder_x"]) / (lm["wrist_x"] - lm["shoulder_x"])))))
        return [obj], ["Torso", "UpperArms", "LowerArms"]
    if part == "bodice":
        sel = top_select(lm, lm["shoulder_x"] - 0.01, lm["hip_z"] - 0.03)
        under_bust = lm["chest_z"] - 0.05
        obj = C.shell(base, part, lambda co, b: sel(co, b) and co.z <= under_bust + 0.03, 0.03, mat, smooth=6, push_min=0.024,
                      cuts=top_cuts(lm, lm["shoulder_x"] - 0.01, lm["hip_z"] - 0.03) + [((0, 0, under_bust), (0, 0, -1))],
                      keep_boundary=True)
        return [obj], []
    if part == "vest":
        sel = top_select(lm, lm["shoulder_x"] + 0.02, lm["hip_z"] - 0.02, neck_drop=0.2)
        obj = C.shell(base, part, sel, 0.032, mat, smooth=6, push_min=0.026,
                      cuts=top_cuts(lm, lm["shoulder_x"] + 0.02, lm["hip_z"] - 0.02) + neck_cuts(lm, 0.2, 0.02, v=True),
                      keep_boundary=True)
        pts = []
        for k in range(4):
            z = lm["chest_z"] - 0.08 - k * 0.07
            p, n = C.surface_point(base, 0.0, z)
            if p is not None:
                pts.append((p + n * 0.034, n))
        return [obj, C.buttons(base, "vestButtons", C.cloth_mat("VestButtons", (0.75, 0.62, 0.35), 0.35), pts)], []
    if part == "shirt_rolled":
        elbow = lm["elbow_x"] + 0.03
        obj = C.shell(base, part, top_select(lm, elbow, lm["hip_z"] - 0.03, neck_drop=0.05), 0.012, mat, smooth=8,
                      cuts=top_cuts(lm, elbow, lm["hip_z"] - 0.03) + neck_cuts(lm, 0.06, 0.0, v=True), keep_boundary=True)
        return [obj, _cuff_ring(base, obj, "shirtRoll", mat, only_arms=True, width=0.035)], ["Torso", "UpperArms"]
    if part == "coat":
        obj = C.shell(base, "coat", top_select(lm, lm["wrist_x"] - 0.03, lm["waist_z"] - 0.02), 0.026, mat,
                      smooth=10, push_min=0.02, cuts=top_cuts(lm, lm["wrist_x"] - 0.03, lm["waist_z"] - 0.02) + neck_cuts(lm, 0.04),
                      keep_boundary=True)
        skirt = C.bell(base, "coatSkirt", lm["waist_z"] + 0.0, lm["knee_z"] - 0.08, mat, flare=0.08, offset=0.03,
                       open_front=0.0)
        pts = []
        for k in range(4):
            z = lm["chest_z"] - 0.02 - k * 0.1
            p, n = C.surface_point(base, 0.06, z)
            if p is not None:
                pts.append((p + n * 0.03, n))
        btn = C.buttons(base, "coatButtons", C.cloth_mat("CoatButtons", (0.25, 0.18, 0.12), 0.4), pts, radius=0.011)
        return [obj, skirt, btn], ["Torso", "UpperArms", "LowerArms", "Hips"]
    if part in ("leggings", "jeans", "trousers"):
        cuff = lm["ankle_z"] + (0.07 if part == "leggings" else 0.05)
        off = {"leggings": 0.004, "jeans": 0.012, "trousers": 0.016}[part]
        obj = C.shell(base, part, bottom_select(lm, lm["waist_z"] + 0.015, cuff), off, mat, smooth=6 if part != "leggings" else 3,
                      push_min=off * 0.7, cuts=[((0, 0, cuff), (0, 0, 1)), ((0, 0, lm["waist_z"] + 0.015), (0, 0, -1))],
                      keep_boundary=True)
        return [obj], ["Hips", "Thighs", "Calves"]
    if part in ("long_skirt", "midi_skirt"):
        bottom = lm["ankle_z"] + 0.1 if part == "long_skirt" else lm["knee_z"] - 0.2
        skirt = C.bell(base, part, lm["waist_z"] + 0.02, bottom, mat, flare=0.14 if part == "long_skirt" else 0.1, offset=0.014)
        band = _waistband(base, part + "Band", C.cloth_mat(part + "Band", knit(color)), lm["waist_z"] + 0.01, 0.018)
        return [skirt, band], ["Hips", "Thighs"]
    if part in ("ankle_boots", "boots", "sneakers", "shoes", "flat_shoes"):
        top = {"ankle_boots": lm["ankle_z"] + 0.1, "boots": lm["ankle_z"] + 0.09, "sneakers": lm["ankle_z"] + 0.0,
               "shoes": lm["ankle_z"] - 0.01, "flat_shoes": lm["ankle_z"] - 0.025}[part]
        sole_col = (0.92, 0.9, 0.85) if part == "sneakers" else (0.14, 0.11, 0.09)
        objs = C.shoe(base, part, mat, C.cloth_mat(part + "Sole", sole_col, 0.7), top,
                      shaft=part in ("ankle_boots", "boots"), side_off=0.009 if part != "flat_shoes" else 0.006,
                      sole=0.018 if part in ("boots", "ankle_boots", "sneakers") else 0.012)
        ankle = lm["ankle_z"]
        hide = lambda co, b, top=top: b in FEET or (b in ("calf_l", "calf_r") and co.z < max(top, ankle) - 0.015)  # noqa: E731
        return objs, ["Feet"], hide
    if part == "scarf":
        n0 = lm["bones"]["neck_01"][0]
        path = []
        for k in range(17):
            a = 2 * math.pi * k / 16
            path.append(Vector((math.sin(a) * 0.075, n0.y - math.cos(a) * 0.072, n0.z - 0.012 + 0.008 * math.sin(a * 2))))
        ring = C.tube_object(base, "scarf", mat, path, 0.026, {"neck_01": 0.6, "spine_03": 0.4}, segments=10)
        tail = [Vector((0.05, n0.y - 0.08, n0.z - 0.02)), Vector((0.07, n0.y - 0.115, n0.z - 0.12)),
                Vector((0.075, n0.y - 0.13, n0.z - 0.26))]
        tail = [_out_of(base, p, 0.035) for p in tail]
        t = C.tube_object(base, "scarfTail", mat, tail, lambda t: 0.024 * (1 - 0.15 * t), {"spine_03": 1.0}, segments=10)
        return [ring, t], []
    if part == "flat_cap":
        head = C.HeadShape(base)
        cap = C.scalp_cap(base, "flat_cap", mat, lambda az: 22 if abs(az) < 60 else 12, off=0.03)
        # Schirm vorn
        import bmesh
        me = bpy.data.meshes.new("capBrim")
        brim = bpy.data.objects.new("capBrim", me)
        base["body"].users_collection[0].objects.link(brim)
        bm = bmesh.new()
        ring_in, ring_out = [], []
        for k in range(9):
            az = -55 + 110 * k / 8
            p, d = head.surface(az, 22, 0.03)
            ring_in.append(bm.verts.new(p))
            ring_out.append(bm.verts.new(p + Vector((d.x, d.y, 0)).normalized() * 0.055 + Vector((0, 0, -0.012))))
        top_in = [bm.verts.new(v.co + Vector((0, 0, 0.006))) for v in ring_in]
        top_out = [bm.verts.new(v.co + Vector((0, 0, 0.006))) for v in ring_out]
        for k in range(8):
            bm.faces.new((ring_in[k], ring_in[k + 1], ring_out[k + 1], ring_out[k]))
            bm.faces.new((top_in[k], top_out[k], top_out[k + 1], top_in[k + 1]))
            bm.faces.new((ring_out[k], ring_out[k + 1], top_out[k + 1], top_out[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        brim.vertex_groups.new(name="Head").add(list(range(len(me.vertices))), 1.0, "REPLACE")
        brim.parent = base["arm"]
        brim.modifiers.new("Armature", "ARMATURE").object = base["arm"]
        return [cap, brim], []
    raise ValueError("Unbekanntes Kleidungsstück: " + part)


def _out_of(base, p, margin):
    tree = C.body_bvh(base["body"])
    loc, nrm, _, _ = tree.find_nearest(p)
    if loc is not None and (p - loc).dot(nrm) < margin:
        p = loc + nrm * margin
    return p


def _cuff_ring(base, obj, name, mat, only_arms=False, width=0.025):
    """Bündchen: an jedem offenen Rand des Kleidungsstücks ein dickes Band (Röhre)."""
    import bmesh
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    loops = _boundary_loops(bm)
    bm.free()
    out = None
    lm = base["lm"]
    parts = []
    for loop in loops:
        cen = sum(loop, Vector()) / len(loop)
        if only_arms and abs(cen.x) < lm["shoulder_x"] + 0.05:
            continue
        neck = cen.z > lm["shoulder_z"] - 0.06 and abs(cen.x) < lm["shoulder_x"]
        if neck and only_arms:
            continue
        pts = loop + [loop[0]]
        # Leicht nach außen
        pts = [p + (p - cen).normalized() * 0.004 for p in pts]
        bones = _bones_near(base, cen)
        # Halsbündchen schmaler
        parts.append(C.tube_object(base, name, mat, pts, width / (3.4 if neck else 2.6), bones, segments=8))
    if not parts:
        return None
    if len(parts) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
    out = parts[0]
    out.name = name
    return out


def _bones_near(base, p):
    """Gewichte des nächsten Körperpunkts."""
    body = base["body"]
    best, bi = 1e9, 0
    for v in body.data.vertices:
        d = (v.co - p).length_squared
        if d < best:
            best, bi = d, v.index
    return C.weights_of(body, body.data.vertices[bi])


def _boundary_loops(bm):
    edges = [e for e in bm.edges if e.is_boundary]
    used = set()
    loops = []
    adj = {}
    for e in edges:
        for v in e.verts:
            adj.setdefault(v.index, []).append(e)
    for e in edges:
        if e.index in used:
            continue
        loop = [e.verts[0]]
        cur_e, cur_v = e, e.verts[1]
        used.add(e.index)
        while cur_v != loop[0]:
            loop.append(cur_v)
            nxt = [x for x in adj.get(cur_v.index, []) if x.index not in used]
            if not nxt:
                break
            cur_e = nxt[0]
            used.add(cur_e.index)
            cur_v = cur_e.other_vert(cur_v)
        if len(loop) > 5:
            loops.append([v.co.copy() for v in loop])
    return loops


def _waistband(base, name, mat, z, off):
    tree = C.body_bvh(base["body"])
    pts = []
    pel = base["lm"]["bones"]["pelvis"][0]
    for k in range(25):
        a = 2 * math.pi * k / 24
        d = Vector((math.sin(a), -math.cos(a), 0.0))
        hit = tree.ray_cast(Vector((0, pel.y, z)) + d * 0.5, -d)
        p = hit[0] if hit[0] is not None else Vector((0, pel.y, z)) + d * 0.15
        pts.append(p + d * off)
    return C.tube_object(base, name, mat, pts, 0.014, {"pelvis": 0.6, "spine_01": 0.4}, segments=8)


def _flatten_sole(obj):
    """Schuhsohle flach auf den Boden."""
    me = obj.data
    keys = C._key_coords(me)
    for cos in keys:
        for c in cos:
            if c.z < 0.012:
                c.z = max(-0.003, min(c.z, 0.0) if c.z < 0.004 else c.z)
    C._write_keys(me, keys)


# ---------------------------------------------------------------------------------------------
# Frisuren
# ---------------------------------------------------------------------------------------------

def make_hair(base, style, color, extra):
    mat = C.cloth_mat("Hair", color, rough=0.5)
    dark = C.cloth_mat("HairBase", tuple(x * 0.75 for x in color), rough=0.6)
    objs = []
    if style in ("long", "long_curly"):
        objs.append(C.scalp_cap(base, "hairCap", dark, lambda az: C.hairline_soft(az) + 2, off=0.006))
        objs.append(C.long_hair(base, "hair", mat, length=0.42 if style == "long" else 0.36, count=26, width=0.068,
                                wave=0.018 if style == "long" else 0.032, curl=0.0 if style == "long" else 0.04,
                                seed=2 if style == "long" else 9))
    elif style == "bun":
        objs.append(C.scalp_cap(base, "hairCap", dark, lambda az: C.hairline_soft(az) + 2, off=0.006))
        objs.append(C.bun_hair(base, "hair", mat))
    elif style in ("tousled", "short", "side_part"):
        hl = (lambda az: C.hairline_soft(az, front=34, temple=16, side=8, back=-30) + 1)
        objs.append(C.scalp_cap(base, "hairCap", dark, hl, off=0.005))
        if style == "tousled":
            objs.append(C.cropped_hair(base, "hair", mat, count=30, tip=0.045, lift=0.012, front_up=0.03, messy=0.8,
                                       width=0.055, thick=0.017, seed=4))
        elif style == "short":
            objs.append(C.cropped_hair(base, "hair", mat, count=36, tip=0.02, lift=0.003, width=0.042, thick=0.012, seed=6))
        else:
            objs.append(C.cropped_hair(base, "hair", mat, count=32, part_az=-40, tip=0.03, lift=0.008, width=0.05,
                                       thick=0.014, seed=8))
    if extra.get("beard"):
        objs += C.beard(base, "beard", mat, full=True, mustache=True)
    elif extra.get("mustache"):
        objs += C.beard(base, "beard", mat, full=False, mustache=True)
    return objs


# ---------------------------------------------------------------------------------------------
# Ablauf
# ---------------------------------------------------------------------------------------------

# Kleidungsschichten von innen nach außen (Teile mit diesem Namensanfang)
LAYERS = [("leggings", "jeans", "trousers"), ("sweater", "cardigan", "blouse", "shirt_rolled"),
          ("bodice", "vest", "coat", "long_skirt", "midi_skirt")]


def _layer_clothes(clothes):
    """Äußere Schichten liegen immer über den inneren (kein Durchstechen an der Hüfte)."""
    def layer_of(o):
        for i, names in enumerate(LAYERS):
            if any(o.name.startswith(n) for n in names) and "Cuffs" not in o.name and "Buttons" not in o.name:
                return i
        return None
    for i in range(1, len(LAYERS)):
        inner = [o for o in clothes if layer_of(o) is not None and layer_of(o) < i]
        if not inner:
            continue
        for o in clothes:
            if layer_of(o) == i and o.data.polygons:
                C.push_out_of(o, inner, 0.006)


def prepare_base(kind):
    base = C.load_base(kind)
    if kind == "male":
        # Weniger Superheld: schmalere Schultern und Arme, weichere Brust, kräftigerer Hals
        deltas = C.radial_field(base, dict(upperarm_l=-0.012, upperarm_r=-0.012, lowerarm_l=-0.005, lowerarm_r=-0.005,
                                           clavicle_l=-0.01, clavicle_r=-0.01, spine_03=-0.01, neck_01=0.008))
        for v, d in zip(base["body"].data.vertices, deltas):
            v.co += d
    C.soften_body(base, 1.0 if kind == "female" else 2.0)
    C.scale_head(base, 1.06 if kind == "female" else 1.045)
    for name, (amounts, front) in BODY_SHAPES[kind].items():
        C.add_shape_key(base, name, C.radial_field(base, amounts, front))
    return base


def build_character(name, render_only=False):
    spec = CHARACTERS[name]
    C.reset()
    base = prepare_base(spec["kind"])
    C.skin_material(base, spec["skin"][0], spec["skin"][1])
    C.tint_material(base["brows"], spec["brows"])
    for kb in base["body"].data.shape_keys.key_blocks[1:]:
        kb.value = spec["shape"].get(kb.name, 0.0)
    clothes, covered, hides = [], set(), []
    for part in spec["parts"]:
        pname, col = _parse(part)
        res = make_part(base, pname, col)
        objs, cov = res[0], res[1]
        if len(res) > 2:
            hides.append(res[2])
        clothes += [o for o in objs if o]
        covered |= set(cov)
    _layer_clothes(clothes)
    hair = make_hair(base, spec["hair"][0], spec["hair"][1], spec)
    if render_only:
        if hides:
            C.hide_by(base, lambda co, b: any(h(co, b) for h in hides))
        C.hide_covered(base, [o for o in clothes if o.data.polygons and o.type == "MESH"])
    for o in clothes + hair:
        if o.data.shape_keys:
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = spec["shape"].get(kb.name, 0.0)
    return base, clothes, hair


def render_character(name, base):
    C.setup_render()
    top = base["lm"]["top"]
    os.makedirs(SHOTS, exist_ok=True)
    C.render(os.path.join(SHOTS, name + "-front.png"), (0.0, -4.2, 1.0), (0.0, 0.0, 0.92), lens=40)
    C.render(os.path.join(SHOTS, name + "-side.png"), (3.0, -3.0, 1.1), (0.0, 0.0, 0.92), lens=40)
    C.render(os.path.join(SHOTS, name + "-head.png"), (0.35, -1.0, top - 0.08), (0.0, 0.0, top - 0.12), lens=60)
    C.render(os.path.join(SHOTS, name + "-back.png"), (-1.2, 2.4, 1.5), (0.0, 0.0, 1.25), lens=45)
    C.render(os.path.join(SHOTS, name + "-hem.png"), (0.25, -1.1, 0.75), (0.0, 0.0, 0.85), lens=50)


def export_character(name):
    """Fertige Figur: Formregler fest, verdeckter Körper weg, Größe übernommen; .glb (Godot),
    .fbx (Mixamo, nur Netze in T-Pose) und .blend."""
    spec = CHARACTERS[name]
    base, clothes, hair = build_character(name, render_only=True)
    objs = [base["body"], base["eyes"], base["brows"]] + clothes + hair
    objs = [o for o in objs if o and o.type == "MESH" and len(o.data.polygons)]
    C.apply_shape_mix(objs, spec["shape"])
    C.scale_character(base, spec["height"])
    for o in objs:
        o.data.name = o.name
    C.export_glb(os.path.join(OUT, name + ".glb"), objs, base["arm"], keep_shape_keys=False)
    C.export_fbx(os.path.join(OUT, "mixamo", name + ".fbx"), objs, base["arm"])
    os.makedirs(SRC, exist_ok=True)
    C.display_materials()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, name + ".blend"), compress=True)
    tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    print("%s: %d Dreiecke, %.2f m groß" % (name, tris, base["lm"]["top"]))


def export_kit(kind):
    """Baukasten je Grundkörper: Körper in Teilen (mit Formreglern), alle Kleidungsstücke und
    Frisuren der Figuren dieses Körpers (je Teil einmal), Skelett in T-Pose."""
    C.reset()
    base = prepare_base(kind)
    tone = "light"
    C.skin_material(base, tone, (1.0, 0.95, 0.9))
    parts, seen = [], set()
    for name, spec in CHARACTERS.items():
        if spec["kind"] != kind:
            continue
        for part in spec["parts"]:
            pname, col = _parse(part)
            if pname in seen:
                continue
            seen.add(pname)
            res = make_part(base, pname, col)
            for o in res[0]:
                if o:
                    o["covers"] = ",".join(res[1])
                    parts.append(o)
        style = spec["hair"][0]
        if style not in seen:
            seen.add(style)
            for o in make_hair(base, style, spec["hair"][1], spec):
                o.name = "hair_" + style + ("_" + o.name if not o.name.startswith("hair") else o.name[4:])
                parts.append(o)
    segments = C.split_segments(base)
    objs = list(segments.values()) + [base["eyes"], base["brows"]] + [o for o in parts if o.type == "MESH" and len(o.data.polygons)]
    C.export_glb(os.path.join(OUT, "kit_%s.glb" % kind), objs, base["arm"], keep_shape_keys=True)
    os.makedirs(SRC, exist_ok=True)
    C.display_materials()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "kit_%s.blend" % kind), compress=True)
    print("Baukasten %s: %d Teile" % (kind, len(objs)))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in argv if not a.startswith("--")] or list(CHARACTERS)
    if "--render" in argv:
        for n in names:
            base, clothes, hair = build_character(n, render_only=True)
            render_character(n, base)
        return
    for n in names:
        export_character(n)
    if "--no-kit" not in argv:
        for kind in ("female", "male"):
            export_kit(kind)


if __name__ == "__main__":
    main()
