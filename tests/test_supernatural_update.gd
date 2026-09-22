extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	game=preload("res://scripts/main.gd").new(); game.progress.transient=true; root.add_child(game)
	game.start_free_play(); game.set_process(false); game.player.set_physics_process(false); game.campaign.set_process(false)
	game.supernatural.set_process(false)
	game.rituals.grant("wolf",0); game.rituals.grant("wolf",0)
	check(is_equal_approx(game.rituals.factor("damage"),1.5),"two wolf stacks give +50%")
	game.rituals.grant("werewolf",0); game.rituals.grant("werewolf",0)
	check(is_equal_approx(game.maximum_health(),180),"two moon stacks give +80% HP")
	game.rituals.grant("angel",0); game.rituals.grant("angel",0)
	check(is_equal_approx(game.damage_at_distance(game.weapon_spec(),0),game.weapon_spec().damage+60),"angel bonus adds absolute damage after falloff")
	game.affliction.infected_wave=5; game.level=9
	check(game.affliction.blur_amount()>0,"lycanthropy blurs before next moon")
	game.level=10; check(game.affliction.blur_amount()==0,"blur ends on next moon")
	var fixture:=Vector3(140,80,140); game.player.position=fixture+Vector3(0,0,2)
	var bird=preload("res://scripts/wildlife.gd").new(); bird.game=game; bird.species="goose"; game.add_child(bird); bird.position=fixture; bird.set_physics_process(false)
	bird.health=1; bird.reaction._process(1)
	await physics_frame; await physics_frame
	var pose: Transform3D=bird.reaction.anatomy_transform()
	var center: Vector3=pose*Vector3(0,.24,0)
	var query:=PhysicsRayQueryParameters3D.create(center+Vector3(0,0,2),center-Vector3(0,0,2),2); query.collide_with_areas=true
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider.get_meta("wolf",null)==bird,"lying goose collider follows its visible body")
	check(center.y>fixture.y,"fallen body stays above ground")
	var devil=game.supernatural.spawn("devil",fixture+Vector3(4,0,0)); devil.set_physics_process(false)
	var human=preload("res://scripts/human_xray.gd")
	var brain: Vector3=human.ORGANS[0].center
	for organ in human.ORGANS:
		if organ.id=="brain": brain=organ.center
	var result: Dictionary=devil.receive_ballistic_hit(20,devil.to_global(brain),Vector3.RIGHT,"body",1,1,.3)
	check(is_equal_approx(devil.health,550) and not devil.dead,"1000 HP devil survives 450 brain hit")
	devil.alerted=false; game.player.position=devil.position+Vector3(0,0,1)
	await physics_frame; await physics_frame
	var hp: float=game.maximum_health(); var counts:=0
	for n in game.rituals.boons.values(): counts+=int(n)
	check(game.supernatural.deal(1),"nearby devil grants soul deal")
	var after:=0
	for n in game.rituals.boons.values(): after+=int(n)
	check(after==counts+3 and game.supernatural.soul_cost==1,"deal costs half base maximum and grants exactly 3 stacks")
	check(not game.supernatural.deal(1),"same devil cannot charge twice")
	for i in 4: game.supernatural.sacrifice_completed(1)
	check(game.nodes_in_group("campaign_threats").filter(func(a): return a.species=="angel").is_empty(),"no angels before fifth sacrifice")
	game.supernatural.sacrifice_completed(1)
	var angels: Array=game.nodes_in_group("campaign_threats").filter(func(a): return a.species=="angel")
	check(angels.size()==3,"fifth sacrifice summons three angels")
	var count: int=game.rituals.count("angel"); angels[0].damage(1000,true)
	check(game.rituals.count("angel")==count+1,"angel kill grants one permanent stack")
	angels[0].damage(1000,true); check(game.rituals.count("angel")==count+1,"dead angel cannot award twice")
	check(preload("res://scripts/vital_damage.gd").resolve(["heart"],5000)==900,"heart damage capped at 900")
	check(game.WeaponCatalog.weapon(0).spread>game.WeaponCatalog.weapon(29).spread*5,"smoothbore musket less precise than Mauser rifle")
	game.rituals._process(0)
	check("×2" in game.rituals.ui.text,"stack counts are visible")
	game.queue_free(); await process_frame
	print("SUPERNATURAL_UPDATE failures=",failures); quit(1 if failures else 0)
