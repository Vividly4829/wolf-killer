extends Node

const Gunshots = preload("res://scripts/gunshot_bank.gd")
var gun_voices: Array[AudioStreamPlayer] = []
var gun_spatial: Array[AudioStreamPlayer3D] = []
var gun_index := 0
var gun_spatial_index := 0
var last_gun_variant: Dictionary = {}
const LOCAL_GUN_DB := -6.0

const WOLF_HOWL = preload("res://assets/audio/wolf_howl_denali.mp3")
var samples: Dictionary = {}
var score: Array[AudioStreamPlayer] = []
var tension := 0.0
var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var spatial_voices: Array[AudioStreamPlayer3D] = []
var spatial_index: int = 0
var dialogue: AudioStreamPlayer
var wind: AudioStreamPlayer
var silent: bool = false
var howl_voice: AudioStreamPlayer3D
var _next_howl_at: int = 0
var maul_voice: AudioStreamPlayer
var tear_voice: AudioStreamPlayer
var maul_cooldown:=0.0
var last_scream:=0
var last_snarl:=0
var last_tear:=0
var flesh_voices: Array[AudioStreamPlayer] = []
var flesh_index := 0
var last_flesh_variant := -1

func _ready() -> void:
	samples["flame"] = load("res://assets/audio/fire_siphon.wav")
	silent = DisplayServer.get_name() == "headless"
	# One shared limiter also catches simultaneous local/co-op blasts without
	# flattening the ordinary mix. Do not install another for the second viewport.
	var limited:=false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0,i) is AudioEffectHardLimiter: limited=true
	if not limited:
		var limiter:=AudioEffectHardLimiter.new()
		limiter.ceiling_db=-1.0; limiter.release=.12
		AudioServer.add_bus_effect(0,limiter)
	for i in 8:
		var gun:=AudioStreamPlayer.new(); add_child(gun); gun_voices.append(gun)
		var distant:=AudioStreamPlayer3D.new(); add_child(distant); gun_spatial.append(distant)
	for index in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
		var spatial := AudioStreamPlayer3D.new()
		spatial.unit_size = 7.0
		spatial.max_distance = 42.0
		spatial.attenuation_filter_cutoff_hz = 3600
		add_child(spatial)
		spatial_voices.append(spatial)
	# A field recording already contains natural answering calls. Give it its
	# own emitter so barks cannot cut it off and a large pack cannot pile it up.
	howl_voice = AudioStreamPlayer3D.new()
	howl_voice.name = "WolfHowl"
	add_child(howl_voice)
	for kind in Gunshots.SAMPLES: samples[kind]=Gunshots.SAMPLES[kind][0]
	samples["crossbow"] = _crossbow_release()
	for i in 3:
		samples["flesh_hit_%d"%i] = load("res://assets/audio/flesh_hit_%d.wav"%(i+1))
		var impact := AudioStreamPlayer.new(); add_child(impact); flesh_voices.append(impact)
	samples["hurt"] = _synth(0.25, 65.0, 0.3, 12.0)
	samples["coin"] = _synth(0.22, 920.0, 0.0, 13.0)
	samples["reload"] = _synth(0.14, 340.0, 0.38, 27.0)
	samples["wave"] = _synth(0.85, 160.0, 0.05, 4.0)
	samples["bite_tear"] = load("res://assets/audio/bite_tear.wav")
	samples["scream"] = load("res://assets/audio/gun_pain_1.wav")
	for i in 3: samples["gun_pain_%d"%(i+1)]=load("res://assets/audio/gun_pain_%d.wav"%(i+1))
	samples["explosion"]=load("res://assets/audio/explosion_boom.wav")
	for i in 4: samples["snarl_%d"%i]=load("res://assets/audio/wolf_snarl_%d.wav"%(i+1))
	for i in 3: samples["maul_scream_%d"%i]=load("res://assets/audio/maul_scream_%d.wav"%(i+1))
	for i in 4: samples["tear_%d"%i]=load("res://assets/audio/cloth_tear_%d.wav"%(i+1))
	maul_voice=AudioStreamPlayer.new(); add_child(maul_voice)
	tear_voice=AudioStreamPlayer.new(); add_child(tear_voice)
	samples["growl"] = samples.snarl_0
	samples["bark"] = samples.snarl_1 # Recorded sharp canine snarl for close lunges.
	samples["howl"] = WOLF_HOWL
	samples["bear_growl"]=load("res://assets/audio/bear_growl.wav")
	dialogue = AudioStreamPlayer.new()
	dialogue.stream = preload("res://assets/audio/opening_line.wav")
	dialogue.volume_db = -3.0
	add_child(dialogue)
	wind = AudioStreamPlayer.new()
	wind.stream = _wind()
	wind.volume_db = -29
	add_child(wind)
	if not silent:
		wind.play()
		for track in ["island_calm","island_tension"]:
			var music := AudioStreamPlayer.new()
			var stream := load("res://assets/audio/"+track+".wav") as AudioStreamWAV
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = 32*22050
			music.stream = stream
			music.volume_db = -20 if score.is_empty() else -60
			add_child(music)
			score.append(music)
			music.play()

