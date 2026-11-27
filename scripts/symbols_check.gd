extends SceneTree
# Run: godot --headless --path . --script scripts/symbols_check.gd

const Symbols := preload("res://scripts/symbols.gd")
const Items := preload("res://scripts/items.gd")


# Fills the rest of the grid with a non-matching mix so only the cells given can line up.
func _grid(cells: Dictionary) -> Array:
	var g := ["mage", "healer", "bomber", "knight", "assassin", "champion", "spearman", "lamb", "magnet"]
	for c in cells:
		g[c] = cells[c]
	return g


func _initialize() -> void:
	# A pair does nothing; three of a kind in any of the 8 lines summons a Lv1 hero.
	var res := Symbols.resolve(_grid({0: "archer", 1: "archer"}))
	assert(res.summons.is_empty() and res.lines.is_empty())
	res = Symbols.resolve(_grid({0: "archer", 1: "archer", 2: "archer"}))
	assert(res.summons == [["archer", 1]] and res.lines == [0])
	res = Symbols.resolve(_grid({2: "archer", 5: "archer", 8: "archer"}))
	assert(res.summons == [["archer", 1]] and res.lines == [5], "columns count")
	res = Symbols.resolve(_grid({6: "archer", 4: "archer", 2: "archer"}))
	assert(res.lines == [7], "diagonals count")
	# Might next to a line cell: +1 level.
	res = Symbols.resolve(_grid({0: "archer", 1: "archer", 2: "archer", 3: "might"}))
	assert(res.summons == [["archer", 2]])
	# 3 lines in one spin = JACKPOT, every summon +1 level.
	res = Symbols.resolve(_grid({0: "swordsman", 1: "swordsman", 2: "swordsman", 3: "swordsman", 4: "swordsman", 5: "swordsman"}))
	assert(res.lines.size() == 2 and not res.jackpot)
	res = Symbols.resolve(_grid({0: "swordsman", 1: "swordsman", 2: "swordsman", 3: "swordsman", 4: "swordsman", 5: "swordsman", 6: "swordsman"}))
	assert(res.jackpot and res.summons.all(func(sm): return sm[1] == 2), str(res.summons))

	# Powers pay per cell; Haste doubles neighbours; three powers in a line pay again; 7-7-7 = +5 spins.
	res = Symbols.resolve(_grid({0: "might", 2: "might"}))
	assert(res.buffs.might == 10.0)
	res = Symbols.resolve(_grid({0: "might", 1: "haste"}))
	assert(res.buffs.might == 10.0 and res.buffs.haste == 4.0)
	res = Symbols.resolve(_grid({0: "seven", 1: "seven", 2: "seven"}))
	assert(res.buffs.spins == 5 and res.buffs.gold >= 240 and res.lines == [0])

	# Items and cores.
	res = Symbols.resolve(_grid({0: "archer", 1: "archer", 2: "archer"}), {ranks = {archer = 1}, items = ["hammer"]})
	assert(res.summons == [["archer", 3]])
	res = Symbols.resolve(_grid({0: "archer", 1: "archer", 2: "archer"}), {cores = ["barracks"]})
	assert(res.summons == [["archer", 1], ["archer", 1]])
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

	for i in 30:
		assert(Symbols.draft_offers(3, true).all(func(id): return Symbols.DATA[id].rarity != "common"))
	for i in 50:  # no empty cells: every roll is from the pool
		var r := Symbols.roll(Symbols.STARTER, {items = ["leaf", "nugget"]})
		assert(r.size() == 9 and r.all(func(id): return Symbols.STARTER.has(id)))
	assert(Symbols.neighbours(4).size() == 8 and Symbols.neighbours(0) == [1, 3, 4])
	assert(Items.offers(Items.ITEMS, ["leaf"], 3).size() == 3 and not Items.offers(Items.ITEMS, ["leaf"], 20).has("leaf"))

	# How often a spin summons with the starting reels (should be a real chance, not a lottery).
	var hits := 0
	for i in 2000:
		if not Symbols.resolve(Symbols.roll(Symbols.STARTER)).summons.is_empty():
			hits += 1
	print("symbols_check ok: starter reels summon on %d%% of spins" % (hits / 20))
	quit()
