# Reel symbols: heroes (summoned by three in a line) and powers (squad-wide permanent buffs).
# A spin fills a 3x3 grid from your pool, weighted by rarity - no empty cells, so every symbol type
# you add makes triples rarer (focused reels hit more often). See resolve().
# Neighbours (8 around a cell) combo: Might levels up adjacent heroes, Haste doubles adjacent powers.
const RARITY_WEIGHT := {common = 1.0, rare = 0.7, epic = 0.45, legendary = 0.25}
const RARITY_COLOR := {common = Color("b8b8b8"), rare = Color("4aa8ff"), epic = Color("c05cff"), legendary = Color("ffb020")}

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
		attack = "melee", hp = 260.0, dmg = 16.0, range = 100.0, cd = 0.9, desc = "Tank. Stands in front and cleaves"},
	assassin = {name = "Assassin", letter = "As", color = Color("9a4ad0"), rarity = "epic", type = "unit",
		attack = "shot", crit = 0.3, hp = 50.0, dmg = 15.0, range = 700.0, cd = 0.3, desc = "Rapid knives, 30% crit x3"},
	champion = {name = "Champion", letter = "Ch", color = Color("ffc83a"), rarity = "legendary", type = "unit",
		attack = "shot", blast = 80.0, hp = 160.0, dmg = 22.0, range = 600.0, cd = 0.25, desc = "Golden lancer: rapid strikes that splash"},

	shieldmaiden = {name = "Shieldmaiden", letter = "Sh", color = Color("f0d060"), rarity = "rare", type = "unit",
		attack = "melee", ability = "taunt", hp = 220.0, dmg = 12.0, range = 100.0, cd = 1.0, desc = "Taunts: nearby enemies must attack her"},
	frostmage = {name = "Frost Mage", letter = "Fr", color = Color("8fd8ff"), rarity = "rare", type = "unit",
		attack = "shot", ability = "slow", hp = 40.0, dmg = 10.0, range = 640.0, cd = 1.1, desc = "Frost bolts slow enemies by 40%"},
	hunter = {name = "Hunter", letter = "Hu", color = Color("8a9a5a"), rarity = "common", type = "unit",
		attack = "shot", shots = 2, hp = 45.0, dmg = 7.0, range = 760.0, cd = 0.8, desc = "Shoots 2 enemies at once"},
	bard = {name = "Bard", letter = "Bd", color = Color("ffd27a"), rarity = "epic", type = "unit",
		attack = "aura", hp = 60.0, dmg = 0.0, range = 520.0, cd = 3.0, desc = "Every 3s nearby heroes attack 40% faster"},
	skylancer = {name = "Skylancer", letter = "Sk", color = Color("6a7aa0"), rarity = "epic", type = "unit",
		attack = "melee", ability = "leap", hp = 140.0, dmg = 26.0, range = 110.0, cd = 0.9, desc = "Leaps onto the enemy back row"},

	might = {name = "Might", letter = "+D", color = Color("e0b040"), rarity = "common", type = "power",
		stat = "might", amount = 5.0, desc = "Dmg +5%. Heroes next to it arrive +1 level"},
	haste = {name = "Haste", letter = "+S", color = Color("4ad0e0"), rarity = "common", type = "power",
		stat = "haste", amount = 4.0, desc = "Speed +4%. Powers next to it pay x2"},
	vigor = {name = "Vigor", letter = "+H", color = Color("4ae08a"), rarity = "common", type = "power",
		stat = "vigor", amount = 5.0, desc = "Squad max HP +5%, heal 10%"},
	magnet = {name = "Bounty", letter = "Mn", color = Color("b04ae0"), rarity = "common", type = "power",
		stat = "magnet", amount = 0.1, desc = "Enemies drop +10% gold (stacks up to +100%)"},
	seven = {name = "Seven", letter = "7", color = Color("ff5fa2"), rarity = "rare", type = "power",
		stat = "gold", amount = 40.0, desc = "+40 gold. 7-7-7 on a line: JACKPOT +5 free spins"},
	skull = {name = "Skull", letter = "X", color = Color("8a8a8a"), rarity = "common", type = "power",
		stat = "gold", amount = 60.0, desc = "+60 gold, but enemies +5% HP"},
	lamb = {name = "Lamb", letter = "L", color = Color("f0f0e0"), rarity = "common", type = "power",
		stat = "gold", amount = 20.0, hatch = 3, desc = "+20 gold. After landing 3 times it grows into a random rare+ hero"},
}
# Class promotions: a hero at Lv3+ picks one of two classes (once). mul = stat multipliers
# (only applied to stats the hero has), set = stats added/replaced. tint colours the sprite.
const CLASS_TIER := 3
const CLASSES := {
	swordsman = [
		{id = "guardian", name = "Guardian", tint = Color(0.75, 0.85, 1.2), desc = "Tank: x2 HP, a bit less damage", mul = {hp = 2.0, dmg = 0.8}},
		{id = "berserker", name = "Berserker", tint = Color(1.3, 0.75, 0.7), desc = "x1.6 damage, faster swings, less HP", mul = {dmg = 1.6, cd = 0.8, hp = 0.8}},
	],
	archer = [
		{id = "ranger", name = "Ranger", tint = Color(0.8, 1.25, 0.8), desc = "Fires 70% faster", mul = {cd = 0.6}},
		{id = "sniper", name = "Sniper", tint = Color(1.2, 1.1, 0.7), desc = "x1.4 damage, 35% crits, longer range", mul = {dmg = 1.4, range = 1.3}, set = {crit = 0.35}},
	],
	spearman = [
		{id = "impaler", name = "Impaler", tint = Color(1.25, 0.9, 0.7), desc = "Spears pierce 7 enemies", set = {pierce = 7}},
		{id = "dragoon", name = "Dragoon", tint = Color(0.9, 0.9, 1.3), desc = "x1.5 damage, spears explode", mul = {dmg = 1.5}, set = {blast = 60.0}},
	],
	mage = [
		{id = "pyromancer", name = "Pyromancer", tint = Color(1.35, 0.75, 0.6), desc = "Bigger blasts, x1.3 damage", mul = {blast = 1.6, dmg = 1.3}},
		{id = "stormcaller", name = "Stormcaller", tint = Color(0.75, 0.95, 1.4), desc = "Casts almost twice as fast", mul = {cd = 0.55}},
	],
	healer = [
		{id = "priest", name = "Priest", tint = Color(1.25, 1.2, 0.8), desc = "Heals x1.8 more", mul = {dmg = 1.8}},
		{id = "oracle", name = "Oracle", tint = Color(0.9, 0.8, 1.35), desc = "Heals the whole squad at once", mul = {dmg = 0.55, cd = 1.2}, set = {attack = "heal_all"}},
	],
	bomber = [
		{id = "demolisher", name = "Demolisher", tint = Color(1.3, 0.8, 0.65), desc = "Huge blast, x1.4 damage", mul = {blast = 1.5, dmg = 1.4}},
		{id = "sapper", name = "Sapper", tint = Color(0.85, 1.2, 0.85), desc = "Throws twice as often", mul = {cd = 0.5, blast = 0.8}},
	],
	knight = [
		{id = "paladin", name = "Paladin", tint = Color(1.25, 1.2, 0.85), desc = "x1.6 HP, x1.2 damage", mul = {hp = 1.6, dmg = 1.2}},
		{id = "warden", name = "Warden", tint = Color(0.8, 0.9, 1.3), desc = "Cleaves twice as far", mul = {range = 2.0}},
	],
	assassin = [
		{id = "shadow", name = "Shadow", tint = Color(0.8, 0.7, 1.2), desc = "60% crits", set = {crit = 0.6}},
		{id = "blademaster", name = "Blademaster", tint = Color(1.25, 0.85, 0.85), desc = "Knives pierce 2, x1.3 damage", mul = {dmg = 1.3}, set = {pierce = 2}},
	],
	shieldmaiden = [
		{id = "bulwark", name = "Bulwark", tint = Color(0.85, 0.95, 1.25), desc = "x1.7 HP", mul = {hp = 1.7}},
		{id = "valkyrie", name = "Valkyrie", tint = Color(1.3, 0.85, 0.7), desc = "x1.8 damage, still taunts", mul = {dmg = 1.8}},
	],
	frostmage = [
		{id = "cryomancer", name = "Cryomancer", tint = Color(0.7, 0.95, 1.4), desc = "Casts 40% faster", mul = {cd = 0.6}},
		{id = "glacier", name = "Glacier", tint = Color(0.9, 1.0, 1.3), desc = "Frost bolts burst and slow an area", set = {blast = 80.0}},
	],
	hunter = [
		{id = "trapper", name = "Trapper", tint = Color(0.85, 1.2, 0.8), desc = "Shoots 3 enemies at once", set = {shots = 3}},
		{id = "falconer", name = "Falconer", tint = Color(1.2, 1.05, 0.75), desc = "x1.6 damage", mul = {dmg = 1.6}},
	],
	bard = [
		{id = "skald", name = "Skald", tint = Color(1.3, 1.0, 0.7), desc = "Aura reaches 50% further, every 2s", mul = {range = 1.5, cd = 0.67}},
		{id = "minstrel", name = "Minstrel", tint = Color(0.85, 1.25, 0.9), desc = "Aura also heals 10% HP", set = {heal = 0.1}},
	],
	skylancer = [
		{id = "dragonfang", name = "Dragonfang", tint = Color(1.3, 0.75, 0.65), desc = "x1.5 damage", mul = {dmg = 1.5}},
		{id = "stormrider", name = "Stormrider", tint = Color(0.75, 0.9, 1.35), desc = "Strikes 40% faster, more HP", mul = {cd = 0.6, hp = 1.3}},
	],
	champion = [
		{id = "hero", name = "Hero", tint = Color(1.3, 1.2, 0.8), desc = "x1.3 HP, damage and speed", mul = {hp = 1.3, dmg = 1.3, cd = 0.77}},
		{id = "conqueror", name = "Conqueror", tint = Color(1.3, 0.75, 0.7), desc = "Splash twice as big", mul = {blast = 2.0}},
	],
}