func gun_sample(kind: String) -> AudioStream:
	var variants: Array=Gunshots.SAMPLES[kind]
	var index: int=(int(last_gun_variant.get(kind,-1))+randi_range(1,variants.size()-1))%variants.size()
	last_gun_variant[kind]=index
	return variants[index]

func play_maul(point: Vector3, pitch: float=1.0) -> void:
	if silent: return
	# Dedicated voices preserve screams when bites, coins or footsteps overlap.
	last_tear=(last_tear+randi_range(1,3))%4
	tear_voice.stream=samples["tear_%d"%last_tear]
	tear_voice.volume_db=-7; tear_voice.pitch_scale=randf_range(.9,1.05)
	tear_voice.stream_paused=false; tear_voice.play()
	if not maul_voice.playing and maul_cooldown<=0:
		last_scream=(last_scream+randi_range(1,2))%3
		maul_voice.stream=samples["maul_scream_%d"%last_scream]
		maul_voice.volume_db=-6; maul_voice.pitch_scale=randf_range(.97,1.03)
		maul_voice.stream_paused=false; maul_voice.play()
		maul_cooldown=maul_voice.stream.get_length()+randf_range(.5,1.2)
	play_at("growl",point,-3,pitch)

func play_flesh_hit() -> void:
	if silent or flesh_voices.is_empty(): return
	last_flesh_variant=(last_flesh_variant+randi_range(1,2))%3
	var voice := flesh_voices[flesh_index%flesh_voices.size()]
	flesh_index+=1
	voice.stream=samples["flesh_hit_%d"%last_flesh_variant]
	voice.volume_db=-9.0
	voice.pitch_scale=randf_range(.94,1.06)
	voice.stream_paused=false
	voice.play()

func play_weapon(kind: String) -> void:
	play(kind,LOCAL_GUN_DB if Gunshots.SAMPLES.has(kind) else -12.0)

func play(kind: String, volume: float = -12.0) -> void:
	if kind=="gun_pain": kind="gun_pain_%d"%randi_range(1,3)
	if silent or not samples.has(kind) or voices.is_empty():
		return
	if Gunshots.SAMPLES.has(kind):
		var gun:=gun_voices[gun_index%gun_voices.size()]; gun_index+=1
		gun.stream=gun_sample(kind); gun.volume_db=minf(volume,-4.0)
		gun.pitch_scale=randf_range(.985,1.015); gun.stream_paused=false; gun.play()
		return
	var voice: AudioStreamPlayer = voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = samples[kind]
	voice.volume_db = volume
	voice.pitch_scale = randf_range(0.96, 1.04)
	voice.play()

