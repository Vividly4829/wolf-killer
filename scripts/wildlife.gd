extends Node3D
var game: Node
var species := "deer"
var health := 70.0
var dead := false
var size_scale := 1.0
var bleeding_rate := 0.0
var water_polygons: Array[PackedVector2Array] = []
var aquatic := false
var water_home := Vector3.ZERO
var fear_left := 0.0
var threat_memory := Vector3.ZERO
var trail_left := 0.0
var wounded_by_hunter := false
var route := PackedVector3Array()
var search: RefCounted
var velocity := Vector3.ZERO
var blocked_time := 0.0
var escape_angle := 0.0
var rejected_goals := PackedVector3Array()
var progress_anchor := Vector3.INF
var progress_clock := 0.0
var reaction: Node
var goal := Vector3.ZERO
var timer := 0.0
var phase := 0.0
var model: Node3D
var animation: AnimationPlayer
var idle_clip := ""
var movement_heading := Vector3.ZERO
var network_replica := false
var network_position := Vector3.ZERO
var network_yaw := 0.0
var reward := 10
var alerted:=false
var defensive_left:=0.0
var defensive_cooldown:=0.0
var defensive_hit:=0.0
var defensive_target: Node3D
func _ready() -> void:
	add_to_group("wildlife")
	escape_angle=randf_range(-PI,PI)
	health = 70 if species=="deer" else 18
	reward = 15 if species=="deer" else (7 if species=="goose" else 5)
	if species in ["deer","mink"]:
		model = load("res://assets/wildlife/"+species+".glb").instantiate()
		add_child(model)
		var box := AABB()
		var first := true
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB = model.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
			box = bounds if first else box.merge(bounds)
			first = false
		var factor := (1.6 if species=="deer" else .25)/maxf(.1,box.size.y)
		model.scale = Vector3.ONE*factor
		model.position.y = -box.position.y*factor
		var animations := model.find_children("*","AnimationPlayer",true,false)
		if not animations.is_empty(): animation = animations[0]
		if animation:
			idle_clip = "Idle_001" if animation.has_animation("Idle_001") else "Idle.001"
			if animation.has_animation(idle_clip):
				animation.play(idle_clip); animation.seek(0,true)
			for clip in [idle_clip,"Run"]:
				if animation.has_animation(clip): animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		if species=="deer":
			# Imported mesh AABBs include the armature offset twice. Ground the
			# posed ankle joints, rather than sinking the skin by that offset.
			var skeletons:=model.find_children("*","Skeleton3D",true,false)
			if not skeletons.is_empty():
				var skeleton: Skeleton3D=skeletons[0]
				skeleton.force_update_all_bone_transforms()
				var lowest:=INF
				for bone in skeleton.get_bone_count():
					if "leg" in skeleton.get_bone_name(bone) and ".002" in skeleton.get_bone_name(bone):
						lowest=minf(lowest,to_local(skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin).y)
				if is_finite(lowest): model.position.y+=.085-lowest
	else:
		model = Node3D.new()
		add_child(model)
		var goose := species=="goose"
		var coat := Color("b4b2a2") if goose else Color("695646")
		ellipsoid(Vector3(0,.25,0),Vector3(.19,.18,.32),coat)
		ellipsoid(Vector3(0,.47 if goose else .39,.20),Vector3(.075,.25 if goose else .10,.075),coat)
		ellipsoid(Vector3(0,.72 if goose else .46,.24),Vector3(.095,.095,.12),Color("d6d2be") if goose else Color("284e3a"))
		ellipsoid(Vector3(0,.69 if goose else .435,.36),Vector3(.065,.026,.09),Color("d2963e"))
		for side in [-1,1]:
			ellipsoid(Vector3(side*.07,.055,.02),Vector3(.045,.027,.09),Color("bc7d3e"))
			ellipsoid(Vector3(side*.17,.29,-.04),Vector3(.045,.10,.25),Color("62655f"))
	reaction = preload("res://scripts/animal_reaction.gd").new()
	reaction.animal = self
	add_child(reaction)
	var hit := Area3D.new()
	hit.collision_layer = 2
	hit.collision_mask = 0
	hit.set_meta("wolf",self)
	hit.set_meta("hit_zone","body")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .30 if species=="deer" else .17
	capsule.height = 1.4 if species=="deer" else .65
	shape.shape = capsule
	shape.rotation.x = PI/2
	shape.position.y = .82 if species=="deer" else .24
	hit.add_child(shape)
	add_child(hit)
	for organ in preload("res://scripts/wildlife_anatomy.gd").organs(species):
		var extra := CollisionShape3D.new()
		var volume := SphereShape3D.new(); volume.radius=1
		extra.shape=volume; extra.position=organ.center; extra.scale=organ.radii*1.1
		hit.add_child(extra)
