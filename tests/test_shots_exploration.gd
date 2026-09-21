extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	var anatomy = preload("res://scripts/wolf_anatomy.gd")
	check(anatomy.trace(Vector3(-.3,.46,.25),Vector3.RIGHT,.7,"body").organs.has("heart"),"Heart trajectory")
	check(anatomy.trace(Vector3(-.3,.61,.12),Vector3.RIGHT,.7,"body").organs.size()==2,"Broadside double lung")
	check(anatomy.trace(Vector3(-.3,.61,.12),Vector3.RIGHT,.15,"body").organs.size()==1,"Short penetration stops in near lung")
	check(anatomy.trace(Vector3(-.3,.46,.25),Vector3.RIGHT,.7,"front_left").organs.is_empty(),"Leg injury remains localized")
	var game = preload("res://scripts/main.gd").new()
	game.progress = preload("res://scripts/progress_store.gd").new()
	game.progress.save_path = "user://test_shots_exploration_%s.cfg" % OS.get_process_id()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.start_run()
	game.level = 4
	game.player.position = game.world.exterior_rally_point
	game.begin_wave()
	check(game.level==4 and game.wolves.size()==1,"Level four has exactly one wolf")
	for wolf in game.wolves: wolf.set_physics_process(false)
	var nav = game.world.nav
	var t := Time.get_ticks_usec()
	nav.field(game.world.spawn_position.x,game.world.spawn_position.z)
	print("Navigation field ms: ",(Time.get_ticks_usec()-t)/1000.0," reachable: ",nav.reachable.size())
	for route: Dictionary in game.world.exploration_data.bridges:
		var a := Vector3(route.a[0],route.a[1],route.a[2])
		var b := Vector3(route.b[0],route.b[1],route.b[2])
		var i: int = nav.at(b.x,b.z)
		check(nav.valid(i) and nav.distances[i]>=0,route.name+" destination reachable")
		var pos := a
		for step in 600:
			var delta := b-pos
			if Vector2(delta.x,delta.z).length()<.15: break
			delta = delta.normalized()*.15
			pos = nav.move_position(pos,delta.x,delta.z)
		check(Vector2(pos.x-b.x,pos.z-b.z).length()<.3,route.name+" continuous crossing")
		print("Crossing end ",pos," target ",b)
		for route_nav in [nav,game.world.wolf_nav]:
			pos = b
			for step in 600:
				var delta := a-pos
				if Vector2(delta.x,delta.z).length()<.15: break
				delta = delta.normalized()*.15
				pos = route_nav.move_position(pos,delta.x,delta.z)
			check(Vector2(pos.x-a.x,pos.z-a.z).length()<.3,route.name+" return crossing "+("player" if route_nav==nav else "wolf"))
			if Vector2(pos.x-a.x,pos.z-a.z).length()>=.3: print("Stuck at ",pos," toward ",a)
		var wolf_end: int = game.world.wolf_nav.at(b.x,b.z)
		check(game.world.wolf_nav.valid(wolf_end) and game.world.wolf_nav.distances[wolf_end]>=0,route.name+" wolf pursuit connected")
		game.world.wolf_nav.field(a.x,a.z)
		pos = b
		for step in 1500:
			if Vector2(pos.x-a.x,pos.z-a.z).length()<.6: break
			var next: Vector3 = game.world.wolf_nav.next_point(pos.x,pos.z)
			if not next.is_finite(): break
			var delta := next-pos
			delta.y = 0
			delta = delta.normalized()*minf(.15,delta.length())
			pos = game.world.wolf_nav.move_position(pos,delta.x,delta.z)
		check(Vector2(pos.x-a.x,pos.z-a.z).length()<.6,route.name+" follows actual pursuit field")
		if Vector2(pos.x-a.x,pos.z-a.z).length()>=.6: print("Pursuit stuck ",pos," next ",game.world.wolf_nav.next_point(pos.x,pos.z))
	check(not nav.valid(nav.at(90,80)),"Open water remains inaccessible")
	check(not game.world.wolf_nav.valid(game.world.wolf_nav.at(game.world.spawn_position.x,game.world.spawn_position.z)),"Cabin still excludes wolves")
	game.shot_review.begin_shot()
	var target = game.wolves[0]
	target.health = 500
	var report: Dictionary = target.receive_ballistic_hit(30,target.to_global(Vector3(-.3,.46,.25)*target.size_scale),target.global_basis*Vector3.RIGHT,"body",1.0)
	game.shot_review.record(report)
	check(report.organs.has("heart") and target.bleeding_rate>=18,"Actual hit damages heart and causes blood loss")
	check(game.shot_review.reports.size()==1 and game.mode=="playing","X-ray does not pause combat")
	if OS.get_cmdline_user_args().has("--capture"):
		OS.low_processor_usage_mode = false
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		root.size = Vector2i(1280,720)
		root.content_scale_size = Vector2i(1280,720)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		game.player.camera.global_position = Vector3(5,3.0,20)
		game.player.camera.look_at(Vector3(3,1.5,65))
		await create_timer(1).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/shot-exploration"))
		root.get_texture().get_image().save_png("res://qa/shot-exploration/xray-bridge.png")
		game.shot_review.remaining = 100
		var peak := 0.0
		var frames := 0
		var start := Time.get_ticks_usec()
		game.world.wolf_nav.request_field(3,77)
		for frame in 150:
			var before := Time.get_ticks_usec()
			game.world.wolf_nav.pump_field()
			peak = maxf(peak,(Time.get_ticks_usec()-before)/1000.0)
			await process_frame
			frames += 1
		print("Rendered average FPS: ",frames*1000000.0/(Time.get_ticks_usec()-start)," navigation slice peak ms: ",peak)
	game.progress.money = 432
	game.level = 7
	game.damage_player(1000)
	check(game.level==1 and game.progress.money==432 and game.mode=="dead","Death resets level but retains money")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
