extends RefCounted
## Resolve firearm gravity through swept segments; the review uses these same hits.
static func cast(space: PhysicsDirectSpaceState3D,origin: Vector3,direction: Vector3,spec: Dictionary,exclude: Array[RID]) -> Dictionary:
	var flight=preload("res://scripts/shot_path.gd").new()
	flight.begin(origin,direction,spec)
	var point:=origin
	var velocity:=direction*float(spec.get("bullet_speed",300.0))
	var gravity:=Vector3.ZERO if spec.get("laser",false) else Vector3.DOWN*9.8
	var hit: Dictionary={}
	for step in 256:
		var remaining: float=float(spec.range)-flight.travelled
		if remaining<.0001: break
		var dt:=minf(1.5,remaining)/maxf(1,velocity.length())
		var next:=point+velocity*dt+gravity*.5*dt*dt
		if gravity==Vector3.ZERO: next=origin+direction*float(spec.range)
		var segment:=point.distance_to(next)
		if segment>remaining: next=point.lerp(next,remaining/segment)
		var query:=PhysicsRayQueryParameters3D.create(point,next,3)
		query.collide_with_areas=true; query.exclude=exclude
		hit=space.intersect_ray(query)
		var endpoint: Vector3=hit.position if not hit.is_empty() else next
		flight.append(endpoint,dt*point.distance_to(endpoint)/maxf(segment,.000001))
		velocity+=gravity*dt
		if not hit.is_empty(): break
		point=next
	return {"hit":hit,"direction":velocity.normalized(),"path":flight.report("MISS / WEAPON RANGE LIMIT" if hit.is_empty() else "IMPACT / NO ANIMAL HIT")}
