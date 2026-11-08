@tool
class_name ChibiGestureModifier
extends SkeletonModifier3D
## Gesten zusätzlich zur Animation (seit Etappe 6c): winken, auf die Uhr schauen, sich strecken und beim
## Plaudern mit den Händen erzählen. Läuft nach der Animation (SkeletonModifier3D) und dreht Arme (und
## etwas den Oberkörper) zu Zielrichtungen im Raum der Figur – weich ein- und ausgeblendet (weight).
## ChibiPasserbyModel setzt gesture, weight und time jedes Bild (play_gesture, set_talking).
##
## Figur schaut nach +Z, ihre linke Seite ist +X, oben +Y.

enum Gesture { NONE, WAVE, WATCH, STRETCH, TALK, CLIP, SWEEP, HUG, DRINK }

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
## Stelle auf dem Oberschenkel für die Handwurzel: Anteil von der Hüfte zum Knie; so weit nach außen (m)
const THIGH_SPOT := 0.62
## Die Handwurzel bleibt mindestens so weit (m) auf der eigenen Körperseite
const HAND_MIN_X := 0.05
const THIGH_SPOT_MIN := 0.3
## Arm nie weiter als dieser Anteil seiner Länge gestreckt (Ellenbogen bleibt gebeugt), Finger so weit gestreckt (0…1)
const ARM_BENT := 0.86
const FINGERS_FLAT := 0.85
const THIGH_OUT := 0.012
## Fegen (seit Etappe 6i): der Besen schwingt vor der Figur hin und her; so viele Schwünge je Sekunde (Bogenmaß)
const SWEEP_RATE := 2.6
## Finger beim Greifen so weit eingeknickt (Grad je Glied)
const GRIP_ANGLE := 65.0
## Fegen: Größe der Figur gegenüber der mittleren (Schulterhöhe), setzt ChibiPasserbyModel
var body_scale: float = 1.0
## Umarmen (seit Etappe 6i): Partner steht seitlich daneben (+1 = links von mir, -1 = rechts)
var hug_side: float = 1.0
## Trinken/Essen im Sitzen (seit Etappe 6i): 0…1 = wie weit die Hand am Mund ist
var sip: float = 0.0
## Hände greifen etwas (0…1; rechts: Gegenstand in der Hand, beide beim Fegen) – Finger krümmen sich
var grip_right: float = 0.0
var grip_left: float = 0.0
var _clip_tracks: Dictionary = {}
## Oberkörper zurückgelehnt (Grad; im Sitzen, seit Nachbesserung 4 von 6h): Rücken und Brust nach hinten, der Hals gleicht
## einen Teil davon aus (der Blick bleibt geradeaus)
var lean: float = 0.0
## Runder Rücken (Grad; im Sitzen, seit Nachbesserung 6): Brust und Schultern sinken nach vorn – die Arme hängen dann locker
var round_back: float = 0.0
## Hände auf den Oberschenkeln (0…1, im Sitzen; seit Nachbesserung 5 von 6h): Arme per Zwei-Glieder-Rechnung zu einer Stelle
## auf dem Oberschenkel; thigh_lift = so weit über der Knochenlinie liegt die Handwurzel (Dicke des Beins, m)
var hands_on_thighs: float = 0.0
var thigh_lift: float = 0.085
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
	if skeleton == null:
		return
	if absf(lean) > 0.05 or absf(round_back) > 0.05:
		_apply_lean(skeleton)
	if hands_on_thighs > 0.001:
		_apply_hands(skeleton)
	if grip_right > 0.001:
		_grip(skeleton, "Right", grip_right)
	if grip_left > 0.001:
		_grip(skeleton, "Left", grip_left)
	if gesture == Gesture.NONE or weight <= 0.001:
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
		Gesture.SWEEP:
			# Beide Hände am Stiel des Besens (Lage aus sweep_points, Modell und Hände passen immer zusammen)
			_grip(skeleton, "Left", w)
			_grip(skeleton, "Right", w)
			var p := sweep_points(t, body_scale)
			_reach(skeleton, "Right", (p.head as Vector3).lerp(p.top, 0.8), Vector3(-0.8, -0.3, -0.4), w)
			_reach(skeleton, "Left", (p.head as Vector3).lerp(p.top, 1.0), Vector3(0.8, -0.3, -0.4), w)
			_orient_hand_along(skeleton, skeleton.find_bone("RightHand"), Vector3(0.15, 0.1, 1.0).normalized(), Vector3(-1.0, 0.2, 0.0), w)
			_orient_hand_along(skeleton, skeleton.find_bone("LeftHand"), Vector3(-0.15, 0.1, 1.0).normalized(), Vector3(1.0, 0.2, 0.0), w)
			# der Oberkörper dreht ein wenig mit dem Besen
			_turn(skeleton, skeleton.find_bone("Spine"), Vector3.UP, sin(t * SWEEP_RATE) * 0.14 * w)
		Gesture.HUG:
			# Umarmung von der Seite: der innere Arm um den Rücken des anderen, Hand auf seiner fernen Schulter
			var outer := "Left" if hug_side > 0.0 else "Right"
			var lift := 0.98 if hug_side > 0.0 else 0.82  # die Arme liegen über- und untereinander
			_reach(skeleton, outer, Vector3(hug_side * 0.45 * body_scale, lift * body_scale, -0.13 * body_scale), Vector3(hug_side * 0.1, -0.4, -1.0), w)
			_orient_hand_along(skeleton, skeleton.find_bone(outer + "Hand"), Vector3(hug_side, 0.0, 0.0), Vector3(0.0, 0.2, -1.0), w)
			# etwas zum anderen hin neigen
			_turn(skeleton, skeleton.find_bone("Spine"), Vector3.BACK, -hug_side * 0.08 * w)
			_turn(skeleton, skeleton.find_bone("Neck"), Vector3.BACK, -hug_side * 0.2 * w)
		Gesture.DRINK:
			# rechte Hand vom Tisch zum Mund und zurück (sip: 0 = Hand am Tisch, 1 = am Mund)
			# Mund: vor dem großen Kopf, etwas über dem Halsansatz (Lage des Kopfknochens in dieser Haltung)
			var head := skeleton.find_bone("Head")
			var neck := skeleton.get_bone_global_pose(head).origin if head >= 0 else Vector3(0.0, 1.1, 0.0)
			var mouth := neck + Vector3(-0.06, 0.03 * body_scale, 0.29 * body_scale)
			var rest := Vector3(-0.16 * body_scale, neck.y - 0.42 * body_scale, 0.3 * body_scale)
			_reach(skeleton, "Right", rest.lerp(mouth, sip), Vector3(-0.9, -0.7, -0.3), w)
			# Finger zeigen zur Körpermitte, Daumen oben, Handrücken nach vorn – so hält man eine Tasse
			_orient_hand_along(skeleton, skeleton.find_bone("RightHand"), Vector3(0.9, 0.15, 0.2).normalized(), Vector3(-0.2, 0.2, 1.0), w)
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


