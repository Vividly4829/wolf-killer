extends SceneTree

const ProgressStore = preload("res://scripts/progress_store.gd")
# Observe the real spawn method immediately after it returns; no positions change.
class EncounterGame extends "res://scripts/main.gd":
	var spawn_observations: Array[Dictionary] = []
	var profile_serial := 0
	func _add_wolf_at(spawn: Vector3, profile_seed: int = -1) -> void:
		# Global seed() does not seed each wolf's private profile RNG.
		var chosen_seed := 37127 + profile_serial * 137 if profile_seed < 0 else profile_seed
		profile_serial += 1
		super._add_wolf_at(spawn, chosen_seed)
	func _spawn_wolf() -> void:
		var before := wolves.size()
		super._spawn_wolf()
		if wolves.size() > before:
			var newborn: Node3D = wolves.back()
			var offset: Vector3 = newborn.position - player.position
			var observation := {"horizontal_distance": Vector2(offset.x, offset.z).length(), "position": str(newborn.position), "player_position": str(player.position), "pack_size_after": wolves.size()}
			if before > 0:
				var spacing := INF
				for i in before:
					var away: Vector3 = newborn.position - wolves[i].position
					spacing = minf(spacing, Vector2(away.x, away.z).length())
				observation["nearest_packmate_m"] = spacing
			spawn_observations.append(observation)

