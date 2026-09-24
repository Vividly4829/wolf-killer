extends Node3D
## Shared four-seat boats. Host validates boarding, controls and shoreline exits.
const TOP_SPEED := 6.075 * 1.5
const STOP_SPEED := .12
const SEATS := [Vector3(-.48,.32,-.8),Vector3(.48,.32,-.8),Vector3(-.48,.32,.7),Vector3(.48,.32,.7)]
var game: Node3D
var fleet: Array[Dictionary] = []
var shores: Array[PackedVector2Array] = []
var docks: Array[PackedVector2Array] = []
var water_cache: Dictionary = {}
var elapsed := 0.0
var send_left := 0.0
var last_round := -1

func _ready() -> void:
	name="CoastalBoats"
	var original:=PackedVector2Array()
	for p in game.world.world_data.islandOutline: original.append(Vector2(p[0],p[1]))
	shores.append(original)
	# Context outlines are Blender XY; the original island outline is Godot XZ.
	for outline in game.world.exploration_data.outlines:
		var ring:=PackedVector2Array()
		for p in outline: ring.append(Vector2(p[0],-p[1]))
		shores.append(ring)
	for dock in preload("res://scripts/coastal_reference.gd").DOCKS:
		var ring:=PackedVector2Array()
		for p in dock.polygon: ring.append(Vector2(p[0],p[1]))
		docks.append(ring)
	# Quays in the mapped metre coordinates. Pick the water-facing side without
	# changing the coastline or the original island model.
	for anchor in [Vector3(-17,-.05,9),Vector3(-29,-.05,28),Vector3(6,-.05,62),Vector3(-18,-.05,-58)]:
		var berth: Vector3=anchor if water_clear(anchor,0) and shore_exit(anchor).is_finite() else find_berth(anchor)
		if not berth.is_finite(): continue
		var model:=preload("res://scripts/coastal_boat_model.gd").new()
		model.variant=fleet.size(); add_child(model); model.position=berth
		fleet.append({"node":model,"p":berth,"home":berth,"yaw":0.0,"speed":0.0,"riders":[],"axis":Vector2.ZERO,"input_at":0.0,"shore":shore_exit(berth),"shore_at":0.0})

func on_land(point: Vector3) -> bool:
	var key:=Vector2i(roundi(point.x*2),roundi(point.z*2))
	if water_cache.has(key): return water_cache[key]
	var occupied:=false
	for polygon in shores:
		if Geometry2D.is_point_in_polygon(Vector2(key.x*.5,key.y*.5),polygon): occupied=true; break
	water_cache[key]=occupied
	return occupied

func on_dock(point: Vector3) -> bool:
	for polygon in docks:
		if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon): return true
	return false

func water_clear(point: Vector3, heading: float, ignore: int = -1) -> bool:
	if point.x < -245 or point.x>215 or point.z < -225 or point.z>180: return false
	for x in [-.85,0.0,.85]:
		for z in [-2.1,0.0,2.1]:
			var p: Vector3=point+Vector3(x,0,z).rotated(Vector3.UP,heading)
			if on_land(p) or on_dock(p): return false
	for i in fleet.size():
		if i!=ignore and point.distance_to(fleet[i].p)<4.6: return false
	return true

func shore_exit(point: Vector3) -> Vector3:
	var best:=Vector3.INF; var score:=INF
	# The walkable cell must also be on actual land or close to its edge: no
	# disembarking onto the middle of a long bridge over open water.
	for angle_index in 16:
		for radius in [2.0,3.0,4.0]:
			var sample: Vector3=point+Vector3(cos(angle_index*TAU/16),0,sin(angle_index*TAU/16))*radius
			var cell: int=game.world.nav.nearest(sample.x,sample.z,.8)
			if cell<0: continue
			var p: Vector3=game.world.nav.point(cell)
			if p.y<.05 or p.y>1.85 or game.world.nav.distances[cell]<0: continue
			var near_land:=on_land(p) or on_dock(p)
			for offset in [Vector3(1.5,0,0),Vector3(-1.5,0,0),Vector3(0,0,1.5),Vector3(0,0,-1.5)]: near_land=near_land or on_land(p+offset)
			if not near_land: continue
			var d:=Vector2(p.x-point.x,p.z-point.z).length()
			if d<=4.1 and d<score and boarding_clear(point,p): score=d; best=p
	return best

