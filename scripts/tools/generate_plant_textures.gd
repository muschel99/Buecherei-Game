extends SceneTree
## Erzeugt die Pflanzen-Texturen der Außenwelt (seit Etappe 4g, Teil 4f).
##
## Pflanzen aus Blender (tools/blender/style_plants.py) bestehen aus echten, gebogenen
## Blättern und Blüten. Ihre Form (gezackter Rand, Lappen beim Efeu, Blütenblätter) kommt aus
## diesen Bildern: Alpha = Deckung (0 = weggeschnitten). Jede Ebene ist 512 x 512 Pixel groß und
## zeigt genau EIN Blatt bzw. EINE Blüte bzw. einen Zweig (Texturkoordinaten 0..1 über die ganze
## Ebene, Ansatz des Stiels unten in der Mitte). Nur "bark" (Rinde) ist nahtlos und deckend.
##
## Farben: Blätter haben ihre natürliche Farbe, Blüten sind hell (fast weiß) und bekommen ihre
## Farbe vom Modell (Farbe der Ecken). Der Shader rechnet Textur x Farbe x tint_gain – die
## neutrale Farbe im Modell ist darum hellgrau (0,8).
## Ausgabe (assets/textures/plants/):
##   plant_albedo.png  Farben + Deckung, 4 x 4 Ebenen (Zeile für Zeile)
##   plant_normal.png  Relief (Adern, gewölbte Blattflächen), gleiche Anordnung
##   layers.json       Tabelle der Ebenen (Name, Nummer, Rauheit, Durchscheinen) – liest
##                     tools/blender/style_lib.py
##
## Starten (Terminal, im Projektordner):
##   godot --headless -s res://scripts/tools/generate_plant_textures.gd
## Danach importiert Godot die Bilder beim nächsten Öffnen von selbst (als Texture2DArray).

const SIZE := 512
const GRID_X := 4
const GRID_Y := 4
const OUT_DIR := "res://assets/textures/plants/"

## Die Ebenen: Name, Rauheit, Durchscheinen (wie viel Licht von hinten durchkommt). Die
## Reihenfolge ist die Nummer der Ebene – nur hinten anhängen, sonst passen fertige Modelle
## nicht mehr.
const LAYERS := [
	["ivy_leaf", 0.42, 0.3],
	["broad_leaf", 0.6, 0.45],
	["narrow_leaf", 0.62, 0.3],
	["round_leaf", 0.75, 0.4],
	["heart_leaf", 0.5, 0.45],
	["box_sprig", 0.45, 0.25],
	["leaf_spray", 0.6, 0.45],
	["fern_frond", 0.7, 0.5],
	["grass_tuft", 0.7, 0.5],
	["floret5", 0.6, 0.6],
	["floret4", 0.6, 0.6],
	["petunia", 0.55, 0.6],
	["daisy", 0.7, 0.5],
	["petal", 0.5, 0.6],
	["lavender", 0.75, 0.3],
	["bark", 0.92, 0.0],
]

## Blattformen (Breite entlang der Länge, siehe _half_width)
enum Shape { OVATE, ELLIPTIC, LANCE, OBOVATE, BLADE, OBLONG }
## Adern: fiederig (vom Mittelnerv schräg nach außen) oder längs (wie Meridiane, Blütenblätter)
enum Veins { PINNATE, PARALLEL, NONE }

var _albedo := Image.create_empty(SIZE * GRID_X, SIZE * GRID_Y, false, Image.FORMAT_RGBA8)
var _normal := Image.create_empty(SIZE * GRID_X, SIZE * GRID_Y, false, Image.FORMAT_RGB8)
var _rnd := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for index in LAYERS.size():
		var started := Time.get_ticks_msec()
		_rnd.seed = 1000 + index
		var layer := _make_layer(LAYERS[index][0])
		_blit(layer, index)
		print("Ebene %d %s: %d ms" % [index, LAYERS[index][0], Time.get_ticks_msec() - started])
	_albedo.save_png(OUT_DIR + "plant_albedo.png")
	_normal.save_png(OUT_DIR + "plant_normal.png")
	_save_table()
	print("Pflanzen-Texturen gespeichert in ", OUT_DIR)
	quit()


## Eine Ebene: Farbe (RGBA, 0..1) und Höhe (0..1) je Pixel. Koordinaten beim Zeichnen:
## x 0..1 nach rechts, y 0..1 nach OBEN (wie die Texturkoordinaten in Blender).
class Layer:
	var color := PackedFloat32Array()
	var height := PackedFloat32Array()
	var normal_strength := 3.0
	var opaque := false

	func _init() -> void:
		color.resize(SIZE * SIZE * 4)
		height.resize(SIZE * SIZE)
		height.fill(0.5)

	## Farbe c mit Deckung a über das Vorhandene legen (Höhe h genauso).
	func over(i: int, c: Color, a: float, h: float) -> void:
		if a <= 0.0:
			return
		var k := i * 4
		var keep := 1.0 - a
		color[k] = c.r * a + color[k] * keep
		color[k + 1] = c.g * a + color[k + 1] * keep
		color[k + 2] = c.b * a + color[k + 2] * keep
		color[k + 3] = a + color[k + 3] * keep
		height[i] = h * a + height[i] * keep


func _make_layer(layer_name: String) -> Layer:
	match layer_name:
		"ivy_leaf":
			return _ivy_leaf()
		"broad_leaf":
			return _single_leaf(Shape.OVATE, 0.62, Color(0.25, 0.4, 0.15), Color(0.5, 0.62, 0.32), 0.07, 22, 8, 0.75)
		"narrow_leaf":
			return _single_leaf(Shape.LANCE, 0.2, Color(0.35, 0.42, 0.29), Color(0.58, 0.63, 0.5), 0.0, 0, 9, 1.4)
		"round_leaf":
			return _geranium_leaf()
		"heart_leaf":
			return _hosta_leaf()
		"box_sprig":
			return _box_sprig()
		"leaf_spray":
			return _leaf_spray()
		"fern_frond":
			return _fern_frond()
		"grass_tuft":
			return _grass_tuft()
		"floret5":
			return _floret(5, 0.44, 0.4, 0.0)
		"floret4":
			return _floret(4, 0.46, 0.5, 0.35)
		"petunia":
			return _petunia()
		"daisy":
			return _daisy()
		"petal":
			return _single_petal()
		"lavender":
			return _lavender()
		"bark":
			return _bark()
	push_error("Unbekannte Ebene " + layer_name)
	return Layer.new()