func play_at(kind: String, point: Vector3, volume: float = -12.0, individual_pitch: float = 1.0) -> void:
	if silent or not samples.has(kind) or spatial_voices.is_empty():
		return
	if kind == "howl":
		_play_howl(point, volume, individual_pitch)
		return
	if Gunshots.SAMPLES.has(kind):
		var gun:=gun_spatial[gun_spatial_index%gun_spatial.size()]; gun_spatial_index+=1
		gun.global_position=point; gun.stream=gun_sample(kind)
		gun.max_distance=180; gun.unit_size=14
		gun.attenuation_filter_cutoff_hz=4200
		gun.volume_db=minf(volume,-4.0)
		gun.pitch_scale=clampf(individual_pitch,.85,1.1)*randf_range(.985,1.015)
		gun.stream_paused=false; gun.play()
		return
	if kind=="growl":
		last_snarl=(last_snarl+randi_range(1,3))%4
		kind="snarl_%d"%last_snarl
	var voice := spatial_voices[spatial_index % spatial_voices.size()]
	spatial_index += 1
	voice.global_position = point
	voice.stream = samples[kind]
	voice.max_distance = 85.0
	voice.unit_size = 18.0 if kind in ["bark","bear_growl"] or kind.begins_with("snarl") else 9.0
	voice.attenuation_filter_cutoff_hz = 6000.0
	voice.volume_db = volume
	voice.pitch_scale = clampf(individual_pitch, 0.75, 1.25) * randf_range(0.96, 1.04)
	voice.stream_paused = false
	voice.play()

func _play_howl(point: Vector3, volume: float, individual_pitch: float) -> void:
	var now := Time.get_ticks_msec()
	if howl_voice.playing or now < _next_howl_at:
		return
	howl_voice.global_position = point
	howl_voice.stream = samples.howl
	howl_voice.max_distance = 110.0
	howl_voice.unit_size = 14.0
	howl_voice.attenuation_filter_cutoff_hz = 4200.0
	howl_voice.volume_db = volume - 3.0
	# Preserve the recording's throat/breath texture; avoid extreme pitch shifts.
	howl_voice.pitch_scale = clampf(individual_pitch, 0.94, 1.06) * randf_range(0.99, 1.01)
	howl_voice.stream_paused = false
	howl_voice.play()
	_next_howl_at = now + int(randf_range(14000.0, 21000.0))

func play_intro() -> float:
	dialogue.stop()
	dialogue.stream_paused = false
	if not silent:
		dialogue.play()
	return dialogue.stream.get_length() + 1.2

func set_context(sheltered: bool, playing: bool) -> void:
	if maul_voice: maul_voice.stream_paused=not playing
	if tear_voice: tear_voice.stream_paused=not playing
	if wind:
		wind.volume_db = -34 if sheltered else -24
		wind.stream_paused = not playing
	if dialogue:
		dialogue.stream_paused = not playing
	for voice in flesh_voices: voice.stream_paused=not playing
	for voice in gun_voices: voice.stream_paused=not playing
	for voice in gun_spatial: voice.stream_paused=not playing
	for voice in spatial_voices:
		voice.stream_paused = not playing
	if howl_voice:
		howl_voice.stream_paused = not playing

func stop_dialogue() -> void:
	if dialogue:
		dialogue.stop()

func _wave_sample(data: PackedByteArray, looping: bool = false) -> AudioStreamWAV:
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 22050
	sample.data = data
	if looping:
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sample.loop_end = data.size() / 2
	return sample

