# Items: passive relics bought in the shop between waves (one of each).
# Cores: big rule changers. Pick one at the start of the run and after every boss.
# icon = sprite path under Art.BASE (whole image is drawn, fitted to the slot).
const ITEMS := {
	leaf = {name = "Lucky Leaf", icon = "UI Elements/UI Elements/Icons/Icon_07.png", cost = 400,
		desc = "Hero symbols land 25% more often"},
	nugget = {name = "Gold Nugget", icon = "Terrain/Resources/Gold/Gold Stones/Gold Stone 2.png", cost = 600,
		desc = "Rare, epic and legendary symbols land more often"},
	hammer = {name = "Forge Hammer", icon = "Terrain/Resources/Tools/Tool_01.png", cost = 600,
		desc = "Hero lines summon 1 level higher"},
	purse = {name = "Coin Purse", icon = "UI Elements/UI Elements/Icons/Icon_03.png", cost = 300,
		desc = "After each wave: +20% interest on your gold (max 200)"},
	spyglass = {name = "Spyglass", icon = "UI Elements/UI Elements/Icons/Icon_06.png", cost = 500,
		desc = "Always PEEK at your next spin"},
	gear = {name = "Spare Gear", icon = "UI Elements/UI Elements/Icons/Icon_10.png", cost = 500,
		desc = "+1 free spin every prepare phase"},
	whetstone = {name = "Whetstone", icon = "Terrain/Resources/Tools/Tool_03.png", cost = 400,
		desc = "Squad damage +20%"},
	meat = {name = "Hearty Meat", icon = "UI Elements/UI Elements/Icons/Icon_04.png", cost = 300,
		desc = "Heal 70% between waves (instead of 30%)"},
	crook = {name = "Shepherd's Crook", icon = "Terrain/Resources/Meat/Sheep/Sheep_Idle.png", cost = 400,
		desc = "+2 Lambs on your reels. Lambs grow 1 landing sooner"},
	axe = {name = "Woodcutter Axe", icon = "Terrain/Resources/Tools/Tool_02.png", cost = 300,
		desc = "+60 gold on spins without a line"},
	dice = {name = "Loaded Dice", icon = "UI Elements/UI Elements/Icons/Icon_09.png", cost = 400,
		desc = "+1 NUDGE every prepare phase"},
	chain = {name = "Iron Chain", icon = "Terrain/Resources/Tools/Tool_01.png", cost = 400,
		desc = "+1 HOLD every prepare phase"},
	pickaxe = {name = "Pickaxe", icon = "Terrain/Resources/Tools/Tool_04.png", cost = 400,
		desc = "Sevens pay double gold"},
}

const CORES := {
	crossroads = {name = "Crossroads Core", icon = "Buildings/Blue Buildings/Tower.png",
		desc = "Diagonal lines summon 1 level higher"},
	heart = {name = "Heart Core", icon = "Buildings/Blue Buildings/Castle.png",
		desc = "The center cell pays x3"},
	chaos = {name = "Chaos Core", icon = "Buildings/Red Buildings/Tower.png",
		desc = "Heroes that land off a line give +15 gold each"},
	barracks = {name = "Barracks Core", icon = "Buildings/Blue Buildings/Barracks.png",
		desc = "Hero lines summon 2 units"},
	sanctum = {name = "Sanctum Core", icon = "Buildings/Blue Buildings/Monastery.png",
		desc = "Every spin heals the squad 10%"},
	jackpot = {name = "Jackpot Core", icon = "Buildings/Yellow Buildings/Castle.png",
		desc = "Three in a line pays double"},
	archery = {name = "Archery Core", icon = "Buildings/Blue Buildings/Archery.png",
		desc = "Ranged units deal +30% damage"},
}


static func info(id: String) -> Dictionary:
	return ITEMS[id] if ITEMS.has(id) else CORES[id]


# n random ids from table that are not in owned.
static func offers(table: Dictionary, owned: Array, n: int) -> Array:
	var ids: Array = table.keys().filter(func(k): return not owned.has(k))
	ids.shuffle()
	return ids.slice(0, n)
