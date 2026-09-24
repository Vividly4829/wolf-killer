extends Node3D
var variant:=0
var moving:=0.0
var wake: MeshInstance3D
func _ready() -> void:
	name="Motorboat_%d"%variant
	var outer:=Color("a4b6bb") if variant%2==0 else Color("244d72")
	var rim:=Color("deddd0")
	var mesh:=SurfaceTool.new(); mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Open clinker-shaped hull: tapered bow, broad stern, inset cream gunwales.
	var outline: Array[Vector2]=[Vector2(0,-2.4),Vector2(.72,-1.8),Vector2(1,-.8),Vector2(1,1.85),Vector2(-1,1.85),Vector2(-1,-.8),Vector2(-.72,-1.8)]
	for i in outline.size():
		var a: Vector2=outline[i]; var b: Vector2=outline[(i+1)%outline.size()]
		var top_a:=Vector3(a.x,.7,a.y); var top_b:=Vector3(b.x,.7,b.y)
		var low_a:=Vector3(a.x*.65,-.15,a.y*.86); var low_b:=Vector3(b.x*.65,-.15,b.y*.86)
		for vertex in [top_a,low_a,top_b,top_b,low_a,low_b]: mesh.set_color(outer); mesh.add_vertex(vertex)
		var rail: MeshInstance3D=box((top_a+top_b)*.5,Vector3(.09,.1,top_a.distance_to(top_b)),rim)
		rail.rotation.y=atan2(top_b.x-top_a.x,top_b.z-top_a.z)
	mesh.generate_normals(); var hull:=MeshInstance3D.new(); hull.mesh=mesh.commit()
	var mat:=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.cull_mode=BaseMaterial3D.CULL_DISABLED; mat.roughness=.7; hull.material_override=mat; add_child(hull)
	box(Vector3(0,.08,0),Vector3(1.35,.14,3.3),Color("8f9290"))
	for z in [-.8,.7]:
		box(Vector3(0,.35,z),Vector3(1.73,.15,.42),Color("a89068"))
		for x in [-.65,.65]: box(Vector3(x,.2,z),Vector3(.09,.3,.28),Color("44494a"))
	box(Vector3(0,.63,2),Vector3(.47,.65,.46),Color("303c42"))
	box(Vector3(0,.02,2.05),Vector3(.15,.75,.15),Color("333c42"))
	box(Vector3(0,-.34,2.15),Vector3(.55,.08,.18),Color("5a6669"))
	box(Vector3(-.65,.84,-1.3),Vector3(.38,.12,.48),Color("e8dec4"))
	var wheel:=MeshInstance3D.new(); var torus:=TorusMesh.new(); torus.inner_radius=.13; torus.outer_radius=.17; wheel.mesh=torus; wheel.position=Vector3(-.48,.94,-1.2); wheel.rotation.x=PI/2; add_child(wheel)
	var label:=Label3D.new(); label.text="NAUTOY %02d"%(variant+1); label.font_size=30; label.pixel_size=.006; label.position=Vector3(0,.77,1.7); label.rotation.y=PI; add_child(label)
	wake=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(2,3); wake.mesh=plane; wake.position=Vector3(0,.01,3.6)
	var foam:=StandardMaterial3D.new(); foam.albedo_color=Color(.68,.82,.8,.14); foam.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; foam.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; wake.material_override=foam; add_child(wake)
func box(p: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var m:=BoxMesh.new(); m.size=size; n.mesh=m; n.position=p
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=.75; n.material_override=mat; add_child(n); return n
func _process(_delta: float) -> void:
	wake.visible=moving>.5
	wake.scale.z=clampf(moving/3,.2,3)
