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
    # Blumenkästen: Ausschnitt 0,3 m (Greenery reiht verschiedene Sorten nebeneinander)
    "box_geranium_red": ("box", (0.3, 0.16, 0.42), 1.0, 0.0, "", lambda p: G.box_geranium(p, "red")),
    "box_geranium_pink": ("box", (0.3, 0.16, 0.42), 1.0, 0.0, "", lambda p: G.box_geranium(p, "pink")),
    "box_geranium_coral": ("box", (0.3, 0.16, 0.42), 0.7, 0.0, "", lambda p: G.box_geranium(p, "coral", "leaf_dark")),
    "box_geranium_white": ("box", (0.3, 0.16, 0.42), 0.6, 0.0, "", lambda p: G.box_geranium(p, "white_flower", "leaf_blue")),
    "box_petunia": ("box", (0.3, 0.16, 0.3), 1.0, 0.0, "", lambda p: G.box_petunia(p, ("pink", "rose", "lilac", "cream_flower"))),
    "box_petunia_purple": ("box", (0.3, 0.16, 0.3), 0.8, 0.0, "",
                           lambda p: G.box_petunia(p, ("purple_flower", "magenta_flower", "white_flower"), "leaf_lime")),
    "box_petunia_white": ("box", (0.3, 0.16, 0.3), 0.6, 0.0, "", lambda p: G.box_petunia(p, ("white_flower", "blush_flower", "sky_flower"))),
    "box_mixed": ("box", (0.3, 0.16, 0.34), 0.8, 0.0, "", G.box_mixed),
    "box_lobelia": ("box", (0.3, 0.16, 0.2), 0.8, 0.0, "", lambda p: G.lobelia_box(p)),
    "box_lobelia_white": ("box", (0.3, 0.16, 0.2), 0.5, 0.0, "", lambda p: G.lobelia_box(p, ("white_flower", "sky_flower"), "leaf")),
    "box_begonia_red": ("box", (0.3, 0.16, 0.24), 0.7, 0.0, "", lambda p: G.begonia_box(p, "red", "leaf_dark")),
    "box_begonia_pink": ("box", (0.3, 0.16, 0.24), 0.6, 0.0, "", lambda p: G.begonia_box(p, "pink", "leaf_bronze")),
    "box_fuchsia": ("box", (0.3, 0.16, 0.3), 0.7, 0.0, "", lambda p: G.fuchsia(p, "magenta_flower", "purple_flower")),
    "box_fuchsia_red": ("box", (0.3, 0.16, 0.3), 0.5, 0.0, "", lambda p: G.fuchsia(p, "red", "purple_flower")),
    "box_herbs": ("box", (0.3, 0.16, 0.28), 0.5, 0.0, "", G.herb_box),
    "box_pansy": ("box", (0.3, 0.16, 0.16), 0.6, 0.0, "", G.pansy_box),
    "box_heather": ("box", (0.3, 0.16, 0.26), 0.4, 0.0, "", lambda p: G.heather(p, "magenta_flower", n=26)),
    "box_heather_white": ("box", (0.3, 0.16, 0.26), 0.3, 0.0, "", lambda p: G.heather(p, "white_flower", n=26)),
    "box_ivy": ("box", (0.3, 0.16, 0.2), 0.6, 0.0, "", G.ivy_box),
    # Füllung vorhandener Töpfe und Kübel (Hinweis = Topfform)
    "potfill_bush": ("potfill", (0.4, 0.4, 0.5), 1.0, 0.0, "classic", lambda p: G.bush(p, 0.22, 0.42)),
    "potfill_bush_dark": ("potfill", (0.4, 0.4, 0.5), 0.6, 0.0, "classic", lambda p: G.bush(p, 0.22, 0.4, mat="leaf_dark", leaf=0.055)),
    "potfill_boxball": ("potfill", (0.4, 0.4, 0.42), 0.7, 0.0, "classic", lambda p: G.boxball(p, 0.19)),
    "potfill_hydrangea_blue": ("potfill", (0.4, 0.4, 0.5), 0.8, 0.0, "bowl", lambda p: G.hydrangea(p, "blue_flower")),
    "potfill_hydrangea_pink": ("potfill", (0.4, 0.4, 0.5), 0.7, 0.0, "bowl", lambda p: G.hydrangea(p, "pink", leaf_mat="leaf_dark")),
    "potfill_hydrangea_white": ("potfill", (0.4, 0.4, 0.5), 0.5, 0.0, "bowl", lambda p: G.hydrangea(p, "white_flower", leaf_mat="leaf_lime")),
    "potfill_geranium_red": ("potfill", (0.4, 0.4, 0.45), 0.8, 0.0, "", lambda p: G.geranium_bush(p, "red")),
    "potfill_geranium_pink": ("potfill", (0.4, 0.4, 0.45), 0.7, 0.0, "", lambda p: G.geranium_bush(p, "pink")),
    "potfill_geranium_coral": ("potfill", (0.4, 0.4, 0.45), 0.5, 0.0, "", lambda p: G.geranium_bush(p, "coral")),
    "potfill_olive": ("potfill", (0.4, 0.4, 1.2), 0.8, 0.0, "tall", lambda p: G.olive(p, 0.85, 0.26)),
    "potfill_lavender": ("potfill", (0.4, 0.4, 0.55), 0.9, 0.0, "tub", lambda p: G.lavender_bush(p)),
    "potfill_lavender_dark": ("potfill", (0.4, 0.4, 0.55), 0.5, 0.0, "tub", lambda p: G.lavender_bush(p, "purple_flower", spikes=42)),
    "potfill_marguerite": ("potfill", (0.4, 0.4, 0.5), 0.7, 0.0, "",
                           lambda p: G.flower_bush(p, lambda q, c, at, up: G.daisy_head(q, at, up, 0.036, petal=c), ("white_flower",), n=12,
                                                   height=0.38, leaf_mat="leaf_blue", leaf_shape="narrow", leaf=0.05)),
    "potfill_dahlia": ("potfill", (0.4, 0.4, 0.55), 0.5, 0.0, "",
                       lambda p: G.flower_bush(p, lambda q, c, at, up: G.pompon(q, c, at, up, 0.048), ("burgundy_flower", "orange_flower",
                                                                                                     "peach_flower"), n=7, height=0.42, leaf_mat="leaf_dark")),
    "potfill_mums": ("potfill", (0.4, 0.4, 0.4), 0.5, 0.0, "bowl",
                     lambda p: G.flower_bush(p, lambda q, c, at, up: G.pompon(q, c, at, up, 0.03, layers=3, points=12),
                                             ("yellow_flower", "orange_flower", "gold_flower"), n=18, height=0.3, leaf_mat="leaf_dark", leaf=0.045)),
    "potfill_tulips_red": ("potfill", (0.4, 0.4, 0.45), 0.5, 0.0, "", lambda p: G.tulip_pot(p, "red")),
    "potfill_tulips_yellow": ("potfill", (0.4, 0.4, 0.45), 0.5, 0.0, "", lambda p: G.tulip_pot(p, "yellow_flower")),
    "potfill_tulips_mixed": ("potfill", (0.4, 0.4, 0.45), 0.5, 0.0, "", lambda p: G.tulip_pot(p, ("pink", "white_flower", "peach_flower"))),
    "potfill_grass": ("potfill", (0.4, 0.4, 0.6), 0.5, 0.0, "tall",
                      lambda p: G.grass_tuft(p, blades=60, height=0.5, mats=("grass_leaf", "leaf_blue", "grass_leaf"), plume="peach_flower")),
    "potfill_fern": ("potfill", (0.4, 0.4, 0.45), 0.5, 0.0, "", lambda p: G.fern(p, 0.85)),
    "potfill_hosta": ("potfill", (0.4, 0.4, 0.4), 0.5, 0.0, "bowl", lambda p: G.hosta(p, 0.85, mats=("leaf_blue", "leaf_blue", "leaf"))),
    "potfill_hosta_lime": ("potfill", (0.4, 0.4, 0.4), 0.4, 0.0, "bowl", lambda p: G.hosta(p, 0.8, mats=("leaf_lime", "leaf"))),
    "potfill_rosemary": ("potfill", (0.4, 0.4, 0.45), 0.4, 0.0, "", lambda p: G.rosemary(p)),
    "potfill_pansy": ("potfill", (0.4, 0.4, 0.2), 0.6, 0.0, "bowl", G.pansy_box),
    "potfill_fuchsia": ("potfill", (0.4, 0.4, 0.4), 0.5, 0.0, "bowl", lambda p: G.fuchsia(p, "magenta_flower", "purple_flower", trails=7)),
    "potfill_heather": ("potfill", (0.4, 0.4, 0.3), 0.4, 0.0, "", lambda p: G.heather(p, "magenta_flower")),
    "potfill_heather_white": ("potfill", (0.4, 0.4, 0.3), 0.3, 0.0, "", lambda p: G.heather(p, "white_flower")),
    "potfill_citrus": ("potfill", (0.4, 0.4, 1.1), 0.5, 0.0, "tall", lambda p: G.citrus(p, 0.7, "fruit_lemon")),
    "potfill_orange": ("potfill", (0.4, 0.4, 1.1), 0.4, 0.0, "tall", lambda p: G.citrus(p, 0.7, "fruit")),
    "potfill_rose": ("potfill", (0.4, 0.4, 0.55), 0.6, 0.0, "", lambda p: G.rose_bush(p, ("rose", "pink"))),
    "potfill_rose_white": ("potfill", (0.4, 0.4, 0.55), 0.4, 0.0, "", lambda p: G.rose_bush(p, ("cream_flower", "blush_flower"))),
    "potfill_trailing": ("potfill", (0.4, 0.4, 0.4), 0.6, 0.0, "", lambda p: G.trailing(p, ("pink", "blush_flower", "white_flower"), ranks=9)),
    # Ampeln
    "basket_trailing_pink": ("basket", (0.34, 0.34, 0.5), 1.0, 0.0, "", lambda p: G.trailing(p, ("pink", "rose", "cream_flower"))),
    "basket_trailing_red": ("basket", (0.34, 0.34, 0.5), 1.0, 0.0, "", lambda p: G.trailing(p, ("red", "coral", "cream_flower"))),
    "basket_trailing_blue": ("basket", (0.34, 0.34, 0.5), 0.8, 0.0, "",
                             lambda p: G.trailing(p, ("blue_flower", "sky_flower", "white_flower"), leaf_mat="leaf_lime")),
    "basket_trailing_purple": ("basket", (0.34, 0.34, 0.5), 0.8, 0.0, "", lambda p: G.trailing(p, ("purple_flower", "magenta_flower",
                                                                                                    "white_flower"))),
    "basket_fuchsia": ("basket", (0.34, 0.34, 0.5), 0.7, 0.0, "", lambda p: G.fuchsia(p, "magenta_flower", "purple_flower", trails=8)),
    # Kübel mit Pflanze vor der Tür (Topf gehört zur Pflanze)
    "pot_bush": ("pot", (0.5, 0.5, 0.9), 1.0, 0.0, "", "pot:bush"),
    "pot_hydrangea": ("pot", (0.5, 0.5, 0.85), 0.8, 0.0, "", "pot:hydrangea"),
    "pot_olive": ("pot", (0.5, 0.5, 1.4), 0.7, 0.0, "", "pot:olive"),
    "pot_boxball": ("pot", (0.5, 0.5, 1.2), 0.6, 0.0, "", "pot:boxball"),
    "pot_cone": ("pot", (0.5, 0.5, 1.35), 0.5, 0.0, "", "pot:cone"),
    "pot_citrus": ("pot", (0.5, 0.5, 1.3), 0.6, 0.0, "", "pot:citrus"),
    "pot_grass": ("pot", (0.5, 0.5, 1.1), 0.4, 0.0, "", "pot:grass"),
    "pot_lavender": ("pot", (0.5, 0.5, 1.0), 0.5, 0.0, "", "pot:lavender"),
    "pot_rose": ("pot", (0.5, 0.5, 1.25), 0.5, 0.0, "", "pot:rose"),
    # Kletterpflanzen: Efeu, Rosen und Glyzinien wachsen jetzt mit ihrer Wand (storybook_greenery.wall_ivy/garland,
    # gebaut von den Haus-, Gassen- und Laden-Scripts) – keine einzelnen Modelle mehr
    # Schnittblumen im Eimer, in der Vase oder im Fahrradkorb (Blumenladen)
    "bucket_tulips_red": ("bucket", (0.24, 0.24, 0.55), 0.8, 0.0, "", lambda p: G.cut_bunch(p, G.head_tulip, ("red",), n=13,
                                                                                               leaf_mat="leaf_blue", leaf=0.12)),
    "bucket_tulips_yellow": ("bucket", (0.24, 0.24, 0.55), 0.7, 0.0, "", lambda p: G.cut_bunch(p, G.head_tulip, ("yellow_flower",), n=13,
                                                                                                  leaf_mat="leaf_blue", leaf=0.12)),
    "bucket_tulips_pink": ("bucket", (0.24, 0.24, 0.55), 0.8, 0.0, "", lambda p: G.cut_bunch(p, G.head_tulip, ("pink", "blush_flower"), n=13,
                                                                                                leaf_mat="leaf_blue", leaf=0.12)),
    "bucket_tulips_mixed": ("bucket", (0.24, 0.24, 0.55), 0.8, 0.0, "",
                            lambda p: G.cut_bunch(p, G.head_tulip, ("orange_flower", "pink", "white_flower", "purple_flower"), n=14,
                                                  leaf_mat="leaf_blue", leaf=0.12)),
    "bucket_tulips_white": ("bucket", (0.24, 0.24, 0.55), 0.5, 0.0, "", lambda p: G.cut_bunch(p, G.head_tulip, ("white_flower",), n=13,
                                                                                                 leaf_mat="leaf_blue", leaf=0.12)),
    "bucket_roses_pink": ("bucket", (0.24, 0.24, 0.6), 0.8, 0.0, "", lambda p: G.cut_bunch(p, G.head_rose, ("pink", "rose"), n=11,
                                                                                              leaf_mat="leaf_dark", leaf_shape="oval", leaf=0.06, leaf_width=0.62)),
    "bucket_roses_red": ("bucket", (0.24, 0.24, 0.6), 0.7, 0.0, "", lambda p: G.cut_bunch(p, G.head_rose, ("red",), n=11,
                                                                                             leaf_mat="leaf_dark", leaf_shape="oval", leaf=0.06, leaf_width=0.62)),
    "bucket_roses_cream": ("bucket", (0.24, 0.24, 0.6), 0.7, 0.0, "", lambda p: G.cut_bunch(p, G.head_rose, ("cream_flower", "blush_flower"), n=11,
                                                                                               leaf_mat="leaf_dark", leaf_shape="oval", leaf=0.06, leaf_width=0.62)),
    "bucket_roses_peach": ("bucket", (0.24, 0.24, 0.6), 0.6, 0.0, "", lambda p: G.cut_bunch(p, G.head_rose, ("peach_flower", "coral"), n=11,
                                                                                               leaf_mat="leaf_dark", leaf_shape="oval", leaf=0.06, leaf_width=0.62)),
    "bucket_ranunculus": ("bucket", (0.24, 0.24, 0.5), 0.7, 0.0, "", lambda p: G.cut_bunch(p, G.head_peony, ("blush_flower", "pink", "coral"),
                                                                                              n=12, height=0.34, leaf_mat="leaf", leaf_shape="round", leaf=0.05,
                                                                                              leaf_width=0.9)),
    "bucket_peonies": ("bucket", (0.24, 0.24, 0.55), 0.6, 0.0, "", lambda p: G.cut_bunch(p, G.head_peony, ("pink", "white_flower", "magenta_flower"),
                                                                                           n=9, leaf_mat="leaf_dark", leaf_shape="oval", leaf=0.08)),
    "bucket_dahlias": ("bucket", (0.24, 0.24, 0.55), 0.6, 0.0, "",
                       lambda p: G.cut_bunch(p, G.head_dahlia, ("burgundy_flower", "peach_flower", "magenta_flower"), n=9, leaf_mat="leaf_dark",
                                             leaf_shape="oval", leaf=0.08, leaf_width=0.6)),
    "bucket_dahlias_warm": ("bucket", (0.24, 0.24, 0.55), 0.5, 0.0, "",
                            lambda p: G.cut_bunch(p, G.head_dahlia, ("orange_flower", "yellow_flower", "coral"), n=9, leaf_mat="leaf_dark",
                                                  leaf_shape="oval", leaf=0.08, leaf_width=0.6)),
    "bucket_sunflowers": ("bucket", (0.24, 0.24, 0.75), 0.6, 0.0, "", lambda p: G.cut_bunch(p, G.head_sunflower, ("yellow_flower", "gold_flower"),
                                                                                              n=6, height=0.6, spread=0.2, leaf_shape="heart", leaf=0.11,
                                                                                              leaf_width=0.85)),
    "bucket_daisies": ("bucket", (0.24, 0.24, 0.5), 0.7, 0.0, "", lambda p: G.cut_bunch(p, G.head_daisy, ("white_flower",), n=16, height=0.38,
                                                                                           leaf_mat="leaf_blue", leaf=0.06)),
    "bucket_hydrangea": ("bucket", (0.24, 0.24, 0.5), 0.6, 0.0, "", lambda p: G.cut_bunch(p, G.head_hydrangea, ("blue_flower", "sky_flower"), n=5,
                                                                                             height=0.32, spread=0.13, leaf_shape="oval", leaf=0.09,
                                                                                             leaf_width=0.7)),
    "bucket_hydrangea_pink": ("bucket", (0.24, 0.24, 0.5), 0.5, 0.0, "",
                              lambda p: G.cut_bunch(p, G.head_hydrangea, ("pink", "blush_flower", "white_flower"), n=5, height=0.32, spread=0.13,
                                                    leaf_shape="oval", leaf=0.09, leaf_width=0.7)),
    "bucket_lavender": ("bucket", (0.24, 0.24, 0.55), 0.6, 0.0, "", lambda p: G.cut_bunch(p, G.head_lavender, ("lilac", "purple_flower"), n=30,
                                                                                            height=0.45, spread=0.12, leaf_mat="leaf_silver", leaves=0)),
    "bucket_gypsophila": ("bucket", (0.24, 0.24, 0.5), 0.5, 0.0, "", lambda p: G.cut_bunch(p, G.head_gyps, ("white_flower",), n=12, height=0.38,
                                                                                              leaves=0)),
    "bucket_mixed": ("bucket", (0.24, 0.24, 0.5), 0.8, 0.0, "",
                     lambda p: G.cut_bunch(p, G.head_mixed, ("pink", "blush_flower", "white_flower", "peach_flower", "lilac"), n=13, height=0.36,
                                           leaf_mat="leaf_dark", leaf_shape="oval", leaf=0.06, leaf_width=0.6)),
    "bucket_mixed_bright": ("bucket", (0.24, 0.24, 0.5), 0.7, 0.0, "",
                            lambda p: G.cut_bunch(p, G.head_mixed, ("yellow_flower", "orange_flower", "magenta_flower", "white_flower", "red"), n=13,
                                                  height=0.36, leaf_mat="leaf", leaf_shape="oval", leaf=0.06, leaf_width=0.6)),
    "bucket_mums": ("bucket", (0.24, 0.24, 0.45), 0.5, 0.0, "",
                    lambda p: G.cut_bunch(p, lambda q, c, at, up: G.pompon(q, c, at, up, 0.04, layers=3, points=12),
                                          ("yellow_flower", "gold_flower", "burgundy_flower"), n=14, height=0.32, leaf_mat="leaf_dark", leaf_shape="oval",
                                          leaf=0.05, leaf_width=0.6)),
    # Beete
    "bed_hosta": ("bed", (0.55, 0.55, 0.4), 1.0, 0.0, "", lambda p: G.hosta(p, 1.0)),
    "bed_hosta_blue": ("bed", (0.55, 0.55, 0.4), 0.7, 0.0, "", lambda p: G.hosta(p, 1.0, mats=("leaf_blue", "leaf_blue", "leaf"))),
    "bed_fern": ("bed", (0.6, 0.6, 0.45), 1.0, 0.0, "", lambda p: G.fern(p, 1.0)),
    "bed_daisy": ("bed", (0.45, 0.45, 0.42), 1.0, 0.0, "", G.daisies),
    "bed_lavender": ("bed", (0.45, 0.45, 0.55), 1.0, 0.0, "", lambda p: G.lavender_bush(p)),
    "bed_pansy": ("bed", (0.4, 0.4, 0.2), 0.7, 0.0, "", G.pansy_box),
    "bed_tulips": ("bed", (0.4, 0.4, 0.45), 0.7, 0.0, "", lambda p: G.tulip_pot(p, ("red", "yellow_flower", "pink", "white_flower"), n=11)),
    "bed_grass": ("bed", (0.5, 0.5, 0.5), 0.6, 0.0, "", lambda p: G.grass_tuft(p, blades=45, height=0.45, plume="peach_flower")),
    # Bauerngarten (Vorgärten, Eckbeet: Hinweis "garden"): üppige Büsche und große Blumen
    "bed_hollyhock_pink": ("bed", (0.5, 0.5, 1.5), 0.8, 0.0, "garden", lambda p: G.hollyhock(p, ("pink", "blush_flower"))),
    "bed_hollyhock_mixed": ("bed", (0.5, 0.5, 1.5), 0.7, 0.0, "garden", lambda p: G.hollyhock(p, ("white_flower", "burgundy_flower", "peach_flower"))),
    "bed_foxglove": ("bed", (0.45, 0.45, 1.0), 0.8, 0.0, "garden", lambda p: G.foxglove(p, ("magenta_flower", "pink", "white_flower"))),
    "bed_delphinium": ("bed", (0.45, 0.45, 1.1), 0.7, 0.0, "garden", lambda p: G.delphinium(p, ("blue_flower", "sky_flower", "purple_flower"))),
    "bed_hydrangea_blue": ("bed", (0.7, 0.7, 0.7), 1.0, 0.0, "garden", lambda p: G.hydrangea(p, "blue_flower", size=1.5)),
    "bed_hydrangea_pink": ("bed", (0.7, 0.7, 0.7), 0.8, 0.0, "garden", lambda p: G.hydrangea(p, "pink", size=1.5, leaf_mat="leaf_dark")),
    "bed_hydrangea_white": ("bed", (0.7, 0.7, 0.7), 0.6, 0.0, "garden", lambda p: G.hydrangea(p, "white_flower", size=1.45, leaf_mat="leaf_lime")),
    "bed_rose_bush": ("bed", (0.6, 0.6, 0.8), 0.9, 0.0, "garden", lambda p: G.rose_bush(p, ("rose", "pink", "blush_flower"), height=0.7)),
    "bed_rose_bush_red": ("bed", (0.6, 0.6, 0.8), 0.6, 0.0, "garden", lambda p: G.rose_bush(p, ("red", "burgundy_flower"), height=0.7)),
    "bed_peony": ("bed", (0.55, 0.55, 0.6), 0.8, 0.0, "garden",
                  lambda p: G.flower_bush(p, lambda q, c, at, up: G.peony(q, c, at, up, 0.07), ("pink", "blush_flower", "white_flower"), n=7,
                                          height=0.55, leaf_mat="leaf_dark", leaf_shape="oval", leaf=0.08)),
    "bed_boxball": ("bed", (0.6, 0.6, 0.55), 0.6, 0.0, "garden", lambda p: G.boxball(p, 0.27)),
    "bed_flowering_shrub": ("bed", (0.7, 0.7, 0.8), 0.7, 0.0, "garden",
                            lambda p: G.bush(p, 0.3, 0.75, mat="leaf", leaf=0.06, blossoms="pink", mats=("leaf", "leaf_dark"))),
    "bed_marguerite": ("bed", (0.55, 0.55, 0.6), 0.7, 0.0, "garden",
                       lambda p: G.flower_bush(p, lambda q, c, at, up: G.daisy_head(q, at, up, 0.04, petal=c), ("white_flower",), n=16,
                                               height=0.55, leaf_mat="leaf_blue", leaf_shape="narrow", leaf=0.06)),
    "bed_dahlia": ("bed", (0.55, 0.55, 0.75), 0.6, 0.0, "garden",
                   lambda p: G.flower_bush(p, lambda q, c, at, up: G.pompon(q, c, at, up, 0.06), ("burgundy_flower", "peach_flower", "magenta_flower",
                                                                                                "orange_flower"), n=8, height=0.7, leaf_mat="leaf_dark")),
    # Hecke, Bäume
    "hedge_shrub": ("hedge", (0.8, 0.8, 1.3), 1.0, 0.0, "", lambda p: G.shrub(p, 0.8, 1.3)),
    "hedge_shrub_dark": ("hedge", (0.8, 0.8, 1.3), 0.8, 0.0, "", lambda p: G.shrub(p, 0.8, 1.25, mats=("leaf_dark", "box_leaf"))),
    "hedge_shrub_rose": ("hedge", (0.8, 0.8, 1.2), 0.7, 0.0, "", lambda p: G.shrub(p, 0.8, 1.2, "rose")),
    "hedge_hydrangea": ("hedge", (0.8, 0.8, 1.1), 0.6, 0.0, "", lambda p: G.shrub(p, 0.8, 1.1, "hydrangea_blue", mats=("leaf", "leaf_lime"))),
    "tree_garden": ("tree", (3.0, 3.0, 5.0), 1.0, 0.0, "", lambda p: G.tree(p, 5.0, 1.45)),
    "tree_garden_big": ("tree", (5.6, 7.4, 10.0), 1.0, 0.0, "garden", G.garden_tree),
    "tubtree_bay": ("tubtree", (0.9, 0.9, 3.0), 1.0, 0.36, "", "tub:tree"),
    # Grasbüschel aus der Ecke zwischen Hauswand und Gehweg (nach vorn gefächert), mal mit Wildblumen
    "walltuft_small": ("walltuft", (0.25, 0.12, 0.26), 1.0, 0.0, "", lambda p: G.wall_tuft(p, blades=18, height=0.26)),
    "walltuft_medium": ("walltuft", (0.3, 0.15, 0.38), 1.0, 0.0, "", lambda p: G.wall_tuft(p, blades=30, height=0.38)),
    "walltuft_large": ("walltuft", (0.4, 0.2, 0.5), 0.8, 0.0, "", lambda p: G.wall_tuft(p, blades=44, height=0.5)),
    "walltuft_tall": ("walltuft", (0.35, 0.18, 0.62), 0.6, 0.0, "", lambda p: G.wall_tuft(p, blades=34, height=0.62)),
    "walltuft_daisy": ("walltuft", (0.3, 0.15, 0.3), 0.6, 0.0, "", lambda p: G.wall_tuft(p, blades=28, height=0.36, flowers=("daisy",))),
    "walltuft_dandelion": ("walltuft", (0.3, 0.15, 0.28), 0.5, 0.0, "", lambda p: G.wall_tuft(p, blades=24, height=0.32, flowers=("dandelion",))),
    "walltuft_forgetmenot": ("walltuft", (0.3, 0.15, 0.28), 0.5, 0.0, "",
                             lambda p: G.wall_tuft(p, blades=26, height=0.34, flowers=("forgetmenot",), n_flowers=(2, 3))),
    "walltuft_campion": ("walltuft", (0.35, 0.18, 0.36), 0.5, 0.0, "", lambda p: G.wall_tuft(p, blades=30, height=0.44, flowers=("campion",))),
    "walltuft_poppy": ("walltuft", (0.35, 0.18, 0.36), 0.4, 0.0, "",
                       lambda p: G.wall_tuft(p, blades=28, height=0.42, flowers=("poppy",), n_flowers=(1, 2))),
    "walltuft_mixed": ("walltuft", (0.4, 0.2, 0.4), 0.6, 0.0, "",
                       lambda p: G.wall_tuft(p, blades=40, height=0.48, flowers=("daisy", "campion", "forgetmenot"), n_flowers=(2, 4))),
    # Begleiter für Töpfe: hängen auf einer Seite über den Rand (Greenery setzt sie zu den Topfpflanzen)
    "rim_ivy": ("rim", (0.4, 0.4, 0.3), 1.0, 0.0, "", lambda p: G.rim_piece(p, "ivy")),
    "rim_ivy_long": ("rim", (0.4, 0.4, 0.3), 0.8, 0.0, "", lambda p: G.rim_piece(p, "ivy_long")),
    "rim_grass": ("rim", (0.4, 0.4, 0.3), 1.0, 0.0, "", lambda p: G.rim_piece(p, "grass")),
    "rim_grass_flowers": ("rim", (0.4, 0.4, 0.3), 0.8, 0.0, "", lambda p: G.rim_piece(p, "grass_flowers")),
    "rim_flowers": ("rim", (0.4, 0.4, 0.3), 0.8, 0.0, "", lambda p: G.rim_piece(p, "flowers")),
    "rim_bacopa": ("rim", (0.4, 0.4, 0.3), 0.7, 0.0, "", lambda p: G.rim_piece(p, "bacopa")),
    # Grasbüschel an Bordstein und Laternen (rund)
    "tuft_grass": ("tuft", (0.3, 0.3, 0.25), 1.0, 0.0, "", lambda p: G.grass_tuft(p)),
    "tuft_grass_low": ("tuft", (0.25, 0.25, 0.18), 1.0, 0.0, "", lambda p: G.grass_tuft(p, blades=16, height=0.17)),
    "tuft_grass_tall": ("tuft", (0.35, 0.35, 0.32), 0.6, 0.0, "", lambda p: G.grass_tuft(p, blades=30, height=0.32)),
    "tuft_daisy": ("tuft", (0.3, 0.3, 0.22), 0.6, 0.0, "", lambda p: G.grass_tuft(p, blades=18, height=0.2, flowers=("white_flower",))),
    "tuft_dandelion": ("tuft", (0.3, 0.3, 0.2), 0.5, 0.0, "", lambda p: G.grass_tuft(p, blades=16, height=0.18, flowers=("gold_flower",))),
}

