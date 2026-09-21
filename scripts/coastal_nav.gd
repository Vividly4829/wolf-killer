extends IslandNav
## Original quarter-metre island grid plus sparse one-metre coastal samples.
var base_size := 0
var extras := PackedVector3Array()
var lookup: Dictionary = {}
var neighbors: Dictionary = {}
var working := PackedInt32Array()
var work_queue := PackedInt32Array()
var work_head := 0
var work_tail := 0
var requested := Vector2.INF
var crossings: Array = []

func request_field(x: float,z: float) -> void:
	requested = Vector2(x,z)

func pump_field() -> void:
	if work_head >= work_tail:
		if not requested.is_finite(): return
		var start := nearest(requested.x,requested.y,2)
		requested = Vector2.INF
		if start < 0: return
		working.resize(size)
		working.fill(-1)
		work_queue.resize(size)
		work_queue[0] = start
		working[start] = 0
		work_head = 0
		work_tail = 1
	var deadline := Time.get_ticks_usec()+2500
	while work_head < work_tail:
		var i := work_queue[work_head]
		work_head += 1
		for j in adjacent(i):
			if working[j] < 0:
				working[j] = working[i]+1
				work_queue[work_tail] = j
				work_tail += 1
		if work_head % 128 == 0 and Time.get_ticks_usec() >= deadline: return
	distances = working
	reachable = work_queue.slice(0,work_tail)
	working = PackedInt32Array()

func extend_coast(data: Dictionary) -> void:
	crossings = data.get("bridges",[]).duplicate()
	for house: Dictionary in data.get("houses",[]):
		crossings.append({"a":house.door,"b":house.end})
	base_size = size
	for p: Array in data.points:
		lookup[Vector2i(int(p[0]),int(p[2]))] = size
		extras.append(Vector3(p[0],p[1],p[2]))
		heights.append(float(p[1]))
		blocked.append(0)
		links.append(0)
		size += 1
	for pair: Array in data.edges: connect_nodes(base_size+int(pair[0]),base_size+int(pair[1]))
	for pair: Array in data.joins:
		if valid(int(pair[1])): connect_nodes(base_size+int(pair[0]),int(pair[1]))
	distances.resize(size)
	_queue.resize(size)

func connect_nodes(a: int,b: int) -> void:
	if not neighbors.has(a): neighbors[a] = PackedInt32Array()
	if not neighbors.has(b): neighbors[b] = PackedInt32Array()
	neighbors[a].append(b)
	neighbors[b].append(a)

func at(x: float,z: float) -> int:
	var old := super.at(x,z)
	if valid(old): return old
	return int(lookup.get(Vector2i(roundi(x),roundi(z)),-1))

func point(i: int) -> Vector3:
	return extras[i-base_size] if base_size > 0 and i >= base_size and i < size else super.point(i)

func height_at(x: float,z: float) -> float:
	var cell := at(x,z)
	if not valid(cell): return NAN
	# Match the actual continuous bridge plane rather than one-metre stair steps.
	for crossing: Dictionary in crossings:
		var a := Vector3(crossing.a[0],crossing.a[1],crossing.a[2])
		var b := Vector3(crossing.b[0],crossing.b[1],crossing.b[2])
		var line := Vector2(b.x-a.x,b.z-a.z)
		var t := Vector2(x-a.x,z-a.z).dot(line)/line.length_squared()
		if t<0 or t>1: continue
		if Vector2(x-a.x,z-a.z).distance_to(line*t)<1.5: return lerpf(a.y,b.y,t)
	# Interpolate only connected samples: walls and inaccessible water stay blocked.
	var origin := point(cell)
	var spacing := 1.0 if cell>=base_size and base_size>0 else cell_size
	var weighted := 0.0
	var weight_sum := 0.0
	var samples := adjacent(cell)
	samples.append(cell)
	for sample in samples:
		var p := point(sample)
		if absf(p.y-origin.y)>1.1: continue
		var weight := maxf(0,1.0-absf(p.x-x)/spacing)*maxf(0,1.0-absf(p.z-z)/spacing)
		weighted += p.y*weight
		weight_sum += weight
	return weighted/weight_sum if weight_sum>.001 else origin.y

func nearest(x: float,z: float,radius: float = 8.0) -> int:
	var best := super.nearest(x,z,radius)
	var score := INF if best < 0 else Vector2(point(best).x-x,point(best).z-z).length_squared()
	for dz in range(-ceili(radius),ceili(radius)+1):
		for dx in range(-ceili(radius),ceili(radius)+1):
			var i := int(lookup.get(Vector2i(roundi(x)+dx,roundi(z)+dz),-1))
			if i < 0: continue
			var p := point(i)
			var distance := Vector2(p.x-x,p.z-z).length_squared()
			if distance < score: best = i; score = distance
	return best

func can_move(ax: float,az: float,bx: float,bz: float) -> bool:
	var a := at(ax,az)
	var b := at(bx,bz)
	if not valid(a) or not valid(b): return false
	if a == b: return true
	if neighbors.has(a) and neighbors[a].has(b): return true
	if base_size == 0 or (a < base_size and b < base_size): return super.can_move(ax,az,bx,bz)
	return false

func adjacent(i: int) -> PackedInt32Array:
	var result: PackedInt32Array = neighbors.get(i,PackedInt32Array()).duplicate()
	if base_size == 0 or i < base_size:
		for k in 8:
			if links[i] & (1 << k): result.append(i+_offsets[k])
	return result

func field(x: float,z: float) -> void:
	if base_size == 0: super.field(x,z); return
	var start := nearest(x,z,2)
	distances.fill(-1)
	reachable.clear()
	if start < 0: return
	var head := 0
	var tail := 1
	_queue[0] = start
	distances[start] = 0
	while head < tail:
		var i := _queue[head]
		head += 1
		for j in adjacent(i):
			if distances[j] < 0:
				distances[j] = distances[i]+1
				_queue[tail] = j
				tail += 1
	reachable = _queue.slice(0,tail)

func next_point(x: float,z: float) -> Vector3:
	var i := at(x,z)
	if not valid(i) or distances[i] < 0: return Vector3.INF
	var best := i
	for j in adjacent(i):
		if distances[j] >= 0 and distances[j] < distances[best]: best = j
	var destination := point(best)
	# Coarse deck samples can overlap a fine island cell. Skip such virtual
	# waypoints so an animal never aims forever at its current physical position.
	if at(destination.x,destination.z)!=best or Vector2(destination.x-x,destination.z-z).length()<.06:
		var candidates := adjacent(i)
		for neighbor in adjacent(i): candidates.append_array(adjacent(neighbor))
		var score := distances[i]
		for candidate in candidates:
			var p := point(candidate)
			var canonical := at(p.x,p.z)
			if canonical==i or not valid(canonical) or distances[canonical]<0 or distances[canonical]>=score: continue
			if line_clear(x,z,p.x,p.z):
				destination = p
				score = distances[canonical]
	return destination

var brush: Dictionary = {}
func vegetation_factor(p: Vector3) -> float:
	var key:=Vector2i(floori(p.x/4),floori(p.z/4))
	var factor:=1.0
	for x in range(-1,2):
		for z in range(-1,2):
			var other:=key+Vector2i(x,z)
			if brush.has(other):
				var distance:=Vector2(p.x-brush[other].x,p.z-brush[other].z).length()
				factor=minf(factor,lerpf(.68,1.0,smoothstep(.25,1.7,distance)))
	return factor
