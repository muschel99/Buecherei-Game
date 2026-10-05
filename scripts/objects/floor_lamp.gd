extends Node3D
## Stehlampe, die man mit E ein- und ausschalten kann.
##
## Nutzt den Baustein "Interactable": Dessen Signal "interacted" ist im
## Editor mit der Funktion _on_interactable_interacted verbunden.

## Ist die Lampe beim Spielstart an?
@export var is_on: bool = true
## Helligkeit des Lichts, wenn die Lampe an ist.
@export var light_energy: float = 1.6
## Leuchtstärke des Lampenschirms, wenn die Lampe an ist.
@export var shade_glow: float = 0.8
## Leuchtstärke der Glühbirne, wenn die Lampe an ist.
@export var bulb_glow: float = 4.0

@onready var _light: OmniLight3D = $Light
@onready var _interactable: Interactable = $Interactable
@onready var _shade: MeshInstance3D = $Model/Shade
@onready var _bulb: MeshInstance3D = $Model/Bulb

var _shade_material: StandardMaterial3D
var _bulb_material: StandardMaterial3D
var _tween: Tween


func _ready() -> void:
	# Eigene Kopien der Materialien, damit jede Lampe unabhängig leuchtet
	_shade_material = _shade.material_override.duplicate()
	_shade.material_override = _shade_material
	_bulb_material = _bulb.material_override.duplicate()
	_bulb.material_override = _bulb_material
	_apply_state(false)


func _on_interactable_interacted(_interactor: Node) -> void:
	set_on(not is_on)


## Schaltet die Lampe an oder aus (wird auch vom Lichtschalter benutzt).
func set_on(value: bool) -> void:
	if value == is_on:
		return
	is_on = value
	_apply_state(true)


## Setzt Licht, Leuchten und Hinweistext passend zu is_on.
func _apply_state(animate: bool) -> void:
	_interactable.prompt_text = "Lampe ausschalten" if is_on else "Lampe einschalten"

	var target_light := light_energy if is_on else 0.0
	var target_shade := shade_glow if is_on else 0.0
	var target_bulb := bulb_glow if is_on else 0.0

	if _tween:
		_tween.kill()
	if is_on:
		_light.visible = true

	if not animate:
		_light.light_energy = target_light
		_shade_material.emission_energy_multiplier = target_shade
		_bulb_material.emission_energy_multiplier = target_bulb
		_light.visible = is_on
		return

	# Sanft überblenden statt hart umschalten
	var duration := GameConfig.light_fade_time
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_light, "light_energy", target_light, duration)
	_tween.tween_property(_shade_material, "emission_energy_multiplier", target_shade, duration)
	_tween.tween_property(_bulb_material, "emission_energy_multiplier", target_bulb, duration)
	if not is_on:
		# Ausgeschaltetes Licht ganz verstecken (spart Rechenleistung)
		_tween.chain().tween_callback(_light.hide)
