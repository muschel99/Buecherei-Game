"""Bauteil-Bibliothek für die Stil-Modelle (seit Etappe 4g).

Wird von den Bau-Scripts in tools/blender/ benutzt (z. B. build_houses.py). Alles wird in
Godot-Koordinaten gebaut: x nach rechts, y nach oben, z nach vorn (zur Straße), 1 Einheit = 1 m.
Ursprung wie in den Vorlagen (assets/models/templates/): unten in der Mitte der Vorderseite.

Jede Fläche bekommt:
  - eine Ebene der Stil-Texturen (assets/textures/style/layers.json: brick, stone, slate …),
  - eine Rolle: "fixed" (feste Farbe), "wall", "door", "accent" (Farbe kommt vom Haus in Godot),
  - eine Farbe (nur bei "fixed": färbt einfärbbare Ebenen, z. B. rote Ziegel; sRGB 0..1),
  - Texturkoordinaten in Metern (geteilt durch die Kachelgröße der Ebene), automatisch.

Ergebnis:
  - eine .glb-Datei für Godot (eigener kleiner Exporter, siehe write_glb – Blenders glTF-Export
    braucht numpy, das im Container fehlt). Zwei Materialien: "house" (alles Feste, ein
    Zeichenaufruf) und "glass" (durchsichtige Schaufenster).
    UV2 = (Ebene, Rolle), Vertex-Farbe = feste Farbe (linear).
  - eine .blend-Datei zum Anschauen und Weiterbearbeiten (mit Vorschau-Materialien, die wie im
    Spiel aussehen).
"""

import bpy
import bmesh
import json
import math
import os
import struct
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX_DIR = os.path.join(ROOT, "assets", "textures", "style")
with open(os.path.join(TEX_DIR, "layers.json")) as _file:
    _TABLE = json.load(_file)
GRID_X = _TABLE["grid_x"]
GRID_Y = _TABLE["grid_y"]
LAYERS = {entry["name"]: entry for entry in _TABLE["layers"]}
ROLES = {"fixed": 0, "wall": 1, "door": 2, "accent": 3}
SERIF_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
# Für verspielte Schrift (Buchstaben hüpfen zusätzlich, siehe Builder.playful_text)
PLAYFUL_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-BoldItalic.ttf"
# Stärke des Leuchtens (wie glow_strength im Shader)
GLOW_STRENGTH = 1.5
# Prüfmodus: Rückseiten leuchten pink. Godot zeichnet nur Vorderseiten – jede pinke Stelle
# im Kontrollbild wäre im Spiel ein Loch (man sieht hindurch).
SHOW_BACKFACES = False


