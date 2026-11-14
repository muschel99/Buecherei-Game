extends Node
## Messwerkzeug (seit Etappe 8): Wie lange braucht der Start? Misst Engine + Autoloads (bis hierher), Laden der Hauptszene,
## Erzeugen, _ready aller Knoten und die ersten Bilder. Mit --profile_nodes: _ready-Zeit der großen Knoten einzeln.
##   godot --headless --path . res://scenes/tools/startup_probe.tscn
##   xvfb-run -a godot --path . res://scenes/tools/startup_probe.tscn   (mit Grafik: Shader-Vorbereitung zählt mit)

var _t0 := 0


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	print("START bis Probe (Engine + Autoloads): %d ms" % _t0)
	_run.call_deferred()


func _run() -> void:
	var t := Time.get_ticks_msec()
	var packed := load("res://scenes/main.tscn") as PackedScene
	var t_load := Time.get_ticks_msec()
	print("START Laden main.tscn (Ressourcen): %d ms" % (t_load - t))
	var main := packed.instantiate()
	var t_inst := Time.get_ticks_msec()
	print("START Erzeugen: %d ms" % (t_inst - t_load))
	_watch(main, 0)
	get_tree().root.add_child(main)
	var t_ready := Time.get_ticks_msec()
	print("START add_child/_ready: %d ms" % (t_ready - t_inst))
	var times: Array = []
	for node: Node in _marks.keys():
		if _marks[node].has("end"):
			times.append([_marks[node].end - _marks[node].begin, node.name])
	times.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for row: Array in times.slice(0, 15):
		print("   _ready %5d ms  %s" % [row[0], row[1]])
	for i in 5:
		var f := Time.get_ticks_msec()
		await get_tree().process_frame
		print("START Bild %d: %d ms" % [i + 1, Time.get_ticks_msec() - f])
	print("START gesamt bis spielbar: %d ms" % Time.get_ticks_msec())
	for pair: Array in [["Oberfläche", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS],
			["Netze", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH],
			["Flächen", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE],
			["beim Zeichnen", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW],
			["Spezialisierung", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]]:
		print("START Pipelines %s: %d" % [pair[0], RenderingServer.get_rendering_info(pair[1])])
	print("START Zeichenaufrufe: %d, Dreiecke: %d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()


var _marks := {}


## Große Knoten bis Tiefe 3: Zeit von ENTER_TREE bis READY (enthält ihre Kinder).
func _watch(node: Node, depth: int) -> void:
	if depth > 3:
		return
	_marks[node] = {}
	node.tree_entered.connect(func() -> void: _marks[node]["begin"] = Time.get_ticks_msec(), CONNECT_ONE_SHOT)
	node.ready.connect(func() -> void: _marks[node]["end"] = Time.get_ticks_msec(), CONNECT_ONE_SHOT)
	for child in node.get_children():
		_watch(child, depth + 1)
