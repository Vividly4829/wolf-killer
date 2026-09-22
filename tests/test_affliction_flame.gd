extends SceneTree
var game: Node3D
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/affliction-"+label+".png")
func run() -> void:
	game=preload("res://scripts/main.gd").new(); game.progress.transient=true
	game.progress.save_path="user://affliction_test_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	AudioServer.set_bus_mute(0,true); root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	game.level=5; game.affliction.infect(); game.affliction._process(0)
	check(game.player.supernatural_speed==1.5 and game.affliction.blur_amount()==0 and game.maximum_health()==100,"infection immediately gives speed and no blur")
	game.level=10; check(game.maximum_health()==100,"next werewolf round must be survived before health unlock")
	game.level=11; check(game.maximum_health()==200,"health permanently doubles after next werewolf round")
	game.level=12; check(game.maximum_health()==200 and game.affliction.transformed(),"health and transformation persist on ordinary rounds")
	game.health=200; game.affliction.consume(); game.affliction.consume()
	check(is_equal_approx(game.maximum_health(),140) and is_equal_approx(game.health,140),"psychedelic stacks with lycanthropy, but repeated mushrooms do not compound penalty")
	game.affliction._process(0)
	check(game.affliction.overlay.material.get_shader_parameter("vivid")==1.0 and game.affliction.overlay.material.get_shader_parameter("red")>0,"vivid and red effects combine")
	game.begin_rest(); game.finish_rest(); game.set_process(false)
	check(not game.affliction.psychedelic and game.health==200 and game.affliction.transformed(),"rest removes psychedelic and restores full transformed health")
	check(game.mushrooms.spots.size()>0 and game.mushrooms.spots.size()<=10,"occasional mushroom clusters spawn on navigable terrain")
	game.player.position=game.mushrooms.spots[0]; game.coop.eat_mushroom(0)
	check(game.affliction.psychedelic and not game.mushrooms.models[0].visible,"nearby mushroom interaction consumes cluster and applies effect")
	check(not game.mushrooms.can_consume(0,1,game.player.position),"same player cannot consume the same cluster twice")
	check(not game.mushrooms.can_consume(1,1,Vector3(999,999,999)),"distant mushroom requests rejected")
	var deer=preload("res://scripts/wildlife.gd").new(); deer.game=game; game.add_child(deer); deer.set_physics_process(false); deer.position=Vector3(140,80,140)
	game.player.position=Vector3(-100,1,-100)
	check(not game.radar_animals().has(deer),"psychedelic radar keeps distant passive animals off map")
	game.affliction.psychedelic=false
	check(not game.radar_animals().has(deer),"normal radar retains 75 metre limit")
	var avatar=preload("res://scripts/coop_avatar.gd").new(); game.add_child(avatar); avatar.set_beast(true)
	check(avatar.character.beast,"co-op player can use werewolf-like character mesh")
	game.player.position=Vector3(140,80,146); game.player.yaw=0; game.player.pitch=0; game.player._update_rotation()
	game.current_slot=game.progress.owned.find(35); game.current_weapon=35; game.player.set_weapon(35)
	var spec: Dictionary=game.WeaponCatalog.weapon(35)
	check(spec.flame and spec.automatic and spec.range==10 and spec.price==850 and spec.reload==5,"flamethrower has bounded range, continuous fuel and balanced price")
	await physics_frame; await physics_frame
	var excluded: Array[RID] = []
	var origin:=Vector3(140,80.6,146); var direction:=Vector3.FORWARD
	game.shot_review.begin_shot(false)
	game.fire_ballistic(origin,direction,spec,game.shot_review.serial,1,excluded)
	check(deer.health<70,"flame trace damages exposed animal")
	var wall:=StaticBody3D.new(); wall.collision_layer=1; game.add_child(wall); wall.position=Vector3(140,81,143)
	var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(4,4,.3); shape.shape=box; wall.add_child(shape)
	await physics_frame; await physics_frame
	var before: float=deer.health
	game.fire_ballistic(origin,direction,spec,game.shot_review.serial,1,excluded)
	check(deer.health==before,"solid wall blocks flame damage")
	wall.queue_free()
	game.set_mode("playing"); game.fire_cooldown=0; game.reload_left=0; game.player.is_sprinting=false
	game.ammo[35]=25; game.player._fire_trigger_down=true
	game.player._physics_process(0)
	check(game.ammo[35]==24,"held keyboard trigger consumes a fuel pulse")
	game.fire_cooldown=0; game.player._physics_process(0)
	check(game.ammo[35]==23,"held keyboard trigger continues the flame stream")
	game.player._fire_trigger_down=false
	game.player._physics_process(0)
	check(game.ammo[35]==23,"releasing trigger stops fuel use")
	game.affliction.psychedelic=true; game.affliction._process(0); game.hud._process(0)
	await capture("effects")
	game.coop.flame_effect(game.player.weapon.to_global(game.player.weapon.muzzle_position),origin+Vector3.FORWARD*8)
	await create_timer(.12).timeout
	await capture("flame")
	game.set_mode("menu"); game.hud.open_weapon_stats(); game.hud.stats_page=4; game.hud.refresh_panel()
	await capture("guide")
	game.affliction.infected_wave=-1; game.affliction.psychedelic=false; game.affliction._process(0)
	game.mushrooms.regrow(12); game.set_mode("playing")
	game.player.weapon.hide(); game.shot_review.close_review() if game.shot_review.has_method("close_review") else game.shot_review.hide()
	var spot: Vector3=game.mushrooms.spots[0]
	game.player.camera.global_position=spot+Vector3(.7,.8,.8); game.player.camera.look_at(spot+Vector3(0,.3,0))
	await capture("mushrooms")
	game.restore_campaign(); game.queue_free(); await process_frame
	print("AFFLICTION_FLAME failures=",failures); quit(1 if failures else 0)
