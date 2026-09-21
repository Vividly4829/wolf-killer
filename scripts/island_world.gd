class_name IslandWorld
extends Node3D
## The existing island model and its sampled walkable terrain, in original metres.

const NavScript = preload("res://scripts/coastal_nav.gd")
const ISLAND: PackedScene = preload("res://assets/island-realistic.glb")
const SURROUNDINGS_PATH := "res://assets/surroundings.glb"
var nav: IslandNav
var wolf_nav: IslandNav
var spawn_position := Vector3(-1.5, 3.85, 1.25)
var spawn_yaw: float = 0.0
var bed_position := Vector3(-6.25, 3.85, 3.25)
var bed_yaw: float = -1.72
var bed_wake_position := Vector3(-5.75, 3.85, 2.5)
var bed_wake_yaw: float = -1.107
var exterior_rally_point := Vector3(-0.25, 3.75, 6.0)
var cabin_outline := PackedVector2Array()
var cabin_floor: float = 3.85
const WOLF_CABIN_BUFFER := 0.8
var shop_position := Vector3(-7.75, 3.75, 5.25)
var world_data: Dictionary = {}
var sun: DirectionalLight3D
var shop: Node3D
var leaf_batches: Array[MultiMeshInstance3D] = []
var surroundings: Node3D
var exploration_data: Dictionary
var shooting_range: Node3D
var houses: Node3D
var weather: Node
var services: Node3D

func _ready() -> void:
	world_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world.json"))
	exploration_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/exploration.json"))
	for sample: Array in exploration_data.deck_samples:
		world_data.grid.heights[int(sample[0])] = float(sample[1])
	_read_cabin_footprint()
	preload("res://scripts/cabin_portal.gd").open_navigation(world_data.grid)
	_reserve_shop_footprint(world_data.grid)
	nav = NavScript.new()
	nav.setup(world_data.grid)
	spawn_position = nav.point(nav.nearest(spawn_position.x, spawn_position.z))
	# Aim through the clear left side of the doorway, beside the living-room table.
	var doorway := Vector3(-1.0, 3.87, 4.2069)
	spawn_yaw = atan2(spawn_position.x - doorway.x, spawn_position.z - doorway.z)
	bed_position = nav.point(nav.nearest(bed_position.x, bed_position.z, 1.0))
	bed_yaw = atan2(bed_position.x + 5.15, bed_position.z - 3.4)
	# Stand beside the foot of the source bunk, looking through its open aisle.
	bed_wake_position = nav.point(nav.nearest(bed_wake_position.x, bed_wake_position.z, .5))
	bed_wake_yaw = atan2(bed_wake_position.x + 4.75, bed_wake_position.z - 2.0)
	nav.field(spawn_position.x, spawn_position.z)
	_create_wolf_navigation()
	nav.extend_coast(exploration_data)
	wolf_nav.extend_coast(exploration_data)
	nav.field(spawn_position.x,spawn_position.z)
	wolf_nav.field(exterior_rally_point.x,exterior_rally_point.z)
	_create_environment()
	var island := ISLAND.instantiate()
	island.name = "OriginalIsland"
	add_child(island)
	var terrain_material := _surface_material(true)
	var building_material := _surface_material(false)
	_prepare_model(island, terrain_material, building_material)
	_create_foliage()
	_create_surroundings()
	houses = preload("res://scripts/loot_houses.gd").new()
	houses.world = self
	add_child(houses)
	var bridges := preload("res://scripts/coastal_bridges.gd").new()
	bridges.name = "GameOnlyBridges"
	add_child(bridges)
	bridges.build(exploration_data)
	_create_shop()
	_create_shelter_lighting()
	_create_cabin_bed()
	_create_chimney_smoke()
	shooting_range = preload("res://scripts/shooting_range.gd").new()
	shooting_range.world = self
	add_child(shooting_range)
	var brush := preload("res://scripts/undergrowth.gd").new()
	brush.world = self
	add_child(brush)
	var comfort := preload("res://scripts/cabin_comfort.gd").new()
	comfort.world = self
	comfort.name = "CabinComfort"
	add_child(comfort)
	services = preload("res://scripts/cabin_services.gd").new()
	services.world = self
	services.name = "CabinServices"
	add_child(services)
	weather = preload("res://scripts/wake_weather.gd").new()
	weather.world = self
	add_child(weather)

