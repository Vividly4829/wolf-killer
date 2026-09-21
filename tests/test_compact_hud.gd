extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/hud-"+label+".png")
func run() -> void:
	var game=load("res://scripts/main.gd").new()
	game.progress.transient=true
	game.progress.save_path="user://hud_test_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.start_free_play()
	game.set_process(false); game.player.set_physics_process(false)
	game.world.weather.hour=13; game.world.weather.apply()
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	var review=game.shot_review
	review.set_process(false)
	game.hud._process(0)
	check(game.hud.health_label.scale.x<1 and game.hud.health_label.position.y>606,"compact health stays near the bottom edge")
	check(is_equal_approx(game.player.SPRINT_SPEED,6.075) and is_equal_approx(game.player.MAX_STAMINA,337.5),"sprint speed and available stamina reduced by 25 percent")
	# A physical keyboard X opens details even before the first shot.
	var key:=InputEventKey.new(); key.physical_keycode=KEY_X; key.pressed=true
	review._unhandled_key_input(key); game.hud._process(0)
	check(game.hud.health_label.scale==Vector2.ONE and game.hud_detail_left>0,"X restores the original HUD size without requiring shot history")
	game.hud_detail_left=0
	game.coop.award(25)
	game.hud._process(0)
	check(game.hud.round_money_label.text.contains("P1 +25"),"round earnings appear in the main HUD")
	review.begin_shot()
	var flight=load("res://scripts/shot_path.gd").new()
	flight.begin(Vector3(0,3,0),Vector3(1,.05,0).normalized(),game.WeaponCatalog.weapon(0))
	flight.append(Vector3(15,3.1,0),.2)
	flight.append(Vector3(40,2,0),.5)
	review.record_path(flight.report("MISS / TERRAIN"),review.serial)
	review._process(0); game.hud._process(0)
	check(review.modulate.a<.5 and review.scale.x<1,"automatic miss review is smaller and much more transparent")
	await capture("compact-miss")
	review._unhandled_key_input(key); review._process(0); game.hud._process(0)
	check(review.modulate.a==1 and review.scale==Vector2.ONE,"X makes the miss fully readable at the original size")
	await capture("expanded-miss")
	game.hud_detail_left=.01; game._process(.02); game.hud._process(0)
	check(game.hud_detail_left==0 and game.hud.health_label.scale.x<1,"detail view returns to compact after timeout")
	game.restore_campaign()
	game.queue_free(); await process_frame; await process_frame
	print("COMPACT_HUD failures=",failures)
	quit(1 if failures else 0)
