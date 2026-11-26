extends SceneTree
# Run: godot --headless --path . --script scripts/symbols_check.gd

const Symbols := preload("res://scripts/symbols.gd")
const Items := preload("res://scripts/items.gd")


func _grid(top: Array, mid := ["blank", "blank", "blank"], bot := ["blank", "blank", "blank"]) -> Array:
	return top + mid + bot


func _initialize() -> void:
	# Characters only summon from paylines: a pair = Lv1, three = Lv3 jackpot.
	var res := Symbols.resolve(_grid(["swordsman", "blank", "archer"]))
	assert(res.summons.is_empty())
	res = Symbols.resolve(_grid(["swordsman", "blank", "swordsman"]))
	assert(res.summons == [["swordsman", 1]] and not res.jackpot and res.lines == [0])
	res = Symbols.resolve(_grid(["mage", "mage", "mage"]))
	assert(res.summons == [["mage", 3]] and res.jackpot)
	# Diagonal 0-4-8 pair, with Might next to cell 0 -> Lv2.
	res = Symbols.resolve(_grid(["archer", "might", "blank"], ["blank", "archer", "blank"]))
	assert(res.summons == [["archer", 2]] and res.lines == [3], str(res.summons))

	# Powers pay per cell; Haste next to a power doubles it.
	res = Symbols.resolve(_grid(["might", "blank", "might"]))
	assert(res.buffs.might == 20.0)
	res = Symbols.resolve(_grid(["might", "haste", "blank"]))
	assert(res.buffs.might == 20.0 and res.buffs.haste == 8.0)
	# Three powers in a line pay again; 7-7-7 = +5 spins.
	res = Symbols.resolve(_grid(["seven", "seven", "seven"]))
	assert(res.buffs.gold == 240 and res.buffs.spins == 5 and res.jackpot)

	# Curses: skull destroys neighbours, knight blocks.
	res = Symbols.resolve(_grid(["trap", "skull", "thief"]))
	assert(res.destroyed == ["trap", "thief"] and res.buffs.trap == 0.0 and res.buffs.thief == 0.0)
	res = Symbols.resolve(_grid(["ambush", "blank", "blank"], ["knight", "blank", "blank"]))
	assert(res.buffs.ambush == 0 and res.summons.is_empty())
	res = Symbols.resolve(_grid(["trap", "blank", "blank"]))
	assert(is_equal_approx(res.buffs.trap, 0.08))

	# Growth ranks, items and cores.
	res = Symbols.resolve(_grid(["archer", "archer", "blank"]), {ranks = {archer = 1}, items = ["hammer"]})
	assert(res.summons == [["archer", 3]])
	res = Symbols.resolve(_grid(["trap", "blank", "blank"]), {ranks = {trap = 1}, items = ["ward"]})
	assert(is_equal_approx(res.buffs.trap, 0.06))
	res = Symbols.resolve(_grid(["blank", "blank", "blank"], ["blank", "might", "blank"]), {cores = ["heart"], items = ["axe"]})
	assert(res.buffs.might == 30.0 and res.buffs.gold == 160)
	res = Symbols.resolve(_grid(["swordsman", "swordsman", "blank"]), {cores = ["barracks"]})
	assert(res.summons == [["swordsman", 1], ["swordsman", 1]])

	for i in 30:
		assert(not Symbols.draft_offers(3).any(Symbols.is_curse))
		assert(Symbols.draft_offers(3, true).all(func(id): return Symbols.DATA[id].rarity != "common"))
	assert(Symbols.bag(Symbols.STARTER).size() == Symbols.BAG_MIN)
	for i in 50:
		var r := Symbols.roll(Symbols.STARTER, {items = ["leaf", "nugget"]})
		assert(r.size() == 9 and r.all(func(id): return Symbols.DATA.has(id) or Symbols.is_curse(id)))
	assert(Symbols.neighbours(4).size() == 8 and Symbols.neighbours(0) == [1, 3, 4])
	assert(Items.offers(Items.ITEMS, ["leaf"], 3).size() == 3 and not Items.offers(Items.ITEMS, ["leaf"], 20).has("leaf"))
	print("symbols_check ok: ", Symbols.summary(Symbols.resolve(_grid(["mage", "mage", "might"]))))
	quit()
