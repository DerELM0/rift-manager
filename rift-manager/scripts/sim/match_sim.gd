class_name MatchSim
extends RefCounted
## Match-Simulation, 1:1 portiert aus web-sim/sim.js (simulateGame, simulateSeries).
## Kennt keine Szenen oder Nodes.
##
## Gleicher Seed und gleiche Teams ergeben exakt dasselbe Spiel wie im Web-Simulator.
## Deshalb ist die Reihenfolge der Zufallszahlen genau wie im Original. Wer hier
## etwas umstellt, ändert alle Ergebnisse.
##
## Aufruf:
##   var result: MatchResult = MatchSim.simulate_game(team_a, team_b, {}, 42)
##
## Optionen (opt), wie im Original:
##   "pressure": bool        Druckspiel (Playoffs, Entscheidungsspiel). Dann wirken
##                           Clutch Player, Choker, Bühnentier und Bühnenangst.
##   "planA", "planB": String Jungle-Plan erzwingen: "Top", "Mid", "Bot", "Objectives"
##                           oder "Auto" (= automatisch, wie wenn nichts angegeben ist).
##   "consts": Dictionary    Überschreibt einzelne Werte aus RiftSim.DEFAULTS.
##
## Die Simulation läuft in vier Phasen: Draft, Laning (bis Minute 14),
## Midgame-Objectives (Minute 15–24) und Teamfights bis zum Nexus.

## Farm-Gold pro Minute je Rolle.
const FARM: Dictionary = {"TOP": 320, "JGL": 290, "MID": 340, "ADC": 360, "SUP": 210}
## Gewicht jeder Rolle beim Macro-Wert des Teams.
const MACRO_WEIGHT: Dictionary = {"TOP": 1.0, "JGL": 1.5, "MID": 1.0, "ADC": 1.0, "SUP": 1.25}
const LANES: Array[String] = ["Top", "Mid", "Bot"]
## Midgame-Objectives: [Minute, Name, Gold].
const OBJECTIVES: Array = [
	[15, "Herold", 600], [17, "Drache", 300], [20, "Turm", 550], [22, "Drache", 300], [24, "Turm", 550],
]


## Ein Spieler mit seinen effektiven Werten für dieses eine Spiel.
class PreparedPlayer extends RefCounted:
	var p: Player = null
	var role: String = ""
	## Effektive Werte [Mechanics, Laning, Macro, Teamwork, Mental] für dieses Spiel.
	var s: Array[float] = []
	## Tagesform-Abweichung (Zufall, abhängig von Mental).
	var d: float = 0.0
	## Kommunikationswert K.
	var comm: float = 0.0
	## Overall aus den effektiven Werten.
	var ovr: float = 0.0
	var kills: int = 0
	var deaths: int = 0
	var assists: int = 0
	var gold: float = 500.0


## Ein Team mit seinen vorbereiteten Spielern.
class PreparedTeam extends RefCounted:
	var team: Team = null
	var coach: Coach = null
	var chem: float = 0.0
	## Spieler in Rollenreihenfolge TOP, JGL, MID, ADC, SUP.
	var ps: Array[PreparedPlayer] = []

	func by(role: String) -> PreparedPlayer:
		return ps[RiftSim.ROLES.find(role)]

	func has_any_trait(trait_name: String) -> bool:
		for pp: PreparedPlayer in ps:
			if pp.p.has_trait(trait_name):
				return true
		return false


# Zustand eines laufenden Spiels (eine MatchSim-Instanz pro Spiel).
var _c: Dictionary = {}
var _opt: Dictionary = {}
var _rng: RiftSim.Rng = null
var _a: PreparedTeam = null
var _b: PreparedTeam = null
var _log: Array[MatchResult.LogEntry] = []
var _draft: Dictionary = {}
## Golddifferenz A − B (immer eine ganze Zahl, als float wegen der Formeln).
var _gd: float = 0.0
var _gold_at: Array[int] = []
var _minute: int = 14
var _drakes: Dictionary = {"A": 0, "B": 0}
var _baron_buff: Dictionary = {"A": -1, "B": -1}


# --- Öffentliche Funktionen -------------------------------------------------

