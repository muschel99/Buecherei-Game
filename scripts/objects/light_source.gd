class_name LightSource
extends Node3D
## Gemeinsamer Baustein für alles, was Licht abgibt (Lampen, Kerzen, Laternen …).
##
## So wird ein Objekt zur schaltbaren Lichtquelle:
## 1. Dieses Script an den obersten Knoten der Szene hängen.
## 2. Einen Interactable-Knoten mit Kollisionsform hinzufügen (für die Taste E).
## Den Rest findet das Script selbst: alle Lichter (OmniLight3D, SpotLight3D …) und
## alle leuchtenden Teile (Materialien mit "Emission" – auch Bilderbuch-Materialien mit dem
## Shader-Wert emission_energy, z. B. in einem .glb-Modell). Mehr ist nicht nötig.
## Flammen schrumpfen beim Löschen: In eigenen Modellen ist darum jede Flamme ein eigenes Teil
## mit dem Ursprung am Docht.
##
## Elektrische Lampen blenden sanft auf und ab. Bei Flammen (Kerzen, Laternen)
## flackert die Flamme beim Löschen kurz auf und erlischt dann.
## Seit Etappe 6d bewegen sich alle Flammen wie Feuer: Jedes Teil mit dem Material „flame“ bekommt die
## gemeinsame Flamme (assets/materials/flame.tres, Shader flame.gdshader: zittert, flackert, wiegt sich,
## jede etwas anders), und das Licht flackert passend mit (GameConfig.flame_light_flicker). Neue Kerzen
## und Feuer brauchen dafür nichts weiter als ein Flammen-Teil mit diesem Materialnamen.

enum Kind {
	ELECTRIC,  ## Elektrische Lampe: wird auch vom Lichtschalter geschaltet
	FLAME,  ## Kerze oder Laterne: wird einzeln angezündet und gelöscht
}

## Elektrisch oder Flamme?
@export var kind: Kind = Kind.ELECTRIC
## Leuchtet es beim Spielstart?
@export var is_on: bool = true
## Hinweistext zum Einschalten (leer = Standardtext).
@export var prompt_turn_on: String = ""
## Hinweistext zum Ausschalten (leer = Standardtext).
@export var prompt_turn_off: String = ""

enum ShadowImportance {
	NONE,  ## Wirft nie Schatten
	IMPORTANT,  ## Wirft ab Grafikstufe "Mittel" Schatten (z. B. Stehlampen)
	OPTIONAL,  ## Wirft nur bei Grafikstufe "Hoch" Schatten (z. B. Deckenlampen)
}
## Geräusch, solange es leuchtet (Name im Audio-System, z. B. "ambience/fireplace"; leer = still).
@export var loop_sound: String = ""

## Wie wichtig die Schatten dieser Lampe sind (Schatten kosten viel Rechenleistung).
## Lichter, die in der Szene ohne Schatten angelegt sind (Kerzen), bleiben immer ohne.
@export var shadow_importance: ShadowImportance = ShadowImportance.IMPORTANT

var _lights: Array[Light3D] = []
var _light_energy: Array[float] = []
var _light_has_shadow: Array[bool] = []
var _glow_meshes: Array[MeshInstance3D] = []
## Ist das leuchtende Teil eine Flamme (wächst, schrumpft, verschwindet) oder nur glühend (Glut, Ziegel im
## Feuerschein, Laternenglas – hört bloß auf zu leuchten)? Seit Etappe 6f getrennt.
var _glow_is_flame: Array[bool] = []
## Funken über einem Kaminfeuer (seit Etappe 6f, an Markern „SparkSpot…“)
var _sparks: Array[GPUParticles3D] = []
var _glow_materials: Array[Material] = []
## Name des Helligkeits-Werts je leuchtendem Material (normales oder Shader-Material).
var _glow_properties: Array[String] = []
var _glow_energy: Array[float] = []
var _glow_scale: Array[Vector3] = []
var _interactable: Interactable = null
var _tween: Tween
var _flame_tweens: Array[Tween] = []
## Flackern des Lichts (nur Flammen): eigener Takt je Lichtquelle
var _flicker_phase := 0.0
var _flicker_time := 0.0
var _sound: AudioStreamPlayer3D

