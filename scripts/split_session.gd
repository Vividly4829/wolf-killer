extends Control
## Local-only two-to-four-player session. Direct in-process state, no network connection.
var games: Array[Node] = []
var views: Array[SubViewport] = []
var screens: Array[TextureRect] = []
var closing := false
var secondary_save_path := "user://progress_local_controller.cfg"
const HUD_SIZE := Vector2i(1280,360)
var player_count := 2
var devices: Array[int] = []
func launch(original: Node,count: int = 2,resume: bool = false) -> void:
	player_count=clampi(count,2,4)
	devices.assign(Input.get_connected_joypads().slice(0,player_count-1))
	while devices.size()<player_count-1:
		var unused := 0
		while unused in devices: unused+=1
		devices.append(unused)
	name="SplitSession"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	original.hud.commit_start_options()
	var profile = original.progress
	var start_level: int=original.menu_start_level
	var start_money: int=-1 if resume else original.menu_start_money
	var unlocked: bool=original.start_options_unlocked
	var saved_level: int=profile.resume_level if resume else 0
	original.coop.leave()
	get_tree().set_multiplayer(null,original.get_path())
	original.queue_free()
	await get_tree().process_frame
	for index in player_count:
		var viewport := SubViewport.new()
		viewport.name="View%d"%index
		viewport.size=HUD_SIZE
		viewport.size_2d_override=logical_size(index)
		viewport.size_2d_override_stretch=true
		viewport.scaling_3d_scale=1.0
		viewport.msaa_3d=Viewport.MSAA_DISABLED if player_count>=3 else Viewport.MSAA_2X
		viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.handle_input_locally=true
		viewport.audio_listener_enable_3d=index==0
		add_child(viewport); views.append(viewport)
		var screen := TextureRect.new()
		screen.texture=viewport.get_texture(); screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
		screen.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; screen.stretch_mode=TextureRect.STRETCH_SCALE
		add_child(screen); screens.append(screen)
		var game = load("res://scripts/main.gd").new()
		game.controller_device=-1 if index==0 else devices[index-1]
		game.split_session=self
		game.mode="loading"
		game.menu_start_level=start_level; game.menu_start_money=start_money
		game.start_options_unlocked=unlocked
		if index==0: game.progress=profile
		else: game.progress.save_path=secondary_save_path if index==1 else secondary_save_path.get_basename()+"_p%d.cfg"%(index+1)
		viewport.add_child(game); games.append(game)
		# Native pixels for every seat; reduce repeated shadow passes instead.
		game.world.sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		game.world.sun.directional_shadow_max_distance=40.0
		var menu_scale := float(logical_size(index).y)/720.0
		game.hud.scale=Vector2.ONE*menu_scale; game.hud.position=Vector2((1280-1280*menu_scale)*.5,0)
		var canvas:=CanvasLayer.new(); game.add_child(canvas)
		var compact=load("res://scripts/split_hud.gd").new(); compact.game=game; canvas.add_child(compact)
		game.shot_review.reparent(compact); game.shot_review.scale=Vector2.ONE*.65; game.shot_review.position=Vector2(1005,125)
		if index>0:
			for track in game.sounds.score: track.stop()
	var peers: Array = games.map(func(game): return game.coop)
	for index in player_count: games[index].coop.setup_local(peers,index+1)
	for index in range(1,player_count):
		games[0].coop._peer_connected(index+1)
		games[index].start_run(false,not resume,saved_level)
	games[0].start_run(false,not resume,saved_level)
	games[0].coop._process(.1)
	_process(0) # Establish view rectangles before accepting the first mouse event.
	views[0].notify_mouse_entered()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _process(_delta: float) -> void:
	if closing: return
	var area:=get_viewport_rect().size
	# Canvas coordinates stay at the UI design size. The camera textures must
	# use real framebuffer pixels, otherwise 4K just enlarges two 1280x360 views.
	var pixels:=Vector2i((get_viewport().get_stretch_transform()*Rect2(Vector2.ZERO,area)).size)
	for i in screens.size():
		var rect := view_rect(i)
		screens[i].position=rect.position*area
		screens[i].size=rect.size*area
		var render_size:=Vector2i(Vector2(pixels)*rect.size)
		if views[i].size!=render_size: views[i].size=render_size
	for game in games:
		if is_instance_valid(game.hud): game.hud.visible=game.mode!="playing"
	var connected := Input.get_connected_joypads()
	for i in range(1,games.size()):
		if devices[i-1] not in connected:
			for device in connected:
				if device not in devices: devices[i-1]=device; break
		games[i].player.use_input_device(devices[i-1])
func logical_size(index: int) -> Vector2i:
	return Vector2i(1280,360) if player_count==2 or (player_count==3 and index==0) else Vector2i(1280,720)
func view_rect(index: int) -> Rect2:
	if player_count==2: return Rect2(0,index*.5,1,.5)
	if player_count==3:
		return Rect2(0,0,1,.5) if index==0 else Rect2((index-1)*.5,.5,.5,.5)
	return Rect2((index%2)*.5,floori(index/2.0)*.5,.5,.5)
func _input(event: InputEvent) -> void:
	if views.is_empty() or closing: return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		for i in range(1,views.size()):
			if event.device==devices[i-1]: views[i].push_input(event.duplicate(),true)
		get_viewport().set_input_as_handled()
		return
	var forwarded:=event.duplicate()
	if forwarded is InputEventMouse:
		# Keyboard/mouse belong exclusively to the upper player, including their menus.
		forwarded.position=forwarded.position/screens[0].size*Vector2(views[0].size_2d_override)
		if forwarded is InputEventMouseMotion: forwarded.relative=event.relative
	views[0].push_input(forwarded,true)
	get_viewport().set_input_as_handled()
func close() -> void:
	if closing: return
	closing=true
	for game in games:
		game.save_checkpoint(); game.coop.leave()
		get_tree().set_multiplayer(null,game.get_path())
	var menu=load("res://scripts/main.gd").new()
	if not games.is_empty(): menu.progress=games[0].progress
	get_tree().root.add_child(menu)
	queue_free()