def srgb_to_linear(c):
    out = []
    for value in c[:3]:
        out.append(value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# Wie im Shader (assets/shaders/house_style.gdshader): Einfärben = Textur x Farbe x TINT_GAIN.
# Die einfärbbaren Stellen der Texturen haben im Mittel die Helligkeit tint_mean – so ergibt
# sich im Mittel genau die gewählte Farbe.
TINT_GAIN = 1.0 / srgb_to_linear((_TABLE["tint_mean"],) * 3)[0]


def V(x, y, z):
    return Vector((x, y, z))


class Mat:
    """Aussehen einer Fläche: Ebene, Rolle und (bei "fixed") Farbe in sRGB.
    glow = leichtes Leuchten 0..1 (z. B. beleuchtetes Schaufenster), steht im Alpha der
    Vertex-Farbe (1 - glow)."""

    def __init__(self, layer, role="fixed", color=(1.0, 1.0, 1.0), glass=False, glow=0.0):
        assert layer in LAYERS, layer
        self.layer = layer
        self.role = role
        self.color = tuple(color)
        self.glass = glass
        self.glow = glow

    def key(self):
        if self.glass:
            return "glass"
        glow = "_g%02d" % round(self.glow * 99) if self.glow > 0 else ""
        if self.role != "fixed":
            return "%s_%s%s" % (self.layer, self.role, glow)
        return "%s_%02x%02x%02x%s" % ((self.layer,) + tuple(int(round(c * 255)) for c in self.color) + (glow,))


class Builder:
    """Sammelt Flächen in Godot-Koordinaten (siehe oben)."""

    def __init__(self, name):
        self.name = name
        self.faces = []
        # Feste Kästen für Dinge, an denen man nicht vorbeilaufen soll (z. B. Blumenkübel vor
        # dem Haus): landen als eigener Knoten "…-colonly" in der .glb – Godot macht daraus
        # eine unsichtbare Kollision
        self.colliders = []
        self.xf = Matrix.Identity(4)
        self._stack = []

    # --- Verschieben und Drehen (wirkt auf alles, was danach gebaut wird) ---

    def push(self, matrix):
        self._stack.append(self.xf.copy())
        self.xf = self.xf @ matrix

    def pop(self):
        self.xf = self._stack.pop()

    @staticmethod
    def move(x, y, z):
        return Matrix.Translation((x, y, z))

    @staticmethod
    def turn_y(degrees):
        return Matrix.Rotation(math.radians(degrees), 4, "Y")

    # --- Grundflächen ---

    def poly(self, pts, mat, normals=None, both=False):
        """Ein ebenes, konvexes Vieleck (Punkte gegen den Uhrzeigersinn von außen gesehen).
        both = auch die Rückseite (knapp dahinter), für dünne Dinge wie Tuch oder Blätter."""
        if both:
            a, b2, c = (Vector(p) for p in pts[:3])
            n = (b2 - a).cross(c - a)
            if n.length > 1e-12:
                off = n.normalized() * -0.0008
                self.poly([Vector(p) + off for p in reversed(pts)], mat)
        pts = [self.xf @ Vector(p) for p in pts]
        n = (pts[1] - pts[0]).cross(pts[2] - pts[0])
        if n.length < 1e-9:
            # Erste drei Punkte liegen auf einer Linie: Newell-Verfahren
            n = Vector((0, 0, 0))
            for i, a in enumerate(pts):
                b = pts[(i + 1) % len(pts)]
                n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
            if n.length < 1e-12:
                return
        n.normalize()
        if normals is not None:
            rot = self.xf.to_3x3()
            normals = [(rot @ Vector(m)).normalized() for m in normals]
        else:
            normals = [n] * len(pts)
        self.faces.append({"pts": pts, "normals": normals, "n": n, "mat": mat})

    def quad(self, a, b, c, d, mat):
        self.poly([a, b, c, d], mat)

    def box(self, lo, hi, mat, skip=()):
        """Quader von lo bis hi. skip: Seiten weglassen ("left", "right", "bottom", "top",
        "back", "front")."""
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        if "front" not in skip:
            self.poly([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], mat)
        if "back" not in skip:
            self.poly([(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], mat)
        if "left" not in skip:
            self.poly([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], mat)
        if "right" not in skip:
            self.poly([(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)], mat)
        if "top" not in skip:
            self.poly([(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)], mat)
        if "bottom" not in skip:
            self.poly([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], mat)

    def beam(self, a, b, width, height, mat, skip_ends=False):
        """Balken von Punkt a nach Punkt b (Mittellinie der Unterseite), width quer (waagerecht),
        height nach oben senkrecht zum Balken – für Abdeckungen, Ortgänge, Fachwerk."""
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        side = d.cross(Vector((0, 1, 0)))
        if side.length < 1e-6:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(d).normalized()
        hw = side * (width / 2)
        hu = up * height
        c = [a - hw, a + hw, b + hw, b - hw]
        t = [p + hu for p in c]
        self.poly([t[0], t[1], t[2], t[3]], mat)
        self.poly([c[3], c[2], c[1], c[0]], mat)
        self.poly([c[1], c[2], t[2], t[1]], mat)
        self.poly([c[3], c[0], t[0], t[3]], mat)
        if not skip_ends:
            self.poly([c[0], c[1], t[1], t[0]], mat)
            self.poly([c[2], c[3], t[3], t[2]], mat)

    def slab(self, pts, thickness, mat, side_mat=None):
        """Platte: Vieleck (Oberseite, gegen den Uhrzeigersinn von oben/außen) mit Dicke nach
        innen – rundum geschlossen (Dachflächen von Gauben, Schilder, Bretter)."""
        pts = [Vector(p) for p in pts]
        n = Vector((0, 0, 0))
        for i, a in enumerate(pts):
            b2 = pts[(i + 1) % len(pts)]
            n += Vector(((a.y - b2.y) * (a.z + b2.z), (a.z - b2.z) * (a.x + b2.x), (a.x - b2.x) * (a.y + b2.y)))
        n.normalize()
        low = [p - n * thickness for p in pts]
        for tri in triangulate(pts):
            self.poly(tri, mat)
        for tri in triangulate(list(reversed(low))):
            self.poly(tri, mat)
        sm = side_mat or mat
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            self.poly([low[i], low[j], pts[j], pts[i]], sm)

    def room(self, lo, hi, mats, skip=()):
        """Raum (Quader von innen gesehen): mats = {"floor", "ceiling", "back", "front", "left",
        "right"} – fehlende Einträge und skip werden weggelassen."""
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        faces = {
            "floor": [(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)],
            "ceiling": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
            "back": [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
            "front": [(x1, y0, z1), (x0, y0, z1), (x0, y1, z1), (x1, y1, z1)],
            "left": [(x0, y0, z1), (x0, y0, z0), (x0, y1, z0), (x0, y1, z1)],
            "right": [(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)],
        }
        for key, pts in faces.items():
            if key in mats and key not in skip:
                self.poly(pts, mats[key])

    def tube(self, points, radius, mat, segments=6, caps=True):
        """Röhre entlang einer Linie aus Punkten (Schmiedeeisen, Faden, Ranken, Kabel)."""
        pts = [Vector(p) for p in points]
        if len(pts) < 2:
            return
        rings = []
        prev_side = None
        for i, p in enumerate(pts):
            if i == 0:
                d = pts[1] - pts[0]
            elif i == len(pts) - 1:
                d = pts[-1] - pts[-2]
            else:
                d = pts[i + 1] - pts[i - 1]
            d.normalize()
            ref = prev_side if prev_side is not None else (Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0)))
            side = (ref - d * ref.dot(d))
            if side.length < 1e-6:
                side = d.orthogonal()
            side.normalize()
            prev_side = side
            up = d.cross(side).normalized()
            r = radius(i / (len(pts) - 1)) if callable(radius) else radius
            ring = []
            for k in range(segments):
                a = 2 * math.pi * k / segments
                nrm = side * math.cos(a) + up * math.sin(a)
                ring.append((p + nrm * r, nrm))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for k in range(segments):
                k1 = (k + 1) % segments
                a, b2, c, d2 = rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]
                self.poly([a[0], b2[0], c[0], d2[0]], mat, normals=[a[1], b2[1], c[1], d2[1]])
        if caps:
            self.poly([v[0] for v in rings[-1]], mat)
            self.poly([v[0] for v in rings[0]][::-1], mat)

    def playful_text(self, string, x, y, z, size, depth, mat, font_path=None, seed=1, bounce=0.08,
                     tilt=6.0, spacing=0.0, first_scale=1.0):
        """Verspielte Schrift: jeder Buchstabe leicht gehüpft und gekippt, große Anfangsbuchstaben
        (first_scale). Mittig um x, Grundlinie bei y, Vorderseite +z. Liefert die Breite."""
        import random
        rnd = random.Random(seed)
        font_path = font_path or SERIF_FONT
        glyphs = []
        for k, ch in enumerate(string):
            word_start = k == 0 or string[k - 1] == " "
            scale = first_scale if (word_start and ch.isupper()) else 1.0
            glyphs.append((ch, size * scale))
        # Breite je Buchstabe aus Blender messen
        widths = [self._glyph_width(ch, sz, font_path) for ch, sz in glyphs]
        total = sum(widths) + spacing * size * (len(glyphs) - 1)
        cx = x - total / 2
        for (ch, sz), w in zip(glyphs, widths):
            if ch != " ":
                dy = rnd.uniform(-bounce, bounce) * size
                angle = rnd.uniform(-tilt, tilt)
                self.push(Matrix.Translation((cx + w / 2, y + dy, z)) @ Matrix.Rotation(math.radians(angle), 4, "Z"))
                self.text(ch, 0.0, 0.0, 0.0, sz, depth, mat, font_path=font_path, align="CENTER")
                self.pop()
            cx += w + spacing * size
        return total

    _width_cache = {}

    def _glyph_width(self, ch, size, font_path):
        key = (ch, round(size, 4), font_path)
        if key in Builder._width_cache:
            return Builder._width_cache[key]
        if ch == " ":
            w = size * 0.32
        else:
            curve = bpy.data.curves.new("w", "FONT")
            curve.body = ch
            curve.size = size
            if font_path and os.path.exists(font_path):
                curve.font = bpy.data.fonts.load(font_path, check_existing=True)
            obj = bpy.data.objects.new("w", curve)
            bpy.context.scene.collection.objects.link(obj)
            bpy.context.view_layer.update()
            xs = [v[0] for v in obj.bound_box]
            w = max(xs) - min(xs) + size * 0.04
            bpy.data.objects.remove(obj)
            bpy.data.curves.remove(curve)
        Builder._width_cache[key] = w
        return w

    def extrude_x(self, profile, x0, x1, mat, caps=True):
        """Profil (Liste von (z, y), gegen den Uhrzeigersinn, wenn man von +x schaut) von x0 bis x1
        ziehen – für Gesimse, Bänder, Fensterbänke."""
        n = len(profile)
        for i in range(n):
            z_a, y_a = profile[i]
            z_b, y_b = profile[(i + 1) % n]
            self.poly([(x0, y_a, z_a), (x0, y_b, z_b), (x1, y_b, z_b), (x1, y_a, z_a)], mat)
        if caps:
            self._cap([(x1, y, z) for z, y in profile], mat)
            self._cap([(x0, y, z) for z, y in reversed(profile)], mat)

    def _cap(self, pts, mat):
        # Profile können konkav sein: als Dreiecksfächer um den Schwerpunkt nur, wenn konvex –
        # sonst in Dreiecke zerlegen (Ohrenschneiden)
        for tri in triangulate(pts):
            self.poly(tri, mat)

    def prism(self, outline, y0, y1, mat, caps=(True, True)):
        """Grundriss (Liste von (x, z), gegen den Uhrzeigersinn von oben) von y0 bis y1 hochziehen."""
        n = len(outline)
        for i in range(n):
            x_a, z_a = outline[i]
            x_b, z_b = outline[(i + 1) % n]
            self.poly([(x_a, y0, z_a), (x_b, y0, z_b), (x_b, y1, z_b), (x_a, y1, z_a)], mat)
        if caps[1]:
            self._cap([(x, y1, z) for x, z in outline], mat)
        if caps[0]:
            self._cap([(x, y0, z) for x, z in reversed(outline)], mat)

    def cylinder(self, base, radius, height, mat, segments=12, caps=(False, True), radius_top=None, axis="y"):
        """Zylinder oder Kegelstumpf (weich schattiert). axis: "y" (stehend), "x" oder "z" (liegend)."""
        r1 = radius_top if radius_top is not None else radius
        rot = {"y": Matrix.Identity(4), "x": Matrix.Rotation(math.radians(-90), 4, "Z"),
               "z": Matrix.Rotation(math.radians(90), 4, "X")}[axis]
        self.push(Matrix.Translation(base) @ rot)
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append((math.cos(a), math.sin(a)))
        slope = (radius - r1) / height
        for i in range(segments):
            ca, sa = ring[i]
            cb, sb = ring[(i + 1) % segments]
            na = Vector((ca, slope, -sa)).normalized()
            nb = Vector((cb, slope, -sb)).normalized()
            self.poly([(ca * radius, 0, -sa * radius), (cb * radius, 0, -sb * radius),
                       (cb * r1, height, -sb * r1), (ca * r1, height, -sa * r1)], mat,
                      normals=[na, nb, nb, na])
        if caps[1] and r1 > 0:
            self.poly([(c * r1, height, -s * r1) for c, s in ring], mat)
        if caps[0]:
            self.poly([(c * radius, 0, -s * radius) for c, s in reversed(ring)], mat)
        self.pop()

    def sphere(self, center, radius, mat, rings=6, segments=10, squash=1.0, jitter=0.0, seed=0):
        """Kugel (weich schattiert); jitter beult sie etwas aus (z. B. Buchsbaumkugel)."""
        import random
        rnd = random.Random(seed)
        grid = []
        for r in range(rings + 1):
            phi = math.pi * r / rings
            row = []
            for s in range(segments):
                theta = 2 * math.pi * s / segments
                d = Vector((math.sin(phi) * math.cos(theta), math.cos(phi) * squash, math.sin(phi) * math.sin(theta)))
                k = 1.0 + (rnd.uniform(-jitter, jitter) if 0 < r < rings else 0.0)
                row.append((d * radius * k, d.normalized()))
            grid.append(row)
        c = Vector(center)
        for r in range(rings):
            for s in range(segments):
                s1 = (s + 1) % segments
                a, b, cc, d = grid[r][s], grid[r][s1], grid[r + 1][s1], grid[r + 1][s]
                if r == 0:
                    self.poly([c + a[0], c + cc[0], c + d[0]], mat, normals=[a[1], cc[1], d[1]])
                elif r == rings - 1:
                    self.poly([c + a[0], c + b[0], c + d[0]], mat, normals=[a[1], b[1], d[1]])
                else:
                    self.poly([c + a[0], c + b[0], c + cc[0], c + d[0]], mat, normals=[a[1], b[1], cc[1], d[1]])

    # --- Bauteile ---

    def wall_with_holes(self, x0, x1, y0, y1, z, holes, mat, reveal=0.0, reveal_mat=None):
        """Senkrechte Wand in der Ebene z (Vorderseite +z) mit rechteckigen Öffnungen
        holes = [(hx0, hy0, hx1, hy1), …]. reveal = Tiefe der Laibung (Seitenflächen der Öffnung)."""
        xs = sorted({x0, x1} | {h[0] for h in holes} | {h[2] for h in holes})
        ys = sorted({y0, y1} | {h[1] for h in holes} | {h[3] for h in holes})
        for i in range(len(xs) - 1):
            for j in range(len(ys) - 1):
                cx = (xs[i] + xs[i + 1]) / 2
                cy = (ys[j] + ys[j + 1]) / 2
                if any(h[0] < cx < h[2] and h[1] < cy < h[3] for h in holes):
                    continue
                self.poly([(xs[i], ys[j], z), (xs[i + 1], ys[j], z), (xs[i + 1], ys[j + 1], z), (xs[i], ys[j + 1], z)], mat)
        if reveal > 0:
            rm = reveal_mat or mat
            zb = z - reveal
            for hx0, hy0, hx1, hy1 in holes:
                # Seiten der Öffnung zeigen in die Öffnung hinein
                self.poly([(hx0, hy1, zb), (hx0, hy1, z), (hx0, hy0, z), (hx0, hy0, zb)], rm)
                self.poly([(hx1, hy1, z), (hx1, hy1, zb), (hx1, hy0, zb), (hx1, hy0, z)], rm)
                self.poly([(hx0, hy1, zb), (hx1, hy1, zb), (hx1, hy1, z), (hx0, hy1, z)], rm)
                self.poly([(hx0, hy0, z), (hx1, hy0, z), (hx1, hy0, zb), (hx0, hy0, zb)], rm)

    def frame(self, x0, y0, x1, y1, z0, z1, width, mat, bottom=True):
        """Rahmen um eine rechteckige Öffnung (innen x0..x1, y0..y1), Tiefe z0..z1."""
        self.box((x0 - width, y0 - (width if bottom else 0), z0), (x0, y1 + width, z1), mat, skip=("back",))
        self.box((x1, y0 - (width if bottom else 0), z0), (x1 + width, y1 + width, z1), mat, skip=("back",))
        self.box((x0, y1, z0), (x1, y1 + width, z1), mat, skip=("back", "left", "right"))
        if bottom:
            self.box((x0, y0 - width, z0), (x1, y0, z1), mat, skip=("back", "left", "right"))

    def glazing_bars(self, x0, y0, x1, y1, z0, z1, cols, rows, bar, mat):
        """Sprossen in einer Glasfläche: cols x rows Scheiben."""
        for c in range(1, cols):
            x = x0 + (x1 - x0) * c / cols
            self.box((x - bar / 2, y0, z0), (x + bar / 2, y1, z1), mat, skip=("back", "top", "bottom"))
        for r in range(1, rows):
            y = y0 + (y1 - y0) * r / rows
            self.box((x0, y - bar / 2, z0), (x1, y + bar / 2, z1), mat, skip=("back", "left", "right"))

    def text(self, string, x, y, z, size, depth, mat, font_path=SERIF_FONT, align="CENTER", spacing=1.0):
        """Schrift als 3D-Buchstaben (Vorderseite +z), Grundlinie bei y, mittig um x."""
        curve = bpy.data.curves.new("txt", "FONT")
        curve.body = string
        curve.size = size
        curve.extrude = depth / 2
        curve.align_x = align
        curve.space_character = spacing
        if font_path and os.path.exists(font_path):
            curve.font = bpy.data.fonts.load(font_path, check_existing=True)
        obj = bpy.data.objects.new("txt", curve)
        bpy.context.scene.collection.objects.link(obj)
        depsgraph = bpy.context.evaluated_depsgraph_get()
        mesh = obj.evaluated_get(depsgraph).to_mesh()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        # Blender-Text: x nach rechts, y nach oben, z nach vorn (Dicke um 0 herum)
        for f in bm.faces:
            pts = [(x + v.co.x, y + v.co.y, z + depth / 2 + v.co.z) for v in f.verts]
            self.poly(pts, mat)
        bm.free()
        obj.evaluated_get(depsgraph).to_mesh_clear()
        bpy.data.objects.remove(obj)
        bpy.data.curves.remove(curve)

    # --- Ausgabe ---

    def triangles(self):
        """Alle Flächen als Dreiecke mit Daten je Ecke (für den Exporter)."""
        out = {"house": [], "glass": []}
        for face in self.faces:
            mat = face["mat"]
            info = LAYERS[mat.layer]
            tile = info["tile_size"]
            uv_of = [_planar_uv(p, face["n"], tile) for p in face["pts"]]
            color = srgb_to_linear(mat.color) if mat.role == "fixed" else (1.0, 1.0, 1.0)
            target = out["glass" if mat.glass else "house"]
            pts = face["pts"]
            for i in range(1, len(pts) - 1):
                for k in (0, i, i + 1):
                    target.append((pts[k], face["normals"][k], uv_of[k], (float(info["index"]), float(ROLES[mat.role])),
                                   color + (1.0 - mat.glow,)))
        return out


