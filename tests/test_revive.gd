extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures+=1
func run() -> void:
 var original=load("res://scripts/main.gd").new(); original.progress.transient=true; root.add_child(original)
 var session=load("res://scripts/split_session.gd").new()
 session.secondary_save_path="user://revive_test_%d.cfg"%OS.get_process_id(); root.add_child(session)
 await session.launch(original)
 var host=session.games[0]; var guest=session.games[1]
 for game in [host,guest]:
  game.progress.transient=true; game.set_process(false); game.player.set_physics_process(false); game.coop.set_process(false)
  game.supernatural.set_process(false); game.campaign.set_process(false)
 var p:=Vector3(140,80,140)
 host.player.position=p; guest.player.position=p+Vector3(0,0,2)
 host.coop.avatars[2].position=guest.player.position; guest.coop.avatars[1].position=p
 guest.player.bleeding_rate=1; guest.player.leg_injury=.5
 guest._apply_health_damage(10000,false)
 check(guest.mode=="waiting" and host.coop.avatars[2].health==0,"guest down reaches host without ending live teammate run")
 await physics_frame; await physics_frame
 check(host.coop.revive_target()==2 and "REVIVE" in host.interaction_prompt(),"nearby downed teammate has revive prompt")
 host.interact_shop()
 check(guest.health==10 and guest.mode=="playing" and host.coop.avatars[2].health==10,"P1 revives P2 at 10 HP")
 check(guest.player.bleeding_rate==0 and guest.player.leg_injury==.5,"revival stops bleeding but preserves other injuries")
 var rev: int=guest.coop.revive_revision
 host.coop.receive_local("report_down",[host.coop.generation,rev-1],2)
 host.coop.receive_local("pose",[guest.player.position,0.0,false,0.0,0.0,0,false,host.coop.generation,rev-1],2)
 check(host.coop.avatars[2].health==10,"stale pre-revival packets cannot down revived player")
 check(not host.coop.revive_teammate(1,2),"living teammate cannot be revived twice")
 host._apply_health_damage(10000,false); guest.coop.avatars[1].health=0
 check(host.mode=="waiting","host can wait while guest survives")
 guest.interact_shop()
 check(host.health==10 and host.mode=="playing","P2 revives P1 through authority request")
 guest._apply_health_damage(10000,false)
 host.coop.avatars[2].position=p+Vector3(0,0,8)
 check(not host.coop.revive_teammate(1,2),"distant revival rejected")
 host.coop.avatars[2].position=p+Vector3(0,0,2)
 var wall:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new()
 box.size=Vector3(6,4,.5); shape.shape=box; wall.add_child(shape); host.add_child(wall); wall.position=p+Vector3(0,1,1)
 await physics_frame; await physics_frame
 check(not host.coop.revive_teammate(1,2),"walls block revival")
 wall.queue_free(); await physics_frame; await physics_frame
 host.coop.receive_local("request_revive",[2,host.coop.generation],2)
 check(guest.health==0,"downed hunter cannot self revive")
 host._apply_health_damage(10000,false)
 check(host.mode=="dead" and guest.mode=="dead","both down still ends run")
 check(not host.coop.revive_teammate(1,2),"revival cannot bypass team wipe")
 print("REVIVE_COMPLETE failures=",failures)
 quit(1 if failures else 0)
