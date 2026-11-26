extends Node2D
# Squad lane shooter + 3x3 slot machine. A run = 3 acts x 5 waves, a boss ends each act.
# Two phases: PREPARE (between waves) - spend gold to spin the machine (paylines summon the army,
# powers buff it), pick a symbol after each spin, buy Items, pick a Core (run start / after bosses),
# remove curses. Then FIGHT: no spinning, just steer, dodge and merge; kills drop the gold for the
# next prepare phase. A JUDGEMENT wave is harder but pays double gold + a bonus.

const Symbols := preload("res://scripts/symbols.gd")
const Art := preload("res://scripts/art.gd")
const Items := preload("res://scripts/items.gd")

# Tuning
const LEVELS := 15
const BOSS_EVERY := 5         # waves per act; the last one is a boss
const START_GOLD := 1000
const SPIN_COST := 200         # first spin of each prepare phase...
const SPIN_COST_STEP := 50     # ...each further spin in the same phase costs this much more
const COIN_GOLD := 20          # per coin picked up in battle
const CHEST_GOLD := 150
const WAVE_GOLD := 250         # clearing a wave (+ WAVE_GOLD_STEP per wave number)
const WAVE_GOLD_STEP := 30
const SQUAD_CAP := 8
const MAX_TIER := 5
const WAVE_HEAL := 0.3
const JUDGE_HP := 1.5           # judgement wave: enemy HP x
const JUDGE_DMG := 1.25
const JUDGE_GOLD := 150         # bonus gold for clearing a judgement wave
const ITEM_COST_PER_ACT := 200 # shop prices rise each act
const SCROLL := 160.0
const WAVE_LENGTH := 3600.0
const ROW_GAP := 300.0
const CHEST_EVERY := 4
const HP_GROWTH := 1.88        # enemy HP x per wave
const DMG_GROWTH := 1.28      # enemy damage x per wave
const ENEMY_HP := 20.0
const ENEMY_HP_PER_ROW := 4.0
const ENEMY_DMG := 15.0
const CHASE_SPEED := 60.0
const BOSS_HP := 1200.0
const BOSS_DMG := 40.0
const BOSS_SPEED := 50.0
const MAGNET_RANGE := 300.0
const ENEMY_SHOT_SPEED := 420.0
const SHELL_TIME := 1.2        # warning time before a mortar shell lands
const CREEP := 18.0            # ranged enemies inch forward after stopping, so melee squads can reach them
const BOSS_SHELL_EVERY := 3.5
const BOSS_SHELL_DMG := 0.4     # boss shell damage vs its melee hit

