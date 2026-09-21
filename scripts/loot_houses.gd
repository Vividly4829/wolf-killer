extends Node3D
var world: Node3D
var drops: Array[int] = []
var models: Array[Node3D] = []
var positions: Array[Vector3] = []
func _ready() -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("66513b")
	timber.cull_mode = BaseMaterial3D.CULL_DISABLED
	for house: Dictionary in world.exploration_data.get("houses",[]):
		var polygon := PackedVector2Array()
		for p: Array in house.polygon: polygon.append(Vector2(p[0],p[1]))
		var triangles := Geometry2D.triangulate_polygon(polygon)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in triangles:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(polygon[i].x,house.floor,polygon[i].y))
		var floor_mesh := MeshInstance3D.new()
		floor_mesh.mesh = st.commit()
		floor_mesh.material_override = timber
		add_child(floor_mesh)
		floor_mesh.create_trimesh_collision()
		var door := Vector3(house.door[0],house.floor,house.door[2])
		var end := Vector3(house.end[0],house.end[1],house.end[2])
		var count := maxi(4,ceili(door.distance_to(end)/.35))
		for step in count:
			var p := door.lerp(end,(float(step)+.5)/count)
			var box := MeshInstance3D.new()
			var shape := BoxMesh.new()
			var riser := maxf(.18,p.y-minf(door.y,end.y)+.18)
			shape.size = Vector3(3.0,riser,Vector2(door.x-end.x,door.z-end.z).length()/count+.025)
			box.mesh = shape
			box.material_override = timber
			box.position = p-Vector3.UP*riser*.5
			box.rotation.y = atan2(end.x-door.x,end.z-door.z)
			add_child(box)
			box.create_trimesh_collision()
		var position := Vector3(house.center[0],house.floor+.45,house.center[1])
		positions.append(position)
		var table := MeshInstance3D.new()
		var top := BoxMesh.new()
		top.size = Vector3(1.0,.12,.6)
		table.mesh = top
		table.material_override = timber
		table.position = position-Vector3.UP*.1
		add_child(table)
		var model := Node3D.new()
		add_child(model)
		model.position = position
		model.rotation = Vector3(PI/2,.3,0)
		models.append(model)
		drops.append(-1)
func reroll() -> void:
	var rolled: Array = []
	for i in positions.size(): rolled.append([3,6,7,10,13,14].pick_random() if randf()<.08 else randi_range(18,21))
	apply_drops(rolled)
func apply_drops(values: Array) -> void:
	for i in mini(values.size(),models.size()):
		var weapon := int(values[i])
		if drops[i]==weapon: continue
		drops[i] = weapon
		for child in models[i].get_children(): child.queue_free()
		if weapon>=0 and weapon<24:
			var built: Dictionary = preload("res://scripts/weapon_model_builder.gd").new().build(weapon)
			models[i].add_child(built.root)
func nearby(p: Vector3) -> int:
	for i in positions.size():
		if drops[i]>=0 and positions[i].distance_to(p)<2.4:
			var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.2,positions[i]+Vector3.UP*.1,1)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return i
	return -1
func take(index: int,game: Node3D) -> void:
	if index<0 or index>=drops.size() or drops[index]<0: return
	var weapon := drops[index]
	var changed: Array = drops.duplicate()
	changed[index] = -1
	apply_drops(changed)
	grant(game,weapon)
static func grant(game: Node3D,weapon: int) -> void:
	if not game.progress.owned.has(weapon): game.progress.owned.append(weapon)
	game.progress.save_progress()
	game.select_weapon(weapon)
	game.ammo[weapon] = int(game.WEAPONS[weapon].magazine)
	game.reserve_ammo[weapon] = maxi(game.reserve_ammo[weapon],int(game.WEAPONS[weapon].reserve))
	game.show_notice("FOUND: "+str(game.WEAPONS[weapon].name)+" — free supplies",5)
func _process(_delta: float) -> void:
	var game = world.get_parent()
	if not game.get("player") or game.mode!="playing": return
	var i := nearby(game.player.position)
	if i>=0: game.show_notice("[ %s ] TAKE %s" % ["Y" if game.controller_device>=0 else "E",game.WEAPONS[drops[i]].name],.2)

static func lower_interior_ground(mesh: Mesh,transform: Transform3D,houses: Array) -> Mesh:
	var output := ArrayMesh.new()
	var inverse := transform.affine_inverse()
	var polygons: Array[PackedVector2Array] = []
	var bounds: Array[Rect2] = []
	for house: Dictionary in houses:
		var polygon := PackedVector2Array()
		for p: Array in house.polygon: polygon.append(Vector2(p[0],p[1]))
		polygons.append(polygon)
		var bound := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon: bound = bound.expand(point)
		bounds.append(bound.grow(1.2))
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			var p := transform*vertices[i]
			for j in houses.size():
				var q := Vector2(p.x,p.z)
				if not bounds[j].has_point(q): continue
				var inside := Geometry2D.is_point_in_polygon(q,polygons[j])
				var distance := INF
				for edge in polygons[j].size(): distance = minf(distance,q.distance_to(Geometry2D.get_closest_point_to_segment(q,polygons[j][edge],polygons[j][(edge+1)%polygons[j].size()])))
				if inside or distance<1.2: p.y = minf(p.y,float(houses[j].floor)-.12)
			vertices[i] = inverse*p
		arrays[Mesh.ARRAY_VERTEX] = vertices
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return output
