# Reel symbols: characters (summon units from paylines), powers (squad-wide permanent buffs), curses.
# A spin fills a 3x3 grid from a bag = your pool + empties, weighted by rarity. See resolve().
# Neighbours (8 around a cell) combo: Might levels up adjacent characters, Haste doubles
# adjacent powers, Skull destroys adjacent curses for good, Knight blocks adjacent curses.
const RARITY_WEIGHT := {common = 1.0, rare = 0.7, epic = 0.45, legendary = 0.25, curse = 0.8}
const RARITY_COLOR := {common = Color("b8b8b8"), rare = Color("4aa8ff"), epic = Color("c05cff"), legendary = Color("ffb020"), curse = Color("d0303a")}

# Units: attack = melee (hit all in range ahead) | shot (projectile; pierce/blast/crit optional) | heal
const DATA := {
	blank = {name = "Empty", letter = "", color = Color("34343e"), rarity = "common", type = "blank"},

	swordsman = {name = "Swordsman", letter = "Sw", color = Color("d0d0d8"), rarity = "common", type = "unit",
		attack = "melee", hp = 70.0, dmg = 20.0, range = 110.0, cd = 0.7, desc = "Slashes every enemy close in front"},
	archer = {name = "Archer", letter = "Ar", color = Color("6cc04a"), rarity = "common", type = "unit",
		attack = "shot", hp = 40.0, dmg = 9.0, range = 850.0, cd = 0.7, desc = "Long-range arrows"},
	spearman = {name = "Spearman", letter = "Sp", color = Color("c09050"), rarity = "common", type = "unit",
		attack = "shot", pierce = 3, hp = 55.0, dmg = 8.0, range = 600.0, cd = 0.9, desc = "Thrown spear pierces 3 enemies"},
	mage = {name = "Mage", letter = "Mg", color = Color("4a7cff"), rarity = "rare", type = "unit",
		attack = "shot", blast = 90.0, hp = 40.0, dmg = 14.0, range = 650.0, cd = 1.3, desc = "Magic blast hits an area"},
	healer = {name = "Healer", letter = "He", color = Color("7af0c0"), rarity = "rare", type = "unit",
		attack = "heal", hp = 45.0, dmg = 10.0, range = 900.0, cd = 1.2, desc = "Heals the most hurt ally"},
	bomber = {name = "Bomber", letter = "Bo", color = Color("ff8a3a"), rarity = "rare", type = "unit",
		attack = "shot", blast = 140.0, hp = 45.0, dmg = 32.0, range = 550.0, cd = 2.4, desc = "Slow, huge explosion"},
	knight = {name = "Knight", letter = "Kn", color = Color("a0b4d0"), rarity = "epic", type = "unit",
		attack = "melee", hp = 260.0, dmg = 16.0, range = 100.0, cd = 0.9, desc = "Tank. Blocks curses next to it on the reels"},
	assassin = {name = "Assassin", letter = "As", color = Color("9a4ad0"), rarity = "epic", type = "unit",
		attack = "shot", crit = 0.3, hp = 50.0, dmg = 15.0, range = 700.0, cd = 0.3, desc = "Rapid knives, 30% crit x3"},
	champion = {name = "Champion", letter = "Ch", color = Color("ffc83a"), rarity = "legendary", type = "unit",
		attack = "shot", blast = 80.0, hp = 160.0, dmg = 22.0, range = 600.0, cd = 0.25, desc = "Golden lancer: rapid strikes that splash"},

	might = {name = "Might", letter = "+D", color = Color("e0b040"), rarity = "common", type = "power",
		stat = "might", amount = 10.0, desc = "Dmg +10%. Characters next to it arrive +1 level"},
	haste = {name = "Haste", letter = "+S", color = Color("4ad0e0"), rarity = "common", type = "power",
		stat = "haste", amount = 8.0, desc = "Speed +8%. Powers next to it pay x2"},
	vigor = {name = "Vigor", letter = "+H", color = Color("4ae08a"), rarity = "common", type = "power",
		stat = "vigor", amount = 10.0, desc = "Squad max HP +10%, heal 10%"},
	magnet = {name = "Magnet", letter = "Mn", color = Color("b04ae0"), rarity = "common", type = "power",
		stat = "magnet", amount = 0.5, desc = "Pull coins from further away"},
	seven = {name = "Seven", letter = "7", color = Color("ff5fa2"), rarity = "rare", type = "power",
		stat = "gold", amount = 40.0, desc = "+40 gold. 7-7-7 on a line: JACKPOT +5 free spins"},
	skull = {name = "Skull", letter = "X", color = Color("8a8a8a"), rarity = "common", type = "power",
		stat = "gold", amount = 60.0, desc = "+60 gold, enemies +5% HP. Destroys curses next to it"},
	lamb = {name = "Lamb", letter = "L", color = Color("f0f0e0"), rarity = "common", type = "power",
		stat = "gold", amount = 20.0, hatch = 3, desc = "+20 gold. After landing 3 times it grows into a random rare+ hero"},
}
# Curses: bad outcomes that live on the reels. Same match rule (pair x4, triple x9).
# One more joins the reels at the start of every wave; the draft can remove them for gold.
const CURSES := {
	trap = {name = "Trap", letter = "!", color = Color("d0303a"), rarity = "curse", type = "curse",
		stat = "trap", amount = 0.08, desc = "CURSE: every unit loses 8% HP"},
	thief = {name = "Thief", letter = "$", color = Color("d0303a"), rarity = "curse", type = "curse",
		stat = "thief", amount = 0.15, desc = "CURSE: steals 15% of your gold"},
	ambush = {name = "Ambush", letter = "A", color = Color("d0303a"), rarity = "curse", type = "curse",
		stat = "ambush", amount = 2.0, desc = "CURSE: 2 runners charge your squad"},
}
const STARTER := ["swordsman", "swordsman", "archer", "might", "haste", "trap"]
const BAG_MIN := 10
const BLANK_MIN := 3
const ROWS := 3
const COLS := 3
const CELLS := 9
const CENTER := 4
# Paylines over the 3x3 grid (row-major cell indices): 3 rows + 2 diagonals.
const LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 4, 8], [6, 4, 2]]
const GROW_EVERY := 10   # a symbol type ranks up every this many landings...
const MAX_RANK := 3      # ...up to this rank. Each rank: characters +1 level, powers and curses +50%


