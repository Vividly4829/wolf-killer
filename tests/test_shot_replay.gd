extends SceneTree
var failures:=0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await create_timer(.15).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/replay-"+label+".png")
func run() -> void:
	game=preload("res://scripts/main.gd").new(); game.progress.save_path="user://replay_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720); AudioServer.set_bus_mute(0,true)
	for actor in game.wolves+game.nodes_in_group("wildlife"): actor.set_physics_process(false)
	var review=game.shot_review; review.set_process(false)
	var replay=review.replay
	var target=game.wolves[0]; target.position=Vector3(0,80,0); target.rotation.y=0
	game.player.position=Vector3(-12,80,0); await physics_frame; await physics_frame
	var weapon: Dictionary=game.WeaponCatalog.weapon(0)
	var excluded: Array[RID]=[]
	review.begin_shot(); game.fire_ballistic(Vector3(-12,80.57,.15),Vector3.RIGHT,weapon,review.serial,1,excluded); review._process(0)
	check(not review.reports.is_empty() and review.reports[0].has("target_transform"),"real firearm hit stores target pose for isolated replay")
	check(replay.ready_to_play and replay.markers.size()==1,"recorded shot builds its 3D replay")
	var path: Dictionary=review.trajectories[0]
	check(path.times.size()==path.points.size() and path.duration>0,"combat records sample timing with trajectory")
	check(is_equal_approx(review.remaining,4),"review stays visible for four seconds")
	review._process(1.75)
	var expected: Vector3=replay.sample(path,.5,path.duration)-path.points[0]
	check(replay.markers[0].position.distance_to(expected)<.001,"slow-motion projectile follows recorded flight time")
	await capture("midflight")
	game.set_mode("paused"); var elapsed: float=replay.elapsed; review._process(3)
	check(replay.elapsed==elapsed and replay.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"pause freezes replay and stops its rendering")
	game.set_mode("playing"); review._process(1.75)
	check(replay.markers[0].position.distance_to(path.points[-1]-path.points[0])<.001,"replay arrives at the actual hit point")
	await capture("impact")
	check(Engine.time_scale==1,"slow motion never changes live game speed")
	review._process(.51); check(not review.visible,"panel closes after four seconds")
	review.begin_shot(); game.fire_ballistic(Vector3(0,80,0),Vector3.UP,weapon,review.serial,1,excluded); review._process(0)
	check(review.reports.is_empty() and replay.ready_to_play,"vertical miss receives a valid replay")
	review._process(3.8); await capture("miss")
	review.cycle_review(); review._process(0)
	check(review.selected==1 and replay.elapsed==0 and replay.ready_to_play,"history replays a previous shot from its beginning")
	review.begin_shot()
	for pellet in 8:
		var direction:=Vector3(1,(pellet-4)*.003,0).normalized()
		game.fire_ballistic(Vector3(-12,80.6,1),direction,weapon,review.serial,1,excluded)
	review._process(2)
	check(replay.markers.size()==8,"all shotgun-style pellet traces replay together")
	var flight=preload("res://scripts/shot_path.gd").new(); flight.begin(Vector3.ZERO,Vector3.FORWARD,game.WeaponCatalog.weapon(22))
	for i in range(1,170): flight.append(Vector3(0,-i*.003,-i*.1),.01)
	check(flight.times.size()==flight.points.size() and flight.points.size()<=64 and absf(flight.times[-1]-1.69)<.001,"sample compaction preserves matching flight timestamps")
	review.begin_shot(true); review.record_path(flight.report("PROJECTILE IN FLIGHT",false),review.serial); review._process(2)
	check(not replay.ready_to_play and replay.elapsed==0,"live arrow waits for its complete path before replay")
	review.record_path(flight.report("MISS / RANGE LIMIT"),review.serial); review._process(0)
	check(replay.ready_to_play and replay.elapsed==0 and review.remaining==4,"arrow completion starts a full four-second replay")
	var serialized: Dictionary=bytes_to_var(var_to_bytes(review.displayed()))
	check(serialized.trajectories[0].times==flight.times,"replay data survives multiplayer serialization")
	review.scale=Vector2.ONE*.65; review.position=Vector2(1005,125)
	check(review.position.x+replay.position.x*.65>=0 and review.position.x+review.size.x*.65<=1280 and review.position.y+review.size.y*.65<=360,"paired panels fit each split-screen HUD")
	review.reset_history(); review._process(0)
	check(not review.visible and replay.markers.is_empty(),"new run clears replay resources and history")
	game.restore_campaign()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; await process_frame
	print("SHOT_REPLAY failures=",failures); quit(1 if failures else 0)
