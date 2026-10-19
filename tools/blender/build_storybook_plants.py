"""Baut die Pflanzen-Bibliothek im Bilderbuch-Stil (Stil-Umbau der Welt, Etappe 4h, Schritt 5).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_plants.py [-- <id> …] [--render] [--force]

Je Pflanze:
    assets/models/plants/<id>.glb                 Spiel (Blätter, Blüten, Stiele in Sammel-Materialien)
    assets/models/source/plants/<id>.blend        Einzelteile zum Nachmodellieren (Blender, Nomad Sculpt)
    scenes/world/plants/<id>.tscn                 austauschbare Szene (Wurzel PlantPiece + Kind "Model")
und je Art eine Vorlage in echter Größe: assets/models/templates/plants/<art>.glb (Kasten-Ausschnitt,
Topf, Wandstück … mit dem Ursprung des Pflanzplatzes).
Im Spiel setzt Greenery (scripts/world/greenery.gd) die Szenen auf die Pflanzplätze („PlantSpot_…“ in den
Haus-Modellen). Eigene Pflanze: neue Szene in scenes/world/plants/ mit PlantPiece (Art, Nennmaß) – fertig.
"""

import json
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_greenery as G  # noqa: E402
import storybook_lib as SB  # noqa: E402
from storybook_lib import Body  # noqa: E402

OUT = os.path.join(SC.ROOT, "assets", "models", "plants")
SRC = os.path.join(SC.ROOT, "assets", "models", "source", "plants")
SCENES = os.path.join(SC.ROOT, "scenes", "world", "plants")
TEMPLATES = os.path.join(SC.ROOT, "assets", "models", "templates", "plants")

