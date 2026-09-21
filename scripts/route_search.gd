extends RefCounted
## Incremental A*: all callers share 3 ms per physics frame. Searches retain state
## across frames instead of repeatedly blocking a render with thousands of cells.
static var frame := -1
static var spent := 0
var nav: RefCounted
var source := -1
var target := -1
var origin := Vector3.ZERO
var end := Vector3.ZERO
var queue: Array=[]
var costs: Dictionary={}
var parents: Dictionary={}
var closed: Dictionary={}
var finished := false
var result := PackedVector3Array()
var reversing := -1
var raw := PackedVector3Array()
func start(navigation: RefCounted,a: Vector3,b: Vector3) -> void:
	nav=navigation; origin=a
	source=nav.at(a.x,a.z); target=nav.at(b.x,b.z)
	if not nav.valid(source): source=nav.nearest(a.x,a.z,3)
	if not nav.valid(target): target=nav.nearest(b.x,b.z,3)
	if source<0 or target<0: finished=true; return
	end=nav.point(target); costs[source]=0.0; push([0.0,source])
func push(entry: Array) -> void:
	queue.append(entry); var i:=queue.size()-1
	while i>0:
		var parent: int=(i-1)/2
		if queue[parent][0]<=queue[i][0]: break
		var swap=queue[parent]; queue[parent]=queue[i]; queue[i]=swap; i=parent
func pop() -> Array:
	var top: Array=queue[0]; var last=queue.pop_back()
	if queue.is_empty(): return top
	queue[0]=last; var i:=0
	while true:
		var child:=i*2+1
		if child>=queue.size(): break
		if child+1<queue.size() and queue[child+1][0]<queue[child][0]: child+=1
		if queue[i][0]<=queue[child][0]: break
		var swap=queue[i]; queue[i]=queue[child]; queue[child]=swap; i=child
	return top
func advance() -> void:
	if finished: return
	var current:=Engine.get_physics_frames()
	if current!=frame: frame=current; spent=0
	if spent>=3000: return
	var start_time:=Time.get_ticks_usec()
	var deadline:=start_time+mini(550,3000-spent)
	while Time.get_ticks_usec()<deadline:
		if reversing>=0:
			if reversing==source:
				raw.reverse(); result=raw; finished=true; break
			raw.append(nav.point(reversing)); reversing=parents[reversing]; continue
		if queue.is_empty() or closed.size()>24000: finished=true; break
		var entry=pop(); var id: int=entry[1]
		if closed.has(id): continue
		if id==target: reversing=id; continue
		closed[id]=true
		var here: Vector3=nav.point(id)
		for next in nav.adjacent(id):
			if closed.has(next): continue
			var point: Vector3=nav.point(next)
			if absf(point.x-here.x)>.05 and absf(point.z-here.z)>.05:
				if not nav.can_move(here.x,here.z,point.x,here.z) or not nav.can_move(point.x,here.z,point.x,point.z) or not nav.can_move(here.x,here.z,here.x,point.z) or not nav.can_move(here.x,point.z,point.x,point.z): continue
			var cost: float=costs[id]+here.distance_to(point)
			if cost>=float(costs.get(next,INF)): continue
			costs[next]=cost; parents[next]=id
			push([cost+point.distance_to(end),next])
	spent+=Time.get_ticks_usec()-start_time
