extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var original=load("res://scripts/main.gd").new(); original.progress.save_path="user://coast_split_%d.cfg"%OS.get_process_id(); root.add_child(original)
	var session=load("res://scripts/split_session.gd").new(); session.secondary_save_path="user://coast_guest_%d.cfg"%OS.get_process_id(); root.add_child(session); await session.launch(original)
	var host=session.games[0]; var guest=session.games[1]
	for game in [host,guest]:
		game.set_process(false); game.campaign.set_process(false); game.campaign.clear_round(); game.player.set_physics_process(false); game.boats.set_physics_process(false)
	await physics_frame
	var boats=host.boats; var boat: Dictionary=boats.fleet[0]; var berth: Vector3=boat.p; var shore: Vector3=boat.shore
	host.player.position=shore; guest.player.position=shore; host.coop.avatars[2].position=shore
	check(boats.request(1),"Keyboard player boards as driver")
	guest.player.controller_button(JOY_BUTTON_Y)
	check(boat.riders==[1,2],"Controller player joins the same boat through host validation")
	check(guest.boats.fleet[0].riders==[1,2],"Both views see the same occupied seats")
	check(host.player.position.distance_to(host.coop.avatars[2].position)>.8,"Passengers have distinct places")
	var forward:=InputEventKey.new(); forward.physical_keycode=KEY_W; forward.pressed=true; Input.parse_input_event(forward); Input.flush_buffered_events()
	host.player._physics_process(1.0/60)
	check(boat.axis.y<-.9,"Keyboard W drives boat instead of walking off the deck")
	var released:=forward.duplicate(); released.pressed=false; Input.parse_input_event(released); Input.flush_buffered_events(); boats.control(1,Vector2.ZERO,true)
	boats.control(2,Vector2(0,-1),false)
	check(boat.axis==Vector2.ZERO,"Passenger cannot override steering")
	boat.p=Vector3(180,-.05,130); boat.yaw=0; boats.place_riders()
	check(boats.water_clear(boat.p,0,0),"Speed test begins in unobstructed open water")
	var start: Vector3=boat.p
	for frame in 240:
		boats.control(1,Vector2(0,-1),false); boats._physics_process(1.0/60)
	check(absf(boat.speed-boats.TOP_SPEED)<.01,"Motorboat reaches specified maximum speed")
	check(boat.p.distance_to(start)>20,"Boat actually moves over the sea")
	host.coop._process(.2)
	check(guest.boats.fleet[0].p.distance_to(boat.p)<.01,"Shared snapshots carry boat movement")
	var authoritative: Vector3=host.coop.avatars[2].position
	host.coop.local_sender=2; host.coop.pose(authoritative,0,false,.03,100,0,false,host.coop.generation); host.coop.local_sender=0
	check(host.coop.avatars[2].position.distance_to(authoritative)<.01,"Passenger pose is not snapped back to land navigation")
	check(not boats.request(1),"Driver cannot jump off underway")
	for frame in 100: boats.control(1,Vector2.ZERO,true); boats._physics_process(1.0/60)
	check(absf(boat.speed)<=boats.STOP_SPEED,"Brake stops the motorboat")
	check(not boats.request(1),"Stationary boat in open sea still prevents disembarking")
	boat.p=berth; boats.place_riders()
	check(boats.request(1),"Driver can disembark after returning to shore")
	check(boat.riders==[2],"Remaining passenger becomes driver")
	boats.control(2,Vector2(0,-1),false)
	check(boat.axis.y==-1,"New controller driver can steer")
	boat.axis=Vector2.ZERO
	for id in [3,4,5,6]:
		var avatar=load("res://scripts/coop_avatar.gd").new(); avatar.peer_id=id; host.add_child(avatar); host.coop.avatars[id]=avatar; avatar.position=shore
	check(boats.request(3) and boats.request(4) and boats.request(5),"Four players can share a boat")
	check(not boats.request(6),"Fifth passenger is rejected")
	boats.release_all()
	check(boat.riders.is_empty() and boat.speed==0 and boat.p==boat.home,"Round reset clears seats and returns boats to their moorings")
	for id in [3,4,5,6]: host.coop.avatars[id].queue_free(); host.coop.avatars.erase(id)
	print("COASTAL_COOP_COMPLETE failures=",failures)
	session.queue_free(); await process_frame; quit(1 if failures else 0)
