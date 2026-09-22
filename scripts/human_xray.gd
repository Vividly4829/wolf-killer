extends "res://scripts/wolf_xray.gd"
const ORGANS := [
	{"id":"brain","center":Vector3(0,1.65,0),"radii":Vector3(.11,.12,.11)},
	{"id":"heart","center":Vector3(-.06,1.20,0),"radii":Vector3(.07,.09,.08)},
	{"id":"left lung","center":Vector3(-.13,1.27,0),"radii":Vector3(.09,.16,.10)},
	{"id":"right lung","center":Vector3(.13,1.27,0),"radii":Vector3(.09,.16,.10)},
	{"id":"liver","center":Vector3(.09,1.04,0),"radii":Vector3(.12,.07,.08)}]
static func trace(entry: Vector3,direction: Vector3,amount: float,penetration: float=.65) -> Dictionary:
	penetration=Anatomy.tissue_length(entry,direction,penetration,[{"center":Vector3(0,1.17,0),"radii":Vector3(.28,.40,.20)},{"center":Vector3(0,1.65,0),"radii":Vector3(.15,.18,.15)},{"center":Vector3(-.13,.43,0),"radii":Vector3(.12,.43,.13)},{"center":Vector3(.13,.43,0),"radii":Vector3(.12,.43,.13)}])
	var organs: Array[String] = []
	var multiplier := .65 if entry.y<.8 else (.75 if absf(entry.x)>.23 else 1.0)
	for organ in ORGANS:
		if Anatomy.intersect_ellipsoid(entry,direction,organ.center,organ.radii,penetration)<INF: organs.append(organ.id)
	if organs.has("brain"): multiplier = 2.5
	elif organs.has("heart"): multiplier = 2.0
	elif not organs.is_empty(): multiplier = 1.4
	return {"entry":entry,"end":entry+direction*penetration,"organs":organs,"zone":"FRIENDLY FIRE / "+("HEAD" if entry.y>1.5 else ("LEG" if entry.y<.8 else "BODY")),"species":"hunter","multiplier":multiplier,"calculated_damage":amount*multiplier,"damage":0.0}
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240,210) if front_view else Vector2i(410,210)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	scene = Node3D.new()
	viewport.add_child(scene)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.1
	scene.add_child(camera)
	camera.position = Vector3(0,.95,-4) if front_view else Vector3(4,1.0,.3)
	camera.look_at(Vector3(0,.91,0))
	bone = material(Color(.55,.89,1,.9))
	var blue := material(Color(.08,.3,.9,.22))
	ellipsoid(Vector3(0,1.18,0),Vector3(.27,.34,.15),blue)
	ellipsoid(Vector3(0,1.66,0),Vector3(.145,.18,.135),blue)
	ellipsoid(Vector3(0,1.66,0),Vector3(.12,.15,.11),bone)
	ellipsoid(Vector3(0,.85,0),Vector3(.19,.10,.09),bone)
	for i in 17: ellipsoid(Vector3(0,.86+i*.039,.025),Vector3(.033,.017,.035),bone)
	for i in 8:
		var y := 1.05+i*.046
		var width := .16+sin(float(i)/7*PI)*.045
		for side in [-1,1]:
			var previous := Vector3(0,y,.055)
			for step in range(1,12):
				var angle := step*PI/11
				var point := Vector3(side*sin(angle)*width,y-.045*sin(angle),cos(angle)*.11)
				rod(previous,point,.009)
				previous = point
	for side in [-1,1]:
		rod(Vector3(0,1.46,0),Vector3(side*.25,1.43,0),.025)
		var shoulder := Vector3(side*.25,1.43,0)
		var elbow := Vector3(side*.34,1.13,0)
		var wrist := Vector3(side*.37,.88,.015)
		rod(shoulder,elbow,.025)
		rod(elbow,wrist,.018)
		for finger in 5: rod(wrist+Vector3(finger*.012,0,0),wrist+Vector3(finger*.015,-.13,0),.006)
		var hip := Vector3(side*.12,.83,0)
		var knee := Vector3(side*.13,.46,.025)
		var ankle := Vector3(side*.13,.08,0)
		rod(hip,knee,.033)
		rod(knee,ankle,.024)
		rod(ankle,ankle+Vector3(0,-.035,.16),.03)
		ellipsoid((hip+knee)*.5,Vector3(.085,.22,.085),blue)
		ellipsoid((shoulder+elbow)*.5,Vector3(.075,.19,.075),blue)
	for transform in rods:
		var segment := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1
		mesh.bottom_radius = 1
		mesh.height = 1
		mesh.radial_segments = 8
		segment.mesh = mesh
		segment.transform = transform
		segment.material_override = bone
		scene.add_child(segment)
	impacts = Node3D.new()
	scene.add_child(impacts)
func review(reports: Array[Dictionary]) -> void:
	for child in impacts.get_children(): child.free()
	var affected: Array = []
	for report in reports: affected.append_array(report.organs)
	for organ in ORGANS: ellipsoid(organ.center,organ.radii,material(Color(1,.12,.2,.7) if affected.has(organ.id) else Color(.15,.4,.8,.2)),impacts)
	for report in reports:
		var a: Vector3 = report.entry
		var b: Vector3 = report.end
		var node := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = .019
		mesh.bottom_radius = .019
		mesh.height = maxf(.001,a.distance_to(b))
		node.mesh = mesh
		node.position = (a+b)*.5
		if a.distance_to(b)>.001: node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
		node.material_override = material(Color("ffc977"))
		impacts.add_child(node)
		if not report.get("unhit",false): ellipsoid(a,Vector3.ONE*.05,material(Color("ff172e")),impacts)
	get_child(0).render_target_update_mode = SubViewport.UPDATE_ONCE
