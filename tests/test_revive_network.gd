extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var host:=OS.get_cmdline_user_args().has("--host")
 game=preload("res://scripts/main.gd").new(); game.progress.transient=true; root.add_child(game)
 game.set_process(false); game.player.set_physics_process(false); game.supernatural.set_process(false)
 game.coop.port=27988
 if host: game.coop.host_session()
 else: game.coop.join_session("127.0.0.1")
 var deadline:=Time.get_ticks_msec()+45000
 while game.coop.avatars.is_empty() and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
 if game.coop.avatars.is_empty(): push_error("No network partner"); quit(1); return
 if not host: game.coop.set_process(false)
 await create_timer(2).timeout
 if host:
  var id: int=game.coop.avatars.keys()[0]
  game.player.position=Vector3(140,80,140)
  game.coop.avatars[id].position=Vector3(140,80,142)
  game.coop.send_to(id,"correct_position",[Vector3(140,80,142)])
  while game.coop.avatars[id].health>0 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
  if not game.coop.revive_teammate(1,id): push_error("Host revive failed"); quit(1); return
  await create_timer(1).timeout
  if game.coop.avatars[id].health!=10: push_error("Remote HP not retained"); quit(1); return
  game._apply_health_damage(10000,false)
  while game.health<=0 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
  if game.health!=10 or game.mode!="playing": push_error("Guest to host revive failed"); quit(1); return
  await create_timer(1).timeout
 else:
  game._apply_health_damage(10000,false)
  while game.health<=0 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
  if game.health!=10 or game.mode!="playing": push_error("Client revive RPC failed"); quit(1); return
  while game.coop.avatars[1].health>0 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
  game.interact_shop()
  await create_timer(.5).timeout
  if game.coop.avatars[1].health!=10: push_error("Host revive snapshot failed"); quit(1); return
 print("NETWORK_REVIVE_PASS ","host" if host else "client")
 game.coop.leave(); quit()
