extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(512,256)
	var viewport:=SubViewport.new(); viewport.size=Vector2i(400,180); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("15242c"); env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c5d8e2"); env.environment.ambient_light_energy=.85; viewport.add_child(env)
	for rotation in [Vector3(-40,-30,0),Vector3(30,140,0)]:
		var light:=DirectionalLight3D.new(); light.rotation_degrees=rotation; light.light_energy=1.3; viewport.add_child(light)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.position.z=4; viewport.add_child(camera); camera.current=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/weapon_icons"))
	for index in 36:
		var pivot:=Node3D.new(); viewport.add_child(pivot)
		var weapon=preload("res://scripts/weapon_visual.gd").new(); weapon.set_inspection_mode(true); pivot.add_child(weapon); weapon.set_process(false); weapon.build(index)
		var bounds: AABB=weapon.get_model_bounds(); weapon.position=-bounds.get_center()
		pivot.rotation_degrees=Vector3(-38,35,-8) if index==3 else Vector3(-8,74,-3)
		var rotated: AABB=pivot.transform*bounds
		camera.size=maxf(.20,maxf(rotated.size.y*1.25,rotated.size.x/(400.0/180.0)*1.20))
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://assets/weapon_icons/%02d.png"%index)
		pivot.queue_free(); await process_frame
	print("WEAPON_ICONS_COMPLETE"); quit()
