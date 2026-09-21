extends SceneTree
## Native, real-time performance capture. Never run with --fixed-fps or --qa.
## Example: --script res://tests/performance_playtest.gd -- --perf-output=qa/performance-720.json

const Progress = preload("res://scripts/progress_store.gd")
const Catalog = preload("res://scripts/weapon_catalog.gd")

class PerformanceGame extends "res://scripts/main.gd":
	var profile_serial := 0
	var spawn_events: Array[Dictionary] = []
	var slow_main_calls: Array[Dictionary] = []
	var manual_pause := false
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Notifications also reach the inherited script automatically. Restore
			# only its focus pause after both handlers have finished.
			call_deferred("_restore_focus_pause")
	func _restore_focus_pause() -> void:
		if mode == "paused" and not manual_pause:
			set_mode("playing")
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			if mode == "playing":
				manual_pause = true
			elif mode == "paused":
				manual_pause = false
		super._unhandled_input(event)
	func _process(delta: float) -> void:
		var before := Time.get_ticks_usec()
		super._process(delta)
		_record_slow_main("main._process", before)
	func _update_pursuit() -> void:
		var before := Time.get_ticks_usec()
		super._update_pursuit()
		_record_slow_main("main._update_pursuit", before)
	func _record_slow_main(method: String, before: int) -> void:
		var duration := (Time.get_ticks_usec() - before) / 1000.0
		if duration > 20.0:
			slow_main_calls.append({"uptime_us": before, "method": method, "duration_ms": duration, "wolves": wolves.size(), "mode": mode, "struggling": is_struggling(), "bites": run_bites})
	func _add_wolf_at(spawn: Vector3, profile_seed: int = -1) -> void:
		var before := Time.get_ticks_usec()
		var chosen_seed := profile_seed if profile_seed >= 0 else 70400 + profile_serial
		profile_serial += 1
		super._add_wolf_at(spawn, chosen_seed)
		spawn_events.append({"uptime_us": Time.get_ticks_usec(), "seed": chosen_seed, "position": str(spawn), "create_ms": (Time.get_ticks_usec() - before) / 1000.0, "active_after": wolves.size()})

var game: PerformanceGame
var started_us: int
var output_path := "res://qa/performance-playtest.json"
var save_path: String
var steady_seconds := 8.0
var warmup_seconds := 2.0
var cold_seconds := 1.5
var requested_size := Vector2i(1280, 720)
var uncapped := false
var request_foreground := false
var short_run := false
var stress_only := false
var phases: Array[Dictionary] = []
var events: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var warnings: Array[String] = []
var result: Dictionary = {}
var held_keys: Dictionary = {}
var route: Array[Vector3] = []
var route_index := 0
var last_route_index := -1
var last_shot := -100.0
var next_effect := 0.0
var next_limb := 0.0
var last_stage := -1
var last_catalog_event := -1.0
var preview_visited: Dictionary = {}
var equip_visited: Dictionary = {}
var next_catalog_index := 0
var last_monitor_us := 0
var last_counts: Dictionary = {}
var counts_snapshots: Array[Dictionary] = []
var finished := false

func _initialize() -> void:
	call_deferred("run_playtest")

