class_name Notice
extends CanvasLayer
## Kleine, dezente Hinweise oben im Bild, z. B. "Deine Lieferung ist da".
##
## Ein Hinweis blendet sanft ein, bleibt ein paar Sekunden (GameConfig.notice_time) und
## blendet wieder aus. Kommen mehrere kurz hintereinander, erscheinen sie nacheinander.
## Von überall aus aufrufen: Notice.post(self, "Text").

const GROUP := "notice"
const FADE_TIME := 0.35

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = %Label

var _queue: Array[String] = []
var _is_showing := false


## Zeigt einen Hinweis (sender = irgendein Knoten im Spiel).
static func post(sender: Node, text: String) -> void:
	sender.get_tree().call_group(GROUP, "show_message", text)


func _ready() -> void:
	add_to_group(GROUP)
	_panel.modulate.a = 0.0


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden
	visible = not get_tree().paused


func show_message(text: String) -> void:
	_queue.append(text)
	if not _is_showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_is_showing = false
		return
	_is_showing = true
	_label.text = _queue.pop_front()
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_panel, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(GameConfig.notice_time)
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_show_next)
