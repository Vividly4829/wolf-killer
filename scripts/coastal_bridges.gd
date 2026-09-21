extends Node3D
var pieces: Array[Transform3D] = []
## Fictional gameplay crossings, separate from the surveyed as-is island asset.
func build(data: Dictionary) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("695449")
	wood.roughness = .95
	for route: Dictionary in data.bridges:
		var a := Vector3(route.a[0],route.a[1],route.a[2])
		var b := Vector3(route.b[0],route.b[1],route.b[2])
		var forward := (b-a).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var up := right.cross(forward).normalized()
		var basis := Basis(right,up,-forward)
		var length := a.distance_to(b)
		box(route.name+" deck",(a+b)*.5-up*.12,Vector3(3.4,.24,length+1.2),basis,wood)
		for side in [-1,1]:
			box("Handrail",(a+b)*.5+right*side*1.55+Vector3.UP,Vector3(.12,.13,length+1.2),basis,wood)
			for step in range(ceili(length/2.5)+1):
				var p: Vector3 = a.lerp(b,minf(1.0,step*2.5/length))+right*side*1.55
				box("Timber post",p+Vector3.UP*.35,Vector3(.17,1.6,.17),Basis.IDENTITY,wood)
		for step in range(ceili(length/.32)):
			box("Deck board",a.lerp(b,minf(1.0,step*.32/length))+up*.008,Vector3(3.35,.025,.29),basis,wood,false)
		# Visible trestles beneath the added spans, batched with their decking.
		if "footbridge" in route.name:
			for step in range(1,ceili(length/6)):
				var p := a.lerp(b,step*6.0/length)
				for side in [-1,1]:
					var depth := maxf(.5,p.y+.5)
					box("Bridge piling",p+right*side*1.3-Vector3.UP*depth*.5,Vector3(.3,depth,.3),Basis.IDENTITY,wood,false)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	batch.multimesh.mesh = cube
	batch.multimesh.instance_count = pieces.size()
	for i in pieces.size(): batch.multimesh.set_instance_transform(i,pieces[i])
	batch.material_override = wood
	add_child(batch)

func box(label: String,p: Vector3,dimensions: Vector3,orientation: Basis,material: Material,collision: bool = true) -> void:
	pieces.append(Transform3D(orientation.scaled_local(dimensions),p))
	if collision:
		var body := StaticBody3D.new()
		body.name = label
		body.transform = Transform3D(orientation,p)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
