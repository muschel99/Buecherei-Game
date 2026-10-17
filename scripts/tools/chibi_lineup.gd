extends Node3D
## Ansicht der Chibi-Figuren (scenes/tools/chibi_lineup.tscn): alle sechs Grundkörper, je dünn,
## mittel und dick (hintereinander). Im laufenden Spiel (F6) wechseln die Gesichtsausdrücke
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
			c.position = Vector3((i - 2.5) * SPACING, 0.0, -row * ROW_DEPTH)
			add_child(c)
			_characters.append(c)


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
