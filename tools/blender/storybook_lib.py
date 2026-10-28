"""Bausteine für die Häuser im Bilderbuch-Stil (eigene Modelle, unabhängig von style_lib).

Grundregeln:
  - Jedes Teil ist ein geschlossener Körper mit Dicke (keine einzelnen Flächen) – so lässt es
    sich in Blender weiter bearbeiten (Edit Mode, Sculpt, Modifikatoren).
  - Nichts ist ganz regelmäßig: Kästen sind fein unterteilt und leicht verbeult, Bauteile minimal
    gedreht, Blätter und Blüten haben jedes eine eigene Form, Größe und Farbe.
  - Weiche Kanten über einen Bevel-Modifikator (bleibt einstellbar).
  - Farbunterschiede je Teil über das Farbattribut "tint" (die Materialien multiplizieren es).

Koordinaten: Blender (x rechts, y nach hinten, z oben). Die Hausfront liegt bei y = 0 und zeigt
nach -y, der Boden liegt bei z = 0, Ursprung unten in der Mitte der Front (wie die Vorlagen im
Spiel: Godot +Z vorn = Blender -Y).
"""

import bmesh
import bpy
import math
import os
import random

from mathutils import Matrix, Vector, noise

FONT_DIR = "/usr/share/fonts/truetype/dejavu"
# Alle weichen Kanten (Bevel) um diesen Faktor breiter als im Bau-Script angegeben
BEVEL_SCALE = 1.6
# Rundungsstufen der weichen Kanten: (große Teile ab 1 cm, kleine Teile). Die Wohnhäuser setzen
# weniger (sparsamer fürs Spiel), die Läden behalten (3, 2).
BEVEL_SEGMENTS = (3, 2)


def srgb(c):
    """sRGB 0..1 -> linear (Blender rechnet linear)."""
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c[:3])


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# --- Sammlungen ---

def collection(name, parent=None):
    if name in bpy.data.collections:
        return bpy.data.collections[name]
    c = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(c)
    return c


# --- Materialien (matt, mit sichtbarer Materialität) ---

