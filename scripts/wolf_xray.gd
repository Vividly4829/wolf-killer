extends SubViewportContainer
const Anatomy = preload("res://scripts/wolf_anatomy.gd")
var front_view := false
var scene: Node3D
var impacts: Node3D
var bone: StandardMaterial3D
var rods: Array[Transform3D] = []
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
	camera.size = 1.25
	scene.add_child(camera)
	camera.position = Vector3(0,.60,3) if front_view else Vector3(3,.87,.2)
	camera.look_at(Vector3(0,.52,0))
	bone = material(Color(.55,.89,1,.78))
	var skin := preload("res://assets/wolf.glb").instantiate()
	skin.scale = Vector3.ONE*.27931
	skin.position = Vector3(0,.00036,.06887)
	scene.add_child(skin)
	var translucent := material(Color(.06,.32,1,.27))
	for mesh in skin.find_children("*","MeshInstance3D",true,false): mesh.material_override = translucent
	# Canid vertebral column, rib basket, scapulae, pelvis and four articulated limbs.
	for i in 23:
		var z := -.56+i*.048
		var y := .78+.09*smoothstep(.1,.54,z)
		ellipsoid(Vector3(0,y,z),Vector3(.045,.035,.022),bone)
		rod(Vector3(0,y,z),Vector3(0,y+.065,z-.02),.013)
	for i in 10:
		var z := -.18+i*.045
		var radius := .16+sin(float(i)/9*PI)*.035
		for side in [-1,1]:
			var last := Vector3(0,.79,z)
			for k in range(1,10):
				var a := k*PI/10
				var p := Vector3(side*sin(a)*radius,.58+cos(a)*.21,z-.05*sin(a))
				rod(last,p,.009)
				last = p
	for side in [-1,1]:
		var x: float = side*.155
		var shoulder := Vector3(x,.69,.36)
		rod(shoulder,Vector3(x,.84,.20),.032)
		var elbow := Vector3(x,.38,.30)
		var wrist := Vector3(x,.10,.43)
		rod(shoulder,elbow,.025)
		rod(elbow,wrist,.017)
		rod(Vector3(x+.018,.38,.30),Vector3(x+.012,.1,.43),.01)
		var hip := Vector3(x,.71,-.48)
		var knee := Vector3(x,.40,-.29)
		var hock := Vector3(x,.18,-.53)
		rod(Vector3(0,.79,-.45),hip,.04)
		rod(hip,knee,.03)
		rod(knee,hock,.022)
		rod(hock,Vector3(x,.05,-.44),.013)
		for z in [.44,-.44]:
			for toe in 4:
				var foot := Vector3(x+(toe-1.5)*.022,.045,z)
				rod(foot,foot+Vector3(0,-.015,.085),.008)
	# Long muzzle, separate mandible, cheek arches and teeth give a canine skull silhouette.
	ellipsoid(Vector3(0,.91,.60),Vector3(.12,.105,.15),bone)
	ellipsoid(Vector3(0,.83,.77),Vector3(.065,.052,.13),bone)
	for side in [-1,1]:
		rod(Vector3(side*.085,.83,.55),Vector3(side*.047,.76,.86),.017)
		rod(Vector3(side*.115,.91,.57),Vector3(side*.055,.84,.74),.018)
		for tooth in 7:
			var z := .70+tooth*.025
			rod(Vector3(side*.048,.81,z),Vector3(side*.045,.77,z+.005),.005)
	var tail := Vector3(0,.74,-.55)
	for i in 13:
		var p := tail+Vector3(0,-.025,-.033)
		rod(tail,p,.018-i*.0008)
		tail = p
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1
	cylinder.bottom_radius = 1
	cylinder.height = 1
	cylinder.radial_segments = 8
	batch.multimesh.mesh = cylinder
	batch.multimesh.instance_count = rods.size()
	for i in rods.size(): batch.multimesh.set_instance_transform(i,rods[i])
	batch.material_override = bone
	scene.add_child(batch)
	impacts = Node3D.new()
	scene.add_child(impacts)
func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
func ellipsoid(p: Vector3,r: Vector3,mat: Material,parent: Node3D = null) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 20
	mesh.rings = 10
	node.mesh = mesh
	node.scale = r
	node.position = p
	node.material_override = mat
	(parent if parent else scene).add_child(node)
func rod(a: Vector3,b: Vector3,radius: float) -> void:
	rods.append(Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())).scaled_local(Vector3(radius,a.distance_to(b),radius)),(a+b)*.5))
func review(reports: Array[Dictionary]) -> void:
	for child in impacts.get_children(): child.free()
	var affected: Array = []
	for report: Dictionary in reports:
		for id in report.organs: if not affected.has(id): affected.append(id)
	for organ: Dictionary in Anatomy.ORGANS:
		ellipsoid(organ.center,organ.radii,material(Color(1,.15,.21,.66) if affected.has(organ.id) else Color(.12,.42,.72,.16)),impacts)
	for report: Dictionary in reports:
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
		node.material_override = material(Color("fff4c4"))
		impacts.add_child(node)
		if not report.get("unhit",false): ellipsoid(a,Vector3.ONE*.055,material(Color("ff172e")),impacts)
	get_child(0).render_target_update_mode = SubViewport.UPDATE_ONCE
