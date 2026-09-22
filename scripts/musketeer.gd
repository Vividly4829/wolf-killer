extends "res://scripts/campaign_threat.gd"
var squad:=0
var rank_index:=0
var musket: Node3D
var muzzle:=Vector3.ZERO
func build_raider() -> void:
	var soldier=preload("res://scripts/musketeer_model.gd").new()
	soldier.coat_color=Color("263b61"); soldier.rotation.y=PI; model.add_child(soldier)
	raider_weapon=0
	var built=preload("res://scripts/weapon_model_builder.gd").new().build(0)
	musket=built.root; muzzle=built.muzzle
	musket.position=Vector3(.17,1.24,.25); musket.rotation.y=PI; model.add_child(musket)
	var bayonet:=MeshInstance3D.new(); var steel:=CylinderMesh.new()
	steel.top_radius=0; steel.bottom_radius=.018; steel.height=.30; steel.radial_segments=4
	bayonet.mesh=steel; bayonet.rotation.x=-PI/2; bayonet.position=muzzle+Vector3(.035,0,-.16)
	bayonet.material_override=preload("res://scripts/combat_fx.gd").material(Color("b1b7ba")); musket.add_child(bayonet)
func hear(origin: Vector3) -> void:
	var newly_alerted:=not alerted
	super(origin)
	if newly_alerted: warning=3.0+(rank_index%3)*.65
func formation_goal(destination: Vector3) -> Vector3:
	if not is_instance_valid(target): return destination
	var front: Vector3=(target.position-home); front.y=0; front=front.normalized()
	if front.length_squared()<.1: front=Vector3.FORWARD
	var side:=Vector3(front.z,0,-front.x)
	return target.position-front*(20+(rank_index/3)*2.5)+side*((rank_index%3)-1)*2.2
func _physics_process(delta: float) -> void:
	super(delta)
	if not dead: model.get_child(0).reloading=cooldown>1.0
func shoot() -> void:
	if not is_instance_valid(target): return
	if position.distance_to(target.position)<2.1: strike(target,20); cooldown=1.5; return
	var origin:=musket.to_global(muzzle)
	var aim: Vector3=target.position+Vector3.UP
	var spread:=maxf(.12,origin.distance_to(aim)*.017)
	var direction: Vector3=(aim-origin+Vector3(randf_range(-spread,spread),randf_range(-spread*.5,spread*.5),randf_range(-spread,spread))).normalized()
	cooldown=7.5+randf_range(0,1.5)
	var bolt=preload("res://scripts/raider_projectile.gd").new()
	bolt.attacker=self; bolt.game=game; bolt.power=32; bolt.spec={"id":"enemy_musket"}
	game.add_child(bolt); bolt.position=origin; bolt.velocity=direction*150
	game.coop.enemy_muzzle(origin,direction)
	if game.coop.active: game.coop.send_all("enemy_muzzle",[origin,direction])
	game.frighten_wildlife(origin,90)
