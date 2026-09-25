extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func run() -> void:
	var count := 3 if "--three" in OS.get_cmdline_user_args() else 4
	root.content_scale_size=Vector2i(1280,720)
	root.size=Vector2i(3840,2160)
	var original=load("res://scripts/main.gd").new()
	original.progress.save_path="user://four_test_%d.cfg"%OS.get_process_id()
	root.add_child(original)
	original.menu_start_money=987
	var session=load("res://scripts/split_session.gd").new()
	session.secondary_save_path="user://four_guest_%d.cfg"%OS.get_process_id()
	root.add_child(session)
	await session.launch(original,count)
	await process_frame
	var host=session.games[0]
	host.coop.award(25)
	host.coop.clock+=1; host.coop._process(.2)
	var paths: Array=[]
	for i in count:
		var game=session.games[i]
		check(game.mode=="playing","P%d enters gameplay immediately"%(i+1))
		check(game.coop.peer_id()==i+1 and game.coop.avatars.size()==count-1,"P%d has all teammates"%(i+1))
		check(game.progress.money==1012,"P%d starting funds and shared reward"%(i+1))
		check(game.progress.save_path not in paths,"P%d unique save profile"%(i+1)); paths.append(game.progress.save_path)
		check(game.controller_device==(-1 if i==0 else session.devices[i-1]),"P%d owns correct device"%(i+1))
		check(session.views[i].size==Vector2i(Vector2(3840,2160)*session.view_rect(i).size),"P%d native 4K pixel allocation"%(i+1))
		game.hud_detail_left=30
		for kind in game.rituals.BOONS: game.rituals.boons[kind]=2
		game.shot_review.begin_shot()
		game.shot_review.remaining=60
		game.world.weather.hour=13; game.world.weather.apply()
		game.shot_review._process(0)
		check(game.shot_review.position.x-332*game.shot_review.scale.x>=0,"P%d replay fits"%(i+1))
		check(game.shot_review.position.y>=0 and game.shot_review.position.y+345*game.shot_review.scale.y<=session.logical_size(i).y,"P%d xray fits"%(i+1))
	for i in range(1,count):
		var event:=InputEventJoypadButton.new()
		event.device=session.devices[i-1]; event.button_index=JOY_BUTTON_START; event.pressed=true
		session._input(event)
		check(session.games[i].mode=="paused","controller pauses only P%d"%(i+1))
		for j in count:
			if j!=i: check(session.games[j].mode=="playing","other P%d unaffected"%(j+1))
		event.pressed=false; session._input(event)
		event.pressed=true; session._input(event)
		event.pressed=false; session._input(event)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/local-%d-4k.png"%count)
	for game in session.games:
		game.coop.leave()
		for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	print("LOCAL MULTI FAILURES: ",failures)
	quit(failures)
