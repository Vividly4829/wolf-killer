extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func animal(kind: String,p: Vector3) -> Node3D:
	var a:=preload("res://scripts/wildlife.gd").new(); a.game=game; a.species=kind; game.add_child(a); a.position=p; a.set_physics_process(false); return a
func run() -> void:
	game=preload("res://scripts/main.gd").new(); game.progress.transient=true; game.progress.save_path="user://expansion_test_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_run(false); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false); game.campaign.running=false
	AudioServer.set_bus_mute(0,true)
	game.player.position=game.world.exterior_rally_point; game.begin_wave(); game.campaign.running=false
	check(game.nodes_in_group("wildlife").filter(func(a): return a.species=="moose" and not a.is_queued_for_deletion()).size()==2,"two ambient moose populate each round")
	for a in game.nodes_in_group("wildlife"): a.set_physics_process(false)
	var travel=game.fast_travel
	check(travel.points.size()==5 and travel.points[1].z<0 and travel.points[2].x>0 and travel.points[3].z>0 and travel.points[4].x<0,"four watchtowers and main cabin form travel network")
	for i in range(1,5):
		var p: Vector3=travel.points[i]
		check(game.world.nav.valid(game.world.nav.at(p.x,p.z)),"tower %d is on reachable terrain"%i)
		game.player.position=travel.points[0]
		check(travel.travel(1,i) and game.player.position.distance_to(p)<.1,"travel reaches tower %d"%i)
		check(travel.travel(1,0) and game.world.is_safe_position(game.player.position),"travel returns to main cabin")
	game.player.position=Vector3(140,80,150)
	check(not travel.travel(1,1),"travel rejected away from a station")
	var moose=animal("moose",Vector3(140,80,140)); moose.defensive_cooldown=10
	check(moose.max_health==650 and not moose.alerted,"moose starts passive with 650 HP")
	moose.damage(200)
	check(moose.alerted and moose.defensive_left>0 and moose.health==450,"shooting moose provokes without bypassing health")
	moose.defensive_deer(.1)
	check(moose.alerted and moose.defensive_left>0,"moose remains provoked while flinching")
	game.affliction.psychedelic=true; game.player.position=Vector3(-100,80,-100)
	var deer=animal("deer",Vector3(145,80,140))
	check(game.radar_animals().has(moose) and not game.radar_animals().has(deer),"psychedelic extends danger markers without passive-animal clutter")
	game.affliction.psychedelic=false
	game.player.position=Vector3(140,80,146)
	var a=animal("moose",Vector3(138,80,140)); var b=animal("moose",Vector3(142,80,140)); var far=animal("moose",Vector3(140,80,130))
	var spec: Dictionary=game.WeaponCatalog.weapon(35); var excluded: Array[RID]=[]
	check(is_equal_approx(spec.magazine*spec.interval,5.0),"five seconds continuous flame fuel per magazine")
	await physics_frame; await physics_frame
	game.shot_review.begin_shot(false)
	game.fire_ballistic(Vector3(140,81.55,146),Vector3.FORWARD,spec,game.shot_review.serial,1,excluded)
	check(a.health<650 and b.health<650 and far.health==650,"wide flame damages both sides of pack but not distant animal")
	check(a.health>550 and b.health>550,"each pulse hits each victim only once")
	check(game.WeaponCatalog.weapon(18).damage>=game.WeaponCatalog.weapon(0).damage and game.WeaponCatalog.weapon(19).damage>=game.WeaponCatalog.weapon(0).damage and game.WeaponCatalog.weapon(20).damage>game.WeaponCatalog.weapon(0).damage,"throwing weapons rival musket, spear exceeds it")
	var wolf=game.WolfScript.new(); wolf.configure(game,game.world.wolf_nav,1,65); game.add_child(wolf); wolf.position=game.player.position+Vector3.FORWARD; wolf.set_physics_process(false); game.wolves.append(wolf)
	game.health=100; check(game.start_wolf_struggle(wolf),"wolf begins close struggle")
	var before: float=wolf.health
	game.player.controller_device=0
	var trigger:=InputEventJoypadMotion.new(); trigger.device=0; trigger.axis=JOY_AXIS_TRIGGER_RIGHT; trigger.axis_value=1
	Input.parse_input_event(trigger); Input.flush_buffered_events()
	game._update_struggle(.01)
	check(is_equal_approx(before-wolf.health,10) and is_instance_valid(game.player.struggle_knife),"one defensive stab deals ten damage and displays knife")
	game.end_wolf_struggle(true)
	var at: Vector3=wolf.position; wolf._physics_process(.1)
	check(wolf.reaction.down>=3 and wolf.position==at,"released wolf cannot move during three-second flinch")
	trigger.axis_value=0; Input.parse_input_event(trigger.duplicate()); Input.flush_buffered_events()
	game.player.controller_device=-1
	game.rituals.grant("wolf",game.level+3); game.level=30
	check(game.rituals.factor("damage")==1.25,"25% damage wolf ritual survives all later rounds")
	if OS.get_cmdline_user_args().has("--capture"):
		game.world.weather.hour=13; game.world.weather.apply(); game.player.weapon.hide(); game.player.struggle_knife.hide(); game.player.clear_injuries(); game.damage_flash=0
		game.shot_review.hide(); game.dialogue_left=0
		moose.position=game.world.exterior_rally_point+Vector3(3,0,3); moose.reaction.down=0; moose.model.rotation=Vector3.ZERO
		game.player.camera.global_position=moose.position+Vector3(5,2.1,4); game.player.camera.look_at(moose.position+Vector3(0,1.35,0))
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/expansion-moose.png")
		for i in range(1,5):
			game.player.camera.global_position=travel.points[i]+Vector3(10,13,10); game.player.camera.look_at(travel.points[i]+Vector3(3,4,0))
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/expansion-tower-%d.png"%i)
		game.player.position=travel.points[0]; travel.open_menu()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/expansion-travel-menu.png")
	game.queue_free(); await process_frame
	print("GAMEPLAY_EXPANSION failures=",failures); quit(1 if failures else 0)
