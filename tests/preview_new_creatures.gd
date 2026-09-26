extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1800,900)
	var scene:=Node3D.new(); root.add_child(scene)
	var env:=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("313944")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color.WHITE; env.environment.ambient_light_energy=.7; scene.add_child(env)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-40,-35,0); light.light_energy=1.4; scene.add_child(light)
	for i in 2:
		var animal=load("res://scripts/wildlife.gd").new()
		animal.species="rabbit" if i==0 else "wererabbit"
		animal.model=Node3D.new(); scene.add_child(animal.model); animal.build_rabbit()
		animal.model.position=Vector3(-3+i*2.6,0,0); animal.model.rotation.y=.4
		animal.free()
	for i in 2:
		var soldier=load("res://scripts/period_soldier_model.gd").new()
		soldier.faction="confederate" if i==0 else "nazi"; soldier.coat_color=Color("77736d") if i==0 else Color("4a5146")
		scene.add_child(soldier); soldier.position=Vector3(2+i*1.7,0,0); soldier.rotation.y=PI+.2
	var camera:=Camera3D.new(); scene.add_child(camera); camera.position=Vector3(3,3.5,10); camera.look_at(Vector3(.6,1.1,0)); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=10.5
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/new-creatures.png"); quit()
