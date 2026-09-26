extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	create_timer(100).timeout.connect(func(): print("TEST TIMEOUT"); quit(2))
	var progress=load("res://scripts/progress_store.gd").new()
	progress.save_path="user://wallet_migration_test.cfg"
	var cfg:=ConfigFile.new(); cfg.set_value("progress","money",5432); cfg.set_value("progress","owned",[0,2]); cfg.save(progress.save_path)
	progress.load_progress(); check(progress.money==0 and progress.owned.has(2),"Old cash reset; inventory retained")
	progress.earn(17); progress.load_progress(); check(progress.money==17,"New earnings persist after migration")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path+suffix))
	var game=load("res://scripts/main.gd").new(); game.progress.transient=true; game.progress.save_path="user://unused_rabbit_test.cfg"
	root.add_child(game); game.start_run(); game.player.position=game.world.exterior_rally_point; game.begin_wave()
	check(not game.world.firing_allowed(game.world.bed_wake_position),"Cabin blocks firing")
	var outline:PackedVector2Array=game.world.cabin_outline
	var center:=Vector2.ZERO
	for p in outline: center+=p
	center/=outline.size()
	var edge:Vector2=(outline[0]+outline[1])*.5
	var outward:Vector2=(edge-center).normalized()
	var near:Vector2=edge+outward*1.5; var far:Vector2=edge+outward*5
	check(not game.world.firing_allowed(Vector3(near.x,5,near.y)),"Firing blocked beside cabin")
	check(game.world.firing_allowed(Vector3(far.x,5,far.y)),"Firing allowed beyond cabin apron")
	var rabbits:Array=game.nodes_in_group("wildlife").filter(func(a):return a.species=="rabbit")
	check(rabbits.size()>=3,"Multiple ambient rabbits")
	if rabbits.is_empty(): quit(1); return
	check(rabbits[0].max_health==45 and rabbits[0].limbs.parts.size()==4,"Rabbit health and four limb zones")
	check(game.campaign.Catalog.wave(7).hunt.has("rabbit"),"Rabbit hunting objective")
	for event in ["confederates","nazis"]:
		game.level=19; game.campaign.event=event; game.campaign.event_origin=game.world.exterior_rally_point
		var before:int=game.nodes_in_group("campaign_threats").size()
		game.campaign.launch_event(); check(game.nodes_in_group("campaign_threats").size()==before,event+" excluded before 20")
		game.level=20; game.campaign.launch_event()
		check(game.nodes_in_group("campaign_threats").size()==before+4,event+" contains exactly four soldiers")
	game.campaign.event="wererabbit"; game.campaign.launch_event()
	var monsters:Array=game.nodes_in_group("wildlife").filter(func(a):return a.species=="wererabbit")
	check(monsters.size()==1 and monsters[0].max_health==320,"Large cursed rabbit spawned")
	var beast:Node3D=monsters[0]; beast.health=20
	check(game.rituals.eligible(beast),"Wounded were-rabbit can be sacrificed")
	game.rituals.grant("wererabbit",0); game.rituals.grant("wererabbit",0)
	check(is_equal_approx(game.rituals.factor("jump"),2.0),"Were-rabbit ritual stacks jump height")
	check(not game.rituals.status_entries().is_empty(),"New ritual descriptions render")
	var report:Dictionary=load("res://scripts/wildlife_anatomy.gd").trace("rabbit",Vector3(0,.4,1),Vector3.BACK*-1,2)
	check(report.organs.has("heart"),"Rabbit heart matches body")
	var reports:Array[Dictionary]=[report]
	game.shot_review.wildlife.review(reports)
	game.campaign.job=game.campaign.Catalog.wave(7)
	game.campaign.done={"hunt_rabbit":0,"sites":0,"search":0}
	game.intermission=false; game.campaign.running=true
	rabbits[0].damage(1000)
	check(game.campaign.done.get("hunt_rabbit",0)==1,"Rabbit kill advances food objective")
	await process_frame
	print("RABBITS_PATROLS_FAILURES ",failures)
	quit(1 if failures else 0)