## Finger krümmen (um einen Stiel oder Griff): die Fingerglieder gegenüber der Ruhehaltung einknicken, der Daumen weniger.
func _grip(skeleton: Skeleton3D, prefix: String, amount: float) -> void:
	for finger: String in ["Index", "Middle", "Ring", "Little"]:
		for joint: String in ["Proximal", "Intermediate", "Distal"]:
			_bend_joint(skeleton, prefix + finger + joint, GRIP_ANGLE, amount)
	_bend_joint(skeleton, prefix + "ThumbProximal", GRIP_ANGLE * 0.4, amount)
	_bend_joint(skeleton, prefix + "ThumbDistal", GRIP_ANGLE * 0.5, amount)


func _bend_joint(skeleton: Skeleton3D, bone_name: String, degrees: float, amount: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	var bent := rest * Quaternion(Vector3.RIGHT, deg_to_rad(degrees))
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone).slerp(bent, clampf(amount, 0.0, 1.0)))


## Besen beim Fegen zur Zeit t: Unterkante der Borsten (auf dem Boden) und oberes Ende des Stiels, im Raum der Figur.
static func sweep_points(t: float, scale_y: float) -> Dictionary:
	var a := sin(t * SWEEP_RATE)
	var head := Vector3(0.24 * a, 0.0, 0.5 * scale_y)
	var top := Vector3(0.07 * a * 0.4, 0.9 * scale_y, 0.17 * scale_y)
	return {"head": head, "top": top}


