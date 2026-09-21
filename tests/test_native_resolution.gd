extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func settle() -> void:
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Run this test with the native renderer.")
		quit(1); return
	AudioServer.set_bus_mute(0,true)
	var game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://resolution_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	await settle()
	var monitor:=DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var framebuffer:=root.get_texture().get_image().get_size()
	print("DISPLAY monitor=",monitor," window=",root.size," framebuffer=",framebuffer," canvas=",root.get_visible_rect().size," 3D scale=",root.scaling_3d_scale)
	check(root.mode==Window.MODE_FULLSCREEN,"launches fullscreen automatically")
	check(framebuffer==monitor and root.size==monitor,"solo framebuffer matches the monitor's native pixels")
	check(root.scaling_3d_scale==1.0 and root.content_scale_mode==Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,"3D renders at 100 percent while UI scales separately")
	check(root.get_visible_rect().size.is_equal_approx(Vector2(1280,720)),"readable UI keeps its design coordinates on this 16:9 display")
	game.start_run()
	game.world.weather.hour=12; game.world.weather.apply()
	await settle()
	root.get_texture().get_image().save_png("res://qa/native-resolution-solo.png")
	var session=preload("res://scripts/split_session.gd").new()
	session.secondary_save_path="user://resolution_guest_%d.cfg"%OS.get_process_id()
	root.add_child(session)
	await session.launch(game)
	await settle()
	for view in session.views:
		var render_pixels: Vector2i=view.get_texture().get_image().get_size()
		print("SPLIT physical=",view.size," image=",render_pixels," canvas=",view.get_visible_rect().size)
		check(view.size==Vector2i(monitor.x,monitor.y/2) and render_pixels==view.size,"each hunter renders native half-screen pixels")
		check(view.size_2d_override==Vector2i(1280,360) and view.scaling_3d_scale==1,"split HUD stays readable without reducing camera resolution")
	for hunter in session.games:
		hunter.world.weather.hour=12; hunter.world.weather.apply()
	await settle()
	root.get_texture().get_image().save_png("res://qa/native-resolution-split.png")
	# Exercise GUI input in the real scaled viewport, not just camera sizing.
	var host=session.games[0]
	host.set_mode("paused")
	await settle()
	var button:=Button.new()
	button.position=Vector2(400,100); button.size=Vector2(200,50)
	host.hud.add_child(button)
	var clicked: Array[bool]=[false]
	button.pressed.connect(func(): clicked[0]=true)
	await settle()
	var click_at: Vector2=host.hud.position+(button.position+button.size*.5)*host.hud.scale
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=click_at; event.global_position=click_at
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		session._input(event)
	check(clicked[0],"P1 mouse clicks the correct scaled split-screen control at native resolution")
	button.queue_free()
	host.set_mode("playing")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var yaw_before: float=host.player.yaw
	var motion:=InputEventMouseMotion.new()
	motion.relative=Vector2(4,0); motion.screen_relative=Vector2(12,0)
	session._input(motion)
	check(absf(host.player.yaw-yaw_before+12*host.player.sensitivity)<.0001,"mouse look uses physical motion, independent of 4K UI scaling")
	# F11's windowed mode must resize camera textures and returning fullscreen
	# must restore native resolution, without reconstructing the session.
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1600,900)
	await settle()
	check(session.views[0].size==Vector2i(1600,450),"resizing the window updates split rendering resolution")
	root.mode=Window.MODE_FULLSCREEN
	await settle()
	check(session.views[0].size==Vector2i(monitor.x,monitor.y/2),"returning fullscreen restores native split resolution")
	for hunter in session.games:
		for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(hunter.progress.save_path+suffix))
	session.queue_free()
	await process_frame
	quit(1 if failures else 0)
