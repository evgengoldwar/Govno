extends Node
## Procedurally synthesized sound effects (no audio assets needed).

const RATE := 22050

var streams := {}
var players: Array = []
var next := 0
var last_play := {}
var clock := 0.0


func _ready() -> void:
	for i in range(12):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		players.append(p)
	_build()


func _process(dt: float) -> void:
	clock += dt


func play(snd: String, pitch_var := 0.06) -> void:
	if not streams.has(snd):
		return
	if clock - float(last_play.get(snd, -1.0)) < 0.045:
		return
	last_play[snd] = clock
	var p: AudioStreamPlayer = players[next]
	next = (next + 1) % players.size()
	p.stream = streams[snd]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func _wave(kind: String, ph: float) -> float:
	match kind:
		"sine":
			return sin(ph * TAU)
		"square":
			return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		"saw":
			return fmod(ph, 1.0) * 2.0 - 1.0
		"tri":
			var x := fmod(ph, 1.0)
			return 4.0 * x - 1.0 if x < 0.5 else 3.0 - 4.0 * x
		"noise":
			return randf_range(-1.0, 1.0)
	return 0.0


## segs: array of [f0, f1, dur, wave, vol, noise]
func _make(segs: Array) -> AudioStreamWAV:
	var total := 0
	for sg in segs:
		total += int(float(sg[2]) * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var idx := 0
	var lp := 0.0
	for sg in segs:
		var f0: float = sg[0]
		var f1: float = sg[1]
		var dur: float = sg[2]
		var kind: String = sg[3]
		var vol: float = sg[4]
		var noise: float = sg[5]
		var n := int(dur * RATE)
		var ph := 0.0
		for i in range(n):
			var k := float(i) / n
			var f := lerpf(f0, f1, k)
			ph += f / RATE
			var sm := _wave(kind, ph)
			if noise > 0.0:
				var nz := randf_range(-1.0, 1.0)
				lp = lp + (nz - lp) * 0.35
				sm = sm * (1.0 - noise) + lp * noise * 1.6
			var env := minf(1.0, float(i) / (RATE * 0.004)) * pow(1.0 - k, 1.4)
			var v := clampf(sm * env * vol, -1.0, 1.0)
			data.encode_s16(idx * 2, int(v * 32000.0))
			idx += 1
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st


func _build() -> void:
	var defs := {
		"jump": [[320.0, 620.0, 0.11, "square", 0.25, 0.0]],
		"djump": [[420.0, 900.0, 0.14, "tri", 0.4, 0.2]],
		"swim": [[300.0, 520.0, 0.09, "sine", 0.35, 0.1]],
		"dash": [[900.0, 300.0, 0.15, "noise", 0.35, 1.0]],
		"switch": [[600.0, 950.0, 0.09, "sine", 0.4, 0.0]],
		"shoot_fire": [[520.0, 180.0, 0.13, "saw", 0.25, 0.5]],
		"shoot_water": [[760.0, 380.0, 0.12, "sine", 0.4, 0.15]],
		"shoot_poison": [[260.0, 160.0, 0.12, "square", 0.22, 0.2]],
		"shoot_air": [[1400.0, 700.0, 0.1, "noise", 0.3, 0.9]],
		"shoot_earth": [[170.0, 70.0, 0.16, "square", 0.3, 0.3]],
		"hit": [[260.0, 120.0, 0.07, "square", 0.25, 0.6]],
		"block": [[1300.0, 1100.0, 0.06, "tri", 0.3, 0.0]],
		"kill": [[400.0, 60.0, 0.26, "noise", 0.45, 0.8]],
		"hurt": [[420.0, 110.0, 0.24, "saw", 0.35, 0.3]],
		"die": [[500.0, 40.0, 0.9, "saw", 0.4, 0.4]],
		"coin": [[980.0, 980.0, 0.05, "square", 0.18, 0.0], [1470.0, 1470.0, 0.09, "square", 0.18, 0.0]],
		"chest": [[523.0, 523.0, 0.08, "tri", 0.4, 0.0], [659.0, 659.0, 0.08, "tri", 0.4, 0.0], [784.0, 784.0, 0.08, "tri", 0.4, 0.0], [1046.0, 1046.0, 0.2, "tri", 0.4, 0.0]],
		"heal": [[400.0, 800.0, 0.3, "sine", 0.4, 0.0]],
		"save": [[392.0, 392.0, 0.12, "sine", 0.4, 0.0], [523.0, 523.0, 0.12, "sine", 0.4, 0.0], [784.0, 784.0, 0.3, "sine", 0.4, 0.0]],
		"unlock": [[392.0, 392.0, 0.12, "tri", 0.45, 0.0], [494.0, 494.0, 0.12, "tri", 0.45, 0.0], [587.0, 587.0, 0.12, "tri", 0.45, 0.0], [784.0, 784.0, 0.45, "tri", 0.45, 0.0]],
		"buy": [[700.0, 700.0, 0.06, "square", 0.2, 0.0], [1050.0, 1050.0, 0.12, "square", 0.2, 0.0]],
		"deny": [[140.0, 120.0, 0.2, "square", 0.25, 0.0]],
		"select": [[800.0, 900.0, 0.04, "sine", 0.25, 0.0]],
		"break": [[300.0, 80.0, 0.32, "noise", 0.5, 0.9]],
		"roar": [[120.0, 60.0, 0.9, "saw", 0.45, 0.5]],
		"slam": [[110.0, 40.0, 0.32, "square", 0.45, 0.6]],
		"fireball": [[400.0, 150.0, 0.14, "noise", 0.3, 0.7]],
		"bow": [[600.0, 300.0, 0.08, "tri", 0.3, 0.2]],
		"spit": [[300.0, 500.0, 0.1, "square", 0.2, 0.4]],
		"crystal": [[1500.0, 2100.0, 0.16, "sine", 0.3, 0.0]],
		"charge": [[200.0, 500.0, 0.22, "saw", 0.25, 0.3]],
		"growl": [[90.0, 70.0, 0.25, "saw", 0.3, 0.6]],
		"rumble": [[80.0, 50.0, 0.6, "noise", 0.5, 0.95]],
		"beam": [[900.0, 1300.0, 0.4, "saw", 0.25, 0.3]],
		"wave": [[200.0, 400.0, 0.5, "noise", 0.4, 0.9]],
		"wind": [[500.0, 900.0, 0.8, "noise", 0.3, 1.0]],
	}
	for k in defs.keys():
		streams[k] = _make(defs[k])
