extends Node2D
# Auto-battler + 3x3 slot machine. A run = 3 acts x 5 waves, a boss ends each act.
# Two phases: PREPARE (between waves) - spend gold to spin the machine (paylines summon the army,
# powers buff it), pick a symbol after each spin, buy Items, pick a Core (run start / after bosses),
# Then FIGHT: no spinning, just steer, dodge and merge; kills drop the gold for the
# next prepare phase. A JUDGEMENT wave is harder but pays double gold + a bonus.

const Symbols := preload("res://scripts/symbols.gd")
const Art := preload("res://scripts/art.gd")
const Items := preload("res://scripts/items.gd")
const Meta := preload("res://scripts/meta.gd")
const Fate := preload("res://scripts/fate.gd")

# Tuning
const LEVELS := 15
const BOSS_EVERY := 5         # waves per act; the last one is a boss
const START_GOLD := 1000
const SPIN_COST := 200         # first spin of each prepare phase...
const SPIN_COST_STEP := 50     # ...each further spin in the same phase costs this much more
const SPIN_CAP := 6            # max spins per prepare phase (FATE SPINs are extra)
const KILL_GOLD := 35          # per enemy killed (x1.5 on judgement waves)
const BOSS_GOLD := 400
const WAVE_GOLD := 350         # clearing a wave (+ WAVE_GOLD_STEP per wave number)
const WAVE_GOLD_STEP := 40
const SQUAD_CAP := 8
const MAX_TIER := Symbols.MAX_LEVEL   # max hero level = awakened
const WAVE_HEAL := 0.3
const JUDGE_HP := 1.5           # judgement wave: enemy HP x
const JUDGE_DMG := 1.25
const JUDGE_GOLD := 150         # bonus gold for clearing a judgement wave
const ITEM_COST_PER_ACT := 200 # shop prices rise each act
const HP_GROWTH := 1.74        # enemy HP x per wave
const DMG_GROWTH := 1.5       # enemy damage x per wave
const ENEMY_HP := 60.0
const ENEMY_DMG := 12.0
const ENEMY_SPEED := 95.0
const HERO_SPEED := 110.0
const DASH_SPEED := 650.0      # Skylancer leap / Warlord charge
const TAUNT_RANGE := 260.0
const HERO_SPACING := 100.0
const ENEMY_GAP := 330.0       # enemy front row stands this far up from ours
const DEPLOY_TIME := 1.3       # both sides march into formation before the fight starts
const OVERTIME_AFTER := 25.0   # then damage ramps up so no fight lasts forever
const BATTLE_SPEED := 1.6      # the whole fight runs this much faster than real time
const ENEMY_SHOT_SPEED := 520.0
const SHELL_TIME := 1.2        # warning time before a lobbed bomb / boss slam lands

# Enemy types. hp/dmg are multipliers on the wave's base values, speed on ENEMY_SPEED, reach in px.
# attack: melee | bolt (arrow) | shell (lobbed AoE bomb) | heal (heals the most hurt ally)
# ability: dive (goes for your BACK row) | cleave (hits every hero in reach)
const ENEMY_TYPES := {
	grunt = {name = "Grunt", from = 1, weight = 3.0, hp = 1.0, dmg = 1.0, r = 22.0, speed = 1.0, cd = 1.0,
		attack = "melee", reach = 44.0, desc = "Basic fighter"},
	runner = {name = "Raider", from = 2, weight = 1.6, hp = 0.6, dmg = 0.9, r = 18.0, speed = 1.9, cd = 0.7,
		attack = "melee", reach = 40.0, ability = "dive", desc = "Runs past your front to hit the BACK row"},
	shooter = {name = "Archer", from = 3, weight = 1.5, hp = 0.7, dmg = 0.9, r = 20.0, speed = 0.9, cd = 1.6,
		attack = "bolt", reach = 380.0, desc = "Shoots your FRONT row from range"},
	brute = {name = "Brute", from = 4, weight = 1.0, hp = 3.0, dmg = 1.6, r = 30.0, speed = 0.6, cd = 1.4,
		attack = "melee", reach = 60.0, ability = "cleave", desc = "Tank. Hits every hero in reach"},
	shaman = {name = "Shaman", from = 6, weight = 0.9, hp = 0.8, dmg = 1.0, r = 20.0, speed = 0.8, cd = 2.0,
		attack = "heal", reach = 0.0, desc = "Heals the most hurt enemy"},
	mortar = {name = "Bombardier", from = 8, weight = 0.9, hp = 0.9, dmg = 1.1, r = 22.0, speed = 0.8, cd = 3.0,
		attack = "shell", reach = 460.0, desc = "Lobs bombs that hit an area"},
}
# One boss closes each act; its ability fires every `every` seconds.
const BOSS_ORDER := ["warlord", "witch", "bloodknight"]
const BOSSES := {
	warlord = {name = "The Warlord", hp = 16.0, dmg = 2.4, r = 40.0, speed = 0.8, cd = 1.2, attack = "melee", reach = 64.0,
		ability = "charge", every = 6.0, scale = 1.7, tint = Color(1, 1, 1), desc = "Charges into your BACK row"},
	witch = {name = "The Witch", hp = 13.0, dmg = 1.8, r = 36.0, speed = 0.7, cd = 2.2, attack = "shell", reach = 480.0,
		ability = "summon", every = 7.0, scale = 1.8, tint = Color(0.85, 0.6, 1.2), desc = "Summons grunts, bombs from afar"},
	bloodknight = {name = "Blood Knight", hp = 18.0, dmg = 2.8, r = 42.0, speed = 0.7, cd = 1.3, attack = "melee", reach = 72.0,
		ability = "slam", every = 5.0, enrage = true, scale = 1.9, tint = Color(1.0, 0.55, 0.55), desc = "Slams an area, ENRAGES at half HP"},
}

# One look per act. Later waves in an act get darker (dusk), bosses pulse red, judgement goes purple.
# decor = [kind, weight] spawned on the banks / lane edges (see _spawn_decor).
const THEMES := [
	{name = "The Green Meadows", tile = "Terrain/Tileset/Tilemap_color1.png", tint = Color(1, 1, 1), water = Color(1, 1, 1),
		decor = [["tree", 0.45], ["bush", 0.35], ["water_rock", 0.2]], clouds = 0.08, vignette = Color(0, 0, 0, 0.0)},
	{name = "The Dusk Highlands", tile = "Terrain/Tileset/Tilemap_color2.png", tint = Color(1.15, 0.82, 0.5), water = Color(0.95, 0.65, 0.55),
		decor = [["tree", 0.2], ["rock", 0.25], ["gold", 0.15], ["house", 0.25], ["water_rock", 0.15]], clouds = 0.16,
		vignette = Color(0.35, 0.12, 0.0, 0.3)},
	{name = "The Burning Kingdom", tile = "Terrain/Tileset/Tilemap_color4.png", tint = Color(1.15, 0.6, 0.48), water = Color(0.55, 0.22, 0.25),
		decor = [["red_building", 0.3], ["fire", 0.35], ["rock", 0.2], ["water_rock", 0.15]], clouds = 0.24, embers = true,
		vignette = Color(0.4, 0.0, 0.0, 0.45)},
]

# Layout (720 wide; designed for 1280 tall. Taller phones stretch the lane, see _fit_screen)
const W := 720.0
const LANE_L := 40.0
const LANE_R := 680.0
var LANE_BOTTOM := 880.0
var SQUAD_Y := 760.0
const UNIT_R := 22.0
const PROJ_SPEED := 900.0
var REEL_POS := Vector2(24, 896)   # top-left of the 3x3 grid
const REEL_CELL := 104.0
const PAPER_TEXT := Color("3b2a1a")
const WAVE_RIBBON := Rect2(170, 8, 380, 64)
const BAR_RECT := Rect2(130, 78, 460, 34)
const MSG_RIBBON := Rect2(40, 150, 640, 84)
var REEL_WINDOW := Rect2(12, 884, 336, 336)
var LEVER_RECT := Rect2(352, 884, 84, 210)   # slot-machine lever: pull (or tap) to spin
var SPIN_RECT := Rect2(444, 896, 262, 84)     # price plate; also taps as SPIN / STOP / COLLECT
var TRICK_POS := Vector2(444, 990)   # NUDGE / HOLD charge pills
var ITEMS_POS := Vector2(444, 1042)   # owned items + cores icons
const DRAFT_RIBBON := Rect2(130, 150, 460, 72)
# Camp corner buttons (bottom of the lane): SHOP left, FIGHT right with JUDGEMENT above it.
var SHOP_BTN_RECT := Rect2(12, 800, 150, 68)
var FATE_BTN_RECT := Rect2(12, 726, 150, 64)
var NEXT_RECT := Rect2(548, 800, 160, 68)
var JUDGE_RECT := Rect2(548, 726, 160, 64)
# Shop panel (opened from the SHOP button)
const SHOP_PANEL := Rect2(40, 250, 640, 470)
const SHOP_RIBBON := Rect2(190, 222, 340, 70)
const SHOP_CLOSE_RECT := Rect2(250, 610, 220, 70)
const OVER_RECT := Rect2(100, 340, 520, 300)
const RESTART_RECT := Rect2(210, 660, 300, 96)
# Title screen + upgrade tree
const PLAY_RECT := Rect2(200, 560, 320, 110)
const UPG_RECT := Rect2(200, 690, 320, 84)
const HARD_RECT := Rect2(200, 794, 320, 70)
const STAGE_RECT := Rect2(160, 466, 400, 70)
const META_PANEL := Rect2(26, 150, 668, 880)
const META_RIBBON := Rect2(170, 122, 380, 72)
const META_CLOSE := Rect2(250, 940, 220, 70)
const GEAR_RECT := Rect2(12, 74, 48, 48)
const SETTINGS_RECT := Rect2(70, 330, 580, 450)
const SETTINGS_RIBBON := Rect2(170, 300, 380, 72)
const CLOSE_RECT := Rect2(250, 680, 220, 76)
const BUS_LABELS := {Master = "Master", Music = "Music", SFX = "Sound FX"}
const REEL_TIME := 0.8          # first reel spin time (s)
const REEL_STAGGER := 0.3       # each next reel spins this much longer
const REEL_STRIP := 14          # symbols scrolled by the first reel
const REEL_STRIP_STEP := 5      # extra symbols per later reel (keeps speeds similar)
const REEL_TEASE_TIME := 0.9    # extra time on the last reel when the first two match
const REEL_TEASE_EXTRA := 6
const REEL_BOUNCE := 0.18       # stop bounce duration
const REEL_GLOW := 1.4          # how long matching symbols glow after a spin
const REEL_SLAM_T := 0.93       # tapping SPIN mid-spin jumps reels to this progress
const PAY_STEP := 0.22         # seconds between payout events after a spin
const CAMP_CENTER := Vector2(360, 500)   # summoning circle in the camp (prepare phase)
const CAMP_SPACING := 96.0
const CAMP_SCALE := 1.2
const BORN_TIME := 1.1          # hero birth animation (light beam + pop)
const LEVEL_TIME := 1.0         # level-up animation
const TRANS_TIME := 0.8         # camp -> path transition when the fight starts
const WAVE_INTRO := 2.2         # path preview card (act, wave, enemies ahead)
# Formation: 2 rows x 4 slots. Slots 0-3 = FRONT (meets enemies first), 4-7 = BACK.
const FRONT_MELEE_DMG := 1.3    # melee heroes in front hit harder...
const FRONT_MELEE_ARMOR := 0.6  # ...and take less damage
const FRONT_RANGED_HURT := 1.8  # ranged heroes / healers in front are exposed
const BACK_RANGED_DMG := 1.3    # ranged heroes in back aim steadily
const BACK_MELEE_DMG := 0.25   # melee heroes in back can barely reach
const FRONT_RANGED_DMG := 0.7   # ranged heroes in front can't aim well in the crush
const NUDGES := 1               # reel tricks per prepare phase (items add more)
const HOLDS := 1
const NUDGE_ANIM := 0.18
const LEVER_ANIM := 0.55        # lever pull + spring back
const COIN_FLY := 0.6           # payout coin flying to the purse
const PENTA := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]  # bell steps (semitones) for rising payouts
const ATTACK_ANIM := 0.4     # seconds an attack/shoot/cast animation plays

var state := "title"  # title | draft (camp) | wave | over
var meta = Meta.new()
var meta_open := false
var play_btn: Button
var upg_btn: Button
var hard_btn: Button
var stage_btn: Button
var meta_close: Button
var meta_btns: Array = []
var earned := 0
var level := 1
var gold := START_GOLD
var spins := 0               # free spins (Skull, 7-7-7, Spare Gear); used before gold
var spin_cost := SPIN_COST
var pool: Array = []
var power := {}
var squad: Array = []    # {type, tier, hp, t}
var reels: Array = []    # 9 cells, row-major: result shown when reels are still
var reel_spinning := false
var reel_strips: Array = [[], [], []]   # symbols scrolling past during a spin
var reel_t: Array = [1.0, 1.0, 1.0]     # 0..1 progress of each reel
var reel_dur: Array = [1.0, 1.0, 1.0]
var reel_bounce: Array = [0.0, 0.0, 0.0]
var reel_glow := 0.0
var reel_tease := false
var hit_cells: Array = []     # cells on winning lines (glow)
var items: Array = []         # owned Items ids
var cores: Array = []         # owned Cores ids
var shop: Array = []          # item ids for sale this camp ("" = sold)
var offer_kind := "symbol"    # camp offers: symbol | core
var picked := false           # camp offer taken
var started := false          # first wave begun
var judgement := false        # current wave is a judgement wave
var offers: Array = []
var spin_offers: Array = []   # pick 1 of 3 after every spin; the next spin skips them
var payout: Array = []        # per-reel events still to pay out (Symbols.resolve events)
var payout_t := 0.0
var payout_step := 0
var payout_res := {}
var popups: Array = []        # {pos, text, color, t} floating payout numbers
var links: Array = []         # {a, b, t} combo link drawn between two reels
var lands := {}               # symbol id -> times landed (drives growth / lamb hatching)
var ranks := {}               # symbol id -> rank (Symbols.GROW_EVERY landings per rank)
var unlocked := []            # heroes categories can summon (empty = all); tasks will unlock them
var fate_spins: Array = []    # grades of earned FATE SPINs (used by the next spins)
var spin_grade := ""          # grade of the FATE SPIN in progress ("" = normal spin)
var wave_flags := {}          # once-per-prepare item triggers already used (tooth, anvil, contract)
var trials: Array = []        # Fate trials on offer, one per grade (Fate.new_trial)
var camp_spins := 0           # spins this prepare phase (for Fate trial rules)
var wave_rec := {}            # this wave for Fate trials: {spins, deaths, gold, squad, cats}
var nudges := 0                # NUDGE: after a spin lands, push one reel down a cell
var holds := 0                 # HOLD: freeze a reel so the next spin keeps it
var held: Array = [false, false, false]
var awaiting := false          # reels landed, waiting for a nudge or COLLECT before paying
var nudge_off: Array = [0.0, 0.0, 0.0]
var next_roll: Array = []      # PEEK: after a spin with no line, the next spin is rolled early and shown
var lever_t := 1.0             # 0..1 progress of the pull animation (1 = at rest)
var lever_drag := -1.0         # finger y when the lever was grabbed (-1 = not held)
var lever_pull := 0.0          # how far the finger dragged it down (0..1)
var lever_from := 0.0
var fly_coins: Array = []      # {from, to, t, delay}
var gold_shown := 0.0          # purse counts up as coins land
var purse_bump := 0.0
var win_banner := {}           # {text, sub, tier, t, t0}
var win_flash := 0.0           # marquee bulbs all flash
var cell_flash: Array = []     # {c, t, color} winning cell pops
var promote_unit = null        # hero whose panel is open (see panel_mode)
var panel_mode := ""           # promote (pick a class) | info (skill, imprints) | absorb (absorb_from into promote_unit, or swap)
var absorb_from = null
var promo_btns: Array = []
var promo_close: Button
var shake := 0.0              # screen shake strength, decays to 0

var distance := 0.0            # the battlefield doesn't scroll; kept 0 for the ground/cloud drawing
var battle_t := 0.0
var victory_t := 0.0
var wave_hp := 0.0             # total enemy HP this wave (progress bar)
var next_id := 0
var enemies: Array = []      # {id, kind, pos, hp, r, dmg, t}  kind: enemy|boss|chest
var projectiles: Array = []  # {pos, vel, dmg, pierce, blast, crit, color, hit}
var enemy_shots: Array = []  # {pos, vel, dmg}
var shells: Array = []       # {pos, t, dmg, r}
var rng := RandomNumberGenerator.new()
var effects: Array = []      # {pos, r, t, color, boom?, t0?}
var decor: Array = []        # {path, pos, scale, top}  scrolling scenery
var decor_at := 0.0
var fade := 0.0                # black fade-in when returning to the camp
var wave_intro := 0.0          # path preview time left
var trans := 0.0               # camp -> path transition time left
var sparks: Array = []         # {pos, vel, t, t0, color} birth / level-up particles
var anim_time := 0.0

var drag_idx := -1             # unit being dragged in the camp (merge onto a twin)
var drag_pos := Vector2.ZERO

var screen_h := 1280.0
var draft_info: Label
var font := ThemeDB.fallback_font
var sfx: Node
var settings_open := false
var settings_ui: Array = []    # controls shown only while the settings panel is open
var settings_toggles := {}     # bus -> ON/OFF Button
var gear_btn: TextureButton
var settings_close: Button
var ui: Control
var wave_label: Label
var gold_label: Label
var squad_label: Label
var power_label: Label
var msg_label: Label
var msg_timer := 0.0
var spin_btn: Button
var draft_title: Label
var draft_btns: Array = []
var next_btn: Button
var judge_btn: Button
var shop_btns: Array = []
var shop_btn: Button          # opens the shop panel
var shop_close: Button
var shop_open := false
var shop_tab := "shop"        # shop | fate: which page the panel shows
var fate_btn: Button
var over_label: Label
var restart_btn: Button


