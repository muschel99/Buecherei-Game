"""Gleichmäßiges Dreiecksnetz für die Chibi-Figuren (seit Etappe 5c): "isotropes Remeshing" nach
Botsch & Kobbelt. Lange Kanten teilen, kurze zusammenlegen, Kanten umklappen (jede Ecke möglichst
6 Nachbarn), Ecken gleichmäßig verteilen und zurück auf die Oberfläche des Feldes setzen.

Warum: Ausdünnen erzeugt lange, dünne Dreiecke. Deren flache Flächen weichen stark von der
glatten Rundung ab; Programme wie Mixamo werfen dort Schatten auf die Figur selbst (dunkle
Flecken), und beim Biegen der Gelenke knicken sie zu Ecken.

Die Kantenlänge passt sich an: dünne Teile (Finger, Ohren) feiner, Gelenke feiner, sonst gröber.
"""

import math

import bmesh
import numpy as np

import chibi_sdf as S


def local_radius(node, p, n, steps=40, depth=0.08):
    """Wie dick ist der Körper an dieser Stelle? (größte Tiefe im Inneren entlang der Normalen)"""
    best = np.zeros(len(p))
    for t in np.linspace(0.002, depth, steps):
        d = node.eval_points(p - n * t)
        best = np.maximum(best, -d)
    return best


def length_field(node, zones, base, finest, zone_length, samples, cell=0.01):
    """Liefert L(p): gewünschte Kantenlänge je Punkt. Einmal an den Punkten samples (auf der
    Oberfläche) berechnet und in ein Raster (cell) eingetragen; danach nur noch nachschlagen."""
    n = S.normals(node, samples)
    r = local_radius(node, samples, n)
    val = np.clip(0.5 * r, finest, base)
    for zone in zones:
        c, rad = zone[0], zone[1]
        zl = zone[2] if len(zone) > 2 else zone_length      # eigene Kantenlänge (Details)
        dist = np.linalg.norm(samples - np.asarray(c), axis=1)
        w = np.clip(1.0 - (dist - rad) / rad, 0.0, 1.0)     # innen 1, weich auslaufend
        val = np.minimum(val, zl + (base - zl) * (1.0 - w))
    keys = np.floor(samples / cell).astype(np.int64)
    table = {}
    for k, v in zip(map(tuple, keys), val):
        table[k] = min(table.get(k, base), v)
    # Nachbarzellen mitnehmen (Werte weich und ohne Lücken)
    grid = {}
    for (i, j, k), v in table.items():
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                for dk in (-1, 0, 1):
                    key = (i + di, j + dj, k + dk)
                    grid[key] = min(grid.get(key, base), v)

    def L(p):
        ks = np.floor(np.asarray(p) / cell).astype(np.int64)
        return np.array([grid.get(tuple(k), base) for k in ks])
    return L


def _coords(bm):
    return np.array([v.co[:] for v in bm.verts])


def _split_long(bm, L):
    bm.edges.ensure_lookup_table()
    mids = np.array([((e.verts[0].co + e.verts[1].co) / 2)[:] for e in bm.edges])
    lens = np.array([e.calc_length() for e in bm.edges])
    want = L(mids)
    long_edges = [e for e, ln, w in zip(bm.edges, lens, want) if ln > 4.0 / 3.0 * w]
    if long_edges:
        bmesh.ops.subdivide_edges(bm, edges=long_edges, cuts=1, use_grid_fill=False)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    return len(long_edges)


def _collapse_short(bm, L):
    bm.edges.ensure_lookup_table()
    mids = np.array([((e.verts[0].co + e.verts[1].co) / 2)[:] for e in bm.edges])
    lens = np.array([e.calc_length() for e in bm.edges])
    want = L(mids)
    order = np.argsort(lens / want)
    used = set()
    todo = []
    edges = list(bm.edges)
    for i in order:
        if lens[i] >= 0.8 * want[i]:
            break
        e = edges[i]
        a, b = e.verts
        if a.index in used or b.index in used:
            continue
        na = {x.other_vert(a) for x in a.link_edges}
        nb = {x.other_vert(b) for x in b.link_edges}
        # Verbindungsbedingung: genau zwei gemeinsame Nachbarn (sonst entsteht ein Loch/Knick)
        if len(na & nb) != 2 or len(a.link_edges) < 4 or len(b.link_edges) < 4:
            continue
        mid = (a.co + b.co) / 2
        if any((x.co - mid).length > 4.0 / 3.0 * want[i] for x in (na | nb) - {a, b}):
            continue
        todo.append(e)
        used.update(x.index for x in na | nb)
        used.update((a.index, b.index))
    if todo:
        bmesh.ops.collapse(bm, edges=todo, uvs=False)
    return len(todo)


def _flip_edges(bm):
    flips = 0
    bm.verts.index_update()
    for e in list(bm.edges):
        if not e.is_valid or len(e.link_faces) != 2:
            continue
        a, b = e.verts
        f1, f2 = e.link_faces
        c = [v for v in f1.verts if v not in (a, b)]
        d = [v for v in f2.verts if v not in (a, b)]
        if len(c) != 1 or len(d) != 1:
            continue
        c, d = c[0], d[0]
        if c in {x.other_vert(d) for x in d.link_edges}:
            continue

        def dev(v, delta):
            return abs(len(v.link_edges) + delta - 6)

        before = dev(a, 0) + dev(b, 0) + dev(c, 0) + dev(d, 0)
        after = dev(a, -1) + dev(b, -1) + dev(c, 1) + dev(d, 1)
        if after >= before:
            continue
        # nicht umklappen, wenn die neuen Dreiecke umkippen würden
        n_old = (f1.normal + f2.normal).normalized()
        n1 = (c.co - a.co).cross(d.co - a.co)
        n2 = (d.co - b.co).cross(c.co - b.co)
        if n1.length < 1e-12 or n2.length < 1e-12:
            continue
        if abs(n1.normalized().dot(n_old)) < 0.5 or abs(n2.normalized().dot(n_old)) < 0.5:
            continue
        res = bmesh.ops.rotate_edges(bm, edges=[e], use_ccw=False)
        if res["edges"]:
            flips += 1
            for f in res["edges"][0].link_faces:
                f.normal_update()
    return flips


def _relax(bm, node, strength=0.5):
    """Tangentiales Glätten: jede Ecke ein Stück zur Mitte ihrer Nachbarn (nur entlang der
    Oberfläche), dann zurück auf die Oberfläche."""
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    p = _coords(bm)
    acc = np.zeros_like(p)
    cnt = np.zeros(len(p))
    for e in bm.edges:
        i, j = e.verts[0].index, e.verts[1].index
        acc[i] += p[j]
        acc[j] += p[i]
        cnt[i] += 1
        cnt[j] += 1
    c = acc / np.maximum(cnt, 1)[:, None]
    n = S.normals(node, p)
    move = c - p
    move -= (move * n).sum(1)[:, None] * n
    p = S.project(node, p + strength * move, 4)
    for v, q in zip(bm.verts, p):
        v.co = q


def remesh(obj, node, L, iterations=6):
    """Netz von obj gleichmäßig machen (auf der Oberfläche von node)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for it in range(iterations):
        s = _split_long(bm, L)
        c = _collapse_short(bm, L)
        bm.normal_update()
        f = _flip_edges(bm)
        for _ in range(2):
            _relax(bm, node)
        bm.normal_update()
        print(f"  Remesh {it + 1}: {s} geteilt, {c} zusammengelegt, {f} umgeklappt, {len(bm.faces)} Dreiecke")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
