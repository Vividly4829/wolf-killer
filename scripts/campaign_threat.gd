extends Node3D
## Host-authoritative bear / human opponent. Cover and LOS are world collisions.
const Route = preload("res://scripts/animal_route.gd")
var game: Node
var species := "bear"
var health := 260.0
var max_health := 260.0
var dead := false
var model: Node3D
var animation: AnimationPlayer
var reaction: Node
var home := Vector3.ZERO
var goal := Vector3.ZERO
var memory := Vector3.INF
var alerted := false
var wounded := false
var bleeding_rate := 0.0
var paid := false
var route := PackedVector3Array()
var search: RefCounted
var think := 0.0
var cooldown := 0.0
var warning := 0.0
var memory_left := 0.0
var phase := 0.0
var legs: Array[Node3D]=[]
var limbs: Node
var target: Node3D
var cover_side := 1.0
var trail := 0.0
var voice_left:=0.0
var raider_weapon:=-1
func _ready() -> void:
	add_to_group("campaign_threats")
	max_health=110 if species in ["raider","legionary","musketeer"] else 260
	health=max_health; cover_side=-1 if randf()<.5 else 1
	model=Node3D.new(); add_child(model)
	if species=="bear": build_bear()
	else: build_raider()
	reaction=preload("res://scripts/animal_reaction.gd").new(); reaction.animal=self; add_child(reaction)
	var hit:=Area3D.new(); hit.collision_layer=2; hit.collision_mask=0
	hit.set_meta("wolf",self); hit.set_meta("hit_zone","body"); add_child(hit)
	var shape:=CollisionShape3D.new(); var body:=CapsuleShape3D.new()
	body.radius=.30 if species in ["raider","legionary","musketeer"] else .52; body.height=1.8 if species in ["raider","legionary","musketeer"] else 2.0
	shape.shape=body; shape.position.y=.90
	if species=="bear": shape.rotation.x=PI/2
	hit.add_child(shape)
	var organs: Array=preload("res://scripts/human_xray.gd").ORGANS if species in ["raider","legionary","musketeer"] else preload("res://scripts/wildlife_anatomy.gd").organs("bear")
	for organ in organs:
		var extra:=CollisionShape3D.new(); var volume:=SphereShape3D.new(); volume.radius=1
		extra.shape=volume; extra.position=organ.center; extra.scale=organ.radii*1.1; hit.add_child(extra)
	if species=="bear":
		limbs=preload("res://scripts/animal_limbs.gd").new(); limbs.animal=self; add_child(limbs)
