extends SceneTree
## Additive context regression; no saves or live game instances are touched.

const World = preload("res://scripts/island_world.gd")
const PROTECTED_FILES := {
	"res://assets/island-realistic.glb": "b1608663daa9d03a014a6335f6670ea44178a132383b88662e82ba27832ab471",
	"res://assets/world.json": "4773174eb25a3625ebc7e222bd86ec6e26a8abaeb8d75cecdad20f5fd50359f9",
	"res://assets/foliage/canopies.json": "bed242b38025fe0db04a2f9d480a6f2ade6288861f79d22801f1ddff02a9e62a",
	"res://../game/assets/island.glb": "9bdd5165efd04980b7063cde3ed7f00ec8dd3c56df6480910a885b7877f742bd",
	"res://../game/assets/island-realistic.glb": "95dd847619f9e89b89af454b1100a1ee56db26d5d4105f99d6bd87b0123857e8",
	"res://../game/assets/world.json": "4773174eb25a3625ebc7e222bd86ec6e26a8abaeb8d75cecdad20f5fd50359f9",
	"res://../game/assets/foliage/canopies.json": "bed242b38025fe0db04a2f9d480a6f2ade6288861f79d22801f1ddff02a9e62a",
}

class OriginalWorld extends "res://scripts/island_world.gd":
	func _create_surroundings() -> void:
		pass

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	for path: String in PROTECTED_FILES:
		var absolute := ProjectSettings.globalize_path(path).simplify_path()
		check(FileAccess.file_exists(absolute), "Protected asset exists: " + path)
		if FileAccess.file_exists(absolute):
			check(FileAccess.get_sha256(absolute) == PROTECTED_FILES[path], "Original asset remains byte-identical: " + path)
	check(ResourceLoader.exists(World.SURROUNDINGS_PATH), "The separate surroundings asset is imported")
	if not ResourceLoader.exists(World.SURROUNDINGS_PATH):
		finish()
		return
	print("SURROUNDINGS_ASSET_SHA256: " + FileAccess.get_sha256(World.SURROUNDINGS_PATH))
	var imported := (load(World.SURROUNDINGS_PATH) as PackedScene).instantiate() as Node3D
	check(imported != null and imported.transform == Transform3D.IDENTITY, "The exported context already uses an identity Godot root transform")
	if imported:
		imported.free()

	# Construct the unchanged world first, then compare the same implementation
	# with only its new surroundings loading hook enabled.
	var original := OriginalWorld.new()
	root.add_child(original)
	var baseline := snapshot(original)
	original.queue_free()
	await process_frame
	var world := World.new()
	root.add_child(world)
	await process_frame
	var current := snapshot(world)
	for key: String in baseline:
		check(current[key] == baseline[key], "Adding context preserves " + key)

	check(is_instance_valid(world.surroundings), "The world contains its separate surroundings node")
	if not is_instance_valid(world.surroundings):
		world.queue_free()
		await process_frame
		finish()
		return
	var context: Node3D = world.surroundings
	check(context.transform == Transform3D.IDENTITY and context.global_transform == Transform3D.IDENTITY, "Context uses the original metre coordinates without an extra transform")
	check(not context.get_meta("visual_only", true), "Neighboring context supports exploration")
	check(context.process_mode == Node.PROCESS_MODE_DISABLED, "Imported context has no running gameplay or animation process")
	for type_name in ["NavigationRegion3D", "NavigationLink3D", "NavigationObstacle3D", "NavigationAgent3D", "Camera3D", "Light3D", "WorldEnvironment", "AnimationPlayer", "AnimationTree"]:
		check(context.find_children("*", type_name, true, false).is_empty(), "Context introduces no " + type_name)
	var before_count := world.get_child_count()
	world._create_surroundings()
	check(world.get_child_count() == before_count and world.surroundings == context, "Repeated loading cannot duplicate neighboring surfaces")

	var existing_materials: Array[Material] = []
	for mesh: MeshInstance3D in world.get_node("OriginalIsland").find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override != null and not existing_materials.has(mesh.material_override):
			existing_materials.append(mesh.material_override)
	var meshes := context.find_children("*", "MeshInstance3D", true, false)
	if context is MeshInstance3D:
		meshes.append(context)
	check(not meshes.is_empty(), "Context contains visible mesh geometry")
	var bounds := AABB()
	var has_bounds := false
	var all_vertex_colors := true
	var all_materials_independent := true
	var all_categories_valid := true
	var all_shadows_off := true
	var all_vertices_finite := true
	var total_vertices := 0
	var total_triangles := 0
	var neighbor_probes: Dictionary = {}
	for mesh: MeshInstance3D in meshes:
		all_shadows_off = all_shadows_off and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := mesh.material_override as ShaderMaterial
		all_materials_independent = all_materials_independent and material != null and not existing_materials.has(material)
		var label := str(mesh.name).to_lower()
		var is_land := label.begins_with("context_ground") or label.begins_with("context_rock")
		var recognized := is_land or label.begins_with("context_timber") or label.begins_with("context_foliage")
		all_categories_valid = all_categories_valid and recognized
		if material:
			all_categories_valid = all_categories_valid and bool(material.get_shader_parameter("terrain")) == is_land
		if mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		bounds = bounds.merge(box) if has_bounds else box
		has_bounds = true
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			total_vertices += vertices.size()
			total_triangles += int((vertices.size() if indices.is_empty() else indices.size()) / 3.0)
			all_vertex_colors = all_vertex_colors and colors.size() == vertices.size()
			for index in range(0, vertices.size(), maxi(1, int(vertices.size() / 32.0))):
				var point: Vector3 = mesh.global_transform * vertices[index]
				all_vertices_finite = all_vertices_finite and point.is_finite()
				if world.nav.at(point.x, point.z) < 0:
					neighbor_probes[Vector2i(roundi(point.x), roundi(point.z))] = point
	check(has_bounds and bounds.size.length() > 5.0 and total_triangles > 0, "Neighboring land has nonzero spatial extent and triangles")
	check(all_vertices_finite, "Context bounds and sampled vertices contain finite coordinates")
	check(all_vertex_colors, "Imported context retains COLOR_0 for the existing surface shader")
	check(all_materials_independent, "Context owns new materials rather than mutating island materials")
	check(all_categories_valid, "Context material batches use their intended terrain or vegetation treatment")
	check(all_shadows_off, "Distant context does not add shadow passes")
	check(neighbor_probes.size() >= 3, "Actual context vertices supply off-island navigation probes")
	for point: Vector3 in neighbor_probes.values():
		check(not world.is_safe_position(point), "Neighboring land does not become a safe zone")
	check(world.nav.reachable.size() > 100000, "Coastal navigation is connected to the island")
	print("SURROUNDINGS: meshes=%d vertices=%d triangles=%d bounds=%s neighbor_probes=%d" % [meshes.size(), total_vertices, total_triangles, bounds, neighbor_probes.size()])
	world.queue_free()
	await process_frame
	finish()

