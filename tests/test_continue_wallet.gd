extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failures+=1
func run() -> void:
	var store=preload("res://scripts/progress_store.gd").new()
	check(store.money==0,"new profile starts with zero credits")
	var game=preload("res://scripts/main.gd").new()
	game.progress.save_path="user://continue_test_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.set_process(false); game.player.set_physics_process(false); game.supernatural.set_process(false)
	check(not game.unlock_start_options("bad-code"),"incorrect code remains locked")
	game.menu_start_money=9000; game.menu_start_level=20; game.hud.commit_start_options()
	check(game.menu_start_money==-1 and game.menu_start_level==1,"locked menu ignores custom start values")
	check(game.unlock_start_options("WOLFMASTER"),"correct code unlocks settings")
	game.menu_start_money=1450; game.menu_start_level=8; game.start_run(false,true)
	game.progress.owned.append(7); game.save_checkpoint()
	store.save_path=game.progress.save_path; store.load_progress()
	check(store.money==1450 and store.resume_level==8 and store.owned.has(7),"wallet level and equipment survive disk reload")
	game.return_to_menu(); game.continue_run()
	check(game.level==8 and game.progress.money==1450 and game.progress.owned.has(7),"continue restores level without a money override")
	game._apply_health_damage(10000)
	check(game.mode=="dead" and game.progress.resume_level==0,"death prevents free continue bypass")
	game.paid_revive()
	check(game.health==10 and game.level==8 and game.progress.money==450 and game.mode=="playing","paid revive costs 1000 and restores current level at 10 HP")
	game.paid_revive(); check(game.progress.money==450,"repeat revive cannot charge a living player")
	game._apply_health_damage(10000); game.paid_revive()
	check(game.health==0 and game.progress.money==450,"insufficient money cannot revive")
	game.return_to_menu(); game.start_options_unlocked=false; game.start_from_menu()
	check(game.level==1 and game.progress.money==450,"normal new run preserves earned wallet at level one")
	game.queue_free(); await process_frame
	print("CONTINUE_WALLET failures=",failures); quit(1 if failures else 0)