func run_playtest() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--fixed-fps") or OS.get_cmdline_user_args().has("--qa"):
		push_error("Performance playtest requires native rendering and real time; --headless, --fixed-fps and --qa are unsupported.")
		quit(2)
		return
	parse_options()
	started_us = Time.get_ticks_usec()
	var low_usage_before := OS.low_processor_usage_mode
	OS.low_processor_usage_mode = false
	seed(70419)
	AudioServer.set_bus_mute(0, true)
	root.size = requested_size
	root.content_scale_size = Vector2i(1280, 720)
	if request_foreground:
		DisplayServer.window_move_to_foreground()
	if uncapped:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	create_timer(210.0).timeout.connect(timeout_cleanup)
	result = {"schema_version": 1, "started_utc": Time.get_datetime_string_from_system(true), "scenario_seed": 70419, "short_run": short_run, "requested_resolution": [requested_size.x, requested_size.y], "adapter": RenderingServer.get_video_adapter_name(), "adapter_vendor": RenderingServer.get_video_adapter_vendor(), "rendering_method": RenderingServer.get_current_rendering_method(), "engine": Engine.get_version_info(), "os": OS.get_name(), "os_version": OS.get_version(), "processor": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "vsync_mode": DisplayServer.window_get_vsync_mode(), "screen_refresh_hz": DisplayServer.screen_get_refresh_rate(), "engine_max_fps": Engine.max_fps, "measurement_seconds": steady_seconds, "warmup_seconds": warmup_seconds, "method": "Wall-clock microseconds between consecutive process-frame callbacks, native renderer, real delta time. 1% low FPS = 1000 / mean of the slowest ceil(1% of frames) frame times. Percentiles use linear interpolation. Threshold counts use strict >33/>50/>100ms.", "monitor_note": "Godot process and physics monitors are sampled once per frame but may update at coarser cadence; process time can include frame waits. These are not GPU timer measurements. Scene counts are sampled every0.5s to reduce instrumentation overhead.", "fixture_note": "Normal exploration uses real WASD/mouse-look and starts the first wave at the cabin boundary. Sustained combat uses10000 health, with ordinary damage, injuries, AI, movement and reloads. Nine/24-wolf fixtures represent gathered packs at reachable exterior points; setup costs are reported separately, not called natural spawn hitches. No player teleport occurs inside a steady-state measurement."}
	result["window_mode"] = DisplayServer.window_get_mode()
	result["window_minimized"] = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	result["window_visible"] = root.visible
	result["window_has_focus"] = root.has_focus()
	result["low_processor_usage_before"] = low_usage_before
	result["low_processor_usage_mode"] = OS.low_processor_usage_mode
	result["run_kind"] = "stress_repeat" if stress_only else "full_playtest"
	result["started_uptime_us"] = started_us
	result["source_sha256"] = {}
	result["source_sha256"]["project.godot"] = FileAccess.get_sha256("res://project.godot")
	for source in ["main.gd", "hud.gd", "player.gd", "wolf.gd", "island_world.gd", "weapon_model_builder.gd", "weapon_visual.gd"]:
		var source_path: String = "res://scripts/" + source
		if FileAccess.file_exists(source_path):
			result["source_sha256"][source] = FileAccess.get_sha256(source_path)
	var startup_tick := Time.get_ticks_usec()
	game = PerformanceGame.new()
	game.progress = Progress.new()
	save_path = "user://performance_playtest_%s_%s.cfg" % [OS.get_process_id(), startup_tick]
	game.progress.save_path = save_path
	root.add_child(game)
	game.gore._rng.seed = 70420
	record_event("instantiate_main", startup_tick)
	await window("startup_menu", "cold_transition", cold_seconds + 1.0, Callable(), startup_tick)
	result["window_resolution"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	result["viewport_resolution"] = [root.get_texture().get_size().x, root.get_texture().get_size().y]
	result["viewport_texture_reported_at_startup"] = result["viewport_resolution"].duplicate()
	var start_tick := Time.get_ticks_usec()
	game.start_run()
	record_event("start_run", start_tick)
	await window("wake_in_cabin", "cold_transition", cold_seconds, Callable(), start_tick)
	check(game.is_player_safe() and game.wolves.is_empty(), "The run starts indoors with no wolves")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check(game.mode == "playing", "Only the benchmark ignores focus loss; play remains active")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await process_frame
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check(game.mode == "paused", "A deliberate Escape pause survives benchmark focus restoration")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await process_frame
	check(game.mode == "playing", "Actual Escape input resumes the deliberate pause")
	if stress_only:
		var stress_setup_tick := Time.get_ticks_usec()
		setup_pack(24, 12, true)
		record_event("authored_24_wolf_and_corpses_setup", stress_setup_tick)
		next_effect = 0.0
		next_limb = 0.0
		await window("24_wolves_corpses_gore", "fixture_setup", cold_seconds, stress_tick, stress_setup_tick)
		await window("24_wolves_corpses_gore", "warmup", warmup_seconds, stress_tick)
		await window("24_wolves_corpses_gore", "steady", 30.0, stress_tick)
		check(game.wolves.size() == 24 and get_nodes_in_group("wolf_corpses").size() >= 10, "The long stress repeat retains24 live wolves and persistent corpses")
		await capture_frame("03_24_wolves_gore")
		finish_capture()
		return
	await window("cabin_baseline", "warmup", warmup_seconds)
	await window("cabin_baseline", "steady", steady_seconds)
	await capture_frame("01_cabin")

	route = [nav_point(-1.0, 9.0), nav_point(-5.0, 12.0), nav_point(-3.0, 9.0)]
	route_index = 0
	last_route_index = -1
	last_stage = -1
	await window("walk_out_and_explore", "cold_transition", cold_seconds + 1.0, explore_tick)
	await window("walk_out_and_explore", "steady", steady_seconds, explore_tick)
	release_controls()
	check(not game.is_player_safe() and game.wolves.size() == 3, "Actual walking starts the natural three-wolf wave")
	game.health = 10000.0
	last_shot = -100.0
	var bites_before := game.run_bites
	await window("three_wolf_combat", "cold_transition", cold_seconds, combat_tick)
	await window("three_wolf_combat", "warmup", warmup_seconds, combat_tick)
	await window("three_wolf_combat", "steady", maxf(steady_seconds, 10.0) if short_run else steady_seconds, combat_tick)
	check(game.run_bites > bites_before, "The natural pack lands actual attacks during the combat observation")
	await capture_frame("02_natural_combat")
	release_controls()

	var setup_tick := Time.get_ticks_usec()
	setup_pack(9, 4, false)
	record_event("authored_nine_wolf_setup", setup_tick)
	await window("nine_wolf_combat", "fixture_setup", cold_seconds, combat_tick, setup_tick)
	await window("nine_wolf_combat", "warmup", warmup_seconds, combat_tick)
	await window("nine_wolf_combat", "steady", steady_seconds, combat_tick)
	check(game.wolves.size() == 9, "Nine wolves remain active for the larger-pack measurement")
	release_controls()

	setup_tick = Time.get_ticks_usec()
	setup_pack(24, 12, true)
	record_event("authored_24_wolf_and_corpses_setup", setup_tick)
	next_effect = 0.0
	next_limb = 0.0
	await window("24_wolves_corpses_gore", "fixture_setup", cold_seconds, stress_tick, setup_tick)
	await window("24_wolves_corpses_gore", "warmup", warmup_seconds, stress_tick)
	await window("24_wolves_corpses_gore", "steady", steady_seconds, stress_tick)
	check(game.wolves.size() == 24 and get_nodes_in_group("wolf_corpses").size() >= 10, "The stress fixture maintains24 active wolves plus persistent corpses")
	await capture_frame("03_24_wolves_gore")
	release_controls()

	setup_tick = Time.get_ticks_usec()
	game.start_run()
	game.progress.money = 100000
	for index in Catalog.WEAPONS.size():
		if not game.progress.owned.has(index):
			game.progress.owned.append(index)
	game.progress.save_progress()
	game.player.reset_at(game.world.shop_position)
	record_event("prepare_armory_fixture", setup_tick)
	await process_frame
	await process_frame
	setup_tick = Time.get_ticks_usec()
	game.interact_shop()
	record_event("open_armory", setup_tick)
	check(game.mode == "shop", "The store opens through the actual game interaction")
	await window("armory_open", "cold_transition", cold_seconds, Callable(), setup_tick)
	next_catalog_index = 0
	last_catalog_event = -1.0
	await window("all_18_armory_previews", "cold_transition", 5.5 if short_run else 8.5, armory_tick)
	check(preview_visited.size() == 18, "Every production armory preview was created and scrolled into view")
	await window("armory_browsing", "warmup", warmup_seconds, armory_tick)
	await window("armory_browsing", "steady", steady_seconds, armory_tick)
	await capture_frame("04_armory")
	setup_tick = Time.get_ticks_usec()
	game.close_shop()
	game.player.reset_at(game.world.spawn_position)
	record_event("close_armory", setup_tick)
	await window("close_armory", "cold_transition", cold_seconds, Callable(), setup_tick)
	next_catalog_index = 0
	last_catalog_event = -1.0
	await window("all_18_equip_reload", "cold_transition", 7.5 if short_run else 12.0, equip_tick)
	check(equip_visited.size() == 18, "Every held weapon was selected and its actual reload started")
	game.select_weapon(0)
	game.ammo[0] = 0
	game.reload_weapon()
	await window("musket_reload", "warmup", warmup_seconds)
	await window("musket_reload", "steady", maxf(steady_seconds, 6.6 - warmup_seconds))
	check(game.ammo[0] == 1 and game.reload_left == 0.0, "The full musket reload completes during real-time measurement")

	setup_tick = Time.get_ticks_usec()
	setup_pack(1, 1, false)
	game.health = 40.0
	game.player.apply_injury("bleeding", 0.5)
	game.progress.money = 12345
	record_event("prepare_wave_clear_fixture", setup_tick)
	await process_frame
	await process_frame
	setup_tick = Time.get_ticks_usec()
	game.wolves[0].damage(10000.0)
	record_event("last_wolf_clear_to_bed", setup_tick)
	check(game.mode == "resting" and game.level == 2 and game.health == 100.0, "Defeating the final wolf enters bed rest and restores health")
	await window("wave_clear_bed_wake", "cold_transition", 4.1, Callable(), setup_tick)
	check(game.mode == "playing" and game.is_player_safe() and game.player.get_injury_summary().is_empty(), "Bed rest finishes inside shelter with healed injuries")
	route = [nav_point(-1.0, 9.0)]
	route_index = 0
	last_route_index = -1
	await window("walk_after_rest", "transition_control", 3.5, follow_route)
	release_controls()
	check(not game.is_player_safe(), "Actual walking leaves the bed area and reaches the exposed lawn")
	setup_tick = Time.get_ticks_usec()
	game.damage_player(10000.0)
	record_event("death_and_save", setup_tick)
	await window("death_panel", "cold_transition", cold_seconds, Callable(), setup_tick)
	check(game.mode == "dead" and game.progress.owned == [0] and game.progress.money == 12370, "Death removes paid weapons and preserves the earned wallet")
	setup_tick = Time.get_ticks_usec()
	game.start_run()
	record_event("retry", setup_tick)
	await window("retry_cabin", "cold_transition", cold_seconds, Callable(), setup_tick)
	check(game.mode == "playing" and game.health == 100.0 and game.wolves.is_empty(), "Retry returns to a clean level-one cabin")
	finish_capture()

func parse_options() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--perf-short":
			short_run = true
			steady_seconds = 3.0
			warmup_seconds = 0.8
			cold_seconds = 0.6
		elif argument == "--perf-uncapped":
			uncapped = true
		elif argument == "--perf-foreground":
			request_foreground = true
		elif argument == "--perf-stress-only":
			stress_only = true
		elif argument.begins_with("--perf-output="):
			output_path = argument.trim_prefix("--perf-output=")
			if not output_path.is_absolute_path() and not output_path.begins_with("res://") and not output_path.begins_with("user://"):
				output_path = "res://" + output_path
		elif argument.begins_with("--perf-resolution="):
			var parts := argument.trim_prefix("--perf-resolution=").split("x")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				requested_size = Vector2i(clampi(int(parts[0]), 640, 3840), clampi(int(parts[1]), 360, 2160))

func window(scenario: String, category: String, seconds: float, action: Callable = Callable(), first_tick: int = -1) -> void:
	var begin := Time.get_ticks_usec() if first_tick < 0 else first_tick
	var previous := begin
	var frame_times: Array[float] = []
	var process_times: Array[float] = []
	var physics_times: Array[float] = []
	var draw_calls: Array[float] = []
	var objects: Array[float] = []
	var primitives: Array[float] = []
	var memory: Array[float] = []
	var automation_times: Array[float] = []
	var hitch_frames: Array[Dictionary] = []
	var modes: Dictionary = {}
	var start_state := state_snapshot()
	counts_snapshots.clear()
	last_monitor_us = 0
	# Include rendered frames after synchronous setup even if setup exceeded
	# the requested window. The first interval retains that cold setup cost.
	while not finished and (frame_times.size() < 3 or (Time.get_ticks_usec() - begin) / 1000000.0 < seconds):
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now - previous) / 1000.0)
		previous = now
		if frame_times.back() > 50.0:
			hitch_frames.append({"frame_index": frame_times.size() - 1, "phase_seconds": (now - begin) / 1000000.0, "frame_ms": frame_times.back(), "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, "previous_automation_ms": automation_times.back() if not automation_times.is_empty() else 0.0, "state": state_snapshot()})
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		memory.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		modes[game.mode] = int(modes.get(game.mode, 0)) + 1
		if now - last_monitor_us >= 500000:
			last_counts = state_snapshot()
			last_counts["phase_seconds"] = (now - begin) / 1000000.0
			counts_snapshots.append(last_counts)
			last_monitor_us = now
		if action.is_valid():
			var action_started := Time.get_ticks_usec()
			action.call((now - begin) / 1000000.0)
			automation_times.append((Time.get_ticks_usec() - action_started) / 1000.0)
	var metric := frame_summary(frame_times)
	metric.merge({"scenario": scenario, "category": category, "requested_seconds": seconds, "wall_seconds": (Time.get_ticks_usec() - begin) / 1000000.0, "start_state": start_state, "end_state": state_snapshot(), "mode_frame_counts": modes, "process_ms": numeric_summary(process_times), "physics_ms": numeric_summary(physics_times), "draw_calls": numeric_summary(draw_calls), "render_objects": numeric_summary(objects), "primitives": numeric_summary(primitives), "static_memory_mib": numeric_summary(memory), "scene_samples": counts_snapshots.duplicate(true), "frame_ms": frame_times})
	metric["hitch_frames"] = hitch_frames
	metric["automation_callback_ms"] = numeric_summary(automation_times)
	phases.append(metric)
	print("PERF_PHASE %s/%s fps=%.1f p95=%.2f p99=%.2f max=%.2f wolves=%d" % [scenario, category, float(metric.mean_fps), float(metric.p95_ms), float(metric.p99_ms), float(metric.max_ms), game.wolves.size()])

func explore_tick(elapsed: float) -> void:
	var stage := int(elapsed / 2.5)
	if stage != last_stage:
		last_stage = stage
		key(KEY_A, false)
		key(KEY_D, false)
	if fmod(elapsed, 5.0) > 3.8:
		key(KEY_W, false)
		key(KEY_D, true)
		mouse_turn(0.005, 0.0)
	else:
		key(KEY_D, false)
		follow_route(elapsed)

func follow_route(_elapsed: float) -> void:
	if game.mode != "playing" or route.is_empty():
		key(KEY_W, false)
		return
	if route_index >= route.size():
		key(KEY_W, false)
		return
	var goal := route[route_index]
	var offset: Vector3 = goal - game.player.position
	offset.y = 0.0
	if offset.length() < 0.35:
		route_index += 1
		last_route_index = -1
		return
	if last_route_index != route_index:
		var tick := Time.get_ticks_usec()
		game.world.nav.field(goal.x, goal.z)
		record_event("controller_route_field", tick)
		last_route_index = route_index
	var next: Vector3 = game.world.nav.next_point(game.player.position.x, game.player.position.z)
	if not next.is_finite():
		key(KEY_W, false)
		return
	var direction := next - game.player.position
	if direction.length_squared() < 0.01:
		direction = offset
	look_toward(atan2(-direction.x, -direction.z), -0.08, 0.18)
	key(KEY_W, true)

func combat_tick(_elapsed: float) -> void:
	if game.mode != "playing":
		return
	key(KEY_F, true)
	var time := (Time.get_ticks_usec() - started_us) / 1000000.0
	key(KEY_W, false)
	key(KEY_A, fmod(time, 5.0) < 1.0)
	key(KEY_D, fmod(time, 5.0) > 2.5 and fmod(time, 5.0) < 3.5)
	if game.is_struggling():
		return
	var nearest: Node3D = null
	var distance := INF
	for wolf: Node3D in game.wolves:
		var away: float = wolf.position.distance_squared_to(game.player.position)
		if away < distance:
			distance = away
			nearest = wolf
	if nearest:
		var aim: Vector3 = nearest.position + Vector3.UP * 0.7 - game.player.camera.global_position
		look_toward(atan2(-aim.x, -aim.z), atan2(aim.y, Vector2(aim.x, aim.z).length()), 0.11)
	if time - last_shot >= 8.0 and game.reload_left <= 0.0:
		last_shot = time
		# Real input shoots above the pack so population remains comparable.
		look_toward(game.player.yaw, 1.2, 3.0)
		click()
		key(KEY_R, true)
		key(KEY_R, false)

func stress_tick(elapsed: float) -> void:
	combat_tick(elapsed)
	var time := (Time.get_ticks_usec() - started_us) / 1000000.0
	if time >= next_effect:
		next_effect = time + 0.25
		var point: Vector3 = game.player.position + Vector3(sin(time) * 2.0, 0.55, cos(time) * 2.0)
		game.gore.blood_burst(point, Vector3.UP, 1.2)
		game.gore.blood_pool(point - Vector3.UP * 0.5, 0.20)
	if time >= next_limb:
		next_limb = time + 0.8
		game.gore.severed_limb(game.player.position + Vector3(1.0, 0.7, 1.0), Vector3.RIGHT, Color("514334"), 1.0)

func armory_tick(elapsed: float) -> void:
	if game.mode != "shop":
		return
	if elapsed < last_catalog_event:
		last_catalog_event = -1.0
	if elapsed - last_catalog_event < (0.20 if short_run else 0.36):
		return
	last_catalog_event = elapsed
	var index := next_catalog_index % Catalog.WEAPONS.size()
	next_catalog_index += 1
	var tick := Time.get_ticks_usec()
	game.hud._select_shop_weapon(index)
	if is_instance_valid(game.hud.shop_scroll):
		game.hud.shop_scroll.scroll_vertical = maxi(0, index * 69 - 140)
	preview_visited[index] = true
	record_event("armory_preview_%02d" % index, tick)

func equip_tick(elapsed: float) -> void:
	if elapsed < last_catalog_event:
		last_catalog_event = -1.0
	if elapsed - last_catalog_event < (0.30 if short_run else 0.60):
		return
	last_catalog_event = elapsed
	var index := next_catalog_index % Catalog.WEAPONS.size()
	next_catalog_index += 1
	var tick := Time.get_ticks_usec()
	game.select_weapon(index)
	game.ammo[index] = 0
	game.reload_weapon()
	equip_visited[index] = true
	record_event("equip_reload_%02d" % index, tick)

func setup_pack(count: int, wave_level: int, with_corpses: bool) -> void:
	release_controls()
	game.start_run()
	game.health = 10000.0
	game.level = wave_level
	game.intermission = false
	game.wave_total = count
	game.pending_spawns = 1
	game.player.reset_at(nav_point(-3.0, 13.0))
	if with_corpses:
		for index in 12:
			game.pending_spawns += 1
			var location: Vector3 = fixture_position(index, 12, 5.0, 6.5)
			game._add_wolf_at(location)
			game.wolves.back().damage(10000.0)
	for index in count:
		game.pending_spawns += 1
		var location: Vector3 = fixture_position(index, count, 7.0, 15.0)
		game._add_wolf_at(location)
	game.pending_spawns = 0
	for wolf: Node3D in game.wolves:
		wolf.hear_gunshot(game.player.position)
	game._update_pursuit()
	last_shot = -100.0
	game.player.yaw = 0.0
	game.player.pitch = -0.08
	game.player._update_rotation()

func fixture_position(index: int, total: int, inner: float, outer: float) -> Vector3:
	var angle := TAU * float(index) / maxf(1.0, total)
	var radius := lerpf(inner, outer, float(index % 3) / 2.0)
	var candidate: Vector3 = game.player.position + Vector3(cos(angle), 0, sin(angle)) * radius
	var cell: int = game.world.wolf_nav.nearest(candidate.x, candidate.z, 7.0)
	return game.world.wolf_nav.point(cell)

func nav_point(x: float, z: float) -> Vector3:
	return game.world.nav.point(game.world.nav.nearest(x, z, 4.0))

func look_toward(target_yaw: float, target_pitch: float, limit: float) -> void:
	mouse_turn(clampf(wrapf(target_yaw - game.player.yaw, -PI, PI), -limit, limit), clampf(target_pitch - game.player.pitch, -limit, limit))

func mouse_turn(yaw_delta: float, pitch_delta: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-yaw_delta / game.player.sensitivity, -pitch_delta / game.player.sensitivity)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key, down: bool) -> void:
	if bool(held_keys.get(code, false)) == down:
		return
	held_keys[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click() -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func release_controls() -> void:
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_F, KEY_R, KEY_SHIFT, KEY_CTRL, KEY_SPACE]:
		key(code, false)

func record_event(name: String, before: int) -> void:
	events.append({"name": name, "seconds": (Time.get_ticks_usec() - started_us) / 1000000.0, "synchronous_ms": (Time.get_ticks_usec() - before) / 1000.0, "mode": game.mode if is_instance_valid(game) else "initializing"})

func capture_frame(label: String) -> void:
	# GPU readback and PNG compression are deliberately outside timed windows.
	await RenderingServer.frame_post_draw
	var before := Time.get_ticks_usec()
	var directory := ProjectSettings.globalize_path(output_path.get_basename() + "-images")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(label + ".png")
	var frame_image := root.get_texture().get_image()
	var error := frame_image.save_png(path)
	var pixels := [frame_image.get_width(), frame_image.get_height()]
	result["viewport_resolution"] = pixels
	result["resolution_note"] = "viewport_resolution records actual pixels returned by native viewport image capture. viewport_texture_reported_at_startup preserves the initial get_size API reading before later captures."
	screenshots.append({"label": label, "path": path, "error": error, "rendered_image_pixels": pixels, "reported_texture_size": str(root.get_texture().get_size()), "root_size": str(root.size), "content_scale_size": str(root.content_scale_size), "content_scale_factor": root.content_scale_factor, "scaling_3d_scale": root.scaling_3d_scale, "state": state_snapshot()})
	record_event("untimed_screenshot_" + label, before)

func state_snapshot() -> Dictionary:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return {}
	return {"mode": game.mode, "wolves": game.wolves.size(), "pending_spawns": game.pending_spawns, "corpses": get_nodes_in_group("wolf_corpses").size(), "bolts": get_nodes_in_group("player_bolts").size(), "gore": game.gore.effect_counts(), "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "physics_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), "physics_collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), "player_position": str(game.player.position), "player_health": game.health, "bites": game.run_bites, "struggling": game.is_struggling(), "safe": game.is_player_safe(), "reload_left": game.reload_left, "window_has_focus": root.has_focus(), "window_mode": DisplayServer.window_get_mode(), "window_minimized": DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED, "window_visible": root.visible, "vsync_mode": DisplayServer.window_get_vsync_mode(), "engine_max_fps": Engine.max_fps, "low_processor_usage_mode": OS.low_processor_usage_mode}

func frame_summary(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"frames": 0, "mean_fps": 0.0, "p50_ms": 0.0, "p95_ms": 0.0, "p99_ms": 0.0, "max_ms": 0.0, "one_percent_low_fps": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	var over33 := 0
	var over50 := 0
	var over100 := 0
	for value in values:
		total += value
		over33 += int(value > 33.0)
		over50 += int(value > 50.0)
		over100 += int(value > 100.0)
	var slow_count := maxi(1, ceili(values.size() * 0.01))
	var slow_total := 0.0
	for index in range(sorted.size() - slow_count, sorted.size()):
		slow_total += sorted[index]
	return {"frames": values.size(), "mean_fps": values.size() * 1000.0 / maxf(total, 0.001), "p50_ms": percentile(sorted, 0.50), "p95_ms": percentile(sorted, 0.95), "p99_ms": percentile(sorted, 0.99), "max_ms": sorted.back(), "one_percent_low_fps": 1000.0 * slow_count / maxf(slow_total, 0.001), "over_33ms": over33, "over_50ms": over50, "over_100ms": over100, "total_frame_ms": total}

func numeric_summary(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values:
		total += value
	return {"mean": total / values.size(), "p50": percentile(sorted, 0.5), "p95": percentile(sorted, 0.95), "max": sorted.back()}

func percentile(sorted: Array[float], quantile: float) -> float:
	var position := clampf(quantile, 0.0, 1.0) * (sorted.size() - 1)
	var lower := int(floor(position))
	var upper := mini(sorted.size() - 1, lower + 1)
	return lerpf(sorted[lower], sorted[upper], position - lower)

func check(condition: bool, message: String) -> void:
	checks.append({"passed": condition, "description": message})
	if not condition:
		warnings.append(message)
		print("PERF_CHECK_FAILED " + message)

func finish_capture(timed_out: bool = false) -> void:
	if finished:
		return
	finished = true
	release_controls()
	result["elapsed_seconds"] = (Time.get_ticks_usec() - started_us) / 1000000.0
	result["timed_out"] = timed_out
	result["phases"] = phases
	result["events"] = events
	result["screenshots"] = screenshots
	result["checks"] = checks
	result["warnings"] = warnings
	result["valid_behavior_run"] = warnings.is_empty() and not timed_out
	result["spawn_events"] = game.spawn_events if is_instance_valid(game) else []
	result["slow_main_calls"] = game.slow_main_calls if is_instance_valid(game) else []
	result["preview_ids_visited"] = preview_visited.keys()
	result["held_weapon_ids_visited"] = equip_visited.keys()
	var absolute := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	if is_instance_valid(game):
		game.queue_free()
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PERFORMANCE_PLAYTEST_COMPLETE path=%s phases=%d warnings=%d elapsed=%.2fs" % [absolute, phases.size(), warnings.size(), float(result.elapsed_seconds)])
	quit(2 if timed_out or file == null else (0 if warnings.is_empty() else 1))

func timeout_cleanup() -> void:
	warnings.append("Benchmark exceeded its210-second watchdog")
	finish_capture(true)