func _ready() -> void:
	_fit_screen()
	pool.assign(Symbols.STARTER)
	sfx = preload("res://scripts/sfx.gd").new()
	add_child(sfx)
	power = Symbols.empty_buffs()
	# Controls only carry text and clicks; their wood/paper/button art is drawn in _draw_ui().
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = _make_theme()
	layer.add_child(ui)

	wave_label = _label(WAVE_RIBBON.position, WAVE_RIBBON.size, 30)
	gold_label = _label(Vector2(64, 18), Vector2(110, 44), 28)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	squad_label = _label(Vector2(546, 18), Vector2(110, 44), 28)
	squad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_label = _label(Vector2(20, 116), Vector2(680, 30), 20)
	msg_label = _label(MSG_RIBBON.position + Vector2(90, 0), MSG_RIBBON.size - Vector2(180, 0), 24)

	spin_btn = _button(SPIN_RECT.position, SPIN_RECT.size, 30, _pull_lever)

	draft_title = _label(DRAFT_RIBBON.position, DRAFT_RIBBON.size, 32)
	draft_title.text = "Wave reward: rare+"
	for i in 3:
		var card := _card_rect(i)
		var b := _button(card.position, card.size, 15, _pick.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_color_override("font_color", PAPER_TEXT)
		b.add_theme_color_override("font_hover_color", Color("6a3a10"))
		b.add_theme_color_override("font_pressed_color", Color("6a3a10"))
		b.add_theme_constant_override("outline_size", 0)
		var pad := StyleBoxEmpty.new()
		pad.content_margin_left = 70
		pad.content_margin_right = 8
		pad.content_margin_top = 26
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, pad)
		draft_btns.append(b)
	for i in 3:
		var b := _button(_shop_rect(i).position, _shop_rect(i).size, 15, _buy_item.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_color_override("font_color", PAPER_TEXT)
		b.add_theme_color_override("font_hover_color", Color("6a3a10"))
		b.add_theme_color_override("font_disabled_color", Color(0.45, 0.38, 0.3))
		b.add_theme_constant_override("outline_size", 0)
		var pad := StyleBoxEmpty.new()
		pad.content_margin_left = 62
		pad.content_margin_right = 6
		pad.content_margin_top = 32
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(st, pad)
		shop_btns.append(b)
	next_btn = _button(NEXT_RECT.position, NEXT_RECT.size, 26, _next.bind(false))
	judge_btn = _button(JUDGE_RECT.position, JUDGE_RECT.size, 15, _next.bind(true))
	judge_btn.text = "JUDGEMENT\nhard, more gold"
	shop_btn = _button(SHOP_BTN_RECT.position + Vector2(34, 0), SHOP_BTN_RECT.size - Vector2(34, 0), 24, _toggle_shop)
	shop_btn.text = "SHOP"
	fate_btn = _button(FATE_BTN_RECT.position + Vector2(34, 0), FATE_BTN_RECT.size - Vector2(34, 0), 22, _toggle_shop.bind("fate"))
	fate_btn.text = "FATE"
	shop_close = _button(SHOP_CLOSE_RECT.position, SHOP_CLOSE_RECT.size, 28, _toggle_shop)
	shop_close.text = "Close"
	for k in 2:
		promo_btns.append(_button(_promo_rect(k).position, _promo_rect(k).size, 16, _on_promote.bind(k)))
	promo_close = _button(SHOP_CLOSE_RECT.position, SHOP_CLOSE_RECT.size, 28, func(): promote_unit = null)
	draft_info = _label(Vector2(0, 224), Vector2(W, 36), 20)

	over_label = _label(OVER_RECT.position + Vector2(40, 30), OVER_RECT.size - Vector2(80, 70), 40)
	over_label.add_theme_color_override("font_color", PAPER_TEXT)
	over_label.add_theme_constant_override("outline_size", 0)
	over_label.add_theme_font_size_override("font_size", 32)
	restart_btn = _button(RESTART_RECT.position, RESTART_RECT.size, 36, get_tree().reload_current_scene)
	restart_btn.text = "Continue"
	play_btn = _button(PLAY_RECT.position, PLAY_RECT.size, 48, _start_run)
	play_btn.text = "PLAY"
	upg_btn = _button(UPG_RECT.position, UPG_RECT.size, 30, _set_meta_open.bind(true))
	upg_btn.text = "UPGRADES"
	hard_btn = _button(HARD_RECT.position, HARD_RECT.size, 22, _toggle_hard)
	stage_btn = _button(STAGE_RECT.position, STAGE_RECT.size, 22, _next_stage)
	for k in Meta.UPGRADES.size():
		var id: String = Meta.UPGRADES[k].id
		meta_btns.append(_button(_meta_row(k).position + Vector2(_meta_row(k).size.x - 150, 12), Vector2(140, 54), 22, _buy_upgrade.bind(id)))
	meta_close = _button(META_CLOSE.position, META_CLOSE.size, 28, _set_meta_open.bind(false))
	meta_close.text = "Close"
	_build_settings()

	meta.load_save()
	rng.randomize()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for i in 12:  # fill the screen with scenery before the first frame
		_scroll_decor(LANE_BOTTOM / 12.0)
	reels.resize(Symbols.CELLS)
	reels.fill("blank")


# PLAY on the title screen: permanent upgrades apply, starting squad arrives, first Core pick.
func _start_run() -> void:
	if state != "title":
		return
	meta_open = false
	gold = START_GOLD + 150 * meta.lvl("gold")
	gold_shown = 0.0
	_open_camp(true)
	unlocked = Symbols.all_heroes().filter(func(h): return meta.rarity_unlocked(Symbols.DATA[h].rarity))
	var tier: int = Symbols.SUMMON_LEVEL[2 if meta.lvl("veteran") > 0 else 1]
	_summon("swordsman", tier)
	_summon("swordsman", tier)
	_summon("archer", tier)
	trials = Fate.GRADES.map(func(g): return Fate.new_trial(g))


func _buy_upgrade(id: String) -> void:
	if meta.buy(id):
		sfx.play("levelup")
		_burst(Vector2(W / 2, 300), Color("c05cff"), 20)
	else:
		sfx.play("error")


func _set_meta_open(on: bool) -> void:
	meta_open = on
	sfx.play("draft" if on else "pick")


# Title: cycle through the stages beaten so far (+ the next one).
func _next_stage() -> void:
	meta.stage = (meta.stage + 1) % (mini(meta.cleared, Meta.STAGES.size() - 1) + 1)
	meta.save()
	sfx.play("pick")


func _toggle_hard() -> void:
	meta.hard = not meta.hard
	meta.save()
	sfx.play("pick")


func _meta_row(k: int) -> Rect2:
	return Rect2(META_PANEL.position.x + 24, META_PANEL.position.y + 84 + k * 84, META_PANEL.size.x - 48, 78)


func _discount() -> float:
	return 1.0 - 0.1 * meta.lvl("discount")


# Taller screens (e.g. 20:9 phones): lengthen the lane and keep the bottom panel on the bottom edge.
func _fit_screen() -> void:
	screen_h = maxf(1280.0, get_viewport_rect().size.y)
	var dy := screen_h - 1280.0
	LANE_BOTTOM += dy
	SQUAD_Y += dy
	REEL_POS.y += dy
	REEL_WINDOW.position.y += dy
	SPIN_RECT.position.y += dy
	ITEMS_POS.y += dy
	TRICK_POS.y += dy
	LEVER_RECT.position.y += dy
	SHOP_BTN_RECT.position.y += dy
	FATE_BTN_RECT.position.y += dy
	NEXT_RECT.position.y += dy
	JUDGE_RECT.position.y += dy


func _make_theme() -> Theme:
	var th := Theme.new()
	var ink := Color("2a1d14")
	for type in ["Label", "Button"]:
		th.set_color("font_color", type, Color.WHITE)
		th.set_color("font_outline_color", type, ink)
		th.set_constant("outline_size", type, 10)
	th.set_color("font_hover_color", "Button", Color("fff2b0"))
	th.set_color("font_pressed_color", "Button", Color("fff2b0"))
	th.set_color("font_disabled_color", "Button", Color(0.8, 0.8, 0.8))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		th.set_stylebox(st, "Button", empty)
	return th


# Gear button + volume panel (Master / Music / Sound FX sliders with ON/OFF). Values live in sfx.gd.
func _build_settings() -> void:
	gear_btn = TextureButton.new()
	gear_btn.texture_normal = Art.tex(Art.ICON_GEAR)
	gear_btn.ignore_texture_size = true
	gear_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	gear_btn.position = GEAR_RECT.position
	gear_btn.size = GEAR_RECT.size
	gear_btn.pressed.connect(_toggle_settings)
	ui.add_child(gear_btn)

	var blocker := Control.new()  # swallows clicks meant for things under the panel
	blocker.position = Vector2.ZERO
	blocker.size = Vector2(W, screen_h)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(blocker)
	settings_ui.append(blocker)

	var title := _label(SETTINGS_RIBBON.position, SETTINGS_RIBBON.size, 32)
	title.text = "SETTINGS"
	settings_ui.append(title)

	var track := StyleBoxFlat.new()
	track.bg_color = Color("6b4a2b")
	track.set_corner_radius_all(6)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = Color("e0b040")
	var knob_img := Art.tex(Art.ICON_COIN).get_image()
	knob_img.resize(40, 40, Image.INTERPOLATE_NEAREST)
	var knob := ImageTexture.create_from_image(knob_img)

	for i in sfx.BUSES.size():
		var bus: String = sfx.BUSES[i]
		var y: float = SETTINGS_RECT.position.y + 80 + i * 85
		var l := _label(Vector2(105, y), Vector2(150, 56), 26)
		l.text = BUS_LABELS[bus]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.add_theme_color_override("font_color", PAPER_TEXT)
		l.add_theme_constant_override("outline_size", 0)
		settings_ui.append(l)

		var s := HSlider.new()
		s.position = Vector2(255, y + 4)
		s.size = Vector2(230, 48)
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = sfx.volume[bus]
		s.add_theme_stylebox_override("slider", track)
		s.add_theme_stylebox_override("grabber_area", fill)
		s.add_theme_stylebox_override("grabber_area_highlight", fill)
		s.add_theme_icon_override("grabber", knob)
		s.add_theme_icon_override("grabber_highlight", knob)
		s.value_changed.connect(func(v: float): sfx.set_volume(bus, v))
		ui.add_child(s)
		settings_ui.append(s)

		var t := _button(Vector2(505, y + 2), Vector2(110, 52), 24, func(): pass)
		t.toggle_mode = true
		t.toggled.connect(func(on: bool): sfx.set_enabled(bus, on))
		settings_ui.append(t)
		settings_toggles[bus] = t

	settings_close = _button(CLOSE_RECT.position, CLOSE_RECT.size, 32, _toggle_settings)
	settings_close.text = "Close"
	settings_ui.append(settings_close)


func _toggle_settings() -> void:
	settings_open = not settings_open
	drag_idx = -1
	sfx.play("draft" if settings_open else "pick")


func _label(pos: Vector2, size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	ui.add_child(l)
	return l


func _button(pos: Vector2, size: Vector2, font_size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	ui.add_child(b)
	return b


func _flash(text: String) -> void:
	msg_label.text = text
	msg_timer = 2.5


# ---------------------------------------------------------------- reels

# Each reel scrolls a strip of random symbols that ends on the pre-rolled result. Reels stop
# left to right with a bounce; if the first two match, the last reel slows down (anticipation).
# Pressing SPIN again while spinning slams the reels to a quick stop.
func _on_spin() -> void:
	if reel_spinning:
		for i in 3:
			reel_t[i] = maxf(reel_t[i], REEL_SLAM_T)
		return
	if awaiting:  # SPIN reads COLLECT while nudges are on offer
		_collect()
		return
	while not payout.is_empty():  # tapping again finishes the payout at once
		_pay_next()
	if not _can_spin():
		return
	spin_grade = ""
	if not fate_spins.is_empty():  # FATE SPIN: free, extra, always a hero line
		spin_grade = fate_spins.pop_front()
		popups.append({pos = REEL_WINDOW.get_center() + Vector2(0, -60), text = "FATE SPIN!", color = Fate.COLOR[spin_grade], t = 1.4})
		sfx.play("levelup")
	else:
		camp_spins += 1
		if spins > 0:
			spins -= 1
		else:
			gold -= spin_cost
			spin_cost += int((SPIN_COST_STEP if started else 20) * _discount())  # always rises, so gold symbols can't loop forever
	spin_offers.clear()  # not picking = skip
	reel_spinning = true
	reel_glow = 0.0
	var result: Array = next_roll if not next_roll.is_empty() else Symbols.roll(pool, _ctx())
	next_roll = []
	for i in 3:  # held reels keep their column
		if held[i]:
			for r in 3:
				result[r * 3 + i] = reels[r * 3 + i]
	if spin_grade != "":
		var cats := pool.filter(func(id): return Symbols.DATA[id].type == "category")
		var cat: String = cats.pick_random() if not cats.is_empty() else "warrior"
		for c in Symbols.LINES.pick_random():
			result[c] = cat
	elif items.has("note") and camp_spins == 1:
		result[Symbols.CENTER] = "jester"
	var bag: Array = pool
	# Tease: a payline already matches on its first two columns -> the last column slows down.
	reel_tease = false
	for line in Symbols.LINES:
		var by_col := {}
		for c in line:
			by_col[c % 3] = result[c]
		if by_col.get(0) == by_col.get(1) and by_col.get(0) != "blank" and by_col.size() == 3:
			reel_tease = true
	var tease := reel_tease
	for i in 3:  # column i: strip holds old column (bottom first), random symbols, new column
		if held[i]:
			reel_strips[i] = []
			reel_t[i] = 1.0
			continue
		var n: int = REEL_STRIP + i * REEL_STRIP_STEP + (REEL_TEASE_EXTRA if tease and i == 2 else 0)
		var strip: Array = [reels[6 + i], reels[3 + i], reels[i]]
		for k in n:
			strip.append(bag.pick_random())
		strip += [result[6 + i], result[3 + i], result[i]]
		reel_strips[i] = strip
		reel_t[i] = 0.0
		reel_dur[i] = REEL_TIME + i * REEL_STAGGER + (REEL_TEASE_TIME if tease and i == 2 else 0.0)
		reel_bounce[i] = 0.0
	reels = result
	held = [false, false, false]
	sfx.play("spin")


# Lever / plate: STOP while spinning, COLLECT while nudges are offered, else pull and spin.
func _pull_lever() -> void:
	if reel_spinning or awaiting:
		_on_spin()
		return
	if not _can_spin():
		if state == "draft":
			sfx.play("error")
		return
	lever_from = lever_pull
	lever_t = 0.0
	sfx.play("click")
	_on_spin()


# Lever knob travel 0..1 (1 = pulled all the way down).
func _lever_amount() -> float:
	if lever_drag >= 0:
		return lever_pull
	if lever_t >= 1.0:
		return 0.0
	var k := lever_t * LEVER_ANIM
	if k < 0.12:  # snap down
		return lerpf(lever_from, 1.0, k / 0.12)
	k -= 0.12
	return clampf(cos(k * 22.0) * exp(-k * 9.0), -0.25, 1.0)  # spring back with a wobble


# Spinning only happens while preparing, after any Core pick, with a free spin or enough gold.
func _can_spin() -> bool:
	return state == "draft" and not _core_pending() and promote_unit == null \
		and (not fate_spins.is_empty() or (camp_spins < SPIN_CAP and (spins > 0 or gold >= spin_cost)))


func _core_pending() -> bool:
	return offer_kind == "core" and not picked


# Ids shown on the big prepare cards: Cores to choose, else the symbols offered after a spin.
func _card_ids() -> Array:
	return offers if _core_pending() else spin_offers


# Strip position in cells: fast start, smooth slow-down (cubic ease-out).
func _reel_pos(i: int) -> float:
	return (reel_strips[i].size() - 3) * (1.0 - pow(1.0 - reel_t[i], 3))


func _process_reels(delta: float) -> void:
	reel_glow = maxf(0.0, reel_glow - delta)
	for i in 3:
		reel_bounce[i] = maxf(0.0, reel_bounce[i] - delta)
		nudge_off[i] = maxf(0.0, nudge_off[i] - delta / NUDGE_ANIM)
	for p in popups:
		p.t -= delta
	popups = popups.filter(func(p): return p.t > 0)
	for l in links:
		l.t -= delta
	links = links.filter(func(l): return l.t > 0)
	if not payout.is_empty():
		payout_t -= delta
		if payout_t <= 0:
			_pay_next()
	if not reel_spinning:
		return
	for i in 3:
		if reel_t[i] >= 1.0:
			continue
		var before := floori(_reel_pos(i))
		reel_t[i] = minf(1.0, reel_t[i] + delta / reel_dur[i])
		if floori(_reel_pos(i)) != before:
			sfx.play("tick", 1.0 + 0.15 * i)
		if reel_t[i] >= 1.0:
			reel_bounce[i] = REEL_BOUNCE
			sfx.play("reel_stop", 1.0 - 0.06 * i)
			if i == 1 and reel_tease:
				sfx.play("tease")
	if reel_t.all(func(t): return t >= 1.0):
		reel_spinning = false
		_preview()
		if state == "draft" and nudges > 0:
			awaiting = true  # player may nudge first; SPIN / FIGHT collects
		else:
			_collect()


# Resolve the grid as it stands and light up the winning cells (before and after nudges).
func _preview() -> void:
	payout_res = Symbols.resolve(reels, _ctx())
	reel_glow = REEL_GLOW + PAY_STEP * payout_res.events.size()
	hit_cells.clear()
	for k in payout_res.lines:
		for c in Symbols.LINES[k]:
			hit_cells.append(c)


func _collect() -> void:
	awaiting = false
	_preview()
	payout = payout_res.events.duplicate()
	payout_step = 0
	payout_t = 0.15


# NUDGE: reel i drops one cell, a fresh symbol rolls in on top.
func _nudge(i: int) -> void:
	if not awaiting or nudges <= 0:
		return
	nudges -= 1
	var strip: Array = reel_strips[i] if not reel_strips[i].is_empty() else [reels[6 + i], reels[3 + i], reels[i]]
	var fresh: String = Symbols.roll(pool, _ctx())[i]
	strip.append(fresh)
	reel_strips[i] = strip
	reel_t[i] = 1.0
	nudge_off[i] = 1.0
	reels[6 + i] = reels[3 + i]
	reels[3 + i] = reels[i]
	reels[i] = fresh
	reel_bounce[i] = REEL_BOUNCE
	sfx.play("tick", 1.2)
	sfx.play("reel_stop")
	_preview()
	if nudges == 0:
		_collect()


# HOLD: lock reel i for the next spin (tap again to release and get the charge back).
func _toggle_hold(i: int) -> void:
	if state != "draft" or reel_spinning or awaiting or _core_pending():
		return
	if held[i]:
		held[i] = false
		holds += 1
	elif holds > 0:
		held[i] = true
		holds -= 1
	else:
		return
	sfx.play("clang" if held[i] else "pick")


func _reel_col_at(pos: Vector2) -> int:
	for i in 3:
		if Rect2(REEL_POS + Vector2(i * REEL_CELL, 0), Vector2(REEL_CELL, REEL_CELL * 3)).has_point(pos):
			return i
	return -1


# Pays one reel: popup over it, bump, rising chime. The spin is fully applied after 3 calls.
func _pay_next() -> void:
	var ev: Dictionary = payout.pop_front()
	var b: Dictionary = ev.buffs
	Symbols.add(power, b)
	gold += b.gold
	spins += b.spins
	for u in squad:
		u.hp = minf(_max_hp(u), u.hp + _max_hp(u) * b.heal)
	if ev.has("summon"):
		var names := []
		var n: int = ev.get("count", 1)
		if items.has("anvil") and not wave_flags.has("anvil"):
			wave_flags.anvil = true
			n += 1
			pool.append(ev.summon[0])
		var tier: int = Symbols.SUMMON_LEVEL[mini(ev.summon[1] + (1 if spin_grade == "A" else 0), 5)]
		for k in n:  # the category rolls an actual hero (FATE SPINs roll rarer ones)
			var hero := Symbols.pick_hero(ev.summon[0], unlocked, Fate.POWER.get(spin_grade, 0))
			_summon(hero, tier)
			names.append(Symbols.DATA[hero].name)
		ev.text = "%s Lv%d!" % [" + ".join(names), tier]
	if ev.text != "":
		popups.append({pos = _reel_cell(ev.i).get_center() + Vector2(0, -30), text = ev.text, color = ev.color, t = 1.3})
		reel_bounce[ev.i % 3] = REEL_BOUNCE
		if ev.has("cells"):  # payline hit: gold stroke through the matching cells
			links.append({a = ev.cells.front(), b = ev.cells.back(), t = 1.0, line = true})
			for c in ev.cells:
				cell_flash.append({c = c, t = 0.5, color = ev.color})
			win_flash = maxf(win_flash, 0.5)
		else:
			cell_flash.append({c = ev.i, t = 0.4, color = ev.color})
		if b.gold > 0:  # coins fly from the cell into the purse
			for k in clampi(int(b.gold / 20.0), 1, 10):
				fly_coins.append({from = _reel_cell(ev.i).get_center(), t = 0.0, delay = k * 0.05})
		if ev.has("link"):
			links.append({a = ev.i, b = ev.link, t = 1.0})
		if ev.has("summon"):
			_bell()
		else:
			_bell()
	payout_t = PAY_STEP if ev.text != "" else 0.05
	if payout.is_empty():
		_payout_done()


# Each paying cell rings one step higher on a pentatonic scale.
func _bell() -> void:
	sfx.play("bell", pow(2.0, PENTA[mini(payout_step, PENTA.size() - 1)] / 12.0))
	payout_step += 1


func _payout_done() -> void:
	var res := payout_res
	if spin_grade == "":
		if items.has("tooth") and not res.lines.is_empty() and not wave_flags.has("tooth"):
			wave_flags.tooth = true
			spins += 1
			_flash("Gold Tooth: +1 free spin")
		if items.has("contract") and res.lines.is_empty() and camp_spins == 1 and not wave_flags.has("contract"):
			wave_flags.contract = true
			spins += 1
			_flash("Mercenary Contract: free reroll")
	var tier := 3 if res.jackpot else (2 if res.lines.size() >= 2 else (1 if res.lines.size() == 1 else 0))
	if tier > 0:
		var gain: int = res.buffs.gold
		var sub := "+%d gold" % gain if gain > 0 else "%d lines" % res.lines.size() if res.lines.size() > 1 else ""
		var dur: float = [0.0, 1.3, 1.8, 2.8][tier]
		win_banner = {text = ["", "NICE!", "BIG WIN!", "JACKPOT!!"][tier], sub = sub, tier = tier, t = dur, t0 = dur}
		win_flash = dur
		sfx.play(["", "win1", "bigwin", "jackpot_bells"][tier])
		if tier == 3:
			sfx.play("jackpot")
		shake = maxf(shake, [0.0, 0.2, 0.5, 1.0][tier])
		for k in [0, 10, 24, 50][tier]:  # gold confetti from the machine
			var a := randf_range(-PI * 0.85, -PI * 0.15)
			var t := randf_range(0.8, 1.4)
			sparks.append({pos = REEL_WINDOW.get_center(), vel = Vector2(cos(a), sin(a)) * randf_range(300, 700), t = t, t0 = t,
				color = [Color("ffe14d"), Color("fff6c0"), Color("ffb020")].pick_random(), coin = k % 3 == 0})
	if cores.has("sanctum"):
		for u in squad:
			u.hp = minf(_max_hp(u), u.hp + _max_hp(u) * 0.1)
	_grow()
	if state == "draft":
		spin_offers = Symbols.draft_offers(3, false, 0.15 * meta.lvl("luck"))
		if res.lines.is_empty() or items.has("spyglass"):  # PEEK: a losing spin reveals the next one
			next_roll = Symbols.roll(pool, _ctx())
			popups.append({pos = _reel_cell(4).get_center() + Vector2(0, -40), text = "No line...\nPEEK at next spin!", color = Color("8fd0ff"), t = 1.4})


# Landing grows symbols: every GROW_EVERY landings a type ranks up (permanently stronger).
# Lambs instead hatch into a random rare+ character after `hatch` landings.
func _grow() -> void:
	for i in Symbols.CELLS:
		var id: String = reels[i]
		if id == "blank" or not pool.has(id):
			continue
		lands[id] = lands.get(id, 0) + 1
		var pos := _reel_cell(i).get_center() + Vector2(0, -100)
		var hatch: int = Symbols.info(id).get("hatch", 0) - (1 if items.has("crook") else 0)
		if hatch > 0:
			if lands[id] >= hatch:
				lands[id] = 0
				var heroes := ["mystic", "support"]
				var hero: String = heroes.pick_random()
				pool[pool.find(id)] = hero
				popups.append({pos = pos, text = "Grew into\n%s!" % Symbols.DATA[hero].name, color = Color("ffe14d"), t = 1.6})
				_flash("Your Lamb grew into a %s! (on your reels)" % Symbols.DATA[hero].name)
				sfx.play("jackpot")
				shake = maxf(shake, 0.5)
		elif lands[id] % Symbols.GROW_EVERY == 0 and ranks.get(id, 0) < Symbols.MAX_RANK:
			ranks[id] = ranks.get(id, 0) + 1
			popups.append({pos = pos, text = "%s\nRANK %d!" % [Symbols.info(id).name, ranks[id]], color = Color("ffe14d"), t = 1.6})
			sfx.play("merge")
			shake = maxf(shake, 0.3)


func _pick_offer(i: int) -> void:
	if i >= spin_offers.size():
		return
	pool.append(spin_offers[i])
	popups.append({pos = _reel_cell(1).get_center() + Vector2(0, -40), text = "+%s on reels" % Symbols.DATA[spin_offers[i]].name,
		color = Color("ffe14d"), t = 1.2})
	spin_offers.clear()
	sfx.play("pick")


func _reel_cell(i: int) -> Rect2:
	return Rect2(REEL_POS + Vector2(i % 3, int(i / 3.0)) * REEL_CELL, Vector2(REEL_CELL, REEL_CELL)).grow(-6)


func _ctx() -> Dictionary:
	return {ranks = ranks, items = items, cores = cores}


func _shop_rect(i: int) -> Rect2:
	return Rect2(SHOP_PANEL.position.x + 22 + i * 202, SHOP_PANEL.position.y + 70, 194, 150)


func _toggle_shop(tab := "shop") -> void:
	shop_open = not shop_open and state == "draft"
	shop_tab = tab
	drag_idx = -1
	sfx.play("draft" if shop_open else "pick")


func _item_cost(id: String) -> int:
	return Items.ITEMS[id].cost + ITEM_COST_PER_ACT * _act_index()


func _act_index() -> int:  # 0-based act of the current level
	return int((level - 1) / float(BOSS_EVERY))


# ---------------------------------------------------------------- squad

func _d(u: Dictionary) -> Dictionary:
	return u.stats if u.has("stats") else Symbols.DATA[u.type]


# Next promotion stage reached: 0 -> pick a class, 1 -> Class II, 2 -> Class III.
func _can_promote(u: Dictionary) -> bool:
	var p: int = u.get("promo", 0)
	return p < Symbols.PROMO_LEVELS.size() and u.tier >= Symbols.PROMO_LEVELS[p] and Symbols.CLASSES.has(u.type)


# Class II and III: x1.3 HP and damage each.
func _promo_mult(u: Dictionary) -> float:
	return pow(1.3, maxi(0, u.get("promo", 0) - 1))


# Class II / III need no choice: rank up on the spot with a celebration.
func _promote_stage(u: Dictionary) -> void:
	while _can_promote(u) and u.get("promo", 0) >= 1:
		u.promo += 1
		u.hp = _max_hp(u)
		u.lvl_t = LEVEL_TIME
		var p := _unit_pos(squad.find(u))
		_burst(p, Color("c05cff"), 26)
		popups.append({pos = p + Vector2(0, -60), text = "%s %s!" % [_d(u).cls_name.to_upper(), "II" if u.promo == 2 else "III"],
			color = Color("e0a0ff"), t = 1.8})
		sfx.play("jackpot")
		shake = maxf(shake, 0.5)


func _class_title(u: Dictionary) -> String:
	var d := _d(u)
	return d.get("cls_name", d.name) + ["", "", " II", " III"][u.get("promo", 0)]


func _on_promote(k: int) -> void:
	var u = promote_unit
	var mode := panel_mode
	promote_unit = null
	if u == null:
		return
	match mode:
		"promote":
			_promote(u, k)
		"absorb":
			if k == 0:
				_merge(squad.find(u), squad.find(absorb_from))
			else:  # swap places
				var sl: int = u.slot
				u.slot = absorb_from.slot
				absorb_from.slot = sl
				_sort_squad()
				sfx.play("pick")


func _open_panel(u: Dictionary, mode: String) -> void:
	promote_unit = u
	panel_mode = mode
	sfx.play("draft")


func _promote(u: Dictionary, k: int) -> void:
	if not _can_promote(u):
		return
	u.stats = Symbols.class_stats(u.type, k)
	u.cls = u.stats.cls
	u.promo = 1
	u.hp = _max_hp(u)
	u.lvl_t = LEVEL_TIME
	_sort_squad()
	var p := _unit_pos(squad.find(u))
	_burst(p, u.stats.tint, 26)
	popups.append({pos = p + Vector2(0, -50), text = "%s!" % u.stats.cls_name.to_upper(), color = u.stats.tint, t = 1.6})
	sfx.play("levelup")
	sfx.play("jackpot")
	shake = maxf(shake, 0.5)


func _promo_rect(k: int) -> Rect2:
	return Rect2(SHOP_PANEL.position.x + 24 + k * 302, SHOP_PANEL.position.y + 70, 290, 270)


func _max_hp(u: Dictionary) -> float:
	var syn := _syn_levels()
	var m: float = (1.0 + power.vigor / 100.0) * (1.0 + Symbols.SYNERGY.support.amount[syn.get("support", 0)] / 100.0)
	if Symbols.category_of(u.type) == "warrior":
		m *= 1.0 + Symbols.SYNERGY.warrior.amount[syn.get("warrior", 0)] / 100.0
	return _d(u).hp * Symbols.level_power(u.tier) * m * _promo_mult(u)


# Faction synergy level (0-2) per hero category, from how many of its heroes are in the squad.
func _syn_levels() -> Dictionary:
	var n := {}
	for u in squad:
		var c := Symbols.category_of(u.type)
		n[c] = n.get(c, 0) + 1
	var out := {}
	for c in Symbols.SYNERGY:
		out[c] = Symbols.synergy_level(n.get(c, 0))
	return out


func _dmg(u: Dictionary) -> float:
	var m: float = (1.0 + power.might / 100.0) * (1.2 if items.has("whetstone") else 1.0)
	if _d(u).attack == "melee":
		m *= FRONT_MELEE_DMG if _front(u) else BACK_MELEE_DMG
	elif _d(u).attack == "shot":
		m *= FRONT_RANGED_DMG if _front(u) else BACK_RANGED_DMG
	if cores.has("archery") and _d(u).attack == "shot":
		m *= 1.3
	var cat := Symbols.category_of(u.type)
	if cat in ["ranger", "mystic"]:
		m *= 1.0 + Symbols.SYNERGY[cat].amount[_syn_levels()[cat]] / 100.0
	if items.has("drum") and state == "wave" and battle_t < 6.0 and _front(u):
		m *= 1.3
	if state == "wave":  # Build Up: stacks every 2s of battle
		m *= 1.0 + Symbols.IMPRINTS.buildup.per / 100.0 * _imp(u, "buildup") * minf(10.0, floorf(maxf(0.0, battle_t - DEPLOY_TIME) / 2.0))
	return _d(u).dmg * Symbols.level_power(u.tier) * m * _promo_mult(u)


func _cooldown(u: Dictionary) -> float:
	return _d(u).cd / (1.0 + power.haste / 100.0) / (1.0 + Symbols.IMPRINTS.frenzy.per / 100.0 * _imp(u, "frenzy")) \
		/ (1.4 if u.get("buff_t", 0.0) > 0 else 1.0)  # Bard aura


func _summon(id: String, tier: int) -> void:
	var u := {type = id, tier = tier, hp = 0.0, t = 0.0, act_t = 0.0, slot = -1}
	u.hp = _max_hp(u)
	squad.append(u)
	if squad.size() > SQUAD_CAP and not _auto_merge():
		squad.erase(u)
		_flash("Squad full! %s lost - merge to make room" % Symbols.DATA[id].name)
		sfx.play("error")
	if squad.has(u) and u.slot < 0:  # melee prefer the front row, ranged/healers the back
		u.slot = _free_slot(Symbols.DATA[id].attack == "melee")
	_sort_squad()
	var i := squad.find(u)
	if i >= 0:  # birth: light beam + pop + sparks in the camp, a quick flash in battle
		u.born = BORN_TIME if state == "draft" else 0.5
		var rar: String = Symbols.DATA[id].rarity
		var col: Color = Color(1, 0.95, 0.7) if rar == "common" else Symbols.RARITY_COLOR[rar]
		u.color = col
		_burst(_unit_pos(i), col, 18 if state == "draft" else 8)
		sfx.play("summon", 1.0 + 0.1 * tier)
		if rar in ["epic", "legendary"] or tier >= Symbols.SUMMON_LEVEL[3]:
			shake = maxf(shake, 0.4)


func _burst(pos: Vector2, col: Color, n: int) -> void:
	for k in n:
		var a := TAU * k / n + randf_range(-0.2, 0.2)
		var t := randf_range(0.5, 0.9)
		sparks.append({pos = pos, vel = Vector2(cos(a), sin(a) - 0.8) * randf_range(140, 300), t = t, t0 = t, color = col})


func _camp_pos(i: int) -> Vector2:
	return _camp_slot_pos(maxi(squad[i].get("slot", 0), 0))


func _camp_slot_pos(slot: int) -> Vector2:
	return CAMP_CENTER + Vector2((slot % 4 - 1.5) * CAMP_SPACING, -30 + int(slot / 4.0) * 96)


func _free_slot(front: bool) -> int:
	var taken := squad.map(func(u): return u.get("slot", -1))
	var order := [0, 1, 2, 3, 4, 5, 6, 7] if front else [4, 5, 6, 7, 0, 1, 2, 3]
	for k in order:
		if not taken.has(k):
			return k
	return 0


func _front(u: Dictionary) -> bool:
	return u.get("slot", 0) < 4


# Camp formation slot under the finger, or -1.
func _formation_at(pos: Vector2) -> int:
	for k in SQUAD_CAP:
		if pos.distance_to(_camp_slot_pos(k)) < 48.0:
			return k
	return -1


# Damage a hero: front-row melee heroes shrug some off, exposed ranged heroes take more.
func _hurt(u: Dictionary, dmg: float) -> void:
	if _front(u):
		dmg *= FRONT_MELEE_ARMOR if _d(u).attack == "melee" else FRONT_RANGED_HURT
	dmg *= 1.0 - Symbols.IMPRINTS.guard.per / 100.0 * _imp(u, "guard")
	var sh: float = minf(u.get("shield", 0.0), dmg)  # skill shields soak damage first
	u.shield = u.get("shield", 0.0) - sh
	u.hp -= dmg - sh


func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# Squad order = formation order (front row first), so contact hits the front row first.
func _sort_squad() -> void:
	squad.sort_custom(func(a, b): return a.get("slot", 0) < b.get("slot", 0))


func _can_merge(a: Dictionary, b: Dictionary) -> bool:
	return not is_same(a, b)


# u absorbs g: g's worth as XP (levels up), g's imprints and its signature imprint +1, and a
# same-type twin's class. Returns what changed, as lines. No effects: also used for previews.
func _absorb_into(u: Dictionary, g: Dictionary) -> Array:
	var out := []
	if u.type == g.type and not u.has("cls") and g.has("cls"):
		u.cls = g.cls
		u.stats = g.stats
		u.promo = maxi(1, g.get("promo", 1))
		out.append("Becomes a %s" % g.stats.cls_name)
	var t0: int = u.tier
	u.xp = u.get("xp", 0.0) + Symbols.feed_value(g.type, g.tier, g.get("xp", 0.0))
	while u.tier < MAX_TIER and u.xp >= Symbols.xp_need(u.type, u.tier) - 0.001:
		u.xp -= Symbols.xp_need(u.type, u.tier)
		u.tier += 1
	if u.tier >= MAX_TIER:
		u.xp = 0.0
		out.append("Lv%d -> Lv%d  AWAKENED!" % [t0, u.tier] if t0 < MAX_TIER else "Max level")
	elif u.tier > t0:
		out.append("Lv%d -> Lv%d" % [t0, u.tier])
	else:
		out.append("XP %.1f / %.1f" % [u.xp, Symbols.xp_need(u.type, u.tier)])
	var gifts: Dictionary = g.get("imp", {}).duplicate()
	var sig: String = Symbols.HERO_IMPRINT[g.type]
	gifts[sig] = maxi(gifts.get(sig, 0), _imp(u, sig) + 1)
	for id in gifts:
		var imp: Dictionary = u.get("imp", {}).duplicate()
		if not imp.has(id) and imp.size() >= _imprint_slots(u):
			out.append("No slot for %s" % Symbols.IMPRINTS[id].name)
			continue
		var lv := mini(maxi(imp.get(id, 0), gifts[id]), Symbols.IMPRINT_MAX)
		if lv > imp.get(id, 0):
			imp[id] = lv
			u.imp = imp
			out.append("+ " + Symbols.imprint_text(id, lv))
	return out


func _imp(u: Dictionary, id: String) -> int:
	return u.get("imp", {}).get(id, 0)


func _imprint_slots(u: Dictionary) -> int:
	return Symbols.IMPRINT_SLOTS + mini(u.get("promo", 0), 2)


# squad[keep] absorbs squad[gone].
func _merge(keep: int, gone: int) -> bool:
	if keep < 0 or gone < 0 or keep == gone:
		return false
	var u: Dictionary = squad[keep]
	var g: Dictionary = squad[gone]
	var t0: int = u.tier
	var lines := _absorb_into(u, g)
	if u.get("slot", -1) < 0:
		u.slot = g.slot
	u.hp = _max_hp(u)
	squad.remove_at(gone)
	_sort_squad()
	u.lvl_t = LEVEL_TIME
	var p := _unit_pos(squad.find(u))
	_burst(p, Color(1, 0.85, 0.25), 16)
	popups.append({pos = p + Vector2(0, -40), text = ("LEVEL UP!\n" if u.tier > t0 else "") + "\n".join(lines.slice(0, 2)),
		color = Color("ffe14d"), t = 1.6})
	sfx.play("merge")
	sfx.play("levelup", 0.9 + 0.01 * u.tier)
	shake = maxf(shake, 0.25 if u.tier == t0 else 0.4)
	if state == "draft" and _can_promote(u):
		if u.get("promo", 0) == 0:
			_open_panel(u, "promote")
		else:
			_promote_stage(u)
	return true


# Squad over the cap: the newest hero is absorbed into its best match (same hero, else same category).
func _auto_merge() -> bool:
	var g: Dictionary = squad.back()
	var best := -1
	var score := -1
	for i in squad.size() - 1:
		var o: Dictionary = squad[i]
		var sc: int = o.tier + (100 if o.type == g.type else 50 if Symbols.category_of(o.type) == Symbols.category_of(g.type) else 0)
		if sc > score:
			best = i
			score = sc
	return _merge(best, squad.size() - 1)

# Battle formation on the path; in the camp the squad stands on the summoning circle,
# and while the fight starts it marches from the circle onto the path.
func _unit_pos(i: int) -> Vector2:
	var u: Dictionary = squad[i]
	if state == "draft":
		return _camp_pos(i)
	if trans > 0 and state == "wave":
		return _camp_pos(i).lerp(_home(u), _smooth(1.0 - trans / TRANS_TIME))
	return u.get("pos", _home(u))


# ---------------------------------------------------------------- wave

func _start_wave() -> void:
	state = "wave"
	wave_rec = {spins = camp_spins, deaths = 0, gold = gold, squad = squad.size(), hp = 0.0,
		syn = _syn_levels().values().filter(func(l): return l > 0).size(),
		promoted = squad.filter(func(u): return u.has("stats")).size(),
		class2 = squad.filter(func(u): return u.get("promo", 0) >= 2).size(),
		imp3 = squad.filter(func(u): return u.get("imp", {}).values().has(Symbols.IMPRINT_MAX)).size()}
	battle_t = 0.0
	victory_t = 0.0
	projectiles.clear()
	enemy_shots.clear()
	shells.clear()
	for u in squad:
		u.pos = _home(u)
		u.t = randf_range(0.0, 0.4)
		u.shield = 0.0
		if Symbols.SKILLS.has(u.type):  # first cast comes halfway through the cooldown
			u.sk_t = Symbols.SKILLS[u.type].cd * 0.5 + randf_range(0.0, 0.5)
		u.erase("leapt")
		u.erase("dash_to")
	_make_wave()
	trans = TRANS_TIME
	wave_intro = WAVE_INTRO
	sfx.play("march")
	if (level - 1) % BOSS_EVERY == 0:
		decor.clear()
		for i in 12:
			_scroll_decor(LANE_BOTTOM / 12.0)
	var notes := []
	var news := ENEMY_TYPES.values().filter(func(t): return t.from == level).map(func(t): return "%s - %s" % [t.name, t.desc])
	if not news.is_empty():
		notes.append("New enemy: " + ", ".join(news))
	sfx.play("boss" if _boss_level() or judgement else "wave")
	_flash("%s  FIGHT!%s" % [_wave_name(),
		"\n" + "\n".join(notes) if not notes.is_empty() else ""])


func _boss_level() -> bool:
	return level % BOSS_EVERY == 0


func _wave_name() -> String:
	return "Act %d  Wave %d%s" % [_act_index() + 1, (level - 1) % BOSS_EVERY + 1,
		"  BOSS" if _boss_level() else ("  JUDGEMENT" if judgement and state == "wave" else "")]


func _hp_scale() -> float:
	return pow(HP_GROWTH, level - 1) * (1.0 + power.enemy_hp) * (JUDGE_HP if judgement else 1.0) * (Meta.HARD_HP if meta.hard else 1.0) * _stage().hp


func _dmg_scale() -> float:
	return pow(DMG_GROWTH, level - 1) * (JUDGE_DMG if judgement else 1.0) * (Meta.HARD_DMG if meta.hard else 1.0) * _stage().dmg


# Scenery: trees on the banks (drawn over units), bushes on the lane edges, rocks in the water.
func _scroll_decor(dy: float) -> void:
	for d in decor:
		d.pos += Vector2(0, dy)
	decor = decor.filter(func(d): return d.pos.y < LANE_BOTTOM + 200)
	decor_at -= dy
	while decor_at <= 0:
		decor_at += randf_range(60, 140)
		var kinds: Array = _theme().decor
		var weights := PackedFloat32Array(kinds.map(func(k): return k[1]))
		_spawn_decor(kinds[rng.rand_weighted(weights)][0], randf_range(-80, -40))


func _spawn_decor(kind: String, y: float) -> void:
	var left := randf() < 0.5
	var bank := randf_range(0, 30) if left else randf_range(690, 720)
	var edge := LANE_L + 14 if left else LANE_R - 14
	match kind:
		"tree": decor.append({path = Art.TREES.pick_random(), pos = Vector2(bank, y), scale = 0.6, top = true})
		"bush": decor.append({path = Art.BUSHES.pick_random(), pos = Vector2(edge, y), scale = 0.45, top = false})
		"water_rock": decor.append({path = Art.WATER_ROCKS.pick_random(), pos = Vector2(randf_range(8, 30) if left else randf_range(690, 712), y), scale = 0.7, top = false})
		"rock": decor.append({path = Art.ROCKS.pick_random(), pos = Vector2(edge, y), scale = 0.6, top = false})
		"gold": decor.append({path = Art.GOLD_STONES.pick_random(), pos = Vector2(edge, y), scale = 0.4, top = false})
		"house": decor.append({path = Art.HOUSES.pick_random(), pos = Vector2(22.0 if left else 698.0, y), scale = 0.42, top = true, whole = true})
		"red_building": decor.append({path = Art.RED_BUILDINGS.pick_random(), pos = Vector2(22.0 if left else 698.0, y), scale = 0.4, top = true, whole = true})
		"fire": decor.append({path = Art.FIRES.pick_random(), pos = Vector2(bank if randf() < 0.6 else edge, y), scale = 1.1, top = true})


func _theme() -> Dictionary:
	return THEMES[mini(_act_index() + _stage().theme, THEMES.size() - 1)]


func _stage() -> Dictionary:
	return Meta.STAGES[meta.stage]


# Ground/scenery colour: act tint, darker each wave of the act, purple on judgement, red on bosses.
func _tint() -> Color:
	var t: Color = _theme().tint.darkened(0.05 * ((level - 1) % BOSS_EVERY))
	if judgement and state == "wave":
		t *= Color(0.85, 0.72, 1.0)
	if _boss_level():
		t *= Color(1.0, 0.82, 0.82)
	return t


func _draw_decor(d: Dictionary) -> void:
	if d.get("whole", false):  # buildings are single images, not animation strips
		var t := Art.tex(d.path)
		var size: Vector2 = t.get_size() * d.scale
		draw_texture_rect(t, Rect2(d.pos - size / 2, size), false, _tint())
	else:
		_sprite(d.path, d.pos, d.scale, false, int(d.pos.x), _tint())


# ---------------------------------------------------------------- battle
# Auto-battle: both squads walk into formation (DEPLOY_TIME), then every unit picks a target,
# closes to its reach and attacks on its cooldown until one side is gone.

func _etype(type: String) -> Dictionary:
	return ENEMY_TYPES[type] if ENEMY_TYPES.has(type) else BOSSES[type]


# Hero home spot on the battlefield, from its formation slot.
func _home(u: Dictionary) -> Vector2:
	var slot := maxi(u.get("slot", 0), 0)
	return Vector2(W / 2 + (slot % 4 - 1.5) * HERO_SPACING, SQUAD_Y - 64 + int(slot / 4.0) * 80)


func _enemy_row_y(r: int) -> float:
	return SQUAD_Y - 64 - ENEMY_GAP - r * 84


# Enemy squad about the size of yours: fighters in front, shooters and casters behind, the act's
# boss up front on boss waves.
func _make_wave() -> void:
	enemies.clear()
	var n := clampi(squad.size() + (1 if level >= 8 else 0) + rng.randi_range(-1, 0), 3, 10)
	var ids := []
	if _boss_level():
		ids.append(BOSS_ORDER[mini(_act_index(), BOSS_ORDER.size() - 1)])
		n = maxi(2, n - 3)
	for k in n:
		ids.append(_pick_enemy_type())
	var rows := [[], [], []]
	for id in ids:
		var melee: bool = _etype(id).attack == "melee"
		var r := 0 if melee else 1
		if rows[r].size() >= 5:
			r = 1 if r == 0 else 2
		rows[r].append(id)
	wave_hp = 0.0
	for r in 3:
		for k in rows[r].size():
			var home := Vector2(W / 2 + (k - (rows[r].size() - 1) / 2.0) * 112, _enemy_row_y(r))
			_add_enemy(rows[r][k], home, home - Vector2(0, home.y + 80 + randf() * 80))


func _add_enemy(type: String, home: Vector2, start: Vector2) -> void:
	var t := _etype(type)
	var hp_: float = ENEMY_HP * t.hp * _hp_scale() * (_stage().boss_hp if BOSSES.has(type) else 1.0)
	enemies.append({id = next_id, kind = "boss" if BOSSES.has(type) else "enemy", type = type, pos = start, home = home,
		hp = hp_, max_hp = hp_, r = t.r, dmg = ENEMY_DMG * t.dmg * _dmg_scale(), t = randf_range(0.2, 0.8),
		ab_t = t.get("every", 0.0), act_t = 0.0, flip = false, slow_t = 0.0, spd = 1.0})
	wave_hp += hp_
	next_id += 1


func _pick_enemy_type() -> String:
	var ids := []
	var weights := PackedFloat32Array()
	for id in ENEMY_TYPES:
		if ENEMY_TYPES[id].from <= level:
			ids.append(id)
			weights.append(ENEMY_TYPES[id].weight)
	return ids[rng.rand_weighted(weights)]


func _process_wave(delta: float) -> void:
	delta *= BATTLE_SPEED
	battle_t += delta
	for p in projectiles:
		p.pos += p.vel * delta
	projectiles = projectiles.filter(func(p): return p.pos.y > -20 and p.pos.y < LANE_BOTTOM and p.pos.x > 0 and p.pos.x < W)
	for fx in effects:
		fx.t -= delta
	effects = effects.filter(func(fx): return fx.t > 0)
	for e in enemies:
		e.act_t = maxf(0.0, e.act_t - delta)
	if battle_t < DEPLOY_TIME:  # march into formation
		for e in enemies:
			e.pos = e.pos.move_toward(e.home, 420.0 * delta)
		return
	# overtime: after a while both sides hit harder, so stalemates (healer vs shaman) end
	var ot := 1.0 + maxf(0.0, battle_t - DEPLOY_TIME - OVERTIME_AFTER) * 0.08
	_heroes_act(delta, ot)
	_enemies_act(delta, ot)
	_separate()
	_collide()
	_enemy_projectiles(delta)
	if squad.is_empty():
		_game_over("Squad wiped on\n%s" % _wave_name())
	elif enemies.is_empty():
		victory_t += delta
		if victory_t > 0.8:
			_end_wave()


func _closest(p: Vector2, list: Array):
	var best = null
	var best_d := INF
	for o in list:
		var dd: float = p.distance_squared_to(o.pos)
		if dd < best_d:
			best = o
			best_d = dd
	return best


func _reach(u: Dictionary) -> float:
	var d := _d(u)
	if d.attack == "melee":
		return 26.0 + d.range * 0.35
	return d.range * 0.5


func _heroes_act(delta: float, ot: float) -> void:
	for u in squad:
		u.act_t = maxf(0.0, u.get("act_t", 0.0) - delta)
		u.buff_t = maxf(0.0, u.get("buff_t", 0.0) - delta)
		u.t -= delta
		u.moving = false
		var d := _d(u)
		var p: Vector2 = u.pos
		if u.has("dash_to"):  # Skylancer leap
			u.pos = p.move_toward(u.dash_to, DASH_SPEED * delta)
			u.moving = true
			if u.pos.distance_to(u.dash_to) < 2.0:
				u.erase("dash_to")
				for e in enemies:
					if e.pos.distance_to(u.pos) < 80.0 + e.r:
						e.hp -= _dmg(u) * 1.5 * ot
				effects.append({pos = u.pos, r = 70.0, t = 0.4, t0 = 0.4, boom = true, color = Color(0.6, 0.7, 1, 0.3)})
				sfx.play("boom")
			continue
		if enemies.is_empty():
			continue
		var rg := _imp(u, "regen")
		if rg > 0:
			u.hp = minf(_max_hp(u), u.hp + _max_hp(u) * Symbols.IMPRINTS.regen.per / 100.0 * rg * delta)
		u.sk_t = u.get("sk_t", 3.0) - delta
		if u.sk_t <= 0 and Symbols.SKILLS.has(u.type):
			u.sk_t = Symbols.SKILLS[u.type].cd * (1.0 - 0.1 * _imp(u, "focus"))
			_cast_skill(u, ot)
		if d.get("ability", "") == "leap" and not u.get("leapt", false):
			u.leapt = true
			var far = enemies[0]
			for e in enemies:
				if e.pos.y < far.pos.y:
					far = e
			u.dash_to = far.pos + Vector2(0, far.r + 20)
			continue
		match d.attack:
			"heal_all", "heal":
				if u.t > 0:
					continue
				var hurt := squad.filter(func(o): return o.hp < _max_hp(o))
				u.t = 0.2
				if hurt.is_empty():
					continue
				if d.attack == "heal":
					hurt.sort_custom(func(a, b): return a.hp / _max_hp(a) < b.hp / _max_hp(b))
					hurt = [hurt[0]]
				for o in hurt:
					o.hp = minf(_max_hp(o), o.hp + _dmg(u))
				sfx.play("heal")
				u.t = _cooldown(u)
				u.act_t = ATTACK_ANIM
			"aura":  # Bard: nearby heroes attack faster for a while (and heal, as Minstrel)
				if u.t > 0:
					continue
				for o in squad:
					if o.pos.distance_to(p) < _reach(u):
						o.buff_t = 4.0
						o.hp = minf(_max_hp(o), o.hp + _max_hp(o) * d.get("heal", 0.0))
				effects.append({pos = p, r = _reach(u), t = 0.5, color = Color(1, 0.85, 0.4)})
				sfx.play("heal")
				u.t = _cooldown(u)
				u.act_t = ATTACK_ANIM
			"melee", "shot":
				var target = _closest(p, enemies)
				var reach: float = _reach(u) + (target.r if d.attack == "melee" else 0.0)
				u.flip = target.pos.x < p.x - 4
				if p.distance_to(target.pos) > reach:
					u.pos = p.move_toward(target.pos, HERO_SPEED * delta)
					u.moving = true
				elif u.t <= 0:
					u.t = _cooldown(u)
					u.act_t = ATTACK_ANIM
					if d.attack == "melee":
						for e in enemies:  # sweeping strike: everyone in reach
							if p.distance_to(e.pos) <= _reach(u) + e.r:
								e.hp -= _dmg(u) * ot
						effects.append({pos = p + (target.pos - p).normalized() * 30, r = 40.0, t = 0.12, color = Color(1, 1, 1)})
						sfx.play("swing")
						sfx.play("clang", 0.9)
					else:
						var targets := [target]
						if d.has("shots"):  # Hunter: several nearest targets
							var by_dist := enemies.duplicate()
							by_dist.sort_custom(func(a, b): return p.distance_squared_to(a.pos) < p.distance_squared_to(b.pos))
							targets = by_dist.slice(0, d.shots)
						for tg in targets:
							projectiles.append({pos = p, vel = (tg.pos - p).normalized() * PROJ_SPEED, dmg = _dmg(u) * ot,
								pierce = d.get("pierce", 0), blast = d.get("blast", 0.0), crit = d.get("crit", 0.0),
								slow = d.get("ability", "") == "slow", color = d.color, hit = []})
						sfx.play("throw" if d.get("blast", 0.0) > 0 else "bow")


# Who an enemy goes for: a taunting Shieldmaiden nearby, else raiders dive the back row,
# archers aim at the front row, everyone else hits the closest hero.
func _enemy_target(e: Dictionary, t: Dictionary):
	var taunt := squad.filter(func(u): return _d(u).get("ability", "") == "taunt" and u.pos.distance_to(e.pos) < TAUNT_RANGE)
	if not taunt.is_empty():
		return _closest(e.pos, taunt)
	var pool_: Array = squad
	if t.get("ability", "") == "dive" and squad.any(func(u): return not _front(u)):
		pool_ = squad.filter(func(u): return not _front(u))
	elif t.attack == "bolt" and squad.any(_front):
		pool_ = squad.filter(_front)
	return _closest(e.pos, pool_)


func _enemies_act(delta: float, ot: float) -> void:
	var spawned := []
	for e in enemies:
		var t := _etype(e.type)
		e.slow_t = maxf(0.0, e.slow_t - delta)
		if e.get("stun_t", 0.0) > 0:  # Last Stand stun
			e.stun_t -= delta
			continue
		var sf := 0.6 if e.slow_t > 0 else 1.0
		e.t -= delta * sf
		if t.has("every"):  # boss ability
			e.ab_t -= delta
			if e.ab_t <= 0:
				e.ab_t = t.every
				spawned += _boss_ability(e)
		if t.get("enrage", false) and not e.get("enraged", false) and e.hp < e.max_hp * 0.5:
			e.enraged = true
			e.dmg *= 1.5
			e.spd = 1.5
			popups.append({pos = e.pos + Vector2(0, -70), text = "ENRAGED!", color = Color(1, 0.3, 0.2), t = 1.5})
			sfx.play("boss")
			shake = maxf(shake, 0.6)
		if e.has("dash_to"):  # Warlord charge
			e.pos = e.pos.move_toward(e.dash_to, DASH_SPEED * delta)
			if e.pos.distance_to(e.dash_to) < 2.0:
				e.erase("dash_to")
				for u in squad:
					if u.pos.distance_to(e.pos) < 90.0:
						_hurt(u, e.dmg * 1.5 * ot)
				effects.append({pos = e.pos, r = 90.0, t = 0.4, t0 = 0.4, boom = true, color = Color(1, 0.3, 0.2, 0.3)})
				sfx.play("boom")
				shake = maxf(shake, 0.4)
			continue
		if t.attack == "heal":  # Shaman: patch up the most hurt ally
			var low = null
			for o in enemies:
				if o.hp < o.max_hp and (low == null or o.hp / o.max_hp < low.hp / low.max_hp):
					low = o
			if low != null and e.t <= 0:
				low.hp = minf(low.max_hp, low.hp + e.dmg * 2.5 * ot)
				e.t = t.cd
				e.act_t = ATTACK_ANIM
				effects.append({pos = low.pos, r = 34.0, t = 0.3, color = Color(0.4, 1, 0.5)})
			continue
		if squad.is_empty():
			continue
		var tg = _enemy_target(e, t)
		e.flip = tg.pos.x < e.pos.x - 4
		var reach: float = t.reach + (UNIT_R if t.attack == "melee" else 0.0)
		if e.pos.distance_to(tg.pos) > reach:
			e.pos = e.pos.move_toward(tg.pos, ENEMY_SPEED * t.speed * e.spd * sf * delta)
			continue
		if e.t > 0:
			continue
		e.t = t.cd
		e.act_t = ATTACK_ANIM
		match t.attack:
			"melee":
				if t.get("ability", "") == "cleave":
					for u in squad:
						if u.pos.distance_to(e.pos) <= reach:
							_hurt(u, e.dmg * ot)
				else:
					_hurt(tg, e.dmg * ot)
				sfx.play("hurt")
			"bolt":
				enemy_shots.append({pos = e.pos, vel = (tg.pos - e.pos).normalized() * ENEMY_SHOT_SPEED, dmg = e.dmg * ot})
				sfx.play("bow", 0.8)
			"shell":
				shells.append({pos = tg.pos, t = SHELL_TIME, dmg = e.dmg * ot, r = 70.0})
				sfx.play("launch")
	enemies += spawned
	_apply_deaths()


# Boss specials. Returns enemies to add (Witch summons).
func _boss_ability(e: Dictionary) -> Array:
	match _etype(e.type).ability:
		"charge":  # dash into the back row
			var back := squad.filter(func(u): return not _front(u))
			var tg = _closest(e.pos, back if not back.is_empty() else squad)
			if tg != null:
				e.dash_to = tg.pos
				popups.append({pos = e.pos + Vector2(0, -70), text = "CHARGE!", color = Color(1, 0.5, 0.3), t = 1.2})
		"summon":  # two grunts appear beside her
			var out := []
			if enemies.size() < 12:
				for k in 2:
					var p: Vector2 = e.pos + Vector2(-70 + 140 * k, 30)
					_add_enemy("grunt", p, p)
					out.append(enemies.pop_back())
					effects.append({pos = p, r = 40.0, t = 0.4, t0 = 0.4, boom = true, color = Color(0.7, 0.3, 1, 0.3)})
				popups.append({pos = e.pos + Vector2(0, -70), text = "SUMMON!", color = Color(0.8, 0.5, 1), t = 1.2})
			return out
		"slam":  # warning circle around itself, lands after SHELL_TIME
			shells.append({pos = e.pos, t = SHELL_TIME, dmg = e.dmg * 1.4, r = 130.0})
			popups.append({pos = e.pos + Vector2(0, -70), text = "SLAM!", color = Color(1, 0.4, 0.3), t = 1.2})
	return []


# Units don't stack: overlapping bodies push apart; everyone stays inside the arena.
func _separate() -> void:
	var bodies: Array = []
	for u in squad:
		bodies.append([u, UNIT_R])
	for e in enemies:
		bodies.append([e, e.r * 0.8])
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Dictionary = bodies[i][0]
			var b: Dictionary = bodies[j][0]
			var gap: float = bodies[i][1] + bodies[j][1]
			var dv: Vector2 = a.pos - b.pos
			var dist := dv.length()
			if dist < gap:
				var push: Vector2 = (dv / dist if dist > 0.01 else Vector2(randf() - 0.5, 1)) * (gap - dist) * 0.5
				if not a.has("dash_to"):
					a.pos += push
				if not b.has("dash_to"):
					b.pos -= push
	for body in bodies:
		var o: Dictionary = body[0]
		o.pos = Vector2(clampf(o.pos.x, LANE_L + 20, LANE_R - 20), clampf(o.pos.y, 60, LANE_BOTTOM - 20))


func _collide() -> void:
	for p in projectiles:
		for e in enemies:
			if e.hp <= 0 or p.hit.has(e.id) or p.pos.distance_to(e.pos) > e.r + 6:
				continue
			var dmg: float = p.dmg * (3.0 if randf() < p.crit else 1.0)
			if p.slow:
				e.slow_t = 2.0
			if p.blast > 0:
				for o in enemies:
					if o.pos.distance_to(p.pos) < p.blast + o.r:
						o.hp -= dmg
						if p.slow:
							o.slow_t = 2.0
				effects.append({pos = p.pos, r = p.blast, t = 0.4, t0 = 0.4, boom = true, color = Color(1, 0.6, 0.2, 0.2)})
				p.pierce = -1
				sfx.play("boom")
			else:
				e.hp -= dmg
				sfx.play("hit")
				p.hit.append(e.id)
				p.pierce -= 1
			break
	projectiles = projectiles.filter(func(p): return p.pierce >= 0)
	var alive: Array = []
	for e in enemies:
		if e.hp <= 0:
			_kill(e)
		else:
			alive.append(e)
	enemies = alive


func _enemy_projectiles(delta: float) -> void:
	for s in enemy_shots:
		s.pos += s.vel * delta
		for u in squad:
			if u.pos.distance_to(s.pos) < UNIT_R + 6:
				_hurt(u, s.dmg)
				sfx.play("hurt")
				s.pos.y = 99999.0  # consumed
				break
	enemy_shots = enemy_shots.filter(func(s): return s.pos.y > -20 and s.pos.y < LANE_BOTTOM)
	for sh in shells:
		sh.t -= delta
		if sh.t <= 0:
			sfx.play("boom")
			for u in squad:
				if u.pos.distance_to(sh.pos) < sh.r + UNIT_R:
					_hurt(u, sh.dmg)
			effects.append({pos = sh.pos, r = sh.r, t = 0.4, t0 = 0.4, boom = true, color = Color(1, 0.4, 0.1, 0.25)})
	shells = shells.filter(func(sh): return sh.t > 0)
	_apply_deaths()


func _apply_deaths() -> void:
	var dead := squad.filter(func(u): return u.hp <= 0)
	if not dead.is_empty():
		squad = squad.filter(func(u): return u.hp > 0)
		for u in dead:  # Last Stand: explode on death and stun nearby enemies
			var ex := _imp(u, "explode")
			if ex > 0 and state == "wave":
				for e in enemies:
					if e.pos.distance_to(u.pos) < 140.0 + e.r:
						e.hp -= _max_hp(u) * Symbols.IMPRINTS.explode.per / 100.0 * ex
						e.stun_t = 1.0
				effects.append({pos = u.pos, r = 140.0, t = 0.5, t0 = 0.5, boom = true, color = Color(1, 0.5, 0.1, 0.35)})
				popups.append({pos = u.pos + Vector2(0, -40), text = "LAST STAND!", color = Color(1, 0.6, 0.2), t = 1.2})
				sfx.play("boom")
				shake = maxf(shake, 0.4)
		wave_rec.deaths = wave_rec.get("deaths", 0) + dead.size()
		_flash("%s fell!" % Symbols.DATA[dead[0].type].name)
		sfx.play("unit_die")


# Kill reward: gold straight to the purse (coins fly up to it).
func _kill(e: Dictionary) -> void:
	var boss: bool = e.kind == "boss"
	var g := int((BOSS_GOLD if boss else KILL_GOLD) * (1.0 + minf(power.magnet, 1.0)) * (1.5 if judgement else 1.0))
	gold += g
	for k in (12 if boss else 3):
		fly_coins.append({from = e.pos, t = 0.0, delay = k * 0.04})
	popups.append({pos = e.pos + Vector2(0, -30), text = "+%d" % g, color = Color("ffe14d"), t = 1.0})
	effects.append({pos = e.pos, r = 30.0, t = 0.3, t0 = 0.3, boom = true, color = Color(1, 1, 1, 0.2)})
	sfx.play("enemy_die")
	if boss:
		shake = 1.0
		sfx.play("jackpot")


func _end_wave() -> void:
	if level >= LEVELS:
		_game_over("You beat all 3 acts!")
		return
	var hp_now := 0.0
	var hp_max := 0.0
	for u in squad:
		hp_now += maxf(u.hp, 0.0)
		hp_max += _max_hp(u)
	wave_rec.hp = hp_now / maxf(hp_max, 1.0)
	var heal := (0.7 if items.has("meat") else WAVE_HEAL) + 0.15 * meta.lvl("heal")
	for u in squad:
		u.hp = minf(_max_hp(u), u.hp + _max_hp(u) * heal)
	var notes := []
	var bonus := WAVE_GOLD + WAVE_GOLD_STEP * level
	gold += bonus
	notes.append("Wave cleared! +%d gold" % bonus)
	if items.has("purse"):
		var interest := mini(int(gold / 5.0), 200)
		gold += interest
		notes.append("Coin Purse +%d gold" % interest)
	if judgement:
		gold += JUDGE_GOLD
		notes.append("Judgement passed! +%d gold" % JUDGE_GOLD)
	for k in trials.size():
		var t: Dictionary = trials[k]
		if Fate.advance(t, wave_rec):
			fate_spins.append(t.grade)
			notes.append("FATE STONE! %s done: FATE SPIN ready" % t.name)
			sfx.play("jackpot")
			shake = maxf(shake, 0.5)
		if t.progress >= t.need or t.left <= 0:
			trials[k] = Fate.new_trial(t.grade, t.id)
	if not notes.is_empty():
		_flash("\n".join(notes))
	_open_camp(_boss_level())


# Camp between waves. core = offer Cores (run start and after each boss) instead of symbols.
func _open_camp(core: bool) -> void:
	state = "draft"
	picked = false
	offer_kind = "core" if core else "symbol"
	offers = Items.offers(Items.CORES, cores, 3) if core else []
	spin_offers.clear()
	spin_cost = int(SPIN_COST * _discount())
	camp_spins = 0
	wave_flags = {}
	nudges = NUDGES + (1 if items.has("dice") else 0) + meta.lvl("nudge")
	holds = HOLDS + (1 if items.has("chain") else 0) + meta.lvl("hold")
	held = [false, false, false]
	fade = 0.9 if started else 0.0
	if items.has("gear") and started:
		spins += 1
	shop = Items.offers(Items.ITEMS, items, 3) if started else []
	sfx.play("draft")


func _buy_item(i: int) -> void:
	if state != "draft" or i >= shop.size() or shop[i] == "" or gold < _item_cost(shop[i]):
		return
	var id: String = shop[i]
	gold -= _item_cost(id)
	items.append(id)
	shop[i] = ""
	if id == "crook":
		pool += ["lamb", "lamb"]
	if id == "seed":
		pool += ["jester", "jester"]
	sfx.play("buy")


# Start the next wave (judge = judgement wave: harder, x1.5 coin gold + JUDGE_GOLD bonus).
func _next(judge: bool) -> void:
	if state != "draft":
		return
	if reel_spinning:
		return
	if awaiting:
		_collect()
	while not payout.is_empty():
		_pay_next()
	promote_unit = null
	if started:
		level += 1
	started = true
	shop_open = false
	spin_offers.clear()
	judgement = judge and not _boss_level()
	_start_wave()


func _pick(i: int) -> void:
	if state != "draft":
		return
	if not _core_pending():
		_pick_offer(i)
		return
	cores.append(offers[i])
	picked = true
	sfx.play("pick")


func _game_over(msg: String) -> void:
	state = "over"
	var won := msg.begins_with("You beat")
	var cleared := level if won else level - 1
	earned = meta.reward(cleared, won)
	meta.crystals += earned
	var locked := ["rare", "epic", "legendary"].filter(func(r): return not meta.rarity_unlocked(r))
	meta.best = maxi(meta.best, level)
	var news := []
	for r in locked:
		if meta.rarity_unlocked(r):
			news.append("New %s heroes unlocked!" % r)
	if won:
		meta.wins += 1
		if meta.stage + 1 > meta.cleared and meta.stage + 1 < Meta.STAGES.size():
			news.append("Stage %d unlocked: %s" % [meta.stage + 2, Meta.STAGES[meta.stage + 1].name])
		meta.cleared = maxi(meta.cleared, meta.stage + 1)
	meta.save()
	over_label.text = "%s\n+%d crystals%s" % [msg, earned, "\n" + "\n".join(news) if not news.is_empty() else ""]
	sfx.stop_music()
	sfx.play("win" if msg.begins_with("You beat") else "lose")


# ---------------------------------------------------------------- input

# Camp unit under the finger (prepare phase only), or -1.
func _slot_at(pos: Vector2) -> int:
	if state != "draft":
		return -1
	for i in squad.size():
		if pos.distance_to(_camp_pos(i) + Vector2(0, -6)) < 46.0:
			return i
	return -1


func _input(event: InputEvent) -> void:
	if state == "over" or settings_open or shop_open or promote_unit != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var slot := _slot_at(event.position)
		if event.pressed and LEVER_RECT.has_point(event.position) and state == "draft":
			lever_drag = event.position.y
			lever_pull = 0.0
			sfx.play("lever")
			return
		if not event.pressed and lever_drag >= 0:
			var tap := absf(event.position.y - lever_drag) < 12.0
			lever_drag = -1.0
			if tap or lever_pull > 0.35:
				_pull_lever()
			else:
				lever_from = lever_pull
				lever_t = 0.12 / LEVER_ANIM  # let go early: spring back
			return
		if event.pressed:
			var col := _reel_col_at(event.position) if state == "draft" else -1
			if col >= 0:
				if awaiting:
					_nudge(col)
				else:
					_toggle_hold(col)
				return
			if slot >= 0 and slot < squad.size():
				drag_idx = slot
				drag_pos = event.position
		else:
			if drag_idx >= 0 and slot == drag_idx:  # tap = promote, else hero info (skill, imprints)
				_open_panel(squad[slot], "promote" if _can_promote(squad[slot]) else "info")
			elif drag_idx >= 0 and drag_idx < squad.size() and slot >= 0 and slot < squad.size() and slot != drag_idx:
				absorb_from = squad[drag_idx]  # dropped on another hero: absorb it, or swap places
				_open_panel(squad[slot], "absorb")
			elif drag_idx >= 0 and drag_idx < squad.size():
				var to := _formation_at(event.position)
				if to >= 0 and to != squad[drag_idx].slot:  # move to an empty slot, or swap places
					var other: Array = squad.filter(func(o): return o.slot == to)
					if not other.is_empty():
						other[0].slot = squad[drag_idx].slot
					squad[drag_idx].slot = to
					_sort_squad()
					sfx.play("pick")
			drag_idx = -1
	elif event is InputEventMouseMotion:
		if lever_drag >= 0:
			var was := lever_pull
			lever_pull = clampf((event.position.y - lever_drag) / 110.0, 0.0, 1.0)
			if int(lever_pull * 5) != int(was * 5):
				sfx.play("click", 0.8 + lever_pull * 0.5)  # ratchet
		elif drag_idx >= 0:
			drag_pos = event.position


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.0)
	fade = maxf(0.0, fade - delta * 1.6)
	wave_intro = maxf(0.0, wave_intro - delta)
	trans = maxf(0.0, trans - delta)
	for u in squad:
		u.born = maxf(0.0, u.get("born", 0.0) - delta)
		u.lvl_t = maxf(0.0, u.get("lvl_t", 0.0) - delta)
	lever_t = minf(1.0, lever_t + delta / LEVER_ANIM)
	win_flash = maxf(0.0, win_flash - delta)
	purse_bump = maxf(0.0, purse_bump - delta * 4.0)
	if not win_banner.is_empty():
		win_banner.t -= delta
		if win_banner.t <= 0:
			win_banner = {}
	for f in cell_flash:
		f.t -= delta
	cell_flash = cell_flash.filter(func(f): return f.t > 0)
	for c in fly_coins:
		c.delay -= delta
		if c.delay <= 0:
			c.t += delta / COIN_FLY
			if c.t >= 1.0:
				purse_bump = 1.0
				sfx.play("tink", randf_range(0.95, 1.15))
	fly_coins = fly_coins.filter(func(c): return c.t < 1.0)
	if gold < gold_shown:  # spending shows at once, winnings count up
		gold_shown = gold
	else:
		gold_shown = move_toward(gold_shown, gold, maxf((gold - gold_shown) * delta * 4.0, delta * 150.0))
	for p in sparks:
		p.pos += p.vel * delta
		p.vel.y += 420.0 * delta
		p.t -= delta
	sparks = sparks.filter(func(p): return p.t > 0)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 18.0 * shake * shake
	if not settings_open:  # settings panel pauses the game
		_process_reels(delta)
		if state == "wave":
			_process_wave(delta)
		msg_timer -= delta
		anim_time += delta
	_update_ui()
	queue_redraw()


func _update_ui() -> void:
	var title := state == "title"
	wave_label.text = "CAMP" if title else _wave_name().to_upper().replace("  JUDGEMENT", "")
	gold_label.text = str(meta.crystals) if title else str(int(gold_shown))
	power_label.visible = not title
	squad_label.visible = not title
	play_btn.visible = title and not meta_open and not settings_open
	upg_btn.visible = play_btn.visible
	hard_btn.visible = play_btn.visible and meta.wins > 0
	hard_btn.text = "HARD MODE: %s" % ("ON" if meta.hard else "OFF")
	stage_btn.visible = play_btn.visible
	var st := _stage()
	stage_btn.text = "STAGE %d: %s%s" % [meta.stage + 1, st.name, "   >" if meta.cleared > 0 else ""]
	meta_close.visible = title and meta_open and not settings_open
	for k in meta_btns.size():
		var id: String = Meta.UPGRADES[k].id
		meta_btns[k].visible = meta_close.visible
		meta_btns[k].text = "MAX" if meta.cost(id) < 0 else "     %d" % meta.cost(id)
		meta_btns[k].disabled = meta.cost(id) < 0 or meta.crystals < meta.cost(id)
	squad_label.text = "%d/%d" % [squad.size(), SQUAD_CAP]
	power_label.text = "Dmg +%d%%   Speed +%d%%   HP +%d%%   Enemy HP x%s" % [power.might, power.haste, power.vigor, snappedf(_hp_scale(), 0.1)]
	msg_label.visible = msg_timer > 0 and state == "wave"
	if reel_spinning:
		spin_btn.text = "STOP"
	elif awaiting:
		spin_btn.text = "COLLECT"
	elif state == "wave":
		spin_btn.text = "IN BATTLE"
	elif _core_pending():
		spin_btn.text = "Pick a Core"
	else:
		spin_btn.text = "FATE SPIN" if not fate_spins.is_empty() and not reel_spinning else "NO SPINS LEFT" if camp_spins >= SPIN_CAP \
			else "FREE x%d" % spins if spins > 0 else "      %d" % spin_cost
	spin_btn.disabled = not reel_spinning and not awaiting and not _can_spin()
	spin_btn.visible = not settings_open and state in ["draft", "wave"]

	var camp := state == "draft" and not settings_open
	var in_promo := camp and promote_unit != null and not shop_open
	var in_shop := camp and shop_open
	camp = camp and not shop_open and not in_promo
	for k in 2:
		promo_btns[k].visible = in_promo and panel_mode != "info"
		promo_btns[k].text = ""
	promo_close.visible = in_promo
	promo_close.text = {promote = "Later", absorb = "Cancel", info = "Close"}.get(panel_mode, "Close")
	draft_title.visible = camp
	var ids := _card_ids()
	if _core_pending():
		draft_title.text = "Choose a Core"
	elif not ids.is_empty():
		draft_title.text = "Add one to your reels"
	else:
		draft_title.text = "PREPARE YOUR ARMY"
	shop_close.visible = in_shop
	shop_btn.visible = camp
	fate_btn.visible = camp and not trials.is_empty()
	next_btn.visible = camp
	next_btn.text = "FIGHT!"
	next_btn.disabled = _core_pending()
	var next_boss := (level + 1) % BOSS_EVERY == 0
	judge_btn.visible = camp and started and not next_boss
	draft_info.visible = camp
	var kinds := {}
	for id in pool:
		kinds[id] = true
	var syn := []
	var lv := _syn_levels()
	for c in lv:
		if lv[c] > 0:
			syn.append("%s %s" % [Symbols.DATA[c].name, "I".repeat(lv[c])])
	draft_info.text = "Spins %d/%d   Next: %s   %s" % [camp_spins, SPIN_CAP,
		"BOSS" if next_boss and started else "wave",
		"(spin again = skip)" if not ids.is_empty() and not _core_pending() else
		"Synergy: " + ", ".join(syn) if not syn.is_empty() else "Synergy: 2+ of a category"]
	for i in 3:
		draft_btns[i].visible = camp and i < ids.size() and not reel_spinning
		if draft_btns[i].visible:
			var d: Dictionary = Items.info(ids[i]) if _core_pending() else Symbols.DATA[ids[i]]
			draft_btns[i].text = d.desc
		shop_btns[i].visible = in_shop and shop_tab == "shop" and i < shop.size()
		if shop_btns[i].visible:
			shop_btns[i].text = "SOLD" if shop[i] == "" else Items.ITEMS[shop[i]].desc
			shop_btns[i].disabled = shop[i] == "" or gold < _item_cost(shop[i])
	over_label.visible = state == "over"
	restart_btn.visible = state == "over"
	for c in settings_ui:
		c.visible = settings_open
	for bus in sfx.BUSES:
		var t: Button = settings_toggles[bus]
		t.set_pressed_no_signal(sfx.enabled[bus])
		t.text = "ON" if sfx.enabled[bus] else "OFF"


# ---------------------------------------------------------------- drawing

const UNIT_SCALE := 0.8   # sprite pixels -> screen (all Tiny Swords units share one pixel scale)
const TILE := 40.0        # on-screen size of a 64px terrain tile


# One animated frame of a horizontal sprite strip, centered at pos. phase desyncs identical sprites.
func _sprite(path: String, pos: Vector2, scale: float, flip := false, phase := 0, mod := Color.WHITE, frame := -1) -> void:
	var t := Art.tex(path)
	var fh := float(t.get_height())
	var fw := Art.frame_w(path)
	var f := frame if frame >= 0 else (int(anim_time * 10.0) + phase) % Art.frames(path)
	draw_set_transform(pos, 0.0, Vector2(-scale if flip else scale, scale))
	draw_texture_rect_region(t, Rect2(-fw / 2, -fh / 2, fw, fh), Rect2(f * fw, 0, fw, fh), mod)
	draw_set_transform(Vector2.ZERO)


# Frame of a one-shot attack animation with act_t seconds left.
func _act_frame(path: String, act_t: float) -> int:
	var n := Art.frames(path)
	return clampi(int((1.0 - act_t / ATTACK_ANIM) * n), 0, n - 1)


func _arrow(path: String, pos: Vector2, vel: Vector2) -> void:
	draw_set_transform(pos, vel.angle(), Vector2(0.6, 0.6))
	draw_texture(Art.tex(path), Vector2(-32, -32))
	draw_set_transform(Vector2.ZERO)


func _text(pos: Vector2, text: String, size: int, width: float, color := Color.WHITE) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 6, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


func _draw_symbol(rect: Rect2, id: String, tier := 0) -> void:
	var d: Dictionary = Symbols.info(id)
	var src := _symbol_src(id, rect)
	if not src.is_empty():
		draw_texture_rect_region(src[0], src[2], src[1], src[3])
	elif id != "blank":
		_text(Vector2(rect.position.x, rect.get_center().y + rect.size.y * 0.18), d.letter, int(rect.size.y * 0.5), rect.size.x, d.color)
	if id != "blank" and d.rarity != "common":
		draw_rect(rect.grow(-5), Symbols.RARITY_COLOR[d.rarity], false, 4.0)
	if tier > 0:
		_text(rect.position + Vector2(0, rect.size.y - 8), "Lv%d" % tier, 20, rect.size.x, Color("ffe14d"))
	elif id != "blank":
		var rk: int = ranks.get(id, 0)
		var pip := clampf(rect.size.x * 0.07, 4.0, 8.0)
		for k in rk:  # one pip per rank, top-left
			var c := rect.position + Vector2(pip * 1.6 + k * pip * 2.6, pip * 1.6)
			draw_circle(c, pip + 1.5, Color(0, 0, 0, 0.7))
			draw_circle(c, pip, Color("ffe14d"))
		if d.has("hatch"):
			_text(rect.position + Vector2(0, rect.size.y - 6), "%d/%d" % [lands.get(id, 0), d.hatch], int(clampf(rect.size.y * 0.22, 12, 22)), rect.size.x, Color("ffe14d"))


# [texture, source rect, dest rect] for picture symbols, [] for text/blank symbols.
func _symbol_src(id: String, rect: Rect2) -> Array:
	if Art.UNITS.has(id):  # crop the figure (96px around the frame center) from the first frame
		var t := Art.tex(Art.UNITS[id])
		var fh := float(t.get_height())
		return [t, Rect2(fh / 2 - 48, fh / 2 - 44, 96, 96), rect.grow(-4), Color.WHITE]
	if Art.POWER_ICONS.has(id):
		var t := Art.tex(Art.POWER_ICONS[id])
		return [t, Rect2(Vector2.ZERO, t.get_size()), rect.grow(-rect.size.x * 0.1), Color.WHITE]
	if Art.CATEGORY_ICONS.has(id):  # whole building, fitted into the cell
		var t := Art.tex(Art.CATEGORY_ICONS[id])
		var r := rect.grow(-rect.size.x * 0.06)
		var sz := t.get_size() * minf(r.size.x / t.get_size().x, r.size.y / t.get_size().y)
		return [t, Rect2(Vector2.ZERO, t.get_size()), Rect2(r.get_center() - sz / 2, sz), Color.WHITE]
	if id == "lamb":
		return [Art.tex(Art.LAMB), Rect2(24, 34, 80, 80), rect.grow(-4), Color.WHITE]
	return []


# Symbol cut off at the reel window edge (only the part inside clip is drawn).
func _draw_symbol_clipped(rect: Rect2, id: String, clip: Rect2) -> void:
	if clip.encloses(rect):
		_draw_symbol(rect, id)
		return
	var src := _symbol_src(id, rect)
	if src.is_empty():
		return  # text symbols only show once fully in the window
	var d: Rect2 = src[2]
	var s: Rect2 = src[1]
	var v := d.intersection(clip)
	if v.size.y <= 0:
		return
	var f0 := (v.position.y - d.position.y) / d.size.y
	var f1 := (v.end.y - d.position.y) / d.size.y
	draw_texture_rect_region(src[0], v, Rect2(s.position.x, s.position.y + s.size.y * f0, s.size.x, s.size.y * (f1 - f0)), src[3])


# Column i of the grid (3 cells tall). Strip index k sits at row (pos - k + 2).
func _draw_reel(i: int, col: Rect2) -> void:
	var strip: Array = reel_strips[i]
	var pos: float = _reel_pos(i) - nudge_off[i] if not strip.is_empty() else 0.0
	if reel_bounce[i] > 0:  # overshoot down then settle
		pos -= sin(PI * (1.0 - reel_bounce[i] / REEL_BOUNCE)) * 0.15
	var clip := col.grow(-4)
	if strip.is_empty():
		for r in 3:
			_draw_symbol(_reel_cell(r * 3 + i).grow(-2), reels[r * 3 + i])
	else:
		for k in range(floori(pos) - 1, floori(pos) + 4):
			if k >= 0 and k < strip.size():
				var y := (pos - k + 2) * REEL_CELL
				_draw_symbol_clipped(Rect2(col.position + Vector2(0, y), Vector2(REEL_CELL, REEL_CELL)).grow(-8), strip[k], clip)
		if reel_t[i] < 1.0:  # shade top/bottom for a curved-drum look
			draw_rect(Rect2(clip.position, Vector2(clip.size.x, 18)), Color(0.25, 0.15, 0.05, 0.35))
			draw_rect(Rect2(clip.position + Vector2(0, clip.size.y - 18), Vector2(clip.size.x, 18)), Color(0.25, 0.15, 0.05, 0.35))
	if held[i]:  # held reel: steel frame + lock label
		draw_rect(col.grow(-2), Color(0.55, 0.75, 1.0, 0.9), false, 6.0)
		var tag := Rect2(col.position + Vector2(col.size.x / 2 - 34, col.size.y - 30), Vector2(68, 26))
		draw_rect(tag, Color(0.15, 0.25, 0.45, 0.9))
		_text(tag.position + Vector2(0, 20), "HOLD", 18, tag.size.x, Color(0.8, 0.9, 1))
	if reel_glow > 0 and reel_t[i] >= 1.0:
		var a := (0.55 + 0.45 * sin(anim_time * 14.0)) * minf(1.0, reel_glow * 2.0)
		for r in 3:
			var c := r * 3 + i
			if hit_cells.has(c):
				var glow := Color(1, 0.85, 0.2, a)
				draw_rect(_reel_cell(c).grow(1), glow, false, 5.0)


# Item / core art fitted into rect (keeps aspect).
func _draw_icon(rect: Rect2, path: String) -> void:
	var t := Art.tex(path)
	var src := Rect2(Vector2.ZERO, t.get_size())
	if path == Art.LAMB:
		src = Rect2(24, 34, 80, 80)
	var k := minf(rect.size.x / src.size.x, rect.size.y / src.size.y)
	draw_texture_rect_region(t, Rect2(rect.get_center() - src.size * k / 2, src.size * k), src)


func _draw_unit(pos: Vector2, u: Dictionary, phase: int) -> void:
	var camp := state == "draft" or (trans > 0 and state == "wave")
	var s: float = UNIT_SCALE * (1.0 + 0.4 * (u.tier - 1) / (MAX_TIER - 1.0))
	if camp:
		s *= lerpf(1.0, CAMP_SCALE, trans / TRANS_TIME if state == "wave" else 1.0)
	var mod := Color.WHITE
	var born: float = u.get("born", 0.0)
	if born > 0:  # light beam from the sky, ring on the ground, pop-in with overshoot
		var k := 1.0 - born / BORN_TIME
		var col: Color = u.get("color", Color(1, 0.95, 0.7))
		var a := clampf(born / BORN_TIME * 1.6, 0.0, 1.0)
		var w := 56.0 * (1.0 - k * 0.7)
		draw_rect(Rect2(pos.x - w / 2, 0, w, pos.y + 20), Color(col, 0.45 * a))
		draw_rect(Rect2(pos.x - w / 6, 0, w / 3, pos.y + 20), Color(1, 1, 1, 0.8 * a))
		draw_set_transform(pos + Vector2(0, 26), 0.0, Vector2(1, 0.4))
		draw_arc(Vector2.ZERO, 20.0 + 110.0 * k, 0, TAU, 40, Color(col, 1.0 - k), 6.0)
		draw_circle(Vector2.ZERO, 40.0, Color(col, 0.35 * a))
		draw_set_transform(Vector2.ZERO)
		var t := clampf(k / 0.45, 0.0, 1.0)  # ease-out-back pop
		s *= 1.0 + 2.70158 * pow(t - 1.0, 3) + 1.70158 * pow(t - 1.0, 2)
		mod = Color(1, 1, 1).lerp(Color(3, 3, 3), clampf(born / BORN_TIME - 0.4, 0.0, 1.0))
	var lvl: float = u.get("lvl_t", 0.0)
	if lvl > 0:  # level up: golden rings spin outward, quick bounce
		var k := 1.0 - lvl / LEVEL_TIME
		for r in 3:
			var start := anim_time * 6.0 + r * TAU / 3
			draw_arc(pos, 30.0 + 50.0 * k + r * 6, start, start + 2.0, 16, Color(1, 0.85, 0.25, 1.0 - k), 4.0)
		s *= 1.0 + 0.35 * sin(PI * minf(1.0, k * 2.0))
		mod = Color(1, 1, 1).lerp(Color(2.2, 2.0, 1.2), 1.0 - k)
	if s <= 0.01:
		return
	if u.has("stats"):
		mod *= u.stats.tint
	var act: float = u.get("act_t", 0.0)
	if act > 0:
		var path: String = Art.UNIT_ATTACK[u.type]
		_sprite(path, pos, s, u.get("flip", false), 0, mod, _act_frame(path, act))
	elif camp or not u.get("moving", false):  # idle in the camp or holding position
		_sprite(Art.UNIT_IDLE[u.type], pos, s, u.get("flip", false), phase, mod)
	else:  # walking to a target
		_sprite(Art.UNITS[u.type], pos, s, u.get("flip", false), phase, mod)
	if u.tier > 1:
		_text(pos + Vector2(-30, -26), str(u.tier), 18, 60, Color("ffe14d"))
	if state == "draft" and _can_promote(u):  # tap to promote
		var b := pos + Vector2(0, -58 - 4 * sin(anim_time * 5.0))
		draw_circle(b, 15.0, Color("c05cff"))
		draw_arc(b, 15.0, 0, TAU, 20, Color(1, 0.9, 0.5), 2.0)
		_text(b + Vector2(-15, 8), "!", 22, 30)
	var frac: float = clampf(u.hp / _max_hp(u), 0, 1)
	draw_rect(Rect2(pos + Vector2(-20, 30), Vector2(40, 5)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(pos + Vector2(-20, 30), Vector2(40 * frac, 5)), Color("4ae08a"))
	if u.get("shield", 0.0) > 0:  # skill shield on top of the HP bar
		draw_rect(Rect2(pos + Vector2(-20, 29), Vector2(40 * clampf(u.shield / _max_hp(u), 0, 1), 3)), Color("8fd8ff"))
	if camp and u.tier < MAX_TIER and u.get("xp", 0.0) > 0:  # absorb progress to the next level
		draw_rect(Rect2(pos + Vector2(-20, 36), Vector2(40 * clampf(u.xp / Symbols.xp_need(u.type, u.tier), 0, 1), 3)), Color("ffe14d"))
	if u.tier >= MAX_TIER:  # awakened: golden halo
		draw_arc(pos + Vector2(0, -40), 12.0, 0, TAU, 20, Color(1, 0.85, 0.3, 0.8), 3.0)


func _draw_ground() -> void:
	var tint := _tint()
	draw_texture_rect(Art.tex(Art.WATER), Rect2(0, 0, W, LANE_BOTTOM), true, _theme().water * tint)
	var grass := Art.tex(_theme().tile)
	var cols := int((LANE_R - LANE_L) / TILE)
	var y := fmod(distance, TILE) - TILE
	while y < LANE_BOTTOM:
		for c in cols:
			var src_x := 0.0 if c == 0 else (128.0 if c == cols - 1 else 64.0)
			draw_texture_rect_region(grass, Rect2(LANE_L + c * TILE, y, TILE, TILE), Rect2(src_x, 64, 64, 64), tint)
		y += TILE
	for d in decor:
		if not d.top:
			_draw_decor(d)


func _draw() -> void:
	if state in ["draft", "title"]:
		_draw_camp(1.0, 0.0)
	else:
		_draw_ground()
		if trans > 0 and state == "wave":  # camp slides down and fades, revealing the path
			var k := _smooth(1.0 - trans / TRANS_TIME)
			_draw_camp(1.0 - k, k * LANE_BOTTOM * 0.8)

	var by_y := enemies.duplicate()  # draw back to front
	by_y.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for e in by_y:
		var big: bool = e.kind == "boss"
		var t := _etype(e.type)
		var s: float = UNIT_SCALE * t.get("scale", {brute = 1.3, runner = 0.85}.get(e.type, 1.0))
		var mod: Color = t.get("tint", Color.WHITE)
		if e.get("enraged", false):
			mod = Color(1.6, 0.5, 0.45)
		if e.slow_t > 0:
			mod *= Color(0.65, 0.85, 1.4)
		if big:  # boss aura on the ground
			draw_set_transform(e.pos + Vector2(0, e.r * 0.8), 0.0, Vector2(1, 0.4))
			draw_circle(Vector2.ZERO, e.r * 1.6, Color(1, 0.2, 0.1, 0.18 + 0.08 * sin(anim_time * 4.0)))
			draw_set_transform(Vector2.ZERO)
		if e.act_t > 0 and Art.ENEMY_ATTACK.has(e.type):
			var path: String = Art.ENEMY_ATTACK[e.type]
			_sprite(path, e.pos, s, e.flip, 0, mod, _act_frame(path, e.act_t))
		else:
			var moving: bool = battle_t < DEPLOY_TIME or e.has("dash_to")
			_sprite(Art.ENEMIES[e.type], e.pos, s, e.flip, e.id, mod, -1 if moving or state == "wave" else 0)
		var bw := 70.0 if big else 40.0  # HP bar
		var by: float = e.pos.y - e.r - (34 if big else 22)
		draw_rect(Rect2(e.pos.x - bw / 2, by, bw, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(e.pos.x - bw / 2, by, bw * clampf(e.hp / e.max_hp, 0, 1), 6), Color("e0403a"))
		if big:
			_text(Vector2(e.pos.x - 100, by - 6), t.name, 18, 200, Color(1, 0.85, 0.7))

	for sh in shells:  # landing warning fills in as the shell falls
		draw_circle(sh.pos, sh.r, Color(1, 0.2, 0.1, 0.15))
		draw_arc(sh.pos, sh.r * (1.0 - sh.t / SHELL_TIME), 0, TAU, 32, Color(1, 0.3, 0.1, 0.9), 3.0)
	for s in enemy_shots:
		_arrow(Art.ENEMY_ARROW, s.pos, s.vel)
	for p in projectiles:
		if p.blast > 0:
			draw_circle(p.pos, 7.0, p.color)
		else:
			_arrow(Art.ARROW, p.pos, p.vel)
	for fx in effects:
		if fx.get("boom", false):
			var n := Art.frames(Art.EXPLOSION)
			var f := clampi(int((1.0 - fx.t / fx.t0) * n), 0, n - 1)
			_sprite(Art.EXPLOSION, fx.pos, fx.r * 2.6 / 192.0, false, 0, Color.WHITE, f)
		else:  # thin ring that fades out
			var c: Color = fx.color
			c.a = clampf(fx.t * 5.0, 0.0, 0.9)
			draw_arc(fx.pos, fx.r, 0, TAU, 40, c, 5.0)
	var dragging := state == "draft" and drag_idx >= 0 and drag_idx < squad.size()
	if state == "draft":  # formation: 8 slots in two rows; twins of the dragged hero pulse gold
		var hover := _formation_at(drag_pos) if dragging else -1
		for k in SQUAD_CAP:
			var who: Array = squad.filter(func(o): return o.slot == k)
			var twin: bool = dragging and not who.is_empty() and who[0].slot != squad[drag_idx].slot and _can_merge(squad[drag_idx], who[0])
			var front := k < 4
			var col := Color(1, 0.45, 0.35) if front else Color(0.5, 0.75, 1.0)
			var a := 0.6 if who.is_empty() else 0.85
			if twin:
				col = Color(1, 0.85, 0.3)
				a = 0.55 + 0.45 * sin(anim_time * 8.0)
			elif k == hover:
				a = 1.0
			draw_set_transform(_camp_slot_pos(k) + Vector2(0, 30), 0.0, Vector2(1, 0.4))
			draw_circle(Vector2.ZERO, 38.0, Color(col, 0.12 if who.is_empty() else 0.2))
			draw_arc(Vector2.ZERO, 40.0, 0, TAU, 32, Color(col, a), 6.0 if twin or k == hover else 3.5)
			draw_set_transform(Vector2.ZERO)
		for r in 2:
			var y := _camp_slot_pos(r * 4).y + 20
			var x := _camp_slot_pos(0).x - 92
			draw_rect(Rect2(x - 38, y - 26, 80, 36), Color(0, 0, 0, 0.55))
			_text(Vector2(x - 38, y), ["FRONT", "BACK"][r], 21, 80, Color(1, 0.55, 0.45) if r == 0 else Color(0.6, 0.85, 1.0))
	for i in squad.size():
		if dragging and i == drag_idx:
			continue
		_draw_unit(_unit_pos(i), squad[i], i * 3)
	if dragging:
		_draw_unit(drag_pos, squad[drag_idx], 0)
	elif state == "draft" and not squad.is_empty():
		_text(Vector2(0, CAMP_CENTER.y + 132), "FRONT: melee hit harder, take less    BACK: safe from arrows, ranged +30%", 16, W, Color(1, 1, 1, 0.85))
		if squad.size() >= 2:
			_text(Vector2(0, CAMP_CENTER.y + 156), "Drag a hero onto another to ABSORB it.  Tap for skills", 20, W, Color(1, 0.92, 0.5, 0.6 + 0.4 * sin(anim_time * 3.0)))
		for i in squad.size():  # warn about heroes in the wrong row
			var u: Dictionary = squad[i]
			var melee: bool = _d(u).attack == "melee"
			if melee != _front(u):
				_text(_camp_pos(i) + Vector2(-60, 58), "can't reach!" if melee else "exposed!", 17, 120, Color(1, 0.45, 0.35))
	for p in sparks:
		var a: float = p.t / p.t0
		if p.get("coin", false):
			var cs := 22.0 * (0.5 + 0.5 * a)
			draw_texture_rect(Art.tex(Art.ICON_COIN), Rect2(p.pos - Vector2(cs, cs) / 2, Vector2(cs, cs)), false, Color(1, 1, 1, a))
			continue
		draw_rect(Rect2(p.pos - Vector2(3, 3) * a - Vector2(1, 1), Vector2(6, 6) * a + Vector2(2, 2)), Color(p.color, a))
	if state != "draft":
		for d in decor:
			if d.top:
				_draw_decor(d)
		_draw_atmosphere()
	if fade > 0:
		draw_rect(Rect2(0, 0, W, LANE_BOTTOM), Color(0, 0, 0, fade))

	_draw_ui()


# Drifting cloud shadows, embers (act 3), edge vignette, boss pulse, wave fade-in, act title.
# Stateless: positions come from distance / anim_time.
func _draw_atmosphere() -> void:
	var th := _theme()
	for k in Art.CLOUDS.size():
		var t := Art.tex(Art.CLOUDS[k])
		var y := fmod(distance * 0.55 + anim_time * 6.0 + k * 430.0, LANE_BOTTOM + 300.0) - 260.0
		var x: float = [-160.0, 260.0, 40.0][k]
		draw_texture_rect(t, Rect2(Vector2(x, y), t.get_size() * 1.1), false, Color(0, 0, 0, th.clouds))
	if th.get("embers", false):
		for k in 40:
			var speed := 40.0 + (k % 5) * 22.0
			var y := LANE_BOTTOM - fmod(anim_time * speed + k * 71.0, LANE_BOTTOM + 40.0)
			var x := fmod(k * 137.5 + sin(anim_time * 1.3 + k) * 24.0, W)
			var a := 0.5 + 0.5 * sin(anim_time * 7.0 + k)
			draw_circle(Vector2(x, y), 1.5 + (k % 3), Color(1.0, 0.55 + 0.3 * a, 0.15, 0.4 + 0.5 * a))
	var v: Color = th.vignette
	if judgement and state == "wave":
		v = Color(0.3, 0.0, 0.45, 0.4)
	if _boss_level() and state == "wave":
		v = Color(0.6, 0.0, 0.0, 0.35 + 0.15 * sin(anim_time * 3.0))
	if v.a > 0:
		_vignette(v)
	if wave_intro > 0 and state == "wave":
		_draw_path_preview(th)


# Shown as the fight starts: act title (first wave of an act), wave number and the enemies ahead.
func _draw_path_preview(th: Dictionary) -> void:
	var a := clampf(wave_intro / 0.6, 0.0, 1.0) * clampf((WAVE_INTRO - wave_intro) * 3.0, 0.0, 1.0)
	var act_start := (level - 1) % BOSS_EVERY == 0
	var mid := LANE_BOTTOM * 0.46
	draw_rect(Rect2(0, mid - (110 if act_start else 50), W, 250 if act_start else 190), Color(0, 0, 0, 0.5 * a))
	var y := mid
	if act_start:
		_text(Vector2(0, mid - 40), "ACT %d" % (_act_index() + 1), 60, W, Color(1, 0.88, 0.3, a))
		_text(Vector2(0, mid), th.name.to_upper(), 28, W, Color(1, 1, 1, a))
		y = mid + 40
	var title := "BOSS WAVE" if _boss_level() else ("JUDGEMENT  WAVE %d" if judgement else "WAVE %d") % ((level - 1) % BOSS_EVERY + 1)
	_text(Vector2(0, y), title, 30, W, Color(1, 0.4, 0.35, a) if _boss_level() or judgement else Color(1, 1, 1, a))
	var lines := []
	for e in enemies:
		var t := _etype(e.type)
		var line: String = ""
		if e.kind == "boss":
			line = "%s: %s" % [t.name.to_upper(), t.desc]
		elif t.from == level:
			line = "NEW %s: %s" % [t.name, t.desc]
		if line != "" and not lines.has(line):
			lines.append(line)
	lines.append("%d enemies vs your %d heroes" % [enemies.size(), squad.size()])
	for k in lines.size():
		_text(Vector2(0, y + 40 + k * 28), lines[k], 20, W, Color(1, 0.88, 0.3, a) if k < lines.size() - 1 else Color(1, 1, 1, a))


# The camp: home ground for the prepare phase, with the summoning circle in the middle.
# oy slides it down (camp -> path transition), alpha fades it out.
func _draw_camp(alpha: float, oy: float) -> void:
	var m := Color(1, 1, 1, alpha)
	var grass := Art.tex(THEMES[0].tile)
	var y := -TILE + fmod(oy, TILE)
	while y < LANE_BOTTOM:
		for c in int(W / TILE) + 1:
			draw_texture_rect_region(grass, Rect2(c * TILE, y, TILE, TILE), Rect2(64, 64, 64, 64), m)
		y += TILE
	for b in Art.CAMP_BUILDINGS:
		var t := Art.tex(b[0])
		var size: Vector2 = t.get_size() * b[2]
		draw_texture_rect(t, Rect2(b[1] + Vector2(0, oy) - size / 2, size), false, m)
	for p in [Vector2(30, 180), Vector2(690, 170), Vector2(20, 470), Vector2(700, 480), Vector2(40, 820), Vector2(680, 830)]:
		_sprite(Art.TREES[int(p.x) % 4], p + Vector2(0, oy), 0.6, false, int(p.y), m)
	# summoning circle: dark ground, two rotating rune rings, glowing dots
	var c := CAMP_CENTER + Vector2(0, 20 + oy)
	draw_set_transform(c, 0.0, Vector2(1, 0.42))
	draw_circle(Vector2.ZERO, 250.0, Color(0.15, 0.1, 0.05, 0.28 * alpha))
	var glow := 0.6 + 0.4 * sin(anim_time * 2.0)
	draw_arc(Vector2.ZERO, 238.0, 0, TAU, 64, Color(1, 0.85, 0.35, 0.7 * alpha * glow), 5.0)
	for r in 2:
		var rad := 200.0 - r * 40.0
		var turn := anim_time * (0.4 if r == 0 else -0.6)
		for k in 12:
			var a0 := turn + k * TAU / 12
			draw_arc(Vector2.ZERO, rad, a0, a0 + 0.3, 6, Color(1, 0.85, 0.35, 0.6 * alpha), 3.0)
			draw_circle(Vector2(cos(a0 + 0.4), sin(a0 + 0.4)) * rad, 5.0, Color(1, 0.95, 0.6, 0.8 * alpha * glow))
	draw_set_transform(Vector2.ZERO)
	for p in [Vector2(165, 545), Vector2(555, 545)]:  # torches by the circle
		_sprite(Art.FIRES[0], p + Vector2(0, oy), 1.0, false, int(p.x), m)
	for k in 26:  # fireflies
		var fx := fmod(k * 173.0 + sin(anim_time * 0.7 + k) * 40.0, W)
		var fy := fmod(k * 97.0 + cos(anim_time * 0.5 + k * 2.0) * 30.0, LANE_BOTTOM) + oy
		var fa := (0.5 + 0.5 * sin(anim_time * 3.0 + k)) * alpha
		draw_circle(Vector2(fx, fy), 2.5, Color(1, 1, 0.6, 0.7 * fa))
		draw_circle(Vector2(fx, fy), 6.0, Color(1, 1, 0.5, 0.15 * fa))
	_vignette(Color(0, 0, 0, 0.35 * alpha))


# Soft dark edges: four gradient bands fading toward the middle of the lane.
func _vignette(c: Color) -> void:
	var clear := Color(c, 0.0)
	var d := 150.0
	var h := LANE_BOTTOM
	for band in [[Vector2(0, 0), Vector2(W, 0), Vector2(W, d), Vector2(0, d), true],
			[Vector2(0, h - d), Vector2(W, h - d), Vector2(W, h), Vector2(0, h), false]]:
		var top: bool = band[4]
		draw_polygon(PackedVector2Array([band[0], band[1], band[2], band[3]]),
			PackedColorArray([c, c, clear, clear] if top else [clear, clear, c, c]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(d, 0), Vector2(d, h), Vector2(0, h)]),
		PackedColorArray([c, clear, clear, c]))
	draw_polygon(PackedVector2Array([Vector2(W - d, 0), Vector2(W, 0), Vector2(W, h), Vector2(W - d, h)]),
		PackedColorArray([clear, c, c, clear]))


# ---------------------------------------------------------------- UI art

# 9-slice draw of a packed UI texture; s scales the borders (pack art is drawn at 2x).
# Purple crystal (meta currency).
func _gem(c: Vector2, r: float, col := Color("a050e8")) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.2)])
	draw_colored_polygon(pts, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, -r * 0.1)]), col.lightened(0.5))
	pts.append(pts[0])
	draw_polyline(pts, Color("3a1060"), 2.5)


