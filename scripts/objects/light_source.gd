class_name LightSource
extends Node3D
## Gemeinsamer Baustein für alles, was Licht abgibt (Lampen, Kerzen, Laternen …).
##
## So wird ein Objekt zur schaltbaren Lichtquelle:
## 1. Dieses Script an den obersten Knoten der Szene hängen.
## 2. Einen Interactable-Knoten mit Kollisionsform hinzufügen (für die Taste E).
## Den Rest findet das Script selbst: alle Lichter (OmniLight3D, SpotLight3D …) und
## alle leuchtenden Teile (Materialien mit "Emission"). Mehr ist nicht nötig.
##
## Elektrische Lampen blenden sanft auf und ab. Bei Flammen (Kerzen, Laternen)
## flackert die Flamme beim Löschen kurz auf und erlischt dann.

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

var _lights: Array[Light3D] = []
var _light_energy: Array[float] = []
var _glow_meshes: Array[MeshInstance3D] = []
var _glow_materials: Array[StandardMaterial3D] = []
var _glow_energy: Array[float] = []
var _glow_scale: Array[Vector3] = []
var _interactable: Interactable = null
var _tween: Tween
var _flame_tweens: Array[Tween] = []


func _ready() -> void:
	for node in find_children("*", "Light3D", true, false):
		_lights.append(node)
		_light_energy.append(node.light_energy)
	for node in find_children("*", "MeshInstance3D", true, false):
		var material := node.material_override as StandardMaterial3D
		if material and material.emission_enabled:
			# Eigene Kopie, damit jede Lampe unabhängig leuchtet
			material = material.duplicate()
			node.material_override = material
			_glow_meshes.append(node)
			_glow_materials.append(material)
			_glow_energy.append(material.emission_energy_multiplier)
			_glow_scale.append(node.scale)
	for node in find_children("*", "Area3D", true, false):
		if node is Interactable:
			_interactable = node
			if not _interactable.interacted.is_connected(_on_interactable_interacted):
				_interactable.interacted.connect(_on_interactable_interacted)
			break
	_apply_state(false)


## Elektrische Lampe? (nur die schaltet der Lichtschalter, siehe GameConfig)
func is_electric() -> bool:
	return kind == Kind.ELECTRIC


## Schaltet an oder aus (wird auch vom Lichtschalter benutzt).
func set_on(value: bool) -> void:
	if value == is_on:
		return
	is_on = value
	_apply_state(true)


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

	if not animate:
		for i in _lights.size():
			_lights[i].light_energy = _light_energy[i] if is_on else 0.0
			_lights[i].visible = is_on
		for i in _glow_materials.size():
			_glow_materials[i].emission_energy_multiplier = _glow_energy[i] if is_on else 0.0
			if kind == Kind.FLAME:
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
		_tween.tween_property(_glow_materials[i], "emission_energy_multiplier", _glow_energy[i] if is_on else 0.0, duration)
	if not is_on:
		_tween.chain().tween_callback(_hide_lights)


## Flamme: beim Löschen kurz aufflackern, dann klein werden und erlöschen.
## Beim Anzünden wächst die Flamme aus einem kleinen Funken.
func _animate_flame() -> void:
	var duration := GameConfig.flame_fade_time
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	if is_on:
		for i in _glow_meshes.size():
			_glow_meshes[i].scale = _glow_scale[i] * 0.2
			_tween.tween_property(_glow_meshes[i], "scale", _glow_scale[i], duration * 0.7).set_ease(Tween.EASE_OUT)
			_tween.tween_property(_glow_materials[i], "emission_energy_multiplier", _glow_energy[i], duration * 0.7)
		for i in _lights.size():
			_tween.tween_property(_lights[i], "light_energy", _light_energy[i], duration * 0.7)
		return

	var flicker := duration * 0.2
	for i in _glow_meshes.size():
		var stretched := _glow_scale[i] * Vector3(0.8, 1.3, 0.8)
		var gone := _glow_scale[i] * Vector3(0.3, 0.05, 0.3)
		var flame_tween := create_tween().set_trans(Tween.TRANS_SINE)
		_flame_tweens.append(flame_tween)
		flame_tween.tween_property(_glow_meshes[i], "scale", stretched, flicker)
		flame_tween.tween_property(_glow_meshes[i], "scale", gone, duration - flicker).set_ease(Tween.EASE_IN)
		_tween.tween_property(_glow_materials[i], "emission_energy_multiplier", 0.0, duration)
	for i in _lights.size():
		_tween.tween_property(_lights[i], "light_energy", 0.0, duration)
	_tween.chain().tween_callback(_hide_lights)


## Ausgeschaltete Lichter ganz verstecken (spart Rechenleistung), Flammen ebenso.
func _hide_lights() -> void:
	for light in _lights:
		light.visible = false
	if kind == Kind.FLAME:
		for mesh in _glow_meshes:
			mesh.visible = false


func _update_prompt() -> void:
	if _interactable == null:
		return
	var turn_on := prompt_turn_on
	var turn_off := prompt_turn_off
	if turn_on.is_empty():
		turn_on = "Anzünden" if kind == Kind.FLAME else "Licht einschalten"
	if turn_off.is_empty():
		turn_off = "Löschen" if kind == Kind.FLAME else "Licht ausschalten"
	_interactable.prompt_text = turn_off if is_on else turn_on
