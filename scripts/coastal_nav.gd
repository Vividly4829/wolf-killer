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
var deck_index:Dictionary={}
var deck_planes:Array=[]

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
	_build_deck_index()
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
	# Fine island cells take precedence in at(). Mirror existing coarse links
	# onto those canonical cells so overlap seams cannot trap moving actors.
	for pair:Array in data.edges:
		var pa:=point(base_size+int(pair[0])); var pb:=point(base_size+int(pair[1]))
		var ca:=at(pa.x,pa.z); var cb:=at(pb.x,pb.z)
		if ca!=cb and (ca<base_size or cb<base_size) and valid(ca) and valid(cb) and absf(point(ca).y-point(cb).y)<=STEP_HEIGHT:
			connect_nodes(ca,cb)
	distances.resize(size)
	_queue.resize(size)

func connect_nodes(a: int,b: int) -> void:
	if not neighbors.has(a): neighbors[a] = PackedInt32Array()
	if not neighbors.has(b): neighbors[b] = PackedInt32Array()
	if not neighbors[a].has(b): neighbors[a].append(b)
	if not neighbors[b].has(a): neighbors[b].append(a)

func at(x: float,z: float) -> int:
	var old := super.at(x,z)
	if valid(old): return old
	return int(lookup.get(Vector2i(roundi(x),roundi(z)),-1))

func point(i: int) -> Vector3:
	return extras[i-base_size] if base_size > 0 and i >= base_size and i < size else super.point(i)

func height_at(x: float,z: float) -> float:
	var deck:=deck_at(x,z)
	if deck>=0: return deck_height(deck,x,z)
	var cell := at(x,z)
	if not valid(cell): return NAN
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
	var score := INF if best<0 else Vector2(point(best).x-x,point(best).z-z).length_squared()
	var closest:=Vector2i(roundi(x),roundi(z))
	var center:=int(lookup.get(closest,-1))
	if valid(center):
		var p:=point(center)
		return center if Vector2(p.x-x,p.z-z).length_squared()<score else best
	for ring in range(1,ceili(radius)+1):
		if score<pow(ring-.5,2): break
		for dz in range(-ring,ring+1):
			for dx in range(-ring,ring+1):
				if absi(dx)!=ring and absi(dz)!=ring: continue
				var i:=int(lookup.get(closest+Vector2i(dx,dz),-1))
				if not valid(i): continue
				var p:=point(i)
				var distance:=Vector2(p.x-x,p.z-z).length_squared()
				if distance<score: best=i; score=distance
	return best

func can_move(ax: float,az: float,bx: float,bz: float) -> bool:
	var from_deck:=deck_at(ax,az); var to_deck:=deck_at(bx,bz)
	if from_deck>=0 and to_deck>=0:
		return absf(deck_height(from_deck,ax,az)-deck_height(to_deck,bx,bz))<=STEP_HEIGHT
	# Keep feet on a raised deck rather than accepting a water/ground sample
	# beside its handrail. Only level landings allow stepping off.
	if from_deck>=0 or to_deck>=0:
		var terrain:=at(bx,bz) if from_deck>=0 else at(ax,az)
		var deck_y:=deck_height(from_deck,ax,az) if from_deck>=0 else deck_height(to_deck,bx,bz)
		if not valid(terrain) or absf(point(terrain).y-deck_y)>STEP_HEIGHT: return false
		return true
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

func _build_deck_index() -> void:
	deck_planes.clear(); deck_index.clear()
	for crossing:Dictionary in crossings:
		var a:=Vector3(crossing.a[0],crossing.a[1],crossing.a[2])
		var b:=Vector3(crossing.b[0],crossing.b[1],crossing.b[2])
		var line:=Vector2(b.x-a.x,b.z-a.z)
		if line.length_squared()<.001: continue
		var half:=float(crossing.get("width",2.0))*.5-.28
		var entry:Dictionary={"a":a,"line":line,"inverse":1.0/line.length_squared(),"rise":b.y-a.y,"half":half,"margin":.45/line.length()}
		var id:=deck_planes.size(); deck_planes.append(entry)
		for x in range(floori((minf(a.x,b.x)-half-1)/8),floori((maxf(a.x,b.x)+half+1)/8)+1):
			for z in range(floori((minf(a.z,b.z)-half-1)/8),floori((maxf(a.z,b.z)+half+1)/8)+1):
				var key:=Vector2i(x,z)
				if not deck_index.has(key): deck_index[key]=[]
				deck_index[key].append(id)
func deck_at(x:float,z:float) -> int:
	var candidates:Array=deck_index.get(Vector2i(floori(x/8),floori(z/8)),[])
	var chosen:=-1; var score:=INF
	for id:int in candidates:
		var deck:Dictionary=deck_planes[id]
		var offset:=Vector2(x-deck.a.x,z-deck.a.z)
		var t:float=offset.dot(deck.line)*deck.inverse
		if t< -deck.margin or t>1+deck.margin: continue
		var distance:float=(offset-deck.line*t).length_squared()
		if distance<=deck.half*deck.half and distance<score: chosen=id; score=distance
	return chosen
func deck_height(id:int,x:float,z:float) -> float:
	var deck:Dictionary=deck_planes[id]
	var t:float=Vector2(x-deck.a.x,z-deck.a.z).dot(deck.line)*deck.inverse
	return deck.a.y+deck.rise*t
