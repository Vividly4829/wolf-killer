extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func capture(path: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await create_timer(.25).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/"+path)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://armory_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_run(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	game.progress.money=10000; game.set_mode("shop")
	for id in range(27,31):
		game.purchase_weapon(id)
		check(game.current_weapon==id and game.current_ammo()==int(game.WEAPONS[id].magazine),"new weapon purchased and equipped: %d"%id)
		check(int(game.player.weapon.model_meta.source_meshes)>30,"detailed model %d"%id)
		game.player.weapon.animate_reload(.4,true); game.player.weapon.animate_reload(1,false)
		game.hud._select_shop_weapon(id)
		await capture("armory-%d.png"%id)
	game.ammo[30]=1; game._sync_weapon_visual()
	check(game.player.weapon.dual_hand==1,"one round remaining selects left naval pistol")
	game.toggle_store_weapon(30)
	check(game.progress.stowed.has(30) and game.current_weapon!=30,"unequip stores owned weapon and switches away")
	game.close_shop()
	for i in 12:
		game.cycle_weapon(1); check(game.current_weapon!=30,"cycling skips stowed pair")
	game.set_mode("shop"); game.toggle_store_weapon(30)
	check(game.current_weapon==30 and game.current_ammo()==1 and game.player.weapon.dual_hand==1,"re-equip restores remaining ammo and active hand")
	game.toggle_store_weapon(0)
	check(game.progress.stowed.has(0),"starter musket can also be unequipped")
	var restored=preload("res://scripts/progress_store.gd").new(); restored.save_path=game.progress.save_path; restored.load_progress()
	check(restored.stowed.has(0) and restored.owned.has(0),"stowed weapon stays owned across save/load")
	game.close_shop(); game.player.position=Vector3(0,80,0)
	game.ammo[30]=2; game._sync_weapon_visual(); game.fire_cooldown=0
	game.fire_weapon()
	check(game.current_ammo()==1 and game.player.weapon._fired_hand==0 and game.player.weapon.dual_hand==1,"actual first shot fires right then selects left")
	game.fire_cooldown=0; game.fire_weapon()
	check(game.current_ammo()==0 and game.player.weapon._fired_hand==1,"actual second shot fires left")
	game.fire_cooldown=0; game.reload_weapon(); game._finish_reload()
	check(game.current_ammo()==2 and game.player.weapon.dual_hand==0,"reload restores both shots and right hand")
	game.beam_effect(Vector3.ZERO,Vector3(0,1,-20))
	var beam=game.get_node("RedLaserBeam")
	check(beam.get_child_count()==2 and beam.get_child(0).mesh.top_radius>=.045,"laser has thick core and glow")
	check(beam.get_child(0).material_override.albedo_color.r>.9 and beam.get_child(0).material_override.albedo_color.g<.1,"laser is bright red")
	check(game.sounds.samples.growl.resource_path.ends_with("wolf_snarl_1.wav"),"growls use recorded canine sound")
	check(game.sounds.samples.maul_scream_2.get_length()>3,"long human scream available")
	check(game.sounds.samples.tear_3.get_length()>1,"real sustained cloth tear available")
	if "--capture" in OS.get_cmdline_user_args():
		game.player.position=game.world.exterior_rally_point; game.player.pitch=0; game.player.yaw=PI; game.player._update_rotation()
		game.shot_review.reset_history(); game.dialogue_left=0; game.notice_left=0
		game.reload_left=0; game.player._reload_time=0
		game.world.weather.hour=16; game.world.weather.apply()
		game.player.set_physics_process(true)
		await capture("naval-first-person.png")
	game.set_mode("menu")
	game.hud.overlay.get_node("StartingMoney").get_line_edit().text="4321"
	game.hud.overlay.get_node("StartingMoney").get_line_edit().text_changed.emit("4321")
	var split=preload("res://scripts/split_session.gd").new(); split.secondary_save_path="user://armory_guest_%d.cfg"%OS.get_process_id()
	root.add_child(split); await split.launch(game)
	var host=split.games[0]; var guest=split.games[1]
	for local in split.games:
		local.set_process(false); local.player.set_physics_process(false); local.campaign.set_process(false)
	check(host.progress.money==4321 and guest.progress.money==4321,"uncommitted typed menu credits reach both split hunters")
	guest.progress.money=3999; host.coop.wake_remote(2,true)
	check(guest.progress.money==3999,"round recovery never resets earned/spent credits")
	host.coop.local_sender=2; host.coop.ready_player(); host.coop.local_sender=0
	check(guest.progress.money==4321,"host sends configured wallet on first joining handshake")
	guest.progress.money=4001
	host.coop.local_sender=2; host.coop.ready_player(); host.coop.local_sender=0
	check(guest.progress.money==4001,"repeated ready handshake cannot reset guest earnings")
	var wolf=host.WolfScript.new(); wolf.configure(host,host.world.wolf_nav,5,73); host.add_child(wolf); wolf.set_physics_process(false)
	var avatar=host.coop.avatars[2]
	wolf.hunted_hunter=avatar; avatar.position=host.world.bed_wake_position
	avatar.mauling=wolf.get_instance_id(); wolf.behavior="maul"
	wolf._tick_maul(avatar,.016)
	check(avatar.mauling==0 and wolf.behavior!="maul","remote hunter reaching safety releases maul and unfreezes wolf")
	check(not wolf._struggle_active(),"other pack wolves see the cleared struggle state")
	avatar.position=host.world.exterior_rally_point
	wolf.behavior="maul"; avatar.mauling=wolf.get_instance_id(); host.coop.release_remote_maul(2)
	check(avatar.mauling==0 and wolf.behavior!="maul","explicit remote escape releases attacker")
	avatar.mauling=wolf.get_instance_id(); wolf.dead=true
	host.coop.clock=1; host.coop.last_snapshot=0; host.coop._process(.1)
	check(avatar.mauling==0,"dead attacker cannot leave a frozen remote struggle flag")
	for local in split.games:
		local.coop.leave(); set_multiplayer(null,local.get_path())
		for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(local.progress.save_path+suffix))
	split.queue_free()
	for i in 6: await process_frame
	print("ARMORY_MAUL failures=",failures); quit(1 if failures else 0)
