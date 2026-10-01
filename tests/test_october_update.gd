extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func freeze(game: Node) -> void:
	game.progress.transient=true; game.set_process(false); game.player.set_physics_process(false); game.coop.set_process(false)
	game.campaign.set_process(false); game.supernatural.set_process(false)
	for a in game.wolves+game.nodes_in_group("wildlife")+game.nodes_in_group("campaign_threats"): a.set_physics_process(false)
func run() -> void:
	create_timer(420).timeout.connect(func(): print("TIMEOUT"); quit(2))
	var original=load("res://scripts/main.gd").new(); original.progress.transient=true; root.add_child(original)
	var session=load("res://scripts/split_session.gd").new(); session.secondary_save_path="user://october_test_%d.cfg"%OS.get_process_id(); root.add_child(session)
	await session.launch(original,4)
	for g in session.games: freeze(g)
	var host=session.games[0]; var guest=session.games[1]
	var p: Vector3=host.world.exterior_rally_point
	for g in session.games: g.player.position=p; g.player.cabin_exited=true
	for avatar in host.coop.avatars.values(): avatar.position=p
	guest.player._jump_height=1.0; guest.player.position=p+Vector3.UP; guest.player.is_crouching=true
	guest.coop.clock+=1; guest.coop._process(.1)
	check(host.coop.avatars[2].is_crouching and host.coop.avatars[2].jump_height==1.0,"Guest jump height and crouch reach authority")
	check(absf(host.coop.avatars[2].position.y-p.y-1)<.15,"Host retains airborne vertical position")
	host.player.is_crouching=true; host.player._jump_height=.7; host.player.position=p+Vector3.UP*.7
	host.coop.clock+=1; host.coop._process(.1)
	check(guest.coop.avatars[1].is_crouching and guest.coop.avatars[1].jump_height==.7,"Host crouch and jump reach guests")
	check(session.games[2].coop.avatars[2].is_crouching and session.games[2].coop.avatars[2].jump_height==1,"Guest pose relayed to other guests")
	guest.coop.avatars[1]._process(.1)
	check(guest.coop.avatars[1].character.airborne,"Remote character uses airborne animation")
	guest.health=0; guest.player.position=p-Vector3.UP*40; guest.player.settle_downed()
	check(absf(guest.player.position.y-p.y)<.15,"Downed local player recovered to sampled floor")
	host.coop.avatars[2].health=0; host.coop.avatars[2].position=p-Vector3.UP*40; host.coop.avatars[2]._process(.1)
	check(absf(host.coop.avatars[2].position.y-p.y)<.15,"Downed authority avatar rests on terrain")
	host.coop.clock+=1; host.coop._process(.1)
	check(session.games[3].coop.avatars[2].health==0,"Downed marker state reaches every player")
	guest.health=100; host.coop.avatars[2].health=100; guest.player._jump_height=0; host.player._jump_height=0
	for g in session.games: g.player.position=p; g.player.is_crouching=false
	for i in 4:
		host.bandages=0; host.player.bleeding_rate=1; host.use_bandage()
		check(host.bandage_left>0,"Unlimited bandage use %d with zero inventory"%i)
		host._process(2.5)
	check(host.player.bleeding_rate==0,"Bandage still completes treatment")
	host.level=30; host.intermission=true; host.begin_wave(); freeze(host)
	check(host.wolves.filter(func(w):return not w.werewolf).size()==15,"Finale spawns exactly fifteen wolves")
	check(host.wolves.filter(func(w):return w.werewolf).size()==5,"Finale spawns exactly five werewolves")
	var vampires=host.nodes_in_group("campaign_threats").filter(func(a):return not a.is_queued_for_deletion() and a.species=="vampire")
	check(vampires.size()==1 and vampires[0].health==1200,"Finale spawns one 1200 HP vampire")
	check(host.campaign.job.kill=={"wolf":15,"werewolf":5,"vampire":1} and host.campaign.event=="none","Finale quota fixed for four players; no random extra encounter")
	host.coop.clock+=1; host.coop._process(.1)
	check(not vampires.is_empty() and guest.coop.replicas.has(vampires[0].get_instance_id()) and guest.coop.replicas[vampires[0].get_instance_id()].species=="vampire","Vampire replicated as human boss")
	host.guardians.reset_round(); host.guardians.set_physics_process(false)
	host.guardians.cats[0].rider=2; host.coop.send_all("cat_state",[host.guardians.snapshot()])
	guest.player.jump(); host.guardians._physics_process(.1)
	check(host.guardians.cats[0].jump>.1,"Controller/Space jump request lifts mounted cat on host")
	host.coop.send_all("cat_state",[host.guardians.snapshot()]); guest.guardians._physics_process(.1)
	check(guest.guardians.cats[0].jump>.1 and guest.player.position.y>guest.guardians.cats[0].p.y+.7,"Jumping cat and rider replicated")
	for i in 100: host.guardians._physics_process(.02)
	check(host.guardians.cats[0].jump==0,"Mounted cat returns to ground")
	var target=host.world.shooting_range.targets[0]
	var origin: Vector3=target.to_global(Vector3(0,1.5,-3))
	var excluded: Array[RID]=[]
	host.shot_review.begin_shot(); host.fire_ballistic(origin,target.global_basis.z,host.WeaponCatalog.weapon(37),host.shot_review.serial,1,excluded)
	check(target.hits>0 and not host.shot_review.reports.is_empty(),"Real ballistic shot produces range report")
	check(host.shot_review.reports.back().species=="target" and host.shot_review.reports.back().damage==60,"Bullseye yields score and 2x simulated damage")
	check(guest.world.shooting_range.targets[0].hits==target.hits,"Target ring feedback replicated")
	var edge=target.receive_ballistic_hit(30,target.to_global(Vector3(.64,1.5,0)),target.global_basis.z,"target",0,1,1)
	check(edge.damage<60 and edge.score<10,"Outer circle produces lower score and damage")
	check(target.rings.any(func(r):return r.material_override.emission_enabled),"Hit circle lights up")
	host.set_mode("shop"); host.hud.shop_selection=37; host.hud.refresh_panel()
	check(host.hud._shop_stat_labels.size()==8 and host.hud._shop_stat_labels[3].text.contains("0.00"),"Store shows eight stats including actual accuracy")
	host.set_mode("playing")
	var saved_nav=host.player.nav
	var nav=preload("res://scripts/coastal_nav.gd").new()
	nav.setup({"width":2,"depth":1,"cellSize":1.0,"origin":[1000,1000],"heights":[5.0,5.9],"blocked":[0,0]})
	host.player.nav=nav
	var start:=Vector3(1000.49,5,1000)
	var climbed: Vector3=host.player.move_ground(start,.1,0)
	check(climbed.x>start.x and climbed.x<start.x+.1 and climbed.y>start.y,"Unlinked steep terrain is traversed at climbing speed")
	var wall:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(.015,4,2); shape.shape=box; wall.add_child(shape); host.add_child(wall); wall.position=Vector3(1000.50,6,1000)
	await physics_frame; await physics_frame
	check(host.player.move_ground(start,.1,0).x<=start.x+.001,"Climbing cannot bypass a solid wall")
	wall.queue_free(); host.player.nav=saved_nav
	for g in session.games:
		g.notice_left=0; g.dialogue_left=0; g.player.position=p; g.player.yaw=1.6; g.player._update_rotation()
		target=host.world.shooting_range.targets[0]
	if DisplayServer.get_name()!="headless":
		await create_timer(2).timeout
		root.get_texture().get_image().save_png("res://qa/october1-four-player-hud.png")
	print("OCTOBER_UPDATE failures=",failures)
	quit(1 if failures else 0)
