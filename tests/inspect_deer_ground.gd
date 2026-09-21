extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://deer_inspect_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.set_process(false)
	var deer=preload("res://scripts/wildlife.gd").new()
	deer.game=game; game.add_child(deer); deer.set_physics_process(false)
	print("MODEL scale=",deer.model.scale," offset=",deer.model.position," anim=",deer.animation.get_animation_list())
	var skeleton=deer.model.find_children("*","Skeleton3D",true,false)[0]
	for clip in ["Idle_001","Run"]:
		deer.animation.play(clip)
		for t in [0.0,.15,.3,.45,.6]:
			deer.animation.seek(t,true); skeleton.force_update_all_bone_transforms()
			var feet:=[]
			for i in skeleton.get_bone_count():
				if ".002" in skeleton.get_bone_name(i) and "leg" in skeleton.get_bone_name(i): feet.append([skeleton.get_bone_name(i),skeleton.global_transform*skeleton.get_bone_global_pose(i).origin])
			print(clip," ",t," feet=",feet)
	game.queue_free(); await process_frame; quit()
