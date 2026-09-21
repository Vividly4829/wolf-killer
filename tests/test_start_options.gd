extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://start_options_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	var level: SpinBox=game.hud.overlay.get_node("StartingLevel")
	var money: SpinBox=game.hud.overlay.get_node("StartingMoney")
	check(level.value==1 and int(money.value)==game.progress.money,"menu defaults to level one and saved credits")
	level.value=10; money.value=1500
	check(game.menu_start_level==10 and game.menu_start_money==1500,"menu changes update the selected settings")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(.3).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/start-options-menu.png")
	game.start_from_menu()
	check(game.level==10 and game.progress.money==1500 and game.intermission and game.is_player_safe(),"custom expedition starts safely in bed at level ten with 1500 credits")
	check(game.world.weather.blood_moon,"selected level initializes its matching moon weather")
	var saved:=ConfigFile.new(); saved.load(game.progress.save_path)
	check(saved.get_value("progress","money")==1500,"selected credits are saved only when starting")
	game.player.position=game.world.exterior_rally_point; game.begin_wave()
	check(game.campaign.job.number==10,"leaving cabin begins the selected mission")
	game.progress.money=1375; game.damage_player(100000); game.start_run()
	check(game.level==1 and game.progress.money==1375,"death retry resets level one without regranting credits")
	game.set_mode("menu")
	check(int(game.hud.overlay.get_node("StartingMoney").value)==1375,"returning menu shows current wallet")
	game.hud.overlay.get_node("StartingMoney").value=0; game.start_from_menu()
	check(game.progress.money==0,"zero starting credits is supported")
	game.set_mode("menu"); game.menu_start_level=7; game.menu_start_money=2200
	var session=preload("res://scripts/split_session.gd").new()
	session.secondary_save_path="user://start_options_guest_%d.cfg"%OS.get_process_id()
	root.add_child(session); await session.launch(game)
	for local in session.games:
		local.set_process(false); local.player.set_physics_process(false)
		check(local.level==7 and local.progress.money==2200 and local.mode=="playing","split hunter receives selected level and credits")
	check(session.games[0].player.position.distance_to(session.games[1].player.position)>5,"split hunters still start in separate buildings")
	for local in session.games:
		local.coop.leave(); set_multiplayer(null,local.get_path())
		for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(local.progress.save_path+suffix))
	session.queue_free(); await process_frame
	print("START_OPTIONS failures=",failures); quit(1 if failures else 0)
