@tool
class_name ChibiGestureModifier
extends SkeletonModifier3D
## Gesten zusätzlich zur Animation (seit Etappe 6c): winken, auf die Uhr schauen, sich strecken und beim
## Plaudern mit den Händen erzählen. Läuft nach der Animation (SkeletonModifier3D) und dreht Arme (und
## etwas den Oberkörper) zu Zielrichtungen im Raum der Figur – weich ein- und ausgeblendet (weight).
## ChibiPasserbyModel setzt gesture, weight und time jedes Bild (play_gesture, set_talking).
##
## Figur schaut nach +Z, ihre linke Seite ist +X, oben +Y.

enum Gesture { NONE, WAVE, WATCH, STRETCH, TALK }

var gesture: Gesture = Gesture.NONE
## 0 = keine Geste, 1 = ganz
var weight: float = 0.0
## Sekunden seit Beginn der Geste (für Bewegung wie das Hin und Her beim Winken)
var time: float = 0.0
## Sprechpause beim Plaudern (Hände ruhig): 0 … 1
var talk_energy: float = 1.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or gesture == Gesture.NONE or weight <= 0.001:
		return
	var w := weight
	var t := time
	match gesture:
		Gesture.WAVE:
			# rechte Hand hoch, Unterarm schwingt hin und her
			_aim(skeleton, "RightUpperArm", Vector3(-0.55, 0.78, 0.18), w)
			_aim(skeleton, "RightLowerArm", Vector3(-0.2 + 0.38 * sin(t * 9.0), 1.0, 0.12), w)
		Gesture.WATCH:
			# linker Unterarm vor die Brust, Handgelenk nach oben gedreht
			_aim(skeleton, "LeftUpperArm", Vector3(0.28, -0.6, 0.75), w)
			_aim(skeleton, "LeftLowerArm", Vector3(-0.85, 0.32, 0.4), w)
		Gesture.STRETCH:
			# beide Arme nach oben, ein wenig nach hinten gebeugt
			var lift := clampf(sin(clampf(t / 2.2, 0.0, 1.0) * PI) * 1.4, 0.0, 1.0)
			for side: float in [1.0, -1.0]:
				var prefix := "Left" if side > 0.0 else "Right"
				_aim(skeleton, prefix + "UpperArm", Vector3(0.28 * side, 1.0, -0.08), w * lift)
				_aim(skeleton, prefix + "LowerArm", Vector3(0.08 * side, 1.0, -0.12), w * lift)
		Gesture.TALK:
			# erzählen: Unterarme vor dem Bauch, Hände bewegen sich ruhig
			var e := talk_energy
			_aim(skeleton, "RightUpperArm", Vector3(-0.2, -0.9, 0.32), w * 0.8)
			_aim(skeleton, "RightLowerArm", Vector3(-0.25 + 0.2 * sin(t * 2.7) * e, -0.15 + 0.35 * sin(t * 1.9 + 1.0) * e, 0.95), w)
			_aim(skeleton, "LeftUpperArm", Vector3(0.18, -0.95, 0.22), w * 0.6)
			_aim(skeleton, "LeftLowerArm", Vector3(0.3 + 0.12 * sin(t * 2.1 + 2.0) * e, -0.35 + 0.2 * sin(t * 1.5) * e, 0.85), w * 0.7)


## Dreht einen Knochen so, dass er in die Richtung dir zeigt (im Raum der Figur), um amount überblendet.
func _aim(skeleton: Skeleton3D, bone_name: String, dir: Vector3, amount: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0 or amount <= 0.0:
		return
	var parent := skeleton.get_bone_parent(bone)
	var parent_global := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := skeleton.get_bone_pose(bone)
	var global_basis := (parent_global.basis * local.basis).orthonormalized()
	var current := global_basis.y.normalized()
	var target := dir.normalized()
	if current.dot(target) > 0.9999:
		return
	var turn := Quaternion(current, target)
	var turned := Basis(Quaternion.IDENTITY.slerp(turn, clampf(amount, 0.0, 1.0))) * global_basis
	var new_local := (parent_global.basis.inverse() * turned).orthonormalized()
	skeleton.set_bone_pose_rotation(bone, new_local.get_rotation_quaternion())
