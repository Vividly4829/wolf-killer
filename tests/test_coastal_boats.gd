extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var game=load("res://scripts/main.gd").new()
	game.progress.save_path="user://coastal_test_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.start_run(true)
	game.player.enabled=false
	await physics_frame
	await physics_frame
	print("FLEET ",game.boats.snapshot())
	check(game.boats.fleet.size()==4,"Four boats placed by reachable quays")
	if game.boats.fleet.is_empty(): quit(1); return
	for index in game.boats.fleet.size():
		var vessel: Dictionary=game.boats.fleet[index]
		vessel.shore=game.boats.shore_exit(vessel.p)
		game.player.position=vessel.shore
		check(game.boats.request(1),"Boarding works at mapped berth %d"%(index+1))
		check(game.boats.request(1),"Shore exit works at mapped berth %d"%(index+1))
	check(game.boats.on_land(Vector3(190,0,-140)),"Northern context coastline uses the correct coordinate orientation")
	var boat: Dictionary=game.boats.fleet[0]
	check(is_equal_approx(game.boats.TOP_SPEED,IslandPlayer.SPRINT_SPEED*1.5),"Boat maximum speed is sprint plus 50 percent")
	check(boat.shore.is_finite(),"Starting berth has a valid shoreline exit")
	game.player.position=boat.shore
	check(game.boats.request(1),"Player can board a stopped boat by land")
	check(game.boats.occupied(1)==0,"Boarded player has assigned boat")
	check(game.player.position.distance_to(boat.p)<2,"Player placed inside boat")
	boat.speed=2
	check(not game.boats.request(1),"Cannot leave a moving boat")
	boat.speed=0
	check(game.boats.request(1),"Can disembark when stationary near shore")
	check(game.world.nav.valid(game.world.nav.at(game.player.position.x,game.player.position.z)),"Exit places feet on valid walkable terrain")
	var home: Vector3=boat.p
	boat.p=Vector3(180,-.05,130)
	game.player.position=boat.p
	check(not game.boats.request(1),"Cannot board in open water")
	boat.p=home
	check(not game.boats.water_clear(game.world.spawn_position,0,0),"Land blocks boat hull")
	check(not game.boats.water_clear(Vector3(230,0,0),0,0),"Boat remains inside playable sea bounds")
	var details=game.world.get_node("PhotoCoastalDetails")
	check(details.detail_count>500,"Photo detail includes batched cladding, window frames and wharf planks")
	for house in game.world.exploration_data.houses:
		check(game.world.nav.nearest(house.door[0],house.door[2],1)>=0,"Neighbour cabin doorway remains accessible: "+house.name if house.has("name") else "Neighbour doorway accessible")
	game.boats.release_all()
	game.queue_free(); await process_frame
	print("COASTAL_CHECKS_COMPLETE failures=",failures)
	quit(1 if failures else 0)