static func tier_mult(tier: int) -> float:
	return pow(2.0, tier - 1)


static func empty_buffs() -> Dictionary:
	return {might = 0.0, haste = 0.0, vigor = 0.0, magnet = 0.0, enemy_hp = 0.0, heal = 0.0, gold = 0, spins = 0,
		trap = 0.0, thief = 0.0, ambush = 0}


static func info(id: String) -> Dictionary:
	return CURSES[id] if CURSES.has(id) else DATA[id]


static func is_curse(id: String) -> bool:
	return CURSES.has(id)


static func bag(pool: Array) -> Array:
	var b: Array = pool.duplicate()
	for i in maxi(BLANK_MIN, BAG_MIN - pool.size()):
		b.append("blank")
	return b


# ctx.items: "leaf" = fewer empties, "nugget" = rare+ land more often.
static func roll(pool: Array, ctx := {}) -> Array:
	var items: Array = ctx.get("items", [])
	var b := bag(pool)
	var weights := PackedFloat32Array()
	for id in b:
		var rar: String = info(id).rarity
		var w: float = RARITY_WEIGHT[rar]
		if id == "blank" and items.has("leaf"):
			w *= 0.4
		if rar in ["rare", "epic", "legendary"] and items.has("nugget"):
			w *= 1.6
		weights.append(w)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := []
	for i in CELLS:
		out.append(str(b[rng.rand_weighted(weights)]))
	return out