func ellipsoid(p: Vector3,r: Vector3,color: Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=1; sphere.height=2
	sphere.radial_segments=18; sphere.rings=10; node.mesh=sphere; node.position=p; node.scale=r
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=.95
	node.material_override=mat; model.add_child(node); return node
func build_bear() -> void:
	var fur:=Color("4b382c").lightened(randf_range(0,.15))
	ellipsoid(Vector3(0,.88,0),Vector3(.50,.58,.95),fur)
	ellipsoid(Vector3(0,1.13,.43),Vector3(.47,.52,.53),fur.darkened(.1))
	ellipsoid(Vector3(0,1.02,.98),Vector3(.32,.34,.34),fur)
	ellipsoid(Vector3(0,.91,1.25),Vector3(.22,.17,.25),Color("876e52"))
	ellipsoid(Vector3(0,.94,1.44),Vector3(.13,.085,.06),Color("171817"))
	for side in [-1,1]:
		ellipsoid(Vector3(side*.24,1.30,.87),Vector3(.12,.13,.08),fur)
		ellipsoid(Vector3(side*.20,1.10,1.22),Vector3(.035,.026,.025),Color("15110c"))
		for z in [-.56,.60]:
			var zone: String=("front" if z>0 else "rear")+("_left_leg" if side<0 else "_right_leg")
			var leg:=ellipsoid(Vector3(side*.32,.40,z),Vector3(.18,.43,.21),fur.darkened(.1)); leg.set_meta("limb",zone); legs.append(leg)
			ellipsoid(Vector3(side*.32,.12,z+.12),Vector3(.19,.12,.28),fur).set_meta("limb",zone)
			for claw in 3: ellipsoid(Vector3(side*.32+(claw-1)*.08,.10,z+.35),Vector3(.023,.025,.09),Color("a89d83")).set_meta("limb",zone)
func build_raider() -> void:
	var hunter=preload("res://scripts/field_character.gd").new()
	hunter.coat_color=Color("665043"); hunter.rotation.y=PI
	model.add_child(hunter)
	if raider_weapon<0: raider_weapon=[18,19,20,21,22,23][randi()%6]
	var gun=preload("res://scripts/weapon_model_builder.gd").new().build(raider_weapon).root
	gun.position=Vector3(.17,1.22,.30); gun.rotation.y=PI; model.add_child(gun)

func visible_to(p: Vector3) -> bool:
	var ray=PhysicsRayQueryParameters3D.create(position+Vector3.UP*(1.5 if species in ["raider","legionary","musketeer"] else .9),p+Vector3.UP,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func hear(origin: Vector3) -> void:
	if dead: return
	memory=origin; memory_left=24
	if not alerted:
		alerted=true; warning=2.5 if species=="bear" else 1.7
		if species=="bear": bear_voice()
		if position.distance_to(game.player.position)<45: game.show_notice("A bear huffs and stamps." if species=="bear" else "Shields raised! Legionaries advance." if species=="legionary" else "Muskets raised! Take cover." if species=="musketeer" else "A raider shouts: Who's there?",3)
func bear_voice() -> void:
	voice_left=randf_range(2.5,4.5)
	game.sounds.play_at("bear_growl",position,-3,.98)
	if game.coop.active: game.coop.broadcast_voice("bear_growl",position,-3,.98)

func choose_target() -> Node3D:
	var result: Node3D
	var best:=INF
	for candidate in [game.player]+game.coop.avatars.values():
		var hp: float=game.health if candidate==game.player else candidate.health
		if hp<=0 or game.world.is_safe_position(candidate.position): continue
		var d:=position.distance_to(candidate.position)
		var noise: float=candidate.get_noise_level()
		var sight:=23.0 if candidate.is_crouching else 40.0
		if d<5 or d<noise*42 or (d<sight and visible_to(candidate.position)):
			if d<best: result=candidate; best=d
	# Predators and raiders can fight; loud combat creates real opportunities.
	if species in ["raider","legionary","musketeer"]:
		for enemy in game.wolves+game.nodes_in_group("campaign_threats"):
			if enemy==self or enemy.dead or enemy.get("species") in ["raider","legionary","musketeer"]: continue
			var d:=position.distance_to(enemy.position)
			if d<minf(best,25) and visible_to(enemy.position): result=enemy; best=d
	else:
		for enemy in game.nodes_in_group("campaign_threats"):
			if enemy.species in ["raider","legionary","musketeer"] and not enemy.dead and position.distance_to(enemy.position)<minf(best,18): result=enemy; best=position.distance_to(enemy.position)
	return result
func _physics_process(delta: float) -> void:
	if reaction and reaction.hold_incapacitated(): return
	if dead or is_queued_for_deletion() or game.coop.client() or not game.is_playing(): return
	if species in ["raider","legionary","musketeer"]: model.get_child(0).set_motion(2.8 if not route.is_empty() else 0,false,alerted,species=="legionary" and cooldown>.85)
	voice_left=maxf(0,voice_left-delta)
	if species=="bear" and alerted and voice_left<=0: bear_voice()
	phase+=delta; cooldown=maxf(0,cooldown-delta); warning=maxf(0,warning-delta); memory_left-=delta
	if wounded or bleeding_rate>0:
		trail-=delta
		if trail<=0: game.gore.blood_pool(position,.15); trail=.65
		if bleeding_rate>0: damage(bleeding_rate*delta,paid)
	if dead or reaction.down>0: return
	if search:
		search.advance()
		if search.finished: route=search.result; search=null
	think-=delta
	if think<=0:
		think=.65
		target=choose_target()
		if is_instance_valid(target): hear(target.position)
		elif memory_left<=0: alerted=false
		goal=memory if alerted and memory.is_finite() else home+Vector3(sin(phase*.08)*8,0,cos(phase*.08)*8)
		if species=="raider" and is_instance_valid(target):
			var away: Vector3=(position-target.position).normalized()
			if raider_weapon in [18,19,20]: goal=target.position
			elif position.distance_to(target.position)<6: goal=position+away*3
			elif position.distance_to(target.position)<28 and cooldown>1.0:
				goal=position+Vector3(-away.z,0,away.x)*cover_side*5
				# Prefer a reachable point hidden behind geometry while reloading.
				for i in 8:
					var p:=position+away.rotated(Vector3.UP,i*TAU/8)*5
					var ray=PhysicsRayQueryParameters3D.create(target.position+Vector3.UP,p+Vector3.UP,1)
					if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): goal=p; break
		if species in ["legionary","musketeer"]: goal=formation_goal(goal)
		if not search:
			var cell: int=game.world.wolf_nav.nearest(goal.x,goal.z,5)
			if cell>=0:
				search=preload("res://scripts/route_search.gd").new()
				search.start(game.world.wolf_nav,position,game.world.wolf_nav.point(cell))
	if is_instance_valid(target) and warning<=0 and cooldown<=0 and visible_to(target.position):
		var range_to:=position.distance_to(target.position)
		if species in ["raider","musketeer"] and range_to<(65 if species=="musketeer" else 42): shoot()
		elif species=="legionary" and range_to<1.9: strike(target,24.0); cooldown=1.25
		elif species=="bear" and range_to<2.25: strike(target,36.0); cooldown=1.55
	while not route.is_empty() and Vector2(position.x-route[0].x,position.z-route[0].z).length()<.05: route.remove_at(0)
	for shortcut in 2:
		if route.size()>1 and Route.corridor_clear(game.world.wolf_nav,position,route[1]): route.remove_at(0)
		else: break
	var moving:=false
	if not route.is_empty() and warning<=0:
		var direction:=route[0]-position; direction.y=0
		var speed: float=(6.1 if species=="bear" else 2.6) if alerted else .85
		if limbs: speed*=limbs.speed_factor()
		speed*=game.world.wolf_nav.vegetation_factor(position)
		var step:=direction.normalized()*minf(direction.length(),delta*speed)
		var prior:=position
		position=game.world.wolf_nav.move_position(position,step.x,step.z)
		moving=position.distance_to(prior)>.002
		if moving: rotation.y=lerp_angle(rotation.y,atan2(direction.x,direction.z),delta*6)
	if is_instance_valid(target) and species in ["raider","legionary","musketeer"]:
		var direction:=target.position-position; rotation.y=lerp_angle(rotation.y,atan2(direction.x,direction.z),delta*8)
	for i in legs.size(): legs[i].rotation.x=sin(phase*(10 if alerted else 4)+i*PI)*(.24 if moving else 0)
func shoot() -> void:
	var distance: float=position.distance_to(target.position)
	if distance<1.9:
		strike(target,18); cooldown=1.1; return
	var throwing: bool=raider_weapon in [18,19,20]
	if distance>(18 if throwing else 35): return
	cooldown=3.0 if throwing else 3.8
	var origin:=position+Vector3.UP*1.4
	var aim: Vector3=target.position+Vector3.UP
	var speed:=18.0 if throwing else 32.0
	var direction: Vector3=(aim-origin).normalized()
	var flight_time:=origin.distance_to(aim)/speed
	direction=(aim+Vector3.UP*4.9*flight_time*flight_time-origin+Vector3(randf_range(-.15,.15),randf_range(-.12,.12),0)).normalized()
	var bolt=preload("res://scripts/raider_projectile.gd").new()
	bolt.attacker=self; bolt.game=game; bolt.power=22 if throwing else 25
	bolt.spec=preload("res://scripts/weapon_catalog.gd").weapon(raider_weapon)
	game.add_child(bolt); bolt.position=origin; bolt.velocity=direction*speed
	game.sounds.play_at("crossbow",origin,-10)
	if game.coop.active: game.coop.broadcast_voice("crossbow",origin,-10,1)
func strike(victim: Node3D,amount: float) -> void:
	if victim==game.player:
		if species=="bear": game.receive_wolf_bite(amount,position)
		else: game.receive_gunshot(amount)
	elif victim.get("peer_id")!=null:
		var shooter: int=game.coop.shooter; game.coop.shooter=0; game.coop.friendly_hit(victim.peer_id,amount); game.coop.shooter=shooter
	else: victim.damage(amount)
func receive_ballistic_hit(amount: float,point: Vector3,direction: Vector3,_zone: String,_force: float,vital_bonus: float=1,penetration: float=.65) -> Dictionary:
	if limbs and limbs.parts.has(_zone):
		paid=true; hear(point-direction*4)
		return limbs.hit(_zone,amount,_force,point,direction)
	var entry:=to_local(point); var ray: Vector3=(global_basis.inverse()*direction).normalized()
	var report: Dictionary=preload("res://scripts/human_xray.gd").trace(entry,ray,amount,penetration) if species in ["raider","legionary","musketeer"] else preload("res://scripts/wildlife_anatomy.gd").trace("bear",entry,ray,penetration*.75)
	report.species="raider" if species in ["raider","legionary","musketeer"] else "bear"; report.zone="BODY"
	report.instant_fatal=report.organs.has("brain") or report.organs.has("heart")
	var before:=health; var mult: float=report.multiplier*vital_bonus
	paid=true; bleeding_rate=maxf(bleeding_rate,.8 if report.organs.is_empty() else 2.2)
	damage(health if report.instant_fatal else amount*mult,true)
	hear(point-direction*4); game.gore.blood_burst(point,direction,1.0)
	report.merge({"damage":before-health,"calculated_damage":amount*mult,"multiplier":mult,"fatal":dead,"bleed":bleeding_rate},true)
	return report
func damage(amount: float,reward_hunter: bool=false) -> void:
	if dead: return
	if amount>2: reaction.hit(amount/max_health)
	health=maxf(0,health-amount)
	if reaction: reaction.hold_incapacitated()
	paid=paid or reward_hunter
	if health<=0:
		dead=true; reaction.die()
		if species in ["raider","legionary","musketeer"]: model.get_child(0).set_process(false)
		for area in find_children("*","Area3D",true,false): area.set_deferred("collision_layer",0)
		# Required threats count even when the player engineers an animal fight.
		game.campaign.animal_killed(self,true)
		if paid: game.progress.earn(60 if species=="bear" else 35); game.coop.award(60 if species=="bear" else 35)
		game.gore.blood_pool(position,.4)
func get_identification() -> String: return species.to_upper()+" / "+("ALERTED" if alerted else "UNAWARE")

func formation_goal(destination: Vector3) -> Vector3: return destination
