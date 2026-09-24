extends SceneTree
var failed:=0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=preload("res://scripts/main.gd").new(); game.progress.transient=true; game.mode="loading"
	root.add_child(game); game.start_run(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	game.campaign.running=true
	game.campaign.job=preload("res://scripts/campaign_catalog.gd").wave(game.level)
	var nav=game.world.wolf_nav
	var wolf=game.WolfScript.new(); wolf.configure(game,nav,6,81); game.add_child(wolf); wolf.set_physics_process(false)
	for house in game.world.exploration_data.houses:
		for size in [.85,1.3]:
			wolf.size_scale=size; wolf.position=nav.point(nav.nearest(house.center[0],house.center[1],3))
			var start: Vector3=wolf.position
			var end: Vector3=Vector3(house.end[0],house.end[1],house.end[2])
			var goal: Vector3=nav.point(nav.nearest(end.x,end.z,3))
			wolf.campaign_route.clear(); wolf.campaign_search=null; wolf.campaign_route_at=0
			for i in 1800:
				wolf._time+=1./60
				var dir: Vector3=wolf._toward_goal(goal)
				wolf.position=wolf._move_scaled(dir.x*.045,dir.z*.045)
				if wolf.position.distance_to(goal)<.65: break
				# Incremental pathfinding advances on physics frames under a shared budget.
				await physics_frame
			var passed: bool=wolf.position.distance_to(goal)<.65
			print("PASS " if passed else "FAIL ",house.name," size=",size," exit distance=",wolf.position.distance_to(goal)," travelled=",wolf.position.distance_to(start))
			if not passed: failed+=1
	game.queue_free(); await process_frame; await process_frame
	print("BUILDING_EXITS failures=",failed); quit(1 if failed else 0)
