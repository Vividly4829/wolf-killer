extends SceneTree

const GameScript = preload("res://scripts/main.gd")
const ProgressStore = preload("res://scripts/progress_store.gd")
const Catalog = preload("res://scripts/weapon_catalog.gd")

var checks := 0
var failures: Array[String] = []
var test_path: String

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	test_path = "user://test_game_%s_%s.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var game = GameScript.new()
	game.progress = ProgressStore.new()
	game.progress.save_path = test_path
	root.add_child(game)
	await process_frame
	# Advance states explicitly to keep this headless test deterministic.
	game.set_process(false)
	game.player.set_physics_process(false)
	# Sound is inspected in rendered QA; rapid synthetic state changes need no voices.
	game.sounds.voices.clear()
	check(game.mode == "menu", "A fresh launch opens the menu")
	game.start_run()
	for wolf: Node3D in game.wolves:
		wolf.set_physics_process(false)
	check(game.OPENING_LINE == "Should go out and do something about these wolves." and game.dialogue_left > 3.0, "Starting a run displays the requested opening subtitle")
	check(not game.sounds.dialogue.playing, "Opening subtitle has no spoken audio")
	var dialogue_before_pause: float = game.dialogue_left
	game.set_mode("paused")
	game._process(3.0)
	check(game.dialogue_left == dialogue_before_pause, "Pausing preserves the opening subtitle timer")
	game.set_mode("playing")
	check(game.level == 1 and game.health == 100.0 and game.intermission and game.wolves.is_empty(), "A new run waits at level one inside the cabin with no wolves")
	check(game.current_weapon == 0 and game.ammo[0] == 1, "A fresh run equips a loaded single-shot musket")
	check(game.is_player_safe(), "A fresh run starts safely inside the cabin")
	game.damage_player(40)
	check(game.health == 100.0, "The cabin protects the player from damage")
	game._process(20.0)
	check(game.intermission and game.wolves.is_empty() and game.health == 100.0, "Waiting indoors does not start the first wave")
	game.begin_wave()
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	game._unhandled_input(enter)
	check(game.intermission and game.wolves.is_empty(), "Neither a manual start nor ENTER can start a wave inside the cabin")
	check(game.wolves_for_level(1) == 0 and game.wolves_for_level(3) == 0 and game.wolves_for_level(4) == 1 and game.wolves_for_level(5) == 3, "Each successive level has more wolves")
	check(game.world.nav.reachable.size() > 100, "The player has a connected area of the actual island to explore")
	game.level = 4 # Exercise wolf combat after the three introductory hunts.
	game.player.position = game.world.exterior_rally_point
	game._update_pursuit()
	check(not game.is_player_safe(), "Stepping outside leaves the safe cabin")
	game._process(0.01)
	check(game.wolves.size() == 1 and game.pending_spawns == 0 and not game.intermission, "Level four spawns one reachable wolf")
	for wolf: Node3D in game.wolves:
		wolf.set_physics_process(false)
		check(game.world.wolf_nav.distances[game.world.wolf_nav.at(wolf.position.x, wolf.position.z)] >= 0 and not game.world.is_safe_position(wolf.position), "A spawned wolf can navigate outside the safe cabin")
		var offset: Vector3 = wolf.position - game.player.position
		check(Vector2(offset.x, offset.z).length() >= 28.0, "Each wolf spawns at least 28 horizontal metres from the player")
	var pack_spacing := INF
	for i in game.wolves.size():
		for j in range(i + 1, game.wolves.size()):
			var separation: Vector3 = game.wolves[i].position - game.wolves[j].position
			pack_spacing = minf(pack_spacing, Vector2(separation.x, separation.z).length())
	check(pack_spacing >= 2.5, "The distant wolves spawn with at least 2.5 metres of spacing")
	var target: Node3D = game.wolves[0]
	var initial_wolf_position := target.position
	target.hear_gunshot(game.player.position)
	game._update_pursuit()
	for step in 360:
		target._physics_process(1.0 / 60.0)
	check(target.position.distance_to(initial_wolf_position) > 1.0, "A live wolf actually moves toward the player")
	check(game.world.wolf_nav.valid(game.world.wolf_nav.at(target.position.x, target.position.z)), "Wolf pursuit stays on the exterior navigation surface")

	# Place one real wolf in clear air so only its actual Area3D hitbox can stop the ray.
	var initial_player_position: Vector3 = game.player.position
	var initial_camera_transform: Transform3D = game.player.camera.transform
	var initial_wolf_rotation := target.rotation
	game.player.position = Vector3(4, 60, 0)
	target.position = Vector3(0, 60, -5)
	target.rotation = Vector3.ZERO
	target.max_health = 300.0
	target.health = 300.0
	# A side-on torso ray avoids the separate head/leg damage zones.
	game.player.camera.global_position = Vector3(4, 60.57, -5)
	game.player.camera.look_at(target.position + Vector3.UP * 0.57)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	await physics_frame
	game.fire_cooldown = 0.0
	game.fire_weapon()
	var health_after_shot: float = target.health
	check(game.ammo[0] == 0 and health_after_shot < 300 and not game.shot_review.reports.is_empty(), "The musket consumes one round and records its anatomical physics hit")
	game.fire_weapon()
	check(game.ammo[0] == 0 and target.health == health_after_shot, "The single-shot musket cannot fire a second round")
	game.reload_weapon()
	check(game.reload_left == 3.25 and game.player.get_reload_stage() == "POUR POWDER", "Musket loading starts a 3.25-second powder stage")
	game.fire_cooldown = 0.0
	game.fire_weapon()
	check(game.ammo[0] == 0 and target.health == health_after_shot, "The musket cannot fire while loading")
	game._process(1.0)
	check(game.ammo[0] == 0 and game.player.get_reload_stage() == "LOAD BALL", "The ball stage remains unloaded after one second")
	game._process(0.5)
	check(game.ammo[0] == 0 and game.player.get_reload_stage() == "RAM BALL", "The ramrod stage follows loading the ball")
	game._process(1.25)
	check(game.ammo[0] == 0 and game.player.get_reload_stage() == "COCK HAMMER", "Cocking the hammer happens near the end of loading")
	game._process(0.49)
	game.fire_weapon()
	check(game.ammo[0] == 0 and target.health == health_after_shot, "Even at 3.24 seconds the musket cannot fire")
	game._process(0.02)
	check(game.ammo[0] == 1 and game.reload_left == 0.0, "Only a complete 3.25-second reload grants one round")
	game.player.position = initial_player_position
	game.player.camera.transform = initial_camera_transform
	target.position = initial_wolf_position
	target.rotation = initial_wolf_rotation
	game._update_pursuit()
	var pack: Array = game.wolves.duplicate()
	for wolf: Node3D in pack:
		wolf.damage(1000.0)
		wolf.damage(1000.0)
	check(game.progress.money == 25 and game.progress.total_kills == 1 and game.run_kills == 1, "Each defeated wolf awards exactly 25 credits once")
	check(game.wolves.is_empty() and game.level == 5 and game.intermission and game.mode == "resting", "Defeating the entire pack advances to level five and starts bed rest")
	check(game.player.position.is_equal_approx(game.world.bed_position) and game.health == 100.0 and game.ammo == Catalog.full_magazines(), "Clearing the pack restores health and ammunition at the cabin bed")
	game._process(3.49)
	check(game.mode == "resting", "Bed rest lasts the full three and a half seconds")
	game._process(0.02)
	check(game.mode == "playing" and game.player.position.is_equal_approx(game.world.bed_wake_position), "Rest returns control beside the bed before outdoor preparation")
	check(game.progress.best_level == 5, "Advancing records the best level")
	game.player.position = game.world.spawn_position
	game._process(30.0)
	check(game.intermission and game.wolves.is_empty() and game.wave_countdown == 20.0, "The next-level preparation countdown pauses inside the cabin")
	game.begin_wave()
	game._unhandled_input(enter)
	check(game.intermission and game.wolves.is_empty(), "The next wave also rejects manual and ENTER starts indoors")
	game.player.position = game.world.exterior_rally_point
	game._process(5.0)
	check(game.intermission and game.wave_countdown == 15.0, "The next-level countdown advances outdoors")
	game.player.position = game.world.spawn_position
	game._process(30.0)
	check(game.intermission and game.wave_countdown == 15.0 and game.wolves.is_empty(), "Returning to shelter pauses the remaining countdown")

	var coach_price: int = Catalog.weapon(1).price
	var carbine_price: int = Catalog.weapon(2).price
	var store_budget: int = coach_price + 50
	var saved_wallet: int = coach_price + 100
	game.progress.money = store_budget
	game.progress.save_progress()
	game.purchase_weapon(1)
	check(game.progress.money == store_budget and not game.progress.owned.has(1), "Weapons can only be bought while the store is open")
	game.player.position = game.world.shop_position
	game.interact_shop()
	check(game.mode == "shop", "Interacting at the store opens it")
	game.purchase_weapon(2)
	check(game.progress.money == store_budget and not game.progress.owned.has(2), "The store refuses weapons the player cannot afford")
	game.purchase_weapon(1)
	check(game.progress.money == 50 and game.progress.owned.has(1) and game.current_weapon == 1, "Buying a shotgun spends earned money and equips it")
	game.purchase_weapon(1)
	check(game.progress.money == 50, "Selecting an owned weapon in the store does not charge twice")
	# Fund a second purchase so death must remove both paid weapon types.
	game.progress.money = carbine_price + saved_wallet
	game.purchase_weapon(2)
	check(game.progress.money == saved_wallet and game.progress.owned == [0, 1, 2] and game.current_weapon == 2, "Buying the carbine grants the second paid weapon at its normal price")
	game.close_shop()
	check(game.is_playing(), "Closing the store resumes the run")
	game.select_weapon(0)
	game.ammo[0] = 0
	var reserve_before_cancel: int = game.reserve_ammo[0]
	game.reload_weapon()
	game._process(3.0)
	game.select_weapon(1)
	game._process(5.0)
	check(game.reload_left == 0.0 and game.ammo[0] == 0 and game.reserve_ammo[0] == reserve_before_cancel, "Changing weapons cancels musket loading without granting a round or consuming reserve ammunition")
	game.select_weapon(0)
	game.reload_weapon()
	check(game.reload_left == 3.25, "Returning to the unloaded musket requires the full reload again")
	game.select_weapon(1)
	game._process(game.wave_countdown + 0.01)
	check(game.wave_total == 3 and game.wolves.size() == 3, "The next level actually spawns the larger pack")
	for wolf: Node3D in game.wolves:
		wolf.set_physics_process(false)
	game.player.position = game.world.exterior_rally_point
	var health_before_hit: float = game.health
	game.damage_player(14.0)
	check(game.health == health_before_hit - 14.0 and game.progress.owned == [0, 1, 2], "Nonfatal damage preserves both purchased weapons")
	var money_before_death: int = game.progress.money
	var best_before_death: int = game.progress.best_level
	var kills_before_death: int = game.progress.total_kills
	game.return_to_menu()
	var ordinary_save = ProgressStore.new()
	ordinary_save.save_path = test_path
	ordinary_save.load_progress()
	check(ordinary_save.money == saved_wallet and ordinary_save.owned == [0, 1, 2], "An ordinary return to the menu saves purchased weapons without confiscating them")
	# Load that save through another actual game instance to catch a blanket startup wipe.
	var reopened_game = GameScript.new()
	reopened_game.progress = ProgressStore.new()
	reopened_game.progress.save_path = test_path
	root.add_child(reopened_game)
	reopened_game.set_process(false)
	reopened_game.player.set_physics_process(false)
	reopened_game.sounds.voices.clear()
	reopened_game.start_run()
	check(reopened_game.progress.owned == [0, 1, 2] and reopened_game.progress.money == saved_wallet, "Starting a new session from a normal save retains both bought weapons")
	reopened_game.queue_free()
	await process_frame
	game.player.camera.current = true
	game.set_mode("playing")
	game.select_weapon(2)
	game.ammo[2] = 0
	game.reload_weapon()
	check(game.current_weapon == 2 and game.reload_left > 0.0, "The lethal-hit case starts while a purchased carbine is reloading")
	game.damage_player(1000.0)
	check(game.mode == "dead" and game.level == 1 and game.death_level == 5, "Losing returns the current level to one and shows the defeated level")
	check(game.progress.owned == [0] and game.current_weapon == 0 and game.player.weapon_index == 0 and game.reload_left == 0.0, "Death removes both purchased weapons, equips the musket, and cancels the reload")
	check(game.progress.money == money_before_death and game.progress.best_level == best_before_death and game.progress.total_kills == kills_before_death, "Death preserves unspent money, the best-level record, and total kills")
	var saved = ProgressStore.new()
	saved.save_path = test_path
	saved.load_progress()
	check(saved.owned == [0], "Weapon loss is saved immediately on death before retrying")
	check(saved.money == money_before_death and saved.best_level == best_before_death and saved.total_kills == kills_before_death, "The immediate death save retains the wallet and records")
	game.start_run()
	check(game.level == 1 and game.health == 100.0 and game.wolves.is_empty() and game.intermission, "Retry waits safely at level one with no wolves until the player leaves")
	check(game.progress.money == money_before_death and game.progress.owned == [0] and game.current_weapon == 0 and game.ammo[0] == 1, "Retry retains money and starts with only a loaded musket")
	game.select_weapon(1)
	check(game.current_weapon == 0 and game.player.weapon_index == 0, "The lost shotgun cannot be selected after retry")
	game.select_weapon(2)
	check(game.current_weapon == 0 and game.player.weapon_index == 0, "The lost carbine cannot be selected after retry")
	game.player.position = game.world.shop_position
	game.interact_shop()
	game.purchase_weapon(1)
	check(game.progress.owned == [0, 1] and game.current_weapon == 1 and game.progress.money == money_before_death - coach_price, "The lost shotgun can be bought again at its normal price")

	game.queue_free()
	await process_frame
	await process_frame
	for path: String in [test_path, test_path + ".bak", test_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("PASS: %s game integration checks; isolated test saves removed." % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %s of %s game integration checks failed." % [failures.size(), checks])
		quit(1)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
