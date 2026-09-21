extends "res://scripts/wolf_xray.gd"
var species := ""
var camera: Camera3D
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240,210) if front_view else Vector2i(410,210)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	scene = Node3D.new(); viewport.add_child(scene)
	camera = Camera3D.new(); scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	bone = material(Color(.55,.89,1,.9))
func review(reports: Array[Dictionary]) -> void:
	if reports.is_empty(): return
	var shot: Dictionary = reports.back()
	if shot.get("species","") not in ["deer","duck","goose","mink","bear"]: return
	species = shot.species
	for child in scene.get_children():
		if child!=camera: child.free()
	rods.clear()
	var deer := species in ["deer","bear"]
	var bird := species in ["duck","goose"]
	var height := .95 if deer else (.28 if bird else .15)
	var length := 1.0 if species=="bear" else .65 if deer else (.27 if bird else .24)
	var width := .36 if species=="bear" else .19 if deer else (.14 if bird else .06)
	var organs: Array = preload("res://scripts/wildlife_anatomy.gd").organs(species)
	var head: Vector3 = organs[1].center
	ellipsoid(Vector3(0,height-.10,0),Vector3(width*1.2,height*.27,length),material(Color(.08,.3,.9,.18)))
	for i in 18:
		var z := lerpf(-length,length*.6,i/17.0)
		ellipsoid(Vector3(0,height,z),Vector3(width*.18,width*.12,length*.05),bone)
	for i in 9:
		var z := lerpf(-length*.5,length*.5,i/8.0)
		for side in [-1,1]:
			var prior := Vector3(0,height,z)
			for k in range(1,9):
				var a := k*PI/8
				var p := Vector3(side*sin(a)*width,height-width+cos(a)*width,z)
				rod(prior,p,.009 if deer else .004); prior=p
	rod(Vector3(0,height,length*.55),head,.035 if deer else .015)
	ellipsoid(head,organs[1].radii*1.45,bone)
	ellipsoid(head+Vector3(0,-.035,.10 if deer else .06),Vector3(.055,.04,.11) if deer else Vector3(.035,.018,.065),bone)
	for side in [-1,1]:
		for z in [-length*.65,length*.55]:
			if bird and z>0:
				rod(Vector3(side*width,height,z),Vector3(side*width*2,height-.06,-length*.3),.009)
				for feather in 5: rod(Vector3(side*width*2,height-.06,-length*.3),Vector3(side*(width*2+feather*.025),height-.1,-length*.9),.003)
			else:
				var hip := Vector3(side*width*.65,height-.05,z)
				var knee := Vector3(hip.x,height*.45,z+.06)
				var foot := Vector3(hip.x,.035,z)
				rod(hip,knee,.022 if deer else .009); rod(knee,foot,.013 if deer else .006)
				ellipsoid(foot,Vector3(.028,.025,.045) if deer else Vector3(.012,.012,.028),bone)
	if species=="deer":
		for side in [-1,1]:
			var tip := head+Vector3(side*.25,.42,-.12)
			rod(head,tip,.017)
			for tine in 3:
				var start := head.lerp(tip,.35+tine*.2)
				rod(start,start+Vector3(side*.1,.14,.05),.010)
	for pose in rods:
		var part := MeshInstance3D.new(); var mesh := CylinderMesh.new()
		mesh.top_radius=1; mesh.bottom_radius=1; mesh.height=1; mesh.radial_segments=8
		part.mesh=mesh; part.transform=pose; part.material_override=bone; scene.add_child(part)
	for organ in organs: ellipsoid(organ.center,organ.radii,material(Color(1,.1,.15,.8) if shot.organs.has(organ.id) else Color(.1,.4,.8,.25)))
	var beam := MeshInstance3D.new(); var shaft := CylinderMesh.new()
	shaft.top_radius=.006; shaft.bottom_radius=.006; shaft.height=shot.entry.distance_to(shot.end)
	beam.mesh=shaft; beam.position=(shot.entry+shot.end)*.5
	beam.quaternion=Quaternion(Vector3.UP,(shot.end-shot.entry).normalized())
	beam.material_override=material(Color("ffc977")); scene.add_child(beam)
	var middle := .94 if deer else (.40 if species=="goose" else (.26 if species=="duck" else .15))
	camera.size=3.0 if species=="bear" else 2.15 if deer else (1.0 if species=="goose" else .72)
	camera.position=Vector3(0,middle,3) if front_view else Vector3(3,middle+.10,.2); camera.look_at(Vector3(0,middle,0))
	get_child(0).render_target_update_mode=SubViewport.UPDATE_ONCE
