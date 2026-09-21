extends SceneTree
var game: Node3D
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func arena() -> Vector3:
	var nav=game.world.wolf_nav
	for cell in nav.reachable:
		var p: Vector3=nav.point(cell)
		if p.distance_to(game.world.exterior_rally_point)<28: continue
		if nav.line_clear(p.x,p.z,p.x+12,p.z) and nav.line_clear(p.x,p.z,p.x,p.z+4): return p
	return game.world.exterior_rally_point
func run() -> void:
	game=preload("res://scripts/main.gd").new(); game.progress.save_path="user://campaign_runtime_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.set_process(false); game.player.set_physics_process(false)
	game.start_run(); game.level=9; game.intermission=true; game.player.position=game.world.exterior_rally_point; game.begin_wave()
	game.campaign.set_process(false)
	for a in game.nodes_in_group("wildlife"): a.set_physics_process(false)
	var bear=game.nodes_in_group("campaign_threats")[0]; bear.set_physics_process(false)
	var p:=arena(); bear.position=p; bear.home=p; game.player.position=p+Vector3(7,0,0)
	var nav=game.world.nav; game.player.position=nav.point(nav.nearest(game.player.position.x,game.player.position.z,3))
	game.player._movement_noise=.5; bear.hear(game.player.position)
	check(bear.warning>0,"Bear warns before charging")
	var before: Vector3=bear.position
	for frame in 240:
		bear._physics_process(.05)
		if game.health<100: break
		await process_frame
	check(bear.position.distance_to(before)>2,"Bear follows a real navigation route")
	check(game.health<100,"Bear closes and injures hunter")
	bear.queue_free(); await process_frame
	game.health=100
	var raider=game.campaign.spawn_threat("raider",p,false); raider.set_physics_process(false)
	raider.position=p; raider.home=p; game.player.position=nav.point(nav.nearest(p.x+9,p.z,2))
	raider.hear(game.player.position)
	for frame in 800:
		raider._physics_process(.05)
		if game.health<100: break
		await process_frame
	check(game.health<100,"Raider can fire and damage hunter")
	check(raider.cooldown>0,"Raider reload cooldown prevents continuous fire")
	game.player.position=game.world.bed_wake_position
	check(raider.choose_target()!=game.player,"Cabin protects hunter from raider targeting")
	if OS.get_cmdline_user_args().has("--capture"):
		game.health=100; game.world.weather.hour=12; game.world.weather.apply()
		game.player.camera.position=Vector3.ZERO
		var camera=game.player.camera
		camera.global_position=raider.position+Vector3(3,2,5); camera.look_at(raider.position+Vector3.UP)
		await capture("raider")
		var animal=game.campaign.spawn_threat("bear",p+Vector3(4,0,0),true); animal.set_physics_process(false)
		camera.global_position=animal.position+Vector3(4,2,4); camera.look_at(animal.position+Vector3.UP*.9)
		await capture("bear")
		var report: Dictionary=animal.receive_ballistic_hit(1,animal.to_global(Vector3(-1,.92,.48)),animal.global_basis*Vector3.RIGHT,"body",0)
		report.merge({"base_damage":1,"weapon":"QA vital shot","distance":8,"range_factor":1},true)
		game.shot_review.record(report); await capture("bear-xray")
		game.campaign.weather_effect="rain"; game.campaign.apply_weather(); await capture("rain")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; quit(1 if failures else 0)
func capture(label: String) -> void:
	await create_timer(.3).timeout; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/campaign"))
	root.get_texture().get_image().save_png("res://qa/campaign/"+label+".png")
