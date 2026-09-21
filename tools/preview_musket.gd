extends SceneTree

func _initialize() -> void:
	call_deferred("render_preview")

func render_preview() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("879a91")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	world.environment = environment
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, -0.7, 0)
	light.light_energy = 1.2
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 78
	camera.near = 0.035
	scene.add_child(camera)
	camera.current = true
	var weapon = load("res://scripts/weapon_visual.gd").new()
	camera.add_child(weapon)
	weapon.build(0)
	weapon.position = Vector3(0.24, -0.29, -0.42)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/musket_model.png")
	weapon.position = Vector3(0.17, -0.44, -0.52)
	weapon.rotation = Vector3(0.90, 0.09, -0.20)
	weapon.animate_reload(0.58, true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/musket_loading.png")
	quit()
