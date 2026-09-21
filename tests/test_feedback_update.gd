extends SceneTree
var game: Node3D
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	game = preload("res://scripts/main.gd").new()
	game.progress.save_path = "user://feedback_test_%s.cfg" % OS.get_process_id()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.start_run()
	var seasons: Dictionary = {}
	var hours: Dictionary = {}
	for i in 40:
		game.world.weather.wake(1)
		seasons[game.world.weather.season] = true
		hours[game.world.weather.hour] = true
	check(seasons.size()==4 and hours.size()>10,"Wakes vary across all seasons and daytime hours")
	game.world.weather.wake(5)
	check(game.world.weather.blood_moon and game.world.weather.hour==0,"Every fifth wave overrides the time with a blood moon night")
	game.world.weather.wake(6)
	check(not game.world.weather.blood_moon,"Ordinary waves clear the blood moon")
	game.fire_cooldown = 0
	var ammunition: int = game.current_ammo()
	game.fire_weapon()
	check(game.current_ammo()==ammunition,"Weapons cannot fire inside the cabin")
	var comfort = game.world.get_node("CabinComfort")
	game.player.position = Vector3(-3.5,3.85,-.55)
	game.player._actual_speed = 1
	comfort._process(1)
	check(comfort.doors[1].rotation.y<0,"Approaching the backdoor opens it")
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-3.5,5.2,.2),Vector3(-3.5,5.2,-2),1)
	var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(hit.is_empty(),"Backdoor is a real opening in the wall collision")
	if not hit.is_empty(): print("Door obstruction ",hit.collider.get_parent().name)
	var pos := Vector3(-3.5,3.85,.25)
	for i in 40: pos = game.world.nav.move_position(pos,0,-.1)
	check(pos.z< -2.8,"Player can walk fully through the backdoor to the outside")
	print("Backdoor walk ends ",pos)
	game.player.position = game.world.spawn_position
	game.player._actual_speed = 0
	comfort._process(2)
	check(is_equal_approx(comfort.doors[1].rotation.y,.2),"Door closes automatically behind the player")
	var catalog = preload("res://scripts/weapon_catalog.gd")
	check(catalog.WEAPONS.size()==24,"24 weapons including six field weapons")
	for i in range(18,24):
		var weapon: Dictionary = catalog.weapon(i)
		check(weapon.price<=110 and weapon.projectile_speed>0 and weapon.damage<=38 and weapon.vital_bonus>2,"Cheap arcing precision weapon: "+weapon.name)
		var model: Dictionary = preload("res://scripts/weapon_model_builder.gd").new().build(i)
		check(model.triangles>20,"Dedicated model: "+weapon.name)
		model.root.free()
	game.player.position = game.world.exterior_rally_point
	game.level = 5
	game.begin_wave()
	var bosses := 0
	for wolf in game.wolves:
		wolf.set_physics_process(false)
		if wolf.werewolf:
			bosses += 1
			check(wolf.size_scale>1.5 and wolf.max_health>300,"Werewolf is larger and tougher than an ordinary wolf")
	check(bosses==1,"Exactly one werewolf spawns on the fifth wave")
	var wildlife := get_nodes_in_group("wildlife")
	check(wildlife.size()==6,"Each wave includes deer, ducks, goose and mink")
	var before: int = game.wave_kills
	var cash: int = game.progress.money
	wildlife[0].damage(1000)
	check(game.wave_kills==before and game.progress.money>cash,"Wildlife earns money without advancing the mission")
	var first = game.wolves.back()
	var animal = wildlife.back()
	first.prey = animal
	first.position = animal.position+Vector3(0,0,.5)
	first._attack_cooldown = 0
	var hp: float = animal.health
	first._hunt_wildlife(.1)
	check(animal.health<hp,"An unalerted wolf can hunt optional wildlife")
	if OS.get_cmdline_user_args().has("--capture"):
		root.size = Vector2i(1280,720)
		root.content_scale_size = Vector2i(1280,720)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/feedback-update"))
		game.world.weather.season = 1
		game.world.weather.hour = 12
		game.world.weather.blood_moon = false
		game.world.weather.apply()
		game.player.camera.global_position = Vector3(-1.5,5.25,2.5)
		game.player.camera.look_at(Vector3(.8,4.4,.62))
		game.player.weapon.visible = false
		await capture("cabin")
		game.world.weather.wake(5)
		game.player.camera.global_position = Vector3(5,2.65,40)
		game.wolves[0].position = Vector3(5,1.0,34)
		game.wolves[0].rotation.y = PI/2
		game.player.camera.look_at(Vector3(5,2.4,34))
		await capture("werewolf")
		game.world.weather.season = 0
		game.world.weather.hour = 9
		game.world.weather.blood_moon = false
		game.world.weather.apply()
		game.player.position = Vector3(5,1.0,30)
		game.player.camera.global_position = Vector3(5,2.65,30)
		first.position = Vector3(5,1.0,34)
		first.health = 600
		first.rotation.y = PI/2
		game.player.camera.look_at(first.position+Vector3(0,.60,0)*first.size_scale)
		game.current_weapon = 0
		game.player.weapon.visible = true
		game.player.set_weapon(0)
		game.fire_cooldown = 0
		game.reload_left = 0
		await physics_frame
		await physics_frame
		game.fire_weapon()
		check(not game.shot_review.reports.is_empty(),"Actual firearm shot produces a damage breakdown")
		await capture("bone-xray")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+".bak"))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
func capture(label: String) -> void:
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/feedback-update/"+label+".png")
