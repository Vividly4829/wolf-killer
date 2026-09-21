extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=preload("res://scripts/main.gd").new(); game.progress.save_path="user://beast_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_run(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	game.campaign.clear_round(); await process_frame
	var nav=game.world.wolf_nav; var origin:=Vector3.INF
	for cell in nav.reachable:
		var p: Vector3=nav.point(cell)
		if p.distance_to(game.world.exterior_rally_point)<35: continue
		if nav.line_clear(p.x,p.z,p.x+12,p.z) and nav.line_clear(p.x,p.z-1,p.x+12,p.z-1) and nav.line_clear(p.x,p.z+1,p.x+12,p.z+1): origin=p; break
	if not origin.is_finite(): print("FAIL no suitable pursuit lane"); quit(1); return
	game.player.position=nav.point(nav.nearest(origin.x+11,origin.z,2)); game.player._movement_noise=.7
	var beast=game.campaign.spawn_wolf(origin,true,false,501); beast.set_physics_process(false); beast.hear_gunshot(game.player.position)
	await physics_frame; await physics_frame
	var maximum:=0.0; var charged:=false; var bite_time:=0.0
	for frame in 600:
		var previous: Vector3=beast.position
		beast._physics_process(1.0/60)
		maximum=maxf(maximum,Vector2(beast.position.x-previous.x,beast.position.z-previous.z).length()*60)
		charged=charged or beast.behavior=="charge"
		if game.is_struggling() or game.health<100: bite_time=(frame+1)/60.0; break
	print("WEREWOLF charge=",charged," max actual speed=",maximum," bite/struggle after seconds=",bite_time)
	var passed: bool=charged and maximum>5.4 and bite_time>0 and bite_time<8
	print("PASS" if passed else "FAIL"," werewolf warns, outruns a sprinting hunter and closes into a maul")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; quit(0 if passed else 1)
