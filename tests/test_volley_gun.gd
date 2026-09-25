extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func run() -> void:
	var game=preload("res://scripts/main.gd").new()
	game.progress.transient=true; root.add_child(game)
	game.start_free_play(); game.set_process(false); game.player.set_physics_process(false)
	AudioServer.set_bus_mute(0,true)
	game.select_weapon(36); game.player.position=Vector3(150,80,140)
	game.fire_cooldown=0; game.reload_left=0
	var spec: Dictionary=game.weapon_spec()
	check(spec.id=="nock_volley" and spec.magazine==1 and spec.pellets==7,"volley is selectable with one seven-ball charge")
	check(is_equal_approx(spec.reload,8.0) and spec.barrel=="Smoothbore" and is_equal_approx(spec.penetration,.70),"smoothbore ballistics and eight-second reload")
	game.fire_weapon()
	check(game.current_ammo()==0,"single trigger consumes the entire charge")
	check(game.shot_review.trajectories.size()==7,"live firing records seven separate ballistic trajectories")
	check(game.player.weapon._flash_mesh.get_child_count()==6,"all seven barrel mouths have synchronized flashes")
	game.reload_weapon()
	check(game.reload_left>0,"empty volley begins reloading")
	game.queue_free(); await process_frame; await process_frame
	print("VOLLEY_GUN failures=",failures); quit(1 if failures else 0)
