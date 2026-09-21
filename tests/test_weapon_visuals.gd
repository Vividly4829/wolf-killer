extends SceneTree
const Visual=preload("res://scripts/weapon_visual.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	call_deferred("run_checks")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition: failures.append(message)
func run_checks() -> void:
	var visual:=Visual.new()
	root.add_child(visual)
	visual.set_inspection_mode(true)
	var mesh_counts: Array[int]=[]
	for index: int in 18:
		visual.build(index)
		var bounds:=visual.get_model_bounds()
		check(bounds.size.is_finite() and bounds.size.length()>.15,"Model %d has finite visible geometry"%index)
		check(int(visual.model_meta.source_meshes)>45 and int(visual.model_meta.mesh_count)<60,"Model %d retains detailed parts with bounded batched draw meshes"%index)
		check(int(visual.model_meta.triangles)==int(visual.model_meta.source_triangles),"Model %d preserves every source triangle when custom and primitive meshes are batched"%index)
		mesh_counts.append(int(visual.model_meta.mesh_count))
		var changed:=false
		for p: float in [.1,.25,.52,.75,.95]:
			visual.animate_reload(p,true)
			for key: String in visual._actions:
				var node: Node3D=visual._actions[key]
				check(node.transform.is_finite(),"Model %d action %s has a finite loading pose"%[index,key])
				changed=changed or not node.transform.is_equal_approx(node.get_meta("rest"))
		check(changed,"Model %d animates its actual loading mechanism"%index)
		visual.animate_reload(1.0,false)
		visual.set_loaded(true)
		visual.flash()
		if index==3:
			check(not visual._flash_mesh.visible and not visual._actions.bolt.visible and visual._actions.string.scale.z<.1,"Crossbow releases a real bolt/string with no gunfire flash")
		else:
			visual.set_inspection_mode(false)
			visual.flash()
			check(visual._flash_mesh.visible,"Firearm %d flashes when fired"%index)
			visual.set_inspection_mode(true)
		if index==9:
			var primary: Vector3=visual.muzzle_position
			visual.set_secondary(true)
			check(visual.muzzle_position.y<primary.y,"LeMat selector moves its muzzle effect to the separate shotgun bore")
			var cylinder_pose: Transform3D=visual._actions.cylinder.transform
			visual.animate_cycle(.5)
			check(visual._actions.cylinder.transform.is_equal_approx(cylinder_pose),"LeMat central shotgun firing does not index the nine-shot cylinder")
			visual.animate_reload(.6,true)
			check(visual._actions.secondary_ramrod.visible and is_zero_approx(visual._actions.cylinder.rotation.z),"LeMat secondary reload rams the central bore while keeping the cylinder locked")
		await process_frame
	visual.queue_free()
	await process_frame
	await process_frame
	for failure: String in failures: push_error(failure)
	print("%s: %d weapon visual checks. Batched model meshes: %s"%["PASS" if failures.is_empty() else "FAIL",checks,str(mesh_counts)])
	quit(0 if failures.is_empty() else 1)
