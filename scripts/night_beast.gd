extends Node3D
## Original quadruped: heavy forequarters, articulated hocks, jaw and mane.
var joints: Dictionary={}
var knees: Array[Node3D]=[]
var phase:=0.0
var travel:=0.0
var attacking:=false
var head: Node3D
var jaw: Node3D
var tail: Node3D
var materials: Dictionary={}
func part(parent: Node3D,p: Vector3,r: Vector3,color: String,pointed: bool=false) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	if pointed:
		var cone:=CylinderMesh.new(); cone.top_radius=0; cone.bottom_radius=1; cone.height=2; cone.radial_segments=7; node.mesh=cone
	else:
		var sphere:=SphereMesh.new(); sphere.radius=1; sphere.height=2; sphere.radial_segments=14; sphere.rings=8; node.mesh=sphere
	node.position=p; node.scale=r
	if not materials.has(color):
		var mat:=StandardMaterial3D.new(); mat.albedo_color=Color(color); mat.roughness=.92
		if color=="ff244a": mat.emission_enabled=true; mat.emission=Color(color); mat.emission_energy_multiplier=2.5
		materials[color]=mat
	node.material_override=materials[color]; parent.add_child(node); return node
func pivot(parent: Node3D,p: Vector3) -> Node3D:
	var node:=Node3D.new(); parent.add_child(node); node.position=p; return node
func _ready() -> void:
	part(self,Vector3(0,.64,-.08),Vector3(.32,.35,.66),"211e29")
	part(self,Vector3(0,.75,.29),Vector3(.40,.40,.39),"292430")
	part(self,Vector3(0,.50,.36),Vector3(.24,.22,.29),"462332")
	head=pivot(self,Vector3(0,.85,.48)); head.name="beast_head"
	part(head,Vector3(0,.04,.08),Vector3(.24,.25,.27),"27222e")
	part(head,Vector3(0,-.07,.32),Vector3(.16,.12,.24),"3e3447")
	part(head,Vector3(0,-.055,.53),Vector3(.125,.075,.055),"100f18")
	jaw=pivot(head,Vector3(0,-.18,.18))
	part(jaw,Vector3(0,-.025,.19),Vector3(.15,.065,.23),"311c2b")
	part(jaw,Vector3(0,.025,.22),Vector3(.10,.014,.16),"b22e48")
	for side in [-1,1]:
		part(head,Vector3(side*.18,.29,-.015),Vector3(.10,.21,.10),"211c2b",true).rotation.z=-side*.2
		part(head,Vector3(side*.185,.105,.24),Vector3(.075,.031,.036),"ff244a").rotation.z=side*.20
		part(head,Vector3(side*.18,.15,.23),Vector3(.11,.04,.075),"393044").rotation.z=side*.3
		for i in 7:
			part(head,Vector3(side*.13,-.165,.13+i*.051),Vector3(.024,.040 if i!=4 else .080,.025),"e3dbc6",true).rotation.z=PI
			part(jaw,Vector3(side*.12,.045,.02+i*.048),Vector3(.020,.03,.018),"e3dbc6",true)
		for back in [false,true]:
			var joint:=pivot(self,Vector3(side*(.29 if not back else .24),.62,.34 if not back else -.50))
			joints[("hip" if back else "shoulder")+("R" if side<0 else "L")]=joint
			part(joint,Vector3(0,-.13,0),Vector3(.16 if not back else .18,.26,.19),"292430")
			var knee:=pivot(joint,Vector3(0,-.30,-.065 if back else .025)); knees.append(knee)
			part(knee,Vector3(0,-.12,.015),Vector3(.09,.19,.10),"211e29")
			part(knee,Vector3(0,-.255,.09),Vector3(.135,.065,.18),"382634")
			for c in 4: part(knee,Vector3((c-1.5)*.055,-.25,.24),Vector3(.02,.022,.075),"b6a8b7")
		for i in 11:
			var tuft:=part(self,Vector3(side*(.27+sin(i*.8)*.06),.84-i*.015,.31-i*.085),Vector3(.10,.18,.12),"302b3c",true)
			tuft.rotation=Vector3(-.65,0,-side*.70)
	for i in 8:
		part(self,Vector3(0,1.00-i*.029,.24-i*.10),Vector3(.095,.15,.12),"393044",true).rotation.x=-.6
	tail=pivot(self,Vector3(0,.62,-.63))
	part(tail,Vector3(0,-.10,-.29),Vector3(.14,.16,.38),"292430").rotation.x=-.3
	preload("res://scripts/weapon_model_builder.gd").new()._merge_group(self)
func set_motion(speed: float,_crouch: bool=false,_aim: bool=false,bite: bool=false) -> void:
	travel=speed; attacking=bite
func _process(delta: float) -> void:
	phase+=delta*(5.0+travel*1.15)
	var activity:=clampf(travel/3.0,0,1)
	var i:=0
	for key in joints:
		var offset:=0.0 if key in ["shoulderL","hipR"] else PI
		if travel>6: offset=0.0 if key.begins_with("shoulder") else PI*.75
		joints[key].rotation.x=sin(phase+offset)*.48*activity
		knees[i].rotation.x=maxf(0,-sin(phase+offset))*.55*activity; i+=1
	head.rotation.x=sin(phase*2)*.035*activity+sin(phase*.17)*.025+(-.18 if attacking else 0)
	jaw.rotation.x=(-.26-absf(sin(phase*2))*.22) if attacking else -.045-absf(sin(phase*.6))*.035
	tail.rotation.y=sin(phase*.45)*.16
