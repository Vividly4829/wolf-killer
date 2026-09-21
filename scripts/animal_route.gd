extends RefCounted
static var last_frame := -1
static func permit() -> bool:
	var frame := Engine.get_physics_frames()
	if frame==last_frame: return false
	last_frame=frame
	return true
## Bounded A* over existing collision-aware links; shared pursuit fields stay untouched.
static func plan(nav: RefCounted,start: Vector3,goal: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var source: int = nav.at(start.x,start.z)
	if not nav.valid(source): source=nav.nearest(start.x,start.z,2)
	var target: int = nav.at(goal.x,goal.z)
	if not nav.valid(target): target=nav.nearest(goal.x,goal.z,2)
	if source<0 or target<0: return result
	var queue: Array = [[0.0,source]]
	var costs := {source:0.0}
	var parent := {}
	var closed := {}
	var end: Vector3 = nav.point(target)
	while not queue.is_empty() and closed.size()<4096:
		var item: Array = queue[0]
		var tail: Array = queue.pop_back()
		if not queue.is_empty():
			queue[0] = tail
			var k := 0
			while k*2+1<queue.size():
				var child := k*2+1
				if child+1<queue.size() and queue[child+1][0]<queue[child][0]: child += 1
				if queue[k][0]<=queue[child][0]: break
				var swap: Array = queue[k]; queue[k]=queue[child]; queue[child]=swap
				k = child
		var id: int = item[1]
		if closed.has(id): continue
		closed[id] = true
		if id==target:
			var reversed := PackedVector3Array()
			while id!=source:
				reversed.append(nav.point(id)); id=parent[id]
			reversed.reverse()
			var cursor := start
			var n := 0
			while n<reversed.size():
				var far := n
				while far+1<reversed.size() and far-n<32 and corridor_clear(nav,cursor,reversed[far+1]): far += 1
				result.append(reversed[far]); cursor=reversed[far]; n=far+1
			return result
		for next in nav.adjacent(id):
			if closed.has(next): continue
			var point: Vector3 = nav.point(next)
			var here: Vector3 = nav.point(id)
			if absf(point.x-here.x)>.05 and absf(point.z-here.z)>.05:
				if not nav.can_move(here.x,here.z,point.x,here.z) or not nav.can_move(point.x,here.z,point.x,point.z) or not nav.can_move(here.x,here.z,here.x,point.z) or not nav.can_move(here.x,point.z,point.x,point.z): continue
			var cost: float = costs[id]+nav.point(id).distance_to(point)
			if cost>=float(costs.get(next,INF)): continue
			costs[next]=cost; parent[next]=id
			queue.append([cost+point.distance_to(end),next])
			var k := queue.size()-1
			while k>0:
				var up := (k-1)/2
				if queue[up][0]<=queue[k][0]: break
				var swap: Array=queue[up]; queue[up]=queue[k]; queue[k]=swap; k=up
	return result
static func corridor_clear(nav: RefCounted,a: Vector3,b: Vector3) -> bool:
	var side: Vector3=(b-a).cross(Vector3.UP).normalized()*.08
	for offset in [Vector3.ZERO,side,-side]:
		if not nav.line_clear(a.x+offset.x,a.z+offset.z,b.x+offset.x,b.z+offset.z): return false
	return true