const STARTER := ["swordsman", "swordsman", "swordsman", "archer", "archer", "might", "haste"]
const ROWS := 3
const COLS := 3
const CELLS := 9
const CENTER := 4
# Lines over the 3x3 grid (row-major cell indices): 3 rows, 3 columns, 2 diagonals.
const LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [6, 4, 2]]
const DIAGONALS := [6, 7]
const JACKPOT_LINES := 3  # this many lines in one spin = JACKPOT: every summon +1 level
const GROW_EVERY := 10   # a symbol type ranks up every this many landings...
const MAX_RANK := 3      # ...up to this rank. Each rank: heroes +1 level, powers +50%


static func tier_mult(tier: int) -> float:
	return pow(2.0, tier - 1)


static func empty_buffs() -> Dictionary:
	return {might = 0.0, haste = 0.0, vigor = 0.0, magnet = 0.0, enemy_hp = 0.0, heal = 0.0, gold = 0, spins = 0}


static func info(id: String) -> Dictionary:
	return DATA[id]


# ctx.items: "leaf" = heroes land more often, "nugget" = rare+ land more often.
static func roll(pool: Array, ctx := {}) -> Array:
	var items: Array = ctx.get("items", [])
	var b := pool
	var weights := PackedFloat32Array()
	for id in b:
		var rar: String = info(id).rarity
		var w: float = RARITY_WEIGHT[rar]
		if DATA[id].type == "unit" and items.has("leaf"):
			w *= 1.25
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
# Powers pay a little from every cell (neighbours combo). Three of the same in a line (any of the
# 8 lines) is a hit: heroes summon a Lv1 unit (+levels from rank, Might, items, cores), powers pay the
# line again, 7-7-7 adds 5 free spins. JACKPOT_LINES hits in one spin = JACKPOT (+1 level to all).
# Returns {summons: [[id, tier]], buffs, jackpot, lines: [line indices that hit],
#  events: [{i, text, color, buffs, summon?, count?, link?, cells?}]} cell events first, then lines.
static func resolve(grid: Array, ctx := {}) -> Dictionary:
	var ranks: Dictionary = ctx.get("ranks", {})
	var items: Array = ctx.get("items", [])
	var cores: Array = ctx.get("cores", [])
	var res := {summons = [], buffs = empty_buffs(), jackpot = false, lines = [], events = []}
	var cell_buffs := []
	for i in CELLS:
		var id := str(grid[i])
		var d: Dictionary = info(id)
		var ev := {i = i, text = "", color = d.color}
		var b := empty_buffs()
		var grow: float = 1.0 + 0.5 * ranks.get(id, 0)
		if i == CENTER and cores.has("heart"):
			grow *= 3.0
		if d.type == "power":
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

	var on_line := {}
	for k in LINES.size():
		var line: Array = LINES[k]
		var id := str(grid[line[0]])
		if id == "blank" or grid[line[1]] != id or grid[line[2]] != id:
			continue
		var d: Dictionary = info(id)
		var ev := {i = line[1], cells = line, color = Color("ffe14d"), buffs = empty_buffs()}
		if d.type == "unit":
			var might := -1
			for c in line:
				if might < 0:
					might = _find_adj(grid, c, "might")
			var tier: int = 1 + ranks.get(id, 0) + (1 if might >= 0 else 0) + (1 if items.has("hammer") else 0)
			if DIAGONALS.has(k) and cores.has("crossroads"):
				tier += 1
			ev.summon = [id, mini(tier, 5)]
			ev.count = 2 if cores.has("barracks") else 1
			if might >= 0:
				ev.link = might
		else:  # three powers in a line: the line pays again
			var b := empty_buffs()
			for c in line:
				for r in (2 if cores.has("jackpot") else 1):
					add(b, cell_buffs[c])
			if id == "seven":
				b.spins += 5
			ev.buffs = b
			ev.text = "LINE x%d\n%s" % [3 if cores.has("jackpot") else 2, _buff_text(b)]
			add(res.buffs, b)
		for c in line:
			on_line[c] = true
		res.lines.append(k)
		res.events.append(ev)

	res.jackpot = res.lines.size() >= JACKPOT_LINES
	for ev in res.events:
		if ev.has("summon"):
			if res.jackpot:
				ev.summon = [ev.summon[0], mini(ev.summon[1] + 1, 5)]
			ev.text = "%s%s Lv%d" % ["2x " if ev.count == 2 else "", DATA[ev.summon[0]].name, ev.summon[1]]
			for j in ev.count:
				res.summons.append(ev.summon)

	var miss := {i = CENTER, text = "", color = Color("ffe14d"), buffs = empty_buffs()}
	if res.lines.is_empty() and items.has("axe"):  # consolation for a spin with no line
		miss.buffs.gold += 60
	if cores.has("chaos"):  # heroes that land off any line still pay
		for c in CELLS:
			if not on_line.has(c) and DATA.get(str(grid[c]), {}).get("type", "") == "unit":
				miss.buffs.gold += 15
	if miss.buffs.gold > 0:
		miss.text = "+%d gold" % miss.buffs.gold
		add(res.buffs, miss.buffs)
		res.events.append(miss)
	return res


