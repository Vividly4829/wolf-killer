extends Node3D
## Original frontier ranger silhouettes: leather dusters, worn armor and field gear.
var beast:=false
var costume:="ranger"
var coat_color:=Color("52645a")
var joints: Dictionary={}
var materials: Dictionary={}
var motion:=0.0
var crouched:=false
var aiming:=false
var attacking:=false
var phase:=0.0
var torso: Node3D
func mat(key: String,color: Color) -> StandardMaterial3D:
	if materials.has(key): return materials[key]
	var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=.94
	if key=="eyes": m.emission_enabled=true; m.emission=color; m.emission_energy_multiplier=2.3
	materials[key]=m; return m
func oval(parent: Node3D,p: Vector3,r: Vector3,m: Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var mesh:=SphereMesh.new()
	mesh.radius=1; mesh.height=2; mesh.radial_segments=18; mesh.rings=9
	n.mesh=mesh; n.position=p; n.scale=r; n.material_override=m; parent.add_child(n); return n
func segment(parent: Node3D,a: Vector3,b: Vector3,r1: float,r2: float,m: Material) -> void:
	var n:=MeshInstance3D.new(); var mesh:=CylinderMesh.new()
	mesh.top_radius=r1; mesh.bottom_radius=r2; mesh.height=a.distance_to(b); mesh.radial_segments=8
	n.mesh=mesh; n.position=(a+b)*.5; n.quaternion=Quaternion(Vector3.UP,(a-b).normalized()); n.material_override=m; parent.add_child(n)
func joint(parent: Node3D,id: String,p: Vector3) -> Node3D:
	var n:=Node3D.new(); n.name=id; n.position=p; parent.add_child(n); joints[id]=n; return n
func _ready() -> void:
	var wool:=mat("coat",Color("342e36") if beast else coat_color)
	var shadow:=mat("shadow",Color("211e26") if beast else coat_color.darkened(.25))
	var leather:=mat("leather",Color("352c26")); var skin:=mat("skin",Color("4b454e") if beast else (Color("bc2425") if costume=="devil" else Color("b28d72")))
	var trim:=mat("trim",Color("716564") if beast else Color("afa18a")); var dark:=mat("dark",Color("191c20"))
	torso=joint(self,"torso",Vector3(0,.84,0))
	oval(torso,Vector3(0,.36,0),Vector3(.30 if beast else .255,.34,.18),wool)
	segment(torso,Vector3(0,.35,0),Vector3(0,.02,0),.22,.26,shadow)
	var head:=joint(torso,"head",Vector3(0,.77,-.025))
	oval(head,Vector3.ZERO,Vector3(.135,.175,.13),skin)
	oval(head,Vector3(0,-.065,-.105),Vector3(.10,.085,.07),shadow if beast else skin)
	oval(head,Vector3(0,.005,-.14),Vector3(.033,.05,.055),dark if beast else skin)
	for side in [-1,1]:
		var eye:=mat("eyes",Color("f36a35")) if beast else dark
		oval(head,Vector3(side*.060,.037,-.116),Vector3(.025,.014,.016),eye)
		segment(head,Vector3(side*.035,.070,-.115),Vector3(side*.09,.06,-.10),.016,.011,shadow)
		if beast:
			segment(head,Vector3(side*.105,.30,.015),Vector3(side*.10,.10,0),0,.07,wool)
			for tooth in 3: segment(head,Vector3(side*(.025+tooth*.021),-.105,-.23),Vector3(side*(.025+tooth*.021),-.058,-.21),0,.012,trim)
		else: oval(head,Vector3(side*.133,-.005,0),Vector3(.028,.05,.035),skin)
	if beast:
		head.scale=Vector3(1.35,1.15,1.35)
		oval(torso,Vector3(0,.49,.08),Vector3(.38,.28,.25),wool)
		oval(torso,Vector3(0,.34,-.15),Vector3(.23,.25,.08),shadow)
		oval(head,Vector3(0,-.032,-.18),Vector3(.085,.065,.14),shadow)
		oval(head,Vector3(0,-.005,-.285),Vector3(.060,.035,.025),dark)
		for side in [-1,1]:
			for tuft in 7:
				segment(torso,Vector3(side*(.38+tuft*.018),.69-tuft*.085,.10),Vector3(side*.20,.49-tuft*.035,0),0,.085,wool)
			for tuft in 4:
				segment(head,Vector3(side*(.16+tuft*.016),-.04-tuft*.035,.01),Vector3(side*.10,.04,-.03),0,.045,wool)
	elif costume=="ranger":
		oval(head,Vector3(0,-.08,-.085),Vector3(.10,.071,.075),leather)
		oval(head,Vector3(0,.12,.012),Vector3(.151,.085,.143),shadow)
		oval(head,Vector3(0,.083,-.035),Vector3(.157,.025,.164),wool)
		oval(torso,Vector3(0,.655,0),Vector3(.15,.075,.16),trim)
		segment(torso,Vector3(.11,.60,-.17),Vector3(.10,.34,-.19),.042,.04,trim)
		oval(torso,Vector3(0,.27,.18),Vector3(.19,.23,.09),leather)
		for side in [-1,1]:
			segment(torso,Vector3(side*.15,.61,-.12),Vector3(side*.17,.12,-.18),.017,.02,leather)
			oval(torso,Vector3(side*.12,.16,-.16),Vector3(.075,.07,.026),shadow)
		for button in 5: oval(torso,Vector3(.005,.50-button*.07,-.182),Vector3(.011,.012,.005),trim)
	for side in [-1,1]:
		var suffix:="L" if side<0 else "R"
		var leg:=joint(torso,"hip"+suffix,Vector3(side*.13,.015,0))
		segment(leg,Vector3.ZERO,Vector3(0,-.39,.015),.14 if beast else .115,.083,shadow)
		var knee:=joint(leg,"knee"+suffix,Vector3(0,-.39,.015))
		segment(knee,Vector3.ZERO,Vector3(0,-.35,0),.082,.065,shadow)
		oval(knee,Vector3(0,-.35,-.055),Vector3(.12,.085,.20) if beast else Vector3(.105,.09,.18),wool if beast else leather)
		if beast:
			for toe in 3:
				segment(knee,Vector3((toe-1)*.068,-.38,-.30),Vector3((toe-1)*.068,-.33,-.14),0,.022,trim)
			for tuft in 3: segment(knee,Vector3(side*(.09+tuft*.022),-.10-tuft*.055,.05),Vector3(0,-.05,0),0,.065,wool)
		var arm:=joint(torso,"shoulder"+suffix,Vector3(side*(.31 if beast else .265),.57,0))
		oval(arm,Vector3.ZERO,Vector3(.15,.16,.16) if beast else Vector3(.105,.115,.11),wool)
		segment(arm,Vector3.ZERO,Vector3(side*.035,-.31,0),.10,.075,wool)
		var elbow:=joint(arm,"elbow"+suffix,Vector3(side*.035,-.31,0))
		segment(elbow,Vector3.ZERO,Vector3(0,-.29,0),.078,.052,wool)
		oval(elbow,Vector3(0,-.32,-.018),Vector3(.067,.08,.045),skin if beast else leather)
		if beast:
			for finger in 4: segment(elbow,Vector3((finger-1.5)*.026,-.37,-.045),Vector3((finger-1.5)*.026,-.49,-.11),.010,0,trim)
			for tuft in 3: segment(elbow,Vector3(side*.14,-.10-tuft*.08,.04),Vector3(0,-.04-tuft*.06,0),0,.055,wool)
	if not beast and costume=="ranger": ranger_details(head,leather,dark,trim)
	# Batch static detail within each joint; retain the articulated transforms.
	preload("res://scripts/weapon_model_builder.gd").new()._merge_group(self)
func set_motion(speed: float,crouch: bool=false,aim: bool=false,attack: bool=false) -> void:
	motion=speed; crouched=crouch; aiming=aim; attacking=attack
func _process(delta: float) -> void:
	if not is_instance_valid(torso): return
	phase+=delta*(3+minf(motion,10)*2.2)
	var activity:=clampf(motion/3,0,1)
	torso.position.y=lerpf(torso.position.y,(.65 if crouched else .84)+absf(sin(phase))*activity*.035,1-exp(-delta*12))
	torso.rotation.x=(.16+.15*activity if beast else .08*activity)+(.25 if crouched else 0)
	joints.head.rotation.y=sin(phase*.22)*.045*(1-activity)
	if not beast and costume=="ranger":
		for side in [-1,1]: joints["coat_tail_%d"%side].rotation.x=sin(phase+side)*activity*.16
	for side in [-1,1]:
		var suffix:="L" if side<0 else "R"
		var swing:=sin(phase+(0 if side<0 else PI))*activity
		joints["hip"+suffix].rotation.x=swing*.62-(.25 if crouched else 0)
		joints["knee"+suffix].rotation.x=maxf(0,-swing)*.85+(.50 if crouched else (.18 if beast else 0))
		joints["shoulder"+suffix].rotation.x=-swing*.45 if not aiming else (.95 if side<0 else .70)
		joints["elbow"+suffix].rotation.x=.18 if not aiming else (.45 if side<0 else .70)
		if attacking:
			joints["shoulder"+suffix].rotation.x=1.4+sin(phase*1.8+side)*.65
			joints["elbow"+suffix].rotation.x=.45

func panel(parent: Node3D,p: Vector3,dimensions: Vector3,material: Material) -> void:
	var mesh:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=dimensions
	mesh.mesh=box; mesh.position=p; mesh.material_override=material; parent.add_child(mesh)
func ranger_details(head: Node3D,leather: Material,dark: Material,trim: Material) -> void:
	var duster:=mat("duster",coat_color.lerp(Color("725740"),.65))
	var armor:=mat("armor",Color("54554d"))
	var lens:=mat("goggle",Color("af8d50"))
	oval(head,Vector3(0,.12,.005),Vector3(.245,.014,.215),leather)
	oval(head,Vector3(0,.18,.018),Vector3(.14,.085,.133),duster)
	oval(head,Vector3(0,-.06,-.123),Vector3(.095,.070,.052),duster)
	for side in [-1,1]:
		oval(head,Vector3(side*.063,.036,-.142),Vector3(.049,.033,.022),dark)
		oval(head,Vector3(side*.063,.036,-.160),Vector3(.037,.025,.009),lens)
		var tail:=joint(torso,"coat_tail_%d"%side,Vector3(side*.17,.03,.055))
		panel(tail,Vector3(0,-.21,.07),Vector3(.22,.45,.042),duster)
		panel(torso,Vector3(side*.16,.40,-.17),Vector3(.125,.22,.044),armor)
		panel(torso,Vector3(side*.18,.12,-.19),Vector3(.105,.11,.065),leather)
		panel(joints["kneeL" if side<0 else "kneeR"],Vector3(0,-.055,-.079),Vector3(.115,.14,.036),armor)
		panel(joints["shoulderL" if side<0 else "shoulderR"],Vector3(side*.03,.015,-.02),Vector3(.16,.085,.20),leather)
	for i in 8: segment(torso,Vector3(-.17+i*.047,.02,-.22),Vector3(-.17+i*.047,.08,-.22),.009,.009,trim)
	panel(torso,Vector3(0,.035,-.225),Vector3(.065,.055,.014),armor)
	panel(torso,Vector3(.27,-.10,.015),Vector3(.065,.24,.11),leather)
