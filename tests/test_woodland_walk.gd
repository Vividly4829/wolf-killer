extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func hold(down: bool) -> void:
	var event:=InputEventKey.new(); event.keycode=KEY_W; event.physical_keycode=KEY_W; event.pressed=down
	Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	var game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://woods_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_run(); game.set_process(false); game.campaign.set_process(false); game.player.set_physics_process(false)
	var player=game.player; var nav=game.world.nav
	var routes:=0; var timings:=PackedInt64Array(); var maximum_step:=0.0; var maximum_eye_step:=0.0; var min_factor:=1.0
	for center: Vector3 in nav.brush.values():
		if routes>=24: break
		for direction in [Vector3.RIGHT,Vector3.FORWARD]:
			var a: Vector3=center-direction*3; var b: Vector3=center+direction*3
			if not nav.line_clear(a.x,a.z,b.x,b.z): continue
			a.y=nav.height_at(a.x,a.z); b.y=nav.height_at(b.x,b.z)
			for reverse in [false,true]:
				var start: Vector3=b if reverse else a; var end: Vector3=a if reverse else b
				var heading: Vector3=(end-start).normalized()
				player.reset_at(start); player.yaw=atan2(-heading.x,-heading.z); player._update_rotation(); hold(true)
				var reached:=false; var stalled:=0
				for frame in 360:
					var before: Vector3=player.position; var eye: float=player.camera.global_position.y
					var clock:=Time.get_ticks_usec(); player._physics_process(1.0/60); timings.append(Time.get_ticks_usec()-clock)
					var distance:=Vector2(player.position.x-before.x,player.position.z-before.z).length()
					maximum_step=maxf(maximum_step,distance); maximum_eye_step=maxf(maximum_eye_step,absf(player.camera.global_position.y-eye))
					min_factor=minf(min_factor,nav.vegetation_factor(player.position))
					if frame>15 and distance<.001: stalled+=1
					if Vector2(player.position.x-end.x,player.position.z-end.z).length()<.08: reached=true; break
				hold(false); check(reached and stalled==0,"continuous player walk through brush route %d %s"%[routes,"reverse" if reverse else "forward"])
			routes+=1
			break
	check(routes==24,"24 actual woodland corridors exercised both directions")
	check(min_factor<.8 and maximum_step<.055,"bushes slow walking without position jumps")
	check(maximum_eye_step<.20,"terrain camera smoothing stays below 20 cm per frame")
	timings.sort()
	print("WOODLAND simulated frames=",timings.size()," max step=",maximum_step," max eye step=",maximum_eye_step," min brush factor=",min_factor," physics us median=",timings[timings.size()/2]," p95=",timings[int(timings.size()*.95)])
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; print("WOODLAND failures=",failures); quit(1 if failures else 0)