static func _buff_text(b: Dictionary) -> String:
	var parts := []
	if b.might: parts.append("+%d%% dmg" % b.might)
	if b.haste: parts.append("+%d%% spd" % b.haste)
	if b.vigor: parts.append("+%d%% HP" % b.vigor)
	if b.magnet: parts.append("magnet")
	if b.gold: parts.append("+%d gold" % b.gold)
	if b.spins: parts.append("+%d spin" % b.spins)
	return "\n".join(parts)


# Stats of `type` promoted to class index `k` (CLASSES[type][k]).
static func class_stats(type: String, k: int) -> Dictionary:
	var c: Dictionary = CLASSES[type][k]
	var d: Dictionary = DATA[type].duplicate()
	for key in c.get("mul", {}):
		if d.has(key):
			d[key] = d[key] * c.mul[key]
	d.merge(c.get("set", {}), true)
	d.cls = c.id
	d.cls_name = c.name
	d.tint = c.tint
	return d


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
	return ", ".join(parts) if parts else "nothing"


# Draft offers rolled by rarity: 60% common, 27% rare, 10% epic, 3% legendary.
# rare_plus: wave rewards only offer rare or better.
# luck (0..1) shrinks the roll, so rarer heroes come up more often.
static func draft_offers(n: int, rare_plus := false, luck := 0.0) -> Array:
	var out := []
	while out.size() < n:
		var r := randf() * (0.4 if rare_plus else 1.0) * (1.0 - luck)
		var rar := "legendary" if r < 0.03 else "epic" if r < 0.13 else "rare" if r < 0.4 else "common"
		var ids: Array = DATA.keys().filter(func(k): return k != "blank" and DATA[k].rarity == rar and not out.has(str(k)))
		if not ids.is_empty():
			out.append(str(ids.pick_random()))
	return out