## Simuliert ein Spiel (simulateGame). Gibt null zurück, wenn ein Team nicht
## genau einen Spieler pro Rolle hat (das Original würde dann abstürzen).
static func simulate_game(team_a: Team, team_b: Team, opt: Dictionary = {}, seed_value: int = 0) -> MatchResult:
	for team: Team in [team_a, team_b]:
		for role: String in RiftSim.ROLES:
			if team.get_player(role) == null:
				push_warning("MatchSim: Team %s hat keinen Spieler auf %s, Spiel nicht simuliert." % [team.short, role])
				return null
	var sim: MatchSim = MatchSim.new()
	return sim._run(team_a, team_b, opt, seed_value)


## Simuliert eine Serie (simulateSeries), z. B. best_of = 3 für ein Bo3.
## Spiel i bekommt den Seed seed + i * 7919. Im Entscheidungsspiel einer Serie
## (beide Teams eins vor dem Sieg) gilt automatisch "pressure".
static func simulate_series(team_a: Team, team_b: Team, best_of: int, opt: Dictionary = {}, seed_value: int = 0) -> SeriesResult:
	var result := SeriesResult.new()
	var need: int = ceili(best_of / 2.0)
	var i: int = 0
	while result.wins_a < need and result.wins_b < need:
		var decider: bool = result.wins_a == need - 1 and result.wins_b == need - 1
		var game_opt: Dictionary = opt.duplicate()
		game_opt["pressure"] = bool(opt.get("pressure", false)) or (best_of > 1 and decider)
		var game: MatchResult = simulate_game(team_a, team_b, game_opt, (seed_value + i * 7919) & 0xFFFFFFFF)
		if game == null:
			return result
		result.games.append(game)
		if game.winner == "A":
			result.wins_a += 1
		else:
			result.wins_b += 1
		i += 1
	return result


# --- Ablauf eines Spiels ----------------------------------------------------

