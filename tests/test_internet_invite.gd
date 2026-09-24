extends SceneTree
var game: Node3D
var failed:=false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label); failed=failed or not ok
func wait_for(test: Callable,seconds: float=50) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while not test.call() and Time.get_ticks_msec()<until: await create_timer(.2).timeout
	return test.call()
func run() -> void:
	var args:=OS.get_cmdline_user_args(); var host:=args.has("--host")
	game=preload("res://scripts/main.gd").new(); game.progress.transient=true; root.add_child(game)
	game.player.set_physics_process(false)
	if host:
		game.coop.internet.host()
		check(await wait_for(func(): return not game.coop.internet.invite.is_empty(),175),"public TLS invite ready")
		if failed: await finish(); return
		var file:=FileAccess.open("res://qa/test-invite.txt",FileAccess.WRITE); file.store_string(game.coop.internet.invite); file.close()
		check(await wait_for(func(): return game.coop.avatars.size()==3 and game.coop.avatars.values().all(func(a): return a.has_meta("start_money_applied")),80),"host plus three internet clients joined")
		if not failed:
			game.set_process(false); game.campaign.set_process(false)
			var actor=game.supernatural.spawn("angel",Vector3(140,80,140)); actor.set_physics_process(false)
			actor.health=321
			for id in game.coop.avatars:
				game.rituals.give(id,"wolf"); game.rituals.give(id,"wolf")
			var boat: Dictionary=game.boats.fleet[0]
			game.player.position=boat.shore
			for id in game.coop.avatars:
				game.coop.avatars[id].position=boat.shore
				game.coop.send_to(id,"correct_position",[boat.shore])
			check(game.boats.request(1),"internet host boards boat")
			check(await wait_for(func(): return boat.riders.size()==4,40),"four internet players share the boat")
			boat.p=Vector3(180,-.05,130); game.boats.place_riders()
			for step in 100:
				game.boats.control(1,Vector2(0,-1),false)
				await create_timer(.05).timeout
			check(boat.p.z<120,"internet host drives boat across open sea")
			await create_timer(3).timeout
			actor.damage(1000,true)
			await create_timer(8).timeout
	else:
		var invite:=FileAccess.get_file_as_string("res://qa/test-invite.txt").strip_edges()
		game.coop.join_session(invite)
		check(await wait_for(func(): return game.coop.active and not game.coop.awaiting_spawn and game.mode!="connecting"),"client spawned through public relay")
		if not failed:
			check(await wait_for(func(): return game.rituals.count("wolf")==2),"ritual stacks replicated")
			check(await wait_for(func(): return game.coop.replicas.values().any(func(a): return a.get("species")=="angel" and is_equal_approx(a.health,321))),"angel and health replicate")
			check(await wait_for(func(): return game.boats.fleet[0].riders.has(1) and game.player.position.distance_to(game.boats.fleet[0].p)<4.3),"internet boat and shore spawn replicate")
			game.boats.interact()
			check(await wait_for(func(): return game.boats.fleet[0].riders.size()==4),"all internet passengers replicate")
			check(await wait_for(func(): return game.boats.fleet[0].p.x>170 and game.boats.fleet[0].p.z<120),"internet boat movement replicates")
			check(game.player.position.distance_to(game.boats.fleet[0].p)<2,"internet passenger stays aboard")
			check(await wait_for(func(): return game.coop.replicas.values().any(func(a): return a.get("species")=="angel" and a.dead)),"angel death replicated")
			await create_timer(2).timeout
	await finish()
func finish() -> void:
	game.coop.leave(); game.queue_free(); await process_frame
	print("INTERNET_TEST failures=",failed); quit(1 if failed else 0)
