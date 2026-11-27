# Fate Stones: per-run trials, one per grade (C, B, A). Win `need` waves in a row while keeping
# the rule; a broken rule resets the streak, and a trial expires after WAVES waves. A finished
# trial gives a FATE SPIN: a free spin that always lands a hero line and rolls heroes with
# POWER[grade] fate (Symbols.pick_hero), so rare/epic/legendary heroes come up far more often.
const WAVES := 6
const GRADES := ["C", "B", "A"]
const POWER := {C = 4, B = 8, A = 14}
const COLOR := {C = Color("3f9a6a"), B = Color("3a6ad0"), A = Color("d0403a")}
const TRIALS := {
	C = [
		{id = "breeze", name = "Breeze", need = 3, rule = "Max 2 spins before each wave", spins = 2},
		{id = "steady", name = "Steady", need = 3, rule = "No hero falls", deaths = 0},
		{id = "hoard", name = "Hoard", need = 3, rule = "FIGHT with 400+ gold left", gold = 400},
	],
	B = [
		{id = "special", name = "Special", need = 4, rule = "No hero falls", deaths = 0},
		{id = "bond", name = "Bond", need = 3, rule = "2+ faction synergies active", syn = 2},
		{id = "vital", name = "Vital", need = 3, rule = "End waves with 60%+ squad HP", hp = 0.6},
		{id = "lean", name = "Lean", need = 3, rule = "FIGHT with 5 or fewer heroes", max_squad = 5},
		{id = "promoted", name = "Promoted", need = 3, rule = "2+ promoted heroes", promoted = 2},
	],
	A = [
		{id = "constellation", name = "Constellation", need = 3, rule = "3+ faction synergies active", syn = 3},
		{id = "ascetic", name = "Ascetic", need = 4, rule = "Max 1 spin before each wave", spins = 1},
		{id = "flawless", name = "Flawless", need = 3, rule = "No hero falls, max 3 spins", deaths = 0, spins = 3},
		{id = "ascended", name = "Ascended", need = 2, rule = "2+ heroes at Class II", class2 = 2},
		{id = "imprinted", name = "Imprinted", need = 2, rule = "A hero with a level-3 imprint", imp3 = 1},
	],
}


static func new_trial(grade: String, not_id := "") -> Dictionary:
	var pick: Array = TRIALS[grade].filter(func(t): return t.id != not_id)
	var t: Dictionary = pick.pick_random().duplicate()
	t.grade = grade
	t.progress = 0
	t.left = WAVES
	return t


# w = the wave just won: {spins, deaths, gold, squad, syn, hp, promoted}.
static func ok(t: Dictionary, w: Dictionary) -> bool:
	return w.spins <= t.get("spins", 999) and w.deaths <= t.get("deaths", 999) and w.gold >= t.get("gold", 0) \
		and w.squad <= t.get("max_squad", 999) and w.syn >= t.get("syn", 0) and w.hp >= t.get("hp", 0.0) \
		and w.promoted >= t.get("promoted", 0) and w.get("class2", 0) >= t.get("class2", 0) and w.get("imp3", 0) >= t.get("imp3", 0)


# After a won wave: streak +1 (or reset), one wave less. True when the trial is complete.
static func advance(t: Dictionary, w: Dictionary) -> bool:
	t.left -= 1
	t.progress = t.progress + 1 if ok(t, w) else 0
	return t.progress >= t.need