def bake_role(builder, role, color):
    """Kopie der Flächen, bei der die Rolle (z. B. "accent") durch eine feste Farbe ersetzt ist
    – für Vorschaubilder einzelner Requisiten mit ihrer Farbe aus Godot."""
    out = Builder(builder.name)
    for face in builder.faces:
        mat = face["mat"]
        if mat.role == role:
            mat = Mat(mat.layer, color=color, glow=mat.glow)
        out.faces.append(dict(face, mat=mat))
    return out


def _planar_uv(p, n, tile):
    """Texturkoordinaten in Metern: u waagerecht entlang der Fläche, v nach oben bzw. hangaufwärts."""
    if abs(n.y) > 0.98:
        u_axis = Vector((1, 0, 0))
        v_axis = Vector((0, 0, -1)) if n.y > 0 else Vector((0, 0, 1))
    else:
        u_axis = Vector((0, 1, 0)).cross(n).normalized()
        v_axis = n.cross(u_axis).normalized()
    return (p.dot(u_axis) / tile, p.dot(v_axis) / tile)


def triangulate(pts):
    """Vieleck (ebene Punkte, auch konkav) in Dreiecke zerlegen (Ohrenschneiden)."""
    pts = [Vector(p) for p in pts]
    if len(pts) == 3:
        return [pts]
    n = Vector((0, 0, 0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    if n.length < 1e-12:
        return []
    n.normalize()
    idx = list(range(len(pts)))
    tris = []
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if (b - a).cross(c - b).dot(n) <= 1e-12:
                continue
            inside = False
            for j in idx:
                if j in (i0, i1, i2):
                    continue
                p = pts[j]
                if ((b - a).cross(p - a).dot(n) > 0 and (c - b).cross(p - b).dot(n) > 0
                        and (a - c).cross(p - c).dot(n) > 0):
                    inside = True
                    break
            if not inside:
                tris.append([a, b, c])
                idx.pop(k)
                break
        else:
            break
    if len(idx) == 3:
        tris.append([pts[i] for i in idx])
    return tris


# --- GLB schreiben (eigener kleiner Exporter) ---

def write_glb(builder, path):
    tris = builder.triangles()
    chunks = bytearray()
    buffer_views = []
    accessors = []

    def add(data, fmt, count, kind, target=34962, minmax=None):
        nonlocal chunks
        while len(chunks) % 4:
            chunks += b"\0"
        offset = len(chunks)
        chunks += data
        buffer_views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target})
        acc = {"bufferView": len(buffer_views) - 1, "componentType": fmt, "count": count, "type": kind}
        if minmax:
            acc["min"], acc["max"] = minmax
        accessors.append(acc)
        return len(accessors) - 1

    primitives = []
    materials = []
    for mat_name in ("house", "glass"):
        verts = tris[mat_name]
        if not verts:
            continue
        pos = bytearray()
        nor = bytearray()
        uv0 = bytearray()
        uv1 = bytearray()
        col = bytearray()
        lo = [1e9] * 3
        hi = [-1e9] * 3
        # Gleiche Ecken (Lage, Normale, Koordinaten, Farbe) nur einmal speichern
        unique = {}
        index_list = []
        for vert in verts:
            p, n, uv, uv2, c = vert
            key = (round(p.x, 5), round(p.y, 5), round(p.z, 5), round(n.x, 4), round(n.y, 4), round(n.z, 4),
                   round(uv[0], 5), round(uv[1], 5), uv2, tuple(round(v, 4) for v in c))
            if key in unique:
                index_list.append(unique[key])
                continue
            unique[key] = len(unique)
            index_list.append(unique[key])
            pos += struct.pack("<3f", p.x, p.y, p.z)
            nor += struct.pack("<3f", n.x, n.y, n.z)
            # glTF zählt v von oben nach unten
            uv0 += struct.pack("<2f", uv[0], 1.0 - uv[1])
            uv1 += struct.pack("<2f", uv2[0], uv2[1])
            col += struct.pack("<4f", c[0], c[1], c[2], c[3])
            for k in range(3):
                lo[k] = min(lo[k], p[k])
                hi[k] = max(hi[k], p[k])
        count = len(unique)
        attributes = {
            "POSITION": add(bytes(pos), 5126, count, "VEC3", minmax=(lo, hi)),
            "NORMAL": add(bytes(nor), 5126, count, "VEC3"),
            "TEXCOORD_0": add(bytes(uv0), 5126, count, "VEC2"),
            "TEXCOORD_1": add(bytes(uv1), 5126, count, "VEC2"),
            "COLOR_0": add(bytes(col), 5126, count, "VEC4"),
        }
        index_data = struct.pack("<%dI" % len(index_list), *index_list)
        indices = add(index_data, 5125, len(index_list), "SCALAR", target=34963)
        if mat_name == "house":
            materials.append({"name": "house", "pbrMetallicRoughness": {"baseColorFactor": [0.8, 0.8, 0.8, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.8}})
        else:
            materials.append({"name": "glass", "alphaMode": "BLEND", "pbrMetallicRoughness": {"baseColorFactor": [0.15, 0.18, 0.2, 0.3], "metallicFactor": 0.0, "roughnessFactor": 0.05}})
        primitives.append({"attributes": attributes, "indices": indices, "material": len(materials) - 1})
    nodes = [{"name": builder.name, "mesh": 0}]
    meshes = [{"name": builder.name, "primitives": primitives}]
    # Jeder Kasten ein eigener Knoten "PropN-colonly" (Godot: unsichtbare feste Kollision;
    # HouseFacade setzt daraus auch Hindernisse für Passanten)
    for number, (b_lo, b_hi) in enumerate(builder.colliders, start=1):
        x0, y0, z0 = b_lo
        x1, y1, z1 = b_hi
        corners = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                   (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        pos = bytearray()
        count = 0
        for quad in ((4, 5, 6, 7), (1, 0, 3, 2), (0, 4, 7, 3), (5, 1, 2, 6), (7, 6, 2, 3), (0, 1, 5, 4)):
            for k in (quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]):
                pos += struct.pack("<3f", *corners[k])
                count += 1
        acc = add(bytes(pos), 5126, count, "VEC3", minmax=([x0, y0, z0], [x1, y1, z1]))
        meshes.append({"name": "Prop%d" % number, "primitives": [{"attributes": {"POSITION": acc}}]})
        nodes.append({"name": "Prop%d-colonly" % number, "mesh": len(meshes) - 1})
    while len(chunks) % 4:
        chunks += b"\0"
    doc = {
        "asset": {"version": "2.0", "generator": "Cozy Bücherei style_lib.py"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(chunks)}],
    }
    js = json.dumps(doc, separators=(",", ":")).encode("utf8")
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(chunks)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(chunks), 0x004E4942))
        f.write(chunks)
    return sum(len(v) for v in tris.values()) // 3