func _run(team_a: Team, team_b: Team, opt: Dictionary, seed_value: int) -> MatchResult:
	_opt = opt
	_c = RiftSim.merge_consts(opt.get("consts", {}))
	_rng = RiftSim.make_rng(seed_value)
	_a = _prep_team(team_a)
	_b = _prep_team(team_b)
	_gold_at.resize(61)
	_gold_at.fill(0)

	# ---- Phase 1: Draft ----
	_draft = _make_draft()
	_ev(0, "Draft: %s spielt %s (Comp %d), %s spielt %s (Comp %d)" % [
		team_a.short, _draft["A"]["arch"], _draft["A"]["score"],
		team_b.short, _draft["B"]["arch"], _draft["B"]["score"]], "", "draft")

	# ---- Phase 2: Laning ----
	var la: Dictionary = _lane_values(_a)
	var lb: Dictionary = _lane_values(_b)
	var ja: float = _jungle_value(_a)
	var jb: float = _jungle_value(_b)
	# Roamer: +3 auf die schwächste andere Lane, −2 auf die eigene
	_apply_roamers(_a, la, lb)
	_apply_roamers(_b, lb, la)
	var plan_a: String = _plan(la, lb, ja, jb, str(opt.get("planA", "")))
	var plan_b: String = _plan(lb, la, jb, ja, str(opt.get("planB", "")))
	_ev(0, "Jungle-Plan: %s → %s, %s → %s" % [team_a.short, plan_a, team_b.short, plan_b], "", "plan")

	var lane_eff: Dictionary = {}
	var gold14: float = 0.0
	for lane: String in LANES:
		var a: float = la[lane] + _proximity(_a, plan_a, ja, lane)
		var b: float = lb[lane] + _proximity(_b, plan_b, jb, lane)
		lane_eff[lane] = [a, b]
		gold14 += _c["lane"] * (a - b)
	gold14 += _c["jgl"] * (ja - jb)
	# Lane-Vorsprung als zusätzlicher Farm der Laner
	for lane: String in LANES:
		var v: float = _c["lane"] * (lane_eff[lane][0] - lane_eff[lane][1])
		var lane_team: PreparedTeam = _a if v >= 0 else _b
		var ps: Array[PreparedPlayer] = _lane_players(lane_team, lane)
		if ps.size() > 1:
			ps[0].gold += 0.7 * absf(v)
			ps[1].gold += 0.3 * absf(v)
		else:
			ps[0].gold += absf(v)
	var jv: float = _c["jgl"] * (ja - jb)
	var jungle_team: PreparedTeam = _a if jv >= 0 else _b
	jungle_team.by("JGL").gold += absf(jv)

	var timeline: Array[float] = []  # Golddifferenz-Ereignisse pro Minute (A − B)
	timeline.resize(61)
	timeline.fill(0.0)
	var base14: float = gold14
	var first_blood: bool = false
	var kill_events: Array = []
	for lane: String in LANES:
		var n: int = _rng.poisson(_c["killsPerLane"])
		var invader: bool = (plan_a == lane and _a.by("JGL").p.has_trait("Invader")) \
				or (plan_b == lane and _b.by("JGL").p.has_trait("Invader"))
		if invader:
			n += 1
		for _i: int in n:
			var a: float = lane_eff[lane][0]
			var b: float = lane_eff[lane][1]
			var win_a: bool = _rng.next_float() < RiftSim.sig((a - b) / 10.0)
			var w_team: PreparedTeam = _a if win_a else _b
			var l_team: PreparedTeam = _b if win_a else _a
			var w_plan: String = plan_a if win_a else plan_b
			var killers: Array[PreparedPlayer] = _lane_players(w_team, lane)
			var victims: Array[PreparedPlayer] = _lane_players(l_team, lane)
			var killer: PreparedPlayer = killers[0]
			if killers.size() > 1:
				killer = killers[0] if _rng.next_float() < 0.6 else killers[1]
			var jg: PreparedPlayer = w_team.by("JGL")
			if w_plan == lane:
				# Gank-Anteil hängt an Jungler und Laner
				var share: float = _c["gankShare"]
				if jg.p.has_trait("Invader"):
					share += 0.08
				if jg.p.has_trait("Early-Game-Spezialist"):
					share += 0.05
				if killer.p.has_trait("Lane Bully"):
					share -= 0.08
				if killer.p.has_trait("Carry"):
					share -= 0.05
				if killer.p.has_trait("Egoist"):
					share -= 0.08
				if killer.p.has_trait("Teamplayer"):
					share += 0.05
				if _rng.next_float() < clampf(share, 0.05, 0.45):
					killer = jg
			var victim: PreparedPlayer = victims[0]
			if victims.size() > 1:
				var weights: Array[float] = []
				for vp: PreparedPlayer in victims:
					weights.append((100 - vp.s[4]) * (0.7 if vp.p.has_trait("Risikoarm") else 1.0))
				victim = _rng.weighted(victims, weights)
			killer.kills += 1
			victim.deaths += 1
			var pool: Array[PreparedPlayer] = killers.duplicate()
			if w_plan == lane:
				pool.append(jg)
			var assists: Array[PreparedPlayer] = []
			for x: PreparedPlayer in pool:
				if x != killer:
					assists.append(x)
			for x: PreparedPlayer in assists:
				x.assists += 1
			_pay_kill(killer, assists)
			var minute: int = _rng.int_range(3, 13)
			kill_events.append({"min": minute, "win_a": win_a, "killer": killer, "victim": victim, "lane": lane})

	kill_events = RiftSim.stable_sort(kill_events, func(x: Dictionary, y: Dictionary) -> bool:
		return x["min"] < y["min"])
	for e: Dictionary in kill_events:
		timeline[e["min"]] += (1 if e["win_a"] else -1) * _c["kill"]
		var fb: String = "First Blood! " if not first_blood else ""
		first_blood = true
		_ev(e["min"], "%s%s tötet %s (%s)" % [fb, e["killer"].p.display_name(), e["victim"].p.display_name(), e["lane"]],
				"A" if e["win_a"] else "B", "kill")

	# Golddifferenz-Verlauf
	var cum: float = 0.0
	for m: int in range(1, 15):
		cum += timeline[m]
		_gold_at[m] = RiftSim.js_round(base14 * m / 14.0 + cum)
	_gd = _gold_at[14]
	_ev(14, "Nach dem Laning: %s führt mit %d Gold" % [team_a.short if _gd >= 0 else team_b.short, int(absf(_gd))],
			"A" if _gd >= 0 else "B", "phase")
	var leader14: String = "" if _gd == 0 else ("A" if _gd > 0 else "B")

	# ---- Phase 3: Midgame ----
	var macro_a: float = _macro(_a)
	var macro_b: float = _macro(_b)
	var early_obj: int = 0
	_minute = 14
	for obj: Array in OBJECTIVES:
		var m: int = obj[0]
		var obj_name: String = obj[1]
		var g: int = obj[2]
		var m_a: float = macro_a + _vision(_a)
		var m_b: float = macro_b + _vision(_b)
		if early_obj < 3 and obj_name != "Turm":
			if plan_a == "Objectives":
				m_a += 0.05 * ja
			if plan_b == "Objectives":
				m_b += 0.05 * jb
			early_obj += 1
		var p_a: float = RiftSim.sig((m_a - m_b) / _c["objDiv"] + _gd / _c["objGold"]
				+ (_comp_at("A", m) - _comp_at("B", m)) / _c["compDiv"])
		var win_a: bool = _rng.next_float() < p_a
		_gd += (1 if win_a else -1) * g
		_pay_team(_a if win_a else _b, g)
		if obj_name == "Drache":
			_drakes["A" if win_a else "B"] += 1
		# Gelegentliches Scharmützel
		if _rng.next_float() < _c["skirmish"]:
			var w_team: PreparedTeam = _a if win_a else _b
			var l_team: PreparedTeam = _b if win_a else _a
			var kw: Array[float] = []
			for x: PreparedPlayer in w_team.ps:
				kw.append(maxf(1.0, x.s[0]))
			var killer: PreparedPlayer = _rng.weighted(w_team.ps, kw)
			var victim: PreparedPlayer = _rng.weighted(l_team.ps, _victim_weights(l_team))
			killer.kills += 1
			victim.deaths += 1
			_gd += (1 if win_a else -1) * _c["kill"]
			var assists: Array[PreparedPlayer] = []
			for x: PreparedPlayer in w_team.ps:
				if x != killer and _rng.next_float() < x.s[3] / 100.0 * 0.5:
					assists.append(x)
			for x: PreparedPlayer in assists:
				x.assists += 1
			_pay_kill(killer, assists)
		_set_gold(m, _gd)
		_ev(m, "%s sichert %s" % [team_a.short if win_a else team_b.short, obj_name], "A" if win_a else "B", "obj")

	# ---- Phase 4: Teamfights ----
	var pressure: Dictionary = {"A": 0, "B": 0}
	var baron_cd: float = 20.0
	var elder_cd: float = 35.0
	var winner: String = ""
	var t: float = 25.0
	var fights: int = 0
	while winner.is_empty():
		t += 1.2 + _rng.next_float() * 1.8
		var tm: int = RiftSim.js_round(t)
		var f_a: float = _fight_value(_a, "A", tm) + _c["fightGold"] * _gd / 1000.0
		var f_b: float = _fight_value(_b, "B", tm)
		var win_a: bool = false
		var thrown: bool = false
		if absf(_gd) > 5000:
			var lead: PreparedTeam = _a if _gd > 0 else _b
			var men_sum: float = 0.0
			for x: PreparedPlayer in lead.ps:
				men_sum += x.s[4]
			var men_avg: float = men_sum / 5.0
			if _rng.next_float() < _c["throwBase"] * (1 - men_avg / 100.0):
				win_a = _gd < 0
				thrown = true
		if not thrown:
			win_a = _rng.next_float() < RiftSim.sig((f_a - f_b) / _c["fightDiv"])
		fights += 1
		var side: String = "A" if win_a else "B"
		var other: String = "B" if win_a else "A"
		var w_team: PreparedTeam = _a if win_a else _b
		var l_team: PreparedTeam = _b if win_a else _a
		var was_behind: bool = _gd < 0 if win_a else _gd > 0
		var g: float = 800 + _rng.next_float() * 700
		if was_behind:
			g += _c["shutdown"] * absf(_gd)
		# Kills: Sieger im Schnitt fightKills, Verlierer etwa ein Drittel davon
		var nk: int = mini(5, maxi(1, _rng.poisson(_c["fightKills"])))
		var nb: int = mini(4, _rng.poisson(_c["fightKills"] / 3.0))
		_do_fight_kills(w_team, l_team, nk)
		_do_fight_kills(l_team, w_team, nb)
		_pay_team(w_team, g)
		g += (nk - nb) * _c["kill"]
		var obj_name: String = "Turm"
		var pr: int = 1
		if t >= elder_cd and t >= 35:
			obj_name = "Elder Drache"
			pr = 3
			elder_cd = t + 6
		elif t >= baron_cd:
			obj_name = "Baron"
			pr = 2
			baron_cd = t + 6
			_baron_buff[side] = tm + 3
			g += 1500
			_pay_team(w_team, 1500)
		pressure[side] += pr
		pressure[other] = maxi(0, pressure[other] - 1)
		_gd += (1 if win_a else -1) * RiftSim.js_round(g)
		_set_gold(mini(60, tm), _gd)
		var tag: String = "Throw! " if thrown else ("Comeback-Fight! " if was_behind else "")
		_ev(tm, "%s%s gewinnt den Teamfight %d:%d und holt %s" % [tag, w_team.team.short, nk, nb, obj_name],
				side, "big" if obj_name == "Baron" or obj_name == "Elder Drache" else "fight")
		if pressure[side] >= 4 or t >= 45:
			winner = side
			_ev(tm, "%s zerstört den Nexus" % w_team.team.short, side, "end")

	var dur: int = RiftSim.js_round(t)
	for x: int in range(_minute + 1, mini(60, dur) + 1):
		_gold_at[x] = int(_gd)

	# ---- Farm über die Spielzeit (für beide Teams gleich) ----
	for team: PreparedTeam in [_a, _b]:
		for x: PreparedPlayer in team.ps:
			x.gold += FARM[x.role] * t

	# ---- Ergebnis ----
	var result := MatchResult.new()
	result.team_a = team_a
	result.team_b = team_b
	result.winner = winner
	result.duration = dur
	result.gold = _gold_at.slice(0, mini(60, dur) + 1)
	result.gold14 = _gold_at[14]
	result.leader14 = leader14
	result.game_log = _log
	result.draft = _draft
	result.plans = {"A": plan_a, "B": plan_b}
	var ratings_a: Array[MatchResult.PlayerRating] = _rate(_a, _b, winner == "A")
	var ratings_b: Array[MatchResult.PlayerRating] = _rate(_b, _a, winner == "B")
	result.ratings = {"A": ratings_a, "B": ratings_b}
	result.mvp = _mvp(ratings_a if winner == "A" else ratings_b)
	result.drakes = _drakes
	result.fights = fights
	result.team_gold = {"A": _team_gold(_a), "B": _team_gold(_b)}
	result.kills = {"A": _team_kills(_a), "B": _team_kills(_b)}
	return result


