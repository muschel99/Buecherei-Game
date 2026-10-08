class_name LooseBook
extends RefCounted
## Ein Buch, das frei in der Welt liegt oder steht (auf einem Tisch, der Theke, einer
## Fensterbank, dem Boden …) – "ausgelegt", nicht im Regal.
##
## Alle ausgelegten Bücher eines Raums verwaltet LooseBooks (ein Knoten je Raum, alle Bücher
## in einem einzigen Zeichenaufruf). Das Buch selbst bleibt ein normales Exemplar (Book).
## Später sollen auch Besucher Bücher auslegen – sie benutzen dieselben Funktionen
## (LooseBooks.place, LooseBooks.remove).

## Wie das Buch daliegt.
enum Pose {
	FLAT,  ## flach, Cover nach oben (Standard; mehrere übereinander = kleiner Stapel)
	UPRIGHT,  ## aufrecht, Rücken nach vorn (z. B. neben einer Buchstütze)
	LEANING,  ## aufrecht an eine Wand gelehnt, Cover nach vorn
	OPEN,  ## aufgeschlagen (vorgesehen für später – wird vorerst wie FLAT gezeigt)
	DISPLAYED,  ## in einem Buch-Aufsteller präsentiert (BookStand), Cover nach vorn
}

const _POSE_IDS := {Pose.FLAT: "flat", Pose.UPRIGHT: "upright", Pose.LEANING: "leaning", Pose.OPEN: "open",
	Pose.DISPLAYED: "displayed"}

## Das Exemplar.
var book: Book
## Lage und Größe in LooseBooks (= im Raum): Basis enthält schon die Buchgröße
## (wie im Regal: ein Würfel der Größe 1, gestreckt).
var transform: Transform3D
## Nummer des Möbelstücks, auf dem es liegt (0 = auf dem Boden). Wird das Möbelstück
## verschoben, wandert das Buch mit; wird es weggeräumt, kommt das Buch ins Lager.
var support_uid: int = 0
var pose: Pose = Pose.FLAT
## Gerade unsichtbar (z. B. während das Möbelstück darunter im Gestaltungsmodus getragen wird).
var hidden: bool = false


static func create(new_book: Book, new_transform: Transform3D, new_support_uid: int, new_pose: Pose) -> LooseBook:
	var entry := LooseBook.new()
	entry.book = new_book
	entry.transform = new_transform
	entry.support_uid = new_support_uid
	entry.pose = new_pose
	return entry


## Liegt es flach (darauf kann man weitere Bücher stapeln)?
func is_flat() -> bool:
	return pose == Pose.FLAT or pose == Pose.OPEN


# --- Speichern und Laden ---

func to_save_data() -> Dictionary:
	var b := transform.basis
	var o := transform.origin
	return {
		"book": book.to_save_data(),
		"transform": [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, o.x, o.y, o.z],
		"support_uid": support_uid,
		"pose": _POSE_IDS[pose],
	}


static func from_save_data(saved: Variant) -> LooseBook:
	if not saved is Dictionary:
		return null
	var saved_book := Book.from_save_data(saved.get("book"))
	var values = saved.get("transform")
	if saved_book == null or not values is Array or values.size() != 12:
		return null
	var v: Array = values.map(func(value) -> float: return float(value))
	var basis := Basis(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), Vector3(v[6], v[7], v[8]))
	var pose_value: Variant = _POSE_IDS.find_key(str(saved.get("pose", "flat")))
	return create(saved_book, Transform3D(basis, Vector3(v[9], v[10], v[11])),
		int(saved.get("support_uid", 0)), pose_value if pose_value != null else Pose.FLAT)
