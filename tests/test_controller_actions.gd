extends SceneTree
var game: Node3D
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	print("PASS " if ok else "FAIL ",caption)
	if not ok: failures+=1
func button(index: int, down: bool=true, device: int=0) -> void:
	var event:=InputEventJoypadButton.new()
	event.device=device; event.button_index=index; event.pressed=down
	Input.parse_input_event(event); Input.flush_buffered_events()
func tap(index: int) -> void:
	button(index); button(index,false)
func run() -> void:
	game=load("res://scripts/main.gd").new()
	game.progress.save_path="user://controller_test_%d.cfg" % OS.get_process_id()
	root.add_child(game); game.set_process(false); game.player.set_physics_process(false)
	game.start_run(); game.progress.money=10000
	game.player.position=game.world.shop_position
	tap(JOY_BUTTON_Y)
	check(game.controller_device==0 and game.player.controller_device==0,"Xbox input automatically activates outside split screen")
	check(game.mode=="shop","Y opens store, even a tap between physics frames")
	tap(JOY_BUTTON_DPAD_DOWN)
	check(game.hud.shop_selection==1,"D-pad selects next weapon")
	var before: int=game.progress.money
	# Deliberately focus another button: A must buy the selected weapon only.
	game.hud._shop_filter_buttons.Special.grab_focus()
	tap(JOY_BUTTON_A)
	check(game.current_weapon==1 and game.progress.owned.has(1) and game.progress.money==before-int(game.WEAPONS[1].price),"A buys and equips exactly the selected weapon despite GUI focus")
	game.reserve_ammo[1]=0
	tap(JOY_BUTTON_X)
	check(game.reserve_ammo[1]==int(game.WEAPONS[1].reserve),"X buys reserve ammunition")
	game.health=70
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(game.health==game.maximum_health(),"D-pad right buys first aid")
	for i in 15: tap(JOY_BUTTON_DPAD_DOWN)
	await process_frame; await process_frame; await process_frame
	check(game.hud.shop_scroll.scroll_vertical>0,"Store scroll follows selection beyond first page")
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.hud.shop_filter=="Sidearms" and game.hud._shop_rows.has(game.hud.shop_selection),"RB changes category and selects visible weapon")
	tap(JOY_BUTTON_DPAD_DOWN)
	check(game.hud._shop_rows.has(game.hud.shop_selection),"Store browsing respects category filter")
	tap(JOY_BUTTON_B)
	check(game.mode=="playing" and game.player._jump_velocity==0,"B closes store without jumping or firing")
	game.player.poll_controller(.016)
	button(JOY_BUTTON_LEFT_SHOULDER)
	game.player.poll_controller(.016); game.player.poll_controller(.016)
	check(game.current_weapon==0,"LB changes weapon once while held")
	button(JOY_BUTTON_LEFT_SHOULDER,false); tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.current_weapon==1,"RB changes to next owned weapon")
	var drops: Array=game.world.houses.drops.duplicate()
	drops[0]=18; game.world.houses.apply_drops(drops)
	game.player.position=game.world.houses.positions[0]
	check(game.interaction_prompt().begins_with("[ Y ] TAKE"),"Xbox pickup prompt uses Y")
	tap(JOY_BUTTON_Y)
	check(game.world.houses.drops[0]==-1 and game.current_weapon==18,"Y picks up and equips a free house weapon")
	game.player.position=game.world.shop_position
	tap(JOY_BUTTON_Y); tap(JOY_BUTTON_Y)
	check(game.mode=="playing","Y can also leave the store")
	var key:=InputEventKey.new(); key.physical_keycode=KEY_Q; key.pressed=true
	Input.parse_input_event(key); Input.flush_buffered_events()
	check(game.controller_device==-1 and game.current_weapon==1,"Keyboard input switches back and cycles normally")
	key.pressed=false; Input.parse_input_event(key.duplicate()); Input.flush_buffered_events()
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.controller_device==0 and game.current_weapon==18,"Controller can take over again")
	game.player._joy_connection_changed(0,false)
	check(game.controller_device==-1,"Disconnected controller restores keyboard control")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame
	quit(1 if failures else 0)