# --- Rauschen (wie in generate_style_textures.gd, nahtlos) ---

static func _hash(ix: int, iy: int, seed: int) -> float:
	var h := (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func _value_noise(u: float, v: float, freq: int, seed: int) -> float:
	var x := u * freq
	var y := v * freq
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(ix, freq)
	var y0 := posmod(iy, freq)
	var x1 := (x0 + 1) % freq
	var y1 := (y0 + 1) % freq
	return lerpf(lerpf(_hash(x0, y0, seed), _hash(x1, y0, seed), fx), lerpf(_hash(x0, y1, seed), _hash(x1, y1, seed), fx), fy)


static func _fbm(u: float, v: float, freq: int, octaves: int, seed: int) -> float:
	var total := 0.0
	var amplitude := 1.0
	var sum := 0.0
	for octave in octaves:
		total += _value_noise(u, v, freq, seed + octave * 31) * amplitude
		sum += amplitude
		amplitude *= 0.5
		freq *= 2
	return total / sum


static func _field(freq: int, octaves: int, seed: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			out[y * SIZE + x] = _fbm(float(x) / SIZE, float(y) / SIZE, freq, octaves, seed)
	return out


# --- Bausteine ---

## Pixel-Nummer und Lage (x, y nach oben) eines Pixels.
static func _pos(px: int, py: int) -> Vector2:
	return Vector2((px + 0.5) / SIZE, 1.0 - (py + 0.5) / SIZE)


## Pixel-Bereich (x0, y0, x1, y1) um ein Rechteck in Ebenen-Koordinaten.
static func _box(lo: Vector2, hi: Vector2) -> Rect2i:
	var x0 := clampi(floori(lo.x * SIZE) - 2, 0, SIZE - 1)
	var x1 := clampi(ceili(hi.x * SIZE) + 2, 0, SIZE - 1)
	var y0 := clampi(floori((1.0 - hi.y) * SIZE) - 2, 0, SIZE - 1)
	var y1 := clampi(ceili((1.0 - lo.y) * SIZE) + 2, 0, SIZE - 1)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


## Halbe Breite (0..1) eines Blatts an der Stelle t (0 = Ansatz, 1 = Spitze).
static func _half_width(shape: int, t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	match shape:
		Shape.OVATE:
			return pow(sin(PI * pow(t, 0.72)), 0.8)
		Shape.ELLIPTIC:
			return pow(sin(PI * t), 0.7)
		Shape.LANCE:
			return pow(sin(PI * pow(t, 0.85)), 0.85) * (1.0 - 0.3 * t)
		Shape.OBOVATE:
			return pow(sin(PI * pow(t, 1.5)), 0.5)
		Shape.BLADE:
			return pow(1.0 - t, 0.75) * smoothstep(0.0, 0.03, t)
		Shape.OBLONG:
			return pow(sin(PI * pow(t, 0.55)), 0.35)
	return 0.0


## Strich (Stängel, Zweig, Blattstiel) entlang einer Linie aus Punkten, Breite w0 → w1
## (Ebenen-Einheiten), Farbe c0 → c1.
func _stroke(layer: Layer, pts: PackedVector2Array, w0: float, w1: float, c0: Color, c1: Color) -> void:
	var total := 0.0
	for k in range(1, pts.size()):
		total += pts[k].distance_to(pts[k - 1])
	var run := 0.0
	for k in range(1, pts.size()):
		var a := pts[k - 1]
		var b := pts[k]
		var seg := b - a
		var seg_len := seg.length()
		if seg_len < 1e-6:
			continue
		var ta := run / total
		var tb := (run + seg_len) / total
		run += seg_len
		var wmax := maxf(lerpf(w0, w1, ta), lerpf(w0, w1, tb))
		var rect := _box(Vector2(minf(a.x, b.x) - wmax, minf(a.y, b.y) - wmax), Vector2(maxf(a.x, b.x) + wmax, maxf(a.y, b.y) + wmax))
		for py in range(rect.position.y, rect.end.y + 1):
			for px in range(rect.position.x, rect.end.x + 1):
				var p := _pos(px, py)
				var f := clampf((p - a).dot(seg) / (seg_len * seg_len), 0.0, 1.0)
				var dist := p.distance_to(a + seg * f)
				var t := lerpf(ta, tb, f)
				var w := lerpf(w0, w1, t) * 0.5
				var alpha := clampf((w - dist) * SIZE + 0.5, 0.0, 1.0)
				if alpha <= 0.0:
					continue
				var across := clampf(dist / maxf(w, 1e-5), 0.0, 1.0)
				var c := c0.lerp(c1, t) * (1.05 - 0.25 * across * across)
				layer.over(py * SIZE + px, c, alpha, 0.55 + 0.2 * sqrt(1.0 - across * across))


## Ein Blatt (oder Blütenblatt): Ansatz bei base, Richtung angle (0 = nach oben, im
## Uhrzeigersinn), Länge und Breite in Ebenen-Einheiten. serr/teeth = gesägter Rand,
## veins = Aderung, vein_count = Seitennerven je Seite, slope = Neigung der Seitennerven.
func _leaf(layer: Layer, base: Vector2, angle: float, length: float, width: float, shape: int,
		base_color: Color, vein_color: Color, serr := 0.0, teeth := 0, veins := Veins.PINNATE,
		vein_count := 7, slope := 0.8, mottle := 0.12, rim := 0.25, seed := 0) -> void:
	var dir := Vector2(sin(angle), cos(angle))
	var side := Vector2(dir.y, -dir.x)
	var hw_max := width * 0.5
	var tip := base + dir * length
	var lo := Vector2(minf(base.x, tip.x), minf(base.y, tip.y)) - Vector2(hw_max, hw_max)
	var hi := Vector2(maxf(base.x, tip.x), maxf(base.y, tip.y)) + Vector2(hw_max, hw_max)
	var rect := _box(lo, hi)
	var px_size := 1.0 / SIZE
	for py in range(rect.position.y, rect.end.y + 1):
		for px in range(rect.position.x, rect.end.x + 1):
			var p := _pos(px, py)
			var d := p - base
			var along := d.dot(dir)
			var t := along / length
			if t <= 0.0 or t >= 1.0:
				continue
			var across := d.dot(side)
			var hw := _half_width(shape, t)
			if teeth > 0 and t > 0.12 and t < 0.96:
				hw *= 1.0 - serr * fposmod(t * teeth, 1.0)
			var edge := (hw * hw_max - absf(across)) / px_size
			var alpha := clampf(edge + 0.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var s := clampf(absf(across) / maxf(hw * hw_max, 1e-5), 0.0, 1.0)
			# Mittelnerv
			var mid_w := maxf(1.1, 0.011 * length * SIZE * (1.0 - 0.75 * t))
			var mid := 1.0 - smoothstep(mid_w * 0.45, mid_w, absf(across) / px_size)
			var vein := 0.0
			if veins == Veins.PINNATE:
				var c := (along - slope * absf(across)) / length * vein_count
				var line := absf(fposmod(c + 0.5, 1.0) - 0.5) * length / vein_count / px_size
				vein = (1.0 - smoothstep(0.5, 1.4, line)) * (1.0 - smoothstep(0.7, 0.97, s)) * smoothstep(0.02, 0.08, t)
			elif veins == Veins.PARALLEL:
				var m := s * vein_count
				var line2 := absf(fposmod(m + 0.5, 1.0) - 0.5) / vein_count * hw * hw_max / px_size
				vein = (1.0 - smoothstep(0.35, 1.1, line2)) * smoothstep(0.03, 0.2, t) * 0.8
			var n := _value_noise(p.x, p.y, 48, seed + 7) * 0.6 + _value_noise(p.x, p.y, 160, seed + 9) * 0.4
			var col := base_color * (1.0 - mottle + 2.0 * mottle * n)
			# Zum Mittelnerv hin etwas heller, am Rand eine feine helle Kante
			col = col.lerp(vein_color, 0.12 * (1.0 - s))
			col = col.lerp(vein_color, maxf(mid, vein * 0.75))
			col = col.lerp(vein_color.lerp(base_color, 0.5), rim * (1.0 - smoothstep(0.5, 2.5, edge)))
			var h := 0.45 + 0.18 * (1.0 - s * s) + 0.12 * mid + 0.05 * vein
			col.a = 1.0
			layer.over(py * SIZE + px, col, alpha, h)


## Füllt die Farbe weggeschnittener Pixel mit der Farbe benachbarter Blätter (sonst entsteht
## in der Ferne, wenn Godot das Bild verkleinert, ein dunkler Rand um jedes Blatt).
func _bleed(layer: Layer) -> void:
	var filled := PackedByteArray()
	filled.resize(SIZE * SIZE)
	var sum := Color(0, 0, 0)
	var weight := 0.0
	for i in SIZE * SIZE:
		var a := layer.color[i * 4 + 3]
		if a > 0.02:
			# Beim Zeichnen ist die Farbe mit der Deckung multipliziert: zurückrechnen
			for k in 3:
				layer.color[i * 4 + k] /= a
			filled[i] = 1
			sum += Color(layer.color[i * 4], layer.color[i * 4 + 1], layer.color[i * 4 + 2]) * a
			weight += a
	var mean := sum / maxf(weight, 1e-5)
	for pass_index in 6:
		var next := filled.duplicate()
		for y in SIZE:
			for x in SIZE:
				var i := y * SIZE + x
				if filled[i]:
					continue
				var r := 0.0
				var g := 0.0
				var b := 0.0
				var count := 0
				if x > 0 and filled[i - 1]:
					r += layer.color[(i - 1) * 4]
					g += layer.color[(i - 1) * 4 + 1]
					b += layer.color[(i - 1) * 4 + 2]
					count += 1
				if x < SIZE - 1 and filled[i + 1]:
					r += layer.color[(i + 1) * 4]
					g += layer.color[(i + 1) * 4 + 1]
					b += layer.color[(i + 1) * 4 + 2]
					count += 1
				if y > 0 and filled[i - SIZE]:
					r += layer.color[(i - SIZE) * 4]
					g += layer.color[(i - SIZE) * 4 + 1]
					b += layer.color[(i - SIZE) * 4 + 2]
					count += 1
				if y < SIZE - 1 and filled[i + SIZE]:
					r += layer.color[(i + SIZE) * 4]
					g += layer.color[(i + SIZE) * 4 + 1]
					b += layer.color[(i + SIZE) * 4 + 2]
					count += 1
				if count > 0:
					layer.color[i * 4] = r / count
					layer.color[i * 4 + 1] = g / count
					layer.color[i * 4 + 2] = b / count
					next[i] = 1
		filled = next
	for i in SIZE * SIZE:
		if not filled[i]:
			layer.color[i * 4] = mean.r
			layer.color[i * 4 + 1] = mean.g
			layer.color[i * 4 + 2] = mean.b


# --- Die Ebenen ---

## Efeu (Hedera helix): fünf spitze Lappen, dunkel glänzend mit hellen, handförmigen Adern.
## Ansatz des Stiels unten in der Mitte (0,5 | 0,0), Stiel 0,1 lang.
func _ivy_leaf() -> Layer:
	var layer := Layer.new()
	var center := Vector2(0.5, 0.3)
	# Lappen: Winkel (0 = oben), Länge, Breite (Winkel)
	var lobes := [[0.0, 0.64, 0.8], [1.2, 0.46, 0.72], [-1.2, 0.46, 0.72], [2.2, 0.32, 0.62], [-2.2, 0.32, 0.62]]
	var base_color := Color(0.15, 0.27, 0.1)
	var vein_color := Color(0.58, 0.64, 0.46)
	var px_size := 1.0 / SIZE
	_stroke(layer, PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.5, 0.2), center]), 0.022, 0.016,
		Color(0.36, 0.33, 0.2), Color(0.42, 0.45, 0.28))
	for py in SIZE:
		for px in SIZE:
			var p := _pos(px, py)
			var d := p - center
			var r := d.length()
			var theta := atan2(d.x, d.y)
			# Weiche Vereinigung der Lappen (spitz an den Enden, flache Buchten dazwischen)
			var sum := pow(0.25 + 0.04 * cos(theta), 5.0)
			if absf(theta) > 2.6:
				sum = pow(0.05 + 0.2 * (PI - absf(theta)) / (PI - 2.6), 5.0)
			for lobe: Array in lobes:
				var lobe_angle: float = lobe[0]
				var lobe_length: float = lobe[1]
				var lobe_width: float = lobe[2]
				var dt := absf(wrapf(theta - lobe_angle, -PI, PI)) / lobe_width
				if dt < 1.0:
					sum += pow(lobe_length * pow(1.0 - dt, 0.95), 5.0)
			var radius := pow(sum, 0.2)
			var edge := (radius - r) / px_size
			var alpha := clampf(edge + 0.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			# Hauptadern zu den Lappenspitzen, dazu feine Seitenadern
			var vein := 0.0
			for lobe: Array in lobes:
				var lobe_angle: float = lobe[0]
				var lobe_length: float = lobe[1]
				var dir := Vector2(sin(lobe_angle), cos(lobe_angle))
				var along := d.dot(dir)
				if along < 0.0 or along > lobe_length * 0.92:
					continue
				var dist := absf(d.dot(Vector2(dir.y, -dir.x)))
				var w := (0.0065 - 0.004 * along / lobe_length) / px_size
				vein = maxf(vein, 1.0 - smoothstep(w * 0.5, w, dist / px_size))
				# Seitenadern zweigen schräg zur Spitze hin ab
				var c := (along - 0.9 * dist) * 22.0
				var side_line := absf(fposmod(c + 0.5, 1.0) - 0.5) / 22.0 / px_size
				var fade := (1.0 - smoothstep(0.3, 0.5, dist / maxf(lobe_length, 0.01))) * smoothstep(0.04, 0.1, along)
				vein = maxf(vein, (1.0 - smoothstep(0.4, 1.1, side_line)) * fade * 0.55)
			var n := _value_noise(p.x, p.y, 40, 3) * 0.6 + _value_noise(p.x, p.y, 150, 4) * 0.4
			var col := base_color * (0.86 + 0.3 * n)
			col = col.lerp(base_color * 1.5, 0.25 * (1.0 - smoothstep(0.0, 0.35, r)))
			col = col.lerp(vein_color, vein * 0.85)
			col = col.lerp(Color(0.4, 0.46, 0.28), 0.4 * (1.0 - smoothstep(0.5, 3.0, edge)))
			col.a = 1.0
			var h := 0.45 + 0.2 * clampf(1.0 - r / maxf(radius, 0.01), 0.0, 1.0) - 0.06 * vein
			layer.over(py * SIZE + px, col, alpha, h)
	layer.normal_strength = 4.0
	_bleed(layer)
	return layer


## Ein einzelnes Blatt, das die Ebene ausfüllt (Ansatz unten in der Mitte, kurzer Stiel).
func _single_leaf(shape: int, width: float, base_color: Color, vein_color: Color, serr: float, teeth: int,
		vein_count: int, slope: float) -> Layer:
	var layer := Layer.new()
	_stroke(layer, PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.5, 0.09)]), 0.02, 0.016,
		base_color.lerp(Color(0.45, 0.4, 0.25), 0.5), vein_color)
	_leaf(layer, Vector2(0.5, 0.06), 0.0, 0.93, width, shape, base_color, vein_color, serr, teeth, Veins.PINNATE,
		vein_count, slope, 0.12, 0.3, 11)
	layer.normal_strength = 3.5
	_bleed(layer)
	return layer