func ellipsoid(p: Vector3,r: Vector3,color: Color) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 20
	sphere.rings = 12
	node.mesh = sphere
	node.position = p
	node.scale = r
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .95
	node.material_override = material
	model.add_child(node)
func damage(amount: float,paid: bool = true) -> void:
	if dead: return
	if amount>2: reaction.hit(amount/(70.0 if species=="deer" else 18.0))
	health = maxf(0,health-amount)
	if health<=0:
		dead = true
		for node in get_children():
			if node is Area3D: node.set_deferred("collision_layer",0)
		reaction.die()
		if paid:
			game.progress.money += reward
			game.coop.award(reward)
			game.progress.save_progress()
			game.show_notice("+%d CR / %s" % [reward,species.to_upper()],2)
			game.wildlife_defeated(self)
		get_tree().create_timer(35).timeout.connect(queue_free)
func receive_ballistic_hit(amount: float,point: Vector3,direction: Vector3,zone: String,_force: float,vital_bonus: float = 1.0, penetration: float = .65) -> Dictionary:
	var local := to_local(point)
	var ray := (global_basis.inverse()*direction).normalized()
	var report: Dictionary = preload("res://scripts/wildlife_anatomy.gd").trace(species,local,ray,penetration)
	var vital: bool = not report.organs.is_empty()
	var multiplier: float = report.multiplier*vital_bonus if vital else 1.0
	var before := health
	wounded_by_hunter = true
	bleeding_rate = maxf(bleeding_rate,2.5 if vital else .65)
	frighten(point-direction*3,20.0)
	for animal in game.nodes_in_group("wildlife"):
		if animal!=self and animal.position.distance_to(position)<24: animal.frighten(point-direction*3,10)
	damage(health if report.instant_fatal else amount*multiplier)
	game.gore.blood_burst(point,direction,1.0)
	report.merge({"multiplier":multiplier,"bleed":bleeding_rate,"calculated_damage":amount*multiplier,"damage":before-health,"fatal":dead},true)
	return report

func frighten(origin: Vector3,duration: float = 10.0) -> void:
	if dead: return
	if fear_left<=0:
		route.clear(); search=null; velocity=Vector3.ZERO
	threat_memory = origin
	fear_left = maxf(fear_left,duration)
	timer = 0