# --- Vorbereitung -----------------------------------------------------------

## Effektive Werte aller Spieler für dieses Spiel (prepTeam).
func _prep_team(team: Team) -> PreparedTeam:
	var pt := PreparedTeam.new()
	pt.team = team
	pt.coach = team.coach if team.coach != null else Coach.fallback()
	pt.chem = team.chemistry
	var pressure: bool = bool(_opt.get("pressure", false))
	var champ: float = 0.85 + 0.15 * _c["mastery"] / 100.0
	for role: String in RiftSim.ROLES:
		var p: Player = team.get_player(role)
		var mec: float = p.mechanics
		var lan: float = p.laning
		var mac: float = p.macro
		var tea: float = p.teamwork
		var men: float = p.mental
		if p.has_trait("Arrogant"):
			men += 3
		if p.has_trait("Egoist"):
			mec += 3
			tea -= 4
		if pressure:
			if p.has_trait("Clutch Player"):
				mec += 5
			if p.has_trait("Choker"):
				men -= 5
			if p.has_trait("Bühnentier"):
				mec += 3
			if p.has_trait("Bühnenangst"):
				mec -= 4
		var sd: float = _c["sigmaBase"] * (1.5 - men / 100.0)
		if p.has_trait("Hot-Headed"):
			sd *= 1.5
		if p.has_trait("Tilt-Proof"):
			sd *= 0.75
		if pressure and p.has_trait("Clutch Player"):
			sd *= 0.5
		var d: float = _rng.gauss() * sd
		var k: float = RiftSim.comm_k(p, team.language)
		var fm: float = 0.0
		if p.has_form():
			fm = clampf((p.form - _c["formCenter"]) / _c["formDiv"], -4.0, 4.0)
		var base: Array[float] = []
		for x: float in [mec, lan, mac, tea, men]:
			base.append(x * champ + d + fm)
		base[3] = base[3] * (0.80 + 0.40 * pt.chem / 100.0) * (0.80 + 0.20 * k / 100.0)
		var pp := PreparedPlayer.new()
		pp.p = p
		pp.role = role
		pp.s = base
		pp.d = d
		pp.comm = k
		pp.ovr = RiftSim.ovr_of(role, base)
		pt.ps.append(pp)
	return pt


