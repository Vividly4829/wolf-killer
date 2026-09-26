extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	create_timer(100).timeout.connect(func(): print("TEST TIMEOUT"); quit(2))
	var original=load("res://scripts/main.gd").new(); original.progress.transient=true
	original.progress.save_path="user://unused_enemy_coop.cfg"; root.add_child(original)
	var session=load("res://scripts/split_session.gd").new()
	session.secondary_save_path="user://enemy_coop_%d.cfg"%OS.get_process_id(); root.add_child(session)
	await session.launch(original,2)
	var host=session.games[0]; var guest=session.games[1]
	guest.progress.transient=true
	host.player.position=host.world.exterior_rally_point; host.level=20; host.begin_wave()
	host.campaign.event_origin=host.campaign.random_point(40)
	for event in ["nazis","confederates","wererabbit"]:
		host.campaign.event=event; host.campaign.launch_event()
	host.coop.clock+=1; host.coop._process(.2)
	for species in ["nazi","confederate","wererabbit"]:
		var found:=0
		for replica in guest.coop.replicas.values():
			if replica.get("species")==species: found+=1
		check(found==(1 if species=="wererabbit" else 4),species+" replicated with correct type")
	var beast:Node3D
	for a in host.nodes_in_group("wildlife"):
		if a.species=="wererabbit": beast=a
	var point:Vector3=host.campaign.random_point(45)
	guest.player.position=point; host.coop.avatars[2].position=point
	beast.position=point+Vector3(.5,0,0); beast.prey=host.coop.avatars[2]; beast.hunt_think=2
	host.set_mode("playing"); guest.set_mode("playing")
	await physics_frame
	beast._physics_process(.1)
	check(guest.affliction.infected_wave==20,"Were-rabbit bite infects remote player")
	check(guest.health<guest.maximum_health(),"Remote player receives bite damage")
	beast.damage(10000)
	host.coop.clock+=1; host.coop._process(.2)
	check(guest.coop.replicas[beast.get_instance_id()].dead,"Were-rabbit death synchronized")
	for soldier in host.nodes_in_group("campaign_threats"):
		if soldier.species=="nazi":
			soldier.damage(10000); host.coop.clock+=1; host.coop._process(.2)
			check(guest.coop.replicas[soldier.get_instance_id()].dead,"Soldier death synchronized"); break
	check(guest.coop.replicas[beast.get_instance_id()].limbs.areas.is_empty(),"Replica retains visual limbs without redundant hitboxes")
	var outline:PackedVector2Array=host.world.cabin_outline
	var center:=Vector2.ZERO
	for vertex in outline: center+=vertex
	center/=outline.size()
	var edge:Vector2=(outline[0]+outline[1])*.5
	var near:Vector2=edge+(edge-center).normalized()*1.5
	var avatar=host.coop.avatars[2]; avatar.health=100; avatar.position=Vector3(near.x,host.world.cabin_floor,near.y)
	host.coop.last_shot.erase(2)
	guest.coop.submit_shot(avatar.position+Vector3.UP,Vector3.FORWARD,0,0)
	check(not host.coop.last_shot.has(2),"Host rejects guest firing within cabin apron")
	for game in session.games: game.coop.leave()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(guest.progress.save_path+suffix))
	print("NEW_ENEMY_COOP_FAILURES ",failures); quit(1 if failures else 0)
