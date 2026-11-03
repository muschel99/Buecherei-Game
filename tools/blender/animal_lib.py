"""Bausteine für weiche, organische Tiere (seit Etappe 6h): Körper aus Metaballs (Kugeln/Ellipsoide, die
weich ineinanderfließen wie bei den Chibi-Figuren – keine Kanten, keine Nähte), Teile, die genau auf der
Körperoberfläche liegen (Flügel als dünne, geschlossene Schale mit kleinem Abstand), und ein Sammel-Netz,
das alle Teile zu EINEM Netz mit Gewichten, Farbmaske und Formvarianten (Shape Keys) zusammenfügt.

Koordinaten wie in Blender: vorn = -y, oben = z, Ursprung zwischen den Füßen.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree


def smoothstep(a, b, x):
    if a == b:
        return 1.0 if x >= b else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------------------------
# Metaball-Körper
# ---------------------------------------------------------------------------------------------

class Blobs:
    """Körper aus Metaballs. add(...) = Kugel oder Ellipsoid (Größe = Halbachsen der Oberfläche in Metern, wenn
    das Teil allein stünde; Drehung in Grad), capsule(a, b, r) = Röhre von a nach b. Nahe Teile fließen weich
    ineinander (dann etwas dicker). mesh() rechnet die Oberfläche aus und liefert ein geschlossenes Netz,
    auf etwa target_faces Flächen vereinfacht.
    Blender rechnet Metaballs höchstens auf 5 mm genau – kleine Tiere werden darum in scale-facher Größe
    gebaut und am Ende verkleinert."""

    _count = 0
    # Oberfläche einer einzelnen Kugel (Steifheit 2, Schwelle 0,6) bei diesem Anteil des Radius
    SURFACE = 0.553

    def __init__(self, coll, resolution=0.006, threshold=0.6, scale=10.0):
        Blobs._count += 1
        # jeder Körper eine eigene „Familie“ (Metaballs mit gleichem Grundnamen verschmelzen sonst)
        self.name = "Weich%02dKoerper" % Blobs._count
        self.scale = scale
        self.mb = bpy.data.metaballs.new(self.name)
        self.mb.resolution = resolution
        self.mb.render_resolution = resolution
        self.mb.threshold = threshold
        self.obj = bpy.data.objects.new(self.name, self.mb)
        coll.objects.link(self.obj)

    def add(self, center, size, rot=(0, 0, 0), stiffness=2.0, negative=False):
        """Ellipsoid mit Halbachsen size (x, y, z) um center, gedreht um rot (Grad, Reihenfolge x, y, z)."""
        e = self.mb.elements.new(type="ELLIPSOID")
        k = self.scale / self.SURFACE
        r = max(size) * k
        e.co = Vector(center) * self.scale
        e.radius = r
        e.size_x, e.size_y, e.size_z = (s * k / r for s in size)
        e.rotation = (Matrix.Rotation(math.radians(rot[2]), 3, "Z") @ Matrix.Rotation(math.radians(rot[1]), 3, "Y")
                      @ Matrix.Rotation(math.radians(rot[0]), 3, "X")).to_quaternion()
        e.stiffness = stiffness
        e.use_negative = negative
        return e

    def add_axes(self, center, size, axes, stiffness=2.0, negative=False):
        """Ellipsoid mit Halbachsen size entlang der Achsen axes = (X, Y, Z) (Einheitsvektoren, rechtwinklig)."""
        e = self.mb.elements.new(type="ELLIPSOID")
        k = self.scale / self.SURFACE
        r = max(size) * k
        e.co = Vector(center) * self.scale
        e.radius = r
        e.size_x, e.size_y, e.size_z = (s * k / r for s in size)
        e.rotation = Matrix((axes[0], axes[1], axes[2])).transposed().to_quaternion()
        e.stiffness = stiffness
        e.use_negative = negative
        return e

    def capsule(self, a, b, radius, stiffness=2.0):
        """Röhre (Kapsel) von a nach b mit Radius (der Oberfläche)."""
        a, b = Vector(a) * self.scale, Vector(b) * self.scale
        d = b - a
        e = self.mb.elements.new(type="CAPSULE")
        e.co = (a + b) / 2
        e.radius = radius * self.scale / self.SURFACE
        e.size_x = d.length / 2
        # Kapseln liegen entlang ihrer x-Achse
        e.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())
        e.stiffness = stiffness
        return e

    def mesh(self, target_faces=None, smooth=2):
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.obj.evaluated_get(dg), depsgraph=dg)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(self.name + "_netz", me)
        self.obj.users_collection[0].objects.link(obj)
        if target_faces and len(me.polygons) > target_faces:
            mod = obj.modifiers.new("Vereinfachen", "DECIMATE")
            mod.ratio = target_faces / len(me.polygons)
            mod.use_collapse_triangulate = True
        if smooth:
            mod = obj.modifiers.new("Glätten", "SMOOTH")
            mod.factor = 0.5
            mod.iterations = smooth
        dg = bpy.context.evaluated_depsgraph_get()
        out = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), depsgraph=dg)
        out.transform(Matrix.Scale(1.0 / self.scale, 4))
        bpy.data.objects.remove(obj)
        bpy.data.objects.remove(self.obj)
        return out


def bvh_of(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


# ---------------------------------------------------------------------------------------------
# Sammel-Netz
# ---------------------------------------------------------------------------------------------

class Parts:
    """Sammelt Netze zu einem: Ecken, Flächen (je Fläche ein Material), Gewichte je Ecke (Funktion der Lage),
    Farbmaske je Ecke (UV2.y: > 0 = zweite Farbe, < 0 = dritte Farbe) und Formvarianten (Name → Lage je Ecke)."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.mats = []
        self.weights = []
        self.mask = []
        self.keys = {}
        self.materials = []

    def mat_index(self, mat):
        if mat not in self.materials:
            self.materials.append(mat)
        return self.materials.index(mat)

    def add_mesh(self, me, mat, weights, mask=None, keys=None, matrix=None):
        """Netz anfügen. weights(co) -> {knochen: gewicht} oder Liste je Ecke; mask(co) -> Wert oder Zahl;
        keys = {name: [Lage je Ecke]}."""
        base = len(self.verts)
        m = matrix or Matrix.Identity(4)
        mi = self.mat_index(mat)
        for k, v in enumerate(me.vertices):
            co = m @ v.co
            self.verts.append(co.copy())
            self.weights.append(weights[k] if isinstance(weights, list) else weights(co))
            self.mask.append(mask(co) if callable(mask) else (mask or 0.0))
        for name, positions in (keys or {}).items():
            arr = self.keys.setdefault(name, [None] * base)
            arr.extend(m @ Vector(p) for p in positions)
        for name, arr in self.keys.items():
            while len(arr) < len(self.verts):
                arr.append(None)
        for p in me.polygons:
            self.faces.append([base + i for i in p.vertices])
            self.mats.append(mi)

    def add_body(self, body, weights, mask=None, smooth_angle=180):
        """storybook_lib.Body bauen (mit weichen Kanten) und anfügen."""
        o = body.build(smooth_angle=smooth_angle)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        mat = o.data.materials[0] if o.data.materials else None
        self.add_mesh(me, mat, weights, mask, matrix=o.matrix_world)
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)

    def build(self, name, coll, preview=None):
        """Netz anlegen. preview = (Farbe Maske +, Farbe Maske −): färbt das Farbattribut „tint“ nach der Maske –
        nur für Kontrollbilder in Blender (im Spiel rechnet der Shader die Farben aus der Maske; dann weiß)."""
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        for mat in self.materials:
            me.materials.append(mat)
        for poly, mi in zip(me.polygons, self.mats):
            poly.material_index = mi
            poly.use_smooth = True
        me.use_auto_smooth = False
        ca = me.color_attributes.new("tint", "FLOAT_COLOR", "POINT")
        for i, m in enumerate(self.mask):
            c = Vector((1.0, 1.0, 1.0))
            if preview and m > 0:
                c = c.lerp(Vector(preview[0]), min(1.0, m))
            elif preview and m < 0:
                c = c.lerp(Vector(preview[1]), min(1.0, -m))
            ca.data[i].color = (c.x, c.y, c.z, 1.0)
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = 0
        obj = bpy.data.objects.new(name, me)
        coll.objects.link(obj)
        groups = {}
        for i, w in enumerate(self.weights):
            for bone, val in w.items():
                if val <= 1e-4:
                    continue
                if bone not in groups:
                    groups[bone] = obj.vertex_groups.new(name=bone)
                groups[bone].add([i], val, "REPLACE")
        # Formvarianten (Shape Keys)
        if self.keys:
            obj.shape_key_add(name="Basis", from_mix=False)
            for kname, arr in self.keys.items():
                sk = obj.shape_key_add(name=kname, from_mix=False)
                for i, p in enumerate(arr):
                    if p is not None:
                        sk.data[i].co = p
        # Texturkoordinaten: Ruhelage (UV = x, z; UV2 = -y, Maske) – siehe storybook_animal.gdshader
        uv1 = me.uv_layers.new(name="rest_xy")
        uv2 = me.uv_layers.new(name="rest_z")
        for loop in me.loops:
            co = me.vertices[loop.vertex_index].co
            uv1.data[loop.index].uv = (co.x, co.z)
            uv2.data[loop.index].uv = (-co.y, self.mask[loop.vertex_index])
        return obj


