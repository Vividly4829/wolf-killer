extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var game=preload("res://scripts/main.gd").new(); game.progress.save_path="user://polish_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720); AudioServer.set_bus_mute(0,true)
	for animal in game.wolves+game.nodes_in_group("wildlife"): animal.set_physics_process(false)
	check(game.player.SPRINT_SPEED==8.1 and game.player.MAX_STAMINA==450,"sprint speed and stamina each increased50percent")
	game.player.position=Vector3(150,80,150); game.player.is_sprinting=true
	var ammo: int=game.current_ammo(); game.fire_weapon()
	check(game.current_ammo()==ammo and not game.quick_throw(),"sprinting blocks gunfire and quick throws")
	game.player.is_sprinting=false
	for id in range(31,35):
		var model: Dictionary=preload("res://scripts/weapon_model_builder.gd").new().build(id)
		var materials: Dictionary={}; var missing:=0
		for mesh in model.root.find_children("*","MeshInstance3D",true,false):
			for i in mesh.mesh.get_surface_count():
				var mat: Material=mesh.get_active_material(i)
				if mat: materials[mat.get_instance_id()]=true
				else: missing+=1
		check(missing==0 and materials.size()>=3,"new weapon%d retains multiple coloured materials"%id); model.root.free()
	var foliage:=0; var solids:=0
	for node in game.world.get_node("OriginalIsland").find_children("*","MeshInstance3D",true,false):
		var tags: Dictionary=node.get_meta("extras",{})
		if tags.get("gameClass","")=="scenery" and not tags.get("collision",false):
			foliage+=1; check(node.find_children("*","StaticBody3D",true,false).is_empty(),"leafy scenery has no bullet-blocking collider")
		elif tags.get("collision",false) and not node.find_children("*","StaticBody3D",true,false).is_empty(): solids+=1
	check(foliage>0 and solids>0,"soft foliage removed while solid geometry still blocks shots")
	var raider=preload("res://scripts/campaign_threat.gd").new(); raider.game=game; raider.species="raider"; game.add_child(raider); raider.set_physics_process(false)
	check(raider.raider_weapon in [18,19,20,21,22,23],"raider loadout contains no firearm")
	var wall:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(4,4,.2); shape.shape=box; wall.add_child(shape); game.add_child(wall); wall.position=Vector3(150,81,148)
	await physics_frame; await physics_frame
	var hp: float=game.health
	var arrow=preload("res://scripts/raider_projectile.gd").new(); arrow.game=game; arrow.attacker=raider; game.add_child(arrow); arrow.set_physics_process(false); arrow.position=Vector3(150,81,146); arrow.velocity=Vector3(0,0,40); arrow._physics_process(.2)
	check(arrow.is_queued_for_deletion() and game.health==hp,"enemy projectile stops at wall without damaging player behind it")
	wall.position.x+=20; await physics_frame; await physics_frame
	arrow=preload("res://scripts/raider_projectile.gd").new(); arrow.game=game; arrow.attacker=raider; game.add_child(arrow); arrow.set_physics_process(false); arrow.position=Vector3(150,81,146); arrow.velocity=Vector3(0,0,40); arrow._physics_process(.2)
	check(game.health<hp,"unobstructed enemy projectile damages player along swept path")
	var grenade=preload("res://scripts/crossbow_bolt.gd").new(); game.add_child(grenade); grenade.launch(game,Vector3(150,82,140),Vector3.FORWARD,game.WeaponCatalog.weapon(24)); grenade.set_physics_process(false)
	check(is_instance_valid(grenade.fuse_label),"thrown grenade carries visible countdown")
	grenade._physics_process(.1); check(grenade.fuse_label.text.begins_with("2.7"),"grenade countdown follows actual fuse time"); grenade.queue_free()
	wall.position.x-=20; await physics_frame; await physics_frame
	game.player.position=Vector3(165,80,150)
	var shell=preload("res://scripts/crossbow_bolt.gd").new(); game.add_child(shell); shell.launch(game,Vector3(150,81,147),Vector3.BACK,game.WeaponCatalog.weapon(34)); shell.set_physics_process(false); shell._physics_process(.05)
	check(shell.get_meta("detonated",false),"launcher explodes at first impact even before0.2seconds")
	check(not game.nodes_in_group("explosion_effects").is_empty(),"impact produces visible explosion effect")
	var deer=game.nodes_in_group("wildlife").filter(func(a):return a.species=="deer")[0]
	game.free_play=false; game.player.position=game.world.exterior_rally_point; deer.position=game.player.position+Vector3(0,0,1)
	deer.defensive_left=2; deer.defensive_target=game.player; deer.defensive_hit=0; hp=game.health
	deer.defensive_deer(.001)
	check(deer.alerted and game.health<hp,"cornered deer can become hostile and strike")
	deer.defensive_left=.001; deer.defensive_deer(.01)
	check(not deer.alerted and deer.fear_left>0,"defensive deer returns to fleeing")
	game.free_play=true; deer.defensive_left=2
	check(not deer.defensive_deer(.1),"free-play deer stay nonhostile")
	wall.position.x+=50
	for effect in game.nodes_in_group("explosion_effects"): effect.queue_free()
	await physics_frame; await physics_frame
	game.player.position=Vector3(150,80,150); game.player.yaw=0; game.player.pitch=0; game.player._update_rotation(); deer.position=Vector3(151,80,140)
	game.shot_review.begin_shot(); var snapshot: Array=game.shot_review.displayed().nearby
	check(snapshot.any(func(record): return record.target_uid==deer.get_instance_id()),"shot captures nearby unhit animal at firing time")
	deer.position+=Vector3.RIGHT*30
	game.fire_ballistic(game.player.camera.global_position,Vector3.FORWARD,game.WeaponCatalog.weapon(0),game.shot_review.serial,1,[]); game.shot_review._process(0)
	var labels=game.shot_review.replay.content.find_children("*","Label3D",true,false)
	check(labels.any(func(label):return label.text=="DEER / UNHIT"),"miss replay includes recorded nearby deer anatomy")
	if "--capture" in OS.get_cmdline_user_args():
		game.shot_review.replay.elapsed=1; game.shot_review.replay.update_frame()
		await create_timer(.2).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/polish-miss.png")
	var guest=preload("res://scripts/main.gd").new(); guest.progress.save_path="user://polish_guest_%d.cfg"%OS.get_process_id(); root.add_child(guest)
	game.coop.setup_local(guest.coop,1); guest.coop.setup_local(game.coop,2); game.coop._peer_connected(2)
	var dynamite=preload("res://scripts/crossbow_bolt.gd").new(); game.add_child(dynamite); dynamite.launch(game,Vector3(150,81,140),Vector3.FORWARD,game.WeaponCatalog.weapon(25)); dynamite.set_physics_process(false)
	game.coop.clock+=1; game.coop._process(.2)
	check(guest.coop.replicas[raider.get_instance_id()].raider_weapon==raider.raider_weapon,"co-op raider displays the host's bow or throwing weapon")
	check(guest.coop.bolt_replicas[dynamite.get_instance_id()].has_node("Fuse"),"co-op dynamite has visible replicated fuse countdown")
	var remote=game.coop.avatars[2]; remote.position=Vector3(150,80,150); remote.set_meta("sprinting",true)
	var bolt_count: int=game.nodes_in_group("player_bolts").size()
	game.coop.local_sender=2; game.coop.quick_throw_shot(remote.position+Vector3.UP*1.7,Vector3.FORWARD,18,1)
	check(game.nodes_in_group("player_bolts").size()==bolt_count,"host rejects sprinting remote quick throw")
	remote.set_meta("sprinting",false); game.coop.quick_throw_shot(remote.position+Vector3.UP*1.7,Vector3.FORWARD,18,1); game.coop.local_sender=0
	check(game.nodes_in_group("player_bolts").size()==bolt_count+1,"remote quick throw works again after sprint ends")
	game.coop.leave(); guest.coop.leave()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(guest.progress.save_path+suffix))
	guest.queue_free()
	game.restore_campaign()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; await process_frame
	print("HUNTING_COMBAT_POLISH failures=",failures); quit(1 if failures else 0)