# id: (Art, Nennmaß (Breite, Tiefe, Höhe) in m, Gewicht, Kollisionsradius, Hinweis, Bau-Funktion)
PLANTS = {
    "box_geranium_red": ("box", (0.3, 0.16, 0.42), 1.0, 0.0, "", lambda p: G.box_geranium(p, "red")),
    "box_geranium_pink": ("box", (0.3, 0.16, 0.42), 1.0, 0.0, "", lambda p: G.box_geranium(p, "pink")),
    "box_petunia": ("box", (0.3, 0.16, 0.3), 1.0, 0.0, "", lambda p: G.box_petunia(p, ("pink", "rose", "lilac", "cream_flower"))),
    "box_mixed": ("box", (0.3, 0.16, 0.34), 0.8, 0.0, "", G.box_mixed),
    "potfill_bush": ("potfill", (0.4, 0.4, 0.5), 1.0, 0.0, "classic", lambda p: G.bush(p, 0.22, 0.42)),
    "potfill_hydrangea": ("potfill", (0.4, 0.4, 0.5), 1.0, 0.0, "bowl", lambda p: G.hydrangea(p, p.rnd.choice(("blue_flower", "pink")), 1.0)),
    "potfill_geranium": ("potfill", (0.4, 0.4, 0.45), 1.0, 0.0, "", lambda p: G.geranium_bush(p, "red")),
    "potfill_olive": ("potfill", (0.4, 0.4, 1.2), 0.8, 0.0, "tall", lambda p: G.olive(p, 0.85, 0.26)),
    "potfill_lavender": ("potfill", (0.4, 0.4, 0.55), 0.8, 0.0, "tub", G.lavender),
    "basket_trailing_pink": ("basket", (0.34, 0.34, 0.5), 1.0, 0.0, "", lambda p: G.trailing(p, ("pink", "rose", "cream_flower"))),
    "basket_trailing_red": ("basket", (0.34, 0.34, 0.5), 1.0, 0.0, "", lambda p: G.trailing(p, ("red", "coral", "cream_flower"))),
    "pot_bush": ("pot", (0.5, 0.5, 0.9), 1.0, 0.0, "", "pot:bush"),
    "pot_hydrangea": ("pot", (0.5, 0.5, 0.85), 1.0, 0.0, "", "pot:hydrangea"),
    "pot_olive": ("pot", (0.5, 0.5, 1.4), 0.7, 0.0, "", "pot:olive"),
    "climber_ivy_25": ("climber", (1.3, 0.25, 2.5), 1.0, 0.0, "", lambda p: G.climber(p, 1.3, 2.5, "ivy")),
    "climber_ivy_40": ("climber", (1.4, 0.3, 4.0), 1.0, 0.0, "", lambda p: G.climber(p, 1.4, 4.0, "ivy")),
    "climber_ivy_55": ("climber", (1.6, 0.3, 5.5), 1.0, 0.0, "", lambda p: G.climber(p, 1.6, 5.5, "ivy")),
    "climber_ivy_narrow": ("climber", (0.5, 0.25, 3.5), 1.0, 0.0, "", lambda p: G.climber(p, 0.5, 3.5, "ivy")),
    "climber_rose_30": ("climber", (1.2, 0.3, 3.0), 0.8, 0.0, "", lambda p: G.climber(p, 1.2, 3.0, "rose")),
    "climber_rose_45": ("climber", (1.3, 0.3, 4.5), 0.8, 0.0, "", lambda p: G.climber(p, 1.3, 4.5, "rose")),
    "climber_wisteria_55": ("climber", (1.5, 0.35, 5.5), 0.6, 0.0, "wisteria", lambda p: G.climber(p, 1.5, 5.5, "wisteria")),
    "climber_wisteria_narrow": ("climber", (0.6, 0.3, 5.5), 0.6, 0.0, "wisteria", lambda p: G.climber(p, 0.6, 5.5, "wisteria")),
    "bed_hosta": ("bed", (0.55, 0.55, 0.4), 1.0, 0.0, "", lambda p: G.hosta(p, 1.0)),
    "bed_fern": ("bed", (0.6, 0.6, 0.45), 1.0, 0.0, "", lambda p: G.fern(p, 1.0)),
    "bed_daisy": ("bed", (0.45, 0.45, 0.42), 1.0, 0.0, "", G.daisies),
    "bed_lavender": ("bed", (0.45, 0.45, 0.55), 1.0, 0.0, "", G.lavender),
    "hedge_shrub": ("hedge", (0.8, 0.8, 1.3), 1.0, 0.0, "", lambda p: G.shrub(p, 0.8, 1.3)),
    "hedge_shrub_rose": ("hedge", (0.8, 0.8, 1.2), 0.7, 0.0, "", lambda p: G.shrub(p, 0.8, 1.2, "rose")),
    "tree_garden": ("tree", (3.0, 3.0, 5.0), 1.0, 0.0, "", lambda p: G.tree(p, 5.0, 1.45)),
    "tubtree_bay": ("tubtree", (0.9, 0.9, 3.0), 1.0, 0.36, "", "tub:tree"),
}

# frischere, wärmere Grüntöne als die alten Pflanzen (Vorlagebilder: saftiges Gelbgrün)
FRESH = {"ivy": (0.26, 0.42, 0.16), "ivy_young": (0.42, 0.58, 0.22), "leaf": (0.34, 0.52, 0.2), "box_leaf": (0.27, 0.45, 0.17),
         "olive_leaf": (0.52, 0.6, 0.4), "stem": (0.4, 0.42, 0.22), "bark": (0.45, 0.34, 0.24)}


def materials():
    M = SC.materials()
    G.plant_materials(M)
    for key, col in FRESH.items():
        info = SC.GAME_MATERIALS[M[key].name]
        kw = {k: v for k, v in info.items() if k not in ("color", "glow", "plant")}
        M[key] = SC.make_material(M[key].name + " frisch", col, glow=info.get("glow", 0.0), plant=info.get("plant", False), **kw)
    return M


