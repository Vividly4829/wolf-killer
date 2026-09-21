extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	var game=load("res://scripts/main.gd").new()
	game.progress.save_path="user://upgrade_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.set_process(false); game.player.set_physics_process(false)
	game.start_run(); game.level=5; game.player.position=game.world.exterior_rally_point; game.begin_wave()
	check(game.wolves.size()==3 and game.objective_targets().size()==3,"all three level-five wolves stay marked without sightings")
	game.free_play=true
	for animal in game.nodes_in_group("wildlife"):
		animal.set_physics_process(false)
	for wolf in game.wolves: wolf.set_physics_process(false)
	var nav=game.world.wolf_nav
	var routed:=0
	var detours:=0
	for animal in game.nodes_in_group("wildlife"):
		if animal.aquatic: continue
		for offset in [Vector3(7,0,0),Vector3(0,0,7),Vector3(-7,0,-7)]:
			var id: int=nav.nearest(animal.position.x+offset.x,animal.position.z+offset.z,3)
			if id<0: continue
			var goal: Vector3=nav.point(id)
			var path=preload("res://scripts/animal_route.gd").plan(nav,animal.position,goal)
			if path.is_empty(): continue
			routed+=1
			if not nav.line_clear(animal.position.x,animal.position.z,goal.x,goal.z): detours+=1
			var p: Vector3=animal.position
			for waypoint in path:
				for frame in 2000:
					var d: Vector3=waypoint-p; d.y=0
					if d.length()<.03: break
					d=d.normalized()*minf(.07,d.length())
					p=nav.move_position(p,d.x,d.z)
			if Vector2(p.x-goal.x,p.z-goal.z).length()>=.5: print("ROUTE STUCK ",animal.position," -> ",goal," at ",p," path ",path)
			check(Vector2(p.x-goal.x,p.z-goal.z).length()<.5,"actual animal route reaches goal around terrain")
	check(routed>10 and detours>0,"routing covers direct paths and obstacle detours")
	for species in ["deer","duck","goose","mink"]:
		for organ_name in ["brain","heart"]:
			var animal=load("res://scripts/wildlife.gd").new(); animal.game=game; animal.species=species; game.add_child(animal); animal.set_physics_process(false)
			var organ: Dictionary=preload("res://scripts/wildlife_anatomy.gd").organs(species).filter(func(o): return o.id==organ_name)[0]
			var report: Dictionary=animal.receive_ballistic_hit(.1,animal.to_global(organ.center-Vector3.RIGHT*.4),Vector3.RIGHT,"body",.01)
			check(animal.dead and report.instant_fatal,"tiny %s %s hit is fatal"%[species,organ_name])
			game.shot_review.begin_shot(); game.shot_review.record(report)
			if OS.get_cmdline_user_args().has("--capture") and organ_name=="heart":
				game.set_mode("playing"); await create_timer(.2).timeout; await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/hunting-upgrade"))
				root.get_texture().get_image().save_png("res://qa/hunting-upgrade/%s-xray.png"%species)
	var wolf=game.wolves[0]
	var report: Dictionary=wolf.receive_ballistic_hit(.1,wolf.to_global(Vector3(-.3,.46,.25)*wolf.size_scale),wolf.global_basis*Vector3.RIGHT,"body",.01)
	check(wolf.dead,"tiny wolf heart hit is fatal")
	var deer=load("res://scripts/wildlife.gd").new(); deer.game=game; deer.species="deer"; game.add_child(deer); deer.set_physics_process(false)
	deer.damage(30,false)
	check(not deer.dead and deer.reaction.down>0,"substantial survivable hit knocks deer down")
	for frame in 240: deer.reaction._process(1.0/60)
	check(deer.reaction.down==0 and absf(deer.model.rotation.z)<.05,"wounded deer gets back up")
	check(game.player.stamina==300,"sprint stamina increased by 200 percent")
	game.player.jump(); game.player._physics_process(.1)
	check(game.player._jump_height>0,"jump leaves ground")
	game.player._jump_height=0; game.player._jump_velocity=0
	game.free_play=false; game.progress.money=10000; game.set_mode("shop")
	game.purchase_weapon(24)
	check(game.current_ammo()==1 and game.current_reserve()==0,"grenade purchase carries exactly one round")
	game.set_mode("playing"); game.fire_cooldown=0; game.fire_weapon()
	check(game.ammo[24]==0 and not game.progress.owned.has(24),"grenade consumed and must be purchased again")
	var bolts=game.nodes_in_group("player_bolts")
	check(bolts.size()==1 and bolts[0].spec.explosive,"grenade is a real timed projectile")
	if not bolts.is_empty():
		var victim=load("res://scripts/wildlife.gd").new(); victim.game=game; victim.species="deer"; game.add_child(victim); victim.set_physics_process(false)
		var point: Vector3=game.world.shooting_range.firing_point+Vector3.UP*4
		victim.position=point+Vector3.RIGHT
		bolts[0].global_position=point
		game.player.position=point+Vector3.BACK; game.health=1000
		await physics_frame
		bolts[0].detonate()
		check(victim.dead and game.health<1000,"blast damages nearby animals and the thrower")
		game.health=100
	game.set_mode("shop"); game.purchase_weapon(25)
	check(game.current_ammo()==1 and game.current_reserve()==0,"dynamite purchase carries exactly one bundle")
	game.purchase_weapon(26); game.set_mode("playing"); game.ammo[26]=0; game.reload_left=0; game.reload_weapon()
	check(game.reload_left==12,"aether musket has long crank recharge")
	game._finish_reload()
	check(game.ammo[26]==5 and game.reserve_ammo[26]==0,"cranking restores five laser shots without cartridges")
	game.reload_left=0
	for shot in 5:
		game.fire_cooldown=0; game.fire_weapon()
	check(game.ammo[26]==0,"five actual laser shots exhaust the capacitor")
	game.fire_cooldown=0; game.fire_weapon()
	check(game.reload_left==12 and game.ammo[26]==0,"sixth trigger starts crank instead of firing")
	if OS.get_cmdline_user_args().has("--capture"):
		game.shot_review.remaining=0; game.dialogue_left=0; game.notice_left=0; game.reload_left=0
		game.world.weather.hour=12; game.world.weather.apply()
		game.player.reset_at(game.world.shooting_range.firing_point)
		game.player.yaw=game.world.shooting_range.facing_yaw; game.player._update_rotation()
		for index in [0,7,24,25,26]:
			game.current_weapon=index; game.player.set_weapon(index); game.player._physics_process(.016)
			await create_timer(.15).timeout; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/hunting-upgrade/weapon-%d.png"%index)
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame
	quit(1 if failures else 0)
