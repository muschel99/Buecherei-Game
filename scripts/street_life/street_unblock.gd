class_name StreetUnblock
extends RefCounted
## Stau-Wächter (seit dem zweiten Nachtest der Überarbeitung, Wunsch der Entwicklerin: „wenn sich Passanten blockieren, brauchen
## wir etwas, das prüft, ob sie blockiert sind, und eine Lösung, dass sie sich aus dem Weg gehen – auch bei Katzen“).
## Alle CHECK_EVERY Sekunden: Wer gehen will (Schritt walk/cross), aber seit ASK_AFTER Sekunden kaum vom Fleck kommt, und wer
## steht direkt vor ihm?
##   – ein Passant, der nur steht oder wartet (Schaufenster, Warten, Umschauen): er tritt beiseite, wartet, bis der andere vorbei
##     ist, und geht an seinen Platz zurück (Passerby.make_way)
##   – eine ruhende Katze: sie steht auf, geht ein Stück zur Seite und setzt sich dort wieder hin (CatLife.make_way)
##   – sonst (beide wollen aneinander vorbei, kein Platz zum Beiseitetreten, eine laufende Katze): nach PASS_AFTER Sekunden
##     schlüpfen beide aneinander vorbei (pass_agents – sie halten einander PASS_TIME Sekunden lang nicht auf)
## Katzen, die vor einem Passanten feststecken, meldet CatLife.blocked hierher (cat_blocked).
## Die Spielfigur tritt nie beiseite – sie entscheidet selbst.

const CHECK_EVERY := 0.25
## so wenig Bewegung in CHECK_EVERY gilt als „kommt nicht vom Fleck“ (m)
const STILL_MOVE := 0.03
const ASK_AFTER := 1.0
const PASS_AFTER := 2.4
const PASS_TIME := 2.5
## Abstand zur Seite beim Beiseitetreten (m), der Reihe nach probiert (positiv/negativ = links/rechts vom Wartenden aus)
const ASIDE_STEPS: Array[float] = [0.65, -0.65, 0.85, -0.85, 0.48, -0.48]
## Wer gerade so etwas tut, ist gleich fertig – auf ihn wird gewartet (kein Vorbeischlüpfen)
const BUSY_TYPES: Array[String] = ["door", "sit", "buy", "chore", "pet", "call", "leave"]

var life: StreetLife
var stat_make_way := 0
var stat_cat_make_way := 0
var stat_pass := 0
var _timer := 0.0
var _still := {}        # Passerby → Sekunden ohne Fortschritt
var _last := {}         # Passerby → Lage beim letzten Blick


func _init(owner_life: StreetLife) -> void:
	life = owner_life