func _create_surroundings() -> void:
	# Preserve the separate source asset; gameplay navigation lives in exploration.json.
	if is_instance_valid(surroundings) or not ResourceLoader.exists(SURROUNDINGS_PATH):
		return
	var source := load(SURROUNDINGS_PATH) as PackedScene
	if source == null:
		return
	var context := source.instantiate() as Node3D
	if context == null:
		return
	if _is_surroundings_service(context):
		context.free()
		return
	context.name = "Surroundings"
	context.transform = Transform3D.IDENTITY
	context.process_mode = Node.PROCESS_MODE_DISABLED
	context.set_meta("visual_only", false)
	# Share shader code, not the existing island's material instances.
	_prepare_surroundings(context, _surface_material(true), _surface_material(false))
	surroundings = context
	add_child(surroundings)
	_add_coastal_collision(surroundings)

func _add_coastal_collision(node: Node) -> void:
	if node is MeshInstance3D and not str(node.name).to_lower().begins_with("context_foliage"):
		if str(node.name).to_lower().begins_with("context_ground"):
			node.mesh = preload("res://scripts/loot_houses.gd").lower_interior_ground(node.mesh,node.global_transform,exploration_data.get("houses",[]))
		for house: Dictionary in exploration_data.get("houses",[]):
			var normal := Vector3(house.normal[0],0,house.normal[1])
			var center := Vector3(house.door[0],house.floor+1.15,house.door[2])
			var portal := Transform3D(Basis(Vector3.UP,atan2(normal.x,normal.z)),center)
			node.mesh = preload("res://scripts/cabin_portal.gd").cut(node.mesh,node.global_transform,portal,Vector3(1.6,1.2,.8))
		node.create_trimesh_collision()
		return
	for child in node.get_children(): _add_coastal_collision(child)

func _is_surroundings_service(node: Node) -> bool:
	return node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D or node is NavigationRegion3D or node is NavigationLink3D or node is NavigationObstacle3D or node is NavigationAgent3D or node is Camera3D or node is Light3D or node is WorldEnvironment or node is AnimationPlayer or node is AnimationTree

func _prepare_surroundings(node: Node, terrain: ShaderMaterial, vegetation: ShaderMaterial) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is MeshInstance3D:
		var label := str(node.name).to_lower()
		var is_land := label.begins_with("context_ground") or label.begins_with("context_rock")
		node.material_override = terrain if is_land else vegetation
	for child in node.get_children():
		# Strip service nodes before entering the tree, even if a future export
		# accidentally adds a collision suffix, light, camera or navigation node.
		if _is_surroundings_service(child):
			child.free()
		else:
			_prepare_surroundings(child, terrain, vegetation)

func _read_cabin_footprint() -> void:
	for building: Dictionary in world_data.buildings:
		if str(building.name) == "Cabin":
			cabin_floor = float(building.floorHeight)
			for vertex: Array in building.outline:
				cabin_outline.append(Vector2(float(vertex[0]), float(vertex[2])))
			break

func is_safe_position(pos: Vector3) -> bool:
	# Only the actual house interior is safe. The terrace, store and roof are not.
	return pos.y >= cabin_floor - .35 and pos.y <= cabin_floor + 2.55 and Geometry2D.is_point_in_polygon(Vector2(pos.x, pos.z), cabin_outline)

