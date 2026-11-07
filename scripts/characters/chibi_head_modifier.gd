@tool
class_name ChibiHeadModifier
extends SkeletonModifier3D
## Dreht den Kopf zusätzlich zur Animation (seit Etappe 5c): zum Umschauen nach links und rechts
## und zum leicht gesenkten Blick ins Schaufenster. Läuft nach der Animation (SkeletonModifier3D).
## ChibiPasserbyModel setzt die Werte jedes Bild.

## Drehung nach links (+) und rechts (−) in Grad.
var yaw: float = 0.0
## Nicken nach unten (+) in Grad.
var pitch: float = 0.0
## Größe des Kopfes (seit der Nachbesserung von 6h etwas kleiner, GameConfig.chibi_head_scale: beim Händeschütteln
## kamen sich die großen Köpfe so nah, als würden sie sich küssen)
var head_scale: float = 1.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var head := skeleton.find_bone("Head")
	if head < 0:
		return
	if not is_equal_approx(head_scale, 1.0):
		skeleton.set_bone_pose_scale(head, Vector3.ONE * head_scale)
	if is_zero_approx(yaw) and is_zero_approx(pitch):
		return
	var parent := skeleton.get_bone_parent(head)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var head_basis := skeleton.get_bone_global_pose(head).basis
	# erst nicken (Querachse der Figur), dann drehen (Hochachse)
	var turned := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch)) * head_basis
	var local := (parent_basis.inverse() * turned).orthonormalized()
	skeleton.set_bone_pose_rotation(head, local.get_rotation_quaternion())
