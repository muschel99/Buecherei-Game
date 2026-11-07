@tool
class_name ChibiGestureModifier
extends SkeletonModifier3D
## Gesten zusätzlich zur Animation (seit Etappe 6c): winken, auf die Uhr schauen, sich strecken und beim
## Plaudern mit den Händen erzählen. Läuft nach der Animation (SkeletonModifier3D) und dreht Arme (und
## etwas den Oberkörper) zu Zielrichtungen im Raum der Figur – weich ein- und ausgeblendet (weight).
## ChibiPasserbyModel setzt gesture, weight und time jedes Bild (play_gesture, set_talking).
##
## Figur schaut nach +Z, ihre linke Seite ist +X, oben +Y.

enum Gesture { NONE, WAVE, WATCH, STRETCH, TALK, CLIP }

var gesture: Gesture = Gesture.NONE
## 0 = keine Geste, 1 = ganz
var weight: float = 0.0
## Sekunden seit Beginn der Geste (für Bewegung wie das Hin und Her beim Winken)
var time: float = 0.0
## Sprechpause beim Plaudern (Hände ruhig): 0 … 1
var talk_energy: float = 1.0
## Gesture.CLIP (seit Etappe 6h): die Arm-Bewegung aus einer Animation der Figur über die laufende Bewegung legen
## (z. B. die Wink-Animation im Gehen und Sitzen) – Animation, Zeit darin, Knochen → Spur der Drehung
var clip: Animation
var clip_time: float = 0.0
## Erhobener Oberarm etwas weiter nach außen (Grad) – die Animationen sind für Menschen gemacht, bei den großen
## Chibi-Köpfen käme die winkende Hand sonst ans Gesicht
var clip_arm_out: float = 20.0
## … und die Hand bleibt seitlich neben dem Kopf: höchstens bis hierhin zur Mitte (x im Raum der Figur, rechts
## negativ; Kopf samt Frisur ist etwa 0,46 m breit)
var clip_hand_min_x: float = -0.29
## Nur beim Winken: Oberarm nach außen, Hand neben dem Kopf (die Ebenen für Oberkörper und Beine übernehmen genau)
var clip_wave_fix: bool = true
var _clip_tracks: Dictionary = {}
## … und die Spur der Lage der Hüfte, falls sie dabei ist (z. B. bei der Anhalte-Haltung auf dem Rad)
var _clip_positions: Dictionary = {}


