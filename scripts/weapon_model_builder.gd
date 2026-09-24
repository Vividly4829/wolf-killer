extends RefCounted

## Original procedural period armory. Measurements are metres; muzzles face -Z.
## Each mechanism is a separate transform. Its decorative meshes are merged by
## material, keeping the detailed round work inexpensive in the live viewport.
const NAMES := ["Frontier flintlock", "Hammer coach gun", "Winchester 1873", "Hunting crossbow", "Dueling flintlock", "Blunderbuss", "Allen pepperbox", "Colt 1851 Navy", "Remington 1858", "LeMat 1856", "Remington derringer", "Colt Single Action Army", "Schofield 1875", "Snider-Enfield", "Martini-Henry", "Sharps 1874", "Spencer 1865", "Winchester 1887"]
# PackedScene stores immutable mesh/material resources and serialized node data,
# never a live template. Each instance owns its mechanisms and animation state.
static var _model_cache: Dictionary = {}
var root: Node3D
var actions: Dictionary = {}
var materials: Dictionary = {}
var muzzle := Vector3.ZERO
var secondary_muzzle := Vector3.ZERO
var sight := Vector3.ZERO
var action: String = "muzzle"
var index: int = 0
var source_meshes: int = 0
var mesh_count: int = 0
var source_triangles: int = 0

static func warm_cache() -> void:
	var builder: RefCounted = (load("res://scripts/weapon_model_builder.gd") as GDScript).new()
	for weapon_index: int in preload("res://scripts/weapon_catalog.gd").WEAPONS.size():
		if _model_cache.has(weapon_index): continue
		var model: Dictionary = builder.call("build", weapon_index)
		(model.root as Node3D).free()

func build(weapon_index: int) -> Dictionary:
	index = clampi(weapon_index, 0, preload("res://scripts/weapon_catalog.gd").WEAPONS.size()-1)
	if _model_cache.has(index): return _instantiate_cached(_model_cache[index])
	# A builder can be reused; no scratch state may leak into the next model.
	actions = {}
	materials = {}
	sight = Vector3.ZERO
	muzzle = Vector3.ZERO
	secondary_muzzle = Vector3.ZERO
	action = "muzzle"
	source_meshes = 0
	mesh_count = 0
	source_triangles = 0
	root = Node3D.new()
	root.name = "HistoricalWeapon"
	_make_materials()
	match index:
		0, 4, 5: _flintlock()
		1: _coach_gun()
		3: _crossbow()
		6: _pepperbox()
		7, 8, 9, 11, 12: _revolver()
		10: _derringer()
		18,19,20,21,22,23: _field_weapon()
		24,25,26: _experimental()
		27: _lancaster()
		28: _mauser_revolver()
		29: _mauser_rifle()
		30: _naval_pair()
		31,32: _paired_period()
		33: _luger()
		34: _hand_mortar()
		35: _fire_siphon()
		_: _rifle()
	if sight==Vector3.ZERO: sight = muzzle+Vector3(0,.035,0)
	for key: String in actions:
		var node: Node3D = actions[key]
		node.set_meta("rest", node.transform)
	_merge_group(root)
	mesh_count = _count_meshes(root)
	var metadata := {"sight": sight, "muzzle": muzzle, "secondary_muzzle": secondary_muzzle, "action": action, "name": preload("res://scripts/weapon_catalog.gd").WEAPONS[index].name, "mesh_count": mesh_count, "source_meshes": source_meshes, "source_triangles": source_triangles, "triangles": _count_triangles(root)}
	var action_paths: Dictionary = {}
	for key: String in actions: action_paths[key] = root.get_path_to(actions[key])
	_assign_scene_owners(root)
	var scene := PackedScene.new()
	if scene.pack(root) == OK:
		_model_cache[index] = {"scene": scene, "metadata": metadata.duplicate(), "action_paths": action_paths}
	metadata["root"] = root
	metadata["actions"] = actions
	return metadata

