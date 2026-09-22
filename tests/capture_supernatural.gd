extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	var game=preload("res://scripts/main.gd").new(); game.progress.transient=true; root.add_child(game)
	game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.supernatural.set_process(false)
	game.set_mode("weapon_stats")
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/new-armory.png")
	game.set_mode("playing"); game.player.weapon.hide()
	var p:=Vector3(140,80,140)
	var a=game.supernatural.spawn("angel",p+Vector3(-1.3,.5,0)); a.set_physics_process(false); a.rotation.y=0
	var b=game.supernatural.spawn("devil",p+Vector3(1.3,0,0)); b.set_physics_process(false); b.rotation.y=0
	var floor_mesh:=MeshInstance3D.new(); var plane:=BoxMesh.new(); plane.size=Vector3(12,.1,10); floor_mesh.mesh=plane
	game.add_child(floor_mesh); floor_mesh.position=p+Vector3(0,-.1,0)
	var light:=OmniLight3D.new(); light.omni_range=15; light.light_energy=1.2; game.add_child(light); light.position=p+Vector3(0,4,3)
	game.player.camera.global_position=p+Vector3(0,2.2,6); game.player.camera.look_at(p+Vector3(0,1.2,0)); game.player.camera.current=true
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/supernatural-actors.png")
	game.queue_free(); await process_frame; quit()