var game: Node3D
var checks := 0
var failures: Array[String] = []
var test_path: String
var simulation_time := 0.0
var exposed_at := -1.0
var first_bite_at := -1.0
var died_at := -1.0
var previous_health := 100.0
var previous_bite_count := 0
var bites: Array[Dictionary] = []
var cabin_breach := false
var track_encounter := false
var observed_charge_serials: Dictionary = {}
var charge_events: Array[Dictionary] = []
var maximum_chargers := 0
var minimum_other_wolf_charge_gap := INF
var last_charger_id: int = -1
var last_charge_time := -1.0

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	AudioServer.set_bus_mute(0, true)
	seed(37127)
	test_path = "user://test_encounter_%s.cfg" % OS.get_process_id()
	game = EncounterGame.new()
	game.progress = ProgressStore.new()
	game.progress.save_path = test_path
	root.add_child(game)
	await physics_frame
	game.start_run()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await step_frames(2)
	check(game.wolves.is_empty() and game.intermission, "The first wave waits with zero wolves while the player is indoors")
	check(game.is_player_safe(), "The player starts inside the safe cabin")
	game.begin_wave()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	enter = enter.duplicate()
	enter.pressed = false
	Input.parse_input_event(enter)
	await step_frames(2)
	check(game.wolves.is_empty() and game.intermission, "Manual calls and the actual ENTER key cannot bypass shelter gating")
	track_encounter = true
	await step_frames(1800)
	check(game.health == 100.0 and game.mode == "playing", "Thirty seconds inside the cabin causes no damage")
	check(game.wolves.is_empty() and game.intermission and game.spawn_observations.is_empty(), "Thirty seconds inside does not spawn or start any wave")

	# Use the actual controller and sampled path through the real doorway.
	# No wolves, player position, health or AI timers are teleported/overridden here.
	var lawn: Vector3 = game.world.nav.point(game.world.nav.nearest(-1.0, 9.0, 3.0))
	var walked: bool = await walk_to(lawn, 12.0)
	check(walked, "W input moves the player from the cabin through the doorway onto the lawn")
	check(not game.is_player_safe(), "The lawn is exposed")
	check(game.wolves.size() == 3 and game.spawn_observations.size() == 3 and not game.intermission, "Leaving the cabin automatically starts exactly three wolves without ENTER")
	check_spawn_distances(game.spawn_observations)
	fire_signal_shot()
	var deadline := simulation_time + 52.0
	while game.mode == "playing" and simulation_time < deadline:
		await step_frames(1)
	check(first_bite_at >= 0.0 and first_bite_at - exposed_at <= 25.0, "A distant natural wolf approaches and bites within twenty-five seconds after exit")
	check(died_at >= 0.0, "An exposed stationary player can actually be killed by the natural pack")
	if died_at >= 0.0:
		check(died_at - first_bite_at <= 30.0 and bites.size() >= 3, "Repeated mauling and bleeding defeat an undefended player within thirty seconds of contact")
	check(game.level == 1 and game.mode == "dead", "Natural combat death returns the run to level one")
	# An undefended victim remains pinned: repeated bites need no new charges.
	check_charge_coordination(1, false)

	var report := {"spawns": game.spawn_observations.duplicate(true), "exposed_at": exposed_at, "first_bite_after_exit_seconds": first_bite_at - exposed_at if first_bite_at >= 0 else -1, "death_after_exit_seconds": died_at - exposed_at if died_at >= 0 else -1, "player_final_position": str(game.player.position), "bites": bites.duplicate(true), "coordination": coordination_snapshot(), "wolves": wolf_snapshot()}

	# A second natural pack must bite just outside the door, where wolves cannot walk.
	# This catches the old exterior immunity strip caused by using wolf-only LOS.
	track_encounter = false
	game.start_run()
	game.spawn_observations.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await step_frames(2)
	check(game.wolves.is_empty() and game.intermission, "Retry again waits for the player to leave shelter")
	exposed_at = -1
	first_bite_at = -1
	died_at = -1
	previous_health = 100
	previous_bite_count = 0
	bites = []
	observed_charge_serials.clear()
	charge_events.clear()
	maximum_chargers = 0
	minimum_other_wolf_charge_gap = INF
	last_charger_id = -1
	last_charge_time = -1.0
	track_encounter = true
	var threshold: Vector3 = game.world.nav.point(game.world.nav.nearest(-1.0, 4.5, 0.5))
	check(await walk_to(threshold, 10.0), "The controller can stop immediately outside the real doorway")
	await step_frames(25)
	var threshold_position: Vector3 = game.player.position
	check(not game.is_player_safe() and not game.world.wolf_nav.valid(game.world.wolf_nav.at(threshold_position.x, threshold_position.z)), "The doorway test stands in the exposed 0.8 m wolf-exclusion band")
	fire_signal_shot()
	deadline = simulation_time + 27.0
	while first_bite_at < 0.0 and simulation_time < deadline:
		await step_frames(1)
	check(first_bite_at >= 0 and first_bite_at - exposed_at <= 25.0, "Distant wolves can approach and bite an exposed player just outside the doorway")
	check_spawn_distances(game.spawn_observations)
	report["doorway"] = {"spawns": game.spawn_observations.duplicate(true), "position": str(threshold_position), "first_bite_after_exit_seconds": first_bite_at - exposed_at if first_bite_at >= 0 else -1, "health_after_bite": game.health, "wolves": wolf_snapshot()}

	# Increase health only after proving real damage, then test fleeing and re-engagement.
	if first_bite_at >= 0:
		game.health = 10000
		previous_health = 10000
		set_key(KEY_F, true)
		deadline = simulation_time + 6.0
		while game.is_struggling() and simulation_time < deadline:
			await step_frames(1)
		check(not game.is_struggling(), "Holding the actual F key releases the wolf before fleeing")
		var bites_before_flee := bites.size()
		var flee_goal: Vector3 = game.world.nav.point(game.world.nav.nearest(-5.0, 9.0, 2.0))
		check(await walk_to(flee_goal, 20.0), "The injured player can flee to another reachable lawn position while fighting off catches")
		var stopped_at := simulation_time
		deadline = simulation_time + 12.0
		while bites.size() < bites_before_flee + 2 and simulation_time < deadline:
			await step_frames(1)
		check(bites.size() >= bites_before_flee + 2, "The pack follows the changed target and attacks repeatedly instead of circling forever")
		var reengage_delay := -1.0
		if bites.size() > bites_before_flee:
			reengage_delay = maxf(0.0, float(bites[bites_before_flee].seconds_after_exit) + exposed_at - stopped_at)
		check(reengage_delay >= 0 and reengage_delay <= 8.0, "Wolves resume biting within eight seconds after the fleeing player stops")
		report["flee"] = {"position": str(game.player.position), "bite_delay_after_stopping_seconds": reengage_delay, "subsequent_bites": bites.size() - bites_before_flee, "wolves": wolf_snapshot()}
		# Firearm hit zones and packmate-loss reactions have separate focused fixtures.
		check(await walk_to(game.world.spawn_position, 30.0), "The actual controller can return from the pursued lawn into the cabin")
		await step_frames(30)
		set_key(KEY_F, false)
		check(game.is_player_safe(), "Returning through the doorway restores shelter protection")
		var sheltered_health: float = game.health
		var sheltered_bites: int = game.run_bites
		await step_frames(60)
		check(game.health < sheltered_health and game.run_bites == sheltered_bites, "Existing bleeding continues indoors without new wolf bites")
		set_key(KEY_B, true)
		set_key(KEY_B, false)
		await step_frames(150)
		check(game.player.bleeding_rate == 0.0 and game.bandages == 1, "Actual B input completes a bandage and stops bleeding inside shelter")
		sheltered_health = game.health
		await step_frames(600)
		check(game.health == sheltered_health and game.run_bites == sheltered_bites and not cabin_breach, "Ten seconds inside after bandaging prevents damage and wolves remain outside")
		report["return_to_shelter"] = {"position": str(game.player.position), "health_before_wait": sheltered_health, "health_after_wait": game.health, "wolves": wolf_snapshot()}
		check_charge_coordination()
		report["second_pack_coordination"] = coordination_snapshot()
	report["checks"] = checks
	report["failures"] = failures
	var output := FileAccess.open("res://qa/encounter.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	track_encounter = false
	set_forward(false)
	set_key(KEY_F, false)
	game.queue_free()
	await process_frame
	await process_frame
	for path: String in [test_path, test_path + ".bak", test_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for failure in failures:
		push_error(failure)
	print("%s: %d real-physics encounter checks. %s" % ["PASS" if failures.is_empty() else "FAIL", checks, JSON.stringify(report)])
	quit(0 if failures.is_empty() else 1)

func step_frames(count: int) -> void:
	for frame in count:
		await physics_frame
		simulation_time += 1.0 / 60.0
		if not track_encounter:
			continue
		if exposed_at < 0.0 and not game.is_player_safe():
			exposed_at = simulation_time
		if game.run_bites > previous_bite_count:
			if first_bite_at < 0.0:
				first_bite_at = simulation_time
			bites.append({"seconds_after_exit": simulation_time - exposed_at, "health": game.health, "position": str(game.player.position)})
		previous_health = game.health
		previous_bite_count = game.run_bites
		if died_at < 0.0 and game.mode == "dead":
			died_at = simulation_time
		var charging := 0
		var starts: Array[Dictionary] = []
		for wolf in game.wolves:
			if game.world.is_safe_position(wolf.position):
				cabin_breach = true
			var wolf_id: int = wolf.get_instance_id()
			if wolf.behavior == "charge":
				charging += 1
			# A serial also captures a rush that lands a bite and retreats in one tick.
			if wolf.charge_serial > int(observed_charge_serials.get(wolf_id, 0)):
				starts.append({"wolf_id": wolf_id, "serial": wolf.charge_serial, "pack_time": wolf.last_charge_at, "seconds_after_exit": simulation_time - exposed_at, "position": str(wolf.position)})
				observed_charge_serials[wolf_id] = wolf.charge_serial
		starts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.serial) < int(b.serial))
		for start in starts:
			if last_charger_id >= 0 and last_charger_id != int(start.wolf_id):
				minimum_other_wolf_charge_gap = minf(minimum_other_wolf_charge_gap, float(start.pack_time) - last_charge_time)
			charge_events.append(start)
			last_charger_id = int(start.wolf_id)
			last_charge_time = float(start.pack_time)
		maximum_chargers = maxi(maximum_chargers, charging)

