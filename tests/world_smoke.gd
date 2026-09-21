extends SceneTree
## Run: Godot --headless --path godot --script res://tests/world_smoke.gd
## Optional graphical verification: omit --headless and pass -- --capture.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var world := IslandWorld.new()
	root.add_child(world)
	await process_frame
	var nav := world.nav
	_check(nav.reachable.size() > 40000, "Island should retain over 40,000 reachable navigation cells.")
	_check(nav.valid(nav.at(world.spawn_position.x, world.spawn_position.z)), "Player spawn must be walkable.")
	_check(world.is_safe_position(world.spawn_position), "Player must start inside the safe cabin.")
	var bed_cell := nav.at(world.bed_position.x, world.bed_position.z)
	_check(nav.valid(bed_cell) and nav.distances[bed_cell] >= 0, "Recovery bed must have a walkable aisle connected to the exit.")
	_check(world.is_safe_position(world.bed_position), "Recovery position must remain inside the safe cabin.")
	var wake_cell := nav.at(world.bed_wake_position.x, world.bed_wake_position.z)
	_check(nav.valid(wake_cell) and nav.distances[wake_cell] >= 0, "Standing wake point must connect to the cabin exit.")
	_check(world.is_safe_position(world.bed_wake_position), "Standing wake point must remain inside the cabin.")
	var wake_forward := Vector3(-sin(world.bed_wake_yaw), 0, -cos(world.bed_wake_yaw))
	var wake_ahead: Vector3 = world.bed_wake_position + wake_forward * .75
	_check(nav.line_clear(world.bed_wake_position.x, world.bed_wake_position.z, wake_ahead.x, wake_ahead.z), "Waking must face clear walking space instead of the bunk.")
	_check(world.has_node("RecoveryBed/Mattress"), "Recovery bed must have a visible mattress.")
	var smoke := world.get_node("ChimneySmoke") as MultiMeshInstance3D
	_check(smoke.multimesh.instance_count == 18, "Animated chimney smoke must use a fixed number of puffs.")
	_check(smoke.position.distance_to(Vector3(1.17718, 7.105, .40941)) < .01, "Smoke must start at the actual masonry chimney cap.")
	_check(nav.line_clear(world.spawn_position.x, world.spawn_position.z, -.75, 5.6), "Player must have an unobstructed walk from spawn through the open exit.")
	_check(not world.is_safe_position(Vector3(-.5, 3.75, 5.3)), "Outside terrace must not be a safe zone.")
	_check(not world.is_safe_position(Vector3(-8.75, 3.85, .25)), "The store is outside the cabin safe zone.")
	_check(not world.is_safe_position(Vector3(-3.0, 3.85, -1.5)), "The concave cabin footprint must not include its outdoor bounding-box corner.")
	_check(not world.is_safe_position(Vector3(-.75, 7.8, 2.0)), "The cabin roof must not count as the safe interior.")
	var wolf_nav := world.wolf_nav
	_check(not wolf_nav.valid(wolf_nav.at(world.spawn_position.x, world.spawn_position.z)), "Wolves must be unable to enter the cabin spawn.")
	_check(not wolf_nav.line_clear(world.exterior_rally_point.x, world.exterior_rally_point.z, world.spawn_position.x, world.spawn_position.z), "Wolf pathfinding must never cross the cabin doorway.")
	_check(wolf_nav.valid(wolf_nav.at(world.exterior_rally_point.x, world.exterior_rally_point.z)), "The outside wolf rally point must be walkable.")
	_check(wolf_nav.reachable.size() > 39000, "Wolves must retain access to the rest of the island.")
	var unsafe_wolf_cells := 0
	for i in wolf_nav.reachable:
		if world.is_safe_position(wolf_nav.point(i)):
			unsafe_wolf_cells += 1
	_check(unsafe_wolf_cells == 0, "No reachable wolf cell may enter the safe house.")
	_check(not nav.valid(nav.at(world.shop_position.x, world.shop_position.z)), "Store counter must block movement.")
	var approach := world.shop_position + Vector3(0, 0, 1.6)
	_check(nav.distances[nav.at(approach.x, approach.z)] >= 0, "Player must be able to reach the armory.")
	var into_counter := nav.move_position(approach, 0, -2.5)
	_check(into_counter.z > world.shop_position.z + .75, "Moving into the counter must stop at its edge.")
	for room: Dictionary in world.world_data.rooms:
		var position_data: Array = room.navigationPoint
		var cell := nav.nearest(float(position_data[0]), float(position_data[2]), .5)
		_check(cell >= 0 and nav.distances[cell] >= 0, "Room must remain accessible: " + str(room.name))
	# The expanded map includes mainland at (-100,-100). Use the open sound.
	_check(not nav.line_clear(80, 40, 85, 45), "Navigation must reject open water.")
	_check(is_nan(nav.height_at(80, 40)), "Open-water height must be invalid.")
	_check(world.find_children("*", "StaticBody3D", true, false).size() > 40, "Island architecture needs bullet collision.")
	var exit_point: Vector3 = nav.point(nav.nearest(-.75, 5.6, 1.0))
	nav.field(exit_point.x, exit_point.z)
	var walking: Vector3 = world.bed_wake_position
	for step in 500:
		if walking.distance_to(exit_point) < .2:
			break
		var next: Vector3 = nav.next_point(walking.x, walking.z)
		if not next.is_finite():
			break
		var delta: Vector3 = next - walking
		delta.y = 0.0
		delta = delta.limit_length(.09)
		walking = nav.move_position(walking, delta.x, delta.z)
	_check(walking.distance_to(exit_point) < .2, "Standing wake point must permit an actual navigation walk through the cabin exit.")
	nav.field(world.spawn_position.x, world.spawn_position.z)
	var gore := preload("res://scripts/gore_effects.gd").new()
	root.add_child(gore)
	gore.set_process(false)
	await physics_frame
	for i in 24:
		gore.severed_limb(Vector3(0, 4.6, 9), Vector3.FORWARD)
	for i in 110:
		gore.blood_pool(Vector3(0, 3.75, 9), .2)
	_check(gore.effect_counts() == {"droplets": 160, "pools": 96, "limbs": 18}, "Combat effect populations must stay within their hard caps.")
	for i in 2020:
		gore._process(.05)
	_check(gore.effect_counts() == {"droplets": 0, "pools": 0, "limbs": 0}, "Combat effects must expire without retaining live records.")
	gore.blood_burst(Vector3(0, 4.6, 9), Vector3.FORWARD)
	gore.blood_pool(Vector3(0, 3.75, 9))
	gore.severed_limb(Vector3(0, 4.6, 9), Vector3.FORWARD)
	gore.clear()
	await process_frame
	_check(gore.get_child_count() == 0, "Clearing a wave must free all effect nodes.")
	print("WORLD_SMOKE: reachable=%d, wolf_reachable=%d, safe_wolf_cells=%d, rooms=%d, spawn=%s, yaw=%.3f, rally=%s, failures=%d" % [nav.reachable.size(), wolf_nav.reachable.size(), unsafe_wolf_cells, world.world_data.rooms.size(), world.spawn_position, world.spawn_yaw, world.exterior_rally_point, failures])
	if "--capture" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(0.0, 4.95, 12.0)
		camera.look_at(world.shop_position + Vector3(3.0, 1.1, -3.0))
		camera.current = true
		await create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		screenshot.save_png("res://qa/world_preview.png")
		print("WORLD_PREVIEW: res://qa/world_preview.png")
		camera.position = Vector3(10.0, 5.6, 17.0)
		camera.look_at(Vector3(-1.0, 7.3, 0.0))
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/moonlit_cabin_preview.png")
		camera.position = world.spawn_position + Vector3(0, 1.65, 0)
		camera.rotation = Vector3(0, world.spawn_yaw, 0)
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/shelter_preview.png")
		camera.position = world.bed_position + Vector3(0, .85, 0)
		camera.rotation = Vector3(-.12, world.bed_yaw, 0)
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/bed_preview.png")
		camera.position = world.bed_wake_position + Vector3(0, 1.65, 0)
		camera.rotation = Vector3(-.04, world.bed_wake_yaw, 0)
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/bed_wake_preview.png")
		var blood_ground := Vector3(-.5, nav.height_at(-.5, 9), 9)
		gore.blood_pool(blood_ground, .45)
		gore.severed_limb(blood_ground + Vector3.UP * .7, Vector3(.2, 0, -.1))
		for i in 50:
			gore._process(.04)
		camera.position = blood_ground + Vector3(1.4, 1.7, 2.1)
		camera.look_at(blood_ground)
		gore.blood_burst(blood_ground + Vector3.UP * .4, Vector3.UP, 1.5)
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/gore_preview.png")
	gore.queue_free()
	world.queue_free()
	await process_frame
	quit(failures)
