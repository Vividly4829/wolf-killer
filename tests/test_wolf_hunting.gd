extends SceneTree

const Wolf = preload("res://scripts/wolf.gd")
const Nav = preload("res://scripts/island_nav.gd")
const Gore = preload("res://scripts/gore_effects.gd")

class Prey extends Node3D:
	var noise: float = 0.025
	var visibility: float = 0.4
	var is_crouching: bool = true
	func get_noise_level() -> float:
		return noise
	func get_visibility() -> float:
		return visibility

class Sounds extends Node:
	var calls: Dictionary = {}
	func play_at(kind: String, _point: Vector3, _volume: float = -12.0, _individual_pitch: float = 1.0) -> void:
		calls[kind] = int(calls.get(kind, 0)) + 1

class Ground extends Node3D:
	var nav: RefCounted
	var exterior_rally_point := Vector3(0, 0, 5)

class HuntingGame extends Node3D:
	var player: Prey
	var world: Ground
	var sounds: Sounds
	var gore: Node3D
	var safe: bool = false
	var defeats: int = 0
	var bite_damage: float = 0.0
	var struggle_wolf: Node3D
	var struggle_starts: int = 0
	var allow_struggle: bool = true
	func is_playing() -> bool:
		return true
	func is_player_safe() -> bool:
		return safe
	func damage_player(amount: float) -> void:
		bite_damage += amount
	func receive_wolf_bite(amount: float, _source: Vector3) -> void:
		bite_damage += amount
	func wolf_defeated(wolf: Node3D) -> void:
		defeats += 1
		if struggle_wolf == wolf:
			struggle_wolf = null
	func is_struggling() -> bool:
		return is_instance_valid(struggle_wolf) and not bool(struggle_wolf.get("dead"))
	func start_wolf_struggle(wolf: Node3D) -> bool:
		if safe or is_struggling() or not allow_struggle:
			return false
		struggle_wolf = wolf
		struggle_starts += 1
		return true
	func end_wolf_struggle(escaped: bool) -> void:
		var attacker: Node3D = struggle_wolf
		struggle_wolf = null
		if is_instance_valid(attacker):
			attacker.call("end_struggle", escaped)

var checks: int = 0
var failures: Array[String] = []
var game: HuntingGame
var navigation: RefCounted
var next_profile_seed := 90210

func _initialize() -> void:
	call_deferred("run_checks")

func make_wolf(point: Vector3 = Vector3.ZERO) -> Node3D:
	var wolf := Wolf.new()
	wolf.configure(game, navigation, 1, next_profile_seed)
	next_profile_seed += 1
	game.add_child(wolf)
	wolf.position = point
	wolf.set_physics_process(false)
	wolf.rng.seed = 90210
	return wolf

func sense(wolf: Node3D, duration: float) -> void:
	for step: int in range(ceili(duration / 0.1)):
		wolf.set("_time", float(wolf.get("_time")) + 0.1)
		wolf.call("_update_perception", game.player, 0.1)

func tick(wolf: Node3D, duration: float) -> void:
	for step: int in range(ceili(duration * 60.0)):
		wolf.call("_physics_process", 1.0 / 60.0)

