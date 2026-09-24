extends SceneTree
const Visual=preload("res://scripts/weapon_visual.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var suffix:="after" if OS.get_cmdline_user_args().has("--after") else "before"
 root.mode=Window.MODE_WINDOWED; root.size=Vector2i(480,300); root.content_scale_size=Vector2i(480,300)
 var studio:=Node3D.new(); root.add_child(studio)
 var world:=WorldEnvironment.new(); world.environment=Environment.new(); studio.add_child(world)
 world.environment.background_mode=Environment.BG_COLOR; world.environment.background_color=Color("202831")
 world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; world.environment.ambient_light_color=Color("d5dfec"); world.environment.ambient_light_energy=.85
 for angle in [Vector3(-40,-35,0),Vector3(15,130,0)]:
  var light:=DirectionalLight3D.new(); light.rotation_degrees=angle; light.light_energy=1.25 if angle.x<0 else .65; studio.add_child(light)
 var camera:=Camera3D.new(); studio.add_child(camera); camera.current=true; camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.position=Vector3(0,0,4)
 var canvas:=CanvasLayer.new(); root.add_child(canvas); var label:=Label.new(); canvas.add_child(label); label.position=Vector2(12,273); label.add_theme_font_size_override("font_size",14)
 for page in 3:
  var sheet:=Image.create(1920,900,false,Image.FORMAT_RGBA8)
  for cell in 12:
   var id:=page*12+cell
   var visual:=Visual.new(); studio.add_child(visual); visual.build(id); visual.set_inspection_mode(true); visual.set_process(false)
   visual.rotation=Vector3(.12,1.10 if id not in [3,21,22,23] else .52,-.08)
   var box: AABB=visual.transform*visual.get_model_bounds(); visual.position=-box.get_center()
   camera.size=maxf(box.size.y,box.size.x/1.6)*1.28
   label.text="%02d  %s"%[id,preload("res://scripts/weapon_catalog.gd").WEAPONS[id].name]
   await process_frame; await process_frame; await RenderingServer.frame_post_draw
   var shot:=root.get_texture().get_image(); shot.resize(480,300)
   sheet.blit_rect(shot,Rect2i(0,0,480,300),Vector2i(cell%4*480,cell/4*300))
   visual.free()
  sheet.save_png("res://qa/armory-review-%s-%d.png"%[suffix,page])
 print("ARMORY_REVIEW_COMPLETE ",suffix)
 quit()