const FLAME_MATERIAL := preload("res://assets/materials/flame.tres")
## Kaminfeuer (Material „fire“, seit Etappe 6f): lodernde Feuerzungen
const FIRE_MATERIAL := preload("res://assets/materials/fire.tres")
## Funken über einem Kaminfeuer (Marker „SparkSpot…“ im Modell, seit Etappe 6f)
const SPARK_PREFIX := "SparkSpot"


func _ready() -> void:
	for node in find_children("*", "Light3D", true, false):
		_lights.append(node)
		_light_energy.append(node.light_energy)
		_light_has_shadow.append(node.shadow_enabled)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var material := mesh_instance.material_override as StandardMaterial3D
		if material and material.emission_enabled:
			# Eigene Kopie, damit jede Lampe unabhängig leuchtet
			material = material.duplicate()
			mesh_instance.material_override = material
			_add_glow(mesh_instance, material, "emission_energy_multiplier")
		elif mesh_instance.material_override == null and mesh_instance.mesh:
			# Teile eines Modells (.glb): jede leuchtende Fläche bekommt eine eigene Kopie
			for i in mesh_instance.mesh.get_surface_count():
				var surface_material := mesh_instance.get_active_material(i)
				var property := _glow_property(surface_material)
				if property.is_empty():
					continue
				if kind == Kind.FLAME and surface_material.resource_name in ["flame", "fire"]:
					# gemeinsame, bewegte Flamme bzw. lodernde Feuerzunge (Helligkeit wie im Modell, Höhe aus dem Netz)
					var source := FIRE_MATERIAL if surface_material.resource_name == "fire" else FLAME_MATERIAL
					var flame := source.duplicate() as ShaderMaterial
					if source == FLAME_MATERIAL:
						flame.set_shader_parameter("emission_energy", float(surface_material.get(property)))
					flame.set_shader_parameter("height", maxf(mesh_instance.get_aabb().end.y, 0.01))
					mesh_instance.set_surface_override_material(i, flame)
					_add_glow(mesh_instance, flame, "shader_parameter/emission_energy", true)
					continue
				surface_material = surface_material.duplicate()
				mesh_instance.set_surface_override_material(i, surface_material)
				_add_glow(mesh_instance, surface_material, property)
	for node in find_children("*", "Area3D", true, false):
		if node is Interactable:
			_interactable = node
			if not _interactable.interacted.is_connected(_on_interactable_interacted):
				_interactable.interacted.connect(_on_interactable_interacted)
			break
	for node in find_children(SPARK_PREFIX + "*", "Node3D", true, false):
		var particles := _make_sparks()
		(node as Node3D).add_child(particles)
		_sparks.append(particles)
	_flicker_phase = randf() * TAU
	if not loop_sound.is_empty():
		_sound = Audio.loop_at(self, loop_sound, 0.0, 9.0)
	_apply_state(false)
	_apply_shadow_quality()
	Settings.setting_changed.connect(_on_setting_changed)
	set_process(kind == Kind.FLAME and not _lights.is_empty())


## Flammen: das Licht flackert sanft (weiche Mischung aus Wellen, je Lichtquelle anders) – nur wenn es
## brennt und gerade nicht an- oder ausgeht.
func _process(delta: float) -> void:
	if not is_on or (_tween and _tween.is_running()):
		return
	_flicker_time += delta
	var t := _flicker_time
	var p := _flicker_phase
	var wobble := sin(t * 7.3 + p) * 0.45 + sin(t * 13.1 + p * 2.3) * 0.3 + sin(t * 2.9 + p * 0.7) * 0.25
	var factor := 1.0 + GameConfig.flame_light_flicker * wobble
	for i in _lights.size():
		_lights[i].light_energy = _light_energy[i] * factor