func boarding_clear(boat: Vector3,land: Vector3) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(boat+Vector3.UP*1.7,land+Vector3.UP,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func find_berth(anchor: Vector3) -> Vector3:
	var best:=Vector3.INF; var distance:=INF
	for x in range(-9,10):
		for z in range(-9,10):
			var p:=Vector3(roundf(anchor.x)+x,-.05,roundf(anchor.z)+z)
			var d:=p.distance_squared_to(anchor)
			if d>=distance or not water_clear(p,0): continue
			if shore_exit(p).is_finite(): best=p; distance=d
	return best

func local_id() -> int: return game.coop.peer_id() if game.coop.active else 1
func occupied(peer: int) -> int:
	for i in fleet.size():
		if fleet[i].riders.has(peer): return i
	return -1
func hunter(peer: int) -> Node3D: return game.player if peer==1 else game.coop.avatars.get(peer)
func nearby(p: Vector3) -> int:
	for i in fleet.size():
		if p.distance_to(fleet[i].p)<4.3: return i
	return -1
func prompt() -> String:
	var key: String="Y" if game.controller_device>=0 else "E"
	var i:=occupied(local_id())
	if i>=0:
		var boat:=fleet[i]
		var driver: bool=boat.riders[0]==local_id()
		var help: String=("W/S throttle • A/D steer • Space brake" if game.controller_device<0 else "Left stick steer/throttle • A brake") if driver else "PASSENGER"
		var exit_text: String="[ %s ] DISEMBARK"%key if absf(boat.speed)<=STOP_SPEED and boat.shore.is_finite() else "STOP NEAR SHORE TO DISEMBARK"
		return "BOAT %d/4 • %.1f km/h • %s • %s"%[boat.riders.size(),absf(boat.speed)*3.6,help,exit_text]
	i=nearby(game.player.position)
	if i<0: return ""
	if fleet[i].riders.size()>=4: return "BOAT FULL / 4 PASSENGERS"
	if absf(fleet[i].speed)>STOP_SPEED: return "WAIT UNTIL THE BOAT STOPS"
	return "[ %s ] BOARD BOAT / UP TO 4 PLAYERS"%key if fleet[i].shore.is_finite() else "BOAT TOO FAR FROM SHORE"

func interact() -> bool:
	if occupied(local_id())<0 and nearby(game.player.position)<0: return false
	if game.coop.client(): game.coop.send_to(1,"boat_interact",[])
	else: request(1)
	return true

func request(peer: int) -> bool:
	if game.coop.client() or not game.is_playing(): return false
	var actor:=hunter(peer)
	if not is_instance_valid(actor): return false
	if (game.health<=0 or game.is_struggling()) if peer==1 else (actor.health<=0 or actor.mauling!=0): return false
	if game.rituals.tasks.has(peer): return false
	var i:=occupied(peer)
	if i<0: i=nearby(actor.position)
	if i<0: return false
	var boat:=fleet[i]
	boat.shore=shore_exit(boat.p)
	if absf(boat.speed)>STOP_SPEED or not boat.shore.is_finite(): return false
	if boat.riders.has(peer):
		boat.riders.erase(peer); boat.axis=Vector2.ZERO; boat.speed=0
		actor.position=boat.shore
		if peer!=1: game.coop.send_to(peer,"boat_exit",[boat.shore])
	else:
		if boat.riders.size()>=4 or actor.position.distance_to(boat.shore)>5 or not boarding_clear(boat.p,actor.position): return false
		boat.riders.append(peer)
		if peer==1: game.player.yaw=boat.yaw; game.player._update_rotation()
	place_riders()
	if game.coop.active: game.coop.send_all("boat_state",[snapshot()])
	return true

func control(peer: int, axis: Vector2, brake: bool) -> void:
	if game.coop.client() or not axis.is_finite(): return
	var i:=occupied(peer)
	if i<0 or fleet[i].riders[0]!=peer: return
	fleet[i].axis=Vector2.ZERO if brake else axis.limit_length(1)
	fleet[i]["brake"]=brake
	fleet[i].input_at=elapsed

func local_control(axis: Vector2, brake: bool, delta: float) -> void:
	if game.coop.client():
		send_left-=delta
		if send_left<=0: send_left=.05; game.coop.send_to(1,"boat_control",[axis,brake])
	else: control(1,axis,brake)

func _physics_process(delta: float) -> void:
	elapsed+=delta
	if game.coop.client():
		for boat in fleet:
			boat.node.position=boat.node.position.lerp(boat.p,minf(1,delta*18))
			boat.node.rotation.y=lerp_angle(boat.node.rotation.y,boat.yaw,minf(1,delta*18))
		place_riders(true); return
	if not game.is_playing():
		for boat in fleet:
			boat.speed=0; boat.axis=Vector2.ZERO
			if game.mode in ["resting","menu","dead","victory"]: boat.riders.clear()
		return
	for i in fleet.size():
		var boat:=fleet[i]
		for peer in boat.riders.duplicate():
			var actor:=hunter(peer)
			if not is_instance_valid(actor) or (game.health<=0 if peer==1 else actor.health<=0): boat.riders.erase(peer); boat.axis=Vector2.ZERO
		var axis: Vector2=boat.axis if elapsed-float(boat.input_at)<.25 and not boat.riders.is_empty() else Vector2.ZERO
		var braking: bool=boat.get("brake",false) or axis==Vector2.ZERO
		boat.speed=move_toward(float(boat.speed),-axis.y*TOP_SPEED,delta*(7.0 if braking else 2.8))
		var yaw: float=boat.yaw-axis.x*delta*1.0*clampf(absf(boat.speed)/2,.4,1)*(-1 if boat.speed<0 else 1)
		var next: Vector3=boat.p+Vector3(-sin(yaw),0,-cos(yaw))*boat.speed*delta
		if water_clear(next,yaw,i) and passage_clear(boat.p,next,yaw): boat.p=next; boat.yaw=yaw
		else: boat.speed=0
		boat.node.position=boat.p; boat.node.rotation.y=boat.yaw
		boat.node.moving=absf(boat.speed)
		if elapsed>=float(boat.shore_at) and (absf(boat.speed)>.01 or boat.shore_at==0): boat.shore=shore_exit(boat.p); boat.shore_at=elapsed+.5
	place_riders()

func passage_clear(a: Vector3,b: Vector3,yaw: float) -> bool:
	if a.distance_squared_to(b)<.000001: return true
	# Swept rays protect docks, rocks and low bridges, including at full speed.
	for side in [-.85,.85]:
		for height in [.35,1.5,2.1]:
			var offset:=Vector3(side,height,-2.15 if (b-a).dot(Vector3(-sin(yaw),0,-cos(yaw)))>=0 else 2.15).rotated(Vector3.UP,yaw)
			var query:=PhysicsRayQueryParameters3D.create(a+offset,b+offset,1)
			if a.distance_squared_to(b)>.000001 and not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	return true

func place_riders(visual: bool = false) -> void:
	for boat in fleet:
		for seat in boat.riders.size():
			var id: int=boat.riders[seat]
			var actor: Node3D=game.player if id==local_id() else game.coop.avatars.get(id)
			if not is_instance_valid(actor): continue
			actor.position=(boat.node.position if visual else boat.p)+SEATS[seat].rotated(Vector3.UP,boat.node.rotation.y if visual else boat.yaw)

func snapshot() -> Array:
	var result: Array=[]
	for boat in fleet: result.append({"p":boat.p,"yaw":boat.yaw,"speed":boat.speed,"riders":boat.riders.duplicate(),"shore":boat.shore})
	return result
func apply_snapshot(data: Array) -> void:
	if not game.coop.client(): return
	var previously:=occupied(local_id())
	for i in mini(data.size(),fleet.size()):
		for key in ["p","yaw","speed","riders","shore"]: fleet[i][key]=data[i][key]
		fleet[i].node.moving=absf(fleet[i].speed)
	var current:=occupied(local_id())
	if previously<0 and current>=0: game.player.yaw=fleet[current].yaw; game.player._update_rotation()
	place_riders(true)
func release_all() -> void:
	for boat in fleet:
		boat.riders.clear(); boat.speed=0; boat.axis=Vector2.ZERO
		boat.p=boat.home; boat.yaw=0; boat.node.position=boat.home; boat.node.rotation.y=0; boat.node.moving=0
		boat.shore=shore_exit(boat.home); boat.shore_at=0
