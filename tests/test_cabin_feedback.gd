extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func coffee_position(world,index: int) -> Vector3:
	var cabin: Dictionary=world.services.cabins[index]
	for radius in [.7,1.1,1.45]:
		for step in 16:
			var p: Vector3=cabin.cup+Vector3.RIGHT.rotated(Vector3.UP,step*TAU/16)*radius
			var cell: int=world.nav.at(p.x,p.z)
			if not world.nav.valid(cell): continue
			p=world.nav.point(cell)
			if world.services.nearby_coffee(p)==index: return p
	return Vector3.INF
func run() -> void:
	var legacy:=IslandProgress.new()
	legacy.save_path="user://starter_migration_%d.cfg"%OS.get_process_id()
	check(legacy.money==350,"new hunter starts with 350 credits")
	var cfg:=ConfigFile.new(); cfg.set_value("progress","money",30); cfg.save(legacy.save_path)
	legacy.load_progress()
	check(legacy.money==350,"old low balance gets one starter allowance")
	legacy.money=12; legacy.save_progress(); legacy.load_progress()
	check(legacy.money==12,"spending or restarting cannot repeat the allowance")
	var game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://cabin_feedback_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.start_run(); game.set_process(false); game.player.set_physics_process(false)
	game.campaign.set_process(false)
	AudioServer.set_bus_mute(0,true)
	await physics_frame; await physics_frame
	check(game.world.services.cabins.size()==9,"all nine enterable buildings have supplies and coffee")
	check(game.world.get_node("CabinComfort").find_children("CoffeeCup*","MeshInstance3D",true,false).size()==9,"nine visible coffee cups")
	check(game.world.get_node("CabinComfort").find_children("CoffeeSteam*","GPUParticles3D",true,false).size()==9,"every coffee cup steams")
	for i in game.world.services.cabins.size():
		var p:=coffee_position(game.world,i)
		check(p.is_finite(),"coffee reachable without walls: "+str(game.world.services.cabins[i].id))
		if not p.is_finite(): continue
		game.player.position=p
		check(game.near_shop(),"supplies available in building %d"%i)
		game.health=40
		game.drink_coffee()
		check(game.health==70,"coffee heals 30 HP in building %d"%i)
		game.drink_coffee()
		check(game.health==70,"coffee cannot be spammed in building %d"%i)
		check("COFFEE" in game.interaction_prompt(),"coffee interaction is advertised")
	game.player.position=game.world.exterior_rally_point
	game.health=40
	game.coop.serve_coffee(1,-1)
	check(game.health==40,"invalid coffee request cannot heal outdoors")
	game.ammo[0]=0; game.reload_weapon()
	check(game.reload_left==3.25,"musket reload is halved to 3.25 seconds")
	var deer=preload("res://scripts/wildlife.gd").new()
	deer.game=game; game.add_child(deer); deer.set_physics_process(false)
	deer.position=game.world.nav.point(game.world.nav.nearest(5,12))
	var skeleton: Skeleton3D=deer.model.find_children("*","Skeleton3D",true,false)[0]
	for clip in ["Idle_001","Run"]:
		deer.animation.play(clip)
		var lowest:=INF
		for step in 24:
			deer.animation.seek(step/24.0*deer.animation.get_animation(clip).length,true)
			skeleton.force_update_all_bone_transforms()
			for bone in skeleton.get_bone_count():
				if "leg" in skeleton.get_bone_name(bone) and ".002" in skeleton.get_bone_name(bone):
					lowest=minf(lowest,deer.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin).y)
		print("LOWEST ANKLE ",clip," ",lowest," model offset ",deer.model.position.y)
		check(lowest>0,"deer ankle joints remain above terrain for "+clip)
	deer.update_animation(0)
	check(deer.animation.current_animation=="Idle_001","stationary deer uses the real idle clip")
	var wolf=preload("res://scripts/wolf.gd").new()
	wolf.configure(game,game.world.wolf_nav,4,1245,true)
	game.add_child(wolf); game.wolves.append(wolf); wolf.set_physics_process(false)
	wolf.position=deer.position
	wolf._alert_to(game.player.position)
	wolf._think(game.player.position,8,false,wolf._pack_members())
	check(wolf._close_warning_until-wolf._time>=4 and not wolf._start_charge(wolf._pack_members()),"new encounter gives at least four seconds of warning before attack")
	var first_growl: float=wolf._last_growl
	wolf._time+=1.8; wolf._tick_vocalizations(1.8)
	check(wolf._last_growl>first_growl,"wolf snarls repeatedly during warning")
	wolf._state_left=0
	wolf._think(game.player.position,8,false,wolf._pack_members())
	check(wolf.behavior=="circle","warning leads into circling instead of an immediate rush")
	wolf._time=wolf._close_warning_until+3
	wolf._pack.clock=wolf._time
	wolf._commit_wait=10
	wolf._choose_attack(wolf._pack_members())
	check(wolf.behavior=="charge","wolf still commits after the standoff")
	if "--capture" in OS.get_cmdline_user_args():
		root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
		game.world.weather.hour=12; game.world.weather.apply()
		game.player.position=deer.position+Vector3(3,0,3)
		game.player.camera.look_at(deer.position+Vector3.UP*.7)
		deer.animation.play("Idle_001")
		await create_timer(.3).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/deer-ground-corrected.png")
		game.player.position=coffee_position(game.world,3)
		game.player.camera.look_at(game.world.services.cabins[3].cup)
		await create_timer(.3).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/cabin-coffee.png")
	for path in [legacy.save_path,game.progress.save_path]:
		for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	game.queue_free(); await process_frame; quit(1 if failures else 0)
