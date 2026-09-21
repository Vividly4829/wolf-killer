extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var game=preload("res://scripts/main.gd").new(); game.progress.save_path="user://limbs_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720); AudioServer.set_bus_mute(0,true)
	var controller=preload("res://scripts/animal_limbs.gd")
	var previous:=0.0; var proportion:=0.0
	for hp in [18.0,70.0,80.0,260.0,420.0,700.0]:
		var limit: float=controller.threshold(hp)
		check(limit>previous and limit/hp>proportion,"sever threshold and HP fraction grow at%dHP"%hp)
		previous=limit; proportion=limit/hp
	var animals: Array=[]
	for species in ["duck","goose","mink","deer","bear","werewolf"]:
		var animal: Node3D
		if species=="werewolf":
			animal=game.WolfScript.new(); animal.configure(game,game.world.wolf_nav,10,723); game.add_child(animal); animal.make_werewolf()
		elif species=="bear":
			animal=preload("res://scripts/campaign_threat.gd").new(); animal.game=game; animal.species=species; game.add_child(animal)
		else:
			animal=preload("res://scripts/wildlife.gd").new(); animal.game=game; animal.species=species; game.add_child(animal)
		animal.set_physics_process(false); animal.position=Vector3(140+animals.size()*3,80,140); animals.append(animal)
		check(animal.limbs.parts.size()==4,species+" has four dedicated limb hit zones")
		var zone: String=animal.limbs.parts.keys()[0]
		var point: Vector3=animal.limbs.points(animal.limbs.parts[zone])[0]
		animal.limbs._process(0)
		await physics_frame; await physics_frame
		var endpoints: Array=animal.limbs.points(animal.limbs.parts[zone])
		var probe: Vector3=endpoints[0].lerp(endpoints[1],.82)
		var query:=PhysicsRayQueryParameters3D.create(probe+Vector3.RIGHT*.5,probe-Vector3.RIGHT*.5,2); query.collide_with_areas=true
		var collision:=game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not collision.is_empty(),species+" lower limb has real projectile collision")
		var limit: float=controller.threshold(animal.max_health)
		animal.receive_ballistic_hit(limit*.4,point,Vector3.RIGHT,zone,1,1,.5)
		check(animal.limbs.severed.is_empty(),species+" subthreshold shot wounds without severing")
		animal.receive_ballistic_hit(limit*.65,point,Vector3.RIGHT,zone,1,1,.5)
		check(animal.limbs.severed.has(zone) and not animal.dead,species+" cumulative limb damage severs with brief survival")
		check(animal.bleeding_rate>0 and animal.limbs.speed_factor()<.7,species+" bleeds and slows after limb loss")
		animal.limbs._process(0)
		check(animal.limbs.areas[zone].collision_layer==0,species+" severed limb no longer collides")
		if species in ["deer","mink"]:
			var part: Dictionary=animal.limbs.parts[zone]
			check(part.skeleton.get_bone_pose_scale(part.bone).x<.01,species+" actual skinned limb is hidden")
		else: check(not animal.limbs.parts[zone].nodes[0].visible,species+" actual limb geometry hidden")
		if species in ["duck","goose"]:
			animal.limbs.hit("left_wing",limit*1.1,1,point,Vector3.RIGHT)
			check(animal.limbs.severed.has("left_wing") and not animal.limbs.parts.left_wing.nodes[0].visible,species+" wings also detach")
		if "--capture" in OS.get_cmdline_user_args():
			var camera:=Camera3D.new(); game.add_child(camera); camera.fov=40
			var size:=1.0 if species in ["deer","bear","werewolf"] else .3
			camera.position=animal.position+Vector3(2.6,1.5,2.2)*size
			camera.look_at(animal.position+Vector3.UP*(1.2 if species=="werewolf" else .7 if species in ["deer","bear"] else .2)); camera.make_current()
			game.hud.hide(); game.world.weather.hour=14; game.world.weather.apply()
			await create_timer(.15).timeout; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/severed-"+species+".png")
			camera.queue_free()
	var victim=animals[3]
	var replica=preload("res://scripts/wildlife.gd").new(); replica.game=game; replica.species="deer"; game.add_child(replica); replica.set_physics_process(false)
	game.coop.apply_animal_life(replica,{"health":0,"dead":true,"limbs":victim.limbs.snapshot()})
	check(replica.dead and replica.limbs.severed==victim.limbs.severed,"co-op applies severed geometry even on lethal snapshot")
	var wildlife_state: Dictionary=bytes_to_var(var_to_bytes(victim.limbs.snapshot()))
	check(wildlife_state.severed==victim.limbs.severed,"limb state survives network serialization")
	game.restore_campaign()
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path+suffix))
	game.queue_free(); await process_frame; await process_frame
	print("ALL_ANIMAL_LIMBS failures=",failures); quit(1 if failures else 0)
