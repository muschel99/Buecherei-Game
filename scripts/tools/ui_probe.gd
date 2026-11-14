extends Node
## Prüfbilder einzelner Oberflächen ohne die ganze Welt (seit Testrunde 7b): viel schneller als screenshot_tour.
## Start: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 --audio-driver Dummy
##   res://scenes/tools/ui_probe.tscn -- pause:<Doppelseite> [pause:<…> …]
## Bilder: screenshots/ui_probe/<name>.png

const OUT := "res://screenshots/ui_probe/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var back := ColorRect.new()
	back.color = Color(0.42, 0.36, 0.3)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("pause:"):
			var menu := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
			add_child(menu)
			for i in 3:
				await get_tree().process_frame
			menu.call("open_instant", arg.trim_prefix("pause:"))
			for i in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var name_ := arg.replace(":", "_").replace(" ", "_").replace("&", "und")
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name_ + ".png"))
			print("Bild: ", name_)
			menu.queue_free()
			await get_tree().process_frame
		elif arg.begins_with("open:"):
			# Aufklapp-Animation: Bilder zu diesen Zeitpunkten (Sekunden), z. B. open:0.2,0.5,0.8
			var menu := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
			add_child(menu)
			for i in 3:
				await get_tree().process_frame
			menu.call("open")
			var started := Time.get_ticks_msec()
			for t_text in arg.trim_prefix("open:").split(","):
				var t := float(t_text)
				while (Time.get_ticks_msec() - started) / 1000.0 < t:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "open_%s.png" % t_text))
				print("Bild: open_", t_text)
			get_tree().paused = false
			menu.queue_free()
	get_tree().quit()