def image_material(name, path, rough=0.7, emit=0.0):
    """Material, das ein Bild zeigt (Schilder der Entwicklerin, assets/textures/signs/*.png),
    über die Texturkoordinaten "UVMap" der Schild-Platte (Body.panel)."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    bsdf = N["Principled BSDF"]
    tex = N.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=True)
    tex.interpolation = "Cubic"
    uv = N.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    L.new(uv.outputs["UV"], tex.inputs["Vector"])
    L.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular"].default_value = 0.25
    if emit > 0:
        L.new(tex.outputs["Color"], bsdf.inputs["Emission"])
        bsdf.inputs["Emission Strength"].default_value = emit
    m["schild_bild"] = path
    return m


def material(name, color, rough=0.85, grain="plaster", vary=0.08, scale=4.0, bump=0.25, metal=0.0, emit=0.0,
             emit_color=None, glass=False, color2=None, stripes=None):
    """Mattes Material: Grundfarbe x Farbton je Teil ("tint") x leichte Flecken (Rauschen).
    grain: plaster (Putz), stone, wood (feine Maserung), paint (gestrichenes Holz, matt), fabric, leaf,
    smooth, brick, ashlar (große Quader) – wie im Godot-Shader storybook.gdshaderinc.
    stripes = Breite der Streifen (m) in color/color2 (Markisenstoff)."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    bsdf = N["Principled BSDF"]
    coord = N.new("ShaderNodeTexCoord")
    base = N.new("ShaderNodeRGB")
    base.outputs[0].default_value = (*srgb(color), 1)
    col = base.outputs[0]
    if stripes:
        # Streifen entlang x (Objektkoordinaten), Kanten leicht unruhig wie gewebt
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(coord.outputs["Object"], sep.inputs[0])
        wob = N.new("ShaderNodeTexNoise")
        wob.inputs["Scale"].default_value = 3.0
        L.new(coord.outputs["Object"], wob.inputs["Vector"])
        add = N.new("ShaderNodeMath")
        add.operation = "MULTIPLY_ADD"
        L.new(wob.outputs["Fac"], add.inputs[0])
        add.inputs[1].default_value = 0.012
        L.new(sep.outputs["X"], add.inputs[2])
        div = N.new("ShaderNodeMath")
        div.operation = "DIVIDE"
        L.new(add.outputs[0], div.inputs[0])
        div.inputs[1].default_value = stripes * 2
        frac = N.new("ShaderNodeMath")
        frac.operation = "FRACT"
        L.new(div.outputs[0], frac.inputs[0])
        step = N.new("ShaderNodeMath")
        step.operation = "GREATER_THAN"
        step.inputs[1].default_value = 0.5
        L.new(frac.outputs[0], step.inputs[0])
        c2 = N.new("ShaderNodeRGB")
        c2.outputs[0].default_value = (*srgb(color2), 1)
        mix = N.new("ShaderNodeMixRGB")
        L.new(step.outputs[0], mix.inputs[0])
        L.new(base.outputs[0], mix.inputs[1])
        L.new(c2.outputs[0], mix.inputs[2])
        col = mix.outputs[0]
    attr = N.new("ShaderNodeAttribute")
    attr.attribute_name = "tint"
    mul = N.new("ShaderNodeMixRGB")
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    L.new(col, mul.inputs[1])
    L.new(attr.outputs["Color"], mul.inputs[2])
    # Flecken: Helligkeit wandert leicht (handgemalt)
    blot = N.new("ShaderNodeTexNoise")
    blot.inputs["Scale"].default_value = scale
    blot.inputs["Detail"].default_value = 4.0
    L.new(coord.outputs["Object"], blot.inputs["Vector"])
    rng = N.new("ShaderNodeMapRange")
    rng.inputs["To Min"].default_value = 1.0 - vary
    rng.inputs["To Max"].default_value = 1.0 + vary
    rng.inputs["From Min"].default_value = 0.3
    rng.inputs["From Max"].default_value = 0.7
    L.new(blot.outputs["Fac"], rng.inputs["Value"])
    hsv = N.new("ShaderNodeHueSaturation")
    L.new(mul.outputs[0], hsv.inputs["Color"])
    L.new(rng.outputs[0], hsv.inputs["Value"])
    col = hsv.outputs[0]
    height = None
    if grain == "wood":
        wave = N.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "Z"
        # ruhige, breite Maserung (wie im Godot-Shader: keine feinen Linien)
        wave.inputs["Scale"].default_value = 3.5
        wave.inputs["Distortion"].default_value = 3.0
        wave.inputs["Detail"].default_value = 2.0
        L.new(coord.outputs["Object"], wave.inputs["Vector"])
        dark = N.new("ShaderNodeMapRange")
        dark.inputs["To Min"].default_value = 0.92
        L.new(wave.outputs["Fac"], dark.inputs["Value"])
        hv = N.new("ShaderNodeHueSaturation")
        L.new(col, hv.inputs["Color"])
        L.new(dark.outputs[0], hv.inputs["Value"])
        col = hv.outputs[0]
        height = None
    elif grain == "stone":
        # weich unregelmäßig, keine Risslinien
        st = N.new("ShaderNodeTexNoise")
        st.inputs["Scale"].default_value = 9.0
        st.inputs["Detail"].default_value = 4.0
        L.new(coord.outputs["Object"], st.inputs["Vector"])
        height = st.outputs["Fac"]
    elif grain in ("brick", "ashlar"):
        # Mauerwerk wie im Godot-Shader: Ziegel 34 x 11,5 cm, Quader 46 x 27 cm; Steinfarbe =
        # Grundfarbe x Farbton des Teils ("tint"), Fuge = color2 (nicht eingefärbt)
        ash = grain == "ashlar"
        brick = N.new("ShaderNodeTexBrick")
        brick.inputs["Scale"].default_value = 1.0
        brick.inputs["Mortar Size"].default_value = 0.012 if ash else 0.01
        brick.inputs["Mortar Smooth"].default_value = 0.7 if ash else 0.6
        brick.inputs["Bias"].default_value = 0.0
        brick.inputs["Brick Width"].default_value = 0.46 if ash else 0.34
        brick.inputs["Row Height"].default_value = 0.27 if ash else 0.115
        if ash:
            brick.offset = 0.37
        L.new(mul.outputs[0], brick.inputs["Color1"])
        dark = N.new("ShaderNodeMixRGB")
        dark.blend_type = "MULTIPLY"
        dark.inputs[0].default_value = 1.0
        dark.inputs[2].default_value = (0.86, 0.84, 0.8, 1) if not ash else (1.04, 1.02, 0.95, 1)
        L.new(mul.outputs[0], dark.inputs[1])
        L.new(dark.outputs[0], brick.inputs["Color2"])
        brick.inputs["Mortar"].default_value = (*srgb(color2 or (0.6, 0.53, 0.44)), 1)
        # Steine liegen waagerecht auf allen Seiten: Koordinaten (x + y, z)
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(coord.outputs["Object"], sep.inputs[0])
        xy = N.new("ShaderNodeMath")
        L.new(sep.outputs["X"], xy.inputs[0])
        L.new(sep.outputs["Y"], xy.inputs[1])
        comb = N.new("ShaderNodeCombineXYZ")
        L.new(xy.outputs[0], comb.inputs["X"])
        L.new(sep.outputs["Z"], comb.inputs["Y"])
        L.new(comb.outputs[0], brick.inputs["Vector"])
        col = brick.outputs["Color"]
        height = brick.outputs["Fac"]
    else:
        fine = N.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = {"plaster": 7.0, "fabric": 90.0, "leaf": 5.0, "smooth": 25.0, "paint": 6.0}.get(grain, 40.0)
        fine.inputs["Detail"].default_value = 8.0
        L.new(coord.outputs["Object"], fine.inputs["Vector"])
        height = fine.outputs["Fac"]
    L.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Specular"].default_value = 0.3
    if height is not None and bump > 0:
        b = N.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump
        b.inputs["Distance"].default_value = 0.02
        L.new(height, b.inputs["Height"])
        L.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    if emit > 0:
        ec = N.new("ShaderNodeRGB")
        ec.outputs[0].default_value = (*srgb(emit_color or color), 1)
        L.new(ec.outputs[0], bsdf.inputs["Emission"])
        bsdf.inputs["Emission Strength"].default_value = emit
    if glass:
        # Klar, aber nicht spiegelnd: kaum Brechung, leicht matt
        bsdf.inputs["Transmission"].default_value = 1.0
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["IOR"].default_value = 1.05
        bsdf.inputs["Specular"].default_value = 0.15
    return m


