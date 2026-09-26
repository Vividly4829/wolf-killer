extends Node3D
## Host-owned cabin guardians; guests receive state and submit riding input only.
const CAT_NAMES := ["Tijgertje", "Sirius"]
const CAT_HEALTH := 150.0
const GUARD_RADIUS := 32.0
const LEASH_RADIUS := 42.0
const SWIPE_DAMAGE := 32.0
const RIDE_SPEED := 8.5
const Model = preload("res://scripts/guardian_cat_model.gd")
var game: Node3D
var cats: Array[Dictionary] = []
var elapsed := 0.0
var send_left := 0.0
func local_id() -> int: return game.coop.peer_id() if game.coop.active else 1
func hunter(peer: int) -> Node3D: return game.player if peer==1 else game.coop.avatars.get(peer)
func occupied(peer: int) -> int:
	for i in cats.size():
		if cats[i].rider==peer and cats[i].hp>0: return i
	return -1
func home_point(index: int) -> Vector3:
	var anchor: Vector3=game.world.exterior_rally_point
	for radius in [4.0,7.0,10.0,14.0]:
		for step in 16:
			var p: Vector3=anchor+Vector3(cos((step+index*8)*TAU/16),0,sin((step+index*8)*TAU/16))*radius
			var cell: int=game.world.wolf_nav.nearest(p.x,p.z,1.5)
			if cell<0 or game.world.wolf_nav.distances[cell]<0: continue
			p=game.world.wolf_nav.point(cell)
			if cats.any(func(cat): return cat.home.distance_to(p)<3.2): continue
			if outside_buildings(p) and p.y>.15 and body_clear(p): return p
	return anchor
func outside_buildings(point: Vector3) -> bool:
	var p:=Vector2(point.x,point.z)
	for cabin in game.world.services.cabins:
		if Geometry2D.is_point_in_polygon(p,cabin.outline): return false
		for i in cabin.outline.size():
			if Geometry2D.get_closest_point_to_segment(p,cabin.outline[i],cabin.outline[(i+1)%cabin.outline.size()]).distance_to(p)<1.5: return false
	return true
func body_clear(point: Vector3) -> bool:
	var shape:=CapsuleShape3D.new(); shape.radius=.42; shape.height=2.55
	var query:=PhysicsShapeQueryParameters3D.new(); query.shape=shape; query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*1.40)
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func clear() -> void:
	for cat in cats: cat.node.queue_free()
	cats.clear()
func reset_round() -> void:
	if game.coop.client(): return
	release_all()
	clear()
	if game.level<10:
		if game.coop.active: game.coop.send_all("cat_state",[[]])
		return
	for i in 2:
		var hp: float=CAT_HEALTH
		add_cat(i,home_point(i),hp)
	if game.coop.active: game.coop.send_all("cat_state",[snapshot()])
func add_cat(index: int,p: Vector3,hp: float) -> void:
	var model:=Model.new(); model.variant=index; add_child(model); model.position=p
	cats.append({"name":CAT_NAMES[index],"node":model,"p":p,"home":p,"yaw":0.0,"hp":hp,"max_hp":hp,"rider":0,"axis":Vector2.ZERO,"heading":0.0,"input_at":-1.0,"speed":0.0,"cooldown":0.0,"target":null,"think":0.0,"search":null,"route":PackedVector3Array(),"route_at":0.0,"swipe":0.0})
func hostile(enemy: Node3D) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("dead")==true or game.free_play: return false
	if enemy is IslandWolf: return true
	var species: String=str(enemy.get("species"))
	if species in ["deer","moose"]: return float(enemy.get("defensive_left"))>0
	if species in ["bear","devil"]: return enemy.get("alerted")==true
	return species in ["wererabbit","raider","legionary","musketeer","confederate","nazi","angel"]
func candidates() -> Array:
	return game.wolves+game.nodes_in_group("campaign_threats")+game.nodes_in_group("wildlife")
func clear_sight(a: Vector3,b: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a+Vector3.UP,b+Vector3.UP,1)).is_empty()
func nearby(p: Vector3) -> int:
	var found := -1; var distance := 3.4
	for i in cats.size():
		var cat:=cats[i]; var d: float=p.distance_to(cat.p)
		if cat.hp>0 and d<distance and clear_sight(p,cat.p): found=i; distance=d
	return found
