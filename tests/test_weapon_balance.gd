extends SceneTree
var failures := 0
var game: Node3D
const Catalog = preload("res://scripts/weapon_catalog.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func run() -> void:
	game = preload("res://scripts/main.gd").new()
	game.progress.transient = true
	game.progress.save_path = "user://balance_test_%d.cfg" % OS.get_process_id()
	root.add_child(game)
	game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1280,720)
	var highest := 0
	for i in Catalog.WEAPONS.size():
		var price: int = Catalog.weapon(i).price
		check(price == 25 if i == 20 else price > 25 and price <= 1000, "price bounds: " + str(Catalog.weapon(i).id))
		highest = maxi(highest, price)
	check(highest == 1000, "premium ceiling is exactly 1000")
	game.menu_start_level = 8; game.menu_start_money = 456
	game.hud.open_weapon_stats()
	check(game.mode == "weapon_stats", "main menu opens field guide")
	var shown: Array[int] = []
	for page in 5:
		for child in game.hud.overlay.get_children():
			if str(child.name).begins_with("WeaponStatsRow"):
				var index: int = str(child.name).trim_prefix("WeaponStatsRow").to_int()
				shown.append(index)
				check(game.hud.overlay.get_node("Stat%d_1" % index).text == str(Catalog.weapon(index).price), "guide price matches store: %d" % index)
				if Catalog.is_gun(index): check(game.hud.overlay.get_node("Stat%d_5" % index).text == "%.2f" % Catalog.weapon(index).reload, "guide uses actual reload: %d" % index)
		if OS.get_cmdline_user_args().has("--capture"):
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/weapon-guide-%d.png" % page)
		game.player.controller_button(JOY_BUTTON_DPAD_RIGHT)
	check(shown.size() == 35 and game.hud.stats_page == 0, "all 35 weapons reachable; controller paging wraps")
	game.player.controller_button(JOY_BUTTON_B)
	check(game.mode == "menu" and game.menu_start_level == 8 and game.menu_start_money == 456, "back preserves expedition settings")
	game.progress.owned.assign([0,24,25]); game.current_slot = 0; game.current_weapon = 0
	game._replenish_ammunition(); game.free_play = false; game.set_mode("playing")
	game.player.position = Vector3(150,80,140)
	for index in [24,25]:
		game._equip_slot(game.progress.owned.find(index)); game.fire_cooldown = 0
		game.fire_weapon()
		check(game.progress.owned.has(index) and game.current_ammo() == 0 and game.current_reserve() == 0, "explosive remains owned, empty after throwing: %d" % index)
		game._equip_slot(0); game._equip_slot(game.progress.owned.find(index)); game.fire_cooldown = 0
		game.reload_weapon()
		check(game.current_ammo() == 0 and game.reload_left == 0, "switching/reloading cannot replenish explosive mid-round")
		game.set_mode("shop"); game.purchase_weapon(index); game.purchase_weapon(index,true)
		check(game.progress.owned.count(index) == 1 and game.current_ammo() == 0, "store re-equip cannot duplicate/refill explosive")
		game.set_mode("playing")
	game.begin_rest()
	check(game.ammo[24] == 1 and game.ammo[25] == 1 and game.reserve_ammo[24] == 0 and game.reserve_ammo[25] == 0, "next round restores one of each explosive")
	game.ammo[24] = 0; game.ammo[25] = 0
	game.coop.wake_player(2,0,12,false,game.world.bed_wake_position,0,2)
	check(game.ammo[24] == 1 and game.ammo[25] == 1, "remote player wake also replenishes both explosives")
	game.free_play = true; game.set_mode("playing"); game._equip_slot(1); game.ammo[24] = 0; game.reload_weapon()
	check(game.ammo[24] == 1, "free play permits repeated explosive practice")
	game.queue_free(); await process_frame
	print("WEAPON_BALANCE failures=", failures)
	quit(1 if failures else 0)
