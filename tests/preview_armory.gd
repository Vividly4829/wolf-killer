extends SceneTree
const Visual=preload("res://scripts/weapon_visual.gd")
const Builder=preload("res://scripts/weapon_model_builder.gd")
class PreviewGame extends "res://scripts/main.gd":
	func _run_visual_qa() -> void:
		pass
var directory: String
func _initialize() -> void:
	call_deferred("run_preview")
func frames(count: int) -> void:
	for frame: int in count: await process_frame
func run_preview() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	directory=ProjectSettings.globalize_path("res://qa/armory")
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1800,1080)
	root.content_scale_size=Vector2i(1800,1080)
	AudioServer.set_bus_mute(0,true)
	var studio:=Node3D.new()
	root.add_child(studio)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("172029")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("d8e0e6")
	environment.environment.ambient_light_energy=.7
	studio.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-40,0)
	light.light_energy=1.4
	studio.add_child(light)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(25,120,0)
	fill.light_color=Color("bbd2ee")
	fill.light_energy=.7
	studio.add_child(fill)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=9.2
	camera.position=Vector3(0,0,10)
	camera.current=true
	studio.add_child(camera)
	var canvas:=CanvasLayer.new()
	studio.add_child(canvas)
	for index: int in 18:
		var pivot:=Node3D.new()
		studio.add_child(pivot)
		pivot.position=Vector3((float(index%6)-2.5)*2.50,(1.-floor(float(index)/6.))*2.82,0)
		pivot.rotation=Vector3(.16,1.15 if index!=3 else .30,0)
		var visual:=Visual.new()
		pivot.add_child(visual)
		visual.build(index)
		visual.set_inspection_mode(true)
		visual.set_process(false)
		var bounds:=visual.get_model_bounds()
		visual.position=-bounds.get_center()
		var scale_factor:=2.10/maxf(bounds.size.z,bounds.size.x)
		pivot.scale=Vector3.ONE*scale_factor
		var label:=Label.new()
		label.position=Vector2(float(index%6)*300.+15.,float(index/6)*331.+279.)
		label.size=Vector2(280,54)
		label.text="%02d  %s"%[index+1,Builder.NAMES[index]]
		label.add_theme_font_size_override("font_size",18)
		label.add_theme_color_override("font_color",Color("e5d7bc"))
		canvas.add_child(label)
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("contact_sheet.png"))
	studio.queue_free()
	await frames(3)
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	var game:=PreviewGame.new()
	root.add_child(game)
	var save_path: String="user://armory_preview_%s.cfg"%OS.get_process_id()
	game.progress.save_path=save_path
	game.start_run()
	game.dialogue_left=0.0
	game.notice_left=0.0
	for index: int in 18:
		if not game.progress.owned.has(index): game.progress.owned.append(index)
	var contact:=Image.create(1600,1620,false,Image.FORMAT_RGBA8)
	contact.fill(Color("172029"))
	for index: int in 18:
		game.select_weapon(index)
		game.player.pitch=-.05
		game.player._update_rotation()
		game.reload_left=0.0
		game.player.weapon.set_loaded(true)
		await frames(4)
		await RenderingServer.frame_post_draw
		var picture:=root.get_texture().get_image()
		picture.save_png(directory.path_join("fps_%02d.png"%index))
		var thumbnail:=picture.get_region(Rect2i(320,180,960,540))
		thumbnail.resize(400,270,Image.INTERPOLATE_LANCZOS)
		contact.blit_rect(thumbnail,Rect2i(0,0,400,270),Vector2i((index%4)*400,(index/4)*270))
		game.ammo[index]=0
		game.reload_weapon()
		game.reload_left=game.reload_duration*.49
		await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("reload_%02d.png"%index))
		game.reload_left=0.0
		if index==9:
			game.toggle_fire_mode()
			game.lemat_shot_ammo=0
			game.reload_weapon()
			game.reload_left=game.reload_duration*.43
			await frames(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("reload_09_secondary.png"))
			game.toggle_fire_mode()
	contact.save_png(directory.path_join("first_person_contact.png"))
	game.queue_free()
	await frames(4)
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("ARMORY_VISUAL_QA_COMPLETE: 18 models, 18 first-person views and 18 reloads.")
	quit()