def materials():
    return G.plant_palette(SC.materials())


def build_plant(pid, M, coll):
    kind, size, weight, col_r, hint, fn = PLANTS[pid]
    # Gefäßrand (Ranken legen sich darüber, nichts steckt in der Wand)
    container = G.CONTAINERS.get(kind) if kind in ("box", "potfill", "basket", "bucket") else None
    if kind == "rim":
        container = G.CONTAINERS["potfill"]
    if isinstance(fn, str):
        container = G.CONTAINERS["pot" if fn.startswith("pot:") else "tub"]
    p = G.Plant(M, coll, seed=sum(ord(c) * (i + 1) for i, c in enumerate(pid)), container=container)
    extra = []
    if isinstance(fn, str) and fn.startswith("pot:"):
        # Topf (Terrakotta) mit Erde, darin die Pflanze
        SC.SPOTS["coll"] = None
        r, h = 0.22, 0.46
        SC.pot(M, coll, "Topf", (0, 0, 0), r, h, 7, mat=p.rnd.choice(("pot", "pot_light", "pot_dark")), style="classic", spot=None)
        top = h * 0.84 + 0.035
        sub = {"bush": lambda q: G.bush(q, 0.22, 0.42, mats=("box_leaf", "leaf_dark")),
               "hydrangea": lambda q: G.hydrangea(q, q.rnd.choice(("blue_flower", "pink")), 1.0),
               "olive": lambda q: G.olive(q, 0.85, 0.26),
               "boxball": lambda q: G.standard_ball(q, 0.48, 0.2),
               "cone": lambda q: G.cone_topiary(q, 0.85, 0.22),
               "citrus": lambda q: G.citrus(q, 0.62, q.rnd.choice(("fruit_lemon", "fruit"))),
               "grass": lambda q: G.grass_tuft(q, blades=70, height=0.62, mats=("grass_leaf", "leaf_blue", "leaf_lime"), plume="peach_flower"),
               "lavender": lambda q: G.lavender_bush(q, spikes=60, height=0.55),
               "rose": lambda q: G.standard_rose(q)}[fn[4:]]
        sub(p)
        objs = p.build(sway_height=None)
        for o in objs:
            o.location.z += top
        return objs
    if isinstance(fn, str) and fn.startswith("tub:"):
        top = G.tub(M, coll, 0.36, 0.5, seed=5)
        G.bay_tree(p)
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
    elif kind == "walltuft":
        b.box((0, 0.1, 0.4), (0.6, 0.2, 0.8), step=1, dent=0.0)        # Hauswand bei y = 0
    elif kind == "bucket":
        b.lathe([(0.0, -0.3), (0.1, -0.3), (0.125, 0.0), (0.0, 0.0)], (0, 0, 0), segs=24)
    elif kind in ("potfill", "basket", "rim"):
        b.lathe([(0.0, -0.4), (0.15, -0.4), (0.21, -0.04), (0.23, 0.0), (0.0, 0.0)], (0, 0, 0), segs=24)
    elif kind == "pot":
        b.box((0, 0.55, 0.5), (1.0, 0.04, 1.0), step=1, dent=0.0)      # Wand 0,32 m dahinter (ungefähr)
    elif kind == "climber":
        b.box((0, 0.02, 2.0), (1.6, 0.04, 4.0), step=1, dent=0.0)       # Wand bei y = 0
    elif kind in ("bed", "hedge", "tree", "tubtree", "tuft"):
        b.box((0, 0, -0.02), (1.0, 1.0, 0.04), step=1, dent=0.0)       # Boden
    b.build()
    os.makedirs(TEMPLATES, exist_ok=True)
    gd = os.path.join(TEMPLATES, ".gdignore")
    if not os.path.exists(gd):
        open(gd, "w").close()
    SC.export_objects(list(coll.objects), [], os.path.join(TEMPLATES, kind + ".glb"), extra=[])


def remove_stale():
    """Pflanzen, die es in PLANTS nicht mehr gibt, entfernen – nur, was dieses Script gebaut hat und
    in Blender nicht bearbeitet wurde (eigene Szenen und Modelle der Entwicklerin bleiben)."""
    for name in sorted(os.listdir(SCENES)):
        pid, ext = os.path.splitext(name)
        if ext != ".tscn" or pid in PLANTS:
            continue
        path = os.path.join(SCENES, name)
        if "build_storybook_plants.py" not in open(path).read():
            continue
        blend, stamp = os.path.join(SRC, pid + ".blend"), os.path.join(SRC, pid + ".stamp")
        if SC.edited_by_hand(blend, stamp):
            continue
        for f in (path, os.path.join(OUT, pid + ".glb"), os.path.join(OUT, pid + ".glb.import"), blend, stamp):
            if os.path.exists(f):
                os.remove(f)
        print("entfernt (nicht mehr in PLANTS): %s" % pid)


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
        remove_stale()
    print("Fertig: zusammen %d Dreiecke" % total)


if __name__ == "__main__":
    main()