func run_checks() -> void:
	game = HuntingGame.new()
	root.add_child(game)
	game.player = Prey.new()
	game.add_child(game.player)
	game.world = Ground.new()
	game.add_child(game.world)
	game.sounds = Sounds.new()
	game.add_child(game.sounds)
	game.gore = Gore.new()
	game.add_child(game.gore)
	navigation = Nav.new()
	var heights: Array = []
	heights.resize(201 * 201)
	heights.fill(0.0)
	var blocked := PackedByteArray()
	blocked.resize(201 * 201)
	navigation.call("setup", {"width": 201, "depth": 201, "cellSize": 0.5, "origin": [-50.0, -50.0], "heights": heights, "blocked": blocked})
	game.world.nav = navigation
	navigation.call("field", 0.0, 0.0)
	var wolf := make_wolf()
	game.player.position = Vector3(0, 0, -8)
	sense(wolf, 3.0)
	check(not wolf.alerted and wolf.awareness < 0.12 and not wolf.get_pursuit_target().is_finite(), "Quiet crouching behind an unaware wolf does not reveal the player or an omniscient pursuit target")
	game.player.position = Vector3(0, 0, 9)
	sense(wolf, 0.8)
	check(not wolf.alerted and wolf.awareness < 0.6, "Crouching reduces visual detection buildup even within the wolf's sight cone")
	game.player.visibility = 1.0
	game.player.is_crouching = false
	sense(wolf, 1.5)
	check(wolf.alerted and wolf.last_known_position == game.player.position and wolf.detection_state == "alert", "A visible standing survivor is detected and yields an actual known pursuit position")
	wolf.free()
	wolf = make_wolf()
	game.player.position = Vector3(0, 0, -10)
	game.player.noise = 0.95
	sense(wolf, 1.2)
	check(wolf.alerted and wolf.heard_noise and not wolf._has_visual_contact, "Loud movement alerts a wolf through hearing even outside its sight cone")
	wolf.free()
	wolf = make_wolf()
	game.player.position = Vector3(0, 0, 8)
	game.player.noise = 0.025
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 0.3)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = Vector3(0, 1, 4)
	await physics_frame
	await physics_frame
	sense(wolf, 3.0)
	check(not wolf.alerted and wolf.awareness == 0.0, "A physical wall blocks sight of a quiet survivor")
	wolf.hear_gunshot(Vector3(0, 0, 8))
	check(wolf.alerted and wolf.awareness == 1.0 and wolf.last_known_position == Vector3(0, 0, 8), "A gunshot gives nearby wolves the shot's position despite blocked sight")
	game.player.position = Vector3(12, 0, -12)
	sense(wolf, 4.0)
	check(wolf.last_known_position == Vector3(0, 0, 8) and wolf.detection_state == "searching", "After contact is lost a wolf searches the last known cue instead of tracking the hidden player")
	sense(wolf, 13.0)
	check(not wolf.alerted and wolf.awareness < 0.12 and not wolf.get_pursuit_target().is_finite(), "An unrefreshed cue decays and the wolf returns to unaware patrol")
	var bark_count: int = int(game.sounds.calls.get("bark", 0))
	for request: int in range(20):
		wolf._bark()
	check(int(game.sounds.calls.get("bark", 0)) <= bark_count + 1, "Barking is rate-limited rather than emitted every frame")
	wolf._howl_left = 0.01
	var howl_count: int = int(game.sounds.calls.get("howl", 0))
	for frame: int in range(60):
		wolf._tick_vocalizations(1.0 / 60.0)
	check(int(game.sounds.calls.get("howl", 0)) == howl_count + 1 and wolf._howl_left > 16.0, "A howl schedules a staggered pause before the next call")
	wolf.free()
	wall.queue_free()
	await physics_frame
	game.player.position = Vector3(40, 0, 40)
	wolf = make_wolf()
	await physics_frame
	await physics_frame
	var leg_shape: CollisionShape3D = wolf._hit_zones.front_left.get_child(0)
	var leg_center: Vector3 = leg_shape.global_position
	var query := PhysicsRayQueryParameters3D.create(leg_center + Vector3.RIGHT * 2, leg_center + Vector3.LEFT * 2, 2)
	query.collide_with_areas = true
	var leg_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	check(not leg_hit.is_empty() and str(leg_hit.collider.get_meta("hit_zone", "")) == "front_left", "A ray aimed at a front leg hits its distinct physical damage zone")
	check(wolf._hit_zones.size() == 6 and wolf._hit_zones.has("head"), "The wolf has body, head and four distinct leg hit areas")
	var defeats_before: int = game.defeats
	wolf.receive_hit(115.0, leg_center, Vector3.LEFT, "front_left")
	var leg_index: int = int(wolf._joints["FrontLeg1_L"][0])
	check(not wolf.dead and wolf.health > 0 and game.defeats == defeats_before, "A severe leg hit leaves a living wolf and does not grant an early defeat reward")
	check(wolf.severed_legs.has("front_left") and wolf._skeleton.get_bone_pose_scale(leg_index).x < 0.02 and wolf.model.has_node("WoundStump_front_left"), "Severing changes the actual skinned limb and adds visible stump geometry")
	check(game.gore.effect_counts().limbs >= 1 and wolf.injury_speed_scale <= 0.34 and wolf.bleeding_rate >= 12.0, "Limb loss creates a detached leg, severe bleeding and impaired movement")
	var detached: Node3D = game.gore.get_node_or_null("SeveredWolfLeg")
	check(detached != null and is_equal_approx(detached.scale.x, wolf.size_scale), "The detached limb retains the actual individual wolf's size")
	var injured_health: float = wolf.health
	tick(wolf, 1.0)
	check(not wolf.dead and wolf.health < injured_health and game.gore.effect_counts().pools >= 2, "The injured wolf survives briefly while bleeding onto the ground")
	tick(wolf, float(wolf.health) / float(wolf.bleeding_rate) + 0.1)
	check(wolf.dead and game.defeats == defeats_before + 1, "Blood loss eventually defeats the wolf and awards it once")
	wolf.damage(999.0)
	tick(wolf, 1.0)
	check(game.defeats == defeats_before + 1 and not wolf.is_queued_for_deletion() and wolf.is_in_group("wolf_corpses"), "A blood-loss corpse persists and cannot grant duplicate rewards")
	for zone: String in ["head", "body"]:
		var target := make_wolf(Vector3(4, 0, 4))
		var hit_shape: CollisionShape3D = target._hit_zones[zone].get_child(0)
		target.receive_hit(115.0, hit_shape.global_position, Vector3.FORWARD, zone)
		check(target.dead, "A musket %s hit remains immediately lethal" % zone)
	var hunter := make_wolf(Vector3(0, 0, 1.0))
	game.player.position = Vector3.ZERO
	game.player.visibility = 1.0
	hunter.rotation.y = PI
	hunter.hear_gunshot(game.player.position)
	hunter._time = 1.0
	hunter._warning_until = 0.0
	hunter._attack_cooldown = 0.0
	hunter._enter_state("charge", 2.0)
	navigation.call("field", 0.0, 0.0)
	game.allow_struggle = false
	hunter._physics_process(1.0 / 60.0)
	check(game.bite_damage == 0.0 and hunter.behavior == "retreat", "A root-rejected latch backs off without bypassing escape grace through a legacy bite")
	game.allow_struggle = true
	hunter._attack_cooldown = 0.0
	hunter._enter_state("charge", 2.0)
	hunter._physics_process(1.0 / 60.0)
	check(game.struggle_wolf == hunter and hunter.behavior == "maul", "A successful close attack latches into the root-owned struggle instead of immediately retreating")
	var mate := make_wolf(Vector3(0.8, 0, 1.0))
	mate.hear_gunshot(game.player.position)
	mate._time = 1.0
	mate._warning_until = 0.0
	mate._enter_state("charge", 2.0)
	for frame: int in range(180):
		hunter._physics_process(1.0 / 60.0)
		mate._physics_process(1.0 / 60.0)
		if frame % 45 == 0:
			game.receive_wolf_bite(14.0, hunter.position)
	check(hunter.behavior == "maul" and game.bite_damage >= 56.0 and game.struggle_starts == 1, "The sustained latch allows repeated root bite damage while another wolf avoids piling on")
	game.end_wolf_struggle(true)
	check(hunter.behavior == "retreat" and hunter._attack_cooldown >= 3.0, "Breaking free produces a bounded retreat and cooldown")
	mate.free()
	tick(hunter, 7.0)
	check(game.struggle_starts >= 2, "A surviving wolf can renew its attack after the escape cooldown")
	var gripping_leg: CollisionShape3D = hunter._hit_zones.front_left.get_child(0)
	hunter.receive_hit(115.0, gripping_leg.global_position, Vector3.FORWARD, "front_left")
	check(not game.is_struggling() and not hunter.dead and hunter.behavior != "maul", "A severe limb wound breaks the grip in both the wolf and root struggle state")
	game.start_wolf_struggle(hunter)
	hunter._enter_state("maul", 99.0)
	game.safe = true
	tick(hunter, 0.2)
	check(hunter.behavior != "maul" and not game.is_struggling(), "Entering safety releases the wolf and root struggle state together")
	for index: int in range(14):
		var corpse := make_wolf(Vector3(8, 0, 8))
		corpse.damage(999.0)
	var live_corpses: int = 0
	for corpse: Node in get_nodes_in_group("wolf_corpses"):
		live_corpses += int(not corpse.is_queued_for_deletion())
	check(live_corpses <= 12, "Persistent corpse count stays within its hard budget")
	game.queue_free()
	await process_frame
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print("%s: %d wolf hunting, injury and struggle checks." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
