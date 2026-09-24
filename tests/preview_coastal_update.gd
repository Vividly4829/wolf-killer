extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	var game=load("res://scripts/main.gd").new(); game.progress.save_path="user://coastal_preview.cfg"; root.add_child(game)
	game.set_process(false); game.player.set_physics_process(false); game.hud.hide(); game.shot_review.hide()
	game.world.weather.hour=13; game.world.weather.season=1; game.world.weather.apply()
	var camera:=Camera3D.new(); camera.fov=65; root.add_child(camera); camera.current=true
	var views=[
		["south_cabin",Vector3(9,5.5,71),Vector3(-4,6.5,83)],
		["waterside",Vector3(13,4.0,55),Vector3(0,2.8,66)],
		["west_cabin",Vector3(-50,10,14),Vector3(-64,8,25)],
		["boat",game.boats.fleet[0].p+Vector3(5,3.5,5),game.boats.fleet[0].p]]
	for view in views:
		camera.position=view[1]; camera.look_at(view[2]); await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/coastal-"+view[0]+".png")
	print("COASTAL_PREVIEW_COMPLETE"); game.queue_free(); await process_frame; quit()
