extends SceneTree

const GameScript = preload("res://scripts/main.gd")
const ProgressStore = preload("res://scripts/progress_store.gd")

var game: Node3D
var collecting := false
var moving := false
var previous_tick: int = 0
var frame_ms: Array[float] = []
var process_ms: Array[float] = []
var physics_ms: Array[float] = []
var draw_calls: Array[float] = []
var movement_points: Array[Vector3] = []
var move_left := 0.0
var move_index := 0
var test_path: String

func _initialize() -> void:
	call_deferred("run_benchmark")

func run_benchmark() -> void:
	AudioServer.set_bus_mute(0, true)
	test_path = "user://test_benchmark_%s.cfg" % OS.get_process_id()
	game = GameScript.new()
	game.progress = ProgressStore.new()
	game.progress.save_path = test_path
	root.add_child(game)
	await process_frame
	game.start_run()
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.reset_at(game.world.nav.point(game.world.nav.nearest(0, 12)))
	game.player.yaw = 0.0
	game.player.pitch = -0.06
	game.player._update_rotation()
	game.health = 100000.0
	game.begin_wave()
	var offset := -1.8
	for wolf in game.wolves:
		wolf.position = game.world.wolf_nav.point(game.world.wolf_nav.nearest(game.player.position.x + offset, game.player.position.z - 7, 5))
		offset += 1.8
	for index in 12:
		var angle := float(index) / 12.0 * TAU
		movement_points.append(game.world.nav.point(game.world.nav.nearest(sin(angle) * 3, 12 + cos(angle) * 3, 2)))
	await create_timer(2.0).timeout
	var result := {"resolution": "1280x720", "adapter": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string, "wolves": game.wolves.size(), "warmup_seconds": 2, "measurement_seconds_each": 5, "player_input_disabled": true, "vsync_mode": DisplayServer.window_get_vsync_mode()}
	begin_measurement(false)
	await create_timer(5.0).timeout
	result["stationary"] = end_measurement()
	begin_measurement(true)
	await create_timer(5.0).timeout
	result["moving_target"] = end_measurement()
	result["monitor_note"] = "Wall-frame timings use a microsecond clock. Godot process/physics monitors update at a coarser cadence; process time can include frame waits."
	result["movement_note"] = "The player target changes between valid outdoor cells every 0.5 seconds; three wolves continue their actual AI and rendering."
	if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED and FileAccess.file_exists("res://qa/performance-vsync.json"):
		result["default_vsync_run"] = JSON.parse_string(FileAccess.get_file_as_string("res://qa/performance-vsync.json"))
	var output := FileAccess.open("res://qa/performance.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("BENCHMARK_COMPLETE " + JSON.stringify(result))
	game.queue_free()
	await process_frame
	for path: String in [test_path, test_path + ".bak", test_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit()

func begin_measurement(move: bool) -> void:
	frame_ms.clear()
	process_ms.clear()
	physics_ms.clear()
	draw_calls.clear()
	moving = move
	previous_tick = Time.get_ticks_usec()
	collecting = true

func end_measurement() -> Dictionary:
	collecting = false
	moving = false
	var total := 0.0
	for frame in frame_ms:
		total += frame
	return {"frames": frame_ms.size(), "mean_fps": frame_ms.size() * 1000.0 / total, "wall_frame_ms": summary(frame_ms), "cpu_process_ms": summary(process_ms), "cpu_physics_ms": summary(physics_ms), "draw_calls": summary(draw_calls)}

func summary(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	return {"median": sorted[sorted.size() / 2], "p95": sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], "max": sorted.back()}

func _process(delta: float) -> bool:
	if is_instance_valid(game) and game.started:
		# A hidden render window must keep simulating even if desktop focus changes.
		game.mode = "playing"
	if collecting:
		var now := Time.get_ticks_usec()
		frame_ms.append((now - previous_tick) / 1000.0)
		previous_tick = now
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if moving:
			move_left -= delta
			if move_left <= 0:
				game.player.position = movement_points[move_index % movement_points.size()]
				move_index += 1
				move_left = 0.5
	return false
