extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	var game := preload("res://scripts/main.gd").new()
	game.progress.save_path = "user://free_play_test_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.progress.money = 432
	game.progress.owned.assign([0,6])
	game.progress.save_progress()
	var campaign = game.progress
	var original := FileAccess.get_file_as_bytes(campaign.save_path)
	game.start_free_play()
	check(game.free_play and game.progress.owned.size()==27 and game.progress.transient,"All weapons in an unsaved Free Play inventory")
	check(game.world.shooting_range.firing_point.length()>10 and game.world.nav.distances[game.world.nav.at(game.player.position.x,game.player.position.z)]>=0,"Range lies on connected walkable land")
	check(game.wolves.size()==3 and get_nodes_in_group("wildlife").size()>=6,"Practice animals and wolves are present")
	game.begin_wave()
	game._process(1)
	check(game.pending_spawns==0 and game.wave_total==0 and not game.intermission,"Free Play does not start campaign objectives")
	for wolf in game.wolves:
		wolf.set_physics_process(false)
		wolf.position = game.player.position+Vector3(1,0,0)
		wolf.hear_gunshot(game.player.position)
		for frame in 180: wolf._physics_process(1.0/60)
		check(not wolf.alerted and not game.is_struggling() and game.health==100,"Practice wolf never attacks, even after a shot")
		wolf.position += Vector3(0,0,15)
	await physics_frame
	await physics_frame
	for target in game.world.shooting_range.targets:
		var point: Vector3 = target.position+Vector3.UP*1.5
		var origin: Vector3 = game.player.position+Vector3.UP*1.65
		var query := PhysicsRayQueryParameters3D.create(origin,point,3)
		query.collide_with_areas = true
		# Validate the lane geometry independently of randomly wandering practice animals.
		for animal in game.wolves+game.nodes_in_group("wildlife"):
			for area in animal.find_children("*","Area3D",true,false): query.exclude += [area.get_rid()]
		var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider.get_meta("wolf",null)==target,"Target has an unobstructed shooting lane: "+target.distance_label)
		if not hit.is_empty():
			game.shot_review.begin_shot()
			game.resolve_weapon_hit(hit,(point-origin).normalized(),game.weapon_spec(),origin.distance_to(point))
		check(target.hits==1,"Target registers shot score and damage")
	game.reserve_ammo[0] = 0
	game._process(.1)
	check(game.reserve_ammo[0]>0,"Ammo reserves replenish while reload mechanics remain")
	game.wolves[0].damage(10000)
	game.progress.money += 999
	game.progress.save_progress()
	check(FileAccess.get_file_as_bytes(campaign.save_path)==original,"Practice writes cannot alter campaign save bytes")
	if OS.get_cmdline_user_args().has("--capture"):
		game.player.yaw = game.world.shooting_range.facing_yaw
		game.player.pitch = 0
		game.player._update_rotation()
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/free-play"))
		root.get_texture().get_image().save_png("res://qa/free-play/range.png")
	game.return_to_menu()
	if OS.get_cmdline_user_args().has("--capture"):
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/free-play/menu.png")
	check(not game.free_play and game.progress==campaign and game.progress.money==432 and game.progress.owned==[0,6],"Leaving Free Play restores original money and ownership")
	game.start_run()
	check(not game.free_play and game.level==1 and game.progress.owned==[0,6],"Campaign starts normally after Free Play")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign.save_path+suffix))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
