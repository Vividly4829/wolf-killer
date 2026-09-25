extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=preload("res://scripts/main.gd").new(); game.progress.transient=true; root.add_child(game)
 game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.supernatural.set_process(false)
 game.hud.hide(); game.world.weather.hour=13; game.world.weather.apply()
 game.player.position=game.world.exterior_rally_point; game.player.yaw=1.3; game.player.pitch=0; game.player._update_rotation()
 root.mode=Window.MODE_WINDOWED; root.size=Vector2i(960,540); root.content_scale_size=Vector2i(1280,720)
 var canvas:=CanvasLayer.new(); root.add_child(canvas); var label:=Label.new(); canvas.add_child(label); label.position=Vector2(15,15); label.add_theme_font_size_override("font_size",20)
 for pose in ["hip","aim","reload"]:
  for page in 1:
   var sheet:=Image.create(960,270,false,Image.FORMAT_RGBA8)
   for cell in 2:
    var id: int=[33,36][cell]; game.select_weapon(id)
    var visual: Node3D=game.player.weapon
    visual.position=Vector3(.04 if id in [30,31,32] else .26,-.24,-.38); visual.rotation=Vector3.ZERO
    if id in [21,22,23]: visual.position=Vector3(.25,-.18,-.45)
    if pose=="aim": visual.position=Vector3(-visual.model_meta.sight.x,-visual.model_meta.sight.y,-.48)
    if pose=="reload": visual.position=Vector3(.18,-.22,-.46); visual.rotation=Vector3(.25,.25,-.18)
    visual.set_process(false); visual.animate_reload(.52,pose=="reload"); visual.set_loaded(pose!="reload")
    label.text="%02d %s / %s"%[id,game.WEAPONS[id].name,pose]
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    var picture:=root.get_texture().get_image(); picture.resize(480,270)
    sheet.blit_rect(picture,Rect2i(0,0,480,270),Vector2i(cell*480,0))
   sheet.save_png("res://qa/volley-luger-%s-%d.png"%[pose,page])
 print("FIRST_PERSON_REVIEW_COMPLETE: Luger and volley gun / hip, aim, reload")
 quit()
