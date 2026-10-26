extends Node3D
## Ansicht der Chibi-Figuren (scenes/tools/chibi_lineup.tscn): alle sechs Grundkörper, je dünn,
## mittel und dick (hintereinander), jede anders angezogen und frisiert. Im laufenden Spiel (F6) wechseln die Gesichtsausdrücke
## alle paar Sekunden, die vordere Reihe spricht ab und zu, alle blinzeln.

const CHARACTER := preload("res://scenes/characters/chibi_character.tscn")
const SPACING := 0.85
const ROW_DEPTH := 1.4
const EXPRESSION_TIME := 2.5

var _characters: Array[ChibiCharacter] = []
var _t := 0.0
var _step := 0


func _ready() -> void:
	var shapes := [0.0, -1.0, 1.0]
	for row in shapes.size():
		for i in ChibiCharacter.Figure.size():
			var c: ChibiCharacter = CHARACTER.instantiate()
			c.figure = i as ChibiCharacter.Figure
			c.body_shape = shapes[row]
			var colors := GameConfig.chibi_skin_colors
			c.skin_color = colors[(i + row * 2) % colors.size()]
			c.iris_color = GameConfig.chibi_iris_colors[(i + row) % GameConfig.chibi_iris_colors.size()]
			c.eye_shape = ((i + row) % 3) as ChibiCharacter.EyeShape
			_dress(c, i, row)
			c.position = Vector3((i - 2.5) * SPACING, 0.0, -row * ROW_DEPTH)
			add_child(c)
			_characters.append(c)


## Kleidung und Frisur: jede Figur anders (Farben aus GameConfig).
func _dress(c: ChibiCharacter, i: int, row: int) -> void:
	var k := i + row * 2
	c.top = ChibiCharacter.Top.TSHIRT if k % 2 == 0 else ChibiCharacter.Top.SWEATER
	if c.is_female():
		c.bottom = ChibiCharacter.Bottom.SKIRT if (i + row) % 2 == 1 else ChibiCharacter.Bottom.TROUSERS
		c.hair = [ChibiCharacter.Hair.BOB, ChibiCharacter.Hair.PIGTAILS, ChibiCharacter.Hair.BUN][(i + row) % 3]
	else:
		c.bottom = ChibiCharacter.Bottom.TROUSERS
		c.hair = ChibiCharacter.Hair.SHORT
	c.shoes = true
	c.top_color = GameConfig.chibi_top_colors[k % GameConfig.chibi_top_colors.size()]
	c.bottom_color = GameConfig.chibi_bottom_colors[(k + 3) % GameConfig.chibi_bottom_colors.size()]
	c.shoe_color = GameConfig.chibi_shoe_colors[k % GameConfig.chibi_shoe_colors.size()]
	c.hair_color = GameConfig.chibi_hair_colors[(k + 1) % GameConfig.chibi_hair_colors.size()]
	c.brow_color = c.hair_color.darkened(0.25)


func _process(delta: float) -> void:
	_t += delta
	if _t < EXPRESSION_TIME:
		return
	_t = 0.0
	_step += 1
	var count := ChibiCharacter.Mood.size()
	for i in _characters.size():
		var c := _characters[i]
		c.mood = ((i + _step) % count) as ChibiCharacter.Mood
		c.talking = i < 6 and (_step + i) % 3 == 0
		c.look = Vector2(sin(_step * 1.3 + i), cos(_step * 0.7 + i) * 0.5)
