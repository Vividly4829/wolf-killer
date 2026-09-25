extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var original=load("res://scripts/main.gd").new(); original.progress.save_path="user://cats_test_%d.cfg"%OS.get_process_id(); root.add_child(original)
	original.menu_start_level=10; original.menu_start_money=777
	var session=load("res://scripts/split_session.gd").new(); session.secondary_save_path="user://cats_guest_%d.cfg"%OS.get_process_id(); root.add_child(session)
	await session.launch(original)
	var host=session.games[0]; var guest=session.games[1]; var guards=host.guardians
	host.campaign.set_process(false); guest.campaign.set_process(false)
	check(guards.cats.size()==2 and guest.guardians.cats.size()==2,"two guardians appear on wave ten in both worlds")
	check(guards.cats[0].max_hp==150 and guards.cats[1].max_hp==150,"both cats have 150 HP")
	check(guards.outside_buildings(guards.cats[0].home) and guards.outside_buildings(guards.cats[1].home),"guardians spawn outdoors away from roofs and walls")
	check(guards.cats[0].home.distance_to(guards.cats[1].home)>2,"separate outdoor home positions")
	host.level=9; guards.reset_round(); check(guards.cats.is_empty(),"no cats before wave ten")
	host.level=10; guards.reset_round()
	check(guards.cats[0].name=="Tijgertje" and guards.cats[1].name=="Sirius","cats have their personal names")
	check(guards.cats[0].node.scale.is_equal_approx(Vector3.ONE*.6) and guest.guardians.cats[1].node.scale.is_equal_approx(Vector3.ONE*.6),"local and replicated models are forty percent smaller")
	var cat: Dictionary=guards.cats[0]
	host.player.position=cat.p+Vector3(1,0,0); host.health=100
	check(guards.request(1),"host can mount")
	check(guards.occupied(1)==0 and guest.guardians.occupied(1)==0,"host mount replicated")
	host.coop.avatars[2].position=cat.p
	check(not guards.request(2),"occupied saddle rejects second rider")
	var other: Dictionary=guards.cats[1]
	host.coop.avatars[2].position=other.p; guest.player.position=other.p
	guest.coop.send_to(1,"cat_interact",[])
	check(guards.occupied(2)==1 and guest.guardians.occupied(2)==1,"guest mounts second cat through host")
	if "--capture" in OS.get_cmdline_user_args():
		for game in session.games: game.world.weather.hour=13; game.world.weather.apply()
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/guardian-cats-riding.png")
	var before: Vector3=cat.p
	guards.control(1,Vector2(0,-1),0)
	for i in 12: guards._physics_process(.016)
	check(cat.p.distance_to(before)>.05,"riding input moves cat on navigation")
	check(is_equal_approx(host.player.position.y,cat.p.y+.75),"rider follows the resized saddle")
	guards.request(1); guest.coop.send_to(1,"cat_interact",[])
	check(guards.occupied(1)<0 and guards.occupied(2)<0,"both players dismount")
	check(guest.guardians.occupied(2)<0 and guest.player.position.y<other.p.y+1,"guest exits at ground level")
	var return_start := Vector3.INF
	for angle in 16:
		var sample: Vector3=cat.home+Vector3(cos(angle*TAU/16),0,sin(angle*TAU/16))*7
		var cell: int=host.world.wolf_nav.nearest(sample.x,sample.z,1)
		if cell>=0 and preload("res://scripts/animal_route.gd").corridor_clear(host.world.wolf_nav,cat.home,host.world.wolf_nav.point(cell)):
			return_start=host.world.wolf_nav.point(cell); break
	check(return_start.is_finite(),"reachable return-home fixture")
	if return_start.is_finite():
		cat.p=return_start; cat.node.position=return_start
		for tick in 160: guards._physics_process(.02)
		check(cat.p.distance_to(cat.home)<1.3,"unmounted guardian returns home")
	var wolf=load("res://scripts/wolf.gd").new(); wolf.configure(host,host.world.wolf_nav,10,938); host.add_child(wolf); wolf.position=cat.p+Vector3(0,0,2); host.wolves.append(wolf); wolf.set_physics_process(false)
	wolf.set_meta("mission",true); wolf.health=20
	host.campaign.running=true; host.campaign.job=preload("res://scripts/campaign_catalog.gd").wave(10).duplicate(true); host.campaign.job.hunt={}; host.campaign.job.kill={"wolf":3}; host.campaign.done={}; host.wave_total=3; host.intermission=false
	check(guards.hostile(wolf),"wolves are hostile guard targets")
	var money: int=host.progress.money
	cat.think=0; cat.cooldown=0
	guards._physics_process(.02)
	check(wolf.dead,"guardian defeats nearby wolf")
	check(int(host.campaign.done.get("kill_wolf",0))==1,"guardian kill advances mission")
	check(host.progress.money==money+25 and guest.progress.money==host.progress.money,"guardian kill pays both hunters once")
	var deer=load("res://scripts/wildlife.gd").new(); deer.game=host; deer.species="deer"; host.add_child(deer)
	check(not guards.hostile(deer),"peaceful deer are protected from cats")
	deer.defensive_left=5; check(guards.hostile(deer),"attacking deer becomes eligible")
	var devil=load("res://scripts/supernatural_actor.gd").new(); devil.game=host; devil.species="devil"; host.add_child(devil)
	check(not guards.hostile(devil),"neutral devil is left alone")
	devil.alerted=true; check(guards.hostile(devil),"hostile devil becomes eligible")
	devil.queue_free(); deer.queue_free()
	var enemy=load("res://scripts/wolf.gd").new(); enemy.configure(host,host.world.wolf_nav,10,139); host.add_child(enemy); enemy.position=cat.p+Vector3(0,0,1.5); enemy.set_physics_process(false)
	var hp: float=cat.hp
	check(guards.defend_against(enemy,.1) and cat.hp<hp,"enemy retaliates against guardian")
	host.player.position=cat.p; guards.request(1); guards.hurt(cat,10000)
	check(cat.hp==0 and guards.occupied(1)<0,"fallen cat releases rider")
	guards.reset_round(); check(guards.cats.size()==2 and guards.cats[0].hp==guards.cats[0].max_hp,"next round revives both cats at full health")
	host.coop.clock+=1; host.coop._process(.2)
	check(guest.guardians.cats[0].hp==guards.cats[0].hp,"respawn health is replicated")
	enemy.queue_free()
	for game in session.games:
		game.coop.leave()
		for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	print("GUARDIAN FAILURES: ",failures); quit(failures)
