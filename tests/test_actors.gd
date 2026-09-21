extends SceneTree

## Focused actor regressions on a small navigation fixture, without saving a game.
const PlayerScript = preload("res://scripts/player.gd")
const WolfScript = preload("res://scripts/wolf.gd")
const NavScript = preload("res://scripts/island_nav.gd")
const WorldScript = preload("res://scripts/island_world.gd")

class SoundSpy extends Node:
	var growls: int = 0
	func play_at(kind: String, _point: Vector3, _volume: float, _individual_pitch: float = 1.0) -> void:
		if kind == "growl":
			growls += 1

class WorldStub extends Node3D:
	var exterior_rally_point := Vector3(-2.0, 3.25, 0.0)
	var nav: RefCounted

class ActorGame extends Node3D:
	var player: Node3D
	var sounds: SoundSpy
	var world: Node3D
	var safe: bool = false
	var reload_left: float = 0.0
	var health: float = 100.0
	var simulated_time: float = 0.0
	var first_bite_time: float = -1.0
	var death_time: float = -1.0
	var playing: bool = true
	var bite_damage: float = 0.0
	var defeats: int = 0
	var reloads: int = 0
	var selected: int = 0
	func is_playing() -> bool:
		return playing
	func is_player_safe() -> bool:
		return safe or (world.has_method("is_safe_position") and bool(world.call("is_safe_position", player.position)))
	func damage_player(amount: float) -> void:
		bite_damage += amount
		if first_bite_time < 0.0:
			first_bite_time = simulated_time
		health = maxf(0.0, health - amount)
		if health <= 0.0 and death_time < 0.0:
			death_time = simulated_time
	func wolf_defeated(_wolf: Node3D) -> void:
		defeats += 1
	func fire_weapon() -> void:
		pass
	func reload_weapon() -> void:
		reloads += 1
	func select_weapon(index: int) -> void:
		selected = index
	func select_owned_slot(index: int) -> void:
		selected = index
	func interact_shop() -> void:
		pass

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func make_navigation(wall: bool) -> RefCounted:
	var grid: Dictionary = {"width": 21, "depth": 21, "cellSize": 0.5, "origin": [-5.0, -5.0], "heights": [], "blocked": []}
	for z: int in range(21):
		for x: int in range(21):
			grid.heights.append(3.25)
			grid.blocked.append(1 if x == 0 or z == 0 or x == 20 or z == 20 or (wall and x == 10 and z >= 5 and z <= 15) else 0)
	var navigation := NavScript.new()
	navigation.setup(grid)
	return navigation

