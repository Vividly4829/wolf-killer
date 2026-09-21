extends SceneTree
var game: Node3D
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failed+=1
func wait_until(predicate: Callable,seconds: float=15) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<end: await create_timer(.1).timeout
	return predicate.call()
func run() -> void:
	game=preload("res://scripts/main.gd").new(); game.progress.save_path="user://campaign_net_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-port="): game.coop.port=int(arg.get_slice("=",1))
	var host:=OS.get_cmdline_user_args().has("--host")
	if host: game.coop.host_session()
	else: game.coop.join_session("127.0.0.1")
	if not await wait_until(func(): return game.coop.avatars.size()==2,35): check(false,"three connected"); await finish(); return
	await create_timer(1).timeout
	if host:
		game.level=26; game.intermission=true; game.set_mode("playing")
		game.player.position=game.world.exterior_rally_point; game.begin_wave()
		for animal in game.nodes_in_group("wildlife"): animal.set_physics_process(false)
		var ids=game.coop.avatars.keys()
		var first=game.campaign.items[0]
		var second=game.campaign.items[1]
		game.coop.avatars[ids[0]].position=first.position; game.coop.correct_position.rpc_id(ids[0],first.position)
		check(await wait_until(func(): return first.taken),"remote discovery counts at its location")
		check(game.level==26 and game.wave_kills==1,"one discovery leaves second site required")
		await create_timer(.5).timeout
		game.coop.avatars[ids[0]].health=0; game.coop.hurt.rpc_id(ids[0],1000)
		game._apply_health_damage(1000)
		check(game.mode=="waiting","dead host keeps mission running")
		game.coop.avatars[ids[1]].position=second.position; game.coop.correct_position.rpc_id(ids[1],second.position)
		check(await wait_until(func(): return game.level==27),"last survivor discovery automatically finishes round")
		check(game.health==100,"host revives after round")
		await create_timer(1).timeout
		check(game.coop.avatars.values().all(func(a): return a.health==100),"both peers revive")
		game.level=1; game.intermission=true; game.set_mode("playing"); game.player.position=game.world.exterior_rally_point; game.begin_wave()
		await create_timer(.7).timeout
		game.nodes_in_group("wildlife").filter(func(a): return a.species=="deer")[0].damage(1000)
		check(await wait_until(func(): return game.level==2),"shared hunt completes directly on kill")
		await create_timer(1).timeout
		game.level=12; game.intermission=true; game.set_mode("playing"); game.player.position=game.world.exterior_rally_point; game.begin_wave()
		for actor in game.nodes_in_group("campaign_threats"): actor.set_physics_process(false)
		await create_timer(3).timeout
	else:
		var end:=Time.get_ticks_msec()+30000
		var saw_found:=false; var saw_next:=false; var saw_hunt:=false
		while Time.get_ticks_msec()<end and game.level!=12:
			if game.health>0 and game.campaign.running and game.level==26:
				if game.campaign.nearby(game.campaign.peer()): game.coop.mission_interact.rpc_id(1)
			saw_found=saw_found or (game.level==26 and int(game.campaign.done.get("sites",0))==1)
			saw_next=saw_next or game.level==27
			saw_hunt=saw_hunt or game.level==2
			await create_timer(.15).timeout
		check(saw_found,"client sees shared discovery count")
		check(saw_next,"client observes automatic recovery round")
		check(saw_hunt,"client observes kill-only hunt completion")
		check(await wait_until(func(): return game.nodes_in_group("campaign_threats").size()>=3,8),"raiders replicate to clients")
		check(game.campaign.job.get("title","")=="Unwelcome Guests","shared mixed mission synced")
	await finish()
func finish() -> void:
	game.coop.leave()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; quit(1 if failed else 0)