func notices(hunter: Node3D) -> bool:
	var distance := position.distance_to(hunter.position)
	var noise: float = hunter.get_noise_level()
	if distance<4 or distance<5+noise*38: return true
	var sight := (14.0 if hunter.is_crouching else 30.0) if get_meta("skittish",false) else (9.0 if hunter.is_crouching else 19.0)
	if distance>sight: return false
	var query := PhysicsRayQueryParameters3D.create(position+Vector3.UP*.8,hunter.position+Vector3.UP,1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func water_clear(p: Vector3) -> bool:
	if Vector2(p.x-water_home.x,p.z-water_home.z).length()>12: return false
	if water_polygons.is_empty():
		for outline: Array in game.world.exploration_data.outlines:
			var polygon := PackedVector2Array()
			for vertex: Array in outline: polygon.append(Vector2(vertex[0],vertex[1]))
			water_polygons.append(polygon)
	for polygon in water_polygons:
		if Geometry2D.is_point_in_polygon(Vector2(p.x,-p.z),polygon): return false
	return true
func land_room(p: Vector3) -> float:
	# Prefer open ground over the last walkable sample on a beach or cliff.
	var nav=game.world.wolf_nav
	var room:=0.0
	for i in 8:
		var d:=Vector3.RIGHT.rotated(Vector3.UP,i*TAU/8)*2.5
		var cell: int=nav.at(p.x+d.x,p.z+d.z)
		if nav.valid(cell) and nav.point(cell).y>.1 and absf(nav.point(cell).y-p.y)<1.8: room+=.125
	return room

func crowd_cost(p: Vector3) -> float:
	var cost:=0.0
	for other in game.nodes_in_group("wildlife"):
		if other==self or other.dead or other.aquatic or other.is_queued_for_deletion(): continue
		cost+=maxf(0,3.5-p.distance_to(other.position))*1.6
		if other.goal!=Vector3.ZERO: cost+=maxf(0,2.5-p.distance_to(other.goal))
	return cost

func choose_land_goal(fleeing: bool) -> void:
	var nav=game.world.wolf_nav
	var away:=position-threat_memory; away.y=0
	if away.length()<.1: away=Vector3.RIGHT.rotated(Vector3.UP,escape_angle)
	away=away.normalized()
	var best:=-INF
	var direct_best:=-INF
	var direct_goal:=position
	goal=position
	# Different headings and distances let deer turn along a shore or back out of
	# a dead end, instead of repeatedly snapping a water-bound goal to the beach.
	for i in 32:
		var direction:=away.rotated(Vector3.UP,i*TAU/8+escape_angle*.2)
		var distance:= [2.5,6.0,12.0,18.0][i/8] as float
		var candidate:=position+direction*distance
		var cell: int=nav.at(candidate.x,candidate.z)
		if not nav.valid(cell): cell=nav.nearest(candidate.x,candidate.z,.8)
		if cell<0: continue
		candidate=nav.point(cell)
		var displacement:=candidate-position; displacement.y=0
		if displacement.length()<.7 or candidate.y<.1: continue
		var room:=land_room(candidate)
		var value:=room*14+displacement.length()*.3-crowd_cost(candidate)
		if movement_heading.length_squared()>.1: value+=displacement.normalized().dot(movement_heading)*3
		if fleeing: value+=displacement.dot(away)*.48
		else: value+=randf_range(0,5)
		for rejected in rejected_goals: value-=maxf(0,5-candidate.distance_to(rejected))*3
		# Direct local exits are reliable; longer detours still use bounded A*.
		if value>best: best=value; goal=candidate
		if value>direct_best and preload("res://scripts/animal_route.gd").corridor_clear(nav,position,candidate):
			direct_best=value; direct_goal=candidate
	# Take an available connected escape first. A* is for enclosed obstacles,
	# never a reason to stand still while a nearby open exit is available.
	if direct_best>-INF: goal=direct_goal
	else:
		# Narrow shore exits may not fit a full-width corridor. Take a short
		# connected step out before asking A* for a distant detour.
		for distance in [.8,1.4,2.5]:
			for i in 16:
				var candidate: Vector3=position+away.rotated(Vector3.UP,i*TAU/16)*distance
				var cell: int=nav.at(candidate.x,candidate.z)
				if not nav.valid(cell): continue
				candidate=nav.point(cell)
				if not nav.line_clear(position.x,position.z,candidate.x,candidate.z): continue
				var displacement: Vector3=candidate-position; displacement.y=0
				if displacement.length()<.5: continue
				var value:=land_room(candidate)*14+displacement.length()+displacement.dot(away)*.3
				if value>direct_best: direct_best=value; goal=candidate

func choose_escape() -> void:
	if not aquatic:
		choose_land_goal(true); return
	var away:=position-threat_memory; away.y=0
	if away.length()<.1: away=Vector3.RIGHT
	away=away.normalized()
	var score:=-INF
	goal=position
	for i in 16:
		var candidate:=position+away.rotated(Vector3.UP,float(i)*TAU/16)*6
		if not water_clear(candidate): continue
		var value:=(candidate-position).dot(away)
		if value>score: score=value; goal=candidate

func abandon_route() -> void:
	rejected_goals.append(goal)
	if rejected_goals.size()>5: rejected_goals.remove_at(0)
	route.clear(); search=null; velocity=Vector3.ZERO; timer=0
	blocked_time=0; progress_clock=0; progress_anchor=position
	escape_angle=wrapf(escape_angle+1.1,-PI,PI)

func separation() -> Vector3:
	var push:=Vector3.ZERO
	for other in game.nodes_in_group("wildlife"):
		if other==self or other.dead or other.aquatic or other.is_queued_for_deletion(): continue
		var offset: Vector3=position-other.position; offset.y=0
		var distance:=offset.length()
		if distance>=2: continue
		if distance<.05: offset=Vector3.RIGHT.rotated(Vector3.UP,escape_angle); distance=.05
		push+=offset.normalized()*(2-distance)/2
	return push.limit_length(1.2)

func _physics_process(delta: float) -> void:
	if dead or is_queued_for_deletion() or not game.is_playing(): return
	var was_fleeing:=fear_left>0
	timer -= delta
	phase += delta
	fear_left = maxf(0,fear_left-delta)
	if bleeding_rate>0:
		trail_left -= delta
		if trail_left<=0:
			trail_left = .55
			if not aquatic: game.gore.blood_pool(position,.13)
		damage(bleeding_rate*delta,wounded_by_hunter)
		if dead: return
	if defensive_deer(delta): return
	var hunters: Array = [game.player]
	if game.coop.active: hunters.append_array(game.coop.avatars.values())
	for hunter in hunters:
		if notices(hunter):
			threat_memory = hunter.position
			fear_left = maxf(fear_left,7)
	for wolf in game.wolves:
		if is_instance_valid(wolf) and not wolf.dead and position.distance_to(wolf.position)<22:
			threat_memory = wolf.position
			fear_left = maxf(fear_left,10)
	var fleeing := fear_left>0
	if fleeing and not was_fleeing:
		route.clear(); search=null; timer=0
	if search:
		search.advance()
		if search.finished:
			route=search.result; search=null
			if route.is_empty(): abandon_route()

	if reaction.down>0: return
	if timer<=0 and (aquatic or (not search and route.is_empty() and preload("res://scripts/animal_route.gd").permit())):
		timer = 1.8 if fleeing else randf_range(4,7)
		if fleeing: choose_escape()
		elif aquatic:
			var candidate := water_home+Vector3(randf_range(-5,5),0,randf_range(-5,5))
			goal = candidate if water_clear(candidate) else position
		else:
			choose_land_goal(false)
		if not aquatic:
			if game.world.wolf_nav.line_clear(position.x,position.z,goal.x,goal.z):
				route=PackedVector3Array([goal])
			else:
				search=preload("res://scripts/route_search.gd").new()
				search.start(game.world.wolf_nav,position,goal)

	while not route.is_empty() and Vector2(route[0].x-position.x,route[0].z-position.z).length()<.045: route.remove_at(0)
	for shortcut in 2:
		if route.size()>1 and preload("res://scripts/animal_route.gd").corridor_clear(game.world.wolf_nav,position,route[1]): route.remove_at(0)
		else: break
	var destination: Vector3 = goal if aquatic else (route[0] if not route.is_empty() else position)
	var direction := destination-position
	direction.y = 0
	var speed := (6.0 if species=="deer" else 2.3) if fleeing else .65
	if not aquatic: speed *= game.world.wolf_nav.vegetation_factor(position)
	if direction.length()>.025:
		var remaining := direction.length()
		direction = direction.normalized()
		if aquatic:
			var next := position+direction*speed*delta
			if water_clear(next): position = next
		else:
			var steer: Vector3=(direction+separation()*.9).normalized()
			var ahead:=position+steer*minf(.8,speed*delta+.35)
			if not game.world.wolf_nav.line_clear(position.x,position.z,ahead.x,ahead.z): steer=direction
			# Turn continuously; abrupt route/separation changes must not reverse
			# a running deer in one frame. Slow or pivot before a blocked shoreline.
			if movement_heading.length_squared()<.1: movement_heading=steer
			var angle:=movement_heading.signed_angle_to(steer,Vector3.UP)
			movement_heading=movement_heading.rotated(Vector3.UP,clampf(angle,-delta*2.8,delta*2.8)).normalized()
			var corner_speed:=speed*clampf(movement_heading.dot(steer),.15,1.0)
			var look_ahead:=position+movement_heading*maxf(.4,velocity.length()*.22)
			if not game.world.wolf_nav.line_clear(position.x,position.z,look_ahead.x,look_ahead.z): corner_speed=0
			velocity=movement_heading*move_toward(velocity.length(),corner_speed,delta*9)
			var prior := position
			var step := velocity*delta
			if remaining<.3: step=direction*minf(remaining,speed*delta)
			position = game.world.wolf_nav.move_position(position,step.x,step.z)
			blocked_time = blocked_time+delta if position.distance_to(prior)<delta*.1 else 0.0
			if blocked_time>1.4: abandon_route()
		var facing: Vector3=direction if aquatic or movement_heading.length_squared()<.1 else movement_heading
		rotation.y = lerp_angle(rotation.y,atan2(facing.x,facing.z),1-exp(-delta*7))
	if not aquatic:
		if not progress_anchor.is_finite(): progress_anchor=position
		progress_clock+=delta
		if progress_clock>=1.5:
			if not search and not route.is_empty() and position.distance_to(progress_anchor)<.5: abandon_route()
			progress_anchor=position; progress_clock=0
		if route.is_empty():
			velocity=Vector3.ZERO
			if fleeing: timer=minf(timer,.12)
	if aquatic: position.y = -.1+sin(phase*2)*.025
	update_animation(velocity.length() if not aquatic else speed if direction.length()>.025 else 0.0)

func update_animation(speed: float) -> void:
	if not animation or dead or (reaction and reaction.down>0): return
	var clip: String="Run" if speed>.12 else idle_clip
	if animation.has_animation(clip):
		if animation.current_animation!=clip or not animation.is_playing(): animation.play(clip,.2)
		animation.speed_scale=clampf(speed/4.5,.15,1.4) if clip=="Run" else 1.0

func set_network_pose(p: Vector3,yaw: float) -> void:
	if not network_replica: position=p; rotation.y=yaw
	network_replica=true; network_position=p; network_yaw=yaw

func _process(delta: float) -> void:
	if network_replica:
		position=position.lerp(network_position,1-exp(-delta*18))
		rotation.y=lerp_angle(rotation.y,network_yaw,1-exp(-delta*12))

func get_identification() -> String: return species.to_upper()+(" / WOUNDED" if bleeding_rate>0 else "")

func defensive_deer(delta: float) -> bool:
	if species!="deer" or game.free_play or network_replica: return false
	defensive_cooldown=maxf(0,defensive_cooldown-delta); defensive_hit=maxf(0,defensive_hit-delta)
	if defensive_left<=0 and defensive_cooldown<=0 and reaction.down<=0:
		for hunter in [game.player]+game.coop.avatars.values():
			if position.distance_to(hunter.position)>2.8 or game.world.is_safe_position(hunter.position): continue
			defensive_cooldown=25
			if randf()<.22:
				defensive_left=2.4; defensive_target=hunter; route.clear(); search=null
				game.show_notice("The deer lowers its head!",2)
			break
	if defensive_left<=0: alerted=false; return false
	defensive_left=maxf(0,defensive_left-delta); alerted=true; fear_left=0
	if reaction.down>0 or not is_instance_valid(defensive_target) or game.world.is_safe_position(defensive_target.position): defensive_left=0
	if defensive_left<=0:
		alerted=false; frighten(position,12); return false
	var offset: Vector3=defensive_target.position-position; offset.y=0
	var step:=offset.normalized()*minf(offset.length(),delta*3.8)
	position=game.world.wolf_nav.move_position(position,step.x,step.z)
	rotation.y=lerp_angle(rotation.y,atan2(offset.x,offset.z),delta*9); update_animation(3.8)
	if offset.length()<1.6 and defensive_hit<=0:
		var ray:=PhysicsRayQueryParameters3D.create(position+Vector3.UP,defensive_target.position+Vector3.UP,1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			if defensive_target==game.player: game.receive_gunshot(14)
			else:
				var old: int=game.coop.shooter; game.coop.shooter=0; game.coop.friendly_hit(defensive_target.peer_id,14); game.coop.shooter=old
			defensive_hit=1.1
	return true