## Hand einer Seite ("Left"/"Right") zu einem Punkt im Raum der Figur führen (Zwei-Glieder-Rechnung); pole = wohin der
## Ellbogen zeigt.
func _reach(skeleton: Skeleton3D, prefix: String, target: Vector3, pole: Vector3, amount: float) -> void:
	var upper := skeleton.find_bone(prefix + "UpperArm")
	var lower := skeleton.find_bone(prefix + "LowerArm")
	var hand := skeleton.find_bone(prefix + "Hand")
	if upper < 0 or lower < 0 or hand < 0 or amount <= 0.0:
		return
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var a := shoulder.distance_to(skeleton.get_bone_global_pose(lower).origin)
	var b := skeleton.get_bone_global_pose(lower).origin.distance_to(skeleton.get_bone_global_pose(hand).origin)
	var to := target - shoulder
	var dist := clampf(to.length(), absf(a - b) + 0.002, (a + b) * 0.995)
	var along := to.normalized()
	var x := (a * a - b * b + dist * dist) / (2.0 * dist)
	var perp := (pole - along * pole.dot(along)).normalized()
	var elbow := shoulder + along * x + perp * sqrt(maxf(a * a - x * x, 0.0))
	_aim(skeleton, prefix + "UpperArm", elbow - shoulder, amount)
	var elbow_real := skeleton.get_bone_global_pose(lower).origin
	_aim(skeleton, prefix + "LowerArm", shoulder + along * dist - elbow_real, amount)


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
## Sitzen: beide Hände flach auf die Oberschenkel, Finger Richtung Knie und gestreckt, Ellbogen immer gebeugt und locker nach
## hinten außen. Ist die Stelle zu weit weg (zurückgelehnt), rutscht die Hand am Bein Richtung Hüfte, statt den Arm zu strecken.
## Beine übereinander: jede Hand bleibt auf ihrer Körperseite, liegt aber auf dem oberen Bein, wo es darüberliegt.
func _apply_hands(skeleton: Skeleton3D) -> void:
	var left_hip := skeleton.find_bone("LeftUpperLeg")
	var left_knee := skeleton.find_bone("LeftLowerLeg")
	var right_hip := skeleton.find_bone("RightUpperLeg")
	var right_knee := skeleton.find_bone("RightLowerLeg")
	if left_hip < 0 or left_knee < 0 or right_hip < 0 or right_knee < 0:
		return
	var lh := skeleton.get_bone_global_pose(left_hip).origin
	var lk := skeleton.get_bone_global_pose(left_knee).origin
	var rh := skeleton.get_bone_global_pose(right_hip).origin
	var rk := skeleton.get_bone_global_pose(right_knee).origin
	var left_on_top := lk.y > rk.y
	var crossed := smoothstep(0.02, 0.07, absf(lk.y - rk.y))
	var top_h := lh if left_on_top else rh
	var top_k := lk if left_on_top else rk
	for side: Array in [["Left", 1.0], ["Right", -1.0]]:
		var prefix := String(side[0])
		var sx := float(side[1])
		var upper := skeleton.find_bone(prefix + "UpperArm")
		var lower := skeleton.find_bone(prefix + "LowerArm")
		var hand := skeleton.find_bone(prefix + "Hand")
		if upper < 0 or lower < 0 or hand < 0:
			continue
		var shoulder := skeleton.get_bone_global_pose(upper).origin
		var elbow_now := skeleton.get_bone_global_pose(lower).origin
		var wrist_now := skeleton.get_bone_global_pose(hand).origin
		var a := shoulder.distance_to(elbow_now)
		var b := elbow_now.distance_to(wrist_now)
		var h := lh if sx > 0.0 else rh
		var k := lk if sx > 0.0 else rk
		var reach := (a + b) * ARM_BENT
		var lift := Vector3(sx * THIGH_OUT, thigh_lift, 0.0)
		var spot := THIGH_SPOT
		var target := _thigh_target(h, k, top_h, top_k, spot, sx, crossed) + lift
		while spot > THIGH_SPOT_MIN and shoulder.distance_to(target) > reach:
			spot -= 0.04
			target = _thigh_target(h, k, top_h, top_k, spot, sx, crossed) + lift
		var to := target - shoulder
		var dist := clampf(to.length(), absf(a - b) + 0.002, reach)
		var along := to.normalized()
		var x := (a * a - b * b + dist * dist) / (2.0 * dist)
		var pole := Vector3(sx * 0.6, -0.15, -0.8)
		var perp := (pole - along * pole.dot(along)).normalized()
		var elbow := shoulder + along * x + perp * sqrt(maxf(a * a - x * x, 0.0))
		var w := hands_on_thighs
		_aim(skeleton, prefix + "UpperArm", elbow - shoulder, w)
		var elbow_real := skeleton.get_bone_global_pose(lower).origin
		_aim(skeleton, prefix + "LowerArm", shoulder + along * dist - elbow_real, w)
		# die Hand liegt flach auf dem Bein: Finger entlang des Oberschenkels (leicht nach innen), Handrücken oben
		var thigh_dir := (k - h).normalized().lerp((top_k - top_h).normalized(), crossed)
		var fingers := thigh_dir.normalized() + Vector3(-sx * 0.22, 0.0, 0.0)
		_orient_hand_along(skeleton, hand, fingers.normalized(), Vector3(sx * 0.15, 1.0, 0.0), w)
		_flatten_fingers(skeleton, prefix, w)


