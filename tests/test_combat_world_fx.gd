extends SceneTree
var failures:=0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	game.set_mode("playing"); game.shot_review._process(0); game.hud._process(0)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/combat-"+label+".png")
func grenade(origin: Vector3) -> Node3D:
	game.shot_review.begin_shot(true)
	var bolt=preload("res://scripts/crossbow_bolt.gd").new(); game.add_child(bolt)
	bolt.launch(game,origin,Vector3.DOWN,game.WeaponCatalog.weapon(24)); bolt.set_physics_process(false)
	return bolt
func run() -> void:
	game=preload("res://scripts/main.gd").new(); game.progress.transient=true
	game.progress.save_path="user://combat_fx_test_%d.cfg"%OS.get_process_id()
	root.add_child(game); game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	AudioServer.set_bus_mute(0,true); root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720)
	for actor in game.wolves+game.nodes_in_group("wildlife"): actor.set_physics_process(false)
	var fx=game.combat_fx
	check(not fx.vegetation.is_empty(),"tree canopies and low vegetation indexed for local reactions")
	var plant: Dictionary=fx.vegetation.values()[0][0]
	fx.ballistic(PackedVector3Array([plant.center-Vector3.RIGHT*2,plant.center+Vector3.RIGHT*2]),"test-foliage")
	check(not fx.disturbed.is_empty() and fx.get_children().any(func(n):return str(n.name).begins_with("LeafBurst")),"shots through leaves cause debris and a localized sway")
	var count: int=fx.get_child_count()
	fx.ballistic(PackedVector3Array([plant.center,plant.center+Vector3.RIGHT]),"test-foliage")
	check(fx.get_child_count()==count,"pellets do not duplicate an entire smoke trail")
	for kind in ["wood","soil","stone"]: fx.impact(Vector3(150,80,150),Vector3.UP,kind)
	check(fx.get_children().any(func(n):return str(n.name).begins_with("BulletScar")),"solid surfaces retain a visible impact scar")
	game.player.weapon.flash()
	check(game.player.weapon.find_children("*","MeshInstance3D",true,false).any(func(n): return n.mesh is CylinderMesh and n.material_override is StandardMaterial3D and n.material_override.emission_enabled and n.mesh.height>.2),"firing creates tapered flame geometry at the barrel")
	var slope:=StaticBody3D.new(); slope.collision_layer=1; game.add_child(slope); slope.position=Vector3(150,80,150); slope.rotation.z=.4
	var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(12,.15,12); shape.shape=box; slope.add_child(shape)
	await physics_frame; await physics_frame
	game.player.position=Vector3(170,83,150)
	var bomb=grenade(Vector3(150,83,150)); bomb.velocity=Vector3.DOWN*50; bomb._physics_process(.1)
	check(bomb.landed and bomb.position.y>80,"fast grenade sweeps against an inclined ground surface")
	var resting: Vector3=bomb.position; bomb._physics_process(.1)
	check(bomb.position==resting and not bomb.get_meta("detonated",false),"grenade rests above the slope while its fuse continues")
	var deer=game.nodes_in_group("wildlife").filter(func(n):return n.species=="deer")[0]; deer.position=Vector3(152,82,150)
	bomb.detonate(); game.shot_review._process(0)
	var path: Dictionary=game.shot_review.displayed().trajectories.back()
	check(path.has("blast") and path.blast.radius==6 and path.blast.targets.size()>0,"review stores actual blast center, radius and affected targets")
	check(game.shot_review.replay.content.has_node("BlastRadius"),"X-ray replay renders blast radius at world scale")
	check(deer.health<70,"grounded grenade can damage an exposed animal on the slope")
	game.hud_detail_left=8; await capture("blast-xray")
	var flying=grenade(Vector3(150,95,150)); flying.distance=35; flying.velocity=Vector3.RIGHT; flying._physics_process(.1)
	check(not flying.landed and flying.position.y<95,"grenade keeps falling after exceeding its nominal throw range")
	flying.queue_free(); slope.queue_free(); await physics_frame
	game.level=10; game.campaign.event="musketeers"; game.campaign.event_origin=game.world.exterior_rally_point; game.campaign.launch_event()
	check(game.nodes_in_group("campaign_threats").filter(func(n):return n.species=="musketeer").is_empty(),"musketeer platoons do not appear before level 11")
	game.level=11; game.campaign.event="musketeers"; game.campaign.launch_event()
	var squad=game.nodes_in_group("campaign_threats").filter(func(n):return n.species=="musketeer")
	check(squad.size()==5,"level 11 encounter creates a five-soldier platoon")
	for soldier in squad: soldier.set_physics_process(false)
	var soldier=squad[0]; soldier.position=Vector3(150,83,140); soldier.target=game.player; game.player.position=Vector3(150,83,150)
	check(soldier.max_health==110 and soldier.warning>=3 and squad[1].warning>soldier.warning,"human anatomy and staggered volley warning are configured")
	soldier.shoot()
	check(soldier.cooldown>=7.5 and game.nodes_in_group("enemy_bolts").any(func(n):return n.spec.id=="enemy_musket"),"musketeer fires a swept musket ball then enters a long reload")
	var bullet=game.nodes_in_group("enemy_bolts").filter(func(n):return n.spec.id=="enemy_musket")[0]
	bullet.set_physics_process(false)
	var wall:=StaticBody3D.new(); wall.collision_layer=1; game.add_child(wall); wall.position=Vector3(150,84,145)
	var wall_shape:=CollisionShape3D.new(); var wall_box:=BoxShape3D.new(); wall_box.size=Vector3(5,4,.3); wall_shape.shape=wall_box; wall.add_child(wall_shape)
	await physics_frame; await physics_frame
	bullet.set_physics_process(false); bullet.position=Vector3(150,84,141); bullet.velocity=Vector3.BACK*150
	var hp: float=game.health; bullet._physics_process(.1)
	check(bullet.is_queued_for_deletion() and game.health==hp,"musketeer bullets cannot shoot through walls")
	game.shot_review.close_review()
	game.player.camera.global_position=soldier.position+Vector3(3,2,5)
	game.player.camera.look_at(soldier.position+Vector3.UP,Vector3.UP)
	await capture("musketeer")
	for i in 90: fx.impact(Vector3(150,80,150),Vector3.UP,"soil")
	check(fx.get_child_count()<=64,"effect count stays bounded under sustained fire")
	game.restore_campaign(); game.queue_free(); await process_frame; await process_frame
	print("COMBAT_WORLD_FX failures=",failures); quit(1 if failures else 0)
