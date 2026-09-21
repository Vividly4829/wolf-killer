extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	var game = preload("res://scripts/main.gd").new()
	game.progress.save_path = "user://polish_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.position = game.world.exterior_rally_point
	game.begin_wave()
	var deer := 0
	var distant := 0
	for animal in get_nodes_in_group("wildlife"):
		animal.set_physics_process(false)
		if animal.species=="deer": deer += 1
		if animal.position.distance_to(game.world.exterior_rally_point)>65: distant += 1
	check(deer==10 and get_nodes_in_group("wildlife").size()==20,"level one has ten deer and ten ambient animals")
	check(distant>=3 and game.wave_total==1,"distant wildlife does not increase objective quota")
	for route in game.world.exploration_data.bridges:
		var a := Vector3(route.a[0],route.a[1],route.a[2])
		var b := Vector3(route.b[0],route.b[1],route.b[2])
		var error := 0.0
		for step in range(1,100):
			var p := a.lerp(b,step/100.0)
			error = maxf(error,absf(game.world.nav.height_at(p.x,p.z)-p.y))
		check(error<.03,route.name+" walking height matches continuous deck")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	game.dialogue_left = 0
	game.notice_left = 0
	game.world.weather.hour = 12
	game.world.weather.apply()
	root.size = Vector2i(1280,720)
	for index in 18:
		game.current_weapon = index
		game.player.set_weapon(index)
		for frame in 20: game.player._physics_process(1.0/60)
		var p: Vector3 = game.player.weapon.transform*game.player.weapon.model_meta.sight
		check(absf(p.x)<.001 and absf(p.y)<.001,"weapon %d sight centered in camera"%index)
		if OS.get_cmdline_user_args().has("--capture") and index in [0,7,15]:
			await create_timer(.2).timeout
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/playtest-polish"))
			root.get_texture().get_image().save_png("res://qa/playtest-polish/ads-%d.png"%index)
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
