extends Node
# Sound effects from Kenney CC0 packs in assets/audio. Each name maps to variants; one is picked
# at random with a small pitch wobble so repeated sounds don't feel robotic.
# To swap a sound, edit the paths here. Jingle choices were picked by length, not by ear.

const DIR := "res://assets/audio/"
const C := "casino-audio/Audio/"
const R := "rpg-audio/Audio/"
const I := "interface-sounds/Audio/"
const H := "impact-sounds/Audio/"
const J := "music-jingles/Audio/"

const SOUNDS := {
	# slot machine
	spin = [R + "metalLatch.ogg"],                             # lever pull
	tick = [I + "tick_001.ogg", I + "tick_002.ogg", I + "tick_004.ogg"],   # symbol passing
	reel_stop = [C + "chip-lay-1.ogg", C + "chip-lay-2.ogg", C + "chip-lay-3.ogg"],
	tease = [I + "question_002.ogg"],                          # first two reels match
	pair = [J + "Pizzicato jingles/jingles_PIZZI00.ogg"],
	jackpot = [J + "Pizzicato jingles/jingles_PIZZI07.ogg"],
	buy = [C + "chips-handle-1.ogg", C + "chips-handle-2.ogg", C + "chips-handle-3.ogg"],
	coin = [C + "chips-collide-1.ogg", C + "chips-collide-2.ogg", C + "chips-collide-3.ogg", C + "chips-collide-4.ogg"],
	chest = [C + "chips-stack-1.ogg", C + "chips-stack-2.ogg", C + "chips-stack-3.ogg"],
	# synthesized bells (tools/make_sfx.gd)
	bell = ["synth/bell.wav"],          # payout step, pitched up a pentatonic step each time
	tink = ["synth/tink.wav"],          # coin lands in the purse
	click = ["synth/click.wav"],
	win1 = ["synth/win1.wav"],
	bigwin = ["synth/bigwin.wav"],
	jackpot_bells = ["synth/jackpot.wav"],
	lever = [R + "creak1.ogg", R + "creak2.ogg"],
	# squad
	merge = [I + "maximize_006.ogg"],
	summon = [I + "maximize_003.ogg", I + "maximize_004.ogg"],   # hero appears in the camp
	levelup = [J + "Pizzicato jingles/jingles_PIZZI01.ogg"],
	march = [J + "Steel jingles/jingles_STEEL07.ogg"],
	# sword hit = soft cloth whoosh + light metal clang, played together
	swing = [R + "cloth1.ogg", R + "cloth2.ogg", R + "cloth3.ogg", R + "cloth4.ogg"],
	clang = [H + "impactMetal_light_000.ogg", H + "impactMetal_light_001.ogg", H + "impactMetal_light_002.ogg",
		H + "impactMetal_light_003.ogg", H + "impactMetal_light_004.ogg"],
	bow = [I + "pluck_001.ogg", I + "pluck_002.ogg"],
	throw = [R + "cloth1.ogg", R + "cloth2.ogg", R + "cloth3.ogg"],
	heal = [I + "glass_001.ogg", I + "glass_002.ogg", I + "glass_003.ogg"],
	unit_die = [H + "impactBell_heavy_000.ogg", H + "impactBell_heavy_001.ogg"],
	# combat
	hit = [H + "impactSoft_medium_000.ogg", H + "impactSoft_medium_001.ogg", H + "impactSoft_medium_002.ogg"],
	boom = [H + "impactPunch_heavy_000.ogg", H + "impactPunch_heavy_001.ogg", H + "impactPunch_heavy_002.ogg"],
	hurt = [H + "impactPlate_medium_000.ogg", H + "impactPlate_medium_001.ogg", H + "impactPlate_medium_002.ogg"],
	enemy_die = [H + "impactWood_light_000.ogg", H + "impactWood_light_001.ogg", H + "impactWood_light_002.ogg"],
	launch = [I + "drop_001.ogg", I + "drop_002.ogg"],
	# flow
	wave = [J + "Steel jingles/jingles_STEEL07.ogg"],
	boss = [J + "Hit jingles/jingles_HIT15.ogg"],
	draft = [R + "bookOpen.ogg"],
	pick = [R + "bookPlace1.ogg", R + "bookPlace2.ogg"],
	error = [I + "error_004.ogg"],
	win = [J + "Steel jingles/jingles_STEEL01.ogg"],
	lose = [J + "Sax jingles/jingles_SAX07.ogg"],
}
const VOLUME := {bell = -4.0, tink = -9.0, click = -6.0, lever = -4.0, tick = -14.0, reel_stop = -2.0, coin = -10.0, hit = -12.0, enemy_die = -10.0, bow = -8.0, swing = -9.0, clang = -11.0, throw = -8.0, spin = -4.0}
const EXACT_PITCH := ["bell", "win1", "bigwin", "jackpot_bells"]  # tuned notes: no random wobble
const MIN_GAP := 0.07   # seconds before the same sound may retrigger (stops arrow/coin spam)
const VOICES := 16

const MUSIC := "music/8BitBattleLoop.ogg"
const MUSIC_DB := -10.0
const SAVE_PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX"]

# Player-facing volume settings, saved to SAVE_PATH. volume 0..1, on = not muted.
var volume := {Master = 1.0, Music = 0.8, SFX = 1.0}
var enabled := {Master = true, Music = true, SFX = true}

var _players: Array[AudioStreamPlayer] = []
var _last := {}
var _cache := {}
var _music := AudioStreamPlayer.new()


func _ready() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_load_settings()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	var track: AudioStreamOggVorbis = load(DIR + MUSIC)
	track.loop = true
	_music.stream = track
	_music.volume_db = MUSIC_DB
	_music.bus = "Music"
	add_child(_music)
	_music.play()


func set_volume(bus: String, v: float) -> void:
	volume[bus] = v
	_apply(bus)
	_save_settings()


func set_enabled(bus: String, on: bool) -> void:
	enabled[bus] = on
	_apply(bus)
	_save_settings()


func _apply(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume[bus], 0.0001)))
	AudioServer.set_bus_mute(idx, not enabled[bus] or volume[bus] <= 0.0)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # missing file on first run is fine: defaults stay
	for bus in BUSES:
		volume[bus] = clampf(cfg.get_value("volume", bus, volume[bus]), 0.0, 1.0)
		enabled[bus] = cfg.get_value("enabled", bus, enabled[bus])
		_apply(bus)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in BUSES:
		cfg.set_value("volume", bus, volume[bus])
		cfg.set_value("enabled", bus, enabled[bus])
	cfg.save(SAVE_PATH)


func stop_music() -> void:
	_music.stop()


func play(name: String, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last.get(name, -1.0) < MIN_GAP:
		return
	_last[name] = now
	var path: String = SOUNDS[name].pick_random()
	if not _cache.has(path):
		_cache[path] = load(DIR + path)
	var player := _players[0]
	for p in _players:
		if not p.playing:
			player = p
			break
	player.stream = _cache[path]
	player.volume_db = VOLUME.get(name, 0.0)
	player.pitch_scale = pitch * (1.0 if name in EXACT_PITCH else randf_range(0.93, 1.07))
	player.play()
