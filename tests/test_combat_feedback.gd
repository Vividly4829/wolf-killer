extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://combat_feedback_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	for actor in game.wolves+game.nodes_in_group("wildlife"): actor.set_physics_process(false)
	var wolf=game.wolves[0]
	wolf.position=game.player.position+Vector3(4,0,0)
	game.coop.apply_animal_life(wolf,{"health":40,"max_health":100,"dead":false,"down":2.5,"flinch":.3,"behavior":"recover"})
	check(is_instance_valid(wolf.reaction) and wolf.reaction.down==2.5,"replica creates reaction even with physics disabled")
	var limb: String=wolf.LEG_BONES.keys()[0]
	game.coop.apply_animal_life(wolf,{"health":40,"dead":false,"severed":[limb],"injuries":{limb:.8}})
	check(wolf.severed_legs.has(limb) and wolf.leg_injuries[limb]==.8,"replica receives severed limb and injury state")
	game.coop.apply_animal_life(wolf,{"health":0,"dead":true})
	wolf.reaction._process(.3)
	check(wolf.dead and wolf.reaction.falling and absf(wolf.model.rotation.z)>1,"replicated death visibly collapses wolf")
	game.coop.apply_animal_life(wolf,{"health":0,"dead":true})
	check(not game.radar_animals().has(wolf),"dead animal removed from radar")
	var deer=game.nodes_in_group("wildlife")[0]
	deer.position=game.player.position+Vector3(74,0,0)
	check(game.radar_animals().has(deer),"nearby non-objective animal visible within75m")
	deer.position.x+=2
	check(not game.radar_animals().has(deer),"animal beyond75m excluded")
	deer.fear_left=3
	check(game.radar_color(deer)==Color("58b8ff"),"panicked animal radar blue")
	deer.fear_left=0
	check(game.radar_color(deer)==Color("ed9fc8"),"neutral animal radar pink")
	game.coop.apply_animal_life(deer,{"health":0,"dead":true})
	check(deer.dead and deer.reaction.falling,"wildlife death sync works without max_health field")
	var catalog=preload("res://scripts/campaign_catalog.gd")
	check(catalog.wolf_budget(6,1)==4 and catalog.wolf_budget(6,2)==5,"round6 ordinary wolf budgets4solo5coop")
	var rng:=RandomNumberGenerator.new(); var largest:=0
	for seed_value in 1000:
		rng.seed=seed_value; largest=maxi(largest,catalog.pack_size(6,rng))
	check(largest<=4,"1000early pack draws never exceed4")
	game.level=6; game.campaign.job=catalog.wave(6); game.campaign.round_wolves_spawned=0
	game.campaign.spawn_pack(12,game.world.exterior_rally_point,false)
	game.campaign.spawn_pack(12,game.world.exterior_rally_point,false)
	check(game.campaign.round_wolves_spawned==4,"multiple surprise packs share the whole-round budget")
	game.player.position=game.world.exterior_rally_point
	game._equip_slot(game.progress.owned.find(0)); game.reload_left=0
	var ammunition: int=game.current_ammo()
	var spear_slot: int=game.progress.owned.find(20)
	var before: int=game.copy_magazines[spear_slot].loaded
	check(game.quick_throw(),"quick throw starts outdoors")
	check(game.copy_magazines[spear_slot].loaded==before-1,"quick throw prioritizes highest damage spear")
	check(game.current_weapon==0 and game.current_ammo()==ammunition,"quick throw preserves equipped gun and ammunition")
	check(not game.quick_throw(),"quick throw enforces short recovery")
	check(game.quick_throw_left<=.25,"quick throw ready in quarter second")
	game.player.bleeding_rate=1; game.player.leg_injury=.5; game.player.concussion=.3
	var avatar=preload("res://scripts/injury_avatar.gd").new(); avatar.game=game
	check(avatar.status_lines().has("BLEEDING") and avatar.status_lines().has("LEG INJURY") and avatar.status_lines().has("CONCUSSION"),"injury avatar reflects real status")
	avatar.free()
	game.shot_review.reset_history(); game.shot_review._process(0); game.notice_left=0; game.dialogue_left=0
	game.player.yaw=PI; game.player.pitch=0; game.player._update_rotation()
	var ranger=preload("res://scripts/field_character.gd").new(); game.add_child(ranger)
	ranger.position=game.player.position+Vector3(0,0,4)
	for id in range(31,35):
		game._equip_slot(game.progress.owned.find(id)); game._sync_weapon_visual()
		check(game.player.weapon.model_meta.source_meshes>20,"detailed new weapon model%d"%id)
		game.player.weapon.animate_reload(.5,true); game.player.weapon.animate_reload(1,false)
		if id in [31,32]:
			game.player.weapon.set_dual_ammo(int(game.WEAPONS[id].magazine)-1)
			check(game.player.weapon.dual_hand==1,"paired weapon alternates left%d"%id)
		if "--capture" in OS.get_cmdline_user_args():
			game.player.set_physics_process(true)
			await create_timer(.2).timeout; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/combat-weapon-%d.png"%id)
			game.player.set_physics_process(false)
	check(game.sounds.samples.has("bear_growl") and game.sounds.samples.bear_growl.get_length()>1,"recorded bear growl loaded")
	game.reload_left=0; game.fire_cooldown=0; game.fire_weapon()
	check(game.progress.owned.has(34),"grenade launcher retained after firing")
	game.restore_campaign()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; await process_frame
	print("COMBAT_FEEDBACK failures=",failures); quit(1 if failures else 0)