func step(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_EVERY
	var seen := {}
	for walker in life._walkers:
		if not walker.active or walker.making_way or walker.scripted:
			continue
		seen[walker] = true
		var type := walker.get_action_type()
		var last: Vector2 = _last.get(walker, walker.pos)
		_last[walker] = walker.pos
		if type not in ["walk", "cross"] or walker.pos.distance_to(last) > STILL_MOVE:
			_still.erase(walker)
			continue
		_still[walker] = float(_still.get(walker, 0.0)) + CHECK_EVERY
		var still := float(_still[walker])
		if still < ASK_AFTER:
			continue
		var blocker := _blocker_for(walker)
		if blocker == null:
			continue
		if _resolve(walker, blocker, still):
			_still[walker] = 0.0
	# Vergessene Figuren (weg, im Vorrat) nicht weiter merken
	for walker: Variant in _last.keys():
		if not seen.has(walker):
			_last.erase(walker)
			_still.erase(walker)


## Wer steht direkt vor dem Passanten (in seiner Gehrichtung, so nah, dass er nicht weiter kann)? Passant, Katze oder null.
func _blocker_for(walker: Passerby) -> Node3D:
	var dir := walker.wanted_dir()
	if dir == Vector2.ZERO:
		return null
	var own := walker.radius * walker.scale.x
	var best: Node3D = null
	var best_along := INF
	var candidates: Array = []
	for other in life._walkers:
		if other != walker and other.active and other != walker.companion:
			candidates.append([other, other.pos, other.radius * other.scale.x])
	if life.cats:
		for cat in life.cats.get_cats():
			if cat.active and cat.on_ground():
				candidates.append([cat, life.to_local2(cat.global_position), cat.radius])
	for entry: Array in candidates:
		var rel: Vector2 = (entry[1] as Vector2) - walker.pos
		var along := rel.dot(dir)
		var reach := own + float(entry[2])
		if along < -0.05 or along > reach + 0.45:
			continue
		if (rel - dir * along).length() > reach + 0.12:
			continue
		if along < best_along:
			best_along = along
			best = entry[0]
	return best


## Eine Lösung für walker, der vor blocker feststeckt (true = etwas getan).
func _resolve(walker: Passerby, blocker: Node3D, still: float) -> bool:
	var dir := walker.wanted_dir()
	if blocker is Passerby:
		var other := blocker as Passerby
		var busy := other.get_action_type()
		if busy in BUSY_TYPES:
			return false  # geht gerade durch eine Tür, setzt sich, kauft ein …: gleich fertig – abwarten
		if _can_make_way(other):
			var aside := _aside_spot(other.pos, dir, other)
			if aside != Vector2.INF:
				other.make_way(aside, walker)
				stat_make_way += 1
				return true
		# beide wollen aneinander vorbei – oder der Stehende kann nirgends hin: vorbeischlüpfen
		if (busy in ["walk", "cross"] and still >= PASS_AFTER) or still >= PASS_AFTER * 2.0:
			_let_pass(walker, other)
			return true
	elif blocker is StreetCat:
		var cat := blocker as StreetCat
		if cat.is_resting() and life.cats:
			var spot := _aside_spot(life.to_local2(cat.global_position), dir, cat)
			if spot != Vector2.INF and life.cats.make_way(cat, spot, walker):
				stat_cat_make_way += 1
				return true
		if still >= PASS_AFTER * 0.6:
			# laufende Katze oder kein Platz: die Katze schlüpft zwischen den Beinen hindurch, der Passant geht weiter
			_let_pass(walker, cat)
			return true
	return false


## Darf dieser Passant für einen anderen beiseitetreten? Nur, wer gerade steht oder wartet – nicht beim Plaudern, Sitzen,
## an Türen, an der Theke, beim Streicheln, mit Begleiter im Gespräch oder in einer festen Szene (Story).
func _can_make_way(walker: Passerby) -> bool:
	if walker.making_way or walker.scripted or walker.chat != null or walker.talking:
		return false
	if walker.get_action_type() not in ["stand", "wait"]:
		return false
	var action := walker.get_action()
	return not action.has("seat") and not action.has("read")


## Freie Stelle neben from (quer zur Gehrichtung dir des anderen): nichts Festes, niemand dort, nicht auf die Fahrbahn
## (außer man steht schon darauf). Vector2.INF = keine.
func _aside_spot(from: Vector2, dir: Vector2, who: Node3D) -> Vector2:
	var across := Vector2(-dir.y, dir.x)
	var on_road := absf(life.centerline.project(from).y) < GameConfig.street_width / 2.0
	for step in ASIDE_STEPS:
		var spot := from + across * step + dir * 0.15
		if not on_road and absf(life.centerline.project(spot).y) < GameConfig.street_width / 2.0 + 0.25:
			continue
		if life._spot_in_solid(spot, 0.2) or not life.clear_of_static(spot, 0.22):
			continue
		if life._walkers_near(spot, 0.5, [who]) > 0 or life.player_pos().distance_to(spot) < 0.6:
			continue
		return spot
	return Vector2.INF


## Beide halten einander kurz nicht auf (schlüpfen aneinander vorbei).
func _let_pass(walker: Passerby, other: Node3D) -> void:
	walker.pass_agents[other] = PASS_TIME
	if other is Passerby:
		(other as Passerby).pass_agents[walker] = PASS_TIME
	elif other is StreetCat:
		(other as StreetCat).pass_agents[walker] = PASS_TIME
	stat_pass += 1


## CatLife meldet: diese Katze steckt seit einer Weile vor who fest (Passant oder Katze). true = gelöst (die Katze wartet kurz).
func cat_blocked(cat: StreetCat, who: Node3D, dir: Vector3) -> bool:
	if who is Passerby:
		var walker := who as Passerby
		var flat := Vector2(dir.x, dir.z).normalized()
		if _can_make_way(walker):
			var aside := _aside_spot(walker.pos, flat, walker)
			if aside != Vector2.INF:
				walker.make_way(aside, cat)
				stat_make_way += 1
				return true
		# der Passant geht gerade selbst oder kann nicht weg: die Katze schlüpft an seinen Beinen vorbei
		_let_pass_cat(cat, walker)
		return true
	if who is StreetCat:
		_let_pass_cat(cat, who)
		return true
	return false


func _let_pass_cat(cat: StreetCat, other: Node3D) -> void:
	cat.pass_agents[other] = PASS_TIME
	if other is Passerby:
		(other as Passerby).pass_agents[cat] = PASS_TIME
	elif other is StreetCat:
		(other as StreetCat).pass_agents[cat] = PASS_TIME
	stat_pass += 1
