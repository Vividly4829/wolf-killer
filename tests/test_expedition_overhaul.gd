extends SceneTree
var failures:=0
var game: Node3D
const Catalog=preload("res://scripts/campaign_catalog.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func freeze() -> void:
	for actor in game.wolves+game.nodes_in_group("wildlife")+game.nodes_in_group("campaign_threats"): actor.set_physics_process(false)
func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await create_timer(.2).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/overhaul-"+label+".png")
func run() -> void:
	var rng:=RandomNumberGenerator.new(); rng.seed=12784
	for level in range(1,31):
		var job:=Catalog.wave(level,2)
		check(job.sites==0 and job.search==0 and Catalog.total(job)>0,"wave %d has combat/hunting goals and no searching"%level)
	var early_large:=0; var late_large:=0
	for trial in 1000:
		early_large+=int(Catalog.pack_size(1,rng)>=5); late_large+=int(Catalog.pack_size(30,rng)>=5)
	check(early_large>20 and late_large>early_large*3,"large packs are possible early and much more common late")
	check(Catalog.encounter_chance(1)>0 and Catalog.encounter_chance(30)<1 and Catalog.encounter_chance(10)>Catalog.encounter_chance(5),"danger chance increases without becoming guaranteed")
	game=preload("res://scripts/main.gd").new(); game.progress.save_path="user://overhaul_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_run(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	await physics_frame; await physics_frame
	for level in [1,5,10,12,19,22,26,30]:
		game.level=level; game.player.position=game.world.exterior_rally_point; game.campaign.rng.seed=1234+level; game.campaign.begin(); freeze()
		check(game.campaign.items.is_empty(),"no physical supply packs on wave %d"%level)
		if level in [12,22]: check(game.nodes_in_group("campaign_threats").any(func(n): return n.species=="raider" and n.get_meta("mission",false)),"replacement raider objective can be completed")
		await process_frame
	game.campaign.clear_round(); await process_frame
	game.level=10; game.campaign.begin(); freeze()
	for kind in ["wolves","patrol","bear","werewolf"]:
		game.campaign.event=kind; game.campaign.warn_event(); game.campaign.launch_event(); freeze()
		check(game.campaign.event_started,"optional threat launches: "+kind)
	var beast=game.wolves.filter(func(w): return w.werewolf)[0]
	check(beast.model.beast and beast.model.joints.has("shoulderL") and beast.charge_speed>=11,"werewolf has an upright articulated model and fast charge")
	beast._time=20; beast.warned=false; beast._begin_warning()
	check(beast._warning_until>20 and beast._warning_until<21.2,"werewolf has a short threatening windup")
	var ordinary=game.wolves.filter(func(w): return not w.werewolf)[0]
	ordinary._time=20; ordinary.warned=false; ordinary._begin_warning()
	check(ordinary._warning_until>=24,"normal wolf retains its longer audible warning")
	var hunter=preload("res://scripts/coop_avatar.gd").new(); game.add_child(hunter)
	hunter.character.set_motion(4,false,false,false); hunter.character._process(.15)
	check(absf(hunter.character.joints.hipL.rotation.x)>.1 and hunter.character.joints.kneeL!=null,"hunter walk animation articulates hips and knees")
	game.campaign.running=false
	game.player.position=Vector3(0,80,0)
	var anatomy=preload("res://scripts/wolf_anatomy.gd")
	var shallow: Dictionary=anatomy.trace(Vector3(0,.46,.6),Vector3.FORWARD,.22,"body")
	var deep: Dictionary=anatomy.trace(Vector3(0,.46,.6),Vector3.FORWARD,.7,"body")
	check(not shallow.organs.has("heart") and deep.organs.has("heart"),"deeper weapon can reach a heart beyond knife penetration")
	var head: Dictionary=anatomy.trace(Vector3(0,.91,.80),Vector3.FORWARD,.7,"head")
	check(head.organs.has("brain") and not head.organs.has("heart"),"level head shot cannot report an unrelated heart hit")
	var first:=head.duplicate(true); first.target_uid=101
	var second:=deep.duplicate(true); second.target_uid=202
	var separate: Array[Dictionary]=[first,second]
	var filtered: Array[Dictionary]=game.shot_review.target_reports(separate)
	check(filtered.size()==1 and filtered[0].target_uid==202,"different targets cannot combine brain and heart in one skeleton")
	check(game.WeaponCatalog.weapon(18).penetration<game.WeaponCatalog.weapon(0).penetration and game.WeaponCatalog.weapon(15).penetration>game.WeaponCatalog.weapon(0).penetration,"weapon-specific penetration budgets")
	for index in [24,25]:
		ordinary.position=Vector3(35,80,-2); ordinary.health=1000; ordinary.max_health=1000
		var spec: Dictionary=game.WeaponCatalog.weapon(index); spec.range=.5
		var bolt=preload("res://scripts/crossbow_bolt.gd").new(); game.add_child(bolt)
		game.shot_review.begin_shot(true); bolt.launch(game,Vector3(35,80,0),Vector3.FORWARD,spec); bolt.set_physics_process(false)
		bolt._physics_process(.2)
		check(bolt.landed and not bolt.is_queued_for_deletion(),"explosive survives range cap until fuse: %d"%index)
		bolt._physics_process(float(spec.fuse))
		check(bolt.get_meta("detonated",false) and bolt.is_queued_for_deletion(),"explosive detonates on fuse: %d"%index)
		check(ordinary.health<1000,"explosion damages a nearby animal: %d"%index)
	check(not game.nodes_in_group("explosion_effects").is_empty(),"explosions produce a visible timed effect")
	game.set_mode("playing")
	game.health=100; game.receive_gunshot(25)
	check(game.health==75 and game.player.bleeding_rate>0 and game.damage_flash>1 and game.player._damage_kick>1,"gunshot causes HP loss, blood, bleeding and camera shake")
	check(game.sounds.samples["gun_pain_1"]!=null and game.sounds.samples["explosion"]!=null,"recorded pain vocals and explosion boom imported")
	game.campaign.wind=Vector3.ZERO
	for index in [21,22,23]:
		var arrow=preload("res://scripts/crossbow_bolt.gd").new(); game.add_child(arrow)
		arrow.launch(game,Vector3(50,80,0),Vector3.FORWARD,game.WeaponCatalog.weapon(index)); arrow.set_physics_process(false)
		for frame in 180:
			arrow._physics_process(.005)
			if arrow.position.z<=-20: break
		check(absf(arrow.position.y-80)<.035,"bow sight crosses aim line at 20 m: %d"%index)
		arrow.queue_free()
	var brush_point: Vector3=game.world.nav.brush.values()[0]
	var previous: float=game.world.nav.vegetation_factor(brush_point)
	var largest:=0.0
	for step in 100:
		var speed: float=game.world.nav.vegetation_factor(brush_point+Vector3(step*.025,0,0))
		largest=maxf(largest,absf(speed-previous)); previous=speed
	check(largest<.04,"brush slows movement continuously without a hard speed boundary")
	game.world.weather.hour=12; game.world.weather.apply()
	beast.position=Vector3(0,80,0); beast.rotation.y=0
	hunter.position=Vector3(2,80,0); hunter.rotation.y=PI; hunter.equip(2)
	game.player.camera.global_position=Vector3(3,81.7,4); game.player.camera.look_at(Vector3(1,81.25,0))
	game.shot_review.remaining=0
	game.damage_flash=0; game.player.bleeding_rate=0
	game.player.weapon.visible=false
	await create_timer(2).timeout
	await capture("characters")
	for species in ["wolf","deer","goose","duck","mink","bear","hunter","werewolf"]:
		game.shot_review.begin_shot()
		var report: Dictionary
		if species in ["hunter","werewolf"]: report=preload("res://scripts/human_xray.gd").trace(Vector3(-.3,1.2,0),Vector3.RIGHT,25,.8)
		elif species=="wolf": report=deep.duplicate(true)
		else:
			var organ: Dictionary=preload("res://scripts/wildlife_anatomy.gd").organs(species)[0]
			report=preload("res://scripts/wildlife_anatomy.gd").trace(species,organ.center-Vector3.RIGHT*.35,Vector3.RIGHT,.8)
		report.merge({"species":species,"damage":25,"calculated_damage":25,"base_damage":25,"range_factor":1,"weapon":"QA anatomy","distance":15},true)
		game.shot_review.record(report); game.shot_review._process(0)
		check(game.shot_review.front_views.any(func(v): return v.visible),"frontal review is shown for "+species)
		await capture("xray-"+species)
	game.shot_review.remaining=0
	game.current_weapon=22; game.player.set_weapon(22); game.player.position=game.world.shooting_range.firing_point
	game.player.weapon.visible=true
	game.player.pitch=0; game.player.yaw=0; game.player._update_rotation(); game.player._aim=1
	game.player._physics_process(0)
	await capture("bow")
	hunter.queue_free()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame
	print("OVERHAUL failures=",failures); quit(1 if failures else 0)
