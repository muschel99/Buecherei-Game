class_name TabletSounds
extends RefCounted
## Leises „Plopp“ bei jedem Antippen in den Tablets (seit Etappe 6f): Theken-Tablet mit allen Apps (auch Lager und
## Bücherladen) und das Regal-Menü. Jeder Knopf (BaseButton: Knöpfe, Kacheln, Aufklapp-Listen, Schalter) bekommt
## den Ton automatisch, auch wenn er erst später entsteht. Knöpfe mit eigenem Ton (Reiter „tab“, Kacheln, App-
## Symbole) tragen die Markierung OWN_SOUND und bleiben bei ihrem Ton.

## Metadaten-Name: Dieser Knopf spielt selbst einen Ton (oder hat den Plopp schon)
const OWN_SOUND := &"tablet_sound"


## Alle Knöpfe unter root (jetzt und später) ploppen beim Antippen.
static func watch(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		_hook(root, node)
	var tree := root.get_tree()
	var hook := func(node: Node) -> void: _hook(root, node)
	tree.node_added.connect(hook)
	# verschwindet root (z. B. beim Neuladen der Szene: Neues Spiel), die Verbindung wieder lösen
	root.tree_exiting.connect(func() -> void:
		if tree.node_added.is_connected(hook):
			tree.node_added.disconnect(hook), CONNECT_ONE_SHOT)


## Markiert einen Knopf, der seinen eigenen Ton spielt (bekommt keinen Plopp dazu).
static func own_sound(button: Node) -> void:
	button.set_meta(OWN_SOUND, true)


static func _hook(root: Node, node: Node) -> void:
	if not node is BaseButton or not is_instance_valid(root) or not root.is_ancestor_of(node):
		return
	_spring(node as BaseButton)
	if node.has_meta(OWN_SOUND):
		return
	node.set_meta(OWN_SOUND, true)
	(node as BaseButton).pressed.connect(func() -> void: Audio.play("ui/plop", -7.0, Audio.vary(0.05)))


# --- Federn (seit der großen Überarbeitung, „satisfying“): jeder Knopf wird beim Drüberfahren ein wenig größer, beim
# Drücken kurz kleiner und federt beim Loslassen zurück. Nur die Darstellung (scale) – die Anordnung bleibt. Knöpfe mit
# der Markierung NO_SPRING federn nicht.
const SPRING := &"tablet_spring"
const NO_SPRING := &"tablet_no_spring"


static func _spring(button: BaseButton) -> void:
	if button.has_meta(SPRING) or button.has_meta(NO_SPRING):
		return
	button.set_meta(SPRING, true)
	button.mouse_entered.connect(_bounce.bind(button, GameConfig.ui_hover_scale, 0.16, false))
	button.mouse_exited.connect(_bounce.bind(button, 1.0, 0.2, false))
	button.button_down.connect(_bounce.bind(button, GameConfig.ui_press_scale, 0.06, false))
	button.button_up.connect(func() -> void:
		_bounce(button, GameConfig.ui_hover_scale if button.is_hovered() else 1.0, 0.4, true))


static func _bounce(button: BaseButton, target: float, time: float, elastic: bool) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree() or button.disabled and target > 1.0:
		return
	button.pivot_offset = button.size / 2.0
	var old: Variant = button.get_meta(&"spring_tween", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * target, time) \
		.set_trans(Tween.TRANS_ELASTIC if elastic else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button.set_meta(&"spring_tween", tween)
