extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func wait_for(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+45000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	return predicate.call()
func fail(message: String) -> void:
	push_error(message); game.coop.leave(); quit(1)
func run() -> void:
	var host:=OS.get_cmdline_user_args().has("--host")
	game=load("res://scripts/main.gd").new(); game.progress.transient=true; root.add_child(game)
	game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false); game.supernatural.set_process(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): game.coop.port=int(arg.get_slice("=",1))
	if host: game.coop.host_session()
	else: game.coop.join_session("127.0.0.1")
	if not await wait_for(func():return not game.coop.avatars.is_empty()): fail("Connection timeout"); return
	await create_timer(2).timeout
	if host:
		var id: int=game.coop.avatars.keys()[0]
		var avatar=game.coop.avatars[id]
		if not await wait_for(func():return avatar.is_crouching and avatar.jump_height>.7): fail("Guest pose RPC missing"); return
		game.player.is_crouching=true; game.player._jump_height=.6; game.player.position.y+=.6
		if not await wait_for(func():return avatar.health<=0): fail("Down RPC missing"); return
		game.player._jump_height=0; game.player.position=avatar.position+Vector3(.6,0,0)
		game.player.settle_downed()
		if not game.coop.revive_teammate(1,id): fail("Grounded revive failed"); return
		await create_timer(.5).timeout
		if avatar.health!=10: fail("Revive state lost"); return
	else:
		game.player.is_crouching=true; game.player._jump_height=.8; game.player.position.y+=.8
		game.progress.owned.append(37)
		if not await wait_for(func():return game.coop.avatars[1].is_crouching and game.coop.avatars[1].jump_height>.5): fail("Host animation snapshot missing"); return
		game.player._jump_height=0; game.player.settle_downed()
		game._apply_health_damage(10000,false)
		if not await wait_for(func():return game.health==10): fail("Revive RPC missing"); return
		if not game.progress.owned.has(37): fail("Revive lost weapon"); return
		await create_timer(2).timeout
	print("POSE_NETWORK_PASS ","host" if host else "client")
	game.coop.leave(); quit()
