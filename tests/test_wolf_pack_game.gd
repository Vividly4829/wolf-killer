extends SceneTree

const Game = preload("res://scripts/main.gd")
const Profiles = preload("res://scripts/wolf_profile.gd")
var game: Node3D
var save_path: String
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func run_checks() -> void:
	AudioServer.set_bus_mute(0, true)
	game = Game.new()
	save_path = "user://test_wolf_pack_game_%s_%s.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	game.progress.save_path = save_path
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.start_run()
	game.intermission = false
	game.pending_spawns = 2
	game.wave_total = 2
	var small_seed := -1
	var large_seed := -1
	for number in 2000:
		var profile: Dictionary = Profiles.generate(1, number)
		if float(profile.size_scale) < 0.86:
			small_seed = number
		if bool(profile.exceptional_size) and float(profile.size_scale) > 1.18:
			large_seed = number
		if small_seed >= 0 and large_seed >= 0:
			break
	check(small_seed >= 0 and large_seed >= 0, "Reproducible ordinary-small and exceptional-large adult profiles exist")
	game._add_wolf_at(Vector3(0, 60, 0), small_seed)
	game._add_wolf_at(Vector3(0, 60, 8), large_seed)
	var small: Node3D = game.wolves[0]
	var large: Node3D = game.wolves[1]
	for wolf: Node3D in game.wolves:
		wolf.set_physics_process(false)
	check(small.is_alpha and not large.is_alpha, "A pack has one leader and leadership does not automatically go to its largest wolf")
	check(large.size_scale > small.size_scale * 1.35 and large.bite_damage > small.bite_damage * 1.35, "Rare heavy adults are visibly larger and hit substantially harder")
	check(large.max_health > small.max_health and large.get_struggle_resistance() > small.get_struggle_resistance(), "The heavy wolf is harder to wound and shake loose")

	# Actual physics hits control identification: terrain blocks it and dead
	# targets never retain a label, even before the next spotting update.
	game.player.position = Vector3(5, 60, 0)
	game.player.camera.global_position = Vector3(5, 60.6, 0)
	var body_shape: CollisionShape3D = small._hit_zones.body.get_child(0)
	game.player.camera.look_at(body_shape.global_position)
	await physics_frame
	await physics_frame
	game._update_wolf_focus()
	check(game.get_focused_wolf_text().contains("ALPHA"), "Looking at the leader identifies its social role")
	check(game.get_focused_wolf_text().contains(str(small.profile.coat_name).to_upper()), "The target label describes the actual individual coat")
	game.hud._process(0.0)
	check(game.hud.wolf_focus_label.text == game.get_focused_wolf_text(), "The live HUD presents the visible wolf identification")
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(.2, 5, 5)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	game.add_child(wall)
	wall.position = Vector3(2.5, 60.5, 0)
	await physics_frame
	await physics_frame
	game._update_wolf_focus()
	check(game.get_focused_wolf_text().is_empty(), "A solid wall prevents identifying a wolf through cover")
	wall.queue_free()
	await physics_frame
	await physics_frame
	game._update_wolf_focus()
	game.set_mode("paused")
	check(game.get_focused_wolf_text().is_empty(), "Paused menus hide target identification")
	game.set_mode("playing")

	var light_results := measure_maul(small)
	var heavy_results := measure_maul(large)
	check(heavy_results.initial > light_results.initial * 1.35, "The real initial struggle bite uses each wolf's strength")
	check(heavy_results.repeat > light_results.repeat * 1.35, "Repeated maul bites also use individual damage")
	check(is_equal_approx(float(light_results.initial), 8.0 * small.bite_damage / 14.0), "Initial damage is applied once at the configured strength")
	check(is_equal_approx(float(heavy_results.repeat), 5.5 * large.bite_damage / 14.0), "Repeated damage is applied once at the configured strength")
	check(heavy_results.escape < light_results.escape, "Holding the escape input makes less progress against the stronger wolf")
	game.set_mode("paused")
	var paused_health: float = game.health
	var paused_tick: float = game.struggle_tick
	game._process(2.0)
	check(game.health == paused_health and game.struggle_tick == paused_tick, "Pause still freezes the variable-strength maul")
	game.set_mode("playing")
	game.end_wolf_struggle(true)
	game.player.clear_injuries()
	game.health = 100.0
	var wallet: int = game.progress.money
	small.damage(10000.0)
	check(game.get_focused_wolf_text().is_empty(), "The dead leader disappears from target identification immediately")
	check(game.notice.contains("Alpha defeated") and game.progress.money == wallet + 25, "A leader kill has clear feedback and exactly the usual kill reward")
	check(game.mode == "playing" and game.wolves.size() == 1, "Leader death leaves living packmates and the wave active")
	small.damage(10000.0)
	check(game.progress.money == wallet + 25, "A dead leader cannot grant a second reward")
	large.damage(10000.0)
	check(game.mode == "resting" and game.level == 2, "The wave ends only when every surviving member is defeated")
	check(game.health == 100.0 and game.player.get_injury_summary().is_empty(), "Wave recovery clears injuries from both small and heavy wolf bites")
	game.finish_rest()
	game.player.position = game.world.exterior_rally_point
	game.begin_wave(false)
	var leaders := 0
	for wolf: Node3D in game.wolves:
		wolf.set_physics_process(false)
		leaders += int(wolf.is_alpha)
	check(game.wolves.size() == 5 and leaders == 1, "A new naturally spawned wave starts with exactly one new pack leader")

	game.queue_free()
	await process_frame
	await process_frame
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for message: String in failures:
		push_error(message)
	print("%s: %d wolf-pack game checks; %d failed." % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func measure_maul(wolf: Node3D) -> Dictionary:
	if game.is_struggling():
		game.end_wolf_struggle(false)
	game.struggle_grace = 0.0
	game.player.clear_injuries()
	game.health = 100.0
	check(game.start_wolf_struggle(wolf), "A live individual starts the real struggle callback")
	var initial: float = 100.0 - game.health
	var before_repeat: float = game.health
	game.struggle_tick = 0.01
	game._update_struggle(0.02)
	var repeated: float = before_repeat - game.health
	check(game.run_bites > 0 and game.player.bleeding_rate > 0.0, "Individual bites still inflict persistent player wounds")
	game.struggle_tick = 10.0
	game.player.clear_injuries()
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.physical_keycode = KEY_F
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	game._update_struggle(0.5)
	var progress: float = game.struggle_progress
	key = InputEventKey.new()
	key.keycode = KEY_F
	key.physical_keycode = KEY_F
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	return {"initial": initial, "repeat": repeated, "escape": progress}