def write_import_settings(glb_path):
    """Godot-Importeinstellungen für ein neues Modell: Material "house" wird zum gemeinsamen
    Stil-Material, "glass" zum Schaufensterglas; keine automatischen Detailstufen (LOD)."""
    path = glb_path + ".import"
    if os.path.exists(path):
        return
    res = "res://" + os.path.relpath(glb_path, ROOT).replace(os.sep, "/")
    with open(path, "w") as f:
        f.write("""[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="%s"

[params]

meshes/generate_lods=false
_subresources={
"materials": {
"glass": {
"use_external/enabled": true,
"use_external/path": "res://assets/materials/house_glass.tres"
},
"house": {
"use_external/enabled": true,
"use_external/path": "res://assets/materials/house_style.tres"
}
}
}
""" % res)


# --- Blender-Objekt mit Vorschau-Materialien (sieht aus wie im Spiel) ---

_ATLAS = {}


def _atlas(kind):
    if kind in _ATLAS:
        try:
            _ATLAS[kind].name
        except ReferenceError:
            # Nach einem Neustart der Blender-Szene ist das Bild weg
            del _ATLAS[kind]
    if kind not in _ATLAS:
        path = os.path.join(TEX_DIR, "house_%s.png" % kind)
        img = bpy.data.images.load(path, check_existing=True)
        if kind == "normal":
            img.colorspace_settings.name = "Non-Color"
        else:
            # Alpha ist kein Durchsichtig, sondern "darf eingefärbt werden"
            img.alpha_mode = "CHANNEL_PACKED"
        _ATLAS[kind] = img
    return _ATLAS[kind]


