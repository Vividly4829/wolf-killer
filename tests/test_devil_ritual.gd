extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures+=1
func run() -> void:
 game=preload("res://scripts/main.gd").new(); game.progress.transient=true; root.add_child(game)
 game.start_free_play(); game.set_process(false); game.player.set_physics_process(false)
 game.campaign.set_process(false); game.supernatural.set_process(false); game.rituals.set_process(false)
 AudioServer.set_bus_mute(0,true)
 var point:=Vector3(140,80,140)
 game.player.position=point+Vector3(0,0,10)
 var devil=game.supernatural.spawn("devil",point); devil.set_physics_process(false); devil.target=game.player
 devil.shoot_pepperbox()
 check(game.nodes_in_group("enemy_bolts").is_empty() and not devil.pepperbox.visible,"peaceful devil does not draw or shoot")
 devil.hear(game.player.position); check(not devil.alerted,"noise does not provoke devil")
 devil.damage(1,true); devil.reaction.down=0
 await physics_frame; await physics_frame
 var wall:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new()
 box.size=Vector3(8,5,1); shape.shape=box; wall.add_child(shape); game.add_child(wall); wall.position=point+Vector3(0,1,5)
 await physics_frame; await physics_frame
 devil.shoot_pepperbox(); check(devil.pepper_rounds==6,"wall blocks hostile devil fire")
 wall.queue_free(); await physics_frame; await physics_frame
 for i in 6:
  devil.cooldown=0; devil.shoot_pepperbox()
 check(devil.pepper_rounds==0 and is_equal_approx(devil.cooldown,devil.PEPPERBOX_RELOAD),"six pepperbox shots then reload")
 devil.shoot_pepperbox(); check(devil.pepper_rounds==0,"cannot fire during reload")
 devil.cooldown=0; devil.shoot_pepperbox(); check(devil.pepper_rounds==5,"can fire again after reload")
 for bolt in game.nodes_in_group("enemy_bolts"):
  bolt.set_physics_process(false); bolt.queue_free()
 game.health=game.maximum_health(); game.mode="playing"
 devil.health=71; check(not game.rituals.eligible(devil),"71 HP cannot be sacrificed")
 devil.health=70; check(game.rituals.eligible(devil),"living devil at 70 HP can be sacrificed")
 devil.cooldown=0; var rounds: int=devil.pepper_rounds; devil.shoot_pepperbox()
 check(devil.pepper_rounds==rounds,"incapacitated devil cannot fire")
 game.player.position=point+Vector3(0,0,2)
 await physics_frame; await physics_frame
 check(game.rituals.start(1,devil.get_instance_id()),"devil ritual starts in reach")
 game.rituals._process(4.1)
 check(devil.dead and game.rituals.count("devil")==1,"completed sacrifice grants Infernal Fortune")
 var before: int=game.progress.money
 game.coop.award(100)
 check(game.progress.money-before==150,"one stack gives 50 percent extra credits")
 game.rituals.grant("devil",0); before=game.progress.money; game.coop.award(100)
 check(game.progress.money-before==200,"two stacks double earned credits")
 var remote:=Node3D.new(); game.add_child(remote); remote.set_meta("ritual_boons",{"devil":3}); game.coop.avatars[42]=remote
 check(game.coop.reward_amount(100,42)==250 and game.coop.reward_amount(100,1)==200,"each player uses their own ritual stacks")
 game.coop.avatars.erase(42); remote.queue_free()
 check(game.rituals.status_entries()[0].description=="+100% earned credits","status explains total bonus")
 print("DEVIL_RITUAL_COMPLETE failures=",failures)
 quit(1 if failures else 0)
