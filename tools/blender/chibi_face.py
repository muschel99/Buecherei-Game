"""Gezeichnete Chibi-Gesichter (seit Etappe 5c): Augen, Iris, Augenbrauen und Münder als Bilder-
Atlanten (je Feld ein Ausdruck). In Godot setzt der Shader chibi_face.gdshader das Gesicht aus
den Atlanten zusammen (Ausdruck, Blickrichtung, Blinzeln, Wangenröte als Instanz-Werte);
compose() macht hier dasselbe in numpy (Kontrollbilder in Blender, Standard-Gesicht im .glb).

Reines numpy. Längen in Metern im Gesicht: fx = Bogenlänge quer über das Gesicht (+ = linke
Gesichtshälfte der Figur, vom Betrachter aus rechts), fz = Höhe über dem Kinn.
Linien sind gespiegelt (außen = Augenwinkel außen), die Iris nicht (Glanzpunkte für beide Augen
auf derselben Seite).
"""

import math
import os
import struct
import zlib

import numpy as np

# --- Lage im Gesicht (m) – muss zu chibi_face.gdshader passen -------------------------------
FACE_SIZE = 0.48          # UV 0..1 entspricht 0,48 m
FACE_RADIUS = 0.21        # Radius der Zylinder-Abwicklung (Kopfmitte)
FACE_AXIS_Y = 0.0138      # Kopfachse (y) für die Abwicklung
EYE_X, EYE_Z = 0.089, 0.146
EYE_CELL = 0.085          # Größe eines Feldes im Atlas (Zeichnung in m)
IRIS_CELL = 0.05
EYE_SCALE = 2.05          # Augen im Gesicht so viel größer als gezeichnet
BROW_X, BROW_Z = 0.088, 0.232
BROW_CELL = (0.07, 0.035)
BROW_SCALE = 1.5
MOUTH_Z = 0.068
MOUTH_CELL = 0.06
MOUTH_SCALE = 2.6
BLUSH_X, BLUSH_Z = 0.112, 0.098
BLUSH_R = (0.034, 0.019)

CELL_PX = 256
LINE = (0.16, 0.10, 0.10)
LINE_SOFT = (0.36, 0.24, 0.22)

EYE_FRAMES = ["open", "half", "closed", "happy", "wide", "sad", "angry", "soft", "annoyed", "squeeze", "cry",
              "teary"]
IRIS_FRAMES = ["normal", "heart", "sparkle", "spiral", "small", "star"]
BROW_FRAMES = ["neutral", "raised", "worried", "angry", "sad", "flat", "focused", "relaxed"]
MOUTH_FRAMES = ["smile", "smile_wide", "open_smile", "laugh", "o", "O", "flat", "frown",
                "cat", "wavy", "sad_open", "smirk", "talk_a", "talk_e", "talk_o", "pout",
                "grin", "bleh", "shout", "triangle"]


# ---------------------------------------------------------------------------------------------
# Zeichnen mit Abstandsfeldern (weiche Kanten)
# ---------------------------------------------------------------------------------------------

class Layer:
    def __init__(self, w, h, size_x, size_y):
        self.w, self.h = w, h
        self.px = size_x / w
        xs = (np.arange(w) + 0.5) / w * size_x - size_x / 2
        ys = size_y / 2 - (np.arange(h) + 0.5) / h * size_y
        self.X, self.Y = np.meshgrid(xs, ys)
        self.rgb = np.zeros((h, w, 3))
        self.a = np.zeros((h, w))

    def cov(self, d, soft=1.0):
        return np.clip(0.5 - d / (self.px * soft), 0.0, 1.0)

    def paint(self, d, color, alpha=1.0, soft=1.0):
        c = self.cov(d, soft) * alpha
        self.rgb = self.rgb * (1 - c[..., None]) + np.array(color)[None, None, :] * c[..., None]
        self.a = self.a * (1 - c) + c

    def rgba(self):
        out = np.zeros((self.h, self.w, 4))
        out[..., :3] = self.rgb / np.maximum(self.a, 1e-6)[..., None]
        out[..., 3] = self.a
        return out


def sd_ellipse(X, Y, cx, cy, rx, ry, rot=0.0):
    dx, dy = X - cx, Y - cy
    if rot:
        c, s = math.cos(rot), math.sin(rot)
        dx, dy = c * dx + s * dy, -s * dx + c * dy
    k0 = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
    k1 = np.sqrt((dx / (rx * rx)) ** 2 + (dy / (ry * ry)) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sd_stroke(X, Y, pts, widths):
    """Linie durch pts mit Breite je Punkt (spitz zulaufend möglich), runde Enden."""
    pts = np.asarray(pts, float)
    widths = np.asarray(widths, float)
    best = np.full(X.shape, 1.0)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        l2 = max(float(ab @ ab), 1e-12)
        t = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / l2, 0.0, 1.0)
        dx = X - (a[0] + ab[0] * t)
        dy = Y - (a[1] + ab[1] * t)
        w = widths[i] + (widths[i + 1] - widths[i]) * t
        best = np.minimum(best, np.sqrt(dx * dx + dy * dy) - w * 0.5)
    return best


def sd_poly(X, Y, pts):
    """Gefülltes Vieleck (gerade-ungerade Regel), negativ innen."""
    pts = np.asarray(pts, float)
    n = len(pts)
    dist = np.full(X.shape, 1.0)
    inside = np.zeros(X.shape, bool)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        ab = b - a
        l2 = max(float(ab @ ab), 1e-12)
        t = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / l2, 0.0, 1.0)
        dx = X - (a[0] + ab[0] * t)
        dy = Y - (a[1] + ab[1] * t)
        dist = np.minimum(dist, np.sqrt(dx * dx + dy * dy))
        cond = ((a[1] > Y) != (b[1] > Y)) & (X < (b[0] - a[0]) * (Y - a[1]) / np.where(b[1] - a[1] == 0, 1e-12, b[1] - a[1]) + a[0])
        inside ^= cond
    return np.where(inside, -dist, dist)