# 8 neighbours of a cell in the 3x3 grid.
static func neighbours(i: int) -> Array:
	var out := []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var r: int = i / COLS + dy
			var c: int = i % COLS + dx
			if (dx != 0 or dy != 0) and r >= 0 and r < ROWS and c >= 0 and c < COLS:
				out.append(r * COLS + c)
	return out


static func _find_adj(grid: Array, i: int, id: String) -> int:
	for j in neighbours(i):
		if grid[j] == id:
			return j
	return -1


# grid: 9 symbol ids, row-major. ctx: {ranks: {id: rank}, items: [ids], cores: [ids]}.
# Every power/curse cell pays on its own (neighbours combo). Characters only summon from lines:
# 2 of the same on a payline = Lv1 unit, 3 = Lv3 (JACKPOT). Three powers/curses in a line pay double.
# Returns {summons: [[id, tier]], buffs, jackpot, destroyed: [curse ids], lines: [line indices that hit],
#  events: [{i, text, color, buffs, summon?, count?, destroy?, link?, cells?}]} cell events first, then lines.
static func resolve(grid: Array, ctx := {}) -> Dictionary:
	var ranks: Dictionary = ctx.get("ranks", {})
	var items: Array = ctx.get("items", [])
	var cores: Array = ctx.get("cores", [])
	var res := {summons = [], buffs = empty_buffs(), jackpot = false, destroyed = [], lines = [], events = []}
	var cell_buffs := []
	for i in CELLS:
		var id := str(grid[i])
		var d: Dictionary = info(id)
		var ev := {i = i, text = "", color = d.color}
		var b := empty_buffs()
		var grow: float = 1.0 + 0.5 * ranks.get(id, 0)
		if i == CENTER and cores.has("heart"):
			grow *= 3.0
		if d.type == "blank":
			if items.has("axe"):
				b.gold += 20
				ev.text = "+20 gold"
		elif d.type == "curse":
			var skull := _find_adj(grid, i, "skull")
			var knight := _find_adj(grid, i, "knight")
			if skull >= 0:
				res.destroyed.append(id)
				ev.merge({text = "DESTROYED", color = Color("ffe14d"), destroy = id, link = skull}, true)
			elif knight >= 0:
				ev.merge({text = "BLOCKED", color = Color("a0b4d0"), link = knight}, true)
			else:
				var amt: float = d.amount * grow * (0.5 if items.has("ward") else 1.0)
				b[d.stat] += maxi(1, roundi(amt)) if d.stat == "ambush" else amt
				ev.text = _buff_text(b)
			if cores.has("chaos"):
				b.gold += 80
				ev.text += ("\n" if ev.text else "") + "+80 gold"
		elif d.type == "power":
			var haste := _find_adj(grid, i, "haste")
			var amt: float = d.amount * grow * (2.0 if haste >= 0 else 1.0)
			if id == "seven" and items.has("pickaxe"):
				amt *= 2.0
			if d.stat == "gold":
				b.gold += roundi(amt)
			else:
				b[d.stat] += amt
			if id == "vigor":
				b.heal += 0.1
			if id == "skull":
				b.enemy_hp += 0.05
			ev.text = _buff_text(b) + (" x2" if haste >= 0 else "")
			if haste >= 0:
				ev.link = haste
		cell_buffs.append(b)
		add(res.buffs, b)
		ev.buffs = b
		if ev.text != "":
			res.events.append(ev)

	for k in LINES.size():
		var line: Array = LINES[k]
		var ids: Array = line.map(func(c): return str(grid[c]))
		# one event per symbol that repeats on this line
		var seen := {}
		for id in ids:
			var n: int = ids.count(id)
			if id == "blank" or n < 2 or seen.has(id):
				continue
			seen[id] = true
			var d: Dictionary = info(id)
			var cells: Array = line.filter(func(c): return grid[c] == id)
			var ev := {i = line[1], cells = cells, color = Color("ffe14d"), buffs = empty_buffs()}
			if d.type == "unit":
				var might := -1
				for c in cells:
					if might < 0:
						might = _find_adj(grid, c, "might")
				var tier: int = (3 if n == 3 else 1) + ranks.get(id, 0) + (1 if might >= 0 else 0)
				if n == 2 and items.has("hammer"):
					tier += 1
				if k >= 3 and cores.has("crossroads"):
					tier += 1
				tier = mini(tier, 5)
				ev.summon = [id, tier]
				ev.count = 2 if n == 2 and cores.has("barracks") else 1
				ev.text = "%s%s Lv%d" % ["2x " if ev.count == 2 else "", d.name, tier]
				if might >= 0:
					ev.link = might
				for j in ev.count:
					res.summons.append(ev.summon)
			elif n == 3 and d.type in ["power", "curse"]:  # three in a line: the line pays again
				var b := empty_buffs()
				var reps := 2 if cores.has("jackpot") else 1
				for c in cells:
					for r in reps:
						add(b, cell_buffs[c])
				if id == "seven":
					b.spins += 5
				ev.buffs = b
				ev.text = "LINE x%d\n%s" % [2 * reps, _buff_text(b)]
				ev.color = Color("ff5050") if d.type == "curse" else Color("ffe14d")
				add(res.buffs, b)
			else:
				continue
			if n == 3:
				res.jackpot = true
			res.lines.append(k)
			res.events.append(ev)
	return res