# ---------------------------------------------------------------------------------------------
# Teile auf der Körperoberfläche
# ---------------------------------------------------------------------------------------------

def surface_shell(tree, axis_point, axis_dir, grid, thickness, gap=0.0008, outline=None, spread=None):
    """Dünne, geschlossene Schale, die genau auf der Oberfläche eines Körpers liegt (z. B. angelegter Flügel).

    grid(u, v) -> (Punkt auf der Achse, Richtung nach außen): je Gitterpunkt wird von außen auf den Körper
    gezielt; getroffene Stelle + Normale = Lage der Schale. thickness(u, v) = Dicke, gap = Luft zum Körper.
    Außerhalb des Körpers (Federspitzen über den Schwanz hinaus) geht die Schale geradeaus weiter.
    spread(u, v, seite) -> Lage in der Formvariante (z. B. ausgebreiteter Flügel), seite = +1 außen, -1 innen.
    Liefert (Netz, Lagen der Formvariante oder None, (u, v) je Ecke)."""
    nu, nv = 18, 9
    outer, inner, key_out, key_in = {}, {}, {}, {}
    last = {}
    for i in range(nu + 1):
        u = i / nu
        for j in range(nv + 1):
            v = j / nv
            origin, out_dir = grid(u, v)
            origin, out_dir = Vector(origin), Vector(out_dir).normalized()
            start = origin + out_dir * 0.2
            hit = tree.ray_cast(start, -out_dir, 0.4)
            if hit[0] is not None:
                p, n = hit[0], hit[1]
                if n.dot(out_dir) < 0:
                    n = -n
                last[j] = (p, n, i)
            else:
                # über den Körper hinaus: geradeaus weiter (von der letzten getroffenen Stelle)
                p0, n, i0 = last.get(j, (origin, out_dir, i))
                prev_origin, _ = grid((i0) / nu, v)
                step = Vector(origin) - Vector(prev_origin)
                p = p0 + step
            t = thickness(u, v)
            outer[i, j] = p + n * (gap + t)
            inner[i, j] = p + n * gap
            if spread:
                key_out[i, j] = Vector(spread(u, v, 1))
                key_in[i, j] = Vector(spread(u, v, -1))
    bm = bmesh.new()
    vo = {k: bm.verts.new(p) for k, p in outer.items()}
    vi = {k: bm.verts.new(p) for k, p in inner.items()}
    order = list(vo.values()) + list(vi.values())
    keys = None
    if spread:
        keys = [key_out[k] for k in vo] + [key_in[k] for k in vi]
    params = [(k[0] / nu, k[1] / nv) for k in vo] + [(k[0] / nu, k[1] / nv) for k in vi]
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((vo[i, j], vo[i + 1, j], vo[i + 1, j + 1], vo[i, j + 1]))
            bm.faces.new((vi[i, j], vi[i, j + 1], vi[i + 1, j + 1], vi[i + 1, j]))
    # Rand: Außen- und Innenseite verbinden (geschlossener Körper)
    for i in range(nu):
        for j, flip in ((0, False), (nv, True)):
            a, b = (i, j), (i + 1, j)
            f = (vo[a], vi[a], vi[b], vo[b]) if not flip else (vo[a], vo[b], vi[b], vi[a])
            bm.faces.new(f)
    for j in range(nv):
        for i, flip in ((0, True), (nu, False)):
            a, b = (i, j), (i, j + 1)
            f = (vo[a], vi[a], vi[b], vo[b]) if not flip else (vo[a], vo[b], vi[b], vi[a])
            bm.faces.new(f)
    bm.verts.index_update()
    # Umlaufsinn nach außen (Godot zeichnet nur Vorderseiten)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Schale")
    # Reihenfolge der Ecken wie order (für die Formvariante)
    index = {v: k for k, v in enumerate(order)}
    verts = [None] * len(order)
    for v in bm.verts:
        verts[index[v]] = v.co.copy()
    faces = [[index[v] for v in f.verts] for f in bm.faces]
    bm.free()
    me.from_pydata([tuple(v) for v in verts], [], faces)
    return me, keys, params
