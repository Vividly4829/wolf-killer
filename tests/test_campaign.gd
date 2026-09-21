extends SceneTree
var game: Node3D
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,caption: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL / ",caption)
func start(number: int) -> void:
	game.level=number; game.intermission=true; game.set_mode("playing")
	game.player.position=game.world.exterior_rally_point
	game.health=100; game.world.weather.wake(number); game.begin_wave()
func run() -> void:
	game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://campaign_test_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.set_process(false); game.player.set_physics_process(false)
	game.start_run()
	var c=game.campaign
	c.set_process(false)
	for number in range(1,31):
		start(number)
		await process_frame
		for a in game.nodes_in_group("wildlife")+game.wolves+game.nodes_in_group("campaign_threats"): a.set_physics_process(false)
		check(c.running and c.job.number==number,"Starts wave %d"%number)
		check(game.wave_total>0,"Has objective %d"%number)
		check(game.world.weather.blood_moon==(number%5==0),"Moon schedule %d"%number)
		check(game.wolves.size()>=int(c.job.wolves)+int(c.job.bosses),"Enough wolves, with optional extra packs %d"%number)
		check(c.items.is_empty(),"No pack or cabin search objectives")
		for item in c.items:
			check(game.world.wolf_nav.reachable.has(game.world.wolf_nav.at(item.position.x,item.position.z)),"Reachable mission item %d"%number)
		# Complete the actual kill objectives (using vital hits for the new actors).
		for wolf in game.wolves.duplicate():
			if wolf.get_meta("mission",false): wolf.damage(100000)
		for actor in game.nodes_in_group("campaign_threats"):
			if actor.get_meta("mission",false):
				var organs=preload("res://scripts/human_xray.gd").ORGANS if actor.species=="raider" else preload("res://scripts/wildlife_anatomy.gd").organs("bear")
				var report=actor.receive_ballistic_hit(.1,actor.to_global(organs[0].center-Vector3.RIGHT*.35),actor.global_basis*Vector3.RIGHT,"body",0,1,1.15)
				check(actor.dead and report.instant_fatal,"Vital heart hit is fatal when penetration reaches it")
		# Required hunts count at death without creating a retrieval item.
		for key in c.job.hunt:
			var animals=game.nodes_in_group("wildlife").filter(func(a): return not a.dead and c.species_key(a.species)==key)
			check(animals.size()>=int(c.job.hunt[key]),"Enough animals for %d %s"%[number,key])
			for i in int(c.job.hunt[key]):
				animals[i].damage(1000)
				check(game.level==number,"Finish is deferred until damage resolves")
		check(c.items.size()==int(c.job.sites)+int(c.job.search),"Hunts create no retrieval items")
		if number==26: check(c.items.is_empty() and c.job.hunt.size()==2,"Wave 26 is hunting, no discovery sites")
		# Searches count onsite; no home or destination interaction is needed.
		for item in c.items.duplicate():
			game.player.position=item.position
			var previous: int=game.wave_kills
			check(c.interact(1),"Interact with mission item %d"%number)
			check(item.taken and game.wave_kills==previous+1,"Search counts immediately")
		check(c.job_ready(),"All goals ready %d"%number)
		await process_frame
		check(game.mode==("victory" if number==30 else "resting"),"Round completion mode %d"%number)
		check(game.level==(30 if number==30 else number+1),"Correct next wave %d"%number)
		print("WAVE ",number," checked")
	# Optional encounters never enter quotas; every event dispatch path executes.
	for event in ["wolves","carcass_pack","scent_pack","migration","crossfire","patrol","scout","pursuit","bear","bear_claim","fog","rain","wind","fever"]:
		start(17); await process_frame
		var total: int=game.wave_total
		c.event=event; c.warn_event(); c.launch_event()
		check(c.event_started and game.wave_total==total,"Optional event preserves job: "+event)
		if event=="fever": check(c.fever,"Fever applies")
		if event=="fog": check(game.world.get_node("CoastalAtmosphere").environment.fog_density>.02,"Fog applies")
	# Spoiled carcasses cannot count, but replacement wildlife keeps jobs possible.
	start(11); await process_frame
	for a in game.nodes_in_group("wildlife"):
		if a.species=="deer": a.set_meta("ruined_meat",true); a.damage(1000)
	check(game.wave_kills==0,"Explosive meat excluded")
	c.ensure_huntable()
	check(game.nodes_in_group("wildlife").any(func(a): return a.species=="deer" and not a.dead),"Replacement prey prevents softlock")
	start(12); await process_frame
	var raider=game.nodes_in_group("campaign_threats")[0]
	var report=raider.receive_ballistic_hit(.1,raider.to_global(Vector3(-.15,1.65,0)),raider.global_basis*Vector3.RIGHT,"head",0,1,.42)
	check(raider.dead and report.instant_fatal and report.species=="raider","Raider brain fatal / human xray")
	# Round data can be serialised without objects.
	var state: Dictionary=c.snapshot()
	check(bytes_to_var(var_to_bytes(state))==state,"Mission snapshot serialises")
	start(7); await process_frame
	check(c.items.is_empty() and not c.interact(1),"Removed search cannot produce progress")
	await process_frame
	check(game.level==7 and game.mode=="playing","Only hunt objective advances former mixed-search wave")
	start(2); await process_frame
	var prey=game.nodes_in_group("wildlife").filter(func(a): return a.species=="deer")
	prey[0].damage(1000,false)
	check(game.wave_kills==0,"Predation cannot satisfy a hunt")
	prey[1].damage(1000); c.animal_killed(prey[1])
	await process_frame
	check(game.wave_kills==1 and game.level==2,"Duplicate kill cannot finish quota early")
	start(1); await process_frame
	game.nodes_in_group("wildlife").filter(func(a): return a.species=="deer")[0].damage(1000)
	start(2)
	await process_frame
	check(game.level==2 and game.mode=="playing" and game.wave_kills==0,"Old completion cannot finish new round")
	start(1); await process_frame
	game.nodes_in_group("wildlife").filter(func(a): return a.species=="deer")[0].damage(1000)
	game.progress.money=1234; game.progress.owned.assign([0,1]); game.damage_player(10000)
	await process_frame
	check(game.level==1 and game.progress.money==1234 and game.progress.owned==[0],"Death resets wave and weapons, keeps wallet")
	check(game.mode=="dead" and game.health==0,"Queued completion cannot revive a same-frame death")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	print("CAMPAIGN / ",checks," checks / ",failures," failures")
	game.queue_free(); await process_frame; quit(1 if failures else 0)