def bezier(p0, p1, p2, p3, n=24):
    t = np.linspace(0.0, 1.0, n)[:, None]
    p0, p1, p2, p3 = (np.asarray(p, float) for p in (p0, p1, p2, p3))
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3


def taper(n, w0, w1, w2=None, mid=0.5):
    """Breiten entlang einer Linie: w0 am Anfang, w1 in der Mitte (bzw. am Ende), w2 am Ende."""
    t = np.linspace(0.0, 1.0, n)
    if w2 is None:
        return w0 + (w1 - w0) * t
    return np.where(t < mid, w0 + (w1 - w0) * (t / mid), w1 + (w2 - w1) * ((t - mid) / (1 - mid)))


# ---------------------------------------------------------------------------------------------
# Augen (Linien + Maske), Koordinaten: x nach außen, y nach oben, Mitte des Auges = 0
# ---------------------------------------------------------------------------------------------

EYE_RX, EYE_RY = 0.0205, 0.0275
EYE_CELL_PX = 192         # Augen-Atlas: 12 Ausdrücke × 6 Sätze (Frau/Mann × 3 Augenformen)

# Augenformen im Manga-Stil: Innen- und Außenwinkel, Kontrollpunkte der oberen und unteren
# Lidlinie (Bezier), Stärke der Lidlinie, Schwung außen, Iris (Größe, Höhe)
EYE_SHAPES = {
    "female": {
        # süß: groß und breit, große Iris (wie die meisten Vorlagen)
        "sweet": dict(inner=(-0.023, -0.006), outer=(0.024, -0.004), top=((-0.020, 0.026), (0.017, 0.029)),
                      bottom=((0.020, -0.028), (-0.018, -0.028)), line=0.0052, wing=(0.0045, 0.0020),
                      iris=(1.20, -0.003)),
        # elegant: mandelförmig, Außenwinkel mit Schwung nach oben
        "elegant": dict(inner=(-0.023, -0.004), outer=(0.025, 0.006), top=((-0.016, 0.020), (0.013, 0.025)),
                        bottom=((0.019, -0.021), (-0.015, -0.022)), line=0.0052, wing=(0.0080, 0.0045),
                        iris=(1.05, -0.002)),
        # lebhaft: groß und hoch, rund oben
        "lively": dict(inner=(-0.021, -0.003), outer=(0.022, -0.002), top=((-0.020, 0.032), (0.017, 0.034)),
                       bottom=((0.019, -0.029), (-0.017, -0.029)), line=0.0050, wing=(0.0050, 0.0020),
                       iris=(1.17, -0.001)),
    },
    "male": {
        # sanft: groß, oben weich gebogen, Außenwinkel leicht hängend
        "gentle": dict(inner=(-0.022, -0.004), outer=(0.023, -0.007), top=((-0.017, 0.022), (0.013, 0.025)),
                       bottom=((0.018, -0.025), (-0.016, -0.024)), line=0.0048, wing=(0.0012, -0.0004),
                       iris=(1.06, -0.002)),
        # cool: schmal, Oberlid fast gerade und nach außen ansteigend, Iris halb unter dem Lid
        "cool": dict(inner=(-0.022, -0.003), outer=(0.024, 0.006), top=((-0.014, 0.012), (0.010, 0.017)),
                     bottom=((0.018, -0.017), (-0.013, -0.018)), line=0.0052, wing=(0.0012, 0.0),
                     iris=(0.96, -0.004)),
        # fröhlich: groß und hoch, kräftiger runder Bogen
        "bright": dict(inner=(-0.020, -0.002), outer=(0.021, -0.002), top=((-0.019, 0.028), (0.015, 0.031)),
                       bottom=((0.018, -0.027), (-0.016, -0.026)), line=0.0050, wing=(0.0012, 0.0),
                       iris=(1.10, -0.002)),
    },
}
SHAPE_NAMES = {g: list(v) for g, v in EYE_SHAPES.items()}
TEAR = (0.55, 0.76, 0.96)


def _curves(gender, shape, ys=1.0):
    """Obere (innen → außen) und untere (außen → innen) Lidlinie als Punkte."""
    sh = EYE_SHAPES[gender][shape]
    sc = np.array((1.0, ys))
    a, b = np.array(sh["inner"]) * sc, np.array(sh["outer"]) * sc
    t1, t2 = (np.array(p) * sc for p in sh["top"])
    b1, b2 = (np.array(p) * sc for p in sh["bottom"])
    return bezier(a, t1, t2, b, 48), bezier(b, b1, b2, a, 48)


def _curve_y(curve, x):
    """y der Linie an den Stellen x (Punkte nach x sortiert)."""
    order = np.argsort(curve[:, 0])
    return np.interp(x, curve[order, 0], curve[order, 1])


def _lid_clip(frame, upper, lower):
    """Zusätzliche Begrenzung der Öffnung je Ausdruck: (Oberlid(x), Unterlid(x)) oder None."""
    lo = lambda x: _curve_y(lower, x)           # noqa: E731
    up = lambda x: _curve_y(upper, x)           # noqa: E731
    x0, x1 = upper[0, 0], upper[-1, 0]
    t = lambda x: np.clip((x - x0) / (x1 - x0), 0, 1)   # noqa: E731  0 innen, 1 außen
    if frame == "half":
        return (lambda x: lo(x) + 0.42 * (up(x) - lo(x))), None
    if frame == "annoyed":
        return (lambda x: lo(x) + 0.5 * (up(x) - lo(x)) * (0.75 + 0.25 * t(x))), None
    if frame == "sad":
        return (lambda x: up(x) - (up(x) - lo(x)) * 0.42 * t(x)), None
    if frame == "angry":
        return (lambda x: up(x) - (up(x) - lo(x)) * 0.48 * (1 - t(x))), None
    if frame == "soft":
        return None, (lambda x: lo(x) + (up(x) - lo(x)) * 0.36 * np.sin(np.pi * t(x)) ** 0.7)
    return None, None


