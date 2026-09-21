class_name GoreEffects
extends Node3D
## Bounded, stylized combat effects compatible with Godot's GL renderer.
## Public positions and directions are in world space. Pool points are ground points.

const MAX_DROPLETS := 160
const MAX_POOLS := 96
const MAX_LIMBS := 18
const POOL_LIFETIME := 100.0
const LIMB_LIFETIME := 65.0
var _droplets: Array[Dictionary] = []
var _pools: Array[Dictionary] = []
var _limbs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _blood_material: StandardMaterial3D
var _pool_material: StandardMaterial3D
var _stump_material: StandardMaterial3D
var _bone_material: StandardMaterial3D
var _drop_mesh: SphereMesh
var _pool_mesh: ArrayMesh

func _ready() -> void:
	_rng.randomize()
	_prepare_resources()

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .84
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _prepare_resources() -> void:
	if _blood_material != null:
		return
	_blood_material = _material(Color("92232c"), true)
	_pool_material = _material(Color("611018"), true)
	_stump_material = _material(Color("8c1d28"), true)
	_bone_material = _material(Color("c7b6a2"))
	_drop_mesh = SphereMesh.new()
	_drop_mesh.radius = .5
	_drop_mesh.height = 1.0
	_drop_mesh.radial_segments = 5
	_drop_mesh.rings = 2
	_drop_mesh.material = _blood_material
	_pool_mesh = _make_pool_mesh()

func _make_pool_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	# Main uneven splash plus three separate satellite marks in a single draw.
	for part in 4:
		var center := Vector3.ZERO if part == 0 else Vector3(cos(part * 2.1), 0, sin(part * 2.1)) * 1.03
		var radius := 1.0 if part == 0 else .12 + part * .035
		for i in 12:
			var angle_a := float(i) / 12.0 * TAU
			var angle_b := float(i + 1) / 12.0 * TAU
			var radius_a := radius * (.80 + .18 * sin(i * 2.4 + part))
			var radius_b := radius * (.80 + .18 * sin((i + 1) * 2.4 + part))
			var a := center + Vector3(cos(angle_a), 0, sin(angle_a)) * radius_a
			var b := center + Vector3(cos(angle_b), 0, sin(angle_b)) * radius_b
			for p in [center, b, a]:
				vertices.append(p)
				normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _pool_material)
	return mesh

func _discard(entry: Dictionary) -> void:
	var node: Node3D = entry.node
	if is_instance_valid(node):
		node.visible = false
		node.queue_free()

func _trim(entries: Array[Dictionary], limit: int) -> void:
	while entries.size() >= limit:
		_discard(entries.pop_front())

func clear() -> void:
	for entries in [_droplets, _pools, _limbs]:
		for entry: Dictionary in entries:
			_discard(entry)
		entries.clear()

func blood_burst(point: Vector3, direction: Vector3, intensity: float = 1.0) -> void:
	_prepare_resources()
	intensity = clampf(intensity, .25, 2.5)
	var forward := direction.normalized() if direction.length_squared() > .001 else Vector3.UP
	var floor_y := _ground_height(point)
	var count := clampi(roundi(14 * intensity), 5, 30)
	for i in count:
		_trim(_droplets, MAX_DROPLETS)
		var drop := MeshInstance3D.new()
		drop.name = "BloodDroplet"
		drop.mesh = _drop_mesh
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(drop)
		drop.global_position = point
		var size := _rng.randf_range(.023, .065) * sqrt(intensity)
		drop.scale = Vector3(size, size * _rng.randf_range(1.1, 2.8), size)
		var scatter := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-.2, 1.3), _rng.randf_range(-1, 1))
		var velocity := forward * _rng.randf_range(1.2, 3.6) + scatter * (1.0 + intensity * .45)
		_droplets.append({"node": drop, "velocity": velocity, "age": 0.0, "life": _rng.randf_range(.45, .95), "ground": floor_y, "size": size})

func blood_pool(point: Vector3, size: float = .25) -> void:
	_prepare_resources()
	_trim(_pools, MAX_POOLS)
	var pool := MeshInstance3D.new()
	pool.name = "BloodPool"
	pool.mesh = _pool_mesh
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	pool.global_position = point + Vector3.UP * (.012 + _rng.randf_range(0, .003))
	pool.rotation.y = _rng.randf() * TAU
	var radius := clampf(size, .025, 1.2)
	pool.scale = Vector3(radius * _rng.randf_range(.8, 1.15), 1.0, radius)
	_pools.append({"node": pool, "age": 0.0, "life": POOL_LIFETIME, "scale": pool.scale})