def preview_material(mat, role_colors):
    """Blender-Material, das rechnet wie der Godot-Shader (Ebene aus dem Atlas, Einfärben)."""
    name = mat.key()
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nodes = nt.nodes
    links = nt.links
    bsdf = nodes["Principled BSDF"]
    if mat.glass:
        bsdf.inputs["Base Color"].default_value = (0.85, 0.9, 0.9, 1)
        bsdf.inputs["Roughness"].default_value = 0.04
        bsdf.inputs["Transmission"].default_value = 0.9
        bsdf.inputs["IOR"].default_value = 1.2
        return m
    info = LAYERS[mat.layer]
    index = info["index"]
    cell_x = index % GRID_X
    cell_y = GRID_Y - 1 - index // GRID_X
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    frac = nodes.new("ShaderNodeVectorMath")
    frac.operation = "FRACTION"
    links.new(uv.outputs["UV"], frac.inputs[0])
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.0 / GRID_X, 1.0 / GRID_Y, 1)
    mapping.inputs["Location"].default_value = (cell_x / GRID_X, cell_y / GRID_Y, 0)
    links.new(frac.outputs[0], mapping.inputs["Vector"])
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = _atlas("albedo")
    tex.interpolation = "Linear"
    links.new(mapping.outputs[0], tex.inputs["Vector"])
    if mat.role == "fixed":
        tint = srgb_to_linear(mat.color)
    else:
        tint = srgb_to_linear(role_colors[mat.role])
    rgb = nodes.new("ShaderNodeRGB")
    rgb.outputs[0].default_value = (tint[0] * TINT_GAIN, tint[1] * TINT_GAIN, tint[2] * TINT_GAIN, 1)
    mult = nodes.new("ShaderNodeMixRGB")
    mult.blend_type = "MULTIPLY"
    mult.inputs["Fac"].default_value = 1.0
    links.new(tex.outputs["Color"], mult.inputs["Color1"])
    links.new(rgb.outputs[0], mult.inputs["Color2"])
    mix = nodes.new("ShaderNodeMixRGB")
    links.new(tex.outputs["Alpha"], mix.inputs["Fac"])
    links.new(tex.outputs["Color"], mix.inputs["Color1"])
    links.new(mult.outputs[0], mix.inputs["Color2"])
    links.new(mix.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = info["roughness"]
    bsdf.inputs["Metallic"].default_value = info["metallic"]
    ntex = nodes.new("ShaderNodeTexImage")
    ntex.image = _atlas("normal")
    links.new(mapping.outputs[0], ntex.inputs["Vector"])
    nmap = nodes.new("ShaderNodeNormalMap")
    nmap.uv_map = "UVMap"
    links.new(ntex.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    if mat.glow > 0:
        # Wie im Shader: Leuchten in der eigenen Farbe
        links.new(mix.outputs[0], bsdf.inputs["Emission"])
        bsdf.inputs["Emission Strength"].default_value = mat.glow * GLOW_STRENGTH
    if SHOW_BACKFACES:
        geo = nodes.new("ShaderNodeNewGeometry")
        pink = nodes.new("ShaderNodeEmission")
        pink.inputs["Color"].default_value = (1.0, 0.0, 0.8, 1)
        pink.inputs["Strength"].default_value = 3.0
        choose = nodes.new("ShaderNodeMixShader")
        links.new(geo.outputs["Backfacing"], choose.inputs["Fac"])
        links.new(bsdf.outputs[0], choose.inputs[1])
        links.new(pink.outputs[0], choose.inputs[2])
        links.new(choose.outputs[0], nodes["Material Output"].inputs["Surface"])
    return m


def to_blender(builder, role_colors, collection=None):
    """Blender-Objekt bauen (Godot-Koordinaten werden zu Blender: x, -z, y)."""
    mesh = bpy.data.meshes.new(builder.name)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("Layers")
    slots = {}
    materials = []
    loop_normals = []
    for face in builder.faces:
        mat = face["mat"]
        key = mat.key()
        if key not in slots:
            slots[key] = len(materials)
            materials.append(preview_material(mat, role_colors))
        verts = [bm.verts.new((p.x, -p.z, p.y)) for p in face["pts"]]
        try:
            f = bm.faces.new(verts)
        except ValueError:
            continue
        f.material_index = slots[key]
        info = LAYERS[mat.layer]
        for loop, p, n in zip(f.loops, face["pts"], face["normals"]):
            u, v = _planar_uv(p, face["n"], info["tile_size"])
            loop[uv].uv = (u, v)
            loop[uv2].uv = (info["index"], ROLES[mat.role])
            loop_normals.append((n.x, -n.z, n.y))
        f.smooth = True
    bm.to_mesh(mesh)
    bm.free()
    for m in materials:
        mesh.materials.append(m)
    mesh.use_auto_smooth = True
    mesh.normals_split_custom_set(loop_normals)
    obj = bpy.data.objects.new(builder.name, mesh)
    (collection or bpy.context.scene.collection).objects.link(obj)
    return obj


# --- Kontrollbilder (Cycles, ohne Bildschirm) ---

def setup_render(resolution=(1200, 800), samples=24):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = -0.6
    world = bpy.data.worlds.new("Sky") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    sky = world.node_tree.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"
    sky.sun_elevation = math.radians(28)
    sky.sun_rotation = math.radians(200)
    sky.sun_intensity = 0.35
    world.node_tree.links.new(sky.outputs[0], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.35
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.2
    sun_data.color = (1.0, 0.9, 0.78)
    sun_data.angle = math.radians(2)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(55), 0, math.radians(200))
    scene.collection.objects.link(sun)


def render_view(path, cam_godot, target_godot, lens=35):
    """Bild aus Kamera-Position cam (Godot-Koordinaten) mit Blick auf target."""
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    c = Vector((cam_godot[0], -cam_godot[2], cam_godot[1]))
    t = Vector((target_godot[0], -target_godot[2], target_godot[1]))
    cam.location = c
    cam.rotation_euler = (t - c).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