# Title: game name over the camp, best run, crystals; upgrade tree panel on top when open.
func _draw_title() -> void:
	draw_rect(Rect2(0, 0, W, LANE_BOTTOM), Color(0, 0, 0, 0.25))
	var bob := 6.0 * sin(anim_time * 2.0)
	draw_string_outline(font, Vector2(0, 330 + bob), "SWORD SLOTS", HORIZONTAL_ALIGNMENT_CENTER, W, 86, 18, Color("3b1a08"))
	draw_string(font, Vector2(0, 330 + bob), "SWORD SLOTS", HORIZONTAL_ALIGNMENT_CENTER, W, 86, Color("ffe14d"))
	_text(Vector2(0, 390), "Spin. Summon. Survive.", 28, W, Color(1, 1, 1))
	var sub := "Best: Act %d Wave %d   Wins: %d" % [int((maxi(meta.best, 1) - 1) / 5.0) + 1, (maxi(meta.best, 1) - 1) % 5 + 1, meta.wins] if meta.best > 0 else "Your first run awaits"
	_text(Vector2(0, 440), sub, 22, W, Color(1, 0.92, 0.6))
	if not meta_open:
		_button_art(play_btn, "red")
		_button_art(upg_btn, "blue", 0.45)
		_button_art(hard_btn, "red" if meta.hard else "blue", 0.35)
		_button_art(stage_btn, "red" if meta.stage > 0 else "blue", 0.35)
		var n := Symbols.all_heroes().filter(func(h): return meta.rarity_unlocked(Symbols.DATA[h].rarity)).size()
		var next := ""
		for rar in ["rare", "epic", "legendary"]:
			if not meta.rarity_unlocked(rar):
				next = "   (%s heroes: reach wave %d)" % [rar, Meta.UNLOCK_WAVE[rar]]
				break
		_text(Vector2(0, 556 - 10), "Heroes unlocked %d/%d%s" % [n, Symbols.all_heroes().size(), next], 18, W, Color(0.85, 1, 0.85))
		return
	draw_rect(Rect2(0, 0, W, screen_h), Color(0, 0, 0, 0.6))
	_nine("paper", META_PANEL, 0.6)
	_nine("ribbon_purple", META_RIBBON, 0.7)
	_text(META_RIBBON.position + Vector2(0, 48), "UPGRADES", 32, META_RIBBON.size.x)
	_gem(META_PANEL.position + Vector2(META_PANEL.size.x / 2 - 60, 66), 14.0)
	draw_string(font, META_PANEL.position + Vector2(META_PANEL.size.x / 2 - 40, 76), "%d crystals" % meta.crystals, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, PAPER_TEXT)
	for k in Meta.UPGRADES.size():
		var u: Dictionary = Meta.UPGRADES[k]
		var r := _meta_row(k)
		draw_rect(r.grow(-2), Color(0.55, 0.4, 0.25, 0.18))
		draw_string(font, r.position + Vector2(14, 30), u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, PAPER_TEXT)
		draw_string(font, r.position + Vector2(14, 60), u.desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 190, 17, Color(0.35, 0.25, 0.15))
		for i in u.cost.size():  # level pips
			var c := r.position + Vector2(r.size.x - 172 - (u.cost.size() - 1 - i) * 18, 22)
			draw_circle(c, 6.0, Color("a050e8") if i < meta.lvl(u.id) else Color(0.6, 0.5, 0.4))
		var b: Button = meta_btns[k]
		_button_art(b, "blue", 0.33)
		if meta.cost(u.id) >= 0:
			_gem(b.position + Vector2(36, 27), 11.0)
	_button_art(meta_close, "red", 0.4)


