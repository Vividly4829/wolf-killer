extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var game=load("res://scripts/main.gd").new(); game.progress.save_path="user://pack_roam_%d.cfg"%OS.get_process_id(); root.add_child(game)
	game.start_run(); game.set_process(false); game.campaign.set_process(false); game.campaign.clear_round(); game.campaign.job={"kill":{}}; game.player.set_physics_process(false)
	await physics_frame
	game.campaign.rng.seed=341
	var nav=game.world.wolf_nav
	var start: Vector3=nav.point(nav.nearest(-57,24,8))
	var wolves: Array[Node3D]=[]
	for i in 4:
		var wolf: Node3D=game.campaign.spawn_wolf(start+Vector3(i,0,0),false,false,910)
		wolf.set_physics_process(false); wolves.append(wolf)
	game.free_play=true
	var first: Vector3=wolves[0]._roaming_goal(.01)
	check(first.distance_to(start)>10,"Pack chooses a destination beyond its spawn clearing")
	check(wolves[1]._roaming_goal(.01).distance_to(first)<7,"Pack shares a roaming destination with loose spacing")
	var traveled:=0.0
	for frame in 1000:
		var before: Vector3=wolves[0].position
		for wolf in wolves: wolf._physics_process(1.0/60)
		traveled+=wolves[0].position.distance_to(before)
		await physics_frame
	check(traveled>8,"Patrolling wolf follows terrain routes and travels more than eight metres")
	check(not wolves[0].alerted,"Roaming does not automatically reveal the player")
	print("PACK actual travel=",traveled," start=",start," end=",wolves[0].position)
	# Find open terrain to verify multi-sided encirclement independently of rocks.
	var center:=Vector3.INF
	for cell in nav.reachable:
		var p: Vector3=nav.point(cell)
		if p.distance_to(game.world.spawn_position)<35: continue
		var open:=true
		for angle in 8:
			var q:=p+Vector3(cos(angle*TAU/8),0,sin(angle*TAU/8))*6
			if nav.nearest(q.x,q.z,.7)<0: open=false; break
		if open: center=p; break
	check(center.is_finite(),"Map contains reachable encirclement terrain")
	if center.is_finite():
		var quadrants: Dictionary={}
		game.player.position=center
		for wolf in wolves:
			wolf._orbit_timer=0; wolf._pack.erase("encircle_bearing"); wolf.position=center+Vector3(7,0,0)
			var goal: Vector3=wolf._circle_goal(center,wolves)
			var d:=goal-center
			quadrants[Vector2i(1 if d.x>=0 else -1,1 if d.z>=0 else -1)]=true
		check(quadrants.size()>=3,"Pack takes positions on at least three sides of its target")
	for wolf in wolves: wolf.queue_free()
	game.wolves.clear(); await physics_frame
	game.free_play=false; game.player.position=game.world.spawn_position
	var beast: Node3D=game.campaign.spawn_wolf(start,true,false,911); beast.set_physics_process(false)
	var goal: Vector3=beast._roaming_goal(.1)
	check(goal.is_finite() and goal.distance_to(game.player.position)<30,"Werewolf searches a broad area around hunters")
	check(not beast.alerted,"Werewolf search preserves detection and warning before attacking")
	var distance:=0.0; var peak:=0.0
	for frame in 900:
		var before: Vector3=beast.position
		beast._time+=1.0/60; beast._tick_hunting(1.0/60)
		var step:=beast.position.distance_to(before); distance+=step; peak=maxf(peak,Vector2(beast.position.x-before.x,beast.position.z-before.z).length()*60)
		await physics_frame
	check(distance>5,"Unalerted werewolf actively travels through the map")
	check(peak<3.5,"Searching werewolf moves calmly rather than charging")
	print("WEREWOLF search travel=",distance," peak=",peak)
	print("PACK_ROAMING_COMPLETE failures=",failures)
	game.queue_free(); await process_frame; quit(1 if failures else 0)