# Enemy types. hp/dmg/speed are multipliers on the wave's base values.
# stop = y where a ranged enemy halts to fire; shot = bolt (aimed, dodgeable) | shell (lobbed AoE).
const ENEMY_TYPES := {
	grunt = {name = "Grunt", from = 1, weight = 3.0, hp = 1.0, dmg = 1.0, r = 22.0, speed = 1.0, chase = 60.0, color = Color("d94a4a")},
	runner = {name = "Runner", from = 2, weight = 2.0, hp = 0.5, dmg = 0.7, r = 16.0, speed = 1.8, chase = 150.0, color = Color("ff9a4a")},
	shooter = {name = "Shooter", from = 4, weight = 1.5, hp = 0.8, dmg = 0.6, r = 20.0, speed = 1.0, chase = 40.0, color = Color("e05ab0"),
		stop = 380.0, shot = "bolt", fire = 2.2},
	brute = {name = "Brute", from = 6, weight = 1.0, hp = 4.0, dmg = 3.0, r = 32.0, speed = 0.6, chase = 30.0, color = Color("8a2a2a")},
	mortar = {name = "Mortar", from = 8, weight = 1.0, hp = 1.2, dmg = 0.8, r = 24.0, speed = 1.0, chase = 0.0, color = Color("a05ae0"),
		stop = 240.0, shot = "shell", fire = 3.5},
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
const SPACING := 64.0
const STEER_SPEED := 700.0
const PROJ_SPEED := 900.0
var REEL_POS := Vector2(24, 896)   # top-left of the 3x3 grid
const REEL_CELL := 104.0
const PAPER_TEXT := Color("3b2a1a")
const WAVE_RIBBON := Rect2(170, 8, 380, 64)
const BAR_RECT := Rect2(130, 78, 460, 34)
const MSG_RIBBON := Rect2(40, 150, 640, 84)
var REEL_WINDOW := Rect2(12, 884, 336, 336)
var SPIN_RECT := Rect2(366, 892, 340, 200)
var ITEMS_POS := Vector2(370, 1106)   # owned items + cores icons
const DRAFT_RIBBON := Rect2(130, 150, 460, 72)
# Camp corner buttons (bottom of the lane): SHOP left, FIGHT right with JUDGEMENT above it.
var SHOP_BTN_RECT := Rect2(12, 800, 150, 68)
var NEXT_RECT := Rect2(548, 800, 160, 68)
var JUDGE_RECT := Rect2(548, 726, 160, 64)
# Shop panel (opened from the SHOP button)
const SHOP_PANEL := Rect2(40, 250, 640, 470)
const SHOP_RIBBON := Rect2(190, 222, 340, 70)
const PURGE_RECT := Rect2(190, 520, 340, 66)
const SHOP_CLOSE_RECT := Rect2(250, 610, 220, 70)
const PURGE_COST_START := 300
const PURGE_COST_STEP := 200
const OVER_RECT := Rect2(100, 380, 520, 240)
const RESTART_RECT := Rect2(210, 640, 300, 96)
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
const TRANS_TIME := 1.4         # camp -> path transition when the fight starts
const WAVE_INTRO := 3.0         # path preview card (act, wave, enemies ahead)
const ATTACK_ANIM := 0.4     # seconds an attack/shoot/cast animation plays

var state := "wave"  # wave | draft | over
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
var shake := 0.0              # screen shake strength, decays to 0

var distance := 0.0
var squad_x := W / 2
var spawn_at := 0.0
var row := 0
var next_id := 0
var boss_spawned := false
var enemies: Array = []      # {id, kind, pos, hp, r, dmg, t}  kind: enemy|boss|chest
var projectiles: Array = []  # {pos, vel, dmg, pierce, blast, crit, color, hit}
var coins: Array = []        # Vector2
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
var steering := false

var screen_h := 1280.0
var pending_ambush := 0
var purge_target := ""          # curse the draft's Remove button will take off the reels
var purge_cost := PURGE_COST_START
var purge_btn: Button
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

	spin_btn = _button(SPIN_RECT.position, SPIN_RECT.size, 40, _on_spin)

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
	purge_btn = _button(PURGE_RECT.position, PURGE_RECT.size, 20, _on_purge)
	shop_close = _button(SHOP_CLOSE_RECT.position, SHOP_CLOSE_RECT.size, 28, _toggle_shop)
	shop_close.text = "Close"
	draft_info = _label(Vector2(0, 224), Vector2(W, 36), 20)

	over_label = _label(OVER_RECT.position + Vector2(40, 30), OVER_RECT.size - Vector2(80, 70), 40)
	over_label.add_theme_color_override("font_color", PAPER_TEXT)
	over_label.add_theme_constant_override("outline_size", 0)
	restart_btn = _button(RESTART_RECT.position, RESTART_RECT.size, 40, get_tree().reload_current_scene)
	restart_btn.text = "Restart"
	_build_settings()

	_summon("swordsman", 1)
	_summon("swordsman", 1)
	_summon("archer", 1)
	rng.randomize()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for i in 12:  # fill the screen with scenery before the first frame
		_scroll_decor(LANE_BOTTOM / 12.0)
	reels.resize(Symbols.CELLS)
	reels.fill("blank")
	_open_camp(true)


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
	SHOP_BTN_RECT.position.y += dy
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
	steering = false
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
	while not payout.is_empty():  # tapping again finishes the payout at once
		_pay_next()
	if not _can_spin():
		return
	if spins > 0:
		spins -= 1
	else:
		gold -= spin_cost
		spin_cost += SPIN_COST_STEP if started else 20  # always rises, so gold symbols can't loop forever
	spin_offers.clear()  # not picking = skip
	reel_spinning = true
	reel_glow = 0.0
	var result := Symbols.roll(pool, _ctx())
	var bag := Symbols.bag(pool)
	# Tease: a payline already matches on its first two columns -> the last column slows down.
	reel_tease = false
	for line in Symbols.LINES:
		var by_col := {}
		for c in line:
			by_col[c % 3] = result[c]
		if by_col[0] == by_col[1] and by_col[0] != "blank" and not Symbols.is_curse(by_col[0]):
			reel_tease = true
	var tease := reel_tease
	for i in 3:  # column i: strip holds old column (bottom first), random symbols, new column
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
	sfx.play("spin")


# Spinning only happens while preparing, after any Core pick, with a free spin or enough gold.
func _can_spin() -> bool:
	return state == "draft" and not _core_pending() and (spins > 0 or gold >= spin_cost)


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
		payout_res = Symbols.resolve(reels, _ctx())
		reel_glow = REEL_GLOW + PAY_STEP * payout_res.events.size()
		hit_cells.clear()
		for k in payout_res.lines:
			for c in Symbols.LINES[k]:
				if reels[c] != "blank" and Symbols.LINES[k].map(func(x): return reels[x]).count(reels[c]) >= 2:
					hit_cells.append(c)
		payout = payout_res.events.duplicate()
		payout_step = 0
		payout_t = 0.15


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
		for k in ev.get("count", 1):
			_summon(ev.summon[0], ev.summon[1])
	_apply_curses(b)
	if ev.has("destroy"):
		pool.erase(ev.destroy)
		shake = maxf(shake, 0.3)
	if ev.text != "":
		popups.append({pos = _reel_cell(ev.i).get_center() + Vector2(0, -30), text = ev.text, color = ev.color, t = 1.3})
		reel_bounce[ev.i % 3] = REEL_BOUNCE
		if ev.has("cells"):  # payline hit: gold stroke through the matching cells
			links.append({a = ev.cells.front(), b = ev.cells.back(), t = 1.0, line = true})
		if ev.has("link"):
			links.append({a = ev.i, b = ev.link, t = 1.0})
		if ev.has("summon"):
			sfx.play("pair", 1.0 + 0.1 * payout_step)
			payout_step += 1
		elif ev.has("destroy"):
			sfx.play("boom")
		elif ev.text == "BLOCKED":
			sfx.play("clang")
		elif Symbols.is_curse(reels[ev.i]):
			sfx.play("curse")
		else:
			sfx.play("coin", 1.0 + 0.15 * payout_step)
			payout_step += 1
	payout_t = PAY_STEP if ev.text != "" else 0.05
	if payout.is_empty():
		_payout_done()


func _payout_done() -> void:
	var res := payout_res
	if res.jackpot:
		_flash("JACKPOT!  " + Symbols.summary(res))
		sfx.play("jackpot")
		shake = 1.0
	if cores.has("sanctum"):
		for u in squad:
			u.hp = minf(_max_hp(u), u.hp + _max_hp(u) * 0.1)
	if not res.destroyed.is_empty():
		_flash("%s destroyed - gone from your reels!" % ", ".join(res.destroyed.map(func(id): return Symbols.CURSES[id].name)))
	_grow()
	if state == "draft":
		spin_offers = Symbols.draft_offers(3)


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
				var heroes := Symbols.DATA.keys().filter(func(k): return Symbols.DATA[k].type == "unit" and Symbols.DATA[k].rarity != "common")
				var hero: String = heroes.pick_random()
				pool[pool.find(id)] = hero
				popups.append({pos = pos, text = "Grew into\n%s!" % Symbols.DATA[hero].name, color = Color("ffe14d"), t = 1.6})
				_flash("Your Lamb grew into a %s! (on your reels)" % Symbols.DATA[hero].name)
				sfx.play("jackpot")
				shake = maxf(shake, 0.5)
		elif lands[id] % Symbols.GROW_EVERY == 0 and ranks.get(id, 0) < Symbols.MAX_RANK:
			ranks[id] = ranks.get(id, 0) + 1
			var curse := Symbols.is_curse(id)
			popups.append({pos = pos, text = "%s\nRANK %d!" % [Symbols.info(id).name, ranks[id]],
				color = Color("ff5050") if curse else Color("ffe14d"), t = 1.6})
			sfx.play("curse" if curse else "merge")
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


func _toggle_shop() -> void:
	shop_open = not shop_open and state == "draft"
	drag_idx = -1
	sfx.play("draft" if shop_open else "pick")


func _item_cost(id: String) -> int:
	return Items.ITEMS[id].cost + ITEM_COST_PER_ACT * _act_index()


func _act_index() -> int:  # 0-based act of the current level
	return int((level - 1) / float(BOSS_EVERY))


# Trap: hurts every unit (never below 1 HP). Thief: takes gold. Ambush: runners charge now,
# or at the start of the next wave if spun between waves.
func _apply_curses(b: Dictionary) -> void:
	if b.trap > 0:
		for i in squad.size():
			var u: Dictionary = squad[i]
			u.hp = maxf(1.0, u.hp - _max_hp(u) * b.trap)
			effects.append({pos = _unit_pos(i), r = 30.0, t = 0.4, t0 = 0.4, boom = true, color = Color(1, 0.3, 0.2, 0.2)})
	if b.thief > 0:
		gold -= int(gold * minf(b.thief, 1.0))
	pending_ambush += b.ambush
	if state == "wave":
		_spawn_ambush()


func _spawn_ambush() -> void:
	var t: Dictionary = ENEMY_TYPES.runner
	for k in pending_ambush:
		var x := clampf(squad_x + (k - (pending_ambush - 1) / 2.0) * 60.0, LANE_L + 40, LANE_R - 40)
		_add("enemy", Vector2(x, 120), (ENEMY_HP + 4 * ENEMY_HP_PER_ROW) * _hp_scale() * t.hp, t.r,
			ENEMY_DMG * _dmg_scale() * t.dmg, "runner")
	pending_ambush = 0


# ---------------------------------------------------------------- squad

func _d(u: Dictionary) -> Dictionary:
	return Symbols.DATA[u.type]


func _max_hp(u: Dictionary) -> float:
	return _d(u).hp * Symbols.tier_mult(u.tier) * (1.0 + power.vigor / 100.0)


func _dmg(u: Dictionary) -> float:
	var m: float = (1.0 + power.might / 100.0) * (1.2 if items.has("whetstone") else 1.0)
	if cores.has("archery") and _d(u).attack == "shot":
		m *= 1.3
	return _d(u).dmg * Symbols.tier_mult(u.tier) * m


func _cooldown(u: Dictionary) -> float:
	return _d(u).cd / (1.0 + power.haste / 100.0)


func _summon(id: String, tier: int) -> void:
	var u := {type = id, tier = tier, hp = 0.0, t = 0.0, act_t = 0.0}
	u.hp = _max_hp(u)
	squad.append(u)
	if squad.size() > SQUAD_CAP and not _auto_merge():
		squad.erase(u)
		_flash("Squad full! %s lost - merge to make room" % Symbols.DATA[id].name)
		sfx.play("error")
	_sort_squad()
	var i := squad.find(u)
	if i >= 0:  # birth: light beam + pop + sparks in the camp, a quick flash in battle
		u.born = BORN_TIME if state == "draft" else 0.5
		var rar: String = Symbols.DATA[id].rarity
		var col: Color = Color(1, 0.95, 0.7) if rar == "common" else Symbols.RARITY_COLOR[rar]
		u.color = col
		_burst(_unit_pos(i), col, 18 if state == "draft" else 8)
		sfx.play("summon", 1.0 + 0.1 * tier)
		if rar in ["epic", "legendary"] or tier >= 3:
			shake = maxf(shake, 0.4)


func _burst(pos: Vector2, col: Color, n: int) -> void:
	for k in n:
		var a := TAU * k / n + randf_range(-0.2, 0.2)
		var t := randf_range(0.5, 0.9)
		sparks.append({pos = pos, vel = Vector2(cos(a), sin(a) - 0.8) * randf_range(140, 300), t = t, t0 = t, color = col})


func _camp_pos(i: int) -> Vector2:
	var r := int(i / 4.0)
	var in_row := mini(4, squad.size() - r * 4)
	return CAMP_CENTER + Vector2((i % 4 - (in_row - 1) / 2.0) * CAMP_SPACING, -30 + r * 96)


func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# Front row = shortest range (melee/tanks), back row = shooters/healers.
func _sort_squad() -> void:
	squad.sort_custom(func(a, b): return _d(a).range < _d(b).range)


func _can_merge(a: Dictionary, b: Dictionary) -> bool:
	return a.type == b.type and a.tier == b.tier and a.tier < MAX_TIER


# Keeps squad[keep], removes squad[gone].
func _merge(keep: int, gone: int) -> bool:
	if keep == gone or not _can_merge(squad[keep], squad[gone]):
		return false
	var u: Dictionary = squad[keep]
	u.tier += 1
	u.hp = _max_hp(u)
	squad.remove_at(gone)
	_sort_squad()
	u.lvl_t = LEVEL_TIME
	var p := _unit_pos(squad.find(u))
	_burst(p, Color(1, 0.85, 0.25), 16)
	popups.append({pos = p + Vector2(0, -40), text = "LEVEL UP!\nLv%d" % u.tier, color = Color("ffe14d"), t = 1.3})
	sfx.play("merge")
	sfx.play("levelup", 0.9 + 0.1 * u.tier)
	shake = maxf(shake, 0.25)
	return true


func _has_twins() -> bool:
	for i in squad.size():
		for j in range(i + 1, squad.size()):
			if _can_merge(squad[i], squad[j]):
				return true
	return false


func _auto_merge() -> bool:
	var best := []
	for i in squad.size():
		for j in range(i + 1, squad.size()):
			if _can_merge(squad[i], squad[j]) and (best.is_empty() or squad[i].tier > squad[best[0]].tier):
				best = [i, j]
	return not best.is_empty() and _merge(best[0], best[1])


# Battle formation on the path; in the camp the squad stands on the summoning circle,
# and while the fight starts it marches from the circle onto the path.
func _unit_pos(i: int) -> Vector2:
	var r := int(i / 4.0)
	var in_row := mini(4, squad.size() - r * 4)
	var lane := Vector2(squad_x + (i % 4 - (in_row - 1) / 2.0) * SPACING, SQUAD_Y - 64 + r * 64)
	if state == "draft":
		return _camp_pos(i)
	if trans > 0 and state == "wave":
		return _camp_pos(i).lerp(lane, _smooth(1.0 - trans / TRANS_TIME))
	return lane


func _squad_center() -> Vector2:
	return Vector2(squad_x, SQUAD_Y - 32)


# ---------------------------------------------------------------- wave

func _start_wave() -> void:
	state = "wave"
	distance = 0.0
	spawn_at = 500.0
	row = 0
	boss_spawned = false
	enemies.clear()
	projectiles.clear()
	coins.clear()
	enemy_shots.clear()
	shells.clear()
	trans = TRANS_TIME
	wave_intro = WAVE_INTRO
	sfx.play("march")
	if (level - 1) % BOSS_EVERY == 0:
		decor.clear()
		for i in 12:
			_scroll_decor(LANE_BOTTOM / 12.0)
	var notes := []
	var news := ENEMY_TYPES.values().filter(func(t): return t.from == level).map(func(t): return t.name)
	if not news.is_empty():
		notes.append("New enemy: " + ", ".join(news))
	if level % 2 == 0 or judgement:  # the reels grow darker as the run goes on
		var c: String = Symbols.CURSES.keys().pick_random()
		pool.append(c)
		notes.append("A %s curse joins your reels" % Symbols.CURSES[c].name)
	sfx.play("boss" if _boss_level() or judgement else "wave")
	_flash("%s  FIGHT!%s" % [_wave_name(),
		"\n" + "\n".join(notes) if not notes.is_empty() else ""])
	_spawn_ambush()


func _boss_level() -> bool:
	return level % BOSS_EVERY == 0


func _wave_name() -> String:
	return "Act %d  Wave %d%s" % [_act_index() + 1, (level - 1) % BOSS_EVERY + 1,
		"  BOSS" if _boss_level() else ("  JUDGEMENT" if judgement and state == "wave" else "")]


func _hp_scale() -> float:
	return pow(HP_GROWTH, level - 1) * (1.0 + power.enemy_hp) * (JUDGE_HP if judgement else 1.0)


func _dmg_scale() -> float:
	return pow(DMG_GROWTH, level - 1) * (JUDGE_DMG if judgement else 1.0)


func _process_wave(delta: float) -> void:
	distance += SCROLL * delta
	_scroll_decor(SCROLL * delta)
	_steer(delta)
	_spawn()
	_units_act(delta)
	_move(delta)
	_enemies_fire(delta)
	_enemy_projectiles(delta)
	_collide(delta)
	if squad.is_empty():
		_game_over("Squad wiped on\n%s" % _wave_name())
	elif distance >= WAVE_LENGTH and enemies.is_empty() and (boss_spawned or not _boss_level()):
		_end_wave()


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
	return THEMES[mini(_act_index(), THEMES.size() - 1)]


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


func _steer(delta: float) -> void:
	var dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	squad_x += dir * STEER_SPEED * delta
	var half := 1.5 * SPACING + UNIT_R
	squad_x = clampf(squad_x, LANE_L + half, LANE_R - half)


func _spawn() -> void:
	if distance < spawn_at:
		return
	var scale := _hp_scale()
	if distance >= WAVE_LENGTH:
		if _boss_level() and not boss_spawned:
			boss_spawned = true
			_add("boss", Vector2(W / 2, -100), BOSS_HP * scale, 80.0, BOSS_DMG * _dmg_scale())
		return
	if row % CHEST_EVERY == CHEST_EVERY - 1:
		_add("chest", Vector2(randf_range(LANE_L + 60, LANE_R - 60), -40), 4.0 * ENEMY_HP * scale, 32.0, 0.0)
	else:
		var n := randi_range(2 + mini(level - 1, 1), 3 + mini(level - 1, 2))  # gentler first waves
		for i in n:
			var x := lerpf(LANE_L + 40, LANE_R - 40, (i + 0.5) / n)
			var type := _pick_enemy_type()
			var t: Dictionary = ENEMY_TYPES[type]
			_add("enemy", Vector2(x, -40), (ENEMY_HP + row * ENEMY_HP_PER_ROW) * scale * t.hp, t.r,
				ENEMY_DMG * _dmg_scale() * t.dmg, type)
	row += 1
	spawn_at += ROW_GAP


func _pick_enemy_type() -> String:
	var ids := []
	var weights := PackedFloat32Array()
	for id in ENEMY_TYPES:
		if ENEMY_TYPES[id].from <= level:
			ids.append(id)
			weights.append(ENEMY_TYPES[id].weight)
	return ids[rng.rand_weighted(weights)]


func _add(kind: String, pos: Vector2, hp_: float, r: float, dmg: float, type := "") -> void:
	enemies.append({id = next_id, kind = kind, type = type, pos = pos, hp = hp_, r = r, dmg = dmg, t = 0.0,
		fire_t = randf_range(0.5, 1.5), act_t = 0.0, flip = false})
	next_id += 1


func _nearest(p: Vector2, reach: float):
	var best = null
	var best_d := reach
	for e in enemies:
		var dist: float = p.distance_to(e.pos)
		if e.pos.y < p.y and e.pos.y > 0 and dist < best_d:
			best = e
			best_d = dist
	return best


func _units_act(delta: float) -> void:
	for i in squad.size():
		var u: Dictionary = squad[i]
		u.act_t = maxf(0.0, u.get("act_t", 0.0) - delta)
		u.t -= delta
		if u.t > 0:
			continue
		var d := _d(u)
		var p := _unit_pos(i)
		match d.attack:
			"heal":
				var low = null
				for o in squad:
					if o.hp < _max_hp(o) and (low == null or o.hp / _max_hp(o) < low.hp / _max_hp(low)):
						low = o
				u.t = 0.2
				if low != null:
					low.hp = minf(_max_hp(low), low.hp + _dmg(u))
					sfx.play("heal")
					u.t = _cooldown(u)
					u.act_t = ATTACK_ANIM
			"melee":
				var hit := false
				for e in enemies:
					if e.pos.y < p.y + 10 and p.distance_to(e.pos) < d.range + e.r:
						e.hp -= _dmg(u)
						hit = true
				if hit:
					u.t = _cooldown(u)
					u.act_t = ATTACK_ANIM
					effects.append({pos = p + Vector2(0, -20), r = d.range * 0.45, t = 0.12, color = Color(1, 1, 1)})
					sfx.play("swing")
					sfx.play("clang", 0.9)
			"shot":
				var target = _nearest(p, d.range)
				if target != null:
					sfx.play("throw" if d.get("blast", 0.0) > 0 else "bow")
					projectiles.append({pos = p, vel = (target.pos - p).normalized() * PROJ_SPEED, dmg = _dmg(u),
						pierce = d.get("pierce", 0), blast = d.get("blast", 0.0), crit = d.get("crit", 0.0),
						color = d.color, hit = []})
					u.t = _cooldown(u)
					u.act_t = ATTACK_ANIM


func _move(delta: float) -> void:
	for p in projectiles:
		p.pos += p.vel * delta
	projectiles = projectiles.filter(func(p): return p.pos.y > -20 and p.pos.y < LANE_BOTTOM and p.pos.x > 0 and p.pos.x < W)

	var front_y := SQUAD_Y - 64 - UNIT_R
	for e in enemies:
		var pos: Vector2 = e.pos
		e.act_t = maxf(0.0, e.act_t - delta)
		if e.kind == "boss":
			pos.y = minf(pos.y + BOSS_SPEED * delta, front_y - e.r)
			pos.x = move_toward(pos.x, squad_x, BOSS_SPEED * delta)
		else:
			var t: Dictionary = ENEMY_TYPES.get(e.type, {})
			var speed: float = SCROLL * t.get("speed", 1.0)
			if t.has("stop") and pos.y >= t.stop:
				speed = CREEP
			pos.y += speed * delta
			if e.kind == "enemy" and pos.y > 0:
				pos.x = move_toward(pos.x, squad_x, t.get("chase", CHASE_SPEED) * delta)
		e.pos = pos

	var c := _squad_center()
	for i in coins.size():
		var coin: Vector2 = coins[i]
		if power.magnet > 0 and coin.distance_to(c) < MAGNET_RANGE * power.magnet:
			coins[i] = coin.move_toward(c, 700.0 * delta)
		else:
			coins[i] = coin + Vector2(0, SCROLL * delta)

	for fx in effects:
		fx.t -= delta
	effects = effects.filter(func(fx): return fx.t > 0)


func _collide(delta: float) -> void:
	# Projectiles
	for p in projectiles:
		for e in enemies:
			if e.hp <= 0 or p.hit.has(e.id) or p.pos.distance_to(e.pos) > e.r + 6:
				continue
			var dmg: float = p.dmg * (3.0 if randf() < p.crit else 1.0)
			if p.blast > 0:
				for o in enemies:
					if o.pos.distance_to(p.pos) < p.blast + o.r:
						o.hp -= dmg
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

	# Enemy contact / boss attacks
	for e in enemies:
		if e.hp <= 0 or e.kind == "chest":
			continue
		for i in squad.size():
			var up := _unit_pos(i)
			if up.distance_to(e.pos) >= e.r + UNIT_R + (40.0 if e.kind == "boss" else 0.0):
				continue
			if e.kind == "boss":
				e.t -= delta
				if e.t <= 0:
					squad[i].hp -= e.dmg
					sfx.play("hurt")
					e.t = 1.0
					e.act_t = ATTACK_ANIM
					effects.append({pos = up, r = 40.0, t = 0.2, color = Color(1, 0.2, 0.2, 0.6)})
			else:
				squad[i].hp -= e.dmg
				sfx.play("hurt")
				e.hp = 0
				e.kind = "spent"
			break

	_apply_deaths()

	var alive: Array = []
	for e in enemies:
		if e.hp <= 0:
			_kill(e)
		elif e.pos.y < LANE_BOTTOM + 40:
			alive.append(e)
	enemies = alive

	var c := _squad_center()
	var kept: Array = []
	for coin in coins:
		if absf(coin.x - c.x) < 2 * SPACING + 20 and absf(coin.y - c.y) < 70:
			gold += int(COIN_GOLD * (1.5 if judgement else 1.0))
			sfx.play("coin")
		elif coin.y < LANE_BOTTOM:
			kept.append(coin)
	coins = kept


# Ranged enemies (and the boss) fire at a random squad member's current position.
func _enemies_fire(delta: float) -> void:
	if squad.is_empty():
		return
	for e in enemies:
		var t: Dictionary = ENEMY_TYPES.get(e.type, {})
		var shot: String = "shell" if e.kind == "boss" else t.get("shot", "")
		if shot == "" or e.pos.y < 60:
			continue
		e.fire_t -= delta
		if e.fire_t > 0:
			continue
		e.fire_t = BOSS_SHELL_EVERY if e.kind == "boss" else t.fire
		e.act_t = ATTACK_ANIM
		var target := _unit_pos(rng.randi() % squad.size())
		if shot == "bolt":
			enemy_shots.append({pos = e.pos, vel = (target - e.pos).normalized() * ENEMY_SHOT_SPEED, dmg = e.dmg})
			sfx.play("bow", 0.8)
		else:
			shells.append({pos = target, t = SHELL_TIME, dmg = e.dmg * (BOSS_SHELL_DMG if e.kind == "boss" else 1.0), r = 90.0 if e.kind == "boss" else 70.0})
			sfx.play("launch")


func _enemy_projectiles(delta: float) -> void:
	for s in enemy_shots:
		s.pos += s.vel * delta
		for i in squad.size():
			if _unit_pos(i).distance_to(s.pos) < UNIT_R + 6:
				squad[i].hp -= s.dmg
				sfx.play("hurt")
				s.pos.y = 99999.0  # consumed
				break
	enemy_shots = enemy_shots.filter(func(s): return s.pos.y > -20 and s.pos.y < LANE_BOTTOM)

	for sh in shells:
		sh.t -= delta
		if sh.t <= 0:
			sfx.play("boom")
			for i in squad.size():
				if _unit_pos(i).distance_to(sh.pos) < sh.r + UNIT_R:
					squad[i].hp -= sh.dmg
			effects.append({pos = sh.pos, r = sh.r, t = 0.4, t0 = 0.4, boom = true, color = Color(1, 0.4, 0.1, 0.25)})
	shells = shells.filter(func(sh): return sh.t > 0)
	_apply_deaths()


func _apply_deaths() -> void:
	var dead := squad.filter(func(u): return u.hp <= 0)
	if not dead.is_empty():
		squad = squad.filter(func(u): return u.hp > 0)
		_flash("%s fell!" % Symbols.DATA[dead[0].type].name)
		sfx.play("unit_die")


func _kill(e: Dictionary) -> void:
	match e.kind:
		"enemy":
			sfx.play("enemy_die")
			coins.append(e.pos)
		"boss":
			for i in 15:
				coins.append(e.pos + Vector2(randf_range(-80, 80), randf_range(-60, 60)))
		"chest":
			gold += CHEST_GOLD
			_flash("+%d gold" % CHEST_GOLD)
			sfx.play("chest")


func _end_wave() -> void:
	if level >= LEVELS:
		_game_over("You beat all 3 acts!")
		return
	var heal := 0.7 if items.has("meat") else WAVE_HEAL
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
	spin_cost = SPIN_COST
	fade = 0.9 if started else 0.0
	if items.has("gear") and started:
		spins += 1
	shop = Items.offers(Items.ITEMS, items, 3) if started else []
	_pick_purge_target()
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
	sfx.play("buy")


# Start the next wave (judge = judgement wave: harder, x1.5 coin gold + JUDGE_GOLD bonus).
func _next(judge: bool) -> void:
	if state != "draft":
		return
	if reel_spinning:
		return
	while not payout.is_empty():
		_pay_next()
	if started:
		level += 1
	started = true
	shop_open = false
	spin_offers.clear()
	judgement = judge and not _boss_level()
	_start_wave()


func _pick_purge_target() -> void:
	var curses := pool.filter(Symbols.is_curse)
	purge_target = curses.pick_random() if not curses.is_empty() else ""


func _on_purge() -> void:
	if state != "draft" or purge_target == "" or gold < purge_cost:
		return
	pool.erase(purge_target)
	gold -= purge_cost
	purge_cost += PURGE_COST_STEP
	sfx.play("merge")
	_pick_purge_target()


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
	over_label.text = "%s\nGold: %d" % [msg, gold]
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
	if state == "over" or settings_open or shop_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var slot := _slot_at(event.position)
		if event.pressed:
			if slot >= 0 and slot < squad.size():
				drag_idx = slot
				drag_pos = event.position
			steering = slot < 0 and event.position.y < LANE_BOTTOM and state == "wave"
		else:
			if drag_idx >= 0 and drag_idx < squad.size() and slot >= 0 and slot < squad.size() and slot != drag_idx:
				if not _merge(slot, drag_idx):
					popups.append({pos = _camp_pos(slot) + Vector2(0, -40), text = "Needs same hero\n+ same level", color = Color(1, 0.5, 0.4), t = 1.2})
					sfx.play("error")
			drag_idx = -1
			steering = false
	elif event is InputEventMouseMotion:
		if drag_idx >= 0:
			drag_pos = event.position
		elif steering and state == "wave":
			squad_x += event.relative.x


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.0)
	fade = maxf(0.0, fade - delta * 1.6)
	wave_intro = maxf(0.0, wave_intro - delta)
	trans = maxf(0.0, trans - delta)
	for u in squad:
		u.born = maxf(0.0, u.get("born", 0.0) - delta)
		u.lvl_t = maxf(0.0, u.get("lvl_t", 0.0) - delta)
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
	wave_label.text = _wave_name().to_upper().replace("  JUDGEMENT", "")
	gold_label.text = str(gold)
	squad_label.text = "%d/%d" % [squad.size(), SQUAD_CAP]
	power_label.text = "Dmg +%d%%   Speed +%d%%   HP +%d%%   Enemy HP x%s" % [power.might, power.haste, power.vigor, snappedf(_hp_scale(), 0.1)]
	msg_label.visible = msg_timer > 0 and state == "wave"
	if reel_spinning:
		spin_btn.text = "STOP"
	elif state == "wave":
		spin_btn.text = "IN BATTLE"
	elif _core_pending():
		spin_btn.text = "Pick a Core"
	else:
		spin_btn.text = "FREE SPIN x%d" % spins if spins > 0 else "SPIN  %d" % spin_cost
	spin_btn.disabled = not reel_spinning and not _can_spin()
	spin_btn.visible = not settings_open

	var camp := state == "draft" and not settings_open
	var in_shop := camp and shop_open
	camp = camp and not shop_open
	draft_title.visible = camp
	var ids := _card_ids()
	if _core_pending():
		draft_title.text = "Choose a Core"
	elif not ids.is_empty():
		draft_title.text = "Add one to your reels"
	else:
		draft_title.text = "PREPARE YOUR ARMY"
	purge_btn.visible = in_shop
	shop_close.visible = in_shop
	shop_btn.visible = camp
	purge_btn.disabled = purge_target == "" or gold < purge_cost
	purge_btn.text = "No curses" if purge_target == "" else "Remove %s\n%d gold" % [Symbols.CURSES[purge_target].name, purge_cost]
	next_btn.visible = camp
	next_btn.text = "FIGHT!"
	next_btn.disabled = _core_pending()
	var next_boss := (level + 1) % BOSS_EVERY == 0
	judge_btn.visible = camp and started and not next_boss
	draft_info.visible = camp
	var n_curse := pool.filter(Symbols.is_curse).size()
	draft_info.text = "Reels: %d symbols, %d curses, %d empty   Next: %s%s" % [pool.size() - n_curse, n_curse,
		Symbols.bag(pool).size() - pool.size(), "BOSS" if next_boss and started else "wave",
		"  (spin again = skip)" if not ids.is_empty() and not _core_pending() else ""]
	for i in 3:
		draft_btns[i].visible = camp and i < ids.size() and not reel_spinning
		if draft_btns[i].visible:
			var d: Dictionary = Items.info(ids[i]) if _core_pending() else Symbols.DATA[ids[i]]
			draft_btns[i].text = d.desc
		shop_btns[i].visible = in_shop and i < shop.size()
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
	if Symbols.is_curse(id):
		draw_rect(rect.grow(-2), Color(0.8, 0.1, 0.1, 0.22))
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
			draw_circle(c, pip, Color("ff5050") if Symbols.is_curse(id) else Color("ffe14d"))
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
	if id == "lamb":
		return [Art.tex(Art.LAMB), Rect2(24, 34, 80, 80), rect.grow(-4), Color.WHITE]
	if Art.CURSES.has(id):
		var c: Dictionary = Art.CURSES[id]
		return [Art.tex(c.path), c.src, rect.grow(-4), Color.WHITE]
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
	var pos := _reel_pos(i) if not strip.is_empty() else 0.0
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
	if reel_glow > 0 and reel_t[i] >= 1.0:
		var a := (0.55 + 0.45 * sin(anim_time * 14.0)) * minf(1.0, reel_glow * 2.0)
		for r in 3:
			var c := r * 3 + i
			if hit_cells.has(c):
				var glow := Color(1, 0.2, 0.15, a) if Symbols.is_curse(reels[c]) else Color(1, 0.85, 0.2, a)
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
	var s: float = UNIT_SCALE * (1.0 + 0.1 * (u.tier - 1))
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
	var act: float = u.get("act_t", 0.0)
	if act > 0:
		var path: String = Art.UNIT_ATTACK[u.type]
		_sprite(path, pos, s, false, 0, mod, _act_frame(path, act))
	elif camp:  # idle in the camp
		_sprite(Art.UNIT_IDLE[u.type], pos, s, false, phase, mod)
	else:  # run while marching
		_sprite(Art.UNITS[u.type], pos, s, false, phase, mod, -1 if state == "wave" else 0)
	if u.tier > 1:
		_text(pos + Vector2(-30, -26), str(u.tier), 18, 60, Color("ffe14d"))
	var frac: float = clampf(u.hp / _max_hp(u), 0, 1)
	draw_rect(Rect2(pos + Vector2(-20, 30), Vector2(40, 5)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(pos + Vector2(-20, 30), Vector2(40 * frac, 5)), Color("4ae08a"))


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
	if state == "draft":
		_draw_camp(1.0, 0.0)
	else:
		_draw_ground()
		if trans > 0 and state == "wave":  # camp slides down and fades, revealing the path
			var k := _smooth(1.0 - trans / TRANS_TIME)
			_draw_camp(1.0 - k, k * LANE_BOTTOM * 0.8)

	for coin in coins:
		_sprite(Art.GOLD, coin, 0.22, false, 0, Color.WHITE, 0)
	for e in enemies:
		var big: bool = e.kind == "boss"
		if e.kind == "chest":
			_sprite(Art.CHEST, e.pos, 0.55, false, 0, Color.WHITE, 0)
			_text(e.pos + Vector2(-40, -30), "GOLD", 18, 80, Color("ffe14d"))
		else:
			var key: String = "boss" if big else e.type
			var s: float = UNIT_SCALE * {boss = 1.7, brute = 1.3, runner = 0.85}.get(key, 1.0)
			if e.pos.x > squad_x + 12:  # dead zone stops facing from flickering when lined up
				e.flip = true
			elif e.pos.x < squad_x - 12:
				e.flip = false
			if e.act_t > 0 and Art.ENEMY_ATTACK.has(key):
				var path: String = Art.ENEMY_ATTACK[key]
				_sprite(path, e.pos, s, e.flip, 0, Color.WHITE, _act_frame(path, e.act_t))
			else:
				_sprite(Art.ENEMIES.get(key, Art.ENEMIES.grunt), e.pos, s, e.flip, e.id, Color.WHITE, -1 if state == "wave" else 0)
		_text(e.pos + Vector2(-50, e.r + 20), str(ceili(e.hp)), 34 if big else 20, 100)

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
	if state == "draft":  # ground ring under each unit; twins of the dragged unit pulse gold
		for i in squad.size():
			var twin := dragging and i != drag_idx and _can_merge(squad[drag_idx], squad[i])
			draw_set_transform(_camp_pos(i) + Vector2(0, 30), 0.0, Vector2(1, 0.4))
			var a := 0.55 + 0.45 * sin(anim_time * 8.0) if twin else 0.25
			draw_arc(Vector2.ZERO, 40.0 if twin else 32.0, 0, TAU, 32, Color(1, 0.85, 0.3, a) if twin else Color(1, 1, 1, a), 5.0 if twin else 2.0)
			draw_set_transform(Vector2.ZERO)
	for i in squad.size():
		if dragging and i == drag_idx:
			continue
		_draw_unit(_unit_pos(i), squad[i], i * 3)
	if dragging:
		_draw_unit(drag_pos, squad[drag_idx], 0)
	elif state == "draft" and _has_twins():
		_text(Vector2(0, CAMP_CENTER.y + 118), "Drag a hero onto its twin to level up", 20, W, Color(1, 0.92, 0.5, 0.6 + 0.4 * sin(anim_time * 3.0)))
	for p in sparks:
		var a: float = p.t / p.t0
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
	var ids: Array = ENEMY_TYPES.keys().filter(func(k): return ENEMY_TYPES[k].from <= level)
	if _boss_level():
		ids.append("boss")
	for k in ids.size():
		var p := Vector2(W / 2 + (k - (ids.size() - 1) / 2.0) * 112, y + 70)
		_sprite(Art.ENEMIES[ids[k]], p, 0.55 if ids[k] != "boss" else 0.75, false, k, Color(1, 1, 1, a))
		var name: String = "BOSS" if ids[k] == "boss" else ENEMY_TYPES[ids[k]].name
		var new: bool = ids[k] != "boss" and ENEMY_TYPES[ids[k]].from == level
		_text(p + Vector2(-56, 52), ("NEW " if new else "") + name, 16, 112, Color(1, 0.88, 0.3, a) if new else Color(1, 1, 1, a))


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
	draw_texture_rect(Art.tex(Art.ICON_COIN), Rect2(12, 14, 52, 52), false)
	draw_texture_rect(Art.tex(Art.ICON_SWORD), Rect2(656, 14, 52, 52), false)
	if state == "wave":
		_nine("bar", BAR_RECT, 0.67)
		var inner := Rect2(BAR_RECT.position + Vector2(14, 10), BAR_RECT.size - Vector2(28, 20))
		draw_texture_rect(Art.tex(Art.BAR_FILL), Rect2(inner.position, Vector2(inner.size.x * clampf(distance / WAVE_LENGTH, 0, 1), inner.size.y)), false)
	if msg_label.visible:
		_nine("ribbon_yellow", Rect2(MSG_RIBBON.position.x, msg_label.position.y, MSG_RIBBON.size.x, MSG_RIBBON.size.y), 0.8)

	# Bottom panel: wood table, paper reel window, buttons, squad slots
	_nine("wood", Rect2(-8, LANE_BOTTOM - 6, W + 16, screen_h - LANE_BOTTOM + 30), 0.5)
	_nine("paper_special", REEL_WINDOW, 0.45)
	for i in Symbols.CELLS:
		_nine("paper", _reel_cell(i).grow(2), 0.25)
	for i in 3:
		_draw_reel(i, Rect2(REEL_POS + Vector2(i * REEL_CELL, 0), Vector2(REEL_CELL, REEL_CELL * 3)))
	for l in links:  # payline stroke, or combo link (with a + badge) between two cells
		var a := _reel_cell(l.a).get_center()
		var c := _reel_cell(l.b).get_center()
		var col := Color(1, 0.88, 0.3, minf(1.0, l.t * 2.0))
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
	_button_art(spin_btn, "red")
	var owned: Array = cores + items
	for i in owned.size():
		var r := Rect2(ITEMS_POS + Vector2((i % 9) * 42, int(i / 9.0) * 42), Vector2(40, 40))
		_nine("paper", r, 0.15)
		_draw_icon(r.grow(-5), Items.info(owned[i]).icon)

	# Draft / game over overlays
	if state == "over":
		draw_rect(Rect2(0, 0, W, LANE_BOTTOM), Color(0, 0, 0, 0.55))
	if state == "draft":
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
	if state == "draft" and shop_open:
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
		_button_art(purge_btn, "red", 0.4)
		_button_art(shop_close, "blue", 0.4)
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

