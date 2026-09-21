extends SceneTree
## Native, read-only scene preview. No gameplay instance, input or save file.
## Optional: -- --scene-benchmark --preview-output=qa/surroundings-native

const World = preload("res://scripts/island_world.gd")
const VIEWS := [
	{"name": "01_west_cabin92", "eye": Vector3(-6.0, 5.7, 10.0), "target": Vector3(-64.735, 8.0, 24.325)},
	{"name": "02_north_cabin90", "eye": Vector3(-13.0, 4.9, -24.0), "target": Vector3(-50.146, 5.5, -57.473)},
	{"name": "03_north_road", "eye": Vector3(-13.0, 4.9, -24.0), "target": Vector3(-105.0, 8.0, -65.0)},
	{"name": "04_south_cabin94", "eye": Vector3(4.0, 3.6, 21.0), "target": Vector3(-4.493, 4.0, 83.514)},
	{"name": "05_northern_bridge", "eye": Vector3(12.0, 4.0, -46.0), "target": Vector3(11.0, 9.0, -174.5)},
	{"name": "07_west_cabin92_clear", "eye": Vector3(0.0, 4.0, 17.0), "target": Vector3(-64.735, 8.0, 24.325)},
]

var world: Node3D
var camera: Camera3D
var output_directory := "res://qa/surroundings-native"
var benchmark := false
var report: Dictionary = {}
var views: Array[Dictionary] = []

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		# Do not ask Windows for focus or change the user's captured mouse.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	call_deferred("run_preview")

