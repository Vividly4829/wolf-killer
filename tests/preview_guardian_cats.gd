extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1600,1000); root.content_scale_size=root.size
	var studio:=Node3D.new(); root.add_child(studio)
	var world:=WorldEnvironment.new(); world.environment=Environment.new(); studio.add_child(world)
	world.environment.background_mode=Environment.BG_COLOR; world.environment.background_color=Color("263340")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; world.environment.ambient_light_color=Color("d5dfec"); world.environment.ambient_light_energy=.65
	for angle in [Vector3(-40,-35,0),Vector3(15,130,0)]:
		var light:=DirectionalLight3D.new(); light.rotation_degrees=angle; light.light_energy=1.25 if angle.x<0 else .65; studio.add_child(light)
	for i in 2:
		var cat=load("res://scripts/guardian_cat_model.gd").new(); cat.variant=i; studio.add_child(cat); cat.position.x=(i-.5)*3.8; cat.rotation.y=-.35
	var camera:=Camera3D.new(); studio.add_child(camera); camera.current=true; camera.position=Vector3(6,4.2,10); camera.look_at(Vector3(0,1.2,0)); camera.fov=43
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/guardian-cats-models.png")
	print("CAT PREVIEW COMPLETE"); quit()
