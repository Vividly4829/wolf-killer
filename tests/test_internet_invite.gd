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
		check(await wait_for(func(): return game.coop.avatars.size()==3,80),"host plus three internet clients joined")
		if not failed:
			var actor=game.supernatural.spawn("angel",Vector3(140,80,140)); actor.set_physics_process(false)
			actor.health=321
			for id in game.coop.avatars:
				game.rituals.give(id,"wolf"); game.rituals.give(id,"wolf")
			await create_timer(8).timeout
			actor.damage(1000,true)
			await create_timer(8).timeout
	else:
		var invite:=FileAccess.get_file_as_string("res://qa/test-invite.txt").strip_edges()
		game.coop.join_session(invite)
		check(await wait_for(func(): return game.coop.active and not game.coop.awaiting_spawn and game.mode!="connecting"),"client spawned through public relay")
		if not failed:
			check(await wait_for(func(): return game.rituals.count("wolf")==2),"ritual stacks replicated")
			check(await wait_for(func(): return game.coop.replicas.values().any(func(a): return a.get("species")=="angel" and is_equal_approx(a.health,321))),"angel and health replicate")
			check(await wait_for(func(): return game.coop.replicas.values().any(func(a): return a.get("species")=="angel" and a.dead)),"angel death replicated")
			await create_timer(2).timeout
	await finish()
func finish() -> void:
	game.coop.leave(); game.queue_free(); await process_frame
	print("INTERNET_TEST failures=",failed); quit(1 if failed else 0)
