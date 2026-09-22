extends Node3D
var game: Node3D
var spots: Array[Vector3] = []
var models: Array[Node3D] = []
var consumed: Dictionary = {}
func regrow(wave: int) -> void:
	for model in models: model.queue_free()
	models.clear(); spots.clear(); consumed.clear()
	var nav = game.world.wolf_nav
	if nav.reachable.is_empty(): return
	var rng := RandomNumberGenerator.new(); rng.seed = 98431 + wave * 137
	for i in 10:
		var p: Vector3 = nav.point(nav.reachable[rng.randi_range(0,nav.reachable.size()-1)])
		if game.world.is_safe_position(p): continue
		spots.append(p)
		var cluster := Node3D.new(); add_child(cluster); cluster.position=p; models.append(cluster)
		for j in 3:
			var offset := Vector3((j-1)*.24,0,float(j%2)*.17)
			part(cluster,offset+Vector3(0,.16,0),Vector3(.04,.18,.04),Color("e9d9ba"))
			part(cluster,offset+Vector3(0,.34,0),Vector3(.18,.095,.18),Color("ce3324"))
			for dot in 7:
				var angle := dot*TAU/7
				part(cluster,offset+Vector3(cos(angle)*.11,.407,sin(angle)*.11),Vector3(.023,.015,.023),Color("fff3de"))
		batch(cluster)
func part(parent: Node3D,p: Vector3,s: Vector3,c: Color) -> void:
	var node := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius=1; mesh.height=2; mesh.radial_segments=8; mesh.rings=4
	node.mesh=mesh; node.position=p; node.scale=s
	var mat := StandardMaterial3D.new(); mat.albedo_color=c; mat.roughness=.9; node.material_override=mat; parent.add_child(node)
func nearby() -> int:
	for i in models.size():
		if models[i].visible and game.player.position.distance_to(spots[i])<2.2: return i
	return -1
func can_consume(index: int,peer: int,p: Vector3) -> bool:
	return index>=0 and index<spots.size() and p.distance_to(spots[index])<2.5 and not consumed.has("%d:%d"%[peer,index])
func mark(index: int,peer: int) -> void: consumed["%d:%d"%[peer,index]]=true
func apply(index: int) -> void:
	if index<0 or index>=models.size(): return
	models[index].hide(); game.affliction.consume()

func batch(cluster: Node3D) -> void:
	var groups: Dictionary = {}
	for node in cluster.get_children():
		var key: Color = node.material_override.albedo_color
		if not groups.has(key): groups[key]=[]
		groups[key].append(node)
	for nodes in groups.values():
		var instance := MultiMeshInstance3D.new(); var multi := MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=nodes[0].mesh; multi.instance_count=nodes.size()
		for i in nodes.size(): multi.set_instance_transform(i,nodes[i].transform)
		instance.multimesh=multi; instance.material_override=nodes[0].material_override; cluster.add_child(instance)
		for node in nodes: cluster.remove_child(node); node.queue_free()
