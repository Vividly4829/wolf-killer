extends SceneTree

# Rendering fixture for the real game's night lighting, wounds, latch and bed UI.
# --qa prevents focus pausing; the override avoids starting main's parallel tour.
class PreviewGame extends "res://scripts/main.gd":
	func _run_visual_qa() -> void:
		pass

var game: Node3D
var save_path: String

func _initialize() -> void:
	call_deferred("run_preview")

func frames(count: int) -> void:
	for frame: int in count:
		await physics_frame

func aim_at(point: Vector3) -> void:
	var direction: Vector3 = (point - game.player.camera.global_position).normalized()
	game.player.yaw = atan2(-direction.x, -direction.z)
	game.player.pitch = asin(direction.y)
	game.player._update_rotation()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	game._capture("survival_" + label)
	print("CAPTURE: survival_" + label)

func run_preview() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("preview_survival requires a graphical renderer.")
		quit(1)
		return
	seed(74107)
	AudioServer.set_bus_mute(0, true)
	game = PreviewGame.new()
	root.add_child(game)
	save_path = "user://preview_survival_%s.cfg" % OS.get_process_id()
	game.progress.save_path = save_path
	await frames(15)
	game.start_run()
	game.dialogue_left = 0.0
	game.intermission = false
	game.pending_spawns = 1
	game.wave_total = 2
	game.player.reset_at(game.world.nav.point(game.world.nav.nearest(-3.0, 8.75, 2.0)))
	var point: Vector3 = game.world.wolf_nav.point(game.world.wolf_nav.nearest(-0.5, 9.0, 2.0))
	game._add_wolf_at(point)
	var wounded: Node3D = game.wolves.back()
	wounded.set_physics_process(false)
	wounded.rotation.y = 0.1
	aim_at(wounded.position + Vector3.UP * 0.45)
	game.notice_left = 0.0
	await frames(8)
	var hit_point: Vector3 = wounded._hit_zones.front_right.get_child(0).global_position
	wounded.receive_hit(115.0, hit_point, (hit_point - game.player.camera.global_position).normalized(), "front_right")
	for step: int in 18:
		wounded._physics_process(1.0 / 60.0)
		await physics_frame
	wounded.rotation.y = 0.1
	aim_at(wounded.position + Vector3.UP * 0.38)
	await frames(5)
	await capture("injury")
	# A fresh nearby wolf performs the real charge-to-latch transition.
	game.pending_spawns = 1
	var maul_point: Vector3 = game.world.wolf_nav.point(game.world.wolf_nav.nearest(game.player.position.x, game.player.position.z + 1.15, 1.0))
	game._add_wolf_at(maul_point)
	var attacker: Node3D = game.wolves.back()
	attacker.hear_gunshot(game.player.position)
	attacker._warning_until = 0.0
	attacker._attack_cooldown = 0.0
	attacker._enter_state("charge", 2.0)
	game.struggle_grace = 0.0
	await frames(100)
	print("PREVIEW_MAUL: ", game.is_struggling(), " state=", attacker.behavior, " health=", game.health)
	await capture("maul")
	game.end_wolf_struggle(true)
	for wolf: Node3D in game.wolves.duplicate():
		wolf.damage(999.0)
	await frames(35)
	print("PREVIEW_REST: mode=", game.mode, " safe=", game.is_player_safe(), " health=", game.health)
	await capture("bed_rest")
	await frames(220)
	print("PREVIEW_AWAKE: mode=", game.mode, " safe=", game.is_player_safe(), " health=", game.health, " wounds=", game.player.bleeding_rate)
	await capture("bed_awake")
	game.queue_free()
	await process_frame
	await process_frame
	await process_frame
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("SURVIVAL_VISUAL_QA_COMPLETE")
	quit(0)