# --- Körper ---

class Body:
    """Sammelt geschlossene Körper (Inseln) für EIN Blender-Objekt. Jede Insel bekommt einen
    eigenen Farbton (tint), leicht wärmer/kühler und heller/dunkler."""

    def __init__(self, name, mat, coll, seed=1, vary=0.05, bevel=0.0):
        self.name = name
        self.mat = mat
        self.coll = coll
        self.rnd = random.Random(seed)
        self.vary = vary
        self.bevel = bevel
        self.bm = bmesh.new()
        self.tint = self.bm.verts.layers.float_color.new("tint")
        self.uv = None
        self.extra_mats = []

    # Farbton der zuletzt gebauten Verts
    def _paint(self, verts, tint=None):
        if tint is None:
            v = 1.0 + self.rnd.uniform(-self.vary, self.vary)
            w = self.rnd.uniform(-self.vary, self.vary) * 0.6
            tint = (v * (1 + w), v, v * (1 - w))
        for vert in verts:
            vert[self.tint] = (*tint, 1.0)

    def _finish_island(self, verts, faces, tint=None):
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        for f in faces:
            f.smooth = True
        self._paint(verts, tint)

    def box(self, center, size, step=0.25, turn=(0, 0, 0), dent=0.004, dent_scale=3.0, tint=None, matrix=None):
        """Kasten (fein unterteilt, damit er sich biegen lässt), leicht verbeult (dent) und um
        turn Grad gedreht."""
        sx, sy, sz = size
        nx, ny, nz = (max(1, int(round(s / step))) for s in (sx, sy, sz))
        m = Matrix.Translation(center) @ Matrix.Rotation(math.radians(turn[2]), 4, "Z") @ \
            Matrix.Rotation(math.radians(turn[1]), 4, "Y") @ Matrix.Rotation(math.radians(turn[0]), 4, "X")
        if matrix is not None:
            m = matrix @ m
        seed = Vector((self.rnd.uniform(0, 100), self.rnd.uniform(0, 100), self.rnd.uniform(0, 100)))
        idx = {}
        bm = self.bm

        def v(i, j, k):
            key = (i, j, k)
            if key not in idx:
                p = Vector(((i / nx - 0.5) * sx, (j / ny - 0.5) * sy, (k / nz - 0.5) * sz))
                if dent > 0:
                    p += noise.noise_vector(p * dent_scale + seed) * dent
                idx[key] = bm.verts.new(m @ p)
            return idx[key]
        faces = []
        for j in range(ny):
            for k in range(nz):
                faces.append(bm.faces.new((v(0, j, k), v(0, j + 1, k), v(0, j + 1, k + 1), v(0, j, k + 1))))
                faces.append(bm.faces.new((v(nx, j, k), v(nx, j, k + 1), v(nx, j + 1, k + 1), v(nx, j + 1, k))))
        for i in range(nx):
            for k in range(nz):
                faces.append(bm.faces.new((v(i, 0, k), v(i, 0, k + 1), v(i + 1, 0, k + 1), v(i + 1, 0, k))))
                faces.append(bm.faces.new((v(i, ny, k), v(i + 1, ny, k), v(i + 1, ny, k + 1), v(i, ny, k + 1))))
        for i in range(nx):
            for j in range(ny):
                faces.append(bm.faces.new((v(i, j, 0), v(i + 1, j, 0), v(i + 1, j + 1, 0), v(i, j + 1, 0))))
                faces.append(bm.faces.new((v(i, j, nz), v(i, j + 1, nz), v(i + 1, j + 1, nz), v(i + 1, j, nz))))
        self._finish_island(list(idx.values()), faces, tint)
        return faces

    def span(self, a, b, width, height, step=0.25, dent=0.004, roll=0.0, tint=None):
        """Balken/Leiste von Punkt a nach Punkt b (Mitte), width quer, height senkrecht."""
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        fwd = d.normalized()
        side = fwd.cross(Vector((0, 0, 1)))
        if side.length < 1e-6:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(fwd).normalized()
        rot = Matrix((side, fwd, up)).transposed().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Rotation(math.radians(roll), 4, "Y")
        return self.box((0, 0, 0), (width, length, height), step=step, dent=dent, tint=tint, matrix=m)

    def slab(self, outline, thickness, matrix, dent=0.003, tint=None):
        """Platte: Umriss (2D, gegen den Uhrzeigersinn) in der xy-Ebene von matrix, Dicke nach +z."""
        bm = self.bm
        seed = Vector((self.rnd.uniform(0, 50), self.rnd.uniform(0, 50), 0))
        low, high = [], []
        for x, y in outline:
            p = Vector((x, y, 0))
            j = noise.noise_vector(p * 4 + seed) * dent
            low.append(bm.verts.new(matrix @ (p + j)))
            high.append(bm.verts.new(matrix @ (p + j + Vector((0, 0, thickness)))))
        faces = [bm.faces.new(list(reversed(low))), bm.faces.new(high)]
        n = len(outline)
        for i in range(n):
            k = (i + 1) % n
            faces.append(bm.faces.new((low[i], low[k], high[k], high[i])))
        self._finish_island(low + high, faces, tint)
        return faces

    def tube(self, points, radius, segs=7, tint=None, wobble=0.0, smooth=0, round_ends=False):
        """Röhre entlang einer Punktfolge, an beiden Enden geschlossen (Stiele, Äste, Eisen).
        smooth = so oft die Bahn runden (Ecken abschneiden, Chaikin), round_ends = Enden als
        kleine Kuppel statt flachem Deckel."""
        pts = [Vector(p) for p in points]
        if len(pts) < 2:
            return []
        for _ in range(smooth):
            out = [pts[0]]
            for a, b2 in zip(pts, pts[1:]):
                out += [a.lerp(b2, 0.25), a.lerp(b2, 0.75)]
            out.append(pts[-1])
            pts = out
        if round_ends and len(pts) >= 2:
            r0 = radius(0.0) if callable(radius) else radius
            r1 = radius(1.0) if callable(radius) else radius
            pts.insert(0, pts[0] - (pts[1] - pts[0]).normalized() * r0 * 0.6)
            pts.append(pts[-1] + (pts[-1] - pts[-2]).normalized() * r1 * 0.6)
            base_radius = radius
            n_pts = len(pts)

            def radius(t, f=base_radius, n=n_pts):
                k = t * (n - 1)
                v = f(min(1.0, max(0.0, (k - 1) / max(1, n - 3)))) if callable(f) else f
                return v * (0.55 if k < 0.5 or k > n - 1.5 else 1.0)
        bm = self.bm
        rings = []
        prev = None
        for i, p in enumerate(pts):
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            ref = prev if prev is not None else (Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0)))
            side = (ref - d * ref.dot(d))
            if side.length < 1e-6:
                side = d.orthogonal()
            side.normalize()
            prev = side
            up = d.cross(side).normalized()
            r = radius(i / (len(pts) - 1)) if callable(radius) else radius
            r *= 1 + self.rnd.uniform(-wobble, wobble)
            rings.append([bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * r)
                          for a in [2 * math.pi * k / segs for k in range(segs)]])
        faces = []
        for i in range(len(rings) - 1):
            for k in range(segs):
                k1 = (k + 1) % segs
                faces.append(bm.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k])))
        faces.append(bm.faces.new(list(reversed(rings[0]))))
        faces.append(bm.faces.new(rings[-1]))
        self._finish_island([v for r in rings for v in r], faces, tint)
        return faces

    def lathe(self, profile, center, segs=16, wave=0.0, waves=0, dent=0.0, tint=None, turn=(0, 0), spin=0.0):
        """Drehkörper um die z-Achse: profile = [(Radius, Höhe), …] von unten nach oben; Radius 0
        am Anfang/Ende schließt den Körper (sonst Deckel). wave/waves = Falten (Rock, Topf)."""
        bm = self.bm
        m = Matrix.Translation(center) @ Matrix.Rotation(math.radians(turn[1]), 4, "Y") @ Matrix.Rotation(math.radians(turn[0]), 4, "X") @ \
            Matrix.Rotation(math.radians(spin), 4, "Z")
        seed = Vector((self.rnd.uniform(0, 50), self.rnd.uniform(0, 50), self.rnd.uniform(0, 50)))
        rings = []
        for r, z in profile:
            if r < 1e-6:
                p = Vector((0, 0, z))
                if dent > 0:
                    p += noise.noise_vector(p * 5 + seed) * dent
                rings.append([bm.verts.new(m @ p)])
                continue
            ring = []
            for k in range(segs):
                a = 2 * math.pi * k / segs
                rr = r * (1 + wave * math.sin(a * waves) * smooth(z / max(profile[-1][1], 1e-3)) if waves else 1)
                p = Vector((math.cos(a) * rr, math.sin(a) * rr, z))
                if dent > 0:
                    p += noise.noise_vector(p * 5 + seed) * dent
                ring.append(bm.verts.new(m @ p))
            rings.append(ring)
        faces = []
        for i in range(len(rings) - 1):
            a, b2 = rings[i], rings[i + 1]
            for k in range(segs):
                k1 = (k + 1) % segs
                if len(a) == 1:
                    faces.append(bm.faces.new((a[0], b2[k1], b2[k])))
                elif len(b2) == 1:
                    faces.append(bm.faces.new((a[k], a[k1], b2[0])))
                else:
                    faces.append(bm.faces.new((a[k], a[k1], b2[k1], b2[k])))
        if len(rings[0]) > 1:
            faces.append(bm.faces.new(list(reversed(rings[0]))))
        if len(rings[-1]) > 1:
            faces.append(bm.faces.new(rings[-1]))
        verts = [v for r in rings for v in r]
        self._finish_island(verts, faces, tint)
        return faces

    def sheet(self, origin, u_vec, v_vec, nu, nv, thickness, offset=None, tint=None):
        """Tuch oder gebogene Platte als Gitter: origin + u·u_vec + v·v_vec (u, v = 0..1);
        offset(u, v) schiebt entlang der Normalen (Falten, Durchhang). Dicke nach hinten."""
        o, U, V = Vector(origin), Vector(u_vec), Vector(v_vec)
        n = U.cross(V).normalized()
        bm = self.bm
        front = [[None] * (nv + 1) for _ in range(nu + 1)]
        back = [[None] * (nv + 1) for _ in range(nu + 1)]
        for i in range(nu + 1):
            for j in range(nv + 1):
                p = o + U * (i / nu) + V * (j / nv) + n * (offset(i / nu, j / nv) if offset else 0.0)
                front[i][j] = bm.verts.new(p)
                back[i][j] = bm.verts.new(p - n * thickness)
        faces = []
        for i in range(nu):
            for j in range(nv):
                faces.append(bm.faces.new((front[i][j], front[i + 1][j], front[i + 1][j + 1], front[i][j + 1])))
                faces.append(bm.faces.new((back[i][j + 1], back[i + 1][j + 1], back[i + 1][j], back[i][j])))
        for i in range(nu):
            for j in (0, nv):
                faces.append(bm.faces.new((front[i][j], back[i][j], back[i + 1][j], front[i + 1][j])))
        for j in range(nv):
            for i in (0, nu):
                faces.append(bm.faces.new((front[i][j], front[i][j + 1], back[i][j + 1], back[i][j])))
        self._finish_island([v for row in front + back for v in row], faces, tint)
        return faces

    def blob(self, center, radius, subdiv=2, lump=0.15, scale=(1, 1, 1), tint=None):
        """Unregelmäßige Knolle (Kern von Büschen, Steine, Erde)."""
        bm = self.bm
        res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
        verts = res["verts"]
        seed = Vector((self.rnd.uniform(0, 50), self.rnd.uniform(0, 50), self.rnd.uniform(0, 50)))
        c = Vector(center)
        for v in verts:
            d = v.co.normalized()
            k = 1 + lump * noise.noise(d * 2.2 + seed)
            v.co = c + Vector((d.x * scale[0], d.y * scale[1], d.z * scale[2])) * radius * k
        faces = list({f for v in verts for f in v.link_faces})
        self._finish_island(verts, faces, tint)
        return faces

    def leaf(self, base, direction, normal, length, width, shape="oval", thick=0.003, curl=0.15, tint=None, segs=None, fan=None):
        """Blatt als kleiner, weich gewölbter Körper (wie ein Kissen): runder Umriss mit vielen
        Randpunkten, Ober- und Unterseite wölben sich über einen inneren Ring zur Mitte auf –
        im Querschnitt rund, nirgends eine scharfe Kante. Formen: ivy (dreilappig), oval, round
        (Geranie, leicht gewellt), narrow (Olive), petal (Blütenblatt), heart. curl biegt das Blatt."""
        f = Vector(direction).normalized()
        n = Vector(normal)
        n = (n - f * n.dot(f))
        n = n.normalized() if n.length > 1e-6 else f.orthogonal().normalized()
        s_ = f.cross(n).normalized()
        outline = _leaf_outline(shape, self.rnd, segs)
        bm = self.bm

        def at(u, w):
            bend = curl * (u * u) * length - abs(w) * curl * 0.3 * width
            return Vector(base) + f * (u * length) + s_ * (w * width * 0.5) + n * bend
        uc = 0.45
        rim = [bm.verts.new(at(u, w)) for u, w in outline]
        top = bm.verts.new(at(uc, 0.0) + n * thick * 0.55)
        bot = bm.verts.new(at(uc, 0.0) - n * thick * 0.42)
        faces = []
        k = len(rim)
        if fan or (fan is None and length < 0.17):
            # kleine Blätter (die allermeisten): Rand direkt zur gewölbten Mitte – weich schattiert genauso
            # rund, aber nur ein Drittel der Dreiecke
            for i in range(k):
                j = (i + 1) % k
                faces.append(bm.faces.new((rim[i], rim[j], top)))
                faces.append(bm.faces.new((rim[j], rim[i], bot)))
            self._finish_island(rim + [top, bot], faces, tint)
            return faces
        # große Blätter: innerer Ring (60 % zur Mitte) oben und unten aufgewölbt
        t_in = [bm.verts.new(at(uc + (u - uc) * 0.6, w * 0.6) + n * thick * 0.42) for u, w in outline]
        b_in = [bm.verts.new(at(uc + (u - uc) * 0.6, w * 0.6) - n * thick * 0.32) for u, w in outline]
        for i in range(k):
            j = (i + 1) % k
            faces.append(bm.faces.new((rim[i], rim[j], t_in[j], t_in[i])))
            faces.append(bm.faces.new((t_in[i], t_in[j], top)))
            faces.append(bm.faces.new((rim[j], rim[i], b_in[i], b_in[j])))
            faces.append(bm.faces.new((b_in[j], b_in[i], bot)))
        self._finish_island(rim + t_in + b_in + [top, bot], faces, tint)
        return faces

    def panel(self, matrix, width, height, thick, outline=None, tint=None):
        """Schild-Platte für ein Bild: Vorderseite (lokal +z) zeigt das ganze Bild (u über die
        Breite, v über die Höhe), Rand und Rückseite den Randpixel. outline = eigener Umriss
        (Punkte in -0.5..0.5, z. B. rund oder mit Bogen), sonst Rechteck. Ein geschlossener
        Körper, Ursprung in der Mitte der Rückseite."""
        if self.uv is None:
            self.uv = self.bm.loops.layers.uv.new("UVMap")
        pts = outline or [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)]
        bm = self.bm
        back = [bm.verts.new(matrix @ Vector((u * width, v * height, 0.0))) for u, v in pts]
        front = [bm.verts.new(matrix @ Vector((u * width, v * height, thick))) for u, v in pts]
        faces = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((back[i], back[j], front[j], front[i])))
        uv_of = {v: (u + 0.5, w + 0.5) for v, (u, w) in zip(front, pts)}
        for f in faces:
            for loop in f.loops:
                loop[self.uv].uv = uv_of.get(loop.vert, (0.01, 0.5))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        self._paint(back + front, tint)
        return faces

    def star(self, center, normal, size, points, rnd, thick=0.004, cup=0.25, tint=None, samples=None, notch=0.42):
        """Ganze Blüte als ein weicher Körper: runde Blütenblätter (Umriss mit sanften, runden
        Bögen statt Spitzen), leicht schalenförmig, in der Mitte zu einem runden Polster gewölbt –
        wie gemalt, nicht sternförmig."""
        nrm = Vector(normal).normalized()
        ref = Vector((0, 0, 1)) if abs(nrm.z) < 0.9 else Vector((1, 0, 0))
        s1 = nrm.cross(ref).normalized()
        s2 = nrm.cross(s1).normalized()
        spin = rnd.uniform(0, 2 * math.pi)
        c = Vector(center)
        m = points * (samples or (6 if size >= 0.016 else 4))
        th = max(thick, size * 0.16)
        bm = self.bm
        rings = []
        small = size < 0.05   # kleine Blüten: Rand direkt zur gewölbten Mitte (weniger Dreiecke)
        for frac, lift_t, lift_b in ((1.0, 0.0, 0.0),) + (() if small else ((0.55, 0.55, -0.35),)):
            top_ring, bot_ring = [], []
            for k in range(m):
                a = spin + 2 * math.pi * k / m
                # runde Blütenblätter mit kleiner Kerbe dazwischen (wie gemalte Blüten)
                lobe = abs(math.cos(points * (a - spin) / 2))
                r = size * frac * (1.0 - notch + notch * lobe ** 0.55)
                d = s1 * math.cos(a) + s2 * math.sin(a)
                p = c + d * r + nrm * cup * r
                if frac == 1.0:
                    v = bm.verts.new(p)
                    top_ring.append(v)
                    bot_ring.append(v)
                else:
                    top_ring.append(bm.verts.new(p + nrm * th * lift_t))
                    bot_ring.append(bm.verts.new(p + nrm * th * lift_b))
            rings.append((top_ring, bot_ring))
        rim = rings[0][0]
        top = bm.verts.new(c + nrm * th * 0.9)
        bot = bm.verts.new(c - nrm * th * 0.5)
        faces = []
        if small:
            for i in range(m):
                j = (i + 1) % m
                faces.append(bm.faces.new((rim[i], rim[j], top)))
                faces.append(bm.faces.new((rim[j], rim[i], bot)))
            self._finish_island(rim + [top, bot], faces, tint)
            return faces
        t_in, b_in = rings[1]
        for i in range(m):
            j = (i + 1) % m
            faces.append(bm.faces.new((rim[i], rim[j], t_in[j], t_in[i])))
            faces.append(bm.faces.new((t_in[i], t_in[j], top)))
            faces.append(bm.faces.new((rim[j], rim[i], b_in[i], b_in[j])))
            faces.append(bm.faces.new((b_in[j], b_in[i], bot)))
        self._finish_island(rim + t_in + b_in + [top, bot], faces, tint)
        return faces

    def text(self, string, size, depth, matrix, font="DejaVuSerif-Bold.ttf", jitter=0.0, tint=None, spacing=1.0,
             resolution=None):
        """Schrift als Körper (jeder Buchstabe einzeln, leicht gehüpft/gekippt: handgemalt).
        Mittig um den Ursprung von matrix, Grundlinie bei y = 0, Vorderseite +z. resolution =
        Zwischenpunkte je Kurvenstück (leer = Blenders 12; kleine Schrift reicht 4)."""
        glyphs = []
        x = 0.0
        for ch in string:
            if ch == " ":
                x += size * 0.33
                continue
            curve = bpy.data.curves.new("t", "FONT")
            curve.body = ch
            curve.size = size
            curve.extrude = depth / 2
            if resolution:
                curve.resolution_u = resolution
            curve.font = bpy.data.fonts.load(os.path.join(FONT_DIR, font), check_existing=True)
            obj = bpy.data.objects.new("t", curve)
            bpy.context.scene.collection.objects.link(obj)
            dg = bpy.context.evaluated_depsgraph_get()
            me = obj.evaluated_get(dg).to_mesh()
            xs = [v.co.x for v in me.vertices] or [0, size * 0.5]
            w = max(xs) - min(xs)
            glyphs.append((x - min(xs), [v.co.copy() for v in me.vertices], [list(p.vertices) for p in me.polygons]))
            x += w + size * 0.06 * spacing
            obj.evaluated_get(dg).to_mesh_clear()
            bpy.data.objects.remove(obj)
            bpy.data.curves.remove(curve)
        total = x - size * 0.06 * spacing
        for gx, cos, polys in glyphs:
            dy = self.rnd.uniform(-jitter, jitter) * size
            ang = math.radians(self.rnd.uniform(-jitter, jitter) * 40)
            gm = matrix @ Matrix.Translation((gx - total / 2, dy, depth / 2)) @ Matrix.Rotation(ang, 4, "Z")
            vs = [self.bm.verts.new(gm @ c) for c in cos]
            faces = []
            for p in polys:
                try:
                    faces.append(self.bm.faces.new([vs[i] for i in p]))
                except ValueError:
                    pass
            bmesh.ops.remove_doubles(self.bm, verts=vs, dist=1e-5)
            vs = [v for v in vs if v.is_valid]
            self._finish_island(vs, [f for f in faces if f.is_valid], tint)
        return total

    def build(self, smooth_angle=50):
        """Blender-Objekt erzeugen (mit Bevel für weiche Kanten, falls gewünscht)."""
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.use_auto_smooth = True
        me.auto_smooth_angle = math.radians(smooth_angle)
        obj = bpy.data.objects.new(self.name, me)
        self.coll.objects.link(obj)
        if self.mat is not None:
            me.materials.append(self.mat)
        if self.bevel > 0:
            # Weiche, runde Kanten (keine scharfen Ecken): etwas breiter als angegeben, dreifach
            # gerundet bei größeren Teilen
            mod = obj.modifiers.new("Weiche Kanten", "BEVEL")
            mod.width = self.bevel * BEVEL_SCALE
            mod.segments = BEVEL_SEGMENTS[0] if self.bevel >= 0.01 else BEVEL_SEGMENTS[1]
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(40)
            mod.harden_normals = False
        return obj


