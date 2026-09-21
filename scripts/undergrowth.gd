extends Node3D
## Deterministic, batched game-only shrubs. A spatial hash is shared with navigation.
var world: Node3D
var patches: Dictionary = {}
func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 96021
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 3
	mesh.radius = 1
	mesh.height = 2
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1
	mesh.material = material
	var poses: Array[Transform3D] = []
	var colors: Array[Color] = []
	for attempt in 2400:
		var i: int = world.nav.reachable[rng.randi_range(0,world.nav.reachable.size()-1)]
		var p: Vector3 = world.nav.point(i)
		if p.y<.65 or p.distance_to(world.spawn_position)<11: continue
		if world.shooting_range and p.distance_to(world.shooting_range.firing_point)<30: continue
		var clear := true
		for bridge: Dictionary in world.exploration_data.bridges:
			var a := Vector3(bridge.a[0],bridge.a[1],bridge.a[2])
			var b := Vector3(bridge.b[0],bridge.b[1],bridge.b[2])
			if Geometry3D.get_closest_point_to_segment(p,a,b).distance_to(p)<3: clear = false
		for house: Dictionary in world.exploration_data.get("houses",[]):
			if Vector2(p.x-house.center[0],p.z-house.center[1]).length()<12: clear = false
		if not clear: continue
		var key := Vector2i(floori(p.x/4),floori(p.z/4))
		if patches.has(key): continue
		patches[key] = p
		for branch in 5:
			var at := p+Vector3(rng.randf_range(-.8,.8),rng.randf_range(.25,.5),rng.randf_range(-.8,.8))
			poses.append(Transform3D(Basis.IDENTITY.scaled(Vector3(rng.randf_range(.45,.8),rng.randf_range(.3,.65),rng.randf_range(.45,.8))),at))
			colors.append(Color(.18+rng.randf()*.14,.23+rng.randf()*.12,.10))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = poses.size()
	for i in poses.size():
		batch.multimesh.set_instance_transform(i,poses[i])
		batch.multimesh.set_instance_color(i,colors[i])
	add_child(batch)
	world.nav.brush = patches
	world.wolf_nav.brush = patches
