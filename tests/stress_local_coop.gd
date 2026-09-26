extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var count:=4 if "--four" in OS.get_cmdline_user_args() else 2
	root.size=Vector2i(3840,2160)
	OS.low_processor_usage_mode=false
	if "--vsync-off" in OS.get_cmdline_user_args(): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var original=load("res://scripts/main.gd").new()
	original.progress.transient=true
	original.progress.save_path="user://stress_unused.cfg"
	root.add_child(original)
	var session=load("res://scripts/split_session.gd").new()
	session.secondary_save_path="user://stress_%d.cfg"%OS.get_process_id()
	root.add_child(session)
	await session.launch(original,count)
	for game in session.games: game.progress.transient=true
	var host=session.games[0]
	seed(26092026); host.campaign.rng.seed=26092026
	host.player.position=host.world.exterior_rally_point
	host.level=28; host.intermission=true; host.set_mode("playing"); host.begin_wave()
	host.campaign.event="none"
	for cat in host.guardians.cats: cat.hp=0; cat.node.fallen=true
	for i in count:
		var game=session.games[i]
		game.player.position=host.world.exterior_rally_point+Vector3(i*2,0,0)
		game.player.set_physics_process(false)
	for wolf in host.wolves: wolf.hear_gunshot(host.player.position)
	var start:=Time.get_ticks_msec(); var previous:=Time.get_ticks_usec()
	var frames:Array[float]=[]
	while Time.get_ticks_msec()-start<14000:
		await process_frame
		var now:=Time.get_ticks_usec()
		if Time.get_ticks_msec()-start>4000: frames.append((now-previous)/1000.0)
		previous=now
		for game in session.games:
			game.health=100000.0
			if game.mode=="paused": game.set_mode("playing")
	var total:=0.0
	for ms in frames: total+=ms
	frames.sort()
	print("STRESS_RESULT ",JSON.stringify({"players":count,"resolution":str(root.size),"frames":frames.size(),"fps":1000.0*frames.size()/total,"p95_ms":frames[int(frames.size()*.95)],"max_ms":frames.back(),"wolves":host.wolves.size(),"wildlife":host.nodes_in_group("wildlife").size(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"gpu":RenderingServer.get_video_adapter_name()}))
	for game in session.games:
		if "stress_" in game.progress.save_path:
			for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	quit()
