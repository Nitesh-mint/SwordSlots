# Meta-progression kept between runs: crystals earned at game over buy permanent upgrades.
# Saved to user://meta.cfg.
const SAVE_PATH := "user://meta.cfg"

# cost[k] = crystals for level k+1. Effects are read in run.gd via lvl(id).
const UPGRADES := [
	{id = "gold", name = "War Chest", desc = "+150 starting gold per level", cost = [15, 30, 50]},
	{id = "discount", name = "Greased Gears", desc = "Spins cost 10% less per level", cost = [25, 50]},
	{id = "veteran", name = "Veterans", desc = "Your starting heroes begin at Lv2", cost = [40]},
	{id = "heal", name = "Field Medics", desc = "+15% healing between waves per level", cost = [20, 40]},
	{id = "nudge", name = "Loose Reels", desc = "+1 NUDGE every prepare phase", cost = [45]},
	{id = "hold", name = "Iron Grip", desc = "+1 HOLD every prepare phase", cost = [45]},
	{id = "luck", name = "Lucky Star", desc = "Rarer heroes show up more in your picks", cost = [30, 60]},
	{id = "crystal", name = "Crystal Sense", desc = "+25% crystals from every run", cost = [50]},
]

const HARD_HP := 1.4        # hard mode: enemy HP x, damage x, crystals x
const HARD_DMG := 1.2
const HARD_CRYSTALS := 1.5

var crystals := 0
var levels := {}             # upgrade id -> level
var best := 0                # furthest wave reached
var wins := 0
var hard := false            # hard mode selected (unlocked after the first win)
var enabled := true          # false in headless sims so they never touch the save


func lvl(id: String) -> int:
	return levels.get(id, 0)


func info(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


# Next level's cost, or -1 when maxed.
func cost(id: String) -> int:
	var c: Array = info(id).cost
	return c[lvl(id)] if lvl(id) < c.size() else -1


func buy(id: String) -> bool:
	var c := cost(id)
	if c < 0 or crystals < c:
		return false
	crystals -= c
	levels[id] = lvl(id) + 1
	save()
	return true


# Crystals for a finished run: 3 per wave cleared, 10 per boss, 25 for winning.
func reward(cleared: int, won: bool) -> int:
	var n := cleared * 3 + int(cleared / 5.0) * 10 + (25 if won else 0)
	return int(n * (1.0 + 0.25 * lvl("crystal")) * (HARD_CRYSTALS if hard else 1.0))


func load_save() -> void:
	if not enabled:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	crystals = cfg.get_value("meta", "crystals", 0)
	levels = cfg.get_value("meta", "levels", {})
	best = cfg.get_value("meta", "best", 0)
	wins = cfg.get_value("meta", "wins", 0)
	hard = cfg.get_value("meta", "hard", false) and wins > 0


func save() -> void:
	if not enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "crystals", crystals)
	cfg.set_value("meta", "levels", levels)
	cfg.set_value("meta", "best", best)
	cfg.set_value("meta", "wins", wins)
	cfg.set_value("meta", "hard", hard)
	cfg.save(SAVE_PATH)
