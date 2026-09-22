extends Node3D
## Bounded cosmetic effects. They never change bullet collision or navigation.
var game: Node3D
var vegetation: Dictionary={}
var disturbed: Dictionary={}
var shots: Array[String]=[]
func _ready() -> void:
	for batch in game.world.find_children("*","MultiMeshInstance3D",true,false):
		if not batch.multimesh: continue
		var parent_script = batch.get_parent().get_script()
		if not str(batch.name).begins_with("BirchCanopy") and (parent_script==null or not parent_script.resource_path.ends_with("undergrowth.gd")): continue
		for i in batch.multimesh.instance_count:
			var rest: Transform3D=batch.multimesh.get_instance_transform(i)
			var pose: Transform3D=batch.global_transform*rest
			var radius:=maxf(.6,maxf(pose.basis.x.length(),maxf(pose.basis.y.length(),pose.basis.z.length())))
			var key:=Vector3i((pose.origin/8).floor())
			if not vegetation.has(key): vegetation[key]=[]
			vegetation[key].append({"batch":batch,"index":i,"rest":rest,"center":pose.origin,"radius":radius})
func effect(label: String,lifetime: float) -> Node3D:
	while get_child_count()>=64:
		var old:=get_child(0); remove_child(old); old.queue_free()
	var node:=Node3D.new(); node.name=label; add_child(node)
	var tween:=node.create_tween(); tween.tween_interval(lifetime); tween.tween_callback(node.queue_free)
	return node
static func material(color: Color, glow: bool=false) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.albedo_color=color; m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.no_depth_test=false
	if glow: m.emission_enabled=true; m.emission=color; m.emission_energy_multiplier=2
	return m
func fragments(point: Vector3,normal: Vector3,kind: String) -> void:
	var node:=effect("LeafBurst" if kind=="leaves" else "ImpactDebris",1.5)
	node.position=point
	var particles:=CPUParticles3D.new(); node.add_child(particles)
	particles.amount=12; particles.lifetime=1.15; particles.one_shot=true; particles.explosiveness=1
	particles.direction=normal; particles.spread=65; particles.gravity=Vector3.DOWN*3
	particles.initial_velocity_min=.8; particles.initial_velocity_max=3.3
	particles.angular_velocity_min=-180; particles.angular_velocity_max=180
	var mesh:=BoxMesh.new(); mesh.size=Vector3(.06,.009,.12) if kind=="leaves" else Vector3(.026,.025,.085)
	var color: Color={"leaves":Color("809347"),"wood":Color("9f754b"),"stone":Color("969589"),"soil":Color("85715a")}.get(kind,Color("85715a"))
	mesh.material=material(color); particles.mesh=mesh
	var ramp:=Gradient.new(); ramp.set_color(0,Color.WHITE); ramp.set_color(1,Color(1,1,1,0)); particles.color_ramp=ramp
	particles.emitting=true
	if kind!="leaves":
		var dust:=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=.12; sphere.height=.24; sphere.radial_segments=8; sphere.rings=4
		dust.mesh=sphere; var mat:=material(Color(color,.28)); dust.material_override=mat; node.add_child(dust)
		var tween:=dust.create_tween().set_parallel(true)
		tween.tween_property(dust,"scale",Vector3.ONE*3,.7); tween.tween_property(dust,"position",normal*.45+Vector3.UP*.15,.7); tween.tween_property(mat,"albedo_color:a",0,.7)
func impact(point: Vector3,normal: Vector3,kind: String) -> void:
	if normal.length_squared()<.1: normal=Vector3.UP
	fragments(point,normal,kind)
	var mark:=effect("BulletScar",12)
	mark.position=point+normal*.012; mark.quaternion=Quaternion(Vector3.UP,normal.normalized())
	var disk:=MeshInstance3D.new(); var mesh:=CylinderMesh.new(); mesh.top_radius=.037; mesh.bottom_radius=.05; mesh.height=.005; mesh.radial_segments=9
	disk.mesh=mesh; var mat:=material(Color(.12,.09,.065,.8)); disk.material_override=mat; mark.add_child(disk)
	var fade:=mark.create_tween(); fade.tween_interval(8); fade.tween_property(mat,"albedo_color:a",0,3)
func ballistic(points: PackedVector3Array,token: String) -> bool:
	if points.size()<2 or shots.has(token): return false
	shots.append(token)
	if shots.size()>96: shots.pop_front()
	var node:=effect("ShotSmokeTrail",1.0)
	var mat:=material(Color(.80,.81,.76,.19))
	var stride:=maxi(1,ceili(float(points.size()-1)/20))
	var previous: Vector3=points[0]
	for i in range(stride,points.size()+stride,stride):
		var end: Vector3=points[mini(i,points.size()-1)]
		if previous.distance_to(end)>.001:
			var streak:=MeshInstance3D.new(); var mesh:=CylinderMesh.new()
			mesh.top_radius=.019; mesh.bottom_radius=.027; mesh.height=previous.distance_to(end); mesh.radial_segments=5
			streak.mesh=mesh; streak.material_override=mat; streak.position=(previous+end)*.5
			streak.quaternion=Quaternion(Vector3.UP,(end-previous).normalized()); streak.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(streak)
		previous=end
	var tween:=node.create_tween().set_parallel(true)
	tween.tween_property(mat,"albedo_color:a",0,.85); tween.tween_property(node,"position",Vector3.UP*.15,.85)
	var count:=0
	for i in range(1,points.size()):
		var key:=Vector3i((points[i]/8).floor())
		for x in range(-1,2):
			for y in range(-1,2):
				for z in range(-1,2):
					for leaf in vegetation.get(key+Vector3i(x,y,z),[]):
						var id: String=str(leaf.batch.get_instance_id())+":"+str(leaf.index)
						if disturbed.has(id) or Geometry3D.get_closest_point_to_segment(leaf.center,points[i-1],points[i]).distance_to(leaf.center)>leaf.radius: continue
						disturbed[id]=true; count+=1
						fragments(Geometry3D.get_closest_point_to_segment(leaf.center,points[i-1],points[i]),Vector3.UP,"leaves")
						var motion:=create_tween()
						motion.tween_method(func(t: float):
							if is_instance_valid(leaf.batch):
								var pose: Transform3D=leaf.rest
								pose.basis=pose.basis.rotated(Vector3.FORWARD,sin(t*22)*.10*(1-t))
								leaf.batch.multimesh.set_instance_transform(leaf.index,pose),0.0,1.0,1.0)
						motion.tween_callback(func(): disturbed.erase(id))
						if count>=3: return true
	return true
func muzzle(point: Vector3,direction: Vector3) -> void:
	var node:=effect("MuzzleFlame",.18); node.position=point
	if direction.length_squared()<.1: return
	node.quaternion=Quaternion(Vector3.FORWARD,direction.normalized())
	for i in 3:
		var fire:=MeshInstance3D.new(); var mesh:=CylinderMesh.new()
		mesh.top_radius=.006; mesh.bottom_radius=.075-i*.018; mesh.height=.48-i*.11; mesh.radial_segments=7
		fire.mesh=mesh; fire.rotation.x=-PI/2; fire.position.z=-mesh.height*.5
		var mat:=material(Color(1,.3+i*.25,.035+i*.25,.85),true); fire.material_override=mat; node.add_child(fire)
		var tween:=fire.create_tween().set_parallel(true); tween.tween_property(mat,"albedo_color:a",0,.16); tween.tween_property(fire,"scale",Vector3(.35,.7,.35),.16)