# Marquee bulbs around the reel window: slow blink idle, chase while spinning, all flash on a win.
func _draw_bulbs() -> void:
	var r := REEL_WINDOW.grow(-7)
	var pts := []
	var step := 28.0
	for k in int(r.size.x / step):
		pts.append(r.position + Vector2(k * step + step / 2, 0))
	for k in int(r.size.y / step):
		pts.append(Vector2(r.end.x, r.position.y + k * step + step / 2))
	for k in int(r.size.x / step):
		pts.append(Vector2(r.end.x - k * step - step / 2, r.end.y))
	for k in int(r.size.y / step):
		pts.append(Vector2(r.position.x, r.end.y - k * step - step / 2))
	for k in pts.size():
		var on: bool
		var col := Color(1, 0.85, 0.3)
		if win_flash > 0:
			on = int(anim_time * 12.0) % 2 == k % 2
			col = Color(1, 1, 0.85) if on else Color(1, 0.6, 0.1)
			on = true
		elif reel_spinning:
			on = (k + int(anim_time * 24.0)) % 4 == 0
		elif awaiting:
			on = (k + int(anim_time * 8.0)) % 3 == 0
		else:
			on = (k + int(anim_time * 1.5)) % 2 == 0
		var p: Vector2 = pts[k]
		if on:
			draw_circle(p, 8.0, Color(col, 0.25))
		draw_circle(p, 4.5, col if on else Color(0.35, 0.22, 0.1))