func _growl() -> AudioStreamWAV:
	# Uneven breath noise and subharmonics give a low, rough warning from a
	# spatial emitter, with a soft lead-in instead of a repeated electronic beep.
	var duration := 2.25
	var data := PackedByteArray()
	data.resize(int(duration * 22050) * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 9126
	var breath := 0.0
	var phase := 0.0
	for i in range(data.size() / 2):
		var t := float(i) / 22050.0
		breath = lerpf(breath, random.randf_range(-1, 1), 0.11)
		var frequency := 74.0 + 11.0 * sin(t * 7.3) + 6.0 * sin(t * 31.0)
		phase += TAU * frequency / 22050.0
		var throat := sin(phase) * 0.32 + sin(phase * 0.5 + 0.3) * 0.21 + sin(phase * 2.02) * 0.12
		var envelope := smoothstep(0.0, 0.24, t) * (1.0 - smoothstep(1.58, duration, t))
		envelope *= 0.72 + 0.28 * sin(t * 18.0) * sin(t * 9.1)
		var value := tanh((throat + breath * 2.1) * 1.8) * envelope * 0.75
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	return _wave_sample(data)

func _crossbow_release() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(int(0.38 * 22050) * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 1650
	for i in range(data.size() / 2):
		var t := float(i) / 22050.0
		var twang := sin(TAU * 158.0 * t) * 0.36 + sin(TAU * 319.0 * t) * 0.17 + sin(TAU * 643.0 * t) * 0.08
		var value := twang * exp(-15.0 * t) + random.randf_range(-1.0, 1.0) * exp(-95.0 * t) * 0.3
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767))
	return _wave_sample(data)

func _bark() -> AudioStreamWAV:
	# Two sharp, breathy throaty pulses; original synthesis, not a game asset.
	var data := PackedByteArray()
	data.resize(int(0.68 * 22050) * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 4802
	var phase := 0.0
	var breath := 0.0
	for i in range(data.size() / 2):
		var t := float(i) / 22050.0
		var local := t if t < 0.32 else t - 0.34
		var envelope := smoothstep(0.0, 0.012, local) * exp(-maxf(local, 0.0) * 13.0)
		if local < 0.0:
			envelope = 0.0
		phase += TAU * (175.0 - minf(maxf(local, 0.0), 0.2) * 320.0) / 22050.0
		breath = lerpf(breath, random.randf_range(-1.0, 1.0), 0.4)
		var throat := sin(phase) * 0.48 + sin(phase * 2.0) * 0.3 + sin(phase * 3.0) * 0.2 + sin(phase * 5.0) * 0.10
		var value := tanh((throat + breath * 1.5) * 1.8) * envelope * 0.93
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767))
	return _wave_sample(data)

func _wind() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(22050 * 8 * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 1919
	var low := 0.0
	var high := 0.0
	for i in range(data.size() / 2):
		var t := float(i) / 22050.0
		var noise := random.randf_range(-1, 1)
		low = lerpf(low, noise, 0.009)
		high = lerpf(high, noise, 0.095)
		var envelope := 0.54 + 0.18 * sin(TAU * t / 8) + 0.1 * sin(TAU * t / 4)
		var seam := minf(smoothstep(0, 0.12, t), 1.0 - smoothstep(7.88, 8, t))
		var value := (high - low + low * 2.0) * envelope * seam
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	return _wave_sample(data, true)

func _synth(duration: float, frequency: float, noise_mix: float, decay: float) -> AudioStreamWAV:
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(int(duration * 22050.0) * 2)
	var random := RandomNumberGenerator.new()
	random.seed = int(frequency)
	for i in range(data.size() / 2):
		var t := float(i) / 22050.0
		var value := (sin(TAU * frequency * t * (1.0 - t * 0.5)) * (1.0 - noise_mix) + random.randf_range(-1, 1) * noise_mix) * exp(-decay * t) * 0.65
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	sample.data = data
	return sample

func _process(delta: float) -> void:
	maul_cooldown=maxf(0,maul_cooldown-delta)
	if score.size()!=2: return
	var game = get_parent()
	var alert := false
	for wolf in game.wolves:
		if is_instance_valid(wolf) and wolf.alerted and not wolf.dead: alert = true; break
	for threat in game.nodes_in_group("campaign_threats"):
		if not threat.dead and threat.alerted and threat.position.distance_to(game.player.position)<45: alert=true
	tension = move_toward(tension,1.0 if alert else 0.0,delta*.12)
	score[0].volume_db = lerpf(-20,-28,tension)
	score[1].volume_db = linear_to_db(lerpf(.001,.09,tension))
