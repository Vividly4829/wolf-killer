extends SceneTree
# Windows playback run (still no window): --headless --audio-driver WASAPI.
# The default Dummy driver does not drain queued audio playback objects.

const Soundscape = preload("res://scripts/soundscape.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func run_checks() -> void:
	# Muting affects this isolated headless process only, not the running game.
	AudioServer.set_bus_mute(0, true)
	seed(398430)
	var sounds := Soundscape.new()
	root.add_child(sounds)
	sounds.silent = false
	var stream: AudioStream = sounds.samples.howl
	check(stream is AudioStreamMP3 and stream == Soundscape.WOLF_HOWL and stream.resource_path.ends_with("wolf_howl_denali.mp3"), "Howling uses the imported Denali field recording rather than a generated waveform")
	check(stream.get_length() > 7.0 and stream.get_length() < 10.0, "The complete natural howl has the expected approximately eight-second duration")
	check(not (stream as AudioStreamMP3).loop and (stream as AudioStreamMP3).data.size() > 100000, "The recording contains MP3 audio data and cannot loop")
	var decoder: AudioStreamPlayback = stream.instantiate_playback()
	decoder.start(0.0)
	var decoded: PackedVector2Array = decoder.mix_audio(1.0, ceili((stream.get_length() + .1) * AudioServer.get_mix_rate()))
	var peak := 0.0
	var square_sum := 0.0
	var nonzero := 0
	var clipped := 0
	for frame: Vector2 in decoded:
		var amplitude := maxf(absf(frame.x), absf(frame.y))
		peak = maxf(peak, amplitude)
		square_sum += frame.x * frame.x + frame.y * frame.y
		if amplitude > .00001: nonzero += 1
		if amplitude >= .9995: clipped += 1
	var rms := sqrt(square_sum / maxf(1.0, decoded.size() * 2.0))
	check(decoded.size() > 100000 and nonzero > 1000 and rms > .00001, "Godot decodes the imported field recording into real non-silent PCM samples")
	check(float(clipped) / maxf(1.0, decoded.size()) < .01, "The source recording is not dominated by clipped samples")
	print("HOWL_PCM: %d frames; %d nonzero; peak %.4f (%.2f dBFS); RMS %.4f (%.2f dBFS); clipped %d" % [decoded.size(), nonzero, peak, linear_to_db(peak), rms, linear_to_db(rms), clipped])
	decoder.stop()
	decoder = null
	var source := Vector3(8.0, 2.0, -12.0)
	var before_start := Time.get_ticks_msec()
	sounds.play_at("howl", source, -9.0, 2.0)
	await physics_frame
	await physics_frame
	check(sounds.howl_voice.playing and sounds.howl_voice.stream == stream, "An eligible howl starts the real recording")
	check(sounds.howl_voice.global_position.is_equal_approx(source) and sounds.howl_voice.max_distance == 110.0 and sounds.howl_voice.unit_size == 14.0, "The dedicated howl emitter retains the wolf's world position and long-distance attenuation")
	check(is_equal_approx(sounds.howl_voice.volume_db, -12.0), "Howls play three decibels below their requested call volume")
	check(sounds.howl_voice.pitch_scale >= 1.06 * .99 and sounds.howl_voice.pitch_scale <= 1.06 * 1.01, "An extreme high individual pitch is restrained to the natural recording range")
	check(sounds._next_howl_at >= before_start + 14000 and sounds._next_howl_at <= Time.get_ticks_msec() + 21000, "Starting a howl reserves a global fourteen-to-twenty-one-second interval")
	check(sounds.spatial_index == 0 and not sounds.spatial_voices.has(sounds.howl_voice), "A howl uses no bark/growl pool slot")
	var playback: AudioStreamPlayback = sounds.howl_voice.get_stream_playback()
	var original_pitch: float = sounds.howl_voice.pitch_scale
	sounds._next_howl_at = 0
	for caller: int in 24:
		sounds.play_at("howl", Vector3(caller, 0, 5), -2.0, .3)
	check(sounds.howl_voice.get_stream_playback() == playback and sounds.howl_voice.global_position == source and is_equal_approx(sounds.howl_voice.pitch_scale, original_pitch) and sounds._next_howl_at == 0, "Twenty-four other wolves cannot stack, restart or relocate an already active howl even when the cooldown has expired")
	for bark: int in 12:
		sounds.play_at("bark", Vector3(bark, 0, 0), -18.0)
	await physics_frame
	check(sounds.spatial_index == 12 and sounds.howl_voice.playing and sounds.howl_voice.get_stream_playback() == playback and sounds.howl_voice.global_position == source, "Cycling past the entire bark pool does not interrupt the howl")
	sounds.set_context(false, false)
	var paused_position: float = sounds.howl_voice.get_playback_position()
	await create_timer(.08).timeout
	# Godot reports playing=false while a stream is paused; its playback object
	# and position establish that it was suspended rather than stopped/replaced.
	check(sounds.howl_voice.stream_paused and sounds.howl_voice.get_stream_playback() == playback, "Pausing suspends the active howl without discarding its playback")
	check(absf(sounds.howl_voice.get_playback_position() - paused_position) < .03, "The paused recording does not keep advancing")
	sounds.set_context(true, true)
	await create_timer(.08).timeout
	check(not sounds.howl_voice.stream_paused and sounds.howl_voice.playing and sounds.howl_voice.get_stream_playback() == playback, "Resuming continues the same spatial recording")
	check(sounds.howl_voice.get_playback_position() > paused_position + .01, "Resume advances the preserved recording position instead of restarting or remaining stuck")
	sounds.howl_voice.stop()
	sounds._next_howl_at = Time.get_ticks_msec() + 1000
	sounds.play_at("howl", Vector3(1, 0, 1), -12.0, .2)
	check(not sounds.howl_voice.playing and sounds.howl_voice.global_position == source, "Cooldown blocks a fresh howl after the preceding one stops")
	sounds._next_howl_at = Time.get_ticks_msec() - 1
	var second_source := Vector3(-7, 3, 9)
	sounds.play_at("howl", second_source, -13.0, .2)
	await physics_frame
	check(sounds.howl_voice.playing and sounds.howl_voice.global_position == second_source, "A later eligible wolf can howl from its own spatial position")
	check(sounds.howl_voice.pitch_scale >= .94 * .99 and sounds.howl_voice.pitch_scale <= .94 * 1.01, "An extreme low individual pitch is also restrained to the natural recording range")
	check(sounds.spatial_index == 12, "Later howls still leave the combat voice pool unchanged")
	sounds.howl_voice.stop()
	sounds.silent = true
	sounds._next_howl_at = 0
	sounds.play_at("howl", Vector3.ZERO)
	check(not sounds.howl_voice.playing, "The existing silent mode still suppresses real howl playback")
	for voice: AudioStreamPlayer3D in sounds.spatial_voices: voice.stop()
	playback = null
	sounds.queue_free()
	await process_frame
	await process_frame
	await create_timer(.04).timeout
	for failure: String in failures: push_error(failure)
	print("%s: %d natural howl audio checks; recording %.3fs; %d failures." % ["PASS" if failures.is_empty() else "FAIL", checks, stream.get_length(), failures.size()])
	quit(0 if failures.is_empty() else 1)
