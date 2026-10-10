extends SceneTree
## Erzeugt die gemeinsamen Stil-Texturen der Außenwelt (seit Etappe 4g).
##
## Alle Häuser (und später Treppe, Gassenende …) nutzen EIN Material mit einer
## Texturliste (Texture2DArray): Ziegel, Sandstein, Putz, Schiefer, Dachziegel, lackiertes Holz,
## Glas … Jede Ebene ist 512 x 512 Pixel groß und nahtlos (wiederholt sich ohne Kante).
## Ausgabe (assets/textures/style/):
##   house_albedo.png  Farben, 4 x 5 Ebenen (Zeile für Zeile). Alpha = "darf eingefärbt werden" (1 = ja, z. B. die
##                     Ziegel; 0 = nein, z. B. die Fugen)
##   house_normal.png  Oberflächen-Relief (Normal-Map), gleiche Anordnung
##   layers.json       Tabelle der Ebenen (Name, Nummer, Kachelgröße in Metern, Rauheit,
##                     Metall) – liest das Blender-Script tools/blender/style_lib.py
##
## Starten (Terminal, im Projektordner):
##   godot --headless -s res://scripts/tools/generate_style_textures.gd
## Danach importiert Godot die Bilder beim nächsten Öffnen von selbst.

const SIZE := 512
const GRID_X := 4
const GRID_Y := 5
## Einfärbbare Stellen werden auf diese mittlere Helligkeit gebracht (sRGB). Der Shader teilt
## wieder dadurch – so hat ein Haus im Mittel genau die Farbe, die man im Inspektor wählt.
const TINT_MEAN := 0.8
const OUT_DIR := "res://assets/textures/style/"

## Die Ebenen: Name, Kachelgröße (m), Rauheit, Metall. Die Reihenfolge ist die Nummer der Ebene –
## nur hinten anhängen, sonst passen fertige Modelle nicht mehr.
const LAYERS := [
	["brick", 0.9, 0.9, 0.0],
	["stone", 1.2, 0.85, 0.0],
	["render", 2.0, 0.9, 0.0],
	["slate", 1.0, 0.55, 0.0],
	["clay_tile", 1.0, 0.8, 0.0],
	["paint", 1.0, 0.6, 0.0],
	["stone_trim", 1.0, 0.8, 0.0],
	["metal", 1.0, 0.45, 0.5],
	["glass", 1.0, 0.06, 0.0],
	["fabric", 0.6, 0.95, 0.0],
	["terracotta", 1.0, 0.85, 0.0],
	["timber", 1.0, 0.75, 0.0],
	["gold", 1.0, 0.3, 1.0],
	["paving", 1.8, 0.9, 0.0],
	["plain", 1.0, 0.6, 0.0],
	["canvas", 0.5, 0.9, 0.0],
	["foliage", 0.6, 0.85, 0.0],
	["setts", 1.2, 0.85, 0.0],
	["boards", 1.2, 0.6, 0.0],
	["roughcast", 1.5, 0.95, 0.0],
]

var _albedo := Image.create_empty(SIZE * GRID_X, SIZE * GRID_Y, false, Image.FORMAT_RGBA8)
var _normal := Image.create_empty(SIZE * GRID_X, SIZE * GRID_Y, false, Image.FORMAT_RGB8)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for index in LAYERS.size():
		var started := Time.get_ticks_msec()
		var layer := _make_layer(LAYERS[index][0])
		_normalize_tint(layer)
		_blit(layer, index)
		print("Ebene %d %s: %d ms" % [index, LAYERS[index][0], Time.get_ticks_msec() - started])
	_albedo.save_png(OUT_DIR + "house_albedo.png")
	_normal.save_png(OUT_DIR + "house_normal.png")
	_save_table()
	print("Stil-Texturen gespeichert in ", OUT_DIR)
	quit()


## Eine Ebene: Farbe (RGBA, 0..1) und Höhe (0..1) je Pixel.
class Layer:
	var color := PackedFloat32Array()
	var height := PackedFloat32Array()
	var normal_strength := 2.0

	func _init() -> void:
		color.resize(SIZE * SIZE * 4)
		height.resize(SIZE * SIZE)

	func set_px(i: int, c: Color, h: float) -> void:
		color[i * 4] = c.r
		color[i * 4 + 1] = c.g
		color[i * 4 + 2] = c.b
		color[i * 4 + 3] = c.a
		height[i] = h