## Geranie (Pelargonium zonale): rund, fein gekerbt, dunkle Zone wie ein Hufeisen, handförmige
## Adern. Ansatz unten in der Mitte, Mitte des Blatts bei (0,5 | 0,45).
func _geranium_leaf() -> Layer:
	var layer := Layer.new()
	var center := Vector2(0.5, 0.47)
	var base_color := Color(0.29, 0.47, 0.2)
	var zone_color := Color(0.25, 0.25, 0.1)
	var vein_color := Color(0.48, 0.62, 0.32)
	var px_size := 1.0 / SIZE
	_stroke(layer, PackedVector2Array([Vector2(0.5, 0.0), center]), 0.022, 0.018, Color(0.38, 0.5, 0.25), vein_color)
	for py in SIZE:
		for px in SIZE:
			var p := _pos(px, py)
			var d := p - center
			var r := d.length()
			var theta := atan2(d.x, d.y)
			var radius := 0.46 * (1.0 + 0.02 * absf(cos(theta * 9.0))) * (1.0 + 0.035 * cos(theta * 7.0))
			# Herzförmige Bucht am Stiel
			var notch := 1.0 - smoothstep(PI - 0.45, PI, absf(theta)) * 0.75
			radius *= notch
			var edge := (radius - r) / px_size
			var alpha := clampf(edge + 0.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var q := r / maxf(radius, 0.01)
			var spoke := absf(fposmod(theta / TAU * 9.0 + 0.5, 1.0) - 0.5) * TAU / 9.0 * r / px_size
			var vein := (1.0 - smoothstep(0.6, 1.6 - q, spoke)) * smoothstep(0.03, 0.12, r) * (1.0 - smoothstep(0.85, 0.98, q))
			var zone := smoothstep(0.5, 0.58, q) * (1.0 - smoothstep(0.64, 0.74, q)) * (1.0 - smoothstep(PI - 0.9, PI - 0.3, absf(theta))) * (0.75 + 0.5 * _value_noise(p.x, p.y, 20, 23))
			var n := _value_noise(p.x, p.y, 44, 21) * 0.6 + _value_noise(p.x, p.y, 170, 22) * 0.4
			var col := base_color * (0.85 + 0.3 * n)
			col = col.lerp(zone_color, clampf(zone, 0.0, 1.0) * 0.5)
			col = col.lerp(vein_color, vein * 0.6)
			col = col.lerp(Color(0.42, 0.55, 0.3), 0.3 * (1.0 - smoothstep(0.5, 2.5, edge)))
			col.a = 1.0
			# Gewellt: zwischen den Adern leicht gewölbt
			var h := 0.5 + 0.08 * cos(theta * 9.0) * q + 0.1 * (1.0 - q) + 0.05 * vein
			layer.over(py * SIZE + px, col, alpha, h)
	layer.normal_strength = 4.0
	_bleed(layer)
	return layer


## Funkie (Hosta): breit eiförmig, bläulich-grün, tiefe Längsadern bis in die Spitze.
func _hosta_leaf() -> Layer:
	var layer := Layer.new()
	var base_color := Color(0.26, 0.42, 0.24)
	var vein_color := Color(0.42, 0.56, 0.36)
	_stroke(layer, PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.5, 0.1)]), 0.03, 0.022, Color(0.5, 0.58, 0.38), vein_color)
	_leaf(layer, Vector2(0.5, 0.06), 0.0, 0.93, 0.74, Shape.OVATE, base_color, vein_color, 0.0, 0, Veins.PARALLEL,
		7, 0.0, 0.1, 0.2, 31)
	# Die Furchen zwischen den Längsadern machen das Relief
	layer.normal_strength = 5.0
	_bleed(layer)
	return layer