func snapshot(world: Node3D) -> Dictionary:
	var island: Node3D = world.get_node("OriginalIsland")
	var mesh_state: Dictionary = {}
	for mesh: MeshInstance3D in island.find_children("*", "MeshInstance3D", true, false):
		mesh_state[str(island.get_path_to(mesh))] = [mesh.transform, mesh.mesh.get_aabb(), mesh.mesh.get_surface_count()]
	var foliage: Dictionary = {}
	for batch: MultiMeshInstance3D in world.leaf_batches:
		foliage[str(batch.name)] = [batch.transform, batch.multimesh.instance_count, batch.multimesh.mesh.get_aabb()]
	var sea := world.get_node("CoastalSea") as MeshInstance3D
	var atmosphere := world.get_node("CoastalAtmosphere") as WorldEnvironment
	return {
		"original_island_transform": island.transform,
		"original_island_meshes": mesh_state,
		"world_metadata": world.world_data.duplicate(true),
		"navigation_dimensions": [world.nav.origin, world.nav.width, world.nav.depth, world.nav.cell_size],
		"navigation_heights": world.nav.heights.duplicate(),
		"navigation_obstacles": world.nav.blocked.duplicate(),
		"navigation_links": world.nav.links.duplicate(),
		"navigation_reachable": world.nav.reachable.duplicate(),
		"wolf_obstacles": world.wolf_nav.blocked.duplicate(),
		"wolf_links": world.wolf_nav.links.duplicate(),
		"wolf_reachable": world.wolf_nav.reachable.duplicate(),
		"safe_cabin_footprint": world.cabin_outline.duplicate(),
		"spawn_and_recovery": [world.spawn_position, world.spawn_yaw, world.bed_position, world.bed_wake_position, world.exterior_rally_point],
		"original_foliage_batches": foliage,
		"existing_collision_count": island.find_children("*", "StaticBody3D", true, false).size(),
		"sea_and_atmosphere": [sea.transform, sea.mesh.size, atmosphere.environment.fog_density, atmosphere.environment.ambient_light_energy, world.sun.transform, world.sun.light_energy],
	}

func check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures.append(description)

func finish() -> void:
	for failure in failures:
		push_error(failure)
	print("%s: %d additive surroundings checks; %d failed." % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
