extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	print("PASS " if ok else "FAIL ",caption)
	if not ok: failures+=1
func run() -> void:
	var sounds=load("res://scripts/soundscape.gd").new()
	root.add_child(sounds); sounds.set_process(false)
	var catalog=load("res://scripts/weapon_catalog.gd")
	for weapon in catalog.WEAPONS:
		check(sounds.samples.has(weapon.sound),"weapon has sound: "+weapon.id)
	for kind in sounds.Gunshots.SAMPLES:
		var previous: AudioStream
		for i in 9:
			var sample: AudioStream=sounds.gun_sample(kind)
			check(sample!=previous,"successive "+kind+" shots vary")
			previous=sample
		for sample in sounds.Gunshots.SAMPLES[kind]:
			check(sample.get_length()>=1 and sample.mix_rate==48000,"full-length high-quality "+kind)
	sounds.silent=false
	sounds.play_weapon("musket")
	var blast=sounds.gun_voices[0]
	var sample=blast.stream
	for i in 24: sounds.play("hit",-21)
	check(blast.playing and blast.stream==sample,"pellet impacts cannot cut off gunshot boom")
	check(blast.volume_db==sounds.LOCAL_GUN_DB,"local gun uses punchier gain")
	sounds.play_at("heavy_rifle",Vector3(30,1,0),-8)
	var distant=sounds.gun_spatial[0]
	for i in 16: sounds.play_at("bark",Vector3.ZERO,-18)
	check(distant.playing and distant.global_position==Vector3(30,1,0),"animal voices cannot interrupt positional gunshot")
	sounds.play_weapon("crossbow")
	check(sounds.gun_index==1,"quiet bows retain their own release sound")
	await create_timer(.1).timeout
	sounds.set_context(false,false)
	check(blast.stream_paused and distant.stream_paused,"pausing freezes local and distant gunshot tails")
	sounds.set_context(false,true)
	check(not blast.stream_paused and not distant.stream_paused,"unpausing restores gunshot tails")
	var second=load("res://scripts/soundscape.gd").new(); root.add_child(second); second.set_process(false)
	var limiters:=0
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0,i) is AudioEffectHardLimiter: limiters+=1
	check(limiters==1,"split-screen soundscapes share a single peak limiter")
	await create_timer(2.8).timeout
	for voice in sounds.gun_voices+sounds.gun_spatial+sounds.voices+sounds.spatial_voices: voice.stop()
	sounds.queue_free(); second.queue_free(); await process_frame
	await create_timer(.1).timeout
	quit(1 if failures else 0)