## Buchs-Zweig: verzweigter dünner Trieb mit vielen kleinen, glänzenden, gegenständigen
## Blättchen (für Kugeln und Kegel aus Buchs: viele solcher Zweige rundherum).
func _box_sprig() -> Layer:
	var layer := Layer.new()
	var twig := Color(0.38, 0.33, 0.2)
	var dark := Color(0.13, 0.26, 0.09)
	var young := Color(0.3, 0.45, 0.14)
	var stems := [
		PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.49, 0.35), Vector2(0.52, 0.65), Vector2(0.5, 0.93)]),
		PackedVector2Array([Vector2(0.495, 0.3), Vector2(0.36, 0.5), Vector2(0.26, 0.78)]),
		PackedVector2Array([Vector2(0.505, 0.45), Vector2(0.66, 0.62), Vector2(0.74, 0.86)]),
		PackedVector2Array([Vector2(0.5, 0.18), Vector2(0.66, 0.3), Vector2(0.8, 0.46)]),
		PackedVector2Array([Vector2(0.49, 0.22), Vector2(0.32, 0.3), Vector2(0.18, 0.44)]),
		PackedVector2Array([Vector2(0.37, 0.48), Vector2(0.2, 0.6), Vector2(0.14, 0.7)]),
		PackedVector2Array([Vector2(0.67, 0.64), Vector2(0.84, 0.7), Vector2(0.88, 0.62)]),
		PackedVector2Array([Vector2(0.51, 0.7), Vector2(0.38, 0.86), Vector2(0.36, 0.95)]),
	]
	for stem in stems:
		_stroke(layer, stem, 0.014, 0.007, twig, twig.lerp(young, 0.5))
	for stem in stems:
		# Blattpaare entlang des Triebs, zur Spitze kleiner und heller
		var total := 0.0
		for k in range(1, stem.size()):
			total += stem[k].distance_to(stem[k - 1])
		var count := int(total / 0.042)
		for j in range(1, count + 1):
			var f := float(j) / (count + 0.3)
			var p := _point_on(stem, f)
			var tangent := (_point_on(stem, minf(f + 0.02, 1.0)) - _point_on(stem, maxf(f - 0.02, 0.0))).normalized()
			var base_angle := atan2(tangent.x, tangent.y)
			var size := lerpf(0.095, 0.06, f) * _rnd.randf_range(0.9, 1.1)
			var col := dark.lerp(young, f * f * 0.8) * _rnd.randf_range(0.9, 1.1)
			for s in [-1.0, 1.0]:
				var a: float = base_angle + s * _rnd.randf_range(0.75, 1.1) + float(j % 2) * 0.12
				_leaf(layer, p, a, size, size * 0.72, Shape.ELLIPTIC, col, col.lerp(Color(0.5, 0.58, 0.32), 0.45), 0.0, 0,
					Veins.NONE, 0, 0.0, 0.08, 0.35, j * 7)
		_leaf(layer, stem[stem.size() - 1], atan2((stem[stem.size() - 1] - stem[stem.size() - 2]).x,
			(stem[stem.size() - 1] - stem[stem.size() - 2]).y), 0.06, 0.035, Shape.ELLIPTIC, young, young * 1.3,
			0.0, 0, Veins.NONE, 0, 0.0, 0.05, 0.3, 3)
	layer.normal_strength = 3.0
	_bleed(layer)
	return layer


