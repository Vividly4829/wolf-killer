extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
const Catalog = preload("res://scripts/weapon_catalog.gd")

class FlatNavigation extends RefCounted:
	func move_position(point: Vector3, dx: float, dz: float) -> Vector3:
		return Vector3(point.x + dx, 0.0, point.z + dz)

class ControlGame extends Node3D:
	var mode := "playing"
	var playing := true
	var struggling := false
	var reload_left := 0.0
	var shots := 0
	var slots: Array[int] = []
	var cycles: Array[int] = []
	var modes := 0
	var weapon_index := 0
	var secondary := false
	func is_playing() -> bool: return playing
	func is_struggling() -> bool: return struggling
	func fire_weapon() -> void: shots += 1
	func reload_weapon() -> void: pass
	func interact_shop() -> void: pass
	func select_owned_slot(index: int) -> void: slots.append(index)
	func cycle_weapon(direction: int) -> void: cycles.append(direction)
	func toggle_fire_mode() -> void: modes += 1
	func weapon_spec() -> Dictionary:
		return Catalog.secondary_weapon() if secondary and weapon_index == 9 else Catalog.weapon(weapon_index)

var game: ControlGame
var player: Node3D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	game = ControlGame.new()
	root.add_child(game)
	player = PlayerScript.new()
	game.add_child(player)
	player.configure(game, FlatNavigation.new())
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check(Catalog.WEAPONS.size() == 27, "All twenty-seven weapons are available to the controller")
	for index in Catalog.WEAPONS.size():
		var data: Dictionary = Catalog.weapon(index)
		game.weapon_index = index
		player.reset_at(Vector3.ZERO)
		player.set_weapon(index)
		player.pitch = -0.04
		player.play_shot()
		check(is_equal_approx(player._recoil, float(data.recoil)) and is_equal_approx(player.pitch, -0.04 - float(data.kick)), "Weapon %d uses its catalog recoil and camera kick" % index)
		check(is_equal_approx(player.get_noise_level(), 0.16 if float(data.projectile_speed)>0 else 1.0), "Weapon %d has its intended crossbow/firearm noise level" % index)
		var duration: float = data.reload
		player.play_reload(duration)
		var stages: Array = data.reload_stages
		var all_stages_match := true
		for stage in stages.size():
			game.reload_left = duration * (1.0 - (float(stage) + 0.5) / float(stages.size()))
			all_stages_match = all_stages_match and player.get_reload_stage() == str(stages[stage])
		check(all_stages_match and not stages.is_empty(), "Weapon %d exposes its actual loading stages" % index)
		game.reload_left = 0.0
		check(player.get_reload_stage().is_empty(), "Weapon %d stops reporting loading stages when complete" % index)
		player.reset_at(Vector3.ZERO)
		game.reload_left = duration
		player.play_reload(duration)
		key(KEY_W, true)
		step(30)
		key(KEY_W, false)
		check(player.position.length() == 0.0 if index == 0 else player.position.length() > 0.7, "Only the starter musket immobilizes movement while loading (weapon %d)" % index)
		game.reload_left = 0.0

	game.weapon_index = 9
	game.secondary = true
	player.set_weapon(9)
	player.reset_at(Vector3.ZERO)
	player.pitch = -0.04
	player.play_shot()
	var secondary_spec: Dictionary = Catalog.secondary_weapon()
	check(is_equal_approx(player._recoil, float(secondary_spec.recoil)) and is_equal_approx(player.pitch, -0.04 - float(secondary_spec.kick)), "The LeMat shot barrel uses the main-owned secondary recoil and kick")
	game.reload_left = float(secondary_spec.reload)
	player.play_reload(game.reload_left)
	check(player.get_reload_stage() == str(secondary_spec.reload_stages[0]), "The LeMat secondary mode exposes its separate muzzle-loading stages")
	game.reload_left = 0.0
	game.secondary = false
	for index in 9:
		player._unhandled_input(key_event(KEY_1 + index, true))
	check(game.slots == [0, 1, 2, 3, 4, 5, 6, 7, 8], "Number keys one through nine select owned-inventory slots")
	player._unhandled_input(mouse_event(MOUSE_BUTTON_WHEEL_UP, true))
	player._unhandled_input(mouse_event(MOUSE_BUTTON_WHEEL_DOWN, true))
	player._unhandled_input(key_event(KEY_Q, true))
	check(game.cycles == [1, -1, -1], "Wheel and Q cycle through owned inventory using the game contract")
	player._unhandled_input(key_event(KEY_V, true))
	check(game.modes == 1, "V requests the LeMat fire-mode toggle")
	game.struggling = true
	player._unhandled_input(key_event(KEY_V, true))
	player._unhandled_input(key_event(KEY_9, true))
	player._unhandled_input(mouse_event(MOUSE_BUTTON_WHEEL_UP, true))
	check(game.modes == 1 and game.slots.size() == 9 and game.cycles.size() == 3, "Struggling blocks fire-mode changes and inventory controls")
	game.struggling = false
	player.reset_at(Vector3.ZERO)
	player.set_weapon(2)
	game.weapon_index = 2
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		click(true)
		check(game.shots == 1, "A fresh left-mouse press fires one shot")
		step(120)
		click(true)
		check(game.shots == 1, "Holding or repeating a pressed event never creates automatic fire")
		click(false)
		click(true)
		check(game.shots == 2, "Release and a fresh press permit the next shot")
		click(false)
		game.playing = false
		click(true)
		game.playing = true
		step(20)
		check(game.shots == 2, "A trigger held through pause does not fire on resume")
		click(false)
		game.struggling = true
		click(true)
		step(20)
		game.struggling = false
		step(20)
		check(game.shots == 2, "A trigger held to fight a wolf does not fire the gun when released from its jaws")
		click(false)
		click(true)
		check(game.shots == 3, "A fresh trigger press works after the struggle")
		click(false)
	else:
		print("Captured-mouse trigger checks require the native renderer; other controller checks run headlessly.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await process_frame
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d historical weapon controller checks; %d failed." % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func step(frames: int) -> void:
	for frame in frames:
		player._physics_process(1.0 / 60.0)

func key_event(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func key(code: int, pressed: bool) -> void:
	Input.parse_input_event(key_event(code, pressed))
	Input.flush_buffered_events()

func mouse_event(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event

func click(pressed: bool) -> void:
	Input.parse_input_event(mouse_event(MOUSE_BUTTON_LEFT, pressed))
	Input.flush_buffered_events()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