func run_preview() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--fixed-fps"):
		push_error("Surroundings screenshots require the native renderer and real time.")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--scene-benchmark":
			benchmark = true
		elif argument.begins_with("--preview-output="):
			output_directory = argument.trim_prefix("--preview-output=")
			if not output_directory.is_absolute_path() and not output_directory.begins_with("res://"):
				output_directory = "res://" + output_directory
	root.title = "Wolf Island — Surroundings scene preview"
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	AudioServer.set_bus_mute(0, true)
	OS.low_processor_usage_mode = false
	if benchmark:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	world = World.new()
	root.add_child(world)
	if not is_instance_valid(world.surroundings):
		push_error("The separate surroundings asset must be imported before this preview runs.")
		quit(1)
		return
	camera = Camera3D.new()
	camera.near = .035
	camera.far = 900.0
	camera.fov = 78.0
	camera.current = true
	root.add_child(camera)
	report = {"kind": "scene_only_native_preview", "gameplay_benchmark": false, "adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "engine": Engine.get_version_info(), "screen_refresh_hz": DisplayServer.screen_get_refresh_rate(), "note": "Original IslandWorld plus additive visual context. No wolves, player, HUD, input automation or progress save. Optional A/B uses the same static camera and settings; it is not gameplay FPS."}
	report["protected_asset_sha256"] = {}
	for path in ["res://assets/island-realistic.glb", "res://assets/world.json", "res://assets/foliage/canopies.json", World.SURROUNDINGS_PATH]:
		report["protected_asset_sha256"][path] = FileAccess.get_sha256(path)
	var absolute := ProjectSettings.globalize_path(output_directory)
	DirAccess.make_dir_recursive_absolute(absolute)
	await create_timer(.8).timeout
	for view: Dictionary in VIEWS:
		var position := place_eye_camera(view.eye, view.target)
		await create_timer(.45).timeout
		await save_view(view.name, position)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 320.0
	camera.position = Vector3(85.0, 170.0, 190.0)
	camera.look_at(Vector3(-40.0, 0.0, -25.0))
	var atmosphere: WorldEnvironment = world.get_node("CoastalAtmosphere")
	var original_fog := atmosphere.environment.fog_enabled
	# This single diagnostic frame inspects geometric placement from above.
	# Eye-height captures and A/B measurement retain production atmosphere.
	atmosphere.environment.fog_enabled = false
	await create_timer(.45).timeout
	await save_view("06_overview", {"requested_eye": str(camera.position), "actual_eye": str(camera.position), "target": str(Vector3(-40, 0, -25)), "projection": "orthographic", "size_m": camera.size, "diagnostic_only": true, "gameplay_atmosphere": false, "fog_disabled_for_geometry_inspection": true})
	atmosphere.environment.fog_enabled = original_fog
	report["production_atmosphere_restored_before_measurement"] = atmosphere.environment.fog_enabled == original_fog
	if benchmark:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		place_eye_camera(VIEWS.back().eye, VIEWS.back().target)
		world.surroundings.visible = false
		await create_timer(.8).timeout
		var without := await sample_scene("original_island_only", 3.0)
		world.surroundings.visible = true
		await create_timer(.8).timeout
		var with_context := await sample_scene("same_view_with_surroundings", 3.0)
		report["scene_only_comparison"] = {"without_context": without, "with_context": with_context, "camera": str(camera.position), "same_settings": true}
	report["views"] = views
	report["window_has_focus"] = root.has_focus()
	report["window_no_focus_flag"] = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)
	report["window_minimized"] = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	report["window_resolution"] = str(DisplayServer.window_get_size())
	report["vsync_mode"] = DisplayServer.window_get_vsync_mode()
	var file := FileAccess.open(absolute.path_join("native-preview-report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("SURROUNDINGS_PREVIEW_COMPLETE: " + absolute)
	world.queue_free()
	camera.queue_free()
	await process_frame
	quit(0 if file != null else 1)

func place_eye_camera(requested: Vector3, target: Vector3) -> Dictionary:
	var cell: int = world.nav.at(requested.x, requested.z)
	if not world.nav.valid(cell) or world.nav.distances[cell] < 0:
		var best_distance := INF
		cell = -1
		for candidate: int in world.nav.reachable:
			var point: Vector3 = world.nav.point(candidate)
			var distance := Vector2(point.x - requested.x, point.z - requested.z).length_squared()
			if distance < best_distance:
				best_distance = distance
				cell = candidate
	var position := requested
	var floor_height: Variant = null
	if world.nav.valid(cell):
		position = world.nav.point(cell)
		floor_height = position.y
		position.y += 1.65
	camera.position = position
	camera.look_at(target)
	return {"requested_eye": str(requested), "actual_eye": str(position), "target": str(target), "eye_height_m": 1.65 if floor_height != null else null, "ground_height": floor_height, "navigation_snap_metres": Vector2(position.x - requested.x, position.z - requested.z).length(), "original_navigation_cell": cell, "camera_on_original_navigation": world.nav.valid(cell), "projection": "perspective", "fov_degrees": camera.fov}

func save_view(label: String, position: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(output_directory).path_join(label + ".png")
	var status := image.save_png(path)
	var item := position.duplicate(true)
	item.merge({"name": label, "path": path, "error": status, "pixels": [image.get_width(), image.get_height()], "fog_enabled": world.get_node("CoastalAtmosphere").environment.fog_enabled})
	views.append(item)
	print("SURROUNDINGS_VIEW: %s %s" % [label, path])

func sample_scene(label: String, seconds: float) -> Dictionary:
	var frame_ms: Array[float] = []
	var draws := 0.0
	var objects := 0.0
	var primitives := 0.0
	var process_ms := 0.0
	var start := Time.get_ticks_usec()
	var previous := start
	while (Time.get_ticks_usec() - start) / 1000000.0 < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now - previous) / 1000.0)
		previous = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var sorted := frame_ms.duplicate()
	sorted.sort()
	var total := 0.0
	var over33 := 0
	for value in frame_ms:
		total += value
		over33 += int(value > 33.0)
	var count := frame_ms.size()
	return {"name": label, "frames": count, "mean_fps": count * 1000.0 / maxf(total, .001), "p50_ms": quantile(sorted, .5), "p95_ms": quantile(sorted, .95), "p99_ms": quantile(sorted, .99), "max_ms": sorted.back(), "over33ms": over33, "draw_calls_mean": draws / count, "render_objects_mean": objects / count, "primitives_mean": primitives / count, "process_monitor_mean_ms": process_ms / count, "frame_ms": frame_ms}

func quantile(values: Array[float], fraction: float) -> float:
	var index := (values.size() - 1) * fraction
	var lower := floori(index)
	return lerpf(values[lower], values[mini(lower + 1, values.size() - 1)], index - lower)