def build_plant(pid, M, coll):
    kind, size, weight, col_r, hint, fn = PLANTS[pid]
    p = G.Plant(M, coll, seed=abs(hash(pid)) % 100000 if False else sum(ord(c) * (i + 1) for i, c in enumerate(pid)))
    extra = []
    if isinstance(fn, str) and fn.startswith("pot:"):
        # Topf (Terrakotta) mit Erde, darin die Pflanze
        SC.SPOTS["coll"] = None
        r, h = 0.22, 0.46
        SC.pot(M, coll, "Topf", (0, 0, 0), r, h, 7, mat=p.rnd.choice(("pot", "pot_light", "pot_dark")), style="classic", spot=None)
        top = h * 0.84 + 0.035
        sub = {"bush": lambda q: G.bush(q, 0.22, 0.42), "hydrangea": lambda q: G.hydrangea(q, q.rnd.choice(("blue_flower", "pink")), 1.0),
               "olive": lambda q: G.olive(q, 0.85, 0.26)}[fn[4:]]
        sub(p)
        objs = p.build(sway_height=None)
        for o in objs:
            o.location.z += top
        return objs
    if isinstance(fn, str) and fn.startswith("tub:"):
        top = G.tub(M, coll, 0.36, 0.5, seed=5)
        G.tree(p, 2.6, 0.9, mat="box_leaf")
        objs = p.build()
        for o in objs:
            o.location.z += top
        return objs
    fn(p)
    sway = {"climber": None, "tree": None, "hedge": size[2], "tubtree": None}.get(kind, size[2])
    return p.build(sway_height=sway)


def measured_size(meshes):
    """Echte Ausdehnung (Breite x, Tiefe y, Höhe z) der gebauten Pflanze."""
    dg = bpy.context.evaluated_depsgraph_get()
    lo, hi = [1e9] * 3, [-1e9] * 3
    for o in meshes:
        ev = o.evaluated_get(dg)
        for v in ev.to_mesh().vertices:
            p = o.matrix_world @ v.co
            for i in range(3):
                lo[i], hi[i] = min(lo[i], p[i]), max(hi[i], p[i])
        ev.to_mesh_clear()
    return (2 * max(abs(lo[0]), abs(hi[0])), hi[1] - lo[1], hi[2])


SIZE_FILE = os.path.join(SRC, "measured_sizes.json")


def write_scene(pid, real=None):
    """real = gemessene Größe: Kletterpflanzen bekommen ihr echtes Maß als Nennmaß (Greenery setzt sie
    danach so ein, dass sie nie über ihren Wandstreifen hinaus – also über Fenster – wachsen)."""
    kind, size, weight, col_r, hint, _ = PLANTS[pid]
    sizes = json.load(open(SIZE_FILE)) if os.path.exists(SIZE_FILE) else {}
    if real is not None:
        sizes[pid] = [round(v, 3) for v in real]
        os.makedirs(SRC, exist_ok=True)
        json.dump(sizes, open(SIZE_FILE, "w"), indent=1, sort_keys=True)
    if kind == "climber" and pid in sizes:
        w, d, h = sizes[pid]
        size = (w, d, h)
    os.makedirs(SCENES, exist_ok=True)
    text = """[gd_scene load_steps=3 format=3]

; Pflanze im Bilderbuch-Stil (gebaut von tools/blender/build_storybook_plants.py). Austauschbar: das Kind
; "Model" durch ein eigenes Modell ersetzen (Ursprung wie die Vorlage assets/models/templates/plants/%s.glb)
; oder eine neue Szene mit PlantPiece in diesen Ordner legen – Greenery findet sie selbst.

[ext_resource type="Script" path="res://scripts/world/plant_piece.gd" id="1_piece"]
[ext_resource type="PackedScene" path="res://assets/models/plants/%s.glb" id="2_model"]

[node name="%s" type="Node3D"]
script = ExtResource("1_piece")
kind = "%s"
nominal_size = Vector3(%.3f, %.3f, %.3f)
weight = %.2f
collision_radius = %.2f
hint = "%s"

[node name="Model" parent="." instance=ExtResource("2_model")]
""" % (kind, pid, "".join(w.capitalize() for w in pid.split("_")), kind, size[0], size[2], size[1], weight, col_r, hint)
    with open(os.path.join(SCENES, pid + ".tscn"), "w") as f:
        f.write(text)


