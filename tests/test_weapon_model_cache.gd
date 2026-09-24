extends SceneTree

const Builder = preload("res://scripts/weapon_model_builder.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node as MeshInstance3D)
	for child: Node in node.get_children(): result.append_array(meshes(child))
	return result

func cache_has_live_node(value: Variant) -> bool:
	if value is Node: return true
	if value is Dictionary:
		for key: Variant in value:
			if cache_has_live_node(key) or cache_has_live_node(value[key]): return true
	elif value is Array:
		for item: Variant in value:
			if cache_has_live_node(item): return true
	return false

func run_checks() -> void:
	var builder := Builder.new()
	var cold_usec := 0
	var warm_usec := 0
	for index: int in preload("res://scripts/weapon_catalog.gd").WEAPONS.size():
		var start := Time.get_ticks_usec()
		var cold: Dictionary = builder.build(index)
		cold_usec += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		var warm: Dictionary = builder.build(index)
		warm_usec += Time.get_ticks_usec() - start
		var original: Node3D = cold.root
		var instance: Node3D = warm.root
		check(original != instance and not original.is_inside_tree() and not instance.is_inside_tree(), "Weapon %d returns independently owned unattached roots" % index)
		var equivalent := true
		for key: String in ["muzzle", "secondary_muzzle", "action", "name", "mesh_count", "source_meshes", "source_triangles", "triangles"]:
			equivalent = equivalent and cold[key] == warm[key]
		check(equivalent and int(warm.triangles) == int(warm.source_triangles), "Weapon %d preserves its complete mesh/triangle/mechanism metadata" % index)
		var originals := meshes(original)
		var instances := meshes(instance)
		var shared := originals.size() == instances.size()
		var geometry_equal := shared
		for i: int in originals.size():
			shared = shared and originals[i] != instances[i] and originals[i].mesh == instances[i].mesh
			geometry_equal = geometry_equal and originals[i].transform.is_equal_approx(instances[i].transform) and originals[i].get_aabb() == instances[i].get_aabb()
			for surface: int in originals[i].mesh.get_surface_count():
				shared = shared and originals[i].get_active_material(surface) == instances[i].get_active_material(surface)
		check(shared and geometry_equal, "Weapon %d shares exact mesh/material resources while retaining geometry and transforms" % index)
		var independent: bool = cold.actions.size() == warm.actions.size()
		for key: String in cold.actions:
			var a: Node3D = cold.actions[key]
			var b: Node3D = warm.actions[key]
			independent = independent and a != b and a.get_meta("rest") == b.get_meta("rest") and a.visible == b.visible
			var rest: Transform3D = b.transform
			var visibility := b.visible
			a.rotate_x(.4)
			a.visible = not a.visible
			independent = independent and b.transform == rest and b.visible == visibility
		check(independent, "Weapon %d has isolated action transforms, visibility and rest metadata" % index)
		var original_ref: WeakRef = weakref(original)
		original.free()
		instance.free()
		var later: Dictionary = builder.build(index)
		var restored := original_ref.get_ref() == null
		for key: String in later.actions:
			var node: Node3D = later.actions[key]
			restored = restored and node.transform.is_equal_approx(node.get_meta("rest"))
		check(restored, "Weapon %d remains buildable after original roots are freed, with pristine actions" % index)
		(later.root as Node3D).free()
	check(Builder._model_cache.size() == preload("res://scripts/weapon_catalog.gd").WEAPONS.size() and not cache_has_live_node(Builder._model_cache), "The bounded cache retains serialized resources and no live node templates")
	var orphan_count := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	Builder._model_cache.erase(9)
	Builder.warm_cache()
	check(Builder._model_cache.size() == preload("res://scripts/weapon_catalog.gd").WEAPONS.size() and int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_count, "Warm-up builds a missing model and frees its temporary procedural node hierarchy")
	Builder.warm_cache()
	check(Builder._model_cache.size() == preload("res://scripts/weapon_catalog.gd").WEAPONS.size() and int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_count, "Repeated warm-up is idempotent and retains no extra orphan nodes")
	var lemat_times: Array[int] = []
	for iteration: int in 25:
		var start := Time.get_ticks_usec()
		var model: Dictionary = Builder.new().build(9)
		lemat_times.append(Time.get_ticks_usec() - start)
		(model.root as Node3D).free()
	lemat_times.sort()
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_count, "Repeated warm LeMat builds free every independently created node")
	for failure: String in failures: push_error(failure)
	print("CACHE_TIMING: cold total %.2f ms; warm total %.2f ms; repeated LeMat median %.3f ms" % [cold_usec / 1000.0, warm_usec / 1000.0, lemat_times[12] / 1000.0])
	print("%s: %d weapon model cache checks." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