## Stelle für die Handwurzel: auf dem eigenen Oberschenkel, immer auf der eigenen Körperseite (sonst griffe der Arm quer durch
## den Bauch). Liegt dort das andere Bein darüber (Beine übereinander), wird die Hand so weit angehoben, dass sie darauf liegt.
func _thigh_target(h: Vector3, k: Vector3, top_h: Vector3, top_k: Vector3, spot: float, sx: float, crossed: float) -> Vector3:
	var own := h.lerp(k, spot)
	own.x = sx * maxf(own.x * sx, HAND_MIN_X)
	if crossed <= 0.0:
		return own
	var line := Vector2(top_k.x - top_h.x, top_k.z - top_h.z)
	var t := clampf(Vector2(own.x - top_h.x, own.z - top_h.z).dot(line) / maxf(line.length_squared(), 0.0001), 0.0, 1.0)
	var on_top := top_h.lerp(top_k, t)
	var away := Vector2(own.x - on_top.x, own.z - on_top.z).length()
	own.y = lerpf(own.y, maxf(own.y, on_top.y), crossed * (1.0 - smoothstep(0.07, 0.14, away)))
	return own


## Hand so drehen, dass die Finger in Richtung fingers zeigen, der Handrücken nach back (im Raum der Figur).
func _orient_hand_along(skeleton: Skeleton3D, hand: int, fingers: Vector3, back: Vector3, amount: float) -> void:
	var z := back - fingers * back.dot(fingers)
	if z.length() < 0.001:
		return
	z = z.normalized()
	var wanted := Basis(fingers.cross(z), fingers, z)
	var parent := skeleton.get_bone_parent(hand)
	var parent_global := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var target := (parent_global.basis.orthonormalized().inverse() * wanted).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(hand, skeleton.get_bone_pose_rotation(hand).slerp(target, clampf(amount, 0.0, 1.0)))


## Finger fast gestreckt (wie in der Ruhehaltung) – sonst krallen sie sich aus der Sitz-Animation ins Bein.
func _flatten_fingers(skeleton: Skeleton3D, prefix: String, amount: float) -> void:
	for finger: String in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		for joint: String in ["Metacarpal", "Proximal", "Intermediate", "Distal"]:
			var bone := skeleton.find_bone(prefix + finger + joint)
			if bone >= 0:
				var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
				skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone).slerp(rest, clampf(amount, 0.0, 1.0) * FINGERS_FLAT))


## Zurücklehnen: Drehung um die Achse quer durch die Figur (+X = links; negativ = der Oberkörper geht nach hinten).
func _apply_lean(skeleton: Skeleton3D) -> void:
	# unten nach hinten (zurücklehnen), oben nach vorn (runder Rücken); der Hals gleicht aus, der Blick bleibt geradeaus
	var net := round_back - lean
	for part: Array in [["Spine", -lean], ["Chest", round_back * 0.5], ["UpperChest", round_back * 0.5], ["Neck", -net * 0.8]]:
		var bone := skeleton.find_bone(String(part[0]))
		if bone >= 0:
			_turn(skeleton, bone, Vector3.RIGHT, deg_to_rad(float(part[1])))


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
