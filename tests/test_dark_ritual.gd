extends SceneTree
var game: Node3D
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func spawn(species: String,p: Vector3) -> Node3D:
	var animal: Node3D
	if species in ["wolf","werewolf"]:
		animal=game.WolfScript.new(); animal.configure(game,game.world.wolf_nav,1,55); game.add_child(animal); animal.position=p; animal._ensure_reaction()
		if species=="werewolf": animal.make_werewolf()
	elif species in ["deer","moose","duck","goose","mink"]:
		animal=preload("res://scripts/wildlife.gd").new(); animal.game=game; animal.species=species; game.add_child(animal); animal.position=p
	else:
		animal=(load("res://scripts/"+species+".gd") if species in ["legionary","musketeer"] else preload("res://scripts/campaign_threat.gd")).new()
		animal.game=game; animal.species=species; game.add_child(animal); animal.position=p
	animal.set_physics_process(false)
	return animal
func run() -> void:
	game=preload("res://scripts/main.gd").new(); game.progress.transient=true; game.progress.save_path="user://ritual_test_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false); game.rituals.set_process(false)
	AudioServer.set_bus_mute(0,true); root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	var x:=140.0
	for species in game.rituals.BOONS:
		if species=="angel": continue
		var animal=spawn(species,Vector3(x,80,140)); x+=5
		animal.health=animal.max_health*.071
		check(not animal.reaction.incapacitated(),species+" above 7% stays active")
		animal.health=animal.max_health*.07
		check(animal.reaction.hold_incapacitated(),species+" exactly 7% becomes incapacitated")
		var p: Vector3=animal.position
		animal.bleeding_rate=10; animal._physics_process(2); animal.reaction._process(5)
		check(not animal.dead and animal.position==p and animal.reaction.down>0,species+" stays alive, down and stationary")
		animal.health=0
		check(not game.rituals.eligible(animal),species+" zero HP cannot be sacrificed")
		animal.queue_free()
	await process_frame
	var offering=spawn("deer",Vector3(140,80,140)); offering.damage(offering.max_health*.95)
	game.player.position=Vector3(140,80,142); game.health=100
	await physics_frame; await physics_frame
	game.player.position=Vector3(150,80,142)
	check(not game.rituals.start(1,offering.get_instance_id()),"distant sacrifice rejected")
	game.player.position=Vector3(140,80,142)
	var wall:=StaticBody3D.new(); game.add_child(wall); wall.position=Vector3(140,81,141); wall.collision_layer=1
	var collision:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(4,4,.2); collision.shape=box; wall.add_child(collision)
	await physics_frame; await physics_frame
	check(not game.rituals.start(1,offering.get_instance_id()),"wall blocks sacrifice interaction")
	wall.queue_free(); await physics_frame; await physics_frame
	check(game.rituals.start(1,offering.get_instance_id()),"nearby incapacitated victim starts ritual")
	check(not game.rituals.start(2,offering.get_instance_id()),"victim cannot be claimed twice")
	var ammo: int=game.current_ammo(); game.fire_cooldown=0; game.fire_weapon()
	check(game.current_ammo()==ammo,"ritual locks weapon use")
	game.rituals._process(2)
	check(not offering.dead and game.rituals.channeling(),"ritual cannot complete early")
	game._apply_health_damage(1,false)
	check(not game.rituals.channeling() and not offering.dead,"damage interrupts ritual without killing victim")
	check(game.rituals.start(1,offering.get_instance_id()),"interrupted victim remains available")
	if OS.get_cmdline_user_args().has("--capture"):
		game.player.camera.global_position=offering.position+Vector3(0,2.8,3); game.player.camera.look_at(offering.position)
		game.player.weapon.hide(); game.rituals._process(1.8)
		await create_timer(.4).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/dark-ritual.png")
	game.rituals._process(4.1)
	check(offering.dead and game.rituals.has_boon("deer"),"completed sacrifice kills victim and grants matching boon")
	check(not game.rituals.start(1,offering.get_instance_id()),"corpse cannot grant another boon")
	for species in game.rituals.BOONS: game.rituals.grant(species,game.level+3)
	check(is_equal_approx(game.player.get_reload_multiplier(),.75) and is_equal_approx(game.player.get_aim_spread_multiplier(),.7),"raider and musketeer boons affect weapon handling")
	check(is_equal_approx(game.weapon_spec().damage,game.WeaponCatalog.weapon(game.current_weapon).damage*1.25),"wolf boon increases actual weapon damage")
	check(game.rituals.all_radar() and game.rituals.factor("sneak")==1.5 and is_equal_approx(game.rituals.factor("stamina"),.65*.65) and game.rituals.factor("struggle")==1.35,"bird and movement boons expose distinct live modifiers")
	game.affliction.infected_wave=5; game.level=11
	for species in game.rituals.BOONS: game.rituals.grant(species,14)
	game.affliction.psychedelic=true
	check(is_equal_approx(game.maximum_health(),252),"moon blood stacks with lycanthropy and psychedelic")
	game.affliction.psychedelic=false; game.health=100; game._apply_health_damage(10,false)
	check(is_equal_approx(game.health,93.6),"bear boon reduces incoming damage")
	game.level=14; check(game.rituals.has_boon("deer") and is_equal_approx(game.rituals.factor("health"),1.8),"boons persist without round expiry")
	game.start_run(false); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false); game.rituals.set_process(false)
	game.player.position=game.world.exterior_rally_point; game.begin_wave()
	var target: Node3D=game.objective_targets()[0]; target.set_physics_process(false); target.damage(target.max_health*.95)
	game.player.position=target.position+Vector3(0,0,1.8)
	await physics_frame; await physics_frame
	var money: int=game.progress.money
	check(game.rituals.start(1,target.get_instance_id()),"mission target can be offered")
	game.rituals._process(4.1)
	await process_frame
	check(game.level==2 and game.progress.money>money and (not is_instance_valid(target) or target.dead),"sacrifice counts for mission and normal rewards exactly once")
	check(game.rituals.has_boon("deer"),"boon survives mission transition to cabin rest")
	game.queue_free(); await process_frame
	print("DARK_RITUAL failures=",failures); quit(1 if failures else 0)
