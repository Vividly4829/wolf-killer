extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
 game=preload("res://scripts/main.gd").new(); game.progress.transient=true
 root.add_child(game); game.start_free_play(); game.set_process(false)
 game.player.set_physics_process(false); AudioServer.set_bus_mute(0,true)
 game.rituals.boons={"wolf":2,"bear":2,"angel":3}
 var entries: Array=game.rituals.status_entries()
 assert(entries[0].description=="+90 damage per hit")
 assert(entries[1].description=="+50% weapon damage")
 assert(entries[2].description=="36% less incoming damage")
 for species in game.rituals.BOONS: game.rituals.boons[species]=2
 game.supernatural.soul_cost=2
 game.player.bleeding_rate=1; game.player.leg_injury=1
 game.hud_detail_left=100
 root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
 await process_frame; await process_frame
 assert(not game.rituals.ui.visible)
 assert(game.rituals.status_entries().size()==13)
 print("RITUAL_STATUS_PASS: totals, stacks, full roster, no scattered label")
 quit()
