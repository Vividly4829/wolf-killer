extends SceneTree

const GameScript = preload("res://scripts/main.gd")

class TestNavigation extends RefCounted:
	var reachable := PackedInt32Array()
	var points: Array[Vector3] = []
	var queries := 0
	func set_points(values: Array[Vector3]) -> void:
		points = values
		reachable = PackedInt32Array(range(points.size()))
		queries = 0
	func point(index: int) -> Vector3:
		queries += 1
		return points[index]

class TestWorld extends Node3D:
	var wolf_nav := TestNavigation.new()
	var safe_points: Array[Vector3] = []
	func is_safe_position(point: Vector3) -> bool:
		return point in safe_points

class SpawnGame extends GameScript:
	func _add_wolf_at(point: Vector3, _profile_seed: int = -1) -> void:
		var wolf := Node3D.new()
		wolf.position = point
		wolves.append(wolf)
		pending_spawns -= 1
	func clear_pack() -> void:
		for wolf in wolves:
			wolf.free()
		wolves.clear()

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	seed(70201)
	var game := SpawnGame.new()
	var world := TestWorld.new()
	game.world = world
	game.player = Node3D.new()
	# Do not enter the scene tree: isolate selection from loading/rendering/AI.
	game.pending_spawns = 1
	game._spawn_wolf()
	check(game.wolves.is_empty() and game.pending_spawns == 1, "An empty navigation region leaves the pending spawn intact")
	world.wolf_nav.set_points([Vector3(27.9, 50, 0), Vector3(4, 0, 0)])
	game._spawn_wolf()
	check(game.wolves.is_empty() and game.pending_spawns == 1, "Height cannot make a nearby horizontal spawn eligible")
	world.wolf_nav.set_points([Vector3(60, 2, 0)])
	game._spawn_wolf()
	check(game.wolves.size() == 1 and game.wolves[0].position.x == 60, "A shore with no 28–42m candidate uses a farther point")
	game.clear_pack()
	world.wolf_nav.set_points([Vector3(28, 0, 0), Vector3(42, 0, 0), Vector3(60, 0, 0)])
	for trial in 32:
		game.pending_spawns = 1
		game._spawn_wolf()
		check(game.wolves.size() == 1 and game.wolves[0].position.x in [28.0, 42.0], "Preferred band wins over a farther fallback (%d)" % trial)
		game.clear_pack()
	world.wolf_nav.set_points([Vector3(30, 0, 0), Vector3(31, 0, 0), Vector3(-30, 0, 0), Vector3(0, 0, 35)])
	world.safe_points = [Vector3(-30, 0, 0)]
	game._add_wolf_at(Vector3(30, 0, 0))
	game.pending_spawns = 1
	game._spawn_wolf()
	check(game.wolves.size() == 2 and game.wolves[1].position == Vector3(0, 0, 35), "Spawn selection excludes occupied, crowded and safe-zone points")
	game.clear_pack()
	world.safe_points.clear()
	var points: Array[Vector3] = []
	for index in 10000:
		var angle := TAU * float(index) / 10000.0
		points.append(Vector3(cos(angle), 0, sin(angle)) * 35.0)
	world.wolf_nav.set_points(points)
	game.pending_spawns = 1
	game._spawn_wolf()
	check(game.wolves.size() == 1 and world.wolf_nav.queries == 1, "A normal eligible region needs one point query rather than a full-island scan")
	game.clear_pack()
	# A lone preferred cell amongst crowded cells must never force a close spawn.
	world.wolf_nav.set_points([Vector3(1, 0, 0), Vector3(30, 0, 0), Vector3(60, 0, 0)])
	world.safe_points = [Vector3(30, 0, 0), Vector3(60, 0, 0)]
	game.pending_spawns = 1
	game._spawn_wolf()
	check(game.wolves.is_empty() and game.pending_spawns == 1, "No eligible location keeps the wolf pending instead of spawning unsafely")
	game.player.free()
	world.free()
	game.free()
	for failure in failures:
		push_error(failure)
	print("%s: %d spawn selection checks; %d failed." % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures.append(description)
