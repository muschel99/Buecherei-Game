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
	if not node is BaseButton or node.has_meta(OWN_SOUND) or not is_instance_valid(root) or not root.is_ancestor_of(node):
		return
	node.set_meta(OWN_SOUND, true)
	(node as BaseButton).pressed.connect(func() -> void: Audio.play("ui/plop", -7.0, Audio.vary(0.05)))
