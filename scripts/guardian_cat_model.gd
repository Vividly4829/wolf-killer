extends Node3D
## Long-haired silver/brown tabbies: broad muzzle, cream ruff, tufted ears and ringed plume.
var variant := 0
var moving := 0.0
var attacking := 0.0
var fallen := false
var phase := 0.0
var legs: Array[Node3D] = []
var tail: Node3D
var head: Node3D
var body: Node3D
var fur: ShaderMaterial
func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new(); result.albedo_color=color; result.roughness=.82; result.metallic=metal
	return result
func oval(parent: Node3D,p: Vector3,r: Vector3,mat: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); var mesh:=SphereMesh.new(); mesh.radial_segments=24; mesh.rings=14
	mesh.radius=1; mesh.height=2; node.mesh=mesh; node.position=p; node.scale=r; node.material_override=mat; parent.add_child(node); return node
func strand(parent: Node3D,a: Vector3,b: Vector3,width: float,mat: Material) -> void:
	var node:=MeshInstance3D.new(); var mesh:=CylinderMesh.new(); mesh.top_radius=width*.15; mesh.bottom_radius=width; mesh.height=a.distance_to(b); mesh.radial_segments=7
	node.mesh=mesh; node.material_override=mat; node.position=(a+b)*.5; node.quaternion=Quaternion(Vector3.UP,(b-a).normalized()); parent.add_child(node)
