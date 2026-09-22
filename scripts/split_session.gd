extends Control
## Local-only two-player session. Direct in-process state, no network connection.
var games: Array[Node] = []
var views: Array[SubViewport] = []
var screens: Array[TextureRect] = []
var closing := false
var secondary_save_path := "user://progress_local_controller.cfg"
const HUD_SIZE := Vector2i(1280,360)
func launch(original: Node) -> void:
	name="SplitSession"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	original.hud.commit_start_options()
	var profile = original.progress
	var start_level: int=original.menu_start_level
	var start_money: int=original.menu_start_money
	original.coop.leave()
	get_tree().set_multiplayer(null,original.get_path())
	original.queue_free()
	await get_tree().process_frame
	for index in 2:
		var viewport := SubViewport.new()
		viewport.name="View%d"%index
		viewport.size=HUD_SIZE
		viewport.size_2d_override=HUD_SIZE
		viewport.size_2d_override_stretch=true
		viewport.scaling_3d_scale=1.0
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
		game.controller_device=-1 if index==0 else (Input.get_connected_joypads()[0] if not Input.get_connected_joypads().is_empty() else 0)
		game.split_session=self
		game.mode="loading"
		game.menu_start_level=start_level; game.menu_start_money=start_money
		if index==0: game.progress=profile
		else: game.progress.save_path=secondary_save_path
		viewport.add_child(game); games.append(game)
		game.hud.scale=Vector2.ONE*.5; game.hud.position=Vector2(320,0)
		var canvas:=CanvasLayer.new(); game.add_child(canvas)
		var compact=load("res://scripts/split_hud.gd").new(); compact.game=game; canvas.add_child(compact)
		game.shot_review.reparent(compact); game.shot_review.scale=Vector2.ONE*.65; game.shot_review.position=Vector2(1005,125)
		if index==1:
			for track in game.sounds.score: track.stop()
	# Bind both hunters before starting either campaign. The host's normal wake
	# path places both hunters in the main cabin synchronously, without joining.
	games[0].coop.setup_local(games[1].coop,1)
	games[1].coop.setup_local(games[0].coop,2)
	games[0].coop._peer_connected(2)
	games[1].start_from_menu()
	games[0].start_from_menu()
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
		screens[i].position=Vector2(0,area.y*.5*i)
		screens[i].size=Vector2(area.x,area.y*.5)
		var render_size:=Vector2i(maxi(2,pixels.x),maxi(2,pixels.y/2))
		if views[i].size!=render_size: views[i].size=render_size
	for game in games:
		if is_instance_valid(game.hud): game.hud.visible=game.mode!="playing"
	if games.size()==2 and not Input.get_connected_joypads().is_empty():
		games[1].player.use_input_device(Input.get_connected_joypads()[0])
func _input(event: InputEvent) -> void:
	if views.is_empty() or closing: return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if views.size()>1: views[1].push_input(event.duplicate(),true)
		get_viewport().set_input_as_handled()
		return
	var forwarded:=event.duplicate()
	if forwarded is InputEventMouse:
		# Keyboard/mouse belong exclusively to the upper player, including their menus.
		forwarded.position=forwarded.position/screens[0].size*Vector2(HUD_SIZE)
		if forwarded is InputEventMouseMotion: forwarded.relative=event.relative
	views[0].push_input(forwarded,true)
	get_viewport().set_input_as_handled()
func close() -> void:
	if closing: return
	closing=true
	for game in games:
		game.progress.save_progress(); game.coop.leave()
		get_tree().set_multiplayer(null,game.get_path())
	var menu=load("res://scripts/main.gd").new()
	if not games.is_empty(): menu.progress=games[0].progress
	get_tree().root.add_child(menu)
	queue_free()
