extends RefCounted
## Original, deliberately simplified game anatomy in an adult wolf's local metres.
## The same volumes drive damage AND the shot-review drawing.
const ORGANS := [
	{"id":"brain", "center":Vector3(0,.91,.60), "radii":Vector3(.055,.055,.075), "multiplier":4.0, "bleed":0.0},
	{"id":"spine", "center":Vector3(0,.80,-.06), "radii":Vector3(.055,.055,.55), "multiplier":2.5, "bleed":2.0},
	{"id":"heart", "center":Vector3(0,.46,.25), "radii":Vector3(.075,.09,.095), "multiplier":3.0, "bleed":18.0},
	{"id":"left lung", "center":Vector3(.115,.61,.12), "radii":Vector3(.105,.17,.28), "multiplier":1.55, "bleed":6.0},
	{"id":"right lung", "center":Vector3(-.115,.61,.12), "radii":Vector3(.105,.17,.28), "multiplier":1.55, "bleed":6.0},
	{"id":"liver", "center":Vector3(0,.50,-.24), "radii":Vector3(.17,.13,.15), "multiplier":1.25, "bleed":4.0}
]

static func intersect_ellipsoid(start: Vector3, direction: Vector3, center: Vector3, radii: Vector3, length: float) -> float:
	var p := (start-center)/radii
	var d := direction/radii
	var a := d.dot(d)
	var b := 2.0*p.dot(d)
	var c := p.dot(p)-1.0
	var discriminant := b*b-4.0*a*c
	if discriminant < 0.0 or a < .000001: return INF
	var enter := (-b-sqrt(discriminant))/(2.0*a)
	var leave := (-b+sqrt(discriminant))/(2.0*a)
	if leave < 0.0 or enter > length: return INF
	return maxf(0.0, enter)

static func trace(entry: Vector3, direction: Vector3, penetration: float, surface_zone: String) -> Dictionary:
	# Stop the displayed path at the skin exit, using the same capsule/sphere
	# dimensions as the outer hit areas. Energy can also stop it before the exit.
	if surface_zone in ["body", "head"]:
		var last_inside := 0.0
		var entered := false
		for step in range(1,ceili(penetration/.01)+1):
			var t := minf(penetration,step*.01)
			var p := entry+direction*t
			var axis := Vector3(0,.57,clampf(p.z,-.435,.475))
			if p.distance_squared_to(axis) <= .27*.27 or p.distance_squared_to(Vector3(0,.86,.55)) <= .3*.3:
				last_inside = t; entered=true
			elif entered: break
		penetration = last_inside
	var hits: Array[Dictionary] = []
	# Limb hits remain localized: an internal organ behind the body is not
	# magically hit when the bullet first strikes an isolated lower leg.
	if surface_zone in ["body", "head"]:
		for organ: Dictionary in ORGANS:
			var t := intersect_ellipsoid(entry, direction, organ.center, organ.radii, penetration)
			if is_finite(t): hits.append({"id":organ.id, "distance":t, "multiplier":organ.multiplier, "bleed":organ.bleed})
	hits.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.distance < b.distance)
	var names: Array[String] = []
	var multiplier := .7 if surface_zone == "body" else 1.0
	var bleed := .5 if surface_zone == "body" else 0.0
	for hit: Dictionary in hits:
		names.append(hit.id)
		multiplier = maxf(multiplier,float(hit.multiplier))
		bleed += float(hit.bleed)
	return {"entry":entry, "end":entry+direction*penetration, "organs":names, "zone":surface_zone, "multiplier":multiplier, "bleed":bleed}

static func tissue_length(entry: Vector3,direction: Vector3,limit: float,regions: Array) -> float:
	var inside_seen:=false
	var end:=0.0
	for step in range(ceili(limit/.01)+1):
		var t:=minf(limit,step*.01)
		var p:=entry+direction*t
		var inside:=false
		for region in regions:
			if ((p-region.center)/region.radii).length_squared()<=1.001: inside=true; break
		if inside: inside_seen=true; end=t
		elif inside_seen: break
	return end
