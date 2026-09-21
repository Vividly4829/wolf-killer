extends SceneTree
var failures := 0
class FlatNav extends RefCounted:
	func move_position(p: Vector3,x: float,z: float) -> Vector3: return Vector3(p.x+x,0,p.z+z)
func key(code: int,pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures += 1
func run() -> void:
	var game := preload("res://scripts/main.gd").new()
	game.progress.save_path = "user://expansion_%d.cfg"%OS.get_process_id()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.start_run()
	var navigation = game.player.nav
	game.player.nav = FlatNav.new()
	game.player.reset_at(Vector3.ZERO)
	key(KEY_W,true)
	for frame in 120: game.player._physics_process(1.0/60)
	check(game.player._actual_speed>2.3 and game.player._actual_speed<2.5,"Walking settles at 2.45 metres per second")
	key(KEY_SHIFT,true)
	var aim := InputEventMouseButton.new()
	aim.button_index = MOUSE_BUTTON_RIGHT
	aim.pressed = true
	Input.parse_input_event(aim)
	Input.flush_buffered_events()
	for frame in 60: game.player._physics_process(1.0/60)
	check(game.player.is_sprinting and game.player._aim==0 and game.player.camera.fov>77 and game.player.get_aim_spread_multiplier()>=4,"Sprint blocks sights and increases dispersion even while aiming")
	key(KEY_W,false)
	key(KEY_SHIFT,false)
	aim = aim.duplicate()
	aim.pressed = false
	Input.parse_input_event(aim)
	Input.flush_buffered_events()
	game.player.nav = navigation
	game.player.reset_at(game.world.spawn_position)
	check(game.dialogue_left>0 and not game.sounds.dialogue.playing,"Opening is text only")
	check(game.world.nav.brush.size()>100,"Batched undergrowth is present")
	var brush: Vector3 = game.world.nav.brush.values()[0]
	check(game.world.nav.vegetation_factor(brush)==.55 and game.world.wolf_nav.vegetation_factor(brush)==.55,"Brush slows both species")
	game.world.nav.field(game.world.spawn_position.x,game.world.spawn_position.z)
	game.world.wolf_nav.field(game.world.exterior_rally_point.x,game.world.exterior_rally_point.z)
	await physics_frame
	await physics_frame
	for house: Dictionary in game.world.exploration_data.houses:
		var at := Vector3(house.center[0],house.floor,house.center[1])
		var i: int = game.world.nav.nearest(at.x,at.z,2)
		var j: int = game.world.wolf_nav.nearest(at.x,at.z,2)
		check(i>=0 and game.world.nav.distances[i]>=0,"Player route: "+house.name)
		check(j>=0 and game.world.wolf_nav.distances[j]>=0,"Wolf route: "+house.name)
		var door := Vector3(house.door[0],house.floor+1,house.door[2])
		var n := Vector3(house.normal[0],0,house.normal[1])
		var query := PhysicsRayQueryParameters3D.create(door+n*.9,door-n*.9,1)
		check(game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Doorway collision open: "+house.name)
		for nav in [game.world.nav,game.world.wolf_nav]:
			nav.field(at.x,at.z)
			var pos := Vector3(house.end[0],house.end[1],house.end[2])
			for step in 900:
				if Vector2(pos.x-at.x,pos.z-at.z).length()<1: break
				var next: Vector3 = nav.next_point(pos.x,pos.z)
				if not next.is_finite(): break
				var offset := next-pos
				offset.y = 0
				offset = offset.normalized()*minf(.1,offset.length())
				pos = nav.move_position(pos,offset.x,offset.z)
			check(Vector2(pos.x-at.x,pos.z-at.z).length()<1,"Walk through entrance: "+house.name)
		check(not game.world.is_safe_position(at),"House is not a wolf sanctuary: "+house.name)
	var before: int = game.progress.money
	game.world.houses.take(0,game)
	check(game.world.houses.drops[0]==-1 and game.progress.owned.size()==2 and game.progress.money==before,"Free loot grants one owned weapon without spending")
	game.world.houses.take(0,game)
	check(game.progress.owned.size()==2,"Claimed loot cannot be collected twice")
	game.level = 5
	game.player.position = game.world.exterior_rally_point
	game.receive_wolf_bite(1,game.player.position+Vector3.RIGHT,true)
	check(game.affliction.infected_wave==5,"Werewolf bite infects")
	var previous := 0.0
	for wave in range(5,10):
		game.level = wave
		check(game.affliction.blur_amount()>previous and game.maximum_health()==100,"Progressive incubation wave %d"%wave)
		previous = game.affliction.blur_amount()
	game.level = 10
	game.begin_rest()
	game.affliction._process(.1)
	check(game.health==200 and game.player.supernatural_speed==1.5 and game.affliction.blur_amount()==0,"Mature full moon gives 200 HP and 50 percent speed")
	game.level = 11
	game.begin_rest()
	game.affliction._process(.1)
	check(game.health==100 and game.player.supernatural_speed==1 and game.affliction.blur_amount()==0,"Normal wave restores ordinary sight and stats")
	game.start_run()
	check(game.affliction.infected_wave==-1,"Death/retry clears infection")
	if OS.get_cmdline_user_args().has("--capture"):
		root.size = Vector2i(1280,720)
		var house: Dictionary = game.world.exploration_data.houses[0]
		game.world.weather.hour = 12
		game.world.weather.apply()
		game.player.camera.global_position = Vector3(house.end[0],house.end[1]+1.65,house.end[2])
		game.player.camera.look_at(Vector3(house.door[0],house.floor+1.2,house.door[2]))
		await create_timer(1).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/survival-expansion"))
		root.get_texture().get_image().save_png("res://qa/survival-expansion/house.png")
		game.affliction.infected_wave = 5
		for wave in [9,10]:
			game.level = wave
			game.health = game.maximum_health()
			game.affliction._process(.1)
			await create_timer(.3).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/survival-expansion/curse_%d.png"%wave)
		check(game.sounds.score.size()==2 and game.sounds.score[0].playing and game.sounds.score[1].playing,"Both original ambient music layers play")
		game.level = 1
		game._add_wolf_at(game.world.exterior_rally_point+Vector3(10,0,0))
		game.wolves.back().set_physics_process(false)
		game.wolves.back().alerted = true
		for step in 80: game.sounds._process(.1)
		check(game.sounds.tension>.9,"Pack alert smoothly raises the tension layer")
		game.wolves.back().alerted = false
		for step in 90: game.sounds._process(.1)
		check(game.sounds.tension<.05,"Music settles again when the pack calms")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