## Draft: Wer zuerst seine Comp festlegt, wird ausgelost; der andere kann kontern.
func _make_draft() -> Dictionary:
	var a_first: bool = _rng.next_float() < 0.5
	var second: PreparedTeam = _b if a_first else _a
	var a1: String = _rng.pick(RiftSim.ARCH)
	var a2: String
	if _rng.next_float() < 0.30 + 0.50 * second.coach.drafting / 100.0:
		a2 = RiftSim.best_counter(a1)
	else:
		a2 = _rng.pick(RiftSim.ARCH)
	var arch_a: String = a1 if a_first else a2
	var arch_b: String = a2 if a_first else a1
	var score_a: int = _comp_score(_a)
	var score_b: int = _comp_score(_b)
	return {"A": {"arch": arch_a, "score": score_a}, "B": {"arch": arch_b, "score": score_b}}


func _comp_score(team: PreparedTeam) -> int:
	return clampi(RiftSim.js_round(_rng.next_float() * 3 + 2.0 * team.coach.drafting / 100.0), 0, 5)


## Comp-Stärke einer Seite zu einer Spielminute (compAt): Draft-Score + Zeitkurve + Counter.
func _comp_at(side: String, minute: int) -> int:
	var me: Dictionary = _draft[side]
	var op: Dictionary = _draft["B" if side == "A" else "A"]
	var idx: int = 0 if minute < 25 else (1 if minute < 35 else 2)
	return me["score"] + RiftSim.CURVE[me["arch"]][idx] + RiftSim.counter(me["arch"], op["arch"])


