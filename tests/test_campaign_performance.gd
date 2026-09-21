extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	game=preload("res://scripts/main.gd").new(); game.progress.save_path="user://campaign_perf_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_run(); game.player.set_physics_process(false)
	var results: Array=[]
	for number in [27,30]:
		game.level=number; game.world.weather.wake(number); game.intermission=true; game.set_mode("playing"); game.player.position=game.world.exterior_rally_point; game.begin_wave()
		game.player.yaw=1.5; game.player._update_rotation()
		game.campaign.event="none"
		game.frighten_wildlife(game.player.position,100)
		for wolf in game.wolves: wolf.hear_gunshot(game.player.position)
		var start:=Time.get_ticks_msec(); var previous:=Time.get_ticks_usec()
		var frames: Array[float]=[]
		while Time.get_ticks_msec()-start<10000:
			await process_frame
			var now:=Time.get_ticks_usec()
			if Time.get_ticks_msec()-start>2000: frames.append((now-previous)/1000.0)
			previous=now
			game.health=game.maximum_health()
			if game.mode=="paused": game.set_mode("playing")
		var total:=0.0
		for ms in frames: total+=ms
		frames.sort()
		var result: Dictionary={"wave":number,"frames":frames.size(),"mean_fps":1000/(total/frames.size()),"p95_ms":frames[int(frames.size()*.95)],"max_ms":frames.back(),"wolves":game.wolves.size(),"new_threats":game.nodes_in_group("campaign_threats").size(),"renderer":RenderingServer.get_video_adapter_name()}
		results.append(result); print(JSON.stringify(result))
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/campaign"))
		root.get_texture().get_image().save_png("res://qa/campaign/wave-%d.png"%number)
	var file=FileAccess.open("res://qa/campaign/performance.json",FileAccess.WRITE); file.store_string(JSON.stringify(results,"  ")); file.close()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; quit()