def _lashes(lay, line_pts, fem, lw):
    """Schmuckwimpern (Frauen) am äußeren Ende der Oberlidlinie."""
    if not fem:
        return
    n = len(line_pts)
    for i, (k, ang, ln, w0) in enumerate(((0.62, 72.0, 0.0050, 0.0013), (0.74, 55.0, 0.0064, 0.0015),
                                          (0.85, 36.0, 0.0076, 0.0017), (0.95, 16.0, 0.0080, 0.0018))):
        base = line_pts[min(int(k * (n - 1)), n - 1)]
        a = math.radians(ang)
        tip = base + np.array((math.cos(a), math.sin(a))) * ln
        c1 = base + np.array((math.cos(a + 0.5), math.sin(a + 0.5))) * ln * 0.45
        c2 = tip - np.array((math.cos(a - 0.35), math.sin(a - 0.35))) * ln * 0.3
        lp = bezier(base, c1, c2, tip, 12)
        lay.paint(sd_stroke(lay.X, lay.Y, lp, taper(len(lp), w0, 0.0)), LINE)


def _tears(lay, start, length=0.024):
    """Tränenbach von start nach unten, mit Tropfen."""
    X, Y = lay.X, lay.Y
    pts = bezier(start, start + np.array((0.002, -length * 0.4)), start + np.array((0.001, -length * 0.75)),
                 start + np.array((0.0025, -length)), 16)
    lay.paint(sd_stroke(X, Y, pts, taper(len(pts), 0.0018, 0.0034, 0.0026, 0.6)), TEAR, 0.85)
    lay.paint(sd_ellipse(X, Y, start[0] + 0.0035, start[1] - length - 0.004, 0.0026, 0.0034), TEAR, 0.9)


def draw_eye(frame, gender, shape):
    """Ein Auge (Linien RGBA + Maske: R = Öffnung, G = Lidschatten), x nach außen."""
    lay = Layer(EYE_CELL_PX, EYE_CELL_PX, EYE_CELL, EYE_CELL)
    mask = np.zeros((EYE_CELL_PX, EYE_CELL_PX, 4))
    X, Y = lay.X, lay.Y
    fem = gender == "female"
    sh = EYE_SHAPES[gender][shape]
    upper, lower = _curves(gender, shape, 1.1 if frame == "wide" else 1.0)
    if frame == "wide":
        upper = upper * np.array((1.06, 1.0))
        lower = lower * np.array((1.06, 1.0))
    lw = sh["line"]
    inner, outer = upper[0], upper[-1]
    wing = np.array(sh["wing"])
    if frame in ("closed", "happy", "squeeze", "cry"):
        w = outer[0] - inner[0]
        cx = (outer[0] + inner[0]) / 2
        cy = (outer[1] + inner[1]) / 2 - 0.002
        if frame in ("closed", "cry"):
            pts = bezier((inner[0], cy + 0.002), (cx - w * 0.2, cy - 0.010), (cx + w * 0.25, cy - 0.010),
                         (outer[0] + wing[0] * 0.6, cy + 0.001), 32)
            lash_dir = -1
        elif frame == "happy":
            pts = bezier((inner[0], cy - 0.006), (cx - w * 0.25, cy + 0.011), (cx + w * 0.25, cy + 0.011),
                         (outer[0] + wing[0] * 0.5, cy - 0.005), 32)
            lash_dir = 1
        else:
            # zusammengekniffen ">": Spitze zur Nase
            a = np.array((outer[0], cy + 0.010))
            m = np.array((inner[0] + 0.004, cy))
            b = np.array((outer[0], cy - 0.010))
            for p, q in ((a, m), (m, b)):
                seg = np.linspace(p, q, 12)
                lay.paint(sd_stroke(X, Y, seg, taper(len(seg), 0.0040, 0.0030)), LINE)
            return lay.rgba(), mask
        lay.paint(sd_stroke(X, Y, pts, taper(len(pts), 0.0014, lw * 0.85, lw, 0.6)), LINE)
        if fem:
            for i, (k, ang, ln) in enumerate(((0.95, 8.0, 0.0060), (0.85, -18.0, 0.0064), (0.74, -42.0, 0.0054))):
                base = pts[int(k * (len(pts) - 1))]
                a = math.radians(ang * lash_dir)
                tip = base + np.array((math.cos(a), math.sin(a))) * ln
                ctrl = base + (tip - base) * 0.45 + np.array((0.0, lash_dir * 0.0015))
                lp = bezier(base, ctrl, ctrl, tip, 10)
                lay.paint(sd_stroke(X, Y, lp, taper(len(lp), 0.0016, 0.0)), LINE)
        if frame == "cry":
            _tears(lay, np.array((cx + w * 0.18, cy - 0.008)))
        return lay.rgba(), mask
    # Öffnung
    poly = np.concatenate([upper, lower[1:-1]])
    d_open = sd_poly(X, Y, poly)
    top, bottom = _lid_clip(frame, upper, lower)
    if top is not None:
        d_open = np.maximum(d_open, Y - top(X))
    if bottom is not None:
        d_open = np.maximum(d_open, bottom(X) - Y)
    mask[..., 0] = lay.cov(d_open)
    up_y = _curve_y(upper, X) if top is None else np.minimum(_curve_y(upper, X), top(X))
    mask[..., 1] = np.clip(1.0 - (up_y - Y) / 0.010, 0.0, 1.0) * mask[..., 0]
    mask[..., 3] = 1.0
    # Oberlidlinie entlang der sichtbaren oberen Grenze, außen dick, mit Schwung
    xs = upper[:, 0]
    yl = upper[:, 1] if top is None else np.minimum(upper[:, 1], top(xs))
    keep = yl > _curve_y(lower, xs) + 0.0005
    line = np.stack([xs[keep], yl[keep]], axis=1) + np.array((0.0, lw * 0.25))
    if len(line) < 3:
        return lay.rgba(), mask
    tail_end = line[-1] + wing
    tail = bezier(line[-1], line[-1] + wing * 0.4, tail_end - wing * 0.2, tail_end, 10)[1:]
    path = np.concatenate([line, tail])
    widths = np.concatenate([taper(len(line), lw * 0.35, lw * 0.85, lw, 0.55), taper(len(tail), lw * 0.95, 0.0004)])
    lay.paint(sd_stroke(X, Y, path, widths), LINE)
    _lashes(lay, line, fem, lw)
    # Unterlid: kurzer Strich außen
    if bottom is None:
        lowp = lower[2:20]
    else:
        lx = np.linspace(outer[0] * 0.95, outer[0] * 0.2, 16)
        lowp = np.stack([lx, bottom(lx) - 0.0004], axis=1)
    lay.paint(sd_stroke(X, Y, lowp, taper(len(lowp), lw * 0.45, 0.0)), LINE_SOFT if bottom is None else LINE, 0.95)
    if fem and bottom is None:
        for k, ang, ln in ((0.12, -40.0, 0.0030), (0.28, -62.0, 0.0024)):
            base = lower[int(k * (len(lower) - 1))]
            a = math.radians(ang)
            tip = base + np.array((math.cos(a), math.sin(a))) * ln
            lay.paint(sd_stroke(X, Y, np.linspace(base, tip, 6), taper(6, 0.0010, 0.0)), LINE_SOFT)
    if frame == "teary":
        # nasser Rand unten und ein Tropfen außen
        wet = lower[4:44] + np.array((0.0, 0.0018))
        lay.paint(sd_stroke(X, Y, wet, taper(len(wet), 0.0006, 0.0020, 0.0006)), TEAR, 0.75)
        lay.paint(sd_ellipse(X, Y, outer[0] - 0.002, outer[1] - 0.006, 0.0022, 0.0030), TEAR, 0.85)
    return lay.rgba(), mask


