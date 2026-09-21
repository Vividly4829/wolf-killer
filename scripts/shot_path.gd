extends RefCounted
## Actual combat samples, shared by local and host-authoritative shot reviews.
var points := PackedVector3Array()
var times := PackedFloat32Array()
var duration := 0.0
var direction := Vector3.FORWARD
var travelled := 0.0
var weapon := ""
var limit := 0.0
var curved := false
var projectile := false
func begin(origin: Vector3, heading: Vector3, spec: Dictionary) -> void:
	points = PackedVector3Array([origin])
	times=PackedFloat32Array([0.0]); duration=0.0
	direction = heading.normalized()
	weapon = str(spec.name)
	limit = float(spec.range)
	projectile = float(spec.projectile_speed)>0
	curved = projectile or not spec.get("laser",false)
func append(point: Vector3, seconds: float = 0.0) -> void:
	travelled += points[-1].distance_to(point)
	duration+=maxf(0,seconds); times.append(duration)
	points.append(point)
	if points.size()>64:
		var reduced := PackedVector3Array()
		var reduced_times:=PackedFloat32Array()
		for i in range(0,points.size()-1,2): reduced.append(points[i]); reduced_times.append(times[i])
		reduced.append(points[-1])
		reduced_times.append(times[-1]); times=reduced_times
		points = reduced
func report(outcome: String, complete: bool = true) -> Dictionary:
	var offset := points[-1]-points[0]
	var ground_range := Vector2(offset.x,offset.z).length()
	var horizontal_heading := Vector2(direction.x,direction.z).length()
	var drop := direction.y*ground_range/horizontal_heading-offset.y if horizontal_heading>.01 else 0.0
	return {"points":points.duplicate(),"times":times.duplicate(),"duration":duration,"direction":direction,"travelled":travelled,
		"distance":offset.length(),"ground_range":ground_range,"drop":drop,
		"weapon":weapon,"limit":limit,"curved":curved,"projectile":projectile,"outcome":outcome,"complete":complete}
