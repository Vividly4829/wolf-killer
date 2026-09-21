extends Node
## Shared limb damage, scaled to the individual's original maximum health.
var animal: Node3D
var injuries: Dictionary={}
var severed: Array[String]=[]
var parts: Dictionary={}
var areas: Dictionary={}
static func threshold(maximum_health: float) -> float:
	return maximum_health*clampf(.65+maximum_health/800.0,.65,1.6)
func _ready() -> void:
	process_priority=100
	var species: String="werewolf" if animal is IslandWolf else animal.species
	if species in ["deer","mink"]:
		var skeleton: Skeleton3D=animal.model.find_children("*","Skeleton3D",true,false)[0]
		for side in ["L","R"]:
			for pair in [["front","Frontleg_" if species=="deer" else "Front_"],["rear","Backleg_" if species=="deer" else "Back_"]]:
				var bone:=skeleton.find_bone(pair[1]+side)
				register(pair[0]+("_left_leg" if side=="L" else "_right_leg"),{"skeleton":skeleton,"bone":bone,"nodes":[],"radius":.075 if species=="deer" else .025})
	elif species=="werewolf":
		for zone in animal.LEG_BONES:
			var joint: Node3D=animal.model.joints[("shoulder" if "front" in zone else "hip")+("R" if "left" in zone else "L")]
			register(zone,{"nodes":[joint],"radius":.13})
	else:
		for node in animal.model.get_children():
			if node.has_meta("limb"):
				var zone: String=node.get_meta("limb")
				if not parts.has(zone): parts[zone]={"nodes":[],"radius":.16 if species=="bear" else .045}
				parts[zone].nodes.append(node)
		for zone in parts.keys(): register(zone,parts[zone])
	_process(0)
func register(zone: String,data: Dictionary) -> void:
	parts[zone]=data
	var area:=Area3D.new(); area.collision_layer=2; area.collision_mask=0
	area.set_meta("wolf",animal); area.set_meta("hit_zone",zone); animal.add_child(area)
	var collision:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new()
	capsule.radius=float(data.radius); capsule.height=capsule.radius*2
	collision.shape=capsule; area.add_child(collision); areas[zone]=area
func points(data: Dictionary) -> Array[Vector3]:
	if data.has("skeleton"):
		var skeleton: Skeleton3D=data.skeleton; var bone: int=data.bone
		var start: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin
		var children:=skeleton.get_bone_children(bone)
		var last:=bone
		while not children.is_empty():
			last=children[0]; children=skeleton.get_bone_children(last)
		var end: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(last).origin if last!=bone else start+Vector3.DOWN*.1
		return [start,end]
	var node: Node3D=data.nodes[0]
	if animal is IslandWolf: return [node.global_position,node.to_global(Vector3(0,-.55,0))]
	var axis: Vector3=node.global_basis.z if node.scale.z>node.scale.y else node.global_basis.y
	return [node.global_position+axis*.75,node.global_position-axis*.75]
func _process(_delta: float) -> void:
	for zone in parts:
		var data: Dictionary=parts[zone]
		if severed.has(zone):
			if data.has("skeleton"): data.skeleton.set_bone_pose_scale(data.bone,Vector3.ONE*.001)
			else:
				for node in data.nodes: node.hide()
			areas[zone].collision_layer=0
			continue
		if animal.dead: areas[zone].collision_layer=0; continue
		var endpoints:=points(data); var a: Vector3=endpoints[0]; var b: Vector3=endpoints[1]
		var area: Area3D=areas[zone]; area.global_position=(a+b)*.5
		var capsule: CapsuleShape3D=area.get_child(0).shape
		capsule.height=maxf(capsule.radius*2,a.distance_to(b)+capsule.radius*2)
		if a.distance_to(b)>.001: area.global_basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
func speed_factor() -> float:
	return maxf(.12,1.0-severed.size()*.34-float(injuries.size())*.04)
func hit(zone: String,amount: float,force: float,point: Vector3,direction: Vector3) -> Dictionary:
	if not parts.has(zone) or animal.dead: return {}
	var before: float=animal.health
	var limit:=threshold(animal.max_health)
	injuries[zone]=float(injuries.get(zone,0))+maxf(0,amount)*maxf(0,force)
	if injuries[zone]>=limit and not severed.has(zone):
		severed.append(zone); show_loss(zone,point,direction)
		animal.bleeding_rate=maxf(animal.bleeding_rate,animal.max_health*(.075+.035*severed.size()))
		animal.damage(minf(amount*.22,maxf(0,before-animal.max_health*.12)))
	else:
		animal.bleeding_rate=maxf(animal.bleeding_rate,animal.max_health*.012)
		animal.damage(amount*.35)
	return {"entry":animal.to_local(point),"end":animal.to_local(point+direction*.06),"organs":[],"zone":zone.to_upper()+(" / SEVERED" if severed.has(zone) else " / WOUNDED"),"species":"werewolf" if animal is IslandWolf else animal.species,"damage":before-animal.health,"calculated_damage":before-animal.health,"multiplier":(before-animal.health)/maxf(amount,.001),"fatal":animal.dead,"instant_fatal":false,"bleed":animal.bleeding_rate,"sever_threshold":limit}
func show_loss(zone: String,point: Vector3,direction: Vector3) -> void:
	var data: Dictionary=parts[zone]
	var radius: float=data.radius
	var stump:=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=radius; sphere.height=radius*1.2; sphere.radial_segments=8; sphere.rings=4
	stump.mesh=sphere; var material:=StandardMaterial3D.new(); material.albedo_color=Color("8b2530"); stump.material_override=material
	animal.model.add_child(stump); stump.global_position=points(data)[0]
	animal.game.gore.blood_burst(point,direction,1)
	animal.game.gore.animal_limb(data.nodes,point,direction,radius,.55 if animal.get("species")=="deer" else .12)
	_process(0)
func apply_snapshot(data: Dictionary) -> void:
	injuries=data.get("injuries",{}).duplicate()
	for zone in data.get("severed",[]):
		if parts.has(zone) and not severed.has(zone):
			severed.append(zone); show_loss(zone,points(parts[zone])[0],Vector3.UP)
	_process(0)
func snapshot() -> Dictionary: return {"injuries":injuries,"severed":severed}
