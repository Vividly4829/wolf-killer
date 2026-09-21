extends SceneTree
var game: Node3D
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failures+=1
func run() -> void:
	var test_seed:=82713
	var ticks:=720
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): test_seed=int(arg.get_slice("=",1))
		if arg.begins_with("--ticks="): ticks=int(arg.get_slice("=",1))
	seed(test_seed)
	game=load("res://scripts/main.gd").new()
	game.progress.save_path="user://deer_shore_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.set_process(false); game.player.set_physics_process(false)
	game.start_run(); game.player.position=game.world.exterior_rally_point
	game.begin_wave(); game.free_play=true; game.campaign.set_process(false)
	game.player.position=Vector3(1000,100,1000)
	for a in game.nodes_in_group("wildlife"):
		if a.species=="deer" and not a.is_queued_for_deletion(): check(a.land_room(a.position)>=.625,"deer spawns in roomy habitat")
	for a in game.nodes_in_group("wildlife"): a.queue_free()
	await process_frame
	var nav=game.world.wolf_nav
	var fixtures: Array=[]
	for cell in nav.reachable:
		var p: Vector3=nav.point(cell)
		if p.y<.2 or p.y>2.8 or fixtures.any(func(f): return p.distance_to(f[0])<35): continue
		var clear:=0; var inland:=Vector3.ZERO
		for i in 8:
			var d:=Vector3.RIGHT.rotated(Vector3.UP,i*TAU/8)
			if nav.line_clear(p.x,p.z,p.x+d.x*5,p.z+d.z*5):
				clear+=1; inland=d
		if clear<2 or clear>4: continue
		fixtures.append([p,p+inland*5])
		if fixtures.size()==4: break
	check(fixtures.size()==4,"four shoreline fixtures across the real map")
	var animals: Array=[]; var origins: Array=[]; var stalled: Array=[]; var maxima: Array=[]; var movement_times: Array=[]
	for f in fixtures:
		print("COAST ",f)
		for i in 3:
			var deer=load("res://scripts/wildlife.gd").new(); deer.game=game; deer.species="deer"
			game.add_child(deer); deer.set_physics_process(false)
			deer.position=f[0]; deer.frighten(f[1],ticks/30.0+10)
			animals.append(deer); origins.append(deer.position); stalled.append(0.0); maxima.append(0.0)
	for tick in ticks:
		await physics_frame
		var started:=Time.get_ticks_usec()
		for i in animals.size():
			var deer=animals[i]
			deer._physics_process(1.0/30)
			if not nav.valid(nav.at(deer.position.x,deer.position.z)): check(false,"deer stays on navigable land")
			if tick%30==29:
				stalled[i]=float(stalled[i])+1 if deer.position.distance_to(origins[i])<.4 else 0.0
				maxima[i]=maxf(maxima[i],stalled[i]); origins[i]=deer.position
				if stalled[i]>=2: print("STALL ",i," sec=",tick/30," p=",deer.position," goal=",deer.goal," first=",deer.route[0] if not deer.route.is_empty() else Vector3.INF," search=",deer.search.closed.size() if deer.search else -1)
		movement_times.append(Time.get_ticks_usec()-started)
	for i in animals.size():
		print("DEER ",i," max still ",maxima[i]," at ",animals[i].position)
		check(maxima[i]<=4,"frightened deer %d never stuck for over four seconds"%i)
	var closest:=INF
	for i in animals.size():
		for j in range(i+1,animals.size()): closest=minf(closest,animals[i].position.distance_to(animals[j].position))
	check(closest>.9,"crowded deer spread apart instead of stacking at shore")
	movement_times.sort()
	print("MOVEMENT us median=",movement_times[movement_times.size()/2]," p95=",movement_times[int(movement_times.size()*.95)]," max=",movement_times[-1]," nearest deer=",closest)
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; quit(1 if failures else 0)