def _leaf_outline(shape, rnd, segs=None):
    """Umriss eines Blatts als (u, w): u = 0 (Stiel) .. 1 (Spitze), w = -1..1 quer."""
    pts = []
    if shape == "heart":
        # Herzblatt (Bilderbuch-Efeu, Ranken): rundliche Lappen am Stiel, weiche Spitze
        out = []
        n = segs or 12
        for k in range(n):
            t = 2 * math.pi * k / n
            x = math.sin(t) ** 3 * 0.55 + math.sin(t) * 0.45   # fülliger, runde Lappen
            y = (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 17.0
            out.append(((0.72 - y) / 1.72, x * rnd.uniform(0.97, 1.03)))
        return out
    if shape == "ivy":
        # Efeublatt: drei bis fünf Lappen, jedes etwas anders
        side = []
        lobes = [(0.05, 0.25), (0.28, 0.95 + rnd.uniform(-0.1, 0.1)), (0.45, 0.55), (0.62, 0.7 + rnd.uniform(-0.1, 0.1)), (0.82, 0.3)]
        for u, w in lobes:
            side.append((u, w * rnd.uniform(0.9, 1.1)))
        pts = [(0.0, 0.0)] + [(u, -w) for u, w in side] + [(1.0, 0.0)] + [(u, w) for u, w in reversed(side)]
        return pts
    n = segs or {"oval": 8, "round": 9, "narrow": 6, "petal": 6}.get(shape, 8)
    right = []
    for i in range(1, n):
        # Punkte an Stiel und Spitze dichter (runde Enden), Breite mit Hochzahl < 1: prall, nie spitz
        u = 0.5 - 0.5 * math.cos(math.pi * i / n)
        if shape == "round":
            w = math.sin(math.pi * (0.12 + 0.88 * u)) ** 0.75 * (1 + 0.035 * math.sin(u * 2 * math.pi * 3))  # sanft gewellter Rand
        elif shape == "narrow":
            w = math.sin(math.pi * u) ** 0.7 * 0.6
        elif shape == "petal":
            w = math.sin(math.pi * u ** 0.7) ** 0.7 * 0.9
        elif shape == "cup":
            # Tulpenblatt: oben am breitesten, runde Spitze
            w = math.sin(math.pi * u ** 1.35) ** 0.6 * 0.95
        elif shape == "blade":
            # Grashalm: am Fuß breit, läuft lang und spitz aus
            w = (1.0 - u ** 1.6) ** 0.8 * min(1.0, 0.35 + u * 4.0)
        else:
            w = math.sin(math.pi * u ** 0.9) ** 0.7
        right.append((u, w * rnd.uniform(0.97, 1.03)))
    return [(0.0, 0.0)] + [(u, -w) for u, w in right] + [(1.0, 0.0)] + [(u, w) for u, w in reversed(right)]


def boolean_cut(obj, cutters):
    """Öffnungen (Fenster, Türen) aus einem Körper schneiden – das Ergebnis bleibt geschlossen."""
    coll = bpy.data.collections.new("_cutters")
    bpy.context.scene.collection.children.link(coll)
    for c in cutters:
        coll.objects.link(c)
    mod = obj.modifiers.new("Öffnungen", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.operand_type = "COLLECTION"
    mod.collection = coll
    mod.solver = "EXACT"
    bpy.context.view_layer.objects.active = obj
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for c in cutters:
        me = c.data
        bpy.data.objects.remove(c)
        bpy.data.meshes.remove(me)
    bpy.data.collections.remove(coll)


def round_outline(n=40, arch=None):
    """Umriss für Body.panel: Kreis (arch=None) oder Rechteck mit Bogen oben (arch = Höhe des
    Bogens als Anteil der Höhe, z. B. 0.18)."""
    if arch is None:
        return [(0.5 * math.cos(2 * math.pi * k / n), 0.5 * math.sin(2 * math.pi * k / n)) for k in range(n)]
    top = 0.5 - arch
    pts = [(-0.5, -0.5), (0.5, -0.5), (0.5, top)]
    for k in range(1, n):
        t = k / n
        pts.append((0.5 * math.cos(math.pi * t), top + arch * math.sin(math.pi * t)))
    pts.append((-0.5, top))
    return pts


def cutter(center, size, turn=(0, 0, 0), matrix=None):
    """Schneide-Kasten (wird nach dem Schneiden gelöscht); matrix = dieselbe Ebene wie das
    Fenster, dann sitzt die Öffnung genau so schief wie der Rahmen."""
    b = Body("_cut", None, bpy.context.scene.collection, vary=0)
    b.box(center, size, step=10, turn=turn, dent=0, matrix=matrix)
    me = bpy.data.meshes.new("_cut")
    b.bm.to_mesh(me)
    b.bm.free()
    obj = bpy.data.objects.new("_cut", me)
    return obj


def slab_cutter(outline, matrix, z0=-0.5, depth=1.0):
    """Schneide-Körper mit beliebigem Umriss (2D, gegen den Uhrzeigersinn, in der xy-Ebene von
    matrix), von z0 bis z0 + depth – z. B. Fenster mit Bogen oben."""
    b = Body("_cut", None, bpy.context.scene.collection, vary=0)
    b.slab(outline, depth, matrix @ Matrix.Translation((0, 0, z0)), dent=0.0)
    me = bpy.data.meshes.new("_cut")
    b.bm.to_mesh(me)
    b.bm.free()
    return bpy.data.objects.new("_cut", me)


def arc_points(hx, hs, rise, inset=0.0, n=16):
    """Flacher Bogen über einer Öffnung der halben Breite hx (Seiten bis Höhe hs, Scheitel
    hs + rise), um inset nach innen versetzt; Punkte von rechts nach links."""
    big_r = (hx * hx + rise * rise) / (2 * rise)
    cy = hs + rise - big_r
    r = big_r - inset
    phi0 = math.asin((hx - inset) / r)
    return [(r * math.sin(phi0 - 2 * phi0 * k / n), cy + r * math.cos(phi0 - 2 * phi0 * k / n)) for k in range(n + 1)]


def non_manifold(obj):
    """Anzahl offener/kaputter Kanten (0 = geschlossener Körper)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = sum(1 for e in bm.edges if not e.is_manifold)
    bm.free()
    return bad
