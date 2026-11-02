class_name AnimalHeadModifier
extends SkeletonModifier3D
## Dreht den Kopf eines Tiers zusätzlich zur Bewegung (seit Etappe 6g): Katze schaut zum Schaufenster hinauf
## oder zur Spielfigur. Läuft nach der Animation (Kind des Skeleton3D); StreetCat setzt die Werte jedes Bild.
## Ein Teil der Drehung geht in den Hals (weicher).

## Drehung nach links (+) und rechts (−) in Grad.
var yaw: float = 0.0
## Blick nach oben (+) in Grad.
var pitch: float = 0.0
var head_bone := "head"
var neck_bone := "neck"
## So viel der Drehung übernimmt der Hals.
var neck_share := 0.35


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or (is_zero_approx(yaw) and is_zero_approx(pitch)):
		return
	var neck := skeleton.find_bone(neck_bone)
	if neck >= 0:
		_turn(skeleton, neck, neck_share)
	var head := skeleton.find_bone(head_bone)
	if head >= 0:
		_turn(skeleton, head, 1.0 - neck_share if neck >= 0 else 1.0)


func _turn(skeleton: Skeleton3D, bone: int, share: float) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var basis := skeleton.get_bone_global_pose(bone).basis
	# Modell: +Z vorn, +Y oben – nach oben schauen = um +X zurückdrehen
	var turned := Basis(Vector3.UP, deg_to_rad(yaw * share)) * Basis(Vector3.RIGHT, -deg_to_rad(pitch * share)) * basis
	var local := (parent_basis.inverse() * turned).orthonormalized()
	skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
