extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var game=load("res://scripts/main.gd").new(); game.progress.transient=true; root.add_child(game)
	game.start_run(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false); game.supernatural.set_process(false)
	game.player.position=Vector3(140,80,140)
	var pistol=game.WeaponCatalog.weapon(37)
	check(pistol.damage==30 and pistol.magazine==20 and pistol.interval<game.WeaponCatalog.weapon(26).interval and pistol.range>=10000 and pistol.laser,"Laser pistol: 30 damage, twenty faster shots, map-wide beam")
	game.progress.owned.append(37); game.current_weapon=37; game.ammo[37]=0; game.reserve_ammo[37]=0; game._reload_weapon_id=37; game._reload_secondary=false; game._finish_reload()
	check(game.ammo[37]==20 and game.reserve_ammo[37]==0,"Cranking restores all twenty shots without consuming reserve")
	var target:=Area3D.new(); target.collision_layer=2; target.collision_mask=0
	var shape:=CollisionShape3D.new(); shape.shape=SphereShape3D.new(); target.add_child(shape); game.add_child(target); target.position=Vector3(140,80,640)
	await physics_frame; await physics_frame
	var shot=preload("res://scripts/ballistic_trace.gd").cast(game.get_world_3d().direct_space_state,Vector3(140,80,140),Vector3.BACK,pistol,[])
	check(not shot.hit.is_empty() and absf(shot.path.drop)<.001 and shot.path.travelled>499,"Green beam hits a target 500 m away with no drop")
	target.queue_free()
	var charge=game.BoltScript.new(); game.add_child(charge); charge.launch(game,Vector3(140,100,140),Vector3.BACK,game.WeaponCatalog.weapon(25)); charge.set_physics_process(false)
	charge._physics_process(4.0)
	check(not charge.is_queued_for_deletion() and charge.trigger_left<0,"Thrown dynamite waits indefinitely for second click")
	charge.trigger_detonation(); charge._physics_process(.29)
	check(not charge.is_queued_for_deletion(),"Remote detonation does not fire before 0.3 seconds")
	charge._physics_process(.011)
	check(charge.is_queued_for_deletion(),"Remote detonation fires after 0.3 seconds")
	game.player.cabin_exited=true
	check(not game.player.cabin_step_allowed(game.world.spawn_position) and game.player.cabin_step_allowed(game.world.exterior_rally_point),"Cabin boundary blocks re-entry after departure")
	game.player.cabin_exited=false
	check(game.player.cabin_step_allowed(game.world.spawn_position),"Fresh round permits starting inside cabin")
	var beast=game.campaign.spawn_wolf(Vector3(140,80,150),true,false,123); beast.set_physics_process(false)
	check(beast.model.get_script().resource_path.ends_with("night_beast.gd") and beast.model.joints.size()==4,"Werewolf has quadruped rig")
	beast.model.set_motion(8,false,false,true); beast.model._process(.1)
	check(absf(beast.model.joints.shoulderL.rotation.x)>.01 and beast.model.jaw.rotation.x<-.2,"Quadruped legs and biting jaw animate")
	var rabbit=load("res://scripts/were_rabbit.gd").new(); rabbit.game=game; rabbit.species="wererabbit"; game.add_child(rabbit); rabbit.set_physics_process(false)
	check(rabbit.health==320 and rabbit.model.get_child_count()>35,"Infected rabbit retains hostile enlarged anatomy")
	var bear=load("res://scripts/campaign_threat.gd").new(); bear.game=game; bear.appearance_seed=7; game.add_child(bear); bear.set_physics_process(false)
	var bear2=load("res://scripts/campaign_threat.gd").new(); bear2.game=game; bear2.appearance_seed=8; game.add_child(bear2); bear2.set_physics_process(false)
	check(bear.scale!=bear2.scale and bear.model.get_child_count()>40,"Bears have varied sizes and detailed models")
	var deer=load("res://scripts/wildlife.gd").new(); deer.game=game; game.add_child(deer); deer.set_physics_process(false)
	game.kill_board.mark(deer,"EMERALD CRANK PISTOL",1); deer.set_meta("kill_organs",["heart"]); deer.damage(1000)
	await process_frame
	check(game.kill_board.rows.get(1,{}).get("total",0)==1 and game.kill_board.rows[1].species.deer==1 and game.kill_board.rows[1].credits==15,"Kill ledger records hunter, species and money value once")
	check(game.kill_board.feed[0].vital=="heart" and game.kill_board.feed[0].weapon=="EMERALD CRANK PISTOL","Kill banner carries vital icon and weapon")
	game.kill_board.expanded=true
	await process_frame
	print("SEPTEMBER_UPDATE failures=",failures)
	quit(1 if failures else 0)