func _assign_scene_owners(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.owner = root
		_assign_scene_owners(child)

func _instantiate_cached(cached: Dictionary) -> Dictionary:
	root = (cached.scene as PackedScene).instantiate() as Node3D
	actions = {}
	for key: String in cached.action_paths:
		actions[key] = root.get_node(cached.action_paths[key])
	var metadata: Dictionary = cached.metadata.duplicate()
	muzzle = metadata.muzzle
	secondary_muzzle = metadata.secondary_muzzle
	action = metadata.action
	mesh_count = metadata.mesh_count
	source_meshes = metadata.source_meshes
	source_triangles = metadata.source_triangles
	materials = {}
	metadata["root"] = root
	metadata["actions"] = actions
	return metadata

func _make_materials() -> void:
	for entry: Array in [["steel", "343e48", .72, .43], ["edge", "78828a", .85, .24], ["black", "151b20", .65, .42], ["brass", "bc9250", .80, .30], ["silver", "929ea7", .75, .35], ["bore", "080b0d", .0, .97], ["ivory", "c9bf9b", .0, .72], ["string", "baa582", .0, .96], ["red", "783b25", .0, .84]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(str(entry[1]))
		material.metallic = float(entry[2])
		material.roughness = float(entry[3])
		materials[str(entry[0])] = material
	var wood := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_back; uniform vec4 wood_color: source_color = vec4(.30,.12,.05,1.); varying vec3 local_pos; void vertex(){local_pos=VERTEX;} void fragment(){float grain=sin(local_pos.z*95.+sin(local_pos.x*135.)*.8+sin(local_pos.y*80.)*1.6);float fine=sin(local_pos.z*430.+sin(local_pos.x*72.)*6.);float pores=pow(abs(sin(local_pos.z*251.+local_pos.x*83.)),18.);ALBEDO=wood_color.rgb*(.86+grain*.038+fine*.014-pores*.018);ROUGHNESS=.52+grain*.04;SPECULAR=.32;}"
	wood.shader = shader
	var colors := [Color("603e29"), Color("422b22"), Color("89572f"), Color("815933"), Color("4f2e23"), Color("713921"), Color("462b26"), Color("764029"), Color("4a2d24"), Color("492724"), Color("221e20"), Color("71422c"), Color("352723"), Color("644531"), Color("422d20"), Color("6c3c20"), Color("8c582e"), Color("6b3824")]
	wood.set_shader_parameter("wood_color", colors[mini(index,colors.size()-1)])
	materials.wood = wood
	for entry in [["leather","49372c"],["paper","a84731"],["horn","38312a"],["copper","b36b43"],["fuel","52615b"]]:
		var finish:=StandardMaterial3D.new(); finish.albedo_color=Color(entry[1]); finish.roughness=.72
		if entry[0]=="copper": finish.metallic=.72; finish.roughness=.38
		materials[entry[0]]=finish

func _node(name: String, point: Vector3 = Vector3.ZERO, parent: Node3D = null) -> Node3D:
	var node := Node3D.new()
	node.name = name
	node.position = point
	(parent if parent else root).add_child(node)
	actions[name] = node
	return node

func _mesh(parent: Node3D, geometry: Mesh, point: Vector3, material: String, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = geometry
	mesh.material_override = materials[material]
	mesh.position = point
	mesh.rotation = rotation
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	source_meshes += 1
	source_triangles += _triangles(geometry)
	return mesh

func _loft(parent: Node3D, sections: Array, material: String, point: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	# z, centre height, half width, half height; chamfered corners carry highlights.
	var ring := [Vector2(-.76,-1), Vector2(.76,-1), Vector2(1,-.76), Vector2(1,.76), Vector2(.76,1), Vector2(-.76,1), Vector2(-1,.76), Vector2(-1,-.76)]
	var vertices: Array[Vector3] = []
	for section: Vector4 in sections:
		for corner: Vector2 in ring:
			vertices.append(Vector3(corner.x * section.z, section.y + corner.y * section.w, section.x))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(sections.size() - 1):
		for side: int in 8:
			var a := row * 8 + side
			var b := row * 8 + (side + 1) % 8
			for vertex: int in [a,b,b+8,a,b+8,a+8]:
				surface.add_vertex(vertices[vertex])
	var last := (sections.size() - 1) * 8
	for side: int in range(1,7):
		for vertex: int in [0,side+1,side,last,last+side,last+side+1]:
			surface.add_vertex(vertices[vertex])
	surface.generate_normals()
	surface.index()
	return _mesh(parent, surface.commit(), point, material)

func _box(parent: Node3D, point: Vector3, size: Vector3, material: String, tilt: float = 0.0) -> MeshInstance3D:
	var mesh := _loft(parent, [Vector4(size.z*.5,0,size.x*.46,size.y*.46), Vector4(size.z*.5-.003,0,size.x*.5,size.y*.5), Vector4(-size.z*.5+.003,0,size.x*.5,size.y*.5), Vector4(-size.z*.5,0,size.x*.46,size.y*.46)], material, point)
	mesh.rotation.x = tilt
	return mesh

func _cylinder(parent: Node3D, point: Vector3, length: float, radius: float, material: String, axis: Vector3 = Vector3.FORWARD, sides: int = 32, end_radius: float = -1.0) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius if end_radius < 0 else end_radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = sides
	cylinder.rings = 1
	var node := _mesh(parent, cylinder, point, material)
	node.quaternion = Quaternion(Vector3.UP, axis.normalized())
	return node

func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: String, sides: int = 10) -> void:
	_cylinder(parent, (a+b)*.5, a.distance_to(b), radius, material, (b-a).normalized(), sides)

func _ring(parent: Node3D, point: Vector3, radius: float, thickness: float, material: String, axis: Vector3 = Vector3.FORWARD, scale_y: float = 1.0) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius-thickness
	torus.outer_radius = radius+thickness
	torus.rings = 32
	torus.ring_segments = 8
	var node := _mesh(parent, torus, point, material)
	node.quaternion = Quaternion(Vector3.UP, axis.normalized())
	node.scale.z = scale_y
	return node

func _barrel(parent: Node3D, start: float, end: float, y: float, radius: float, x: float = 0.0, sides: int = 40, material: String = "steel", flare: float = -1.0) -> void:
	var outer := radius if flare < 0 else flare
	# Open front and a short inner wall give the bore real depth. A capped
	# cylinder with a black disc behind its front face would hide the bore.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in sides:
		var a:=TAU*float(segment)/sides
		var b:=TAU*float(segment+1)/sides
		var radial_a:=Vector3(sin(a),cos(a),0)
		var radial_b:=Vector3(sin(b),cos(b),0)
		var back_a:=radial_a*radius+Vector3(0,0,start)
		var back_b:=radial_b*radius+Vector3(0,0,start)
		var front_a:=radial_a*outer+Vector3(0,0,end)
		var front_b:=radial_b*outer+Vector3(0,0,end)
		var inner_a:=radial_a*outer*.76+Vector3(0,0,end)
		var inner_b:=radial_b*outer*.76+Vector3(0,0,end)
		var deep_a:=inner_a+Vector3.BACK*.04
		var deep_b:=inner_b+Vector3.BACK*.04
		for v: Vector3 in [back_a,front_b,back_b,back_a,front_a,front_b,front_a,inner_b,front_b,front_a,inner_a,inner_b,inner_a,deep_b,inner_b,inner_a,deep_a,deep_b]: surface.add_vertex(v)
	surface.generate_normals()
	surface.index()
	_mesh(parent,surface.commit(),Vector3(x,y,0),material)
	_ring(parent, Vector3(x,y,end), outer*.88, outer*.12, "edge")
	_cylinder(parent, Vector3(x,y,end+.042), .004, outer*.75, "bore", Vector3.FORWARD, 40)
	_ring(parent, Vector3(x,y,start-.005), radius*1.03, .003, "edge")
	# The muzzle is hollow; the breech must not be a see-through pipe in first person.
	_cylinder(parent,Vector3(x,y,start+.002),.006,radius*.98,material,Vector3.FORWARD,sides)

func _screw(parent: Node3D, point: Vector3, radius: float = .006, axis: Vector3 = Vector3.RIGHT) -> void:
	_cylinder(parent, point, .0025, radius, "silver", axis, 20)
	var slot := _box(parent, point + axis*.0014, Vector3(.001,.0014,radius*1.35), "black")
	if axis != Vector3.RIGHT:
		slot.quaternion = Quaternion(Vector3.RIGHT, axis)

func _sights(parent: Node3D, end: float, y: float, rear: float = -.12) -> void:
	sight = Vector3(0,y+.035,rear)
	var ancestor := parent
	while ancestor!=root:
		sight = ancestor.transform*sight
		ancestor = ancestor.get_parent() as Node3D
	_box(parent, Vector3(0,y+.017,end+.05), Vector3(.015,.027,.023), "black")
	_box(parent, Vector3(0,y+.031,end+.05), Vector3(.006,.008,.017), "brass")
	_box(parent, Vector3(0,y+.017,rear), Vector3(.040,.012,.028), "steel")
	for x: float in [-.016,.016]:
		_box(parent, Vector3(x,y+.026,rear), Vector3(.008,.018,.013), "edge")

func _stock(end: float, full: bool = false) -> void:
	var sections := [Vector4(.35,-.063,.047,.102), Vector4(.32,-.061,.057,.107), Vector4(.22,-.041,.052,.092), Vector4(.11,-.013,.030,.044), Vector4(.015,.002,.033,.032), Vector4(-.15,.004,.039,.040)]
	if full:
		sections.append(Vector4(end*.65,.005,.028,.029))
		sections.append(Vector4(end+.08,.012,.023,.023))
	_loft(root, sections, "wood")
	_box(root, Vector3(0,-.062,.350), Vector3(.099,.207,.013), "brass" if index in [0,2,5,16] else "edge")
	for x: float in [-.056,.056]:
		_screw(root, Vector3(x,-.067,.26), .005, Vector3.RIGHT if x>0 else Vector3.LEFT)
	# Raised cheekpiece and a slender inlaid stock line follow the walnut contour.
	_box(root, Vector3(-.047,-.022,.245), Vector3(.013,.065,.155), "wood", .13)
	for x: float in [-.035,.035]:
		_rod(root, Vector3(x,-.016,.19), Vector3(x,.004,.045), .0016, "brass", 8)

func _grip(parent: Node3D, short: bool = false, material: String = "wood") -> void:
	# Rounded palm swell, flared heel and continuous backstrap, rather than a bent stick.
	var grip:=Node3D.new(); parent.add_child(grip); grip.name="SculptedGrip"
	if short: grip.scale=Vector3(.86,.78,.88)
	var contour: Array=[Vector4(.177,.064,.033,.028),Vector4(.166,.062,.039,.038),Vector4(.138,.052,.036,.044),Vector4(.094,.032,.032,.044),Vector4(.042,.013,.027,.037),Vector4(-.010,.0,.023,.030)]
	var strap:=_loft(grip,contour,"steel"); strap.rotation.x=PI/2
	var panel:=_loft(grip,contour,material); panel.rotation.x=PI/2; panel.scale=Vector3(1.055,.90,.94); panel.position.y=-.004
	for side: float in [-1.,1.]:
		_screw(grip,Vector3(side*.036,-.105,.035),.005,Vector3.RIGHT*side)
		for row in 9:
			var y: float=-.064-row*.008
			var z: float=.018+row*.004
			_rod(grip,Vector3(side*.035,y,z-.017),Vector3(side*.035,y-.008,z+.017),.00065,"black",5)
			_rod(grip,Vector3(side*.035,y,z+.017),Vector3(side*.035,y-.008,z-.017),.00065,"black",5)

func _oval(parent: Node3D,point: Vector3,radii: Vector3,material: String) -> MeshInstance3D:
	var sphere:=SphereMesh.new(); sphere.radius=1; sphere.height=2; sphere.radial_segments=24; sphere.rings=12
	var node:=_mesh(parent,sphere,point,material); node.scale=radii; return node

func _blade(parent: Node3D,outline: Array,thickness: float,material: String) -> void:
	# A forged blade with a central ridge and an actual thin cutting edge.
	var polygon:=PackedVector2Array(outline)
	var center:=Vector2.ZERO
	for p in polygon: center+=p
	center/=polygon.size()
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in polygon.size():
		var a: Vector2=polygon[i]; var b: Vector2=polygon[(i+1)%polygon.size()]
		for side in [-1.,1.]:
			var vertices: Array[Vector3]=[Vector3(side*thickness,center.y,center.x),Vector3(0,a.y,a.x),Vector3(0,b.y,b.x)]
			if side<0: vertices.reverse()
			for vertex in vertices: surface.add_vertex(vertex)
	surface.generate_normals(); surface.index()
	var finish: Material=materials[material].duplicate()
	finish.cull_mode=BaseMaterial3D.CULL_DISABLED
	var mesh:=_mesh(parent,surface.commit(),Vector3.ZERO,material); mesh.material_override=finish

func _guard(parent: Node3D, point: Vector3 = Vector3(0,-.054,-.060), width: float = .046, material: String = "brass", lever: bool = false) -> void:
	var last := Vector3.ZERO
	for i: int in 29:
		var angle := TAU * float(i)/28.
		var p := point + Vector3(0,sin(angle)*width*.7,cos(angle)*width*(1.65 if lever else 1.0))
		if i > 0:
			_rod(parent,last,p,.0045,material,8)
		last = p
	_rod(parent, Vector3(0,-.022,point.z-.005), Vector3(0,-.062,point.z+.012), .004,"black")

func _hammer(parent: Node3D, point: Vector3, flint: bool = false, name: String = "hammer") -> Node3D:
	var hammer := _node(name,point,parent)
	_cylinder(hammer,Vector3.ZERO,.016,.017,"steel",Vector3.RIGHT,24)
	_box(hammer,Vector3(0,.025,.004),Vector3(.014,.055,.019),"edge",-.35)
	_box(hammer,Vector3(0,.050,.014),Vector3(.028,.009,.037),"steel",-.3)
	for i: int in 4:
		_box(hammer,Vector3(0,.056,.005+float(i)*.007),Vector3(.029,.002,.002),"edge")
	if flint:
		_box(hammer,Vector3(0,.055,-.016),Vector3(.025,.017,.046),"steel")
		_box(hammer,Vector3(0,.050,-.044),Vector3(.021,.009,.029),"ivory")
	return hammer

func _engrave(parent: Node3D, x: float, y: float, z: float, span: float = .11) -> void:
	for branch: int in 2:
		var previous := Vector3.ZERO
		for step: int in 17:
			var t := float(step)/16.
			var angle := t * TAU * 1.25
			var point := Vector3(x,y+sin(angle)*.010*(1.-t),z+(t-.5)*span+float(branch)*.018)
			if step > 0:
				_rod(parent,previous,point,.0007,"silver",6)
			previous=point

func _flintlock() -> void:
	action = "muzzle"
	var pistol := index == 4
	var end := -.39 if pistol else (-.70 if index == 5 else -1.24)
	if pistol:
		_grip(root)
		_loft(root,[Vector4(.07,-.026,.033,.035),Vector4(-.07,.006,.037,.032),Vector4(end+.06,.020,.023,.021)],"wood")
	else:
		_stock(end,true)
	_barrel(root,-.025,end,.059,.030 if not pistol else .024,0,40,"brass" if index == 5 else "steel",.070 if index == 5 else -1.)
	_cylinder(root,Vector3(0,.059,-.10),.17,.034,"steel",Vector3.FORWARD,8)
	_box(root,Vector3(.040,.040,-.09),Vector3(.013,.066,.19),"silver")
	_engrave(root,.048,.040,-.09)
	for z: float in [-.15,-.035]: _screw(root,Vector3(.049,.042,z))
	_box(root,Vector3(.058,.071,-.16),Vector3(.031,.018,.046),"brass")
	var frizzen := _node("frizzen",Vector3(.057,.078,-.17))
	_box(frizzen,Vector3(0,.029,-.007),Vector3(.020,.064,.013),"steel",-.15)
	_hammer(root,Vector3(.052,.052,-.015),true)
	_guard(root,Vector3(0,-.046,-.034),.041)
	var bands := 1 if pistol else (2 if index==5 else 3)
	for n: int in bands:
		var z := lerpf(-.23,end+.12,float(n)/maxf(1,bands-1))
		_ring(root,Vector3(0,.026,z),.038,.004,"brass",Vector3.FORWARD,1.5)
		_screw(root,Vector3(.041,.025,z),.004)
	var rod := _node("ramrod",Vector3(0,-.019,end*.56))
	_cylinder(rod,Vector3.ZERO,absf(end)*.80,.0055,"edge")
	_cylinder(rod,Vector3(0,0,-absf(end)*.40),.025,.009,"brass")
	for z: float in [-.20,end+.13]:
		_ring(root,Vector3(0,-.019,z),.010,.003,"brass")
	var powder := _node("powder",Vector3(.035,.14,end))
	_cylinder(powder,Vector3.ZERO,.12,.033,"ivory",Vector3.UP,24,.013)
	_ring(powder,Vector3(0,.040,0),.021,.003,"brass",Vector3.UP)
	powder.visible=false
	_sights(root,end,.082)
	muzzle=Vector3(0,.059,end-.015)

func _coach_gun() -> void:
	action="break"
	_stock(-.67)
	_box(root,Vector3(0,.026,-.105),Vector3(.100,.096,.21),"silver")
	for side: float in [-1.,1.]:
		_engrave(root,side*.052,.025,-.10,.12)
		_hammer(root,Vector3(side*.054,.050,-.010),false,"hammer" if side>0 else "hammer_left")
		_screw(root,Vector3(side*.052,.023,-.14),.008,Vector3.RIGHT*side)
	var hinge := _node("break",Vector3(0,.018,-.19))
	for x: float in [-.034,.034]:
		_barrel(hinge,.025,-.54,.044,.032,x)
		_cylinder(hinge,Vector3(x,.044,.022),.01,.025,"brass")
	_box(hinge,Vector3(0,.078,-.26),Vector3(.014,.008,.51),"steel")
	_loft(hinge,[Vector4(-.06,-.012,.050,.029),Vector4(-.25,-.015,.042,.032),Vector4(-.39,-.006,.034,.023)],"wood")
	_sights(hinge,-.54,.077,-.02)
	_guard(root,Vector3(0,-.051,-.050),.053,"steel")
	var latch := _node("latch",Vector3(0,.080,-.055))
	_box(latch,Vector3(.018,0,.035),Vector3(.015,.009,.08),"edge")
	muzzle=Vector3(0,.062,-.745)

func _cylinder_drum(parent: Node3D, chambers: int, radius: float, length: float, flutes: bool = true) -> void:
	# True fluting in the outside profile, rather than a smooth placeholder drum.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := chambers*16
	for i: int in segments:
		var a := TAU*float(i)/segments
		var b := TAU*float(i+1)/segments
		var ra := radius*(1.-(.065*pow(maxf(0,cos(a*chambers)),3.) if flutes else 0.))
		var rb := radius*(1.-(.065*pow(maxf(0,cos(b*chambers)),3.) if flutes else 0.))
		var p := Vector3(sin(a)*ra,cos(a)*ra,0)
		var q := Vector3(sin(b)*rb,cos(b)*rb,0)
		for v: Vector3 in [p+Vector3.BACK*length*.5,q-Vector3.BACK*length*.5,q+Vector3.BACK*length*.5,p+Vector3.BACK*length*.5,p-Vector3.BACK*length*.5,q-Vector3.BACK*length*.5]: st.add_vertex(v)
	st.generate_normals()
	st.index()
	_mesh(parent,st.commit(),Vector3.ZERO,"steel")
	for z: float in [-length*.5,length*.5]:
		_cylinder(parent,Vector3(0,0,z),.003,radius*.95,"steel",Vector3.FORWARD,48)
	for chamber: int in chambers:
		var a := TAU*float(chamber)/chambers
		var p := Vector3(sin(a)*radius*.63,cos(a)*radius*.63,0)
		for z: float in [-length*.5-.002,length*.5+.002]:
			_cylinder(parent,p+Vector3(0,0,z),.002,radius*.215,"bore",Vector3.FORWARD,20)
			_ring(parent,p+Vector3(0,0,z),radius*.225,.0017,"edge")
		_box(parent,Vector3(sin(a)*radius,cos(a)*radius,length*.27),Vector3(.008,.004,.018),"black")

func _revolver() -> void:
	var capball := index in [7,8,9]
	action="capball" if capball else ("topbreak" if index==12 else "gate")
	var lemat := index==9
	var radius := .061 if lemat else .044
	var length := .31 if index==7 else (.27 if index==8 else (.29 if lemat else (.24 if index==11 else .26)))
	_grip(root,false,"ivory" if index==12 else "wood")
	_loft(root,[Vector4(.040,.004,.025,.043),Vector4(.006,-.006,.030,.038),Vector4(-.09,-.017,.028,.028),Vector4(-.14,.018,.029,.052)],"brass" if index==7 else "steel")
	var assembly: Node3D = root
	if index==12:
		assembly=_node("break",Vector3(0,-.020,-.085))
		assembly.position=Vector3.ZERO
	var cylinder := _node("cylinder",Vector3(0,.048,-.078),assembly)
	_cylinder_drum(cylinder,9 if lemat else 6,radius,.097 if lemat else .081,index not in [7,9])
	_cylinder(assembly,Vector3(0,.048,-.075),.129,.009,"edge")
	_cylinder(root,Vector3(0,.048,-.027),.012,radius*.94,"steel",Vector3.FORWARD,40)
	var y := .048+radius*.64
	_barrel(assembly,-.12,-length-.12,y,.020 if not lemat else .023,0,8 if index in [7,8] else 40)
	if index in [8,11,12]:
		_box(assembly,Vector3(0,.106,-.065),Vector3(.033,.017,.142),"steel")
	_box(assembly,Vector3(0,.044,-.139),Vector3(.052,.100,.037),"steel")
	_sights(assembly,-length-.12,y+.017,-.016)
	_hammer(root,Vector3(0,.070,.008))
	_guard(root,Vector3(0,-.040,-.052),.032,"brass" if index in [7,9,11] else "steel")
	for side: float in [-1.,1.]:
		_screw(root,Vector3(side*.028,.025,-.003),.007,Vector3.RIGHT*side)
		_screw(root,Vector3(side*.028,-.013,-.035),.005,Vector3.RIGHT*side)
		_engrave(root,side*.029,.008,-.023,.045)
	if capball:
		var rammer := _node("rammer",Vector3(0,.006,-.139))
		_cylinder(rammer,Vector3(0,0,-length*.35),length*.69,.008,"edge")
		_box(rammer,Vector3(0,0,-length*.67),Vector3(.024,.017,.04),"steel")
	else:
		var gate := _node("gate",Vector3(.030,.047,-.015))
		_box(gate,Vector3(0,0,-.018),Vector3(.012,.030,.039),"edge")
		var ejector := _node("ejector",Vector3(.023,y-.027,-.23))
		_cylinder(ejector,Vector3.ZERO,.17,.006,"edge")
		_cylinder(ejector,Vector3(0,0,.081),.008,.012,"black")
	if lemat:
		_barrel(assembly,-.02,-length-.08,.005,.027)
		secondary_muzzle=Vector3(0,.005,-length-.095)
		var selector:=_node("selector",Vector3(.014,.119,.008))
		_box(selector,Vector3.ZERO,Vector3(.013,.015,.022),"silver")
		var shotgun_rod:=_node("secondary_ramrod",Vector3(.032,-.025,-.22))
		_cylinder(shotgun_rod,Vector3.ZERO,.31,.0045,"edge")
		_cylinder(shotgun_rod,Vector3(0,0,.145),.015,.009,"brass")
		shotgun_rod.visible=false
	if index==12:
		_box(root,Vector3(0,.121,.007),Vector3(.067,.023,.036),"black")
	muzzle=Vector3(0,y,-length-.135)

func _pepperbox() -> void:
	action="pepperbox"
	_grip(root)
	_loft(root,[Vector4(.032,.014,.027,.042),Vector4(.006,.024,.034,.048),Vector4(-.058,.032,.035,.045),Vector4(-.094,.041,.028,.034)],"steel")
	for side: float in [-1.,1.]: _engrave(root,side*.036,.02,-.035,.075)
	var barrels := _node("cylinder",Vector3(0,.055,-.14))
	for chamber: int in 6:
		var a:=TAU*chamber/6.
		_barrel(barrels,.045,-.145,cos(a)*.032,.017,sin(a)*.032,32)
	_ring(barrels,Vector3(0,0,-.020),.048,.005,"steel")
	_cylinder(barrels,Vector3(0,0,-.053),.19,.009,"edge")
	_hammer(root,Vector3(0,.080,.003))
	_guard(root,Vector3(0,-.034,-.038),.034,"steel")
	for z: float in [-.060,.0]: _screw(root,Vector3(.037,.02,z))
	muzzle=Vector3(0,.087,-.295)
	_sights(root,-.295,.09,.0)

func _derringer() -> void:
	action="derringer"
	_grip(root,true,"black")
	_loft(root,[Vector4(.040,.008,.023,.035),Vector4(.013,.025,.028,.040),Vector4(-.045,.032,.025,.026),Vector4(-.065,.032,.020,.018)],"silver")
	var hinge := _node("break",Vector3(0,.065,-.033))
	for y: float in [-.009,.024]: _barrel(hinge,.025,-.119,y,.019,0,36,"silver")
	_box(hinge,Vector3(0,.037,-.06),Vector3(.014,.009,.115),"silver")
	_sights(hinge,-.119,.020,.033)
	_hammer(root,Vector3(0,.043,.025))
	_rod(root,Vector3(0,-.012,-.046),Vector3(0,-.037,-.039),.005,"black")
	_screw(root,Vector3(.026,.025,-.015),.008)
	_screw(root,Vector3(.023,.065,-.031),.006)
	_engrave(root,.026,.019,-.013,.04)
	muzzle=Vector3(0,.089,-.163)

func _rifle() -> void:
	var ends := {2:-.90,13:-1.08,14:-.94,15:-1.03,16:-.93,17:-.86}
	var end: float = float(ends[index])
	action="snider" if index==13 else ("falling" if index in [14,15] else "lever")
	_stock(end,index==13)
	var receiver_material := "brass" if index==2 else "steel"
	_box(root,Vector3(0,.030,-.095),Vector3(.076,.105,.244 if index!=17 else .27),receiver_material)
	var radius := .033 if index==17 else (.029 if index==15 else .023)
	_barrel(root,-.19,end,.073,radius,0,8 if index in [2,15] else 40)
	if index!=13:
		_loft(root,[Vector4(-.22,.005,.035,.035),Vector4(-.39,.004,.037,.039),Vector4(-.62,.014,.029,.028)],"wood")
	if index in [2,16,17]:
		_barrel(root,-.21,end+.05,.009,.018 if index!=17 else .025)
	for z: float in [-.35,end+.14]:
		_ring(root,Vector3(0,.039,z),.044,.0035,"steel",Vector3.FORWARD,1.34)
		_screw(root,Vector3(.046,.03,z),.004)
	for side: float in [-1.,1.]:
		_box(root,Vector3(side*.039,.033,-.085),Vector3(.005,.073,.166),receiver_material)
		for z: float in [-.145,-.050,.006]: _screw(root,Vector3(side*.043,.038,z),.0055,Vector3.RIGHT*side)
		_engrave(root,side*.043,.030,-.078,.12)
	_sights(root,end,.073+radius,-.29)
	var lever:=_node("lever",Vector3(0,-.005,-.045))
	_guard(lever,Vector3(0,-.058,.030),.047,"steel",true)
	_rod(lever,Vector3(0,-.004,-.002),Vector3(0,-.046,-.029),.006,"edge")
	if index in [2,13,15,16,17]: _hammer(root,Vector3(0,.072,.024))
	var breech:=_node("breech",Vector3(0,.081,-.123))
	if index==13:
		_cylinder(breech,Vector3.ZERO,.093,.033,"edge",Vector3.FORWARD,24)
		_box(breech,Vector3(.041,.006,-.003),Vector3(.043,.015,.022),"black")
		_cylinder(root,Vector3(.043,.071,-.121),.118,.009,"steel")
	elif index in [14,15]:
		_box(breech,Vector3(0,-.002,0),Vector3(.057,.062,.073),"black")
		if index==15:
			var sight:=_node("vernier",Vector3(0,.081,.06))
			for x: float in [-.009,.009]: _box(sight,Vector3(x,.066,0),Vector3(.005,.130,.008),"edge")
			_ring(sight,Vector3(0,.098,0),.011,.003,"black")
			for line: int in 8: _box(sight,Vector3(.015,.020+line*.012,0),Vector3(.009,.0015,.003),"silver")
			sight.rotation.x = PI/2 # Fold the unused tang sight clear of the barrel sights.
	else:
		_box(breech,Vector3(0,0,.014),Vector3(.049,.031,.09),"black")
		var gate:=_node("gate",Vector3(.044,.044,-.10))
		_box(gate,Vector3.ZERO,Vector3(.007,.022,.065),"black")
	if index==16:
		_cylinder(root,Vector3(0,-.06,.36),.012,.022,"steel")
		_ring(root,Vector3(.049,.041,.027),.025,.003,"edge",Vector3.RIGHT)
	if index==17:
		_cylinder(root,Vector3(0,.044,-.055),.068,.070,"steel",Vector3.RIGHT,40)
		for side: float in [-1.,1.]: _screw(root,Vector3(side*.040,.044,-.055),.010,Vector3.RIGHT*side)
	muzzle=Vector3(0,.073,end-.017)

func _crossbow() -> void:
	action="crossbow"
	_loft(root,[Vector4(.26,-.04,.035,.05),Vector4(.13,-.014,.034,.035),Vector4(-.13,.005,.039,.033),Vector4(-.56,.01,.034,.029),Vector4(-.66,.017,.044,.026)],"wood")
	for x: float in [-.021,.021]: _rod(root,Vector3(x,.051,.01),Vector3(x,.051,-.63),.0025,"brass")
	var limbs:=_node("limbs",Vector3(0,.03,-.62))
	for side: float in [-1.,1.]:
		var prior:=Vector3.ZERO
		for segment: int in 8:
			var t:=float(segment+1)/8.
			var point:=Vector3(side*t*.51,.012*sin(t*PI),t*t*.12)
			var limb:=_rod_limb(limbs,prior,point,.026*(1.-t*.58))
			limb.material_override=materials.steel
			prior=point
		_ring(limbs,prior,.012,.002,"string",Vector3.UP)
	var string_node:=_node("string")
	for side: float in [-1.,1.]:
		_rod(string_node,Vector3(side*.51,.042,-.50),Vector3(0,.059,-.095),.0024,"string",8)
	var bolt:=_node("bolt")
	_cylinder(bolt,Vector3(0,.060,-.35),.47,.004,"wood",Vector3.FORWARD,16)
	_cylinder(bolt,Vector3(0,.060,-.61),.065,.012,"edge",Vector3.FORWARD,4,0.)
	for angle: float in [0.,TAU/3.,TAU*2./3.]:
		var feather:=_box(bolt,Vector3(0,.061,-.144),Vector3(.002,.029,.072),"ivory")
		feather.rotation.z=angle
	var catch_node:=_node("hammer",Vector3(0,.045,-.072))
	_cylinder(catch_node,Vector3.ZERO,.055,.021,"ivory",Vector3.RIGHT,24)
	_guard(root,Vector3(0,-.037,-.058),.046,"steel")
	_rod(root,Vector3(0,-.032,.012),Vector3(0,-.075,.17),.010,"steel")
	_ring(root,Vector3(0,-.012,-.74),.075,.005,"steel",Vector3.RIGHT,1.5)
	for x: float in [-.043,.043]:
		_screw(root,Vector3(x,.027,-.60),.008,Vector3.RIGHT if x>0 else Vector3.LEFT)
		_screw(root,Vector3(x,.012,-.09),.006,Vector3.RIGHT if x>0 else Vector3.LEFT)
	var windlass:=_node("windlass",Vector3(0,.092,-.018))
	_cylinder(windlass,Vector3.ZERO,.20,.011,"steel",Vector3.RIGHT)
	for x: float in [-.10,.10]:
		_rod(windlass,Vector3(x,0,0),Vector3(x,.065,0),.006,"brass")
		_cylinder(windlass,Vector3(x,.065,.015),.06,.013,"wood")
	windlass.visible=false
	muzzle=Vector3(0,.06,-.67)

func _rod_limb(parent: Node3D,a: Vector3,b: Vector3,width: float) -> MeshInstance3D:
	var mesh:=_box(parent,(a+b)*.5,Vector3(width,.013,a.distance_to(b)+.006),"steel")
	mesh.quaternion=Quaternion(Vector3.FORWARD,(b-a).normalized())
	return mesh

func _merge_group(parent: Node3D) -> void:
	var groups: Dictionary={}
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			var mesh:=child as MeshInstance3D
			var mat: Material=mesh.material_override
			# Already-batched/cached models store colours on individual surfaces.
			# Merging these again under a null override erased the paired gun colours.
			if mat==null: continue
			if not groups.has(mat): groups[mat]=[]
			groups[mat].append(mesh)
		elif child is Node3D:
			_merge_group(child)
	for mat: Material in groups:
		var combined:=ArrayMesh.new()
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in groups[mat]:
			for i: int in part.mesh.get_surface_count(): surface.append_from(part.mesh,i,part.transform)
			parent.remove_child(part)
			part.free()
		surface.set_material(mat)
		surface.commit(combined)
		var result:=MeshInstance3D.new()
		result.name="BatchedDetail"
		result.mesh=combined
		result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(result)

func _count_meshes(parent: Node) -> int:
	var count:=int(parent is MeshInstance3D)
	for child: Node in parent.get_children(): count+=_count_meshes(child)
	return count

func _triangles(mesh: Mesh) -> int:
	var count:=0
	for surface: int in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		count+=(indices.size() if not indices.is_empty() else vertices.size())/3
	return count

func _count_triangles(parent: Node) -> int:
	var count:=_triangles((parent as MeshInstance3D).mesh) if parent is MeshInstance3D else 0
	for child: Node in parent.get_children(): count+=_count_triangles(child)
	return count

func _field_weapon() -> void:
	action="field"
	if index>=21:
		var bow:=_node("bow")
		var height: float=.59 if index==21 else .86 if index==22 else .68
		for side in [-1.,1.]:
			var last:=Vector3.ZERO
			for i in range(1,25):
				var t:=i/24.0
				var curve: float=-.21*sin(t*PI*.75)
				if index==23: curve+=.18*pow(t,5)
				var point:=Vector3(0,side*height*t,curve)
				var limb:=_cylinder(bow,(last+point)*.5,last.distance_to(point)+.002,lerpf(.025,.008,t),"horn" if index==23 else "wood",point-last,8)
				limb.scale.x=.52
				if index==23:
					_rod(bow,last+Vector3(.002,0,.009),point+Vector3(.002,0,.009),lerpf(.007,.002,t),"wood",6)
				last=point
			_rod(bow,last,Vector3(0,0,.19),.0014,"string",8)
			_cylinder(bow,last,.035,.009,"horn",Vector3.UP,10)
		_oval(bow,Vector3.ZERO,Vector3(.025,.08,.03),"leather")
		for i in 11: _ring(bow,Vector3(0,(i-5)*.012,0),.026,.0018,"string",Vector3.UP)
		var arrow:=_node("arrow")
		_rod(arrow,Vector3(0,0,.19),Vector3(0,0,-.65),.0035,"wood",12)
		_cylinder(arrow,Vector3(0,0,-.66),.055,.012,"edge",Vector3.FORWARD,4,0)
		for turn in 3:
			var feather:=_box(arrow,Vector3(0,.012,.11),Vector3(.002,.025,.07),"ivory")
			feather.position=feather.position.rotated(Vector3.FORWARD,turn*TAU/3); feather.rotation.z=turn*TAU/3
		_rod(bow,Vector3(0,.075,-.18),Vector3(.13,.075,-.18),.002,"brass",8)
		_cylinder(bow,Vector3(.13,.075,-.18),.004,.0025,"ivory",Vector3.FORWARD,10,0)
		sight=Vector3(.13,.075,-.18); muzzle=Vector3(0,0,-.687)
	elif index==20:
		_rod(root,Vector3(0,-.03,.45),Vector3(0,0,-1.0),.014,"wood",16)
		_cylinder(root,Vector3(0,0,-1.015),.15,.018,"steel")
		_blade(root,[Vector2(-1.03,0),Vector2(-1.10,.034),Vector2(-1.24,0),Vector2(-1.10,-.034)],.009,"edge")
		for i in 12: _ring(root,Vector3(0,0,-.91-i*.009),.015,.0017,"string")
		_cylinder(root,Vector3(0,-.03,.45),.04,.016,"steel")
		muzzle=Vector3(0,0,-1.24)
	elif index==19:
		_loft(root,[Vector4(.14,-.17,.021,.022),Vector4(.10,-.11,.018,.025),Vector4(-.10,.04,.017,.024),Vector4(-.27,.19,.018,.030)],"wood")
		_cylinder(root,Vector3(0,.205,-.255),.07,.036,"steel",Vector3.UP,12)
		_blade(root,[Vector2(-.22,.235),Vector2(-.34,.285),Vector2(-.40,.275),Vector2(-.405,.155),Vector2(-.36,.13),Vector2(-.26,.17)],.025,"steel")
		_blade(root,[Vector2(-.36,.279),Vector2(-.40,.275),Vector2(-.405,.155),Vector2(-.36,.13)],.008,"edge")
		_box(root,Vector3(0,.202,-.205),Vector3(.05,.058,.050),"steel")
		for i in 6: _ring(root,Vector3(0,-.09+i*.012,.08-i*.014),.022,.002,"leather",Vector3(0,1,-1))
		muzzle=Vector3(0,.2,-.405)
	else:
		_loft(root,[Vector4(.09,0,.019,.020),Vector4(.07,0,.024,.023),Vector4(-.04,0,.022,.020),Vector4(-.06,0,.018,.016)],"wood")
		_box(root,Vector3(0,0,-.058),Vector3(.058,.018,.012),"steel")
		_blade(root,[Vector2(-.061,.018),Vector2(-.22,.018),Vector2(-.30,0),Vector2(-.22,-.018),Vector2(-.061,-.018)],.006,"edge")
		for z in [.05,-.02]:
			for side in [-1.,1.]: _screw(root,Vector3(side*.023,0,z),.004,Vector3.RIGHT*side)
		_ring(root,Vector3(0,0,.094),.009,.002,"steel")
		muzzle=Vector3(0,0,-.30)

func _experimental() -> void:
	if index==26:
		_flintlock()
		action="crank"
		_box(root,Vector3(0,.069,-.39),Vector3(.097,.045,.34),"steel")
		for coil in 22: _ring(root,Vector3(0,.07,-.29-coil*.009),.045,.0025,"copper")
		for z in [-.22,-.56]:
			_ring(root,Vector3(0,.07,z),.049,.005,"brass")
		for x in [-.063,.063]:
			_cylinder(root,Vector3(x,.055,-.36),.23,.017,"black")
			for z in [-.245,-.475]: _cylinder(root,Vector3(x,.055,z),.018,.018,"brass")
		for z in [-.25,-.35,-.45,-.55]: _ring(root,Vector3(0,.07,z),.052,.009,"brass",Vector3.FORWARD)
		for x in [-.06,.06]: _cylinder(root,Vector3(x,.06,-.36),.32,.019,"silver",Vector3.FORWARD)
		var crank := _node("crank",Vector3(.10,.04,-.12))
		_rod(crank,Vector3.ZERO,Vector3(0,.07,0),.009,"brass")
		_cylinder(crank,Vector3(.025,.07,0),.05,.016,"wood",Vector3.RIGHT)
	else:
		action="throw"
		if index==24:
			_oval(root,Vector3(0,0,-.10),Vector3(.061,.073,.061),"steel")
			_cylinder(root,Vector3(0,.068,-.10),.025,.023,"brass",Vector3.UP,12)
			_ring(root,Vector3(0,.079,-.10),.022,.003,"edge",Vector3.UP)
			for y in [-.034,0.,.034]: _ring(root,Vector3(0,y,-.10),.060*sqrt(1-pow(y/.078,2)),.002,"black",Vector3.UP)
			_rod(root,Vector3(0,.083,-.10),Vector3(.01,.115,-.10),.003,"string")
			_rod(root,Vector3(.01,.115,-.10),Vector3(.034,.128,-.085),.003,"string")
		else:
			for x in [-.034,0.,.034]:
				_cylinder(root,Vector3(x,0,-.10),.20,.019,"paper",Vector3.UP,20)
				for y in [-.099,.099]: _cylinder(root,Vector3(x,y,-.10),.003,.018,"ivory",Vector3.UP,20)
			for y in [-.053,.053]:
				_box(root,Vector3(0,y,-.10),Vector3(.11,.014,.044),"leather")
				_box(root,Vector3(0,y,-.125),Vector3(.022,.020,.003),"brass")
			_box(root,Vector3(0,0,-.120),Vector3(.073,.055,.002),"ivory")
			for y in [-.014,-.005,.004,.013]: _box(root,Vector3(0,y,-.122),Vector3(.049,.002,.001),"red")
			_rod(root,Vector3(0,.1,-.1),Vector3(.02,.13,-.1),.003,"string")
			_rod(root,Vector3(.02,.13,-.1),Vector3(.035,.14,-.07),.003,"string")
		muzzle=Vector3(0,.05,-.1)

func _lancaster() -> void:
	action="break"
	_grip(root)
	_loft(root,[Vector4(.039,.015,.029,.039),Vector4(.012,.035,.036,.049),Vector4(-.07,.044,.040,.052),Vector4(-.115,.044,.037,.048)],"steel")
	var hinge:=_node("break",Vector3(0,.015,-.11))
	for x: float in [-.025,.025]:
		for y: float in [.025,.075]:
			_barrel(hinge,.02,-.30,y,.024,x,40,"steel")
	_box(hinge,Vector3(0,.099,-.14),Vector3(.018,.008,.31),"edge")
	var latch:=_node("latch",Vector3(.04,.08,-.07))
	_box(latch,Vector3.ZERO,Vector3(.013,.025,.07),"edge")
	_guard(root,Vector3(0,-.035,-.055),.042,"steel")
	for side: float in [-1.,1.]:
		_engrave(root,side*.037,.025,-.035,.085)
		_screw(root,Vector3(side*.038,.027,-.060),.007,Vector3.RIGHT*side)
	_sights(hinge,-.30,.09,.05)
	muzzle=Vector3(.025,.09,-.42)

func _mauser_revolver() -> void:
	_revolver()
	# Raised groove lips catch the light on the C78's unfluted zig-zag cylinder.
	var cylinder: Node3D=actions.cylinder
	for i in 6:
		var angle:=i*TAU/6.
		var a:=Vector3(sin(angle)*.045,cos(angle)*.045,-.048)
		var b:=Vector3(sin(angle+.48)*.045,cos(angle+.48)*.045,.046)
		_rod(cylinder,a,b,.0016,"edge",6)
		_rod(cylinder,b,Vector3(sin(angle+TAU/6)*.045,cos(angle+TAU/6)*.045,-.048),.0016,"black",6)
	_box(root,Vector3(0,.115,-.12),Vector3(.035,.013,.20),"steel")

func _mauser_rifle() -> void:
	action="bolt"
	_stock(-1.12,true)
	_barrel(root,-.21,-1.22,.073,.024)
	_cylinder(root,Vector3(0,.07,-.1),.28,.032,"steel")
	var bolt:=_node("bolt",Vector3(0,.075,-.055))
	_cylinder(bolt,Vector3.ZERO,.20,.022,"silver")
	_rod(bolt,Vector3(0,0,.025),Vector3(.09,-.008,.025),.009,"steel")
	_cylinder(bolt,Vector3(.096,-.008,.025),.026,.018,"edge",Vector3.RIGHT)
	_box(bolt,Vector3(0,.035,.085),Vector3(.009,.046,.04),"black")
	_guard(root,Vector3(0,-.045,-.04),.044,"steel")
	for z: float in [-.40,-.80,-1.06]:
		_ring(root,Vector3(0,.03,z),.042,.004,"steel",Vector3.FORWARD,1.4)
		_screw(root,Vector3(.045,.03,z),.005)
	_cylinder(root,Vector3(0,-.013,-.66),.92,.004,"edge")
	_sights(root,-1.22,.097,-.29)
	for i in 6: _box(root,Vector3(.017,.12,-.29-i*.009),Vector3(.008,.0015,.002),"silver")
	muzzle=Vector3(0,.073,-1.24)

func _naval_pair() -> void:
	action="naval"
	var gold:=StandardMaterial3D.new()
	gold.albedo_color=Color("eac166"); gold.metallic=.86; gold.roughness=.23
	materials.gold=gold
	for side in 2:
		var gun:=_node("naval_right" if side==0 else "naval_left",Vector3(.16 if side==0 else -.24,0,0))
		_grip(gun,false,"ivory")
		_loft(gun,[Vector4(.055,.0,.034,.030),Vector4(-.14,.02,.031,.026),Vector4(-.39,.026,.023,.023)],"wood")
		_barrel(gun,-.015,-.45,.064,.029,0,48,"gold")
		_box(gun,Vector3(.037,.043,-.085),Vector3(.009,.059,.14),"gold")
		_engrave(gun,.043,.043,-.084,.11)
		_hammer(gun,Vector3(.035,.07,.004),false,"naval_hammer_%d"%side)
		_guard(gun,Vector3(0,-.044,-.028),.042,"gold")
		for z: float in [-.11,-.31]: _ring(gun,Vector3(0,.025,z),.037,.003,"gold",Vector3.FORWARD,1.4)
		for z: float in [-.02,-.13]: _screw(gun,Vector3(.043,.035,z),.004)
		_cylinder(gun,Vector3(0,-.015,-.23),.35,.004,"silver")
		_ring(gun,Vector3(0,-.17,.075),.015,.003,"gold",Vector3.RIGHT)
		_sights(gun,-.45,.092,-.075)
	muzzle=Vector3(.16,.064,-.465); secondary_muzzle=Vector3(-.24,.064,-.465)
	sight=Vector3(.16,.127,-.075)

func _paired_period() -> void:
	action="naval"
	for hand in 2:
		var holder:=_node("naval_right" if hand==0 else "naval_left",Vector3(.16 if hand==0 else -.24,0,0))
		var tip: Vector3
		if index==31:
			# Purpose-built pistols: shoulder stocks do not belong on dual-wielded guns.
			_grip(holder)
			_loft(holder,[Vector4(.04,.006,.03,.034),Vector4(-.14,.023,.034,.027),Vector4(-.29,.025,.024,.023)],"wood")
			_barrel(holder,-.025,-.34,.066,.025,0,40,"brass",.056)
			_ring(holder,Vector3(0,.066,-.335),.055,.003,"brass")
			_box(holder,Vector3(.032,.04,-.075),Vector3(.01,.05,.11),"steel")
			_engrave(holder,.039,.04,-.075,.085)
			_hammer(holder,Vector3(.032,.063,.012),true,"naval_hammer_%d"%hand)
			_guard(holder,Vector3(0,-.043,-.027),.034,"brass")
			_cylinder(holder,Vector3(0,-.009,-.15),.29,.004,"steel")
			_sights(holder,-.34,.121,-.08)
			tip=holder.position+Vector3(0,.066,-.35)
			if hand==0: sight=holder.position+Vector3(0,.156,-.08)
		else:
			var data: Dictionary=(get_script().new()).build(11)
			var gun: Node3D=data.root; holder.add_child(gun)
			tip=holder.position+data.muzzle
			if hand==0: sight=holder.position+data.sight
			source_meshes+=int(data.source_meshes); source_triangles+=int(data.source_triangles)
		if hand==0: muzzle=tip
		else: secondary_muzzle=tip

	if index==31: sight=Vector3(.16,.156,-.08)

func _luger() -> void:
	action="toggle"
	_grip(root,false,"wood")
	_loft(root,[Vector4(.035,.015,.025,.035),Vector4(-.02,.028,.029,.031),Vector4(-.115,.043,.027,.029),Vector4(-.18,.059,.021,.022)],"steel")
	for side in [-1.,1.]:
		_rod(root,Vector3(side*.029,.075,.019),Vector3(side*.029,.075,-.115),.004,"edge")
		_screw(root,Vector3(side*.03,.018,-.015),.004,Vector3.RIGHT*side)
	_barrel(root,-.10,-.40,.078,.018,0,40)
	_cylinder(root,Vector3(0,.076,-.095),.075,.028,"steel")
	var toggle:=_node("toggle",Vector3(0,.095,-.04))
	_box(toggle,Vector3(0,0,-.025),Vector3(.035,.015,.09),"edge")
	for x in [-.037,.037]:
		_cylinder(toggle,Vector3(x,.007,.005),.016,.022,"steel",Vector3.RIGHT)
		for line in 10: _rod(toggle,Vector3(x-.008,.012,-.01+line*.003),Vector3(x+.008,.012,-.01+line*.003),.001,"edge",6)
	_guard(root,Vector3(0,-.045,-.055),.035,"steel")
	var drum:=_node("drum",Vector3(0,-.215,.02))
	_cylinder(drum,Vector3.ZERO,.065,.105,"steel",Vector3.RIGHT,48)
	for side in [-1.,1.]:
		_ring(drum,Vector3(side*.034,0,0),.092,.003,"edge",Vector3.RIGHT)
		_cylinder(drum,Vector3(side*.038,0,0),.004,.024,"black",Vector3.RIGHT)
		_rod(drum,Vector3(side*.041,0,0),Vector3(side*.041,-.055,-.035),.005,"steel")
	_loft(root,[Vector4(.05,-.15,.018,.050),Vector4(.025,-.145,.018,.047),Vector4(.0,-.11,.018,.027)],"black")
	_sights(root,-.4,.096,-.14); muzzle=Vector3(0,.078,-.415)

func _hand_mortar() -> void:
	action="break"
	_stock(-.42)
	_box(root,Vector3(0,.026,-.07),Vector3(.09,.09,.17),"steel")
	var breech:=_node("break",Vector3(0,.03,-.15))
	_barrel(breech,.03,-.40,.05,.076,0,48,"brass")
	for z in [-.04,-.29]: _ring(breech,Vector3(0,.05,z),.079,.007,"steel")
	_guard(root,Vector3(0,-.045,-.035),.043,"steel")
	_hammer(root,Vector3(.05,.053,.02))
	_sights(breech,-.40,.14,.01)
	for i in 4: _box(breech,Vector3(.027,.10+i*.017,.01),Vector3(.04,.003,.006),"silver")
	muzzle=Vector3(0,.08,-.57)

func _fire_siphon() -> void:
	action="siphon"
	_stock(-.40)
	_loft(root,[Vector4(.015,.025,.039,.034),Vector4(-.20,.035,.045,.040),Vector4(-.35,.05,.036,.029)],"steel")
	_barrel(root,-.18,-.65,.08,.027,0,32,"brass")
	for z in [-.24,-.32,-.40,-.48,-.56]: _ring(root,Vector3(0,.08,z),.032,.004,"steel")
	# One connected reservoir, with domed ends, retaining straps and a pressure pump.
	_cylinder(root,Vector3(0,-.105,-.28),.35,.063,"fuel",Vector3.FORWARD,32)
	for z in [-.105,-.455]: _oval(root,Vector3(0,-.105,z),Vector3(.063,.063,.025),"brass")
	for z in [-.16,-.40]:
		_ring(root,Vector3(0,-.105,z),.066,.005,"steel")
		_box(root,Vector3(0,-.038,z),Vector3(.035,.060,.023),"steel")
	_cylinder(root,Vector3(.09,.025,-.14),.20,.020,"brass",Vector3.FORWARD)
	var pump:=_node("pump",Vector3(.09,.025,-.035))
	_cylinder(pump,Vector3(0,0,.02),.08,.006,"edge")
	_cylinder(pump,Vector3(0,0,.066),.07,.014,"wood",Vector3.RIGHT)
	var valve:=_node("valve",Vector3(-.055,.016,-.30))
	_ring(valve,Vector3.ZERO,.028,.004,"red",Vector3.RIGHT)
	for i in 4: _rod(valve,Vector3.ZERO,Vector3(0,sin(i*TAU/4),cos(i*TAU/4))*.028,.003,"brass")
	var hose: Array[Vector3]=[Vector3(.045,-.13,-.12),Vector3(.08,-.12,-.16),Vector3(.085,-.045,-.24),Vector3(.07,.005,-.41),Vector3(.025,.06,-.50)]
	for i in range(1,hose.size()): _rod(root,hose[i-1],hose[i],.008,"black",12)
	_cylinder(root,Vector3(.075,.115,-.20),.021,.030,"brass",Vector3.UP)
	_cylinder(root,Vector3(.075,.128,-.20),.003,.025,"ivory",Vector3.UP)
	for i in 9:
		var angle:=i*PI/6
		_rod(root,Vector3(.075+cos(angle)*.02,.131,-.20+sin(angle)*.02),Vector3(.075+cos(angle)*.024,.131,-.20+sin(angle)*.024),.0008,"black",5)
	_rod(root,Vector3(.075,.133,-.20),Vector3(.060,.133,-.213),.0015,"red")
	_guard(root,Vector3(0,-.052,-.025),.033,"steel")
	_rod(root,Vector3(.027,.035,-.50),Vector3(.027,.035,-.675),.005,"copper")
	_ring(root,Vector3(0,.08,-.625),.031,.004,"copper")
	_sights(root,-.60,.11,-.10)
	muzzle=Vector3(0,.08,-.67)
