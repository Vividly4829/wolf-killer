extends SceneTree
var game: Node3D
var host := false
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	host = OS.get_cmdline_user_args().has("--host")
	game = preload("res://scripts/main.gd").new()
	game.progress.save_path = "user://respawn_test_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	if host: game.coop.host_session()
	else: game.coop.join_session("127.0.0.1")
	var deadline := Time.get_ticks_msec()+45000
	while game.coop.avatars.size()<2 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	check(game.coop.avatars.size()==2,"three peers connected")
	if failures: await finish(); return
	await create_timer(2).timeout
	var spawn: Vector3 = game.player.position
	var wallet: int = game.progress.money
	game.progress.owned.append(6)
	if host:
		var ids: Array = game.coop.avatars.keys()
		check(spawn.distance_to(game.coop.avatars[ids[0]].position)>20 and game.coop.avatars[ids[0]].position.distance_to(game.coop.avatars[ids[1]].position)>20,"three separate building spawns")
		for id in ids:
			check(game.coop.avatars[id].position.distance_to(game.coop.spawn_point(id))<.2,"client at assigned building")
		game.begin_wave()
		for animal in get_nodes_in_group("wildlife"): animal.set_physics_process(false)
		game._apply_health_damage(1000)
		check(game.mode=="waiting" and game.level==1 and game.is_playing(),"dead host continues world while teammates alive")
		var victim = game.coop.avatars[ids[0]]
		game.shot_review.begin_shot()
		var weak: Dictionary=preload("res://scripts/weapon_catalog.gd").weapon(18)
		weak.damage=.1
		game.resolve_weapon_hit({"collider":victim.area,"position":victim.to_global(Vector3(-.06,1.2,.3))},victim.global_basis*Vector3.FORWARD,weak,5,game.shot_review.serial)
		check(not game.shot_review.reports.is_empty() and game.shot_review.reports.back().species=="hunter","friendly fire produces human X-ray report")
		check(victim.health==0 and game.shot_review.reports.back().instant_fatal,"tiny human heart shot is fatal over the network")
		game.coop.friendly_hit(ids[0],1000)
		await create_timer(3).timeout
		check(game.mode=="waiting" and game.level==1 and game.coop.avatars[ids[0]].health==0 and game.coop.avatars[ids[1]].health>0,"one survivor keeps round alive")
		for animal in get_nodes_in_group("wildlife"):
			if animal.species=="deer": game.wildlife_defeated(animal); break
		await create_timer(3).timeout
		check(game.level==2 and game.health==100 and game.mode=="resting","objective revives dead host in next round")
		for id in ids: check(game.coop.avatars[id].health==100 and game.coop.avatars[id].position.distance_to(game.coop.spawn_point(id))<.2,"teammate revived at own building")
		check(not game.progress.owned.has(6) and game.progress.money==wallet,"death loses weapons and retains money")
		game.finish_rest()
		for id in ids: game.coop.friendly_hit(id,1000)
		game._apply_health_damage(1000)
		await create_timer(2).timeout
		check(game.mode=="dead" and game.level==1,"total team wipe resets to level one")
		await create_timer(2).timeout
	else:
		check(spawn.distance_to(game.world.bed_wake_position)>20,"client begins in a different house from host")
		var saw_waiting := false
		deadline = Time.get_ticks_msec()+12000
		while game.level<2 and Time.get_ticks_msec()<deadline:
			saw_waiting = saw_waiting or game.mode=="waiting"
			await create_timer(.1).timeout
		await create_timer(.4).timeout
		check(game.level==2 and game.health==100 and game.mode=="resting","client enters next round healed")
		check(game.player.position.distance_to(spawn)<.2,"client returns to same assigned building")
		if saw_waiting: check(not game.progress.owned.has(6) and game.progress.money==wallet,"dead client keeps wallet and loses weapon")
		else: check(game.progress.owned.has(6),"surviving client keeps weapon")
		deadline = Time.get_ticks_msec()+10000
		while game.mode!="dead" and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
		check(game.mode=="dead" and game.level==1,"client receives team wipe")
		await create_timer(.5).timeout
	await finish()
func finish() -> void:
	game.coop.leave()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+".bak"))
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
