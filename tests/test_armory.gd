extends SceneTree

const GameScript = preload("res://scripts/main.gd")
const Catalog = preload("res://scripts/weapon_catalog.gd")
const Progress = preload("res://scripts/progress_store.gd")
var game: Node3D
var checks := 0
var failures: Array[String] = []
var save_path: String

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func run_checks() -> void:
	seed(1890)
	AudioServer.set_bus_mute(0, true)
	game = GameScript.new()
	save_path = "user://test_armory_%s.cfg" % OS.get_process_id()
	game.progress.save_path = save_path
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.start_run()
	check(Catalog.WEAPONS.size() == 24 and game.ammo.size() == 24 and game.reserve_ammo.size() == 24, "Fifteen additions plus three period replacements make twenty-four working slots")
	var unique: Dictionary = {}
	var total_cost := 0
	for index: int in Catalog.WEAPONS.size():
		var spec: Dictionary = Catalog.weapon(index)
		check(int(spec.year) < 1890 and int(spec.year) > 1400 and not unique.has(spec.id), "Weapon %d is unique and predates1890" % index)
		unique[spec.id] = true
		check(not spec.automatic and float(spec.interval) >= 0.4 and int(spec.reserve) > 0, "%s has deliberate fire and finite reserve ammunition" % spec.name)
		check(game.sounds.samples.has(spec.sound), "%s has a valid sound" % spec.name)
		total_cost += int(spec.price)
	game.progress.money = 50000
	game.player.position = game.world.shop_position
	game.interact_shop()
	for index: int in range(1, 24):
		game.purchase_weapon(index)
		check(game.progress.owned.has(index) and game.current_weapon == index, "The real store purchases and equips slot%d" % index)
	check(game.progress.money == 50000 - total_cost and game.progress.owned.size() == 24, "All purchases spend exactly the catalog total")
	var saved := Progress.new()
	saved.save_path = save_path
	saved.load_progress()
	check(saved.owned.size() == 24 and saved.money == game.progress.money, "All twenty-four ownership IDs and the wallet survive disk reload")
	game.close_shop()
	game.intermission = false
	game.pending_spawns = 0
	game.player.position = Vector3(0, 60, 0)
	game.player.camera.look_at(Vector3(0, 65, -10))
	for index: int in 24:
		game.select_weapon(index)
		game.fire_cooldown = 0.0
		var reserve_before: int = game.current_reserve()
		var loaded_before: int = game.current_ammo()
		game.fire_weapon()
		check(game.current_ammo() == loaded_before - 1 and game.current_reserve() == reserve_before, "Firing slot%d consumes only its loaded round" % index)
		game.fire_weapon()
		check(game.current_ammo() == loaded_before - 1, "Slot%d cannot bypass its action-cycle delay" % index)
		game.reload_weapon()
		check(game.reload_left > 0.0, "Slot%d starts its proper reload" % index)
		var remaining: float = game.reload_left
		game.set_mode("paused")
		game._process(remaining + 1.0)
		check(game.reload_left == remaining and game.current_reserve() == reserve_before, "Pause preserves slot%d reload and ammunition" % index)
		game.set_mode("playing")
		game._process(remaining + 0.01)
		check(game.current_ammo() == loaded_before and game.current_reserve() == reserve_before - 1, "Completing slot%d reload transfers one finite reserve round" % index)
		game._clear_projectiles()
		await process_frame
	game.select_weapon(6)
	game.ammo[6] = 1
	game.reserve_ammo[6] = 2
	game.reload_weapon()
	game._process(game.reload_left + 0.01)
	check(game.ammo[6] == 3 and game.reserve_ammo[6] == 0, "A six-barrel pepperbox partially loads when only two spare rounds remain")
	game.ammo[6] = 0
	game.reload_weapon()
	check(game.reload_left == 0.0 and game.ammo[6] == 0, "Empty reserve cannot create free ammunition")
	game.reserve_ammo[6] = 4
	game.reload_weapon()
	game._process(2.0)
	game.select_weapon(14)
	game._process(20.0)
	check(game.ammo[6] == 0 and game.reserve_ammo[6] == 4, "Changing guns cancels a partial reload without transferring ammunition")
	game.select_owned_slot(8)
	check(game.current_weapon == 8, "Numeric owned slots reach the ninth weapon")
	game.cycle_weapon(1)
	check(game.current_weapon == 9, "Cycling reaches weapons beyond numeric slots")
	game.select_weapon(23)
	game.cycle_weapon(1)
	check(game.current_weapon == 0, "Owned weapon cycling wraps across all twenty-four entries")
	game.cycle_weapon(-1)
	check(game.current_weapon == 23, "Previous weapon wraps back to the twenty-fourth entry")

	game.select_weapon(9)
	var cylinder: int = game.ammo[9]
	game.toggle_fire_mode()
	check(game.lemat_secondary and game.current_ammo() == 1 and game.weapon_spec().pellets == 10, "LeMat selector exposes its independently loaded central shot barrel")
	game.fire_cooldown = 0.0
	game.fire_weapon()
	check(game.lemat_shot_ammo == 0 and game.ammo[9] == cylinder, "LeMat shot mode leaves its nine-shot cylinder untouched")
	game.reload_weapon()
	game._process(game.reload_left + 0.01)
	check(game.lemat_shot_ammo == 1 and game.lemat_shot_reserve == 3 and game.ammo[9] == cylinder, "Central barrel loading spends only its own shot reserve")
	game.toggle_fire_mode()
	check(not game.lemat_secondary and game.current_ammo() == cylinder, "LeMat selector restores the untouched cylinder")

	game.player.position = game.world.shop_position
	game.interact_shop()
	var wallet: int = game.progress.money
	var missing_cost: int = game.ammo_refill_cost()
	var loaded_snapshot: Array = game.ammo.duplicate()
	game.purchase_ammo()
	check(missing_cost > 0 and game.progress.money == wallet - missing_cost, "The store charges the exact missing-ammunition cost")
	check(game.reserve_ammo == Catalog.full_reserves() and game.lemat_shot_reserve == 4 and game.ammo == loaded_snapshot, "Ammunition purchase replenishes reserves without bypassing reloads")
	game.purchase_ammo()
	check(game.progress.money == wallet - missing_cost, "An already-full reserve cannot be charged twice")
	game.close_shop()
	game.player.position = Vector3(0, 60, 0)
	game.player.camera.position = Vector3(0, 0.72, 0)
	game.player.camera.look_at(Vector3(0, 60.72, -10))
	game.pending_spawns = 1
	game.spawn_timer = 999.0
	game._add_wolf_at(Vector3(0, 60, -8))
	var target: Node3D = game.wolves.back()
	target.set_physics_process(false)
	target.rotation.y = PI / 2.0
	var body_shape: CollisionShape3D = target._hit_zones.body.get_child(0)
	var torso: Vector3 = body_shape.global_position
	# Side-on aim clears the head, with elevation for the bolt's eight-metre drop.
	game.player.camera.global_position = Vector3(torso.x, torso.y + 0.15, 0.0)
	game.player.camera.look_at(torso + Vector3.UP * 0.15)
	game.pending_spawns = 1
	game.select_weapon(3)
	game.fire_cooldown = 0.0
	await physics_frame
	await physics_frame
	game.fire_weapon()
	check(not target.alerted and game.get_tree().get_nodes_in_group("player_bolts").size() == 1, "A quiet crossbow shot launches a visible projectile without alerting an eight-metre wolf immediately")
	var bolt: Node3D = game.get_tree().get_nodes_in_group("player_bolts")[0]
	bolt.set_physics_process(false)
	var original: Vector3 = bolt.position
	game.set_mode("paused")
	bolt._physics_process(0.1)
	check(bolt.position == original, "Pause freezes bolts in flight")
	game.set_mode("playing")
	bolt._physics_process(0.05)
	check(bolt.position.z < original.z - 2.0 and bolt.position.y < original.y and bolt.velocity.y < 0.0, "Crossbow bolts travel through space and fall under gravity")
	var before_kills: int = game.progress.total_kills
	var before_bolt_health: float = target.health
	for frame: int in 25:
		if bolt.is_queued_for_deletion():
			break
		bolt._physics_process(1.0 / 60.0)
	var report: Dictionary = game.shot_review.reports.back() if not game.shot_review.reports.is_empty() else {}
	var expected_health: float = maxf(0.0, before_bolt_health - float(report.get("calculated_damage",0)))
	check(target.health < before_bolt_health and is_equal_approx(target.health, expected_health) and game.progress.total_kills == before_kills + int(expected_health == 0.0), "A travelling bolt damages the actual scaled torso and awards a kill only if its individual health is exhausted")
	await process_frame
	game.pending_spawns = 1
	game._add_wolf_at(Vector3(0, 60, -15))
	var hearing_wolf: Node3D = game.wolves.back()
	hearing_wolf.set_physics_process(false)
	game.pending_spawns = 1
	game.player.camera.look_at(Vector3(0, 70, -10))
	game.select_weapon(0)
	game.fire_cooldown = 0.0
	game.fire_weapon()
	check(hearing_wolf.alerted, "A firearm report alerts the distant wolf that the crossbow left unaware")
	# Reuse the living wolf for the new low-force projectile versus heavy-rifle
	# wound behavior, both through real collision shapes rather than direct damage.
	hearing_wolf.position = Vector3(0, 60, 0)
	hearing_wolf.rotation = Vector3.ZERO
	hearing_wolf.max_health *= 4.0
	hearing_wolf.health = hearing_wolf.max_health
	game.player.position = Vector3(4, 60, 0)
	var leg_shape: CollisionShape3D = hearing_wolf._hit_zones.front_left.get_child(0)
	var leg_point: Vector3 = leg_shape.global_position
	game.player.camera.global_position = leg_point + Vector3.RIGHT * 4.0
	game.player.camera.look_at(leg_point)
	game.select_weapon(3)
	game.ammo[3] = 1
	game.fire_cooldown = 0.0
	await physics_frame
	await physics_frame
	game.fire_weapon()
	for frame: int in 30:
		await physics_frame
	check(hearing_wolf.leg_injuries.front_left > 0.0 and hearing_wolf.severed_legs.is_empty() and hearing_wolf.bleeding_rate > 0.0, "A real bolt through a leg produces a bleeding wound without tearing off the limb")
	game.select_weapon(15)
	game.player.camera.global_position = leg_shape.global_position + Vector3.RIGHT * 4.0
	game.player.camera.look_at(leg_shape.global_position)
	game.fire_cooldown = 0.0
	game.fire_weapon()
	check(hearing_wolf.severed_legs.has("front_left") and hearing_wolf.health > 0.0 and not hearing_wolf.dead, "A real heavy Sharps leg shot severs the limb while leaving a living, bleeding animal")
	# The same swept projectile must stop on island-style solid collision.
	hearing_wolf.position = Vector3(0, 60, -8)
	game.player.position = Vector3(0, 60, 0)
	game.player.camera.position = Vector3(0, 0.72, 0)
	game.player.camera.look_at(Vector3(0, 60.72, -10))
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.15)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = Vector3(0, 60.7, -4)
	game.select_weapon(3)
	game.ammo[3] = 1
	game.fire_cooldown = 0.0
	await physics_frame
	await physics_frame
	var behind_wall_health: float = hearing_wolf.health
	game.fire_weapon()
	for frame: int in 40:
		await physics_frame
	check(hearing_wolf.health == behind_wall_health and get_nodes_in_group("player_bolts").is_empty(), "A moving bolt hits a thin solid wall and cannot tunnel through to the wolf")
	wall.queue_free()
	var shotgun: Dictionary = Catalog.weapon(1)
	check(game.damage_at_distance(shotgun, 30.0) < game.damage_at_distance(shotgun, 3.0) * 0.5, "Shotgun pellets lose most of their stopping power at long range")
	check(game.damage_at_distance(Catalog.weapon(15), 60.0) == 190.0, "The costly Sharps retains its heavy damage at rifle distances")
	var money_before_death: int = game.progress.money
	game.damage_player(1000.0)
	check(game.progress.owned == [0] and game.progress.money == money_before_death and game.mode == "dead", "Death removes every purchased armory weapon while retaining the wallet")
	game.start_run()
	check(game.ammo == Catalog.full_magazines() and game.reserve_ammo == Catalog.full_reserves() and game.progress.owned == [0], "A retry refills the starter without restoring lost ownership")
	game.queue_free()
	await process_frame
	await process_frame
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for failure in failures:
		push_error(failure)
	print("%s: %d armory integration checks; %d failed." % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
