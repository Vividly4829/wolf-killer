extends SceneTree

const GameScript = preload("res://scripts/main.gd")
const ProgressStore = preload("res://scripts/progress_store.gd")
const Catalog = preload("res://scripts/weapon_catalog.gd")
class SurvivalGame extends "res://scripts/main.gd":
	var profile_serial := 0
	# Keep this injury/ammunition fixture at three ordinary, fixed-profile wolves.
	func wolves_for_level(number: int) -> int:
		return 3 if number==4 else super.wolves_for_level(number)
	func _add_wolf_at(spawn: Vector3, profile_seed: int = -1) -> void:
		var chosen_seed := 8730 + profile_serial * 137 if profile_seed < 0 else profile_seed
		profile_serial += 1
		var actual_level := level
		level = 2
		super._add_wolf_at(spawn, chosen_seed)
		level = actual_level

var game: Node3D
var test_path: String
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	AudioServer.set_bus_mute(0, true)
	seed(873)
	test_path = "user://test_survival_%s_%s.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	game = SurvivalGame.new()
	game.progress = ProgressStore.new()
	game.progress.save_path = test_path
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.sounds.voices.clear()
	game.start_run()
	game.level = 4
	game.progress.money = int(Catalog.weapon(1).price) + int(Catalog.weapon(2).price) + 190
	game.player.position = game.world.shop_position
	game.interact_shop()
	game.purchase_weapon(1)
	game.purchase_weapon(2)
	game.close_shop()
	check(game.progress.owned == [0, 1, 2] and game.progress.money == 190, "The survival fixture acquires both paid weapons through the real store")
	game.select_weapon(0)
	game.player.position = game.world.exterior_rally_point
	game._process(0.5)
	check(game.wolves.size() == 3, "Leaving shelter starts the actual three-wolf wave")
	for wolf: Node3D in game.wolves:
		wolf.set_physics_process(false)
	var first: Node3D = game.wolves[0]
	var wounded: Node3D = game.wolves[1]
	var attacker: Node3D = game.wolves[2]
	# Isolated geometry makes ray/hit-zone assertions independent of tree cover.
	await aim_at_zone(first, "body")
	game.fire_weapon()
	check(first.dead and game.ammo[0] == 0 and game.wolves.size() == 2, "An actual musket body ray kills a normal wolf and spends one round")
	check(game.progress.money == 215 and game.progress.total_kills == 1, "A body-shot kill earns one reward")
	check(is_instance_valid(first) and first.is_in_group("wolf_corpses"), "The defeated wolf remains as a persistent corpse")
	game.reload_weapon()
	game._process(3.26)
	await aim_at_zone(wounded, "front_left")
	game.fire_weapon()
	check(not wounded.dead and wounded.health > 0.0 and game.ammo[0] == 0, "An actual limb ray injures the wolf without granting an immediate kill")
	check(wounded.severed_legs.has("front_left") and wounded.bleeding_rate > 0.0 and wounded.injury_speed_scale < 0.5, "A musket leg hit changes the matching limb, bleeding and movement")
	check(game.progress.money == 215 and game.progress.total_kills == 1, "Injury alone grants no credits")
	var wounded_health: float = wounded.health
	game.set_mode("paused")
	game._process(2.0)
	wounded._physics_process(2.0)
	check(wounded.health == wounded_health, "Pausing freezes a wounded wolf's blood loss")
	game.set_mode("playing")
	var bleed_frames: int = ceili(float(wounded.health) / float(wounded.bleeding_rate) * 60.0) + 2
	for frame in bleed_frames:
		await advance_frame(wounded)
		if wounded.dead:
			break
	check(wounded.dead and game.progress.money == 240 and game.progress.total_kills == 2, "The wounded wolf eventually bleeds out and awards one kill")
	wounded.damage(1000.0)
	check(game.progress.money == 240 and game.progress.total_kills == 2, "Further damage to the corpse cannot award another reward")
	check(game.mode == "playing" and game.wolves.size() == 1, "A surviving wolf keeps the current hunt active")

	# A close, reachable fixture exercises the real wolf-to-main maul callback.
	game.player.reset_at(game.world.nav.point(game.world.nav.nearest(-1.0, 9.0, 3.0)))
	attacker.position = game.world.wolf_nav.point(game.world.wolf_nav.nearest(-1.0, 11.0, 2.0))
	attacker.hear_gunshot(game.player.position)
	game._update_pursuit()
	game.reload_weapon()
	check(game.reload_left > 0.0, "The player is loading the musket when the live wolf approaches")
	for frame in 480:
		await advance_frame(attacker, true)
		if game.is_struggling():
			break
	check(game.is_struggling() and attacker.behavior == "maul" and game.run_bites >= 1, "A live wolf reaches the player and starts a real struggle")
	check(game.reload_left == 0.0 and not game.player.weapon.visible and game.player.bleeding_rate > 0.0, "The initial bite cancels loading, lowers the gun and creates a persistent wound")
	var pinned_position: Vector3 = game.player.position
	var pinned_ammo: Array = game.ammo.duplicate()
	set_key(KEY_W, true)
	set_key(KEY_SPACE, true)
	set_key(KEY_SPACE, false)
	game.fire_weapon()
	game.reload_weapon()
	game.select_weapon(2)
	for frame in 50:
		await advance_frame(attacker, true)
	check(game.player.position.is_equal_approx(pinned_position) and game.player._jump_height == 0.0, "Real walking and jump input cannot move a pinned player")
	check(game.ammo == pinned_ammo and game.reload_left == 0.0 and game.current_weapon == 0, "Fire, reload and weapon switching stay blocked during the struggle")
	check(game.run_bites >= 2 and game.player.arm_injury > 0.0 and game.health < 92.0, "A wolf holding the player lands repeated bites and different injuries")
	check(is_equal_approx(game.player._eye_height, 1.12) and absf(game.player.camera.fov - 70.0) < 0.7, "The struggle lowers the viewpoint and frames the attacking wolf")
	set_key(KEY_W, false)
	var paused_health: float = game.health
	var paused_bites: int = game.run_bites
	var paused_tick: float = game.struggle_tick
	var paused_concussion: float = game.player.concussion
	set_key(KEY_ESCAPE, true)
	set_key(KEY_ESCAPE, false)
	check(game.mode == "paused", "Actual Escape input pauses an active struggle")
	set_key(KEY_F, true)
	for frame in 90:
		await advance_frame(attacker, true)
	check(game.health == paused_health and game.run_bites == paused_bites and game.struggle_tick == paused_tick and game.struggle_progress == 0.0 and game.player.concussion == paused_concussion, "Pause freezes mauling, bleed damage, injury recovery and escape progress")
	set_key(KEY_ESCAPE, true)
	set_key(KEY_ESCAPE, false)
	var escape_frames := 0
	while game.is_struggling() and game.is_playing() and escape_frames < 360:
		await advance_frame(attacker, true)
		escape_frames += 1
	set_key(KEY_F, false)
	check(game.is_playing() and not game.is_struggling() and escape_frames > 150, "Holding actual F escapes a live maul through sustained effort")
	check(game.struggle_grace > 0.0 and game.player.weapon.visible and game.player.stamina < 100.0, "Escaping restores the gun, costs stamina and grants a brief release window")
	check(game.run_bites > paused_bites and game.player.leg_injury > 0.0 and game.player.arm_injury > 0.0 and game.player.concussion > 0.0, "The maul accumulates bleeding, leg, arm and head injuries")
	set_key(KEY_W, true)
	for frame in 20:
		await advance_frame(null, true)
	set_key(KEY_W, false)
	check(game.player.position.distance_to(pinned_position) > 0.1, "Walking resumes after the struggle ends")
	check(is_equal_approx(game.player._eye_height, 1.65), "The camera returns to standing height after escape")

	game.player.reset_at(game.world.spawn_position)
	var indoor_health: float = game.health
	var indoor_bites: int = game.run_bites
	game._process(1.0)
	check(game.is_player_safe() and game.health < indoor_health and game.run_bites == indoor_bites, "Shelter prevents new attacks but does not heal existing blood loss")
	set_key(KEY_B, true)
	set_key(KEY_B, false)
	check(is_equal_approx(game.bandage_left, 2.4) and game.bandages == 2, "Actual B starts a 2.4-second bandage without spending it early")
	var bleeding: float = game.player.bleeding_rate
	game.set_mode("paused")
	game._process(3.0)
	check(is_equal_approx(game.bandage_left, 2.4) and game.player.bleeding_rate == bleeding, "Pause also freezes an in-progress bandage")
	game.set_mode("playing")
	game._process(2.39)
	check(game.bandage_left > 0.0 and game.player.bleeding_rate > 0.0 and game.bandages == 2, "An incomplete bandage cannot stop bleeding or spend supplies")
	game._process(0.02)
	check(game.player.bleeding_rate == 0.0 and game.bandages == 1 and game.player.leg_injury > 0.0 and game.player.arm_injury > 0.0, "A completed bandage stops bleeding, spends one supply and retains limb injuries")
	var treated_health: float = game.health
	game._process(2.0)
	check(game.health == treated_health, "Bandaged injuries cause no further passive health loss")
	# A cautious wolf may have arrived after the earlier reload finished. A maul
	# correctly keeps that loaded round; consume it before testing a new reload.
	game.player.position = game.world.exterior_rally_point
	if game.ammo[0] > 0:
		game.player.pitch = 1.2
		game.player._update_rotation()
		game.fire_weapon()
	check(game.ammo[0] == 0, "The injured-arm reload test starts with an unloaded musket")
	game.reload_weapon()
	check(game.reload_left > 3.25 and is_equal_approx(game.reload_left, 3.25 * game.player.get_reload_multiplier()), "Main applies the injured arm multiplier to the actual musket reload")
	game._process(game.reload_left + 0.01)
	game.ammo[1] = 1
	game.ammo[2] = 2
	await aim_at_zone(attacker, "body")
	game.fire_weapon()
	check(attacker.dead and game.mode == "resting" and game.level == 5, "The last actual body shot automatically advances the level and starts bed rest")
	check(game.player.position.is_equal_approx(game.world.bed_position) and is_equal_approx(game.player.camera.position.y, 0.85) and not game.player.weapon.visible, "Rest places the player lying at the real cabin bed with the gun lowered")
	check(game.health == 100.0 and game.player.get_injury_summary().is_empty() and game.player.stamina == 100.0, "Bed rest restores health, every injury and stamina")
	check(game.ammo == Catalog.full_magazines() and game.reserve_ammo == Catalog.full_reserves() and game.reload_left == 0.0 and game.bandages == 2 and game.bandage_left == 0.0, "Bed rest replenishes loaded ammunition, reserves and bandages and clears interrupted actions")
	check(game.progress.money == 265 and game.progress.owned == [0, 1, 2] and game.progress.total_kills == 3, "Rest retains all paid weapons and the wallet including three earned rewards")
	set_key(KEY_W, true)
	set_key(KEY_SPACE, true)
	set_key(KEY_SPACE, false)
	game.player._physics_process(1.0)
	game.fire_weapon()
	check(game.player.position.is_equal_approx(game.world.bed_position) and game.ammo[0] == 1, "Movement, jumping and firing remain blocked while lying in bed")
	set_key(KEY_W, false)
	game._process(3.49)
	check(game.mode == "resting", "The bed animation lasts the full 3.5 seconds")
	game._process(0.02)
	check(game.mode == "playing" and game.player.weapon.visible and game.player.position.is_equal_approx(game.world.bed_wake_position), "Finishing rest returns control beside the bed")
	game._process(30.0)
	check(game.wolves.is_empty() and game.intermission and game.wave_countdown == 20.0, "The next larger wave waits while the rested player remains indoors")
	var doorway: Vector3 = game.world.spawn_position
	game.world.nav.field(doorway.x, doorway.z)
	set_key(KEY_W, true)
	for frame in 480:
		var away: Vector3 = doorway - game.player.position
		away.y = 0.0
		if away.length() < 0.3:
			break
		var next: Vector3 = game.world.nav.next_point(game.player.position.x, game.player.position.z)
		if not next.is_finite():
			break
		var heading: Vector3 = next - game.player.position
		if heading.length_squared() < 0.012:
			heading = away
		game.player.yaw = atan2(-heading.x, -heading.z)
		await advance_frame(null, true)
	set_key(KEY_W, false)
	var door_distance: Vector3 = doorway - game.player.position
	check(Vector2(door_distance.x, door_distance.z).length() < 0.3 and game.is_player_safe(), "Real W movement can leave the wake position and reach the cabin doorway without becoming trapped in the bunk")
	var completed_save = ProgressStore.new()
	completed_save.save_path = test_path
	completed_save.load_progress()
	check(completed_save.money == 265 and completed_save.owned == [0, 1, 2] and completed_save.best_level == 5 and completed_save.total_kills == 3, "The completed wave saves money, paid weapons and records")

	# Fatal untreated bleeding uses the same loss/save path even inside the cabin.
	game.player.apply_injury("bleeding", 1.0)
	game.health = 1.0
	game._process(1.0)
	check(game.mode == "dead" and game.health == 0.0 and game.level == 1 and game.progress.owned == [0], "Untreated blood loss can kill indoors and removes purchased weapons")
	var death_save = ProgressStore.new()
	death_save.save_path = test_path
	death_save.load_progress()
	check(death_save.money == 265 and death_save.owned == [0] and death_save.best_level == 5 and death_save.total_kills == 3, "Bleeding death immediately saves weapon loss while preserving wallet and records")
	game.start_run()
	check(game.health == 100.0 and game.player.get_injury_summary().is_empty() and game.bandages == 2 and game.wolves.is_empty() and game.current_weapon == 0, "Retry clears injuries and supplies a loaded musket while waiting indoors")

	game.queue_free()
	await process_frame
	await process_frame
	for path: String in [test_path, test_path + ".bak", test_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for failure in failures:
		push_error(failure)
	print("%s: %d survival integration checks; %d failed." % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func aim_at_zone(wolf: Node3D, zone: String) -> void:
	wolf.position = Vector3(0.0, 60.0, 0.0)
	wolf.rotation = Vector3.ZERO
	game.player.position = Vector3(4.0, 60.0, 0.0)
	var shape: CollisionShape3D = wolf._hit_zones[zone].get_child(0)
	var aim: Vector3 = shape.global_position
	game.player.camera.global_position = aim + Vector3.RIGHT * 4.0
	game.player.camera.look_at(aim)
	game.fire_cooldown = 0.0
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(game.player.camera.global_position, aim, 3)
	query.collide_with_areas = true
	var result: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	check(not result.is_empty() and result.collider.get_meta("hit_zone", "") == zone, "The real physics ray intersects the requested %s hit zone" % zone)

func advance_frame(active_wolf: Node3D = null, move_player: bool = false) -> void:
	await physics_frame
	game._process(1.0 / 60.0)
	if is_instance_valid(active_wolf):
		active_wolf._physics_process(1.0 / 60.0)
	if move_player:
		game.player._physics_process(1.0 / 60.0)

func set_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
