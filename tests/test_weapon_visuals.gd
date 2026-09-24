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
	for index: int in preload("res://scripts/weapon_catalog.gd").WEAPONS.size():
		visual.build(index)
		var bounds:=visual.get_model_bounds()
		check(bounds.size.is_finite() and bounds.size.length()>.15,"Model %d has finite visible geometry"%index)
		check(int(visual.model_meta.source_meshes)>5 and int(visual.model_meta.mesh_count)<80,"Model %d retains detailed parts with bounded batched draw meshes"%index)
		check(int(visual.model_meta.triangles)==int(visual.model_meta.source_triangles),"Model %d preserves every source triangle when custom and primitive meshes are batched"%index)
		mesh_counts.append(int(visual.model_meta.mesh_count))
		var changed:=false
		for p: float in [.1,.25,.52,.75,.95]:
			visual.animate_reload(p,true)
			for key: String in visual._actions:
				var node: Node3D=visual._actions[key]
				check(node.transform.is_finite(),"Model %d action %s has a finite loading pose"%[index,key])
				changed=changed or not node.transform.is_equal_approx(node.get_meta("rest"))
		if index not in range(18,26): check(changed,"Model %d animates its actual loading mechanism"%index)
		visual.animate_reload(1.0,false)
		visual.set_loaded(true)
		visual.flash()
		if index==3:
			check(not visual._flash_mesh.visible and not visual._actions.bolt.visible and visual._actions.string.scale.z<.1,"Crossbow releases a real bolt/string with no gunfire flash")
		elif index not in range(18,27):
			visual.set_inspection_mode(false)
			visual.flash()
			check(visual._flash_mesh.visible,"Firearm %d flashes when fired"%index)
			visual.set_inspection_mode(true)
		if index in [18,19,24,25]: check(not visual._offhand.visible,"One-handed equipment hides unsupported offhand")
		if index in [21,22,23]:
			visual.set_loaded(false); check(not visual._actions.arrow.visible,"Empty bow hides nocked arrow")
			visual.set_loaded(true); check(visual._actions.arrow.visible,"Loaded bow shows nocked arrow")
		if index in [30,31,32]:
			visual.animate_reload(.52,true)
			check(visual._main_hand.position.distance_to(visual._actions.naval_right.transform*Vector3(.016,-.050,.037))<.001,"Dual reload keeps right hand on grip")
			check(visual._offhand.position.distance_to(visual._actions.naval_left.transform*Vector3(-.016,-.050,.037))<.001,"Dual reload keeps left hand on grip")
			visual.animate_reload(1,false)
		if index==31:
			check(is_equal_approx(visual.model_meta.sight.x,.16),"Dual blunderbuss initially sights along right barrel")
			visual.set_dual_ammo(1); check(visual.muzzle_position.x<0 and visual.model_meta.sight.x<0,"Dual blunderbuss switches muzzle and sight to left hand")
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
