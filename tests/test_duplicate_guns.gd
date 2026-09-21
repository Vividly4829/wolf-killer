extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var catalog=preload("res://scripts/weapon_catalog.gd")
	for index in catalog.WEAPONS.size():
		var expected: float=float(catalog.WEAPONS[index].reload)/(3.0 if catalog.is_gun(index) else 1.0)
		check(is_equal_approx(catalog.weapon(index).reload,expected),"correct reload scaling: "+catalog.WEAPONS[index].name)
	check(is_equal_approx(catalog.secondary_weapon().reload,8.5/3),"LeMat secondary reload is also three times faster")
	var game=preload("res://scripts/main.gd").new(); game.progress.save_path="user://copies_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_run(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	game.progress.money=10000; game.set_mode("shop")
	game.purchase_weapon(6); game.purchase_weapon(6,true)
	check(game.progress.owned==[0,6,6] and game.progress.money==9600,"two purchases create two guns and charge twice")
	check(game.current_slot==2 and game.current_ammo()==6,"new copy is equipped and loaded")
	game.close_shop(); game.select_owned_slot(1); game.ammo[6]=1; game.select_owned_slot(2)
	check(game.current_ammo()==6,"second copy does not inherit first copy's spent rounds")
	game.ammo[6]=4; game.cycle_weapon(-1)
	check(game.current_slot==1 and game.current_ammo()==1,"cycling returns to first copy with its remaining round")
	game.cycle_weapon(1); check(game.current_slot==2 and game.current_ammo()==4,"cycling retains the second magazine too")
	check("COPY 2 OF 2" in game.weapon_display_name(),"HUD identifies the equipped copy")
	game.reserve_ammo[6]=18
	check(game.ammo_refill_cost()==int(catalog.weapon(6).reserve)*int(catalog.weapon(6).ammo_cost),"shared ammo refill is not charged twice for duplicate designs")
	game.reserve_ammo[6]=18; game.ammo[6]=0; game.reload_weapon()
	check(is_equal_approx(game.reload_left,14.0/3),"actual reload timer uses the faster gun reload")
	game.select_owned_slot(1); check(game.reload_left==0 and game.current_ammo()==1,"changing copies cancels reload without refilling the other copy")
	game.set_mode("shop"); game.purchase_weapon(9); game.purchase_weapon(9,true)
	game.close_shop(); game.select_owned_slot(3); game.lemat_shot_ammo=0; game.select_owned_slot(4)
	check(game.lemat_shot_ammo==1,"each LeMat has its own loaded secondary barrel")
	game.select_owned_slot(3); check(game.lemat_shot_ammo==0,"empty LeMat secondary stays empty after switching")
	var restored=preload("res://scripts/progress_store.gd").new(); restored.save_path=game.progress.save_path; restored.load_progress()
	check(restored.owned==game.progress.owned,"saved inventory preserves duplicate guns")
	game.set_mode("shop"); game.hud._select_shop_weapon(6)
	check(game.hud._shop_buttons.another.visible and not game.hud._shop_buttons.another.disabled,"store exposes Buy Another for owned guns")
	check(game.hud._shop_stat_labels[2].text=="4.7 seconds","store displays the new reload duration")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(.3).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/duplicate-guns-store.png")
	game.close_shop(); game._replenish_ammunition(); game.select_owned_slot(1)
	check(game.current_ammo()==6,"bed refresh replenishes every gun copy")
	var wolf=game.WolfScript.new(); wolf.configure(game,game.world.wolf_nav,5,112); game.add_child(wolf); wolf.make_werewolf(); wolf.set_physics_process(false)
	var report: Dictionary=wolf.receive_ballistic_hit(1,wolf.to_global(Vector3(.48,1.1,0)),Vector3.RIGHT,"body",0)
	check(report.species=="werewolf" and not "FRIENDLY FIRE" in report.zone,"werewolf non-vital X-ray never says friendly fire")
	game.player.position=Vector3(0,80,0); var money: int=game.progress.money; game.damage_player(100000)
	check(game.progress.owned==[0] and game.progress.money==money,"death removes duplicate guns but preserves credits")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; await process_frame
	print("DUPLICATE_GUNS failures=",failures); quit(1 if failures else 0)