## Kleine glühende Funken, die aus dem Feuer aufsteigen und verglühen (Werte GameConfig.fire_spark_*).
func _make_sparks() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Sparks"
	particles.amount = GameConfig.fire_spark_amount
	particles.lifetime = GameConfig.fire_spark_lifetime
	particles.randomness = 0.7
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-0.3, -0.1, -0.3), Vector3(0.6, 0.6, 0.6))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.08
	process.direction = Vector3.UP
	process.spread = 25.0
	process.initial_velocity_min = GameConfig.fire_spark_speed * 0.5
	process.initial_velocity_max = GameConfig.fire_spark_speed
	process.gravity = Vector3(0.0, 0.05, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_scale = 3.0
	process.scale_min = 0.5
	process.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	ramp.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.albedo_color = Color(2.0, 1.4, 0.8)
	quad.material = look
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


func _add_glow(mesh_instance: MeshInstance3D, material: Material, property: String, is_flame := false) -> void:
	_glow_meshes.append(mesh_instance)
	_glow_is_flame.append(is_flame)
	_glow_materials.append(material)
	_glow_properties.append(property)
	_glow_energy.append(float(material.get(property)))
	_glow_scale.append(mesh_instance.scale)


## Welcher Wert macht dieses Material hell? Leer = es leuchtet nicht.
static func _glow_property(material: Material) -> String:
	if material is StandardMaterial3D and material.emission_enabled:
		return "emission_energy_multiplier"
	if material is ShaderMaterial:
		var energy = material.get_shader_parameter("emission_energy")
		if energy is float and energy > 0.0:
			return "shader_parameter/emission_energy"
	return ""


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "graphics/quality":
		_apply_shadow_quality()


## Schatten je nach Grafikstufe: nur wichtige Lampen, und günstigere Schattenart.
func _apply_shadow_quality() -> void:
	var preset := Settings.get_graphics_preset()
	var level: int = preset.lamp_shadows
	var allowed := shadow_importance != ShadowImportance.NONE and int(shadow_importance) <= level
	for i in _lights.size():
		_lights[i].shadow_enabled = _light_has_shadow[i] and allowed
		if _lights[i] is OmniLight3D:
			# Würfel = 6 Durchgänge je Lampe, Doppel-Paraboloid = 2 (etwas ungenauer)
			# (der einfache Renderer "Compatibility" kennt nur Würfel-Schatten)
			var cube: bool = preset.cube_shadows or RenderingServer.get_current_rendering_method() == "gl_compatibility"
			_lights[i].omni_shadow_mode = OmniLight3D.SHADOW_CUBE if cube else OmniLight3D.SHADOW_DUAL_PARABOLOID


## Elektrische Lampe? (nur die schaltet der Lichtschalter, siehe GameConfig)
func is_electric() -> bool:
	return kind == Kind.ELECTRIC


## Schaltet an oder aus (wird auch vom Lichtschalter benutzt).
func set_on(value: bool) -> void:
	if value == is_on:
		return
	is_on = value
	_apply_state(true)
	if kind == Kind.FLAME:
		# Streichholz/Ausblasen (Aufnahmen der Entwicklerin; fehlt eine, bleibt es still)
		Audio.play_at("lights/candle_on" if is_on else "lights/candle_off", global_position,
			GameConfig.candle_sound_volume_db, Audio.vary(0.05))


func _on_interactable_interacted(_interactor: Node) -> void:
	set_on(not is_on)


func _apply_state(animate: bool) -> void:
	_update_prompt()
	if _tween:
		_tween.kill()
	for flame_tween in _flame_tweens:
		flame_tween.kill()
	_flame_tweens.clear()
	if is_on:
		for light in _lights:
			light.visible = true
		for mesh in _glow_meshes:
			mesh.visible = true
	for particles in _sparks:
		particles.emitting = is_on
	if _sound:
		if is_on and not _sound.playing:
			_sound.play()
		elif not is_on:
			_sound.stop()

	if not animate:
		for i in _lights.size():
			_lights[i].light_energy = _light_energy[i] if is_on else 0.0
			_lights[i].visible = is_on
		for i in _glow_materials.size():
			_glow_materials[i].set(_glow_properties[i], _glow_energy[i] if is_on else 0.0)
			if kind == Kind.FLAME and _glow_is_flame[i]:
				_glow_meshes[i].visible = is_on
		return

	if kind == Kind.FLAME:
		_animate_flame()
	else:
		_animate_electric()


## Elektrisch: sanft überblenden.
func _animate_electric() -> void:
	var duration := GameConfig.light_fade_time
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for i in _lights.size():
		_tween.tween_property(_lights[i], "light_energy", _light_energy[i] if is_on else 0.0, duration)
	for i in _glow_materials.size():
		_tween.tween_property(_glow_materials[i], _glow_properties[i], _glow_energy[i] if is_on else 0.0, duration)
	if not is_on:
		_tween.chain().tween_callback(_hide_lights)


## Flamme: beim Löschen kurz aufflackern, dann klein werden und erlöschen.
## Beim Anzünden wächst die Flamme aus einem kleinen Funken.
func _animate_flame() -> void:
	var duration := GameConfig.flame_fade_time
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	if is_on:
		for i in _glow_meshes.size():
			if _glow_is_flame[i]:
				_glow_meshes[i].scale = _glow_scale[i] * 0.2
				_tween.tween_property(_glow_meshes[i], "scale", _glow_scale[i], duration * 0.7).set_ease(Tween.EASE_OUT)
			_tween.tween_property(_glow_materials[i], _glow_properties[i], _glow_energy[i], duration * 0.7)
		for i in _lights.size():
			_tween.tween_property(_lights[i], "light_energy", _light_energy[i], duration * 0.7)
		return

	var flicker := duration * 0.2
	for i in _glow_meshes.size():
		if not _glow_is_flame[i]:
			# Glut und Ziegel: nur langsam dunkler werden
			_tween.tween_property(_glow_materials[i], _glow_properties[i], 0.0, duration * 1.6)
			continue
		var stretched := _glow_scale[i] * Vector3(0.8, 1.3, 0.8)
		var gone := _glow_scale[i] * Vector3(0.3, 0.05, 0.3)
		var flame_tween := create_tween().set_trans(Tween.TRANS_SINE)
		_flame_tweens.append(flame_tween)
		flame_tween.tween_property(_glow_meshes[i], "scale", stretched, flicker)
		flame_tween.tween_property(_glow_meshes[i], "scale", gone, duration - flicker).set_ease(Tween.EASE_IN)
		_tween.tween_property(_glow_materials[i], _glow_properties[i], 0.0, duration)
	for i in _lights.size():
		_tween.tween_property(_lights[i], "light_energy", 0.0, duration)
	_tween.chain().tween_callback(_hide_lights)


## Ausgeschaltete Lichter ganz verstecken (spart Rechenleistung), Flammen ebenso.
func _hide_lights() -> void:
	for light in _lights:
		light.visible = false
	if kind == Kind.FLAME:
		for i in _glow_meshes.size():
			if _glow_is_flame[i]:
				_glow_meshes[i].visible = false


func _update_prompt() -> void:
	if _interactable == null:
		return
	var turn_on := prompt_turn_on
	var turn_off := prompt_turn_off
	if turn_on.is_empty():
		turn_on = "Anzünden" if kind == Kind.FLAME else "An"
	if turn_off.is_empty():
		turn_off = "Löschen" if kind == Kind.FLAME else "Aus"
	_interactable.prompt_text = turn_off if is_on else turn_on