func _limb_part(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rotation_z: float = 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.rotation.z = rotation_z
	part.material_override = material
	parent.add_child(part)
	return part

func _taper(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 6
	return mesh

func severed_limb(point: Vector3, direction: Vector3, fur_color: Color = Color(.28, .25, .22), size_scale: float = 1.0) -> void:
	_prepare_resources()
	_trim(_limbs, MAX_LIMBS)
	var limb := Node3D.new()
	limb.name = "SeveredWolfLeg"
	add_child(limb)
	limb.global_position = point
	var limb_scale := clampf(size_scale, .5, 1.8)
	limb.scale = Vector3.ONE * limb_scale
	var fur := _material(fur_color)
	_limb_part(limb, _taper(.105, .075, .33), Vector3.ZERO, fur, .12)
	_limb_part(limb, _taper(.073, .041, .29), Vector3(.025, -.28, 0), fur, -.12)
	var paw := BoxMesh.new()
	paw.size = Vector3(.13, .09, .20)
	_limb_part(limb, paw, Vector3(.04, -.445, -.035), fur)
	_limb_part(limb, _taper(.105, .105, .025), Vector3(-.021, .167, 0), _stump_material, .12)
	_limb_part(limb, _taper(.025, .025, .034), Vector3(-.024, .185, 0), _bone_material, .12)
	var forward := direction.normalized() if direction.length_squared() > .001 else Vector3.FORWARD
	var velocity := forward * _rng.randf_range(1.2, 2.4) + Vector3(_rng.randf_range(-.8, .8), 2.1, _rng.randf_range(-.8, .8))
	_limbs.append({"node": limb, "velocity": velocity, "spin": Vector3(_rng.randf_range(-5, 5), _rng.randf_range(-4, 4), _rng.randf_range(-5, 5)), "age": 0.0, "life": LIMB_LIFETIME, "ground": _ground_height(point), "rest_height": .11 * limb_scale, "pool_radius": .18 * limb_scale, "resting": false})
	blood_burst(point, direction, 1.25)

func _ground_height(point: Vector3) -> float:
	if not is_inside_tree():
		return point.y - .65
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .15, point + Vector3.DOWN * 4.0, 1)
	ray.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.normal.y > .25:
		return float(hit.position.y)
	return point.y - .65

func _process(delta: float) -> void:
	delta = minf(delta, .05)
	for i in range(_droplets.size() - 1, -1, -1):
		var entry := _droplets[i]
		entry.age += delta
		var node: Node3D = entry.node
		var velocity: Vector3 = entry.velocity
		velocity.y -= 9.8 * delta
		node.global_position += velocity * delta
		entry.velocity = velocity
		node.rotation += Vector3(3.0, 1.5, 2.0) * delta
		if node.global_position.y <= float(entry.ground) + .02:
			if _rng.randf() < .34:
				blood_pool(Vector3(node.global_position.x, entry.ground, node.global_position.z), float(entry.size) * 1.15)
			_discard(entry)
			_droplets.remove_at(i)
		elif float(entry.age) >= float(entry.life):
			_discard(entry)
			_droplets.remove_at(i)
	for i in range(_limbs.size() - 1, -1, -1):
		var entry := _limbs[i]
		entry.age += delta
		var node: Node3D = entry.node
		if not entry.resting:
			var velocity: Vector3 = entry.velocity
			velocity.y -= 9.8 * delta
			node.global_position += velocity * delta
			node.rotation += (entry.spin as Vector3) * delta
			entry.velocity = velocity
			if node.global_position.y <= float(entry.ground) + float(entry.rest_height):
				node.global_position.y = float(entry.ground) + float(entry.rest_height)
				node.rotation = Vector3(0, node.rotation.y, PI * .5)
				entry.resting = true
				blood_pool(Vector3(node.global_position.x, entry.ground, node.global_position.z), float(entry.pool_radius))
		if float(entry.age) >= float(entry.life):
			_discard(entry)
			_limbs.remove_at(i)
	for i in range(_pools.size() - 1, -1, -1):
		var entry := _pools[i]
		entry.age += delta
		if float(entry.age) > float(entry.life) - 3.0:
			var node: Node3D = entry.node
			node.scale = (entry.scale as Vector3) * maxf(.02, (float(entry.life) - float(entry.age)) / 3.0)
		if float(entry.age) >= float(entry.life):
			_discard(entry)
			_pools.remove_at(i)

func effect_counts() -> Dictionary:
	return {"droplets": _droplets.size(), "pools": _pools.size(), "limbs": _limbs.size()}