## Laubzweig für Baumkronen und Sträucher: ein Zweig mit acht gesägten, eiförmigen Blättern.
func _leaf_spray() -> Layer:
	var layer := Layer.new()
	var twig := Color(0.36, 0.3, 0.22)
	var stem := PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.48, 0.3), Vector2(0.52, 0.62), Vector2(0.5, 0.8)])
	_stroke(layer, stem, 0.018, 0.008, twig, twig.lerp(Color(0.4, 0.5, 0.25), 0.6))
	var greens := [Color(0.24, 0.4, 0.15), Color(0.3, 0.46, 0.17), Color(0.21, 0.36, 0.13), Color(0.34, 0.5, 0.2)]
	var spots := [[0.12, -1.0, 0.36], [0.24, 1.0, 0.4], [0.38, -1.0, 0.42], [0.5, 1.0, 0.4], [0.62, -1.0, 0.36],
		[0.74, 1.0, 0.32], [0.86, -1.0, 0.27]]
	for k in spots.size():
		var spot: Array = spots[k]
		var p := _point_on(stem, spot[0])
		var a: float = spot[1] * _rnd.randf_range(0.75, 1.05)
		var length: float = spot[2] * _rnd.randf_range(0.9, 1.05)
		var col: Color = greens[k % greens.size()]
		# Kurzer Blattstiel, dann das Blatt
		var stalk_end := p + Vector2(sin(a), cos(a)) * 0.03
		_stroke(layer, PackedVector2Array([p, stalk_end]), 0.009, 0.007, twig, col)
		_leaf(layer, stalk_end - Vector2(sin(a), cos(a)) * 0.005, a, length, length * 0.52, Shape.OVATE, col,
			col.lerp(Color(0.55, 0.64, 0.38), 0.6), 0.08, 18, Veins.PINNATE, 7, 0.75, 0.12, 0.25, k * 13)
	_leaf(layer, _point_on(stem, 1.0) - Vector2(0, 0.005), 0.05, 0.2, 0.11, Shape.OVATE, greens[3], greens[3] * 1.4,
		0.08, 14, Veins.PINNATE, 6, 0.75, 0.1, 0.25, 99)
	layer.normal_strength = 3.0
	_bleed(layer)
	return layer