func prompt() -> String:
	var i:=occupied(local_id())
	if i<0: i=nearby(game.player.position)
	if i<0: return ""
	var key: String="Y" if game.controller_device>=0 else "E"
	var cat:=cats[i]
	if cat.rider==local_id(): return "[ %s ] DISMOUNT / %s / %d HP / %s"%[key,cat.name,ceili(cat.hp),"Left stick to ride" if game.controller_device>=0 else "WASD to ride"]
	return "%s / ANOTHER PLAYER IS RIDING"%cat.name if cat.rider>0 else "[ %s ] RIDE %s / %d HP"%[key,cat.name,ceili(cat.hp)]
func interact() -> bool:
	if occupied(local_id())<0 and nearby(game.player.position)<0: return false
	if game.coop.client(): game.coop.send_to(1,"cat_interact",[])
	else: request(1)
	return true
func exit_point(cat: Dictionary) -> Vector3:
	for radius in [1.5,2.0,2.7]:
		for step in 12:
			var p: Vector3=cat.p+Vector3(cos(step*TAU/12),0,sin(step*TAU/12))*radius
			var cell: int=game.world.nav.nearest(p.x,p.z,.6)
			if cell>=0:
				p=game.world.nav.point(cell)
				if absf(p.y-cat.p.y)<1.2 and clear_sight(cat.p,p): return p
	return cat.p
func request(peer: int) -> bool:
	if game.coop.client() or not game.is_playing(): return false
	var actor:=hunter(peer)
	if not is_instance_valid(actor) or (game.health<=0 or game.is_struggling() if peer==1 else actor.health<=0 or actor.mauling!=0): return false
	if game.rituals.tasks.has(peer) or game.boats.occupied(peer)>=0: return false
	var i:=occupied(peer)
	if i>=0:
		dismount(cats[i]); return true
	i=nearby(actor.position)
	if i<0 or cats[i].rider>0: return false
	if peer==1:
		game.player.yaw=cats[i].yaw+PI; game.player._update_rotation()
	cats[i].rider=peer; cats[i].axis=Vector2.ZERO; cats[i].target=null; cats[i].route=PackedVector3Array(); cats[i].search=null
	place_riders()
	if game.coop.active: game.coop.send_all("cat_state",[snapshot()])
	return true
func dismount(cat: Dictionary) -> void:
	var peer: int=cat.rider
	cat.rider=0; cat.axis=Vector2.ZERO; cat.input_at=-1.0; cat.route_at=0.0
	var actor:=hunter(peer)
	if peer>0 and is_instance_valid(actor):
		var p:=exit_point(cat); actor.position=p
		if peer==1: settle_rider(p)
		else: game.coop.send_to(peer,"cat_exit",[p])
	if game.coop.active: game.coop.send_all("cat_state",[snapshot()])
func settle_rider(point: Vector3) -> void:
	game.player.position=point
	game.player._jump_height=0.0; game.player._jump_velocity=0.0
	game.player._velocity=Vector2.ZERO; game.player.ground_view_offset=0.0
func release_all() -> void:
	if game.coop.client(): return
	for cat in cats:
		if cat.rider>0: dismount(cat)
func control(peer: int,axis: Vector2,heading: float) -> void:
	if game.coop.client() or not axis.is_finite() or not is_finite(heading): return
	var i:=occupied(peer)
	if i<0: return
	cats[i].axis=axis.limit_length(1); cats[i].heading=heading; cats[i].input_at=elapsed
func local_control(axis: Vector2,heading: float,delta: float) -> void:
	if game.coop.client():
		send_left-=delta
		if send_left<=0: send_left=.05; game.coop.send_to(1,"cat_control",[axis,heading])
	else: control(1,axis,heading)
func place_riders() -> void:
	for avatar in game.coop.avatars.values(): avatar.set_meta("cat_riding",false)
	for cat in cats:
		if cat.rider<=0: continue
		var actor: Node3D=game.player if cat.rider==local_id() else game.coop.avatars.get(cat.rider)
		if is_instance_valid(actor):
			actor.position=cat.node.position+(Vector3(0,1.25,-.28)*Model.MODEL_SCALE).rotated(Vector3.UP,cat.yaw)
			if actor!=game.player: actor.set_meta("cat_riding",true)