# --- Laning -----------------------------------------------------------------

func _early(pp: PreparedPlayer) -> float:
	return 4.0 if pp.p.has_trait("Early-Game-Spezialist") else 0.0


func _lane_value(pp: PreparedPlayer) -> float:
	var e: float = _early(pp)
	var lan: float = pp.s[1] + e + (5 if pp.p.has_trait("Lane Bully") else 0)
	return 0.6 * lan + 0.4 * (pp.s[0] + e)


## Lane-Stärke je Lane (L im Original).
func _lane_values(team: PreparedTeam) -> Dictionary:
	var top: float = _lane_value(team.by("TOP"))
	var mid: float = _lane_value(team.by("MID"))
	var bot: float = 0.6 * _lane_value(team.by("ADC")) + 0.4 * _lane_value(team.by("SUP"))
	return {"Top": top, "Mid": mid, "Bot": bot}


## Jungle-Stärke (Jval im Original).
func _jungle_value(team: PreparedTeam) -> float:
	var j: PreparedPlayer = team.by("JGL")
	var e: float = _early(j)
	return 0.6 * (j.s[2] + e) + 0.4 * (j.s[0] + e) + (3 if j.p.has_trait("Invader") else 0)


func _apply_roamers(team: PreparedTeam, mine: Dictionary, theirs: Dictionary) -> void:
	for role: String in ["MID", "SUP"]:
		var pp: PreparedPlayer = team.by(role)
		if pp.p.has_trait("Roamer"):
			var own: String = "Mid" if role == "MID" else "Bot"
			# Schwächste andere Lane; bei Gleichstand die zuerst genannte
			var weakest: String = ""
			for lane: String in LANES:
				if lane == own:
					continue
				if weakest.is_empty() or mine[lane] - theirs[lane] < mine[weakest] - theirs[weakest]:
					weakest = lane
			mine[weakest] += 3
			mine[own] -= 2