func walk_to(goal: Vector3, timeout_seconds: float) -> bool:
	game.world.nav.field(goal.x, goal.z)
	var deadline := simulation_time + timeout_seconds
	set_forward(true)
	while simulation_time < deadline and game.mode == "playing":
		var offset: Vector3 = goal - game.player.position
		offset.y = 0
		if offset.length() < 0.3:
			set_forward(false)
			return true
		var next: Vector3 = game.world.nav.next_point(game.player.position.x, game.player.position.z)
		if not next.is_finite():
			break
		var direction: Vector3 = next - game.player.position
		if direction.length_squared() < 0.012:
			direction = offset
		game.player.yaw = atan2(-direction.x, -direction.z)
		await step_frames(1)
	set_forward(false)
	return false

func set_forward(pressed: bool) -> void:
	set_key(KEY_W, pressed)

func set_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func fire_signal_shot() -> void:
	# A real shot is an observable cue; unseen hunters no longer know our position.
	game.player.pitch = 1.2
	game.player._update_rotation()
	game.fire_weapon()
	check(game.ammo[0] == 0, "A real musket shot alerts the distant pack using an audible cue")
	game.player.pitch = -0.04
	game.player._update_rotation()

func check_spawn_distances(observations: Array[Dictionary]) -> void:
	for observation in observations:
		check(float(observation.horizontal_distance) >= 28.0, "Every natural wolf spawns at least 28 horizontal metres away")
		if observation.has("nearest_packmate_m"):
			check(float(observation.nearest_packmate_m) >= 2.5, "Natural pack spawns have at least 2.5 metres of spacing")

func check_charge_coordination(required_starts: int = 3, require_multiple_attackers: bool = true) -> void:
	check(charge_events.size() >= required_starts, "The natural pack commits to attacks and renews them when the victim fights free")
	check(maximum_chargers <= 2, "No more than two wolves charge simultaneously")
	# The AI reserves 0.75–1.0 s between starts; use its shared simulation timestamps.
	if require_multiple_attackers or is_finite(minimum_other_wolf_charge_gap):
		check(minimum_other_wolf_charge_gap >= 0.70 and is_finite(minimum_other_wolf_charge_gap), "Different wolves stagger their observed charge starts by at least 0.70 seconds")

func coordination_snapshot() -> Dictionary:
	return {"maximum_simultaneous_chargers": maximum_chargers, "minimum_other_wolf_charge_gap_seconds": minimum_other_wolf_charge_gap if is_finite(minimum_other_wolf_charge_gap) else -1, "charge_starts": charge_events.duplicate(true)}

func wolf_snapshot() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for wolf in game.wolves:
		rows.append({"position": str(wolf.position), "state": wolf.behavior, "distance": wolf.position.distance_to(game.player.position), "warned": wolf.warned})
	return rows

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