## Farnwedel: Mittelrippe, gegenständige Fiedern mit gekerbtem Rand, zur Spitze kleiner.
func _fern_frond() -> Layer:
	var layer := Layer.new()
	var rachis := PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.49, 0.3), Vector2(0.5, 0.65), Vector2(0.52, 0.99)])
	var green := Color(0.27, 0.45, 0.16)
	_stroke(layer, rachis, 0.016, 0.004, Color(0.36, 0.38, 0.2), green)
	var pairs := 15
	for j in pairs:
		var f := 0.1 + 0.86 * float(j) / pairs
		var p := _point_on(rachis, f)
		# Fiederlänge: unten etwas kürzer, Mitte am längsten, Spitze kurz
		var length := 0.36 * sin(PI * pow(f, 0.7)) * (1.0 - 0.1 * f) + 0.025
		var col := green.lerp(Color(0.36, 0.52, 0.2), f * 0.6) * _rnd.randf_range(0.92, 1.08)
		for s in [-1.0, 1.0]:
			var a: float = s * lerpf(1.25, 0.8, f)
			_leaf(layer, p, a, length, length * 0.24, Shape.LANCE, col, col.lerp(Color(0.5, 0.6, 0.3), 0.5), 0.4,
				14, Veins.PINNATE, 12, 1.2, 0.1, 0.2, j * 5 + int(s))
	layer.normal_strength = 3.0
	_bleed(layer)
	return layer


## Grasbüschel: schmale, gebogene Halme aus einem Punkt, grün bis gelblich.
func _grass_tuft() -> Layer:
	var layer := Layer.new()
	for k in 15:
		var spread := (float(k) / 14.0 - 0.5) * 2.0
		var a := spread * 0.75 + _rnd.randf_range(-0.1, 0.1)
		var length := _rnd.randf_range(0.7, 0.98) * (1.0 - 0.3 * absf(spread))
		var col := Color(0.32, 0.48, 0.17).lerp(Color(0.52, 0.56, 0.28), _rnd.randf_range(0.0, 0.5))
		# Gebogener Halm aus kurzen, geraden Stücken
		var p := Vector2(0.5 + spread * 0.06, 0.0)
		var heading := a * 0.4
		var steps := 6
		for step in steps:
			var seg := length / steps
			var w := 0.016 * (1.0 - float(step) / steps) + 0.005
			_leaf(layer, p, heading, seg * 1.35, w * 2.0, Shape.OBLONG if step < steps - 1 else Shape.LANCE, col,
				col * 1.25, 0.0, 0, Veins.NONE, 0, 0.0, 0.08, 0.15, k * 11 + step)
			p += Vector2(sin(heading), cos(heading)) * seg
			heading += a * 0.25
	layer.normal_strength = 2.0
	_bleed(layer)
	return layer


## Einzelne Blüte von vorn aus count Blütenblättern (Geranie: 5, Hortensie: 4), hell zum
## Einfärben. Mitte bei (0,5 | 0,5).
func _floret(count: int, length: float, width_factor: float, rotation: float) -> Layer:
	var layer := Layer.new()
	var center := Vector2(0.5, 0.5)
	var white := Color(0.93, 0.92, 0.9)
	var vein := Color(0.8, 0.78, 0.76)
	for k in count:
		var a := rotation + TAU * k / count + _rnd.randf_range(-0.06, 0.06)
		var l := length * _rnd.randf_range(0.94, 1.04)
		if count == 5 and (k == 0 or k == 4):
			# Geranie: die beiden oberen Blätter etwas schmaler
			l *= 0.92
		_leaf(layer, center - Vector2(sin(a), cos(a)) * 0.03, a, l, l * width_factor * 2.0, Shape.OBOVATE, white * _rnd.randf_range(0.95, 1.02),
			vein, 0.0, 0, Veins.PARALLEL, 9, 0.0, 0.05, 0.12, k * 17)
	# Mitte: Staubgefäße als kleine helle Punkte
	var eye := Color(0.86, 0.85, 0.7)
	for k in 7:
		var a2 := TAU * k / 7.0
		var p := center + Vector2(sin(a2), cos(a2)) * 0.025
		_stroke(layer, PackedVector2Array([center, p]), 0.012, 0.008, eye * 0.85, eye)
	_dot(layer, center, 0.022, Color(0.75, 0.78, 0.55))
	layer.normal_strength = 2.0
	_bleed(layer)
	return layer


