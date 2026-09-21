extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	var anatomy = preload("res://scripts/human_xray.gd")
	var head: Dictionary = anatomy.trace(Vector3(0,1.65,.28),Vector3.FORWARD,40)
	var heart: Dictionary = anatomy.trace(Vector3(-.06,1.20,.28),Vector3.FORWARD,40)
	var leg: Dictionary = anatomy.trace(Vector3(.13,.45,.28),Vector3.FORWARD,40)
	check(head.organs.has("brain") and head.calculated_damage==100,"head trajectory and damage")
	check(heart.organs.has("heart") and heart.calculated_damage==80,"heart trajectory and damage")
	check(leg.organs.is_empty() and leg.calculated_damage==26,"leg trajectory and damage")
	var game = preload("res://scripts/main.gd").new()
	game.progress.save_path = "user://human_xray_test_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.shot_review.begin_shot()
	heart.damage = 80
	heart.base_damage = 40
	heart.distance = 12
	heart.range_factor = 1
	heart.weapon = "TEST REVOLVER"
	game.shot_review.record(heart)
	await create_timer(.1).timeout
	check(game.shot_review.human.visible and not game.shot_review.xray.visible,"human skeleton replaces wolf skeleton")
	check(game.shot_review.caption.contains("FRIENDLY FIRE"),"review identifies friendly fire")
	if OS.get_cmdline_user_args().has("--capture"):
		root.size = Vector2i(1280,720)
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/coop-respawn"))
		root.get_texture().get_image().save_png("res://qa/coop-respawn/human-xray.png")
		game.set_mode("waiting")
		await create_timer(.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/coop-respawn/waiting.png")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