# Slot-machine lever beside the reels. Knob slides down its track as it is pulled.
func _draw_lever() -> void:
	var r := LEVER_RECT
	var live := state == "draft" and (_can_spin() or reel_spinning or awaiting)
	var x := r.get_center().x
	var top := r.position.y + 30
	var bottom := r.end.y - 50
	draw_rect(Rect2(x - 7, top, 14, bottom - top), Color(0.18, 0.12, 0.08))  # track slot
	draw_rect(Rect2(x - 3, top, 6, bottom - top), Color(0.08, 0.05, 0.03))
	var y := lerpf(top, bottom, clampf(_lever_amount(), -0.2, 1.0))
	var base := Rect2(x - 30, r.end.y - 52, 60, 44)
	draw_line(Vector2(x, base.position.y + 10), Vector2(x, y), Color(0.55, 0.55, 0.6), 10.0)  # shaft
	draw_line(Vector2(x - 2, base.position.y + 10), Vector2(x - 2, y), Color(0.85, 0.85, 0.9), 3.0)
	draw_rect(base, Color(0.3, 0.3, 0.35))
	draw_rect(base.grow(-4), Color(0.45, 0.45, 0.5))
	draw_rect(Rect2(base.position + Vector2(4, 4), Vector2(base.size.x - 8, 6)), Color(0.7, 0.7, 0.75))
	var knob := Color("e0302a") if live else Color(0.45, 0.35, 0.35)
	if live and not reel_spinning and lever_drag < 0 and lever_t >= 1.0:  # idle glow invites a pull
		draw_circle(Vector2(x, y), 30.0 + 3.0 * sin(anim_time * 4.0), Color(1, 0.8, 0.3, 0.25))
	draw_circle(Vector2(x, y + 3), 23.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(x, y), 22.0, knob)
	draw_circle(Vector2(x, y), 22.0, knob.darkened(0.4), false, 3.0)
	draw_circle(Vector2(x - 7, y - 8), 7.0, Color(1, 1, 1, 0.55))
	if live and not reel_spinning and not awaiting:
		_text(Vector2(r.position.x - 10, r.end.y - 2), "PULL", 18, r.size.x + 20, Color(1, 0.92, 0.5))