# ---------------------------------------------------------------------------------------------
# Iris: R = Helligkeit (oben dunkel), G = Glanzlicht, B = dunkle Linien/Pupille, A = Iris
# ---------------------------------------------------------------------------------------------

IRIS_RX, IRIS_RY = 0.0160, 0.0215


def _heart(X, Y, cx, cy, s):
    """Herz (Abstandsfeld nach Inigo Quilez), Spitze unten, Größe s (Höhe ≈ 1,1 s)."""
    x = np.abs(X - cx) / s
    y = (Y - cy) / s + 0.55
    upper = np.sqrt((x - 0.25) ** 2 + (y - 0.75) ** 2) - math.sqrt(2) / 4
    m = np.maximum(x + y, 0.0) * 0.5
    lower = np.sqrt(np.minimum(x * x + (y - 1.0) ** 2, (x - m) ** 2 + (y - m) ** 2)) * np.sign(x - y)
    return np.where(y + x > 1.0, upper, lower) * s


def _star(X, Y, cx, cy, r, thin=0.18):
    """Vierzackiger Glitzerstern."""
    dx, dy = np.abs(X - cx), np.abs(Y - cy)
    k = (dx / r) ** 0.5 + (dy / r) ** 0.5
    return (k - 1.0) * r * thin * 2


def draw_iris(frame, gender="female"):
    lay = Layer(CELL_PX, CELL_PX, IRIS_CELL, IRIS_CELL)
    X, Y = lay.X, lay.Y
    out = np.zeros((CELL_PX, CELL_PX, 4))
    irx, iry = IRIS_RX, IRIS_RY
    vinyl = False
    d = sd_ellipse(X, Y, 0, 0, irx, iry)
    cov = lay.cov(d)
    k0 = np.sqrt((X / irx) ** 2 + (Y / iry) ** 2)
    shade = 0.28 + 0.72 * np.clip((iry * 0.35 - Y) / (iry * 1.2), 0.0, 1.0) ** 0.8
    shade *= 1.0 - 0.45 * np.clip((k0 - 0.72) / 0.28, 0.0, 1.0)
    # heller Bogen unten
    shade += 0.25 * np.clip(1 - np.abs(k0 - 0.68) / 0.12, 0, 1) * np.clip(-Y / iry, 0, 1)
    out[..., 0] = np.clip(shade, 0.0, 1.0)
    dark = lay.cov(np.abs(d + 0.0006) - 0.0006) * 0.9            # Rand der Iris
    ang = np.arctan2(Y, X)
    streak = (0.5 + 0.5 * np.cos(ang * 22.0)) * np.clip((k0 - 0.45) / 0.4, 0, 1) * np.clip((0.95 - k0) / 0.2, 0, 1)
    dark = np.maximum(dark, 0.18 * streak * (Y < iry * 0.2) * (0.0 if vinyl else 1.0))
    if vinyl:
        # Knopfauge: dunkel, weicher Verlauf, nur ein feiner Rand
        out[..., 0] = np.clip(0.15 + 0.55 * np.clip(-Y / iry, 0, 1) ** 1.5, 0, 1)
        dark = lay.cov(np.abs(d + 0.0004) - 0.0004) * 0.5
    hi = np.zeros_like(X)
    if frame == "small":
        # erschrocken: nur ein kleiner Punkt mit Glanz
        cov = lay.cov(sd_ellipse(X, Y, 0, -0.001, 0.0062, 0.0080))
        out[..., 0] = 0.25
        dark = cov * 0.9
        hi = lay.cov(sd_ellipse(X, Y, -0.0018, 0.0022, 0.0016, 0.0018))
        out[..., 1] = hi * cov
        out[..., 2] = dark * cov
        out[..., 3] = cov
        return out
    if frame == "heart":
        dark = np.maximum(dark, lay.cov(_heart(X, Y, 0.0, -0.001, 0.0135)) * 0.95)
        hi = np.maximum(hi, lay.cov(_heart(X, Y, -0.0062, 0.0085, 0.0062)))
        hi = np.maximum(hi, lay.cov(sd_ellipse(X, Y, 0.0068, -0.0095, 0.0018, 0.0018)))
    elif frame == "spiral":
        r = np.sqrt(X * X + Y * Y)
        sp = np.abs(((r / 0.0042 - ang / (2 * math.pi)) % 1.0) - 0.5) * 0.0042 - 0.0007
        dark = np.maximum(dark, lay.cov(sp) * (r < irx * 0.95))
    else:
        if not vinyl:
            dark = np.maximum(dark, lay.cov(sd_ellipse(X, Y, 0.0, -0.0008, 0.0066, 0.0094)) * 0.95)
        hi = np.maximum(hi, lay.cov(sd_ellipse(X, Y, -0.0060, 0.0085, 0.0054, 0.0062, rot=0.35)))
        hi = np.maximum(hi, lay.cov(sd_ellipse(X, Y, 0.0068, -0.0092, 0.0021, 0.0021)))
        hi = np.maximum(hi, 0.8 * lay.cov(sd_ellipse(X, Y, 0.0030, 0.0098, 0.0011, 0.0011)))
        if frame == "star":
            hi = np.maximum(hi, lay.cov(_star(X, Y, 0.0, -0.001, 0.0080, 0.22)))
        if frame == "sparkle":
            hi = np.maximum(hi, lay.cov(_star(X, Y, 0.0055, 0.0035, 0.0055)))
            hi = np.maximum(hi, lay.cov(_star(X, Y, -0.0048, -0.0072, 0.0035)))
    if gender == "male" and frame in ("normal", "sparkle", "star"):
        # Männer: nur ein kleiner, gedämpfter Glanzpunkt (sonst wirkt es zu weiblich)
        hi = 0.7 * lay.cov(sd_ellipse(X, Y, -0.0050, 0.0072, 0.0026, 0.0028))
        if frame == "star":
            hi = np.maximum(hi, 0.8 * lay.cov(_star(X, Y, 0.0, -0.001, 0.0060, 0.22)))
    out[..., 1] = hi * cov
    out[..., 2] = dark * cov
    out[..., 3] = cov
    return out