func _inside_wolf_exclusion(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	if Geometry2D.is_point_in_polygon(p, cabin_outline):
		return true
	for i in cabin_outline.size():
		var closest := Geometry2D.get_closest_point_to_segment(p, cabin_outline[i], cabin_outline[(i + 1) % cabin_outline.size()])
		if p.distance_squared_to(closest) <= WOLF_CABIN_BUFFER * WOLF_CABIN_BUFFER:
			return true
	return false

func _create_wolf_navigation() -> void:
	var wolf_grid: Dictionary = world_data.grid.duplicate(true)
	for i in nav.size:
		if nav.valid(i) and _inside_wolf_exclusion(nav.point(i)):
			wolf_grid.blocked[i] = 1
	wolf_nav = NavScript.new()
	wolf_nav.setup(wolf_grid)
	exterior_rally_point = wolf_nav.point(wolf_nav.nearest(exterior_rally_point.x, exterior_rally_point.z, 3.0))
	wolf_nav.field(exterior_rally_point.x, exterior_rally_point.z)

func _reserve_shop_footprint(grid: Dictionary) -> void:
	# The kiosk is a new obstacle, so reserve its solid counter before links build.
	var grid_width := int(grid.width)
	var grid_cell := float(grid.cellSize)
	var ox := float(grid.origin[0])
	var oz := float(grid.origin[1])
	var x0 := floori((shop_position.x - 1.5 - ox) / grid_cell)
	var x1 := ceili((shop_position.x + 1.5 - ox) / grid_cell)
	var z0 := floori((shop_position.z - .8 - oz) / grid_cell)
	var z1 := ceili((shop_position.z + .8 - oz) / grid_cell)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := z * grid_width + x
			if i >= 0 and i < grid.blocked.size():
				grid.blocked[i] = 1

func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "CoastalAtmosphere"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://assets/environment/autumn_sky.gdshader")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.sky_rotation = Vector3.ZERO
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("78949d")
	environment.ambient_light_energy = .54
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("727d8e")
	environment.fog_light_energy = .65
	environment.fog_density = .006
	environment.fog_sky_affect = .08
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "AutumnMoonlight"
	sun.rotation_degrees = Vector3(-29, -35, 0)
	sun.light_color = Color("a4bbd1")
	sun.light_energy = .54
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 75.0
	sun.shadow_bias = .04
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	var sea := MeshInstance3D.new()
	sea.name = "CoastalSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800, 1800)
	sea.mesh = plane
	sea.position.y = -.14
	var sea_material := ShaderMaterial.new()
	sea_material.shader = preload("res://assets/environment/coastal_water.gdshader")
	sea.material_override = sea_material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

func _surface_material(terrain: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/environment/island_surface.gdshader")
	material.set_shader_parameter("terrain", terrain)
	material.set_shader_parameter("cabin_outline", cabin_outline)
	return material

func _prepare_model(node: Node, terrain: ShaderMaterial, buildings: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.mesh = preload("res://scripts/cabin_portal.gd").cut(mesh_instance.mesh,mesh_instance.global_transform)
		var original := mesh_instance.get_active_material(0)
		var is_glass := original is BaseMaterial3D and (original as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		if is_glass:
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(.77, .54, .27, .32)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.emission_enabled = true
			glass.emission = Color("dd9752")
			glass.emission_energy_multiplier = .26
			glass.roughness = .14
			glass.metallic = .12
			glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_instance.material_override = glass
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mesh_instance.material_override = terrain if str(node.name).begins_with("ground") else buildings
			var soft_cover: bool=["bush","shrub","foliage","canopy","grass"].any(func(word): return str(node.name).to_lower().contains(word))
			# The source batches already distinguish leafy scenery from solid wood/stone.
			var source_tags: Dictionary=node.get_meta("extras",{})
			if source_tags.get("gameClass","")=="scenery" and not source_tags.get("collision",false): soft_cover=true
			if mesh_instance.mesh != null and not soft_cover:
				var body := StaticBody3D.new()
				body.name = "BulletCollision"
				body.collision_layer = 1
				body.collision_mask = 0
				var shape := CollisionShape3D.new()
				shape.shape = mesh_instance.mesh.create_trimesh_shape()
				body.add_child(shape)
				mesh_instance.add_child(body)
	for child in node.get_children():
		_prepare_model(child, terrain, buildings)

func _create_foliage() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/foliage/canopies.json"))
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/foliage/leaves.gdshader")
	# Irregular native leaf sprays retain open birch silhouettes and broad color.
	var leaf_spray := _make_autumn_leaf_spray(material)
	var tiles: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 27613
	for cluster: Dictionary in data.clusters:
		var center := Vector3(float(cluster.center[0]), float(cluster.center[1]), float(cluster.center[2]))
		var radii := Vector3(float(cluster.radii[0]), float(cluster.radii[1]), float(cluster.radii[2]))
		var key := Vector2i(floori(center.x / 16), floori(center.z / 16))
		if not tiles.has(key):
			tiles[key] = []
		var rotation_euler := Vector3(rng.randf_range(-.3, .3), rng.randf() * TAU, rng.randf_range(-.2, .2))
		var basis := Basis.from_euler(rotation_euler).scaled(radii * Vector3(1.1, 1.0, 1.1))
		var brightness := .84 + rng.randf() * .16
		var green_variation := rng.randf_range(.77, 1.05)
		tiles[key].append([Transform3D(basis, center), Color(brightness, brightness * green_variation, brightness * .88)])
	for key: Vector2i in tiles:
		var cards: Array = tiles[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = leaf_spray
		multimesh.instance_count = cards.size()
		for i in cards.size():
			multimesh.set_instance_transform(i, cards[i][0])
			multimesh.set_instance_color(i, cards[i][1])
		var batch := MultiMeshInstance3D.new()
		batch.name = "BirchCanopy_%d_%d" % [key.x, key.y]
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		leaf_batches.append(batch)

func _make_autumn_leaf_spray(material: Material) -> ArrayMesh:
	# A shared spray of angular birch leaves; no images or solid crown blobs.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 48931
	var palette := [Color("b9983b"), Color("be7c35"), Color("9c522d"), Color("c7a153"), Color("888044")]
	var outline: Array[Vector2] = [Vector2(0, -.65), Vector2(-.38, -.24), Vector2(-.45, .16), Vector2(-.24, .44), Vector2(0, .56), Vector2(.26, .4), Vector2(.46, .1), Vector2(.36, -.27)]
	for i in 36:
		var angle := i * 2.39996
		var y := float(i) / 35.0 * 1.7 - .85
		var radius := sqrt(maxf(.05, 1.0 - y * y)) * rng.randf_range(.55, 1.0)
		var center := Vector3(cos(angle) * radius, y, sin(angle) * radius)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-1.3, 1.3), angle, rng.randf_range(-.8, .8)))
		var leaf_size := rng.randf_range(.28, .43)
		var tint: Color = palette[i % palette.size()]
		var ridge := center + basis * Vector3(0, 0, .025)
		for k in outline.size():
			var p := outline[k] * leaf_size
			var q := outline[(k + 1) % outline.size()] * leaf_size
			var a := center + basis * Vector3(p.x, p.y, 0)
			var b := center + basis * Vector3(q.x, q.y, 0)
			var normal := (a - ridge).cross(b - ridge).normalized()
			for vertex: Vector3 in [ridge, a, b]:
				vertices.append(vertex)
				normals.append(normal)
				colors.append(tint)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var leaf_mesh := ArrayMesh.new()
	leaf_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	leaf_mesh.surface_set_material(0, material)
	return leaf_mesh

func _solid_material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = metallic
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material

func _shop_box(label_text: String, dimensions: Vector3, pos: Vector3, material: Material, collision: bool = true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label_text
	var box := BoxMesh.new()
	box.size = dimensions
	instance.mesh = box
	instance.material_override = material
	instance.position = pos
	shop.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = dimensions
		shape.shape = box_shape
		body.add_child(shape)
		instance.add_child(body)
	return instance

func _create_shop() -> void:
	shop = Node3D.new()
	shop.name = "WeaponStore"
	shop.position = shop_position
	add_child(shop)
	var wood := _solid_material(Color("5d4931"))
	var dark := _solid_material(Color("142629"), .35)
	var teal := _solid_material(Color("37616b"), .0)
	var gold := _solid_material(Color("f4c467"))
	_shop_box("SupplyCounter", Vector3(2.8, .90, 1.15), Vector3(0, .45, 0), wood)
	_shop_box("CounterTop", Vector3(3.0, .10, 1.35), Vector3(0, .94, 0), dark)
	_shop_box("RearRack", Vector3(2.75, 1.25, .10), Vector3(0, 1.60, -.51), dark)
	for x in [-1.38, 1.38]:
		_shop_box("CanopyPost", Vector3(.12, 2.75, .12), Vector3(x, 1.375, -.53), wood)
	_shop_box("StoreCanopy", Vector3(3.15, .18, 1.60), Vector3(0, 2.78, -.15), teal)
	_shop_box("SignBoard", Vector3(2.85, .52, .12), Vector3(0, 2.40, .56), dark)
	_shop_box("GoldTrim", Vector3(2.85, .035, .13), Vector3(0, 2.135, .565), gold, false)
	var title := Label3D.new()
	title.name = "StoreSign"
	title.text = "ISLAND ARMORY"
	title.font_size = 64
	title.pixel_size = .0054
	title.modulate = Color("f5dc9c")
	title.outline_size = 5
	title.position = Vector3(0, 2.40, .63)
	title.no_depth_test = false
	shop.add_child(title)
	var instruction := Label3D.new()
	instruction.name = "StoreInstruction"
	instruction.text = "[ E ]  WEAPONS & SUPPLIES"
	instruction.font_size = 46
	instruction.pixel_size = .0037
	instruction.modulate = Color("bfeee6")
	instruction.position = Vector3(0, .48, .584)
	shop.add_child(instruction)
	# Readable silhouettes on the store's back wall match the equipment for sale.
	for i in 3:
		var x := -.85 + i * .84
		var gun := _shop_box("DisplayWeapon", Vector3(.55, .12, .12), Vector3(x, 1.66, -.40), gold, false)
		gun.rotation.z = .18
		_shop_box("DisplayGrip", Vector3(.13, .26, .10), Vector3(x + .12, 1.51, -.38), wood, false)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.1, .6)
	lamp.light_color = Color("ffd68c")
	lamp.light_energy = 1.35
	lamp.omni_range = 4
	shop.add_child(lamp)

func _create_shelter_lighting() -> void:
	var shelter := Node3D.new()
	shelter.name = "WarmCabinShelter"
	add_child(shelter)
	var porch_lamp := OmniLight3D.new()
	porch_lamp.name = "WelcomingPorchLight"
	porch_lamp.position = Vector3(-.55, 5.8, 4.45)
	porch_lamp.light_color = Color("ffc584")
	porch_lamp.light_energy = 1.7
	porch_lamp.omni_range = 4.2
	porch_lamp.omni_attenuation = 1.7
	shelter.add_child(porch_lamp)
	for lamp_position in [Vector3(-1.85, 5.55, 1.45), Vector3(-4.1, 5.5, 1.5), Vector3(-6.3, 5.4, .3)]:
		var lamp := OmniLight3D.new()
		lamp.position = lamp_position
		lamp.light_color = Color("ffd298")
		lamp.light_energy = 2.6
		lamp.omni_range = 4.8
		lamp.omni_attenuation = 1.4
		lamp.shadow_enabled = false
		shelter.add_child(lamp)
	var lantern := MeshInstance3D.new()
	lantern.name = "ShelterLantern"
	lantern.position = Vector3(-1.85, 5.55, 1.45)
	var body := CylinderMesh.new()
	body.top_radius = .13
	body.bottom_radius = .11
	body.height = .3
	body.radial_segments = 6
	lantern.mesh = body
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("e6bb76")
	glow.emission_enabled = true
	glow.emission = Color("e7a654")
	glow.emission_energy_multiplier = .7
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lantern.material_override = glow
	shelter.add_child(lantern)
	for offset_y in [-.18, .18]:
		var cap := MeshInstance3D.new()
		cap.position = lantern.position + Vector3(0, offset_y, 0)
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = .18
		cap_mesh.bottom_radius = .18
		cap_mesh.height = .07
		cap_mesh.radial_segments = 6
		cap.mesh = cap_mesh
		cap.material_override = _solid_material(Color("25313a"))
		shelter.add_child(cap)

func _bed_box(parent: Node3D, label_text: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label_text
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _create_cabin_bed() -> void:
	# The source bedroom already has a furniture footprint. Dress that footprint
	# as the recovery bed and keep its existing walkable aisle completely open.
	var bed := Node3D.new()
	bed.name = "RecoveryBed"
	bed.position = Vector3(-5.15, cabin_floor, 3.43)
	bed.rotation.y = .20
	add_child(bed)
	var timber := _solid_material(Color("493329"))
	var linen := _solid_material(Color("d2c2a5"))
	var blanket := _solid_material(Color("4c6563"))
	var stripe := _solid_material(Color("9d8861"))
	_bed_box(bed, "BedFrame", Vector3(2.05, .20, 1.17), Vector3(0, .32, 0), timber)
	_bed_box(bed, "Mattress", Vector3(1.94, .19, 1.09), Vector3(0, .51, 0), linen)
	_bed_box(bed, "WoolBlanket", Vector3(1.47, .075, 1.12), Vector3(-.20, .64, 0), blanket)
	_bed_box(bed, "BlanketFold", Vector3(.16, .035, 1.12), Vector3(.47, .692, 0), stripe)
	for x in [-.77, -.52, -.27]:
		_bed_box(bed, "BlanketWovenStripe", Vector3(.045, .006, 1.125), Vector3(x, .681, 0), stripe)
	_bed_box(bed, "Pillow", Vector3(.42, .12, .78), Vector3(.66, .67, 0), linen)
	_bed_box(bed, "Headboard", Vector3(.10, 1.06, 1.27), Vector3(1.035, .61, 0), timber)
	_bed_box(bed, "Footboard", Vector3(.085, .55, 1.23), Vector3(-1.04, .34, 0), timber)
	for x in [-.90, .90]:
		for z in [-.49, .49]:
			_bed_box(bed, "BedLeg", Vector3(.12, .3, .12), Vector3(x, .15, z), timber)
	var lamp := OmniLight3D.new()
	lamp.name = "BedsideWarmLight"
	lamp.position = Vector3(-5.8, 5.45, 3.15)
	lamp.light_color = Color("ffd39b")
	lamp.light_energy = 1.4
	lamp.omni_range = 3.0
	add_child(lamp)

func _create_chimney_smoke() -> void:
	# The photo-backed masonry chimney is at cabin-local (8.665, 2.5).
	# Transform from the original footprint: its cap ends at world height 7.105.
	var smoke := MultiMeshInstance3D.new()
	smoke.name = "ChimneySmoke"
	smoke.position = Vector3(1.17718, 7.105, .40941)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/environment/chimney_smoke.gdshader")
	var card := QuadMesh.new()
	card.size = Vector2(.85, .85)
	card.material = material
	var puffs := MultiMesh.new()
	puffs.transform_format = MultiMesh.TRANSFORM_3D
	puffs.use_custom_data = true
	puffs.mesh = card
	puffs.instance_count = 18
	for i in puffs.instance_count:
		puffs.set_instance_transform(i, Transform3D.IDENTITY)
		puffs.set_instance_custom_data(i, Color(float(i) / 18.0, float(i % 5) / 5.0, 0, 1))
	smoke.multimesh = puffs
	smoke.custom_aabb = AABB(Vector3(-2, 0, -2), Vector3(7, 9, 7))
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)

func set_quality(high_quality: bool) -> void:
	sun.shadow_enabled = high_quality
	for batch in leaf_batches:
		batch.visible = high_quality