# Win banner: rotating sunburst + popping title over the camp, bigger for bigger wins.
func _draw_win_banner() -> void:
	var b := win_banner
	var k: float = 1.0 - b.t / b.t0
	var a := clampf(b.t / 0.35, 0.0, 1.0)
	var c := Vector2(W / 2, REEL_POS.y - (250.0 if b.tier == 3 else 170.0))
	var size: float = [0, 46, 60, 80][b.tier]
	var rays: int = [0, 10, 14, 20][b.tier]
	var reach: float = (160.0 + 60.0 * b.tier) * minf(1.0, k * 6.0)
	for i in rays:
		var ang := anim_time * 0.8 + i * TAU / rays
		var p1 := c + Vector2(cos(ang - 0.09), sin(ang - 0.09)) * reach
		var p2 := c + Vector2(cos(ang + 0.09), sin(ang + 0.09)) * reach
		draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(1, 0.85, 0.3, 0.22 * a))
	var t := clampf(k / 0.18, 0.0, 1.0)
	var pop := 1.0 + 2.70158 * pow(t - 1.0, 3) + 1.70158 * pow(t - 1.0, 2)  # ease-out-back
	pop *= 1.0 + 0.05 * sin(anim_time * 10.0)
	draw_set_transform(c, sin(anim_time * 3.0) * 0.04, Vector2(pop, pop))
	var col := Color("ffe14d") if b.tier < 3 else Color.from_hsv(fmod(anim_time * 0.6, 1.0), 0.45, 1.0)
	draw_string_outline(font, Vector2(-W / 2, size * 0.35), b.text, HORIZONTAL_ALIGNMENT_CENTER, W, size, 14, Color(0.25, 0.1, 0.0, a))
	draw_string(font, Vector2(-W / 2, size * 0.35), b.text, HORIZONTAL_ALIGNMENT_CENTER, W, size, Color(col, a))
	if b.sub != "":
		draw_string_outline(font, Vector2(-W / 2, size * 0.35 + 40), b.sub, HORIZONTAL_ALIGNMENT_CENTER, W, 28, 10, Color(0, 0, 0, a))
		draw_string(font, Vector2(-W / 2, size * 0.35 + 40), b.sub, HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)


