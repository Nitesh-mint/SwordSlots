extends SceneTree
# Synthesizes the slot-machine bell sounds into assets/audio/synth/*.wav (bells = sine partials
# with exponential decay). Run once after editing:
#   godot --headless --path . --script tools/make_sfx.gd

const RATE := 22050
const OUT := "res://assets/audio/synth/"

# Pentatonic notes (Hz)
const C6 := 1046.5
const D6 := 1174.7
const E6 := 1318.5
const G6 := 1568.0
const A6 := 1760.0
const C7 := 2093.0
const D7 := 2349.3
const E7 := 2637.0
const G7 := 3136.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# one bell; the game pitches it up a pentatonic step per payout
	_save("bell", 0.9, [[C6, 0.0, 0.32, 1.0]])
	# coin landing in the purse
	_save("tink", 0.25, [[E7, 0.0, 0.05, 0.8], [G7, 0.02, 0.05, 0.5]])
	# lever ratchet click
	_save("click", 0.08, [[220.0, 0.0, 0.012, 1.0], [880.0, 0.0, 0.008, 0.6]])
	# win tiers
	_save("win1", 0.9, [[C6, 0.0, 0.3, 1.0], [E6, 0.08, 0.3, 1.0], [G6, 0.16, 0.45, 1.0]])
	_save("bigwin", 1.6, [[C6, 0.0, 0.25, 1.0], [E6, 0.07, 0.25, 1.0], [G6, 0.14, 0.25, 1.0],
		[C7, 0.21, 0.25, 1.0], [E7, 0.28, 0.3, 0.9],
		[C6, 0.42, 0.7, 0.8], [E6, 0.42, 0.7, 0.8], [G6, 0.42, 0.7, 0.8], [C7, 0.42, 0.7, 0.6]])
	var run := []
	var notes := [C6, D6, E6, G6, A6, C7, D7, E7, G7, E7, G7]
	for k in notes.size():
		run.append([notes[k], k * 0.055, 0.2, 0.9])
	for f in [C6, E6, G6, C7, E7]:
		run.append([f, 0.65, 1.1, 0.7])
	_save("jackpot", 2.6, run)
	print("synth sounds written to ", OUT)
	quit()


# notes: [[freq, start s, decay s, amp]]
func _save(name: String, dur: float, notes: Array) -> void:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for note in notes:
		var f: float = note[0]
		var s0 := int(note[1] * RATE)
		var decay: float = note[2]
		var amp: float = note[3]
		var length := mini(n - s0, int(decay * 6.0 * RATE))
		for i in length:
			var t := i / float(RATE)
			var env := exp(-t / decay) * minf(1.0, t * 600.0)
			var v := sin(TAU * f * t) + 0.45 * sin(TAU * 2.0 * f * t) * exp(-t / (decay * 0.5)) \
				+ 0.2 * sin(TAU * 3.01 * f * t) * exp(-t / (decay * 0.3))
			buf[s0 + i] += v * env * amp
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(buf[i] / peak * 0.8 * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.save_to_wav(OUT + name + ".wav")
