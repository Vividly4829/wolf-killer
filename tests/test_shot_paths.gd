extends SceneTree
var failures := 0
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func fire(index: int) -> void:
	game.current_weapon=index
	game.player.set_weapon(index)
	game.ammo[index]=int(game.WEAPONS[index].magazine)
	game.fire_cooldown=0; game.reload_left=0
	game.fire_weapon()
func finish_bolt() -> void:
	var bolts: Array=game.nodes_in_group("player_bolts")
	check(bolts.size()==1,"one real projectile launched")
	if bolts.is_empty(): return
	var bolt=bolts[0]
	bolt.set_physics_process(false)
	for frame in 500:
		if bolt.is_queued_for_deletion(): break
		bolt._physics_process(.02)
	check(bolt.is_queued_for_deletion(),"projectile finishes its flight")
	await process_frame
func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	game.shot_review.remaining=10
	game.shot_review._process(0)
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/shot-path-"+label+".png")
func run() -> void:
	game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://shot_paths_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.start_free_play()
	game.set_process(false); game.player.set_physics_process(false)
	game.campaign.set_process(false); game.campaign.wind=Vector3.ZERO
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	game.world.weather.hour=12; game.world.weather.apply()
	var crossing: Dictionary=game.world.exploration_data.bridges.filter(func(b): return b.name=="South island footbridge")[0]
	var a:=Vector3(crossing.a[0],crossing.a[1],crossing.a[2])
	var b:=Vector3(crossing.b[0],crossing.b[1],crossing.b[2])
	game.player.reset_at(a.lerp(b,.3))
	game.player.yaw=atan2(a.x-b.x,a.z-b.z)
	var move_key:=InputEventKey.new(); move_key.physical_keycode=KEY_W; move_key.pressed=true
	Input.parse_input_event(move_key); Input.flush_buffered_events()
	for tick in 60: game.player._physics_process(1.0/60)
	check(absf(game.player._actual_speed-2.85)<.15,"actual walking movement reaches the increased speed on a bridge")
	check(absf(game.player.camera.position.y-1.78)<.02,"standing camera uses the taller eye height while moving")
	var sprint_key:=InputEventKey.new(); sprint_key.physical_keycode=KEY_SHIFT; sprint_key.pressed=true
	Input.parse_input_event(sprint_key); Input.flush_buffered_events()
	for tick in 60: game.player._physics_process(1.0/60)
	check(absf(game.player._actual_speed-5.4)<.2 and game.player.is_sprinting,"actual sprint movement reaches the increased speed")
	move_key.pressed=false; sprint_key.pressed=false
	Input.parse_input_event(move_key.duplicate()); Input.parse_input_event(sprint_key.duplicate()); Input.flush_buffered_events()
	game.player.reset_at(Vector3(0,80,0))
	game.player.yaw=0; game.player.pitch=0; game.player._update_rotation()
	await physics_frame
	fire(0)
	var review=game.shot_review
	check(review.reports.is_empty() and review.trajectories.size()==1,"firearm miss still records a trajectory")
	var path: Dictionary=review.trajectories.back()
	check(absf(path.travelled-100)<.01 and path.drop>1.4 and path.drop<1.7 and path.curved,"firearm reports exact range limit and its actual gravity arc")
	check(path.complete and "RANGE LIMIT" in review.caption,"miss says why the shot ended")
	var plot: PackedVector2Array=review.plot_samples(path)
	var middle:=plot[plot.size()/2]
	var linear_y: float=plot[-1].y*middle.x/plot[-1].x
	check(middle.y>linear_y+.15,"firearm review is curved instead of a diagonal line")
	await capture("miss")
	game.player.pitch=-.7; game.player._update_rotation()
	fire(0)
	var down_plot: PackedVector2Array=review.plot_samples(review.trajectories.back())
	check(down_plot[-1].y> -3 and down_plot[-1].y< -.5,"downward aiming graph isolates gravity from camera angle")
	await capture("downward-arc")
	game.player.pitch=0; game.player._update_rotation()
	var old_serial: int=review.serial
	var old_path:=path.duplicate(true)
	fire(1)
	check(review.trajectories.size()==8,"shotgun retains every pellet path, including misses")
	review.record_path(old_path,old_serial)
	check(review.trajectories.size()==8,"late results cannot overwrite a newer shot")
	fire(3)
	await finish_bolt()
	path=review.trajectories.back()
	check(path.curved and path.points.size()>3 and path.points.size()<=64,"crossbow retains bounded real flight samples")
	check(absf(path.travelled-85)<.01 and path.drop>10,"crossbow miss reports arc drop and exact range cap")
	check(review.reports.is_empty() and path.complete,"curved miss remains reviewable after projectile cleanup")
	await capture("arc-miss")
	# A thin target below a level aim line proves gravity changes collision,
	# rather than only drawing a decorative curve over a straight hit ray.
	var gravity_target:=StaticBody3D.new()
	var gravity_shape:=CollisionShape3D.new()
	var gravity_box:=BoxShape3D.new(); gravity_box.size=Vector3(.5,.12,.12)
	gravity_shape.shape=gravity_box; gravity_target.add_child(gravity_shape); game.add_child(gravity_target)
	var origin: Vector3=game.player.camera.global_position
	gravity_target.position=origin+Vector3(0,-4.9*pow(50.0/180.0,2),-50)
	await physics_frame; await physics_frame
	var result: Dictionary=preload("res://scripts/ballistic_trace.gd").cast(game.get_world_3d().direct_space_state,origin,Vector3.FORWARD,game.WeaponCatalog.weapon(0),[])
	check(not result.hit.is_empty() and result.hit.collider==gravity_target,"bullet drop hits a target below the original aim line")
	var laser: Dictionary=game.WeaponCatalog.weapon(26)
	var beam: Dictionary=preload("res://scripts/ballistic_trace.gd").cast(game.get_world_3d().direct_space_state,origin,Vector3.FORWARD,laser,[])
	check(beam.hit.is_empty() and not beam.path.curved and absf(beam.path.drop)<.001,"laser stays straight and misses the target below aim")
	check(result.path.points[-1].is_equal_approx(result.hit.position),"bullet review terminates exactly at physics impact")
	gravity_target.queue_free(); await physics_frame
	# A wall at ten metres must end the recorded shot there, rather than at
	# the weapon's maximum range or the end of a physics integration step.
	var wall:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new(); box.size=Vector3(30,30,.2)
	shape.shape=box; wall.add_child(shape); game.add_child(wall)
	wall.position=Vector3(0,80,-10)
	await physics_frame; await physics_frame
	game.player.pitch=0; game.player._update_rotation()
	fire(0)
	path=review.trajectories.back()
	check(path.travelled>9.8 and path.travelled<10.1 and review.reports.is_empty(),"terrain/object miss measures to the actual impact")
	check("IMPACT" in review.caption,"blocked shot is distinguished from a range-limit miss")
	fire(18)
	await finish_bolt()
	path=review.trajectories.back()
	check(path.travelled>9 and path.travelled<12 and path.drop>.3,"thrown weapon reports real arc to wall, not maximum range")
	check(absf(path.points[-1].z+9.9)<.01,"projectile's last path point is its collision point")
	# Preserve bone X-ray and damage alongside the flight diagram.
	var hit:=preload("res://scripts/human_xray.gd").trace(Vector3(-.06,1.2,.3),Vector3.FORWARD,20)
	hit.weapon=path.weapon; hit.distance=path.distance; hit.base_damage=20; hit.range_factor=1
	review.record(hit)
	check(review.trajectories.size()==1 and review.reports.size()==1,"anatomy and trajectory coexist in one review")
	await capture("hit")
	var current: int=review.serial
	var older: int=review.history[1].serial
	var key:=InputEventKey.new(); key.physical_keycode=KEY_X; key.pressed=true
	Input.parse_input_event(key); Input.flush_buffered_events()
	check(review.displayed().serial==older,"X selects the previous shot rather than reopening the same one")
	Input.parse_input_event(key.duplicate()); Input.flush_buffered_events()
	check(review.selected==2,"pressing X again continues backward through history")
	await capture("history")
	for i in review.history.size()-2: review.cycle_review()
	check(review.displayed().serial==current,"history wraps back to the latest shot")
	var saved_damage: float=review.reports[0].damage
	hit.damage=9999
	check(review.reports[0].damage==saved_damage,"history owns a copy of its damage report")
	# Three rapid throws can overlap; an older impact must update its own entry.
	fire(18)
	var earlier: int=review.serial
	var live_bolt: Node=game.nodes_in_group("player_bolts")[0]
	live_bolt.set_physics_process(false)
	game.fire_cooldown=0
	game.fire_weapon()
	var newer: int=review.serial
	for frame in 150:
		if live_bolt.is_queued_for_deletion(): break
		live_bolt._physics_process(.02)
	check(review.entry_for(earlier).trajectories[0].complete and review.serial==newer,"late projectile completes its own historical shot")
	review.record(hit,earlier)
	check(review.entry_for(earlier).reports.size()==1 and review.reports.is_empty(),"late damage goes to its shot instead of contaminating a newer review")
	for bolt in game.nodes_in_group("player_bolts"): bolt.queue_free()
	await process_frame
	check(game.WEAPONS[18].magazine==3 and game.WEAPONS[18].reserve==0 and game.WEAPONS[20].magazine==1 and game.WEAPONS[20].reserve==0,"inventory is capped at three knives and one spear")
	check(game.WEAPONS[18].interval<=.25 and game.WEAPONS[20].interval<=.3 and game.WEAPONS[18].projectile_speed>=30 and game.WEAPONS[20].projectile_speed>=30,"throws release and travel quickly")
	check(game.WEAPONS[20].damage>=150,"single spear has high stopping damage")
	game.ammo[18]=0; game.ammo[20]=0
	game.progress.money=10000; game.set_mode("shop"); game.purchase_ammo()
	check(game.ammo[18]==3 and game.ammo[20]==1 and game.reserve_ammo[18]==0 and game.reserve_ammo[20]==0,"store restocks thrown weapons without exceeding their carry limit")
	game.set_mode("playing")
	game.current_weapon=20; game.ammo[20]=0; game.reload_left=0
	game.free_play=false; game.reload_weapon()
	check(game.ammo[20]==0 and game.reload_left==0,"campaign cannot conjure a spare spear by reloading")
	game.free_play=true; game.reload_weapon()
	check(game.ammo[20]==1 and game.reserve_ammo[20]==0,"free play R restocks one practice spear for continued testing")
	for i in 40: review.begin_shot()
	check(review.history.size()==32,"history retains a bounded 32 shots")
	review.remaining=0; review.selected=20; review.cycle_review()
	check(review.selected==0 and review.remaining>0,"X reopens the latest shot after the panel expires")
	review.reset_history()
	check(review.history.is_empty() and review.trajectories.is_empty() and review.reports.is_empty(),"new run clears the prior shot history")
	wall.queue_free()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