## Jungle-Plan: stärkste Lane bei klarem Vorsprung, sonst Objectives, sonst schwächste Lane.
func _plan(mine: Dictionary, theirs: Dictionary, j_mine: float, j_theirs: float, forced: String) -> String:
	if not forced.is_empty() and forced != "Auto":
		return forced
	var diffs: Array = []
	for lane: String in LANES:
		diffs.append([lane, mine[lane] - theirs[lane]])
	diffs = RiftSim.stable_sort(diffs, func(x: Array, y: Array) -> bool: return x[1] > y[1])
	if diffs[0][1] >= 3:
		return diffs[0][0]
	if j_mine >= j_theirs + 3:
		return "Objectives"
	return diffs[2][0]


## Wie viel der Jungler einer Lane hilft (prox im Original).
func _proximity(team: PreparedTeam, plan: String, j: float, lane: String) -> float:
	if plan == "Objectives":
		return 0.0
	if plan == lane:
		return 0.10 * j
	var lane_player: PreparedPlayer = null
	if lane == "Top":
		lane_player = team.by("TOP")
	elif lane == "Bot":
		lane_player = team.by("ADC")
	if lane_player != null and lane_player.p.has_trait("Weak-Side-Spezialist"):
		return 0.05 * j
	return 0.025 * j


func _lane_players(team: PreparedTeam, lane: String) -> Array[PreparedPlayer]:
	if lane == "Top":
		return [team.by("TOP")]
	if lane == "Mid":
		return [team.by("MID")]
	return [team.by("ADC"), team.by("SUP")]


# --- Midgame und Teamfights -------------------------------------------------

## Macro-Wert des Teams: gewichteter Macro-Schnitt + Shotcaller + Coach-Taktik.
func _macro(team: PreparedTeam) -> float:
	var s: float = 0.0
	var w: float = 0.0
	for pp: PreparedPlayer in team.ps:
		s += MACRO_WEIGHT[pp.role] * pp.s[2]
		w += MACRO_WEIGHT[pp.role]
	var m: float = s / w
	var best_charisma: int = -1
	for pp: PreparedPlayer in team.ps:
		if pp.p.has_trait("Shotcaller"):
			best_charisma = maxi(best_charisma, pp.p.charisma)
	if best_charisma >= 0:
		m += 4.0 * best_charisma / 100.0
	m += (team.coach.tactics - 50) / 10.0
	return m


func _vision(team: PreparedTeam) -> float:
	return 3.0 if team.has_any_trait("Vision Master") else 0.0


## Teamfight-Stärke einer Seite (F im Original).
func _fight_value(team: PreparedTeam, side: String, tm: int) -> float:
	var ahead: bool = _gd > 0 if side == "A" else _gd < 0
	var f: float = 0.0
	for pp: PreparedPlayer in team.ps:
		var mec: float = pp.s[0]
		if pp.p.has_trait("Late-Game-Monster"):
			mec += 4
		if pp.p.has_trait("Carry") and ahead:
			mec += 4
		f += 0.5 * mec + 0.3 * pp.s[3] + 0.2 * pp.s[2]
	if team.has_any_trait("Engage Caller"):
		f += 3
	f += _comp_at(side, tm) + _drakes[side]
	if _baron_buff[side] >= tm:
		f += 5
	return f


