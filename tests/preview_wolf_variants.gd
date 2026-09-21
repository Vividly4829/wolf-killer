extends SceneTree

const Wolf = preload("res://scripts/wolf.gd")
const Profiles = preload("res://scripts/wolf_profile.gd")
const Navigation = preload("res://scripts/island_nav.gd")
const MainGame = preload("res://scripts/main.gd")
const Progress = preload("res://scripts/progress_store.gd")

class StudioGame extends Node3D:
	var world: Node3D
	var player: Node3D
	var sounds: Node
	var safe := false
	func is_playing() -> bool: return false
	func is_player_safe() -> bool: return false

class StudioGround extends Node3D:
	var nav: RefCounted
	var exterior_rally_point := Vector3.ZERO

var output_dir: String
var samples: Array[Dictionary] = []
var small_seed := -1
var large_seed := -1
var middle_seed := -1
var save_path: String

func _initialize() -> void:
	call_deferred("run_preview")

func run_preview() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Wolf previews require the native renderer.")
		quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	output_dir = ProjectSettings.globalize_path("res://qa/wolf_variants")
	DirAccess.make_dir_recursive_absolute(output_dir)
	select_samples()
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var gallery := Control.new()
	root.add_child(gallery)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101921")
	backdrop.size = Vector2(1920, 1080)
	gallery.add_child(backdrop)
	add_label(gallery, "ADULT WOLF VARIATION", Vector2(30, 20), 30)
	add_label(gallery, "Six natural coats, followed by the smallest and largest seeded adults. Identical lighting and camera scale.", Vector2(32, 62), 19)
	for index in samples.size():
		var column := index % 4
		var row := index / 4
		var container := SubViewportContainer.new()
		container.position = Vector2(column * 480, 110 + row * 470)
		container.size = Vector2(480, 390)
		gallery.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(480, 390)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var studio := make_studio(viewport)
		var wolf := add_studio_wolf(studio, int(samples[index].seed))
		var camera := Camera3D.new()
		studio.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.5
		camera.position = Vector3(4.0, 1.7, 3.7)
		camera.look_at(Vector3(0, 0.60, 0))
		camera.current = true
		var profile: Dictionary = wolf.profile
		add_label(gallery, str(samples[index].title), Vector2(column * 480 + 28, 504 + row * 470), 20)
		add_label(gallery, "%s  /  %.1f kg  /  %.2fx  /  seed %d" % [str(profile.sex).capitalize(), float(profile.mass_kg), float(profile.size_scale), int(profile.profile_seed)], Vector2(column * 480 + 28, 535 + row * 470), 15)
	await capture("01_coat_gallery.png", 18)
	gallery.queue_free()
	await frames(3)

	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var comparison := make_studio(root)
	var view := Camera3D.new()
	comparison.add_child(view)
	view.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.size = 6.6
	view.position = Vector3(0, 1.3, 10)
	view.look_at(Vector3(0, 0.45, 0))
	view.current = true
	var overlay := CanvasLayer.new()
	comparison.add_child(overlay)
	add_label(overlay, "ADULT SIZE COMPARISON", Vector2(28, 25), 28)
	add_label(overlay, "Same ground, same camera. Larger individuals trade agility for strength.", Vector2(30, 63), 18)
	var comparison_seeds: Array[int] = [small_seed, middle_seed, large_seed]
	var comparison_names: Array[String] = ["SMALL ADULT", "MIDDLE ADULT", "RARE LARGE ADULT"]
	for index in 3:
		var wolf := add_studio_wolf(comparison, comparison_seeds[index])
		wolf.position.x = (index - 1) * 3.7
		wolf.rotation.y = PI / 2.0
		var profile: Dictionary = wolf.profile
		add_label(overlay, comparison_names[index], Vector2(44 + index * 420, 534), 22)
		add_label(overlay, "%.2fx  |  %.1f kg  |  %s" % [float(profile.size_scale), float(profile.mass_kg), str(profile.sex)], Vector2(44 + index * 420, 567), 18)
		add_label(overlay, "Health %.0f  /  Bite %.1f  /  Charge %.2f m/s" % [float(profile.max_health), float(profile.bite_damage), float(profile.charge_speed)], Vector2(44 + index * 420, 600), 15)
	await capture("02_size_comparison.png", 12)
	comparison.queue_free()
	await frames(3)

	var game := MainGame.new()
	game.progress = Progress.new()
	save_path = "user://wolf_variants_preview_%s_%s.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	game.progress.save_path = save_path
	root.add_child(game)
	game.set_process(false)
	game.start_run()
	game.player.set_physics_process(false)
	game.dialogue_left = 0.0
	game.notice_left = 0.0
	game.intermission = false
	game.pending_spawns = 1
	game.player.reset_at(game.world.nav.point(game.world.nav.nearest(-1.0, 9.0, 3.0)))
	var spawn: Vector3 = game.world.wolf_nav.point(game.world.wolf_nav.nearest(-1.0, 12.0, 3.0))
	game._add_wolf_at(spawn, large_seed)
	var attacker: Node3D = game.wolves.back()
	attacker.set_physics_process(false)
	var facing: Vector3 = attacker.position + Vector3.UP * (0.8 * attacker.size_scale) - game.player.camera.global_position
	game.player.yaw = atan2(-facing.x, -facing.z)
	game.player.pitch = atan2(facing.y, Vector2(facing.x, facing.z).length())
	game.player._update_rotation()
	attacker.rotation.y = atan2(game.player.position.x - attacker.position.x, game.player.position.z - attacker.position.z)
	game.mode = "playing"
	await capture("03_large_wolf_in_game.png", 12)
	attacker.hear_gunshot(game.player.position)
	game._update_pursuit()
	var caught := false
	var caught_frames := 0
	for frame in 600:
		await physics_frame
		# The hidden QA window can lose focus; actual gameplay timers still run.
		if game.mode == "paused":
			game.mode = "playing"
		game._process(1.0 / 60.0)
		attacker._physics_process(1.0 / 60.0)
		game.player._physics_process(1.0 / 60.0)
		if game.is_struggling():
			caught = true
			caught_frames += 1
			if caught_frames >= 24:
				break
	game.mode = "playing"
	await capture("04_large_wolf_grapple.png", 3)
	var report := {"profiles": samples, "large_seed": large_seed, "large_size": attacker.size_scale, "large_mass_kg": attacker.profile.mass_kg, "grapple_active": caught and game.is_struggling(), "wolf_behavior": attacker.behavior, "player_health": game.health, "camera_height": game.player.camera.position.y, "camera_fov": game.player.camera.fov, "wolf_distance": game.player.position.distance_to(attacker.position), "player_position": str(game.player.position), "wolf_position": str(attacker.position)}
	var file := FileAccess.open(output_dir.path_join("preview_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	game.queue_free()
	await frames(3)
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("WOLF_VARIANTS_PREVIEW %s" % JSON.stringify(report))
	quit(0 if caught else 1)

func select_samples() -> void:
	var choices: Dictionary = {}
	var smallest := INF
	var largest := -INF
	var middle_difference := INF
	for candidate_seed in range(50000, 60000):
		var profile: Dictionary = Profiles.generate(1, candidate_seed)
		var size: float = profile.size_scale
		if size < smallest:
			smallest = size
			small_seed = candidate_seed
		if size > largest:
			largest = size
			large_seed = candidate_seed
		if absf(size - 1.0) < middle_difference:
			middle_difference = absf(size - 1.0)
			middle_seed = candidate_seed
		if size >= 0.98 and size <= 1.04 and not choices.has(profile.coat_name):
			choices[profile.coat_name] = candidate_seed
	for coat: Dictionary in Profiles.COATS:
		var candidate: int = choices[coat.name]
		samples.append({"title": str(coat.name).to_upper(), "seed": candidate, "size": Profiles.generate(1, candidate).size_scale})
	samples.append({"title": "SMALL ADULT / " + str(Profiles.generate(1, small_seed).coat_name).to_upper(), "seed": small_seed, "size": smallest})
	samples.append({"title": "RARE LARGE ADULT / " + str(Profiles.generate(1, large_seed).coat_name).to_upper(), "seed": large_seed, "size": largest})

func make_studio(parent: Node) -> StudioGame:
	var studio := StudioGame.new()
	parent.add_child(studio)
	studio.world = StudioGround.new()
	studio.add_child(studio.world)
	var navigation := Navigation.new()
	var heights: Array = []
	heights.resize(41 * 41)
	heights.fill(0.0)
	var blocked := PackedByteArray()
	blocked.resize(41 * 41)
	navigation.setup({"width":41, "depth":41, "cellSize":0.5, "origin":[-10,-10], "heights":heights, "blocked":blocked})
	studio.world.nav = navigation
	studio.player = Node3D.new()
	studio.add_child(studio.player)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("19232b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d8e1eb")
	environment.environment.ambient_light_energy = 0.70
	studio.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -45, 0)
	light.light_energy = 1.2
	studio.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 135, 0)
	fill.light_energy = 0.5
	fill.light_color = Color("b6c9dc")
	studio.add_child(fill)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(30, 30)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263238")
	material.roughness = 1.0
	plane.material_override = material
	studio.add_child(plane)
	return studio

func add_studio_wolf(studio: StudioGame, profile_seed: int) -> Node3D:
	var wolf := Wolf.new()
	wolf.configure(studio, studio.world.nav, 1, profile_seed)
	studio.add_child(wolf)
	wolf.set_physics_process(false)
	return wolf

func add_label(parent: Node, text_value: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e6e0d0"))
	parent.add_child(label)

func frames(count: int) -> void:
	for frame in count:
		await process_frame

func capture(filename: String, warmup_frames: int) -> void:
	await frames(warmup_frames)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(filename))