func _ready() -> void:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
varying vec3 coat_point;
uniform vec4 light_coat : source_color = vec4(.52,.48,.40,1.);
uniform vec4 dark_coat : source_color = vec4(.16,.15,.14,1.);
void vertex(){coat_point=VERTEX;}
void fragment(){
 float stripes=sin(coat_point.z*7.0+sin(coat_point.y*4.0+coat_point.x*2.0)*1.1);
 float grain=sin(coat_point.x*155.0+sin(coat_point.z*60.0))*sin(coat_point.y*220.0);
 float stripe=smoothstep(.3,.68,stripes);
 ALBEDO=mix(light_coat.rgb,dark_coat.rgb,stripe*.60)*(1.0+grain*.025);
 ROUGHNESS=.97;
}
"""
	fur=ShaderMaterial.new(); fur.shader=shader
	fur.set_shader_parameter("light_coat",Color("a69c83") if variant==0 else Color("827c72"))
	fur.set_shader_parameter("dark_coat",Color("40352c") if variant==0 else Color("292b2a"))
	var fluff:=material(Color("9c927c") if variant==0 else Color("77756d"))
	var ring:=material(Color("51483c") if variant==0 else Color("41433e"))
	var cream:=material(Color("dbd5ba")); var dark:=material(Color("27231f")); var pink:=material(Color("956e69")); var leather:=material(Color("49352b")); var brass:=material(Color("b19a5b"),.55)
	body=Node3D.new(); add_child(body)
	oval(body,Vector3(0,1.26,-.25),Vector3(.57,.63,1.10),fur)
	oval(body,Vector3(0,1.42,.50),Vector3(.68,.75,.66),fur)
	oval(body,Vector3(0,1.30,1.03),Vector3(.41,.55,.20),cream)
	# Layered, tapered ruff tufts break up the rounded silhouette.
	for i in 18:
		var a:=i*TAU/18
		strand(body,Vector3(cos(a)*.36,1.52+sin(a)*.38,.64),Vector3(cos(a)*.78,1.40+sin(a)*.76,.55),.10,cream if i%3==0 else fluff)
	head=Node3D.new(); head.position=Vector3(0,1.96,.72); body.add_child(head)
	oval(head,Vector3.ZERO,Vector3(.54,.47,.43),fur)
	for side in [-1,1]:
		oval(head,Vector3(side*.32,-.10,.13),Vector3(.29,.32,.28),fur)
		oval(head,Vector3(side*.14,-.19,.37),Vector3(.19,.135,.15),cream)
		var ear:=SurfaceTool.new(); ear.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts: Array[Vector3]=[Vector3(side*.23,.24,.02),Vector3(side*.54,.20,-.12),Vector3(side*.49,.72,-.11)]
		for j in ([0,1,2] if side>0 else [2,1,0]): ear.add_vertex(pts[j])
		ear.generate_normals(); var ear_mesh:=MeshInstance3D.new(); ear_mesh.mesh=ear.commit(); var ear_mat:=fluff.duplicate(); ear_mat.cull_mode=BaseMaterial3D.CULL_DISABLED; ear_mesh.material_override=ear_mat; head.add_child(ear_mesh)
		strand(head,Vector3(side*.45,.62,-.09),Vector3(side*.51,.84,-.10),.030,dark)
		oval(head,Vector3(side*.40,.39,-.065),Vector3(.10,.20,.025),pink)
		var eye:=oval(head,Vector3(side*.245,.015,.375),Vector3(.125,.078,.040),dark); eye.rotation.z=side*.15
		oval(head,Vector3(side*.245,.018,.407),Vector3(.100,.055,.018),material(Color("bcc879") if variant==0 else Color("aac56c")))
		oval(head,Vector3(side*.245,.018,.423),Vector3(.023,.047,.007),dark)
		oval(head,Vector3(side*.22,.037,.430),Vector3(.011,.011,.006),material(Color("fff6dc")))
		for whisker in 4:
			strand(head,Vector3(side*.17,-.19,.47),Vector3(side*(.75+whisker*.045),-.19+(whisker-1.5)*.065,.48-whisker*.035),.0045,cream)
	oval(head,Vector3(0,-.155,.51),Vector3(.105,.067,.044),material(Color("65463d")))
	strand(head,Vector3(0,-.18,.52),Vector3(0,-.255,.49),.016,dark)
	for side in [-1,1]:
		strand(head,Vector3(side*.05,.34,.31),Vector3(side*.13,.20,.39),.013,dark)
		strand(head,Vector3(side*.13,.20,.39),Vector3(side*.27,.29,.32),.012,dark)
		strand(head,Vector3(side*.16,.12,.407),Vector3(side*.35,.16,.33),.033,fluff)
	oval(head,Vector3(0,-.305,.32),Vector3(.20,.085,.14),cream)
	for side in [-1,1]:
		for z in [-.92,.62]:
			var leg:=Node3D.new(); leg.position=Vector3(side*.40,1.05,z); body.add_child(leg); legs.append(leg)
			oval(leg,Vector3(0,-.25,0),Vector3(.225,.43,.24),fur)
			oval(leg,Vector3(0,-.67,.015),Vector3(.17,.34,.18),fur)
			oval(leg,Vector3(0,-.94,.15),Vector3(.235,.16,.32),cream if variant==0 else fur)
			for toe in [-1,0,1]: strand(leg,Vector3(toe*.09,-.90,.38),Vector3(toe*.09,-.98,.40),.009,dark)
	tail=Node3D.new(); tail.position=Vector3(0,1.38,-1.1); body.add_child(tail)
	for i in 12:
		var t:=float(i)/11
		oval(tail,Vector3(sin(t*2.8)*.42,t*1.35,-t*.90),Vector3(.22-t*.045,.23,.25),ring if i%3==0 else fluff)
	# Short overlapping coat tips around cheeks and flanks suggest long fur.
	for side in [-1,1]:
		for i in 9:
			var z: float=-.95+i*.20
			strand(body,Vector3(side*.49,1.10,z),Vector3(side*.64,.87,z-.12),.085,fluff)
		for i in 5:
			strand(head,Vector3(side*.37,-.04-i*.05,.12),Vector3(side*(.58+i*.015),-.16-i*.05,.03),.065,fluff)
	# A low saddle leaves the neck and face visible from the rider's camera.
	oval(body,Vector3(0,1.84,-.35),Vector3(.46,.075,.55),leather)
	for z in [-.74,.03]: oval(body,Vector3(0,1.94,z),Vector3(.42,.11,.10),leather)
	for side in [-1,1]:
		strand(body,Vector3(side*.44,1.81,-.34),Vector3(side*.62,1.10,-.25),.03,leather)
		oval(body,Vector3(side*.63,1.08,-.25),Vector3(.10,.035,.11),brass)
	# Batch static details per animated joint; preserve the head, legs and tail.
	preload("res://scripts/weapon_model_builder.gd").new()._merge_group(self)
	for mesh in find_children("*","MeshInstance3D",true,false): mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
func _process(delta: float) -> void:
	phase+=delta*(2.0+moving*1.5)
	body.rotation.z=lerp_angle(body.rotation.z,1.4 if fallen else 0.0,delta*5)
	body.position.y=lerpf(body.position.y,-.65 if fallen else sin(phase*2)*minf(.045,moving*.007),minf(1,delta*8))
	if fallen: return
	for i in legs.size(): legs[i].rotation.x=sin(phase+(0 if i in [0,3] else PI))*minf(.60,moving*.09)
	tail.rotation.z=sin(phase*.35)*.12; head.rotation.y=sin(phase*.17)*.08
	attacking=maxf(0,attacking-delta)
	if attacking>0: legs[0].rotation.x=-1.1*sin(attacking*PI/.38)