func _nine(name: String, rect: Rect2, s := 0.5, mod := Color.WHITE) -> void:
	var t := Art.ui(name)
	var m: Array = Art.NINE[name]
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var sx := [0.0, float(m[0]), tw - m[2], tw]
	var sy := [0.0, float(m[1]), th - m[3], th]
	var dx := [rect.position.x, rect.position.x + m[0] * s, rect.end.x - m[2] * s, rect.end.x]
	var dy := [rect.position.y, rect.position.y + m[1] * s, rect.end.y - m[3] * s, rect.end.y]
	for i in 3:
		for j in 3:
			var src := Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j])
			var dst := Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j])
			if src.size.x > 0 and src.size.y > 0 and dst.size.x > 0 and dst.size.y > 0:
				draw_texture_rect_region(t, dst, src, mod)


func _button_art(b: Button, color: String, s := 0.5) -> void:
	if not b.visible:
		return
	var down := b.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	var mod := Color(0.55, 0.55, 0.55) if b.disabled else (Color(1.1, 1.1, 1.1) if b.is_hovered() else Color.WHITE)
	_nine("btn_%s%s" % [color, "_pressed" if down else ""], Rect2(b.position, b.size), s, mod)


func _card_rect(i: int) -> Rect2:
	return Rect2(30 + i * 222, 266, 216, 128)