## Kills in einem Teamfight (doKills im Original).
func _do_fight_kills(winners: PreparedTeam, losers: PreparedTeam, n: int) -> void:
	for _i: int in n:
		var kw: Array[float] = []
		for x: PreparedPlayer in winners.ps:
			var mec: float = maxf(1.0, x.s[0])
			kw.append(mec * mec)
		var killer: PreparedPlayer = _rng.weighted(winners.ps, kw)
		var victim: PreparedPlayer = _rng.weighted(losers.ps, _victim_weights(losers))
		killer.kills += 1
		victim.deaths += 1
		var assists: Array[PreparedPlayer] = []
		for x: PreparedPlayer in winners.ps:
			if x != killer and _rng.next_float() < x.s[3] / 100.0:
				assists.append(x)
		for x: PreparedPlayer in assists:
			x.assists += 1
		_pay_kill(killer, assists)


## Opfer-Gewichte: wenig Mental = eher Opfer; "Risikoarm" senkt das Risiko.
func _victim_weights(team: PreparedTeam) -> Array[float]:
	var weights: Array[float] = []
	for x: PreparedPlayer in team.ps:
		weights.append(maxf(1.0, 100 - x.s[4]) * (0.7 if x.p.has_trait("Risikoarm") else 1.0))
	return weights


# --- Gold, Log, Bewertung ---------------------------------------------------

## Kill-Gold: 70 % an den Killer, 30 % an die Assists.
func _pay_kill(killer: PreparedPlayer, assists: Array[PreparedPlayer]) -> void:
	if not assists.is_empty():
		killer.gold += 0.7 * _c["kill"]
		for x: PreparedPlayer in assists:
			x.gold += 0.3 * _c["kill"] / assists.size()
	else:
		killer.gold += _c["kill"]


func _pay_team(team: PreparedTeam, g: float) -> void:
	for x: PreparedPlayer in team.ps:
		x.gold += g / 5.0


## Trägt die Golddifferenz für alle Minuten bis m ein (setGold).
func _set_gold(m: int, value: float) -> void:
	for x: int in range(_minute + 1, m + 1):
		_gold_at[x] = int(value)
	_minute = m


func _ev(minute: int, text: String, side: String, kind: String) -> void:
	_log.append(MatchResult.LogEntry.new(minute, text, side, kind))


func _team_gold(team: PreparedTeam) -> int:
	var total: float = 0.0
	for x: PreparedPlayer in team.ps:
		total += x.gold
	return RiftSim.js_round(total)


func _team_kills(team: PreparedTeam) -> int:
	var total: int = 0
	for x: PreparedPlayer in team.ps:
		total += x.kills
	return total


## Spielnoten (rate im Original).
func _rate(team: PreparedTeam, opponent: PreparedTeam, won: bool) -> Array[MatchResult.PlayerRating]:
	var result: Array[MatchResult.PlayerRating] = []
	for pp: PreparedPlayer in team.ps:
		var opp: PreparedPlayer = opponent.by(pp.role)
		var kda: float = float(pp.kills + pp.assists) / maxi(1, pp.deaths)
		var wn: int = 1 if won else -1
		var kda_base: float = float(_c["kdaBase"].get(pp.role, 3))
		var raw: float = clampf(_c["ratingBase"] + 5 * wn + 0.4 * (pp.ovr - opp.ovr)
				+ 2 * clampf(kda - kda_base, -4.0, 4.0) + pp.d, 0.0, 100.0)
		var grade: float = 100 - (100 - raw) * _c["ratingCompress"]  # höherer Boden, gleiche Spitze
		var rating := MatchResult.PlayerRating.new()
		rating.player = pp.p
		rating.name = pp.p.display_name()
		rating.role = pp.role
		rating.kills = pp.kills
		rating.deaths = pp.deaths
		rating.assists = pp.assists
		rating.kda = kda
		rating.grade = RiftSim.js_round(grade)
		rating.comm = pp.comm
		rating.gold = RiftSim.js_round(pp.gold)
		result.append(rating)
	return result


## MVP: beste Note im Siegerteam; bei Gleichstand der Spieler mit der früheren Rolle.
func _mvp(ratings: Array[MatchResult.PlayerRating]) -> String:
	var best: MatchResult.PlayerRating = ratings[0]
	for rating: MatchResult.PlayerRating in ratings:
		if rating.grade > best.grade:
			best = rating
	return best.name