# ---------------------------------------------------------------------------------------------
# Augenbrauen (A = Deckkraft; Farbe kommt aus dem Shader), x nach außen
# ---------------------------------------------------------------------------------------------

def draw_brow(frame, gender="female"):
    w, h = BROW_CELL
    male = gender == "male"
    lay = Layer(CELL_PX, CELL_PX // 2, w, h)
    inner_y, mid_y, outer_y, lift = {
        "neutral": (0.0, 0.0035, -0.0015, 0.0),
        "raised": (0.0015, 0.0055, 0.0, 0.003),
        "worried": (0.0055, 0.002, -0.0035, 0.0),
        "angry": (-0.0050, 0.0005, 0.0035, 0.0),
        "sad": (0.0040, 0.0025, -0.0045, 0.0),
        "flat": (0.0, 0.001, 0.0, 0.0),
        "focused": (-0.0025, 0.0015, 0.001, 0.0),
        "relaxed": (-0.0005, 0.0025, -0.0025, -0.001),
    }[frame]
    p0 = (-0.019, inner_y + lift)
    p3 = (0.021, outer_y + lift)
    p1 = (-0.007, mid_y + 0.0015 + lift)
    p2 = (0.010, mid_y + 0.0012 + lift)
    if male:
        # Männer: kräftig und gerade
        p1 = (p1[0], p1[1] - 0.0018)
        p2 = (p2[0], p2[1] - 0.0018)
    pts = bezier(p0, p1, p2, p3, 28)
    t = 2.0 if male else 1.0
    lay.paint(sd_stroke(lay.X, lay.Y, pts, taper(len(pts), 0.0036 * t, 0.0031 * t, 0.0012 * t, 0.35)), (1, 1, 1))
    return lay.rgba()


# ---------------------------------------------------------------------------------------------
# Münder (farbig), Mitte = 0
# ---------------------------------------------------------------------------------------------

MOUTH_INSIDE = (0.50, 0.17, 0.19)
TONGUE = (0.93, 0.52, 0.52)
TEETH = (0.99, 0.97, 0.93)


def _open_mouth(lay, top_pts, bottom_pts, tongue=True, teeth=False, line=0.0016):
    X, Y = lay.X, lay.Y
    poly = np.concatenate([top_pts, bottom_pts[::-1]])
    d = sd_poly(X, Y, poly)
    lay.paint(d, MOUTH_INSIDE)
    if tongue:
        lo = bottom_pts[:, 1].min()
        cx = bottom_pts[:, 0].mean()
        width = (bottom_pts[:, 0].max() - bottom_pts[:, 0].min()) * 0.32
        t = sd_ellipse(X, Y, cx, lo + 0.0005, width, (top_pts[:, 1].max() - lo) * 0.42)
        lay.paint(np.maximum(t, d), TONGUE)
    if teeth:
        hi = top_pts[:, 1].max()
        lay.paint(np.maximum(d, -(Y - (hi - 0.0028))), TEETH)
    lay.paint(np.abs(d) - line * 0.5, LINE)


def draw_mouth(frame):
    lay = Layer(CELL_PX, CELL_PX, MOUTH_CELL, MOUTH_CELL)
    X, Y = lay.X, lay.Y
    lw = 0.0026

    def line(pts, w0=0.0016, w1=lw, w2=0.0016):
        lay.paint(sd_stroke(X, Y, pts, taper(len(pts), w0, w1, w2, 0.5)), LINE)

    if frame == "smile":
        line(bezier((-0.0105, 0.0024), (-0.0045, -0.0034), (0.0045, -0.0034), (0.0105, 0.0024)))
    elif frame == "smile_wide":
        line(bezier((-0.0145, 0.0034), (-0.0065, -0.0048), (0.0065, -0.0048), (0.0145, 0.0034)))
    elif frame == "open_smile":
        top = bezier((-0.010, 0.002), (-0.004, 0.0005), (0.004, 0.0005), (0.010, 0.002), 16)
        bot = bezier((-0.010, 0.002), (-0.007, -0.010), (0.007, -0.010), (0.010, 0.002), 16)
        _open_mouth(lay, top, bot)
    elif frame == "laugh":
        top = bezier((-0.0145, 0.0035), (-0.006, 0.0015), (0.006, 0.0015), (0.0145, 0.0035), 16)
        bot = bezier((-0.0145, 0.0035), (-0.011, -0.016), (0.011, -0.016), (0.0145, 0.0035), 16)
        _open_mouth(lay, top, bot, teeth=True)
    elif frame == "o":
        d = sd_ellipse(X, Y, 0, -0.001, 0.0045, 0.0058)
        lay.paint(d, MOUTH_INSIDE)
        lay.paint(np.abs(d) - 0.0008, LINE)
    elif frame == "O":
        d = sd_ellipse(X, Y, 0, -0.002, 0.0078, 0.0105)
        lay.paint(d, MOUTH_INSIDE)
        lay.paint(np.maximum(sd_ellipse(X, Y, 0, -0.0095, 0.0045, 0.0035), d), TONGUE)
        lay.paint(np.abs(d) - 0.0008, LINE)
    elif frame == "flat":
        line(np.array([(-0.0075, 0.0), (0.0075, 0.0)]))
    elif frame == "frown":
        line(bezier((-0.008, -0.0025), (-0.004, 0.0018), (0.004, 0.0018), (0.008, -0.0025)))
    elif frame == "cat":
        a = bezier((0.0, 0.001), (-0.001, -0.004), (-0.007, -0.004), (-0.0085, 0.0015), 14)
        b = a * np.array((-1, 1))
        line(a, 0.0014, lw, 0.0008)
        line(b, 0.0014, lw, 0.0008)
    elif frame == "wavy":
        xs = np.linspace(-0.0105, 0.0105, 40)
        line(np.stack([xs, 0.0016 * np.sin(xs / 0.0105 * 2.5 * math.pi)], axis=1))
    elif frame == "sad_open":
        top = bezier((-0.0085, -0.004), (-0.004, 0.0045), (0.004, 0.0045), (0.0085, -0.004), 16)
        bot = bezier((-0.0085, -0.004), (-0.004, -0.0025), (0.004, -0.0025), (0.0085, -0.004), 16)
        _open_mouth(lay, top, bot, tongue=False)
    elif frame == "smirk":
        line(bezier((-0.0075, -0.0005), (-0.002, -0.002), (0.004, -0.0015), (0.0095, 0.003)))
    elif frame == "talk_a":
        top = bezier((-0.0075, 0.0015), (-0.003, 0.0025), (0.003, 0.0025), (0.0075, 0.0015), 16)
        bot = bezier((-0.0075, 0.0015), (-0.0055, -0.0085), (0.0055, -0.0085), (0.0075, 0.0015), 16)
        _open_mouth(lay, top, bot)
    elif frame == "talk_e":
        top = bezier((-0.0095, 0.001), (-0.004, 0.0018), (0.004, 0.0018), (0.0095, 0.001), 16)
        bot = bezier((-0.0095, 0.001), (-0.006, -0.0045), (0.006, -0.0045), (0.0095, 0.001), 16)
        _open_mouth(lay, top, bot, tongue=False, teeth=True)
    elif frame == "talk_o":
        d = sd_ellipse(X, Y, 0, -0.0015, 0.0058, 0.0072)
        lay.paint(d, MOUTH_INSIDE)
        lay.paint(np.abs(d) - 0.0008, LINE)
    elif frame == "grin":
        # breites Grinsen mit Zähnen
        top = bezier((-0.0135, 0.0030), (-0.006, 0.0005), (0.006, 0.0005), (0.0135, 0.0030), 16)
        bot = bezier((-0.0135, 0.0030), (-0.008, -0.0075), (0.008, -0.0075), (0.0135, 0.0030), 16)
        _open_mouth(lay, top, bot, tongue=False, teeth=True)
    elif frame == "bleh":
        line(bezier((-0.009, 0.0015), (-0.004, -0.0025), (0.004, -0.0025), (0.009, 0.0015)))
        t = sd_ellipse(X, Y, 0.002, -0.0045, 0.0042, 0.0045)
        lay.paint(np.maximum(t, -(Y + 0.0010)), TONGUE)
        lay.paint(np.maximum(np.abs(t) - 0.0006, -(Y + 0.0012)), LINE)
    elif frame == "shout":
        top = bezier((-0.0110, 0.0050), (-0.005, 0.0020), (0.005, 0.0020), (0.0110, 0.0050), 16)
        bot = bezier((-0.0110, 0.0050), (-0.009, -0.0140), (0.009, -0.0140), (0.0110, 0.0050), 16)
        _open_mouth(lay, top, bot, teeth=True)
    elif frame == "triangle":
        tri = np.array([(-0.0050, -0.0035), (0.0050, -0.0035), (0.0, 0.0040)])
        d = sd_poly(X, Y, tri) - 0.0008
        lay.paint(d, MOUTH_INSIDE)
        lay.paint(np.abs(d) - 0.0007, LINE)
    elif frame == "pout":
        a = bezier((-0.0035, 0.004), (0.0015, 0.004), (0.0015, 0.0), (-0.0015, 0.0), 12)
        b = bezier((-0.0015, 0.0), (0.0015, 0.0), (0.0015, -0.004), (-0.0035, -0.004), 12)
        line(np.concatenate([a, b[1:]]), 0.0012, 0.0016, 0.0012)
    return lay.rgba()


# ---------------------------------------------------------------------------------------------
# Atlanten
# ---------------------------------------------------------------------------------------------

def build_atlases():
    """Liefert dict Name -> Bild (H, W, 4) in 0..1.
    Augen/Masken: Spalte = Ausdruck (EYE_FRAMES), Zeile = Satz (Frau: 3 Formen, Mann: 3 Formen)."""
    ec = EYE_CELL_PX
    eyes = np.zeros((6 * ec, len(EYE_FRAMES) * ec, 4))
    masks = np.zeros_like(eyes)
    for gi, gender in enumerate(("female", "male")):
        for si, shape in enumerate(SHAPE_NAMES[gender]):
            r = gi * 3 + si
            for c, f in enumerate(EYE_FRAMES):
                lines, mask = draw_eye(f, gender, shape)
                eyes[r * ec:(r + 1) * ec, c * ec:(c + 1) * ec] = lines
                masks[r * ec:(r + 1) * ec, c * ec:(c + 1) * ec] = mask
    iris = np.zeros((4 * CELL_PX, 3 * CELL_PX, 4))
    for gi, gender in enumerate(("female", "male")):
        for i, f in enumerate(IRIS_FRAMES):
            r, c = gi * 2 + i // 3, i % 3
            iris[r * CELL_PX:(r + 1) * CELL_PX, c * CELL_PX:(c + 1) * CELL_PX] = draw_iris(f, gender)
    brows = np.zeros((4 * CELL_PX // 2, 4 * CELL_PX, 4))
    for gi, gender in enumerate(("female", "male")):
        for i, f in enumerate(BROW_FRAMES):
            r, c = gi * 2 + i // 4, i % 4
            brows[r * CELL_PX // 2:(r + 1) * CELL_PX // 2, c * CELL_PX:(c + 1) * CELL_PX] = draw_brow(f, gender)
    mouths = np.zeros((4 * CELL_PX, 5 * CELL_PX, 4))
    for i, f in enumerate(MOUTH_FRAMES):
        r, c = i // 5, i % 5
        mouths[r * CELL_PX:(r + 1) * CELL_PX, c * CELL_PX:(c + 1) * CELL_PX] = draw_mouth(f)
    return {"face_eyes": eyes, "face_eye_masks": masks, "face_iris": iris, "face_brows": brows,
            "face_mouths": mouths}


def write_png(path, img):
    """img (H, W, 4) in 0..1 -> 8-bit RGBA PNG (ohne Zusatzbibliotheken)."""
    a = (np.clip(img, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    h, w = a.shape[:2]
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


# ---------------------------------------------------------------------------------------------
# Ausdrücke und Zusammensetzen (wie der Shader)
# ---------------------------------------------------------------------------------------------

# Ausdruck = Auge links, Auge rechts (der Figur), Iris, Augenbrauen, Mund, Wangenröte, Irisgröße,
# Rotstriche auf den Wangen – muss zu ChibiCharacter.MOODS passen
EXPRESSIONS = {
    "neutral": ("open", "open", "normal", "neutral", "smile", 0.55, 1.0, 0.0),
    "happy": ("soft", "soft", "normal", "relaxed", "open_smile", 0.5, 1.0, 0.0),
    "laugh": ("happy", "happy", "normal", "raised", "laugh", 0.7, 1.0, 0.0),
    "content": ("happy", "happy", "normal", "relaxed", "smile_wide", 0.6, 1.0, 0.0),
    "grin": ("soft", "soft", "normal", "raised", "grin", 0.5, 1.0, 0.0),
    "excited": ("open", "open", "sparkle", "raised", "open_smile", 0.6, 1.05, 0.0),
    "love": ("open", "open", "heart", "raised", "cat", 0.9, 1.05, 0.0),
    "starstruck": ("wide", "wide", "star", "raised", "O", 0.6, 1.0, 0.0),
    "wink": ("open", "happy", "normal", "raised", "grin", 0.5, 1.0, 0.0),
    "cheeky": ("happy", "open", "normal", "raised", "bleh", 0.5, 1.0, 0.0),
    "surprised": ("wide", "wide", "normal", "raised", "O", 0.2, 0.8, 0.0),
    "shocked": ("wide", "wide", "small", "raised", "triangle", 0.1, 1.0, 0.0),
    "sad": ("sad", "sad", "normal", "worried", "frown", 0.1, 1.0, 0.0),
    "teary": ("teary", "teary", "sparkle", "worried", "wavy", 0.4, 1.0, 0.0),
    "crying": ("cry", "cry", "normal", "worried", "sad_open", 0.4, 1.0, 0.0),
    "angry": ("angry", "angry", "normal", "angry", "flat", 0.3, 0.95, 0.0),
    "furious": ("squeeze", "squeeze", "normal", "angry", "shout", 0.6, 1.0, 0.0),
    "annoyed": ("annoyed", "annoyed", "normal", "flat", "flat", 0.1, 1.0, 0.0),
    "smug": ("annoyed", "annoyed", "normal", "focused", "smirk", 0.2, 1.0, 0.0),
    "worried": ("open", "open", "normal", "worried", "wavy", 0.3, 0.9, 0.0),
    "embarrassed": ("soft", "soft", "normal", "worried", "wavy", 0.9, 1.0, 1.0),
    "shy": ("open", "open", "normal", "sad", "pout", 0.8, 1.0, 1.0),
    "thinking": ("open", "half", "normal", "focused", "pout", 0.2, 1.0, 0.0),
    "sleepy": ("half", "half", "normal", "relaxed", "o", 0.2, 1.0, 0.0),
    "asleep": ("closed", "closed", "normal", "relaxed", "o", 0.3, 1.0, 0.0),
    "dizzy": ("open", "open", "spiral", "worried", "wavy", 0.2, 1.0, 0.0),
    "blink": ("closed", "closed", "normal", "neutral", "smile", 0.55, 1.0, 0.0),
}
# Iris je Augenform: (Größe, Höhe) – auch in chibi_face.gdshader (SET_IRIS)


def _sample(img, u, v):
    """Bilinear (u, v in Pixeln, außerhalb = durchsichtig)."""
    h, w = img.shape[:2]
    x0 = np.floor(u - 0.5).astype(int)
    y0 = np.floor(v - 0.5).astype(int)
    fx = (u - 0.5) - x0
    fy = (v - 0.5) - y0
    out = 0.0
    for dy, wy in ((0, 1 - fy), (1, fy)):
        for dx, wx in ((0, 1 - fx), (1, fx)):
            xx = np.clip(x0 + dx, 0, w - 1)
            yy = np.clip(y0 + dy, 0, h - 1)
            ok = ((x0 + dx >= 0) & (x0 + dx < w) & (y0 + dy >= 0) & (y0 + dy < h)).astype(float)
            out = out + img[yy, xx] * (wx * wy * ok)[..., None]
    return out


def _cell(img, local_x, local_y, cell_w, cell_h, col, row, cw_px, ch_px):
    u = (local_x / cell_w + 0.5)
    v = (0.5 - local_y / cell_h)
    inside = (u >= 0) & (u <= 1) & (v >= 0) & (v <= 1)
    s = _sample(img, col * cw_px + np.clip(u, 0, 1) * cw_px, row * ch_px + np.clip(v, 0, 1) * ch_px)
    return s * inside[..., None]


def srgb_to_linear(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def compose(atlases, expression="neutral", gender="female", size=1024, skin=(0.95, 0.80, 0.68),
            iris_color=(0.42, 0.28, 0.20), brow_color=(0.30, 0.22, 0.18), look=(0.0, 0.0), shape=None):
    """Ganzes Gesicht (sRGB, 0..1) im UV-Bereich 0..1 – Gegenstück zu chibi_face.gdshader."""
    eye_l, eye_r, iris_f, brow_f, mouth_f, blush, iris_scale, blush_lines = EXPRESSIONS[expression]
    n = size
    u = (np.arange(n) + 0.5) / n
    U, V = np.meshgrid(u, u)
    fx = (U - 0.5) * FACE_SIZE
    fz = (1.0 - V) * FACE_SIZE
    col = np.ones((n, n, 3)) * np.array(skin)
    for s in (1, -1):
        bu, bv = (fx - s * BLUSH_X) / BLUSH_R[0], (fz - BLUSH_Z) / BLUSH_R[1]
        a = np.clip(1.0 - (bu * bu + bv * bv), 0.0, 1.0) ** 1.2 * 0.75 * blush
        col = col * (1 - a[..., None]) + np.array((0.97, 0.50, 0.52)) * a[..., None]
        if blush_lines > 0:
            # drei kurze schräge Striche ("///")
            st = np.abs(((bu * s * 0.9 + bv * 1.6) * 1.5 + 0.5) % 1.0 - 0.5)
            a = (st < 0.11) * (np.abs(bu) < 0.62) * (np.abs(bv) < 0.55) * 0.75 * blush_lines
            col = col * (1 - a[..., None]) + np.array((0.86, 0.36, 0.38)) * a[..., None]
    gi = 0 if gender == "female" else 1
    shape = shape or SHAPE_NAMES[gender][0]
    row = gi * 3 + SHAPE_NAMES[gender].index(shape)
    isc, idy = EYE_SHAPES[gender][shape]["iris"]
    ii = IRIS_FRAMES.index(iris_f)
    ec = EYE_CELL_PX
    for s, eye_f in ((1, eye_l), (-1, eye_r)):
        ei = EYE_FRAMES.index(eye_f)
        lx = (fx - s * EYE_X) * s / EYE_SCALE
        ly = (fz - EYE_Z) / EYE_SCALE
        lines = _cell(atlases["face_eyes"], lx, ly, EYE_CELL, EYE_CELL, ei, row, ec, ec)
        mask = _cell(atlases["face_eye_masks"], lx, ly, EYE_CELL, EYE_CELL, ei, row, ec, ec)
        white, shadow = mask[..., 0], mask[..., 1]
        col = col * (1 - white[..., None]) + np.array((0.99, 0.98, 0.97)) * white[..., None]
        sc = iris_scale * isc
        ix = ((fx - s * EYE_X) / EYE_SCALE - look[0] * 0.006) / sc
        iy = ((fz - EYE_Z) / EYE_SCALE - idy - look[1] * 0.004) / sc
        ir = _cell(atlases["face_iris"], ix, iy, IRIS_CELL, IRIS_CELL, ii % 3, gi * 2 + ii // 3, CELL_PX, CELL_PX)
        ia = ir[..., 3] * white
        base = np.array(iris_color)
        icol = base * 0.25 + (base * 1.2 - base * 0.25) * np.clip(ir[..., 0:1], 0, 1)
        icol = icol * (1 - ir[..., 2:3]) + np.array(LINE) * ir[..., 2:3] * 0.85
        icol = icol * (1 - ir[..., 1:2]) + 1.0 * ir[..., 1:2]
        col = col * (1 - ia[..., None]) + np.clip(icol, 0, 1) * ia[..., None]
        sh = shadow * 0.5
        col = col * (1 - sh[..., None] * (1 - np.array((0.72, 0.70, 0.82))))
        la = lines[..., 3:4]
        col = col * (1 - la) + lines[..., :3] * la
        bi = BROW_FRAMES.index(brow_f)
        bx = (fx - s * BROW_X) * s / BROW_SCALE
        br = _cell(atlases["face_brows"], bx, (fz - BROW_Z) / BROW_SCALE, BROW_CELL[0], BROW_CELL[1], bi % 4,
                   gi * 2 + bi // 4, CELL_PX, CELL_PX // 2)
        ba = br[..., 3:4]
        col = col * (1 - ba) + np.array(brow_color) * ba
    mi = MOUTH_FRAMES.index(mouth_f)
    m = _cell(atlases["face_mouths"], fx / MOUTH_SCALE, (fz - MOUTH_Z) / MOUTH_SCALE, MOUTH_CELL, MOUTH_CELL,
              mi % 5, mi // 5, CELL_PX, CELL_PX)
    ma = m[..., 3:4]
    col = col * (1 - ma) + m[..., :3] * ma
    out = np.ones((n, n, 4))
    out[..., :3] = np.clip(col, 0, 1)
    return out
