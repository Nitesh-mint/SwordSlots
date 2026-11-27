extends SceneTree
# Run: godot --headless --path . --script scripts/symbols_check.gd

const Symbols := preload("res://scripts/symbols.gd")
const Items := preload("res://scripts/items.gd")
const Fate := preload("res://scripts/fate.gd")


# Fills the rest of the grid with a non-matching mix so only the cells given can line up.
func _grid(cells: Dictionary) -> Array:
	var g := ["mage", "healer", "bomber", "knight", "assassin", "champion", "spearman", "lamb", "magnet"]
	for c in cells:
		g[c] = cells[c]
	return g


func _initialize() -> void:
	# A pair does nothing; three of a kind in any of the 8 lines summons a Lv1 hero.
	var res := Symbols.resolve(_grid({0: "ranger", 1: "ranger"}))
	assert(res.summons.is_empty() and res.lines.is_empty())
	res = Symbols.resolve(_grid({0: "ranger", 1: "ranger", 2: "ranger"}))
	assert(res.summons == [["ranger", 1]] and res.lines == [0])
	res = Symbols.resolve(_grid({2: "ranger", 5: "ranger", 8: "ranger"}))
	assert(res.summons == [["ranger", 1]] and res.lines == [5], "columns count")
	res = Symbols.resolve(_grid({6: "ranger", 4: "ranger", 2: "ranger"}))
	assert(res.lines == [7], "diagonals count")
	# Might next to a line cell: +1 level.
	res = Symbols.resolve(_grid({0: "ranger", 1: "ranger", 2: "ranger", 3: "might"}))
	assert(res.summons == [["ranger", 2]])
	# 3 lines in one spin = JACKPOT, every summon +1 level.
	res = Symbols.resolve(_grid({0: "warrior", 1: "warrior", 2: "warrior", 3: "warrior", 4: "warrior", 5: "warrior"}))
	assert(res.lines.size() == 2 and not res.jackpot)
	res = Symbols.resolve(_grid({0: "warrior", 1: "warrior", 2: "warrior", 3: "warrior", 4: "warrior", 5: "warrior", 6: "warrior"}))
	assert(res.jackpot and res.summons.all(func(sm): return sm[1] == 2), str(res.summons))

	# Powers pay per cell; Haste doubles neighbours; three powers in a line pay again; 7-7-7 = +5 spins.
	res = Symbols.resolve(_grid({0: "might", 2: "might"}))
	assert(res.buffs.might == 10.0)
	res = Symbols.resolve(_grid({0: "might", 1: "haste"}))
	assert(res.buffs.might == 10.0 and res.buffs.haste == 4.0)
	res = Symbols.resolve(_grid({0: "seven", 1: "seven", 2: "seven"}))
	assert(res.buffs.spins == 5 and res.buffs.gold >= 240 and res.lines == [0])

	# Items and cores.
	res = Symbols.resolve(_grid({0: "ranger", 1: "ranger", 2: "ranger"}), {ranks = {ranger = 1}, items = ["hammer"]})
	assert(res.summons == [["ranger", 3]])
	res = Symbols.resolve(_grid({0: "ranger", 1: "ranger", 2: "ranger"}), {cores = ["barracks"]})
	assert(res.summons == [["ranger", 1], ["ranger", 1]])
	res = Symbols.resolve(_grid({}), {items = ["axe"]})
	assert(res.lines.is_empty() and res.buffs.gold >= 60)
	res = Symbols.resolve(_grid({4: "might"}), {cores = ["heart"]})
	assert(res.buffs.might == 15.0)

	# Class promotions: every hero has 2 classes; stats only scale what the hero has.
	for id in Symbols.DATA:
		if Symbols.DATA[id].type == "unit":
			assert(Symbols.CLASSES[id].size() == 2, id)
	var g := Symbols.class_stats("swordsman", 0)
	assert(g.hp == 140.0 and g.cls == "guardian" and not g.has("blast"))
	assert(Symbols.class_stats("healer", 1).attack == "heal_all")

	# Categories summon one of their own heroes; heroes never show up as reel picks.
	for i in 50:
		assert(Symbols.DATA.ranger.heroes.has(Symbols.pick_hero("ranger")))
		assert(Symbols.pick_hero("warrior", ["knight"]) == "knight")
		assert(Symbols.draft_offers(3).all(func(id): return Symbols.DATA[id].type != "unit"))
	for h in Symbols.all_heroes():  # every hero belongs to exactly one category
		assert(Symbols.DATA.keys().filter(func(k): return Symbols.DATA[k].type == "category" and Symbols.DATA[k].heroes.has(h)).size() == 1, h)
	for i in 30:
		assert(Symbols.draft_offers(3, true).all(func(id): return Symbols.DATA[id].rarity != "common"))
	for i in 50:  # no empty cells: every roll is from the pool
		var r := Symbols.roll(Symbols.STARTER, {items = ["leaf", "nugget"]})
		assert(r.size() == 9 and r.all(func(id): return Symbols.STARTER.has(id)))
	assert(Symbols.neighbours(4).size() == 8 and Symbols.neighbours(0) == [1, 3, 4])
	assert(Items.offers(Items.ITEMS, ["leaf"], 3).size() == 3 and not Items.offers(Items.ITEMS, ["leaf"], 20).has("leaf"))

	# Fate trials: streak resets when the rule breaks; Fate makes rarer heroes likelier.
	var t := Fate.new_trial("C")
	t.merge({need = 2, spins = 2}, true)
	var good := {spins = 1, deaths = 0, gold = 0, squad = 3, syn = 1, hp = 1.0, promoted = 0}
	assert(not Fate.advance(t, good) and t.progress == 1 and t.left == Fate.WAVES - 1)
	assert(not Fate.advance(t, {spins = 5, deaths = 0, gold = 0, squad = 3, syn = 1, hp = 1.0, promoted = 0}) and t.progress == 0)
	Fate.advance(t, good)
	assert(Fate.advance(t, good))
	assert(Symbols.fate_mult("common", 5) == 1.0 and Symbols.fate_mult("legendary", 2) > Symbols.fate_mult("rare", 2))
	assert(Symbols.category_of("knight") == "warrior")
	# Jesters are wild for categories only; three Jesters summon a random category.
	res = Symbols.resolve(_grid({0: "warrior", 1: "jester", 2: "warrior"}))
	assert(res.summons.size() == 1 and res.summons[0][0] == "warrior")
	res = Symbols.resolve(_grid({0: "might", 1: "jester", 2: "might"}))
	assert(res.lines.is_empty())
	res = Symbols.resolve(_grid({0: "jester", 1: "jester", 2: "jester"}))
	assert(res.summons.size() == 1 and Symbols.DATA[res.summons[0][0]].type == "category")
	assert(Symbols.synergy_level(1) == 0 and Symbols.synergy_level(2) == 1 and Symbols.synergy_level(5) == 2)

	# Every hero has a skill and gives an imprint; two equal commons still make Lv2, rarer need more.
	for h in Symbols.all_heroes():
		assert(Symbols.SKILLS.has(h) and Symbols.IMPRINTS.has(Symbols.HERO_IMPRINT[h]), h)
	assert(Symbols.level_power(1) == 1.0 and Symbols.level_power(Symbols.SUMMON_LEVEL[3]) > 3.5)
	assert(Symbols.level_power(Symbols.MAX_LEVEL) > 60.0)
	assert(Symbols.xp_need("knight", 3) > Symbols.xp_need("archer", 3))

	# How often a spin summons with the starting reels (should be a real chance, not a lottery).
	var hits := 0
	for i in 2000:
		if not Symbols.resolve(Symbols.roll(Symbols.STARTER)).summons.is_empty():
			hits += 1
	print("symbols_check ok: starter reels summon on %d%% of spins" % (hits / 20))
	quit()
