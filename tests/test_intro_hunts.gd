extends SceneTree
var failures := 0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func start_hunt() -> void:
	game.set_mode("playing")
	game.player.position = game.world.exterior_rally_point
	game.intermission = true
	game.begin_wave()
	for animal in get_nodes_in_group("wildlife"): animal.set_physics_process(false)
func animals(species: String) -> Array:
	return get_nodes_in_group("wildlife").filter(func(a): return not a.is_queued_for_deletion() and not a.dead and a.species==species)
func run() -> void:
	game = preload("res://scripts/main.gd").new()
	game.progress.save_path = "user://intro_hunts_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.start_run()
	start_hunt()
	check(game.level==1 and game.wave_total==1 and game.pending_spawns==0 and game.wolves.is_empty(),"Level one is one deer and no wolves")
	check(animals("deer").size()>=4,"Several deer are available")
	var deer = animals("deer")[0]
	game.player.position = deer.position+Vector3.RIGHT*3
	check(deer.notices(game.player),"Close approach frightens deer")
	game.player.position = deer.position+Vector3.RIGHT*28
	game.player._noise_pulse_left = 1
	game.player._noise_pulse = 1
	check(deer.notices(game.player),"Loud movement is detected farther away")
	game.player._noise_pulse_left = 0
	game.player._movement_noise = .03
	game.player.is_crouching = true
	check(not deer.notices(game.player),"Quiet distant crouching does not automatically reveal player")
	game.frighten_wildlife(deer.position+Vector3.RIGHT*35,60)
	check(deer.fear_left>=12,"Gun report starts sustained flight")
	deer.receive_ballistic_hit(4,deer.to_global(Vector3(-.3,.82,-.38)),deer.global_basis*Vector3.RIGHT,"body",.1)
	var hp: float = deer.health
	var pools: int = game.gore._pools.size()
	deer._physics_process(.6)
	check(not deer.dead and deer.fear_left>0 and deer.health<hp and game.gore._pools.size()>pools,"Wounded deer flees, bleeds and leaves trail")
	var wounded_position: Vector3 = deer.position
	for frame in 120:
		deer._physics_process(1.0/60)
		await process_frame
	check(deer.position.distance_to(wounded_position)>.5,"Injured deer actually moves away along navigation")
	animals("duck")[0].damage(1000)
	check(game.level==1 and game.wave_kills==0,"Wrong species does not complete deer objective")
	deer.damage(1000)
	await process_frame
	check(game.level==2 and game.mode=="resting","One deer completes level one")
	await process_frame
	start_hunt()
	check(game.wave_total==2 and game.wolves.is_empty(),"Level two asks for two deer without wolves")
	animals("deer")[0].damage(1000)
	await process_frame
	check(game.level==2 and game.wave_kills==1,"First of two deer does not advance early")
	animals("deer")[0].damage(1000)
	await process_frame
	check(game.level==3 and game.mode=="resting","Second deer completes level two")
	await process_frame
	start_hunt()
	check(game.wave_total==1 and game.objective_species()=="goose" and game.wolves.is_empty(),"Level three is a goose and no wolves")
	var geese := animals("goose")
	check(geese.size()>=3,"Several water geese provide targets")
	for goose in geese:
		check(goose.aquatic and goose.water_clear(goose.position) and absf(goose.position.y)<.2,"Goose spawns on water")
		goose.frighten(game.world.exterior_rally_point,12)
		for step in 200: goose._physics_process(.05)
		check(goose.water_clear(goose.position),"Startled goose remains in the huntable water area")
	if OS.get_cmdline_user_args().has("--capture"):
		game.world.weather.hour = 12
		game.world.weather.apply()
		game.player.camera.global_position = Vector3(5,2.5,34)
		game.player.camera.look_at(geese[0].position+Vector3.UP*.3)
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/intro-hunts"))
		root.get_texture().get_image().save_png("res://qa/intro-hunts/geese.png")
	geese[0].damage(1000)
	await process_frame
	check(game.level==4 and game.mode=="resting","Water goose completes level three")
	await process_frame
	start_hunt()
	check(game.wave_total==2 and game.wolves.size()==6,"Level four offers six wolves but requires only two")
	var packs: Dictionary={}
	for wolf in game.wolves:
		wolf.set_physics_process(false)
		var pack_id: int=wolf.get_meta("campaign_pack")
		packs[pack_id]=int(packs.get(pack_id,0))+1
	check(packs.size()==3 and packs.values().all(func(n): return n==2),"Six wolves are spread across three pairs")
	check(game.objective_targets().size()==6,"All six choices are marked on the map")
	game.wolves[5].damage(100000)
	check(game.wave_kills==1 and game.level==4,"A wolf outside the first pair counts")
	var extra=game.campaign.spawn_wolf(game.campaign.random_point(40),false,false,999)
	extra.set_physics_process(false)
	check(game.wave_total==2 and game.objective_targets().has(extra),"A surprise wolf is also eligible without raising quota")
	extra.damage(100000)
	await process_frame
	check(game.level==5 and game.mode=="resting","Any two wolves finish the mission without clearing all packs")
	start_hunt()
	check(game.wolves_for_level(5)==3,"Level five still has its authored blood-moon wolves")
	game.damage_player(1000)
	check(game.level==1,"Death returns to the first deer hunt")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