func move_cat(cat: Dictionary,direction: Vector3,speed: float,delta: float) -> void:
	var before: Vector3=cat.p
	var movement:=direction*minf(speed*delta,.35)
	var next: Vector3=game.world.wolf_nav.move_position(cat.p,movement.x,movement.z)
	if not game.world.is_safe_position(next) and body_clear(next): cat.p=next
	elif cat.rider==0:
		# Slide around trunks/rocks that are narrower in the sampled wolf grid.
		for angle in [.55,-.55,1.0,-1.0,1.5,-1.5]:
			var slide:=movement.rotated(Vector3.UP,angle)
			var alternate: Vector3=game.world.wolf_nav.move_position(cat.p,slide.x,slide.z)
			if alternate.distance_to(cat.p)>.001 and not game.world.is_safe_position(alternate) and body_clear(alternate): cat.p=alternate; break
	cat.speed=Vector2(cat.p.x-before.x,cat.p.z-before.z).length()/maxf(.001,delta)
	if direction.length_squared()>.01: cat.yaw=lerp_angle(cat.yaw,atan2(direction.x,direction.z),minf(1,delta*7))
func route_direction(cat: Dictionary,goal: Vector3) -> Vector3:
	var nav=game.world.wolf_nav
	if preload("res://scripts/animal_route.gd").corridor_clear(nav,cat.p,goal): return (goal-cat.p).normalized()
	if cat.search:
		cat.search.advance()
		if cat.search.finished: cat.route=cat.search.result; cat.search=null
	if elapsed>=cat.route_at and not cat.search:
		cat.route_at=elapsed+1.0
		cat.search=preload("res://scripts/route_search.gd").new(); cat.search.start(nav,cat.p,goal)
	while not cat.route.is_empty() and Vector2(cat.p.x-cat.route[0].x,cat.p.z-cat.route[0].z).length()<.35: cat.route.remove_at(0)
	if cat.route.is_empty(): return Vector3.ZERO
	var direction: Vector3=cat.route[0]-cat.p; direction.y=0; return direction.normalized()
func hurt(cat: Dictionary,amount: float) -> void:
	if game.coop.client() or cat.hp<=0: return
	cat.hp=maxf(0,cat.hp-amount)
	game.gore.blood_burst(cat.p+Vector3.UP,Vector3.UP,.4)
	if cat.hp<=0:
		dismount(cat); cat.node.fallen=true; cat.target=null
		game.show_notice("%s has fallen. They return next round."%cat.name,5)
func defend_against(enemy: Node3D,delta: float) -> bool:
	# Called by enemy AI after death/incapacitation checks; replaces its attack,
	# rather than dealing a second invisible attack on top of the normal one.
	if game.coop.client() or not hostile(enemy): return false
	var nearest := -1; var distance := 5.0
	for i in cats.size():
		var cat:=cats[i]
		if cat.hp<=0 or cat.p.distance_to(cat.home)>LEASH_RADIUS: continue
		var d: float=enemy.position.distance_to(cat.p)
		if d<distance and clear_sight(enemy.position,cat.p): distance=d; nearest=i
	if nearest<0: return false
	var cat:=cats[nearest]
	if enemy is IslandWolf and enemy.behavior=="maul": return false
	var offset: Vector3=cat.p-enemy.position; offset.y=0
	if distance>2.3:
		var step:=offset.normalized()*delta*3.8
		enemy.position=game.world.wolf_nav.move_position(enemy.position,step.x,step.z)
	else:
		var cooldown: float=float(enemy.get_meta("cat_attack_left",0))-delta
		if cooldown<=0:
			var damage: float=enemy.bite_damage if enemy is IslandWolf else (36.0 if str(enemy.get("species")) in ["bear","moose"] else 24.0)
			hurt(cat,damage); cooldown=1.5
		enemy.set_meta("cat_attack_left",cooldown)
	enemy.rotation.y=lerp_angle(enemy.rotation.y,atan2(offset.x,offset.z),delta*6)
	if enemy is IslandWolf:
		enemy.alerted=true; enemy._animate(3.8 if distance>2.3 else 0.0,distance<=2.3); enemy._growl()
	elif str(enemy.get("species"))=="bear" and float(enemy.get("voice_left"))<=0: enemy.bear_voice()
	return true
