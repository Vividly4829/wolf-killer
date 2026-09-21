extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")

class FlatNavigation extends RefCounted:
	func move_position(position: Vector3, dx: float, dz: float) -> Vector3:
		return Vector3(position.x + dx, 0.0, position.z + dz)

class PlayerGame extends Node3D:
	var mode := "playing"
	var playing := true
	var struggling := false
	var reload_left := 0.0
	var damage_calls := 0
	var shots := 0
	var reloads := 0
	var selections := 0
	func is_playing() -> bool: return playing
	func is_struggling() -> bool: return struggling
	func damage_player(_amount: float) -> void: damage_calls += 1
	func fire_weapon() -> void: shots += 1
	func reload_weapon() -> void: reloads += 1
	func select_weapon(_index: int) -> void: selections += 1
	func interact_shop() -> void: pass

var game: PlayerGame
var player: Node3D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	game = PlayerGame.new()
	root.add_child(game)
	player = PlayerScript.new()
	game.add_child(player)
	player.configure(game, FlatNavigation.new())
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.reset_at(Vector3.ZERO)
	step(2)
	check(player.get_noise_level() < 0.1 and not player.is_crouching, "Standing still is quiet")
	var standing_visibility: float = player.get_visibility()
	hold(KEY_CTRL, true)
	step(30)
	check(player.is_crouching and is_equal_approx(player.camera.position.y, 1.05), "Holding Control crouches and lowers the eye to 1.05 m")
	check(player.get_visibility() < standing_visibility and player.get_noise_level() < 0.1, "Stationary crouching is quieter and less visible")
	player._unhandled_input(key_event(KEY_SPACE, true))
	step(1)
	check(player._jump_height == 0.0, "A crouched player does not jump out of concealment")
	hold(KEY_W, true)
	hold(KEY_SHIFT, true)
	var start: Vector3 = player.position
	step(60)
	var crouch_distance: float = player.position.distance_to(start)
	var crouch_noise: float = player.get_noise_level()
	check(crouch_distance < 2.1 and player.stamina == player.MAX_STAMINA, "Crouching stays slow even with sprint held and does not drain sprint stamina")
	check(crouch_noise > 0.05 and crouch_noise < 0.2, "Crouched footsteps produce a low detectable noise")
	release_keys()
	player.reset_at(Vector3.ZERO)
	hold(KEY_W, true)
	step(60)
	var walking_distance: float = player.position.length()
	var walking_noise: float = player.get_noise_level()
	check(walking_distance > crouch_distance * 1.5 and walking_distance<2.5 and walking_noise > crouch_noise, "Natural walking is faster and louder than crouching")
	release_keys()
	player.reset_at(Vector3.ZERO)
	hold(KEY_W, true)
	hold(KEY_SHIFT, true)
	step(60)
	var sprint_distance: float = player.position.length()
	check(sprint_distance > walking_distance and player.get_noise_level() > walking_noise and player.stamina < player.MAX_STAMINA, "Sprinting has distinct speed, loudness and stamina cost")
	release_keys()
	player.reset_at(Vector3.ZERO)
	player._unhandled_input(key_event(KEY_SPACE, true))
	step(1)
	check(player._jump_height > 0.0 and player.get_noise_level() >= 0.75, "Jumping creates a distinct loud movement cue")
	var healthy_peak := 0.0
	var landing_heard := false
	for frame in 90:
		var airborne: bool = player._jump_height > 0.02
		step(1)
		healthy_peak = maxf(healthy_peak, player._jump_height)
		if airborne and player._jump_height == 0.0:
			landing_heard = player.get_noise_level() >= 0.7
	check(landing_heard and player.get_noise_level() < 0.1, "Landing makes a short noise that fades back to stationary quiet")

	player.apply_injury("leg", 0.75)
	player.reset_at(Vector3.ZERO)
	hold(KEY_W, true)
	step(60)
	check(player.position.length() < walking_distance * 0.8, "A leg injury noticeably slows ordinary movement")
	release_keys()
	player.reset_at(Vector3.ZERO)
	player._unhandled_input(key_event(KEY_SPACE, true))
	var injured_peak := 0.0
	for frame in 90:
		step(1)
		injured_peak = maxf(injured_peak, player._jump_height)
	check(injured_peak < healthy_peak * 0.6, "A leg injury lowers jump height")
	player.apply_injury("leg", 1.0)
	player.reset_at(Vector3.ZERO)
	hold(KEY_W, true)
	hold(KEY_SHIFT, true)
	step(30)
	check(player.leg_injury == 1.0 and player._velocity.length() < 4.0 and player.stamina == player.MAX_STAMINA, "Severe leg injury caps severity and prevents sprinting")
	release_keys()
	player.apply_injury("arm", 0.6)
	check(is_equal_approx(player.get_reload_multiplier(), 1.39) and is_equal_approx(player.get_aim_spread_multiplier(), 1.9), "Arm damage increases reload duration and shot spread")
	player.apply_injury("concussion", 0.8)
	player.apply_injury("bleeding", 0.5)
	step(2)
	check(absf(player.camera.rotation.y) > 0.0001 and absf(player.camera.rotation.z) > 0.0001, "Arm injury adds aim sway and concussion adds a camera effect")
	var summary: String = player.get_injury_summary()
	check(summary.contains("BLEEDING") and summary.contains("LEG") and summary.contains("ARM") and summary.contains("CONCUSSION"), "The injury summary reports all active conditions")
	player.reset_at(Vector3(3, 0, 0))
	check(player.leg_injury == 1.0 and player.arm_injury == 0.6 and player.concussion == 0.8 and is_equal_approx(player.bleeding_rate, 0.7), "Changing position does not heal persistent injuries")
	step(120)
	check(game.damage_calls == 0 and player.concussion == 0.8, "Controller physics never independently ticks bleeding or recovery")
	check(is_equal_approx(player.tick_injuries(2.0), 1.4) and is_equal_approx(player.concussion, 0.7), "The main-owned injury tick returns bleed damage and gradually reduces concussion")
	check(player.leg_injury == 1.0 and player.arm_injury == 0.6 and player.bleeding_rate > 0.0, "Time alone does not heal leg, arm or bleeding injuries")
	check(player.tick_injuries(-1.0) == 0.0, "A negative time step cannot heal or apply negative bleed damage")
	player.stop_bleeding()
	check(player.tick_injuries(1.0) == 0.0 and player.leg_injury == 1.0 and player.arm_injury == 0.6, "Bandaging stops bleeding without healing limb injuries")
	player.stamina = 17.0
	player.clear_injuries()
	check(player.get_injury_summary().is_empty() and player.stamina == player.MAX_STAMINA and player.get_reload_multiplier() == 1.0 and player.get_aim_spread_multiplier() == 1.0, "Clearing injuries heals all conditions and restores stamina")

	for index in 3:
		game.reload_left = 0.0
		player.set_weapon(index)
		player.reset_at(Vector3.ZERO)
		hold(KEY_W, true)
		step(20)
		game.reload_left = 2.0
		player.play_reload(2.0)
		var planted: Vector3 = player.position
		step(20)
		check(player.position == planted if index == 0 else player.position.distance_to(planted) > 0.5, "Weapon %d retains its intended reload movement rule" % index)
		release_keys()
	game.reload_left = 0.0
	player.reset_at(Vector3.ZERO)
	hold(KEY_W, true)
	step(20)
	game.struggling = true
	var grapple_position: Vector3 = player.position
	step(1)
	check(player.position == grapple_position and player._velocity == Vector2.ZERO, "A struggle immediately cancels walking momentum")
	var before_reload: int = game.reloads
	var before_select: int = game.selections
	player._unhandled_input(key_event(KEY_SPACE, true))
	player._unhandled_input(key_event(KEY_R, true))
	player._unhandled_input(key_event(KEY_1, true))
	step(30)
	check(player.position == grapple_position and player._jump_height == 0.0 and game.reloads == before_reload and game.selections == before_select, "A struggle blocks movement, jumping, reload and weapon selection")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	var before_shots: int = game.shots
	step(10)
	check(game.shots == before_shots, "Held fire cannot shoot the weapon during a struggle")
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var original_yaw: float = player.yaw
		var look := InputEventMouseMotion.new()
		look.relative = Vector2(120, 50)
		player._unhandled_input(look)
		check(player.yaw != original_yaw, "The player can still look around during a struggle")
		look.relative = Vector2(4000, 4000)
		player._unhandled_input(look)
		check(absf(player.yaw - player._struggle_anchor_yaw) <= 0.551 and absf(player.pitch - player._struggle_anchor_pitch) <= 0.351, "Struggle look stays within a limited range")
	check(absf(player.camera.rotation.z) > 0.00001 and player.get_noise_level() >= 0.8, "Struggle animation and audible effort continue while movement is locked")
	mouse = mouse.duplicate()
	mouse.pressed = false
	Input.parse_input_event(mouse)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.struggling = false
	step(1)
	check(player._velocity.length() > 0.0, "Held movement resumes immediately after the struggle ends")
	release_keys()
	game.playing = false
	player.camera.position.y = 0.7
	var resting_position: Vector3 = player.position
	hold(KEY_W, true)
	step(60)
	check(player.position == resting_position and is_equal_approx(player.camera.position.y, 0.7), "Resting freezes the controller and preserves the bed camera height")
	release_keys()
	game.queue_free()
	await process_frame
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d player hunting, injury and struggle checks; no save files touched." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func step(count: int) -> void:
	for frame in count:
		player._physics_process(1.0 / 60.0)

func key_event(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func hold(code: Key, pressed: bool) -> void:
	Input.parse_input_event(key_event(code, pressed))
	Input.flush_buffered_events()

func release_keys() -> void:
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_CTRL, KEY_SPACE]:
		hold(code, false)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