func key_event(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func hold_key(code: Key, pressed: bool) -> void:
	Input.parse_input_event(key_event(code, pressed))
	Input.flush_buffered_events()

func run_checks() -> void:
	var game := ActorGame.new()
	root.add_child(game)
	game.sounds = SoundSpy.new()
	game.add_child(game.sounds)
	game.world = WorldStub.new()
	game.add_child(game.world)
	var navigation := make_navigation(true)
	var player := PlayerScript.new()
	game.player = player
	game.add_child(player)
	player.configure(game, navigation)
	player.set_physics_process(false)
	player.reset_at(Vector3(-2.0, 3.25, 0.0))
	check(is_equal_approx(player.camera.position.y, 1.65), "The FPS eye rests 1.65 m above the player's feet")
	hold_key(KEY_D, true)
	for frame: int in range(120):
		player._physics_process(1.0 / 60.0)
	hold_key(KEY_D, false)
	check(player.position.x > -1.0 and player.position.x <= -0.24, "D moves the player right but the grid wall stops their feet (x=%.3f)" % player.position.x)
	check(is_equal_approx(player.position.y, 3.25), "Ground movement stays anchored to the sampled terrain")
	player.reset_at(Vector3(-2.0, 3.25, 0.0))
	var peak: float = player.position.y
	for jump_number: int in range(20):
		player._unhandled_input(key_event(KEY_SPACE, true))
		for frame: int in range(90):
			player._physics_process(1.0 / 60.0)
			peak = maxf(peak, player.position.y)
	check(peak > 3.8 and peak < 4.35, "Jumping rises by about one metre, without accumulating terrain height")
	check(is_equal_approx(player.position.y, 3.25) and is_zero_approx(player._jump_height), "Twenty repeated jumps land at the original ground height")
	game.playing = false
	hold_key(KEY_W, true)
	var paused_position: Vector3 = player.position
	player._physics_process(0.25)
	check(player.position == paused_position, "Player movement is frozen while the game is paused")
	hold_key(KEY_W, false)
	game.playing = true
	player._unhandled_input(key_event(KEY_R, true))
	player._unhandled_input(key_event(KEY_3, true))
	check(game.reloads == 1 and game.selected == 2, "Reload and weapon-selection input reaches game logic")
	player.play_reload(1.2)
	game.reload_left = 0.6
	player._physics_process(0.6)
	check(player.weapon.position.y < -0.35, "The weapon visibly lowers during the reload interval")
	game.reload_left = 0.0
	player._physics_process(0.7)
	check(is_zero_approx(player._reload_time), "The reload animation finishes")
	run_reload_movement_checks(game, player)
	for weapon_index: int in range(3):
		player.set_weapon(weapon_index)
		player.play_shot()
		check(player.weapon.get("_flash_mesh").visible, "Weapon %d has a visible muzzle flash when fired" % weapon_index)
	player.reset_at(Vector3(-0.5, 3.25, 0.0))
	navigation.call("field", player.position.x, player.position.z)
	var wolf := WolfScript.new()
	wolf.configure(game, navigation, 1, 8141)
	game.add_child(wolf)
	wolf.position = Vector3(0.5, 3.25, 0.0)
	wolf.set_physics_process(false)
	wolf.rng.seed = 8141
	alert_for_combat(wolf, player.position)
	wolf.warned = true
	wolf._warning_until = 0.0
	wolf._attack_cooldown = 0.0
	wolf._enter_state("charge", 3.0)
	wolf._physics_process(1.0 / 60.0)
	check(is_zero_approx(game.bite_damage), "A nearby wolf cannot bite through the grid wall")
	check(wolf.position.is_finite(), "Blocked pursuit keeps the wolf position finite")
	check(wolf.charge_speed > 5.0 and is_equal_approx(wolf.charge_speed, float(wolf.profile.charge_speed)), "An individual wolf's charge can catch a walking player and uses its generated speed")
	var open_navigation := make_navigation(false)
	wolf.nav = open_navigation
	open_navigation.call("field", player.position.x, player.position.z)
	wolf.position = Vector3(3.5, 3.25, 0.0)
	wolf._enter_state("approach", 0.0)
	var initial_distance: float = wolf.position.distance_to(player.position)
	for frame: int in range(360):
		wolf._physics_process(1.0 / 60.0)
	check(wolf.position.distance_to(Vector3(3.5, 3.25, 0.0)) > 1.0, "An unobstructed wolf approaches or circles rather than remaining frozen")
	check(wolf.position.is_finite() and initial_distance > 0.0, "Varied pursuit keeps the wolf on finite navigation coordinates")
	game.bite_damage = 0.0
	wolf.position = Vector3(0.5, 3.25, 0.0)
	wolf._velocity = Vector3.ZERO
	wolf.warned = false
	wolf._warning_until = INF
	wolf._attack_cooldown = 0.0
	wolf._last_growl = -99.0
	wolf._enter_state("observe", 0.2)
	var growls_before: int = game.sounds.growls
	wolf._physics_process(0.1)
	check(is_zero_approx(game.bite_damage) and not wolf.warned, "An unprovoked nearby wolf observes before attacking")
	wolf._physics_process(0.2)
	check(wolf.behavior == "warn" and wolf.warned and game.sounds.growls == growls_before + 1, "The first threat produces a spatial growl and a visible warning state")
	for frame: int in range(34):
		wolf._physics_process(1.0 / 60.0)
	check(is_zero_approx(game.bite_damage) and not wolf._can_bite(player.position), "The first growl grants a readable 0.65-second reaction interval")
	wolf._time = wolf._warning_until + 0.1
	wolf.position = Vector3(0.5, 3.25, 0.0)
	wolf._velocity = Vector3.ZERO
	wolf._attack_cooldown = 0.0
	wolf._enter_state("charge", 2.0)
	wolf._physics_process(1.0 / 60.0)
	var damage_after_bite: float = game.bite_damage
	check(is_equal_approx(damage_after_bite, wolf.bite_damage), "A warned wolf in unobstructed biting range applies its individual bite damage once")
	check(wolf.behavior == "retreat", "The wolf pulls back after landing a bite")
	wolf._physics_process(1.0 / 60.0)
	check(is_equal_approx(game.bite_damage, damage_after_bite), "A bite cooldown prevents damage on every physics frame")
	game.playing = false
	wolf._attack_cooldown = 0.0
	wolf._physics_process(1.0)
	check(is_equal_approx(game.bite_damage, damage_after_bite), "Pausing also stops wolf attacks")
	game.playing = true
	wolf.position = Vector3(0.5, 3.25, 0.0)
	wolf._attack_cooldown = 0.0
	player.position.y = 4.6
	check(not wolf._can_bite(player.position), "A wolf cannot bite a player more than one metre above its feet")
	player.position.y = 3.25
	var barrier := StaticBody3D.new()
	barrier.collision_layer = 1
	var barrier_shape := CollisionShape3D.new()
	var barrier_box := BoxShape3D.new()
	barrier_box.size = Vector3(0.18, 2.0, 1.5)
	barrier_shape.shape = barrier_box
	barrier.add_child(barrier_shape)
	game.add_child(barrier)
	barrier.position = Vector3(0.0, 4.0, 0.0)
	await physics_frame
	await physics_frame
	check(not wolf._can_bite(player.position), "A solid physical barrier also blocks a bite when the navigation grid is open")
	wolf._sight_timer = 0.0
	wolf._update_perception(player, 0.2)
	game.reload_left = 6.5
	check(not wolf._has_visual_contact and wolf._visible_opportunity(player.position) == 0.0, "A player behind a physical barrier creates no visual opportunity even while reloading")
	game.reload_left = 0.0
	barrier.queue_free()
	await process_frame
	await physics_frame
	game.safe = true
	wolf._enter_state("charge", 2.0)
	wolf._physics_process(0.1)
	check(wolf.behavior == "circle" and not wolf._can_bite(player.position), "Entering the safe cabin cancels a charge and prevents damage")
	check(is_equal_approx(game.bite_damage, damage_after_bite), "The safe player receives no bite damage")
	game.safe = false
	var outcomes: Dictionary = {}
	var prior_warning_until: float = wolf._warning_until
	for sample: int in range(40):
		wolf.rng.seed = sample + 30
		wolf._shot_cooldown = 0.0
		wolf._last_flinch = -99.0
		wolf.hear_gunshot(player.position)
		outcomes[wolf.behavior] = true
	check(outcomes.has("retreat") and outcomes.has("recover"), "Musket reports cause varied brief recoil or hesitation rather than perpetual pursuit resets")
	check(is_equal_approx(wolf._warning_until, prior_warning_until), "Repeated gunfire cannot restart an alert wolf's warning grace indefinitely")
	wolf._time = wolf._warning_until + 0.1
	wolf._attack_cooldown = 0.0
	wolf._aggression = 0.0
	wolf._commit_wait = 0.0
	wolf.role = "distract"
	alert_for_combat(wolf, player.position)
	var solo: Array[Node3D] = [wolf]
	var choices: Dictionary = {}
	for sample: int in range(40):
		wolf.rng.seed = sample + 400
		wolf._pack.next_commit = 0.0
		wolf._choose_attack(solo)
		choices[wolf.behavior] = true
	check(choices.has("circle") and choices.has("charge"), "A warned wolf varies between circling and direct attack")
	wolf._pack.next_commit = 0.0
	wolf._commit_wait = 1.9
	wolf._choose_attack(solo)
	check(wolf.behavior == "charge", "A brief circling decision is followed by a guaranteed commitment when a charge slot is free")
	var pack: Array[Node3D] = [wolf]
	for index: int in range(5):
		var packmate := WolfScript.new()
		packmate.configure(game, open_navigation, 1, 8200 + index)
		game.add_child(packmate)
		packmate.position = Vector3(2.0, 3.25, float(index) - 2.0)
		packmate.set_physics_process(false)
		packmate.warned = true
		packmate._warning_until = 0.0
		alert_for_combat(packmate, player.position)
		packmate.rng.seed = index + 321
		pack.append(packmate)
	for member: Node3D in pack:
		member.call("_enter_state", "circle", 2.0)
	var slot_positions: Dictionary = {}
	for member: Node3D in pack:
		var goal: Vector3 = member.call("_circle_goal", Vector3(0.0, 3.25, 0.0), pack)
		slot_positions[Vector2(goal.x, goal.z)] = true
	check(slot_positions.size() >= 4, "Pack members spread pressure across several distinct flank positions")
	var stable_flank: Vector3 = wolf._circle_goal(Vector3(0.0, 3.25, 0.0), pack)
	wolf._time += 20.0
	wolf._orbit_timer = 0.0
	check(wolf._circle_goal(Vector3(0.0, 3.25, 0.0), pack) == stable_flank, "Passing time does not mechanically rotate a wolf's flanking position around stationary prey")
	wolf._pack.next_commit = 0.0
	for member: Node3D in pack:
		member.set("_commit_wait", 2.0)
		member.call("_choose_attack", pack)
	var chargers: int = 0
	for member: Node3D in pack:
		chargers += int(str(member.get("behavior")) == "charge")
	check(chargers == 1, "The shared launch delay prevents a same-frame pack-wide charge")
	var first_launch: float = float(wolf._pack.clock)
	wolf._pack.clock = float(wolf._pack.next_commit) + 0.01
	for member: Node3D in pack:
		if str(member.get("behavior")) != "charge":
			member.set("_commit_wait", 2.0)
			member.call("_choose_attack", pack)
	chargers = 0
	var second_launch: float = first_launch
	for member: Node3D in pack:
		chargers += int(str(member.get("behavior")) == "charge")
		second_launch = maxf(second_launch, float(member.get("last_charge_at")))
	check(chargers == 2 and second_launch - first_launch >= 0.75, "A second wolf can rush after the stagger interval while simultaneous attackers remain capped at two")
	for member: Node3D in pack:
		if member != wolf:
			member.free()
	check(wolf._skeleton != null and wolf._joints.has("FrontLeg1_L"), "The imported wolf skeleton exposes the animated leg joints")
	wolf.damage(10000.0)
	wolf.damage(10000.0)
	check(game.defeats == 1 and wolf.dead and is_zero_approx(wolf.health), "Repeated damage awards defeat exactly once")
	check(not wolf.is_in_group("wolves"), "A defeated wolf immediately leaves the active pack")
	wolf._physics_process(2.0)
	check(is_equal_approx(game.bite_damage, damage_after_bite), "A defeated wolf cannot attack during its death animation")
	await process_frame
	check(wolf._hit_area.collision_layer == 0, "Defeated wolves stop intercepting bullets")
	var fresh_wolf := WolfScript.new()
	fresh_wolf.configure(game, open_navigation, 1, 8300)
	game.add_child(fresh_wolf)
	fresh_wolf.set_physics_process(false)
	check(fresh_wolf.pack_slot == 0 and fresh_wolf.get_pack_debug().clock == 0.0 and fresh_wolf.get_pack_debug().next_commit == 0.0, "A new pack on a reused game starts without an old clock or charge cooldown")
	fresh_wolf._pack.clock = 50.0
	fresh_wolf._pack.next_commit = 51.0
	fresh_wolf.queue_free()
	var replacement := WolfScript.new()
	replacement.configure(game, open_navigation, 1, 8301)
	game.add_child(replacement)
	replacement.set_physics_process(false)
	check(replacement.pack_slot == 0 and replacement.get_pack_debug().clock == 0.0 and replacement.get_pack_debug().members == 1, "Queued wolves from a previous run do not keep stale pack metadata alive")
	game.queue_free()
	await process_frame
	await process_frame
	await run_island_simulation()
	if failures.is_empty():
		print("PASS: %d focused actor checks; no save files touched." % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("FAIL: %d of %d actor checks failed." % [failures.size(), checks])
		quit(1)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func alert_for_combat(wolf: Node3D, known_position: Vector3) -> void:
	# These fixtures isolate bite geometry and charge coordination. Stealth,
	# awareness gain and losing a trail have their own hunting regressions.
	wolf.awareness = 1.0
	wolf.alerted = true
	wolf.last_known_position = known_position
	wolf._last_cue_at = wolf._time

func run_reload_movement_checks(game: ActorGame, player: Node3D) -> void:
	for weapon_index: int in range(3):
		game.reload_left = 0.0
		player.set_weapon(weapon_index)
		player.reset_at(Vector3(-2.0, 3.25, 1.0))
		player.yaw = 0.0
		hold_key(KEY_W, true)
		hold_key(KEY_SHIFT, true)
		for frame: int in range(12):
			player._physics_process(1.0 / 60.0)
		check(player._velocity.length() > 1.0, "Weapon %d reload test starts with real sprinting input and existing velocity" % weapon_index)
		var previous_velocity: Vector2 = player._velocity
		game.reload_left = 1.5
		player.play_reload(1.5)
		var planted: Vector3 = player.position
		var stamina_before: float = player.stamina
		if weapon_index == 0:
			check(player._velocity == Vector2.ZERO, "Musket reload immediately cancels horizontal momentum")
			hold_key(KEY_W, false)
			for movement_key: Key in [KEY_W, KEY_A, KEY_S, KEY_D]:
				hold_key(movement_key, true)
				hold_key(KEY_SPACE, true)
				for frame: int in range(8):
					player._physics_process(1.0 / 60.0)
				hold_key(KEY_SPACE, false)
				hold_key(movement_key, false)
			check(player.position == planted and player._velocity == Vector2.ZERO, "Musket reload ignores held WASD, sprint and jump without drifting")
			check(player.stamina >= stamina_before, "Musket reload does not drain stamina from held sprint")
			check(is_zero_approx(player._jump_height) and is_zero_approx(player._jump_velocity), "A jump cannot start during musket reload")
		else:
			check(player._velocity == previous_velocity, "Weapon %d preserves existing momentum when reload starts" % weapon_index)
			for frame: int in range(8):
				player._physics_process(1.0 / 60.0)
			check(player.position.z < planted.z and player._velocity.length() >= previous_velocity.length(), "Weapon %d continues held sprinting during reload" % weapon_index)
			check(player.stamina < stamina_before, "Weapon %d reload retains normal sprint stamina use" % weapon_index)
			hold_key(KEY_W, false)
			hold_key(KEY_SHIFT, false)
			var walk_directions: Dictionary = {KEY_W: Vector3.FORWARD, KEY_A: Vector3.LEFT, KEY_S: Vector3.BACK, KEY_D: Vector3.RIGHT}
			for movement_key: Key in [KEY_W, KEY_A, KEY_S, KEY_D]:
				player.reset_at(Vector3(-2.0, 3.25, 0.0))
				var walk_start: Vector3 = player.position
				hold_key(movement_key, true)
				for frame: int in range(8):
					player._physics_process(1.0 / 60.0)
				hold_key(movement_key, false)
				check((player.position - walk_start).dot(walk_directions[movement_key]) > 0.1, "Weapon %d allows held %s walking during reload" % [weapon_index, OS.get_keycode_string(movement_key)])
			player.reset_at(Vector3(-2.0, 3.25, 0.0))
			hold_key(KEY_SPACE, true)
			player._physics_process(1.0 / 60.0)
			hold_key(KEY_SPACE, false)
			check(player._jump_height > 0.0 and player._jump_velocity > 0.0, "Weapon %d can start a jump during reload" % weapon_index)
		game.reload_left = 0.75
		player._physics_process(1.0 / 60.0)
		check(player._reload_time > 0.0 and player.weapon.rotation.length() > 0.1, "Weapon %d reload animation remains active with its intended movement behavior" % weapon_index)
		game.reload_left = 0.0
		var before_completion_move: Vector3 = player.position
		hold_key(KEY_W, true)
		player._physics_process(1.0 / 60.0)
		check(player.position.z < before_completion_move.z and player._velocity.length() > 0.0, "Weapon %d accepts held movement as soon as reload completes" % weapon_index)
		hold_key(KEY_W, false)
		hold_key(KEY_SHIFT, false)
	# A midair musket reload stops horizontal travel without freezing vertical motion.
	player.set_weapon(0)
	player.reset_at(Vector3(-2.0, 3.25, 0.0))
	player._unhandled_input(key_event(KEY_SPACE, true))
	player._physics_process(0.15)
	check(player.weapon_index == 0 and player._jump_height > 0.4, "The airborne musket reload regression begins during an actual jump")
	game.reload_left = 1.5
	player.play_reload(1.5)
	var airborne_position: Vector3 = player.position
	hold_key(KEY_D, true)
	for frame: int in range(90):
		player._physics_process(1.0 / 60.0)
	hold_key(KEY_D, false)
	check(is_equal_approx(player.position.y, 3.25) and is_zero_approx(player._jump_height), "Gravity lands an airborne player while musket reload continues")
	check(is_equal_approx(player.position.x, airborne_position.x) and is_equal_approx(player.position.z, airborne_position.z), "Musket reload prevents horizontal travel throughout the fall")
	# Mouse motion uses the normal captured-input path even while feet are locked.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var previous_yaw: float = player.yaw
	var previous_pitch: float = player.pitch
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(30.0, 12.0)
	player._unhandled_input(look)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		check(player.yaw != previous_yaw and player.pitch != previous_pitch, "Mouse look remains responsive during reload")
	else:
		print("SKIP: Headless display cannot capture the mouse; reload leaves the existing mouse-motion handler active.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Selecting another weapon cancels the authoritative game timer; no extra
	# controller timer should keep the player locked after the cancellation.
	game.reload_left = 0.0
	player.set_weapon(1)
	player.yaw = 0.0
	var before_cancel_move: Vector3 = player.position
	hold_key(KEY_W, true)
	player._physics_process(1.0 / 60.0)
	hold_key(KEY_W, false)
	check(player.weapon_index == 1 and player.position.z < before_cancel_move.z, "Switching from the loading musket to the shotgun cancels the lock and immediately restores movement")
	player._unhandled_input(key_event(KEY_SPACE, true))
	player._physics_process(1.0 / 60.0)
	check(player._jump_height > 0.0, "Jumping is available again once reload has been cancelled")
	game.reload_left = 0.0
	player.reset_at(Vector3(-2.0, 3.25, 0.0))
	player.yaw = 0.0
	player.pitch = -0.04

func run_island_simulation() -> void:
	# The real terrain, fence collision and exterior-only grid catch problems that
	# an empty navigation fixture cannot. A stationary survivor records damage
	# without ending the run; no wallet, HUD or save store is created.
	var game := ActorGame.new()
	root.add_child(game)
	game.sounds = SoundSpy.new()
	game.add_child(game.sounds)
	game.world = WorldScript.new()
	game.add_child(game.world)
	game.player = Node3D.new()
	game.add_child(game.player)
	await physics_frame
	await physics_frame
	var navigation: RefCounted = game.world.get("wolf_nav")
	var scenarios: Array[Dictionary] = [
		{"name": "southern lawn", "point": Vector2(-3.0, 13.0), "seed": 5000},
		{"name": "northern clearing", "point": Vector2(10.0, -24.0), "seed": 6000}
	]
	for scenario: Dictionary in scenarios:
		var desired: Vector2 = scenario.point
		game.player.position = navigation.call("point", navigation.call("nearest", desired.x, desired.y, 4.0))
		navigation.call("field", game.player.position.x, game.player.position.z)
		check(game.player.position.is_finite() and not game.is_player_safe(), "%s simulation places the player on outdoor ground" % scenario.name)
		var pack: Array[Node3D] = []
		var distances := PackedFloat32Array()
		distances.resize(6)
		distances.fill(0.0)
		for slot: int in range(6):
			var angle: float = float(slot) / 6.0 * TAU
			var desired_spawn := game.player.position + Vector3(cos(angle), 0.0, sin(angle)) * 9.0
			var spawn_id: int = int(navigation.call("nearest", desired_spawn.x, desired_spawn.z, 7.0))
			var wolf := WolfScript.new()
			wolf.configure(game, navigation, 1, int(scenario.seed) + slot)
			game.add_child(wolf)
			wolf.set_physics_process(false)
			wolf.position = navigation.call("point", spawn_id)
			wolf.rng.seed = int(scenario.seed) + slot
			wolf._boldness = 0.4 + float(slot) * 0.07
			wolf._circle_radius = 4.8 + float(slot) * 0.2
			wolf._enter_state("observe", 0.4 + float(slot) * 0.14)
			pack.append(wolf)
		var seen: Dictionary = {}
		var invalid_cells: int = 0
		var maximum_chargers: int = 0
		game.bite_damage = 0.0
		game.sounds.growls = 0
		for step: int in range(1350):
			var chargers: int = 0
			for index: int in range(pack.size()):
				var wolf: Node3D = pack[index]
				var previous: Vector3 = wolf.position
				wolf.call("_physics_process", 1.0 / 30.0)
				seen[str(wolf.get("behavior"))] = true
				chargers += int(str(wolf.get("behavior")) == "charge")
				distances[index] += previous.distance_to(wolf.position)
				var cell: int = int(navigation.call("at", wolf.position.x, wolf.position.z))
				if not wolf.position.is_finite() or not bool(navigation.call("valid", cell)) or game.world.call("is_safe_position", wolf.position):
					invalid_cells += 1
			maximum_chargers = maxi(maximum_chargers, chargers)
		var moving_wolves: int = 0
		for traveled: float in distances:
			moving_wolves += int(traveled > 5.0)
		print("ISLAND_PACK_SIM %s player=%s simulated=45s states=%s damage=%.0f growls=%d invalid_cells=%d max_chargers=%d travel=%s" % [scenario.name, game.player.position, str(seen.keys()), game.bite_damage, game.sounds.growls, invalid_cells, maximum_chargers, str(distances)])
		check(seen.has("warn") and seen.has("circle") and seen.has("charge") and seen.has("retreat"), "%s pack naturally warns, circles, charges and retreats" % scenario.name)
		check(game.bite_damage > 0.0 and game.sounds.growls > 0, "%s wolves reach and bite the player after warning" % scenario.name)
		check(invalid_cells == 0, "%s wolves stay on valid exterior cells for all 45 simulated seconds" % scenario.name)
		check(moving_wolves >= 5 and maximum_chargers <= 2, "%s pack moves around obstacles while preserving the simultaneous attack limit" % scenario.name)
		for wolf: Node3D in pack:
			wolf.free()
	await run_doorway_encounters(game, navigation)
	game.queue_free()
	await process_frame
	await process_frame

func run_doorway_encounters(game: ActorGame, navigation: RefCounted) -> void:
	# Real physics frames synchronize moving hitboxes with the actual cabin,
	# terrace railing and island collider. In particular, the exterior cabin
	# exclusion strip is NOT shelter, even though wolves cannot walk onto it.
	var scenarios: Array[Dictionary] = [
		{"name": "doorway exclusion strip", "point": Vector2(-1.0, 4.5), "excluded": true},
		{"name": "terrace", "point": Vector2(-0.25, 6.0), "excluded": false},
		{"name": "east cabin perimeter", "point": Vector2(1.0, 4.25), "excluded": true}
	]
	var player_nav: RefCounted = game.world.get("nav")
	for scenario: Dictionary in scenarios:
		var point: Vector2 = scenario.point
		var target: Vector3 = player_nav.call("point", player_nav.call("at", point.x, point.y))
		game.player.position = game.world.get("spawn_position")
		var rally: Vector3 = game.world.get("exterior_rally_point")
		navigation.call("field", rally.x, rally.z)
		game.bite_damage = 0.0
		game.health = 100.0
		game.first_bite_time = -1.0
		game.death_time = -1.0
		game.sounds.growls = 0
		var pack: Array[Node3D] = []
		var anchors: Array[Vector2] = [Vector2(-2.0, 12.5), Vector2(2.75, 12.0), Vector2(0.25, 16.0)]
		for slot: int in range(3):
			var anchor: Vector2 = anchors[slot]
			var wolf := WolfScript.new()
			wolf.configure(game, navigation, 1, 9210 + slot)
			game.add_child(wolf)
			wolf.set_physics_process(false)
			wolf.position = navigation.call("point", navigation.call("nearest", anchor.x, anchor.y, 4.0))
			wolf.rng.seed = 9210 + slot
			wolf._safe_growl_left = 0.4 + slot * 0.2
			wolf._circle_radius = 3.2 + slot * 0.25
			pack.append(wolf)
		for step: int in range(120):
			for wolf: Node3D in pack:
				wolf.call("_physics_process", 1.0 / 30.0)
			await physics_frame
		check(game.bite_damage == 0.0 and game.sounds.growls >= 1, "%s pack audibly warns outside while the occupied cabin stays safe" % scenario.name)
		game.player.position = target
		navigation.call("field", target.x, target.z)
		check(not game.is_player_safe() and bool(player_nav.call("valid", player_nav.call("at", target.x, target.z))), "%s is exposed and walkable by the player" % scenario.name)
		if bool(scenario.excluded):
			check(not bool(navigation.call("valid", navigation.call("at", target.x, target.z))), "%s reproduces a player-valid but wolf-invalid cell" % scenario.name)
		var invalid: int = 0
		var states: Dictionary = {}
		var bites: Array[float] = []
		for step: int in range(900):
			game.simulated_time = float(step) / 30.0
			if step % 8 == 0:
				navigation.call("field", target.x, target.z)
			var damage_before: float = game.bite_damage
			for wolf: Node3D in pack:
				wolf.call("_physics_process", 1.0 / 30.0)
				states[str(wolf.get("behavior"))] = true
				if not navigation.call("valid", navigation.call("at", wolf.position.x, wolf.position.z)) or game.world.call("is_safe_position", wolf.position):
					invalid += 1
			if game.bite_damage > damage_before:
				bites.append(game.simulated_time)
			await physics_frame
			if game.death_time >= 0.0:
				break
		print("REAL_PHYSICS_ENCOUNTER %s target=%s first_bite=%.2fs death=%.2fs damage=%.0f invalid=%d states=%s bites=%s" % [scenario.name, target, game.first_bite_time, game.death_time, game.bite_damage, invalid, str(states.keys()), str(bites)])
		check(game.first_bite_time >= 0.0 and game.first_bite_time <= 8.0, "%s wolves land their first bite within eight seconds of exposure" % scenario.name)
		check(game.death_time >= 12.0 and game.death_time <= 25.0, "%s stationary survivor loses within the intended threat window" % scenario.name)
		check(invalid == 0, "%s wolves attack without entering the cabin or its movement exclusion strip" % scenario.name)
		for wolf: Node3D in pack:
			wolf.free()
		await physics_frame