def write_template(kind, M):
    """Vorlage in echter Größe: Umgebung des Pflanzplatzes (Kasten-Ausschnitt, Topf, Wandstück …),
    Ursprung = Pflanzplatz, Vorderseite -y (glTF: +z)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M = materials()
    coll = SB.collection("Vorlage %s" % kind)
    b = Body("Vorlage", M["box"], coll, seed=1, vary=0.0)
    if kind == "box":
        b.box((0, 0.0, -0.1), (0.3, 0.16, 0.2), step=1, dent=0.0)
        b.box((0, 0.11, 0.0), (0.4, 0.02, 0.42), step=1, dent=0.0)     # Hauswand dahinter
    elif kind in ("potfill", "basket"):
        b.lathe([(0.0, -0.4), (0.15, -0.4), (0.21, -0.04), (0.23, 0.0), (0.0, 0.0)], (0, 0, 0), segs=24)
    elif kind == "pot":
        b.box((0, 0.55, 0.5), (1.0, 0.04, 1.0), step=1, dent=0.0)      # Wand 0,32 m dahinter (ungefähr)
    elif kind == "climber":
        b.box((0, 0.02, 2.0), (1.6, 0.04, 4.0), step=1, dent=0.0)       # Wand bei y = 0
    elif kind in ("bed", "hedge", "tree", "tubtree"):
        b.box((0, 0, -0.02), (1.0, 1.0, 0.04), step=1, dent=0.0)       # Boden
    b.build()
    os.makedirs(TEMPLATES, exist_ok=True)
    gd = os.path.join(TEMPLATES, ".gdignore")
    if not os.path.exists(gd):
        open(gd, "w").close()
    SC.export_objects(list(coll.objects), [], os.path.join(TEMPLATES, kind + ".glb"), extra=[])


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = [a for a in argv if not a.startswith("--")]
    total = 0
    for pid in PLANTS:
        if only and pid not in only:
            continue
        blend = os.path.join(SRC, pid + ".blend")
        stamp = os.path.join(SRC, pid + ".stamp")
        if SC.edited_by_hand(blend, stamp) and "--force" not in argv:
            print("%-26s in Blender bearbeitet – bleibt" % pid)
            write_scene(pid)
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.preferences.filepaths.save_version = 0
        SC.GAME_MATERIALS.clear()
        SB.BEVEL_SEGMENTS = (2, 1)
        M = materials()
        coll = SB.collection("Pflanze %s" % pid)
        objs = build_plant(pid, M, coll)
        meshes = [o for o in coll.objects if o.type == "MESH"]
        bad = [(o.name, SB.non_manifold(o)) for o in meshes if SB.non_manifold(o)]
        glb = os.path.join(OUT, pid + ".glb")
        tris, n = SC.export_objects(meshes, [], glb, palette=True, extra=[])
        mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
        SC.write_import_settings(mapping, glb)
        write_scene(pid, measured_size(meshes))
        total += tris
        print("%-26s %6d Dreiecke, %d Netze, offene Kanten: %s" % (pid, tris, n, bad if bad else "keine"))
        if "--render" in argv:
            SC.setup_render(True)
            k, size = PLANTS[pid][0], PLANTS[pid][1]
            h = size[2]
            d = max(1.2, h * 1.6 + 0.6)
            SC.render("pflanze_%s" % pid, (d * 0.45, -d, h * 0.65 + 0.3), (0, 0, h * 0.45), 35, (700, 700))
        os.makedirs(SRC, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
        with open(stamp, "w") as f:
            f.write(SC.blend_fingerprint(blend) + "\n")
        del objs
    if not only:
        for kind in sorted({v[0] for v in PLANTS.values()}):
            write_template(kind, None)
    print("Fertig: zusammen %d Dreiecke" % total)


if __name__ == "__main__":
    main()
