extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=preload("res://scripts/main.gd").new(); game.progress.transient=true; root.add_child(game)
	game.progress.resume_level=8; game.progress.money=1750; game.hud.refresh_panel()
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/continue-menu.png")
	game.health=0; game.death_level=8; game.set_mode("dead")
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/paid-revive-menu.png")
	game.queue_free(); await process_frame; quit()
