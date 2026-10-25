@tool
class_name ChibiShapeModifier
extends SkeletonModifier3D
## Rückt bei dünnen und dicken Chibi-Figuren Arme und Beine samt Gelenken nach innen bzw. außen.
## Die Formregler im Modell machen nur den Körper breiter oder schmaler – ohne diesen Baustein
## säße z. B. der Ellbogen einer dicken Figur 5 cm neben ihrem Knochen und knickte falsch.
## Läuft nach den Animationen (SkeletonModifier3D), funktioniert also auch mit Mixamo-Bewegungen.
## ChibiCharacter legt ihn an und setzt die Werte (aus der Figur, "chibi_bone_offsets").

## Verschiebung je Knochen (Name → Vector3 im Skelett-Raum) bei voll dick bzw. voll dünn.
var offsets_fat: Dictionary = {}
var offsets_thin: Dictionary = {}
## -1 = dünn, 0 = mittel, 1 = dick (wie ChibiCharacter.body_shape).
var body_shape: float = 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or is_zero_approx(body_shape):
		return
	var table: Dictionary = offsets_fat if body_shape > 0.0 else offsets_thin
	var amount := absf(body_shape)
	for bone_name in table:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		# die Verschiebung gilt im Raum des Elternknochens (dreht also mit Schulter bzw. Hüfte mit)
		var offset: Vector3 = table[bone_name] * amount
		var parent := skeleton.get_bone_parent(bone)
		if parent >= 0:
			offset = skeleton.get_bone_global_rest(parent).basis.inverse() * offset
		skeleton.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone) + offset)