static func _buff_text(b: Dictionary) -> String:
	var parts := []
	if b.might: parts.append("+%d%% dmg" % b.might)
	if b.haste: parts.append("+%d%% spd" % b.haste)
	if b.vigor: parts.append("+%d%% HP" % b.vigor)
	if b.magnet: parts.append("magnet")
	if b.gold: parts.append("+%d gold" % b.gold)
	if b.spins: parts.append("+%d spin" % b.spins)
	if b.trap: parts.append("-%d%% HP" % roundi(b.trap * 100))
	if b.thief: parts.append("-%d%% gold" % roundi(minf(b.thief, 1.0) * 100))
	if b.ambush: parts.append("AMBUSH x%d" % b.ambush)
	return "\n".join(parts)


static func add(into: Dictionary, b: Dictionary) -> void:
	for k in into:
		into[k] += b[k]


static func summary(res: Dictionary) -> String:
	var parts := []
	for s in res.summons:
		parts.append(DATA[s[0]].name + (" Lv%d" % s[1] if s[1] > 1 else ""))
	var b: Dictionary = res.buffs
	if b.might: parts.append("+%d%% dmg" % b.might)
	if b.haste: parts.append("+%d%% speed" % b.haste)
	if b.vigor: parts.append("+%d%% HP" % b.vigor)
	if b.magnet: parts.append("+magnet")
	if b.gold: parts.append("+%d gold" % b.gold)
	if b.spins: parts.append("+%d spins" % b.spins)
	if b.trap: parts.append("TRAP -%d%% HP" % roundi(b.trap * 100))
	if b.thief: parts.append("THIEF -%d%% gold" % roundi(minf(b.thief, 1.0) * 100))
	if b.ambush: parts.append("AMBUSH x%d" % b.ambush)
	return ", ".join(parts) if parts else "nothing"


# Draft offers rolled by rarity: 60% common, 27% rare, 10% epic, 3% legendary.
# rare_plus: wave rewards only offer rare or better.
static func draft_offers(n: int, rare_plus := false) -> Array:
	var out := []
	while out.size() < n:
		var r := randf() * (0.4 if rare_plus else 1.0)
		var rar := "legendary" if r < 0.03 else "epic" if r < 0.13 else "rare" if r < 0.4 else "common"
		var ids: Array = DATA.keys().filter(func(k): return k != "blank" and DATA[k].rarity == rar and not out.has(str(k)))
		if not ids.is_empty():
			out.append(str(ids.pick_random()))
	return out
