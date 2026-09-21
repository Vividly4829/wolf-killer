extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=preload("res://scripts/main.gd").new(); game.progress.transient=true; game.progress.save_path="user://armory_preview_unused.cfg"
	root.add_child(game); game.start_run(true); game.set_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	game.world.weather.hour=17; game.world.weather.apply()
	game.player.position=game.world.exterior_rally_point
	game.player.yaw=PI; game.player.pitch=0; game.player._update_rotation()
	game.dialogue_left=0; game.notice_left=0; game.reload_left=0; game.shot_review.reset_history()
	game.select_weapon(30); game.player._reload_time=0
	await create_timer(.8).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/naval-first-person.png")
	game.select_weapon(26)
	await create_timer(.6).timeout
	var a: Vector3=game.player.weapon.to_global(game.player.weapon.muzzle_position)
	var b: Vector3=game.player.camera.global_position-game.player.camera.global_basis.z*45
	game.beam_effect(a,b)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/red-laser-first-person.png")
	game.queue_free()
	for i in 6: await process_frame
	quit()
