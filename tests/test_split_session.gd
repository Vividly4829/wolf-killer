extends SceneTree
var failures := 0
var controller_id := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func tap(button: int) -> void:
	for down in [true,false]:
		var event:=InputEventJoypadButton.new()
		event.device=controller_id; event.button_index=button; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()
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
	var original=load("res://scripts/main.gd").new()
	original.progress.save_path="user://split_test_%d.cfg"%OS.get_process_id()
	root.add_child(original)
	original.player.use_input_device(0) # Entering from a controller-operated menu must not give P1 the pad.
	var session=load("res://scripts/split_session.gd").new()
	session.secondary_save_path="user://split_guest_test_%d.cfg"%OS.get_process_id()
	root.add_child(session)
	await session.launch(original)
	var host=session.games[0]; var guest=session.games[1]
	controller_id=guest.controller_device
	check(host.mode=="playing" and guest.mode=="playing","both players are active as soon as launch returns, without joining")
	check(not host.coop.awaiting_spawn and not guest.coop.awaiting_spawn,"neither local player waits for a connection")
	check(host.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and guest.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"split screen opens no network sockets")
	check(host.coop.peer_id()==1 and guest.coop.peer_id()==2,"two stable local player identities")
	check(guest.player.camera.current and guest.level==host.level,"controller uses its gameplay camera and shared wave")
	check(host.coop.avatars.size()==1 and guest.coop.avatars.size()==1 and guest.coop.client(),"both hunters can see their teammate immediately")
	# Rewards are gross round income, shared through the same host snapshot as online play.
	host.coop.award(25)
	host.coop.clock+=1; host.coop._process(.2)
	check(host.coop.earnings_text()==guest.coop.earnings_text() and guest.coop.round_earnings.get(1)==25 and guest.coop.round_earnings.get(2)==25,"both HUDs show round earnings for both hunters")
	guest.progress.money-=10
	host.coop.clock+=1; host.coop._process(.2)
	check(guest.coop.round_earnings.get(2)==25,"spending does not reduce gross round earnings")
	host.coop.reset_round_earnings()
	host.coop.clock+=1; host.coop._process(.2)
	check(guest.coop.round_earnings.get(1)==0 and guest.coop.round_earnings.get(2)==0,"new-round earnings reset is replicated")
	var deadline:=0
	if OS.get_cmdline_user_args().has("--capture"):
		AudioServer.set_bus_volume_db(0,-80)
		for game in session.games:
			game.world.weather.hour=13; game.world.weather.apply()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/split-local-start.png")
	check(host.get_world_3d()!=guest.get_world_3d(),"local physics worlds isolated")
	check(host.player.position.distance_to(guest.player.position)>20,"local hunters have different building spawns")
	check(host.player.controller_device==-1 and guest.player.controller_device==controller_id,"keyboard and controller assigned separately")
	check(host.nodes_in_group("wildlife").all(func(n): return host.is_ancestor_of(n)),"wildlife queries scoped to local world")
	await process_frame # Allow viewport rectangles to be laid out before mouse events.
	var keyboard:=InputEventKey.new(); keyboard.physical_keycode=KEY_W; keyboard.pressed=true
	Input.parse_input_event(keyboard); Input.flush_buffered_events()
	check(host.player.key_held(KEY_W) and not guest.player.key_held(KEY_W),"WASD belongs exclusively to player 1")
	keyboard.pressed=false; Input.parse_input_event(keyboard.duplicate()); Input.flush_buffered_events()
	var host_yaw: float=host.player.yaw; var guest_yaw: float=guest.player.yaw
	var mouse:=InputEventMouseMotion.new(); mouse.relative=Vector2(12,0)
	Input.parse_input_event(mouse); Input.flush_buffered_events()
	if DisplayServer.get_name()=="headless":
		print("SKIP mouse capture: dummy display cannot capture the cursor; covered by native render run")
	else:
		check(host.player.yaw!=host_yaw and guest.player.yaw==guest_yaw,"mouse look belongs exclusively to player 1")
	guest.player.set_physics_process(false)
	var axis:=InputEventJoypadMotion.new(); axis.device=controller_id; axis.axis=JOY_AXIS_LEFT_Y; axis.axis_value=-1
	Input.parse_input_event(axis); Input.flush_buffered_events()
	check(guest.player.pad_move().y<-.9 and not host.player.key_held(KEY_W),"controller movement does not drive keyboard player")
	var jump:=InputEventJoypadButton.new(); jump.device=controller_id; jump.button_index=JOY_BUTTON_A; jump.pressed=true
	Input.parse_input_event(jump); Input.flush_buffered_events(); guest.player.poll_controller(.016)
	check(guest.player._jump_velocity>0 and host.player._jump_velocity==0,"controller jump is independent")
	axis.axis_value=0; jump.pressed=false; Input.parse_input_event(axis.duplicate()); Input.parse_input_event(jump.duplicate()); Input.flush_buffered_events()
	# Exercise the real controller events through the split viewport and local pickup.
	var guest_id: int=guest.coop.peer_id()
	var drops: Array=host.world.houses.drops.duplicate(); drops[0]=18
	host.world.houses.apply_drops(drops)
	guest.world.houses.apply_drops(drops)
	guest.player.position=guest.world.houses.positions[0]
	host.coop.avatars[guest_id].position=guest.player.position
	check(guest.interaction_prompt().begins_with("[ Y ] TAKE"),"split-screen hunter sees controller pickup prompt")
	tap(JOY_BUTTON_Y)
	deadline=Time.get_ticks_msec()+5000
	while not guest.progress.owned.has(18) and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	check(guest.current_weapon==18 and host.world.houses.drops[0]==-1,"controller Y claims a host-authoritative pickup")
	tap(JOY_BUTTON_LEFT_SHOULDER)
	check(guest.current_weapon==0 and host.current_weapon==0,"LB changes only controller hunter's weapon")
	guest.progress.money=10000; guest.player.position=guest.world.shop_position
	tap(JOY_BUTTON_Y)
	check(guest.mode=="shop" and host.mode=="playing","Y opens only controller hunter's store")
	tap(JOY_BUTTON_DPAD_DOWN); tap(JOY_BUTTON_A)
	check(guest.current_weapon==1 and not host.progress.owned.has(1),"controller buys and equips independently in split screen")
	tap(JOY_BUTTON_B)
	check(guest.mode=="playing" and host.player.controller_device==-1,"B exits store without taking keyboard hunter's input")
	# Controller coffee goes through the authoritative shared-session handler.
	var coffee_spot:=coffee_position(guest.world,3)
	check(coffee_spot.is_finite(),"controller cabin has reachable coffee")
	guest.player.position=coffee_spot
	host.coop.avatars[guest_id].position=coffee_spot
	guest.health=40; host.coop.avatars[guest_id].health=40
	var host_hp: float=host.health
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(guest.health==70 and host.coop.avatars[guest_id].health==70 and host.health==host_hp,"controller coffee heals only P2 and updates authoritative health")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(guest.health==70,"controller coffee refill cooldown prevents repeated healing")
	await create_timer(.25).timeout
	check(guest.health==70 and host.coop.avatars[guest_id].health==70,"coffee healing survives position and health replication")
	tap(JOY_BUTTON_Y)
	check(guest.mode=="shop" and host.mode=="playing","controller opens store inside a neighboring cabin")
	tap(JOY_BUTTON_B)
	# Shots have immediate local audio and a single positional report for peers.
	host.player.set_physics_process(false)
	host.player.position=host.world.exterior_rally_point
	guest.player.position=host.player.position+Vector3.RIGHT*3
	host.coop.avatars[guest_id].position=guest.player.position
	host.player.pitch=-1.3; host.player._update_rotation()
	guest.player.pitch=-1.3; guest.player._update_rotation()
	host.sounds.silent=false; guest.sounds.silent=false
	host.fire_cooldown=0; host.fire_weapon()
	await create_timer(.3).timeout
	check(host.sounds.gun_index==1 and host.sounds.gun_spatial_index==0 and guest.sounds.gun_spatial_index==1,"host gunshot heard locally once and spatially by controller hunter")
	guest.fire_cooldown=0; guest.fire_weapon()
	await create_timer(.3).timeout
	check(guest.sounds.gun_index==1 and guest.sounds.gun_spatial_index==1 and host.sounds.gun_spatial_index==1,"client gunshot replicated without echoing back to its shooter")
	check(host.shot_review.trajectories.size()==1 and guest.shot_review.trajectories.size()==int(guest.weapon_spec().pellets),"each split-screen hunter receives their own shot paths, including shotgun misses")
	# These shots start beside cabin eaves, so a pellet may hit the roof.
	check(guest.shot_review.trajectories[0].complete and guest.shot_review.trajectories[0].travelled>0 and guest.shot_review.trajectories[0].travelled<=float(guest.weapon_spec().range)+.01,"controller shot review includes host-calculated distance within weapon range")
	guest.shot_review.begin_shot(true)
	var bolt=preload("res://scripts/crossbow_bolt.gd").new()
	host.add_child(bolt)
	bolt.launch(host,Vector3(0,100,0),Vector3.FORWARD,host.WeaponCatalog.weapon(3))
	bolt.shooter_peer=guest_id; bolt.review_serial=guest.shot_review.serial
	bolt.set_physics_process(false)
	for frame in 300:
		if bolt.is_queued_for_deletion(): break
		bolt._physics_process(.02)
	check(guest.shot_review.trajectories.size()==1 and guest.shot_review.trajectories[0].curved and guest.shot_review.trajectories[0].complete,"controller receives completed projectile arc from host")
	check(not host.shot_review.trajectories[0].projectile,"controller projectile cannot replace keyboard hunter's shot review")
	if OS.get_cmdline_user_args().has("--capture"):
		var preview_wolf=preload("res://scripts/wolf.gd").new()
		preview_wolf.configure(host,host.world.wolf_nav,4,751,true)
		host.add_child(preview_wolf); preview_wolf.set_physics_process(false)
		host.set_process(false); guest.set_process(false)
		host.struggle_wolf=preview_wolf; host.struggle_progress=.65
		guest.struggle_wolf=preview_wolf; guest.struggle_progress=.30
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/split-credits-struggle.png")
		host.struggle_wolf=null; guest.struggle_wolf=null; preview_wolf.queue_free()
		host.set_process(true); guest.set_process(true)
	var host_selection: int=host.shot_review.selected
	tap(JOY_BUTTON_DPAD_DOWN)
	check(guest.shot_review.selected==1 and host.shot_review.selected==host_selection,"controller browses only P2 shot history")
	var review_key:=InputEventKey.new(); review_key.physical_keycode=KEY_X; review_key.pressed=true
	Input.parse_input_event(review_key); Input.flush_buffered_events()
	check(guest.shot_review.selected==1,"keyboard X never changes P2 shot history")
	# Local mode cannot turn into an online host or client, even via direct calls.
	host.coop.host_session(); guest.coop.join_session("127.0.0.1")
	check(host.coop.peer_id()==1 and guest.coop.peer_id()==2 and host.mode=="playing" and guest.mode=="playing","online host/join requests cannot replace the local session")
	# A fallen teammate revives when the survivor completes the shared hunt.
	host.set_process(false); guest.set_process(false)
	host.campaign.set_process(false)
	if host.intermission: host.begin_wave()
	for animal in host.nodes_in_group("wildlife"): animal.set_physics_process(false)
	host.coop.shooter=1
	host.coop.friendly_hit(2,1000)
	check(guest.mode=="waiting" and guest.health==0 and host.mode=="playing","local friendly fire can down only player 2")
	var deer=host.nodes_in_group("wildlife").filter(func(a): return not a.dead and not a.is_queued_for_deletion() and a.species=="deer")[0]
	deer.damage(1000)
	await process_frame
	host.coop._process(.1)
	check(host.level==2 and guest.level==2 and host.mode=="resting" and guest.mode=="resting" and guest.health==100,"survivor completes hunt and both recover for round two")
	host.finish_rest(); guest.finish_rest()
	host.player.position=host.world.exterior_rally_point
	guest.player.position=host.player.position+Vector3.RIGHT*3
	host.coop.avatars[2].position=guest.player.position
	host.coop.friendly_hit(2,1000); host._apply_health_damage(1000)
	check(host.mode=="dead" and guest.mode=="dead" and host.level==1 and guest.level==1,"local team wipe resets both hunters")
	tap(JOY_BUTTON_A)
	check(host.mode=="playing" and guest.mode=="playing" and host.health==100 and guest.health==100,"controller retries both players immediately without reconnecting")
	check(host.player.controller_device==-1 and guest.player.controller_device==controller_id,"input ownership survives death and restart")
	var sync_wolf=host.campaign.spawn_wolf(host.world.exterior_rally_point,false,false,99)
	sync_wolf.set_physics_process(false)
	host.coop.clock+=1; host.coop._process(.2)
	var replica=guest.coop.replicas[sync_wolf.get_instance_id()]
	check(is_instance_valid(replica.reaction),"split wolf has reaction controller before taking damage")
	sync_wolf.damage(10000)
	host.coop.clock+=1; host.coop._process(.2)
	replica.reaction._process(.3)
	check(replica.dead and replica.health==0 and replica.reaction.falling and absf(replica.model.rotation.z)>1,"host wolf kill arrives as collapsed corpse on controller view")
	var soldier=preload("res://scripts/musketeer.gd").new(); soldier.game=host; soldier.species="musketeer"
	host.add_child(soldier); soldier.position=host.world.exterior_rally_point; soldier.set_physics_process(false); soldier.cooldown=8
	host.coop.clock+=1; host.coop._process(.2)
	var soldier_copy=guest.coop.replicas[soldier.get_instance_id()]
	check(soldier_copy.species=="musketeer" and soldier_copy.model.get_child(0).reloading,"musketeer model and reload state replicate to the second player")
	host.coop.send_to(2,"ballistic_effect",[PackedVector3Array([soldier.position+Vector3.UP,soldier.position+Vector3.UP+Vector3.RIGHT*5]),"split-fx-test",1])
	check(guest.combat_fx.shots.has("split-fx-test"),"smoky firearm trails replicate to the other viewport")
	host.coop.send_to(2,"surface_impact",[soldier.position,Vector3.UP,"wood"])
	check(guest.combat_fx.get_children().any(func(n):return str(n.name).begins_with("BulletScar")),"surface impacts replicate to the other viewport")
	host.level=11; guest.level=11
	host.affliction.infected_wave=5; guest.affliction.infected_wave=5
	host.coop.avatars[2].set_meta("infected_wave",5)
	host.begin_rest(); host.coop.clock+=1; host.coop._process(.2)
	check(guest.health==200 and host.health==200,"both infected players retain doubled health after next werewolf round")
	host.finish_rest(); guest.finish_rest()
	guest.player.position=host.mushrooms.spots[0]; host.coop.avatars[2].position=guest.player.position
	guest.coop.send_to(1,"eat_mushroom",[0])
	check(guest.affliction.psychedelic and not host.affliction.psychedelic and is_equal_approx(guest.health,140),"controller mushroom consumption affects only that player and stacks with lycanthropy")
	check(is_equal_approx(host.coop.avatar_maximum(host.coop.avatars[2]),140),"host applies psychedelic maximum to remote hunter")
	host.coop.clock+=1; host.coop._process(.2)
	check(guest.coop.avatars[1].character.beast,"infected host appearance replicates to other viewport")
	host.coop.send_to(2,"flame_effect",[host.player.position+Vector3.UP,host.player.position+Vector3.UP+Vector3.FORWARD*6])
	check(guest.combat_fx.get_children().any(func(n): return str(n.name).begins_with("FlameJet")),"flamethrower effects replicate locally")
	host.level=12; host.begin_rest(); host.coop.clock+=1; host.coop._process(.2)
	check(not guest.affliction.psychedelic and guest.health==200 and host.coop.avatars[2].health==200,"next rest clears remote psychedelic penalty and restores transformed health")
	for game in session.games:
		game.coop.leave(); set_multiplayer(null,game.get_path())
		for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	session.queue_free()
	await process_frame
	quit(1 if failures else 0)
