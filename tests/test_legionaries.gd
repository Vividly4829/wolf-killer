extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://legionary_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_run(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720); AudioServer.set_bus_mute(0,true)
	game.campaign.event="legionaries"; game.level=10; game.campaign.launch_event()
	check(game.nodes_in_group("campaign_threats").is_empty(),"Roman encounter refused through level10")
	game.level=11; game.campaign.event_origin=game.campaign.encounter_point(); game.campaign.launch_event()
	var soldiers=game.nodes_in_group("campaign_threats")
	check(soldiers.size()==6,"level11 platoon has six legionaries")
	for soldier in soldiers: soldier.set_physics_process(false)
	var soldier=soldiers[0]
	check(soldier.species=="legionary" and soldier.model.get_child(0).joints.has("elbowL"),"dedicated articulated Roman model")
	check(soldiers[0].formation_goal(game.player.position)!=soldiers[1].formation_goal(game.player.position),"soldiers have different formation slots")
	var before: float=soldier.health
	var hit: Dictionary=soldier.receive_ballistic_hit(40,soldier.to_global(Vector3(.1,1,.3)),-soldier.global_basis.z,"body",1,1,.4)
	check(hit.zone=="SHIELD BLOCK" and soldier.health==before,"front shield stops low-penetration body shot")
	hit=soldier.receive_ballistic_hit(20,soldier.to_global(Vector3(.1,1,-.3)),soldier.global_basis.z,"body",1,1,.4)
	check(soldier.health<before,"rear body shot bypasses shield")
	check(not soldier.get_meta("mission",false),"optional platoon does not add mission quota")
	game.player.position=game.world.exterior_rally_point
	soldier.position=game.player.position+Vector3(0,0,1.5); soldier.target=game.player; soldier.warning=0; soldier.cooldown=0; soldier.think=10; soldier.reaction.down=0
	var hp: float=game.health; soldier._physics_process(.016)
	check(game.health<hp and soldier.cooldown>0,"legionary deals sword damage at close range")
	if "--capture" in OS.get_cmdline_user_args():
		game.player.yaw=PI; game.player.pitch=0; game.player._update_rotation(); game.notice_left=0; game.dialogue_left=0
		game.world.weather.hour=15; game.world.weather.apply()
		for i in soldiers.size():
			soldiers[i].position=game.player.position+Vector3((i%3-1)*1.4,0,4+(i/3)*1.7); soldiers[i].rotation.y=PI
			soldiers[i].reaction.down=0; soldiers[i].model.rotation=Vector3.ZERO
		await create_timer(.2).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/legionaries.png")
	var guest=preload("res://scripts/main.gd").new(); guest.progress.save_path="user://legionary_guest_%d.cfg"%OS.get_process_id(); root.add_child(guest)
	game.coop.setup_local(guest.coop,1); guest.coop.setup_local(game.coop,2)
	game.coop._peer_connected(2); game.coop.clock+=1; game.coop._process(.2)
	check(guest.coop.replicas.has(soldier.get_instance_id()) and guest.coop.replicas[soldier.get_instance_id()].species=="legionary","co-op creates correct legionary replica")
	soldier.damage(10000); game.coop.clock+=1; game.coop._process(.2)
	check(guest.coop.replicas[soldier.get_instance_id()].dead,"legionary death replicated")
	for local in [game,guest]:
		local.coop.leave()
		for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(local.progress.save_path+suffix))
		local.queue_free()
	await process_frame; await process_frame
	print("LEGIONARIES failures=",failures); quit(1 if failures else 0)