func _physics_process(delta: float) -> void:
	elapsed+=delta
	if game.coop.client():
		for cat in cats:
			cat.node.position=cat.node.position.lerp(cat.p,minf(1,delta*18)); cat.node.rotation.y=lerp_angle(cat.node.rotation.y,cat.yaw,minf(1,delta*18))
		place_riders(); return
	if not game.is_playing(): return
	for cat in cats:
		cat.cooldown=maxf(0,cat.cooldown-delta); cat.swipe=maxf(0,cat.swipe-delta); cat.speed=0.0
		if cat.hp<=0: cat.node.fallen=true; continue
		if cat.rider>0:
			var actor:=hunter(cat.rider)
			if not is_instance_valid(actor) or (game.health<=0 if cat.rider==1 else actor.health<=0): dismount(cat)
		if cat.rider>0:
			var axis: Vector2=cat.axis if elapsed-cat.input_at<.25 else Vector2.ZERO
			var forward:=Vector3(-sin(cat.heading),0,-cos(cat.heading)); var right:=Vector3(cos(cat.heading),0,-sin(cat.heading))
			move_cat(cat,(right*axis.x-forward*axis.y),RIDE_SPEED,delta)
			if cat.p.distance_to(cat.home)<GUARD_RADIUS:
				for enemy in candidates():
					if hostile(enemy) and cat.p.distance_to(enemy.position)<2.8 and clear_sight(cat.p,enemy.position):
						swipe(cat,enemy); break
		else:
			cat.think-=delta
			if cat.think<=0:
				cat.think=.35; cat.target=null; var best:=GUARD_RADIUS
				if cat.p.distance_to(cat.home)<LEASH_RADIUS:
					for enemy in candidates():
						if not hostile(enemy) or enemy.position.distance_to(cat.home)>GUARD_RADIUS: continue
						var d: float=cat.p.distance_to(enemy.position)
						if d<best and clear_sight(cat.p,enemy.position): best=d; cat.target=enemy
			var target: Node3D=cat.target
			if not is_instance_valid(target) or not hostile(target): cat.target=null; target=null
			var goal: Vector3=target.position if target else cat.home
			var distance: float=cat.p.distance_to(goal)
			if distance>(2.5 if target else 1.1): move_cat(cat,route_direction(cat,goal),6.8 if target else 4.2,delta)
			if target and distance<=2.8 and absf(goal.y-cat.p.y)<2.8 and cat.cooldown<=0 and clear_sight(cat.p,goal):
				cat.yaw=lerp_angle(cat.yaw,atan2(goal.x-cat.p.x,goal.z-cat.p.z),minf(1,delta*8))
				swipe(cat,target)
		cat.node.position=cat.p; cat.node.rotation.y=cat.yaw; cat.node.moving=cat.speed
	place_riders()
func swipe(cat: Dictionary,target: Node3D) -> void:
	if cat.cooldown>0: return
	cat.cooldown=1.1; cat.swipe=.38; cat.node.attacking=.38
	if target is IslandWolf: target.damage(SWIPE_DAMAGE)
	else: target.damage(SWIPE_DAMAGE,true)
	game.gore.blood_burst(target.position+Vector3.UP,(target.position-cat.p).normalized(),.6)
func snapshot() -> Array:
	var result: Array=[]
	for cat in cats: result.append({"p":cat.p,"home":cat.home,"yaw":cat.yaw,"hp":cat.hp,"max_hp":cat.max_hp,"rider":cat.rider,"speed":cat.speed,"swipe":cat.swipe})
	return result
func apply_snapshot(data: Array) -> void:
	if not game.coop.client(): return
	var was_riding := occupied(local_id())
	if cats.size()!=data.size():
		clear()
		for i in mini(2,data.size()): add_cat(i,data[i].p,data[i].max_hp)
	for i in cats.size():
		for key in ["p","home","yaw","hp","max_hp","rider","speed","swipe"]: cats[i][key]=data[i][key]
		cats[i].node.fallen=cats[i].hp<=0; cats[i].node.moving=cats[i].speed; cats[i].node.attacking=cats[i].swipe
	var now_riding := occupied(local_id())
	if was_riding<0 and now_riding>=0:
		game.player.yaw=cats[now_riding].yaw+PI; game.player._update_rotation()
	place_riders()