func _draw_ui() -> void:
	# Top HUD: wave ribbon, gold, squad count, wave progress
	_nine("ribbon_red" if judgement and state == "wave" else "ribbon_blue", WAVE_RIBBON, 0.62)
	var pb := 10.0 * sin(PI * purse_bump)
	if state == "title":
		_gem(Vector2(38, 40), 22.0)
	else:
		draw_texture_rect(Art.tex(Art.ICON_COIN), Rect2(12 - pb / 2, 14 - pb / 2, 52 + pb, 52 + pb), false)
	draw_texture_rect(Art.tex(Art.ICON_SWORD), Rect2(656, 14, 52, 52), false)
	if state == "wave":
		_nine("bar", BAR_RECT, 0.67)
		var inner := Rect2(BAR_RECT.position + Vector2(14, 10), BAR_RECT.size - Vector2(28, 20))
		var left := 0.0
		for e in enemies:
			left += maxf(e.hp, 0.0)
		var done := 1.0 - (left / wave_hp if wave_hp > 0 else 0.0)  # fills as the enemy squad falls
		draw_texture_rect(Art.tex(Art.BAR_FILL), Rect2(inner.position, Vector2(inner.size.x * clampf(done, 0, 1), inner.size.y)), false)
	if msg_label.visible:
		_nine("ribbon_yellow", Rect2(MSG_RIBBON.position.x, msg_label.position.y, MSG_RIBBON.size.x, MSG_RIBBON.size.y), 0.8)

	# Bottom panel: wood table, paper reel window, buttons, squad slots
	_nine("wood", Rect2(-8, LANE_BOTTOM - 6, W + 16, screen_h - LANE_BOTTOM + 30), 0.5)
	_nine("paper_special", REEL_WINDOW, 0.45)
	_draw_bulbs()
	for i in Symbols.CELLS:
		_nine("paper", _reel_cell(i).grow(2), 0.25)
	for i in 3:
		_draw_reel(i, Rect2(REEL_POS + Vector2(i * REEL_CELL, 0), Vector2(REEL_CELL, REEL_CELL * 3)))
	if awaiting:  # pulsing chevrons over the reels: tap to nudge that reel down
		for i in 3:
			var c := REEL_POS + Vector2((i + 0.5) * REEL_CELL, 6 + 5 * sin(anim_time * 8.0))
			var tri := PackedVector2Array([c + Vector2(-24, -14), c + Vector2(24, -14), c + Vector2(0, 14)])
			draw_colored_polygon(tri, Color(1, 0.8, 0.15))
			tri.append(tri[0])
			draw_polyline(tri, Color(0.3, 0.15, 0.0), 3.0)
	for f in cell_flash:  # winning cell pops: white flash + expanding ring
		var r := _reel_cell(f.c)
		var k: float = 1.0 - f.t / 0.5
		draw_rect(r, Color(1, 1, 1, 0.45 * (1.0 - k)))
		draw_rect(r.grow(4 + 14 * k), Color(f.color.lightened(0.4), 1.0 - k), false, 4.0)
	if reel_spinning and reel_tease and reel_t[2] < 1.0:  # anticipation: last reel glows
		var col2 := Rect2(REEL_POS + Vector2(2 * REEL_CELL, 0), Vector2(REEL_CELL, REEL_CELL * 3))
		draw_rect(col2.grow(2), Color(1, 0.85, 0.2, 0.5 + 0.5 * sin(anim_time * 20.0)), false, 6.0)
	for l in links:  # payline stroke (draws itself across), or combo link with a + badge
		var a := _reel_cell(l.a).get_center()
		var c := _reel_cell(l.b).get_center()
		var col := Color(1, 0.88, 0.3, minf(1.0, l.t * 2.0))
		if l.get("line", false):
			var e: Vector2 = a.lerp(c, minf(1.0, (1.0 - l.t) * 5.0))
			draw_line(a - (c - a).normalized() * 18, e, Color(1, 0.7, 0.1, col.a * 0.45), 18.0)
			draw_line(a - (c - a).normalized() * 18, e, Color(1, 0.97, 0.7, col.a), 6.0)
			continue
		draw_line(a, c, col, 6.0)
		if not l.get("line", false):
			draw_circle((a + c) / 2, 12.0, col)
			_text((a + c) / 2 + Vector2(-20, 7), "+", 20, 40, Color("6a3a10"))
	for p in popups:  # payout numbers float up and fade
		var k: float = 1.0 - p.t / 1.3
		var col: Color = p.color.lightened(0.35)
		col.a = minf(1.0, p.t * 2.0)
		var lines: PackedStringArray = p.text.split("\n")
		for j in lines.size():
			var pos: Vector2 = p.pos + Vector2(-85, -k * 60 + j * 22)
			draw_string_outline(font, pos, lines[j], HORIZONTAL_ALIGNMENT_CENTER, 170, 20, 8, Color(0, 0, 0, col.a))
			draw_string(font, pos, lines[j], HORIZONTAL_ALIGNMENT_CENTER, 170, 20, col)
	_draw_lever()
	_button_art(spin_btn, "red", 0.4)
	if spin_btn.visible and spin_btn.text.begins_with("      "):  # coin icon on the price plate
		draw_texture_rect(Art.tex(Art.ICON_COIN), Rect2(SPIN_RECT.position + Vector2(58, 18), Vector2(48, 48)), false)
	if state == "draft":  # reel trick charges
		for k in 2:
			var n: int = [nudges, holds][k]
			var r := Rect2(TRICK_POS + Vector2(k * 134, 0), Vector2(128, 40))
			var on: bool = n > 0 and (awaiting if k == 0 else not awaiting and not reel_spinning)
			_nine("paper", r, 0.2, Color.WHITE if n > 0 else Color(0.6, 0.6, 0.6))
			if on:
				draw_rect(r.grow(-2), Color(1, 0.85, 0.25, 0.6 + 0.4 * sin(anim_time * 6.0)), false, 3.0)
			draw_string(font, r.position + Vector2(0, 28), "%s x%d" % [["NUDGE", "HOLD"][k], n], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, PAPER_TEXT)
	var owned: Array = cores + items
	for i in owned.size():
		var r := Rect2(ITEMS_POS + Vector2((i % 6) * 44, int(i / 6.0) * 44), Vector2(40, 40))
		_nine("paper", r, 0.15)
		_draw_icon(r.grow(-5), Items.info(owned[i]).icon)

	# Draft / game over overlays
	if state == "over":
		draw_rect(Rect2(0, 0, W, LANE_BOTTOM), Color(0, 0, 0, 0.55))
	if state == "draft":
		if draft_title.visible:
			_nine("ribbon_yellow", DRAFT_RIBBON, 0.8)
		var ids := _card_ids()
		for i in 3:
			if not draft_btns[i].visible:
				continue
			var card := _card_rect(i)
			var hover: bool = draft_btns[i].is_hovered()
			_nine("paper", card, 0.3, Color(1.1, 1.1, 1.0) if hover else Color.WHITE)
			var icon := Rect2(card.position + Vector2(8, 26), Vector2(58, 58))
			if _core_pending():
				_draw_icon(icon, Items.CORES[ids[i]].icon)
				draw_rect(card.grow(-3), Color("c05cff"), false, 3.0)
				draw_string(font, card.position + Vector2(10, 120), "CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7a2aa0"))
				draw_string(font, card.position + Vector2(70, 22), Items.CORES[ids[i]].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, PAPER_TEXT)
			else:
				var d: Dictionary = Symbols.DATA[ids[i]]
				_draw_symbol(icon, ids[i])
				if d.rarity != "common":
					draw_rect(card.grow(-3), Symbols.RARITY_COLOR[d.rarity], false, 3.0)
				draw_string(font, card.position + Vector2(70, 22), d.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, PAPER_TEXT)
				var n := pool.count(ids[i])
				draw_string(font, card.position + Vector2(10, 120), "x%d" % n if n > 0 else "New!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PAPER_TEXT)
		_button_art(next_btn, "blue", 0.4)
		_button_art(judge_btn, "red", 0.33)
		if shop_btn.visible:
			_button_art(shop_btn, "blue", 0.4)
			draw_texture_rect(Art.tex(Art.ICON_COIN), Rect2(SHOP_BTN_RECT.position + Vector2(6, 12), Vector2(44, 44)), false)
			var affordable := shop.filter(func(id): return id != "" and gold >= _item_cost(id)).size()
			if affordable > 0:  # badge: how many items you can buy now
				var c := SHOP_BTN_RECT.position + Vector2(SHOP_BTN_RECT.size.x - 6, 6)
				draw_circle(c, 15.0, Color("d0303a"))
				_text(c + Vector2(-15, 7), str(affordable), 18, 30)
	if fate_btn.visible:
		_button_art(fate_btn, "red", 0.4)
		_gem(FATE_BTN_RECT.position + Vector2(28, FATE_BTN_RECT.size.y / 2), 16.0, Color("c05cff"))
		if not fate_spins.is_empty():  # badge: FATE SPINs ready
			var c := FATE_BTN_RECT.position + Vector2(FATE_BTN_RECT.size.x - 6, 6)
			draw_circle(c, 15.0, Color("c05cff"))
			_text(c + Vector2(-15, 7), str(fate_spins.size()), 18, 30)
	if state == "draft" and shop_open and shop_tab == "fate":
		_draw_fate()
	elif state == "draft" and shop_open:
		draw_rect(Rect2(0, 0, W, screen_h), Color(0, 0, 0, 0.6))
		_nine("paper", SHOP_PANEL, 0.6)
		_nine("ribbon_blue", SHOP_RIBBON, 0.7)
		_text(SHOP_RIBBON.position + Vector2(0, 46), "SHOP", 32, SHOP_RIBBON.size.x)
		var note := "Items last the whole run" if not shop.is_empty() else "The shop opens after your first wave"
		draw_string(font, Vector2(SHOP_PANEL.position.x, SHOP_PANEL.position.y + 250), note, HORIZONTAL_ALIGNMENT_CENTER, SHOP_PANEL.size.x, 20, PAPER_TEXT)
		for i in shop.size():
			var r := _shop_rect(i)
			_nine("paper", r, 0.3, Color(0.7, 0.7, 0.7) if shop_btns[i].disabled else Color.WHITE)
			if shop[i] == "":
				continue
			var it: Dictionary = Items.ITEMS[shop[i]]
			draw_string(font, r.position + Vector2(0, 24), it.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, PAPER_TEXT)
			_draw_icon(Rect2(r.position + Vector2(8, 36), Vector2(48, 48)), it.icon)
			draw_texture_rect(Art.tex(Art.ICON_COIN), Rect2(r.position + Vector2(6, 92), Vector2(24, 24)), false)
			draw_string(font, r.position + Vector2(30, 111), str(_item_cost(shop[i])), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, PAPER_TEXT)
		_button_art(shop_close, "blue", 0.4)
	for c in fly_coins:
		if c.delay > 0:
			continue
		var t: float = c.t
		var to := Vector2(38, 40)
		var mid: Vector2 = c.from.lerp(to, 0.3) + Vector2(-80, -260)
		var p: Vector2 = c.from.lerp(mid, t).lerp(mid.lerp(to, t), t)  # quadratic bezier
		var s := 30.0 * (1.0 - 0.4 * t)
		draw_texture_rect(Art.tex(Art.ICON_COIN), Rect2(p - Vector2(s, s) / 2, Vector2(s, s)), false)
	if not win_banner.is_empty():
		_draw_win_banner()
	if state == "draft" and not shop_open and promote_unit == null:
		var hy := NEXT_RECT.position.y - 14
		var hint := ""
		if awaiting:
			hint = "Tap a reel to NUDGE it, or COLLECT"
		elif holds > 0 and not reel_spinning and reels.any(func(id): return id != "blank"):
			hint = "Tap a reel to HOLD it for the next spin"
		if hint != "":
			_text(Vector2(170, hy), hint, 18, 370, Color(1, 0.92, 0.5))
		if not next_roll.is_empty() and not reel_spinning:
			var gx := W / 2 - 20
			_text(Vector2(gx - 112, hy + 60), "NEXT SPIN", 18, 108, Color("8fd0ff"))
			for c in Symbols.CELLS:
				var r := Rect2(Vector2(gx, hy + 6) + Vector2(c % 3, int(c / 3.0)) * 29, Vector2(28, 28))
				draw_rect(r, Color(0.95, 0.9, 0.75, 0.9))
				if held[c % 3]:
					draw_rect(r, Color(0.55, 0.75, 1.0, 0.6))
				else:
					_draw_symbol(r, next_roll[c])
	if state == "draft" and promote_unit != null and panel_mode != "promote":
		_draw_hero_panel()
	elif state == "draft" and promote_unit != null:
		var u: Dictionary = promote_unit
		draw_rect(Rect2(0, 0, W, screen_h), Color(0, 0, 0, 0.6))
		_nine("paper", SHOP_PANEL, 0.6)
		_nine("ribbon_purple", SHOP_RIBBON, 0.7)
		_text(SHOP_RIBBON.position + Vector2(0, 46), "PROMOTE", 32, SHOP_RIBBON.size.x)
		draw_string(font, SHOP_PANEL.position + Vector2(0, 58), "Choose a class for your Lv%d %s" % [u.tier, Symbols.DATA[u.type].name],
			HORIZONTAL_ALIGNMENT_CENTER, SHOP_PANEL.size.x, 20, PAPER_TEXT)
		for k in 2:
			var c: Dictionary = Symbols.CLASSES[u.type][k]
			var r := _promo_rect(k)
			_nine("banner", r, 0.4, Color(1.08, 1.08, 1.0) if promo_btns[k].is_hovered() else Color.WHITE)
			_sprite(Art.UNIT_IDLE[u.type], r.position + Vector2(r.size.x / 2, 96), 1.3, false, k, c.tint)
			draw_string(font, r.position + Vector2(0, 176), c.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, PAPER_TEXT)
			draw_multiline_string(font, r.position + Vector2(28, 204), c.desc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 56, 17, 3, PAPER_TEXT)
		_button_art(promo_close, "blue", 0.4)
	if state == "title":
		_draw_title()
	if state == "over":
		_nine("banner", OVER_RECT, 0.6)
		_button_art(restart_btn, "red")

	if settings_open:
		draw_rect(Rect2(0, 0, W, screen_h), Color(0, 0, 0, 0.6))
		_nine("paper", SETTINGS_RECT, 0.6)
		_nine("ribbon_blue", SETTINGS_RIBBON, 0.7)
		for bus in sfx.BUSES:
			var t: Button = settings_toggles[bus]
			_nine("btn_blue" if t.button_pressed else "btn_red", Rect2(t.position, t.size), 0.33)
		_button_art(settings_close, "red")



# Fate panel: the three trials (C/B/A) with streak progress, rule, waves left and stone reward.
func _draw_fate() -> void:
	draw_rect(Rect2(0, 0, W, screen_h), Color(0, 0, 0, 0.6))
	_nine("paper", SHOP_PANEL, 0.6)
	_nine("ribbon_purple", SHOP_RIBBON, 0.7)
	_text(SHOP_RIBBON.position + Vector2(0, 46), "FATE STONES", 30, SHOP_RIBBON.size.x)
	for i in trials.size():
		var t: Dictionary = trials[i]
		var r := Rect2(SHOP_PANEL.position.x + 22 + i * 202, SHOP_PANEL.position.y + 66, 194, 250)
		var col: Color = Fate.COLOR[t.grade]
		_nine("paper", r, 0.3)
		draw_circle(r.position + Vector2(r.size.x - 26, 26), 18.0, col)
		_text(r.position + Vector2(r.size.x - 44, 34), t.grade, 22, 36)
		_gem(r.position + Vector2(r.size.x / 2, 58), 22.0, col.lightened(0.3))
		draw_string(font, r.position + Vector2(0, 104), t.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, PAPER_TEXT)
		var bar := Rect2(r.position + Vector2(24, 116), Vector2(r.size.x - 48, 8))
		draw_rect(bar, Color(0, 0, 0, 0.2))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * t.progress / t.need, bar.size.y)), col)
		draw_string(font, r.position + Vector2(24, 146), "%d/%d" % [t.progress, t.need], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col.darkened(0.2))
		draw_multiline_string(font, r.position + Vector2(16, 170), "Win %d waves in a row\n%s" % [t.need, t.rule],
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 15, 4, PAPER_TEXT)
		draw_string(font, r.position + Vector2(0, r.size.y - 14), "FATE SPIN %s   %d waves left" % [t.grade, t.left],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color("7a5a30"))
	var odds := "Each stone = a FATE SPIN: a sure hero line, legendary heroes up to x%.0f as likely" % Symbols.fate_mult("legendary", Fate.POWER.A)
	if not fate_spins.is_empty():
		odds = "%d FATE SPIN%s ready - pull the lever!" % [fate_spins.size(), "S" if fate_spins.size() > 1 else ""]
	draw_string(font, Vector2(SHOP_PANEL.position.x, SHOP_PANEL.position.y + 346), odds, HORIZONTAL_ALIGNMENT_CENTER, SHOP_PANEL.size.x, 17, PAPER_TEXT)
	_button_art(shop_close, "blue", 0.4)



# Signature skill (Symbols.SKILLS). Awakened (max level) heroes cast at x1.5, Focus adds more.
func _cast_skill(u: Dictionary, ot: float) -> void:
	var sk: Dictionary = Symbols.SKILLS[u.type]
	var p: Vector2 = u.pos
	var m: float = sk.mult * (1.5 if u.tier >= MAX_TIER else 1.0) * (1.3 if u.get("promo", 0) >= 3 else 1.0) * (1.0 + Symbols.IMPRINTS.focus.per / 100.0 * _imp(u, "focus"))
	var dmg := _dmg(u) * m * ot
	var col: Color = _d(u).color
	match sk.kind:
		"nova":
			for e in enemies:
				if e.pos.distance_to(p) < sk.r + e.r:
					e.hp -= dmg
			effects.append({pos = p, r = sk.r, t = 0.45, t0 = 0.45, boom = true, color = Color(col, 0.35)})
		"volley", "execute":
			var by := enemies.duplicate()
			if sk.kind == "volley":
				by.sort_custom(func(a, b): return p.distance_squared_to(a.pos) < p.distance_squared_to(b.pos))
			else:
				by.sort_custom(func(a, b): return a.hp / a.max_hp < b.hp / b.max_hp)
			for e in by.slice(0, sk.get("n", 1)):
				e.hp -= dmg
				effects.append({pos = e.pos, r = 40.0, t = 0.35, t0 = 0.35, boom = true, color = Color(col, 0.55)})
		"meteor":
			var best: Dictionary = enemies[0]
			var most := -1
			for e in enemies:
				var n := enemies.filter(func(o): return o.pos.distance_to(e.pos) < sk.r).size()
				if n > most:
					most = n
					best = e
			var at: Vector2 = best.pos
			for e in enemies:
				if e.pos.distance_to(at) < sk.r + e.r:
					e.hp -= dmg
			effects.append({pos = at, r = sk.r, t = 0.55, t0 = 0.55, boom = true, color = Color(1, 0.5, 0.15, 0.4)})
			shake = maxf(shake, 0.3)
		"frost":
			for e in enemies:
				e.hp -= dmg
				e.slow_t = 2.5
				effects.append({pos = e.pos, r = 34.0, t = 0.5, t0 = 0.5, boom = true, color = Color(0.6, 0.85, 1, 0.5)})
		"shield":
			for o in squad:
				if (sk.r == 0.0 and is_same(o, u)) or (sk.r > 0.0 and o.pos.distance_to(p) < sk.r):
					o.shield = maxf(o.get("shield", 0.0), _max_hp(o) * m)
			effects.append({pos = p, r = maxf(sk.r, 50.0), t = 0.5, color = Color(0.5, 0.8, 1)})
		"heal", "rally":
			for o in squad:
				o.hp = minf(_max_hp(o), o.hp + _max_hp(o) * m)
				if sk.kind == "rally":
					o.buff_t = 4.0
			effects.append({pos = p, r = 220.0, t = 0.5, color = Color(0.5, 1, 0.6)})
	popups.append({pos = p + Vector2(0, -56), text = sk.name + "!", color = Color("ffe14d"), t = 1.0})
	u.act_t = ATTACK_ANIM
	sfx.play("heal" if sk.kind in ["shield", "heal", "rally"] else "boom")

# Hero panel: info (skill, imprints, XP) or absorb (preview of absorbing absorb_from, or swap).
func _draw_hero_panel() -> void:
	var u: Dictionary = promote_unit
	var d := _d(u)
	var P := SHOP_PANEL
	draw_rect(Rect2(0, 0, W, screen_h), Color(0, 0, 0, 0.6))
	_nine("paper", P, 0.6)
	_nine("ribbon_purple" if panel_mode == "absorb" else "ribbon_blue", SHOP_RIBBON, 0.7)
	_text(SHOP_RIBBON.position + Vector2(0, 46), "ABSORB?" if panel_mode == "absorb" else _class_title(u).to_upper(), 30, SHOP_RIBBON.size.x)
	if panel_mode == "absorb":
		var g: Dictionary = absorb_from
		var preview := u.duplicate(true)
		var lines := _absorb_into(preview, g)
		draw_string(font, P.position + Vector2(0, 58), "%s Lv%d  into  %s Lv%d" % [_d(g).name, g.tier, d.name, u.tier],
			HORIZONTAL_ALIGNMENT_CENTER, P.size.x, 20, PAPER_TEXT)
		for k in 2:
			var r := _promo_rect(k)
			_nine("banner", r, 0.4, Color(1.08, 1.08, 1.0) if promo_btns[k].is_hovered() else Color.WHITE)
			if k == 0:
				_sprite(Art.UNIT_IDLE[g.type], r.position + Vector2(r.size.x / 2 - 50, 80), 0.9, false, 0, Color(1, 1, 1, 0.6))
				_sprite(Art.UNIT_IDLE[u.type], r.position + Vector2(r.size.x / 2 + 30, 80), 1.2)
				draw_string(font, r.position + Vector2(0, 150), "ABSORB", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, PAPER_TEXT)
				draw_multiline_string(font, r.position + Vector2(26, 176), "\n".join(lines), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 52, 15, 5, PAPER_TEXT)
			else:
				_sprite(Art.UNIT_IDLE[u.type], r.position + Vector2(r.size.x / 2 - 40, 80), 1.0)
				_sprite(Art.UNIT_IDLE[g.type], r.position + Vector2(r.size.x / 2 + 40, 80), 1.0, true)
				draw_string(font, r.position + Vector2(0, 150), "SWAP PLACES", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, PAPER_TEXT)
				draw_multiline_string(font, r.position + Vector2(26, 176), "Keep both heroes, trade their formation spots",
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 52, 15, 3, PAPER_TEXT)
		return
	# info
	_sprite(Art.UNIT_IDLE[u.type], P.position + Vector2(100, 150), 1.6, false, 0, d.get("tint", Color.WHITE))
	var x := P.position.x + 200
	var y := P.position.y + 66
	var w := P.size.x - 230
	var rar: String = Symbols.DATA[u.type].rarity
	draw_string(font, Vector2(x, y), "Lv%d %s  (%s)" % [u.tier, d.name, rar], HORIZONTAL_ALIGNMENT_LEFT, w, 22, PAPER_TEXT)
	y += 26
	var bar := Rect2(x, y, w - 20, 10)
	draw_rect(bar, Color(0, 0, 0, 0.2))
	if u.tier >= MAX_TIER:
		draw_rect(bar, Color("ffb020"))
		draw_string(font, Vector2(x, y + 30), "AWAKENED: skill x1.5", HORIZONTAL_ALIGNMENT_LEFT, w, 16, Color("a06010"))
	else:
		var need := Symbols.xp_need(u.type, u.tier)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(u.get("xp", 0.0) / need, 0, 1), bar.size.y)), Color("ffe14d"))
		draw_string(font, Vector2(x, y + 30), "XP %.1f / %.1f   (absorb heroes)" % [u.get("xp", 0.0), need], HORIZONTAL_ALIGNMENT_LEFT, w, 16, PAPER_TEXT)
	y += 62
	var sk: Dictionary = Symbols.SKILLS.get(u.type, {})
	if not sk.is_empty():
		draw_string(font, Vector2(x, y), "SKILL  %s  (every %ds)" % [sk.name, int(sk.cd)], HORIZONTAL_ALIGNMENT_LEFT, w, 19, Color("6a3a10"))
		draw_multiline_string(font, Vector2(x, y + 22), sk.desc, HORIZONTAL_ALIGNMENT_LEFT, w - 10, 16, 2, PAPER_TEXT)
	y += 70
	draw_string(font, Vector2(x, y), "IMPRINTS  %d / %d slots" % [u.get("imp", {}).size(), _imprint_slots(u)], HORIZONTAL_ALIGNMENT_LEFT, w, 19, Color("6a3a10"))
	y += 4
	for id in u.get("imp", {}):
		y += 22
		draw_string(font, Vector2(x, y), Symbols.imprint_text(id, u.imp[id]), HORIZONTAL_ALIGNMENT_LEFT, w - 10, 15, PAPER_TEXT)
	if u.get("imp", {}).is_empty():
		y += 22
		draw_string(font, Vector2(x, y), "None yet: absorb heroes to gain theirs", HORIZONTAL_ALIGNMENT_LEFT, w - 10, 15, PAPER_TEXT)
	var gives: String = Symbols.HERO_IMPRINT[u.type]
	draw_string(font, Vector2(P.position.x + 24, P.position.y + 330), "Absorbed by another hero, it gives:  %s" % Symbols.imprint_text(gives, 1),
		HORIZONTAL_ALIGNMENT_CENTER, P.size.x - 48, 16, Color("7a2aa0"))