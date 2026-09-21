extends SceneTree
var game: Node3D
var host := false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	host = OS.get_cmdline_user_args().has("--host")
	game = preload("res://scripts/main.gd").new()
	game.progress.save_path = "user://coop_loot_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	if host: game.coop.host_session()
	else: game.coop.join_session("127.0.0.1")
	var deadline := Time.get_ticks_msec()+40000
	while game.coop.avatars.is_empty() and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	if game.coop.avatars.is_empty(): finish(false,"connection"); return
	if host:
		var id: int = game.coop.avatars.keys()[0]
		var p: Vector3 = game.world.houses.positions[0]-Vector3.UP*.45
		game.coop.avatars[id].position = p
		game.coop.correct_position.rpc_id(id,p)
		deadline = Time.get_ticks_msec()+12000
		while game.world.houses.drops[0]>=0 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
		if game.world.houses.drops[0]>=0: finish(false,"host-authoritative loot claim"); return
		print("PASS shared pickup removed on host")
		game.level = 5
		game._add_wolf_at(p+Vector3(0,0,2))
		var wolf = game.wolves.back()
		wolf.set_physics_process(false)
		if not wolf.werewolf: wolf.make_werewolf()
		await create_timer(1.5).timeout
		game.coop.begin_remote_maul(wolf,game.coop.avatars[id])
		await create_timer(2).timeout
		game.level = 10
		game.begin_rest()
		await create_timer(3).timeout
		finish(true,"loot and werewolf progression dispatched")
	else:
		deadline = Time.get_ticks_msec()+12000
		while game.world.houses.nearby(game.player.position)!=0 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
		if game.world.houses.nearby(game.player.position)!=0: finish(false,"visible reachable loot"); return
		game.interact_shop()
		deadline = Time.get_ticks_msec()+12000
		while game.progress.owned.size()<2 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
		if game.progress.owned.size()!=2: finish(false,"client pickup ownership"); return
		print("PASS client receives free weapon")
		deadline = Time.get_ticks_msec()+12000
		while game.affliction.infected_wave<0 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
		if game.affliction.infected_wave!=5: finish(false,"remote werewolf bite infection"); return
		print("PASS remote bite infects client")
		while game.level<10 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
		await create_timer(.2).timeout
		finish(game.level==10 and game.health==200 and game.player.supernatural_speed==1.5,"co-op full-moon 200 HP and speed")
func finish(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	game.coop.leave()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
