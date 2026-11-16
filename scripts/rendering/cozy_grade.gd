class_name CozyGrade
extends RefCounted
## Farbabstimmung „Bilderbuch“ (seit der großen Überarbeitung): eine Farbtabelle (3D-LUT), die Godot nach dem
## Tonemapping auf jedes Bild legt (Environment.adjustment_color_correction). Sie macht, was Maler in gemütlichen
## Illustrationen tun:
## - Lichter warm (Pfirsich/Honig), Schatten leicht kühl (Lavendel) – warme und kühle Töne nebeneinander wirken lebendig
## - weiche, nie ganz schwarze Tiefen (wie Druckfarbe auf Papier)
## - sanfte S-Kurve (mehr Tiefe), etwas mehr Farbe in den Mitteltönen, sehr helle Stellen nicht grell
## Alle Werte in GameConfig (grade_*). Einmal beim Start gebaut (main.gd), Größe GRID³ Felder.

const GRID := 17


## Die Farbtabelle für die Umgebung (ImageTexture3D, GRID x GRID x GRID).
static func make_lut() -> ImageTexture3D:
	var layers: Array[Image] = []
	for b in GRID:
		var image := Image.create(GRID, GRID, false, Image.FORMAT_RGB8)
		for g in GRID:
			for r in GRID:
				var c := Color(float(r) / (GRID - 1), float(g) / (GRID - 1), float(b) / (GRID - 1))
				image.set_pixel(r, g, grade(c))
		layers.append(image)
	var lut := ImageTexture3D.new()
	lut.create(Image.FORMAT_RGB8, GRID, GRID, GRID, false, layers)
	return lut


## Eine Farbe (sRGB, 0–1) abstimmen.
static func grade(c: Color) -> Color:
	var v := Vector3(c.r, c.g, c.b)
	var luma := _luma(v)
	# 1. sanfte S-Kurve auf die Helligkeit (Farbton bleibt)
	var curved := _s_curve(luma, GameConfig.grade_contrast)
	if luma > 0.0001:
		v *= curved / luma
	luma = _luma(v)
	# 2. Mitteltöne etwas satter, sehr helle Stellen etwas ruhiger
	var mid := 1.0 - absf(luma * 2.0 - 1.0)
	var sat := 1.0 + GameConfig.grade_mid_saturation * mid - GameConfig.grade_highlight_calm * smoothstep(0.75, 1.0, luma)
	v = Vector3(luma, luma, luma).lerp(v, sat)
	# 3. Schatten Lavendel, Lichter warm (Teiltönung: verschiebt nur den Farbton, kaum die Helligkeit)
	var shadow := (1.0 - smoothstep(0.0, 0.5, luma)) * GameConfig.grade_shadow_amount
	var light := smoothstep(0.45, 1.0, luma) * GameConfig.grade_highlight_amount
	v += _tint_offset(GameConfig.grade_shadow_tint) * shadow
	v += _tint_offset(GameConfig.grade_highlight_tint) * light
	# 4. weiche Tiefen: Schwarz wird zu einem dunklen, warmen Violett
	var lift := Vector3(GameConfig.grade_black_lift.r, GameConfig.grade_black_lift.g, GameConfig.grade_black_lift.b)
	v = lift + v * (Vector3.ONE - lift)
	return Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0), clampf(v.z, 0.0, 1.0))


static func _luma(v: Vector3) -> float:
	return v.x * 0.2126 + v.y * 0.7152 + v.z * 0.0722


## S-Kurve um die Mitte 0,5: amount 0 = unverändert, 1 = deutlich.
static func _s_curve(x: float, amount: float) -> float:
	var s := x * x * (3.0 - 2.0 * x)
	return lerpf(x, s, amount)


## Farbton als Verschiebung um Grau (Helligkeit bleibt etwa gleich).
static func _tint_offset(tint: Color) -> Vector3:
	var t := Vector3(tint.r, tint.g, tint.b)
	return t - Vector3.ONE * _luma(t)