## Runder Punkt (Mitte einer Blüte, Knospe).
func _dot(layer: Layer, center: Vector2, radius: float, col: Color) -> void:
	var rect := _box(center - Vector2(radius, radius), center + Vector2(radius, radius))
	for py in range(rect.position.y, rect.end.y + 1):
		for px in range(rect.position.x, rect.end.x + 1):
			var p := _pos(px, py)
			var r := p.distance_to(center)
			var alpha := clampf((radius - r) * SIZE + 0.5, 0.0, 1.0)
			if alpha > 0.0:
				var q := r / radius
				layer.over(py * SIZE + px, col * (1.05 - 0.3 * q * q), alpha, 0.6 + 0.3 * sqrt(maxf(0.0, 1.0 - q * q)))


## Petunie von vorn: fünf verwachsene, runde Lappen, dunklere Adern und Schlund.
func _petunia() -> Layer:
	var layer := Layer.new()
	var center := Vector2(0.5, 0.5)
	var px_size := 1.0 / SIZE
	for py in SIZE:
		for px in SIZE:
			var p := _pos(px, py)
			var d := p - center
			var r := d.length()
			var theta := atan2(d.x, d.y)
			var lobe := absf(cos(theta * 2.5))
			var radius := 0.47 * (0.86 + 0.14 * pow(lobe, 0.6)) + 0.012 * pow(lobe, 40.0)
			var edge := (radius - r) / px_size
			var alpha := clampf(edge + 0.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var q := r / radius
			# Fünf Hauptadern (zwischen den Lappen) und viele feine
			var main := absf(fposmod(theta / TAU * 5.0, 1.0) - 0.5) * TAU / 5.0 * r / px_size
			var fine := absf(fposmod(theta / TAU * 40.0 + 0.5, 1.0) - 0.5) * TAU / 40.0 * r / px_size
			var vein := maxf(1.0 - smoothstep(0.7, 2.0, main), (1.0 - smoothstep(0.3, 1.0, fine)) * 0.35) * (1.0 - smoothstep(0.7, 0.95, q))
			var col := Color(0.94, 0.93, 0.92) * (0.96 + 0.06 * _value_noise(p.x, p.y, 60, 5))
			col = col.lerp(Color(0.62, 0.58, 0.62), vein * 0.75)
			col = col.lerp(Color(0.45, 0.4, 0.45), (1.0 - smoothstep(0.0, 0.32, q)) * 0.7)
			col = col.lerp(Color(0.85, 0.8, 0.5), 1.0 - smoothstep(0.03, 0.06, r))
			col.a = 1.0
			# Trichter: zur Mitte hin tiefer, Lappen leicht gewellt
			var h := 0.3 + 0.5 * smoothstep(0.0, 0.5, q) + 0.05 * cos(theta * 5.0) * q - 0.04 * vein
			layer.over(py * SIZE + px, col, alpha, h)
	layer.normal_strength = 3.0
	_bleed(layer)
	return layer


## Margerite: viele schmale weiße Zungenblüten um eine gelbe, körnige Mitte.
func _daisy() -> Layer:
	var layer := Layer.new()
	var center := Vector2(0.5, 0.5)
	var count := 21
	for k in count:
		var a := TAU * k / count + _rnd.randf_range(-0.05, 0.05)
		var l := 0.42 * _rnd.randf_range(0.9, 1.04)
		_leaf(layer, center + Vector2(sin(a), cos(a)) * 0.06, a, l, 0.085, Shape.OBLONG, Color(0.95, 0.95, 0.93) * _rnd.randf_range(0.95, 1.0),
			Color(0.84, 0.84, 0.82), 0.0, 0, Veins.PARALLEL, 3, 0.0, 0.04, 0.1, k)
	var radius := 0.12
	var rect := _box(center - Vector2(radius, radius), center + Vector2(radius, radius))
	for py in range(rect.position.y, rect.end.y + 1):
		for px in range(rect.position.x, rect.end.x + 1):
			var p := _pos(px, py)
			var d := p - center
			var r := d.length()
			var alpha := clampf((radius - r) * SIZE + 0.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			# Röhrenblüten in Spiralen (wie bei Sonnenblumen)
			var golden := 2.39996
			var best := 9.0
			var q := r / radius
			var n := int(q * q * 160.0)
			for j in range(maxi(0, n - 14), mini(170, n + 14)):
				var fp := center + Vector2(sin(j * golden), cos(j * golden)) * radius * sqrt(j / 170.0)
				best = minf(best, fp.distance_to(p))
			var bump := 1.0 - smoothstep(0.0, 0.009, best)
			var col := Color(0.95, 0.72, 0.15).lerp(Color(0.75, 0.48, 0.08), 0.5 * (1.0 - q))
			col = col * (0.8 + 0.3 * bump)
			col.a = 1.0
			layer.over(py * SIZE + px, col, alpha, 0.6 + 0.2 * bump + 0.15 * (1.0 - q))
	layer.normal_strength = 3.0
	_bleed(layer)
	return layer


## Einzelnes Blütenblatt (Rose, Tulpe): verkehrt-eiförmig, feine Längsadern, Grund heller.
func _single_petal() -> Layer:
	var layer := Layer.new()
	_leaf(layer, Vector2(0.5, 0.02), 0.0, 0.96, 0.9, Shape.OBOVATE, Color(0.94, 0.93, 0.91), Color(0.84, 0.82, 0.8),
		0.0, 0, Veins.PARALLEL, 14, 0.0, 0.04, 0.1, 41)
	# Grund des Blatts etwas gelblich
	for py in SIZE:
		for px in SIZE:
			var i := py * SIZE + px
			var p := _pos(px, py)
			var f := 1.0 - smoothstep(0.02, 0.3, p.y)
			if layer.color[i * 4 + 3] > 0.0 and f > 0.0:
				layer.color[i * 4] = lerpf(layer.color[i * 4], 0.93 * layer.color[i * 4 + 3], f * 0.4)
				layer.color[i * 4 + 1] = lerpf(layer.color[i * 4 + 1], 0.88 * layer.color[i * 4 + 3], f * 0.4)
				layer.color[i * 4 + 2] = lerpf(layer.color[i * 4 + 2], 0.62 * layer.color[i * 4 + 3], f * 0.4)
	layer.normal_strength = 2.0
	_bleed(layer)
	return layer


## Lavendel-Ähre: dünner, graugrüner Stiel, oben quirlständige violette Blüten.
func _lavender() -> Layer:
	var layer := Layer.new()
	var stem := PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.495, 0.5), Vector2(0.505, 0.97)])
	_stroke(layer, stem, 0.022, 0.012, Color(0.45, 0.5, 0.38), Color(0.5, 0.5, 0.48))
	var whorls := 12
	for w in whorls:
		var f := 0.5 + 0.47 * float(w) / (whorls - 1)
		var p := _point_on(stem, f)
		var size := lerpf(0.075, 0.04, float(w) / whorls)
		for k in 5:
			var a := (k - 2) * 0.55 + _rnd.randf_range(-0.15, 0.15)
			var col := Color(0.52, 0.42, 0.72).lerp(Color(0.66, 0.58, 0.84), _rnd.randf()) * _rnd.randf_range(0.85, 1.05)
			var dir := Vector2(sin(a), cos(a))
			_dot(layer, p + dir * size * 0.55 + Vector2(0.0, size * 0.2), size * 0.42, col)
		_dot(layer, p + Vector2(0, size * 0.2), size * 0.38, Color(0.42, 0.38, 0.52))
	layer.normal_strength = 2.5
	_bleed(layer)
	return layer