func _make_layer(layer_name: String) -> Layer:
	match layer_name:
		"brick":
			return _brick()
		"stone":
			return _ashlar()
		"render":
			return _render()
		"slate":
			return _roof_tiles(4, 8, Color(0.25, 0.27, 0.31), 0.16, 0.004, false)
		"clay_tile":
			return _roof_tiles(6, 10, Color(0.56, 0.29, 0.19), 0.2, 0.003, true)
		"paint":
			return _grain(Color(0.92, 0.92, 0.92, 1.0), 0.05, 0.4)
		"stone_trim":
			return _mottled(Color(0.81, 0.77, 0.67, 0.0), 0.06, 0.05, 11)
		"metal":
			return _mottled(Color(0.11, 0.11, 0.12, 0.0), 0.1, 0.03, 12)
		"glass":
			return _glass()
		"fabric":
			return _fabric()
		"terracotta":
			return _mottled(Color(0.6, 0.33, 0.22, 0.0), 0.1, 0.08, 13)
		"timber":
			return _grain(Color(0.24, 0.16, 0.1, 0.0), 0.18, 1.2)
		"gold":
			return _mottled(Color(0.85, 0.66, 0.3, 0.0), 0.08, 0.02, 14)
		"paving":
			return _paving()
		"plain":
			return _mottled(Color(1.0, 1.0, 1.0, 1.0), 0.0, 0.0, 15)
		"canvas":
			return _canvas()
		"foliage":
			return _foliage()
		"setts":
			return _setts()
		"boards":
			return _boards()
		"roughcast":
			return _roughcast()
	push_error("Unbekannte Ebene " + layer_name)
	return Layer.new()


# --- Rauschen (nahtlos: ganzzahlige Frequenzen, Gitter wiederholt sich) ---

