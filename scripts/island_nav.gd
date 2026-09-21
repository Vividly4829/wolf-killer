class_name IslandNav
extends RefCounted
## Navigation sampled from the real island, including floors, stairs and doors.
## Invalid height queries return NAN; unreachable next points return Vector3.INF.

const STEP_HEIGHT := 0.68
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
var width: int
var depth: int
var size: int
var cell_size: float
var origin := Vector2.ZERO
var heights := PackedFloat32Array()
var blocked := PackedByteArray()
var links := PackedByteArray()
var distances := PackedInt32Array()
var reachable := PackedInt32Array()
var _queue := PackedInt32Array()
var _offsets := PackedInt32Array()

func setup(grid: Dictionary) -> void:
	width = int(grid.width)
	depth = int(grid.depth)
	size = width * depth
	cell_size = float(grid.cellSize)
	origin = Vector2(float(grid.origin[0]), float(grid.origin[1]))
	heights.resize(size)
	blocked = PackedByteArray(grid.blocked)
	links.resize(size)
	links.fill(0)
	distances.resize(size)
	distances.fill(-1)
	_queue.resize(size)
	_offsets.clear()
	for i in size:
		heights[i] = -999.0 if grid.heights[i] == null else float(grid.heights[i])
	for direction in DIRS:
		_offsets.append(direction.y * width + direction.x)
	for i in size:
		if not valid(i):
			continue
		var x: int = i % width
		var z: int = i / width
		for k in 8:
			var direction := DIRS[k]
			var j := index(x + direction.x, z + direction.y)
			if not valid(j) or absf(heights[j] - heights[i]) > STEP_HEIGHT:
				continue
			if direction.x != 0 and direction.y != 0:
				var a := index(x + direction.x, z)
				var b := index(x, z + direction.y)
				if not valid(a) or not valid(b) or absf(heights[a] - heights[i]) > STEP_HEIGHT or absf(heights[b] - heights[i]) > STEP_HEIGHT:
					continue
			links[i] |= 1 << k

func index(x: int, z: int) -> int:
	return -1 if x < 0 or z < 0 or x >= width or z >= depth else z * width + x

func at(x: float, z: float) -> int:
	return index(roundi((x - origin.x) / cell_size), roundi((z - origin.y) / cell_size))

func valid(i: int) -> bool:
	return i >= 0 and i < size and blocked[i] == 0 and heights[i] > -900.0

func point(i: int) -> Vector3:
	if i < 0 or i >= size:
		return Vector3.INF
	return Vector3(origin.x + (i % width) * cell_size, heights[i], origin.y + int(i / width) * cell_size)

func nearest(x: float, z: float, radius: float = 8.0) -> int:
	var best := -1
	var score := INF
	var column := roundi((x - origin.x) / cell_size)
	var row := roundi((z - origin.y) / cell_size)
	var n := ceili(radius / cell_size)
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var i := index(column + dx, row + dz)
			if not valid(i):
				continue
			var p := point(i)
			var distance := Vector2(p.x - x, p.z - z).length_squared()
			if distance < score:
				score = distance
				best = i
	return best

func height_at(x: float, z: float) -> float:
	var i := at(x, z)
	return heights[i] if valid(i) else NAN

func can_move(ax: float, az: float, bx: float, bz: float) -> bool:
	var a := at(ax, az)
	var b := at(bx, bz)
	if not valid(a) or not valid(b):
		return false
	if a == b:
		return true
	var direction := Vector2i(b % width - a % width, int(b / width) - int(a / width))
	var k := DIRS.find(direction)
	return k >= 0 and bool(links[a] & (1 << k))

func move_position(pos: Vector3, dx: float, dz: float) -> Vector3:
	var steps := maxi(1, ceili(Vector2(dx, dz).length() / (cell_size * 0.45)))
	var sx := dx / steps
	var sz := dz / steps
	for _step in steps:
		if can_move(pos.x, pos.z, pos.x + sx, pos.z + sz):
			pos.x += sx
			pos.z += sz
		else:
			var wanted:=Vector2(sx,sz)
			var best:=Vector2.ZERO
			var score:=0.0
			# Follow the nearest clear tangent around roots and trunk corners.
			for angle in [.30,-.30,.60,-.60,.95,-.95,1.25,-1.25]:
				var slide:=wanted.rotated(angle)
				if can_move(pos.x,pos.z,pos.x+slide.x,pos.z+slide.y) and slide.dot(wanted)>score:
					best=slide; score=slide.dot(wanted)
			for slide in [Vector2(sx,0),Vector2(0,sz)]:
				if can_move(pos.x,pos.z,pos.x+slide.x,pos.z+slide.y) and slide.dot(wanted)>score:
					best=slide; score=slide.dot(wanted)
			pos.x+=best.x; pos.z+=best.y

	var ground := height_at(pos.x, pos.z)
	if not is_nan(ground):
		pos.y = ground
	return pos

func field(x: float, z: float) -> void:
	var start := nearest(x, z, 2.0)
	distances.fill(-1)
	reachable.clear()
	if start < 0:
		return
	var head := 0
	var tail := 1
	_queue[0] = start
	distances[start] = 0
	while head < tail:
		var i := _queue[head]
		head += 1
		for k in 8:
			if links[i] & (1 << k):
				var j := i + _offsets[k]
				if distances[j] < 0:
					distances[j] = distances[i] + 1
					_queue[tail] = j
					tail += 1
	reachable = _queue.slice(0, tail)

func next_point(x: float, z: float) -> Vector3:
	var i := at(x, z)
	if not valid(i) or distances[i] < 0:
		return Vector3.INF
	var best := i
	var distance := distances[i]
	for k in 8:
		if links[i] & (1 << k):
			var j := i + _offsets[k]
			if distances[j] >= 0 and distances[j] < distance:
				distance = distances[j]
				best = j
	return point(best)

func line_clear(ax: float, az: float, bx: float, bz: float) -> bool:
	var steps := maxi(1, ceili(Vector2(bx - ax, bz - az).length() / (cell_size * 0.5)))
	var x := ax
	var z := az
	for step in range(1, steps + 1):
		var nx := lerpf(ax, bx, float(step) / steps)
		var nz := lerpf(az, bz, float(step) / steps)
		if not can_move(x, z, nx, nz):
			return false
		x = nx
		z = nz
	return true