## Animation für Gesture.CLIP: nur diese Knochen (Namen) werden übernommen; prefix = Pfad zum Skelett in der
## Animation (z. B. "Skeleton/Skeleton3D").
func set_clip(anim: Animation, prefix: String, bone_names: PackedStringArray) -> void:
	clip = anim
	_clip_tracks.clear()
	_clip_positions.clear()
	var skeleton := get_skeleton()
	if anim == null or skeleton == null:
		return
	for bone_name in bone_names:
		var bone := skeleton.find_bone(bone_name)
		var track := anim.find_track(NodePath(prefix + ":" + bone_name), Animation.TYPE_ROTATION_3D)
		if bone >= 0 and track >= 0:
			_clip_tracks[bone] = track
		# Lage nur für die Hüfte: die Lage von Armen und Beinen setzen die Formregler (ChibiShapeModifier)
		var moved := anim.find_track(NodePath(prefix + ":" + bone_name), Animation.TYPE_POSITION_3D) if bone_name == "Hips" else -1
		if bone >= 0 and moved >= 0:
			_clip_positions[bone] = moved


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or gesture == Gesture.NONE or weight <= 0.001:
		return
	var w := weight
	var t := time
	match gesture:
		Gesture.WAVE:
			# rechte Hand hoch, Unterarm schwingt hin und her; Handfläche nach vorn (Handrücken nach hinten)
			_aim(skeleton, "RightUpperArm", Vector3(-0.55, 0.78, 0.18), w)
			_aim(skeleton, "RightLowerArm", Vector3(-0.2 + 0.38 * sin(t * 9.0), 1.0, 0.12), w)
			_orient_hand(skeleton, "RightHand", "RightLowerArm", Vector3(0.0, 0.15, -1.0), w)
		Gesture.WATCH:
			# linker Unterarm vor die Brust, Handgelenk nach oben gedreht
			_aim(skeleton, "LeftUpperArm", Vector3(0.28, -0.6, 0.75), w)
			_aim(skeleton, "LeftLowerArm", Vector3(-0.85, 0.32, 0.4), w)
			# Handrücken (mit der Uhr) nach oben zu den Augen, Handfläche zur Brust
			_orient_hand(skeleton, "LeftHand", "LeftLowerArm", Vector3(0.0, 0.85, -0.5), w)
		Gesture.STRETCH:
			# beide Arme nach oben, ein wenig nach hinten gebeugt
			var lift := clampf(sin(clampf(t / 2.2, 0.0, 1.0) * PI) * 1.4, 0.0, 1.0)
			for side: float in [1.0, -1.0]:
				var prefix := "Left" if side > 0.0 else "Right"
				_aim(skeleton, prefix + "UpperArm", Vector3(0.28 * side, 1.0, -0.08), w * lift)
				_aim(skeleton, prefix + "LowerArm", Vector3(0.08 * side, 1.0, -0.12), w * lift)
				# Handflächen zueinander (Handrücken nach außen)
				_orient_hand(skeleton, prefix + "Hand", prefix + "LowerArm", Vector3(side, 0.0, 0.0), w * lift)
		Gesture.CLIP:
			# Drehungen der Knochen aus der Animation (lokal zum Elternknochen) – der Rest bewegt sich weiter
			if clip:
				for bone: int in _clip_tracks:
					var q := clip.rotation_track_interpolate(_clip_tracks[bone], clip_time)
					skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone).slerp(q, w))
				for bone: int in _clip_positions:
					var p := clip.position_track_interpolate(_clip_positions[bone], clip_time)
					skeleton.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone).lerp(p, w))
				# je weiter der Arm angehoben ist (hängend: nichts, waagerecht und höher: ganz), desto weiter nach außen
				# (rechter Arm: zur Seite -X, Drehung um +Z) …
				var upper := skeleton.find_bone("RightUpperArm")
				var hand := skeleton.find_bone("RightHand")
				if clip_wave_fix and upper >= 0 and hand >= 0:
					var up := skeleton.get_bone_global_pose(upper).basis.y.normalized().y
					_turn(skeleton, upper, Vector3.BACK, deg_to_rad(clip_arm_out) * clampf(up + 1.0, 0.0, 1.0) * w)
					# … und schwingt die Hand beim Winken zur Mitte, schwenkt der Arm waagerecht (um die Senkrechte durch die
					# Schulter) so weit nach außen, dass sie neben dem Kopf bleibt – nie vor Gesicht oder Brust
					var shoulder := skeleton.get_bone_global_pose(upper).origin
					var h := skeleton.get_bone_global_pose(hand).origin
					var dx := h.x - shoulder.x
					var dz := h.z - shoulder.z
					var r := Vector2(dx, dz).length()
					var want := clip_hand_min_x - shoulder.x
					if r > 0.05 and dx > want and dz > -0.05:
						var swing := asin(clampf(want / r, -1.0, 1.0)) - atan2(dx, dz)
						_turn(skeleton, upper, Vector3.UP, swing * w)
		Gesture.TALK:
			# erzählen: Unterarme vor dem Bauch, Hände bewegen sich ruhig
			var e := talk_energy
			_aim(skeleton, "RightUpperArm", Vector3(-0.2, -0.9, 0.32), w * 0.8)
			_aim(skeleton, "RightLowerArm", Vector3(-0.25 + 0.2 * sin(t * 2.7) * e, -0.15 + 0.35 * sin(t * 1.9 + 1.0) * e, 0.95), w)
			_aim(skeleton, "LeftUpperArm", Vector3(0.18, -0.95, 0.22), w * 0.6)
			_aim(skeleton, "LeftLowerArm", Vector3(0.3 + 0.12 * sin(t * 2.1 + 2.0) * e, -0.35 + 0.2 * sin(t * 1.5) * e, 0.85), w * 0.7)
			# Handflächen leicht nach oben und innen (offene, erzählende Hände)
			_orient_hand(skeleton, "RightHand", "RightLowerArm", Vector3(-0.45, -0.85, 0.0), w)
			_orient_hand(skeleton, "LeftHand", "LeftLowerArm", Vector3(0.45, -0.85, 0.0), w * 0.7)


## Richtet eine Hand aus (seit Etappe 6d – vorher behielt sie die Drehung des hängenden Arms und war
## verdreht): Finger in Verlängerung des Unterarms (kein abgeknicktes Handgelenk), Handrücken möglichst
## in Richtung back (Raum der Figur). Achsen der Hände: +Y = Finger, +Z = Handrücken, Daumen rechts -X,
## links +X (wie in der T-Pose: Handflächen unten, Daumen vorn).
func _orient_hand(skeleton: Skeleton3D, hand_name: String, forearm_name: String, back: Vector3, amount: float) -> void:
	var hand := skeleton.find_bone(hand_name)
	var forearm := skeleton.find_bone(forearm_name)
	if hand < 0 or forearm < 0 or amount <= 0.0:
		return
	var fingers := skeleton.get_bone_global_pose(forearm).basis.y.normalized()
	var z := back - fingers * back.dot(fingers)
	if z.length() < 0.001:
		return
	z = z.normalized()
	var wanted := Basis(fingers.cross(z), fingers, z)
	var parent := skeleton.get_bone_parent(hand)
	var parent_global := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var current := skeleton.get_bone_pose_rotation(hand)
	var target := (parent_global.basis.orthonormalized().inverse() * wanted).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(hand, current.slerp(target, clampf(amount, 0.0, 1.0)))


## Dreht einen Knochen um eine Achse im Raum der Figur (Bogenmaß).
func _turn(skeleton: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.0001:
		return
	var parent := skeleton.get_bone_parent(bone)
	var parent_global := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var global_basis := (parent_global.basis * skeleton.get_bone_pose(bone).basis).orthonormalized()
	var turned := Basis(axis, angle) * global_basis
	skeleton.set_bone_pose_rotation(bone, (parent_global.basis.inverse() * turned).orthonormalized().get_rotation_quaternion())


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
