extends SceneTree

const WolfScript = preload("res://scripts/wolf.gd")
const PlayerScript = preload("res://scripts/player.gd")
const NavScript = preload("res://scripts/island_nav.gd")

class SoundSpy extends Node:
	var growls := 0
	func play_at(kind: String, _at: Vector3, _volume: float = 0.0, _individual_pitch: float = 1.0) -> void:
		if kind == "growl":
			growls += 1

class Ground extends Node3D:
	var nav: RefCounted
	var exterior_rally_point := Vector3(0, 0, 7)
	func is_safe_position(_at: Vector3) -> bool:
		return false

class PackGame extends Node3D:
	var player: Node3D
	var world: Node3D
	var sounds: Node
	var health := 100000.0
	var reload_left := 0.0
	var safe := false
	var bite_count := 0
	var defeats := 0
	func is_playing() -> bool:
		return true
	func is_player_safe() -> bool:
		return safe
	func damage_player(amount: float) -> void:
		if not safe:
			health -= amount
			bite_count += 1
	func wolf_defeated(_wolf: Node3D) -> void:
		defeats += 1

var checks := 0
var failures: Array[String] = []
var game: PackGame
var pack: Array[Node3D] = []
var launches: Array[Dictionary] = []
var seen_launches: Dictionary = {}
var maximum_chargers := 0

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	game = PackGame.new()
	root.add_child(game)
	game.world = Ground.new()
	game.add_child(game.world)
	var navigation := NavScript.new()
	var heights: Array = []
	heights.resize(161 * 161)
	heights.fill(0.0)
	var blocked := PackedByteArray()
	blocked.resize(161 * 161)
	blocked.fill(0)
	navigation.setup({"width": 161, "depth": 161, "cellSize": 0.25, "origin": [-20.0, -20.0], "heights": heights, "blocked": blocked})
	navigation.field(0, 0)
	game.world.nav = navigation
	game.sounds = SoundSpy.new()
	game.add_child(game.sounds)
	game.player = PlayerScript.new()
	game.add_child(game.player)
	game.player.configure(game, navigation)
	game.player.reset_at(Vector3.ZERO)
	game.player.set_physics_process(false)
	for index in 6:
		var wolf := WolfScript.new()
		wolf.configure(game, navigation, 1, 8401 + index)
		game.add_child(wolf)
		wolf.rng.seed = 8401 + index
		wolf._boldness = 0.4 + index * 0.05
		var angle := TAU * float(index) / 6.0
		wolf.position = Vector3(cos(angle), 0, sin(angle)) * (8.0 + float(index % 2))
		pack.append(wolf)
	# This fixture exercises an alerted pack. A real audible shot establishes
	# knowledge; the separate hunting suite tests whether a hidden player is found.
	for wolf in pack:
		wolf.hear_gunshot(game.player.position)
	await step_frames(3)
	var assignments: Dictionary = {}
	for wolf in pack:
		assignments[wolf.get_instance_id()] = [wolf.pack_slot, wolf.flank_side]
	await step_frames(1080)
	check(game.sounds.growls >= 1, "The pack gives an audible warning before sustained pressure")
	check(game.bite_count >= 4, "A six-wolf pack repeatedly bites instead of endlessly circling")
	check(maximum_chargers <= 2, "No more than two wolves rush simultaneously")
	check(launches.size() >= 5, "The pack repeatedly commits to fresh attacks")
	launches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))
	var minimum_gap := INF
	var attackers: Dictionary = {}
	for index in launches.size():
		attackers[launches[index].wolf] = true
		if index > 0:
			minimum_gap = minf(minimum_gap, float(launches[index].time) - float(launches[index - 1].time))
	check(minimum_gap >= 0.70, "Fresh lunges are staggered rather than synchronized")
	check(attackers.size() >= 3, "Several pack members take turns applying attack pressure")

	# A casualty must provoke a local reaction without scrambling every survivor.
	var reactions_before := 0
	for wolf in pack:
		reactions_before += int(wolf.pack_reaction_count)
	pack[0].damage(1000.0)
	await step_frames(3)
	var reactions_after := 0
	var stable := true
	for wolf in pack:
		if not is_instance_valid(wolf) or wolf.dead:
			continue
		reactions_after += int(wolf.pack_reaction_count)
		stable = stable and assignments[wolf.get_instance_id()] == [wolf.pack_slot, wolf.flank_side]
	check(reactions_after > reactions_before, "A nearby packmate's death visibly changes survivor behavior")
	check(stable, "A casualty preserves the surviving wolves' positions in the pack")
	var bites_before := game.bite_count
	await step_frames(900)
	check(game.bite_count > bites_before, "The surviving pack resumes attacks after briefly reassessing")

	var survivor: Node3D = null
	for wolf in pack:
		if not is_instance_valid(wolf) or wolf.dead:
			continue
		if survivor == null:
			survivor = wolf
		else:
			wolf.damage(1000.0)
	bites_before = game.bite_count
	await step_frames(1200)
	check(is_instance_valid(survivor) and not survivor.dead and game.bite_count > bites_before, "A lone survivor still commits after losing its pack")
	game.safe = true
	bites_before = game.bite_count
	await step_frames(300)
	check(game.bite_count == bites_before, "Shelter interrupts coordinated aggression and prevents bites")
	var report := {"checks": checks, "failures": failures, "launches": launches, "minimum_launch_gap": minimum_gap, "maximum_chargers": maximum_chargers, "distinct_attackers": attackers.size(), "bites": game.bite_count}
	var output := FileAccess.open("res://qa/pack_behavior.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	game.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d pack behavior checks; launch gap %.2fs, max chargers %d, attackers %d." % ["PASS" if failures.is_empty() else "FAIL", checks, minimum_gap, maximum_chargers, attackers.size()])
	quit(0 if failures.is_empty() else 1)

func step_frames(count: int) -> void:
	for frame in count:
		await physics_frame
		var charging := 0
		for wolf in pack:
			if not is_instance_valid(wolf) or wolf.dead:
				continue
			charging += int(wolf.behavior == "charge")
			if wolf.last_charge_at >= 0 and not seen_launches.has(wolf.charge_serial):
				seen_launches[wolf.charge_serial] = true
				launches.append({"time": wolf.last_charge_at, "serial": wolf.charge_serial, "wolf": wolf.get_instance_id()})
		maximum_chargers = maxi(maximum_chargers, charging)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
