extends SceneTree
var game: Node3D
var role := "host"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	game = preload("res://scripts/main.gd").new()
	game.progress.save_path = "user://coop_test_%s.cfg" % OS.get_process_id()
	root.add_child(game)
	game.player.set_physics_process(false)
	game.set_process(false)
	if role=="host": game.coop.host_session()
	else: game.coop.join_session("127.0.0.1")
	var deadline := Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		await create_timer(.1).timeout
		if game.coop.avatars.size()==2: break
	if game.coop.avatars.size()!=2: finish(false,"three-player connection"); return
	print("PASS ",role," sees both other hunters")
	if role=="host":
		game.player.position = game.world.nav.point(game.world.nav.at(5,30))
		for id in game.coop.avatars:
			var p: Vector3 = game.world.nav.point(game.world.nav.at(5,34+game.coop.avatars.keys().find(id)*4))
			game.coop.avatars[id].position = p
			game.coop.correct_position.rpc_id(id,p)
		game.begin_wave()
		for wolf in game.wolves: wolf.set_physics_process(false)
		await create_timer(3).timeout
		var first: int = game.coop.avatars.keys()[0]
		game.coop.shooter = 1
		game.coop.friendly_hit(first,17)
		game.coop.award(25)
		await create_timer(1).timeout
		var combined: float = game.health
		for avatar in game.coop.avatars.values(): combined += avatar.health
		var confirmed: bool = game.coop.avatars.size()==2 and combined<=253
		print("COMBINED HEALTH AFTER FRIENDLY FIRE ",combined)
		await create_timer(3).timeout
		finish(confirmed,"friendly fire delivered and returned in health state")
	else:
		await create_timer(1.5).timeout
		if role=="client1":
			game.progress.owned.append(6)
			game.current_weapon = 6
			game.player.set_weapon(6)
			game.player.camera.look_at(game.coop.avatars[1].position+Vector3.UP)
			game.fire_cooldown = 0
			game.fire_weapon()
		await create_timer(3.5).timeout
		var synced: bool = game.wolves.is_empty() and get_nodes_in_group("wildlife").size()>=7 and game.level==1 and game.progress.money>=25
		if role=="client1":
			var reviewed: bool = not game.shot_review.reports.is_empty() and game.shot_review.reports.back().get("species","")=="hunter" and game.shot_review.human.visible
			print("PASS " if reviewed else "FAIL ","remote shooter receives human X-ray")
			synced = synced and reviewed
		print("CLIENT STATE ",role," wolves ",game.wolves.size()," health ",game.health," money ",game.progress.money)
		finish(synced,"shared wave and reward replication")
func finish(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",role," ",label)
	game.coop.leave()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+".bak"))
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
