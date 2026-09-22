extends RefCounted
## Finite-radius sweep plus a sampled terrain safety net for mesh seams.
static func sweep(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3, exclude: Array[RID], nav: RefCounted = null) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(start,finish,3)
	ray.collide_with_areas=true; ray.hit_back_faces=true; ray.hit_from_inside=true; ray.exclude=exclude
	var hit := space.intersect_ray(ray)
	var sphere := SphereShape3D.new(); sphere.radius=.10
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=sphere; query.transform=Transform3D(Basis.IDENTITY,start)
	query.motion=finish-start; query.collision_mask=3; query.collide_with_areas=true; query.exclude=exclude
	var fractions := space.cast_motion(query)
	if fractions.size()==2 and fractions[0]<1:
		var center := start.lerp(finish,fractions[0])
		query.transform.origin=start.lerp(finish,minf(1,fractions[1]+.002)); query.motion=Vector3.ZERO
		var rest := space.get_rest_info(query)
		var normal: Vector3=rest.get("normal",(start-finish).normalized())
		if hit.is_empty() or start.distance_to(center)<start.distance_to(hit.position):
			hit={"position":center,"normal":normal,"sphere_contact":true}
	if not hit.is_empty(): return hit
	if nav:
		for i in range(1,maxi(1,ceili(start.distance_to(finish)/.15))+1):
			var p := start.lerp(finish,float(i)/maxi(1,ceili(start.distance_to(finish)/.15)))
			var floor_y: float=nav.height_at(p.x,p.z)
			if not is_nan(floor_y) and p.y<=floor_y+.10 and start.y>=floor_y-.5:
				return {"position":Vector3(p.x,floor_y+.11,p.z),"normal":Vector3.UP,"sphere_contact":true}
	return {}