## Rinde (nahtlos, deckend): längs gefurcht, Platten, ab und zu Flechten.
func _bark() -> Layer:
	var layer := Layer.new()
	layer.opaque = true
	var warp := _field(4, 3, 61)
	var plates := _field(6, 3, 62)
	var fine := _field(64, 2, 63)
	var lichen := _field(8, 3, 64)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var ridge := absf(sin((u * 7.0 + warp[i] * 0.9 + _value_noise(u, v, 3, 65) * 0.5) * PI))
			var fissure := 1.0 - smoothstep(0.05, 0.42, ridge)
			var cross := smoothstep(0.62, 0.7, _value_noise(u, v * 0.5, 18, 66)) * (1.0 - fissure)
			var tone := (0.8 + 0.3 * plates[i]) * (0.9 + 0.15 * fine[i])
			var c := Color(0.4, 0.35, 0.29) * tone
			c = c.lerp(Color(0.17, 0.14, 0.11), fissure * 0.85 + cross * 0.4)
			c = c.lerp(Color(0.56, 0.6, 0.46), smoothstep(0.74, 0.84, lichen[i]) * 0.35 * (1.0 - fissure))
			c.a = 1.0
			layer.color[i * 4] = c.r
			layer.color[i * 4 + 1] = c.g
			layer.color[i * 4 + 2] = c.b
			layer.color[i * 4 + 3] = 1.0
			layer.height[i] = 0.7 - 0.55 * fissure - 0.2 * cross + 0.08 * fine[i]
	layer.normal_strength = 4.0
	return layer


## Punkt auf einer Linie aus Punkten bei Anteil f (0..1 der Länge).
static func _point_on(pts: PackedVector2Array, f: float) -> Vector2:
	var total := 0.0
	for k in range(1, pts.size()):
		total += pts[k].distance_to(pts[k - 1])
	var goal := f * total
	for k in range(1, pts.size()):
		var seg := pts[k].distance_to(pts[k - 1])
		if goal <= seg or k == pts.size() - 1:
			return pts[k - 1].lerp(pts[k], clampf(goal / maxf(seg, 1e-6), 0.0, 1.0))
		goal -= seg
	return pts[pts.size() - 1]


# --- Zusammensetzen ---

## Farbe und Relief einer Ebene an ihren Platz im großen Bild schreiben.
func _blit(layer: Layer, index: int) -> void:
	var ox := (index % GRID_X) * SIZE
	var oy := (index / GRID_X) * SIZE
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var a := 1.0 if layer.opaque else layer.color[i * 4 + 3]
			_albedo.set_pixel(ox + x, oy + y, Color(
				clampf(layer.color[i * 4], 0.0, 1.0),
				clampf(layer.color[i * 4 + 1], 0.0, 1.0),
				clampf(layer.color[i * 4 + 2], 0.0, 1.0),
				clampf(a, 0.0, 1.0)))
			var xl := posmod(x - 1, SIZE) if layer.opaque else maxi(x - 1, 0)
			var xr := (x + 1) % SIZE if layer.opaque else mini(x + 1, SIZE - 1)
			var yu := posmod(y - 1, SIZE) if layer.opaque else maxi(y - 1, 0)
			var yd := (y + 1) % SIZE if layer.opaque else mini(y + 1, SIZE - 1)
			var left := layer.height[y * SIZE + xl]
			var right := layer.height[y * SIZE + xr]
			var up := layer.height[yu * SIZE + x]
			var down := layer.height[yd * SIZE + x]
			var n := Vector3((left - right) * layer.normal_strength, (up - down) * layer.normal_strength, 1.0).normalized()
			_normal.set_pixel(ox + x, oy + y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))


func _save_table() -> void:
	var table := []
	for index in LAYERS.size():
		table.append({
			"index": index,
			"name": LAYERS[index][0],
			"roughness": LAYERS[index][1],
			"translucency": LAYERS[index][2],
		})
	var file := FileAccess.open(OUT_DIR + "layers.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"grid_x": GRID_X, "grid_y": GRID_Y, "layer_size": SIZE, "neutral": 0.8,
		"layers": table}, "\t"))