static func _hash(ix: int, iy: int, seed: int) -> float:
	var h := (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


## Wertrauschen 0..1 an der Stelle (u, v) im Bereich 0..1, wiederholt sich nach 1.
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
	var a := lerpf(_hash(x0, y0, seed), _hash(x1, y0, seed), fx)
	var b := lerpf(_hash(x0, y1, seed), _hash(x1, y1, seed), fx)
	return lerpf(a, b, fy)


## Mehrere Rauschstufen übereinander (grob bis fein), Ergebnis 0..1.
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


## Ein Rauschfeld für die ganze Ebene (schneller als jedes Mal neu rechnen).
static func _field(freq: int, octaves: int, seed: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			out[y * SIZE + x] = _fbm(float(x) / SIZE, float(y) / SIZE, freq, octaves, seed)
	return out


# --- Die Ebenen ---

## Ziegel im Läuferverband (englisches Format: 21,5 x 6,5 cm + 1 cm Fuge). Kachel 0,9 m:
## 4 Steine nebeneinander, 12 Schichten. Steine einfärbbar, Fugen hell und fest.
func _brick() -> Layer:
	var layer := Layer.new()
	var tile := 0.9
	var courses := 12
	var per_row := 4
	var fine := _field(64, 3, 1)
	var wash := _field(4, 3, 2)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var row := floori(v * courses)
			var bu := u * per_row + (0.5 if row % 2 == 1 else 0.0)
			var col := posmod(floori(bu), per_row)
			var fu := bu - floorf(bu)
			var fv := v * courses - row
			var edge := minf(minf(fu, 1.0 - fu) * tile / per_row, minf(fv, 1.0 - fv) * tile / courses)
			var jitter := (fine[i] - 0.5) * 0.003
			var brick := smoothstep(0.004, 0.0065, edge + jitter)
			var r1 := _hash(col, row, 5)
			var r2 := _hash(col, row, 6)
			var tone := (0.72 + 0.22 * r1) * (0.92 + 0.08 * wash[i]) * (0.95 + 0.08 * fine[i])
			# Einzelne dunkel gebrannte Steine
			if _hash(col, row, 7) > 0.88:
				tone *= 0.72
			var warm := (r2 - 0.5) * 0.08
			var stone := Color(tone * (1.0 + warm), tone, tone * (1.0 - warm), 1.0)
			# Kanten der Steine etwas dunkler (abgegriffen)
			stone = stone * lerpf(0.82, 1.0, smoothstep(0.004, 0.012, edge))
			var mortar_tone := 0.68 + 0.1 * fine[i]
			var mortar := Color(mortar_tone * 1.03, mortar_tone, mortar_tone * 0.92, 0.0)
			var c := mortar.lerp(stone, brick)
			c.a = 1.0 if brick > 0.5 else 0.0
			layer.set_px(i, c, 0.35 + 0.6 * brick + 0.05 * fine[i])
	return layer


## Sandstein-Quader (60 x 30 cm, versetzt), Kachel 1,2 m. Steine einfärbbar.
func _ashlar() -> Layer:
	var layer := Layer.new()
	var tile := 1.2
	var rows := 4
	var per_row := 2
	var fine := _field(96, 3, 21)
	var mottle := _field(8, 4, 22)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var row := floori(v * rows)
			var bu := u * per_row + (0.5 if row % 2 == 1 else 0.0)
			var col := posmod(floori(bu), per_row)
			var fu := bu - floorf(bu)
			var fv := v * rows - row
			var edge := minf(minf(fu, 1.0 - fu) * tile / per_row, minf(fv, 1.0 - fv) * tile / rows)
			var block := smoothstep(0.003, 0.005, edge)
			var tone := (0.9 + 0.1 * _hash(col, row, 23)) * (0.86 + 0.18 * mottle[i]) * (0.95 + 0.1 * fine[i])
			var stone := Color(tone, tone, tone, 1.0) * lerpf(0.88, 1.0, smoothstep(0.003, 0.02, edge))
			var joint := Color(0.6, 0.58, 0.53, 0.0)
			var c := joint.lerp(stone, block)
			c.a = 1.0 if block > 0.5 else 0.0
			layer.set_px(i, c, 0.5 + 0.4 * block * smoothstep(0.003, 0.015, edge) + 0.1 * fine[i])
	return layer


## Glatter Putz mit leichten Flecken, Kachel 2 m. Einfärbbar.
func _render() -> Layer:
	var layer := Layer.new()
	var fine := _field(128, 2, 31)
	var mottle := _field(6, 4, 32)
	for i in SIZE * SIZE:
		var tone := (0.88 + 0.12 * mottle[i]) * (0.97 + 0.05 * fine[i])
		layer.set_px(i, Color(tone, tone, tone, 1.0), 0.5 + 0.3 * fine[i] + 0.2 * mottle[i])
	layer.normal_strength = 0.8
	return layer


## Dachdeckung aus Platten (Schiefer oder Tonziegel): "across" Platten nebeneinander,
## "courses" Reihen; jede Reihe überlappt die darunter (Bildzeile nach unten = dachabwärts).
func _roof_tiles(across: int, courses: int, base: Color, variation: float, gap: float, cambered: bool) -> Layer:
	var layer := Layer.new()
	var fine := _field(64, 3, 41)
	var moss := _field(8, 3, 42)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var row := floori(v * courses)
			var bu := u * across + (0.5 if row % 2 == 1 else 0.0)
			var col := posmod(floori(bu), across)
			var fu := bu - floorf(bu)
			var fv := v * courses - row
			var side := minf(fu, 1.0 - fu) / across
			var joint := smoothstep(gap * 0.5, gap, side)
			var r := _hash(col, row, 43)
			var tone := 1.0 + (r - 0.5) * 2.0 * variation
			var c := Color(base.r * tone * (1.0 + (_hash(col, row, 44) - 0.5) * 0.12), base.g * tone,
				base.b * tone * (1.0 + (_hash(col, row, 45) - 0.5) * 0.12), 0.0)
			c = c * (0.92 + 0.14 * fine[i])
			# Schatten unter der Kante der Reihe darüber, Wölbung bei Tonziegeln
			c = c * lerpf(0.55, 1.0, smoothstep(0.0, 0.22, fv))
			if cambered:
				c = c * (0.9 + 0.1 * sin(fu * PI))
			c = c * lerpf(0.35, 1.0, joint)
			# Ein Hauch Flechten/Moos
			var lichen := smoothstep(0.62, 0.8, moss[i]) * 0.25
			c = c.lerp(Color(0.42, 0.44, 0.3, 0.0), lichen)
			c.a = 0.0
			var h := 0.3 + 0.6 * fv
			if cambered:
				h += 0.15 * sin(fu * PI)
			layer.set_px(i, c, h * lerpf(0.4, 1.0, joint) + 0.04 * fine[i])
	layer.normal_strength = 3.0
	return layer


## Holz mit Maserung (waagerecht, entlang u): lackiert (einfärbbar) oder Balken (fest).
func _grain(base: Color, amount: float, relief: float) -> Layer:
	var layer := Layer.new()
	var streaks := PackedFloat32Array()
	streaks.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			# Gestreckt: wenig Änderung entlang u, viel quer dazu
			streaks[y * SIZE + x] = _fbm(float(x) / SIZE, float(y) / SIZE * 1.0, 4, 2, 51) * 0.5 \
				+ _value_noise(float(x) / SIZE, float(y) / SIZE, 2, 52) * 0.2 \
				+ _fbm(float(x) / SIZE, float(y) / SIZE, 2, 1, 53) * 0.3
	var lines := _field(8, 2, 54)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var v := float(y) / SIZE
			var ring := 0.5 + 0.5 * sin((v * 48.0 + streaks[i] * 6.0 + lines[i] * 2.0) * TAU)
			var tone := 1.0 - amount * ring
			var c := Color(base.r * tone, base.g * tone, base.b * tone, base.a)
			layer.set_px(i, c, 0.5 + 0.15 * ring * relief)
	layer.normal_strength = 1.0
	return layer


## Gleichmäßig mit leichten Flecken (Stein, Metall, Terrakotta, Gold, Weiß).
func _mottled(base: Color, mottle_amount: float, fine_amount: float, seed: int) -> Layer:
	var layer := Layer.new()
	var fine := _field(96, 2, seed * 7)
	var mottle := _field(6, 4, seed * 7 + 1)
	for i in SIZE * SIZE:
		var tone := (1.0 - mottle_amount + 2.0 * mottle_amount * mottle[i]) * (1.0 - fine_amount + 2.0 * fine_amount * fine[i])
		layer.set_px(i, Color(base.r * tone, base.g * tone, base.b * tone, base.a), 0.5 + 0.25 * fine[i] + 0.25 * mottle[i])
	layer.normal_strength = 0.6
	return layer


## Altes Fensterglas: dunkel, mit leichten Wellen (spiegelt den Himmel unruhig).
func _glass() -> Layer:
	var layer := Layer.new()
	var wave := _field(5, 3, 61)
	for i in SIZE * SIZE:
		var tone := 0.85 + 0.3 * wave[i]
		layer.set_px(i, Color(0.07 * tone, 0.085 * tone, 0.1 * tone, 0.0), wave[i])
	layer.normal_strength = 0.6
	return layer


## Vorhangstoff: helles Leinen mit senkrechten Falten (Kachel 0,6 m, 5 Falten).
func _fabric() -> Layer:
	var layer := Layer.new()
	var fine := _field(128, 2, 71)
	var drift := _field(4, 2, 72)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE
			var fold := 0.5 + 0.5 * sin((u * 5.0 + drift[i] * 0.4) * TAU)
			var tone := (0.8 + 0.2 * fold) * (0.96 + 0.06 * fine[i])
			layer.set_px(i, Color(0.88 * tone, 0.85 * tone, 0.78 * tone, 0.0), fold * 0.8 + 0.2 * fine[i])
	layer.normal_strength = 2.5
	return layer


## Große Gehwegplatten (Kachel 1,8 m, 3 x 4 Platten, versetzt), grauer Stein.
func _paving() -> Layer:
	var layer := Layer.new()
	var tile := 1.8
	var rows := 4
	var per_row := 3
	var fine := _field(96, 3, 81)
	var mottle := _field(6, 3, 82)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var row := floori(v * rows)
			var bu := u * per_row + (0.33 if row % 2 == 1 else 0.0)
			var col := posmod(floori(bu), per_row)
			var fu := bu - floorf(bu)
			var fv := v * rows - row
			var edge := minf(minf(fu, 1.0 - fu) * tile / per_row, minf(fv, 1.0 - fv) * tile / rows)
			var slab := smoothstep(0.003, 0.006, edge)
			var tone := (0.9 + 0.14 * _hash(col, row, 83)) * (0.88 + 0.16 * mottle[i]) * (0.94 + 0.1 * fine[i])
			var c := Color(0.56 * tone, 0.54 * tone, 0.51 * tone, 0.0) * lerpf(0.4, 1.0, slab)
			layer.set_px(i, c, 0.4 + 0.5 * slab + 0.1 * fine[i])
	return layer


## Markisenstoff mit Streifen (12,5 cm): jeder zweite Streifen einfärbbar, die anderen cremeweiß.
func _canvas() -> Layer:
	var layer := Layer.new()
	var fine := _field(128, 2, 91)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE
			var stripe := posmod(floori(u * 4.0), 2) == 0
			var weave := 0.95 + 0.07 * fine[i] + 0.03 * sin(float(y) * 1.7)
			var c := Color(0.95 * weave, 0.95 * weave, 0.95 * weave, 1.0) if stripe \
				else Color(0.9 * weave, 0.86 * weave, 0.78 * weave, 0.0)
			layer.set_px(i, c, 0.5 + 0.3 * fine[i])
	layer.normal_strength = 1.0
	return layer


## Laub (Buchsbaum, Hecken, Blumenkästen): kleine Blätter in Büscheln, einfärbbar (grün).
func _foliage() -> Layer:
	var layer := Layer.new()
	var clumps := _field(12, 3, 101)
	var cells := 40
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE * cells
			var v := float(y) / SIZE * cells
			# Nächstes Blatt (Zellenrauschen, nahtlos)
			var best := 9.0
			var best_id := 0
			var cx := floori(u)
			var cy := floori(v)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := cx + ox
					var gy := cy + oy
					var px := gx + _hash(posmod(gx, cells), posmod(gy, cells), 102)
					var py := gy + _hash(posmod(gx, cells), posmod(gy, cells), 103)
					var dist := Vector2(u - px, (v - py) * 1.4).length()
					if dist < best:
						best = dist
						best_id = posmod(gx, cells) * 131 + posmod(gy, cells)
			var leaf := 1.0 - smoothstep(0.25, 0.75, best)
			var tone := (0.55 + 0.45 * leaf) * (0.75 + 0.35 * clumps[i]) * (0.85 + 0.25 * _hash(best_id, 0, 104))
			var hue := (_hash(best_id, 1, 105) - 0.5) * 0.25
			layer.set_px(i, Color(tone * (1.0 + hue), tone, tone * (1.0 - hue * 0.5), 1.0), leaf * 0.7 + clumps[i] * 0.3)
	layer.normal_strength = 3.0
	return layer


## Kopfsteinpflaster (Granit-Setzsteine 15 x 10 cm, Kachel 1,2 m), fest grau-braun.
func _setts() -> Layer:
	var layer := Layer.new()
	var tile := 1.2
	var rows := 12
	var per_row := 8
	var fine := _field(96, 3, 111)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var row := floori(v * rows)
			var bu := u * per_row + _hash(0, row, 112) * 0.6
			var col := posmod(floori(bu), per_row)
			var fu := bu - floorf(bu)
			var fv := v * rows - row
			var edge := minf(minf(fu, 1.0 - fu) * tile / per_row, minf(fv, 1.0 - fv) * tile / rows)
			var dome := smoothstep(0.0, 0.03, edge)
			var stone := smoothstep(0.004, 0.009, edge)
			var r := _hash(col, row, 113)
			var tone := (0.75 + 0.3 * r) * (0.9 + 0.15 * fine[i])
			var c := Color(0.5 * tone, 0.47 * tone, 0.44 * tone * (0.95 + 0.1 * _hash(col, row, 114)), 0.0)
			c = c * lerpf(0.35, 1.0, stone)
			layer.set_px(i, c, 0.2 + 0.7 * dome * stone + 0.1 * fine[i])
	layer.normal_strength = 3.0
	return layer


## Dielen (14 cm breit, versetzte Stöße), einfärbbar (Holzton).
func _boards() -> Layer:
	var layer := Layer.new()
	var tile := 1.2
	var count := 8
	var grain := _field(4, 3, 121)
	var fine := _field(128, 2, 122)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var row := floori(v * count)
			var fv := v * count - row
			var bu := u * 2.0 + _hash(0, row, 123)
			var plank := posmod(floori(bu), 2)
			var fu := bu - floorf(bu)
			var edge := minf(minf(fv, 1.0 - fv) * tile / count, minf(fu, 1.0 - fu) * tile / 2.0)
			var gap := smoothstep(0.001, 0.003, edge)
			var ring := 0.5 + 0.5 * sin((u * 22.0 + grain[i] * 4.0 + _hash(plank, row, 124) * 5.0) * TAU)
			var tone := (0.82 + 0.18 * _hash(plank, row, 125)) * (0.9 + 0.1 * ring) * (0.96 + 0.06 * fine[i])
			var c := Color(tone, tone, tone, 1.0) * lerpf(0.4, 1.0, gap)
			c.a = 1.0 if gap > 0.5 else 0.0
			layer.set_px(i, c, 0.3 + 0.6 * gap + 0.1 * ring)
	layer.normal_strength = 1.5
	return layer


## Rauputz (Kieselputz), einfärbbar.
func _roughcast() -> Layer:
	var layer := Layer.new()
	var fine := _field(160, 2, 131)
	var grit := _field(64, 2, 132)
	var mottle := _field(6, 3, 133)
	for i in SIZE * SIZE:
		var bump := smoothstep(0.45, 0.8, grit[i]) * 0.6 + fine[i] * 0.4
		var tone := (0.85 + 0.15 * bump) * (0.92 + 0.1 * mottle[i])
		layer.set_px(i, Color(tone, tone, tone, 1.0), bump)
	layer.normal_strength = 2.5
	return layer


## Einfärbbare Stellen (Alpha 1) auf die mittlere Helligkeit TINT_MEAN bringen.
func _normalize_tint(layer: Layer) -> void:
	var total := 0.0
	var count := 0
	for i in SIZE * SIZE:
		if layer.color[i * 4 + 3] > 0.5:
			total += (layer.color[i * 4] + layer.color[i * 4 + 1] + layer.color[i * 4 + 2]) / 3.0
			count += 1
	if count == 0:
		return
	var factor := TINT_MEAN / (total / count)
	for i in SIZE * SIZE:
		if layer.color[i * 4 + 3] > 0.5:
			for k in 3:
				layer.color[i * 4 + k] *= factor


# --- Zusammensetzen ---

## Farbe und Normal-Map einer Ebene an ihren Platz im großen Bild schreiben. Die Höhe wird dabei
## leicht als Schattierung in die Farbe gerechnet (Vertiefungen etwas dunkler).
func _blit(layer: Layer, index: int) -> void:
	var ox := (index % GRID_X) * SIZE
	var oy := (index / GRID_X) * SIZE
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var h := layer.height[i]
			var occlusion := lerpf(0.86, 1.0, clampf(h * 1.4, 0.0, 1.0))
			_albedo.set_pixel(ox + x, oy + y, Color(
				clampf(layer.color[i * 4] * occlusion, 0.0, 1.0),
				clampf(layer.color[i * 4 + 1] * occlusion, 0.0, 1.0),
				clampf(layer.color[i * 4 + 2] * occlusion, 0.0, 1.0),
				layer.color[i * 4 + 3]))
			# Steigung der Höhe (nahtlos: am Rand geht es auf der anderen Seite weiter)
			var left := layer.height[y * SIZE + posmod(x - 1, SIZE)]
			var right := layer.height[y * SIZE + (x + 1) % SIZE]
			var up := layer.height[posmod(y - 1, SIZE) * SIZE + x]
			var down := layer.height[((y + 1) % SIZE) * SIZE + x]
			var n := Vector3((left - right) * layer.normal_strength, (up - down) * layer.normal_strength, 1.0).normalized()
			_normal.set_pixel(ox + x, oy + y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))


func _save_table() -> void:
	var table := []
	for index in LAYERS.size():
		table.append({
			"index": index,
			"name": LAYERS[index][0],
			"tile_size": LAYERS[index][1],
			"roughness": LAYERS[index][2],
			"metallic": LAYERS[index][3],
		})
	var file := FileAccess.open(OUT_DIR + "layers.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"grid_x": GRID_X, "grid_y": GRID_Y, "layer_size": SIZE,
		"tint_mean": TINT_MEAN, "layers": table}, "\t"))
